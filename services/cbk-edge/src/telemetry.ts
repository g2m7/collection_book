import {
  telemetryClientIdPattern,
  telemetryEventIdPattern,
  telemetryEventNames,
  telemetryMaxCompressedBytes,
  telemetryMaxDecompressedBytes,
  type TelemetryBatch,
  type TelemetryEvent,
  type TelemetryEventName,
  type TelemetryProperties,
  type TelemetryPropertyName,
} from "@collection-book/contracts";

const serviceTypes = new Set(["tv", "fiber"]);
const firstSubscriberMethods = new Set(["manual", "mso_import"]);
const importFormats = new Set([
  "book1",
  "active_packages",
  "total_list",
  "csv",
  "unknown",
]);
const integerProperties = new Set<TelemetryPropertyName>([
  "record_count",
  "elapsed_ms",
  "inserted_count",
  "updated_count",
  "payment_count",
]);
const booleanProperties = new Set<TelemetryPropertyName>([
  "has_adjustment",
  "used_web_fallback",
]);
const requiredProperties: Record<
  TelemetryEventName,
  readonly TelemetryPropertyName[]
> = {
  app_first_open: [],
  first_subscriber_created: ["method"],
  mso_file_imported: [
    "service_type",
    "record_count",
    "mso_format",
    "elapsed_ms",
    "inserted_count",
    "updated_count",
    "payment_count",
  ],
  payment_recorded: ["service_type", "has_adjustment"],
  whatsapp_receipt_dispatched: ["service_type", "used_web_fallback"],
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isBoundedInteger(
  value: unknown,
  maximum = 2_147_483_647,
): value is number {
  return (
    typeof value === "number" &&
    Number.isSafeInteger(value) &&
    value >= 0 &&
    value <= maximum
  );
}

function validateProperty(
  key: string,
  value: unknown,
): value is TelemetryProperties[TelemetryPropertyName] {
  if (integerProperties.has(key as TelemetryPropertyName)) {
    return isBoundedInteger(
      value,
      key === "elapsed_ms" ? 86_400_000 : undefined,
    );
  }
  if (booleanProperties.has(key as TelemetryPropertyName)) {
    return typeof value === "boolean";
  }
  if (key === "service_type") {
    return typeof value === "string" && serviceTypes.has(value);
  }
  if (key === "method") {
    return typeof value === "string" && firstSubscriberMethods.has(value);
  }
  if (key === "mso_format") {
    return typeof value === "string" && importFormats.has(value);
  }
  return false;
}

function validateProperties(
  eventName: TelemetryEventName,
  value: unknown,
): value is TelemetryProperties {
  if (!isRecord(value)) return false;

  const allowed = new Set(requiredProperties[eventName]);
  if (allowed.size !== Object.keys(value).length) return false;
  if (
    !Object.keys(value).every((key) =>
      allowed.has(key as TelemetryPropertyName),
    )
  ) {
    return false;
  }
  if (!requiredProperties[eventName].every((key) => key in value)) return false;

  return Object.entries(value).every(([key, propertyValue]) =>
    validateProperty(key, propertyValue),
  );
}

function isTelemetryEventName(value: unknown): value is TelemetryEventName {
  return telemetryEventNames.some((name) => name === value);
}

export function validateTelemetryBatch(value: unknown): TelemetryBatch | null {
  if (!isRecord(value)) return null;
  if (
    typeof value.client_id !== "string" ||
    !telemetryClientIdPattern.test(value.client_id) ||
    !Array.isArray(value.events) ||
    value.events.length === 0
  ) {
    return null;
  }
  if (
    Object.keys(value).some((key) => key !== "client_id" && key !== "events")
  ) {
    return null;
  }

  const events: TelemetryEvent[] = [];
  const ids = new Set<string>();
  for (const candidate of value.events) {
    if (!isRecord(candidate)) return null;
    if (
      Object.keys(candidate).some(
        (key) => !["id", "event_name", "timestamp", "properties"].includes(key),
      )
    ) {
      return null;
    }
    if (
      typeof candidate.id !== "string" ||
      !telemetryEventIdPattern.test(candidate.id) ||
      ids.has(candidate.id) ||
      !isTelemetryEventName(candidate.event_name) ||
      !isBoundedInteger(candidate.timestamp, 4_102_444_800_000) ||
      !validateProperties(candidate.event_name, candidate.properties)
    ) {
      return null;
    }
    ids.add(candidate.id);
    events.push(candidate as unknown as TelemetryEvent);
  }
  return { client_id: value.client_id, events };
}

async function readCompressed(
  request: Request,
  maximum: number,
): Promise<Uint8Array> {
  const source = request.body;
  if (source === null) throw new TypeError("missing_body");
  const reader = source.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    if (value === undefined) continue;
    total += value.byteLength;
    if (total > maximum) {
      await reader.cancel();
      throw new RangeError("compressed_too_large");
    }
    chunks.push(value);
  }
  const result = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    result.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return result;
}

async function decompressBounded(
  compressed: Uint8Array,
  maximum: number,
): Promise<Uint8Array> {
  const decompressor = new DecompressionStream("gzip");
  const compressedWriter = decompressor.writable.getWriter();
  const input = new Uint8Array(compressed.byteLength);
  input.set(compressed);
  const write = compressedWriter
    .write(input)
    .then(() => compressedWriter.close());
  void write.catch(() => undefined);
  const reader = decompressor.readable.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    if (value === undefined) continue;
    total += value.byteLength;
    if (total > maximum) {
      await reader.cancel().catch(() => undefined);
      throw new RangeError("decompressed_too_large");
    }
    chunks.push(value);
  }
  await write;
  const result = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    result.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return result;
}

export async function readTelemetryJson(
  request: Request,
): Promise<
  { json: unknown } | { error: "compressed" | "decompressed" | "malformed" }
> {
  try {
    const compressed = await readCompressed(
      request,
      telemetryMaxCompressedBytes,
    );
    const decompressed = await decompressBounded(
      compressed,
      telemetryMaxDecompressedBytes,
    );
    return {
      json: JSON.parse(
        new TextDecoder("utf-8", { fatal: true }).decode(decompressed),
      ),
    };
  } catch (error) {
    if (
      error instanceof RangeError &&
      error.message === "compressed_too_large"
    ) {
      return { error: "compressed" };
    }
    if (
      error instanceof RangeError &&
      error.message === "decompressed_too_large"
    ) {
      return { error: "decompressed" };
    }
    return { error: "malformed" };
  }
}

export function telemetryBatchError(
  error: "compressed" | "decompressed" | "malformed",
): string {
  switch (error) {
    case "compressed":
      return "compressed_body_too_large";
    case "decompressed":
      return "decompressed_body_too_large";
    case "malformed":
      return "malformed_telemetry";
  }
}

import { gzipSync } from "node:zlib";
import { afterEach, describe, expect, test } from "bun:test";
import type { AnalyticsEngineBinding } from "@collection-book/contracts";
import { handleRequest } from "../src/index";

const endpoint = "https://cbk.sarbaa.com/api/v1/telemetry/batch";
const originalLog = console.log;

afterEach(() => {
  console.log = originalLog;
});

function event(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    id: "0123456789abcdef0123456789abcdef",
    event_name: "app_first_open",
    timestamp: 1_790_150_400_000,
    properties: {},
    ...overrides,
  };
}

function batch(
  events: Record<string, unknown>[],
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    client_id: "anon_0123456789abcdef0123456789abcdef",
    events,
    ...overrides,
  };
}

function request(value: unknown, init: RequestInit = {}): Request {
  return new Request(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json", "Content-Encoding": "gzip" },
    body: gzipSync(JSON.stringify(value)),
    ...init,
  });
}

class Binding implements AnalyticsEngineBinding {
  readonly points: Array<{
    blobs: string[];
    doubles: number[];
    indexes: string[];
  }> = [];

  constructor(private readonly shouldThrow = false) {}

  writeDataPoint(options: {
    blobs: string[];
    doubles: number[];
    indexes: string[];
  }): void {
    const byteLength = (value: string) =>
      new TextEncoder().encode(value).length;
    if (
      options.indexes.length > 1 ||
      options.blobs.length > 20 ||
      options.doubles.length > 20
    ) {
      throw new Error("Analytics Engine field count exceeded");
    }
    if (options.indexes.some((value) => byteLength(value) > 96)) {
      throw new Error("Analytics Engine index exceeded");
    }
    if (options.blobs.some((value) => byteLength(value) > 5120)) {
      throw new Error("Analytics Engine blob exceeded");
    }
    if (this.shouldThrow) throw new Error("write failed");
    this.points.push(options);
  }
}

describe("telemetry ingestion", () => {
  test("accepts a valid bounded batch and writes typed points", async () => {
    const telemetry = new Binding();
    const response = await handleRequest(request(batch([event()])), {
      TELEMETRY: telemetry,
    });

    expect(response.status).toBe(200);
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(response.headers.get("X-Content-Type-Options")).toBe("nosniff");
    expect(await response.json()).toEqual({
      accepted_event_ids: ["0123456789abcdef0123456789abcdef"],
    });
    expect(telemetry.points).toEqual([
      {
        indexes: ["anon_0123456789abcdef0123456789abcdef"],
        doubles: [1_790_150_400_000],
        blobs: ["app_first_open", "0123456789abcdef0123456789abcdef", "{}"],
      },
    ]);
  });

  test("test binding enforces native Analytics Engine field limits", () => {
    const telemetry = new Binding();

    expect(() =>
      telemetry.writeDataPoint({
        indexes: ["client", "event"],
        blobs: [],
        doubles: [],
      }),
    ).toThrow();
    expect(() =>
      telemetry.writeDataPoint({
        indexes: [],
        blobs: ["x".repeat(5121)],
        doubles: [],
      }),
    ).toThrow();
  });

  test("accepts every implemented event with its exact safe properties", async () => {
    const telemetry = new Binding();
    const events = [
      event(),
      event({
        id: "11111111111111111111111111111111",
        event_name: "first_subscriber_created",
        properties: { method: "manual" },
      }),
      event({
        id: "22222222222222222222222222222222",
        event_name: "mso_file_imported",
        properties: {
          service_type: "fiber",
          record_count: 12,
          mso_format: "book1",
          elapsed_ms: 500,
          inserted_count: 10,
          updated_count: 2,
          payment_count: 8,
        },
      }),
      event({
        id: "33333333333333333333333333333333",
        event_name: "payment_recorded",
        properties: { service_type: "tv", has_adjustment: false },
      }),
      event({
        id: "44444444444444444444444444444444",
        event_name: "whatsapp_receipt_dispatched",
        properties: { service_type: "tv", used_web_fallback: true },
      }),
    ];
    const response = await handleRequest(request(batch(events)), {
      TELEMETRY: telemetry,
    });

    expect(response.status).toBe(200);
    expect(telemetry.points).toHaveLength(5);
  });

  test.each([
    ["unknown event", batch([event({ event_name: "paywall_impression" })])],
    [
      "unknown property",
      batch([
        event({
          event_name: "payment_recorded",
          properties: {
            service_type: "tv",
            has_adjustment: false,
            subscriber_name: "Private Customer",
          },
        }),
      ]),
    ],
    [
      "wrong property type",
      batch([
        event({
          event_name: "payment_recorded",
          properties: { service_type: "operator", has_adjustment: "no" },
        }),
      ]),
    ],
    ["extra top-level field", batch([event()], { device_model: "Redmi" })],
    [
      "identifier",
      batch([event()], {
        client_id: "anon_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        device_model: "Redmi",
      }),
    ],
  ])("rejects %s without writing", async (_name, value) => {
    const telemetry = new Binding();
    const response = await handleRequest(request(value), {
      TELEMETRY: telemetry,
    });

    expect(response.status).toBe(400);
    expect(telemetry.points).toHaveLength(0);
  });

  test("rejects too many events", async () => {
    const events = Array.from({ length: 51 }, (_, index) =>
      event({ id: index.toString(16).padStart(32, "0") }),
    );
    const response = await handleRequest(request(batch(events)), {
      TELEMETRY: new Binding(),
    });

    expect(response.status).toBe(413);
    expect(await response.json()).toEqual({ error: "too_many_events" });
  });

  test("rejects malformed JSON and invalid gzip", async () => {
    const malformed = await handleRequest(
      new Request(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Encoding": "gzip",
        },
        body: gzipSync("not-json"),
      }),
      { TELEMETRY: new Binding() },
    );
    const invalidEncoding = await handleRequest(
      new Request(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Encoding": "gzip",
        },
        body: "{}",
      }),
      { TELEMETRY: new Binding() },
    );

    expect(malformed.status).toBe(400);
    expect(invalidEncoding.status).toBe(400);
  });

  test("enforces JSON content type and gzip encoding", async () => {
    const wrongType = await handleRequest(
      request(batch([event()]), { headers: { "Content-Type": "text/plain" } }),
      { TELEMETRY: new Binding() },
    );
    const wrongEncoding = await handleRequest(
      request(batch([event()]), {
        headers: {
          "Content-Type": "application/json",
          "Content-Encoding": "br",
        },
      }),
      { TELEMETRY: new Binding() },
    );

    expect(wrongType.status).toBe(415);
    expect(wrongEncoding.status).toBe(415);
  });

  test("rejects oversized compressed and decompressed bodies", async () => {
    const compressedBody = Buffer.alloc(64 * 1024 + 1, 0x61);
    const compressed = await handleRequest(
      new Request(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Encoding": "gzip",
          "Content-Length": String(compressedBody.length),
        },
        body: compressedBody,
      }),
      { TELEMETRY: new Binding() },
    );
    const decompressed = await handleRequest(
      request({ padding: "x".repeat(257 * 1024) }),
      { TELEMETRY: new Binding() },
    );

    expect(compressed.status).toBe(413);
    expect(await compressed.json()).toEqual({
      error: "compressed_body_too_large",
    });
    expect(decompressed.status).toBe(413);
    expect(await decompressed.json()).toEqual({
      error: "decompressed_body_too_large",
    });
  });

  test("is method aware", async () => {
    const response = await handleRequest(new Request(endpoint));

    expect(response.status).toBe(405);
    expect(response.headers.get("Allow")).toBe("POST");
  });

  test("returns retryable 503 when the binding is absent or write fails", async () => {
    const missing = await handleRequest(request(batch([event()])));
    const failed = await handleRequest(request(batch([event()])), {
      TELEMETRY: new Binding(true),
    });

    expect(missing.status).toBe(503);
    expect(failed.status).toBe(503);
    expect(failed.headers.get("Retry-After")).toBe("60");
  });

  test("does not log request metadata or bodies", async () => {
    const logs: unknown[][] = [];
    console.log = (...values: unknown[]) => logs.push(values);
    const response = await handleRequest(
      request(batch([event({ properties: { safe: "no" } })]), {
        headers: {
          "Content-Type": "application/json",
          "Content-Encoding": "gzip",
          "User-Agent": "private-agent",
        },
      }),
      { TELEMETRY: new Binding() },
    );

    expect(response.status).toBe(400);
    expect(logs).toHaveLength(0);
  });
});

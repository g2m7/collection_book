export const publicOrigin = "https://cbk.sarbaa.com";
export const androidPackageName = "com.sarbaa.cbk";
export const referralCodeLength = 6;
export const referralCodePattern = /^[A-Z0-9]{6}$/u;
export const referralCookieName = "cbk_referral";

export const telemetryBatchPath = "/api/v1/telemetry/batch";
export const telemetryMaxEventsPerBatch = 50;
export const telemetryMaxCompressedBytes = 64 * 1024;
export const telemetryMaxDecompressedBytes = 256 * 1024;
export const telemetryClientIdPattern = /^anon_[0-9a-f]{32}$/u;
export const telemetryEventIdPattern = /^[0-9a-f]{32}$/u;

export const telemetryEventNames = [
  "app_first_open",
  "first_subscriber_created",
  "mso_file_imported",
  "payment_recorded",
  "whatsapp_receipt_dispatched",
] as const;

export type TelemetryEventName = (typeof telemetryEventNames)[number];

export const telemetryPropertyNames = [
  "method",
  "service_type",
  "record_count",
  "mso_format",
  "elapsed_ms",
  "inserted_count",
  "updated_count",
  "payment_count",
  "has_adjustment",
  "used_web_fallback",
] as const;

export type TelemetryPropertyName = (typeof telemetryPropertyNames)[number];
export type TelemetryPropertyValue = boolean | number | string;
export type TelemetryProperties = Partial<
  Record<TelemetryPropertyName, TelemetryPropertyValue>
>;

export interface TelemetryEvent {
  id: string;
  event_name: TelemetryEventName;
  timestamp: number;
  properties: TelemetryProperties;
}

export interface TelemetryBatch {
  client_id: string;
  events: TelemetryEvent[];
}

export interface AnalyticsEngineBinding {
  writeDataPoint(options: {
    blobs: string[];
    doubles: number[];
    indexes: string[];
  }): void;
}

export function isValidReferralCode(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value.length === referralCodeLength &&
    referralCodePattern.test(value)
  );
}

export function parseReferralCode(value: unknown): string | null {
  return isValidReferralCode(value) ? value : null;
}

export function buildReferralUrl(value: unknown): string | null {
  const code = parseReferralCode(value);
  return code === null ? null : `${publicOrigin}/r/${code}`;
}

export {
  findNumericCapClaims,
  findUnsupportedClaims,
  unsupportedClaimRules,
  type UnsupportedClaimHit,
  type UnsupportedClaimRule,
} from "./claims";

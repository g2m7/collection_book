/**
 * Pure configuration parsing for the Bun production server adapter.
 *
 * Kept free of `Bun` globals so the validation rules can be unit tested
 * without binding a socket.
 */

/** Loopback by default: nginx terminates TLS and is the only public listener. */
export const defaultListenHostname = "127.0.0.1";
export const defaultListenPort = 8787;

export interface VpsServerConfig {
  /** Host or IP to bind. Loopback unless an operator overrides it. */
  readonly hostname: string;
  /** TCP port to bind. `0` asks the OS for an ephemeral port (tests only). */
  readonly port: number;
  /** Optional HTTPS Google Play listing; absent means no download call to action. */
  readonly playStoreUrl: string | undefined;
  /**
   * Raw Android signing-certificate SHA-256 value. A blank value is unconfigured
   * so asset links stay `[]`; anything else is passed through unvalidated because
   * `normalizeFingerprint` in the request handler already rejects and normalizes
   * a malformed value. No fingerprint is ever defaulted or invented here.
   */
  readonly androidSha256CertFingerprint: string | undefined;
  /**
   * The Bun adapter cannot provide the analytics binding, so the telemetry
   * route answers `503 telemetry_unavailable` and the app keeps its queue.
   */
  readonly telemetryEnabled: false;
}

const hostnamePattern = /^[A-Za-z0-9._:-]+$/u;
const portPattern = /^[0-9]{1,5}$/u;

export function parseListenHostname(value: string | undefined): string {
  if (value === undefined) return defaultListenHostname;
  const hostname = value.trim();
  if (
    hostname === "" ||
    hostname.length > 255 ||
    !hostnamePattern.test(hostname) ||
    hostname.startsWith(".") ||
    hostname.startsWith("-") ||
    hostname.endsWith(".")
  ) {
    throw new Error(
      "CBK_EDGE_HOST must be a bare host or IP literal such as 127.0.0.1 or ::1",
    );
  }
  return hostname;
}

export function parseListenPort(value: string | undefined): number {
  if (value === undefined) return defaultListenPort;
  const port = value.trim();
  if (!portPattern.test(port)) {
    throw new Error("CBK_EDGE_PORT must be a decimal port number");
  }
  const parsed = Number.parseInt(port, 10);
  if (parsed > 65535) {
    throw new Error("CBK_EDGE_PORT must be between 0 and 65535");
  }
  return parsed;
}

function parsePlayStoreUrl(value: string | undefined): string | undefined {
  if (value === undefined) return undefined;
  const trimmed = value.trim();
  return trimmed === "" ? undefined : trimmed;
}

export function parseAndroidSha256CertFingerprint(
  value: string | undefined,
): string | undefined {
  if (value === undefined) return undefined;
  const trimmed = value.trim();
  return trimmed === "" ? undefined : trimmed;
}

export function resolveVpsServerConfig(
  environment: Readonly<Record<string, string | undefined>>,
): VpsServerConfig {
  return {
    hostname: parseListenHostname(environment["CBK_EDGE_HOST"]),
    port: parseListenPort(environment["CBK_EDGE_PORT"]),
    playStoreUrl: parsePlayStoreUrl(environment["PLAY_STORE_URL"]),
    androidSha256CertFingerprint: parseAndroidSha256CertFingerprint(
      environment["ANDROID_SHA256_CERT_FINGERPRINT"],
    ),
    telemetryEnabled: false,
  };
}

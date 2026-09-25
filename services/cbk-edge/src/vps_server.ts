/**
 * Bun production server adapter for the existing `handleRequest` handler.
 *
 * The same request handler that runs on Cloudflare Workers runs here, so the
 * VPS deployment only swaps the runtime, never the behavior. It binds to
 * loopback by default and never logs request metadata: no URL, headers, IP
 * addresses, user agents, or cookies. The only line it writes at startup is the
 * bind address, and the only line the handler itself writes is the minimal
 * referral click record.
 *
 * Known limitation: `TELEMETRY` is a Cloudflare Analytics Engine binding and has
 * no equivalent here, so `POST /api/v1/telemetry/batch` answers
 * `503 telemetry_unavailable` with `Retry-After: 60`. The Android app keeps its
 * queued events instead of discarding them.
 */

import { handleRequest, requestFailedResponse, type WorkerEnv } from "./index";
import { resolveVpsServerConfig, type VpsServerConfig } from "./vps_config";

export interface VpsServerHandle {
  readonly config: VpsServerConfig;
  /** Base URL for local requests, for example `http://127.0.0.1:8787`. */
  readonly url: string;
  stop(): void;
}

export function startVpsServer(
  environment: Readonly<Record<string, string | undefined>> = process.env,
): VpsServerHandle {
  const config = resolveVpsServerConfig(environment);
  const env: WorkerEnv = {
    PLAY_STORE_URL: config.playStoreUrl,
    ANDROID_SHA256_CERT_FINGERPRINT: config.androidSha256CertFingerprint,
  };

  const server = Bun.serve({
    hostname: config.hostname,
    port: config.port,
    development: false,
    // Runtime-level failures answer with the same status, body shape, cache
    // policy, and security headers as every other response from `handleRequest`.
    error(): Response {
      return requestFailedResponse();
    },
    fetch(request: Request): Response | Promise<Response> {
      return handleRequest(request, env);
    },
  });

  const displayHost = config.hostname.includes(":")
    ? `[${config.hostname}]`
    : config.hostname;
  return {
    config,
    url: `http://${displayHost}:${server.port}`,
    stop(): void {
      server.stop(true);
    },
  };
}

if (import.meta.main) {
  const server = startVpsServer();
  console.log(`cbk-edge VPS adapter listening on ${server.url}`);
}

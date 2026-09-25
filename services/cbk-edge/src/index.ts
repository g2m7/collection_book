import {
  parseReferralCode,
  publicOrigin,
  referralCookieName,
  telemetryBatchPath,
  telemetryMaxCompressedBytes,
  telemetryMaxEventsPerBatch,
  type AnalyticsEngineBinding,
} from "@collection-book/contracts";

import { renderLandingPage } from "./landing";
import { renderPrivacyPage } from "./privacy";
import {
  readTelemetryJson,
  telemetryBatchError,
  validateTelemetryBatch,
} from "./telemetry";

const serviceName = "cbk-edge";
const serviceVersion = "0.1.0";
const referralCookieMaxAge = 60 * 60 * 24 * 30;

export interface WorkerEnv {
  PLAY_STORE_URL?: string;
  ANDROID_SHA256_CERT_FINGERPRINT?: string;
  TELEMETRY?: AnalyticsEngineBinding;
}

export interface Worker {
  fetch(request: Request, env: WorkerEnv): Response | Promise<Response>;
}

const contentSecurityPolicy = [
  "default-src 'none'",
  "style-src 'unsafe-inline'",
  "img-src data:",
  "script-src 'none'",
  "connect-src 'none'",
  "font-src 'none'",
  "object-src 'none'",
  "base-uri 'none'",
  "form-action 'none'",
  "frame-ancestors 'none'",
  "upgrade-insecure-requests",
].join("; ");

function withSecurityHeaders(response: Response): Response {
  const headers = new Headers(response.headers);
  headers.set("Content-Security-Policy", contentSecurityPolicy);
  headers.set("Permissions-Policy", "camera=(), geolocation=(), microphone=()");
  headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
  headers.set(
    "Strict-Transport-Security",
    "max-age=31536000; includeSubDomains",
  );
  headers.set("X-Content-Type-Options", "nosniff");
  headers.set("X-Frame-Options", "DENY");
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

function jsonResponse(
  body: unknown,
  status: number,
  cacheControl: string,
  extraHeaders: Readonly<Record<string, string>> = {},
): Response {
  const headers = new Headers({
    "Cache-Control": cacheControl,
    "Content-Type": "application/json; charset=utf-8",
    ...extraHeaders,
  });
  return withSecurityHeaders(
    new Response(JSON.stringify(body), { status, headers }),
  );
}

function normalizeFingerprint(value: string | undefined): string | null {
  if (value === undefined) return null;
  const trimmed = value.trim();
  const compact = trimmed.replaceAll(":", "");
  if (!/^[0-9a-f]{64}$/iu.test(compact)) return null;
  if (
    trimmed.includes(":") &&
    !/^(?:[0-9a-f]{2}:){31}[0-9a-f]{2}$/iu.test(trimmed)
  ) {
    return null;
  }
  return compact.toUpperCase().match(/.{2}/gu)?.join(":") ?? null;
}

function methodNotAllowed(allow: "GET" | "POST" = "GET"): Response {
  return jsonResponse({ error: "method_not_allowed" }, 405, "no-store", {
    Allow: allow,
  });
}

function notFound(): Response {
  return jsonResponse({ error: "not_found" }, 404, "no-store");
}

/**
 * Shared answer for a runtime-level failure, so a runtime that cannot reach the
 * routing code (the Bun adapter's `Bun.serve` error hook) still returns the
 * same status, body shape, cache policy, and security headers as every response
 * built by {@link handleRequest}.
 */
export function requestFailedResponse(): Response {
  return jsonResponse({ error: "request_failed" }, 500, "no-store");
}

const htmlCacheControl = "public, max-age=300, stale-while-revalidate=60";

function htmlResponse(html: string, cacheControl: string): Response {
  return withSecurityHeaders(
    new Response(html, {
      headers: {
        "Cache-Control": cacheControl,
        "Content-Type": "text/html; charset=utf-8",
      },
    }),
  );
}

function landingResponse(url: URL, env: WorkerEnv): Response {
  const html = renderLandingPage(
    url.searchParams.get("ref"),
    env.PLAY_STORE_URL,
  );
  return htmlResponse(html, htmlCacheControl);
}

export async function handleRequest(
  request: Request,
  env: WorkerEnv = {},
): Promise<Response> {
  const url = new URL(request.url);

  if (url.pathname === telemetryBatchPath) {
    if (request.method !== "POST") return methodNotAllowed("POST");
    const contentType = request.headers
      .get("Content-Type")
      ?.split(";", 1)[0]
      ?.trim()
      .toLowerCase();
    if (contentType !== "application/json") {
      return jsonResponse({ error: "content_type_required" }, 415, "no-store");
    }
    if (
      request.headers.get("Content-Encoding")?.trim().toLowerCase() !== "gzip"
    ) {
      return jsonResponse({ error: "gzip_required" }, 415, "no-store");
    }
    const contentLength = Number(request.headers.get("Content-Length"));
    if (
      Number.isFinite(contentLength) &&
      contentLength > telemetryMaxCompressedBytes
    ) {
      return jsonResponse(
        { error: "compressed_body_too_large" },
        413,
        "no-store",
      );
    }
    const read = await readTelemetryJson(request);
    if ("error" in read) {
      return jsonResponse(
        { error: telemetryBatchError(read.error) },
        read.error === "decompressed" ? 413 : 400,
        "no-store",
      );
    }
    if (
      Array.isArray(read.json) &&
      read.json.length > telemetryMaxEventsPerBatch
    ) {
      return jsonResponse({ error: "too_many_events" }, 413, "no-store");
    }
    const batch = validateTelemetryBatch(read.json);
    if (batch === null) {
      return jsonResponse({ error: "invalid_telemetry" }, 400, "no-store");
    }
    if (batch.events.length > telemetryMaxEventsPerBatch) {
      return jsonResponse({ error: "too_many_events" }, 413, "no-store");
    }
    if (env.TELEMETRY === undefined) {
      return jsonResponse({ error: "telemetry_unavailable" }, 503, "no-store", {
        "Retry-After": "60",
      });
    }
    try {
      for (const event of batch.events) {
        env.TELEMETRY.writeDataPoint({
          indexes: [batch.client_id],
          doubles: [event.timestamp],
          blobs: [event.event_name, event.id, JSON.stringify(event.properties)],
        });
      }
    } catch {
      return jsonResponse({ error: "telemetry_unavailable" }, 503, "no-store", {
        "Retry-After": "60",
      });
    }
    return jsonResponse(
      { accepted_event_ids: batch.events.map((event) => event.id) },
      200,
      "no-store",
    );
  }

  if (request.method !== "GET") return methodNotAllowed();

  if (url.pathname === "/health") {
    return jsonResponse(
      { service: serviceName, status: "ok", version: serviceVersion },
      200,
      "no-store",
    );
  }

  // `/import` is the public App Link target. Until Digital Asset Links are
  // verified, a dismissed chooser, an incomplete association, or any
  // non-Android client must still reach a safe, cacheable Play handoff instead
  // of a JSON 404.
  if (url.pathname === "/" || url.pathname === "/import") {
    return landingResponse(url, env);
  }

  // `/privacy` is the canonical privacy URL; the trailing-slash form redirects
  // permanently instead of serving a second copy of the same policy.
  if (url.pathname === "/privacy") {
    return htmlResponse(renderPrivacyPage(), htmlCacheControl);
  }

  if (url.pathname === "/privacy/") {
    return withSecurityHeaders(
      new Response(null, {
        status: 308,
        headers: {
          "Cache-Control": "public, max-age=300",
          Location: "/privacy",
        },
      }),
    );
  }

  if (url.pathname === "/.well-known/assetlinks.json") {
    const fingerprint = normalizeFingerprint(
      env.ANDROID_SHA256_CERT_FINGERPRINT,
    );
    const body =
      fingerprint === null
        ? []
        : [
            {
              relation: ["delegate_permission/common.handle_all_urls"],
              target: {
                namespace: "android_app",
                package_name: "com.sarbaa.cbk",
                sha256_cert_fingerprints: [fingerprint],
              },
            },
          ];
    return jsonResponse(
      body,
      200,
      fingerprint === null ? "no-store" : "public, max-age=3600",
    );
  }

  if (url.pathname.startsWith("/r/")) {
    const code = parseReferralCode(url.pathname.slice(3));
    if (code === null) return notFound();

    const requestId = crypto.randomUUID();
    const timestamp = new Date().toISOString();
    console.log(
      JSON.stringify({
        event: "referral_click",
        code,
        requestId,
        timestamp,
      }),
    );

    const cookie = [
      `${referralCookieName}=${code}`,
      `Max-Age=${referralCookieMaxAge}`,
      "Path=/",
      "Secure",
      "HttpOnly",
      "SameSite=Lax",
    ].join("; ");
    return withSecurityHeaders(
      new Response(null, {
        status: 302,
        headers: {
          "Cache-Control": "no-store",
          Location: `${publicOrigin}/?ref=${code}`,
          "Set-Cookie": cookie,
          "X-Request-Id": requestId,
        },
      }),
    );
  }

  return notFound();
}

const worker: Worker = {
  fetch: (request, env) => handleRequest(request, env),
};

export default worker;

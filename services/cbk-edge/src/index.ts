import {
  parseReferralCode,
  publicOrigin,
  referralCookieName,
} from "@collection-book/contracts";

import { renderLandingPage } from "./landing";

const serviceName = "cbk-edge";
const serviceVersion = "0.1.0";
const referralCookieMaxAge = 60 * 60 * 24 * 30;

export interface WorkerEnv {
  PLAY_STORE_URL?: string;
  ANDROID_SHA256_CERT_FINGERPRINT?: string;
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

function methodNotAllowed(): Response {
  return jsonResponse({ error: "method_not_allowed" }, 405, "no-store", {
    Allow: "GET",
  });
}

function notFound(): Response {
  return jsonResponse({ error: "not_found" }, 404, "no-store");
}

export function handleRequest(request: Request, env: WorkerEnv = {}): Response {
  if (request.method !== "GET") return methodNotAllowed();

  const url = new URL(request.url);

  if (url.pathname === "/health") {
    return jsonResponse(
      { service: serviceName, status: "ok", version: serviceVersion },
      200,
      "no-store",
    );
  }

  if (url.pathname === "/") {
    const html = renderLandingPage(
      url.searchParams.get("ref"),
      env.PLAY_STORE_URL,
    );
    return withSecurityHeaders(
      new Response(html, {
        headers: {
          "Cache-Control": "public, max-age=300, stale-while-revalidate=60",
          "Content-Type": "text/html; charset=utf-8",
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
  fetch: handleRequest,
};

export default worker;

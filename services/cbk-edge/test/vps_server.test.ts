import { afterAll, beforeAll, describe, expect, test } from "bun:test";

import { startVpsServer, type VpsServerHandle } from "../src/vps_server";

let server: VpsServerHandle;
let base: string;
let logs: string[] = [];

beforeAll(() => {
  const originalLog = console.log;
  logs = [];
  console.log = (...values: unknown[]) => {
    logs.push(values.map(String).join(" "));
  };
  server = startVpsServer({ CBK_EDGE_PORT: "0" });
  base = server.url;
  console.log = originalLog;
});

afterAll(() => {
  server.stop();
});

describe("bun vps adapter", () => {
  test("binds loopback and reports a real port", () => {
    expect(server.config.hostname).toBe("127.0.0.1");
    expect(server.config.telemetryEnabled).toBe(false);
    expect(server.url).toMatch(/^http:\/\/127\.0\.0\.1:\d+$/u);
    expect(server.url).not.toContain(":0");
  });

  test("serves health over HTTP with the same JSON body", async () => {
    const response = await fetch(`${base}/health`);

    expect(response.status).toBe(200);
    expect(response.headers.get("Content-Security-Policy")).toContain(
      "script-src 'none'",
    );
    expect(await response.json()).toEqual({
      service: "cbk-edge",
      status: "ok",
      version: "0.1.0",
    });
  });

  test("serves the landing page with the honest no-listing state", async () => {
    const response = await fetch(`${base}/`);
    const html = await response.text();

    expect(response.status).toBe(200);
    expect(response.headers.get("Content-Type")).toContain("text/html");
    expect(html).toContain("Google Play release in progress");
    expect(html).not.toContain("play.google.com");
  });

  test("serves the privacy policy and its trailing-slash redirect", async () => {
    const policy = await fetch(`${base}/privacy`);
    const redirect = await fetch(`${base}/privacy/`, { redirect: "manual" });

    expect(policy.status).toBe(200);
    expect(await policy.text()).toContain("<h1>Privacy policy</h1>");
    expect(redirect.status).toBe(308);
    expect(redirect.headers.get("Location")).toBe("/privacy");
  });

  test("keeps referral redirect, cookie, and minimal logging", async () => {
    logs = [];
    const originalLog = console.log;
    console.log = (...values: unknown[]) => {
      logs.push(values.map(String).join(" "));
    };
    const response = await fetch(`${base}/r/AB12CD`, { redirect: "manual" });
    console.log = originalLog;

    expect(response.status).toBe(302);
    expect(response.headers.get("Location")).toBe(
      "https://cbk.sarbaa.com/?ref=AB12CD",
    );
    expect(response.headers.get("Set-Cookie")).toContain("cbk_referral=AB12CD");
    expect(logs).toHaveLength(1);
    expect(JSON.parse(logs[0] ?? "{}")).toEqual({
      event: "referral_click",
      code: "AB12CD",
      requestId: response.headers.get("X-Request-Id"),
      timestamp: expect.any(String),
    });
  });

  test("answers bounded 404 and 405 responses", async () => {
    const missing = await fetch(`${base}/no-such-route`);
    const wrongMethod = await fetch(`${base}/`, { method: "POST" });
    const invalidReferral = await fetch(`${base}/r/AB12C`);

    expect(missing.status).toBe(404);
    expect(await missing.text()).toBe('{"error":"not_found"}');
    expect(wrongMethod.status).toBe(405);
    expect(wrongMethod.headers.get("Allow")).toBe("GET");
    expect(invalidReferral.status).toBe(404);
  });

  test("answers 503 for telemetry and never writes request metadata", async () => {
    logs = [];
    const originalLog = console.log;
    console.log = (...values: unknown[]) => {
      logs.push(values.map(String).join(" "));
    };
    const response = await fetch(`${base}/api/v1/telemetry/batch`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Encoding": "gzip",
        "User-Agent": "must-not-be-logged",
      },
      body: Bun.gzipSync(
        new TextEncoder().encode(
          JSON.stringify({
            client_id: `anon_${"0".repeat(32)}`,
            events: [
              {
                id: "1".repeat(32),
                event_name: "app_first_open",
                timestamp: 1_760_000_000_000,
                properties: {},
              },
            ],
          }),
        ),
      ),
    });
    console.log = originalLog;

    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: "telemetry_unavailable" });
    expect(logs).toEqual([]);
  });
});

describe("bun vps adapter environment wiring", () => {
  const fingerprint =
    "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:" +
    "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99";

  test("serves empty asset links when no fingerprint is configured", async () => {
    const response = await fetch(`${base}/.well-known/assetlinks.json`);

    expect(response.status).toBe(200);
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(await response.json()).toEqual([]);
  });

  test("serves the configured fingerprint and ignores an invalid one", async () => {
    const configured = startVpsServer({
      CBK_EDGE_PORT: "0",
      ANDROID_SHA256_CERT_FINGERPRINT: fingerprint,
    });
    const invalid = startVpsServer({
      CBK_EDGE_PORT: "0",
      ANDROID_SHA256_CERT_FINGERPRINT:
        "REPLACE_WITH_REAL_SHA256_CERT_FINGERPRINT",
    });

    try {
      expect(
        await (
          await fetch(`${configured.url}/.well-known/assetlinks.json`)
        ).json(),
      ).toEqual([
        {
          relation: ["delegate_permission/common.handle_all_urls"],
          target: {
            namespace: "android_app",
            package_name: "com.sarbaa.cbk",
            sha256_cert_fingerprints: [fingerprint],
          },
        },
      ]);
      expect(
        await (
          await fetch(`${invalid.url}/.well-known/assetlinks.json`)
        ).json(),
      ).toEqual([]);
    } finally {
      configured.stop();
      invalid.stop();
    }
  });
});

import { afterEach, describe, expect, spyOn, test } from "bun:test";

import { handleRequest, type WorkerEnv } from "../src/index";
import { buildPlayStoreUrl, escapeHtml } from "../src/landing";

const fingerprint =
  "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:" +
  "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99";

const originalLog = console.log;
afterEach(() => {
  console.log = originalLog;
});

describe("cbk-edge routes", () => {
  test("health returns only bounded service metadata", async () => {
    const response = await handleRequest(
      new Request("https://cbk.sarbaa.com/health"),
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("Content-Type")).toContain("application/json");
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(await response.json()).toEqual({
      service: "cbk-edge",
      status: "ok",
      version: "0.1.0",
    });
  });

  test("landing is self-contained, semantic, accessible, and secure", async () => {
    const response = await handleRequest(
      new Request("https://cbk.sarbaa.com/"),
    );
    const html = await response.text();

    expect(response.status).toBe(200);
    expect(response.headers.get("Content-Type")).toContain("text/html");
    expect(response.headers.get("Cache-Control")).toContain("max-age=300");
    expect(html).toContain('<main id="main">');
    expect(html).toContain("<h1");
    expect(html).toContain('rel="canonical"');
    expect(html).toContain('href="https://cbk.sarbaa.com/"');
    expect(html).toContain("prefers-reduced-motion:reduce");
    expect(html).toContain(":focus-visible");
    expect(html).toContain(
      "https://play.google.com/store/apps/details?id=com.sarbaa.cbk",
    );
    expect(html).not.toContain("<script");
    expect(html).not.toContain("http://");
  });

  test("landing preserves a valid referral in the Google Play referrer", async () => {
    const response = await handleRequest(
      new Request("https://cbk.sarbaa.com/?ref=AB12CD"),
    );
    const html = await response.text();
    const href = html.match(/class="button" href="([^"]+)"/u)?.[1];

    expect(href).toBeDefined();
    const downloadUrl = new URL(href!.replaceAll("&amp;", "&"));
    expect(downloadUrl.origin).toBe("https://play.google.com");
    expect(downloadUrl.searchParams.get("id")).toBe("com.sarbaa.cbk");
    expect(downloadUrl.searchParams.get("referrer")).toBe(
      "utm_source=cbk_edge&utm_medium=referral&utm_campaign=AB12CD",
    );
    expect(html).toContain("Referral <strong>AB12CD</strong> is ready");
  });

  test.each([
    "https://evil.example/store/apps/details?id=com.sarbaa.cbk",
    "https://play.google.com.evil.example/store/apps/details?id=com.sarbaa.cbk",
    "https://play.google.com/not-an-app-listing?id=com.sarbaa.cbk",
  ])("rejects unsafe PLAY_STORE_URL %s", (configuredUrl) => {
    const downloadUrl = new URL(buildPlayStoreUrl(configuredUrl, null));

    expect(downloadUrl.origin).toBe("https://play.google.com");
    expect(downloadUrl.pathname).toBe("/store/apps/details");
    expect(downloadUrl.searchParams.get("id")).toBe("com.sarbaa.cbk");
  });

  test("accepts an HTTPS Google Play listing and forces the package ID", () => {
    const downloadUrl = new URL(
      buildPlayStoreUrl(
        "https://play.google.com/store/apps/details?hl=en&gl=IN",
        null,
      ),
    );

    expect(downloadUrl.origin).toBe("https://play.google.com");
    expect(downloadUrl.pathname).toBe("/store/apps/details");
    expect(downloadUrl.searchParams.get("hl")).toBe("en");
    expect(downloadUrl.searchParams.get("id")).toBe("com.sarbaa.cbk");
  });

  test("HTML escaping neutralizes markup delimiters", () => {
    expect(escapeHtml(`<a href="x">&'`)).toBe(
      "&lt;a href=&quot;x&quot;&gt;&amp;&#39;",
    );
  });

  test("landing escapes hostile query and configuration input", async () => {
    const env: WorkerEnv = {
      PLAY_STORE_URL: 'javascript:alert("injection")',
    };
    const response = await handleRequest(
      new Request(
        "https://cbk.sarbaa.com/?ref=%3Cscript%3Ealert(1)%3C%2Fscript%3E",
        { headers: { "User-Agent": "must-not-be-logged" } },
      ),
      env,
    );
    const html = await response.text();

    expect(html).not.toContain("<script>alert(1)");
    expect(html).not.toContain("javascript:alert");
    expect(html).toContain("id=com.sarbaa.cbk");
    expect(html).not.toContain("Referral <strong>");
  });

  test("valid referral redirects, sets a secure cookie, and emits minimal log", async () => {
    const logs: unknown[][] = [];
    console.log = (...values: unknown[]) => {
      logs.push(values);
    };

    const response = await handleRequest(
      new Request("https://cbk.sarbaa.com/r/AB12CD?source=receipt"),
    );
    const setCookie = response.headers.get("Set-Cookie") ?? "";

    expect(response.status).toBe(302);
    expect(response.headers.get("Location")).toBe(
      "https://cbk.sarbaa.com/?ref=AB12CD",
    );
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(response.headers.get("X-Request-Id")).toMatch(/^[0-9a-f-]{36}$/u);
    expect(setCookie).toContain("cbk_referral=AB12CD");
    expect(setCookie).toContain("Path=/");
    expect(setCookie).toContain("Secure");
    expect(setCookie).toContain("HttpOnly");
    expect(setCookie).toContain("SameSite=Lax");
    expect(logs).toHaveLength(1);
    expect(logs[0]).toHaveLength(1);

    const event = JSON.parse(String(logs[0]?.[0])) as Record<string, unknown>;
    expect(Object.keys(event).sort()).toEqual([
      "code",
      "event",
      "requestId",
      "timestamp",
    ]);
    expect(event.event).toBe("referral_click");
    expect(event.code).toBe("AB12CD");
    expect(event.requestId).toBe(response.headers.get("X-Request-Id"));
    expect(String(event.timestamp)).toMatch(/^\d{4}-/u);
    expect(JSON.stringify(event)).not.toContain("source=receipt");
  });

  test.each(["ABC123", "I0O1IL", "ZZZZZZ"])(
    "accepts uppercase alphanumeric code %s",
    async (code) => {
      console.log = spyOn(console, "log").mockImplementation(() => undefined);
      const response = await handleRequest(
        new Request(`https://cbk.sarbaa.com/r/${code}`),
      );

      expect(response.status).toBe(302);
      expect(console.log).toHaveBeenCalledTimes(1);
    },
  );

  test.each(["ABC12", "ABC1234", "abc123", "../bad", "ABC%0D", "ABC%2F123"])(
    "rejects invalid referral %s without logging or a cookie",
    async (code) => {
      const logs: unknown[][] = [];
      console.log = (...values: unknown[]) => {
        logs.push(values);
      };

      const response = await handleRequest(
        new Request(`https://cbk.sarbaa.com/r/${code}`),
      );

      expect(response.status).toBe(404);
      expect(response.headers.get("Set-Cookie")).toBeNull();
      expect(logs).toHaveLength(0);
    },
  );

  test("/import serves the same secure landing fallback as /", async () => {
    const logs: unknown[][] = [];
    console.log = (...values: unknown[]) => {
      logs.push(values);
    };

    const [root, importRoute] = await Promise.all([
      handleRequest(new Request("https://cbk.sarbaa.com/")),
      handleRequest(new Request("https://cbk.sarbaa.com/import?source=reel")),
    ]);
    const html = await importRoute.text();

    expect(importRoute.status).toBe(200);
    expect(importRoute.headers.get("Content-Type")).toContain("text/html");
    expect(importRoute.headers.get("Cache-Control")).toBe(
      "public, max-age=300, stale-while-revalidate=60",
    );
    expect(importRoute.headers.get("Set-Cookie")).toBeNull();
    expect(importRoute.headers.get("Location")).toBeNull();
    expect(importRoute.headers.get("Content-Security-Policy")).toContain(
      "default-src 'none'",
    );
    expect(importRoute.headers.get("X-Content-Type-Options")).toBe("nosniff");
    expect(importRoute.headers.get("X-Frame-Options")).toBe("DENY");
    expect(html).toBe(await root.text());
    expect(html).toContain(
      "https://play.google.com/store/apps/details?id=com.sarbaa.cbk",
    );
    expect(html).not.toContain("<script");
    expect(logs).toHaveLength(0);
  });

  test("/import rejects unsupported methods and stays bounded to one path", async () => {
    console.log = () => undefined;

    for (const method of ["POST", "PUT", "DELETE", "HEAD"]) {
      const response = await handleRequest(
        new Request("https://cbk.sarbaa.com/import", { method }),
      );
      expect(response.status).toBe(405);
      expect(response.headers.get("Allow")).toBe("GET");
    }

    for (const path of ["/import/", "/imports", "/import/extra"]) {
      const response = await handleRequest(
        new Request(`https://cbk.sarbaa.com${path}`),
      );
      expect(response.status).toBe(404);
      expect(await response.text()).toBe('{"error":"not_found"}');
    }
  });

  test("unknown paths return bounded 404 responses", async () => {
    const response = await handleRequest(
      new Request("https://cbk.sarbaa.com/not-a-route"),
    );

    expect(response.status).toBe(404);
    expect(await response.text()).toBe('{"error":"not_found"}');
  });

  test("unsupported methods return 405 with GET allowed", async () => {
    for (const method of ["POST", "PUT", "DELETE", "HEAD"]) {
      const response = await handleRequest(
        new Request("https://cbk.sarbaa.com/", { method }),
      );
      expect(response.status).toBe(405);
      expect(response.headers.get("Allow")).toBe("GET");
    }
  });

  test("assetlinks is empty without a real configured fingerprint", async () => {
    for (const env of [
      {},
      { ANDROID_SHA256_CERT_FINGERPRINT: "" },
      { ANDROID_SHA256_CERT_FINGERPRINT: "not-a-fingerprint" },
    ] satisfies WorkerEnv[]) {
      const response = await handleRequest(
        new Request("https://cbk.sarbaa.com/.well-known/assetlinks.json"),
        env,
      );
      expect(response.headers.get("Cache-Control")).toBe("no-store");
      expect(await response.json()).toEqual([]);
    }
  });

  test("assetlinks contains the package and only a valid configured SHA-256", async () => {
    const response = await handleRequest(
      new Request("https://cbk.sarbaa.com/.well-known/assetlinks.json"),
      { ANDROID_SHA256_CERT_FINGERPRINT: fingerprint },
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("Cache-Control")).toContain("max-age=3600");
    expect(await response.json()).toEqual([
      {
        relation: ["delegate_permission/common.handle_all_urls"],
        target: {
          namespace: "android_app",
          package_name: "com.sarbaa.cbk",
          sha256_cert_fingerprints: [fingerprint],
        },
      },
    ]);
  });

  test("security headers apply to every response class", async () => {
    console.log = () => undefined;
    const responses = await Promise.all([
      handleRequest(new Request("https://cbk.sarbaa.com/")),
      handleRequest(new Request("https://cbk.sarbaa.com/r/AB12CD")),
      handleRequest(new Request("https://cbk.sarbaa.com/missing")),
      handleRequest(new Request("https://cbk.sarbaa.com/", { method: "POST" })),
    ]);

    for (const response of responses) {
      expect(response.headers.get("Content-Security-Policy")).toContain(
        "default-src 'none'",
      );
      expect(response.headers.get("Content-Security-Policy")).toContain(
        "script-src 'none'",
      );
      expect(response.headers.get("X-Content-Type-Options")).toBe("nosniff");
      expect(response.headers.get("X-Frame-Options")).toBe("DENY");
      expect(response.headers.get("Referrer-Policy")).toBe(
        "strict-origin-when-cross-origin",
      );
    }
  });
});

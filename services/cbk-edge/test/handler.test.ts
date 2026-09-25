import { afterEach, describe, expect, spyOn, test } from "bun:test";
import { findUnsupportedClaims } from "@collection-book/contracts";

import {
  handleRequest,
  requestFailedResponse,
  type WorkerEnv,
} from "../src/index";
import { resolvePlayStoreUrl } from "../src/landing";
import { escapeHtml } from "../src/page";
import { renderPrivacyPage } from "../src/privacy";
import { htmlToText } from "./support/html_text";

const fingerprint =
  "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:" +
  "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99";

const validPlayStoreUrl =
  "https://play.google.com/store/apps/details?id=com.sarbaa.cbk";

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

  test("telemetry ingestion is 503 while no analytics storage is bound", async () => {
    const batch = {
      client_id: `anon_${"0".repeat(32)}`,
      events: [
        {
          id: "1".repeat(32),
          event_name: "app_first_open",
          timestamp: 1_760_000_000_000,
          properties: {},
        },
      ],
    };
    const response = await handleRequest(
      new Request("https://cbk.sarbaa.com/api/v1/telemetry/batch", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Encoding": "gzip",
        },
        body: Bun.gzipSync(new TextEncoder().encode(JSON.stringify(batch))),
      }),
    );

    expect(response.status).toBe(503);
    expect(response.headers.get("Retry-After")).toBe("60");
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(await response.json()).toEqual({ error: "telemetry_unavailable" });
  });

  test("a runtime failure uses the shared bounded 500 response", () => {
    const response = requestFailedResponse();

    expect(response.status).toBe(500);
    expect(response.headers.get("Content-Type")).toContain("application/json");
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(response.headers.get("Content-Security-Policy")).toContain(
      "script-src 'none'",
    );
    expect(response.headers.get("X-Frame-Options")).toBe("DENY");
    expect(response.headers.get("X-Content-Type-Options")).toBe("nosniff");
  });
});

describe("landing page", () => {
  test("is self-contained, semantic, accessible, and secure", async () => {
    const response = await handleRequest(
      new Request("https://cbk.sarbaa.com/"),
    );
    const html = await response.text();

    expect(response.status).toBe(200);
    expect(response.headers.get("Content-Type")).toContain("text/html");
    expect(response.headers.get("Cache-Control")).toBe(
      "public, max-age=300, stale-while-revalidate=60",
    );
    expect(html).toContain('<main id="main">');
    expect(html).toContain('<a class="skip-link" href="#main">');
    expect(html).toContain("<h1");
    expect(html).toContain('rel="canonical"');
    expect(html).toContain('href="https://cbk.sarbaa.com/"');
    expect(html).toContain("prefers-reduced-motion: reduce");
    expect(html).toContain(":focus-visible");
    expect(html).toContain("touch-action: manipulation");
    expect(html).toContain("text-wrap: balance");
    expect(html).toContain("text-wrap: pretty");
    expect(html).toContain("env(safe-area-inset-left)");
    expect(html).toContain("viewport-fit=cover");
    expect(html).toContain("--tap: 48px");
    expect(html).not.toContain("transition: all");
    expect(html).not.toContain("<script");
    expect(html).not.toContain('<link rel="stylesheet"');
    expect(html).not.toContain("@import");
    expect(html).not.toContain("http://");
  });

  test("uses semantic, labelled sections in a single h1 hierarchy", async () => {
    const html = await (
      await handleRequest(new Request("https://cbk.sarbaa.com/"))
    ).text();
    const copy = htmlToText(html);

    expect(html.match(/<h1[ >]/gu)).toHaveLength(1);
    for (const id of [
      "outcomes-title",
      "how-title",
      "capabilities-title",
      "trust-title",
      "faq-title",
      "availability-title",
    ]) {
      expect(html).toContain(`id="${id}"`);
      expect(html).toContain(`aria-labelledby="${id}"`);
    }
    expect(copy).toContain("Cable TV and fiber, separated");
    expect(copy).toContain("Offline-first database");
    expect(copy).toContain("Local backup and restore");
    expect(copy).toContain("Multilingual receipts");
  });

  test("offers no download call to action until a Play listing is configured", async () => {
    for (const env of [
      {},
      { PLAY_STORE_URL: "" },
      { PLAY_STORE_URL: "   " },
      { PLAY_STORE_URL: 'javascript:alert("injection")' },
      {
        PLAY_STORE_URL:
          "https://play.google.com.evil.example/store/apps/details",
      },
      { PLAY_STORE_URL: "http://play.google.com/store/apps/details" },
      { PLAY_STORE_URL: "https://play.google.com/store/listing?id=x" },
    ] satisfies WorkerEnv[]) {
      const response = await handleRequest(
        new Request("https://cbk.sarbaa.com/?ref=AB12CD"),
        env,
      );
      const html = await response.text();

      expect(response.status).toBe(200);
      expect(html).toContain("Google Play release in progress");
      expect(html).not.toContain("play.google.com");
      expect(html).not.toContain("id=com.sarbaa.cbk");
      expect(html).not.toContain("Referral <strong>");
      expect(html).not.toContain("Get Collection Book on Google Play");
    }
  });

  test("links the Play listing and carries a referral when one is configured", async () => {
    const response = await handleRequest(
      new Request("https://cbk.sarbaa.com/?ref=AB12CD"),
      { PLAY_STORE_URL: validPlayStoreUrl },
    );
    const html = await response.text();
    const href = html.match(/class="button" href="([^"]+)"/u)?.[1];

    expect(href).toBeDefined();
    const downloadUrl = new URL(href!.replaceAll("&amp;", "&"));
    expect(downloadUrl.origin).toBe("https://play.google.com");
    expect(downloadUrl.pathname).toBe("/store/apps/details");
    expect(downloadUrl.searchParams.get("id")).toBe("com.sarbaa.cbk");
    expect(downloadUrl.searchParams.get("referrer")).toBe(
      "utm_source=cbk_edge&utm_medium=referral&utm_campaign=AB12CD",
    );
    expect(html).toContain("Referral <strong>AB12CD</strong> is carried");
    expect(html).not.toContain("Google Play release in progress");
  });

  test("keeps a configured listing usable when no referral is present", async () => {
    const html = await (
      await handleRequest(new Request("https://cbk.sarbaa.com/"), {
        PLAY_STORE_URL: validPlayStoreUrl,
      })
    ).text();

    expect(html).toContain("Get Collection Book on Google Play");
    expect(html).not.toContain("utm_campaign");
  });

  test("links the privacy policy from the header and the footer", async () => {
    const html = await (
      await handleRequest(new Request("https://cbk.sarbaa.com/"))
    ).text();

    expect(html).toContain('href="/privacy"');
    expect(html).toContain("Read the privacy policy");
    expect(html).toContain("https://sarbaa.com");
    expect(html).toContain("tel:+918972146130");
  });

  test("marks static notes without a live-region role", async () => {
    const configured = await handleRequest(
      new Request("https://cbk.sarbaa.com/?ref=AB12CD"),
      { PLAY_STORE_URL: validPlayStoreUrl },
    );
    const unconfigured = await handleRequest(
      new Request("https://cbk.sarbaa.com/"),
    );

    // The release-in-progress panel and the referral note are static server
    // rendered content, so a live-region role would only add noise.
    for (const page of [configured, unconfigured]) {
      const html = await page.text();

      expect(html).toContain('role="note"');
      expect(html).not.toContain('role="status"');
      expect(html).not.toContain("aria-live");
    }
  });

  test("discloses the wa.me browser fallback on the landing page", async () => {
    const copy = htmlToText(
      await (
        await handleRequest(new Request("https://cbk.sarbaa.com/"))
      ).text(),
    );

    expect(copy).not.toContain("installed app only");
    expect(copy).toContain("wa.me");
    expect(copy).toContain("your browser");
    expect(copy).toContain("including the customer name and payment details");
  });
});

describe("play store url resolution", () => {
  test.each([
    undefined,
    "",
    "   ",
    "not a url",
    'javascript:alert("injection")',
    "http://play.google.com/store/apps/details",
    "https://play.google.com.evil.example/store/apps/details?id=com.sarbaa.cbk",
    "https://play.google.com/not-an-app-listing?id=com.sarbaa.cbk",
    "https://user:pass@play.google.com/store/apps/details",
    "https://play.google.com:8443/store/apps/details",
  ])("refuses %s instead of falling back to a broken link", (configuredUrl) => {
    expect(resolvePlayStoreUrl(configuredUrl, null)).toBeNull();
  });

  test("accepts an HTTPS Google Play listing and forces the package ID", () => {
    const downloadUrl = new URL(
      resolvePlayStoreUrl(
        "https://play.google.com/store/apps/details?hl=en&gl=IN",
        null,
      )!,
    );

    expect(downloadUrl.origin).toBe("https://play.google.com");
    expect(downloadUrl.pathname).toBe("/store/apps/details");
    expect(downloadUrl.searchParams.get("hl")).toBe("en");
    expect(downloadUrl.searchParams.get("id")).toBe("com.sarbaa.cbk");
  });

  test("ignores an invalid referral code even with a valid listing", () => {
    const resolved = resolvePlayStoreUrl(validPlayStoreUrl, "bad-code");

    expect(resolved).not.toBeNull();
    expect(new URL(resolved!).searchParams.get("referrer")).toBeNull();
  });
});

describe("privacy policy", () => {
  test("serves a self-contained, cacheable policy with security headers", async () => {
    const response = await handleRequest(
      new Request("https://cbk.sarbaa.com/privacy"),
    );
    const html = await response.text();

    expect(response.status).toBe(200);
    expect(response.headers.get("Content-Type")).toContain("text/html");
    expect(response.headers.get("Cache-Control")).toBe(
      "public, max-age=300, stale-while-revalidate=60",
    );
    expect(response.headers.get("Content-Security-Policy")).toContain(
      "script-src 'none'",
    );
    expect(response.headers.get("X-Frame-Options")).toBe("DENY");
    expect(response.headers.get("Set-Cookie")).toBeNull();
    expect(html).toContain(
      'rel="canonical" href="https://cbk.sarbaa.com/privacy"',
    );
    expect(html).toContain("<h1>Privacy policy</h1>");
    expect(html).not.toContain("<script");
    expect(html).not.toContain("http://");
  });

  test("discloses the real data flow of the app and the site", async () => {
    const copy = htmlToText(renderPrivacyPage());

    expect(copy).toContain("Sarbani Associates");
    expect(copy).toContain("Bagdogra, Siliguri, West Bengal");
    expect(copy).toContain("https://sarbaa.com");
    expect(copy).toContain("+91 89721 46130");
    expect(copy).toContain("local SQLite database");
    expect(copy).toContain("only when you choose to");
    expect(copy).toContain(
      "hands it to the WhatsApp app installed on the phone",
    );
    expect(copy).toContain("falls back to wa.me");
    expect(copy).toContain("complete receipt text is placed in the link");
    expect(copy).toContain("WhatsApp's web service");
    expect(copy).toContain("operating-system backup disabled");
    expect(copy).toContain("random client identifier generated on the device");
    expect(copy).toContain("fixed allowlist");
    expect(copy).toContain(
      "only attempted while the device reports a Wi-Fi connection",
    );
    expect(copy).toContain("cbk.sarbaa.com");
    expect(copy).toContain("never contain subscriber names");
    expect(copy).toContain("30 days");
    expect(copy).toContain("HttpOnly");
    expect(copy).toContain("excludes IP addresses, user agents, cookies");
    expect(copy).toContain("ordinary network metadata");
    expect(copy).toContain(
      "removes the local register, the queued events, and the random client identifier",
    );
  });

  test("does not overpromise retention and invents no email address", () => {
    const html = renderPrivacyPage();

    expect(html).not.toContain("mailto:");
    expect(html).not.toContain("@sarbaa.com");
    expect(html).toContain("we do not publish a fixed deletion window here");
  });

  test("redirects the trailing-slash form to the canonical policy", async () => {
    const response = await handleRequest(
      new Request("https://cbk.sarbaa.com/privacy/"),
    );

    expect(response.status).toBe(308);
    expect(response.headers.get("Location")).toBe("/privacy");
    expect(response.headers.get("Cache-Control")).toBe("public, max-age=300");
    expect(response.headers.get("Set-Cookie")).toBeNull();
  });

  test("rejects unsupported methods and near-miss paths", async () => {
    for (const method of ["POST", "PUT", "DELETE", "HEAD"]) {
      const response = await handleRequest(
        new Request("https://cbk.sarbaa.com/privacy", { method }),
      );
      expect(response.status).toBe(405);
      expect(response.headers.get("Allow")).toBe("GET");
    }

    for (const path of ["/privacy/policy", "/privacy.html", "/Privacy"]) {
      const response = await handleRequest(
        new Request(`https://cbk.sarbaa.com${path}`),
      );
      expect(response.status).toBe(404);
      expect(await response.text()).toBe('{"error":"not_found"}');
    }
  });
});

describe("customer-facing claim enforcement", () => {
  test("the landing and privacy copy contain no unsupported claim", async () => {
    // Both landing variants are scanned: the configured listing renders extra
    // call-to-action copy that the default, unconfigured page never shows.
    const pages = await Promise.all([
      handleRequest(new Request("https://cbk.sarbaa.com/?ref=AB12CD")),
      handleRequest(new Request("https://cbk.sarbaa.com/?ref=AB12CD"), {
        PLAY_STORE_URL: validPlayStoreUrl,
      }),
      handleRequest(new Request("https://cbk.sarbaa.com/")),
      handleRequest(new Request("https://cbk.sarbaa.com/privacy")),
    ]);

    for (const page of pages) {
      expect(findUnsupportedClaims(htmlToText(await page.text()))).toEqual([]);
    }
  });

  test("the scan is live: an injected cap in landing copy would fail", async () => {
    const withInjectedCap =
      "Free for up to 100 subscribers, and free forever, with cloud sync across devices.";

    expect(
      findUnsupportedClaims(htmlToText(withInjectedCap)).map((hit) => hit.id),
    ).toEqual(
      expect.arrayContaining(["free-forever", "cloud-sync", "numeric-cap"]),
    );
  });
});

describe("referrals and errors", () => {
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
    expect(html).toContain("Google Play release in progress");
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
    expect(html).toContain("Google Play release in progress");
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
      handleRequest(new Request("https://cbk.sarbaa.com/privacy")),
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

import { describe, expect, test } from "bun:test";

import {
  defaultListenHostname,
  defaultListenPort,
  parseAndroidSha256CertFingerprint,
  parseListenHostname,
  parseListenPort,
  resolveVpsServerConfig,
} from "../src/vps_config";

describe("listen hostname parsing", () => {
  test("defaults to loopback and trims an explicit value", () => {
    expect(parseListenHostname(undefined)).toBe(defaultListenHostname);
    expect(parseListenHostname("  127.0.0.1 ")).toBe("127.0.0.1");
    expect(parseListenHostname("::1")).toBe("::1");
    expect(parseListenHostname("localhost")).toBe("localhost");
  });

  test.each([
    "",
    "   ",
    "-bad",
    ".hidden",
    "trailing.",
    "not a host",
    "http://127.0.0.1",
    "127.0.0.1/path",
    "a".repeat(256),
  ])("rejects %s", (value) => {
    expect(() => parseListenHostname(value)).toThrow("CBK_EDGE_HOST");
  });
});

describe("listen port parsing", () => {
  test("defaults and accepts the full valid range", () => {
    expect(parseListenPort(undefined)).toBe(defaultListenPort);
    expect(parseListenPort(" 8080 ")).toBe(8080);
    expect(parseListenPort("0")).toBe(0);
    expect(parseListenPort("65535")).toBe(65535);
  });

  test.each([
    "",
    "  ",
    "-1",
    "80.5",
    "65536",
    "99999",
    "http",
    "8080abc",
    "0x1f",
  ])("rejects %s", (value) => {
    expect(() => parseListenPort(value)).toThrow("CBK_EDGE_PORT");
  });
});

describe("server configuration", () => {
  test("reads the listen address and the optional Play listing from the environment", () => {
    expect(resolveVpsServerConfig({})).toEqual({
      hostname: defaultListenHostname,
      port: defaultListenPort,
      playStoreUrl: undefined,
      androidSha256CertFingerprint: undefined,
      telemetryEnabled: false,
    });

    expect(
      resolveVpsServerConfig({
        CBK_EDGE_HOST: "127.0.0.1",
        CBK_EDGE_PORT: "9000",
        PLAY_STORE_URL: " https://play.google.com/store/apps/details ",
      }),
    ).toEqual({
      hostname: "127.0.0.1",
      port: 9000,
      playStoreUrl: "https://play.google.com/store/apps/details",
      androidSha256CertFingerprint: undefined,
      telemetryEnabled: false,
    });
  });

  test("treats a blank Play listing as unconfigured", () => {
    expect(
      resolveVpsServerConfig({ PLAY_STORE_URL: "   " }).playStoreUrl,
    ).toBeUndefined();
  });
});

describe("signing fingerprint configuration", () => {
  test("passes a raw nonblank value through for the handler to validate", () => {
    const colonSeparated =
      "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:" +
      "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99";

    expect(parseAndroidSha256CertFingerprint(`  ${colonSeparated}  `)).toBe(
      colonSeparated,
    );
    expect(
      resolveVpsServerConfig({
        ANDROID_SHA256_CERT_FINGERPRINT: colonSeparated,
      }).androidSha256CertFingerprint,
    ).toBe(colonSeparated);
  });

  test("never defaults, invents, or keeps a blank fingerprint", () => {
    for (const value of [undefined, "", "   ", "\n"]) {
      expect(parseAndroidSha256CertFingerprint(value)).toBeUndefined();
      expect(
        resolveVpsServerConfig({
          ANDROID_SHA256_CERT_FINGERPRINT: value,
        }).androidSha256CertFingerprint,
      ).toBeUndefined();
    }
  });
});

import { describe, expect, test } from "bun:test";

import {
  androidPackageName,
  buildReferralUrl,
  isValidReferralCode,
  parseReferralCode,
  publicOrigin,
} from "../src/index";

describe("referral contracts", () => {
  test("accepts the six-character uppercase alphanumeric app contract", () => {
    expect(isValidReferralCode("AB12CD")).toBe(true);
    expect(parseReferralCode("123456")).toBe("123456");
    expect(buildReferralUrl("AB12CD")).toBe(`${publicOrigin}/r/AB12CD`);
  });

  test("rejects malformed, lowercase, and non-string values", () => {
    for (const value of [
      "AB12C",
      "AB12CDE",
      "ab12cd",
      "../bad",
      "",
      null,
      42,
    ]) {
      expect(isValidReferralCode(value)).toBe(false);
      expect(parseReferralCode(value)).toBeNull();
      expect(buildReferralUrl(value)).toBeNull();
    }
  });

  test("publishes the canonical Android package name", () => {
    expect(androidPackageName).toBe("com.sarbaa.cbk");
  });
});

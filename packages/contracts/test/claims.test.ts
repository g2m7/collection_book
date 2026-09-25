import { describe, expect, test } from "bun:test";

import {
  findNumericCapClaims,
  findUnsupportedClaims,
  unsupportedClaimRules,
} from "../src/claims";

describe("shared unsupported-claim rules", () => {
  test("every fixed claim rule rejects a known unsupported phrase", () => {
    const samples: Record<string, string> = {
      "free-forever": "100 subscribers free forever",
      "free-plan-or-tier": "Every operator starts on the free plan",
      "licensing-or-paywall": "License required for unlimited operators",
      "tax-or-legal-invoice": "Generates a GST invoice for every payment",
      "automatic-payment": "Automatic payment collection is supported",
      "cloud-sync": "Everything is kept in cloud sync across your devices",
      "production-uptime-guarantee":
        "Guaranteed uptime of 99.9% for every operator",
    };
    for (const rule of unsupportedClaimRules) {
      const sample = samples[rule.id];
      expect(sample).toBeDefined();
      if (sample === undefined) {
        continue;
      }
      expect(findUnsupportedClaims(sample).map((hit) => hit.id)).toContain(
        rule.id,
      );
    }
  });

  test("the numeric cap guard covers Latin and Indic digits in every script", () => {
    const capped = [
      "Free for 100 subscribers.",
      "Are you a Cable/WiFi Operator? Try Free (up to 100 subs).",
      "100 कनेक्शन तक मुफ़्त ऐप।",
      "Up to 250 customers on every plan.",
      "Only 50 connections are supported.",
      "No more than 75 subscribers.",
      "पहले 200 ग्राहक मुफ्त।",
      "केवल 30 कनेक्शन समर्थित।",
      "৫০ জন গ্রাহক পর্যন্ত বিনামূল্যে।",
      "শুধু ১০ জন গ্রাহক।",
      "முதல் 40 வாடிக்கையாளர்கள் இலவசம்.",
      "வரை 60 வாடிக்கையாளர்கள் மட்டும்.",
    ];
    for (const phrase of capped) {
      expect(findNumericCapClaims(phrase).map((hit) => hit.id)).toContain(
        "numeric-cap",
      );
    }
  });

  test("the numeric cap guard does not false-positive on implemented prose", () => {
    const allowed = [
      "Add subscribers with full name, alias name, area, monthly rent and previous due.",
      "Every subscription you record stays on this device.",
      "Book1 collection books and operator active-package or total-subscriber reports are detected automatically.",
      "The file picker accepts .xlsx, .xls and .csv.",
      "Every import shows a preview first, so you can check the detected columns and records.",
      "Store the VC / STB number for Cable TV and the account or card number for Internet.",
      "हर ग्राहक का भुगतान दर्ज करें।",
      "প্রতিটি গ্রাহকের পেমেন্ট লিখে রাখুন।",
      "ஒவ்வொரு வாடிக்கையாளரின் கட்டணத்தையும் பதிவு செய்து.",
      "100% offline",
      "Version 1.0 collection book",
    ];
    for (const phrase of allowed) {
      expect(findNumericCapClaims(phrase)).toEqual([]);
    }
  });
});

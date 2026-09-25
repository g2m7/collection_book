/**
 * Guards the Flutter receipt templates with the shared claim scanner.
 *
 * `lib/services/whatsapp_receipt_service.dart` is the one place where customer
 * facing product copy ships in five languages, and it used to advertise a free
 * tier and a 100-subscriber cap that the product never had. Duplicating the
 * rule set in Dart would drift, so the authoritative
 * `findUnsupportedClaims` scanner from `@collection-book/contracts` is run over
 * the Dart source here. The Dart-side regression guard for the exact removed
 * phrases lives in `test/whatsapp_receipt_claims_test.dart`.
 */

import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";

import {
  findNumericCapClaims,
  findUnsupportedClaims,
} from "@collection-book/contracts";

const receiptServicePath = join(
  import.meta.dir,
  "..",
  "..",
  "..",
  "lib",
  "services",
  "whatsapp_receipt_service.dart",
);
const receiptSource = readFileSync(receiptServicePath, "utf8");

/** The five receipt bodies, in the order `_template` returns them. */
function receiptTemplates(): string[] {
  const bodies = [...receiptSource.matchAll(/'''([\s\S]*?)'''/gu)]
    .map((match) => match[1])
    .filter((body) => body?.includes("{{REF_URL}}") === true);

  return bodies.filter((body): body is string => body !== undefined);
}

describe("flutter receipt templates", () => {
  test("the source exposes all five localized receipt templates", () => {
    expect(receiptTemplates()).toHaveLength(5);
  });

  test("no locale advertises a free tier, a plan, or an unsupported promise", () => {
    for (const template of receiptTemplates()) {
      expect(findUnsupportedClaims(template)).toEqual([]);
    }
  });

  test("no locale claims a subscriber cap", () => {
    for (const template of receiptTemplates()) {
      expect(findNumericCapClaims(template)).toEqual([]);
    }
  });

  test("the removed free/100-subscriber copy is gone in every language", () => {
    // The exact phrases the previous templates shipped, in Latin and Indic
    // digits, so a reintroduction fails with a readable message.
    for (const removed of [
      "Try Free (up to 100 subs)",
      "up to 100 subs",
      "100 कनेक्शन तक मुफ़्त",
      "१०० ग्राहकांसाठी मोफत",
      "১০০ গ্রাহক পর্যন্ত বিনামূল্যে",
      "100 इணைப்புகள் இலவசம்",
    ]) {
      expect(receiptSource).not.toContain(removed);
    }
  });

  test("the scanner is live against the claim it removed", () => {
    expect(
      findUnsupportedClaims(
        "Are you a Cable/WiFi Operator? Try Free (up to 100 subs): https://cbk.sarbaa.com/r/AB12CD",
      ).map((hit) => hit.id),
    ).toContain("numeric-cap");
  });
});

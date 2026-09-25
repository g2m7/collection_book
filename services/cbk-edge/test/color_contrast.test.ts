import { describe, expect, test } from "bun:test";

import { renderLandingPage } from "../src/landing";
import { renderPrivacyPage } from "../src/privacy";
import {
  contrastRatio,
  extractColorSchemes,
  extractStyleSheet,
  type ColorScheme,
} from "./support/color_scheme";

/** WCAG 2.1 AA minimum for normal-sized body text. */
const minimumContrast = 4.5;

const pages = {
  landing: renderLandingPage(null, undefined),
  "configured landing": renderLandingPage(
    "AB12CD",
    "https://play.google.com/store/apps/details",
  ),
  privacy: renderPrivacyPage(),
};

function schemesFor(html: string): { light: ColorScheme; dark: ColorScheme } {
  return extractColorSchemes(html);
}

describe.each(Object.entries(pages))("%s color scheme", (_, html) => {
  const { light, dark } = schemesFor(html);
  const styleSheet = extractStyleSheet(html);

  test("defines the accent foreground tokens in both schemes", () => {
    for (const scheme of [light, dark]) {
      for (const token of [
        "accent",
        "on-accent",
        "on-accent-soft",
        "accent-dark",
        "accent-soft",
        "ink",
        "ink-soft",
        "paper",
      ]) {
        expect(scheme[token]).toMatch(/^#[0-9a-f]{6}$/iu);
      }
    }
  });

  test("keeps text on the accent background readable", () => {
    for (const scheme of [light, dark]) {
      const accent = scheme["accent"]!;

      expect(
        contrastRatio(scheme["on-accent"]!, accent),
      ).toBeGreaterThanOrEqual(minimumContrast);
      expect(
        contrastRatio(scheme["on-accent-soft"]!, accent),
      ).toBeGreaterThanOrEqual(minimumContrast);
    }
  });

  test("keeps the muted accent-on-soft and body text readable", () => {
    for (const scheme of [light, dark]) {
      expect(
        contrastRatio(scheme["accent-dark"]!, scheme["accent-soft"]!),
      ).toBeGreaterThanOrEqual(minimumContrast);
      expect(
        contrastRatio(scheme["ink"]!, scheme["paper"]!),
      ).toBeGreaterThanOrEqual(minimumContrast);
      expect(
        contrastRatio(scheme["ink-soft"]!, scheme["paper"]!),
      ).toBeGreaterThanOrEqual(minimumContrast);
      expect(
        contrastRatio(scheme["ink-soft"]!, scheme["card"]!),
      ).toBeGreaterThanOrEqual(minimumContrast);
    }
  });

  test("never hardcodes a light text color on an accent background", () => {
    // A literal #fff or white is what produced the unreadable dark-mode
    // accent panel; every accent foreground must come from a token.
    expect(styleSheet).not.toMatch(/color:\s*#(?:fff|ffffff|eee|dddd)\b/iu);
    expect(styleSheet).not.toMatch(/color:\s*(?:white|#d8efe5)\s*;/iu);
    expect(styleSheet).toContain("color: var(--on-accent)");
  });
});

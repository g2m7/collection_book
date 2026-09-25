/**
 * Test helper: reads the design tokens out of a rendered page's inline
 * stylesheet so contrast can be asserted numerically instead of by eye.
 *
 * Dark mode is where accent-background text breaks silently, so the two
 * `:root` blocks (light default and `prefers-color-scheme: dark`) are extracted
 * separately and every text-on-surface pair is checked against the WCAG AA
 * minimum.
 */

export type ColorScheme = Readonly<Record<string, string>>;

const darkRoot =
  /@media \(prefers-color-scheme: dark\) \{\s*:root \{([^}]*)\}/u;
const lightRoot = /:root \{([^}]*)\}/u;

function parseDeclarations(block: string): ColorScheme {
  const tokens: Record<string, string> = {};
  for (const [, name, value] of block.matchAll(
    /--([a-z-]+):\s*(#[0-9a-f]{3,8})\s*;/giu,
  )) {
    if (name !== undefined && value !== undefined) {
      tokens[name] = value;
    }
  }
  return tokens;
}

export function extractStyleSheet(html: string): string {
  return html.match(/<style>([\s\S]*?)<\/style>/u)?.[1] ?? "";
}

export function extractColorSchemes(html: string): {
  readonly light: ColorScheme;
  readonly dark: ColorScheme;
} {
  const styleSheet = extractStyleSheet(html);

  return {
    light: parseDeclarations(styleSheet.match(lightRoot)?.[1] ?? ""),
    dark: parseDeclarations(styleSheet.match(darkRoot)?.[1] ?? ""),
  };
}

function toRgb(color: string): readonly [number, number, number] {
  const hex = color.replace("#", "");
  const expanded =
    hex.length === 3
      ? hex
          .split("")
          .map((digit) => `${digit}${digit}`)
          .join("")
      : hex;

  return [
    Number.parseInt(expanded.slice(0, 2), 16),
    Number.parseInt(expanded.slice(2, 4), 16),
    Number.parseInt(expanded.slice(4, 6), 16),
  ];
}

function relativeLuminance(color: string): number {
  const [red, green, blue] = toRgb(color).map((channel) => {
    const ratio = channel / 255;
    return ratio <= 0.04045 ? ratio / 12.92 : ((ratio + 0.055) / 1.055) ** 2.4;
  });

  return 0.2126 * (red ?? 0) + 0.7152 * (green ?? 0) + 0.0722 * (blue ?? 0);
}

/** WCAG 2.1 contrast ratio, from 1 (identical) to 21 (black on white). */
export function contrastRatio(foreground: string, background: string): number {
  const lighter = Math.max(
    relativeLuminance(foreground),
    relativeLuminance(background),
  );
  const darker = Math.min(
    relativeLuminance(foreground),
    relativeLuminance(background),
  );
  return (lighter + 0.05) / (darker + 0.05);
}

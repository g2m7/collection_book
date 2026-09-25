/**
 * Test helper: reduces a rendered page to the copy a reader would actually
 * see, so the shared claim scanner runs on customer-facing text instead of on
 * CSS, attribute values, and markup.
 */

const blockElements =
  /<\/?(?:style|script|head|title)[^>]*>[\s\S]*?<\/(?:style|script|head|title)>/giu;
const anyTag = /<[^>]*>/gu;

const entities: Record<string, string> = {
  "&amp;": "&",
  "&lt;": "<",
  "&gt;": ">",
  "&quot;": '"',
  "&#39;": "'",
  "&middot;": "·",
  "&mdash;": "—",
  "&ndash;": "–",
  "&amp;amp;": "&",
};

export function htmlToText(html: string): string {
  return html
    .replace(blockElements, " ")
    .replace(anyTag, " ")
    .replace(
      /&[a-z]+;|&#\d+;/giu,
      (entity) => entities[entity.toLowerCase()] ?? " ",
    )
    .replace(/\s+/gu, " ")
    .trim();
}

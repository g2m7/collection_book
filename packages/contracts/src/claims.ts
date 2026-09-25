/**
 * Guard against marketing claims the product does not actually implement.
 *
 * This module is the single shared scanner for customer-facing product copy.
 * The Play Store listing pipeline and the `cbk.sarbaa.com` landing/privacy
 * pages both run their copy through {@link findUnsupportedClaims}, so a future
 * edit cannot silently reintroduce a subscriber cap, a free tier, or another
 * unimplemented promise.
 *
 * Each entry pairs a stable identifier with a human-readable reason so a
 * failing claim reports what is wrong and not only what matched.
 */

export interface UnsupportedClaimRule {
  readonly id: string;
  readonly reason: string;
  readonly pattern: RegExp;
}

export const unsupportedClaimRules: readonly UnsupportedClaimRule[] = [
  {
    id: "free-forever",
    reason: "no free-forever promise is made anywhere in the product",
    pattern:
      /(free\s+forever|forever\s+free|हमेशा\s+के\s+लिए\s+(?:फ़?र?ी|मुफ़?त)|कायमस्वरूपी\s+मोफत|चिरंतन\s+(?:फ्री|मुफ्त)|চিরকাল\s+(?:ফ্রি|মুক্ত)|சமீப(?:ம்)?\s+இலவசம்)/iu,
  },
  {
    id: "free-plan-or-tier",
    reason:
      "the app has no paid plan, no free tier, and no licensing product yet",
    pattern:
      /(free\s+(?:plan|tier|version|edition)|(?:plan|tier|version)\s+is\s+free|start\s+free|मुफ्त\s+प्लान|फ्री\s+टियर|बिनामूल्ये\s+प्लान|বিনামূল্যে\s+প্ল্যান|இலவச\s+திட்டம்)/iu,
  },
  {
    id: "licensing-or-paywall",
    reason: "there is no licence, paywall or subscription tier in the app",
    pattern:
      /(paywall|licen[cs]e\s+required|subscription\s+(?:required|needed)|प्रीमियम|लाइसेंस|पेमेंट\s+वॉल|লাইসেন্স|சந்தா|பயம்\s+செலுத்த)/iu,
  },
  {
    id: "tax-or-legal-invoice",
    reason: "payment acknowledgements are not tax or legal invoices",
    pattern:
      /(GST\s+(?:invoice|bill)|tax\s+invoice|government\s+invoice|जीएसटी|कर\s+चालान|জিএসটি|வரி\s+ரசீது|বৈধ\s+রসিদ|कानूनी\s+रसीद|legal\s+receipt)/iu,
  },
  {
    id: "automatic-payment",
    reason:
      "the app records payments manually; it never charges anyone automatically",
    pattern:
      /(auto(?:matic)?[- ]?pay(?:ment)?|auto\s*debit|स्वचालित\s+(?:भुगतान|पेमेंट)|ऑटोमेटिक\s+पेमेंट|স্বয়ংক্রিয়\s+পেমেন্ট|தானியங்கி\s+கட்டணம்)/iu,
  },
  {
    id: "cloud-sync",
    reason:
      "data is stored on the device; the app has no cloud account or sync service",
    pattern:
      /(cloud\s+sync|sync\s+(?:across|with)\s+(?:devices|cloud)|क्लाउड\s+सिंक|क्लाउड\s+समन्वय|ক্লাউড\s+সিঙ্ক|கிளவுட்\s+ஒருங்கிணைப்பு)/iu,
  },
  {
    id: "production-uptime-guarantee",
    reason:
      "the app has no hosted backend, so uptime guarantees are not applicable",
    pattern:
      /(guaranteed\s+uptime|100%\s*uptime|99\.9%\s*uptime|हमेशा\s+चालू|কখনও\s+বন্ধ\s+হবে\s+না|எப்போதும்\s+இயங்கும்)/iu,
  },
];

export interface UnsupportedClaimHit {
  readonly id: string;
  readonly reason: string;
  readonly match: string;
}

/**
 * Latin, Devanagari, Bengali and Tamil digits, so a cap written as "५०" or
 * "৫০" is caught just like "50".
 */
const numeralClass = "0-9\\u0966-\\u096F\\u09E6-\\u09EF\\u0BE6-\\u0BEF";
const numberPattern = `[${numeralClass}][${numeralClass},\\u00A0]*(?:\\.[${numeralClass}]+)?`;

const unitPattern =
  "(?:subs?\\b|subscribers?|customers?|connections?|users?|" +
  "ग्राहक(?:ों|ां)?|कनेक्शन|उपयोगकर्ता|" +
  "গ্রাহক(?:দের)?|ব্যবহারকারী|" +
  "வாடிக்கையாளர(?:்|கள்)?|இணைப்பு|பயன்படுத்துபவர)";

const capWordPattern =
  "(?:up\\s?to|upto|no\\s+more\\s+than|only|just|first|free|capped?|limit(?:ed)?|maximum|max\\b|" +
  "तक|केवल|सिर्फ|मात्र|मुफ्त|फ़?री|अधिकतम|सीमित|" +
  "পর্যন্ত|শুধু|কেবল|ফ্রি|বিনামূল্যে|সর্বোচ্চ|সীমিত|" +
  "வரை|மட்டும்|இலவசம்|உலவச|அதிகபட்சம்|கட்டுப்படுத்தப்பட்ட)";

/**
 * Splits into short clauses so a number in one sentence cannot be joined with
 * a cap word from an unrelated sentence.
 */
function toClauses(text: string): string[] {
  return text
    .split(/[\n\r.;:!?()[\]"'`·।॥]+/u)
    .map((clause) => clause.trim())
    .filter((clause) => clause.length > 0);
}

const numberRe = new RegExp(numberPattern, "u");
const unitRe = new RegExp(unitPattern, "iu");
const capWordRe = new RegExp(capWordPattern, "iu");

/**
 * Finds any "at most N subscribers"-style cap. A clause only counts when it
 * contains a number, a subscriber/customer/connection unit, and a cap word, so
 * ordinary implemented feature prose is not flagged.
 */
export function findNumericCapClaims(text: string): UnsupportedClaimHit[] {
  const hits: UnsupportedClaimHit[] = [];
  for (const clause of toClauses(text)) {
    if (
      !numberRe.test(clause) ||
      !unitRe.test(clause) ||
      !capWordRe.test(clause)
    ) {
      continue;
    }
    const capWord = clause.match(capWordRe)?.[0] ?? "";
    hits.push({
      id: "numeric-cap",
      reason:
        "the app has no subscriber cap, so no 'up to N customers' style limit may be advertised",
      match: `${capWord} … ${clause.slice(0, 60)}`,
    });
  }
  return hits;
}

export function findUnsupportedClaims(text: string): UnsupportedClaimHit[] {
  const hits: UnsupportedClaimHit[] = [];
  for (const rule of unsupportedClaimRules) {
    const match = text.match(rule.pattern);
    if (match !== null) {
      hits.push({ id: rule.id, reason: rule.reason, match: match[0] });
    }
  }
  return [...hits, ...findNumericCapClaims(text)];
}

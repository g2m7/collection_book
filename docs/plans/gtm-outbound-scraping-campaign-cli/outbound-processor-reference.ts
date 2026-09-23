/**
 * Outbound Directory Processor & Campaign Stager (Bun Runtime Standard)
 * 
 * Ingests raw cable operator directories, normalizes Indian mobile numbers (+91),
 * removes duplicates, tags upstream MSO brands, and generates staged WhatsApp queues.
 * 
 * Execution:
 *   bun run outbound-processor-reference.ts --input=raw_operators.csv --output=staged_campaign.json
 */

interface RawOperator {
  name: string;
  businessName?: string;
  phone: string;
  city?: string;
  state?: string;
  msoBrand?: string;
}

interface StagedLead {
  leadId: string;
  name: string;
  businessName: string;
  cleanPhone: string; // 91XXXXXXXXXX
  state: string;
  detectedMso: string;
  targetLanguage: "hi" | "mr" | "bn" | "ta" | "en";
  whatsappMessage: string;
  waLink: string;
}

// 1. Phone Normalizer for Indian Mobile Numbers
function normalizeIndianMobile(raw: string): string | null {
  if (!raw) return null;

  // Remove spaces, dashes, parentheses, dots
  let digits = raw.replace(/\D/g, "");

  // If starts with 0, remove leading zero
  if (digits.startsWith("0")) {
    digits = digits.substring(1);
  }

  // If starts with 91 and has 12 digits, strip 91 for length check
  if (digits.startsWith("91") && digits.length === 12) {
    digits = digits.substring(2);
  }

  // Must be exactly 10 digits
  if (digits.length !== 10) {
    return null;
  }

  // Indian mobile numbers must start with 6, 7, 8, or 9
  if (!/^[6-9]/.test(digits)) {
    return null;
  }

  return `91${digits}`;
}

// 2. MSO Brand Classifier
function detectMso(text: string): string {
  const lower = text.toLowerCase();
  if (lower.includes("siti")) return "Siti Networks";
  if (lower.includes("den")) return "DEN Networks";
  if (lower.includes("gtpl")) return "GTPL Hathway";
  if (lower.includes("hathway")) return "Hathway";
  if (lower.includes("fastway")) return "Fastway";
  if (lower.includes("railwire")) return "Railwire";
  return "General Cable / ISP";
}

// 3. Language Selector based on State
function detectLanguage(state?: string): "hi" | "mr" | "bn" | "ta" | "en" {
  if (!state) return "hi";
  const s = state.toLowerCase();
  if (s.includes("maharashtra") || s.includes("goa")) return "mr";
  if (s.includes("bengal") || s.includes("tripura")) return "bn";
  if (s.includes("tamil")) return "ta";
  if (
    s.includes("uttar pradesh") ||
    s.includes("bihar") ||
    s.includes("madhya pradesh") ||
    s.includes("rajasthan") ||
    s.includes("delhi")
  ) {
    return "hi";
  }
  return "en";
}

// 4. Personalized Video Script Generator
function buildPitchMessage(
  name: string,
  mso: string,
  lang: "hi" | "mr" | "bn" | "ta" | "en"
): string {
  if (lang === "mr") {
    return `नमस्कार ${name} साहेब, ${mso} चे कलेक्शन डायरीमध्ये लिहून कंटाळा आलाय का?
कलेक्शन बुक अ‍ॅपमध्ये इंटरनेटशिवाय गल्लीनिहाय वसुली करा आणि १-क्लिकमध्ये ग्राहकांना व्हॉट्सअ‍ॅप पावती पाठवा.

👉 १०० ग्राहकांसाठी कायमस्वरूपी फ्री. ३० सेकंदांचा डेमो व्हिडिओ पहा: https://youtu.be/cbk-demo`;
  }

  if (lang === "bn") {
    return `নমস্কার ${name} বাবু, ${mso} এর কালেকশন কি এখনও পুরোনো খাতায় লিখছেন?
কালেকশন বুক অ্যাপের মাধ্যমে ইন্টারনেট ছাড়া এলাকাভিত্তিক হিসেব রাখুন এবং হোয়াটসঅ্যাপে ডিজিটাল রসিদ পাঠান।

👉 ১০০ গ্রাহক পর্যন্ত সম্পূর্ণ ফ্রি। ৩০ সেকেন্ডের ডেমো ভিডিও দেখুন: https://youtu.be/cbk-demo`;
  }

  if (lang === "ta") {
    return `வணக்கம் ${name} அவர்களே, ${mso} வசூலை டைரியில் எழுதி அலுத்துவிட்டதா?
கலெக்ஷன் புக் ஆப் மூலம் இணையம் இன்றியே வசூல் செய்து வாடிக்கையாளருக்கு வாட்ஸ்அப் ரசீது அனுப்பலாம்.

👉 100 இணைப்புகள் முற்றிலும் இலவசம். டெமோ வீடியோ பார்க்க: https://youtu.be/cbk-demo`;
  }

  // Default Hindi
  return `नमस्ते ${name} जी, ${mso} का कलेक्शन क्या अभी भी पुरानी डायरी में लिख रहे हैं?
कलेक्शन बुक ऐप से बिना इंटरनेट के पूरा हिसाब रखें और 1-क्लिक में ग्राहक को व्हाट्सएप रसीद भेजें।

👉 100 कनेक्शन हमेशा के लिए बिल्कुल फ्री। 30 सेकंड का डेमो वीडियो देखें: https://youtu.be/cbk-demo`;
}

// 5. Main CLI Processor
export async function processOutboundDataset(
  inputCsv: string,
  outputJson: string
): Promise<void> {
  console.log(`[Bun GTM Pipeline] Reading dataset: ${inputCsv}`);

  const file = Bun.file(inputCsv);
  if (!(await file.exists())) {
    console.error(`Error: File not found ${inputCsv}`);
    return;
  }

  const text = await file.text();
  const lines = text.split("\n").filter((l) => l.trim().length > 0);

  const seenPhones = new Set<string>();
  const stagedLeads: StagedLead[] = [];

  let invalidCount = 0;
  let duplicateCount = 0;

  // Process rows (Assuming CSV header: Name,Business,Phone,City,State,MSO)
  for (let i = 1; i < lines.length; i++) {
    const cols = lines[i].split(",").map((c) => c.trim().replace(/^"|"$/g, ""));
    const name = cols[0] || "Operator";
    const businessName = cols[1] || "";
    const rawPhone = cols[2] || "";
    const city = cols[3] || "";
    const state = cols[4] || "";
    const rawMso = cols[5] || "";

    const cleanPhone = normalizeIndianMobile(rawPhone);
    if (!cleanPhone) {
      invalidCount++;
      continue;
    }

    if (seenPhones.has(cleanPhone)) {
      duplicateCount++;
      continue;
    }

    seenPhones.add(cleanPhone);

    const mso = detectMso(`${businessName} ${rawMso}`);
    const lang = detectLanguage(state);
    const message = buildPitchMessage(name, mso, lang);
    const waLink = `https://wa.me/${cleanPhone}?text=${encodeURIComponent(message)}`;

    stagedLeads.push({
      leadId: `lead_${i}`,
      name,
      businessName,
      cleanPhone,
      state,
      detectedMso: mso,
      targetLanguage: lang,
      whatsappMessage: message,
      waLink,
    });
  }

  console.log(`[Bun GTM Pipeline] Extraction Complete:`);
  console.log(`  - Total Rows: ${lines.length - 1}`);
  console.log(`  - Valid Unique Leads: ${stagedLeads.length}`);
  console.log(`  - Invalid/Landlines Dropped: ${invalidCount}`);
  console.log(`  - Duplicate Numbers Dropped: ${duplicateCount}`);

  await Bun.write(outputJson, JSON.stringify(stagedLeads, null, 2));
  console.log(`[Bun GTM Pipeline] Saved staged campaign to: ${outputJson}`);
}

// Self-executing runner if called directly
if (import.meta.main) {
  const args = Bun.argv.slice(2);
  const input = args[0] || "data/raw/operators_sample.csv";
  const output = args[1] || "data/staged/outreach_sample.json";
  await processOutboundDataset(input, output);
}

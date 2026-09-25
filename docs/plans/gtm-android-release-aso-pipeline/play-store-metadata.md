# Google Play Store Multi-Language Metadata & ASO Kit

## Source of Truth and Commands

The localized listing text lives in
`packages/play-store-metadata/src/metadata.ts`. It is not maintained by hand
here; this document describes the kit, not the copy. Edit the package and
regenerate.

`src/validate.ts` is the single gate. It enforces the exact locale set
(`en-IN`, `hi-IN`, `mr-IN`, `bn-IN`, `ta-IN`), non-empty fields, the Google Play
limits of 30 title, 80 short description, and 4000 full description Unicode code
points, and the claim policy in `src/claims.ts`. `assertValidMetadata` runs all
three, so `planListingFiles`, `generateListingFiles`, and `--check` all reject a
bad claim or an over-long field before anything is written.

From the repository root:

```sh
bun run aso:generate                          # writes packages/play-store-metadata/dist (git-ignored)
bun run aso:generate --out build/play-store   # relative --out resolves from the repository root
bun run aso:check                             # validates only, using a temporary directory
```

Output layout, one directory per locale:

```
dist/<locale>/title.txt
dist/<locale>/short-description.txt
dist/<locale>/full-description.txt
```

Generation is deterministic: re-running over a clean directory produces
byte-identical files. `bun run aso:check` runs inside `bun run verify:bun`, which
CI executes as the independent Bun gate. Generating files does not upload
anything to Play Console.

## Claim Policy

The listings describe only implemented behaviour, checked against the app source
and the shipped `assets/i18n` catalogs:

- An offline-first collection ledger for Cable TV and Internet operators.
- Subscribers with full name, alias name, area, monthly rent and previous due.
  There is **no** package field; the `subscribers` table has no such column.
- Service identifiers: **VC / STB number** for Cable TV; **account or card
  number**, login username and WhatsApp mobile number for Internet/Fiber.
- Manual payment records with paid-versus-pending visibility, filtered by
  service or area.
- Import through a file picker that accepts **.xlsx, .xls and .csv**. Book1
  collection books and operator active-package or total-subscriber reports are
  detected automatically. Operator portals that export an HTML table are also
  handled, but only when the file is saved with an `.xls` extension.
- Local backup creation, sharing of the database file, and restore.
- A generated WhatsApp receipt. The message is pre-filled and opens in
  WhatsApp, or in the browser through **wa.me** when WhatsApp is not installed,
  where the operator reviews it and then sends it. There is **no** in-app
  receipt editor and **no** share-to-any-other-app path.
- A five-language UI covering English, Hindi, Marathi, Bengali, and Tamil, with
  the receipt language following the app language.

Explicitly excluded, because the app does not implement them: any subscriber
cap or free-forever plan, licensing or paywall tiers, GST or legal invoices,
automatic payment collection, cloud sync, and any uptime or production
guarantee. Payment acknowledgements are described as receipts, never as tax or
legal invoices.

`src/claims.ts` enforces this automatically. It blocks a fixed set of promise
patterns plus a **numeric cap guard** that catches "up to N subscribers"-style
limits written with Latin, Devanagari, Bengali, or Tamil digits. A clause is
only flagged when it contains a number, a subscriber/customer/connection unit,
*and* a cap word, so ordinary feature prose is not caught.

## Output Directory Safety

`generateListingFiles` validates and inventories everything before the first
canonical file is written:

- Every path is resolved and proved to stay inside the requested root.
- The requested root is caller-selected, so a symlinked root is honoured, but
  a pre-existing symlinked **locale directory** or **target file** is refused
  and nothing is written. Files are opened with `O_NOFOLLOW` where the platform
  provides it.
- The destination is inventoried **fail-closed**. Only the current locale
  directories and the current generated file names are allowed. A stale locale
  directory, a stale or unknown file, a symlinked entry, or any other stray
  entry makes the run fail with the offending paths listed, and **nothing is
  deleted or overwritten**. Remove the stale entry by hand, or point `--out` at
  an empty directory.

This is deliberate: the CLI never prunes a custom output directory on your
behalf. When a locale is removed from `supportedLocales`, its old directory
must be deleted once before the next run will succeed.

## 1. English (en-IN)
* **Title (25 code points)**: `Collection Book: Cable TV`
* **Short description (66 code points)**: `Offline collection and payment register for Cable TV and Internet.`
* **Full description (1739 code points)**: the offline ledger, subscriber and payment records with the real Cable TV and Internet identifiers, the .xlsx/.xls/.csv picker and HTML-table caveat, import preview, local backup and restore, the pre-filled WhatsApp receipt with wa.me fallback, and the five-language UI.

## 2. Hindi (hi-IN)
* **Title (24 code points)**: `केबल वसूली और भुगतान बही`
* **Short description (70 code points)**: `केबल टीवी और इंटरनेट ऑपरेटरों के लिए ऑफ़लाइन संग्रह और भुगतान रजिस्टर।`
* **Full description (1644 code points)**: the same truthful feature set, using established app vocabulary such as `ग्राहक`, `क्षेत्र`, `पिछला बकाया`, `वीसी / एसटीबी नंबर`, `खाता या कार्ड नंबर`, `उपयोगकर्ता नाम`, `पूर्वावलोकन`, and `बही`.

## 3. Marathi (mr-IN)
* **Title (25 code points)**: `केबल वसुली आणि पेमेंट बही`
* **Short description (68 code points)**: `केबल टीव्ही आणि इंटरनेट ऑपरेटरसाठी ऑफलाइन संग्रह आणि पेमेंट नोंदवही.`
* **Full description (1618 code points)**: the same truthful feature set, using established app vocabulary such as `ग्राहक`, `भाग`, `मागील बाकी`, `व्हीसी / एसटीबी क्रमांक`, `खाते किंवा कार्ड क्रमांक`, `वापरकर्तानाव`, `प्रलंबित`, `पूर्वदृश्य`, `स्प्रेडशीट`, and `आवडीच्या`.

## 4. Bengali (bn-IN)
* **Title (27 code points)**: `কেবল কালেকশন ও পেমেন্ট খাতা`
* **Short description (68 code points)**: `কেবল টিভি ও ইন্টারনেট অপারেটরদের জন্য অফলাইন কালেকশন ও পেমেন্ট খাতা।`
* **Full description (1621 code points)**: the same truthful feature set, using `assets/i18n/bn.json` vocabulary (`গ্রাহক`, `এলাকা`, `পূর্বের বকেয়া`, `ভিসি / এসটিবি নম্বর`, `অ্যাকাউন্ট বা কার্ড নম্বর`, `অপেক্ষমাণ`, `প্রিভিউ`). The earlier mixed-script keyword line that used Arabic script for a Bengali word has been removed; a test now fails if Arabic code points reappear in the Bengali listing.

## 5. Tamil (ta-IN)
* **Title (25 code points)**: `கேபிள் டிவி வசூல் பதிவேடு`
* **Short description (72 code points)**: `கேபிள் டிவி மற்றும் இண்டர்நெட் ஆபரேட்டர்களுக்கான ஆஃப்லைன் வசூல் பதிவேடு.`
* **Full description (2094 code points)**: the same truthful feature set, using established app vocabulary such as `வாடிக்கையாளர்`, `பகுதி`, `முந்தைய பாக்கி`, `விசி / எஸ்டிபி எண்`, `கணக்கு அல்லது அட்டை எண்`, `பயனர் பெயர்`, `நிலுவையில்`, `அட்டவணை`, `நெடுவரிசை`, and `மராத்தி`.

## Terminology Checks

`test/metadata.test.ts` carries regression assertions for tokens that were
malformed in the first draft of these listings, plus a mechanical check that the
required app term appears in each locale. Corrected forms include Tamil
`வாடிக்கையாளர்` / `நிலுவையில்` / `அட்டவணை` / `நெடுவரிசை` / `மராத்தி`,
Marathi `स्वतंत्रपणे` / `म्हणून` / `आवडीच्या` / `स्प्रेडशीट`, and Hindi
`पूर्वावलोकन` / `बही`.

These checks are **automated policy and terminology checks only**. They are not
a native-language editorial review, and no native speaker or professional
translator has signed off on the vernacular copy.

## ASO Keyword Research Notes

The following keyword lists are human research notes used when selecting the
copy above. They are not generated, not validated, and not uploaded anywhere.

* **en-IN**: `cable billing app, lco collection book, cable tv register, broadband billing, hathway lco, siti digital`
* **hi-IN**: `केबल बिलिंग ऐप, केबल ऑपरेटर रजिस्टर, कलेक्शन खाता बुक, लाइन बॉय ऐप, ब्रॉडबैंड बिलिंग, जीटीपीएल केबल`
* **mr-IN**: `केबल टीव्ही वसुली, केबल वहीखाते, इंटरनेट बिलिंग अ‍ॅप, ऑपरेटर रजिस्टर`
* **bn-IN**: `কেবল বিলিং অ্যাপ, কেবল অপারেটর খাতা, ব্রডব্যান্ড বিলিং সফটওয়্যার`
* **ta-IN**: `கேபிள் டிவி பில்லிங் ஆப், வசூல் பதிவு, பிராட்பேண்ட் பில்லிங்`

## Still Pending

- **Native-language editorial review** of the four vernacular listings. The
  automated policy and terminology checks pass, but a native reviewer or
  professional translator must approve the copy before it is uploaded.
- Packaging high-converting 1080x1920 vernacular screenshots.
- Pasting each generated file into the corresponding Google Play Console
  listing and submitting it for review. Nothing in this repository publishes or
  uploads a listing.

# Go-To-Market (GTM) & Marketing Playbook: India Mass Market

> **Copy status — this playbook is not approved public copy.** Every script, caption,
> creative, and receipt footer below is a **draft**. Two classes of line are **blocked**
> until the commercial gate (Gate 13 in
> [`plans/cloud-authoritative-offline-first-saas/plan.md`](plans/cloud-authoritative-offline-first-saas/plan.md))
> closes:
> 1. **Any free/price/limit claim** — "100% free", "100 connection bilkul free",
>    "Download Free", "free forever", a subscriber cap, or a price. The direction
>    **retains an affordable free entry path**, but its boundary, limit, and prices are
>    undecided, so no such line may run publicly.
> 2. **Any "download on Play Store" call to action** — the app is **not publicly listed**
>    until the public release gate (Gate 15). Publishing this playbook's CTAs before then
>    would point operators at a listing that does not exist.
>
> Until both are settled, every line above is edited to remove the claim before use, and
> the claim scanners (`packages/contracts/src` `findUnsupportedClaims` and the Play
> metadata scanner) remain the enforcement point. Nothing here changes shipped landing,
> privacy, or Play Store copy.
>
> **Section quarantine rule for this document.** Every numbered section below is a
> **draft planning sketch, not an instruction to publish**. The illustrative budgets,
> costs, prices, ROAS figures, scripts, and CTAs in §1–§5 are historical modelling
> retained for the Gate 13 commercial decision and the Gate 15 release; none of them is
> evidence, an approved offer, or authorization to run. An implementer must not use this
> document to schedule a campaign, buy advertising, or publish a script before the
> corresponding gate closes. The gate reference is
> [`plans/cloud-authoritative-offline-first-saas/plan.md`](plans/cloud-authoritative-offline-first-saas/plan.md)
> §11; the rollout order is its §9.

## 1. Strategy for an Offline-First ICP

> **Quarantined — not an active acquisition plan.** The funnel below is a draft channel
> sketch. **No channel may be activated before the public release gate (Gate 15)**: every
> install CTA here points at a Google Play listing that does not exist until then, and a
> pre-release install base would create the exact migration burden the current direction
> removed (§9.2 of the canonical plan). Paid acquisition additionally depends on the
> commercial gate (Gate 13), because every conversion assumption below is priced against
> an undecided tier.

Because Indian Local Cable Operators (LCOs) and FTTH technicians do not consume traditional B2B SaaS marketing, customer acquisition relies on a **four-channel hybrid funnel**:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               FOUR-CHANNEL ACQUISITION FUNNEL                          │
├─────────────────────────┬───────────────────────────┬──────────────────────────────────┤
│ Channel                 │ Primary Mechanism         │ Cost / Economic Profile          │
├─────────────────────────┼───────────────────────────┼──────────────────────────────────┤
│ 1. WhatsApp Direct      │ Outbound video outreach   │ ₹0.25 - ₹0.35 per message        │
│    Outbound             │ to scraped directories    │ (Fastest to initial 500 users)   │
├─────────────────────────┼───────────────────────────┼──────────────────────────────────┤
│ 2. Meta Advantage+ Ads  │ Video ads on Reels & Feed │ ₹12 - ₹25 per install            │
│    (Android Only)       │ targeting LCO brand pages │ (Predictable, scalable pipeline) │
├─────────────────────────┼───────────────────────────┼──────────────────────────────────┤
│ 3. YouTube Shorts &     │ Practical video hacks and │ ₹0 Organic reach                 │
│    Vernacular SEO       │ relatable operator skits  │ (Compounds long-term trust)      │
├─────────────────────────┼───────────────────────────┼──────────────────────────────────┤
│ 4. Play Store ASO       │ Multi-language keyword    │ ₹0 Organic inbound               │
│    (Vernacular)         │ index (5 regional langs)  │ (High-intent search capture)     │
└─────────────────────────┴───────────────────────────┴──────────────────────────────────┘
```

---

## 2. Meta Ads Playbook (Facebook & Instagram)

> **Quarantined — provisional spend and unit economics, and no public listing to point
> at.** Do not open an ads account, set a budget, or start creative testing from this
> section. The figures below are the **pre-Gate-13 modelling assumption** (a paid tier
> priced at ₹1,499/year converting at 5%), not a forecast and not an approved budget.
> They must be re-derived after Gate 13 decides the offer, and the campaigns cannot run
> at all before Gate 15, because the campaign objective below targets a direct Play
> Store link.

### Campaign Configuration in Meta Ads Manager
* **Campaign Objective**: App Promotion (Advantage+ App Campaigns) or Leads/Traffic targeting direct Play Store link *(blocked until Gate 15: no public listing exists yet)*.
* **Target Operating System**: **Android ONLY** (strictly exclude iOS to avoid wasting budget).
* **Geographic Scope**: Pan-India excluding Tier-1 metro cores (prioritize Maharashtra, Uttar Pradesh, West Bengal, Bihar, Gujarat, Madhya Pradesh, Rajasthan, Andhra Pradesh/Telangana).
* **Demographics**: Men, Age 23–52.
* **Detailed Targeting Parameters**:
  * *Brands/Entities*: `GTPL Hathway`, `Siti Networks`, `DEN Networks`, `Fastway Transmissions`, `Hathway`, `Railwire`, `BSNL Bharat Fibre`.
  * *Interests*: `Optical fiber`, `Cable television`, `Fusion splicing`, `MikroTik`, `Network switch`.

### Budget & Benchmark Unit Economics

> **Provisional assumptions only.** The budget, CPI, and ROAS lines below are an
> illustrative pre-Gate-13 model that assumes a ₹1,499/year paid tier. No price is
> decided, no budget is approved, and no campaign is authorized. Treat the numbers as
> the shape of the model to be rebuilt at Gate 13, not as a spend plan.

* **Daily Test Budget**: ₹500/day ($\approx$ ₹15,000/month).
* **Expected Cost Per Install (CPI)**: ₹12 – ₹25.
* **Monthly Installs**: ~600 to 1,000 targeted installs per month.
* **Paid Conversion**: At a 5% conversion rate to the ₹1,499/year Starter Plan, ₹15,000 spend yields 30–50 paid customers ($\approx$ ₹45,000 – ₹75,000 revenue $\rightarrow$ **3x to 5x ROAS**).

### High-Converting Creative Angles

#### Creative 1: The Pain Point ("Bheega Register" / Lost Paper Diary)
* **Format**: 9:16 Vertical Video (Reels/Feed).
* **Hook (0-3s)**: Close-up of tea spilling over an open collection register with handwritten names getting smudged.
* **Audio / Script (Hinglish)**:
  > *"Baarish me register bheeg gaya ya line boy ne hisab uljha diya? Purani diary chhoro! Collection Book app se bina internet ke area-wise collection track karo aur customer ko 1-click me WhatsApp receipt bhejo. 100 connection bilkul free. Abhi install karein!"*
* **CTA**: Download / Install Now.
* **Blocked claim:** the final sentence's "100 connection bilkul free" and the install CTA are **not approved for public use** — see the copy status note at the top of this document. The free-path boundary and the Play availability are both undecided.

#### Creative 2: The Friction Killer ("Direct MSO Excel Import")
* **Format**: 9:16 Screen Recording with bold captions.
* **Hook (0-3s)**: "500 customer ke naam hath se likhna band karo!"
* **Visual**: Shows an operator opening an Excel file from Siti/DEN/GTPL inside the app; in 2 seconds, all 500 customers appear categorized by lane.
* **Audio / Script (Hinglish)**:
  > *"Apne MSO portal ka Excel file phone me select karo aur 2 second me saara hisab taiyar. Kaunsa box active hai, kiska kitna baqaya hai, sab mobile par dekho. 100% offline."*

---

## 3. YouTube Shorts Strategy (Organic Video Engine)

> **Quarantined — script drafts.** The pillar map and the 30-second script below are
> drafts, not approved creative. The script's closing line is blocked on both counts
> (see the blocked-claim note under the table), so the script may not be recorded or
> published until the free-path boundary is decided at Gate 13 and the public listing
> exists at Gate 15.

Cable operators actively search YouTube for equipment tutorials, splicing guides, and software tips.

### 3 Content Pillars That Trigger Algorithmic Reach

```
┌─────────────────────────────────┬─────────────────────────────────┬─────────────────────────────────┐
│ PILLAR 1: THE RELATABLE SKIT    │ PILLAR 2: THE PRACTICAL HACK    │ PILLAR 3: THE LOSS PREVENTION   │
├─────────────────────────────────┼─────────────────────────────────┼─────────────────────────────────┤
│ Customer vs Operator disputes   │ "How to upload Siti/DEN Excel   │ "How to prevent line boys from  │
│ over payment history with real  │ file to mobile without a PC     │ holding back cash collections   │
│ timestamped proof.              │ in under 30 seconds."           │ on the 1st of the month."       │
└─────────────────────────────────┴─────────────────────────────────┴─────────────────────────────────┘
```

### Complete 30-Second Plug-and-Play Script

* **Title**: `Customer bola: "Maine pichle mahine paise de diye the!" Ab kya karein? #shorts #cableoperator`
* **Format**: 9:16 Vertical Short.

| Timestamp | Visual Cue | Spoken Voiceover (Hindi) | Text Overlay (Captions) |
| :--- | :--- | :--- | :--- |
| **0:00 - 0:06** | Customer standing at the door looking irritated. | *"Bhaiya maine pichle mahine 300 rupaye de diye the, aap har mahine aake behas kyu karte ho?"* | **"Customer ne bola: Maine de diya!"** |
| **0:06 - 0:13** | Operator smiles, opens Collection Book app on phone. | *Aise jhagdo se tang aa chuke ho? Ab purani diary chhoro aur mobile me dekho.* | **Torn Diary ❌ Mobile App ✅** |
| **0:13 - 0:21** | Screen zoom: Shows transaction history with date & time. | *App me turant dikhao: 'Bhaiya 14 August ko 200 diya tha, 100 baqaya bacha tha.'* | **Exact Proof: ₹200 Paid, ₹100 Due** |
| **0:21 - 0:30** | Operator taps "WhatsApp Receipt" $\rightarrow$ customer's phone chimes. | *Ek click me WhatsApp receipt bhejo. Play Store se download karein 'Collection Book' – 100% free.* | **Download Free on Play Store 👇** |

> **Blocked claim (this row is not approved public copy).** "100% free" and "Download
> Free on Play Store" are both blocked: the free-path boundary is undecided until Gate 13,
> and the app is not publicly listed until Gate 15. Rewrite the closing line to drop both
> before this script is recorded or published.

---

## 4. Play Store ASO Kit (Multi-Language Metadata)

> **Quarantined — this section is not the canonical listing copy.** The canonical
> five-language Play listing text, its claim rules, and its generator are
> [`packages/play-store-metadata/`](../packages/play-store-metadata/)
> (`src/metadata.ts`, `src/claims.ts`, and the `aso:generate` / `aso:check` Bun CLI).
> **Edit the package, not this section.** The block below is an early keyword scratchpad
> kept for history; it is **not** what may be pasted into Play Console, and it is not
> approved copy.
>
> **Release gate: nothing here is published before Gate 15.** The listing is submitted,
> and the Gate 11 data-safety disclosure is published, as part of the public release in
> [`plans/cloud-authoritative-offline-first-saas/plan.md`](plans/cloud-authoritative-offline-first-saas/plan.md)
> §11 (Gate 15), **after** Gates 1–14. Until then the listing describes the
> **local-only** app, and customer-facing copy must never lead the implementation: the
> listing, the landing page, and `/privacy` change **in the same release** that makes a
> cloud capability true. Mechanics, screenshots, native-speaker review, and publishing
> live in
> [`plans/gtm-android-release-aso-pipeline/plan.md`](plans/gtm-android-release-aso-pipeline/plan.md).

### English Listing Metadata (draft scratchpad — not canonical, not approved)
* **App Name**: `Collection Book: Cable & ISP`
* **Subtitle**: `Cable TV & WiFi Billing App | LCO Collection Register`
* **Short Description**: `Offline collection register & billing app for Cable TV & WiFi operators. WhatsApp receipts.`
* **Core Keywords**: `cable billing app`, `lco register`, `cable tv collection`, `broadband billing app`, `isp billing software`, `gtpl billing app`, `siti digital lco`, `cable khata book`.

### Vernacular ASO Keywords (Play Store Regional Indexing)

```
┌───────────┬───────────────────────────────────┬────────────────────────────────────────────────────────┐
│ Language  │ Primary Search Query              │ High-Volume Keyword Variations                         │
├───────────┼───────────────────────────────────┼────────────────────────────────────────────────────────┤
│ Hindi     │ केबल बिलिंग ऐप                    │ केबल ऑपरेटर रजिस्टर, कलेक्शन खाता बुक, ब्रॉडबैंड बिलिंग│
├───────────┼───────────────────────────────────┼────────────────────────────────────────────────────────┤
│ Marathi   │ केबल टीव्ही वसुली अ‍ॅप           │ केबल ऑपरेटर वहीखाते, इंटरनेट बिलिंग, गल्ली वसुली यादी   │
├───────────┼───────────────────────────────----┼────────────────────────────────────────────────────────┤
│ Bengali   │ কেবল বিলিং অ্যাপ                  │ কেবল অপারেটর কালেকশন খাতা, ব্রডব্যান্ড বিলিং সফটওয়্যার │
├───────────┼───────────────────────────────────┼────────────────────────────────────────────────────────┤
│ Tamil     │ கேபிள் டிவி பில்லிங் ஆப்         │ வசூல் பதிவு ஆப், பிராட்பேண்ட் பில்லிங்                 │
├───────────┼───────────────────────────────────┼────────────────────────────────────────────────────────┤
│ Telugu    │ కేబుల్ బిల్లింగ్ యాప్            │ కలెక్షన్ రిజిస్టర్, ఇంటర్నెట్ బిల్లింగ్ సాఫ్ట్‌వేర్     │
└───────────┴───────────────────────────────────┴────────────────────────────────────────────────────────┘
```

---

## 5. In-Product Organic Viral Loop: The "Trojan Horse" Receipt

> **Quarantined — the shipped footer is a landing referral, not a Play CTA.** The receipt
> template in the app is the source of truth and links to the landing/referral URL
> (`https://cbk.sarbaa.com/r/{code}`), which honestly reports Play availability; it does
> **not** say "Download Free" and does **not** link to Google Play. The "bit.ly" line
> below is a blocked draft and must not ship: a Play install CTA in a receipt is only
> truthful after Gate 15, and any "free" wording is blocked until Gate 13. Engineering
> requirements for the receipt loop are in
> [`plans/gtm-in-app-viral-receipts/plan.md`](plans/gtm-in-app-viral-receipts/plan.md).

Every receipt generated via device intent carries a discrete viral invitation in the footer:

```text
🧾 PAYMENT RECEIPT / भुगतान रसीद
━━━━━━━━━━━━━━━━━━━━━
👤 Customer: Rajesh Kumar
📺 Service: Cable TV (VC: 0214892348)
📍 Area: Main Road, Sector 4
🗓️ Month: October 2026
━━━━━━━━━━━━━━━━━━━━━
💵 Amount Paid: ₹350
✅ Status: PAID (चुकता)
⚠️ Remaining Due: ₹0
━━━━━━━━━━━━━━━━━━━━━
🙏 Thank you for your payment!
📱 Managed via Collection Book App
👉 Are you a Cable/WiFi Operator? Download Free: bit.ly/collection-book
```

> **Blocked claim (this receipt footer is not approved public copy).** "Download Free" is
> blocked until Gate 13 fixes the free-path boundary and Gate 15 makes the public listing
> real. The current shipped receipt template in the app is the source of truth and does
> not carry this line.

*Mechanism*: Local operators, sub-operators, and neighboring technicians regularly observe receipts received by their peers or family members, creating zero-cost organic discovery.

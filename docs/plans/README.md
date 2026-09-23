# Plans Directory

This directory contains all technical and feature implementation plans for **Collection Book**.

---

## 📌 Standard Operating Rule

> **EVERY PLAN MUST HAVE ITS OWN DEDICATED DIRECTORY.**  
> Do not place loose plan files directly in `docs/plans/` or `docs/`.

### Directory Structure Convention

Each plan should be created inside a distinct folder named with a descriptive slug or date prefix:

```
docs/plans/
├── README.md                           # This index & convention guide
└── <plan-name>/                        # Dedicated directory per plan
    ├── plan.md (or README.md)          # Core plan specification & checklist
    ├── architecture.md                 # (Optional) Detailed architectural design
    ├── research.md                     # (Optional) Background context, benchmarks, or notes
    └── assets/                         # (Optional) Diagrams, mockups, or schemas
```

### Plan Folder Naming Examples

- `docs/plans/convex-cloud-sync/`
- `docs/plans/upi-auto-pay-integration/`
- `docs/plans/multi-language-localization/`
- `docs/plans/bluetooth-thermal-printer/`

---

## 📋 Recommended Plan Template (`plan.md`)

Each plan directory's primary document should follow this structure:

```markdown
# Plan: [Feature / Architecture Name]

## 1. Overview & Objective
Brief summary of the feature, user problem solved, and expected business/technical outcome.

## 2. Requirements & Scope
- **In Scope**: Key capabilities to implement.
- **Out of Scope**: Deliberately deferred items.

## 3. Architecture & Technical Design
- Schema / Database modifications (e.g., SQLite migration, Convex tables).
- Service / Provider layers involved.
- UI Screens & Components affected.

## 4. Implementation Checklist
- [ ] Task 1: Data layer / models
- [ ] Task 2: Business logic / services
- [ ] Task 3: UI screens & navigation
- [ ] Task 4: Error handling & edge cases

## 5. Verification Plan
- `flutter analyze` lint checks.
- Unit and widget tests (`flutter test`).
- Manual verification steps on physical device / emulator.
```

---

## 🚀 Active Technical Plans: Go-To-Market (GTM) Engine

The following 7 technical implementation plans form the core engineering foundation for acquiring, activating, and monetizing 100,000 Indian Local Cable Operators and FTTH ISPs:

| Plan Directory | Focus Area | Key Architectural Deliverables |
| :--- | :--- | :--- |
| **[`gtm-in-app-viral-receipts/`](file:///c:/projects/cross/collection_book/docs/plans/gtm-in-app-viral-receipts/plan.md)** | **Viral Loop & WhatsApp Receipts** | SQLite v5 migration (`phone`), native Android `whatsapp://send` intent engine, 5-language localized templates, and Trojan Horse referral footer with attribution tracking. |
| **[`gtm-freemium-paywall-licensing/`](file:///c:/projects/cross/collection_book/docs/plans/gtm-freemium-paywall-licensing/plan.md)** | **Freemium Paywall & Licensing** | 100-subscriber freemium cap guard, MSO bulk import grace gate, vernacular upgrade bottom sheet, and Ed25519 offline-durable cryptographic license tokens. |
| **[`gtm-upi-checkout-edge-pipeline/`](file:///c:/projects/cross/collection_book/docs/plans/gtm-upi-checkout-edge-pipeline/plan.md)** | **1-Tap UPI Checkout & Edge Worker** | Cloudflare Edge Gateway (Bun runtime), Android UPI intent (PhonePe/GPay), Razorpay HMAC webhook verification, and Convex plan mutation. |
| **[`gtm-vernacular-localization/`](file:///c:/projects/cross/collection_book/docs/plans/gtm-vernacular-localization/plan.md)** | **Vernacular i18n Localization** | 5 regional languages (Hindi, Marathi, Bengali, Tamil, English), reactive `AppLanguageService`, and grassroots jargon matrix (*bahi-khata, line boy, baqaya*). |
| **[`gtm-android-release-aso-pipeline/`](file:///c:/projects/cross/collection_book/docs/plans/gtm-android-release-aso-pipeline/plan.md)** | **Android Release & ASO Pipeline** | $<15\text{MB}$ AAB optimization (R8 shrinking, ProGuard), Android App Links (`assetlinks.json`), and regional Play Store metadata generator. |
| **[`gtm-outbound-scraping-campaign-cli/`](file:///c:/projects/cross/collection_book/docs/plans/gtm-outbound-scraping-campaign-cli/plan.md)** | **Outbound Scraping CLI (Bun)** | Bun TypeScript CLI pipeline ingesting public TRAI/association directories, normalizing Indian mobiles (+91 E.164), MSO brand tagging, and staged WhatsApp outreach queues. |
| **[`gtm-acquisition-telemetry-funnel/`](file:///c:/projects/cross/collection_book/docs/plans/gtm-acquisition-telemetry-funnel/plan.md)** | **Acquisition & Funnel Telemetry** | Local SQLite event buffer (`analytics_events`), 8 milestone funnel events, battery-friendly edge beacon flush, and zero-PII data privacy guards. |


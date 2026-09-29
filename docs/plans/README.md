# Plans Directory

This directory contains all technical and feature implementation plans for **Collection Book**.

> **Current vs. target product.** The shipped app is a **local-authoritative, offline-first
> Android app** with no account, cloud ledger, or sync. The approved **target** is an
> **offline-capable, cloud-authoritative, multi-tenant SaaS** in which the cloud ledger is
> the system of record and SQLite becomes a local cache plus mutation outbox. The target
> is documented and **not implemented**; the backend vendor is an **open decision**.
> See [`cloud-authoritative-offline-first-saas/`](cloud-authoritative-offline-first-saas/plan.md).
>
> **Overall direction (SaaS-first, 2026-09-30).** Build the cloud target and close
> Stages 0–8 and Gates 1–14 **before** the app is published on Google Play; cloud Stage 1
> is a pre-launch item and the Gate 1 vendor decision runs in parallel. The public release
> is Gate 15. The order for all
> plans is the stage and gate sequence in
> [`cloud-authoritative-offline-first-saas/`](cloud-authoritative-offline-first-saas/plan.md)
> §9–§11. The earlier "launch the local-only app first" decision in
> [`play-launch-then-cloud-direction/`](play-launch-then-cloud-direction/plan.md) is
> **superseded** and is history only; do not use its §5 priority order or §3.6.

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

- `docs/plans/cloud-authoritative-offline-first-saas/`
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
- Schema / Database modifications (e.g., SQLite migration, cloud ledger tables).
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

## 📚 Plan Directory Index

This index lists all **13** plan directories in the repository, including the canonical
project direction and staged-rollout plan, the superseded Play-first direction record, the GTM implementation proposals, the cross-cutting
Patrol verification plan, the future GST workflow plan, and the VPS landing/privacy
launch plan:

| Plan Directory | Focus Area | Key Architectural Deliverables |
| :--- | :--- | :--- |
| **[`play-launch-then-cloud-direction/`](play-launch-then-cloud-direction/plan.md)** | **SUPERSEDED (2026-09-30) — historical record** | The reversed Play-first decision, preserved for history. Its §1 order, §3.3 "the launch is free" claim, §3.6 pin, §5 priority order, and §7 checklist are **not operative**. What still applies: signing-key custody, the Play app-signing fingerprint for asset links, copy never leading implementation, no unearned free/cap promises, and the safe-restore and off-device-backup data-safety findings — now sequenced by the canonical plan's §9.2 and Gate 15. No item is complete. |
| **[`cloud-authoritative-offline-first-saas/`](cloud-authoritative-offline-first-saas/plan.md)** | **Canonical Overall Direction & Cloud-Authoritative, Offline-First Multi-Tenant SaaS (TARGET, not implemented)** | Approved target architecture: cloud ledger as system of record, SQLite as local cache plus durable mutation outbox, organizations and owner/manager/collector roles, server-side authorization and tenant isolation, globally stable ids, revisions and tombstones, idempotent sync with **permanent-rejection quarantine** and **blocking of reset/export/restore while unsynced**, **server-derived billing periods in the organization timezone (default `Asia/Kolkata`)**, append-only financial history with an immutable audit log, **local-cache security review** (keystore-backed tokens, cache-encryption threat model, app lock, secure export), migration blockers, staged rollout (§9, including **account/org/cloud-first public onboarding**, a **free entry path whose boundaries and limits stay provisional pending the commercial gate (Gate 13)**, and an **optional verified claim/import path for existing local, test, and sideload ledgers** with no coercive paid migration, no data loss, and no double counting), DR, and explicit launch gates (§11), where **Gates 1–14 close before the public Google Play release (Gate 15)**. **Every checklist item is unchecked; Stage 0 is the only complete stage; the backend vendor is an open decision that blocks provider-dependent work only, so Stage 1 local foundations may start before it closes.** It supersedes the Convex-specific target claims in `product.md` and `docs/05-product-architecture-and-roadmap.md`. |
| **[`monorepo-cbk-edge/`](monorepo-cbk-edge/plan.md)** | **Monorepo & CBK Edge Vertical Slice** | Additive Bun workspaces, shared referral contracts, privacy-safe Cloudflare Worker landing/referral routes, Android asset links, and independent CI. |
| **[`cbk-vps-landing-launch/`](cbk-vps-landing-launch/plan.md)** | **VPS Landing, Privacy & Launch** | Truthful no-JS landing page with honest Google Play availability states, `/privacy` policy, a Bun runtime adapter around `handleRequest`, versioned systemd/nginx deployment assets, and shared claim scanning for customer-facing copy. |
| **[`gtm-in-app-viral-receipts/`](gtm-in-app-viral-receipts/plan.md)** | **Viral Loop & WhatsApp Receipts** | SQLite v7 phone-index migration, native Android `whatsapp://send` intent engine, five-language templates, and a referral footer linked to the separate CBK edge plan. The footer links to the **landing/referral URL, not Google Play**; a Play install CTA is blocked until Gate 15 and the footer's copy is blocked until Gate 13. |
| **[`gtm-freemium-paywall-licensing/`](gtm-freemium-paywall-licensing/plan.md)** | **Freemium Paywall & Licensing — device-authoritative model OBSOLETE, checklist DEPENDS ON Gate 13** | A retained sketch of the 100-subscriber device-local cap, MSO bulk import grace gate, vernacular upgrade bottom sheet, and Ed25519 offline token. The cap and the token-as-authority are **nonoperative** for the SaaS target; the token becomes a cached, expiring grant under **server-side entitlements** decided at Gate 13, and §4 must be rewritten at that gate before any item is treated as work. Nothing is implemented and no item is complete. |
| **[`gtm-upi-checkout-edge-pipeline/`](gtm-upi-checkout-edge-pipeline/plan.md)** | **1-Tap UPI Checkout & Edge Worker — NON-NORMATIVE, BLOCKED BY Gate 1** | Cloudflare edge gateway, Android UPI intent (PhonePe/GPay), and Razorpay HMAC webhook verification are reusable provider-neutral seams. Its Convex plan-state mutation, bindings, and schema are **non-normative placeholders**: no backend vendor is selected, and the post-payment plan-state write stays deliberately **undefined** rather than being replaced with an invented generic endpoint. |
| **[`gtm-vernacular-localization/`](gtm-vernacular-localization/plan.md)** | **Vernacular i18n Localization** | Five regional languages (Hindi, Marathi, Bengali, Tamil, English), reactive `AppLanguageService`, and grassroots jargon matrix (*bahi-khata, line boy, baqaya*). The matrix's `backup_cloud` key and its paywall/price CTA strings are **blocked drafts**: no cloud-capability claim (the app is local-only) and no price, tier, or cap claim before Gate 13. |
| **[`gtm-android-release-aso-pipeline/`](gtm-android-release-aso-pipeline/plan.md)** | **Android Release & ASO Pipeline** | $<15\text{MB}$ AAB optimization (R8 shrinking, ProGuard), locally implemented strict `/import` and `/r/{code}` App Link routing with Digital Asset Links still pending domain verification, and the regional Play Store metadata generator that is the **canonical** listing copy. All publishing runs at **Gate 15**, after Gates 1–14; there is no `/paywall` route and no upload before then. |
| **[`gtm-outbound-scraping-campaign-cli/`](gtm-outbound-scraping-campaign-cli/plan.md)** | **Outbound Scraping CLI (Bun) — DEFERRED until after Gate 15** | A retained sketch of a Bun TypeScript CLI pipeline ingesting public TRAI/association directories, normalizing Indian mobiles (+91 E.164), MSO brand tagging, and staged WhatsApp outreach queues. It is **not an active objective** and must not be repurposed as invited testing or as Gate 13 evidence. Nothing is implemented. |
| **[`gtm-acquisition-telemetry-funnel/`](gtm-acquisition-telemetry-funnel/plan.md)** | **Acquisition & Funnel Telemetry** | Implemented local SQLite event buffer (`analytics_events`), milestone funnel events, battery-friendly edge beacon flush, Worker ingestion, and zero-PII guards; production deployment and device verification remain pending. |
| **[`patrol-e2e/`](patrol-e2e/plan.md)** | **Patrol Android E2E Coverage** | Ten deterministic app journeys using production bootstrap, app widgets, SQLite, and shared preferences; compilation evidence is separated from pending current-source device execution and external-only native scenarios. |
| **[`india-gst-billing-and-invoicing/`](india-gst-billing-and-invoicing/plan.md)** | **Future India GST Billing and Invoicing** | Future-only, offline-first GST/tax-invoice design for unregistered, regular, and composition modes, explicitly requiring Indian CA/legal review and implementing no GST capability today. |


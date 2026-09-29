# Collection Book: Master Strategic & Technical Documentation

This directory contains the verified market data, customer research synthesis, go-to-market playbooks, pricing models, and technical architecture specifications for **Collection Book**.

> **Current vs. target product.** The shipped app is a **local-authoritative, offline-first
> Android app** with no account, cloud ledger, or sync. The approved **target** is an
> **offline-capable, cloud-authoritative, multi-tenant SaaS** in which the cloud ledger
> is the system of record and SQLite becomes a local cache plus mutation outbox. That
> target is documented and **not implemented**, and the backend vendor is an open
> decision. See [`plans/cloud-authoritative-offline-first-saas/plan.md`](plans/cloud-authoritative-offline-first-saas/plan.md).
>
> **Overall direction (SaaS-first, 2026-09-30).** Build the cloud target and close
> Stages 0–8 and Gates 1–14 **before** the app is published on Google Play; cloud Stage 1
> is a pre-launch item (it is the local counterpart of Gates 2–5) and the Gate 1 vendor
> decision runs in parallel. The public release is **Gate 15, after Stage 8**; Stage 8
> prepares and reviews the launch material and Gate 15 publishes it. The earlier
> "launch the local-only app first" decision is **superseded** and retained as history in
> [`plans/play-launch-then-cloud-direction/plan.md`](plans/play-launch-then-cloud-direction/plan.md).
> The canonical order is
> [`plans/cloud-authoritative-offline-first-saas/plan.md`](plans/cloud-authoritative-offline-first-saas/plan.md)
> §9–§11.

---

## Documentation Index

| File | Title | Summary & Key Decisions |
| :--- | :--- | :--- |
| **[01-market-and-competitor-intelligence.md](01-market-and-competitor-intelligence.md)** | **Market & Competitor Intelligence** | Regulatory data from TRAI (48M wired broadband base) and AIDCF-EY (85k active LCOs). Verified competitor metrics for BixApp (100k+ installs) and Mobiezy (₹2,542–₹3,559/yr pricing). Explains why Google Ads fails (₹65–₹200 CPC) while Meta/WhatsApp succeeds. |
| **[02-customer-research-and-icp.md](02-customer-research-and-icp.md)** | **Customer Research & ICP Synthesis** | Corey Haines customer research framework. Jobs to Be Done (JTBD), field jargon dictionary (*bahi-khata, line boy, VC number, baqaya*), trigger events, and 3 distinct operator personas (Micro LCO, Hybrid Operator, Multi-Area Owner). |
| **[03-go-to-market-and-marketing-playbook.md](03-go-to-market-and-marketing-playbook.md)** | **GTM & Marketing Playbook** | 4-channel hybrid funnel for the offline-first operator: Meta Advantage+ Ads setup (targeting, ₹500/day budget, ₹12–₹25 CPI), YouTube Shorts strategy with full 30s scripts, multi-language Play Store ASO kit, and organic WhatsApp growth loops. |
| **[04-pricing-and-5k-customer-economics.md](04-pricing-and-5k-customer-economics.md)** | **Pricing Strategy & 5k Financials** | Three-tier freemium model: Free (100 subs), Starter (₹199/mo or ₹1,499/yr), and Pro (₹349/mo or ₹2,499/yr) — **all of it provisional until the commercial gate (Gate 13) closes**, including the free tier's 100-subscriber limit and every price. Financial model to 5,000 paying customers yielding **~₹90 Lakhs ($108k USD) ARR**. Its cost model rests on a **provisional, unselected** vendor assumption: the **working total of ~₹2,80,000/yr and working margin of >96.8%** are the same figures used in `product.md` §7.2, and both must be re-derived once the vendor gate in the [cloud-authoritative SaaS plan](plans/cloud-authoritative-offline-first-saas/plan.md) closes. No public copy may state a tier, a limit, or a price before that gate closes. |
| **[05-product-architecture-and-roadmap.md](05-product-architecture-and-roadmap.md)** | **Product Architecture & Roadmap** | Separates the **shipped** local-authoritative SQLite client (schema v8, no auth, no sync) from the **approved target** cloud-authoritative architecture: authority boundary, identity/tenancy/RBAC, sync contract (including permanent-rejection quarantine and destructive-action blocking), billing-period timezone attribution, local-cache security, financial audit rules, and the canonical Stage 0–8 rollout. The previous Convex-specific schema draft is marked superseded; the backend vendor is an open decision that blocks provider-dependent work only. |
| **[plans/](plans/)** | **Implementation Plans** | Directory for all technical, feature, and architectural implementation plans. **Each plan has its own dedicated directory** (see [plans/README.md](plans/README.md) and [agent.md](../agent.md)). Includes the canonical [Cloud-Authoritative Offline-First SaaS](plans/cloud-authoritative-offline-first-saas/plan.md) direction and staged rollout, the **superseded** [Play Launch Then Cloud](plans/play-launch-then-cloud-direction/plan.md) decision (historical record; its release mechanics and data-safety notes still apply), the [Monorepo & CBK Edge](plans/monorepo-cbk-edge/plan.md) vertical slice, the [VPS Landing & Privacy Launch](plans/cbk-vps-landing-launch/plan.md) surface, and 7 core GTM engineering plans: [Viral Receipts](plans/gtm-in-app-viral-receipts/plan.md), [Paywall & Licensing](plans/gtm-freemium-paywall-licensing/plan.md), [UPI Edge Pipeline](plans/gtm-upi-checkout-edge-pipeline/plan.md), [Vernacular i18n](plans/gtm-vernacular-localization/plan.md), [Release & ASO](plans/gtm-android-release-aso-pipeline/plan.md), [Outbound CLI](plans/gtm-outbound-scraping-campaign-cli/plan.md), and [Funnel Telemetry](plans/gtm-acquisition-telemetry-funnel/plan.md). |


---

## Executive Summary of Strategic Judgments

1. **Target Audience Reality**:
   * Indian local cable and broadband operators do not use email or tech blogs. Outreach must be driven through **direct WhatsApp video demos**, **regional YouTube Shorts**, **Facebook/Instagram Reels**, and **Play Store ASO**.
2. **Pricing Disruption**:
   * Incumbents (BixApp, Mobiezy) lock operators into expensive, high-friction annual sales calls (₹3,000–₹6,000/yr). The intended disruption is an **affordable free entry path (provisional, boundary and limit undecided until the commercial gate)** with a self-serve paid tier and instant UPI checkout. Until that gate closes, this is strategy intent only: no landing page, listing, script, or receipt may state "100% free", "free forever", a limit, or a price.
3. **Core Architectural Differentiator**:
   * Offline-first field operation is the moat: a collector on a 2G link or with no signal records a payment instantly, and the built-in MSO parser imports existing customer bases in seconds.
   * **Target state (approved, not built):** the cloud ledger becomes the system of record and SQLite becomes a local cache plus mutation outbox, so the offline guarantee is preserved while adding multi-device, multi-user, and auditable financial history. The backend vendor is an open decision that blocks provider-dependent work only; Stage 1 local foundations may start before it closes, and Stage 1 now runs **before** the public Play release. See [`plans/cloud-authoritative-offline-first-saas/plan.md`](plans/cloud-authoritative-offline-first-saas/plan.md).
4. **Regional Language Priority**:
   * English-only products fail in Tier 2/3/4 India. Full support for **Hindi, Marathi, Bengali, and Tamil** is essential for both in-app adoption and Play Store search conversion.

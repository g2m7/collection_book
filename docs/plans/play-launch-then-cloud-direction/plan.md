# Plan: Project Direction — Play Launch First, Then the Cloud SaaS

**Status:** Approved as the **overall project direction** on 2026-09-27. This document
records a sequencing decision. It does not implement anything by itself. Only the
"direction recorded" item in §7 is complete; every implementation, release, and external
item is unchecked until evidence exists.

**Precedence:** This is the top-level ordering rule for the whole repository. When plans
compete for effort, this document decides the order. It does not change the target
architecture in
[`../cloud-authoritative-offline-first-saas/plan.md`](../cloud-authoritative-offline-first-saas/plan.md);
it decides *when* its stages run relative to the Google Play launch.

---

## 1. Decision

The project runs on two tracks, in this order of priority:

1. **Track A — Launch the current app on Google Play now.** The shipped
   local-authoritative, offline-first Android app is released as a **free** app, with
   truthful copy that describes a local-only app. No account, cloud, sync, paid plan, or
   subscriber cap is added for this launch.
2. **Track B — Build the cloud-authoritative SaaS after and alongside the launch.** The
   first update after launch is **Stage 1 (local data foundations)** of the cloud plan.
   The backend vendor decision (Gate 1) runs in parallel so Stages 2–4 can start as soon
   as Stage 1 is out.

The alternative, holding the Play launch until the cloud version is ready, was rejected.
The cloud plan has every gate unchecked and Gate 1 open, so the cloud version is months
away, not weeks.

## 2. Rationale

- **The offline app is the cloud plan's offline client.** Launching it does not throw
  work away; the cloud plan keeps the local app and turns its SQLite database into a
  cache plus outbox.
- **Real operators replace guesses.** Pricing, the free-tier size, and the need for
  multiple collectors are assumptions today. Actual usage should shape which cloud
  features come first and what operators will pay for.
- **The slow steps are external.** Play Console review, a possible closed-testing period,
  native-speaker review of the vernacular listings, and screenshots take calendar time.
  Starting them now overlaps that waiting with engineering work.
- **Public copy already matches the shipped app.** The landing page, `/privacy`, and the
  generated Play listing describe a local-only app, and the shared claim scanner blocks
  cap, free-tier, and cloud-sync promises.
- **Receipts bring in new operators.** Every WhatsApp receipt carries the landing-page
  link, which builds an install base while the cloud work proceeds.

## 3. Launch Guardrails (binding for Track A)

These conditions apply to the Play launch and to every release until the cloud plan's
Stage 1 ships.

1. **Signing key custody.** Use Play App Signing. Keep the upload keystore and its
   passwords backed up in at least two separate secure places. Never commit
   `android/key.properties`, `*.jks`, or `*.keystore`. Losing the upload key disrupts
   updates.
2. **Asset-links fingerprint.** With Play App Signing, installs from Play are signed by
   Google's app-signing key, not the upload key. The value configured as
   `ANDROID_SHA256_CERT_FINGERPRINT` must be the **app-signing key SHA-256 shown in Play
   Console (App integrity)**. The handler currently publishes exactly one fingerprint
   (`services/cbk-edge/src/index.ts`), so an upload-key-signed sideloaded build will not
   verify at the same time. Supporting both keys needs a separate, tested handler change.
3. **Free, with no permanent promises.** The launch is free. No copy may promise "free
   forever", an unlimited plan, or a specific subscriber cap. The existing
   `findUnsupportedClaims` scanner and its tests remain the enforcement point.
4. **Copy never leads implementation.** Landing, `/privacy`, the Play listing, the Play
   data-safety form, and receipts describe only the shipped local-only behavior.
5. **Do not deepen the cloud migration blockers.** Until Stage 1 ships, new work must not
   add `REAL`/`double` money columns, new device-scoped autoincrement identities for
   syncable records, or new hard-delete paths for financial records. Each one adds work
   to the later ledger migration (cloud plan §2.1, Stage 6).
6. **Stage 1 is the first post-launch update.** Every install creates a local ledger
   that Stage 6 must later claim. Converting money to integer paise and adding global
   ids is safest while the installed base is small, so Stage 1 ships before growth
   work (paid acquisition, outbound campaigns) scales up.

## 4. Pre-Launch Data-Safety Fixes (required before publishing)

The shipped ledger exists only on the phone. Current code facts, as of 2026-09-27:

- `android:allowBackup="false"`, so Android backup never copies the database.
- Automatic and "Backup now" copies are written under the app's documents directory
  (`RentLedgerBackups/`), which is removed on uninstall and is lost with the phone. Only
  **Share backup** moves a copy off the device.
- `DatabaseService.replaceDatabase` deletes the live database **before** copying the
  picked file, performs no integrity, schema-version, or content check, and reopens the
  file without `version`/`onUpgrade`. A wrong, corrupt, or newer-schema file can
  therefore replace the only ledger with no way back.

Required fixes before the Play release:

1. **Safe restore.** Validate a picked file before touching the live database (SQLite
   integrity check, expected tables, schema version not newer than the app), keep the
   current database until the replacement is proven good, roll back on failure, and
   reopen through the normal migration path.
2. **Off-device backup reminder.** Make Share backup easy to find and remind the operator
   to keep an off-device copy, with concise, localized copy in all five languages and
   no claim of cloud storage.
3. **Tests.** Deterministic unit/widget tests for the restore validation and rollback,
   plus Patrol coverage and stable `lib/app_keys.dart` selectors for any new
   user-visible flow, per `AGENTS.md`.

Each fix needs its own implementation plan directory or an explicit addition to an
existing plan before code starts.

## 5. Priority Order for All Work

When choosing what to work on, use this order. An item lower in the list does not start
at the expense of an unfinished item above it, except external waits, which run in
parallel.

| Priority | Work | Owning plan |
| :--- | :--- | :--- |
| 1 | Pre-launch data-safety fixes (§4) | New plan(s) under `docs/plans/` |
| 2 | Play release: signing, AAB size check, listing review, screenshots, data-safety form, publish, `PLAY_STORE_URL`, fingerprint | [`gtm-android-release-aso-pipeline`](../gtm-android-release-aso-pipeline/plan.md), [`cbk-vps-landing-launch`](../cbk-vps-landing-launch/plan.md) |
| 3 | Manual device checks: receipts with and without WhatsApp, verified App Link on the signed build, five-language visual pass, landing page on real phones and dark mode | [`gtm-in-app-viral-receipts`](../gtm-in-app-viral-receipts/plan.md), [`gtm-vernacular-localization`](../gtm-vernacular-localization/plan.md), [`cbk-vps-landing-launch`](../cbk-vps-landing-launch/plan.md) |
| 4 | Stage 1 local data foundations (Gates 2–5), shipped as the first post-launch update | [`cloud-authoritative-offline-first-saas`](../cloud-authoritative-offline-first-saas/plan.md) |
| 5 | Gate 1 backend vendor decision (decision work, parallel from now) | [`cloud-authoritative-offline-first-saas`](../cloud-authoritative-offline-first-saas/plan.md) |
| 6 | Cloud Stages 2–8 in the canonical order | [`cloud-authoritative-offline-first-saas`](../cloud-authoritative-offline-first-saas/plan.md) |

**Not part of the Play launch:**

- [`gtm-freemium-paywall-licensing`](../gtm-freemium-paywall-licensing/plan.md) and
  [`gtm-upi-checkout-edge-pipeline`](../gtm-upi-checkout-edge-pipeline/plan.md). Paid
  plans arrive with cloud Stage 8 and server-side entitlements (Gate 13). Building the
  device-local paywall earlier requires an explicit, separately approved decision.
- [`gtm-outbound-scraping-campaign-cli`](../gtm-outbound-scraping-campaign-cli/plan.md)
  and paid acquisition at scale. These wait until Stage 1 ships (§3.6).
- [`india-gst-billing-and-invoicing`](../india-gst-billing-and-invoicing/plan.md). It
  stays future-only; it depends on integer-paise money and append-only history anyway.
- A VPS telemetry sink. The app keeps its queue while the endpoint answers `503`; adding
  a sink needs a separate approved decision and is not a launch blocker.

## 6. What Changes and What Does Not

- **Unchanged:** the cloud plan's target architecture, stage numbers, gates, and open
  decisions; all repository rules in `AGENTS.md`; the requirement that customer-facing
  copy is updated only in the release that makes a capability true.
- **Changed:** the relative order of work. The Play launch comes first, and Stage 1 is
  pinned as the first post-launch update rather than floating.
- **Stage 6 population:** the existing local ledgers that Stage 6 must migrate are
  exactly the Play installs created under this direction. Stage 6 must support ledgers
  created both before and after the Stage 1 update.

## 7. Checklist

### Direction

- [x] Record the direction, guardrails, and priority order, and point `AGENTS.md`,
      `product.md`, `README.md`, `docs/INDEX.md`, `docs/05-product-architecture-and-roadmap.md`,
      `docs/plans/README.md`, and the affected plans at this document.

### Track A — pre-launch fixes

- [ ] Plan, implement, and test safe restore (§4.1).
- [ ] Plan, implement, and test the off-device backup reminder in five languages (§4.2).
- [ ] Update Patrol journeys and app keys for the new flows; run `patrol test` on a device
      or record the run as pending.

### Track A — release

- [ ] Create the upload keystore and ignored `android/key.properties`; back up the key
      and passwords in two secure places.
- [ ] Build the signed release AAB and verify it is under 15 MB.
- [ ] Create the Play Console app with Play App Signing, and complete the listing,
      content rating, privacy URL (`https://cbk.sarbaa.com/privacy`), and data-safety form
      to match the shipped behavior.
- [ ] Native-speaker review of the `hi-IN`, `mr-IN`, `bn-IN`, and `ta-IN` listings.
- [ ] Produce the 1080x1920 vernacular screenshots.
- [ ] Complete any closed-testing requirement Google applies to the developer account.
- [ ] Publish to production.
- [ ] Set `PLAY_STORE_URL` on the VPS and confirm the landing page shows the download
      call to action.
- [ ] Configure the Play app-signing SHA-256 as `ANDROID_SHA256_CERT_FINGERPRINT` and
      verify `/.well-known/assetlinks.json` and the `/r/{code}` and `/import` App Links
      on a Play-installed build.
- [ ] Complete the manual device checks in §5 priority 3 and record device, Android
      version, and result.

### Track B — first post-launch update

- [ ] Ship cloud Stage 1 (Gates 2–5) as the first update after launch, with migration
      tests from the launched schema.
- [ ] Record the Gate 1 backend vendor decision.

## 8. Verification

- Documentation-only change: `git diff --check`, link review, and a consistency check
  that no plan checkbox outside §7 "Direction" was marked complete.
- Track A and Track B items are verified under their owning plans with the gates in
  `AGENTS.md` (Flutter format, analyze, tests, Patrol compile gate and device runs; Bun
  format, typecheck, tests, Worker dry-run).

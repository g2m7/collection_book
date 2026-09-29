# Plan: Project Direction — Play Launch First, Then the Cloud SaaS

> # ⚠️ SUPERSEDED — HISTORICAL RECORD ONLY (superseded 2026-09-30)
>
> **Do not follow the ordering in this document.** The approved overall direction is now
> **SaaS-first**: the cloud-authoritative product is built, and its rollout **Stages 0–8
> and Gates 1–14** close **before** the public Google Play release, which is **Gate 15**
> of the canonical plan. The canonical overall direction, staged rollout, and launch
> gates live in
> [`../cloud-authoritative-offline-first-saas/plan.md`](../cloud-authoritative-offline-first-saas/plan.md).
>
> **Why it was superseded:** publishing the local-only app first would build an installed
> base with no account, no organization, no cloud ledger, and no settled pricing. A
> later **forced** account, pricing, and data migration would then burden the exact
> operators the product exists to serve — and would risk charging for money they already
> recorded, or losing it.
>
> **What still stands:** the factual parts — the §2 rationale inputs, the still-valid §3
> release mechanics (**items 1, 2, 4, and 5** only: signing-key custody, the Play
> app-signing asset-links fingerprint, copy never leading implementation, and no new
> migration blockers), and the §4 data-safety findings and required fixes. These are
> re-stated as release-time requirements in the canonical plan and in
> [`../gtm-android-release-aso-pipeline/plan.md`](../gtm-android-release-aso-pipeline/plan.md).
>
> **What is not operative:** §1 (the two-track order), §3.3's "the launch is free"
> claim (superseded — see §3.3 below), §5 (the priority order), §3.6
> (the Stage-1-after-launch pin), and §7 (the checklist). They are preserved below as
> history. **Do not cite §5 or §3.6 as a priority order or a sequencing rule**, and do not
> infer from any unchecked item below that the work is still approved.

**Original status (2026-09-27, historical):** Approved then as the overall project
direction. This document records a sequencing decision and implemented nothing by itself.
Only the "direction recorded" item in §7 was checked; every implementation, release, and
external item is unchecked and remains unchecked.

---

## 1. Decision (HISTORICAL — superseded, do not apply)

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

> **Reversed 2026-09-30.** The rejected alternative is now the approved order. The delay
> argument is outweighed by the cost of a later forced account, pricing, and data
> migration on operators who already recorded their money locally.

## 2. Rationale (HISTORICAL — the reasoning behind the superseded order)

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

## 3. Launch Guardrails (HISTORICAL section — items 1, 2, 4, and 5 remain valid release guidance; items 3 and 6 are not operative)

The mechanics in items 1, 2, 4, and 5 still apply whenever the Play release happens,
including a private or test-track build. Item 3 is **superseded** (its "the launch is
free" statement is not a public claim under the current direction; see below). Item 6 is
**superseded**: cloud Stage 1 is no longer "the first post-launch update"; it is work
that happens before the public Play launch.

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
3. ~~**Free, with no permanent promises.** The launch is free.~~ **SUPERSEDED
   2026-09-30.** "The launch is free" described the *local-only* launch this document
   ordered, and that launch no longer happens. The public product is the cloud SaaS, and
   its entry path is now: **retain an affordable free entry path**, with the exact
   boundaries, limits, and prices decided from evidence at the commercial gate (Gate 13
   of the canonical plan). That is **not** an approved promise of permanent or unlimited
   use, and **no copy may state a free tier, "free forever", "no limits", a price, or a
   subscriber cap** until Gate 13 closes and the claim scanner in
   `packages/contracts/` and the Play metadata scanner agree with it. A downgrade must
   still leave authorized members able to **read and export the records they already
   have** (canonical plan §1.2).
4. **Copy never leads implementation.** Landing, `/privacy`, the Play listing, the Play
   data-safety form, and receipts describe only the shipped local-only behavior.
5. **Do not deepen the cloud migration blockers.** Until Stage 1 ships, new work must not
   add `REAL`/`double` money columns, new device-scoped autoincrement identities for
   syncable records, or new hard-delete paths for financial records. Each one adds work
   to the later ledger migration (cloud plan §2.1, Stage 6).
6. ~~**Stage 1 is the first post-launch update.**~~ **SUPERSEDED 2026-09-30.** The public
   Play launch now happens *after* cloud Stage 1 and Gates 1–14, so the local-only
   schema is not published at scale before its migration blockers are removed. An
   *internal, private-track, or invited-test* build may still be used for local
   testing, and any data such a build creates needs the optional, verified claim/import
   path required by the canonical plan — no coercive paid migration, no data loss, no
   double counting.

## 4. Data-Safety Fixes (findings still valid; ordering rescoped by the canonical plan)

The shipped ledger exists only on the phone. Current code facts, as of 2026-09-27:

- `android:allowBackup="false"`, so Android backup never copies the database.
- Automatic and "Backup now" copies are written under the app's documents directory
  (`RentLedgerBackups/`), which is removed on uninstall and is lost with the phone. Only
  **Share backup** moves a copy off the device.
- `DatabaseService.replaceDatabase` deletes the live database **before** copying the
  picked file, performs no integrity, schema-version, or content check, and reopens the
  file without `version`/`onUpgrade`. A wrong, corrupt, or newer-schema file can
  therefore replace the only ledger with no way back.

Required fixes, and their rescoped ordering under the canonical plan (see the banner and
[`../cloud-authoritative-offline-first-saas/plan.md`](../cloud-authoritative-offline-first-saas/plan.md)
§9): safe restore and the off-device backup reminder are **prerequisites**, and must ship
**before the public Google Play release** (Gate 15), **before any real-money invited
external test** that puts an operator's own collected cash behind the app (Play
private-track, closed-test, or invited-tester builds), and **before the claim/import
path** (§9.2 of the canonical plan) opens an external-data path for existing ledgers.
They are not a later gate's deliverable: synthetic fixtures, internal use, and internal
testing may inform the commercial gate (Gate 13) beforehand, and Gate 14 re-verifies the
already-shipped fixes on a real device.

**Current risk, recorded honestly:** the shipped app already exposes both edges today —
**Share backup** moves a database copy off the device, and the restore path replaces the
only copy of the live ledger with a picked file that is not yet validated. Neither fix is
implemented. Until they ship, external sharing and restore on the shipped build remain
unsafe for an operator's real data, and that risk is open, not closed by this plan.

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

## 5. Priority Order for All Work (SUPERSEDED — NOT OPERATIVE)

> **Superseded 2026-09-30.** The order this document encoded is the Play-first order, and
> it is **withdrawn as an instruction**. The old numbered priority table has been removed
> so that no skimmable row can be read as a work order: the Play release used to be
> priority 2 with cloud Stage 1 at priority 4, which is the exact inversion the supersession
> reverses. The **only** operative order is the stage and gate sequence in
> [`../cloud-authoritative-offline-first-saas/plan.md`](../cloud-authoritative-offline-first-saas/plan.md)
> §9 and §11: cloud Stage 1 (the local counterpart of Gates 2–5) and Gates 1–14 come
> **before** the public Play release, which is **Gate 15** and publishes what Stage 8
> prepares and reviews.

What the removed table recorded, as history only:

- The **data-safety fixes in §4** (safe restore, off-device backup reminder) are still
  required, and they now come **before any real-money invited external test** — not at a
  later gate — per the canonical plan §9.2.
- The **Play release mechanics** (signing custody, AAB size check, listing, screenshots,
  data-safety form, publish, `PLAY_STORE_URL`, app-signing fingerprint, and manual device
  checks) are still required and still pending, and they are **Gate 15** of the canonical
  plan, not an early step.
- The **manual device checks** (receipts with and without WhatsApp, verified App Link on
  the signed build, five-language visual pass, landing page on real phones and dark mode)
  are still required, and are likewise Gate 15 work.
- **Stage 1 local data foundations** are a **pre-launch** item, not the first post-launch
  update, and the **Gate 1 vendor decision** is parallel decision work.

Work that is **not** part of the launch is listed in the canonical plan's §12 dependency
table, which is the authoritative statement of what each other plan waits for. In
particular:

- [`gtm-freemium-paywall-licensing`](../gtm-freemium-paywall-licensing/plan.md) and
  [`gtm-upi-checkout-edge-pipeline`](../gtm-upi-checkout-edge-pipeline/plan.md). Paid
  plans arrive with cloud Stage 8 and server-side entitlements (Gate 13). Building the
  device-local paywall earlier requires an explicit, separately approved decision.
- [`gtm-outbound-scraping-campaign-cli`](../gtm-outbound-scraping-campaign-cli/plan.md)
  and paid acquisition at scale stay deferred, per the canonical plan §12.
- [`india-gst-billing-and-invoicing`](../india-gst-billing-and-invoicing/plan.md). It
  stays future-only; it depends on integer-paise money and append-only history anyway.
- A VPS telemetry sink. The app keeps its queue while the endpoint answers `503`; adding
  a sink needs a separate approved decision and is not a launch blocker.

## 6. What Changes and What Does Not (HISTORICAL)

> Superseded with the rest of this document. Its "unchanged / changed" split described the
> Play-first decision and no longer describes the current work.

- **Unchanged:** the cloud plan's target architecture, stage numbers, gates, and open
  decisions; all repository rules in `AGENTS.md`; the requirement that customer-facing
  copy is updated only in the release that makes a capability true.
- **Changed:** the relative order of work. Under this decision the Play launch came
  first and Stage 1 was pinned as the first post-launch update; that order is now
  reversed (§5).
- **Stage 6 population (still applicable):** the existing local ledgers Stage 6 must
  migrate are no longer the Play installs this document created, because that launch
  never happened. Stage 6 must support ledgers created from developer/test/sideload
  builds and from the eventual public release, on both sides of the Stage 1 update.

## 7. Checklist (SUPERSEDED — NOT OPERATIVE)

> **Superseded 2026-09-30.** Nothing below is an approved task list. The order it encodes
> (Play first, cloud Stage 1 after) no longer holds, and no item below is authorized by
> this document. The current, operative work order is the stage/gate sequence in
> [`../cloud-authoritative-offline-first-saas/plan.md`](../cloud-authoritative-offline-first-saas/plan.md)
> §9–§11. The Play mechanics and release steps below are still the required mechanics
> **when** the release happens (they are Gate 15 of the canonical plan), and remain
> pending.

### Direction (historical)

- [x] Historical record: the Play-first direction, guardrails, and priority order were
      documented and linked on 2026-09-27. Those pointers were replaced when this
      direction was superseded on 2026-09-30; this checkbox records past documentation
      work, not a current instruction or a completed implementation gate.

### Track A — pre-launch fixes (historical labels; still required, still pending)

> These two fixes are **prerequisites before any real-money invited external test**, not a
> later gate's deliverable (canonical plan §9.2). They are also re-verified at Gate 14.

- [ ] Plan, implement, and test safe restore (§4.1).
- [ ] Plan, implement, and test the off-device backup reminder in five languages (§4.2).
- [ ] Update Patrol journeys and app keys for the new flows; run `patrol test` on a device
      or record the run as pending.

### Track A — release (still pending; now after Stages 0–8 and Gates 1–14)

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
- [ ] Complete the manual device checks listed in §5 (receipts with and without WhatsApp,
      verified App Link on the signed build, five-language visual pass, landing page on
      real phones and dark mode) and record device, Android version, and result.

### Track B — first post-launch update (historical labels; the "post-launch" framing is superseded)

- [ ] Ship cloud Stage 1 (Gates 2–5) — now a **pre-launch** item, with migration tests
      from the local/test/sideload schema.
- [ ] Record the Gate 1 backend vendor decision.

## 8. Verification (HISTORICAL)

> The check below describes how this document's own supersession was recorded. The
> canonical plan carries verification for the current direction.

- Documentation-only change: `git diff --check`, link review, and a consistency check
  that no plan checkbox outside §7 "Direction" was marked complete.
- Track A and Track B items are verified under their owning plans with the gates in
  `AGENTS.md` (Flutter format, analyze, tests, Patrol compile gate and device runs; Bun
  format, typecheck, tests, Worker dry-run).

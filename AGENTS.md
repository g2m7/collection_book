# AGENTS.md

Canonical repository contract for the Collection Book Flutter app and its additive Bun/Cloudflare monorepo. `agent.md` is only a pointer to this file.

## Repository Map

| Path | Scope |
| --- | --- |
| `lib/`, `test/`, `patrol_test/`, `assets/`, `pubspec.yaml` | Root Flutter application, lower-layer tests, and Patrol E2E tests |
| `android/`, `ios/` | Root Flutter platform projects |
| `packages/contracts/` | Shared TypeScript domain contracts and constants |
| `packages/play-store-metadata/` | Canonical five-language Play Store listing text and its `aso:generate` / `aso:check` Bun CLI |
| `services/` | Deployable services; `services/cbk-edge/` is the Worker |
| `docs/plans/<plan-name>/` | One directory and `plan.md` per plan |
| `product.md` | Product requirements and source product information |
| `.github/workflows/ci.yml` | Independent Flutter and Bun verification jobs |

The Flutter app stays at repository root. Do not move `lib/`, `test/`, `android/`, `ios/`, `assets/`, `pubspec.yaml`, or platform projects into a workspace package.

## Project Direction

The canonical overall direction is `docs/plans/cloud-authoritative-offline-first-saas/plan.md`, including its staged rollout (§9) and launch gates (§11). Read it before choosing what to work on. The earlier "launch the local-only app on Google Play first" decision in `docs/plans/play-launch-then-cloud-direction/plan.md` is **superseded** and is a historical record only; do not follow its §1, §3.6, §5, or §7.

1. **SaaS-first:** build the cloud-authoritative offline-first SaaS. Cloud Stage 1 (local data foundations) comes **before** the public Google Play launch, and **Stages 0–8 and Gates 1–14 close before the public Play release**, which is Gate 15. The local-only app is not published publicly first. Stage 1 is the local counterpart of Gates 2–5, and Stage 8 only **prepares and reviews** the launch material — **Gate 15 publishes it**.
2. **Gate 1 runs in parallel:** the backend vendor decision is decision work and does not block Stage 1 or any other vendor-neutral work.
3. **Play release work is late-stage and still pending:** signing, the Play app-signing asset-links fingerprint, the listing, screenshots, the data-safety form, publish, `PLAY_STORE_URL`, and manual device checks happen at the public release gate, not before it.
4. **Public onboarding is account/organization/cloud-first,** with offline writes and an explicit, visible unsynced-risk indicator. The **free entry path is retained** as an affordable entry, but its boundaries, any limits, and the paid prices around it stay **provisional** until the commercial gate (Gate 13) closes; no copy may promise "free forever", state a price, or name a specific subscriber cap, and a downgrade must still leave authorized members able to read and export records they already have. Existing local/test/sideload data needs an **optional, verified** claim/import path with no coercive paid migration, no data loss, and no double counting.
5. **Until Stage 1 ships,** do not add `REAL`/`double` money columns, new device-scoped autoincrement identities for syncable records, or new hard-delete paths for financial records.
6. **Keep shipped copy truthful.** The landing page, `/privacy`, and the Play Store metadata describe the shipped local-only app until the cloud capability is real, and the privacy and Play data-safety disclosures change **in the same release** that makes the capability true.

## Non-Negotiable Tooling and Planning Rules

1. **Bun only for TypeScript tooling:** use `bun` and `bunx`. Never use `npm`, `npx`, Yarn, or pnpm. Bun is pinned to 1.3.4 in the root manifest and CI.
2. **Dedicated plan directories:** every feature or architecture plan lives at `docs/plans/<descriptive-plan-name>/` with a primary `plan.md` or `README.md`. Never add a loose plan directly under `docs/` or `docs/plans/`.
3. **Update plans honestly:** mark only verified implementation complete. Keep deployment, DNS, secrets, signing fingerprints, and manual smoke checks pending until performed.
4. **Focused changes:** preserve unrelated work. Do not stash, reset, broadly rewrite, stage, or commit unless the user explicitly requests it.
5. **No implicit architecture expansion:** do not add Convex, payments, telemetry ingestion, D1, outbound tooling, or other planned systems without an approved plan/task.

## Setup and Verification

### Flutter

- Install dependencies: `flutter pub get`
- Environment: `flutter doctor -v`
- Format check: `dart format --output=none --set-exit-if-changed lib test patrol_test`
- Analyze: `flutter analyze`
- Unit/widget tests: `flutter test`
- Patrol CLI: `dart pub global activate patrol_cli 4.8.0` (keep this version pinned)
- Patrol environment: `patrol doctor`
- Patrol Android compile gate: `patrol build android --debug` (optionally verify native assembly with `(cd android && ./gradlew :app:assembleDebugAndroidTest)` under JDK 17)
- Patrol device run: `patrol test` (select a device with `patrol test --device <device_id>` when multiple are connected)
- Debug APK: `flutter build apk --debug`
- Run: `flutter run` (or `flutter run -d <device_id>`)

Before completing an affected Flutter task, run the targeted tests plus `dart format` and `flutter analyze`. Changes to user-visible behavior require relevant Patrol journey updates; run `patrol test` when an Android device/emulator is available, otherwise keep execution honestly pending. Normal CI must pass the Patrol compile gate, but mandatory per-PR emulator execution is not required because hosted emulators are slow and can be flaky; the separately invokable CI job is opt-in. Keep documentation synchronized with behavior changes. Production Android release builds require real signing properties from ignored `android/key.properties`; relative `storeFile` values resolve from the `android/` root Gradle-project directory, and the debug signing key must never be used for a release artifact.

### Bun and Worker

From the repository root:

- Install workspace dependencies: `bun install`
- Format: `bun run format`
- Format check: `bun run format:check`
- Typecheck: `bun run typecheck`
- Tests: `bun test`
- Play listing metadata check: `bun run aso:check` (also inside `bun run verify:bun`)
- Worker dry-run build: `bun run build:worker`
- All Bun gates: `bun run verify:bun`
- All repository gates: `bun run verify:all`

The Wrangler dry-run must not deploy or change DNS. Disable Wrangler client metrics in local/CI commands where the tooling supports it.

## Flutter Conventions

Follow `flutter_lints` through `analysis_options.yaml`.

### Imports

Use this order:

1. Dart SDK (`dart:*`)
2. Packages (`package:*`)
3. Relative application files

Keep imports minimal.

### Types and Naming

- Public APIs and model fields use explicit types.
- Prefer `final`; use `var` only when the type is obvious and mutable.
- Nullability must be intentional.
- Types use `PascalCase`; methods, variables, and fields use `lowerCamelCase`; private members use `_` prefixes.
- Existing project enum values use lower camel case.

### UI

- Keep widgets small and composable.
- Use `const` where possible.
- Check `mounted` after awaits before navigation or UI updates.
- Keep SnackBars and dialogs concise and actionable.
- Use trailing commas in multiline constructors.

### Data and Services

- Reuse the singleton `DatabaseService`; do not introduce a second database abstraction.
- Use parameterized SQL, never interpolated untrusted input.
- Preserve migration compatibility in `onUpgrade`.
- Use transactions for multi-row and critical writes.
- Parse imports in isolation and never write during preview.
- Validate required identifiers and amounts before database writes.
- Service mode is `tv` or `fiber`; preserve service separation in queries, filters, imports, and upserts.

### Error Handling

Catch expected failures at file/database/device boundaries and surface useful messages. Imports must abort on invalid required data rather than silently writing partial records. Never swallow errors without a meaningful boundary response.

## TypeScript and Worker Conventions

### Packages and Services

- Shared reusable TypeScript belongs under `packages/`.
- Deployables belong under `services/`.
- Worker entrypoints export a small, testable request handler plus the native Worker default export.
- Keep Cloudflare platform APIs explicit and dependency-light.
- Use the strict root `tsconfig.json`; package configs narrow the included files.
- Keep deterministic tests in Bun (`bun:test`) near the owning package/service.

### `services/cbk-edge/`

- Canonical origin: `https://cbk.sarbaa.com`
- Referral path: `/r/{six-character-code}`
- Android package: `com.sarbaa.cbk`
- Referral code contract: exactly six uppercase ASCII alphanumeric characters (`[A-Z0-9]{6}`)
- Referral persistence is deferred. Valid clicks may log only `event`, `code`, `requestId`, and `timestamp`.
- Never log or persist IP addresses, user agents, subscriber/operator data, referral cookies, or secrets.
- Never invent an Android certificate fingerprint. Asset links remain `[]` without a valid configured SHA-256 fingerprint.
- Keep `PLAY_STORE_URL` restricted to the HTTPS `play.google.com/store/apps/details` listing and always force the Play target package to `com.sarbaa.cbk`.
- Do not deploy, create Cloudflare resources, or mutate DNS without explicit user approval.

## File-Specific Guidance

- `lib/services/import_service.dart`: keep format detection deterministic, parsing isolated, and preview side-effect free.
- `lib/services/database_service.dart`: keep queries parameterized, migrations safe, and service-filter summary paths consistent.
- `lib/screens/settings_screen.dart`: show visible progress for long settings operations.
- `lib/services/whatsapp_receipt_service.dart`: preserve valid referral URL behavior and do not add unrelated receipt features.
- `services/cbk-edge/src/`: keep routes bounded, cache-aware, method-aware, and protected by the shared security-header policy.

## Testing Guidance

Patrol is the repository standard for end-to-end coverage of implemented app surfaces. Keep a small number of complete journeys in `patrol_test/`, use `lib/app_keys.dart` for stable interactive selectors, and call the shared bootstrap before pumping `CollectionBookApp`. Do not call `WidgetsFlutterBinding.ensureInitialized()`, `runApp()`, or use arbitrary sleeps inside Patrol tests. Android test-orchestrator package clearing is the primary per-test isolation; keep the existing `DatabaseService` singleton.

Retain `test/` unit and widget tests for lower layers. Add or update tests for import format detection, required-field validation, service filtering, migration-sensitive logic, and backend route/security behavior. Prefer deterministic fixtures. Native file pickers, installed WhatsApp/browser handling, share targets, and physical-device behavior remain explicit opt-in/manual scenarios unless a deterministic fixture and device contract are available; never add a fake required test around them. The Worker suite must cover health, landing rendering, referral validation, cookie/redirect/referrer behavior, methods/404, asset links, headers, and injection resistance.

## Pre-Completion Checklist

- [ ] Relevant code and documentation are formatted.
- [ ] Flutter analyze, unit/widget tests, Patrol compile gate, and affected Patrol device journeys pass; any unavailable device-only run is explicitly identified.
- [ ] User-visible changes have updated Patrol coverage and stable production keys where needed.
- [ ] Bun format check, typecheck, tests, Play metadata check (`bun run aso:check`), and Worker dry-run pass.
- [ ] `git diff --check` passes.
- [ ] `git diff --cached` is empty unless the user explicitly authorized staging.
- [ ] No debug prints, placeholder code, fake metrics, fake fingerprints, or secrets remain.
- [ ] Plan checkboxes match actual implementation and external prerequisites remain pending.

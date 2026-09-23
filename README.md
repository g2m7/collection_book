# Collection Book

Collection Book is an offline-first subscriber, payment, and collection ledger for Indian local cable TV and fiber internet operators. The Flutter mobile app remains at the repository root. TypeScript workspaces are additive: reusable contracts live in `packages/`, and deployable services live in `services/`.

## Project Map

| Path | Purpose |
| --- | --- |
| `lib/`, `test/`, `assets/` | Flutter application, tests, and app assets |
| `android/`, `ios/` | Flutter platform projects |
| `product.md` | Product requirements and product copy source |
| `docs/` | Strategy, technical documentation, and plans |
| `docs/plans/<name>/plan.md` | One implementation or architecture plan per directory |
| `packages/contracts/` | Shared TypeScript domain contracts and canonical constants |
| `services/cbk-edge/` | Native Cloudflare Worker for `cbk.sarbaa.com` |
| `packages/contracts/src/index.ts` | Referral validation and canonical public/package constants |

## Prerequisites

- Flutter 3.29+ with Dart 3.9+
- Bun 1.3.4 for all TypeScript tooling
- A Cloudflare account and a zone containing `sarbaa.com` for deployment

**Use Bun only for TypeScript work. Do not use npm or npx.**

## Flutter Setup

```sh
flutter pub get
flutter doctor -v
flutter run
```

Useful checks:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

## Bun Workspace Setup and Checks

From the repository root:

```sh
bun install
bun run format:check
bun run typecheck
bun test
bun run build:worker
```

`bun run build:worker` invokes `wrangler deploy --dry-run` inside `services/cbk-edge`; it does not deploy the Worker or change DNS. Run `bun run verify:bun` for all TypeScript gates or `bun run verify:all` for the TypeScript and Flutter gates.

## Local cbk.sarbaa.com Backend

1. Create an untracked local file:

   ```sh
   cp services/cbk-edge/.dev.vars.example services/cbk-edge/.dev.vars
   ```

2. Edit `.dev.vars` as needed. Values are ignored when unset and are never loaded from the Flutter app.
3. Start Wrangler:

   ```sh
   bun run --cwd services/cbk-edge dev
   ```

4. Open the URL printed by Wrangler and check `/health`, `/`, `/r/AB12CD`, and `/.well-known/assetlinks.json`.

Configuration:

- `PLAY_STORE_URL`: optional HTTPS Google Play listing URL. The Worker always forces the target package to `com.sarbaa.cbk`. The safe default is `https://play.google.com/store/apps/details?id=com.sarbaa.cbk`.
- `ANDROID_SHA256_CERT_FINGERPRINT`: optional real Android signing-certificate SHA-256 fingerprint, with or without colon separators. Until a valid value is configured, asset links return `[]`; never place a fake fingerprint in source control.

`.dev.vars` is ignored. `.dev.vars.example` contains placeholders only.

### Route Summary

| Route | Behavior |
| --- | --- |
| `GET /health` | Bounded service/status/version JSON; no secrets |
| `GET /` | Self-contained mobile-first download landing page; valid `?ref=` codes are carried to the Play Store `referrer` parameter |
| `GET /r/:code` | Validates `[A-Z0-9]{6}`, emits a four-field privacy-safe log, sets a secure HttpOnly SameSite cookie, and redirects temporarily to `/?ref=CODE` |
| `GET /.well-known/assetlinks.json` | Returns `[]` without a valid fingerprint, otherwise declares `com.sarbaa.cbk` |
| Other `GET` paths | Bounded JSON 404 |
| Unsupported methods | JSON 405 with `Allow: GET` |

Referral click persistence, telemetry ingestion, payments, D1, Convex, and outbound tooling are intentionally not part of this slice.

## Release Signing and Asset Links

Production Android release builds must use a real upload/release key; the app intentionally does not fall back to the debug signing key.

```sh
cp android/key.properties.example android/key.properties
# Fill android/key.properties with the real local signing values.
flutter build appbundle --release
keytool -list -v -keystore /absolute/path/to/release-keystore.jks -alias YOUR_KEY_ALIAS
```

The `preReleaseBuild` Gradle task depends on `verifyReleaseSigning`, which fails when `android/key.properties` is incomplete or its keystore file is missing. `android/key.properties`, `*.jks`, and `*.keystore` are ignored. A relative `storeFile` value resolves from the `android/` directory (the root Gradle project), matching `android/key.properties.example`; an absolute path is also accepted. Record the `SHA256` value from the actual signing key and use that exact value for `ANDROID_SHA256_CERT_FINGERPRINT`; do not use the debug key fingerprint.

## Deployment Prerequisites

Do not deploy or mutate DNS as part of local verification or pull-request CI. Before an explicitly approved production deployment:

1. Confirm `wrangler whoami` identifies the intended Cloudflare account.
2. Confirm `sarbaa.com` is an active Cloudflare zone and review any existing DNS records for `cbk`.
3. Build the signed release artifact, verify its certificate SHA-256, and ensure the `com.sarbaa.cbk` App Link includes the `https://cbk.sarbaa.com/r/` scope.
4. Set the matching real fingerprint in Cloudflare without committing it:

   ```sh
   bun run --cwd services/cbk-edge wrangler secret put ANDROID_SHA256_CERT_FINGERPRINT
   ```

   `PLAY_STORE_URL` may be set as a non-secret Worker variable in the chosen Wrangler configuration. Only an HTTPS URL on `play.google.com` at `/store/apps/details` is accepted; other values fall back to the safe package default.
5. Review `services/cbk-edge/wrangler.jsonc`. It declares `cbk.sarbaa.com` as a Wrangler custom domain and does not contain account credentials.
6. Run the local `bun run verify:bun` checks again.

## Manual Deployment and Custom-Domain Steps

These are operator actions and are intentionally not automated by CI:

1. Authenticate with Wrangler and confirm the target account.
2. Run `bun run --cwd services/cbk-edge deploy` only after explicit approval.
3. Cloudflare may provision the declared custom domain and its DNS record when the authenticated account has the required zone permissions. If it does not, use the Cloudflare dashboard/CLI to attach the `cbk-edge` Worker to the `cbk.sarbaa.com` custom-domain hostname and follow Cloudflare's displayed DNS record exactly; do not guess a conflicting CNAME target.
4. Verify authoritative DNS (`dig cbk.sarbaa.com`) and HTTPS (`curl -I https://cbk.sarbaa.com/health`).
5. Configure release signing from an ignored `android/key.properties` and verify the artifact fingerprint. Release builds fail their `verifyReleaseSigning` pre-build check when required signing properties or the keystore are missing; they never fall back to the debug key.
6. Configure the matching production signing fingerprint before checking Android Digital Asset Links in production.
7. Install a signed release APK/AAB, confirm the `cbk.sarbaa.com/r/` App Link is verified, then run manual smoke checks for landing, referral redirect/cookie/referrer, 404/405, security headers, and asset links.

## Documentation and Plans

Start with `AGENTS.md` for repository rules and `docs/INDEX.md` for the documentation map. Every plan belongs in its own `docs/plans/<name>/` directory with a `plan.md`; current external prerequisites must remain unchecked until completed.

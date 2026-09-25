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
| `packages/contracts/` | Shared TypeScript domain contracts, canonical constants, and the unsupported-claim scanner |
| `packages/play-store-metadata/` | Canonical five-language Play Store listing text and its Bun CLI |
| `services/cbk-edge/` | Native Cloudflare Worker for `cbk.sarbaa.com`, its Bun VPS adapter, and the VPS deployment assets |
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

The app loads the English, Hindi, Marathi, Bengali, and Tamil JSON catalogs from
`assets/i18n/`. The selected app language is persisted locally and also selects
the generated WhatsApp receipt language.

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
bun run aso:check
bun run build:worker
```

`bun run build:worker` invokes `wrangler deploy --dry-run` inside `services/cbk-edge`; it does not deploy the Worker or change DNS. `bun run serve:edge` starts the Bun VPS adapter on loopback for local checks. Run `bun run verify:bun` for all TypeScript gates or `bun run verify:all` for the TypeScript and Flutter gates.

## Play Store Listing Metadata

`packages/play-store-metadata/src/metadata.ts` is the single source of truth for
the `en-IN`, `hi-IN`, `mr-IN`, `bn-IN`, and `ta-IN` Google Play listings. The
CLI validates every locale, field length, and claim before writing Play-ready
files:

```sh
bun run aso:generate                          # writes packages/play-store-metadata/dist (git-ignored)
bun run aso:generate --out build/play-store   # relative --out resolves from the repository root
bun run aso:check                             # validates only, uses a temporary directory
```

Each locale directory receives `title.txt`, `short-description.txt`, and
`full-description.txt`. Generation is deterministic, so re-running it produces
byte-identical files. The CLI refuses a pre-existing symlinked locale directory
or target file, and inventories the destination fail-closed: a stale locale
directory, a stale or unknown file, or any stray entry makes the run fail with
the offending paths listed, and nothing is deleted or overwritten. Remove such
entries by hand, or point `--out` at an empty directory. `bun run aso:check`
runs as part of `bun run verify:bun`, which CI executes as the independent Bun
gate. Uploading the listings to Play Console, native-language editorial review
of the vernacular copy, and packaging vernacular screenshots are still pending
and tracked in `docs/plans/gtm-android-release-aso-pipeline/plan.md`.

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

- `PLAY_STORE_URL`: optional HTTPS Google Play listing URL, restricted to `play.google.com/store/apps/details`; the app package is always forced to `com.sarbaa.cbk`. While it is unset or invalid the landing page renders no download button at all and shows an honest "Google Play release in progress" panel instead of linking to a listing that does not exist.
- `ANDROID_SHA256_CERT_FINGERPRINT`: optional real Android signing-certificate SHA-256 fingerprint, with or without colon separators. Until a valid value is configured, asset links return `[]`; never place a fake fingerprint in source control.

`.dev.vars` is ignored. `.dev.vars.example` contains placeholders only.

### Route Summary

| Route | Behavior |
| --- | --- |
| `GET /health` | Bounded service/status/version JSON; no secrets |
| `GET /` | Self-contained, mobile-first landing page; shows a Google Play download call to action only when `PLAY_STORE_URL` is a valid listing, and carries a valid `?ref=` code into the Play `referrer` parameter |
| `GET /import` | Same cacheable, security-header-protected landing page as `GET /`; no referral cookie, redirect, or log |
| `GET /privacy` | Self-contained privacy policy describing local storage, user-initiated sharing, the wa.me browser fallback and what it exposes, operating-system backup being disabled, the pseudonymous event queue, the referral cookie, and the operator contact details |
| `GET /privacy/` | `308` redirect to `/privacy`, so the policy has exactly one canonical URL |
| `GET /r/:code` | Validates `[A-Z0-9]{6}`, emits a four-field privacy-safe log, sets a secure HttpOnly SameSite cookie, and redirects temporarily to `/?ref=CODE` |
| `POST /api/v1/telemetry/batch` | Gzip-only JSON event ingestion; requires the `TELEMETRY` analytics binding, otherwise `503 telemetry_unavailable` with `Retry-After: 60` |
| `GET /.well-known/assetlinks.json` | Returns `[]` without a valid fingerprint, otherwise declares `com.sarbaa.cbk` |
| Other `GET` paths | Bounded JSON 404 |
| Unsupported methods | JSON 405 with `Allow: GET` (or `Allow: POST` for the telemetry route) |

Referral click persistence, payments, D1, Convex, and outbound tooling are intentionally not part of this Worker slice. The Flutter app queues its own privacy-safe analytics events and keeps them on the device while a telemetry endpoint is unavailable.

## Bun Adapter and VPS Hosting

`services/cbk-edge/src/vps_server.ts` is a thin Bun server around the same `handleRequest` handler the Cloudflare Worker uses, so `cbk.sarbaa.com` can be served from the existing nginx + Bun VPS without moving the whole `sarbaa.com` zone to Cloudflare. The Cloudflare default export in `src/index.ts` is unchanged.

```sh
bun run serve:edge                                  # loopback:8787 by default
CBK_EDGE_HOST=127.0.0.1 CBK_EDGE_PORT=9000 bun run serve:edge
curl -fsS http://127.0.0.1:8787/health
```

| Variable | Default | Meaning |
| --- | --- | --- |
| `CBK_EDGE_HOST` | `127.0.0.1` | Bind address. Parsed strictly; anything that is not a bare host or IP literal is rejected before the socket opens. |
| `CBK_EDGE_PORT` | `8787` | Bind port (`0`-`65535`; `0` requests an ephemeral port and is only used by tests). |
| `PLAY_STORE_URL` | unset | Same strict Google Play listing restriction as the Worker. Unset means no download call to action on the page. |
| `ANDROID_SHA256_CERT_FINGERPRINT` | unset | Real release-key SHA-256 fingerprint, with or without colons. A blank or malformed value is ignored by the handler, so `/.well-known/assetlinks.json` keeps answering `[]` and the App Link stays unverified. |

The adapter logs no request metadata. Its only startup log line is the bind address, and the only per-request log is the minimal four-field referral record. Because `TELEMETRY` is a Cloudflare Analytics Engine binding, the Bun adapter leaves it undefined, so `POST /api/v1/telemetry/batch` answers `503 telemetry_unavailable` with `Retry-After: 60` and the Android app keeps its local queue. Event ingestion on the VPS would need a separate, explicitly approved storage decision.

Versioned example deployment assets (systemd unit, non-secret environment example, stage-1 HTTP vhost, stage-2 HTTPS template, and a runbook that keeps the two-stage Certbot flow explicit) live in `services/cbk-edge/deploy/v1/`. Nothing there has been applied to any machine.

The adapter shares the handler's bounded 500 body, cache policy, and security
headers, so a runtime-level failure looks like every other response. Two
operator-facing details are easy to get wrong and are covered by tests: the
release copy is a copy of the working tree, so the checkout must be clean and
committed first, and stage 2 renders the vhost through `sudo tee` rather than a
plain `>`, which would silently leave the old vhost in place.

## Release Signing and Asset Links

Production Android release builds must use a real upload/release key; the app intentionally does not fall back to the debug signing key.

```sh
cp android/key.properties.example android/key.properties
# Fill android/key.properties with the real local signing values.
flutter build appbundle --release
keytool -list -v -keystore /absolute/path/to/release-keystore.jks -alias YOUR_KEY_ALIAS
```

The `preReleaseBuild` Gradle task depends on `verifyReleaseSigning`, which fails when `android/key.properties` is incomplete or its keystore file is missing. `android/key.properties`, `*.jks`, and `*.keystore` are ignored. A relative `storeFile` value resolves from the `android/` directory (the root Gradle project), matching `android/key.properties.example`; an absolute path is also accepted. Record the `SHA256` value from the actual signing key and use that exact value for `ANDROID_SHA256_CERT_FINGERPRINT`; do not use the debug key fingerprint.

`android:allowBackup="false"` is set in the app manifest, so the local database is never handed to the platform's backup service. `test/android_manifest_backup_test.dart` keeps that attribute from being dropped, and the privacy policy states the same thing.

## Deployment Prerequisites

Do not deploy or mutate DNS as part of local verification or pull-request CI. Before an explicitly approved production deployment:

1. Confirm `wrangler whoami` identifies the intended Cloudflare account.
2. Confirm `sarbaa.com` is an active Cloudflare zone and review any existing DNS records for `cbk`.
3. Build the signed release artifact, verify its certificate SHA-256, and ensure the `com.sarbaa.cbk` App Link includes the `https://cbk.sarbaa.com/r/` scope.
4. Set the matching real fingerprint in Cloudflare without committing it:

   ```sh
   bun run --cwd services/cbk-edge wrangler secret put ANDROID_SHA256_CERT_FINGERPRINT
   ```

   `PLAY_STORE_URL` may be set as a non-secret Worker variable in the chosen Wrangler configuration. Only an HTTPS URL on `play.google.com` at `/store/apps/details` is accepted; any other value, including an unset one, leaves the landing page without a download call to action.
5. Review `services/cbk-edge/wrangler.jsonc`. It declares `cbk.sarbaa.com` as a Wrangler custom domain and does not contain account credentials.
6. Run the local `bun run verify:bun` checks again.

## Manual Deployment and Custom-Domain Steps

These are operator actions and are intentionally not automated by CI:

1. Authenticate with Wrangler and confirm the target account.
2. Run `bun run --cwd services/cbk-edge deploy` only after explicit approval.
3. Cloudflare may provision the declared custom domain and its DNS record when the authenticated account has the required zone permissions. If it does not, use the Cloudflare dashboard/CLI to attach the `cbk-edge` Worker to the `cbk.sarbaa.com` custom-domain hostname and follow Cloudflare's displayed DNS record exactly; do not guess a conflicting CNAME target.
4. Verify authoritative DNS (`dig cbk.sarbaa.com`) and HTTPS (`curl -sS -o /dev/null -w '%{http_code}\n' https://cbk.sarbaa.com/health`; the handler answers `GET` only, so `HEAD` is a 405).
5. Configure release signing from an ignored `android/key.properties` and verify the artifact fingerprint. Release builds fail their `verifyReleaseSigning` pre-build check when required signing properties or the keystore are missing; they never fall back to the debug key.
6. Configure the matching production signing fingerprint before checking Android Digital Asset Links in production.
7. Install a signed release APK/AAB, confirm the `cbk.sarbaa.com/r/` App Link is verified, then run manual smoke checks for landing, privacy policy, referral redirect/cookie/referrer, 404/405, security headers, and asset links.

## Manual Bun VPS Deployment

Hosting on the existing VPS instead of Cloudflare follows `services/cbk-edge/deploy/v1/README.md`: place a versioned release under `/opt/cbk-edge/releases`, install the systemd unit and the non-secret environment file, start the loopback adapter, then bring up nginx in two stages (plain HTTP, then Certbot plus the rendered HTTPS vhost). The `cbk` DNS record stays in the current `sarbaa.com` zone. Every step there is still pending operator execution, approval, and production smoke testing.

Stage 1 is plain HTTP and is only a bring-up state: the `cbk_referral` cookie is `Secure`, so a browser discards it before TLS exists, and Android App Links need HTTPS plus a verified `assetlinks.json`, so `/import` and `/r/{code}` do not open the app until stage 2. Run the production smoke checks only after stage 2.

## Documentation and Plans

Start with `AGENTS.md` for repository rules and `docs/INDEX.md` for the documentation map. Every plan belongs in its own `docs/plans/<name>/` directory with a `plan.md`; current external prerequisites must remain unchecked until completed.

# Plan: Additive Monorepo and cbk.sarbaa.com Edge Vertical Slice

**Status:** Implemented locally; deployment, DNS, production fingerprint, and manual production smoke checks pending.

## 1. Overview & Objective

Add an incremental Bun workspace without moving the root Flutter application, then provide the first deployable backend vertical slice at `https://cbk.sarbaa.com`. The slice supports an app-download landing page, privacy-safe referral redirects, Android Digital Asset Links, bounded errors, and deterministic tests.

## 2. Requirements & Scope

### In Scope

- Keep Flutter, its platform projects, assets, tests, and `pubspec.yaml` at repository root.
- Add private Bun 1.3.4 workspaces under `services/*` and `packages/*`.
- Add shared referral and canonical domain constants in `@collection-book/contracts`.
- Add native Cloudflare Worker routes under `services/cbk-edge`.
- Register the verified `https://cbk.sarbaa.com/r/` Android App Link for `com.sarbaa.cbk`.
- Update Flutter receipt links to `https://cbk.sarbaa.com/r/{code}`.
- Add independent Flutter/Bun CI and a non-deploying Wrangler dry-run.
- Preserve unstaged viral-receipt work and leave the entire working tree unstaged.

### Deliberately Deferred

- Referral click persistence, D1, analytics/telemetry ingestion, payments, Convex, and the outbound CLI.
- Production deployment, DNS/custom-domain provisioning, and production Android fingerprint configuration.
- App-store publication or install attribution beyond constructing the Google Play `referrer` parameter.

## 3. Architecture & Technical Design

### Repository Layout

```text
/
├── lib/, test/, android/, ios/       # existing Flutter app
├── packages/contracts/               # reusable TypeScript contracts
├── services/cbk-edge/                # native Cloudflare Worker
├── docs/plans/monorepo-cbk-edge/     # this plan
├── package.json                      # private Bun workspace
└── tsconfig.json                     # strict shared TypeScript config
```

### Shared Contracts

`packages/contracts` owns the canonical origin `https://cbk.sarbaa.com`, Android package `com.sarbaa.cbk`, referral cookie name, safe Play Store default, and strict six-character uppercase ASCII alphanumeric referral parser.

### Worker Routes and Privacy Boundary

- `GET /health`: service, status, and version only.
- `GET /`: self-contained semantic HTML, no scripts/CDNs/tracking, safe Play URL, and valid referral preservation.
- `GET /r/:code`: validates first, generates a request ID, then emits only event/code/request ID/timestamp; sets a 30-day `Secure; HttpOnly; SameSite=Lax` host-only cookie and returns 302.
- `GET /.well-known/assetlinks.json`: returns `[]` unless a valid SHA-256 certificate fingerprint is configured.
- Unknown GET route: bounded JSON 404. Other method: bounded JSON 405 with `Allow: GET`.
- All responses receive CSP, HSTS, frame denial, MIME sniffing protection, permissions policy, and referrer policy. Cache policy varies by route.

Referral logs deliberately exclude IP, user agent, cookies, subscriber/operator data, and secrets. The log shape is directly unit tested.

## 4. Implementation Checklist

### Workspace and Tooling

- [x] Add private root Bun workspaces for `services/*` and `packages/*`.
- [x] Pin package-manager metadata to Bun 1.3.4 and CI setup to 1.3.4.
- [x] Add strict shared and scoped TypeScript configs.
- [x] Add format/check, typecheck, test, Worker dry-run, and aggregate verification scripts.
- [x] Generate `bun.lock` using Bun only.
- [x] Extend ignore rules for dependencies, env files, Wrangler state/output, and TypeScript output while allowing example env files.

### Contracts and Worker

- [x] Add shared canonical constants and referral parsing/validation.
- [x] Add a native, testable Cloudflare Worker request handler with no framework.
- [x] Implement bounded health, landing, referral, asset-links, 404, and 405 behavior.
- [x] Restrict `PLAY_STORE_URL` to the intended HTTPS Google Play listing host/path and fall back safely.
- [x] Register the `cbk.sarbaa.com/r/` App Link intent filter with Android auto-verification.
- [x] Require explicit real release signing instead of using the Android debug key for release artifacts.
- [x] Carry valid referral codes through the Google Play `referrer` query parameter while forcing package `com.sarbaa.cbk`.
- [x] Add CSP/security headers and per-route cache controls.
- [x] Add deterministic Bun tests for all routes, referral/cookie/referrer behavior, methods, cache/security headers, fingerprint states, and injection resistance.
- [x] Add Wrangler custom-domain configuration for `cbk.sarbaa.com` and placeholder-only `.dev.vars.example`.
- [x] Document configuration, secrets, local preview, deployment prerequisites, and manual DNS/custom-domain steps.

### Flutter and Documentation

- [x] Change receipt referral URL and tests to `https://cbk.sarbaa.com/`.
- [x] Update relevant receipt plan/template documentation without changing receipt behavior.
- [x] Replace starter README with an accurate project/operations map.
- [x] Make root `AGENTS.md` canonical and reduce `agent.md` to a pointer.
- [x] Add independent Flutter and Bun CI jobs with no deployment or secrets.
- [x] Index this plan in `docs/plans/README.md` and `docs/INDEX.md`.

### External Work Still Pending

- [ ] Authenticate Wrangler against the intended production Cloudflare account.
- [ ] Configure real release signing in ignored `android/key.properties` and build the signed APK/AAB.
- [ ] Confirm the signed artifact's certificate SHA-256 and configure that exact value as `ANDROID_SHA256_CERT_FINGERPRINT` in Cloudflare.
- [ ] Review production `PLAY_STORE_URL` or retain the safe package default.
- [ ] Obtain explicit approval, deploy `services/cbk-edge`, and allow Cloudflare to provision/attach the custom domain.
- [ ] Complete authoritative DNS review and record any manual DNS action required.
- [ ] Run production manual smoke checks for landing, referral redirect/cookie/referrer, errors, headers, asset links, and the signed Android App Link.

## 5. Verification Plan

### Automated Local Gates

- `bun install`
- `bun run format:check`
- `bun run typecheck`
- `bun test`
- `bun run build:worker` (Wrangler dry-run only)
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug` when practical
- `git diff --check`
- `git diff --cached --exit-code`
- Re-run the available read-only repository audit script and record its score/findings as evidence.

### Manual Gates

- Open `/health`, `/`, `/r/AB12CD`, invalid referral routes, and asset links against the deployed custom domain.
- Verify TLS, authoritative DNS, security headers, Play target package, referrer continuation, cookie flags, and no invalid-click logs.
- Validate Android Digital Asset Links and the `cbk.sarbaa.com/r/` App Link only on the signed release artifact after the matching production fingerprint is configured.

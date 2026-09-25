# Plan: cbk.sarbaa.com VPS Landing, Privacy, and Launch Surface

**Status:** Implemented and verified locally, including the independent review
corrections. The pinned Bun runtime, versioned release, systemd service, DNS,
Let's Encrypt TLS, and the HTTPS nginx vhost are deployed and healthy on the
target VPS. Production telemetry, the public Play listing, the signing
fingerprint, real-device App Link verification, and broader mobile/dark-mode
visual smoke checks remain pending.

## 1. Overview & Objective

Make `cbk.sarbaa.com` a truthful, conversion-focused public surface for
Collection Book and make it hostable on the existing Linode VPS (nginx + Bun)
without moving the whole `sarbaa.com` zone to Cloudflare.

The site must convert an operator without lying: the Play listing does not
exist yet, the app has no subscriber cap, no paid plan, and no hosted copy of
customer data, so none of those may be implied. The privacy policy must match
the behavior that actually ships in the Flutter app and in `handleRequest`,
including the `wa.me` browser fallback, and the pages must stay readable in dark
mode.

## 2. Requirements & Scope

### In Scope

- A thin Bun server adapter around the existing `handleRequest`, with strictly
  parsed `CBK_EDGE_HOST` / `CBK_EDGE_PORT` configuration and no request logging.
- Versioned example deployment assets: systemd unit, non-secret environment
  example, stage-1 HTTP nginx vhost, stage-2 HTTPS template, and a runbook.
- A redesigned, self-contained, no-JS landing page with honest availability
  states and a CSS-composed ledger illustration.
- A `/privacy` policy with a single canonical URL.
- Shared, reusable unsupported-claim scanning that covers the landing and
  privacy copy and the five Flutter receipt templates, not only the Play Store
  listing.
- Tests for the new routes, states, adapter, deployment assets, and color-scheme
  contrast.

### Deliberately Deferred

- A VPS telemetry sink. The Bun adapter keeps `TELEMETRY` undefined, so the
  ingestion route answers `503` and the app retains its queue.
- Cloudflare deployment of this slice, D1 referral persistence, payments,
  Convex, and any outbound tooling.
- Any referral persistence, pricing, or plan system. The receipt footers only
  ask another operator to try the app.
- A signed release build, so the real signing fingerprint stays unset and asset
  links stay `[]`.

## 3. Architecture & Technical Design

### Runtime

```text
Cloudflare Workers  -> services/cbk-edge/src/index.ts      (default export, unchanged)
Bun on a VPS        -> services/cbk-edge/src/vps_server.ts (Bun.serve -> handleRequest)
                       services/cbk-edge/src/vps_config.ts (pure env parsing, unit tested)
```

Both runtimes execute the same handler, so routes, security headers, and cache
policy cannot drift. The adapter binds loopback and never logs request
metadata; nginx terminates TLS in front of it.

### Landing page

`services/cbk-edge/src/page.ts` owns the shared document shell and stylesheet;
`src/landing.ts` owns the landing content; `src/privacy.ts` owns the policy.
`resolvePlayStoreUrl` returns `null` unless `PLAY_STORE_URL` is a valid HTTPS
Google Play listing, and the page renders a "Google Play release in progress"
panel instead of a download link in that state. A referral code is only carried
into the Play `referrer` parameter when a real listing link exists.

Page structure: hero, three operator outcomes, how-it-works steps, shipped
capabilities, privacy/trust disclosure, FAQ (`<details>`), final availability
call to action, and a footer with the policy, website, and phone.

The `defaultPlayStoreUrl` constant was removed from `packages/contracts`: with
no public listing, a hard-coded package link is a broken call to action, so
"unconfigured" now means "no link", not "link to a guess".

Accessibility and platform conventions: semantic landmarks, one `h1`, labelled
sections, skip link, visible `:focus-visible`, `touch-action: manipulation`,
48px minimum targets, `text-wrap: balance` / `pretty`, safe-area padding,
`viewport-fit=cover`, reduced-motion support, no `transition: all`, no external
assets, and no scripts. Static panels use `role="note"` rather than a live-region
role, because a server-rendered page announces nothing.

### Color scheme and contrast

Text that sits on the accent background uses the `--on-accent` token, with
`--on-accent-soft` for the muted panel paragraph. The dark scheme inverts both
(dark ink on the light green accent) instead of keeping a hard-coded white,
which was unreadable in dark mode. `services/cbk-edge/test/color_contrast.test.ts`
extracts the tokens from the rendered stylesheet and asserts a WCAG AA 4.5:1
minimum for every accent and body pair in both schemes, so a future palette edit
fails a test instead of shipping silently.

### Privacy route

`GET /privacy` serves the policy; `GET /privacy/` answers `308` to `/privacy`
so the policy has exactly one canonical URL. The policy discloses local SQLite
storage, user-initiated WhatsApp/file sharing, the pseudonymous client id plus
allowlisted event names/timestamps/properties, Wi-Fi-only delivery attempts to
`cbk.sarbaa.com`, the absence of subscriber names/phones/VC numbers in events,
the 30-day HttpOnly referral cookie and its minimal log, ordinary hosting
network metadata, and the reset behavior.

Two disclosures were corrected after review. The app does **not** only ever use
the installed WhatsApp app: when that app is unavailable it hands the browser a
`wa.me` link, so the policy now states that the complete receipt text,
including the customer name and payment details, travels in that URL and is
handled by the browser and by WhatsApp's web service. The app is also installed
with `android:allowBackup="false"`, and the policy says the local database is
not copied into the platform's backup services. Retention is described without
promising a deletion window, and the contact is Sarbani Associates with the
published website and phone only; no email address is invented.

### Claim enforcement

`findUnsupportedClaims` and the numeric-cap guard moved from
`packages/play-store-metadata` to `packages/contracts`, which `cbk-edge` already
depends on, so there is no dependency cycle. `packages/play-store-metadata`
re-exports them and keeps only the listing-specific pass. A new `free-plan-or-tier`
rule complements the existing cap guard, and the cap guard also accepts `subs`
so the old "up to 100 subs" receipt footer could not slip through.
`services/cbk-edge/test/handler.test.ts` scans the rendered customer-facing text
of both landing variants and the policy, `services/cbk-edge/test/receipt_claims.test.ts`
scans the Dart receipt templates with the same shared scanner instead of
duplicating the rules in Dart, and a companion test proves the scan still fails
on injected cap/free/cloud-sync copy.

## 4. Implementation Checklist

### Verified locally

- [x] Add the Bun adapter with strict host/port parsing and no request logging.
- [x] Document the missing `TELEMETRY` binding and its safe 503 behavior.
- [x] Add versioned systemd, nginx, environment, and runbook assets under
      `services/cbk-edge/deploy/v1/`, with no certificate path in the active
      HTTP configuration and no secrets anywhere.
- [x] Redesign the landing page as a self-contained, mobile-first, no-JS page
      using only implemented product claims.
- [x] Show a live Play call to action only for a valid configured listing, and
      an honest release-in-progress state otherwise.
- [x] Add `/privacy` plus the `/privacy/` redirect, linked from header and
      footer, with content that matches real app and service behavior.
- [x] Move the claim scanner to `packages/contracts` and scan landing/privacy
      copy with it, in both the configured and unconfigured landing variants.
- [x] Extend tests for landing states, privacy route/content/security/cache,
      referrals, the adapter, and the deployment assets.
- [x] Add `bun run serve:edge` and `bun run --cwd services/cbk-edge serve`.
- [x] Update the README route, configuration, and deployment documentation.
- [x] Wire `ANDROID_SHA256_CERT_FINGERPRINT` through `VpsServerConfig` into the
      handler environment, documented in the env example, runbook, and README.
      A blank value stays unconfigured, so asset links remain `[]`.
- [x] Render the stage 2 vhost through `sudo tee`, drop the stale
      `.http.conf` deletion, redirect to the literal host, and let the handler
      own HSTS so the header is not sent twice.
- [x] Add `--on-accent` / `--on-accent-soft` tokens and a numeric WCAG AA
      contrast test over the rendered stylesheet.
- [x] Disclose the `wa.me` browser fallback on the landing page and in the
      privacy policy, and drop the "installed app only" framing.
- [x] Remove the free/100-subscriber claim from all five receipt locales and
      guard the templates with the shared scanner plus per-locale assertions.
- [x] Set `android:allowBackup="false"` and cover it with a manifest test.

### External work still pending

- [x] Create the `cbk` DNS record in the existing `sarbaa.com` zone.
- [x] On 2026-09-25, install checksum-verified Bun 1.3.4 at the isolated pinned
      runtime path, deploy release `6f45193-07e8502d-20260925T205529Z`, and
      start the hardened systemd service on `127.0.0.1:8787`.
- [x] Install the stage-1 HTTP nginx vhost; native `nginx -t` and
      `systemd-analyze verify` accepted the cbk-edge assets, and loopback
      Host-header smoke checks passed for health, landing, privacy, referral,
      errors, empty asset links, and the intentional telemetry 503.
- [x] On 2026-09-25, issue a Let's Encrypt certificate for `cbk.sarbaa.com`,
      render the HTTPS vhost, correct the template for nginx 1.18's
      `listen ... http2` syntax, and reload nginx after `nginx -t` passed.
- [x] Run HTTPS production smoke checks for health, landing, privacy, referral
      redirect/cookie, invalid referrals, empty asset links, telemetry 503,
      unsupported methods, and HTTP-to-HTTPS redirect. Checks used an explicit
      DNS override while resolver propagation was still inconsistent.
- [ ] Publish the Google Play listing, then set `PLAY_STORE_URL` so the
      download call to action appears.
- [ ] Configure the real Android signing-certificate SHA-256 fingerprint
      (`ANDROID_SHA256_CERT_FINGERPRINT` for the VPS adapter, a Wrangler secret
      for the Worker). Until then asset links stay `[]`.
- [ ] Decide and approve a VPS telemetry sink, or accept the 503 behavior.
- [ ] Review the rendered pages on real mobile viewports, in dark mode, and
      with a screen reader.

## 5. Verification Plan

### Automated

- `bun run format:check`, `bun run typecheck`, `bun test`
- `bun run build:worker` (Wrangler dry-run, no deploy, no DNS change)
- `bun test services/cbk-edge/test/vps_server.test.ts` binds an ephemeral
  loopback port and exercises `/health`, `/`, `/privacy`, `/privacy/`,
  `/r/:code`, 404, 405, asset links with and without a configured fingerprint,
  and the telemetry 503 path.
- `bun test services/cbk-edge/test/color_contrast.test.ts` asserts the WCAG AA
  minimum for the accent and body token pairs in both color schemes.
- `bun test services/cbk-edge/test/receipt_claims.test.ts` and
  `flutter test test/whatsapp_receipt_claims_test.dart` guard the receipt copy.
- `git diff --check`

### Manual

- [x] Run `nginx -t` and `systemd-analyze verify` on the target host for the
  deployed stage-1 assets; both accepted the cbk-edge configuration. The
  systemd command also reported an unrelated pre-existing warning for
  `snapd.service`'s unsupported `RestartMode` key.
- [ ] Render `/` and `/privacy` at narrow and wide viewports, in both color schemes,
  with reduced motion, and with keyboard-only navigation.
- [ ] Confirm the download call to action appears only after a real Play listing
  is configured.
- [ ] Confirm the production `/r/{code}` App Link and asset links on a signed
  release build after the real fingerprint is configured.

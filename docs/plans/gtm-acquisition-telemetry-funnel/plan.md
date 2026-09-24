# Plan: Acquisition & Product Funnel Telemetry

## 1. Overview & Objective

Measure the currently available operator journey with privacy-minimized,
offline-first milestones:

`first app open → first subscriber created → import completed → payment
recorded / receipt intent opened`

The implemented events support acquisition and product-usage analysis. Upgrade,
licensing, and UPI milestones are deferred because those product flows do not
exist in the current application. The Worker does not create storage or
analytics resources during local implementation.

## 2. Implemented Architecture

### Flutter client

- `analytics_events` is created by the existing `DatabaseService` in schema v8.
  Rows contain a random event ID, allowlisted name/properties, epoch-millisecond
  creation time, attempt count, next-attempt time, and a bounded generic error
  code. The simple `synced` flag in the original draft was replaced because it
  could not safely represent retry scheduling. `analytics_milestones` provides
  durable unique claims in the same transaction as first-open and
  first-subscriber event insertion.
- `AnalyticsService` validates events, names, property keys, primitive types,
  and enum/count values before local insertion. It generates a cryptographically
  random install-scoped `anon_<32 hex>` client ID. This is **not** a hash of an
  operator identity.
- The queue is retained for 30 days, sent in batches of at most 50 as gzip JSON,
  and only deleted after the Worker explicitly accepts their event IDs. Network,
  timeout, 408, 425, 429, and 5xx failures use bounded exponential backoff.
  Other 4xx responses, including permanent 413 size rejection, discard the
  client-invalid batch. Redirect responses are retained. The eight-second
  transport timeout covers request close and complete response-body consumption.
  Raw response bodies and exception text are never stored in the queue.
- Connectivity is only a flush trigger, not proof of internet access. Periodic,
  resume, and milestone-triggered flush attempts proceed only when
  `connectivity_plus` reports Wi-Fi. Only one flush runs at a time.
- No subscriber/operator PII, import filename, exception text, IP address, user
  agent, phone, VC, address, name, cookie, secret, raw order ID, device model,
  OS version, or referrer is queued or transmitted.

### cbk-edge Worker

- `POST /api/v1/telemetry/batch` requires `application/json` and gzip encoding.
- The request is rejected unless its compressed body is at most 64 KiB,
  decompressed body is at most 256 KiB, and batch has 1–50 events. Validation is
  repeated server-side against the same canonical event/property allowlist.
  Compressed size, decompressed size, and event-count limit failures all return
  413; malformed gzip/JSON and schema/taxonomy failures return 400.
- Every validated event is written to the typed `TELEMETRY` Analytics Engine
  binding with the anonymous client ID as its single index. Event name, stable
  event ID, and validated properties are blobs; timestamp is a double. The
  binding/dataset is configured locally only. A missing binding or write failure
  returns retryable 503; it is never falsely acknowledged.
- Responses are method-aware, `no-store`, and use the existing Worker security
  headers. Telemetry requests and bodies are not logged. Existing minimal
  referral logging is unchanged.

## 3. Privacy Correction From Earlier Draft

The earlier plan proposed a salted hash of operator identity, device model, OS,
and referrer. Those items are not implemented. The client ID is random and
install-scoped; it is not derived from any subscriber, operator, account, or
device identity. Device metadata and referrers remain absent pending a separate,
explicit privacy decision.

## 4. Implementation Checklist

- [x] **Phase 1: Local validated queue**
  - [x] Add the migration-safe schema v8 analytics queue.
  - [x] Add one allowlisting `AnalyticsService` with a random anonymous client
        ID, retention, bounded batching, backoff, and exact acknowledgement.
  - [x] Add deterministic queue, validation, retry, expiry, milestone, client-ID
        persistence, actual import-commit, and migration tests.
- [x] **Phase 2: Existing-flow instrumentation**
  - [x] Record `app_first_open` once per install with a transactional SQLite
        claim, including concurrent-call and rollback coverage.
  - [x] Record the first manual or successfully imported subscriber in the same
        database transaction as subscriber creation, using one durable claim;
        cover concurrent and both manual/import orderings.
  - [x] Record MSO import telemetry only when the persisted run status is
        `success` or `partial`; failed runs emit no import milestone. Payloads
        contain aggregate counts, format, elapsed time, and service mode, never
        the filename.
  - [x] Record payment only after the database write succeeds.
  - [x] Record receipt dispatch only after an app or wa.me launcher succeeds;
        this does not claim delivery.
- [x] **Phase 3: Flush and Worker ingestion**
  - [x] Add periodic/resume/milestone best-effort Wi-Fi triggers and serialized
        gzip delivery with timeout and bounded backoff.
  - [x] Add strict, method-aware, privacy-allowlisted Worker ingestion with
        typed Analytics Engine writes and no-store/security responses.
  - [x] Add deterministic Worker success, malformed, oversize, encoding,
        method, missing-binding, native field-limit, write-failure, unknown
        taxonomy, and privacy tests; add client redirect/body-timeout tests.
- [ ] **Phase 4: External and device verification**
  - [ ] Configure the production Analytics Engine binding through the approved
        Cloudflare deployment process.
  - [ ] Deploy and verify the Worker, DNS, and production endpoint externally.
  - [ ] On a physical Android device, verify offline queueing, Wi-Fi/resume
        flush, background/resume behavior, and absence of PII in the local
        queue and backend configuration.
  - [ ] Perform a production Analytics Engine query/sample inspection after
        deployment using synthetic data only.

Parent phases are checked only when all their child checks above are verified.
External deployment and manual device checks remain deliberately unchecked.

## 5. Automated Verification

Run from repository root:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
bun run format:check
bun run typecheck
bun test
bun run build:worker
git diff --check
git diff --cached
```

No fake deployment, DNS, binding availability, or device result is claimed.

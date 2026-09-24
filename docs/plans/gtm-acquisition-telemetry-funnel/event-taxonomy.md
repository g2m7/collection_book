# GTM Funnel Telemetry Event Taxonomy

## 1. Current Implemented Events

All timestamps and elapsed times are epoch/time duration milliseconds represented
as integer counts. Service mode remains `tv` or `fiber` and never crosses the
existing service boundary.

| Event name | Exact trigger | Allowed properties | Status |
| :--- | :--- | :--- | :--- |
| `app_first_open` | A durable SQLite milestone claim and event insert commit in one transaction | none | Implemented |
| `first_subscriber_created` | The subscriber insert and one durable milestone claim/event insert commit in the same manual or MSO import transaction | `method`: `manual` or `mso_import` | Implemented |
| `mso_file_imported` | Import transaction and run persistence complete with computed status `success` or `partial`; never emitted for `failed` runs | `service_type`, `record_count`, `mso_format`, `elapsed_ms`, `inserted_count`, `updated_count`, `payment_count` | Implemented |
| `payment_recorded` | Payment insert/update returns successfully | `service_type`, `has_adjustment` | Implemented |
| `whatsapp_receipt_dispatched` | WhatsApp app or wa.me external intent launcher returns success | `service_type`, `used_web_fallback` | Implemented |

`mso_format` is one of `book1`, `active_packages`, `total_list`, `csv`, or
`unknown`.
Counts are non-negative bounded integers and `elapsed_ms` is at most 86,400,000.
`whatsapp_receipt_dispatched` means only that an intent was opened. It does not
mean that a message was composed, sent, delivered, or read.

## 2. Bounded Batch Contract

`POST /api/v1/telemetry/batch` requires `Content-Type: application/json` and
gzip content encoding. The compressed body limit is 64 KiB; the decompressed JSON
limit is 256 KiB; and each batch contains 1–50 events. Compressed size,
decompressed size, and event-count rejections consistently return 413. Because
local event/property allowlists keep normal events intrinsically bounded, the
client treats 413 as a permanent client-invalid batch rather than retrying it
forever.

```json
{
  "client_id": "anon_0123456789abcdef0123456789abcdef",
  "events": [
    {
      "id": "0123456789abcdef0123456789abcdef",
      "event_name": "payment_recorded",
      "timestamp": 1790150400000,
      "properties": {
        "service_type": "tv",
        "has_adjustment": false
      }
    }
  ]
}
```

A successful response explicitly acknowledges the exact accepted IDs:

```json
{
  "accepted_event_ids": [
    "0123456789abcdef0123456789abcdef"
  ]
}
```

The Flutter client deletes only those IDs. A missing binding or any binding
write failure returns retryable `503`, so the client retains queued rows.

## 3. Privacy Rules

The client ID is 128 bits from `Random.secure`, persisted for the install as
`anon_<32 lowercase hex>`. It is not a hash of an operator or subscriber
identity and cannot be used to recover one.

The client and Worker independently allowlist event names, exact property keys,
types, enum values, and count bounds. The following never enter the local queue
or telemetry request:

- subscriber/operator names, aliases, phone numbers, VC/account/customer IDs,
  addresses, areas, usernames, or other subscriber/operator PII;
- filenames, source headers, imported row values, payment notes, receipt text,
  exception text, or raw order IDs;
- IP addresses, user agents, cookies, referral codes, secrets, or credentials;
- device model, operating-system version, app install referrer, or other device
  metadata.

Device model, OS version, locale, and referrer are not sent absent a separate
explicit privacy decision. Connectivity state is a local flush trigger and is not
transmitted.

## 4. Safely Defined but Not Implemented

These names remain future taxonomy only. They are not emitted, accepted by the
current Worker, or product hooks in this change because the corresponding
product flows do not exist.

| Future event name | Proposed safe trigger | Proposed safe properties | State |
| :--- | :--- | :--- | :--- |
| `onboarding_completed` | A future onboarding flow completes its configured choices | `service_type` | Not implemented / not accepted |
| `paywall_impression` | A future upgrade surface is actually shown | `trigger_source`: `add_subscriber`, `import`, `settings` | Not implemented / not accepted |
| `upi_checkout_initiated` | A future compliant UPI checkout begins | `tier`, `billing_cycle` | Not implemented / not accepted |
| `upi_payment_succeeded` | A future server-verified payment result is available | `tier`, `billing_cycle`, `status` | Not implemented / not accepted |

No raw order ID is an allowed property. These definitions must be re-reviewed
and added to both allowlists atomically when their real product flows are
approved. Paywall, licensing, and UPI functionality is outside this plan's
implementation scope.

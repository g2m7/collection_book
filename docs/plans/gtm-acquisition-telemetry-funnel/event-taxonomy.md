# GTM Funnel Telemetry Event Taxonomy

This document specifies the exact events, triggers, and payload parameters required to track the customer acquisition and monetization funnel.

---

## 1. Funnel Milestone Event Matrix

| Event Name | Trigger Condition | Key Properties | Funnel Stage |
| :--- | :--- | :--- | :--- |
| `app_first_open` | First time app is launched after Play Store install | `referrer`, `install_time`, `locale` | Acquisition |
| `onboarding_completed` | User sets business name and selects primary service | `service_type` (`tv`, `fiber`, `both`) | Activation |
| `first_subscriber_created` | User saves their 1st subscriber record | `method` (`manual` or `mso_import`) | Activation |
| `mso_file_imported` | User imports Excel / HTML billing report | `record_count`, `mso_format`, `elapsed_ms` | Activation |
| `payment_recorded` | User logs cash / payment for any subscriber | `mode`, `has_adjustment`, `is_cleared` | Retention |
| `whatsapp_receipt_sent` | User taps "Send WhatsApp Receipt" intent | `locale`, `has_trojan_link` | Viral Loop |
| `paywall_impression` | 100-sub cap hit or user opens upgrade sheet | `trigger_source` (`add_sub`, `import`, `backup`) | Monetization |
| `upi_checkout_initiated`| User taps "Upgrade with UPI" | `tier` (`starter`, `pro`), `billing_cycle` | Monetization |
| `upi_payment_succeeded`| Webhook / local confirmation of payment | `order_id`, `amount`, `tier` | Conversion |

---

## 2. Ingest Payload Contract (`POST /api/v1/telemetry/batch`)

```json
{
  "client_id": "anon_8f7b2c91a0",
  "app_version": "1.0.0",
  "device_model": "Redmi 9A",
  "os_version": "Android 11",
  "batch_sent_at": 1790150400,
  "events": [
    {
      "event_name": "whatsapp_receipt_sent",
      "timestamp": 1790149200,
      "properties": {
        "locale": "hi",
        "has_trojan_link": true,
        "service_type": "tv"
      }
    },
    {
      "event_name": "paywall_impression",
      "timestamp": 1790150100,
      "properties": {
        "trigger_source": "subscriber_101_attempt",
        "subscriber_count": 100
      }
    }
  ]
}
```

---

## 3. Privacy & Compliance Guarantees
- **No Subscriber PII**: Customer names, phone numbers, addresses, and viewing card numbers are **strictly filtered** before entering the local queue.
- **Hashed Operator Identity**: Operator identity is represented by a local salted SHA-256 hash (`anon_...`).

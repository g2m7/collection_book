# Plan: In-Product Viral Loop & WhatsApp Receipts Engine

## 1. Overview & Objective
Local Cable Operators (LCOs) and FTTH technicians interact with 100 to 2,000+ customers monthly. Every collection is an opportunity for customer trust and organic viral acquisition. This plan specifies the engineering architecture for:
1. **Zero-Cost WhatsApp Receipts**: Generating and dispatching instant payment receipts via native Android platform intents (`whatsapp://send`), eliminating recurring Meta Cloud API / BSP fees.
2. **The "Trojan Horse" Referral Loop**: Embedding a discrete, non-intrusive footer in every receipt linking to a tracked download link, turning every receipt sent to a customer into a potential acquisition touchpoint for neighboring operators and collection boys.
3. **Database Migration (SQLite Schema v5)**: Adding the `phone` field and associated indexes to the `subscribers` table.

---

## 2. Requirements & Scope

### In Scope
- **Schema Migration (v5)**: Backwards-compatible migration adding `phone TEXT` column and indexing.
- **Intent Service**: `WhatsAppReceiptService` supporting Android `whatsapp://send` URI intent with fallback to web browser (`https://wa.me/`).
- **Dynamic Vernacular Templates**: Formatting receipts dynamically in 5 languages (English, Hindi, Marathi, Bengali, Tamil) with dynamic balance status (*Fully Paid*, *Advance*, *Arrears/Baqaya*).
- **Trojan Horse Attribution**: Unique operator referral code injected into the download link footer.
- **UI Integration**: 1-Tap "Share on WhatsApp" action button on both [`RecordPaymentScreen`](file:///c:/projects/cross/collection_book/lib/screens/record_payment_screen.dart) and [`SubscriberDetailScreen`](file:///c:/projects/cross/collection_book/lib/screens/subscriber_detail_screen.dart).

### Out of Scope
- Paid Meta WhatsApp Cloud API / Twilio BSP integration (deliberately rejected due to ₹0.80–₹1.20/msg overhead).
- Automated SMS fallback gateways (can be added in Phase 3 if operator requests).

---

## 3. Architecture & Technical Design

### 3.1 SQLite Schema Upgrade (`v4 -> v5`)

In [`lib/services/database_service.dart`](file:///c:/projects/cross/collection_book/lib/services/database_service.dart):
```dart
// Database version increment: 4 -> 5
static const int _dbVersion = 5;

// In _onUpgrade:
if (oldVersion < 5) {
  await db.execute('ALTER TABLE subscribers ADD COLUMN phone TEXT');
  await db.execute('CREATE INDEX idx_subscribers_phone ON subscribers(phone)');
}
```

### 3.2 Receipt Delivery Engine (`WhatsAppReceiptService`)

```mermaid
sequenceDiagram
    autonumber
    actor Tech as Line Boy / Operator
    participant UI as RecordPaymentScreen
    participant Receipt as WhatsAppReceiptService
    participant OS as Android OS (Intent Resolver)
    participant WA as WhatsApp App

    Tech->>UI: Logs ₹350 Cash & Taps "Save & WhatsApp Receipt"
    UI->>UI: Commits payment to SQLite
    UI->>Receipt: buildReceiptText(subscriber, payment, orgDetails, lang)
    Receipt->>Receipt: Clean phone number (strip spaces/dashes, prepend 91 if 10-digit)
    Receipt->>Receipt: Append Trojan Horse referral footer: cbk.in/r/{operatorRef}
    Receipt->>OS: launchUrl("whatsapp://send?phone=91XXXXXXXXXX&text=...")
    alt WhatsApp Installed
        OS->>WA: Opens chat with prefilled formatted receipt
        Tech->>WA: Taps Send button (1 tap)
    else WhatsApp Not Installed
        OS->>UI: Fallback to https://wa.me/ or prompt install
    end
```

### 3.3 Receipt Format & Trojan Horse Footer Structure

The receipt message follows a structured layout:
1. **Header**: Brand title & date stamp.
2. **Subscriber Details**: Name, Service Type (Cable TV / Fiber Internet), VC # or Box ID, Area.
3. **Billing Breakdown**: Billed Month, Amount Collected, Previous Dues, Remaining Arrears.
4. **Collector Signature**: Operator business name & contact.
5. **The Trojan Horse Footer**:
   ```text
   ━━━━━━━━━━━━━━━━━━━━━
   📱 Managed via Collection Book App
   👉 Cable/WiFi Operator? Try Free (100 Subs): cbk.in/r/OP9821
   ```

---

## 4. Implementation Checklist

- [ ] **Phase 1: Database Migration**
  - [ ] Update `_dbVersion` to `5` in [`lib/services/database_service.dart`](file:///c:/projects/cross/collection_book/lib/services/database_service.dart).
  - [ ] Add `ALTER TABLE subscribers ADD COLUMN phone TEXT` migration block.
  - [ ] Add index on `subscribers(phone)`.
  - [ ] Update `Subscriber` model to deserialize/serialize `phone`.

- [ ] **Phase 2: Intent Service Implementation**
  - [ ] Create `lib/services/whatsapp_receipt_service.dart`.
  - [ ] Implement phone number sanitizer (E.164 normalization for India `+91`).
  - [ ] Implement `whatsapp://send` intent launcher with URI encoding.
  - [ ] Add fallback mechanism to `https://wa.me/` via `url_launcher`.

- [ ] **Phase 3: Vernacular Template Engine**
  - [ ] Build multi-language string formatters (see `receipt-templates.md`).
  - [ ] Incorporate arithmetic status labels (*Pura Chukta*, *Baqaya*, *Advance*).
  - [ ] Add Trojan Horse viral link formatter with configurable referral code.

- [ ] **Phase 4: UI Screens & Workflows**
  - [ ] Add `phone` input field to [`lib/screens/add_subscriber_screen.dart`](file:///c:/projects/cross/collection_book/lib/screens/add_subscriber_screen.dart).
  - [ ] Update [`lib/screens/record_payment_screen.dart`](file:///c:/projects/cross/collection_book/lib/screens/record_payment_screen.dart) with "Save & Send Receipt" split action.
  - [ ] Add WhatsApp icon button on [`lib/screens/subscriber_detail_screen.dart`](file:///c:/projects/cross/collection_book/lib/screens/subscriber_detail_screen.dart) ledger entries.

---

## 5. Verification Plan

### Automated Tests
- Unit test: SQLite migration from v4 to v5 without data corruption.
- Unit test: Phone number normalization edge cases (`9876543210`, `+91 98765 43210`, `09876543210`).
- Unit test: Vernacular receipt template string formatting across all 5 languages.

### Manual Verification
- Test payment creation and receipt dispatch on Android physical device with WhatsApp installed.
- Verify that clicking the Trojan Horse link correctly routes to the app installation landing page with referral query parameters preserved.

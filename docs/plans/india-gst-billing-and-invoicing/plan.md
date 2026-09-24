# Plan: India GST Billing and Invoicing

**Status:** Future implementation plan only. No GST, invoice, registration, tax-rate, SAC, legal-compliance, deployment, or manual-verification capability is implemented by this document.

> **Important:** This is product and engineering planning, not tax, accounting, or legal advice. The proposed defaults, taxable-value treatment, invoice particulars, rounding, tax treatment, and release criteria require review by an Indian chartered accountant and, where needed, legal counsel before implementation or release. Rules, thresholds, notifications, SAC classifications, and invoice requirements must be re-verified for the intended release date.

## 1. Overview and Objective

Collection Book serves Indian local cable television operators and FTTH internet service providers. The requested future capability is a deliberately conservative, offline-first GST workflow that distinguishes tax invoices from collection receipts and avoids changing the meaning of existing customer prices or historical payments.

The plan has four objectives:

1. Preserve the current unregistered experience by default.
2. Let an eligible operator configure regular GST or composition treatment only after appropriate review.
3. Issue durable invoices for forward billing periods without inferring tax on historical transactions.
4. Keep payment collection reliable, idempotent, and clearly referenced from the invoice lifecycle.

## 2. Background and Current Repository State

- Collection Book's intended customers are Indian cable TV and FTTH operators.
- Existing WhatsApp messages acknowledge a payment. They are collection receipts, not GST tax invoices or Bills of Supply.
- `subscribers.monthly_rent` is mutable. Updating a subscriber's current rent can therefore affect how historical dynamic due calculations are displayed.
- `payments` currently stores `amount_paid` and `adjustment` as SQLite `REAL` values. `DatabaseService` uses `insertOrUpdatePayment`, and Dart models expose money as `double`; amounts can therefore carry binary floating-point rounding behavior.
- The existing monthly payment row is editable and deletable through ledger workflows. It is a collection record, not an immutable issued invoice.
- The existing service model separates cable TV (`tv`) and fiber internet (`fiber`) modes. That separation must be preserved in price periods, imports, invoice lines, filters, and reporting.
- Existing backups copy the SQLite database and restore by replacing it. A future invoice-numbering design must account for numbering state, divergent backups, and restore behavior.

## 3. Official Research Baseline

The items below are a product-planning baseline from official CBIC materials. They are not a substitute for CA review, notification checks, or a decision on the operator's exact facts.

### 3.1 Services, rates, and classification

- Most services are generally taxed at **18%**, but the applicable rate depends on the service classification and current notifications.
  - Official source: [CBIC — GST rates for goods and services](https://cbic-gst.gov.in/hindi/gst-goods-services-rates.html)
- **SAC 998466** is the proposed editable default for cable television distribution/program transmission-type services, and **SAC 998422** is the proposed editable default for internet access services. These are classification defaults only, not automatic legal determinations.
  - Planning source: [CBIC — GST rates for goods and services](https://cbic-gst.gov.in/hindi/gst-goods-services-rates.html)
- The implementation must require CA confirmation before locking an operator to a SAC classification or rate. It must not silently change a configured SAC/rate when external material changes.

### 3.2 Place of supply, CGST/SGST, and IGST

- A transaction with supplier and recipient in the same state is generally evaluated for **CGST plus SGST**, each **9%** where the total applicable rate is 18%.
- A transaction involving different states is generally evaluated under **IGST**; the initial planning baseline for the services discussed here is **18%**, subject to the service classification, current notifications, and CA review.
- Place of supply and recipient location can be more complicated than comparing only a supplier state code with a billing address. Interstate invoices therefore require separate product rules and must not be inferred in the initial MVP.
  - Official source: [CBIC — Integrated Goods and Services Tax Act](https://cbic-gst.gov.in/aces/Documents/IGST-bill.pdf)
  - Supporting source: [CBIC — GST rates for goods and services](https://cbic-gst.gov.in/hindi/gst-goods-services-rates.html)

### 3.3 Registration and charging eligibility

- The broad general GST registration threshold for a person supplying services is **₹20 lakh aggregate annual turnover**, with a **₹10 lakh** threshold in Manipur, Mizoram, Nagaland, and Tripura, subject to compulsory-registration cases, exemptions, notifications, and later amendments.
  - Official source: [CBIC — Concept/status of GST](https://cbic-gst.gov.in/pdf/01052019-GST-Concept-Status.pdf)
- Notification No. 2/2019–Central Tax (Rate) introduced a separate concessional scheme for eligible service suppliers with preceding-financial-year aggregate turnover up to **₹50 lakh**, generally at **6% total tax (3% central plus 3% state)** and subject to its conditions. This must not be confused with registration thresholds or the ordinary composition scheme.
  - Official sources: [CBIC — Concept/status of GST](https://cbic-gst.gov.in/pdf/01052019-GST-Concept-Status.pdf) and [CBIC — Composition Rules](https://cbic-gst.gov.in/composition-rules.html)
- The app must not determine that an operator is registered, eligible, exempt, or outside a threshold from incomplete data. It must require an explicit operator-confirmed mode and the business information needed for that mode.
- An **unregistered person cannot charge or separately collect GST** in the regular GST invoice model. The unregistered mode must not show CGST, SGST, IGST, or a tax amount collected by the operator.
  - Supporting official source: [CBIC — Concept/status of GST](https://cbic-gst.gov.in/pdf/01052019-GST-Concept-Status.pdf)

### 3.4 Composition or concessional-scheme taxpayers

- A taxpayer using an applicable composition or concessional service-supplier scheme uses a **Bill of Supply**, not the regular GST tax-invoice flow, subject to CA confirmation of the exact scheme and document requirements.
- Such a taxpayer must **not separately show or collect GST** from the customer. The application must not present the operator's own tax liability as a customer tax component.
- This treatment is not a fallback for regular GST registration. Mode selection must preserve the distinction and prevent regular tax-invoice behavior.
  - Official source: [CBIC — Composition Rules](https://cbic-gst.gov.in/composition-rules.html)

### 3.5 Invoice rules

- Regular tax invoices and Bills of Supply have distinct required particulars and declarations. A current invoice should identify the parties and invoice, describe the taxable supply, show the applicable classification and values, and show the appropriate tax components and totals according to the taxpayer's status and place of supply.
  - Official source: [CBIC — GST invoice rules](https://cbic-gst.gov.in/gst-invoice-rules.html)
- This plan describes a candidate high-level field set only. The final field set, compulsory declarations, document numbering, signatures, QR/IRN treatment, and customer-detail rules require CA/legal approval.

## 4. Recommended Product Modes

### 4.1 Unregistered (default)

- New and upgraded installations remain **Unregistered** until an operator explicitly configures another mode.
- Preserve the current displayed monthly price and collection workflow.
- Do not show a GST-inclusive label unless the operator has affirmatively opted into the safe-default policy after reviewing the migration preview.
- Do not create inferred invoices, tax components, GSTIN requirements, or registration prompts that block collections.
- Name the output a payment receipt, not a tax invoice.

### 4.2 Regular GST

- Intended only for an operator who confirms that they are registered and supplies a valid GSTIN and required business particulars.
- Initial MVP scope is limited to confirmed **intra-state supplies**.
- Permit an editable SAC selection per service category, with cable (`998466`) and internet (`998422`) as suggested defaults, not locked legal classifications.
- Support a CA-reviewed rate per service/line and clearly label the mode as regular GST.
- Block invoice issuance if required business, supplier, recipient, service, price-period, SAC/rate, or place-of-supply data is invalid; payment collection must remain usable where safe.

### 4.3 Composition

- Intended only for an operator who confirms current composition eligibility and acknowledges the selected mode's reviewed charge treatment.
- Issue a **Bill of Supply**, never a regular tax invoice.
- Do not calculate or display separate CGST, SGST, or IGST and do not imply that the customer paid GST separately.
- Keep the regular-GST invoice form and composition Bill of Supply form behavior isolated and covered by distinct tests.
- Do not use composition mode to support interstate MVP behavior.

## 5. Recommended Safe Defaults

- Treat all current displayed prices as **GST-inclusive** when regular GST mode is activated.
- Show the resulting exclusive taxable value and tax components only in the invoice preview; do not silently increase the amount collected from the customer.
- Activation is **forward-only**, from an operator-selected effective billing period/date.
- Do **not** infer GST for retroactive periods, infer tax from historical payments, or create historical tax invoices during activation.
- Existing historical payments remain payment receipts and receive no inferred tax breakdown.
- Keep **invoice issuance separate from payment recording**: creating an invoice does not mean cash was collected, and recording a payment does not silently create an invoice.
- Keep SAC editable and require explicit confirmation for service classifications and rates.
- Default to no interstate invoice issuance in the initial implementation.
- Require a review acknowledgement during setup that the configuration is operator- and CA-reviewed and that the app does not provide tax advice.

## 6. Requirements and Scope

### 6.1 In scope for a future MVP

- Three explicit modes: unregistered, regular GST, and composition.
- SQLite business/tax profile and customer tax details where required.
- Effective-dated, immutable price periods that preserve the amount the customer is charged.
- Regular tax-invoice and composition Bill of Supply workflows, initially intra-state regular GST only.
- Deterministic integer-paise tax calculation, rounding, and invoice totals.
- Sequential invoice/Bill of Supply numbering per financial year.
- Immutable issued documents with line-item and party/profile snapshots.
- Explicit invoice issue, view, share, and controlled cancellation decision flow.
- Payment receipt recording with optional invoice reference/allocation.
- WhatsApp acknowledgement enhanced with the relevant invoice/Bill of Supply number or reference, while remaining a receipt/acknowledgement rather than the invoice document.
- Import, migration, backup, and restore compatibility.
- User-visible validation, privacy, recovery, and error states.

### 6.2 Explicit non-goals for the MVP

- Determining GST registration, eligibility, exemption, or threshold status.
- GST registration or application workflows.
- GST returns preparation, submission, reconciliation, or filing.
- GSTR-1/GSTR-3B or other GSTR exports unless separately planned and approved.
- E-invoice IRN/QR generation, signing, acknowledgement, or cancellation.
- E-way bills or vehicle/document reporting.
- Automatic online GSTIN validation.
- Interstate invoice issuance, IGST calculation, export, or place-of-supply determinations beyond an explicit intra-state guard.
- Credit notes, debit notes, or other document types beyond the separately reviewed cancellation/correction process required for MVP.
- Retroactive or bulk-backdated inferred GST invoices.
- Automatic legal, tax-rate, notification, or SAC updates.
- Cloud synchronization, multi-device invoice-number coordination, or a backend tax service.
- Tax advice, accounting advice, or automatic eligibility decisions.

## 7. Architecture and Technical Design

### 7.1 Business and tax profile

Create an effective-dated business tax profile rather than overloading current receipt preferences. A candidate profile includes:

- mode: `unregistered`, `regular`, or `composition`;
- effective-from boundary and optional effective-to boundary;
- supplier legal/trade name, address, state code, and contact details;
- GSTIN for confirmed registered regular or composition/concessional-scheme profiles (stored and displayed as a local business record, not sent to a third-party validator in the MVP);
- SAC and reviewed rate defaults for cable and fiber services, with explicit confirmation;
- invoice/Bill of Supply series prefix and numbering configuration;
- configuration acknowledgement/version for later audit and migration support.

Rules:

- Reuse the singleton `DatabaseService`; do not introduce a second database abstraction.
- Use parameterized SQL and transactions for all profile, sequence, invoice, and payment-reference writes.
- Effective dates must prevent a new profile from changing the snapshot on an already issued document.
- Show clear, actionable errors and a recovery path for missing or invalid fields.

### 7.2 Subscriber/customer tax details

Add customer tax/address fields only where the approved invoice type needs them. Likely candidates are billing legal name, address, state code, optional GSTIN, and phone/email. Keep these fields distinct from collection identity fields so payment recording is not blocked when a customer is not available or invoice details are incomplete.

The regular-GST intra-state path must validate the supplier and customer state/place-of-supply inputs under the CA-reviewed rules. Invalid or indeterminate data must fail invoice issuance rather than falling back silently to CGST, SGST, or IGST.

### 7.3 Effective-dated price periods

Introduce price periods so historical documents do not depend on the mutable current `monthly_rent`:

- candidate fields: subscriber/service identity, effective-from month or timestamp, effective-to, displayed customer price in paise, price basis (`gst_inclusive` or a CA-approved future basis), SAC, rate snapshot, currency, and activation source;
- closing a period transactionally when a new price starts prevents overlap;
- invoice and preview calculation resolve the applicable period by billing service date, not by today's current rent;
- changing a subscriber's current rent creates a new future/effective period and does not rewrite old price periods;
- activation from the legacy model creates a clearly marked forward-only period and never labels a historical price as GST-taxed.

The first migration should retain the legacy `monthly_rent REAL` path for existing collection screens. New tax/invoice calculations should use integer paise and snapshots. A later migration may convert legacy displayed prices deterministically; it must not reinterpret historical payments as taxable bases.

### 7.4 Immutable invoices and line snapshots

A future document model should separate an editable draft/preview from an issued document:

- `invoices` or a future document table: type (`tax_invoice` or `bill_of_supply`), status, financial year, sequential number, issue date, service period, place of supply, supplier/customer snapshot identifiers, totals in paise, share/cancel metadata if approved, and document schema version;
- `invoice_lines`: immutable line snapshots with service description, service mode, SAC, quantity/unit, taxable value, rate, discount/adjustment, CGST, SGST, IGST as applicable, line total, and rounding remainder;
- immutable party/profile snapshots on the document so later edits to the operator or subscriber cannot rewrite history;
- a deterministic, human-readable document preview and share artifact built only from issued snapshots.

Once issued, financial fields and line snapshots are not edited in place. Any correction/cancellation must use a separately reviewed state transition and audit record. The MVP must not invent credit/debit notes or legal cancellation semantics.

### 7.5 Sequential numbering per financial year

Numbering must be transactional and gap-auditable:

- allocate a series/prefix for each financial year and document type;
- reserve or increment the next number inside the same transaction that issues the document;
- enforce uniqueness across the selected financial year/series;
- persist the sequence state with the invoice so a database copy/restore cannot silently reuse a number without detection;
- make failed issuance behavior explicit: either the number is not consumed, or a gap and state are recorded according to the CA-approved policy.

A local offline app cannot by itself guarantee globally unique numbering across independently restored devices or divergent backups. This limitation, the restore merge policy, and any future multi-device coordination must be resolved before promising global uniqueness.

### 7.6 Payment receipts and invoice references

Keep `payments`/collection records conceptually separate from issued documents:

- a payment records what was collected, when, by whom, and for which billing periods;
- an invoice records what was billed and the tax/document details at issue time;
- an optional allocation/receipt table references one or more issued invoices and records the allocated amount in paise;
- WhatsApp messages display a payment receipt with the invoice/Bill of Supply reference when one exists, and clearly say when no invoice has been issued;
- payment edits/deletes must not mutate or erase issued document history; a warning and CA-reviewed correction path is required for references that would become invalid.

The MVP should prevent accidental double allocation and make unallocated/over-allocated amounts visible.

### 7.7 Integer-paise math and deterministic rounding

- Store new monetary values as signed integer paise; do not use `double` for invoice calculations, tax components, or totals.
- Parse legacy `REAL` values at the boundary with an explicit, tested conversion policy. Preserve the displayed amount unless a CA-reviewed migration explicitly changes its basis.
- Calculate GST-inclusive totals with integer arithmetic, for example by deriving the exclusive base from the inclusive paise total and the configured rate, rather than binary floating-point division.
- Define a single documented rounding policy for taxable value, each tax component, line total, and invoice total. Reconcile component remainders deterministically to the line/invoice total; never rely on display rounding to fix a mismatch.
- Test half-paise boundaries, zero-rated/zero-value cases permitted by the selected mode, large totals, discounts/adjustments, repeated views, and totals that must match the issued snapshot exactly.
- Let a CA review approve the final rounding and extraction policy before it is enabled in production.

### 7.8 Import and migration compatibility

- Keep `ImportService` parsing isolated and preview side-effect free; it must never issue invoices or collect tax during preview.
- Preserve `tv`/`fiber` service separation in mappings, validation, price periods, and invoice lines.
- Validate required identifiers, amounts, SAC/rate combinations, and effective dates before any tax-related write.
- Existing imports that create/update subscribers or record payments must remain usable in unregistered mode. They must not infer GST or manufacture historical documents.
- For regular GST/composition activation, show a preview that identifies the forward effective period, untouched historical periods, and any customers requiring new tax details.
- Use additive SQLite migrations and preserve compatibility with existing `REAL` collection fields until the full collection-flow migration is deliberately approved. Never destructively reinterpret the old schema in place.
- Define transaction boundaries so a failed invoice import or issue cannot partially create a document, consume a sequence, or attach a payment reference.

### 7.9 Backup, restore, and portability

- Extend the existing backup/restore contract to include every new tax, price, invoice, snapshot, sequence, and allocation table.
- Include a schema/document-format version in the backup or restore validation and refuse incompatible restores with a clear message.
- Verify that restore preserves issued documents, snapshots, numbering state, and audit metadata.
- Detect divergent sequence state when a restored database could reuse an invoice number; require an explicit operator decision and CA-reviewed numbering policy before allowing a potentially unsafe restore.
- Do not promise cloud or multi-device uniqueness in the offline MVP. Backup sharing must continue to use the existing local-file/share flow and must not silently upload tax data.

### 7.10 Services and boundaries

Candidate boundaries are a focused tax/invoice service, invoice renderer, and extension points for the existing `DatabaseService`, `ImportService`, `BackupService`, and `WhatsAppReceiptService`. Keep calculation pure where possible, transaction orchestration in the database/service boundary, and UI components small.

Expected boundary responsibilities:

- tax service: mode validation, effective price resolution, paise calculation, deterministic rounding, and document-type selection;
- invoice service: draft creation, validation, transactionally issued snapshots, numbering, and reference retrieval;
- renderer: deterministic preview/share content from snapshots only;
- payment service: receipt persistence and invoice allocation without mutating issued documents;
- file/import service: validation and preview only, with explicit commit;
- WhatsApp service: receipt/acknowledgement text and safe native/browser handoff, never claiming a payment message is a tax invoice.

## 8. UX Surfaces

### 8.1 Setup and settings

- Add a clearly labeled **Billing and GST** setup surface without changing the default unregistered workflow.
- Explain the three modes in plain language and show the CA-review warning before activation.
- Collect effective date/period, legal/trade name, address/state, GSTIN for registered regular or composition/concessional-scheme modes, SAC/rate confirmation, and invoice series.
- Validate before save; preserve a draft if any field fails.
- Show a read-only summary of current mode, effective period, configured SAC/rate, and unresolved warnings.
- Support suspending future invoicing without changing issued documents; CA/legal review is required for any mode change or cancellation.

### 8.2 Subscriber/customer details

- Add only the customer fields required by the reviewed invoice flow.
- Show whether the customer is ready for a regular GST invoice, needs tax details, or is not eligible for that document path.
- Allow payment recording while explaining that an invoice cannot be issued until required data is completed, where safe.
- Never overwrite historical invoice snapshots when customer details change.

### 8.3 Monthly invoice issue, view, and share

- Add a clear **Issue monthly invoice** action separate from **Record payment**.
- Preview the billing period, customer, place of supply, SAC, taxable value, tax components or Bill of Supply treatment, and total before confirmation.
- Require explicit confirmation; show a progress state while the database transaction executes.
- Offer view and share actions only for issued documents. The share artifact must be based on the immutable snapshot.
- For composition mode, label the document **Bill of Supply** and suppress regular tax-invoice tax-component language.
- For unregistered mode, do not offer a regular tax invoice or imply that a payment receipt is an invoice.
- Define clear states for invalid data, duplicate issue, numbering failure, interrupted storage, and unavailable share target.

### 8.4 WhatsApp receipt reference

- Preserve the current payment acknowledgement use case.
- Add a reference such as `Tax invoice: <number>` or `Bill of Supply: <number>` when a document exists.
- If no document exists, state that the message is a payment receipt and does not itself constitute a tax invoice or Bill of Supply.
- Keep recipient phone normalization, language templates, WhatsApp/browser fallback, and existing referral behavior intact.
- Do not include unnecessary GSTIN, address, or customer data in the message; share the document separately where appropriate.

### 8.5 Validation and error states

Surface actionable states for:

- incomplete supplier/GSTIN/business profile;
- missing or invalid customer billing details;
- same-state requirement and unresolved place of supply;
- invalid SAC/rate or editable-classification confirmation;
- price period gaps/overlaps and legacy price conversion;
- integer conversion, rounding, or total mismatch;
- duplicate invoice/Bill of Supply and sequence exhaustion;
- draft, issued, cancellation-required, and share states;
- backup/restore incompatibility or numbering conflict;
- payment allocation conflicts and deleted/referenced payment records.

No error should silently fall back to another tax mode, tax component, or document type.

## 9. High-Level Compliance Invoice Particulars

The final requirements must be CA/legal approved. The candidate regular GST tax-invoice set should cover, as applicable:

- supplier legal name, registered address, GSTIN, state, and contact details;
- recipient legal name, address, GSTIN/state details where required, and place of supply;
- unique sequential invoice number, invoice date, and billing/service period;
- description of taxable supply/service, service category, SAC, quantity/unit, rate, and taxable value;
- discount/adjustment treatment and the approved line-level tax values;
- CGST and SGST for the supported intra-state case, or IGST only after a separately approved interstate design;
- total taxable value, total tax, invoice total in words where required, and other required declarations/signatures;
- document type, issuer, issue status, and any approved cancellation/correction reference.

The composition Bill of Supply should instead follow the reviewed composition particulars, clearly identify itself as a Bill of Supply, and must not present separate GST collection. The unregistered output is a payment receipt, not a tax invoice.

The following are intentionally not promised: e-invoice IRN/QR, e-way bills, digital signatures, automatic GSTIN validation, credit/debit notes, or online returns compliance.

## 10. Phased Implementation Checklist

Every item in this future plan is pending.

### Phase 0: CA and legal review

- [ ] Confirm whether the MVP can use the recommended three-mode product model and who is responsible for each declaration.
- [ ] Verify current GST registration thresholds, composition eligibility/conditions, rate/SAC treatment, place-of-supply rules, invoice rules, and required particulars against official sources and the operator's facts.
- [ ] Approve GST-inclusive price activation, no retroactive inference, integer-paise rounding, invoice numbering, cancellation/correction, and backup/restore policies.
- [ ] Define the exact release wording, privacy treatment, and support/escalation policy for the app's non-advice disclaimer.

### Phase 1: Product contracts and safety policy

- [ ] Specify mode transitions, effective-dated behavior, supported intra-state rule, and blocked states.
- [ ] Define document types, numbering series, financial-year rules, issue/cancel state transitions, and invoice/payment references.
- [ ] Specify import, migration, backup, restore, and privacy acceptance rules before touching schema or UI.

### Phase 2: SQLite and domain model

- [ ] Add additive tax/business profile, customer-tax-detail, effective price-period, invoice, line-snapshot, numbering, audit, and allocation tables.
- [ ] Add models and explicit integer-paise fields while preserving the current `DatabaseService` singleton and migration chain.
- [ ] Define indexes, foreign keys, uniqueness constraints, transaction boundaries, and migration rollback/recovery behavior.
- [ ] Add deterministic database tests for fresh installs, upgrades, overlaps, numbering, and restore state.

### Phase 3: Calculation and validation services

- [ ] Implement mode/profile validation and effective price resolution.
- [ ] Implement inclusive-price extraction and integer-paise CGST/SGST calculation for the approved intra-state regular GST path.
- [ ] Implement deterministic rounding/remainder reconciliation and composition Bill of Supply behavior.
- [ ] Reject invalid SAC/rate, state/place-of-supply, party, period, and document data without fallback behavior.
- [ ] Add unit/property tests for boundaries, totals, discounts, zero values, large paise values, and repeatability.

### Phase 4: Invoice lifecycle and rendering

- [ ] Implement draft preview, explicit issue confirmation, immutable snapshot persistence, and view/share rendering.
- [ ] Implement sequential number allocation per financial year and document type inside a transaction.
- [ ] Implement duplicate, interruption, sequence, and cancellation/correction states approved in Phase 0.
- [ ] Ensure rendering reads issued snapshots only and produces a stable document artifact.

### Phase 5: Payment and WhatsApp integration

- [ ] Keep payment recording independent from invoice issuance.
- [ ] Add optional invoice/Bill of Supply references and allocation validation without mutating issued documents.
- [ ] Update WhatsApp acknowledgement text to include a reference when available and state when it is only a receipt.
- [ ] Add tests for no-invoice, invoice-referenced, composition, allocation-conflict, and delivery-failure cases.

### Phase 6: Settings and subscriber UX

- [ ] Add the billing/GST setup and read-only settings summary with Unregistered as the default.
- [ ] Add customer tax-detail fields and readiness/error states.
- [ ] Add monthly invoice issue/view/share flows, with progress and recovery states.
- [ ] Add a clearly separate payment-recording path and update affected navigation/help text.

### Phase 7: Import, migration, backup, and restore

- [ ] Keep import preview side-effect free and preserve TV/fiber isolation.
- [ ] Implement forward-only activation preview and safe legacy price conversion/payment handling.
- [ ] Add new tables to backup/restore and version/restore validation.
- [ ] Detect and handle numbering conflicts from divergent restores without silently reusing a number.

### Phase 8: Verification and release hardening

- [ ] Add and run deterministic unit/widget/migration tests.
- [ ] Add/update Patrol journeys and stable app keys for the approved user-visible flows.
- [ ] Complete CA/legal review of the exact strings, fields, labels, tax math, invoice artifacts, and disclaimer.
- [ ] Complete the verification checklist below, including Patrol compile and any available Android device/emulator execution.
- [ ] Review release documentation and operator support instructions.

### Phase 9: Deployment and rollout

- [ ] Obtain explicit product, CA, legal, and release approval after all checks are evidenced.
- [ ] Prepare a release/rollback plan that keeps Unregistered mode safe and preserves issued documents.
- [ ] Deploy only the approved Flutter build and document the exact artifact/version.
- [ ] Perform manual smoke verification on a real supported Android device before enabling the feature for general users.
- [ ] Keep any feature flag, staged rollout, or support escalation decision explicit; no deployment is assumed by this plan.

## 11. Verification Plan

All verification items are pending because the feature is not implemented.

### Static and automated checks

- [ ] Run `dart format --output=none --set-exit-if-changed lib test patrol_test` after implementation.
- [ ] Run `flutter analyze` and resolve all introduced findings.
- [ ] Run targeted tax, migration, import, payment, backup/restore, and widget tests.
- [ ] Run `flutter test` for the complete Flutter suite.
- [ ] Run `patrol doctor` and the pinned Patrol CLI setup where required by the repository.
- [ ] Run `patrol build android --debug`; the Android instrumentation compile gate must pass.
- [ ] Optionally run `(cd android && ./gradlew :app:assembleDebugAndroidTest)` under JDK 17 when required by the environment.
- [ ] If any Bun/shared contract files are affected by a separately approved implementation, run `bun run format:check`, `bun run typecheck`, `bun test`, and `bun run build:worker`/`bun run verify:bun` as applicable. This Flutter-only plan does not claim Bun verification.
- [ ] Run `git diff --check`.
- [ ] Confirm `git diff --cached` is empty unless the user explicitly authorized staging.
- [ ] Confirm no debug prints, placeholder tax values, fake GSTINs, fake certificates, secrets, or unsupported legal claims remain.

### Patrol status and manual verification

- [ ] Record whether affected Patrol journeys were executed on a named Android device/emulator; compilation is not execution.
- [ ] Exercise Unregistered setup, Regular GST intra-state issue/view/share, Composition Bill of Supply, forward-only activation, payment/reference separation, invalid-data errors, backup, restore, and numbering conflict scenarios.
- [ ] Verify the generated tax invoice/Bill of Supply on a real supported Android device against the CA-approved sample, including arithmetic, particulars, labels, and share behavior.
- [ ] Verify physical WhatsApp/browser handoff with a receipt and referenced document, and verify the no-invoice message does not claim to be an invoice.
- [ ] Perform a manual CA-led review of representative cable and fiber invoices; record approval evidence before release.
- [ ] Do not mark a device-only scenario passed when no device, WhatsApp target, or test fixture is available.

### Documentation and release evidence

- [ ] Update user-facing documentation only after behavior is implemented and verified.
- [ ] Record the final CA/legal decisions, source re-check date, supported classifications/rates, rounding policy, document schema, and release version.
- [ ] Confirm this plan's checkboxes are updated honestly: implementation, review, deployment, and manual checks remain pending until evidence exists.

## 12. Risks and Open Decisions

- **Legal/tax accuracy:** CBIC pages and notifications can change; classification and rate defaults may be wrong for a particular operator. A CA must own the release decision.
- **Place of supply:** Address/state data may be incomplete or misleading. The MVP must block uncertain cases rather than infer IGST or a state split.
- **Inclusive-price interpretation:** Existing prices may not consistently have been quoted as inclusive. Activation must be explicit and forward-only, with a CA-reviewed migration explanation.
- **Historical data:** Legacy `REAL` amounts, mutable rents, deleted/edited payments, and unknown historical prices cannot be safely back-taxed or inferred.
- **Numbering and restore:** Local sequential numbering cannot guarantee global uniqueness across devices, app reinstalls, or divergent backups. Restore conflict policy is unresolved.
- **Invoice correction:** A legally meaningful cancellation/correction model is not the same as editing a receipt. The MVP must not invent it.
- **Composition scope:** Composition eligibility, rate, eligible supplies, and document conditions are operator-specific and legally sensitive.
- **Privacy:** GSTIN, legal names, and addresses are sensitive business/customer data. MVP storage, backups, sharing, logs, and analytics must be reviewed.
- **Offline/import reliability:** File parsing, interrupted issue transactions, duplicate documents, and allocation conflicts need explicit recovery behavior.
- **Share artifact:** PDF/print/share implementation and formatting are pending; the artifact must be derived only from immutable snapshots.
- **Regulatory integrations:** E-invoice, e-way bills, GSTIN validation, returns, and exports are out of scope and must not be implied by ordinary invoice issuance.

## 13. Acceptance Criteria for a Future MVP

Acceptance means a later implementation can demonstrate all of the following; none is claimed today:

- [ ] Unregistered is the default and never displays or collects GST through a regular invoice flow.
- [ ] A CA-reviewed Regular GST setup produces deterministic intra-state tax-invoice previews with correct paise arithmetic and required approved particulars.
- [ ] A CA-reviewed Composition setup produces a Bill of Supply and never presents separate GST collection.
- [ ] Activation is forward-only; historical payments and invoices are not inferred, rewritten, or back-taxed.
- [ ] Issued documents are immutable snapshots, numbered sequentially per financial year/series, and viewable/shareable after app restart.
- [ ] Invoice issuance and payment recording are separate operations, with explicit and safe invoice references.
- [ ] Imports, migrations, and backup/restore preserve legacy collection behavior and invoice/sequence integrity, with actionable conflicts rather than silent data loss.
- [ ] TV/fiber service separation, required validation, deterministic rounding, and all user-visible error states are covered by automated tests and the approved documentation.
- [ ] CA/legal review, release approval, deployment, and manual Android verification are documented with evidence before the feature is released.

## 14. Source and Implementation Boundary

This plan intentionally contains no application-code changes. The official CBIC links above are research inputs, not an automated legal update mechanism. Until an approved implementation task, CA/legal review, tests, deployment, and manual device verification are all pending.

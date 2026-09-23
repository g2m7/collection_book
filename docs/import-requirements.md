# Import System Requirements

## 1) Objective
Build a fast, reliable import system that:
- Imports TV and Internet subscribers from spreadsheets with strong validation.
- Keeps TV and Internet subscriber domains fully separate.
- Prevents partial/unsafe imports.
- Provides clear progress and error visibility.

## 2) Scope
In scope:
- Subscriber import for TV and Internet services.
- Dynamic column mapping with deterministic rules.
- Strict required-field validation and fail-on-missing-required behavior.
- Import wizard with preview, dry-run, execution, and error report.
- Import history and error tracking in app.
- Service separation enforcement (`tv` vs `fiber` only).

Out of scope (for this release):
- Background cloud sync.
- OCR/PDF import.
- AI-based fuzzy matching beyond deterministic heuristics.

## 3) Non-Negotiable Business Rules
- A subscriber MUST belong to exactly one service type: `tv` or `fiber`.
- `both` service type is not allowed in create, edit, import, or query paths.
- Import MUST be atomic: if required mapping/validation fails, nothing is written.
- If required fields cannot be resolved with confidence, import is rejected.
- Internet source files are imported only into Internet mode; TV files only into TV mode unless user explicitly chooses target service and mapping validates.

## 4) Data Requirements

### 4.1 Required fields per imported subscriber row
- `service_type` (resolved from wizard selection, not inferred from one row)
- `subscriber_name`
- `monthly_amount`
- `start_period` (year/month or parseable date)
- `unique_identifier` (at least one strong ID)

### 4.2 Strong identifier policy
TV accepted strong IDs:
- `vc_number` OR `stb_number` OR `customer_nbr`

Internet accepted strong IDs:
- `account_id` OR `username` OR `phone` (only if combined with `area`)

If no strong ID is available for a row, that row is invalid.
If invalid-row ratio exceeds configured threshold (default 5%), abort entire import.

### 4.3 Optional fields
- `area`
- `alias_name`
- `previous_due`
- `is_active`
- Payment columns (`amount_paid`, `adjustment`, `payment_period`) where present

## 5) Dynamic Mapping Requirements
- System MUST normalize headers (trim, lowercase, remove punctuation/extra spaces).
- System MUST support synonym dictionary for each target field.
- System MUST run deterministic value-shape checks:
  - ID-like patterns for identifier fields
  - numeric checks for money fields
  - date/month parsing checks for period fields
- System MUST calculate mapping confidence per required field.
- Any required field below confidence threshold MUST block import.
- User MUST be able to review/edit mapping before commit.

## 6) Validation and Error Handling
- Validation layers:
  1. file-level format validation
  2. mapping-level required-field validation
  3. row-level data validation
  4. business-rule validation (service separation, uniqueness)
- Import commit runs in one transaction.
- Fatal validation failures -> rollback entire transaction.
- Error report must include: row number, source column, reason, severity.

## 7) Service Separation Requirements
- DB and domain rules must only allow `service_type IN ('tv', 'fiber')`.
- UI create/edit must not show `both` option.
- Queries and dashboards must not include cross-service blending.
- Upsert matching must include `service_type` boundary:
  - A TV row cannot update a fiber subscriber and vice versa.
- If same identifier exists in opposite service, flag as conflict and reject row.

## 8) Import Wizard Requirements
Wizard steps:
1. Select target service (`tv` or `fiber`)
2. Upload file
3. Detect format + propose mapping
4. Validate required fields and show issues
5. Dry-run summary (insert/update/reject/conflict counts)
6. Execute import with progress
7. Completion summary + error export

Required UX behaviors:
- Progress percentage and stage label during import.
- Cancel allowed before commit, not during commit phase.
- Clear error language (non-technical where possible).

## 9) Settings Expansion Requirements
- Add an "Import Center" section in Settings.
- Separate actions for TV import and Internet import.
- Add "Import History" and "Failed Rows" management options.
- Keep backup/restore intact and clearly separated from import actions.

## 10) Performance and Reliability
- Preview generation for up to 10k rows should complete within acceptable device limits.
- Import must avoid UI freeze (show progress, chunk processing if needed).
- App must survive malformed files without crash.

## 11) Security and Data Integrity
- Never execute formula content from spreadsheet cells.
- Sanitize all text inputs before persistence.
- Enforce SQL parameterization (already used via sqflite query args).
- Keep audit data for import run metadata.

## 12) Release Gate (Requirements Completion)
All must be true before release:
- [ ] `both` removed from data model usage and UI paths.
- [ ] Required-field validator blocks invalid files.
- [ ] Atomic import transaction with rollback verified.
- [ ] Wizard supports detect -> map -> dry-run -> import -> report flow.
- [ ] TV and Internet imports are isolated and conflict-safe.
- [ ] Import history and failed row reporting available in-app.

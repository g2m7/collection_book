# Import System Implementation Plan

## Goal
Ship a production-safe import flow quickly, with strict service separation and strong validation.

## Delivery Strategy
- Phase 1: safety and invariants first
- Phase 2: wizard and operator UX
- Phase 3: tracking and hardening

---

## Phase 1 - Core Safety (Highest Priority)

### Tasks Checklist
- [ ] Remove `both` from subscriber create/edit UI.
- [ ] Update domain comments/types to only allow `tv|fiber`.
- [ ] Update DB query filters to stop treating `both` as valid.
- [ ] Add migration guard for legacy `both` rows (map or block with remediation).
- [ ] Introduce import validation contract for required fields.
- [ ] Add deterministic mapping engine (header normalization + synonyms + value-shape checks).
- [ ] Add fatal validation path for missing required fields.
- [ ] Enforce import transaction rollback on fatal errors.
- [ ] Enforce service-bound upsert keys (no cross-service update).
- [ ] Add unit tests for required-field and service-bound validation.

### Acceptance Criteria
- AC1: User cannot create or edit a subscriber with `service_type=both`.
- AC2: Importing a file with unresolved required fields fails before DB write.
- AC3: Importing rows that collide with opposite service IDs marks conflicts; no cross-service overwrite occurs.
- AC4: If fatal validation occurs, DB state remains unchanged.
- AC5: Existing TV/Fiber list and dashboard screens show only strict service data.

### Verification Checklist
- [ ] Manual: attempt to set `both` in UI (not possible).
- [ ] Manual: import file missing unique identifier -> import rejected.
- [ ] Manual: import file missing monthly amount -> import rejected.
- [ ] Manual: same VC exists in opposite service -> row conflict shown.
- [ ] Automated: tests pass for validator and service-bound upsert logic.

---

## Phase 2 - Import Wizard MVP

### Tasks Checklist
- [ ] Create Import Wizard screen flow (stepper/multi-step).
- [ ] Step 1: select target service (TV/Internet).
- [ ] Step 2: file picker upload.
- [ ] Step 3: auto-detect profile + mapping preview/edit.
- [ ] Step 4: dry-run analysis summary (insert/update/reject/conflict).
- [ ] Step 5: import execution with progress indicator.
- [ ] Step 6: completion summary with failed rows table.
- [ ] Add "Export failed rows" CSV action.
- [ ] Wire Settings "Import Subscribers" to wizard entry.

### Acceptance Criteria
- AC6: User can complete import end-to-end through wizard with no hidden steps.
- AC7: Wizard blocks "Next" when required mapping is unresolved.
- AC8: Dry-run counts match final import outcome (except user-cancel).
- AC9: Import progress is visible and completion shows clear totals.
- AC10: Failed rows can be exported for correction.

### Verification Checklist
- [ ] Manual: TV import happy path via wizard.
- [ ] Manual: Internet import happy path via wizard.
- [ ] Manual: unresolved mapping blocks progression.
- [ ] Manual: cancellation before commit leaves DB unchanged.
- [ ] Manual: failed row export downloads valid CSV.

---

## Phase 3 - Management, Tracking, and Hardening

### Tasks Checklist
- [ ] Add Import History model/table/service.
- [ ] Persist each run metadata (file name, service, start/end time, counts, status).
- [ ] Add Settings "Import Center" section with:
  - [ ] TV Import
  - [ ] Internet Import
  - [ ] Import History
  - [ ] Failed Rows
- [ ] Add import run details screen with searchable error rows.
- [ ] Add performance safeguards (chunked processing, responsiveness checks).
- [ ] Add malformed-file crash guards and user-safe error messages.

### Acceptance Criteria
- AC11: Every import run appears in history with status and counters.
- AC12: User can open run details and inspect errors.
- AC13: Malformed files do not crash app; user gets actionable error message.
- AC14: Large-file import remains responsive and shows progress.

### Verification Checklist
- [ ] Manual: history entry created for success and failure runs.
- [ ] Manual: run detail includes row-level error reasons.
- [ ] Manual: malformed HTML/XLS and invalid CSV handled gracefully.
- [ ] Manual: large file test shows progress without frozen UI.

---

## Work Breakdown by File Area
- `lib/services/import_service.dart`
  - validator, mapping engine, dry-run, transaction-safe commit
- `lib/services/database_service.dart`
  - service-bound upsert and strict service filters
- `lib/models/subscriber.dart`
  - service type constraints/docs update
- `lib/screens/add_subscriber_screen.dart`
  - remove `both` selector path
- `lib/screens/settings_screen.dart`
  - Import Center navigation and expanded settings options
- `lib/screens/*` (new)
  - import wizard and import history/detail screens

## Risks and Mitigations
- Risk: ambiguous headers reduce auto-detection accuracy
  - Mitigation: required mapping step with confidence + user override
- Risk: legacy `both` records break strict mode
  - Mitigation: migration/remediation dialog before enabling strict release
- Risk: rushed UI causes regression
  - Mitigation: keep wizard MVP simple, focus on blocking invalid imports

## Definition of Done
- [ ] All Phase 1 acceptance criteria pass.
- [ ] All Phase 2 acceptance criteria pass.
- [ ] At least AC11-AC13 from Phase 3 pass for first release cut.
- [ ] Manual regression on add/edit subscriber, list filtering, payments, dashboard.
- [ ] No cross-service contamination possible via import or UI.

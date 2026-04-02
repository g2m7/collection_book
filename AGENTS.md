# AGENTS.md

Guidance for coding agents working in `ledger` (Flutter app).

## Repository Overview

- Stack: Flutter (Dart 3.9), sqflite, shared_preferences, file imports (`excel`, `html`).
- App purpose: subscriber/payment ledger for TV and Internet services.
- Main directories:
  - `lib/models` data models (`Subscriber`, `Payment`, `Area`)
  - `lib/services` DB/business services (`DatabaseService`, `ImportService`, etc.)
  - `lib/screens` UI screens and workflows
  - `test` Flutter tests

## Rule Sources (Cursor/Copilot)

- `.cursorrules`: not found
- `.cursor/rules/`: not found
- `.github/copilot-instructions.md`: not found

If these files are later added, treat them as higher-priority repository rules.

## Setup Commands

- Install deps:
  - `flutter pub get`
- Check Flutter environment:
  - `flutter doctor -v`
- Clean build artifacts when needed:
  - `flutter clean && flutter pub get`

## Run / Build Commands

- Run app (default device):
  - `flutter run`
- Run on a specific device:
  - `flutter devices`
  - `flutter run -d <device_id>`
- Debug/profile/release:
  - `flutter run --debug`
  - `flutter run --profile`
  - `flutter run --release`
- Android build:
  - `flutter build apk`
  - `flutter build appbundle`
- iOS build:
  - `flutter build ios`

## Lint / Format / Analyze

- Analyze project:
  - `flutter analyze`
- Format all Dart files:
  - `dart format .`
- Optional strict check before committing:
  - `dart format --output=none --set-exit-if-changed .`
  - `flutter analyze`

## Test Commands

- Run all tests:
  - `flutter test`
- Run a single test file:
  - `flutter test test/widget_test.dart`
- Run a single test by name pattern:
  - `flutter test --plain-name "test name text"`
- Run a single test in a single file (most targeted):
  - `flutter test test/widget_test.dart --plain-name "test name text"`
- Expanded output:
  - `flutter test -r expanded`

## Code Style and Conventions

Follow `flutter_lints` via `analysis_options.yaml`.

### Imports

- Prefer import grouping order:
  1. Dart SDK imports (`dart:*`)
  2. Package imports (`package:*`)
  3. Relative app imports (`../...`)
- Keep imports minimal; remove unused imports.

### Formatting

- Run `dart format .` after edits.
- Keep lines readable; trust formatter for wrapping.
- Prefer trailing commas in multiline widget constructors.

### Types and Null Safety

- Use explicit types for public APIs and model fields.
- Use `final` by default; `var` only when type is obvious and mutable.
- Keep nullability intentional (`String?` only when truly optional).
- Avoid dynamic unless necessary (legacy areas may still contain it).

### Naming

- Types: `PascalCase` (`ImportService`, `SettingsScreen`)
- Methods/variables/fields: `lowerCamelCase`
- Private members: leading underscore (`_loadData`, `_db`)
- Constants: `lowerCamelCase` with `const` (project style), not SCREAMING_SNAKE.
- Enum values: lowerCamel (`tv`, `fiber`).

### UI Patterns

- Keep widgets small and composable; extract repeated UI into helper widgets.
- Use `const` constructors/widgets wherever possible.
- In async UI actions, check `mounted` before navigation/snackbar updates.
- Keep copy concise and action-oriented in SnackBars/dialogs.

### Service and Data Layer Patterns

- `DatabaseService` is a singleton; reuse it instead of creating new DB abstractions.
- Use parameterized SQL (`?` placeholders + args), never string-interpolate untrusted input.
- Preserve schema compatibility in migrations (`onUpgrade`) when changing tables.
- Prefer transactional safety for multi-row imports/critical writes.

### Error Handling

- Catch expected failures at boundaries (file parsing, DB writes, restore/import actions).
- Show user-facing errors via SnackBar with clear action context.
- Fail safe on import: if required data is missing/invalid, abort commit.
- Do not swallow exceptions silently; propagate or surface meaningful messages.

### Domain Constraints (Important)

- Service mode is `tv` or `fiber` (`AppModeService`).
- Treat cross-service data handling carefully in filters, imports, and upserts.
- For import work, validate required identifiers and amounts before DB writes.

## File-Specific Guidance

- `lib/services/import_service.dart`
  - Keep format detection deterministic.
  - Keep parsing logic isolated per format.
  - Avoid writing to DB during preview.
- `lib/services/database_service.dart`
  - Keep queries parameterized and migration-safe.
  - Update both query and summary paths when changing service filtering rules.
- `lib/screens/settings_screen.dart`
  - Settings actions must handle long operations with visible progress.

## Testing Guidance

- Add/adjust tests for:
  - import format detection
  - required-field validation
  - service filtering behavior
  - DB migration-sensitive logic when schema changes
- Prefer deterministic tests with small fixture inputs.

## Agent Working Agreement

- Make focused, minimal changes; avoid unrelated refactors.
- Do not edit generated Flutter platform files unless task requires it.
- Update docs when behavior or workflows change.
- Before finishing, run at least:
  - `dart format .`
  - `flutter analyze`
  - relevant `flutter test` command(s)

## Quick Pre-PR Checklist

- [ ] Code formatted
- [ ] Analyzer clean
- [ ] Tests pass (or explain gaps)
- [ ] No debug prints left behind
- [ ] User-facing errors are clear
- [ ] Import/DB changes validated against service separation rules

# Patrol end-to-end coverage

## Objective and policy

Patrol is the repository-standard end-to-end framework for implemented Flutter
user journeys. A small set of complete journeys in `patrol_test/` exercises the
real app, sqflite database, shared preferences, navigation, and Android native
harness. Unit and widget tests under `test/` remain the right layer for parsers,
migrations, service logic, and other isolated behavior.

Android test orchestration is the primary isolation mechanism: the official
`PatrolJUnitRunner` runs with `clearPackageData=true`, and Gradle uses
`ANDROIDX_TEST_ORCHESTRATOR`. Do not make journeys depend on execution order or
add sleeps. Use Patrol finders, `pumpAndSettle`, and scrolling/waiter APIs.

Normal pull-request CI installs the pinned `patrol_cli` 4.8.0, checks the Patrol
environment, builds the debug APK, and compiles the Android instrumentation APK.
It does not start a hosted emulator on every PR: GitHub-hosted Android emulators
are slow and can be flaky. The `Patrol Android emulator (opt-in)` job is
available through **Actions → CI → Run workflow** with `run_android_patrol=true`
and uses an API 34 x86_64 emulator. A successful or failed opt-in run must be
reported as evidence; neither policy claims device execution by itself.

## Architecture and commands

- `pubspec.yaml` pins `patrol: ^4.10.0` and configures the Collection Book app and
  Android package `com.sarbaa.cbk`. Patrol's default `patrol_test/` directory is
  intentional.
- `patrol_test/app_patrol.dart` calls the same async service/database/preferences
  initialization as production, then each test pumps `CollectionBookApp`. It does
  not call `ensureInitialized`, `runApp`, or override Flutter errors.
- `lib/app_keys.dart` is the shared, production-safe selector catalog. Interactive
  widgets own these stable keys; tests use labels only for meaningful visible
  outcomes where a key would not identify the state.
- Generated `**/test_bundle.dart` and `.patrol.env` are ignored.
- `DatabaseService` remains the singleton used by production and tests. Isolation
  comes from the Android orchestrator clearing app data between tests.
- `AppModeService.resetInMemoryForTesting` is a test-only notifier reset used to
  prove that SharedPreferences restores a mode during bootstrap. It deliberately
  does not change preferences or provide a production reset path.

Install and run (the pinned CLI is also a prerequisite for `bun run verify:all`):

```sh
flutter pub get
dart pub global activate patrol_cli 4.8.0
patrol doctor
patrol test
patrol test --device <device_id>
```

Local compile gate (JDK 17 is the supported Gradle toolchain):

```sh
patrol build android --debug
# Optional lower-level native assembly check:
(cd android && ./gradlew :app:assembleDebugAndroidTest)
```

Repository Flutter checks (`bun run verify:all` includes these Flutter commands,
the ordinary debug APK build, and `patrol build android --debug`):

```sh
bun run verify:all
```

The emulated CI job is a diagnostic/opt-in gate, not proof that every external
application is installed on a physical phone.

## Coverage matrix

| Current app surface | Required Patrol seam | Coverage and assertion policy | Status / remaining boundary |
| --- | --- | --- | --- |
| Clean launch and dashboard | `clean launch reaches every empty-data screen…` | Asserts dashboard selector, empty TV dashboard state, month-forward navigation, and reaches subscriber/add/payment/settings surfaces. | Passed on the Android device run. |
| Subscriber list, search/filter surfaces, add | TV and Fiber journeys | Reaches the empty list, creates records, verifies a matching subscriber search, verifies a no-result search and stable-key clear, then verifies Paid/Unpaid/All payment filters after payment. Fiber creation is hidden in TV mode and restored in Fiber mode. | Passed on the Android device run. |
| Add TV subscriber | `TV subscriber validation, edit, payment, and dashboard persistence` | Required-name/rent validation, name/VC/valid Indian phone/rent entry, real sqflite persistence, list result. | Passed on the Android device run. |
| Edit TV subscriber | Same TV journey | Opens detail, edits name, saves, and sees updated name in detail and list. | Passed on the Android device run. |
| Subscriber detail and year navigation | Same TV journey | Opens detail, sees persisted identifiers, opens payment, and has stable selectors for year navigation. | Detail and payment are implemented in Patrol; changing detail year is selector-wired but not asserted as a separate journey. |
| Record payment, adjustment/note inputs, clear-due controls | Same TV journey | Opens payment for the subscriber, saves the prefilled payment without launching an external app, and verifies the visible paid amount in detail and dashboard. | Core save is implemented; adjustment/note and clear-due helper inputs are selector-wired but not each exercised in a default journey. |
| TV/Fiber isolation and mode persistence | `Fiber data stays isolated and persisted mode survives reinitialization` | Creates Fiber data, verifies it is hidden in TV mode, restores Fiber mode, clears only the singleton's in-memory value through a test-only seam, then re-runs bootstrap so SharedPreferences must restore Fiber before the data is checked again. | Passed on the Android device run; this verifies persistence without claiming an OS process restart. |
| Month navigation | Clean launch journey | Advances the real dashboard month and verifies the next month/year label. | Passed on the Android device run. |
| Settings: mode | Clean launch and Fiber journeys | Switches to Fiber in Settings and exercises the dashboard pill and service isolation. | Passed on the Android device run. |
| Settings: receipt language/business name | Clean launch journey | Selects Hindi and saves a business name in app dialogs, then observes the updated UI. | Passed on the Android device run. |
| Settings: areas, backup, restore, reset | Clean launch journey | Creates a persisted area, creates a real app-internal database backup, asserts durable backup-timestamp state, opens the reset confirmation, and cancels it. Stable selectors also cover native share/restore entry points. | Deterministic portions passed on the Android device run. Native share/picker and area edit/delete confirmation remain separate boundaries. |
| Import wizard deterministic navigation | Clean launch journey | Selects service, start month/year, advances to file selection, and reaches empty import history. | Passed on the Android device run. |
| Import parsing/validation/dry run/commit/history/detail | Unit coverage plus native scenario below | Existing `test/` covers deterministic parser and import behavior. Full E2E requires a real spreadsheet provisioned into the Android document picker. | Pending exact scenario: place a supported `.csv`/`.xls`/`.xlsx` fixture in the emulator/device Downloads location, run `patrol test` with the opt-in import scenario, select it in the native picker, then assert validation, dry run, commit, history, and any error detail. No fake picker test is included. |
| WhatsApp receipt precondition and result | TV payment journey | A valid persisted phone is entered, payment is saved, and the detail receipt action is observed without invoking an installed app. | In-app precondition passed on the Android device run; installed-app behavior remains pending. |
| WhatsApp/browser fallback and receipt text | Existing service unit tests plus manual/physical scenario | Receipt normalization/building/fallback logic remains unit tested. | Pending physical/opt-in scenario: send a real receipt with WhatsApp installed; repeat with WhatsApp absent to verify `wa.me` browser fallback. Do not require this on hosted CI. |
| Share backup and restore picker | Settings selectors | Production interaction points are stable. | Pending physical device/filesystem scenario: create backup, open a real share target, then restore a provisioned backup file. No fake native picker test is included. |

## Android and iOS status

Android uses the official Kotlin DSL Patrol setup in
`android/app/build.gradle.kts`: `PatrolJUnitRunner`, clear-package-data argument,
`ANDROIDX_TEST_ORCHESTRATOR`, orchestrator 1.5.1, and the parameterized
`MainActivityTest.java` under the production package. The
`patrol build android --debug` command and the lower-level Android-test assembly
task both completed locally, so the Dart Patrol bundle and native harness compile.
All three default Patrol journeys subsequently passed on a wireless Pixel 8 running
Android 17 (API 37). This does not clear the separately listed native picker,
installed-app, share-target, or physical restore scenarios.

iOS Patrol integration is pending. The current Xcode app bundle is
`com.example.ledger`, not a confirmed production identifier, so no iOS bundle is
declared in `pubspec.yaml`. Before iOS execution, choose and configure the final
bundle identifier, add the Patrol RunnerUITests target/scheme and required
signing/capabilities in Xcode, and document a real simulator/device pass. Do not
treat Android setup as iOS coverage.

## Completion evidence policy

A device test is “verified” only after `patrol doctor` and the corresponding
`patrol test` command complete on a named Android device/emulator. A successful
APK build or Android-test APK assembly proves compilation only. Pending iOS,
native file selection, installed-app, browser fallback, share-target, and
physical restore checks must remain pending until performed. No deployment or
signing prerequisite is implied by this plan.

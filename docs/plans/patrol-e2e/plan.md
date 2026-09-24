# Patrol end-to-end coverage

## Objective and status policy

Patrol is the repository-standard Android end-to-end layer for implemented,
deterministic Flutter journeys. Production initialization, the singleton
`DatabaseService`, shared preferences, app navigation, and real app widgets are
used throughout. Android test orchestration (`clearPackageData=true`) isolates
each journey. Tests do not use arbitrary sleeps, fake native pickers, or fake
external applications.

Status terms in this plan are deliberately narrow:

- **Written**: deterministic assertions exist in `patrol_test/`.
- **Analyzed/formatted**: Dart formatting and static analysis pass.
- **Compiled**: the Android app and instrumentation harness build.
- **Executed**: a named Android device/emulator completed the corresponding
  Patrol command. Compilation is not execution, and CI configuration is not
  execution evidence.

The nine current journeys are written, analyzed, compiled, and executed. The full
9/9 suite passed on a Pixel 8 running Android 17 / API 37 in 3m37 through
`tool/run_patrol_android.sh`. The runner temporarily changed
`screen_off_timeout` from 30000 to 2147483647 and verified restoration back to
30000 afterward. Native picker, share, installed-app, browser, App Link, physical
restore, and iOS scenarios are not represented by fake automated tests.

## Architecture and commands

- `pubspec.yaml` pins Patrol and configures package `com.sarbaa.cbk`.
- `patrol_test/app_patrol.dart` exposes the same
  `initializeCollectionBookApp` bootstrap used by production. A test can call
  that bootstrap before deterministic database seeding, then pump
  `CollectionBookApp`; UI-created journeys use `pumpCollectionBook` directly.
- `lib/app_keys.dart` contains stable production-safe selectors. Dynamic keys
  identify area-specific cards/chips/rows and subscriber-specific month cells.
- Unit/widget tests under `test/` continue to own exhaustive parser, migration,
  receipt formatting/normalization, and analytics edge cases.
- Generated `**/test_bundle.dart` and `.patrol.env` remain ignored.
- Reinitializing a pumped app proves SharedPreferences restoration through the
  production bootstrap; it is not described as an Android OS process kill.

```sh
flutter pub get
dart pub global activate patrol_cli 4.8.0
patrol doctor
patrol test
patrol test --device <device_id>
patrol build android --debug
(cd android && ./gradlew :app:assembleDebugAndroidTest) # optional JDK 17 check
```

Repository checks:

```sh
dart format --output=none --set-exit-if-changed lib test patrol_test
flutter analyze
flutter test
git diff --check
```

Normal PR CI compiles the Patrol harness. The API 34 emulator job remains an
opt-in workflow input because hosted Android emulators are slow and flaky:

```sh
# GitHub Actions -> CI -> Run workflow
# input: run_android_patrol=true
```

## Deterministic coverage matrix

| App-owned surface | Journey and meaningful assertions | Current status |
| --- | --- | --- |
| Clean launch and dashboard | Empty-state text; production loading/bootstrap; subscribers, settings, and payment entry points | Passed in the 9/9 Pixel 8 run; the TV journey's initial state and explicit entry navigation provide this coverage |
| Dashboard KPIs, area summary, month boundaries | Seeded TV data proves outstanding/collected/pending counts, area totals, January lower boundary, December-to-January rollover, reset-to-current behavior, and area-card deep link with its area filter | Passed in the 9/9 Pixel 8 run |
| TV subscriber form | Required-name and rent failures; invalid/valid phone; area, alias, VC, rent, previous due, start month, active state; list/detail persisted outcomes | Passed in the 9/9 Pixel 8 run |
| TV subscriber edit | Name, alias, VC, phone, rent, previous due, start month, and active state are edited through the production form and observed afterward | Passed in the 9/9 Pixel 8 run |
| Fiber subscriber form and isolation | TV/Fiber selector visibility, account ID, username, common fields, complete database re-query after create/edit, seeded TV/Fiber isolation, blue/green production themes, and Fiber restoration after production reinitialization | Passed in the 9/9 Pixel 8 run |
| Search | Name/alias/VC search, no-result behavior inherited from the empty/search flow, stable clear action, restored result counts | Passed in the 9/9 Pixel 8 run |
| Payment/status filters | Seed balances are verified directly before UI interaction; all, unpaid, paid (including overpaid under the current predicate), overpaid, active, inactive, combined filters, and reset are asserted against resulting visibility/counts | Passed in the 9/9 Pixel 8 run |
| Area filter and grouping | Seeded two-area directory, North-only combined filter, grouped area headings, and restored complete result count | Passed in the 9/9 Pixel 8 run |
| Sort modes | Name ascending/descending, due high/low, and rent high/low are tapped through stable keys; selected state and filtered result count are asserted | Passed in the 9/9 Pixel 8 run |
| Detail profile, matrix, and years | Persisted profile values, previous/next year, non-current matrix-cell entry, and keyed payment month/year changes with due-projection assertions | Passed in the 9/9 Pixel 8 run |
| Payment save/edit/delete | Real database subscriber; current-due calculation; both clear-due actions; auto-note; zero/remaining/advance projection; positive and negative adjustments; save; edit existing month; cancel/confirm delete; database re-query | Passed in the 9/9 Pixel 8 run |
| Receipt precondition and error branch | Save & Send with no phone asserts the in-app saved-but-not-sent outcome and exactly one persisted payment | Passed in the 9/9 Pixel 8 run |
| Receipt settings and referral | Cycles English, Marathi, Bengali, Tamil, and Hindi; edits business name; asserts a generated six-character referral code; reboots the production bootstrap and verifies persisted settings | Passed in the 9/9 Pixel 8 run |
| Area CRUD | Add, rename, cancel/confirm delete, warning text, and transactional subscriber unassignment after area deletion | Passed in the 9/9 Pixel 8 run |
| Backup and restore | One real app-internal backup with success/timestamp state and a one-file directory assertion; restore destructive confirmation is cancelled before the native picker | Passed in the 9/9 Pixel 8 run |
| Reset | Countdown starts at 10, is advanced through the test clock, confirms after enablement, returns home, verifies empty subscriber/area tables, and verifies cleared preferences and restored in-memory defaults | Passed in the 9/9 Pixel 8 run |
| Subscriber deletion | Cancel and confirm paths; detail removal; subscriber and payment database re-query | Passed in the 9/9 Pixel 8 run |
| Import setup | TV and Fiber preselection, disabled Continue state, start month/year selection, file-selection transition, and Back behavior are exercised; native file acquisition remains external | Passed in the 9/9 Pixel 8 run |
| Import history and run details | Seeded production import-run/error rows prove partial/success summaries, added/updated/rejected/conflict/payment counts, fatal/error/warning rows, error search, and no-match state | Passed in the 9/9 Pixel 8 run |
| Import parser, mapping, dry run, commit, transaction, dedup | Exhaustive deterministic logic remains under `test/` | Unit coverage; full file-driven UI scenario pending a provisioned native file |

## Explicitly unimplemented product surfaces

The current Flutter client is hardcoded English; receipt language does not localize
app UI. `both` service mode, cloud sync/auth, and the paywall described in the
longer product brief are not implemented routes or behaviors. They are not
claimed as Patrol coverage until separately designed and implemented. The
Android theme test covers the implemented TV blue and Fiber teal palettes only.

Reset clears app-owned SQLite data, SharedPreferences, and the in-memory
singleton defaults as one coordinated operation. Preference and database recovery
is covered by deterministic service tests; the device journey verifies the
resulting clean state.

## External-only and opt-in scenarios

These require an actual device filesystem or installed application and remain
honestly pending. Add an opt-in Patrol journey or run an exact manual scenario
only when the device contract is provisioned; do not inject a fake production
launcher/picker in the default suite.

1. **Import file picker and complete import:** copy a supported
   `patrol-tv-valid.csv`, invalid/partial fixture, and Fiber fixture into the
   emulator/device Downloads location; run the import scenario on a named
   device; select each real file; assert mapping, auto-ID (when applicable),
   validation, dry-run counts, transactional commit, history summary, and error
   search. Repeat one fixture to assert upsert/conflict behavior.
2. **Restore:** create a backup, provision a second app database state, choose
   the real backup through Android's picker, confirm replacement, relaunch, and
   assert the restored records. The deterministic confirmation/cancel path is
   automated.
3. **Share backup:** tap Share Backup on a device with a known share target;
   verify the database filename and target handoff. Default CI must not depend
   on a vendor share sheet.
4. **WhatsApp/browser:** send a real receipt with WhatsApp installed, then with
   WhatsApp absent to verify the `wa.me` browser fallback and chooser. Dart
   tests cover normalization/templates; neither installed state is fakeable in
   the default harness.
5. **Referral App Link:** verify `/r/{six-character-code}` against the signed
   Android package, Play listing, and production Worker on a real device. The
   Flutter app currently has no in-app route for this URL.
6. **Lifecycle/analytics network:** exercise real app background/resume and
   Wi-Fi transport separately; deterministic queue/privacy/retry behavior stays
   in `test/`.
7. **iOS:** no Patrol iOS bundle/scheme/signing setup is claimed. Configure the
   final bundle identifier and RunnerUITests target before adding execution
   evidence.

## Completion evidence policy

A journey is **executed** only after `patrol doctor` and `patrol test` (or
`patrol test --device <device_id>`) complete on a named Android device or
emulator. Record the device/API and exact command when execution occurs. The
current 9/9 command completed on a Pixel 8 (Android 17 / API 37) in 3m37
through `tool/run_patrol_android.sh`; the timeout restoration readback confirmed
30000 after the temporary 2147483647 setting. Deployment, signing, external
application delivery, native filesystem, and iOS checks are never implied by a
passing build.

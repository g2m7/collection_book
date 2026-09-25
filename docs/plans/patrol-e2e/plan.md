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

The current tree contains **11** `patrolTest` journeys. They are written,
formatted, analyzed, compiled, and **executed 11/11 on the Mi A3** (`45fa99100e02`,
Android 13 / API 33). The current-source passing run took 6m14 (6m42.24 wall
time) through `tool/run_patrol_android.sh`, temporarily changed
`screen_off_timeout` from 30000 to 2147483647, and verified restoration to
30000 afterward. That run reported no layout overflow, no caught Flutter
exception, and no semantics-handle leak.

An immediately preceding full run of the 10-journey source (before journey 11
existed) completed **9/10**: the first journey, `dashboard KPIs, month
boundaries, and area deep link are data-driven`, completed every one of its own
assertions and then failed only Flutter's end-of-test check with `A
SemanticsHandle was active at the end of the test`
(`WidgetTester._verifySemanticsHandlesWereDisposed`). An identical-source rerun
of that same 10-journey tree completed **10/10** in 5m16, and that semantics
event did not recur in any later run. That event is a Patrol semantics-handle
leak, not an assertion failure in app behavior. It is recorded rather than
hidden; if it recurs it must be treated as a real first-journey isolation
defect. It is not evidence about the current 11-journey source.

A historical pre-localization run completed **9/9** journeys on a Pixel 8
running Android 17 / API 37 in 3m37 through `tool/run_patrol_android.sh`. That run
covered the then-current nine English journeys and temporarily changed
`screen_off_timeout` from 30000 to 2147483647, verifying restoration to 30000.
It is not evidence of a Pixel 8 pass for the modified 11-journey source tree.

Native picker, share, installed-app, browser, App Link, physical restore, and
iOS scenarios are not represented by fake automated tests.

## Architecture and commands

- `pubspec.yaml` pins Patrol and configures package `com.sarbaa.cbk`.
- `patrol_test/app_patrol.dart` exposes the same
  `initializeCollectionBookApp` bootstrap used by production. A test can call
  that bootstrap before deterministic database seeding, then pump
  `CollectionBookApp`; UI-created journeys use `pumpCollectionBook` directly.
- `lib/app_keys.dart` contains stable production-safe selectors. Dynamic keys
  identify area-specific cards/chips/rows and subscriber-specific month cells.
- Unit/widget tests under `test/` continue to own exhaustive parser, migration,
  receipt formatting/localization, and analytics edge cases.
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

Every row below is present in the current 11-journey source and passed in the
current-source Mi A3 run. This does not erase the separate historical 9/9
pre-localization evidence above.

| Current journey | Meaningful assertions | Current status |
| --- | --- | --- |
| 1. Dashboard KPIs, month boundaries, and area deep link | Seeded TV data verifies outstanding/collected/pending counts, area totals, January lower boundary, December-to-January rollover, reset-to-current behavior, and area-card deep link with its area filter | Passed in the current-source 11/11 Mi A3 run |
| 2. TV subscriber form | Required-name and rent failures; invalid/valid phone; area, alias, VC, rent, previous due, start month, active state; list/detail persisted outcomes | Passed in the current-source 11/11 Mi A3 run |
| 3. Fiber subscriber form and isolation | TV/Fiber selector visibility, account ID, username, common fields, complete database re-query after create/edit, seeded TV/Fiber isolation, blue/green production themes, and Fiber restoration after production reinitialization | Passed in the current-source 11/11 Mi A3 run |
| 4. Search, combined filters, grouping, and sorting | Name/alias/VC search and no-result behavior; all, unpaid, paid/overpaid, active, inactive, area, and combined filters; grouped headings; every name/due/rent sort; selected states and result counts | Passed in the current-source 11/11 Mi A3 run |
| 5. Payment helpers, adjustments, edit, and delete | Real database subscriber; current-due calculation; year/month navigation; both clear-due actions; auto-note; zero/remainder/advance projection; save; edit and cancel/confirm delete; database re-query | Passed in the current-source 11/11 Mi A3 run |
| 6. Full app reset, settings, areas, and backup paths | Fiber mode, Hindi app language, business name, referral code, settings restoration, area create/delete and subscriber unassignment, internal backup, restore cancellation, countdown/reset, cleared preferences, database tables, and singleton defaults | Passed in the current-source 11/11 Mi A3 run |
| 7. Subscriber deletion | Cancel and confirm paths; detail removal; subscriber and payment database re-query | Passed in the current-source 11/11 Mi A3 run |
| 8. **Localized Hindi import history** | Switches to Hindi through production settings, then verifies localized history and run-detail headings/status and absence of hardcoded `PARTIAL`; restores English before teardown | Passed in the current-source 11/11 Mi A3 run |
| 9. Import setup, persisted history, severity details, and error search | Seeded production import-run/error rows prove partial/success summaries, counts, fatal/error/warning rows, error search, and no-match state; TV/Fiber setup, disabled Continue, month/year, file-selection transition, and Back behavior; native file acquisition remains external | Passed in the current-source 11/11 Mi A3 run |
| 10. Save & Send missing-phone branch | Save & Send without a phone asserts the saved-but-not-sent outcome and exactly one persisted payment without launching an external application | Passed in the current-source 11/11 Mi A3 run |
| 11. **All five app languages render Settings, Import Wizard, Home, and Subscribers** | Cycles English, Hindi, Marathi, Bengali, and Tamil through the production Settings language selector without restarting the app; asserts `AppLanguageService` active locale plus Settings header/tile copy, lower scrolling Danger Zone and Import Center tile copy, the TV Import Wizard title/step/service copy and disabled Continue, the Home app title, hero-card labels, Record Payment label and tooltips, and the Subscribers title and empty state; returns through `AppKeys.importBack` and `find.byType(BackButton)`; restores English through the production selector with an `AppLanguageService` fallback | Passed in the current-source 11/11 Mi A3 run |
| Exhaustive import parsing/mapping and receipt behavior | Deterministic parser, required-field, service-isolation, migration, receipt formatting/localization, and analytics edge cases remain under `test/` rather than a brittle file-driven UI journey | Unit coverage; native file import execution pending |

## Implemented localization surface

The client now provides English, Hindi, Marathi, Bengali, and Tamil app
localization, live Settings selection, localized import status/diagnostic
surfaces, and receipt-template language composition. The default remains
English, and the app language drives generated WhatsApp receipt templates.
Receipt preferences retain their own independent initialization for business
name and referral code.

The Patrol Hindi journey covers one representative localized import workflow,
and the five-language journey renders four production surfaces in every
supported language on a 720x1560 display. Exhaustive catalog parity, preference
migration/cold start, unsupported-value fallback, and all five app-to-receipt
language mappings remain deterministic unit/service tests under `test/`.

That five-language journey found and now guards one real responsive defect: the
Home dues hero-card header overflowed horizontally on vernacular labels at this
device width. The header now lays its label and subscriber count out as two
expandable columns, and the journey asserts both localized strings. After each
localized Settings lower surface, Import Wizard, Home, and Subscriber List
render, the journey takes the pending Flutter exception and asserts it is
`null` with a locale-and-surface reason, so a future `RenderFlex` overflow fails
the journey deterministically instead of depending on incidental reporting.

`both` service mode, cloud sync/auth, and the paywall described in the longer
product brief are not implemented routes or behaviors. They are not claimed as
Patrol coverage until separately designed and implemented. The Android theme
test covers the implemented TV blue and Fiber teal palettes only.

Reset clears app-owned SQLite data, SharedPreferences, and the in-memory
singleton defaults as one coordinated operation. Preference and database recovery
is covered by deterministic service tests; the current Mi A3 journey verifies
the resulting clean state.

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
   local app opens Home for a valid code without retaining it; signed-build and
   deployed-Worker verification remain external.
6. **Lifecycle/analytics network:** exercise real app background/resume and
   Wi-Fi transport separately; deterministic queue/privacy/retry behavior stays
   in `test/`.
7. **Localization visual checks:** the automated five-language journey already
   renders Settings, the TV Import Wizard, Home, and Subscribers in all five
   languages on the low-resolution Mi A3 (720x1560) and asserts
   `takeException() == null` after each one, so any layout overflow fails the
   journey. A native-speaker/editorial wrapping and truncation review of all
   five languages on a named device is still required and remains pending.
8. **iOS:** no Patrol iOS bundle/scheme/signing setup is claimed. Configure the
   final bundle identifier and RunnerUITests target before adding execution
   evidence.

## Completion evidence policy

A journey is **executed** only after `patrol doctor` and `patrol test` (or
`patrol test --device <device_id>`) complete on a named Android device or
emulator. Record the device/API and exact command when execution occurs. The
current-source 11/11 run used the Mi A3 (`45fa99100e02`, Android 13 / API 33)
in 6m14 (6m42.24 wall time) through `tool/run_patrol_android.sh`; the timeout
restoration readback confirmed 30000 after the temporary 2147483647 setting. The
separate historical 9/9 pre-localization run used a Pixel 8 (Android 17 / API 37)
in 3m37.
Deployment, signing, external application delivery, native filesystem,
native-speaker localization review, and iOS checks are never implied by a
passing build.

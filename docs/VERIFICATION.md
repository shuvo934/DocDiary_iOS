# Startup/device verification — 18 October 2026 (current)

- Flutter3.29.2 / Dart3.7.2, framework c23637390482d4cf9598c3ce3f2be31aa7332daf.
- `flutter pub get`: successful with exact device_info_plus12.2.0,
  network_info_plus7.0.0 and package_info_plus8.3.1.
- `flutter analyze --no-pub --fatal-infos`: No issues found, exit0.
- `flutter test --no-pub`: all220 tests pass, exit0, Linux. Prior187 retained,
  33 new metadata/update cases. Full log: verification/startup_flutter_tests_2026-10-18.log.
- Eight installer fixtures pass: full Dart reconstruction, local UI/signing/settings
  preservation, idempotence, exact restore, formatting/CRLF, conflict rejection,
  payload checksum rejection and write-failure rollback. These are separate from
  the220 Flutter tests. Tested lock snapshot: startup_dependency_snapshot.lock.
- Native Android source, accepted dashboard code/assets, splash and login UI
  remain unchanged. No live DocDiary API or real App Store was called by tests.
- Mac iOS build, native plugin values, live loginLog persistence and published
  Store-version acceptance remain unrun here. Run the Mac commands and iPhone
  checks in STARTUP_DEVICE_UPDATE_BN.md. Linux checks do not establish them.

---

## Previous dashboard checkpoint

# Dashboard update verification — 18 October 2026

- SDK: Flutter3.29.2, framework c23637390482d4cf9598c3ce3f2be31aa7332daf,
  engine18b71d647a, Dart3.7.2. SDK tools run in CI mode to omit the cloud
  metadata bot probe.
- Actual `flutter analyze --no-pub --fatal-infos`: **No issues found**, exit0.
- Actual `flutter test --no-pub`: **187 tests passed**, exit0, on Linux.
  Includes the prior150 cases and37 new picture/camera/navigation cases.
  Full output: verification/dashboard_flutter_tests_2026-10-18.log.
- Dart formatter parsed all63 Dart sources/tests. Offline imports/assets and
  Python installer/privacy/setup checks also passed:7 update-installer fixtures,
  3 targeted media-privacy cases and6 iOS-configuration fixtures. These are
  separate from the187 Flutter tests.
- Layout, overview, meeting, line-chart, payment-format and chart-model Dart
  token streams equal the prior accepted version. Only formatting differs.
- The update installer reconstructs all63 Dart source/test token streams equal
  to this analyzed/tested source; accepted UI files are kept byte-for-byte by
  the installer. Backup/idempotence/conflict/tamper/rollback/restore checks pass.
- Native Android source is untouched. No live production API requests were
  sent by these tests.
- **Not run:** macOS CocoaPods/Xcode build, real iPhone camera/flash/settings,
  native iOS crop/HEIC handling, live picture upload, Keychain and TestFlight.
  Automated Linux tests do not establish these results.

Apply/run instructions: DASHBOARD_UPDATE_BN.md. Full behavior mapping and
remaining destination modules: DASHBOARD_COMPLETION_AUDIT.md.

---

## Earlier checkpoints (historical, before the SDK became available)

# Dashboard access/error checkpoint — 18 October 2026

The uploaded native_admin_overview.dart is the new baseline. Its `_total` and
entire `_card` rendering are byte-identical, including FontWeight.w600 for label
and value. Existing header/identity/actions/summary/tabs/menu/full-top shadow,
centered meeting, date-axis and payment formatting are retained.

Twenty new contract cases and sixteen widget cases are authored for doctor/
admin forced access, mobile flags, expiry/day warnings, status/no-information,
explicit denial acknowledgement, read-only revalidation, retry stages, stale
responses, repeated errors, full versus scoped error dialogs, initial Admin
chart failure, EXIT, logout and large text. Existing error/denial/picture cases
are updated rather than removed. The expected suite is150 cases; it has not run.

**Flutter/Dart SDK and Xcode are unavailable here.** Official SDK download was
unavailable in this environment. No new Flutter analyzer/test/build pass or
pixel-perfect claim is made. Independent Dart grammar/source checks, native
mapping, font validation and installer fixtures are separate local evidence.
Local evidence:52 Dart files pass source/import/assets and independent grammar
checks; Lato-Bold tables/weight700 and native palette are verified. Eight
installer fixtures pass (UI/settings preservation, idempotence, later local UI,
existing font merge, payload/integration rejection, rollback, exact restore and
Dart interpolation lexing). These are not Flutter tests. Required flow-control
braces are also normalized without changing branch conditions/actions.

The most recent supplied Mac log remains analyzer clean /113 passed /1 legend
overflow before its correction, not a result for this expanded checkpoint.

Run `flutter pub get` and `bash tool/verify.sh --ios-simulator` on Mac. Use the
offline access scenarios to inspect the dialogs, then verify live backend and
real iPhone/Keychain/lifecycle behavior. See DASHBOARD_ACCESS_PATCH_BN.md and
DASHBOARD_ACCESS_PARITY.md for exact actions, adaptations and remaining scope.

---

# Chart date/payment formatting correction — 17 October 2026

The supplied 18:07 iPhone simulator screenshot shows monthly X dates crossing
the baseline and a payment total of 628,900. The user reports that the dashboard
is almost complete and requests date spacing and the native payment pattern.
This is UI feedback, not a new analyzer/test result.

- Monthly dates now use the top of the full rotated rectangle as their anchor,
  4px below the X axis, including the single-point branch. Yearly dates stay flat.
- Summary/payment totals share the native ICU lakh/crore grouping; no financial
  value or HALF_EVEN rounding logic changes. Appointment totals use raw integer
  text as in DocDashboard.java. Marker grouping and point abbreviations remain
  separate, matching their distinct native formatter calls.
- Android14 java.text.DecimalFormat initPattern delegates to the ICU compatible
  factory, which changes parsing mode only. The earlier desktop-Java grouping
  assumption was incorrect. ICU74 formatted twelve sample/signed/large/rounding
  values with the literal pattern; expected regression strings agree.
- Existing monetary contract tests are expanded; no test is removed. The last
  supplied Mac log is still analyzer clean / 113 passed / 1 legend-overflow
  failure before the legend fix. No corrected full-suite pass is claimed.
- Local source consistency, independent Dart grammar and patch installer checks
  are distinct from Flutter execution. Flutter/Dart/Xcode are unavailable here;
  run `bash tool/verify.sh --ios-simulator` and compare with native on Mac.

---

# Admin OVERVIEW chart checkpoint — 17 October 2026

Latest supplied Mac result (Flutter 3.29.2 / Dart 3.7.2): analyzer reports
**No issues found**, 113 tests pass and one test fails: `small screens and large
text render without overflow`. Legend labels overflow their Rows by 3/43/63px
at the first 320px / 2x text-scale fixture. Verification stops before the
simulator build.

The correction constrains each legend label with a loose Flexible inside its
Row. Labels retain their normal font size and can wrap at available width;
the outer Wrap still places whole legend entries. The existing failing test
is retained unchanged as the regression check. Source/import/assets and Dart
grammar checks pass locally; the corrected Flutter suite and simulator build
must be rerun on Mac. No corrected Flutter pass is claimed here.

Repository/model/widget coverage is authored for all twelve chart routes,
role/user filtering, encoded/null/invalid data, date boundaries/leap years,
whole-number rounding, independent dates, type resets, retry, stale requests,
summary-tab retention, lifecycle refresh, owned-dialog logout, tap markers, zoom and large text.

**Flutter/Dart SDK and Xcode are unavailable here.** The Mac result above is
supplied by the user. Corrected tests, iOS build and actual Flutter screenshots
are pending. Source grammar is not a type check or proof of runtime/visual
parity. User acceptance of the preceding UI is not a full test-suite result.

Local evidence:

- Source/import/assets check and independent Dart grammar cover 47 Dart files.
- The uploaded NativeMeetingPanel is byte-identical; all non-integration layout
  classes retain elevation2, typography, cards, menus and the full-top painter.
- 37 pre-existing Dart/YAML files are unchanged; no dependency changes.
- MPAndroidChart formatter examples were checked with Java17 against its native
  DecimalFormat algorithm; tiny fractions intentionally guard its exponent bug.
- Original marker PNG and the arrow/refresh vector source are retained.
- Seven backed-up installer fixtures pass: preservation, repeat application,
  later local edits, unsupported integration/project/payload rejection, mid-write
  rollback and exact restore. All three surgical merges match the packaged Dart
  source tokens and parse with the independent grammar checker.

Mac commands and offline Admin preview: ADMIN_CHARTS_PATCH_BN.md.

---

# Doctor countdown checkpoint — 17 October 2026

Implementation and 21 new cases (8 unit/contract, 13 widget) are authored.
The cases cover timestamp validation, intervals and progress clamps, missing
last_sc anchors across tab changes, native labels/format branches, right fill,
expiry/Today delay, lifecycle/pending-request behavior, error recovery, access
checks, logout/switch/disposal, no meeting and small/large-text layouts.

**Flutter/Dart SDK and Xcode are unavailable here.** No new flutter analyze,
flutter test, iOS build or Flutter-rendered screenshot result is claimed.
Run `bash tool/verify.sh --ios-simulator` on the user's Mac and compare the
countdown with native. See COUNTDOWN_PATCH_BN.md for the 20-second offline demo.

Local evidence:

- Source consistency/import/assets/delimiters: 39 Dart files, no reported issues.
- Independent tree-sitter Dart grammar: 39 files parse without syntax errors;
  this does not validate types or Flutter widget APIs.
- Latest uploaded full-top shadow, identity, header, tabs, summary-card and menu
  class implementations are byte-identical outside the meeting integration.
- Approved app/auth/splash source checksums retained.
- AOSP Roboto 2.138 regular/bold parse with expected weights/numeric/unit glyphs;
  Apache NOTICE/source hashes bundled; font declarations remain valid YAML.
- Countdown installer: seven local fixtures pass, covering preservation,
  repeat application, already-integrated custom edits, unsupported-layout/project/
  payload rejection, simulated mid-write rollback, and exact backup restoration.

Earlier dated sections below describe earlier checkpoints, not a test result
for this version. Native day-number-only date comparison, invalid timestamp
crashes and unbounded progress/division are intentionally guarded; UI/behavior
scope and remaining differences are recorded in DASHBOARD_NATIVE_REFERENCE.md.

---

# Dashboard corner finish — 17 October 2026

The user confirmed the previous selected-tab and zero-elevation changes work.
A follow-up cosmetic update adds a white backing behind the rounded bottom
navigation and a CustomPainter that draws only the surface's two top corner arcs.
Scaffold clouds and user-adjusted typography/padding/card height are retained.
Source preservation and Dart grammar checks pass. Flutter runtime/iOS visual
confirmation of the new corner finish is pending; no new full-suite pass claimed.

---

# Dashboard UI refinement — 17 October 2026

The user accepts the current dashboard UI and supplied a simulator screenshot
and an edited native_dashboard_layout(1).dart. The exact uploaded file is the
new baseline. Its content inset, 75sdp appointment height and entire identity
implementation are preserved. Only the white tab-bottom overlay and the outer
surface elevation are changed. A byte-level expected-diff check and independent
Dart grammar/source checks pass; Flutter runtime/visual confirmation remains
pending on the user's Mac. No additional tests were added for these two cosmetic
edits, and no new analyzer/test/iOS build result has been provided.

---

# Dashboard step 1 — 17 October 2026

Implementation is ready for Mac verification; UI acceptance is pending.
The user approved selection UI and considers its logic satisfactory. The last
provided test log still records 47 passed / 6 stopped at the selection Semantics
assertion; the required flag was corrected before this dashboard patch. No
subsequent full Flutter test result has been supplied.

This checkpoint adds 14 Flutter tests (9 widget cases and 5 display/photo cases).
The expected suite has 67 cases, but it has **not been executed here**. Do not
interpret source checks or the number of authored cases as passing tests.

Local completed checks:

- Source consistency across 35 Dart files: imports/assets/delimiters pass.
- Independent tree-sitter Dart grammar parsing of the 35 files: no syntax errors.
- Original PNG copies compare byte-for-byte; vector paths come directly from XML.
- New Archivo and original Baloo binaries parse; numeric glyphs and licences checked.
- Four installer fixtures pass: approved/local code and pubspec preservation plus
  repeat application; invalid-project rejection; altered-payload rejection; rollback
  after a simulated write failure. Backup contains exact original bytes.
- Approved splash/login/selection/auth/app integration files are unchanged.
  DashboardRepository.load remains byte-identical to the previous package.

Required on the user's Mac:

```bash
flutter pub get
bash tool/verify.sh
flutter build ios --simulator --debug --no-codesign
```

Then compare Doctor and Admin screenshots with native Android using the same
role, data, date tab and similar screen dimensions. Running countdown, chart
logic and destination screens remain future checkpoints. See DASHBOARD_PATCH_BN.md.
Flutter/Dart/Xcode are unavailable in this environment; no Flutter analyzer,
Flutter tests, iOS build or actual Flutter screenshot was produced here.

---

# Verification record

## Selection Semantics correction — 17 October 2026

The latest user-supplied Mac log reports a clean analyzer and 47 passed / 6
failed tests. Each selection test stopped at the same render assertion before
its interaction checks: `explicitChildNodes must be set to true if scopes route
is true`. The selection dialog now sets `explicitChildNodes: true` beside
`scopesRoute: true`. This is the only Dart source change in the correction.

The 47 preceding tests passed in that run. The six corrected selection tests
and the full 53-test suite still need to be rerun on Mac; they have not run in
this SDK-less environment. Source consistency and archive integrity checks pass.

## Selection dialog change — 17 October 2026

The user approved the login UI before proceeding to multi-center/multi-user
selection. The change follows both native dialog XMLs, row XMLs, adapters and
border drawables. The original hospital asset is copied unchanged. The bundled
Open Sans font's wght axis was checked to support 700, used for the native bold
rows. AppCompat's official source confirmed the minimum width fractions and
2dp corner default; the official 1.7.1 AAR confirmed API21+ background insets of
16dp. The window appearance still needs comparison with the actual Android app.

Six widget tests were added (53 total authored), covering chained selection,
single-center/direct-account cases, cancellation/back/outside tap, long lists
and current-account indicators. The approved login layout, startup/splash and
authentication controller/repositories are unchanged. The patch installer keeps
the existing LoginScreen code and changes only its selection component/export.

Offline checks cover imports/assets/delimiters, native asset byte equality,
source preservation, installer fixture/backup and archive integrity. Flutter,
Dart and Xcode are unavailable here; an SDK download probe timed out. New
Flutter analyzer/tests, actual UI rendering and iOS build have **not run here**.
Use `docs/SELECTION_PATCH_BN.md` for Mac verification. No new all-tests-passed or
pixel-parity result is claimed.

## Login TextField correction — 17 October 2026

The user's Mac log reports a clean analyzer and 38 passed / 9 failed tests.
The repeated originating assertion was `inherit false style must supply fontSize
and textBaseline` for the Mobile and Password TextFields. Their shared `_text`
factory supplied fontSize but omitted textBaseline. It now explicitly supplies
`TextBaseline.alphabetic`, retaining the native fonts, sizes and non-inheriting
style. The log's other missing-widget/multiple-exception messages occurred after
these construction failures; no separate cause was established from that run.

The corrected source passes the offline consistency check. Flutter tests have
not been rerun here because the SDK is unavailable. Rerun `bash tool/verify.sh`
on Mac to establish the new result; 47 passed is not yet claimed.

## Login change — 17 October 2026

The user approved the splash appearance before proceeding to login. The login
change uses the original PNG, native XML dimensions, button gradient and the
Poppins, Patua One, Ubuntu and Open Sans font families. All seven bundled font
binaries were parsed successfully with fontTools; upstream licences are included.
Font declarations were validated as YAML. Pubspec merge checks cover new setup,
existing/quoted family names, preservation of custom fonts and peer settings,
idempotence, and a strict failed-download case that leaves pubspec unchanged.

The native loading state retains the first white background layer in the XML;
only the form is hidden while the central primary-colour indicator is shown.

Three login widget tests were added (47 total authored); the existing keyboard
test also checks the header stays fixed and the button scrolls above the keyboard.
The source/import/asset consistency check passes for 26 Dart files. Patch fixture
checks cover selective copy, backup, font merge, repeat application and rejection
of a different/incomplete project. The accepted splash source and authentication
controller/repositories remain unchanged.

**No new Flutter analyzer/tests, iOS build or rendered UI comparison ran here:**
the creation environment has no Flutter/Dart SDK or Xcode. User-reported results
from the baseline do not establish that this new code has passed those checks.
Use `docs/LOGIN_PATCH_BN.md` for Mac verification and the visual preview.

## Splash change — 17 October 2026

The user reported that the preceding baseline passed `flutter analyze`, all 41
tests, an iOS simulator build and live API use on their Mac. Those results predate
this splash change. New startup routing/timing coverage adds three widget tests.

The creation environment still has no Flutter/Dart SDK or Xcode. The new Flutter
tests, analyzer, iOS build, fullscreen behaviour and Android/iOS visual parity have
**not run here**. The source/import/asset consistency check passes for 24 Dart
files. The original three splash PNGs are byte-identical to the native assets.
The focused patch installer was checked against an isolated existing-project
fixture, including backup preservation and unchanged project configuration.

Use `docs/SPLASH_PATCH_BN.md` for Mac verification and the screenshot preview.

## Original checkpoint — 15 October 2026

Date: **15 October 2026**. Creation environment: Linux, without Flutter/Dart SDK or Xcode.
Flutter SDK retrieval was unavailable in this environment. No iOS execution is claimed.

| Check | Actual result |
| --- | --- |
| Native baseline references | SHA-256 checks passed for all five referenced native source/layout files; unchanged |
| Project source consistency | Passed for 21 Dart implementation/test files: local imports, image assets and balanced delimiters |
| Python iOS configuration tests | **6 passed**, using a minimal isolated Xcode-project fixture |
| Python script parsing | Passed with Python byte-code compilation |
| Shell script parsing | Passed with `bash -n` |
| Dart/Flutter test cases authored | **41**; synthetic credentials/data; fake backend and session store |
| Dart format/parser | **Not run** — SDK unavailable |
| `flutter pub get` | **Not run** — SDK unavailable; no lockfile fabricated |
| `flutter analyze` | **Not run** — SDK unavailable |
| `flutter test` | **Not run** — SDK unavailable |
| Actual generated iOS Xcode runner | **Not generated here** — bootstrap creates it using the Mac's installed Flutter SDK |
| iOS simulator compilation | **Not run** |
| Physical iPhone / Keychain / API tests | **Not run** |
| Screenshot/pixel parity | **Not verified** |
| Real backend login or mutations | **None performed** |

The custom offline checker is deliberately limited. It cannot validate Dart types,
Flutter widget APIs, dependency compatibility, platform plugins, Xcode signing or iOS behaviour.
The six Python tests validate the setup transformation, not an actual Xcode build.

The package is a first implementation checkpoint. Resolve Mac analyzer/test/build results
and complete the acceptance checklist before considering this milestone accepted.


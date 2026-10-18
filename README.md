# Startup/device update — 18 October 2026 (current)

Splash now checks compatible public App Store versions before session restore;
loginLog collects actual iOS device/hostname/OS/IP metadata. Native failure and
Retry/Cancel behavior is retained with App Store/Home-gesture iOS adaptations.
Flutter3.29.2/Dart3.7.2 analyzer is clean; all220 tests pass on Linux. Mac/iPhone
plugin, Store and live audit acceptance remains. Accepted dashboard UI is kept.

Apply/configuration/preview: `docs/STARTUP_DEVICE_UPDATE_BN.md`.
Audit: `docs/STARTUP_DEVICE_AUDIT.md`. Use the focused Startup Device patch on
an existing Mac project; do not replace the whole project or regenerate Runner.

---

# Latest dashboard update — 18 October 2026

The supplied dashboard file is the current integration baseline. Dashboard
Admin picture/camera/crop/upload, the Retry lint fix, iOS review hook and native
destination/return wiring are implemented. Flutter3.29.2/Dart3.7.2 analyzer clean;
187 tests pass on Linux. Mac/iPhone plugin/build/live acceptance remains.

See `docs/DASHBOARD_UPDATE_BN.md` and `docs/DASHBOARD_COMPLETION_AUDIT.md`.
Existing accepted UI, lighter overview totals, elevations, padding, centered
meeting and full-top shadow are retained. Android source is untouched.

---

# DocDiary Flutter iOS — Milestone 1

## Dashboard access/error audit — 18 October 2026

The latest uploaded overview and its lighter w600 totals are retained. Native
forced logout, mobile access, inactive doctor/admin availability, inclusive
expiry, once-per-entry0–3-day warning and full-load versus tab/chart dialogs now
have explicit routing and actions. Full errors use the original WARNING! layout
and Lato/Poppins styling. Session clearing waits for denial OK; obsolete routes
and responses are invalidated. See [apply/preview instructions](docs/DASHBOARD_ACCESS_PATCH_BN.md)
and [the parity audit/remaining scope](docs/DASHBOARD_ACCESS_PARITY.md).

The focused installer backs up changes and merges the local overview UI,
layout, app routing and font declarations. No new package dependency or iOS
configuration change is needed. Twenty new contract cases and sixteen widget
cases are authored; corrected Flutter analyzer/tests, Mac/iPhone visual and
lifecycle checks remain pending. iOS EXIT gives Home-gesture instructions;
programmatic app termination is not used.

## Chart date spacing and payment format correction — 17 October 2026

Monthly X-axis dates now align their full rotated bounds below the axis with
a 4px gap; yearly labels retain their horizontal alignment. Payment summary
and chart totals use the Android ICU pattern `###,##,##,###` (6,28,900), while
native appointment totals remain ungrouped and marker tooltips keep their
separate three-digit grouping. The previous legend wrapping fix is retained.
The existing monetary contract cases are expanded for lakh/crore, signed and
large exact values. Corrected Flutter checks/build and screenshot comparison
remain pending on Mac. Apply the updated Admin chart patch as described below.

## Admin OVERVIEW charts checkpoint — 17 October 2026

Admin Payment/Appointment overview, independent date pickers, Monthly/Yearly,
permission-gated All/Offline/Online, rounded totals, markers, axis zoom and
per-chart retry are implemented from the native source. The latest uploaded
button elevation2, centered meeting content, full-top shadow and outer scroll
padding are the current UI baseline. The installer merges only the integration
sections of the local dashboard/screen/test fixture files and backs up changes.

Apply [the Admin chart patch](docs/ADMIN_CHARTS_PATCH_BN.md) to the existing
countdown project. No new dependencies are needed. For the offline fixture:
`flutter run -t lib/main_dashboard_preview.dart --dart-define=DASHBOARD_PREVIEW_ROLE=admin`.
Scroll below the summary to OVERVIEW. Use main.dart for real backend data.

Local source/grammar and installer checks are distinct from Flutter execution.
The supplied Mac run reports a clean analyzer and 113 passing tests, with one
small-screen/large-text test failing on legend overflow. Legend labels now use
Flexible to wrap within available width; the existing regression test is
retained. The corrected test suite, simulator build and native/device visual
parity remain pending on Mac. See [the native chart reference](docs/ADMIN_CHARTS_NATIVE_REFERENCE.md).


## Doctor countdown checkpoint — 17 October 2026

The user's latest full-top-edge shadow, content padding, identity typography and
75sdp appointment card are retained. Doctor Next Meeting now has native local
last_sc/next_sc arithmetic, h/m/s groups, right-anchored progress, a 3-second
expiry refresh returning to Today, and pause/resume handling. Read-only refreshes
still enforce access and never add login POSTs. A focused installer backs up
changes and merges the meeting integration into the user's existing layout.

Follow [the countdown instructions](docs/COUNTDOWN_PATCH_BN.md). A short offline
preview is available with `--dart-define=DASHBOARD_PREVIEW_TIMER_SECONDS=20`.
Eight unit/contract and thirteen widget cases are authored for this checkpoint;
Flutter tests, analyzer, iOS build and visual acceptance are pending on Mac.
Local source/grammar checks do not establish runtime correctness.

Admin OVERVIEW charts/filters are included in the later checkpoint above.


## Dashboard step 1 patch — 17 October 2026

Native-derived Doctor/Admin header, identity, summary cards, four date tabs,
permission-based actions and unlabeled bottom icons are ready for Mac review.
Existing summary API/auth logic is retained; native photo GETs are added.
Offline role previews and a focused backup installer are supplied. Follow
[the dashboard instructions](docs/DASHBOARD_PATCH_BN.md).

Camera upload and destination screens remain future checkpoints.
Countdown implementation is included in the later checkpoint above. This is not full dashboard acceptance. Local grammar,
source/asset and installer checks passed; Flutter analyze/tests/iOS builds have
not run here. The expanded suite must be verified on Mac before a full suite pass is claimed.

This is a separate iOS migration project based on DocDiary Android **1.3.9.5 (27)**.
It does not replace, rebuild, or modify the Android project or its Play Store release.

**Status: partial migration; native UI parity is not yet accepted.**
This package is not a complete conversion and is not ready for App Store submission.

17 October update: the user reports the previous baseline passed analyzer, all
41 tests, simulator build and live API checks on Mac, and has approved the splash
and login UI. The center/account dialogs now follow the native selection XML,
row adapters, hospital asset, typography, borders and close behaviour. The new
selection changes require Mac verification. Existing project users should apply
`DocDiary_Selection_Patch.zip` and follow `docs/SELECTION_PATCH_BN.md`.

The user's initial selection verification passed analyzer and 47 existing tests;
all six selection tests stopped at a Semantics assertion. The dialog now sets
the required `explicitChildNodes: true` with `scopesRoute: true`. A new full test
run after this correction is pending.

The first login patch produced a runtime TextField assertion on Flutter 3.29.2
despite a clean analyzer. The shared text style now supplies the required
alphabetic textBaseline. The reported 38 passed / 9 failed test run predates
this correction; the corrected tests must be rerun on Mac.

## Start on your Mac

Open a terminal in this extracted folder, then run:

```bash
bash tool/bootstrap_ios.sh
```

The setup requires Flutter/Dart in PATH, Python 3, Xcode and its command-line tools.
It uses your installed Flutter SDK to generate the actual `ios/` runner in a temporary
project, copies only the runner and metadata, and leaves this Dart implementation intact.
It configures Keychain, networking, deployment settings and the original app icon.
It also tries to download the original login font families and their licences,
resolves dependencies, formats/parses Dart, runs `flutter analyze`, then `flutter test`.
It does not publish or upload an app, and the automated tests use synthetic fixtures.

After those checks pass:

```bash
flutter devices
flutter build ios --simulator --debug --no-codesign
```

For a physical iPhone, open `ios/Runner.xcworkspace` in Xcode, select **Runner →
Signing & Capabilities → Team**, choose your development team, then run:

```bash
flutter run -d YOUR_IPHONE_DEVICE_ID
```

`com.techterrain.docdiary.ios` is a provisional bundle ID; change `BUNDLE_ID` in
`tool/configure_ios.py` to your intended Apple identifier, then rerun setup.
The minimum iOS version is provisionally **15.0**. Reassess it against your target users
before final release. Keep the `pubspec.lock` generated by `flutter pub get` with this project.

## Included implementation

- Native MainActivity splash assets, gradient and fullscreen layout; minimum one-second startup display.
- Original native login artwork and colour palette; responsive scrolling and keyboard handling.
- Native public server-directory discovery and the same five fallback API base addresses.
- `is_available` branches `0`, `1`, `3`, `4`, `5`, including encoded or direct JSON arrays.
- Centre selection and doctor/admin/mixed account selection.
- Native role-specific first-login/forced-logout reset POST and custom headers.
- Doctor/admin profile loading, mobile-access checks, expiry initialization/checks and login audit POST.
- Secure Keychain session persistence, Remember Me, cold restoration, logout and account switching.
- Dashboard entry: correct identity/centre, doctor schedule/appointment summaries, next meeting details,
  admin appointment/payment summaries and date-period selection.
- Revalidation on dashboard refresh/app resume; forced logout blocks access.
- Expanded Dart/Flutter cases use synthetic data and fake transport/storage; new cases still require a Mac run.

## Explicitly pending

- Analyzer, tests and simulator verification of the current dashboard checkpoints on Mac.
- Signing and real iPhone API/Keychain/lifecycle tests.
- Pixel comparison against Android screenshots and confirmation of downloaded font rendering.
- Dashboard device/visual acceptance, profile camera/edit and navigation destination screens.
- Every remaining appointment, patient, prescription, payment, report, HR and Accounts screen.
- Early camera/crop and multipage prescription PDF platform trials.
- App Store metadata, final networking/privacy review, TestFlight and release acceptance.

No fake totals, fake patients or fake destinations are supplied in the live app.
The absent modules are recorded in `docs/screen_inventory.json` and `docs/MIGRATION_STATUS.md`.

## Backend behaviour during manual testing

**Do not assume login is read-only.** Like the Android implementation, a real login
can reset a forced-logout flag, initialize an expiry date, and insert a login audit log.
Use a test centre/account for first verification where available. The creation environment
did not contact those APIs, change any backend, or log in with production credentials.

Default Debug iOS configuration permits the native HTTP servers for development.
Profile/Release use a separate, strict networking plist. Current HTTP-only deployments
need a verified HTTPS or deliberately scoped iOS networking strategy before release.
The legacy login contract puts credentials in query parameters; it is preserved for
compatibility and never logged by this Flutter implementation. It is not silently replaced
with a different authentication API.

## Verification records

Read `docs/VERIFICATION.md` for what actually ran in the creation environment.
Do not interpret a source delimiter check or authored test file as a passed Flutter test.

## References used

- https://docs.flutter.dev/deployment/ios
- https://docs.flutter.dev/platform-integration/ios/setup
- https://pub.dev/packages/flutter_secure_storage/versions/10.0.0
- https://pub.dev/packages/url_launcher/versions/6.3.2


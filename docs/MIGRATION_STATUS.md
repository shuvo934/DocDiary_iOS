# Migration status — 18 October 2026

Baseline: supplied `DocDiary.zip`, Android version 1.3.9.5 (27). Its SHA-256 and the
reference source checksums are recorded in `native_baseline.json`.

Status vocabulary:

- **Drafted**: Dart implementation exists; Flutter compilation/device acceptance still pending.
- **Partial**: only the listed subset exists.
- **Pending**: implementation has not started.
- **Accepted UI**: the user approved that screen's appearance; this does not establish full module/device acceptance.
- **Accepted**: reserved for a verified build plus all agreed device/behaviour checks.

| Native area | Current implementation | Status |
| --- | --- | --- |
| Splash UI | Original MainActivity PNG layers/gradient/fullscreen; user approved appearance on 17 October | Accepted UI |
| Startup routing/update | Public App Store check before restore; compatible marketing versions, Retry/Cancel and 1000ms splash; Linux coverage passes, Mac/iPhone acceptance pending | Implemented — device acceptance pending |
| Login UI | Native DocLogin form, typography, gradient button, loading/contact/keyboard states; user approved appearance | Accepted UI |
| Login authentication | Server discovery, native response variants, validation and login flow; full device acceptance pending | Drafted |
| Centre/account selection | User approved UI on 17 October; native header/rows/close behavior; six corrected tests still need a supplied rerun result | Accepted UI |
| Session/access | Native flag resets, expiry/access checks, real device/IP/OS login logs, secure persistence, logout/switch | Implemented subset — live device acceptance pending |
| Dashboard access/dialog audit | Native forced/mobile/status/expiry dialogs, inclusive0–3-day warning, full error-handler/scoped Retry, owned routes and explicit acknowledgement | Drafted — Mac/iPhone verification pending; iOS Exit adapted |
| Dashboard | Native-derived header/identity, role/permission buttons and icon menus, 4 date tabs, doctor/admin summary UI; existing summary API and native photo GETs | Partial — summary UI accepted; latest user full-top shadow retained |
| Doctor Next Meeting countdown | Native interval/units/right-anchored progress; 3-second Today refresh; lifecycle and pending-request guards | Drafted — Mac verification pending |
| Admin OVERVIEW charts | Native endpoints, independent dates, Monthly/Yearly, allowed type filters, cubic plots, totals, tap markers, zoom and retry | Drafted — Mac verification pending |
| Dashboard destination screens | Native target/permission mapping and owned-route return refresh implemented; Profile implemented; remaining destinations show availability notice | Pending destination modules |
| Admin Dashboard photo/camera/crop/upload/retry | Implemented; all relevant automated cases pass; actual iOS plugin build/camera/upload acceptance pending | Drafted |
| iOS review integration | Optional StoreKit request after later full success; debug disabled and bounded once per entry | Drafted |
| Doctor Profile main/data/photo/video | Native-derived UI, getDocProfile/updateImage, lifecycle/error/retry and dashboard navigation | Implemented checkpoint — Mac/iPhone acceptance pending |
| Doctor Profile Update Address / Change Password | Entry buttons present; editing/validation/write/session flows next | Pending next checkpoint |
| Appointment schedules/unit/all/admin changes | Not implemented | Pending |
| Patient search/history/health progress | Not implemented | Pending |
| Old prescription workflows | Not implemented | Pending |
| Dynamic prescription/vitals/history/PDF/print/share | Not implemented | Pending |
| Payments/service modifications | Not implemented | Pending |
| Reports/PDF viewing | Not implemented | Pending |
| HR, Accounts, approvals and analytics | Not implemented | Pending |
| Camera and PDF iOS feasibility trials | Not performed | Pending |
| TestFlight/App Store preparation | Not started | Pending |

## Current startup/device checkpoint

The user considers dashboard-owned work complete; destination screen modules
remain separate. Splash update and real loginLog metadata now have33 additional
automated cases (220 total passing). Read STARTUP_DEVICE_UPDATE_BN.md for iOS
adaptations, configuration and Mac/iPhone acceptance. Existing chart/UI changes
and native Android source are untouched. No complete app conversion or App Store
release acceptance is claimed.

## Current Profile checkpoint

The user selected Doc Profile before Appointment. Main UI/API/photo/video and
Dashboard entry/return are implemented, with30 new automated cases (250 total).
Next work: native Update Address, then Change Password. See PROFILE_PATCH_BN.md
and PROFILE_NATIVE_AUDIT.md. Existing accepted dashboard rendering, startup and
login implementation remain unchanged.

## Earlier dashboard checkpoint

Dashboard-owned behavior is implemented, including the uploaded dashboard's
Retry callback lint correction, native Admin chooser/custom camera/free crop/
binary picture upload/manual Retry-Cancel, StoreKit review and destination
return refresh. Native Android files remain unchanged. UI/chart/format tokens
match the prior approved files, including lighter totals and local layout edits.

Flutter3.29.2/Dart3.7.2 analyzer is clean and all187 tests pass on Linux. This
now executes the previous150 authored cases and37 new cases. It supersedes the
old113-pass/legend-overflow report and earlier 'SDK unavailable' checkpoints.

Run the update installer and Mac verify command in DASHBOARD_UPDATE_BN.md, then
check native camera, permissions, crop/HEIC and live image persistence on iPhone.
These native plugin/device checks cannot be established by the Linux suite.
Use DASHBOARD_COMPLETION_AUDIT.md for exact scope and intentional iOS differences.

Doctor Appointment schedule/list and its filters/details follow the Profile module. Profile address/password, patient/prescription/payment/
reports/HR/accounts destination workflows and PDF printing remain separate
migration modules. No full app/production-release completion is claimed.

## Deliberate migration decisions to validate

- Keychain replaces Android SharedPreferences for credentials/session data.
- The same backend routes/parameters/custom headers are retained; inputs are correctly URI-encoded.
- Unsupported roles and malformed account identifiers are rejected rather than treated as admin.
- A failure at the last discovery server does not discard earlier valid centres.
- Write POSTs are not automatically retried, so a connection failure requires an explicit user retry.
- iOS update/review/system dialogs will follow iOS facilities; Google Play APIs are not ported.
- Native login font binaries and licences are now bundled. Android's source used
  downloadable-font XML; actual iOS text rendering still needs screenshot comparison.
- Native Current Week explicitly starts **Saturday** and ends **Friday**.
- Native doctor “COMPLETED” is based on elapsed schedule time, not clinical completion; that meaning is preserved.
- The iOS deployment target and bundle ID are provisional; review before release.


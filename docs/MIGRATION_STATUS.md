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
| Startup routing | Keychain restoration and minimum 1000ms splash; full device/lifecycle acceptance remains pending | Drafted |
| Login UI | Native DocLogin form, typography, gradient button, loading/contact/keyboard states; user approved appearance | Accepted UI |
| Login authentication | Server discovery, native response variants, validation and login flow; full device acceptance pending | Drafted |
| Centre/account selection | User approved UI on 17 October; native header/rows/close behavior; six corrected tests still need a supplied rerun result | Accepted UI |
| Session/access | Native flag resets, expiry/access checks, login logs, secure persistence, logout/switch | Drafted |
| Dashboard access/dialog audit | Native forced/mobile/status/expiry dialogs, inclusive0–3-day warning, full error-handler/scoped Retry, owned routes and explicit acknowledgement | Drafted — Mac/iPhone verification pending; iOS Exit adapted |
| Dashboard | Native-derived header/identity, role/permission buttons and icon menus, 4 date tabs, doctor/admin summary UI; existing summary API and native photo GETs | Partial — summary UI accepted; latest user full-top shadow retained |
| Doctor Next Meeting countdown | Native interval/units/right-anchored progress; 3-second Today refresh; lifecycle and pending-request guards | Drafted — Mac verification pending |
| Admin OVERVIEW charts | Native endpoints, independent dates, Monthly/Yearly, allowed type filters, cubic plots, totals, tap markers, zoom and retry | Drafted — Mac verification pending |
| Dashboard destination screens | Pictures read-only; menu destinations show a development availability notice | Pending / partial |
| Profile edit/camera/crop | Not implemented | Pending |
| Appointment schedules/unit/all/admin changes | Not implemented | Pending |
| Patient search/history/health progress | Not implemented | Pending |
| Old prescription workflows | Not implemented | Pending |
| Dynamic prescription/vitals/history/PDF/print/share | Not implemented | Pending |
| Payments/service modifications | Not implemented | Pending |
| Reports/PDF viewing | Not implemented | Pending |
| HR, Accounts, approvals and analytics | Not implemented | Pending |
| Camera and PDF iOS feasibility trials | Not performed | Pending |
| TestFlight/App Store preparation | Not started | Pending |

## Next checkpoint

The latest uploaded overview is the UI baseline, including its lighter totals.
The access/error audit corrects the missing native dialogs and warning/action
flows. The focused access patch requires Mac verification before proceeding.
It includes36 authored regression cases; no corrected full-suite/build result
has yet been supplied. See DASHBOARD_ACCESS_PARITY.md for behavior mapping,
remaining native methods and intentional iOS/defensive differences.

The user accepts the doctor countdown with two local UI adjustments: common
unit/report buttons use elevation2 and the meeting column is centered. Both
uploaded files are the latest baseline, including the revised outer scroll
padding. Admin overview charts/filters are now drafted and supplied separately
for Mac verification. See ADMIN_CHARTS_PATCH_BN.md and ADMIN_CHARTS_NATIVE_REFERENCE.md.
The user reports that the dashboard is almost complete; the remaining screenshot
issues have corrections for X-label positioning and native lakh/crore payment
grouping, with existing monetary regression cases expanded. Simulator pinch
instructions are included. Corrected device appearance still needs acceptance.
The latest Mac log has a clean analyzer, 113 passing tests and one failing
small-screen/large-text legend-overflow test. The legend wrapping correction
retains that test; a corrected suite and simulator build are pending. UI approval
does not prove all lifecycle, API, device and release behavior.

After chart acceptance, continue to doctor Appointment schedule/list navigation,
then its filters and appointment details. Profile/edit and camera/crop remain
separate modules. Run a focused camera/crop and multipage prescription PDF iOS
trial before bulk migration of those workflows.

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


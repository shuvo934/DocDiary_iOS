# DocDashboard access/error audit — 18 October 2026

This audit compares the supplied Android 1.3.9.5(27) source with the implemented
Flutter dashboard. Its authored access/error cases have now been executed and
pass as part of the187-test suite (see DASHBOARD_COMPLETION_AUDIT.md). It is a source-level behavior mapping, not a claim of a
verified Flutter build or complete app migration. The user's overview
file is the UI baseline; `_total`/`_card` styling is retained, including w600.
Dart formatting is normalized; accepted UI token sequences are unchanged.

| Native path | Resulting Flutter behavior | Verification status |
| --- | --- | --- |
| getDocData/getAdminData | Same role endpoint/identity; server metadata retained | Source + authored contracts |
| user_avail0, doc_status/doc_eff_date | Native Access Denied text, including No User Data Found fallback; availability precedes force/access | Source + authored contracts |
| Admin count0 | No Information Found! and native admin message | Source + authored contracts |
| fl_flag / usr_mob_forced_log_out_flag1 | Native Forced Log Out! message including apology; OK removes active session and returns Login | Source + authored contract/widget cases |
| access_flag / usr_mob_app_access | Native Access Denied! message; no profile-initialization/log POST after denial | Source + authored contract/widget cases |
| updateDocExpDate/updateUSRExpDate | Only account initialization with first-login flag not1; existing expiry retained, otherwise three calendar months; same P_DATE/identity headers | Prior and expanded authored contracts |
| loginLog | Native identity headers and initialization order; iOS client descriptor replaces Android descriptor | Prior and expanded authored contracts |
| Expiry comparison | Calendar-day cutoff; today's expiry remains valid for doctor/admin | Source + authored contracts/widgets |
| first_flag0 warning | Native title/message/date/days, inclusive0–3; once after first full success per dashboard entry | Source + authored contracts/widgets |
| DocData/AdminData errors | Profile gate with native error-handler layout and actions; Retry repeats that account attempt without another login forced-flag reset | Source + authored contracts/widgets |
| DocSchedule/AdminDashboard errors | Hide full content/navigation, native WARNING! dialog; Retry remains a read-only dashboard operation; Log Out clears session | Source + authored contracts/widgets |
| Initial Admin chart pair failure | Full-load error handler; no queued second chart after first fails | Source + authored widget case |
| docPic/adminPic GET failure | Full-load error handler; successful empty/null picture retains the role placeholder | Source + expanded picture contract |
| alertMessage3 tab failure | Native Error!/OK plus summary refresh; selected period retained | Source + authored widget case |
| alertMessage4/5/6 chart failure | Existing Error!/OK and scoped refresh retained; fatal access failures route to the blocking account gate | Existing plus expanded cases |
| onButtonChoose retry destination | Auth/profile and full dashboard attempts retain their respective retry context; no flag reset on retry/switch | Source + authored cases |
| Log Out! Yes/No | Native confirmation; No keeps session, Yes clears it; explicit Remember Me retained | Existing and expanded cases |
| Owned dialogs, first_flag and lifecycle | One owned modal, close old routes on logout/switch/disposal; resume validates current account; discard obsolete responses and queued work | Source + authored cases |
| Summary-tab failure | Meeting/chart widgets retain real prior data; full failure still hides protected content | Source; Mac visual/interaction check pending |
| Existing role/action menus, filters, date ranges, countdown | Existing native-derived rules retained; current header/identity/actions/summary/tabs/menu/shadow and centered meeting rendering preserved | Earlier UI acceptance; expanded Mac checks pending |

Native references include DocDashboard.java `updateInterface`, `updateLayout`,
`updateAdminInterface`, `updateAdminLayout`, `alertMessage[2..6]`,
`adminAlertMessage[2]`, `onButtonChoose`, `onResume`, `onPause`,
ErrorHandlerDialogue.java and error_screen_logout_layout.xml. The custom error
dialog copies its WARNING! header, original logo/logout path, colours,
Poppins/Lato typography and LOG OUT / EXIT / RETRY order. Lato-Bold and its OFL
are bundled. Exact UIKit/Flutter text metrics and modal dimensions need Mac
screenshot comparison. Source hashes are in dashboard_access_native_reference.json.

## Intentional platform adaptations and guards

- iOS has no supported programmatic quit API. EXIT displays Home-gesture/Home-
  button instructions and retains any saved sign-in. It does not claim to close
  the process. Access-denial/expiry OK clears the session and returns Login,
  instead of closing the Android activity. No exit(0) or ProcessPhoenix clone.
- Cold restore and dashboard profile checks use a blocking typed denial state;
  no session is silently cleared before its OK. A failed Keychain erase keeps
  access blocked and its Retry retries erasure, not another sign-in.
- Read-only profile checks at dashboard entry/resume/tab changes add fresh
  access checks without another loginLog/expiry POST. Force flags are also
  checked before summary/chart batches. These guards add GETs versus native
  cached metadata; they do not add business mutations.
- Initialization/explicit profile Retry can POST exactly as native; there are
  no automatic POST retries. A persistence-only retry re-reads access without
  inserting another login log, so revoked access cannot be saved from a stale
  already-loaded profile.
- Missing/invalid access metadata or established expiry is retryable, never an
  implicit entitlement extension. A first-login0 null/empty expiry still gets
  the native three-calendar-month initialization. Invalid dates/numbers fail
  safely rather than copying native crashes or fabricating success/zero data.
- Obsolete/background requests cannot commit UI or queue later phases. Already
  sent requests cannot be rolled back. A full connection failure requires an
  explicit Retry; no automatic loop hammers the backend. Warning day counts
  use calendar dates even in zones with daylight-saving transitions.
- Summary, picture and chart reads are split into repositories; the photo is
  awaited before the initial chart pair, with readiness/warning only after the
  full batch succeeds. This preserves the failure/readiness behavior while
  adding access preflights, rather than reproducing Android's shared flags and
  exact request ordering.

Apple: https://developer.apple.com/library/archive/qa/qa1561/_index.html
Flutter: https://api.flutter.dev/flutter/services/SystemNavigator/pop.html

## Remaining dashboard/app scope

| Native feature | Current scope |
| --- | --- |
| Admin Dashboard camera/gallery/crop/updateAdminPic/Retry/Cancel | Implemented in this update; iPhone/iOS build acceptance pending |
| Doctor Profile edit/updateDocPic | Remains the separate DocProfile module |
| Profile, appointments, patients, block time, payments, report manager, HR/accounts/analytics destinations | Native entry/menu visibility retained; destination workflows remain separate migration modules |
| Google Play in-app review | iOS StoreKit replacement implemented; optional, debug disabled, at most once per dashboard entry after later full success |
| ProcessPhoenix and Android activity finish/process exit | Not copied into iOS; safe route/session handling and explicit Exit instructions used |
| Real-device, Keychain, lifecycle, accessibility and App Store release acceptance | Pending on Mac/iPhone; not established by source checks |

The requested access/expiry/error flows pass their Flutter regression cases.
The current187-test suite and analyzer pass on Linux. Mac/iPhone acceptance and
the complete app migration remain pending. Dashboard-owned remaining flows are
mapped in DASHBOARD_COMPLETION_AUDIT.md.

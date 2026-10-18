# Dashboard step 1 source mapping

Reference: supplied Android DocDiary 1.3.9.5 source. Source-file SHA-256 values
are recorded in `dashboard_native_reference.json`. The Play Store app and Android
source have not been modified.

| Flutter component | Native reference | Scope |
| --- | --- | --- |
| Header / white surface | activity_doc_dashboard.xml; ShapeAppearanceOverlay.MaterialCardView.Cut | Clouds header, 12sdp padding, 22sdp logo, 14sdp Poppins Bold title, 30dp top corners |
| Identity | activity_doc_dashboard.xml; updateInterface/updateAdminInterface | Poppins greeting/name/center, parentheses, 42sdp role-specific circular default photo |
| Center-name color | @color/colorLightBlue from HappyTimer/src/main/res/values/colors.xml | #2196F3; app-local colors.xml does not redeclare this inherited resource |
| Doctor actions | DocDashboard.updateInterface | doc_manager_flag takes precedence; doc_deptd_head_flag enables Unit Appointment otherwise |
| Summary tabs | three_tab_layout; NavigationTabTextAppeareance; tab_color_selector | Four fixed tabs, Patua One, primary-to-green-sea selected capsule, indicator removed at user request |
| Date labels | DocDashboard tab selection listener | dd MMMM, yy; Saturday–Friday and calendar-month API ranges retained |
| Schedule/admin cards | activity_doc_dashboard.xml; doc_dashboard_extra_layout.xml | Native padding, labels, Baloo numerals, design_new/border_design_1/design_new_2 colors |
| Appointment cards | activity_doc_dashboard.xml | Original dotted PNG, orange/teal/gray, 75sdp minimum height (user adjustment) |
| Doctor bottom menu | bottom_menu.xml | Profile, Appointment, Block Time, Patient; no Home entry; unlabeled white icons |
| Admin bottom menu | bottom_menu_admin.xml; updateAdminInterface | Payment/Appointment visibility for HR/Accounts flags; Patient and Reports/Management |
| Picture GET requests | getDocSchedule/getAdminDashboardData | getDocPic?doc_id and getAdminPic?p_usr_id; base64 image fields; native fallback assets |
| Next Meeting | updateInterface/updateLayout; HappyTimer 1.0.1 | last_sc/next_sc interval, native text branches, h/m/s groups, right-anchored progress and expiry/resume refresh |

PNG files are copied byte-for-byte. The logout/profile/appointment/block/payment/
camera vector paths are translated directly into Flutter Canvas Path operations.
No icon package or image-generating service substitutes their artwork.

SDP measurements use the same 30dp smallest-width buckets and 300dp baseline as
the earlier approved screens. Actual iOS font rasterization, shadows, tab wrapping
and system insets require device/screenshot review; source inspection cannot
establish pixel-level equality.

Native uses the original Baloo family, not Baloo 2. Baloo 1.443 is bundled from
Google's font endpoint with the font author's OFL. Archivo is the Google Fonts
variable face at weight 700/width 100, alongside existing approved fonts. Licences
and hashes are bundled in assets/fonts. The inherited center color was resolved
from the upstream HappyTimer resource:
https://github.com/happysingh23828/HappyTimer/blob/master/HappyTimer/src/main/res/values/colors.xml

## Behavior boundaries

- DashboardRepository.load retains its existing endpoint/access/count contracts,
  now also mapping last_sc and the request clock. It checks forced
  logout before summaries, uses native field/parameter names and preserves raw
  monetary strings. Formatting adds `৳` and native lakh/crore grouping
  (final3 digits, then groups of2) without rounding decimals.
- Picture GETs are separate and read-only. A successful empty/null photo uses
  the role PNG; full-load request failures now use the native three-action
  error handler. A malformed Base64 response is retryable instead of a crash.
- Period changes and refresh revalidate with recordLogin:false. The later access
  checkpoint adds typed blocking/retry states and dialog routing. The Keychain
  format and approved login/splash/selection rendering remain retained.
- Switch availability continues to use the existing AuthController.canSwitch.
  Android shows its icon whenever any center list exists, including a single
  non-switchable account. That single-account icon behavior is not changed here.
- New destination screens are pending and show an availability notice in this
  development build. Camera upload/crop and admin chart endpoints are not invoked.
- Native next-time rendering has two spacing/leading-zero branches based on
  last_sc. Both branches are now implemented, including the same-day leading-zero
  removal only when last_sc exists. The actual calendar date is checked instead
  of copying the native day-of-month-only comparison bug.
- Next-meeting data is retained while a period request loads; summary counts are
  hidden while loading or failed. No zero-filled data is fabricated.

## Verification evidence

Offline source/import/asset checks, an independent Dart syntax grammar parser,
font/asset checks and installer preservation/rollback fixtures run locally.
These do **not** replace flutter analyze, flutter test or an iOS build. Flutter,
Dart and Xcode are unavailable here. Mac runtime/visual acceptance is pending.

## User UI adjustments — 17 October 2026

The uploaded native_dashboard_layout(1).dart is the new working UI baseline.
It retains 6 logical pixels of horizontal scroll-content padding, a 75sdp
appointment-card minimum height, and the user's complete identity typography
and spacing (12sdp top, 13sdp greeting, 11sdp name, 2sdp name top padding).
Only two edits were made to that exact uploaded file: remove the selected-tab
2px white bottom overlay, and set the outer dashboard white surface elevation
from 3 to 0. This removes the flattened capsule edge and the body shadow spilling
above the rounded bottom navigation. Inner cards and the avatar keep their
existing shadows. Source/grammar checks pass; the result still needs visual
confirmation on the Mac. No new runtime test pass is claimed.

## Corner backing and top-arc shadow — 17 October 2026

The user confirmed the selected tab and zero-elevation fixes work. The follow-up
request keeps Scaffold clouds while making the exposed rounded-footer corners
white and adding a shadow only at the white surface's top-left and top-right.
The footer now has a white ColoredBox backing. A CustomPaint behind the existing
zero-elevation Material draws two open radius-30 arcs with a 2px blurred stroke
(sigma 3.5, ARGB 0x33000000), clipped to its own bounds. The center/side/bottom
edges have no painted shadow path. Layout, scroll geometry and user font/padding
changes are retained. Actual iPhone rendering of this cosmetic update is pending.


## Doctor countdown and latest user layout — 17 October 2026

The latest native_dashboard_layout(1).dart changes the shadow to one open path
across the full top edge. That painter implementation, identity, header, tabs,
summary cards and bottom-menu implementations are preserved byte-for-byte.
The countdown installer also preserves local layout customizations by merging
only imports, optional countdown/loading fields and the meeting-card call.

Native reference: DocDashboard.java onTick/onTimeUp, getDocSchedule,
updateInterface/updateLayout; activity_doc_dashboard.xml lines 262–404; and the
exact dependency `com.github.happysingh23828:HappyTimer:1.0.1`:
https://github.com/happysingh23828/HappyTimer/tree/1.0.1/HappyTimer/src/main

- Parse dd-MM-yyyy HH:mm:ss as local time, without inventing a server UTC offset.
- Interval: next_sc minus last_sc; without last_sc, first observed next_sc minus
  current time. Repeated reads of the same interval retain that initial anchor.
- Remaining whole seconds and integer percentages are recomputed from current
  time. Clamp percentages to 0–100; guard zero/negative intervals and invalid
  timestamps rather than reproducing a native parse/division crash.
- Show h only when hours are nonzero; m when total minutes are nonzero; always s.
  Digits have at least two places, with no 24-hour wrap. Native timer artwork,
  h/m/s labels, 10/8sdp timer typography and 8dp label gaps are retained.
- Card: native gray #CED6E0, teal #50C2C0, 86sdp track/minimum height, radius10,
  elevation3. Right-anchored fill follows native rotation180 and animates its
  integer target. Timer is allowed to scale down within its cell to prevent
  overflow for long durations/large system text; native may clip in those cases.
- AOSP Roboto 2.138 regular/bold is bundled for the timer instead of allowing
  iOS to substitute its default font. NOTICE and source hashes are included.
  Original native and iOS font rasterization still require screenshot review.
- On expiry hide dashboard/menu behind the main white loading state, wait 3s,
  then read doctor summary/schedule for Today. Existing in-flight work finishes
  first; exactly one queued Today refresh follows without overlapping requests.
- Pause cancels ticking and pending expiry work. Resume revalidates with
  recordLogin:false, returns to Today and uses the current clock. A resume during
  a request is queued rather than dropped. Disposal/logout/switch stops old work.
- A failed read displays retry, stops automatic polling and never fabricates a
  no-meeting response. A successful stale expired response can schedule another
  3s read, as in native, until the backend supplies a later/empty schedule.
- Counts/date labels remain tied to their request clock while seconds tick, so
  midnight cannot relabel yesterday's fetched counts as today's figures.

Local source/grammar/preservation and installer fixtures are recorded in
VERIFICATION.md. Flutter execution, iPhone acceptance and pixel parity remain
pending. Admin charts, camera writes and destination screens are outside this
checkpoint.


## Admin overview and latest accepted UI — 17 October 2026

The latest uploaded layout(3) changes the shared doctor-action button elevation
from5 to2 and moves scroll padding to an outer top2/left6/right6/bottom6 wrapper.
The uploaded NativeMeetingPanel centers its content column. These exact files
are adopted; only the optional Admin child/integration is added to the layout.
Doctor summary, timer, header, menus and all their class implementations remain
unchanged from these uploads. Admin overview now follows the dedicated reference
ADMIN_CHARTS_NATIVE_REFERENCE.md; the earlier pending statements are historical.

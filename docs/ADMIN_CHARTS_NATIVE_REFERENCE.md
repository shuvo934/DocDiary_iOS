# Admin overview source mapping

Native baseline: DocDiary 1.3.9.5 (27). References are read from the supplied
DocDashboard.java, doc_dashboard_extra_layout_1.xml, MyMarkerView.java,
AppointMarkerView.java, custom_marker_view.xml, colours and vector resources.

| Behavior | Flutter implementation |
| --- | --- |
| Monthly payment | getPaymentDataMonthly / getPaymentDataOfflineMonthly / getPaymentDataOnlineMonthly |
| Yearly payment | getPaymentDataYearly / getPaymentDataOfflineYearly / getPaymentDataOnlineYearly |
| Monthly appointment | getAppointDataMonthly / getAppointDataOfflineMonthly / getAppointDataOnlineMonthly |
| Yearly appointment | getAppointDataYearly / getAppointDataOfflineYearly / getAppointDataOnlineYearly |
| Parameters | begin_date/end_date in dd-MMM-yy; payment also gets user_id |
| User scope | all_access_flag1 gives empty payment user filter; other admin roles use usr_name; appointment has no user_id |
| Type controls | Visible only for is_pay_appoint_type_active1; hidden controls cannot issue non-All requests |
| Data mapping | Monthly dates; yearly pmonths; payment amount/amount1; appointment total_app/cancel_app |
| Row positions | API order retained; no invented dates, padding points or reordered rows |
| Shared controls | Monthly/Yearly or type changes reset both dates to the current month/year |
| Individual date | Payment and appointment dates reload independently |
| Picker range | 12 inclusive months; 11 inclusive years, matching native limits |
| Lifecycle | Dashboard resume/full refresh revalidates without login records, then resets Monthly/All |

AdminChartRepository verifies the current force-logout flag before a chart read
or pair, in addition to cached profile access. This is an extra read-only guard
compared with the native chart-filter methods, which rely on dashboard validation.
Pair reads remain sequential Payment then Appointment, but use independent
request generations instead of Android's shared conn/connected flags. Stale
results and background/account changes cannot commit or queue an old second read.
No authentication flag reset, login log or payment/appointment mutation is added.

## Rendering

| Native resource/configuration | Implementation |
| --- | --- |
| OVERVIEW | Orange #FDA000, PoppinsBold13sdp |
| Type capsules | GreenSea #16A085 / white; inactive #1A50C2C0; PoppinsSemiBold8sdp; radius9sdp |
| Mode tabs | PatuaOne11sdp, approved gradient capsules without the white bottom overlay |
| Cards | White, height280sdp, radius10dp, elevation2dp |
| Primary series | GreenSea line, #50C2C0 circle |
| Payment return | #FDA000 line, #C23616 circle |
| Cancel appointment | #B2BEC3 line, #95A5A6 circle |
| Geometry | 2dp cubic lines with intensity .2; 3dp circles/1.8dp white holes; no fill/grid/Y labels |
| Axis/values | Roboto; X10sp, point8sp; full rotated X label bounds start4px below the axis;45 degrees monthly and0 yearly |
| Payment totals | Android ICU DecimalFormat("###,##,##,###"):3 digits then2-digit groups; HALF_EVEN whole numbers |
| Appointment totals | String.valueOf(int), without digit grouping |
| Legend | Centered two-series names with native line colours |
| Animation | One-second XY reveal; reload resets zoom and marker |
| Marker | Original unmodified c_marker.png, white9sdp value; payment prefix ৳; whole-number grouping |
| Error | Initial full-load errors delegate to native WARNING!/LOG OUT/EXIT/RETRY; scoped chart changes retain Error!/OK and refresh icons |
| Empty | No chart data available. with successful zero totals |

Primary dependency references inspected at the exact Android versions:

- MPAndroidChart v3.1.0, LineChartRenderer, LineDataSet, LargeValueFormatter and
  AxisRenderer: https://github.com/PhilJay/MPAndroidChart/tree/v3.1.0
- Month-year wheel library1.0.2: https://github.com/dewinjm/monthyear-picker/tree/1.0.2
- Year picker1.3.0: https://github.com/joeShuff/MonthAndYearPicker/tree/1.3.0

This is a Flutter Canvas/widget implementation of the native configuration;
no chart/picker package or native platform-view dependency is added. Android
source/licences remain with the supplied project; the original app PNG/vector
resources are retained rather than substituted artwork.

## Deliberate guards and pending acceptance

- Exact decimal sums are rounded HALF_EVEN to whole-number chart totals. Android
  sums doubles and rounds with DecimalFormat; this avoids floating accumulation
  and integer-count overflow differences at extreme boundaries. Chart points
  retain native float32 precision. Summary keeps its original decimal precision
  and now shares the corrected lakh/crore payment grouping. Payment chart totals
  differ from MPAndroidChart marker tooltips, which group every three digits.
- Android14 java.text.DecimalFormat uses CompatibleDecimalFormatFactory/ICU;
  a desktop Java formatter is not an oracle for its secondary grouping. The
  literal pattern was checked against ICU74 for twelve sample and edge values.
  Sources: https://android.googlesource.com/platform/libcore/+/refs/heads/android14-release/ojluni/src/main/java/java/text/DecimalFormat.java
  and https://android.googlesource.com/platform/external/icu/+/refs/heads/android14-release/android_icu4j/libcore_bridge/src/java/com/android/icu/text/CompatibleDecimalFormatFactory.java
- LargeValueFormatter's normal k/m/b/t cases were checked with Java17. Its
  malformed negative-exponent output for tiny fractions is kept readable here.
- The native value-text colour passes a resource ID to setValueTextColor; its
  intended #6C6E6F is resolved here instead of depending on a generated ID value.
- Invalid/missing/non-finite data raises retry, rather than silently fabricating
  zeros or copying a native parsing crash. count0 remains valid empty data.
- Pinch selects the dominant X/Y axis, with bounded zoom/pan; double-tap zoom is
  disabled. Dense/single/empty data and collapsed chart ranges are guarded.
- At large system font sizes, header/legend wrapping and fitted controls/totals
  avoid native clipping. Regular-size dimensions follow the native attributes.
- Flutter font metrics, exact axis tick placement, shadows, gesture feel and the
  two reconstructed Android-library picker dialogs require device/screenshot
  comparison. Source mapping does not establish pixel-perfect parity.

The uploaded centered meeting panel is unchanged. All other dashboard widget
classes retain the user's latest typography, padding, elevation2 and full-top
shadow. Integration is optional and Admin-only. Flutter analyzer/tests/iOS build
and runtime/visual acceptance are pending; see VERIFICATION.md.

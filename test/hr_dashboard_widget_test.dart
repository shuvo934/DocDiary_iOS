import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/login_screen.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_services.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_models.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_navigation.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_screen.dart';
import 'package:docdiary_ios/features/hr/native_hr_attendance_chart.dart';
import 'package:docdiary_ios/features/hr/native_hr_dashboard_layout.dart';
import 'package:docdiary_ios/features/hr/native_hr_payroll_month_dialog.dart';
import 'package:docdiary_ios/features/management/native_management_portal_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'hr_dashboard_test_support.dart';

void _case(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    final shadows = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = shadows;
    }
  });
}

Future<void> _tap(WidgetTester t, String key) async {
  final finder = find.byKey(Key(key));
  if (finder.hitTestable().evaluate().isEmpty) await t.ensureVisible(finder);
  await t.tap(finder);
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> _show(
  WidgetTester t,
  HrHarness h, {
  DashboardDestinationBuilder? builder,
  bool enterHr = true,
}) async {
  t.view.physicalSize = const Size(393, 852);
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPadding);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await h.signIn();
  await t.pumpWidget(
    RepaintBoundary(
      key: const Key('hr_capture'),
      child: DocDiaryApp(
        auth: h.auth,
        initializeOnStart: false,
        dashboard: DashboardRepository(h.transport, now: () => h.now),
        dashboardServices: DashboardServices(destinationBuilder: builder),
      ),
    ),
  );
  await t.pumpAndSettle();
  await _tap(t, 'dashboard_nav_management');
  if (enterHr) await _tap(t, 'management_humanResources');
}

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
  expect(t.takeException(), isNull);
}

Future<void> _capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_HR_CAPTURE_DIR'];
  if (dir == null) return;
  await t.runAsync(() async {
    final context = t.element(find.byType(NativeHrDashboardLayout));
    for (final asset in [
      'background_png_dot.png',
      'hr_icon.png',
      ...HrDestination.values.map((d) => d.artwork),
    ]) {
      await precacheImage(AssetImage('assets/images/$asset'), context);
    }
  });
  await t.pumpAndSettle();
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('hr_capture')),
  );
  await t.runAsync(() async {
    final bitmap = await boundary.toImage(pixelRatio: 1);
    final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
    bitmap.dispose();
    final file = File('$dir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry
        in <String, List<String>>{
          'Poppins': [
            'Poppins-Regular.ttf',
            'Poppins-Medium.ttf',
            'Poppins-Bold.ttf',
          ],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
          'DocDiaryBengali': ['NotoSansBengali.ttf'],
          'Archivo': ['Archivo[wdth,wght].ttf'],
          'Baloo': ['Baloo-Regular.ttf'],
          'PatuaOne': ['PatuaOne-Regular.ttf'],
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
        }.entries) {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  _case(
    'live Dashboard opens permitted HR main screen and Back refreshes Portal',
    (t) async {
      final h = HrHarness();
      await _show(t, h);
      expect(find.byType(HrDashboardScreen), findsOneWidget);
      expect(find.text('DEPARTMENTS'), findsOneWidget);
      expect(find.text('88'), findsOneWidget);
      expect(find.byType(NativeHrAttendanceChart), findsOneWidget);
      final ui = t.widget<NativeHrDashboardLayout>(
        find.byType(NativeHrDashboardLayout),
      );
      expect(ui.attendancePeriod, HrAttendancePeriod.today);
      expect(ui.leavePeriod, HrLeavePeriod.thisWeek);
      expect(ui.payrollMonth.label, 'MONTH: SEP-26');
      expect(h.hrRequests.length, 6);
      final posts = h.posts.length;
      await _capture(t, 'hr_dashboard_top');
      await _tap(t, 'hr_back');
      expect(find.byType(NativeManagementPortalLayout), findsOneWidget);
      expect(h.posts.length, posts);
      await _finish(t);
    },
  );

  _case(
    'HR-only role also reaches HR without gaining Accounts Analytics access',
    (t) async {
      final h = HrHarness()..adminData['all_access_flag'] = '2';
      await _show(t, h);
      expect(find.byType(HrDashboardScreen), findsOneWidget);
      await _tap(t, 'hr_back');
      expect(find.text('HR & Reports'), findsOneWidget);
      expect(find.byKey(const Key('management_accounts')), findsNothing);
      expect(find.byKey(const Key('management_analytics')), findsNothing);
      await _finish(t);
    },
  );

  _case(
    'attendance period fetches only its native endpoint and same tab is not reloaded',
    (t) async {
      final h = HrHarness();
      await _show(t, h);
      h.transport.requests.clear();
      await _tap(t, 'hr_att_2');
      expect(h.hrRequests.length, 1);
      expect(h.hrRequests.single.uri.queryParameters, {
        'first_date': '10-OCT-26',
        'last_date': '16-OCT-26',
      });
      expect(find.text('10 October, 26  --  16 October, 26'), findsOneWidget);
      expect(
        t
            .widget<NativeHrDashboardLayout>(
              find.byType(NativeHrDashboardLayout),
            )
            .valueFontSize,
        10,
      );
      await _tap(t, 'hr_att_2');
      expect(h.hrRequests.length, 1);
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );

  _case(
    'leave filters refresh only their two endpoints with matching Saturday-Friday dates',
    (t) async {
      final h = HrHarness();
      await _show(t, h);
      h.transport.requests.clear();
      await _tap(t, 'hr_leave_2');
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getEmpWithLeaveDate',
        'getEmpInLeave',
      ]);
      expect(
        h.hrRequests.every(
          (r) => r.uri.queryParameters['first_date'] == '24-OCT-26',
        ),
        isTrue,
      );
      expect(
        h.hrRequests.every(
          (r) => r.uri.queryParameters['last_date'] == '30-OCT-26',
        ),
        isTrue,
      );
      expect(
        t
            .widget<NativeHrDashboardLayout>(
              find.byType(NativeHrDashboardLayout),
            )
            .leave!
            .employees
            .first
            .cells
            .first,
        'CL',
      );
      await _finish(t);
    },
  );

  _case('empty attendance and leave show native No Data and week message', (
    t,
  ) async {
    final h = HrHarness();
    h.attendanceRow = {for (final k in HrAttendance.keys) k: '0'};
    h.dateRows = [];
    h.employeeRows = [];
    await _show(t, h);
    expect(find.text('No Data'), findsOneWidget);
    expect(find.byKey(const Key('hr_no_leave')), findsOneWidget);
    await _tap(t, 'hr_leave_more');
    expect(find.byKey(const Key('hr_unavailable')), findsOneWidget);
    expect(find.text('Leave Record'), findsWidgets);
    await _finish(t);
  });

  _case(
    'payroll shows all six native cards exact formatting and real-font render',
    (t) async {
      final h = HrHarness();
      await _show(t, h);
      await t.ensureVisible(find.byKey(const Key('hr_payroll_5')));
      await t.pumpAndSettle();
      expect(find.text('Working Hours'), findsOneWidget);
      expect(find.text('Salary Generated'), findsOneWidget);
      expect(find.text('Net Salary'), findsOneWidget);
      expect(find.text('৳ 1,23,45,678.2'), findsOneWidget);
      expect(find.text('15488 h'), findsOneWidget);
      expect(find.text('WD: 25'), findsOneWidget);
      await _capture(t, 'hr_dashboard_payroll');
      await _finish(t);
    },
  );

  _case(
    'canceling month picker sends no request and leaves other controls usable',
    (t) async {
      final h = HrHarness();
      await _show(t, h);
      h.transport.requests.clear();
      await _tap(t, 'hr_payroll_month');
      expect(find.byType(NativeHrPayrollMonthDialog), findsOneWidget);
      await _tap(t, 'hr_month_cancel');
      expect(h.hrRequests, isEmpty);
      await _tap(t, 'hr_att_1');
      expect(h.hrRequests.length, 1);
      await _finish(t);
    },
  );

  _case(
    'payroll month changes only payroll and working-days requests after OK',
    (t) async {
      final h = HrHarness();
      await _show(t, h);
      h.transport.requests.clear();
      await _tap(t, 'hr_payroll_month');
      await t.timedDrag(
        find.byKey(const Key('hr_payroll_month_wheel')),
        const Offset(0, 50),
        const Duration(seconds: 1),
      );
      await t.pumpAndSettle();
      expect(h.hrRequests, isEmpty);
      await _tap(t, 'hr_month_ok');
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getPayrollData',
        'getAttWorkingDays',
      ]);
      expect(
        h.hrRequests.every(
          (r) => r.uri.queryParameters['first_date'] == '01-AUG-26',
        ),
        isTrue,
      );
      expect(find.text('MONTH: AUG-26'), findsOneWidget);
      await _finish(t);
    },
  );

  _case(
    'right drawer has six native destinations original icons and clean close',
    (t) async {
      final h = HrHarness();
      await _show(t, h);
      await _tap(t, 'hr_menu');
      expect(find.text('HR Menu'), findsOneWidget);
      for (final entry in HrDestination.values) {
        expect(find.byKey(Key('hr_menu_${entry.name}')), findsOneWidget);
      }
      await _capture(t, 'hr_dashboard_menu');
      await _tap(t, 'hr_drawer_close');
      expect(find.byKey(const Key('hr_scroll')).hitTestable(), findsOneWidget);
      await _finish(t);
    },
  );

  _case(
    'future drawer destination uses explicit availability and returns to usable HR',
    (t) async {
      final h = HrHarness();
      await _show(t, h);
      await _tap(t, 'hr_menu');
      await _tap(t, 'hr_menu_leaveBalance');
      expect(find.byKey(const Key('hr_unavailable')), findsOneWidget);
      await t.tap(find.text('Close'));
      await t.pumpAndSettle();
      await _tap(t, 'hr_att_1');
      expect(
        t
            .widget<NativeHrDashboardLayout>(
              find.byType(NativeHrDashboardLayout),
            )
            .attendancePeriod,
        HrAttendancePeriod.lastDay,
      );
      await _finish(t);
    },
  );

  _case(
    'pie tap dispatches Daily Attendance and pie drag rotates without dispatch',
    (t) async {
      final h = HrHarness();
      await _show(
        t,
        h,
        builder:
            (context, route) =>
                route.module == DashboardModule.hrDailyAttendance
                    ? const Scaffold(
                      body: Center(
                        child: Text(
                          'Daily Attendance',
                          key: Key('hr_dispatched_daily'),
                        ),
                      ),
                    )
                    : null,
      );
      await t.drag(find.byKey(const Key('hr_pie')), const Offset(30, 25));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('hr_unavailable')), findsNothing);
      await _tap(t, 'hr_pie');
      expect(find.byKey(const Key('hr_dispatched_daily')), findsOneWidget);
      expect(find.text('Daily Attendance'), findsOneWidget);
      await _finish(t);
    },
  );

  _case(
    'custom Leave Approval route retains FLAG zero and return resets native defaults',
    (t) async {
      final h = HrHarness();
      DashboardRoute? route;
      await _show(
        t,
        h,
        builder: (context, r) {
          if (r.module != DashboardModule.hrLeaveApproval) return null;
          route = r;
          return Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('hr_child_back'),
                onPressed: () => Navigator.pop(context),
                child: const Text('Back from child'),
              ),
            ),
          );
        },
      );
      await _tap(t, 'hr_att_1');
      await _tap(t, 'hr_menu');
      await _tap(t, 'hr_menu_leaveApproval');
      expect(route!.extras, {'FLAG': '0'});
      final count = h.hrRequests.length;
      await _tap(t, 'hr_child_back');
      expect(h.hrRequests.length, count + 6);
      expect(
        t
            .widget<NativeHrDashboardLayout>(
              find.byType(NativeHrDashboardLayout),
            )
            .attendancePeriod,
        HrAttendancePeriod.today,
      );
      await _finish(t);
    },
  );

  _case(
    'initial HR read failure uses noncancelable Retry and reloads without writes',
    (t) async {
      final h = HrHarness();
      var fail = true;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getDeptEmpCount') && fail) {
          throw const AppFailure('HR counts unavailable');
        }
        return h.respond(uri);
      };
      await _show(t, h);
      expect(find.byKey(const Key('hr_full_error')), findsOneWidget);
      expect(find.byKey(const Key('hr_scroll')), findsNothing);
      await t.tapAt(const Offset(5, 800));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('hr_full_error')), findsOneWidget);
      final posts = h.posts.length;
      fail = false;
      await _tap(t, 'hr_error_retry');
      expect(find.text('88'), findsOneWidget);
      expect(h.posts.length, posts);
      await _finish(t);
    },
  );

  _case('initial error Exit returns to Portal keeping authenticated session', (
    t,
  ) async {
    final h = HrHarness();
    h.transport.onGet = (uri) async {
      if (uri.path.endsWith('getPayrollData')) {
        throw const AppFailure('Payroll unavailable');
      }
      return h.respond(uri);
    };
    await _show(t, h);
    await _tap(t, 'hr_error_exit');
    expect(find.byType(NativeManagementPortalLayout), findsOneWidget);
    expect(h.auth.stage, AuthStage.authenticated);
    await _finish(t);
  });

  for (final section in [
    HrSection.attendance,
    HrSection.leave,
    HrSection.payroll,
  ]) {
    _case('${section.name} filter error uses OK and scoped manual refresh', (
      t,
    ) async {
      final h = HrHarness();
      await _show(t, h);
      var fail = true;
      h.transport.requests.clear();
      h.transport.onGet = (uri) async {
        final endpoint = switch (section) {
          HrSection.attendance => 'getAttendancePerc',
          HrSection.leave => 'getEmpInLeave',
          _ => 'getAttWorkingDays',
        };
        if (uri.path.endsWith(endpoint) && fail) {
          throw const AppFailure('Selected period unavailable');
        }
        return h.respond(uri);
      };
      if (section == HrSection.attendance) {
        await _tap(t, 'hr_att_1');
      } else if (section == HrSection.leave) {
        await _tap(t, 'hr_leave_0');
      } else {
        await _tap(t, 'hr_payroll_month');
        await _tap(t, 'hr_month_ok');
      }
      expect(find.byKey(const Key('hr_section_error')), findsOneWidget);
      await _tap(t, 'hr_error_ok');
      expect(find.byKey(Key('hr_${section.name}_refresh')), findsOneWidget);
      fail = false;
      h.transport.requests.clear();
      await _tap(t, 'hr_${section.name}_refresh');
      expect(find.byKey(Key('hr_${section.name}_refresh')), findsNothing);
      expect(h.hrRequests.length, section == HrSection.attendance ? 1 : 2);
      expect(h.posts, isEmpty);
      await _finish(t);
    });
  }

  _case(
    'loading ignores repeated and retained filter callbacks and blocks Back',
    (t) async {
      final h = HrHarness();
      await _show(t, h);
      final before = t.widget<NativeHrDashboardLayout>(
        find.byType(NativeHrDashboardLayout),
      );
      final pending = Completer<JsonMap>();
      h.transport.onGet =
          (uri) =>
              uri.path.endsWith('getAttendancePerc')
                  ? pending.future
                  : h.respond(uri);
      before.onAttendancePeriod(HrAttendancePeriod.lastDay);
      await t.pump();
      before.onLeavePeriod(HrLeavePeriod.nextWeek);
      before.onDestination(HrDestination.leaveApproval);
      before.onBack();
      await t.pump();
      expect(find.byType(HrDashboardScreen), findsOneWidget);
      expect(
        t
            .widget<NativeHrDashboardLayout>(
              find.byType(NativeHrDashboardLayout),
            )
            .leavePeriod,
        HrLeavePeriod.thisWeek,
      );
      pending.complete(hrPage([h.attendanceRow]));
      await t.pumpAndSettle();
      await _finish(t);
    },
  );

  _case(
    'background hides sensitive body and resume resets periods at the new calendar date',
    (t) async {
      final h = HrHarness();
      await _show(t, h);
      await _tap(t, 'hr_att_1');
      final posts = h.posts.length;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      expect(find.byKey(const Key('hr_scroll')), findsNothing);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      h.now = DateTime(2026, 10, 21, 1);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      final layout = t.widget<NativeHrDashboardLayout>(
        find.byType(NativeHrDashboardLayout),
      );
      expect(layout.attendancePeriod, HrAttendancePeriod.today);
      expect(layout.attendanceRange.label, '21 October, 26');
      expect(h.posts.length, posts);
      await _finish(t);
    },
  );

  _case(
    'retained child callback rechecks revoked HR access before opening any destination',
    (t) async {
      final h = HrHarness();
      await _show(t, h);
      final layout = t.widget<NativeHrDashboardLayout>(
        find.byType(NativeHrDashboardLayout),
      );
      h.adminData['hr_dashboard'] = '0';
      h.transport.requests.clear();
      layout.onDestination(HrDestination.dailyAttendance);
      await t.pumpAndSettle();
      expect(
        find.text('HR Dashboard access is not available for this account.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('hr_unavailable')), findsNothing);
      expect(h.hrRequests, isEmpty);
      expect(h.auth.stage, AuthStage.authenticated);
      await _tap(t, 'hr_back');
      expect(find.byKey(const Key('management_humanResources')), findsNothing);
      await _finish(t);
    },
  );

  for (final change in ['forced', 'mobile', 'expired']) {
    _case('$change access on resume closes HR and all owned Portal routes', (
      t,
    ) async {
      final h = HrHarness();
      await _show(t, h);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      if (change == 'forced') {
        h.adminData['usr_mob_forced_log_out_flag'] = '1';
      } else if (change == 'mobile') {
        h.adminData['usr_mob_app_access'] = '0';
      } else {
        h.adminData['exp_date'] = '19-OCT-26';
      }
      h.transport.requests.clear();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(find.byType(HrDashboardScreen), findsNothing);
      expect(h.auth.stage, AuthStage.accountBlocked);
      expect(h.hrRequests, isEmpty);
      await _finish(t);
    });
  }

  _case(
    'logout during pending initial read ignores late reply and stops the remaining chain',
    (t) async {
      final h = HrHarness();
      await _show(t, h, enterHr: false);
      final pending = Completer<JsonMap>();
      h.transport.onGet =
          (uri) =>
              uri.path.endsWith('getDeptEmpCount')
                  ? pending.future
                  : h.respond(uri);
      await t.tap(find.byKey(const Key('management_humanResources')));
      await t.pump();
      await t.pump();
      await h.auth.logout();
      await t.pumpAndSettle();
      pending.complete(hrPage([h.departmentRow]));
      await t.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HrDashboardScreen), findsNothing);
      expect(h.hrRequests.length, 1);
      await _finish(t);
    },
  );

  _case(
    'logout closes an owned month picker without leaving an overlay above Login',
    (t) async {
      final h = HrHarness();
      await _show(t, h);
      await _tap(t, 'hr_payroll_month');
      await h.auth.logout();
      await t.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(NativeHrPayrollMonthDialog), findsNothing);
      await _finish(t);
    },
  );

  _case('signed-out direct entry makes no profile or HR request', (t) async {
    final h = HrHarness();
    addTearDown(h.auth.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: docDiaryTheme(),
        home: HrDashboardScreen(auth: h.auth, repository: h.hr),
      ),
    );
    await t.pumpAndSettle();
    expect(h.transport.requests, isEmpty);
    expect(
      find.text('HR Dashboard access is not available for this account.'),
      findsOneWidget,
    );
    await _finish(t);
  });

  _case(
    'normal small landscape and large-text HR layouts render and scroll without overflow',
    (t) async {
      final h = HrHarness();
      addTearDown(h.auth.dispose);
      final range = HrDateRange.leave(HrLeavePeriod.thisWeek, h.now);
      final leave = HrWeeklyLeave.fromRows(
        range,
        [
          hrDateRow(
            '17-OCT-26',
            'An exceptionally long employee display name',
            'CL',
          ),
        ],
        [
          {'emp_name': 'An exceptionally long employee display name'},
        ],
      );
      for (final spec in [
        (const Size(320, 568), 1.0),
        (const Size(320, 568), 2.5),
        (const Size(852, 393), 2.5),
      ]) {
        t.view.physicalSize = spec.$1;
        t.view.devicePixelRatio = 1;
        await t.pumpWidget(
          MaterialApp(
            theme: docDiaryTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: spec.$1,
                textScaler: TextScaler.linear(spec.$2),
              ),
              child: NativeHrDashboardLayout(
                scaffoldKey: GlobalKey<ScaffoldState>(),
                onBack: () {},
                onDestination: (_) {},
                onAttendancePeriod: (_) {},
                onLeavePeriod: (_) {},
                onPayrollMonth: () {},
                onRetry: (_) {},
                attendancePeriod: HrAttendancePeriod.today,
                leavePeriod: HrLeavePeriod.thisWeek,
                attendanceRange: HrDateRange.attendance(
                  HrAttendancePeriod.today,
                  h.now,
                ),
                leaveRange: range,
                payrollMonth: HrPayrollMonth(DateTime(2026, 9)),
                failures: const {},
                counts: const HrCounts('12', '88'),
                attendance: HrAttendance.fromJson(h.attendanceRow),
                leave: leave,
                payroll: HrPayroll.fromRows(h.payrollRow, {'work_days': '25'}),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(
          t.takeException(),
          isNull,
          reason: '${spec.$1} scale ${spec.$2}',
        );
        await t.ensureVisible(find.byKey(const Key('hr_payroll_5')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
      }
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
      await _finish(t);
    },
  );

  _case(
    'large-text payroll picker can choose earliest completed month across year boundary',
    (t) async {
      HrPayrollMonth? result;
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          theme: docDiaryTheme(),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    key: const Key('open_month'),
                    onPressed: () async {
                      result = await showDialog<HrPayrollMonth>(
                        context: context,
                        builder:
                            (_) => NativeHrPayrollMonthDialog(
                              selected: HrPayrollMonth(DateTime(2025, 12)),
                              now: DateTime(2026, 1, 10),
                            ),
                      );
                    },
                    child: const Text('Month'),
                  ),
                ),
          ),
        ),
      );
      await _tap(t, 'open_month');
      await _tap(t, 'hr_month_2025_7');
      await _tap(t, 'hr_month_ok');
      expect(result!.first, DateTime(2025, 7));
      await _finish(t);
    },
  );
}

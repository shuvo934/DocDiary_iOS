import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/features/auth/login_screen.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_services.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/hr/employee_attendance/employee_attendance_models.dart';
import 'package:docdiary_ios/features/hr/employee_attendance/employee_attendance_screen.dart';
import 'package:docdiary_ios/features/hr/employee_attendance/native_employee_attendance_layout.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'employee_attendance_test_support.dart';

void _case(String label, Future<void> Function(WidgetTester) body) {
  testWidgets(label, (t) async {
    final old = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await body(t);
    } finally {
      debugDisableShadows = old;
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

NativeEmployeeAttendanceLayout _layout(WidgetTester t) =>
    t.widget(find.byType(NativeEmployeeAttendanceLayout));
Future<void> _show(
  WidgetTester t,
  EmployeeAttendanceHarness h, {
  EmployeeAttendanceSeed seed = const EmployeeAttendanceSeed(),
  Size size = const Size(393, 852),
  double textScale = 1,
  bool hr = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPadding);
  addTearDown(h.auth.dispose);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await h.signIn();
  h.transport.requests.clear();
  await t.pumpWidget(
    RepaintBoundary(
      key: const Key('employee_capture'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: docDiaryTheme(),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    key: const Key('open_employee'),
                    onPressed:
                        () => unawaited(
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder:
                                  (_) =>
                                      hr
                                          ? HrDashboardScreen(
                                            auth: h.auth,
                                            repository: h.hr,
                                          )
                                          : EmployeeAttendanceScreen(
                                            auth: h.auth,
                                            repository: h.employeeAttendance,
                                            seed: seed,
                                          ),
                            ),
                          ),
                        ),
                    child: const Text('Open'),
                  ),
                ),
              ),
        ),
      ),
    ),
  );
  await _tap(t, 'open_employee');
}

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
  expect(t.takeException(), isNull);
}

Future<void> _cascade(WidgetTester t, {int employee = 0}) async {
  for (final name in ['division', 'department', 'designation', 'employee']) {
    await _tap(t, 'employee_$name');
    await _tap(
      t,
      'employee_${name}_option_${name == 'employee' ? employee : 0}',
    );
  }
}

Future<void> _capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_EMPLOYEE_CAPTURE_DIR'];
  if (dir == null) return;
  await t.runAsync(() async {
    await precacheImage(
      const AssetImage('assets/images/hospital_icon.png'),
      t.element(find.byType(NativeEmployeeAttendanceLayout)),
    );
  });
  await t.pumpAndSettle();
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('employee_capture')),
  );
  await t.runAsync(() async {
    final bitmap = await boundary.toImage(pixelRatio: 1);
    final data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
    bitmap.dispose();
    final file = File('$dir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry
        in <String, List<String>>{
          'Poppins': ['Poppins-Regular.ttf', 'Poppins-Bold.ttf'],
          'Roboto': ['Roboto-Regular.ttf'],
          'Archivo': ['Archivo[wdth,wght].ttf'],
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
          'DocDiaryBengali': ['NotoSansBengali.ttf'],
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
    'default entry has two enabled/disabled filter rows and no fabricated employee report',
    (t) async {
      final h = EmployeeAttendanceHarness();
      await _show(t, h);
      expect(find.text('Emp Wise Attendance'), findsOneWidget);
      expect(_layout(t).catalog!.department, isNull);
      expect(_layout(t).report, isNull);
      expect(find.byKey(const Key('employee_identity')), findsNothing);
      expect(h.hrRequests.length, 2);
      expect(
        t
            .widget<PopupMenuButton<EmployeeAttendanceChoice>>(
              find.byKey(const Key('employee_department')),
            )
            .enabled,
        isFalse,
      );
      final department = t.widget<InputDecorator>(
        find.descendant(
          of: find.byKey(const Key('employee_department')),
          matching: find.byType(InputDecorator),
        ),
      );
      expect(department.decoration.enabled, isFalse);
      expect(department.decoration.fillColor, const Color(0xfff5f5f5));
      expect(department.decoration.labelStyle!.fontSize, 13);
      await _capture(t, 'employee_attendance_filters');
      await _finish(t);
    },
  );
  _case(
    'four filter levels use duplicate-name employee IDs and reset downstream selections',
    (t) async {
      final h = EmployeeAttendanceHarness();
      await _show(t, h);
      await _cascade(t, employee: 1);
      expect(_layout(t).catalog!.employee!.id, '12');
      expect(_layout(t).report!.rows.length, 4);
      expect(h.hrRequests.length, 9);
      await _tap(t, 'employee_division');
      await _tap(t, 'employee_division_option_1');
      expect(_layout(t).catalog!.division!.id, '2');
      expect(_layout(t).catalog!.department, isNull);
      expect(_layout(t).catalog!.employee, isNull);
      expect(_layout(t).report, isNull);
      expect(find.byKey(const Key('employee_identity')), findsNothing);
      await _finish(t);
    },
  );
  _case(
    'branch selection only fetches scoped divisions and None resets to global catalogues',
    (t) async {
      final h = EmployeeAttendanceHarness();
      await _show(t, h);
      await _cascade(t);
      h.transport.requests.clear();
      await _tap(t, 'employee_branch');
      await _tap(t, 'employee_branch_option_1');
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getDivisionWithCoa',
      ]);
      expect(_layout(t).catalog!.employee, isNull);
      await _tap(t, 'employee_branch');
      await _tap(t, 'employee_branch_option_0');
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getDivisionWithCoa',
        'getBranches',
        'getDivision',
      ]);
      await _finish(t);
    },
  );
  _case(
    'seed displays native identity, count chart, colored report and summary',
    (t) async {
      final h = EmployeeAttendanceHarness();
      await _show(t, h, seed: employeeSeed);
      expect(find.text('(E-11)'), findsOneWidget);
      expect(find.text('MONTH: OCT-26'), findsOneWidget);
      expect(_layout(t).report!.summary.workingDays, '25');
      final table = t.widget<Table>(
        find.byKey(const Key('employee_report_table')),
      );
      expect(table.children.length, 5);
      expect(
        t.getSize(find.byKey(const Key('employee_report_table'))).height,
        greaterThan(60),
      );
      expect(find.text('Present\n(Late)'), findsNothing);
      expect(find.text('Out Miss\n(Late)'), findsOneWidget);
      final pie = t.getRect(find.byKey(const Key('employee_pie')));
      final legend = t.getRect(find.byKey(const Key('employee_chart_legend')));
      final card = t.getRect(
        find
            .descendant(
              of: find.byKey(const Key('employee_chart_card')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(legend.left, greaterThan(pie.right));
      expect(legend.center.dy, closeTo(pie.center.dy, 1));
      expect(
        t.getCenter(find.byKey(const Key('employee_chart_group'))).dx,
        closeTo(card.center.dx, 1),
      );
      expect(pie.width, greaterThan(200));
      expect(card.height - pie.height, lessThan(70));
      await _capture(t, 'employee_attendance');
      await t.drag(
        find.byKey(const Key('employee_attendance_scroll')),
        const Offset(0, -370),
      );
      await t.pumpAndSettle();
      await _capture(t, 'employee_attendance_report');
      await _finish(t);
    },
  );
  _case(
    'three attendance slices enlarge the pie with the right legend centered in a fitted card',
    (t) async {
      final h =
          EmployeeAttendanceHarness()
            ..counts = [
              {
                'present': '12',
                'absent': '1',
                'leave': '0',
                'holiday_weekend': '6',
                'late_count': '0',
                'early_count': '0',
                'both_late_early_count': '0',
              },
            ];
      await _show(t, h, seed: employeeSeed);
      final pie = t.getRect(find.byKey(const Key('employee_pie'))),
          legend = t.getRect(find.byKey(const Key('employee_chart_legend'))),
          card = t.getRect(
            find
                .descendant(
                  of: find.byKey(const Key('employee_chart_card')),
                  matching: find.byType(Material),
                )
                .first,
          );
      expect(pie.width, greaterThan(210));
      expect(legend.left, greaterThan(pie.right));
      expect(legend.center.dy, closeTo(pie.center.dy, 1));
      expect(
        t.getCenter(find.byKey(const Key('employee_chart_group'))).dx,
        closeTo(card.center.dx, 1),
      );
      expect(card.height - pie.height, lessThan(70));
      await _capture(t, 'employee_attendance_three_slices_ui');
      await _finish(t);
    },
  );
  _case('month Cancel sends nothing, OK fetches the four report APIs only', (
    t,
  ) async {
    final h = EmployeeAttendanceHarness();
    await _show(t, h, seed: employeeSeed);
    h.transport.requests.clear();
    await _tap(t, 'employee_month');
    await _tap(t, 'employee_month_cancel');
    expect(h.hrRequests, isEmpty);
    await _tap(t, 'employee_month');
    final wheel = t.widget<ListWheelScrollView>(
      find.byKey(const Key('employee_month_wheel')),
    );
    (wheel.controller! as FixedExtentScrollController).jumpToItem(4);
    await t.pumpAndSettle();
    await _tap(t, 'employee_month_ok');
    expect(_layout(t).month.first, DateTime(2026, 9));
    expect(h.hrRequests.length, 4);
    expect(
      h.hrRequests.every(
        (r) => r.uri.queryParameters['first_date'] == '01-SEP-26',
      ),
      isTrue,
    );
    await _finish(t);
  });
  _case(
    'empty reports retain a centered No Data chart and the attendance summary',
    (t) async {
      final h =
          EmployeeAttendanceHarness()
            ..counts = []
            ..reports = []
            ..statuses = []
            ..working = [];
      await _show(t, h, seed: employeeSeed);
      expect(find.text('No Data'), findsOneWidget);
      expect(find.text('No Data Found'), findsOneWidget);
      expect(find.byKey(const Key('employee_report_table')), findsNothing);
      expect(find.byKey(const Key('employee_summary')), findsOneWidget);
      final pie = t.getRect(find.byKey(const Key('employee_pie')));
      final legend = t.getRect(find.byKey(const Key('employee_chart_legend')));
      final groupCenter = t.getCenter(
        find.byKey(const Key('employee_chart_group')),
      );
      final cardCenter = t.getCenter(
        find.byKey(const Key('employee_chart_card')),
      );
      expect(groupCenter.dx, closeTo(cardCenter.dx, 1));
      expect(legend.left, greaterThan(pie.right));
      expect(legend.center.dy, closeTo(pie.center.dy, 1));
      await _capture(t, 'employee_attendance_empty');
      await _finish(t);
    },
  );
  _case(
    'catalogue failure Retry repeats the entry chain and Exit returns to caller',
    (t) async {
      final h = EmployeeAttendanceHarness();
      var fail = true;
      h.transport.onGet = (uri) async {
        if (fail && uri.path.endsWith('getDivision')) {
          throw const AppFailure('Offline');
        }
        return h.respond(uri);
      };
      await _show(t, h);
      expect(find.text('Exit'), findsOneWidget);
      expect(find.textContaining('Offline'), findsOneWidget);
      fail = false;
      await _tap(t, 'employee_error_retry');
      expect(_layout(t).catalog!.divisions.length, 2);
      fail = true;
      await _tap(t, 'employee_branch');
      await _tap(t, 'employee_branch_option_0');
      await _tap(t, 'employee_error_cancel');
      expect(find.byType(EmployeeAttendanceScreen), findsNothing);
      await _finish(t);
    },
  );
  _case(
    'failed hierarchy stage Cancel restores usable controls and Retry repeats that stage',
    (t) async {
      final h = EmployeeAttendanceHarness();
      await _show(t, h);
      var fail = true;
      h.transport.onGet = (uri) async {
        if (fail && uri.path.endsWith('getDepartmentByDiv')) {
          throw const AppFailure('Department offline');
        }
        return h.respond(uri);
      };
      await _tap(t, 'employee_division');
      await _tap(t, 'employee_division_option_0');
      expect(find.text('Cancel'), findsOneWidget);
      await _tap(t, 'employee_error_cancel');
      expect(_layout(t).waiting, isFalse);
      expect(_layout(t).catalog!.employee, isNull);
      await _tap(t, 'employee_division');
      await _tap(t, 'employee_division_option_0');
      fail = false;
      h.transport.requests.clear();
      await _tap(t, 'employee_error_retry');
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getDepartmentByDiv',
      ]);
      await _finish(t);
    },
  );
  _case(
    'failed employee report cannot expose previous data and retries four reads',
    (t) async {
      final h = EmployeeAttendanceHarness();
      await _show(t, h, seed: employeeSeed);
      var fail = true;
      h.transport.onGet = (uri) async {
        if (fail && uri.path.endsWith('getAttStatus')) {
          throw const AppFailure('Status offline');
        }
        return h.respond(uri);
      };
      await _tap(t, 'employee_employee');
      await _tap(t, 'employee_employee_option_1');
      expect(_layout(t).report, isNull);
      expect(find.byKey(const Key('employee_identity')), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);
      fail = false;
      h.transport.requests.clear();
      await _tap(t, 'employee_error_retry');
      expect(h.hrRequests.length, 4);
      expect(_layout(t).catalog!.employee!.id, '12');
      await _finish(t);
    },
  );
  _case(
    'loading ignores duplicate filter callbacks and Back until response settles',
    (t) async {
      final h = EmployeeAttendanceHarness();
      await _show(t, h);
      final old = _layout(t);
      final response = Completer<JsonMap>();
      h.transport.onGet =
          (uri) =>
              uri.path.endsWith('getDepartmentByDiv')
                  ? response.future
                  : h.respond(uri);
      old.onDivision(old.catalog!.divisions.first);
      await t.pump();
      old.onDivision(old.catalog!.divisions.last);
      old.onBack();
      await t.pump();
      expect(find.byType(EmployeeAttendanceScreen), findsOneWidget);
      expect(_layout(t).catalog!.division!.id, '1');
      response.complete({'count': 0, 'items': <Object?>[]});
      await t.pumpAndSettle();
      expect(_layout(t).waiting, isFalse);
      await _finish(t);
    },
  );
  _case(
    'foreground return hides old data and rebuilds selected employee with no login log',
    (t) async {
      final h = EmployeeAttendanceHarness();
      await _show(t, h, seed: employeeSeed);
      h.transport.requests.clear();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      expect(find.byKey(const Key('employee_identity')), findsNothing);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(h.hrRequests.length, 9);
      expect(_layout(t).catalog!.employee!.id, '11');
      expect(h.transport.requests.any((r) => r.method == 'POST'), isFalse);
      await _finish(t);
    },
  );
  _case(
    'background closes month picker and does not submit its unconfirmed month',
    (t) async {
      final h = EmployeeAttendanceHarness();
      await _show(t, h, seed: employeeSeed);
      await _tap(t, 'employee_month');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('employee_month_dialog')), findsNothing);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(_layout(t).month.first, DateTime(2026, 10));
      await _finish(t);
    },
  );
  _case('logout closes an open employee dropdown and removes employee data', (
    t,
  ) async {
    final h = EmployeeAttendanceHarness();
    await _show(t, h, seed: employeeSeed);
    await _tap(t, 'employee_employee');
    await h.auth.logout();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(h.auth.stage, AuthStage.signedOut);
    expect(find.byKey(const Key('employee_employee_option_0')), findsNothing);
    expect(find.byKey(const Key('employee_identity')), findsNothing);
    await _finish(t);
  });
  _case('revoked access on month operation blocks reads and clears report', (
    t,
  ) async {
    final h = EmployeeAttendanceHarness();
    await _show(t, h, seed: employeeSeed);
    h.adminData['usr_mob_app_access'] = '0';
    h.transport.requests.clear();
    await _tap(t, 'employee_month');
    await t.tap(find.byKey(const Key('employee_month_ok')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(h.auth.stage, isNot(AuthStage.authenticated));
    expect(h.hrRequests, isEmpty);
    expect(find.byKey(const Key('employee_identity')), findsNothing);
    await _finish(t);
  });
  _case(
    'an obsolete pending employee response cannot replace the resumed report or continue its chain',
    (t) async {
      final h = EmployeeAttendanceHarness();
      await _show(t, h, seed: employeeSeed);
      final pending = Completer<JsonMap>();
      var first = true;
      h.transport.onGet = (uri) {
        if (first && uri.path.endsWith('getAttendanceCountEmp')) {
          first = false;
          return pending.future;
        }
        return h.respond(uri);
      };
      h.transport.requests.clear();
      _layout(t).onEmployee(_layout(t).catalog!.employees[1]);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(_layout(t).catalog!.employee!.id, '12');
      final report = _layout(t).report;
      final calls = h.hrRequests.length;
      pending.complete({
        'count': 1,
        'items': <JsonMap>[
          {
            for (final key in [
              'present',
              'absent',
              'leave',
              'holiday_weekend',
              'late_count',
              'early_count',
              'both_late_early_count',
            ])
              key: '777',
          },
        ],
      });
      await t.pumpAndSettle();
      expect(identical(_layout(t).report, report), isTrue);
      expect(h.hrRequests.length, calls);
      await _finish(t);
    },
  );
  _case(
    'large-text month picker offers the current and five previous months and submits by ID',
    (t) async {
      final h = EmployeeAttendanceHarness(clock: DateTime(2027, 1, 12));
      await _show(t, h, seed: employeeSeed, textScale: 2.4);
      await _tap(t, 'employee_month');
      expect(find.text('August 2026'), findsOneWidget);
      expect(find.text('January 2027'), findsOneWidget);
      await _tap(t, 'employee_month_2026_8');
      await _tap(t, 'employee_month_ok');
      expect(_layout(t).month.first, DateTime(2026, 8));
      await _finish(t);
    },
  );
  _case(
    'logout from the live Dashboard Portal HR Employee stack closes its month dialog and returns to Login',
    (t) async {
      final h = EmployeeAttendanceHarness();
      await h.signIn();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpWidget(
        DocDiaryApp(
          auth: h.auth,
          initializeOnStart: false,
          dashboard: DashboardRepository(h.transport, now: () => h.now),
          dashboardServices: DashboardServices(),
        ),
      );
      await t.pumpAndSettle();
      await _tap(t, 'dashboard_nav_management');
      await _tap(t, 'management_humanResources');
      await _tap(t, 'hr_menu');
      await _tap(t, 'hr_menu_employeeAttendance');
      await _cascade(t);
      await _tap(t, 'employee_month');
      await h.auth.logout();
      await t.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(EmployeeAttendanceScreen), findsNothing);
      expect(find.byKey(const Key('employee_month_dialog')), findsNothing);
      await _finish(t);
    },
  );
  _case('HR drawer opens built-in Emp Wise Attendance and Back refreshes HR', (
    t,
  ) async {
    final h = EmployeeAttendanceHarness();
    await _show(t, h, hr: true);
    await _tap(t, 'hr_menu');
    await _tap(t, 'hr_menu_employeeAttendance');
    expect(find.byType(EmployeeAttendanceScreen), findsOneWidget);
    final count = h.hrRequests.length;
    await _tap(t, 'employee_attendance_back');
    expect(find.byType(HrDashboardScreen), findsOneWidget);
    expect(h.hrRequests.length, greaterThan(count));
    await _finish(t);
  });
  _case('donut rotation and slice highlighting do not trigger API requests', (
    t,
  ) async {
    final h = EmployeeAttendanceHarness();
    await _show(t, h, seed: employeeSeed);
    final count = h.hrRequests.length;
    await t.drag(find.byKey(const Key('employee_pie')), const Offset(25, 15));
    await t.pumpAndSettle();
    await t.tapAt(
      t.getCenter(find.byKey(const Key('employee_pie'))) + const Offset(50, 0),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(h.hrRequests.length, count);
    await _finish(t);
  });
  _case(
    'small, landscape and large-text layouts render reports without overflow',
    (t) async {
      for (final entry in [
        (const Size(320, 568), 1.0),
        (const Size(568, 320), 1.0),
        (const Size(320, 568), 2.4),
      ]) {
        final h = EmployeeAttendanceHarness();
        await _show(
          t,
          h,
          seed: employeeSeed,
          size: entry.$1,
          textScale: entry.$2,
        );
        await t.drag(
          find.byKey(const Key('employee_attendance_scroll')),
          const Offset(0, -700),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await _finish(t);
      }
    },
  );
}

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_services.dart';
import 'package:docdiary_ios/features/hr/daily_attendance/daily_attendance_screen.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_screen.dart';
import 'package:docdiary_ios/features/hr/employee_attendance/employee_attendance_screen.dart';
import 'package:docdiary_ios/features/hr/employee_attendance/native_employee_attendance_layout.dart';
import 'package:docdiary_ios/features/hr/daily_attendance/native_daily_attendance_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'daily_attendance_test_support.dart';
import 'employee_attendance_test_support.dart';

void _case(String label, Future<void> Function(WidgetTester) body) {
  testWidgets(label, (tester) async {
    final original = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = original;
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

NativeDailyAttendanceLayout _layout(WidgetTester t) =>
    t.widget(find.byType(NativeDailyAttendanceLayout));
Future<void> _show(
  WidgetTester t,
  AttendanceHarness h, {
  DashboardDestinationBuilder? builder,
  Size size = const Size(393, 852),
  double textScale = 1,
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
  await t.pumpWidget(
    RepaintBoundary(
      key: const Key('daily_capture'),
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
                    key: const Key('open_daily'),
                    onPressed:
                        () => unawaited(
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder:
                                  (_) => DailyAttendanceScreen(
                                    auth: h.auth,
                                    repository: h.daily,
                                    destinationBuilder: builder,
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
  await _tap(t, 'open_daily');
}

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
  expect(t.takeException(), isNull);
}

Future<void> _capture(WidgetTester t, String name) async {
  final directory = Platform.environment['DOC_DAILY_CAPTURE_DIR'];
  if (directory == null) return;
  await t.runAsync(() async {
    final context = t.element(find.byType(NativeDailyAttendanceLayout));
    await precacheImage(
      const AssetImage('assets/images/hospital_icon.png'),
      context,
    );
  });
  await t.pumpAndSettle();
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('daily_capture')),
  );
  await t.runAsync(() async {
    final bitmap = await boundary.toImage(pixelRatio: 1);
    final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
    bitmap.dispose();
    final file = File('$directory/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
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

  _case('Daily Attendance entry shows native columns rows count and date', (
    t,
  ) async {
    final h = AttendanceHarness();
    await _show(t, h);
    expect(find.text('Daily Attendance'), findsOneWidget);
    for (final label in [
      'EMP  NAME',
      'SHIFT',
      'IN TIME',
      'OUT TIME',
      'STATUS',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Same Name'), findsNWidgets(2));
    expect(find.text('(Late)'), findsOneWidget);
    expect(find.text('(Early)'), findsOneWidget);
    expect(find.text('(Example Branch)'), findsNWidgets(2));
    expect(_layout(t).filter.employeeCount(_layout(t).data!), 3);
    expect(_layout(t).selectedDate, DateTime(2026, 10, 20));
    expect(h.dailyRequests.length, 5);
    await _capture(t, 'daily_attendance');
    await _finish(t);
  });
  _case(
    'Division Department Employee cascade uses duplicate-name IDs and resets children',
    (t) async {
      final h = AttendanceHarness();
      await _show(t, h);
      final count = h.dailyRequests.length;
      await _tap(t, 'daily_division');
      await _tap(t, 'daily_division_option_1');
      expect(_layout(t).filter.division, '1');
      expect(_layout(t).filter.employeeEnabled, isFalse);
      await _tap(t, 'daily_department');
      await _tap(t, 'daily_department_option_1');
      await _tap(t, 'daily_employee');
      await _tap(t, 'daily_employee_option_2');
      expect(_layout(t).filter.employee, '12');
      expect(find.text('Out Miss'), findsOneWidget);
      expect(_layout(t).filter.employeeCount(_layout(t).data!), 2);
      expect(h.dailyRequests.length, count);
      await _tap(t, 'daily_division');
      await _tap(t, 'daily_division_option_2');
      expect(_layout(t).filter.department, '');
      expect(_layout(t).filter.employee, '');
      expect(_layout(t).filter.employeeEnabled, isFalse);
      expect(find.text('Employee C'), findsOneWidget);
      await _tap(t, 'daily_division');
      await _tap(t, 'daily_division_option_0');
      expect(_layout(t).filter.departmentEnabled, isFalse);
      expect(_layout(t).filter.employeeCount(_layout(t).data!), 3);
      await _finish(t);
    },
  );
  _case(
    'branch selection reloads correct endpoints and None resets global scope',
    (t) async {
      final h = AttendanceHarness();
      await _show(t, h);
      await _tap(t, 'daily_division');
      await _tap(t, 'daily_division_option_1');
      h.transport.requests.clear();
      await _tap(t, 'daily_branch');
      await t.tap(find.text('Example Branch'));
      await t.pumpAndSettle();
      expect(_layout(t).branchName, 'Example Branch');
      expect(_layout(t).filter.division, '');
      expect(h.dailyRequests.length, 4);
      expect(
        h.dailyRequests.every((r) => r.uri.queryParameters['p_coa_id'] == '2'),
        isTrue,
      );
      await _tap(t, 'daily_branch');
      await t.tap(find.text('None'));
      await t.pumpAndSettle();
      expect(_layout(t).branchName, 'None');
      expect(h.dailyRequests.length, 9);
      await _finish(t);
    },
  );
  _case('month arrows reload attendance only and stop at range boundaries', (
    t,
  ) async {
    final h = AttendanceHarness();
    await _show(t, h);
    h.transport.requests.clear();
    await _tap(t, 'daily_previous_month');
    expect(_layout(t).selectedDate, DateTime(2026, 9, 20));
    await _tap(t, 'daily_previous_month');
    expect(_layout(t).selectedDate, DateTime(2026, 8, 20));
    await _tap(t, 'daily_previous_month');
    expect(h.dailyRequests.length, 2);
    await _tap(t, 'daily_next_month');
    await _tap(t, 'daily_next_month');
    expect(_layout(t).selectedDate, DateTime(2026, 10, 20));
    expect(h.dailyRequests.length, 4);
    expect(
      h.dailyRequests.every((r) => r.uri.path.endsWith('getDailyAttendance')),
      isTrue,
    );
    await _finish(t);
  });
  _case('horizontal date swipe selects a date and requests its attendance', (
    t,
  ) async {
    final h = AttendanceHarness();
    await _show(t, h);
    h.transport.requests.clear();
    await t.drag(find.byKey(const Key('daily_dates')), const Offset(160, 0));
    await t.pumpAndSettle();
    expect(_layout(t).selectedDate.isBefore(h.now), isTrue);
    expect(h.dailyRequests.length, 1);
    await _finish(t);
  });
  _case('date change retains active filters', (t) async {
    final h = AttendanceHarness();
    await _show(t, h);
    await _tap(t, 'daily_division');
    await _tap(t, 'daily_division_option_1');
    await _tap(t, 'daily_department');
    await _tap(t, 'daily_department_option_1');
    await _tap(t, 'daily_employee');
    await _tap(t, 'daily_employee_option_2');
    _layout(t).onDate(DateTime(2026, 10, 19));
    await t.pumpAndSettle();
    expect(_layout(t).filter.employee, '12');
    expect(find.text('Out Miss'), findsOneWidget);
    await _finish(t);
  });
  _case('No Data message does not replace catalog employee count', (t) async {
    final h = AttendanceHarness()..records = [];
    await _show(t, h);
    expect(find.byKey(const Key('daily_no_data')), findsOneWidget);
    expect(_layout(t).filter.employeeCount(_layout(t).data!), 3);
    await _capture(t, 'daily_attendance_empty');
    await _finish(t);
  });
  _case('request failure Retry repeats the failed date operation', (t) async {
    final h = AttendanceHarness();
    await _show(t, h);
    var fail = true;
    h.transport.onGet = (uri) async {
      if (uri.path.endsWith('getDailyAttendance') && fail) {
        throw const AppFailure('Offline');
      }
      return h.respond(uri);
    };
    h.transport.requests.clear();
    _layout(t).onDate(DateTime(2026, 10, 19));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('daily_error')), findsOneWidget);
    expect(find.textContaining('Offline'), findsOneWidget);
    fail = false;
    await _tap(t, 'daily_error_retry');
    expect(h.dailyRequests.length, 2);
    expect(
      h.dailyRequests.every((r) => r.uri.path.endsWith('getDailyAttendance')),
      isTrue,
    );
    expect(_layout(t).selectedDate, DateTime(2026, 10, 19));
    await _finish(t);
  });
  _case('initial failure Cancel returns to caller', (t) async {
    final h = AttendanceHarness();
    final respond = h.respond;
    h.transport.onGet = (uri) async {
      if (uri.path.endsWith('getBranches')) throw const AppFailure('Offline');
      return respond(uri);
    };
    await _show(t, h);
    expect(find.byKey(const Key('daily_error')), findsOneWidget);
    await _tap(t, 'daily_error_cancel');
    expect(find.byKey(const Key('open_daily')), findsOneWidget);
    expect(find.byType(DailyAttendanceScreen), findsNothing);
    await _finish(t);
  });
  _case(
    'late response and duplicate callbacks cannot overwrite a loading operation',
    (t) async {
      final h = AttendanceHarness();
      await _show(t, h);
      final old = _layout(t);
      final response = Completer<JsonMap>();
      h.transport.onGet =
          (uri) =>
              uri.path.endsWith('getDailyAttendance')
                  ? response.future
                  : h.respond(uri);
      h.transport.requests.clear();
      old.onDate(DateTime(2026, 10, 19));
      await t.pump();
      old.onDate(DateTime(2026, 10, 18));
      await t.pump();
      expect(h.dailyRequests.length, 1);
      expect(find.byKey(const Key('daily_loading')), findsOneWidget);
      response.complete({'count': 0, 'items': <Object?>[]});
      await t.pumpAndSettle();
      expect(_layout(t).selectedDate, DateTime(2026, 10, 19));
      await _finish(t);
    },
  );
  _case('revoked HR access clears rows and sends no attendance request', (
    t,
  ) async {
    final h = AttendanceHarness();
    await _show(t, h);
    h.adminData['hr_dashboard'] = '0';
    h.transport.requests.clear();
    _layout(t).onDate(DateTime(2026, 10, 19));
    await t.pumpAndSettle();
    expect(find.textContaining('access is not available'), findsOneWidget);
    expect(find.text('Same Name'), findsNothing);
    expect(h.dailyRequests, isEmpty);
    await _finish(t);
  });
  _case('background hides data and resume revalidates without login writes', (
    t,
  ) async {
    final h = AttendanceHarness();
    await _show(t, h);
    h.transport.requests.clear();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    expect(find.byKey(const Key('daily_loading')), findsOneWidget);
    h.now = DateTime(2026, 10, 21);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(h.dailyRequests.length, 5);
    expect(h.posts, isEmpty);
    expect(_layout(t).calendar.last, DateTime(2026, 10, 21));
    await _finish(t);
  });
  _case('row custom destination receives exact employee and branch extras', (
    t,
  ) async {
    final h = AttendanceHarness();
    DashboardRoute? selected;
    await _show(
      t,
      h,
      builder: (context, route) {
        selected = route;
        return Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('employee_back'),
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ),
        );
      },
    );
    await _tap(t, 'daily_row_0');
    expect(selected!.module, DashboardModule.hrEmployeeAttendance);
    expect(selected!.extras, {
      'DIV_ID': '1',
      'DEPT_ID': '10',
      'DESIG_ID': '7',
      'EMP_ID': '11',
      'COA_ID': '',
    });
    final count = h.dailyRequests.length;
    await _tap(t, 'employee_back');
    expect(h.dailyRequests.length, count + 5);
    await _finish(t);
  });
  _case(
    'employee row opens the built-in seeded Emp Wise Attendance and returns to Daily Attendance',
    (t) async {
      final h = EmployeeAttendanceHarness();
      await _show(t, h);
      await _tap(t, 'daily_row_0');
      expect(find.byType(EmployeeAttendanceScreen), findsOneWidget);
      final employee = t.widget<NativeEmployeeAttendanceLayout>(
        find.byType(NativeEmployeeAttendanceLayout),
      );
      expect(employee.catalog!.employee!.id, '11');
      expect(employee.catalog!.division!.id, '1');
      expect(employee.catalog!.department!.id, '10');
      expect(employee.catalog!.designation!.id, '7');
      expect(employee.report!.rows.length, 4);
      await _tap(t, 'employee_attendance_back');
      expect(find.byType(DailyAttendanceScreen), findsOneWidget);
      await _finish(t);
    },
  );
  _case(
    'live Dashboard Portal HR pie opens default Daily Attendance and Back refreshes HR',
    (t) async {
      final h = AttendanceHarness();

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
      await _tap(t, 'hr_pie');
      expect(find.byType(DailyAttendanceScreen), findsOneWidget);
      expect(h.dailyRequests.length, 5);
      await _tap(t, 'daily_attendance_back');
      expect(find.byType(HrDashboardScreen), findsOneWidget);
      expect(
        h.hrRequests
            .where((r) => r.uri.path.endsWith('getDeptEmpCount'))
            .length,
        2,
      );
      await _finish(t);
    },
  );
  _case('live HR drawer opens the same default Daily Attendance screen', (
    t,
  ) async {
    final h = AttendanceHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpWidget(
      MaterialApp(
        theme: docDiaryTheme(),
        home: HrDashboardScreen(auth: h.auth, repository: h.hr),
      ),
    );
    await t.pumpAndSettle();
    await _tap(t, 'hr_menu');
    await _tap(t, 'hr_menu_dailyAttendance');
    expect(find.byType(DailyAttendanceScreen), findsOneWidget);
    await _finish(t);
  });
  _case('all native status colors remain exact', (t) async {
    expect(dailyAttendanceStatusColor('Out Miss'), const Color(0xffc23616));
    expect(dailyAttendanceStatusColor('In Leave'), const Color(0xff8f8f8f));
    expect(dailyAttendanceStatusColor('Off Day'), const Color(0xff80e0ff));
    expect(
      dailyAttendanceStatusColor('Present on Leave Day'),
      const Color(0xff4080c0),
    );
    expect(
      dailyAttendanceStatusColor('Present on Off Day'),
      const Color(0xffe0c080),
    );
    expect(dailyAttendanceStatusColor('Absent'), const Color(0xffc000ff));
    expect(dailyAttendanceStatusColor('Present'), const Color(0xff00c080));
    expect(dailyAttendanceStatusColor('Unexpected'), const Color(0xffced6e0));
  });
  for (final scenario in [
    (const Size(320, 568), 1.0),
    (const Size(320, 568), 2.5),
    (const Size(852, 393), 1.5),
  ]) {
    _case(
      'small/landscape/large text ${scenario.$1} ${scenario.$2} has no overflow',
      (t) async {
        final h = AttendanceHarness();
        await _show(t, h, size: scenario.$1, textScale: scenario.$2);
        await t.drag(
          find.byKey(const Key('daily_attendance_scroll')),
          const Offset(0, -500),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await _finish(t);
      },
    );
  }
}

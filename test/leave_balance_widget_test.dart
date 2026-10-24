import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_screen.dart';
import 'package:docdiary_ios/features/hr/leave_balance/leave_balance_models.dart';
import 'package:docdiary_ios/features/hr/leave_balance/leave_balance_screen.dart';
import 'package:docdiary_ios/features/hr/leave_balance/native_leave_balance_layout.dart';
import 'package:docdiary_ios/features/hr/leave_record/leave_record_screen.dart';
import 'package:docdiary_ios/features/hr/leave_record/native_leave_record_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'leave_balance_test_support.dart';

void _case(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (t) async {
    final shadows = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await body(t);
    } finally {
      debugDisableShadows = shadows;
    }
  });
}

Future<void> _tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  final root = find.byKey(const Key('leave_balance_scroll'));
  if (f.evaluate().isEmpty && root.evaluate().isNotEmpty) {
    await t.scrollUntilVisible(
      f,
      150,
      maxScrolls: 100,
      scrollable:
          find.descendant(of: root, matching: find.byType(Scrollable)).first,
    );
  }
  if (f.hitTestable().evaluate().isEmpty) {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
  }
  await t.tap(f);
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> _show(
  WidgetTester t,
  LeaveBalanceHarness h, {
  LeaveBalanceSeed seed = const LeaveBalanceSeed(),
  Size size = const Size(393, 852),
  double scale = 1,
  bool hr = false,
  bool record = false,
  bool signIn = true,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPadding);
  addTearDown(h.auth.dispose);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  if (signIn) {
    await h.signIn();
  }
  h.transport.requests.clear();
  await t.pumpWidget(
    RepaintBoundary(
      key: const Key('balance_capture'),
      child: MaterialApp(
        theme: docDiaryTheme(),
        debugShowCheckedModeBanner: false,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    key: const Key('open_balance'),
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
                                          : record
                                          ? LeaveRecordScreen(
                                            auth: h.auth,
                                            repository: h.leaveRecord,
                                          )
                                          : LeaveBalanceScreen(
                                            auth: h.auth,
                                            repository: h.leaveBalance,
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
  await _tap(t, 'open_balance');
}

NativeLeaveBalanceLayout _layout(WidgetTester t) =>
    t.widget(find.byType(NativeLeaveBalanceLayout));
bool _enabled(WidgetTester t, String name) =>
    t
        .widget<PopupMenuButton<LeaveBalanceChoice>>(
          find.byKey(Key('leave_balance_$name')),
        )
        .enabled;
Future<void> _select(WidgetTester t, String name, int index) async {
  await _tap(t, 'leave_balance_$name');
  await _tap(t, 'leave_balance_${name}_option_$index');
}

Future<void> _employee(WidgetTester t, {int index = 0}) async {
  await _select(t, 'division', 0);
  await _select(t, 'department', 0);
  await _select(t, 'designation', 0);
  await _select(t, 'employee', index);
}

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
  expect(t.takeException(), isNull);
}

Future<void> _capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_LEAVE_BALANCE_CAPTURE_DIR'];
  if (dir == null) return;
  await t.runAsync(
    () async => await precacheImage(
      const AssetImage('assets/images/hospital_icon.png'),
      t.element(find.byType(NativeLeaveBalanceLayout)),
    ),
  );
  await t.pumpAndSettle();
  final box = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('balance_capture')),
  );
  await t.runAsync(() async {
    final bitmap = await box.toImage(pixelRatio: 1);
    final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
    bitmap.dispose();
    final f = File('$dir/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry
        in <String, List<String>>{
          'Poppins': [
            'Poppins-Regular.ttf',
            'Poppins-SemiBold.ttf',
            'Poppins-Bold.ttf',
          ],
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
          'Archivo': ['Archivo[wdth,wght].ttf'],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
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
    'initial native filters have shared outlines and disabled gray with no report',
    (t) async {
      final h = LeaveBalanceHarness();
      await _show(t, h);
      expect(find.text('Leave Balance'), findsOneWidget);
      expect(_enabled(t, 'division'), isTrue);
      for (final name in ['department', 'designation', 'employee']) {
        expect(_enabled(t, name), isFalse);
        final field = t.widget<InputDecorator>(
          find.descendant(
            of: find.byKey(Key('leave_balance_$name')),
            matching: find.byType(InputDecorator),
          ),
        );
        expect(field.decoration.fillColor, const Color(0xfff5f5f5));
        expect(field.decoration.labelStyle!.fontFamily, 'OpenSans');
      }
      expect(find.byKey(const Key('leave_balance_chart_card')), findsNothing);
      expect(h.hrRequests.length, 2);
      expect(h.posts, isEmpty);
      await _capture(t, 'leave_balance_filters');
      await _finish(t);
    },
  );
  _case(
    'selection cascades via APIs and identical names use selected employee ID',
    (t) async {
      final h = LeaveBalanceHarness();
      await _show(t, h);
      await _employee(t, index: 1);
      expect(_layout(t).catalog!.employee!.id, '12');
      expect(_layout(t).report!.rows.length, 2);
      expect(h.hrRequests.last.uri.queryParameters, {
        'p_emp_id': '12',
        'now_date': '31-DEC-26',
      });
      expect(find.text('YEAR: 2026'), findsOneWidget);
      expect(find.text('Casual Leave(CL)'), findsOneWidget);
      expect(find.text('Transferred'), findsOneWidget);
      await _capture(t, 'leave_balance_report');
      await _finish(t);
    },
  );
  _case(
    'branch change resets ancestry, scoped endpoint is one read and None is two',
    (t) async {
      final h = LeaveBalanceHarness();
      await _show(t, h, seed: leaveBalanceSeed);
      h.transport.requests.clear();
      await _select(t, 'branch', 2);
      expect(h.hrRequests.single.uri.pathSegments.last, 'getDivisionWithCoa');
      expect(_layout(t).catalog!.employee, isNull);
      expect(_enabled(t, 'department'), isFalse);
      h.transport.requests.clear();
      await _select(t, 'branch', 0);
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getBranches',
        'getDivision',
      ]);
      await _finish(t);
    },
  );
  _case('changing an ancestor hides identity and clears all lower selections', (
    t,
  ) async {
    final h = LeaveBalanceHarness();
    await _show(t, h, seed: leaveBalanceSeed);
    await _select(t, 'division', 0);
    expect(_layout(t).catalog!.department, isNull);
    expect(_layout(t).report, isNull);
    expect(_enabled(t, 'designation'), isFalse);
    await _finish(t);
  });
  _case('year Cancel has no IO and OK reloads exactly table then chart', (
    t,
  ) async {
    final h = LeaveBalanceHarness();
    await _show(t, h, seed: leaveBalanceSeed);
    h.transport.requests.clear();
    await _tap(t, 'leave_balance_year');
    await _capture(t, 'leave_balance_year');
    await _tap(t, 'leave_balance_year_cancel');
    expect(h.transport.requests, isEmpty);
    await _tap(t, 'leave_balance_year');
    await _tap(t, 'leave_balance_year_2025');
    await _tap(t, 'leave_balance_year_ok');
    expect(_layout(t).year.year, 2025);
    expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
      'getLeaveBalance',
      'getLeaveChartData',
    ]);
    expect(
      h.hrRequests.every(
        (r) => r.uri.queryParameters['now_date'] == '31-DEC-25',
      ),
      isTrue,
    );
    await _finish(t);
  });
  _case('no-data table and chart each retain their native empty state', (
    t,
  ) async {
    final h =
        LeaveBalanceHarness()
          ..balances = []
          ..chartRows = [];
    await _show(t, h, seed: leaveBalanceSeed);
    expect(find.text('No chart data available.'), findsOneWidget);
    expect(find.text('No Data Found'), findsOneWidget);
    expect(find.text('Leave Category'), findsNothing);
    await _capture(t, 'leave_balance_empty');
    await _finish(t);
  });
  _case(
    'initial read failure Retry and Exit use native ownership and no writes',
    (t) async {
      final h = LeaveBalanceHarness();
      var fail = true;
      h.transport.onGet = (uri) async {
        if (fail && uri.path.endsWith('/getDivision')) {
          throw const AppFailure('Offline');
        }
        return h.respondBalance(uri);
      };
      await _show(t, h);
      expect(find.text('Exit'), findsOneWidget);
      fail = false;
      await _tap(t, 'leave_balance_error_retry');
      expect(_layout(t).catalog, isNotNull);
      await _finish(t);
      final h2 = LeaveBalanceHarness();
      h2.transport.onGet = (uri) async {
        if (uri.path.endsWith('/getBranches')) {
          throw const AppFailure('Offline');
        }
        return h2.respondBalance(uri);
      };
      await _show(t, h2);
      await _tap(t, 'leave_balance_error_cancel');
      expect(find.byType(LeaveBalanceScreen), findsNothing);
      await _finish(t);
    },
  );
  _case(
    'cascade error Cancel retains usable controls and Retry repeats only failed stage',
    (t) async {
      final h = LeaveBalanceHarness();
      var fail = true;
      h.transport.onGet = (uri) async {
        if (fail && uri.path.endsWith('/getDepartmentByDiv')) {
          throw const AppFailure('Department offline');
        }
        return h.respondBalance(uri);
      };
      await _show(t, h);
      await _select(t, 'division', 0);
      expect(find.text('Cancel'), findsOneWidget);
      await _tap(t, 'leave_balance_error_cancel');
      expect(_enabled(t, 'division'), isTrue);
      await _select(t, 'division', 0);
      h.transport.requests.clear();
      fail = false;
      await _tap(t, 'leave_balance_error_retry');
      expect(h.hrRequests.single.uri.pathSegments.last, 'getDepartmentByDiv');
      await _finish(t);
    },
  );
  _case(
    'chart error Retry reloads table and chart, Cancel hides failed report',
    (t) async {
      final h = LeaveBalanceHarness();
      var fail = true;
      h.transport.onGet = (uri) async {
        if (fail && uri.path.endsWith('/getLeaveChartData')) {
          throw const AppFailure('Chart offline');
        }
        return h.respondBalance(uri);
      };
      await _show(t, h);
      await _employee(t);
      h.transport.requests.clear();
      fail = false;
      await _tap(t, 'leave_balance_error_retry');
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getLeaveBalance',
        'getLeaveChartData',
      ]);
      expect(_layout(t).report, isNotNull);
      fail = true;
      await _select(t, 'employee', 0);
      await _tap(t, 'leave_balance_error_cancel');
      expect(_layout(t).report, isNull);
      expect(_enabled(t, 'employee'), isTrue);
      await _finish(t);
    },
  );
  _case(
    'pending report blocks back, duplicate callbacks and late reply after logout',
    (t) async {
      final h = LeaveBalanceHarness();
      await _show(t, h, seed: leaveBalanceSeed);
      final gate = Completer<JsonMap>();
      h.transport.onGet =
          (uri) =>
              uri.path.endsWith('/getLeaveBalance')
                  ? gate.future
                  : h.respondBalance(uri);
      final ui = _layout(t);
      ui.onEmployee(ui.catalog!.employees.first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('leave_balance_loading')), findsOneWidget);
      ui.onDivision(ui.catalog!.divisions.first);
      await t.pump();
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.byType(LeaveBalanceScreen), findsOneWidget);
      await h.auth.logout();
      gate.complete({'count': 0});
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(_layout(t).catalog, isNull);
      expect(_layout(t).report, isNull);
      await _finish(t);
    },
  );
  _case(
    'background closes year dialog and resume restores selected employee and year',
    (t) async {
      final h = LeaveBalanceHarness();
      await _show(t, h, seed: leaveBalanceSeed);
      await _tap(t, 'leave_balance_year');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('leave_balance_year_dialog')), findsNothing);
      expect(_layout(t).waiting, isTrue);
      h.transport.requests.clear();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(_layout(t).catalog!.employee!.id, '11');
      expect(h.hrRequests.length, 7);
      await _finish(t);
    },
  );
  _case('background closes owned filter popup without a stale callback', (
    t,
  ) async {
    final h = LeaveBalanceHarness();
    await _show(t, h);
    await _tap(t, 'leave_balance_division');
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    await t.pump();
    await t.pump();
    expect(
      find.byKey(const Key('leave_balance_division_option_0')),
      findsNothing,
    );
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    await _finish(t);
  });
  _case('late report reply cannot replace a fresh foreground report', (
    t,
  ) async {
    final h = LeaveBalanceHarness();
    await _show(t, h, seed: leaveBalanceSeed);
    final gate = Completer<JsonMap>();
    h.transport.onGet =
        (uri) =>
            uri.path.endsWith('/getLeaveBalance')
                ? gate.future
                : h.respondBalance(uri);
    final ui = _layout(t);
    ui.onEmployee(ui.catalog!.employees.first);
    await t.pump();
    await t.pump();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    h.balances = [];
    h.chartRows = [];
    h.transport.onGet = h.respondBalance;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(_layout(t).report!.rows, isEmpty);
    gate.complete({
      'count': 1,
      'items': [balanceRow()],
    });
    await t.pumpAndSettle();
    expect(_layout(t).report!.rows, isEmpty);
    expect(find.byKey(const Key('leave_balance_no_data')), findsOneWidget);
    await _finish(t);
  });
  _case('HR drawer opens real Leave Balance and Back refreshes HR', (t) async {
    final h = LeaveBalanceHarness();
    await _show(t, h, hr: true);
    await _tap(t, 'hr_menu');
    await _tap(t, 'hr_menu_leaveBalance');
    expect(find.byType(LeaveBalanceScreen), findsOneWidget);
    h.transport.requests.clear();
    await _tap(t, 'leave_balance_back');
    expect(find.byType(HrDashboardScreen), findsOneWidget);
    expect(
      h.hrRequests.any((r) => r.uri.path.endsWith('/getDeptEmpCount')),
      isTrue,
    );
    await _finish(t);
  });
  _case(
    'processed Leave Record opens selected employee balance and Back refreshes records',
    (t) async {
      final h = LeaveBalanceHarness();
      await _show(t, h, record: true);
      await _tap(t, 'leave_record_row_42');
      expect(find.byType(LeaveBalanceScreen), findsOneWidget);
      expect(_layout(t).catalog!.employee!.id, '12');
      expect(_layout(t).year.lastDate, '31-DEC-26');
      h.transport.requests.clear();
      await _tap(t, 'leave_balance_back');
      expect(find.byType(LeaveRecordScreen), findsOneWidget);
      expect(h.hrRequests.length, 5);
      expect(
        t
            .widget<NativeLeaveRecordLayout>(
              find.byType(NativeLeaveRecordLayout),
            )
            .data!
            .rows
            .length,
        4,
      );
      await _finish(t);
    },
  );
  _case('signed out entry performs no reads', (t) async {
    final h = LeaveBalanceHarness();
    await _show(t, h, signIn: false);
    expect(h.transport.requests, isEmpty);
    await _finish(t);
  });
  for (final key in [
    'hr_dashboard',
    'usr_mob_forced_log_out_flag',
    'usr_mob_app_access',
    'exp_date',
  ]) {
    _case('revoked $key prevents report reads on foreground', (t) async {
      final h = LeaveBalanceHarness();
      await _show(t, h, seed: leaveBalanceSeed);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      h.adminData[key] =
          key == 'usr_mob_forced_log_out_flag'
              ? '1'
              : key == 'exp_date'
              ? '01-JAN-20'
              : '0';
      h.transport.requests.clear();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(h.hrRequests, isEmpty);
      expect(_layout(t).report, isNull);
      if (key == 'hr_dashboard') {
        expect(_layout(t).message, isNotNull);
      } else {
        expect(h.auth.stage, AuthStage.accountBlocked);
      }
      await _finish(t);
    });
  }
  for (final spec in [
    (const Size(320, 568), 2.0),
    (const Size(568, 320), 1.6),
    (const Size(768, 1024), 1.4),
  ]) {
    _case(
      'native balance, long names and year dialog fit ${spec.$1} scale ${spec.$2}',
      (t) async {
        final h = LeaveBalanceHarness();
        h.employees.first['emp_name'] = 'Long employee name বাংলা পরীক্ষা';
        await _show(
          t,
          h,
          seed: leaveBalanceSeed,
          size: spec.$1,
          scale: spec.$2,
        );
        await _tap(t, 'leave_balance_year');
        await _tap(t, 'leave_balance_year_2024');
        await _tap(t, 'leave_balance_year_ok');
        expect(_layout(t).year.year, 2024);
        expect(t.takeException(), isNull);
        await _finish(t);
      },
    );
  }
}

import 'leave_approval_test_support.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_screen.dart';
import 'package:docdiary_ios/features/hr/leave_record/leave_record_models.dart';
import 'package:docdiary_ios/features/hr/leave_record/leave_record_screen.dart';
import 'package:docdiary_ios/features/hr/leave_record/native_leave_record_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'hr_dashboard_test_support.dart';
import 'leave_record_test_support.dart';

void _case(String label, Future<void> Function(WidgetTester) body) {
  testWidgets(label, (t) async {
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
  if (f.evaluate().isEmpty &&
      find.byKey(const Key('leave_record_scroll')).evaluate().isNotEmpty) {
    await t.scrollUntilVisible(
      f,
      200,
      maxScrolls: 150,
      scrollable:
          find
              .descendant(
                of: find.byKey(const Key('leave_record_scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
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
  LeaveRecordHarness h, {
  Size size = const Size(393, 852),
  double textScale = 1,
  bool hr = false,
  bool signIn = true,
  DashboardDestinationBuilder? destinationBuilder,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPadding);
  addTearDown(h.auth.dispose);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  if (signIn) await h.signIn();
  h.transport.requests.clear();
  await t.pumpWidget(
    RepaintBoundary(
      key: const Key('leave_record_capture'),
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
                    key: const Key('open_leave_record'),
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
                                          : LeaveRecordScreen(
                                            auth: h.auth,
                                            repository: h.leaveRecord,
                                            destinationBuilder:
                                                destinationBuilder,
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
  await _tap(t, 'open_leave_record');
}

NativeLeaveRecordLayout _layout(WidgetTester t) =>
    t.widget(find.byType(NativeLeaveRecordLayout));
bool _enabled(WidgetTester t, String name) =>
    t
        .widget<PopupMenuButton<LeaveRecordChoice>>(
          find.byKey(Key('leave_record_$name')),
        )
        .enabled;
Future<void> _select(WidgetTester t, String name, int index) async {
  await _tap(t, 'leave_record_$name');
  await _tap(t, 'leave_record_${name}_option_$index');
}

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
  expect(t.takeException(), isNull);
}

Future<void> _capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_LEAVE_RECORD_CAPTURE_DIR'];
  if (dir == null) return;
  await t.runAsync(
    () async => await precacheImage(
      const AssetImage('assets/images/hospital_icon.png'),
      t.element(find.byType(NativeLeaveRecordLayout)),
    ),
  );
  await t.pumpAndSettle();
  final box = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('leave_record_capture')),
  );
  await t.runAsync(() async {
    final bitmap = await box.toImage(pixelRatio: 1);
    final data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
    bitmap.dispose();
    final path = File('$dir/$name.png');
    await path.parent.create(recursive: true);
    await path.writeAsBytes(data!.buffer.asUint8List());
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
    'native default filter layout, month, four columns and all four status colours',
    (t) async {
      final h = LeaveRecordHarness();
      await _show(t, h);
      expect(find.text('Leave Record'), findsOneWidget);
      expect(find.text('OCTOBER, 2026'), findsOneWidget);
      expect(_enabled(t, 'division'), isTrue);
      expect(_enabled(t, 'department'), isFalse);
      expect(_enabled(t, 'employee'), isFalse);
      final field = t.widget<InputDecorator>(
        find.descendant(
          of: find.byKey(const Key('leave_record_department')),
          matching: find.byType(InputDecorator),
        ),
      );
      expect(field.decoration.fillColor, const Color(0xfff5f5f5));
      expect(field.decoration.enabled, isFalse);
      expect(field.decoration.labelStyle!.fontFamily, 'OpenSans');
      for (final text in [
        'EMP  NAME',
        'LEAVE TYPE',
        'LEAVE DATE',
        'STATUS',
        'PENDING',
        'APPROVED',
        'REJECTED',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(h.hrRequests.length, 5);
      expect(h.posts, isEmpty);
      await _capture(t, 'leave_record');
      await _finish(t);
    },
  );
  _case(
    'local cascade filters by selected IDs, disables fields again and makes no HR request',
    (t) async {
      final h = LeaveRecordHarness();
      await _show(t, h);
      h.transport.requests.clear();
      await _select(t, 'division', 1);
      expect(_enabled(t, 'department'), isTrue);
      expect(_enabled(t, 'employee'), isFalse);
      await _select(t, 'department', 1);
      expect(_enabled(t, 'employee'), isTrue);
      await _select(t, 'employee', 2);
      expect(_layout(t).filter.employee, '12');
      expect(find.byKey(const Key('leave_record_row_42')), findsOneWidget);
      expect(find.byKey(const Key('leave_record_row_41')), findsNothing);
      await _tap(t, 'leave_record_status');
      expect(
        find.text('Total Leave Application:   1', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Approved:   1', findRichText: true), findsOneWidget);
      expect(find.text('Pending:   0', findRichText: true), findsOneWidget);
      await _tap(t, 'leave_record_summary_close');
      await _select(t, 'employee', 0);
      expect(_layout(t).filter.employee, '');
      await _select(t, 'division', 0);
      expect(_layout(t).filter.division, '');
      expect(_enabled(t, 'department'), isFalse);
      expect(_enabled(t, 'employee'), isFalse);
      expect(h.hrRequests, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'branch selection loads scoped endpoints; None clears selections and reloads global catalogues',
    (t) async {
      final h = LeaveRecordHarness();
      await _show(t, h);
      await _select(t, 'division', 1);
      h.transport.requests.clear();
      await _select(t, 'branch', 2);
      expect(_layout(t).data!.branch.id, '2');
      expect(_layout(t).filter.division, '');
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getDivisionWithCoa',
        'getDepartmentWithCoa',
        'getEmployeeWithCoa',
        'getLeaveRecordWithCoa',
      ]);
      expect(find.byKey(const Key('leave_record_row_44')), findsOneWidget);
      h.transport.requests.clear();
      await _select(t, 'branch', 0);
      expect(_layout(t).data!.branch.id, '');
      expect(h.hrRequests.length, 5);
      await _finish(t);
    },
  );
  _case(
    'summary counts applications and all zero counts remain accessible with no data',
    (t) async {
      final h = LeaveRecordHarness();
      h.records = [];
      await _show(t, h);
      expect(find.text('No Leave Record Found'), findsOneWidget);
      await _capture(t, 'leave_record_empty');
      await _tap(t, 'leave_record_status');
      for (final label in [
        'Total Leave Application',
        'Pending',
        'Approved',
        'Rejected',
        'Cancel Approved Leave',
      ]) {
        expect(find.text('$label:   0', findRichText: true), findsOneWidget);
      }
      await _tap(t, 'leave_record_summary_close');
      await _finish(t);
    },
  );
  _case(
    'month Cancel sends nothing and OK sends one record read preserving employee filter',
    (t) async {
      final h = LeaveRecordHarness();
      await _show(t, h);
      await _select(t, 'division', 1);
      await _select(t, 'department', 1);
      await _select(t, 'employee', 2);
      h.transport.requests.clear();
      await _tap(t, 'leave_record_month');
      await _tap(t, 'leave_record_month_cancel');
      expect(h.hrRequests, isEmpty);
      await _tap(t, 'leave_record_month');
      final wheel = t.widget<ListWheelScrollView>(
        find.byKey(const Key('leave_record_month_wheel')),
      );
      (wheel.controller! as FixedExtentScrollController).jumpToItem(3);
      await t.pumpAndSettle();
      await _capture(t, 'leave_record_month');
      await _tap(t, 'leave_record_month_ok');
      expect(find.text('NOVEMBER, 2026'), findsOneWidget);
      expect(_layout(t).filter.employee, '12');
      expect(h.hrRequests.single.uri.queryParameters, {
        'first_date': '01-NOV-26',
        'last_date': '30-NOV-26',
      });
      await _finish(t);
    },
  );
  _case(
    'large-text month picker supports native next-year bound without overflowing',
    (t) async {
      final h = LeaveRecordHarness(clock: DateTime(2026, 12, 20));
      h.adminData['exp_date'] = '01-JAN-30';
      await _show(t, h, textScale: 2);
      await _tap(t, 'leave_record_month');
      await _tap(t, 'leave_record_month_2027_1');
      await _tap(t, 'leave_record_month_ok');
      expect(_layout(t).month.first, DateTime(2027, 1));
      expect(h.hrRequests.last.uri.queryParameters['last_date'], '31-JAN-27');
      await _finish(t);
    },
  );
  for (final pending in [true, false]) {
    _case(
      '${pending ? 'pending' : 'processed'} row passes native extras and returning refreshes with filters',
      (t) async {
        final h = LeaveRecordHarness();
        DashboardRoute? route;
        await _show(
          t,
          h,
          destinationBuilder: (context, destination) {
            route = destination;
            return Scaffold(
              body: Center(
                child: TextButton(
                  key: const Key('return_leave_child'),
                  onPressed: () {
                    h.records = [
                      {...leaveRecordRow(), 'la_approved': '1'},
                    ];
                    Navigator.pop(context);
                  },
                  child: const Text('Return'),
                ),
              ),
            );
          },
        );
        await _select(t, 'division', 1);
        await _select(t, 'department', 1);
        if (pending) await _select(t, 'employee', 1);
        await _tap(t, pending ? 'leave_record_row_41' : 'leave_record_row_42');
        expect(
          route!.module,
          pending
              ? DashboardModule.hrLeaveApproval
              : DashboardModule.hrLeaveBalance,
        );
        expect(
          route!.extras[pending ? 'FLAG' : 'LAST_DATE'],
          pending ? '1' : '31-OCT-26',
        );
        h.transport.requests.clear();
        await _tap(t, 'return_leave_child');
        expect(_layout(t).filter.department, '100');
        if (pending) expect(_layout(t).filter.employee, '11');
        expect(h.hrRequests.length, 5);
        expect(find.text('APPROVED'), findsOneWidget);
        await _finish(t);
      },
    );
  }
  _case('pending row opens Leave Approval with native seed identifiers', (
    t,
  ) async {
    final h = LeaveApprovalHarness();
    await _show(t, h);
    await _tap(t, 'leave_record_row_41');
    expect(find.byKey(const Key('leave_approval_select')), findsOneWidget);
    expect(find.byKey(const Key('leave_request_picker')), findsNothing);
    expect(h.hrRequests.last.uri.queryParameters['p_la_id'], '41');
    expect(find.text('LR-2026-41'), findsOneWidget);
    expect(h.posts, isEmpty);
    await _finish(t);
  });
  _case(
    'load error Retry restarts the right chain and Cancel leaves the screen',
    (t) async {
      final h = LeaveRecordHarness();
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('/getLeaveRecord')) {
          throw const AppFailure('Leave service unavailable');
        }
        return h.respondLeave(uri);
      };
      await _show(t, h);
      expect(
        find.text(
          'Error Message: Leave service unavailable.\nPlease try again.',
        ),
        findsOneWidget,
      );
      h.transport.onGet = h.respondLeave;
      await _tap(t, 'leave_record_error_retry');
      expect(_layout(t).data!.rows.length, 4);
      h.transport.onGet =
          (uri) async =>
              uri.path.endsWith('/getLeaveRecord')
                  ? throw const AppFailure('Unavailable')
                  : h.respondLeave(uri);
      await _tap(t, 'leave_record_month');
      await _tap(t, 'leave_record_month_ok');
      await _tap(t, 'leave_record_error_cancel');
      expect(find.byType(LeaveRecordScreen), findsNothing);
      await _finish(t);
    },
  );
  _case(
    'pending refresh blocks Back and retained callbacks, then replaces the record set',
    (t) async {
      final h = LeaveRecordHarness();
      await _show(t, h);
      final retained = _layout(t);
      final gate = Completer<JsonMap>();
      h.transport.onGet =
          (uri) =>
              uri.path.endsWith('/getLeaveRecord')
                  ? gate.future
                  : h.respondLeave(uri);
      final refresh = retained.onRefresh();
      await t.pump();
      await t.pump();
      retained.onBack();
      retained.onDivision(retained.data!.divisions[1]);
      retained.onRow(retained.data!.rows.first);
      await t.pump();
      expect(find.byType(LeaveRecordScreen), findsOneWidget);
      gate.complete(hrPage([]));
      await refresh;
      await t.pumpAndSettle();
      expect(_layout(t).filter.division, '');
      expect(find.text('No Leave Record Found'), findsOneWidget);
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'logout during pending record read ignores late data and closes an owned month dialog',
    (t) async {
      final h = LeaveRecordHarness();
      await _show(t, h);
      final gate = Completer<JsonMap>();
      h.transport.onGet =
          (uri) =>
              uri.path.endsWith('/getLeaveRecord')
                  ? gate.future
                  : h.respondLeave(uri);
      final future = _layout(t).onRefresh();
      await t.pump();
      await t.pump();
      await h.auth.logout();
      await t.pump();
      gate.complete(hrPage([leaveRecordRow()]));
      await future;
      await t.pump();
      expect(_layout(t).data, isNull);
      expect(h.auth.stage, AuthStage.signedOut);
      expect(find.byKey(const Key('leave_record_row_41')), findsNothing);
      await _finish(t);
    },
  );
  _case('logout removes owned month popup immediately', (t) async {
    final h = LeaveRecordHarness();
    await _show(t, h);
    await _tap(t, 'leave_record_month');
    await h.auth.logout();
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('leave_record_month_dialog')), findsNothing);
    await _finish(t);
  });
  _case(
    'background removes filter popup, hides records and resume restores valid filter IDs',
    (t) async {
      final h = LeaveRecordHarness();
      await _show(t, h);
      await _select(t, 'division', 1);
      await _select(t, 'department', 1);
      await _tap(t, 'leave_record_employee');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('leave_record_scroll')), findsNothing);
      expect(
        find.byKey(const Key('leave_record_employee_option_1')),
        findsNothing,
      );
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(_layout(t).filter.department, '100');
      await _finish(t);
    },
  );
  _case(
    'a late obsolete record reply cannot overwrite a newer foreground snapshot',
    (t) async {
      final h = LeaveRecordHarness();
      await _show(t, h);
      final gate = Completer<JsonMap>();
      h.transport.onGet =
          (uri) =>
              uri.path.endsWith('/getLeaveRecord')
                  ? gate.future
                  : h.respondLeave(uri);
      final pending = _layout(t).onRefresh();
      await t.pump();
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      h.records = [];
      h.transport.onGet = h.respondLeave;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      gate.complete(hrPage([leaveRecordRow()]));
      await pending;
      await t.pumpAndSettle();
      expect(_layout(t).data!.rows, isEmpty);
      await _finish(t);
    },
  );
  for (final change in [
    'hr_dashboard',
    'usr_mob_forced_log_out_flag',
    'usr_mob_app_access',
    'exp_date',
  ]) {
    _case(
      'revoked $change before opening a record prevents child navigation and HR reads',
      (t) async {
        final h = LeaveRecordHarness();
        var built = false;
        await _show(
          t,
          h,
          destinationBuilder: (context, route) {
            built = true;
            return const Scaffold();
          },
        );
        h.adminData[change] =
            change == 'usr_mob_forced_log_out_flag'
                ? '1'
                : change == 'exp_date'
                ? '01-JAN-20'
                : '0';
        h.transport.requests.clear();
        _layout(t).onRow(_layout(t).data!.rows.first);
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(built, isFalse);
        expect(h.hrRequests, isEmpty);
        if (change == 'hr_dashboard') {
          expect(_layout(t).message, isNotNull);
        } else {
          expect(h.auth.stage, AuthStage.accountBlocked);
        }
        await _finish(t);
      },
    );
  }
  _case(
    'HR drawer opens the default Leave Record module and Back refreshes HR',
    (t) async {
      final h = LeaveRecordHarness();
      await _show(t, h, hr: true);
      await _tap(t, 'hr_menu');
      await _tap(t, 'hr_menu_leaveRecord');
      expect(find.byType(LeaveRecordScreen), findsOneWidget);
      h.transport.requests.clear();
      await _tap(t, 'leave_record_back');
      expect(find.byType(HrDashboardScreen), findsOneWidget);
      expect(
        h.hrRequests.any((r) => r.uri.path.endsWith('/getDeptEmpCount')),
        isTrue,
      );
      await _finish(t);
    },
  );
  _case('signed-out direct entry loads no data', (t) async {
    final h = LeaveRecordHarness();
    await _show(t, h, signIn: false);
    expect(h.transport.requests, isEmpty);
    expect(_layout(t).message, isNotNull);
    await _finish(t);
  });
  for (final spec in [
    (const Size(320, 568), 2.0),
    (const Size(568, 320), 1.6),
    (const Size(768, 1024), 1.4),
  ]) {
    _case(
      'small/landscape/large-font leave rows scroll without overflow ${spec.$1} ${spec.$2}',
      (t) async {
        final h = LeaveRecordHarness();
        h.records = [
          for (var i = 0; i < 18; i++)
            leaveRecordRow(
              id: '$i',
              name: 'Long employee name বাংলা পরীক্ষা $i',
              status: '${i % 4}',
              from: '21-OCT',
              to: '23-OCT',
              days: '3',
            ),
        ];
        await _show(
          t,
          h,
          size: spec.$1,
          textScale: spec.$2,
          destinationBuilder:
              (context, route) => const Scaffold(
                key: Key('leave_record_scroll_test_child'),
                body: Center(child: Text('Selected record')),
              ),
        );
        await _tap(t, 'leave_record_status');
        await _tap(t, 'leave_record_summary_close');
        await _tap(t, 'leave_record_row_17');
        expect(
          find.byKey(const Key('leave_record_scroll_test_child')),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
        await _finish(t);
      },
    );
  }
}

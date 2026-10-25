import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/hr/leave_approval/leave_approval_models.dart';
import 'package:docdiary_ios/features/hr/leave_approval/leave_approval_screen.dart';
import 'package:docdiary_ios/features/hr/leave_approval/native_leave_approval_layout.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'leave_approval_test_support.dart';
import 'hr_dashboard_test_support.dart';
import 'package:docdiary_ios/features/hr/leave_record/leave_record_screen.dart';
import 'package:docdiary_ios/features/hr/leave_record/native_leave_record_layout.dart';

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
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty &&
      find.byKey(const Key('leave_picker_rows')).evaluate().isNotEmpty) {
    await t.scrollUntilVisible(
      finder,
      80,
      scrollable:
          find
              .descendant(
                of: find.byKey(const Key('leave_picker_rows')),
                matching: find.byType(Scrollable),
              )
              .first,
    );
  }
  if (finder.hitTestable().evaluate().isEmpty) {
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
  }
  await t.tap(finder);
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

NativeLeaveApprovalLayout _layout(WidgetTester t) =>
    t.widget(find.byType(NativeLeaveApprovalLayout));
Finder _pickerSurface() =>
    find
        .descendant(
          of: find.byKey(const Key('leave_request_picker')),
          matching: find.byType(Material),
        )
        .first;
Future<void> _show(
  WidgetTester t,
  LeaveApprovalHarness h, {
  Size size = const Size(393, 852),
  double textScale = 1,
  bool hr = false,
  bool record = false,
  bool signIn = true,
  LeaveApprovalSeed? seed,
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
      key: const Key('approval_capture'),
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
                    key: const Key('open_approval'),
                    onPressed:
                        () => unawaited(
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder:
                                  (_) =>
                                      record
                                          ? LeaveRecordScreen(
                                            auth: h.auth,
                                            repository: h.leaveRecord,
                                          )
                                          : hr
                                          ? HrDashboardScreen(
                                            auth: h.auth,
                                            repository: h.hr,
                                          )
                                          : LeaveApprovalScreen(
                                            auth: h.auth,
                                            repository: h.approval,
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
  await _tap(t, 'open_approval');
}

Future<void> _select(WidgetTester t, {String id = '41'}) =>
    _tap(t, 'leave_request_$id');
Future<void> _comment(WidgetTester t, String text) async {
  final f = find.byKey(const Key('leave_approval_comments'));
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.enterText(f, text);
  await t.pumpAndSettle();
}

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
  expect(t.takeException(), isNull);
}

Future<void> _capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_LEAVE_APPROVAL_CAPTURE_DIR'];
  if (dir == null) return;
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('approval_capture')),
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
          'Poppins': [
            'Poppins-Regular.ttf',
            'Poppins-SemiBold.ttf',
            'Poppins-Bold.ttf',
          ],
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
          'RussoOne': ['RussoOne-Regular.ttf'],
          'PatuaOne': ['PatuaOne-Regular.ttf'],
          'Roboto': ['Roboto-Regular.ttf'],
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
    'entry automatically opens native five column selector; CANCEL leaves empty screen',
    (t) async {
      final h = LeaveApprovalHarness();
      await _show(t, h);
      expect(find.text('Select Leave Request Code:'), findsOneWidget);
      for (final text in [
        'Application Code',
        'Emp Name',
        'Emp Code',
        'Application Date',
        'Leave Days',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(h.hrRequests.single.uri.pathSegments.last, 'getLeaveRequestList');
      await _capture(t, 'leave_requests');
      await _tap(t, 'leave_picker_cancel');
      expect(_layout(t).detail, isNull);
      expect(find.byKey(const Key('leave_approval_approve')), findsNothing);
      await _tap(t, 'leave_approval_select');
      expect(find.byKey(const Key('leave_request_picker')), findsOneWidget);
      await _finish(t);
    },
  );
  _case(
    'search, no matches, clear and select keep correct record and detail query',
    (t) async {
      final h = LeaveApprovalHarness();
      await _show(t, h);
      final search = find.byKey(const Key('leave_picker_search'));
      await t.enterText(search, 'nothing');
      await t.pump();
      expect(find.text('No Leave Request Found'), findsOneWidget);
      await t.enterText(search, 'employee b');
      await t.pump();
      expect(find.byKey(const Key('leave_request_41')), findsNothing);
      await _select(t, id: '42');
      expect(_layout(t).request!.id, '42');
      expect(h.hrRequests.last.uri.queryParameters['p_la_id'], '42');
      await _tap(t, 'leave_approval_select');
      expect(t.widget<TextField>(search).controller!.text, '');
      await t.enterText(search, 'LR-26-0041');
      await t.pump();
      await _select(t);
      expect(_layout(t).request!.id, '41');
      await _finish(t);
    },
  );
  _case(
    'details match native sections and comments label updates without resetting text',
    (t) async {
      final h = LeaveApprovalHarness();
      await _show(t, h);
      await _select(t);
      expect(_layout(t).detail!.value('emp_name'), 'Example Employee A');
      for (final key in [
        'la_from_date',
        'la_to_date',
        'la_leave_days',
        'leave_balance',
        'leave_type',
        'la_reason',
      ]) {
        expect(find.byKey(Key('leave_approval_field_$key')), findsOneWidget);
      }
      await _capture(t, 'leave_request_detail');
      await _comment(t, 'Checked');
      expect(
        t
            .widget<TextField>(find.byKey(const Key('leave_approval_comments')))
            .decoration!
            .labelText,
        'Approve/Reject Comments:',
      );
      await _capture(t, 'leave_request_comments');
      await _finish(t);
    },
  );
  for (final action in LeaveApprovalAction.values) {
    _case(
      '${action.name} requires explicit YES; NO sends no POST and retains comments',
      (t) async {
        final h = LeaveApprovalHarness();
        await _show(t, h);
        await _select(t);
        await _comment(t, 'Reason for decision');
        await _tap(t, 'leave_approval_${action.name}');
        expect(find.text('${action.label} Leave!'), findsOneWidget);
        expect(
          find.text('Do you want ${action.name} this leave?'),
          findsOneWidget,
        );
        await _tap(t, 'leave_approval_no');
        expect(h.hrRequests.where((r) => r.method == 'POST'), isEmpty);
        expect(_layout(t).comments.text, 'Reason for decision');
        await _tap(t, 'leave_approval_${action.name}');
        await _tap(t, 'leave_approval_yes');
        expect(find.text(action.successMessage), findsOneWidget);
        expect(h.hrRequests.where((r) => r.method == 'POST').length, 1);
        await _tap(t, 'leave_approval_ok');
        expect(find.byType(LeaveApprovalScreen), findsNothing);
        await _finish(t);
      },
    );
  }
  _case(
    'reject without reason shows native message; approve permits empty comment',
    (t) async {
      final h = LeaveApprovalHarness();
      await _show(t, h);
      await _select(t);
      await _tap(t, 'leave_approval_reject');
      expect(find.text('Please mention reason for reject'), findsOneWidget);
      expect(find.byKey(const Key('leave_approval_confirm')), findsNothing);
      await _tap(t, 'leave_approval_approve');
      await _tap(t, 'leave_approval_yes');
      expect(h.hrRequests.last.headers['P_TEXT_COMMENTS'], '');
      await _finish(t);
    },
  );
  for (final action in LeaveApprovalAction.values) {
    _case(
      '${action.name} returns updated_req non-ok without success or exiting',
      (t) async {
        final h = LeaveApprovalHarness();
        h.response['updated_req'] = 'Already handled';
        await _show(t, h);
        await _select(t);
        await _comment(t, 'Review');
        await _tap(t, 'leave_approval_${action.name}');
        await _tap(t, 'leave_approval_yes');
        expect(find.text('Already handled'), findsOneWidget);
        expect(find.text(action.successMessage), findsNothing);
        expect(find.byType(LeaveApprovalScreen), findsOneWidget);
        expect(_layout(t).comments.text, 'Review');
        await _finish(t);
      },
    );
  }
  _case(
    'list read failure offers Retry and CANCEL without showing stale rows',
    (t) async {
      final h = LeaveApprovalHarness();
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('/getLeaveRequestList')) {
          throw const AppFailure('List unavailable');
        }
        return h.respondApproval(uri);
      };
      await _show(t, h);
      expect(find.text('List unavailable'), findsOneWidget);
      expect(find.byKey(const Key('leave_picker_rows')), findsNothing);
      h.transport.onGet = h.respondApproval;
      await _tap(t, 'leave_picker_retry');
      await _select(t);
      expect(_layout(t).detail, isNotNull);
      await _finish(t);
    },
  );
  _case('detail failure Cancel exits; Retry reloads detail only', (t) async {
    final h = LeaveApprovalHarness();
    await _show(t, h);
    h.transport.onGet =
        (uri) async =>
            uri.path.endsWith('/getLeaveData')
                ? throw const AppFailure('Detail unavailable')
                : h.respondApproval(uri);
    await _select(t);
    expect(
      find.text('Error Message: Detail unavailable.\nPlease try again.'),
      findsOneWidget,
    );
    h.transport.onGet = h.respondApproval;
    await _tap(t, 'leave_approval_error_retry');
    expect(_layout(t).detail, isNotNull);
    await _tap(t, 'leave_approval_select');
    h.transport.onGet =
        (uri) async =>
            uri.path.endsWith('/getLeaveData')
                ? throw const AppFailure('Detail unavailable')
                : h.respondApproval(uri);
    await _select(t);
    await _tap(t, 'leave_approval_error_cancel');
    expect(find.byType(LeaveApprovalScreen), findsNothing);
    await _finish(t);
  });
  _case(
    'missing detail cannot expose empty fields with active Approve or Reject',
    (t) async {
      final h = LeaveApprovalHarness();
      h.details = [];
      await _show(t, h);
      await _select(t);
      expect(
        find.text('This leave request is no longer pending.'),
        findsOneWidget,
      );
      await _tap(t, 'leave_approval_ok');
      expect(_layout(t).detail, isNull);
      expect(find.byKey(const Key('leave_approval_approve')), findsNothing);
      await _finish(t);
    },
  );
  _case(
    'POST failure Retry refreshes reads and requires new confirmation, never replaying write',
    (t) async {
      final h = LeaveApprovalHarness();
      await _show(t, h);
      await _select(t);
      h.transport.onPost =
          (uri, headers) async =>
              throw const AppFailure('Timed out', kind: FailureKind.network);
      await _comment(t, 'Keep this comment');
      await _tap(t, 'leave_approval_approve');
      await _tap(t, 'leave_approval_yes');
      expect(find.byKey(const Key('leave_approval_error')), findsOneWidget);
      await _tap(t, 'leave_approval_error_retry');
      expect(h.hrRequests.where((r) => r.method == 'POST').length, 1);
      expect(_layout(t).detail, isNotNull);
      expect(_layout(t).comments.text, 'Keep this comment');
      expect(find.byKey(const Key('leave_approval_confirm')), findsNothing);
      await _finish(t);
    },
  );
  _case(
    'unknown POST outcome then request disappears does not claim success or repeat POST',
    (t) async {
      final h = LeaveApprovalHarness();
      await _show(t, h);
      await _select(t);
      h.transport.onPost = (uri, headers) async {
        h.requests = [];
        throw const AppFailure(
          'Connection interrupted',
          kind: FailureKind.network,
        );
      };
      await _tap(t, 'leave_approval_approve');
      await _tap(t, 'leave_approval_yes');
      await _tap(t, 'leave_approval_error_retry');
      expect(
        find.text('This leave request is no longer pending.'),
        findsOneWidget,
      );
      expect(h.hrRequests.where((r) => r.method == 'POST').length, 1);
      await _tap(t, 'leave_approval_ok');
      expect(_layout(t).detail, isNull);
      await _finish(t);
    },
  );
  _case(
    'another approver handles selection before YES so preflight blocks the POST',
    (t) async {
      final h = LeaveApprovalHarness();
      await _show(t, h);
      await _select(t);
      await _tap(t, 'leave_approval_approve');
      h.requests = [];
      await _tap(t, 'leave_approval_yes');
      expect(h.hrRequests.where((r) => r.method == 'POST'), isEmpty);
      expect(
        find.text('This leave request is no longer pending.'),
        findsOneWidget,
      );
      await _finish(t);
    },
  );
  _case(
    'rapid and retained callbacks while writing cannot send two POSTs or pop screen',
    (t) async {
      final h = LeaveApprovalHarness();
      await _show(t, h);
      await _select(t);
      final retained = _layout(t);
      final gate = Completer<JsonMap>();
      h.transport.onPost = (uri, headers) => gate.future;
      await _tap(t, 'leave_approval_approve');
      await t.tap(find.byKey(const Key('leave_approval_yes')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      retained.onAction(LeaveApprovalAction.approve);
      retained.onSelect();
      retained.onBack();
      await t.pump();
      expect(find.byType(LeaveApprovalScreen), findsOneWidget);
      expect(h.hrRequests.where((r) => r.method == 'POST').length, 1);
      gate.complete({
        'string_out': 'Successfully Created',
        'updated_req': 'ok',
      });
      await t.pumpAndSettle();
      expect(find.text('Leave Approved Successfully'), findsOneWidget);
      await _finish(t);
    },
  );
  _case(
    'background closes confirmation and resume revalidates access without POST',
    (t) async {
      final h = LeaveApprovalHarness();
      await _show(t, h);
      await _select(t);
      await _comment(t, 'Keep');
      await _tap(t, 'leave_approval_approve');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('leave_approval_confirm')), findsNothing);
      expect(find.byKey(const Key('leave_approval_details')), findsNothing);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(_layout(t).comments.text, 'Keep');
      expect(h.hrRequests.where((r) => r.method == 'POST'), isEmpty);
      await _finish(t);
    },
  );
  _case(
    'resume while POST is pending waits, then reads pending status without replay',
    (t) async {
      final h = LeaveApprovalHarness();
      await _show(t, h);
      await _select(t);
      final gate = Completer<JsonMap>();
      h.transport.onPost = (uri, headers) => gate.future;
      await _tap(t, 'leave_approval_approve');
      await t.tap(find.byKey(const Key('leave_approval_yes')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(h.hrRequests.where((r) => r.method == 'POST').length, 1);
      gate.complete({
        'string_out': 'Successfully Created',
        'updated_req': 'ok',
      });
      await t.pumpAndSettle();
      expect(_layout(t).detail, isNotNull);
      expect(find.text('Leave Approved Successfully'), findsNothing);
      expect(h.hrRequests.where((r) => r.method == 'POST').length, 1);
      await _finish(t);
    },
  );
  for (final phase in ['picker', 'confirm', 'write']) {
    _case('logout during $phase closes owned dialog and ignores late work', (
      t,
    ) async {
      final h = LeaveApprovalHarness();
      await _show(t, h);
      final gate = Completer<JsonMap>();
      if (phase != 'picker') {
        await _select(t);
        await _tap(t, 'leave_approval_approve');
      }
      if (phase == 'write') {
        h.transport.onPost = (uri, headers) => gate.future;
        await t.tap(find.byKey(const Key('leave_approval_yes')));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
      }
      await h.auth.logout();
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      if (phase == 'write') {
        gate.complete({
          'string_out': 'Successfully Created',
          'updated_req': 'ok',
        });
        await t.pump();
      }
      expect(find.byKey(const Key('leave_request_picker')), findsNothing);
      expect(find.byKey(const Key('leave_approval_confirm')), findsNothing);
      expect(find.byKey(const Key('leave_approval_message')), findsNothing);
      expect(h.auth.stage, AuthStage.signedOut);
      await _finish(t);
    });
  }
  for (final key in [
    'hr_dashboard',
    'usr_mob_forced_log_out_flag',
    'usr_mob_app_access',
    'exp_date',
  ]) {
    _case(
      'revalidate $key immediately before POST and prevent revoked action',
      (t) async {
        final h = LeaveApprovalHarness();
        await _show(t, h);
        await _select(t);
        await _tap(t, 'leave_approval_approve');
        h.adminData[key] =
            key == 'usr_mob_forced_log_out_flag'
                ? '1'
                : key == 'exp_date'
                ? '01-JAN-20'
                : '0';
        await t.tap(find.byKey(const Key('leave_approval_yes')));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        expect(h.hrRequests.where((r) => r.method == 'POST'), isEmpty);
        if (key == 'hr_dashboard') {
          expect(_layout(t).message, isNotNull);
        } else {
          expect(h.auth.stage, AuthStage.accountBlocked);
        }
        await _finish(t);
      },
    );
  }
  _case('HR drawer opens this default module and refreshes HR after success', (
    t,
  ) async {
    final h = LeaveApprovalHarness();
    await _show(t, h, hr: true);
    await _tap(t, 'hr_menu');
    await _tap(t, 'hr_menu_leaveApproval');
    expect(find.byType(LeaveApprovalScreen), findsOneWidget);
    await _select(t);
    await _tap(t, 'leave_approval_approve');
    await _tap(t, 'leave_approval_yes');
    h.transport.requests.clear();
    await _tap(t, 'leave_approval_ok');
    expect(find.byType(HrDashboardScreen), findsOneWidget);
    expect(find.byType(LeaveApprovalScreen), findsNothing);
    expect(
      h.hrRequests.any((r) => r.uri.path.endsWith('/getDeptEmpCount')),
      isTrue,
    );
    await _finish(t);
  });
  _case(
    'logout during a pending picker read ignores the late result and disposed notifier',
    (t) async {
      final h = LeaveApprovalHarness();
      await _show(t, h);
      await _tap(t, 'leave_picker_cancel');
      final gate = Completer<JsonMap>();
      h.transport.onGet =
          (uri) =>
              uri.path.endsWith('/getLeaveRequestList')
                  ? gate.future
                  : h.respondApproval(uri);
      await t.tap(find.byKey(const Key('leave_approval_select')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      await h.auth.logout();
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      gate.complete(hrPage([approvalRequest()]));
      await t.pump();
      expect(find.byKey(const Key('leave_request_picker')), findsNothing);
      expect(t.takeException(), isNull);
      await _finish(t);
    },
  );
  _case(
    'old detail read finishing after foreground reload cannot replace the new detail',
    (t) async {
      final h = LeaveApprovalHarness();
      await _show(t, h);
      final gate = Completer<JsonMap>();
      h.transport.onGet =
          (uri) =>
              uri.path.endsWith('/getLeaveData')
                  ? gate.future
                  : h.respondApproval(uri);
      await t.tap(find.byKey(const Key('leave_request_41')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      h.details = [
        {...approvalDetail(), 'emp_name': 'Fresh detail'},
      ];
      h.transport.onGet = h.respondApproval;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(_layout(t).detail!.value('emp_name'), 'Fresh detail');
      gate.complete(
        hrPage([
          {...approvalDetail(), 'emp_name': 'Obsolete detail'},
        ]),
      );
      await t.pumpAndSettle();
      expect(_layout(t).detail!.value('emp_name'), 'Fresh detail');
      expect(h.hrRequests.where((r) => r.method == 'POST'), isEmpty);
      await _finish(t);
    },
  );
  _case(
    'success dialog survives pause as an acknowledged result without resubmitting',
    (t) async {
      final h = LeaveApprovalHarness();
      await _show(t, h);
      await _select(t);
      await _tap(t, 'leave_approval_approve');
      await _tap(t, 'leave_approval_yes');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(find.text('Leave Approved Successfully'), findsOneWidget);
      expect(h.hrRequests.where((r) => r.method == 'POST').length, 1);
      await _tap(t, 'leave_approval_ok');
      expect(find.byType(LeaveApprovalScreen), findsNothing);
      await _finish(t);
    },
  );
  _case(
    'empty request picker wraps content with a visible no-data message and CANCEL',
    (t) async {
      final h = LeaveApprovalHarness();
      h.requests = [];
      await _show(t, h);
      expect(find.text('No Leave Request Found'), findsOneWidget);
      expect(t.getSize(_pickerSurface()).height, lessThan(360));
      expect(
        find.byKey(const Key('leave_picker_cancel')).hitTestable(),
        findsOneWidget,
      );
      await _capture(t, 'leave_approval_empty');
      await _tap(t, 'leave_picker_cancel');
      await _finish(t);
    },
  );
  _case(
    'long pending list stays inside safe bounds and scrolling selects the real last row',
    (t) async {
      final h = LeaveApprovalHarness();
      h.requests = [
        for (var i = 0; i < 60; i++)
          approvalRequest(
            id: '$i',
            code: '2026/00000001/$i',
            name: 'Sample Employee $i',
            employee: '$i',
          ),
      ];
      await _show(t, h);
      final dialog = t.getRect(_pickerSurface());
      expect(dialog.top, greaterThanOrEqualTo(59));
      expect(dialog.bottom, lessThanOrEqualTo(818));
      await _tap(t, 'leave_request_59');
      expect(_layout(t).request!.id, '59');
      expect(h.hrRequests.last.uri.queryParameters['p_la_id'], '59');
      await _finish(t);
    },
  );
  _case('search and selection fit above the iOS keyboard without overflow', (
    t,
  ) async {
    final h = LeaveApprovalHarness();
    await _show(t, h);
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(t.view.resetViewInsets);
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const Key('leave_picker_search')),
      'employee b',
    );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('leave_request_41')), findsNothing);
    expect(
      t.getRect(find.byKey(const Key('leave_picker_cancel'))).bottom,
      lessThan(552),
    );
    await _select(t, id: '42');
    expect(_layout(t).request!.id, '42');
    expect(t.takeException(), isNull);
    await _finish(t);
  });
  _case(
    'lower leave balance warns before confirmation while reject remains usable',
    (t) async {
      final h = LeaveApprovalHarness();
      h.details = [approvalDetail(balance: '1', days: '2')];
      await _show(t, h);
      await _select(t);
      await _tap(t, 'leave_approval_approve');
      expect(find.text('Warning!'), findsOneWidget);
      expect(
        find.text('Leave Balance is lower than Total Leave Days.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('leave_approval_confirm')), findsNothing);
      expect(h.hrRequests.where((r) => r.method == 'POST'), isEmpty);
      await _capture(t, 'leave_approval_balance_warning');
      await _tap(t, 'leave_approval_ok');
      await _comment(t, 'Insufficient balance');
      await _tap(t, 'leave_approval_reject');
      await _tap(t, 'leave_approval_yes');
      expect(h.hrRequests.last.uri.pathSegments.last, 'rejectLeave');
      await _finish(t);
    },
  );
  for (final checked in [false, true]) {
    _case(
      'SL prescription $checked submits the native flag only after both answers',
      (t) async {
        final h = LeaveApprovalHarness();
        h.details = [approvalDetail(shortCode: 'SL')];
        await _show(t, h);
        await _select(t);
        await _tap(t, 'leave_approval_approve');
        expect(
          find.byKey(const Key('leave_approval_prescription')),
          findsNothing,
        );
        await _tap(t, 'leave_approval_yes');
        expect(find.text('Prescription Check!'), findsOneWidget);
        expect(
          find.text('Did you checked prescription of the applicant?'),
          findsOneWidget,
        );
        expect(h.hrRequests.where((r) => r.method == 'POST'), isEmpty);
        await _capture(t, 'leave_approval_prescription');
        await _tap(t, 'leave_approval_prescription_${checked ? 'yes' : 'no'}');
        expect(h.hrRequests.last.headers['P_SL_CHECK'], checked ? '1' : '0');
        expect(find.text('Leave Approved Successfully'), findsOneWidget);
        await _finish(t);
      },
    );
  }
  _case(
    'background during SL prescription invalidates both answers and never posts',
    (t) async {
      final h = LeaveApprovalHarness();
      h.details = [approvalDetail(shortCode: 'SL')];
      await _show(t, h);
      await _select(t);
      await _tap(t, 'leave_approval_approve');
      await _tap(t, 'leave_approval_yes');
      final retained = t.widget<TextButton>(
        find.byKey(const Key('leave_approval_prescription_yes')),
      );
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const Key('leave_approval_prescription')),
        findsNothing,
      );
      // Removed dialog callbacks cannot become a valid action after resume.
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      retained.onPressed!();
      await t.pumpAndSettle();
      expect(find.byType(LeaveApprovalScreen), findsOneWidget);
      expect(h.hrRequests.where((r) => r.method == 'POST'), isEmpty);
      await _tap(t, 'leave_approval_approve');
      await _tap(t, 'leave_approval_no');
      expect(h.hrRequests.where((r) => r.method == 'POST'), isEmpty);
      await _finish(t);
    },
  );
  _case(
    'ordinary leave uses SL_CHECK=0 and comment is retained when choosing another request',
    (t) async {
      final h = LeaveApprovalHarness();
      await _show(t, h);
      await _select(t);
      await _comment(t, 'Keep native comments');
      await _tap(t, 'leave_approval_select');
      await _select(t, id: '42');
      expect(_layout(t).comments.text, 'Keep native comments');
      await _tap(t, 'leave_approval_approve');
      await _tap(t, 'leave_approval_yes');
      expect(
        find.byKey(const Key('leave_approval_prescription')),
        findsNothing,
      );
      expect(h.hrRequests.last.headers['P_SL_CHECK'], '0');
      expect(h.hrRequests.last.headers['P_LA_ID'], '42');
      await _finish(t);
    },
  );
  _case(
    'Leave Record seed loads detail directly without selector or guessed IDs',
    (t) async {
      final h = LeaveApprovalHarness();
      await _show(
        t,
        h,
        seed: const LeaveApprovalSeed(
          id: '41',
          code: 'LR-26-0041',
          employeeId: '11',
        ),
      );
      expect(find.byKey(const Key('leave_request_picker')), findsNothing);
      expect(_layout(t).request!.id, '41');
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getLeaveData',
      ]);
      expect(h.hrRequests.single.uri.queryParameters['p_la_id'], '41');
      await _finish(t);
    },
  );
  _case('incomplete seed opens selection without reading an empty ID', (
    t,
  ) async {
    final h = LeaveApprovalHarness();
    await _show(
      t,
      h,
      seed: const LeaveApprovalSeed(id: '', code: '', employeeId: ''),
    );
    expect(find.byKey(const Key('leave_request_picker')), findsOneWidget);
    expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
      'getLeaveRequestList',
    ]);
    await _finish(t);
  });
  _case(
    'pending Leave Record row opens approval and returns with refreshed status',
    (t) async {
      final h = LeaveApprovalHarness();
      h.requests = [
        {...approvalRequest(), 'la_app_code': 'LR-2026-41'},
      ];
      await _show(t, h, record: true);
      await _tap(t, 'leave_record_row_41');
      expect(find.byType(LeaveApprovalScreen), findsOneWidget);
      expect(find.byKey(const Key('leave_request_picker')), findsNothing);
      expect(_layout(t).request!.id, '41');
      await _tap(t, 'leave_approval_approve');
      await _tap(t, 'leave_approval_yes');
      h.transport.requests.clear();
      await _tap(t, 'leave_approval_ok');
      expect(find.byType(LeaveApprovalScreen), findsNothing);
      final record = t.widget<NativeLeaveRecordLayout>(
        find.byType(NativeLeaveRecordLayout),
      );
      expect(record.data!.rows.first.status, '1');
      expect(
        h.hrRequests.any((r) => r.uri.path.endsWith('/getLeaveRecord')),
        isTrue,
      );
      await _finish(t);
    },
  );
  _case(
    'native detail fields, calendar icons and accepted selector style render together',
    (t) async {
      final h = LeaveApprovalHarness();
      await _show(t, h);
      await _capture(t, 'leave_approval_picker');
      expect(t.getSize(_pickerSurface()).height, lessThan(430));
      expect(
        ModalRoute.of(t.element(_pickerSurface()))!.barrierColor,
        const Color(0xcc000000),
      );
      final search = t.widget<TextField>(
        find.byKey(const Key('leave_picker_search')),
      );
      expect(search.autocorrect, isFalse);
      expect(search.enableSuggestions, isFalse);
      expect(search.smartDashesType, SmartDashesType.disabled);
      expect(search.smartQuotesType, SmartQuotesType.disabled);
      final row = find.byKey(const Key('leave_request_41'));
      expect(
        t
            .widgetList<Container>(
              find.descendant(of: row, matching: find.byType(Container)),
            )
            .where((c) => c.color == DocColors.clouds)
            .length,
        5,
      );
      await _select(t);
      expect(find.byIcon(Icons.calendar_month), findsNWidgets(2));
      final code = t.getRect(find.byKey(const Key('leave_approval_select')));
      final label = t.getRect(
        find.byKey(const Key('leave_approval_code_label')),
      );
      expect(label.top, greaterThan(code.top));
      expect(label.bottom, lessThan(code.bottom));
      await _capture(t, 'leave_approval_detail');
      await _comment(t, 'Reviewed leave request');
      final comments = t.widget<TextField>(
        find.byKey(const Key('leave_approval_comments')),
      );
      expect(comments.autocorrect, isFalse);
      expect(comments.smartQuotesType, SmartQuotesType.disabled);
      await _capture(t, 'leave_approval_comments');
      await _finish(t);
    },
  );
  _case(
    'approved dialog keeps search/header/cancel fixed while only request rows scroll',
    (t) async {
      final h = LeaveApprovalHarness();
      h.requests = [
        for (var i = 0; i < 60; i++)
          approvalRequest(
            id: '$i',
            code: 'LR-26-$i',
            name: 'Sample Employee $i',
            employee: '$i',
          ),
      ];
      await _show(t, h);
      final search = t.getRect(find.byKey(const Key('leave_picker_search')));
      final header = t.getRect(find.byKey(const Key('leave_picker_table')));
      final cancel = t.getRect(find.byKey(const Key('leave_picker_cancel')));
      await t.drag(
        find.byKey(const Key('leave_picker_rows')),
        const Offset(0, -400),
      );
      await t.pumpAndSettle();
      expect(t.getRect(find.byKey(const Key('leave_picker_search'))), search);
      expect(t.getRect(find.byKey(const Key('leave_picker_table'))), header);
      expect(t.getRect(find.byKey(const Key('leave_picker_cancel'))), cancel);
      await _finish(t);
    },
  );
  _case('signed out entry makes no API calls', (t) async {
    final h = LeaveApprovalHarness();
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
    _case('picker and long details fit ${spec.$1} with scale ${spec.$2}', (
      t,
    ) async {
      final h = LeaveApprovalHarness();
      h.details = [
        {
          ...approvalDetail(),
          for (final key in [
            'emp_name',
            'emp_code',
            'la_calling_title',
            'la_reason',
            'la_from_date',
            'la_to_date',
            'leave_type',
          ])
            key:
                '${approvalDetail()[key]} long content বাংলা পরীক্ষা 1234567890',
        },
      ];
      await _show(t, h, size: spec.$1, textScale: spec.$2);
      await _select(t);
      await _comment(
        t,
        'A long approval comment to exercise input and scrolling',
      );
      await _tap(t, 'leave_approval_approve');
      await _tap(t, 'leave_approval_no');
      expect(t.takeException(), isNull);
      await _finish(t);
    });
  }
}

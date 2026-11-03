import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/accounts/voucher_approval/native_voucher_approval_layout.dart';
import 'package:docdiary_ios/features/accounts/voucher_approval/voucher_approval_models.dart';
import 'package:docdiary_ios/features/accounts/voucher_approval/voucher_approval_screen.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'voucher_approval_test_support.dart';

Future<void> tap(WidgetTester t, String key, {bool settle = true}) async {
  final finder = find.byKey(Key(key));
  if (finder.hitTestable().evaluate().isEmpty) {
    await t.ensureVisible(finder);
    await t.pump();
  }
  await t.tap(finder);
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }
  expect(t.takeException(), isNull);
}

String txt(WidgetTester t, String key) =>
    t.widget<Text>(find.byKey(Key(key))).data!;
ScrollController scroll(WidgetTester t, String key) =>
    t.widget<SingleChildScrollView>(find.byKey(Key(key))).controller!;
void pause(WidgetTester t) {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    t.binding.handleAppLifecycleStateChanged(s);
  }
}

void resume(WidgetTester t) {
  if (t.binding.lifecycleState == AppLifecycleState.paused) {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

Future<void> host(
  WidgetTester t,
  ApprovalHarness h, {
  VoucherApprovalKind kind = VoucherApprovalKind.credit,
  bool app = false,
  Size size = const Size(393, 852),
  double zoom = 1,
  bool settle = true,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.view.padding = FakeViewPadding(
    top: size.width > size.height ? 24 : 59,
    bottom: size.width > size.height ? 20 : 34,
  );
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPadding);
  if (!app) addTearDown(h.auth.dispose);
  resume(t);
  await h.signIn();
  h.transport.requests.clear();
  await t.pumpWidget(
    RepaintBoundary(
      key: const Key('va_capture'),
      child:
          app
              ? DocDiaryApp(
                auth: h.auth,
                initializeOnStart: false,
                dashboard: DashboardRepository(h.transport, now: () => h.now),
              )
              : MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: docDiaryTheme(),
                builder:
                    (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(zoom)),
                      child: child!,
                    ),
                home: Builder(
                  builder:
                      (context) => Scaffold(
                        body: TextButton(
                          key: const Key('open_approval'),
                          child: const Text('Synthetic parent'),
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => VoucherApprovalScreen(
                                        auth: h.auth,
                                        repository: h.approvals,
                                        kind: kind,
                                      ),
                                ),
                              ),
                        ),
                      ),
                ),
              ),
    ),
  );
  await t.pumpAndSettle();
  if (app) {
    await tap(t, 'dashboard_nav_management');
    await tap(t, 'management_accounts');
    await tap(t, 'accounts_menu');
    await tap(t, 'accounts_menu_${kind.name}Approval', settle: settle);
  } else {
    await tap(t, 'open_approval', settle: settle);
  }
}

Future<void> select(
  WidgetTester t,
  ApprovalHarness h,
  VoucherApprovalKind kind,
  int index, {
  bool settle = true,
}) async {
  await tap(t, 'va_select');
  await tap(t, 'va_choice_${h.choice(kind, index).id}', settle: settle);
}

Future<void> finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_APPROVAL_CAPTURE_DIR'];
  if (dir == null) return;
  await t.pumpAndSettle();
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('va_capture')),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2),
        bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('$dir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final e
        in <String, List<String>>{
          'Poppins': [
            'Poppins-Regular.ttf',
            'Poppins-Medium.ttf',
            'Poppins-Bold.ttf',
          ],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
          'Ubuntu': ['Ubuntu-Medium.ttf'],
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
          'Archivo': ['Archivo[wdth,wght].ttf'],
          'PatuaOne': ['PatuaOne-Regular.ttf'],
          'RussoOne': ['RussoOne-Regular.ttf'],
        }.entries) {
      final loader = FontLoader(e.key);
      for (final file in e.value) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  void check(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (t) async {
        final old = debugDisableShadows;
        debugDisableShadows = false;
        try {
          await body(t);
        } finally {
          debugDisableShadows = old;
        }
      });
  for (final kind in VoucherApprovalKind.values) {
    check(
      '${kind.code} real menu, native counts, picker, report and horizontal totals',
      (t) async {
        final h = ApprovalHarness();
        await host(t, h, kind: kind, app: true);
        expect(find.byType(VoucherApprovalScreen), findsOneWidget);
        expect(find.text(kind.title), findsOneWidget);
        expect(txt(t, 'va_pending'), '1');
        expect(txt(t, 'va_approved'), '3');
        expect(find.byKey(const Key('va_action')), findsNothing);
        await capture(t, '01_${kind.code}_initial');
        await tap(t, 'va_select');
        expect(txt(t, 'va_prefix'), 'EXAMPLE.${kind.code}.');
        await capture(t, '02_${kind.code}_picker');
        await tap(t, 'va_picker_cancel');
        expect(find.byKey(const Key('va_detail')), findsNothing);
        await select(t, h, kind, 0);
        expect(txt(t, 'va_number'), h.choice(kind, 0).number);
        expect(txt(t, 'va_status'), 'Approved');
        expect(find.text('DISAPPROVE'), findsOneWidget);
        expect(find.text(kind.narrationLabel), findsOneWidget);
        await capture(t, '03_${kind.code}_approved');
        final horizontal = scroll(t, 'va_horizontal');
        horizontal.jumpTo(horizontal.position.maxScrollExtent);
        scroll(
          t,
          'va_scroll',
        ).jumpTo(scroll(t, 'va_scroll').position.maxScrollExtent);
        await t.pumpAndSettle();
        expect(txt(t, 'va_total_debit'), '1,83,000');
        expect(txt(t, 'va_total_credit'), '1,83,000');
        await capture(t, '04_${kind.code}_totals');
        await tap(t, 'va_report');
        expect(find.byKey(const Key('vt_report_dialog')), findsOneWidget);
        expect(txt(t, 'vt_report_number'), h.choice(kind, 0).number);
        await capture(t, '05_${kind.code}_report_left');
        final reportScroll = scroll(t, 'vt_report_horizontal');
        reportScroll.jumpTo(reportScroll.position.maxScrollExtent);
        await t.pumpAndSettle();
        expect(txt(t, 'vt_report_debit'), '1,83,000');
        await capture(t, '06_${kind.code}_report_right');
        await t.binding.handlePopRoute();
        await t.pumpAndSettle();
        expect(find.byKey(const Key('vt_report_dialog')), findsOneWidget);
        await tap(t, 'vt_report_ok');
        expect(horizontal.offset, horizontal.position.maxScrollExtent);
        expect(h.updates, isEmpty);
        await tap(t, 'va_back');
        expect(find.byType(VoucherApprovalScreen), findsNothing);
        await finish(t);
      },
    );
    for (final action in VoucherApprovalAction.values) {
      check(
        '${kind.code} ${action.name}: NO does nothing, repeated YES sends one native update',
        (t) async {
          final h = ApprovalHarness();
          await host(t, h, kind: kind);
          await select(
            t,
            h,
            kind,
            action == VoucherApprovalAction.approve ? 1 : 0,
          );
          await tap(t, 'va_action');
          expect(find.text('${action.label}!'), findsOneWidget);
          await capture(t, '07_${kind.code}_${action.name}_confirmation');
          await tap(t, 'va_no');
          expect(h.updates, isEmpty);
          await tap(t, 'va_action');
          final yes =
              t.widget<TextButton>(find.byKey(const Key('va_yes'))).onPressed!;
          yes();
          yes();
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          expect(h.updates.length, 1);
          expect(h.updates.single.headers['P_APPROVE_FLAG'], action.flag);
          expect(find.byKey(const Key('va_number')), findsNothing);
          expect(find.byKey(const Key('va_detail')), findsNothing);
          expect(
            txt(t, 'va_pending'),
            action == VoucherApprovalAction.approve ? '0' : '2',
          );
          expect(
            txt(t, 'va_approved'),
            action == VoucherApprovalAction.approve ? '4' : '2',
          );
          expect(
            h.transport.requests.where(
              (r) => r.uri.pathSegments.last == 'LoginLog',
            ),
            isEmpty,
          );
          await finish(t);
        },
      );
    }
  }
  check(
    'search validation, Done, missing results, suffix query, Clear and actual row selection',
    (t) async {
      final h = ApprovalHarness();
      await host(t, h);
      await tap(t, 'va_select');
      for (final query in ['', '.123', '12', 'EXAMPLE.CV.123']) {
        await t.enterText(find.byKey(const Key('va_query')), query);
        await tap(t, 'va_search');
        expect(find.byKey(const Key('va_validation')), findsOneWidget);
      }
      expect(
        h.approvalReads.where(
          (r) => r.uri.pathSegments.last == 'getVoucherSelectListBySearch',
        ),
        isEmpty,
      );
      await t.enterText(find.byKey(const Key('va_query')), 'ddd');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(
        h.approvalReads.where(
          (r) => r.uri.pathSegments.last == 'getVoucherSelectListBySearch',
        ),
        isEmpty,
      );
      await tap(t, 'va_search');
      expect(find.byKey(const Key('va_picker_empty')), findsOneWidget);
      expect(find.byKey(const Key('va_latest')), findsNothing);
      await capture(t, '08_search_empty');
      await tap(t, 'va_clear');
      expect(find.byKey(const Key('va_latest')), findsOneWidget);
      expect(
        t.widget<TextField>(find.byKey(const Key('va_query'))).controller!.text,
        isEmpty,
      );
      await t.enterText(find.byKey(const Key('va_query')), '00002');
      await tap(t, 'va_search');
      expect(h.approvalReads.last.uri.queryParameters, {
        'v_type': 'CV',
        'p_vm_no': '00002',
      });
      await capture(t, '09_search_result');
      await tap(t, 'va_choice_${h.choice(VoucherApprovalKind.credit, 1).id}');
      expect(txt(t, 'va_status'), 'Pending');
      expect(find.text('Disapproved By:'), findsOneWidget);
      expect(find.text('Disapproved Time:'), findsOneWidget);
      expect(find.text('APPROVE'), findsOneWidget);
      await capture(t, '10_previously_disapproved_pending');
      await finish(t);
    },
  );
  check(
    'empty latest list has zero counts and can search without an invented prefix',
    (t) async {
      final h = ApprovalHarness(),
          old = h.choices[VoucherApprovalKind.credit]!.first;
      h.choices[VoucherApprovalKind.credit] = [];
      h.onApprovalGet =
          (u) async =>
              u.pathSegments.last == 'getVoucherSelectListBySearch'
                  ? h.page([old])
                  : null;
      await host(t, h);
      expect(txt(t, 'va_pending'), '0');
      expect(txt(t, 'va_approved'), '0');
      await tap(t, 'va_select');
      expect(txt(t, 'va_prefix'), '');
      await t.enterText(find.byKey(const Key('va_query')), '001');
      await tap(t, 'va_search');
      await tap(t, 'va_choice_${old['vm_id']}');
      expect(find.byKey(const Key('va_detail')), findsOneWidget);
      expect(h.updates, isEmpty);
      await finish(t);
    },
  );
  check(
    'search Retry reloads results and Back/Cancel wait for the active read',
    (t) async {
      final h = ApprovalHarness(), pending = Completer<JsonMap>();
      var calls = 0;
      h.onApprovalGet = (u) async {
        if (u.pathSegments.last != 'getVoucherSelectListBySearch') return null;
        if (calls++ == 0) throw const AppFailure('Synthetic search error');
        return pending.future;
      };
      await host(t, h);
      await tap(t, 'va_select');
      await t.enterText(find.byKey(const Key('va_query')), '00002');
      await tap(t, 'va_search');
      expect(find.byKey(const Key('va_search_error')), findsOneWidget);
      await tap(t, 'va_search_retry', settle: false);
      expect(
        t
            .widget<TextButton>(find.byKey(const Key('va_picker_cancel')))
            .onPressed,
        isNull,
      );
      await t.binding.handlePopRoute();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('va_picker')), findsOneWidget);
      pending.complete(h.page([h.choices[VoucherApprovalKind.credit]![1]]));
      await t.pumpAndSettle();
      await tap(t, 'va_choice_${h.choice(VoucherApprovalKind.credit, 1).id}');
      expect(txt(t, 'va_status'), 'Pending');
      expect(h.updates, isEmpty);
      await finish(t);
    },
  );
  check(
    'picker controls and validation remain usable above a small-screen keyboard',
    (t) async {
      final h = ApprovalHarness();
      await host(t, h, size: const Size(320, 568));
      await tap(t, 'va_select');
      t.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(t.view.resetViewInsets);
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('va_query')), '12');
      await tap(t, 'va_search');
      expect(find.byKey(const Key('va_validation')), findsOneWidget);
      await capture(t, '18_keyboard_validation');
      await tap(t, 'va_picker_cancel');
      t.view.resetViewInsets();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(h.updates, isEmpty);
      await finish(t);
    },
  );
  check('Debit approval blocks unequal debit/credit with native Warning', (
    t,
  ) async {
    final h = ApprovalHarness();
    h.ledgerFor(VoucherApprovalKind.debit, 1)[0]['vd_dr_amt'] = '139.05';
    await host(t, h, kind: VoucherApprovalKind.debit);
    await select(t, h, VoucherApprovalKind.debit, 1);
    await tap(t, 'va_action');
    expect(find.text('Warning!'), findsOneWidget);
    expect(
      find.text('Total Debit Amount is not equal to Total Credit Amount'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('va_confirmation')), findsNothing);
    expect(h.updates, isEmpty);
    await capture(t, '11_debit_imbalance');
    await tap(t, 'va_message_ok');
    await finish(t);
  });
  check('changed ledger after YES requires selecting again and never writes', (
    t,
  ) async {
    final h = ApprovalHarness();
    await host(t, h);
    await select(t, h, VoucherApprovalKind.credit, 1);
    await tap(t, 'va_action');
    h.ledgerFor(VoucherApprovalKind.credit, 1)[0]['vd_dr_amt'] = '183001';
    await tap(t, 'va_yes');
    expect(
      find.text('This voucher changed. Please select it again.'),
      findsOneWidget,
    );
    expect(h.updates, isEmpty);
    await tap(t, 'va_message_ok');
    expect(find.byKey(const Key('va_detail')), findsNothing);
    expect(txt(t, 'va_pending'), '1');
    await finish(t);
  });
  check(
    'fresh permission revocation blocks a retained confirmation before POST',
    (t) async {
      final h = ApprovalHarness();
      await host(t, h);
      await select(t, h, VoucherApprovalKind.credit, 1);
      await tap(t, 'va_action');
      h.adminData['acc_dashboard'] = '0';
      await tap(t, 'va_yes');
      expect(h.updates, isEmpty);
      expect(find.byKey(const Key('va_detail')), findsNothing);
      expect(
        find.text('Accounts access is not available for this account.'),
        findsOneWidget,
      );
      await finish(t);
    },
  );
  check(
    'uncertain committed POST Retry reloads status and cannot submit again',
    (t) async {
      final h = ApprovalHarness();
      h.onApprovalPost = (_, headers) async {
        h.applyUpdate(headers);
        throw const AppFailure(
          'Synthetic lost response',
          kind: FailureKind.network,
        );
      };
      await host(t, h);
      await select(t, h, VoucherApprovalKind.credit, 1);
      await tap(t, 'va_action');
      await tap(t, 'va_yes');
      expect(find.byKey(const Key('va_error')), findsOneWidget);
      expect(h.updates.length, 1);
      await capture(t, '12_unconfirmed_update');
      await tap(t, 'va_error_retry');
      expect(txt(t, 'va_pending'), '0');
      expect(txt(t, 'va_approved'), '4');
      expect(h.updates.length, 1);
      expect(find.byKey(const Key('va_action')), findsNothing);
      await finish(t);
    },
  );
  check('initial error Retry only reloads latest vouchers', (t) async {
    final h = ApprovalHarness();
    var fail = true;
    h.onApprovalGet = (u) async {
      if (u.pathSegments.last == 'getVoucherSelectListHundred' && fail) {
        fail = false;
        throw const AppFailure('Synthetic read error');
      }
      return null;
    };
    await host(t, h);
    expect(find.byKey(const Key('va_error')), findsOneWidget);
    await capture(t, '13_initial_error');
    await tap(t, 'va_error_retry');
    expect(txt(t, 'va_pending'), '1');
    expect(h.updates, isEmpty);
    await finish(t);
  });
  check('detail Retry and Cancel cannot leave previous voucher data visible', (
    t,
  ) async {
    final h = ApprovalHarness();
    var fail = true;
    h.onApprovalGet = (u) async {
      if (u.pathSegments.last == 'getVoucherDetails' && fail)
        throw const AppFailure('Synthetic detail error');
      return null;
    };
    await host(t, h);
    await select(t, h, VoucherApprovalKind.credit, 0);
    expect(find.byKey(const Key('va_detail')), findsNothing);
    fail = false;
    await tap(t, 'va_error_retry');
    expect(txt(t, 'va_status'), 'Approved');
    fail = true;
    await select(t, h, VoucherApprovalKind.credit, 1);
    await tap(t, 'va_error_cancel');
    expect(find.byKey(const Key('va_detail')), findsNothing);
    expect(find.byKey(const Key('va_number')), findsNothing);
    expect(h.updates, isEmpty);
    await finish(t);
  });
  check(
    'empty details are readable as an empty state and cannot approve or open report',
    (t) async {
      final h = ApprovalHarness();
      h.ledgers[h.choice(VoucherApprovalKind.credit, 0).id] = [];
      await host(t, h);
      await select(t, h, VoucherApprovalKind.credit, 0);
      expect(find.text('No Voucher Details Found'), findsOneWidget);
      expect(find.byKey(const Key('va_action')), findsNothing);
      expect(find.byKey(const Key('va_report')), findsNothing);
      await finish(t);
    },
  );
  check(
    'a long latest-100 list scrolls to its actual last voucher and remains selectable',
    (t) async {
      final h = ApprovalHarness(), kind = VoucherApprovalKind.debit;
      h.choices[kind] = List.generate(100, (i) => approvalChoice(kind, i + 1));
      for (final choice in h.choices[kind]!) {
        h.ledgers[choice['vm_id'] as String] = approvalLedger(choice);
      }
      await host(t, h, kind: kind);
      expect(txt(t, 'va_approved'), '100');
      await tap(t, 'va_select');
      await capture(t, '17_debit_latest_100');
      final key = 'va_choice_${h.choice(kind, 99).id}';
      await t.scrollUntilVisible(
        find.byKey(Key(key)),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('va_choices')),
          matching: find.byType(Scrollable),
        ),
      );
      await tap(t, key);
      expect(txt(t, 'va_number'), h.choice(kind, 99).number);
      await finish(t);
    },
  );
  check(
    'background invalidates confirmation and resume clears selection without LoginLog',
    (t) async {
      final h = ApprovalHarness();
      await host(t, h);
      await select(t, h, VoucherApprovalKind.credit, 1);
      await tap(t, 'va_action');
      final oldYes =
          t.widget<TextButton>(find.byKey(const Key('va_yes'))).onPressed!;
      pause(t);
      await t.pump();
      resume(t);
      await t.pumpAndSettle();
      oldYes();
      await t.pumpAndSettle();
      expect(h.updates, isEmpty);
      expect(find.byKey(const Key('va_confirmation')), findsNothing);
      expect(find.byKey(const Key('va_detail')), findsNothing);
      expect(
        h.transport.requests.where(
          (r) => r.uri.pathSegments.last == 'LoginLog',
        ),
        isEmpty,
      );
      await finish(t);
    },
  );
  check(
    'resume during a pending POST waits for completion then refreshes without resending',
    (t) async {
      final h = ApprovalHarness(), pending = Completer<JsonMap>();
      Map<String, String>? sent;
      h.onApprovalPost = (_, headers) async {
        sent = headers;
        return pending.future;
      };
      await host(t, h);
      await select(t, h, VoucherApprovalKind.credit, 1);
      await tap(t, 'va_action');
      await tap(t, 'va_yes', settle: false);
      expect(h.updates.length, 1);
      pause(t);
      await t.pump();
      resume(t);
      await t.pump(const Duration(milliseconds: 100));
      expect(h.updates.length, 1);
      h.applyUpdate(sent!);
      pending.complete({'string_out': 'Successfully Created'});
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(h.updates.length, 1);
      expect(txt(t, 'va_pending'), '0');
      await finish(t);
    },
  );
  check('late detail completion cannot overwrite a newly resumed list', (
    t,
  ) async {
    final h = ApprovalHarness(), pending = Completer<JsonMap>();
    final old = h.page([
      {'voucher_list': h.ledgerFor(VoucherApprovalKind.credit, 0)},
    ]);
    h.onApprovalGet =
        (u) async =>
            u.pathSegments.last == 'getVoucherDetails' ? pending.future : null;
    await host(t, h);
    await select(t, h, VoucherApprovalKind.credit, 0, settle: false);
    pause(t);
    await t.pump();
    resume(t);
    await t.pumpAndSettle();
    pending.complete(old);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.byKey(const Key('va_detail')), findsNothing);
    expect(txt(t, 'va_pending'), '1');
    await finish(t);
  });
  check('logout from the real app closes an owned approval confirmation', (
    t,
  ) async {
    final h = ApprovalHarness();
    await host(t, h, app: true);
    await select(t, h, VoucherApprovalKind.credit, 1);
    await tap(t, 'va_action');
    await h.auth.logout();
    await t.pumpAndSettle();
    expect(find.byType(VoucherApprovalScreen), findsNothing);
    expect(find.byKey(const Key('va_confirmation')), findsNothing);
    expect(h.updates, isEmpty);
    await finish(t);
  });
  for (final e
      in {
        'small': const Size(320, 568),
        'landscape': const Size(844, 390),
        'large_text': const Size(393, 852),
      }.entries) {
    check(
      'picker, approval ledger and report render without overflow at ${e.key}',
      (t) async {
        final h = ApprovalHarness();
        await host(
          t,
          h,
          kind: VoucherApprovalKind.journal,
          size: e.value,
          zoom: e.key == 'large_text' ? 1.8 : 1,
        );
        await tap(t, 'va_select');
        await capture(t, '14_${e.key}_picker');
        await tap(
          t,
          'va_choice_${h.choice(VoucherApprovalKind.journal, 0).id}',
        );
        await capture(t, '15_${e.key}_detail');
        await tap(t, 'va_report');
        await capture(t, '16_${e.key}_report');
        await tap(t, 'vt_report_ok');
        expect(t.takeException(), isNull);
        await finish(t);
      },
    );
  }
}

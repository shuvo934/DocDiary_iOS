import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/features/accounts/voucher_transaction/native_voucher_controls.dart';
import 'package:docdiary_ios/features/accounts/voucher_transaction/native_voucher_tables.dart';
import 'package:docdiary_ios/features/accounts/voucher_transaction/payment_invoice_screen.dart';
import 'package:docdiary_ios/features/accounts/voucher_transaction/voucher_transaction_screen.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'voucher_test_support.dart';

Future<void> press(WidgetTester t, Finder finder, {bool settle = true}) async {
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

Future<void> keyTap(WidgetTester t, String key, {bool settle = true}) async =>
    press(t, find.byKey(Key(key)), settle: settle);
Future<void> link(
  WidgetTester t,
  String number, {
  String date = '01-OCT-26',
  bool settle = true,
}) async => keyTap(t, 'vt_voucher_${date}_$number', settle: settle);
String text(WidgetTester t, String key) =>
    t.widget<Text>(find.byKey(Key(key))).data!;
ScrollController horizontal(WidgetTester t, String key) =>
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
  VoucherHarness h, {
  Size size = const Size(393, 852),
  double zoom = 1,
  bool app = false,
  bool chart = false,
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
      key: const Key('vt_capture'),
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
                          key: const Key('open_voucher'),
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => VoucherTransactionScreen(
                                        auth: h.auth,
                                        repository: h.vouchers,
                                        firstDate: '01-Oct-26',
                                        lastDate: '31-Oct-26',
                                      ),
                                ),
                              ),
                          child: const Text('Synthetic parent'),
                        ),
                      ),
                ),
              ),
    ),
  );
  await t.pumpAndSettle();
  if (app) {
    await keyTap(t, 'dashboard_nav_management');
    await keyTap(t, 'management_accounts');
    if (chart) {
      await keyTap(t, 'accounts_period_lastMonth');
      await keyTap(t, 'accounts_voucher_pie', settle: settle);
    } else {
      await keyTap(t, 'accounts_menu');
      await keyTap(t, 'accounts_menu_voucherTransaction', settle: settle);
    }
  } else {
    await keyTap(t, 'open_voucher', settle: settle);
  }
}

Future<void> finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_VOUCHER_CAPTURE_DIR'];
  if (dir == null) return;
  await t.pumpAndSettle();
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('vt_capture')),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('$dir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> filter(WidgetTester t, int index) async {
  await keyTap(t, 'vt_type');
  await keyTap(t, 'vt_type_option_$index');
}

Future<void> chooseDay(WidgetTester t, bool begin, String day) async {
  await keyTap(t, begin ? 'vt_begin' : 'vt_end');
  await press(
    t,
    find
        .descendant(
          of: find.byKey(const Key('vt_date_picker')),
          matching: find.text(day),
        )
        .last,
  );
  await press(
    t,
    find
        .descendant(
          of: find.byKey(const Key('vt_date_picker')),
          matching: find.text('OK'),
        )
        .last,
  );
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
          'Archivo': ['Archivo[wdth,wght].ttf'],
          'PatuaOne': ['PatuaOne-Regular.ttf'],
          'DocDiaryBengali': ['NotoSansBengali.ttf'],
        }.entries) {
      final loader = FontLoader(e.key);
      for (final name in e.value) {
        loader.addFont(rootBundle.load('assets/fonts/$name'));
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
  check(
    'Dashboard chart opens real Voucher Transaction with selected native dates',
    (t) async {
      final h = VoucherHarness();
      await host(t, h, app: true, chart: true);
      expect(find.byType(VoucherTransactionScreen), findsOneWidget);
      expect(text(t, 'vt_count'), 'Total Voucher : 4');
      expect(h.transactionReads.last.uri.queryParameters, {
        'st_date': '01-Oct-26',
        'end_date': '31-Oct-26',
      });
      expect(
        find.text('Voucher Transaction List (01-Oct-26 to 31-Oct-26)'),
        findsOneWidget,
      );
      await capture(t, '01_voucher_transactions_top');
      await keyTap(t, 'vt_back');
      expect(find.byType(VoucherTransactionScreen), findsNothing);
      await finish(t);
    },
  );
  check('Accounts menu opens Today and every read stays GET', (t) async {
    final h = VoucherHarness();
    await host(t, h, app: true);
    expect(h.transactionReads.last.uri.queryParameters, {
      'st_date': '02-Nov-26',
      'end_date': '02-Nov-26',
    });
    expect(h.transactionReads.every((r) => r.method == 'GET'), true);
    await finish(t);
  });
  check(
    'table scrolls left/right with aligned exact footer and native grouping',
    (t) async {
      final h = VoucherHarness();
      await host(t, h);
      final table = t.widget<NativeVoucherTable>(
        find.byType(NativeVoucherTable),
      );
      expect(table.data.days.first.entries[1].lines.first.debitText, '2620');
      final hScroll = horizontal(t, 'vt_horizontal');
      hScroll.jumpTo(hScroll.position.maxScrollExtent);
      await t.pumpAndSettle();
      await capture(t, '02_voucher_transactions_right');
      final scroll = horizontal(t, 'vt_scroll');
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await t.pumpAndSettle();
      expect(text(t, 'vt_total_debit'), '৳ 8,718.1');
      expect(text(t, 'vt_total_credit'), '৳ 8,718.1');
      await capture(t, '03_totals_right');
      hScroll.jumpTo(0);
      await t.pumpAndSettle();
      await capture(t, '04_totals_left');
      await finish(t);
    },
  );
  check(
    'type menu filters locally, updates chart and clearing restores every voucher',
    (t) async {
      final h = VoucherHarness();
      await host(t, h);
      await keyTap(t, 'vt_type');
      await capture(t, '05_voucher_type_menu');
      await keyTap(t, 'vt_type_option_1');
      expect(
        t.widget<VoucherTypeField>(find.byType(VoucherTypeField)).selected,
        'CV (Receive)',
      );
      expect(text(t, 'vt_count'), 'Total Voucher : 2');
      expect(text(t, 'vt_total_debit'), '৳ 4,398.1');
      expect(
        find.byKey(const Key('vt_voucher_01-OCT-26_C-STAR.DV.03399.26')),
        findsNothing,
      );
      expect(h.transactionReads.length, 2);
      await filter(t, 0);
      expect(text(t, 'vt_count'), 'Total Voucher : 4');
      expect(h.transactionReads.length, 2);
      await finish(t);
    },
  );
  check('system Back closes open type menu before leaving the screen', (
    t,
  ) async {
    final h = VoucherHarness();
    await host(t, h);
    await keyTap(t, 'vt_type');
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(VoucherTransactionScreen), findsOneWidget);
    expect(find.byKey(const Key('vt_type_option_1')), findsNothing);
    await keyTap(t, 'vt_back');
    expect(find.byType(VoucherTransactionScreen), findsNothing);
    await finish(t);
  });
  check(
    'date picker has native minimum, valid change reloads/reset filter, invalid range clears chosen field',
    (t) async {
      final h = VoucherHarness();
      await host(t, h);
      await filter(t, 1);
      await keyTap(t, 'vt_begin');
      expect(
        t
            .widget<DatePickerDialog>(find.byKey(const Key('vt_date_picker')))
            .firstDate,
        DateTime(2026, 9),
      );
      await capture(t, '06_date_picker');
      await press(
        t,
        find
            .descendant(
              of: find.byKey(const Key('vt_date_picker')),
              matching: find.text('15'),
            )
            .last,
      );
      await press(
        t,
        find
            .descendant(
              of: find.byKey(const Key('vt_date_picker')),
              matching: find.text('OK'),
            )
            .last,
      );
      expect(h.transactionReads.last.uri.queryParameters, {
        'st_date': '15-OCT-26',
        'end_date': '31-Oct-26',
      });
      expect(
        t.widget<VoucherTypeField>(find.byType(VoucherTypeField)).selected,
        '',
      );
      final calls = h.transactionReads.length;
      await chooseDay(t, false, '5');
      expect(find.byKey(const Key('vt_invalid_range')), findsOneWidget);
      expect(
        t.widget<VoucherDateField>(find.byKey(const Key('vt_end'))).value,
        '',
      );
      expect(h.transactionReads.length, calls);
      await capture(t, '07_invalid_range');
      await keyTap(t, 'vt_end');
      await press(
        t,
        find
            .descendant(
              of: find.byKey(const Key('vt_date_picker')),
              matching: find.text('CANCEL'),
            )
            .last,
      );
      expect(h.transactionReads.length, calls);
      await finish(t);
    },
  );
  check(
    'PRM link opens read-only invoice with native service lines and totals; Back keeps list position',
    (t) async {
      final h = VoucherHarness();
      await host(t, h);
      await link(t, testDecimal, date: '02-OCT-26');
      expect(find.byType(PaymentInvoiceScreen), findsOneWidget);
      expect(find.text('PR.26.000029'), findsOneWidget);
      expect(text(t, 'invoice_subtotal'), '৳ 3,600');
      expect(text(t, 'invoice_charge'), '৳ 108');
      expect(text(t, 'invoice_grandtotal'), '৳ 3,708');
      await capture(t, '08_invoice_top');
      final scroll = horizontal(t, 'invoice_scroll');
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await t.pumpAndSettle();
      await capture(t, '09_invoice_bottom');
      await keyTap(t, 'invoice_back');
      expect(find.byType(PaymentInvoiceScreen), findsNothing);
      expect(text(t, 'vt_count'), 'Total Voucher : 4');
      expect(
        h.transactionReads
            .where((r) => r.uri.path.endsWith('getNewVoucherList'))
            .length,
        1,
      );
      expect(horizontal(t, 'vt_scroll').offset, greaterThan(0));
      await finish(t);
    },
  );
  check(
    'single invoice and numeric-zero/month/discount presentation match native branches',
    (t) async {
      final h = VoucherHarness();
      await host(t, h);
      await link(t, testJv);
      expect(find.byKey(const Key('invoice_serial_1')), findsNothing);
      expect(text(t, 'invoice_grandtotal'), '৳ 4,120');
      await capture(t, '10_invoice_single');
      await keyTap(t, 'invoice_back');
      h.invoiceRows = paymentInvoiceFixture('PR.26.000016');
      h.invoiceRows!.first.addAll({
        'prd_rate': '0.00',
        'amt': '0.0',
        'prd_discount_amt': '0',
        'prd_service_charge_pct': '0',
        'prd_payment_for_month': 'NOV-26',
      });
      await link(t, testJv);
      expect(find.text('Free of Cost'), findsNWidgets(2));
      expect(find.byKey(const Key('invoice_month_0')), findsOneWidget);
      expect(find.byKey(const Key('invoice_charge')), findsNothing);
      expect(find.byKey(const Key('invoice_discount')), findsNothing);
      await finish(t);
    },
  );
  check(
    'AV link opens owned voucher dialog with horizontal table and exact totals',
    (t) async {
      final h = VoucherHarness();
      await host(t, h);
      await link(t, testDv);
      expect(find.byKey(const Key('vt_report_dialog')), findsOneWidget);
      expect(find.text('Debit Voucher'), findsOneWidget);
      expect(find.text('Example Payee'), findsOneWidget);
      await capture(t, '11_debit_voucher_left');
      final controller = horizontal(t, 'vt_report_horizontal');
      controller.jumpTo(controller.position.maxScrollExtent);
      await t.pumpAndSettle();
      expect(text(t, 'vt_report_debit'), '200');
      expect(text(t, 'vt_report_credit'), '200');
      await capture(t, '12_debit_voucher_right');
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byKey(const Key('vt_report_dialog')), findsOneWidget);
      await keyTap(t, 'vt_report_ok');
      expect(find.byKey(const Key('vt_report_dialog')), findsNothing);
      expect(
        h.transactionReads
            .where((r) => r.uri.path.endsWith('getNewVoucherList'))
            .length,
        1,
      );
      await finish(t);
    },
  );
  check(
    'AV report failure retries inside dialog; empty report is safe and closable',
    (t) async {
      final h = VoucherHarness();
      h.onVoucherGet = (u) async {
        if (u.path.endsWith('getVoucherReport')) {
          throw const AppFailure(
            'Synthetic report failure',
            kind: FailureKind.network,
          );
        }
        return null;
      };
      await host(t, h);
      await link(t, testDv);
      expect(find.byKey(const Key('vt_report_error')), findsOneWidget);
      h.onVoucherGet = null;
      await keyTap(t, 'vt_report_retry');
      expect(text(t, 'vt_report_debit'), '200');
      await keyTap(t, 'vt_report_ok');
      h.reportRows = [];
      await link(t, testDv);
      expect(find.text('No Voucher Details Found'), findsOneWidget);
      await keyTap(t, 'vt_report_ok');
      await finish(t);
    },
  );
  check(
    'wrong invoice identity displays Retry/Exit and never renders returned patient details',
    (t) async {
      final h = VoucherHarness();
      await host(t, h);
      h.invoiceRows = paymentInvoiceFixture('WRONG');
      await link(t, testJv);
      expect(find.byKey(const Key('invoice_error')), findsOneWidget);
      expect(find.byKey(const Key('invoice_code')), findsNothing);
      expect(find.text('Example Patient'), findsNothing);
      h.invoiceRows = null;
      await keyTap(t, 'invoice_error_retry');
      expect(find.byKey(const Key('invoice_code')), findsOneWidget);
      await finish(t);
    },
  );
  check(
    'list read failure is atomic and Retry keeps dates; Exit returns to parent',
    (t) async {
      final h = VoucherHarness();
      h.onVoucherGet = (u) async {
        if (u.path.endsWith('getNewVoucherList')) {
          throw const AppFailure(
            'Synthetic list failure',
            kind: FailureKind.network,
          );
        }
        return null;
      };
      await host(t, h);
      expect(find.byKey(const Key('vt_error')), findsOneWidget);
      expect(find.byKey(const Key('vt_count')), findsNothing);
      await capture(t, '13_load_error');
      h.onVoucherGet = null;
      await keyTap(t, 'vt_error_retry');
      expect(text(t, 'vt_count'), 'Total Voucher : 4');
      await finish(t);
    },
  );
  check('initial list loading blocks Back and duplicate reads', (t) async {
    final h = VoucherHarness(), pending = Completer<void>();
    h.onVoucherGet = (u) async {
      if (u.path.endsWith('getNewVoucherList')) await pending.future;
      return null;
    };
    await host(t, h, settle: false);
    expect(find.byKey(const Key('vt_loading')), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pump();
    expect(find.byType(VoucherTransactionScreen), findsOneWidget);
    pending.complete();
    await t.pumpAndSettle();
    expect(text(t, 'vt_count'), 'Total Voucher : 4');
    expect(h.transactionReads.length, 2);
    await finish(t);
  });
  check('a retained hidden entry callback cannot bypass a new type filter', (
    t,
  ) async {
    final h = VoucherHarness();
    await host(t, h);
    final old = t.widget<NativeVoucherTable>(find.byType(NativeVoucherTable)),
        hidden = old.data.days.first.entries.last;
    await filter(t, 1);
    old.onEntry(hidden);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('vt_report_dialog')), findsNothing);
    expect(h.transactionReads.length, 2);
    await finish(t);
  });
  check(
    'fresh permission revocation prevents invoice/report calls and clears ledger',
    (t) async {
      final h = VoucherHarness();
      await host(t, h);
      h.adminData['acc_dashboard'] = '0';
      await link(t, testDv);
      expect(find.byKey(const Key('vt_error')), findsOneWidget);
      expect(
        h.transactionReads.where(
          (r) => r.uri.path.endsWith('getVoucherReport'),
        ),
        isEmpty,
      );
      expect(find.byType(NativeVoucherTable), findsNothing);
      await keyTap(t, 'vt_error_exit');
      expect(find.text('Synthetic parent'), findsOneWidget);
      await finish(t);
    },
  );
  check(
    'resume retains selected dates/filter, refreshes values without LoginLog',
    (t) async {
      final h = VoucherHarness();
      await host(t, h);
      await filter(t, 1);
      final posts = h.posts.length;
      pause(t);
      await t.pump();
      h.voucherRows.first['cc'] = '3';
      resume(t);
      await t.pumpAndSettle();
      expect(
        t.widget<VoucherTypeField>(find.byType(VoucherTypeField)).selected,
        'CV (Receive)',
      );
      expect(text(t, 'vt_count'), 'Total Voucher : 3');
      expect(h.transactionReads.length, 4);
      expect(h.posts.length, posts);
      await finish(t);
    },
  );
  check(
    'late voucher-report result cannot overwrite a new foreground response',
    (t) async {
      final h = VoucherHarness(), pending = Completer<void>();
      var first = true;
      h.onVoucherGet = (u) async {
        if (u.path.endsWith('getVoucherReport') && first) {
          first = false;
          await pending.future;
          return {'count': 2, 'items': voucherReportFixture()};
        }
        return null;
      };
      await host(t, h);
      await link(t, testDv, settle: false);
      pause(t);
      await t.pump();
      h.reportRows = [
        for (final row in voucherReportFixture())
          {
            ...row,
            'vd_dr_amt': row['vd_dr_amt'] == '' ? '' : '500',
            'vd_cr_amt': row['vd_cr_amt'] == '' ? '' : '500',
          },
      ];
      resume(t);
      await t.pumpAndSettle();
      expect(text(t, 'vt_report_debit'), '500');
      pending.complete();
      await t.pumpAndSettle();
      expect(text(t, 'vt_report_debit'), '500');
      await finish(t);
    },
  );
  check('logout from real app removes an owned voucher dialog and ledger', (
    t,
  ) async {
    final h = VoucherHarness();
    await host(t, h, app: true);
    await link(t, testDv, date: '02-NOV-26');
    await h.auth.logout();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('vt_report_dialog')), findsNothing);
    expect(find.byType(VoucherTransactionScreen), findsNothing);
    await finish(t);
  });
  check('empty list has No Data chart/message and no stale totals', (t) async {
    final h = VoucherHarness();
    h.ledger = [];
    h.voucherRows = [];
    await host(t, h);
    expect(text(t, 'vt_count'), 'Total Voucher : 0');
    expect(find.byKey(const Key('vt_empty')), findsOneWidget);
    expect(find.byKey(const Key('vt_total_debit')), findsNothing);
    await capture(t, '14_empty');
    await finish(t);
  });
  for (final e
      in {
        'small': (const Size(320, 568), 1.0),
        'landscape': (const Size(852, 393), 1.0),
        'large_text': (const Size(393, 852), 1.8),
      }.entries) {
    check('list, report and invoice remain usable at ${e.key}', (t) async {
      final h = VoucherHarness();
      await host(t, h, size: e.value.$1, zoom: e.value.$2);
      await capture(t, '15_${e.key}_list');
      await link(t, testDv);
      await capture(t, '16_${e.key}_report');
      await keyTap(t, 'vt_report_ok');
      await link(t, testDecimal, date: '02-OCT-26');
      final scroll = horizontal(t, 'invoice_scroll');
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await t.pumpAndSettle();
      await capture(t, '17_${e.key}_invoice');
      expect(text(t, 'invoice_grandtotal'), '৳ 3,708');
      await finish(t);
    });
  }
}

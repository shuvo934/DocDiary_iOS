import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/accounts/accounts_dashboard_screen.dart';
import 'package:docdiary_ios/features/accounts/account_ledger/account_ledger_screen.dart';
import 'package:docdiary_ios/features/accounts/statements/income_expense_screen.dart';
import 'package:docdiary_ios/features/accounts/statements/daily_statement_screen.dart';
import 'package:docdiary_ios/features/accounts/voucher_approval/voucher_approval_models.dart';
import 'package:docdiary_ios/features/accounts/voucher_transaction/voucher_transaction_screen.dart';
import 'package:docdiary_ios/features/accounts/voucher_transaction/payment_invoice_screen.dart';
import 'package:docdiary_ios/features/accounts/voucher_transaction/voucher_report_dialog.dart';
import 'package:docdiary_ios/features/reports/report_pdf_screen.dart';
import 'ledger_widget_test.dart' as ui;
import 'voucher_approval_test_support.dart';
import 'voucher_approval_widget_test.dart' as approval;
import 'statement_test_support.dart';
import 'report_manager_test_support.dart'
    show FakeReportPdfPlatform, FakeReportPdfTransport;
import 'toast_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final native = ToastRecorder();
  setUp(native.install);
  tearDown(native.uninstall);
  setUpAll(() async {
    for (final e
        in <String, List<String>>{
          'Poppins': [
            'Poppins-Regular.ttf',
            'Poppins-Medium.ttf',
            'Poppins-SemiBold.ttf',
            'Poppins-Bold.ttf',
          ],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
          'Ubuntu': ['Ubuntu-Medium.ttf'],
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
          'Archivo': ['Archivo[wdth,wght].ttf'],
          'PatuaOne': ['PatuaOne-Regular.ttf'],
          'RussoOne': ['RussoOne-Regular.ttf'],
          'DocDiaryBengali': ['NotoSansBengali.ttf'],
        }.entries) {
      final loader = FontLoader(e.key);
      for (final f in e.value) {
        loader.addFont(rootBundle.load('assets/fonts/$f'));
      }
      await loader.load();
    }
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  void check(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (t) async {
        final shadows = debugDisableShadows;
        debugDisableShadows = false;
        try {
          await body(t);
        } finally {
          debugDisableShadows = shadows;
        }
      });
  Future<void> statement(
    WidgetTester t,
    StatementHarness h, {
    bool settle = true,
    Size size = const Size(393, 852),
    double zoom = 1,
  }) async {
    await ui.host(
      t,
      h,
      settle: settle,
      size: size,
      zoom: zoom,
      child: IncomeExpenseScreen(auth: h.auth, repository: h.statements),
    );
  }

  Future<void> daily(
    WidgetTester t,
    StatementHarness h,
    FakeReportPdfPlatform platform,
    FakeReportPdfTransport pdf, {
    bool settle = true,
  }) async {
    await ui.host(
      t,
      h,
      settle: settle,
      child: DailyStatementScreen(
        auth: h.auth,
        repository: h.statements,
        platform: platform,
        transportFactory: () => pdf,
      ),
    );
  }

  void scrollTo(WidgetTester t, double value) {
    final c = ui.scrolling(t, 'statement_scroll');
    c.jumpTo(math.min(value, c.position.maxScrollExtent));
  }

  Future<void> waitToast(WidgetTester t, String key) async {
    native.calls.clear();
    await ui.tap(t, key, settle: false);
    expect(native.messages, contains('Please wait while loading'));
  }

  Future<void> systemToast(WidgetTester t) async {
    native.calls.clear();
    await t.binding.handlePopRoute();
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(native.messages, contains('Please wait while loading'));
  }

  check(
    'real app Accounts menu opens Income Expense with native defaults and chart',
    (t) async {
      final h = StatementHarness();
      await ui.host(t, h, app: true);
      await ui.tap(t, 'ledger_back');
      await ui.tap(t, 'accounts_menu');
      await ui.tap(t, 'accounts_menu_incomeExpense');
      expect(find.byType(IncomeExpenseScreen), findsOneWidget);
      expect(ui.text(t, 'statement_amount'), 'Amount : 40,440 (Net Profit)');
      expect(find.text('Level-03 (Account Details)'), findsOneWidget);
      expect(ui.painters(t).single.title, '');
      await ui.capture(t, '01_income_expense_chart');
      scrollTo(t, 235);
      await t.pump();
      await ui.capture(t, '02_statement_level3_left');
      final c = ui.scrolling(t, 'statement_horizontal');
      c.jumpTo(c.position.maxScrollExtent);
      await t.pump();
      await ui.capture(t, '03_statement_level3_right');
      expect(ui.text(t, 'statement_income_total_4'), '৳ 2,86,70,820');
      expect(ui.text(t, 'statement_expense_total_4'), '৳ 2,80,89,966');
      scrollTo(t, 10000);
      await t.pump();
      await ui.capture(t, '04_statement_profit_summary');
      expect(
        [
          ui.text(t, 'statement_profit_0'),
          ui.text(t, 'statement_profit_1'),
          ui.text(t, 'statement_profit_2'),
        ],
        ['৳ 5,40,414', '৳ 40,440', '৳ 5,80,854'],
      );
      await ui.finish(t);
    },
  );
  check('level 1 and 2 regroup locally and keep every total unchanged', (
    t,
  ) async {
    final h = StatementHarness();
    await statement(t, h);
    final reads = h.accountReads.length;
    await ui.tap(t, 'statement_level');
    await ui.capture(t, '05_statement_level_menu');
    await ui.tap(t, 'statement_level_2');
    expect(find.byKey(const Key('statement_expense_row_5')), findsOneWidget);
    expect(find.byKey(const Key('statement_expense_row_6')), findsNothing);
    expect(find.byKey(const Key('statement_income_account_0')), findsNothing);
    scrollTo(t, 230);
    await t.pump();
    await ui.capture(t, '06_statement_level2');
    await ui.tap(t, 'statement_level');
    await ui.tap(t, 'statement_level_1');
    expect(find.byKey(const Key('statement_expense_row_3')), findsOneWidget);
    expect(find.byKey(const Key('statement_expense_row_4')), findsNothing);
    await ui.capture(t, '07_statement_level1');
    expect(ui.text(t, 'statement_profit_2'), '৳ 5,80,854');
    expect(h.accountReads.length, reads);
    await ui.finish(t);
  });
  check(
    'level 3 link opens existing Ledger with selected ID/dates and preserves return state',
    (t) async {
      final h = StatementHarness();
      await statement(t, h);
      scrollTo(t, 220);
      await t.pump();
      final prior = ui.scrolling(t, 'statement_scroll').offset,
          reads =
              h.accountReads
                  .where(
                    (r) => r.uri.pathSegments.last == 'getNIncomeStatement',
                  )
                  .length;
      await ui.tap(t, 'statement_income_account_0');
      expect(find.byType(AccountLedgerScreen), findsOneWidget);
      final read =
          h.accountReads
              .where((r) => r.uri.pathSegments.last == 'getAccLedger')
              .last;
      expect(read.uri.queryParameters, {
        'st_date': '03-Nov-26',
        'end_date': '03-Nov-26',
        'ad_id': 'bank',
      });
      await ui.capture(t, '08_statement_to_account_ledger');
      await ui.tap(t, 'ledger_back');
      expect(find.byType(IncomeExpenseScreen), findsOneWidget);
      expect(ui.scrolling(t, 'statement_scroll').offset, prior);
      expect(
        h.accountReads
            .where((r) => r.uri.pathSegments.last == 'getNIncomeStatement')
            .length,
        reads,
      );
      await ui.finish(t);
    },
  );
  check(
    'date range invalidates only edited field and recovers with a valid date',
    (t) async {
      final h = StatementHarness();
      await statement(t, h);
      await ui.tap(t, 'statement_begin');
      expect(
        t.widget<DatePickerDialog>(find.byType(DatePickerDialog)).firstDate,
        DateTime(2026, 9, 1),
      );
      final reads = h.accountReads.length;
      await t.tap(find.text('4').last);
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      expect(find.text('Date Range is Invalid'), findsOneWidget);
      expect(h.accountReads.length, reads);
      expect(find.byKey(const Key('statement_amount')), findsNothing);
      await ui.capture(t, '09_statement_date_validation');
      await ui.tap(t, 'statement_begin');
      await t.tap(find.text('2').last);
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      expect(
        h.accountReads
            .where((r) => r.uri.pathSegments.last == 'getNIncomeStatement')
            .last
            .uri
            .queryParameters,
        {'begin_date': '02-NOV-26', 'end_date': '03-Nov-26'},
      );
      expect(find.byKey(const Key('statement_amount')), findsOneWidget);
      await ui.finish(t);
    },
  );
  check('net loss and no data follow native labels, colors and zero totals', (
    t,
  ) async {
    final h = StatementHarness();
    h.incomeRows = [
      {'income': '0.1', 'expense': '0.3'},
    ];
    await statement(t, h);
    expect(ui.text(t, 'statement_amount'), 'Amount : 0.2 (Net Loss)');
    await ui.capture(t, '10_statement_net_loss');
    h.incomeRows = [];
    h.statementIncome = [];
    h.statementExpense = [];
    ui.pause(t);
    await t.pump();
    ui.resume(t);
    await t.pumpAndSettle();
    expect(find.text('No Data'), findsOneWidget);
    expect(ui.painters(t).single.title, '');
    expect(ui.text(t, 'statement_amount'), 'Amount : 0 (Break Even Point)');
    expect(ui.text(t, 'statement_income_total_0'), '৳ 0');
    await ui.capture(t, '11_statement_no_data');
    scrollTo(t, 1000);
    await t.pump();
    await ui.capture(t, '12_statement_empty_tables');
    await ui.finish(t);
  });
  check(
    'statement Retry starts complete chain and rapid double Retry cannot pop parent',
    (t) async {
      final h = StatementHarness();
      var fail = true;
      h.onStatementGet = (u) async {
        if (fail && u.pathSegments.last == 'getNExpenseStatement') {
          throw const AppFailure(
            'Synthetic offline',
            kind: FailureKind.network,
          );
        }
        return null;
      };
      await statement(t, h);
      expect(find.byKey(const Key('statement_amount')), findsNothing);
      await ui.capture(t, '13_statement_retry');
      fail = false;
      final retry =
          t
              .widget<TextButton>(
                find.byKey(const Key('statement_error_retry')),
              )
              .onPressed!;
      retry();
      retry();
      await t.pumpAndSettle();
      expect(find.byType(IncomeExpenseScreen), findsOneWidget);
      expect(ui.text(t, 'statement_amount'), 'Amount : 40,440 (Net Profit)');
      await ui.finish(t);
    },
  );
  check(
    'background discards late section response and resume refreshes all three reads',
    (t) async {
      final h = StatementHarness(), gate = Completer<JsonMap>();
      var held = true;
      h.onStatementGet =
          (u) async =>
              held && u.pathSegments.last == 'getNIncomeStatement'
                  ? gate.future
                  : null;
      await statement(t, h, settle: false);
      await waitToast(t, 'statement_back');
      ui.pause(t);
      await t.pump();
      held = false;
      gate.complete(h.page(h.statementIncome));
      await t.pump();
      ui.resume(t);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('statement_amount')), findsOneWidget);
      expect(
        h.accountReads
            .where((r) => r.uri.pathSegments.last == 'getNExpenseStatement')
            .length,
        1,
      );
      await ui.finish(t);
    },
  );
  check(
    'revoked access before account link prevents Ledger opening and removes statement',
    (t) async {
      final h = StatementHarness();
      await statement(t, h);
      h.adminData['acc_dashboard'] = '0';
      h.transport.requests.clear();
      await ui.tap(t, 'statement_income_account_0');
      expect(find.byType(AccountLedgerScreen), findsNothing);
      expect(
        find.text('Accounts access is not available for this account.'),
        findsOneWidget,
      );
      expect(h.accountReads, isEmpty);
      await ui.finish(t);
    },
  );
  check('chart route passes selected period into Income Expense', (t) async {
    final h = StatementHarness();
    await ui.host(
      t,
      h,
      child: AccountsDashboardScreen(auth: h.auth, repository: h.accounts),
    );
    await ui.tap(t, 'accounts_period_lastMonth');
    await ui.tap(t, 'accounts_income_pie');
    final q =
        h.accountReads
            .where((r) => r.uri.pathSegments.last == 'getNIncomeStatement')
            .last
            .uri
            .queryParameters;
    expect(q, {'begin_date': '01-Oct-26', 'end_date': '31-Oct-26'});
    await ui.finish(t);
  });
  for (final frame in [
    (const Size(320, 568), 1.0, 'small'),
    (const Size(393, 852), 2.0, 'large_text'),
    (const Size(852, 393), 1.0, 'landscape'),
  ]) {
    check(
      'statement ${frame.$3} chart, table, menu and summary remain scrollable',
      (t) async {
        final h = StatementHarness();
        await statement(t, h, size: frame.$1, zoom: frame.$2);
        await ui.capture(t, '14_${frame.$3}_statement');
        await ui.tap(t, 'statement_level');
        await ui.capture(t, '15_${frame.$3}_level_menu');
        await ui.tap(t, 'statement_level_2');
        scrollTo(t, 10000);
        await t.pump();
        await ui.capture(t, '16_${frame.$3}_summary');
        expect(t.takeException(), isNull);
        await ui.finish(t);
      },
    );
  }
  check(
    'Daily native menu uses existing PDF view and original download/page/zoom actions',
    (t) async {
      final h = StatementHarness(),
          platform = FakeReportPdfPlatform(),
          pdf = FakeReportPdfTransport();
      await ui.host(
        t,
        h,
        child: AccountsDashboardScreen(
          auth: h.auth,
          repository: h.accounts,
          dailyPlatformFactory: () => platform,
          dailyTransportFactory: () => pdf,
        ),
      );
      await ui.tap(t, 'accounts_menu');
      await ui.tap(t, 'accounts_menu_dailyStatement');
      expect(find.byType(ReportPdfScreen), findsOneWidget);
      expect(find.text('Daily Statement'), findsOneWidget);
      expect(pdf.calls.single.query, contains('DAILY_STATEMENT.rep'));
      expect(pdf.calls.single.query, isNot(contains('CIDID')));
      expect(
        h.transport.requests.where(
          (r) => r.uri.pathSegments.last == 'getDeptd',
        ),
        isEmpty,
      );
      await ui.capture(t, '17_daily_existing_pdf_viewer');
      await ui.tap(t, 'report_pdf_next');
      expect(platform.pages, [1]);
      await ui.tap(t, 'report_pdf_zoom_in');
      expect(platform.zooms, [true]);
      await ui.tap(t, 'report_pdf_download');
      final confirm =
          t
              .widget<TextButton>(find.byKey(const Key('report_download_yes')))
              .onPressed!;
      confirm();
      confirm();
      await t.pumpAndSettle();
      expect(platform.saves, 1);
      await ui.tap(t, 'report_close');
      expect(find.byType(AccountsDashboardScreen), findsOneWidget);
      await ui.finish(t);
    },
  );
  check('Daily configuration Retry recovers before opening the PDF viewer', (
    t,
  ) async {
    final h = StatementHarness(),
        platform = FakeReportPdfPlatform(),
        pdf = FakeReportPdfTransport();
    var failed = true;
    h.onStatementGet =
        (u) async =>
            failed && u.pathSegments.last == 'getUrlData' ? h.page([]) : null;
    await daily(t, h, platform, pdf);
    expect(pdf.calls, isEmpty);
    await ui.capture(t, '18_daily_config_error');
    failed = false;
    await ui.tap(t, 'daily_error_retry');
    expect(find.byType(ReportPdfScreen), findsOneWidget);
    expect(pdf.calls.length, 1);
    await ui.finish(t);
  });
  check('Daily PDF download failure stays in existing Retry/Exit flow', (
    t,
  ) async {
    final h = StatementHarness(),
        platform = FakeReportPdfPlatform(),
        pdf = FakeReportPdfTransport();
    var fail = true;
    pdf.onGet = () async {
      if (fail) {
        throw const AppFailure(
          'Synthetic PDF offline',
          kind: FailureKind.network,
        );
      }
      return Uint8List.fromList('%PDF-1.7 synthetic'.codeUnits);
    };
    await daily(t, h, platform, pdf);
    expect(find.byKey(const Key('report_error_dialog')), findsOneWidget);
    await ui.capture(t, '19_daily_pdf_error');
    fail = false;
    await ui.tap(t, 'report_error_retry');
    expect(pdf.calls.length, 2);
    await ui.finish(t);
  });
  check('Daily configuration and PDF loading Back actions show native toast', (
    t,
  ) async {
    final h = StatementHarness(),
        platform = FakeReportPdfPlatform(),
        pdf = FakeReportPdfTransport(),
        gate = Completer<JsonMap>();
    var held = true;
    h.onStatementGet =
        (u) async =>
            held && u.pathSegments.last == 'getUrlData' ? gate.future : null;
    await daily(t, h, platform, pdf, settle: false);
    await waitToast(t, 'daily_back');
    await systemToast(t);
    final download = Completer<Uint8List>();
    pdf.onGet = () => download.future;
    held = false;
    gate.complete(h.page(h.configRows));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await waitToast(t, 'report_close');
    await systemToast(t);
    expect(find.byType(ReportPdfScreen), findsOneWidget);
    platform.autoLoad = false;
    download.complete(Uint8List.fromList('%PDF-1.7 synthetic'.codeUnits));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await waitToast(t, 'report_close');
    await systemToast(t);
    platform.loaded!(3);
    await t.pumpAndSettle();
    await ui.finish(t);
  });
  check('Daily resume uses fresh Accounts access before another PDF read', (
    t,
  ) async {
    final h = StatementHarness(),
        platform = FakeReportPdfPlatform(),
        pdf = FakeReportPdfTransport();
    await daily(t, h, platform, pdf);
    h.adminData['acc_dashboard'] = '0';
    ui.pause(t);
    await t.pump();
    ui.resume(t);
    await t.pumpAndSettle();
    expect(pdf.calls.length, 1);
    expect(
      find.text('Daily Statement is not available for this account.'),
      findsWidgets,
    );
    expect(find.byKey(const Key('report_error_dialog')), findsOneWidget);
    await ui.finish(t);
  });
  check(
    'Accounts Dashboard loading Back, system Back and Menu each show feedback',
    (t) async {
      final h = StatementHarness(), gate = Completer<JsonMap>();
      var held = true;
      h.onStatementGet =
          (u) async =>
              held && u.pathSegments.last == 'getVoucherCount'
                  ? gate.future
                  : null;
      await ui.host(
        t,
        h,
        child: AccountsDashboardScreen(auth: h.auth, repository: h.accounts),
        settle: false,
      );
      await waitToast(t, 'accounts_back');
      await systemToast(t);
      await waitToast(t, 'accounts_menu');
      expect(find.text('Accounts Menu'), findsNothing);
      held = false;
      gate.complete(h.page(h.voucherRows));
      await t.pumpAndSettle();
      await ui.finish(t);
    },
  );
  check('Voucher Transaction loading Back is blocked with feedback', (t) async {
    final h = StatementHarness(), gate = Completer<JsonMap>();
    var held = true;
    h.onStatementGet =
        (u) async =>
            held && u.pathSegments.last == 'getVoucherCount'
                ? gate.future
                : null;
    await ui.host(
      t,
      h,
      child: VoucherTransactionScreen(auth: h.auth, repository: h.vouchers),
      settle: false,
    );
    await waitToast(t, 'vt_back');
    await systemToast(t);
    held = false;
    gate.complete(h.page(h.voucherRows));
    await t.pumpAndSettle();
    await ui.finish(t);
  });
  check('Payment Invoice loading Back uses shared native feedback', (t) async {
    final h = StatementHarness(), gate = Completer<JsonMap>();
    h.onStatementGet =
        (u) async =>
            u.pathSegments.last == 'getPaymentInvoice' ? gate.future : null;
    await ui.host(
      t,
      h,
      child: PaymentInvoiceScreen(
        auth: h.auth,
        repository: h.vouchers,
        paymentCode: 'PR.26.000016',
      ),
      settle: false,
    );
    await waitToast(t, 'invoice_back');
    await systemToast(t);
    gate.complete(h.page([]));
    await t.pumpAndSettle();
    await ui.tap(t, 'invoice_error_exit');
    await ui.finish(t);
  });
  for (final kind in VoucherApprovalKind.values) {
    check('${kind.code} approval loading Back uses shared native feedback', (
      t,
    ) async {
      final h = ApprovalHarness(), gate = Completer<JsonMap>();
      var held = true;
      h.onApprovalGet =
          (u) async =>
              held && u.pathSegments.last == 'getVoucherSelectListHundred'
                  ? gate.future
                  : null;
      await approval.host(t, h, kind: kind, settle: false);
      await waitToast(t, 'va_back');
      await systemToast(t);
      held = false;
      gate.complete(h.page(h.choices[kind]!));
      await t.pumpAndSettle();
      await ui.finish(t);
    });
  }
  check('Ledger loading toolbar and system Back show feedback', (t) async {
    final h = StatementHarness(), gate = Completer<JsonMap>();
    var held = true;
    h.onStatementGet =
        (u) async =>
            held && u.pathSegments.last == 'getAccountList'
                ? gate.future
                : null;
    await ui.host(t, h, settle: false);
    await waitToast(t, 'ledger_back');
    await systemToast(t);
    held = false;
    gate.complete(h.page(h.accountRows));
    await t.pumpAndSettle();
    await ui.finish(t);
  });
  check(
    'user patient picker blocks system Back during search with native toast',
    (t) async {
      final h = StatementHarness(), gate = Completer<JsonMap>();
      var held = true;
      h.onStatementGet =
          (u) async =>
              held && u.pathSegments.last == 'getFiftyPrescriptionList'
                  ? gate.future
                  : null;
      await ui.host(t, h, patient: true);
      await ui.tap(t, 'ledger_patient_select', settle: false);
      await systemToast(t);
      expect(find.byKey(const Key('ledger_patient_picker')), findsOneWidget);
      held = false;
      gate.complete({'pat_pres_list': h.patients});
      await t.pumpAndSettle();
      await ui.capture(t, '20_user_patient_picker_preserved');
      await ui.tap(t, 'ledger_patient_patient');
      expect(find.byKey(const Key('ledger_heading')), findsOneWidget);
      await ui.finish(t);
    },
  );
  check('voucher report loading system Back uses native toast', (t) async {
    final h = StatementHarness(), gate = Completer<JsonMap>();
    var held = true;
    h.onStatementGet =
        (u) async =>
            held && u.pathSegments.last == 'getVoucherReport'
                ? gate.future
                : null;
    await ui.host(t, h);
    await ui.bank(t);
    await ui.tap(t, 'ledger_row_2_1', settle: false);
    expect(find.byType(VoucherReportDialog), findsOneWidget);
    await systemToast(t);
    held = false;
    gate.complete(h.page(h.reportRows));
    await t.pumpAndSettle();
    await ui.tap(t, 'vt_report_ok');
    await ui.finish(t);
  });
  check('approval picker search loading blocks system Back with native toast', (
    t,
  ) async {
    final h = ApprovalHarness(), gate = Completer<JsonMap>();
    var held = true;
    h.onApprovalGet =
        (u) async =>
            held && u.pathSegments.last == 'getVoucherSelectListBySearch'
                ? gate.future
                : null;
    await approval.host(t, h);
    await ui.tap(t, 'va_select');
    await t.enterText(find.byKey(const Key('va_query')), '000');
    await ui.tap(t, 'va_search', settle: false);
    await systemToast(t);
    expect(find.byKey(const Key('va_picker')), findsOneWidget);
    held = false;
    gate.complete(h.page(h.choices[VoucherApprovalKind.credit]!));
    await t.pumpAndSettle();
    await ui.tap(t, 'va_picker_cancel');
    await ui.finish(t);
  });
}

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
import 'package:docdiary_ios/features/accounts/account_ledger/account_ledger_screen.dart';
import 'package:docdiary_ios/features/accounts/accounts_dashboard_screen.dart';
import 'package:docdiary_ios/features/accounts/native_accounts_donut.dart';
import 'package:docdiary_ios/features/accounts/voucher_transaction/voucher_transaction_screen.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'ledger_test_support.dart';

Future<void> tap(WidgetTester t, String key, {bool settle = true}) async {
  final f = find.byKey(Key(key));
  if (f.hitTestable().evaluate().isEmpty) {
    await t.ensureVisible(f);
    await t.pump();
  }
  await t.tap(f);
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }
  expect(t.takeException(), isNull);
}

String text(WidgetTester t, String key) =>
    t.widget<Text>(find.byKey(Key(key))).data!;
ScrollController scrolling(WidgetTester t, String key) =>
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
  LedgerHarness h, {
  bool patient = false,
  bool app = false,
  Widget? child,
  String id = '',
  String first = '',
  String last = '',
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
      key: const Key('ledger_capture'),
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
                          key: const Key('open_ledger'),
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) =>
                                          child ??
                                          AccountLedgerScreen(
                                            auth: h.auth,
                                            repository: h.ledgers,
                                            patientLedger: patient,
                                            accountId: id,
                                            firstDate: first,
                                            lastDate: last,
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
    await tap(t, 'dashboard_nav_management');
    await tap(t, 'management_accounts');
    await tap(t, 'accounts_menu');
    await tap(
      t,
      patient ? 'accounts_menu_patientLedger' : 'accounts_menu_accountLedger',
      settle: settle,
    );
  } else {
    await tap(t, 'open_ledger', settle: settle);
  }
}

Future<void> bank(WidgetTester t) async {
  await tap(t, 'ledger_account_dropdown');
  await tap(t, 'ledger_account_bank');
}

Future<void> patient(WidgetTester t, {String id = 'patient'}) async {
  await tap(t, 'ledger_patient_select');
  await tap(t, 'ledger_patient_$id');
}

Future<void> finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_LEDGER_CAPTURE_DIR'];
  if (dir == null) return;
  await t.pumpAndSettle();
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('ledger_capture')),
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

List<dynamic> painters(WidgetTester t) =>
    t
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((w) => w.painter.runtimeType.toString() == '_PiePainter')
        .map((w) => w.painter as dynamic)
        .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  check(
    'real Account Ledger menu, selector, left/right table and carried totals',
    (t) async {
      final h = LedgerHarness();
      await host(t, h, app: true);
      expect(find.byType(AccountLedgerScreen), findsOneWidget);
      expect(find.text('Account Ledger'), findsOneWidget);
      expect(find.byKey(const Key('ledger_heading')), findsNothing);
      await capture(t, '01_account_initial');
      await bank(t);
      expect(text(t, 'ledger_heading'), h.accountRows.first['ad_name']);
      expect(find.text('Bank Account'), findsOneWidget);
      expect(find.text('Financial Account'), findsOneWidget);
      await capture(t, '02_account_ledger_left');
      final scroll = scrolling(t, 'ledger_horizontal');
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await t.pump();
      expect(text(t, 'ledger_opening_0'), '(-)  5,89,436');
      expect(text(t, 'ledger_total_0'), '(-)  5,56,166');
      expect(text(t, 'ledger_total_2'), '(-)  5,56,166');
      await capture(t, '03_account_ledger_right');
      await finish(t);
    },
  );
  check('real Patient Ledger menu, latest picker, selection and totals', (
    t,
  ) async {
    final h = LedgerHarness();
    await host(t, h, app: true, patient: true);
    expect(find.text('Account Ledger (Patient)'), findsOneWidget);
    await capture(t, '04_patient_initial');
    await tap(t, 'ledger_patient_select');
    expect(find.text('Latest 50 Patients'), findsOneWidget);
    expect(find.text('Prescription Code'), findsOneWidget);
    await capture(t, '05_patient_picker_latest');
    await tap(t, 'ledger_patient_patient');
    expect(text(t, 'ledger_heading'), 'Example Patient');
    expect(text(t, 'ledger_code'), '(26.01.00009.01)');
    await capture(t, '06_patient_ledger_left');
    final scroll = scrolling(t, 'ledger_horizontal');
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await t.pump();
    expect(text(t, 'ledger_row_2_5'), '(-)  2,060');
    expect(
      [
        text(t, 'ledger_total_0'),
        text(t, 'ledger_total_1'),
        text(t, 'ledger_total_2'),
      ],
      ['7,828', '6,180', '1,648'],
    );
    await capture(t, '07_patient_ledger_right');
    await finish(t);
  });
  check(
    'patient validations, live invalid character, search, no results and small Clear',
    (t) async {
      final h = LedgerHarness();
      await host(t, h, patient: true);
      await tap(t, 'ledger_patient_select');
      final calls = h.transport.requests.length;
      await tap(t, 'ledger_patient_search');
      expect(find.text('Please Provide Patient Name or Code'), findsOneWidget);
      await capture(t, '08_patient_empty_query_validation');
      await t.enterText(find.byKey(const Key('ledger_patient_query')), 'ab');
      await tap(t, 'ledger_patient_search');
      expect(
        find.text('Name or Code must be greater than 2 character'),
        findsOneWidget,
      );
      await t.enterText(find.byKey(const Key('ledger_patient_query')), 'a.b');
      await t.pump();
      expect(find.text('Invalid Character.'), findsOneWidget);
      await tap(t, 'ledger_patient_search');
      expect(h.transport.requests.length, calls);
      await t.enterText(find.byKey(const Key('ledger_patient_query')), 'shu');
      await tap(t, 'ledger_patient_search');
      expect(find.byKey(const Key('ledger_patient_patient')), findsNothing);
      expect(find.byKey(const Key('ledger_patient_shu1')), findsOneWidget);
      await capture(t, '09_patient_search_results');
      expect(
        t.getSize(find.byKey(const Key('ledger_patient_clear'))).width,
        lessThan(125),
      );
      final before = h.transport.requests.length;
      await tap(t, 'ledger_patient_clear');
      expect(h.transport.requests.length, before);
      expect(find.text('Latest 50 Patients'), findsOneWidget);
      await t.enterText(find.byKey(const Key('ledger_patient_query')), 'zzzz');
      await tap(t, 'ledger_patient_search');
      expect(find.text('No Patient Found'), findsOneWidget);
      await capture(t, '10_patient_search_empty');
      await tap(t, 'ledger_patient_cancel');
      expect(find.byKey(const Key('ledger_patient_picker')), findsNothing);
      await finish(t);
    },
  );
  check(
    'account dropdown supports filtered names and validates empty/invalid text',
    (t) async {
      final h = LedgerHarness();
      await host(t, h);
      await t.enterText(find.byKey(const Key('ledger_account')), 'nonsense');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(find.text('Invalid A/C No'), findsOneWidget);
      await capture(t, '11_account_invalid');
      await t.enterText(find.byKey(const Key('ledger_account')), '');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(find.text('Please Select A/C No'), findsOneWidget);
      await capture(t, '12_account_missing');
      await t.enterText(find.byKey(const Key('ledger_account')), 'Cash');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ledger_account_cash')), findsOneWidget);
      expect(find.byKey(const Key('ledger_account_bank')), findsNothing);
      await tap(t, 'ledger_account_cash');
      expect(text(t, 'ledger_heading'), 'Cash in Hand');
      await finish(t);
    },
  );
  check('valid supplied dates and AD_ID automatically load matching account', (
    t,
  ) async {
    final h = LedgerHarness();
    await host(t, h, id: 'bank', first: '01-Nov-26', last: '03-Nov-26');
    expect(find.byKey(const Key('ledger_heading')), findsOneWidget);
    expect(h.accountReads.first.uri.pathSegments.last, 'getAccountList');
    expect(
      h.accountReads
          .where((r) => r.uri.pathSegments.last == 'getAccLedger')
          .single
          .uri
          .queryParameters['ad_id'],
      'bank',
    );
    await finish(t);
  });
  check('date picker minimum and invalid begin clear only edited field', (
    t,
  ) async {
    final h = LedgerHarness();
    await host(t, h);
    await bank(t);
    await tap(t, 'ledger_begin');
    final picker = t.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.firstDate, DateTime(2026, 9, 1));
    await t.tap(find.text('3').last);
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(find.text('Date Range is Invalid'), findsOneWidget);
    expect(find.byKey(const Key('ledger_heading')), findsNothing);
    await capture(t, '13_account_invalid_date');
    await tap(t, 'ledger_begin');
    await t.tap(find.text('1').last);
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('ledger_heading')), findsOneWidget);
    await finish(t);
  });
  check('opening-only ledger shows native totals without balance calls', (
    t,
  ) async {
    final h = LedgerHarness();
    h.bankRows = [
      {'lg_id': 0, 'opening_dr': '-1234.5', 'opening_cr': null},
    ];
    await host(t, h);
    await bank(t);
    expect(find.byKey(const Key('ledger_row_0')), findsNothing);
    final scroll = scrolling(t, 'ledger_horizontal');
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await t.pump();
    expect(text(t, 'ledger_total_2'), '(-)  1,234.5');
    await capture(t, '14_account_opening_only');
    await finish(t);
  });
  check(
    'PRM invoice and AV report links preserve parent selection and scroll',
    (t) async {
      final h = LedgerHarness();
      await host(t, h);
      await bank(t);
      await tap(t, 'ledger_row_0_1');
      expect(find.text('Payment Invoice'), findsOneWidget);
      await capture(t, '15_ledger_invoice');
      await tap(t, 'invoice_back');
      final horizontal = scrolling(t, 'ledger_horizontal');
      horizontal.jumpTo(20);
      await t.pump();
      final ledgerCalls =
          h.accountReads
              .where((r) => r.uri.pathSegments.last == 'getAccLedger')
              .length;
      await tap(t, 'ledger_row_2_1');
      expect(find.byKey(const Key('vt_report_dialog')), findsOneWidget);
      expect(
        h.accountReads.last.uri.queryParameters['p_vm_no'],
        'EXAMPLE.DV.00003.26',
      );
      await capture(t, '16_ledger_report');
      await tap(t, 'vt_report_ok');
      expect(scrolling(t, 'ledger_horizontal').offset, 20);
      expect(
        h.accountReads
            .where((r) => r.uri.pathSegments.last == 'getAccLedger')
            .length,
        ledgerCalls,
      );
      await finish(t);
    },
  );
  check(
    'initial account error Retry recovers, ledger failure never shows partial data',
    (t) async {
      final h = LedgerHarness();
      var initial = true;
      h.onLedgerGet = (uri) async {
        if (initial && uri.pathSegments.last == 'getAccountList') {
          throw const AppFailure(
            'Synthetic offline',
            kind: FailureKind.network,
          );
        }
        return null;
      };
      await host(t, h);
      expect(find.byKey(const Key('ledger_error')), findsOneWidget);
      await capture(t, '17_account_retry');
      initial = false;
      final retry =
          t
              .widget<TextButton>(find.byKey(const Key('ledger_error_retry')))
              .onPressed!;
      retry();
      retry();
      await t.pumpAndSettle();
      expect(find.byType(AccountLedgerScreen), findsOneWidget);
      h.onLedgerGet =
          (uri) async =>
              uri.pathSegments.last == 'getLedgerBalance' ? h.page([]) : null;
      await bank(t);
      expect(find.byKey(const Key('ledger_heading')), findsNothing);
      expect(find.byKey(const Key('ledger_error')), findsOneWidget);
      await capture(t, '18_balance_error');
      h.onLedgerGet = null;
      await tap(t, 'ledger_error_retry');
      expect(find.byKey(const Key('ledger_heading')), findsOneWidget);
      await finish(t);
    },
  );
  check('patient latest error inline Retry, then search error Retry', (
    t,
  ) async {
    final h = LedgerHarness();
    var failLatest = true, failSearch = false;
    h.onLedgerGet = (uri) async {
      if (failLatest && uri.pathSegments.last == 'getFiftyPrescriptionList' ||
          failSearch && uri.pathSegments.last == 'getPrescriptionCodeList') {
        throw const AppFailure('Synthetic offline', kind: FailureKind.network);
      }
      return null;
    };
    await host(t, h, patient: true);
    await tap(t, 'ledger_patient_select');
    expect(find.byKey(const Key('ledger_patient_retry')), findsOneWidget);
    failLatest = false;
    await tap(t, 'ledger_patient_retry');
    expect(find.text('Latest 50 Patients'), findsOneWidget);
    failSearch = true;
    await t.enterText(find.byKey(const Key('ledger_patient_query')), 'shu');
    await tap(t, 'ledger_patient_search');
    await capture(t, '19_patient_search_retry');
    failSearch = false;
    await tap(t, 'ledger_patient_retry');
    expect(find.byKey(const Key('ledger_patient_shu1')), findsOneWidget);
    await finish(t);
  });
  check(
    'background closes picker and stale latest response cannot select or reopen it',
    (t) async {
      final h = LedgerHarness(), gate = Completer<JsonMap>();
      var held = true;
      h.onLedgerGet =
          (uri) async =>
              held && uri.pathSegments.last == 'getFiftyPrescriptionList'
                  ? gate.future
                  : null;
      await host(t, h, patient: true);
      await tap(t, 'ledger_patient_select', settle: false);
      pause(t);
      await t.pump();
      gate.complete({'pat_pres_list': h.patients});
      held = false;
      resume(t);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ledger_patient_picker')), findsNothing);
      expect(find.byKey(const Key('ledger_heading')), findsNothing);
      await patient(t);
      expect(find.byKey(const Key('ledger_heading')), findsOneWidget);
      await finish(t);
    },
  );
  check(
    'background during balance chain discards stale response and reloads fresh ledger',
    (t) async {
      final h = LedgerHarness(), gate = Completer<JsonMap>();
      var held = true;
      h.onLedgerGet =
          (uri) async =>
              held && uri.pathSegments.last == 'getLedgerBalance'
                  ? gate.future
                  : null;
      await host(t, h);
      await tap(t, 'ledger_account_dropdown');
      await tap(t, 'ledger_account_bank', settle: false);
      expect(find.byKey(const Key('ledger_loading')), findsOneWidget);
      pause(t);
      await t.pump();
      held = false;
      gate.complete(
        h.page([
          {'ledger_balance': '999999'},
        ]),
      );
      resume(t);
      await t.pumpAndSettle();
      expect(text(t, 'ledger_total_2'), '(-)  5,56,166');
      await finish(t);
    },
  );
  check('module revoked before selection suppresses ledger data and calls', (
    t,
  ) async {
    final h = LedgerHarness();
    await host(t, h);
    h.adminData['acc_dashboard'] = '0';
    h.transport.requests.clear();
    await bank(t);
    expect(
      find.text('Accounts access is not available for this account.'),
      findsOneWidget,
    );
    expect(h.accountReads, isEmpty);
    await finish(t);
  });
  check('logout invalidates picker, held response and old callbacks', (
    t,
  ) async {
    final h = LedgerHarness(), gate = Completer<JsonMap>();
    h.onLedgerGet =
        (uri) async =>
            uri.pathSegments.last == 'getFiftyPrescriptionList'
                ? gate.future
                : null;
    await host(t, h, patient: true, app: true);
    await tap(t, 'ledger_patient_select', settle: false);
    await h.auth.logout();
    gate.complete({'pat_pres_list': h.patients});
    await t.pumpAndSettle();
    expect(find.byKey(const Key('ledger_patient_picker')), findsNothing);
    expect(find.byType(AccountLedgerScreen), findsNothing);
    await finish(t);
  });
  check('empty account list, no automatic ledger request and usable Back', (
    t,
  ) async {
    final h = LedgerHarness();
    h.accountRows = [];
    await host(t, h);
    expect(find.text('No Account List Found'), findsOneWidget);
    await capture(t, '20_accounts_empty');
    await tap(t, 'ledger_back');
    expect(find.text('Synthetic parent'), findsOneWidget);
    await finish(t);
  });
  check('empty patient list keeps native headings and no result message', (
    t,
  ) async {
    final h = LedgerHarness();
    h.patients = [];
    await host(t, h, patient: true);
    await tap(t, 'ledger_patient_select');
    expect(find.text('Latest 50 Patients'), findsOneWidget);
    expect(find.text('No Patient Found'), findsOneWidget);
    await capture(t, '21_patients_empty');
    await finish(t);
  });
  for (final frame in [
    (const Size(320, 568), 1.0, 'small'),
    (const Size(393, 852), 2.0, 'large_text'),
    (const Size(852, 393), 1.0, 'landscape'),
  ]) {
    check('${frame.$3}: ledger and long patient picker remain scrollable', (
      t,
    ) async {
      final h = LedgerHarness();
      h.patients = [
        for (var i = 0; i < 50; i++)
          ledgerPatient(id: 'p$i', name: 'Example Patient $i Long Name'),
      ];
      await host(t, h, patient: true, size: frame.$1, zoom: frame.$2);
      await capture(t, '22_${frame.$3}_initial');
      await tap(t, 'ledger_patient_select');
      await capture(t, '23_${frame.$3}_picker');
      await tap(t, 'ledger_patient_p0');
      await capture(t, '24_${frame.$3}_ledger');
      expect(t.takeException(), isNull);
      await finish(t);
    });
  }
  check('patient picker keyboard inset keeps search and Cancel usable', (
    t,
  ) async {
    final h = LedgerHarness();
    await host(t, h, patient: true);
    await tap(t, 'ledger_patient_select');
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(t.view.resetViewInsets);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('ledger_patient_query')), 'shu');
    await tap(t, 'ledger_patient_search');
    await capture(t, '25_patient_keyboard');
    await tap(t, 'ledger_patient_cancel');
    await finish(t);
  });
  check('dashboard no data has right legends and native centre titles', (
    t,
  ) async {
    final h = LedgerHarness();
    h.voucherRows = [];
    h.amountRows = [
      {'amount': 0},
    ];
    h.incomeRows = [
      {'income': 0, 'expense': 0},
    ];
    await host(
      t,
      h,
      child: AccountsDashboardScreen(auth: h.auth, repository: h.accounts),
    );
    expect(find.text('No Data'), findsNWidgets(2));
    expect(painters(t).map((dynamic p) => p.title), [
      'Voucher',
      'Income/\nExpense',
    ]);
    await capture(t, '26_dashboard_no_data');
    await t.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -500),
    );
    await t.pumpAndSettle();
    await capture(t, '27_dashboard_income_no_data');
    await finish(t);
  });
  check('transaction no data has blank centre and right legend', (t) async {
    final h = LedgerHarness();
    h.voucherRows = [];
    h.ledger = [];
    await host(
      t,
      h,
      child: VoucherTransactionScreen(auth: h.auth, repository: h.vouchers),
    );
    expect(find.text('No Data'), findsOneWidget);
    expect(painters(t).single.title, '');
    expect(find.text('No Voucher Transaction Found'), findsOneWidget);
    await capture(t, '28_transaction_no_data');
    await finish(t);
  });
  check('populated chart retains native labels, counts and no empty legend', (
    t,
  ) async {
    final h = LedgerHarness();
    await host(
      t,
      h,
      child: AccountsDashboardScreen(auth: h.auth, repository: h.accounts),
    );
    expect(find.text('No Data'), findsNothing);
    expect(find.text('CV (Receive)'), findsOneWidget);
    expect(painters(t).first.title, 'Voucher');
    expect(painters(t).first.slices.length, 3);
    await capture(t, '29_dashboard_with_data');
    await finish(t);
  });
  check('large text empty chart legend stays visible without overflow', (
    t,
  ) async {
    final h = LedgerHarness();
    h.voucherRows = [];
    h.ledger = [];
    await host(
      t,
      h,
      size: const Size(320, 568),
      zoom: 2,
      child: VoucherTransactionScreen(auth: h.auth, repository: h.vouchers),
    );
    expect(find.byType(NativeAccountsDonut), findsOneWidget);
    expect(find.text('No Data'), findsOneWidget);
    await capture(t, '30_transaction_no_data_accessible');
    await finish(t);
  });
}

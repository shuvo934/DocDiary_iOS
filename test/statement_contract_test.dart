import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/accounts/accounts_dashboard_repository.dart';
import 'package:docdiary_ios/features/accounts/statements/statement_models.dart';
import 'package:docdiary_ios/features/accounts/statements/daily_statement_screen.dart';
import 'package:docdiary_ios/features/accounts/voucher_transaction/voucher_models.dart';
import 'package:docdiary_ios/features/reports/report_manager_models.dart';
import 'package:docdiary_ios/features/reports/report_manager_menu.dart';
import 'package:docdiary_ios/features/reports/report_manager_repository.dart';
import 'statement_test_support.dart';

void main() {
  late StatementHarness h;
  final dates = VoucherDates('03-Nov-26', '03-Nov-26');
  setUp(() async {
    h = StatementHarness();
    await h.signIn();
    h.transport.requests.clear();
  });
  tearDown(() => h.auth.dispose());
  Future<StatementData> load({bool Function()? current}) async =>
      await h.statements.statement(
        h.auth.session!,
        h.profile,
        dates,
        isCurrent: current ?? () => true,
      );

  test('native three GET sequence and exact query names', () async {
    final data = await load();
    expect(h.accountReads.map((r) => r.uri.pathSegments.last), [
      'getIncomeExpense',
      'getNIncomeStatement',
      'getNExpenseStatement',
    ]);
    expect(h.accountReads.first.uri.queryParameters, {
      'first_date': '03-Nov-26',
      'end_date': '03-Nov-26',
    });
    expect(h.accountReads[1].uri.queryParameters, {
      'begin_date': '03-Nov-26',
      'end_date': '03-Nov-26',
    });
    expect(
      h.accountReads[2].uri.queryParameters,
      h.accountReads[1].uri.queryParameters,
    );
    expect(data.chartNet.text, '40440');
    expect(data.amountLabel, 'Amount : 40,440 (Net Profit)');
    expect(h.transport.requests.every((r) => r.method == 'GET'), isTrue);
  });
  test(
    'signed arithmetic and native absolute balance / currency displays',
    () async {
      final data = await load();
      expect(data.income.totals.columns.map((v) => v.text), [
        '343350',
        '28971870',
        '0',
        '42300',
        '28670820',
      ]);
      expect(data.expense.totals.columns.map((v) => v.text), [
        '28089956',
        '1850',
        '1860',
        '0',
        '-28089966',
      ]);
      expect(
        [
          data.profit.before.text,
          data.profit.during.text,
          data.profit.balance.text,
        ],
        ['540414', '40440', '580854'],
      );
      expect(
        statementAmount(data.expense.totals.balance, absolute: true),
        '2,80,89,966',
      );
    },
  );
  test(
    'all three native levels keep order, totals and reuse the same rows',
    () async {
      final data = await load();
      final requests = h.transport.requests.length;
      expect(data.expense.lines(StatementLevel.details).length, 8);
      expect(data.expense.lines(StatementLevel.subControl).length, 6);
      expect(data.expense.lines(StatementLevel.control).length, 4);
      expect(
        data.income.lines(StatementLevel.control).single.amounts.balance.text,
        '28670820',
      );
      for (final level in StatementLevel.values) {
        final totals = data.expense
            .lines(level)
            .fold(StatementAmounts.zero, (sum, line) => sum + line.amounts);
        expect(
          totals.columns.map((v) => v.text),
          data.expense.totals.columns.map((v) => v.text),
        );
      }
      expect(h.transport.requests.length, requests);
    },
  );
  test(
    'adjacent hierarchy grouping is stable and includes both control codes',
    () {
      StatementAccount row(String id, String a, String b) =>
          StatementAccount(statementAccount(id, a, b, id, beforeDebit: '1'));
      final section = StatementSection([
        row('1', 'A', 'same'),
        row('2', 'A', 'same'),
        row('3', 'B', 'same'),
        row('4', 'A', 'same'),
      ]);
      final groups = section.lines(StatementLevel.subControl);
      expect(groups.map((g) => g.accounts.map((r) => r.id).join(',')), [
        '1,2',
        '3',
        '4',
      ]);
      expect(groups.first.amounts.beforeDebit.text, '2');
    },
  );
  test(
    'decimal precision survives grouping before native one-place display',
    () {
      final section = StatementSection([
        StatementAccount(
          statementAccount('a', 'A', 'B', 'a', duringCredit: '0.15'),
        ),
        StatementAccount(
          statementAccount('b', 'A', 'B', 'b', duringCredit: '0.25'),
        ),
      ]);
      expect(
        section.lines(StatementLevel.control).single.amounts.duringCredit.text,
        '0.4',
      );
      expect(statementAmount(VtMoney.parse('139.15')), '139.2');
      expect(
        statementAmount(VtMoney.parse('-123456.05'), absolute: true),
        '1,23,456',
      );
      expect(statementAmount(VtMoney.parse('0.04'), blankZero: true), '');
      expect(statementAmount(VtMoney.zero), '0');
    },
  );
  test(
    'net loss and break even use independent chart endpoint values',
    () async {
      h.incomeRows = [
        {'income': '0.1', 'expense': '0.3'},
      ];
      var data = await load();
      expect(data.chartNet.text, '-0.2');
      expect(data.amountLabel, 'Amount : 0.2 (Net Loss)');
      expect(data.profit.during.text, '40440');
      h.incomeRows = [
        {'income': 0, 'expense': 0},
      ];
      data = await load();
      expect(data.amountLabel, 'Amount : 0 (Break Even Point)');
    },
  );
  test('encoded arrays and native null fields are supported', () async {
    h.encoded = true;
    final template = statementAccount('a', 'A', 'B', 'name');
    h.statementIncome = [
      {for (final key in template.keys) key: null},
    ];
    h.statementExpense = [];
    final data = await load();
    expect(data.income.rows.single.id, '');
    expect(data.income.totals.balance.text, '0');
    expect(data.expense.rows, isEmpty);
  });
  test('empty counts clear prior financial totals and chart', () async {
    await load();
    h.statementIncome = [];
    h.statementExpense = [];
    h.incomeRows = [];
    final data = await load();
    expect(data.chartIncome.isZero, isTrue);
    expect(data.chartExpense.isZero, isTrue);
    expect(data.profit.columns.every((n) => n.isZero), isTrue);
  });
  test(
    'malformed counts and amounts fail without requesting the next section',
    () async {
      for (final broken in <JsonMap>[
        {'count': 1, 'items': []},
        {'items': []},
        {'count': -1, 'items': []},
        {
          'count': 1,
          'items': [
            {...h.statementIncome.first}..remove('bfdr'),
          ],
        },
        {
          'count': 1,
          'items': [
            {...h.statementIncome.first, 'bfdr': 'invalid'},
          ],
        },
      ]) {
        h.transport.requests.clear();
        h.onStatementGet =
            (u) async =>
                u.pathSegments.last == 'getNIncomeStatement' ? broken : null;
        await expectLater(load(), throwsA(isA<AppFailure>()));
        expect(h.accountReads.map((r) => r.uri.pathSegments.last), [
          'getIncomeExpense',
          'getNIncomeStatement',
        ]);
      }
    },
  );
  test('expense failure never returns an income-only statement', () async {
    h.onStatementGet = (u) async {
      if (u.pathSegments.last == 'getNExpenseStatement') {
        throw const AppFailure('Synthetic offline', kind: FailureKind.network);
      }
      return null;
    };
    await expectLater(load(), throwsA(isA<AppFailure>()));
    expect(h.accountReads.length, 3);
  });
  test(
    'obsolete chart response cannot continue to income or expense',
    () async {
      final gate = Completer<JsonMap>();
      var current = true;
      h.onStatementGet =
          (u) async =>
              u.pathSegments.last == 'getIncomeExpense' ? gate.future : null;
      final result = load(current: () => current);
      await Future<void>.delayed(Duration.zero);
      current = false;
      gate.complete(h.page(h.incomeRows));
      await expectLater(result, throwsA(isA<ObsoleteRequest>()));
      expect(h.accountReads.length, 1);
    },
  );
  test('Accounts role revocation prevents the full statement chain', () async {
    h.adminData['all_access_flag'] = '2';
    await expectLater(load(), throwsA(isA<AccountsModuleUnavailable>()));
    expect(h.transport.requests, isEmpty);
  });
  test(
    'daily metadata is one native report-manager GET and no catalogue reads',
    () async {
      final config = await h.statements.dailyConfig(
        h.auth.session!,
        h.profile,
        isCurrent: () => true,
      );
      expect(
        h.transport.requests.single.uri.path,
        '/ords/cstar/report_manager/getUrlData',
      );
      expect(h.transport.requests.single.uri.queryParameters, isEmpty);
      expect(config.server, 'report.example:8889');
    },
  );
  test(
    'daily URL has only report, BEGIN_DATE and END_DATE; shared viewer title/name',
    () async {
      final config = await h.statements.dailyConfig(
        h.auth.session!,
        h.profile,
        isCurrent: () => true,
      );
      final request = DailyStatementRequest(dates),
          url = config.url(DailyStatementRequest(dates));
      expect(request.title, 'Daily Statement');
      expect(request.reportFile, 'DAILY_STATEMENT.rep');
      expect(request.documentName, 'Daily_Statement_03-Nov-26_to_03-Nov-26');
      expect(url.scheme, 'http');
      expect(url.host, 'report.example');
      expect(url.port, 8889);
      expect(url.path, '/reports/rwservlet');
      expect(
        url.query,
        'report_key+report=C%3A%5Creports%5CDAILY_STATEMENT.rep+BEGIN_DATE=03-Nov-26+END_DATE=03-Nov-26',
      );
      for (final key in ['DEPTD', 'DEPTS', 'PFN', 'CIDID', 'DOC']) {
        expect(url.query, isNot(contains('+$key=')));
      }
      expect(
        nativeReportManagerItems(h.auth.session!.center.baseUri).length,
        5,
      );
    },
  );
  test(
    'daily PDF guard uses Accounts permission and native centre restriction',
    () {
      final repository = DailyStatementReportRepository(
        h.transport,
        now: () => h.now,
      );
      repository.guard(
        h.auth.session!,
        h.profile,
        ReportManagerItem.paymentRegister,
        () => true,
      );
      h.adminData['acc_dashboard'] = '0';
      expect(
        () => repository.guard(
          h.auth.session!,
          h.profile,
          ReportManagerItem.paymentRegister,
          () => true,
        ),
        throwsA(isA<ReportManagerUnavailable>()),
      );
    },
  );
  test('daily unavailable outside cstar/btrf sends no metadata GET', () async {
    final other = StatementHarness(special: false);
    addTearDown(other.auth.dispose);
    await other.signIn();
    other.transport.requests.clear();
    await expectLater(
      other.statements.dailyConfig(
        other.auth.session!,
        other.profile,
        isCurrent: () => true,
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(other.transport.requests, isEmpty);
  });
  test(
    'missing daily metadata and malformed server address are errors',
    () async {
      h.configRows = [];
      await expectLater(
        h.statements.dailyConfig(
          h.auth.session!,
          h.profile,
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      h.configRows = [
        {
          'lic_rep_server_port': 'bad/path',
          'lic_rep_path': 'x',
          'lic_rep_hrs_link': 'k',
          'cid_id': null,
        },
      ];
      final config = await h.statements.dailyConfig(
        h.auth.session!,
        h.profile,
        isCurrent: () => true,
      );
      expect(
        () => config.url(DailyStatementRequest(dates)),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'daily permits unused missing CID and preserves URL argument encoding',
    () {
      const config = ReportServerConfig(
        server: 'report.example:8889',
        path: 'C:\\Folder Name\\',
        link: 'native_key',
        center: 'unused / identifier',
      );
      final uri = config.url(DailyStatementRequest(dates));
      expect(uri.query, contains('Folder%20Name'));
      expect(uri.query, isNot(contains('CIDID')));
    },
  );
  test('encoded daily metadata and last native configuration row', () async {
    h.encoded = true;
    h.configRows = [
      ...h.configRows,
      {...h.configRows.first, 'lic_rep_server_port': 'last.example:8889'},
    ];
    final config = await h.statements.dailyConfig(
      h.auth.session!,
      h.profile,
      isCurrent: () => true,
    );
    expect(config.server, 'last.example:8889');
    h.onStatementGet =
        (u) async =>
            u.pathSegments.last == 'getUrlData'
                ? {'count': 1, 'items': jsonEncode([])}
                : null;
    await expectLater(
      h.statements.dailyConfig(
        h.auth.session!,
        h.profile,
        isCurrent: () => true,
      ),
      throwsA(isA<AppFailure>()),
    );
  });
}

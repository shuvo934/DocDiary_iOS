import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/features/accounts/accounts_dashboard_models.dart';
import 'package:docdiary_ios/features/accounts/accounts_dashboard_navigation.dart';
import 'package:docdiary_ios/features/accounts/accounts_dashboard_repository.dart';
import 'accounts_dashboard_test_support.dart';

void main() {
  final today = DateTime(2026, 11, 2, 15, 19);
  final range = AccountsRange.forPeriod(AccountsPeriod.today, today);
  Future<AccountsHarness> signed() async {
    final h = AccountsHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    h.transport.requests.clear();
    return h;
  }

  Future<AccountsDashboardData> load(
    AccountsHarness h, {
    bool Function()? current,
  }) => h.accounts.load(
    h.auth.session!,
    h.profile,
    range,
    isCurrent: current ?? () => true,
  );
  test('four native periods use Saturday to Friday and full month', () {
    expect(range.label, '02 November, 26');
    expect(AccountsRange.forPeriod(AccountsPeriod.currentWeek, today).query, {
      'first_date': '31-Oct-26',
      'end_date': '06-Nov-26',
    });
    expect(AccountsRange.forPeriod(AccountsPeriod.currentMonth, today).query, {
      'first_date': '01-Nov-26',
      'end_date': '30-Nov-26',
    });
    expect(
      AccountsRange.forPeriod(AccountsPeriod.lastMonth, today).label,
      '01 October, 26  --  31 October, 26',
    );
  });
  test(
    'week boundaries, leap February, January rollover are calendar dates',
    () {
      expect(
        AccountsRange.forPeriod(
          AccountsPeriod.currentWeek,
          DateTime(2026, 11, 6),
        ).first,
        DateTime(2026, 10, 31),
      );
      expect(
        AccountsRange.forPeriod(
          AccountsPeriod.currentWeek,
          DateTime(2026, 11, 7),
        ).first,
        DateTime(2026, 11, 7),
      );
      expect(
        AccountsRange.forPeriod(
          AccountsPeriod.lastMonth,
          DateTime(2027, 1, 1),
        ).query,
        {'first_date': '01-Dec-26', 'end_date': '31-Dec-26'},
      );
      expect(
        AccountsRange.forPeriod(
          AccountsPeriod.currentMonth,
          DateTime(2028, 2, 15),
        ).last.day,
        29,
      );
    },
  );
  test(
    'read-only native API chain uses first_date and end_date on all three calls',
    () async {
      final h = await signed();
      final data = await load(h);
      expect(data.voucherCount, BigInt.from(8));
      expect(data.amountLabel, '10200 (Net Profit)');
      expect(h.accountReads.map((r) => r.uri.pathSegments.last), [
        'getVoucherCount',
        'getVoucherTotalAmnt',
        'getIncomeExpense',
      ]);
      expect(
        h.accountReads.every(
          (r) =>
              r.method == 'GET' &&
              r.uri.queryParameters.toString() == range.query.toString(),
        ),
        true,
      );
      expect(h.posts, isEmpty);
    },
  );
  test(
    '139.05 retains cents and aggregate net amount is authoritative',
    () async {
      final h = await signed();
      h.amountRows = [
        {'amount': '-139.050'},
      ];
      h.incomeRows = [
        {'income': '200.10', 'expense': '339.15'},
      ];
      final data = await load(h);
      expect(data.amountLabel, '139.05 (Net Loss)');
      expect(data.income.text, '200.1');
      expect(data.expense.text, '339.15');
      expect(
        AccountsNumber('99999999999999999999.05').text,
        '99999999999999999999.05',
      );
    },
  );
  test(
    'empty new period resets all data, numeric zero is break even',
    () async {
      final h = await signed();
      await load(h);
      h.voucherRows = [];
      h.amountRows = [];
      h.incomeRows = [];
      final data = await load(h);
      expect(data.vouchers, isEmpty);
      expect(data.voucherCount, BigInt.zero);
      expect(data.amountLabel, '0 (Break Even Point)');
      expect(data.income.text, '0');
      expect(data.expense.text, '0');
    },
  );
  test('encoded ORDS rows and last aggregate row match native', () async {
    final h = await signed();
    h.encoded = true;
    h.amountRows = [
      {'amount': '2'},
      {'amount': '139.05'},
    ];
    h.incomeRows = [
      {'income': '1', 'expense': '2'},
      {'income': '139.05', 'expense': '0.00'},
    ];
    final data = await load(h);
    expect(data.amount.text, '139.05');
    expect(data.expense.isZero, true);
  });
  test(
    'blank labels and zero slices preserve native source color indexes',
    () async {
      final h = await signed();
      h.voucherRows = [
        {'voucher_type': '', 'cc': '5'},
        {'voucher_type': 'empty', 'cc': '0'},
        {'voucher_type': 'DV', 'cc': '3'},
      ];
      final data = await load(h);
      expect(data.vouchers.single.colorIndex, 2);
      expect(data.voucherCount, BigInt.from(3));
    },
  );
  for (final invalid in ['1.5', '-1', 'NaN', 'Infinity', '1e100']) {
    test(
      'invalid count $invalid is rejected before aggregate requests',
      () async {
        final h = await signed();
        h.voucherRows = [
          {'voucher_type': 'CV', 'cc': invalid},
        ];
        await expectLater(load(h), throwsA(isA<AppFailure>()));
        expect(h.accountReads.length, 1);
      },
    );
  }
  for (final endpoint in [
    'getVoucherCount',
    'getVoucherTotalAmnt',
    'getIncomeExpense',
  ]) {
    test('missing required fields on $endpoint fail the atomic load', () async {
      final h = await signed();
      h.onAccountsGet =
          (u) async =>
              u.path.endsWith(endpoint)
                  ? {
                    'count': 1,
                    'items': [{}],
                  }
                  : null;
      await expectLater(load(h), throwsA(isA<AppFailure>()));
    });
  }
  test('incomplete count envelope is rejected', () async {
    final h = await signed();
    h.onAccountsGet = (_) async => {'count': 2, 'items': []};
    await expectLater(load(h), throwsA(isA<AppFailure>()));
  });
  for (final flag in ['hr_acc_active_flag', 'acc_dashboard']) {
    test(
      'revoked $flag blocks full-access accounts before data requests',
      () async {
        final h = await signed();
        h.adminData[flag] = '0';
        await expectLater(load(h), throwsA(isA<AccountsModuleUnavailable>()));
        expect(h.accountReads, isEmpty);
      },
    );
  }
  test('Accounts role 3 allowed; HR role 2 denied', () async {
    final h = await signed();
    h.adminData['all_access_flag'] = '3';
    expect((await load(h)).voucherCount, BigInt.from(8));
    h.adminData['all_access_flag'] = '2';
    await expectLater(load(h), throwsA(isA<AccountsModuleUnavailable>()));
  });
  for (final entry
      in {
        'usr_id': 'other',
        'usr_mob_app_access': '0',
        'usr_mob_forced_log_out_flag': '1',
        'exp_date': '01-NOV-26',
      }.entries) {
    test(
      'account identity/access check ${entry.key} precedes all data reads',
      () async {
        final h = await signed();
        h.adminData[entry.key] = entry.value;
        await expectLater(load(h), throwsA(isA<AppFailure>()));
        expect(h.accountReads, isEmpty);
      },
    );
  }
  test('obsolete requests stop chain after a pending response', () async {
    final h = await signed();
    var current = true;
    final gate = Completer<void>();
    h.onAccountsGet = (_) async {
      await gate.future;
      return null;
    };
    final future = load(h, current: () => current);
    current = false;
    gate.complete();
    await expectLater(future, throwsA(isA<ObsoleteRequest>()));
    expect(h.accountReads.length, 1);
  });
  test(
    'daily centre gate, menu blank dates and chart selected dates match native',
    () {
      expect(
        accountsDestinations(Uri.parse('https://centre.example/api/')).length,
        7,
      );
      for (final base in ['cstar', 'btrf']) {
        expect(
          accountsDestinations(
            Uri.parse('https://centre.example/ords/$base/'),
          ).length,
          8,
        );
      }
      expect(
        accountsDailyStatementAllowed(Uri.parse('https://x/CSTAR/')),
        false,
      );
      expect(AccountsDestination.voucherTransaction.route(now: today).extras, {
        'FIRST_DATE': '',
        'LAST_DATE': '',
      });
      expect(
        AccountsDestination.voucherTransaction
            .route(now: today, chartRange: range)
            .extras,
        {'FIRST_DATE': '02-Nov-26', 'LAST_DATE': '02-Nov-26'},
      );
      expect(AccountsDestination.accountLedger.route(now: today).extras, {
        'FIRST_DATE': '',
        'LAST_DATE': '',
        'AD_ID': '',
      });
      expect(AccountsDestination.dailyStatement.route(now: today).extras, {
        'REPORT_NAME': 'DAILY_STATEMENT.rep',
        'FIRST_DATE': '02-Nov-26',
        'LAST_DATE': '02-Nov-26',
        'APP_BAR_NAME': 'Daily Statement',
      });
    },
  );
}

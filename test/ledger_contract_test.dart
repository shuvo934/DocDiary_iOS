import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/accounts/account_ledger/ledger_models.dart';
import 'package:docdiary_ios/features/accounts/accounts_dashboard_repository.dart';
import 'package:docdiary_ios/features/accounts/voucher_transaction/voucher_models.dart';
import 'ledger_test_support.dart';

void main() {
  final dates = VoucherDates('01-Nov-26', '03-Nov-26');
  Future<LedgerData> bank(LedgerHarness h, {bool Function()? current}) async =>
      await h.ledgers.ledger(
        h.auth.session!,
        h.profile,
        dates,
        account: LedgerAccount(h.accountRows.first),
        isCurrent: current ?? () => true,
      );
  Future<LedgerData> patient(LedgerHarness h) async => await h.ledgers.ledger(
    h.auth.session!,
    h.profile,
    dates,
    patient: LedgerPatient(h.patients.first),
    isCurrent: () => true,
  );
  test(
    'ledger defaults first of month to today and preserves supplied dates',
    () {
      final value = initialLedgerDates('', '', DateTime(2026, 11, 3));
      expect([value.first, value.last], ['01-Nov-26', '03-Nov-26']);
      final passed = initialLedgerDates(
        '01-OCT-26',
        '31-OCT-26',
        DateTime(2026, 11, 3),
      );
      expect([passed.first, passed.last], ['01-OCT-26', '31-OCT-26']);
      expect(
        VoucherDates.earliest(DateTime(2026, 1, 3)),
        DateTime(2025, 11, 1),
      );
      expect(
        () => VoucherDates('03-Nov-26', '01-Nov-26'),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test('native lakh grouping, one decimal half-even and negative brackets', () {
    for (final pair in [
      ('-589436', '(-)  5,89,436'),
      ('183000', '1,83,000'),
      ('0', '0'),
      ('123456789.25', '12,34,56,789.2'),
      ('139.05', '139'),
      ('139.15', '139.2'),
      ('999.95', '1,000'),
      ('-0.04', '0'),
      ('9007199254740993.25', '9,00,71,99,25,47,40,993.2'),
    ]) {
      expect(ledgerAmount(VtMoney.parse(pair.$1)), pair.$2);
    }
    expect(ledgerAmount(VtMoney.parse('-12.36'), parentheses: false), '-12.4');
  });
  test(
    'account GET and bank server balance chain include opening in totals',
    () async {
      final h = LedgerHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.transport.requests.clear();
      final accounts = await h.ledgers.accounts(
        h.auth.session!,
        h.profile,
        isCurrent: () => true,
      );
      expect(accounts.first.id, 'bank');
      final data = await bank(h);
      expect(data.entries.map((e) => e.balance.text), [
        '-578271',
        '-571166',
        '-556166',
      ]);
      expect(
        [data.debit.text, data.credit.text, data.closingBalance.text],
        ['-556166', '0', '-556166'],
      );
      expect(h.accountReads.first.uri.pathSegments.last, 'getAccountList');
      final request = h.accountReads[1];
      expect(request.uri.queryParameters, {
        'st_date': '01-Nov-26',
        'end_date': '03-Nov-26',
        'ad_id': 'bank',
      });
      final q = h.accountReads[2].uri.queryParameters;
      expect(q, {
        'st_date': '01-Nov-26',
        'ad_id': 'bank',
        'debit_amnt': '11165',
        'credit_amnt': '0',
        'ah_code': '01',
        'balance': '-589436',
      });
      expect(h.accountReads.last.uri.queryParameters['balance'], '-571166');
      expect(h.transport.requests.every((r) => r.method == 'GET'), isTrue);
    },
  );
  test(
    'patient uses ph_id, blank ad_id, exact balance order and totals',
    () async {
      final h = LedgerHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.transport.requests.clear();
      final data = await patient(h);
      expect(h.accountReads.first.uri.queryParameters, {
        'st_date': '01-Nov-26',
        'end_date': '03-Nov-26',
        'p_ph_id': 'patient',
      });
      expect(h.accountReads.first.uri.pathSegments.last, 'getAccLedgerPh');
      expect(
        h.accountReads
            .skip(1)
            .every((r) => r.uri.queryParameters['ad_id'] == ''),
        isTrue,
      );
      expect(data.entries.map((e) => e.balance.text), [
        '4120',
        '0',
        '-2060',
        '1648',
      ]);
      expect(
        [data.debit.text, data.credit.text, data.closingBalance.text],
        ['7828', '6180', '1648'],
      );
    },
  );
  test(
    'server balance is authoritative and carried without display rounding',
    () async {
      final h = LedgerHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      var index = 0;
      h.onLedgerGet = (uri) async {
        if (uri.pathSegments.last != 'getLedgerBalance') return null;
        index++;
        if (index == 2) expect(uri.queryParameters['balance'], '42.12345');
        return h.page([
          {'ledger_balance': index == 1 ? '42.12345' : '17.23456'},
        ]);
      };
      final data = await bank(h);
      expect(data.entries.first.balance.text, '42.12345');
      expect(data.closingBalance.text, '17.23456');
      expect(ledgerAmount(data.closingBalance), '17.2');
    },
  );
  for (final head in ['01', '02', '03', '04', '05']) {
    test('head $head opening polarity reaches first server request', () async {
      final h = LedgerHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.bankRows = [
        ledgerRow(1, head: head, openingDebit: '100.1', openingCredit: '30.05'),
      ];
      h.transport.requests.clear();
      await bank(h);
      expect(
        h.accountReads.last.uri.queryParameters['balance'],
        ['01', '04'].contains(head) ? '70.05' : '-70.05',
      );
    });
  }
  test(
    'empty bank opening sentinel and patient native reverse polarity',
    () async {
      final h = LedgerHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      final sentinel = {
        'lg_id': 0,
        'opening_dr': '100.25',
        'opening_cr': '30.05',
      };
      h.bankRows = [sentinel];
      h.patientRows = [sentinel];
      h.transport.requests.clear();
      final a = await bank(h), p = await patient(h);
      expect(a.entries, isEmpty);
      expect(a.debit.text, '100.25');
      expect(a.closingBalance.text, '70.2');
      expect(p.closingBalance.text, '-70.2');
      expect(
        h.accountReads.any(
          (r) => r.uri.pathSegments.last == 'getLedgerBalance',
        ),
        isFalse,
      );
    },
  );
  test(
    'zero count and nested encoded arrays accepted without invented rows',
    () async {
      final h = LedgerHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.encoded = true;
      h.nestedEncoded = true;
      expect((await bank(h)).entries.length, 3);
      h.onLedgerGet =
          (uri) async =>
              uri.pathSegments.last == 'getAccLedger'
                  ? {'count': 0, 'items': '[]'}
                  : null;
      final data = await bank(h);
      expect(data.entries, isEmpty);
      expect(data.closingBalance.text, '0');
    },
  );
  test('patient latest/search contract and query encoding', () async {
    final h = LedgerHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    h.transport.requests.clear();
    h.nestedEncoded = true;
    final latest = await h.ledgers.patients(
      h.auth.session!,
      h.profile,
      isCurrent: () => true,
    );
    expect(latest.length, 3);
    expect(
      h.transport.requests.last.uri.pathSegments.last,
      'getFiftyPrescriptionList',
    );
    final rows = await h.ledgers.patients(
      h.auth.session!,
      h.profile,
      query: 'shu',
      isCurrent: () => true,
    );
    expect(rows.length, 2);
    expect(h.transport.requests.last.uri.queryParameters, {'ph_pat': 'shu'});
    await h.ledgers.patients(
      h.auth.session!,
      h.profile,
      query: 'Name & Code',
      isCurrent: () => true,
    );
    expect(
      h.transport.requests.last.uri.queryParameters['ph_pat'],
      'Name & Code',
    );
  });
  test('all native patient validation branches prevent requests', () async {
    final h = LedgerHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    h.transport.requests.clear();
    expect(
      validateLedgerPatientQuery(''),
      'Please Provide Patient Name or Code',
    );
    expect(
      validateLedgerPatientQuery('ab'),
      'Name or Code must be greater than 2 character',
    );
    for (final value in ['a.b', 'a,b', 'a-b']) {
      expect(validateLedgerPatientQuery(value), contains('must not contain'));
    }
    for (final value in ['', 'ab', 'a.b', 'a,b', 'a-b']) {
      await expectLater(
        h.ledgers.patients(
          h.auth.session!,
          h.profile,
          query: value,
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
    }
    expect(h.transport.requests, isEmpty);
  });
  test(
    'malformed count, nested list, ledger fields and numeric values fail',
    () async {
      final h = LedgerHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      for (final response in <JsonMap>[
        {'count': 1, 'items': []},
        {'count': -1, 'items': []},
        {'items': []},
        {
          'count': 1,
          'items': [
            {'acc_ledger': 'null'},
          ],
        },
        {
          'count': 1,
          'items': [
            {'acc_ledger': ''},
          ],
        },
        {
          'count': 1,
          'items': [<String, Object?>{}],
        },
        {
          'count': 1,
          'items': [
            {'acc_ledger': <String, Object?>{}},
          ],
        },
        {
          'count': 1,
          'items': [
            {
              'acc_ledger': [
                {...ledgerRow(1), 'lg_dr_amt': 'bad'},
              ],
            },
          ],
        },
        {
          'count': 1,
          'items': [
            {
              'acc_ledger': [
                {...ledgerRow(1)}..remove('ah_code'),
              ],
            },
          ],
        },
      ]) {
        h.onLedgerGet =
            (uri) async =>
                uri.pathSegments.last == 'getAccLedger' ? response : null;
        await expectLater(bank(h), throwsA(isA<AppFailure>()));
      }
    },
  );
  test('out of range dates rejected before balance requests', () async {
    final h = LedgerHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    h.bankRows = [
      {...ledgerRow(1), 'lg_voucher_date': '31-OCT-26'},
    ];
    h.transport.requests.clear();
    await expectLater(bank(h), throwsA(isA<AppFailure>()));
    expect(h.accountReads.length, 1);
  });
  test(
    'missing balance stops chain instead of retrying forever or showing partial ledger',
    () async {
      final h = LedgerHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.transport.requests.clear();
      h.onLedgerGet =
          (uri) async =>
              uri.pathSegments.last == 'getLedgerBalance' ? h.page([]) : null;
      await expectLater(
        bank(h).timeout(const Duration(seconds: 1)),
        throwsA(isA<AppFailure>()),
      );
      expect(h.accountReads.length, 2);
    },
  );
  test('obsolete response prevents the next balance request', () async {
    final h = LedgerHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    var current = true;
    final gate = Completer<JsonMap>();
    h.onLedgerGet =
        (uri) async =>
            uri.pathSegments.last == 'getLedgerBalance' ? gate.future : null;
    h.transport.requests.clear();
    final work = bank(h, current: () => current);
    await Future<void>.delayed(Duration.zero);
    current = false;
    gate.complete(
      h.page([
        {'ledger_balance': '0'},
      ]),
    );
    await expectLater(work, throwsA(isA<ObsoleteRequest>()));
    expect(h.accountReads.length, 2);
  });
  test(
    'module revocation and stale account suppress all ledger calls',
    () async {
      final h = LedgerHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.transport.requests.clear();
      h.adminData['acc_dashboard'] = '0';
      await expectLater(bank(h), throwsA(isA<AccountsModuleUnavailable>()));
      expect(h.transport.requests, isEmpty);
    },
  );
  test(
    'missing patient identity and duplicate account identities rejected',
    () async {
      expect(
        () => LedgerPatient({...ledgerPatient()}..remove('ph_id')),
        throwsA(isA<AppFailure>()),
      );
      final h = LedgerHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.accountRows = [ledgerAccount(), ledgerAccount()];
      await expectLater(
        h.ledgers.accounts(h.auth.session!, h.profile, isCurrent: () => true),
        throwsA(isA<AppFailure>()),
      );
      for (final invalid in <JsonMap>[
        {'items': jsonEncode([])},
        {'pat_pres_list': null},
        {'pat_pres_list': 'null'},
        {'pat_pres_list': ''},
      ]) {
        h.onLedgerGet =
            (uri) async =>
                uri.pathSegments.last == 'getFiftyPrescriptionList'
                    ? invalid
                    : null;
        await expectLater(
          h.ledgers.patients(h.auth.session!, h.profile, isCurrent: () => true),
          throwsA(isA<AppFailure>()),
        );
      }
    },
  );
  test('native PRM flag and AV report links use invoice order number', () {
    expect(LedgerRow(ledgerRow(1)).opensInvoice, isTrue);
    expect(LedgerRow(ledgerRow(1, flag: '0')).actionable, isFalse);
    expect(LedgerRow(ledgerRow(1, type: 'OTHER')).actionable, isFalse);
    final av = LedgerRow(ledgerRow(3, type: 'AV', order: 'EXAMPLE.DV.3.26'));
    expect(av.opensReport, isTrue);
    expect(av.orderNo, 'EXAMPLE.DV.3.26');
  });
}

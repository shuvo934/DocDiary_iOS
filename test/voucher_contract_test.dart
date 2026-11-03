import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/features/accounts/accounts_dashboard_repository.dart';
import 'package:docdiary_ios/features/accounts/voucher_transaction/voucher_models.dart';
import 'voucher_test_support.dart';

void main() {
  final dates = VoucherDates('01-Oct-26', '31-Oct-26');
  Future<VoucherHarness> signed() async {
    final h = VoucherHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    h.transport.requests.clear();
    return h;
  }

  Future<VoucherData> load(
    VoucherHarness h, {
    bool Function()? current,
  }) async => h.vouchers.load(
    h.auth.session!,
    h.profile,
    dates,
    isCurrent: current ?? () => true,
  );
  test(
    'initial dates default independently to today and native minimum spans month/year boundaries',
    () {
      final now = DateTime(2026, 11, 2, 18, 16);
      expect(VoucherDates.initial('', '', now).first, '02-Nov-26');
      expect(VoucherDates.initial('01-Oct-26', '', now).last, '02-Nov-26');
      expect(VoucherDates.earliest(now), DateTime(2026, 9));
      expect(VoucherDates.earliest(DateTime(2027, 1, 10)), DateTime(2026, 11));
      expect(
        () => VoucherDates('31-Oct-26', '01-Oct-26'),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => VoucherDates('31-Feb-26', '01-Mar-26'),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'ledger money preserves 139.05, equal sums, huge values, negative sign and grouping',
    () {
      expect(
        (VtMoney.parse('139.05') + VtMoney.parse('139.050')).text,
        '278.1',
      );
      expect(
        (VtMoney.parse('99999999999999999999.05') + VtMoney.parse('0')).text,
        '99999999999999999999.05',
      );
      expect(VtMoney.parse('-1234567.05').currency, '৳ -1,234,567.05');
      expect(VtMoney.parse('0.00').text, '0');
      expect((VtMoney.parse('0.3') - VtMoney.parse('0.1')).text, '0.2');
    },
  );
  test(
    'native GET sequence uses distinct first_date and st_date keys and no POST',
    () async {
      final h = await signed();
      final data = await load(h);
      expect(h.transactionReads.map((r) => r.uri.pathSegments.last), [
        'getVoucherCount',
        'getNewVoucherList',
      ]);
      expect(h.transactionReads.first.uri.queryParameters, {
        'first_date': '01-Oct-26',
        'end_date': '31-Oct-26',
      });
      expect(h.transactionReads.last.uri.queryParameters, {
        'st_date': '01-Oct-26',
        'end_date': '31-Oct-26',
      });
      expect(h.posts, isEmpty);
      expect(data.totalCount, BigInt.from(4));
      expect(data.debit.text, '8718.1');
      expect(data.credit.text, '8718.1');
    },
  );
  test(
    'grouping retains first-seen dates/vouchers and original metadata without mutating server rows',
    () async {
      final h = await signed(), before = jsonEncode(voucherLedgerFixture());
      final data = await load(h);
      expect(data.days.map((d) => d.date), ['01-OCT-26', '02-OCT-26']);
      expect(data.days.first.entries.map((e) => e.number), [
        testJv,
        testCv,
        testDv,
      ]);
      expect(data.days.first.entries.first.orderNo, 'PR.26.000016');
      expect(jsonEncode(h.ledger), before);
    },
  );
  test(
    'stable descending debit then credit rows retain equal-value rows exactly once',
    () async {
      final h = await signed(), data = await load(h);
      final bank = data.days.first.entries[1];
      expect(bank.lines.map((l) => l.debitText), ['2620', '1500', '']);
      final decimal = data.days.last.entries.single;
      expect(decimal.lines.length, 3);
      expect(decimal.lines.map((l) => l.account), [
        '(010101001) Equal debit A',
        '(010101001) Equal debit B',
        '(010108000001) Payment Receive (Patient)',
      ]);
      expect(decimal.lines.map((l) => l.debitText), ['139.05', '139.050', '']);
    },
  );
  test(
    'blank/both-sided rows follow corrected native classification without inventing zero rows',
    () {
      final rows = [
        voucherLedgerRow('X', 'JV', '', '', 'empty', '', ''),
        voucherLedgerRow('X', 'JV', '', '', 'both', '1', '2'),
        voucherLedgerRow('X', 'JV', '', '', 'zero', '0.00', ''),
      ];
      final entry = groupVoucherRows(rows).single.entries.single;
      expect(entry.lines.length, 1);
      expect(entry.lines.single.account, 'zero');
    },
  );
  test(
    'local type filter uses type code, preserves full data and recalculates exact totals/count',
    () async {
      final h = await signed(), data = await load(h);
      final filtered = data.filtered('CV (Receive)');
      expect(filtered.totalCount, BigInt.from(2));
      expect(filtered.debit.text, '4398.1');
      expect(filtered.credit.text, '4398.1');
      expect(filtered.days.length, 2);
      expect(data.totalCount, BigInt.from(4));
      expect(data.days.first.entries.length, 3);
      expect(data.filtered('...'), same(data));
      expect(h.transactionReads.length, 2);
      expect(data.filtered('missing').days, isEmpty);
    },
  );
  test(
    'PRM pay flag 1 opens Invoice, AV opens Report, other row types stay inactive',
    () async {
      final h = await signed(), data = await load(h);
      expect(data.days.first.entries.first.opensInvoice, true);
      expect(data.days.first.entries[2].opensReport, true);
      final raw = voucherLedgerRow(
        'X',
        'CV',
        'PRM',
        'PR.26.1',
        'Cash',
        '1',
        '',
        flag: '0',
      );
      expect(groupVoucherRows([raw]).single.entries.single.actionable, false);
      raw['lg_trans_type'] = 'OTHER';
      raw['prm_pay_type_flag'] = '1';
      expect(groupVoucherRows([raw]).single.entries.single.actionable, false);
    },
  );
  test(
    'empty new response resets all totals and handles encoded ORDS arrays',
    () async {
      final h = await signed();
      h.encoded = true;
      await load(h);
      h.ledger = [];
      h.voucherRows = [];
      final data = await load(h);
      expect(data.days, isEmpty);
      expect(data.counts, isEmpty);
      expect(data.debit.text, '0');
      expect(data.typeOptions, isEmpty);
    },
  );
  for (final bad in ['1.5', '-1', 'NaN', 'Infinity']) {
    test('invalid voucher count $bad stops before list request', () async {
      final h = await signed();
      h.voucherRows = [
        {'voucher_type': 'CV (Receive)', 'cc': bad},
      ];
      await expectLater(load(h), throwsA(isA<AppFailure>()));
      expect(h.transactionReads.length, 1);
    });
  }
  test(
    'a malformed amount is rejected even when it is the only row to sort',
    () async {
      final h = await signed();
      h.ledger = [
        voucherLedgerRow('X', 'CV', 'PRM', 'PR.1', 'Cash', 'not a number', ''),
      ];
      await expectLater(load(h), throwsA(isA<AppFailure>()));
    },
  );
  test(
    'incomplete list envelope, missing row field and out-of-range date fail closed',
    () async {
      final h = await signed();
      h.onVoucherGet =
          (u) async =>
              u.path.endsWith('getNewVoucherList')
                  ? {'count': 1, 'items': <Object?>[]}
                  : null;
      await expectLater(load(h), throwsA(isA<AppFailure>()));
      h.onVoucherGet = null;
      h.ledger[1].remove('lg_trans_type');
      await expectLater(load(h), throwsA(isA<AppFailure>()));
      h.ledger = voucherLedgerFixture();
      h.adaptDates = false;
      h.ledger.first['vdate'] = '01-JAN-20';
      await expectLater(load(h), throwsA(isA<AppFailure>()));
    },
  );
  test('stale response cannot continue to second API', () async {
    final h = await signed();
    var current = true;
    final gate = Completer<void>();
    h.onVoucherGet = (_) async {
      await gate.future;
      return null;
    };
    final future = load(h, current: () => current);
    current = false;
    gate.complete();
    await expectLater(future, throwsA(isA<ObsoleteRequest>()));
    expect(h.transactionReads.length, 1);
  });
  for (final flag in ['acc_dashboard', 'hr_acc_active_flag']) {
    test('revoked $flag blocks all voucher endpoints', () async {
      final h = await signed();
      h.adminData[flag] = '0';
      await expectLater(load(h), throwsA(isA<AccountsModuleUnavailable>()));
      expect(h.transactionReads, isEmpty);
    });
  }
  test(
    'role 3 permitted; HR-only role denied before financial reads',
    () async {
      final h = await signed();
      h.adminData['all_access_flag'] = '3';
      await load(h);
      h.transport.requests.clear();
      h.adminData['all_access_flag'] = '2';
      await expectLater(load(h), throwsA(isA<AccountsModuleUnavailable>()));
      expect(h.transactionReads, isEmpty);
    },
  );
  for (final entry
      in {
        'usr_id': 'another',
        'usr_mob_app_access': '0',
        'usr_mob_forced_log_out_flag': '1',
        'exp_date': '01-NOV-26',
      }.entries) {
    test(
      'account guard ${entry.key} precedes document and list reads',
      () async {
        final h = await signed();
        h.adminData[entry.key] = entry.value;
        await expectLater(load(h), throwsA(isA<AppFailure>()));
        expect(h.transactionReads, isEmpty);
      },
    );
  }
  test(
    'voucher report uses encoded p_vm_no and preserves metadata, order, cents and totals',
    () async {
      final h = await signed();
      final report = await h.vouchers.report(
        h.auth.session!,
        h.profile,
        'C STAR.DV&1',
        isCurrent: () => true,
      );
      expect(h.transactionReads.single.uri.queryParameters, {
        'p_vm_no': 'C STAR.DV&1',
      });
      expect(report.title, 'Debit Voucher');
      expect(report.reference, 'Example Payee');
      expect(report.referenceDate, '');
      expect(report.debit.text, '200');
      expect(report.credit.text, '200');
      h.reportRows = [];
      expect(
        (await h.vouchers.report(
          h.auth.session!,
          h.profile,
          testDv,
          isCurrent: () => true,
        )).empty,
        true,
      );
    },
  );
  test(
    'invoice uses PRM code, exact per-line discount/charge, and actual service rows',
    () async {
      final h = await signed();
      final invoice = await h.vouchers.invoice(
        h.auth.session!,
        h.profile,
        'PR.26.000029',
        isCurrent: () => true,
      );
      expect(h.transactionReads.single.uri.queryParameters, {
        'p_prm_code': 'PR.26.000029',
      });
      expect(invoice.lines.length, 2);
      expect(invoice.field('pat_phone'), 'N/A');
      expect(invoice.subTotal.text, '3600');
      expect(invoice.discount.isZero, true);
      expect(invoice.charge.text, '108');
      expect(invoice.grandTotal.text, '3708');
      h.invoiceRows = paymentInvoiceFixture('PR.26.000016');
      h.invoiceRows!.first.addAll({
        'amt': '100.50',
        'prd_discount_amt': '10.25',
        'prd_service_charge_pct': '2.5',
      });
      final discount = await h.vouchers.invoice(
        h.auth.session!,
        h.profile,
        'PR.26.000016',
        isCurrent: () => true,
      );
      expect(discount.charge.text, '2.25625');
      expect(discount.grandTotal.text, '92.50625');
    },
  );
  test(
    'invoice identity mismatch, empty rows and missing totals never return partial data',
    () async {
      final h = await signed();
      h.invoiceRows = paymentInvoiceFixture('OTHER');
      await expectLater(
        h.vouchers.invoice(
          h.auth.session!,
          h.profile,
          'PR.26.000029',
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      h.invoiceRows = [];
      await expectLater(
        h.vouchers.invoice(
          h.auth.session!,
          h.profile,
          'PR.26.000029',
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      h.invoiceRows = paymentInvoiceFixture('PR.26.000029');
      h.invoiceRows!.first.remove('prd_discount_amt');
      await expectLater(
        h.vouchers.invoice(
          h.auth.session!,
          h.profile,
          'PR.26.000029',
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'invoice numeric zero is Free of Cost and a month is retained when supplied',
    () {
      final raw = paymentInvoiceFixture('PR.26.000016').first;
      raw.addAll({
        'prd_rate': '0.00',
        'amt': '0.0',
        'prd_payment_for_month': 'NOV-26',
      });
      final line = InvoiceLine(raw);
      expect(line.rateLabel, 'Free of Cost');
      expect(line.amountLabel, 'Free of Cost');
      expect(line.month, 'NOV-26');
    },
  );
}

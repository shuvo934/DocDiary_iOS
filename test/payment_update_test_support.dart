import 'dart:convert';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/payments/payment_models.dart';
import 'package:docdiary_ios/features/payments/payment_update_models.dart';
import 'package:docdiary_ios/features/payments/payment_update_repository.dart';
import 'payment_test_support.dart';

/// Fictional, non-production payment data. All tests use the in-memory transport.
class PaymentUpdateHarness extends PaymentHarness {
  PaymentUpdateHarness({super.fullAccess, super.mode}) {
    payments = [
      for (var i = 0; i < patients.length; i++)
        {
          ...patients[i],
          'prm_id': '${501 + i}',
          'prm_code': 'PR.26.00050${i + 1}',
          'prm_date': '25-OCT-26',
        },
    ];
    onPaymentGet = (uri) async {
      final override = await onUpdateGet?.call(uri);
      if (override != null) return override;
      final endpoint = uri.pathSegments.last;
      final List<JsonMap> rows;
      String field = 'items';
      switch (endpoint) {
        case 'getFiftyPaymentList':
        case 'getPaymentCodeList':
          rows = payments;
          field = 'pay_list';
        case 'getPaymentDetailsList':
          rows = details;
        case 'getPaymentModeSavedList':
          rows = saved;
        default:
          return null;
      }
      return {'count': rows.length, field: encoded ? jsonEncode(rows) : rows};
    };
  }
  PaymentUpdateRepository get updateRepository =>
      PaymentUpdateRepository(appointments);
  late List<JsonMap> payments;
  List<JsonMap> details = [
    {
      'prd_id': '601',
      'prd_pfn_id': '31',
      'pfn_fee_name': 'Physiotherapy Service Charge',
      'prd_depts_id': '20',
      'depts_name': 'Autism Communication Group',
      'prd_rate': '1000',
      'prd_top_cat_rate': '1200',
      'prd_qty': '1',
      'amount': '1000',
      'available_qty': '1',
      'prd_sched_avail_mark': '0',
      'prd_cancel_mark': '0',
      'prd_return_mark': '0',
    },
  ];
  List<JsonMap> saved = [
    {
      'prmd_id': '701',
      'prmd_amt': '1030',
      'prmd_pmm_id': '1',
      'prmd_pmd_id': '11',
      'prmd_ad_id': '111',
      'pmm_name': 'Cash Payment (1)',
      'account_name': 'Cash in Hand (010101001)',
    },
  ];
  Future<JsonMap?> Function(Uri)? onUpdateGet;
  PaymentUpdateDraft updateDraft() =>
      PaymentUpdateDraft()
        ..select(paymentRecord(payments.first))
        ..load(
          details.map(PaymentUpdateLine.fromJson).toList(),
          adminData['is_pay_mode_active'] == '1'
              ? saved.map(savedPaymentAllocation).toList()
              : [],
        );
  PaymentServiceLine edited(
    PaymentUpdateLine row, {
    int quantity = 2,
    String? unit,
    int? cents,
  }) => PaymentServiceLine(
    service: row.line.service,
    unit:
        unit == null
            ? row.line.unit
            : PaymentChoice.unit(
              units.firstWhere((r) => r['depts_id'] == unit),
            ),
    rate:
        cents == null
            ? row.line.rate
            : PaymentRate(cents, row.line.rate.topCents),
    quantity: quantity,
  );
  PaymentServiceLine newLine({int quantity = 1, int cents = 80000}) =>
      PaymentServiceLine(
        service: PaymentChoice.service(services[1]),
        unit: PaymentChoice.unit(units[1]),
        rate: PaymentRate(cents, 100000),
        quantity: quantity,
      );
  PaymentConfirmation updateConfirmation(
    PaymentUpdateDraft draft, {
    bool replace = false,
  }) {
    final charge = (draft.total * 3 + 50) ~/ 100;
    final q = PaymentQuote(
      total: draft.total,
      charge: charge,
      methods: methods.map(PaymentChoice.method).toList(),
    );
    return PaymentConfirmation(
      q,
      replace
          ? [PaymentAllocation(q.methods[1], q.grandTotal)]
          : [
            ...draft.methods,
            if (q.grandTotal >
                draft.methods.fold<int>(0, (n, r) => n + r.cents))
              PaymentAllocation(
                q.methods[1],
                q.grandTotal -
                    draft.methods.fold<int>(0, (n, r) => n + r.cents),
              ),
          ],
      saved: draft.methods,
    );
  }
}

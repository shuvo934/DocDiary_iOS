import 'dart:convert';
import 'package:docdiary_ios/core/native_dates.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/accounts/voucher_transaction/voucher_repository.dart';
import 'accounts_dashboard_test_support.dart';
import 'support.dart';

JsonMap voucherLedgerRow(
  String number,
  String type,
  String trans,
  String order,
  String account,
  String dr,
  String cr, {
  String date = '01-OCT-26',
  String flag = '1',
}) => {
  'vdate': date,
  'lg_voucher_no': number,
  'lg_particulars': 'Synthetic particulars for $number. Reference $order.',
  'lg_inv_pur_no': order,
  'lg_trans_type': trans,
  'prm_pay_type_flag': flag,
  'ad_dtl': account,
  'lg_dr_amt': dr,
  'lg_cr_amt': cr,
  'lg_voucher_type': type,
};
const testJv = 'C-STAR.JV.0016.26',
    testCv = 'C-STAR.CV.0016.26',
    testDv = 'C-STAR.DV.03399.26',
    testDecimal = 'C-STAR.CV.0022.26';
List<JsonMap> voucherLedgerFixture() => [
  voucherLedgerRow(
    testJv,
    'JV',
    'PRM',
    'PR.26.000016',
    '(010108000001) Payment Receive (Patient)',
    '4120',
    '',
  ),
  voucherLedgerRow(
    testJv,
    'JV',
    'PRM',
    'PR.26.000016',
    '(030101001) Sales Revenue',
    '',
    '4000',
  ),
  voucherLedgerRow(
    testJv,
    'JV',
    'PRM',
    'PR.26.000016',
    '(020109000001) Commission Payable to HIS Vendor',
    '',
    '120',
  ),
  voucherLedgerRow(
    testCv,
    'CV',
    'PRM',
    'PR.26.000016',
    '(010101001) Cash in Hand',
    '1500',
    '',
  ),
  voucherLedgerRow(
    testCv,
    'CV',
    'PRM',
    'PR.26.000016',
    '(010301000004) Example Bank',
    '2620',
    '',
  ),
  voucherLedgerRow(
    testCv,
    'CV',
    'PRM',
    'PR.26.000016',
    '(010108000001) Payment Receive (Patient)',
    '',
    '4120',
  ),
  voucherLedgerRow(
    testDv,
    'DV',
    'AV',
    testDv,
    '(040106000001) Overtime',
    '200',
    '',
    flag: '',
  ),
  voucherLedgerRow(
    testDv,
    'DV',
    'AV',
    testDv,
    '(010101001) Cash in Hand',
    '',
    '200',
    flag: '',
  ),
  voucherLedgerRow(
    testDecimal,
    'CV',
    'PRM',
    'PR.26.000029',
    '(010101001) Equal debit A',
    '139.05',
    '',
    date: '02-OCT-26',
  ),
  voucherLedgerRow(
    testDecimal,
    'CV',
    'PRM',
    'PR.26.000029',
    '(010101001) Equal debit B',
    '139.050',
    '',
    date: '02-OCT-26',
  ),
  voucherLedgerRow(
    testDecimal,
    'CV',
    'PRM',
    'PR.26.000029',
    '(010108000001) Payment Receive (Patient)',
    '',
    '278.10',
    date: '02-OCT-26',
  ),
];
List<JsonMap> voucherReportFixture() => [
  {
    'vm_date': '01-OCT-26',
    'vm_type': 'DV',
    'vm_bill_ref_no': 'Example Payee',
    'vm_bill_ref_date': '',
    'vm_naration': 'Teacher higher for Evening Shift',
    'ad_code': '040106000001',
    'ad_name': 'Overtime',
    'vd_dr_amt': '200',
    'vd_cr_amt': '',
  },
  {
    'vm_date': '01-OCT-26',
    'vm_type': 'DV',
    'vm_bill_ref_no': 'Example Payee',
    'vm_bill_ref_date': '',
    'vm_naration': 'Teacher higher for Evening Shift',
    'ad_code': '010101001',
    'ad_name': 'Cash in Hand',
    'vd_dr_amt': '',
    'vd_cr_amt': '200',
  },
];
List<JsonMap> paymentInvoiceFixture(String code) => [
  for (var i = 0; i < (code == 'PR.26.000016' ? 1 : 2); i++)
    {
      'prm_code': code,
      'prm_date': '02-NOV-26',
      'pat_name': 'Example Patient',
      'pat_code': '26.01.000001',
      'ph_sub_code': '26.01.000001.01',
      'p_age': '0 Year 11 Months 16 Days',
      'gender': 'Male',
      'marital_status': 'Single',
      'ph_patient_cat': 'A',
      'address': 'Example Address',
      'pat_phone': null,
      'pfn_fee_name':
          i == 0
              ? 'Physiotherapy Service Charge'
              : 'Overall Physiotherapy Service',
      'depts_name':
          i == 0 ? 'Autism Communication Group' : 'Overall Physiotherapy Unit',
      'prd_payment_for_month': '',
      'prd_rate': i == 0 ? '1000' : '800',
      'prd_qty': code == 'PR.26.000016' ? '4' : '2',
      'amt':
          code == 'PR.26.000016'
              ? '4000'
              : i == 0
              ? '2000'
              : '1600',
      'prd_service_charge_pct': '3',
      'prd_discount_amt': '0',
      'prm_amt': code == 'PR.26.000016' ? '4120' : '3708',
    },
];

class VoucherHarness extends AccountsHarness {
  VoucherHarness() {
    voucherRows = [
      {'voucher_type': 'CV (Receive)', 'cc': '2'},
      {'voucher_type': 'JV (Transfer)', 'cc': '1'},
      {'voucher_type': 'DV (Payment)', 'cc': '1'},
    ];
    transport.onGet = respondVoucher;
  }
  VoucherRepository get vouchers =>
      VoucherRepository(transport, now: () => now);
  List<JsonMap> ledger = voucherLedgerFixture(),
      reportRows = voucherReportFixture();
  List<JsonMap>? invoiceRows;
  bool adaptDates = true;
  Future<JsonMap?> Function(Uri)? onVoucherGet;
  Future<JsonMap> respondVoucher(Uri uri) async {
    if (!uri.path.contains('/acc_dashboard/')) return respondAccounts(uri);
    final override = await onVoucherGet?.call(uri);
    if (override != null) return override;
    List<JsonMap>? rows;
    switch (uri.pathSegments.last) {
      case 'getNewVoucherList':
        rows = ledger;
        if (adaptDates) {
          final first = parseOracleDate(uri.queryParameters['st_date']!),
              last = parseOracleDate(uri.queryParameters['end_date']!),
              second = first.add(const Duration(days: 1));
          rows = [
            for (final row in ledger)
              {
                ...row,
                'vdate': oracleDate(
                  row['vdate'] == '02-OCT-26' && !second.isAfter(last)
                      ? second
                      : first,
                ),
              },
          ];
        }
      case 'getVoucherReport':
        rows = reportRows;
      case 'getPaymentInvoice':
        rows =
            invoiceRows ??
            paymentInvoiceFixture(uri.queryParameters['p_prm_code']!);
      default:
        return respondAccounts(uri);
    }
    return {'count': rows.length, 'items': encoded ? jsonEncode(rows) : rows};
  }

  List<RequestRecord> get transactionReads =>
      transport.requests
          .where(
            (r) => [
              'getVoucherCount',
              'getNewVoucherList',
              'getVoucherReport',
              'getPaymentInvoice',
            ].contains(r.uri.pathSegments.last),
          )
          .toList();
}

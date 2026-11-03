import 'dart:convert';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/accounts/account_ledger/ledger_repository.dart';
import 'package:docdiary_ios/features/accounts/voucher_transaction/voucher_models.dart';
import 'voucher_test_support.dart';

JsonMap ledgerAccount({String id = 'bank', String head = '01', String? name}) =>
    {
      'lg_ad_id': id,
      'ad_name':
          name ?? 'Example Bank Ltd. A/C No 1000123456, Central Branch, Dhaka.',
      'ad_code': '010301000001',
      'al2_name': 'Bank Account',
      'al1_name': 'Financial Account',
      'ah_name': 'Assets',
      'ah_code': head,
    };
JsonMap ledgerPatient({
  String id = 'patient',
  String name = 'Example Patient',
  String? code,
}) => {
  'ph_id': id,
  'ph_sub_code': code ?? '26.01.00009.01',
  'pat_name': name,
  'pat_code': '26.01.00009',
  'pat_date': '02-NOV-26',
};
JsonMap ledgerRow(
  int i, {
  String head = '01',
  String debit = '0',
  String credit = '0',
  String openingDebit = '0',
  String openingCredit = '0',
  String type = 'PRM',
  String flag = '1',
  String? order,
}) => {
  'lg_id': '$i',
  'lg_voucher_date': '02-NOV-26',
  'lg_voucher_no':
      'EXAMPLE.${i.isEven ? 'CV' : 'JV'}.${i.toString().padLeft(5, '0')}.26',
  'lg_particulars':
      i == 3
          ? 'Synthetic cash deposit voucher.'
          : '${debit == '0' ? 'Received with thanks' : 'Receivable'} against synthetic invoice. Example Patient.',
  'lg_dr_amt': debit,
  'lg_cr_amt': credit,
  'dr_null': null,
  'cr_null': null,
  'opening_dr': openingDebit,
  'opening_cr': openingCredit,
  'ah_code': head,
  'lg_trans_type': type,
  'lg_inv_pur_no': order ?? 'PR.26.000016',
  'prm_pay_type_flag': flag,
};

class LedgerHarness extends VoucherHarness {
  LedgerHarness() {
    transport.onGet = respondLedger;
  }
  LedgerRepository get ledgers => LedgerRepository(transport, now: () => now);
  List<JsonMap> accountRows = [
    ledgerAccount(),
    ledgerAccount(id: 'cash', name: 'Cash in Hand'),
  ];
  List<JsonMap> patients = [
    ledgerPatient(),
    ledgerPatient(id: 'shu1', name: 'Example Shuhasini'),
    ledgerPatient(id: 'shu2', name: 'Example Shuayeb'),
  ];
  List<JsonMap> bankRows = [
    ledgerRow(1, debit: '11165', openingDebit: '-589436'),
    ledgerRow(2, debit: '7105', openingDebit: '-589436'),
    ledgerRow(
      3,
      debit: '15000',
      openingDebit: '-589436',
      type: 'AV',
      order: 'EXAMPLE.DV.00003.26',
    ),
  ];
  List<JsonMap> patientRows = [
    ledgerRow(1, debit: '4120'),
    ledgerRow(2, credit: '4120'),
    ledgerRow(4, credit: '2060'),
    ledgerRow(5, debit: '3708'),
  ];
  Future<JsonMap?> Function(Uri)? onLedgerGet;
  bool nestedEncoded = false;
  JsonMap page(List<JsonMap> rows) => {
    'count': rows.length,
    'items': encoded ? jsonEncode(rows) : rows,
  };
  Future<JsonMap> respondLedger(Uri uri) async {
    final endpoint = uri.pathSegments.last;
    if (![
      'getAccountList',
      'getAccLedger',
      'getAccLedgerPh',
      'getLedgerBalance',
      'getFiftyPrescriptionList',
      'getPrescriptionCodeList',
    ].contains(endpoint)) {
      return respondVoucher(uri);
    }
    final custom = await onLedgerGet?.call(uri);
    if (custom != null) return custom;
    switch (endpoint) {
      case 'getAccountList':
        return page(accountRows);
      case 'getAccLedger':
      case 'getAccLedgerPh':
        final rows = endpoint == 'getAccLedger' ? bankRows : patientRows;
        return page([
          {'acc_ledger': nestedEncoded ? jsonEncode(rows) : rows},
        ]);
      case 'getLedgerBalance':
        final q = uri.queryParameters;
        final debit = VtMoney.parse(q['debit_amnt']),
            credit = VtMoney.parse(q['credit_amnt']),
            prior = VtMoney.parse(q['balance']);
        final balance =
            ['02', '03', '05'].contains(q['ah_code'])
                ? prior + credit - debit
                : prior + debit - credit;
        return page([
          {'ledger_balance': balance.text},
        ]);
      default:
        final query = uri.queryParameters['ph_pat']?.toLowerCase();
        final rows =
            query == null
                ? patients
                : patients
                    .where(
                      (p) =>
                          (p['pat_name'] as String).toLowerCase().contains(
                            query,
                          ) ||
                          (p['ph_sub_code'] as String).contains(query),
                    )
                    .toList();
        return {'pat_pres_list': nestedEncoded ? jsonEncode(rows) : rows};
    }
  }
}

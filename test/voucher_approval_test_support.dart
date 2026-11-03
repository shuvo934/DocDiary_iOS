import 'dart:convert';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/accounts/voucher_approval/voucher_approval_models.dart';
import 'package:docdiary_ios/features/accounts/voucher_approval/voucher_approval_repository.dart';
import 'accounts_dashboard_test_support.dart';
import 'support.dart';

JsonMap approvalChoice(
  VoucherApprovalKind kind,
  int index, {
  bool approved = true,
}) => {
  'vm_id': '${kind.index + 1}0$index',
  'vm_no': 'EXAMPLE.${kind.code}.${index.toString().padLeft(5, '0')}.26',
  'vm_date': '02-NOV-26',
  'vm_type': kind.code,
  'vm_bill_ref_no': 'Example Payee',
  'vm_naration': 'Synthetic voucher $index',
  'bill_date': '02-NOV-26',
  'vm_voucher_approved_flag': approved ? '1' : '0',
  'amount': '183000',
  'status': approved ? 'Approved' : 'Pending',
  'approved_user': 'Example Reviewer',
  'approved_date': '03-NOV-26, 10:15 am',
};

List<JsonMap> approvalLedger(JsonMap choice) => [
  for (var i = 0; i < 2; i++)
    {
      'vm_id': choice['vm_id'],
      'vm_no': choice['vm_no'],
      'vm_date': choice['vm_date'],
      'vm_time': '01:38 pm',
      'vm_naration': choice['vm_naration'],
      'vm_user': 'Example Prepared User',
      'vm_bill_ref_no': choice['vm_bill_ref_no'],
      'vm_bill_ref_date': choice['bill_date'],
      'vm_no_id': '1',
      'vm_cid_id': '7',
      'vm_proj_id': '1',
      'vm_voucher_approved_flag': choice['vm_voucher_approved_flag'],
      'vm_voucher_approved_by': 'Example Reviewer',
      'vm_voucher_approved_time': '03-NOV-26, 10:15 am',
      'vm_der_id': null,
      'vd_id': '$i',
      'vd_ad_id': '${i + 10}',
      'ad_code': i == 0 ? '010101001' : '010108000001',
      'ad_name': i == 0 ? 'Cash in Hand' : 'Payment Receive',
      'vd_cheque_no': i == 0 ? '000' : null,
      'vd_cheque_date': i == 0 ? '02-NOV-26' : null,
      'vd_dr_amt': i == 0 ? '183000' : null,
      'vd_cr_amt': i == 1 ? '183000' : null,
    },
];

class ApprovalHarness extends AccountsHarness {
  ApprovalHarness() : super(clock: DateTime(2026, 11, 3, 11, 51)) {
    choices = {
      for (final k in VoucherApprovalKind.values)
        k: [
          approvalChoice(k, 1),
          approvalChoice(k, 2, approved: false),
          approvalChoice(k, 3),
          approvalChoice(k, 4),
        ],
    };
    for (final rows in choices.values) {
      for (final choice in rows) {
        ledgers[choice['vm_id'] as String] = approvalLedger(choice);
      }
    }
    transport.onGet = respondApproval;
    transport.onPost = respondPost;
  }
  VoucherApprovalRepository get approvals =>
      VoucherApprovalRepository(transport, now: () => now);
  late Map<VoucherApprovalKind, List<JsonMap>> choices;
  final ledgers = <String, List<JsonMap>>{};
  Future<JsonMap?> Function(Uri)? onApprovalGet;
  Future<JsonMap?> Function(Uri, Map<String, String>)? onApprovalPost;
  bool encodeNested = false;
  JsonMap page(List<JsonMap> rows) => {
    'count': rows.length,
    'items': encoded ? jsonEncode(rows) : rows,
  };
  ApprovalVoucher choice(VoucherApprovalKind k, int i) =>
      ApprovalVoucher(k, choices[k]![i]);
  List<JsonMap> ledgerFor(VoucherApprovalKind k, int i) =>
      ledgers[choice(k, i).id]!;
  Future<JsonMap> respondApproval(Uri uri) async {
    final endpoint = uri.pathSegments.last;
    if (![
      'getVoucherSelectListHundred',
      'getVoucherSelectListBySearch',
      'getVoucherDetails',
      'getVoucherReport',
    ].contains(endpoint))
      return respondAccounts(uri);
    final custom = await onApprovalGet?.call(uri);
    if (custom != null) return custom;
    if (endpoint == 'getVoucherSelectListHundred' ||
        endpoint == 'getVoucherSelectListBySearch') {
      final kind = VoucherApprovalKind.values.singleWhere(
        (k) => k.code == uri.queryParameters['v_type'],
      );
      var rows = choices[kind]!;
      if (endpoint == 'getVoucherSelectListBySearch') {
        final query = uri.queryParameters['p_vm_no']!.toLowerCase();
        rows =
            rows
                .where(
                  (r) => (r['vm_no'] as String).toLowerCase().contains(query),
                )
                .toList();
      }
      return page(rows);
    }
    if (endpoint == 'getVoucherDetails') {
      final rows = ledgers[uri.queryParameters['vm_id']] ?? [];
      return page([
        {'voucher_list': encodeNested ? jsonEncode(rows) : rows},
      ]);
    }
    final rows =
        ledgers.values
            .expand((r) => r)
            .where((r) => r['vm_no'] == uri.queryParameters['p_vm_no'])
            .toList();
    return page([
      for (final row in rows)
        {
          'vm_date': row['vm_date'],
          'vm_type': 'AV',
          'vm_bill_ref_no': row['vm_bill_ref_no'],
          'vm_bill_ref_date': row['vm_bill_ref_date'],
          'vm_naration': row['vm_naration'],
          'ad_code': row['ad_code'],
          'ad_name': row['ad_name'],
          'vd_dr_amt': row['vd_dr_amt'],
          'vd_cr_amt': row['vd_cr_amt'],
        },
    ]);
  }

  void applyUpdate(Map<String, String> headers) {
    final id = headers['P_VM_ID'], flag = headers['P_APPROVE_FLAG'];
    for (final rows in choices.values) {
      for (final r in rows) {
        if (r['vm_id'] == id) {
          r['vm_voucher_approved_flag'] = flag;
          r['status'] = flag == '1' ? 'Approved' : 'Pending';
        }
      }
    }
    for (final row in ledgers[id] ?? <JsonMap>[]) {
      row['vm_voucher_approved_flag'] = flag;
    }
  }

  Future<JsonMap> respondPost(Uri uri, Map<String, String> headers) async {
    if (uri.pathSegments.last != 'updateVoucher')
      return {'string_out': 'Successfully Created'};
    final custom = await onApprovalPost?.call(uri, headers);
    if (custom != null) return custom;
    applyUpdate(headers);
    return {'string_out': 'Successfully Created'};
  }

  List<RequestRecord> get approvalReads =>
      transport.requests
          .where((r) => r.uri.path.contains('/acc_dashboard/'))
          .toList();
  List<RequestRecord> get updates =>
      approvalReads.where((r) => r.method == 'POST').toList();
}

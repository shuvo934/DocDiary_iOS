import 'dart:convert';
import '../../../core/failure.dart';
import '../../../core/native_json.dart';
import '../accounts_dashboard_models.dart';
import '../voucher_transaction/voucher_models.dart';

enum VoucherApprovalKind {
  credit('CV', 'Credit'),
  debit('DV', 'Debit'),
  journal('JV', 'Journal');

  const VoucherApprovalKind(this.code, this.label);
  final String code, label;
  String get title => '$label Voucher Approval';
  String get narrationLabel => this == debit ? 'Remarks:' : 'Narration:';
}

enum VoucherApprovalAction {
  approve('1', 'Approve', 'APPROVED'),
  disapprove('0', 'Disapprove', 'DISAPPROVED');

  const VoucherApprovalAction(this.flag, this.label, this.feedback);
  final String flag, label, feedback;
}

class VoucherApprovalChanged implements Exception {
  const VoucherApprovalChanged();
}

String approvalField(JsonMap row, String key) =>
    nativeText(accountsField(row, key));

/// Native approval/report screenshots use lakh grouping; retain exact cents.
String approvalAmount(VtMoney value) {
  final text = value.text, negative = text.startsWith('-');
  final parts = (negative ? text.substring(1) : text).split('.');
  final digits = parts.first;
  var whole = digits;
  if (digits.length > 3) {
    final leading = digits
        .substring(0, digits.length - 3)
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+(?!\d))'), (m) => '${m[1]},');
    whole = '$leading,${digits.substring(digits.length - 3)}';
  }
  return '${negative ? '-' : ''}$whole${parts.length == 2 ? '.${parts[1]}' : ''}';
}

class ApprovalVoucher {
  ApprovalVoucher(this.kind, JsonMap row)
    : values = Map.unmodifiable({
        for (final key in fields) key: approvalField(row, key),
      }) {
    accountsRequire(
      id.isNotEmpty &&
          number.isNotEmpty &&
          value('vm_type') == kind.code &&
          (flag == '0' || flag == '1') &&
          status == (flag == '0' ? 'Pending' : 'Approved'),
      'The server returned an invalid voucher selection.',
    );
    VtMoney.parse(value('amount'));
  }
  static const fields = [
    'vm_id',
    'vm_no',
    'vm_date',
    'vm_type',
    'vm_bill_ref_no',
    'vm_naration',
    'bill_date',
    'vm_voucher_approved_flag',
    'amount',
    'status',
    'approved_user',
    'approved_date',
  ];
  final VoucherApprovalKind kind;
  final Map<String, String> values;
  String value(String key) => values[key] ?? '';
  String get id => value('vm_id');
  String get number => value('vm_no');
  String get flag => value('vm_voucher_approved_flag');
  String get status => value('status');
  bool get approved => flag == '1';
  String get prefix {
    final i = number.indexOf('.${kind.code}.');
    return i < 0 ? '' : number.substring(0, i + 4);
  }

  String get auditUser =>
      approved && value('approved_user').isEmpty
          ? 'No Name found'
          : value('approved_user');
  String get auditUserLabel =>
      approved
          ? 'Approved By:'
          : value('approved_user').isNotEmpty
          ? 'Disapproved By:'
          : 'Approved By / Disapproved By:';
  String get auditTimeLabel =>
      approved
          ? 'Approved Time:'
          : value('approved_user').isNotEmpty
          ? 'Disapproved Time:'
          : 'Approved / Disapproved Time:';
}

class ApprovalLedgerLine {
  ApprovalLedgerLine(JsonMap row)
    : values = Map.unmodifiable({
        for (final key in fields) key: _field(row, key),
      }) {
    debit = VtMoney.parse(value('vd_dr_amt'));
    credit = VtMoney.parse(value('vd_cr_amt'));
  }
  static const fields = [
    'vm_id',
    'vm_no',
    'vm_date',
    'vm_time',
    'vm_naration',
    'vm_user',
    'vm_bill_ref_no',
    'vm_bill_ref_date',
    'vm_no_id',
    'vm_cid_id',
    'vm_proj_id',
    'vm_voucher_approved_flag',
    'vm_voucher_approved_by',
    'vm_voucher_approved_time',
    'vm_der_id',
    'vd_id',
    'vd_ad_id',
    'ad_code',
    'ad_name',
    'vd_cheque_no',
    'vd_cheque_date',
    'vd_dr_amt',
    'vd_cr_amt',
  ];
  final Map<String, String> values;
  late final VtMoney debit, credit;
  static String _field(JsonMap row, String key) {
    final raw = accountsField(row, key);
    return key == 'vm_voucher_approved_flag' && (raw == null || raw == 'null')
        ? '0'
        : nativeText(raw);
  }

  String value(String key) => values[key] ?? '';
  Map<String, String> get snapshot => {
    ...values,
    'vd_dr_amt': debit.text,
    'vd_cr_amt': credit.text,
  };
}

class ApprovalVoucherDetail {
  ApprovalVoucherDetail(this.voucher, List<ApprovalLedgerLine> rows)
    : lines = List.unmodifiable(rows) {
    for (final line in lines) {
      accountsRequire(
        line.value('vm_id') == voucher.id &&
            line.value('vm_no') == voucher.number,
        'The server returned details for a different voucher.',
      );
      if (line.value('vm_voucher_approved_flag') != voucher.flag) {
        throw const VoucherApprovalChanged();
      }
    }
  }
  final ApprovalVoucher voucher;
  final List<ApprovalLedgerLine> lines;
  bool get empty => lines.isEmpty;
  String value(String key) => empty ? '' : lines.first.value(key);
  VtMoney get debit => lines.fold(VtMoney.zero, (sum, l) => sum + l.debit);
  VtMoney get credit => lines.fold(VtMoney.zero, (sum, l) => sum + l.credit);
  bool get balanced => debit.compareTo(credit) == 0;
  String get snapshot => jsonEncode(lines.map((l) => l.snapshot).toList());
  VoucherApprovalAction get action =>
      voucher.approved
          ? VoucherApprovalAction.disapprove
          : VoucherApprovalAction.approve;
  void validateAction(VoucherApprovalAction requested) {
    accountsRequire(
      !empty && requested == action,
      'Reload this voucher before changing its approval.',
    );
    if (voucher.kind == VoucherApprovalKind.debit &&
        requested == VoucherApprovalAction.approve &&
        !balanced) {
      throw const AppFailure(
        'Total Debit Amount is not equal to Total Credit Amount',
        kind: FailureKind.invalidData,
      );
    }
  }
}

String? validateVoucherQuery(String query, String prefix) {
  if (query.trim().isEmpty) return 'Please Provide Voucher No';
  if (query.startsWith('.')) {
    return "Invalid Character. Code should not start with '.'";
  }
  if (query.length < 3) return 'Voucher No must be greater than 2 character';
  if (prefix.isNotEmpty && query.contains(prefix)) {
    return "Code must not include '$prefix'";
  }
  return null;
}

class VoucherPickerData {
  const VoucherPickerData({
    this.rows = const [],
    this.busy = false,
    this.searched = false,
    this.failure,
  });
  final List<ApprovalVoucher> rows;
  final bool busy, searched;
  final Object? failure;
}

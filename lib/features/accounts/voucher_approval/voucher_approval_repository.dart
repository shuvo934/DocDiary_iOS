import '../../../core/failure.dart';
import '../../../core/native_json.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../accounts_dashboard_models.dart';
import '../voucher_transaction/voucher_repository.dart';
import 'voucher_approval_models.dart';

class VoucherApprovalRepository extends VoucherRepository {
  VoucherApprovalRepository(super.transport, {super.now});
  Future<List<JsonMap>> _rows(
    AuthSession session,
    AccountProfile profile,
    String endpoint,
    Map<String, String> query,
    bool Function() current,
  ) async {
    guard(session, profile, current);
    final response = await transport
        .get(
          apiEndpoint(session.center.baseUri, 'acc_dashboard/$endpoint', query),
        )
        .timeout(const Duration(seconds: 30));
    guard(session, profile, current);
    final count = int.tryParse(nativeText(response['count']).trim());
    accountsRequire(
      count != null && count >= 0 && response.containsKey('items'),
      'The server returned incomplete voucher data.',
    );
    final rows = nativeItems(response);
    accountsRequire(
      count == rows.length,
      'The server returned incomplete voucher data.',
    );
    return rows;
  }

  Future<List<ApprovalVoucher>> latest(
    AuthSession session,
    AccountProfile profile,
    VoucherApprovalKind kind, {
    required bool Function() isCurrent,
  }) async {
    final rows = await _rows(session, profile, 'getVoucherSelectListHundred', {
      'v_type': kind.code,
    }, isCurrent);
    return List.unmodifiable(rows.map((r) => ApprovalVoucher(kind, r)));
  }

  Future<List<ApprovalVoucher>> search(
    AuthSession session,
    AccountProfile profile,
    VoucherApprovalKind kind,
    String query,
    String prefix, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    final error = validateVoucherQuery(query, prefix);
    if (error != null) throw AppFailure(error, kind: FailureKind.invalidData);
    final rows = await _rows(session, profile, 'getVoucherSelectListBySearch', {
      'v_type': kind.code,
      'p_vm_no': query,
    }, isCurrent);
    return List.unmodifiable(rows.map((r) => ApprovalVoucher(kind, r)));
  }

  Future<ApprovalVoucherDetail> details(
    AuthSession session,
    AccountProfile profile,
    ApprovalVoucher voucher, {
    required bool Function() isCurrent,
  }) async {
    final rows = await _rows(session, profile, 'getVoucherDetails', {
      'vm_id': voucher.id,
    }, isCurrent);
    final lines = <ApprovalLedgerLine>[];
    for (final row in rows) {
      accountsRequire(
        row.containsKey('voucher_list') && row['voucher_list'] != null,
        'The server returned incomplete voucher details.',
      );
      final nested = nativeArray(row['voucher_list']);
      lines.addAll(nested.map(ApprovalLedgerLine.new));
    }
    guard(session, profile, isCurrent);
    return ApprovalVoucherDetail(voucher, lines);
  }

  /// Native contract: three HTTP headers, no form/JSON body, no POST retry.
  Future<void> submit(
    AuthSession session,
    AccountProfile profile,
    ApprovalVoucherDetail shown,
    VoucherApprovalAction action, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    shown.validateAction(action);
    final headers = {
      'P_VM_ID': shown.voucher.id,
      'P_APPROVE_FLAG': action.flag,
      'P_USER_ID': profile.value('usr_name'),
    };
    accountsRequire(
      headers.values.every(
        (v) => v.isNotEmpty && v.codeUnits.every((c) => c >= 32 && c <= 126),
      ),
      'This account contains values unsupported by the server headers.',
    );
    // A confirmation covers the displayed voucher, status and ledger amounts.
    final fresh = await details(
      session,
      profile,
      shown.voucher,
      isCurrent: isCurrent,
    );
    if (fresh.empty || fresh.snapshot != shown.snapshot) {
      throw const VoucherApprovalChanged();
    }
    fresh.validateAction(action);
    guard(session, profile, isCurrent);
    final response = await transport
        .post(
          apiEndpoint(session.center.baseUri, 'acc_dashboard/updateVoucher'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 30));
    guard(session, profile, isCurrent);
    accountsRequire(
      response['string_out'] == 'Successfully Created',
      'The server did not confirm the voucher update.',
    );
  }
}

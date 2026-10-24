import '../../../core/failure.dart';
import '../../../core/native_json.dart';
import '../../../core/transport.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../hr_dashboard_repository.dart';
import 'leave_approval_models.dart';

class LeaveApprovalRepository {
  LeaveApprovalRepository(this.transport, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Transport transport;
  final DateTime Function() now;

  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() current,
  ) {
    HrDashboardRepository(transport, now: now).guard(session, profile, current);
    if (profile.value('usr_name').trim().isEmpty) throw leaveApprovalInvalid;
  }

  Future<List<JsonMap>> _rows(
    AuthSession session,
    AccountProfile profile,
    String endpoint,
    Map<String, String> query,
    bool Function() current,
  ) async {
    guard(session, profile, current);
    final response = await transport.get(
      apiEndpoint(session.center.baseUri, 'hrm_dashboard/$endpoint', query),
    );
    guard(session, profile, current);
    final count = int.tryParse(nativeText(response['count']).trim());
    if (count == null || count < 0) {
      throw AppFailure(
        'The server returned an invalid count for $endpoint.',
        kind: FailureKind.invalidData,
      );
    }
    if (count == 0) return [];
    try {
      final rows = nativeItems(response);
      if (rows.isEmpty) throw leaveApprovalInvalid;
      return rows;
    } on AppFailure {
      throw AppFailure(
        'The server returned an invalid list for $endpoint.',
        kind: FailureKind.invalidData,
      );
    }
  }

  Future<List<LeaveApprovalRequest>> pending(
    AuthSession session,
    AccountProfile profile, {
    required bool Function() isCurrent,
  }) async {
    final rows = await _rows(session, profile, 'getLeaveRequestList', {
      'p_usr_name': profile.value('usr_name'),
    }, isCurrent);
    // Like native, retain row order and repeated display values/IDs.
    return List.unmodifiable(rows.map(LeaveApprovalRequest.fromJson));
  }

  Future<LeaveApprovalDetail?> detail(
    AuthSession session,
    AccountProfile profile,
    LeaveApprovalRequest request, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    if (!request.valid) throw leaveApprovalInvalid;
    final rows = await _rows(session, profile, 'getLeaveData', {
      'p_la_id': request.id,
      'p_usr_name': profile.value('usr_name'),
    }, isCurrent);
    // Native assigns each returned row in sequence, displaying the final row.
    final details = rows.map(LeaveApprovalDetail.new).toList();
    return details.isEmpty ? null : details.last;
  }

  /// Native parameters are HTTP headers; there is no form/JSON body.
  /// An uncertain POST is never automatically repeated. The screen's Retry
  /// refreshes pending/detail and requires a new explicit confirmation.
  Future<LeaveApprovalResult> submit(
    AuthSession session,
    AccountProfile profile,
    LeaveApprovalRequest request,
    LeaveApprovalDetail detail,
    LeaveApprovalAction action,
    String comment, {
    bool prescriptionChecked = false,
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    if (!request.valid) throw leaveApprovalInvalid;
    if (action == LeaveApprovalAction.approve && !detail.hasEnoughBalance) {
      throw const AppFailure(
        'Leave Balance is lower than Total Leave Days.',
        kind: FailureKind.invalidData,
      );
    }
    if (action == LeaveApprovalAction.reject && comment.trim().isEmpty) {
      throw const AppFailure(
        'Please mention reason for reject',
        kind: FailureKind.invalidData,
      );
    }
    // The legacy API has no agreed Unicode encoding for header comments.
    // Do not corrupt Bangla text or silently move it into a different body.
    if (comment.codeUnits.any((unit) => unit < 32 || unit > 126)) {
      throw const AppFailure(
        'This server sends comments as HTTP headers. Please use a single line of English text.',
        kind: FailureKind.invalidData,
      );
    }
    final headers = {
      'P_LA_ID': request.id,
      'P_USR_NAME': profile.value('usr_name'),
      if (action == LeaveApprovalAction.approve)
        'P_SL_CHECK': detail.isSickLeave && prescriptionChecked ? '1' : '0',
      'P_TEXT_COMMENTS': comment,
    };
    if (headers.values.any(
      (v) => v.codeUnits.any((unit) => unit < 32 || unit > 126),
    )) {
      throw const AppFailure(
        'This request contains account values unsupported by the server headers.',
        kind: FailureKind.invalidData,
      );
    }
    final rows = await pending(session, profile, isCurrent: isCurrent);
    if (!rows.any(request.sameRequest)) {
      throw const LeaveRequestNoLongerPending();
    }
    guard(session, profile, isCurrent);
    final response = await transport.post(
      apiEndpoint(session.center.baseUri, 'hrm_dashboard/${action.endpoint}'),
      headers: headers,
    );
    guard(session, profile, isCurrent);
    final status = response['string_out'];
    if (status is! String || status != 'Successfully Created') {
      throw AppFailure(
        status is String && nativeText(status).isNotEmpty
            ? status
            : 'The server did not confirm this request.',
      );
    }
    final updated = response['updated_req'];
    if (updated is! String || nativeText(updated).isEmpty) {
      throw leaveApprovalInvalid;
    }
    return LeaveApprovalResult(updated);
  }
}

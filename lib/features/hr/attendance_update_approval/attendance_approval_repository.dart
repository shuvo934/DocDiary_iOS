import '../../../core/failure.dart';
import '../../../core/native_json.dart';
import '../../../core/transport.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../hr_dashboard_repository.dart';
import 'attendance_approval_models.dart';

class AttendanceApprovalRepository {
  AttendanceApprovalRepository(this.transport, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Transport transport;
  final DateTime Function() now;

  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() current,
  ) {
    HrDashboardRepository(transport, now: now).guard(session, profile, current);
    if (profile.value('usr_name').trim().isEmpty) {
      throw attendanceApprovalInvalid;
    }
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
    if (count == null || count < 0) throw attendanceApprovalInvalid;
    if (count == 0) return [];
    final rows = nativeItems(response);
    if (rows.isEmpty) throw attendanceApprovalInvalid;
    return rows;
  }

  Future<List<AttendanceApprovalRequest>> pending(
    AuthSession session,
    AccountProfile profile, {
    required bool Function() isCurrent,
  }) async {
    final rows = await _rows(session, profile, 'getAttUpReqList', {
      'p_usr_name': profile.value('usr_name'),
    }, isCurrent);
    final result = rows.map(AttendanceApprovalRequest.fromJson).toList();
    if (result.map((r) => r.id).toSet().length != result.length ||
        result.map((r) => r.code).toSet().length != result.length) {
      throw attendanceApprovalInvalid;
    }
    return List.unmodifiable(result);
  }

  Future<AttendanceApprovalDetail?> detail(
    AuthSession session,
    AccountProfile profile,
    AttendanceApprovalRequest request, {
    required bool Function() isCurrent,
  }) async {
    final rows = await _rows(session, profile, 'getAttUpdateData', {
      'p_darm_app_code': request.code,
      'p_usr_name': profile.value('usr_name'),
    }, isCurrent);
    // Native overwrites these values per row, leaving the final row displayed.
    final details = rows.map(AttendanceApprovalDetail.new).toList();
    return details.isEmpty ? null : details.last;
  }

  /// Native POSTs carry parameters as headers, with no JSON or form body.
  /// A single explicit confirmation issues at most one POST. Retry is a read
  /// of pending requests first, never an automatic replay of an uncertain write.
  Future<AttendanceApprovalResult> submit(
    AuthSession session,
    AccountProfile profile,
    AttendanceApprovalRequest request,
    AttendanceApprovalDetail detail,
    AttendanceApprovalAction action,
    String comment, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    if (action == AttendanceApprovalAction.reject && comment.trim().isEmpty) {
      throw const AppFailure(
        'Please mention reason for reject',
        kind: FailureKind.invalidData,
      );
    }
    // Dart's HTTP implementation accepts ASCII header values. Do not silently
    // corrupt Bangla text or invent an encoding unsupported by this native API.
    if (comment.codeUnits.any((unit) => unit < 32 || unit > 126)) {
      throw const AppFailure(
        'This server sends comments as HTTP headers. Please use a single line of English text.',
        kind: FailureKind.invalidData,
      );
    }
    final headers = {
      'P_DARM_ID': request.id,
      'P_USR_NAME': profile.value('usr_name'),
      if (action == AttendanceApprovalAction.approve) ...{
        'P_DARM_EMP_ID': request.employeeId,
        'P_UPDATE_DATE': detail.updateDate,
      },
      'P_TEXT_COMMENTS': comment,
    };
    if (request.id.trim().isEmpty ||
        request.employeeId.trim().isEmpty ||
        action == AttendanceApprovalAction.approve &&
            detail.updateDate.trim().isEmpty ||
        headers.values.any((v) => v.contains(RegExp(r'[\x00-\x1f\x7f]')))) {
      throw const AppFailure(
        'Request details or comments contain invalid values. Use a single line for comments.',
        kind: FailureKind.invalidData,
      );
    }
    // A request another approver has already handled must not be submitted.
    final rows = await pending(session, profile, isCurrent: isCurrent);
    if (!rows.any(request.sameRequest)) {
      throw const AttendanceRequestNoLongerPending();
    }
    guard(session, profile, isCurrent);
    final response = await transport.post(
      apiEndpoint(session.center.baseUri, 'hrm_dashboard/${action.endpoint}'),
      headers: headers,
    );
    guard(session, profile, isCurrent);
    final status = nativeText(response['string_out']);
    if (status != 'Successfully Created') {
      throw AppFailure(
        status.isEmpty ? 'The server did not confirm this request.' : status,
      );
    }
    final updated = response['updated_req'];
    if (updated == null || updated is! String || nativeText(updated).isEmpty) {
      throw attendanceApprovalInvalid;
    }
    return AttendanceApprovalResult(updated);
  }
}

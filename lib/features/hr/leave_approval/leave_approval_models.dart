import '../../../core/failure.dart';
import '../../../core/native_json.dart';

const leaveApprovalInvalid = AppFailure(
  'The server returned incomplete leave request data.',
  kind: FailureKind.invalidData,
);

String _field(JsonMap row, String key, [String fallback = '']) {
  if (!row.containsKey(key) ||
      row[key] is Map ||
      row[key] is List ||
      row[key] is bool) {
    throw AppFailure(
      'The server returned an invalid "$key" field for Leave Approval.',
      kind: FailureKind.invalidData,
    );
  }
  return nativeText(row[key], fallback);
}

/// Keep the selected row, so filtering never changes the submitted ID.
class LeaveApprovalRequest {
  const LeaveApprovalRequest({
    required this.code,
    required this.id,
    required this.employeeId,
    this.employeeName = '',
    this.employeeCode = '',
    this.applicationDate = '',
    this.leaveDays = '',
  });
  factory LeaveApprovalRequest.fromJson(JsonMap row) {
    final value = LeaveApprovalRequest(
      code: _field(row, 'la_app_code'),
      id: _field(row, 'la_id'),
      employeeId: _field(row, 'la_emp_id'),
      employeeName: _field(row, 'emp_name'),
      employeeCode: _field(row, 'emp_code'),
      applicationDate: _field(row, 'la_date'),
      leaveDays: _field(row, 'la_leave_days'),
    );
    if (!value.valid) throw leaveApprovalInvalid;
    return value;
  }
  final String code,
      id,
      employeeId,
      employeeName,
      employeeCode,
      applicationDate,
      leaveDays;
  bool get valid =>
      code.trim().isNotEmpty &&
      id.trim().isNotEmpty &&
      employeeId.trim().isNotEmpty;
  bool matches(String query) {
    final search = query.toLowerCase();
    return code.toLowerCase().contains(search) ||
        employeeName.toLowerCase().contains(search);
  }

  bool sameRequest(LeaveApprovalRequest other) =>
      code == other.code && id == other.id && employeeId == other.employeeId;
  List<String> get cells => [
    code,
    employeeName,
    employeeCode,
    applicationDate,
    leaveDays,
  ];
}

/// Native Leave Record passes these three identifiers with FLAG=1.
class LeaveApprovalSeed {
  const LeaveApprovalSeed({
    required this.id,
    required this.code,
    required this.employeeId,
  });
  factory LeaveApprovalSeed.fromExtras(Map<String, String> extras) =>
      LeaveApprovalSeed(
        id: extras['LA_ID'] ?? '',
        code: extras['LA_APP_CODE'] ?? '',
        employeeId: extras['LA_EMP_ID'] ?? '',
      );
  final String id, code, employeeId;
  LeaveApprovalRequest get request =>
      LeaveApprovalRequest(id: id, code: code, employeeId: employeeId);
}

class LeaveApprovalDetail {
  LeaveApprovalDetail(JsonMap row)
    : values = Map.unmodifiable({
        for (final key in keys)
          key: _field(
            row,
            key,
            key == 'la_leave_days' || key == 'leave_balance' ? '0' : '',
          ),
      }) {
    _number('leave_balance');
    if (_number('la_leave_days') < 0) throw leaveApprovalInvalid;
  }
  static const keys = [
    'emp_code',
    'emp_name',
    'la_calling_title',
    'la_date',
    'la_lc_id',
    'leave_type',
    'la_from_date',
    'la_to_date',
    'la_leave_days',
    'leave_balance',
    'la_reason',
    'lc_short_code',
  ];
  final Map<String, String> values;
  String value(String key) => values[key] ?? '';
  num _number(String key) {
    final result = num.tryParse(value(key).trim());
    if (result == null || !result.isFinite) {
      throw AppFailure(
        'The server returned an invalid "$key" number for Leave Approval.',
        kind: FailureKind.invalidData,
      );
    }
    return result;
  }

  bool get hasEnoughBalance =>
      _number('leave_balance') >= _number('la_leave_days');
  bool get isSickLeave => value('lc_short_code') == 'SL';
}

enum LeaveApprovalAction {
  approve('Approve', 'approveLeave', 'Approved'),
  reject('Reject', 'rejectLeave', 'Rejected');

  const LeaveApprovalAction(this.label, this.endpoint, this.pastTense);
  final String label, endpoint, pastTense;
  String get successMessage => 'Leave $pastTense Successfully';
}

class LeaveApprovalResult {
  const LeaveApprovalResult(this.message);
  final String message;
  bool get succeeded => message.toLowerCase() == 'ok';
}

class LeaveRequestNoLongerPending implements Exception {
  const LeaveRequestNoLongerPending();
}

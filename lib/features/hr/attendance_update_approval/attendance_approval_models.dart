import '../../../core/failure.dart';
import '../../../core/native_json.dart';

const attendanceApprovalInvalid = AppFailure(
  'The server returned incomplete attendance request data.',
  kind: FailureKind.invalidData,
);

String _field(JsonMap row, String key) {
  if (!row.containsKey(key) ||
      row[key] is Map ||
      row[key] is List ||
      row[key] is bool) {
    throw attendanceApprovalInvalid;
  }
  return nativeText(row[key]);
}

/// Keep the selected row itself; filtering must never change the ID submitted.
class AttendanceApprovalRequest {
  const AttendanceApprovalRequest({
    required this.code,
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeCode,
    required this.applicationDate,
    required this.updateDate,
  });
  factory AttendanceApprovalRequest.fromJson(JsonMap row) {
    final value = AttendanceApprovalRequest(
      code: _field(row, 'darm_app_code'),
      id: _field(row, 'darm_id'),
      employeeId: _field(row, 'darm_emp_id'),
      employeeName: _field(row, 'emp_name'),
      employeeCode: _field(row, 'emp_code'),
      applicationDate: _field(row, 'darm_date'),
      updateDate: _field(row, 'darm_update_date'),
    );
    if (value.code.trim().isEmpty ||
        value.id.trim().isEmpty ||
        value.employeeId.trim().isEmpty) {
      throw attendanceApprovalInvalid;
    }
    return value;
  }
  final String code,
      id,
      employeeId,
      employeeName,
      employeeCode,
      applicationDate,
      updateDate;
  bool matches(String query) {
    final search = query.toLowerCase();
    return code.toLowerCase().contains(search) ||
        employeeName.toLowerCase().contains(search);
  }

  bool sameRequest(AttendanceApprovalRequest other) =>
      code == other.code && id == other.id && employeeId == other.employeeId;
  List<String> get cells => [
    code,
    employeeName,
    employeeCode,
    applicationDate,
    updateDate,
  ];
}

class AttendanceApprovalDetail {
  AttendanceApprovalDetail(JsonMap row)
    : values = Map.unmodifiable({
        for (final key in keys) key: _field(row, key),
      });
  static const keys = [
    'emp_code',
    'emp_name',
    'job_calling_title',
    'darm_date',
    'darm_req_type',
    'shift',
    'darm_update_date',
    'arrival_time',
    'departure_time',
    'reason',
    'darm_reason',
    'mac_in_time',
    'mac_out_time',
    'current_shift',
    'dard_recommendation',
    'forwarder_name',
  ];
  final Map<String, String> values;
  String value(String key) => values[key] ?? '';
  String get updateDate => value('darm_update_date');
  bool get hasIn => value('arrival_time').isNotEmpty;
  bool get hasOut => value('departure_time').isNotEmpty;
  bool get hasForwarder => value('forwarder_name').isNotEmpty;
}

enum AttendanceApprovalAction {
  approve('Approve', 'approveAttUpReq', 'Approved'),
  reject('Reject', 'rejectAttUpReq', 'Rejected');

  const AttendanceApprovalAction(this.label, this.endpoint, this.pastTense);
  final String label, endpoint, pastTense;
  String get successMessage => 'Attendance Update $pastTense Successfully';
}

class AttendanceApprovalResult {
  const AttendanceApprovalResult(this.message);
  final String message;
  bool get succeeded => message.toLowerCase() == 'ok';
}

class AttendanceRequestNoLongerPending implements Exception {
  const AttendanceRequestNoLongerPending();
}

import '../../../core/failure.dart';
import '../../../core/native_json.dart';
import '../../../core/transport.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../hr_dashboard_repository.dart';
import 'leave_record_models.dart';

class LeaveRecordRepository {
  LeaveRecordRepository(this.transport, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Transport transport;
  final DateTime Function() now;
  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() current,
  ) => HrDashboardRepository(
    transport,
    now: now,
  ).guard(session, profile, current);
  Future<List<JsonMap>> _rows(
    AuthSession session,
    AccountProfile profile,
    String endpoint,
    Map<String, String> query,
    bool Function() current,
  ) async {
    guard(session, profile, current);
    final result = await transport.get(
      apiEndpoint(
        session.center.baseUri,
        'hrm_dashboard/$endpoint',
        query.isEmpty ? null : query,
      ),
    );
    guard(session, profile, current);
    final count = int.tryParse(nativeText(result['count']).trim());
    if (count == null || count < 0) {
      throw leaveRecordInvalid('$endpoint: missing or invalid "count".');
    }
    if (count == 0) return [];
    final List<JsonMap> rows;
    try {
      rows = nativeItems(result);
    } on AppFailure catch (failure) {
      throw AppFailure('$endpoint: ${failure.message}', kind: failure.kind);
    }
    if (rows.isEmpty) {
      throw leaveRecordInvalid(
        '$endpoint: positive "count" with empty "items".',
      );
    }
    return rows;
  }

  List<LeaveRecordChoice> _choices(List<JsonMap> rows, String kind) {
    // Native keeps every returned row; repeated IDs are not a parse failure.
    try {
      return rows.map((row) => LeaveRecordChoice.fromJson(row, kind)).toList();
    } on AppFailure catch (failure) {
      throw AppFailure('$kind list: ${failure.message}', kind: failure.kind);
    }
  }

  Future<List<LeaveRecordRow>> records(
    AuthSession session,
    AccountProfile profile,
    LeaveRecordMonth month, {
    String branch = '',
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    if (!month.isAllowed(now())) {
      throw const AppFailure(
        'Choose a month within the leave record calendar.',
        kind: FailureKind.invalidData,
      );
    }
    final id = branch == '30' ? '' : branch;
    return (await _rows(
      session,
      profile,
      id.isEmpty ? 'getLeaveRecord' : 'getLeaveRecordWithCoa',
      {...month.query, if (id.isNotEmpty) 'p_coa_id': id},
      isCurrent,
    )).map(LeaveRecordRow.new).toList();
  }

  Future<LeaveRecordData> load(
    AuthSession session,
    AccountProfile profile,
    LeaveRecordMonth month, {
    LeaveRecordChoice branch = LeaveRecordChoice.none,
    List<LeaveRecordChoice> branches = const [],
    bool reloadBranches = false,
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    if (!month.isAllowed(now())) {
      throw const AppFailure(
        'Choose a month within the leave record calendar.',
        kind: FailureKind.invalidData,
      );
    }
    final id = branch.id == '30' ? '' : branch.id;
    var available = branches;
    if (id.isEmpty || reloadBranches) {
      final choices = _choices(
        await _rows(session, profile, 'getBranches', {}, isCurrent),
        'branch',
      );
      available = [if (choices.isNotEmpty) LeaveRecordChoice.none, ...choices];
    }
    if (id.isNotEmpty && !available.any((c) => c.id == id)) {
      throw leaveRecordInvalid('The selected branch is no longer available.');
    }
    final query = {if (id.isNotEmpty) 'p_coa_id': id};
    final divisions = _choices(
      await _rows(
        session,
        profile,
        id.isEmpty ? 'getDivision' : 'getDivisionWithCoa',
        query,
        isCurrent,
      ),
      'division',
    );
    final departments = _choices(
      await _rows(
        session,
        profile,
        id.isEmpty ? 'getDepartment' : 'getDepartmentWithCoa',
        query,
        isCurrent,
      ),
      'department',
    );
    final employees = _choices(
      await _rows(
        session,
        profile,
        id.isEmpty ? 'getEmployee' : 'getEmployeeWithCoa',
        query,
        isCurrent,
      ),
      'employee',
    );
    final rows = await records(
      session,
      profile,
      month,
      branch: id,
      isCurrent: isCurrent,
    );
    return LeaveRecordData(
      branches: available,
      branch:
          id.isEmpty
              ? LeaveRecordChoice.none
              : available.firstWhere((c) => c.id == id),
      divisions: [
        if (divisions.isNotEmpty) LeaveRecordChoice.clear,
        ...divisions,
      ],
      departments: departments,
      employees: employees,
      rows: rows,
    );
  }
}

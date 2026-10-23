import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../../core/native_json.dart';
import '../../../core/transport.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import 'daily_attendance_models.dart';
import '../hr_dashboard_repository.dart';

class DailyAttendanceRepository {
  DailyAttendanceRepository(this.transport, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Transport transport;
  final DateTime Function() now;
  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() isCurrent,
  ) => HrDashboardRepository(
    transport,
    now: now,
  ).guard(session, profile, isCurrent);

  Future<List<JsonMap>> _rows(
    AuthSession session,
    AccountProfile profile,
    String endpoint,
    Map<String, String> query,
    bool Function() isCurrent,
  ) async {
    guard(session, profile, isCurrent);
    final response = await transport.get(
      apiEndpoint(
        session.center.baseUri,
        'hrm_dashboard/$endpoint',
        query.isEmpty ? null : query,
      ),
    );
    guard(session, profile, isCurrent);
    final count = int.tryParse(nativeText(response['count']).trim());
    if (count == null || count < 0 || count > 0 && response['items'] == null) {
      throw const AppFailure(
        'The server returned incomplete Daily Attendance data.',
        kind: FailureKind.invalidData,
      );
    }
    if (count == 0) return [];
    final rows = nativeItems(response);
    if (rows.isEmpty) {
      throw const AppFailure(
        'The server returned incomplete Daily Attendance data.',
        kind: FailureKind.invalidData,
      );
    }
    return rows;
  }

  String _branch(String id) => id == '30' ? '' : id;

  Future<List<DailyAttendanceRow>> attendance(
    AuthSession session,
    AccountProfile profile,
    DateTime date,
    String branchId, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    if (!AttendanceCalendar(now()).contains(date)) {
      throw const AppFailure(
        'Choose a date within the attendance calendar.',
        kind: FailureKind.invalidData,
      );
    }
    final branch = _branch(branchId);
    return (await _rows(
      session,
      profile,
      branch.isEmpty ? 'getDailyAttendance' : 'getDailyAttendanceWithCoa',
      {'p_date': oracleDate(date), if (branch.isNotEmpty) 'p_coa_id': branch},
      isCurrent,
    )).map(DailyAttendanceRow.fromJson).toList(growable: false);
  }

  Future<DailyAttendanceData> load(
    AuthSession session,
    AccountProfile profile,
    DateTime date, {
    String branchId = '',
    List<AttendanceChoice> branches = const [],
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    final branch = _branch(branchId);
    final branchRows =
        branch.isEmpty
            ? (await _rows(
              session,
              profile,
              'getBranches',
              const {},
              isCurrent,
            )).map(AttendanceChoice.branch).toList(growable: false)
            : null;
    final suffix = branch.isEmpty ? '' : 'WithCoa';
    final query = <String, String>{if (branch.isNotEmpty) 'p_coa_id': branch};
    final divisions = (await _rows(
      session,
      profile,
      'getDivision$suffix',
      query,
      isCurrent,
    )).map(AttendanceChoice.division).toList(growable: false);
    final departments = (await _rows(
      session,
      profile,
      'getDepartment$suffix',
      query,
      isCurrent,
    )).map(AttendanceChoice.department).toList(growable: false);
    final employees = (await _rows(
      session,
      profile,
      'getEmployee$suffix',
      query,
      isCurrent,
    )).map(AttendanceEmployee.fromJson).toList(growable: false);
    final rows = await attendance(
      session,
      profile,
      date,
      branch,
      isCurrent: isCurrent,
    );
    return DailyAttendanceData(
      branches:
          branchRows == null
              ? branches
              : [
                if (branchRows.isNotEmpty) AttendanceChoice.noBranch,
                ...branchRows,
              ],
      divisions: [
        if (divisions.isNotEmpty) AttendanceChoice.clear,
        ...divisions,
      ],
      departments: departments,
      employees: employees,
      rows: rows,
    );
  }
}

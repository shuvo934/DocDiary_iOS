import '../../../core/failure.dart';
import '../../../core/native_json.dart';
import '../../../core/transport.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../hr_dashboard_models.dart';
import '../hr_dashboard_repository.dart';
import 'employee_attendance_models.dart';

/// All requests are reads of the same native hrm_dashboard endpoints.
class EmployeeAttendanceRepository {
  EmployeeAttendanceRepository(this.transport, {DateTime Function()? now})
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
      throw employeeAttendanceInvalid;
    }
    if (count == 0) return [];
    final rows = nativeItems(response);
    if (rows.isEmpty) throw employeeAttendanceInvalid;
    return rows;
  }

  String _branch(String id) => id == '30' ? '' : id;

  Future<EmployeeAttendanceCatalog> catalog(
    AuthSession session,
    AccountProfile profile, {
    EmployeeAttendanceChoice branch = EmployeeAttendanceChoice.noBranch,
    List<EmployeeAttendanceChoice> branches = const [],
    bool reloadBranches = false,
    required bool Function() isCurrent,
  }) async {
    final id = _branch(branch.id);
    var available = branches;
    if (id.isEmpty || reloadBranches) {
      final rows =
          (await _rows(
            session,
            profile,
            'getBranches',
            const {},
            isCurrent,
          )).map(EmployeeAttendanceChoice.branch).toList();
      available = [
        if (rows.isNotEmpty) EmployeeAttendanceChoice.noBranch,
        ...rows,
      ];
    }
    if (id.isNotEmpty && !available.any((choice) => choice.id == id)) {
      throw employeeAttendanceInvalid;
    }
    final divisions =
        (await _rows(
          session,
          profile,
          id.isEmpty ? 'getDivision' : 'getDivisionWithCoa',
          {if (id.isNotEmpty) 'p_coa_id': id},
          isCurrent,
        )).map(EmployeeAttendanceChoice.division).toList();
    return EmployeeAttendanceCatalog(
      branches: available,
      divisions: divisions,
      branch:
          id.isEmpty
              ? EmployeeAttendanceChoice.noBranch
              : available.firstWhere((choice) => choice.id == id),
    );
  }

  Future<List<EmployeeAttendanceChoice>> departments(
    AuthSession session,
    AccountProfile profile,
    String division,
    String branch, {
    required bool Function() isCurrent,
  }) async {
    final id = _branch(branch);
    return (await _rows(
      session,
      profile,
      id.isEmpty ? 'getDepartmentByDiv' : 'getDepartmentByDivCoa',
      {'p_div_id': division, if (id.isNotEmpty) 'p_coa_id': id},
      isCurrent,
    )).map(EmployeeAttendanceChoice.department).toList();
  }

  Future<List<EmployeeAttendanceChoice>> designations(
    AuthSession session,
    AccountProfile profile,
    String division,
    String department,
    String branch, {
    required bool Function() isCurrent,
  }) async {
    final id = _branch(branch);
    return (await _rows(
      session,
      profile,
      id.isEmpty ? 'getDesignationsByDept' : 'getDesignationsByDeptCoa',
      {
        'p_dep_Id': department,
        'p_div_id': division,
        if (id.isNotEmpty) 'p_coa_id': id,
      },
      isCurrent,
    )).map(EmployeeAttendanceChoice.designation).toList();
  }

  Future<List<EmployeeAttendanceEmployee>> employees(
    AuthSession session,
    AccountProfile profile,
    String division,
    String department,
    String designation,
    String branch, {
    required bool Function() isCurrent,
  }) async {
    final id = _branch(branch);
    return (await _rows(
      session,
      profile,
      id.isEmpty ? 'getEmployeeByDesig' : 'getEmployeeByDesigCoa',
      {
        'p_dep_id': department,
        'p_div_id': division,
        'p_desig_id': designation,
        if (id.isNotEmpty) 'p_coa_id': id,
      },
      isCurrent,
    )).map(EmployeeAttendanceEmployee.fromJson).toList();
  }

  Future<EmployeeAttendanceReport> attendance(
    AuthSession session,
    AccountProfile profile,
    String employee,
    EmployeeAttendanceMonth month, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    if (employee.isEmpty || !month.isAllowed(now())) {
      throw const AppFailure(
        'Choose an employee and a month within the attendance calendar.',
        kind: FailureKind.invalidData,
      );
    }
    final counts = await _rows(session, profile, 'getAttendanceCountEmp', {
      ...month.query,
      'p_emp_id': employee,
    }, isCurrent);
    // Native aggregates use the final row. Earlier malformed rows still fail parsing.
    var chart = HrAttendance.fromJson({
      for (final key in HrAttendance.keys) key: '0',
    });
    for (final row in counts) {
      chart = HrAttendance.fromJson(row);
    }
    final rows =
        (await _rows(session, profile, 'getAttReportData', {
          ...month.query,
          'emp_id': employee,
        }, isCurrent)).map(EmployeeAttendanceRow.fromJson).toList();
    final status = await _rows(session, profile, 'getAttStatus', {
      ...month.query,
      'emp_id': employee,
    }, isCurrent);
    for (final row in status) {
      for (final key in EmployeeAttendanceSummary.keys) {
        employeeAttendanceField(row, key, '0');
      }
    }
    final working = await _rows(
      session,
      profile,
      'getAttWorkingDays',
      month.query,
      isCurrent,
    );
    for (final row in working) {
      employeeAttendanceField(row, 'work_days', '0');
    }
    return EmployeeAttendanceReport(
      month: month,
      chart: chart,
      rows: rows,
      summary: EmployeeAttendanceSummary.fromRows(status, working),
    );
  }

  /// Daily Attendance intent: branches -> four filter levels -> four report reads.
  Future<EmployeeAttendanceSnapshot> load(
    AuthSession session,
    AccountProfile profile,
    EmployeeAttendanceSeed seed,
    EmployeeAttendanceMonth month, {
    required bool Function() isCurrent,
  }) async {
    if (!seed.complete) {
      return EmployeeAttendanceSnapshot(
        await catalog(session, profile, isCurrent: isCurrent),
        null,
      );
    }
    var data = await catalog(
      session,
      profile,
      branch: EmployeeAttendanceChoice(_branch(seed.branch), ''),
      reloadBranches: true,
      isCurrent: isCurrent,
    );
    T match<T extends EmployeeAttendanceChoice>(List<T> choices, String id) {
      final value = choices.where((choice) => choice.id == id).firstOrNull;
      if (value == null) throw employeeAttendanceInvalid;
      return value;
    }

    final div = match(data.divisions, seed.division);
    data = data.withDivision(
      div,
      await departments(
        session,
        profile,
        div.id,
        data.branch.id,
        isCurrent: isCurrent,
      ),
    );
    final dep = match(data.departments, seed.department);
    data = data.withDepartment(
      dep,
      await designations(
        session,
        profile,
        div.id,
        dep.id,
        data.branch.id,
        isCurrent: isCurrent,
      ),
    );
    final desig = match(data.designations, seed.designation);
    data = data.withDesignation(
      desig,
      await employees(
        session,
        profile,
        div.id,
        dep.id,
        desig.id,
        data.branch.id,
        isCurrent: isCurrent,
      ),
    );
    final employee = match(data.employees, seed.employee);
    if (employee.divisionId != div.id ||
        employee.departmentId != dep.id ||
        employee.designationId != desig.id) {
      throw employeeAttendanceInvalid;
    }
    data = data.withEmployee(employee);
    return EmployeeAttendanceSnapshot(
      data,
      await attendance(
        session,
        profile,
        employee.id,
        month,
        isCurrent: isCurrent,
      ),
    );
  }

  /// Revalidate catalogues on foreground return without guessing a replacement employee.
  Future<EmployeeAttendanceSnapshot> restore(
    AuthSession session,
    AccountProfile profile,
    EmployeeAttendanceCatalog previous,
    EmployeeAttendanceMonth month, {
    required bool Function() isCurrent,
  }) async {
    var data = await catalog(
      session,
      profile,
      branch: previous.branch,
      reloadBranches: true,
      isCurrent: isCurrent,
    );
    EmployeeAttendanceChoice? match(
      List<EmployeeAttendanceChoice> choices,
      EmployeeAttendanceChoice? old,
    ) =>
        old == null
            ? null
            : choices.where((choice) => choice.id == old.id).firstOrNull;
    final div = match(data.divisions, previous.division);
    if (div == null) return EmployeeAttendanceSnapshot(data, null);
    data = data.withDivision(
      div,
      await departments(
        session,
        profile,
        div.id,
        data.branch.id,
        isCurrent: isCurrent,
      ),
    );
    final dep = match(data.departments, previous.department);
    if (dep == null) return EmployeeAttendanceSnapshot(data, null);
    data = data.withDepartment(
      dep,
      await designations(
        session,
        profile,
        div.id,
        dep.id,
        data.branch.id,
        isCurrent: isCurrent,
      ),
    );
    final desig = match(data.designations, previous.designation);
    if (desig == null) return EmployeeAttendanceSnapshot(data, null);
    data = data.withDesignation(
      desig,
      await employees(
        session,
        profile,
        div.id,
        dep.id,
        desig.id,
        data.branch.id,
        isCurrent: isCurrent,
      ),
    );
    final emp =
        data.employees
            .where((choice) => choice.id == previous.employee?.id)
            .firstOrNull;
    if (emp == null) return EmployeeAttendanceSnapshot(data, null);
    if (emp.divisionId != div.id ||
        emp.departmentId != dep.id ||
        emp.designationId != desig.id) {
      throw employeeAttendanceInvalid;
    }
    return EmployeeAttendanceSnapshot(
      data.withEmployee(emp),
      await attendance(session, profile, emp.id, month, isCurrent: isCurrent),
    );
  }
}

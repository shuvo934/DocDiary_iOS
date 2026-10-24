import '../../../core/failure.dart';
import '../../../core/native_json.dart';
import '../../../core/transport.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../hr_dashboard_repository.dart';
import 'leave_balance_models.dart';

/// All requests are reads of the same native hrm_dashboard endpoints.
class LeaveBalanceRepository {
  LeaveBalanceRepository(this.transport, {DateTime Function()? now})
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
      throw AppFailure(
        'Leave Balance: $endpoint has invalid count/items.',
        kind: FailureKind.invalidData,
      );
    }
    if (count == 0) return [];
    final rows = nativeItems(response);
    if (rows.isEmpty) {
      throw AppFailure(
        'Leave Balance: $endpoint has a positive count with empty items.',
        kind: FailureKind.invalidData,
      );
    }
    return rows;
  }

  String _branch(String id) => id == '30' ? '' : id;

  Future<LeaveBalanceCatalog> catalog(
    AuthSession session,
    AccountProfile profile, {
    LeaveBalanceChoice branch = LeaveBalanceChoice.noBranch,
    List<LeaveBalanceChoice> branches = const [],
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
          )).map(LeaveBalanceChoice.branch).toList();
      available = [if (rows.isNotEmpty) LeaveBalanceChoice.noBranch, ...rows];
    }
    final divisions =
        (await _rows(
          session,
          profile,
          id.isEmpty ? 'getDivision' : 'getDivisionWithCoa',
          {if (id.isNotEmpty) 'p_coa_id': id},
          isCurrent,
        )).map(LeaveBalanceChoice.division).toList();
    return LeaveBalanceCatalog(
      branches: available,
      divisions: divisions,
      branch:
          id.isEmpty
              ? LeaveBalanceChoice.noBranch
              : available.where((choice) => choice.id == id).firstOrNull ??
                  LeaveBalanceChoice(id, ''),
    );
  }

  Future<List<LeaveBalanceChoice>> departments(
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
    )).map(LeaveBalanceChoice.department).toList();
  }

  Future<List<LeaveBalanceChoice>> designations(
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
    )).map(LeaveBalanceChoice.designation).toList();
  }

  Future<List<LeaveBalanceEmployee>> employees(
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
    )).map(LeaveBalanceEmployee.fromJson).toList();
  }

  Future<LeaveBalanceReport> report(
    AuthSession session,
    AccountProfile profile,
    String employee,
    LeaveBalanceYear year, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    if (employee.isEmpty || year.year < 1 || year.year > 9999) {
      throw leaveBalanceInvalid;
    }
    final query = {'now_date': year.lastDate, 'p_emp_id': employee};
    final rows =
        (await _rows(
          session,
          profile,
          'getLeaveBalance',
          query,
          isCurrent,
        )).map(LeaveBalanceRow.new).toList();
    final chart = <LeaveBalanceChartRow>[];
    for (final row in await _rows(
      session,
      profile,
      'getLeaveChartData',
      query,
      isCurrent,
    )) {
      final value = LeaveBalanceChartRow.fromJson(row);
      if (value != null) chart.add(value);
    }
    return LeaveBalanceReport(year: year, rows: rows, chart: chart);
  }

  /// Historical Leave Record entry: native still uses IDs no longer in menus.
  Future<LeaveBalanceSnapshot> load(
    AuthSession session,
    AccountProfile profile,
    LeaveBalanceSeed seed,
    LeaveBalanceYear year, {
    required bool Function() isCurrent,
  }) async {
    if (!seed.complete) {
      return LeaveBalanceSnapshot(
        await catalog(session, profile, isCurrent: isCurrent),
        null,
      );
    }
    var data = await catalog(
      session,
      profile,
      branch: LeaveBalanceChoice(_branch(seed.branch), ''),
      reloadBranches: true,
      isCurrent: isCurrent,
    );
    LeaveBalanceChoice match(List<LeaveBalanceChoice> choices, String id) =>
        choices.where((c) => c.id == id).firstOrNull ??
        LeaveBalanceChoice(id, '');
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
    final emp =
        data.employees.where((c) => c.id == seed.employee).firstOrNull ??
        LeaveBalanceEmployee(
          id: seed.employee,
          name: '',
          code: '',
          title: '',
          branchName: '',
          divisionId: div.id,
          departmentId: dep.id,
          designationId: desig.id,
        );
    return LeaveBalanceSnapshot(
      data.withEmployee(emp),
      await report(session, profile, emp.id, year, isCurrent: isCurrent),
    );
  }

  Future<LeaveBalanceSnapshot> restore(
    AuthSession session,
    AccountProfile profile,
    LeaveBalanceCatalog previous,
    LeaveBalanceYear year, {
    required bool Function() isCurrent,
  }) async {
    var data = await catalog(
      session,
      profile,
      branch: previous.branch,
      reloadBranches: true,
      isCurrent: isCurrent,
    );
    LeaveBalanceChoice? match(
      List<LeaveBalanceChoice> choices,
      LeaveBalanceChoice? old,
    ) => old == null ? null : choices.where((c) => c.id == old.id).firstOrNull;
    final div = match(data.divisions, previous.division);
    if (div == null) return LeaveBalanceSnapshot(data, null);
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
    if (dep == null) return LeaveBalanceSnapshot(data, null);
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
    if (desig == null) return LeaveBalanceSnapshot(data, null);
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
        data.employees.where((c) => c.id == previous.employee?.id).firstOrNull;
    if (emp == null) return LeaveBalanceSnapshot(data, null);
    return LeaveBalanceSnapshot(
      data.withEmployee(emp),
      await report(session, profile, emp.id, year, isCurrent: isCurrent),
    );
  }
}

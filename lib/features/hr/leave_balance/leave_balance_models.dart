import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../../core/native_json.dart';

const leaveBalanceInvalid = AppFailure(
  'The server returned incomplete Leave Balance data.',
  kind: FailureKind.invalidData,
);

String leaveBalanceField(JsonMap row, String key, [String fallback = '']) {
  if (!row.containsKey(key) || row[key] is Map || row[key] is List) {
    throw AppFailure(
      'Leave Balance: missing or invalid field "$key".',
      kind: FailureKind.invalidData,
    );
  }
  return nativeText(row[key], fallback);
}

class LeaveBalanceChoice {
  const LeaveBalanceChoice(this.id, this.name);
  final String id, name;
  static const noBranch = LeaveBalanceChoice('', 'None');
  factory LeaveBalanceChoice.branch(JsonMap row) => LeaveBalanceChoice(
    leaveBalanceField(row, 'coa_id'),
    leaveBalanceField(row, 'coa_name'),
  );
  factory LeaveBalanceChoice.division(JsonMap row) => LeaveBalanceChoice(
    leaveBalanceField(row, 'divm_id'),
    leaveBalanceField(row, 'divm_name'),
  );
  factory LeaveBalanceChoice.department(JsonMap row) {
    leaveBalanceField(row, 'dept_divm_id');
    return LeaveBalanceChoice(
      leaveBalanceField(row, 'dept_id'),
      leaveBalanceField(row, 'dept_name'),
    );
  }
  factory LeaveBalanceChoice.designation(JsonMap row) => LeaveBalanceChoice(
    leaveBalanceField(row, 'desig_id'),
    leaveBalanceField(row, 'desig_name'),
  );
}

class LeaveBalanceEmployee extends LeaveBalanceChoice {
  const LeaveBalanceEmployee({
    required String id,
    required String name,
    required this.code,
    required this.title,
    required this.branchName,
    required this.divisionId,
    required this.departmentId,
    required this.designationId,
  }) : super(id, name);
  final String code, title, branchName, divisionId, departmentId, designationId;
  factory LeaveBalanceEmployee.fromJson(JsonMap row) => LeaveBalanceEmployee(
    id: leaveBalanceField(row, 'emp_id'),
    name: leaveBalanceField(row, 'emp_name'),
    code: leaveBalanceField(row, 'emp_code'),
    title: leaveBalanceField(row, 'job_calling_title'),
    branchName: leaveBalanceField(row, 'coa_name'),
    divisionId: leaveBalanceField(row, 'jsm_divm_id'),
    departmentId: leaveBalanceField(row, 'jsm_dept_id'),
    designationId: leaveBalanceField(row, 'jsm_desig_id'),
  );
}

class LeaveBalanceSeed {
  const LeaveBalanceSeed({
    this.branch = '',
    this.division = '',
    this.department = '',
    this.designation = '',
    this.employee = '',
    this.lastDate = '',
  });
  factory LeaveBalanceSeed.fromExtras(Map<String, String> extras) =>
      LeaveBalanceSeed(
        branch: extras['COA_ID'] == '30' ? '' : extras['COA_ID'] ?? '',
        division: extras['DIV_ID'] ?? '',
        department: extras['DEPT_ID'] ?? '',
        designation: extras['DESIG_ID'] ?? '',
        employee: extras['EMP_ID'] ?? '',
        lastDate: extras['LAST_DATE'] ?? '',
      );
  final String branch, division, department, designation, employee, lastDate;
  bool get complete => [
    division,
    department,
    designation,
    employee,
  ].every((id) => id.isNotEmpty);
}

/// Native always asks for 31-DEC of the selected year, including current year.
class LeaveBalanceYear {
  const LeaveBalanceYear(this.year);
  final int year;
  String get label => 'YEAR: $year';
  String get lastDate => oracleDate(DateTime(year, 12, 31));
  bool isAllowed(DateTime now) => year >= now.year - 10 && year <= now.year;
  static LeaveBalanceYear initial(LeaveBalanceSeed seed, DateTime now) {
    if (seed.complete && seed.lastDate.isNotEmpty) {
      try {
        return LeaveBalanceYear(parseOracleDate(seed.lastDate).year);
      } on AppFailure {
        // The native initial screen falls back to the current year.
      }
    }
    return LeaveBalanceYear(now.year);
  }
}

class LeaveBalanceRow {
  LeaveBalanceRow(JsonMap row)
    : values = List.unmodifiable([
        '${leaveBalanceField(row, 'lc_name')}(${leaveBalanceField(row, 'lc_short_code')})',
        for (final key in quantityKeys) leaveBalanceField(row, key, '0'),
      ]);
  static const quantityKeys = [
    'lbd_opening_qty',
    'lbd_current_qty',
    'lbd_taken_qty',
    'lbd_transfer_qty',
    'lbd_cash_taken_qty',
    'lbd_balance_qty',
  ];
  final List<String> values;
}

class LeaveBalanceChartRow {
  const LeaveBalanceChartRow(
    this.code,
    this.total,
    this.consumed,
    this.balance,
  );
  final String code;
  final double total, consumed, balance;
  static LeaveBalanceChartRow? fromJson(JsonMap row) {
    final code = leaveBalanceField(row, 'lc_short_code');
    final quantity = leaveBalanceField(row, 'quantity', '0');
    final taken = leaveBalanceField(row, 'consumed', '0');
    final remaining = leaveBalanceField(row, 'balance', '0');
    if (quantity == '0') return null;
    double number(String text, String key) {
      final value = double.tryParse(text);
      if (value == null || !value.isFinite) {
        throw AppFailure(
          'Leave Balance: invalid number in "$key".',
          kind: FailureKind.invalidData,
        );
      }
      return value;
    }

    return LeaveBalanceChartRow(
      code,
      number(quantity, 'quantity'),
      number(taken, 'consumed'),
      number(remaining, 'balance'),
    );
  }
}

String leaveBalanceBarLabel(double value) {
  final text = value.toString();
  // Preserve the Android adapter's contains(".0") rule.
  return text.contains('.0') ? value.floor().toString() : text;
}

class LeaveBalanceReport {
  LeaveBalanceReport({
    required this.year,
    required List<LeaveBalanceRow> rows,
    required List<LeaveBalanceChartRow> chart,
  }) : rows = List.unmodifiable(rows),
       chart = List.unmodifiable(chart);
  final LeaveBalanceYear year;
  final List<LeaveBalanceRow> rows;
  final List<LeaveBalanceChartRow> chart;
}

class LeaveBalanceSnapshot {
  const LeaveBalanceSnapshot(this.catalog, this.report);
  final LeaveBalanceCatalog catalog;
  final LeaveBalanceReport? report;
}

class LeaveBalanceCatalog {
  LeaveBalanceCatalog({
    List<LeaveBalanceChoice> branches = const [],
    List<LeaveBalanceChoice> divisions = const [],
    List<LeaveBalanceChoice> departments = const [],
    List<LeaveBalanceChoice> designations = const [],
    List<LeaveBalanceEmployee> employees = const [],
    this.branch = LeaveBalanceChoice.noBranch,
    this.division,
    this.department,
    this.designation,
    this.employee,
  }) : branches = List.unmodifiable(branches),
       divisions = List.unmodifiable(divisions),
       departments = List.unmodifiable(departments),
       designations = List.unmodifiable(designations),
       employees = List.unmodifiable(employees);
  final List<LeaveBalanceChoice> branches, divisions, departments, designations;
  final List<LeaveBalanceEmployee> employees;
  final LeaveBalanceChoice branch;
  final LeaveBalanceChoice? division, department, designation;
  final LeaveBalanceEmployee? employee;
  LeaveBalanceCatalog withDivision(
    LeaveBalanceChoice value, [
    List<LeaveBalanceChoice> choices = const [],
  ]) => LeaveBalanceCatalog(
    branches: branches,
    divisions: divisions,
    branch: branch,
    division: value,
    departments: choices,
  );
  LeaveBalanceCatalog withDepartment(
    LeaveBalanceChoice value, [
    List<LeaveBalanceChoice> choices = const [],
  ]) => LeaveBalanceCatalog(
    branches: branches,
    divisions: divisions,
    departments: departments,
    branch: branch,
    division: division,
    department: value,
    designations: choices,
  );
  LeaveBalanceCatalog withDesignation(
    LeaveBalanceChoice value, [
    List<LeaveBalanceEmployee> choices = const [],
  ]) => LeaveBalanceCatalog(
    branches: branches,
    divisions: divisions,
    departments: departments,
    designations: designations,
    branch: branch,
    division: division,
    department: department,
    designation: value,
    employees: choices,
  );
  LeaveBalanceCatalog withEmployee(LeaveBalanceEmployee value) =>
      LeaveBalanceCatalog(
        branches: branches,
        divisions: divisions,
        departments: departments,
        designations: designations,
        employees: employees,
        branch: branch,
        division: division,
        department: department,
        designation: designation,
        employee: value,
      );
  LeaveBalanceSeed get seed => LeaveBalanceSeed(
    branch: branch.id,
    division: division?.id ?? '',
    department: department?.id ?? '',
    designation: designation?.id ?? '',
    employee: employee?.id ?? '',
  );
}

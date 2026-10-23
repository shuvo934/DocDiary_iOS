import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../../core/native_json.dart';
import '../../dashboard/dashboard_navigation.dart';

String _field(JsonMap row, String key) {
  final value = row[key];
  if (!row.containsKey(key) || value is Map || value is List) {
    throw const AppFailure(
      'The server returned incomplete Daily Attendance data.',
      kind: FailureKind.invalidData,
    );
  }
  return nativeText(value);
}

class AttendanceChoice {
  const AttendanceChoice(this.id, this.name, {this.divisionId = ''});
  final String id, name, divisionId;
  static const clear = AttendanceChoice('', '...');
  static const noBranch = AttendanceChoice('', 'None');

  factory AttendanceChoice.branch(JsonMap row) =>
      AttendanceChoice(_field(row, 'coa_id'), _field(row, 'coa_name'));
  factory AttendanceChoice.division(JsonMap row) =>
      AttendanceChoice(_field(row, 'divm_id'), _field(row, 'divm_name'));
  factory AttendanceChoice.department(JsonMap row) => AttendanceChoice(
    _field(row, 'dept_id'),
    _field(row, 'dept_name'),
    divisionId: _field(row, 'dept_divm_id'),
  );
}

class AttendanceEmployee {
  const AttendanceEmployee({
    required this.id,
    required this.code,
    required this.name,
    required this.divisionId,
    required this.departmentId,
    required this.designationId,
    required this.title,
  });
  factory AttendanceEmployee.fromJson(JsonMap row) => AttendanceEmployee(
    id: _field(row, 'emp_id'),
    code: _field(row, 'emp_code'),
    name: _field(row, 'emp_name'),
    divisionId: _field(row, 'jsm_divm_id'),
    departmentId: _field(row, 'jsm_dept_id'),
    designationId: _field(row, 'jsm_desig_id'),
    title: _field(row, 'job_calling_title'),
  );
  final String id, code, name, divisionId, departmentId, designationId, title;
}

class DailyAttendanceRow {
  const DailyAttendanceRow({
    required this.employee,
    required this.shift,
    required this.inTime,
    required this.outTime,
    required this.status,
    required this.lateStatus,
    required this.earlyStatus,
    required this.location,
  });
  factory DailyAttendanceRow.fromJson(JsonMap row) => DailyAttendanceRow(
    employee: AttendanceEmployee.fromJson(row),
    shift: _field(row, 'osm_name'),
    inTime: _field(row, 'in_time'),
    outTime: _field(row, 'out_time'),
    status: _field(row, 'status'),
    lateStatus: _field(row, 'late_status'),
    earlyStatus: _field(row, 'early_status'),
    location: _field(row, 'coa_name'),
  );
  final AttendanceEmployee employee;
  final String shift,
      inTime,
      outTime,
      status,
      lateStatus,
      earlyStatus,
      location;

  DashboardRoute route(String branchId) => DashboardRoute(
    DashboardModule.hrEmployeeAttendance,
    extras: {
      'DIV_ID': employee.divisionId,
      'DEPT_ID': employee.departmentId,
      'DESIG_ID': employee.designationId,
      'EMP_ID': employee.id,
      'COA_ID': branchId == '30' ? '' : branchId,
    },
  );
}

class DailyAttendanceData {
  DailyAttendanceData({
    required List<AttendanceChoice> branches,
    required List<AttendanceChoice> divisions,
    required List<AttendanceChoice> departments,
    required List<AttendanceEmployee> employees,
    required List<DailyAttendanceRow> rows,
  }) : branches = List.unmodifiable(branches),
       divisions = List.unmodifiable(divisions),
       departments = List.unmodifiable(departments),
       employees = List.unmodifiable(employees),
       rows = List.unmodifiable(rows);
  final List<AttendanceChoice> branches, divisions, departments;
  final List<AttendanceEmployee> employees;
  final List<DailyAttendanceRow> rows;

  DailyAttendanceData withRows(List<DailyAttendanceRow> value) =>
      DailyAttendanceData(
        branches: branches,
        divisions: divisions,
        departments: departments,
        employees: employees,
        rows: value,
      );
}

class AttendanceFilter {
  const AttendanceFilter({
    this.division = '',
    this.department = '',
    this.employee = '',
  });
  final String division, department, employee;
  bool get departmentEnabled => division.isNotEmpty;
  bool get employeeEnabled => departmentEnabled && department.isNotEmpty;

  bool _matches(AttendanceEmployee value) =>
      (division.isEmpty || value.divisionId == division) &&
      (department.isEmpty || value.departmentId == department);

  List<AttendanceChoice> departments(DailyAttendanceData data) =>
      departmentEnabled
          ? [
            AttendanceChoice.clear,
            ...data.departments.where((item) => item.divisionId == division),
          ]
          : [];
  List<AttendanceChoice> employees(DailyAttendanceData data) =>
      employeeEnabled
          ? [
            AttendanceChoice.clear,
            for (final item in data.employees.where(_matches))
              AttendanceChoice(item.id, item.name),
          ]
          : [];
  int employeeCount(DailyAttendanceData data) =>
      data.employees.where(_matches).length;
  List<DailyAttendanceRow> rows(DailyAttendanceData data) => data.rows
      .where(
        (row) =>
            _matches(row.employee) &&
            (employee.isEmpty || row.employee.id == employee),
      )
      .toList(growable: false);

  AttendanceFilter retainedIn(DailyAttendanceData data) {
    if (division.isEmpty ||
        !data.divisions.any((item) => item.id == division)) {
      return const AttendanceFilter();
    }
    final div = AttendanceFilter(division: division);
    if (department.isEmpty ||
        !div.departments(data).any((item) => item.id == department)) {
      return div;
    }
    final dept = AttendanceFilter(division: division, department: department);
    return dept.employees(data).any((item) => item.id == employee)
        ? AttendanceFilter(
          division: division,
          department: department,
          employee: employee,
        )
        : dept;
  }
}

/// Preserve the three Calendar.add calls that establish the native range.
class AttendanceCalendar {
  AttendanceCalendar(DateTime anchor)
    : last = dateOnly(anchor),
      first = calendarAddMonths(
        calendarAddMonths(calendarAddMonths(dateOnly(anchor), -2), 1),
        -1,
      );
  final DateTime first, last;
  int get dayCount => _distance(last, first) + 1;
  int indexOf(DateTime date) => _distance(dateOnly(date), first);
  DateTime at(int index) =>
      DateTime(first.year, first.month, first.day + index);
  bool contains(DateTime date) =>
      !dateOnly(date).isBefore(first) && !dateOnly(date).isAfter(last);
  DateTime clamp(DateTime date) =>
      date.isBefore(first)
          ? first
          : date.isAfter(last)
          ? last
          : dateOnly(date);
  DateTime moveMonth(DateTime selected, int direction) =>
      clamp(calendarAddMonths(selected, direction));
  bool canMove(DateTime selected, int direction) =>
      direction < 0
          ? selected.year != first.year || selected.month != first.month
          : selected.year != last.year || selected.month != last.month;
  static int _distance(DateTime a, DateTime b) =>
      DateTime.utc(
        a.year,
        a.month,
        a.day,
      ).difference(DateTime.utc(b.year, b.month, b.day)).inDays;
}

String attendanceMonthLabel(DateTime date) =>
    '${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][date.month - 1]}, ${date.year}';

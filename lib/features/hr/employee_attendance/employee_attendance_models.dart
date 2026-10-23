import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../../core/native_json.dart';
import '../hr_dashboard_models.dart';

const employeeAttendanceInvalid = AppFailure(
  'The server returned incomplete Emp Wise Attendance data.',
  kind: FailureKind.invalidData,
);

String employeeAttendanceField(
  JsonMap row,
  String key, [
  String fallback = '',
]) {
  if (!row.containsKey(key) || row[key] is Map || row[key] is List) {
    throw employeeAttendanceInvalid;
  }
  return nativeText(row[key], fallback);
}

class EmployeeAttendanceChoice {
  const EmployeeAttendanceChoice(this.id, this.name);
  final String id, name;
  static const noBranch = EmployeeAttendanceChoice('', 'None');
  factory EmployeeAttendanceChoice.branch(JsonMap row) =>
      EmployeeAttendanceChoice(
        employeeAttendanceField(row, 'coa_id'),
        employeeAttendanceField(row, 'coa_name'),
      );
  factory EmployeeAttendanceChoice.division(JsonMap row) =>
      EmployeeAttendanceChoice(
        employeeAttendanceField(row, 'divm_id'),
        employeeAttendanceField(row, 'divm_name'),
      );
  factory EmployeeAttendanceChoice.department(JsonMap row) {
    employeeAttendanceField(row, 'dept_divm_id');
    return EmployeeAttendanceChoice(
      employeeAttendanceField(row, 'dept_id'),
      employeeAttendanceField(row, 'dept_name'),
    );
  }
  factory EmployeeAttendanceChoice.designation(JsonMap row) =>
      EmployeeAttendanceChoice(
        employeeAttendanceField(row, 'desig_id'),
        employeeAttendanceField(row, 'desig_name'),
      );
}

class EmployeeAttendanceEmployee extends EmployeeAttendanceChoice {
  const EmployeeAttendanceEmployee({
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
  factory EmployeeAttendanceEmployee.fromJson(JsonMap row) =>
      EmployeeAttendanceEmployee(
        id: employeeAttendanceField(row, 'emp_id'),
        name: employeeAttendanceField(row, 'emp_name'),
        code: employeeAttendanceField(row, 'emp_code'),
        title: employeeAttendanceField(row, 'job_calling_title'),
        branchName: employeeAttendanceField(row, 'coa_name'),
        divisionId: employeeAttendanceField(row, 'jsm_divm_id'),
        departmentId: employeeAttendanceField(row, 'jsm_dept_id'),
        designationId: employeeAttendanceField(row, 'jsm_desig_id'),
      );
}

class EmployeeAttendanceSeed {
  const EmployeeAttendanceSeed({
    this.branch = '',
    this.division = '',
    this.department = '',
    this.designation = '',
    this.employee = '',
  });
  factory EmployeeAttendanceSeed.fromExtras(Map<String, String> extras) =>
      EmployeeAttendanceSeed(
        branch: extras['COA_ID'] == '30' ? '' : extras['COA_ID'] ?? '',
        division: extras['DIV_ID'] ?? '',
        department: extras['DEPT_ID'] ?? '',
        designation: extras['DESIG_ID'] ?? '',
        employee: extras['EMP_ID'] ?? '',
      );
  final String branch, division, department, designation, employee;
  bool get complete => [
    division,
    department,
    designation,
    employee,
  ].every((id) => id.isNotEmpty);
}

/// Current month and the previous five, unlike the HR payroll picker.
class EmployeeAttendanceMonth {
  EmployeeAttendanceMonth(DateTime date)
    : first = DateTime(date.year, date.month);
  final DateTime first;
  DateTime get last => DateTime(first.year, first.month + 1, 0);
  int get days => last.day;
  Map<String, String> get query => {
    'first_date': oracleDate(first),
    'last_date': oracleDate(last),
  };
  String get label =>
      'MONTH: ${hrMonths[first.month - 1].substring(0, 3).toUpperCase()}-${(first.year % 100).toString().padLeft(2, '0')}';
  String get rangeLabel {
    String date(DateTime value) =>
        '${value.day.toString().padLeft(2, '0')} ${hrMonths[value.month - 1].substring(0, 3).toUpperCase()}, ${value.year}';
    return '${date(first)} -- ${date(last)}';
  }

  bool isAllowed(DateTime now) {
    final distance = now.year * 12 + now.month - first.year * 12 - first.month;
    return distance >= 0 && distance <= 5;
  }

  static List<EmployeeAttendanceMonth> available(DateTime now) => [
    for (var offset = 5; offset >= 0; offset--)
      EmployeeAttendanceMonth(DateTime(now.year, now.month - offset)),
  ];
}

class EmployeeAttendanceCatalog {
  EmployeeAttendanceCatalog({
    List<EmployeeAttendanceChoice> branches = const [],
    List<EmployeeAttendanceChoice> divisions = const [],
    List<EmployeeAttendanceChoice> departments = const [],
    List<EmployeeAttendanceChoice> designations = const [],
    List<EmployeeAttendanceEmployee> employees = const [],
    this.branch = EmployeeAttendanceChoice.noBranch,
    this.division,
    this.department,
    this.designation,
    this.employee,
  }) : branches = List.unmodifiable(branches),
       divisions = List.unmodifiable(divisions),
       departments = List.unmodifiable(departments),
       designations = List.unmodifiable(designations),
       employees = List.unmodifiable(employees);
  final List<EmployeeAttendanceChoice> branches,
      divisions,
      departments,
      designations;
  final List<EmployeeAttendanceEmployee> employees;
  final EmployeeAttendanceChoice branch;
  final EmployeeAttendanceChoice? division, department, designation;
  final EmployeeAttendanceEmployee? employee;
  EmployeeAttendanceCatalog withDivision(
    EmployeeAttendanceChoice value, [
    List<EmployeeAttendanceChoice> choices = const [],
  ]) => EmployeeAttendanceCatalog(
    branches: branches,
    divisions: divisions,
    branch: branch,
    division: value,
    departments: choices,
  );
  EmployeeAttendanceCatalog withDepartment(
    EmployeeAttendanceChoice value, [
    List<EmployeeAttendanceChoice> choices = const [],
  ]) => EmployeeAttendanceCatalog(
    branches: branches,
    divisions: divisions,
    departments: departments,
    branch: branch,
    division: division,
    department: value,
    designations: choices,
  );
  EmployeeAttendanceCatalog withDesignation(
    EmployeeAttendanceChoice value, [
    List<EmployeeAttendanceEmployee> choices = const [],
  ]) => EmployeeAttendanceCatalog(
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
  EmployeeAttendanceCatalog withEmployee(EmployeeAttendanceEmployee value) =>
      EmployeeAttendanceCatalog(
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
  EmployeeAttendanceSeed get seed => EmployeeAttendanceSeed(
    branch: branch.id,
    division: division?.id ?? '',
    department: department?.id ?? '',
    designation: designation?.id ?? '',
    employee: employee?.id ?? '',
  );
}

enum EmployeeAttendanceRowKind {
  normal,
  multiStation,
  outMiss,
  leave,
  offDay,
  presentLeave,
  presentOffDay,
  absent,
}

/// Adapter normalization from EmpWiseAttendance.java, retaining raw location/coordinates.
class EmployeeAttendanceRow {
  const EmployeeAttendanceRow({
    required this.date,
    required this.status,
    required this.kind,
    required this.shift,
    required this.location,
    required this.inTime,
    required this.outTime,
    required this.late,
    required this.early,
    required this.inLatitude,
    required this.inLongitude,
    required this.outLatitude,
    required this.outLongitude,
  });
  final String date,
      status,
      shift,
      location,
      inTime,
      outTime,
      inLatitude,
      inLongitude,
      outLatitude,
      outLongitude;
  final bool late, early;
  final EmployeeAttendanceRowKind kind;
  String get statusLabel =>
      '$status${late ? '\n(Late)' : ''}${early ? '\n(Early)' : ''}';
  factory EmployeeAttendanceRow.fromJson(JsonMap row) {
    String field(String key) => employeeAttendanceField(row, key);
    final rawIn = field('dac_in_date_time'),
        rawOut = field('dac_out_date_time');
    final short = field('dac_attn_status'), leaveName = field('lc_name');
    final rawShift = field('osm_name');
    var kind = EmployeeAttendanceRowKind.normal;
    var status = 'No Status';
    if (short.isNotEmpty) {
      if (rawIn.isNotEmpty && rawOut.isEmpty) {
        status = 'Out Miss';
        kind = EmployeeAttendanceRowKind.outMiss;
      } else {
        switch (short) {
          case 'L':
          case 'LW':
          case 'LH':
            status = leaveName.isEmpty ? 'In Leave' : leaveName;
            kind = EmployeeAttendanceRowKind.leave;
          case 'H':
            status = 'Holiday';
            kind = EmployeeAttendanceRowKind.offDay;
          case 'W':
            status = 'Weekend';
            kind = EmployeeAttendanceRowKind.offDay;
          case 'PL':
          case 'PLH':
          case 'PLW':
            status = 'Present & Leave';
            kind = EmployeeAttendanceRowKind.presentLeave;
          case 'PAT':
            status = 'Attended training';
          case 'PHD':
          case 'PWD':
          case 'PLHD':
          case 'PLWD':
            status = 'Present & Day Off Taken';
          case 'P':
          case 'PWWO':
          case 'PHWC':
          case 'PWWC':
          case 'PA':
            status = 'Present';
          case 'PW':
          case 'PH':
            status = 'Present & Off Day';
            kind = EmployeeAttendanceRowKind.presentOffDay;
          case 'PT':
            status = 'Tour';
          case 'SP':
            status = 'Suspend';
          default:
            status = 'Absent';
            kind = EmployeeAttendanceRowKind.absent;
        }
      }
    }
    final inMachine = field('in_machine_coa_id'),
        outMachine = field('out_machine_coa_id');
    if (inMachine.isNotEmpty && outMachine.isNotEmpty) {
      final first = int.tryParse(inMachine), last = int.tryParse(outMachine);
      if (first == null || last == null) throw employeeAttendanceInvalid;
      if (first != last) kind = EmployeeAttendanceRowKind.multiStation;
    }
    final incoming = _time(rawIn), lateAfter = _time(field('dac_late_after'));
    final outgoing = _time(rawOut),
        earlyBefore = _time(field('dac_early_before'));
    return EmployeeAttendanceRow(
      date: field('dac_date1'),
      status: status,
      kind: kind,
      shift: leaveName.isNotEmpty || status == 'Weekend' ? '' : rawShift,
      location: field('coa_name'),
      inTime:
          incoming != null && lateAfter != null
              ? _displayTime(incoming)
              : rawIn,
      outTime:
          outgoing != null && earlyBefore != null
              ? _displayTime(outgoing)
              : rawOut,
      late: incoming != null && lateAfter != null && incoming >= lateAfter,
      early: outgoing != null && earlyBefore != null && outgoing < earlyBefore,
      inLatitude: field('dac_in_attd_latitude'),
      inLongitude: field('dac_in_attd_longitude'),
      outLatitude: field('dac_out_attd_latitude'),
      outLongitude: field('dac_out_attd_longitude'),
    );
  }
  static int? _time(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2}):(\d{2})\s+(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.parse(match[1]!),
        minute = int.parse(match[2]!),
        second = int.parse(match[3]!);
    if (hour < 1 || hour > 12 || minute > 59 || second > 59) return null;
    return (hour % 12 + (match[4]!.toUpperCase() == 'PM' ? 12 : 0)) * 3600 +
        minute * 60 +
        second;
  }

  static String _displayTime(int seconds) {
    final hour = seconds ~/ 3600;
    return '${(hour % 12 == 0 ? 12 : hour % 12).toString().padLeft(2, '0')}:${(seconds ~/ 60 % 60).toString().padLeft(2, '0')} ${hour >= 12 ? 'PM' : 'AM'}';
  }
}

class EmployeeAttendanceSummary {
  const EmployeeAttendanceSummary(this.values, this.workingDays);
  final List<String> values;
  final String workingDays;
  static const keys = [
    'present_status',
    'absent_status',
    'weekend_status',
    'present_weekend',
    'holiday_status',
    'present_holiday_status',
    'leave_status',
    'present_leave_status',
  ];
  factory EmployeeAttendanceSummary.fromRows(
    List<JsonMap> status,
    List<JsonMap> working,
  ) => EmployeeAttendanceSummary(
    List.unmodifiable([
      for (final key in keys)
        status.isEmpty ? '' : employeeAttendanceField(status.last, key, '0'),
    ]),
    working.isEmpty
        ? ''
        : employeeAttendanceField(working.last, 'work_days', '0'),
  );
}

class EmployeeAttendanceReport {
  EmployeeAttendanceReport({
    required this.month,
    required this.chart,
    required List<EmployeeAttendanceRow> rows,
    required this.summary,
  }) : rows = List.unmodifiable(rows);
  final EmployeeAttendanceMonth month;
  final HrAttendance chart;
  final List<EmployeeAttendanceRow> rows;
  final EmployeeAttendanceSummary summary;
}

class EmployeeAttendanceSnapshot {
  const EmployeeAttendanceSnapshot(this.catalog, this.report);
  final EmployeeAttendanceCatalog catalog;
  final EmployeeAttendanceReport? report;
}

import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../../core/native_json.dart';
import '../../dashboard/dashboard_navigation.dart';

AppFailure leaveRecordInvalid(String detail) => AppFailure(
  'Invalid Leave Record data: $detail',
  kind: FailureKind.invalidData,
);

String leaveRecordField(JsonMap row, String key) {
  if (!row.containsKey(key)) {
    throw leaveRecordInvalid('Missing field "$key".');
  }
  if (row[key] is Map || row[key] is List || row[key] is bool) {
    throw leaveRecordInvalid('Field "$key" must be text or a number.');
  }
  return nativeText(row[key]);
}

class LeaveRecordChoice {
  const LeaveRecordChoice(
    this.id,
    this.name, {
    this.division = '',
    this.department = '',
  });
  static const none = LeaveRecordChoice('', 'None');
  static const clear = LeaveRecordChoice('', '...');
  final String id, name, division, department;
  factory LeaveRecordChoice.fromJson(JsonMap row, String kind) {
    final keys = switch (kind) {
      'branch' => ['coa_id', 'coa_name'],
      'division' => ['divm_id', 'divm_name'],
      'department' => ['dept_id', 'dept_name'],
      _ => ['emp_id', 'emp_name'],
    };
    final id = leaveRecordField(row, keys[0]);
    if (id.isEmpty) {
      throw leaveRecordInvalid('Empty field "${keys[0]}".');
    }
    if (kind == 'employee') {
      for (final key in ['emp_code', 'jsm_desig_id', 'job_calling_title']) {
        leaveRecordField(row, key);
      }
    }
    return LeaveRecordChoice(
      id,
      leaveRecordField(row, keys[1]),
      division:
          kind == 'department'
              ? leaveRecordField(row, 'dept_divm_id')
              : kind == 'employee'
              ? leaveRecordField(row, 'jsm_divm_id')
              : '',
      department:
          kind == 'employee' ? leaveRecordField(row, 'jsm_dept_id') : '',
    );
  }
}

class LeaveRecordMonth {
  LeaveRecordMonth(DateTime date) : first = DateTime(date.year, date.month);
  final DateTime first;
  DateTime get last => DateTime(first.year, first.month + 1, 0);
  Map<String, String> get query => {
    'first_date': oracleDate(first),
    'last_date': oracleDate(last),
  };
  bool isAllowed(DateTime now) {
    final choices = available(now);
    return !first.isBefore(choices.first.first) &&
        !first.isAfter(choices.last.first);
  }

  static List<LeaveRecordMonth> available(DateTime now) {
    // Preserve Java Calendar's zero-based month and lenient last-day rollover.
    // min = current - 2; max = next month with the current month's last day.
    // E.g. 31-Nov rolls to 1-Dec, so October's native picker includes December.
    final min = DateTime(now.year, now.month - 2);
    final max = DateTime(
      now.year,
      now.month + 1,
      DateTime(now.year, now.month + 1, 0).day,
    );
    final count = (max.year - min.year) * 12 + max.month - min.month;
    return [
      for (var i = 0; i <= count; i++)
        LeaveRecordMonth(DateTime(min.year, min.month + i)),
    ];
  }
}

class LeaveRecordRow {
  LeaveRecordRow(JsonMap row)
    : values = Map.unmodifiable({
        for (final key in keys) key: leaveRecordField(row, key),
      }) {
    for (final key in ['la_id', 'emp_id']) {
      if (value(key).isEmpty) {
        throw leaveRecordInvalid('Empty field "$key".');
      }
    }
    for (final key in ['la_from_date', 'la_to_date']) {
      if (value(key).isNotEmpty) {
        _LeaveDay.parse(value(key), field: key);
      }
    }
  }
  static const keys = [
    'la_id',
    'la_app_code',
    'la_approved',
    'la_date',
    'leave_type',
    'la_from_date',
    'la_to_date',
    'la_leave_days',
    'emp_name',
    'emp_id',
    'job_calling_title',
    'jsm_divm_id',
    'jsm_dept_id',
    'jsm_desig_id',
    'coa_name',
    'coa_id',
  ];
  final Map<String, String> values;
  String value(String key) => values[key] ?? '';
  String get id => value('la_id');
  String get status => value('la_approved');
  String get statusLabel => switch (status) {
    '0' => 'PENDING',
    '1' => 'APPROVED',
    '2' => 'REJECTED',
    '3' => 'CANCEL APPROVED LEAVE',
    _ => status,
  };
  String get daysLabel {
    final days = value('la_leave_days');
    return days.isEmpty ? '' : '($days ${days == '1' ? 'Day' : 'Days'})';
  }

  String get dateLabel {
    if (value('la_from_date').isEmpty || value('la_to_date').isEmpty) return '';
    final from = _LeaveDay.parse(value('la_from_date'));
    final to = _LeaveDay.parse(value('la_to_date'));
    if (value('la_from_date') == value('la_to_date')) {
      return '${from.ordinal} ${from.month}';
    }
    if (from.month == to.month) {
      return '${from.ordinal} to ${to.ordinal} (${from.month})';
    }
    return '${from.ordinal} ${from.month} to ${to.ordinal} ${to.month}';
  }

  DashboardRoute route(LeaveRecordMonth month) =>
      status == '0'
          ? DashboardRoute(
            DashboardModule.hrLeaveApproval,
            extras: {
              'LA_ID': id,
              'LA_EMP_ID': value('emp_id'),
              'LA_APP_CODE': value('la_app_code'),
              'FLAG': '1',
            },
          )
          : DashboardRoute(
            DashboardModule.hrLeaveBalance,
            extras: {
              'COA_ID': value('coa_id'),
              'DIV_ID': value('jsm_divm_id'),
              'DEPT_ID': value('jsm_dept_id'),
              'DESIG_ID': value('jsm_desig_id'),
              'EMP_ID': value('emp_id'),
              'LAST_DATE': oracleDate(month.last),
            },
          );
}

class _LeaveDay {
  const _LeaveDay(this.day, this.month);
  static const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  final int day;
  final String month;
  factory _LeaveDay.parse(String text, {String field = 'leave date'}) {
    final match = RegExp(
      r'^(\d{1,2})[\s./-]*([A-Za-z]{3})(?:[\s./-]*(\d{2}|\d{4}))?$',
    ).firstMatch(text.trim());
    if (match == null) {
      throw leaveRecordInvalid('Invalid date format in "$field".');
    }
    final day = int.parse(match[1]!),
        month = months.indexOf(match[2]!.toUpperCase()) + 1;
    if (month == 0 || day < 1 || day > DateTime(2000, month + 1, 0).day) {
      throw leaveRecordInvalid('Invalid day or month in "$field".');
    }
    return _LeaveDay(day, months[month - 1]);
  }
  String get ordinal {
    final suffix =
        day >= 11 && day <= 13
            ? 'th'
            : switch (day % 10) {
              1 => 'st',
              2 => 'nd',
              3 => 'rd',
              _ => 'th',
            };
    return '$day$suffix';
  }
}

class LeaveRecordFilter {
  const LeaveRecordFilter({
    this.division = '',
    this.department = '',
    this.employee = '',
  });
  final String division, department, employee;
  bool get departmentEnabled => division.isNotEmpty;
  bool get employeeEnabled => division.isNotEmpty && department.isNotEmpty;
  List<LeaveRecordRow> rows(LeaveRecordData data) =>
      data.rows
          .where(
            (row) =>
                (division.isEmpty || row.value('jsm_divm_id') == division) &&
                (department.isEmpty ||
                    row.value('jsm_dept_id') == department) &&
                (employee.isEmpty || row.value('emp_id') == employee),
          )
          .toList();
  List<LeaveRecordChoice> departments(LeaveRecordData data) =>
      departmentEnabled
          ? [
            LeaveRecordChoice.clear,
            ...data.departments.where((c) => c.division == division),
          ]
          : [];
  List<LeaveRecordChoice> employees(LeaveRecordData data) =>
      employeeEnabled
          ? [
            LeaveRecordChoice.clear,
            ...data.employees.where(
              (c) => c.division == division && c.department == department,
            ),
          ]
          : [];
  LeaveRecordFilter restored(LeaveRecordData data) {
    if (!data.divisions.any((c) => c.id == division)) {
      return const LeaveRecordFilter();
    }
    final div = LeaveRecordFilter(division: division);
    if (!div.departments(data).any((c) => c.id == department)) return div;
    final dep = LeaveRecordFilter(division: division, department: department);
    return dep.employees(data).any((c) => c.id == employee)
        ? LeaveRecordFilter(
          division: division,
          department: department,
          employee: employee,
        )
        : dep;
  }
}

class LeaveRecordCounts {
  LeaveRecordCounts(List<LeaveRecordRow> rows)
    : total = rows.length,
      pending = rows.where((r) => r.status == '0').length,
      approved = rows.where((r) => r.status == '1').length,
      rejected = rows.where((r) => r.status == '2').length,
      cancelled = rows.where((r) => r.status == '3').length;
  final int total, pending, approved, rejected, cancelled;
  Map<String, int> get entries => {
    'Total Leave Application': total,
    'Pending': pending,
    'Approved': approved,
    'Rejected': rejected,
    'Cancel Approved Leave': cancelled,
  };
}

class LeaveRecordData {
  LeaveRecordData({
    required List<LeaveRecordChoice> branches,
    required List<LeaveRecordChoice> divisions,
    required List<LeaveRecordChoice> departments,
    required List<LeaveRecordChoice> employees,
    required List<LeaveRecordRow> rows,
    this.branch = LeaveRecordChoice.none,
  }) : branches = List.unmodifiable(branches),
       divisions = List.unmodifiable(divisions),
       departments = List.unmodifiable(departments),
       employees = List.unmodifiable(employees),
       rows = List.unmodifiable(rows);
  final List<LeaveRecordChoice> branches, divisions, departments, employees;
  final List<LeaveRecordRow> rows;
  final LeaveRecordChoice branch;
  LeaveRecordData withRows(List<LeaveRecordRow> next) => LeaveRecordData(
    branches: branches,
    divisions: divisions,
    departments: departments,
    employees: employees,
    rows: next,
    branch: branch,
  );
}

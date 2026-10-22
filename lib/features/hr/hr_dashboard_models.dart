import '../../core/failure.dart';
import '../../core/native_dates.dart';
import '../../core/native_json.dart';
import '../dashboard/admin_chart_models.dart';
import '../dashboard/native_dashboard_format.dart';

const hrMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

enum HrAttendancePeriod { today, lastDay, lastWeek, lastMonth }

enum HrLeavePeriod { lastWeek, thisWeek, nextWeek }

enum HrSection { full, attendance, leave, payroll }

extension HrAttendanceLabel on HrAttendancePeriod {
  String get label =>
      const ['TODAY', 'LAST DAY', 'LAST WEEK', 'LAST MONTH'][index];
}

extension HrLeaveLabel on HrLeavePeriod {
  String get label => const ['LAST WEEK', 'THIS WEEK', 'NEXT WEEK'][index];
}

class HrDateRange {
  const HrDateRange(this.first, this.last);
  final DateTime first, last;
  Map<String, String> get query => {
    'first_date': oracleDate(first),
    'last_date': oracleDate(last),
  };
  String get label =>
      first == last
          ? hrFullDate(first)
          : '${hrFullDate(first)}  --  ${hrFullDate(last)}';
  List<DateTime> get days => List.generate(
    last.difference(first).inDays + 1,
    (i) => DateTime(first.year, first.month, first.day + i),
    growable: false,
  );

  factory HrDateRange.attendance(HrAttendancePeriod period, DateTime now) {
    final today = dateOnly(now);
    final week = SummaryRange.forPeriod(SummaryPeriod.currentWeek, today);
    return switch (period) {
      HrAttendancePeriod.today => HrDateRange(today, today),
      HrAttendancePeriod.lastDay => HrDateRange(
        DateTime(today.year, today.month, today.day - 1),
        DateTime(today.year, today.month, today.day - 1),
      ),
      HrAttendancePeriod.lastWeek => HrDateRange(
        DateTime(week.first.year, week.first.month, week.first.day - 7),
        DateTime(week.first.year, week.first.month, week.first.day - 1),
      ),
      HrAttendancePeriod.lastMonth => HrDateRange(
        DateTime(today.year, today.month - 1),
        DateTime(today.year, today.month, 0),
      ),
    };
  }

  factory HrDateRange.leave(HrLeavePeriod period, DateTime now) {
    final week = SummaryRange.forPeriod(SummaryPeriod.currentWeek, now);
    final offset = (period.index - 1) * 7;
    final first = DateTime(
      week.first.year,
      week.first.month,
      week.first.day + offset,
    );
    return HrDateRange(first, DateTime(first.year, first.month, first.day + 6));
  }
}

String hrFullDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} ${hrMonths[date.month - 1]}, '
    '${(date.year % 100).toString().padLeft(2, '0')}';

class HrPayrollMonth {
  HrPayrollMonth(DateTime date) : first = DateTime(date.year, date.month);
  final DateTime first;
  HrDateRange get range =>
      HrDateRange(first, DateTime(first.year, first.month + 1, 0));
  String get label =>
      'MONTH: ${hrMonths[first.month - 1].substring(0, 3).toUpperCase()}-'
      '${(first.year % 100).toString().padLeft(2, '0')}';
  bool isAllowed(DateTime now) {
    final distance = now.year * 12 + now.month - first.year * 12 - first.month;
    return distance >= 1 && distance <= 6;
  }

  static List<HrPayrollMonth> available(DateTime now) => [
    for (var offset = 6; offset >= 1; offset--)
      HrPayrollMonth(DateTime(now.year, now.month - offset)),
  ];
}

String hrRequiredText(JsonMap row, String key) {
  if (!row.containsKey(key)) {
    throw const AppFailure(
      'The server returned incomplete HR Dashboard data.',
      kind: FailureKind.invalidData,
    );
  }
  return nativeText(row[key], '0');
}

AdminChartNumber hrNumber(JsonMap row, String key, {bool nonNegative = false}) {
  final value = AdminChartNumber.parse(hrRequiredText(row, key));
  if (nonNegative && value.units.isNegative) {
    throw const AppFailure(
      'The server returned an invalid HR Dashboard count.',
      kind: FailureKind.invalidData,
    );
  }
  return value;
}

class HrCounts {
  const HrCounts(this.departments, this.employees);
  final String departments, employees;
  factory HrCounts.fromJson(JsonMap row) {
    hrNumber(row, 'total_depts', nonNegative: true);
    hrNumber(row, 'total_emp', nonNegative: true);
    return HrCounts(
      hrRequiredText(row, 'total_depts'),
      hrRequiredText(row, 'total_emp'),
    );
  }
}

class HrAttendanceSlice {
  const HrAttendanceSlice(this.index, this.label, this.number);
  final int index;
  final String label;
  final AdminChartNumber number;
}

class HrAttendance {
  HrAttendance(this.slices);
  final List<HrAttendanceSlice> slices;
  static const keys = [
    'present',
    'absent',
    'leave',
    'holiday_weekend',
    'late_count',
    'early_count',
    'both_late_early_count',
  ];
  static const labels = [
    'On-Time Present',
    'Absent',
    'On Leave',
    'Holiday/Weekend',
    'Late Arrival',
    'Early Departure',
    'Both Late & Early',
  ];
  factory HrAttendance.fromJson(JsonMap row) => HrAttendance(
    List.unmodifiable(
      [
        for (var i = 0; i < keys.length; i++)
          HrAttendanceSlice(
            i,
            labels[i],
            hrNumber(row, keys[i], nonNegative: true),
          ),
      ].where((slice) => slice.number.units != BigInt.zero),
    ),
  );
  bool get isEmpty => slices.isEmpty;
  double get total => slices.fold(0.0, (sum, s) => sum + s.number.plot);
  String legend(HrAttendanceSlice slice) {
    // Native's legend denominator sums each integer-truncated float count.
    final denominator = slices.fold<int>(
      0,
      (sum, s) => sum + s.number.plot.toInt(),
    );
    if (denominator == 0) return slice.label;
    final divisor =
        BigInt.from(denominator) * BigInt.from(10).pow(slice.number.scale);
    final tenths = _roundedRatio(
      slice.number.units * BigInt.from(1000),
      divisor,
    );
    return '${slice.label} (${_tenths(tenths)} %)';
  }
}

class HrLeaveEmployee {
  HrLeaveEmployee(this.name, List<String> cells)
    : cells = List.unmodifiable(cells);
  final String name;
  final List<String> cells;
}

class HrWeeklyLeave {
  const HrWeeklyLeave(this.range, this.employees, {required this.hasDateRows});
  final HrDateRange range;
  final List<HrLeaveEmployee> employees;
  final bool hasDateRows;
  factory HrWeeklyLeave.fromRows(
    HrDateRange range,
    List<JsonMap> dates,
    List<JsonMap> names,
  ) {
    validateDateRows(dates);
    final days = range.days.map(oracleDate).toList(growable: false);
    return HrWeeklyLeave(
      range,
      List.unmodifiable([
        for (final row in names.take(5)) _employee(row, dates, days),
      ]),
      hasDateRows: dates.isNotEmpty,
    );
  }
  static void validateDateRows(List<JsonMap> dates) {
    for (final row in dates) {
      for (final key in [
        'd_date',
        'date_day',
        'emp_id',
        'emp_name',
        'leave',
        'h_flag',
      ]) {
        hrRequiredText(row, key);
      }
    }
  }

  static HrLeaveEmployee _employee(
    JsonMap row,
    List<JsonMap> dates,
    List<String> days,
  ) {
    final name = hrRequiredText(row, 'emp_name');
    final cells = List.filled(7, '');
    for (final entry in dates) {
      if (hrRequiredText(entry, 'emp_name') != name) continue;
      final index = days.indexOf(hrRequiredText(entry, 'd_date'));
      if (index >= 0 && (index < 6 || hrRequiredText(entry, 'h_flag') == '1')) {
        cells[index] = hrRequiredText(entry, 'leave');
      }
    }
    return HrLeaveEmployee(name, cells);
  }
}

BigInt _roundedRatio(BigInt numerator, BigInt denominator) {
  var quotient = numerator.abs() ~/ denominator;
  final twice = numerator.abs().remainder(denominator) * BigInt.two;
  if (twice > denominator || twice == denominator && quotient.isOdd) {
    quotient += BigInt.one;
  }
  return numerator.isNegative ? -quotient : quotient;
}

String _tenths(BigInt value) {
  final absolute = value.abs();
  final fraction = absolute.remainder(BigInt.from(10));
  return '${value.isNegative ? '-' : ''}${absolute ~/ BigInt.from(10)}'
      '${fraction == BigInt.zero ? '' : '.$fraction'}';
}

/// DecimalFormat("###,##,##,###.#"): lakh/crore groups, optional tenth, HALF_EVEN.
String nativeHrMoney(AdminChartNumber value) {
  final numerator = value.units * BigInt.from(10);
  final tenths = _roundedRatio(numerator, BigInt.from(10).pow(value.scale));
  final text = _tenths(tenths).split('.');
  final negativeZero = tenths == BigInt.zero && value.units.isNegative;
  return '৳ ${negativeZero ? '-' : ''}${nativePaymentInteger(text.first)}'
      '${text.length == 1 ? '' : '.${text.last}'}';
}

class HrPayroll {
  const HrPayroll({
    required this.hours,
    required this.workingDays,
    required this.salary,
    required this.refundable,
    required this.allowance,
    required this.deduction,
    required this.net,
  });
  final String hours, workingDays;
  final AdminChartNumber salary, refundable, allowance, deduction, net;
  factory HrPayroll.fromRows(JsonMap pay, JsonMap days) {
    hrNumber(pay, 'total');
    hrNumber(days, 'work_days', nonNegative: true);
    return HrPayroll(
      hours: hrRequiredText(pay, 'total'),
      workingDays: hrRequiredText(days, 'work_days'),
      salary: hrNumber(pay, 'salary'),
      refundable: hrNumber(pay, 'refundable'),
      allowance: hrNumber(pay, 'other_allowance'),
      deduction: hrNumber(pay, 'deduction'),
      net: hrNumber(pay, 'net_payable'),
    );
  }
}

class HrDashboardData {
  const HrDashboardData(this.counts, this.attendance, this.leave, this.payroll);
  final HrCounts counts;
  final HrAttendance attendance;
  final HrWeeklyLeave leave;
  final HrPayroll payroll;
}

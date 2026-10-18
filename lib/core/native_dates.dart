import 'failure.dart';

const _months = [
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

String _two(int value) => value.toString().padLeft(2, '0');
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String oracleDate(DateTime value) =>
    '${_two(value.day)}-${_months[value.month - 1]}-${_two(value.year % 100)}';

String nativeClockRequest(DateTime value) =>
    '${_two(value.day)}-${_two(value.month)}-${value.year} '
    '${_two(value.hour % 12 == 0 ? 12 : value.hour % 12)}:${_two(value.minute)} '
    '${value.hour < 12 ? 'AM' : 'PM'}';

DateTime parseOracleDate(String value) {
  final parts = value.trim().toUpperCase().split('-');
  if (parts.length == 3) {
    final day = int.tryParse(parts[0]);
    final month = _months.indexOf(parts[1]) + 1;
    final rawYear = int.tryParse(parts[2]);
    if (day != null && month > 0 && rawYear != null) {
      final year = parts[2].length == 2 ? 2000 + rawYear : rawYear;
      final result = DateTime(year, month, day);
      if (result.year == year && result.month == month && result.day == day) {
        return result;
      }
    }
  }
  throw const AppFailure(
    'The server returned an invalid appointment or expiry date.',
    kind: FailureKind.invalidData,
  );
}

DateTime parseAppointmentTime(String day, String time) {
  final date = parseOracleDate(day);
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(time.trim());
  if (match == null) {
    throw const AppFailure(
      'The server returned an invalid appointment time.',
      kind: FailureKind.invalidData,
    );
  }
  final rawHour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  if (rawHour < 1 || rawHour > 12 || minute > 59) {
    throw const AppFailure(
      'The server returned an invalid appointment time.',
      kind: FailureKind.invalidData,
    );
  }
  final hour = rawHour % 12 + (match[3]!.toUpperCase() == 'PM' ? 12 : 0);
  return DateTime(date.year, date.month, date.day, hour, minute);
}

DateTime calendarAddMonths(DateTime value, int months) {
  final target = DateTime(value.year, value.month + months);
  final maxDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(
    target.year,
    target.month,
    value.day > maxDay ? maxDay : value.day,
  );
}

enum SummaryPeriod { today, currentWeek, currentMonth, nextMonth }

extension SummaryPeriodLabel on SummaryPeriod {
  String get label => switch (this) {
    SummaryPeriod.today => 'Today',
    SummaryPeriod.currentWeek => 'Current Week',
    SummaryPeriod.currentMonth => 'Current Month',
    SummaryPeriod.nextMonth => 'Next Month',
  };
}

class SummaryRange {
  const SummaryRange(this.first, this.last);
  final DateTime first;
  final DateTime last;

  factory SummaryRange.forPeriod(SummaryPeriod period, DateTime now) {
    final today = dateOnly(now);
    return switch (period) {
      SummaryPeriod.today => SummaryRange(today, today),
      // DocDashboard explicitly sets Calendar.SATURDAY as the first day.
      SummaryPeriod.currentWeek => SummaryRange(
        today.subtract(Duration(days: (today.weekday + 1) % 7)),
        today.add(Duration(days: 6 - (today.weekday + 1) % 7)),
      ),
      SummaryPeriod.currentMonth => SummaryRange(
        DateTime(today.year, today.month),
        DateTime(today.year, today.month + 1, 0),
      ),
      SummaryPeriod.nextMonth => SummaryRange(
        DateTime(today.year, today.month + 1),
        DateTime(today.year, today.month + 2, 0),
      ),
    };
  }
}

String greeting(DateTime now) => switch (now.hour) {
  >= 4 && <= 11 => 'Good Morning,',
  >= 12 && <= 16 => 'Good Afternoon,',
  >= 17 && <= 22 => 'Good Evening,',
  _ => 'Hello,',
};

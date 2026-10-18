import '../../core/native_dates.dart';
import 'meeting_countdown.dart';

const _monthNames = [
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

String _two(int value) => value.toString().padLeft(2, '0');

String _fullDate(DateTime day) =>
    '${_two(day.day)} ${_monthNames[day.month - 1]}, ${_two(day.year % 100)}';

/// DocDashboard uses a full English date, including both ends of a range.
String nativeDashboardDate(SummaryPeriod period, DateTime now) {
  final range = SummaryRange.forPeriod(period, now);
  return period == SummaryPeriod.today
      ? _fullDate(range.first)
      : '${_fullDate(range.first)}  --  ${_fullDate(range.last)}';
}

/// Android's ICU-backed DecimalFormat("###,##,##,###") uses a final group of
/// three digits, then groups of two (lakh/crore). Keep the integer exact.
String nativePaymentInteger(String value) {
  final signed = value.startsWith('-') || value.startsWith('+');
  final digits = signed ? value.substring(1) : value;
  final grouped = StringBuffer(signed ? value[0] : '');
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && (remaining == 3 || (remaining > 3 && remaining.isOdd))) {
      grouped.write(',');
    }
    grouped.write(digits[i]);
  }
  return grouped.toString();
}

/// Match the native currency prefix/grouping without rounding API decimals.
String nativeDashboardMoney(String value) {
  final clean = value.trim();
  final match = RegExp(r'^([+-]?)(\d+)(\.\d+)?$').firstMatch(clean);
  if (match == null) {
    return '৳ $clean';
  }
  final integer = nativePaymentInteger('${match[1]}${match[2]}');
  return '৳ $integer${match[3] ?? ''}';
}

/// Native has distinct spacing/leading-zero branches when last_sc is present.
/// Keep the existing full-calendar-date check instead of its day-number bug.
String nativeDashboardMeeting(
  String value,
  DateTime now, {
  bool hasPrevious = false,
}) {
  final date = parseNativeMeetingTime(value);
  if (date == null) {
    return value;
  }
  final hour = date.hour;
  final minute = date.minute;
  final clock =
      '${_two(hour % 12 == 0 ? 12 : hour % 12)}:${_two(minute)} '
      '${hour < 12 ? 'AM' : 'PM'}';
  if (dateOnly(date) == dateOnly(now)) {
    final display =
        hasPrevious && clock.startsWith('0') ? clock.substring(1) : clock;
    return hasPrevious ? 'At  $display' : 'At $display';
  }
  final calendar =
      '${_two(date.day)} ${_monthNames[date.month - 1].substring(0, 3)}, '
      '${_two(date.year % 100)}';
  return hasPrevious ? 'At  $clock\nIn  $calendar' : 'At $clock\nIn $calendar';
}

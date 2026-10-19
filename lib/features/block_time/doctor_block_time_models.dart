import '../../core/failure.dart';
import '../../core/native_dates.dart';
import '../../core/native_json.dart';

const blockTimeMonths = [
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
const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
String blockTimeDateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} ${blockTimeMonths[date.month - 1]}, ${date.year}';
String blockTimeWeekday(DateTime date) => _weekdays[date.weekday - 1];
String blockTimeDateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Native current month and the following two, inclusive. Calendar constructors
/// avoid end-of-month rollover and elapsed-hour arithmetic across local DST.
class DoctorBlockWindow {
  DoctorBlockWindow(DateTime now)
    : first = DateTime(now.year, now.month),
      last = DateTime(now.year, now.month + 3, 0);
  final DateTime first, last;
  String get firstMonth => oracleDate(first).substring(3);
  String get lastMonth => oracleDate(last).substring(3);
  bool contains(DateTime date) {
    final day = dateOnly(date);
    return !day.isBefore(first) && !day.isAfter(last);
  }

  DateTime month(int offset) => DateTime(first.year, first.month + offset);
}

class DoctorBlockedSlot {
  const DoctorBlockedSlot({
    required this.date,
    required this.ladId,
    required this.lasId,
    required this.timeScheduleId,
    required this.notes,
    required this.leaveId,
    required this.leaveMonth,
    required this.time,
    required this.totalSchedules,
  });
  final DateTime date;
  final String ladId, lasId, timeScheduleId, notes, leaveId, leaveMonth, time;
  final int totalSchedules;
  factory DoctorBlockedSlot.fromJson(JsonMap row) {
    if (!const [
      'lad_id',
      'lad_date',
      'las_id',
      'las_ts_id',
      'las_notes',
      'la_id',
      'la_month',
      'schedule_time',
      'tot_sc',
    ].every(row.containsKey)) {
      throw const AppFailure(
        'The server returned incomplete blocked schedule data.',
        kind: FailureKind.invalidData,
      );
    }
    final rawDate = nativeText(row['lad_date']).trim();
    final total = int.tryParse(nativeText(row['tot_sc'], '0').trim());
    if (!RegExp(r'^\d{1,2}-[a-zA-Z]{3}-(?:\d{2}|\d{4})$').hasMatch(rawDate) ||
        total == null ||
        total < 0) {
      throw const AppFailure(
        'The server returned an invalid blocked schedule date or count.',
        kind: FailureKind.invalidData,
      );
    }
    DateTime date;
    try {
      date = parseOracleDate(rawDate);
    } on AppFailure {
      throw const AppFailure(
        'The server returned an invalid blocked schedule date.',
        kind: FailureKind.invalidData,
      );
    }
    return DoctorBlockedSlot(
      date: date,
      ladId: nativeText(row['lad_id']),
      lasId: nativeText(row['las_id']),
      timeScheduleId: nativeText(row['las_ts_id']),
      notes: nativeText(row['las_notes']),
      leaveId: nativeText(row['la_id']),
      leaveMonth: nativeText(row['la_month']),
      time: nativeText(row['schedule_time']),
      totalSchedules: total,
    );
  }
}

class DoctorBlockedDay {
  DoctorBlockedDay({
    required DateTime date,
    required List<DoctorBlockedSlot> slots,
    this.fullDay = false,
  }) : date = dateOnly(date),
       slots = List.unmodifiable(slots);
  final DateTime date;
  final List<DoctorBlockedSlot> slots;
  // DocLeave's getLeaveDays is commented out. getTimeSchedule always produces
  // fullDay=false; all slots blocked must not invent a full-day leave.
  final bool fullDay;
  int get totalSchedules => slots.isEmpty ? 0 : slots.last.totalSchedules;
  bool get allSchedulesBlocked => slots.length == totalSchedules;
  String get title => fullDay ? 'Leave Day' : 'Blocked Schedule';
  String? get message =>
      fullDay
          ? 'Full Day Off'
          : allSchedulesBlocked
          ? 'All Schedule Blocked'
          : null;
}

class DoctorBlockCalendar {
  DoctorBlockCalendar(this.window, List<DoctorBlockedSlot> slots) {
    final grouped = <DateTime, List<DoctorBlockedSlot>>{};
    for (final slot in slots) {
      (grouped[dateOnly(slot.date)] ??= []).add(slot);
    }
    days = Map.unmodifiable({
      for (final e in grouped.entries)
        e.key: DoctorBlockedDay(date: e.key, slots: e.value),
    });
  }
  final DoctorBlockWindow window;
  late final Map<DateTime, DoctorBlockedDay> days;
  DoctorBlockedDay? at(DateTime date) =>
      window.contains(date) ? days[dateOnly(date)] : null;
}

List<DateTime> blockTimeMonthCells(DateTime month) {
  final first = DateTime(month.year, month.month),
      leading = (DateTime(month.year, month.month).weekday + 1) % 7;
  return List.generate(
    42,
    (i) => DateTime(first.year, first.month, 1 - leading + i),
    growable: false,
  );
}

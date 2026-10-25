import '../../../../core/failure.dart';
import '../../../../core/native_dates.dart';
import '../../../../core/native_json.dart';

class AppointmentHistoryPatient {
  const AppointmentHistoryPatient({
    required this.id,
    required this.name,
    required this.code,
  });
  final String id, name, code;
  bool get valid {
    final number = double.tryParse(id);
    return id.trim().isNotEmpty && number != null && number.isFinite;
  }
}

class AppointmentHistoryRange {
  AppointmentHistoryRange(DateTime first, DateTime last)
    : first = dateOnly(first),
      last = dateOnly(last);
  factory AppointmentHistoryRange.initial(DateTime now) =>
      AppointmentHistoryRange(DateTime(now.year, now.month), now);
  final DateTime first, last;
  String get label =>
      first == last
          ? oracleDate(first)
          : '${oracleDate(first)}  ---  ${oracleDate(last)}';
  bool allowed(DateTime now, {required bool upcoming}) =>
      !first.isBefore(DateTime(1900)) &&
      !last.isAfter(DateTime(2100, 12, 31)) &&
      !last.isBefore(first) &&
      (upcoming || !last.isAfter(dateOnly(now)));
  AppointmentHistoryRange restrictToToday(DateTime now) {
    final today = dateOnly(now);
    return AppointmentHistoryRange(
      first.isAfter(today) ? today : first,
      last.isAfter(today) ? today : last,
    );
  }
}

enum AppointmentHistoryStatus { completed, upcoming, canceled, notAvailable }

extension AppointmentHistoryStatusLabel on AppointmentHistoryStatus {
  String get label => switch (this) {
    AppointmentHistoryStatus.completed => 'Completed',
    AppointmentHistoryStatus.upcoming => 'Upcoming',
    AppointmentHistoryStatus.canceled => 'Canceled',
    AppointmentHistoryStatus.notAvailable => 'N/A',
  };
}

class AppointmentHistoryRow {
  AppointmentHistoryRow(JsonMap row)
    : values = Map.unmodifiable({
        for (final key in keys) key: _field(row, key),
      });
  static const keys = [
    'ph_patient_status',
    'ph_patient_cat',
    'app_date',
    'date_name',
    'depts_name',
    'depts_id',
    'deptd_name',
    'deptm_name',
    'schedule_time',
    'ets',
    'doc_name',
    'doc_id',
    'pfn_fee_name',
    'pfn_id',
    'avail',
    'ad_pat_app_status',
    'cancel_status',
    'prm_code',
  ];
  final Map<String, String> values;
  String value(String key) => values[key] ?? '';
  static String _field(JsonMap row, String key) {
    if (!row.containsKey(key) ||
        row[key] is Map ||
        row[key] is List ||
        row[key] is bool) {
      throw AppFailure(
        'The server returned an invalid "$key" field for appointment history.',
        kind: FailureKind.invalidData,
      );
    }
    return nativeText(row[key], key == 'cancel_status' ? '0' : '');
  }

  AppointmentHistoryStatus status(DateTime now) {
    try {
      final day = parseOracleDate(value('app_date'));
      final today = dateOnly(now);
      // Native compares today's time before deciding canceled/completed.
      final past =
          day == today
              ? parseAppointmentTime(
                value('app_date'),
                value('schedule_time'),
              ).isBefore(now)
              : day.isBefore(today);
      if (value('cancel_status') == 'Yes') {
        return AppointmentHistoryStatus.canceled;
      }
      return past
          ? AppointmentHistoryStatus.completed
          : AppointmentHistoryStatus.upcoming;
    } on AppFailure {
      return AppointmentHistoryStatus.notAvailable;
    }
  }
}

enum AppointmentHistoryFilter { service, unit, doctor }

extension AppointmentHistoryFilterFields on AppointmentHistoryFilter {
  String get idKey => switch (this) {
    AppointmentHistoryFilter.service => 'pfn_id',
    AppointmentHistoryFilter.unit => 'depts_id',
    AppointmentHistoryFilter.doctor => 'doc_id',
  };
  String get nameKey => switch (this) {
    AppointmentHistoryFilter.service => 'pfn_fee_name',
    AppointmentHistoryFilter.unit => 'depts_name',
    AppointmentHistoryFilter.doctor => 'doc_name',
  };
  String get label => switch (this) {
    AppointmentHistoryFilter.service => 'Search by Service',
    AppointmentHistoryFilter.unit => 'Search by Unit',
    AppointmentHistoryFilter.doctor => 'Search by Doctor/Therapist',
  };
}

class AppointmentHistoryChoice {
  const AppointmentHistoryChoice(this.id, this.name);
  static const clear = AppointmentHistoryChoice('', '...');
  final String id, name;
  bool get isClear => id.isEmpty && name == '...';
}

List<AppointmentHistoryChoice> appointmentHistoryChoices(
  List<AppointmentHistoryRow> rows,
  AppointmentHistoryFilter kind,
) {
  if (rows.isEmpty) return const [];
  final seen = <(String, String)>{('', '...')};
  return List.unmodifiable([
    AppointmentHistoryChoice.clear,
    for (final row in rows)
      if (seen.add((row.value(kind.idKey), row.value(kind.nameKey))))
        AppointmentHistoryChoice(
          row.value(kind.idKey),
          row.value(kind.nameKey),
        ),
  ]);
}

List<AppointmentHistoryRow> filterAppointmentHistory(
  List<AppointmentHistoryRow> rows,
  Map<AppointmentHistoryFilter, AppointmentHistoryChoice> selected,
) => List.unmodifiable(
  rows.where(
    (row) => selected.entries.every(
      // Match IDs, not fragments or display names (1 must not also select 10).
      (entry) =>
          entry.value.id.isEmpty ||
          row.value(entry.key.idKey) == entry.value.id,
    ),
  ),
);

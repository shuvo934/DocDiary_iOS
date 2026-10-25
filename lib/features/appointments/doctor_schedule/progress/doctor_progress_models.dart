import 'dart:convert';
import '../../../../core/failure.dart';
import '../../../../core/native_dates.dart';
import '../../../../core/native_json.dart';
import '../doctor_appointment_models.dart';
import '../history/doctor_appointment_history_models.dart';

class DoctorProgressSeed {
  DoctorProgressSeed.fromAppointment(
    DoctorAppointmentRow row, {
    required this.ownerDoctorId,
  }) : appointment = row,
       patientId = row.value('patient_data'),
       patientName = row.value('pat_name'),
       patientCode = row.value('pat_code');
  const DoctorProgressSeed.viewPatient({
    required this.patientId,
    required this.patientName,
    required this.patientCode,
  }) : appointment = null,
       ownerDoctorId = '';
  final DoctorAppointmentRow? appointment;
  final String patientId, patientName, patientCode, ownerDoctorId;
  bool get valid {
    final number = double.tryParse(patientId);
    return number != null && number.isFinite && patientId.trim().isNotEmpty;
  }

  bool mayAdd(DateTime now) {
    final row = appointment;
    if (row == null ||
        !row.booked ||
        row.value('is_ranked') != '0' ||
        row.value('adm_date') != oracleDate(now)) {
      return false;
    }
    try {
      return dateOnly(row.selectedDate) == dateOnly(now) &&
          parseAppointmentTime(
            row.value('adm_date'),
            row.value('schedule_time'),
          ).isBefore(now);
    } on AppFailure {
      return false;
    }
  }
}

String progressField(JsonMap row, String key) {
  if (!row.containsKey(key) ||
      row[key] is Map ||
      row[key] is List ||
      row[key] is bool) {
    throw AppFailure(
      'The server returned an invalid "$key" field for health progress.',
      kind: FailureKind.invalidData,
    );
  }
  return nativeText(row[key]);
}

String progressNotes(String value) {
  // Legacy Android repairs Latin-1-wrapped UTF-8. Preserve already-correct
  // Unicode instead of replacing Bangla/emoji with question marks.
  if (value.codeUnits.any((unit) => unit > 255)) return value;
  try {
    return utf8.decode(latin1.encode(value));
  } on FormatException {
    return value;
  }
}

class DoctorProgressRow {
  DoctorProgressRow(JsonMap row)
    : values = Map.unmodifiable({
        for (final key in keys)
          key:
              key == 'pph_notes'
                  ? progressNotes(progressField(row, key))
                  : progressField(row, key),
      }) {
    if (int.tryParse(value('pph_progress')) == null) {
      throw const AppFailure(
        'The server returned an invalid health progress score.',
        kind: FailureKind.invalidData,
      );
    }
  }
  static const keys = [
    'pph_id',
    'pph_date',
    'pph_doc_id',
    'doc_name',
    'pph_depts_id',
    'detps_name',
    'pph_pfn_id',
    'pfn_name',
    'pph_ad_id',
    'pph_progress',
    'pph_notes',
    'pph_rec_no',
  ];
  final Map<String, String> values;
  String value(String key) => values[key] ?? '';
  int get score => int.parse(value('pph_progress'));
  bool forSchedule(DoctorProgressSeed seed) =>
      seed.appointment != null &&
      seed.appointment!.id.isNotEmpty &&
      value('pph_ad_id') == seed.appointment!.id;
}

class DoctorProgressSnapshot {
  DoctorProgressSnapshot(
    List<DoctorProgressRow> rows,
    Map<AppointmentHistoryFilter, List<AppointmentHistoryChoice>> choices,
  ) : rows = List.unmodifiable(rows),
      choices = Map.unmodifiable({
        for (final entry in choices.entries)
          entry.key: List<AppointmentHistoryChoice>.unmodifiable(entry.value),
      });
  final List<DoctorProgressRow> rows;
  final Map<AppointmentHistoryFilter, List<AppointmentHistoryChoice>> choices;
}

String progressFilterId(AppointmentHistoryFilter kind) => switch (kind) {
  AppointmentHistoryFilter.service => 'pph_pfn_id',
  AppointmentHistoryFilter.unit => 'pph_depts_id',
  AppointmentHistoryFilter.doctor => 'pph_doc_id',
};
List<DoctorProgressRow> filterDoctorProgress(
  List<DoctorProgressRow> rows,
  Map<AppointmentHistoryFilter, AppointmentHistoryChoice> selected,
) => List.unmodifiable(
  rows.where(
    (row) => selected.entries.every(
      (entry) =>
          entry.value.id.isEmpty ||
          row.value(progressFilterId(entry.key)) == entry.value.id,
    ),
  ),
);

String progressEntryTime(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(now.day)}/${two(now.month)}/${now.year.toString().padLeft(4, '0')} ${two(now.hour % 12 == 0 ? 12 : now.hour % 12)}:${two(now.minute)}:${two(now.second)} ${now.hour < 12 ? 'AM' : 'PM'}';
}

class DoctorProgressDraft {
  const DoctorProgressDraft({
    required this.score,
    required this.notes,
    required this.entryTime,
  });
  final int score;
  final String notes, entryTime;
  bool get valid =>
      score >= 1 &&
      score <= 10 &&
      notes.trim().isNotEmpty &&
      entryTime.isNotEmpty;
}

enum DoctorProgressResult { created, alreadyAdded, unavailable }

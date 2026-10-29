import '../../core/failure.dart';
import '../../core/native_dates.dart';
import '../../core/native_json.dart';
import '../auth/profile_repository.dart';
import '../prescription/normal_prescription_models.dart';

/// PatientSearch.java and PatientSearchDyPrescription.java. Admin's registration
/// and calling flow is a separate entry; it does not acquire doctor capability.
enum PatientSearchMode {
  normal,
  dynamicPrescription;

  static PatientSearchMode forProfile(AccountProfile profile) =>
      profile.value('presc_active') == '1' &&
              profile.value('can_prescribe') == '1'
          ? dynamicPrescription
          : normal;
}

class PatientSearchRow {
  PatientSearchRow(JsonMap values) : values = Map.unmodifiable(values) {
    if (!rxId(historyId)) {
      throw const AppFailure(
        'The server returned an invalid patient identifier.',
        kind: FailureKind.invalidData,
      );
    }
  }
  final JsonMap values;
  String value(String key) => nativeText(values[key]).trim();
  String get id => value('pat_id');
  String get historyId => value('ph_id');
  String get name => value('pat_name');
  String get code => value('sub_code');
  String get area => value('dd_thana_name');
  String get year => value('pyear');
  String get genderAge => [
    value('gender'),
    value('pat_age'),
  ].where((s) => s.isNotEmpty).join('  •  ');
  int get progress {
    final number = double.tryParse(value('pph_progress'));
    if (number == null || !number.isFinite) return 0;
    return number.round().clamp(0, 10);
  }

  bool matches(String query) =>
      name.toLowerCase().contains(query.toLowerCase()) ||
      code.toLowerCase().contains(query.toLowerCase());
}

const patientSearchRecentMessage =
    'Showing the latest 100 patients for the selected year';
const patientSearchResultsMessage = 'Showing all searched registered patients';
String? patientSearchQueryError(String text) =>
    text.trim().isEmpty
        ? 'Please write patient name, code or mobile before search'
        : text.trim().length < 3
        ? 'Please write at least 3 characters before search'
        : null;

/// PatAppointmentCalendar's previous month through two months ahead, inclusive.
class PatientAppointmentWindow {
  PatientAppointmentWindow(DateTime now)
    : first = DateTime(now.year, now.month - 1),
      last = DateTime(now.year, now.month + 3, 0);
  final DateTime first, last;
  bool contains(DateTime day) =>
      !dateOnly(day).isBefore(first) && !dateOnly(day).isAfter(last);
  DateTime monthAt(int index) => DateTime(first.year, first.month + index);
  int indexOf(DateTime day) =>
      (day.year - first.year) * 12 + day.month - first.month;
}

enum PatientAppointmentStatus { completed, upcoming, canceled }

class PatientCalendarAppointment {
  PatientCalendarAppointment(JsonMap values)
    : values = Map.unmodifiable(values),
      date = parseOracleDate(nativeText(values['app_date'])) {
    if (value('schedule_time').isEmpty) {
      throw const AppFailure(
        'The server returned an invalid appointment time.',
        kind: FailureKind.invalidData,
      );
    }
    // Validate once, before publishing any calendar data.
    startsAt;
  }
  final JsonMap values;
  final DateTime date;
  String value(String key) => nativeText(values[key]).trim();
  DateTime get startsAt {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value('schedule_time'));
    if (match == null) {
      throw const AppFailure(
        'The server returned an invalid appointment time.',
      );
    }
    final hour = int.parse(match[1]!), minute = int.parse(match[2]!);
    if (hour < 1 || hour > 12 || minute > 59) {
      throw const AppFailure(
        'The server returned an invalid appointment time.',
      );
    }
    return DateTime(
      date.year,
      date.month,
      date.day,
      hour % 12 + (match[3]!.toUpperCase() == 'PM' ? 12 : 0),
      minute,
    );
  }

  PatientAppointmentStatus status(DateTime now) =>
      value('cancel_status') == 'Yes'
          ? PatientAppointmentStatus.canceled
          : startsAt.isBefore(now)
          ? PatientAppointmentStatus.completed
          : PatientAppointmentStatus.upcoming;
}

/// The seven original drawable combinations, including mixed days.
String patientCalendarMarker(
  Iterable<PatientCalendarAppointment> appointments,
  DateTime now,
) {
  final states = appointments.map((row) => row.status(now)).toSet();
  final parts = [
    if (states.contains(PatientAppointmentStatus.canceled)) 'cancel',
    if (states.contains(PatientAppointmentStatus.completed)) 'done',
    if (states.contains(PatientAppointmentStatus.upcoming)) 'upcoming',
  ];
  return parts.isEmpty ? '' : '${parts.join('_')}_appt';
}

import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../../core/native_json.dart';
import '../../auth/profile_repository.dart';

bool unitAppointmentAllowed(AccountProfile profile) =>
    profile.isDoctor &&
    profile.value('doc_deptd_head_flag') == '1' &&
    profile.value('doc_manager_flag') != '1';

String unitAppointmentScope(AccountProfile profile) => [
  profile.doctorId,
  profile.value('doc_code'),
  profile.value('deptd_id'),
  profile.value('depts_id'),
].join('|');

bool unitAppointmentId(String value) => RegExp(r'^\d+$').hasMatch(value);

class UnitAppointmentUnavailable implements Exception {
  const UnitAppointmentUnavailable();
}

class UnitAppointmentChoice {
  const UnitAppointmentChoice(this.id, this.name);
  final String id, name;
  static const clear = UnitAppointmentChoice('', '...');
}

enum UnitAppointmentSlotKind { booked, blank, blocked }

/// DoctorAppSchList. UnitWiseAppointment always supplies calling_permission=1.
class UnitAppointmentSlot {
  UnitAppointmentSlot(JsonMap row)
    : values = Map.unmodifiable(row),
      startsAt = parseAppointmentTime(
        nativeText(row['adm_date']),
        nativeText(row['schedule_time']),
      );
  final JsonMap values;
  final DateTime startsAt;
  String value(String key) => nativeText(values[key]).trim();
  bool get booked {
    final number = double.tryParse(value('patient_data'));
    return number != null && number.isFinite;
  }

  UnitAppointmentSlotKind get kind =>
      value('patient_data').isEmpty
          ? UnitAppointmentSlotKind.blank
          : booked
          ? UnitAppointmentSlotKind.booked
          : UnitAppointmentSlotKind.blocked;
  bool completed(DateTime now) => booked && startsAt.isBefore(now);
  String message(DateTime now) => switch (kind) {
    UnitAppointmentSlotKind.booked => '',
    UnitAppointmentSlotKind.blocked => value('patient_data'),
    UnitAppointmentSlotKind.blank =>
      startsAt.isBefore(now) ? 'No Meeting happened' : '...',
  };
}

int _count(JsonMap row, String key, {bool nullAsZero = false}) {
  if (!row.containsKey(key)) {
    throw const AppFailure(
      'The server returned incomplete unit schedule data.',
    );
  }
  final value = nativeText(row[key], nullAsZero ? '0' : '');
  final number = int.tryParse(value);
  if (number == null || number < 0) {
    throw const AppFailure(
      'The server returned an invalid unit schedule count.',
    );
  }
  return number;
}

/// UnitDoctorsList and the native totals calculation (busy slots are excluded).
class UnitAppointmentDoctor {
  UnitAppointmentDoctor.fromData(JsonMap row)
    : id = nativeText(row['doc_id']).trim(),
      name = nativeText(row['doc_name']).trim(),
      code = nativeText(row['doc_code']).trim(),
      appointmentCount = _count(row, 'app_count'),
      totalCount = _count(row, 'tot_count', nullAsZero: true),
      busyCount = _count(row, 'busy_count', nullAsZero: true),
      schedules = List.unmodifiable(
        nativeArray(row['app_list']).map(UnitAppointmentSlot.new),
      ) {
    if (!unitAppointmentId(id) ||
        !row.containsKey('app_list') ||
        row['app_list'] == null ||
        row['app_list'] == '' ||
        row['app_list'] == 'null') {
      throw const AppFailure(
        'The server returned invalid doctor schedule data.',
      );
    }
  }
  final String id, name, code;
  final int appointmentCount, totalCount, busyCount;
  final List<UnitAppointmentSlot> schedules;
  String get label => '$name ($code)';
  int get blankCount =>
      totalCount == 0 ? 0 : totalCount - appointmentCount - busyCount;
  int initialScheduleIndex(DateTime now) {
    final index = schedules.indexWhere(
      (slot) => slot.booked && !slot.startsAt.isBefore(now),
    );
    return index < 0 ? 0 : index;
  }
}

class UnitAppointmentSnapshot {
  UnitAppointmentSnapshot(Iterable<UnitAppointmentDoctor> rows)
    : doctors = List.unmodifiable(rows);
  final List<UnitAppointmentDoctor> doctors;
  int get appointmentCount =>
      doctors.fold(0, (sum, row) => sum + row.appointmentCount);
  int get blankCount => doctors.fold(0, (sum, row) => sum + row.blankCount);
  List<UnitAppointmentDoctor> filtered(String id) =>
      id.isEmpty
          ? doctors
          : List.unmodifiable(doctors.where((doctor) => doctor.id == id));
  List<UnitAppointmentChoice> get doctorChoices => List.unmodifiable([
    if (doctors.length > 1) UnitAppointmentChoice.clear,
    for (final doctor in doctors)
      UnitAppointmentChoice(doctor.id, doctor.label),
  ]);
}

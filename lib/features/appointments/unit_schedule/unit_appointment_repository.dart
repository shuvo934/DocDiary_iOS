import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../../core/native_json.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../doctor_schedule/doctor_appointment_models.dart';
import '../doctor_schedule/doctor_appointment_repository.dart';
import 'unit_appointment_models.dart';

class UnitAppointmentRepository {
  const UnitAppointmentRepository(this.appointments);
  final DoctorAppointmentRepository appointments;
  DateTime now() => appointments.now();

  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() isCurrent,
  ) {
    appointments.guard(session, profile, isCurrent);
    if (!unitAppointmentAllowed(profile)) {
      throw const UnitAppointmentUnavailable();
    }
    if (!unitAppointmentId(profile.value('deptd_id').trim())) {
      throw const AppFailure(
        'The department for Unit Appointment was not returned by the server.',
      );
    }
  }

  Future<List<JsonMap>> _get(
    AuthSession session,
    AccountProfile profile,
    String endpoint,
    Map<String, String> query,
    bool Function() isCurrent,
  ) async {
    guard(session, profile, isCurrent);
    final data = await appointments.transport
        .get(
          apiEndpoint(
            session.center.baseUri,
            'doctors_app_schedule/$endpoint',
            query,
          ),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout:
              () =>
                  throw const AppFailure(
                    'The server took too long to respond. Please try again.',
                    kind: FailureKind.network,
                  ),
        );
    guard(session, profile, isCurrent);
    final count = int.tryParse(nativeText(data['count']));
    if (count == null || count < 0) {
      throw const AppFailure(
        'The server returned an invalid unit appointment count.',
      );
    }
    if (count == 0) return const [];
    final rows = nativeItems(data);
    if (rows.isEmpty) {
      throw const AppFailure(
        'The server returned incomplete unit appointment data.',
      );
    }
    return rows;
  }

  Future<List<UnitAppointmentChoice>> units(
    AuthSession session,
    AccountProfile profile, {
    required bool Function() isCurrent,
  }) async {
    final rows = await _get(session, profile, 'getUnitList', {
      'deptd_id': profile.value('deptd_id').trim(),
    }, isCurrent);
    final choices =
        rows
            .map(
              (row) => UnitAppointmentChoice(
                nativeText(row['depts_id']).trim(),
                nativeText(row['depts_name']).trim(),
              ),
            )
            .toList();
    if (choices.any((choice) => !unitAppointmentId(choice.id))) {
      throw const AppFailure('The server returned an invalid unit identifier.');
    }
    return List.unmodifiable(choices);
  }

  Future<UnitAppointmentSnapshot> doctors(
    AuthSession session,
    AccountProfile profile,
    DateTime selected,
    UnitAppointmentChoice unit,
    List<UnitAppointmentChoice> permittedUnits, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    if (!DoctorAppointmentWindow(now()).contains(selected)) {
      throw const AppFailure('This date is outside the appointment calendar.');
    }
    if (!permittedUnits.any((choice) => choice.id == unit.id) ||
        !unitAppointmentId(unit.id)) {
      throw const AppFailure('Please select a unit from the current list.');
    }
    final rows = await _get(session, profile, 'getDocWithSchedule', {
      'pdate': oracleDate(selected),
      'depts_id': unit.id,
      'deptd_id': profile.value('deptd_id').trim(),
    }, isCurrent);
    final result = UnitAppointmentSnapshot(
      rows.map(UnitAppointmentDoctor.fromData),
    );
    if (result.doctors.any(
      (doctor) => doctor.schedules.any(
        (slot) => dateOnly(slot.startsAt) != dateOnly(selected),
      ),
    )) {
      throw const AppFailure(
        'The server returned a schedule for a different date.',
      );
    }
    return result;
  }
}

import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../../core/native_json.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../../patient_search/patient_view_access.dart';
import '../doctor_schedule/doctor_appointment_models.dart';
import '../doctor_schedule/doctor_appointment_repository.dart';
import '../unit_schedule/unit_appointment_models.dart';
import 'all_appointment_models.dart';

class AllAppointmentRepository {
  const AllAppointmentRepository(this.appointments);
  final DoctorAppointmentRepository appointments;
  DateTime now() => appointments.now();

  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() isCurrent,
  ) {
    guardPatientViewAccess(appointments, session, profile, isCurrent);
    if (!allAppointmentAllowed(profile)) {
      throw const AllAppointmentUnavailable();
    }
  }

  Future<List<JsonMap>> _get(
    AuthSession session,
    AccountProfile profile,
    String path,
    Map<String, String> query,
    bool Function() isCurrent,
  ) async {
    guard(session, profile, isCurrent);
    final response = await appointments.transport
        .get(apiEndpoint(session.center.baseUri, path, query))
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
    final count = int.tryParse(nativeText(response['count']));
    if (count == null || count < 0) {
      throw const AppFailure(
        'The server returned an invalid appointment count.',
      );
    }
    if (count == 0) return const [];
    final rows = nativeItems(response);
    if (rows.isEmpty) {
      throw const AppFailure(
        'The server returned incomplete appointment data.',
      );
    }
    return rows;
  }

  List<UnitAppointmentChoice> _choices(List<JsonMap> rows, bool department) {
    final id = department ? 'deptd_id' : 'depts_id';
    final name = department ? 'deptd_name' : 'depts_name';
    final choices = [
      for (final row in rows)
        UnitAppointmentChoice(
          nativeText(row[id]).trim(),
          nativeText(row[name]).trim(),
        ),
    ];
    if (choices.any((choice) => !unitAppointmentId(choice.id))) {
      throw const AppFailure(
        'The server returned an invalid schedule identifier.',
      );
    }
    return List.unmodifiable(choices);
  }

  void _department(
    UnitAppointmentChoice department,
    List<UnitAppointmentChoice> allowed,
  ) {
    if (!unitAppointmentId(department.id) ||
        !allowed.any((row) => row.id == department.id)) {
      throw const AppFailure(
        'Please select a department from the current list.',
      );
    }
  }

  void _day(DateTime day) {
    if (!DoctorAppointmentWindow(now()).contains(day)) {
      throw const AppFailure('This date is outside the appointment calendar.');
    }
  }

  Future<List<UnitAppointmentChoice>> departments(
    AuthSession session,
    AccountProfile profile, {
    required bool Function() isCurrent,
  }) async => _choices(
    await _get(
      session,
      profile,
      'all_appointment/getDeptd',
      const {},
      isCurrent,
    ),
    true,
  );

  Future<List<UnitAppointmentChoice>> units(
    AuthSession session,
    AccountProfile profile,
    UnitAppointmentChoice department,
    List<UnitAppointmentChoice> allowedDepartments, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    _department(department, allowedDepartments);
    return _choices(
      await _get(session, profile, 'doctors_app_schedule/getUnitList', {
        'deptd_id': department.id,
      }, isCurrent),
      false,
    );
  }

  Future<AllAppointmentTotals> totals(
    AuthSession session,
    AccountProfile profile,
    DateTime selected,
    UnitAppointmentChoice department,
    List<UnitAppointmentChoice> allowedDepartments, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    _department(department, allowedDepartments);
    _day(selected);
    final rows = await _get(
      session,
      profile,
      'all_appointment/getDeptdSchCount',
      {'deptd_id': department.id, 'pdate': oracleDate(selected)},
      isCurrent,
    );
    return rows.isEmpty
        ? AllAppointmentTotals.zero
        : AllAppointmentTotals.fromData(rows.last);
  }

  Future<UnitAppointmentSnapshot> doctors(
    AuthSession session,
    AccountProfile profile,
    DateTime selected,
    UnitAppointmentChoice department,
    List<UnitAppointmentChoice> allowedDepartments,
    UnitAppointmentChoice unit,
    List<UnitAppointmentChoice> allowedUnits, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    _department(department, allowedDepartments);
    _day(selected);
    if (!unitAppointmentId(unit.id) ||
        !allowedUnits.any((row) => row.id == unit.id)) {
      throw const AppFailure('Please select a unit from the current list.');
    }
    final rows = await _get(
      session,
      profile,
      'doctors_app_schedule/getDocWithSchedule',
      {
        'pdate': oracleDate(selected),
        'depts_id': unit.id,
        'deptd_id': department.id,
      },
      isCurrent,
    );
    final snapshot = UnitAppointmentSnapshot(
      rows.map(UnitAppointmentDoctor.fromData),
    );
    if (snapshot.doctors.any(
      (doctor) => doctor.schedules.any(
        (slot) => dateOnly(slot.startsAt) != dateOnly(selected),
      ),
    )) {
      throw const AppFailure(
        'The server returned a schedule for a different date.',
      );
    }
    return snapshot;
  }
}

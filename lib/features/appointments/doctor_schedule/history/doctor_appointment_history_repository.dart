import '../../../../core/failure.dart';
import '../../../../core/native_dates.dart';
import '../../../../core/native_json.dart';
import '../../../auth/auth_models.dart';
import '../../../auth/profile_repository.dart';
import '../doctor_appointment_repository.dart';
import 'doctor_appointment_history_models.dart';

class DoctorAppointmentHistoryRepository {
  const DoctorAppointmentHistoryRepository(this.appointments);
  final DoctorAppointmentRepository appointments;
  DateTime now() => appointments.now();
  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() current,
  ) {
    appointments.guard(session, profile, current);
    if (profile.value('pat_app_history') != '1') {
      throw const AppFailure(
        'Appointment history access is no longer available.',
        kind: FailureKind.invalidData,
      );
    }
  }

  Future<List<AppointmentHistoryRow>> load(
    AuthSession session,
    AccountProfile profile,
    AppointmentHistoryPatient patient,
    AppointmentHistoryRange range, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    if (!patient.valid ||
        !range.allowed(
          now(),
          upcoming: profile.value('upcoming_pat_history') == '1',
        )) {
      throw const AppFailure(
        'The patient or appointment history date range is invalid.',
        kind: FailureKind.invalidData,
      );
    }
    final response = await appointments.transport.get(
      apiEndpoint(
        session.center.baseUri,
        'appointment_schedule/getPatAppointHistory',
        {
          'begin_date': oracleDate(range.first),
          'end_date': oracleDate(range.last),
          'p_ph_id': patient.id,
        },
      ),
    );
    guard(session, profile, isCurrent);
    final count = int.tryParse(nativeText(response['count']).trim());
    if (count == null || count < 0) {
      throw const AppFailure(
        'The server returned an invalid appointment history count.',
        kind: FailureKind.invalidData,
      );
    }
    if (count == 0) return const [];
    final rows = nativeItems(response);
    if (rows.isEmpty) {
      throw const AppFailure(
        'The server returned an invalid appointment history list.',
        kind: FailureKind.invalidData,
      );
    }
    return List.unmodifiable(rows.map(AppointmentHistoryRow.new));
  }
}

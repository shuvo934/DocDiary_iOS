import '../../../../core/failure.dart';
import '../../../../core/native_json.dart';
import '../../../auth/auth_models.dart';
import '../../../auth/profile_repository.dart';
import '../doctor_appointment_models.dart';
import '../doctor_appointment_repository.dart';

enum DoctorAppointmentAvailResult { created, alreadyAvailed, unavailable }

class DoctorAppointmentAvailRepository {
  const DoctorAppointmentAvailRepository(this.appointments);
  final DoctorAppointmentRepository appointments;

  static String? notesError(String notes) =>
      notes.codeUnits.any((unit) => unit < 32 || unit > 126)
          ? 'Please use a single line of English text. This server sends notes as HTTP headers.'
          : null;

  /// Native AvailScheduleDialogue sends two headers and no form/JSON body.
  /// Every explicit retry first reads current status; POST is never automatic.
  Future<DoctorAppointmentAvailResult> submit(
    AuthSession session,
    AccountProfile profile,
    DoctorAppointmentRow selected,
    String notes, {
    required bool Function() isCurrent,
  }) async {
    appointments.guard(session, profile, isCurrent);
    final invalidNotes = notesError(notes);
    if (invalidNotes != null) {
      throw AppFailure(invalidNotes, kind: FailureKind.invalidData);
    }
    if (selected.id.trim().isEmpty ||
        selected.id.codeUnits.any((unit) => unit < 32 || unit > 126)) {
      throw const AppFailure(
        'The server returned an invalid appointment ID.',
        kind: FailureKind.invalidData,
      );
    }
    final flags = DoctorAppointmentFeatures(profile);
    if (!selected.present(flags, appointments.now()).showAvail) {
      return DoctorAppointmentAvailResult.unavailable;
    }
    final rows = await appointments.load(
      session,
      profile,
      DoctorAppointmentWindow(appointments.now()),
      selected.selectedDate,
      isCurrent: isCurrent,
    );
    // An ID alone is insufficient when a slot was reassigned while the dialog
    // was open. Keep the patient's native identity and schedule attached.
    final matching = rows.where((row) => _sameAppointment(row, selected));
    if (matching.isEmpty) return DoctorAppointmentAvailResult.unavailable;
    if (matching.any((row) => row.value('avail_flag') == '1')) {
      return DoctorAppointmentAvailResult.alreadyAvailed;
    }
    final current = matching.first;
    if (!current.present(flags, appointments.now()).showAvail) {
      return DoctorAppointmentAvailResult.unavailable;
    }
    appointments.guard(session, profile, isCurrent);
    final response = await appointments.transport.post(
      apiEndpoint(session.center.baseUri, 'appointment_schedule/availSchedule'),
      headers: {'P_AD_ID': current.id, 'P_NOTE': notes},
    );
    appointments.guard(session, profile, isCurrent);
    final status = response['string_out'];
    if (status is! String || status != 'Successfully Created') {
      throw AppFailure(
        status is String && nativeText(status).trim().isNotEmpty
            ? status
            : 'The server did not confirm this request.',
      );
    }
    return DoctorAppointmentAvailResult.created;
  }

  static bool _sameAppointment(
    DoctorAppointmentRow left,
    DoctorAppointmentRow right,
  ) =>
      left.selectedDate == right.selectedDate &&
      const [
        'ad_id',
        'patient_data',
        'pat_id',
        'adm_date',
        'schedule_time',
        'depts_id',
        'pfn_id',
      ].every((key) => left.value(key) == right.value(key));
}

import '../../core/failure.dart';
import '../appointments/doctor_schedule/doctor_appointment_repository.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';

/// Shared patient GET access. Appointment editing keeps its doctor-only guard.
void guardPatientViewAccess(
  DoctorAppointmentRepository appointments,
  AuthSession session,
  AccountProfile profile,
  bool Function() isCurrent,
) {
  if (profile.isDoctor) {
    appointments.guard(session, profile, isCurrent);
    return;
  }
  if (!isCurrent()) throw const ObsoleteRequest();
  if (session.account.role != AccountRole.admin ||
      profile.role != session.account.role ||
      session.account.adminId.isEmpty ||
      (profile.value('usr_id').isNotEmpty &&
          profile.value('usr_id') != session.account.adminId) ||
      (session.account.adminUserName.isNotEmpty &&
          profile.value('usr_name') != session.account.adminUserName)) {
    throw const AppFailure(
      'The server returned information for a different account. Please try again.',
      kind: FailureKind.invalidData,
    );
  }
  ProfileRepository.checkAccess(profile, appointments.now());
}

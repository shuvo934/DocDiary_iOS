import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../appointments/doctor_schedule/doctor_appointment_repository.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../prescription/normal_prescription_models.dart';
import 'admin_patient_search_models.dart';
import 'patient_search_models.dart';
import 'patient_search_repository.dart';
import 'patient_view_access.dart';

/// PatientSearchAdmin.java: both requests use the selected registration year.
class AdminPatientSearchRepository {
  const AdminPatientSearchRepository(this.appointments);
  final DoctorAppointmentRepository appointments;
  DateTime now() => appointments.now();
  PatientSearchRepository get views => PatientSearchRepository(appointments);

  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() isCurrent,
  ) {
    guardPatientViewAccess(appointments, session, profile, isCurrent);
    rxRequire(
      !profile.isDoctor,
      'Patient Search is not available for this account.',
    );
  }

  Future<List<PatientSearchRow>> patients(
    AuthSession session,
    AccountProfile profile,
    int year, {
    String? search,
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    rxRequire(
      year >= 1950 && year <= now().year,
      'Please select a valid year.',
    );
    if (search != null) {
      final error = adminPatientSearchError(search);
      rxRequire(error == null, error ?? 'Please check the search text.');
    }
    final response = await appointments.transport
        .get(
          apiEndpoint(
            session.center.baseUri,
            'patient_search/${search == null ? 'getHundredPatListNew' : 'getPatienListBySearch'}',
            {'p_year': '$year', if (search != null) 'p_name': search},
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
    rxRequire(
      response.containsKey('pat_list'),
      'The server returned an incomplete patient list.',
    );
    return List.unmodifiable(
      nativeArray(
        response['pat_list'],
      ).map((row) => PatientSearchRow({...row, 'pyear': ''})),
    );
  }
}

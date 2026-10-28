import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../appointments/doctor_schedule/doctor_appointment_repository.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import 'dynamic_clinical_repository.dart';
import 'dynamic_patient_models.dart';

/// PrescriptionPatientRepository's two GET endpoints; no patient write.
class DynamicPatientRepository {
  DynamicPatientRepository(this.appointments)
    : _clinical = DynamicClinicalRepository(appointments);
  final DoctorAppointmentRepository appointments;
  final DynamicClinicalRepository _clinical;
  Future<List<DynamicPatientItem>> load(
    AuthSession session,
    AccountProfile profile, {
    String? year,
    String? query,
    required bool Function() isCurrent,
  }) async {
    _clinical.guard(session, profile, isCurrent);
    final search = query?.trim();
    if (search == null && (year == null || year.trim().isEmpty)) {
      throw const AppFailure('Patient registration year is required');
    }
    if (search != null && search.length < 3) return const [];
    try {
      final root = await appointments.transport
          .get(
            apiEndpoint(
              session.center.baseUri,
              'dynamic_presc/${search == null ? 'getHundredPatListYearWise' : 'getPatListBySearch'}',
              search == null ? {'p_year': year!.trim()} : {'p_search': search},
            ),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout:
                () =>
                    throw const AppFailure(
                      'The server took too long to respond. Please try again.',
                      kind: FailureKind.network,
                    ),
          );
      _clinical.guard(session, profile, isCurrent);
      final rows = root['pat_list'];
      // Native optJSONArray treats absent pat_list as a valid empty list.
      if (rows is! List<Object?>) return const [];
      return List.unmodifiable(
        [
          for (final row in rows)
            if (row is Map<String, Object?>) DynamicPatientItem.fromData(row),
        ].where((item) => item.valid),
      );
    } catch (_) {
      _clinical.guard(session, profile, isCurrent);
      rethrow;
    }
  }
}

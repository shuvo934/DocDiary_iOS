import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../appointments/doctor_schedule/doctor_appointment_repository.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import 'dynamic_clinical_models.dart';
import 'dynamic_clinical_repository.dart';
import 'dynamic_rx_models.dart';

/// The six Rx GET contracts in native PrescriptionMainDataRepository.java.
class DynamicRxRepository {
  DynamicRxRepository(this.appointments)
    : _clinical = DynamicClinicalRepository(appointments);
  final DoctorAppointmentRepository appointments;
  final DynamicClinicalRepository _clinical;

  Future<List<DynamicRxOption>> _options(
    AuthSession session,
    AccountProfile profile,
    String endpoint,
    String idKey,
    String nameKey,
    bool doctorSpecific,
    bool Function() current,
  ) async {
    _clinical.guard(session, profile, current);
    try {
      final data = await appointments.transport
          .get(
            apiEndpoint(session.center.baseUri, 'dynamic_presc/$endpoint', {
              if (doctorSpecific) 'p_doc_id': profile.doctorId,
            }),
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
      _clinical.guard(session, profile, current);
      return List.unmodifiable([
        for (final row in nativeItems(data))
          if (dynamicRxText(row[nameKey]).isNotEmpty)
            DynamicRxOption(
              dynamicRxText(row[idKey]),
              dynamicRxText(row[nameKey]),
            ),
      ]);
    } catch (_) {
      _clinical.guard(session, profile, current);
      rethrow;
    }
  }

  Future<DynamicRxCatalogue> load(
    AuthSession session,
    AccountProfile profile, {
    required bool Function() isCurrent,
  }) async {
    _clinical.guard(session, profile, isCurrent);
    final values = await Future.wait([
      _options(
        session,
        profile,
        'getMedicine',
        'medicine_id',
        'medicine_name',
        false,
        isCurrent,
      ),
      _options(
        session,
        profile,
        'getDoses',
        'dose_id',
        'dose_name',
        false,
        isCurrent,
      ),
      _options(
        session,
        profile,
        'getMedicineTiming',
        'timing_id',
        'timing_name',
        false,
        isCurrent,
      ),
      _options(
        session,
        profile,
        'getMedicineRoute',
        'route_id',
        'route_name',
        false,
        isCurrent,
      ),
      _options(
        session,
        profile,
        'getTherapy',
        'tm_id',
        'tm_name',
        true,
        isCurrent,
      ),
      _options(
        session,
        profile,
        'getTreatmentPlan',
        'tpm_id',
        'tpm_treatment_plan_name',
        true,
        isCurrent,
      ),
    ]);
    _clinical.guard(session, profile, isCurrent);
    return DynamicRxCatalogue(
      medicines: values[0],
      doses: values[1],
      timings: values[2],
      routes: values[3],
      therapies: values[4],
      treatmentPlans: values[5],
    );
  }
}

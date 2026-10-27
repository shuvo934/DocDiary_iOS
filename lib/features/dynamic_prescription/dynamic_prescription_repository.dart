import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../appointments/doctor_schedule/doctor_appointment_repository.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import 'dynamic_clinical_models.dart';
import 'dynamic_clinical_repository.dart';
import 'dynamic_prescription_seed.dart';
import 'dynamic_rx_repository.dart';
import 'dynamic_advice_repository.dart';

/// Scheduled Clinical/Rx/Advice entry point. This stage has only GET calls.
class DynamicPrescriptionRepository {
  DynamicPrescriptionRepository(this.appointments)
    : clinical = DynamicClinicalRepository(appointments),
      rx = DynamicRxRepository(appointments),
      advice = DynamicAdviceRepository(appointments);
  final DoctorAppointmentRepository appointments;
  final DynamicClinicalRepository clinical;
  final DynamicRxRepository rx;
  final DynamicAdviceRepository advice;

  void guard(
    AuthSession session,
    AccountProfile profile,
    DynamicPrescriptionSeed seed,
    bool Function() current,
  ) {
    clinical.guard(session, profile, current);
    if (!seed.valid ||
        seed.ownerDoctorId != profile.doctorId ||
        !seed.editableOn(appointments.now())) {
      throw const AppFailure(
        'Prescription editing is available for today’s scheduled appointment only.',
        kind: FailureKind.invalidData,
      );
    }
  }

  Future<JsonMap> _get(
    AuthSession session,
    AccountProfile profile,
    DynamicPrescriptionSeed seed,
    String endpoint,
    Map<String, String> query,
    bool Function() current,
  ) async {
    guard(session, profile, seed, current);
    try {
      final result = await appointments.transport
          .get(
            apiEndpoint(
              session.center.baseUri,
              'dynamic_presc/$endpoint',
              query,
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
      guard(session, profile, seed, current);
      return result;
    } catch (_) {
      guard(session, profile, seed, current);
      rethrow;
    }
  }

  Future<JsonMap> existing(
    AuthSession session,
    AccountProfile profile,
    DynamicPrescriptionSeed seed, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, seed, isCurrent);
    if (!seed.existing) return const {};
    final root = await _get(session, profile, seed, 'getPrescription', {
      'p_ph_id': seed.patientHistoryId,
      'p_pat_id': seed.patientId,
      'p_ad_id': seed.appointmentId,
    }, isCurrent);
    if (dynamicRxText(root['status']) != '200' || root['data'] == null) {
      throw AppFailure(
        dynamicRxText(root['message']).isEmpty
            ? 'Prescription could not be loaded'
            : dynamicRxText(root['message']),
      );
    }
    final data = nativeObject(root['data']);
    if (dynamicRxText(data['rvm_id']).isEmpty) {
      throw const AppFailure(
        'Prescription ID not found',
        kind: FailureKind.invalidData,
      );
    }
    return data;
  }

  Future<JsonMap> patientDetails(
    AuthSession session,
    AccountProfile profile,
    DynamicPrescriptionSeed seed, {
    required bool Function() isCurrent,
  }) async {
    final root = await _get(session, profile, seed, 'getPatDetails', {
      'p_ph_id': seed.patientHistoryId,
    }, isCurrent);
    final items = nativeItems(root);
    if (items.isEmpty) throw const AppFailure('Patient details not found');
    return items.first;
  }
}

import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../patient_search/patient_view_access.dart';
import 'dynamic_prescription_repository.dart';
import 'dynamic_prescription_preview_models.dart';

/// Native getPreviewData: fresh GET, 30 seconds, no automatic retry or write.
class DynamicPrescriptionPreviewRepository {
  const DynamicPrescriptionPreviewRepository(this.prescriptions);
  final DynamicPrescriptionRepository prescriptions;

  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() isCurrent,
  ) {
    if (profile.isDoctor) {
      prescriptions.clinical.guard(session, profile, isCurrent);
      return;
    }
    guardPatientViewAccess(
      prescriptions.appointments,
      session,
      profile,
      isCurrent,
    );
    if (profile.value('presc_active') != '1') {
      throw const AppFailure(
        'Dynamic prescription is not available for this account.',
        kind: FailureKind.denied,
      );
    }
  }

  Future<DynamicPrescriptionPreviewData> load(
    AuthSession session,
    AccountProfile profile,
    String rvmId, {
    required bool Function() isCurrent,
  }) async {
    void check() => guard(session, profile, isCurrent);
    check();
    final id = rvmId.trim();
    if (id.isEmpty) {
      throw const AppFailure('Prescription ID was not provided.');
    }
    try {
      final response = await prescriptions.appointments.transport
          .get(
            apiEndpoint(
              session.center.baseUri,
              'dynamic_presc/getPreviewData',
              {'p_rvm_id': id},
            ),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout:
                () =>
                    throw const AppFailure(
                      'Prescription preview failed to load. Please check your network and try again.',
                      kind: FailureKind.network,
                    ),
          );
      check();
      final data = DynamicPrescriptionPreviewData.fromResponse(response);
      if (data.rvmId != id) {
        throw const AppFailure(
          'Prescription preview identity does not match the selected prescription.',
          kind: FailureKind.invalidData,
        );
      }
      return data;
    } catch (_) {
      check();
      rethrow;
    }
  }
}

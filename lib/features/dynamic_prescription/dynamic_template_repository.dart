import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../appointments/doctor_schedule/doctor_appointment_repository.dart';
import 'dynamic_clinical_models.dart';
import 'dynamic_clinical_repository.dart';
import 'dynamic_template_models.dart';

/// The four native template GET endpoints. No prescription write occurs here.
class DynamicTemplateRepository {
  DynamicTemplateRepository(this.appointments)
    : _clinical = DynamicClinicalRepository(appointments);
  final DoctorAppointmentRepository appointments;
  final DynamicClinicalRepository _clinical;

  Future<JsonMap> _get(
    AuthSession session,
    AccountProfile profile,
    String endpoint,
    Map<String, String> query,
    bool Function() current,
  ) async {
    _clinical.guard(session, profile, current);
    try {
      final root = await appointments.transport
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
      _clinical.guard(session, profile, current);
      return root;
    } catch (_) {
      _clinical.guard(session, profile, current);
      rethrow;
    }
  }

  Future<List<DynamicTemplateOption>> options(
    AuthSession session,
    AccountProfile profile, {
    String? diseaseId,
    required bool Function() isCurrent,
  }) async {
    final treatment = diseaseId != null;
    if (treatment && diseaseId.trim().isEmpty) {
      throw const AppFailure('Disease Template information not found');
    }
    final root = await _get(
      session,
      profile,
      treatment ? 'getTreatmentTemplate' : 'getDiseaseTemplate',
      {
        'p_doc_id': profile.doctorId,
        if (treatment) 'p_td_id': diseaseId.trim(),
      },
      isCurrent,
    );
    if (root['items'] == null) {
      throw const AppFailure('Template list not found');
    }
    final items = root['items'];
    if (items is! List<Object?>) {
      throw const AppFailure(
        'Template list not found',
        kind: FailureKind.invalidData,
      );
    }
    final prefix = treatment ? 'tt' : 'td';
    return List.unmodifiable([
      for (final item in items)
        if (item is Map<String, Object?>)
          if (dynamicRxText(item['${prefix}_id']).isNotEmpty &&
              dynamicRxText(item['${prefix}_name']).isNotEmpty)
            DynamicTemplateOption(
              dynamicRxText(item['${prefix}_id']),
              dynamicRxText(item['${prefix}_name']),
              dynamicRxText(item['${prefix}_description']),
            ),
    ]);
  }

  Future<JsonMap> data(
    AuthSession session,
    AccountProfile profile,
    DynamicTemplateKind kind,
    String id, {
    required bool Function() isCurrent,
  }) async {
    if (id.trim().isEmpty) {
      throw AppFailure('${kind.label} information not found');
    }
    final disease = kind == DynamicTemplateKind.disease;
    final root = await _get(
      session,
      profile,
      disease ? 'loadDiseaseTemplate' : 'loadTreatmentTemplate',
      {disease ? 'p_td_id' : 'p_tt_id': id.trim()},
      isCurrent,
    );
    final fallback = '${kind.label} could not be loaded';
    if (dynamicRxText(root['status']) != '200' ||
        root['data'] is! Map<String, Object?>) {
      throw AppFailure(
        dynamicRxText(root['message']).isEmpty
            ? fallback
            : dynamicRxText(root['message']),
      );
    }
    return nativeObject(root['data']);
  }
}

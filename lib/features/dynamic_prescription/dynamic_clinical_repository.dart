import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../appointments/doctor_schedule/doctor_appointment_models.dart';
import '../appointments/doctor_schedule/doctor_appointment_repository.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import 'dynamic_clinical_models.dart';

/// GET contracts copied from native PrescriptionMainDataRepository.java.
/// Shared with the future builder; this phase has no POST endpoint.
class DynamicClinicalRepository {
  DynamicClinicalRepository(this.appointments);
  final DoctorAppointmentRepository appointments;

  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() current,
  ) {
    appointments.guard(session, profile, current);
    if (!DoctorAppointmentFeatures(profile).dynamicPrescription) {
      throw const AppFailure(
        'Dynamic prescription is not available for this account.',
        kind: FailureKind.denied,
      );
    }
  }

  Future<List<DynamicRxOption>> _options(
    AuthSession session,
    AccountProfile profile,
    String endpoint,
    String idKey,
    String nameKey,
    String noteKey,
    Map<String, String> query,
    bool Function() current,
  ) async {
    guard(session, profile, current);
    final data = await appointments.transport
        .get(
          apiEndpoint(session.center.baseUri, 'dynamic_presc/$endpoint', query),
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
    guard(session, profile, current);
    final rows = nativeItems(data);
    return List.unmodifiable([
      for (final row in rows)
        if (dynamicRxText(row[nameKey]).isNotEmpty)
          DynamicRxOption(
            dynamicRxText(row[idKey]),
            dynamicRxText(row[nameKey]),
            noteKey.isEmpty ? '' : dynamicRxText(row[noteKey]),
          ),
    ]);
  }

  Future<DynamicClinicalCatalogue> load(
    AuthSession session,
    AccountProfile profile, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    final types =
        DynamicClinicalType.values.where((type) => type.hasOptions).toList();
    final values = await Future.wait([
      for (final type in types)
        _options(
          session,
          profile,
          type.endpoint,
          type.idKey,
          type.nameKey,
          type.noteKey,
          {if (type.doctorSpecific) 'p_doc_id': profile.doctorId},
          isCurrent,
        ),
      _options(session, profile, 'getObjective', 'om_id', 'om_name', '', {
        'p_doc_id': profile.doctorId,
      }, isCurrent),
      _options(
        session,
        profile,
        'getMuscleJoint',
        'mjl_id',
        'mjl_name',
        '',
        const {},
        isCurrent,
      ),
    ]);
    guard(session, profile, isCurrent);
    return DynamicClinicalCatalogue(
      clinical: {for (var i = 0; i < types.length; i++) types[i]: values[i]},
      objectives: values[types.length],
      muscleJoints: values[types.length + 1],
    );
  }

  Future<List<DynamicRxOption>> objectiveValues(
    AuthSession session,
    AccountProfile profile,
    String objectiveId, {
    required bool Function() isCurrent,
  }) {
    guard(session, profile, isCurrent);
    if (objectiveId.trim().isEmpty) return Future.value(const []);
    return _options(
      session,
      profile,
      'getObjectiveValue',
      'od_id',
      'od_name',
      '',
      {'p_om_id': objectiveId, 'p_doc_id': profile.doctorId},
      isCurrent,
    );
  }
}

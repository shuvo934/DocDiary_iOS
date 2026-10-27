import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../appointments/doctor_schedule/doctor_appointment_repository.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import 'dynamic_advice_models.dart';
import 'dynamic_clinical_models.dart';
import 'dynamic_clinical_repository.dart';

/// Native getAdvice/getFollowUp/getSpecialAlert GET contracts.
class DynamicAdviceRepository {
  DynamicAdviceRepository(this.appointments)
    : _clinical = DynamicClinicalRepository(appointments);
  final DoctorAppointmentRepository appointments;
  final DynamicClinicalRepository _clinical;
  Future<List<DynamicRxOption>> _options(
    AuthSession session,
    AccountProfile profile,
    DynamicAdviceType type,
    bool Function() current,
  ) async {
    _clinical.guard(session, profile, current);
    try {
      final data = await appointments.transport
          .get(
            apiEndpoint(
              session.center.baseUri,
              'dynamic_presc/${type.endpoint}',
              {'p_doc_id': profile.doctorId},
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
      return List.unmodifiable([
        for (final row in nativeItems(data))
          if (dynamicRxText(row[type.nameKey]).isNotEmpty)
            DynamicRxOption(
              dynamicRxText(row[type.idKey]),
              dynamicRxText(row[type.nameKey]),
            ),
      ]);
    } catch (_) {
      _clinical.guard(session, profile, current);
      rethrow;
    }
  }

  Future<DynamicAdviceCatalogue> load(
    AuthSession session,
    AccountProfile profile, {
    required bool Function() isCurrent,
  }) async {
    _clinical.guard(session, profile, isCurrent);
    final types =
        DynamicAdviceType.values.where((type) => type.hasOptions).toList();
    final values = await Future.wait([
      for (final type in types) _options(session, profile, type, isCurrent),
    ]);
    _clinical.guard(session, profile, isCurrent);
    return DynamicAdviceCatalogue(
      values: {for (var i = 0; i < types.length; i++) types[i]: values[i]},
    );
  }
}

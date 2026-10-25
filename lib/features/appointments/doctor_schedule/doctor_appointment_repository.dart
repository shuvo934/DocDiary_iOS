import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../../core/native_json.dart';
import '../../../core/transport.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import 'doctor_appointment_models.dart';

class DoctorAppointmentRepository {
  DoctorAppointmentRepository(this.transport, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Transport transport;
  final DateTime Function() now;
  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() current,
  ) {
    if (!current()) throw const ObsoleteRequest();
    if (!profile.isDoctor ||
        session.account.role != AccountRole.doctor ||
        profile.doctorId.isEmpty ||
        profile.value('doc_code') != session.account.doctorCode) {
      throw const AppFailure(
        'Could Not Get Doctor Data. Please return to Login.',
        kind: FailureKind.invalidData,
      );
    }
    ProfileRepository.checkAccess(profile, now());
  }

  Future<List<DoctorAppointmentRow>> load(
    AuthSession session,
    AccountProfile profile,
    DoctorAppointmentWindow window,
    DateTime selected, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    if (!window.contains(selected)) {
      throw const AppFailure(
        'This date is outside the appointment calendar.',
        kind: FailureKind.invalidData,
      );
    }
    final flags = DoctorAppointmentFeatures(profile);
    final endpoint =
        flags.dynamicPrescription
            ? 'getAppointmentDataNew'
            : 'getAppointmentData';
    final response = await transport.get(
      apiEndpoint(session.center.baseUri, 'appointment_schedule/$endpoint', {
        'doc_id': profile.doctorId,
        'pdate': oracleDate(selected),
      }),
    );
    guard(session, profile, isCurrent);
    final count = int.tryParse(nativeText(response['count']).trim());
    if (count == null || count < 0) {
      throw AppFailure(
        'The server returned an invalid count for $endpoint.',
        kind: FailureKind.invalidData,
      );
    }
    if (count == 0) return const [];
    List<JsonMap> rows;
    try {
      rows = nativeItems(response);
      if (rows.isEmpty) throw const AppFailure('Empty appointment list');
    } on AppFailure {
      throw AppFailure(
        'The server returned an invalid list for $endpoint.',
        kind: FailureKind.invalidData,
      );
    }
    // Keep native returned order and repeated IDs, including blank/block slots.
    return List.unmodifiable(
      rows.map(
        (r) => DoctorAppointmentRow(r, selectedDate: dateOnly(selected)),
      ),
    );
  }
}

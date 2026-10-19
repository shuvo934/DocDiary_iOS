import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../../core/transport.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import 'doctor_block_time_models.dart';

class DoctorBlockTimeRepository {
  DoctorBlockTimeRepository(this.transport, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Transport transport;
  final DateTime Function() now;
  Future<DoctorBlockCalendar> load(
    AuthSession session,
    AccountProfile profile,
    DoctorBlockWindow window, {
    required bool Function() isCurrent,
  }) async {
    void guard() {
      if (!isCurrent()) {
        throw const ObsoleteRequest();
      }
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

    guard();
    final root = await transport.get(
      apiEndpoint(session.center.baseUri, 'leave_schedule/getTimeSchedule', {
        'doc_id': profile.doctorId,
        'FIRST_MONTH': window.firstMonth,
        'LAST_MONTH': window.lastMonth,
      }),
    );
    guard();
    final count = int.tryParse(nativeText(root['count']).trim());
    if (count == null || count < 0 || (count > 0 && root['items'] == null)) {
      throw const AppFailure(
        'The server returned incomplete blocked schedule data.',
        kind: FailureKind.invalidData,
      );
    }
    final rows = count == 0 ? <JsonMap>[] : nativeItems(root);
    if (count > 0 && rows.isEmpty) {
      throw const AppFailure(
        'The server returned incomplete blocked schedule data.',
        kind: FailureKind.invalidData,
      );
    }
    return DoctorBlockCalendar(
      window,
      rows.map(DoctorBlockedSlot.fromJson).toList(growable: false),
    );
  }
}

import 'dart:typed_data';

import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../../core/transport.dart';
import '../auth/account_access.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';

class DashboardPhotoRepository {
  DashboardPhotoRepository(this.transport, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Transport transport;
  final DateTime Function() now;

  /// One explicit upload attempt. A failed/uncertain POST is never retried here.
  Future<void> upload(
    AuthSession session,
    AccountProfile profile,
    Uint8List jpeg, {
    required bool Function() isCurrent,
    required bool Function() isForeground,
  }) async {
    void guard() {
      if (!isCurrent() || !isForeground()) {
        throw const ObsoleteRequest();
      }
    }

    guard();
    if (profile.isDoctor || session.account.role != profile.role) {
      throw const AppFailure(
        'Only an admin can change a picture from Dashboard.',
        kind: FailureKind.invalidData,
      );
    }
    ProfileRepository.checkAccess(profile, now());
    if (jpeg.length < 4 ||
        jpeg[0] != 0xff ||
        jpeg[1] != 0xd8 ||
        jpeg[jpeg.length - 2] != 0xff ||
        jpeg.last != 0xd9 ||
        jpeg.length > 1024 * 1024) {
      throw const AppFailure(
        'Invalid image. Please choose another picture.',
        kind: FailureKind.invalidData,
      );
    }
    final writer = transport;
    if (writer is! BinaryTransport) {
      throw const AppFailure('Picture upload is unavailable in this build.');
    }
    final flag = await transport.get(
      apiEndpoint(session.center.baseUri, 'doc_dashboard/getAdminFLFlag', {
        'p_usr_id': session.account.adminId,
      }),
    );
    guard();
    final flags =
        nativeText(flag['count']) == '0' ? <JsonMap>[] : nativeItems(flag);
    if (flags.isEmpty ||
        !flags.first.containsKey('fl_flag') ||
        !const ['0', '1'].contains(nativeText(flags.first['fl_flag'], '0'))) {
      throw const AppFailure(
        'Account access could not be verified. Please try again.',
      );
    }
    if (nativeText(flags.first['fl_flag']) == '1') {
      throw const AccountAccessFailure.forcedLogout();
    }
    ProfileRepository.checkAccess(profile, now());
    guard();
    final response = await writer.postBytes(
      apiEndpoint(session.center.baseUri, 'doc_dashboard/updateAdminPic'),
      jpeg,
      headers: {'p_user_id': profile.value('usr_id', session.account.adminId)},
    );
    // A background transition after dispatch must not turn success into an
    // automatic second POST. The caller waits for resume before committing UI.
    if (!isCurrent()) {
      throw const ObsoleteRequest();
    }
    final result = nativeText(response['string_out']);
    if (result != 'Successfully Created') {
      throw AppFailure(result.isEmpty ? 'Picture upload failed.' : result);
    }
  }
}

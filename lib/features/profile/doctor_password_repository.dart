import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../../core/transport.dart';
import '../auth/account_access.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';

enum DoctorPasswordField { current, newPassword, confirm }

class DoctorPasswordProblem {
  const DoctorPasswordProblem(this.field, this.helper, [String? notice])
    : notice = notice ?? helper;
  final DoctorPasswordField field;
  final String helper, notice;
}

class DoctorPasswordChange {
  const DoctorPasswordChange({
    required this.current,
    required this.next,
    required this.confirm,
  });
  final String current, next, confirm;

  static const invalidCharacters =
      'Invalid Character! Blank space, Quotation or New line is not allowed';
  static bool _invalid(String value) =>
      value.contains(' ') ||
      value.contains("'") ||
      value.contains('"') ||
      value.codeUnits.any((code) => code < 32 || code == 127);

  DoctorPasswordProblem? validate(String savedPassword) {
    if (current.isEmpty) {
      return const DoctorPasswordProblem(
        DoctorPasswordField.current,
        'Please Provide Current Password',
      );
    }
    if (current != savedPassword) {
      return const DoctorPasswordProblem(
        DoctorPasswordField.current,
        'Current Password is Wrong',
      );
    }
    if (next.isEmpty) {
      return const DoctorPasswordProblem(
        DoctorPasswordField.newPassword,
        'Please Provide New Password',
        'Please Provide New Password to Update',
      );
    }
    if (_invalid(next)) {
      return const DoctorPasswordProblem(
        DoctorPasswordField.newPassword,
        invalidCharacters,
      );
    }
    if (next == current) {
      return const DoctorPasswordProblem(
        DoctorPasswordField.newPassword,
        'New Password is matched with Current Password.',
      );
    }
    if (confirm.isEmpty) {
      return const DoctorPasswordProblem(
        DoctorPasswordField.confirm,
        'Please Provide Confirm Password',
        'Please Provide Confirm Password to Update',
      );
    }
    if (_invalid(confirm)) {
      return const DoctorPasswordProblem(
        DoctorPasswordField.confirm,
        invalidCharacters,
      );
    }
    if (confirm != next) {
      return const DoctorPasswordProblem(
        DoctorPasswordField.confirm,
        'Confirm Password did not match',
      );
    }
    return null;
  }

  @override
  String toString() => 'DoctorPasswordChange(<redacted>)';
}

class DoctorPasswordRepository {
  DoctorPasswordRepository(this.transport, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Transport transport;
  final DateTime Function() now;

  Future<void> update(
    AuthSession session,
    AccountProfile profile,
    DoctorPasswordChange change, {
    required bool Function() isCurrent,
    required bool Function() isForeground,
  }) async {
    void guard() {
      if (!isCurrent() || !isForeground()) {
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
    final problem = change.validate(session.credentials.password);
    if (problem != null) {
      throw AppFailure(problem.helper, kind: FailureKind.invalidData);
    }
    final flag = await transport.get(
      apiEndpoint(session.center.baseUri, 'doc_dashboard/getDocFLFlag', {
        'p_doc_id': profile.doctorId,
      }),
    );
    guard();
    final rows =
        nativeText(flag['count']) == '0' ? <JsonMap>[] : nativeItems(flag);
    if (rows.isEmpty ||
        !const ['0', '1'].contains(nativeText(rows.first['fl_flag']))) {
      throw const AppFailure(
        'Account access could not be verified. Please try again.',
      );
    }
    if (nativeText(rows.first['fl_flag']) == '1') {
      throw const AccountAccessFailure.forcedLogout();
    }
    guard();
    final response = await transport.post(
      apiEndpoint(session.center.baseUri, 'doc_profile/updatePassword'),
      headers: {'P_DOC_ID': profile.doctorId, 'P_PASS': change.confirm},
    );
    // A successful reply in the background completes this same POST once.
    if (!isCurrent()) {
      throw const ObsoleteRequest();
    }
    final result = nativeText(response['string_out']);
    if (result != 'Successfully Created') {
      throw AppFailure(result.isEmpty ? 'Password update failed.' : result);
    }
  }
}

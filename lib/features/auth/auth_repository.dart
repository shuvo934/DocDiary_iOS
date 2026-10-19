import '../../config/server_directory.dart';
import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../../core/transport.dart';
import 'auth_models.dart';

class DiscoveryResult {
  const DiscoveryResult(this.centers, {required this.failedServerCount});
  final List<CenterOption> centers;
  final int failedServerCount;
}

class AuthRepository {
  AuthRepository(this.transport, this.directory);
  final Transport transport;
  final ServerDirectory directory;

  Future<DiscoveryResult> discover(Credentials credentials) async {
    final centers = <CenterOption>[];
    var failures = 0;
    var receivedResponse = false;
    var serverIssue = false;
    var lastMessage = '';
    for (final base in await directory.load()) {
      try {
        final response = await transport.get(
          apiEndpoint(base, 'login/getAllLoginData', {
            'doc_code': credentials.mobile,
            'doc_password': credentials.password,
          }),
        );
        receivedResponse = true;
        final center = CenterOption.fromLoginResponse(response);
        if (center != null) {
          centers.add(center);
        } else {
          final message = nativeText(response['is_online']);
          // Keep the previous useful business message like native prv_message.
          // A bare Online status is not a reason to show an empty account list.
          if (message.isNotEmpty && message.trim().toLowerCase() != 'online') {
            lastMessage = message;
          }
        }
      } on AppFailure catch (failure) {
        failures++;
        serverIssue = serverIssue || failure.kind != FailureKind.network;
      }
    }
    if (centers.isEmpty) {
      if (lastMessage.isNotEmpty) {
        // A later timeout or malformed reply must not erase a native message.
        throw AppFailure(lastMessage, kind: FailureKind.denied);
      }
      if (receivedResponse && failures == 0) {
        throw const AppFailure(
          'Could not find your id.',
          kind: FailureKind.denied,
        );
      }
      // No account result is conclusive only when every centre was checked.
      // Keep the native retry messages for incomplete/malformed discovery.
      final apiIssue = receivedResponse || serverIssue;
      throw AppFailure(
        apiIssue
            ? 'There is a network issue in the server. Please Try later.'
            : 'Server Problem or Internet Not Connected',
        kind: apiIssue ? FailureKind.server : FailureKind.network,
      );
    }
    return DiscoveryResult(
      List.unmodifiable(centers),
      failedServerCount: failures,
    );
  }

  Future<void> resetFirstLoginFlag(
    CenterOption center,
    AccountOption account,
  ) async {
    final doctor = account.role == AccountRole.doctor;
    final response = await transport.post(
      apiEndpoint(
        center.baseUri,
        doctor ? 'login/updateFLFlag' : 'login/updateAdminFLFlag',
      ),
      headers:
          doctor
              ? {'P_DOC_CODE': account.doctorCode}
              : {'P_USR_ID': account.adminId},
    );
    if (nativeText(response['string_out']) != 'Successfully Created') {
      throw const AppFailure(
        'The sign-in could not be completed. Please try again.',
      );
    }
  }
}

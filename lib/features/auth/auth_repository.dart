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
    var lastMessage = '';
    for (final base in await directory.load()) {
      try {
        final response = await transport.get(
          apiEndpoint(base, 'login/getAllLoginData', {
            'doc_code': credentials.mobile,
            'doc_password': credentials.password,
          }),
        );
        final center = CenterOption.fromLoginResponse(response);
        receivedResponse = true;
        if (center != null) {
          centers.add(center);
        } else {
          final message = nativeText(response['is_online']);
          if (message.isNotEmpty) lastMessage = message;
        }
      } on AppFailure {
        failures++;
      }
    }
    if (centers.isEmpty) {
      throw AppFailure(
        lastMessage.isNotEmpty
            ? lastMessage
            : receivedResponse
            ? 'No account was found for this Mobile No and Password.'
            : 'Server Problem or Internet Not Connected',
        kind: receivedResponse ? FailureKind.denied : FailureKind.network,
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

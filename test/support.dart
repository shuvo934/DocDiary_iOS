import 'dart:typed_data';

import 'package:docdiary_ios/config/server_directory.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/core/transport.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/auth_repository.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/auth/session_vault.dart';

class RequestRecord {
  const RequestRecord(this.method, this.uri, this.headers);
  final String method;
  final Uri uri;
  final Map<String, String> headers;
}

class BinaryRequestRecord {
  const BinaryRequestRecord(
    this.uri,
    this.body,
    this.headers,
    this.contentType,
  );
  final Uri uri;
  final Uint8List body;
  final Map<String, String> headers;
  final String contentType;
}

class FakeTransport implements Transport, BinaryTransport {
  Future<String> Function(Uri)? onText;
  Future<JsonMap> Function(Uri)? onGet;
  Future<JsonMap> Function(Uri, Map<String, String>)? onPost;
  Future<JsonMap> Function(BinaryRequestRecord)? onBytes;
  final binaryRequests = <BinaryRequestRecord>[];
  final requests = <RequestRecord>[];

  @override
  Future<JsonMap> postBytes(
    Uri uri,
    Uint8List body, {
    Map<String, String> headers = const {},
    String contentType = 'application/binary',
  }) async {
    final request = BinaryRequestRecord(
      uri,
      Uint8List.fromList(body),
      Map.of(headers),
      contentType,
    );
    binaryRequests.add(request);
    return onBytes == null
        ? {'string_out': 'Successfully Created'}
        : await onBytes!(request);
  }

  @override
  Future<String> getText(Uri uri) async {
    requests.add(RequestRecord('TEXT', uri, const {}));
    return onText == null
        ? 'https://centre.example/api/\n'
        : await onText!(uri);
  }

  @override
  Future<JsonMap> get(Uri uri) async {
    requests.add(RequestRecord('GET', uri, const {}));
    if (onGet != null) {
      return onGet!(uri);
    }
    throw StateError('No fake GET response configured');
  }

  @override
  Future<JsonMap> post(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    requests.add(RequestRecord('POST', uri, Map.of(headers)));
    return onPost == null
        ? {'string_out': 'Successfully Created'}
        : await onPost!(uri, headers);
  }

  @override
  void close() {}
}

class MemoryVault implements SessionVault, PasswordChangeVault {
  VaultState state = const VaultState();
  bool failSave = false;
  bool failClear = false;
  bool failPasswordChange = false;
  int passwordChanges = 0;
  Future<void> Function()? onPasswordChange;
  int saves = 0;
  int clears = 0;

  @override
  Future<VaultState> load() async => state;

  @override
  Future<void> saveSession(AuthSession session) async {
    if (failSave) {
      throw const AppFailure(
        'Secure storage unavailable.',
        kind: FailureKind.storage,
      );
    }
    saves++;
    state = VaultState(
      session: session,
      remembered: session.remember ? session.credentials : null,
    );
  }

  @override
  Future<void> clearSession() async {
    if (failClear) {
      throw const AppFailure(
        'Secure storage could not be cleared.',
        kind: FailureKind.storage,
      );
    }
    clears++;
    state = VaultState(remembered: state.remembered);
  }

  @override
  Future<void> savePasswordChange(Credentials? remembered) async {
    passwordChanges++;
    if (onPasswordChange != null) {
      await onPasswordChange!();
    }
    if (failPasswordChange) {
      throw const AppFailure(
        'Secure storage unavailable.',
        kind: FailureKind.storage,
      );
    }
    state = VaultState(remembered: remembered);
  }
}

JsonMap doctorLogin({String base = 'https://centre.example/api/'}) => {
  'is_online': 'Online',
  'is_available': '1',
  'p_doc_code': 'D-10',
  'p_center_api': base,
  'p_admin_user_flag': '1',
  'p_admin_user_id': null,
  'p_center_name': 'Example Rehabilitation Centre',
};

JsonMap adminLogin() => {
  'is_online': 'Online',
  'is_available': '1',
  'p_doc_code': null,
  'p_center_api': 'https://centre.example/api/',
  'p_admin_user_flag': '2',
  'p_admin_user_id': '70',
  'p_center_name': 'Example Rehabilitation Centre',
};

JsonMap doctorProfile() => {
  'user_avail': '1',
  'doc_code': 'D-10',
  'doc_id': '10',
  'doc_name': 'Example Therapist',
  'doc_center_name': 'Example Rehabilitation Centre',
  'fl_flag': '0',
  'access_flag': '1',
  'doc_app_first_login_flag': '1',
  'exp_date': '15-JAN-27',
  'presc_active': '1',
  'can_prescribe': '1',
};

JsonMap adminProfile() => {
  'usr_name': 'example.admin',
  'usr_fname': 'Example',
  'usr_lname': 'Admin',
  'admin_center_name': 'Example Rehabilitation Centre',
  'usr_mob_app_access': '1',
  'usr_mob_forced_log_out_flag': '0',
  'usr_app_first_login_flag': '1',
  'all_access_flag': '0',
  'exp_date': '15-JAN-27',
};

class Harness {
  Harness({DateTime? clock}) {
    now = clock ?? DateTime(2026, 10, 15, 13, 30);
    transport.onGet = defaultGet;
    profiles = ProfileRepository(
      transport,
      now: () => now,
      describeClient: () async => const ClientDescriptor(),
    );
    auth = AuthController(
      repository: AuthRepository(transport, ServerDirectory(transport)),
      profiles: profiles,
      vault: vault,
    );
  }

  final transport = FakeTransport();
  final vault = MemoryVault();
  late final ProfileRepository profiles;
  late final AuthController auth;
  late DateTime now;
  JsonMap loginResponse = doctorLogin();
  JsonMap doctorData = doctorProfile();
  JsonMap adminData = adminProfile();

  Future<JsonMap> defaultGet(Uri uri) async {
    if (uri.path.endsWith('getAllLoginData')) {
      return loginResponse;
    }
    if (uri.path.endsWith('getDocData')) {
      return {
        'count': 1,
        'items': [doctorData],
      };
    }
    if (uri.path.endsWith('getAdminData')) {
      return {
        'count': '1',
        'items': [adminData],
      };
    }
    if (uri.path.endsWith('getDocFLFlag') ||
        uri.path.endsWith('getAdminFLFlag')) {
      return {
        'count': 1,
        'items': [
          {'fl_flag': '0'},
        ],
      };
    }
    if (uri.path.endsWith('getMeetingCount')) {
      return {'count': 0, 'items': <Object?>[]};
    }
    if (uri.path.endsWith('getScheduleCount')) {
      return {
        'count': 1,
        'items': [
          {'schedule': '8', 'block_schedule': '2'},
        ],
      };
    }
    if (uri.path.endsWith('getMeetingSchedule')) {
      return {'count': 0, 'items': <Object?>[]};
    }
    if (uri.path.endsWith('getDocPic') || uri.path.endsWith('getAdminPic')) {
      return {'count': 0, 'items': <Object?>[]};
    }
    if (uri.path.endsWith('getAdminAppPayCountNew')) {
      return {
        'total_app_count': '12',
        'cancel_app_count': '2',
        'total_pay_rcv': '1200.50',
        'total_pay_rtn': '100.25',
      };
    }
    // Admin overview fixtures: live main.dart never uses this fake transport.
    if (RegExp(
      r'get(?:Payment|Appoint)Data(?:Offline|Online)?(?:Monthly|Yearly)$',
    ).hasMatch(uri.path)) {
      return {'count': 0, 'items': <Object?>[]};
    }
    throw StateError('Unexpected fake request');
  }

  List<RequestRecord> get posts =>
      transport.requests.where((e) => e.method == 'POST').toList();
  Future<void> signIn({bool remember = false}) async {
    if (auth.stage == AuthStage.booting) {
      await auth.initialize();
    }
    await auth.login('01700000000', 'test-only-password', remember: remember);
  }
}

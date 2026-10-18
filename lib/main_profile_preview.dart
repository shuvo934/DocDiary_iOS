import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'config/server_directory.dart';
import 'core/app_theme.dart';
import 'core/failure.dart';
import 'core/native_json.dart';
import 'core/transport.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_models.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/profile_repository.dart';
import 'features/auth/session_vault.dart';
import 'features/profile/doctor_profile_repository.dart';
import 'features/profile/doctor_profile_screen.dart';

/// Offline API/Keychain fixtures. Camera/gallery still use real iOS plugins.
/// PROFILE_PREVIEW: normal, empty, retry, upload_retry, video, long.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const mode = String.fromEnvironment(
    'PROFILE_PREVIEW',
    defaultValue: 'normal',
  );
  final transport = _PreviewTransport(mode);
  const account = AccountOption(
    role: AccountRole.doctor,
    doctorCode: 'D-10',
    doctorName: 'Example Therapist',
    department: 'Physiotherapy',
  );
  final center = CenterOption(
    name: 'Example Rehabilitation Centre',
    baseUri: Uri.parse('https://profile.preview.invalid/api/'),
    accounts: const [account],
    requiresAccountChoice: false,
  );
  final session = AuthSession(
    credentials: const Credentials('00000000000', 'preview-only'),
    center: center,
    account: account,
    centers: [center],
    remember: false,
  );
  final auth =
      AuthController(
          repository: AuthRepository(transport, ServerDirectory(transport)),
          profiles: ProfileRepository(
            transport,
            describeClient: () async => const ClientDescriptor(),
          ),
          vault: _PreviewVault(),
        )
        ..session = session
        ..profile = AccountProfile(AccountRole.doctor, transport.doctor)
        ..stage = AuthStage.authenticated;
  runApp(_ProfilePreview(auth: auth, transport: transport));
}

class _ProfilePreview extends StatefulWidget {
  const _ProfilePreview({required this.auth, required this.transport});
  final AuthController auth;
  final _PreviewTransport transport;
  @override
  State<_ProfilePreview> createState() => _ProfilePreviewState();
}

class _ProfilePreviewState extends State<_ProfilePreview> {
  @override
  void dispose() {
    widget.auth.dispose();
    widget.transport.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: docDiaryTheme(),
    home: _LaunchProfile(auth: widget.auth, transport: widget.transport),
  );
}

class _LaunchProfile extends StatefulWidget {
  const _LaunchProfile({required this.auth, required this.transport});
  final AuthController auth;
  final _PreviewTransport transport;
  @override
  State<_LaunchProfile> createState() => _LaunchProfileState();
}

class _LaunchProfileState extends State<_LaunchProfile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_open());
      }
    });
  }

  Future<void> _open() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => DoctorProfileScreen(
              auth: widget.auth,
              repository: DoctorProfileRepository(widget.transport),
              openVideo: (_) async => true,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: TextButton(
          onPressed: _open,
          child: const Text('Open Profile preview'),
        ),
      ),
    ),
  );
}

class _PreviewTransport implements BinaryTransport {
  _PreviewTransport(this.mode);
  final String mode;
  bool _readFailed = false, _uploadFailed = false;
  Uint8List? picture;
  JsonMap get doctor => {
    'user_avail': '1',
    'doc_id': '10',
    'doc_code': 'D-10',
    'doc_name': 'Example Therapist',
    'desig_name': 'Consultant',
    'deptd_name': 'Physiotherapy',
    'depts_name': 'Musculoskeletal Unit',
    'doc_center_name': 'Example Rehabilitation Centre',
    'fl_flag': '0',
    'access_flag': '1',
    'doc_app_first_login_flag': '1',
    'exp_date': '31-DEC-99',
    'doc_video_link_enable_flag': mode == 'video' ? '1' : '0',
    'doc_video_link': 'https://video.preview.invalid/doctor10',
  };
  @override
  Future<JsonMap> get(Uri uri) async {
    switch (uri.path.split('/').last) {
      case 'getDocData':
        return {
          'count': 1,
          'items': [doctor],
        };
      case 'getDocFLFlag':
        return {
          'count': 1,
          'items': [
            {'fl_flag': '0'},
          ],
        };
      case 'getDocProfile':
        if (mode == 'retry' && !_readFailed) {
          _readFailed = true;
          throw const AppFailure('Server problem or Internet not connected');
        }
        if (mode == 'empty') {
          return {'count': 0, 'items': null};
        }
        return {
          'count': 1,
          'items': [
            {
              'doc_village':
                  mode == 'long'
                      ? 'A long street address with building, road and locality for wrapping checks'
                      : 'Example Road',
              'doc_poffice': 'Savar',
              'dd_thana_name': 'Savar',
              'dist_name': 'Dhaka',
              'doc_dd_id': '12',
              'dist_id': '1',
              'doc_cell': '01700000000',
              'doc_phone': '',
              'doc_email':
                  mode == 'long'
                      ? 'a.very.long.doctor.address@example.invalid'
                      : 'doctor@example.invalid',
              'doc_profile_pic':
                  picture == null ? null : base64Encode(picture!),
            },
          ],
        };
      default:
        throw StateError('Unexpected offline preview request');
    }
  }

  @override
  Future<JsonMap> postBytes(
    Uri uri,
    Uint8List body, {
    Map<String, String> headers = const {},
    String contentType = 'application/binary',
  }) async {
    if (!uri.path.endsWith('/doc_profile/updateImage') ||
        headers['p_doc_id'] != '10') {
      throw StateError('Unexpected offline preview upload');
    }
    if (mode == 'upload_retry' && !_uploadFailed) {
      _uploadFailed = true;
      throw const AppFailure('Synthetic upload interruption');
    }
    picture = Uint8List.fromList(body);
    return {'string_out': 'Successfully Created'};
  }

  @override
  Future<String> getText(Uri uri) async =>
      throw StateError('No network in Profile preview');
  @override
  Future<JsonMap> post(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async => throw StateError('No account mutations in Profile preview');
  @override
  void close() {}
}

class _PreviewVault implements SessionVault {
  @override
  Future<VaultState> load() async => const VaultState();
  @override
  Future<void> saveSession(AuthSession session) async {}
  @override
  Future<void> clearSession() async {}
}

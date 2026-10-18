import 'package:flutter/material.dart';

import 'config/server_directory.dart';
import 'core/app_theme.dart';
import 'core/native_json.dart';
import 'core/transport.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_models.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/profile_repository.dart';
import 'features/auth/session_vault.dart';

/// Visual preview: no network or Keychain access; main.dart is the live app.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final transport = _PreviewTransport();
  final auth = AuthController(
    repository: AuthRepository(transport, ServerDirectory(transport)),
    profiles: ProfileRepository(transport),
    vault: _PreviewVault(),
  )..stage = AuthStage.signedOut;
  runApp(_LoginPreview(auth: auth));
}

class _LoginPreview extends StatefulWidget {
  const _LoginPreview({required this.auth});
  final AuthController auth;

  @override
  State<_LoginPreview> createState() => _LoginPreviewState();
}

class _LoginPreviewState extends State<_LoginPreview> {
  @override
  void dispose() {
    widget.auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DocDiary',
    debugShowCheckedModeBanner: false,
    theme: docDiaryTheme(),
    home: ListenableBuilder(
      listenable: widget.auth,
      builder: (context, _) => LoginScreen(controller: widget.auth),
    ),
  );
}

class _PreviewTransport implements Transport {
  @override
  Future<String> getText(Uri uri) async => 'https://preview.invalid/api/';

  @override
  Future<JsonMap> get(Uri uri) async => {
    'is_available': '0',
    'is_online': 'No account was found for this Mobile No and Password.',
  };

  @override
  Future<JsonMap> post(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async => throw StateError('Visual preview cannot write backend data.');

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

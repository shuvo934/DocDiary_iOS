import 'package:flutter/material.dart';

import 'app.dart';
import 'config/server_directory.dart';
import 'core/failure.dart';
import 'core/native_json.dart';
import 'core/transport.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_models.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/profile_repository.dart';
import 'features/auth/session_vault.dart';
import 'features/dashboard/dashboard_repository.dart';

/// Offline center -> user visual preview; main.dart is the live app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final transport = _SelectionPreviewTransport();
  final auth = AuthController(
    repository: AuthRepository(transport, ServerDirectory(transport)),
    profiles: ProfileRepository(
      transport,
      describeClient: () async => const ClientDescriptor(),
    ),
    vault: _SelectionPreviewVault(),
  );
  await auth.initialize();
  await auth.login('00000000000', 'preview-only', remember: false);
  runApp(
    DocDiaryApp(
      auth: auth,
      dashboard: DashboardRepository(transport),
      initializeOnStart: false,
      onDispose: transport.close,
    ),
  );
}

class _SelectionPreviewTransport implements Transport {
  @override
  Future<String> getText(Uri uri) async =>
      'https://one.preview.invalid/api/\nhttps://two.preview.invalid/api/';

  @override
  Future<JsonMap> get(Uri uri) async {
    final first = uri.host.startsWith('one.');
    return {
      'is_available': first ? '5' : '3',
      'p_center_api': 'https://${uri.host}/api/',
      'p_center_name':
          first
              ? 'Example Rehabilitation Centre A'
              : 'Example Therapy Centre B',
      'p_admin_list':
          first
              ? [
                {
                  'usr_id': '70',
                  'usr_fname': 'Example',
                  'usr_lname': 'Admin',
                  'usr_name': 'example.admin',
                },
              ]
              : <Object?>[],
      'p_doc_list': [
        {
          'doc_code': 'D-10',
          'doc_name': 'Example Therapist One',
          'depts_name': 'Physiotherapy',
        },
        {
          'doc_code': 'D-20',
          'doc_name': 'Example Therapist Two',
          'depts_name': 'Occupational Therapy',
        },
      ],
    };
  }

  @override
  Future<JsonMap> post(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async =>
      throw const AppFailure(
        'Visual preview only. Run lib/main.dart for live login.',
      );

  @override
  void close() {}
}

class _SelectionPreviewVault implements SessionVault {
  @override
  Future<VaultState> load() async => const VaultState();

  @override
  Future<void> saveSession(AuthSession session) async {}

  @override
  Future<void> clearSession() async {}
}

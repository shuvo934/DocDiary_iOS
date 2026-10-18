import 'package:flutter/material.dart';

import 'app.dart';
import 'config/server_directory.dart';
import 'core/transport.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/profile_repository.dart';
import 'features/auth/session_vault.dart';
import 'features/dashboard/dashboard_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final transport = IoTransport();
  final auth = AuthController(
    repository: AuthRepository(transport, ServerDirectory(transport)),
    profiles: ProfileRepository(transport),
    vault: KeychainSessionVault(),
  );
  runApp(
    DocDiaryApp(
      auth: auth,
      dashboard: DashboardRepository(transport),
      onDispose: transport.close,
    ),
  );
}

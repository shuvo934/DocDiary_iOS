import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'config/server_directory.dart';
import 'core/transport.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/profile_repository.dart';
import 'features/auth/session_vault.dart';
import 'features/dashboard/dashboard_repository.dart';
import 'features/startup/app_store_update.dart';
import 'features/startup/app_update_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final transport = IoTransport();
  final storeTransport = IoTransport(timeout: const Duration(seconds: 5));
  const checkStore = bool.fromEnvironment(
    'DOCDIARY_CHECK_APP_STORE',
    defaultValue: kReleaseMode,
  );
  final updates = AppUpdateController(
    enabled: Platform.isIOS && checkStore,
    checker: AppStoreUpdateChecker(
      storeTransport,
      country: const String.fromEnvironment(
        'DOCDIARY_APP_STORE_COUNTRY',
        defaultValue: 'bd',
      ),
      appStoreId: const String.fromEnvironment('DOCDIARY_APP_STORE_ID'),
    ),
  );
  final auth = AuthController(
    repository: AuthRepository(transport, ServerDirectory(transport)),
    profiles: ProfileRepository(transport),
    vault: KeychainSessionVault(),
  );
  runApp(
    DocDiaryApp(
      auth: auth,
      dashboard: DashboardRepository(transport),
      updates: updates,
      onDispose: () {
        transport.close();
        storeTransport.close();
      },
    ),
  );
}

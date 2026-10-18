import 'dart:async';

import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/login_screen.dart';
import 'package:docdiary_ios/features/auth/session_vault.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/splash/native_splash_screen.dart';
import 'package:docdiary_ios/features/startup/app_store_update.dart';
import 'package:docdiary_ios/features/startup/app_update_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class _Vault extends MemoryVault {
  int loads = 0;
  @override
  Future<VaultState> load() async {
    loads++;
    return await super.load();
  }
}

class _Checker implements AppUpdateChecker {
  AppUpdateOffer? offer = AppUpdateOffer(
    installedVersion: '1.0.0',
    storeVersion: '1.1.0',
    storeUrl: Uri.parse('https://apps.apple.com/bd/app/id123456789'),
  );
  Future<AppUpdateOffer?> Function()? onCheck;
  @override
  Future<AppUpdateOffer?> check() async =>
      onCheck == null ? offer : await onCheck!();
}

Future<_Vault> _show(
  WidgetTester tester,
  AppUpdateController updates, {
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final h = Harness();
  final vault = _Vault();
  final auth = AuthController(
    repository: h.auth.repository,
    profiles: h.profiles,
    vault: vault,
  );
  h.auth.dispose();
  await tester.pumpWidget(
    DocDiaryApp(
      auth: auth,
      updates: updates,
      dashboard: DashboardRepository(h.transport, now: () => h.now),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return vault;
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
    'a required startup update blocks auth restoration, outside tap and Back',
    (tester) async {
      final updates = AppUpdateController(checker: _Checker());
      final vault = await _show(tester, updates);
      expect(find.text('Update Required'), findsOneWidget);
      expect(find.textContaining('(1.1.0)'), findsOneWidget);
      expect(find.byType(NativeSplashScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(vault.loads, 0);
      await tester.tapAt(const Offset(5, 5));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Update Required'), findsOneWidget);
      expect(vault.loads, 0);
      await _finish(tester);
    },
  );

  testWidgets(
    'Cancel follows native Update Failed, Retry and iOS leave-app behavior',
    (tester) async {
      final updates = AppUpdateController(checker: _Checker());
      final vault = await _show(tester, updates);
      await _tap(tester, 'startup_update_cancel');
      expect(find.text('Update Failed!'), findsOneWidget);
      expect(
        find.text('Failed to update the app. Please try again.'),
        findsOneWidget,
      );
      await _tap(tester, 'startup_update_retry');
      expect(find.text('Update Required'), findsOneWidget);
      await _tap(tester, 'startup_update_cancel');
      await _tap(tester, 'startup_update_cancel');
      expect(
        find.textContaining('Use the Home gesture or Home button'),
        findsOneWidget,
      );
      expect(vault.loads, 0);
      expect(find.byType(LoginScreen), findsNothing);
      await _finish(tester);
    },
  );

  testWidgets(
    'App Store launch failure keeps splash with native Retry/Cancel actions',
    (tester) async {
      final updates = AppUpdateController(
        checker: _Checker(),
        openStore: (_) async => false,
      );
      final vault = await _show(tester, updates);
      await _tap(tester, 'startup_update_open');
      expect(find.text('Update Failed!'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(vault.loads, 0);
      await _finish(tester);
    },
  );

  testWidgets(
    'only a successful version recheck permits restoration and another full splash second',
    (tester) async {
      final checker = _Checker();
      final updates = AppUpdateController(
        checker: checker,
        openStore: (_) async => true,
      );
      final vault = await _show(tester, updates);
      await _tap(tester, 'startup_update_open');
      expect(vault.loads, 0);
      checker.offer = null;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(vault.loads, 1);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(NativeSplashScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Update Required'), findsNothing);
      await _finish(tester);
    },
  );

  testWidgets(
    'initial lookup failure proceeds to login without an update-error dialog',
    (tester) async {
      final checker =
          _Checker()
            ..onCheck = () async => throw const AppFailure('No connection');
      final updates = AppUpdateController(checker: checker);
      final vault = await _show(tester, updates);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(vault.loads, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Update Failed!'), findsNothing);
      await _finish(tester);
    },
  );

  testWidgets('late Store response after disposal cannot add a stale dialog', (
    tester,
  ) async {
    final pending = Completer<AppUpdateOffer?>();
    final checker = _Checker()..onCheck = () async => pending.future;
    final updates = AppUpdateController(checker: checker);
    await _show(tester, updates);
    await tester.pumpWidget(const MaterialApp(home: Text('Other screen')));
    pending.complete(checker.offer);
    await tester.pumpAndSettle();
    expect(find.text('Other screen'), findsOneWidget);
    expect(find.text('Update Required'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('update dialog fits small screens with two-times system text', (
    tester,
  ) async {
    final updates = AppUpdateController(checker: _Checker());
    await _show(tester, updates, size: const Size(320, 640), textScale: 2);
    expect(find.text('Update Required'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _finish(tester);
  });
}

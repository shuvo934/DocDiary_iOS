import 'dart:async';

import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/login_screen.dart';
import 'package:docdiary_ios/features/auth/session_vault.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_screen.dart';
import 'package:docdiary_ios/features/splash/native_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class _DelayedVault extends MemoryVault {
  final loaded = Completer<VaultState>();

  @override
  Future<VaultState> load() => loaded.future;
}

void main() {
  testWidgets('fast restoration still shows splash for one full second', (
    tester,
  ) async {
    final h = Harness();
    await tester.pumpWidget(
      DocDiaryApp(
        auth: h.auth,
        dashboard: DashboardRepository(h.transport, now: () => h.now),
      ),
    );
    await tester.pump();

    expect(h.auth.stage, AuthStage.signedOut);
    expect(find.byType(NativeSplashScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(milliseconds: 999));
    expect(find.byType(NativeSplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(NativeSplashScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('slow secure storage keeps splash until the session is known', (
    tester,
  ) async {
    final h = Harness();
    final vault = _DelayedVault();
    final auth = AuthController(
      repository: h.auth.repository,
      profiles: h.profiles,
      vault: vault,
    );
    h.auth.dispose();
    await tester.pumpWidget(
      DocDiaryApp(
        auth: auth,
        dashboard: DashboardRepository(h.transport, now: () => h.now),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(NativeSplashScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    vault.loaded.complete(const VaultState());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved login goes from splash directly to the doctor dashboard', (
    tester,
  ) async {
    final h = Harness();
    await h.signIn();
    await tester.pumpWidget(
      DocDiaryApp(
        auth: h.auth,
        dashboard: DashboardRepository(h.transport, now: () => h.now),
      ),
    );
    await tester.pump();
    expect(find.byType(NativeSplashScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

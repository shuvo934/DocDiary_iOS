import 'dart:async';
import 'dart:convert';

import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/features/auth/account_access.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/session_vault.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real vault atomically saves signed-out state and respects Remember Me',
    () async {
      for (final remember in [true, false]) {
        FlutterSecureStorage.setMockInitialValues({});
        final h = profileHarness();
        await h.signIn(remember: remember);
        final session = h.auth.session!;
        final vault = KeychainSessionVault();
        await vault.saveSession(session);
        const next = Credentials('01700000000', 'New+&123');
        await vault.savePasswordChange(remember ? next : null);
        final raw = await const FlutterSecureStorage().read(
          key: KeychainSessionVault.storageKey,
        );
        final map = jsonDecode(raw!) as Map<String, Object?>;
        expect(map['session'], isNull);
        final state = await vault.load();
        expect(state.session, isNull);
        expect(state.remembered?.password, remember ? 'New+&123' : null);
        expect(map.keys.toSet(), {'version', 'session', 'remembered'});
        h.auth.dispose();
      }
    },
  );
  test(
    'literal null password and legacy string values survive credential serialization',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final vault = KeychainSessionVault();
      await vault.savePasswordChange(const Credentials('01700000000', 'null'));
      expect((await vault.load()).remembered!.password, 'null');
      for (final value in ['null', ' null ', '  legacy secret  ', '+&/?#']) {
        expect(
          Credentials.fromJson({
            'mobile': '01700000000',
            'password': value,
          }).password,
          value,
        );
      }
    },
  );
  test(
    'stored success keeps acknowledgement on screen then returns to Login with new remembered password',
    () async {
      final h = profileHarness();
      await h.signIn(remember: true);
      final session = h.auth.session!;
      final writes = h.posts.length;
      await h.auth.persistPasswordChange(
        session,
        'New123',
        isCurrent: () => true,
      );
      expect(h.auth.stage, AuthStage.authenticated);
      expect(h.auth.busy, isTrue);
      expect(h.vault.state.session, isNull);
      expect(h.vault.state.remembered!.password, 'New123');
      expect(h.auth.finishPasswordChange(session), isTrue);
      expect(h.auth.stage, AuthStage.signedOut);
      expect(h.auth.session, isNull);
      expect(h.auth.formCredentials!.password, 'New123');
      expect(h.auth.formRemember, isTrue);
      expect(h.auth.finishPasswordChange(session), isFalse);
      expect(h.posts.length, writes);
      expect(h.vault.saves, 1);
      expect(h.vault.passwordChanges, 1);
      h.auth.dispose();
    },
  );
  test(
    'Remember Me off clears both auto-login and remembered secret',
    () async {
      final h = profileHarness();
      await h.signIn();
      final session = h.auth.session!;
      await h.auth.persistPasswordChange(
        session,
        'New123',
        isCurrent: () => true,
      );
      expect(h.vault.state.session, isNull);
      expect(h.vault.state.remembered, isNull);
      h.auth.finishPasswordChange(session);
      expect(h.auth.formCredentials, isNull);
      expect(h.auth.formRemember, isFalse);
      h.auth.dispose();
    },
  );
  test(
    'storage failure cannot report a completed sign-out and retries only storage',
    () async {
      final h = profileHarness();
      await h.signIn(remember: true);
      final session = h.auth.session!;
      final writes = h.posts.length;
      h.vault.failPasswordChange = true;
      await expectLater(
        h.auth.persistPasswordChange(session, 'New123', isCurrent: () => true),
        throwsA(isA<AppFailure>()),
      );
      expect(h.auth.stage, AuthStage.authenticated);
      expect(h.auth.busy, isTrue);
      expect(h.auth.finishPasswordChange(session), isFalse);
      expect(h.vault.state.session, same(session));
      h.vault.failPasswordChange = false;
      await h.auth.persistPasswordChange(
        session,
        'New123',
        isCurrent: () => true,
      );
      expect(h.auth.finishPasswordChange(session), isTrue);
      expect(h.vault.passwordChanges, 2);
      expect(h.posts.length, writes);
      expect(h.vault.state.remembered!.password, 'New123');
      h.auth.dispose();
    },
  );
  test(
    'a different password cannot replace an already acknowledged remote change during storage retry',
    () async {
      final h = profileHarness();
      await h.signIn();
      final session = h.auth.session!;
      h.vault.failPasswordChange = true;
      await expectLater(
        h.auth.persistPasswordChange(
          session,
          'FirstNew',
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        h.auth.persistPasswordChange(
          session,
          'OtherNew',
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.vault.passwordChanges, 1);
      h.auth.dispose();
    },
  );
  test(
    'acknowledgement-pending sign-out cannot switch or restore the old active session',
    () async {
      final h = profileHarness();
      await h.signIn(remember: true);
      final session = h.auth.session!;
      await h.auth.persistPasswordChange(
        session,
        'New123',
        isCurrent: () => true,
      );
      final requests = h.transport.requests.length;
      h.auth.beginSwitch();
      await h.auth.initialize();
      expect(h.auth.stage, AuthStage.authenticated);
      expect(h.auth.session, same(session));
      expect(h.transport.requests.length, requests);
      h.auth.finishPasswordChange(session);
      h.auth.dispose();
    },
  );
  test(
    'restart after storage success but before OK restores Login without auto-login requests',
    () async {
      final h = profileHarness();
      await h.signIn(remember: true);
      final session = h.auth.session!;
      await h.auth.persistPasswordChange(
        session,
        'New123',
        isCurrent: () => true,
      );
      final requests = h.transport.requests.length;
      final restored = AuthController(
        repository: h.auth.repository,
        profiles: h.profiles,
        vault: h.vault,
      );
      await restored.initialize();
      expect(restored.stage, AuthStage.signedOut);
      expect(restored.formCredentials!.password, 'New123');
      expect(h.transport.requests.length, requests);
      restored.dispose();
      h.auth.dispose();
    },
  );
  test('stale or signed-out account cannot mutate saved credentials', () async {
    final h = profileHarness();
    await h.signIn();
    final session = h.auth.session!;
    await expectLater(
      h.auth.persistPasswordChange(session, 'New123', isCurrent: () => false),
      throwsA(isA<ObsoleteRequest>()),
    );
    await h.auth.logout();
    await expectLater(
      h.auth.persistPasswordChange(session, 'New123', isCurrent: () => true),
      throwsA(isA<ObsoleteRequest>()),
    );
    expect(h.vault.passwordChanges, 0);
    h.auth.dispose();
  });
  test(
    'forced logout during a delayed credential write queues cleanup after it and cannot restore a session',
    () async {
      final h = profileHarness();
      await h.signIn(remember: true);
      final session = h.auth.session!;
      final pending = Completer<void>();
      h.vault.onPasswordChange = () => pending.future;
      final store = h.auth.persistPasswordChange(
        session,
        'New123',
        isCurrent: () => true,
      );
      final storeExpectation = expectLater(
        store,
        throwsA(isA<ObsoleteRequest>()),
      );
      await Future<void>.delayed(Duration.zero);
      h.auth.blockAccess(const AccountAccessFailure.forcedLogout());
      final signout = h.auth.acknowledgeAccess();
      expect(h.vault.clears, 0);
      pending.complete();
      await storeExpectation;
      await signout;
      expect(h.auth.stage, AuthStage.signedOut);
      expect(h.vault.state.session, isNull);
      expect(h.vault.state.remembered!.password, 'New123');
      expect(h.auth.remembered!.password, 'New123');
      h.auth.dispose();
    },
  );
}

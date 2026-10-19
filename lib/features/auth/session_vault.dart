import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/failure.dart';
import '../../core/native_json.dart';
import 'auth_models.dart';

class VaultState {
  const VaultState({this.session, this.remembered});
  final AuthSession? session;
  final Credentials? remembered;
}

abstract interface class SessionVault {
  Future<VaultState> load();
  Future<void> saveSession(AuthSession session);
  Future<void> clearSession();
}

/// Replace the saved sign-in with a signed-out state in one storage write.
/// Password change must never briefly persist a new auto-login session.
abstract interface class PasswordChangeVault {
  Future<void> savePasswordChange(Credentials? remembered);
}

/// One Keychain item is replaced atomically. Logout retains only credentials
/// explicitly saved through Remember Me, matching the native behaviour.
class KeychainSessionVault implements SessionVault, PasswordChangeVault {
  KeychainSessionVault({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const storageKey = 'ttit.docdiary.ios.auth.v1';

  @override
  Future<VaultState> load() async {
    try {
      final raw = await _storage.read(key: storageKey);
      if (raw == null) {
        return const VaultState();
      }
      final json = nativeObject(raw);
      if (json['version'] != 1) {
        throw const FormatException('Unsupported saved sign-in version');
      }
      return VaultState(
        session:
            json['session'] == null
                ? null
                : AuthSession.fromJson(nativeObject(json['session'])),
        remembered:
            json['remembered'] == null
                ? null
                : Credentials.fromJson(nativeObject(json['remembered'])),
      );
    } on AppFailure {
      await _deleteCorruptItem();
      return const VaultState();
    } on FormatException {
      await _deleteCorruptItem();
      return const VaultState();
    } catch (_) {
      throw const AppFailure(
        'Saved sign-in could not be read. Please try again.',
        kind: FailureKind.storage,
      );
    }
  }

  Future<void> _deleteCorruptItem() async {
    try {
      await _storage.delete(key: storageKey);
    } catch (_) {
      throw const AppFailure(
        'Saved sign-in could not be cleared. Please try again.',
        kind: FailureKind.storage,
      );
    }
  }

  Future<void> _write(VaultState state) async {
    try {
      await _storage.write(
        key: storageKey,
        value: jsonEncode({
          'version': 1,
          'session': state.session?.toJson(),
          'remembered': state.remembered?.toJson(),
        }),
      );
    } catch (_) {
      throw const AppFailure(
        'Sign-in could not be saved securely. Please try again.',
        kind: FailureKind.storage,
      );
    }
  }

  @override
  Future<void> saveSession(AuthSession session) => _write(
    VaultState(
      session: session,
      remembered: session.remember ? session.credentials : null,
    ),
  );

  @override
  Future<void> clearSession() async {
    final previous = await load();
    await _write(VaultState(remembered: previous.remembered));
  }

  @override
  Future<void> savePasswordChange(Credentials? remembered) =>
      _write(VaultState(remembered: remembered));
}

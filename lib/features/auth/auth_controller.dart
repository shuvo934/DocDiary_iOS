import 'package:flutter/foundation.dart';

import '../../core/failure.dart';
import 'account_access.dart';
import 'auth_models.dart';
import 'auth_repository.dart';
import 'profile_repository.dart';
import 'session_vault.dart';

enum AuthStage {
  booting,
  signedOut,
  discovering,
  chooseCenter,
  chooseAccount,
  signingIn,
  authenticated,
  accountBlocked,
  accountError,
  reconnect,
  signingOut,
}

class AuthController extends ChangeNotifier {
  AuthController({
    required this.repository,
    required this.profiles,
    required this.vault,
  });
  final AuthRepository repository;
  final ProfileRepository profiles;
  final SessionVault vault;

  AuthStage stage = AuthStage.booting;
  AuthSession? session;
  AccountProfile? profile;
  Credentials? remembered;
  List<CenterOption> centers = const [];
  CenterOption? selectedCenter;
  String? error;
  int failedServerCount = 0;
  Credentials? _pending;
  Credentials? _draft;
  bool _remember = false;
  bool _switching = false;
  int _operation = 0;
  bool _disposed = false;
  bool _logoutPending = false;
  AccountAccessFailure? accessFailure;
  Future<void> Function()? _retryAccount;
  int _accountGateRevision = 0;

  bool get logoutPending => _logoutPending;
  int get accountGateRevision => _accountGateRevision;

  bool get busy => const [
    AuthStage.booting,
    AuthStage.discovering,
    AuthStage.signingIn,
    AuthStage.signingOut,
  ].contains(stage);
  bool get canSwitch =>
      stage == AuthStage.authenticated &&
      session != null &&
      (session!.centers.length > 1 ||
          session!.centers.any((center) => center.accounts.length > 1));
  Credentials? get formCredentials => _draft ?? remembered;
  bool get formRemember => _draft != null ? _remember : remembered != null;

  bool _current(int operation) => !_disposed && operation == _operation;
  void _changed() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> initialize() async {
    if (_disposed) {
      return;
    }
    if (_logoutPending) {
      await logout();
      return;
    }
    final operation = ++_operation;
    stage = AuthStage.booting;
    profile = null;
    accessFailure = null;
    _retryAccount = null;
    error = null;
    _changed();
    try {
      final saved = await vault.load();
      if (!_current(operation)) {
        return;
      }
      remembered = saved.remembered;
      final candidate = saved.session;
      if (candidate == null) {
        session = null;
        stage = AuthStage.signedOut;
      } else {
        session = candidate;
        await _restoreCandidate(candidate);
        return;
      }
    } catch (failure) {
      if (!_current(operation)) {
        return;
      }
      profile = null;
      error = _message(failure);
      stage = AuthStage.reconnect;
    }
    if (_current(operation)) {
      _changed();
    }
  }

  Future<void> _restoreCandidate(AuthSession candidate) async {
    if (_disposed) {
      return;
    }
    final operation = ++_operation;
    stage = AuthStage.booting;
    profile = null;
    error = null;
    _retryAccount = null;
    _changed();
    try {
      final loaded = await profiles.open(
        candidate,
        isCurrent: () => _current(operation),
      );
      if (!_current(operation)) {
        return;
      }
      profile = loaded;
      stage = AuthStage.authenticated;
    } catch (failure) {
      if (!_current(operation)) {
        return;
      }
      if (failure is AccountAccessFailure) {
        blockAccess(failure);
        return;
      }
      error = _message(failure);
      stage = AuthStage.accountError;
      ++_accountGateRevision;
      _retryAccount = () => _restoreCandidate(candidate);
    }
    if (_current(operation)) {
      _changed();
    }
  }

  /// The native dialog blocks the account until OK; it does not silently route
  /// a denial into an inline login error. Session removal follows the user's OK.
  void blockAccess(AccountAccessFailure failure) {
    if (_disposed ||
        stage == AuthStage.signingOut ||
        stage == AuthStage.accountBlocked) {
      return;
    }
    ++_operation;
    profile = null;
    accessFailure = failure;
    error = null;
    _retryAccount = null;
    stage = AuthStage.accountBlocked;
    ++_accountGateRevision;
    _changed();
  }

  Future<void> acknowledgeAccess() async {
    if (stage == AuthStage.accountBlocked) {
      await logout();
    }
  }

  Future<void> retryAccount() async {
    if (_disposed || stage != AuthStage.accountError) {
      return;
    }
    final retry = _retryAccount;
    _retryAccount = null;
    if (retry != null) {
      await retry();
    }
  }

  Future<void> login(
    String mobile,
    String password, {
    required bool remember,
  }) async {
    if (busy || _disposed || stage != AuthStage.signedOut) {
      return;
    }
    if (mobile.trim().isEmpty || password.isEmpty) {
      error = 'Please Give Mobile No and Password';
      _changed();
      return;
    }
    final operation = ++_operation;
    _pending = Credentials(mobile, password);
    _draft = _pending;
    _remember = remember;
    _switching = false;
    centers = const [];
    selectedCenter = null;
    stage = AuthStage.discovering;
    error = null;
    _changed();
    try {
      final result = await repository.discover(_pending!);
      if (!_current(operation)) {
        return;
      }
      centers = result.centers;
      failedServerCount = result.failedServerCount;
      stage = AuthStage.chooseCenter;
      if (centers.length == 1) {
        await selectCenter(centers.single);
        return;
      }
    } catch (failure) {
      if (!_current(operation)) {
        return;
      }
      _pending = null;
      stage = AuthStage.signedOut;
      error = _message(failure);
    }
    if (_current(operation)) {
      _changed();
    }
  }

  Future<void> selectCenter(CenterOption center) async {
    if (busy ||
        _disposed ||
        stage != AuthStage.chooseCenter ||
        !centers.contains(center)) {
      return;
    }
    selectedCenter = center;
    error = null;
    if (!center.requiresAccountChoice && center.accounts.length == 1) {
      await _finish(center.accounts.single);
    } else {
      stage = AuthStage.chooseAccount;
      _changed();
    }
  }

  Future<void> selectAccount(AccountOption account) async {
    if (busy ||
        _disposed ||
        stage != AuthStage.chooseAccount ||
        selectedCenter == null ||
        !selectedCenter!.accounts.contains(account)) {
      return;
    }
    await _finish(account);
  }

  Future<void> _finish(AccountOption account) async {
    final center = selectedCenter;
    final credentials = _pending;
    if (center == null || credentials == null) {
      return;
    }
    final candidate = AuthSession(
      credentials: credentials,
      center: center,
      account: account,
      centers: centers,
      remember: _remember,
    );
    await _finishCandidate(candidate, resetFlag: !_switching);
  }

  Future<void> _finishCandidate(
    AuthSession candidate, {
    required bool resetFlag,
    AccountProfile? alreadyLoaded,
  }) async {
    if (_disposed) {
      return;
    }
    final operation = ++_operation;
    final previousStage =
        candidate.center.requiresAccountChoice
            ? AuthStage.chooseAccount
            : AuthStage.chooseCenter;
    var flagCompleted = !resetFlag;
    var loaded = alreadyLoaded;
    stage = AuthStage.signingIn;
    error = null;
    accessFailure = null;
    _retryAccount = null;
    _changed();
    try {
      // Account switching and DocData Retry never reset forced-logout flags.
      if (resetFlag) {
        await repository.resetFirstLoginFlag(
          candidate.center,
          candidate.account,
        );
        if (!_current(operation)) {
          return;
        }
        flagCompleted = true;
      }
      final loadedProfile = await profiles.open(
        candidate,
        recordLogin: loaded == null,
        isCurrent: () => _current(operation),
      );
      loaded = loadedProfile;
      if (!_current(operation)) {
        return;
      }
      ProfileRepository.checkAccess(loadedProfile, profiles.now());
      await vault.saveSession(candidate);
      if (!_current(operation)) {
        return;
      }
      session = candidate;
      profile = loadedProfile;
      remembered = candidate.remember ? candidate.credentials : null;
      _pending = null;
      _switching = false;
      _draft = null;
      stage = AuthStage.authenticated;
    } catch (failure) {
      if (!_current(operation)) {
        return;
      }
      if (failure is AccountAccessFailure) {
        blockAccess(failure);
        return;
      }
      error = _message(failure);
      if (!flagCompleted) {
        // Login's flag-reset failure remains in the accepted selection/login UI.
        stage = previousStage;
      } else {
        stage = AuthStage.accountError;
        ++_accountGateRevision;
        _retryAccount =
            () => _finishCandidate(
              candidate,
              resetFlag: false,
              alreadyLoaded: loaded,
            );
      }
    }
    if (_current(operation)) {
      _changed();
    }
  }

  void beginSwitch() {
    if (busy || stage != AuthStage.authenticated || !canSwitch) {
      return;
    }
    final active = session!;
    ++_operation;
    _switching = true;
    _pending = active.credentials;
    _remember = active.remember;
    centers = active.centers;
    error = null;
    selectedCenter = centers.length == 1 ? centers.single : null;
    stage =
        centers.length == 1 ? AuthStage.chooseAccount : AuthStage.chooseCenter;
    _changed();
  }

  void cancelSelection() {
    if (busy ||
        _disposed ||
        (stage != AuthStage.chooseCenter && stage != AuthStage.chooseAccount)) {
      return;
    }
    ++_operation;
    _pending = null;
    selectedCenter = null;
    centers = const [];
    stage =
        _switching && session != null
            ? AuthStage.authenticated
            : AuthStage.signedOut;
    _switching = false;
    error = null;
    _changed();
  }

  void backToCenters() {
    if (busy || _disposed || stage != AuthStage.chooseAccount) {
      return;
    }
    if (centers.length <= 1) {
      cancelSelection();
      return;
    }
    selectedCenter = null;
    stage = AuthStage.chooseCenter;
    error = null;
    _changed();
  }

  Future<void> logout({String? message}) async {
    if (busy || _disposed) {
      return;
    }
    final operation = ++_operation;
    stage = AuthStage.signingOut;
    _logoutPending = true;
    accessFailure = null;
    _retryAccount = null;
    profile = null;
    _pending = null;
    _draft = null;
    _changed();
    try {
      await vault.clearSession();
      if (!_current(operation)) {
        return;
      }
      session = null;
      centers = const [];
      selectedCenter = null;
      _switching = false;
      _logoutPending = false;
      stage = AuthStage.signedOut;
      error = message;
    } catch (failure) {
      if (!_current(operation)) {
        return;
      }
      error = _message(failure);
      // Never report a successful logout when the saved session remains.
      stage = AuthStage.reconnect;
    }
    if (_current(operation)) {
      _changed();
    }
  }

  String _message(Object failure) =>
      failure is AppFailure
          ? failure.message
          : 'The operation could not be completed. Please try again.';

  @override
  void dispose() {
    _disposed = true;
    ++_operation;
    _pending = null;
    _draft = null;
    _retryAccount = null;
    super.dispose();
  }
}

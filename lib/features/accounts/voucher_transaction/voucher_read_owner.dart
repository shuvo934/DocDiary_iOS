import 'package:flutter/widgets.dart';
import '../../../core/failure.dart';
import '../../auth/account_access.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import 'voucher_repository.dart';

/// Owns a read chain's session, foreground state and cancellation generation.
class VoucherReadOwner extends ChangeNotifier with WidgetsBindingObserver {
  VoucherReadOwner(this.auth, this.repository, {required this.onResume})
    : session = auth.session {
    final state = WidgetsBinding.instance.lifecycleState;
    foreground = state == null || state == AppLifecycleState.resumed;
    auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
  }
  final AuthController auth;
  final VoucherRepository repository;
  final AuthSession? session;
  final VoidCallback onResume;
  bool foreground = true, _disposed = false;
  int _generation = 0;
  bool get current =>
      !_disposed &&
      session != null &&
      session!.account.role == AccountRole.admin &&
      auth.stage == AuthStage.authenticated &&
      auth.session == session;
  bool alive(int operation) =>
      current && foreground && operation == _generation;
  int begin() {
    if (!current || !foreground) throw const ObsoleteRequest();
    return ++_generation;
  }

  Future<AccountProfile> fresh(int operation) async {
    if (!alive(operation)) throw const ObsoleteRequest();
    final profile = await auth.profiles.open(
      session!,
      recordLogin: false,
      isCurrent: () => alive(operation),
    );
    repository.guard(session!, profile, () => alive(operation));
    return profile;
  }

  bool blockDenied(Object failure) {
    if (failure is! AppFailure || failure.kind != FailureKind.denied) {
      return false;
    }
    auth.blockAccess(
      failure is AccountAccessFailure
          ? failure
          : const AccountAccessFailure.mobileAccess(),
    );
    return true;
  }

  void _authChanged() {
    if (current) return;
    ++_generation;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ([
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ].contains(state)) {
      foreground = false;
      ++_generation;
      notifyListeners();
    } else if (state == AppLifecycleState.resumed && !foreground) {
      foreground = true;
      ++_generation;
      onResume();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    auth.removeListener(_authChanged);
    super.dispose();
  }
}

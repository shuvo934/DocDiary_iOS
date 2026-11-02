import 'dart:async';
import 'package:flutter/material.dart';
import '../appointments/doctor_schedule/history/doctor_appointment_history_models.dart';
import '../appointments/doctor_schedule/history/native_appointment_history_layout.dart';
import '../../core/app_toast.dart';
import '../../core/failure.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../dashboard/native_dashboard_dialogs.dart';
import 'payment_models.dart';
import 'payment_repository.dart';

typedef PaymentTask =
    Future<void> Function(AccountProfile profile, bool Function() isCurrent);

/// Owns only this feature's overlays/requests. A background transition never
/// replays a POST; acknowledged rows stay in their original account's draft.
abstract class PaymentState<T extends StatefulWidget> extends State<T>
    with WidgetsBindingObserver {
  AuthController get auth;
  PaymentRepository get repository;
  late final AuthSession? session = auth.session;
  final dialogs = NativeDashboardDialogOwner();
  final toasts = AppToastOwner();
  AccountProfile? profile;
  bool busy = true, foreground = true, childAway = false, writing = false;
  String? error;
  PaymentTask? retryStage;
  _PaymentFlow? _flow;
  int _operation = 0;
  bool _resumePending = false;
  bool get current =>
      mounted &&
      session != null &&
      auth.stage == AuthStage.authenticated &&
      auth.session == session;
  bool get ready =>
      current &&
      foreground &&
      profile != null &&
      !busy &&
      !writing &&
      !childAway &&
      !dialogs.isOpen;
  bool alive(int operation) => current && foreground && operation == _operation;
  Future<void> refresh(AccountProfile profile, bool Function() isCurrent);
  void clearPayment();

  Future<PaymentChoice?> choose(
    BuildContext fieldContext,
    List<PaymentChoice> rows,
  ) async {
    if (!ready || rows.isEmpty) return null;
    final box = fieldContext.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final picked = await showOwned<AppointmentHistoryChoice>(
      NativeAppointmentHistoryChoices(
        kind: AppointmentHistoryFilter.unit,
        choices: [
          for (final row in rows) AppointmentHistoryChoice(row.key, row.name),
        ],
        anchor: box.localToGlobal(Offset.zero) & box.size,
      ),
      dismissible: true,
      barrierColor: Colors.transparent,
    );
    if (!current || !foreground || picked == null) return null;
    return rows.where((row) => row.key == picked.id).firstOrNull;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _flow ??=
        context.dependOnInheritedWidgetOfExactType<_PaymentScope>()?.flow ??
        _PaymentFlow();
  }

  Widget ownedChild(Widget child) => _PaymentScope(flow: _flow!, child: child);

  Future<R?> showOwned<R>(
    Widget child, {
    bool dismissible = false,
    Color barrierColor = const Color(0xcc000000),
  }) async {
    try {
      return await dialogs.show<R>(
        context,
        ownedChild(child),
        dismissible: dismissible,
        barrierColor: barrierColor,
      );
    } finally {
      // A profile read can rebuild the form while an owned dialog is open.
      // Re-enable its callbacks after No/OK/dismiss, including success messages
      // that retain collision rows instead of resetting the whole draft.
      if (mounted) setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (current && foreground) {
        unawaited(run(refresh, force: true));
      } else if (mounted && session == null) {
        setState(() {
          busy = false;
          error = 'Payment details are unavailable. Please return to Login.';
        });
      }
    });
  }

  void _authChanged() {
    if (current) return;
    ++_operation;
    _resumePending = false;
    dialogs.close();
    toasts.clear();
    clearPayment();
    profile = null;
    if (mounted) {
      setState(() {
        busy = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ([
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ].contains(state)) {
      foreground = false;
      ++_operation;
      if (!childAway) dialogs.close();
      toasts.clear();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && !foreground) {
      foreground = true;
      if (writing) {
        _resumePending = true;
      } else if (current && !childAway) {
        unawaited(run(refresh, force: true));
      }
    }
  }

  Future<AccountProfile> fresh(bool Function() isCurrent) async {
    final next = await auth.profiles.open(
      session!,
      recordLogin: false,
      isCurrent: isCurrent,
    );
    repository.guard(session!, next, isCurrent);
    return next;
  }

  Future<void> run(
    PaymentTask task, {
    bool write = false,
    bool force = false,
  }) async {
    if (!current || !foreground || childAway || writing || (busy && !force)) {
      return;
    }
    final operation = ++_operation;
    retryStage = task;
    setState(() {
      busy = true;
      error = null;
    });
    Object? failed;
    try {
      final next = await fresh(() => alive(operation));
      if (!alive(operation)) return;
      profile = next;
      if (write) writing = true;
      try {
        await task(next, () => alive(operation));
      } finally {
        if (write) writing = false;
      }
    } catch (failure) {
      failed = failure;
    } finally {
      if (alive(operation)) {
        setState(() {
          busy = false;
        });
      }
      if (_resumePending && !writing) {
        _resumePending = false;
        if (current && foreground && !childAway) {
          unawaited(run(refresh, force: true));
        }
      }
    }
    if (!mounted ||
        !alive(operation) ||
        failed == null ||
        failed is ObsoleteRequest) {
      return;
    }
    final failure = failed;
    if (failure is AppFailure && failure.kind == FailureKind.denied) {
      clearPayment();
      auth.blockAccess(
        failure is AccountAccessFailure
            ? failure
            : const AccountAccessFailure.mobileAccess(),
      );
      return;
    }
    final unavailable = failure is PaymentUnavailable;
    if (unavailable && _flow!.accessLossShown) {
      setState(() {
        clearPayment();
        profile = null;
      });
      await close(force: true);
      return;
    }
    if (unavailable) {
      _flow!.accessLossShown = true;
      clearPayment();
      profile = null;
    }
    final uncertain = failure is PaymentWriteUncertain;
    final settingsChanged = failure is PaymentSettingsChanged;
    final message =
        unavailable
            ? 'Payment is not available for this account.'
            : uncertain
            ? 'The payment result could not be confirmed. Please check Payment records with your accounts team before trying again.'
            : settingsChanged
            ? 'Payment settings changed. Please reopen payment confirmation.'
            : failure is AppFailure
            ? failure.message
            : 'The payment could not be loaded. Please try again.';
    setState(() {
      error = message;
    });
    final retry = await showOwned<bool>(
      AlertDialog(
        key: const Key('payment_error'),
        title: Text(
          unavailable ? 'Not available' : 'Error!',
          style: dashboardDialogText(20),
        ),
        content: SingleChildScrollView(
          child: Text(message, style: dashboardDialogText(16)),
        ),
        actions: [
          TextButton(
            key: const Key('payment_error_cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(unavailable ? 'CLOSE' : 'Cancel'),
          ),
          if (!unavailable && !uncertain && !settingsChanged)
            TextButton(
              key: const Key('payment_error_retry'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
    if (!alive(operation)) return;
    if (unavailable) {
      await close(force: true);
    } else if (retry == true) {
      await run(retryStage ?? task, write: write);
    }
  }

  Future<bool> confirm(
    String title,
    String message, {
    String keyName = 'confirmation',
  }) async {
    if (!ready) return false;
    final answer = await showOwned<bool>(
      AlertDialog(
        key: Key('payment_$keyName'),
        title: Text(title, style: dashboardDialogText(20)),
        content: SingleChildScrollView(
          child: Text(message, style: dashboardDialogText(16)),
        ),
        actions: [
          TextButton(
            key: const Key('payment_no'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            key: const Key('payment_yes'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return current && foreground && answer == true;
  }

  Future<void> message(String title, String message) async {
    if (!current || !foreground || dialogs.isOpen) return;
    await showOwned<void>(
      AlertDialog(
        key: const Key('payment_message'),
        title: Text(title, style: dashboardDialogText(20)),
        content: SingleChildScrollView(
          child: Text(message, style: dashboardDialogText(16)),
        ),
        actions: [
          TextButton(
            key: const Key('payment_ok'),
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<R?> openPage<R>(Widget page) async {
    if (!ready) return null;
    childAway = true;
    try {
      return await dialogs.push<R>(context, ownedChild(page));
    } finally {
      childAway = false;
      if (current && foreground) unawaited(run(refresh, force: true));
    }
  }

  Future<void> close({bool force = false}) async {
    if (!current || dialogs.isOpen) return;
    if (!force && (busy || writing)) {
      toasts.show(context, 'Please wait while loading');
      return;
    }
    if (force && Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      await Navigator.maybePop(context);
    }
  }

  @override
  void dispose() {
    ++_operation;
    auth.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    dialogs.dispose();
    toasts.dispose();
    super.dispose();
  }
}

class _PaymentFlow {
  bool accessLossShown = false;
}

class _PaymentScope extends InheritedWidget {
  const _PaymentScope({required this.flow, required super.child});
  final _PaymentFlow flow;
  @override
  bool updateShouldNotify(_PaymentScope oldWidget) => oldWidget.flow != flow;
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/app_toast.dart';
import '../../../core/failure.dart';
import '../../auth/account_access.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../../dashboard/native_dashboard_dialogs.dart';
import 'admin_appointment_models.dart';
import 'admin_appointment_repository.dart';

typedef AdminAppointmentTask =
    Future<void> Function(AccountProfile profile, bool Function() isCurrent);

/// Owns only this feature's overlays/requests. A background transition never
/// replays a POST; acknowledged rows stay in their original account's draft.
abstract class AdminAppointmentState<T extends StatefulWidget> extends State<T>
    with WidgetsBindingObserver {
  AuthController get auth;
  AdminAppointmentRepository get repository;
  late final AuthSession? session = auth.session;
  final dialogs = NativeDashboardDialogOwner();
  final toasts = AppToastOwner();
  AccountProfile? profile;
  bool busy = true, foreground = true, childAway = false, writing = false;
  String? error;
  AdminAppointmentTask? retryStage;
  _AdminAppointmentFlow? _flow;
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
  void clearAppointment();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _flow ??=
        context
            .dependOnInheritedWidgetOfExactType<_AdminAppointmentScope>()
            ?.flow ??
        _AdminAppointmentFlow();
  }

  Widget ownedChild(Widget child) =>
      _AdminAppointmentScope(flow: _flow!, child: child);

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
          error =
              'Appointment details are unavailable. Please return to Login.';
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
    clearAppointment();
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
    AdminAppointmentTask task, {
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
      clearAppointment();
      auth.blockAccess(
        failure is AccountAccessFailure
            ? failure
            : const AccountAccessFailure.mobileAccess(),
      );
      return;
    }
    final unavailable = failure is AdminAppointmentUnavailable;
    if (unavailable && _flow!.accessLossShown) {
      setState(() {
        clearAppointment();
        profile = null;
      });
      await close(force: true);
      return;
    }
    if (unavailable) {
      _flow!.accessLossShown = true;
      clearAppointment();
      profile = null;
    }
    final message =
        unavailable
            ? 'Appointment is not available for this account.'
            : failure is AppFailure
            ? failure.message
            : 'The appointment could not be loaded. Please try again.';
    setState(() {
      error = message;
    });
    final retry = await showOwned<bool>(
      AlertDialog(
        key: const Key('admin_appointment_error'),
        title: Text(
          unavailable ? 'Not available' : 'Error!',
          style: dashboardDialogText(20),
        ),
        content: SingleChildScrollView(
          child: Text(message, style: dashboardDialogText(16)),
        ),
        actions: [
          TextButton(
            key: const Key('admin_appointment_error_cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(unavailable ? 'CLOSE' : 'Cancel'),
          ),
          if (!unavailable)
            TextButton(
              key: const Key('admin_appointment_error_retry'),
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
        key: Key('admin_appointment_$keyName'),
        title: Text(title, style: dashboardDialogText(20)),
        content: SingleChildScrollView(
          child: Text(message, style: dashboardDialogText(16)),
        ),
        actions: [
          TextButton(
            key: const Key('admin_appointment_no'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            key: const Key('admin_appointment_yes'),
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
        key: const Key('admin_appointment_message'),
        title: Text(title, style: dashboardDialogText(20)),
        content: SingleChildScrollView(
          child: Text(message, style: dashboardDialogText(16)),
        ),
        actions: [
          TextButton(
            key: const Key('admin_appointment_ok'),
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

class _AdminAppointmentFlow {
  bool accessLossShown = false;
}

class _AdminAppointmentScope extends InheritedWidget {
  const _AdminAppointmentScope({required this.flow, required super.child});
  final _AdminAppointmentFlow flow;
  @override
  bool updateShouldNotify(_AdminAppointmentScope oldWidget) =>
      oldWidget.flow != flow;
}

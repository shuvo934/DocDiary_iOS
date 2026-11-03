import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_toast.dart';
import '../../core/failure.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../dashboard/native_dashboard_dialogs.dart';
import 'report_manager_menu.dart';
import 'report_manager_repository.dart';

typedef ReportTask =
    Future<void> Function(AccountProfile profile, bool Function() isCurrent);

/// Owns report reads, dialogs and child pages; stale operations cannot publish
/// data, retry, open a PDF or export another session's document.
abstract class ReportScreenState<T extends StatefulWidget> extends State<T>
    with WidgetsBindingObserver {
  AuthController get auth;
  ReportManagerRepository get repository;
  ReportManagerItem get item;
  Future<void> loadReport(AccountProfile profile, bool Function() current);
  late final AuthSession? session = auth.session;
  final dialogs = NativeDashboardDialogOwner();
  final toasts = AppToastOwner();
  bool busy = true, foreground = true, authorized = false, childAway = false;
  String? error;
  int _operation = 0;
  ReportTask? _interrupted;
  _ReportFlow? _flow;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _flow ??=
        context.dependOnInheritedWidgetOfExactType<_ReportFlowScope>()?.flow ??
        _ReportFlow();
  }

  bool get current =>
      mounted &&
      session != null &&
      auth.stage == AuthStage.authenticated &&
      auth.session == session;
  bool _alive(int operation) =>
      current && foreground && operation == _operation;
  bool get ready =>
      current &&
      foreground &&
      authorized &&
      !busy &&
      error == null &&
      !childAway &&
      !dialogs.isOpen;
  bool get isForegroundAction => false;
  void clearReport() {}
  void onReportBackground() {}
  ReportTask? get refreshOnResume => null;
  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (current && foreground) {
        unawaited(runReportTask(loadReport));
      } else if (mounted && session == null) {
        setState(() {
          busy = false;
          error =
              '${repository.moduleName} is unavailable. Please return to Login.';
        });
      }
    });
  }

  void _authChanged() {
    if (current) return;
    ++_operation;
    _interrupted = null;
    dialogs.close();
    toasts.clear();
    clearReport();
    if (mounted) {
      setState(() {
        authorized = false;
        busy = true;
        error = null;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      foreground = false;
      ++_operation;
      if (!childAway) dialogs.close();
      toasts.clear();
      onReportBackground();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && !foreground) {
      foreground = true;
      if (current && !childAway && !isForegroundAction) {
        unawaited(runReportTask(refreshOnResume ?? _interrupted ?? _guardOnly));
      }
    }
    // Inactive alone can be an owned iOS Files picker; true background suspends it.
  }

  Future<void> _guardOnly(AccountProfile _, bool Function() current) async {}
  Future<void> runReportTask(ReportTask task, {Object? failure}) async {
    if (!current || !foreground || childAway) return;
    final operation = ++_operation;
    _interrupted = task;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final profile = await auth.profiles.open(
        session!,
        recordLogin: false,
        isCurrent: () => _alive(operation),
      );
      repository.guard(session!, profile, item, () => _alive(operation));
      if (profile.isDoctor && profile.doctorId != auth.profile?.doctorId) {
        throw const AppFailure(
          'The server returned information for a different account.',
          kind: FailureKind.invalidData,
        );
      }
      if (failure != null) throw failure;
      await task(profile, () => _alive(operation));
      if (!_alive(operation)) return;
      _interrupted = null;
      setState(() {
        authorized = true;
        busy = false;
      });
    } catch (failure) {
      if (!_alive(operation) || failure is ObsoleteRequest) return;
      if (failure is AppFailure && failure.kind == FailureKind.denied) {
        clearReport();
        auth.blockAccess(
          failure is AccountAccessFailure
              ? failure
              : const AccountAccessFailure.mobileAccess(),
        );
        return;
      }
      final unavailable = failure is ReportManagerUnavailable;
      if (unavailable && _flow!.accessLossShown) {
        clearReport();
        setState(() {
          busy = false;
          authorized = false;
        });
        await closeReport(force: true);
        return;
      }
      if (unavailable) {
        _flow!.accessLossShown = true;
      }
      setState(() {
        busy = false;
        if (unavailable) {
          authorized = false;
          clearReport();
        }
        error =
            unavailable
                ? '${repository.moduleName} is not available for this account.'
                : reportFailureMessage(failure);
      });
      if (!mounted || !_alive(operation)) return;
      final retry = await dialogs.show<bool>(
        context,
        AlertDialog(
          key: const Key('report_error_dialog'),
          title: Text(
            unavailable ? 'Not available' : 'Error!',
            style: dashboardDialogText(20),
          ),
          content: SingleChildScrollView(
            child: Text(error!, style: dashboardDialogText(16)),
          ),
          actions: [
            TextButton(
              key: const Key('report_error_exit'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(unavailable ? 'CLOSE' : 'Exit'),
            ),
            if (!unavailable)
              TextButton(
                key: const Key('report_error_retry'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Retry'),
              ),
          ],
        ),
      );
      if (!_alive(operation)) return;
      if (retry == true) {
        await runReportTask(task);
      } else {
        await closeReport(force: true);
      }
    }
  }

  Future<void> openReport(Widget page) async {
    if (!ready) return;
    childAway = true;
    try {
      await dialogs.push<void>(
        context,
        _ReportFlowScope(flow: _flow!, child: page),
      );
    } finally {
      childAway = false;
      if (current && foreground) {
        if (_flow!.accessLossShown) {
          clearReport();
          setState(() {
            busy = false;
            authorized = false;
          });
          await closeReport(force: true);
        } else {
          await runReportTask(_guardOnly);
        }
      }
    }
  }

  Future<void> closeReport({bool force = false}) async {
    if (!current || dialogs.isOpen) return;
    if (!force && (busy || isForegroundAction)) {
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

String reportFailureMessage(Object failure) =>
    failure is AppFailure
        ? failure.message
        : 'The report could not be loaded. Please try again.';

class _ReportFlow {
  bool accessLossShown = false;
}

class _ReportFlowScope extends InheritedWidget {
  const _ReportFlowScope({required this.flow, required super.child});
  final _ReportFlow flow;
  @override
  bool updateShouldNotify(_ReportFlowScope oldWidget) => oldWidget.flow != flow;
}

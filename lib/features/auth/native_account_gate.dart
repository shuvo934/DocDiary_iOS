import 'dart:async';

import 'package:flutter/material.dart';

import '../dashboard/native_dashboard_dialogs.dart';
import '../dashboard/native_dashboard_layout.dart';
import 'auth_controller.dart';

/// A profile/access failure must cover the dashboard, including cold restore
/// and account switching, rather than falling back to a dismissible login error.
class NativeAccountGate extends StatefulWidget {
  const NativeAccountGate({super.key, required this.auth});
  final AuthController auth;

  @override
  State<NativeAccountGate> createState() => _NativeAccountGateState();
}

class _NativeAccountGateState extends State<NativeAccountGate> {
  final _dialogs = NativeDashboardDialogOwner();
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final revision = ++_revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && revision == _revision) {
        unawaited(_present(revision));
      }
    });
  }

  Future<void> _present(int revision) async {
    bool current() => mounted && revision == _revision;
    final auth = widget.auth;
    if (auth.stage == AuthStage.accountBlocked) {
      final failure = auth.accessFailure;
      if (failure == null) {
        return;
      }
      final accepted = await _dialogs.show<bool>(
        context,
        NativeDashboardMessageDialog(
          title: failure.title,
          message: failure.message,
        ),
      );
      if (current() &&
          auth.stage == AuthStage.accountBlocked &&
          accepted == true) {
        await auth.acknowledgeAccess();
      }
      return;
    }
    while (current() && auth.stage == AuthStage.accountError) {
      if (!mounted) {
        return;
      }
      final choice = await _dialogs.show<DashboardErrorChoice>(
        context,
        NativeDashboardErrorDialog(
          failure: auth.error ?? 'Server problem or Internet not connected',
        ),
      );
      if (!current() ||
          auth.stage != AuthStage.accountError ||
          choice == null) {
        return;
      }
      switch (choice) {
        case DashboardErrorChoice.logOut:
          await auth.logout();
          return;
        case DashboardErrorChoice.retry:
          await auth.retryAccount();
          return;
        case DashboardErrorChoice.exit:
          if (!mounted) {
            return;
          }
          await _dialogs.show<bool>(context, nativeDashboardExitHelp);
      }
    }
  }

  @override
  void dispose() {
    ++_revision;
    _dialogs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const NativeDashboardGateBackground();
}

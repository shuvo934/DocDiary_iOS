import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../splash/native_splash_screen.dart';
import 'app_update_controller.dart';

class NativeStartupUpdateGate extends StatefulWidget {
  const NativeStartupUpdateGate({super.key, required this.updates});
  final AppUpdateController updates;
  @override
  State<NativeStartupUpdateGate> createState() =>
      _NativeStartupUpdateGateState();
}

class _NativeStartupUpdateGateState extends State<NativeStartupUpdateGate> {
  NavigatorState? _navigator;
  DialogRoute<void>? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_present());
      }
    });
  }

  Future<void> _present() async {
    final updates = widget.updates;
    final stage = updates.stage;
    final offer = updates.offer;
    if (stage != AppUpdateStage.required &&
        stage != AppUpdateStage.failed &&
        stage != AppUpdateStage.cancelled) {
      return;
    }
    final navigator = Navigator.of(context);
    _navigator = navigator;
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        void close() => Navigator.pop(dialogContext);
        Widget action(String key, String label, VoidCallback onPressed) =>
            TextButton(
              key: Key(key),
              onPressed: onPressed,
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  color: DocColors.greenSea,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
        final failed = stage == AppUpdateStage.failed;
        final cancelled = stage == AppUpdateStage.cancelled;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            key: const Key('startup_update_dialog'),
            title: Row(
              children: [
                Image.asset(
                  'assets/images/doc_diary_default.png',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    failed ? 'Update Failed!' : 'Update Required',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                failed
                    ? 'Failed to update the app. Please try again.'
                    : cancelled
                    ? 'DocDiary needs the available update before you continue. '
                        'Use the Home gesture or Home button to leave the app, or retry the update.'
                    : 'A new version of DocDiary (${offer?.storeVersion ?? ''}) is available. '
                        'Please update the app to continue.',
                style: const TextStyle(fontFamily: 'Roboto', fontSize: 16),
              ),
            ),
            actions: [
              if (!cancelled)
                action('startup_update_cancel', 'Cancel', () {
                  close();
                  if (failed) {
                    updates.cancelFailure();
                  } else {
                    updates.cancelUpdate();
                  }
                }),
              action(
                failed || cancelled
                    ? 'startup_update_retry'
                    : 'startup_update_open',
                failed || cancelled ? 'Retry' : 'Update',
                () {
                  close();
                  if (failed || cancelled) {
                    unawaited(updates.check());
                  } else {
                    unawaited(updates.update());
                  }
                },
              ),
            ],
          ),
        );
      },
    );
    _route = route;
    await navigator.push(route);
  }

  @override
  void dispose() {
    final navigator = _navigator;
    final route = _route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator != null &&
          navigator.mounted &&
          route != null &&
          route.isActive) {
        navigator.removeRoute(route);
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const PopScope(canPop: false, child: NativeSplashScreen());
}

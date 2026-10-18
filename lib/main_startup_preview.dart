import 'dart:async';

import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'features/startup/app_store_update.dart';
import 'features/startup/app_update_controller.dart';
import 'features/startup/native_startup_update_gate.dart';

/// Offline fixtures only. No backend, device metadata or App Store is accessed.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const mode = String.fromEnvironment(
    'STARTUP_PREVIEW',
    defaultValue: 'required',
  );
  final checker = _PreviewChecker(mode);
  late final AppUpdateController updates;
  updates = AppUpdateController(
    checker: checker,
    openStore: (_) async {
      if (mode == 'updated') {
        checker.updated = true;
      }
      if (mode != 'launch_failed') {
        updates.didChangeAppLifecycleState(AppLifecycleState.paused);
        updates.didChangeAppLifecycleState(AppLifecycleState.resumed);
        return true;
      }
      return false;
    },
  );
  runApp(_StartupPreview(updates: updates));
}

class _PreviewChecker implements AppUpdateChecker {
  _PreviewChecker(this.mode);
  final String mode;
  bool updated = false;

  @override
  Future<AppUpdateOffer?> check() async {
    if (mode == 'offline') {
      throw StateError('Synthetic offline fixture');
    }
    if (updated || mode == 'current' || mode == 'unpublished') {
      return null;
    }
    return AppUpdateOffer(
      installedVersion: '0.1.0',
      storeVersion: '0.2.0',
      storeUrl: Uri.parse('https://apps.apple.com/bd/app/id123456789'),
    );
  }
}

class _StartupPreview extends StatefulWidget {
  const _StartupPreview({required this.updates});
  final AppUpdateController updates;

  @override
  State<_StartupPreview> createState() => _StartupPreviewState();
}

class _StartupPreviewState extends State<_StartupPreview> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.updates.check());
  }

  @override
  void dispose() {
    widget.updates.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: docDiaryTheme(),
    home: ListenableBuilder(
      listenable: widget.updates,
      builder:
          (context, _) =>
              widget.updates.allowsStartup
                  ? const Scaffold(
                    body: SafeArea(
                      child: Center(child: Text('Startup preview complete')),
                    ),
                  )
                  : NativeStartupUpdateGate(
                    key: ValueKey(widget.updates.revision),
                    updates: widget.updates,
                  ),
    ),
  );
}

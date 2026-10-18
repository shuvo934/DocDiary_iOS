import 'dart:async';

import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/native_account_gate.dart';
import 'features/dashboard/dashboard_repository.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/dashboard/dashboard_services.dart';
import 'features/splash/native_splash_screen.dart';
import 'features/startup/app_update_controller.dart';
import 'features/startup/native_startup_update_gate.dart';

class DocDiaryApp extends StatefulWidget {
  const DocDiaryApp({
    super.key,
    required this.auth,
    required this.dashboard,
    this.onDispose,
    this.initializeOnStart = true,
    this.dashboardServices = const DashboardServices(),
    this.updates,
  });
  final AuthController auth;
  final DashboardRepository dashboard;
  final VoidCallback? onDispose;
  final bool initializeOnStart;
  final DashboardServices dashboardServices;
  final AppUpdateController? updates;

  @override
  State<DocDiaryApp> createState() => _DocDiaryAppState();
}

class _DocDiaryAppState extends State<DocDiaryApp> with WidgetsBindingObserver {
  Timer? _splashTimer;
  late bool _showStartupSplash;
  bool _restoringStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.updates?.addListener(_updatesChanged);
    _showStartupSplash = widget.initializeOnStart;
    if (widget.initializeOnStart) {
      final updates = widget.updates;
      if (updates == null) {
        _restoreSession();
      } else {
        unawaited(updates.check());
      }
    }
  }

  void _updatesChanged() {
    if (mounted && widget.initializeOnStart && widget.updates!.allowsStartup) {
      _restoreSession();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.updates?.didChangeAppLifecycleState(state);
  }

  void _restoreSession() {
    if (_restoringStarted || !mounted) {
      return;
    }
    _restoringStarted = true;
    unawaited(widget.auth.initialize());
    // Match MainActivity's 1000ms delay, starting after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _splashTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() => _showStartupSplash = false);
        }
      });
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.updates?.removeListener(_updatesChanged);
    widget.updates?.dispose();
    widget.auth.dispose();
    widget.onDispose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DocDiary',
    debugShowCheckedModeBanner: false,
    theme: docDiaryTheme(),
    home: ListenableBuilder(
      listenable: Listenable.merge([
        widget.auth,
        if (widget.updates != null) widget.updates!,
      ]),
      builder: (context, _) {
        final auth = widget.auth;
        final updates = widget.updates;
        if (widget.initializeOnStart &&
            updates != null &&
            !updates.allowsStartup) {
          return NativeStartupUpdateGate(
            key: ValueKey('startup:${updates.revision}'),
            updates: updates,
          );
        }
        if (_showStartupSplash || auth.stage == AuthStage.booting) {
          return const NativeSplashScreen();
        }
        return switch (auth.stage) {
          AuthStage.authenticated => DashboardScreen(
            key: ValueKey(
              '${auth.session!.center.baseUri}:${auth.session!.account.key}',
            ),
            auth: auth,
            repository: widget.dashboard,
            services: widget.dashboardServices,
          ),
          AuthStage.accountBlocked ||
          AuthStage.accountError => NativeAccountGate(
            key: ValueKey('${auth.stage}:${auth.accountGateRevision}'),
            auth: auth,
          ),
          AuthStage.chooseCenter ||
          AuthStage.chooseAccount => SelectionScreen(controller: auth),
          AuthStage.reconnect => Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/doc_diary_default.png',
                          width: 88,
                        ),
                        const SizedBox(height: 24),
                        ErrorNotice(
                          auth.error ?? 'Please reconnect to continue.',
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: auth.initialize,
                          child: const Text('Retry'),
                        ),
                        TextButton(
                          onPressed: () async => auth.logout(),
                          child: const Text('Return to Login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          AuthStage.booting => const NativeSplashScreen(),
          AuthStage.signingIn => const NativeLoginProgressScreen(),
          AuthStage.signingOut => Scaffold(
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/doc_diary_logo_shadow.png',
                      width: 200,
                    ),
                    const SizedBox(height: 32),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    const Text('Logging out…'),
                  ],
                ),
              ),
            ),
          ),
          AuthStage.signedOut ||
          AuthStage.discovering => LoginScreen(controller: auth),
        };
      },
    ),
  );
}

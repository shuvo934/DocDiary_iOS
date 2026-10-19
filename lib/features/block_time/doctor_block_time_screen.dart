import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/failure.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../dashboard/native_dashboard_dialogs.dart';
import 'doctor_block_time_models.dart';
import 'doctor_block_time_repository.dart';
import 'native_doctor_block_time_layout.dart';

class DoctorBlockTimeScreen extends StatefulWidget {
  const DoctorBlockTimeScreen({
    super.key,
    required this.auth,
    required this.repository,
  });
  final AuthController auth;
  final DoctorBlockTimeRepository repository;
  @override
  State<DoctorBlockTimeScreen> createState() => _DoctorBlockTimeScreenState();
}

class _DoctorBlockTimeScreenState extends State<DoctorBlockTimeScreen>
    with WidgetsBindingObserver {
  late final AuthSession _session;
  late DoctorBlockWindow _window;
  DoctorBlockCalendar? _calendar;
  final _dialogs = NativeDashboardDialogOwner();
  ModalBottomSheetRoute<void>? _sheet;
  NavigatorState? _sheetNavigator;
  bool _invalidSession = false, _loading = true, _foreground = true;
  int _operation = 0;
  bool get _current =>
      mounted &&
      !_invalidSession &&
      widget.auth.stage == AuthStage.authenticated &&
      widget.auth.session == _session;
  bool _alive(int operation) =>
      _current && _foreground && operation == _operation;
  @override
  void initState() {
    super.initState();
    _window = DoctorBlockWindow(widget.repository.now());
    final session = widget.auth.session;
    if (session == null ||
        widget.auth.profile == null ||
        session.account.role != AccountRole.doctor) {
      _invalidSession = true;
      _loading = false;
      return;
    }
    _session = session;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) {
        unawaited(_load());
      }
    });
  }

  void _authChanged() {
    if (!_current) {
      ++_operation;
      _dialogs.close();
      _closeSheet();
      if (mounted) {
        setState(() {
          _calendar = null;
          _loading = true;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _foreground = false;
      ++_operation;
      _dialogs.close();
      _closeSheet();
    } else if (!_foreground) {
      _foreground = true;
      if (_current) {
        unawaited(_load());
      }
    }
  }

  bool _deny(Object failure) {
    if (failure is AppFailure && failure.kind == FailureKind.denied) {
      widget.auth.blockAccess(
        failure is AccountAccessFailure
            ? failure
            : const AccountAccessFailure.mobileAccess(),
      );
      return true;
    }
    return false;
  }

  Future<void> _load() async {
    if (!_current || !_foreground) {
      return;
    }
    final operation = ++_operation,
        window = DoctorBlockWindow(widget.repository.now());
    setState(() {
      _loading = true;
      _window = window;
      _calendar = null;
    });
    try {
      // Recheck live doctor/access without another loginLog or expiry write.
      final profile = await widget.auth.profiles.open(
        _session,
        recordLogin: false,
        isCurrent: () => _alive(operation),
      );
      final calendar = await widget.repository.load(
        _session,
        profile,
        window,
        isCurrent: () => _alive(operation),
      );
      if (!_alive(operation)) {
        return;
      }
      setState(() {
        _calendar = calendar;
        _loading = false;
      });
    } catch (failure) {
      if (!mounted ||
          !_alive(operation) ||
          failure is ObsoleteRequest ||
          _deny(failure)) {
        return;
      }
      setState(() => _loading = false);
      final retry = await _dialogs.show<bool>(
        context,
        AlertDialog(
          key: const Key('block_time_error'),
          title: Text(
            'Error!',
            style: dashboardDialogText(20, weight: FontWeight.w500),
          ),
          content: SingleChildScrollView(
            child: Text(
              dashboardErrorMessage(failure),
              style: dashboardDialogText(16),
            ),
          ),
          actions: [
            TextButton(
              key: const Key('block_time_error_exit'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Exit',
                style: dashboardDialogText(14, color: DocColors.primary),
              ),
            ),
            TextButton(
              key: const Key('block_time_error_retry'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Retry',
                style: dashboardDialogText(14, color: DocColors.primary),
              ),
            ),
          ],
        ),
      );
      if (!_alive(operation)) {
        return;
      }
      if (retry == true) {
        await _load();
      } else if (retry == false) {
        await _back();
      }
    }
  }

  Future<void> _showDay(DoctorBlockedDay day) async {
    if (!_current ||
        !_foreground ||
        _loading ||
        _dialogs.isOpen ||
        _sheet != null) {
      return;
    }
    final navigator = Navigator.of(context);
    final route = ModalBottomSheetRoute<void>(
      builder: (_) => NativeDoctorBlockTimeSheet(day: day),
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      modalBarrierColor: Colors.black54,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
    );
    _sheetNavigator = navigator;
    _sheet = route;
    try {
      await navigator.push<void>(route);
    } finally {
      if (identical(_sheet, route)) {
        _sheet = null;
      }
    }
  }

  void _closeSheet() {
    final route = _sheet, navigator = _sheetNavigator;
    _sheet = null;
    if (route == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator != null && navigator.mounted && route.isActive) {
        navigator.removeRoute(route);
      }
    });
  }

  Future<void> _back() async {
    if (mounted && !_loading && !_dialogs.isOpen && _sheet == null) {
      await Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    ++_operation;
    _dialogs.dispose();
    _closeSheet();
    if (!_invalidSession) {
      widget.auth.removeListener(_authChanged);
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _invalidSession
          ? Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Could Not Get Doctor Data. Please return to Login.',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => unawaited(_back()),
                        child: const Text('Back'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          : PopScope(
            canPop: !_loading,
            child: NativeDoctorBlockTimeLayout(
              window: _window,
              today: widget.repository.now(),
              calendar: _calendar,
              loading: _loading,
              onBack: () => unawaited(_back()),
              onDay: (day) => unawaited(_showDay(day)),
            ),
          );
}

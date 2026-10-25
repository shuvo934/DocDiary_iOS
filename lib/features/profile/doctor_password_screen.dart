import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_toast.dart';

import '../../core/app_theme.dart';
import '../../core/failure.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../dashboard/native_dashboard_dialogs.dart';
import 'doctor_password_repository.dart';
import 'native_doctor_password_layout.dart';

class DoctorPasswordScreen extends StatefulWidget {
  const DoctorPasswordScreen({
    super.key,
    required this.auth,
    required this.repository,
  });
  final AuthController auth;
  final DoctorPasswordRepository repository;
  @override
  State<DoctorPasswordScreen> createState() => _DoctorPasswordScreenState();
}

class _DoctorPasswordScreenState extends State<DoctorPasswordScreen>
    with WidgetsBindingObserver {
  final _toasts = AppToastOwner();
  late final AuthSession _session;
  final _currentPassword = TextEditingController(),
      _newPassword = TextEditingController(),
      _confirmPassword = TextEditingController();
  final _currentFocus = FocusNode(),
      _newFocus = FocusNode(),
      _confirmFocus = FocusNode();
  final _dialogs = NativeDashboardDialogOwner();
  String? _currentHelper, _newHelper, _confirmHelper;
  bool _invalidSession = false,
      _foreground = true,
      _busy = false,
      _saving = false;
  bool _remoteUpdated = false;
  int _operation = 0;
  Completer<void>? _resume;
  bool get _current =>
      mounted &&
      !_invalidSession &&
      widget.auth.stage == AuthStage.authenticated &&
      widget.auth.session == _session;
  bool current(int operation) => _current && operation == _operation;
  bool get _canAct =>
      _current &&
      _foreground &&
      !_busy &&
      !_saving &&
      !_remoteUpdated &&
      !_dialogs.isOpen;

  @override
  void initState() {
    super.initState();
    final session = widget.auth.session;
    if (session == null ||
        widget.auth.profile == null ||
        session.account.role != AccountRole.doctor) {
      _invalidSession = true;
      return;
    }
    _session = session;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.auth.addListener(_authChanged);
  }

  void _wake() {
    final pending = _resume;
    _resume = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
  }

  Future<bool> _ready(int operation) async {
    while (current(operation) && !_foreground) {
      await (_resume ??= Completer<void>()).future;
    }
    return current(operation);
  }

  void _authChanged() {
    if (!_current) {
      _toasts.clear();
      ++_operation;
      _wake();
      _dialogs.close();
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      if (mounted) {
        setState(() => _busy = true);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_saving || _remoteUpdated) {
      _foreground = foreground;
      if (foreground) {
        _wake();
      }
      return;
    }
    if (!foreground) {
      _foreground = false;
      ++_operation;
      _dialogs.close();
    } else if (!_foreground) {
      _foreground = true;
      if (_current) {
        unawaited(_checkAccess());
      }
    }
  }

  Future<void> _checkAccess() async {
    if (!_current || !_foreground || _saving || _remoteUpdated) {
      return;
    }
    final operation = ++_operation;
    setState(() => _busy = true);
    try {
      await widget.auth.profiles.open(
        _session,
        recordLogin: false,
        isCurrent: () => current(operation) && _foreground,
      );
      if (current(operation) && _foreground) {
        setState(() => _busy = false);
      }
    } catch (failure) {
      if (!current(operation) || !_foreground || _deny(failure)) {
        return;
      }
      setState(() => _busy = false);
      final retry = await _error(failure, operation);
      if (!current(operation) || !mounted) {
        return;
      }
      if (retry == true) {
        await _checkAccess();
      } else if (retry == false) {
        await _back();
      }
    }
  }

  Future<bool?> _error(
    Object failure,
    int operation, {
    bool storage = false,
  }) async {
    if (!await _ready(operation) || !mounted) {
      return null;
    }
    return await _dialogs.show<bool>(
      context,
      AlertDialog(
        key: Key(storage ? 'password_storage_error' : 'password_error'),
        title: Text(
          'Error!',
          style: dashboardDialogText(20, weight: FontWeight.w500),
        ),
        content: SingleChildScrollView(
          child: Text(
            storage
                ? 'Password Updated Successfully.\nSaved sign-in could not be updated.\n${dashboardFailureDetail(failure)}.\nPlease try again.'
                : dashboardErrorMessage(failure),
            style: dashboardDialogText(16),
          ),
        ),
        actions: [
          if (!storage)
            TextButton(
              key: const Key('password_error_exit'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Exit',
                style: dashboardDialogText(14, color: DocColors.primary),
              ),
            ),
          TextButton(
            key: Key(
              storage ? 'password_storage_retry' : 'password_error_retry',
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Retry',
              style: dashboardDialogText(14, color: DocColors.primary),
            ),
          ),
        ],
      ),
      dismissible: !storage,
    );
  }

  void _notice(String text) {
    if (_current && _foreground) {
      _toasts.show(context, text);
    }
  }

  Future<void> _back() async {
    if (_busy || _saving || _remoteUpdated) {
      _notice('Please wait while loading');
      return;
    }
    await Navigator.of(context).maybePop();
  }

  Future<void> _update() async {
    if (!_canAct) {
      return;
    }
    FocusScope.of(context).unfocus();
    final change = DoctorPasswordChange(
      current: _currentPassword.text,
      next: _newPassword.text,
      confirm: _confirmPassword.text,
    );
    final problem = change.validate(_session.credentials.password);
    if (problem != null) {
      setState(() {
        switch (problem.field) {
          case DoctorPasswordField.current:
            _currentHelper = problem.helper;
            break;
          case DoctorPasswordField.newPassword:
            _newHelper = problem.helper;
            break;
          case DoctorPasswordField.confirm:
            _confirmHelper = problem.helper;
            break;
        }
      });
      _notice(problem.notice);
      return;
    }
    final operation = ++_operation;
    bool alive() => current(operation);
    setState(() {
      _saving = true;
      _busy = true;
    });
    try {
      while (await _ready(operation)) {
        setState(() => _busy = true);
        try {
          if (!_remoteUpdated) {
            final profile = await widget.auth.profiles.open(
              _session,
              recordLogin: false,
              isCurrent: () => alive() && _foreground,
            );
            await widget.repository.update(
              _session,
              profile,
              change,
              isCurrent: alive,
              isForeground: () => _foreground,
            );
            _remoteUpdated = true;
          }
          if (!await _ready(operation)) {
            return;
          }
          await widget.auth.persistPasswordChange(
            _session,
            change.confirm,
            isCurrent: alive,
          );
          if (!await _ready(operation) || !mounted) {
            return;
          }
          setState(() => _busy = false);
          final acknowledged = await _dialogs.show<bool>(
            context,
            const NativeDashboardMessageDialog(
              key: Key('password_success'),
              title: 'Success!',
              message: 'Password Updated Successfully. Please log in again.',
              button: 'OK',
            ),
          );
          if (acknowledged == true && await _ready(operation)) {
            widget.auth.finishPasswordChange(_session);
          }
          return;
        } catch (failure) {
          if (!alive() || _deny(failure)) {
            return;
          }
          if (!await _ready(operation)) {
            return;
          }
          setState(() => _busy = false);
          final retry = await _error(
            failure is ObsoleteRequest
                ? const AppFailure(
                  'The app was paused. Please retry when ready.',
                )
                : failure,
            operation,
            storage: _remoteUpdated,
          );
          if (!alive()) {
            return;
          }
          if (retry == true) {
            continue;
          }
          if (retry == false && mounted) {
            setState(() {
              _saving = false;
              _busy = false;
            });
            Navigator.of(context).pop();
          }
          return;
        }
      }
    } finally {
      if (alive()) {
        setState(() {
          _saving = false;
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _toasts.dispose();
    ++_operation;
    _wake();
    _dialogs.dispose();
    widget.auth.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in [
      _currentPassword,
      _newPassword,
      _confirmPassword,
    ]) {
      controller.dispose();
    }
    for (final focus in [_currentFocus, _newFocus, _confirmFocus]) {
      focus.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _invalidSession
          ? Scaffold(
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Could Not Get Doctor Data. Please return to Login.',
                    ),
                    TextButton(
                      onPressed: () => unawaited(_back()),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            ),
          )
          : PopScope(
            canPop: !_busy && !_saving && !_remoteUpdated,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && (_busy || _saving || _remoteUpdated)) {
                _notice('Please wait while loading');
              }
            },
            child: NativeDoctorPasswordLayout(
              loading: _busy,
              current: _currentPassword,
              next: _newPassword,
              confirm: _confirmPassword,
              currentFocus: _currentFocus,
              nextFocus: _newFocus,
              confirmFocus: _confirmFocus,
              currentHelper: _currentHelper,
              nextHelper: _newHelper,
              confirmHelper: _confirmHelper,
              onCurrentChanged: (_) => setState(() => _currentHelper = null),
              onNextChanged: (_) => setState(() => _newHelper = null),
              onConfirmChanged: (_) => setState(() => _confirmHelper = null),
              onClose: () => unawaited(_back()),
              onUpdate: () => unawaited(_update()),
            ),
          );
}

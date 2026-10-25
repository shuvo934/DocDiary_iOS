import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/app_toast.dart';
import '../../../core/failure.dart';
import '../../auth/account_access.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../../dashboard/native_dashboard_dialogs.dart';
import '../hr_dashboard_repository.dart';
import 'leave_approval_models.dart';
import 'leave_approval_repository.dart';
import 'native_leave_approval_layout.dart';
import 'native_leave_request_dialog.dart';

class LeaveApprovalScreen extends StatefulWidget {
  const LeaveApprovalScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.seed,
  });
  final AuthController auth;
  final LeaveApprovalRepository repository;
  final LeaveApprovalSeed? seed;
  @override
  State<LeaveApprovalScreen> createState() => _LeaveApprovalScreenState();
}

class _LeaveApprovalScreenState extends State<LeaveApprovalScreen>
    with WidgetsBindingObserver {
  late final AuthSession _session;
  final _dialogs = NativeDashboardDialogOwner();
  final _toasts = AppToastOwner();
  final _comments = TextEditingController();
  LeaveApprovalRequest? _selected;
  LeaveApprovalDetail? _detail;
  LeaveApprovalAction? _completed;
  bool _invalid = false,
      _foreground = true,
      _busy = false,
      _denied = false,
      _writing = false,
      _restoreAfterWrite = false;
  int _operation = 0;
  bool get _current =>
      mounted &&
      !_invalid &&
      widget.auth.stage == AuthStage.authenticated &&
      widget.auth.session == _session;
  bool _alive(int operation) =>
      _current && _foreground && operation == _operation;
  bool get _ready =>
      _current &&
      _foreground &&
      !_busy &&
      !_denied &&
      !_writing &&
      !_dialogs.isOpen &&
      _completed == null;

  @override
  void initState() {
    super.initState();
    final session = widget.auth.session;
    if (session == null ||
        widget.auth.profile == null ||
        session.account.role != AccountRole.admin) {
      _invalid = true;
      _denied = true;
      return;
    }
    _session = session;
    final seed = widget.seed?.request;
    if (seed != null && seed.valid) _selected = seed;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    widget.auth.addListener(_authChanged);
    _comments.addListener(_commentsChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) {
        unawaited(_selected == null ? _openPicker() : _loadDetail());
      }
    });
  }

  void _commentsChanged() {
    if (mounted) setState(() {});
  }

  void _authChanged() {
    if (!_current) {
      ++_operation;
      _dialogs.close();
      _toasts.clear();
      _comments.clear();
      if (mounted) {
        setState(() {
          _selected = null;
          _detail = null;
          _busy = true;
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
      _toasts.clear();
      if (mounted) setState(() {});
    } else if (!_foreground) {
      _foreground = true;
      if (_writing) {
        _restoreAfterWrite = true;
      } else if (_current) {
        unawaited(_restore());
      }
    }
  }

  Future<AccountProfile> _profile(int operation) async {
    final profile = await widget.auth.profiles.open(
      _session,
      recordLogin: false,
      isCurrent: () => _alive(operation),
    );
    widget.repository.guard(_session, profile, () => _alive(operation));
    return profile;
  }

  bool _accessFailure(Object failure, int operation) {
    if (!_alive(operation)) return true;
    if (failure is HrModuleUnavailable) {
      _dialogs.close();
      _comments.clear();
      setState(() {
        _denied = true;
        _busy = false;
        _selected = null;
        _detail = null;
      });
      return true;
    }
    if (failure is AppFailure && failure.kind == FailureKind.denied) {
      widget.auth.blockAccess(
        failure is AccountAccessFailure
            ? failure
            : const AccountAccessFailure.mobileAccess(),
      );
      return true;
    }
    return failure is ObsoleteRequest;
  }

  Future<void> _openPicker() async {
    if (!_ready) return;
    FocusScope.of(context).unfocus();
    final operation = ++_operation;
    final picker = ValueNotifier(const LeaveRequestPickerState(waiting: true));
    Future<void> load() async {
      if (!_alive(operation)) return;
      picker.value = const LeaveRequestPickerState(waiting: true);
      try {
        final profile = await _profile(operation);
        final rows = await widget.repository.pending(
          _session,
          profile,
          isCurrent: () => _alive(operation),
        );
        if (_alive(operation)) {
          picker.value = LeaveRequestPickerState(rows: rows);
        }
      } catch (failure) {
        if (!_accessFailure(failure, operation)) {
          picker.value = LeaveRequestPickerState(failure: failure);
        }
      }
    }

    // The dialog owns its search text; callbacks always select the actual row.
    final future = _dialogs.show<LeaveApprovalRequest>(
      context,
      NativeLeaveRequestDialog(
        state: picker,
        onReload: () {
          if (!picker.value.waiting) unawaited(load());
        },
      ),
      barrierColor: const Color(0xcc000000),
    );
    unawaited(load());
    final selected = await future;
    // A stale read may still complete after this notifier is disposed. Every
    // read above is fenced by the operation generation, including CANCEL.
    final accepted = _alive(operation) && !_denied;
    if (accepted) ++_operation;
    picker.dispose();
    if (!accepted || selected == null) return;
    setState(() {
      _selected = selected;
      _detail = null;
    });
    await _loadDetail();
  }

  Future<void> _loadDetail({bool restore = false}) async {
    if (!_current || !_foreground || _writing || _dialogs.isOpen) return;
    if (_selected == null) {
      await _openPicker();
      return;
    }
    final operation = ++_operation;
    final selected = _selected!;
    setState(() {
      _busy = true;
      _detail = null;
    });
    try {
      final profile = await _profile(operation);
      if (restore) {
        final pending = await widget.repository.pending(
          _session,
          profile,
          isCurrent: () => _alive(operation),
        );
        if (!pending.any(selected.sameRequest)) {
          throw const LeaveRequestNoLongerPending();
        }
      }
      final detail = await widget.repository.detail(
        _session,
        profile,
        selected,
        isCurrent: () => _alive(operation),
      );
      if (!_alive(operation)) return;
      if (detail == null) throw const LeaveRequestNoLongerPending();
      setState(() {
        _busy = false;
        _detail = detail;
      });
    } catch (failure) {
      if (_accessFailure(failure, operation)) return;
      setState(() => _busy = false);
      if (failure is LeaveRequestNoLongerPending) {
        setState(() {
          _selected = null;
          _detail = null;
        });
        _comments.clear();
        await _message('This leave request is no longer pending.');
      } else {
        final retry = await _error(failure);
        if (!_alive(operation)) return;
        if (retry == true) {
          await _loadDetail(restore: restore);
        } else {
          await _back();
        }
      }
    }
  }

  Future<void> _restore() async {
    if (!_current || !_foreground || _writing) return;
    // Let owner.close remove any stale confirmation before opening another route.
    await WidgetsBinding.instance.endOfFrame;
    if (!_current || !_foreground) return;
    setState(() => _busy = false);
    if (_completed != null) {
      final operation = ++_operation;
      try {
        await _profile(operation);
        if (_alive(operation)) await _success(_completed!);
      } catch (failure) {
        if (!_accessFailure(failure, operation)) {
          final retry = await _error(failure);
          if (_alive(operation) && retry == true) await _restore();
        }
      }
    } else if (_selected == null) {
      await _openPicker();
    } else {
      await _loadDetail(restore: true);
    }
  }

  Future<void> _act(LeaveApprovalAction action) async {
    if (!_ready || _selected == null || _detail == null) return;
    FocusScope.of(context).unfocus();
    if (action == LeaveApprovalAction.approve && !_detail!.hasEnoughBalance) {
      await _message(
        'Leave Balance is lower than Total Leave Days.',
        title: 'Warning!',
      );
      return;
    }
    final comment = _comments.text;
    if (action == LeaveApprovalAction.reject && comment.trim().isEmpty) {
      _toast('Please mention reason for reject');
      return;
    }
    final operation = _operation;
    final yes = await _dialogs.show<bool>(
      context,
      AlertDialog(
        key: const Key('leave_approval_confirm'),
        title: Text(
          '${action.label} Leave!',
          style: dashboardDialogText(20, weight: FontWeight.w500),
        ),
        content: Text(
          'Do you want ${action.name} this leave?',
          style: dashboardDialogText(16),
        ),
        actions: [
          TextButton(
            key: const Key('leave_approval_no'),
            onPressed: () => _answer(false, operation),
            child: const Text('NO'),
          ),
          TextButton(
            key: const Key('leave_approval_yes'),
            onPressed: () => _answer(true, operation),
            child: const Text('YES'),
          ),
        ],
      ),
      dismissible: true,
    );
    if (!mounted || !_alive(operation) || yes != true || !_ready) return;
    var prescriptionChecked = false;
    if (action == LeaveApprovalAction.approve && _detail!.isSickLeave) {
      final checked = await _dialogs.show<bool>(
        context,
        AlertDialog(
          key: const Key('leave_approval_prescription'),
          title: Text(
            'Prescription Check!',
            style: dashboardDialogText(20, weight: FontWeight.w500),
          ),
          content: Text(
            'Did you checked prescription of the applicant?',
            style: dashboardDialogText(16),
          ),
          actions: [
            TextButton(
              key: const Key('leave_approval_prescription_no'),
              onPressed: () => _answer(false, operation),
              child: const Text('NO'),
            ),
            TextButton(
              key: const Key('leave_approval_prescription_yes'),
              onPressed: () => _answer(true, operation),
              child: const Text('YES'),
            ),
          ],
        ),
        dismissible: true,
      );
      // Native YES and NO both proceed, setting P_SL_CHECK to 1 or 0.
      // Dismissal/background invalidation never means an implicit NO.
      if (!_alive(operation) || checked == null || !_ready) return;
      prescriptionChecked = checked;
    }
    await _submit(action, comment, prescriptionChecked: prescriptionChecked);
  }

  void _answer(bool answer, int operation) {
    if (_alive(operation) && _dialogs.isOpen) {
      Navigator.pop(context, answer);
    }
  }

  Future<void> _submit(
    LeaveApprovalAction action,
    String comment, {
    required bool prescriptionChecked,
  }) async {
    if (!_ready || _selected == null || _detail == null) return;
    final operation = ++_operation;
    final request = _selected!, detail = _detail!;
    setState(() {
      _busy = true;
      _writing = true;
    });
    LeaveApprovalResult? result;
    Object? error;
    try {
      final profile = await _profile(operation);
      result = await widget.repository.submit(
        _session,
        profile,
        request,
        detail,
        action,
        comment,
        prescriptionChecked: prescriptionChecked,
        isCurrent: () => _alive(operation),
      );
    } catch (failure) {
      error = failure;
    } finally {
      _writing = false;
    }
    if (_restoreAfterWrite && _current && _foreground) {
      _restoreAfterWrite = false;
      await _restore();
      return;
    }
    if (!mounted || !_alive(operation)) return;
    setState(() => _busy = false);
    if (error != null) {
      if (_accessFailure(error, operation)) return;
      if (error is LeaveRequestNoLongerPending) {
        setState(() {
          _selected = null;
          _detail = null;
        });
        _comments.clear();
        await _message('This leave request is no longer pending.');
      } else {
        final retry = await _error(error, writeFailure: true);
        if (!_alive(operation)) return;
        if (retry == true) await _loadDetail(restore: true);
      }
      return;
    }
    if (result!.succeeded) {
      _completed = action;
      await _success(action);
    } else {
      _toast(result.message);
    }
  }

  void _toast(String message) {
    _toasts.show(context, message);
  }

  Future<void> _success(LeaveApprovalAction action) async {
    final operation = _operation;
    await _message(action.successMessage);
    if (_alive(operation)) await _back();
  }

  Future<void> _message(String message, {String? title}) => _dialogs.show<void>(
    context,
    AlertDialog(
      key: const Key('leave_approval_message'),
      title:
          title == null
              ? null
              : Text(
                title,
                style: dashboardDialogText(20, weight: FontWeight.w500),
              ),
      content: SingleChildScrollView(
        child: Text(message, style: dashboardDialogText(16)),
      ),
      actions: [
        TextButton(
          key: const Key('leave_approval_ok'),
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  Future<bool?> _error(
    Object failure, {
    bool writeFailure = false,
  }) => _dialogs.show<bool>(
    context,
    AlertDialog(
      key: const Key('leave_approval_error'),
      title: Text(
        'Error!',
        style: dashboardDialogText(20, weight: FontWeight.w500),
      ),
      content: SingleChildScrollView(
        child: Text(
          '${dashboardErrorMessage(failure)}${writeFailure ? '\nRetry reloads the latest request. Confirm again to submit.' : ''}',
          style: dashboardDialogText(16),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('leave_approval_error_cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('leave_approval_error_retry'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Retry'),
        ),
      ],
    ),
  );
  Future<void> _back() async {
    if (mounted && !_busy && !_writing && !_dialogs.isOpen) {
      await Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_writing,
    child: NativeLeaveApprovalLayout(
      request: _selected,
      detail: _detail,
      comments: _comments,
      waiting: !_invalid && (!_current || !_foreground || _busy),
      enabled: _current && _foreground && !_denied && _completed == null,
      message:
          _denied
              ? 'Leave Approval access is not available for this account.'
              : null,
      onBack: () => unawaited(_back()),
      onSelect: () => unawaited(_openPicker()),
      onAction: (action) => unawaited(_act(action)),
    ),
  );
  @override
  void dispose() {
    _toasts.dispose();
    ++_operation;
    if (!_invalid) {
      widget.auth.removeListener(_authChanged);
      WidgetsBinding.instance.removeObserver(this);
    }
    _dialogs.dispose();
    _comments.dispose();
    super.dispose();
  }
}

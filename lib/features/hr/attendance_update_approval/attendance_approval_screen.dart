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
import 'attendance_approval_models.dart';
import 'attendance_approval_repository.dart';
import 'native_attendance_approval_layout.dart';
import 'native_attendance_request_dialog.dart';

class AttendanceApprovalScreen extends StatefulWidget {
  const AttendanceApprovalScreen({
    super.key,
    required this.auth,
    required this.repository,
  });
  final AuthController auth;
  final AttendanceApprovalRepository repository;
  @override
  State<AttendanceApprovalScreen> createState() =>
      _AttendanceApprovalScreenState();
}

class _AttendanceApprovalScreenState extends State<AttendanceApprovalScreen>
    with WidgetsBindingObserver {
  late final AuthSession _session;
  final _dialogs = NativeDashboardDialogOwner();
  final _toasts = AppToastOwner();
  final _comments = TextEditingController();
  AttendanceApprovalRequest? _selected;
  AttendanceApprovalDetail? _detail;
  AttendanceApprovalAction? _completed;
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
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    widget.auth.addListener(_authChanged);
    _comments.addListener(_commentsChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) unawaited(_openPicker());
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
    final picker = ValueNotifier(
      const AttendanceRequestPickerState(waiting: true),
    );
    Future<void> load() async {
      if (!_alive(operation)) return;
      picker.value = const AttendanceRequestPickerState(waiting: true);
      try {
        final profile = await _profile(operation);
        final rows = await widget.repository.pending(
          _session,
          profile,
          isCurrent: () => _alive(operation),
        );
        if (_alive(operation)) {
          picker.value = AttendanceRequestPickerState(rows: rows);
        }
      } catch (failure) {
        if (!_accessFailure(failure, operation)) {
          picker.value = AttendanceRequestPickerState(failure: failure);
        }
      }
    }

    // The dialog owns its search text; callbacks always select the actual row.
    final future = _dialogs.show<AttendanceApprovalRequest>(
      context,
      NativeAttendanceRequestDialog(
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
    _comments.clear();
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
          throw const AttendanceRequestNoLongerPending();
        }
      }
      final detail = await widget.repository.detail(
        _session,
        profile,
        selected,
        isCurrent: () => _alive(operation),
      );
      if (!_alive(operation)) return;
      if (detail == null) throw const AttendanceRequestNoLongerPending();
      setState(() {
        _busy = false;
        _detail = detail;
      });
    } catch (failure) {
      if (_accessFailure(failure, operation)) return;
      setState(() => _busy = false);
      if (failure is AttendanceRequestNoLongerPending) {
        setState(() {
          _selected = null;
          _detail = null;
        });
        _comments.clear();
        await _message('This attendance update request is no longer pending.');
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

  Future<void> _act(AttendanceApprovalAction action) async {
    if (!_ready || _selected == null || _detail == null) return;
    FocusScope.of(context).unfocus();
    final comment = _comments.text;
    if (action == AttendanceApprovalAction.reject && comment.trim().isEmpty) {
      _toast('Please mention reason for reject');
      return;
    }
    final operation = _operation;
    final yes = await _dialogs.show<bool>(
      context,
      AlertDialog(
        key: const Key('attendance_approval_confirm'),
        title: Text(
          '${action.label} Request!',
          style: dashboardDialogText(20, weight: FontWeight.w500),
        ),
        content: Text(
          'Do you want to ${action.name} this request?',
          style: dashboardDialogText(16),
        ),
        actions: [
          TextButton(
            key: const Key('attendance_approval_no'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO'),
          ),
          TextButton(
            key: const Key('attendance_approval_yes'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('YES'),
          ),
        ],
      ),
      dismissible: true,
    );
    if (!_alive(operation) || yes != true || !_ready) return;
    await _submit(action, comment);
  }

  Future<void> _submit(AttendanceApprovalAction action, String comment) async {
    if (!_ready || _selected == null || _detail == null) return;
    final operation = ++_operation;
    final request = _selected!, detail = _detail!;
    setState(() {
      _busy = true;
      _writing = true;
    });
    AttendanceApprovalResult? result;
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
      if (error is AttendanceRequestNoLongerPending) {
        setState(() {
          _selected = null;
          _detail = null;
        });
        _comments.clear();
        await _message('This attendance update request is no longer pending.');
      } else {
        final retry = await _error(error);
        if (!_alive(operation)) return;
        if (retry == true) await _loadDetail(restore: true);
      }
      return;
    }
    if (result!.succeeded) {
      _completed = action;
      await _success(action);
    } else if (action == AttendanceApprovalAction.approve) {
      await _message(result.message);
    } else {
      _toast(result.message);
    }
  }

  void _toast(String message) {
    _toasts.show(context, message);
  }

  Future<void> _success(AttendanceApprovalAction action) async {
    final operation = _operation;
    await _message(action.successMessage);
    if (_alive(operation)) await _back();
  }

  Future<void> _message(String message) => _dialogs.show<void>(
    context,
    AlertDialog(
      key: const Key('attendance_approval_message'),
      content: SingleChildScrollView(
        child: Text(message, style: dashboardDialogText(16)),
      ),
      actions: [
        TextButton(
          key: const Key('attendance_approval_ok'),
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  Future<bool?> _error(Object failure) => _dialogs.show<bool>(
    context,
    AlertDialog(
      key: const Key('attendance_approval_error'),
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
          key: const Key('attendance_approval_error_cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('attendance_approval_error_retry'),
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
    child: NativeAttendanceApprovalLayout(
      request: _selected,
      detail: _detail,
      comments: _comments,
      waiting: !_invalid && (!_current || !_foreground || _busy),
      enabled: _current && _foreground && !_denied && _completed == null,
      message:
          _denied
              ? 'Attendance Update Approval access is not available for this account.'
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

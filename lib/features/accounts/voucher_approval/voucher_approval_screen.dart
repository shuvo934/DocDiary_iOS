import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/app_toast.dart';
import '../../../core/failure.dart';
import '../../auth/auth_controller.dart';
import '../../dashboard/native_dashboard_dialogs.dart';
import '../accounts_dashboard_repository.dart';
import '../voucher_transaction/native_voucher_controls.dart';
import '../voucher_transaction/voucher_read_owner.dart';
import '../voucher_transaction/voucher_report_dialog.dart';
import 'native_voucher_approval_layout.dart';
import 'native_voucher_picker.dart';
import 'voucher_approval_models.dart';
import 'voucher_approval_repository.dart';

class VoucherApprovalScreen extends StatefulWidget {
  const VoucherApprovalScreen({
    super.key,
    required this.auth,
    required this.repository,
    required this.kind,
  });
  final AuthController auth;
  final VoucherApprovalRepository repository;
  final VoucherApprovalKind kind;
  @override
  State<VoucherApprovalScreen> createState() => _ApprovalState();
}

class _ApprovalState extends State<VoucherApprovalScreen> {
  late final VoucherReadOwner _owner;
  final _dialogs = NativeDashboardDialogOwner(), _toasts = AppToastOwner();
  final _scroll = ScrollController(), _horizontal = ScrollController();
  List<ApprovalVoucher> _rows = const [];
  ApprovalVoucher? _selected;
  ApprovalVoucherDetail? _detail;
  bool _busy = true,
      _writing = false,
      _needsReload = true,
      _restoreAfterWrite = false,
      _denied = false,
      _confirmationAnswered = false;
  bool get _ready =>
      _owner.current &&
      _owner.foreground &&
      !_busy &&
      !_writing &&
      !_denied &&
      !_dialogs.isOpen;

  @override
  void initState() {
    super.initState();
    _owner = VoucherReadOwner(
      widget.auth,
      widget.repository,
      onResume: () => unawaited(_resume()),
    )..addListener(_ownerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_owner.current && _owner.foreground) {
        unawaited(_loadLatest());
      } else if (mounted && !_owner.current) {
        setState(() {
          _busy = false;
          _denied = true;
        });
      }
    });
  }

  void _ownerChanged() {
    if (!_owner.current || !_owner.foreground) {
      _dialogs.close();
      _toasts.clear();
      _selected = null;
      _detail = null;
      _needsReload = true;
      if (!_owner.current) _rows = const [];
      _busy = !_owner.foreground;
    }
    if (mounted) setState(() {});
  }

  Future<void> _resume() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!_owner.current || !_owner.foreground) return;
    if (_writing) {
      _restoreAfterWrite = true;
      return;
    }
    await _loadLatest();
  }

  bool _accessFailure(Object error) {
    if (_owner.blockDenied(error)) return true;
    if (error is AccountsModuleUnavailable) {
      _dialogs.close();
      _toasts.clear();
      setState(() {
        _denied = true;
        _busy = false;
        _rows = const [];
        _selected = null;
        _detail = null;
      });
      return true;
    }
    return error is ObsoleteRequest;
  }

  Future<void> _loadLatest() async {
    if (!_owner.current || !_owner.foreground || _writing || _dialogs.isOpen) {
      return;
    }
    final op = _owner.begin();
    setState(() {
      _busy = true;
      _selected = null;
      _detail = null;
      _rows = const [];
      _needsReload = true;
    });
    try {
      final profile = await _owner.fresh(op),
          rows = await widget.repository.latest(
            _owner.session!,
            profile,
            widget.kind,
            isCurrent: () => _owner.alive(op),
          );
      if (!_owner.alive(op)) return;
      setState(() {
        _rows = rows;
        _busy = false;
        _denied = false;
        _needsReload = false;
      });
    } catch (error) {
      if (!mounted || !_owner.alive(op) || _accessFailure(error)) return;
      setState(() => _busy = false);
      final retry = await _error(error, exit: true);
      if (!_owner.alive(op)) return;
      if (retry == true) {
        await _loadLatest();
      } else {
        await _back();
      }
    }
  }

  Future<void> _openPicker() async {
    if (!_ready) return;
    if (_needsReload) await _loadLatest();
    if (!_ready || _needsReload) return;
    final op = _owner.begin();
    setState(() => _busy = true);
    try {
      await _owner.fresh(op);
    } catch (error) {
      if (!mounted || !_owner.alive(op) || _accessFailure(error)) return;
      setState(() => _busy = false);
      final retry = await _error(error);
      if (_owner.alive(op) && retry == true) await _loadLatest();
      return;
    }
    if (!mounted || !_owner.alive(op)) return;
    setState(() => _busy = false);
    final seed = _rows,
        prefix = seed.isEmpty ? '' : seed.first.prefix,
        state = ValueNotifier(VoucherPickerData(rows: seed));
    var opened = true;
    bool current() => opened && _owner.alive(op);
    Future<void> search(String query) async {
      if (!current() || state.value.busy) return;
      state.value = const VoucherPickerData(busy: true, searched: true);
      try {
        final profile = await _owner.fresh(op),
            rows = await widget.repository.search(
              _owner.session!,
              profile,
              widget.kind,
              query,
              prefix,
              isCurrent: current,
            );
        if (current()) {
          state.value = VoucherPickerData(rows: rows, searched: true);
        }
      } catch (error) {
        if (!current() || _accessFailure(error)) return;
        state.value = VoucherPickerData(searched: true, failure: error);
      }
    }

    final selected = await _dialogs.show<ApprovalVoucher>(
      context,
      NativeVoucherPicker(
        kind: widget.kind,
        prefix: prefix,
        state: state,
        onSearch: (q) => unawaited(search(q)),
        onClear: () {
          if (current() && !state.value.busy) {
            state.value = VoucherPickerData(rows: seed);
          }
        },
      ),
      barrierColor: const Color(0xcc000000),
    );
    final accept =
        current() && selected != null && state.value.rows.contains(selected);
    opened = false;
    state.dispose();
    if (!mounted || !_owner.alive(op)) return;
    if (accept) {
      await _loadDetail(selected);
    } else {
      setState(() {});
    }
  }

  Future<void> _loadDetail(ApprovalVoucher voucher) async {
    if (!_owner.current || !_owner.foreground || _writing || _dialogs.isOpen) {
      return;
    }
    final op = _owner.begin();
    setState(() {
      _busy = true;
      _selected = voucher;
      _detail = null;
    });
    try {
      final profile = await _owner.fresh(op),
          detail = await widget.repository.details(
            _owner.session!,
            profile,
            voucher,
            isCurrent: () => _owner.alive(op),
          );
      if (!_owner.alive(op)) return;
      setState(() {
        _detail = detail;
        _busy = false;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
      if (_horizontal.hasClients) _horizontal.jumpTo(0);
    } catch (error) {
      if (!mounted || !_owner.alive(op) || _accessFailure(error)) return;
      setState(() => _busy = false);
      if (error is VoucherApprovalChanged) {
        await _changed(op);
        return;
      }
      final retry = await _error(error);
      if (!_owner.alive(op)) return;
      if (retry == true) {
        await _loadDetail(voucher);
      } else {
        await _loadLatest();
      }
    }
  }

  Future<void> _report() async {
    if (!_ready || _detail == null || _detail!.empty) return;
    final op = _owner.begin(), number = _detail!.voucher.number;
    setState(() => _busy = true);
    try {
      await _owner.fresh(op);
    } catch (error) {
      if (!mounted || !_owner.alive(op) || _accessFailure(error)) return;
      setState(() => _busy = false);
      final retry = await _error(error);
      if (_owner.alive(op) && retry == true && _selected != null) {
        await _loadDetail(_selected!);
      }
      return;
    }
    if (!mounted || !_owner.alive(op)) return;
    setState(() => _busy = false);
    await _dialogs.show<void>(
      context,
      VoucherReportDialog(
        auth: widget.auth,
        repository: widget.repository,
        number: number,
        formatAmount: approvalAmount,
      ),
      barrierColor: const Color(0xcc000000),
    );
    if (mounted && _owner.alive(op)) setState(() {});
  }

  Future<void> _act() async {
    if (!_ready || _detail == null || _detail!.empty) return;
    final shown = _detail!, action = shown.action, op = _owner.begin();
    _confirmationAnswered = false;
    try {
      shown.validateAction(action);
    } catch (error) {
      await _message(
        error is AppFailure ? error.message : 'Reload this voucher.',
        title: 'Warning!',
      );
      return;
    }
    if (!mounted) return;
    final yes = await _dialogs.show<bool>(
      context,
      AlertDialog(
        key: const Key('va_confirmation'),
        title: Text('${action.label}!', style: dashboardDialogText(20)),
        content: Text(
          'Do you want to ${action.label.toLowerCase()} this voucher?',
          style: dashboardDialogText(16),
        ),
        actions: [
          TextButton(
            key: const Key('va_no'),
            onPressed: () => _answer(false, op),
            child: const Text('NO'),
          ),
          TextButton(
            key: const Key('va_yes'),
            onPressed: () => _answer(true, op),
            child: const Text('YES'),
          ),
        ],
      ),
      dismissible: true,
    );
    if (!_owner.alive(op) ||
        yes != true ||
        !_ready ||
        !identical(_detail, shown)) {
      return;
    }
    await _submit(shown, action);
  }

  void _answer(bool answer, int op) {
    if (_owner.alive(op) && _dialogs.isOpen && !_confirmationAnswered) {
      _confirmationAnswered = true;
      Navigator.pop(context, answer);
    }
  }

  Future<void> _submit(
    ApprovalVoucherDetail shown,
    VoucherApprovalAction action,
  ) async {
    if (!_ready || !identical(_detail, shown)) return;
    final op = _owner.begin();
    setState(() {
      _busy = true;
      _writing = true;
    });
    Object? failure;
    try {
      final profile = await _owner.fresh(op);
      await widget.repository.submit(
        _owner.session!,
        profile,
        shown,
        action,
        isCurrent: () => _owner.alive(op),
      );
    } catch (error) {
      failure = error;
    } finally {
      _writing = false;
    }
    if (_restoreAfterWrite && _owner.current && _owner.foreground) {
      _restoreAfterWrite = false;
      await _loadLatest();
      return;
    }
    if (!mounted || !_owner.alive(op)) return;
    setState(() => _busy = false);
    if (failure != null) {
      if (_accessFailure(failure)) return;
      if (failure is VoucherApprovalChanged) {
        await _changed(op);
        return;
      }
      setState(() {
        _needsReload = true;
        _selected = null;
        _detail = null;
      });
      final retry = await _error(failure, write: true);
      if (_owner.alive(op) && retry == true) await _loadLatest();
      return;
    }
    _toasts.show(context, action.feedback);
    await _loadLatest();
  }

  Future<void> _changed(int op) async {
    setState(() {
      _selected = null;
      _detail = null;
      _needsReload = true;
    });
    await _message(
      'This voucher changed. Please select it again.',
      title: 'Warning!',
    );
    if (_owner.alive(op)) await _loadLatest();
  }

  Future<void> _message(String message, {String? title}) => _dialogs.show<void>(
    context,
    AlertDialog(
      key: const Key('va_message'),
      title: title == null ? null : Text(title, style: dashboardDialogText(20)),
      content: Text(message, style: dashboardDialogText(16)),
      actions: [
        TextButton(
          key: const Key('va_message_ok'),
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  Future<bool?> _error(
    Object error, {
    bool exit = false,
    bool write = false,
  }) => _dialogs.show<bool>(
    context,
    AlertDialog(
      key: const Key('va_error'),
      title: Text('Error!', style: dashboardDialogText(20)),
      content: SingleChildScrollView(
        child: Text(
          write
              ? 'The voucher update could not be confirmed.\nRetry will reload its current status.'
              : dashboardErrorMessage(error),
          style: dashboardDialogText(16),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('va_error_cancel'),
          onPressed: () => Navigator.pop(context, false),
          child: Text(exit ? 'Exit' : 'Cancel'),
        ),
        TextButton(
          key: const Key('va_error_retry'),
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
  void dispose() {
    _owner.removeListener(_ownerChanged);
    _owner.dispose();
    _dialogs.dispose();
    _toasts.dispose();
    _scroll.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_writing,
    child: NativeVoucherShell(
      title: widget.kind.title,
      backKey: 'va_back',
      onBack: _busy || _writing ? null : () => unawaited(_back()),
      child:
          !_owner.current || _denied
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Accounts access is not available for this account.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              : !_owner.foreground || _busy
              ? const Center(
                child: CircularProgressIndicator(key: Key('va_loading')),
              )
              : NativeVoucherApprovalLayout(
                rows: _rows,
                kind: widget.kind,
                selected: _selected,
                detail: _detail,
                scroll: _scroll,
                horizontal: _horizontal,
                onSelect: _ready ? () => unawaited(_openPicker()) : null,
                onReport: _ready ? () => unawaited(_report()) : null,
                onAction: _ready ? () => unawaited(_act()) : null,
              ),
    ),
  );
}

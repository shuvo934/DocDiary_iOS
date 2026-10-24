import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/failure.dart';
import '../../auth/account_access.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../../dashboard/native_dashboard_dialogs.dart';
import '../hr_dashboard_repository.dart';
import 'leave_balance_models.dart';
import 'leave_balance_repository.dart';
import 'native_leave_balance_layout.dart';
import 'native_leave_balance_year_dialog.dart';

class LeaveBalanceScreen extends StatefulWidget {
  const LeaveBalanceScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.seed = const LeaveBalanceSeed(),
  });
  final AuthController auth;
  final LeaveBalanceRepository repository;
  final LeaveBalanceSeed seed;
  @override
  State<LeaveBalanceScreen> createState() => _LeaveBalanceScreenState();
}

enum _Task { entry, restore, branch, division, department, designation, report }

class _LeaveBalanceScreenState extends State<LeaveBalanceScreen>
    with WidgetsBindingObserver {
  late final AuthSession _session;
  late LeaveBalanceYear _year;
  final _dialogs = NativeDashboardDialogOwner();
  LeaveBalanceCatalog? _catalog;
  LeaveBalanceReport? _report;
  bool _invalid = false,
      _foreground = true,
      _busy = true,
      _denied = false,
      _failedLoad = false;
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
      !_dialogs.isOpen &&
      _catalog != null;

  @override
  void initState() {
    super.initState();
    _year = LeaveBalanceYear.initial(widget.seed, widget.repository.now());
    final session = widget.auth.session;
    if (session == null ||
        widget.auth.profile == null ||
        session.account.role != AccountRole.admin) {
      _invalid = true;
      _denied = true;
      _busy = false;
      return;
    }
    _session = session;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) unawaited(_run(_Task.entry, force: true));
    });
  }

  void _authChanged() {
    if (!_current) {
      ++_operation;
      _dialogs.close();
      if (mounted) {
        setState(() {
          _catalog = null;
          _report = null;
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
      if (mounted) setState(() {});
    } else if (!_foreground) {
      _foreground = true;
      if (_current) {
        unawaited(
          _run(_catalog == null ? _Task.entry : _Task.restore, force: true),
        );
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

  Future<void> _run(_Task task, {bool force = false}) async {
    if (!_current || !_foreground || _dialogs.isOpen || _busy && !force) return;
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _denied = false;
      _failedLoad = false;
      _report = null;
    });
    try {
      final profile = await _profile(operation);
      var data = _catalog;
      LeaveBalanceReport? report;
      switch (task) {
        case _Task.entry:
          final result = await widget.repository.load(
            _session,
            profile,
            widget.seed,
            _year,
            isCurrent: () => _alive(operation),
          );
          data = result.catalog;
          report = result.report;
        case _Task.restore:
          final result = await widget.repository.restore(
            _session,
            profile,
            data!,
            _year,
            isCurrent: () => _alive(operation),
          );
          data = result.catalog;
          report = result.report;
        case _Task.branch:
          data = await widget.repository.catalog(
            _session,
            profile,
            branch: data!.branch,
            branches: data.branches,
            isCurrent: () => _alive(operation),
          );
        case _Task.division:
          data = data!.withDivision(
            data.division!,
            await widget.repository.departments(
              _session,
              profile,
              data.division!.id,
              data.branch.id,
              isCurrent: () => _alive(operation),
            ),
          );
        case _Task.department:
          data = data!.withDepartment(
            data.department!,
            await widget.repository.designations(
              _session,
              profile,
              data.division!.id,
              data.department!.id,
              data.branch.id,
              isCurrent: () => _alive(operation),
            ),
          );
        case _Task.designation:
          data = data!.withDesignation(
            data.designation!,
            await widget.repository.employees(
              _session,
              profile,
              data.division!.id,
              data.department!.id,
              data.designation!.id,
              data.branch.id,
              isCurrent: () => _alive(operation),
            ),
          );
        case _Task.report:
          report = await widget.repository.report(
            _session,
            profile,
            data!.employee!.id,
            _year,
            isCurrent: () => _alive(operation),
          );
      }
      if (!_alive(operation)) return;
      setState(() {
        _catalog = data;
        _report = report;
        _busy = false;
      });
    } catch (failure) {
      if (!mounted || !_alive(operation) || failure is ObsoleteRequest) return;
      await _failed(failure, task, operation);
    }
  }

  Future<void> _failed(Object failure, _Task task, int operation) async {
    if (!_alive(operation)) return;
    if (failure is HrModuleUnavailable) {
      setState(() {
        _catalog = null;
        _report = null;
        _denied = true;
        _busy = false;
      });
      return;
    }
    if (failure is AppFailure && failure.kind == FailureKind.denied) {
      widget.auth.blockAccess(
        failure is AccountAccessFailure
            ? failure
            : const AccountAccessFailure.mobileAccess(),
      );
      return;
    }
    setState(() {
      _busy = false;
      _failedLoad = true;
      _report = null;
    });
    final exits =
        task == _Task.entry || task == _Task.restore || task == _Task.branch;
    final retry = await _dialogs.show<bool>(
      context,
      AlertDialog(
        key: const Key('leave_balance_error'),
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
            key: const Key('leave_balance_error_cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(exits ? 'Exit' : 'Cancel'),
          ),
          TextButton(
            key: const Key('leave_balance_error_retry'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    if (!mounted || !_alive(operation)) return;
    if (retry == true) {
      await _run(task);
    } else if (exits) {
      await _back();
    } else {
      setState(() => _failedLoad = false);
    }
  }

  void _branch(LeaveBalanceChoice value) {
    if (!_ready || !_catalog!.branches.contains(value)) return;
    setState(() {
      _catalog = LeaveBalanceCatalog(
        branches: _catalog!.branches,
        branch: value,
      );
      _report = null;
    });
    unawaited(_run(_Task.branch));
  }

  void _division(LeaveBalanceChoice value) {
    if (!_ready || !_catalog!.divisions.contains(value)) return;
    setState(() {
      _catalog = _catalog!.withDivision(value);
      _report = null;
    });
    unawaited(_run(_Task.division));
  }

  void _department(LeaveBalanceChoice value) {
    if (!_ready || !_catalog!.departments.contains(value)) return;
    setState(() {
      _catalog = _catalog!.withDepartment(value);
      _report = null;
    });
    unawaited(_run(_Task.department));
  }

  void _designation(LeaveBalanceChoice value) {
    if (!_ready || !_catalog!.designations.contains(value)) return;
    setState(() {
      _catalog = _catalog!.withDesignation(value);
      _report = null;
    });
    unawaited(_run(_Task.designation));
  }

  void _employee(LeaveBalanceEmployee value) {
    if (!_ready || !_catalog!.employees.contains(value)) return;
    setState(() {
      _catalog = _catalog!.withEmployee(value);
      _report = null;
    });
    unawaited(_run(_Task.report));
  }

  Future<void> _chooseYear() async {
    if (!_ready || _catalog!.employee == null || _report == null) return;
    final operation = _operation;
    final selected = await _dialogs.show<LeaveBalanceYear>(
      context,
      NativeLeaveBalanceYearDialog(
        selected: _year,
        now: widget.repository.now(),
      ),
      dismissible: true,
    );
    if (!_alive(operation) ||
        selected == null ||
        !selected.isAllowed(widget.repository.now())) {
      return;
    }
    setState(() => _year = selected);
    await _run(_Task.report);
  }

  Future<void> _back() async {
    if (mounted && !_busy && !_dialogs.isOpen) {
      await Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: NativeLeaveBalanceLayout(
      catalog: _catalog,
      report: _report,
      year: _year,
      waiting: !_invalid && (!_current || !_foreground || _busy),
      enabled: _current && _foreground,
      message:
          _denied
              ? 'Leave Balance access is not available for this account.'
              : _failedLoad
              ? ''
              : null,
      onBack: () => unawaited(_back()),
      onBranch: _branch,
      onDivision: _division,
      onDepartment: _department,
      onDesignation: _designation,
      onEmployee: _employee,
      onYear: () => unawaited(_chooseYear()),
    ),
  );
  @override
  void dispose() {
    ++_operation;
    if (!_invalid) {
      widget.auth.removeListener(_authChanged);
      WidgetsBinding.instance.removeObserver(this);
    }
    _dialogs.dispose();
    super.dispose();
  }
}

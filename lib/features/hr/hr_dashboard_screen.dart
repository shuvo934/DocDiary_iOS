import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/failure.dart';
import '../auth/account_access.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../dashboard/dashboard_navigation.dart';
import '../dashboard/native_dashboard_dialogs.dart';
import 'hr_dashboard_models.dart';
import 'hr_dashboard_navigation.dart';
import 'hr_dashboard_repository.dart';
import 'native_hr_dashboard_layout.dart';
import 'native_hr_payroll_month_dialog.dart';

class HrDashboardScreen extends StatefulWidget {
  const HrDashboardScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.destinationBuilder,
  });
  final AuthController auth;
  final HrDashboardRepository repository;
  final DashboardDestinationBuilder? destinationBuilder;
  @override
  State<HrDashboardScreen> createState() => _HrDashboardScreenState();
}

class _HrDashboardScreenState extends State<HrDashboardScreen>
    with WidgetsBindingObserver {
  late final AuthSession _session;
  final _scaffold = GlobalKey<ScaffoldState>();
  final _dialogs = NativeDashboardDialogOwner();
  HrCounts? _counts;
  HrAttendance? _attendance;
  HrWeeklyLeave? _leave;
  HrPayroll? _payroll;
  HrAttendancePeriod _attendancePeriod = HrAttendancePeriod.today;
  HrLeavePeriod _leavePeriod = HrLeavePeriod.thisWeek;
  late HrDateRange _attendanceRange, _leaveRange;
  late HrPayrollMonth _payrollMonth;
  final _failures = <HrSection>{};
  HrSection? _busy = HrSection.full;
  bool _invalid = false,
      _foreground = true,
      _moduleDenied = false,
      _childAway = false;
  int _operation = 0;
  double _valueFontSize = 12;

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
      !_childAway &&
      !_moduleDenied &&
      _busy == null &&
      !_dialogs.isOpen &&
      !_failures.contains(HrSection.full);

  void _defaults([DateTime? anchor]) {
    final now = anchor ?? widget.repository.now();
    _attendancePeriod = HrAttendancePeriod.today;
    _leavePeriod = HrLeavePeriod.thisWeek;
    _attendanceRange = HrDateRange.attendance(_attendancePeriod, now);
    _leaveRange = HrDateRange.leave(_leavePeriod, now);
    _payrollMonth = HrPayrollMonth(DateTime(now.year, now.month - 1));
    _valueFontSize = 12;
  }

  void _clearData() {
    _counts = null;
    _attendance = null;
    _leave = null;
    _payroll = null;
  }

  @override
  void initState() {
    super.initState();
    _defaults();
    final session = widget.auth.session;
    if (session == null ||
        widget.auth.profile == null ||
        session.account.role != AccountRole.admin) {
      _invalid = true;
      _moduleDenied = true;
      _busy = null;
      return;
    }
    _session = session;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) {
        unawaited(_load(HrSection.full, force: true));
      }
    });
  }

  void _authChanged() {
    if (!_current) {
      ++_operation;
      _dialogs.close();
      _scaffold.currentState?.closeEndDrawer();
      if (mounted) {
        setState(() {
          _clearData();
          _busy = HrSection.full;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _foreground = false;
      ++_operation;
      if (!_childAway) _dialogs.close();
      _scaffold.currentState?.closeEndDrawer();
      if (mounted) setState(() {});
    } else if (!_foreground) {
      _foreground = true;
      if (_current && !_childAway) {
        unawaited(_load(HrSection.full, force: true));
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

  Future<void> _load(HrSection section, {bool force = false}) async {
    if (!_current ||
        !_foreground ||
        _childAway ||
        _dialogs.isOpen ||
        (_busy != null && !force)) {
      return;
    }
    final operation = ++_operation;
    final snapshot = widget.repository.now();
    setState(() {
      _busy = section;
      _moduleDenied = false;
      _failures.remove(section);
      if (section == HrSection.full) {
        _defaults(snapshot);
        _clearData();
        _failures.clear();
      }
    });
    try {
      final profile = await _profile(operation);
      switch (section) {
        case HrSection.full:
          final data = await widget.repository.load(
            _session,
            profile,
            snapshot,
            isCurrent: () => _alive(operation),
          );
          if (!_alive(operation)) return;
          setState(() {
            _counts = data.counts;
            _attendance = data.attendance;
            _leave = data.leave;
            _payroll = data.payroll;
            _busy = null;
          });
        case HrSection.attendance:
          final data = await widget.repository.attendance(
            _session,
            profile,
            _attendanceRange,
            isCurrent: () => _alive(operation),
          );
          if (!_alive(operation)) return;
          setState(() {
            _attendance = data;
            _busy = null;
            _valueFontSize = 10;
          });
        case HrSection.leave:
          final data = await widget.repository.leave(
            _session,
            profile,
            _leaveRange,
            isCurrent: () => _alive(operation),
          );
          if (!_alive(operation)) return;
          setState(() {
            _leave = data;
            _busy = null;
          });
        case HrSection.payroll:
          final data = await widget.repository.payroll(
            _session,
            profile,
            _payrollMonth,
            isCurrent: () => _alive(operation),
          );
          if (!_alive(operation)) return;
          setState(() {
            _payroll = data;
            _busy = null;
          });
      }
    } catch (failure) {
      if (!mounted || !_alive(operation) || failure is ObsoleteRequest) return;
      await _failed(failure, section, operation);
    }
  }

  Future<void> _failed(Object failure, HrSection section, int operation) async {
    if (!_alive(operation)) return;
    if (failure is HrModuleUnavailable) {
      setState(() {
        _clearData();
        _busy = null;
        _moduleDenied = true;
        _failures.clear();
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
      _busy = null;
      _failures.add(section);
    });
    final full = section == HrSection.full;
    final retry = await _dialogs.show<bool>(
      context,
      AlertDialog(
        key: Key(full ? 'hr_full_error' : 'hr_section_error'),
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
          if (full)
            TextButton(
              key: const Key('hr_error_exit'),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Exit'),
            ),
          TextButton(
            key: Key(full ? 'hr_error_retry' : 'hr_error_ok'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(full ? 'Retry' : 'OK'),
          ),
        ],
      ),
    );
    if (!_alive(operation)) return;
    if (full) {
      if (retry == true) {
        await _load(HrSection.full);
      } else {
        await _back();
      }
    }
  }

  Future<void> _changeAttendance(HrAttendancePeriod period) async {
    if (!_ready || period == _attendancePeriod) return;
    setState(() {
      _attendancePeriod = period;
      _attendanceRange = HrDateRange.attendance(
        period,
        widget.repository.now(),
      );
    });
    await _load(HrSection.attendance);
  }

  Future<void> _changeLeave(HrLeavePeriod period) async {
    if (!_ready || period == _leavePeriod) return;
    setState(() {
      _leavePeriod = period;
      _leaveRange = HrDateRange.leave(period, widget.repository.now());
    });
    await _load(HrSection.leave);
  }

  Future<void> _chooseMonth() async {
    if (!_ready) return;
    final operation = _operation;
    final selection = await _dialogs.show<HrPayrollMonth>(
      context,
      NativeHrPayrollMonthDialog(
        selected: _payrollMonth,
        now: widget.repository.now(),
      ),
      dismissible: true,
    );
    if (!_alive(operation) ||
        selection == null ||
        !selection.isAllowed(widget.repository.now())) {
      return;
    }
    setState(() => _payrollMonth = selection);
    await _load(HrSection.payroll);
  }

  Future<void> _back() async {
    if (!mounted || _busy != null || _dialogs.isOpen) return;
    if (_scaffold.currentState?.isEndDrawerOpen ?? false) {
      _scaffold.currentState?.closeEndDrawer();
      return;
    }
    await Navigator.maybePop(context);
  }

  Future<void> _open(HrDestination destination) async {
    if (!_ready) return;
    final operation = ++_operation;
    setState(() => _busy = HrSection.full);
    try {
      await _profile(operation);
      if (!mounted || !_alive(operation)) return;
      setState(() => _busy = null);
      final page = widget.destinationBuilder?.call(context, destination.route);
      if (page == null) {
        await _dialogs.show<void>(
          context,
          AlertDialog(
            key: const Key('hr_unavailable'),
            title: Text(destination.label),
            content: const Text('This feature is currently unavailable.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
          dismissible: true,
        );
        return;
      }
      _childAway = true;
      try {
        await _dialogs.push<void>(context, page);
      } finally {
        _childAway = false;
        if (_current && _foreground) await _load(HrSection.full, force: true);
      }
    } catch (failure) {
      if (!mounted || !_alive(operation) || failure is ObsoleteRequest) return;
      await _failed(failure, HrSection.full, operation);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final waiting =
        !_invalid && (!_current || !_foreground || _busy == HrSection.full);
    return PopScope(
      canPop: _busy == null,
      child: NativeHrDashboardLayout(
        scaffoldKey: _scaffold,
        onBack: () => unawaited(_back()),
        onDestination: (value) => unawaited(_open(value)),
        onAttendancePeriod: (value) => unawaited(_changeAttendance(value)),
        onLeavePeriod: (value) => unawaited(_changeLeave(value)),
        onPayrollMonth: () => unawaited(_chooseMonth()),
        onRetry: (section) {
          if (_ready && _failures.contains(section)) unawaited(_load(section));
        },
        attendancePeriod: _attendancePeriod,
        leavePeriod: _leavePeriod,
        attendanceRange: _attendanceRange,
        leaveRange: _leaveRange,
        payrollMonth: _payrollMonth,
        counts: _counts,
        attendance: _attendance,
        leave: _leave,
        payroll: _payroll,
        busy: _busy,
        failures: _failures,
        waiting: waiting,
        message:
            _moduleDenied
                ? 'HR Dashboard access is not available for this account.'
                : _failures.contains(HrSection.full)
                ? 'The HR Dashboard could not be loaded.'
                : null,
        enabled: _current && _foreground && !_childAway,
        valueFontSize: _valueFontSize,
      ),
    );
  }
}

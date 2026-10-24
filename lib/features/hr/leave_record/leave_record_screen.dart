import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/failure.dart';
import '../../auth/account_access.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../../dashboard/dashboard_navigation.dart';
import '../../dashboard/native_dashboard_dialogs.dart';
import '../hr_dashboard_repository.dart';
import '../leave_balance/leave_balance_models.dart';
import '../leave_balance/leave_balance_repository.dart';
import '../leave_balance/leave_balance_screen.dart';
import '../leave_approval/leave_approval_models.dart';
import '../leave_approval/leave_approval_repository.dart';
import '../leave_approval/leave_approval_screen.dart';
import 'leave_record_models.dart';
import 'leave_record_repository.dart';
import 'native_leave_record_layout.dart';
import 'native_leave_record_month_dialog.dart';

class LeaveRecordScreen extends StatefulWidget {
  const LeaveRecordScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.destinationBuilder,
  });
  final AuthController auth;
  final LeaveRecordRepository repository;
  final DashboardDestinationBuilder? destinationBuilder;
  @override
  State<LeaveRecordScreen> createState() => _LeaveRecordScreenState();
}

class _LeaveRecordScreenState extends State<LeaveRecordScreen>
    with WidgetsBindingObserver {
  late final AuthSession _session;
  late LeaveRecordMonth _month;
  final _dialogs = NativeDashboardDialogOwner();
  LeaveRecordData? _data;
  LeaveRecordChoice _branch = LeaveRecordChoice.none;
  LeaveRecordFilter _filter = const LeaveRecordFilter();
  bool _invalid = false,
      _foreground = true,
      _busy = true,
      _denied = false,
      _loadFailed = false,
      _childAway = false;
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
      !_loadFailed &&
      !_childAway &&
      !_dialogs.isOpen &&
      _data != null;
  @override
  void initState() {
    super.initState();
    _month = LeaveRecordMonth(widget.repository.now());
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
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) unawaited(_load(catalog: true, force: true));
    });
  }

  void _authChanged() {
    if (!_current) {
      ++_operation;
      _dialogs.close();
      if (mounted) {
        setState(() {
          _data = null;
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
      if (!_childAway) _dialogs.close();
      if (mounted) setState(() {});
    } else if (!_foreground) {
      _foreground = true;
      if (_current && !_childAway) {
        unawaited(_load(catalog: true, force: true, restore: true));
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

  Future<void> _load({
    bool catalog = false,
    bool force = false,
    bool restore = false,
  }) async {
    if (!_current ||
        !_foreground ||
        _childAway ||
        _dialogs.isOpen ||
        _busy && !force) {
      return;
    }
    final operation = ++_operation;
    if (!_month.isAllowed(widget.repository.now())) {
      _month = LeaveRecordMonth(widget.repository.now());
    }
    setState(() {
      _busy = true;
      _loadFailed = false;
      _denied = false;
    });
    try {
      final profile = await _profile(operation);
      final data =
          catalog || _data == null
              ? await widget.repository.load(
                _session,
                profile,
                _month,
                branch: _branch,
                branches: _data?.branches ?? [],
                reloadBranches: restore,
                isCurrent: () => _alive(operation),
              )
              : _data!.withRows(
                await widget.repository.records(
                  _session,
                  profile,
                  _month,
                  branch: _branch.id,
                  isCurrent: () => _alive(operation),
                ),
              );
      if (!_alive(operation)) return;
      setState(() {
        _data = data;
        _branch = data.branch;
        _filter = _filter.restored(data);
        _busy = false;
      });
    } catch (failure) {
      if (!mounted || !_alive(operation) || failure is ObsoleteRequest) return;
      await _failed(
        failure,
        operation,
        () => _load(catalog: catalog, restore: restore),
      );
    }
  }

  Future<void> _failed(
    Object failure,
    int operation,
    Future<void> Function() retryLoad,
  ) async {
    if (!_alive(operation)) return;
    if (failure is HrModuleUnavailable) {
      setState(() {
        _data = null;
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
      _loadFailed = true;
    });
    final retry = await _dialogs.show<bool>(
      context,
      AlertDialog(
        key: const Key('leave_record_error'),
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
            key: const Key('leave_record_error_cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('leave_record_error_retry'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    if (!_alive(operation)) return;
    if (retry == true) {
      await retryLoad();
    } else {
      await _back();
    }
  }

  void _selectBranch(LeaveRecordChoice value) {
    if (!_ready || !_data!.branches.contains(value)) return;
    setState(() {
      _branch = value;
      _filter = const LeaveRecordFilter();
    });
    unawaited(_load(catalog: true));
  }

  void _selectDivision(LeaveRecordChoice value) {
    if (!_ready || !_data!.divisions.contains(value)) return;
    setState(() => _filter = LeaveRecordFilter(division: value.id));
  }

  void _selectDepartment(LeaveRecordChoice value) {
    if (!_ready || !_filter.departments(_data!).contains(value)) return;
    setState(
      () =>
          _filter = LeaveRecordFilter(
            division: _filter.division,
            department: value.id,
          ),
    );
  }

  void _selectEmployee(LeaveRecordChoice value) {
    if (!_ready || !_filter.employees(_data!).contains(value)) return;
    setState(
      () =>
          _filter = LeaveRecordFilter(
            division: _filter.division,
            department: _filter.department,
            employee: value.id,
          ),
    );
  }

  Future<void> _monthDialog() async {
    if (!_ready) return;
    final operation = _operation;
    final month = await _dialogs.show<LeaveRecordMonth>(
      context,
      NativeLeaveRecordMonthDialog(
        selected: _month,
        now: widget.repository.now(),
      ),
      dismissible: true,
    );
    if (!_alive(operation) ||
        month == null ||
        !month.isAllowed(widget.repository.now())) {
      return;
    }
    setState(() => _month = month);
    await _load();
  }

  Future<void> _summary() async {
    if (!_ready) return;
    final counts = LeaveRecordCounts(_filter.rows(_data!));
    await _dialogs.show<void>(
      context,
      AlertDialog(
        key: const Key('leave_record_summary'),
        title: Text(
          'Leave Status',
          style: dashboardDialogText(20, weight: FontWeight.w500),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in counts.entries.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text.rich(
                    TextSpan(
                      style: dashboardDialogText(
                        16,
                        color: const Color(0xff6c6e6f),
                      ),
                      children: [
                        TextSpan(text: '${entry.key}:   '),
                        TextSpan(
                          text: '${entry.value}',
                          style: dashboardDialogText(
                            16,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('leave_record_summary_close'),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
      dismissible: true,
    );
  }

  Future<void> _openRecord(LeaveRecordRow row) async {
    if (!_ready || !_filter.rows(_data!).contains(row)) return;
    final operation = ++_operation;
    setState(() => _busy = true);
    try {
      await _profile(operation);
      if (!mounted || !_alive(operation)) return;
      setState(() => _busy = false);
      final route = row.route(_month);
      final page =
          widget.destinationBuilder?.call(context, route) ??
          (route.module == DashboardModule.hrLeaveBalance
              ? LeaveBalanceScreen(
                auth: widget.auth,
                repository: LeaveBalanceRepository(
                  widget.repository.transport,
                  now: widget.repository.now,
                ),
                seed: LeaveBalanceSeed.fromExtras(route.extras),
              )
              : route.module == DashboardModule.hrLeaveApproval
              ? LeaveApprovalScreen(
                auth: widget.auth,
                repository: LeaveApprovalRepository(
                  widget.repository.transport,
                  now: widget.repository.now,
                ),
                seed: LeaveApprovalSeed.fromExtras(route.extras),
              )
              : null);
      if (page == null) {
        await _dialogs.show<void>(
          context,
          AlertDialog(
            key: const Key('leave_record_destination_unavailable'),
            title: Text(row.status == '0' ? 'Leave Approval' : 'Leave Balance'),
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
        if (_current && _foreground) {
          await _load(catalog: true, force: true, restore: true);
        }
      }
    } catch (failure) {
      if (!mounted || !_alive(operation) || failure is ObsoleteRequest) return;
      await _failed(
        failure,
        operation,
        () => _load(catalog: true, restore: true),
      );
    }
  }

  Future<void> _back() async {
    if (mounted && !_busy && !_dialogs.isOpen) {
      await Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: NativeLeaveRecordLayout(
      month: _month,
      data: _data,
      filter: _filter,
      waiting: !_invalid && (!_current || !_foreground || _busy),
      enabled: _current && _foreground && !_childAway,
      message:
          _denied
              ? 'Leave Record access is not available for this account.'
              : _loadFailed
              ? ''
              : null,
      onBack: () => unawaited(_back()),
      onBranch: _selectBranch,
      onDivision: _selectDivision,
      onDepartment: _selectDepartment,
      onEmployee: _selectEmployee,
      onMonth: () => unawaited(_monthDialog()),
      onSummary: () => unawaited(_summary()),
      onRow: (row) => unawaited(_openRecord(row)),
      onRefresh: () async => await _load(),
    ),
  );
  @override
  void dispose() {
    ++_operation;
    _dialogs.dispose();
    if (!_invalid) {
      widget.auth.removeListener(_authChanged);
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}

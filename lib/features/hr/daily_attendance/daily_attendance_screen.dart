import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../auth/account_access.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../../dashboard/dashboard_navigation.dart';
import '../../dashboard/native_dashboard_dialogs.dart';
import '../employee_attendance/employee_attendance_models.dart';
import '../employee_attendance/employee_attendance_repository.dart';
import '../employee_attendance/employee_attendance_screen.dart';
import 'daily_attendance_models.dart';
import 'daily_attendance_repository.dart';
import '../hr_dashboard_repository.dart';
import 'native_daily_attendance_layout.dart';

class DailyAttendanceScreen extends StatefulWidget {
  const DailyAttendanceScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.destinationBuilder,
  });
  final AuthController auth;
  final DailyAttendanceRepository repository;
  final DashboardDestinationBuilder? destinationBuilder;
  @override
  State<DailyAttendanceScreen> createState() => _DailyAttendanceScreenState();
}

class _DailyAttendanceScreenState extends State<DailyAttendanceScreen>
    with WidgetsBindingObserver {
  late final AuthSession _session;
  late AttendanceCalendar _calendar;
  late DateTime _date;
  final _dialogs = NativeDashboardDialogOwner();
  DailyAttendanceData? _data;
  AttendanceFilter _filter = const AttendanceFilter();
  String _branch = '', _branchName = 'None';
  bool _invalid = false,
      _foreground = true,
      _busy = true,
      _denied = false,
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
      !_childAway &&
      !_dialogs.isOpen &&
      _data != null;

  @override
  void initState() {
    super.initState();
    _calendar = AttendanceCalendar(widget.repository.now());
    _date = _calendar.last;
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
      if (_current && !_childAway) unawaited(_load(catalog: true, force: true));
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

  Future<void> _load({required bool catalog, bool force = false}) async {
    if (!_current ||
        !_foreground ||
        _childAway ||
        _dialogs.isOpen ||
        (_busy && !force)) {
      return;
    }
    final operation = ++_operation;
    _calendar = AttendanceCalendar(widget.repository.now());
    _date = _calendar.clamp(_date);
    setState(() {
      _busy = true;
      _denied = false;
    });
    try {
      final profile = await _profile(operation);
      final data =
          catalog || _data == null
              ? await widget.repository.load(
                _session,
                profile,
                _date,
                branchId: _branch,
                branches: _data?.branches ?? const [],
                isCurrent: () => _alive(operation),
              )
              : _data!.withRows(
                await widget.repository.attendance(
                  _session,
                  profile,
                  _date,
                  _branch,
                  isCurrent: () => _alive(operation),
                ),
              );
      if (!_alive(operation)) return;
      setState(() {
        _data = data;
        _filter = _filter.retainedIn(data);
        _busy = false;
      });
    } catch (failure) {
      if (!mounted || !_alive(operation) || failure is ObsoleteRequest) return;
      await _failed(failure, operation, catalog: catalog);
    }
  }

  Future<void> _failed(
    Object failure,
    int operation, {
    required bool catalog,
  }) async {
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
      _data = _data?.withRows(const []);
    });
    final retry = await _dialogs.show<bool>(
      context,
      AlertDialog(
        key: const Key('daily_error'),
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
            key: const Key('daily_error_cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('daily_error_retry'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    if (!mounted || !_alive(operation)) return;
    if (retry == true) {
      await _load(catalog: catalog);
    } else {
      await _back();
    }
  }

  Future<void> _selectBranch(AttendanceChoice branch) async {
    if (!_ready || !_data!.branches.contains(branch)) return;
    setState(() {
      _branch = branch.id == '30' ? '' : branch.id;
      _branchName = branch.name;
      _filter = const AttendanceFilter();
    });
    await _load(catalog: true);
  }

  void _selectDivision(AttendanceChoice value) {
    if (!_ready || !_data!.divisions.contains(value)) return;
    setState(() => _filter = AttendanceFilter(division: value.id));
  }

  void _selectDepartment(AttendanceChoice value) {
    if (!_ready ||
        !_filter.departments(_data!).any((item) => item.id == value.id)) {
      return;
    }
    setState(
      () =>
          _filter = AttendanceFilter(
            division: _filter.division,
            department: value.id,
          ),
    );
  }

  void _selectEmployee(AttendanceChoice value) {
    if (!_ready ||
        !_filter.employees(_data!).any((item) => item.id == value.id)) {
      return;
    }
    setState(
      () =>
          _filter = AttendanceFilter(
            division: _filter.division,
            department: _filter.department,
            employee: value.id,
          ),
    );
  }

  Future<void> _selectDate(DateTime value) async {
    final selected = dateOnly(value);
    if (!_ready || selected == _date || !_calendar.contains(selected)) return;
    setState(() => _date = selected);
    await _load(catalog: false);
  }

  Future<void> _openEmployee(DailyAttendanceRow row) async {
    if (!_ready || !_filter.rows(_data!).contains(row)) return;
    final operation = ++_operation;
    setState(() => _busy = true);
    try {
      await _profile(operation);
      if (!mounted || !_alive(operation)) return;
      setState(() => _busy = false);
      final route = row.route(_branch);
      final page =
          widget.destinationBuilder?.call(context, route) ??
          EmployeeAttendanceScreen(
            auth: widget.auth,
            repository: EmployeeAttendanceRepository(
              widget.repository.transport,
              now: widget.repository.now,
            ),
            seed: EmployeeAttendanceSeed.fromExtras(route.extras),
          );
      _childAway = true;
      try {
        await _dialogs.push<void>(context, page);
      } finally {
        _childAway = false;
        if (_current && _foreground) await _load(catalog: true, force: true);
      }
    } catch (failure) {
      if (!mounted || !_alive(operation) || failure is ObsoleteRequest) return;
      await _failed(failure, operation, catalog: true);
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
    child: NativeDailyAttendanceLayout(
      calendar: _calendar,
      selectedDate: _date,
      branchName: _branchName,
      filter: _filter,
      data: _data,
      waiting: !_invalid && (!_current || !_foreground || _busy),
      enabled: _current && _foreground && !_childAway,
      message:
          _denied
              ? 'Daily Attendance access is not available for this account.'
              : null,
      onBack: () => unawaited(_back()),
      onBranch: (value) => unawaited(_selectBranch(value)),
      onDivision: _selectDivision,
      onDepartment: _selectDepartment,
      onEmployee: _selectEmployee,
      onDate: (value) => unawaited(_selectDate(value)),
      onRow: (row) => unawaited(_openEmployee(row)),
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

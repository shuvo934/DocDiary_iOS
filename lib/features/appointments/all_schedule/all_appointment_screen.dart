import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';
import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../auth/account_access.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../../dashboard/native_dashboard_dialogs.dart';
import '../doctor_schedule/doctor_appointment_models.dart';
import '../doctor_schedule/history/doctor_appointment_history_models.dart';
import '../doctor_schedule/history/native_appointment_history_layout.dart';
import '../unit_schedule/unit_appointment_models.dart';
import 'all_appointment_models.dart';
import 'all_appointment_repository.dart';
import 'native_all_appointment_layout.dart';

class AllAppointmentScreen extends StatefulWidget {
  const AllAppointmentScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.openPhone,
  });
  final AuthController auth;
  final AllAppointmentRepository repository;
  final Future<bool> Function(Uri)? openPhone;
  @override
  State<AllAppointmentScreen> createState() => _AllAppointmentState();
}

class _AllAppointmentState extends State<AllAppointmentScreen>
    with WidgetsBindingObserver {
  late final AuthSession? _session = widget.auth.session;
  late DoctorAppointmentWindow _window = DoctorAppointmentWindow(
    widget.repository.now(),
  );
  late DateTime _selected = _window.anchor;
  final _dialogs = NativeDashboardDialogOwner();
  final _toasts = AppToastOwner();
  final _scroll = ScrollController();
  List<UnitAppointmentChoice> _departments = const [], _units = const [];
  UnitAppointmentChoice? _department, _unit, _doctor;
  String _departmentId = '', _unitId = '';
  String? _scope, _error;
  AccountProfile? _profile;
  UnitAppointmentSnapshot? _snapshot;
  AllAppointmentTotals _totals = AllAppointmentTotals.zero;
  AllAppointmentLoad _retry = AllAppointmentLoad.departments;
  bool _busy = true,
      _foreground = true,
      _failed = false,
      _overlay = false,
      _answered = false;
  int _operation = 0, _generation = 0;
  bool get _current =>
      mounted &&
      _session != null &&
      widget.auth.stage == AuthStage.authenticated &&
      widget.auth.session == _session;
  bool _alive(int operation) =>
      _current && _foreground && operation == _operation;
  bool get _ready =>
      _current &&
      _foreground &&
      !_busy &&
      !_failed &&
      !_overlay &&
      !_dialogs.isOpen;

  @override
  void initState() {
    super.initState();
    if (_session == null || widget.auth.profile == null) {
      _busy = false;
      _failed = true;
      _error =
          'All Appointment details are unavailable. Please return to Login.';
      return;
    }
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) {
        unawaited(_load(AllAppointmentLoad.departments, force: true));
      }
    });
  }

  void _authChanged() {
    if (_current) return;
    ++_operation;
    _dialogs.close();
    _toasts.clear();
    if (mounted) {
      setState(() {
        _departments = _units = const [];
        _department = _unit = _doctor = null;
        _snapshot = null;
        _profile = null;
        _totals = AllAppointmentTotals.zero;
        _busy = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _overlay = false;
      ++_operation;
      _dialogs.close();
      _toasts.clear();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && !_foreground) {
      _foreground = true;
      if (_current) {
        unawaited(_load(AllAppointmentLoad.departments, force: true));
      }
    }
  }

  Future<AccountProfile> _fresh(int operation) async {
    final profile = await widget.auth.profiles.open(
      _session!,
      recordLogin: false,
      isCurrent: () => _alive(operation),
    );
    widget.repository.guard(_session, profile, () => _alive(operation));
    return profile;
  }

  UnitAppointmentChoice? _match(
    List<UnitAppointmentChoice> choices,
    String id,
  ) {
    final matches = choices.where((choice) => choice.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> _load(AllAppointmentLoad from, {bool force = false}) async {
    if (!_current || !_foreground || (!force && _busy)) return;
    final operation = ++_operation;
    _retry = from;
    setState(() {
      _busy = true;
      _failed = false;
      _error = null;
      _snapshot = null;
      _doctor = null;
      if (from.index <= AllAppointmentLoad.totals.index) {
        _totals = AllAppointmentTotals.zero;
      }
    });
    try {
      final profile = await _fresh(operation),
          scope = allAppointmentScope(profile);
      if (_scope != scope) {
        _departmentId =
            profile.isDoctor ? profile.value('deptd_id').trim() : '';
        _unitId = profile.isDoctor ? profile.value('depts_id').trim() : '';
        _department = _unit = null;
        _departments = _units = const [];
        _totals = AllAppointmentTotals.zero;
        from = AllAppointmentLoad.departments;
      }
      _profile = profile;
      _scope = scope;
      _window = DoctorAppointmentWindow(widget.repository.now());
      if (!_window.contains(_selected)) _selected = _window.anchor;
      if (from.index <= AllAppointmentLoad.departments.index) {
        _retry = AllAppointmentLoad.departments;
        final choices = await widget.repository.departments(
          _session!,
          profile,
          isCurrent: () => _alive(operation),
        );
        if (!_alive(operation)) return;
        _departments = choices;
        _department = _match(choices, _departmentId);
        if (_department == null) {
          _departmentId = _unitId = '';
          _unit = null;
          _units = const [];
        }
      }
      final department = _department;
      if (department != null) {
        if (from.index <= AllAppointmentLoad.units.index) {
          _retry = AllAppointmentLoad.units;
          final choices = await widget.repository.units(
            _session!,
            profile,
            department,
            _departments,
            isCurrent: () => _alive(operation),
          );
          if (!_alive(operation)) return;
          _units = choices;
          _unit = _match(choices, _unitId);
          if (_unit == null) _unitId = '';
        }
        if (from.index <= AllAppointmentLoad.totals.index) {
          _retry = AllAppointmentLoad.totals;
          final totals = await widget.repository.totals(
            _session!,
            profile,
            _selected,
            department,
            _departments,
            isCurrent: () => _alive(operation),
          );
          if (!_alive(operation)) return;
          _totals = totals;
        }
        final unit = _unit;
        if (unit != null) {
          _retry = AllAppointmentLoad.doctors;
          final rows = await widget.repository.doctors(
            _session!,
            profile,
            _selected,
            department,
            _departments,
            unit,
            _units,
            isCurrent: () => _alive(operation),
          );
          if (!_alive(operation)) return;
          _snapshot = rows;
        }
      }
      if (!_alive(operation)) return;
      setState(() {
        _busy = false;
        ++_generation;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (failure) {
      if (!mounted || !_alive(operation) || failure is ObsoleteRequest) return;
      if (_block(failure)) return;
      if (failure is AllAppointmentUnavailable) {
        await _unavailable(operation);
        return;
      }
      setState(() {
        _busy = false;
        _failed = true;
        _snapshot = null;
        _error = dashboardErrorMessage(failure);
      });
      final retry = await _dialog<bool>(
        AlertDialog(
          key: const Key('all_appointment_error_dialog'),
          scrollable: true,
          title: Text(
            'Error!',
            style: dashboardDialogText(20, weight: FontWeight.w500),
          ),
          content: Text(_error!, style: dashboardDialogText(16)),
          actions: [
            _button('all_appointment_error_exit', 'EXIT', () => _answer(false)),
            _button(
              'all_appointment_error_retry',
              'RETRY',
              () => _answer(true),
            ),
          ],
        ),
      );
      if (!mounted || !_alive(operation)) return;
      if (retry == true) {
        await _load(_retry);
      } else if (retry == false && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  bool _block(Object failure) {
    if (failure is! AppFailure || failure.kind != FailureKind.denied) {
      return false;
    }
    widget.auth.blockAccess(
      failure is AccountAccessFailure
          ? failure
          : const AccountAccessFailure.mobileAccess(),
    );
    return true;
  }

  Future<void> _unavailable(int operation) async {
    setState(() {
      _busy = false;
      _failed = true;
      _snapshot = null;
      _profile = null;
      _departments = _units = const [];
      _department = _unit = _doctor = null;
      _totals = AllAppointmentTotals.zero;
      _error = 'All Appointment is not available for this account.';
    });
    await _dialog<void>(
      NativeDashboardMessageDialog(
        title: 'Not available',
        message: _error!,
        button: 'CLOSE',
      ),
    );
    if (mounted && _alive(operation) && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<T?> _dialog<T>(Widget dialog, {bool dismissible = false}) {
    _answered = false;
    return _dialogs.show<T>(context, dialog, dismissible: dismissible);
  }

  void _answer<T>(T? result) {
    if (_current && _foreground && _dialogs.isOpen && !_answered) {
      _answered = true;
      Navigator.pop<T>(context, result);
    }
  }

  Widget _button(String key, String text, VoidCallback onTap) => TextButton(
    key: Key(key),
    onPressed: onTap,
    child: Text(
      text,
      style: dashboardDialogText(
        14,
        color: DocColors.primary,
        weight: FontWeight.w500,
      ),
    ),
  );

  Future<void> _choose(AllAppointmentFilter kind, Rect anchor) async {
    if (!_ready) return;
    final choices = switch (kind) {
      AllAppointmentFilter.department => _departments,
      AllAppointmentFilter.unit => _units,
      AllAppointmentFilter.doctor =>
        _snapshot?.doctorChoices ?? const <UnitAppointmentChoice>[],
    };
    if (choices.isEmpty) return;
    final operation = _operation;
    setState(() => _overlay = true);
    AppointmentHistoryChoice? picked;
    try {
      // The shared popup uses kind only for widget keys; it has no history API.
      picked = await _dialogs.show<AppointmentHistoryChoice>(
        context,
        NativeAppointmentHistoryChoices(
          kind:
              kind == AllAppointmentFilter.doctor
                  ? AppointmentHistoryFilter.doctor
                  : AppointmentHistoryFilter.unit,
          choices: [
            for (final choice in choices)
              AppointmentHistoryChoice(choice.id, choice.name),
          ],
          anchor: anchor,
        ),
        dismissible: true,
        barrierColor: Colors.transparent,
      );
    } finally {
      if (mounted) setState(() => _overlay = false);
    }
    if (!_alive(operation) || !_ready || picked == null) return;
    final selected = _match(choices, picked.id);
    if (selected == null) return;
    if (kind == AllAppointmentFilter.department) {
      setState(() {
        _department = selected;
        _departmentId = selected.id;
        _unitId = '';
        _unit = _doctor = null;
        _units = const [];
      });
      await _load(AllAppointmentLoad.units);
    } else if (kind == AllAppointmentFilter.unit) {
      setState(() {
        _unit = selected;
        _unitId = selected.id;
        _doctor = null;
      });
      await _load(AllAppointmentLoad.doctors);
    } else {
      setState(() => _doctor = selected.id.isEmpty ? null : selected);
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  Future<void> _date(DateTime selected) async {
    final day = dateOnly(selected);
    if (!_ready || !_window.contains(day) || day == _selected) return;
    setState(() {
      _selected = day;
      _doctor = null;
    });
    if (_department == null) {
      _toasts.show(context, 'Please Select Department');
      return;
    }
    if (_unit == null) _toasts.show(context, 'Please Select Unit');
    await _load(AllAppointmentLoad.totals);
  }

  Future<void> _stats(bool department) async {
    if (!_ready) return;
    final name = department ? _department?.name : _unit?.name;
    final appointments =
        department ? _totals.appointments : _snapshot?.appointmentCount ?? 0;
    final blank = department ? _totals.blank : _snapshot?.blankCount ?? 0;
    setState(() => _overlay = true);
    try {
      await _dialog<void>(
        AlertDialog(
          key: Key(
            department
                ? 'all_appointment_department_totals_dialog'
                : 'all_appointment_totals_dialog',
          ),
          scrollable: true,
          title:
              name == null
                  ? null
                  : Text(
                    name,
                    style: dashboardDialogText(20, weight: FontWeight.w500),
                  ),
          content: Text.rich(
            TextSpan(
              style: dashboardDialogText(16),
              children: [
                const TextSpan(text: 'Total Appointment:   '),
                TextSpan(
                  text: '$appointments',
                  style: dashboardDialogText(
                    16,
                    color: Colors.black,
                    weight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: '\nTotal Blank Schedule:   '),
                TextSpan(
                  text: '$blank',
                  style: dashboardDialogText(
                    16,
                    color: Colors.black,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            _button(
              'all_appointment_totals_close',
              'CLOSE',
              () => _answer<void>(null),
            ),
          ],
        ),
        dismissible: true,
      );
    } finally {
      if (mounted) setState(() => _overlay = false);
    }
  }

  bool _contains(UnitAppointmentSlot slot) =>
      _snapshot?.doctors.any((doctor) => doctor.schedules.contains(slot)) ??
      false;
  Future<void> _call(UnitAppointmentSlot slot) async {
    if (!_ready ||
        !_contains(slot) ||
        _profile == null ||
        !allAppointmentMayCall(_profile!, slot)) {
      return;
    }
    final operation = ++_operation;
    var refresh = false;
    setState(() {
      _busy = true;
      _overlay = true;
    });
    try {
      var profile = await _fresh(operation);
      if (allAppointmentScope(profile) != _scope ||
          !allAppointmentMayCall(profile, slot)) {
        refresh = true;
        return;
      }
      setState(() => _busy = false);
      final yes = await _dialog<bool>(
        AlertDialog(
          key: const Key('all_appointment_call_dialog'),
          scrollable: true,
          content: Text(
            'Do you want to make a call to ${slot.value('pat_name')} ?',
            style: dashboardDialogText(16),
          ),
          actions: [
            _button('all_appointment_call_no', 'NO', () => _answer(false)),
            _button('all_appointment_call_yes', 'YES', () => _answer(true)),
          ],
        ),
      );
      if (!_alive(operation) || yes != true) return;
      setState(() => _busy = true);
      profile = await _fresh(operation);
      if (allAppointmentScope(profile) != _scope ||
          !allAppointmentMayCall(profile, slot)) {
        refresh = true;
        return;
      }
      final uri = allAppointmentPhoneUri(slot);
      final opened =
          await (widget.openPhone?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened && _alive(operation)) {
        throw const AppFailure('Could not open the phone dialer.');
      }
    } catch (failure) {
      if (!_alive(operation) || failure is ObsoleteRequest) return;
      if (_block(failure)) return;
      if (failure is AllAppointmentUnavailable) {
        await _unavailable(operation);
        return;
      }
      setState(() => _busy = false);
      await _dialog<void>(
        NativeDashboardMessageDialog(
          title: 'Error!',
          message: dashboardErrorMessage(failure),
        ),
      );
    } finally {
      if (_alive(operation)) {
        setState(() {
          _busy = false;
          _overlay = false;
        });
        if (refresh) await _load(AllAppointmentLoad.departments);
      }
    }
  }

  @override
  void dispose() {
    ++_operation;
    widget.auth.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    _dialogs.dispose();
    _toasts.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: NativeAllAppointmentLayout(
      window: _window,
      selected: _selected,
      now: widget.repository.now(),
      departments: _departments,
      units: _units,
      department: _department,
      unit: _unit,
      doctor: _doctor,
      rows: _snapshot?.filtered(_doctor?.id ?? '') ?? const [],
      doctorCount: _snapshot?.doctors.length ?? 0,
      hasDoctors: _snapshot != null,
      generation: _generation,
      scroll: _scroll,
      busy: _busy,
      enabled: _ready,
      message: _error,
      onBack: () => unawaited(Navigator.maybePop(context)),
      onDepartment:
          (anchor) =>
              unawaited(_choose(AllAppointmentFilter.department, anchor)),
      onUnit: (anchor) => unawaited(_choose(AllAppointmentFilter.unit, anchor)),
      onDoctor:
          (anchor) => unawaited(_choose(AllAppointmentFilter.doctor, anchor)),
      onDepartmentStats: () => unawaited(_stats(true)),
      onUnitStats: () => unawaited(_stats(false)),
      onDate: (day) => unawaited(_date(day)),
      onMonth: (delta) => unawaited(_date(_window.move(_selected, delta))),
      onCall:
          _profile != null &&
                  !_profile!.isDoctor &&
                  _profile!.value('all_access_flag') == '1'
              ? (slot) => unawaited(_call(slot))
              : null,
    ),
  );
}

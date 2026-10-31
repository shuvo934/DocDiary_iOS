import 'dart:async';
import 'package:flutter/material.dart';
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
import 'native_unit_appointment_layout.dart';
import 'unit_appointment_models.dart';
import 'unit_appointment_repository.dart';

class UnitAppointmentScreen extends StatefulWidget {
  const UnitAppointmentScreen({
    super.key,
    required this.auth,
    required this.repository,
  });
  final AuthController auth;
  final UnitAppointmentRepository repository;
  @override
  State<UnitAppointmentScreen> createState() => _UnitAppointmentState();
}

class _UnitAppointmentState extends State<UnitAppointmentScreen>
    with WidgetsBindingObserver {
  late final AuthSession? _session = widget.auth.session;
  late DoctorAppointmentWindow _window = DoctorAppointmentWindow(
    widget.repository.now(),
  );
  late DateTime _selected = _window.anchor;
  final _dialogs = NativeDashboardDialogOwner();
  final _toasts = AppToastOwner();
  final _scroll = ScrollController();
  List<UnitAppointmentChoice> _units = const [];
  UnitAppointmentChoice? _unit, _doctor;
  UnitAppointmentSnapshot? _snapshot;
  String? _scope, _error;
  bool _busy = true,
      _foreground = true,
      _failed = false,
      _overlay = false,
      _unitsLoaded = false,
      _retryUnits = true;
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
          'Unit Appointment details are unavailable. Please return to Login.';
      return;
    }
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) unawaited(_load(units: true, force: true));
    });
  }

  void _authChanged() {
    if (_current) return;
    ++_operation;
    _dialogs.close();
    _toasts.clear();
    if (mounted) {
      setState(() {
        _units = const [];
        _unit = _doctor = null;
        _snapshot = null;
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
      ++_operation;
      _dialogs.close();
      _toasts.clear();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && !_foreground) {
      _foreground = true;
      if (_current) unawaited(_load(units: true, force: true));
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

  Future<void> _load({bool units = false, bool force = false}) async {
    if (!_current || !_foreground || (!force && _busy)) return;
    final operation = ++_operation;
    var reloadUnits = units || !_unitsLoaded;
    _retryUnits = reloadUnits;
    setState(() {
      _busy = true;
      _failed = false;
      _error = null;
      _snapshot = null;
      _doctor = null;
    });
    try {
      final profile = await _fresh(operation),
          scope = unitAppointmentScope(profile);
      final changedScope = _scope != null && _scope != scope;
      _window = DoctorAppointmentWindow(widget.repository.now());
      if (!_window.contains(_selected)) _selected = _window.anchor;
      reloadUnits = reloadUnits || changedScope;
      if (reloadUnits) {
        _retryUnits = true;
        final choices = await widget.repository.units(
          _session!,
          profile,
          isCurrent: () => _alive(operation),
        );
        if (!_alive(operation)) return;
        final preferred =
            changedScope
                ? profile.value('depts_id')
                : _unit?.id ?? profile.value('depts_id');
        final matching = choices.where((choice) => choice.id == preferred);
        _units = choices;
        _unit = matching.isEmpty ? null : matching.first;
        _unitsLoaded = true;
        _scope = scope;
      }
      _retryUnits = false;
      final unit = _unit;
      final snapshot =
          unit == null
              ? null
              : await widget.repository.doctors(
                _session!,
                profile,
                _selected,
                unit,
                _units,
                isCurrent: () => _alive(operation),
              );
      if (!_alive(operation)) return;
      setState(() {
        _snapshot = snapshot;
        _busy = false;
        ++_generation;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (failure) {
      if (!mounted || !_alive(operation) || failure is ObsoleteRequest) return;
      if (failure is AppFailure && failure.kind == FailureKind.denied) {
        widget.auth.blockAccess(
          failure is AccountAccessFailure
              ? failure
              : const AccountAccessFailure.mobileAccess(),
        );
        return;
      }
      final unavailable = failure is UnitAppointmentUnavailable;
      setState(() {
        _busy = false;
        _failed = true;
        _snapshot = null;
        _error =
            unavailable
                ? 'Unit Appointment is not available for this account.'
                : dashboardErrorMessage(failure);
        if (unavailable) {
          _units = const [];
          _unit = _doctor = null;
        }
      });
      if (unavailable) {
        await _dialogs.show<void>(
          context,
          NativeDashboardMessageDialog(
            title: 'Not available',
            message: _error!,
            button: 'CLOSE',
          ),
        );
        if (mounted && _alive(operation) && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        return;
      }
      final retry = await _dialogs.show<bool>(
        context,
        AlertDialog(
          key: const Key('unit_appointment_error_dialog'),
          scrollable: true,
          title: Text(
            'Error!',
            style: dashboardDialogText(20, weight: FontWeight.w500),
          ),
          content: Text(_error!, style: dashboardDialogText(16)),
          actions: [
            TextButton(
              key: const Key('unit_appointment_error_exit'),
              onPressed: () => _answer(false),
              child: Text(
                'EXIT',
                style: dashboardDialogText(
                  14,
                  color: DocColors.primary,
                  weight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              key: const Key('unit_appointment_error_retry'),
              onPressed: () => _answer(true),
              child: Text(
                'RETRY',
                style: dashboardDialogText(
                  14,
                  color: DocColors.primary,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
      if (!mounted || !_alive(operation)) return;
      if (retry == true) {
        await _load(units: _retryUnits);
      } else if (retry == false && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _choose(bool choosingUnit, Rect anchor) async {
    if (!_ready) return;
    final choices =
        choosingUnit
            ? _units
            : _snapshot?.doctorChoices ?? const <UnitAppointmentChoice>[];
    if (choices.isEmpty) return;
    final operation = _operation;
    setState(() => _overlay = true);
    AppointmentHistoryChoice? picked;
    try {
      picked = await _dialogs.show<AppointmentHistoryChoice>(
        context,
        NativeAppointmentHistoryChoices(
          kind:
              choosingUnit
                  ? AppointmentHistoryFilter.unit
                  : AppointmentHistoryFilter.doctor,
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
    if (choosingUnit) {
      final matches = _units.where((choice) => choice.id == picked!.id);
      if (matches.isEmpty) return;
      setState(() {
        _unit = matches.first;
        _doctor = null;
      });
      await _load();
    } else {
      setState(
        () =>
            _doctor =
                picked!.id.isEmpty
                    ? null
                    : UnitAppointmentChoice(picked.id, picked.name),
      );
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
    if (_unit == null) {
      _toasts.show(context, 'Please Select Unit');
      return;
    }
    await _load();
  }

  Future<void> _stats() async {
    if (!_ready) return;
    setState(() => _overlay = true);
    try {
      await _dialogs.show<void>(
        context,
        AlertDialog(
          key: const Key('unit_appointment_totals_dialog'),
          scrollable: true,
          title:
              _unit == null
                  ? null
                  : Text(
                    _unit!.name,
                    style: dashboardDialogText(20, weight: FontWeight.w500),
                  ),
          content: Text.rich(
            TextSpan(
              style: dashboardDialogText(16),
              children: [
                const TextSpan(text: 'Total Appointment:   '),
                TextSpan(
                  text: '${_snapshot?.appointmentCount ?? 0}',
                  style: dashboardDialogText(
                    16,
                    color: Colors.black,
                    weight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: '\nTotal Blank Schedule:   '),
                TextSpan(
                  text: '${_snapshot?.blankCount ?? 0}',
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
            TextButton(
              key: const Key('unit_appointment_totals_close'),
              onPressed: () => _answer<void>(null),
              child: Text(
                'CLOSE',
                style: dashboardDialogText(
                  14,
                  color: DocColors.primary,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        dismissible: true,
      );
    } finally {
      if (mounted) setState(() => _overlay = false);
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

  void _answer<T>(T? result) {
    if (_current && _foreground && _dialogs.isOpen) {
      Navigator.pop<T>(context, result);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: NativeUnitAppointmentLayout(
      window: _window,
      selected: _selected,
      now: widget.repository.now(),
      units: _units,
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
      onUnit: (anchor) => unawaited(_choose(true, anchor)),
      onDoctor: (anchor) => unawaited(_choose(false, anchor)),
      onStats: () => unawaited(_stats()),
      onDate: (day) => unawaited(_date(day)),
      onMonth: (delta) => unawaited(_date(_window.move(_selected, delta))),
    ),
  );
}

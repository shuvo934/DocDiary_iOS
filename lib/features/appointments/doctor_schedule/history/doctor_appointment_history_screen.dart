import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/failure.dart';
import '../../../auth/account_access.dart';
import '../../../auth/auth_controller.dart';
import '../../../auth/auth_models.dart';
import '../../../auth/profile_repository.dart';
import '../../../dashboard/native_dashboard_dialogs.dart';
import 'doctor_appointment_history_models.dart';
import 'doctor_appointment_history_repository.dart';
import 'native_appointment_history_layout.dart';

class DoctorAppointmentHistoryScreen extends StatefulWidget {
  const DoctorAppointmentHistoryScreen({
    super.key,
    required this.auth,
    required this.repository,
    required this.patient,
  });
  final AuthController auth;
  final DoctorAppointmentHistoryRepository repository;
  final AppointmentHistoryPatient patient;
  @override
  State<DoctorAppointmentHistoryScreen> createState() =>
      _DoctorAppointmentHistoryScreenState();
}

class _DoctorAppointmentHistoryScreenState
    extends State<DoctorAppointmentHistoryScreen>
    with WidgetsBindingObserver {
  late final AuthSession _session;
  late AppointmentHistoryRange _range;
  late DateTime _evaluatedAt;
  final _dialogs = NativeDashboardDialogOwner();
  List<AppointmentHistoryRow> _rows = const [];
  final _selected = <AppointmentHistoryFilter, AppointmentHistoryChoice>{};
  bool _invalid = false,
      _foreground = true,
      _busy = true,
      _failed = false,
      _showFilters = false,
      _upcoming = false;
  int _operation = 0;
  bool get _current =>
      mounted &&
      !_invalid &&
      widget.auth.stage == AuthStage.authenticated &&
      widget.auth.session == _session;
  bool _alive(int operation) =>
      _current && _foreground && operation == _operation;
  bool get _ready =>
      _current && _foreground && !_busy && !_failed && !_dialogs.isOpen;
  @override
  void initState() {
    super.initState();
    _evaluatedAt = widget.repository.now();
    _range = AppointmentHistoryRange.initial(_evaluatedAt);
    final session = widget.auth.session;
    if (session == null ||
        widget.auth.profile == null ||
        session.account.role != AccountRole.doctor ||
        !widget.patient.valid) {
      _invalid = true;
      _busy = false;
      return;
    }
    _session = session;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    widget.auth.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current && _foreground) unawaited(_load(force: true));
    });
  }

  void _authChanged() {
    if (!_current) {
      ++_operation;
      _dialogs.close();
      if (mounted) {
        setState(() {
          _rows = const [];
          _selected.clear();
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
      if (_current) unawaited(_resume());
    }
  }

  Future<void> _resume() async {
    await WidgetsBinding.instance.endOfFrame;
    if (_current && _foreground) await _load(force: true);
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

  Future<void> _load({bool force = false}) async {
    if (!_current || !_foreground || _dialogs.isOpen || (_busy && !force)) {
      return;
    }
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _failed = false;
      _rows = const [];
      _selected.clear();
    });
    try {
      final profile = await _profile(operation);
      final upcoming = profile.value('upcoming_pat_history') == '1';
      final range =
          upcoming ? _range : _range.restrictToToday(widget.repository.now());
      final rows = await widget.repository.load(
        _session,
        profile,
        widget.patient,
        range,
        isCurrent: () => _alive(operation),
      );
      if (!_alive(operation)) return;
      setState(() {
        _range = range;
        _upcoming = upcoming;
        _rows = rows;
        _evaluatedAt = widget.repository.now();
        _busy = false;
      });
    } catch (failure) {
      if (!mounted ||
          !_alive(operation) ||
          failure is ObsoleteRequest ||
          _deny(failure)) {
        return;
      }
      setState(() {
        _busy = false;
        _failed = true;
        _rows = const [];
      });
      final retry = await _dialogs.show<bool>(
        context,
        AlertDialog(
          key: const Key('doctor_history_error'),
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
              key: const Key('doctor_history_error_exit'),
              onPressed: () => _answer(false, operation),
              child: const Text('Exit'),
            ),
            TextButton(
              key: const Key('doctor_history_error_retry'),
              onPressed: () => _answer(true, operation),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
      if (!_alive(operation)) return;
      if (retry == true) {
        await _load(force: true);
      } else if (retry == false) {
        await _back();
      }
    }
  }

  void _answer(bool value, int operation) {
    if (_alive(operation) && _dialogs.isOpen) Navigator.pop(context, value);
  }

  Future<void> _rangePicker() async {
    if (!_ready) return;
    final operation = _operation, now = widget.repository.now();
    final range = _upcoming ? _range : _range.restrictToToday(now);
    final selection = await _dialogs.show<DateTimeRange>(
      context,
      Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: DocColors.primary,
            onPrimary: Colors.white,
          ),
          textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Roboto'),
        ),
        child: DateRangePickerDialog(
          key: const Key('doctor_history_range_dialog'),
          helpText: 'Select Begin & End Date',
          saveText: 'SAVE',
          firstDate: DateTime(1900),
          lastDate:
              _upcoming ? DateTime(2100, 12, 31) : DateUtils.dateOnly(now),
          currentDate: now,
          initialDateRange: DateTimeRange(start: range.first, end: range.last),
        ),
      ),
      dismissible: true,
    );
    if (!_alive(operation) || selection == null || !_ready) return;
    final next = AppointmentHistoryRange(selection.start, selection.end);
    if (!next.allowed(widget.repository.now(), upcoming: _upcoming)) return;
    setState(() => _range = next);
    await _load();
  }

  Future<void> _filter(AppointmentHistoryFilter kind, Rect anchor) async {
    if (!_ready) return;
    final choices = appointmentHistoryChoices(_rows, kind),
        operation = _operation;
    if (choices.isEmpty) return;
    final selected = await _dialogs.show<AppointmentHistoryChoice>(
      context,
      NativeAppointmentHistoryChoices(
        kind: kind,
        choices: choices,
        anchor: anchor,
      ),
      dismissible: true,
      barrierColor: Colors.transparent,
    );
    if (!_alive(operation) || selected == null || !_ready) return;
    setState(() {
      if (selected.isClear) {
        _selected.remove(kind);
      } else {
        _selected[kind] = selected;
      }
    });
  }

  Future<void> _back() async {
    if (mounted && !_busy && !_dialogs.isOpen) {
      await Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: NativeAppointmentHistoryLayout(
      patient: widget.patient,
      range: _range,
      now: _evaluatedAt,
      clock: widget.repository.now,
      rows: _foreground ? filterAppointmentHistory(_rows, _selected) : const [],
      selected: Map.unmodifiable(_selected),
      choices: {
        for (final kind in AppointmentHistoryFilter.values)
          kind: appointmentHistoryChoices(_rows, kind),
      },
      showFilters: _showFilters,
      waiting: !_invalid && (!_current || !_foreground || _busy),
      enabled: _ready,
      failed: _failed,
      message:
          _invalid
              ? 'Appointment history is not available for this account.'
              : null,
      onBack: () => unawaited(_back()),
      onRange: () => unawaited(_rangePicker()),
      onFilter: (kind, anchor) => unawaited(_filter(kind, anchor)),
      onToggle: () {
        if (_ready) setState(() => _showFilters = !_showFilters);
      },
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

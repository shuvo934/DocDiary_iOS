import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/app_toast.dart';
import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../auth/account_access.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../../dashboard/dashboard_navigation.dart';
import '../../dashboard/native_dashboard_dialogs.dart';
import 'avail/doctor_appointment_avail_repository.dart';
import 'avail/native_appointment_avail_dialog.dart';
import 'history/doctor_appointment_history_models.dart';
import 'history/doctor_appointment_history_repository.dart';
import 'history/doctor_appointment_history_screen.dart';
import 'progress/doctor_progress_models.dart';
import 'progress/doctor_progress_repository.dart';
import 'progress/doctor_progress_screen.dart';
import 'doctor_appointment_models.dart';
import 'doctor_appointment_navigation.dart';
import 'doctor_appointment_repository.dart';
import 'native_doctor_appointment_layout.dart';

class DoctorAppointmentScreen extends StatefulWidget {
  const DoctorAppointmentScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.destinationBuilder,
  });
  final AuthController auth;
  final DoctorAppointmentRepository repository;
  final DashboardDestinationBuilder? destinationBuilder;
  @override
  State<DoctorAppointmentScreen> createState() =>
      _DoctorAppointmentScreenState();
}

class _DoctorAppointmentScreenState extends State<DoctorAppointmentScreen>
    with WidgetsBindingObserver {
  late final AuthSession _session;
  late final DoctorAppointmentWindow _window;
  late DateTime _selected, _evaluatedAt;
  final _dialogs = NativeDashboardDialogOwner();
  final _toasts = AppToastOwner();
  List<DoctorAppointmentRow> _rows = const [];
  DoctorAppointmentFeatures? _features;
  bool _invalid = false,
      _foreground = true,
      _busy = true,
      _writingAvail = false,
      _failedLoad = false,
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
      !_writingAvail &&
      !_failedLoad &&
      !_childAway &&
      !_dialogs.isOpen &&
      _features != null;
  @override
  void initState() {
    super.initState();
    _evaluatedAt = widget.repository.now();
    _window = DoctorAppointmentWindow(_evaluatedAt);
    _selected = _window.anchor;
    final session = widget.auth.session;
    if (session == null ||
        widget.auth.profile == null ||
        session.account.role != AccountRole.doctor) {
      _invalid = true;
      _busy = false;
      return;
    }
    _session = session;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
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
      _toasts.clear();
      if (mounted) {
        setState(() {
          _rows = const [];
          _features = null;
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
      _toasts.clear();
      if (mounted) setState(() {});
    } else if (!_foreground) {
      _foreground = true;
      if (_current && !_childAway) unawaited(_resume());
    }
  }

  Future<void> _resume() async {
    await WidgetsBinding.instance.endOfFrame;
    if (_current && _foreground && !_childAway) await _load(force: true);
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
    if (!_current ||
        !_foreground ||
        _writingAvail ||
        _childAway ||
        _dialogs.isOpen ||
        (_busy && !force)) {
      return;
    }
    final operation = ++_operation, date = _selected;
    setState(() {
      _busy = true;
      _failedLoad = false;
      _rows = const [];
    });
    try {
      final profile = await _profile(operation);
      final rows = await widget.repository.load(
        _session,
        profile,
        _window,
        date,
        isCurrent: () => _alive(operation),
      );
      if (!_alive(operation)) return;
      setState(() {
        _rows = rows;
        _features = DoctorAppointmentFeatures(profile);
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
      await _error(failure, operation);
    }
  }

  void _select(DateTime date) {
    if (!_ready || !_window.contains(date) || dateOnly(date) == _selected) {
      return;
    }
    setState(() => _selected = dateOnly(date));
    unawaited(_load());
  }

  void _month(int delta) {
    if (!_ready ||
        !const [-1, 1].contains(delta) ||
        !_window.canMove(_selected, delta)) {
      return;
    }
    _select(_window.move(_selected, delta));
  }

  void _answer(bool result, int operation) {
    if (_alive(operation) && _dialogs.isOpen) Navigator.pop(context, result);
  }

  Future<void> _error(Object failure, int operation) async {
    if (!mounted || !_alive(operation)) return;
    setState(() {
      _busy = false;
      _failedLoad = true;
      _rows = const [];
    });
    final retry = await _dialogs.show<bool>(
      context,
      AlertDialog(
        key: const Key('doctor_appointment_error'),
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
            key: const Key('doctor_appointment_error_exit'),
            onPressed: () => _answer(false, operation),
            child: const Text('Exit'),
          ),
          TextButton(
            key: const Key('doctor_appointment_error_retry'),
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

  Future<void> _action(
    DoctorAppointmentAction action,
    DoctorAppointmentRow? row,
  ) async {
    if (!_ready || (row != null && !_rows.contains(row))) return;
    if (action == DoctorAppointmentAction.walkIn
        ? !_features!.dynamicPrescription
        : row == null ||
            !row
                .present(_features!, widget.repository.now())
                .actions
                .contains(action)) {
      return;
    }
    final operation = ++_operation;
    setState(() => _busy = true);
    try {
      final profile = await _profile(operation),
          flags = DoctorAppointmentFeatures(profile);
      if (!mounted || !_alive(operation)) return;
      setState(() {
        _busy = false;
        _features = flags;
        _evaluatedAt = widget.repository.now();
      });
      final allowed =
          action == DoctorAppointmentAction.walkIn
              ? flags.dynamicPrescription
              : row != null &&
                  row.present(flags, _evaluatedAt).actions.contains(action);
      if (!allowed) {
        await _load(force: true);
        return;
      }
      if (action == DoctorAppointmentAction.prescriptionPreview &&
          row!.value('rvm_id').trim().isEmpty) {
        return;
      }
      if (action == DoctorAppointmentAction.video &&
          row!.value('doc_video_link').isEmpty) {
        _toasts.show(context, 'Video call is not available yet');
        return;
      }
      final route = doctorAppointmentRoute(action, row);
      final page =
          widget.destinationBuilder?.call(context, route) ??
          (action == DoctorAppointmentAction.history
              ? DoctorAppointmentHistoryScreen(
                auth: widget.auth,
                repository: DoctorAppointmentHistoryRepository(
                  widget.repository,
                ),
                patient: AppointmentHistoryPatient(
                  id: row!.value('patient_data'),
                  name: row.value('pat_name'),
                  code: row.value('pat_code'),
                ),
              )
              : action == DoctorAppointmentAction.progress
              ? DoctorProgressScreen(
                auth: widget.auth,
                repository: DoctorProgressRepository(widget.repository),
                seed: DoctorProgressSeed.fromAppointment(
                  row!,
                  ownerDoctorId: profile.doctorId,
                ),
              )
              : null);
      if (page == null && action == DoctorAppointmentAction.avail) {
        await _avail(row!, operation);
        return;
      }
      if (page == null) {
        await _dialogs.show<void>(
          context,
          AlertDialog(
            key: const Key('doctor_appointment_unavailable'),
            title: Text(switch (action) {
              DoctorAppointmentAction.avail => 'Avail',
              DoctorAppointmentAction.history => 'Appointment History',
              DoctorAppointmentAction.progress => 'Health Progress',
              DoctorAppointmentAction.video => 'Video Call',
              _ => 'Prescription',
            }),
            content: const Text('This feature is currently unavailable.'),
            actions: [
              TextButton(
                onPressed: () {
                  if (_alive(operation) && _dialogs.isOpen) {
                    Navigator.pop(context);
                  }
                },
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }
      _childAway = true;
      try {
        await _dialogs.push<void>(context, page);
      } finally {
        _childAway = false;
        if (_current && _foreground) await _load(force: true);
      }
    } catch (failure) {
      if (!mounted ||
          !_alive(operation) ||
          failure is ObsoleteRequest ||
          _deny(failure)) {
        return;
      }
      await _error(failure, operation);
    }
  }

  Future<void> _avail(DoctorAppointmentRow row, int operation) async {
    final result = await _dialogs.show<DoctorAppointmentAvailResult>(
      context,
      NativeAppointmentAvailDialog(
        onSubmit: (notes, dialogCurrent) async {
          if (!_alive(operation) || _writingAvail || !dialogCurrent()) {
            throw const ObsoleteRequest();
          }
          setState(() => _writingAvail = true);
          try {
            final profile = await _profile(operation);
            if (!dialogCurrent()) throw const ObsoleteRequest();
            return await DoctorAppointmentAvailRepository(
              widget.repository,
            ).submit(
              _session,
              profile,
              row,
              notes,
              isCurrent: () => _alive(operation) && dialogCurrent(),
            );
          } catch (failure) {
            if (_alive(operation) && _deny(failure)) {
              throw const ObsoleteRequest();
            }
            rethrow;
          } finally {
            _writingAvail = false;
            if (mounted) setState(() {});
            // If iOS suspended the dialog, wait for an in-flight write to
            // finish before fetching status. Resuming never repeats the POST.
            if (!_alive(operation) && _current && _foreground) {
              await _resume();
            }
          }
        },
      ),
    );
    if (!mounted || !_alive(operation) || result == null) return;
    _toasts.show(context, switch (result) {
      DoctorAppointmentAvailResult.created => 'Successfully Availed',
      DoctorAppointmentAvailResult.alreadyAvailed =>
        'This schedule is already availed.',
      DoctorAppointmentAvailResult.unavailable =>
        'This schedule is no longer available to avail.',
    });
    await _load(force: true);
  }

  Future<void> _back() async {
    if (mounted &&
        !_busy &&
        !_writingAvail &&
        !_dialogs.isOpen &&
        !_childAway) {
      await Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_writingAvail,
    child: NativeDoctorAppointmentLayout(
      window: _window,
      selected: _selected,
      now: _evaluatedAt,
      features: _features,
      rows: _foreground ? _rows : const [],
      waiting:
          !_invalid && (!_current || !_foreground || _busy || _writingAvail),
      enabled:
          _current &&
          _foreground &&
          !_childAway &&
          !_failedLoad &&
          !_writingAvail,
      message:
          _invalid
              ? 'Doctor appointments are not available for this account.'
              : _failedLoad
              ? ''
              : null,
      onBack: () => unawaited(_back()),
      onSelected: _select,
      onMonth: _month,
      onAction: (action, row) => unawaited(_action(action, row)),
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
    super.dispose();
  }
}

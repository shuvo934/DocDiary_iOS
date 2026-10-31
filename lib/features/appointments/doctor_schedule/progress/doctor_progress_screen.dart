import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/app_toast.dart';
import '../../../../core/failure.dart';
import '../../../auth/account_access.dart';
import '../../../auth/auth_controller.dart';
import '../../../auth/auth_models.dart';
import '../../../auth/profile_repository.dart';
import '../../../dashboard/native_dashboard_dialogs.dart';
import '../history/doctor_appointment_history_models.dart';
import '../history/native_appointment_history_layout.dart';
import 'doctor_progress_models.dart';
import 'doctor_progress_repository.dart';
import 'native_doctor_progress_layout.dart';

class DoctorProgressScreen extends StatefulWidget {
  const DoctorProgressScreen({
    super.key,
    required this.auth,
    required this.repository,
    required this.seed,
  });
  final AuthController auth;
  final DoctorProgressRepository repository;
  final DoctorProgressSeed seed;
  @override
  State<DoctorProgressScreen> createState() => _DoctorProgressScreenState();
}

class _DoctorProgressScreenState extends State<DoctorProgressScreen>
    with WidgetsBindingObserver {
  late final AuthSession _session;
  final _dialogs = NativeDashboardDialogOwner();
  final _toasts = AppToastOwner();
  final _notes = TextEditingController();
  DoctorProgressSnapshot? _snapshot;
  final _selected = <AppointmentHistoryFilter, AppointmentHistoryChoice>{};
  String _doctorName = '';
  int? _score;
  bool _invalid = false,
      _foreground = true,
      _busy = true,
      _failed = false,
      _writing = false,
      _restoreAfterWrite = false,
      _completed = false,
      _adding = false,
      _showFilters = false,
      _scoreMissing = false,
      _notesMissing = false,
      _dialogAnswered = false;
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
      !_writing &&
      !_failed &&
      !_dialogs.isOpen;
  bool get _canAdd =>
      !_completed && widget.seed.mayAdd(widget.repository.now());
  @override
  void initState() {
    super.initState();
    final session = widget.auth.session;
    if (session == null ||
        widget.auth.profile == null ||
        (widget.seed.appointment != null &&
            session.account.role != AccountRole.doctor) ||
        !widget.seed.valid) {
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
      _notes.clear();
      if (mounted) {
        setState(() {
          _snapshot = null;
          _selected.clear();
          _score = null;
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
        unawaited(_resume());
      }
    }
  }

  Future<void> _resume() async {
    await WidgetsBinding.instance.endOfFrame;
    if (_current && _foreground && !_writing) await _load(force: true);
  }

  Future<AccountProfile> _profile(int operation) async {
    final profile = await widget.auth.profiles.open(
      _session,
      recordLogin: false,
      isCurrent: () => _alive(operation),
    );
    widget.repository.guard(
      _session,
      profile,
      widget.seed,
      () => _alive(operation),
    );
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
        _writing ||
        _dialogs.isOpen ||
        (_busy && !force)) {
      return;
    }
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _failed = false;
      _snapshot = null;
      _selected.clear();
    });
    try {
      final profile = await _profile(operation);
      final data = await widget.repository.load(
        _session,
        profile,
        widget.seed,
        isCurrent: () => _alive(operation),
      );
      if (!_alive(operation)) return;
      setState(() {
        _snapshot = data;
        _doctorName = profile.value('doc_name');
        _busy = false;
        _completed =
            _completed || data.rows.any((row) => row.forSchedule(widget.seed));
        if (!_canAdd) _adding = false;
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
        _snapshot = null;
      });
      final retry = await _error(failure, operation, write: false);
      if (!_alive(operation)) return;
      if (retry == true) {
        await _load(force: true);
      } else if (retry == false) {
        await _back();
      }
    }
  }

  Future<bool?> _error(
    Object failure,
    int operation, {
    required bool write,
  }) async {
    _dialogAnswered = false;
    return await _dialogs.show<bool>(
      context,
      AlertDialog(
        key: Key(
          write ? 'doctor_progress_write_error' : 'doctor_progress_load_error',
        ),
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
            key: Key(
              write
                  ? 'doctor_progress_error_cancel'
                  : 'doctor_progress_error_exit',
            ),
            onPressed: () => _answer(false, operation),
            child: Text(write ? 'Cancel' : 'Exit'),
          ),
          TextButton(
            key: const Key('doctor_progress_error_retry'),
            onPressed: () => _answer(true, operation),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _answer(bool value, int operation) {
    if (!_dialogAnswered && _alive(operation) && _dialogs.isOpen) {
      _dialogAnswered = true;
      Navigator.pop(context, value);
    }
  }

  void _notice(String message) {
    _toasts.show(context, message);
  }

  void _tab(bool add) {
    if (!_ready || (add && !_canAdd)) return;
    FocusScope.of(context).unfocus();
    setState(() => _adding = add);
  }

  Future<void> _filter(AppointmentHistoryFilter kind, Rect anchor) async {
    if (!_ready || _snapshot == null) return;
    final choices =
        _snapshot!.choices[kind] ?? const <AppointmentHistoryChoice>[];
    if (choices.isEmpty) return;
    final operation = _operation;
    final choice = await _dialogs.show<AppointmentHistoryChoice>(
      context,
      KeyedSubtree(
        key: Key('doctor_progress_choices_${kind.name}'),
        child: NativeAppointmentHistoryChoices(
          kind: kind,
          choices: choices,
          anchor: anchor,
        ),
      ),
      dismissible: true,
      barrierColor: Colors.transparent,
    );
    if (!_alive(operation) || choice == null || !_ready) return;
    setState(() {
      if (choice.isClear) {
        _selected.remove(kind);
      } else {
        _selected[kind] = choice;
      }
    });
  }

  Future<void> _chooseScore(Rect anchor) async {
    if (!_ready || !_canAdd || !_adding) return;
    final operation = _operation;
    final choice = await _dialogs.show<AppointmentHistoryChoice>(
      context,
      KeyedSubtree(
        key: const Key('doctor_progress_choices_score'),
        child: NativeAppointmentHistoryChoices(
          kind: AppointmentHistoryFilter.service,
          choices: [
            for (var i = 1; i <= 10; i++) AppointmentHistoryChoice('$i', '$i'),
          ],
          anchor: anchor,
        ),
      ),
      dismissible: true,
      barrierColor: Colors.transparent,
    );
    if (!_alive(operation) || choice == null || !_ready || !_canAdd) return;
    setState(() {
      _score = int.parse(choice.id);
      _scoreMissing = false;
    });
  }

  Future<void> _confirm() async {
    if (!_ready || !_canAdd || !_adding) return;
    if (_score == null) {
      setState(() => _scoreMissing = true);
      _notice('Please Provide Progress');
      return;
    }
    if (_notes.text.trim().isEmpty) {
      setState(() => _notesMissing = true);
      _notice('Please Provide Progress Note');
      return;
    }
    FocusScope.of(context).unfocus();
    final operation = _operation, score = _score!, notes = _notes.text;
    _dialogAnswered = false;
    final yes = await _dialogs.show<bool>(
      context,
      AlertDialog(
        key: const Key('doctor_progress_confirm'),
        title: Text(
          'Add Progress!',
          style: dashboardDialogText(20, weight: FontWeight.w500),
        ),
        content: Text(
          'Do you want to add Progress for this patient in this schedule? if you add progress for this schedule, you will not be able to change or update this progress. So, please carefully add progress for patient.',
          style: dashboardDialogText(16),
        ),
        actions: [
          TextButton(
            key: const Key('doctor_progress_confirm_no'),
            onPressed: () => _answer(false, operation),
            child: const Text('No'),
          ),
          TextButton(
            key: const Key('doctor_progress_confirm_yes'),
            onPressed: () => _answer(true, operation),
            child: const Text('Yes'),
          ),
        ],
      ),
      dismissible: true,
    );
    if (!_alive(operation) || yes != true || !_ready) return;
    await _submit(
      DoctorProgressDraft(
        score: score,
        notes: notes,
        entryTime: progressEntryTime(widget.repository.now()),
      ),
    );
  }

  Future<void> _submit(DoctorProgressDraft draft) async {
    if (!_ready) return;
    if (!_canAdd) {
      _notice('Adding progress is no longer available for this schedule.');
      await _load(force: true);
      return;
    }
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _writing = true;
    });
    DoctorProgressResult? result;
    Object? error;
    try {
      final profile = await _profile(operation);
      result = await widget.repository.submit(
        _session,
        profile,
        widget.seed,
        draft,
        isCurrent: () => _alive(operation),
      );
    } catch (failure) {
      error = failure;
    } finally {
      _writing = false;
    }
    if (_restoreAfterWrite && _current && _foreground) {
      _restoreAfterWrite = false;
      await _resume();
      return;
    }
    if (!mounted || !_alive(operation)) return;
    setState(() => _busy = false);
    if (error != null) {
      if (error is ObsoleteRequest || _deny(error)) return;
      final retry = await _error(error, operation, write: true);
      if (_alive(operation) && retry == true) await _submit(draft);
      return;
    }
    setState(() {
      _completed = true;
      _adding = false;
      _score = null;
      _notes.clear();
      _scoreMissing = false;
      _notesMissing = false;
    });
    _notice(switch (result!) {
      DoctorProgressResult.created => 'New Progress Added',
      DoctorProgressResult.alreadyAdded =>
        'Progress has already been added for this schedule.',
      DoctorProgressResult.unavailable =>
        'This schedule is no longer available for adding progress.',
    });
    await _load(force: true);
  }

  Future<void> _back() async {
    if (mounted && !_busy && !_writing && !_dialogs.isOpen) {
      await Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_writing,
    child: NativeDoctorProgressLayout(
      seed: widget.seed,
      rows:
          _foreground
              ? filterDoctorProgress(_snapshot?.rows ?? const [], _selected)
              : const [],
      choices: _snapshot?.choices ?? const {},
      selected: Map.unmodifiable(_selected),
      notes: _notes,
      doctorName: _doctorName,
      score: _score,
      adding: _adding && _canAdd,
      canAdd: _canAdd,
      showFilters: _showFilters,
      waiting: !_invalid && (!_current || !_foreground || _busy || _writing),
      enabled: _ready,
      failed: _failed,
      scoreMissing: _scoreMissing,
      notesMissing: _notesMissing,
      message:
          _invalid
              ? 'Health progress is not available for this account.'
              : null,
      onBack: () => unawaited(_back()),
      onHistory: () => _tab(false),
      onAdd: () => _tab(true),
      onToggleFilters: () {
        if (_ready) setState(() => _showFilters = !_showFilters);
      },
      onFilter: (kind, anchor) => unawaited(_filter(kind, anchor)),
      onScore: (anchor) => unawaited(_chooseScore(anchor)),
      onSubmit: () => unawaited(_confirm()),
      onNotesChanged: (value) {
        if (_ready && _notesMissing && value.trim().isNotEmpty) {
          setState(() => _notesMissing = false);
        }
      },
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
    _notes.dispose();
    super.dispose();
  }
}

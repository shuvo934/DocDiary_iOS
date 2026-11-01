import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/native_dates.dart';
import '../../auth/auth_controller.dart';
import '../../auth/profile_repository.dart';
import '../doctor_schedule/history/doctor_appointment_history_models.dart';
import '../doctor_schedule/history/native_appointment_history_layout.dart';
import 'admin_appointment_models.dart';
import 'admin_appointment_repository.dart';
import 'admin_appointment_state.dart';
import 'native_admin_appointment_controls.dart';

class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({
    super.key,
    required this.auth,
    required this.repository,
    required this.draft,
    this.replacing,
  });
  final AuthController auth;
  final AdminAppointmentRepository repository;
  final AdminAppointmentDraft draft;
  final int? replacing;
  @override
  State<AdminScheduleScreen> createState() => _ScheduleState();
}

class _ScheduleState extends AdminAppointmentState<AdminScheduleScreen> {
  @override
  AuthController get auth => widget.auth;
  @override
  AdminAppointmentRepository get repository => widget.repository;
  AdminSchedule? get original =>
      widget.replacing == null
          ? null
          : widget.draft.schedules[widget.replacing!];
  late AdminAppointmentDay? _day = original?.day;
  late AdminAppointmentTime? _time =
      original?.duplicate == true ? null : original?.time;
  List<AdminAppointmentDay> _days = const [];
  List<AdminAppointmentTime> _times = const [];
  List<String> _taken = const [];
  String? _dateError, _timeError;
  bool _timeLoaded = false, _answered = false;
  @override
  void clearAppointment() {
    _day = null;
    _time = null;
    _days = const [];
    _times = const [];
    _taken = const [];
    _timeLoaded = false;
  }

  @override
  Future<void> refresh(
    AccountProfile profile,
    bool Function() isCurrent,
  ) async {
    final all = await repository.days(
      session!,
      profile,
      widget.draft,
      isCurrent: isCurrent,
    );
    if (!isCurrent()) return;
    final selected =
        widget.draft.schedules
            .asMap()
            .entries
            .where((e) => e.key != widget.replacing)
            .map((e) => e.value.day.id)
            .toSet();
    setState(() {
      _days =
          all
              .where((day) => !selected.contains(day.id) || day.id == _day?.id)
              .toList();
      if (_day != null && !_days.any((d) => d.id == _day!.id)) {
        _day = null;
        _time = null;
        _timeLoaded = false;
      }
      _dateError =
          _days.isEmpty
              ? 'No Appointment Date Found. Please Reselect Doctor'
              : null;
    });
    if (_day != null) await _loadTimes(profile, isCurrent);
  }

  Future<void> _loadTimes(
    AccountProfile profile,
    bool Function() isCurrent,
  ) async {
    final day = _day;
    if (day == null) return;
    final response = await repository.times(
      session!,
      profile,
      widget.draft,
      day,
      isCurrent: isCurrent,
    );
    if (!isCurrent() || day.id != _day?.id) return;
    final unavailable =
        widget.draft.schedules
            .asMap()
            .entries
            .where((e) => e.key != widget.replacing && e.value.day.id == day.id)
            .map((e) => e.value.time.id)
            .toSet();
    setState(() {
      _times = response.$1.where((t) => !unavailable.contains(t.id)).toList();
      _taken = response.$2;
      _timeLoaded = true;
      _time = _times.where((t) => t.id == _time?.id).firstOrNull;
      _timeError =
          _times.isNotEmpty
              ? null
              : response.$1.isEmpty
              ? 'No Appointment Time Found. Please Reselect Date'
              : 'All available time already Selected. Please Reselect Date';
    });
  }

  Future<void> _chooseDate() async {
    if (!ready || original != null || _days.isEmpty) return;
    final selected = await showOwned<DateTime>(
      NativeAdminScheduleDateDialog(days: _days, now: repository.now()),
    );
    if (!current || !foreground || selected == null) return;
    final day = _days.where((d) => d.date == dateOnly(selected)).firstOrNull;
    if (day == null) return;
    setState(() {
      _day = day;
      _time = null;
      _times = const [];
      _taken = const [];
      _timeLoaded = false;
      _dateError = _timeError = null;
    });
    await run(_loadTimes);
  }

  Future<void> _chooseTime(Rect anchor) async {
    if (!ready || !_timeLoaded || _taken.isNotEmpty || _times.isEmpty) return;
    final selected = await showOwned<AppointmentHistoryChoice>(
      NativeAppointmentHistoryChoices(
        kind: AppointmentHistoryFilter.unit,
        choices: [
          for (final row in _times) AppointmentHistoryChoice(row.id, row.label),
        ],
        anchor: anchor,
      ),
      dismissible: true,
      barrierColor: Colors.transparent,
    );
    if (!current || !foreground || selected == null) return;
    final time = _times.where((t) => t.id == selected.id).firstOrNull;
    if (time != null) {
      setState(() {
        _time = time;
        _timeError = null;
      });
    }
  }

  Future<void> _commit() async {
    if (!ready || _answered) return;
    if (_day == null) {
      setState(() => _dateError = 'Please Select Appointment Date');
      return;
    }
    if (_time == null || !_timeLoaded) {
      setState(() => _timeError = 'Please Select Appointment Time');
      return;
    }
    if (original == null &&
        !_taken.isNotEmpty &&
        !widget.draft.schedules.any((r) => r.day.id == _day!.id) &&
        widget.draft.remaining <= 0) {
      final dates = widget.draft.schedules.map((r) => r.day.label).toSet();
      final text =
          dates.isEmpty
              ? 'Service Quantity is Empty'
              : 'You have taken Service for ${dates.join(', ')} ${dates.length == 1 ? 'date' : 'dates'}. You can not add more schedule other than ${dates.length == 1 ? 'this date' : 'these dates'}.';
      await message('Service Quantity Empty!', text);
      return;
    }
    _answered = true;
    Navigator.pop(
      context,
      AdminSchedule(day: _day!, time: _time!, taken: _taken.isNotEmpty),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context),
        editing = widget.replacing != null;
    Widget warning(String? text) =>
        text == null
            ? const SizedBox()
            : Padding(
              padding: EdgeInsets.fromLTRB(7 * s, 2, 7 * s, 7 * s),
              child: Text(
                text,
                style: adminAppointmentText(
                  10,
                  s,
                  color: const Color(0xffff4444),
                ),
              ),
            );
    return PopScope(
      canPop: !busy && !dialogs.isOpen,
      child: NativeAdminAppointmentShell(
        editor: true,
        title: 'Add Schedule',
        onBack: () => unawaited(close()),
        child:
            busy || !current || !foreground
                ? const Center(
                  child: CircularProgressIndicator(
                    key: Key('admin_appointment_loading'),
                  ),
                )
                : SingleChildScrollView(
                  key: const PageStorageKey('admin_schedule_scroll'),
                  padding: EdgeInsets.all(4 * s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          4 * s,
                          8 * s,
                          4 * s,
                          4 * s,
                        ),
                        child: NativeAdminAppointmentField(
                          key: const Key('admin_schedule_date'),
                          label: 'Appointment Date',
                          value: _day?.label ?? '',
                          calendar: true,
                          enabled: ready && !editing && _days.isNotEmpty,
                          onTap: () => unawaited(_chooseDate()),
                        ),
                      ),
                      warning(_dateError),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          4 * s,
                          8 * s,
                          4 * s,
                          4 * s,
                        ),
                        child: Builder(
                          builder:
                              (fieldContext) => NativeAdminAppointmentField(
                                key: const Key('admin_schedule_time'),
                                label: 'Appointment Time',
                                value: _time?.label ?? '',
                                enabled:
                                    ready &&
                                    _timeLoaded &&
                                    _times.isNotEmpty &&
                                    _taken.isEmpty,
                                onTap: () {
                                  final box =
                                      fieldContext.findRenderObject()!
                                          as RenderBox;
                                  unawaited(
                                    _chooseTime(
                                      box.localToGlobal(Offset.zero) & box.size,
                                    ),
                                  );
                                },
                              ),
                        ),
                      ),
                      warning(_timeError),
                      if (_taken.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.all(4 * s),
                          child: NativeAdminTakenTimes(
                            label: 'Taken Schedule:',
                            times: _taken,
                          ),
                        ),
                      if (error != null && !busy)
                        Padding(
                          padding: EdgeInsets.all(4 * s),
                          child: TextButton(
                            key: const Key('admin_schedule_retry'),
                            onPressed:
                                ready
                                    ? () => unawaited(
                                      run(_day == null ? refresh : _loadTimes),
                                    )
                                    : null,
                            child: const Text('Retry'),
                          ),
                        ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: NativeAdminAppointmentButton(
                            key: const Key('admin_schedule_commit'),
                            label: editing ? 'UPDATE SCHEDULE' : 'ADD SCHEDULE',
                            onPressed:
                                ready ? () => unawaited(_commit()) : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}

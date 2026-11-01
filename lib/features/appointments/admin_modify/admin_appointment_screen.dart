import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../auth/auth_controller.dart';
import '../../auth/profile_repository.dart';
import '../all_schedule/all_appointment_repository.dart';
import '../all_schedule/all_appointment_screen.dart';
import '../doctor_schedule/history/doctor_appointment_history_models.dart';
import '../doctor_schedule/history/native_appointment_history_layout.dart';
import 'admin_appointment_models.dart';
import 'admin_appointment_repository.dart';
import 'admin_appointment_state.dart';
import 'admin_schedule_screen.dart';
import 'native_admin_appointment_controls.dart';
import 'native_admin_appointment_picker.dart';

class AdminAppointmentScreen extends StatefulWidget {
  const AdminAppointmentScreen({
    super.key,
    required this.auth,
    required this.repository,
  });
  final AuthController auth;
  final AdminAppointmentRepository repository;
  @override
  State<AdminAppointmentScreen> createState() => _AdminAppointmentScreenState();
}

class _AdminAppointmentScreenState
    extends AdminAppointmentState<AdminAppointmentScreen> {
  @override
  AuthController get auth => widget.auth;
  @override
  AdminAppointmentRepository get repository => widget.repository;
  AdminAppointmentDraft _draft = AdminAppointmentDraft();
  final _scroll = ScrollController();
  final _errors = <String, String>{};
  String? _notice;
  bool _resetAfterNotice = false;
  @override
  void clearAppointment() {
    _draft = AdminAppointmentDraft();
    _errors.clear();
    _notice = null;
  }

  @override
  Future<void> refresh(
    AccountProfile profile,
    bool Function() isCurrent,
  ) async {
    // Child routes own their GETs. Resume revalidates access without replaying
    // a save/cancel or clearing the locally reserved quantities/receipts.
    if (isCurrent()) await _announce();
  }

  Future<void> _announce() async {
    if (!current || !foreground || _notice == null) return;
    final text = _notice!, reset = _resetAfterNotice;
    _notice = null;
    await message('Success!', text);
    if (!current) return;
    if (reset) {
      setState(() {
        _draft = AdminAppointmentDraft(cancel: _draft.cancel);
        _errors.clear();
      });
    }
  }

  void _reset(bool cancel) {
    setState(() {
      _draft = AdminAppointmentDraft(cancel: cancel);
      _errors.clear();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _tab(bool cancel) async {
    if (!ready || _draft.cancel == cancel) return;
    if (_draft.stored &&
        !await confirm(
          'Switch section?',
          'You have Data Stored in this section. Do you want to switch to ${cancel ? 'Cancel' : 'Add'} Appointment section?',
          keyName: 'switch',
        )) {
      return;
    }
    if (ready) _reset(cancel);
  }

  Future<void> _viewAll() async {
    if (!ready) return;
    _reset(_draft.cancel);
    await openPage<void>(
      AllAppointmentScreen(
        auth: auth,
        repository: AllAppointmentRepository(repository.appointments),
      ),
    );
  }

  Future<void> _patient() async {
    if (!ready) return;
    final draft = _draft;
    final selected = await showOwned<AdminAppointmentChoice>(
      ownedChild(
        NativeAdminAppointmentPicker(
          auth: auth,
          repository: repository,
          kind: AdminAppointmentPicker.patient,
          cancel: draft.cancel,
        ),
      ),
    );
    if (!current || !foreground || !identical(draft, _draft)) return;
    if (selected == null) {
      await run(refresh);
      return;
    }
    setState(() {
      draft.selectPatient(selected);
      _errors.clear();
    });
    await run((profile, current) => _doctors(draft, profile, current));
  }

  Future<void> _doctors(
    AdminAppointmentDraft draft,
    AccountProfile profile,
    bool Function() current,
  ) async {
    retryStage = (p, c) => _doctors(draft, p, c);
    final rows = await repository.doctors(
      session!,
      profile,
      draft.patient!,
      cancel: draft.cancel,
      isCurrent: current,
    );
    if (!current() || !identical(draft, _draft)) return;
    setState(() {
      draft.doctors = rows;
      _errors.remove('doctor');
      if (rows.isEmpty) _errors['doctor'] = 'No Doctor found for this Patient';
    });
    if (rows.length == 1) {
      setState(() => draft.selectDoctor(rows.single));
      await _afterDoctor(draft, profile, current);
    }
  }

  Future<void> _afterDoctor(
    AdminAppointmentDraft draft,
    AccountProfile profile,
    bool Function() current,
  ) async {
    retryStage = (p, c) => _afterDoctor(draft, p, c);
    if (draft.cancel) {
      await _services(draft, profile, current);
      return;
    }
    final rows = await repository.payments(
      session!,
      profile,
      draft,
      isCurrent: current,
    );
    if (!current() || !identical(draft, _draft)) return;
    setState(() {
      draft.payments = rows;
      _errors.remove('payment');
      if (rows.isEmpty) {
        _errors['payment'] = 'No Payment List found for this Patient';
      }
    });
    if (rows.length == 1) {
      setState(() => draft.selectPayment(rows.single));
      await _services(draft, profile, current);
    }
  }

  Future<void> _services(
    AdminAppointmentDraft draft,
    AccountProfile profile,
    bool Function() current,
  ) async {
    retryStage = (p, c) => _services(draft, p, c);
    final rows = await repository.services(
      session!,
      profile,
      draft,
      isCurrent: current,
    );
    if (!current() || !identical(draft, _draft)) return;
    setState(() {
      draft.services = rows;
      _errors.remove('service');
      if (rows.isEmpty) {
        _errors['service'] = 'No Service List found for this Patient';
      }
    });
    if (rows.length == 1) {
      setState(() => draft.selectService(rows.single));
      await _afterService(draft, profile, current);
    }
  }

  Future<void> _afterService(
    AdminAppointmentDraft draft,
    AccountProfile profile,
    bool Function() current,
  ) async {
    retryStage = (p, c) => _afterService(draft, p, c);
    if (draft.cancel) {
      final rows = await repository.cancellations(
        session!,
        profile,
        draft,
        isCurrent: current,
      );
      if (!current() || !identical(draft, _draft)) return;
      setState(() {
        draft.cancellations = rows;
        _errors.remove('date');
        if (rows.isEmpty) {
          _errors['date'] = 'No Appointment Date found for this Patient';
        }
        if (rows.length == 1) draft.cancellation = rows.single;
      });
    } else {
      final limit = await repository.limit(
        session!,
        profile,
        draft,
        isCurrent: current,
      );
      if (current() && identical(draft, _draft)) {
        setState(() => draft.limit = limit);
      }
    }
  }

  Future<void> _doctorOrPayment(bool doctor) async {
    if (!ready) return;
    final draft = _draft, choices = doctor ? _draft.doctors : _draft.payments;
    if (choices.isEmpty) return;
    final selected = await showOwned<AdminAppointmentChoice>(
      ownedChild(
        NativeAdminAppointmentPicker(
          auth: auth,
          repository: repository,
          kind:
              doctor
                  ? AdminAppointmentPicker.doctor
                  : AdminAppointmentPicker.payment,
          choices: choices,
        ),
      ),
    );
    if (!current ||
        !foreground ||
        !identical(draft, _draft) ||
        selected == null ||
        !choices.contains(selected)) {
      return;
    }
    if ((doctor ? draft.doctor?.key : draft.payment?.key) == selected.key) {
      return;
    }
    setState(() {
      if (doctor) {
        draft.selectDoctor(selected);
      } else {
        draft.selectPayment(selected);
      }
      _errors.removeWhere((key, _) => key != 'patient');
    });
    await run(
      (profile, current) =>
          doctor
              ? _afterDoctor(draft, profile, current)
              : _services(draft, profile, current),
    );
  }

  Future<void> _option(bool service, Rect anchor) async {
    if (!ready) return;
    final draft = _draft;
    final options =
        service
            ? [
              for (final row in draft.services)
                AppointmentHistoryChoice(row.key, row.name),
            ]
            : [
              for (final row in draft.cancellations)
                AppointmentHistoryChoice(row.id, row.date),
            ];
    if (options.isEmpty) return;
    final picked = await showOwned<AppointmentHistoryChoice>(
      NativeAppointmentHistoryChoices(
        kind: AppointmentHistoryFilter.unit,
        choices: options,
        anchor: anchor,
      ),
      dismissible: true,
      barrierColor: Colors.transparent,
    );
    if (!current ||
        !foreground ||
        !identical(draft, _draft) ||
        picked == null) {
      return;
    }
    if (service) {
      final selected =
          draft.services.where((r) => r.key == picked.id).firstOrNull;
      if (selected == null || selected.key == draft.service?.key) return;
      setState(() {
        draft.selectService(selected);
        _errors.remove('service');
        _errors.remove('date');
      });
      await run((profile, current) => _afterService(draft, profile, current));
    } else {
      final selected =
          draft.cancellations.where((r) => r.id == picked.id).firstOrNull;
      if (selected != null) {
        setState(() {
          draft.cancellation = selected;
          _errors.remove('date');
        });
      }
    }
  }

  Future<void> _schedule([int? replacing]) async {
    if (!ready) return;
    final draft = _draft;
    if (draft.doctor == null || draft.service == null) {
      toasts.show(context, 'Please Select Doctor & Service First');
      return;
    }
    if (replacing == null) {
      if (draft.limit == null) {
        await run((p, c) => _afterService(draft, p, c));
        return;
      }
      if (!draft.limit!.permits(draft.schedules.length)) {
        await message(
          'Appointment Limit Reached!',
          'Appointment Schedule limit reached. You can have up to ${draft.limit!.allowed} upcoming appointments. Please complete or cancel an existing appointment before scheduling a new one.',
        );
        return;
      }
    } else if (draft.schedules[replacing].locked) {
      return;
    }
    final row = await openPage<AdminSchedule>(
      AdminScheduleScreen(
        auth: auth,
        repository: repository,
        draft: draft,
        replacing: replacing,
      ),
    );
    if (!current || !foreground || !identical(draft, _draft) || row == null) {
      return;
    }
    setState(() => draft.add(row, replacing: replacing));
  }

  Future<void> _remove(int index) async {
    if (!ready || _draft.schedules[index].locked) return;
    final draft = _draft, row = draft.schedules[index];
    final finish =
        row.submitted &&
        row.duplicate &&
        draft.schedules.where((r) => r.submitted && r.duplicate).length == 1;
    if (!await confirm(
      '${row.day.label}, ${row.time.label}',
      'Do you want to remove this schedule?${finish ? ' By removing this Schedule you will complete this add appointment process.' : ''}',
      keyName: 'remove',
    )) {
      return;
    }
    if (!mounted || !current || !identical(draft, _draft)) return;
    setState(() => draft.remove(index));
    toasts.show(context, 'Schedule Removed Successfully');
    if (finish) await close();
  }

  bool _validate() {
    final missing = _draft.missing;
    if (missing == null) return true;
    final field =
        missing.contains('Patient')
            ? 'patient'
            : missing.contains('Doctor')
            ? 'doctor'
            : missing.contains('Payment')
            ? 'payment'
            : missing.contains('Service')
            ? 'service'
            : 'date';
    setState(() => _errors[field] = missing);
    toasts.show(context, missing);
    return false;
  }

  Future<void> _submit() async {
    if (!ready || !_validate()) return;
    final draft = _draft;
    if (draft.cancel) {
      await run(refresh);
      if (!ready || !identical(draft, _draft)) return;
      if (!draft.cancellation!.canCancel(
        repository.now(),
        fullAccess: profile!.value('all_access_flag') == '1',
      )) {
        await message(
          'Unable to Cancel Appointment!',
          'This appointment can no longer be cancelled as the allowed cancellation time has expired.',
        );
        return;
      }
    }
    if (!await confirm(
      draft.cancel ? 'Cancel Appointment!' : 'Save Appointment!',
      draft.cancel
          ? 'Do you want to cancel this appointment?'
          : 'Do you want to save this appointment?',
      keyName: draft.cancel ? 'cancel_confirmation' : 'save_confirmation',
    )) {
      return;
    }
    if (!current || !foreground || !identical(draft, _draft)) return;
    await run((profile, isCurrent) async {
      if (!identical(draft, _draft)) return;
      if (draft.cancel) {
        await repository.cancel(
          session!,
          profile,
          draft,
          isCurrent: isCurrent,
          ownsResponse: () => current,
        );
        if (current && identical(draft, _draft)) {
          _notice = 'Appointment Canceled successfully.';
          _resetAfterNotice = true;
        }
      } else {
        var access = profile;
        var first = true;
        for (final row in List<AdminSchedule>.of(draft.schedules)) {
          if (!isCurrent()) return;
          if (row.submitted) continue;
          if (!first) access = await fresh(isCurrent);
          first = false;
          final duplicate = await repository.insert(
            session!,
            access,
            draft,
            row,
            isCurrent: isCurrent,
            ownsResponse: () => current,
          );
          if (!current || !identical(draft, _draft)) return;
          row.submitted = true;
          row.duplicate = duplicate;
        }
        if (current &&
            identical(draft, _draft) &&
            draft.schedules.every((r) => r.submitted)) {
          final duplicates = draft.schedules.where((r) => r.duplicate).length;
          _resetAfterNotice = duplicates == 0;
          _notice =
              duplicates == 0
                  ? 'Appointment saved successfully.'
                  : 'Red Marked Appointment Time has already been taken. Please Reselect Time or Date.${duplicates == draft.schedules.length ? '' : ' Green Marked Appointment Time added successfully.'}';
        }
      }
    }, write: true);
    await _announce();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft, s = adminAppointmentScale(context), active = ready;
    Widget field(
      String key,
      String label,
      String value, {
      VoidCallback? onTap,
      ValueChanged<Rect>? onOption,
      bool enabled = true,
      bool search = false,
      bool dropdown = true,
    }) => Padding(
      padding: EdgeInsets.fromLTRB(4 * s, 4 * s, 4 * s, 4 * s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder:
                (fieldContext) => NativeAdminAppointmentField(
                  key: Key('admin_appointment_$key'),
                  label: label,
                  value: value,
                  enabled: enabled && active,
                  search: search,
                  center: key == 'quantity',
                  multiline: const ['patient', 'doctor', 'unit'].contains(key),
                  boldLabel: const [
                    'doctor',
                    'unit',
                    'payment',
                    'service',
                    'quantity',
                    'date',
                  ].contains(key),
                  dropdown: dropdown,
                  onTap:
                      onOption == null
                          ? onTap
                          : () {
                            final box =
                                fieldContext.findRenderObject()! as RenderBox;
                            onOption(box.localToGlobal(Offset.zero) & box.size);
                          },
                ),
          ),
          if (_errors[key] != null)
            Padding(
              padding: EdgeInsets.fromLTRB(4 * s, 4, 3 * s, 2 * s),
              child: Text(
                _errors[key]!,
                style: adminAppointmentText(
                  10,
                  s,
                  color: Colors.red,
                  family: 'Roboto',
                  weight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
    return PopScope(
      canPop: !busy && !writing && !dialogs.isOpen,
      child: NativeAdminAppointmentShell(
        onBack: () => unawaited(close()),
        onAll: active ? () => unawaited(_viewAll()) : null,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(4 * s, 8 * s, 4 * s, 0),
              child: Row(
                children: [
                  for (final cancel in [false, true])
                    Expanded(
                      child: InkWell(
                        key: Key(
                          cancel
                              ? 'admin_appointment_tab_cancel'
                              : 'admin_appointment_tab_add',
                        ),
                        onTap: active ? () => unawaited(_tab(cancel)) : null,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                width: 2,
                                color:
                                    draft.cancel == cancel
                                        ? DocColors.greenSea
                                        : Colors.transparent,
                              ),
                            ),
                          ),
                          child: Text(
                            cancel ? 'CANCEL' : 'ADD',
                            style: adminAppointmentText(
                              11,
                              s,
                              family: 'PatuaOne',
                              weight: FontWeight.w700,
                              color:
                                  draft.cancel == cancel
                                      ? DocColors.greenSea
                                      : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child:
                  busy || !current || !foreground
                      ? const Center(
                        child: CircularProgressIndicator(
                          key: Key('admin_appointment_loading'),
                        ),
                      )
                      : profile == null
                      ? Center(
                        child: Text(
                          error ??
                              'Appointment details are unavailable. Please return to Login.',
                        ),
                      )
                      : SingleChildScrollView(
                        key: const PageStorageKey(
                          'admin_appointment_form_scroll',
                        ),
                        controller: _scroll,
                        child: Padding(
                          padding: EdgeInsets.only(top: 6 * s, bottom: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              field(
                                'patient',
                                draft.patient == null
                                    ? 'Select Patient'
                                    : 'Patient',
                                draft.patient?.name ?? '',
                                search: true,
                                onTap: () => unawaited(_patient()),
                              ),
                              field(
                                'doctor',
                                draft.doctor == null
                                    ? 'Select Doctor'
                                    : 'Doctor',
                                draft.doctor?.name ?? '',
                                enabled: draft.doctors.isNotEmpty,
                                onTap: () => unawaited(_doctorOrPayment(true)),
                              ),
                              field(
                                'unit',
                                'Unit',
                                draft.doctor?.value('depts_name') ?? '',
                                dropdown: false,
                                enabled: false,
                              ),
                              if (!draft.cancel)
                                field(
                                  'payment',
                                  draft.payment == null
                                      ? 'Select Payment Code'
                                      : 'Payment Code',
                                  draft.payment?.name ?? '',
                                  enabled: draft.payments.isNotEmpty,
                                  onTap:
                                      () => unawaited(_doctorOrPayment(false)),
                                ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 8,
                                    child: field(
                                      'service',
                                      draft.service == null
                                          ? 'Select Service'
                                          : 'Service',
                                      draft.service?.name ?? '',
                                      enabled: draft.services.isNotEmpty,
                                      onOption:
                                          (rect) =>
                                              unawaited(_option(true, rect)),
                                    ),
                                  ),
                                  if (!draft.cancel)
                                    Expanded(
                                      flex: 2,
                                      child: field(
                                        'quantity',
                                        'Qty',
                                        draft.service == null
                                            ? ''
                                            : draft.remaining.toString(),
                                        enabled: false,
                                        dropdown: false,
                                      ),
                                    ),
                                ],
                              ),
                              if (draft.cancel) ...[
                                field(
                                  'date',
                                  draft.cancellation == null
                                      ? 'Select Appointment Date'
                                      : 'Appointment Date',
                                  draft.cancellation?.date ?? '',
                                  enabled: draft.cancellations.isNotEmpty,
                                  onOption:
                                      (rect) => unawaited(_option(false, rect)),
                                ),
                                if (draft.cancellation != null)
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      4 * s,
                                      8 * s,
                                      4 * s,
                                      4 * s,
                                    ),
                                    child: NativeAdminTakenTimes(
                                      label: 'Time Schedule:',
                                      times: draft.cancellation!.times,
                                    ),
                                  ),
                              ] else
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    5,
                                    12,
                                    5,
                                    7,
                                  ),
                                  child: Material(
                                    color: Colors.white,
                                    elevation: 1,
                                    borderRadius: BorderRadius.circular(10 * s),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      children: [
                                        const NativeAdminAppointmentTableRow(
                                          cells: [
                                            'Appointment Date',
                                            'Appointment Time',
                                            '',
                                          ],
                                          weights: [5, 4, 1],
                                          header: true,
                                          headerFontSize: 11,
                                        ),
                                        for (final entry
                                            in draft.schedules.asMap().entries)
                                          _scheduleRow(
                                            entry.key,
                                            entry.value,
                                            s,
                                            active,
                                          ),
                                        if (!draft.collisions)
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Padding(
                                              padding: EdgeInsets.fromLTRB(
                                                4 * s,
                                                4 * s,
                                                4 * s,
                                                2,
                                              ),
                                              child: TextButton(
                                                key: const Key(
                                                  'admin_appointment_add_schedule',
                                                ),
                                                onPressed:
                                                    active
                                                        ? () => unawaited(
                                                          _schedule(),
                                                        )
                                                        : null,
                                                style: TextButton.styleFrom(
                                                  backgroundColor:
                                                      DocColors.primary,
                                                  foregroundColor: Colors.white,
                                                  elevation: 2,
                                                  minimumSize: const Size(
                                                    88,
                                                    36,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 6,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10 * s,
                                                        ),
                                                  ),
                                                ),
                                                child: Text(
                                                  'ADD SCHEDULE',
                                                  style: adminAppointmentText(
                                                    12,
                                                    s,
                                                    family: 'PatuaOne',
                                                    weight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ).copyWith(
                                                    letterSpacing: 1.25,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: NativeAdminAppointmentButton(
                  key: const Key('admin_appointment_submit'),
                  label:
                      draft.cancel ? 'CANCEL APPOINTMENT' : 'SAVE APPOINTMENT',
                  onPressed: active ? () => unawaited(_submit()) : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduleRow(int index, AdminSchedule row, double s, bool active) {
    final edit =
        active && !row.locked ? () => unawaited(_schedule(index)) : null;
    Widget cell(String text, {required Key key, required Color color}) =>
        Material(
          color: DocColors.clouds,
          child: InkWell(
            key: key,
            onTap: edit,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Center(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: adminAppointmentText(
                    9.5,
                    s,
                    family: 'OpenSans',
                    weight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Keep the same 5:4:1 columns and half-gutters as the header.
            // The gutter is outside each colored surface, so it stays white.
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: cell(
                  row.day.label,
                  key: Key('admin_appointment_schedule_$index'),
                  color: Colors.black54,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: cell(
                  row.time.label,
                  key: Key('admin_appointment_schedule_time_$index'),
                  color:
                      row.submitted
                          ? row.duplicate
                              ? const Color(0xffe74c3c)
                              : DocColors.greenSea
                          : Colors.black54,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 2),
                child: ColoredBox(
                  key: Key('admin_appointment_schedule_delete_cell_$index'),
                  color: DocColors.clouds,
                  child:
                      row.locked
                          ? const SizedBox()
                          : IconButton(
                            key: Key('admin_appointment_remove_$index'),
                            tooltip: 'Remove schedule',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed:
                                active ? () => unawaited(_remove(index)) : null,
                            icon: const Icon(
                              Icons.cancel,
                              size: 24,
                              color: DocColors.primary,
                            ),
                          ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../auth/auth_controller.dart';
import '../auth/profile_repository.dart';
import 'payment_models.dart';
import 'payment_repository.dart';
import 'payment_state.dart';
import 'native_payment_controls.dart';
import 'native_payment_patient_picker.dart';
import 'payment_service_screen.dart';
import 'payment_confirmation_dialog.dart';
import 'payment_update_models.dart';
import 'payment_update_repository.dart';
import 'native_payment_code_picker.dart';
import 'native_payment_update_controls.dart';

class PaymentAddScreen extends StatefulWidget {
  const PaymentAddScreen({
    super.key,
    required this.auth,
    required this.repository,
  });
  final AuthController auth;
  final PaymentRepository repository;
  @override
  State<PaymentAddScreen> createState() => _PaymentAddState();
}

class _PaymentAddState extends PaymentState<PaymentAddScreen> {
  @override
  AuthController get auth => widget.auth;
  @override
  PaymentRepository get repository =>
      _updating ? _updateRepository : widget.repository;
  late final _updateRepository = PaymentUpdateRepository(
    widget.repository.appointments,
  );
  PaymentDraft _draft = PaymentDraft();
  PaymentUpdateDraft _updateDraft = PaymentUpdateDraft();
  bool _updating = false;
  final _scroll = ScrollController();
  bool _announcing = false;
  @override
  void clearPayment() {
    _draft = PaymentDraft();
    _updateDraft = PaymentUpdateDraft();
  }

  @override
  Future<void> refresh(
    AccountProfile profile,
    bool Function() isCurrent,
  ) async {
    if ((_updating
            ? _updateDraft.submission?.uncertain
            : _draft.submission?.uncertain) ==
        true) {
      throw const PaymentWriteUncertain();
    }
    if (_updating && _updateDraft.payment != null && !_updateDraft.loaded) {
      await _loadUpdate(profile, isCurrent);
    }
    await _announce();
  }

  Future<void> _announce() async {
    final complete =
        _updating
            ? _updateDraft.submission?.complete
            : _draft.submission?.complete;
    if (!current ||
        !foreground ||
        complete != true ||
        _announcing ||
        dialogs.isOpen) {
      return;
    }
    _announcing = true;
    try {
      await message(
        'Success!',
        _updating
            ? 'Payment Updated Successfully.\nPayment Code: ${_updateDraft.payment!.name}'
            : 'Payment Received Successfully.\nPayment Code: ${_draft.submission!.masterCode}',
      );
      if (current && foreground) await close(force: true);
    } finally {
      _announcing = false;
    }
  }

  Future<void> _tab(bool update) async {
    if (!ready || update == _updating || _draft.locked || _updateDraft.locked) {
      return;
    }
    await run((p, c) async {
      if (update) _updateRepository.guard(session!, p, c);
    });
    if (!ready) return;
    final hasServices =
        _updating ? _updateDraft.lines.isNotEmpty : _draft.services.isNotEmpty;
    if (hasServices &&
        !await confirm(
          'Switch Payment?',
          'You have Data Stored in this section. Do you want to switch to ${update ? 'Update' : 'Add'} payment section?',
          keyName: 'switch_tab',
        )) {
      return;
    }
    if (!ready) return;
    setState(() {
      clearPayment();
      _updating = update;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _loadUpdate(AccountProfile p, bool Function() isCurrent) async {
    final draft = _updateDraft, payment = _updateDraft.payment;
    if (payment == null || draft.loaded) return;
    final rows = await _updateRepository.details(
      session!,
      p,
      payment,
      isCurrent: isCurrent,
    );
    final methods =
        p.value('is_pay_mode_active') == '1'
            ? await _updateRepository.savedMethods(
              session!,
              p,
              payment,
              isCurrent: isCurrent,
            )
            : const <PaymentAllocation>[];
    if (!isCurrent() || !identical(draft, _updateDraft)) return;
    setState(() => draft.load(rows, methods));
    if (draft.blocked) throw PaymentScheduleBlocked(rows);
  }

  Future<void> _payment() async {
    if (!ready || _updateDraft.locked) return;
    final draft = _updateDraft;
    final selected = await showOwned<PaymentChoice>(
      NativePaymentCodePicker(auth: auth, repository: _updateRepository),
    );
    if (!current ||
        !foreground ||
        !identical(draft, _updateDraft) ||
        selected == null) {
      return;
    }
    setState(() => draft.select(selected));
    if (_scroll.hasClients) _scroll.jumpTo(0);
    await run(_loadUpdate);
  }

  Future<void> _updateService([PaymentUpdateLine? editing]) async {
    final draft = _updateDraft;
    if (!ready || !draft.loaded || draft.locked) return;
    if (draft.blocked) {
      await message('Warning!', paymentScheduleWarning);
      return;
    }
    final line = await openPage<PaymentServiceLine>(
      PaymentServiceScreen(
        auth: auth,
        repository: _updateRepository,
        patient: draft.patient!,
        lines: List.unmodifiable(draft.lines.map((r) => r.line)),
        editing: editing?.line,
        updateRow: editing,
      ),
    );
    if (!current ||
        !foreground ||
        !identical(draft, _updateDraft) ||
        line == null) {
      return;
    }
    setState(() => draft.add(line, replacing: editing));
  }

  Future<void> _availability(PaymentUpdateLine row) async {
    if (!ready) return;
    await showOwned<void>(NativePaymentAvailabilityDialog(row: row));
  }

  Future<void> _writeUpdate(AccountProfile p, bool Function() isCurrent) async {
    final draft = _updateDraft, receipt = _updateDraft.submission;
    if (receipt == null) return;
    bool canReopen() =>
        !receipt.uncertain &&
        receipt.servicesAcknowledged == 0 &&
        receipt.methodsAcknowledged == 0;
    try {
      await _updateRepository.submitUpdate(
        session!,
        p,
        receipt,
        isCurrent: isCurrent,
        ownsResponse: () => current,
      );
    } on PaymentSettingsChanged {
      if (canReopen()) draft.submission = null;
      rethrow;
    } on PaymentScheduleBlocked catch (failure) {
      draft.scheduleBlocked = true;
      if (canReopen()) {
        draft.submission = null;
        draft.load(failure.lines, draft.methods);
      }
      rethrow;
    } on PaymentRecordChanged {
      if (canReopen()) _updateDraft = PaymentUpdateDraft();
      rethrow;
    }
  }

  Future<void> _updatePay() async {
    if (!ready || !_updateDraft.loaded || _updateDraft.blocked) return;
    if (_updateDraft.lines.isEmpty) {
      toasts.show(context, 'Please Add Service.');
      return;
    }
    if (_updateDraft.submission != null) {
      await run(_writeUpdate, write: true);
      await _announce();
      return;
    }
    final draft = _updateDraft;
    bool? requiresMode;
    await run(
      (p, c) async => requiresMode = p.value('is_pay_mode_active') == '1',
    );
    if (!ready || !identical(draft, _updateDraft) || requiresMode == null) {
      return;
    }
    PaymentConfirmation? confirmation;
    if (requiresMode!) {
      confirmation = await showOwned<PaymentConfirmation>(
        PaymentConfirmationDialog(
          auth: auth,
          repository: _updateRepository,
          lines: List.unmodifiable(draft.lines.map((r) => r.line)),
          initialAllocations: draft.methods,
        ),
      );
      if (!current ||
          !foreground ||
          !identical(draft, _updateDraft) ||
          confirmation == null) {
        return;
      }
    }
    if (!mounted) return;
    final receipt = PaymentUpdateSubmission(draft, confirmation);
    if (!receipt.hasChanges) {
      toasts.show(
        context,
        requiresMode!
            ? 'No new changes happened to update'
            : 'No Service Changed for Update.',
      );
      return;
    }
    if (!await confirm(
      'Update Payment!',
      'Do you want to Update Payment for this patient?',
      keyName: 'update_confirmation',
    )) {
      return;
    }
    if (!ready || !identical(draft, _updateDraft)) return;
    setState(() => draft.submission = receipt);
    await run(_writeUpdate, write: true);
    await _announce();
  }

  Future<void> _patient() async {
    if (!ready || _draft.locked) return;
    final draft = _draft;
    final selected = await showOwned<PaymentChoice>(
      NativePaymentPatientPicker(auth: auth, repository: repository),
    );
    if (!current ||
        !foreground ||
        !identical(draft, _draft) ||
        selected == null) {
      return;
    }
    setState(
      () => draft.selectPatient(selected, paymentDate(repository.now())),
    );
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _service([PaymentServiceLine? editing]) async {
    if (!ready || _draft.patient == null || _draft.locked) return;
    final draft = _draft;
    final line = await openPage<PaymentServiceLine>(
      PaymentServiceScreen(
        auth: auth,
        repository: repository,
        patient: draft.patient!,
        lines: List.unmodifiable(draft.services),
        editing: editing,
      ),
    );
    if (!current || !foreground || !identical(draft, _draft) || line == null) {
      return;
    }
    setState(() => draft.add(line, replacing: editing));
  }

  Future<void> _delete(PaymentServiceLine line) async {
    if (!ready || _draft.locked) return;
    final draft = _draft;
    if (await confirm(
      line.service.name,
      'Do you want to delete this Service?',
      keyName: 'delete_service',
    )) {
      if (mounted && current && identical(draft, _draft)) {
        setState(() => draft.services.remove(line));
        toasts.show(context, 'Service Deleted Successfully');
      }
    }
  }

  Future<void> _write(AccountProfile profile, bool Function() isCurrent) async {
    final receipt = _draft.submission;
    if (receipt == null) return;
    try {
      await repository.submit(
        session!,
        profile,
        receipt,
        isCurrent: isCurrent,
        ownsResponse: () => current,
      );
    } on PaymentSettingsChanged {
      if (receipt.masterId == null && !receipt.uncertain) {
        _draft.submission = null;
      }
      rethrow;
    }
  }

  Future<void> _pay() async {
    if (!ready) return;
    if (_draft.services.isEmpty) {
      toasts.show(context, 'Please Add Service.');
      return;
    }
    if (_draft.submission != null) {
      await run(_write, write: true);
      await _announce();
      return;
    }
    final draft = _draft;
    bool? requiresMode;
    await run((p, c) async {
      requiresMode = p.value('is_pay_mode_active') == '1';
    });
    if (!ready || !identical(draft, _draft) || requiresMode == null) return;
    PaymentConfirmation? confirmation;
    if (requiresMode!) {
      confirmation = await showOwned<PaymentConfirmation>(
        PaymentConfirmationDialog(
          auth: auth,
          repository: repository,
          lines: List.unmodifiable(draft.services),
        ),
      );
      if (!current ||
          !foreground ||
          !identical(draft, _draft) ||
          confirmation == null) {
        return;
      }
    }
    if (!await confirm(
      'Add Payment!',
      'Do you want to Add Payment from this patient?',
      keyName: 'save_confirmation',
    )) {
      return;
    }
    if (!ready || !identical(draft, _draft)) return;
    setState(() => draft.submission = PaymentSubmission(draft, confirmation));
    await run(_write, write: true);
    await _announce();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context), draft = _draft;
    final active = ready && !draft.locked;
    final update = _updateDraft;
    final updateActive = ready && !update.locked;
    final updateVisible = profile?.value('all_access_flag') == '1';
    final date =
        draft.date.isEmpty
            ? ''
            : draft.date.replaceAllMapped(
              RegExp(r'-([A-Z]{3})-'),
              (m) => '-${m[1]![0]}${m[1]!.substring(1).toLowerCase()}-',
            );
    return PopScope(
      canPop: !busy && !writing && !dialogs.isOpen,
      child: NativePaymentShell(
        onBack: () => unawaited(close()),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(4 * s, 8 * s, 4 * s, 0),
                child: Row(
                  children: [
                    for (final update in [false, if (updateVisible) true])
                      Expanded(
                        child: Semantics(
                          selected: update == _updating,
                          enabled:
                              ready && !draft.locked && !_updateDraft.locked,
                          child: InkWell(
                            onTap:
                                ready && !draft.locked && !_updateDraft.locked
                                    ? () => unawaited(_tab(update))
                                    : null,
                            child: Container(
                              key: Key(
                                update
                                    ? 'payment_tab_update'
                                    : 'payment_tab_add',
                              ),
                              constraints: const BoxConstraints(minHeight: 48),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    width: 2,
                                    color:
                                        update == _updating
                                            ? DocColors.greenSea
                                            : Colors.transparent,
                                  ),
                                ),
                              ),
                              child: Text(
                                update ? 'UPDATE' : 'ADD',
                                style: adminAppointmentText(
                                  11,
                                  s,
                                  family: 'PatuaOne',
                                  weight: FontWeight.w700,
                                  color:
                                      update == _updating
                                          ? DocColors.greenSea
                                          : Colors.black54,
                                ),
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
                            key: Key('payment_loading'),
                          ),
                        )
                        : SingleChildScrollView(
                          key: const Key('payment_scroll'),
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(
                            4 * s,
                            10 * s,
                            4 * s,
                            10 * s,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_updating) ...[
                                NativeAdminAppointmentField(
                                  key: const Key('payment_update_code'),
                                  label:
                                      update.payment == null
                                          ? 'Select Payment Code'
                                          : 'Payment Code',
                                  value: update.payment?.name ?? '',
                                  search: true,
                                  onTap:
                                      updateActive
                                          ? () => unawaited(_payment())
                                          : null,
                                ),
                                if (update.loaded) ...[
                                  SizedBox(height: 5 * s),
                                  NativePaymentPatientDetails(
                                    patient: update.patient!,
                                    date: update.payment!.value('prm_date'),
                                    prescriptionCode: update.payment!.value(
                                      'ph_sub_code',
                                    ),
                                  ),
                                  SizedBox(height: 10 * s),
                                  NativePaymentUpdateServices(
                                    lines: update.lines,
                                    onAdd:
                                        updateActive
                                            ? () => unawaited(_updateService())
                                            : null,
                                    onEdit:
                                        updateActive
                                            ? (row) =>
                                                unawaited(_updateService(row))
                                            : null,
                                    onAvailability:
                                        ready
                                            ? (row) =>
                                                unawaited(_availability(row))
                                            : null,
                                  ),
                                ],
                              ] else ...[
                                NativeAdminAppointmentField(
                                  key: const Key('payment_patient'),
                                  label:
                                      draft.patient == null
                                          ? 'Select Prescription Code'
                                          : 'Prescription Code',
                                  value:
                                      draft.patient?.value('ph_sub_code') ?? '',
                                  search: true,
                                  onTap:
                                      active
                                          ? () => unawaited(_patient())
                                          : null,
                                ),
                                if (draft.patient != null) ...[
                                  SizedBox(height: 9 * s),
                                  NativePaymentPatientDetails(
                                    patient: draft.patient!,
                                    date: date,
                                  ),
                                  SizedBox(height: 10 * s),
                                  NativePaymentServices(
                                    lines: draft.services,
                                    onAdd:
                                        active
                                            ? () => unawaited(_service())
                                            : null,
                                    onEdit:
                                        active
                                            ? (row) => unawaited(_service(row))
                                            : null,
                                    onDelete:
                                        active
                                            ? (row) => unawaited(_delete(row))
                                            : null,
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
              ),
              if (_updating && update.loaded)
                Padding(
                  padding: EdgeInsets.fromLTRB(4 * s, 8, 4 * s, 4),
                  child: NativeAdminAppointmentButton(
                    key: const Key('payment_update_commit'),
                    label:
                        update.submission != null &&
                                !update.submission!.complete
                            ? 'CONTINUE PAYMENT'
                            : 'UPDATE PAYMENT',
                    onPressed:
                        ready &&
                                !update.blocked &&
                                update.submission?.uncertain != true
                            ? () => unawaited(_updatePay())
                            : null,
                    enabled:
                        !update.blocked && update.submission?.uncertain != true,
                  ),
                ),
              if (!_updating && draft.patient != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(4 * s, 8, 4 * s, 4),
                  child: NativeAdminAppointmentButton(
                    key: const Key('payment_commit'),
                    label:
                        draft.submission != null && !draft.submission!.complete
                            ? 'CONTINUE PAYMENT'
                            : 'ADD PAYMENT',
                    onPressed:
                        ready && draft.submission?.uncertain != true
                            ? () => unawaited(_pay())
                            : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
  PaymentRepository get repository => widget.repository;
  PaymentDraft _draft = PaymentDraft();
  final _scroll = ScrollController();
  bool _announcing = false;
  @override
  void clearPayment() {
    _draft = PaymentDraft();
  }

  @override
  Future<void> refresh(
    AccountProfile profile,
    bool Function() isCurrent,
  ) async {
    if (_draft.submission?.uncertain == true) {
      throw const PaymentWriteUncertain();
    }
    await _announce();
  }

  Future<void> _announce() async {
    final receipt = _draft.submission;
    if (!current ||
        !foreground ||
        receipt?.complete != true ||
        _announcing ||
        dialogs.isOpen) {
      return;
    }
    _announcing = true;
    try {
      await message(
        'Success!',
        'Payment Received Successfully.\nPayment Code: ${receipt!.masterCode}',
      );
      if (current && foreground) await close(force: true);
    } finally {
      _announcing = false;
    }
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
                          selected: !update,
                          enabled: !update,
                          child: Container(
                            key: Key(
                              update ? 'payment_tab_update' : 'payment_tab_add',
                            ),
                            constraints: const BoxConstraints(minHeight: 48),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  width: 2,
                                  color:
                                      update
                                          ? Colors.transparent
                                          : DocColors.greenSea,
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
                                    update
                                        ? Colors.black54
                                        : DocColors.greenSea,
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
                                    active ? () => unawaited(_patient()) : null,
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
                          ),
                        ),
              ),
              if (draft.patient != null)
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

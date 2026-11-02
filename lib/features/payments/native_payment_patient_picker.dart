import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../appointments/admin_modify/admin_appointment_models.dart'
    show adminPatientPhone;
import '../auth/auth_controller.dart';
import '../auth/profile_repository.dart';
import 'payment_models.dart';
import 'payment_repository.dart';
import 'payment_state.dart';
import 'native_payment_controls.dart';

class NativePaymentPatientPicker extends StatefulWidget {
  const NativePaymentPatientPicker({
    super.key,
    required this.auth,
    required this.repository,
  });
  final AuthController auth;
  final PaymentRepository repository;
  @override
  State<NativePaymentPatientPicker> createState() => _PatientPickerState();
}

class _PatientPickerState extends PaymentState<NativePaymentPatientPicker> {
  @override
  AuthController get auth => widget.auth;
  @override
  PaymentRepository get repository => widget.repository;
  final _query = TextEditingController(), _focus = FocusNode();
  List<PaymentChoice> _rows = const [], _latest = const [];
  String _search = '';
  String? _inputError;
  bool _answered = false;
  @override
  void clearPayment() {
    _rows = _latest = const [];
  }

  @override
  Future<void> refresh(
    AccountProfile profile,
    bool Function() isCurrent,
  ) async {
    final rows = await repository.patients(
      session!,
      profile,
      search: _search,
      isCurrent: isCurrent,
    );
    if (!isCurrent()) return;
    setState(() {
      _rows = rows;
      if (_search.isEmpty) _latest = rows;
    });
  }

  Future<void> _find() async {
    if (!ready) return;
    final query = _query.text.trim(),
        invalid = paymentSearchError(_query.text.trim());
    setState(() => _inputError = invalid);
    if (invalid != null) {
      toasts.show(context, invalid);
      return;
    }
    _focus.unfocus();
    _search = query;
    setState(() => _rows = const []);
    await run(refresh);
  }

  void _select(PaymentChoice row) {
    if (!ready || _answered || !_rows.contains(row)) return;
    _answered = true;
    _focus.unfocus();
    Navigator.pop(context, row);
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context), size = MediaQuery.sizeOf(context);
    Widget search() => Padding(
      padding: EdgeInsets.fromLTRB(4 * s, 8 * s, 4 * s, 8 * s),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.white,
              elevation: 1.5,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8 * s),
                side: const BorderSide(color: DocColors.primary),
              ),
              child: TextField(
                key: const Key('payment_patient_query'),
                controller: _query,
                focusNode: _focus,
                enabled: !busy,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _focus.unfocus(),
                onChanged: (_) => setState(() => _inputError = null),
                style: adminAppointmentText(
                  10,
                  s,
                  weight: FontWeight.w500,
                  color: const Color(0xff6c6e6f),
                ),
                decoration: InputDecoration(
                  labelText: 'Write Patient Name or Code',
                  isDense: true,
                  constraints: const BoxConstraints(minHeight: 56),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12 * s,
                    vertical: 10 * s,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  labelStyle: adminAppointmentText(
                    10,
                    s,
                    weight: FontWeight.w500,
                    color: const Color(0xffb2bec3),
                  ),
                  floatingLabelStyle: WidgetStateTextStyle.resolveWith(
                    (states) => adminAppointmentText(
                      11,
                      s,
                      color:
                          states.contains(WidgetState.focused)
                              ? DocColors.primary
                              : const Color(0xff7e8284),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 8 * s),
          SizedBox.square(
            dimension: 43 * s,
            child: Material(
              color: DocColors.primary,
              elevation: 1.5,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(10),
              child: IconButton(
                key: const Key('payment_patient_search'),
                tooltip: 'Search',
                onPressed: ready ? () => unawaited(_find()) : null,
                color: Colors.white,
                disabledColor: Colors.white70,
                icon: const Icon(Icons.search, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
    const headers = [
      'Prescription Code',
      'Patient Name',
      'Patient Code',
      'Phone',
      'Date',
    ];
    const weights = [25, 25, 15, 20, 15];
    Widget table(bool scrollRows) {
      final list = ListView.separated(
        key: const Key('payment_patient_list'),
        shrinkWrap: true,
        physics: scrollRows ? null : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(vertical: 2 * s),
        itemCount: _rows.length,
        separatorBuilder: (_, _) => SizedBox(height: 4 * s + 1),
        itemBuilder:
            (context, i) => Material(
              elevation: 2,
              child: NativeAdminAppointmentTableRow(
                key: Key('payment_patient_option_$i'),
                weights: weights,
                onTap: ready ? () => _select(_rows[i]) : null,
                cells: [
                  _rows[i].value('ph_sub_code'),
                  _rows[i].name,
                  _rows[i].value('pat_code'),
                  adminPatientPhone(_rows[i].value('pat_cell')),
                  _rows[i].value('pat_date'),
                ],
              ),
            ),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(5, 12, 5, 7),
        child: Material(
          color: Colors.white,
          elevation: 3,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(10 * s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NativeAdminAppointmentTableRow(
                cells: headers,
                weights: weights,
                header: true,
              ),
              if (_rows.isEmpty)
                Padding(
                  padding: EdgeInsets.all(8 * s),
                  child: Text(
                    'No Patient Found',
                    style: adminAppointmentText(
                      12,
                      s,
                      weight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                )
              else if (scrollRows)
                Flexible(fit: FlexFit.loose, child: list)
              else
                list,
            ],
          ),
        ),
      );
    }

    Widget contents(bool scrollRows) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current && foreground) search(),
        NativePaymentError(_inputError),
        if (_search.isEmpty && !busy && current && foreground)
          Padding(
            padding: EdgeInsets.fromLTRB(6 * s, 8 * s, 4 * s, 0),
            child: Text(
              'Latest 50 Patients',
              style: adminAppointmentText(
                12,
                s,
                weight: FontWeight.w700,
                color: DocColors.primary,
              ),
            ),
          ),
        if (_search.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4 * s),
              child: NativePaymentPill(
                key: const Key('payment_patient_clear'),
                label: 'CLEAR',
                onPressed:
                    ready
                        ? () {
                          _query.clear();
                          _focus.unfocus();
                          setState(() {
                            _search = '';
                            _rows = _latest;
                            _inputError = null;
                            error = null;
                          });
                        }
                        : null,
              ),
            ),
          ),
        if (busy || !current || !foreground)
          const Padding(
            padding: EdgeInsets.all(28),
            child: CircularProgressIndicator(),
          )
        else if (scrollRows)
          Flexible(fit: FlexFit.loose, child: table(true))
        else
          table(false),
      ],
    );
    return Dialog(
      key: const Key('payment_patient_picker'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(680, size.width - 48),
          maxHeight: size.height * .85,
        ),
        child: LayoutBuilder(
          builder:
              (context, box) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ColoredBox(
                    color: DocColors.primary,
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Text(
                          'Select Prescription Code:',
                          style: adminAppointmentText(
                            13,
                            s,
                            family: 'RussoOne',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    fit: FlexFit.loose,
                    child:
                        box.maxHeight < 430
                            ? SingleChildScrollView(child: contents(false))
                            : contents(true),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (error != null && !busy)
                          TextButton(
                            key: const Key('payment_patient_retry'),
                            onPressed: () => unawaited(run(refresh)),
                            child: const Text('Retry'),
                          ),
                        TextButton(
                          key: const Key('payment_patient_cancel'),
                          onPressed:
                              !busy && !_answered
                                  ? () {
                                    _answered = true;
                                    Navigator.pop(context);
                                  }
                                  : null,
                          child: Text(
                            'CANCEL',
                            style: adminAppointmentText(
                              12,
                              s,
                              family: 'Roboto',
                              color: DocColors.primary,
                            ).copyWith(letterSpacing: 1.25),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}

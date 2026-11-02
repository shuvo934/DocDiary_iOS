import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../appointments/admin_modify/admin_appointment_models.dart'
    show adminPatientPhone;
import '../auth/auth_controller.dart';
import '../auth/profile_repository.dart';
import 'payment_models.dart';
import 'payment_update_repository.dart';
import 'payment_update_models.dart';
import 'payment_state.dart';
import 'native_payment_controls.dart';

class NativePaymentCodePicker extends StatefulWidget {
  const NativePaymentCodePicker({
    super.key,
    required this.auth,
    required this.repository,
  });
  final AuthController auth;
  final PaymentUpdateRepository repository;
  @override
  State<NativePaymentCodePicker> createState() => _CodePickerState();
}

class _CodePickerState extends PaymentState<NativePaymentCodePicker> {
  @override
  AuthController get auth => widget.auth;
  @override
  PaymentUpdateRepository get repository => widget.repository;
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
    final rows = await repository.payments(
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
        invalid = paymentCodeSearchError(_query.text.trim());
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
    final textZoom = MediaQuery.textScalerOf(context).scale(10) / 10;
    Widget search() => Padding(
      padding: EdgeInsets.fromLTRB(4 * s, 8 * s, 4 * s, 8 * s),
      child: Row(
        children: [
          SizedBox(
            width: 43 * s,
            child: Semantics(
              key: const Key('payment_code_prefix'),
              label: 'PR.',
              enabled: false,
              child: Material(
                color: const Color(0xfff5f5f5),
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8 * s),
                  side: const BorderSide(color: DocColors.primary),
                ),
                child: SizedBox(
                  height: math.max(56, 43 * s),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'PR.',
                          style: adminAppointmentText(
                            10,
                            s,
                            color: const Color(0xffb2bec3),
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 5 * s),
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
                key: const Key('payment_code_query'),
                controller: _query,
                focusNode: _focus,
                enabled: !busy,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _focus.unfocus(),
                onChanged:
                    (value) => setState(
                      () =>
                          _inputError =
                              value.startsWith('.')
                                  ? "Code must not start with '.' character"
                                  : null,
                    ),
                style: adminAppointmentText(
                  10,
                  s,
                  weight: FontWeight.w500,
                  color: const Color(0xff6c6e6f),
                ),
                decoration: InputDecoration(
                  labelText: 'Write Payment Code',
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
                key: const Key('payment_code_search'),
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
      'Payment\nCode',
      'Pay\nment\nDate',
      'Prescription\nCode',
      'Patient\nName',
      'Phone',
    ];
    const weights = [25, 15, 23, 20, 17];
    Widget table(bool scrollRows) {
      final list = ListView.separated(
        key: const Key('payment_code_list'),
        shrinkWrap: true,
        physics: scrollRows ? null : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(vertical: 2 * s),
        itemCount: _rows.length,
        separatorBuilder: (_, _) => SizedBox(height: 4 * s + 1),
        itemBuilder:
            (context, i) => Material(
              elevation: 2,
              child: NativeAdminAppointmentTableRow(
                key: Key('payment_code_option_$i'),
                weights: weights,
                onTap: ready ? () => _select(_rows[i]) : null,
                cells: [
                  _rows[i].name,
                  _rows[i].value('prm_date'),
                  _rows[i].value('ph_sub_code'),
                  _rows[i].value('pat_name'),
                  adminPatientPhone(_rows[i].value('pat_cell')),
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
          child: LayoutBuilder(
            builder: (context, box) {
              final content = Column(
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
                        'No Payment List Found',
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
              );
              if (textZoom <= 1.3) return content;
              return SingleChildScrollView(
                key: const Key('payment_code_table_horizontal'),
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: box.maxWidth * textZoom, child: content),
              );
            },
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
              'Latest 50 Payments',
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
                key: const Key('payment_code_clear'),
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
      key: const Key('payment_code_picker'),
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
                          'Select Payment Code:',
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
                        box.maxHeight < 430 || textZoom > 1.3
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
                            key: const Key('payment_code_retry'),
                            onPressed: () => unawaited(run(refresh)),
                            child: const Text('Retry'),
                          ),
                        TextButton(
                          key: const Key('payment_code_cancel'),
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

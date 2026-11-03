import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_toast.dart';
import '../../appointments/admin_modify/native_admin_appointment_controls.dart';
import '../voucher_transaction/native_voucher_controls.dart';
import 'ledger_models.dart';

class NativeLedgerPatientPicker extends StatefulWidget {
  const NativeLedgerPatientPicker({
    super.key,
    required this.state,
    required this.onSearch,
    required this.onClear,
    required this.onRetry,
  });
  final ValueListenable<LedgerPatientPickerData> state;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear, onRetry;
  @override
  State<NativeLedgerPatientPicker> createState() => _PatientPickerState();
}

class _PatientPickerState extends State<NativeLedgerPatientPicker> {
  final _text = TextEditingController();
  final _toasts = AppToastOwner();
  String? _validation;
  bool _answered = false;
  void _search() {
    if (widget.state.value.busy || _answered) return;
    final error = validateLedgerPatientQuery(_text.text);
    setState(() => _validation = error);
    if (error != null) {
      _toasts.show(context, error);
      return;
    }
    FocusScope.of(context).unfocus();
    widget.onSearch(_text.text);
  }

  void _answer(LedgerPatient? value) {
    if (_answered || widget.state.value.busy) return;
    _answered = true;
    Navigator.pop(context, value);
  }

  @override
  void dispose() {
    _text.dispose();
    _toasts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context), media = MediaQuery.of(context);
    final maxHeight = math.max(
      100.0,
      media.size.height - media.padding.vertical - media.viewInsets.bottom - 48,
    );
    return Dialog(
      key: const Key('ledger_patient_picker'),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      child: SizedBox(
        width: math.min(560, media.size.width - 48),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ValueListenableBuilder<LedgerPatientPickerData>(
            valueListenable: widget.state,
            builder:
                (context, data, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ColoredBox(
                      color: DocColors.primary,
                      child: Padding(
                        padding: EdgeInsets.all(8 * s),
                        child: Text(
                          'Select Patient',
                          style: vtText(
                            13,
                            s,
                            family: 'RussoOne',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(5, 10, 5, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Material(
                                    color: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(
                                        color: DocColors.primary,
                                      ),
                                    ),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 56,
                                      ),
                                      child: TextField(
                                        key: const Key('ledger_patient_query'),
                                        controller: _text,
                                        enabled: !data.busy,
                                        textInputAction: TextInputAction.done,
                                        autocorrect: false,
                                        enableSuggestions: false,
                                        onSubmitted:
                                            (_) =>
                                                FocusScope.of(
                                                  context,
                                                ).unfocus(),
                                        onChanged:
                                            (v) => setState(
                                              () =>
                                                  _validation =
                                                      RegExp(
                                                            r'[.,-]',
                                                          ).hasMatch(v)
                                                          ? 'Invalid Character.'
                                                          : null,
                                            ),
                                        style: vtText(
                                          10,
                                          s,
                                          family: 'Poppins',
                                          weight: FontWeight.w500,
                                        ),
                                        decoration: InputDecoration(
                                          labelText:
                                              'Write Patient Name or Code',
                                          labelStyle: vtText(
                                            10,
                                            s,
                                            family: 'Poppins',
                                            color: const Color(0xffb2bec3),
                                            weight: FontWeight.w600,
                                          ),
                                          floatingLabelStyle: vtText(
                                            11,
                                            s,
                                            family: 'Poppins',
                                            color: const Color(0xffb2bec3),
                                            weight: FontWeight.w600,
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12 * s,
                                          ),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          disabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          filled: false,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 54,
                                  height: 56,
                                  child: Material(
                                    color: DocColors.primary,
                                    elevation: 2,
                                    borderRadius: BorderRadius.circular(10),
                                    child: IconButton(
                                      key: const Key('ledger_patient_search'),
                                      tooltip: 'Search patient',
                                      onPressed: data.busy ? null : _search,
                                      icon: const Icon(
                                        Icons.search,
                                        color: Colors.white,
                                        size: 25,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_validation != null)
                              Padding(
                                padding: const EdgeInsets.all(7),
                                child: Text(
                                  _validation!,
                                  key: const Key('ledger_patient_validation'),
                                  style: vtText(
                                    11,
                                    s,
                                    color: const Color(0xffff474c),
                                  ),
                                ),
                              ),
                            SizedBox(height: 8 * s),
                            if (data.searched)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  key: const Key('ledger_patient_clear'),
                                  onPressed:
                                      data.busy
                                          ? null
                                          : () {
                                            _text.clear();
                                            setState(() => _validation = null);
                                            widget.onClear();
                                          },
                                  style: TextButton.styleFrom(
                                    backgroundColor: DocColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    minimumSize: const Size(0, 32),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 4,
                                    ),
                                    shape: const StadiumBorder(),
                                  ),
                                  child: Text(
                                    'CLEAR',
                                    style: vtText(
                                      11,
                                      s,
                                      family: 'PatuaOne',
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            if (!data.searched)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: 7 * s,
                                  left: 4 * s,
                                ),
                                child: Text(
                                  'Latest 50 Patients',
                                  style: vtText(
                                    12,
                                    s,
                                    family: 'Poppins',
                                    color: DocColors.primary,
                                  ),
                                ),
                              ),
                            if (data.busy)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    key: Key('ledger_patient_loading'),
                                  ),
                                ),
                              )
                            else if (data.error != null)
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Text(
                                      data.error!,
                                      textAlign: TextAlign.center,
                                    ),
                                    TextButton(
                                      key: const Key('ledger_patient_retry'),
                                      onPressed: widget.onRetry,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 12,
                                  bottom: 7,
                                ),
                                child: _PatientTable(
                                  data: data,
                                  maxHeight: math.min(500 * s, maxHeight * .65),
                                  onSelect: _answer,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const Key('ledger_patient_cancel'),
                          onPressed: data.busy ? null : () => _answer(null),
                          child: Text(
                            'CANCEL',
                            style: vtText(
                              12,
                              s,
                              color: DocColors.primary,
                              weight: FontWeight.w500,
                            ).copyWith(letterSpacing: 1.25),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

class _PatientTable extends StatelessWidget {
  const _PatientTable({
    required this.data,
    required this.maxHeight,
    required this.onSelect,
  });
  final LedgerPatientPickerData data;
  final double maxHeight;
  final ValueChanged<LedgerPatient> onSelect;

  static const _headers = [
    'Prescription Code',
    'Patient Name',
    'Patient Code',
    'Date',
  ];
  // 1st code er [25,25,15,20,15] theke Phone bad diye ratio thik rakha
  static const _weights = [30, 30, 20, 20];

  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context);
    return Material(
      color: Colors.white,
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(10 * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header – 1st code er motoi
          const NativeAdminAppointmentTableRow(
            cells: _headers,
            weights: _weights,
            header: true,
          ),
          if (data.rows.isEmpty)
            // No Patient Found – 1st code er style
            Padding(
              padding: EdgeInsets.all(8 * s),
              child: Text(
                'No Patient Found',
                key: const Key('ledger_patient_empty'),
                style: adminAppointmentText(
                  12,
                  s,
                  weight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
            )
          else
            // List – 1st code er motoi separated + elevation 2 row
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: ListView.separated(
                key: const Key('ledger_patient_list'),
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(vertical: 2 * s),
                itemCount: data.rows.length,
                separatorBuilder: (_, _) => SizedBox(height: 4 * s + 1),
                itemBuilder: (context, i) {
                  final p = data.rows[i];
                  return Material(
                    elevation: 2,
                    child: NativeAdminAppointmentTableRow(
                      key: Key('ledger_patient_${p.id}'),
                      weights: _weights,
                      onTap: () => onSelect(p),
                      cells: [p.prescriptionCode, p.name, p.code, p.date],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

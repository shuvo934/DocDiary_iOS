import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../auth/auth_controller.dart';
import '../../auth/profile_repository.dart';
import 'admin_appointment_models.dart';
import 'admin_appointment_repository.dart';
import 'admin_appointment_state.dart';
import 'native_admin_appointment_controls.dart';

enum AdminAppointmentPicker { patient, doctor, payment }

class NativeAdminAppointmentPicker extends StatefulWidget {
  const NativeAdminAppointmentPicker({
    super.key,
    required this.auth,
    required this.repository,
    required this.kind,
    this.choices = const [],
    this.cancel = false,
  });
  final AuthController auth;
  final AdminAppointmentRepository repository;
  final AdminAppointmentPicker kind;
  final List<AdminAppointmentChoice> choices;
  final bool cancel;
  @override
  State<NativeAdminAppointmentPicker> createState() => _PickerState();
}

class _PickerState extends AdminAppointmentState<NativeAdminAppointmentPicker> {
  @override
  AuthController get auth => widget.auth;
  @override
  AdminAppointmentRepository get repository => widget.repository;
  final _query = TextEditingController(), _focus = FocusNode();
  List<AdminAppointmentChoice> _rows = const [], _latest = const [];
  String _search = '', _filter = '';
  String? _inputError;
  bool _answered = false;
  bool get _patient => widget.kind == AdminAppointmentPicker.patient;
  @override
  void clearAppointment() {
    _rows = _latest = const [];
  }

  @override
  Future<void> refresh(
    AccountProfile profile,
    bool Function() isCurrent,
  ) async {
    final rows =
        _patient
            ? await repository.patients(
              session!,
              profile,
              cancel: widget.cancel,
              search: _search,
              isCurrent: isCurrent,
            )
            : widget.choices;
    if (!isCurrent()) return;
    setState(() {
      _rows = rows;
      if (_search.isEmpty) _latest = rows;
    });
  }

  Future<void> _find() async {
    if (!ready) return;
    final query = _query.text.trim(),
        invalid = adminPatientSearchError(_query.text.trim());
    setState(() => _inputError = invalid);
    if (invalid != null) {
      toasts.show(context, invalid);
      return;
    }
    _focus.unfocus();
    _search = query;
    await run(refresh);
  }

  void _select(AdminAppointmentChoice row) {
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
    final doctor = widget.kind == AdminAppointmentPicker.doctor;
    final title =
        _patient
            ? 'Select Patient'
            : doctor
            ? 'Select Doctor:'
            : 'Select Payment Code:';
    final headers =
        _patient
            ? [
              'Prescription Code',
              'Patient Name',
              'Patient Code',
              'Phone',
              'Date',
            ]
            : doctor
            ? ['Doctor Name', 'Designation', 'Unit', 'Department']
            : ['Payment Code', 'Payment Date'];
    final weights =
        _patient
            ? [25, 25, 15, 20, 15]
            : doctor
            ? [4, 3, 3, 3]
            : [6, 4];
    final visible =
        _patient
            ? _rows
            : _rows
                .where((r) => r.name.toLowerCase().contains(_filter))
                .toList();
    List<String> cells(AdminAppointmentChoice row) =>
        _patient
            ? [
              row.value('ph_sub_code'),
              row.name,
              row.value('pat_code'),
              adminPatientPhone(
                row.value(widget.cancel ? 'pat_cell' : 'pat_phone'),
              ),
              row.value('ph_date'),
            ]
            : doctor
            ? [
              '${row.name} (${row.value('doc_code')})',
              row.value('desig_name'),
              row.value('depts_name'),
              row.value('deptd_name'),
            ]
            : [row.name, row.value('prm_date')];
    return Dialog(
      key: const Key('admin_appointment_picker'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(680, size.width),
          maxHeight: size.height * .85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColoredBox(
              color: DocColors.primary,
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    title,
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
            if (current && foreground)
              Padding(
                padding: EdgeInsets.fromLTRB(4 * s, 8 * s, 4 * s, 4 * s),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('admin_appointment_picker_query'),
                        controller: _query,
                        focusNode: _focus,
                        enabled: !busy,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        onSubmitted: (_) => _focus.unfocus(),
                        onChanged:
                            (text) => setState(() {
                              _filter = text.toLowerCase();
                              _inputError = null;
                            }),
                        style: adminAppointmentText(
                          10,
                          s,
                          weight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              _patient
                                  ? 'Write Patient Name or Code'
                                  : doctor
                                  ? 'Search Doctor by Name'
                                  : 'Search Payment Code',
                          errorText: _inputError,
                          errorMaxLines: 3,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8 * s),
                            borderSide: const BorderSide(
                              color: DocColors.primary,
                            ),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8 * s),
                            borderSide: const BorderSide(
                              color: Color(0xffb2bec3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8 * s),
                            borderSide: const BorderSide(
                              color: DocColors.primary,
                            ),
                          ),
                          labelStyle: adminAppointmentText(
                            10,
                            s,
                            color: const Color(0xff7e8284),
                          ),
                          floatingLabelStyle: adminAppointmentText(
                            11,
                            s,
                            color: const Color(0xff7e8284),
                          ),
                        ),
                      ),
                    ),
                    if (_patient) ...[
                      SizedBox(width: 4 * s),
                      IconButton(
                        key: const Key('admin_appointment_picker_search'),
                        tooltip: 'Search',
                        onPressed: ready ? () => unawaited(_find()) : null,
                        color: DocColors.primary,
                        icon: const Icon(Icons.search),
                      ),
                    ],
                  ],
                ),
              ),
            if (_patient && _search.isEmpty && !busy && current && foreground)
              Padding(
                padding: EdgeInsets.all(4 * s),
                child: Text(
                  widget.cancel
                      ? 'Latest 50 Patients Available for Cancel Schedule'
                      : 'Latest 50 Patients Available for Schedule',
                  style: adminAppointmentText(
                    12,
                    s,
                    weight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ),
            if (_patient && _search.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('admin_appointment_picker_clear'),
                  onPressed:
                      ready
                          ? () {
                            _query.clear();
                            _focus.unfocus();
                            setState(() {
                              _search = '';
                              _rows = _latest;
                              _inputError = null;
                            });
                          }
                          : null,
                  child: const Text('Clear'),
                ),
              ),
            if (busy || !current || !foreground)
              const Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(
                  key: Key('admin_appointment_loading'),
                ),
              )
            else ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4 * s),
                child: NativeAdminAppointmentTableRow(
                  cells: headers,
                  weights: weights,
                  header: true,
                ),
              ),
              Flexible(
                fit: FlexFit.loose,
                child:
                    visible.isEmpty
                        ? Padding(
                          padding: EdgeInsets.all(8 * s),
                          child: Text(
                            _patient
                                ? 'No Patient Found'
                                : doctor
                                ? 'No Doctor Found'
                                : 'No Payment Found',
                            style: adminAppointmentText(
                              12,
                              s,
                              weight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                        )
                        : ListView.separated(
                          key: const Key('admin_appointment_picker_list'),
                          shrinkWrap: true,
                          padding: EdgeInsets.fromLTRB(4 * s, 0, 4 * s, 4 * s),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 2),
                          itemBuilder:
                              (context, i) => NativeAdminAppointmentTableRow(
                                key: Key('admin_appointment_picker_option_$i'),
                                cells: cells(visible[i]),
                                weights: weights,
                                onTap: ready ? () => _select(visible[i]) : null,
                              ),
                        ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (error != null && !busy)
                    TextButton(
                      key: const Key('admin_appointment_picker_retry'),
                      onPressed: () => unawaited(run(refresh)),
                      child: const Text('Retry'),
                    ),
                  TextButton(
                    key: const Key('admin_appointment_picker_cancel'),
                    onPressed:
                        !busy && !_answered
                            ? () {
                              _answered = true;
                              Navigator.pop(context);
                            }
                            : null,
                    child: const Text('CANCEL'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

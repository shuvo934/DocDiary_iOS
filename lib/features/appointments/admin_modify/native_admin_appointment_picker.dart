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
    Widget searchControls() => Padding(
      padding: EdgeInsets.fromLTRB(4 * s, 8 * s, 4 * s, 8 * s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Material(
              key: const Key('admin_appointment_picker_query_surface'),
              color: Colors.white,
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8 * s),
                side: const BorderSide(color: DocColors.primary),
              ),
              clipBehavior: Clip.antiAlias,
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
                  weight: FontWeight.w500,
                  color: const Color(0xff6c6e6f),
                ),
                decoration: InputDecoration(
                  constraints: const BoxConstraints(minHeight: 56),
                  isDense: true,
                  labelText:
                      _patient
                          ? 'Write Patient Name or Code'
                          : doctor
                          ? 'Search Doctor by Name'
                          : 'Search Payment Code',
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
                  // Retain the user's larger floating-label text.
                  floatingLabelStyle: WidgetStateTextStyle.resolveWith((
                    states,
                  ) {
                    if (states.contains(WidgetState.focused)) {
                      return adminAppointmentText(
                        11,
                        s,
                        color: DocColors.primary,
                      );
                    }
                    return adminAppointmentText(
                      11,
                      s,
                      color: const Color(0xff7e8284),
                    );
                  }),
                ),
              ),
            ),
          ),
          if (_patient) ...[
            SizedBox(width: 8 * s),
            SizedBox.square(
              dimension: 43 * s,
              child: Material(
                key: const Key('admin_appointment_picker_search_surface'),
                color: DocColors.primary,
                elevation: 1.5,
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  key: const Key('admin_appointment_picker_search'),
                  tooltip: 'Search',
                  onPressed: ready ? () => unawaited(_find()) : null,
                  color: Colors.white,
                  disabledColor: Colors.white70,
                  icon: const Icon(Icons.search, size: 24),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    Widget table({required bool scrollRows}) {
      final rows = ListView.separated(
        key: const Key('admin_appointment_picker_list'),
        shrinkWrap: true,
        physics: scrollRows ? null : const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: 2 * s, bottom: 2 * s),
        itemCount: visible.length,
        separatorBuilder: (_, _) => SizedBox(height: 4 * s + 1),
        itemBuilder:
            (context, i) => Material(
              elevation: 2,
              child: NativeAdminAppointmentTableRow(
                key: Key('admin_appointment_picker_option_$i'),
                cells: cells(visible[i]),
                weights: weights,
                onTap: ready ? () => _select(visible[i]) : null,
              ),
            ),
      );
      return Padding(
        padding: EdgeInsets.fromLTRB(5, 12, 5, 7),
        child: Material(
          key: const Key('admin_appointment_picker_table'),
          color: Colors.white,
          elevation: 3,
          borderRadius: BorderRadius.circular(10 * s),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NativeAdminAppointmentTableRow(
                cells: headers,
                weights: weights,
                header: true,
              ),
              if (visible.isEmpty)
                Padding(
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
              else if (scrollRows)
                Flexible(fit: FlexFit.loose, child: rows)
              else
                rows,
            ],
          ),
        ),
      );
    }

    Widget contents({required bool scrollRows}) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (current && foreground) searchControls(),
        if (_inputError != null)
          Padding(
            padding: EdgeInsets.fromLTRB(8 * s, 2, 3 * s, 4 * s),
            child: Text(
              _inputError!,
              style: adminAppointmentText(
                10,
                s,
                color: Colors.red,
                family: 'Roboto',
                weight: FontWeight.w600,
              ),
            ),
          ),
        if (_patient && _search.isEmpty && !busy && current && foreground)
          Padding(
            padding: EdgeInsets.fromLTRB(6 * s, 8 * s, 4 * s, 0),
            child: Text(
              widget.cancel
                  ? 'Latest 50 Patients Available for Cancel Schedule'
                  : 'Latest 50 Patients Available for Schedule',
              style: adminAppointmentText(
                12,
                s,
                weight: FontWeight.w700,
                color: DocColors.primary,
              ),
            ),
          ),
        if (_patient && _search.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4 * s),
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
                style: TextButton.styleFrom(
                  backgroundColor: DocColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'CLEAR',
                  style: adminAppointmentText(
                    10,
                    s,
                    family: 'PatuaOne',
                    color: Colors.white,
                    weight: FontWeight.bold,
                  ).copyWith(letterSpacing: 0.8),
                ),
              ),
            ),
          ),
        if (busy || !current || !foreground)
          const Padding(
            padding: EdgeInsets.all(28),
            child: CircularProgressIndicator(
              key: Key('admin_appointment_loading'),
            ),
          )
        else if (scrollRows)
          Flexible(fit: FlexFit.loose, child: table(scrollRows: true))
        else
          table(scrollRows: false),
      ],
    );

    return Dialog(
      key: const Key('admin_appointment_picker'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(680, size.width - 48),
          maxHeight: size.height * .85,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // With a keyboard or a short landscape viewport, let the search and
            // table scroll together. The title and Cancel action remain reachable.
            final compact = constraints.maxHeight < 430;
            return Column(
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
                Flexible(
                  fit: FlexFit.loose,
                  child:
                      compact
                          ? SingleChildScrollView(
                            key: const Key(
                              'admin_appointment_picker_compact_scroll',
                            ),
                            child: contents(scrollRows: false),
                          )
                          : contents(scrollRows: true),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (error != null && !busy)
                        TextButton(
                          key: const Key('admin_appointment_picker_retry'),
                          onPressed: () => unawaited(run(refresh)),
                          style: TextButton.styleFrom(
                            foregroundColor: DocColors.primary,
                          ),
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
                        style: TextButton.styleFrom(
                          foregroundColor: DocColors.primary,
                        ),
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
            );
          },
        ),
      ),
    );
  }
}

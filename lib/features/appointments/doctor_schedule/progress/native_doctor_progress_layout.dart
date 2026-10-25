import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/app_theme.dart';
import '../native_appointment_timeline_card.dart';
import '../history/doctor_appointment_history_models.dart';
import 'doctor_progress_models.dart';

class NativeDoctorProgressLayout extends StatelessWidget {
  const NativeDoctorProgressLayout({
    super.key,
    required this.seed,
    required this.rows,
    required this.choices,
    required this.selected,
    required this.notes,
    required this.doctorName,
    required this.onBack,
    required this.onHistory,
    required this.onAdd,
    required this.onToggleFilters,
    required this.onFilter,
    required this.onScore,
    required this.onSubmit,
    required this.onNotesChanged,
    this.score,
    this.adding = false,
    this.canAdd = false,
    this.showFilters = false,
    this.waiting = false,
    this.enabled = true,
    this.failed = false,
    this.scoreMissing = false,
    this.notesMissing = false,
    this.message,
  });
  final DoctorProgressSeed seed;
  final List<DoctorProgressRow> rows;
  final Map<AppointmentHistoryFilter, List<AppointmentHistoryChoice>> choices;
  final Map<AppointmentHistoryFilter, AppointmentHistoryChoice> selected;
  final TextEditingController notes;
  final String doctorName;
  final VoidCallback onBack, onHistory, onAdd, onToggleFilters, onSubmit;
  final void Function(AppointmentHistoryFilter, Rect) onFilter;
  final ValueChanged<Rect> onScore;
  final ValueChanged<String> onNotesChanged;
  final int? score;
  final bool adding,
      canAdd,
      showFilters,
      waiting,
      enabled,
      failed,
      scoreMissing,
      notesMissing;
  final String? message;

  Widget _pill({
    required Key key,
    required Widget child,
    required VoidCallback onTap,
    double radius = 12,
  }) => Material(
    color: DocColors.primary,
    elevation: 1,
    borderRadius: BorderRadius.circular(radius),
    clipBehavior: Clip.antiAlias,
    child: InkWell(key: key, onTap: enabled ? onTap : null, child: child),
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context), sdp = appointmentScale(context);
    final patient = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          seed.patientName,
          key: const Key('doctor_progress_patient'),
          textAlign: TextAlign.center,
          style: appointmentText(
            13 * sdp,
            weight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        Text(
          seed.patientCode,
          textAlign: TextAlign.center,
          style: appointmentText(10 * sdp),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4 * sdp, vertical: 4 * sdp),
          child: LayoutBuilder(
            builder:
                (context, bounds) => Row(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: math.max(
                          100,
                          bounds.maxWidth - (canAdd ? 54 : 0) - 20,
                        ),
                      ),
                      child: _pill(
                        key: const Key('doctor_progress_history_tab'),
                        radius: 9 * sdp,
                        onTap: onHistory,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 7 * sdp,
                            vertical: 4 * sdp,
                          ),
                          child: Text(
                            'Patient Progress History',
                            style: appointmentText(
                              11 * sdp,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Expanded(child: Divider(thickness: 2)),
                    const SizedBox(width: 5),
                    if (canAdd)
                      _pill(
                        key: const Key('doctor_progress_add_tab'),
                        radius: 15 * sdp,
                        onTap: onAdd,
                        child: Padding(
                          padding: EdgeInsets.all(3 * sdp),
                          child: const Icon(
                            Icons.add,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
          ),
        ),
      ],
    );
    final summary = Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child:
              showFilters
                  ? Column(
                    key: const Key('doctor_progress_filters'),
                    children: [
                      for (final kind in AppointmentHistoryFilter.values)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            4 * sdp,
                            4 * sdp,
                            4 * sdp,
                            1 * sdp,
                          ),
                          child: NativeProgressChoiceField(
                            label: kind.label,
                            value: selected[kind]?.name ?? '',
                            fieldKey: Key(
                              'doctor_progress_filter_${kind.name}',
                            ),
                            enabled:
                                enabled && (choices[kind]?.isNotEmpty ?? false),
                            sdp: sdp,
                            onTap: (anchor) => onFilter(kind, anchor),
                          ),
                        ),
                    ],
                  )
                  : const SizedBox.shrink(),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(4 * sdp, 10 * sdp, 4 * sdp, 4 * sdp),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8 * sdp,
                  children: [
                    Text(
                      'Health Progress:',
                      style: appointmentText(
                        11 * sdp,
                        weight: FontWeight.w700,
                        color: DocColors.greenSea,
                      ),
                    ),
                    Text(
                      rows.isEmpty ? '0' : rows.first.value('pph_progress'),
                      key: const Key('doctor_progress_current'),
                      style: appointmentText(
                        14 * sdp,
                        family: 'RussoOne',
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              _pill(
                key: const Key('doctor_progress_filter_toggle'),
                radius: 15 * sdp,
                onTap: onToggleFilters,
                child: Padding(
                  padding: EdgeInsets.all(3 * sdp),
                  child: const Icon(
                    Icons.search,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(4 * sdp, 0, 4 * sdp, 10 * sdp),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              key: const Key('doctor_progress_bar'),
              value:
                  rows.isEmpty
                      ? 0
                      : (rows.first.score / 10).clamp(0, 1).toDouble(),
              minHeight: 10 * sdp,
              color: DocColors.greenSea,
              backgroundColor: DocColors.clouds,
            ),
          ),
        ),
      ],
    );
    final form = _form(context, sdp);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: DocColors.primary,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(
                    52.0,
                    (media.size.height - media.padding.vertical) * .09,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12 * sdp,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        key: const Key('doctor_progress_back'),
                        tooltip: 'Back',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 44,
                        ),
                        onPressed: waiting ? null : onBack,
                        icon: Icon(
                          Icons.arrow_back_ios,
                          size: 19 * sdp,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Health Progress',
                          style: appointmentText(
                            13 * sdp,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Material(
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  child: SafeArea(
                    top: false,
                    child:
                        waiting
                            ? const Center(
                              child: CircularProgressIndicator(
                                key: Key('doctor_progress_loading'),
                              ),
                            )
                            : LayoutBuilder(
                              builder: (context, bounds) {
                                if (message != null) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        message!,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                }
                                final roomy =
                                    bounds.maxHeight > 450 &&
                                    media.textScaler.scale(12) <= 18 &&
                                    bounds.maxHeight >
                                        (showFilters ? 420 : 230) *
                                            sdp *
                                            (media.textScaler.scale(12) / 12) &&
                                    media.viewInsets.bottom == 0;
                                final table = _ProgressTable(
                                  rows: rows,
                                  sdp: sdp,
                                  failed: failed,
                                );
                                if (roomy && !adding) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      8.8,
                                      10.8,
                                      8.8,
                                      0,
                                    ),
                                    child: Column(
                                      children: [
                                        patient,
                                        summary,
                                        Expanded(child: table),
                                      ],
                                    ),
                                  );
                                }
                                return SingleChildScrollView(
                                  key: const Key('doctor_progress_scroll'),
                                  padding: const EdgeInsets.fromLTRB(
                                    8.8,
                                    10.8,
                                    8.8,
                                    8.8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      patient,
                                      if (adding)
                                        form
                                      else ...[
                                        summary,
                                        SizedBox(
                                          height: math.max(
                                            180,
                                            bounds.maxHeight * .65,
                                          ),
                                          child: table,
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context, double sdp) {
    Widget readOnly(String label, String value) => InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        enabled: false,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        labelStyle: appointmentText(
          12,
          family: 'OpenSans',
          color: Colors.black54,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: InputBorder.none,
        disabledBorder: InputBorder.none,
      ),
      child: Text(
        value,
        style: appointmentText(
          12,
          family: 'OpenSans',
          weight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
    );
    Widget pair(
      String label,
      String value,
      String otherLabel,
      String otherValue,
    ) => Padding(
      padding: const EdgeInsets.fromLTRB(5, 5, 5, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: readOnly(label, value)),
            const SizedBox(width: 5),
            Expanded(child: readOnly(otherLabel, otherValue)),
          ],
        ),
      ),
    );
    final row = seed.appointment;
    return Column(
      key: const Key('doctor_progress_form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pair(
          'Date:',
          row?.value('adm_date') ?? '',
          'Service Name:',
          row?.value('pfn_fee_name') ?? '',
        ),
        pair(
          'Doctor Name:',
          doctorName,
          'Unit Name:',
          row?.value('depts_name') ?? '',
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(4 * sdp, 8 * sdp, 4 * sdp, 4 * sdp),
          child: NativeProgressChoiceField(
            label: 'Progress',
            value: score?.toString() ?? '',
            fieldKey: const Key('doctor_progress_score'),
            enabled: enabled,
            sdp: sdp,
            onTap: onScore,
            large: true,
          ),
        ),
        if (scoreMissing)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6 * sdp),
            child: const Text(
              'Please Provide Progress',
              key: Key('doctor_progress_score_missing'),
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(4 * sdp, 8 * sdp, 4 * sdp, 4 * sdp),
          child: Material(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: DocColors.primary),
            ),
            clipBehavior: Clip.antiAlias,
            child: TextField(
              key: const Key('doctor_progress_notes'),
              controller: notes,
              enabled: enabled,
              minLines: 1,
              maxLines: 100,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.multiline,
              style: appointmentText(16, family: 'Roboto', color: Colors.black),
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              onChanged: onNotesChanged,
              autocorrect: false,
              enableSuggestions: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              textCapitalization: TextCapitalization.none,
              decoration: InputDecoration(
                labelText: 'Progress Note',
                labelStyle: appointmentText(
                  14,
                  family: 'Roboto',
                  color: Colors.black54,
                ),
                floatingLabelStyle: appointmentText(
                  12,
                  family: 'Roboto',
                  color: Colors.black54,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        if (notesMissing)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6 * sdp),
            child: const Text(
              'Please Provide Progress Note',
              key: Key('doctor_progress_notes_missing'),
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [DocColors.primary, DocColors.greenSea],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('doctor_progress_submit'),
                borderRadius: BorderRadius.circular(10),
                onTap: enabled ? onSubmit : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      'ADD PROGRESS',
                      textAlign: TextAlign.center,
                      style: appointmentText(
                        14 * sdp,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class NativeProgressChoiceField extends StatelessWidget {
  const NativeProgressChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.fieldKey,
    required this.enabled,
    required this.sdp,
    required this.onTap,
    this.large = false,
  });
  final String label, value;
  final Key fieldKey;
  final bool enabled, large;
  final double sdp;
  final ValueChanged<Rect> onTap;
  @override
  Widget build(BuildContext context) => Builder(
    builder:
        (context) => Material(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(large ? 10 : 8 * sdp),
            side: const BorderSide(color: DocColors.primary),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: fieldKey,
            onTap:
                enabled
                    ? () {
                      final box = context.findRenderObject()! as RenderBox;
                      onTap(box.localToGlobal(Offset.zero) & box.size);
                    }
                    : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: InputDecorator(
                isEmpty: value.isEmpty,
                decoration: InputDecoration(
                  labelText: label,
                  enabled: enabled,
                  filled: true,
                  fillColor: enabled ? Colors.white : const Color(0xfff5f5f5),
                  labelStyle: appointmentText(
                    large ? 14 : 9 * sdp,
                    family: large ? 'Roboto' : 'Poppins',
                    color: Colors.black54,
                  ),
                  floatingLabelStyle: appointmentText(
                    large ? 12 : 10 * sdp,
                    family: large ? 'Roboto' : 'Poppins',
                    color: Colors.black54,
                  ),
                  suffixIcon: const Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xff6c6e6f),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
                child: Text(
                  value.isEmpty ? ' ' : value,
                  style: appointmentText(
                    large ? 16 : 9 * sdp,
                    family: large ? 'Roboto' : 'Poppins',
                    weight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
  );
}

class _ProgressTable extends StatelessWidget {
  const _ProgressTable({
    required this.rows,
    required this.sdp,
    required this.failed,
  });
  final List<DoctorProgressRow> rows;
  final double sdp;
  final bool failed;
  static const widths = [25.0, 60.0, 110.0, 110.0, 110.0, 50.0, 230.0];
  Widget _row(List<String> values, {required bool header, Key? rowKey}) =>
      IntrinsicHeight(
        child: Row(
          key: rowKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < values.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  left: i == 0 ? 0 : 2,
                  right: i == 6 ? 0 : 2,
                ),
                child: SizedBox(
                  width: widths[i] * sdp,
                  child: ColoredBox(
                    color: header ? DocColors.primary : DocColors.clouds,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Center(
                        child: Text(
                          values[i],
                          textAlign: TextAlign.center,
                          style: appointmentText(
                            (header
                                    ? 11
                                    : i == 5
                                    ? 11
                                    : 9) *
                                sdp,
                            family: header ? 'PatuaOne' : 'OpenSans',
                            weight: header ? FontWeight.w600 : FontWeight.w700,
                            color:
                                header
                                    ? Colors.white
                                    : i == 5
                                    ? Colors.black
                                    : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(5, 12, 5, 7),
    child: Column(
      children: [
        Flexible(
          child: SingleChildScrollView(
            key: const Key('doctor_progress_horizontal'),
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: widths.fold<double>(0, (a, b) => a + b) * sdp + 24,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(10 * sdp),
                    ),
                    child: _row(
                      [
                        'SL',
                        'Date',
                        'Service Name',
                        'Unit',
                        'Doctor/Therapist',
                        'Progress',
                        'Progress Notes',
                      ],
                      header: true,
                      rowKey: const Key('doctor_progress_table_header'),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      key: const Key('doctor_progress_table_rows'),
                      itemCount: failed ? 0 : rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final radius =
                            index == rows.length - 1
                                ? BorderRadius.vertical(
                                  bottom: Radius.circular(10 * sdp),
                                )
                                : BorderRadius.zero;
                        return ClipRRect(
                          borderRadius: radius,
                          child: _row(
                            [
                              (rows.length - index).toString(),
                              row.value('pph_date'),
                              row.value('pfn_name'),
                              row.value('detps_name'),
                              row.value('doc_name'),
                              row.value('pph_progress'),
                              row.value('pph_notes'),
                            ],
                            header: false,
                            rowKey: Key('doctor_progress_row_$index'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!failed && rows.isEmpty)
          Flexible(
            child: Padding(
              padding: EdgeInsets.all(8 * sdp),
              child: Text(
                'No Information Found',
                key: const Key('doctor_progress_empty'),
                style: appointmentText(14, weight: FontWeight.w500),
              ),
            ),
          ),
      ],
    ),
  );
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/native_json.dart';
import '../appointments/doctor_schedule/native_appointment_timeline_card.dart';
import 'normal_prescription_models.dart';
import 'normal_prescription_native_style.dart';
export 'native_normal_prescription_editor.dart';

class NormalPrescriptionShell extends StatelessWidget {
  const NormalPrescriptionShell({
    super.key,
    required this.title,
    required this.child,
    required this.onBack,
    this.waiting = false,
    this.isEditor = false,
    this.matchNative = false,
  });
  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final bool waiting, isEditor, matchNative;
  @override
  Widget build(BuildContext context) {
    final s = appointmentScale(context), media = MediaQuery.of(context);
    final background = isEditor ? DocColors.clouds : DocColors.primary;
    final content =
        waiting
            ? const Center(
              child: CircularProgressIndicator(
                key: Key('normal_prescription_loading'),
                color: DocColors.primary,
              ),
            )
            : child;
    final header =
        matchNative
            ? Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 12 * s,
                vertical: isEditor ? 12 * s : 6,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: (isEditor ? 21 : 19) * s,
                    height: isEditor ? 21 * s : 44,
                    child: IconButton(
                      key: const Key('normal_prescription_back'),
                      tooltip: isEditor ? 'Close' : 'Back',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onBack,
                      icon: Icon(
                        isEditor ? Icons.close : Icons.arrow_back_ios,
                        size: (isEditor ? 21 : 19) * s,
                        color: isEditor ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: rxNativeText(
                        14 * s,
                        family: 'Poppins',
                        weight: FontWeight.w700,
                        color: isEditor ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            )
            : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('normal_prescription_back'),
                    tooltip: 'Back',
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: appointmentText(
                        16,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isEditor ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.white,
          ),
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              ColoredBox(
                color: background,
                child:
                    isEditor
                        ? header
                        : ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(
                              52,
                              (media.size.height - media.padding.vertical) *
                                  .09,
                            ),
                          ),
                          child: header,
                        ),
              ),
              if (isEditor)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: DocColors.greenSea,
                )
              else
                const SizedBox(height: 5),
              Expanded(
                child: Material(
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  borderRadius:
                      isEditor
                          ? BorderRadius.zero
                          : const BorderRadius.vertical(
                            top: Radius.circular(30),
                          ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox.expand(child: content),
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

class NativeNormalPrescriptionLayout extends StatelessWidget {
  const NativeNormalPrescriptionLayout({
    super.key,
    required this.seed,
    required this.snapshot,
    required this.rows,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onSelect,
    required this.onAdmission,
    required this.onHistoryTab,
    required this.onTreatmentTab,
    required this.onReload,
    this.enabled = true,
    this.historyTab = 0,
    this.treatmentTab = 0,
    this.diagnosis,
    this.referral,
    this.message,
  });
  final NormalPrescriptionSeed seed;
  final NormalPrescriptionSnapshot? snapshot;
  final Map<NormalPrescriptionSection, List<JsonMap>> rows;
  final VoidCallback onCreate, onReload;
  final void Function(NormalPrescriptionSection, JsonMap?) onEdit;
  final void Function(NormalPrescriptionSection, JsonMap) onDelete, onSelect;
  final ValueChanged<bool> onAdmission;
  final ValueChanged<int> onHistoryTab, onTreatmentTab;
  final bool enabled;
  final int historyTab, treatmentTab;
  final JsonMap? diagnosis, referral;
  final String? message;

  Widget _readonly(String label, String value) => Container(
    key: ValueKey('rx_readonly_$label'),
    constraints: const BoxConstraints(minHeight: 48),
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xfff5f5f5),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: rxNativeText(
            12,
            color: const Color(0xff999999),
            weight: FontWeight.w500,
          ),
        ),
        if (value.isNotEmpty)
          Text(
            value,
            style: rxNativeText(
              12,
              family: 'OpenSans',
              weight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
      ],
    ),
  );
  Widget _pair(String a, String b, String c, String d) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _readonly(a, b)),
          const SizedBox(width: 5),
          Expanded(child: _readonly(c, d)),
        ],
      ),
    ),
  );
  Widget _heading(String title, double s) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 7),
    child: Column(
      children: [
        Text(
          '---------------------------------------------------------',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          textAlign: TextAlign.center,
          style: rxNativeText(14, family: 'OpenSans', weight: FontWeight.w700),
        ),
        Text(
          title,
          textAlign: TextAlign.center,
          style: rxNativeText(
            13 * s,
            family: 'OpenSans',
            weight: FontWeight.w700,
            color: DocColors.greenSea,
          ),
        ),
        Text(
          '---------------------------------------------------------',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          textAlign: TextAlign.center,
          style: rxNativeText(14, family: 'OpenSans', weight: FontWeight.w700),
        ),
      ],
    ),
  );
  Widget _tabs(
    List<NormalPrescriptionSection> kinds,
    int selected,
    ValueChanged<int> changed,
    double s,
  ) => Padding(
    padding: const EdgeInsets.only(top: 17, bottom: 5),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < kinds.length; i++)
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  gradient:
                      i == selected
                          ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [DocColors.primary, DocColors.greenSea],
                          )
                          : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: Key('rx_tab_${kinds[i].name}'),
                    borderRadius: BorderRadius.circular(40),
                    onTap: enabled ? () => changed(i) : null,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 46),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 8,
                        ),
                        child: Center(
                          child: Text(
                            rxSectionSpecs[kinds[i]]!.label.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: rxNativeText(
                              9 * s,
                              family: 'PatuaOne',
                              weight: FontWeight.w700,
                              color:
                                  i == selected
                                      ? Colors.white
                                      : const Color(0xff666666),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _row(
    RxSectionSpec spec,
    List<Widget> cells, {
    required bool header,
    bool selected = false,
    Key? key,
    VoidCallback? onTap,
  }) {
    final weights = [...rxNativeWeights(spec.section), if (!seed.readOnly) 1.0];
    final children = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 3));
      children.add(
        Expanded(
          flex: (weights[i] * 100).round(),
          child: ColoredBox(
            color:
                header
                    ? DocColors.primary
                    : selected && i < spec.fields.length
                    ? DocColors.muted
                    : DocColors.clouds,
            child: Padding(
              padding: EdgeInsets.all(i == spec.fields.length ? 2 : 4),
              child: Center(child: cells[i]),
            ),
          ),
        ),
      );
    }
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _table(NormalPrescriptionSection kind, double s) {
    final spec = rxSectionSpecs[kind]!,
        values = rows[kind] ?? const <JsonMap>[];
    final select =
        kind == NormalPrescriptionSection.diagnosis ||
        kind == NormalPrescriptionSection.referral;
    final current =
        kind == NormalPrescriptionSection.diagnosis
            ? diagnosis
            : kind == NormalPrescriptionSection.referral
            ? referral
            : null;
    return Column(
      key: Key('rx_section_${kind.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(spec, [
          for (final field in spec.fields)
            Text(
              rxNativeFieldLabel(spec, field),
              textAlign: TextAlign.center,
              style: rxNativeText(
                11 * s,
                family: 'PatuaOne',
                color: Colors.white,
                height: 1.2,
              ),
            ),
          if (!seed.readOnly) const SizedBox.shrink(),
        ], header: true),
        for (final row in values) ...[
          _row(
            spec,
            [
              for (final field in spec.fields)
                Text(
                  field.display(row),
                  textAlign: TextAlign.center,
                  style: rxNativeText(
                    9 * s,
                    family: 'OpenSans',
                    weight: FontWeight.w700,
                    color:
                        select &&
                                current != null &&
                                rxValue(current, spec.rowId) ==
                                    rxValue(row, spec.rowId)
                            ? Colors.white
                            : const Color(0xff6c6e6f),
                  ),
                ),
              if (!seed.readOnly)
                rxMayModify(spec, row)
                    ? Semantics(
                      button: true,
                      label:
                          select
                              ? 'Edit ${spec.label}'
                              : 'Delete ${spec.label}',
                      child: InkWell(
                        key: Key(
                          'rx_${select ? "edit" : "delete"}_${kind.name}_${rxValue(row, spec.rowId)}',
                        ),
                        onTap:
                            enabled
                                ? () =>
                                    select
                                        ? onEdit(kind, row)
                                        : onDelete(kind, row)
                                : null,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 28),
                          child: Icon(
                            select ? Icons.edit : Icons.cancel,
                            color: DocColors.primary,
                            size: 24,
                          ),
                        ),
                      ),
                    )
                    : const SizedBox.shrink(),
            ],
            header: false,
            selected:
                select &&
                current != null &&
                rxValue(current, spec.rowId) == rxValue(row, spec.rowId),
            key: Key('rx_row_${kind.name}_${rxValue(row, spec.rowId)}'),
            onTap:
                enabled && (select || !seed.readOnly)
                    ? () => select ? onSelect(kind, row) : onEdit(kind, row)
                    : null,
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xffdddddd)),
        ],
        if (values.isEmpty)
          Padding(
            padding: const EdgeInsets.all(5),
            child: Text(
              'No Information Found',
              textAlign: TextAlign.center,
              style: rxNativeText(14, family: 'Poppins'),
            ),
          ),
        if (!seed.readOnly)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 6, right: 5, bottom: 7),
              child: NativeRxActionButton(
                key: Key('rx_add_${kind.name}'),
                label: 'ADD',
                scale: s,
                onPressed: enabled ? () => onEdit(kind, null) : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _card(Widget child) => Card(
    margin: const EdgeInsets.only(top: 12, bottom: 7),
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
  @override
  Widget build(BuildContext context) {
    if (snapshot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message ?? 'Prescription data is unavailable.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                key: const Key('rx_reload'),
                onPressed: onReload,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final p = snapshot!.patient, s = appointmentScale(context);
    const history = [
      NormalPrescriptionSection.medicalHistory,
      NormalPrescriptionSection.drugHistory,
      NormalPrescriptionSection.clinicalFindings,
    ];
    const treatment = [
      NormalPrescriptionSection.management,
      NormalPrescriptionSection.medication,
      NormalPrescriptionSection.advice,
      NormalPrescriptionSection.reference,
    ];
    // Keep the summary offset when loading or an editor temporarily removes it.
    // The route's PageStorage restores only this summary, independently of forms.
    return Padding(
      key: const PageStorageKey<String>('normal_prescription_summary_scroll'),
      padding: const EdgeInsets.only(top: 6.0),
      child: SingleChildScrollView(
        key: const Key('rx_scroll'),
        padding: const EdgeInsets.fromLTRB(13, 8, 13, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              rxValue(p, 'pat_name'),
              key: const Key('rx_patient_name'),
              textAlign: TextAlign.center,
              style: rxNativeText(
                13 * s,
                family: 'Poppins',
                weight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            Text(
              rxValue(p, 'ph_sub_code'),
              textAlign: TextAlign.center,
              style: rxNativeText(10 * s, family: 'Poppins'),
            ),
            if (seed.readOnly)
              Semantics(
                key: Key('rx_view_only'),
                label: 'View only',
                child: SizedBox.shrink(),
              ),
            const SizedBox(height: 10),
            _readonly('MDT Code:', rxValue(p, 'pmm_code')),
            _pair(
              'Age:',
              rxValue(p, 'pat_age'),
              'Marital Status:',
              rxValue(p, 'marital_status'),
            ),
            _pair(
              'Gender:',
              rxValue(p, 'gender'),
              'Blood Group:',
              rxValue(p, 'pat_blood'),
            ),
            _pair(
              'Patient Category:',
              rxValue(p, 'pat_category_name'),
              'Patient Status:',
              rxValue(p, 'ph_patient_status'),
            ),
            const SizedBox(height: 5),
            _readonly('Address:', rxValue(p, 'address')),
            if (!snapshot!.exists)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child:
                    seed.readOnly
                        ? const Text(
                          'No Prescription Found',
                          key: Key('rx_no_prescription'),
                          textAlign: TextAlign.center,
                        )
                        : Align(
                          alignment: Alignment.center,
                          child: NativeRxActionButton(
                            key: const Key('rx_create'),
                            label: 'CREATE PRESCRIPTION',
                            scale: s,
                            textStyle: rxNativeText(
                              14,
                              weight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                            onPressed: enabled ? onCreate : null,
                          ),
                        ),
              )
            else ...[
              _heading('INJURY DETAILS', s),
              _card(_table(NormalPrescriptionSection.complain, s)),
              _heading('PAST MEDICAL INFORMATION', s),
              _tabs(history, historyTab, onHistoryTab, s),
              _card(_table(history[historyTab], s)),
              _heading('DIAGNOSIS DETAILS', s),
              _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _table(NormalPrescriptionSection.diagnosis, s),
                    if (diagnosis != null) ...[
                      const SizedBox(height: 7),
                      if (seed.readOnly) ...[
                        Text(
                          '-----------------------------------------------',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          textAlign: TextAlign.center,
                          style: rxNativeText(
                            14,
                            family: 'OpenSans',
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 9),
                      ],
                      _table(NormalPrescriptionSection.referral, s),
                      if (referral != null) ...[
                        const SizedBox(height: 7),
                        if (seed.readOnly) ...[
                          Text(
                            '-----------------------------------------------',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            textAlign: TextAlign.center,
                            style: rxNativeText(
                              14,
                              family: 'OpenSans',
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 9),
                        ],
                        _table(NormalPrescriptionSection.service, s),
                      ],
                    ],
                  ],
                ),
              ),
              _heading('PRESCRIPTION DETAILS', s),
              _tabs(treatment, treatmentTab, onTreatmentTab, s),
              _card(_table(treatment[treatmentTab], s)),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ListTileTheme(
                  horizontalTitleGap: 4,
                  minLeadingWidth: 0,
                  child: CheckboxListTile(
                    key: const Key('rx_admission'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: DocColors.primary,
                    value: rxValue(p, 'pmm_admission_flag') == '1',
                    onChanged:
                        !seed.readOnly && enabled
                            ? (v) => onAdmission(v ?? false)
                            : null,
                    title: Text(
                      !seed.readOnly
                          ? 'Allow this Check Box for Patient Admission'
                          : 'Patient Admission',
                      style: rxNativeText(
                        14,
                        family: 'PatuaOne',
                        weight: FontWeight.w700,
                        color: DocColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

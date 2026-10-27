import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_toast.dart';
import 'dynamic_rx_models.dart';
import 'native_dynamic_rx_controls.dart';
import 'native_dynamic_rx_icons.dart';
import 'native_dynamic_rx_sections.dart';
import 'native_dynamic_rx_sheets.dart';

/// PrescriptionRxFragment + fragment_prescription_rx.xml.
class NativeDynamicRxTab extends StatefulWidget {
  const NativeDynamicRxTab({
    super.key,
    required this.draft,
    required this.catalogue,
    required this.medicineAllowed,
    this.durationRequired = false,
  });
  final DynamicRxDraft draft;
  final DynamicRxCatalogue catalogue;
  final bool medicineAllowed;
  final bool durationRequired;
  @override
  State<NativeDynamicRxTab> createState() => _RxTabState();
}

class _RxTabState extends State<NativeDynamicRxTab>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _toast = AppToastOwner();
  late bool _medicine;
  bool _sheetOpen = false;
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    _medicine = widget.medicineAllowed;
  }

  @override
  void didUpdateWidget(covariant NativeDynamicRxTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.medicineAllowed) _medicine = false;
  }

  void _select(bool medicine) {
    if (medicine && !widget.medicineAllowed) {
      _toast.show(
        context,
        'Medicine prescribing is not enabled for your account',
      );
      return;
    }
    setState(() => _medicine = medicine);
  }

  Future<void> _open(Widget sheet) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    try {
      await showNativeDynamicRxSheet<void>(context, sheet);
    } finally {
      _sheetOpen = false;
    }
  }

  void _editMedicine([DynamicMedicineEntry? entry]) {
    if (!widget.medicineAllowed) return;
    unawaited(
      _open(
        NativeDynamicMedicineSheet(
          draft: widget.draft,
          catalogue: widget.catalogue,
          existing: entry,
          durationRequired: widget.durationRequired,
        ),
      ),
    );
  }

  void _editTherapy([DynamicTherapyEntry? entry]) => unawaited(
    _open(
      NativeDynamicTherapySheet(
        draft: widget.draft,
        options: widget.catalogue.therapies,
        existing: entry,
      ),
    ),
  );
  void _editPlan([DynamicTreatmentPlanEntry? entry]) => unawaited(
    _open(
      NativeDynamicTreatmentPlanSheet(
        draft: widget.draft,
        options: widget.catalogue.treatmentPlans,
        existing: entry,
      ),
    ),
  );

  Widget _segment(bool medicine, DynamicRxMetrics m) {
    final selected = _medicine == medicine,
        locked = medicine && !widget.medicineAllowed;
    final content =
        locked
            ? const Color(0xff98a2b3)
            : selected
            ? Colors.white
            : DynamicRxColors.secondary;
    final label = medicine ? 'MEDICINE' : 'THERAPY';
    final count =
        medicine
            ? widget.draft.medicines.length
            : widget.draft.therapies.length;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label:
            locked
                ? 'Medicine prescribing locked'
                : medicine
                ? 'Open Medicine'
                : 'Open Therapy',
        child: Material(
          color:
              locked
                  ? const Color(0xfff2f4f7)
                  : selected
                  ? const Color(0xff27aeb8)
                  : Colors.white,
          child: InkWell(
            key: Key('dy_rx_segment_${medicine ? 'medicine' : 'therapy'}'),
            onTap: () => _select(medicine),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: m.d(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NativeDynamicRxIcon(
                    medicine ? DynamicRxGlyph.pill : DynamicRxGlyph.therapy,
                    size: m.d(16),
                    color: content,
                  ),
                  SizedBox(width: m.d(6)),
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.only(top: m.d(2)),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: m.text(
                          9,
                          weight: FontWeight.w500,
                          color: content,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: m.d(locked ? 6 : 7)),
                  if (locked)
                    NativeDynamicRxIcon(
                      DynamicRxGlyph.medicineLocked,
                      size: m.d(18),
                      color: content,
                    )
                  else
                    Container(
                      key: Key(
                        'dy_rx_segment_count_${medicine ? 'medicine' : 'therapy'}',
                      ),
                      width: m.d(23),
                      height: m.d(23),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            selected
                                ? const Color(0xffe8f7f8)
                                : const Color(0xfff2f4f7),
                      ),
                      alignment: Alignment.center,
                      padding: EdgeInsets.only(top: m.d(2)),
                      child: Text(
                        '$count',
                        style: m.text(
                          8,
                          weight: FontWeight.w700,
                          color:
                              selected
                                  ? const Color(0xff159aa5)
                                  : DynamicRxColors.secondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final m = DynamicRxMetrics(context), draft = widget.draft;
    return ColoredBox(
      color: Colors.white,
      child: ListenableBuilder(
        listenable: draft,
        builder:
            (context, _) => SingleChildScrollView(
              key: const PageStorageKey<String>('dynamic_rx_scroll'),
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(m.d(4), m.d(4), m.d(4), m.d(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: m.d(4)),
                    child: Container(
                      height: m.d(38),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(m.d(23)),
                      ),
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(m.d(23)),
                        border: Border.all(color: const Color(0xff27aeb8)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [_segment(true, m), _segment(false, m)],
                      ),
                    ),
                  ),
                  Visibility(
                    visible: _medicine,
                    maintainState: true,
                    child: NativeDynamicRxSection(
                      id: 'medicine',
                      title: 'Medicine',
                      icon: DynamicRxGlyph.drugHistory,
                      badge: '${draft.medicines.length}',
                      empty: 'No medicine added',
                      initiallyExpanded: true,
                      onAdd: _editMedicine,
                      rows: [
                        for (final entry in draft.medicines)
                          NativeDynamicRxEntryRow(
                            id: entry.localId,
                            title: entry.medicine.name,
                            medicine: true,
                            onEdit: () => _editMedicine(entry),
                            onDelete: () => draft.deleteMedicine(entry.localId),
                            details: [
                              DynamicRxRowDetail(
                                'Dose: ${entry.dose.name}',
                                weight: FontWeight.w500,
                              ),
                              DynamicRxRowDetail(
                                '${entry.timing.name} • ${entry.route.name}',
                                top: 1,
                                maxLines: 2,
                              ),
                              if (entry.duration.isNotEmpty)
                                DynamicRxRowDetail(
                                  'Duration: ${entry.duration} Days',
                                  top: 1,
                                ),
                              if (entry.notes.isNotEmpty)
                                DynamicRxRowDetail(
                                  'Notes: ${entry.notes}',
                                  maxLines: 3,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Visibility(
                    visible: !_medicine,
                    maintainState: true,
                    child: NativeDynamicRxSection(
                      id: 'therapy',
                      title: 'Therapy',
                      icon: DynamicRxGlyph.therapy,
                      badge: '${draft.therapies.length}',
                      empty: 'No therapy added',
                      initiallyExpanded: true,
                      onAdd: _editTherapy,
                      rows: [
                        for (final entry in draft.therapies)
                          NativeDynamicRxEntryRow(
                            id: entry.localId,
                            title: entry.therapy.name,
                            onEdit: () => _editTherapy(entry),
                            onDelete: () => draft.deleteTherapy(entry.localId),
                            details: [
                              if (entry.notes.isNotEmpty)
                                DynamicRxRowDetail(
                                  'Notes: ${entry.notes}',
                                  size: 7,
                                  maxLines: 3,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(m.d(3), m.d(16), 0, m.d(3)),
                    child: Text(
                      'TREATMENT PLAN',
                      style: m.text(
                        8,
                        weight: FontWeight.w700,
                        color: DynamicRxColors.secondary,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: m.d(5)),
                    child: NativeDynamicRxSection(
                      id: 'treatment_plan',
                      title: 'Treatment Plan',
                      icon: DynamicRxGlyph.treatmentPlan,
                      badge: '${draft.treatmentPlans.length}',
                      empty: 'No treatment plan added',
                      onAdd: _editPlan,
                      rows: [
                        for (final entry in draft.treatmentPlans)
                          NativeDynamicRxEntryRow(
                            id: entry.localId,
                            title: entry.text,
                            onEdit: () => _editPlan(entry),
                            onDelete:
                                () => draft.deleteTreatmentPlan(entry.localId),
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

  @override
  void dispose() {
    _scroll.dispose();
    _toast.dispose();
    super.dispose();
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import 'dynamic_clinical_models.dart';
import 'native_dynamic_clinical_sheets.dart';
import 'native_dynamic_rx_controls.dart';
import 'native_dynamic_rx_icons.dart';

/// PrescriptionClinicalFragment + view_prescription_expandable_section.xml.
/// Own the draft in the parent builder and reuse it for all four tabs.
class NativeDynamicClinicalTab extends StatefulWidget {
  const NativeDynamicClinicalTab({
    super.key,
    required this.draft,
    required this.catalogue,
    required this.loadObjectiveValues,
  });
  final DynamicClinicalDraft draft;
  final DynamicClinicalCatalogue catalogue;
  final Future<List<DynamicRxOption>> Function(String objectiveId)
  loadObjectiveValues;
  @override
  State<NativeDynamicClinicalTab> createState() => _DynamicClinicalTabState();
}

class _DynamicClinicalTabState extends State<NativeDynamicClinicalTab>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _expanded = <String, bool>{'vitals': true};
  final _valueCache = <String, List<DynamicRxOption>>{};
  bool _sheetOpen = false;
  int _catalogueRevision = 0;
  @override
  bool get wantKeepAlive => true;
  @override
  void didUpdateWidget(covariant NativeDynamicClinicalTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.catalogue, oldWidget.catalogue)) {
      _valueCache.clear();
      _catalogueRevision++;
    }
  }

  Future<List<DynamicRxOption>> _values(String id, {bool retry = false}) async {
    if (retry) _valueCache.remove(id);
    final cached = _valueCache[id];
    if (cached != null) return cached;
    final revision = _catalogueRevision;
    final values = List<DynamicRxOption>.unmodifiable(
      await widget.loadObjectiveValues(id),
    );
    if (mounted && revision == _catalogueRevision) _valueCache[id] = values;
    return values;
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

  void _clinical(DynamicClinicalType type, [DynamicClinicalEntry? entry]) {
    unawaited(
      _open(
        NativeDynamicClinicalEntrySheet(
          type: type,
          draft: widget.draft,
          options: widget.catalogue.clinical[type]!,
          existing: entry,
        ),
      ),
    );
  }

  void _objective([DynamicObjectiveEntry? entry]) {
    unawaited(
      _open(
        NativeDynamicObjectiveSheet(
          draft: widget.draft,
          catalogue: widget.catalogue,
          loadValues: _values,
          existing: entry,
        ),
      ),
    );
  }

  Widget _action(
    DynamicRxGlyph glyph,
    String label,
    String id,
    VoidCallback onTap,
    DynamicRxMetrics m, {
    Color color = DynamicRxColors.primary,
  }) => SizedBox.square(
    dimension: m.d(30),
    child: IconButton(
      key: Key(id),
      tooltip: label,
      padding: EdgeInsets.all(m.d(6)),
      onPressed: onTap,
      icon: NativeDynamicRxIcon(glyph, size: m.d(18), color: color),
    ),
  );

  Widget _entryRow(
    String id,
    String title,
    List<(String, Color, double, FontWeight)> details,
    VoidCallback edit,
    VoidCallback delete,
    DynamicRxMetrics m,
  ) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(m.d(7)),
    child: InkWell(
      key: Key('dy_row_$id'),
      onTap: edit,
      borderRadius: BorderRadius.circular(m.d(7)),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: m.d(details.isEmpty ? 42 : 48)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(m.d(10), m.d(6), m.d(5), m.d(6)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: m.text(9, weight: FontWeight.w500),
                    ),
                    for (final detail in details)
                      Padding(
                        padding: EdgeInsets.only(top: m.d(2)),
                        child: Text(
                          detail.$1,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: m.text(
                            detail.$3,
                            color: detail.$2,
                            weight: detail.$4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: m.d(5)),
              _action(
                DynamicRxGlyph.edit,
                'Edit $title',
                'dy_edit_$id',
                edit,
                m,
              ),
              SizedBox(width: m.d(2)),
              _action(
                DynamicRxGlyph.delete,
                'Delete $title',
                'dy_delete_$id',
                delete,
                m,
                color: DynamicRxColors.error,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _section(
    String id,
    String title,
    DynamicRxGlyph icon,
    String badge,
    String empty,
    VoidCallback add,
    List<Widget> rows,
    DynamicRxMetrics m,
  ) {
    final expanded = _expanded[id] ?? false;
    void toggle() => setState(() => _expanded[id] = !expanded);
    return Card(
      key: Key('dy_section_$id'),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: m.d(1),
      margin: EdgeInsets.only(top: m.d(5)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(m.d(8)),
        side: const BorderSide(color: DynamicRxColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('dy_toggle_$id'),
            onTap: toggle,
            child: SizedBox(
              height: m.d(50),
              child: Padding(
                padding: EdgeInsets.only(left: m.d(8), right: m.d(5)),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: m.d(30),
                      child: Padding(
                        padding: EdgeInsets.all(m.d(6)),
                        child: NativeDynamicRxIcon(icon),
                      ),
                    ),
                    SizedBox(width: m.d(8)),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: m.text(11, weight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(width: m.d(5)),
                    Container(
                      height: m.d(25),
                      constraints: BoxConstraints(minWidth: m.d(25)),
                      padding: EdgeInsets.symmetric(
                        horizontal: m.d(6),
                        vertical: m.d(2),
                      ),
                      decoration: BoxDecoration(
                        color: DynamicRxColors.light,
                        borderRadius: BorderRadius.circular(m.d(50)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge,
                        key: Key('dy_count_$id'),
                        style: m.text(
                          8,
                          weight: FontWeight.w700,
                          color: DynamicRxColors.primary,
                        ),
                      ),
                    ),
                    SizedBox(width: m.d(3)),
                    SizedBox.square(
                      dimension: m.d(25),
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(
                          side: BorderSide(color: DynamicRxColors.primary),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: Key('dy_add_$id'),
                          onTap: () {
                            setState(() => _expanded[id] = true);
                            add();
                          },
                          child: Padding(
                            padding: EdgeInsets.all(m.d(6)),
                            child: const NativeDynamicRxIcon(
                              DynamicRxGlyph.add,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: m.d(30),
                      height: m.d(50),
                      child: IconButton(
                        tooltip: expanded ? 'Collapse $title' : 'Expand $title',
                        padding: EdgeInsets.all(m.d(7)),
                        onPressed: toggle,
                        icon: NativeDynamicRxIcon(
                          expanded
                              ? DynamicRxGlyph.expandLess
                              : DynamicRxGlyph.expandMore,
                          color: DynamicRxColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child:
                !expanded
                    ? const SizedBox.shrink()
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: DynamicRxColors.outline,
                        ),
                        if (rows.isEmpty)
                          SizedBox(
                            height: m.d(48),
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: m.d(10),
                                ),
                                child: Text(
                                  empty,
                                  style: m.text(
                                    9,
                                    color: DynamicRxColors.secondary,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              m.d(5),
                              m.d(4),
                              m.d(5),
                              m.d(5),
                            ),
                            child: Column(children: rows),
                          ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _vitals(DynamicRxMetrics m) {
    final data = widget.draft.vitals,
        present = widget.draft.vitals != null && !widget.draft.vitals!.isEmpty;
    void edit() =>
        unawaited(_open(NativeDynamicVitalsSheet(draft: widget.draft)));
    return _section(
      'vitals',
      'Vitals',
      DynamicRxGlyph.vitals,
      present ? 'Added' : 'Not added',
      'No vitals added',
      edit,
      [
        if (present)
          Material(
            color: Colors.white,
            child: InkWell(
              key: const Key('dy_vitals_summary'),
              onTap: edit,
              child: Padding(
                padding: EdgeInsets.all(m.d(6)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: m.d(26),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Recorded measurements',
                              style: m.text(
                                9,
                                weight: FontWeight.w500,
                                color: DynamicRxColors.primary,
                              ),
                            ),
                          ),
                          _action(
                            DynamicRxGlyph.edit,
                            'Edit vitals',
                            'dy_edit_vitals',
                            edit,
                            m,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: DynamicRxColors.outline),
                    for (final line in data!.summary)
                      Padding(
                        padding: EdgeInsets.only(top: m.d(4)),
                        child: Text(
                          line,
                          style: m.text(9, weight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
      m,
    );
  }

  Widget _clinicalSection(DynamicClinicalType type, DynamicRxMetrics m) {
    final entries = widget.draft.entries(type);
    return _section(
      type.name,
      type.sectionLabel,
      dynamicClinicalGlyph(type),
      '${entries.length}',
      type.emptyMessage,
      () => _clinical(type),
      [
        for (final entry in entries)
          _entryRow(
            entry.localId,
            entry.text,
            [
              if (entry.notes.isNotEmpty)
                (
                  'Notes: ${entry.notes}',
                  DynamicRxColors.secondary,
                  7,
                  FontWeight.w400,
                ),
            ],
            () => _clinical(type, entry),
            () => widget.draft.deleteEntry(type, entry.localId),
            m,
          ),
      ],
      m,
    );
  }

  Widget _objectives(DynamicRxMetrics m) => _section(
    'objective',
    'Objective Info',
    DynamicRxGlyph.objective,
    '${widget.draft.objectives.length}',
    'No objective information added',
    _objective,
    [
      for (final entry in widget.draft.objectives)
        _entryRow(
          entry.localId,
          entry.objective.name,
          [
            if (entry.value != null &&
                entry.value!.id.isNotEmpty &&
                entry.value!.name.isNotEmpty)
              (
                'Value: ${entry.value!.name}',
                DynamicRxColors.primary,
                8,
                FontWeight.w500,
              ),
            if (entry.muscleJoint != null)
              (
                'Muscle / Joint: ${entry.muscleJoint!.name}',
                DynamicRxColors.secondary,
                8,
                FontWeight.w400,
              ),
            if (entry.notes.isNotEmpty)
              (
                'Notes: ${entry.notes}',
                DynamicRxColors.secondary,
                8,
                FontWeight.w400,
              ),
          ],
          () => _objective(entry),
          () => widget.draft.deleteObjective(entry.localId),
          m,
        ),
    ],
    m,
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final m = DynamicRxMetrics(context);
    return ColoredBox(
      color: Colors.white,
      child: ListenableBuilder(
        listenable: widget.draft,
        builder:
            (context, _) => SingleChildScrollView(
              key: const PageStorageKey<String>('dynamic_clinical_scroll'),
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(m.d(4), m.d(4), m.d(4), m.d(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _vitals(m),
                  _clinicalSection(DynamicClinicalType.complain, m),
                  _clinicalSection(DynamicClinicalType.injury, m),
                  _clinicalSection(DynamicClinicalType.diagnosis, m),
                  _objectives(m),
                  _clinicalSection(DynamicClinicalType.drugHistory, m),
                  _clinicalSection(DynamicClinicalType.clinicalFinding, m),
                  _clinicalSection(DynamicClinicalType.investigation, m),
                  _clinicalSection(DynamicClinicalType.importantInfo, m),
                ],
              ),
            ),
      ),
    );
  }

  @override
  void dispose() {
    _catalogueRevision++;
    _scroll.dispose();
    super.dispose();
  }
}

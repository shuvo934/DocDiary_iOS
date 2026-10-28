import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dynamic_clinical_models.dart';
import 'dynamic_patient_models.dart';
import 'native_dynamic_builder_icons.dart';
import 'native_dynamic_rx_controls.dart';
import 'native_dynamic_rx_icons.dart';

/// PrescriptionPatientSelectionBottomSheet, its XML and native patient rows.
class NativeDynamicPatientSelectionSheet extends StatefulWidget {
  const NativeDynamicPatientSelectionSheet({
    super.key,
    required this.controller,
  });
  final DynamicPatientController controller;
  @override
  State<NativeDynamicPatientSelectionSheet> createState() =>
      _PatientSelectionState();
}

class _PatientSelectionState extends State<NativeDynamicPatientSelectionSheet> {
  final _search = TextEditingController(),
      _year = TextEditingController(),
      _type = TextEditingController();
  final _scroll = ScrollController();
  bool _resultDelivered = false;
  void _cancel() {
    if (_resultDelivered) return;
    _resultDelivered = true;
    Navigator.pop(context);
  }

  void _select() {
    if (_resultDelivered || !c.canSelect) return;
    _resultDelivered = true;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pop(
      context,
      DynamicPatientSelection(c.selected!, c.prescriptionType),
    );
  }

  DynamicPatientController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(c.start());
    });
  }

  Widget _header(DynamicRxMetrics m) => ColoredBox(
    color: DynamicRxColors.header,
    child: Padding(
      padding: EdgeInsets.all(m.d(8)),
      child: Column(
        children: [
          SizedBox(height: m.d(7)),
          Container(
            width: m.d(32),
            height: m.d(4),
            color: const Color(0xffd0d5dd),
          ),
          Row(
            children: [
              Container(
                width: m.d(36),
                height: m.d(36),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xffeaf7f8),
                  borderRadius: BorderRadius.circular(m.d(9)),
                ),
                child: NativeDynamicBuilderIcon(
                  DynamicBuilderGlyph.person,
                  size: m.d(21),
                ),
              ),
              SizedBox(width: m.d(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Patient',
                      style: m.text(
                        11,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Search and select a patient',
                      style: m.text(7, color: Colors.white),
                    ),
                  ],
                ),
              ),
              SizedBox.square(
                dimension: m.d(36),
                child: IconButton(
                  key: const Key('dy_select_patient_close'),
                  tooltip: 'Close',
                  padding: EdgeInsets.all(m.d(8)),
                  onPressed: _cancel,
                  icon: NativeDynamicRxIcon(
                    DynamicRxGlyph.close,
                    size: m.d(20),
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget _row(DynamicPatientItem item, int index, DynamicRxMetrics m) {
    final selected = c.selected?.historyId == item.historyId;
    return Padding(
      padding: EdgeInsets.only(bottom: m.d(5)),
      child: Material(
        color: selected ? DynamicRxColors.light : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(m.d(8)),
          side: BorderSide(
            color: selected ? DynamicRxColors.primary : DynamicRxColors.outline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('dy_patient_option_${item.historyId}_$index'),
          onTap: () => c.select(item),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: m.d(64)),
            child: Padding(
              padding: EdgeInsets.all(m.d(9)),
              child: Row(
                children: [
                  Container(
                    width: m.d(36),
                    height: m.d(36),
                    padding: EdgeInsets.all(m.d(7)),
                    decoration: const BoxDecoration(
                      color: DynamicRxColors.light,
                      shape: BoxShape.circle,
                    ),
                    child: const NativeDynamicBuilderIcon(
                      DynamicBuilderGlyph.person,
                    ),
                  ),
                  SizedBox(width: m.d(8)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: m.text(9, weight: FontWeight.w600),
                        ),
                        Text(
                          item.code,
                          style: m.text(
                            7,
                            weight: FontWeight.w500,
                            color: DynamicRxColors.primary,
                          ),
                        ),
                        Text(
                          item.details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: m.text(7, color: DynamicRxColors.secondary),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: m.d(6)),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: m.d(85)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final text in [
                          if (item.thana.isNotEmpty) '(${item.thana})',
                          if (item.year.isNotEmpty) '(${item.year})',
                          if (item.mobile.isNotEmpty) item.mobile,
                        ])
                          Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: m.text(7, color: DynamicRxColors.secondary),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: m.d(4)),
                  SizedBox.square(
                    dimension: m.d(28),
                    child: Padding(
                      padding: EdgeInsets.all(m.d(4)),
                      child: Visibility(
                        visible: selected,
                        maintainState: true,
                        maintainAnimation: true,
                        maintainSize: true,
                        child: const NativeDynamicBuilderIcon(
                          DynamicBuilderGlyph.check,
                        ),
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

  Widget _list(DynamicRxMetrics m) {
    if (c.loading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('dy_patient_selection_progress'),
          color: DynamicRxColors.primary,
        ),
      );
    }
    if (c.items.isEmpty) {
      return Center(
        child: InkWell(
          key: const Key('dy_patient_selection_empty'),
          onTap: () => unawaited(c.retry()),
          child: Padding(
            padding: EdgeInsets.all(m.d(12)),
            child: Text(
              c.emptyText,
              textAlign: TextAlign.center,
              style: m.text(
                9,
                weight: FontWeight.w500,
                color: DynamicRxColors.secondary,
              ),
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      key: const Key('dy_patient_selection_list'),
      controller: _scroll,
      padding: EdgeInsets.only(bottom: m.d(6)),
      itemCount: c.items.length,
      itemBuilder: (_, index) => _row(c.items[index], index, m),
    );
  }

  Widget _contents(DynamicRxMetrics m) {
    _year.text = c.year;
    _type.text = c.prescriptionType == '1' ? 'Outdoor' : 'Indoor';
    return Padding(
      padding: EdgeInsets.fromLTRB(m.d(10), m.d(10), m.d(10), 0),
      child: LayoutBuilder(
        builder:
            (context, constraints) => SingleChildScrollView(
              key: const Key('dy_patient_selection_scroll'),
              child: SizedBox(
                height: math.max(m.d(220), constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NativeDynamicRxField(
                      id: 'patient_search',
                      label: 'Search by name, code or mobile',
                      controller: _search,
                      fontSize: 9,
                      onChanged: c.setQuery,
                      suffix:
                          _search.text.isEmpty
                              ? null
                              : IconButton(
                                key: const Key('dy_patient_search_clear'),
                                tooltip: 'Clear text',
                                onPressed: () {
                                  _search.clear();
                                  c.setQuery('');
                                },
                                icon: NativeDynamicRxIcon(
                                  DynamicRxGlyph.close,
                                  size: m.d(16),
                                  color: DynamicRxColors.secondary,
                                ),
                              ),
                    ),
                    SizedBox(height: m.d(8)),
                    Row(
                      children: [
                        Expanded(
                          child: NativeDynamicRxChoiceField(
                            id: 'patient_year',
                            label: 'Registration Year',
                            controller: _year,
                            dropdownOnly: true,
                            fontSize: 9,
                            enabled: c.yearEnabled,
                            options: [
                              for (final year in c.years)
                                DynamicRxOption(year, year),
                            ],
                            onChoice: (option) => c.setYear(option.id),
                            onChanged: (_) {},
                          ),
                        ),
                        SizedBox(width: m.d(8)),
                        Expanded(
                          child: NativeDynamicRxChoiceField(
                            id: 'patient_type',
                            label: 'Prescription Type',
                            controller: _type,
                            dropdownOnly: true,
                            fontSize: 9,
                            options: const [
                              DynamicRxOption('2', 'Indoor'),
                              DynamicRxOption('1', 'Outdoor'),
                            ],
                            onChoice:
                                (option) => c.setPrescriptionType(option.id),
                            onChanged: (_) {},
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(m.d(4), m.d(6), m.d(4), 0),
                      child: Text(
                        c.helper,
                        style: m.text(7, color: DynamicRxColors.secondary),
                      ),
                    ),
                    SizedBox(height: m.d(5)),
                    Expanded(child: _list(m)),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final m = DynamicRxMetrics(context);
      return Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _header(m),
            Expanded(child: _contents(m)),
            const Divider(height: 1, thickness: 1, color: Color(0xffeaecf0)),
            Padding(
              padding: EdgeInsets.fromLTRB(m.d(10), m.d(8), m.d(10), m.d(10)),
              child: Row(
                children: [
                  Expanded(
                    child: NativeDynamicRxButton(
                      label: 'CANCEL',
                      outlined: true,
                      onPressed: _cancel,
                    ),
                  ),
                  SizedBox(width: m.d(8)),
                  Expanded(
                    child: NativeDynamicRxButton(
                      label: 'SELECT PATIENT',
                      onPressed: c.canSelect ? _select : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
  @override
  void dispose() {
    _search.dispose();
    _year.dispose();
    _type.dispose();
    _scroll.dispose();
    super.dispose();
  }
}

Future<DynamicPatientSelection?> showNativeDynamicPatientSelectionSheet(
  BuildContext context,
  DynamicPatientController controller, {
  required bool requiredSelection,
}) => showModalBottomSheet<DynamicPatientSelection>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  enableDrag: !requiredSelection,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black54,
  builder:
      (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: math.max(
              0,
              MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).top -
                  MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: NativeDynamicPatientSelectionSheet(controller: controller),
          ),
        ),
      ),
);

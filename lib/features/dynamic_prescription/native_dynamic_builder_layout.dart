import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/native_json.dart';
import 'dynamic_clinical_models.dart';
import 'dynamic_prescription_seed.dart';
import 'native_dynamic_builder_icons.dart';
import 'native_dynamic_rx_controls.dart';
import 'native_dynamic_rx_icons.dart';

/// activity_prescription_builder.xml. Clinical, Rx and Advice share the builder.
class NativeDynamicBuilderLayout extends StatelessWidget {
  const NativeDynamicBuilderLayout({
    super.key,
    required this.seed,
    required this.data,
    required this.onBack,
    required this.onPatient,
    required this.body,
    required this.enabled,
    this.selectedTab = 0,
    this.onTabChanged,
  });
  final DynamicPrescriptionSeed seed;
  final JsonMap data;
  final VoidCallback onBack;
  final VoidCallback? onPatient;
  final Widget body;
  final bool enabled;
  final int selectedTab;
  final ValueChanged<int>? onTabChanged;
  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context),
        visit = dynamicRxText(data['rvm_code']);
    final disease = dynamicRxText(data['td_name']),
        treatment = dynamicRxText(data['tt_name']);
    final templateText = [
      if (disease.isNotEmpty) 'Disease: $disease',
      if (treatment.isNotEmpty) 'Treatment: $treatment',
    ].join('\n');
    Widget card(Widget child) => Card(
      margin: EdgeInsets.fromLTRB(m.d(4), m.d(4), m.d(4), 0),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: m.d(1.5),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(m.d(8)),
        side: const BorderSide(color: DynamicRxColors.outline),
      ),
      child: child,
    );
    Widget tag(String value) => ColoredBox(
      color: DynamicRxColors.light,
      child: Padding(
        padding: EdgeInsets.all(m.d(3)),
        child: Text(
          value,
          style: TextStyle(
            fontFamily: 'PatuaOne',
            fontSize: m.d(9) - 1,
            color: DynamicRxColors.primary,
          ),
        ),
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DynamicRxColors.header,
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: kToolbarHeight,
                child: Row(
                  children: [
                    SizedBox(
                      width: m.d(42),
                      child: IconButton(
                        key: const Key('dy_builder_back'),
                        tooltip: 'Back',
                        onPressed: onBack,
                        icon: NativeDynamicBuilderIcon(
                          DynamicBuilderGlyph.back,
                          size: m.d(19),
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Prescription',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: m.text(
                          14,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('dy_builder_history'),
                      tooltip: 'Prescription History',
                      onPressed: null,
                      icon: Opacity(
                        opacity: .45,
                        child: NativeDynamicBuilderIcon(
                          DynamicBuilderGlyph.history,
                          size: m.d(19),
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (dynamicRxText(data['rvm_id']).isNotEmpty)
                      IconButton(
                        key: const Key('dy_builder_preview'),
                        tooltip: 'Prescription Preview',
                        onPressed: null,
                        icon: Opacity(
                          opacity: .45,
                          child: NativeDynamicBuilderIcon(
                            DynamicBuilderGlyph.preview,
                            size: m.d(19),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    SizedBox(width: m.d(4)),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: ColoredBox(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Column(
                        children: [
                          card(
                            InkWell(
                              key: const Key('dy_builder_patient'),
                              onTap: enabled ? onPatient : null,
                              child: Padding(
                                padding: EdgeInsets.all(m.d(10)),
                                child: Row(
                                  children: [
                                    Container(
                                      width: m.d(40),
                                      height: m.d(40),
                                      decoration: const BoxDecoration(
                                        color: DynamicRxColors.light,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: EdgeInsets.all(m.d(6)),
                                      child: const NativeDynamicBuilderIcon(
                                        DynamicBuilderGlyph.person,
                                      ),
                                    ),
                                    SizedBox(width: m.d(8)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            seed.name.isEmpty
                                                ? 'Patient'
                                                : seed.name,
                                            key: const Key(
                                              'dy_builder_patient_name',
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: m.text(
                                              12,
                                              weight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            seed.code.isEmpty ? '-' : seed.code,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: m.text(
                                              8,
                                              color: DynamicRxColors.secondary,
                                            ),
                                          ),
                                          Text(
                                            seed.details.isEmpty
                                                ? 'Patient information'
                                                : seed.details,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: m.text(
                                              8,
                                              color: DynamicRxColors.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: m.d(8)),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        tag(
                                          'Visit: ${visit.isEmpty ? '...' : visit}',
                                        ),
                                        SizedBox(height: m.d(2)),
                                        tag('Date: ${seed.visitDate}'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Semantics(
                            enabled: false,
                            child: card(
                              Padding(
                                key: const Key('dy_builder_template'),
                                padding: EdgeInsets.all(m.d(10)),
                                child: Row(
                                  children: [
                                    Container(
                                      width: m.d(30),
                                      height: m.d(30),
                                      padding: EdgeInsets.all(m.d(6)),
                                      decoration: BoxDecoration(
                                        color: DynamicRxColors.light,
                                        borderRadius: BorderRadius.circular(
                                          m.d(8),
                                        ),
                                      ),
                                      child: const NativeDynamicBuilderIcon(
                                        DynamicBuilderGlyph.template,
                                      ),
                                    ),
                                    SizedBox(width: m.d(8)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Prescription Templates',
                                            style: m.text(
                                              11,
                                              weight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            templateText.isEmpty
                                                ? 'No template loaded'
                                                : templateText,
                                            style: m.text(
                                              8,
                                              color: DynamicRxColors.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (templateText.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.all(m.d(5)),
                                        child: NativeDynamicBuilderIcon(
                                          DynamicBuilderGlyph.check,
                                          size: m.d(18),
                                        ),
                                      ),
                                    SizedBox(
                                      width: m.d(26),
                                      child: Center(
                                        child: Text(
                                          '›',
                                          style: TextStyle(
                                            fontFamily: 'Archivo',
                                            fontSize: m.d(24) - 1,
                                            color: DynamicRxColors.secondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: m.d(8)),
                            child: Row(
                              children: [
                                for (final (index, label)
                                    in const [
                                      'CLINICAL',
                                      'RX',
                                      'ADVICE',
                                      'REVIEW',
                                    ].indexed)
                                  _tab(index, label, m),
                              ],
                            ),
                          ),
                          SizedBox(height: m.d(4)),
                          Expanded(child: body),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              m.d(8),
                              m.d(6),
                              m.d(8),
                              m.d(4),
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: NativeDynamicRxButton(
                                label:
                                    const [
                                      'NEXT: RX',
                                      'NEXT: ADVICE',
                                      'NEXT: REVIEW',
                                    ][selectedTab],
                                onPressed:
                                    enabled &&
                                            selectedTab < 2 &&
                                            onTabChanged != null
                                        ? () => onTabChanged!(selectedTab + 1)
                                        : null,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _tab(int index, String label, DynamicRxMetrics m) {
    final selected = selectedTab == index,
        active = enabled && index < 3 && onTabChanged != null;
    return Expanded(
      child: Semantics(
        selected: selected,
        enabled: active,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: active ? () => onTabChanged!(index) : null,
            borderRadius: BorderRadius.circular(m.d(8)),
            child: Container(
              key: Key('dy_builder_tab_$label'),
              constraints: BoxConstraints(minHeight: m.d(36)),
              alignment: Alignment.center,
              decoration:
                  selected
                      ? BoxDecoration(
                        borderRadius: BorderRadius.circular(m.d(8)),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            DynamicRxColors.header,
                            DynamicRxColors.primary,
                          ],
                        ),
                      )
                      : null,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  label,
                  style: m.text(
                    10.5,
                    weight: FontWeight.w700,
                    family: 'PatuaOne',
                    color: selected ? Colors.white : const Color(0xff777777),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NativeDynamicPatientDetailsFrame extends StatelessWidget {
  const NativeDynamicPatientDetailsFrame({super.key, required this.body});
  final Widget body;
  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context);
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ColoredBox(
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
                        decoration: BoxDecoration(
                          color: const Color(0xffeaf7f8),
                          borderRadius: BorderRadius.circular(m.d(9)),
                        ),
                        child: Center(
                          child: NativeDynamicBuilderIcon(
                            DynamicBuilderGlyph.person,
                            size: m.d(21),
                          ),
                        ),
                      ),
                      SizedBox(width: m.d(8)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Patient Details',
                              style: m.text(
                                11,
                                weight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Registered patient information',
                              style: m.text(7, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      SizedBox.square(
                        dimension: m.d(36),
                        child: IconButton(
                          key: const Key('dy_patient_close'),
                          tooltip: 'Close',
                          padding: EdgeInsets.all(m.d(8)),
                          onPressed: () => Navigator.pop(context),
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
          ),
          Expanded(child: body),
          const Divider(height: 1, thickness: 1, color: Color(0xffeaecf0)),
          Padding(
            padding: EdgeInsets.fromLTRB(m.d(10), m.d(8), m.d(10), m.d(10)),
            child: SizedBox(
              width: double.infinity,
              child: NativeDynamicRxButton(
                label: 'CLOSE',
                outlined: true,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

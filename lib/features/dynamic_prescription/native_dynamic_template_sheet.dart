import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/app_toast.dart';
import 'dynamic_template_models.dart';
import 'native_dynamic_builder_icons.dart';
import 'native_dynamic_rx_controls.dart';
import 'native_dynamic_rx_icons.dart';

/// bottom_sheet_prescription_template.xml and item_prescription_template.xml.
/// Reuses the accepted field metrics, fonts, native assets and sheet appearance.
class NativeDynamicTemplateSheet extends StatefulWidget {
  const NativeDynamicTemplateSheet({super.key, required this.controller});
  final DynamicTemplateController controller;
  @override
  State<NativeDynamicTemplateSheet> createState() => _TemplateSheetState();
}

class _TemplateSheetState extends State<NativeDynamicTemplateSheet> {
  final _diseaseQuery = TextEditingController(),
      _treatmentQuery = TextEditingController();
  final _diseaseScroll = ScrollController(),
      _treatmentScroll = ScrollController();
  final _toast = AppToastOwner();
  bool _treatmentStep = false, _confirming = false;
  String? _diseaseSelection, _treatmentSelection;
  DynamicTemplateController get c => widget.controller;
  DynamicTemplateKind get _kind =>
      _treatmentStep
          ? DynamicTemplateKind.treatment
          : DynamicTemplateKind.disease;
  @override
  void initState() {
    super.initState();
    _treatmentStep = c.diseaseId.isNotEmpty;
    _diseaseSelection = c.diseaseId;
    _treatmentSelection = c.treatmentId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(c.loadDiseases());
      if (_treatmentStep) unawaited(c.loadTreatments());
    });
  }

  DynamicTemplateOption? _selected(
    List<DynamicTemplateOption> items,
    String? id,
  ) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _load() async {
    if (_confirming || c.applying) return;
    final kind = _kind;
    final option = _selected(
      _treatmentStep ? c.treatments : c.diseases,
      _treatmentStep ? _treatmentSelection : _diseaseSelection,
    );
    if (option == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final disease = kind == DynamicTemplateKind.disease;
    if (disease ? c.hasDiseaseData : c.hasRxData) {
      _confirming = true;
      bool? load;
      try {
        load = await showDialog<bool>(
          context: context,
          useRootNavigator: false,
          builder:
              (dialogContext) => AlertDialog(
                key: const Key('dy_template_replace_dialog'),
                title: Text(
                  disease
                      ? 'Replace current prescription data?'
                      : 'Replace current Rx data?',
                ),
                content: Text(
                  disease
                      ? 'Loading this Disease Template will replace all current Clinical, Advice and Rx data.\n\nVitals, Reference and Notes will remain unchanged.'
                      : 'Loading this Treatment Template will replace all current Medicine, Therapy and Treatment Plan data.',
                ),
                actions: [
                  TextButton(
                    key: const Key('dy_template_replace_cancel'),
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('CANCEL'),
                  ),
                  TextButton(
                    key: const Key('dy_template_replace_load'),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('LOAD'),
                  ),
                ],
              ),
        );
      } finally {
        _confirming = false;
      }
      if (!mounted || load != true) return;
    }
    final successful = await c.apply(kind, option);
    if (!mounted || !successful) return;
    _toast.show(context, '${kind.label} loaded successfully');
    if (disease) {
      setState(() {
        _treatmentStep = true;
        _diseaseSelection = c.diseaseId;
        _treatmentSelection = null;
        _treatmentQuery.clear();
      });
    } else {
      Navigator.pop(context);
    }
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
          SizedBox(height: m.d(4)),
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
                  DynamicBuilderGlyph.template,
                  size: m.d(21),
                ),
              ),
              SizedBox(width: m.d(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prescription Templates',
                      style: m.text(
                        11,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Choose a Disease Template, then optionally choose Treatment',
                      style: m.text(7, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Opacity(
                opacity: c.applying ? .45 : 1,
                child: SizedBox.square(
                  dimension: m.d(36),
                  child: IconButton(
                    key: const Key('dy_template_close'),
                    tooltip: 'Close',
                    padding: EdgeInsets.all(m.d(8)),
                    onPressed: c.applying ? null : () => Navigator.pop(context),
                    icon: NativeDynamicRxIcon(
                      DynamicRxGlyph.close,
                      size: m.d(20),
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _button(
    String label,
    VoidCallback? onPressed,
    DynamicRxMetrics m, {
    bool outlined = false,
  }) => Opacity(
    opacity: onPressed == null ? .45 : 1,
    child: SizedBox(
      height: m.d(40),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ElevatedButton(
          key: Key('dy_template_action_$label'),
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: outlined ? Colors.white : DynamicRxColors.primary,
            disabledBackgroundColor:
                outlined ? Colors.white : DynamicRxColors.primary,
            foregroundColor: outlined ? DynamicRxColors.primary : Colors.white,
            disabledForegroundColor:
                outlined ? DynamicRxColors.primary : Colors.white,
            elevation: 0,
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(m.d(8)),
              side:
                  outlined
                      ? const BorderSide(color: DynamicRxColors.primary)
                      : BorderSide.none,
            ),
            textStyle: m.text(8, weight: FontWeight.w700),
          ),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
        ),
      ),
    ),
  );

  Widget _list(DynamicRxMetrics m) {
    final treatment = _treatmentStep;
    final items = treatment ? c.treatments : c.diseases;
    final query = treatment ? _treatmentQuery : _diseaseQuery;
    final values = items
        .where((item) => item.matches(query.text))
        .toList(growable: false);
    final error = treatment ? c.treatmentError : c.diseaseError;
    final applyError = treatment ? c.treatmentApplyError : c.diseaseApplyError;
    final loading =
        (treatment ? c.treatmentLoading : c.diseaseLoading) ||
        c.applyingKind == _kind;
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('dy_template_progress'),
          color: DynamicRxColors.primary,
        ),
      );
    }
    if (error.isNotEmpty) {
      return Center(
        child: InkWell(
          key: const Key('dy_template_error'),
          onTap: () {
            if (applyError) {
              c.clearApplyError(_kind);
            } else if (treatment) {
              unawaited(c.loadTreatments(retry: true));
            } else {
              unawaited(c.loadDiseases(retry: true));
            }
          },
          child: Padding(
            padding: EdgeInsets.all(m.d(10)),
            child: Text(
              error + (applyError ? '' : '\nTap to retry'),
              textAlign: TextAlign.center,
              style: m.text(8, color: DynamicRxColors.error),
            ),
          ),
        ),
      );
    }
    if (values.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(m.d(10)),
          child: Text(
            items.isEmpty
                ? 'No ${_kind.label} available'
                : 'No matching ${_kind.label} found',
            key: const Key('dy_template_empty'),
            textAlign: TextAlign.center,
            style: m.text(8, color: DynamicRxColors.secondary),
          ),
        ),
      );
    }
    final selected = treatment ? _treatmentSelection : _diseaseSelection;
    return ListView.builder(
      key: Key('dy_template_list_${_kind.name}'),
      controller: treatment ? _treatmentScroll : _diseaseScroll,
      padding: EdgeInsets.only(bottom: m.d(4)),
      itemCount: values.length,
      itemBuilder: (context, index) {
        final item = values[index], checked = item.id == selected;
        return Padding(
          padding: EdgeInsets.only(bottom: m.d(5)),
          child: Material(
            color: checked ? const Color(0xfff2fbf6) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(m.d(8)),
              side: BorderSide(
                color:
                    checked ? const Color(0xff27ae60) : const Color(0xffeaecf0),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('dy_template_option_${_kind.name}_${item.id}_$index'),
              onTap:
                  c.applying
                      ? null
                      : () => setState(() {
                        if (treatment) {
                          _treatmentSelection = item.id;
                        } else {
                          _diseaseSelection = item.id;
                        }
                      }),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: m.d(48)),
                child: Padding(
                  padding: EdgeInsets.all(m.d(10)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: m.text(
                                9,
                                weight: FontWeight.w500,
                                color: const Color(0xff101828),
                              ),
                            ),
                            if (item.description.isNotEmpty) ...[
                              SizedBox(height: m.d(2)),
                              Text(
                                item.description,
                                style: m.text(
                                  7,
                                  color: DynamicRxColors.secondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: m.d(2)),
                      IgnorePointer(
                        child: Radio<String>(
                          value: item.id,
                          groupValue: selected,
                          onChanged: (_) {},
                          activeColor: DynamicRxColors.primary,
                          fillColor: const WidgetStatePropertyAll(
                            DynamicRxColors.primary,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _section(DynamicRxMetrics m) {
    final treatment = _treatmentStep;
    final query = treatment ? _treatmentQuery : _diseaseQuery;
    final loading = treatment ? c.treatmentLoading : c.diseaseLoading;
    final selection = _selected(
      treatment ? c.treatments : c.diseases,
      treatment ? _treatmentSelection : _diseaseSelection,
    );
    final canLoad = !loading && !c.applying && selection != null;
    Widget contents() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          treatment ? 'STEP 2 OF 2' : 'STEP 1 OF 2',
          style: m.text(
            7,
            weight: FontWeight.w500,
            color: DynamicRxColors.primary,
          ),
        ),
        SizedBox(height: m.d(2)),
        Text(
          _kind.label,
          style: m.text(
            11,
            weight: FontWeight.w700,
            color: const Color(0xff101828),
          ),
        ),
        SizedBox(height: m.d(2)),
        Text(
          treatment
              ? 'Medicine, Therapy and Treatment Plan data will be loaded'
              : 'Clinical and Advice data will be loaded',
          style: m.text(7, color: DynamicRxColors.secondary),
        ),
        if (treatment) ...[
          SizedBox(height: m.d(8)),
          Container(
            padding: EdgeInsets.fromLTRB(m.d(10), m.d(6), m.d(4), m.d(6)),
            decoration: BoxDecoration(
              color: const Color(0xfff2fbf6),
              borderRadius: BorderRadius.circular(m.d(8)),
              border: Border.all(color: const Color(0xffb7e4c7)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Disease Template loaded',
                        style: m.text(7, color: DynamicRxColors.secondary),
                      ),
                      Text(
                        c.diseaseName,
                        style: m.text(
                          8,
                          weight: FontWeight.w500,
                          color: const Color(0xff1b8f4b),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: const Key('dy_template_change'),
                  onPressed:
                      c.applying
                          ? null
                          : () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() {
                              _treatmentStep = false;
                              _diseaseQuery.clear();
                            });
                          },
                  style: TextButton.styleFrom(
                    foregroundColor: DynamicRxColors.primary,
                    textStyle: m.text(7, weight: FontWeight.w700),
                    minimumSize: Size(0, m.d(36)),
                    padding: EdgeInsets.symmetric(horizontal: m.d(8)),
                  ),
                  child: const Text('CHANGE'),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: m.d(8)),
        NativeDynamicRxField(
          id: 'template_search_${_kind.name}',
          label: 'Search ${_kind.label}',
          controller: query,
          fontSize: 8,
          fontWeight: FontWeight.w400,
          enabled: !loading && !c.applying,
          onChanged: (_) => setState(() {}),
          suffix:
              query.text.isEmpty
                  ? null
                  : IconButton(
                    key: const Key('dy_template_clear_search'),
                    tooltip: 'Clear text',
                    onPressed:
                        !loading && !c.applying
                            ? () => setState(query.clear)
                            : null,
                    icon: NativeDynamicRxIcon(
                      DynamicRxGlyph.close,
                      size: m.d(16),
                      color: DynamicRxColors.secondary,
                    ),
                  ),
        ),
        SizedBox(height: m.d(8)),
        Expanded(child: _list(m)),
        SizedBox(height: m.d(8)),
        if (treatment)
          Row(
            children: [
              Expanded(
                child: _button(
                  'DONE',
                  c.applying ? null : () => Navigator.pop(context),
                  m,
                  outlined: true,
                ),
              ),
              SizedBox(width: m.d(8)),
              Expanded(
                child: _button(
                  c.applyingKind == _kind
                      ? 'LOADING TREATMENT...'
                      : 'LOAD TREATMENT',
                  canLoad ? () => unawaited(_load()) : null,
                  m,
                ),
              ),
            ],
          )
        else
          _button(
            c.applyingKind == _kind
                ? 'LOADING DISEASE TEMPLATE...'
                : 'LOAD DISEASE TEMPLATE',
            canLoad ? () => unawaited(_load()) : null,
            m,
          ),
      ],
    );
    return Padding(
      padding: EdgeInsets.all(m.d(10)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minimum = m.d(treatment ? 310 : 230);
          if (constraints.maxHeight < minimum) {
            return SingleChildScrollView(
              key: const Key('dy_template_compact_scroll'),
              child: SizedBox(height: minimum, child: contents()),
            );
          }
          return contents();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final m = DynamicRxMetrics(context);
      return PopScope(
        canPop: !c.applying,
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [_header(m), Expanded(child: _section(m))]),
        ),
      );
    },
  );
  @override
  void dispose() {
    _diseaseQuery.dispose();
    _treatmentQuery.dispose();
    _diseaseScroll.dispose();
    _treatmentScroll.dispose();
    _toast.dispose();
    super.dispose();
  }
}

Future<void> showNativeDynamicTemplateSheet(
  BuildContext context,
  DynamicTemplateController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  enableDrag: false,
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
            child: NativeDynamicTemplateSheet(controller: controller),
          ),
        ),
      ),
);

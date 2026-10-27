import 'dart:async';

import 'package:flutter/material.dart';

import 'dynamic_advice_models.dart';
import 'native_dynamic_advice_sheet.dart';
import 'native_dynamic_rx_controls.dart';
import 'native_dynamic_rx_sections.dart';

/// PrescriptionAdviceFragment: five native sections, initially collapsed.
class NativeDynamicAdviceTab extends StatefulWidget {
  const NativeDynamicAdviceTab({
    super.key,
    required this.draft,
    required this.catalogue,
  });
  final DynamicAdviceDraft draft;
  final DynamicAdviceCatalogue catalogue;
  @override
  State<NativeDynamicAdviceTab> createState() => _AdviceTabState();
}

class _AdviceTabState extends State<NativeDynamicAdviceTab>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  bool _sheetOpen = false;
  @override
  bool get wantKeepAlive => true;
  Future<void> _open(
    DynamicAdviceType type, [
    DynamicAdviceEntry? entry,
  ]) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    try {
      await showNativeDynamicRxSheet<void>(
        context,
        NativeDynamicAdviceSheet(
          type: type,
          draft: widget.draft,
          options: widget.catalogue.options[type]!,
          existing: entry,
        ),
      );
    } finally {
      _sheetOpen = false;
    }
  }

  void _add(DynamicAdviceType type) {
    final entries = widget.draft.entries(type);
    // Native Reference/Notes '+' opens the existing row in Edit mode.
    unawaited(
      _open(type, type.isSingle && entries.isNotEmpty ? entries.first : null),
    );
  }

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
              key: const PageStorageKey<String>('dynamic_advice_scroll'),
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(m.d(4), m.d(4), m.d(4), m.d(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final type in DynamicAdviceType.values)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: type == DynamicAdviceType.notes ? m.d(5) : 0,
                      ),
                      child: NativeDynamicRxSection(
                        id: type.name,
                        title: type.label,
                        icon: dynamicAdviceGlyph(type),
                        badge:
                            type.isSingle
                                ? widget.draft.entries(type).isEmpty
                                    ? 'Not added'
                                    : 'Added'
                                : '${widget.draft.entries(type).length}',
                        empty: type.emptyMessage,
                        onAdd: () => _add(type),
                        rows: [
                          for (final entry in widget.draft.entries(type))
                            NativeDynamicRxEntryRow(
                              id: entry.localId,
                              title: entry.text,
                              onEdit: () => unawaited(_open(type, entry)),
                              onDelete:
                                  () => widget.draft.deleteEntry(
                                    type,
                                    entry.localId,
                                  ),
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
    super.dispose();
  }
}

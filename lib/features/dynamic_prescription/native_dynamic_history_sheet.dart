import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'dynamic_history_models.dart';
import 'native_dynamic_history_item_tile.dart';
import 'native_dynamic_builder_icons.dart';
import 'native_dynamic_rx_controls.dart';
import 'native_dynamic_rx_icons.dart';

/// PrescriptionHistoryBottomSheet and the two native History XML layouts.
class NativeDynamicHistorySheet extends StatefulWidget {
  const NativeDynamicHistorySheet({
    super.key,
    required this.controller,
    this.onPreview,
  });
  final DynamicHistoryController controller;
  final ValueChanged<String>? onPreview;
  @override
  State<NativeDynamicHistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<NativeDynamicHistorySheet> {
  final _scroll = ScrollController();
  bool _confirming = false;
  bool _resultDelivered = false;
  DynamicHistoryController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(c.load());
    });
  }

  Future<void> _load() async {
    if (_confirming || _resultDelivered || !c.canLoad) return;
    if (c.hasData) {
      _confirming = true;
      bool? replace;
      try {
        replace = await showDialog<bool>(
          context: context,
          useRootNavigator: false,
          builder:
              (dialogContext) => AlertDialog(
                key: const Key('dy_history_replace_dialog'),
                title: const Text('Load previous prescription?'),
                content: const Text(
                  'Loading this prescription will replace all current Clinical, Rx and Advice information.\n\n'
                  'The current patient and prescription identity will remain unchanged.',
                ),
                actions: [
                  TextButton(
                    key: const Key('dy_history_replace_cancel'),
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('CANCEL'),
                  ),
                  TextButton(
                    key: const Key('dy_history_replace_load'),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('LOAD & REPLACE'),
                  ),
                ],
              ),
        );
      } finally {
        _confirming = false;
      }
      if (!mounted || replace != true) return;
    }
    final loaded = await c.applySelected();
    if (!mounted) return;
    if (loaded) {
      _resultDelivered = true;
      Navigator.pop(context, true);
    } else if (c.applyError.isNotEmpty) {
      await showDialog<void>(
        context: context,
        useRootNavigator: false,
        builder:
            (dialogContext) => AlertDialog(
              key: const Key('dy_history_load_error'),
              title: const Text('Load Failed'),
              content: Text(c.applyError),
              actions: [
                TextButton(
                  key: const Key('dy_history_error_ok'),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  }

  void _preview() {
    if (_confirming ||
        _resultDelivered ||
        !c.canLoad ||
        widget.onPreview == null) {
      return;
    }
    _resultDelivered = true;
    final id = c.selected!.rvmId;
    Navigator.pop(context);
    widget.onPreview!(id);
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
                  DynamicBuilderGlyph.history,
                  size: m.d(21),
                ),
              ),
              SizedBox(width: m.d(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prescription History',
                      style: m.text(
                        11,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Select a previous prescription to load or preview',
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
                    key: const Key('dy_history_close'),
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
  Widget _row(
    DynamicPrescriptionHistoryItem item,
    int index,
    DynamicRxMetrics m,
  ) => NativeDynamicHistoryItemTile(
    item: item,
    index: index,
    isSelected: item.rvmId == c.selected?.rvmId,
    onTap: c.applying ? null : () => c.select(item),
  );

  Widget _contents(DynamicRxMetrics m) {
    if (c.loading) return const SizedBox.shrink();
    if (c.listError.isNotEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(m.d(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  c.listError,
                  textAlign: TextAlign.center,
                  style: m.text(8, color: DynamicRxColors.error),
                ),
                SizedBox(height: m.d(8)),
                SizedBox(
                  height: m.d(38),
                  child: OutlinedButton(
                    key: const Key('dy_action_RETRY'),
                    onPressed: () => unawaited(c.load()),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: EdgeInsets.symmetric(horizontal: m.d(16)),
                      foregroundColor: DynamicRxColors.primary,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: DynamicRxColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(m.d(8)),
                      ),
                      textStyle: m.text(8, weight: FontWeight.w700),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('RETRY'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (c.items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(m.d(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: .55,
                  child: NativeDynamicBuilderIcon(
                    DynamicBuilderGlyph.history,
                    size: m.d(42),
                    color: DynamicRxColors.secondary,
                  ),
                ),
                SizedBox(height: m.d(8)),
                Text(
                  'No prescription history found',
                  textAlign: TextAlign.center,
                  style: m.text(9, weight: FontWeight.w600),
                ),
                SizedBox(height: m.d(3)),
                Text(
                  'This patient has no previous prescription.',
                  textAlign: TextAlign.center,
                  style: m.text(7, color: DynamicRxColors.secondary),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return IgnorePointer(
      ignoring: c.applying,
      child: Opacity(
        opacity: c.applying ? .45 : 1,
        child: ListView.builder(
          key: const Key('dy_history_list'),
          controller: _scroll,
          padding: EdgeInsets.only(bottom: m.d(8)),
          itemCount: c.items.length,
          itemBuilder: (_, index) => _row(c.items[index], index, m),
        ),
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
          child: Column(
            children: [
              _header(m),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(m.d(10), m.d(10), m.d(10), 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (c.countText.isNotEmpty)
                        Text(
                          c.countText,
                          style: m.text(
                            8,
                            weight: FontWeight.w500,
                            color: DynamicRxColors.secondary,
                          ),
                        ),
                      SizedBox(height: m.d(6)),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(child: _contents(m)),
                            if (c.loading || c.applying)
                              const Center(
                                child: CircularProgressIndicator(
                                  key: Key('dy_history_progress'),
                                  color: DynamicRxColors.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xffeaecf0)),
              Padding(
                padding: EdgeInsets.fromLTRB(m.d(12), m.d(8), m.d(12), m.d(10)),
                child: Row(
                  children: [
                    Expanded(
                      child: Opacity(
                        opacity:
                            c.canLoad &&
                                    !_confirming &&
                                    widget.onPreview != null
                                ? 1
                                : .45,
                        child: NativeDynamicRxButton(
                          label: 'PREVIEW',
                          outlined: true,
                          onPressed:
                              c.canLoad &&
                                      !_confirming &&
                                      widget.onPreview != null
                                  ? _preview
                                  : null,
                        ),
                      ),
                    ),
                    SizedBox(width: m.d(10)),
                    Expanded(
                      child: NativeDynamicRxButton(
                        label: 'LOAD TO CURRENT RX',
                        onPressed: c.canLoad ? () => unawaited(_load()) : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
}

Future<bool?> showNativeDynamicHistorySheet(
  BuildContext context,
  DynamicHistoryController controller, {
  ValueChanged<String>? onPreview,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  enableDrag: false,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black54,
  builder:
      (context) => SafeArea(
        top: false,
        child: SizedBox(
          height: math.max(
            0,
            MediaQuery.sizeOf(context).height -
                MediaQuery.paddingOf(context).top,
          ),
          child: NativeDynamicHistorySheet(
            controller: controller,
            onPreview: onPreview,
          ),
        ),
      ),
);

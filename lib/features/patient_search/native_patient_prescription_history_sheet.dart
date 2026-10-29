import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/failure.dart';
import '../dynamic_prescription/dynamic_history_models.dart';
import '../dynamic_prescription/native_dynamic_builder_icons.dart';
import '../dynamic_prescription/native_dynamic_history_item_tile.dart';
import '../dynamic_prescription/native_dynamic_rx_controls.dart';
import '../dynamic_prescription/native_dynamic_rx_icons.dart';

/// PatientPrescriptionSearchBottomSheet: select and preview, with no load/edit.
class NativePatientPrescriptionHistorySheet extends StatefulWidget {
  const NativePatientPrescriptionHistorySheet({
    super.key,
    required this.load,
    this.onFailure,
  });
  final Future<List<DynamicPrescriptionHistoryItem>> Function() load;
  final ValueChanged<Object>? onFailure;
  @override
  State<NativePatientPrescriptionHistorySheet> createState() => _HistoryState();
}

class _HistoryState extends State<NativePatientPrescriptionHistorySheet> {
  final _scroll = ScrollController();
  List<DynamicPrescriptionHistoryItem> _items = const [];
  String? _selected;
  String _error = '';
  bool _loading = true, _delivered = false;
  int _version = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
  }

  Future<void> _load() async {
    final version = ++_version;
    setState(() {
      _loading = true;
      _error = '';
      _selected = null;
      _items = const [];
    });
    try {
      final items = await widget.load();
      if (!mounted || version != _version) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (failure) {
      if (!mounted || version != _version || failure is ObsoleteRequest) return;
      setState(() {
        _loading = false;
        _error =
            failure is AppFailure
                ? failure.message
                : 'Prescription history could not be loaded';
      });
      widget.onFailure?.call(failure);
    }
  }

  @override
  void dispose() {
    ++_version;
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context);
    final enabled = !_loading && !_delivered && _selected != null;
    return Material(
      key: const Key('patient_search_history_sheet'),
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
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
                                'Select a prescription to preview',
                                style: m.text(7, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        SizedBox.square(
                          dimension: m.d(36),
                          child: IconButton(
                            key: const Key('patient_search_history_close'),
                            tooltip: 'Close',
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
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(m.d(10), m.d(10), m.d(10), 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_items.isNotEmpty)
                      Text(
                        '${_items.length} ${_items.length == 1 ? 'prescription' : 'prescriptions'} found',
                        style: m.text(
                          8,
                          weight: FontWeight.w500,
                          color: DynamicRxColors.secondary,
                        ),
                      ),
                    SizedBox(height: m.d(6)),
                    Expanded(
                      child:
                          _loading
                              ? const Center(
                                child: CircularProgressIndicator(
                                  key: Key('patient_search_history_progress'),
                                ),
                              )
                              : _error.isNotEmpty
                              ? Center(
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _error,
                                        textAlign: TextAlign.center,
                                        style: m.text(
                                          8,
                                          color: DynamicRxColors.error,
                                        ),
                                      ),
                                      SizedBox(height: m.d(8)),
                                      OutlinedButton(
                                        key: const Key(
                                          'patient_search_history_retry',
                                        ),
                                        onPressed: _load,
                                        child: const Text('RETRY'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              : _items.isEmpty
                              ? Center(
                                child: SingleChildScrollView(
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
                                        style: m.text(
                                          9,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: m.d(3)),
                                      Text(
                                        'This patient has no previous prescription.',
                                        textAlign: TextAlign.center,
                                        style: m.text(
                                          7,
                                          color: DynamicRxColors.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              : ListView.builder(
                                controller: _scroll,
                                itemCount: _items.length,
                                itemBuilder:
                                    (_, index) => NativeDynamicHistoryItemTile(
                                      item: _items[index],
                                      index: index,
                                      isSelected:
                                          _selected == _items[index].rvmId,
                                      keyPrefix:
                                          'patient_search_history_option',
                                      onTap:
                                          _delivered
                                              ? null
                                              : () => setState(
                                                () =>
                                                    _selected =
                                                        _items[index].rvmId,
                                              ),
                                    ),
                              ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xffeaecf0)),
            Padding(
              padding: EdgeInsets.fromLTRB(m.d(12), m.d(8), m.d(12), m.d(10)),
              child: Opacity(
                opacity: enabled ? 1 : .45,
                child: NativeDynamicRxButton(
                  label: 'PREVIEW',
                  onPressed:
                      enabled
                          ? () {
                            _delivered = true;
                            Navigator.pop(context, _selected);
                          }
                          : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

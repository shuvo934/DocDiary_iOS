import 'package:flutter/material.dart';

import 'dynamic_advice_models.dart';
import 'dynamic_clinical_models.dart';
import 'native_dynamic_rx_controls.dart';
import 'native_dynamic_rx_icons.dart';

DynamicRxGlyph dynamicAdviceGlyph(DynamicAdviceType type) => switch (type) {
  DynamicAdviceType.advice => DynamicRxGlyph.advice,
  DynamicAdviceType.followUp => DynamicRxGlyph.followUp,
  DynamicAdviceType.specialAlert => DynamicRxGlyph.specialAlert,
  DynamicAdviceType.reference => DynamicRxGlyph.reference,
  DynamicAdviceType.notes => DynamicRxGlyph.notes,
};

/// PrescriptionAdviceEntryBottomSheet + the shared native Clinical sheet XML.
class NativeDynamicAdviceSheet extends StatefulWidget {
  const NativeDynamicAdviceSheet({
    super.key,
    required this.type,
    required this.draft,
    required this.options,
    this.existing,
  });
  final DynamicAdviceType type;
  final DynamicAdviceDraft draft;
  final List<DynamicRxOption> options;
  final DynamicAdviceEntry? existing;
  @override
  State<NativeDynamicAdviceSheet> createState() => _AdviceSheetState();
}

class _AdviceSheetState extends State<NativeDynamicAdviceSheet> {
  late final TextEditingController _text;
  DynamicRxOption? _retained;
  String? _error;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.existing?.text ?? '');
    _retained =
        widget.type.hasOptions
            ? DynamicRxOption.byId(widget.options, widget.existing?.masterId)
            : null;
  }

  void _save() {
    final type = widget.type,
        name = type.label.toLowerCase(),
        text = _text.text.trim();
    setState(() => _error = null);
    if (text.isEmpty) {
      setState(
        () =>
            _error = type.hasOptions ? 'Enter or select $name' : 'Enter $name',
      );
      return;
    }
    if (type.hasOptions) {
      final exact = DynamicRxOption.exact(widget.options, text);
      if (exact != null) _retained = exact;
    }
    final entry = DynamicAdviceEntry(
      localId: widget.existing?.localId,
      masterId: type.hasOptions ? _retained?.id : null,
      text: text,
    );
    if (!widget.draft.saveEntry(
      type,
      entry,
      updating: widget.existing != null,
    )) {
      setState(() => _error = 'This $name has already been added');
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context),
        type = widget.type,
        editing = widget.existing != null,
        name = widget.type.label.toLowerCase();
    return NativeDynamicRxSheet(
      title: '${editing ? 'Edit' : 'Add'} ${type.label}',
      subtitle:
          editing
              ? 'Update the selected $name information'
              : type.hasOptions
              ? 'Search or enter $name information'
              : 'Enter $name information',
      icon: dynamicAdviceGlyph(type),
      saveLabel: '${editing ? 'UPDATE' : 'ADD'} ${type.label.toUpperCase()}',
      onSave: _save,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(m.d(12), m.d(14), m.d(12), m.d(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (type.hasOptions)
              NativeDynamicRxChoiceField(
                id: 'advice_entry',
                label: type.label,
                controller: _text,
                options: widget.options,
                maxLines: 10,
                error: _error,
                onChoice:
                    (option) => setState(() {
                      _retained = option;
                      _error = null;
                    }),
                onChanged: (_) => setState(() => _error = null),
              )
            else
              NativeDynamicRxField(
                id: 'advice_entry',
                label: type.label,
                controller: _text,
                maxLines: 10,
                error: _error,
                onChanged: (_) => setState(() => _error = null),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(m.d(4), m.d(8), m.d(4), 0),
              child: Text(
                type.hasOptions
                    ? 'Select from the list or enter a custom $name'
                    : 'Write the required information',
                style: m.text(7, color: DynamicRxColors.secondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }
}

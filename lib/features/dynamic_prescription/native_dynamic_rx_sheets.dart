import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dynamic_clinical_models.dart';
import 'dynamic_rx_models.dart';
import 'native_dynamic_rx_controls.dart';
import 'native_dynamic_rx_icons.dart';

class NativeDynamicMedicineSheet extends StatefulWidget {
  const NativeDynamicMedicineSheet({
    super.key,
    required this.draft,
    required this.catalogue,
    this.existing,
  });
  final DynamicRxDraft draft;
  final DynamicRxCatalogue catalogue;
  final DynamicMedicineEntry? existing;
  @override
  State<NativeDynamicMedicineSheet> createState() => _MedicineSheetState();
}

class _MedicineSheetState extends State<NativeDynamicMedicineSheet> {
  late final Map<String, TextEditingController> _fields;
  final _errors = <String, String>{};
  Map<String, List<DynamicRxOption>> get _options => {
    'medicine': widget.catalogue.medicines,
    'dose': widget.catalogue.doses,
    'timing': widget.catalogue.timings,
    'route': widget.catalogue.routes,
  };
  static const _labels = {
    'medicine': 'Medicine',
    'dose': 'Dose',
    'timing': 'Medicine Timing',
    'route': 'Medicine Route',
  };
  @override
  void initState() {
    super.initState();
    final entry = widget.existing, catalogue = widget.catalogue;
    final values = {
      'medicine': entry?.medicine.name ?? '',
      'dose':
          entry != null
              ? entry.dose.name
              : DynamicRxOption.byId(catalogue.doses, '2')?.name ?? '',
      'timing':
          entry != null
              ? entry.timing.name
              : DynamicRxOption.byId(catalogue.timings, '2')?.name ?? '',
      'route':
          entry != null
              ? entry.route.name
              : DynamicRxOption.byId(catalogue.routes, '11')?.name ?? '',
      'duration': entry?.duration ?? '',
      'notes': entry?.notes ?? '',
    };
    _fields = {
      for (final value in values.entries)
        value.key: TextEditingController(text: value.value),
    };
  }

  void _save() {
    final selected = <String, DynamicRxOption>{};
    setState(_errors.clear);
    for (final key in _labels.keys) {
      final text = _fields[key]!.text.trim();
      final name = switch (key) {
        'medicine' => 'a medicine',
        'dose' => 'a dose',
        'timing' => 'medicine timing',
        _ => 'medicine route',
      };
      final exact = DynamicRxOption.exact(_options[key]!, text);
      if (text.isEmpty || exact == null) {
        setState(
          () =>
              _errors[key] =
                  text.isEmpty
                      ? 'Select $name'
                      : 'Select a valid $key from the list',
        );
        return;
      }
      selected[key] = exact;
    }
    final durationError = DynamicMedicineEntry.durationError(
      _fields['duration']!.text,
    );
    if (durationError != null) {
      setState(() => _errors['duration'] = durationError);
      return;
    }
    final entry = DynamicMedicineEntry(
      localId: widget.existing?.localId,
      medicine: selected['medicine']!,
      dose: selected['dose']!,
      timing: selected['timing']!,
      route: selected['route']!,
      duration: _fields['duration']!.text,
      notes: _fields['notes']!.text,
    );
    if (!widget.draft.saveMedicine(entry, updating: widget.existing != null)) {
      setState(
        () => _errors['medicine'] = 'This medicine has already been added',
      );
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context), editing = widget.existing != null;
    return NativeDynamicRxSheet(
      title: '${editing ? 'Edit' : 'Add'} Medicine',
      subtitle:
          editing
              ? 'Update medicine and prescription details'
              : 'Select medicine and prescription details',
      icon: DynamicRxGlyph.drugHistory,
      saveLabel: '${editing ? 'UPDATE' : 'ADD'} MEDICINE',
      onSave: _save,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(m.d(12), m.d(14), m.d(12), m.d(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final field in _labels.entries)
              Padding(
                padding: EdgeInsets.only(
                  top: field.key == 'medicine' ? 0 : m.d(10),
                ),
                child: NativeDynamicRxChoiceField(
                  id: 'rx_${field.key}',
                  label: field.value,
                  controller: _fields[field.key]!,
                  options: _options[field.key]!,
                  error: _errors[field.key],
                  onChoice: (_) => setState(() => _errors.remove(field.key)),
                  onChanged: (_) => setState(() => _errors.remove(field.key)),
                ),
              ),
            SizedBox(height: m.d(10)),
            NativeDynamicRxField(
              id: 'rx_duration',
              label: 'Duration (Days) - Optional',
              controller: _fields['duration']!,
              numeric: true,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              error: _errors['duration'],
              onChanged: (_) => setState(() => _errors.remove('duration')),
            ),
            SizedBox(height: m.d(10)),
            NativeDynamicRxField(
              id: 'rx_notes',
              label: 'Notes (Optional)',
              controller: _fields['notes']!,
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }
}

class NativeDynamicTherapySheet extends StatefulWidget {
  const NativeDynamicTherapySheet({
    super.key,
    required this.draft,
    required this.options,
    this.existing,
  });
  final DynamicRxDraft draft;
  final List<DynamicRxOption> options;
  final DynamicTherapyEntry? existing;
  @override
  State<NativeDynamicTherapySheet> createState() => _TherapySheetState();
}

class _TherapySheetState extends State<NativeDynamicTherapySheet> {
  late final TextEditingController _text, _notes;
  String? _error;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.existing?.therapy.name ?? '');
    _notes = TextEditingController(text: widget.existing?.notes ?? '');
  }

  void _save() {
    final text = _text.text.trim(),
        exact = DynamicRxOption.exact(widget.options, _text.text);
    setState(() => _error = null);
    if (text.isEmpty || exact == null) {
      setState(
        () =>
            _error =
                text.isEmpty
                    ? 'Select a therapy'
                    : 'Select a valid therapy from the list',
      );
      return;
    }
    final entry = DynamicTherapyEntry(
      localId: widget.existing?.localId,
      therapy: exact,
      notes: _notes.text,
    );
    if (!widget.draft.saveTherapy(entry, updating: widget.existing != null)) {
      setState(() => _error = 'This therapy has already been added');
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context), editing = widget.existing != null;
    return NativeDynamicRxSheet(
      title: '${editing ? 'Edit' : 'Add'} Therapy',
      subtitle:
          editing ? 'Update the selected therapy' : 'Search and select therapy',
      icon: DynamicRxGlyph.therapy,
      saveLabel: '${editing ? 'UPDATE' : 'ADD'} THERAPY',
      onSave: _save,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(m.d(12), m.d(14), m.d(12), m.d(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NativeDynamicRxChoiceField(
              id: 'rx_therapy',
              label: 'Therapy',
              controller: _text,
              options: widget.options,
              error: _error,
              onChoice: (_) => setState(() => _error = null),
              onChanged: (_) => setState(() => _error = null),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(m.d(4), m.d(8), m.d(4), 0),
              child: Text(
                'Select therapy from the available list',
                style: m.text(7, color: DynamicRxColors.secondary),
              ),
            ),
            SizedBox(height: m.d(10)),
            NativeDynamicRxField(
              id: 'rx_therapy_notes',
              label: 'Notes (Optional)',
              controller: _notes,
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    _notes.dispose();
    super.dispose();
  }
}

class NativeDynamicTreatmentPlanSheet extends StatefulWidget {
  const NativeDynamicTreatmentPlanSheet({
    super.key,
    required this.draft,
    required this.options,
    this.existing,
  });
  final DynamicRxDraft draft;
  final List<DynamicRxOption> options;
  final DynamicTreatmentPlanEntry? existing;
  @override
  State<NativeDynamicTreatmentPlanSheet> createState() =>
      _TreatmentPlanSheetState();
}

class _TreatmentPlanSheetState extends State<NativeDynamicTreatmentPlanSheet> {
  late final TextEditingController _text;
  DynamicRxOption? _retained;
  String? _error;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.existing?.text ?? '');
    _retained = DynamicRxOption.byId(widget.options, widget.existing?.masterId);
  }

  void _save() {
    final text = _text.text.trim();
    setState(() => _error = null);
    if (text.isEmpty) {
      setState(() => _error = 'Enter or select treatment plan');
      return;
    }
    final exact = DynamicRxOption.exact(widget.options, text);
    if (exact != null) _retained = exact;
    final entry = DynamicTreatmentPlanEntry(
      localId: widget.existing?.localId,
      masterId: _retained?.id,
      text: text,
    );
    if (!widget.draft.saveTreatmentPlan(
      entry,
      updating: widget.existing != null,
    )) {
      setState(() => _error = 'This treatment plan has already been added');
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context), editing = widget.existing != null;
    return NativeDynamicRxSheet(
      title: '${editing ? 'Edit' : 'Add'} Treatment Plan',
      subtitle:
          editing
              ? 'Update the selected treatment plan'
              : 'Search or enter treatment plan information',
      icon: DynamicRxGlyph.treatmentPlan,
      saveLabel: '${editing ? 'UPDATE' : 'ADD'} TREATMENT PLAN',
      onSave: _save,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(m.d(12), m.d(14), m.d(12), m.d(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NativeDynamicRxChoiceField(
              id: 'rx_treatment_plan',
              label: 'Treatment Plan',
              controller: _text,
              options: widget.options,
              error: _error,
              maxLines: 10,
              onChoice:
                  (option) => setState(() {
                    _retained = option;
                    _error = null;
                  }),
              onChanged: (_) => setState(() => _error = null),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(m.d(4), m.d(8), m.d(4), 0),
              child: Text(
                'Select from the list or enter a custom treatment plan',
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

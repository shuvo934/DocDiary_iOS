import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_toast.dart';
import '../../core/failure.dart';
import 'dynamic_clinical_models.dart';
import 'native_dynamic_rx_controls.dart';
import 'native_dynamic_rx_icons.dart';

DynamicRxGlyph dynamicClinicalGlyph(DynamicClinicalType type) => switch (type) {
  DynamicClinicalType.complain => DynamicRxGlyph.complain,
  DynamicClinicalType.injury => DynamicRxGlyph.injury,
  DynamicClinicalType.diagnosis => DynamicRxGlyph.diagnosis,
  DynamicClinicalType.clinicalFinding => DynamicRxGlyph.clinicalFindings,
  DynamicClinicalType.drugHistory => DynamicRxGlyph.drugHistory,
  DynamicClinicalType.investigation => DynamicRxGlyph.investigation,
  DynamicClinicalType.importantInfo => DynamicRxGlyph.importantInfo,
};

class NativeDynamicClinicalEntrySheet extends StatefulWidget {
  const NativeDynamicClinicalEntrySheet({
    super.key,
    required this.type,
    required this.draft,
    required this.options,
    this.existing,
  });
  final DynamicClinicalType type;
  final DynamicClinicalDraft draft;
  final List<DynamicRxOption> options;
  final DynamicClinicalEntry? existing;
  @override
  State<NativeDynamicClinicalEntrySheet> createState() =>
      _ClinicalEntrySheetState();
}

class _ClinicalEntrySheetState extends State<NativeDynamicClinicalEntrySheet> {
  late final TextEditingController _text, _notes;
  DynamicRxOption? _selected, _retained;
  String? _error;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.existing?.text ?? '');
    _notes = TextEditingController(text: widget.existing?.notes ?? '');
    _selected = DynamicRxOption.byId(widget.options, widget.existing?.masterId);
    _retained = _selected;
  }

  void _save() {
    final type = widget.type,
        name = widget.type.label.toLowerCase(),
        text = _text.text.trim();
    setState(() => _error = null);
    if (text.isEmpty) {
      setState(
        () =>
            _error = type.hasOptions ? 'Enter or select $name' : 'Enter $name',
      );
      return;
    }
    final exact =
        type.hasOptions ? DynamicRxOption.exact(widget.options, text) : null;
    if (exact != null) {
      _selected = exact;
      _retained = exact;
    }
    final master = _selected ?? (type.allowsCustom ? _retained : null);
    if (!type.allowsCustom && master == null) {
      setState(() => _error = 'Select a valid $name from the list');
      return;
    }
    final entry = DynamicClinicalEntry(
      localId: widget.existing?.localId,
      masterId: master?.id,
      text: text,
      notes: type.hasNotes ? _notes.text : '',
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
    final subtitle =
        editing
            ? 'Update the selected $name information'
            : !type.hasOptions
            ? 'Enter $name information'
            : type.allowsCustom
            ? 'Search or enter $name information'
            : 'Search and select $name';
    final helper =
        !type.hasOptions
            ? 'Write the required information'
            : type.allowsCustom
            ? 'Select from the list or enter a custom $name'
            : 'Select $name from the available list';
    return NativeDynamicRxSheet(
      title: '${editing ? 'Edit' : 'Add'} ${type.label}',
      subtitle: subtitle,
      icon: dynamicClinicalGlyph(type),
      saveLabel: '${editing ? 'UPDATE' : 'ADD'} ${type.label.toUpperCase()}',
      onSave: _save,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(m.d(12), m.d(14), m.d(12), m.d(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (type.hasOptions)
              NativeDynamicRxChoiceField(
                id: 'entry',
                label: type.label,
                controller: _text,
                options: widget.options,
                error: _error,
                maxLines: 10,
                onChoice:
                    (option) => setState(() {
                      _selected = option;
                      _retained = option;
                      _error = null;
                    }),
                onChanged:
                    (text) => setState(() {
                      _error = null;
                      if (_selected != null &&
                          _selected!.name.toLowerCase() !=
                              text.trim().toLowerCase()) {
                        _selected = null;
                      }
                    }),
              )
            else
              NativeDynamicRxField(
                id: 'entry',
                label: type.label,
                controller: _text,
                maxLines: 10,
                error: _error,
                onChanged: (_) => setState(() => _error = null),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(m.d(4), m.d(8), m.d(4), 0),
              child: Text(
                helper,
                style: m.text(7, color: DynamicRxColors.secondary),
              ),
            ),
            if (type.hasNotes)
              Padding(
                padding: EdgeInsets.only(top: m.d(10)),
                child: NativeDynamicRxField(
                  id: 'entry_notes',
                  label: 'Notes (Optional)',
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                ),
              ),
            // Native btn_delete_clinical_entry stays hidden; deletion is on the row.
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

class NativeDynamicVitalsSheet extends StatefulWidget {
  const NativeDynamicVitalsSheet({super.key, required this.draft});
  final DynamicClinicalDraft draft;
  @override
  State<NativeDynamicVitalsSheet> createState() => _VitalsSheetState();
}

class _VitalsSheetState extends State<NativeDynamicVitalsSheet> {
  late final Map<String, TextEditingController> _fields;
  late final AppToastOwner _toast;
  Map<String, String> _errors = {};
  late final bool _editing;
  @override
  void initState() {
    super.initState();
    _toast = AppToastOwner();
    _editing = widget.draft.vitals != null && !widget.draft.vitals!.isEmpty;
    _fields = {
      for (final key in DynamicVitals.keys)
        key: TextEditingController(text: widget.draft.vitals?[key] ?? ''),
    };
  }

  void _changed(String key) {
    setState(() {
      _errors.remove(key);
      if (key == 'height' || key == 'weight') {
        _fields['bmi']!.text = DynamicVitals.calculateBmi(
          _fields['height']!.text,
          _fields['weight']!.text,
        );
      }
    });
  }

  void _save() {
    final data = DynamicVitals({
      for (final entry in _fields.entries) entry.key: entry.value.text,
    });
    if (data.isEmpty) {
      _toast.show(context, 'Enter at least one vital measurement');
      return;
    }
    setState(() => _errors = data.errors);
    if (_errors.isNotEmpty) return;
    widget.draft.saveVitals(data);
    Navigator.pop(context);
  }

  Future<void> _clear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Clear vitals?'),
            content: const Text(
              'All saved vital measurements will be removed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
    if (!mounted || yes != true) return;
    widget.draft.saveVitals(null);
    Navigator.pop(context);
  }

  Widget _field(
    String key,
    String label,
    String unit, {
    bool decimal = false,
    int length = 3,
  }) => NativeDynamicRxField(
    id: key,
    label: label,
    controller: _fields[key]!,
    numeric: true,
    error: _errors[key],
    unit: unit,
    formatters: [
      decimal
          ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
          : FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(length),
    ],
    onChanged: (_) => _changed(key),
  );
  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context);
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        SizedBox(width: m.d(8)),
        Expanded(child: b),
      ],
    );
    return NativeDynamicRxSheet(
      title: _editing ? 'Edit Vitals' : 'Add Vitals',
      subtitle: 'Enter the patient’s current measurements',
      icon: DynamicRxGlyph.vitals,
      saveLabel: 'SAVE VITALS',
      onSave: _save,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(m.d(12), m.d(12), m.d(12), m.d(6)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: m.d(5)),
              child: Text(
                'Blood Pressure',
                style: m.text(
                  8,
                  weight: FontWeight.w500,
                  color: const Color(0xff344054),
                ),
              ),
            ),
            pair(
              _field('systolic', 'Systolic (mmHg)', 'mmHg'),
              _field('diastolic', 'Diastolic (mmHg)', 'mmHg'),
            ),
            SizedBox(height: m.d(8)),
            pair(
              _field('pulse', 'Pulse Rate (bpm)', 'bpm'),
              _field(
                'temperature',
                'Temperature (°F)',
                '°F',
                decimal: true,
                length: 5,
              ),
            ),
            SizedBox(height: m.d(8)),
            pair(
              _field('spo2', 'SpO₂ (%)', '%'),
              _field('respiration', 'Respiratory Rate (/min)', '/min'),
            ),
            SizedBox(height: m.d(8)),
            pair(
              _field('height', 'Height (cm)', 'cm', decimal: true, length: 6),
              _field('weight', 'Weight (kg)', 'kg', decimal: true, length: 6),
            ),
            SizedBox(height: m.d(8)),
            NativeDynamicRxField(
              id: 'bmi',
              label: 'BMI — automatically calculated',
              controller: _fields['bmi']!,
              readOnly: true,
              filled: true,
              unit: 'kg/m²',
            ),
            if (_editing)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('dy_clear_vitals'),
                  onPressed: _clear,
                  child: Text(
                    'CLEAR VITALS',
                    style: m.text(
                      7,
                      weight: FontWeight.w500,
                      color: DynamicRxColors.error,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _toast.dispose();
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

typedef DynamicObjectiveValueLoader =
    Future<List<DynamicRxOption>> Function(String objectiveId, {bool retry});

class NativeDynamicObjectiveSheet extends StatefulWidget {
  const NativeDynamicObjectiveSheet({
    super.key,
    required this.draft,
    required this.catalogue,
    required this.loadValues,
    this.existing,
  });
  final DynamicClinicalDraft draft;
  final DynamicClinicalCatalogue catalogue;
  final DynamicObjectiveValueLoader loadValues;
  final DynamicObjectiveEntry? existing;
  @override
  State<NativeDynamicObjectiveSheet> createState() => _ObjectiveSheetState();
}

class _ObjectiveSheetState extends State<NativeDynamicObjectiveSheet> {
  late final TextEditingController _objective, _value, _muscle, _notes;
  DynamicRxOption? _selected;
  List<DynamicRxOption> _values = const [];
  String? _pendingValueId, _loadError;
  Map<String, String> _errors = {};
  int _request = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final old = widget.existing;
    _objective = TextEditingController(text: old?.objective.name ?? '');
    _value = TextEditingController();
    _muscle = TextEditingController(text: old?.muscleJoint?.name ?? '');
    _notes = TextEditingController(text: old?.notes ?? '');
    _pendingValueId = old?.value?.id;
    final current = DynamicRxOption.byId(
      widget.catalogue.objectives,
      old?.objective.id,
    );
    if (current != null) {
      _objective.text = current.name;
      _select(current);
    }
    final joint = DynamicRxOption.byId(
      widget.catalogue.muscleJoints,
      old?.muscleJoint?.id,
    );
    if (joint != null) _muscle.text = joint.name;
  }

  void _select(DynamicRxOption option) {
    final changed =
        _selected == null ||
        _selected!.id != option.id ||
        _selected!.name.toLowerCase() != option.name.toLowerCase();
    _selected = option;
    _errors.remove('objective');
    if (!changed) return;
    if (widget.existing?.objective.id != option.id) _pendingValueId = null;
    _value.clear();
    _values = const [];
    _errors.remove('value');
    unawaited(_load(option.id));
  }

  Future<void> _load(String id, {bool retry = false}) async {
    final revision = ++_request;
    setState(() {
      _loading = true;
      _loadError = null;
      _value.clear();
      _values = const [];
    });
    try {
      final values = await widget.loadValues(id, retry: retry);
      if (!mounted || revision != _request || _selected?.id != id) return;
      setState(() {
        _values = List.unmodifiable(values);
        _loading = false;
        if (_pendingValueId != null && widget.existing?.objective.id == id) {
          final restored = DynamicRxOption.byId(_values, _pendingValueId);
          if (restored != null) {
            _value.text = restored.name;
            _pendingValueId = null;
          }
        }
      });
    } on ObsoleteRequest {
      if (mounted && revision == _request) Navigator.pop(context);
    } catch (error) {
      if (!mounted || revision != _request || _selected?.id != id) return;
      setState(() {
        _loading = false;
        _loadError =
            error is AppFailure
                ? error.message
                : 'Server Problem or Internet Not Connected';
      });
    }
  }

  void _objectiveChanged(String text) {
    setState(() {
      _errors.remove('objective');
      if (_selected != null &&
          _selected!.name.toLowerCase() == text.trim().toLowerCase()) {
        return;
      }
      final exact = DynamicRxOption.exact(widget.catalogue.objectives, text);
      if (exact != null) {
        _select(exact);
        return;
      }
      _selected = null;
      _pendingValueId = null;
      _request++;
      _loading = false;
      _loadError = null;
      _values = const [];
      _value.clear();
      _errors.remove('value');
    });
  }

  void _error(String key, String value) => setState(() => _errors[key] = value);

  void _save() {
    setState(() => _errors = {});
    final text = _objective.text.trim();
    if (text.isEmpty) {
      _error('objective', 'Select an objective');
      return;
    }
    final objective = DynamicRxOption.exact(widget.catalogue.objectives, text);
    if (objective == null) {
      _error('objective', 'Select a valid objective from the list');
      return;
    }
    if (_selected == null ||
        _selected!.id != objective.id ||
        _selected!.name.toLowerCase() != objective.name.toLowerCase()) {
      _select(objective);
    }
    if (_loading) {
      _error('value', 'Please wait for the values to load');
      return;
    }
    final valueText = _value.text.trim(), notes = _notes.text.trim();
    final value = DynamicRxOption.exact(_values, valueText);
    if (valueText.isNotEmpty && value == null) {
      _error('value', 'Select a valid value from the list');
      return;
    }
    if (value == null && notes.isEmpty) {
      setState(() {
        _errors['value'] =
            _values.isEmpty
                ? 'No predefined value is available'
                : 'Select a value or enter notes';
        _errors['notes'] = 'Enter notes if no value is selected';
      });
      return;
    }
    final muscleText = _muscle.text.trim(),
        muscle = DynamicRxOption.exact(
          widget.catalogue.muscleJoints,
          _muscle.text,
        );
    if (muscleText.isNotEmpty && muscle == null) {
      _error('muscle', 'Select a valid Muscle / Joint from the list');
      return;
    }
    final item = DynamicObjectiveEntry(
      localId: widget.existing?.localId,
      objective: objective,
      value: value,
      muscleJoint: muscle,
      notes: notes,
    );
    if (!widget.draft.saveObjective(item, updating: widget.existing != null)) {
      _error('objective', 'This objective information has already been added');
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final m = DynamicRxMetrics(context), editing = widget.existing != null;
    return NativeDynamicRxSheet(
      title: editing ? 'Edit Objective Info' : 'Add Objective Info',
      subtitle:
          editing
              ? 'Update the selected objective details'
              : 'Select the objective details',
      icon: DynamicRxGlyph.objective,
      saveLabel: editing ? 'UPDATE OBJECTIVE' : 'ADD OBJECTIVE',
      onSave: _loading ? null : _save,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(m.d(12), m.d(12), m.d(12), m.d(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NativeDynamicRxChoiceField(
              id: 'objective',
              label: 'Objective',
              controller: _objective,
              options: widget.catalogue.objectives,
              maxLines: 2,
              error: _errors['objective'],
              onChoice: (option) => setState(() => _select(option)),
              onChanged: _objectiveChanged,
            ),
            SizedBox(height: m.d(8)),
            NativeDynamicRxChoiceField(
              id: 'value',
              label: 'Value',
              controller: _value,
              options: _values,
              error: _errors['value'],
              enabled:
                  _selected != null &&
                  !_loading &&
                  _loadError == null &&
                  _values.isNotEmpty,
              dropdownOnly: true,
              onChoice: (_) => setState(() => _errors.remove('value')),
              onChanged: (_) {},
            ),
            if (_loading)
              Padding(
                padding: EdgeInsets.only(top: m.d(5)),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: m.d(16),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DynamicRxColors.primary,
                      ),
                    ),
                    SizedBox(width: m.d(6)),
                    Text(
                      'Loading values...',
                      style: m.text(7, color: DynamicRxColors.secondary),
                    ),
                  ],
                ),
              ),
            if (_loadError != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _loadError!,
                      style: m.text(7, color: DynamicRxColors.error),
                    ),
                  ),
                  TextButton(
                    key: const Key('dy_retry_values'),
                    onPressed: () {
                      if (_selected != null) {
                        unawaited(_load(_selected!.id, retry: true));
                      }
                    },
                    child: Text(
                      'RETRY',
                      style: m.text(
                        7,
                        weight: FontWeight.w700,
                        color: DynamicRxColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            SizedBox(height: m.d(8)),
            NativeDynamicRxChoiceField(
              id: 'muscle',
              label: 'Muscle / Joint Name',
              controller: _muscle,
              options: widget.catalogue.muscleJoints,
              maxLines: 2,
              error: _errors['muscle'],
              onChoice: (_) => setState(() => _errors.remove('muscle')),
              onChanged: (_) => setState(() => _errors.remove('muscle')),
            ),
            SizedBox(height: m.d(8)),
            NativeDynamicRxField(
              id: 'notes',
              label: 'Notes / Degree Value (Optional)',
              controller: _notes,
              minLines: 3,
              maxLines: 3,
              error: _errors['notes'],
              onChanged:
                  (_) => setState(() {
                    _errors.remove('notes');
                    _errors.remove('value');
                  }),
            ),
            // Literal helper from native XML; active Java validation accepts value OR notes.
            Padding(
              padding: EdgeInsets.only(top: m.d(8)),
              child: Text(
                'Objective and Value are required',
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
    _request++;
    _objective.dispose();
    _value.dispose();
    _muscle.dispose();
    _notes.dispose();
    super.dispose();
  }
}

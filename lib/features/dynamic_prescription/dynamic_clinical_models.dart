import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/failure.dart';
import '../../core/native_json.dart';

// ClinicalEntryType.java, ClinicalEntryItem.java and ObjectiveInfoItem.java.
enum DynamicClinicalType {
  complain(
    'Complain',
    'complaints',
    'cm_id',
    'cm_name',
    'getComplain',
    'cm_notes',
  ),
  injury(
    'Injury',
    'injuries',
    'injury_id',
    'injury_name',
    'getInjury',
    'injury_notes',
  ),
  diagnosis(
    'Diagnosis',
    'diagnosis',
    'dm_id',
    'dm_name',
    'getDiagnosis',
    'dm_notes',
  ),
  clinicalFinding(
    'Clinical Finding',
    'clinical_findings',
    'cfm_id',
    'cfm_name',
    'getClinicalFindings',
    'cfm_notes',
  ),
  drugHistory(
    'Drug History',
    'drug_history',
    'medicine_id',
    'medicine_name',
    'getDrugHistory',
    '',
  ),
  investigation(
    'Tests / Investigation',
    'investigations',
    'pfn_id',
    'pfn_fee_name',
    'getTestInvestigation',
    '',
  ),
  importantInfo('Important Info', 'important_info', '', '', '', '');

  const DynamicClinicalType(
    this.label,
    this.bodyKey,
    this.idKey,
    this.nameKey,
    this.endpoint,
    this.noteKey,
  );
  final String label, bodyKey, idKey, nameKey, endpoint, noteKey;
  bool get hasOptions => this != importantInfo;
  bool get allowsCustom => this != drugHistory && this != investigation;
  bool get hasNotes => this == investigation;
  bool get doctorSpecific =>
      this == complain ||
      this == injury ||
      this == diagnosis ||
      this == clinicalFinding;
  String get sectionLabel =>
      this == clinicalFinding ? 'Clinical Findings' : label;
  String get emptyMessage => switch (this) {
    complain => 'No complain added',
    injury => 'No injury added',
    diagnosis => 'No diagnosis added',
    clinicalFinding => 'No clinical finding added',
    drugHistory => 'No drug history added',
    investigation => 'No test or investigation added',
    importantInfo => 'No important info added',
  };
}

String dynamicRxText(Object? value) => nativeText(value).trim();

class DynamicRxOption {
  const DynamicRxOption(this.id, this.name, [this.note = '']);
  final String id, name, note;

  bool matches(String query) {
    final nameLower = name.toLowerCase();
    return query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .every(nameLower.contains);
  }

  static DynamicRxOption? exact(
    Iterable<DynamicRxOption> options,
    String text,
  ) {
    final query = text.trim().toLowerCase();
    if (query.isEmpty) return null;
    // Native ClinicalOptionAdapter.findExactMatch uses source order.
    for (final option in options) {
      if (option.name.toLowerCase() == query) return option;
    }
    return null;
  }

  static DynamicRxOption? byId(Iterable<DynamicRxOption> options, String? id) {
    if (id == null || id.isEmpty) return null;
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }
}

String _localId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

Object? _jsonId(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final id = int.tryParse(value.trim());
  if (id == null) {
    throw AppFailure(
      'Invalid master ID: $value',
      kind: FailureKind.invalidData,
    );
  }
  return id;
}

class DynamicClinicalEntry {
  DynamicClinicalEntry({
    String? localId,
    String? masterId,
    required String text,
    String notes = '',
  }) : localId = localId ?? _localId(),
       masterId =
           masterId == null || masterId.trim().isEmpty ? null : masterId.trim(),
       text = text.trim(),
       notes = notes.trim();
  final String localId, text, notes;
  final String? masterId;

  bool sameValue(DynamicClinicalEntry other) =>
      (masterId != null &&
          other.masterId != null &&
          masterId == other.masterId) ||
      text.toLowerCase() == other.text.toLowerCase();

  JsonMap toBody(DynamicClinicalType type) => switch (type) {
    DynamicClinicalType.importantInfo => {'text': text},
    DynamicClinicalType.drugHistory => {'medicine_id': _jsonId(masterId)},
    DynamicClinicalType.investigation => {
      'pfn_id': _jsonId(masterId),
      'notes': notes,
    },
    _ => {type.idKey: _jsonId(masterId), 'name': text},
  };
}

class DynamicObjectiveEntry {
  DynamicObjectiveEntry({
    String? localId,
    required this.objective,
    this.value,
    this.muscleJoint,
    String notes = '',
  }) : localId = localId ?? _localId(),
       notes = notes.trim();
  final String localId, notes;
  final DynamicRxOption objective;
  final DynamicRxOption? value, muscleJoint;

  static bool _same(DynamicRxOption? a, DynamicRxOption? b) {
    if (a != null && b != null && a.id.isNotEmpty && b.id.isNotEmpty) {
      return a.id == b.id;
    }
    return (a?.name ?? '').toLowerCase() == (b?.name ?? '').toLowerCase();
  }

  bool sameValue(DynamicObjectiveEntry other) =>
      _same(objective, other.objective) &&
      _same(value, other.value) &&
      _same(muscleJoint, other.muscleJoint) &&
      notes.toLowerCase() == other.notes.toLowerCase();
  JsonMap toBody() => {
    'om_id': _jsonId(objective.id),
    'od_id': _jsonId(value?.id),
    'mjl_id': _jsonId(muscleJoint?.id),
    'notes': notes,
  };
}

class DynamicVitals {
  DynamicVitals(Map<String, String> values)
    : values = Map.unmodifiable({
        for (final key in keys) key: (values[key] ?? '').trim(),
      });
  static const keys = [
    'systolic',
    'diastolic',
    'pulse',
    'temperature',
    'spo2',
    'respiration',
    'height',
    'weight',
    'bmi',
  ];
  final Map<String, String> values;
  String operator [](String key) => values[key] ?? '';
  bool get isEmpty =>
      keys.where((key) => key != 'bmi').every((key) => this[key].isEmpty);

  static String calculateBmi(String height, String weight) {
    final h = double.tryParse(height.trim()),
        w = double.tryParse(weight.trim());
    if (h == null ||
        w == null ||
        !h.isFinite ||
        !w.isFinite ||
        h <= 0 ||
        w <= 0) {
      return '';
    }
    return (w / ((h / 100) * (h / 100))).toStringAsFixed(1);
  }

  // PrescriptionVitalsBottomSheet.validateVitals: no extra clinical ranges.
  Map<String, String> get errors {
    final result = <String, String>{};
    if (this['systolic'].isNotEmpty && this['diastolic'].isEmpty) {
      result['diastolic'] = 'Enter diastolic pressure';
    }
    if (this['diastolic'].isNotEmpty && this['systolic'].isEmpty) {
      result['systolic'] = 'Enter systolic pressure';
    }
    for (final key in keys.where((key) => key != 'bmi')) {
      if (this[key].isEmpty) continue;
      final number = double.tryParse(this[key]);
      if (key == 'spo2') {
        if (number == null || !number.isFinite || number < 1 || number > 100) {
          result[key] = 'Value must be 1–100';
        }
      } else if (number == null || !number.isFinite || number <= 0) {
        result[key] = 'Enter a valid value';
      }
    }
    return result;
  }

  List<String> get summary {
    String part(String label, String key, String unit) =>
        this[key].isEmpty ? '' : '$label: ${this[key]}$unit';
    final bp =
        this['systolic'].isNotEmpty && this['diastolic'].isNotEmpty
            ? 'BP: ${this['systolic']}/${this['diastolic']} mmHg'
            : '';
    return [
          [bp, part('Pulse', 'pulse', ' bpm')],
          [
            part('Temperature', 'temperature', ' °F'),
            part('SpO₂', 'spo2', '%'),
          ],
          [
            part('Respiratory', 'respiration', '/min'),
            part('BMI', 'bmi', ' kg/m²'),
          ],
          [part('Height', 'height', ' cm'), part('Weight', 'weight', ' kg')],
        ]
        .map((pair) => pair.where((v) => v.isNotEmpty).join('  •  '))
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }
}

/// Clinical data lives in the builder's draft, not in each sheet/tab's state.
/// As in the native ViewModel, editing here never sends a server write.
class DynamicClinicalDraft extends ChangeNotifier {
  final _entries = <DynamicClinicalType, List<DynamicClinicalEntry>>{};
  List<DynamicObjectiveEntry> _objectives = [];
  DynamicVitals? _vitals;
  int _revision = 0;
  int get revision => _revision;
  DynamicVitals? get vitals => _vitals;
  List<DynamicObjectiveEntry> get objectives => List.unmodifiable(_objectives);
  List<DynamicClinicalEntry> entries(DynamicClinicalType type) =>
      List.unmodifiable(_entries[type] ?? const []);
  void _changed() {
    _revision++;
    notifyListeners();
  }

  void saveVitals(DynamicVitals? value) {
    _vitals = value;
    _changed();
  }

  bool saveEntry(
    DynamicClinicalType type,
    DynamicClinicalEntry value, {
    bool updating = false,
  }) {
    final items = [...entries(type)];
    final index = items.indexWhere((item) => item.localId == value.localId);
    if (updating && index < 0 || !updating && index >= 0) return false;
    if (items.any(
      (item) => item.localId != value.localId && item.sameValue(value),
    )) {
      return false;
    }
    if (updating) {
      items[index] = value;
    } else {
      items.add(value);
    }
    _entries[type] = items;
    _changed();
    return true;
  }

  void deleteEntry(DynamicClinicalType type, String id) {
    final items = [...entries(type)]..removeWhere((item) => item.localId == id);
    if (items.length == entries(type).length) return;
    _entries[type] = items;
    _changed();
  }

  bool saveObjective(DynamicObjectiveEntry value, {bool updating = false}) {
    final items = [..._objectives];
    final index = items.indexWhere((item) => item.localId == value.localId);
    if (updating && index < 0 || !updating && index >= 0) return false;
    if (items.any(
      (item) => item.localId != value.localId && item.sameValue(value),
    )) {
      return false;
    }
    if (updating) {
      items[index] = value;
    } else {
      items.add(value);
    }
    _objectives = items;
    _changed();
    return true;
  }

  void deleteObjective(String id) {
    final items = [..._objectives]..removeWhere((item) => item.localId == id);
    if (items.length == _objectives.length) return;
    _objectives = items;
    _changed();
  }

  /// All parsing finishes before publishing, so a bad load keeps the draft.
  void replaceFromData(JsonMap data) {
    final next = <DynamicClinicalType, List<DynamicClinicalEntry>>{};
    for (final type in DynamicClinicalType.values) {
      next[type] = [
        for (final row in nativeArray(data[type.bodyKey]))
          if (dynamicRxText(
            row[type == DynamicClinicalType.importantInfo ? 'text' : 'name'],
          ).isNotEmpty)
            DynamicClinicalEntry(
              masterId: type.hasOptions ? dynamicRxText(row[type.idKey]) : null,
              text: dynamicRxText(
                row[type == DynamicClinicalType.importantInfo
                    ? 'text'
                    : 'name'],
              ),
              notes: type.hasNotes ? dynamicRxText(row['notes']) : '',
            ),
      ];
    }
    DynamicRxOption? option(JsonMap row, String id, String name) {
      final key = dynamicRxText(row[id]), title = dynamicRxText(row[name]);
      return key.isEmpty && title.isEmpty ? null : DynamicRxOption(key, title);
    }

    final objectives = <DynamicObjectiveEntry>[];
    for (final row in nativeArray(data['objective_info'])) {
      final objective = option(row, 'om_id', 'om_name');
      if (objective == null || objective.id.isEmpty || objective.name.isEmpty) {
        continue;
      }
      objectives.add(
        DynamicObjectiveEntry(
          objective: objective,
          value: option(row, 'od_id', 'od_name'),
          muscleJoint: option(row, 'mjl_id', 'mjl_name'),
          notes: dynamicRxText(row['notes']),
        ),
      );
    }
    final rawVitals = data['vitals'];
    final vitalMap = rawVitals == null ? null : nativeObject(rawVitals);
    final vitals =
        vitalMap == null
            ? null
            : DynamicVitals({
              for (final key in DynamicVitals.keys)
                key: dynamicRxText(vitalMap[key]),
            });
    _entries
      ..clear()
      ..addAll(next);
    _objectives = objectives;
    _vitals =
        vitals != null && (!vitals.isEmpty || vitals['bmi'].isNotEmpty)
            ? vitals
            : null;
    _changed();
  }

  JsonMap toBody() => {
    for (final type in DynamicClinicalType.values)
      type.bodyKey: entries(
        type,
      ).map((item) => item.toBody(type)).toList(growable: false),
    'objective_info': _objectives
        .map((item) => item.toBody())
        .toList(growable: false),
  };
}

class DynamicClinicalCatalogue {
  DynamicClinicalCatalogue({
    Map<DynamicClinicalType, List<DynamicRxOption>> clinical = const {},
    List<DynamicRxOption> objectives = const [],
    List<DynamicRxOption> muscleJoints = const [],
  }) : clinical = Map.unmodifiable({
         for (final type in DynamicClinicalType.values)
           type: List<DynamicRxOption>.unmodifiable(clinical[type] ?? const []),
       }),
       objectives = List.unmodifiable(objectives),
       muscleJoints = List.unmodifiable(muscleJoints);
  final Map<DynamicClinicalType, List<DynamicRxOption>> clinical;
  final List<DynamicRxOption> objectives, muscleJoints;
}

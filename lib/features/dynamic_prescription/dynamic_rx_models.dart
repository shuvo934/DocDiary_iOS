import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/failure.dart';
import '../../core/native_json.dart';
import 'dynamic_clinical_models.dart';

String _localId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

int? _bodyId(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  final parsed =
      RegExp(r'^[+-]?[0-9]+$').hasMatch(value) ? int.tryParse(value) : null;
  if (parsed == null) {
    throw const AppFailure(
      'The prescription contains an invalid option identifier.',
      kind: FailureKind.invalidData,
    );
  }
  return parsed;
}

/// MedicineEntryItem and PrescriptionMedicineBottomSheet.java.
class DynamicMedicineEntry {
  DynamicMedicineEntry({
    String? localId,
    required this.medicine,
    required this.dose,
    required this.timing,
    required this.route,
    String duration = '',
    String notes = '',
  }) : localId = localId ?? _localId(),
       duration = duration.trim(),
       notes = notes.trim();
  final String localId, duration, notes;
  final DynamicRxOption medicine, dose, timing, route;

  bool sameValue(DynamicMedicineEntry other) =>
      medicine.id.isNotEmpty && other.medicine.id.isNotEmpty
          ? medicine.id == other.medicine.id
          : medicine.name.toLowerCase() == other.medicine.name.toLowerCase();

  /// Duration is optional in native; a supplied value must fit a positive Java int.
  static String? durationError(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final parsed =
        RegExp(r'^[+-]?[0-9]+$').hasMatch(value) ? int.tryParse(value) : null;
    if (parsed == null || parsed > 2147483647 || parsed < -2147483648) {
      return 'Enter a valid positive duration';
    }
    return parsed <= 0 ? 'Duration must be greater than 0' : null;
  }

  JsonMap toBody() => {
    'medication_id': _bodyId(medicine.id),
    'dose_id': _bodyId(dose.id),
    'timing_id': _bodyId(timing.id),
    'route_id': _bodyId(route.id),
    'duration': duration,
    'notes': notes,
  };
}

/// TherapyEntryItem: only matching IDs are duplicates when both IDs are present.
class DynamicTherapyEntry {
  DynamicTherapyEntry({
    String? localId,
    required this.therapy,
    String notes = '',
  }) : localId = localId ?? _localId(),
       notes = notes.trim();
  final String localId, notes;
  final DynamicRxOption therapy;
  bool sameValue(DynamicTherapyEntry other) =>
      therapy.id.isNotEmpty && other.therapy.id.isNotEmpty
          ? therapy.id == other.therapy.id
          : therapy.name.toLowerCase() == other.therapy.name.toLowerCase();
  JsonMap toBody() => {'tm_id': _bodyId(therapy.id), 'notes': notes};
}

class DynamicTreatmentPlanEntry {
  DynamicTreatmentPlanEntry({
    String? localId,
    String? masterId,
    required String text,
  }) : localId = localId ?? _localId(),
       masterId =
           masterId == null || masterId.trim().isEmpty ? null : masterId.trim(),
       text = text.trim();
  final String localId, text;
  final String? masterId;
  bool sameValue(DynamicTreatmentPlanEntry other) =>
      masterId != null && masterId == other.masterId ||
      text.toLowerCase() == other.text.toLowerCase();
  JsonMap toBody() => {'tpm_id': _bodyId(masterId), 'name': text};
}

/// Immutable parsed snapshot. Parsing completes before an existing draft changes.
class DynamicRxData {
  DynamicRxData({
    List<DynamicMedicineEntry> medicines = const [],
    List<DynamicTherapyEntry> therapies = const [],
    List<DynamicTreatmentPlanEntry> treatmentPlans = const [],
  }) : medicines = List.unmodifiable(medicines),
       therapies = List.unmodifiable(therapies),
       treatmentPlans = List.unmodifiable(treatmentPlans);
  final List<DynamicMedicineEntry> medicines;
  final List<DynamicTherapyEntry> therapies;
  final List<DynamicTreatmentPlanEntry> treatmentPlans;

  factory DynamicRxData.fromData(JsonMap data) {
    DynamicRxOption option(JsonMap row, String id, String name) =>
        DynamicRxOption(dynamicRxText(row[id]), dynamicRxText(row[name]));
    // Native parsing skips incomplete rows, but malformed JSON never clears a draft.
    final medicines = <DynamicMedicineEntry>[];
    for (final row in nativeArray(data['medications'])) {
      final medicine = option(row, 'medication_id', 'medicine_name'),
          dose = option(row, 'dose_id', 'dose_name'),
          timing = option(row, 'timing_id', 'timing_name'),
          route = option(row, 'route_id', 'route_name');
      if (medicine.id.isEmpty ||
          medicine.name.isEmpty ||
          dose.id.isEmpty ||
          timing.id.isEmpty ||
          route.id.isEmpty) {
        continue;
      }
      medicines.add(
        DynamicMedicineEntry(
          medicine: medicine,
          dose: dose,
          timing: timing,
          route: route,
          duration: dynamicRxText(row['duration']),
          notes: dynamicRxText(row['notes']),
        ),
      );
    }
    final therapies = <DynamicTherapyEntry>[];
    for (final row in nativeArray(data['therapies'])) {
      final therapy = option(row, 'tm_id', 'name');
      if (therapy.id.isEmpty || therapy.name.isEmpty) continue;
      therapies.add(
        DynamicTherapyEntry(
          therapy: therapy,
          notes: dynamicRxText(row['notes']),
        ),
      );
    }
    final plans = <DynamicTreatmentPlanEntry>[];
    for (final row in nativeArray(data['treatment_plans'])) {
      final text = dynamicRxText(row['name']);
      if (text.isEmpty) continue;
      plans.add(
        DynamicTreatmentPlanEntry(
          masterId: dynamicRxText(row['tpm_id']),
          text: text,
        ),
      );
    }
    return DynamicRxData(
      medicines: medicines,
      therapies: therapies,
      treatmentPlans: plans,
    );
  }
}

/// Owned by the builder, never by a tab or an edit sheet. No API writes here.
class DynamicRxDraft extends ChangeNotifier {
  List<DynamicMedicineEntry> _medicines = [];
  List<DynamicTherapyEntry> _therapies = [];
  List<DynamicTreatmentPlanEntry> _treatmentPlans = [];
  int _revision = 0;
  int get revision => _revision;
  List<DynamicMedicineEntry> get medicines => List.unmodifiable(_medicines);
  List<DynamicTherapyEntry> get therapies => List.unmodifiable(_therapies);
  List<DynamicTreatmentPlanEntry> get treatmentPlans =>
      List.unmodifiable(_treatmentPlans);

  void _changed() {
    _revision++;
    notifyListeners();
  }

  bool _save<T>(
    List<T> items,
    T value,
    String Function(T) id,
    bool Function(T, T) sameValue,
    bool updating,
  ) {
    final index = items.indexWhere((item) => id(item) == id(value));
    if (updating && index < 0 || !updating && index >= 0) return false;
    if (items.any((item) => id(item) != id(value) && sameValue(item, value))) {
      return false;
    }
    if (updating) {
      items[index] = value;
    } else {
      items.add(value);
    }
    _changed();
    return true;
  }

  void _delete<T>(List<T> items, String target, String Function(T) id) {
    final before = items.length;
    items.removeWhere((item) => id(item) == target);
    if (items.length != before) _changed();
  }

  bool saveMedicine(DynamicMedicineEntry entry, {bool updating = false}) =>
      _save(
        _medicines,
        entry,
        (item) => item.localId,
        (a, b) => a.sameValue(b),
        updating,
      );
  bool saveTherapy(DynamicTherapyEntry entry, {bool updating = false}) => _save(
    _therapies,
    entry,
    (item) => item.localId,
    (a, b) => a.sameValue(b),
    updating,
  );
  bool saveTreatmentPlan(
    DynamicTreatmentPlanEntry entry, {
    bool updating = false,
  }) => _save(
    _treatmentPlans,
    entry,
    (item) => item.localId,
    (a, b) => a.sameValue(b),
    updating,
  );
  void deleteMedicine(String id) =>
      _delete(_medicines, id, (item) => item.localId);
  void deleteTherapy(String id) =>
      _delete(_therapies, id, (item) => item.localId);
  void deleteTreatmentPlan(String id) =>
      _delete(_treatmentPlans, id, (item) => item.localId);

  void replace(DynamicRxData data) {
    _medicines = [...data.medicines];
    _therapies = [...data.therapies];
    _treatmentPlans = [...data.treatmentPlans];
    _changed();
  }

  void replaceFromData(JsonMap data) => replace(DynamicRxData.fromData(data));

  /// Native addRxDataToBody omits medications without med_active permission.
  JsonMap toBody({required bool medicineAllowed}) => {
    'medications': [
      if (medicineAllowed)
        for (final entry in _medicines) entry.toBody(),
    ],
    'therapies': _therapies
        .map((entry) => entry.toBody())
        .toList(growable: false),
    'treatment_plans': _treatmentPlans
        .map((entry) => entry.toBody())
        .toList(growable: false),
  };
}

class DynamicRxCatalogue {
  DynamicRxCatalogue({
    List<DynamicRxOption> medicines = const [],
    List<DynamicRxOption> doses = const [],
    List<DynamicRxOption> timings = const [],
    List<DynamicRxOption> routes = const [],
    List<DynamicRxOption> therapies = const [],
    List<DynamicRxOption> treatmentPlans = const [],
  }) : medicines = List.unmodifiable(medicines),
       doses = List.unmodifiable(doses),
       timings = List.unmodifiable(timings),
       routes = List.unmodifiable(routes),
       therapies = List.unmodifiable(therapies),
       treatmentPlans = List.unmodifiable(treatmentPlans);
  final List<DynamicRxOption> medicines,
      doses,
      timings,
      routes,
      therapies,
      treatmentPlans;
}

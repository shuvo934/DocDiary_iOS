import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/failure.dart';
import '../../core/native_json.dart';
import 'dynamic_clinical_models.dart';

/// AdviceEntryType.java; Reference and Notes are single text entries.
enum DynamicAdviceType {
  advice(
    'Advice',
    'advice',
    'dai_id',
    'dai_advice',
    'getAdvice',
    'No advice added',
  ),
  followUp(
    'Follow-up',
    'followups',
    'dfi_id',
    'dfi_followup_details',
    'getFollowUp',
    'No follow-up added',
  ),
  specialAlert(
    'Special Alert',
    'special_alerts',
    'dsai_id',
    'dsai_special_alert_details',
    'getSpecialAlert',
    'No special alert added',
  ),
  reference('Reference', 'reference', '', '', '', 'No reference added'),
  notes('Notes', 'notes', '', '', '', 'No notes added');

  const DynamicAdviceType(
    this.label,
    this.bodyKey,
    this.idKey,
    this.nameKey,
    this.endpoint,
    this.emptyMessage,
  );
  final String label, bodyKey, idKey, nameKey, endpoint, emptyMessage;
  bool get isSingle => this == reference || this == notes;
  bool get hasOptions => !isSingle;
}

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

class DynamicAdviceEntry {
  DynamicAdviceEntry({String? localId, String? masterId, required String text})
    : localId = localId ?? _localId(),
      masterId =
          masterId == null || masterId.trim().isEmpty ? null : masterId.trim(),
      text = text.trim();
  final String localId, text;
  final String? masterId;
  bool sameValue(DynamicAdviceEntry other) =>
      masterId != null && masterId == other.masterId ||
      text.toLowerCase() == other.text.toLowerCase();

  /// Native Advice deliberately sends text only; Follow-up/Special Alert send IDs.
  JsonMap toBody(DynamicAdviceType type) => {
    if (type == DynamicAdviceType.followUp ||
        type == DynamicAdviceType.specialAlert)
      type.idKey: _bodyId(masterId),
    'text': text,
  };
}

/// Immutable parsed data lets the parent finish parsing before publishing a draft.
class DynamicAdviceData {
  DynamicAdviceData(Map<DynamicAdviceType, List<DynamicAdviceEntry>> values)
    : entries = Map.unmodifiable({
        for (final type in DynamicAdviceType.values)
          type: List<DynamicAdviceEntry>.unmodifiable(values[type] ?? const []),
      });
  final Map<DynamicAdviceType, List<DynamicAdviceEntry>> entries;

  factory DynamicAdviceData.fromData(JsonMap data) {
    final values = <DynamicAdviceType, List<DynamicAdviceEntry>>{};
    for (final type in DynamicAdviceType.values) {
      if (type.isSingle) {
        final text = dynamicRxText(data[type.bodyKey]);
        values[type] = [if (text.isNotEmpty) DynamicAdviceEntry(text: text)];
      } else {
        values[type] = [
          for (final row in nativeArray(data[type.bodyKey]))
            if (dynamicRxText(row['text']).isNotEmpty)
              DynamicAdviceEntry(
                masterId:
                    type == DynamicAdviceType.advice
                        ? null
                        : dynamicRxText(row[type.idKey]),
                text: dynamicRxText(row['text']),
              ),
        ];
      }
    }
    return DynamicAdviceData(values);
  }
}

/// Builder-owned state following PrescriptionBuilderViewModel Advice CRUD.
class DynamicAdviceDraft extends ChangeNotifier {
  final _entries = <DynamicAdviceType, List<DynamicAdviceEntry>>{};
  int _revision = 0;
  int get revision => _revision;
  List<DynamicAdviceEntry> entries(DynamicAdviceType type) =>
      List.unmodifiable(_entries[type] ?? const []);
  String get reference => _single(DynamicAdviceType.reference);
  String get notes => _single(DynamicAdviceType.notes);
  String _single(DynamicAdviceType type) =>
      entries(type).isEmpty ? '' : entries(type).first.text;
  void _changed() {
    _revision++;
    notifyListeners();
  }

  bool saveEntry(
    DynamicAdviceType type,
    DynamicAdviceEntry value, {
    bool updating = false,
  }) {
    final items = [...entries(type)];
    final index = items.indexWhere((entry) => entry.localId == value.localId);
    if (updating && index < 0 || !updating && index >= 0) return false;
    if (!updating && type.isSingle && items.isNotEmpty) return false;
    if (items.any(
      (entry) => entry.localId != value.localId && entry.sameValue(value),
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

  void deleteEntry(DynamicAdviceType type, String id) {
    final items = [...entries(type)]
      ..removeWhere((entry) => entry.localId == id);
    if (items.length == entries(type).length) return;
    _entries[type] = items;
    _changed();
  }

  void replace(DynamicAdviceData data) {
    _entries
      ..clear()
      ..addAll({
        for (final entry in data.entries.entries) entry.key: [...entry.value],
      });
    _changed();
  }

  void replaceFromData(JsonMap data) =>
      replace(DynamicAdviceData.fromData(data));

  /// The three native Advice arrays. Save capture adds Reference/Notes strings
  /// to the same JSON body using the endpoint's scalar keys.
  JsonMap toBody() => {
    for (final type in DynamicAdviceType.values.where((type) => !type.isSingle))
      type.bodyKey: entries(
        type,
      ).map((entry) => entry.toBody(type)).toList(growable: false),
  };
}

class DynamicAdviceCatalogue {
  DynamicAdviceCatalogue({
    Map<DynamicAdviceType, List<DynamicRxOption>> values = const {},
  }) : options = Map.unmodifiable({
         for (final type in DynamicAdviceType.values)
           type: List<DynamicRxOption>.unmodifiable(values[type] ?? const []),
       });
  final Map<DynamicAdviceType, List<DynamicRxOption>> options;
}

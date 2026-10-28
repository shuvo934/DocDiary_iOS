import 'package:flutter/foundation.dart';

import 'dynamic_advice_models.dart';
import 'dynamic_clinical_models.dart';
import 'dynamic_rx_models.dart';

class DynamicReviewRow {
  const DynamicReviewRow(this.label, this.value);
  final String label, value;
}

/// PrescriptionReviewFragment and Builder's confirmation/eligibility observers.
/// Drafts belong to the parent builder; this object only observes them.
class DynamicPrescriptionReview extends ChangeNotifier {
  DynamicPrescriptionReview({
    required this.clinical,
    required this.rx,
    required this.advice,
    bool medicineAllowed = false,
  }) : _medicineAllowed = medicineAllowed {
    clinical.addListener(_changed);
    rx.addListener(_changed);
    advice.addListener(_changed);
  }
  final DynamicClinicalDraft clinical;
  final DynamicRxDraft rx;
  final DynamicAdviceDraft advice;
  bool _medicineAllowed, _confirmed = false;
  bool get medicineAllowed => _medicineAllowed;
  set medicineAllowed(bool value) {
    if (value == _medicineAllowed) return;
    _medicineAllowed = value;
    _changed();
  }

  bool get hasRx =>
      medicineAllowed && rx.medicines.isNotEmpty ||
      rx.therapies.isNotEmpty ||
      rx.treatmentPlans.isNotEmpty;
  bool get confirmed => _confirmed;
  bool get canGenerate => hasRx && confirmed;
  void confirm(bool value) {
    final next = value && hasRx;
    if (next == _confirmed) return;
    _confirmed = next;
    notifyListeners();
  }

  void reset() => confirm(false);
  void _changed() {
    _confirmed = false;
    notifyListeners();
  }

  List<DynamicReviewRow> get clinicalRows {
    final rows = <DynamicReviewRow>[];
    if (clinical.vitals != null && !clinical.vitals!.isEmpty) {
      rows.add(const DynamicReviewRow('Vitals', 'Added'));
    }
    for (final type in const [
      DynamicClinicalType.complain,
      DynamicClinicalType.injury,
      DynamicClinicalType.diagnosis,
      DynamicClinicalType.drugHistory,
      DynamicClinicalType.clinicalFinding,
      DynamicClinicalType.investigation,
      DynamicClinicalType.importantInfo,
    ]) {
      if (clinical.entries(type).isNotEmpty) {
        rows.add(
          DynamicReviewRow(type.label, '${clinical.entries(type).length}'),
        );
      }
      if (type == DynamicClinicalType.diagnosis &&
          clinical.objectives.isNotEmpty) {
        rows.add(
          DynamicReviewRow('Objective Info', '${clinical.objectives.length}'),
        );
      }
    }
    return List.unmodifiable(rows);
  }

  List<DynamicReviewRow> get rxRows => List.unmodifiable([
    if (medicineAllowed && rx.medicines.isNotEmpty)
      DynamicReviewRow('Medicine', '${rx.medicines.length}'),
    if (rx.therapies.isNotEmpty)
      DynamicReviewRow('Therapy', '${rx.therapies.length}'),
    if (rx.treatmentPlans.isNotEmpty)
      DynamicReviewRow('Treatment Plan', '${rx.treatmentPlans.length}'),
  ]);
  List<DynamicReviewRow> get adviceRows => List.unmodifiable([
    for (final type in DynamicAdviceType.values)
      if (advice.entries(type).isNotEmpty)
        DynamicReviewRow(
          type.label,
          type.isSingle ? 'Added' : '${advice.entries(type).length}',
        ),
  ]);
  List<String> get incompleteObjectives => List.unmodifiable({
    for (final entry in clinical.objectives)
      if ((entry.value == null ||
              entry.value!.id.isEmpty ||
              entry.value!.name.isEmpty) &&
          entry.notes.isEmpty)
        entry.objective.name,
  });
  static String badge(int rows) => '$rows ${rows > 1 ? 'items' : 'item'}';
  @override
  void dispose() {
    clinical.removeListener(_changed);
    rx.removeListener(_changed);
    advice.removeListener(_changed);
    super.dispose();
  }
}

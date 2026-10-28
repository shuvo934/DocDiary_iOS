import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../core/failure.dart';
import '../../core/native_json.dart';
import 'dynamic_clinical_models.dart';
import 'dynamic_advice_models.dart';
import 'dynamic_rx_models.dart';
import 'dynamic_prescription_review_models.dart';

enum DynamicTemplateKind {
  disease('Disease Template'),
  treatment('Treatment Template');

  const DynamicTemplateKind(this.label);
  final String label;
}

class DynamicTemplateOption {
  const DynamicTemplateOption(this.id, this.name, [this.description = '']);
  final String id, name, description;
  bool matches(String query) {
    final value = query.trim().toLowerCase();
    return name.trim().toLowerCase().contains(value) ||
        description.trim().toLowerCase().contains(value);
  }
}

/// Builder-owned native template state. Lists survive sheet close/reopen;
/// version guards prevent obsolete loads from changing the current patient draft.
class DynamicTemplateController extends ChangeNotifier {
  DynamicTemplateController({
    required this.review,
    required this.loadDiseaseOptions,
    required this.loadTreatmentOptions,
    required this.loadData,
    this.onFailure,
  });
  final DynamicPrescriptionReview review;
  final Future<List<DynamicTemplateOption>> Function() loadDiseaseOptions;
  final Future<List<DynamicTemplateOption>> Function(String diseaseId)
  loadTreatmentOptions;
  final Future<JsonMap> Function(DynamicTemplateKind kind, String id) loadData;
  final void Function(Object failure)? onFailure;
  List<DynamicTemplateOption> diseases = const [], treatments = const [];
  String diseaseId = '', diseaseName = '', treatmentId = '', treatmentName = '';
  String diseaseError = '', treatmentError = '';
  bool diseaseLoading = false, treatmentLoading = false;
  bool diseaseApplyError = false, treatmentApplyError = false;
  DynamicTemplateKind? applyingKind;
  bool _diseaseLoaded = false, _treatmentLoaded = false, _disposed = false;
  String _treatmentDisease = '';
  int _diseaseVersion = 0, _treatmentVersion = 0, _applyVersion = 0;
  bool get applying => applyingKind != null;
  JsonMap get metadata => {
    'td_id': diseaseId,
    'td_name': diseaseName,
    'tt_id': treatmentId,
    'tt_name': treatmentName,
  };
  bool get hasRxData =>
      review.rx.medicines.isNotEmpty ||
      review.rx.therapies.isNotEmpty ||
      review.rx.treatmentPlans.isNotEmpty;
  bool get hasDiseaseData =>
      review.clinical.objectives.isNotEmpty ||
      DynamicClinicalType.values.any(
        (type) => review.clinical.entries(type).isNotEmpty,
      ) ||
      DynamicAdviceType.values
          .where((type) => !type.isSingle)
          .any((type) => review.advice.entries(type).isNotEmpty) ||
      hasRxData;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _message(Object failure) =>
      failure is AppFailure
          ? failure.message
          : 'Server Problem or Internet Not Connected';

  void restore(JsonMap data) {
    cancelPending();
    diseases = const [];
    treatments = const [];
    _diseaseLoaded = false;
    _treatmentLoaded = false;
    _treatmentDisease = '';
    diseaseError = '';
    treatmentError = '';
    diseaseApplyError = false;
    treatmentApplyError = false;
    diseaseId = dynamicRxText(data['td_id']);
    diseaseName = dynamicRxText(data['td_name']);
    treatmentId = dynamicRxText(data['tt_id']);
    treatmentName = dynamicRxText(data['tt_name']);
    _notify();
  }

  void cancelPending() {
    ++_diseaseVersion;
    ++_treatmentVersion;
    ++_applyVersion;
    diseaseLoading = false;
    treatmentLoading = false;
    applyingKind = null;
    _notify();
  }

  Future<void> loadDiseases({bool retry = false}) async {
    if (_disposed || diseaseLoading || _diseaseLoaded && !retry) return;
    final version = ++_diseaseVersion;
    diseaseLoading = true;
    diseaseError = '';
    diseaseApplyError = false;
    if (retry) {
      diseases = const [];
      _diseaseLoaded = false;
    }
    _notify();
    try {
      final values = await loadDiseaseOptions();
      if (_disposed || version != _diseaseVersion) return;
      diseases = List.unmodifiable(values);
      _diseaseLoaded = true;
    } catch (failure) {
      if (_disposed || version != _diseaseVersion) return;
      if (failure is! ObsoleteRequest) {
        diseaseError = _message(failure);
        onFailure?.call(failure);
      }
    } finally {
      if (!_disposed && version == _diseaseVersion) {
        diseaseLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadTreatments({bool retry = false}) async {
    final id = diseaseId;
    if (_disposed ||
        id.isEmpty ||
        treatmentLoading && _treatmentDisease == id ||
        _treatmentLoaded && _treatmentDisease == id && !retry) {
      return;
    }
    final version = ++_treatmentVersion;
    _treatmentDisease = id;
    _treatmentLoaded = false;
    treatments = const [];
    treatmentLoading = true;
    treatmentError = '';
    treatmentApplyError = false;
    _notify();
    try {
      final values = await loadTreatmentOptions(id);
      if (_disposed || version != _treatmentVersion || diseaseId != id) return;
      treatments = List.unmodifiable(values);
      _treatmentLoaded = true;
    } catch (failure) {
      if (_disposed || version != _treatmentVersion || diseaseId != id) return;
      if (failure is! ObsoleteRequest) {
        treatmentError = _message(failure);
        onFailure?.call(failure);
      }
    } finally {
      if (!_disposed && version == _treatmentVersion) {
        treatmentLoading = false;
        _notify();
      }
    }
  }

  void clearApplyError(DynamicTemplateKind kind) {
    if (kind == DynamicTemplateKind.disease) {
      diseaseError = '';
      diseaseApplyError = false;
    } else {
      treatmentError = '';
      treatmentApplyError = false;
    }
    _notify();
  }

  Future<bool> apply(
    DynamicTemplateKind kind,
    DynamicTemplateOption option,
  ) async {
    if (_disposed || applying) return false;
    final disease = kind == DynamicTemplateKind.disease;
    if (option.id.trim().isEmpty) {
      if (disease) {
        diseaseError = 'Disease Template information not found';
        diseaseApplyError = true;
      } else {
        treatmentError = 'Treatment Template information not found';
        treatmentApplyError = true;
      }
      _notify();
      return false;
    }
    if (!disease && diseaseId.isEmpty) return false;
    final parentDisease = diseaseId, version = ++_applyVersion;
    applyingKind = kind;
    if (disease) {
      diseaseError = '';
      diseaseApplyError = false;
    } else {
      treatmentError = '';
      treatmentApplyError = false;
    }
    _notify();
    try {
      final data = await loadData(kind, option.id);
      if (_disposed ||
          version != _applyVersion ||
          !disease && parentDisease != diseaseId) {
        return false;
      }
      // Complete every parser and body-ID validation before publishing any part.
      if (disease) {
        final parsed = DynamicClinicalData.fromData({
          for (final type in DynamicClinicalType.values)
            type.bodyKey: data[type.bodyKey],
          'objective_info': data['objective_info'],
        });
        final clinical = DynamicClinicalData(
          entries: parsed.entries,
          objectives: parsed.objectives,
          vitals: review.clinical.vitals,
        );
        final parsedAdvice = DynamicAdviceData.fromData({
          for (final type in DynamicAdviceType.values.where(
            (type) => !type.isSingle,
          ))
            type.bodyKey: data[type.bodyKey],
        });
        final advice = DynamicAdviceData({
          ...parsedAdvice.entries,
          for (final type in DynamicAdviceType.values.where(
            (type) => type.isSingle,
          ))
            type: review.advice.entries(type),
        });
        final staging = DynamicClinicalDraft();
        try {
          staging.replace(clinical);
          staging.toBody();
        } finally {
          staging.dispose();
        }
        for (final type in DynamicAdviceType.values.where(
          (type) => !type.isSingle,
        )) {
          for (final entry in advice.entries[type]!) {
            entry.toBody(type);
          }
        }
        review.clinical.replace(clinical);
        review.advice.replace(advice);
        review.rx.replace(DynamicRxData.fromData(const {}));
        diseaseId = option.id;
        diseaseName = option.name;
        treatmentId = '';
        treatmentName = '';
        ++_treatmentVersion;
        _treatmentLoaded = false;
        _treatmentDisease = '';
        treatments = const [];
        treatmentLoading = false;
        treatmentError = '';
        treatmentApplyError = false;
      } else {
        final rx = DynamicRxData.fromData(data);
        for (final item in rx.medicines) {
          item.toBody();
        }
        for (final item in rx.therapies) {
          item.toBody();
        }
        for (final item in rx.treatmentPlans) {
          item.toBody();
        }
        review.rx.replace(rx);
        treatmentId = option.id;
        treatmentName = option.name;
      }
      review.reset();
      _notify();
      if (disease) unawaited(loadTreatments());
      return true;
    } catch (failure) {
      if (_disposed || version != _applyVersion) return false;
      if (failure is! ObsoleteRequest) {
        if (disease) {
          diseaseError = _message(failure);
          diseaseApplyError = true;
        } else {
          treatmentError = _message(failure);
          treatmentApplyError = true;
        }
        onFailure?.call(failure);
      }
      return false;
    } finally {
      if (!_disposed && version == _applyVersion) {
        applyingKind = null;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_diseaseVersion;
    ++_treatmentVersion;
    ++_applyVersion;
    super.dispose();
  }
}

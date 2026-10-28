import 'package:flutter/foundation.dart';

import '../../core/failure.dart';
import '../../core/native_json.dart';
import 'dynamic_advice_models.dart';
import 'dynamic_clinical_models.dart';
import 'dynamic_prescription_review_models.dart';
import 'dynamic_rx_models.dart';
import 'dynamic_template_models.dart';

/// PrescriptionHistoryItem and PrescriptionHistoryAdapter's native text rules.
class DynamicPrescriptionHistoryItem {
  DynamicPrescriptionHistoryItem.fromData(JsonMap row)
    : rvmId = dynamicRxText(row['rvm_id']),
      code = dynamicRxText(row['rvm_code']),
      prescriptionDate = dynamicRxText(row['presc_date']),
      appointmentDate = dynamicRxText(row['app_date']),
      scheduleTime = dynamicRxText(row['sch_time']),
      departmentName = dynamicRxText(row['depts_name']),
      serviceName = dynamicRxText(row['pfn_fee_name']),
      admissionId = dynamicRxText(row['rvm_ad_id']),
      doctorId = dynamicRxText(row['rvm_doc_id']),
      doctorName = dynamicRxText(row['doc_name']),
      designationName = dynamicRxText(row['desig_name']),
      lastUpdatedTime = dynamicRxText(row['last_updated_time']),
      prescriptionType = _legacy(row['presc_type']),
      patientType = _legacy(row['pat_type']);
  final String rvmId,
      code,
      prescriptionDate,
      appointmentDate,
      scheduleTime,
      departmentName,
      serviceName,
      admissionId,
      doctorId,
      doctorName,
      designationName,
      lastUpdatedTime,
      prescriptionType,
      patientType;
  static String _legacy(Object? value) {
    final text = dynamicRxText(value);
    return text.toLowerCase() == 'no data found' ? '' : text;
  }

  String get appointmentText =>
      _joined('Appointment: ', [appointmentDate, scheduleTime]);
  String get createdByText =>
      _joined('Created By: ', [doctorName, designationName]);
  String get typeText => _joined('', [prescriptionType, patientType]);
  String get updatedText =>
      lastUpdatedTime.isEmpty ? '' : 'Last Updated: $lastUpdatedTime';
  static String _joined(String prefix, List<String> values) {
    final text = values.where((value) => value.isNotEmpty).join(' • ');
    return text.isEmpty ? '' : '$prefix$text';
  }
}

/// Builder-owned state. A History sheet always starts with a fresh list and
/// selection. Loading copies content; it never adopts the source's identity.
class DynamicHistoryController extends ChangeNotifier {
  DynamicHistoryController({
    required this.review,
    required this.templates,
    required this.loadOptions,
    required this.loadData,
    this.onFailure,
  });
  final DynamicPrescriptionReview review;
  final DynamicTemplateController templates;
  final Future<List<DynamicPrescriptionHistoryItem>> Function() loadOptions;
  final Future<JsonMap> Function(String sourceRvmId) loadData;
  final void Function(Object failure)? onFailure;
  List<DynamicPrescriptionHistoryItem> items = const [];
  DynamicPrescriptionHistoryItem? selected;
  String listError = '', applyError = '';
  bool loading = false, applying = false, _disposed = false;
  int _listVersion = 0, _applyVersion = 0;
  String get countText =>
      items.isEmpty
          ? ''
          : items.length == 1
          ? '1 prescription found'
          : '${items.length} prescriptions found';
  bool get canLoad => !loading && !applying && selected != null;
  bool get hasData =>
      review.clinical.vitals != null && !review.clinical.vitals!.isEmpty ||
      review.clinical.objectives.isNotEmpty ||
      DynamicClinicalType.values.any(
        (type) => review.clinical.entries(type).isNotEmpty,
      ) ||
      DynamicAdviceType.values.any(
        (type) => review.advice.entries(type).isNotEmpty,
      ) ||
      review.rx.medicines.isNotEmpty ||
      review.rx.therapies.isNotEmpty ||
      review.rx.treatmentPlans.isNotEmpty ||
      templates.diseaseId.isNotEmpty ||
      templates.treatmentId.isNotEmpty;
  String _message(Object failure) =>
      failure is AppFailure
          ? failure.message
          : 'Server Problem or Internet Not Connected';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_disposed || applying) return;
    final version = ++_listVersion;
    items = const [];
    selected = null;
    listError = '';
    applyError = '';
    loading = true;
    _notify();
    try {
      final result = await loadOptions();
      if (_disposed || version != _listVersion) return;
      items = List.unmodifiable(result);
    } catch (failure) {
      if (_disposed || version != _listVersion) return;
      if (failure is! ObsoleteRequest) {
        listError = _message(failure);
        onFailure?.call(failure);
      }
    } finally {
      if (!_disposed && version == _listVersion) {
        loading = false;
        _notify();
      }
    }
  }

  void select(DynamicPrescriptionHistoryItem item) {
    if (_disposed || loading || applying || !items.contains(item)) return;
    selected = item;
    _notify();
  }

  Future<bool> applySelected() async {
    if (_disposed || !canLoad) return false;
    final sourceId = selected!.rvmId, version = ++_applyVersion;
    applying = true;
    applyError = '';
    _notify();
    try {
      final data = await loadData(sourceId);
      if (_disposed || version != _applyVersion) return false;
      final id = dynamicRxText(data['rvm_id']);
      if (id.isEmpty) {
        throw const AppFailure('Previous prescription ID not found');
      }
      if (id != sourceId) {
        throw const AppFailure(
          'Loaded prescription does not match the selected history',
        );
      }
      // Parse and validate every section before publishing any shared draft.
      final clinical = DynamicClinicalData.fromData(data);
      final rx = DynamicRxData.fromData(data);
      final advice = DynamicAdviceData.fromData(data);
      final staging = DynamicClinicalDraft();
      try {
        staging.replace(clinical);
        staging.toBody();
      } finally {
        staging.dispose();
      }
      for (final item in rx.medicines) {
        item.toBody();
      }
      for (final item in rx.therapies) {
        item.toBody();
      }
      for (final item in rx.treatmentPlans) {
        item.toBody();
      }
      for (final type in DynamicAdviceType.values.where(
        (type) => !type.isSingle,
      )) {
        for (final entry in advice.entries[type]!) {
          entry.toBody(type);
        }
      }
      review.clinical.replace(clinical);
      review.rx.replace(rx);
      review.advice.replace(advice);
      templates.clearAfterHistory();
      review.reset();
      return true;
    } catch (failure) {
      if (_disposed || version != _applyVersion) return false;
      if (failure is! ObsoleteRequest) {
        applyError = _message(failure);
        onFailure?.call(failure);
      }
      return false;
    } finally {
      if (!_disposed && version == _applyVersion) {
        applying = false;
        _notify();
      }
    }
  }

  void close() {
    if (_disposed) return;
    ++_listVersion;
    ++_applyVersion;
    items = const [];
    selected = null;
    loading = false;
    applying = false;
    listError = '';
    applyError = '';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_listVersion;
    ++_applyVersion;
    super.dispose();
  }
}

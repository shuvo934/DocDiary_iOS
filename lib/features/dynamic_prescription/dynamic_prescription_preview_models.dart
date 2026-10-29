import 'dart:convert';
import '../../core/failure.dart';
import '../../core/native_json.dart';

// Field names, empty-row rules and defaults mirror PrescriptionPreviewData.java.
String _text(JsonMap row, String key) {
  final value = row[key];
  return value == null
      ? ''
      : (value is Map || value is List ? jsonEncode(value) : value.toString())
          .trim();
}

JsonMap _object(Object? value) => value is JsonMap ? value : const {};
Iterable<JsonMap> _rows(Object? value) =>
    value is List ? value.whereType<JsonMap>() : const <JsonMap>[];

class DynamicPrescriptionPreviewData {
  DynamicPrescriptionPreviewData.fromResponse(JsonMap response) {
    final status = num.tryParse(_text(response, 'status'));
    if (status == null || !status.isFinite || status.toInt() != 200) {
      final message = _text(response, 'message');
      throw AppFailure(
        message.isEmpty ? 'Prescription preview data not found' : message,
      );
    }
    if (response['data'] is! JsonMap) {
      throw const AppFailure('Prescription preview information not found');
    }
    final data = response['data'] as JsonMap;
    rvmId = _text(data, 'rvm_id');
    rvmCode = _text(data, 'rvm_code');
    prescriptionDate = _text(data, 'presc_date');
    reference = _text(data, 'reference');
    notes = _text(data, 'notes');
    prescriptionType = _text(data, 'presc_type');
    patientType = _text(data, 'patient_type');
    facility = DynamicPreviewFacility(_object(data['facility']));
    provider = DynamicPreviewProvider(_object(data['provider']));
    patient = DynamicPreviewPatient(_object(data['patient']));
    vitals = DynamicPreviewVitals(_object(data['vitals']));
    complaints = List.unmodifiable([
      for (final row in _rows(data['complaints']))
        if (_text(row, 'name').isNotEmpty)
          DynamicPreviewSectionItem(_text(row, 'name'), ''),
    ]);
    injuries = List.unmodifiable([
      for (final row in _rows(data['injuries']))
        if (_text(row, 'name').isNotEmpty)
          DynamicPreviewSectionItem(_text(row, 'name'), ''),
    ]);
    diagnosis = List.unmodifiable([
      for (final row in _rows(data['diagnosis']))
        if (_text(row, 'name').isNotEmpty)
          DynamicPreviewSectionItem(_text(row, 'name'), ''),
    ]);
    drugHistory = List.unmodifiable([
      for (final row in _rows(data['drug_history']))
        if (_text(row, 'name').isNotEmpty)
          DynamicPreviewSectionItem(_text(row, 'name'), ''),
    ]);
    clinicalFindings = List.unmodifiable([
      for (final row in _rows(data['clinical_findings']))
        if (_text(row, 'name').isNotEmpty)
          DynamicPreviewSectionItem(_text(row, 'name'), ''),
    ]);
    investigations = List.unmodifiable([
      for (final row in _rows(data['investigations']))
        if (_text(row, 'name').isNotEmpty)
          DynamicPreviewSectionItem(_text(row, 'name'), _text(row, 'notes')),
    ]);
    importantInfo = List.unmodifiable([
      for (final row in _rows(data['important_info']))
        if (_text(row, 'text').isNotEmpty)
          DynamicPreviewSectionItem(_text(row, 'text'), ''),
    ]);
    therapies = List.unmodifiable([
      for (final row in _rows(data['therapies']))
        if (_text(row, 'name').isNotEmpty)
          DynamicPreviewSectionItem(_text(row, 'name'), _text(row, 'notes')),
    ]);
    treatmentPlans = List.unmodifiable([
      for (final row in _rows(data['treatment_plans']))
        if (_text(row, 'name').isNotEmpty)
          DynamicPreviewSectionItem(_text(row, 'name'), ''),
    ]);
    advice = List.unmodifiable([
      for (final row in _rows(data['advice']))
        if (_text(row, 'text').isNotEmpty)
          DynamicPreviewSectionItem(_text(row, 'text'), ''),
    ]);
    followups = List.unmodifiable([
      for (final row in _rows(data['followups']))
        if (_text(row, 'text').isNotEmpty)
          DynamicPreviewSectionItem(_text(row, 'text'), ''),
    ]);
    specialAlerts = List.unmodifiable([
      for (final row in _rows(data['special_alerts']))
        if (_text(row, 'text').isNotEmpty)
          DynamicPreviewSectionItem(_text(row, 'text'), ''),
    ]);
    objectiveInfo = List.unmodifiable([
      for (final row in _rows(data['objective_info']))
        if ([
          'om_name',
          'od_name',
          'mjl_name',
          'notes',
        ].any((key) => _text(row, key).isNotEmpty))
          DynamicPreviewObjectiveItem(
            _text(row, 'om_name'),
            _text(row, 'od_name'),
            _text(row, 'mjl_name'),
            _text(row, 'notes'),
          ),
    ]);
    medications = List.unmodifiable([
      for (final row in _rows(data['medications']))
        if (_text(row, 'medicine_name').isNotEmpty)
          DynamicPreviewMedicationItem(
            _text(row, 'medicine_name'),
            _text(row, 'dose_name'),
            _text(row, 'timing_name'),
            _text(row, 'route_name'),
            _text(row, 'duration'),
            _text(row, 'notes'),
          ),
    ]);
  }
  late final String rvmId;
  late final String rvmCode;
  late final String prescriptionDate;
  late final String reference;
  late final String notes;
  late final String prescriptionType;
  late final String patientType;
  late final DynamicPreviewFacility facility;
  late final DynamicPreviewProvider provider;
  late final DynamicPreviewPatient patient;
  late final DynamicPreviewVitals vitals;
  late final List<DynamicPreviewSectionItem> complaints;
  late final List<DynamicPreviewSectionItem> injuries;
  late final List<DynamicPreviewSectionItem> diagnosis;
  late final List<DynamicPreviewSectionItem> drugHistory;
  late final List<DynamicPreviewSectionItem> clinicalFindings;
  late final List<DynamicPreviewSectionItem> investigations;
  late final List<DynamicPreviewSectionItem> importantInfo;
  late final List<DynamicPreviewSectionItem> therapies;
  late final List<DynamicPreviewSectionItem> treatmentPlans;
  late final List<DynamicPreviewSectionItem> advice;
  late final List<DynamicPreviewSectionItem> followups;
  late final List<DynamicPreviewSectionItem> specialAlerts;
  late final List<DynamicPreviewObjectiveItem> objectiveInfo;
  late final List<DynamicPreviewMedicationItem> medications;
  String get documentName {
    final identity = (rvmCode.isEmpty ? rvmId : rvmCode).trim().replaceAll(
      RegExp('[^A-Za-z0-9_-]+'),
      '_',
    );
    return 'Prescription_${identity.isEmpty ? 'Prescription' : identity}';
  }
}

class DynamicPreviewFacility {
  DynamicPreviewFacility(JsonMap data)
    : name = _text(data, 'cim_name'),
      details = _text(data, 'cim_details'),
      phone = _text(data, 'cim_phone'),
      cell = _text(data, 'cim_cell'),
      email = _text(data, 'cim_email'),
      website = _text(data, 'cim_web'),
      primaryColor = _text(data, 'primary_color'),
      secondaryColor = _text(data, 'secondary_color'),
      logoBase64 = _text(data, 'cim_logo');
  final String name;
  final String details;
  final String phone;
  final String cell;
  final String email;
  final String website;
  final String primaryColor;
  final String secondaryColor;
  final String logoBase64;
}

class DynamicPreviewProvider {
  DynamicPreviewProvider(JsonMap data)
    : doctorName = _text(data, 'doc_name'),
      doctorCode = _text(data, 'doc_code'),
      designation = _text(data, 'designation'),
      unit = _text(data, 'unit'),
      department = _text(data, 'department');
  final String doctorName;
  final String doctorCode;
  final String designation;
  final String unit;
  final String department;
}

class DynamicPreviewPatient {
  DynamicPreviewPatient(JsonMap data)
    : patientName = _text(data, 'pat_name'),
      patientCode = _text(data, 'sub_code'),
      gender = _text(data, 'gender'),
      age = _text(data, 'age'),
      category = _text(data, 'category'),
      reference = _text(data, 'reference');
  final String patientName;
  final String patientCode;
  final String gender;
  final String age;
  final String category;
  final String reference;
}

class DynamicPreviewVitals {
  DynamicPreviewVitals(JsonMap data)
    : weight = _text(data, 'weight'),
      height = _text(data, 'height'),
      systolic = _text(data, 'systolic'),
      diastolic = _text(data, 'diastolic'),
      pulse = _text(data, 'pulse'),
      respiration = _text(data, 'respiration'),
      temperature = _text(data, 'temperature'),
      spo2 = _text(data, 'spo2'),
      bmi = _text(data, 'bmi');
  final String weight;
  final String height;
  final String systolic;
  final String diastolic;
  final String pulse;
  final String respiration;
  final String temperature;
  final String spo2;
  final String bmi;
  bool get isEmpty => [
    weight,
    height,
    systolic,
    diastolic,
    pulse,
    respiration,
    temperature,
    spo2,
    bmi,
  ].every((value) => value.isEmpty);
}

class DynamicPreviewSectionItem {
  const DynamicPreviewSectionItem(this.text, this.notes);
  final String text;
  final String notes;
  bool get hasNotes => notes.isNotEmpty;
}

class DynamicPreviewObjectiveItem {
  const DynamicPreviewObjectiveItem(
    this.objectiveName,
    this.objectiveValue,
    this.muscleJointName,
    this.notes,
  );
  final String objectiveName;
  final String objectiveValue;
  final String muscleJointName;
  final String notes;
  bool get hasObjectiveValue => objectiveValue.isNotEmpty;
  bool get hasMuscleJoint => muscleJointName.isNotEmpty;
  bool get hasNotes => notes.isNotEmpty;
}

class DynamicPreviewMedicationItem {
  const DynamicPreviewMedicationItem(
    this.medicineName,
    this.doseName,
    this.timingName,
    this.routeName,
    this.duration,
    this.notes,
  );
  final String medicineName;
  final String doseName;
  final String timingName;
  final String routeName;
  final String duration;
  final String notes;
  bool get hasDuration => duration.isNotEmpty;
  bool get hasNotes => notes.isNotEmpty;
}

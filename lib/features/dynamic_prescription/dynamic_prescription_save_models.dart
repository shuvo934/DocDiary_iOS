import 'dart:convert';
import 'dart:typed_data';

import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../auth/profile_repository.dart';
import 'dynamic_clinical_models.dart';
import 'dynamic_prescription_review_models.dart';
import 'dynamic_prescription_seed.dart';

String _header(String value) =>
    value.trim().replaceAll('\r', ' ').replaceAll('\n', ' ');

/// Exact native insertPrescription/updatePrescription JSON and custom headers.
/// Capturing strings/UTF-8 bytes prevents an in-flight edit from changing a write.
class DynamicPrescriptionSaveRequest {
  DynamicPrescriptionSaveRequest._({
    required this.bodyJson,
    required Map<String, String> headers,
    required this.rvmId,
    required this.doctorId,
    required this.patientHistoryId,
    required this.patientId,
    required this.appointmentId,
  }) : headers = Map.unmodifiable(headers);
  final String bodyJson,
      rvmId,
      doctorId,
      patientHistoryId,
      patientId,
      appointmentId;
  final Map<String, String> headers;
  bool get updating => rvmId.isNotEmpty;
  String get endpoint => updating ? 'updatePrescription' : 'insertPrescription';
  Uint8List get body => Uint8List.fromList(utf8.encode(bodyJson));
  static const contentType = 'application/json; charset=utf-8';

  factory DynamicPrescriptionSaveRequest.capture({
    required DynamicPrescriptionSeed seed,
    required AccountProfile profile,
    required DynamicPrescriptionReview review,
    JsonMap data = const {},
  }) {
    final id = dynamicRxText(data['rvm_id']);
    if (!seed.valid ||
        profile.doctorId != seed.ownerDoctorId ||
        seed.existing && id.isEmpty) {
      throw const AppFailure(
        'Required prescription, patient or visit information is missing.',
        kind: FailureKind.invalidData,
      );
    }
    if (review.medicineAllowed != (profile.value('med_active') == '1')) {
      throw const AppFailure(
        'Please review and confirm the prescription',
        kind: FailureKind.denied,
      );
    }
    if (!review.hasRx) {
      throw const AppFailure(
        'Add at least one Rx item before generating',
        kind: FailureKind.invalidData,
      );
    }
    if (review.incompleteObjectives.isNotEmpty) {
      throw const AppFailure(
        'Please select a value or enter notes for the Objective Info.',
        kind: FailureKind.invalidData,
      );
    }
    if (!review.confirmed) {
      throw const AppFailure(
        'Please review and confirm the prescription',
        kind: FailureKind.invalidData,
      );
    }
    final clinical = review.clinical,
        advice = review.advice,
        vitals = clinical.vitals;
    final headers = <String, String>{
      if (id.isNotEmpty) 'P_RVM_ID': id,
      'P_DOC_ID': profile.doctorId,
      'P_PH_ID': seed.patientHistoryId,
      'P_PAT_ID': seed.patientId,
      'P_AD_ID': seed.appointmentId,
      'P_TD_ID': dynamicRxText(data['td_id']),
      'P_TT_ID': dynamicRxText(data['tt_id']),
      if (id.isEmpty) 'P_PRESCRIPTION_TYPE': seed.prescriptionType,
      'P_INSERT_TYPE': '4',
      if (id.isEmpty) 'P_PATIENT_TYPE': seed.patientType,
      'P_WEIGHT': vitals?['weight'] ?? '',
      'P_HEIGHT': vitals?['height'] ?? '',
      'P_SYSTOLIC': vitals?['systolic'] ?? '',
      'P_DIASTOLIC': vitals?['diastolic'] ?? '',
      'P_PULSE': vitals?['pulse'] ?? '',
      'P_RESPIRATION': vitals?['respiration'] ?? '',
      'P_TEMPERATURE': vitals?['temperature'] ?? '',
      'P_SPO': vitals?['spo2'] ?? '',
      'P_BMI': vitals?['bmi'] ?? '',
    };
    return DynamicPrescriptionSaveRequest._(
      bodyJson: jsonEncode({
        ...clinical.toBody(),
        ...review.rx.toBody(medicineAllowed: review.medicineAllowed),
        ...advice.toBody(),
        'reference': advice.reference,
        'prescription_notes': advice.notes,
      }),
      headers: {
        for (final entry in headers.entries) entry.key: _header(entry.value),
      },
      rvmId: id,
      doctorId: profile.doctorId,
      patientHistoryId: seed.patientHistoryId,
      patientId: seed.patientId,
      appointmentId: seed.appointmentId,
    );
  }
}

class DynamicPrescriptionSaveReceipt {
  const DynamicPrescriptionSaveReceipt({
    required this.rvmId,
    required this.code,
    required this.message,
    required this.updating,
  });
  final String rvmId, code, message;
  final bool updating;
  factory DynamicPrescriptionSaveReceipt.fromResponse(
    JsonMap response,
    DynamicPrescriptionSaveRequest request,
  ) {
    final message = dynamicRxText(response['string_out']);
    if (RegExp(
          r'\b(?:ORA|PLS)-\d{5}\b',
          caseSensitive: false,
        ).hasMatch(message) ||
        response.containsKey('status') &&
            !const ['200', '201'].contains(dynamicRxText(response['status']))) {
      throw AppFailure(
        message.isEmpty
            ? 'The server could not save the prescription.'
            : message,
      );
    }
    final id =
        request.updating
            ? request.rvmId
            : dynamicRxText(response['out_rvm_id']);
    if (!response.containsKey('string_out') || id.isEmpty) {
      throw const AppFailure(
        'The server did not return a complete save confirmation.',
        kind: FailureKind.invalidData,
      );
    }
    return DynamicPrescriptionSaveReceipt(
      rvmId: id,
      code: dynamicRxText(response['out_rvm_code']),
      message:
          message.isEmpty
              ? request.updating
                  ? 'Prescription updated successfully.'
                  : 'Prescription created successfully.'
              : message,
      updating: request.updating,
    );
  }
}

/// A dispatched write can reach the server even when its response is lost.
class DynamicPrescriptionSaveFailure extends AppFailure {
  const DynamicPrescriptionSaveFailure(super.message, {super.kind});
}

import '../../core/native_dates.dart';
import 'dynamic_clinical_models.dart';

/// PrescriptionBuilder.setupDetails: scheduled extras or a new Walk-in patient.
class DynamicPrescriptionSeed {
  factory DynamicPrescriptionSeed.fromExtras(
    Map<String, String> extras, {
    required String ownerDoctorId,
    DateTime? now,
  }) {
    final type = dynamicRxText(extras['P_PAT_TYPE']);
    final date = dynamicRxText(extras['ADM_DATE']);
    return DynamicPrescriptionSeed._(
      ownerDoctorId: ownerDoctorId,
      patientHistoryId: dynamicRxText(extras['P_PH_ID']),
      patientId: dynamicRxText(extras['P_PAT_ID']),
      appointmentId: dynamicRxText(extras['P_AD_ID']),
      name: dynamicRxText(extras['PAT_NAME']),
      code: dynamicRxText(extras['PAT_CODE']),
      gender: dynamicRxText(extras['PAT_GENDER']),
      age: dynamicRxText(extras['P_AGE']),
      visitDate:
          date.isEmpty && type == '2'
              ? oracleDate(now ?? DateTime.now())
              : date,
      patientType: type,
      prescriptionType:
          type == '2' && dynamicRxText(extras['P_PRESCRIPTION_TYPE']) != '1'
              ? '2'
              : '1',
      existing:
          dynamicRxText(extras['IS_CREATED']).isNotEmpty &&
          dynamicRxText(extras['IS_CREATED']) != '0',
    );
  }
  const DynamicPrescriptionSeed._({
    required this.ownerDoctorId,
    required this.patientHistoryId,
    required this.patientId,
    required this.appointmentId,
    required this.name,
    required this.code,
    required this.gender,
    required this.age,
    required this.visitDate,
    required this.patientType,
    required this.prescriptionType,
    required this.existing,
  });
  final String ownerDoctorId,
      patientHistoryId,
      patientId,
      appointmentId,
      name,
      code,
      gender,
      age,
      visitDate,
      patientType,
      prescriptionType;
  final bool existing;
  bool get isWalkIn => patientType == '2';
  bool get hasPatient => patientHistoryId.isNotEmpty && patientId.isNotEmpty;
  bool get needsPatient => isWalkIn && !existing && !hasPatient;
  bool get valid =>
      ownerDoctorId.isNotEmpty &&
      hasPatient &&
      visitDate.isNotEmpty &&
      (patientType == '1' && appointmentId.isNotEmpty ||
          isWalkIn && appointmentId.isEmpty);
  String get details =>
      [gender, age].where((part) => part.isNotEmpty).join(' • ');
  bool editableOn(DateTime now) {
    if (!valid) return false;
    if (isWalkIn) return true;
    try {
      return parseOracleDate(visitDate) == dateOnly(now);
    } catch (_) {
      return false;
    }
  }

  DynamicPrescriptionSeed withPatient({
    required String patientId,
    required String patientHistoryId,
    required String name,
    required String code,
    required String gender,
    required String age,
    required String prescriptionType,
  }) => DynamicPrescriptionSeed.fromExtras({
    'P_PAT_TYPE': '2',
    'IS_CREATED': '0',
    'P_PH_ID': patientHistoryId,
    'P_PAT_ID': patientId,
    'PAT_NAME': name,
    'PAT_CODE': code,
    'PAT_GENDER': gender,
    'P_AGE': age,
    'ADM_DATE': visitDate,
    'P_PRESCRIPTION_TYPE': prescriptionType,
  }, ownerDoctorId: ownerDoctorId);
}

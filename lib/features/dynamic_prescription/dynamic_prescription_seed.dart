import '../../core/native_dates.dart';
import 'dynamic_clinical_models.dart';

/// PrescriptionBuilder.setupDetails and TimeLineAdapter's scheduled extras.
class DynamicPrescriptionSeed {
  DynamicPrescriptionSeed.fromExtras(
    Map<String, String> extras, {
    required this.ownerDoctorId,
  }) : patientHistoryId = dynamicRxText(extras['P_PH_ID']),
       patientId = dynamicRxText(extras['P_PAT_ID']),
       appointmentId = dynamicRxText(extras['P_AD_ID']),
       name = dynamicRxText(extras['PAT_NAME']),
       code = dynamicRxText(extras['PAT_CODE']),
       gender = dynamicRxText(extras['PAT_GENDER']),
       age = dynamicRxText(extras['P_AGE']),
       visitDate = dynamicRxText(extras['ADM_DATE']),
       patientType = dynamicRxText(extras['P_PAT_TYPE']),
       existing =
           dynamicRxText(extras['IS_CREATED']).isNotEmpty &&
           dynamicRxText(extras['IS_CREATED']) != '0';
  final String ownerDoctorId,
      patientHistoryId,
      patientId,
      appointmentId,
      name,
      code,
      gender,
      age,
      visitDate,
      patientType;
  final bool existing;
  bool get valid =>
      patientType == '1' &&
      ownerDoctorId.isNotEmpty &&
      patientHistoryId.isNotEmpty &&
      patientId.isNotEmpty &&
      appointmentId.isNotEmpty &&
      visitDate.isNotEmpty;
  String get details =>
      [gender, age].where((part) => part.isNotEmpty).join(' • ');
  bool editableOn(DateTime now) {
    if (!valid) return false;
    try {
      return parseOracleDate(visitDate) == dateOnly(now);
    } catch (_) {
      return false;
    }
  }
}

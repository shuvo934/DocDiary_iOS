import '../../dashboard/dashboard_navigation.dart';
import 'doctor_appointment_models.dart';

DashboardRoute doctorAppointmentRoute(
  DoctorAppointmentAction action,
  DoctorAppointmentRow? row,
) {
  if (action == DoctorAppointmentAction.walkIn) {
    return const DashboardRoute(
      DashboardModule.doctorPrescriptionBuilder,
      extras: {'P_PAT_TYPE': '2', 'IS_CREATED': '0'},
    );
  }
  if (row == null) throw ArgumentError('An appointment is required.');
  String v(String key) => row.value(key);
  return switch (action) {
    DoctorAppointmentAction.avail => DashboardRoute(
      DashboardModule.doctorAppointmentAvail,
      extras: {'AD_ID': row.id},
    ),
    DoctorAppointmentAction.history => DashboardRoute(
      DashboardModule.doctorAppointmentHistory,
      extras: {
        'P_NAME': v('pat_name'),
        'P_CODE': v('pat_code'),
        'P_PH_ID': v('patient_data'),
      },
    ),
    DoctorAppointmentAction.progress => DashboardRoute(
      DashboardModule.doctorHealthProgress,
      extras: {
        'P_NAME': v('pat_name'),
        'P_CODE': v('pat_code'),
        'P_PH_ID': v('patient_data'),
        'IS_RANKED': v('is_ranked'),
        'ADM_DATE': v('adm_date'),
        'APPT_TIME': v('schedule_time'),
        'PFN_NAME': v('pfn_fee_name'),
        'PFN_ID': v('pfn_id'),
        'DEPTS_NAME': v('depts_name'),
        'DEPTS_ID': v('depts_id'),
        'CAT_ID': v('ph_cat_id'),
        'PRM_ID': v('ad_prm_id'),
        'PRD_ID': v('ad_prd_id'),
        'AD_ID': row.id,
        'FROM_PSV': 'false',
      },
    ),
    DoctorAppointmentAction.legacyPrescription => DashboardRoute(
      DashboardModule.doctorLegacyPrescription,
      extras: {
        'P_AGE': v('pat_age_now'),
        'PRESCRIPTION_TYPE': v('pmm'),
        'P_PH_ID': v('patient_data'),
      },
    ),
    DoctorAppointmentAction.dynamicPrescription => DashboardRoute(
      DashboardModule.doctorPrescriptionBuilder,
      extras: {
        'P_AGE': v('pat_age_now'),
        'PAT_NAME': v('pat_name'),
        'PAT_GENDER': v('pat_gender'),
        'PAT_CODE': v('pat_code'),
        'P_PH_ID': v('patient_data'),
        'ADM_DATE': v('adm_date'),
        'P_PAT_ID': v('pat_id'),
        'P_AD_ID': row.id,
        'P_PAT_TYPE': '1',
        'IS_CREATED': v('rvm'),
      },
    ),
    DoctorAppointmentAction.prescriptionPreview => DashboardRoute(
      DashboardModule.doctorPrescriptionPreview,
      extras: {'RVM_ID': v('rvm_id').trim()},
    ),
    DoctorAppointmentAction.video => DashboardRoute(
      DashboardModule.doctorVideoCall,
      extras: {'URL': v('doc_video_link')},
    ),
    DoctorAppointmentAction.walkIn => throw StateError('Handled above'),
  };
}

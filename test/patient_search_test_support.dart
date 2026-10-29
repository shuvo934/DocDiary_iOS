import 'dart:async';
import 'dart:convert';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/patient_search/patient_search_repository.dart';
import 'normal_prescription_test_support.dart';
import 'dynamic_history_test_support.dart';
import 'dynamic_preview_test_support.dart';

JsonMap searchedPatient({
  String id = '11',
  String name = 'Sample Patient',
  String progress = '6',
  String year = '2023',
  String area = 'Sample Area',
}) => {
  'pat_id': '${int.parse(id) + 100}',
  'ph_id': id,
  'pat_name': name,
  'sub_code': '23.01.${id.padLeft(5, '0')}.01',
  'dd_thana_name': area,
  'pph_progress': progress,
  'pyear': year,
  'pat_cell': '01700000000',
  'gender': 'Male',
  'pat_age': '31 Years 3 Months 29 Days',
};
JsonMap patientCalendarRow({
  String day = '24-OCT-26',
  String time = '02:00 PM',
  bool canceled = false,
}) => {
  'app_date': day,
  'schedule_time': time,
  'cancel_status': canceled ? 'Yes' : 'No',
  'doc_name': 'Sample Therapist',
  'depts_name': 'Outpatient Unit',
  'deptd_name': 'Physiotherapy Department',
  'deptm_name': 'Therapy',
  'pfn_fee_name': 'Physiotherapy Service',
  'ets': 'Regular',
  'ad_pat_app_status': 'Old',
  'avail': '1',
  'ph_patient_status': 'Active',
  'ph_patient_cat': 'General',
  'prm_code': 'S-1',
};

class PatientSearchHarness extends NormalRxHarness {
  PatientSearchHarness({bool dynamicMode = true}) {
    doctorData.addAll({
      'presc_active': dynamicMode ? '1' : '0',
      'can_prescribe': dynamicMode ? '1' : '0',
    });
    patientRows = [
      searchedPatient(progress: '0'),
      searchedPatient(id: '12', name: 'Another Patient'),
    ];
    transport.onGet = respondSearch;
  }
  PatientSearchRepository get searchRepository =>
      PatientSearchRepository(appointments);
  List<JsonMap> historyRecords = historyRows();
  List<JsonMap> calendarRecords = [
    patientCalendarRow(time: '10:00 AM'),
    patientCalendarRow(),
    patientCalendarRow(time: '04:00 PM', canceled: true),
  ];
  bool failPatients = false,
      failHistory = false,
      failCalendar = false,
      encodedPatients = false;
  Completer<JsonMap>? pendingPatients,
      pendingHistory,
      pendingCalendar,
      pendingProfile;
  JsonMap? patientResponse;
  Future<JsonMap> respondSearch(Uri uri) async {
    final endpoint = uri.pathSegments.last;
    if (endpoint == 'getDocData' && pendingProfile != null) {
      return pendingProfile!.future;
    }
    if (uri.path.contains('/patient_search/') &&
        const [
          'getPatientList',
          'getPatientListNew',
          'getDyPresPatientList',
          'getDyPresPatientListBySearch',
        ].contains(endpoint)) {
      if (pendingPatients != null) return pendingPatients!.future;
      if (failPatients) throw const AppFailure('Patient list unavailable');
      return patientResponse ??
          {'pat_list': encodedPatients ? jsonEncode(patientRows) : patientRows};
    }
    if (endpoint == 'getPrescriptionHistory') {
      if (pendingHistory != null) return pendingHistory!.future;
      if (failHistory) throw const AppFailure('History unavailable');
      return {'items': historyRecords};
    }
    if (endpoint == 'getPatAppointment') {
      if (pendingCalendar != null) return pendingCalendar!.future;
      if (failCalendar) throw const AppFailure('Calendar unavailable');
      return {'count': calendarRecords.length, 'items': calendarRecords};
    }
    if (endpoint == 'getPreviewData') {
      final response = previewFixture();
      (response['data'] as JsonMap)['rvm_id'] = uri.queryParameters['p_rvm_id'];
      return response;
    }
    return respondRx(uri);
  }

  List<Uri> get patientReads =>
      transport.requests
          .where(
            (r) =>
                r.uri.path.contains('/patient_search/') &&
                !const [
                  'getPatData',
                  'getPatAppointment',
                ].contains(r.uri.pathSegments.last),
          )
          .map((r) => r.uri)
          .toList();
}

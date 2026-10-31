import 'dart:async';
import 'dart:convert';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/patient_search/admin_patient_search_repository.dart';
import 'patient_search_test_support.dart';
import 'support.dart';

class AdminPatientSearchHarness extends PatientSearchHarness {
  AdminPatientSearchHarness({bool dynamicMode = true, bool canCall = true}) {
    loginResponse = adminLogin();
    adminData.addAll({
      'presc_active': dynamicMode ? '1' : '0',
      'all_access_flag': canCall ? '1' : '0',
    });
    transport.onGet = respondAdminSearch;
  }
  AdminPatientSearchRepository get adminSearch =>
      AdminPatientSearchRepository(appointments);
  List<JsonMap>? searchedRows;
  Future<JsonMap> respondAdminSearch(Uri uri) async {
    final endpoint = uri.pathSegments.last;
    if (endpoint == 'getAdminData' && pendingProfile != null) {
      return pendingProfile!.future;
    }
    if (endpoint == 'getHundredPatListNew' ||
        endpoint == 'getPatienListBySearch') {
      if (pendingPatients != null) return pendingPatients!.future;
      if (failPatients) throw const AppFailure('Patient list unavailable');
      final rows =
          endpoint == 'getPatienListBySearch'
              ? searchedRows ?? patientRows
              : patientRows;
      return patientResponse ??
          {'pat_list': encodedPatients ? jsonEncode(rows) : rows};
    }
    return respondSearch(uri);
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/appointments/all_schedule/all_appointment_repository.dart';
import 'unit_appointment_test_support.dart';
import 'support.dart';

class AllAppointmentHarness extends UnitAppointmentHarness {
  AllAppointmentHarness({
    bool admin = false,
    bool canCall = true,
    super.clock,
  }) {
    doctorData['doc_manager_flag'] = '1';
    if (admin) loginResponse = adminLogin();
    adminData.addAll({
      'all_access_flag': canCall ? '1' : '0',
      'hr_appointment_active': '1',
      'acc_appointment_active': '1',
    });
    transport.onGet = respondAll;
  }
  AllAppointmentRepository get allRepository =>
      AllAppointmentRepository(appointments);
  List<JsonMap> departmentRows = [
    {'deptd_id': '8', 'deptd_name': 'Speech & Language Therapy Department'},
    {'deptd_id': '99', 'deptd_name': 'Physiotherapy Department'},
  ];
  JsonMap? departmentsResponse, totalsResponse;
  bool failDepartments = false, failTotals = false;
  Completer<JsonMap>? pendingDepartments, pendingTotals;
  Future<JsonMap> respondAll(Uri uri) async {
    final endpoint = uri.pathSegments.last;
    if (endpoint == 'getAdminData' && pendingProfile != null) {
      return pendingProfile!.future;
    }
    if (endpoint == 'getDeptd') {
      if (pendingDepartments != null) return pendingDepartments!.future;
      if (failDepartments) {
        throw const AppFailure('Department list unavailable');
      }
      return departmentsResponse ??
          {
            'count': departmentRows.length,
            'items':
                encodedArrays ? jsonEncode(departmentRows) : departmentRows,
          };
    }
    if (endpoint == 'getDeptdSchCount') {
      if (pendingTotals != null) return pendingTotals!.future;
      if (failTotals) throw const AppFailure('Department totals unavailable');
      final nextDay = uri.queryParameters['pdate'] == '25-OCT-26';
      final rows = [
        <String, Object?>{
          'deptd_sch_count': nextDay ? '6' : '9',
          'deptd_tot_count': '14',
          'deptd_busy_count': '2',
        },
      ];
      return totalsResponse ??
          {'count': 1, 'items': encodedArrays ? jsonEncode(rows) : rows};
    }
    return respondUnit(uri);
  }

  List<Uri> reads(String endpoint) =>
      transport.requests
          .where(
            (request) =>
                request.method == 'GET' &&
                request.uri.pathSegments.last == endpoint,
          )
          .map((request) => request.uri)
          .toList();
  List<Uri> get departmentReads => reads('getDeptd');
  List<Uri> get totalReads => reads('getDeptdSchCount');
}

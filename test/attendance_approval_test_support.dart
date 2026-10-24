import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/hr/attendance_update_approval/attendance_approval_repository.dart';
import 'hr_dashboard_test_support.dart';

JsonMap approvalRequest({
  String id = '41',
  String code = 'AR-26-0041',
  String employee = '11',
  String name = 'Example Employee A',
}) => {
  'darm_app_code': code,
  'darm_id': id,
  'darm_emp_id': employee,
  'emp_name': name,
  'emp_code': 'E-$employee',
  'darm_date': '20-OCT-26',
  'darm_update_date': '19-OCT-26',
};
JsonMap approvalDetail() => {
  'emp_name': 'Example Employee A',
  'emp_code': 'E-11',
  'job_calling_title': 'Executive Officer',
  'darm_date': '20-OCT-26',
  'darm_req_type': 'Attendance Update',
  'shift': 'General Shift',
  'darm_update_date': '19-OCT-26',
  'arrival_time': '09:00 AM',
  'departure_time': '06:00 PM',
  'reason': 'Machine Error',
  'darm_reason': 'Attendance was not recorded by the machine.',
  'mac_in_time': '09:12 AM',
  'mac_out_time': '06:08 PM',
  'current_shift': 'General Shift',
  'dard_recommendation': 'Please review.',
  'forwarder_name': 'Example Supervisor',
};

class AttendanceApprovalHarness extends HrHarness {
  AttendanceApprovalHarness() {
    transport.onGet = respondApproval;
    transport.onPost = (uri, headers) async {
      if (uri.path.endsWith('/approveAttUpReq') ||
          uri.path.endsWith('/rejectAttUpReq')) {
        if (completeOnSubmit && response['updated_req'] == 'ok') requests = [];
        return response;
      }
      return {'string_out': 'Successfully Created'};
    };
  }
  List<JsonMap> requests = [
    approvalRequest(),
    approvalRequest(
      id: '42',
      code: 'AR-26-0042',
      employee: '12',
      name: 'Example Employee B',
    ),
  ];
  List<JsonMap> details = [approvalDetail()];
  JsonMap response = {
    'string_out': 'Successfully Created',
    'updated_req': 'ok',
  };
  bool completeOnSubmit = true;
  AttendanceApprovalRepository get approval =>
      AttendanceApprovalRepository(transport, now: () => now);
  Future<JsonMap> respondApproval(Uri uri) async {
    switch (uri.pathSegments.last) {
      case 'getAttUpReqList':
        return hrPage(requests);
      case 'getAttUpdateData':
        return hrPage(details);
    }
    return respond(uri);
  }
}

import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/hr/leave_approval/leave_approval_repository.dart';
import 'hr_dashboard_test_support.dart';
import 'leave_record_test_support.dart';

JsonMap approvalRequest({
  String id = '41',
  String code = 'LR-26-0041',
  String employee = '11',
  String name = 'Example Employee A',
}) => {
  'la_app_code': code,
  'la_id': id,
  'la_emp_id': employee,
  'emp_name': name,
  'emp_code': 'E-$employee',
  'la_date': '20-OCT-26',
  'la_leave_days': '2',
};
JsonMap approvalDetail({
  String shortCode = 'CL',
  String balance = '10',
  String days = '2',
}) => {
  'emp_name': 'Example Employee A',
  'emp_code': 'E-11',
  'la_calling_title': 'Executive Officer',
  'la_date': '20-OCT-26',
  'la_lc_id': '1',
  'leave_type': shortCode == 'SL' ? 'Sick Leave' : 'Casual Leave',
  'la_from_date': '24-OCT-26',
  'la_to_date': '25-OCT-26',
  'la_leave_days': days,
  'leave_balance': balance,
  'la_reason': 'Personal work requires leave.',
  'lc_short_code': shortCode,
};

class LeaveApprovalHarness extends LeaveRecordHarness {
  LeaveApprovalHarness() {
    transport.onGet = respondApproval;
    transport.onPost = (uri, headers) async {
      if (uri.path.endsWith('/approveLeave') ||
          uri.path.endsWith('/rejectLeave')) {
        if (completeOnSubmit && response['updated_req'] == 'ok') {
          requests = [];
          records = [
            for (final row in records)
              {
                ...row,
                if (row['la_id'] == headers['P_LA_ID'])
                  'la_approved': uri.path.endsWith('/approveLeave') ? '1' : '2',
              },
          ];
        }
        return response;
      }
      return {'string_out': 'Successfully Created'};
    };
  }
  List<JsonMap> requests = [
    approvalRequest(),
    approvalRequest(
      id: '42',
      code: 'LR-26-0042',
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
  LeaveApprovalRepository get approval =>
      LeaveApprovalRepository(transport, now: () => now);
  Future<JsonMap> respondApproval(Uri uri) async {
    switch (uri.pathSegments.last) {
      case 'getLeaveRequestList':
        return hrPage(requests);
      case 'getLeaveData':
        return hrPage(details);
    }
    return respondLeave(uri);
  }
}

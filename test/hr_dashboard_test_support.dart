import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_repository.dart';
import 'support.dart';

JsonMap hrPage(List<JsonMap> rows) => {'count': rows.length, 'items': rows};
JsonMap hrDateRow(
  String date,
  String name,
  String leave, {
  String holiday = '1',
}) => {
  'd_date': date,
  'date_day': 'DAY',
  'emp_id': '1',
  'emp_name': name,
  'leave': leave,
  'h_flag': holiday,
};

class HrHarness extends Harness {
  HrHarness({DateTime? clock})
    : super(clock: clock ?? DateTime(2026, 10, 20, 13, 30)) {
    loginResponse = adminLogin();
    adminData.addAll({
      'all_access_flag': '1',
      'hr_acc_active_flag': '1',
      'hr_dashboard': '1',
      'acc_dashboard': '1',
      'usr_mob_app_analytic_access': '1',
    });
    transport.onGet = respond;
  }
  HrDashboardRepository get hr =>
      HrDashboardRepository(transport, now: () => now);
  JsonMap departmentRow = {'total_depts': '12', 'total_emp': '88'};
  JsonMap attendanceRow = {
    'present': '60',
    'absent': '10',
    'leave': '5',
    'holiday_weekend': '5',
    'late_count': '10',
    'early_count': '5',
    'both_late_early_count': '5',
  };
  JsonMap payrollRow = {
    'total': '15488',
    'salary': '12345678.25',
    'refundable': '1250',
    'other_allowance': '84500.6',
    'deduction': '78500.4',
    'net_payable': '12352928.5',
  };
  List<JsonMap>? dateRows;
  List<JsonMap> employeeRows = [
    {'emp_name': 'Example Employee A'},
    {'emp_name': 'Example Employee B'},
  ];
  Future<JsonMap> respond(Uri uri) async {
    if (!uri.path.contains('/hrm_dashboard/')) return defaultGet(uri);
    switch (uri.pathSegments.last) {
      case 'getDeptEmpCount':
        return hrPage([departmentRow]);
      case 'getAttendancePerc':
        return hrPage([attendanceRow]);
      case 'getEmpWithLeaveDate':
        return hrPage(
          dateRows ??
              [
                hrDateRow(
                  uri.queryParameters['first_date']!,
                  'Example Employee A',
                  'CL',
                ),
              ],
        );
      case 'getEmpInLeave':
        return hrPage(employeeRows);
      case 'getPayrollData':
        return hrPage([payrollRow]);
      case 'getAttWorkingDays':
        return hrPage([
          {'work_days': '25'},
        ]);
    }
    throw StateError('Unexpected HR test request');
  }

  List<RequestRecord> get hrRequests =>
      transport.requests
          .where((r) => r.uri.path.contains('/hrm_dashboard/'))
          .toList();
}

import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/hr/leave_balance/leave_balance_models.dart';
import 'package:docdiary_ios/features/hr/leave_balance/leave_balance_repository.dart';
import 'hr_dashboard_test_support.dart';
import 'leave_record_test_support.dart';

const leaveBalanceSeed = LeaveBalanceSeed(
  branch: '1',
  division: '10',
  department: '100',
  designation: '7',
  employee: '11',
  lastDate: '31-OCT-26',
);
JsonMap balanceRow({
  String code = 'CL',
  String name = 'Casual Leave',
  String value = '10',
}) => {
  'lc_name': name,
  'lc_short_code': code,
  'lbd_opening_qty': '2',
  'lbd_current_qty': value,
  'lbd_taken_qty': '4',
  'lbd_cash_taken_qty': '0',
  'lbd_transfer_qty': '0.5',
  'lbd_balance_qty': '8',
};

class LeaveBalanceHarness extends LeaveRecordHarness {
  LeaveBalanceHarness() {
    transport.onGet = respondBalance;
  }
  List<JsonMap> designations = [
    {'desig_id': '7', 'desig_name': 'Executive Officer'},
    {'desig_id': '8', 'desig_name': 'Manager'},
  ];
  List<JsonMap> balances = [
    balanceRow(),
    balanceRow(code: 'EL', name: 'Earned Leave', value: '20'),
  ];
  List<JsonMap> chartRows = [
    {'lc_short_code': 'CL', 'quantity': '12', 'consumed': '4', 'balance': '8'},
    {
      'lc_short_code': 'EL',
      'quantity': '22',
      'consumed': '1.5',
      'balance': '20.5',
    },
    {'lc_short_code': 'SL', 'quantity': '0', 'consumed': '0', 'balance': '0'},
  ];
  LeaveBalanceRepository get leaveBalance =>
      LeaveBalanceRepository(transport, now: () => now);
  Future<JsonMap> respondBalance(Uri uri) async {
    final name = uri.pathSegments.last;
    switch (name) {
      case 'getDepartmentByDiv':
      case 'getDepartmentByDivCoa':
        return hrPage(
          departments
              .where(
                (r) => r['dept_divm_id'] == uri.queryParameters['p_div_id'],
              )
              .toList(),
        );
      case 'getDesignationsByDept':
      case 'getDesignationsByDeptCoa':
        return hrPage(designations);
      case 'getEmployeeByDesig':
      case 'getEmployeeByDesigCoa':
        return hrPage(
          employees
              .where(
                (r) =>
                    r['jsm_divm_id'] == uri.queryParameters['p_div_id'] &&
                    r['jsm_dept_id'] == uri.queryParameters['p_dep_id'] &&
                    r['jsm_desig_id'] == uri.queryParameters['p_desig_id'],
              )
              .map((r) => <String, Object?>{...r, 'coa_name': 'Sample Centre'})
              .toList(),
        );
      case 'getLeaveBalance':
        return hrPage(balances);
      case 'getLeaveChartData':
        return hrPage(chartRows);
    }
    return respondLeave(uri);
  }
}

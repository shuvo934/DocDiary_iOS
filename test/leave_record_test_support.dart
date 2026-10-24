import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/hr/leave_record/leave_record_repository.dart';
import 'hr_dashboard_test_support.dart';

JsonMap leaveRecordRow({
  String id = '41',
  String employee = '11',
  String name = 'Sample Employee A',
  String division = '10',
  String department = '100',
  String branch = '1',
  String status = '0',
  String from = '24-OCT',
  String to = '24-OCT',
  String days = '1',
}) => {
  'la_id': id,
  'la_app_code': 'LR-2026-$id',
  'la_approved': status,
  'la_date': '24-OCT-26',
  'leave_type': 'Casual Leave',
  'la_from_date': from,
  'la_to_date': to,
  'la_leave_days': days,
  'emp_name': name,
  'emp_id': employee,
  'job_calling_title': 'Executive Officer',
  'jsm_divm_id': division,
  'jsm_dept_id': department,
  'jsm_desig_id': '7',
  'coa_name': branch == '1' ? 'Sample Centre' : 'Other Centre',
  'coa_id': branch,
};
JsonMap leaveEmployee(
  String id,
  String name,
  String division,
  String department,
) => {
  'emp_id': id,
  'emp_code': 'E-$id',
  'emp_name': name,
  'jsm_divm_id': division,
  'jsm_dept_id': department,
  'jsm_desig_id': '7',
  'job_calling_title': 'Executive Officer',
};

class LeaveRecordHarness extends HrHarness {
  LeaveRecordHarness({DateTime? clock})
    : super(clock: clock ?? DateTime(2026, 10, 24, 13, 30)) {
    transport.onGet = respondLeave;
  }
  List<JsonMap> branches = [
    {'coa_id': '1', 'coa_name': 'Sample Centre'},
    {'coa_id': '2', 'coa_name': 'Other Centre'},
  ];
  List<JsonMap> divisions = [
    {'divm_id': '10', 'divm_name': 'Division A'},
    {'divm_id': '20', 'divm_name': 'Division B'},
  ];
  List<JsonMap> departments = [
    {'dept_id': '100', 'dept_name': 'Department A', 'dept_divm_id': '10'},
    {'dept_id': '101', 'dept_name': 'Department B', 'dept_divm_id': '10'},
    {'dept_id': '200', 'dept_name': 'Department C', 'dept_divm_id': '20'},
  ];
  List<JsonMap> employees = [
    leaveEmployee('11', 'Same Name', '10', '100'),
    leaveEmployee('12', 'Same Name', '10', '100'),
    leaveEmployee('13', 'Another Name', '10', '101'),
    leaveEmployee('21', 'Fourth Name', '20', '200'),
  ];
  List<JsonMap> records = [
    leaveRecordRow(name: 'Same Name'),
    leaveRecordRow(
      id: '42',
      employee: '12',
      name: 'Same Name',
      status: '1',
      from: '21-OCT',
      to: '23-OCT',
      days: '3',
    ),
    leaveRecordRow(
      id: '43',
      employee: '13',
      department: '101',
      status: '2',
      from: '30-SEP',
      to: '02-OCT',
      days: '3',
    ),
    leaveRecordRow(
      id: '44',
      employee: '21',
      division: '20',
      department: '200',
      branch: '2',
      status: '3',
    ),
  ];
  LeaveRecordRepository get leaveRecord =>
      LeaveRecordRepository(transport, now: () => now);
  Future<JsonMap> respondLeave(Uri uri) async {
    var name = uri.pathSegments.last;
    final scoped = name.endsWith('WithCoa');
    if (scoped) name = name.substring(0, name.length - 'WithCoa'.length);
    final branch = uri.queryParameters['p_coa_id'];
    final div = branch == '1' ? '10' : '20';
    switch (name) {
      case 'getBranches':
        return hrPage(branches);
      case 'getDivision':
        return hrPage(
          divisions.where((r) => !scoped || r['divm_id'] == div).toList(),
        );
      case 'getDepartment':
        return hrPage(
          departments
              .where((r) => !scoped || r['dept_divm_id'] == div)
              .toList(),
        );
      case 'getEmployee':
        return hrPage(
          employees.where((r) => !scoped || r['jsm_divm_id'] == div).toList(),
        );
      case 'getLeaveRecord':
        return hrPage(
          records.where((r) => !scoped || r['coa_id'] == branch).toList(),
        );
    }
    return respond(uri);
  }
}

import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/hr/daily_attendance/daily_attendance_repository.dart';
import 'hr_dashboard_test_support.dart';
import 'support.dart';

JsonMap attendanceEmployee(
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
  'job_calling_title': 'Therapist',
};
JsonMap attendanceRecord(
  JsonMap employee, {
  String status = 'Present',
  Object? late = '',
  Object? early = '',
  Object? location = 'Example Branch',
}) => {
  ...employee,
  'osm_name': 'Morning',
  'in_time': '08:15 AM',
  'out_time': '05:00 PM',
  'status': status,
  'late_status': late,
  'early_status': early,
  'coa_name': location,
};

class AttendanceHarness extends HrHarness {
  AttendanceHarness({super.clock});
  DailyAttendanceRepository get daily =>
      DailyAttendanceRepository(transport, now: () => now);
  List<JsonMap> branches = [
    {'coa_id': '2', 'coa_name': 'Example Branch'},
  ];
  List<JsonMap> divisions = [
    {'divm_id': '1', 'divm_name': 'Clinical'},
    {'divm_id': '2', 'divm_name': 'Support'},
  ];
  List<JsonMap> departments = [
    {'dept_id': '10', 'dept_name': 'Physiotherapy', 'dept_divm_id': '1'},
    {'dept_id': '20', 'dept_name': 'Administration', 'dept_divm_id': '2'},
  ];
  List<JsonMap> employees = [
    attendanceEmployee('11', 'Same Name', '1', '10'),
    attendanceEmployee('12', 'Same Name', '1', '10'),
    attendanceEmployee('13', 'Employee C', '2', '20'),
  ];
  List<JsonMap>? records;
  List<JsonMap> get actualRecords =>
      records ??
      [
        attendanceRecord(employees[0], late: 'Y'),
        attendanceRecord(employees[1], status: 'Out Miss', early: 'Y'),
        attendanceRecord(employees[2], status: 'In Leave', location: null),
      ];
  @override
  Future<JsonMap> respond(Uri uri) async {
    switch (uri.pathSegments.last.replaceFirst('WithCoa', '')) {
      case 'getBranches':
        return hrPage(branches);
      case 'getDivision':
        return hrPage(divisions);
      case 'getDepartment':
        return hrPage(departments);
      case 'getEmployee':
        return hrPage(employees);
      case 'getDailyAttendance':
        return hrPage(actualRecords);
      default:
        return super.respond(uri);
    }
  }

  List<RequestRecord> get dailyRequests =>
      transport.requests
          .where(
            (request) => const [
              'getBranches',
              'getDivision',
              'getDepartment',
              'getEmployee',
              'getDailyAttendance',
              'getDivisionWithCoa',
              'getDepartmentWithCoa',
              'getEmployeeWithCoa',
              'getDailyAttendanceWithCoa',
            ].contains(request.uri.pathSegments.last),
          )
          .toList();
}

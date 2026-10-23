import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/hr/employee_attendance/employee_attendance_models.dart';
import 'package:docdiary_ios/features/hr/employee_attendance/employee_attendance_repository.dart';
import 'daily_attendance_test_support.dart';
import 'hr_dashboard_test_support.dart';

const employeeSeed = EmployeeAttendanceSeed(
  division: '1',
  department: '10',
  designation: '7',
  employee: '11',
);
JsonMap employeeReportRow({
  String status = 'P',
  Object? inTime = '08:30:00 AM',
  Object? outTime = '05:00:00 PM',
  Object? lateAfter = '09:00:00 AM',
  Object? earlyBefore = '05:00:00 PM',
  Object? leaveName = '',
  Object? shift = 'Morning',
  Object? inMachine = '2',
  Object? outMachine = '2',
  String date = '01-OCT-26',
}) => {
  'dac_in_date_time': inTime,
  'dac_late_after': lateAfter,
  'dac_early_before': earlyBefore,
  'dac_out_date_time': outTime,
  'dac_date1': date,
  'dac_attn_status': status,
  'lc_name': leaveName,
  'osm_name': shift,
  'coa_name': 'Example Branch',
  'in_machine_coa_id': inMachine,
  'out_machine_coa_id': outMachine,
  'dac_in_attd_latitude': '23.7',
  'dac_in_attd_longitude': '90.4',
  'dac_out_attd_latitude': null,
  'dac_out_attd_longitude': 'null',
};

class EmployeeAttendanceHarness extends AttendanceHarness {
  EmployeeAttendanceHarness({super.clock}) {
    employees = [
      for (final row in employees) {...row, 'coa_name': 'Example Branch'},
    ];
  }
  EmployeeAttendanceRepository get employeeAttendance =>
      EmployeeAttendanceRepository(transport, now: () => now);
  List<JsonMap> designations = [
    {'desig_id': '7', 'desig_name': 'Senior Therapist'},
    {'desig_id': '8', 'desig_name': 'Assistant'},
  ];
  List<JsonMap>? counts, reports, statuses, working;
  List<JsonMap> get actualReports =>
      reports ??
      [
        employeeReportRow(),
        employeeReportRow(
          status: 'A',
          inTime: '',
          outTime: '',
          date: '02-OCT-26',
        ),
        employeeReportRow(
          status: 'L',
          leaveName: 'Casual Leave',
          inTime: '',
          outTime: '',
          date: '03-OCT-26',
        ),
        employeeReportRow(
          outTime: '',
          inTime: '09:00:00 AM',
          date: '04-OCT-26',
        ),
      ];
  @override
  Future<JsonMap> respond(Uri uri) async {
    switch (uri.pathSegments.last.replaceFirst('Coa', '')) {
      case 'getDepartmentByDiv':
        return hrPage(
          departments
              .where(
                (row) => row['dept_divm_id'] == uri.queryParameters['p_div_id'],
              )
              .toList(),
        );
      case 'getDesignationsByDept':
        return hrPage(designations);
      case 'getEmployeeByDesig':
        return hrPage(
          employees
              .where(
                (row) =>
                    row['jsm_divm_id'] == uri.queryParameters['p_div_id'] &&
                    row['jsm_dept_id'] == uri.queryParameters['p_dep_id'] &&
                    row['jsm_desig_id'] == uri.queryParameters['p_desig_id'],
              )
              .toList(),
        );
      case 'getAttendanceCountEmp':
        return hrPage(
          counts ??
              [
                {
                  'present': '17',
                  'absent': '2',
                  'leave': '2',
                  'holiday_weekend': '4',
                  'late_count': '3',
                  'early_count': '1',
                  'both_late_early_count': '2',
                },
              ],
        );
      case 'getAttReportData':
        return hrPage(actualReports);
      case 'getAttStatus':
        return hrPage(
          statuses ??
              [
                {
                  'present_status': '23',
                  'absent_status': '2',
                  'weekend_status': '4',
                  'present_weekend': '1',
                  'holiday_status': '0',
                  'present_holiday_status': '0',
                  'leave_status': '2',
                  'present_leave_status': '0',
                },
              ],
        );
      case 'getAttWorkingDays':
        return hrPage(
          working ??
              [
                {'work_days': '25'},
              ],
        );
      default:
        return super.respond(uri);
    }
  }
}

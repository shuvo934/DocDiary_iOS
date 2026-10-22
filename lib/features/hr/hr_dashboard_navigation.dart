import '../dashboard/dashboard_navigation.dart';

enum HrDestination {
  dailyAttendance(
    'Daily Attendance',
    'daily_attendance.png',
    DashboardModule.hrDailyAttendance,
  ),
  employeeAttendance(
    'Emp Wise Attendance',
    'emp_attendance.png',
    DashboardModule.hrEmployeeAttendance,
  ),
  attendanceApproval(
    'Attendance Update Approval',
    'att_up_app.png',
    DashboardModule.hrAttendanceUpdateApproval,
  ),
  leaveRecord('Leave Record', 'leave.png', DashboardModule.hrLeaveRecord),
  leaveBalance('Leave Balance', 'lv_bal.png', DashboardModule.hrLeaveBalance),
  leaveApproval(
    'Leave Approval',
    'leave_app.png',
    DashboardModule.hrLeaveApproval,
  );

  const HrDestination(this.label, this.artwork, this.module);
  final String label, artwork;
  final DashboardModule module;
  DashboardRoute get route => DashboardRoute(
    module,
    extras:
        this == HrDestination.leaveApproval ? const {'FLAG': '0'} : const {},
  );
}

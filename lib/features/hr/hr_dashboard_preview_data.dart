import '../../core/native_dates.dart';
import '../../core/native_json.dart';

/// Synthetic data for main_dashboard_preview.dart only; no production transport.
JsonMap? hrDashboardPreviewResponse(Uri uri) {
  if (!uri.path.contains('/hrm_dashboard/')) return null;
  List<JsonMap> rows;
  switch (uri.pathSegments.last) {
    case 'getDeptEmpCount':
      rows = [
        {'total_depts': '12', 'total_emp': '88'},
      ];
    case 'getAttendancePerc':
      rows = [
        {
          'present': '57',
          'absent': '8',
          'leave': '5',
          'holiday_weekend': '4',
          'late_count': '9',
          'early_count': '3',
          'both_late_early_count': '2',
        },
      ];
    case 'getEmpInLeave':
      rows = [
        for (var i = 0; i < 5; i++) {'emp_name': 'Example Employee ${i + 1}'},
      ];
    case 'getEmpWithLeaveDate':
      final first = parseOracleDate(uri.queryParameters['first_date']!);
      rows = [
        for (var i = 0; i < 5; i++)
          {
            'd_date': oracleDate(
              DateTime(first.year, first.month, first.day + i),
            ),
            'date_day': const ['SAT', 'SUN', 'MON', 'TUE', 'WED'][i],
            'emp_id': '${i + 1}',
            'emp_name': 'Example Employee ${i + 1}',
            'leave': i.isEven ? 'CL' : 'SL',
            'h_flag': '1',
          },
      ];
    case 'getPayrollData':
      rows = [
        {
          'total': '15488',
          'salary': '4568000.25',
          'refundable': '12500',
          'other_allowance': '84500.6',
          'deduction': '78500.4',
          'net_payable': '4586500.5',
        },
      ];
    case 'getAttWorkingDays':
      rows = [
        {'work_days': '25'},
      ];
    default:
      return null;
  }
  return {'count': rows.length, 'items': rows};
}

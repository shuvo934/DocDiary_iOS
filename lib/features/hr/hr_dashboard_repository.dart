import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../../core/transport.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../management/management_access.dart';
import 'hr_dashboard_models.dart';

class HrModuleUnavailable implements Exception {
  const HrModuleUnavailable();
}

class HrDashboardRepository {
  HrDashboardRepository(this.transport, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Transport transport;
  final DateTime Function() now;

  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() isCurrent,
  ) {
    if (!isCurrent()) throw const ObsoleteRequest();
    if (profile.isDoctor ||
        session.account.role != AccountRole.admin ||
        profile.role != session.account.role ||
        (profile.value('usr_id').isNotEmpty &&
            profile.value('usr_id') != session.account.identity)) {
      throw const AppFailure(
        'The server returned information for a different account. Please try again.',
        kind: FailureKind.invalidData,
      );
    }
    ProfileRepository.checkAccess(profile, now());
    if (!ManagementAccess(
      profile,
    ).allows(ManagementDestination.humanResources)) {
      throw const HrModuleUnavailable();
    }
  }

  Future<List<JsonMap>> _rows(
    AuthSession session,
    AccountProfile profile,
    String endpoint,
    bool Function() isCurrent, [
    HrDateRange? range,
  ]) async {
    guard(session, profile, isCurrent);
    final response = await transport.get(
      apiEndpoint(
        session.center.baseUri,
        'hrm_dashboard/$endpoint',
        range?.query,
      ),
    );
    guard(session, profile, isCurrent);
    final count = int.tryParse(nativeText(response['count']).trim());
    if (count == null || count < 0 || count > 0 && response['items'] == null) {
      throw const AppFailure(
        'The server returned incomplete HR Dashboard data.',
        kind: FailureKind.invalidData,
      );
    }
    final rows = count == 0 ? <JsonMap>[] : nativeItems(response);
    if (count > 0 && rows.isEmpty) {
      throw const AppFailure(
        'The server returned incomplete HR Dashboard data.',
        kind: FailureKind.invalidData,
      );
    }
    return rows;
  }

  Future<JsonMap> _last(
    AuthSession session,
    AccountProfile profile,
    String endpoint,
    List<String> keys,
    bool Function() isCurrent, [
    HrDateRange? range,
  ]) async {
    final rows = await _rows(session, profile, endpoint, isCurrent, range);
    // Native assigns aggregate rows in order: the last row wins; it is not a sum.
    for (final row in rows) {
      for (final key in keys) {
        hrNumber(row, key);
      }
    }
    return rows.isEmpty ? {for (final key in keys) key: '0'} : rows.last;
  }

  Future<HrCounts> counts(
    AuthSession session,
    AccountProfile profile, {
    required bool Function() isCurrent,
  }) async => HrCounts.fromJson(
    await _last(session, profile, 'getDeptEmpCount', [
      'total_depts',
      'total_emp',
    ], isCurrent),
  );

  Future<HrAttendance> attendance(
    AuthSession session,
    AccountProfile profile,
    HrDateRange range, {
    required bool Function() isCurrent,
  }) async => HrAttendance.fromJson(
    await _last(
      session,
      profile,
      'getAttendancePerc',
      HrAttendance.keys,
      isCurrent,
      range,
    ),
  );

  Future<HrWeeklyLeave> leave(
    AuthSession session,
    AccountProfile profile,
    HrDateRange range, {
    required bool Function() isCurrent,
  }) async {
    final dates = await _rows(
      session,
      profile,
      'getEmpWithLeaveDate',
      isCurrent,
      range,
    );
    HrWeeklyLeave.validateDateRows(dates);
    final names = await _rows(
      session,
      profile,
      'getEmpInLeave',
      isCurrent,
      range,
    );
    return HrWeeklyLeave.fromRows(range, dates, names);
  }

  Future<HrPayroll> payroll(
    AuthSession session,
    AccountProfile profile,
    HrPayrollMonth month, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    if (!month.isAllowed(now())) {
      throw const AppFailure(
        'Choose one of the previous six payroll months.',
        kind: FailureKind.invalidData,
      );
    }
    final pay = await _last(
      session,
      profile,
      'getPayrollData',
      [
        'total',
        'salary',
        'refundable',
        'other_allowance',
        'deduction',
        'net_payable',
      ],
      isCurrent,
      month.range,
    );
    final days = await _last(
      session,
      profile,
      'getAttWorkingDays',
      ['work_days'],
      isCurrent,
      month.range,
    );
    return HrPayroll.fromRows(pay, days);
  }

  Future<HrDashboardData> load(
    AuthSession session,
    AccountProfile profile,
    DateTime today, {
    required bool Function() isCurrent,
  }) async {
    final count = await counts(session, profile, isCurrent: isCurrent);
    final att = await attendance(
      session,
      profile,
      HrDateRange.attendance(HrAttendancePeriod.today, today),
      isCurrent: isCurrent,
    );
    final leaves = await leave(
      session,
      profile,
      HrDateRange.leave(HrLeavePeriod.thisWeek, today),
      isCurrent: isCurrent,
    );
    final pay = await payroll(
      session,
      profile,
      HrPayrollMonth(DateTime(today.year, today.month - 1)),
      isCurrent: isCurrent,
    );
    return HrDashboardData(count, att, leaves, pay);
  }
}

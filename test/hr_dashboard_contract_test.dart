import 'dart:async';
import 'dart:convert';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/account_access.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/dashboard/admin_chart_models.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_models.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_navigation.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'hr_dashboard_test_support.dart';

void main() {
  test(
    'native attendance periods use completed Saturday-Friday weeks and months',
    () {
      final now = DateTime(2026, 10, 20, 23, 59);
      expect(
        [
          for (final p in HrAttendancePeriod.values)
            HrDateRange.attendance(p, now).query,
        ],
        [
          {'first_date': '20-OCT-26', 'last_date': '20-OCT-26'},
          {'first_date': '19-OCT-26', 'last_date': '19-OCT-26'},
          {'first_date': '10-OCT-26', 'last_date': '16-OCT-26'},
          {'first_date': '01-SEP-26', 'last_date': '30-SEP-26'},
        ],
      );
      expect(
        HrDateRange.attendance(
          HrAttendancePeriod.lastWeek,
          DateTime(2026, 10, 17),
        ).first,
        DateTime(2026, 10, 10),
      );
      expect(
        HrDateRange.attendance(
          HrAttendancePeriod.lastMonth,
          DateTime(2024, 3, 31),
        ).last,
        DateTime(2024, 2, 29),
      );
      expect(
        HrDateRange.attendance(
          HrAttendancePeriod.lastDay,
          DateTime(2026),
        ).label,
        '31 December, 25',
      );
      expect(
        HrDateRange.attendance(HrAttendancePeriod.lastMonth, now).label,
        '01 September, 26  --  30 September, 26',
      );
    },
  );

  test(
    'leave periods keep seven dates and Saturday boundaries across years',
    () {
      final now = DateTime(2026, 10, 20);
      expect(
        [for (final p in HrLeavePeriod.values) HrDateRange.leave(p, now).query],
        [
          {'first_date': '10-OCT-26', 'last_date': '16-OCT-26'},
          {'first_date': '17-OCT-26', 'last_date': '23-OCT-26'},
          {'first_date': '24-OCT-26', 'last_date': '30-OCT-26'},
        ],
      );
      expect(
        HrDateRange.leave(
          HrLeavePeriod.thisWeek,
          DateTime(2026, 10, 23),
        ).days.length,
        7,
      );
      expect(
        HrDateRange.leave(HrLeavePeriod.thisWeek, DateTime(2026, 10, 24)).first,
        DateTime(2026, 10, 24),
      );
      expect(
        HrDateRange.leave(HrLeavePeriod.thisWeek, DateTime(2026)).first,
        DateTime(2025, 12, 27),
      );
    },
  );

  test(
    'payroll picker is exactly six completed months including January rollover',
    () {
      final now = DateTime(2026, 1, 31);
      final months = HrPayrollMonth.available(now);
      expect(months.map((m) => m.first), [
        for (var m = 7; m <= 12; m++) DateTime(2025, m),
      ]);
      expect(months.every((m) => m.isAllowed(now)), isTrue);
      expect(HrPayrollMonth(DateTime(2026)).isAllowed(now), isFalse);
      expect(HrPayrollMonth(DateTime(2025, 6)).isAllowed(now), isFalse);
      expect(HrPayrollMonth(DateTime(2024, 2)).range.query, {
        'first_date': '01-FEB-24',
        'last_date': '29-FEB-24',
      });
      expect(months.last.label, 'MONTH: DEC-25');
    },
  );

  test(
    'native attendance categories retain order omit zeros and calculate percentages',
    () {
      final h = HrHarness();
      addTearDown(h.auth.dispose);
      final a = HrAttendance.fromJson(h.attendanceRow);
      expect(a.slices.map((s) => s.index), [0, 1, 2, 3, 4, 5, 6]);
      expect(a.legend(a.slices.first), 'On-Time Present (60 %)');
      expect(a.legend(a.slices.last), 'Both Late & Early (5 %)');
      final b = HrAttendance.fromJson({
        for (final key in HrAttendance.keys) key: key == 'leave' ? '3' : null,
      });
      expect(b.slices.single.index, 2);
      expect(b.legend(b.slices.single), 'On Leave (100 %)');
      expect(
        HrAttendance.fromJson({
          for (final key in HrAttendance.keys) key: '0.0',
        }).isEmpty,
        isTrue,
      );
    },
  );

  test(
    'fractional attendance uses native integer-truncated legend denominator',
    () {
      final a = HrAttendance.fromJson({
        for (final key in HrAttendance.keys)
          key: key == 'present' ? '1.5' : '0',
      });
      expect(a.legend(a.slices.single), 'On-Time Present (150 %)');
      final b = HrAttendance.fromJson({
        for (final key in HrAttendance.keys)
          key: key == 'present' ? '0.5' : '0',
      });
      expect(b.legend(b.slices.single), 'On-Time Present');
    },
  );

  test(
    'payroll optional tenth uses exact HALF_EVEN and lakh-crore grouping',
    () {
      final examples = <String, String>{
        '12345678.25': '৳ 1,23,45,678.2',
        '12.35': '৳ 12.4',
        '-12.25': '৳ -12.2',
        '999999.96': '৳ 10,00,000',
        '9007199254740993.15': '৳ 9,00,71,99,25,47,40,993.2',
        '1e3': '৳ 1,000',
        '0': '৳ 0',
        '-0.01': '৳ -0',
      };
      for (final e in examples.entries) {
        expect(
          nativeHrMoney(AdminChartNumber.parse(e.key)),
          e.value,
          reason: e.key,
        );
      }
    },
  );

  test(
    'leave join keeps native first-five name order last-match and Friday holiday rule',
    () {
      final range = HrDateRange.leave(
        HrLeavePeriod.thisWeek,
        DateTime(2026, 10, 20),
      );
      final rows = [
        hrDateRow('17-OCT-26', 'A', 'CL', holiday: '0'),
        hrDateRow('17-OCT-26', 'A', 'SL'),
        hrDateRow('18-OCT-26', 'A', 'AL'),
        hrDateRow('23-OCT-26', 'A', 'CL', holiday: '0'),
        hrDateRow('23-OCT-26', 'B', 'PL'),
        hrDateRow('23-OCT-26', 'B', 'SL', holiday: '0'),
        hrDateRow('18-oct-26', 'A', 'ignored'),
      ];
      final data = HrWeeklyLeave.fromRows(range, rows, [
        for (final name in ['A', 'B', 'C', 'D', 'E', 'F']) {'emp_name': name},
      ]);
      expect(data.employees.map((e) => e.name), ['A', 'B', 'C', 'D', 'E']);
      expect(data.employees.first.cells, ['SL', 'AL', '', '', '', '', '']);
      expect(data.employees[1].cells.last, 'PL');
      expect(data.hasDateRows, isTrue);
      final duplicate = HrWeeklyLeave.fromRows(range, rows, [
        {'emp_name': 'A'},
        {'emp_name': 'A'},
      ]);
      expect(duplicate.employees.first.cells, duplicate.employees.last.cells);
    },
  );

  test(
    'native no-leave message follows date rows even when name endpoint is empty',
    () {
      final range = HrDateRange.leave(
        HrLeavePeriod.thisWeek,
        DateTime(2026, 10, 20),
      );
      expect(HrWeeklyLeave.fromRows(range, [], []).hasDateRows, isFalse);
      expect(
        HrWeeklyLeave.fromRows(range, [
          hrDateRow('17-OCT-26', 'A', 'CL'),
        ], []).hasDateRows,
        isTrue,
      );
    },
  );

  test(
    'drawer destinations preserve native order and Leave Approval FLAG zero',
    () {
      expect(HrDestination.values.map((d) => d.route.module), [
        DashboardModule.hrDailyAttendance,
        DashboardModule.hrEmployeeAttendance,
        DashboardModule.hrAttendanceUpdateApproval,
        DashboardModule.hrLeaveRecord,
        DashboardModule.hrLeaveBalance,
        DashboardModule.hrLeaveApproval,
      ]);
      expect(HrDestination.leaveApproval.route.extras, {'FLAG': '0'});
      expect(
        HrDestination.values.take(5).every((d) => d.route.extras.isEmpty),
        isTrue,
      );
    },
  );

  test(
    'full load uses six native GETs in order with independently correct ranges',
    () async {
      final h = HrHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.transport.requests.clear();
      final data = await h.hr.load(
        h.auth.session!,
        h.auth.profile!,
        h.now,
        isCurrent: () => true,
      );
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getDeptEmpCount',
        'getAttendancePerc',
        'getEmpWithLeaveDate',
        'getEmpInLeave',
        'getPayrollData',
        'getAttWorkingDays',
      ]);
      expect(h.hrRequests.every((r) => r.method == 'GET'), isTrue);
      expect(h.hrRequests[0].uri.queryParameters, isEmpty);
      expect(h.hrRequests[1].uri.queryParameters, {
        'first_date': '20-OCT-26',
        'last_date': '20-OCT-26',
      });
      expect(h.hrRequests[2].uri.queryParameters, {
        'first_date': '17-OCT-26',
        'last_date': '23-OCT-26',
      });
      expect(h.hrRequests[4].uri.queryParameters, {
        'first_date': '01-SEP-26',
        'last_date': '30-SEP-26',
      });
      expect(
        h.hrRequests[5].uri.queryParameters,
        h.hrRequests[4].uri.queryParameters,
      );
      expect(data.counts.employees, '88');
      expect(data.payroll.workingDays, '25');
      expect(h.posts, isEmpty);
    },
  );

  test(
    'aggregate response last row wins rather than summing and null means zero',
    () async {
      final h = HrHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.transport.onGet =
          (uri) async => {
            'count': 2,
            'items': jsonEncode([
              {'total_depts': '99', 'total_emp': '1000'},
              {'total_depts': null, 'total_emp': 88},
            ]),
          };
      final result = await h.hr.counts(
        h.auth.session!,
        h.auth.profile!,
        isCurrent: () => true,
      );
      expect(result.departments, '0');
      expect(result.employees, '88');
    },
  );

  test(
    'empty and encoded empty responses produce valid zero aggregates',
    () async {
      final h = HrHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.transport.onGet = (uri) async => {'count': '0', 'items': null};
      final data = await h.hr.load(
        h.auth.session!,
        h.auth.profile!,
        h.now,
        isCurrent: () => true,
      );
      expect(data.counts.departments, '0');
      expect(data.attendance.isEmpty, isTrue);
      expect(data.leave.hasDateRows, isFalse);
      expect(nativeHrMoney(data.payroll.net), '৳ 0');
      expect(data.payroll.hours, '0');
    },
  );

  test(
    'malformed ORDS responses and missing numeric fields are retryable invalid data',
    () async {
      final h = HrHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      for (final response in <JsonMap>[
        {},
        {'count': -1, 'items': []},
        {'count': 1, 'items': []},
        {'count': 1, 'items': null},
        {'count': 1, 'items': 'not json'},
        hrPage([
          {'total_emp': '2'},
        ]),
        hrPage([
          {'total_depts': 'NaN', 'total_emp': '2'},
        ]),
        hrPage([
          {'total_depts': '-1', 'total_emp': '2'},
        ]),
      ]) {
        h.transport.onGet = (uri) async => response;
        await expectLater(
          h.hr.counts(h.auth.session!, h.auth.profile!, isCurrent: () => true),
          throwsA(
            isA<AppFailure>().having(
              (e) => e.kind,
              'kind',
              FailureKind.invalidData,
            ),
          ),
        );
      }
    },
  );

  test('failed initial chain stops before later native endpoints', () async {
    final h = HrHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    h.transport.requests.clear();
    h.transport.onGet = (uri) async {
      if (uri.path.endsWith('getAttendancePerc')) {
        throw const AppFailure('offline', kind: FailureKind.network);
      }
      return h.respond(uri);
    };
    await expectLater(
      h.hr.load(h.auth.session!, h.auth.profile!, h.now, isCurrent: () => true),
      throwsA(isA<AppFailure>()),
    );
    expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
      'getDeptEmpCount',
      'getAttendancePerc',
    ]);
  });

  test(
    'invalid date rows stop the leave chain before employee fetch',
    () async {
      final h = HrHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.transport.requests.clear();
      h.dateRows = [
        {'emp_name': 'A'},
      ];
      await expectLater(
        h.hr.leave(
          h.auth.session!,
          h.auth.profile!,
          HrDateRange.leave(HrLeavePeriod.thisWeek, h.now),
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getEmpWithLeaveDate',
      ]);
    },
  );

  test('stale response cancels the remaining six-read chain', () async {
    final h = HrHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    h.transport.requests.clear();
    var current = true;
    final pending = Completer<JsonMap>();
    h.transport.onGet = (uri) => pending.future;
    final operation = h.hr.load(
      h.auth.session!,
      h.auth.profile!,
      h.now,
      isCurrent: () => current,
    );
    final check = expectLater(operation, throwsA(isA<ObsoleteRequest>()));
    current = false;
    pending.complete(hrPage([h.departmentRow]));
    await check;
    expect(h.hrRequests.length, 1);
    await expectLater(
      h.hr.counts(h.auth.session!, h.auth.profile!, isCurrent: () => false),
      throwsA(isA<ObsoleteRequest>()),
    );
    expect(h.hrRequests.length, 1);
  });

  test(
    'HR role and card flags guard requests independently of Account mobile access',
    () async {
      final h = HrHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.transport.requests.clear();
      for (final changes in <JsonMap>[
        {'all_access_flag': '3'},
        {'hr_acc_active_flag': '0'},
        {'hr_dashboard': '0'},
        {'all_access_flag': '-1'},
      ]) {
        final profile = AccountProfile(AccountRole.admin, {
          ...h.adminData,
          ...changes,
        });
        await expectLater(
          h.hr.counts(h.auth.session!, profile, isCurrent: () => true),
          throwsA(isA<HrModuleUnavailable>()),
        );
      }
      expect(h.hrRequests, isEmpty);
      final hr = AccountProfile(AccountRole.admin, {
        ...h.adminData,
        'all_access_flag': '2',
      });
      expect(
        (await h.hr.counts(
          h.auth.session!,
          hr,
          isCurrent: () => true,
        )).employees,
        '88',
      );
    },
  );

  test(
    'optional admin ID absence is valid but a conflicting supplied ID is rejected',
    () async {
      final h = HrHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.transport.requests.clear();
      expect(h.auth.profile!.values.containsKey('usr_id'), isFalse);
      await h.hr.counts(
        h.auth.session!,
        h.auth.profile!,
        isCurrent: () => true,
      );
      final profile = AccountProfile(AccountRole.admin, {
        ...h.adminData,
        'usr_id': 'other',
      });
      await expectLater(
        h.hr.counts(h.auth.session!, profile, isCurrent: () => true),
        throwsA(isA<AppFailure>()),
      );
      expect(h.hrRequests.length, 1);
    },
  );

  test(
    'forced logout mobile-access denial and expiry cannot read HR data',
    () async {
      final h = HrHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.transport.requests.clear();
      for (final changes in <JsonMap>[
        {'usr_mob_forced_log_out_flag': '1'},
        {'usr_mob_app_access': '0'},
        {'exp_date': '19-OCT-26'},
      ]) {
        await expectLater(
          h.hr.counts(
            h.auth.session!,
            AccountProfile(AccountRole.admin, {...h.adminData, ...changes}),
            isCurrent: () => true,
          ),
          throwsA(isA<AccountAccessFailure>()),
        );
      }
      expect(h.hrRequests, isEmpty);
    },
  );

  test(
    'payroll rejects future or old months before requests and fails as a two-read unit',
    () async {
      final h = HrHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.transport.requests.clear();
      for (final date in [DateTime(2026, 10), DateTime(2026, 3)]) {
        await expectLater(
          h.hr.payroll(
            h.auth.session!,
            h.auth.profile!,
            HrPayrollMonth(date),
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
      }
      expect(h.hrRequests, isEmpty);
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getAttWorkingDays')) {
          throw const AppFailure('Work days unavailable');
        }
        return h.respond(uri);
      };
      await expectLater(
        h.hr.payroll(
          h.auth.session!,
          h.auth.profile!,
          HrPayrollMonth(DateTime(2026, 9)),
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getPayrollData',
        'getAttWorkingDays',
      ]);
    },
  );
}

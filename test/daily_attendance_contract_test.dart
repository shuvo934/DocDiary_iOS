import 'dart:convert';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/account_access.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/hr/daily_attendance/daily_attendance_models.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'daily_attendance_test_support.dart';
import 'hr_dashboard_test_support.dart';

void main() {
  test(
    'calendar includes exactly same day two months earlier through today',
    () {
      final c = AttendanceCalendar(DateTime(2026, 10, 22, 23, 59));
      expect(c.first, DateTime(2026, 8, 22));
      expect(c.last, DateTime(2026, 10, 22));
      expect(c.dayCount, 62);
      expect(c.at(61), c.last);
      expect(c.indexOf(DateTime(2026, 9, 1)), 10);
      expect(c.contains(DateTime(2026, 8, 21)), isFalse);
      expect(c.contains(DateTime(2026, 10, 23)), isFalse);
    },
  );
  test('calendar handles leap year month end and January rollover', () {
    expect(
      AttendanceCalendar(DateTime(2026, 10, 31)).first,
      DateTime(2026, 8, 30),
    );
    expect(
      AttendanceCalendar(DateTime(2026, 5, 31)).first,
      DateTime(2026, 3, 30),
    );
    final leap = AttendanceCalendar(DateTime(2024, 4, 30));
    expect(leap.first, DateTime(2024, 2, 29));
    expect(leap.moveMonth(DateTime(2024, 3, 31), -1), DateTime(2024, 2, 29));
    final jan = AttendanceCalendar(DateTime(2026, 1, 15));
    expect(jan.first, DateTime(2025, 11, 15));
    expect(jan.moveMonth(DateTime(2026, 1, 15), -1), DateTime(2025, 12, 15));
    expect(jan.canMove(jan.first, -1), isFalse);
    expect(jan.canMove(jan.last, 1), isFalse);
    expect(attendanceMonthLabel(jan.last), 'January, 2026');
  });
  test(
    'full read preserves native five GET order and uppercase date only',
    () async {
      final h = AttendanceHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.transport.requests.clear();
      final d = await h.daily.load(
        h.auth.session!,
        h.auth.profile!,
        h.now,
        isCurrent: () => true,
      );
      expect(h.dailyRequests.map((r) => r.uri.pathSegments.last), [
        'getBranches',
        'getDivision',
        'getDepartment',
        'getEmployee',
        'getDailyAttendance',
      ]);
      expect(h.dailyRequests.last.uri.queryParameters, {'p_date': '20-OCT-26'});
      expect(
        h.dailyRequests.take(4).every((r) => r.uri.queryParameters.isEmpty),
        isTrue,
      );
      expect(d.branches.first.name, 'None');
      expect(d.divisions.first.name, '...');
      expect(h.posts, isEmpty);
    },
  );
  test(
    'branch read uses four WithCoa GETs and retains branch choices',
    () async {
      final h = AttendanceHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      final initial = await h.daily.load(
        h.auth.session!,
        h.auth.profile!,
        h.now,
        isCurrent: () => true,
      );
      h.transport.requests.clear();
      final d = await h.daily.load(
        h.auth.session!,
        h.auth.profile!,
        h.now,
        branchId: '2',
        branches: initial.branches,
        isCurrent: () => true,
      );
      expect(h.dailyRequests.map((r) => r.uri.pathSegments.last), [
        'getDivisionWithCoa',
        'getDepartmentWithCoa',
        'getEmployeeWithCoa',
        'getDailyAttendanceWithCoa',
      ]);
      expect(
        h.dailyRequests.every((r) => r.uri.queryParameters['p_coa_id'] == '2'),
        isTrue,
      );
      expect(h.dailyRequests.last.uri.queryParameters, {
        'p_date': '20-OCT-26',
        'p_coa_id': '2',
      });
      expect(d.branches, initial.branches);
      expect(h.posts, isEmpty);
    },
  );
  test(
    'native None branch id 30 becomes global read without p_coa_id',
    () async {
      final h = AttendanceHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      await h.daily.load(
        h.auth.session!,
        h.auth.profile!,
        h.now,
        branchId: '30',
        isCurrent: () => true,
      );
      expect(h.dailyRequests.length, 5);
      expect(
        h.dailyRequests.every(
          (r) => !r.uri.queryParameters.containsKey('p_coa_id'),
        ),
        isTrue,
      );
    },
  );
  test('date-only change performs exactly one attendance request', () async {
    final h = AttendanceHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    await h.daily.attendance(
      h.auth.session!,
      h.auth.profile!,
      DateTime(2026, 9, 30),
      '2',
      isCurrent: () => true,
    );
    expect(h.dailyRequests.single.uri.queryParameters, {
      'p_date': '30-SEP-26',
      'p_coa_id': '2',
    });
  });
  test('future or old dates are rejected before any request', () async {
    final h = AttendanceHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    for (final date in [DateTime(2026, 10, 21), DateTime(2026, 8, 19)]) {
      await expectLater(
        h.daily.attendance(
          h.auth.session!,
          h.auth.profile!,
          date,
          '',
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
    }
    expect(h.dailyRequests, isEmpty);
  });
  test(
    'empty count produces empty data and never invents employee count',
    () async {
      final h = AttendanceHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.branches = [];
      h.divisions = [];
      h.departments = [];
      h.employees = [];
      h.records = [];
      final d = await h.daily.load(
        h.auth.session!,
        h.auth.profile!,
        h.now,
        isCurrent: () => true,
      );
      expect(d.rows, isEmpty);
      expect(d.branches, isEmpty);
      expect(d.divisions, isEmpty);
      expect(const AttendanceFilter().employeeCount(d), 0);
    },
  );
  test(
    'filters use IDs for duplicate names and count catalog employees',
    () async {
      final h = AttendanceHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      final d = await h.daily.load(
        h.auth.session!,
        h.auth.profile!,
        h.now,
        isCurrent: () => true,
      );
      const division = AttendanceFilter(division: '1');
      const department = AttendanceFilter(division: '1', department: '10');
      const selected = AttendanceFilter(
        division: '1',
        department: '10',
        employee: '12',
      );
      expect(division.employeeEnabled, isFalse);
      expect(department.employeeEnabled, isTrue);
      expect(department.employees(d).map((e) => e.id), ['', '11', '12']);
      expect(selected.rows(d).single.employee.id, '12');
      expect(selected.employeeCount(d), 2);
      expect(selected.rows(d.withRows([])), isEmpty);
      expect(selected.employeeCount(d.withRows([])), 2);
      expect(const AttendanceFilter().departmentEnabled, isFalse);
    },
  );
  test(
    'filter retention drops invalid child IDs after refreshed catalog',
    () async {
      final h = AttendanceHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      final d = await h.daily.load(
        h.auth.session!,
        h.auth.profile!,
        h.now,
        isCurrent: () => true,
      );
      expect(
        const AttendanceFilter(
          division: 'missing',
          department: '10',
        ).retainedIn(d).division,
        '',
      );
      expect(
        const AttendanceFilter(
          division: '1',
          department: '20',
        ).retainedIn(d).department,
        '',
      );
      expect(
        const AttendanceFilter(
          division: '1',
          department: '10',
          employee: '13',
        ).retainedIn(d).employee,
        '',
      );
      expect(
        const AttendanceFilter(
          division: '1',
          department: '10',
          employee: '12',
        ).retainedIn(d).employee,
        '12',
      );
    },
  );
  test('employee route preserves all five native intent extras', () {
    final h = AttendanceHarness();
    addTearDown(h.auth.dispose);
    final row = DailyAttendanceRow.fromJson(h.actualRecords.first);
    final route = row.route('2');
    expect(route.module, DashboardModule.hrEmployeeAttendance);
    expect(route.extras, {
      'DIV_ID': '1',
      'DEPT_ID': '10',
      'DESIG_ID': '7',
      'EMP_ID': '11',
      'COA_ID': '2',
    });
    expect(row.route('30').extras['COA_ID'], '');
  });
  test('encoded ORDS arrays and native null strings are supported', () async {
    final h = AttendanceHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    h.transport.onGet =
        (uri) async => {
          'count': '1',
          'items': jsonEncode([
            {
              ...h.actualRecords.first,
              'late_status': 'null',
              'early_status': null,
              'coa_name': null,
            },
          ]),
        };
    final d = await h.daily.attendance(
      h.auth.session!,
      h.auth.profile!,
      h.now,
      '',
      isCurrent: () => true,
    );
    expect(d.single.lateStatus, '');
    expect(d.single.earlyStatus, '');
    expect(d.single.location, '');
  });
  test(
    'malformed count or incomplete rows fail instead of showing No Data',
    () async {
      final h = AttendanceHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      for (final response in <JsonMap>[
        {'items': <Object?>[]},
        {'count': -1, 'items': <Object?>[]},
        {'count': 1, 'items': <Object?>[]},
        {'count': 1, 'items': 'broken'},
        hrPage([
          {'emp_id': '1'},
        ]),
      ]) {
        h.transport.onGet = (uri) async => response;
        await expectLater(
          h.daily.attendance(
            h.auth.session!,
            h.auth.profile!,
            h.now,
            '',
            isCurrent: () => true,
          ),
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
  test('a chain failure stops later calls', () async {
    final h = AttendanceHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    h.transport.onGet = (uri) async {
      if (uri.path.endsWith('getDivision')) throw const AppFailure('offline');
      return h.respond(uri);
    };
    await expectLater(
      h.daily.load(
        h.auth.session!,
        h.auth.profile!,
        h.now,
        isCurrent: () => true,
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(h.dailyRequests.map((r) => r.uri.pathSegments.last), [
      'getBranches',
      'getDivision',
    ]);
  });
  test('obsolete response is rejected before continuing the chain', () async {
    final h = AttendanceHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    var current = true;
    h.transport.onGet = (uri) async {
      final r = await h.respond(uri);
      current = false;
      return r;
    };
    await expectLater(
      h.daily.load(
        h.auth.session!,
        h.auth.profile!,
        h.now,
        isCurrent: () => current,
      ),
      throwsA(isA<ObsoleteRequest>()),
    );
    expect(h.dailyRequests.length, 1);
  });
  test('revoked HR and wrong account identity block reads', () async {
    final h = AttendanceHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    final profile = h.auth.profile!;
    final wrong = AccountProfile(AccountRole.admin, {
      ...profile.values,
      'usr_id': 'different',
    });
    final revoked = AccountProfile(AccountRole.admin, {
      ...profile.values,
      'hr_dashboard': '0',
    });
    await expectLater(
      h.daily.load(h.auth.session!, wrong, h.now, isCurrent: () => true),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      h.daily.load(h.auth.session!, revoked, h.now, isCurrent: () => true),
      throwsA(isA<HrModuleUnavailable>()),
    );
    expect(h.dailyRequests, isEmpty);
  });
  for (final entry
      in <String, String>{
        'usr_mob_forced_log_out_flag': '1',
        'usr_mob_app_access': '0',
        'exp_date': '01-JAN-26',
      }.entries) {
    test('${entry.key} account restriction blocks attendance reads', () async {
      final h = AttendanceHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      final profile = AccountProfile(AccountRole.admin, {
        ...h.auth.profile!.values,
        entry.key: entry.value,
      });
      await expectLater(
        h.daily.load(h.auth.session!, profile, h.now, isCurrent: () => true),
        throwsA(isA<AccountAccessFailure>()),
      );
      expect(h.dailyRequests, isEmpty);
    });
  }
}

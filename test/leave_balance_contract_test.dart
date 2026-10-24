import 'dart:async';
import 'dart:convert';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_repository.dart';
import 'package:docdiary_ios/features/hr/leave_balance/leave_balance_models.dart';
import 'package:docdiary_ios/features/hr/leave_balance/native_leave_balance_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'leave_balance_test_support.dart';

void main() {
  late LeaveBalanceHarness h;
  setUp(() async {
    h = LeaveBalanceHarness();
    await h.signIn();
    h.transport.requests.clear();
  });
  tearDown(() => h.auth.dispose());
  Future<LeaveBalanceSnapshot> load([
    LeaveBalanceSeed seed = leaveBalanceSeed,
  ]) async => await h.leaveBalance.load(
    h.auth.session!,
    h.auth.profile!,
    seed,
    const LeaveBalanceYear(2026),
    isCurrent: () => true,
  );
  test(
    'initial menu opens branches then divisions only without report reads',
    () async {
      final data = await load(const LeaveBalanceSeed());
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getBranches',
        'getDivision',
      ]);
      expect(h.hrRequests.every((r) => !r.uri.hasQuery), isTrue);
      expect(data.report, isNull);
      expect(data.catalog.branch.name, 'None');
      expect(data.catalog.divisions.map((r) => r.id), ['10', '20']);
      expect(data.catalog.department, isNull);
      expect(h.posts, isEmpty);
    },
  );
  test(
    'native seeded scoped seven-read chain uses exact query names and selected year end',
    () async {
      final data = await load();
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getBranches',
        'getDivisionWithCoa',
        'getDepartmentByDivCoa',
        'getDesignationsByDeptCoa',
        'getEmployeeByDesigCoa',
        'getLeaveBalance',
        'getLeaveChartData',
      ]);
      expect(h.hrRequests[2].uri.queryParameters, {
        'p_div_id': '10',
        'p_coa_id': '1',
      });
      expect(h.hrRequests[3].uri.queryParameters, {
        'p_div_id': '10',
        'p_dep_Id': '100',
        'p_coa_id': '1',
      });
      expect(h.hrRequests[4].uri.queryParameters, {
        'p_div_id': '10',
        'p_dep_id': '100',
        'p_desig_id': '7',
        'p_coa_id': '1',
      });
      for (final request in h.hrRequests.skip(5)) {
        expect(request.uri.queryParameters, {
          'now_date': '31-DEC-26',
          'p_emp_id': '11',
        });
      }
      expect(data.catalog.employee!.code, 'E-11');
      expect(data.report!.chart.map((r) => r.code), ['CL', 'EL']);
      expect(data.report!.rows.first.values, [
        'Casual Leave(CL)',
        '2',
        '10',
        '4',
        '0.5',
        '0',
        '8',
      ]);
    },
  );
  test(
    'None sentinel and blank branch use the unscoped native chain',
    () async {
      for (final branch in ['', '30']) {
        h.transport.requests.clear();
        await load(
          LeaveBalanceSeed(
            branch: branch,
            division: '10',
            department: '100',
            designation: '7',
            employee: '11',
          ),
        );
        expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
          'getBranches',
          'getDivision',
          'getDepartmentByDiv',
          'getDesignationsByDept',
          'getEmployeeByDesig',
          'getLeaveBalance',
          'getLeaveChartData',
        ]);
        expect(
          h.hrRequests.every(
            (r) => !r.uri.queryParameters.containsKey('p_coa_id'),
          ),
          isTrue,
        );
      }
    },
  );
  test(
    'scoped branch change reads only division and keeps the branch menu',
    () async {
      final original = (await load(const LeaveBalanceSeed())).catalog;
      h.transport.requests.clear();
      final data = await h.leaveBalance.catalog(
        h.auth.session!,
        h.auth.profile!,
        branch: original.branches[1],
        branches: original.branches,
        isCurrent: () => true,
      );
      expect(h.hrRequests.single.uri.pathSegments.last, 'getDivisionWithCoa');
      expect(data.branches, original.branches);
      expect(data.employee, isNull);
    },
  );
  test('individual cascade stages issue only their native endpoint', () async {
    await h.leaveBalance.departments(
      h.auth.session!,
      h.auth.profile!,
      '10',
      '',
      isCurrent: () => true,
    );
    await h.leaveBalance.designations(
      h.auth.session!,
      h.auth.profile!,
      '10',
      '100',
      '',
      isCurrent: () => true,
    );
    await h.leaveBalance.employees(
      h.auth.session!,
      h.auth.profile!,
      '10',
      '100',
      '7',
      '',
      isCurrent: () => true,
    );
    expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
      'getDepartmentByDiv',
      'getDesignationsByDept',
      'getEmployeeByDesig',
    ]);
  });
  test('catalogue ancestry clears lower menus and employee identity', () async {
    final data = (await load()).catalog;
    expect(data.withDivision(data.division!).department, isNull);
    expect(data.withDepartment(data.department!).designation, isNull);
    expect(data.withDesignation(data.designation!).employee, isNull);
    expect(data.withDivision(data.division!).employees, isEmpty);
  });
  test('year change reloads table then chart only, never catalogue', () async {
    final data = await h.leaveBalance.report(
      h.auth.session!,
      h.auth.profile!,
      '11',
      const LeaveBalanceYear(2020),
      isCurrent: () => true,
    );
    expect(data.year.label, 'YEAR: 2020');
    expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
      'getLeaveBalance',
      'getLeaveChartData',
    ]);
    expect(
      h.hrRequests.every(
        (r) => r.uri.queryParameters['now_date'] == '31-DEC-20',
      ),
      isTrue,
    );
  });
  test('route LAST_DATE uses its year but always sends 31-DEC', () {
    final seed = LeaveBalanceSeed.fromExtras({
      'COA_ID': '30',
      'DIV_ID': '10',
      'DEPT_ID': '100',
      'DESIG_ID': '7',
      'EMP_ID': '11',
      'LAST_DATE': '31-JAN-25',
    });
    expect(seed.branch, '');
    expect(LeaveBalanceYear.initial(seed, h.now).lastDate, '31-DEC-25');
    expect(
      LeaveBalanceYear.initial(
        const LeaveBalanceSeed(lastDate: '01-JAN-20'),
        h.now,
      ).year,
      2026,
    );
    expect(
      LeaveBalanceYear.initial(
        LeaveBalanceSeed(
          division: '10',
          department: '100',
          designation: '7',
          employee: '11',
          lastDate: 'bad',
        ),
        h.now,
      ).year,
      2026,
    );
  });
  test('picker has inclusive native 11-year range', () {
    expect(const LeaveBalanceYear(2016).isAllowed(h.now), isTrue);
    expect(const LeaveBalanceYear(2026).isAllowed(h.now), isTrue);
    expect(const LeaveBalanceYear(2015).isAllowed(h.now), isFalse);
    expect(const LeaveBalanceYear(2027).isAllowed(h.now), isFalse);
  });
  test(
    'a complete native future-year record seed keeps its year until manual selection',
    () async {
      const seed = LeaveBalanceSeed(
        division: '10',
        department: '100',
        designation: '7',
        employee: '11',
        lastDate: '31-JAN-27',
      );
      final year = LeaveBalanceYear.initial(seed, h.now);
      expect(year.year, 2027);
      expect(year.isAllowed(h.now), isFalse);
      await h.leaveBalance.load(
        h.auth.session!,
        h.auth.profile!,
        seed,
        year,
        isCurrent: () => true,
      );
      expect(h.hrRequests.last.uri.queryParameters['now_date'], '31-DEC-27');
    },
  );
  test(
    'native historical seed still loads when an employee is absent from active menus',
    () async {
      h.employees = [];
      final data = await load();
      expect(data.catalog.employee!.id, '11');
      expect(data.catalog.employee!.name, '');
      expect(data.report!.rows, isNotEmpty);
      expect(h.hrRequests.length, 7);
    },
  );
  test('restore clears only the first missing selection level', () async {
    final previous = (await load()).catalog;
    h.designations = [];
    h.transport.requests.clear();
    final data = await h.leaveBalance.restore(
      h.auth.session!,
      h.auth.profile!,
      previous,
      const LeaveBalanceYear(2026),
      isCurrent: () => true,
    );
    expect(data.catalog.department!.id, '100');
    expect(data.catalog.designation, isNull);
    expect(data.report, isNull);
    expect(h.hrRequests.length, 4);
  });
  test('restore reloads all seven endpoints retaining valid IDs', () async {
    final previous = (await load()).catalog;
    h.transport.requests.clear();
    final data = await h.leaveBalance.restore(
      h.auth.session!,
      h.auth.profile!,
      previous,
      const LeaveBalanceYear(2026),
      isCurrent: () => true,
    );
    expect(data.catalog.employee!.id, '11');
    expect(h.hrRequests.length, 7);
  });
  test('duplicate IDs are accepted with native list order', () async {
    h.divisions.add(Map<String, Object?>.of(h.divisions.first));
    h.employees.add(Map<String, Object?>.of(h.employees.first));
    final data = await load();
    expect(data.catalog.divisions.where((r) => r.id == '10').length, 2);
    expect(data.catalog.employees.where((r) => r.id == '11').length, 2);
  });
  test(
    'chart quantities from server are used directly, independently of table',
    () async {
      h.chartRows = [
        {
          'lc_short_code': 'X',
          'quantity': '10.5',
          'consumed': '3.5',
          'balance': '-2',
        },
      ];
      final data = await load();
      final row = data.report!.chart.single;
      expect([row.total, row.consumed, row.balance], [10.5, 3.5, -2]);
      expect(data.report!.rows.first.values.last, '8');
    },
  );
  test('native null numeric defaults and zero quantity exclusion', () async {
    h.chartRows = [
      {
        'lc_short_code': 'X',
        'quantity': null,
        'consumed': null,
        'balance': null,
      },
    ];
    h.balances = [
      {
        for (final key in [
          'lc_name',
          'lc_short_code',
          ...LeaveBalanceRow.quantityKeys,
        ])
          key: null,
      },
    ];
    final data = await load();
    expect(data.report!.chart, isEmpty);
    expect(data.report!.rows.single.values, [
      '()',
      '0',
      '0',
      '0',
      '0',
      '0',
      '0',
    ]);
  });
  test('native bar label formatter and three dataset colours are retained', () {
    expect(
      [
        leaveBalanceBarLabel(10),
        leaveBalanceBarLabel(1.5),
        leaveBalanceBarLabel(4.05),
      ],
      ['10', '1.5', '4'],
    );
    expect(leaveBalanceChartColors, [
      const Color(0xff8ceaff),
      const Color(0xffffd08c),
      const Color(0xffc0ff8c),
    ]);
  });
  for (final bad in <JsonMap>[
    <String, Object?>{},
    {'count': -1},
    {'count': 'bad'},
    {'count': 1, 'items': <Object?>[]},
    {'count': 1, 'items': 'bad'},
  ]) {
    test('malformed envelope ${jsonEncode(bad)} remains an error', () async {
      h.transport.onGet = (uri) async => bad;
      await expectLater(load(), throwsA(isA<AppFailure>()));
    });
  }
  test(
    'malformed numeric chart value fails with a bounded field message',
    () async {
      h.chartRows.first['quantity'] = 'private-invalid-value';
      await expectLater(
        load(),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.message,
            'message',
            allOf(
              contains('quantity'),
              isNot(contains('private-invalid-value')),
            ),
          ),
        ),
      );
    },
  );
  test(
    'encoded items and numeric scalar fields work without coercing missing keys',
    () async {
      h.transport.onGet =
          (uri) async =>
              uri.path.endsWith('/getLeaveBalance')
                  ? {
                    'count': '1',
                    'items': jsonEncode([balanceRow()]),
                  }
                  : h.respondBalance(uri);
      final data = await load();
      expect(data.report!.rows.length, 1);
      expect(
        () => LeaveBalanceRow({'lc_name': 'x'}),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'zero count skips unusable items and leaves both empty report states',
    () async {
      h.transport.onGet =
          (uri) async =>
              uri.path.endsWith('/getLeaveBalance') ||
                      uri.path.endsWith('/getLeaveChartData')
                  ? {'count': 0, 'items': 'ignored'}
                  : h.respondBalance(uri);
      final data = await load();
      expect(data.report!.rows, isEmpty);
      expect(data.report!.chart, isEmpty);
    },
  );
  test('table failure never dispatches the chart request', () async {
    h.balances = [{}];
    await expectLater(load(), throwsA(isA<AppFailure>()));
    expect(h.hrRequests.last.uri.pathSegments.last, 'getLeaveBalance');
  });
  test('obsolete reply stops the seven-read chain', () async {
    final gate = Completer<JsonMap>();
    var current = true;
    h.transport.onGet =
        (uri) =>
            uri.path.endsWith('/getDivisionWithCoa')
                ? gate.future
                : h.respondBalance(uri);
    final data = h.leaveBalance.load(
      h.auth.session!,
      h.auth.profile!,
      leaveBalanceSeed,
      const LeaveBalanceYear(2026),
      isCurrent: () => current,
    );
    while (h.hrRequests.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    current = false;
    gate.complete({'count': 0});
    await expectLater(data, throwsA(isA<ObsoleteRequest>()));
    expect(h.hrRequests.length, 2);
  });
  test(
    'forced logout, mobile/HR access, expiry and identity mismatch block reads',
    () async {
      for (final values in <JsonMap>[
        {'exp_date': '01-JAN-20'},
        {'usr_mob_forced_log_out_flag': '1'},
        {'usr_mob_app_access': '0'},
        {'hr_dashboard': '0'},
        {'usr_id': 'other'},
      ]) {
        final profile = AccountProfile(AccountRole.admin, {
          ...h.auth.profile!.values,
          ...values,
        });
        await expectLater(
          h.leaveBalance.load(
            h.auth.session!,
            profile,
            leaveBalanceSeed,
            const LeaveBalanceYear(2026),
            isCurrent: () => true,
          ),
          throwsA(anyOf(isA<AppFailure>(), isA<HrModuleUnavailable>())),
        );
      }
      expect(h.hrRequests, isEmpty);
    },
  );
}

import 'dart:convert';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/account_access.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_repository.dart';
import 'package:docdiary_ios/features/hr/employee_attendance/employee_attendance_models.dart';
import 'package:docdiary_ios/features/hr/employee_attendance/native_employee_attendance_chart.dart';
import 'package:docdiary_ios/features/hr/employee_attendance/native_employee_attendance_layout.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'employee_attendance_test_support.dart';
import 'hr_dashboard_test_support.dart';

void main() {
  late EmployeeAttendanceHarness h;
  setUp(() async {
    h = EmployeeAttendanceHarness();
    await h.signIn();
    h.transport.requests.clear();
  });
  tearDown(() => h.auth.dispose());
  Future<EmployeeAttendanceSnapshot> load([
    EmployeeAttendanceSeed seed = employeeSeed,
  ]) async => await h.employeeAttendance.load(
    h.auth.session!,
    h.auth.profile!,
    seed,
    EmployeeAttendanceMonth(h.now),
    isCurrent: () => true,
  );
  List<String> calls() =>
      h.hrRequests.map((r) => r.uri.pathSegments.last).toList();
  final four = [
    'getAttendanceCountEmp',
    'getAttReportData',
    'getAttStatus',
    'getAttWorkingDays',
  ];
  test(
    'unseeded and partial entries only fetch branches then divisions without artificial blank rows',
    () async {
      final data = await load(
        const EmployeeAttendanceSeed(branch: '2', division: '1'),
      );
      expect(calls(), ['getBranches', 'getDivision']);
      expect(data.catalog.branches.map((c) => c.name), [
        'None',
        'Example Branch',
      ]);
      expect(data.catalog.divisions.map((c) => c.id), ['1', '2']);
      expect(data.catalog.division, isNull);
      expect(data.catalog.department, isNull);
      expect(data.report, isNull);
    },
  );
  test(
    'unscoped seed runs all nine native requests in order and selects IDs',
    () async {
      final data = await load();
      expect(calls(), [
        'getBranches',
        'getDivision',
        'getDepartmentByDiv',
        'getDesignationsByDept',
        'getEmployeeByDesig',
        ...four,
      ]);
      expect(data.catalog.employee!.id, '11');
      expect(data.catalog.employee!.code, 'E-11');
      expect(data.catalog.employees.map((e) => e.name), [
        'Same Name',
        'Same Name',
      ]);
      final q = h.hrRequests.map((r) => r.uri.queryParameters).toList();
      expect(q[2], {'p_div_id': '1'});
      expect(q[3], {'p_dep_Id': '10', 'p_div_id': '1'});
      expect(q[4], {'p_dep_id': '10', 'p_div_id': '1', 'p_desig_id': '7'});
      expect(q[5], {
        'first_date': '01-OCT-26',
        'last_date': '31-OCT-26',
        'p_emp_id': '11',
      });
      for (final i in [6, 7]) {
        expect(q[i], {
          'first_date': '01-OCT-26',
          'last_date': '31-OCT-26',
          'emp_id': '11',
        });
      }
      expect(q[8], {'first_date': '01-OCT-26', 'last_date': '31-OCT-26'});
      expect(h.hrRequests.every((r) => r.method == 'GET'), isTrue);
    },
  );
  test('scoped seed applies COA only to the catalogue requests', () async {
    final data = await load(
      const EmployeeAttendanceSeed(
        branch: '2',
        division: '1',
        department: '10',
        designation: '7',
        employee: '12',
      ),
    );
    expect(calls(), [
      'getBranches',
      'getDivisionWithCoa',
      'getDepartmentByDivCoa',
      'getDesignationsByDeptCoa',
      'getEmployeeByDesigCoa',
      ...four,
    ]);
    expect(data.catalog.employee!.id, '12');
    expect(data.catalog.branch.name, 'Example Branch');
    for (final request in h.hrRequests.skip(1).take(4)) {
      expect(request.uri.queryParameters['p_coa_id'], '2');
    }
    for (final request in h.hrRequests.skip(5)) {
      expect(request.uri.queryParameters.containsKey('p_coa_id'), isFalse);
    }
  });
  test(
    'None 30 stays unscoped and real branch changes fetch divisions only',
    () async {
      final data = await load(
        const EmployeeAttendanceSeed(
          branch: '30',
          division: '1',
          department: '10',
          designation: '7',
          employee: '11',
        ),
      );
      expect(calls()[1], 'getDivision');
      h.transport.requests.clear();
      final branch = await h.employeeAttendance.catalog(
        h.auth.session!,
        h.auth.profile!,
        branch: data.catalog.branches[1],
        branches: data.catalog.branches,
        isCurrent: () => true,
      );
      expect(calls(), ['getDivisionWithCoa']);
      expect(branch.division, isNull);
      expect(branch.employee, isNull);
    },
  );
  test(
    'month-only change repeats exactly four reads using whole selected month',
    () async {
      await h.employeeAttendance.attendance(
        h.auth.session!,
        h.auth.profile!,
        '12',
        EmployeeAttendanceMonth(DateTime(2026, 9, 15)),
        isCurrent: () => true,
      );
      expect(calls(), four);
      for (final request in h.hrRequests) {
        expect(request.uri.queryParameters['first_date'], '01-SEP-26');
        expect(request.uri.queryParameters['last_date'], '30-SEP-26');
      }
    },
  );
  test(
    'a missing seed employee does not silently use an identically named employee',
    () async {
      await expectLater(
        load(
          const EmployeeAttendanceSeed(
            division: '1',
            department: '10',
            designation: '7',
            employee: 'missing',
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(calls().length, 5);
      expect(calls(), isNot(contains('getAttendanceCountEmp')));
    },
  );
  test(
    'inconsistent employee hierarchy is rejected before report requests',
    () async {
      h.transport.onGet =
          (uri) async =>
              uri.path.endsWith('getEmployeeByDesig')
                  ? hrPage([
                    {...h.employees.first, 'jsm_dept_id': '20'},
                  ])
                  : h.respond(uri);
      await expectLater(load(), throwsA(isA<AppFailure>()));
      expect(calls().length, 5);
    },
  );
  test(
    'restore retains partial filters and drops a removed employee without guessing',
    () async {
      final data = await load();
      h.transport.requests.clear();
      final partial = data.catalog.withDepartment(
        data.catalog.department!,
        data.catalog.designations,
      );
      final a = await h.employeeAttendance.restore(
        h.auth.session!,
        h.auth.profile!,
        partial,
        EmployeeAttendanceMonth(h.now),
        isCurrent: () => true,
      );
      expect(a.catalog.department!.id, '10');
      expect(a.catalog.designation, isNull);
      expect(calls().length, 4);
      h.employees.removeAt(0);
      h.transport.requests.clear();
      final b = await h.employeeAttendance.restore(
        h.auth.session!,
        h.auth.profile!,
        data.catalog,
        EmployeeAttendanceMonth(h.now),
        isCurrent: () => true,
      );
      expect(b.catalog.employee, isNull);
      expect(b.report, isNull);
      expect(calls().length, 5);
    },
  );
  test(
    'count zero preserves blank summary versus null aggregate values becoming zero',
    () async {
      h.counts = [];
      h.reports = [];
      h.statuses = [];
      h.working = [];
      final data = (await load()).report!;
      expect(data.chart.isEmpty, isTrue);
      expect(data.rows, isEmpty);
      expect(data.summary.values, List.filled(8, ''));
      expect(data.summary.workingDays, '');
      h.statuses = [
        {for (final key in EmployeeAttendanceSummary.keys) key: null},
      ];
      h.working = [
        {'work_days': 'null'},
      ];
      final next = (await load()).report!;
      expect(next.summary.values, List.filled(8, '0'));
      expect(next.summary.workingDays, '0');
    },
  );
  test(
    'last aggregate row wins and encoded ORDS arrays remain supported',
    () async {
      h.counts = [
        {for (final key in HrAttendance.keys) key: '1'},
        {
          for (final key in HrAttendance.keys)
            key: key == 'present' ? '2.9' : '0',
        },
      ];
      h.statuses = [
        {for (final key in EmployeeAttendanceSummary.keys) key: '1'},
        {for (final key in EmployeeAttendanceSummary.keys) key: '4'},
      ];
      h.working = [
        {'work_days': '20'},
        {'work_days': '21'},
      ];
      h.transport.onGet = (uri) async {
        final result = await h.respond(uri);
        return uri.path.contains('/hrm_dashboard/')
            ? {
              ...result,
              'count': '${result['count']}',
              'items': jsonEncode(result['items']),
            }
            : result;
      };
      final report = (await load()).report!;
      expect(
        employeeAttendanceChartCount(report.chart.slices.single.number.plot),
        '2',
      );
      expect(report.summary.values, List.filled(8, '4'));
      expect(report.summary.workingDays, '21');
    },
  );
  for (final bad in <JsonMap>[
    {},
    {'count': '-1'},
    {'count': 'oops'},
    {'count': 1},
    {'count': 1, 'items': []},
    {
      'count': 1,
      'items': [17],
    },
  ]) {
    test('malformed response is an error rather than No Data: $bad', () async {
      h.transport.onGet =
          (uri) async =>
              uri.path.endsWith('getBranches') ? bad : h.respond(uri);
      await expectLater(load(), throwsA(isA<AppFailure>()));
      expect(calls().length, 1);
    });
  }
  test(
    'failure and obsolete responses stop the sequential chain immediately',
    () async {
      var current = true;
      h.transport.onGet = (uri) async {
        final data = await h.respond(uri);
        if (uri.path.endsWith('getDepartmentByDiv')) current = false;
        return data;
      };
      await expectLater(
        h.employeeAttendance.load(
          h.auth.session!,
          h.auth.profile!,
          employeeSeed,
          EmployeeAttendanceMonth(h.now),
          isCurrent: () => current,
        ),
        throwsA(isA<ObsoleteRequest>()),
      );
      expect(calls().length, 3);
    },
  );
  test('invalid month is rejected before any attendance request', () async {
    for (final date in [DateTime(2026, 4), DateTime(2026, 11)]) {
      await expectLater(
        h.employeeAttendance.attendance(
          h.auth.session!,
          h.auth.profile!,
          '11',
          EmployeeAttendanceMonth(date),
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
    }
    expect(calls(), isEmpty);
  });
  test('access guard is reapplied before the next endpoint', () async {
    var current = true;
    h.transport.onGet = (uri) async {
      final data = await h.respond(uri);
      if (uri.path.endsWith('getAttReportData')) current = false;
      return data;
    };
    await expectLater(
      h.employeeAttendance.attendance(
        h.auth.session!,
        h.auth.profile!,
        '11',
        EmployeeAttendanceMonth(h.now),
        isCurrent: () => current,
      ),
      throwsA(isA<ObsoleteRequest>()),
    );
    expect(calls(), four.take(2).toList());
  });
  test(
    'forced logout, mobile restriction, expiry, HR revocation and wrong identity stop reads',
    () async {
      for (final changes in <JsonMap>[
        {'usr_mob_forced_log_out_flag': '1'},
        {'usr_mob_app_access': '0'},
        {'exp_date': '01-OCT-26'},
      ]) {
        await expectLater(
          h.employeeAttendance.load(
            h.auth.session!,
            AccountProfile(AccountRole.admin, {
              ...h.auth.profile!.values,
              ...changes,
            }),
            employeeSeed,
            EmployeeAttendanceMonth(h.now),
            isCurrent: () => true,
          ),
          throwsA(isA<AccountAccessFailure>()),
        );
      }
      await expectLater(
        h.employeeAttendance.load(
          h.auth.session!,
          AccountProfile(AccountRole.admin, {
            ...h.auth.profile!.values,
            'hr_dashboard': '0',
          }),
          employeeSeed,
          EmployeeAttendanceMonth(h.now),
          isCurrent: () => true,
        ),
        throwsA(isA<HrModuleUnavailable>()),
      );
      await expectLater(
        h.employeeAttendance.load(
          h.auth.session!,
          AccountProfile(AccountRole.admin, {
            ...h.auth.profile!.values,
            'usr_id': 'other',
          }),
          employeeSeed,
          EmployeeAttendanceMonth(h.now),
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(calls(), isEmpty);
    },
  );
  test('current inclusive six-month range handles January and leap years', () {
    final months = EmployeeAttendanceMonth.available(DateTime(2027, 1, 31));
    expect(months.map((m) => m.first), [
      for (var m = 8; m <= 13; m++) DateTime(2026, m),
    ]);
    expect(EmployeeAttendanceMonth(DateTime(2024, 2)).days, 29);
    final month = EmployeeAttendanceMonth(DateTime(2026, 10));
    expect(month.rangeLabel, '01 OCT, 2026 -- 31 OCT, 2026');
    expect(month.label, 'MONTH: OCT-26');
    expect(month.isAllowed(DateTime(2027, 3)), isTrue);
    expect(month.isAllowed(DateTime(2027, 4)), isFalse);
  });

  final statuses = <String, (String, EmployeeAttendanceRowKind)>{
    '': ('No Status', EmployeeAttendanceRowKind.normal),
    'L': ('In Leave', EmployeeAttendanceRowKind.leave),
    'LW': ('In Leave', EmployeeAttendanceRowKind.leave),
    'LH': ('In Leave', EmployeeAttendanceRowKind.leave),
    'H': ('Holiday', EmployeeAttendanceRowKind.offDay),
    'W': ('Weekend', EmployeeAttendanceRowKind.offDay),
    for (final code in ['PL', 'PLH', 'PLW'])
      code: ('Present & Leave', EmployeeAttendanceRowKind.presentLeave),
    'PAT': ('Attended training', EmployeeAttendanceRowKind.normal),
    for (final code in ['PHD', 'PWD', 'PLHD', 'PLWD'])
      code: ('Present & Day Off Taken', EmployeeAttendanceRowKind.normal),
    for (final code in ['P', 'PWWO', 'PHWC', 'PWWC', 'PA'])
      code: ('Present', EmployeeAttendanceRowKind.normal),
    'PW': ('Present & Off Day', EmployeeAttendanceRowKind.presentOffDay),
    'PH': ('Present & Off Day', EmployeeAttendanceRowKind.presentOffDay),
    'A': ('Absent', EmployeeAttendanceRowKind.absent),
    'PT': ('Tour', EmployeeAttendanceRowKind.normal),
    'SP': ('Suspend', EmployeeAttendanceRowKind.normal),
    '?': ('Absent', EmployeeAttendanceRowKind.absent),
  };
  test('complete native status matrix retains labels and background kinds', () {
    for (final entry in statuses.entries) {
      final row = EmployeeAttendanceRow.fromJson(
        employeeReportRow(status: entry.key),
      );
      expect((row.status, row.kind), entry.value, reason: entry.key);
    }
  });
  test(
    'Out Miss and numeric multi-station overrides retain native status and shift precedence',
    () {
      var row = EmployeeAttendanceRow.fromJson(
        employeeReportRow(status: 'L', leaveName: 'Sick Leave', outTime: ''),
      );
      expect(
        (row.status, row.kind, row.shift),
        ('Out Miss', EmployeeAttendanceRowKind.outMiss, ''),
      );
      row = EmployeeAttendanceRow.fromJson(
        employeeReportRow(
          status: 'L',
          leaveName: 'Sick Leave',
          inMachine: '02',
          outMachine: '3',
        ),
      );
      expect(
        (row.status, row.kind),
        ('Sick Leave', EmployeeAttendanceRowKind.multiStation),
      );
      expect(
        EmployeeAttendanceRow.fromJson(
          employeeReportRow(inMachine: '02', outMachine: '2'),
        ).kind,
        EmployeeAttendanceRowKind.normal,
      );
      expect(
        EmployeeAttendanceRow.fromJson(employeeReportRow(status: 'W')).shift,
        '',
      );
      expect(
        EmployeeAttendanceRow.fromJson(employeeReportRow(status: 'H')).shift,
        'Morning',
      );
      expect(
        EmployeeAttendanceRow.fromJson(
          employeeReportRow(status: '', outTime: ''),
        ).status,
        'No Status',
      );
      expect(
        employeeAttendanceStatusColor(EmployeeAttendanceRowKind.outMiss),
        const Color(0xff00c080),
      );
      expect(
        employeeAttendanceStatusTextColor(EmployeeAttendanceRowKind.offDay),
        Colors.black,
      );
    },
  );
  test(
    'Late equality is inclusive, Early equality is exclusive, and twelve-hour dates format correctly',
    () {
      var row = EmployeeAttendanceRow.fromJson(
        employeeReportRow(inTime: '09:00:00 AM', outTime: '05:00:00 PM'),
      );
      expect((row.late, row.early), (true, false));
      expect(row.statusLabel, 'Present\n(Late)');
      row = EmployeeAttendanceRow.fromJson(
        employeeReportRow(
          inTime: '12:00:00 AM',
          lateAfter: '12:00:01 AM',
          outTime: '12:00:00 PM',
          earlyBefore: '12:00:01 PM',
        ),
      );
      expect((row.late, row.early), (false, true));
      expect((row.inTime, row.outTime), ('12:00 AM', '12:00 PM'));
      row = EmployeeAttendanceRow.fromJson(
        employeeReportRow(inTime: '09:00:01 AM', outTime: '04:59:59 PM'),
      );
      expect(row.statusLabel, 'Present\n(Late)\n(Early)');
    },
  );
  test(
    'malformed or missing times use raw display and never reuse the in threshold for out time',
    () {
      final row = EmployeeAttendanceRow.fromJson(
        employeeReportRow(
          inTime: 'invalid',
          lateAfter: 'null',
          outTime: '04:00:00 PM',
          earlyBefore: null,
        ),
      );
      expect(
        (row.inTime, row.outTime, row.late, row.early),
        ('invalid', '04:00:00 PM', false, false),
      );
      expect(
        (row.inLatitude, row.inLongitude, row.outLatitude, row.outLongitude),
        ('23.7', '90.4', '', ''),
      );
    },
  );
  test(
    'missing report fields, malformed machine IDs and invalid chart numbers fail clearly',
    () async {
      expect(
        () => EmployeeAttendanceRow.fromJson(
          {...employeeReportRow()}..remove('osm_name'),
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () =>
            EmployeeAttendanceRow.fromJson(employeeReportRow(inMachine: 'bad')),
        throwsA(isA<AppFailure>()),
      );
      for (final number in ['-1', 'NaN', 'Infinity', '1e90']) {
        h.counts = [
          {
            for (final key in HrAttendance.keys)
              key: key == 'present' ? number : '0',
          },
        ];
        await expectLater(load(), throwsA(isA<AppFailure>()));
      }
    },
  );
}

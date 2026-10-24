import 'dart:async';
import 'dart:convert';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_repository.dart';
import 'package:docdiary_ios/features/hr/leave_record/leave_record_models.dart';
import 'package:docdiary_ios/features/hr/leave_record/native_leave_record_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'leave_record_test_support.dart';

void main() {
  late LeaveRecordHarness h;
  setUp(() async {
    h = LeaveRecordHarness();
    await h.signIn();
    h.transport.requests.clear();
  });
  tearDown(() => h.auth.dispose());
  Future<LeaveRecordData> load({
    bool Function()? current,
    AccountProfile? profile,
    LeaveRecordMonth? month,
  }) async => await h.leaveRecord.load(
    h.auth.session!,
    profile ?? h.auth.profile!,
    month ?? LeaveRecordMonth(h.now),
    isCurrent: current ?? () => true,
  );
  test(
    'native initial order is branches, division, departments, employees, leave records with month only',
    () async {
      final data = await load();
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getBranches',
        'getDivision',
        'getDepartment',
        'getEmployee',
        'getLeaveRecord',
      ]);
      expect(h.hrRequests.take(4).every((r) => !r.uri.hasQuery), isTrue);
      expect(h.hrRequests.last.uri.queryParameters, {
        'first_date': '01-OCT-26',
        'last_date': '31-OCT-26',
      });
      expect(data.branches.map((r) => r.name), [
        'None',
        'Sample Centre',
        'Other Centre',
      ]);
      expect(data.divisions.map((r) => r.name), [
        '...',
        'Division A',
        'Division B',
      ]);
      expect(data.rows.map((r) => r.id), ['41', '42', '43', '44']);
      expect(
        h.hrRequests.every(
          (r) =>
              r.method == 'GET' &&
              r.uri.host == h.auth.session!.center.baseUri.host,
        ),
        isTrue,
      );
    },
  );
  test(
    'branch change uses four WithCoa reads and preserves cached branch choices',
    () async {
      final initial = await load();
      h.transport.requests.clear();
      final data = await h.leaveRecord.load(
        h.auth.session!,
        h.auth.profile!,
        LeaveRecordMonth(h.now),
        branch: initial.branches[1],
        branches: initial.branches,
        isCurrent: () => true,
      );
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getDivisionWithCoa',
        'getDepartmentWithCoa',
        'getEmployeeWithCoa',
        'getLeaveRecordWithCoa',
      ]);
      for (final request in h.hrRequests.take(3)) {
        expect(request.uri.queryParameters, {'p_coa_id': '1'});
      }
      expect(h.hrRequests.last.uri.queryParameters, {
        'p_coa_id': '1',
        'first_date': '01-OCT-26',
        'last_date': '31-OCT-26',
      });
      expect(data.rows.map((r) => r.id), ['41', '42', '43']);
      expect(data.branch.name, 'Sample Centre');
      expect(data.branches, initial.branches);
    },
  );
  test('None sentinel 30 reloads all five unscoped reads', () async {
    await h.leaveRecord.load(
      h.auth.session!,
      h.auth.profile!,
      LeaveRecordMonth(h.now),
      branch: const LeaveRecordChoice('30', 'None'),
      isCurrent: () => true,
    );
    expect(h.hrRequests.length, 5);
    expect(
      h.hrRequests.every((r) => !r.uri.queryParameters.containsKey('p_coa_id')),
      isTrue,
    );
  });
  test(
    'month refresh fetches one leave endpoint and serialises first/last days accurately',
    () async {
      await h.leaveRecord.records(
        h.auth.session!,
        h.auth.profile!,
        LeaveRecordMonth(DateTime(2026, 11)),
        branch: '2',
        isCurrent: () => true,
      );
      expect(
        h.hrRequests.single.uri.pathSegments.last,
        'getLeaveRecordWithCoa',
      );
      expect(h.hrRequests.single.uri.queryParameters, {
        'p_coa_id': '2',
        'first_date': '01-NOV-26',
        'last_date': '30-NOV-26',
      });
    },
  );
  test(
    'ID-based local filter cascade handles duplicate names and clear rows without network requests',
    () async {
      final data = await load();
      h.transport.requests.clear();
      const empty = LeaveRecordFilter(),
          div = LeaveRecordFilter(division: '10'),
          dep = LeaveRecordFilter(division: '10', department: '100'),
          emp = LeaveRecordFilter(
            division: '10',
            department: '100',
            employee: '12',
          );
      expect(empty.departmentEnabled || empty.employeeEnabled, isFalse);
      expect(div.departmentEnabled, isTrue);
      expect(div.employeeEnabled, isFalse);
      expect(div.departments(data).map((c) => c.id), ['', '100', '101']);
      expect(dep.employees(data).map((c) => c.id), ['', '11', '12']);
      expect(div.rows(data).map((r) => r.id), ['41', '42', '43']);
      expect(dep.rows(data).map((r) => r.id), ['41', '42']);
      expect(emp.rows(data).single.id, '42');
      expect(h.hrRequests, isEmpty);
    },
  );
  test(
    'restoring invalid selected IDs clears only the obsolete filter levels',
    () async {
      final data = await load();
      expect(
        const LeaveRecordFilter(
          division: '99',
          department: '100',
          employee: '11',
        ).restored(data).division,
        '',
      );
      final a = const LeaveRecordFilter(
        division: '10',
        department: '200',
        employee: '21',
      ).restored(data);
      expect(a.division, '10');
      expect(a.department, '');
      expect(a.employee, '');
      final b = const LeaveRecordFilter(
        division: '10',
        department: '100',
        employee: '13',
      ).restored(data);
      expect(b.department, '100');
      expect(b.employee, '');
    },
  );
  test(
    'status counts count applications, not days; unknown status remains in total only',
    () {
      final rows = [
        for (final status in ['0', '1', '2', '3', '9'])
          LeaveRecordRow(
            leaveRecordRow(id: status, status: status, days: '10'),
          ),
      ];
      final counts = LeaveRecordCounts(rows);
      expect(counts.entries, {
        'Total Leave Application': 5,
        'Pending': 1,
        'Approved': 1,
        'Rejected': 1,
        'Cancel Approved Leave': 1,
      });
      expect(rows.map((r) => r.statusLabel), [
        'PENDING',
        'APPROVED',
        'REJECTED',
        'CANCEL APPROVED LEAVE',
        '9',
      ]);
      expect(leaveRecordStatusColor('0'), DocColors.muted);
      expect(leaveRecordStatusColor('1'), DocColors.greenSea);
      expect(leaveRecordStatusColor('2'), const Color(0xffc23616));
      expect(leaveRecordStatusColor('3'), const Color(0xffff7675));
    },
  );
  test(
    'row routes preserve the two native Intent branches and exact extras',
    () {
      final pending = LeaveRecordRow(
        leaveRecordRow(),
      ).route(LeaveRecordMonth(h.now));
      expect(pending.module, DashboardModule.hrLeaveApproval);
      expect(pending.extras, {
        'LA_ID': '41',
        'LA_EMP_ID': '11',
        'LA_APP_CODE': 'LR-2026-41',
        'FLAG': '1',
      });
      final approved = LeaveRecordRow(
        leaveRecordRow(status: '1'),
      ).route(LeaveRecordMonth(h.now));
      expect(approved.module, DashboardModule.hrLeaveBalance);
      expect(approved.extras, {
        'COA_ID': '1',
        'DIV_ID': '10',
        'DEPT_ID': '100',
        'DESIG_ID': '7',
        'EMP_ID': '11',
        'LAST_DATE': '31-OCT-26',
      });
    },
  );
  for (final pair in [
    (1, '1st'),
    (2, '2nd'),
    (3, '3rd'),
    (4, '4th'),
    (11, '11th'),
    (12, '12th'),
    (13, '13th'),
    (21, '21st'),
    (22, '22nd'),
    (23, '23rd'),
    (31, '31st'),
  ]) {
    test('native ordinal ${pair.$1}', () {
      final date = '${pair.$1.toString().padLeft(2, '0')}-OCT';
      expect(
        LeaveRecordRow(leaveRecordRow(from: date, to: date)).dateLabel,
        '${pair.$2} OCT',
      );
    });
  }
  test(
    'same-month, cross-month and singular/plural leave labels match adapter',
    () {
      expect(
        LeaveRecordRow(
          leaveRecordRow(from: '01-OCT', to: '03-OCT', days: '3'),
        ).dateLabel,
        '1st to 3rd (OCT)',
      );
      expect(
        LeaveRecordRow(leaveRecordRow(from: '30-SEP', to: '02-OCT')).dateLabel,
        '30th SEP to 2nd OCT',
      );
      expect(LeaveRecordRow(leaveRecordRow()).daysLabel, '(1 Day)');
      expect(
        LeaveRecordRow(leaveRecordRow(days: '0.5')).daysLabel,
        '(0.5 Days)',
      );
      expect(
        LeaveRecordRow(
          leaveRecordRow(from: '24-OCT-26', to: '24-OCT-26'),
        ).dateLabel,
        '24th OCT',
      );
    },
  );
  test(
    'null text fields stay blank, typed numeric scalars and encoded items parse',
    () async {
      final row = {
        for (final key in LeaveRecordRow.keys) key: null,
        'la_id': 41,
        'emp_id': 11,
        'la_approved': 1,
        'la_leave_days': 1.0,
      };
      h.transport.onGet =
          (uri) async => {
            'count': '1',
            'items': jsonEncode([row]),
          };
      final data = await h.leaveRecord.records(
        h.auth.session!,
        h.auth.profile!,
        LeaveRecordMonth(h.now),
        isCurrent: () => true,
      );
      expect(data.single.id, '41');
      expect(data.single.statusLabel, 'APPROVED');
      expect(data.single.value('emp_name'), '');
      expect(data.single.dateLabel, '');
      expect(data.single.daysLabel, '(1 Day)');
    },
  );
  for (final bad in <JsonMap>[
    {},
    {'count': -1},
    {'count': 'bad'},
    {'count': 1},
    {'count': 1, 'items': []},
    {'count': 1, 'items': 'bad'},
    {
      'count': 1,
      'items': [<String, Object?>{}],
    },
    {
      'count': 1,
      'items': [
        {...leaveRecordRow(), 'la_id': null},
      ],
    },
    {
      'count': 1,
      'items': [
        {...leaveRecordRow(), 'la_from_date': '31-FEB'},
      ],
    },
    {
      'count': 1,
      'items': [
        {...leaveRecordRow(), 'emp_name': true},
      ],
    },
  ]) {
    test(
      'malformed record response ${jsonEncode(bad)} fails without usable rows',
      () async {
        h.transport.onGet = (uri) async => bad;
        await expectLater(
          h.leaveRecord.records(
            h.auth.session!,
            h.auth.profile!,
            LeaveRecordMonth(h.now),
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
      },
    );
  }
  test(
    'zero count ignores unusable items and does not fabricate leave applications',
    () async {
      h.transport.onGet = (uri) async => {'count': '0', 'items': 'ignored'};
      expect(
        await h.leaveRecord.records(
          h.auth.session!,
          h.auth.profile!,
          LeaveRecordMonth(h.now),
          isCurrent: () => true,
        ),
        isEmpty,
      );
    },
  );
  test(
    'catalogue parse error aborts the remaining native request chain',
    () async {
      h.departments = [
        {'dept_id': '100', 'dept_name': 'Missing parent'},
      ];
      await expectLater(load(), throwsA(isA<AppFailure>()));
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getBranches',
        'getDivision',
        'getDepartment',
      ]);
    },
  );
  test(
    'employee identity can appear in two valid department contexts',
    () async {
      h.employees.add(leaveEmployee('11', 'Same Name', '20', '200'));
      final data = await load();
      expect(data.employees.where((e) => e.id == '11').length, 2);
    },
  );
  test(
    'duplicate leave IDs are rejected before an ambiguous row can be tapped',
    () async {
      h.records.add(leaveRecordRow());
      await expectLater(load(), throwsA(isA<AppFailure>()));
    },
  );
  test(
    'month bounds preserve native Calendar rollover, inclusive months and leap years',
    () {
      List<String> values(DateTime now) =>
          LeaveRecordMonth.available(
            now,
          ).map((m) => '${m.first.year}-${m.first.month}').toList();
      expect(values(DateTime(2026, 10, 24)), [
        '2026-8',
        '2026-9',
        '2026-10',
        '2026-11',
        '2026-12',
      ]);
      expect(values(DateTime(2026, 1, 31)), [
        '2025-11',
        '2025-12',
        '2026-1',
        '2026-2',
        '2026-3',
      ]);
      expect(values(DateTime(2026, 12, 31)), [
        '2026-10',
        '2026-11',
        '2026-12',
        '2027-1',
      ]);
      expect(values(DateTime(2024, 2, 29)), [
        '2023-12',
        '2024-1',
        '2024-2',
        '2024-3',
      ]);
      expect(LeaveRecordMonth(DateTime(2024, 2)).query, {
        'first_date': '01-FEB-24',
        'last_date': '29-FEB-24',
      });
    },
  );
  test(
    'invalid calendar month and obsolete entry reject before any HR read',
    () async {
      await expectLater(
        load(month: LeaveRecordMonth(DateTime(2020, 1))),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        load(current: () => false),
        throwsA(isA<ObsoleteRequest>()),
      );
      expect(h.hrRequests, isEmpty);
    },
  );
  test(
    'late obsolete division response cannot continue the catalogue chain',
    () async {
      final gate = Completer<JsonMap>();
      var current = true;
      h.transport.onGet =
          (uri) =>
              uri.path.endsWith('/getDivision')
                  ? gate.future
                  : h.respondLeave(uri);
      final future = load(current: () => current);
      while (!h.hrRequests.any((r) => r.uri.path.endsWith('/getDivision'))) {
        await Future<void>.delayed(Duration.zero);
      }
      current = false;
      gate.complete({'count': 0});
      await expectLater(future, throwsA(isA<ObsoleteRequest>()));
      expect(h.hrRequests.length, 2);
    },
  );
  test(
    'expired, forced, mobile access, HR permission and mismatched identity block reads',
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
          load(profile: profile),
          throwsA(anyOf(isA<AppFailure>(), isA<HrModuleUnavailable>())),
        );
      }
      expect(h.hrRequests, isEmpty);
    },
  );
}

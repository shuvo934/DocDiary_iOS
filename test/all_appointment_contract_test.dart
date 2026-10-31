import 'dart:async';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/appointments/all_schedule/all_appointment_models.dart';
import 'package:docdiary_ios/features/appointments/unit_schedule/unit_appointment_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'all_appointment_test_support.dart';
import 'unit_appointment_test_support.dart';

void main() {
  late AllAppointmentHarness h;
  setUp(() async {
    h = AllAppointmentHarness();
    await h.signIn();
    h.transport.requests.clear();
  });
  tearDown(() => h.auth.dispose());
  const department = UnitAppointmentChoice(
    '8',
    'Speech & Language Therapy Department',
  );
  const unit = UnitAppointmentChoice('2', 'Outpatient Unit');
  const departments = [
    department,
    UnitAppointmentChoice('99', 'Physiotherapy Department'),
  ];
  const units = [unit, UnitAppointmentChoice('3', 'Therapy Unit')];
  AccountProfile profile([JsonMap changes = const {}]) =>
      AccountProfile(AccountRole.doctor, {...h.doctorData, ...changes});
  Future<List<UnitAppointmentChoice>> loadDepartments({
    bool Function()? current,
    AccountProfile? doctor,
  }) async => h.allRepository.departments(
    h.auth.session!,
    doctor ?? profile(),
    isCurrent: current ?? () => true,
  );
  Future<AllAppointmentTotals> totals({
    DateTime? day,
    UnitAppointmentChoice selected = department,
  }) async => h.allRepository.totals(
    h.auth.session!,
    profile(),
    day ?? h.now,
    selected,
    departments,
    isCurrent: () => true,
  );
  Future<UnitAppointmentSnapshot> doctors({
    DateTime? day,
    UnitAppointmentChoice selectedDepartment = department,
    UnitAppointmentChoice selectedUnit = unit,
    List<UnitAppointmentChoice> allowedUnits = units,
    bool Function()? current,
  }) async => h.allRepository.doctors(
    h.auth.session!,
    profile(),
    day ?? h.now,
    selectedDepartment,
    departments,
    selectedUnit,
    allowedUnits,
    isCurrent: current ?? () => true,
  );

  test(
    'Manager access is independent of Unit Head and ordinary doctors cannot open All',
    () {
      expect(
        allAppointmentAllowed(profile({'doc_deptd_head_flag': '0'})),
        isTrue,
      );
      expect(
        allAppointmentAllowed(profile({'doc_manager_flag': '0'})),
        isFalse,
      );
      expect(
        allAppointmentAllowed(AccountProfile(AccountRole.admin, h.adminData)),
        isTrue,
      );
      expect(
        allAppointmentAllowed(
          AccountProfile(AccountRole.admin, {
            ...h.adminData,
            'all_access_flag': '2',
            'hr_appointment_active': '0',
          }),
        ),
        isFalse,
      );
      expect(
        allAppointmentAllowed(
          AccountProfile(AccountRole.admin, {
            ...h.adminData,
            'all_access_flag': '3',
            'acc_appointment_active': '0',
          }),
        ),
        isFalse,
      );
    },
  );
  test(
    'departments, units, department totals and schedules use exact native GET contracts',
    () async {
      await loadDepartments();
      await h.allRepository.units(
        h.auth.session!,
        profile(),
        department,
        departments,
        isCurrent: () => true,
      );
      await totals();
      await doctors();
      expect(
        h.departmentReads.single.path,
        endsWith('/all_appointment/getDeptd'),
      );
      expect(h.departmentReads.single.queryParameters, isEmpty);
      expect(h.unitReads.single.queryParameters, {'deptd_id': '8'});
      expect(
        h.totalReads.single.path,
        endsWith('/all_appointment/getDeptdSchCount'),
      );
      expect(h.totalReads.single.queryParameters, {
        'deptd_id': '8',
        'pdate': '24-OCT-26',
      });
      expect(h.scheduleReads.single.queryParameters, {
        'pdate': '24-OCT-26',
        'depts_id': '2',
        'deptd_id': '8',
      });
      expect(h.posts, isEmpty);
    },
  );
  test(
    'Manager can select a permitted department other than own department',
    () async {
      await h.allRepository.units(
        h.auth.session!,
        profile(),
        departments.last,
        departments,
        isCurrent: () => true,
      );
      expect(h.unitReads.single.queryParameters['deptd_id'], '99');
    },
  );
  for (final changes in [
    <String, Object?>{'doc_manager_flag': '0'},
    {'doc_code': 'OTHER'},
    {'doc_id': ''},
    {'access_flag': '0'},
    {'fl_flag': '1'},
    {'exp_date': '01-JAN-20'},
  ]) {
    test(
      'invalid permission, identity or access $changes blocks catalogue GET',
      () async {
        await expectLater(
          loadDepartments(doctor: profile(changes)),
          throwsA(anyOf(isA<AppFailure>(), isA<AllAppointmentUnavailable>())),
        );
        expect(h.departmentReads, isEmpty);
      },
    );
  }
  test('an obsolete caller is rejected before sending any GET', () async {
    await expectLater(
      loadDepartments(current: () => false),
      throwsA(isA<ObsoleteRequest>()),
    );
    expect(h.departmentReads, isEmpty);
  });
  test(
    'a late department response is rejected after caller becomes obsolete',
    () async {
      final pending = Completer<JsonMap>();
      h.pendingDepartments = pending;
      var current = true;
      final loading = loadDepartments(current: () => current);
      current = false;
      pending.complete({'count': 0});
      await expectLater(loading, throwsA(isA<ObsoleteRequest>()));
    },
  );
  test('department and unit IDs must belong to current catalogues', () async {
    await expectLater(
      totals(selected: const UnitAppointmentChoice('7', 'foreign')),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      doctors(selectedDepartment: const UnitAppointmentChoice('7', 'foreign')),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      doctors(selectedUnit: const UnitAppointmentChoice('9', 'foreign')),
      throwsA(isA<AppFailure>()),
    );
    expect(h.totalReads, isEmpty);
    expect(h.scheduleReads, isEmpty);
  });
  test(
    'both totals and schedules enforce the current native month window',
    () async {
      final old = DateTime(2026, 8, 1);
      await expectLater(totals(day: old), throwsA(isA<AppFailure>()));
      await expectLater(doctors(day: old), throwsA(isA<AppFailure>()));
      expect(h.totalReads, isEmpty);
      expect(h.scheduleReads, isEmpty);
    },
  );
  test(
    'department totals differ from unit totals and subtract busy schedules',
    () async {
      final data = await totals(), schedule = await doctors();
      expect(data.appointments, 9);
      expect(data.blank, 3);
      expect(schedule.appointmentCount, 4);
      expect(schedule.blankCount, 2);
      expect(schedule.filtered('10').single.id, '10');
      expect(schedule.appointmentCount, 4);
    },
  );
  test(
    'zero total overrides blank count while native nonzero subtraction remains exact',
    () {
      expect(
        AllAppointmentTotals.fromData({
          'deptd_sch_count': '3',
          'deptd_tot_count': '0',
          'deptd_busy_count': '2',
        }).blank,
        0,
      );
      expect(
        AllAppointmentTotals.fromData({
          'deptd_sch_count': '3',
          'deptd_tot_count': '1',
          'deptd_busy_count': '2',
        }).blank,
        -4,
      );
      expect(
        AllAppointmentTotals.fromData({
          'deptd_sch_count': null,
          'deptd_tot_count': 'null',
          'deptd_busy_count': null,
        }).blank,
        0,
      );
    },
  );
  test(
    'native totals use last returned row and count zero becomes zero totals',
    () async {
      h.totalsResponse = {
        'count': 2,
        'items': [
          {
            'deptd_sch_count': '1',
            'deptd_tot_count': '3',
            'deptd_busy_count': '1',
          },
          {
            'deptd_sch_count': '4',
            'deptd_tot_count': '8',
            'deptd_busy_count': '2',
          },
        ],
      };
      var data = await totals();
      expect(data.appointments, 4);
      expect(data.blank, 2);
      h.totalsResponse = {'count': 0};
      data = await totals();
      expect(data.appointments, 0);
      expect(data.blank, 0);
    },
  );
  test(
    'encoded arrays preserve Bangla, duplicate labels, exact IDs and slot order',
    () async {
      h.encodedArrays = true;
      h.departmentRows = [
        {'deptd_id': '8', 'deptd_name': 'থেরাপি বিভাগ'},
        {'deptd_id': '99', 'deptd_name': 'থেরাপি বিভাগ'},
      ];
      final list = await loadDepartments();
      expect(list.map((c) => c.id), ['8', '99']);
      expect(list.first.name, 'থেরাপি বিভাগ');
      expect(() => list.clear(), throwsUnsupportedError);
      expect((await totals()).blank, 3);
      final result = await doctors();
      expect(result.doctors.first.initialScheduleIndex(h.now), 3);
      expect(
        result.doctors.first.schedules.first.value('schedule_time'),
        '08:00 AM',
      );
    },
  );
  for (final response in [
    <String, Object?>{},
    {'count': -1},
    {'count': 'bad'},
    {'count': 1},
    {'count': 1, 'items': <Object?>[]},
    {
      'count': 1,
      'items': [
        {'deptd_id': 'invalid', 'deptd_name': 'name'},
      ],
    },
  ]) {
    test('malformed department response $response fails closed', () async {
      h.departmentsResponse = response;
      await expectLater(loadDepartments(), throwsA(isA<AppFailure>()));
    });
  }
  for (final row in [
    <String, Object?>{},
    {'deptd_sch_count': '-1', 'deptd_tot_count': '2', 'deptd_busy_count': '0'},
    {'deptd_sch_count': '1', 'deptd_tot_count': 'bad', 'deptd_busy_count': '0'},
    {'deptd_sch_count': '1', 'deptd_tot_count': '2', 'deptd_busy_count': '1.5'},
  ]) {
    test('malformed totals $row fail without loading doctors', () async {
      h.totalsResponse = {
        'count': 1,
        'items': [row],
      };
      await expectLater(totals(), throwsA(isA<AppFailure>()));
      expect(h.scheduleReads, isEmpty);
    });
  }
  test(
    'wrong-day nested data cannot be rendered under a different selected date',
    () async {
      h.doctorsResponse = {
        'count': 1,
        'items': [
          unitDoctor(slots: [unitSlot(day: '25-OCT-26')]),
        ],
      };
      await expectLater(doctors(), throwsA(isA<AppFailure>()));
    },
  );
  test(
    'failed network request is not automatically retried and sends no write',
    () async {
      h.failDepartments = true;
      await expectLater(loadDepartments(), throwsA(isA<AppFailure>()));
      expect(h.departmentReads, hasLength(1));
      expect(h.posts, isEmpty);
    },
  );
  test(
    'only full-access Admin with a phone can call booked past or upcoming slots',
    () {
      final admin = AccountProfile(AccountRole.admin, h.adminData);
      for (final time in ['08:00 AM', '02:00 PM']) {
        final slot = UnitAppointmentSlot(unitSlot(time: time));
        expect(allAppointmentMayCall(admin, slot), isTrue);
        expect(allAppointmentMayCall(profile(), slot), isFalse);
      }
      for (final row in [
        unitSlot(patient: ''),
        unitSlot(patient: 'Busy'),
        {...unitSlot(), 'pat_cell': ''},
      ]) {
        expect(allAppointmentMayCall(admin, UnitAppointmentSlot(row)), isFalse);
      }
      expect(
        allAppointmentMayCall(
          AccountProfile(AccountRole.admin, {
            ...h.adminData,
            'all_access_flag': '0',
          }),
          UnitAppointmentSlot(unitSlot()),
        ),
        isFalse,
      );
      expect(
        allAppointmentPhoneUri(UnitAppointmentSlot(unitSlot())).toString(),
        'tel:01700000000',
      );
    },
  );
  test(
    'scope includes Manager, department, unit and Admin calling permission changes',
    () {
      for (final changes in [
        {'doc_manager_flag': '0'},
        {'deptd_id': '99'},
        {'depts_id': '9'},
        {'all_access_flag': '0'},
      ]) {
        expect(
          allAppointmentScope(profile(changes)),
          isNot(allAppointmentScope(profile())),
        );
      }
    },
  );
  test(
    'Admin identity and mobile access guard protect read-only All scope',
    () async {
      final admin = AllAppointmentHarness(admin: true);
      addTearDown(admin.auth.dispose);
      await admin.signIn();
      admin.transport.requests.clear();
      final profile = AccountProfile(AccountRole.admin, admin.adminData);
      final signedIn = admin.auth.session!;
      final session = AuthSession(
        credentials: signedIn.credentials,
        center: signedIn.center,
        account: const AccountOption(
          role: AccountRole.admin,
          adminId: '70',
          adminUserName: 'example.admin',
        ),
        centers: signedIn.centers,
        remember: signedIn.remember,
      );
      final data = await admin.allRepository.departments(
        admin.auth.session!,
        profile,
        isCurrent: () => true,
      );
      expect(data, hasLength(2));
      for (final changes in [
        <String, Object?>{'usr_id': 'OTHER'},
        {'usr_name': 'OTHER'},
        {'usr_mob_app_access': '0'},
      ]) {
        final count = admin.departmentReads.length;
        await expectLater(
          admin.allRepository.departments(
            session,
            AccountProfile(AccountRole.admin, {...admin.adminData, ...changes}),
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
        expect(admin.departmentReads.length, count);
      }
    },
  );
}

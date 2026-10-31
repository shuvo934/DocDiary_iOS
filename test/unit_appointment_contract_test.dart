import 'dart:async';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/doctor_appointment_models.dart';
import 'package:docdiary_ios/features/appointments/unit_schedule/unit_appointment_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'unit_appointment_test_support.dart';

void main() {
  late UnitAppointmentHarness h;
  setUp(() async {
    h = UnitAppointmentHarness();
    await h.signIn();
    h.transport.requests.clear();
  });
  tearDown(() => h.auth.dispose());
  AccountProfile profile([JsonMap changes = const {}]) =>
      AccountProfile(AccountRole.doctor, {...h.doctorData, ...changes});
  Future<List<UnitAppointmentChoice>> units({bool Function()? current}) async =>
      h.unitRepository.units(
        h.auth.session!,
        profile(),
        isCurrent: current ?? () => true,
      );
  Future<UnitAppointmentSnapshot> doctors({
    DateTime? day,
    UnitAppointmentChoice choice = const UnitAppointmentChoice(
      '2',
      'Outpatient Unit',
    ),
    List<UnitAppointmentChoice>? permitted,
    bool Function()? current,
  }) async => h.unitRepository.doctors(
    h.auth.session!,
    profile(),
    day ?? h.now,
    choice,
    permitted ??
        const [
          UnitAppointmentChoice('2', 'Outpatient Unit'),
          UnitAppointmentChoice('3', 'Therapy Unit'),
        ],
    isCurrent: current ?? () => true,
  );
  test(
    'native Unit Head access requires doctor role and excludes manager entry',
    () {
      expect(unitAppointmentAllowed(profile()), isTrue);
      expect(
        unitAppointmentAllowed(profile({'doc_manager_flag': '1'})),
        isFalse,
      );
      expect(
        unitAppointmentAllowed(profile({'doc_deptd_head_flag': '0'})),
        isFalse,
      );
      expect(
        unitAppointmentAllowed(AccountProfile(AccountRole.admin, h.adminData)),
        isFalse,
      );
    },
  );
  for (final changes in [
    <String, Object?>{'doc_deptd_head_flag': '0'},
    {'doc_manager_flag': '1'},
  ]) {
    test(
      'unavailable Unit permission $changes prevents every unit GET',
      () async {
        await expectLater(
          h.unitRepository.units(
            h.auth.session!,
            profile(changes),
            isCurrent: () => true,
          ),
          throwsA(isA<UnitAppointmentUnavailable>()),
        );
        expect(h.unitReads, isEmpty);
      },
    );
  }
  for (final changes in [
    <String, Object?>{'doc_code': 'OTHER'},
    {'doc_id': ''},
    {'deptd_id': ''},
    {'deptd_id': 'bad'},
    {'access_flag': '0'},
    {'fl_flag': '1'},
    {'exp_date': '01-JAN-20'},
  ]) {
    test(
      'changed identity/department/access $changes fails before a unit GET',
      () async {
        await expectLater(
          h.unitRepository.units(
            h.auth.session!,
            profile(changes),
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
        expect(h.unitReads, isEmpty);
      },
    );
  }
  test('Admin profile cannot acquire doctor Unit scope', () async {
    await expectLater(
      h.unitRepository.units(
        h.auth.session!,
        AccountProfile(AccountRole.admin, h.adminData),
        isCurrent: () => true,
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(h.unitReads, isEmpty);
  });
  test(
    'unit and nested schedule requests match native path and parameter case',
    () async {
      await units();
      await doctors();
      expect(
        h.unitReads.single.path,
        endsWith('/doctors_app_schedule/getUnitList'),
      );
      expect(h.unitReads.single.queryParameters, {'deptd_id': '8'});
      expect(
        h.scheduleReads.single.path,
        endsWith('/doctors_app_schedule/getDocWithSchedule'),
      );
      expect(h.scheduleReads.single.queryParameters, {
        'pdate': '24-OCT-26',
        'depts_id': '2',
        'deptd_id': '8',
      });
      expect(h.posts, isEmpty);
    },
  );
  test('unit identity must be in the current department catalogue', () async {
    await expectLater(
      doctors(choice: const UnitAppointmentChoice('99', 'Foreign Unit')),
      throwsA(isA<AppFailure>()),
    );
    expect(h.scheduleReads, isEmpty);
  });
  test('year and month rollover obey native Calendar.add boundaries', () {
    final window = DoctorAppointmentWindow(DateTime(2026, 1, 31));
    expect(window.first, DateTime(2025, 12, 31));
    expect(window.last, DateTime(2026, 2, 28));
    expect(window.move(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(window.canMove(window.last, 1), isFalse);
    expect(
      DoctorAppointmentWindow(DateTime(2024, 1, 31)).last,
      DateTime(2024, 2, 29),
    );
  });
  test('out-of-window date cannot request schedules', () async {
    await expectLater(
      doctors(day: DateTime(2026, 8, 1)),
      throwsA(isA<AppFailure>()),
    );
    expect(h.scheduleReads, isEmpty);
  });
  test(
    'encoded outer and nested arrays preserve returned doctor and schedule order',
    () async {
      h.encodedArrays = true;
      h.unitRows[0] = {...h.unitRows[0], 'depts_name': 'ফিজিওথেরাপি ইউনিট'};
      expect((await units()).first.name, 'ফিজিওথেরাপি ইউনিট');
      final data = await doctors();
      expect(data.doctors.map((r) => r.id), ['10', '20', '30']);
      expect(
        data.doctors.first.schedules.map((s) => s.value('schedule_time')),
        ['08:00 AM', '09:00 AM', '10:00 AM', '02:00 PM', '03:00 PM'],
      );
      expect(() => data.doctors.clear(), throwsUnsupportedError);
      expect(
        () => data.doctors.first.schedules.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => data.doctors.first.schedules.first.values.clear(),
        throwsUnsupportedError,
      );
    },
  );
  test(
    'totals exclude busy slots and remain unit totals after local exact-ID filtering',
    () async {
      final data = await doctors();
      expect(data.appointmentCount, 4);
      expect(data.blankCount, 2);
      expect(data.doctors.first.blankCount, 1);
      expect(data.filtered('20').single.id, '20');
      expect(data.appointmentCount, 4);
      expect(data.doctorChoices.first.name, '...');
      expect(data.filtered(''), hasLength(3));
    },
  );
  test(
    'doctor IDs 1 and 10 and duplicate labels never cause substring or name selection',
    () {
      final data = UnitAppointmentSnapshot([
        UnitAppointmentDoctor.fromData(
          unitDoctor(id: '1', name: 'Same Name', code: 'CODE'),
        ),
        UnitAppointmentDoctor.fromData(
          unitDoctor(id: '10', name: 'Same Name', code: 'CODE'),
        ),
      ]);
      expect(data.filtered('1').single.id, '1');
      expect(data.doctorChoices.map((c) => c.id), ['', '1', '10']);
      expect(data.filtered('999'), isEmpty);
    },
  );
  test(
    'zero-total native blank override and null total/busy fallback are retained',
    () {
      expect(
        UnitAppointmentDoctor.fromData(
          unitDoctor(appointments: '3', total: '0', busy: '4'),
        ).blankCount,
        0,
      );
      expect(
        UnitAppointmentDoctor.fromData({
          ...unitDoctor(appointments: '0'),
          'tot_count': null,
          'busy_count': 'null',
        }).blankCount,
        0,
      );
      expect(
        UnitAppointmentDoctor.fromData(
          unitDoctor(appointments: '3', total: '2', busy: '1'),
        ).blankCount,
        -2,
      );
    },
  );
  test(
    'one doctor has no synthetic clear choice and empty rows produce zero totals',
    () {
      final one = UnitAppointmentSnapshot([
        UnitAppointmentDoctor.fromData(unitDoctor()),
      ]);
      expect(one.doctorChoices.single.id, '10');
      final empty = UnitAppointmentSnapshot([]);
      expect(empty.doctorChoices, isEmpty);
      expect(empty.appointmentCount, 0);
      expect(empty.blankCount, 0);
    },
  );
  test(
    'initial horizontal focus chooses first non-past booked row, skipping blank and blocked',
    () async {
      final row = (await doctors()).doctors.first;
      expect(row.initialScheduleIndex(h.now), 3);
      expect(row.initialScheduleIndex(DateTime(2026, 10, 24, 14)), 3);
      expect(row.initialScheduleIndex(DateTime(2026, 10, 24, 15, 1)), 0);
    },
  );
  test(
    'blank and blocked messages and booked completion match native strict-before rule',
    () {
      final blank = UnitAppointmentSlot(
        unitSlot(patient: '', time: '02:00 PM'),
      );
      expect(blank.message(DateTime(2026, 10, 24, 14)), '...');
      expect(
        blank.message(DateTime(2026, 10, 24, 14, 0, 1)),
        'No Meeting happened',
      );
      final booked = UnitAppointmentSlot(unitSlot());
      expect(booked.completed(DateTime(2026, 10, 24, 14)), isFalse);
      expect(booked.completed(DateTime(2026, 10, 24, 14, 0, 1)), isTrue);
      expect(
        UnitAppointmentSlot(unitSlot(patient: 'Blocked Time')).message(h.now),
        'Blocked Time',
      );
      expect(UnitAppointmentSlot(unitSlot(patient: 'NaN')).booked, isFalse);
      expect(UnitAppointmentSlot(unitSlot(patient: '11.5')).booked, isTrue);
    },
  );
  test(
    'first future focus follows server order rather than sorting or selecting a blank',
    () {
      final data = UnitAppointmentDoctor.fromData(
        unitDoctor(
          slots: [
            unitSlot(patient: '', time: '02:00 PM'),
            unitSlot(time: '04:00 PM'),
            unitSlot(time: '03:00 PM'),
          ],
        ),
      );
      expect(data.initialScheduleIndex(h.now), 1);
    },
  );
  for (final response in <JsonMap>[
    {},
    {'count': 'bad'},
    {'count': -1},
    {'count': 1},
    {'count': 1, 'items': []},
    {'count': 1, 'items': 'invalid'},
  ]) {
    test('invalid count/list response $response is rejected', () async {
      h.unitsResponse = response;
      await expectLater(units(), throwsA(isA<AppFailure>()));
      h.doctorsResponse = response;
      await expectLater(doctors(), throwsA(isA<AppFailure>()));
    });
  }
  for (final change in <JsonMap>[
    {'doc_id': ''},
    {'app_count': 'null'},
    {'busy_count': 'bad'},
    {'app_list': null},
    {'app_list': ''},
    {'app_list': 'bad'},
    {
      'app_list': [unitSlot(time: '25:99 PM')],
    },
  ]) {
    test(
      'invalid nested doctor data $change fails without returning a partial list',
      () async {
        h.doctorsResponse = {
          'count': 2,
          'items': [
            unitDoctor(),
            {...unitDoctor(id: '20'), ...change},
          ],
        };
        await expectLater(doctors(), throwsA(isA<AppFailure>()));
      },
    );
  }
  test(
    'missing nested schedule array is not interpreted as No Schedule Found',
    () async {
      final row = unitDoctor()..remove('app_list');
      h.doctorsResponse = {
        'count': 1,
        'items': [row],
      };
      await expectLater(doctors(), throwsA(isA<AppFailure>()));
    },
  );
  test('schedule returned for another date is rejected', () async {
    h.doctorsResponse = {
      'count': 1,
      'items': [
        unitDoctor(slots: [unitSlot(day: '25-OCT-26')]),
      ],
    };
    await expectLater(doctors(), throwsA(isA<AppFailure>()));
  });
  test('count zero is a valid empty result for both requests', () async {
    h.unitsResponse = {'count': '0'};
    expect(await units(), isEmpty);
    h.doctorsResponse = {'count': 0};
    expect((await doctors()).doctors, isEmpty);
  });
  test(
    'obsolete request is blocked before transport and after a pending response',
    () async {
      await expectLater(
        units(current: () => false),
        throwsA(isA<ObsoleteRequest>()),
      );
      expect(h.unitReads, isEmpty);
      var current = true;
      h.pendingDoctors = Completer<JsonMap>();
      final request = doctors(current: () => current);
      final check = expectLater(request, throwsA(isA<ObsoleteRequest>()));
      await Future<void>.delayed(Duration.zero);
      current = false;
      h.pendingDoctors!.complete({'count': 0});
      await check;
    },
  );
  test('transport failure is not automatically retried or written', () async {
    h.failDoctors = true;
    await expectLater(doctors(), throwsA(isA<AppFailure>()));
    expect(h.scheduleReads, hasLength(1));
    expect(h.posts, isEmpty);
  });
}

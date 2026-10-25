import 'dart:async';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/doctor_appointment_models.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/avail/doctor_appointment_avail_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'doctor_appointment_test_support.dart';

void main() {
  late DoctorAppointmentHarness h;
  late JsonMap data;
  late DoctorAppointmentRow selected;
  setUp(() async {
    h = DoctorAppointmentHarness();
    await h.signIn();
    h.transport.requests.clear();
    data = doctorAppointmentRow(time: '09:00 AM');
    h.customRows = [data];
    selected = DoctorAppointmentRow(data, selectedDate: DateTime(2026, 10, 24));
  });
  tearDown(() => h.auth.dispose());
  Future<DoctorAppointmentAvailResult> submit({
    String notes = '',
    AccountProfile? profile,
    DoctorAppointmentRow? row,
    bool Function()? current,
  }) async => await DoctorAppointmentAvailRepository(h.appointments).submit(
    h.auth.session!,
    profile ?? h.auth.profile!,
    row ?? selected,
    notes,
    isCurrent: current ?? () => true,
  );

  for (final notes in [
    '',
    'Patient attended',
    '  Note: ready + stable & ok!  ',
  ]) {
    test(
      'native POST has exactly P_AD_ID/P_NOTE and unchanged notes "$notes"',
      () async {
        expect(
          await submit(notes: notes),
          DoctorAppointmentAvailResult.created,
        );
        expect(h.transport.requests.map((r) => r.method), ['GET', 'POST']);
        final post = h.posts.single;
        expect(post.uri.path, endsWith('/appointment_schedule/availSchedule'));
        expect(post.uri.host, h.auth.session!.center.baseUri.host);
        expect(post.uri.queryParameters, isEmpty);
        expect(post.headers, {'P_AD_ID': '41', 'P_NOTE': notes});
      },
    );
  }
  for (final value in <Object?>[
    null,
    '',
    'null',
    1,
    true,
    <Object?>[],
    <String, Object?>{},
    'Success',
    'Successfully Created ',
    'Doctor denied this request',
  ]) {
    test('string_out=$value cannot be mistaken for native success', () async {
      h.transport.onPost = (_, __) async => {'string_out': value};
      await expectLater(submit(), throwsA(isA<AppFailure>()));
      expect(h.posts.length, 1);
    });
  }
  test('server rejection text remains available to the dialog', () async {
    h.transport.onPost =
        (_, __) async => {'string_out': 'Schedule was changed'};
    await expectLater(
      submit(),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          'Schedule was changed',
        ),
      ),
    );
  });
  for (final notes in [
    'one\ntwo',
    'one\rtwo',
    'tab\there',
    'বাংলা',
    'ready 🙂',
  ]) {
    test('unsupported header note is rejected before any IO: $notes', () async {
      await expectLater(submit(notes: notes), throwsA(isA<AppFailure>()));
      expect(h.transport.requests, isEmpty);
    });
  }
  for (final id in ['', ' ', '41\r\nInjected: 1', 'বাংলা']) {
    test('invalid AD_ID cannot reach the transport: $id', () async {
      final row = DoctorAppointmentRow({
        ...data,
        'ad_id': id,
      }, selectedDate: selected.selectedDate);
      await expectLater(submit(row: row), throwsA(isA<AppFailure>()));
      expect(h.transport.requests, isEmpty);
    });
  }
  test('obsolete operation makes no request', () async {
    await expectLater(
      submit(current: () => false),
      throwsA(isA<ObsoleteRequest>()),
    );
    expect(h.transport.requests, isEmpty);
  });
  for (final edit in <JsonMap>[
    {'fl_flag': '1'},
    {'access_flag': '0'},
    {'exp_date': '01-JAN-20'},
    {'doc_code': 'A-DIFFERENT-DOCTOR'},
  ]) {
    test('fresh doctor access guard prevents mutation with $edit', () async {
      final profile = AccountProfile(AccountRole.doctor, {
        ...h.doctorData,
        ...edit,
      });
      await expectLater(submit(profile: profile), throwsA(isA<AppFailure>()));
      expect(h.transport.requests, isEmpty);
    });
  }
  test('admin profile cannot use a doctor AVAIL mutation', () async {
    await expectLater(
      submit(profile: AccountProfile(AccountRole.admin, h.adminData)),
      throwsA(isA<AppFailure>()),
    );
    expect(h.transport.requests, isEmpty);
  });
  for (final edit in <JsonMap>[
    {'patient_data': ''},
    {'patient_data': 'Blocked Time'},
    {'schedule_time': '10:00 PM'},
    {'avail_flag': '1'},
    {'adm_date': '23-OCT-26'},
  ]) {
    test('ineligible retained row cannot avail: $edit', () async {
      final row = DoctorAppointmentRow({
        ...data,
        ...edit,
      }, selectedDate: selected.selectedDate);
      expect(await submit(row: row), DoctorAppointmentAvailResult.unavailable);
      expect(h.transport.requests, isEmpty);
    });
  }
  test('revoked is_need_avail prevents a retained dialog submit', () async {
    final profile = AccountProfile(AccountRole.doctor, {
      ...h.doctorData,
      'is_need_avail': '0',
    });
    expect(
      await submit(profile: profile),
      DoctorAppointmentAvailResult.unavailable,
    );
    expect(h.posts, isEmpty);
  });
  test('a fresh already-availed row never posts again', () async {
    h.customRows = [
      {...data, 'avail_flag': '1'},
    ];
    expect(await submit(), DoctorAppointmentAvailResult.alreadyAvailed);
    expect(h.posts, isEmpty);
    expect(h.transport.requests.length, 1);
  });
  for (final field in [
    'ad_id',
    'patient_data',
    'pat_id',
    'adm_date',
    'schedule_time',
    'depts_id',
    'pfn_id',
  ]) {
    test(
      'reassigned $field is not mistaken for the selected patient/slot',
      () async {
        h.customRows = [
          {...data, field: field == 'schedule_time' ? '08:00 AM' : 'changed'},
        ];
        expect(await submit(), DoctorAppointmentAvailResult.unavailable);
        expect(h.posts, isEmpty);
      },
    );
  }
  test('removed appointment does not POST', () async {
    h.customRows = [];
    expect(await submit(), DoctorAppointmentAvailResult.unavailable);
    expect(h.posts, isEmpty);
  });
  test(
    'duplicate identical rows with a confirmed status never post again',
    () async {
      h.customRows = [
        data,
        {...data, 'avail_flag': '1'},
      ];
      expect(await submit(), DoctorAppointmentAvailResult.alreadyAvailed);
      expect(h.posts, isEmpty);
    },
  );
  test(
    'repeated IDs preserve patient identity when selecting fresh status',
    () async {
      h.customRows = [
        {...data, 'patient_data': '999', 'avail_flag': '1'},
        data,
      ];
      expect(await submit(), DoctorAppointmentAvailResult.created);
      expect(h.posts.single.headers['P_AD_ID'], '41');
    },
  );
  test('failed preflight read does not submit or retry itself', () async {
    h.transport.onGet = (_) async => throw const AppFailure('Read timed out');
    await expectLater(submit(), throwsA(isA<AppFailure>()));
    expect(h.transport.requests.length, 1);
    expect(h.posts, isEmpty);
  });
  test('stale access after preflight cancels before POST', () async {
    var current = true;
    final gate = Completer<JsonMap>();
    h.transport.onGet = (_) => gate.future;
    final future = submit(current: () => current);
    final expectation = expectLater(future, throwsA(isA<ObsoleteRequest>()));
    current = false;
    gate.complete({
      'count': 1,
      'items': [data],
    });
    await expectation;
    expect(h.posts, isEmpty);
  });
  test('midnight during preflight makes the old day unavailable', () async {
    h.transport.onGet = (_) async {
      h.now = DateTime(2026, 10, 25);
      return {
        'count': 1,
        'items': [data],
      };
    };
    expect(await submit(), DoctorAppointmentAvailResult.unavailable);
    expect(h.posts, isEmpty);
  });
  test(
    'late POST response cannot complete an obsolete account operation',
    () async {
      var current = true;
      final gate = Completer<JsonMap>();
      h.transport.onPost = (_, __) => gate.future;
      final future = submit(current: () => current);
      final expectation = expectLater(future, throwsA(isA<ObsoleteRequest>()));
      await Future<void>.delayed(Duration.zero);
      expect(h.posts.length, 1);
      current = false;
      gate.complete({'string_out': 'Successfully Created'});
      await expectation;
      expect(h.posts.length, 1);
    },
  );
  test(
    'explicit retry reconciles a committed timeout without a second POST',
    () async {
      h.transport.onPost = (_, __) async {
        h.customRows = [
          {...data, 'avail_flag': '1'},
        ];
        throw const AppFailure(
          'The request timed out.',
          kind: FailureKind.network,
        );
      };
      await expectLater(submit(notes: 'same note'), throwsA(isA<AppFailure>()));
      expect(h.posts.length, 1);
      expect(
        await submit(notes: 'same note'),
        DoctorAppointmentAvailResult.alreadyAvailed,
      );
      expect(h.posts.length, 1);
    },
  );
}

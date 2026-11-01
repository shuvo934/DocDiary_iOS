import 'dart:async';
import 'dart:convert';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/appointments/admin_modify/admin_appointment_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'admin_appointment_test_support.dart';

void main() {
  late AdminAppointmentHarness h;
  setUp(() async {
    h = AdminAppointmentHarness();
    await h.signIn();
    h.transport.requests.clear();
  });
  tearDown(() => h.auth.dispose());
  Future<void> insert(
    AdminAppointmentDraft draft,
    AdminSchedule row, {
    bool Function()? current,
    bool Function()? owns,
  }) async {
    await h.repository.insert(
      h.auth.session!,
      h.profile,
      draft,
      row,
      isCurrent: current ?? () => true,
      ownsResponse: owns ?? () => true,
    );
  }

  test(
    'native add/cancel patient endpoints and encoded search remain centre scoped',
    () async {
      for (final cancel in [false, true]) {
        await h.repository.patients(
          h.auth.session!,
          h.profile,
          cancel: cancel,
          search: '',
          isCurrent: () => true,
        );
        await h.repository.patients(
          h.auth.session!,
          h.profile,
          cancel: cancel,
          search: 'রহিম & 12',
          isCurrent: () => true,
        );
      }
      final requests = h.appointmentReads;
      expect(requests.map((r) => r.uri.pathSegments.last), [
        'getFiftyPatientListForAddApp',
        'getPatListForAddAppBySearch',
        'getFiftyPatientListForCancelAppNew',
        'getPatListForCancelAppBySearch',
      ]);
      expect(requests[0].uri.queryParameters, isEmpty);
      expect(requests[1].uri.queryParameters, {'ph_pat': 'রহিম & 12'});
      expect(requests[2].uri.queryParameters, {'is_admin': 'true'});
      expect(requests[3].uri.queryParameters, {
        'ph_pat': 'রহিম & 12',
        'is_admin': 'true',
      });
      expect(requests.every((r) => r.uri.host == 'centre.example'), true);
      expect(h.appointmentPosts, isEmpty);
    },
  );
  test('limited cancellation patient list sends is_admin=false', () async {
    h.adminData['all_access_flag'] = '0';
    await h.repository.patients(
      h.auth.session!,
      h.profile,
      cancel: true,
      search: '',
      isCurrent: () => true,
    );
    expect(h.appointmentReads.single.uri.queryParameters, {
      'is_admin': 'false',
    });
  });
  for (final query in ['', 'ab', 'abc.def', 'abc-def', 'abc,def']) {
    test('native search validation: ${jsonEncode(query)}', () {
      expect(adminPatientSearchError(query), isNotNull);
    });
  }
  test(
    'encoded ORDS arrays, duplicate names and distinct record identities are retained',
    () async {
      h.encoded = true;
      final rows = await h.repository.patients(
        h.auth.session!,
        h.profile,
        cancel: false,
        search: '',
        isCurrent: () => true,
      );
      expect(rows.map((r) => r.id), ['101', '102']);
      expect(rows.map((r) => r.name).toSet().length, 1);
      final one = AdminAppointmentChoice.doctor(h.doctors.first),
          two = AdminAppointmentChoice.doctor({
            ...h.doctors.first,
            'depts_id': '21',
          });
      expect(one.id, two.id);
      expect(one.key, isNot(two.key));
    },
  );
  test('dependent GET requests use the selected record IDs', () async {
    final draft = h.draft();
    await h.repository.doctors(
      h.auth.session!,
      h.profile,
      draft.patient!,
      cancel: false,
      isCurrent: () => true,
    );
    await h.repository.payments(
      h.auth.session!,
      h.profile,
      draft,
      isCurrent: () => true,
    );
    await h.repository.services(
      h.auth.session!,
      h.profile,
      draft,
      isCurrent: () => true,
    );
    await h.repository.limit(
      h.auth.session!,
      h.profile,
      draft,
      isCurrent: () => true,
    );
    expect(h.appointmentReads.map((r) => r.uri.queryParameters), [
      {'ph_id': '101'},
      {'ph_id': '101', 'depts_id': '20'},
      {'ph_id': '101', 'depts_id': '20', 'prm_id': '201'},
      {'p_ph_id': '101', 'p_depts_id': '20', 'p_pfn_id': '31'},
    ]);
  });
  test(
    'cancel doctor/service/date queries and nested time list match native contracts',
    () async {
      final draft = h.draft(cancel: true);
      h.cancellationRows.first['time_list'] = jsonEncode(
        h.cancellationRows.first['time_list'],
      );
      await h.repository.doctors(
        h.auth.session!,
        h.profile,
        draft.patient!,
        cancel: true,
        isCurrent: () => true,
      );
      await h.repository.services(
        h.auth.session!,
        h.profile,
        draft,
        isCurrent: () => true,
      );
      final dates = await h.repository.cancellations(
        h.auth.session!,
        h.profile,
        draft,
        isCurrent: () => true,
      );
      expect(h.appointmentReads.map((r) => r.uri.pathSegments.last), [
        'getDoctorListForCancel',
        'getServiceForCancAppList',
        'getAppDateTimeForCancel',
      ]);
      expect(h.appointmentReads.last.uri.queryParameters, {
        'ph_id': '101',
        'depts_id': '20',
        'doc_id': '10',
        'pfn_id': '31',
      });
      expect(dates.single.times, ['09:00 AM', '11:00 AM']);
    },
  );
  test(
    'schedule dates, dynamic time endpoint and taken times use original query names',
    () async {
      final draft = h.draft();
      await h.repository.days(
        h.auth.session!,
        h.profile,
        draft,
        isCurrent: () => true,
      );
      await h.repository.times(
        h.auth.session!,
        h.profile,
        draft,
        AdminAppointmentDay(h.days.first),
        isCurrent: () => true,
      );
      expect(h.appointmentReads.map((r) => r.uri.pathSegments.last), [
        'getAppointmentDateList',
        'getTimeApiForDiffOccurance',
        'getAvailableTimes',
        'getTakenScheduleList',
      ]);
      expect(h.appointmentReads[2].uri.queryParameters, {
        'doc_id': '10',
        'depts_id': '20',
        'adm_id': '301',
        'adm_date': '02-NOV-26',
        'ph_id': '101',
        'ts_id': '',
        'am_id': '',
      });
      expect(h.appointmentReads.last.uri.queryParameters, {
        'P_ADM_ID': '301',
        'P_DOC_ID': '10',
        'P_DEPTS_ID': '20',
        'P_PH_ID': '101',
        'P_PRM_ID': '201',
        'P_PFN_ID': '31',
        'P_PRD_ID': '41',
      });
    },
  );
  for (final endpoint in [
    '',
    '../insertAppointment',
    'https://other.invalid/api',
    'name?query=1',
  ]) {
    test(
      'invalid dynamic endpoint is rejected before a second GET: $endpoint',
      () async {
        h.apiName = endpoint;
        await expectLater(
          h.repository.times(
            h.auth.session!,
            h.profile,
            h.draft(),
            AdminAppointmentDay(h.days.first),
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
        expect(h.appointmentReads.length, 1);
        expect(h.appointmentPosts, isEmpty);
      },
    );
  }
  for (final response in <JsonMap>[
    {},
    {'count': 'bad', 'items': []},
    {'count': 1, 'items': []},
    {
      'count': 0,
      'items': [<String, Object?>{}],
    },
    {
      'count': 1,
      'items': [
        {'doc_id': 'oops'},
      ],
    },
  ]) {
    test('malformed doctor response is rejected: $response', () async {
      h.onAppointmentGet = (_) async => response;
      await expectLater(
        h.repository.doctors(
          h.auth.session!,
          h.profile,
          AdminAppointmentChoice.patient(h.patients.first),
          cancel: false,
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
    });
  }
  for (final changes in <JsonMap>[
    {'usr_id': '999'},
    {'usr_name': 'other.admin'},
    {'usr_mob_app_access': '0'},
    {'usr_mob_forced_log_out_flag': '1'},
    {'exp_date': '01-JAN-20'},
    {'all_access_flag': '2', 'hr_appointment_active': '0'},
    {'all_access_flag': '3', 'acc_appointment_active': '0'},
  ]) {
    test(
      'access/identity check blocks reads and writes before dispatch: $changes',
      () async {
        final profile = AccountProfile(AccountRole.admin, {
          ...h.adminData,
          ...changes,
        });
        final original = h.auth.session!;
        final session =
            changes.containsKey('usr_name')
                ? AuthSession(
                  credentials: original.credentials,
                  center: original.center,
                  account: const AccountOption(
                    role: AccountRole.admin,
                    adminId: '70',
                    adminUserName: 'example.admin',
                  ),
                  centers: original.centers,
                  remember: original.remember,
                )
                : original;
        await expectLater(
          h.repository.patients(
            session,
            profile,
            cancel: false,
            search: '',
            isCurrent: () => true,
          ),
          throwsA(anything),
        );
        final draft = h.draft(), row = h.schedule();
        draft.add(row);
        await expectLater(
          h.repository.insert(
            session,
            profile,
            draft,
            row,
            isCurrent: () => true,
            ownsResponse: () => true,
          ),
          throwsA(anything),
        );
        expect(h.appointmentReads, isEmpty);
        expect(h.appointmentPosts, isEmpty);
      },
    );
  }
  test('doctor and manager roles cannot enter admin modify', () {
    expect(
      adminAppointmentAllowed(
        AccountProfile(AccountRole.doctor, {
          ...h.doctorData,
          'doc_manager_flag': '1',
        }),
      ),
      false,
    );
    expect(
      () => h.repository.guard(
        h.auth.session!,
        AccountProfile(AccountRole.doctor, h.doctorData),
        () => true,
      ),
      throwsA(anything),
    );
  });
  test('legacy admin profile without usr_id remains valid', () async {
    h.adminData.remove('usr_id');
    await h.repository.patients(
      h.auth.session!,
      h.profile,
      cancel: false,
      search: '',
      isCurrent: () => true,
    );
    expect(h.appointmentReads.length, 1);
  });
  test(
    'stale read is discarded after await and stale write never dispatches',
    () async {
      var current = true;
      final delayed = Completer<JsonMap>();
      h.onAppointmentGet = (_) async => delayed.future;
      final pending = h.repository.patients(
        h.auth.session!,
        h.profile,
        cancel: false,
        search: '',
        isCurrent: () => current,
      );
      current = false;
      delayed.complete({'items': h.patients});
      await expectLater(pending, throwsA(isA<ObsoleteRequest>()));
      final draft = h.draft(), row = h.schedule();
      draft.add(row);
      await expectLater(
        insert(draft, row, current: () => false),
        throwsA(isA<ObsoleteRequest>()),
      );
      expect(h.appointmentPosts, isEmpty);
    },
  );
  test(
    'service quantity counts distinct new dates and refunds on last-row removal',
    () {
      final draft = h.draft();
      draft.add(h.schedule());
      draft.add(h.schedule(0, 1));
      expect(draft.remaining, 2);
      draft.add(h.schedule(1));
      expect(draft.remaining, 1);
      draft.remove(0);
      expect(draft.remaining, 1);
      draft.remove(0);
      expect(draft.remaining, 2);
    },
  );
  test(
    'previously taken dates do not consume quantity; zero stock blocks a new date',
    () {
      h.services.first['rest'] = '0';
      final draft = h.draft();
      expect(() => draft.add(h.schedule()), throwsA(isA<AppFailure>()));
      draft.add(h.schedule(0, 0, true));
      expect(draft.remaining, 0);
    },
  );
  test(
    'limit zero is unlimited; nonzero limit includes already taken quantity',
    () {
      expect(
        AdminScheduleLimit({
          'allowed_qty': 0,
          'taken_service_qty': 100,
        }).permits(500),
        true,
      );
      expect(
        AdminScheduleLimit({
          'allowed_qty': 4,
          'taken_service_qty': 2,
        }).permits(1),
        true,
      );
      expect(
        AdminScheduleLimit({
          'allowed_qty': 4,
          'taken_service_qty': 2,
        }).permits(2),
        false,
      );
    },
  );
  test(
    'changing an upstream choice clears all dependent selections and stored schedules',
    () {
      final draft = h.draft();
      draft.add(h.schedule());
      draft.selectPatient(AdminAppointmentChoice.patient(h.patients.last));
      expect(draft.doctor, isNull);
      expect(draft.payment, isNull);
      expect(draft.service, isNull);
      expect(draft.schedules, isEmpty);
      expect(draft.limit, isNull);
    },
  );
  test(
    'submitted successful rows cannot be edited, deleted or sent a second time',
    () async {
      final draft = h.draft(), row = h.schedule();
      draft.add(row);
      row.submitted = true;
      expect(() => draft.remove(0), throwsA(isA<AppFailure>()));
      expect(
        () => draft.add(h.schedule(0, 1), replacing: 0),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(insert(draft, row), throwsA(isA<AppFailure>()));
      expect(h.appointmentPosts, isEmpty);
    },
  );
  test(
    'collision row can be re-timed on its existing date and resets submission status',
    () {
      final draft = h.draft(), row = h.schedule();
      draft.add(row);
      row.submitted = row.duplicate = true;
      draft.add(h.schedule(0, 1), replacing: 0);
      expect(draft.schedules.single.submitted, false);
      expect(draft.schedules.single.time.id, '402');
      expect(draft.remaining, 2);
    },
  );
  test(
    'insert dispatches exact native POST headers once, without query or automatic retry',
    () async {
      final draft = h.draft(), row = h.schedule();
      draft.add(row);
      await insert(draft, row);
      final post = h.appointmentPosts.single;
      expect(post.uri.path, endsWith('/appointmentModify/insertAppointment'));
      expect(post.uri.hasQuery, false);
      expect(post.headers, {
        'P_DOC_ID': '10',
        'P_DEPTS_ID': '20',
        'P_ADM_DATE': '02-NOV-26',
        'P_TS_ID': '401',
        'P_DESIG_ID': '5',
        'P_ADM_ID': '301',
        'P_PH_ID': '101',
        'P_PAT_CAT_ID': '2',
        'P_PRM_ID': '201',
        'P_PFN_ID': '31',
        'P_PRD_ID': '41',
        'P_USER': 'example.admin',
      });
    },
  );
  test(
    'uncertain POST failure is surfaced without transport retries',
    () async {
      h.transport.onPost =
          (_, _) async =>
              throw const AppFailure('Synthetic connection interrupted');
      final draft = h.draft(), row = h.schedule();
      draft.add(row);
      await expectLater(insert(draft, row), throwsA(isA<AppFailure>()));
      expect(h.appointmentPosts.length, 1);
      expect(row.submitted, false);
    },
  );
  test(
    'original account can retain an acknowledged receipt while UI is backgrounded',
    () async {
      final delayed = Completer<JsonMap>();
      h.transport.onPost = (_, _) => delayed.future;
      var foreground = true;
      final draft = h.draft(), row = h.schedule();
      draft.add(row);
      final pending = h.repository.insert(
        h.auth.session!,
        h.profile,
        draft,
        row,
        isCurrent: () => foreground,
        ownsResponse: () => true,
      );
      foreground = false;
      delayed.complete({
        'string_out': 'Successfully Created',
        'p_sch_msg': 'true',
      });
      expect(await pending, true);
      expect(h.appointmentPosts.length, 1);
    },
  );
  test(
    'cancel dispatches only P_AD_ID and uses each time independently',
    () async {
      final draft = h.draft(cancel: true);
      await h.repository.cancel(
        h.auth.session!,
        h.profile,
        draft,
        isCurrent: () => true,
        ownsResponse: () => true,
      );
      expect(h.appointmentPosts.single.headers, {'P_AD_ID': '501'});
      expect(
        h.appointmentPosts.single.uri.path,
        endsWith('/updateforCancelAppoint'),
      );
    },
  );
  test(
    'limited user cutoff is next day at current time and every time must be eligible',
    () {
      final row = AdminCancellation({
        'ad_id': '9',
        'app_date': '02-NOV-26',
        'time_list': [
          {'schedule': '11:00 AM'},
          {'schedule': '12:30 PM'},
        ],
      });
      expect(row.canCancel(h.now, fullAccess: false), true);
      expect(
        row.canCancel(h.now.add(const Duration(seconds: 1)), fullAccess: false),
        false,
      );
      expect(
        h.draft(cancel: true).cancellation!.canCancel(h.now, fullAccess: false),
        false,
      );
      expect(
        h.draft(cancel: true).cancellation!.canCancel(h.now, fullAccess: true),
        true,
      );
    },
  );
  test(
    'expired cancellation and forged appointment selection cannot dispatch POST',
    () async {
      h.adminData['all_access_flag'] = '0';
      final draft = h.draft(cancel: true);
      await expectLater(
        h.repository.cancel(
          h.auth.session!,
          h.profile,
          draft,
          isCurrent: () => true,
          ownsResponse: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      h.adminData['all_access_flag'] = '1';
      draft.cancellation = AdminCancellation({
        'ad_id': '999',
        'app_date': '02-NOV-26',
        'time_list': [
          {'schedule': '12:00 PM'},
        ],
      });
      await expectLater(
        h.repository.cancel(
          h.auth.session!,
          h.profile,
          draft,
          isCurrent: () => true,
          ownsResponse: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.appointmentPosts, isEmpty);
    },
  );
  test(
    'phone mask preserves native first/last three digits and short inputs never crash',
    () {
      expect(adminPatientPhone('01712345678'), '017*****678');
      for (final phone in ['', '01', '017', '0171', '01712', '017123']) {
        expect(adminPatientPhone(phone), phone);
      }
    },
  );
}

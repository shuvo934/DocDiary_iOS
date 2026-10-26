import 'dart:async';
import 'dart:convert';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/doctor_appointment_models.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/doctor_appointment_navigation.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'doctor_appointment_test_support.dart';

void main() {
  late DoctorAppointmentHarness h;
  setUp(() async {
    h = DoctorAppointmentHarness();
    await h.signIn();
    h.transport.requests.clear();
  });
  tearDown(() => h.auth.dispose());
  Future<List<DoctorAppointmentRow>> load({
    AccountProfile? profile,
    bool Function()? current,
    DateTime? day,
  }) async => await h.appointments.load(
    h.auth.session!,
    profile ?? h.auth.profile!,
    DoctorAppointmentWindow(h.now),
    day ?? h.now,
    isCurrent: current ?? () => true,
  );
  DoctorAppointmentPresentation view({
    JsonMap overrides = const {},
    JsonMap flags = const {},
    DateTime? date,
    DateTime? now,
  }) => DoctorAppointmentRow({
    ...doctorAppointmentRow(),
    ...overrides,
  }, selectedDate: date ?? DateTime(2026, 10, 24)).present(
    DoctorAppointmentFeatures(
      AccountProfile(AccountRole.doctor, {...h.doctorData, ...flags}),
    ),
    now ?? h.now,
  );

  for (final active in ['0', '1']) {
    for (final can in ['0', '1']) {
      test(
        'presc_active=$active and can_prescribe=$can choose exact native endpoint',
        () async {
          final profile = AccountProfile(AccountRole.doctor, {
            ...h.doctorData,
            'presc_active': active,
            'can_prescribe': can,
          });
          final rows = await load(profile: profile);
          expect(rows.length, 6);
          final req = h.appointmentReads.single;
          expect(
            req.uri.pathSegments.last,
            active == '1' && can == '1'
                ? 'getAppointmentDataNew'
                : 'getAppointmentData',
          );
          expect(req.uri.queryParameters, {
            'doc_id': '10',
            'pdate': '24-OCT-26',
          });
          expect(req.uri.host, h.auth.session!.center.baseUri.host);
          expect(h.posts, isEmpty);
        },
      );
    }
  }
  test('doctor query values are encoded once, without admin filters', () async {
    await load(
      profile: AccountProfile(AccountRole.doctor, {
        ...h.doctorData,
        'doc_id': 'A & B+10',
      }),
    );
    expect(h.appointmentReads.single.uri.queryParameters, {
      'doc_id': 'A & B+10',
      'pdate': '24-OCT-26',
    });
  });
  test('calendar range uses anchor day with leap/month/year clamping', () {
    for (final spec in [
      (DateTime(2026, 10, 24), '2026-09-24', '2026-11-24', 62),
      (DateTime(2024, 3, 31), '2024-02-29', '2024-04-30', 62),
      (DateTime(2025, 3, 31), '2025-02-28', '2025-04-30', 62),
      (DateTime(2026, 1, 31), '2025-12-31', '2026-02-28', 60),
    ]) {
      final w = DoctorAppointmentWindow(spec.$1);
      expect(w.first.toIso8601String().substring(0, 10), spec.$2);
      expect(w.last.toIso8601String().substring(0, 10), spec.$3);
      expect(w.length, spec.$4);
      expect(w.dayAt(w.length - 1), w.last);
      expect(w.indexOf(w.last), w.length - 1);
    }
  });
  test(
    'month arrows clamp to partial endpoint months and stop at both edges',
    () {
      final w = DoctorAppointmentWindow(h.now);
      expect(w.move(DateTime(2026, 10, 31), -1), DateTime(2026, 9, 30));
      expect(w.move(DateTime(2026, 10, 1), -1), w.first);
      expect(w.move(DateTime(2026, 10, 31), 1), w.last);
      expect(w.canMove(w.first, -1), isFalse);
      expect(w.canMove(w.last, 1), isFalse);
      expect(w.move(w.first, -1), w.first);
    },
  );
  test('outside date and stale generation block all appointment IO', () async {
    await expectLater(
      load(day: DateTime(2026, 9, 23)),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      load(current: () => false),
      throwsA(isA<ObsoleteRequest>()),
    );
    expect(h.appointmentReads, isEmpty);
  });
  test(
    'decoded and string arrays preserve row order, repeated IDs and native null defaults',
    () async {
      final a = doctorAppointmentRow(id: '1'),
          b = {...doctorAppointmentRow(id: '1'), 'pat_name': 'Other'};
      h.transport.onGet =
          (_) async => {
            'count': '2',
            'items': jsonEncode([a, b]),
          };
      final rows = await load();
      expect(rows.map((r) => r.id), ['1', '1']);
      expect(rows.last.value('pat_name'), 'Other');
      h.transport.onGet =
          (_) async => {
            'count': 1,
            'items': [
              {for (final k in DoctorAppointmentRow.keys) k: null},
            ],
          };
      final empty = (await load()).single;
      expect(empty.value('patient_data'), '');
      expect(empty.value('pph_progress'), '0');
      expect(empty.booked, isFalse);
      expect(empty.startsAt, isNull);
    },
  );
  test(
    'count zero returns native no schedule without parsing ignored items',
    () async {
      h.transport.onGet = (_) async => {'count': '0', 'items': 'ignored'};
      expect(await load(), isEmpty);
    },
  );
  for (final payload in <JsonMap>[
    {},
    {'count': -1},
    {'count': 'bad'},
    {'count': 1},
    {'count': 1, 'items': []},
    {'count': 1, 'items': 'bad'},
    {
      'count': 1,
      'items': [true],
    },
  ]) {
    test(
      'invalid response ${jsonEncode(payload)} fails with endpoint detail',
      () async {
        h.transport.onGet = (_) async => payload;
        await expectLater(
          load(),
          throwsA(
            isA<AppFailure>().having(
              (e) => e.message,
              'message',
              contains('getAppointmentDataNew'),
            ),
          ),
        );
      },
    );
  }
  test(
    'missing/nested native fields report their name rather than patient values',
    () async {
      for (final k in DoctorAppointmentRow.keys) {
        for (final nested in [false, true]) {
          final row = {...doctorAppointmentRow()};
          if (nested) {
            row[k] = <String, Object?>{};
          } else {
            row.remove(k);
          }
          h.customRows = [row];
          await expectLater(
            load(),
            throwsA(
              isA<AppFailure>().having(
                (e) => e.message,
                'field',
                contains('"$k"'),
              ),
            ),
          );
        }
      }
    },
  );
  test(
    'empty, textual blocked and numeric zero slots keep native classification',
    () {
      expect(
        view(
          overrides: {'patient_data': '', 'schedule_time': '09:00 AM'},
        ).patientLabel,
        'No Meeting happened',
      );
      expect(view(overrides: {'patient_data': ''}).patientLabel, '...');
      final blocked = view(overrides: {'patient_data': 'Doctor on leave'});
      expect(blocked.patientLabel, 'Doctor on leave');
      expect(blocked.actions, isEmpty);
      expect(blocked.tone, DoctorAppointmentTone.empty);
      expect(view(overrides: {'patient_data': 0}).booked, isTrue);
    },
  );
  test(
    'today past availed is cyan and unavailed is pale, without claiming completion',
    () {
      final taken = view(
        overrides: {'schedule_time': '09:00 AM', 'avail_flag': '1'},
      );
      expect(taken.tone, DoctorAppointmentTone.completed);
      expect(taken.availMessage, 'Availed');
      expect(taken.showAvail, isFalse);
      expect(taken.showHistory, isTrue);
      final awaiting = view(overrides: {'schedule_time': '09:00 AM'});
      expect(awaiting.tone, DoctorAppointmentTone.awaitingAvail);
      expect(awaiting.showAvail, isTrue);
      expect(awaiting.availMessage, isNull);
      expect(awaiting.progressLabel, 'ADD PROGRESS');
    },
  );
  for (final avail in ['1', '0', '2']) {
    test('older need-avail appointment uses native avail_flag=$avail', () {
      final v = view(
        date: DateTime(2026, 10, 23),
        overrides: {
          'adm_date': '23-OCT-26',
          'avail_flag': avail,
          'rvm': '1',
          'rvm_id': 'RX-1',
          'pph_progress': '4',
          'is_ranked': '1',
        },
      );
      expect(
        v.tone,
        avail == '1'
            ? DoctorAppointmentTone.completed
            : DoctorAppointmentTone.missed,
      );
      expect(v.availMessage, avail == '1' ? 'Availed' : 'Not Availed');
      expect(v.showHistory, isFalse);
      expect(v.showAvail, isFalse);
      expect(v.prescriptionAction, DoctorAppointmentAction.prescriptionPreview);
      expect(v.showPrescription, isTrue);
      expect(v.progressLabel, 'VIEW PROGRESS');
      expect(v.showProgress, isTrue);
      expect(v.progressChecked, isTrue);
      expect(v.videoEligible, isFalse);
    });
  }
  test(
    'avail flag never completes future, exact-time, invalid or empty slots',
    () {
      for (final overrides in <JsonMap>[
        {'avail_flag': '1', 'schedule_time': '02:00 PM'},
        {'avail_flag': '1', 'schedule_time': '01:30 PM'},
        {'avail_flag': '1', 'schedule_time': 'invalid'},
        {'avail_flag': '1', 'patient_data': ''},
        {'avail_flag': '1', 'patient_data': 'Blocked Time'},
      ]) {
        final v = view(overrides: overrides);
        expect(v.tone, isNot(DoctorAppointmentTone.completed));
        expect(v.availMessage, isNull);
        expect(v.showAvail, isFalse);
      }
    },
  );
  test(
    'without need-avail, past is completed with no Avail message or button',
    () {
      final v = view(
        date: DateTime(2026, 10, 23),
        overrides: {'adm_date': '23-OCT-26'},
        flags: {'is_need_avail': '0'},
      );
      expect(v.tone, DoctorAppointmentTone.completed);
      expect(v.showAvail, isFalse);
      expect(v.availMessage, isNull);
      expect(v.showHistory, isFalse);
      expect(v.showPrescription, isFalse);
      expect(v.showProgress, isFalse);
    },
  );
  test('legacy Rx remains visible when dynamic access is off', () {
    final v = view(
      date: DateTime(2026, 10, 23),
      overrides: {'adm_date': '23-OCT-26', 'pmm': '1'},
      flags: {'can_prescribe': '0'},
    );
    expect(v.showPrescription, isTrue);
    expect(v.prescriptionLabel, 'Prescription');
    expect(v.prescriptionAction, DoctorAppointmentAction.legacyPrescription);
  });
  test(
    'upcoming history permission, today-only creation and existing Rx preview stay independent',
    () {
      final next = view(
        date: DateTime(2026, 10, 25),
        overrides: {'adm_date': '25-OCT-26'},
        flags: {'upcoming_pat_history': '0'},
      );
      expect(next.showHistory, isFalse);
      expect(next.showPrescription, isFalse);
      expect(view().showHistory, isTrue);
      expect(view().showPrescription, isTrue);
      expect(view(flags: {'pat_app_history': '0'}).showHistory, isFalse);
      expect(
        view(
          date: DateTime(2026, 10, 25),
          overrides: {'adm_date': '25-OCT-26', 'rvm': '1'},
        ).showPrescription,
        isTrue,
      );
    },
  );
  test(
    'invalid time safely keeps patient/progress but hides time-dependent actions',
    () {
      final v = view(
        overrides: {
          'schedule_time': 'invalid',
          'pph_progress': '7',
          'is_ranked': '1',
        },
      );
      expect(v.timed, isFalse);
      expect(v.showHistory, isFalse);
      expect(v.showPrescription, isFalse);
      expect(v.showAvail, isFalse);
      expect(v.showProgress, isTrue);
      expect(v.progressChecked, isTrue);
      expect(v.tone, DoctorAppointmentTone.upcoming);
    },
  );
  test('HP uses max10, checked flag and native zero text independently', () {
    expect(view(overrides: {'pph_progress': '7'}).row.progressFraction, .7);
    expect(view(overrides: {'pph_progress': '20'}).row.progressFraction, 1);
    expect(view(overrides: {'pph_progress': '-1'}).row.progressFraction, 0);
    final check = view(overrides: {'pph_progress': '0', 'is_ranked': '1'});
    expect(check.progressChecked, isTrue);
    expect(check.hasProgress, isFalse);
    final today = view(
      overrides: {
        'schedule_time': '09:00 AM',
        'pph_progress': '7',
        'is_ranked': '0',
      },
    );
    expect(today.progressLabel, 'ADD PROGRESS');
    expect(
      view(
        overrides: {
          'schedule_time': '09:00 AM',
          'pph_progress': '7',
          'is_ranked': '1',
        },
      ).progressLabel,
      'VIEW PROGRESS',
    );
    for (final bad in ['bad', 'NaN', 'Infinity']) {
      expect(
        () => view(overrides: {'pph_progress': bad}),
        throwsA(isA<AppFailure>()),
      );
    }
  });
  test(
    'video boundary at exactly ten minutes and past cutoff matches native',
    () {
      final data = <String, Object?>{
        'ts_video_conf_flag': '1',
        'schedule_time': '02:00 PM',
      };
      expect(
        view(
          overrides: data,
          now: DateTime(2026, 10, 24, 13, 49, 59),
        ).showVideoNotice,
        isTrue,
      );
      expect(
        view(overrides: data, now: DateTime(2026, 10, 24, 13, 50)).showVideo,
        isTrue,
      );
      expect(
        view(overrides: data, now: DateTime(2026, 10, 24, 14)).showVideo,
        isTrue,
      );
      expect(
        view(overrides: data, now: DateTime(2026, 10, 24, 14, 0, 1)).showVideo,
        isFalse,
      );
    },
  );
  test(
    'navigation preserves native row IDs, full progress extras and walk-in flags',
    () {
      final row = view().row;
      expect(
        doctorAppointmentRoute(DoctorAppointmentAction.avail, row).extras,
        {'AD_ID': '41'},
      );
      final progress = doctorAppointmentRoute(
        DoctorAppointmentAction.progress,
        row,
      );
      expect(progress.module, DashboardModule.doctorHealthProgress);
      expect(progress.extras.length, 15);
      expect(progress.extras['FROM_PSV'], 'false');
      expect(progress.extras['AD_ID'], '41');
      expect(progress.extras['PRD_ID'], '6');
      expect(
        doctorAppointmentRoute(DoctorAppointmentAction.walkIn, null).extras,
        {'P_PAT_TYPE': '2', 'IS_CREATED': '0'},
      );
      expect(
        doctorAppointmentRoute(
          DoctorAppointmentAction.dynamicPrescription,
          row,
        ).extras['P_AD_ID'],
        '41',
      );
      expect(
        doctorAppointmentRoute(
          DoctorAppointmentAction.legacyPrescription,
          row,
        ).extras,
        {'P_AGE': '35 Years', 'PRESCRIPTION_TYPE': '0', 'P_PH_ID': '11'},
      );
      expect(
        doctorAppointmentRoute(
          DoctorAppointmentAction.history,
          row,
        ).extras['P_PH_ID'],
        '11',
      );
    },
  );
  test('stale in-flight read cannot return usable rows', () async {
    final gate = Completer<JsonMap>();
    var current = true;
    h.transport.onGet = (_) => gate.future;
    final future = load(current: () => current);
    current = false;
    gate.complete({
      'count': 1,
      'items': [doctorAppointmentRow()],
    });
    await expectLater(future, throwsA(isA<ObsoleteRequest>()));
  });
  test(
    'forced logout, access removal, expiry and wrong doctor block appointment IO',
    () async {
      for (final change in <JsonMap>[
        {'fl_flag': '1'},
        {'access_flag': '0'},
        {'exp_date': '01-JAN-20'},
        {'doc_code': 'OTHER'},
        {'doc_id': ''},
      ]) {
        await expectLater(
          load(
            profile: AccountProfile(AccountRole.doctor, {
              ...h.doctorData,
              ...change,
            }),
          ),
          throwsA(isA<AppFailure>()),
        );
      }
      await expectLater(
        load(profile: AccountProfile(AccountRole.admin, {})),
        throwsA(isA<AppFailure>()),
      );
      expect(h.appointmentReads, isEmpty);
    },
  );
}

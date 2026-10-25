import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/core/transport.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/doctor_appointment_models.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/progress/doctor_progress_models.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/history/doctor_appointment_history_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'doctor_appointment_test_support.dart';
import 'doctor_progress_test_support.dart';

void main() {
  late DoctorProgressHarness h;
  setUp(() async {
    h = DoctorProgressHarness();
    await h.signIn();
    h.transport.requests.clear();
  });
  tearDown(() => h.auth.dispose());
  const draft = DoctorProgressDraft(
    score: 7,
    notes: 'Improving steadily',
    entryTime: '24/10/2026 01:30:00 PM',
  );
  Future<DoctorProgressSnapshot> load({
    AccountProfile? profile,
    DoctorProgressSeed? seed,
    bool Function()? current,
  }) async => await h.progress.load(
    h.auth.session!,
    profile ?? h.auth.profile!,
    seed ?? h.seed,
    isCurrent: current ?? () => true,
  );
  Future<DoctorProgressResult> submit({
    AccountProfile? profile,
    DoctorProgressSeed? seed,
    DoctorProgressDraft value = draft,
    bool Function()? current,
  }) async => await h.progress.submit(
    h.auth.session!,
    profile ?? h.auth.profile!,
    seed ?? h.seed,
    value,
    isCurrent: current ?? () => true,
  );
  test(
    'native four GETs are ordered, patient-scoped and have no write',
    () async {
      final data = await load();
      expect(h.progressReads.map((r) => r.uri.pathSegments.last), [
        'getHealthProgress',
        'getService',
        'getUnit',
        'getDocs',
      ]);
      for (final request in h.progressReads) {
        expect(request.method, 'GET');
        expect(request.headers, isEmpty);
        expect(request.uri.queryParameters, {'p_ph_id': '11'});
        expect(request.uri.host, h.auth.session!.center.baseUri.host);
      }
      expect(data.rows.map((r) => r.value('pph_id')), ['3', '2', '1']);
      expect(data.rows.first.score, 8);
      expect(data.choices[AppointmentHistoryFilter.service]!.last.id, '99');
      expect(h.progressWrites, isEmpty);
      expect(h.posts, isEmpty);
    },
  );
  for (final failed in [
    'getHealthProgress',
    'getService',
    'getUnit',
    'getDocs',
  ]) {
    test(
      'failed $failed stops the chain without returning partial data',
      () async {
        h.transport.onGet =
            (uri) async =>
                uri.pathSegments.last == failed
                    ? throw const AppFailure('Read failed')
                    : await h.respondProgress(uri);
        await expectLater(load(), throwsA(isA<AppFailure>()));
        expect(h.progressReads.last.uri.pathSegments.last, failed);
        expect(h.progressWrites, isEmpty);
      },
    );
  }
  test('empty history still loads all independent filter catalogues', () async {
    h.progressRows = [];
    final data = await load();
    expect(data.rows, isEmpty);
    expect(data.choices[AppointmentHistoryFilter.service]!.length, 4);
    expect(h.progressReads.length, 4);
  });
  test(
    'encoded arrays and native string nulls preserve rows and repair only wrapped notes',
    () async {
      final text = 'বাংলা নোট';
      final wrapped = latin1.decode(utf8.encode(text));
      h.progressRows = [
        {
          ...progressRow(notes: wrapped),
          'pph_rec_no': null,
          'pph_ad_id': 'null',
        },
        progressRow(notes: text),
      ];
      h.transport.onGet = (uri) async {
        final r = await h.respondProgress(uri);
        return {
          ...r,
          'count': r['count'].toString(),
          'items': jsonEncode(r['items']),
        };
      };
      final data = await load();
      expect(data.rows.map((r) => r.value('pph_notes')), [text, text]);
      expect(data.rows.first.value('pph_rec_no'), '');
      expect(data.rows.first.value('pph_ad_id'), '');
      expect(progressNotes('Café'), 'Café');
      expect(progressNotes('🙂 done'), '🙂 done');
    },
  );
  for (final response in <JsonMap>[
    {},
    {'count': -1},
    {'count': 'bad'},
    {'count': 1, 'items': []},
    {'count': 1, 'items': 'bad'},
    {
      'count': 1,
      'items': [
        {...progressRow(), 'pph_progress': 'not a score'},
      ],
    },
    {
      'count': 1,
      'items': [
        {...progressRow(), 'pph_notes': true},
      ],
    },
    {
      'count': 1,
      'items': [
        {'pph_progress': '5'},
      ],
    },
  ]) {
    test('malformed progress data fails clearly: $response', () async {
      h.transport.onGet = (_) async => response;
      await expectLater(load(), throwsA(isA<AppFailure>()));
      expect(h.progressReads.length, 1);
      expect(h.progressWrites, isEmpty);
    });
  }
  for (final edit in <JsonMap>[
    {'fl_flag': '1'},
    {'access_flag': '0'},
    {'exp_date': '01-JAN-20'},
    {'doc_code': 'wrong'},
    {'doc_id': '999'},
  ]) {
    test('fresh access/owner guard blocks $edit', () async {
      final profile = AccountProfile(AccountRole.doctor, {
        ...h.doctorData,
        ...edit,
      });
      await expectLater(load(profile: profile), throwsA(isA<AppFailure>()));
      expect(h.progressReads, isEmpty);
      expect(h.progressWrites, isEmpty);
    });
  }
  test(
    'progress remains available when appointment-history feature alone is off',
    () async {
      final profile = AccountProfile(AccountRole.doctor, {
        ...h.doctorData,
        'pat_app_history': '0',
      });
      expect((await load(profile: profile)).rows.length, 3);
    },
  );
  test(
    'admin profile and an invalid patient cannot open doctor progress',
    () async {
      await expectLater(
        load(profile: AccountProfile(AccountRole.admin, h.adminData)),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        load(
          seed: const DoctorProgressSeed.viewPatient(
            patientId: 'NaN',
            patientName: 'A',
            patientCode: 'B',
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.progressReads, isEmpty);
    },
  );
  for (final spec in <JsonMap>[
    {'is_ranked': '1'},
    {'adm_date': '23-OCT-26'},
    {'schedule_time': '01:30 PM'},
    {'schedule_time': '09:00 PM'},
    {'schedule_time': 'bad'},
  ]) {
    test('native add eligibility rejects $spec before mutation', () async {
      final row = DoctorAppointmentRow({
        ...doctorAppointmentRow(time: '09:00 AM'),
        ...spec,
      }, selectedDate: DateTime(2026, 10, 24));
      final seed = DoctorProgressSeed.fromAppointment(row, ownerDoctorId: '10');
      expect(seed.mayAdd(h.now), isFalse);
      expect(await submit(seed: seed), DoctorProgressResult.unavailable);
      expect(h.progressReads, isEmpty);
      expect(h.progressWrites, isEmpty);
    });
  }
  test(
    'patient-search seed is view-only and rank is separate from a prior patient score',
    () async {
      const view = DoctorProgressSeed.viewPatient(
        patientId: '11',
        patientName: 'A',
        patientCode: 'B',
      );
      expect(view.mayAdd(h.now), isFalse);
      expect(await submit(seed: view), DoctorProgressResult.unavailable);
      final seed = DoctorProgressSeed.fromAppointment(
        DoctorAppointmentRow({
          ...doctorAppointmentRow(time: '09:00 AM'),
          'pph_progress': '5',
        }, selectedDate: DateTime(2026, 10, 24)),
        ownerDoctorId: '10',
      );
      expect(seed.mayAdd(h.now), isTrue);
    },
  );
  test(
    'filter combinations use exact IDs; score follows first returned filtered row',
    () async {
      final data = await load();
      final selected = <AppointmentHistoryFilter, AppointmentHistoryChoice>{
        AppointmentHistoryFilter.doctor: const AppointmentHistoryChoice(
          '10',
          'Example Doctor',
        ),
      };
      expect(filterDoctorProgress(data.rows, selected).map((r) => r.score), [
        4,
        2,
      ]);
      selected[AppointmentHistoryFilter
          .service] = const AppointmentHistoryChoice('3', 'Physiotherapy');
      expect(filterDoctorProgress(data.rows, selected).single.score, 2);
      selected[AppointmentHistoryFilter
          .service] = const AppointmentHistoryChoice('99', 'Unused Service');
      expect(filterDoctorProgress(data.rows, selected), isEmpty);
    },
  );
  test(
    'entry time uses native dd/MM/yyyy and 12-hour seconds at midnight/noon',
    () {
      expect(
        progressEntryTime(DateTime(2026, 1, 2, 0, 3, 4)),
        '02/01/2026 12:03:04 AM',
      );
      expect(
        progressEntryTime(DateTime(2026, 1, 2, 12, 3, 4)),
        '02/01/2026 12:03:04 PM',
      );
      expect(
        progressEntryTime(DateTime(2026, 1, 2, 13, 3, 4)),
        '02/01/2026 01:03:04 PM',
      );
    },
  );
  for (final value in [
    const DoctorProgressDraft(score: 0, notes: 'A', entryTime: 'X'),
    const DoctorProgressDraft(score: 11, notes: 'A', entryTime: 'X'),
    const DoctorProgressDraft(score: 7, notes: ' \n ', entryTime: 'X'),
    const DoctorProgressDraft(score: 7, notes: 'A', entryTime: ''),
  ]) {
    test('invalid score/note/time cannot reach the write', () async {
      await expectLater(submit(value: value), throwsA(isA<AppFailure>()));
      expect(h.progressReads, isEmpty);
      expect(h.progressWrites, isEmpty);
    });
  }
  test(
    'Retrofit JSON body has all twelve exact string fields and UTF-8 notes',
    () async {
      const note = 'ভালো হচ্ছে 🙂\n"Quoted" & <safe> text';
      expect(
        await submit(
          value: const DoctorProgressDraft(
            score: 7,
            notes: note,
            entryTime: '24/10/2026 01:30:00 PM',
          ),
        ),
        DoctorProgressResult.created,
      );
      final request = h.progressWrites.single;
      expect(request.uri.path, endsWith('/health_progress/InsertPatProgress'));
      expect(request.uri.queryParameters, isEmpty);
      expect(request.headers, isEmpty);
      expect(request.contentType, 'application/json; charset=utf-8');
      final body = nativeObject(utf8.decode(request.body));
      expect(body, {
        'P_PH_ID': '11',
        'P_CAT_ID': '4',
        'P_DOC_ID': '10',
        'P_DEPTS_ID': '2',
        'P_PRM_ID': '5',
        'P_PFN_ID': '3',
        'P_PRD_ID': '6',
        'P_AD_ID': '41',
        'P_PROGRESS': '7',
        'P_NOTES': note,
        'P_DOC_CODE': h.doctorData['doc_code'],
        'P_ENTRY_TIME': '24/10/2026 01:30:00 PM',
      });
      expect(h.progressReads.single.uri.pathSegments.last, 'getHealthProgress');
      expect(
        h.appointmentReads.single.uri.queryParameters['pdate'],
        '24-OCT-26',
      );
      expect(h.posts, isEmpty);
    },
  );
  test(
    'actual HTTP body preserves JSON content type and Unicode bytes',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final wire = IoTransport();
      String raw = '', mime = '', method = '';
      int length = 0;
      final capture = () async {
        final r = await server.first;
        method = r.method;
        mime = r.headers.value(HttpHeaders.contentTypeHeader) ?? '';
        length = r.contentLength;
        raw = await utf8.decoder.bind(r).join();
        r.response.headers.contentType = ContentType.json;
        r.response.write('{"string_out":"Successfully Created"}');
        await r.response.close();
      }();
      h.transport.onBytes =
          (r) => wire.postBytes(
            Uri.parse(
              'http://127.0.0.1:${server.port}/health_progress/InsertPatProgress',
            ),
            r.body,
            headers: r.headers,
            contentType: r.contentType,
          );
      try {
        expect(
          await submit(
            value: const DoctorProgressDraft(
              score: 10,
              notes: 'বাংলা 🙂',
              entryTime: '24/10/2026 01:30:00 PM',
            ),
          ),
          DoctorProgressResult.created,
        );
        await capture;
        expect(method, 'POST');
        expect(mime, contains('application/json'));
        expect(mime, contains('charset=utf-8'));
        expect(length, utf8.encode(raw).length);
        expect(nativeObject(raw)['P_NOTES'], 'বাংলা 🙂');
      } finally {
        wire.close();
        await server.close(force: true);
      }
    },
  );
  for (final status in <Object?>[
    null,
    '',
    'null',
    1,
    <String, Object?>{},
    'Success',
    'Successfully Created ',
    'Denied',
  ]) {
    test('only exact native success is accepted: $status', () async {
      h.transport.onBytes = (_) async => {'string_out': status};
      await expectLater(submit(), throwsA(isA<AppFailure>()));
      expect(h.progressWrites.length, 1);
    });
  }
  test(
    'existing record for this schedule, including another doctor, never posts twice',
    () async {
      h.progressRows = [progressRow(appointment: '41', doctor: '20')];
      expect(await submit(), DoctorProgressResult.alreadyAdded);
      expect(h.progressWrites, isEmpty);
      expect(h.appointmentReads, isEmpty);
    },
  );
  test(
    'fresh rank already set blocks the write even if history is empty',
    () async {
      final seed = h.seed;
      h.progressRows = [];
      h.customRows = [
        {...h.customRows!.first, 'is_ranked': '1'},
      ];
      expect(await submit(seed: seed), DoctorProgressResult.alreadyAdded);
      expect(h.progressWrites, isEmpty);
    },
  );
  for (final field in [
    'patient_data',
    'pat_id',
    'pfn_id',
    'depts_id',
    'ad_prm_id',
    'ad_prd_id',
    'ph_cat_id',
    'adm_date',
    'schedule_time',
  ]) {
    test('reassigned $field invalidates the retained confirmation', () async {
      final seed = h.seed;
      h.customRows = [
        {...h.customRows!.first, field: 'changed'},
      ];
      expect(await submit(seed: seed), DoctorProgressResult.unavailable);
      expect(h.progressWrites, isEmpty);
    });
  }
  test(
    'explicit retry reconciles a committed timeout before another POST',
    () async {
      h.transport.onBytes = (r) async {
        h.commitProgress(r);
        throw const AppFailure('Timed out', kind: FailureKind.network);
      };
      final seed = h.seed;
      await expectLater(submit(seed: seed), throwsA(isA<AppFailure>()));
      expect(h.progressWrites.length, 1);
      expect(await submit(seed: seed), DoctorProgressResult.alreadyAdded);
      expect(h.progressWrites.length, 1);
    },
  );
  test(
    'stale generation before and during reads does not continue the pipeline',
    () async {
      await expectLater(
        load(current: () => false),
        throwsA(isA<ObsoleteRequest>()),
      );
      expect(h.progressReads, isEmpty);
      var current = true;
      final gate = Completer<JsonMap>();
      h.transport.onGet = (_) => gate.future;
      final f = load(current: () => current);
      final check = expectLater(f, throwsA(isA<ObsoleteRequest>()));
      current = false;
      gate.complete({'count': 0});
      await check;
      expect(h.progressReads.length, 1);
      expect(h.progressWrites, isEmpty);
    },
  );
  test('a late POST success cannot finish an obsolete operation', () async {
    var current = true;
    final gate = Completer<JsonMap>();
    h.transport.onBytes = (_) => gate.future;
    final f = submit(current: () => current);
    final check = expectLater(f, throwsA(isA<ObsoleteRequest>()));
    await Future<void>.delayed(Duration.zero);
    expect(h.progressWrites.length, 1);
    current = false;
    gate.complete({'string_out': 'Successfully Created'});
    await check;
  });
}

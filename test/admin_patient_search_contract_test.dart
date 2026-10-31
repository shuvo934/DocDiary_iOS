import 'dart:async';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/patient_search/admin_patient_search_models.dart';
import 'package:docdiary_ios/features/patient_search/patient_search_models.dart';
import 'package:docdiary_ios/features/prescription/normal_prescription_models.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/progress/doctor_progress_models.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/progress/doctor_progress_repository.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_repository.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_preview_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'admin_patient_search_test_support.dart';

void main() {
  late AdminPatientSearchHarness h;
  setUp(() async {
    h = AdminPatientSearchHarness();
    await h.signIn();
    h.transport.requests.clear();
  });
  tearDown(() => h.auth.dispose());
  AccountProfile profile([Map<String, Object?> changes = const {}]) =>
      AccountProfile(h.auth.profile!.role, {...h.adminData, ...changes});
  Future<List<PatientSearchRow>> patients({
    String? search,
    int year = 2023,
    bool Function()? current,
  }) async => h.adminSearch.patients(
    h.auth.session!,
    profile(),
    year,
    search: search,
    isCurrent: current ?? () => true,
  );
  PatientSearchRow patient() => PatientSearchRow(h.patientRows.first);
  test(
    'recent and search requests use exact native year/name parameters with no doctor scope',
    () async {
      await patients();
      expect(
        h.patientReads.single.path,
        endsWith('/patient_search/getHundredPatListNew'),
      );
      expect(h.patientReads.single.queryParameters, {'p_year': '2023'});
      h.transport.requests.clear();
      await patients(search: 'Sample Patient');
      expect(
        h.patientReads.single.path,
        endsWith('/patient_search/getPatienListBySearch'),
      );
      expect(h.patientReads.single.queryParameters, {
        'p_year': '2023',
        'p_name': 'Sample Patient',
      });
    },
  );
  test(
    'search safely encodes Unicode, plus, quotes, ampersand and percent in one value',
    () async {
      const text = "রহিম + O'Neil & 50%";
      await patients(search: text);
      expect(h.patientReads.single.queryParameters, {
        'p_year': '2023',
        'p_name': text,
      });
    },
  );
  for (final query in ['', 'ab', 'a.b', 'a,b', 'a-b']) {
    test('native validation rejects "$query" before a patient GET', () async {
      expect(adminPatientSearchError(query), isNotNull);
      await expectLater(patients(search: query), throwsA(isA<AppFailure>()));
      expect(h.patientReads, isEmpty);
    });
  }
  test('validation uses native messages and punctuation typing hint', () {
    expect(adminPatientSearchError(''), 'Please Provide Patient Name or Code');
    expect(
      adminPatientSearchError('a'),
      'Name or Code must be greater than 2 character',
    );
    expect(
      adminPatientSearchError('a.b'),
      "Name or Code must not contain '.,-' character",
    );
    expect(adminPatientSearchInvalidCharacter('a.b'), isTrue);
    expect(adminPatientSearchError('রহিম'), isNull);
  });
  for (final year in [1949, 2027]) {
    test('year $year is outside native range', () async {
      await expectLater(patients(year: year), throwsA(isA<AppFailure>()));
      expect(h.patientReads, isEmpty);
    });
  }
  test(
    'encoded rows keep all patients, use native no-year display and immutable storage',
    () async {
      h.encodedPatients = true;
      final rows = await patients();
      expect(rows.length, 2);
      expect(rows.first.year, '');
      expect(rows.last.genderAge, contains('Male'));
      expect(rows.last.progress, 6);
      expect(() => rows.clear(), throwsUnsupportedError);
      expect(() => rows.first.values.clear(), throwsUnsupportedError);
    },
  );
  for (final data in [
    <String, Object?>{},
    {'pat_list': 'broken'},
    {
      'pat_list': [
        {'ph_id': 'bad'},
      ],
    },
  ]) {
    test('malformed patient response $data is rejected atomically', () async {
      h.patientResponse = data;
      await expectLater(patients(), throwsA(isA<AppFailure>()));
    });
  }
  test('obsolete response is discarded after transport returns', () async {
    var current = true;
    final pending = Completer<Map<String, Object?>>();
    h.pendingPatients = pending;
    final request = patients(current: () => current);
    final check = expectLater(request, throwsA(isA<ObsoleteRequest>()));
    await Future<void>.delayed(Duration.zero);
    current = false;
    pending.complete({'pat_list': h.patientRows});
    await check;
  });
  for (final changes in [
    {'usr_id': '999'},
    {'usr_mob_app_access': '0'},
    {'usr_mob_forced_log_out_flag': '1'},
    {'exp_date': '01-JAN-20'},
  ]) {
    test('changed account/access $changes blocks patient reads', () async {
      await expectLater(
        h.adminSearch.patients(
          h.auth.session!,
          profile(changes),
          2023,
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.patientReads, isEmpty);
    });
  }
  test(
    'native Admin response may omit usr_id; supplied mismatched IDs still fail',
    () async {
      expect(h.adminData.containsKey('usr_id'), isFalse);
      expect(await patients(), hasLength(2));
    },
  );
  test('calling requires all_access_flag 1 and a nonempty telephone value', () {
    expect(adminPatientMayCall(profile(), patient()), isTrue);
    expect(
      adminPatientMayCall(profile({'all_access_flag': '0'}), patient()),
      isFalse,
    );
    expect(
      adminPatientMayCall(
        profile(),
        PatientSearchRow({...h.patientRows.first, 'pat_cell': 'null'}),
      ),
      isFalse,
    );
    expect(
      adminPatientPhoneUri(
        PatientSearchRow({
          ...h.patientRows.first,
          'pat_cell': '+880 1700 000000',
        }),
      ).scheme,
      'tel',
    );
  });
  test(
    'Admin history is read-only and always sends a blank doctor filter',
    () async {
      final rows = await h.adminSearch.views.history(
        h.auth.session!,
        profile(),
        patient(),
        isCurrent: () => true,
      );
      expect(rows, isNotEmpty);
      final uri = h.transport.requests.single.uri;
      expect(uri.path, endsWith('/dynamic_presc/getPrescriptionHistory'));
      expect(uri.queryParameters, {
        'p_ph_id': '11',
        'p_pat_id': '111',
        'p_doc_id': '',
      });
      expect(h.posts, isEmpty);
    },
  );
  test(
    'presc_active alone selects Admin dynamic history, without can_prescribe',
    () async {
      expect(profile().value('can_prescribe'), '');
      await h.adminSearch.views.history(
        h.auth.session!,
        profile(),
        patient(),
        isCurrent: () => true,
      );
      await expectLater(
        h.adminSearch.views.history(
          h.auth.session!,
          profile({'presc_active': '0'}),
          patient(),
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'Admin calendar reuses the native four-month patient-only GET',
    () async {
      final rows = await h.adminSearch.views.calendar(
        h.auth.session!,
        profile(),
        patient(),
        PatientAppointmentWindow(h.now),
        isCurrent: () => true,
      );
      expect(rows.length, 3);
      expect(h.transport.requests.single.uri.queryParameters, {
        'PHID': '11',
        'FIRST_MONTH': '01-SEP-26',
        'LAST_MONTH': '31-DEC-26',
      });
    },
  );
  test(
    'Admin normal prescription and progress views work without any write capability',
    () async {
      final seed = NormalPrescriptionSeed.patient(h.patientRows.first);
      expect(
        await h.rx.load(
          h.auth.session!,
          profile({'presc_active': '0'}),
          seed,
          isCurrent: () => true,
        ),
        isNotNull,
      );
      final progress = DoctorProgressRepository(h.appointments);
      const progressSeed = DoctorProgressSeed.viewPatient(
        patientId: '11',
        patientName: 'Sample',
        patientCode: 'P-11',
      );
      expect(
        (await progress.load(
          h.auth.session!,
          profile(),
          progressSeed,
          isCurrent: () => true,
        )).rows,
        isEmpty,
      );
      await expectLater(
        h.rx.create(h.auth.session!, profile(), seed, isCurrent: () => true),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => h.rx.guard(
          h.auth.session!,
          profile(),
          seed,
          () => true,
          write: true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => h.appointments.guard(h.auth.session!, profile(), () => true),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => DynamicPrescriptionRepository(
          h.appointments,
        ).clinical.guard(h.auth.session!, profile(), () => true),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        progress.submit(
          h.auth.session!,
          profile(),
          progressSeed,
          const DoctorProgressDraft(
            score: 5,
            notes: 'Sample note',
            entryTime: '13:30',
          ),
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.posts, isEmpty);
    },
  );
  test(
    'Admin preview GET/export guard use presc_active without granting builder access',
    () async {
      final repo = DynamicPrescriptionPreviewRepository(
        DynamicPrescriptionRepository(h.appointments),
      );
      final data = await repo.load(
        h.auth.session!,
        profile(),
        '44',
        isCurrent: () => true,
      );
      expect(data.rvmId, '44');
      repo.guard(h.auth.session!, profile(), () => true);
      expect(
        () => repo.guard(
          h.auth.session!,
          profile({'presc_active': '0'}),
          () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.posts, isEmpty);
    },
  );
}

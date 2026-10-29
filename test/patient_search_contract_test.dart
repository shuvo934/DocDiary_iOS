import 'dart:async';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/features/patient_search/patient_search_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'patient_search_test_support.dart';

void main() {
  group('native doctor PatientSearch contracts', () {
    for (final all in [false, true]) {
      for (final head in [false, true]) {
        test(
          'normal list all=$all head=$head preserves native scope',
          () async {
            final h = PatientSearchHarness(dynamicMode: false);
            addTearDown(h.auth.dispose);
            h.doctorData.addAll({
              'all_presc': all ? '1' : '0',
              'doc_head_flag': head ? '1' : '0',
            });
            await h.signIn();
            h.transport.requests.clear();
            final rows = await h.searchRepository.patients(
              h.auth.session!,
              h.auth.profile!,
              2023,
              isCurrent: () => true,
            );
            expect(rows, hasLength(2));
            final uri = h.patientReads.single;
            expect(
              uri.pathSegments.last,
              all ? 'getPatientList' : 'getPatientListNew',
            );
            expect(uri.queryParameters, {
              'p_year': '2023',
              if (!all) ...{'p_doc_id': head ? '' : '10', 'p_deptd_id': '8'},
            });
            expect(h.posts, isEmpty);
            expect(h.transport.binaryRequests, isEmpty);
          },
        );
      }
      test(
        'dynamic list and all-year search all=$all match native endpoints',
        () async {
          final h = PatientSearchHarness();
          addTearDown(h.auth.dispose);
          h.doctorData['all_presc'] = all ? '1' : '0';
          h.encodedPatients = true;
          await h.signIn();
          h.transport.requests.clear();
          await h.searchRepository.patients(
            h.auth.session!,
            h.auth.profile!,
            2023,
            isCurrent: () => true,
          );
          expect(h.patientReads.last.pathSegments.last, 'getDyPresPatientList');
          expect(h.patientReads.last.queryParameters, {
            'p_year': '2023',
            if (!all) 'p_doc_id': '10',
          });
          const text = 'বাংলা & A/B? #+.,-';
          await h.searchRepository.patients(
            h.auth.session!,
            h.auth.profile!,
            2023,
            search: ' $text ',
            isCurrent: () => true,
          );
          expect(
            h.patientReads.last.pathSegments.last,
            'getDyPresPatientListBySearch',
          );
          expect(h.patientReads.last.queryParameters, {
            'p_search': text,
            if (!all) 'p_doc_id': '10',
          });
          expect(h.patientReads.last.fragment, isEmpty);
          expect(h.posts, isEmpty);
          expect(h.transport.binaryRequests, isEmpty);
        },
      );
      test(
        'history all=$all uses patient identity and empty/own doctor, fresh on every opening',
        () async {
          final h = PatientSearchHarness();
          addTearDown(h.auth.dispose);
          h.doctorData['all_presc'] = all ? '1' : '0';
          await h.signIn();
          h.transport.requests.clear();
          final patient = PatientSearchRow(h.patientRows.first);
          for (var i = 0; i < 2; i++) {
            final rows = await h.searchRepository.history(
              h.auth.session!,
              h.auth.profile!,
              patient,
              isCurrent: () => true,
            );
            expect(rows, hasLength(3));
          }
          final reads =
              h.transport.requests
                  .where((r) => r.uri.path.endsWith('/getPrescriptionHistory'))
                  .toList();
          expect(reads, hasLength(2));
          expect(reads.first.uri.queryParameters, {
            'p_ph_id': '11',
            'p_pat_id': '111',
            'p_doc_id': all ? '' : '10',
          });
          expect(h.posts, isEmpty);
        },
      );
    }
    for (final text in ['', ' ', 'ab']) {
      test('invalid remote query "$text" does not dispatch', () async {
        final h = PatientSearchHarness();
        addTearDown(h.auth.dispose);
        await h.signIn();
        h.transport.requests.clear();
        await expectLater(
          h.searchRepository.patients(
            h.auth.session!,
            h.auth.profile!,
            2026,
            search: text,
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
        expect(h.patientReads, isEmpty);
      });
    }
    for (final year in [1949, 2027]) {
      test('out-of-range year $year cannot dispatch', () async {
        final h = PatientSearchHarness();
        addTearDown(h.auth.dispose);
        await h.signIn();
        h.transport.requests.clear();
        await expectLater(
          h.searchRepository.patients(
            h.auth.session!,
            h.auth.profile!,
            year,
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
        expect(h.patientReads, isEmpty);
      });
    }
    test(
      'obsolete responses are not published; no POST is available in the search flow',
      () async {
        final h = PatientSearchHarness();
        addTearDown(h.auth.dispose);
        await h.signIn();
        h.transport.requests.clear();
        final pending = Completer<Map<String, Object?>>();
        h.pendingPatients = pending;
        var current = true;
        final result = h.searchRepository.patients(
          h.auth.session!,
          h.auth.profile!,
          2026,
          isCurrent: () => current,
        );
        current = false;
        pending.complete({'pat_list': h.patientRows});
        await expectLater(result, throwsA(isA<ObsoleteRequest>()));
        expect(h.posts, isEmpty);
        expect(h.transport.binaryRequests, isEmpty);
      },
    );
    for (final malformed in <Map<String, Object?>>[
      {},
      {'pat_list': 'not json'},
      {
        'pat_list': [
          {'ph_id': '0', 'pat_id': '111'},
        ],
      },
    ]) {
      test('malformed patient response is rejected: $malformed', () async {
        final h = PatientSearchHarness();
        addTearDown(h.auth.dispose);
        await h.signIn();
        h.patientResponse = malformed;
        await expectLater(
          h.searchRepository.patients(
            h.auth.session!,
            h.auth.profile!,
            2026,
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
      });
    }
    test(
      'normal prescription permissions cannot open dynamic history',
      () async {
        final h = PatientSearchHarness(dynamicMode: false);
        addTearDown(h.auth.dispose);
        await h.signIn();
        h.transport.requests.clear();
        await expectLater(
          h.searchRepository.history(
            h.auth.session!,
            h.auth.profile!,
            PatientSearchRow(h.patientRows.first),
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
        expect(h.transport.requests, isEmpty);
      },
    );
  });
  group('native patient card values', () {
    for (final entry
        in {
          '': 0,
          'null': 0,
          '-1': 0,
          '6.5': 7,
          '11': 10,
          'NaN': 0,
          'Infinity': 0,
          'bad': 0,
        }.entries) {
      test(
        'progress ${entry.key} becomes ${entry.value} of ten',
        () => expect(
          PatientSearchRow(searchedPatient(progress: entry.key)).progress,
          entry.value,
        ),
      );
    }
    test(
      'normal name/code filter is case insensitive; nullable address/age and immutable values are preserved',
      () {
        final source = searchedPatient(name: 'Sample Name');
        final row = PatientSearchRow(source);
        source['pat_name'] = 'Changed';
        expect(row.name, 'Sample Name');
        expect(row.matches('SAMPLE'), isTrue);
        expect(row.matches('00011'), isTrue);
        expect(row.matches('017000'), isFalse);
        expect(() => row.values.clear(), throwsUnsupportedError);
        final minimal = PatientSearchRow({
          'ph_id': '11',
          'gender': 'Female',
          'dd_thana_name': null,
          'pat_age': 'null',
        });
        expect(minimal.genderAge, 'Female');
        expect(minimal.area, isEmpty);
      },
    );
  });
  group('native Appointment View', () {
    test('four-month window crosses year/leap boundaries exactly', () {
      final a = PatientAppointmentWindow(DateTime(2026, 12, 29));
      expect(a.first, DateTime(2026, 11));
      expect(a.last, DateTime(2027, 2, 28));
      final b = PatientAppointmentWindow(DateTime(2024, 1, 1));
      expect(b.first, DateTime(2023, 12));
      expect(b.last, DateTime(2024, 3, 31));
    });
    test(
      'calendar GET has original uppercase parameter names and full inclusive dates',
      () async {
        final h = PatientSearchHarness();
        addTearDown(h.auth.dispose);
        await h.signIn();
        h.transport.requests.clear();
        final rows = await h.searchRepository.calendar(
          h.auth.session!,
          h.auth.profile!,
          PatientSearchRow(h.patientRows.first),
          PatientAppointmentWindow(h.now),
          isCurrent: () => true,
        );
        expect(rows, hasLength(3));
        expect(h.transport.requests.single.uri.queryParameters, {
          'PHID': '11',
          'FIRST_MONTH': '01-SEP-26',
          'LAST_MONTH': '31-DEC-26',
        });
        expect(
          h.transport.requests.single.uri.pathSegments.last,
          'getPatAppointment',
        );
        expect(h.posts, isEmpty);
      },
    );
    final now = DateTime(2026, 10, 24, 13, 30);
    final completed = PatientCalendarAppointment(
      patientCalendarRow(time: '10:00 AM'),
    );
    final upcoming = PatientCalendarAppointment(
      patientCalendarRow(time: '01:30 PM'),
    );
    final canceled = PatientCalendarAppointment(
      patientCalendarRow(canceled: true),
    );
    final cases = <List<PatientCalendarAppointment>, String>{
      [completed]: 'done_appt',
      [upcoming]: 'upcoming_appt',
      [canceled]: 'cancel_appt',
      [completed, upcoming]: 'done_upcoming_appt',
      [completed, canceled]: 'cancel_done_appt',
      [upcoming, canceled]: 'cancel_upcoming_appt',
      [completed, upcoming, canceled]: 'cancel_done_upcoming_appt',
    };
    for (final entry in cases.entries) {
      test(
        'mixed day uses ${entry.value}',
        () => expect(patientCalendarMarker(entry.key, now), entry.value),
      );
    }
    test(
      'past/future date status respects native strict time boundary and cancellation',
      () {
        expect(completed.status(now), PatientAppointmentStatus.completed);
        expect(upcoming.status(now), PatientAppointmentStatus.upcoming);
        expect(canceled.status(now), PatientAppointmentStatus.canceled);
        expect(
          PatientCalendarAppointment(
            patientCalendarRow(day: '23-OCT-26'),
          ).status(now),
          PatientAppointmentStatus.completed,
        );
        expect(
          PatientCalendarAppointment(
            patientCalendarRow(day: '25-OCT-26'),
          ).status(now),
          PatientAppointmentStatus.upcoming,
        );
        expect(
          () =>
              PatientCalendarAppointment(patientCalendarRow(time: '25:99 PM')),
          throwsA(isA<AppFailure>()),
        );
      },
    );
  });
}

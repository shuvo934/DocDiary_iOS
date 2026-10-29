import 'dart:async';
import 'dart:convert';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_patient_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_seed.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_save_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dynamic_review_test_support.dart';
import 'dynamic_walkin_test_support.dart';

void main() {
  group('native Walk-in API and identity', () {
    late DynamicReviewHarness h;
    setUp(() async {
      h = DynamicReviewHarness();
      await h.signIn();
      h.transport.requests.clear();
    });
    tearDown(() => h.auth.dispose());
    test(
      'recent year and all-year search use exact native GETs, escaped query and valid registration rows',
      () async {
        h.transport.onGet =
            (_) async => {
              'pat_list': [
                null,
                <String, Object?>{},
                ...walkInRows(),
                {'pat_id': 1, 'ph_id': 2, 'pat_name': 'null'},
              ],
            };
        final list = await h.repository.patients.load(
          h.auth.session!,
          h.auth.profile!,
          year: '2026',
          isCurrent: () => true,
        );
        expect(list.map((p) => p.historyId), ['201', '202', '203']);
        expect(
          h.transport.requests.single.uri.pathSegments.last,
          'getHundredPatListYearWise',
        );
        expect(h.transport.requests.single.uri.queryParameters, {
          'p_year': '2026',
        });
        await h.repository.patients.load(
          h.auth.session!,
          h.auth.profile!,
          query: '  রহিম & + 019  ',
          isCurrent: () => true,
        );
        final uri = h.transport.requests.last.uri;
        expect(uri.pathSegments.last, 'getPatListBySearch');
        expect(uri.queryParameters, {'p_search': 'রহিম & + 019'});
        expect(uri.toString(), contains('%26'));
        expect(uri.toString(), contains('%2B'));
        expect(h.transport.binaryRequests, isEmpty);
      },
    );
    test(
      'short search sends no GET, missing native list is empty, invalid year fails before GET',
      () async {
        for (final query in ['', 'a', 'ab']) {
          expect(
            await h.repository.patients.load(
              h.auth.session!,
              h.auth.profile!,
              query: query,
              isCurrent: () => true,
            ),
            isEmpty,
          );
        }
        expect(h.transport.requests, isEmpty);
        await expectLater(
          h.repository.patients.load(
            h.auth.session!,
            h.auth.profile!,
            year: ' ',
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
        h.transport.onGet = (_) async => {};
        expect(
          await h.repository.patients.load(
            h.auth.session!,
            h.auth.profile!,
            year: '2026',
            isCurrent: () => true,
          ),
          isEmpty,
        );
      },
    );
    test(
      'feature/access and stale-response guards apply before and after patient reads',
      () async {
        final profile = h.auth.profile!;
        final denied = AccountProfile(profile.role, {
          ...profile.values,
          'can_prescribe': '0',
        });
        await expectLater(
          h.repository.patients.load(
            h.auth.session!,
            denied,
            year: '2026',
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
        expect(h.transport.requests, isEmpty);
        var current = true;
        h.transport.onGet = (_) async {
          current = false;
          return {'pat_list': walkInRows()};
        };
        await expectLater(
          h.repository.patients.load(
            h.auth.session!,
            profile,
            query: 'Patient',
            isCurrent: () => current,
          ),
          throwsA(isA<ObsoleteRequest>()),
        );
      },
    );
    test(
      'unselected Walk-in seed needs a patient; selected native identity has today date and no appointment',
      () {
        final seed = DynamicPrescriptionSeed.fromExtras(
          {'P_PAT_TYPE': '2', 'IS_CREATED': '0'},
          ownerDoctorId: '10',
          now: h.now,
        );
        expect(seed.needsPatient, isTrue);
        expect(seed.valid, isFalse);
        expect(seed.visitDate, '24-OCT-26');
        final selected = selectedWalkInSeed();
        expect(selected.valid, isTrue);
        expect(selected.appointmentId, isEmpty);
        expect(selected.patientType, '2');
        expect(selected.prescriptionType, '2');
        expect(selected.editableOn(h.now), isTrue);
        expect(selectedWalkInSeed(prescriptionType: '1').prescriptionType, '1');
        expect(h.seed().patientType, '1');
        expect(h.seed().prescriptionType, '1');
      },
    );
    for (final type in ['1', '2']) {
      test(
        'Walk-in ${type == '1' ? 'Outdoor' : 'Indoor'} create/update keeps native headers, blank AD_ID and iOS flag 4',
        () async {
          final f = DynamicReviewDraftFixture()..populate();
          addTearDown(f.dispose);
          h.transport.onBytes = (_) async => dynamicSavedResponse();
          final seed = selectedWalkInSeed(prescriptionType: type);
          for (final updating in [false, true]) {
            final request = DynamicPrescriptionSaveRequest.capture(
              seed: seed,
              profile: h.auth.profile!,
              review: f.review,
              data: updating ? {'rvm_id': '901'} : {},
            );
            await h.repository.save(
              h.auth.session!,
              h.auth.profile!,
              seed,
              request,
              isCurrent: () => true,
            );
            final sent = h.transport.binaryRequests.last;
            expect(sent.headers['P_PAT_ID'], '101');
            expect(sent.headers['P_PH_ID'], '201');
            expect(sent.headers['P_AD_ID'], '');
            expect(sent.headers['P_INSERT_TYPE'], '4');
            expect(sent.headers.length, updating ? 17 : 18);
            expect(sent.headers.containsKey('P_REFERENCE'), isFalse);
            expect(sent.headers.containsKey('P_NOTES'), isFalse);
            final body = nativeObject(utf8.decode(sent.body));
            expect(body['reference'], 'Ref line 1\r\nline 2');
            expect(body['prescription_notes'], 'Notes line 1\nline 2');
            expect(sent.headers['P_PATIENT_TYPE'], updating ? null : '2');
            expect(sent.headers['P_PRESCRIPTION_TYPE'], updating ? null : type);
            expect(
              sent.uri.pathSegments.last,
              updating ? 'updatePrescription' : 'insertPrescription',
            );
          }
        },
      );
    }
    test(
      'Walk-in lookup cannot query or bind an unrelated prescription by empty appointment',
      () async {
        await expectLater(
          h.repository.lookup(
            h.auth.session!,
            h.auth.profile!,
            selectedWalkInSeed(),
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
        expect(h.transport.requests, isEmpty);
      },
    );
  });
  group('native patient selection debounce', () {
    late DynamicPatientController c;
    var recent = 0, search = 0;
    Future<List<DynamicPatientItem>> Function(String)? onRecent, onSearch;
    setUp(() {
      recent = 0;
      search = 0;
      onRecent = null;
      onSearch = null;
      c = DynamicPatientController(
        currentYear: 2026,
        loadRecent: (year) async {
          recent++;
          return onRecent == null ? walkInPatients() : await onRecent!(year);
        },
        searchPatients: (query) async {
          search++;
          return onSearch == null ? walkInPatients() : await onSearch!(query);
        },
      );
    });
    tearDown(() => c.dispose());
    testWidgets(
      'native current year plus 50 years, default Indoor, three characters and 500ms debounce',
      (tester) async {
        expect(c.years.length, 51);
        expect(c.years.first, '2026');
        expect(c.years.last, '1976');
        expect(c.prescriptionType, '2');
        await c.start();
        expect(recent, 1);
        c.select(c.items.first);
        expect(c.canSelect, isTrue);
        c.setQuery('ab');
        expect(c.selected, isNull);
        expect(c.yearEnabled, isFalse);
        expect(c.emptyText, 'Enter at least 3 characters to search');
        await tester.pump(const Duration(milliseconds: 600));
        expect(search, 0);
        c.setQuery('One');
        await tester.pump(const Duration(milliseconds: 499));
        expect(search, 0);
        await tester.pump(const Duration(milliseconds: 1));
        expect(search, 1);
        expect(c.items.length, 3);
        c.select(c.items.first);
        c.setPrescriptionType('1');
        expect(c.selected!.historyId, '201');
        c.setQuery('');
        await tester.pump();
        expect(recent, 2);
        expect(c.yearEnabled, isTrue);
        expect(c.selected, isNull);
      },
    );
    testWidgets(
      'a recent response cannot restore stale rows during debounce and query replacement',
      (tester) async {
        final pending = Completer<List<DynamicPatientItem>>();
        onRecent = (_) => pending.future;
        final first = c.start();
        c.setQuery('Old');
        c.setQuery('New');
        pending.complete(walkInPatients());
        await first;
        expect(c.items, isEmpty);
        expect(c.loading, isFalse);
        await tester.pump(const Duration(milliseconds: 500));
        expect(search, 1);
        expect(c.items.length, 3);
      },
    );
    testWidgets(
      'year disabled in search and changing year clears selection with a fresh request',
      (tester) async {
        await c.start();
        c.setQuery('Test');
        c.setYear('2025');
        expect(c.year, '2026');
        c.setQuery('');
        await tester.pump();
        c.select(c.items.first);
        c.setYear('2025');
        await tester.pump();
        expect(c.year, '2025');
        expect(c.selected, isNull);
        expect(recent, 3);
        expect(search, 0);
      },
    );
    testWidgets(
      'search error tap retry, empty results and repeated PAT_ID registrations retain native rules',
      (tester) async {
        onSearch = (_) async => throw const AppFailure('Patient lookup failed');
        c.setQuery('Test');
        await tester.pump(const Duration(milliseconds: 500));
        expect(c.emptyText, 'Patient lookup failed\nTap to retry');
        onSearch = (_) async => walkInPatients();
        await c.retry();
        c.select(c.items.last);
        expect(c.selected!.historyId, '203');
        expect(c.selected!.patientId, '101');
        onSearch = (_) async => [];
        await c.retry();
        expect(c.emptyText, 'No patient found');
        expect(c.canSelect, isFalse);
      },
    );
    testWidgets(
      'closing cancels a queued search and ignores an in-flight patient response',
      (tester) async {
        c.setQuery('Test');
        c.close();
        await tester.pump(const Duration(seconds: 1));
        expect(search, 0);
        final pending = Completer<List<DynamicPatientItem>>();
        onRecent = (_) => pending.future;
        c.setQuery('');
        expect(recent, 1);
        c.close();
        pending.complete(walkInPatients());
        await tester.pump();
        expect(c.items, isEmpty);
        expect(c.selected, isNull);
      },
    );
  });
}

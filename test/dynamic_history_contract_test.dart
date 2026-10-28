import 'dart:async';
import 'dart:convert';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_history_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_template_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_clinical_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_advice_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dynamic_review_test_support.dart';
import 'dynamic_template_test_support.dart';
import 'dynamic_history_test_support.dart';

void main() {
  group('native History GET contracts', () {
    late DynamicReviewHarness h;
    setUp(() async {
      h = DynamicReviewHarness();
      await h.signIn();
      h.transport.requests.clear();
    });
    tearDown(() => h.auth.dispose());
    test(
      'list uses selected patient and owner doctor, skips missing IDs and retains native order/duplicates',
      () async {
        h.transport.onGet =
            (_) async => {
              'items': [
                null,
                <String, Object?>{},
                historyRow(),
                historyRow(id: '599'),
                historyRow(),
              ],
            };
        final items = await h.repository.history(
          h.auth.session!,
          h.auth.profile!,
          h.seed(),
          isCurrent: () => true,
        );
        expect(items.map((item) => item.rvmId), ['600', '599', '600']);
        expect(
          h.transport.requests.single.uri.pathSegments.last,
          'getPrescriptionHistory',
        );
        expect(h.transport.requests.single.uri.queryParameters, {
          'p_ph_id': '11',
          'p_pat_id': '21',
          'p_doc_id': '10',
        });
        expect(h.transport.binaryRequests, isEmpty);
      },
    );
    test(
      'missing/malformed list fails while an empty items array is a valid empty state',
      () async {
        for (final response in <JsonMap>[
          {},
          {'items': {}},
          {'items': null},
        ]) {
          h.transport.onGet = (_) async => response;
          await expectLater(
            h.repository.history(
              h.auth.session!,
              h.auth.profile!,
              h.seed(),
              isCurrent: () => true,
            ),
            throwsA(isA<AppFailure>()),
          );
        }
        h.transport.onGet = (_) async => {'items': []};
        expect(
          await h.repository.history(
            h.auth.session!,
            h.auth.profile!,
            h.seed(),
            isCurrent: () => true,
          ),
          isEmpty,
        );
      },
    );
    test(
      'previous data uses only selected source ID and requires status 200 plus a data object',
      () async {
        h.transport.onGet =
            (_) async => {'status': 200, 'data': previousPrescriptionData()};
        final data = await h.repository.previousPrescription(
          h.auth.session!,
          h.auth.profile!,
          h.seed(),
          '600',
          isCurrent: () => true,
        );
        expect(data['rvm_id'], '600');
        expect(
          h.transport.requests.single.uri.pathSegments.last,
          'loadPreviousPrescription',
        );
        expect(h.transport.requests.single.uri.queryParameters, {
          'p_rvm_id': '600',
        });
        for (final response in <JsonMap>[
          {'status': 500, 'message': 'Source unavailable'},
          {'status': 200, 'data': []},
          {},
        ]) {
          h.transport.onGet = (_) async => response;
          await expectLater(
            h.repository.previousPrescription(
              h.auth.session!,
              h.auth.profile!,
              h.seed(),
              '600',
              isCurrent: () => true,
            ),
            throwsA(isA<AppFailure>()),
          );
        }
        final before = h.transport.requests.length;
        await expectLater(
          h.repository.previousPrescription(
            h.auth.session!,
            h.auth.profile!,
            h.seed(),
            ' ',
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
        expect(h.transport.requests.length, before);
        expect(h.transport.binaryRequests, isEmpty);
      },
    );
    test(
      'feature denial and obsolete reads never expose patient history',
      () async {
        final profile = h.auth.profile!;
        final denied = AccountProfile(profile.role, {
          ...profile.values,
          'can_prescribe': '0',
        });
        await expectLater(
          h.repository.history(
            h.auth.session!,
            denied,
            h.seed(),
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
        expect(h.transport.requests, isEmpty);
        var current = true;
        h.transport.onGet = (_) async {
          current = false;
          return {'items': historyRows()};
        };
        await expectLater(
          h.repository.history(
            h.auth.session!,
            profile,
            h.seed(),
            isCurrent: () => current,
          ),
          throwsA(isA<ObsoleteRequest>()),
        );
        current = true;
        h.transport.onGet = (_) async {
          current = false;
          return {'status': 200, 'data': previousPrescriptionData()};
        };
        await expectLater(
          h.repository.previousPrescription(
            h.auth.session!,
            profile,
            h.seed(),
            '600',
            isCurrent: () => current,
          ),
          throwsA(isA<ObsoleteRequest>()),
        );
      },
    );
  });
  test(
    'native row optional labels and legacy empty types never display null or No Data Found',
    () {
      final full = DynamicPrescriptionHistoryItem.fromData({
        ...historyRows()[1],
        'rvm_ad_id': '44',
      });
      expect(full.appointmentText, 'Appointment: 20-SEP-26 • 10:00 AM');
      expect(
        full.createdByText,
        'Created By: Another Clinician • Head of Therapy Department',
      );
      expect(full.typeText, 'Outdoor');
      expect(full.updatedText, 'Last Updated: 20-SEP-26, 03:30 PM');
      expect(full.doctorId, '20');
      expect(full.admissionId, '44');
      final blank = DynamicPrescriptionHistoryItem.fromData({
        'rvm_id': 1,
        'presc_type': ' No Data Found ',
        'pat_type': 'null',
      });
      expect(blank.typeText, isEmpty);
      expect(blank.createdByText, isEmpty);
      expect(blank.appointmentText, isEmpty);
      final partial = DynamicPrescriptionHistoryItem.fromData({
        'sch_time': '10:00 AM',
        'desig_name': 'Therapist',
        'pat_type': 'Walk-in',
      });
      expect(partial.appointmentText, 'Appointment: 10:00 AM');
      expect(partial.createdByText, 'Created By: Therapist');
      expect(partial.typeText, 'Walk-in');
    },
  );
  group('native History replacement', () {
    late DynamicReviewDraftFixture f;
    late DynamicTemplateController t;
    late DynamicHistoryController c;
    Future<JsonMap> Function(String)? loadData;
    Future<List<DynamicPrescriptionHistoryItem>> Function()? loadList;
    var reads = 0, applies = 0, diseaseReads = 0;
    Object? failure;
    setUp(() {
      f = DynamicReviewDraftFixture();
      reads = 0;
      applies = 0;
      diseaseReads = 0;
      failure = null;
      loadData = null;
      loadList = null;
      t = DynamicTemplateController(
        review: f.review,
        loadDiseaseOptions: () async {
          diseaseReads++;
          return diseaseTemplates;
        },
        loadTreatmentOptions: (_) async => treatmentTemplates,
        loadData:
            (kind, _) async =>
                kind == DynamicTemplateKind.disease
                    ? diseaseTemplateData()
                    : treatmentTemplateData(),
      );
      c = DynamicHistoryController(
        review: f.review,
        templates: t,
        loadOptions: () async {
          reads++;
          return loadList == null ? historyItems() : await loadList!();
        },
        loadData: (id) async {
          applies++;
          return loadData == null
              ? previousPrescriptionData(id: id)
              : await loadData!(id);
        },
        onFailure: (value) => failure = value,
      );
    });
    tearDown(() {
      c.dispose();
      t.dispose();
      f.dispose();
    });
    String snapshot() => jsonEncode({
      'clinical': f.clinical.toBody(),
      'vitals': f.clinical.vitals?.values,
      'rx': f.rx.toBody(medicineAllowed: true),
      'advice': f.advice.toBody(),
      'reference': f.advice.reference,
      'notes': f.advice.notes,
      'templates': t.metadata,
      'confirmed': f.review.confirmed,
    });
    Future<void> select() async {
      await c.load();
      c.select(c.items.first);
    }

    test(
      'replaces every section including Vitals/Reference/Notes, clears source templates and resets review',
      () async {
        f.populate();
        t.restore({
          'td_id': '701',
          'td_name': 'Current',
          'tt_id': '801',
          'tt_name': 'Current Rx',
        });
        await select();
        expect(await c.applySelected(), isTrue);
        expect(f.clinical.vitals!['weight'], '66');
        expect(
          f.clinical.entries(DynamicClinicalType.complain).single.text,
          'Template complain',
        );
        expect(f.clinical.objectives.single.notes, 'Template objective notes');
        expect(f.rx.medicines.single.medicine.id, '100');
        expect(f.rx.therapies.single.therapy.id, '200');
        expect(f.advice.reference, 'Previous reference');
        expect(f.advice.notes, 'Previous notes');
        expect(
          f.advice.entries(DynamicAdviceType.followUp).single.masterId,
          '501',
        );
        expect(t.metadata.values, everyElement(isEmpty));
        expect(f.review.confirmed, isFalse);
        expect(applies, 1);
      },
    );
    test(
      'empty source sections clear old content and old vitals rather than merging',
      () async {
        f.populate();
        await select();
        loadData = (id) async => {'rvm_id': id};
        expect(await c.applySelected(), isTrue);
        expect(c.hasData, isFalse);
        expect(f.clinical.vitals, isNull);
        expect(f.advice.reference, isEmpty);
        expect(f.rx.medicines, isEmpty);
      },
    );
    test(
      'malformed late sections or invalid body IDs leave all drafts, templates and confirmation unchanged',
      () async {
        f.populate();
        t.restore({'td_id': '701', 'tt_id': '801'});
        await select();
        for (final malformed in <JsonMap>[
          {...previousPrescriptionData(), 'special_alerts': {}},
          {...previousPrescriptionData(), 'vitals': []},
          {
            ...previousPrescriptionData(),
            'therapies': [
              {'tm_id': 'invalid', 'name': 'Bad ID'},
            ],
          },
          {
            ...previousPrescriptionData(),
            'followups': [
              {'dfi_id': 'invalid', 'text': 'Bad ID'},
            ],
          },
        ]) {
          loadData = (_) async => malformed;
          final before = snapshot();
          expect(await c.applySelected(), isFalse);
          expect(snapshot(), before);
          expect(c.applyError, isNotEmpty);
        }
      },
    );
    test('missing or mismatched source ID cannot replace a draft', () async {
      f.populate();
      await select();
      for (final id in ['', '601']) {
        loadData = (_) async => previousPrescriptionData(id: id);
        final before = snapshot();
        expect(await c.applySelected(), isFalse);
        expect(snapshot(), before);
        expect(failure, isA<AppFailure>());
      }
    });
    test(
      'History reopen always refreshes the list and clears selection without changing a confirmed draft',
      () async {
        f.populate();
        final before = snapshot();
        await select();
        expect(c.countText, '3 prescriptions found');
        c.close();
        await c.load();
        expect(reads, 2);
        expect(c.selected, isNull);
        expect(c.canLoad, isFalse);
        expect(snapshot(), before);
      },
    );
    test(
      'list retry ignores an older response and returns native empty or singular counts',
      () async {
        final old = Completer<List<DynamicPrescriptionHistoryItem>>();
        loadList = () => old.future;
        final first = c.load();
        loadList = () async => [historyItems().first];
        await c.load();
        expect(c.countText, '1 prescription found');
        old.complete(historyItems());
        await first;
        expect(c.countText, '1 prescription found');
        loadList = () async => [];
        await c.load();
        expect(c.countText, isEmpty);
      },
    );
    test(
      'duplicate apply is ignored and closing cancels an in-flight replacement',
      () async {
        f.populate();
        await select();
        final before = snapshot();
        final pending = Completer<JsonMap>();
        loadData = (_) => pending.future;
        final first = c.applySelected();
        expect(c.applying, isTrue);
        expect(await c.applySelected(), isFalse);
        expect(applies, 1);
        c.close();
        pending.complete(previousPrescriptionData());
        expect(await first, isFalse);
        expect(snapshot(), before);
      },
    );
    test(
      'Obsolete reads are silent while list/apply failures report errors and preserve selected content',
      () async {
        f.populate();
        final before = snapshot();
        loadList = () async => throw const AppFailure('History unavailable');
        await c.load();
        expect(c.listError, 'History unavailable');
        loadList = null;
        await select();
        loadData = (_) async => throw const AppFailure('Previous unavailable');
        expect(await c.applySelected(), isFalse);
        expect(c.applyError, 'Previous unavailable');
        expect(c.selected!.rvmId, '600');
        expect(snapshot(), before);
        loadData = (_) async => throw const ObsoleteRequest();
        expect(await c.applySelected(), isFalse);
        expect(c.applyError, isEmpty);
      },
    );
    test(
      'confirmation includes vitals, single advice, template-only data and hidden medicines',
      () {
        expect(c.hasData, isFalse);
        f.clinical.saveVitals(DynamicVitals({'pulse': '72'}));
        expect(c.hasData, isTrue);
        f.clinical.replaceFromData({});
        f.advice.saveEntry(
          DynamicAdviceType.notes,
          DynamicAdviceEntry(text: 'Notes only'),
        );
        expect(c.hasData, isTrue);
        f.advice.replaceFromData({});
        t.restore({'td_id': '701'});
        expect(c.hasData, isTrue);
        t.restore({});
        f.populate();
        f.review.medicineAllowed = false;
        expect(c.hasData, isTrue);
      },
    );
    test(
      'history clears Treatment cache while retaining the native Disease catalogue',
      () async {
        await t.loadDiseases();
        await t.apply(DynamicTemplateKind.disease, diseaseTemplates.first);
        await t.loadTreatments();
        await select();
        expect(await c.applySelected(), isTrue);
        expect(t.treatments, isEmpty);
        await t.loadDiseases();
        expect(diseaseReads, 1);
        expect(t.diseaseId, isEmpty);
      },
    );
    test('closing during list read discards late patient data', () async {
      final pending = Completer<List<DynamicPrescriptionHistoryItem>>();
      loadList = () => pending.future;
      final read = c.load();
      c.close();
      pending.complete(historyItems());
      await read;
      expect(c.items, isEmpty);
      expect(c.selected, isNull);
      expect(c.loading, isFalse);
    });
  });
}

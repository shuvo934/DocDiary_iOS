import 'dart:async';
import 'dart:convert';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_advice_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_clinical_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_template_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dynamic_review_test_support.dart';
import 'dynamic_template_test_support.dart';

void main() {
  group('native template GET contracts', () {
    late DynamicReviewHarness h;
    setUp(() async {
      h = DynamicReviewHarness();
      await h.signIn();
      h.transport.requests.clear();
    });
    tearDown(() => h.auth.dispose());
    test(
      'lists use exact native IDs/description keys, skip invalid rows and preserve source order',
      () async {
        h.transport.onGet =
            (uri) async => {
              'items': [
                null,
                {
                  'td_id': 701,
                  'td_name': 'Disease',
                  'td_description': 'Description',
                },
                {'td_id': '', 'td_name': 'Invalid'},
                {'td_id': 702, 'td_name': 'null'},
                {'td_id': 701, 'td_name': 'Second occurrence'},
              ],
            };
        final repo = h.repository.templates;
        final values = await repo.options(
          h.auth.session!,
          h.auth.profile!,
          isCurrent: () => true,
        );
        expect(values.map((v) => v.name), ['Disease', 'Second occurrence']);
        expect(values.first.description, 'Description');
        expect(
          h.transport.requests.single.uri.pathSegments.last,
          'getDiseaseTemplate',
        );
        expect(h.transport.requests.single.uri.queryParameters, {
          'p_doc_id': '10',
        });
        h.transport.onGet =
            (_) async => {
              'items': [
                {
                  'tt_id': '801',
                  'tt_name': 'Treatment',
                  'tt_description': 'Details',
                },
              ],
            };
        final treatments = await repo.options(
          h.auth.session!,
          h.auth.profile!,
          diseaseId: '701',
          isCurrent: () => true,
        );
        expect(treatments.single.id, '801');
        expect(h.transport.requests.last.uri.queryParameters, {
          'p_doc_id': '10',
          'p_td_id': '701',
        });
        expect(h.posts, isEmpty);
        expect(h.transport.binaryRequests, isEmpty);
      },
    );
    test(
      'missing list and malformed data do not masquerade as empty success',
      () async {
        final repo = h.repository.templates;
        h.transport.onGet = (_) async => {};
        await expectLater(
          repo.options(h.auth.session!, h.auth.profile!, isCurrent: () => true),
          throwsA(isA<AppFailure>()),
        );
        h.transport.onGet = (_) async => {'status': 200, 'data': []};
        await expectLater(
          repo.data(
            h.auth.session!,
            h.auth.profile!,
            DynamicTemplateKind.disease,
            '701',
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
        h.transport.onGet =
            (_) async => {
              'status': 500,
              'data': {},
              'message': 'Template unavailable',
            };
        await expectLater(
          repo.data(
            h.auth.session!,
            h.auth.profile!,
            DynamicTemplateKind.disease,
            '701',
            isCurrent: () => true,
          ),
          throwsA(
            isA<AppFailure>().having(
              (f) => f.message,
              'message',
              'Template unavailable',
            ),
          ),
        );
      },
    );
    test(
      'data endpoints require native status 200 and object; stale replies are ignored',
      () async {
        h.transport.onGet =
            (_) async => {'status': 200, 'data': diseaseTemplateData()};
        await h.repository.templates.data(
          h.auth.session!,
          h.auth.profile!,
          DynamicTemplateKind.disease,
          '701',
          isCurrent: () => true,
        );
        expect(
          h.transport.requests.last.uri.pathSegments.last,
          'loadDiseaseTemplate',
        );
        expect(h.transport.requests.last.uri.queryParameters, {
          'p_td_id': '701',
        });
        await h.repository.templates.data(
          h.auth.session!,
          h.auth.profile!,
          DynamicTemplateKind.treatment,
          '801',
          isCurrent: () => true,
        );
        expect(
          h.transport.requests.last.uri.pathSegments.last,
          'loadTreatmentTemplate',
        );
        expect(h.transport.requests.last.uri.queryParameters, {
          'p_tt_id': '801',
        });
        var current = true;
        h.transport.onGet = (_) async {
          current = false;
          return {'status': 200, 'data': {}};
        };
        await expectLater(
          h.repository.templates.data(
            h.auth.session!,
            h.auth.profile!,
            DynamicTemplateKind.disease,
            '701',
            isCurrent: () => current,
          ),
          throwsA(isA<ObsoleteRequest>()),
        );
      },
    );
  });

  group('builder-owned template rules', () {
    late DynamicReviewDraftFixture f;
    late DynamicTemplateController c;
    var diseaseReads = 0, treatmentReads = 0;
    Future<JsonMap> Function(DynamicTemplateKind, String)? data;
    setUp(() {
      f = DynamicReviewDraftFixture();
      diseaseReads = 0;
      treatmentReads = 0;
      data = null;
      c = DynamicTemplateController(
        review: f.review,
        loadDiseaseOptions: () async {
          diseaseReads++;
          return diseaseTemplates;
        },
        loadTreatmentOptions: (id) async {
          treatmentReads++;
          return treatmentTemplates;
        },
        loadData: (kind, id) async {
          final loader = data;
          if (loader != null) return await loader(kind, id);
          return kind == DynamicTemplateKind.disease
              ? diseaseTemplateData()
              : treatmentTemplateData();
        },
      );
    });
    tearDown(() {
      c.dispose();
      f.dispose();
    });
    String snapshot() => jsonEncode({
      'clinical': f.clinical.toBody(),
      'vitals': f.clinical.vitals?.values,
      'rx': f.rx.toBody(medicineAllowed: true),
      'advice': f.advice.toBody(),
      'reference': f.advice.reference,
      'notes': f.advice.notes,
      'metadata': c.metadata,
    });
    test(
      'native search covers name and description, trims and ignores case',
      () {
        expect(
          diseaseTemplates.where((item) => item.matches('  UPPER  ')).single.id,
          '701',
        );
        expect(
          diseaseTemplates.where((item) => item.matches('PHYSIO')).single.id,
          '702',
        );
        expect(
          diseaseTemplates.where((item) => item.matches('No match')),
          isEmpty,
        );
      },
    );
    test(
      'Disease replaces Clinical/Objective/Advice, clears Rx, preserves Vitals/Reference/Notes, and resets Treatment/confirmation',
      () async {
        f.populate();
        c.restore({
          'td_id': '700',
          'td_name': 'Old disease',
          'tt_id': '800',
          'tt_name': 'Old treatment',
        });
        final vitals = f.clinical.vitals,
            reference = f.advice.entries(DynamicAdviceType.reference).single;
        data =
            (_, _) async => {
              ...diseaseTemplateData(),
              'vitals': false,
              'reference': ['ignore'],
              'notes': {'ignore': true},
              'medications': 'not read from disease',
            };
        expect(
          await c.apply(DynamicTemplateKind.disease, diseaseTemplates.first),
          isTrue,
        );
        expect(
          f.clinical.entries(DynamicClinicalType.complain).single.text,
          'Template complain',
        );
        expect(f.clinical.objectives.single.notes, 'Template objective notes');
        expect(
          f.advice.entries(DynamicAdviceType.advice).single.text,
          'Template advice',
        );
        expect(f.clinical.vitals, same(vitals));
        expect(
          f.advice.entries(DynamicAdviceType.reference).single,
          same(reference),
        );
        expect(f.advice.notes, 'Notes line 1\nline 2');
        expect(f.rx.medicines, isEmpty);
        expect(f.rx.therapies, isEmpty);
        expect(f.rx.treatmentPlans, isEmpty);
        expect(c.diseaseId, '701');
        expect(c.treatmentId, isEmpty);
        expect(f.review.confirmed, isFalse);
        expect(treatmentReads, 1);
      },
    );
    test(
      'Treatment replaces Rx only and preserves Clinical/Advice/template parent',
      () async {
        f.populate();
        c.restore({'td_id': '701', 'td_name': 'Disease'});
        final beforeClinical = jsonEncode(f.clinical.toBody()),
            beforeAdvice = jsonEncode(f.advice.toBody()),
            vitals = f.clinical.vitals;
        data =
            (_, _) async => {
              ...treatmentTemplateData(),
              'complaints': 'ignored',
              'reference': false,
            };
        expect(
          await c.apply(
            DynamicTemplateKind.treatment,
            treatmentTemplates.first,
          ),
          isTrue,
        );
        expect(f.rx.medicines.single.duration, isEmpty);
        expect(f.rx.treatmentPlans.single.text, 'Template treatment plan');
        expect(jsonEncode(f.clinical.toBody()), beforeClinical);
        expect(jsonEncode(f.advice.toBody()), beforeAdvice);
        expect(f.clinical.vitals, same(vitals));
        expect(c.diseaseId, '701');
        expect(c.treatmentId, '801');
        expect(f.review.confirmed, isFalse);
      },
    );
    for (final kind in DynamicTemplateKind.values) {
      test(
        'malformed ${kind.label} leaves every draft, metadata and confirmation intact',
        () async {
          f.populate();
          c.restore({
            'td_id': '701',
            'td_name': 'Disease',
            'tt_id': '800',
            'tt_name': 'Existing treatment',
          });
          final before = snapshot();
          data =
              (_, _) async =>
                  kind == DynamicTemplateKind.disease
                      ? {...diseaseTemplateData(), 'special_alerts': false}
                      : {
                        ...treatmentTemplateData(),
                        'treatment_plans': [
                          {'tpm_id': 'bad-id', 'name': 'Invalid identifier'},
                        ],
                      };
          expect(
            await c.apply(
              kind,
              kind == DynamicTemplateKind.disease
                  ? diseaseTemplates.last
                  : treatmentTemplates.first,
            ),
            isFalse,
          );
          expect(snapshot(), before);
          expect(f.review.confirmed, isTrue);
          expect(
            kind == DynamicTemplateKind.disease
                ? c.diseaseApplyError
                : c.treatmentApplyError,
            isTrue,
          );
        },
      );
    }
    test(
      'empty successful Disease data clears replaceable sections but retains the three protected values',
      () async {
        f.populate();
        data = (_, _) async => {};
        expect(
          await c.apply(DynamicTemplateKind.disease, diseaseTemplates.first),
          isTrue,
        );
        expect(c.hasDiseaseData, isFalse);
        expect(f.clinical.vitals, isNotNull);
        expect(f.advice.reference, isNotEmpty);
        expect(f.advice.notes, isNotEmpty);
        expect(f.clinical.objectives, isEmpty);
      },
    );
    test(
      'lists cache per builder and Treatment reloads when Disease changes',
      () async {
        await c.loadDiseases();
        await c.loadDiseases();
        expect(diseaseReads, 1);
        await c.apply(DynamicTemplateKind.disease, diseaseTemplates.first);
        await c.loadTreatments();
        expect(treatmentReads, 1);
        await c.apply(DynamicTemplateKind.disease, diseaseTemplates.last);
        await c.loadTreatments();
        expect(treatmentReads, 2);
      },
    );
    test(
      'cancel/background invalidates pending apply without altering local data',
      () async {
        f.populate();
        final pending = Completer<JsonMap>();
        data = (_, _) => pending.future;
        final before = snapshot(),
            operation = c.apply(
              DynamicTemplateKind.disease,
              diseaseTemplates.first,
            );
        expect(c.applying, isTrue);
        c.cancelPending();
        pending.complete(diseaseTemplateData());
        expect(await operation, isFalse);
        expect(snapshot(), before);
        expect(f.review.confirmed, isTrue);
      },
    );
    test(
      'late Treatment list for earlier Disease cannot replace current options',
      () async {
        final pending = Completer<List<DynamicTemplateOption>>();
        c.dispose();
        c = DynamicTemplateController(
          review: f.review,
          loadDiseaseOptions: () async => diseaseTemplates,
          loadTreatmentOptions:
              (id) =>
                  id == '701'
                      ? pending.future
                      : Future.value([
                        const DynamicTemplateOption(
                          '900',
                          'New disease treatment',
                        ),
                      ]),
          loadData: (_, _) async => diseaseTemplateData(),
        );
        await c.apply(DynamicTemplateKind.disease, diseaseTemplates.first);
        await c.apply(DynamicTemplateKind.disease, diseaseTemplates.last);
        await c.loadTreatments();
        pending.complete(treatmentTemplates);
        await Future<void>.delayed(Duration.zero);
        expect(c.treatments.single.id, '900');
      },
    );
    test(
      'protected values alone need no Disease replacement confirmation; hidden medicine still does',
      () {
        f.clinical.saveVitals(DynamicVitals({'pulse': '72'}));
        f.advice.saveEntry(
          DynamicAdviceType.notes,
          DynamicAdviceEntry(text: 'Kept notes'),
        );
        expect(c.hasDiseaseData, isFalse);
        f.populate();
        f.review.medicineAllowed = false;
        expect(c.hasDiseaseData, isTrue);
        expect(c.hasRxData, isTrue);
      },
    );
    test(
      'missing Disease or missing option ID never starts an apply request',
      () async {
        var reads = 0;
        data = (_, _) async {
          reads++;
          return {};
        };
        expect(
          await c.apply(
            DynamicTemplateKind.treatment,
            treatmentTemplates.first,
          ),
          isFalse,
        );
        expect(
          await c.apply(
            DynamicTemplateKind.disease,
            const DynamicTemplateOption('', 'Missing'),
          ),
          isFalse,
        );
        expect(reads, 0);
      },
    );
  });
}

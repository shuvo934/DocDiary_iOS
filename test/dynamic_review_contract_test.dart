import 'dart:async';
import 'dart:convert';

import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_advice_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_clinical_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_review_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_save_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_rx_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dynamic_review_test_support.dart';
import 'dynamic_rx_test_support.dart';

void main() {
  group('native Review rules', () {
    late DynamicReviewDraftFixture f;
    setUp(() => f = DynamicReviewDraftFixture());
    tearDown(() => f.dispose());
    test(
      'badges count populated categories, preserve native order and display Added for singles',
      () {
        f.populate();
        expect(f.review.clinicalRows.map((row) => row.label), [
          'Vitals',
          'Complain',
          'Objective Info',
          'Important Info',
        ]);
        expect(f.review.rxRows.map((row) => row.label), [
          'Medicine',
          'Therapy',
          'Treatment Plan',
        ]);
        expect(f.review.adviceRows.map((row) => row.value), [
          '1',
          '1',
          '1',
          'Added',
          'Added',
        ]);
        f.rx.saveMedicine(rxMedicine(id: '101', name: 'Another medicine'));
        expect(f.review.rxRows.first.value, '2');
        expect(f.review.rxRows, hasLength(3));
        expect(DynamicPrescriptionReview.badge(0), '0 item');
        expect(DynamicPrescriptionReview.badge(1), '1 item');
        expect(DynamicPrescriptionReview.badge(3), '3 items');
      },
    );
    test(
      'Medicine permission controls eligibility while Therapy or a Treatment Plan can independently qualify',
      () {
        f.review.confirm(true);
        expect(f.review.confirmed, isFalse);
        final medicine = rxMedicine();
        f.rx.saveMedicine(medicine);
        f.review.confirm(true);
        expect(f.review.canGenerate, isTrue);
        f.review.medicineAllowed = false;
        expect(f.review.hasRx, isFalse);
        expect(f.review.confirmed, isFalse);
        expect(f.rx.medicines, hasLength(1));
        expect(f.review.rxRows, isEmpty);
        final plan = DynamicTreatmentPlanEntry(text: 'Plan only');
        f.rx.saveTreatmentPlan(plan);
        expect(f.review.hasRx, isTrue);
        f.rx.deleteTreatmentPlan(plan.localId);
        f.rx.saveTherapy(
          DynamicTherapyEntry(therapy: const DynamicRxOption('200', 'Therapy')),
        );
        expect(f.review.hasRx, isTrue);
      },
    );
    test(
      'every draft mutation resets confirmation; reading summaries does not reset it',
      () {
        f.populate();
        expect(f.review.confirmed, isTrue);
        expect(f.review.clinicalRows, isNotEmpty);
        expect(f.review.confirmed, isTrue);
        f.advice.saveEntry(
          DynamicAdviceType.notes,
          DynamicAdviceEntry(
            localId: f.advice.entries(DynamicAdviceType.notes).single.localId,
            text: 'Updated notes',
          ),
          updating: true,
        );
        expect(f.review.confirmed, isFalse);
        f.review.confirm(true);
        f.clinical.saveVitals(DynamicVitals({'pulse': '75'}));
        expect(f.review.confirmed, isFalse);
        f.review.confirm(true);
        f.rx.deleteMedicine(f.rx.medicines.single.localId);
        expect(f.review.confirmed, isFalse);
        f.review.confirm(true);
        f.clinical.deleteObjective(f.clinical.objectives.single.localId);
        expect(f.review.confirmed, isFalse);
      },
    );
    test(
      'incomplete Objective names are unique; value ID+name OR notes satisfies native validation',
      () {
        final a = DynamicObjectiveEntry(
          objective: const DynamicRxOption('10', 'ROM'),
          muscleJoint: const DynamicRxOption('30', 'Knee'),
        );
        final b = DynamicObjectiveEntry(
          objective: const DynamicRxOption('10', 'ROM'),
          muscleJoint: const DynamicRxOption('31', 'Shoulder'),
        );
        f.clinical.saveObjective(a);
        f.clinical.saveObjective(b);
        expect(f.review.incompleteObjectives, ['ROM']);
        f.clinical.saveObjective(
          DynamicObjectiveEntry(
            localId: a.localId,
            objective: a.objective,
            muscleJoint: a.muscleJoint,
            notes: 'Notes only',
          ),
          updating: true,
        );
        expect(f.review.incompleteObjectives, ['ROM']);
        f.clinical.saveObjective(
          DynamicObjectiveEntry(
            localId: b.localId,
            objective: b.objective,
            muscleJoint: b.muscleJoint,
            value: const DynamicRxOption('11', 'Flexion'),
          ),
          updating: true,
        );
        expect(f.review.incompleteObjectives, isEmpty);
      },
    );
  });

  group('native JSON save contracts', () {
    late DynamicReviewHarness h;
    late DynamicReviewDraftFixture f;
    setUp(() async {
      h = DynamicReviewHarness();
      await h.signIn();
      h.transport.requests.clear();
      h.transport.binaryRequests.clear();
      f = DynamicReviewDraftFixture()..populate();
    });
    tearDown(() {
      f.dispose();
      h.auth.dispose();
    });
    DynamicPrescriptionSaveRequest request({bool existing = false}) =>
        DynamicPrescriptionSaveRequest.capture(
          seed: h.seed(existing: existing),
          profile: h.auth.profile!,
          review: f.review,
          data: {if (existing) 'rvm_id': '900', 'td_id': 701, 'tt_id': 702},
        );
    test(
      'create sends exact native twenty headers, all fourteen arrays and UTF-8 JSON',
      () async {
        h.transport.onBytes = (_) async => dynamicSavedResponse();
        final req = request();
        final receipt = await h.repository.save(
          h.auth.session!,
          h.auth.profile!,
          h.seed(),
          req,
          isCurrent: () => true,
        );
        final sent = h.transport.binaryRequests.single;
        expect(sent.uri.path, '/api/dynamic_presc/insertPrescription');
        expect(sent.uri.queryParameters, isEmpty);
        expect(sent.contentType, 'application/json; charset=utf-8');
        expect(sent.headers, {
          'P_DOC_ID': '10',
          'P_PH_ID': '11',
          'P_PAT_ID': '21',
          'P_AD_ID': '41',
          'P_REFERENCE': 'Ref line 1  line 2',
          'P_NOTES': 'Notes line 1 line 2',
          'P_TD_ID': '701',
          'P_TT_ID': '702',
          'P_PRESCRIPTION_TYPE': '1',
          'P_INSERT_TYPE': '4',
          'P_PATIENT_TYPE': '1',
          'P_WEIGHT': '70',
          'P_HEIGHT': '175',
          'P_SYSTOLIC': '120',
          'P_DIASTOLIC': '80',
          'P_PULSE': '72',
          'P_RESPIRATION': '16',
          'P_TEMPERATURE': '98.6',
          'P_SPO': '98',
          'P_BMI': '22.9',
        });
        final body = nativeObject(utf8.decode(sent.body));
        expect(body.keys.toSet(), {
          'complaints',
          'injuries',
          'diagnosis',
          'clinical_findings',
          'drug_history',
          'investigations',
          'important_info',
          'objective_info',
          'medications',
          'therapies',
          'treatment_plans',
          'advice',
          'followups',
          'special_alerts',
        });
        expect(body['complaints'], [
          {'cm_id': 1, 'name': 'নমুনা অভিযোগ'},
        ]);
        expect(body['objective_info'], [
          {'om_id': 10, 'od_id': 11, 'mjl_id': 30, 'notes': 'Objective notes'},
        ]);
        expect(body['medications'], [
          {
            'medication_id': 100,
            'dose_id': 2,
            'timing_id': 2,
            'route_id': 11,
            'duration': '7',
            'notes': 'ওষুধের নোট',
          },
        ]);
        expect(body['advice'], [
          {'text': 'পরামর্শ'},
        ]);
        expect(body['injuries'], isEmpty);
        expect(body.containsKey('vitals'), isFalse);
        expect(body.containsKey('notes'), isFalse);
        expect(receipt.rvmId, '901');
        expect(receipt.code, '2600901');
        expect(receipt.updating, isFalse);
        expect(h.transport.requests.where((r) => r.method == 'POST'), isEmpty);
      },
    );
    test(
      'update adds RVM_ID and excludes create-only patient/prescription types',
      () async {
        h.transport.onBytes =
            (_) async => {'string_out': 'Prescription updated successfully.'};
        final receipt = await h.repository.save(
          h.auth.session!,
          h.auth.profile!,
          h.seed(existing: true),
          request(existing: true),
          isCurrent: () => true,
        );
        final sent = h.transport.binaryRequests.single;
        expect(sent.uri.pathSegments.last, 'updatePrescription');
        expect(sent.headers['P_RVM_ID'], '900');
        expect(sent.headers['P_INSERT_TYPE'], '4');
        expect(sent.headers, hasLength(19));
        expect(sent.headers.containsKey('P_PATIENT_TYPE'), isFalse);
        expect(sent.headers.containsKey('P_PRESCRIPTION_TYPE'), isFalse);
        expect(receipt.rvmId, '900');
        expect(receipt.updating, isTrue);
      },
    );
    test(
      'captured request is immutable even if the draft changes before dispatch',
      () {
        final req = request(), before = req.bodyJson;
        f.rx.deleteMedicine(f.rx.medicines.single.localId);
        f.advice.deleteEntry(
          DynamicAdviceType.notes,
          f.advice.entries(DynamicAdviceType.notes).single.localId,
        );
        expect(req.bodyJson, before);
        expect(req.headers['P_NOTES'], 'Notes line 1 line 2');
        expect(() => req.headers.clear(), throwsUnsupportedError);
        final bytes = req.body;
        bytes[0] = 0;
        expect(utf8.decode(req.body), before);
      },
    );
    test(
      'lack of confirmation, invalid Objective or missing existing ID cannot prepare a request',
      () {
        f.review.reset();
        expect(() => request(), throwsA(isA<AppFailure>()));
        f.review.confirm(true);
        f.clinical.saveObjective(
          DynamicObjectiveEntry(
            objective: const DynamicRxOption('20', 'Strength'),
          ),
        );
        f.review.confirm(true);
        expect(() => request(), throwsA(isA<AppFailure>()));
        f.clinical.deleteObjective(f.clinical.objectives.last.localId);
        f.review.confirm(true);
        expect(
          () => DynamicPrescriptionSaveRequest.capture(
            seed: h.seed(existing: true),
            profile: h.auth.profile!,
            review: f.review,
          ),
          throwsA(isA<AppFailure>()),
        );
        expect(h.transport.binaryRequests, isEmpty);
      },
    );
    test(
      'blank native message has a fallback only with a complete save result; empty JSON is never success',
      () {
        expect(
          DynamicPrescriptionSaveReceipt.fromResponse({
            'string_out': '',
            'out_rvm_id': 901,
          }, request()).message,
          'Prescription created successfully.',
        );
        expect(
          () => DynamicPrescriptionSaveReceipt.fromResponse({}, request()),
          throwsA(isA<AppFailure>()),
        );
        expect(
          () => DynamicPrescriptionSaveReceipt.fromResponse(
            {},
            request(existing: true),
          ),
          throwsA(isA<AppFailure>()),
        );
        expect(
          () => DynamicPrescriptionSaveReceipt.fromResponse({
            'string_out': 'Created',
          }, request()),
          throwsA(isA<AppFailure>()),
        );
        expect(
          () => DynamicPrescriptionSaveReceipt.fromResponse({
            'status': 500,
            'string_out': 'ORA-20001: failed',
          }, request(existing: true)),
          throwsA(isA<AppFailure>()),
        );
      },
    );
    test(
      'single in-flight write and zero automatic retry prevent duplicate dispatch',
      () async {
        final pending = Completer<JsonMap>();
        h.transport.onBytes = (_) => pending.future;
        final req = request();
        final saving = h.repository.save(
          h.auth.session!,
          h.auth.profile!,
          h.seed(),
          req,
          isCurrent: () => true,
        );
        expect(h.repository.writing, isTrue);
        await expectLater(
          h.repository.save(
            h.auth.session!,
            h.auth.profile!,
            h.seed(),
            req,
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
        expect(h.transport.binaryRequests, hasLength(1));
        pending.completeError(
          const AppFailure('Connection interrupted', kind: FailureKind.network),
        );
        await expectLater(
          saving,
          throwsA(isA<DynamicPrescriptionSaveFailure>()),
        );
        expect(h.transport.binaryRequests, hasLength(1));
        expect(h.repository.writing, isFalse);
      },
    );
    test(
      'stale before dispatch sends nothing and stale completion cannot publish a receipt',
      () async {
        final req = request();
        await expectLater(
          h.repository.save(
            h.auth.session!,
            h.auth.profile!,
            h.seed(),
            req,
            isCurrent: () => false,
          ),
          throwsA(isA<ObsoleteRequest>()),
        );
        expect(h.transport.binaryRequests, isEmpty);
        var current = true;
        final pending = Completer<JsonMap>();
        h.transport.onBytes = (_) => pending.future;
        final saving = h.repository.save(
          h.auth.session!,
          h.auth.profile!,
          h.seed(),
          req,
          isCurrent: () => current,
        );
        current = false;
        pending.complete(dynamicSavedResponse());
        await expectLater(saving, throwsA(isA<ObsoleteRequest>()));
        expect(h.repository.writing, isFalse);
      },
    );
    test(
      'disabled account or changed patient target cannot dispatch the captured write',
      () async {
        final req = request();
        final denied = AccountProfile(AccountRole.doctor, {
          ...h.doctorData,
          'can_prescribe': '0',
        });
        await expectLater(
          h.repository.save(
            h.auth.session!,
            denied,
            h.seed(),
            req,
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
        final other = h.seed();
        final changedProfile = AccountProfile(AccountRole.doctor, {
          ...h.doctorData,
          'doc_id': '99',
        });
        await expectLater(
          h.repository.save(
            h.auth.session!,
            changedProfile,
            other,
            req,
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
        expect(h.transport.binaryRequests, isEmpty);
      },
    );
    test(
      'Unicode stays valid in JSON; unsupported raw header text is refused before any POST',
      () async {
        for (final type in [
          DynamicAdviceType.reference,
          DynamicAdviceType.notes,
        ]) {
          final entry = f.advice.entries(type).single;
          for (final text in ['বাংলা নোট', 'Mixed বাংলা text', 'Notes 📝']) {
            f.advice.saveEntry(
              type,
              DynamicAdviceEntry(localId: entry.localId, text: text),
              updating: true,
            );
            f.review.confirm(true);
            await expectLater(
              h.repository.save(
                h.auth.session!,
                h.auth.profile!,
                h.seed(),
                request(),
                isCurrent: () => true,
              ),
              throwsA(
                isA<AppFailure>().having(
                  (failure) => failure.message,
                  'clear language message',
                  allOf(
                    contains('do not support Bangla'),
                    contains('Your draft is kept'),
                  ),
                ),
              ),
            );
            expect(f.advice.entries(type).single.text, text);
            expect(h.transport.binaryRequests, isEmpty);
            expect(h.repository.writing, isFalse);
          }
          f.advice.saveEntry(
            type,
            DynamicAdviceEntry(localId: entry.localId, text: 'English text'),
            updating: true,
          );
        }
      },
    );
    test(
      'lookup after an unconfirmed create uses the scheduled identities even for a new seed',
      () async {
        h.transport.onGet =
            (_) async => {
              'status': 200,
              'data': {'rvm_id': 901, 'rvm_code': '2600901'},
            };
        final data = await h.repository.lookup(
          h.auth.session!,
          h.auth.profile!,
          h.seed(),
          isCurrent: () => true,
        );
        expect(data['rvm_id'], 901);
        expect(h.transport.requests.single.uri.queryParameters, {
          'p_ph_id': '11',
          'p_pat_id': '21',
          'p_ad_id': '41',
        });
        expect(h.transport.binaryRequests, isEmpty);
      },
    );
  });
}

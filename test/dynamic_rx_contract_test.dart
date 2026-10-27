import 'dart:async';
import 'dart:convert';

import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_clinical_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_rx_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_rx_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dynamic_clinical_test_support.dart';
import 'dynamic_rx_test_support.dart';

void main() {
  test(
    'durationRequired defaults false; true changes blank validation without changing positive integer rules',
    () {
      expect(DynamicMedicineEntry.durationError(''), isNull);
      expect(
        DynamicMedicineEntry.durationError(' ', durationRequired: true),
        'Enter duration in days',
      );
      expect(
        DynamicMedicineEntry.durationError('7', durationRequired: true),
        isNull,
      );
      expect(
        DynamicMedicineEntry.durationError('0', durationRequired: true),
        'Duration must be greater than 0',
      );
      expect(
        DynamicMedicineEntry.durationError('1.5', durationRequired: true),
        'Enter a valid positive duration',
      );
      expect(
        DynamicMedicineEntry.durationError(
          '2147483648',
          durationRequired: true,
        ),
        'Enter a valid positive duration',
      );
    },
  );
  test(
    'Rx body uses the native three arrays, numeric IDs and no display-only fields',
    () {
      final draft = DynamicRxDraft()..replaceFromData(rxExistingData());
      addTearDown(draft.dispose);
      expect(draft.toBody(medicineAllowed: true), {
        'medications': [
          {
            'medication_id': 100,
            'dose_id': 2,
            'timing_id': 2,
            'route_id': 11,
            'duration': '7',
            'notes': 'Saved notes',
          },
        ],
        'therapies': [
          {'tm_id': 200, 'notes': 'থেরাপির নোট'},
        ],
        'treatment_plans': [
          {'tpm_id': 300, 'name': 'Continue treatment with edited text'},
          {'tpm_id': null, 'name': 'Custom plan'},
        ],
      });
      expect(draft.toBody(medicineAllowed: false)['medications'], isEmpty);
      expect(
        draft.medicines,
        hasLength(1),
        reason: 'Permission masking must not silently delete a loaded draft.',
      );
    },
  );
  test(
    'Rx parsing accepts native encoded arrays and skips native incomplete rows',
    () {
      final data = rxExistingData();
      data['medications'] = jsonEncode([
        ...(data['medications']! as List<Object?>),
        {'medication_id': 4, 'medicine_name': 'Missing route/dose'},
      ]);
      data['therapies'] = jsonEncode([
        ...(data['therapies']! as List<Object?>),
        {'name': 'Missing id'},
      ]);
      data['treatment_plans'] = jsonEncode([
        ...(data['treatment_plans']! as List<Object?>),
        {'tpm_id': 6, 'name': ''},
      ]);
      final draft = DynamicRxDraft()..replaceFromData(data);
      addTearDown(draft.dispose);
      expect(draft.medicines, hasLength(1));
      expect(draft.therapies, hasLength(1));
      expect(draft.treatmentPlans, hasLength(2));
      final ids = [
        ...draft.medicines.map((e) => e.localId),
        ...draft.therapies.map((e) => e.localId),
        ...draft.treatmentPlans.map((e) => e.localId),
      ];
      expect(ids.toSet(), hasLength(4));
      for (final id in ids) {
        expect(
          id,
          matches(
            RegExp(
              r'^[\da-f]{8}-[\da-f]{4}-4[\da-f]{3}-[89ab][\da-f]{3}-[\da-f]{12}$',
            ),
          ),
        );
      }
    },
  );
  test('malformed late Rx array leaves all existing draft lists intact', () {
    final draft = DynamicRxDraft()..replaceFromData(rxExistingData());
    addTearDown(draft.dispose);
    final before = jsonEncode(draft.toBody(medicineAllowed: true)),
        revision = draft.revision;
    expect(
      () => draft.replaceFromData({
        'medications': [],
        'therapies': [],
        'treatment_plans': 'invalid JSON',
      }),
      throwsA(isA<AppFailure>()),
    );
    expect(jsonEncode(draft.toBody(medicineAllowed: true)), before);
    expect(draft.revision, revision);
    expect(() => draft.medicines.clear(), throwsUnsupportedError);
    expect(() => rxCatalogue().therapies.clear(), throwsUnsupportedError);
  });
  test(
    'medicine CRUD excludes its own row, rejects missing edits and compares native IDs',
    () {
      final draft = DynamicRxDraft();
      addTearDown(draft.dispose);
      final a = rxMedicine(localId: 'a'),
          b = rxMedicine(localId: 'b', id: '101', name: 'Sample medicine');
      expect(draft.saveMedicine(a), isTrue);
      expect(
        draft.saveMedicine(
          rxMedicine(localId: 'duplicate', name: 'Changed name'),
        ),
        isFalse,
      );
      expect(
        draft.saveMedicine(b),
        isTrue,
        reason: 'Native IDs differ even when names are the same.',
      );
      expect(
        draft.saveMedicine(
          rxMedicine(localId: 'a', duration: '9'),
          updating: true,
        ),
        isTrue,
      );
      expect(draft.medicines.first.duration, '9');
      expect(
        draft.saveMedicine(rxMedicine(localId: 'missing'), updating: true),
        isFalse,
      );
      expect(draft.saveMedicine(rxMedicine(localId: 'a')), isFalse);
      final revision = draft.revision;
      draft.deleteMedicine('missing');
      expect(draft.revision, revision);
      draft.deleteMedicine('b');
      expect(draft.medicines.single.localId, 'a');
    },
  );
  test('therapy CRUD uses ID first, then case-insensitive name fallback', () {
    final draft = DynamicRxDraft();
    addTearDown(draft.dispose);
    DynamicTherapyEntry entry(String local, String id, String name) =>
        DynamicTherapyEntry(localId: local, therapy: DynamicRxOption(id, name));
    expect(draft.saveTherapy(entry('a', '200', 'Therapy')), isTrue);
    expect(draft.saveTherapy(entry('b', '200', 'Different')), isFalse);
    expect(draft.saveTherapy(entry('b', '201', 'Therapy')), isTrue);
    expect(draft.saveTherapy(entry('c', '', 'THERAPY')), isFalse);
    expect(
      draft.saveTherapy(
        DynamicTherapyEntry(
          localId: 'a',
          therapy: const DynamicRxOption('200', 'Updated'),
          notes: 'updated',
        ),
        updating: true,
      ),
      isTrue,
    );
    expect(draft.therapies.first.notes, 'updated');
    expect(
      draft.saveTherapy(entry('missing', '202', 'New'), updating: true),
      isFalse,
    );
    draft.deleteTherapy('a');
    expect(draft.therapies.single.localId, 'b');
  });
  test(
    'treatment plan duplicate is either matching master ID or matching final text',
    () {
      final draft = DynamicRxDraft();
      addTearDown(draft.dispose);
      expect(
        draft.saveTreatmentPlan(
          DynamicTreatmentPlanEntry(
            localId: 'a',
            masterId: '300',
            text: 'Edited plan',
          ),
        ),
        isTrue,
      );
      expect(
        draft.saveTreatmentPlan(
          DynamicTreatmentPlanEntry(masterId: '300', text: 'Other text'),
        ),
        isFalse,
      );
      expect(
        draft.saveTreatmentPlan(
          DynamicTreatmentPlanEntry(masterId: '301', text: 'EDITED PLAN'),
        ),
        isFalse,
      );
      expect(
        draft.saveTreatmentPlan(
          DynamicTreatmentPlanEntry(
            localId: 'a',
            masterId: '300',
            text: 'Updated',
          ),
          updating: true,
        ),
        isTrue,
      );
      expect(
        draft.saveTreatmentPlan(
          DynamicTreatmentPlanEntry(localId: 'missing', text: 'New'),
          updating: true,
        ),
        isFalse,
      );
      draft.deleteTreatmentPlan('a');
      expect(draft.treatmentPlans, isEmpty);
    },
  );
  for (final duration in ['', '1', '007', '2147483647']) {
    test(
      'native optional duration accepts "$duration"',
      () => expect(DynamicMedicineEntry.durationError(duration), isNull),
    );
  }
  for (final duration in ['0', '-1']) {
    test(
      'native duration rejects "$duration" as non-positive',
      () => expect(
        DynamicMedicineEntry.durationError(duration),
        'Duration must be greater than 0',
      ),
    );
  }
  for (final duration in [
    '1.5',
    'days',
    '0x10',
    '2147483648',
    '999999999999999999999999',
  ]) {
    test(
      'native duration rejects "$duration" as invalid',
      () => expect(
        DynamicMedicineEntry.durationError(duration),
        'Enter a valid positive duration',
      ),
    );
  }
  test('invalid nonnumeric Rx identifiers cannot become null API IDs', () {
    final entry = rxMedicine(id: '0x10');
    expect(entry.toBody, throwsA(isA<AppFailure>()));
    expect(
      () => DynamicTreatmentPlanEntry(masterId: 'bad', text: 'Plan').toBody(),
      throwsA(isA<AppFailure>()),
    );
  });
  test(
    'all six Rx GETs use native response keys and doctor query scope',
    () async {
      final h = DynamicClinicalHarness();
      h.transport.onGet = (uri) async => rxOptionResponse(uri);
      final catalogue = await DynamicRxRepository(
        h.appointments,
      ).load(h.session, h.profile, isCurrent: () => true);
      expect(catalogue.medicines.first.id, '100');
      expect(catalogue.doses.first.id, '2');
      expect(catalogue.timings.first.id, '2');
      expect(catalogue.routes.first.id, '11');
      expect(catalogue.therapies.first.id, '200');
      expect(catalogue.treatmentPlans.first.id, '300');
      expect(h.transport.requests.map((r) => r.uri.pathSegments.last).toSet(), {
        'getMedicine',
        'getDoses',
        'getMedicineTiming',
        'getMedicineRoute',
        'getTherapy',
        'getTreatmentPlan',
      });
      for (final r in h.transport.requests) {
        expect(r.method, 'GET');
        expect(
          r.uri.queryParameters,
          ['getTherapy', 'getTreatmentPlan'].contains(r.uri.pathSegments.last)
              ? {'p_doc_id': '10'}
              : <String, String>{},
        );
      }
    },
  );
  test(
    'catalogue preserves native order/Unicode and filters blank names',
    () async {
      final h = DynamicClinicalHarness();
      h.transport.onGet =
          (uri) async =>
              uri.pathSegments.last == 'getMedicine'
                  ? {
                    'items':
                        '[{"medicine_id":5,"medicine_name":"বাংলা নাম"},{"medicine_id":6,"medicine_name":""},{"medicine_id":7,"medicine_name":"বাংলা নাম"}]',
                  }
                  : rxOptionResponse(uri);
      final c = await DynamicRxRepository(
        h.appointments,
      ).load(h.session, h.profile, isCurrent: () => true);
      expect(c.medicines.map((e) => e.id), ['5', '7']);
      expect(DynamicRxOption.exact(c.medicines, 'বাংলা নাম')!.id, '5');
    },
  );
  test(
    'disabled Dynamic account and stale requests cannot fetch/publish Rx data',
    () async {
      final h = DynamicClinicalHarness();
      final repository = DynamicRxRepository(h.appointments);
      h.doctorData['presc_active'] = '0';
      await expectLater(
        repository.load(h.session, h.profile, isCurrent: () => true),
        throwsA(isA<AppFailure>()),
      );
      expect(h.transport.requests, isEmpty);
      h.doctorData['presc_active'] = '1';
      var current = true;
      final pending = Completer<JsonMap>();
      h.transport.onGet =
          (uri) =>
              uri.pathSegments.last == 'getMedicine'
                  ? pending.future
                  : Future.value(rxOptionResponse(uri));
      final load = DynamicRxRepository(
        h.appointments,
      ).load(h.session, h.profile, isCurrent: () => current);
      current = false;
      pending.completeError(const AppFailure('Late failure'));
      await expectLater(load, throwsA(isA<ObsoleteRequest>()));
    },
  );
  test(
    'malformed Rx catalogue returns an error rather than a successful empty list',
    () async {
      final h = DynamicClinicalHarness();
      h.transport.onGet = (_) async => {'items': 'broken'};
      await expectLater(
        DynamicRxRepository(
          h.appointments,
        ).load(h.session, h.profile, isCurrent: () => true),
        throwsA(isA<AppFailure>()),
      );
    },
  );
}

import 'dart:async';
import 'dart:convert';

import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_advice_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_advice_repository.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_clinical_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dynamic_advice_test_support.dart';
import 'dynamic_clinical_test_support.dart';

void main() {
  test(
    'native Advice body sends text only, two nullable numeric ID arrays and separate header text',
    () {
      final draft = DynamicAdviceDraft()..replaceFromData(adviceExistingData());
      addTearDown(draft.dispose);
      draft.saveEntry(
        DynamicAdviceType.advice,
        DynamicAdviceEntry(masterId: '402', text: 'Master advice'),
      );
      expect(draft.toBody(), {
        'advice': [
          {'text': 'Existing advice'},
          {'text': 'Master advice'},
        ],
        'followups': [
          {'dfi_id': 501, 'text': 'Follow-up detail with edited text'},
        ],
        'special_alerts': [
          {'dsai_id': 601, 'text': 'Special alert detail'},
        ],
      });
      expect(draft.reference, 'Existing reference');
      expect(draft.notes, 'Existing prescription notes');
      expect(draft.entries(DynamicAdviceType.advice).first.masterId, isNull);
      expect(draft.toBody().containsKey('reference'), isFalse);
      expect(draft.toBody().containsKey('notes'), isFalse);
    },
  );
  for (final type in DynamicAdviceType.values) {
    test(
      '${type.label} CRUD keeps local identity, rejects missing edits and does not notify on a no-op delete',
      () {
        final draft = DynamicAdviceDraft();
        addTearDown(draft.dispose);
        final entry = DynamicAdviceEntry(localId: 'a', text: 'Original');
        expect(draft.saveEntry(type, entry), isTrue);
        expect(
          draft.saveEntry(
            type,
            DynamicAdviceEntry(localId: 'a', text: 'Updated'),
            updating: true,
          ),
          isTrue,
        );
        expect(draft.entries(type).single.text, 'Updated');
        expect(
          draft.saveEntry(
            type,
            DynamicAdviceEntry(localId: 'missing', text: 'New'),
            updating: true,
          ),
          isFalse,
        );
        expect(
          draft.saveEntry(
            type,
            DynamicAdviceEntry(localId: 'a', text: 'Cannot append same ID'),
          ),
          isFalse,
        );
        final revision = draft.revision;
        draft.deleteEntry(type, 'missing');
        expect(draft.revision, revision);
        draft.deleteEntry(type, 'a');
        expect(draft.entries(type), isEmpty);
      },
    );
  }
  test(
    'duplicates use master ID OR case-insensitive final text and are scoped per Advice section',
    () {
      final draft = DynamicAdviceDraft();
      addTearDown(draft.dispose);
      expect(
        draft.saveEntry(
          DynamicAdviceType.followUp,
          DynamicAdviceEntry(masterId: '501', text: 'Edited text'),
        ),
        isTrue,
      );
      expect(
        draft.saveEntry(
          DynamicAdviceType.followUp,
          DynamicAdviceEntry(masterId: '501', text: 'Different'),
        ),
        isFalse,
      );
      expect(
        draft.saveEntry(
          DynamicAdviceType.followUp,
          DynamicAdviceEntry(masterId: '502', text: 'EDITED TEXT'),
        ),
        isFalse,
      );
      expect(
        draft.saveEntry(
          DynamicAdviceType.specialAlert,
          DynamicAdviceEntry(masterId: '501', text: 'Edited text'),
        ),
        isTrue,
      );
    },
  );
  for (final type in [DynamicAdviceType.reference, DynamicAdviceType.notes]) {
    test(
      '${type.label} permits one entry and allows an update or delete before adding a replacement',
      () {
        final draft = DynamicAdviceDraft();
        addTearDown(draft.dispose);
        final entry = DynamicAdviceEntry(text: 'First');
        draft.saveEntry(type, entry);
        expect(
          draft.saveEntry(type, DynamicAdviceEntry(text: 'Second')),
          isFalse,
        );
        expect(
          draft.saveEntry(
            type,
            DynamicAdviceEntry(localId: entry.localId, text: 'Updated'),
            updating: true,
          ),
          isTrue,
        );
        expect(draft.entries(type).single.text, 'Updated');
        draft.deleteEntry(type, entry.localId);
        expect(
          draft.saveEntry(type, DynamicAdviceEntry(text: 'Replacement')),
          isTrue,
        );
      },
    );
  }
  test(
    'parsing native arrays skips blank text, preserves Unicode and ignores Advice master IDs on server loads',
    () {
      final draft =
          DynamicAdviceDraft()..replaceFromData({
            'advice': '[{"dai_id":401,"text":"নিজস্ব পরামর্শ"},{"text":""}]',
            'followups': '[{"dfi_id":null,"text":"Custom follow-up"}]',
            'special_alerts': [
              {'dsai_id': 601, 'text': 'Alert'},
            ],
            'reference': null,
            'notes': '  Saved notes  ',
          });
      addTearDown(draft.dispose);
      expect(draft.entries(DynamicAdviceType.advice).single.masterId, isNull);
      expect(
        draft.entries(DynamicAdviceType.advice).single.text,
        'নিজস্ব পরামর্শ',
      );
      expect(draft.entries(DynamicAdviceType.followUp).single.masterId, isNull);
      expect(draft.reference, '');
      expect(draft.notes, 'Saved notes');
      final all = [
        for (final type in DynamicAdviceType.values) ...draft.entries(type),
      ];
      expect(all.map((entry) => entry.localId).toSet(), hasLength(all.length));
    },
  );
  test(
    'malformed final array cannot replace any earlier section or single text',
    () {
      final draft = DynamicAdviceDraft()..replaceFromData(adviceExistingData());
      addTearDown(draft.dispose);
      final before = jsonEncode(draft.toBody()),
          reference = draft.reference,
          notes = draft.notes,
          revision = draft.revision;
      expect(
        () => draft.replaceFromData({
          'advice': [],
          'followups': [],
          'special_alerts': 'broken',
          'reference': 'New',
        }),
        throwsA(isA<AppFailure>()),
      );
      expect(jsonEncode(draft.toBody()), before);
      expect(draft.reference, reference);
      expect(draft.notes, notes);
      expect(draft.revision, revision);
      expect(
        () => draft.entries(DynamicAdviceType.advice).clear(),
        throwsUnsupportedError,
      );
      expect(
        () => adviceCatalogue().options[DynamicAdviceType.advice]!.clear(),
        throwsUnsupportedError,
      );
    },
  );
  test(
    'Follow-up/Special Alert invalid IDs fail serialization; Advice ID is never serialized',
    () {
      final entry = DynamicAdviceEntry(masterId: 'bad-id', text: 'Text');
      expect(
        () => entry.toBody(DynamicAdviceType.followUp),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => entry.toBody(DynamicAdviceType.specialAlert),
        throwsA(isA<AppFailure>()),
      );
      expect(entry.toBody(DynamicAdviceType.advice), {'text': 'Text'});
    },
  );
  test(
    'catalogue calls exactly three native doctor-specific GETs and maps exact response fields',
    () async {
      final h = DynamicClinicalHarness();
      h.transport.onGet = (uri) async => adviceOptionResponse(uri);
      final c = await DynamicAdviceRepository(
        h.appointments,
      ).load(h.session, h.profile, isCurrent: () => true);
      expect(h.transport.requests.map((r) => r.uri.pathSegments.last).toSet(), {
        'getAdvice',
        'getFollowUp',
        'getSpecialAlert',
      });
      for (final r in h.transport.requests) {
        expect(r.method, 'GET');
        expect(r.uri.queryParameters, {'p_doc_id': '10'});
      }
      expect(c.options[DynamicAdviceType.advice]!.first.id, '401');
      expect(c.options[DynamicAdviceType.followUp]!.first.id, '501');
      expect(c.options[DynamicAdviceType.specialAlert]!.first.id, '601');
      expect(c.options[DynamicAdviceType.reference], isEmpty);
      expect(c.options[DynamicAdviceType.notes], isEmpty);
    },
  );
  test(
    'native option source order, duplicate names and Unicode are retained',
    () async {
      final h = DynamicClinicalHarness();
      h.transport.onGet =
          (uri) async =>
              uri.pathSegments.last == 'getAdvice'
                  ? {
                    'items':
                        '[{"dai_id":9,"dai_advice":"নিজস্ব পরামর্শ"},{"dai_id":10,"dai_advice":""},{"dai_id":11,"dai_advice":"নিজস্ব পরামর্শ"}]',
                  }
                  : adviceOptionResponse(uri);
      final c = await DynamicAdviceRepository(
        h.appointments,
      ).load(h.session, h.profile, isCurrent: () => true);
      expect(c.options[DynamicAdviceType.advice]!.map((e) => e.id), [
        '9',
        '11',
      ]);
      expect(
        DynamicRxOption.exact(
          c.options[DynamicAdviceType.advice]!,
          'নিজস্ব পরামর্শ',
        )!.id,
        '9',
      );
    },
  );
  test(
    'disabled account does not read Advice; stale success and failure cannot publish a catalogue',
    () async {
      final h = DynamicClinicalHarness();
      h.doctorData['can_prescribe'] = '0';
      await expectLater(
        DynamicAdviceRepository(
          h.appointments,
        ).load(h.session, h.profile, isCurrent: () => true),
        throwsA(isA<AppFailure>()),
      );
      expect(h.transport.requests, isEmpty);
      h.doctorData['can_prescribe'] = '1';
      for (final fail in [false, true]) {
        var current = true;
        final pending = Completer<JsonMap>();
        h.transport.onGet =
            (uri) =>
                uri.pathSegments.last == 'getAdvice'
                    ? pending.future
                    : Future.value(adviceOptionResponse(uri));
        final load = DynamicAdviceRepository(
          h.appointments,
        ).load(h.session, h.profile, isCurrent: () => current);
        current = false;
        if (fail) {
          pending.completeError(const AppFailure('Late failure'));
        } else {
          pending.complete({'items': []});
        }
        await expectLater(load, throwsA(isA<ObsoleteRequest>()));
      }
    },
  );
  test(
    'malformed catalogue is an error rather than a successful empty response',
    () async {
      final h = DynamicClinicalHarness();
      h.transport.onGet = (_) async => {'items': 'broken'};
      await expectLater(
        DynamicAdviceRepository(
          h.appointments,
        ).load(h.session, h.profile, isCurrent: () => true),
        throwsA(isA<AppFailure>()),
      );
    },
  );
}

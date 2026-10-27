import 'dart:async';
import 'dart:convert';

import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_clinical_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_clinical_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dynamic_clinical_test_support.dart';

void main() {
  group('native Clinical draft', () {
    test(
      'malformed master IDs fail serialization as in native getJsonNumberOrNull',
      () {
        final entry = DynamicClinicalEntry(masterId: 'bad-id', text: 'Text');
        expect(
          () => entry.toBody(DynamicClinicalType.complain),
          throwsA(isA<AppFailure>()),
        );
        expect(
          DynamicClinicalEntry(
            text: 'Custom text',
          ).toBody(DynamicClinicalType.complain),
          {'cm_id': null, 'name': 'Custom text'},
        );
      },
    );
    test(
      'duplicate checks use master ID or case-insensitive final text, scoped by section',
      () {
        final draft = DynamicClinicalDraft();
        addTearDown(draft.dispose);
        expect(
          draft.saveEntry(
            DynamicClinicalType.complain,
            DynamicClinicalEntry(masterId: '1', text: 'Low back pain'),
          ),
          isTrue,
        );
        expect(
          draft.saveEntry(
            DynamicClinicalType.complain,
            DynamicClinicalEntry(
              masterId: '1',
              text: 'Low back pain for 3 days',
            ),
          ),
          isFalse,
        );
        expect(
          draft.saveEntry(
            DynamicClinicalType.complain,
            DynamicClinicalEntry(text: 'LOW BACK PAIN'),
          ),
          isFalse,
        );
        expect(
          draft.saveEntry(
            DynamicClinicalType.diagnosis,
            DynamicClinicalEntry(masterId: '1', text: 'Low back pain'),
          ),
          isTrue,
        );
        final first = draft.entries(DynamicClinicalType.complain).single;
        expect(
          draft.saveEntry(
            DynamicClinicalType.complain,
            DynamicClinicalEntry(
              localId: first.localId,
              masterId: '1',
              text: 'Low back pain for 3 days',
            ),
            updating: true,
          ),
          isTrue,
        );
        expect(
          draft.entries(DynamicClinicalType.complain).single.localId,
          first.localId,
        );
        expect(
          draft.saveEntry(
            DynamicClinicalType.complain,
            DynamicClinicalEntry(localId: 'missing', text: 'Other'),
            updating: true,
          ),
          isFalse,
        );
        expect(
          () => draft.entries(DynamicClinicalType.complain).clear(),
          throwsUnsupportedError,
        );
      },
    );
    test('UUID local IDs do not alias separate entries', () {
      final entries = List.generate(
        100,
        (_) => DynamicClinicalEntry(text: 'Entry'),
      );
      expect(entries.map((item) => item.localId).toSet(), hasLength(100));
      expect(
        entries.first.localId,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });
    test(
      'native JSON body retains custom text and uses numeric master IDs/null',
      () {
        final draft = DynamicClinicalDraft();
        addTearDown(draft.dispose);
        for (final type in DynamicClinicalType.values) {
          draft.saveEntry(
            type,
            DynamicClinicalEntry(
              masterId: type.hasOptions ? '17' : null,
              text: 'Final custom text',
              notes: type.hasNotes ? 'Within 7 days' : '',
            ),
          );
        }
        final body = draft.toBody();
        expect(body['complaints'], [
          {'cm_id': 17, 'name': 'Final custom text'},
        ]);
        expect(body['drug_history'], [
          {'medicine_id': 17},
        ]);
        expect(body['investigations'], [
          {'pfn_id': 17, 'notes': 'Within 7 days'},
        ]);
        expect(body['important_info'], [
          {'text': 'Final custom text'},
        ]);
        draft.saveEntry(
          DynamicClinicalType.injury,
          DynamicClinicalEntry(text: 'Custom injury'),
        );
        expect(nativeArray(draft.toBody()['injuries']).last, {
          'injury_id': null,
          'name': 'Custom injury',
        });
        expect(() => jsonEncode(draft.toBody()), returnsNormally);
      },
    );
    test(
      'objective duplicates compare objective/value/joint/notes; update preserves local identity',
      () {
        final draft = DynamicClinicalDraft();
        addTearDown(draft.dispose);
        final a = DynamicObjectiveEntry(
          objective: const DynamicRxOption('5', 'ROM'),
          notes: 'Loss 15°',
        );
        expect(draft.saveObjective(a), isTrue);
        expect(
          draft.saveObjective(
            DynamicObjectiveEntry(
              objective: const DynamicRxOption('5', 'Range of movement'),
              notes: 'LOSS 15°',
            ),
          ),
          isFalse,
        );
        expect(
          draft.saveObjective(
            DynamicObjectiveEntry(objective: a.objective, notes: 'Loss 30°'),
          ),
          isTrue,
        );
        expect(
          draft.saveObjective(
            DynamicObjectiveEntry(
              localId: a.localId,
              objective: a.objective,
              value: const DynamicRxOption('9', 'Flexion'),
              muscleJoint: const DynamicRxOption('7', 'Knee'),
              notes: 'Loss 15°',
            ),
            updating: true,
          ),
          isTrue,
        );
        expect(nativeArray(draft.toBody()['objective_info']).first, {
          'om_id': 5,
          'od_id': 9,
          'mjl_id': 7,
          'notes': 'Loss 15°',
        });
        draft.deleteObjective(a.localId);
        expect(draft.objectives, hasLength(1));
      },
    );
    test(
      'load parses all Clinical sections and is atomic on malformed data',
      () {
        final draft = DynamicClinicalDraft();
        addTearDown(draft.dispose);
        draft.replaceFromData({
          'complaints': [
            {'cm_id': 1, 'name': 'ব্যথা'},
          ],
          'clinical_findings': jsonEncode([
            {'cfm_id': 2, 'name': 'Tenderness'},
          ]),
          'drug_history': [
            {'medicine_id': 3, 'name': 'Medicine'},
          ],
          'investigations': [
            {'pfn_id': 4, 'name': 'X-ray', 'notes': 'Left knee'},
          ],
          'important_info': [
            {'text': 'Precaution'},
          ],
          'objective_info': [
            {
              'om_id': 5,
              'om_name': 'ROM',
              'od_id': null,
              'od_name': null,
              'notes': '15°',
            },
          ],
          'vitals': {'height': '170', 'weight': '68', 'bmi': '23.5'},
        });
        expect(
          draft.entries(DynamicClinicalType.complain).single.text,
          'ব্যথা',
        );
        expect(draft.objectives.single.value, isNull);
        expect(draft.vitals!['bmi'], '23.5');
        final before = jsonEncode(draft.toBody()), revision = draft.revision;
        expect(
          () => draft.replaceFromData({
            'complaints': [],
            'objective_info': 'broken',
          }),
          throwsA(isA<AppFailure>()),
        );
        expect(jsonEncode(draft.toBody()), before);
        expect(draft.revision, revision);
      },
    );
    test('removing one row leaves other sections and vitals intact', () {
      final draft = DynamicClinicalDraft();
      addTearDown(draft.dispose);
      final entry = DynamicClinicalEntry(text: 'Complain');
      draft.saveEntry(DynamicClinicalType.complain, entry);
      draft.saveEntry(
        DynamicClinicalType.diagnosis,
        DynamicClinicalEntry(text: 'Diagnosis'),
      );
      draft.saveVitals(DynamicVitals({'pulse': '72'}));
      draft.deleteEntry(DynamicClinicalType.complain, entry.localId);
      expect(draft.entries(DynamicClinicalType.complain), isEmpty);
      expect(draft.entries(DynamicClinicalType.diagnosis), hasLength(1));
      expect(draft.vitals!.summary, ['Pulse: 72 bpm']);
    });
    test(
      'ClinicalOptionAdapter uses all-word substring filtering and first exact source match',
      () {
        const first = DynamicRxOption('1', 'Low back pain'),
            second = DynamicRxOption('2', 'LOW BACK PAIN');
        expect(first.matches('pain low'), isTrue);
        expect(first.matches('back hip'), isFalse);
        expect(first.matches('ACK'), isTrue);
        expect(
          DynamicRxOption.exact([first, second], ' low back pain '),
          same(first),
        );
      },
    );
  });

  group('native Vitals validation', () {
    test('all blank is empty and BMI is derived in cm/kg to one decimal', () {
      expect(DynamicVitals({}).isEmpty, isTrue);
      expect(DynamicVitals.calculateBmi('170', '68'), '23.5');
      expect(DynamicVitals.calculateBmi('0', '68'), '');
      expect(DynamicVitals.calculateBmi('170', ''), '');
      expect(DynamicVitals.calculateBmi('bad', '68'), '');
    });
    test(
      'BP requires the pair while independent measurements remain optional',
      () {
        expect(DynamicVitals({'systolic': '120'}).errors, {
          'diastolic': 'Enter diastolic pressure',
        });
        expect(DynamicVitals({'diastolic': '80'}).errors, {
          'systolic': 'Enter systolic pressure',
        });
        expect(DynamicVitals({'pulse': '72'}).errors, isEmpty);
        expect(
          DynamicVitals({'systolic': '120', 'diastolic': '80'}).errors,
          isEmpty,
        );
      },
    );
    for (final key in [
      'systolic',
      'diastolic',
      'pulse',
      'temperature',
      'respiration',
      'height',
      'weight',
    ]) {
      test(
        '$key rejects nonpositive/nonfinite values without inventing an extra medical range',
        () {
          for (final value in ['0', '-1', 'bad', 'NaN', 'Infinity']) {
            expect(
              DynamicVitals({key: value}).errors[key],
              'Enter a valid value',
            );
          }
          expect(DynamicVitals({key: '999'}).errors[key], isNull);
        },
      );
    }
    test('SpO2 accepts native endpoints 1 and 100 only', () {
      for (final value in ['1', '100', '98']) {
        expect(DynamicVitals({'spo2': value}).errors, isEmpty);
      }
      for (final value in ['0', '101', 'bad']) {
        expect(
          DynamicVitals({'spo2': value}).errors['spo2'],
          'Value must be 1–100',
        );
      }
    });
    test(
      'summary uses native units including Fahrenheit and skips blank rows',
      () {
        expect(
          DynamicVitals({
            'systolic': '120',
            'diastolic': '80',
            'temperature': '98.6',
            'spo2': '98',
          }).summary,
          ['BP: 120/80 mmHg', 'Temperature: 98.6 °F  •  SpO₂: 98%'],
        );
      },
    );
  });

  group('native Clinical GET contracts', () {
    late DynamicClinicalHarness h;
    late DynamicClinicalRepository repository;
    setUp(() async {
      h = DynamicClinicalHarness();
      h.transport.requests.clear();
      repository = DynamicClinicalRepository(h.appointments);
      h.transport.onGet = (_) async => {'items': []};
    });
    test(
      'loads exactly eight native catalogues with exact doctor-specific parameters and no writes',
      () async {
        final data = await repository.load(
          h.session,
          h.profile,
          isCurrent: () => true,
        );
        expect(data.clinical[DynamicClinicalType.complain], isEmpty);
        final queries = {
          for (final request in h.transport.requests)
            request.uri.pathSegments.last: request.uri.queryParameters,
        };
        expect(queries, {
          'getComplain': {'p_doc_id': '10'},
          'getInjury': {'p_doc_id': '10'},
          'getDiagnosis': {'p_doc_id': '10'},
          'getClinicalFindings': {'p_doc_id': '10'},
          'getDrugHistory': <String, String>{},
          'getTestInvestigation': <String, String>{},
          'getObjective': {'p_doc_id': '10'},
          'getMuscleJoint': <String, String>{},
        });
        expect(
          h.transport.requests.every(
            (r) => r.method == 'GET' && r.uri.path.contains('/dynamic_presc/'),
          ),
          isTrue,
        );
      },
    );
    test(
      'keeps source order, duplicate names, native notes and Unicode; skips missing names',
      () async {
        h.transport.onGet =
            (uri) async =>
                uri.path.endsWith('/getComplain')
                    ? {
                      'items': [
                        {
                          'cm_id': 3,
                          'cm_name': 'ব্যথা',
                          'cm_notes': 'Doctor notes',
                        },
                        {'cm_id': 4, 'cm_name': 'ব্যথা'},
                        {'cm_id': 5, 'cm_name': null},
                      ],
                    }
                    : {'items': []};
        final data = await repository.load(
          h.session,
          h.profile,
          isCurrent: () => true,
        );
        expect(data.clinical[DynamicClinicalType.complain]!.map((o) => o.id), [
          '3',
          '4',
        ]);
        expect(
          data.clinical[DynamicClinicalType.complain]!.first.note,
          'Doctor notes',
        );
        expect(
          data.clinical[DynamicClinicalType.complain]!.first.name,
          'ব্যথা',
        );
      },
    );
    test(
      'dependent values use objective and doctor IDs encoded once',
      () async {
        h.transport.onGet =
            (_) async => {
              'items': [
                {'od_id': 17, 'od_name': 'Flexion'},
              ],
            };
        final options = await repository.objectiveValues(
          h.session,
          h.profile,
          '1 & 2+',
          isCurrent: () => true,
        );
        expect(options.single.id, '17');
        expect(h.transport.requests.single.uri.queryParameters, {
          'p_om_id': '1 & 2+',
          'p_doc_id': '10',
        });
      },
    );
    test('blank objective does not send a request', () async {
      expect(
        await repository.objectiveValues(
          h.session,
          h.profile,
          '',
          isCurrent: () => true,
        ),
        isEmpty,
      );
      expect(h.transport.requests, isEmpty);
    });
    test(
      'stale request before and after transport cannot publish catalogue data',
      () async {
        await expectLater(
          repository.load(h.session, h.profile, isCurrent: () => false),
          throwsA(isA<ObsoleteRequest>()),
        );
        expect(h.transport.requests, isEmpty);
        var current = true;
        final response = Completer<JsonMap>();
        h.transport.onGet = (_) => response.future;
        final result = repository.objectiveValues(
          h.session,
          h.profile,
          '1',
          isCurrent: () => current,
        );
        current = false;
        response.complete({
          'items': [
            {'od_id': 17, 'od_name': 'Flexion'},
          ],
        });
        await expectLater(result, throwsA(isA<ObsoleteRequest>()));
      },
    );
    test(
      'normal-prescription account, wrong doctor and expired access block IO',
      () async {
        for (final changed in [
          {'presc_active': '0'},
          {'can_prescribe': '0'},
          {'doc_code': 'different'},
          {'exp_date': '01-JAN-20'},
        ]) {
          final profile = AccountProfile(AccountRole.doctor, {
            ...h.doctorData,
            ...changed,
          });
          await expectLater(
            repository.load(h.session, profile, isCurrent: () => true),
            throwsA(isA<AppFailure>()),
          );
        }
        expect(h.transport.requests, isEmpty);
      },
    );
    test(
      'network and malformed responses fail rather than publishing a partial load',
      () async {
        h.transport.onGet = (uri) async {
          if (uri.path.endsWith('/getObjective')) {
            throw const AppFailure('Offline', kind: FailureKind.network);
          }
          return {'items': []};
        };
        await expectLater(
          repository.load(h.session, h.profile, isCurrent: () => true),
          throwsA(isA<AppFailure>()),
        );
        h.transport.onGet = (_) async => {'items': 'broken'};
        await expectLater(
          repository.objectiveValues(
            h.session,
            h.profile,
            '1',
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
      },
    );
  });
}

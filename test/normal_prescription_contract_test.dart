import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/prescription/normal_prescription_models.dart';
import 'package:docdiary_ios/features/prescription/normal_prescription_repository.dart';
import 'normal_prescription_test_support.dart';

void main() {
  late NormalRxHarness h;
  late NormalPrescriptionRepository repo;
  final native =
      jsonDecode(
            File(
              'test/fixtures/normal_prescription_native_contract.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  setUp(() async {
    h = NormalRxHarness();
    await h.signIn();
    h.transport.requests.clear();
    repo = h.rx;
  });
  tearDown(() => h.auth.dispose());
  AccountProfile profile([Map<String, Object?> values = const {}]) =>
      AccountProfile(h.auth.profile!.role, {...h.doctorData, ...values});
  RxContext contextFor() => RxContext(
    rxPatient(),
    diagnosis: rxEntry(NormalPrescriptionSection.diagnosis),
    referral: rxEntry(NormalPrescriptionSection.referral),
  );
  test('editor and patient search modes are fixed by their entry points', () {
    expect(h.editSeed.valid, isTrue);
    expect(h.editSeed.readOnly, isFalse);
    expect(h.viewSeed.valid, isTrue);
    expect(h.viewSeed.readOnly, isTrue);
  });
  test(
    'new prescription loads patient details but sends no create request',
    () async {
      h.created = false;
      final data = await repo.load(
        h.auth.session!,
        profile(),
        h.editSeed,
        isCurrent: () => true,
      );
      expect(data.exists, isFalse);
      expect(data.patient['pat_name'], 'Sample Patient');
      expect(h.posts, isEmpty);
    },
  );
  test(
    'create uses exact native identity headers and output identifier',
    () async {
      h.created = false;
      await repo.create(
        h.auth.session!,
        profile(),
        h.editSeed,
        isCurrent: () => true,
      );
      expect(
        h.posts.single.uri.path,
        endsWith('/prescription/insertNewPrescription'),
      );
      expect(h.posts.single.headers, {
        'P_PH_ID': '11',
        'P_CAT_ID': '4',
        'P_USER': '10',
      });
      expect(
        h.posts.single.headers.keys.toSet(),
        (native['insertNewPrescription']['headers'] as List).toSet(),
      );
    },
  );
  test(
    'rechecking existing master avoids duplicate creation after lost response',
    () async {
      await repo.create(
        h.auth.session!,
        profile(),
        h.editSeed,
        isCurrent: () => true,
      );
      expect(h.posts, isEmpty);
    },
  );
  test(
    'patient search uses native view endpoint and all nine master sections',
    () async {
      final data = await repo.load(
        h.auth.session!,
        profile(),
        h.viewSeed,
        isCurrent: () => true,
      );
      expect(data.rows.length, 9);
      expect(
        h.transport.requests.first.uri.path,
        endsWith('/patient_search/getPatData'),
      );
      expect(h.posts, isEmpty);
    },
  );
  test('view mode without prescription never creates a master', () async {
    h.created = false;
    final data = await repo.load(
      h.auth.session!,
      profile(),
      h.viewSeed,
      isCurrent: () => true,
    );
    expect(data.exists, isFalse);
    expect(h.posts, isEmpty);
  });
  for (final spec in rxSectionSpecs.values) {
    for (final action in ['add', 'edit', 'delete']) {
      test(
        '${spec.label} $action calls native endpoint with native header contract',
        () async {
          final original = rxEntry(spec.section);
          final values = spec.values(original);
          // A different entered value ensures this is a real add/update rather than a duplicate no-op.
          if (action != 'delete') {
            values[spec.fields.first.header] =
                spec.fields.first.isChoice ? '201' : 'New saved detail';
          }
          await repo.save(
            h.auth.session!,
            profile(),
            h.editSeed,
            spec,
            contextFor(),
            values,
            existing: action == 'add' ? null : original,
            deleting: action == 'delete',
            isCurrent: () => true,
          );
          final endpoint =
              action == 'add'
                  ? spec.insertEndpoint
                  : action == 'edit'
                  ? spec.updateEndpoint
                  : spec.deleteEndpoint;
          expect(h.posts.length, 1);
          expect(h.posts.single.uri.path, endsWith('/prescription/$endpoint'));
          expect(
            h.posts.single.headers.keys.toSet(),
            (native[endpoint]['headers'] as List).toSet(),
          );
          if (action == 'delete') {
            expect(h.posts.single.headers, {
              'P_${spec.rowId.toUpperCase()}': original[spec.rowId],
            });
          } else {
            expect(
              h.posts.single.headers['P_${spec.parentKey.toUpperCase()}'],
              contextFor().parentId(spec),
            );
            expect(
              h.posts.single.headers[spec.fields.first.header],
              values[spec.fields.first.header],
            );
          }
        },
      );
    }
    test(
      '${spec.label} refuses all mutations from PatientSearch before any API call',
      () async {
        for (final action in ['add', 'edit', 'delete']) {
          await expectLater(
            repo.save(
              h.auth.session!,
              profile(),
              h.viewSeed,
              spec,
              contextFor(),
              {},
              existing: action == 'add' ? null : rxEntry(spec.section),
              deleting: action == 'delete',
              isCurrent: () => true,
            ),
            throwsA(isA<AppFailure>()),
          );
        }
        expect(h.transport.requests, isEmpty);
      },
    );
    test(
      '${spec.label} unchanged data after a lost add response is not posted twice',
      () async {
        await repo.save(
          h.auth.session!,
          profile(),
          h.editSeed,
          spec,
          contextFor(),
          spec.values(rxEntry(spec.section)),
          isCurrent: () => true,
        );
        expect(h.posts, isEmpty);
      },
    );
  }
  test('PatientSearch also refuses create and admission requests', () async {
    await expectLater(
      repo.create(
        h.auth.session!,
        profile(),
        h.viewSeed,
        isCurrent: () => true,
      ),
      throwsA(isA<AppFailure>()),
    );
    await expectLater(
      repo.admission(
        h.auth.session!,
        profile(),
        h.viewSeed,
        contextFor(),
        true,
        isCurrent: () => true,
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(h.transport.requests, isEmpty);
  });
  test(
    'admission uses native flag headers and skips unchanged state',
    () async {
      await repo.admission(
        h.auth.session!,
        profile(),
        h.editSeed,
        contextFor(),
        false,
        isCurrent: () => true,
      );
      expect(h.posts, isEmpty);
      await repo.admission(
        h.auth.session!,
        profile(),
        h.editSeed,
        contextFor(),
        true,
        isCurrent: () => true,
      );
      expect(h.posts.single.headers, {'P_FLAG': '1', 'P_PMM_ID': '90'});
    },
  );
  for (final change in [
    {'presc_active': '1', 'can_prescribe': '1'},
    {'doc_id': '999'},
    {'access_flag': '0'},
  ]) {
    test('changed access/doctor $change prevents a write', () async {
      await expectLater(
        repo.create(
          h.auth.session!,
          profile(change),
          h.editSeed,
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.posts, isEmpty);
    });
  }
  for (final kind in [
    NormalPrescriptionSection.diagnosis,
    NormalPrescriptionSection.referral,
  ]) {
    for (final deleting in [false, true]) {
      test(
        '$kind with child data cannot be ${deleting ? "deleted" : "edited"}',
        () async {
          final row = {...rxEntry(kind), 'child_count': '1'};
          h.entries[kind] = [row];
          final spec = rxSectionSpecs[kind]!;
          await expectLater(
            repo.save(
              h.auth.session!,
              profile(),
              h.editSeed,
              spec,
              contextFor(),
              spec.values(row),
              existing: row,
              deleting: deleting,
              isCurrent: () => true,
            ),
            throwsA(isA<AppFailure>()),
          );
          expect(h.posts, isEmpty);
        },
      );
    }
  }
  test(
    'deleted parent cannot move a service draft to another referral',
    () async {
      h.entries[NormalPrescriptionSection.referral] = [];
      final spec = rxSectionSpecs[NormalPrescriptionSection.service]!;
      await expectLater(
        repo.save(
          h.auth.session!,
          profile(),
          h.editSeed,
          spec,
          contextFor(),
          spec.values(rxEntry(spec.section)),
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.posts, isEmpty);
    },
  );
  test('a changed master cannot receive old draft data', () async {
    final bad = RxContext({...rxPatient(), 'pmm_id': '99'});
    final spec = rxSectionSpecs[NormalPrescriptionSection.advice]!;
    await expectLater(
      repo.save(h.auth.session!, profile(), h.editSeed, spec, bad, {
        'P_PA_NAME': 'New advice',
      }, isCurrent: () => true),
      throwsA(isA<AppFailure>()),
    );
    expect(h.posts, isEmpty);
  });
  test('server rows for another parent are rejected', () async {
    h.entries[NormalPrescriptionSection.complain] = [
      {...rxEntry(NormalPrescriptionSection.complain), 'pci_pmm_id': '999'},
    ];
    await expectLater(
      repo.load(h.auth.session!, profile(), h.editSeed, isCurrent: () => true),
      throwsA(isA<AppFailure>()),
    );
  });
  test(
    'invalid counts and a missing list are errors rather than empty success',
    () async {
      h.transport.onGet = (uri) async => {'count': 'invalid', 'items': []};
      await expectLater(
        repo.load(
          h.auth.session!,
          profile(),
          h.editSeed,
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'expired operation never displays or posts stale patient data',
    () async {
      var current = true;
      final pending = Completer<JsonMap>();
      h.transport.onGet = (_) => pending.future;
      final load = repo.load(
        h.auth.session!,
        profile(),
        h.editSeed,
        isCurrent: () => current,
      );
      current = false;
      pending.complete({
        'count': 1,
        'items': [rxPatient()],
      });
      await expectLater(load, throwsA(isA<ObsoleteRequest>()));
      expect(h.posts, isEmpty);
    },
  );
  test(
    'one in-flight create and failed POST are never automatically retried',
    () async {
      h.created = false;
      final pending = Completer<JsonMap>();
      h.transport.onPost = (_, _) => pending.future;
      final first = repo.create(
        h.auth.session!,
        profile(),
        h.editSeed,
        isCurrent: () => true,
      );
      for (var i = 0; i < 15; i++) {
        await Future<void>.delayed(Duration.zero);
        if (h.posts.isNotEmpty) break;
      }
      await expectLater(
        repo.create(
          h.auth.session!,
          profile(),
          h.editSeed,
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      pending.completeError(const AppFailure('Timeout'));
      await expectLater(first, throwsA(isA<AppFailure>()));
      expect(h.posts.length, 1);
    },
  );
  test('non-success output and missing created ID are errors', () async {
    h.created = false;
    h.transport.onPost = (_, _) async => {'string_out': 'Failed'};
    await expectLater(
      repo.create(
        h.auth.session!,
        profile(),
        h.editSeed,
        isCurrent: () => true,
      ),
      throwsA(isA<AppFailure>()),
    );
    h.transport.onPost = (_, _) async => {'string_out': 'Successfully Created'};
    await expectLater(
      repo.create(
        h.auth.session!,
        profile(),
        h.editSeed,
        isCurrent: () => true,
      ),
      throwsA(isA<AppFailure>()),
    );
  });
  test(
    'choice IDs are retained independently even when names are identical',
    () async {
      final spec = rxSectionSpecs[NormalPrescriptionSection.diagnosis]!,
          field =
              rxSectionSpecs[NormalPrescriptionSection.diagnosis]!.fields.first;
      h.transport.onGet =
          (_) async => {
            'count': 2,
            'items': [
              {'dm_id': '1', 'dm_name': 'Same'},
              {'dm_id': '11', 'dm_name': 'Same'},
            ],
          };
      final choices = await repo.choices(
        h.auth.session!,
        profile(),
        h.editSeed,
        spec,
        contextFor(),
        field,
        isCurrent: () => true,
      );
      expect(choices.map((c) => c.id), ['1', '11']);
    },
  );
  for (final change in [
    {'all_presc': '1'},
    {'doc_head_flag': '1'},
    {'all_presc': '0', 'doc_head_flag': '0'},
  ]) {
    test('PatientSearch preserves native scope $change', () async {
      await repo.patients(
        h.auth.session!,
        profile(change),
        2026,
        isCurrent: () => true,
      );
      final request = h.transport.requests.last;
      if (change['all_presc'] == '1') {
        expect(request.uri.path, endsWith('/getPatientList'));
        expect(request.uri.queryParameters, {'p_year': '2026'});
      } else {
        expect(request.uri.path, endsWith('/getPatientListNew'));
        expect(request.uri.queryParameters, {
          'p_year': '2026',
          'p_doc_id': change['doc_head_flag'] == '1' ? '' : '10',
          'p_deptd_id': '8',
        });
      }
    });
  }
  test(
    'mandatory selection and API header validation reject invalid drafts',
    () {
      final spec = rxSectionSpecs[NormalPrescriptionSection.medicalHistory]!;
      expect(rxDraftError(spec, {}), isNotNull);
      expect(rxDraftError(spec, {'P_MHM_ID': 'typed name'}), isNotNull);
      expect(
        rxDraftError(spec, {'P_MHM_ID': '1', 'P_DETAILS': 'line\nline'}),
        isNotNull,
      );
      expect(
        rxDraftError(spec, {'P_MHM_ID': '1', 'P_DETAILS': 'বাংলা'}),
        isNotNull,
      );
      expect(
        rxDraftError(spec, {'P_MHM_ID': '1', 'P_DETAILS': 'Optional notes'}),
        isNull,
      );
    },
  );
}

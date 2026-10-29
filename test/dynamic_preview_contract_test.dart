import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_preview_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_preview_repository.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_preview_pdf_layout.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_preview_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dynamic_preview_test_support.dart';

void main() {
  for (final name in [
    'complete',
    'empty',
    'unicode',
    'left_only',
    'right_only',
    'long',
    'malformed_rows',
  ]) {
    test('HTML is byte-for-byte equal to native Java output: $name', () {
      final data = DynamicPrescriptionPreviewData.fromResponse(
        previewFixture(name),
      );
      final html = NativeDynamicPreviewHtml.build(
        data,
        printedAt: DateTime.fromMillisecondsSinceEpoch(
          1793192400000,
          isUtc: true,
        ),
      );
      expect(
        html,
        File('test/fixtures/dynamic_preview/$name.html').readAsStringSync(),
      );
    });
  }
  test(
    'native parsing keeps notes-only objectives and skips empty medicine/section rows',
    () {
      final response = previewFixture('malformed_rows');
      (response['data'] as JsonMap)['medications'] = [
        null,
        <String, Object?>{},
        {'medicine_name': ' '},
        {'medicine_name': ' Test ', 'notes': ' Note '},
      ];
      final data = DynamicPrescriptionPreviewData.fromResponse(response);
      expect(data.complaints.map((row) => row.text), ['42', 'false']);
      expect(data.objectiveInfo.single.notes, 'Notes only');
      expect(data.therapies, isEmpty);
      expect(data.medications.single.medicineName, 'Test');
      expect(data.medications.single.notes, 'Note');
      expect(data.vitals.isEmpty, isFalse);
    },
  );
  test(
    'invalid status/data reports the native error without producing a partial preview',
    () {
      for (final response in <JsonMap>[
        {},
        {'status': 500, 'message': 'Server unavailable'},
        {'status': 200},
        {'status': 200, 'data': []},
      ]) {
        expect(
          () => DynamicPrescriptionPreviewData.fromResponse(response),
          throwsA(isA<AppFailure>()),
        );
      }
    },
  );
  test(
    'document names use prescription code with the native safe fallback',
    () {
      final response = previewFixture();
      (response['data'] as JsonMap)['rvm_code'] = '26/001 9:00';
      expect(
        DynamicPrescriptionPreviewData.fromResponse(response).documentName,
        'Prescription_26_001_9_00',
      );
      expect(
        DynamicPrescriptionPreviewData.fromResponse(
          previewFixture('empty'),
        ).documentName,
        'Prescription_901',
      );
    },
  );
  final pagination =
      jsonDecode(
            File(
              'test/fixtures/dynamic_preview/pagination_oracle.json',
            ).readAsStringSync(),
          )
          as List;
  for (var i = 0; i < pagination.length; i++) {
    test('A4 page boundaries match native Java pagination: $i', () {
      final row = Map<String, Object?>.from(pagination[i] as Map);
      final result = DynamicPreviewPdfLayout.fromData(row).toPlatform();
      expect(result['pages'], row['expected']);
    });
  }
  test('invalid/oversized page layout fails with a bounded message', () {
    final base = Map<String, Object?>.from(pagination.first as Map);
    for (final delta in <JsonMap>[
      {'contentTop': -1},
      {'contentBottom': 0},
      {'footerBottom': 0},
      {'documentHeight': double.nan},
      {'documentHeight': 600001},
      {'ranges': null},
    ]) {
      expect(
        () => DynamicPreviewPdfLayout.fromData({...base, ...delta}).segments(),
        throwsA(isA<AppFailure>()),
      );
    }
    expect(
      () =>
          DynamicPreviewPdfLayout.fromData({
            ...base,
            'contentTop': 1000,
            'footerTop': 10000,
            'footerBottom': 10200,
            'documentHeight': 10200,
          }).segments(),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () =>
          DynamicPreviewPdfLayout.fromData({
            ...base,
            'contentTop': 100,
            'contentBottom': 590000,
            'footerTop': 590000,
            'footerBottom': 590100,
            'documentHeight': 590100,
            'ranges': [],
          }).segments(),
      throwsA(isA<AppFailure>()),
    );
  });
  for (final name in ['complete', 'long']) {
    test('parallel columns keep all rows and avoid tiny PDF pages: $name', () {
      final measured =
          jsonDecode(
                File(
                  'test/fixtures/dynamic_preview/${name}_layout.json',
                ).readAsStringSync(),
              )
              as JsonMap;
      final layout = DynamicPreviewPdfLayout.fromData(measured);
      final pages = layout.toPlatform()['columnPages'] as List<List<JsonMap>>;
      expect(pages.length, name == 'long' ? 5 : 1);
      for (final column in layout.columns) {
        var next = column.top;
        for (final page in pages) {
          for (final region in page.where(
            (r) => r['left'] == column.left && r['right'] == column.right,
          )) {
            expect(region['start'], next);
            next = region['end'] as int;
            expect(
              (region['destination'] as int) -
                  layout.contentTop +
                  next -
                  (region['start'] as int),
              lessThanOrEqualTo(layout.availableHeight),
            );
            for (final range in column.ranges) {
              if (range.bottom - range.top <= layout.availableHeight) {
                expect(range.top < next && range.bottom > next, isFalse);
              }
            }
          }
        }
        expect(next, column.bottom);
      }
    });
  }
  group('preview read-only API', () {
    late DynamicPreviewHarness h;
    late DynamicPrescriptionPreviewRepository repository;
    setUp(() async {
      h = DynamicPreviewHarness();
      await h.signIn();
      h.transport.requests.clear();
      repository = DynamicPrescriptionPreviewRepository(h.repository);
    });
    tearDown(() => h.auth.dispose());
    test(
      'exact GET query is encoded, reopened preview is fresh and never writes',
      () async {
        for (var i = 0; i < 2; i++) {
          await repository.load(
            h.auth.session!,
            h.auth.profile!,
            ' 900 ',
            isCurrent: () => true,
          );
        }
        expect(h.previewReads.length, 2);
        expect(h.previewReads.first.queryParameters, {'p_rvm_id': '900'});
        h.response = previewFixture();
        (h.response['data'] as JsonMap)['rvm_id'] = 'RX + / 1';
        await repository.load(
          h.auth.session!,
          h.auth.profile!,
          'RX + / 1',
          isCurrent: () => true,
        );
        expect(h.previewReads.last.queryParameters, {'p_rvm_id': 'RX + / 1'});
        expect(h.posts, isEmpty);
        expect(h.transport.binaryRequests, isEmpty);
      },
    );
    test('empty/wrong identity and removed permission are blocked', () async {
      await expectLater(
        repository.load(
          h.auth.session!,
          h.auth.profile!,
          '',
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.previewReads, isEmpty);
      await expectLater(
        repository.load(
          h.auth.session!,
          h.auth.profile!,
          '901',
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      final profile = AccountProfile(h.auth.profile!.role, {
        ...h.auth.profile!.values,
        'can_prescribe': '0',
      });
      final before = h.previewReads.length;
      await expectLater(
        repository.load(h.auth.session!, profile, '900', isCurrent: () => true),
        throwsA(isA<AppFailure>()),
      );
      expect(h.previewReads.length, before);
    });
    test(
      'stale success and stale failure never reach another account',
      () async {
        for (final fail in [false, true]) {
          var current = true;
          h.pendingPreview = Completer<JsonMap>();
          final future = repository.load(
            h.auth.session!,
            h.auth.profile!,
            '900',
            isCurrent: () => current,
          );
          final check = expectLater(future, throwsA(isA<ObsoleteRequest>()));
          current = false;
          if (fail) {
            h.pendingPreview!.completeError(const AppFailure('old failure'));
          } else {
            h.pendingPreview!.complete(previewFixture());
          }
          await check;
        }
      },
    );
  });
}

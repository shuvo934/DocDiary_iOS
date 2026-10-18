import 'dart:convert';
import 'dart:typed_data';

import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/profile/doctor_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_support.dart';
import 'support.dart';

DoctorProfileRepository _repo(Harness h) =>
    DoctorProfileRepository(h.transport, now: () => h.now);
Future<DoctorProfileDetails> _load(
  Harness h, {
  AccountProfile? profile,
  bool Function()? current,
}) => _repo(h).load(
  h.auth.session!,
  profile ?? h.auth.profile!,
  isCurrent: current ?? () => true,
);
Future<void> _upload(
  Harness h, {
  AccountProfile? profile,
  Uint8List? bytes,
  bool Function()? current,
  bool Function()? foreground,
}) => _repo(h).upload(
  h.auth.session!,
  profile ?? h.auth.profile!,
  bytes ?? profileJpeg(),
  isCurrent: current ?? () => true,
  isForeground: foreground ?? () => true,
);

void main() {
  test(
    'Profile GET uses doctor id, exact endpoint and no login writes',
    () async {
      final h = profileHarness();
      await h.signIn();
      final posts = h.posts.length;
      final data = await _load(h);
      final request = h.transport.requests.last;
      expect(request.method, 'GET');
      expect(
        request.uri.toString(),
        'https://centre.example/api/doc_profile/getDocProfile?doc_id=10',
      );
      expect(request.headers, isEmpty);
      expect(data.value('doc_village'), 'Example Road');
      expect(data.value('doc_phone'), '');
      expect(data.value('doc_dd_id'), '12');
      expect(h.posts.length, posts);
    },
  );
  test(
    'encoded ORDS rows and native last-row semantics preserve fields and picture bytes',
    () async {
      final h = profileHarness();
      await h.signIn();
      final jpeg = profileJpeg();
      h.transport.onGet =
          (_) async => {
            'count': 2,
            'items': jsonEncode([
              profileDetails(street: 'First'),
              {
                ...profileDetails(street: 'Last'),
                'doc_profile_pic': '\n${base64Encode(jpeg)}\n',
              },
            ]),
          };
      final data = await _load(h);
      expect(data.value('doc_village'), 'Last');
      expect(data.picture, jpeg);
    },
  );
  test(
    'count zero and malformed image use native empty fields and placeholder behavior',
    () async {
      final h = profileHarness();
      await h.signIn();
      h.transport.onGet = (_) async => {'count': 0, 'items': null};
      final empty = await _load(h);
      expect(empty.values, isEmpty);
      expect(empty.picture, isNull);
      h.transport.onGet =
          (_) async => {
            'count': 1,
            'items': [
              {...profileDetails(), 'doc_profile_pic': 'invalid%image'},
            ],
          };
      expect((await _load(h)).picture, isNull);
    },
  );
  test(
    'incomplete responses remain retryable instead of manufacturing doctor data',
    () async {
      final h = profileHarness();
      await h.signIn();
      for (final response in <Map<String, Object?>>[
        {},
        {'count': 1, 'items': null},
        {
          'count': 1,
          'items': [<String, Object?>{}],
        },
        {'count': 1, 'items': 'invalid json'},
      ]) {
        h.transport.onGet = (_) async => response;
        await expectLater(_load(h), throwsA(isA<AppFailure>()));
      }
    },
  );
  test(
    'admin, cross-doctor and expired doctor cannot read or upload',
    () async {
      final h = profileHarness();
      await h.signIn();
      for (final profile in [
        AccountProfile(AccountRole.admin, adminProfile()),
        AccountProfile(AccountRole.doctor, {
          ...h.doctorData,
          'doc_code': 'D-OTHER',
        }),
        AccountProfile(AccountRole.doctor, {
          ...h.doctorData,
          'exp_date': '01-JAN-20',
        }),
      ]) {
        final reads = h.transport.requests.length;
        await expectLater(
          _load(h, profile: profile),
          throwsA(isA<AppFailure>()),
        );
        await expectLater(
          _upload(h, profile: profile),
          throwsA(isA<AppFailure>()),
        );
        expect(h.transport.requests.length, reads);
      }
      expect(h.transport.binaryRequests, isEmpty);
    },
  );
  test(
    'late Profile response cannot be committed to another account',
    () async {
      final h = profileHarness();
      await h.signIn();
      var current = true;
      h.transport.onGet = (_) async {
        current = false;
        return {
          'count': 1,
          'items': [profileDetails()],
        };
      };
      await expectLater(
        _load(h, current: () => current),
        throwsA(isA<ObsoleteRequest>()),
      );
    },
  );
  test(
    'doctor image uses native updateImage, p_doc_id and raw application/binary JPEG',
    () async {
      final h = profileHarness();
      await h.signIn();
      final bytes = profileJpeg();
      final posts = h.posts.length;
      await _upload(h, bytes: bytes);
      final request = h.transport.binaryRequests.single;
      expect(
        request.uri.toString(),
        'https://centre.example/api/doc_profile/updateImage',
      );
      expect(request.headers, {'p_doc_id': '10'});
      expect(request.body, bytes);
      expect(request.contentType, 'application/binary');
      expect(h.posts.length, posts);
      final flag = h.transport.requests.last;
      expect(flag.uri.path, endsWith('/doc_dashboard/getDocFLFlag'));
      expect(flag.uri.queryParameters, {'p_doc_id': '10'});
    },
  );
  test(
    'forced logout or missing preflight flag sends no doctor picture bytes',
    () async {
      final h = profileHarness();
      await h.signIn();
      for (final flag in <Map<String, Object?>>[
        {'count': 0, 'items': null},
        {
          'items': [
            {'fl_flag': '1'},
          ],
        },
        {
          'items': [
            {'fl_flag': 'unknown'},
          ],
        },
      ]) {
        h.transport.onGet = (_) async => flag;
        await expectLater(_upload(h), throwsA(isA<AppFailure>()));
      }
      expect(h.transport.binaryRequests, isEmpty);
    },
  );
  test(
    'invalid and oversized JPEG are rejected before network preflight',
    () async {
      final h = profileHarness();
      await h.signIn();
      final before = h.transport.requests.length;
      for (final bytes in [
        Uint8List(0),
        Uint8List.fromList([1, 2, 3, 4]),
        Uint8List(1024 * 1024 + 1),
      ]) {
        await expectLater(_upload(h, bytes: bytes), throwsA(isA<AppFailure>()));
      }
      expect(h.transport.requests.length, before);
      expect(h.transport.binaryRequests, isEmpty);
    },
  );
  test(
    'network and server rejection never automatically retry a POST',
    () async {
      final h = profileHarness();
      await h.signIn();
      h.transport.onBytes = (_) async => {'string_out': 'Storage full'};
      await expectLater(
        _upload(h),
        throwsA(
          isA<AppFailure>().having((e) => e.message, 'message', 'Storage full'),
        ),
      );
      h.transport.onBytes =
          (_) async => throw const AppFailure('Network interrupted');
      await expectLater(_upload(h), throwsA(isA<AppFailure>()));
      expect(h.transport.binaryRequests, hasLength(2));
    },
  );
  test(
    'background or changed account during preflight prevents dispatch',
    () async {
      for (final obsolete in [true, false]) {
        final h = profileHarness();
        await h.signIn();
        var current = true, foreground = true;
        h.transport.onGet = (_) async {
          if (obsolete) {
            current = false;
          } else {
            foreground = false;
          }
          return {
            'items': [
              {'fl_flag': '0'},
            ],
          };
        };
        await expectLater(
          _upload(h, current: () => current, foreground: () => foreground),
          throwsA(isA<ObsoleteRequest>()),
        );
        expect(h.transport.binaryRequests, isEmpty);
      }
    },
  );
  test(
    'a dispatched success in background completes once without another POST',
    () async {
      final h = profileHarness();
      await h.signIn();
      var foreground = true;
      h.transport.onBytes = (_) async {
        foreground = false;
        return {'string_out': 'Successfully Created'};
      };
      await _upload(h, foreground: () => foreground);
      expect(h.transport.binaryRequests, hasLength(1));
    },
  );
}

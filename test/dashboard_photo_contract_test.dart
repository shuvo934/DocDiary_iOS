import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/transport.dart';
import 'package:docdiary_ios/features/auth/account_access.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_photo_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import 'support.dart';

Uint8List _jpeg() => image.encodeJpg(image.Image(width: 12, height: 8));

Future<Harness> _admin() async {
  final h = Harness();
  h.loginResponse = adminLogin();
  h.adminData['usr_id'] = '70';
  await h.signIn();
  return h;
}

Future<void> _upload(
  Harness h, {
  AccountProfile? profile,
  Uint8List? jpeg,
  bool Function()? current,
  bool Function()? foreground,
}) async {
  await DashboardPhotoRepository(h.transport, now: () => h.now).upload(
    h.auth.session!,
    profile ?? h.auth.profile!,
    jpeg ?? _jpeg(),
    isCurrent: current ?? () => true,
    isForeground: foreground ?? () => true,
  );
}

void main() {
  test(
    'admin upload preserves native endpoint, p_user_id and raw JPEG contract',
    () async {
      final h = await _admin();
      final bytes = _jpeg();
      final previousPosts = h.posts.length;
      await _upload(h, jpeg: bytes);
      final request = h.transport.binaryRequests.single;
      expect(
        request.uri.toString(),
        'https://centre.example/api/doc_dashboard/updateAdminPic',
      );
      expect(request.uri.query, isEmpty);
      expect(request.headers, {'p_user_id': '70'});
      expect(request.contentType, 'application/binary');
      expect(request.body, bytes);
      expect(h.posts.length, previousPosts);
    },
  );

  test(
    'server-declared upload failure and network failure never auto retry',
    () async {
      final h = await _admin();
      h.transport.onBytes =
          (_) async => {'string_out': 'Storage temporarily unavailable'};
      await expectLater(
        _upload(h),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            'Storage temporarily unavailable',
          ),
        ),
      );
      expect(h.transport.binaryRequests, hasLength(1));
      h.transport.onBytes =
          (_) async => throw const AppFailure('Network interrupted');
      await expectLater(_upload(h), throwsA(isA<AppFailure>()));
      expect(h.transport.binaryRequests, hasLength(2));
    },
  );

  test('forced logout in upload preflight cannot send picture bytes', () async {
    final h = await _admin();
    h.transport.onGet =
        (uri) async =>
            uri.path.endsWith('getAdminFLFlag')
                ? {
                  'items': [
                    {'fl_flag': '1'},
                  ],
                }
                : await h.defaultGet(uri);
    await expectLater(_upload(h), throwsA(isA<AccountAccessFailure>()));
    expect(h.transport.binaryRequests, isEmpty);
  });

  test('missing forced-logout flag cannot approve an upload', () async {
    final h = await _admin();
    h.transport.onGet = (_) async => {'count': 0};
    await expectLater(_upload(h), throwsA(isA<AppFailure>()));
    expect(h.transport.binaryRequests, isEmpty);
  });

  test('doctor and expired admin cannot enter a binary upload', () async {
    final h = Harness();
    await h.signIn();
    await expectLater(_upload(h), throwsA(isA<AppFailure>()));
    expect(h.transport.binaryRequests, isEmpty);
    final admin = await _admin();
    final expired = Map<String, Object?>.of(admin.adminData)
      ..['exp_date'] = '01-JAN-20';
    await expectLater(
      _upload(admin, profile: AccountProfile(AccountRole.admin, expired)),
      throwsA(isA<AccountAccessFailure>()),
    );
    expect(admin.transport.binaryRequests, isEmpty);
  });

  test('invalid or oversized image cannot reach the upload endpoint', () async {
    final h = await _admin();
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList([1, 2, 3, 4]),
      Uint8List(1024 * 1024 + 1),
    ]) {
      await expectLater(_upload(h, jpeg: bytes), throwsA(isA<AppFailure>()));
    }
    expect(h.transport.binaryRequests, isEmpty);
  });

  test(
    'background or changed account during GET preflight sends no POST',
    () async {
      for (final obsolete in [false, true]) {
        final h = await _admin();
        var current = true;
        var foreground = true;
        h.transport.onGet = (uri) async {
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
    'a dispatched success in background is returned once without resending',
    () async {
      final h = await _admin();
      var foreground = true;
      h.transport.onBytes = (_) async {
        foreground = false;
        return {'string_out': 'Successfully Created'};
      };
      await _upload(h, foreground: () => foreground);
      expect(h.transport.binaryRequests, hasLength(1));
    },
  );

  test(
    'resize keeps aspect ratio, matches native upscaling and strips EXIF',
    () {
      final original = image.Image(width: 30, height: 20);
      original.exif.imageIfd.make = 'Example';
      final bytes = prepareDashboardJpeg(image.encodeJpg(original));
      final result = image.decodeJpg(bytes)!;
      expect((result.width, result.height), (1080, 720));
      expect(result.exif.imageIfd.make, isNull);
      expect(bytes.length, lessThanOrEqualTo(1024 * 1024));
    },
  );

  test(
    'camera still bakes orientation and mirrors front photo before preview',
    () {
      final original = image.Image(width: 40, height: 20);
      image.fillRect(
        original,
        x1: 0,
        y1: 0,
        x2: 19,
        y2: 19,
        color: image.ColorRgb8(255, 0, 0),
      );
      image.fillRect(
        original,
        x1: 20,
        y1: 0,
        x2: 39,
        y2: 19,
        color: image.ColorRgb8(0, 0, 255),
      );
      final bytes = image.encodeJpg(original, quality: 100);
      final normal =
          image.decodeJpg(
            orientDashboardCapture((bytes: bytes, mirror: false)),
          )!;
      final mirrored =
          image.decodeJpg(
            orientDashboardCapture((bytes: bytes, mirror: true)),
          )!;
      expect(normal.getPixel(5, 10).r, greaterThan(240));
      expect(mirrored.getPixel(5, 10).b, greaterThan(240));
      original.exif.imageIfd.orientation = 6;
      final rotated =
          image.decodeJpg(
            orientDashboardCapture((
              bytes: image.encodeJpg(original),
              mirror: false,
            )),
          )!;
      expect((rotated.width, rotated.height), (20, 40));
      expect(rotated.exif.imageIfd.orientation, isNull);
    },
  );

  test(
    'detailed photos are recompressed within the binary upload size limit',
    () {
      final random = math.Random(42);
      final pixels = image.Image(width: 1080, height: 1080);
      for (final pixel in pixels) {
        pixel.setRgb(
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
      }
      final original = image.encodeJpg(pixels, quality: 100);
      expect(original.length, greaterThan(1024 * 1024));
      final compressed = prepareDashboardJpeg(original);
      expect(compressed.length, lessThanOrEqualTo(1024 * 1024));
      final result = image.decodeJpg(compressed)!;
      expect((result.width, result.height), (1080, 1080));
    },
  );

  test('unreadable input fails before a JPEG can be uploaded', () {
    expect(
      () => prepareDashboardJpeg(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<AppFailure>()),
    );
  });

  test(
    'IoTransport sends bytes as application/binary with no form or base64 envelope',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final transport = IoTransport();
      addTearDown(transport.close);
      addTearDown(() async => await server.close(force: true));
      final requestFuture = server.first;
      final bytes = _jpeg();
      final response = transport.postBytes(
        Uri.parse('http://127.0.0.1:${server.port}/updateAdminPic'),
        bytes,
        headers: {'p_user_id': '70'},
      );
      final request = await requestFuture;
      expect(request.method, 'POST');
      expect(request.headers.value('p_user_id'), '70');
      expect(request.headers.contentType!.mimeType, 'application/binary');
      final received = await request.fold<List<int>>(
        <int>[],
        (buffer, chunk) => buffer..addAll(chunk),
      );
      expect(received, bytes);
      request.response.write(
        jsonEncode({'string_out': 'Successfully Created'}),
      );
      await request.response.close();
      expect(await response, {'string_out': 'Successfully Created'});
    },
  );
}

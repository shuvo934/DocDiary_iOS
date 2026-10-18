import 'dart:async';
import 'dart:convert';

import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/features/auth/login_screen.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_services.dart';
import 'package:docdiary_ios/features/dashboard/native_dashboard_layout.dart';
import 'package:docdiary_ios/features/profile/doctor_profile_repository.dart';
import 'package:docdiary_ios/features/profile/doctor_profile_screen.dart';
import 'package:docdiary_ios/features/profile/native_doctor_profile_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_support.dart';
import 'support.dart';

class _Media implements DashboardPhotoMedia {
  Uint8List? bytes = profileJpeg();
  final sources = <DashboardPhotoSource>[];
  Future<Uint8List?> Function()? action;
  @override
  Future<Uint8List?> select(
    DashboardPhotoSource source, {
    required Future<String?> Function() capture,
    required Future<bool> Function() ready,
  }) async {
    sources.add(source);
    return action == null ? bytes : await action!();
  }
}

Future<void> _show(
  WidgetTester tester,
  Harness h,
  _Media media, {
  Size size = const Size(393, 852),
  double scale = 1,
  Future<bool> Function(Uri)? video,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await h.signIn();
  await tester.pumpWidget(
    DocDiaryApp(
      auth: h.auth,
      dashboard: DashboardRepository(h.transport, now: () => h.now),
      initializeOnStart: false,
      dashboardServices: DashboardServices(
        media: media,
        destinationBuilder:
            video == null
                ? null
                : (context, route) => DoctorProfileScreen(
                  auth: h.auth,
                  repository: DoctorProfileRepository(
                    h.transport,
                    now: () => h.now,
                  ),
                  media: media,
                  openVideo: video,
                ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _tap(tester, 'dashboard_nav_profile');
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _gallery(WidgetTester tester) async {
  await _tap(tester, 'profile_change_photo');
  await _tap(tester, 'dashboard_photo_gallery');
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry
        in {
          'Poppins': [
            'Poppins-Regular.ttf',
            'Poppins-Medium.ttf',
            'Poppins-Bold.ttf',
          ],
          'Baloo': ['Baloo-Regular.ttf'],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
        }.entries) {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }
  });
  testWidgets(
    'auth removed before Profile construction recovers without dereferencing stale session data',
    (tester) async {
      final h = profileHarness();
      await h.signIn();
      await h.auth.logout();
      final reads = h.transport.requests.length;
      await tester.pumpWidget(
        MaterialApp(
          home: DoctorProfileScreen(
            auth: h.auth,
            repository: DoctorProfileRepository(h.transport, now: () => h.now),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Could Not Get Doctor Data. Please return to Login.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(h.transport.requests.length, reads);
      await _finish(tester);
      h.auth.dispose();
    },
  );
  testWidgets(
    'default dashboard Profile route renders native identity, address and contact without login writes',
    (tester) async {
      final h = profileHarness();
      final media = _Media();
      await _show(tester, h, media);
      expect(find.byType(DoctorProfileScreen), findsOneWidget);
      expect(find.text('Example Therapist'), findsOneWidget);
      expect(find.text('(D-10)'), findsOneWidget);
      expect(find.text('Consultant'), findsOneWidget);
      expect(find.text('Physiotherapy'), findsOneWidget);
      expect(find.text('Musculoskeletal Unit'), findsOneWidget);
      expect(find.text('Example Road'), findsOneWidget);
      expect(find.text('Address:'), findsOneWidget);
      expect(find.byKey(const Key('profile_video')), findsNothing);
      expect(find.byKey(const Key('profile_edit_address')), findsOneWidget);
      expect(
        h.posts.where((r) => r.uri.path.endsWith('loginLog')),
        hasLength(1),
      );
      expect(h.transport.binaryRequests, isEmpty);
      await _finish(tester);
    },
  );
  testWidgets(
    'unreadable saved image falls back to doctor asset without a render error',
    (tester) async {
      final h = profileHarness();
      h.transport.onGet =
          (uri) async =>
              uri.path.endsWith('getDocProfile')
                  ? {
                    'count': 1,
                    'items': [
                      {
                        ...profileDetails(),
                        'doc_profile_pic': base64Encode([1, 2, 3, 4]),
                      },
                    ],
                  }
                  : await h.defaultGet(uri);
      await _show(tester, h, _Media());
      expect(find.text('Example Road'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    },
  );
  testWidgets(
    'Profile Back refreshes dashboard Today without adding login POST',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h, _Media());
      final posts = h.posts.length;
      final reads = h.transport.requests.length;
      await _tap(tester, 'profile_back');
      expect(find.byType(NativeDashboardLayout), findsOneWidget);
      expect(h.posts.length, posts);
      expect(h.transport.requests.length, greaterThan(reads));
      await _finish(tester);
    },
  );
  testWidgets(
    'native load error blocks outside/Back and Retry reloads actual Profile',
    (tester) async {
      final h = profileHarness();
      var failed = false;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getDocProfile')) {
          if (!failed) {
            failed = true;
            throw const AppFailure('Profile network interrupted');
          }
          return {
            'count': 1,
            'items': [profileDetails()],
          };
        }
        return await h.defaultGet(uri);
      };
      await _show(tester, h, _Media());
      expect(find.text('Error!'), findsOneWidget);
      expect(
        find.textContaining('Profile network interrupted'),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(4, 4));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile_error')), findsOneWidget);
      await _tap(tester, 'profile_error_retry');
      expect(find.text('Example Road'), findsOneWidget);
      await _finish(tester);
    },
  );
  testWidgets(
    'load-error Exit returns to dashboard rather than terminating iOS',
    (tester) async {
      final h = profileHarness();
      h.transport.onGet =
          (uri) async =>
              uri.path.endsWith('getDocProfile')
                  ? throw const AppFailure('Unavailable')
                  : await h.defaultGet(uri);
      await _show(tester, h, _Media());
      await _tap(tester, 'profile_error_exit');
      expect(find.byType(NativeDashboardLayout), findsOneWidget);
      await _finish(tester);
    },
  );
  testWidgets(
    'photo chooser Close and gallery cancel preserve old photo and send no POST',
    (tester) async {
      final h = profileHarness();
      final media = _Media()..bytes = null;
      await _show(tester, h, media);
      await _tap(tester, 'profile_change_photo');
      expect(find.text('Upload Picture via'), findsOneWidget);
      await _tap(tester, 'dashboard_photo_close');
      expect(media.sources, isEmpty);
      await _gallery(tester);
      expect(media.sources, [DashboardPhotoSource.gallery]);
      expect(h.transport.binaryRequests, isEmpty);
      await _finish(tester);
    },
  );
  testWidgets(
    'doctor gallery success commits picture with native endpoint and no extra login writes',
    (tester) async {
      final h = profileHarness();
      final media = _Media();
      await _show(tester, h, media);
      final posts = h.posts.length;
      await _gallery(tester);
      expect(
        h.transport.binaryRequests.single.uri.path,
        endsWith('/doc_profile/updateImage'),
      );
      expect(
        tester
            .widget<NativeDoctorProfileLayout>(
              find.byType(NativeDoctorProfileLayout),
            )
            .details!
            .picture,
        media.bytes,
      );
      expect(find.text('Picture Uploaded'), findsOneWidget);
      expect(h.posts.length, posts);
      await _finish(tester);
    },
  );
  testWidgets('upload Retry sends the same bytes only after explicit tap', (
    tester,
  ) async {
    final h = profileHarness();
    final media = _Media();
    var calls = 0;
    h.transport.onBytes =
        (_) async => {
          'string_out': ++calls == 1 ? 'Storage full' : 'Successfully Created',
        };
    await _show(tester, h, media);
    await _gallery(tester);
    expect(find.byKey(const Key('dashboard_photo_error')), findsOneWidget);
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 1);
    await _tap(tester, 'dashboard_photo_retry');
    expect(calls, 2);
    expect(
      h.transport.binaryRequests[0].body,
      h.transport.binaryRequests[1].body,
    );
    expect(find.text('Picture Uploaded'), findsOneWidget);
    await _finish(tester);
  });
  testWidgets(
    'upload Cancel keeps previous picture and selects Camera source correctly',
    (tester) async {
      final h = profileHarness();
      final media = _Media();
      h.transport.onBytes =
          (_) async => throw const AppFailure('Connection lost');
      await _show(tester, h, media);
      await _tap(tester, 'profile_change_photo');
      await _tap(tester, 'dashboard_photo_camera');
      expect(media.sources, [DashboardPhotoSource.camera]);
      await _tap(tester, 'dashboard_photo_cancel');
      expect(
        tester
            .widget<NativeDoctorProfileLayout>(
              find.byType(NativeDoctorProfileLayout),
            )
            .details!
            .picture,
        isNull,
      );
      expect(h.transport.binaryRequests, hasLength(1));
      await _finish(tester);
    },
  );
  testWidgets('revoked mobile access before upload blocks without image POST', (
    tester,
  ) async {
    final h = profileHarness();
    final media = _Media();
    await _show(tester, h, media);
    h.doctorData['access_flag'] = '0';
    await _gallery(tester);
    expect(find.text('Access Denied!'), findsOneWidget);
    expect(find.byType(DoctorProfileScreen), findsNothing);
    expect(h.transport.binaryRequests, isEmpty);
    await _finish(tester);
  });
  testWidgets(
    'logout during pending picker cannot upload or retain old Profile route',
    (tester) async {
      final h = profileHarness();
      final pending = Completer<Uint8List?>();
      final media = _Media()..action = () => pending.future;
      await _show(tester, h, media);
      await _tap(tester, 'profile_change_photo');
      await tester.tap(find.byKey(const Key('dashboard_photo_gallery')));
      await tester.pump(const Duration(milliseconds: 400));
      await h.auth.logout();
      await tester.pumpAndSettle();
      pending.complete(profileJpeg());
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(h.transport.binaryRequests, isEmpty);
      await _finish(tester);
    },
  );
  testWidgets('photo completed while background waits for resume before POST', (
    tester,
  ) async {
    final h = profileHarness();
    final pending = Completer<Uint8List?>();
    final media = _Media()..action = () => pending.future;
    await _show(tester, h, media);
    await _tap(tester, 'profile_change_photo');
    await tester.tap(find.byKey(const Key('dashboard_photo_gallery')));
    await tester.pump(const Duration(milliseconds: 400));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    pending.complete(profileJpeg());
    await tester.pump();
    await tester.pump();
    expect(h.transport.binaryRequests, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(h.transport.binaryRequests, hasLength(1));
    await _finish(tester);
  });
  testWidgets(
    'successful POST received in background is never uploaded again on resume',
    (tester) async {
      final h = profileHarness();
      final media = _Media();
      final pending = Completer<Map<String, Object?>>();
      h.transport.onBytes = (_) async {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        return pending.future;
      };
      await _show(tester, h, media);
      await _tap(tester, 'profile_change_photo');
      await tester.tap(find.byKey(const Key('dashboard_photo_gallery')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(h.transport.binaryRequests, hasLength(1));
      pending.complete({'string_out': 'Successfully Created'});
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(h.transport.binaryRequests, hasLength(1));
      expect(find.text('Picture Uploaded'), findsOneWidget);
      await _finish(tester);
    },
  );
  testWidgets(
    'video flag, blank/unsafe links and valid external launch follow native visibility',
    (tester) async {
      final h = profileHarness();
      h.doctorData['doc_video_link_enable_flag'] = '1';
      final urls = <Uri>[];
      await _show(
        tester,
        h,
        _Media(),
        video: (uri) async {
          urls.add(uri);
          return true;
        },
      );
      await _tap(tester, 'profile_video');
      expect(find.text('Video call is not available yet'), findsOneWidget);
      expect(urls, isEmpty);
      await _finish(tester);
      final valid = profileHarness();
      valid.doctorData.addAll({
        'doc_video_link_enable_flag': '1',
        'doc_video_link': 'https://video.example.invalid/doctor10',
      });
      await _show(
        tester,
        valid,
        _Media(),
        video: (uri) async {
          urls.add(uri);
          return true;
        },
      );
      await _tap(tester, 'profile_video');
      expect(urls.single.toString(), 'https://video.example.invalid/doctor10');
      await _finish(tester);
      final invalid = profileHarness();
      invalid.doctorData.addAll({
        'doc_video_link_enable_flag': '1',
        'doc_video_link': 'javascript:alert(1)',
      });
      await _show(
        tester,
        invalid,
        _Media(),
        video: (uri) async {
          urls.add(uri);
          return true;
        },
      );
      await _tap(tester, 'profile_video');
      expect(urls, hasLength(1));
      expect(find.textContaining('Video call link is invalid'), findsOneWidget);
      await _finish(tester);
    },
  );
  testWidgets(
    'next-step Address and Password entry points are explicit and cannot fake saved data',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h, _Media());
      final posts = h.posts.length;
      await _tap(tester, 'profile_password');
      expect(find.text('Change Password'), findsOneWidget);
      expect(
        find.text('This screen is not available in this development build.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await _tap(tester, 'profile_edit_address');
      expect(find.text('Update Address'), findsOneWidget);
      expect(h.posts.length, posts);
      await _finish(tester);
    },
  );
  testWidgets(
    'small screens, large system text and long contact values do not overflow',
    (tester) async {
      for (final size in [const Size(320, 640), const Size(393, 852)]) {
        final h = profileHarness();
        h.doctorData['doc_center_name'] = '';
        h.transport.onGet =
            (uri) async =>
                uri.path.endsWith('getDocProfile')
                    ? {
                      'count': 1,
                      'items': [
                        {
                          ...profileDetails(
                            street:
                                'A very long address including road, village and locality',
                          ),
                          'doc_email':
                              'a.very.long.doctor.address@example.invalid',
                        },
                      ],
                    }
                    : await h.defaultGet(uri);
        await _show(tester, h, _Media(), size: size, scale: 2);
        expect(find.byKey(const Key('profile_center')), findsNothing);
        await tester.ensureVisible(find.byKey(const Key('profile_email')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _finish(tester);
      }
    },
  );
  testWidgets(
    'pause invalidates an old read and resume displays only the newest data',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h, _Media());
      final old = Completer<Map<String, Object?>>();
      var reads = 0;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getDocProfile')) {
          reads++;
          return reads == 1
              ? old.future
              : {
                'count': 1,
                'items': [profileDetails(street: 'Current address')],
              };
        }
        return await h.defaultGet(uri);
      };
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      old.complete({
        'count': 1,
        'items': [profileDetails(street: 'Obsolete address')],
      });
      await tester.pumpAndSettle();
      expect(find.text('Current address'), findsOneWidget);
      expect(find.text('Obsolete address'), findsNothing);
      await _finish(tester);
    },
  );
}

import 'dart:async';
import 'dart:typed_data';

import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_dates.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/login_screen.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_services.dart';
import 'package:docdiary_ios/features/dashboard/native_dashboard_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import 'support.dart';

class _Media implements DashboardPhotoMedia {
  int calls = 0;
  final sources = <DashboardPhotoSource>[];
  Uint8List? bytes = image.encodeJpg(image.Image(width: 24, height: 16));
  Future<Uint8List?> Function()? onSelect;
  @override
  Future<Uint8List?> select(
    DashboardPhotoSource source, {
    required Future<String?> Function() capture,
    required Future<bool> Function() ready,
  }) async {
    calls++;
    sources.add(source);
    return onSelect == null ? bytes : await onSelect!();
  }
}

class _Review implements DashboardReview {
  int calls = 0;
  bool fail = false;
  @override
  Future<void> request() async {
    calls++;
    if (fail) {
      throw const AppFailure('Review unavailable');
    }
  }
}

Future<void> _show(
  WidgetTester tester,
  Harness h,
  _Media media,
  _Review review, {
  bool admin = true,
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  if (admin) {
    h.loginResponse = adminLogin();
  }
  await h.signIn();
  await tester.pumpWidget(
    DocDiaryApp(
      auth: h.auth,
      dashboard: DashboardRepository(h.transport, now: () => h.now),
      initializeOnStart: false,
      dashboardServices: DashboardServices(media: media, review: review),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _tap(WidgetTester tester, String key, {bool settle = true}) async {
  await tester.tap(find.byKey(Key(key)));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}

Future<void> _gallery(WidgetTester tester, {bool settle = true}) async {
  await _tap(tester, 'dashboard_change_photo');
  await _tap(tester, 'dashboard_photo_gallery', settle: settle);
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
    'native photo chooser is admin-only and Close performs no media or upload work',
    (tester) async {
      final h = Harness();
      final media = _Media();
      final review = _Review();
      await _show(tester, h, media, review);
      await _tap(tester, 'dashboard_change_photo');
      expect(find.text('Upload Picture via'), findsOneWidget);
      expect(find.text('CAMERA'), findsOneWidget);
      expect(find.text('GALLERY'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Upload Picture via'), findsOneWidget);
      await _tap(tester, 'dashboard_photo_close');
      expect(media.calls, 0);
      expect(h.transport.binaryRequests, isEmpty);
      await _finish(tester);
      final doctor = Harness();
      await _show(tester, doctor, _Media(), _Review(), admin: false);
      expect(find.byKey(const Key('dashboard_change_photo')), findsNothing);
      await _finish(tester);
    },
  );

  testWidgets(
    'gallery cancel preserves selected summary period and makes no chart reload or POST',
    (tester) async {
      final h = Harness();
      final media = _Media()..bytes = null;
      await _show(tester, h, media, _Review());
      await _tap(tester, 'dashboard_period_currentWeek');
      final reads = h.transport.requests.length;
      await _gallery(tester);
      expect(
        tester
            .widget<NativeDashboardLayout>(find.byType(NativeDashboardLayout))
            .period,
        SummaryPeriod.currentWeek,
      );
      expect(h.transport.requests.length, reads);
      expect(h.transport.binaryRequests, isEmpty);
      await _finish(tester);
    },
  );

  testWidgets(
    'successful gallery upload updates avatar, keeps charts and adds no login mutations',
    (tester) async {
      final h = Harness();
      final media = _Media();
      await _show(tester, h, media, _Review());
      final writes = h.posts.length;
      final charts =
          h.transport.requests
              .where((r) => r.uri.path.contains('Monthly'))
              .length;
      await _gallery(tester);
      expect(media.sources, [DashboardPhotoSource.gallery]);
      expect(h.transport.binaryRequests, hasLength(1));
      expect(h.transport.binaryRequests.single.body, media.bytes);
      expect(
        tester
            .widget<NativeDashboardLayout>(find.byType(NativeDashboardLayout))
            .picture,
        media.bytes,
      );
      expect(find.text('Picture Uploaded'), findsOneWidget);
      expect(h.posts.length, writes);
      expect(
        h.transport.requests
            .where((r) => r.uri.path.contains('Monthly'))
            .length,
        charts,
      );
      await _finish(tester);
    },
  );

  testWidgets(
    'upload failure waits for manual Retry and reuses bytes without selecting again',
    (tester) async {
      final h = Harness();
      final media = _Media();
      var fail = true;
      h.transport.onBytes =
          (_) async =>
              fail
                  ? throw const AppFailure('Upload unavailable')
                  : {'string_out': 'Successfully Created'};
      await _show(tester, h, media, _Review());
      await _gallery(tester);
      expect(find.textContaining('Upload unavailable'), findsOneWidget);
      expect(h.transport.binaryRequests, hasLength(1));
      expect(
        tester
            .widget<NativeDashboardLayout>(find.byType(NativeDashboardLayout))
            .picture,
        isNull,
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(h.transport.binaryRequests, hasLength(1));
      fail = false;
      await _tap(tester, 'dashboard_photo_retry');
      expect(media.calls, 1);
      expect(h.transport.binaryRequests, hasLength(2));
      expect(
        h.transport.binaryRequests[0].body,
        h.transport.binaryRequests[1].body,
      );
      expect(find.text('Picture Uploaded'), findsOneWidget);
      await _finish(tester);
    },
  );

  testWidgets(
    'upload Cancel preserves previous avatar and sends no extra POST',
    (tester) async {
      final h = Harness();
      final media = _Media();
      h.transport.onBytes = (_) async => throw const AppFailure('Offline');
      await _show(tester, h, media, _Review());
      await _gallery(tester);
      await _tap(tester, 'dashboard_photo_cancel');
      expect(h.transport.binaryRequests, hasLength(1));
      expect(
        tester
            .widget<NativeDashboardLayout>(find.byType(NativeDashboardLayout))
            .picture,
        isNull,
      );
      expect(find.text('Picture Uploaded'), findsNothing);
      await _finish(tester);
    },
  );

  testWidgets(
    'upload preflight sees revoked access before any picture is sent',
    (tester) async {
      final h = Harness();
      final media = _Media();
      await _show(tester, h, media, _Review());
      h.adminData['usr_mob_app_access'] = '0';
      await _gallery(tester);
      expect(find.text('Access Denied!'), findsOneWidget);
      expect(h.transport.binaryRequests, isEmpty);
      expect(h.auth.stage, AuthStage.accountBlocked);
      await _tap(tester, 'dashboard_message_ok');
      expect(find.byType(LoginScreen), findsOneWidget);
      await _finish(tester);
    },
  );

  testWidgets(
    'camera selection dispatches the camera source rather than gallery',
    (tester) async {
      final h = Harness();
      final media = _Media()..bytes = null;
      await _show(tester, h, media, _Review());
      await _tap(tester, 'dashboard_change_photo');
      await _tap(tester, 'dashboard_photo_camera');
      expect(media.sources, [DashboardPhotoSource.camera]);
      expect(h.transport.binaryRequests, isEmpty);
      await _finish(tester);
    },
  );

  testWidgets(
    'returning from media waits for resume and does not start competing chart requests',
    (tester) async {
      final h = Harness();
      final media = _Media();
      final pending = Completer<Uint8List?>();
      media.onSelect = () async => pending.future;
      await _show(tester, h, media, _Review());
      final charts =
          h.transport.requests
              .where((r) => r.uri.path.contains('Monthly'))
              .length;
      await _gallery(tester, settle: false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      pending.complete(media.bytes);
      await tester.pump();
      expect(h.transport.binaryRequests, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(h.transport.binaryRequests, hasLength(1));
      expect(
        h.transport.requests
            .where((r) => r.uri.path.contains('Monthly'))
            .length,
        charts,
      );
      expect(find.text('Picture Uploaded'), findsOneWidget);
      await _finish(tester);
    },
  );

  testWidgets(
    'successful POST completed in background is not repeated on resume',
    (tester) async {
      final h = Harness();
      final media = _Media();
      final pending = Completer<JsonMap>();
      h.transport.onBytes = (_) async => pending.future;
      await _show(tester, h, media, _Review());
      await _gallery(tester, settle: false);
      expect(h.transport.binaryRequests, hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      pending.complete({'string_out': 'Successfully Created'});
      await tester.pump();
      expect(find.text('Picture Uploaded'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(h.transport.binaryRequests, hasLength(1));
      expect(find.text('Picture Uploaded'), findsOneWidget);
      await _finish(tester);
    },
  );

  testWidgets(
    'logout while media is pending cannot upload or show old-account success',
    (tester) async {
      final h = Harness();
      final media = _Media();
      final pending = Completer<Uint8List?>();
      media.onSelect = () async => pending.future;
      await _show(tester, h, media, _Review());
      await _gallery(tester, settle: false);
      await h.auth.logout();
      await tester.pumpAndSettle();
      pending.complete(media.bytes);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(h.transport.binaryRequests, isEmpty);
      expect(find.text('Picture Uploaded'), findsNothing);
      await _finish(tester);
    },
  );

  testWidgets('Retry rechecks mobile permission before a second upload', (
    tester,
  ) async {
    final h = Harness();
    final media = _Media();
    h.transport.onBytes = (_) async => throw const AppFailure('Offline');
    await _show(tester, h, media, _Review());
    await _gallery(tester);
    h.adminData['usr_mob_app_access'] = '0';
    await _tap(tester, 'dashboard_photo_retry');
    expect(h.transport.binaryRequests, hasLength(1));
    expect(find.text('Access Denied!'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets(
    'review is skipped on first load and tab changes, then attempted after resume success',
    (tester) async {
      final h = Harness();
      final review = _Review()..fail = true;
      await _show(tester, h, _Media(), review);
      expect(review.calls, 0);
      await _tap(tester, 'dashboard_period_currentWeek');
      expect(review.calls, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(review.calls, 1);
      expect(h.auth.stage, AuthStage.authenticated);
      expect(find.text('WARNING!'), findsNothing);
      expect(
        tester
            .widget<NativeDashboardLayout>(find.byType(NativeDashboardLayout))
            .summary!
            .values['TOTAL APPOINTMENT'],
        '12',
      );
      await _finish(tester);
    },
  );

  testWidgets('small screen and 2x text photo dialog has no overflow', (
    tester,
  ) async {
    final h = Harness();
    await _show(
      tester,
      h,
      _Media(),
      _Review(),
      size: const Size(320, 640),
      textScale: 2,
    );
    await _tap(tester, 'dashboard_change_photo');
    expect(find.text('Upload Picture via'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, 'dashboard_photo_close');
    await _finish(tester);
  });
}

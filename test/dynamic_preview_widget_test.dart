import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_preview_repository.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_preview_platform.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dynamic_preview_test_support.dart';

Future<void> _fonts() async {
  for (final entry
      in {
        'Poppins': [
          'Poppins-Regular.ttf',
          'Poppins-Medium.ttf',
          'Poppins-SemiBold.ttf',
          'Poppins-Bold.ttf',
        ],
        'Roboto': ['Roboto-Regular.ttf'],
      }.entries) {
    final loader = FontLoader(entry.key);
    for (final name in entry.value) {
      loader.addFont(rootBundle.load('assets/fonts/$name'));
    }
    await loader.load();
  }
}

Future<void> _host(
  WidgetTester tester,
  DynamicPreviewHarness h,
  FakeDynamicPreviewPlatform platform, {
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.runAsync(() => h.signIn());
  h.transport.requests.clear();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: docDiaryTheme(),
      home: Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                key: const Key('open_preview'),
                onPressed:
                    () => unawaited(
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder:
                              (_) => NativeDynamicPreviewScreen(
                                auth: h.auth,
                                repository:
                                    DynamicPrescriptionPreviewRepository(
                                      h.repository,
                                    ),
                                rvmId: '900',
                                platform: platform,
                              ),
                        ),
                      ),
                    ),
                child: const Text('Open'),
              ),
            ),
      ),
    ),
  );
  const htmlImage = String.fromEnvironment('DYNAMIC_PREVIEW_HTML_PNG');
  if (htmlImage.isNotEmpty) {
    await tester.runAsync(
      () => precacheImage(
        FileImage(File(htmlImage)),
        tester.element(find.byType(MaterialApp)),
      ),
    );
  }
  await tester.tap(find.byKey(const Key('open_preview')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(Key('dy_action_$label')));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

bool _enabled(WidgetTester tester, String label) =>
    tester
        .widget<ElevatedButton>(find.byKey(Key('dy_action_$label')))
        .onPressed !=
    null;
Future<void> _capture(WidgetTester tester, String name) async {
  const output = String.fromEnvironment('DYNAMIC_PREVIEW_RENDER_DIR');
  if (output.isEmpty) return;
  const htmlImage = String.fromEnvironment('DYNAMIC_PREVIEW_HTML_PNG');
  if (htmlImage.isNotEmpty) {
    await tester.runAsync(
      () => precacheImage(
        FileImage(File(htmlImage)),
        tester.element(find.byType(NativeDynamicPreviewScreen)),
      ),
    );
  }
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final render = tester.binding.renderViews.first;
    final picture = await (render.debugLayer! as OffsetLayer).toImage(
      Offset.zero & render.size,
      pixelRatio: 3,
    );
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    await Directory(output).create(recursive: true);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}

void main() {
  setUpAll(_fonts);
  late DynamicPreviewHarness h;
  late FakeDynamicPreviewPlatform platform;
  setUp(() {
    h = DynamicPreviewHarness();
    platform = FakeDynamicPreviewPlatform();
  });
  tearDown(() => h.auth.dispose());
  for (final size in [
    const Size(320, 693),
    const Size(393, 852),
    const Size(852, 393),
    const Size(768, 1024),
  ]) {
    testWidgets('native preview chrome and safe-area fit $size', (
      tester,
    ) async {
      await _host(tester, h, platform, size: size);
      await tester.pumpAndSettle();
      expect(find.text('Prescription Preview'), findsOneWidget);
      expect(find.text('Prescription No: 2600900'), findsOneWidget);
      for (final label in ['DOWNLOAD', 'PRINT', 'SHARE']) {
        expect(_enabled(tester, label), isTrue);
      }
      expect(platform.html, contains('Demo Patient'));
      expect(h.posts, isEmpty);
      expect(h.previewReads.length, 1);
      expect(
        tester.getRect(find.byKey(const Key('dy_action_DOWNLOAD'))).bottom,
        lessThanOrEqualTo(size.height - 34),
      );
      expect(tester.takeException(), isNull);
      if (size.width == 393) await _capture(tester, 'preview_ready_iphone');
      await tester.pumpWidget(const SizedBox());
      expect(platform.disposed, isTrue);
    });
  }
  testWidgets(
    'HTTP and native rendering must both finish before document actions',
    (tester) async {
      h.pendingPreview = Completer<JsonMap>();
      platform.autoReady = false;
      await _host(tester, h, platform);
      expect(find.byKey(const Key('dy_preview_progress')), findsOneWidget);
      expect(_enabled(tester, 'DOWNLOAD'), isFalse);
      h.pendingPreview!.complete(previewFixture());
      await tester.pump();
      await tester.pump();
      expect(find.text('Preparing prescription layout...'), findsOneWidget);
      expect(_enabled(tester, 'SHARE'), isFalse);
      platform.ready!();
      await tester.pumpAndSettle();
      expect(_enabled(tester, 'PRINT'), isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'server and renderer errors are retryable and never export stale content',
    (tester) async {
      h.response = {'status': 500, 'message': 'Demo preview unavailable'};
      await _host(tester, h, platform);
      await tester.pumpAndSettle();
      expect(find.text('Demo preview unavailable'), findsOneWidget);
      expect(_enabled(tester, 'DOWNLOAD'), isFalse);
      await _capture(tester, 'preview_error');
      h.response = previewFixture();
      await _tap(tester, 'RETRY');
      expect(_enabled(tester, 'DOWNLOAD'), isTrue);
      platform.fail!('Demo render failed');
      await tester.pumpAndSettle();
      expect(_enabled(tester, 'SHARE'), isFalse);
      expect(find.text('Demo render failed'), findsOneWidget);
      await _tap(tester, 'RETRY');
      expect(_enabled(tester, 'SHARE'), isTrue);
      expect(h.previewReads.length, 3);
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'download print share cancellations keep one preview and allow manual retry',
    (tester) async {
      await _host(tester, h, platform);
      await tester.pumpAndSettle();
      for (final label in ['DOWNLOAD', 'PRINT', 'SHARE']) {
        await _tap(tester, label);
      }
      expect(platform.actions, DynamicPreviewAction.values);
      expect(h.previewReads.length, 1);
      expect(h.posts, isEmpty);
      expect(find.byKey(const Key('dy_preview_action_error')), findsNothing);
      platform.actionError = PlatformException(
        code: 'pdf',
        message: 'Demo PDF failed',
      );
      await _tap(tester, 'DOWNLOAD');
      expect(find.text('Demo PDF failed'), findsOneWidget);
      expect(_enabled(tester, 'SHARE'), isTrue);
      platform.actionError = null;
      await _tap(tester, 'DOWNLOAD');
      expect(find.byKey(const Key('dy_preview_action_error')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'pending document action blocks duplicates/back and survives system inactive',
    (tester) async {
      await _host(tester, h, platform);
      await tester.pumpAndSettle();
      platform.pending = Completer<bool>();
      await tester.tap(find.byKey(const Key('dy_action_DOWNLOAD')));
      await tester.pump();
      expect(_enabled(tester, 'SHARE'), isFalse);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('dy_preview_back')))
            .onPressed,
        isNull,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(platform.suspends, 0);
      expect(find.byType(NativeDynamicPreviewScreen), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      platform.pending!.complete(false);
      await tester.pumpAndSettle();
      expect(_enabled(tester, 'PRINT'), isTrue);
      expect(platform.actions.length, 1);
      expect(h.previewReads.length, 1);
      await tester.tap(find.byKey(const Key('dy_preview_back')));
      await tester.pumpAndSettle();
      expect(find.byType(NativeDynamicPreviewScreen), findsNothing);
    },
  );
  testWidgets('true background suspends export and refreshes on return', (
    tester,
  ) async {
    await _host(tester, h, platform);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(platform.suspends, 1);
    tester
        .widget<ElevatedButton>(find.byKey(const Key('dy_action_DOWNLOAD')))
        .onPressed
        ?.call();
    await tester.pump();
    expect(platform.actions, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(h.previewReads.length, 2);
    expect(_enabled(tester, 'DOWNLOAD'), isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'late read and callbacks after leaving cannot reveal a different prescription',
    (tester) async {
      h.pendingPreview = Completer<JsonMap>();
      await _host(tester, h, platform);
      await tester.tap(find.byKey(const Key('dy_preview_back')));
      await tester.pumpAndSettle();
      h.pendingPreview!.complete(previewFixture());
      await tester.pumpAndSettle();
      expect(find.byType(NativeDynamicPreviewScreen), findsNothing);
      expect(platform.html, isEmpty);
      expect(platform.disposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'account access is rechecked before export; denial clears the renderer',
    (tester) async {
      await _host(tester, h, platform);
      await tester.pumpAndSettle();
      h.doctorData['access_flag'] = '0';
      await tester.tap(find.byKey(const Key('dy_action_SHARE')));
      await tester.pump();
      await tester.pump();
      expect(platform.actions, isEmpty);
      expect(h.auth.stage, AuthStage.accountBlocked);
      expect(platform.disposed, isTrue);
      expect(find.byKey(const Key('fake_preview_html')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'removed prescription permission clears the preview before export',
    (tester) async {
      await _host(tester, h, platform);
      await tester.pumpAndSettle();
      h.doctorData['can_prescribe'] = '0';
      await _tap(tester, 'SHARE');
      expect(platform.actions, isEmpty);
      expect(find.byKey(const Key('fake_preview_html')), findsNothing);
      expect(find.byKey(const Key('dy_preview_error')), findsOneWidget);
      expect(_enabled(tester, 'SHARE'), isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

import 'package:docdiary_ios/features/dashboard/native_camera_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const NativeCameraScreen(),
                    ),
                  );
                },
                child: const Text('Open example camera'),
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.text('Open example camera'));
  await tester.pumpAndSettle();
}

void main() {
  const channel = MethodChannel('plugins.flutter.io/camera');
  testWidgets(
    'no simulator camera shows a recoverable message and Cancel returns',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async =>
                call.method == 'availableCameras' ? <Object?>[] : null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await _open(tester);
      expect(
        find.textContaining('Use a real iPhone or choose Gallery.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Open example camera'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'denied camera permission offers Settings and Cancel without capture work',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async =>
                throw PlatformException(
                  code: 'CameraAccessDenied',
                  message: 'Denied',
                ),
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await _open(tester);
      expect(find.text('Open Settings'), findsOneWidget);
      expect(
        find.textContaining('Allow DocDiary camera access in iPhone Settings.'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Open example camera'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

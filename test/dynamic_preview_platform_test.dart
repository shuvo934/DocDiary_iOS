import 'dart:convert';
import 'dart:io';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_preview_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'iOS bridge loads HTML then sends measured native A4 regions for each explicit action',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      String? name;
      Object? measured = jsonDecode(
        File(
          'test/fixtures/dynamic_preview/complete_layout.json',
        ).readAsStringSync(),
      );
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final id = (call.arguments as Map)['id'];
          name = 'docdiary/dynamic_preview/$id';
          messenger.setMockMethodCallHandler(MethodChannel(name!), (
            call,
          ) async {
            calls.add(call);
            if (call.method == 'measure') return measured;
            if (['download', 'print', 'share'].contains(call.method)) {
              return true;
            }
            return null;
          });
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );
      final platform = IosDynamicPreviewPlatform();
      var ready = 0;
      final errors = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: platform.buildView(
              html: '<html>Native source</html>',
              documentName: 'Prescription_900',
              onReady: () => ready++,
              onError: errors.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.single.method, 'load');
      expect(
        (calls.single.arguments as Map)['html'],
        '<html>Native source</html>',
      );
      tester.binding.channelBuffers.push(
        name!,
        const StandardMethodCodec().encodeMethodCall(const MethodCall('ready')),
        (_) {},
      );
      await tester.pump();
      expect(ready, 1);
      for (final action in DynamicPreviewAction.values) {
        expect(await platform.perform(action), isTrue);
        expect(calls.last.method, action.name);
        final args = calls.last.arguments as Map;
        expect((args['columnPages'] as List).length, 1);
        expect(args['contentTop'], isPositive);
      }
      final count = calls.length;
      measured = {'contentTop': -1};
      await expectLater(
        platform.perform(DynamicPreviewAction.share),
        throwsA(isA<AppFailure>()),
      );
      expect(calls.length, count + 1);
      expect(calls.last.method, 'measure');
      await platform.suspend();
      expect(calls.last.method, 'suspend');
      platform.dispose();
      await tester.pump();
      expect(calls.last.method, 'dispose');
      await expectLater(
        platform.perform(DynamicPreviewAction.share),
        throwsStateError,
      );
      expect(errors, isEmpty);
      messenger.setMockMethodCallHandler(MethodChannel(name!), null);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

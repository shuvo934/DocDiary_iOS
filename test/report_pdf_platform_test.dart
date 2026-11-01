import 'dart:async';
import 'package:docdiary_ios/features/reports/native_report_pdf_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'report bridge loads original bytes, pages, zooms and saves on its own channel',
    (t) async {
      final messenger = t.binding.defaultBinaryMessenger,
          calls = <MethodCall>[];
      final bytes = Uint8List.fromList(
        '%PDF-1.7 synthetic bridge fixture'.codeUnits,
      );
      final channels = <MethodChannel>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final channel = MethodChannel(
            'docdiary/report_pdf/${(call.arguments as Map)['id']}',
          );
          channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return switch (call.method) {
              'load' => 3,
              'page' => (call.arguments as Map)['index'],
              'save' => true,
              _ => null,
            };
          });
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      final platform = IosReportPdfPlatform(),
          counts = <int>[],
          errors = <String>[];
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: platform.buildView(
              bytes: bytes,
              documentName: 'Synthetic_report',
              onLoaded: counts.add,
              onError: errors.add,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(counts, [3]);
      expect(calls.single.method, 'load');
      expect((calls.single.arguments as Map)['bytes'], orderedEquals(bytes));
      expect(
        (calls.single.arguments as Map)['documentName'],
        'Synthetic_report',
      );
      expect(await platform.page(2), 2);
      await platform.zoom(true);
      expect(calls.last.method, 'zoom');
      expect(calls.last.arguments, {'factor': 1.25});
      await platform.zoom(false);
      expect(calls.last.arguments, {'factor': .8});
      expect(await platform.save(), true);
      expect(errors, isEmpty);
      await platform.suspend();
      expect(calls.last.method, 'suspend');
      await expectLater(platform.zoom(true), throwsA(isA<PlatformException>()));
      expect(calls.last.method, 'suspend');
      // A new view may load after a genuine background/resume cycle.
      await t.pumpWidget(const SizedBox());
      await t.pump();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: platform.buildView(
              bytes: Uint8List.fromList(bytes),
              documentName: 'Synthetic_report',
              onLoaded: counts.add,
              onError: errors.add,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(counts, [3, 3]);
      platform.dispose();
      await t.pump();
      expect(calls.last.method, 'dispose');
      await expectLater(platform.page(0), throwsA(isA<PlatformException>()));
      await t.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'suspending a pending native fit ignores the late loaded callback',
    (t) async {
      final messenger = t.binding.defaultBinaryMessenger,
          counts = <int>[],
          errors = <String>[];
      final load = Completer<int>();
      MethodChannel? channel;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          channel = MethodChannel(
            'docdiary/report_pdf/${(call.arguments as Map)['id']}',
          );
          messenger.setMockMethodCallHandler(
            channel!,
            (call) async => call.method == 'load' ? load.future : null,
          );
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        if (channel != null) messenger.setMockMethodCallHandler(channel!, null);
      });
      final platform = IosReportPdfPlatform();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: platform.buildView(
              bytes: Uint8List.fromList('%PDF-1.7 synthetic'.codeUnits),
              documentName: 'Synthetic',
              onLoaded: counts.add,
              onError: errors.add,
            ),
          ),
        ),
      );
      await t.pump();
      await platform.suspend();
      load.complete(3);
      await t.pumpAndSettle();
      expect(counts, isEmpty);
      expect(errors, isEmpty);
      platform.dispose();
      await t.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

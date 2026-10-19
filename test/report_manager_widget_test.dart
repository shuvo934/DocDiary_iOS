import 'dart:io';
import 'dart:ui' as ui;

import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/features/reports/native_report_manager_layout.dart';
import 'package:docdiary_ios/features/reports/report_manager_menu.dart';
import 'package:docdiary_ios/main_report_manager_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _show(
  WidgetTester tester, {
  String center = 'crp',
  Size size = const Size(393, 852),
  double textScale = 1,
  EdgeInsets safeArea = EdgeInsets.zero,
  ValueChanged<ReportManagerItem>? onReport,
  VoidCallback? onBack,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('report_manager_capture'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: docDiaryTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
            padding: safeArea,
            viewPadding: safeArea,
          ),
          child: NativeReportManagerLayout(
            centerApi: Uri.parse('https://preview.invalid/ords/$center/'),
            onReport: onReport ?? (_) {},
            onBack: onBack ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage('assets/images/med_background_1.png'),
      tester.element(find.byType(NativeReportManagerLayout)),
    );
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['DOC_REPORT_CAPTURE_DIR'];
  if (directory == null) {
    return;
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('report_manager_capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('$directory/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void _reportTest(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    // Render real Material shadows, then restore the binding's debug defaults
    // before testWidgets checks its invariants (ordinary tearDown is too late).
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = previousShadows;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'))).load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  _reportTest('four-report menu is centred inside the native rounded body', (
    tester,
  ) async {
    await _show(tester, safeArea: const EdgeInsets.only(top: 59, bottom: 34));
    expect(find.text('Report Manager'), findsOneWidget);
    expect(find.text('Payment Receive Register Report'), findsNothing);
    final top = tester.getTopLeft(
      find.byKey(const Key('report_manager_card_1')),
    );
    final bottom = tester.getBottomRight(
      find.byKey(const Key('report_manager_card_4')),
    );
    final viewport = tester.getRect(
      find.byKey(const Key('report_manager_scroll')),
    );
    expect((top.dy + bottom.dy) / 2, closeTo(viewport.center.dy, .1));
    expect(find.byType(Image), findsNWidgets(4));
    await _capture(tester, 'report_manager_standard');
  });

  _reportTest('all five report buttons emit the exact selected native type', (
    tester,
  ) async {
    final selected = <ReportManagerItem>[];
    await _show(
      tester,
      center: 'cstar',
      safeArea: const EdgeInsets.only(top: 59, bottom: 34),
      onReport: selected.add,
    );
    double previousY = 0;
    for (final type in ['1', '5', '2', '3', '4']) {
      final button = find.byKey(Key('report_manager_select_$type'));
      final y = tester.getCenter(button).dy;
      expect(y, greaterThan(previousY));
      previousY = y;
      await tester.tap(button);
      await tester.pumpAndSettle();
    }
    expect(selected.map((r) => r.nativeType), ['1', '5', '2', '3', '4']);
    expect(selected[1].title, 'Payment Receive Register Report');
    expect(tester.takeException(), isNull);
    await _capture(tester, 'report_manager_cstar');
  });

  _reportTest('a changed centre does not retain the previous register button', (
    tester,
  ) async {
    await _show(tester, center: 'btrf');
    expect(find.text('Payment Receive Register Report'), findsOneWidget);
    await _show(tester);
    expect(find.text('Payment Receive Register Report'), findsNothing);
  });

  _reportTest('small screens and large text keep every report reachable', (
    tester,
  ) async {
    for (final size in [
      const Size(280, 568),
      const Size(320, 568),
      const Size(852, 393),
    ]) {
      final selected = <ReportManagerItem>[];
      await _show(
        tester,
        center: 'cstar',
        size: size,
        textScale: 2.5,
        safeArea: const EdgeInsets.only(top: 24, bottom: 21),
        onReport: selected.add,
      );
      final last = find.byKey(const Key('report_manager_select_4'));
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(selected.single, ReportManagerItem.doctorAppointment);
      expect(tester.takeException(), isNull);
      if (size.width > size.height) {
        await _capture(tester, 'report_manager_landscape_large_text');
      }
    }
  });

  _reportTest('the header calls Back once', (tester) async {
    var backs = 0;
    await _show(tester, onBack: () => backs++);
    await tester.tap(find.byKey(const Key('report_manager_back')));
    await tester.pumpAndSettle();
    expect(backs, 1);
  });

  _reportTest('offline preview opens the menu first and Back can reopen it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ReportManagerPreviewApp());
    await tester.pumpAndSettle();
    expect(find.byType(NativeReportManagerLayout), findsOneWidget);
    expect(find.text('Open Report Manager'), findsNothing);
    await tester.tap(find.byKey(const Key('report_manager_back')));
    await tester.pumpAndSettle();
    expect(find.text('Open Report Manager'), findsOneWidget);
    await tester.tap(find.text('Open Report Manager'));
    await tester.pumpAndSettle();
    expect(find.byType(NativeReportManagerLayout), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

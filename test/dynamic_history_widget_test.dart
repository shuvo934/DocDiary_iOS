import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_history_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_template_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_history_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dynamic_review_test_support.dart';
import 'dynamic_template_test_support.dart';
import 'dynamic_history_test_support.dart';

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
    for (final file in entry.value) {
      loader.addFont(rootBundle.load('assets/fonts/$file'));
    }
    await loader.load();
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(finder);
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _host(
  WidgetTester tester,
  DynamicHistoryController c, {
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: docDiaryTheme(),
      home: Scaffold(
        body: Builder(
          builder:
              (context) => TextButton(
                key: const Key('open_history'),
                onPressed:
                    () => unawaited(showNativeDynamicHistorySheet(context, c)),
                child: const Text('Open'),
              ),
        ),
      ),
    ),
  );
  await _tap(tester, 'open_history');
}

Future<void> _capture(WidgetTester tester, String name) async {
  const output = String.fromEnvironment('DYNAMIC_HISTORY_RENDER_DIR');
  if (output.isEmpty) return;
  final context = tester.element(find.byType(NativeDynamicHistorySheet));
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/dy_builder_medical_record.png'),
      context,
    ),
  );
  final shadows = debugDisableShadows;
  try {
    debugDisableShadows = false;
    void repaint(RenderObject object) {
      object.markNeedsPaint();
      object.visitChildren(repaint);
    }

    repaint(tester.binding.renderViews.first);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final render = tester.binding.renderViews.first;
      final image = await (render.debugLayer! as OffsetLayer).toImage(
        Offset.zero & render.size,
        pixelRatio: 3,
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  } finally {
    debugDisableShadows = shadows;
  }
}

void main() {
  setUpAll(_fonts);
  late DynamicReviewDraftFixture f;
  late DynamicTemplateController t;
  late DynamicHistoryController c;
  var reads = 0, applies = 0;
  var failList = false, failApply = false, emptyList = false;
  Completer<JsonMap>? pending;
  setUp(() {
    f = DynamicReviewDraftFixture();
    reads = 0;
    applies = 0;
    failList = false;
    failApply = false;
    emptyList = false;
    pending = null;
    t = DynamicTemplateController(
      review: f.review,
      loadDiseaseOptions: () async => diseaseTemplates,
      loadTreatmentOptions: (_) async => treatmentTemplates,
      loadData: (_, __) async => {},
    );
    c = DynamicHistoryController(
      review: f.review,
      templates: t,
      loadOptions: () async {
        reads++;
        if (failList) throw const AppFailure('History unavailable');
        return emptyList ? [] : historyItems();
      },
      loadData: (id) async {
        applies++;
        if (pending != null) return pending!.future;
        if (failApply) {
          throw const AppFailure('Previous prescription unavailable');
        }
        return previousPrescriptionData(id: id);
      },
    );
  });
  tearDown(() {
    c.dispose();
    t.dispose();
    f.dispose();
  });
  testWidgets(
    'native rows/count/selection keep Preview disabled until the final Preview module',
    (tester) async {
      await _host(tester, c);
      expect(find.text('3 prescriptions found'), findsOneWidget);
      expect(find.text('No Data Found'), findsNothing);
      expect(find.text('Appointment: 20-SEP-26 • 10:00 AM'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('dy_action_LOAD TO CURRENT RX')),
            )
            .onPressed,
        isNull,
      );
      await _capture(tester, 'history_list');
      await _tap(tester, 'dy_history_option_600_0');
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('dy_action_LOAD TO CURRENT RX')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('dy_action_PREVIEW')))
            .onPressed,
        isNull,
      );
      await _capture(tester, 'history_selected');
      expect(applies, 0);
      await _tap(tester, 'dy_history_close');
    },
  );
  testWidgets(
    'native empty history shows the original icon/message and no enabled actions',
    (tester) async {
      emptyList = true;
      await _host(tester, c);
      expect(find.text('No prescription history found'), findsOneWidget);
      expect(
        find.text('This patient has no previous prescription.'),
        findsOneWidget,
      );
      expect(find.text('3 prescriptions found'), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('dy_action_LOAD TO CURRENT RX')),
            )
            .onPressed,
        isNull,
      );
      await _capture(tester, 'history_empty');
      await _tap(tester, 'dy_history_close');
      expect(applies, 0);
    },
  );
  testWidgets('an empty draft loads directly without a replacement dialog', (
    tester,
  ) async {
    await _host(tester, c);
    await _tap(tester, 'dy_history_option_600_0');
    await _tap(tester, 'dy_action_LOAD TO CURRENT RX');
    expect(find.byType(NativeDynamicHistorySheet), findsNothing);
    expect(find.byKey(const Key('dy_history_replace_dialog')), findsNothing);
    expect(f.advice.reference, 'Previous reference');
    expect(applies, 1);
  });
  testWidgets(
    'native replacement Cancel retains confirmed data; LOAD & REPLACE loads only after confirmation',
    (tester) async {
      f.populate();
      await _host(tester, c);
      await _tap(tester, 'dy_history_option_600_0');
      await _tap(tester, 'dy_action_LOAD TO CURRENT RX');
      await _capture(tester, 'history_replace');
      await _tap(tester, 'dy_history_replace_cancel');
      expect(applies, 0);
      expect(f.review.confirmed, isTrue);
      await _tap(tester, 'dy_action_LOAD TO CURRENT RX');
      await _tap(tester, 'dy_history_replace_load');
      expect(applies, 1);
      expect(f.review.confirmed, isFalse);
      expect(f.advice.notes, 'Previous notes');
    },
  );
  testWidgets('list error retains draft and RETRY retrieves a fresh list', (
    tester,
  ) async {
    f.populate();
    failList = true;
    await _host(tester, c);
    expect(find.text('History unavailable'), findsOneWidget);
    await _capture(tester, 'history_list_error');
    failList = false;
    await _tap(tester, 'dy_action_RETRY');
    expect(reads, 2);
    expect(find.text('3 prescriptions found'), findsOneWidget);
    expect(f.review.confirmed, isTrue);
    await _tap(tester, 'dy_history_close');
  });
  testWidgets(
    'previous load error has native Load Failed dialog and retains selection for a manual retry',
    (tester) async {
      failApply = true;
      await _host(tester, c);
      await _tap(tester, 'dy_history_option_600_0');
      await _tap(tester, 'dy_action_LOAD TO CURRENT RX');
      expect(find.text('Load Failed'), findsOneWidget);
      await _capture(tester, 'history_load_error');
      await _tap(tester, 'dy_history_error_ok');
      expect(c.selected!.rvmId, '600');
      expect(f.advice.notes, isEmpty);
      failApply = false;
      await _tap(tester, 'dy_action_LOAD TO CURRENT RX');
      expect(applies, 2);
      expect(find.byType(NativeDynamicHistorySheet), findsNothing);
    },
  );
  testWidgets(
    'pending previous load blocks Close/system Back/outside tap and disables selection/actions',
    (tester) async {
      pending = Completer<JsonMap>();
      await _host(tester, c);
      await _tap(tester, 'dy_history_option_600_0');
      await tester.tap(find.byKey(const Key('dy_action_LOAD TO CURRENT RX')));
      await tester.pump();
      expect(c.applying, isTrue);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('dy_history_close')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('dy_action_LOAD TO CURRENT RX')),
            )
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.tapAt(const Offset(2, 10));
      await tester.pump();
      expect(find.byType(NativeDynamicHistorySheet), findsOneWidget);
      pending!.complete(previousPrescriptionData());
      await tester.pumpAndSettle();
      expect(applies, 1);
      expect(find.byType(NativeDynamicHistorySheet), findsNothing);
    },
  );
  testWidgets(
    'small iPhone rows and footer fit with native spacing and long optional labels',
    (tester) async {
      await _host(tester, c, size: const Size(320, 640));
      await _tap(tester, 'dy_history_option_599_1');
      await _capture(tester, 'history_small');
      expect(
        find.byKey(const Key('dy_action_LOAD TO CURRENT RX')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await _tap(tester, 'dy_history_close');
    },
  );
  testWidgets(
    'closing/reopening clears selection and reloads the list without resetting review confirmation',
    (tester) async {
      f.populate();
      await _host(tester, c);
      await _tap(tester, 'dy_history_option_600_0');
      await _tap(tester, 'dy_history_close');
      await _tap(tester, 'open_history');
      expect(reads, 2);
      expect(c.selected, isNull);
      expect(f.review.confirmed, isTrue);
      await _tap(tester, 'dy_history_close');
    },
  );
}

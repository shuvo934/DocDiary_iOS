import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_template_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_template_sheet.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_clinical_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dynamic_review_test_support.dart';
import 'dynamic_template_test_support.dart';

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
  DynamicTemplateController c, {
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
                key: const Key('open_templates'),
                onPressed:
                    () => unawaited(showNativeDynamicTemplateSheet(context, c)),
                child: const Text('Open'),
              ),
        ),
      ),
    ),
  );
  await _tap(tester, 'open_templates');
}

Future<void> _capture(WidgetTester tester, String name) async {
  const output = String.fromEnvironment('DYNAMIC_TEMPLATE_RENDER_DIR');
  if (output.isEmpty) return;
  final context = tester.element(find.byType(NativeDynamicTemplateSheet));
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/dy_builder_template.png'),
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
  late DynamicTemplateController c;
  var reads = 0, applies = 0;
  var failList = false, failApply = false;
  Completer<JsonMap>? pending;
  setUp(() {
    f = DynamicReviewDraftFixture();
    reads = 0;
    applies = 0;
    failList = false;
    failApply = false;
    pending = null;
    c = DynamicTemplateController(
      review: f.review,
      loadDiseaseOptions: () async {
        reads++;
        if (failList) throw const AppFailure('Catalogue unavailable');
        return diseaseTemplates;
      },
      loadTreatmentOptions: (_) async => treatmentTemplates,
      loadData: (kind, _) async {
        applies++;
        if (pending != null) return pending!.future;
        if (failApply) throw const AppFailure('Template unavailable');
        return kind == DynamicTemplateKind.disease
            ? diseaseTemplateData()
            : treatmentTemplateData();
      },
    );
  });
  tearDown(() {
    c.dispose();
    f.dispose();
  });

  for (final size in [const Size(393, 852), const Size(320, 640)]) {
    for (final treatment in [false, true]) {
      testWidgets(
        '${treatment ? "Treatment" : "Disease"} search keeps focus and input while the keyboard resizes ${size.width.toInt()}px sheet',
        (tester) async {
          if (treatment) {
            await c.apply(DynamicTemplateKind.disease, diseaseTemplates.first);
          }
          await _host(tester, c, size: size);
          final kind = treatment ? 'treatment' : 'disease';
          final field = find.byKey(Key('dy_field_template_search_$kind'));
          final editable = find.descendant(
            of: field,
            matching: find.byType(EditableText),
          );
          await tester.showKeyboard(field);
          await tester.pump();
          final state = tester.state<EditableTextState>(editable);
          final focus = state.widget.focusNode;
          expect(focus.hasFocus, isTrue);
          final before = applies;
          // Exercise the viewport animation that crosses the compact-layout
          // threshold on iPhone, without enterText implicitly restoring focus.
          for (final inset in [120.0, 240.0, 300.0, 380.0, 240.0, 0.0]) {
            tester.view.viewInsets = FakeViewPadding(bottom: inset);
            await tester.pumpAndSettle();
            expect(tester.state<EditableTextState>(editable), same(state));
            expect(focus.hasFocus, isTrue);
            expect(tester.testTextInput.isVisible, isTrue);
            expect(tester.takeException(), isNull);
            if (treatment && inset == 380) {
              await _capture(
                tester,
                'treatment_keyboard_${size.width.toInt()}',
              );
            }
          }
          tester.testTextInput.updateEditingValue(
            TextEditingValue(text: treatment ? 'strengthening' : 'upper'),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(treatment ? 'Exercise Plan' : 'Occupational Template'),
            findsOneWidget,
          );
          expect(
            find.text(treatment ? 'Therapy Plan' : 'Physiotherapy Template'),
            findsNothing,
          );
          expect(focus.hasFocus, isTrue);
          await _tap(tester, 'dy_template_clear_search');
          expect(tester.widget<TextField>(field).controller!.text, isEmpty);
          expect(focus.hasFocus, isTrue);
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(focus.hasFocus, isFalse);
          expect(applies, before);
          expect(find.byType(NativeDynamicTemplateSheet), findsOneWidget);
          await _tap(tester, 'dy_template_close');
        },
      );
    }
  }

  testWidgets(
    'native Disease search and selection; keyboard Done never applies the chosen template',
    (tester) async {
      await _host(tester, c);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('dy_template_action_LOAD DISEASE TEMPLATE')),
            )
            .onPressed,
        isNull,
      );
      await _capture(tester, 'template_disease');
      await _tap(tester, 'dy_template_option_disease_701_0');
      await _capture(tester, 'template_disease_selected');
      await tester.enterText(
        find.byKey(const Key('dy_field_template_search_disease')),
        'upper',
      );
      await tester.pumpAndSettle();
      expect(find.text('Occupational Template'), findsOneWidget);
      expect(find.text('Physiotherapy Template'), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(applies, 0);
      expect(find.byType(NativeDynamicTemplateSheet), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('dy_field_template_search_disease')),
        'no match',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching Disease Template found'), findsOneWidget);
      await _tap(tester, 'dy_template_clear_search');
      expect(
        tester
            .widget<Radio<String>>(find.byType(Radio<String>).first)
            .groupValue,
        '701',
      );
      await _tap(tester, 'dy_template_close');
      expect(applies, 0);
    },
  );
  testWidgets(
    'Disease loads once, advances to optional Treatment, and DONE closes with Disease retained',
    (tester) async {
      await _host(tester, c);
      await _tap(tester, 'dy_template_option_disease_701_0');
      await _tap(tester, 'dy_template_action_LOAD DISEASE TEMPLATE');
      expect(find.text('STEP 2 OF 2'), findsOneWidget);
      expect(find.text('Disease Template loaded'), findsOneWidget);
      await _capture(tester, 'template_treatment');
      await _tap(tester, 'dy_template_action_DONE');
      expect(c.diseaseId, '701');
      expect(c.treatmentId, isEmpty);
      expect(applies, 1);
      await _tap(tester, 'open_templates');
      expect(find.text('STEP 2 OF 2'), findsOneWidget);
      expect(reads, 1);
      await _tap(tester, 'dy_template_change');
      expect(find.text('STEP 1 OF 2'), findsOneWidget);
      expect(reads, 1);
      await _tap(tester, 'dy_template_close');
    },
  );
  testWidgets(
    'replace confirmation Cancel preserves current draft; LOAD follows the native Disease scope',
    (tester) async {
      f.populate();
      await _host(tester, c);
      final pulse = f.clinical.vitals!['pulse'];
      await _tap(tester, 'dy_template_option_disease_701_0');
      await _tap(tester, 'dy_template_action_LOAD DISEASE TEMPLATE');
      expect(find.text('Replace current prescription data?'), findsOneWidget);
      await _capture(tester, 'template_replace_disease');
      await _tap(tester, 'dy_template_replace_cancel');
      expect(applies, 0);
      expect(f.review.confirmed, isTrue);
      await _tap(tester, 'dy_template_action_LOAD DISEASE TEMPLATE');
      await _tap(tester, 'dy_template_replace_load');
      expect(f.clinical.vitals!['pulse'], pulse);
      expect(f.rx.medicines, isEmpty);
      expect(f.review.confirmed, isFalse);
      await _tap(tester, 'dy_template_action_DONE');
    },
  );
  testWidgets(
    'Treatment replace confirmation uses native text and successful LOAD dismisses',
    (tester) async {
      f.populate();
      c.restore({'td_id': '701', 'td_name': 'Occupational Template'});
      await _host(tester, c);
      await _tap(tester, 'dy_template_option_treatment_801_0');
      await _tap(tester, 'dy_template_action_LOAD TREATMENT');
      expect(find.text('Replace current Rx data?'), findsOneWidget);
      await _capture(tester, 'template_replace_treatment');
      await _tap(tester, 'dy_template_replace_load');
      expect(find.byType(NativeDynamicTemplateSheet), findsNothing);
      expect(c.treatmentId, '801');
      expect(
        f.clinical.entries(DynamicClinicalType.complain).single.text,
        'নমুনা অভিযোগ',
      );
    },
  );
  testWidgets(
    'native list retry and apply-error clear never publish a failed draft',
    (tester) async {
      failList = true;
      await _host(tester, c);
      expect(find.text('Catalogue unavailable\nTap to retry'), findsOneWidget);
      failList = false;
      await _tap(tester, 'dy_template_error');
      expect(reads, 2);
      failApply = true;
      await _tap(tester, 'dy_template_option_disease_701_0');
      await _tap(tester, 'dy_template_action_LOAD DISEASE TEMPLATE');
      expect(find.text('Template unavailable'), findsOneWidget);
      expect(c.diseaseId, isEmpty);
      await _capture(tester, 'template_apply_error');
      await _tap(tester, 'dy_template_error');
      expect(find.text('Occupational Template'), findsOneWidget);
      expect(applies, 1);
      failApply = false;
      await _tap(tester, 'dy_template_action_LOAD DISEASE TEMPLATE');
      expect(c.diseaseId, '701');
      await _tap(tester, 'dy_template_action_DONE');
    },
  );
  testWidgets(
    'small iPhone and keyboard preserve usable search and footer without overflow',
    (tester) async {
      c.restore({'td_id': '701', 'td_name': 'Occupational Template'});
      await _host(tester, c, size: const Size(320, 640));
      final input = find.byKey(const Key('dy_field_template_search_treatment'));
      await tester.enterText(input, 'motion');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('dy_template_compact_scroll')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      expect(applies, 0);
      expect(
        find.byKey(const Key('dy_template_action_DONE')).hitTestable(),
        findsOneWidget,
      );
      await _tap(tester, 'dy_template_action_DONE');
    },
  );
  testWidgets(
    'pending apply disables Close and prevents system Back until the read completes',
    (tester) async {
      pending = Completer<JsonMap>();
      await _host(tester, c);
      await _tap(tester, 'dy_template_option_disease_701_0');
      await tester.tap(
        find.byKey(const Key('dy_template_action_LOAD DISEASE TEMPLATE')),
      );
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('dy_template_close')))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(NativeDynamicTemplateSheet), findsOneWidget);
      pending!.complete(diseaseTemplateData());
      await tester.pumpAndSettle();
      expect(c.diseaseId, '701');
      await _tap(tester, 'dy_template_action_DONE');
    },
  );
}

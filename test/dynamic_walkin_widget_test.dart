import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_patient_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_patient_selection_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dynamic_walkin_test_support.dart';

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
  DynamicPatientController c, {
  Size size = const Size(393, 852),
  ValueChanged<DynamicPatientSelection?>? onResult,
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
                key: const Key('open_patient_selection'),
                onPressed: () async {
                  final result = await showNativeDynamicPatientSelectionSheet(
                    context,
                    c,
                    requiredSelection: true,
                  );
                  onResult?.call(result);
                  c.close();
                },
                child: const Text('Open'),
              ),
        ),
      ),
    ),
  );
  await _tap(tester, 'open_patient_selection');
}

Future<void> _capture(WidgetTester tester, String name) async {
  const output = String.fromEnvironment('DYNAMIC_WALKIN_RENDER_DIR');
  if (output.isEmpty) return;
  final context = tester.element(
    find.byType(NativeDynamicPatientSelectionSheet),
  );
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/dy_rx_patient.png'),
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
  late DynamicPatientController c;
  var recent = 0, search = 0;
  var fail = false;
  setUp(() {
    recent = 0;
    search = 0;
    fail = false;
    c = DynamicPatientController(
      currentYear: 2026,
      loadRecent: (_) async {
        recent++;
        if (fail) throw const AppFailure('Patient lookup failed');
        return walkInPatients();
      },
      searchPatients: (_) async {
        search++;
        if (fail) throw const AppFailure('Patient lookup failed');
        return walkInPatients();
      },
    );
  });
  tearDown(() => c.dispose());
  testWidgets(
    'native patient rows and Indoor/Outdoor selection require the SELECT PATIENT button',
    (tester) async {
      DynamicPatientSelection? result;
      var returned = false;
      await _host(
        tester,
        c,
        onResult: (value) {
          result = value;
          returned = true;
        },
      );
      expect(find.text('Indoor'), findsOneWidget);
      expect(find.text('(Mirpur)'), findsOneWidget);
      expect(find.text('Female • 35 Years'), findsNWidgets(2));
      await _capture(tester, 'patient_selection');
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('dy_action_SELECT PATIENT')),
            )
            .onPressed,
        isNull,
      );
      await _tap(tester, 'dy_patient_option_201_0');
      expect(returned, isFalse);
      await _tap(tester, 'dy_dropdown_patient_type');
      await _tap(tester, 'dy_option_patient_type_1_1');
      await _capture(tester, 'patient_selected_outdoor');
      await _tap(tester, 'dy_action_SELECT PATIENT');
      expect(returned, isTrue);
      expect(result!.patient.historyId, '201');
      expect(result!.prescriptionType, '1');
    },
  );
  testWidgets(
    'Registration Year dropdown uses native current-to-minus-50 list and performs a new year GET',
    (tester) async {
      await _host(tester, c);
      await _tap(tester, 'dy_dropdown_patient_year');
      await _tap(tester, 'dy_option_patient_year_2025_1');
      expect(c.year, '2025');
      expect(recent, 2);
      await _tap(tester, 'dy_select_patient_close');
    },
  );
  testWidgets(
    'search waits for three characters and keyboard Done does not select or add extra searches',
    (tester) async {
      await _host(tester, c);
      final field = find.byKey(const Key('dy_field_patient_search'));
      await tester.enterText(field, 'ab');
      await tester.pump(const Duration(milliseconds: 600));
      expect(search, 0);
      expect(
        find.text('Enter at least 3 characters to search'),
        findsNWidgets(2),
      );
      await tester.enterText(field, 'Patient');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(search, 1);
      expect(c.yearEnabled, isFalse);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(search, 1);
      expect(find.byType(NativeDynamicPatientSelectionSheet), findsOneWidget);
      expect(c.selected, isNull);
      await _tap(tester, 'dy_patient_search_clear');
      expect(c.yearEnabled, isTrue);
      expect(recent, 2);
      await _tap(tester, 'dy_select_patient_close');
    },
  );
  testWidgets(
    'patient error tap retries without dismissing the mandatory sheet',
    (tester) async {
      fail = true;
      await _host(tester, c);
      expect(find.text('Patient lookup failed\nTap to retry'), findsOneWidget);
      await _capture(tester, 'patient_list_error');
      fail = false;
      await _tap(tester, 'dy_patient_selection_empty');
      expect(recent, 2);
      expect(find.text('Walk-in Patient One'), findsOneWidget);
      await _tap(tester, 'dy_select_patient_close');
    },
  );
  for (final action in ['close', 'cancel', 'back']) {
    testWidgets(
      'patient selection $action returns cancellation without selecting a row',
      (tester) async {
        var returned = false;
        DynamicPatientSelection? result;
        await _host(
          tester,
          c,
          onResult: (value) {
            returned = true;
            result = value;
          },
        );
        if (action == 'back') {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        } else {
          await _tap(
            tester,
            action == 'close' ? 'dy_select_patient_close' : 'dy_action_CANCEL',
          );
        }
        expect(returned, isTrue);
        expect(result, isNull);
        expect(find.byType(NativeDynamicPatientSelectionSheet), findsNothing);
      },
    );
  }
  for (final size in [const Size(393, 852), const Size(320, 640)]) {
    testWidgets(
      'patient search keeps its focus/connection while keyboard resizes ${size.width.toInt()}px sheet',
      (tester) async {
        await _host(tester, c, size: size);
        final field = find.byKey(const Key('dy_field_patient_search'));
        final editable = find.descendant(
          of: field,
          matching: find.byType(EditableText),
        );
        await tester.showKeyboard(field);
        await tester.pump();
        final state = tester.state<EditableTextState>(editable);
        for (final inset in [180.0, 300.0, 380.0, 0.0]) {
          tester.view.viewInsets = FakeViewPadding(bottom: inset);
          await tester.pumpAndSettle();
          expect(tester.state<EditableTextState>(editable), same(state));
          expect(state.widget.focusNode.hasFocus, isTrue);
          expect(tester.testTextInput.isVisible, isTrue);
          expect(tester.takeException(), isNull);
          if (inset == 300) {
            await _capture(tester, 'patient_keyboard_${size.width.toInt()}');
          }
        }
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(state.widget.focusNode.hasFocus, isFalse);
        await _tap(tester, 'dy_select_patient_close');
      },
    );
  }

  for (final selecting in [false, true]) {
    testWidgets(
      'native resultDelivered guard ignores duplicate ${selecting ? "SELECT" : "CANCEL"} callbacks',
      (tester) async {
        var returned = 0;
        await _host(tester, c, onResult: (_) => returned++);
        if (selecting) await _tap(tester, 'dy_patient_option_201_0');
        final action =
            tester
                .widget<ElevatedButton>(
                  find.byKey(
                    Key(
                      selecting
                          ? 'dy_action_SELECT PATIENT'
                          : 'dy_action_CANCEL',
                    ),
                  ),
                )
                .onPressed!;
        action();
        action();
        await tester.pumpAndSettle();
        expect(returned, 1);
        expect(find.byKey(const Key('open_patient_selection')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

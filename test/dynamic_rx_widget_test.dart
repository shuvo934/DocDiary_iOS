import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_clinical_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_rx_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_rx_controls.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_rx_sheets.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_rx_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dynamic_rx_test_support.dart';

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

final _render = GlobalKey();
Future<void> _host(
  WidgetTester tester,
  Widget child, {
  bool sheet = true,
  Size size = const Size(393, 852),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewInsets);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: docDiaryTheme(),
      home: Scaffold(
        body:
            sheet
                ? Builder(
                  builder:
                      (context) => TextButton(
                        key: const Key('open'),
                        onPressed:
                            () => unawaited(
                              showNativeDynamicRxSheet<void>(
                                context,
                                RepaintBoundary(key: _render, child: child),
                              ),
                            ),
                        child: const Text('Open'),
                      ),
                )
                : RepaintBoundary(key: _render, child: child),
      ),
    ),
  );
  if (sheet) await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  if (target.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(target);
  }
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final target = find.byKey(Key('dy_field_$key'));
  await tester.ensureVisible(target);
  await tester.enterText(target, text);
  await tester.pumpAndSettle();
}

String _value(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key('dy_field_$key'))).controller!.text;

Future<void> _capture(WidgetTester tester, String name) async {
  const output = String.fromEnvironment('DYNAMIC_RX_STAGE2_RENDER_DIR');
  if (output.isEmpty) return;
  final boundary =
      _render.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final before = debugDisableShadows;
  void repaint(RenderObject object) {
    object.markNeedsPaint();
    object.visitChildren(repaint);
  }

  try {
    await tester.runAsync(() async {
      for (final name in ['medicine', 'pill', 'treatment_plan']) {
        await precacheImage(
          AssetImage('assets/images/dy_rx_$name.png'),
          _render.currentContext!,
        );
      }
    });
    debugDisableShadows = false;
    repaint(boundary);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3),
          directory = Directory(output);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  } finally {
    debugDisableShadows = before;
    repaint(boundary);
    await tester.pump();
  }
}

void main() {
  setUpAll(_fonts);
  late DynamicRxDraft draft;
  setUp(() => draft = DynamicRxDraft());
  tearDown(() => draft.dispose());

  for (final editing in [false, true]) {
    testWidgets(
      'required Duration is labelled and validated in ${editing ? 'Edit' : 'Add'} Medicine',
      (tester) async {
        final original = editing ? rxMedicine() : null;
        if (original != null) draft.saveMedicine(original);
        await _host(
          tester,
          NativeDynamicMedicineSheet(
            draft: draft,
            catalogue: rxCatalogue(),
            existing: original,
            durationRequired: true,
          ),
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('dy_field_rx_duration')))
              .decoration!
              .labelText,
          'Duration (Days)',
        );
        if (!editing) await _type(tester, 'rx_medicine', 'Sample medicine');
        final action = 'dy_action_${editing ? 'UPDATE' : 'ADD'} MEDICINE';
        await _tap(tester, action);
        expect(find.text('Enter duration in days'), findsOneWidget);
        await _type(tester, 'rx_duration', '0');
        await _tap(tester, action);
        expect(find.text('Duration must be greater than 0'), findsOneWidget);
        await _type(tester, 'rx_duration', '7');
        await _tap(tester, action);
        expect(draft.medicines.single.duration, '7');
        if (editing) expect(draft.medicines.single.localId, original!.localId);
      },
    );
  }
  for (final flag in [false, true]) {
    testWidgets(
      'Rx tab forwards durationRequired=$flag to both Medicine actions',
      (tester) async {
        final entry = rxMedicine();
        draft.saveMedicine(entry);
        await _host(
          tester,
          NativeDynamicRxTab(
            draft: draft,
            catalogue: rxCatalogue(),
            medicineAllowed: true,
            durationRequired: flag,
          ),
          sheet: false,
        );
        for (final key in ['dy_add_medicine', 'dy_edit_${entry.localId}']) {
          await _tap(tester, key);
          expect(
            tester
                .widget<NativeDynamicMedicineSheet>(
                  find.byType(NativeDynamicMedicineSheet),
                )
                .durationRequired,
            flag,
          );
          await _tap(tester, 'dy_action_CANCEL');
        }
      },
    );
  }

  testWidgets(
    'Medicine add uses native defaults; blank/unmatched inputs have distinct errors and no empty option row',
    (tester) async {
      await _host(
        tester,
        NativeDynamicMedicineSheet(draft: draft, catalogue: rxCatalogue()),
      );
      expect(_value(tester, 'rx_dose'), '0+0+1');
      expect(_value(tester, 'rx_timing'), 'After meals [PC ]');
      expect(_value(tester, 'rx_route'), 'By mouth (oral) [PO ]');
      await _capture(tester, 'add_medicine');
      await _tap(tester, 'dy_action_ADD MEDICINE');
      expect(find.text('Select a medicine'), findsOneWidget);
      await _type(tester, 'rx_medicine', 'No matching medicine');
      expect(find.textContaining('No option'), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await _tap(tester, 'dy_action_ADD MEDICINE');
      expect(
        find.text('Select a valid medicine from the list'),
        findsOneWidget,
      );
      await _type(tester, 'rx_medicine', 'sample MEDICINE');
      await _tap(tester, 'dy_action_ADD MEDICINE');
      expect(draft.medicines.single.medicine.id, '100');
      expect(draft.medicines.single.duration, '');
    },
  );

  testWidgets(
    'select then add extra words is rejected; original Medicine stays searchable after keyboard Done',
    (tester) async {
      await _host(
        tester,
        NativeDynamicMedicineSheet(draft: draft, catalogue: rxCatalogue()),
      );
      await _tap(tester, 'dy_dropdown_rx_medicine');
      await _tap(tester, 'dy_option_rx_medicine_100_0');
      await _type(tester, 'rx_medicine', 'Sample medicine extra');
      await _tap(tester, 'dy_action_ADD MEDICINE');
      expect(
        find.text('Select a valid medicine from the list'),
        findsOneWidget,
      );
      await _type(tester, 'rx_medicine', 'Sample medicine');
      await _tap(tester, 'dy_option_rx_medicine_100_0');
      await _tap(tester, 'dy_action_ADD MEDICINE');
      expect(draft.medicines.single.medicine.id, '100');
    },
  );

  for (final key in ['dose', 'timing', 'route']) {
    testWidgets('Medicine validates strict $key without accepting added text', (
      tester,
    ) async {
      await _host(
        tester,
        NativeDynamicMedicineSheet(draft: draft, catalogue: rxCatalogue()),
      );
      await _type(tester, 'rx_medicine', 'Sample medicine');
      await _type(tester, 'rx_$key', 'invalid $key');
      await _tap(tester, 'dy_action_ADD MEDICINE');
      expect(find.text('Select a valid $key from the list'), findsOneWidget);
      expect(draft.medicines, isEmpty);
    });
  }
  testWidgets(
    'Medicine edit restores fields, retains local ID, validates duration and updates a single row',
    (tester) async {
      final original = rxMedicine(duration: '7', notes: 'Saved notes');
      draft.saveMedicine(original);
      await _host(
        tester,
        NativeDynamicMedicineSheet(
          draft: draft,
          catalogue: rxCatalogue(),
          existing: original,
        ),
      );
      expect(_value(tester, 'rx_duration'), '7');
      expect(_value(tester, 'rx_notes'), 'Saved notes');
      await _type(tester, 'rx_duration', '0');
      await _tap(tester, 'dy_action_UPDATE MEDICINE');
      expect(find.text('Duration must be greater than 0'), findsOneWidget);
      await _type(tester, 'rx_duration', '9');
      await _type(tester, 'rx_notes', 'Updated notes');
      await _tap(tester, 'dy_action_UPDATE MEDICINE');
      expect(draft.medicines.single.localId, original.localId);
      expect(draft.medicines.single.duration, '9');
      expect(draft.medicines.single.notes, 'Updated notes');
    },
  );
  testWidgets(
    'Medicine duplicate blocks save; Cancel leaves previously saved details unchanged',
    (tester) async {
      final original = rxMedicine();
      draft.saveMedicine(original);
      await _host(
        tester,
        NativeDynamicMedicineSheet(draft: draft, catalogue: rxCatalogue()),
      );
      await _type(tester, 'rx_medicine', 'Sample medicine');
      await _tap(tester, 'dy_action_ADD MEDICINE');
      expect(find.text('This medicine has already been added'), findsOneWidget);
      await _tap(tester, 'dy_action_CANCEL');
      expect(draft.medicines.single, same(original));
    },
  );
  testWidgets(
    'missing native default IDs stay blank; edit mode never reapplies add defaults',
    (tester) async {
      final catalogue = DynamicRxCatalogue(
        medicines: rxCatalogue().medicines,
        doses: const [DynamicRxOption('3', '1+0+1')],
        timings: const [],
        routes: const [],
      );
      await _host(
        tester,
        NativeDynamicMedicineSheet(draft: draft, catalogue: catalogue),
      );
      expect(_value(tester, 'rx_dose'), '');
      expect(_value(tester, 'rx_timing'), '');
      expect(_value(tester, 'rx_route'), '');
      await _tap(tester, 'dy_action_CANCEL');
      final entry = DynamicMedicineEntry(
        medicine: rxCatalogue().medicines.first,
        dose: rxCatalogue().doses.last,
        timing: rxCatalogue().timings.last,
        route: rxCatalogue().routes.last,
      );
      draft.saveMedicine(entry);
      await _host(
        tester,
        NativeDynamicMedicineSheet(
          draft: draft,
          catalogue: rxCatalogue(),
          existing: entry,
        ),
      );
      expect(_value(tester, 'rx_dose'), '1+0+1');
      expect(_value(tester, 'rx_route'), 'Topical');
    },
  );
  testWidgets(
    'Therapy strict validation, notes, edit and duplicate match the native sheet',
    (tester) async {
      await _host(
        tester,
        NativeDynamicTherapySheet(
          draft: draft,
          options: rxCatalogue().therapies,
        ),
      );
      await _capture(tester, 'add_therapy');
      await _tap(tester, 'dy_action_ADD THERAPY');
      expect(find.text('Select a therapy'), findsOneWidget);
      await _type(tester, 'rx_therapy', 'not a master');
      await _tap(tester, 'dy_action_ADD THERAPY');
      expect(find.text('Select a valid therapy from the list'), findsOneWidget);
      await _type(tester, 'rx_therapy', 'Sample therapy');
      await _type(tester, 'rx_therapy_notes', 'Saved notes');
      await _tap(tester, 'dy_action_ADD THERAPY');
      final entry = draft.therapies.single;
      await _host(
        tester,
        NativeDynamicTherapySheet(
          draft: draft,
          options: rxCatalogue().therapies,
          existing: entry,
        ),
      );
      await _type(tester, 'rx_therapy_notes', 'Updated');
      await _tap(tester, 'dy_action_UPDATE THERAPY');
      expect(draft.therapies.single.localId, entry.localId);
      expect(draft.therapies.single.notes, 'Updated');
      await _host(
        tester,
        NativeDynamicTherapySheet(
          draft: draft,
          options: rxCatalogue().therapies,
        ),
      );
      await _type(tester, 'rx_therapy', 'Sample therapy');
      await _tap(tester, 'dy_action_ADD THERAPY');
      expect(find.text('This therapy has already been added'), findsOneWidget);
    },
  );
  testWidgets(
    'Treatment Plan custom text, retained master after editing, exact override and duplicates follow native rules',
    (tester) async {
      await _host(
        tester,
        NativeDynamicTreatmentPlanSheet(
          draft: draft,
          options: rxCatalogue().treatmentPlans,
        ),
      );
      await _capture(tester, 'add_treatment_plan');
      await _tap(tester, 'dy_action_ADD TREATMENT PLAN');
      expect(find.text('Enter or select treatment plan'), findsOneWidget);
      await _tap(tester, 'dy_dropdown_rx_treatment_plan');
      await _tap(tester, 'dy_option_rx_treatment_plan_300_0');
      await _type(
        tester,
        'rx_treatment_plan',
        'Continue treatment with edited text',
      );
      await _tap(tester, 'dy_action_ADD TREATMENT PLAN');
      final entry = draft.treatmentPlans.single;
      expect(entry.masterId, '300');
      await _host(
        tester,
        NativeDynamicTreatmentPlanSheet(
          draft: draft,
          options: rxCatalogue().treatmentPlans,
          existing: entry,
        ),
      );
      await _type(tester, 'rx_treatment_plan', 'Review response');
      await _tap(tester, 'dy_action_UPDATE TREATMENT PLAN');
      expect(draft.treatmentPlans.single.masterId, '301');
      expect(draft.treatmentPlans.single.localId, entry.localId);
      await _host(
        tester,
        NativeDynamicTreatmentPlanSheet(
          draft: draft,
          options: rxCatalogue().treatmentPlans,
        ),
      );
      await _type(tester, 'rx_treatment_plan', 'review RESPONSE');
      await _tap(tester, 'dy_action_ADD TREATMENT PLAN');
      expect(
        find.text('This treatment plan has already been added'),
        findsOneWidget,
      );
      await _type(tester, 'rx_treatment_plan', 'Entirely custom plan');
      await _tap(tester, 'dy_action_ADD TREATMENT PLAN');
      expect(
        draft.treatmentPlans,
        hasLength(1),
        reason:
            'The native sheet retains the last exact master even after a duplicate failure.',
      );
      await _tap(tester, 'dy_action_CANCEL');
      await _host(
        tester,
        NativeDynamicTreatmentPlanSheet(
          draft: draft,
          options: rxCatalogue().treatmentPlans,
        ),
      );
      await _type(tester, 'rx_treatment_plan', 'Entirely custom plan');
      await _tap(tester, 'dy_action_ADD TREATMENT PLAN');
      expect(draft.treatmentPlans.last.masterId, isNull);
    },
  );
  testWidgets(
    'Rx tab deletes each row immediately and retains expansion across Medicine/Therapy selection',
    (tester) async {
      draft.replaceFromData(rxExistingData());
      await _host(
        tester,
        NativeDynamicRxTab(
          draft: draft,
          catalogue: rxCatalogue(),
          medicineAllowed: true,
        ),
        sheet: false,
      );
      final medicine = draft.medicines.single,
          therapy = draft.therapies.single,
          plan = draft.treatmentPlans.first;
      await _tap(tester, 'dy_delete_${medicine.localId}');
      expect(draft.medicines, isEmpty);
      await _tap(tester, 'dy_toggle_medicine');
      await _tap(tester, 'dy_rx_segment_therapy');
      await _tap(tester, 'dy_delete_${therapy.localId}');
      expect(draft.therapies, isEmpty);
      await _tap(tester, 'dy_toggle_treatment_plan');
      await _tap(tester, 'dy_delete_${plan.localId}');
      expect(draft.treatmentPlans, hasLength(1));
      await _tap(tester, 'dy_rx_segment_medicine');
      expect(find.text('No medicine added'), findsNothing);
      await _tap(tester, 'dy_toggle_medicine');
      expect(find.text('No medicine added'), findsOneWidget);
    },
  );
  testWidgets('Rx row edit sheet returns to exactly the same scroll position', (
    tester,
  ) async {
    for (var i = 0; i < 15; i++) {
      draft.saveMedicine(rxMedicine(id: '${100 + i}', name: 'Medicine $i'));
    }
    await _host(
      tester,
      NativeDynamicRxTab(
        draft: draft,
        catalogue: rxCatalogue(),
        medicineAllowed: true,
      ),
      sheet: false,
    );
    final view = find.byKey(const PageStorageKey<String>('dynamic_rx_scroll'));
    final scroll = tester.widget<SingleChildScrollView>(view).controller!;
    scroll.jumpTo(450);
    await tester.pumpAndSettle();
    final row = find.byKey(Key('dy_edit_${draft.medicines[5].localId}'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    final before = scroll.offset;
    await tester.tap(row);
    await tester.pumpAndSettle();
    await _tap(tester, 'dy_action_CANCEL');
    expect(scroll.offset, closeTo(before, .1));
  });
  testWidgets(
    'denied Medicine starts in Therapy; locked selector shows native message and cannot open Medicine',
    (tester) async {
      final messages = <String>[];
      const channel = MethodChannel('PonnamKarthik/fluttertoast');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'showToast') {
          messages.add(
            (call.arguments as Map<Object?, Object?>)['msg']! as String,
          );
        }
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await _host(
        tester,
        NativeDynamicRxTab(
          draft: draft,
          catalogue: rxCatalogue(),
          medicineAllowed: false,
        ),
        sheet: false,
      );
      expect(find.text('No therapy added'), findsOneWidget);
      expect(find.byKey(const Key('dy_add_medicine')), findsNothing);
      await _tap(tester, 'dy_rx_segment_medicine');
      await tester.idle();
      expect(find.text('No therapy added'), findsOneWidget);
      expect(messages, [
        'Medicine prescribing is not enabled for your account',
      ]);
    },
  );
  testWidgets(
    'Medicine short viewport/keyboard keeps native footer usable; user floating labels preserve state colors',
    (tester) async {
      await _host(
        tester,
        NativeDynamicMedicineSheet(draft: draft, catalogue: rxCatalogue()),
        size: const Size(320, 640),
      );
      await _type(tester, 'rx_notes', 'Notes while keyboard is open');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('dy_action_ADD MEDICINE')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('dy_action_CANCEL')).hitTestable(),
        findsOneWidget,
      );
      final field = tester.widget<TextField>(
        find.byKey(const Key('dy_field_rx_medicine')),
      );
      final style =
          field.decoration!.floatingLabelStyle! as WidgetStateTextStyle;
      expect(
        style.resolve({WidgetState.focused}).color,
        DynamicRxColors.primary,
      );
      expect(style.resolve({WidgetState.error}).color, DynamicRxColors.error);
      expect(
        style.resolve({WidgetState.disabled}).color,
        const Color(0xff999999),
      );
      final metrics = DynamicRxMetrics(
        tester.element(find.byType(NativeDynamicMedicineSheet)),
      );
      expect(metrics.text(10, family: 'PatuaOne').fontFamily, 'PatuaOne');
      await _tap(tester, 'dy_action_CANCEL');
      expect(draft.medicines, isEmpty);
    },
  );
}

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_clinical_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_clinical_sheets.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_clinical_tab.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_rx_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _options = [
  DynamicRxOption('1', 'Low back pain', 'Doctor notes'),
  DynamicRxOption('2', 'Neck pain'),
];
DynamicClinicalCatalogue _catalogue() => DynamicClinicalCatalogue(
  clinical: {
    for (final type in DynamicClinicalType.values)
      type: type.hasOptions ? _options : [],
  },
  objectives: const [
    DynamicRxOption('10', 'ROM'),
    DynamicRxOption('20', 'Strength'),
  ],
  muscleJoints: const [DynamicRxOption('30', 'Knee')],
);
final _renderKey = GlobalKey();

Future<void> _fonts() async {
  final loader = FontLoader('Poppins');
  for (final file in [
    'Poppins-Regular.ttf',
    'Poppins-Medium.ttf',
    'Poppins-SemiBold.ttf',
    'Poppins-Bold.ttf',
  ]) {
    loader.addFont(rootBundle.load('assets/fonts/$file'));
  }
  await loader.load();
  final fallback = FontLoader('Roboto')
    ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  await fallback.load();
}

Future<void> _size(
  WidgetTester tester, [
  Size size = const Size(393, 852),
]) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);
}

Future<void> _hostTab(
  WidgetTester tester,
  DynamicClinicalDraft draft, {
  Future<List<DynamicRxOption>> Function(String)? loadValues,
  Size size = const Size(393, 852),
}) async {
  await _size(tester, size);
  await tester.pumpWidget(
    MaterialApp(
      theme: docDiaryTheme(),
      home: Scaffold(
        body: RepaintBoundary(
          key: _renderKey,
          child: NativeDynamicClinicalTab(
            draft: draft,
            catalogue: _catalogue(),
            loadObjectiveValues:
                loadValues ??
                (_) async => const [DynamicRxOption('11', 'Flexion')],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _hostSheet(
  WidgetTester tester,
  Widget sheet, {
  Size size = const Size(393, 852),
}) async {
  await _size(tester, size);
  await tester.pumpWidget(
    MaterialApp(
      theme: docDiaryTheme(),
      home: Scaffold(
        body: Builder(
          builder:
              (context) => TextButton(
                key: const Key('open'),
                onPressed:
                    () => unawaited(
                      showNativeDynamicRxSheet<void>(
                        context,
                        RepaintBoundary(key: _renderKey, child: sheet),
                      ),
                    ),
                child: const Text('Open'),
              ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  if (target.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(target);
  }
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  const output = String.fromEnvironment('DYNAMIC_RX_RENDER_DIR');
  if (output.isEmpty) return;
  await tester.runAsync(() async {
    for (final stem in [
      'patient',
      'diagnosis',
      'medicine',
      'chemistry',
      'caution',
    ]) {
      await precacheImage(
        AssetImage('assets/images/dy_rx_$stem.png'),
        _renderKey.currentContext!,
      );
    }
  });
  await tester.pumpAndSettle();
  final boundary =
      _renderKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final before = debugDisableShadows;
  void repaint(RenderObject object) {
    object.markNeedsPaint();
    object.visitChildren(repaint);
  }

  try {
    debugDisableShadows = false;
    repaint(boundary);
    await tester.pump();
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory(output);
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
  late DynamicClinicalDraft draft;
  setUp(() {
    draft = DynamicClinicalDraft();
  });
  tearDown(() => draft.dispose());

  testWidgets('reopening Objective reuses native successful value cache', (
    tester,
  ) async {
    var calls = 0;
    await _hostTab(
      tester,
      draft,
      loadValues: (_) async {
        calls++;
        return const [DynamicRxOption('11', 'Flexion')];
      },
    );
    for (var i = 0; i < 2; i++) {
      await _tap(tester, 'dy_add_objective');
      await _tap(tester, 'dy_dropdown_objective');
      await _tap(tester, 'dy_option_objective_10_0');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('dy_field_value')))
            .enabled,
        isTrue,
      );
      await _tap(tester, 'dy_action_CANCEL');
    }
    expect(calls, 1);
  });

  testWidgets(
    'native tab keep-alive preserves expansion, scroll and shared draft',
    (tester) async {
      await _size(tester, const Size(393, 650));
      await tester.pumpWidget(
        MaterialApp(
          theme: docDiaryTheme(),
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              body: Column(
                children: [
                  const TabBar(
                    tabs: [Tab(text: 'Clinical'), Tab(text: 'Next tab')],
                    labelColor: Colors.black,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        NativeDynamicClinicalTab(
                          draft: draft,
                          catalogue: _catalogue(),
                          loadObjectiveValues: (_) async => [],
                        ),
                        const Center(child: Text('Other tab fixture')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      draft.saveEntry(
        DynamicClinicalType.importantInfo,
        DynamicClinicalEntry(text: 'Shared clinical draft'),
      );
      await tester.pump();
      await _tap(tester, 'dy_toggle_importantInfo');
      await tester.ensureVisible(find.text('Shared clinical draft'));
      await tester.pumpAndSettle();
      final position =
          tester
              .state<ScrollableState>(
                find
                    .descendant(
                      of: find.byKey(
                        const PageStorageKey<String>('dynamic_clinical_scroll'),
                      ),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              )
              .position;
      final before = position.pixels;
      await tester.tap(find.text('Next tab'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clinical'));
      await tester.pumpAndSettle();
      expect(find.text('Shared clinical draft'), findsOneWidget);
      expect(position.pixels, closeTo(before, .1));
      expect(draft.entries(DynamicClinicalType.importantInfo), hasLength(1));
    },
  );

  testWidgets(
    'native section order, counts and initial Vitals-only expansion',
    (tester) async {
      await _hostTab(tester, draft);
      expect(find.text('No vitals added'), findsOneWidget);
      expect(find.text('No complain added'), findsNothing);
      final expected = [
        'Vitals',
        'Complain',
        'Injury',
        'Diagnosis',
        'Objective Info',
        'Drug History',
        'Clinical Findings',
        'Tests / Investigation',
        'Important Info',
      ];
      final positions = [
        for (final label in expected) tester.getTopLeft(find.text(label)).dy,
      ];
      expect(positions, orderedEquals([...positions]..sort()));
      expect(
        tester.widget<Text>(find.byKey(const Key('dy_count_vitals'))).data,
        'Not added',
      );
      await _capture(tester, 'clinical_tab');
      expect(tester.takeException(), isNull);
    },
  );

  for (final type in DynamicClinicalType.values) {
    testWidgets(
      '${type.label}: blank uses the native message and Cancel leaves draft unchanged',
      (tester) async {
        await _hostSheet(
          tester,
          NativeDynamicClinicalEntrySheet(
            type: type,
            draft: draft,
            options: type.hasOptions ? _options : [],
          ),
        );
        await _tap(tester, 'dy_action_ADD ${type.label.toUpperCase()}');
        expect(
          find.text(
            type.hasOptions
                ? 'Enter or select ${type.label.toLowerCase()}'
                : 'Enter ${type.label.toLowerCase()}',
          ),
          findsOneWidget,
        );
        expect(draft.entries(type), isEmpty);
        await _tap(tester, 'dy_action_CANCEL');
        expect(draft.entries(type), isEmpty);
      },
    );
  }
  for (final type in DynamicClinicalType.values.where((t) => t.allowsCustom)) {
    testWidgets(
      '${type.label}: native custom text is accepted without a master',
      (tester) async {
        await _hostSheet(
          tester,
          NativeDynamicClinicalEntrySheet(
            type: type,
            draft: draft,
            options: type.hasOptions ? _options : [],
          ),
        );
        await tester.enterText(
          find.byKey(const Key('dy_field_entry')),
          'Custom clinical detail',
        );
        await _tap(tester, 'dy_action_ADD ${type.label.toUpperCase()}');
        expect(draft.entries(type).single.text, 'Custom clinical detail');
        expect(draft.entries(type).single.masterId, isNull);
      },
    );
  }
  for (final type in [
    DynamicClinicalType.complain,
    DynamicClinicalType.injury,
    DynamicClinicalType.diagnosis,
    DynamicClinicalType.clinicalFinding,
  ]) {
    testWidgets(
      '${type.label}: customized master keeps its ID and a new exact match replaces it',
      (tester) async {
        await _hostSheet(
          tester,
          NativeDynamicClinicalEntrySheet(
            type: type,
            draft: draft,
            options: _options,
          ),
        );
        await _tap(tester, 'dy_dropdown_entry');
        await _tap(tester, 'dy_option_entry_1_0');
        await tester.enterText(
          find.byKey(const Key('dy_field_entry')),
          'Low back pain for 3 days',
        );
        await _tap(tester, 'dy_action_ADD ${type.label.toUpperCase()}');
        final original = draft.entries(type).single;
        expect(original.masterId, '1');
        expect(original.text, 'Low back pain for 3 days');
        await _hostSheet(
          tester,
          NativeDynamicClinicalEntrySheet(
            type: type,
            draft: draft,
            options: _options,
            existing: original,
          ),
        );
        await tester.enterText(
          find.byKey(const Key('dy_field_entry')),
          ' neck PAIN ',
        );
        await _tap(tester, 'dy_action_UPDATE ${type.label.toUpperCase()}');
        expect(draft.entries(type).single.masterId, '2');
        expect(draft.entries(type).single.localId, original.localId);
      },
    );
  }
  for (final type in [
    DynamicClinicalType.drugHistory,
    DynamicClinicalType.investigation,
  ]) {
    testWidgets(
      '${type.label}: strict selection rejects modified words and can recover the full original list',
      (tester) async {
        await _hostSheet(
          tester,
          NativeDynamicClinicalEntrySheet(
            type: type,
            draft: draft,
            options: _options,
          ),
        );
        await _tap(tester, 'dy_dropdown_entry');
        await _tap(tester, 'dy_option_entry_1_0');
        await tester.enterText(
          find.byKey(const Key('dy_field_entry')),
          'Low back pain extra words',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text('No options found'), findsNothing);
        await _tap(tester, 'dy_action_ADD ${type.label.toUpperCase()}');
        expect(
          find.text('Select a valid ${type.label.toLowerCase()} from the list'),
          findsOneWidget,
        );
        await _tap(tester, 'dy_dropdown_entry');
        await _tap(tester, 'dy_option_entry_1_0');
        if (type.hasNotes) {
          await tester.enterText(
            find.byKey(const Key('dy_field_entry_notes')),
            'Within 7 days',
          );
        }
        await _tap(tester, 'dy_action_ADD ${type.label.toUpperCase()}');
        expect(draft.entries(type).single.masterId, '1');
        if (type.hasNotes) {
          expect(draft.entries(type).single.notes, 'Within 7 days');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'typed exact names resolve case-insensitively; duplicate feedback stays in the sheet',
    (tester) async {
      draft.saveEntry(
        DynamicClinicalType.complain,
        DynamicClinicalEntry(masterId: '1', text: 'Low back pain'),
      );
      await _hostSheet(
        tester,
        NativeDynamicClinicalEntrySheet(
          type: DynamicClinicalType.complain,
          draft: draft,
          options: _options,
        ),
      );
      await tester.enterText(
        find.byKey(const Key('dy_field_entry')),
        'low BACK pain',
      );
      await _tap(tester, 'dy_action_ADD COMPLAIN');
      expect(find.text('This complain has already been added'), findsOneWidget);
      expect(draft.entries(DynamicClinicalType.complain), hasLength(1));
    },
  );
  testWidgets('row Edit and immediate Delete act on the selected local entry', (
    tester,
  ) async {
    final entry = DynamicClinicalEntry(text: 'Old entry');
    draft.saveEntry(DynamicClinicalType.complain, entry);
    await _hostTab(tester, draft);
    await _tap(tester, 'dy_toggle_complain');
    await _tap(tester, 'dy_edit_${entry.localId}');
    expect(find.text('Edit Complain'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('dy_field_entry')),
      'Updated entry',
    );
    await _tap(tester, 'dy_action_UPDATE COMPLAIN');
    expect(
      draft.entries(DynamicClinicalType.complain).single.localId,
      entry.localId,
    );
    await _tap(tester, 'dy_delete_${entry.localId}');
    expect(draft.entries(DynamicClinicalType.complain), isEmpty);
    expect(find.text('No complain added'), findsOneWidget);
  });
  testWidgets(
    'dropdown parent rebuild, keyboard dismissal, filtered empty list and route disposal stay safe',
    (tester) async {
      await _hostSheet(
        tester,
        NativeDynamicClinicalEntrySheet(
          type: DynamicClinicalType.complain,
          draft: draft,
          options: _options,
        ),
      );
      await _tap(tester, 'dy_dropdown_entry');
      expect(find.byKey(const Key('dy_options_entry')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('dy_field_entry')),
        'back low',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dy_option_entry_1_0')), findsOneWidget);
      expect(find.byKey(const Key('dy_option_entry_2_1')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('dy_field_entry')),
        'unmatched value',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dy_options_entry')), findsNothing);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump();
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      await _tap(tester, 'dy_sheet_close');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('scroll stays at the clicked section after a sheet closes', (
    tester,
  ) async {
    await _hostTab(tester, draft, size: const Size(393, 650));
    await _tap(tester, 'dy_add_importantInfo');
    await _tap(tester, 'dy_action_CANCEL');
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(
              const PageStorageKey<String>('dynamic_clinical_scroll'),
            ),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final before = scroll.position.pixels;
    expect(before, greaterThan(0));
    await _tap(tester, 'dy_add_importantInfo');
    await _tap(tester, 'dy_action_CANCEL');
    expect(scroll.position.pixels, closeTo(before, .1));
  });

  testWidgets(
    'Vitals BMI is read-only, live calculated, saved, and clear requires native confirmation',
    (tester) async {
      await _hostSheet(tester, NativeDynamicVitalsSheet(draft: draft));
      await _capture(tester, 'add_vitals');
      await tester.enterText(find.byKey(const Key('dy_field_height')), '170');
      await tester.enterText(find.byKey(const Key('dy_field_weight')), '68');
      await tester.pump();
      final bmi = tester.widget<TextField>(
        find.byKey(const Key('dy_field_bmi')),
      );
      expect(bmi.readOnly, isTrue);
      expect(bmi.controller!.text, '23.5');
      await _tap(tester, 'dy_action_SAVE VITALS');
      expect(draft.vitals!['bmi'], '23.5');
      await _hostSheet(tester, NativeDynamicVitalsSheet(draft: draft));
      await _tap(tester, 'dy_clear_vitals');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(draft.vitals, isNotNull);
      await _tap(tester, 'dy_clear_vitals');
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(draft.vitals, isNull);
    },
  );
  testWidgets(
    'Vitals validates BP pair and SpO2 without dropping typed measurements',
    (tester) async {
      await _hostSheet(tester, NativeDynamicVitalsSheet(draft: draft));
      await tester.enterText(find.byKey(const Key('dy_field_systolic')), '120');
      await tester.enterText(find.byKey(const Key('dy_field_spo2')), '101');
      await _tap(tester, 'dy_action_SAVE VITALS');
      expect(find.text('Enter diastolic pressure'), findsOneWidget);
      expect(find.text('Value must be 1–100'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('dy_field_diastolic')), '80');
      await tester.enterText(find.byKey(const Key('dy_field_spo2')), '98');
      await _tap(tester, 'dy_action_SAVE VITALS');
      expect(draft.vitals!['systolic'], '120');
      expect(draft.vitals!['spo2'], '98');
    },
  );
  testWidgets(
    'Vitals keyboard and a short viewport keep both footer actions reachable',
    (tester) async {
      await _hostSheet(
        tester,
        NativeDynamicVitalsSheet(draft: draft),
        size: const Size(320, 640),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('dy_field_weight')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('dy_action_CANCEL')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('dy_action_SAVE VITALS')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Objective starts with disabled Value; notes-only save follows active native Java logic',
    (tester) async {
      await _hostSheet(
        tester,
        NativeDynamicObjectiveSheet(
          draft: draft,
          catalogue: _catalogue(),
          loadValues: (_, {retry = false}) async => [],
        ),
      );
      await _capture(tester, 'add_objective');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('dy_field_value')))
            .enabled,
        isFalse,
      );
      await _tap(tester, 'dy_dropdown_objective');
      await _tap(tester, 'dy_option_objective_10_0');
      await _tap(tester, 'dy_action_ADD OBJECTIVE');
      expect(find.text('No predefined value is available'), findsOneWidget);
      expect(find.text('Enter notes if no value is selected'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('dy_field_notes')),
        'Loss 15 degrees',
      );
      await _tap(tester, 'dy_action_ADD OBJECTIVE');
      expect(draft.objectives.single.objective.id, '10');
      expect(draft.objectives.single.value, isNull);
      expect(draft.objectives.single.notes, 'Loss 15 degrees');
    },
  );
  testWidgets(
    'Objective Value is dropdown-only and a selected Value allows empty notes',
    (tester) async {
      await _hostSheet(
        tester,
        NativeDynamicObjectiveSheet(
          draft: draft,
          catalogue: _catalogue(),
          loadValues:
              (_, {retry = false}) async => const [
                DynamicRxOption('11', 'Flexion'),
              ],
        ),
      );
      await _tap(tester, 'dy_dropdown_objective');
      await _tap(tester, 'dy_option_objective_10_0');
      final value = tester.widget<TextField>(
        find.byKey(const Key('dy_field_value')),
      );
      expect(value.enabled, isTrue);
      expect(value.readOnly, isTrue);
      await _tap(tester, 'dy_dropdown_value');
      await _tap(tester, 'dy_option_value_11_0');
      await _tap(tester, 'dy_dropdown_muscle');
      await _tap(tester, 'dy_option_muscle_30_0');
      await _tap(tester, 'dy_action_ADD OBJECTIVE');
      expect(draft.objectives.single.value!.id, '11');
      expect(draft.objectives.single.muscleJoint!.id, '30');
    },
  );
  testWidgets(
    'Objective switching ignores old asynchronous values and disables Save while loading',
    (tester) async {
      final first = Completer<List<DynamicRxOption>>(),
          second = Completer<List<DynamicRxOption>>();
      await _hostSheet(
        tester,
        NativeDynamicObjectiveSheet(
          draft: draft,
          catalogue: _catalogue(),
          loadValues:
              (id, {retry = false}) =>
                  id == '10' ? first.future : second.future,
        ),
      );
      await tester.enterText(
        find.byKey(const Key('dy_field_objective')),
        'ROM',
      );
      await tester.pump();
      expect(find.text('Loading values...'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('dy_action_ADD OBJECTIVE')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('dy_field_objective')),
        'Strength',
      );
      await tester.pump();
      first.complete(const [DynamicRxOption('old', 'Old value')]);
      await tester.pump();
      expect(find.text('Loading values...'), findsOneWidget);
      second.complete(const [DynamicRxOption('21', 'Grade 4')]);
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('dy_field_value')))
            .enabled,
        isTrue,
      );
      await _tap(tester, 'dy_dropdown_value');
      expect(find.text('Grade 4'), findsOneWidget);
      expect(find.text('Old value'), findsNothing);
      await _tap(tester, 'dy_option_value_21_0');
      await _tap(tester, 'dy_action_ADD OBJECTIVE');
      expect(draft.objectives.single.objective.id, '20');
    },
  );
  testWidgets(
    'Objective lookup failure has native Retry and preserves selection',
    (tester) async {
      var calls = 0, retried = false;
      await _hostSheet(
        tester,
        NativeDynamicObjectiveSheet(
          draft: draft,
          catalogue: _catalogue(),
          loadValues: (id, {retry = false}) async {
            calls++;
            retried = retry;
            if (calls == 1) throw const AppFailure('Unable to load values');
            return const [DynamicRxOption('11', 'Flexion')];
          },
        ),
      );
      await _tap(tester, 'dy_dropdown_objective');
      await _tap(tester, 'dy_option_objective_10_0');
      expect(find.text('Unable to load values'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('dy_field_value')))
            .enabled,
        isFalse,
      );
      await _tap(tester, 'dy_retry_values');
      expect(retried, isTrue);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('dy_field_objective')))
            .controller!
            .text,
        'ROM',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('dy_field_value')))
            .enabled,
        isTrue,
      );
    },
  );
  testWidgets(
    'Objective edit restores current master names and dependent Value after lookup',
    (tester) async {
      final entry = DynamicObjectiveEntry(
        objective: const DynamicRxOption('10', 'Old ROM name'),
        value: const DynamicRxOption('11', 'Old value name'),
        notes: 'Notes',
      );
      draft.saveObjective(entry);
      await _hostSheet(
        tester,
        NativeDynamicObjectiveSheet(
          draft: draft,
          catalogue: _catalogue(),
          existing: entry,
          loadValues:
              (_, {retry = false}) async => const [
                DynamicRxOption('11', 'Flexion'),
              ],
        ),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('dy_field_objective')))
            .controller!
            .text,
        'ROM',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('dy_field_value')))
            .controller!
            .text,
        'Flexion',
      );
      await _tap(tester, 'dy_action_UPDATE OBJECTIVE');
      expect(draft.objectives.single.localId, entry.localId);
      expect(draft.objectives.single.value!.name, 'Flexion');
    },
  );
  testWidgets(
    'invalid typed Muscle/Joint is rejected and duplicate Objective is not added',
    (tester) async {
      final entry = DynamicObjectiveEntry(
        objective: const DynamicRxOption('10', 'ROM'),
        notes: '15 degrees',
      );
      draft.saveObjective(entry);
      await _hostSheet(
        tester,
        NativeDynamicObjectiveSheet(
          draft: draft,
          catalogue: _catalogue(),
          loadValues: (_, {retry = false}) async => [],
        ),
      );
      await tester.enterText(
        find.byKey(const Key('dy_field_objective')),
        'ROM',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('dy_field_notes')),
        '15 degrees',
      );
      await tester.enterText(
        find.byKey(const Key('dy_field_muscle')),
        'Invalid joint',
      );
      await _tap(tester, 'dy_action_ADD OBJECTIVE');
      expect(
        find.text('Select a valid Muscle / Joint from the list'),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(const Key('dy_field_muscle')), '');
      await _tap(tester, 'dy_action_ADD OBJECTIVE');
      expect(
        find.text('This objective information has already been added'),
        findsOneWidget,
      );
      expect(draft.objectives, hasLength(1));
    },
  );
  testWidgets(
    'closing Objective before its response arrives does not mutate draft or throw',
    (tester) async {
      final pending = Completer<List<DynamicRxOption>>();
      await _hostSheet(
        tester,
        NativeDynamicObjectiveSheet(
          draft: draft,
          catalogue: _catalogue(),
          loadValues: (_, {retry = false}) => pending.future,
        ),
      );
      await tester.enterText(
        find.byKey(const Key('dy_field_objective')),
        'ROM',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('dy_sheet_close')));
      await tester.pump(const Duration(milliseconds: 400));
      pending.complete(const [DynamicRxOption('11', 'Flexion')]);
      await tester.pumpAndSettle();
      expect(draft.objectives, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'native Complain sheet render and Cancel/close never commit typed input',
    (tester) async {
      await _hostSheet(
        tester,
        NativeDynamicClinicalEntrySheet(
          type: DynamicClinicalType.complain,
          draft: draft,
          options: _options,
        ),
      );
      await _capture(tester, 'add_complain');
      await tester.enterText(
        find.byKey(const Key('dy_field_entry')),
        'Uncommitted text',
      );
      await _tap(tester, 'dy_sheet_close');
      expect(draft.entries(DynamicClinicalType.complain), isEmpty);
    },
  );
}

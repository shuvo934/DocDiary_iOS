import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_advice_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_advice_sheet.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_advice_tab.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_rx_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dynamic_advice_test_support.dart';

final _render = GlobalKey();
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

Future<void> _host(
  WidgetTester tester,
  Widget widget, {
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
                                RepaintBoundary(key: _render, child: widget),
                              ),
                            ),
                        child: const Text('Open'),
                      ),
                )
                : RepaintBoundary(key: _render, child: widget),
      ),
    ),
  );
  if (sheet) await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _sheet(
  WidgetTester tester,
  DynamicAdviceDraft draft,
  DynamicAdviceType type, {
  DynamicAdviceEntry? existing,
  Size size = const Size(393, 852),
}) => _host(
  tester,
  NativeDynamicAdviceSheet(
    type: type,
    draft: draft,
    options: adviceCatalogue().options[type]!,
    existing: existing,
  ),
  size: size,
);
Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(finder);
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _write(WidgetTester tester, String text) async {
  final field = find.byKey(const Key('dy_field_advice_entry'));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

String _saveKey(DynamicAdviceType type, {bool editing = false}) =>
    'dy_action_${editing ? 'UPDATE' : 'ADD'} ${type.label.toUpperCase()}';
Future<void> _capture(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment('DYNAMIC_ADVICE_RENDER_DIR');
  if (directory.isEmpty) return;
  final boundary =
      _render.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final before = debugDisableShadows;
  void repaint(RenderObject object) {
    object.markNeedsPaint();
    object.visitChildren(repaint);
  }

  try {
    debugDisableShadows = false;
    repaint(boundary);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3),
          folder = Directory(directory);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await folder.create(recursive: true);
      await File(
        '${folder.path}/$name.png',
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
  late DynamicAdviceDraft draft;
  setUp(() => draft = DynamicAdviceDraft());
  tearDown(() => draft.dispose());

  for (final type in DynamicAdviceType.values) {
    testWidgets(
      '${type.label} native sheet validates blank text, supports custom text and renders the shared style',
      (tester) async {
        await _sheet(tester, draft, type);
        await _capture(tester, 'add_${type.name}');
        expect(
          find.byKey(const Key('dy_dropdown_advice_entry')),
          type.hasOptions ? findsOneWidget : findsNothing,
        );
        await _tap(tester, _saveKey(type));
        expect(
          find.text(
            '${type.hasOptions ? 'Enter or select' : 'Enter'} ${type.label.toLowerCase()}',
          ),
          findsOneWidget,
        );
        await _write(tester, 'Custom ${type.label} information');
        expect(find.textContaining('No option'), findsNothing);
        await _tap(tester, _saveKey(type));
        expect(
          draft.entries(type).single.text,
          'Custom ${type.label} information',
        );
        expect(draft.entries(type).single.masterId, isNull);
      },
    );
  }
  for (final type in DynamicAdviceType.values.where(
    (type) => type.hasOptions,
  )) {
    testWidgets(
      '${type.label} keeps selected master after customizing and exact text overrides it in Edit',
      (tester) async {
        final options = adviceCatalogue().options[type]!;
        await _sheet(tester, draft, type);
        await _tap(tester, 'dy_dropdown_advice_entry');
        await _tap(tester, 'dy_option_advice_entry_${options.first.id}_0');
        await _write(tester, '${options.first.name} with customized text');
        await _tap(tester, _saveKey(type));
        final entry = draft.entries(type).single;
        expect(entry.masterId, options.first.id);
        await _sheet(tester, draft, type, existing: entry);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('dy_field_advice_entry')))
              .controller!
              .text,
          entry.text,
        );
        await _write(tester, options.last.name.toUpperCase());
        await _tap(tester, _saveKey(type, editing: true));
        expect(draft.entries(type).single.masterId, options.last.id);
        expect(draft.entries(type).single.localId, entry.localId);
      },
    );
  }
  testWidgets(
    'Advice duplicate message keeps form open, typed text and native master choices intact',
    (tester) async {
      const type = DynamicAdviceType.followUp;
      draft.saveEntry(
        type,
        DynamicAdviceEntry(masterId: '501', text: 'Follow-up detail'),
      );
      await _sheet(tester, draft, type);
      await _write(tester, 'Follow-up detail');
      await _tap(tester, _saveKey(type));
      expect(
        find.text('This follow-up has already been added'),
        findsOneWidget,
      );
      await _write(tester, 'Unmatched text');
      expect(find.textContaining('No option'), findsNothing);
      await _write(tester, 'Another follow-up');
      await _tap(tester, _saveKey(type));
      expect(draft.entries(type), hasLength(2));
      expect(draft.entries(type).last.masterId, '502');
    },
  );
  for (final type in DynamicAdviceType.values) {
    for (final editing in [false, true]) {
      testWidgets(
        '${type.label} ${editing ? 'Edit' : 'Add'} Done only closes keyboard; explicit button commits',
        (tester) async {
          final entry =
              editing ? DynamicAdviceEntry(text: 'Previously saved') : null;
          if (entry != null) draft.saveEntry(type, entry);
          await _sheet(tester, draft, type, existing: entry);
          final before = draft.revision;
          await _write(tester, 'Text waits for the button');
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pumpAndSettle();
          expect(find.byType(NativeDynamicAdviceSheet), findsOneWidget);
          expect(draft.revision, before);
          expect(
            draft.entries(type).map((item) => item.text),
            editing ? ['Previously saved'] : <String>[],
          );
          final field = find.byKey(const Key('dy_field_advice_entry'));
          final editable = tester.widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          );
          expect(editable.focusNode.hasFocus, isFalse);
          expect(
            find.byKey(const Key('dy_options_advice_entry')),
            findsNothing,
          );
          await _tap(tester, _saveKey(type, editing: editing));
          expect(draft.entries(type).single.text, 'Text waits for the button');
          if (editing) {
            expect(draft.entries(type).single.localId, entry!.localId);
          }
          expect(find.byType(NativeDynamicAdviceSheet), findsNothing);
        },
      );
    }
  }
  for (final type in [DynamicAdviceType.reference, DynamicAdviceType.notes]) {
    testWidgets(
      '${type.label} plus edits a saved single row; delete immediately resets the Added badge',
      (tester) async {
        await _host(
          tester,
          NativeDynamicAdviceTab(draft: draft, catalogue: adviceCatalogue()),
          sheet: false,
        );
        await _tap(tester, 'dy_add_${type.name}');
        await _write(tester, 'First ${type.label}');
        await _tap(tester, _saveKey(type));
        final entry = draft.entries(type).single;
        expect(
          tester.widget<Text>(find.byKey(Key('dy_count_${type.name}'))).data,
          'Added',
        );
        await _tap(tester, 'dy_add_${type.name}');
        expect(find.text('Edit ${type.label}'), findsOneWidget);
        await _write(tester, 'Updated ${type.label}');
        await _tap(tester, _saveKey(type, editing: true));
        expect(draft.entries(type).single.localId, entry.localId);
        await _tap(tester, 'dy_delete_${entry.localId}');
        expect(draft.entries(type), isEmpty);
        expect(
          tester.widget<Text>(find.byKey(Key('dy_count_${type.name}'))).data,
          'Not added',
        );
      },
    );
  }
  testWidgets(
    'Advice row edit and Cancel retain scroll; Delete is immediate without a second confirmation',
    (tester) async {
      for (var i = 0; i < 15; i++) {
        draft.saveEntry(
          DynamicAdviceType.advice,
          DynamicAdviceEntry(text: 'Advice row $i'),
        );
      }
      await _host(
        tester,
        NativeDynamicAdviceTab(draft: draft, catalogue: adviceCatalogue()),
        sheet: false,
      );
      await _tap(tester, 'dy_toggle_advice');
      final scroll =
          tester
              .widget<SingleChildScrollView>(
                find.byKey(
                  const PageStorageKey<String>('dynamic_advice_scroll'),
                ),
              )
              .controller!;
      scroll.jumpTo(400);
      await tester.pumpAndSettle();
      final entry = draft.entries(DynamicAdviceType.advice)[6],
          button = find.byKey(
            Key(
              'dy_edit_${draft.entries(DynamicAdviceType.advice)[6].localId}',
            ),
          );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final before = scroll.offset;
      await tester.tap(button);
      await tester.pumpAndSettle();
      await _write(tester, 'Unsaved form text');
      await _tap(tester, 'dy_action_CANCEL');
      expect(scroll.offset, closeTo(before, .1));
      expect(draft.entries(DynamicAdviceType.advice)[6].text, entry.text);
      await _tap(tester, 'dy_delete_${entry.localId}');
      expect(draft.entries(DynamicAdviceType.advice), hasLength(14));
    },
  );
  testWidgets(
    'closing text-only Notes never commits input; short screen with keyboard keeps both footer actions reachable',
    (tester) async {
      await _sheet(
        tester,
        draft,
        DynamicAdviceType.notes,
        size: const Size(320, 640),
      );
      await _write(tester, 'Uncommitted notes');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('dy_action_ADD NOTES')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('dy_action_CANCEL')).hitTestable(),
        findsOneWidget,
      );
      await _tap(tester, 'dy_sheet_close');
      expect(draft.notes, '');
      expect(tester.takeException(), isNull);
    },
  );
}

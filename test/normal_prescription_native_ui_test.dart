import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/features/prescription/normal_prescription_models.dart';
import 'package:docdiary_ios/features/prescription/normal_prescription_native_style.dart';
import 'package:docdiary_ios/features/prescription/native_normal_prescription_layout.dart';
import 'normal_prescription_widget_test.dart' as support;
import 'normal_prescription_test_support.dart';
import 'toast_test_support.dart';

void uiCase(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (t) async {
      final shadows = debugDisableShadows;
      debugDisableShadows = false;
      try {
        await body(t);
      } finally {
        debugDisableShadows = shadows;
      }
    });
Future<void> background(WidgetTester t) async {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    t.binding.handleAppLifecycleStateChanged(state);
  }
  await t.pump();
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    t.binding.handleAppLifecycleStateChanged(state);
  }
  await t.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final toasts = ToastRecorder();
  setUp(toasts.install);
  tearDown(toasts.uninstall);
  final contract =
      jsonDecode(
            File(
              'test/fixtures/normal_prescription_native_ui_contract.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  setUpAll(() async {
    for (final f
        in {
          'Poppins': ['Poppins-Regular.ttf', 'Poppins-Bold.ttf'],
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
          'PatuaOne': ['PatuaOne-Regular.ttf'],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
        }.entries) {
      final loader = FontLoader(f.key);
      for (final file in f.value) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  uiCase(
    'native summary uses filled patient boxes and one grouped diagnosis card',
    (t) async {
      final h = NormalRxHarness();
      await support.show(t, h);
      expect(find.text('Prescription'), findsOneWidget);
      expect(find.text('Patient Prescription'), findsNothing);
      final box = t.widget<Container>(
        find.byKey(const ValueKey('rx_readonly_MDT Code:')),
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xfff5f5f5));
      expect(decoration.border, isNull);
      expect(
        find.text('---------------------------------------------------------'),
        findsNWidgets(8),
      );
      final diagnosis =
          find
              .ancestor(
                of: find.byKey(const Key('rx_section_diagnosis')),
                matching: find.byType(Card),
              )
              .first;
      final referral =
          find
              .ancestor(
                of: find.byKey(const Key('rx_section_referral')),
                matching: find.byType(Card),
              )
              .first;
      final service =
          find
              .ancestor(
                of: find.byKey(const Key('rx_section_service')),
                matching: find.byType(Card),
              )
              .first;
      expect(t.widget(diagnosis), same(t.widget(referral)));
      expect(t.widget(diagnosis), same(t.widget(service)));
      expect(find.text('Tap a row to view its details.'), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.cancel), findsWidgets);
      await support.capture(t, 'native_summary');
      await support.finish(t);
    },
  );
  for (final kind in NormalPrescriptionSection.values) {
    final spec = rxSectionSpecs[kind]!,
        expected = contract[kind.name] as Map<String, dynamic>;
    uiCase('${kind.name} table uses the native XML columns and font', (
      t,
    ) async {
      final h = NormalRxHarness();
      await support.show(t, h);
      await support.showTab(t, kind);
      final table = find.byKey(Key('rx_section_${kind.name}'));
      await t.ensureVisible(table);
      await t.pumpAndSettle();
      final labels =
          List<String>.from(
            expected['headers'] as List,
          ).where((s) => s.isNotEmpty).toList();
      expect(labels.length, spec.fields.length);
      for (final label in labels) {
        final header =
            find.descendant(of: table, matching: find.text(label)).first;
        expect(t.widget<Text>(header).style!.fontFamily, 'PatuaOne');
        expect(t.getRect(header).left, greaterThanOrEqualTo(12));
        expect(t.getRect(header).right, lessThanOrEqualTo(381));
      }
      final widths =
          (expected['weights'] as List)
              .map((v) => (v as num).toDouble())
              .toList();
      for (var i = 1; i < labels.length; i++) {
        final a =
            t
                .getCenter(
                  find
                      .descendant(of: table, matching: find.text(labels[i - 1]))
                      .first,
                )
                .dx;
        final b =
            t
                .getCenter(
                  find
                      .descendant(of: table, matching: find.text(labels[i]))
                      .first,
                )
                .dx;
        expect(b, greaterThan(a));
      }
      expect(widths.reduce((a, b) => a + b), 10);
      if (kind == NormalPrescriptionSection.medication) {
        await support.capture(t, 'native_medication_table');
      }
      if (kind == NormalPrescriptionSection.diagnosis) {
        await support.capture(t, 'native_diagnosis_group');
      }
      await support.finish(t);
    });
    for (final update in [false, true]) {
      uiCase(
        '${kind.name} ${update ? "Update" : "Add"} form matches Android XML title, fields and footer',
        (t) async {
          final h = NormalRxHarness();
          await support.show(t, h);
          await support.showTab(t, kind);
          if (update) {
            final key =
                (kind == NormalPrescriptionSection.diagnosis ||
                        kind == NormalPrescriptionSection.referral)
                    ? 'rx_edit_${kind.name}_${700 + kind.index}'
                    : 'rx_row_${kind.name}_${700 + kind.index}';
            await support.tap(t, key);
          } else {
            await support.tap(t, 'rx_add_${kind.name}');
          }
          expect(
            find.text(
              expected[update ? 'update_title' : 'add_title'] as String,
            ),
            findsOneWidget,
          );
          expect(find.byIcon(Icons.close), findsOneWidget);
          expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
          final shell = t.widget<NormalPrescriptionShell>(
            find.byType(NormalPrescriptionShell),
          );
          expect(shell.isEditor, isTrue);
          final labels = List<String>.from(expected['fields'] as List);
          for (var i = 0; i < spec.fields.length; i++) {
            final field = t.widget<TextField>(
              find.byKey(Key('rx_field_${spec.fields[i].header}')),
            );
            expect(field.decoration!.labelText, labels[i]);
            final outer =
                find
                    .ancestor(
                      of: find.byKey(Key('rx_field_${spec.fields[i].header}')),
                      matching: find.byType(Material),
                    )
                    .first;
            expect(
              (t.widget<Material>(outer).shape! as RoundedRectangleBorder)
                  .side
                  .color,
              DocColors.primary,
            );
            expect(field.style!.fontFamily, 'Roboto');
          }
          final save = t.widget<NativeRxActionButton>(
            find.byKey(const Key('rx_save')),
          );
          expect(save.label, update ? 'UPDATE' : 'ADD');
          expect(save.form, isTrue);
          expect(
            t.getRect(find.byKey(const Key('rx_save'))).bottom,
            closeTo(798, 1),
          );
          expect(
            find.byKey(const Key('rx_editor_delete')),
            update && expected['editor_delete'] == true
                ? findsOneWidget
                : findsNothing,
          );
          expect(find.text('Cancel'), findsNothing);
          if (kind == NormalPrescriptionSection.complain) {
            expect(find.byIcon(Icons.calendar_month), findsOneWidget);
          }
          await support.capture(
            t,
            'native_${update ? "update" : "add"}_${kind.name}',
          );
          await support.finish(t);
        },
      );
    }
  }
  uiCase(
    'autocomplete is anchored, can filter duplicates, and sends only the selected ID',
    (t) async {
      final h = NormalRxHarness();
      final previous = h.transport.onGet!;
      h.transport.onGet =
          (uri) =>
              uri.path.endsWith('/getComplain')
                  ? Future.value({
                    'count': 2,
                    'items': [
                      {
                        'cm_id': '201',
                        'cm_name': 'Same complaint',
                        'cm_notes': 'First choice',
                      },
                      {
                        'cm_id': '211',
                        'cm_name': 'Same complaint',
                        'cm_notes': 'Second choice',
                      },
                    ],
                  })
                  : previous(uri);
      await support.show(t, h);
      await support.tap(t, 'rx_row_complain_700');
      await support.tap(t, 'rx_field_P_CM_ID');
      expect(find.byType(AlertDialog), findsNothing);
      final field = find.byKey(const Key('rx_field_P_CM_ID')),
          list = find.byKey(const Key('rx_dropdown_P_CM_ID'));
      expect(t.getTopLeft(list).dy, closeTo(t.getBottomLeft(field).dy, 2));
      await t.enterText(field, 'Same');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('rx_choice_201')), findsOneWidget);
      expect(find.byKey(const Key('rx_choice_211')), findsOneWidget);
      await t.tap(find.byKey(const Key('rx_choice_211')));
      await t.pumpAndSettle();
      await support.tap(t, 'rx_save');
      expect(find.text('Update Complain!'), findsOneWidget);
      await support.capture(t, 'native_update_confirmation');
      await t.tap(find.byKey(const Key('rx_confirm_yes')));
      await t.pumpAndSettle();
      expect(h.posts.single.headers['P_CM_ID'], '211');
      await support.finish(t);
    },
  );
  uiCase(
    'native delete cross confirms against the row title and leaves data on NO',
    (t) async {
      final h = NormalRxHarness();
      await support.show(t, h);
      await support.tap(t, 'rx_delete_complain_700');
      expect(find.text('Do you want to delete this Complain?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Example Complain'),
        ),
        findsOneWidget,
      );
      await support.capture(t, 'native_delete_confirmation');
      await t.tap(find.text('NO'));
      await t.pumpAndSettle();
      expect(h.posts, isEmpty);
      await support.finish(t);
    },
  );
  uiCase('typed unselected lookup text cannot be saved as a name or stale ID', (
    t,
  ) async {
    final h = NormalRxHarness();
    await support.show(t, h);
    await support.tap(t, 'rx_row_complain_700');
    await t.enterText(
      find.byKey(const Key('rx_field_P_CM_ID')),
      'Not a valid selected option',
    );
    await t.pumpAndSettle();
    await support.tap(t, 'rx_save');
    expect(find.byKey(const Key('rx_confirm_yes')), findsNothing);
    expect(h.posts, isEmpty);
    expect(toasts.messages, contains('Please provide Complain.'));
    await support.finish(t);
  });
  uiCase(
    'typing free text closes dropdown on the same ADD tap and opens confirmation',
    (t) async {
      final h = NormalRxHarness();
      await support.show(t, h);
      await support.tap(t, 'rx_tab_advice');
      await support.tap(t, 'rx_add_advice');
      await t.enterText(
        find.byKey(const Key('rx_field_P_PA_NAME')),
        'Example advice',
      );
      await t.pumpAndSettle();
      await support.tap(t, 'rx_save');
      expect(find.text('Add Advice!'), findsOneWidget);
      expect(h.posts, isEmpty);
      await support.finish(t);
    },
  );
  uiCase(
    'background closes autocomplete and preserves the update form without writes',
    (t) async {
      final h = NormalRxHarness();
      await support.show(t, h);
      await support.tap(t, 'rx_row_complain_700');
      await support.tap(t, 'rx_field_P_CM_ID');
      expect(find.byKey(const Key('rx_dropdown_P_CM_ID')), findsOneWidget);
      await background(t);
      expect(find.byKey(const Key('rx_dropdown_P_CM_ID')), findsNothing);
      expect(find.text('Update Complain'), findsOneWidget);
      expect(h.posts, isEmpty);
      await support.finish(t);
    },
  );
  uiCase('optional referral doctor text must be selected before UPDATE', (
    t,
  ) async {
    final h = NormalRxHarness();
    await support.show(t, h);
    await support.tap(t, 'rx_edit_referral_705');
    await t.enterText(
      find.byKey(const Key('rx_field_P_DOC_ID')),
      'Unselected doctor name',
    );
    await t.pumpAndSettle();
    await support.tap(t, 'rx_save');
    expect(find.byKey(const Key('rx_confirm_yes')), findsNothing);
    expect(toasts.messages, contains('Invalid Doctor Name'));
    expect(h.posts, isEmpty);
    await support.finish(t);
  });
  uiCase('portrait filled Age and Marital Status boxes keep equal heights', (
    t,
  ) async {
    final h = NormalRxHarness();
    final previous = h.transport.onGet!;
    h.transport.onGet = (uri) async {
      final response = await previous(uri);
      if (uri.path.endsWith('/getOldPatData')) {
        return {
          'count': 1,
          'items': [
            {
              ...rxPatient(),
              'pat_age': '17 Years 8 Months 6 Days',
              'pat_blood': '',
            },
          ],
        };
      }
      return response;
    };
    await support.show(t, h);
    final age = t.getRect(find.byKey(const ValueKey('rx_readonly_Age:')));
    final marital = t.getRect(
      find.byKey(const ValueKey('rx_readonly_Marital Status:')),
    );
    expect(age.height, closeTo(marital.height, .1));
    expect(
      t.getRect(find.text('17 Years 8 Months 6 Days')).right,
      lessThan(age.right),
    );
    await support.capture(t, 'native_long_age_summary');
    await support.finish(t);
  });
  for (final size in [const Size(393, 852), const Size(852, 393)]) {
    uiCase(
      'native dropdown scrolls to its final choice with keyboard at $size',
      (t) async {
        final h = NormalRxHarness();
        final previous = h.transport.onGet!;
        h.transport.onGet =
            (uri) =>
                uri.path.endsWith('/getDoses')
                    ? Future.value({
                      'count': 40,
                      'items': [
                        for (var i = 1; i <= 40; i++)
                          {'dose_id': '${200 + i}', 'dose_name': 'Option $i'},
                      ],
                    })
                    : previous(uri);
        await support.show(t, h, size: size, scale: 1.4);
        if (size.width > size.height) {
          t.view.padding = const FakeViewPadding(top: 20, bottom: 21);
        }
        await support.tap(t, 'rx_tab_medication');
        await support.tap(t, 'rx_add_medication');
        t.view.viewInsets = const FakeViewPadding(bottom: 150);
        addTearDown(t.view.resetViewInsets);
        await t.pumpAndSettle();
        final field = find.byKey(const Key('rx_field_P_DOSE_ID'));
        await t.ensureVisible(field);
        await t.pumpAndSettle();
        await t.tap(field);
        await t.pumpAndSettle();
        final dropdown = find.byKey(const Key('rx_dropdown_P_DOSE_ID'));
        expect(dropdown, findsOneWidget);
        final rect = t.getRect(dropdown);
        expect(rect.bottom, lessThanOrEqualTo(size.height - 150 + 1));
        expect(rect.top, greaterThanOrEqualTo(0));
        final scrollable = find.descendant(
          of: dropdown,
          matching: find.byType(Scrollable),
        );
        await t.scrollUntilVisible(
          find.byKey(const Key('rx_choice_240')),
          150,
          scrollable: scrollable,
          maxScrolls: 40,
        );
        await t.tap(find.byKey(const Key('rx_choice_240')));
        await t.pumpAndSettle();
        expect(t.widget<TextField>(field).controller!.text, 'Option 40');
        expect(t.takeException(), isNull);
        await support.finish(t);
      },
    );
  }
}

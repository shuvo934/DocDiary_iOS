import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/prescription/normal_prescription_models.dart';
import 'package:docdiary_ios/features/prescription/normal_prescription_screen.dart';
import 'package:docdiary_ios/features/patient_search/normal_patient_search_screen.dart';
import 'package:docdiary_ios/features/prescription/native_normal_prescription_layout.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'normal_prescription_test_support.dart';
import 'toast_test_support.dart';
import 'package:docdiary_ios/features/prescription/normal_prescription_native_style.dart';

Future<void> tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_RX_CAPTURE_DIR'];
  if (dir == null) return;
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('rx_capture')),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$dir/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> show(
  WidgetTester t,
  NormalRxHarness h, {
  bool readOnly = false,
  bool search = false,
  bool app = false,
  Size size = const Size(393, 852),
  double scale = 1,
  bool settle = true,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPadding);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await h.signIn();
  h.transport.requests.clear();
  Widget root;
  if (app) {
    root = DocDiaryApp(
      auth: h.auth,
      initializeOnStart: false,
      dashboard: DashboardRepository(h.transport, now: () => h.now),
    );
  } else {
    addTearDown(h.auth.dispose);
    root = MaterialApp(
      theme: docDiaryTheme(),
      debugShowCheckedModeBanner: false,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
      home:
          search
              ? NormalPatientSearchScreen(auth: h.auth, repository: h.rx)
              : NormalPrescriptionScreen(
                auth: h.auth,
                repository: h.rx,
                seed: readOnly ? h.viewSeed : h.editSeed,
              ),
    );
  }
  await t.pumpWidget(
    RepaintBoundary(key: const Key('rx_capture'), child: root),
  );
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }
  expect(t.takeException(), isNull);
}

Future<void> showTab(WidgetTester t, NormalPrescriptionSection kind) async {
  if ([
    NormalPrescriptionSection.drugHistory,
    NormalPrescriptionSection.clinicalFindings,
    NormalPrescriptionSection.medication,
    NormalPrescriptionSection.advice,
    NormalPrescriptionSection.reference,
  ].contains(kind)) {
    await tap(t, 'rx_tab_${kind.name}');
  }
}

void _nativeCase(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (t) async {
    final shadows = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await body(t);
    } finally {
      debugDisableShadows = shadows;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final toasts = ToastRecorder();
  setUp(toasts.install);
  tearDown(toasts.uninstall);
  setUpAll(() async {
    for (final entry
        in {
          'Poppins': ['Poppins-Regular.ttf', 'Poppins-Bold.ttf'],
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
          'PatuaOne': ['PatuaOne-Regular.ttf'],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
          'Archivo': ['Archivo[wdth,wght].ttf'],
        }.entries) {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  _nativeCase(
    'view mode shares the same layout and never offers write controls',
    (t) async {
      final h = NormalRxHarness();
      await show(t, h, readOnly: true);
      expect(find.byType(NativeNormalPrescriptionLayout), findsOneWidget);
      expect(find.byKey(const Key('rx_view_only')), findsOneWidget);
      expect(find.byKey(const Key('rx_create')), findsNothing);
      for (final kind in NormalPrescriptionSection.values) {
        expect(find.byKey(Key('rx_add_${kind.name}')), findsNothing);
      }
      final layout = t.widget<NativeNormalPrescriptionLayout>(
        find.byType(NativeNormalPrescriptionLayout),
      );
      expect(layout.seed.readOnly, isTrue);
      expect(
        t
            .widget<CheckboxListTile>(find.byKey(const Key('rx_admission')))
            .onChanged,
        isNull,
      );
      expect(h.posts, isEmpty);
      await capture(t, 'view_only');
      await finish(t);
    },
  );
  _nativeCase(
    'view-only long notes render through the final character without clipping',
    (t) async {
      final h = NormalRxHarness();
      final notes = List.filled(25, 'Long existing history details.').join(' ');
      h.entries[NormalPrescriptionSection.medicalHistory] = [
        {
          ...rxEntry(NormalPrescriptionSection.medicalHistory),
          'pmh_details': notes,
        },
      ];
      await show(t, h, readOnly: true);
      final finder = find.text(notes);
      final paragraph = t.renderObject<RenderParagraph>(finder);
      final lastCharacter = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: notes.length - 1, extentOffset: notes.length),
      );
      expect(lastCharacter, isNotEmpty);
      expect(
        lastCharacter.last.bottom,
        lessThanOrEqualTo(paragraph.size.height + 1),
      );
      expect(t.takeException(), isNull);
      await finish(t);
    },
  );

  _nativeCase(
    'create confirm can cancel, and repeated taps issue just one create',
    (t) async {
      final h = NormalRxHarness()..created = false;
      await show(t, h);
      await tap(t, 'rx_create');
      await t.tap(find.text('NO'));
      await t.pumpAndSettle();
      expect(h.posts, isEmpty);
      await tap(t, 'rx_create');
      await t.tap(find.byKey(const Key('rx_confirm_yes')));
      await t.tap(find.byKey(const Key('rx_confirm_yes')), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(
        h.posts
            .where((p) => p.uri.path.endsWith('/insertNewPrescription'))
            .length,
        1,
      );
      expect(find.byKey(const Key('rx_create')), findsNothing);
      await finish(t);
    },
  );
  for (final kind in NormalPrescriptionSection.values) {
    _nativeCase(
      'native ${kind.name} Add opens its fields and can cancel without writes',
      (t) async {
        final h = NormalRxHarness();
        await show(t, h);
        await showTab(t, kind);
        await tap(t, 'rx_add_${kind.name}');
        expect(find.byKey(const Key('rx_editor')), findsOneWidget);
        for (final field in rxSectionSpecs[kind]!.fields) {
          expect(find.byKey(Key('rx_field_${field.header}')), findsOneWidget);
        }
        if (kind == NormalPrescriptionSection.medication) {
          await capture(t, 'add_medication');
        }
        await tap(t, 'normal_prescription_back');
        await t.tap(find.byKey(const Key('rx_confirm_yes')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('rx_editor')), findsNothing);
        expect(h.posts, isEmpty);
        await finish(t);
      },
    );
  }
  _nativeCase(
    'required fields show Fluttertoast feedback and send no API writes',
    (t) async {
      final h = NormalRxHarness();
      await show(t, h);
      await tap(t, 'rx_add_complain');
      await tap(t, 'rx_save');
      expect(toasts.messages, contains('Please Write Complain'));
      expect(h.posts, isEmpty);
      await finish(t);
    },
  );
  _nativeCase(
    'free text advice confirms, saves using native API, and returns to list',
    (t) async {
      final h = NormalRxHarness();
      await show(t, h);
      await tap(t, 'rx_tab_advice');
      await tap(t, 'rx_add_advice');
      await t.enterText(
        find.byKey(const Key('rx_field_P_PA_NAME')),
        'Example saved advice',
      );
      await tap(t, 'rx_save');
      await t.tap(find.byKey(const Key('rx_confirm_yes')));
      await t.pumpAndSettle();
      expect(h.posts.single.uri.path, endsWith('/prescription/insertAdvice'));
      expect(h.posts.single.headers, {
        'P_PMM_ID': '90',
        'P_PA_NAME': 'Example saved advice',
      });
      expect(find.byKey(const Key('rx_editor')), findsNothing);
      expect(find.text('Example saved advice'), findsOneWidget);
      await capture(t, 'saved_advice');
      await finish(t);
    },
  );
  _nativeCase(
    'update preloads current fields even if choice is absent from lookup list',
    (t) async {
      final h = NormalRxHarness();
      await show(t, h);
      await tap(t, 'rx_row_complain_700');
      expect(
        t
            .widget<TextField>(find.byKey(const Key('rx_field_P_CM_ID')))
            .controller!
            .text,
        'Example Complain',
      );
      await tap(t, 'rx_field_P_CM_ID');
      expect(find.byKey(const Key('rx_choice_100')), findsOneWidget);
      await t.tapAt(const Offset(2, 2));
      await t.pumpAndSettle();
      await capture(t, 'edit_injury');
      await finish(t);
    },
  );
  _nativeCase('delete requires confirmation and refreshes the saved section', (
    t,
  ) async {
    final h = NormalRxHarness();
    await show(t, h);
    await tap(t, 'rx_delete_complain_700');
    await t.tap(find.text('NO'));
    await t.pumpAndSettle();
    expect(h.posts, isEmpty);
    await tap(t, 'rx_delete_complain_700');
    await t.tap(find.byKey(const Key('rx_confirm_yes')));
    await t.pumpAndSettle();
    expect(h.posts.single.headers, {'P_PCI_ID': '700'});
    expect(find.byKey(const Key('rx_row_complain_700')), findsNothing);
    await finish(t);
  });
  _nativeCase(
    'a write timeout retains draft and requires a read before retry',
    (t) async {
      final h = NormalRxHarness();
      await show(t, h);
      await tap(t, 'rx_tab_advice');
      await tap(t, 'rx_add_advice');
      await t.enterText(
        find.byKey(const Key('rx_field_P_PA_NAME')),
        'Keep this draft',
      );
      h.transport.onPost =
          (_, _) async => throw const AppFailure('Connection timed out');
      await tap(t, 'rx_save');
      await t.tap(find.byKey(const Key('rx_confirm_yes')));
      await t.pumpAndSettle();
      expect(h.posts.length, 1);
      expect(
        t
            .widget<TextField>(find.byKey(const Key('rx_field_P_PA_NAME')))
            .controller!
            .text,
        'Keep this draft',
      );
      expect(
        t
            .widget<NativeRxActionButton>(find.byKey(const Key('rx_save')))
            .onPressed,
        isNull,
      );
      await tap(t, 'rx_error_reload');
      expect(
        t
            .widget<NativeRxActionButton>(find.byKey(const Key('rx_save')))
            .onPressed,
        isNotNull,
      );
      expect(h.posts.length, 1);
      await finish(t);
    },
  );
  _nativeCase(
    'child data hides both edit and delete on protected parent rows',
    (t) async {
      final h = NormalRxHarness();
      h.entries[NormalPrescriptionSection.diagnosis] = [
        {...rxEntry(NormalPrescriptionSection.diagnosis), 'child_count': '1'},
      ];
      h.entries[NormalPrescriptionSection.referral] = [
        {...rxEntry(NormalPrescriptionSection.referral), 'child_count': '1'},
      ];
      await show(t, h);
      expect(find.byKey(const Key('rx_edit_diagnosis_704')), findsNothing);
      expect(find.byKey(const Key('rx_delete_diagnosis_704')), findsNothing);
      expect(find.byKey(const Key('rx_edit_referral_705')), findsNothing);
      await finish(t);
    },
  );
  for (final size in [
    const Size(280, 568),
    const Size(852, 393),
    const Size(768, 1024),
  ]) {
    _nativeCase('summary and editor stay usable at $size with large text', (
      t,
    ) async {
      final h = NormalRxHarness();
      await show(t, h, size: size, scale: 1.8);
      await capture(t, 'summary_${size.width.toInt()}');
      await tap(t, 'rx_tab_medication');
      await tap(t, 'rx_add_medication');
      await tap(t, 'rx_field_P_DOSE_ID');
      await t.tapAt(const Offset(2, 2));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('rx_save')));
      expect(t.takeException(), isNull);
      await finish(t);
    });
  }
  _nativeCase(
    'slow prescription request keeps spinner on white content surface',
    (t) async {
      final h = NormalRxHarness();
      final old = h.transport.onGet!;
      final pending = Completer<JsonMap>();
      h.transport.onGet =
          (u) => u.path.endsWith('/getOldPatData') ? pending.future : old(u);
      await show(t, h, settle: false);
      expect(
        find.byKey(const Key('normal_prescription_loading')),
        findsOneWidget,
      );
      await t.pump(const Duration(seconds: 20));
      expect(
        find.byKey(const Key('normal_prescription_loading')),
        findsOneWidget,
      );
      await capture(t, 'loading');
      pending.complete({
        'count': 1,
        'items': [rxPatient()],
      });
      await t.pumpAndSettle();
      expect(
        find.byKey(const Key('normal_prescription_loading')),
        findsNothing,
      );
      await finish(t);
    },
  );
  _nativeCase(
    'PatientSearch filters name/code and opens the shared view-only prescription',
    (t) async {
      final h = NormalRxHarness();
      await show(t, h, search: true);
      await t.enterText(
        find.byKey(const Key('normal_patient_search')),
        'missing',
      );
      await t.pumpAndSettle();
      expect(find.text("No Patient's Prescription Found"), findsOneWidget);
      await t.enterText(find.byKey(const Key('normal_patient_search')), 'p-11');
      await t.pumpAndSettle();
      await tap(t, 'patient_search_prescription_11');
      expect(find.byKey(const Key('rx_view_only')), findsOneWidget);
      expect(h.posts, isEmpty);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(find.byType(NormalPrescriptionScreen), findsOneWidget);
      await finish(t);
    },
  );
  _nativeCase(
    'appointment opens the shared editor and preserves the calendar on Back',
    (t) async {
      final h = NormalRxHarness();
      await show(t, h, app: true);
      await tap(t, 'dashboard_nav_appointment');
      final first = find.byKey(
        const Key('doctor_appointment_0_legacyPrescription'),
      );
      expect(first, findsOneWidget);
      await tap(t, 'doctor_appointment_0_legacyPrescription');
      expect(find.byType(NormalPrescriptionScreen), findsOneWidget);
      expect(find.byKey(const Key('rx_view_only')), findsNothing);
      await tap(t, 'normal_prescription_back');
      expect(find.byType(NormalPrescriptionScreen), findsNothing);
      expect(h.posts, isEmpty);
      await finish(t);
    },
  );
}

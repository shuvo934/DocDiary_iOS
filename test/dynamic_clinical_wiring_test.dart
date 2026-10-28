import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/doctor_appointment_models.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/doctor_appointment_navigation.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/doctor_appointment_screen.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/auth/login_screen.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_clinical_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_clinical_screen.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_repository.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_seed.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_clinical_tab.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_rx_tab.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_rx_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_rx_controls.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_advice_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_advice_tab.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_rx_sheets.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_review_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'doctor_appointment_test_support.dart';
import 'dynamic_rx_test_support.dart';
import 'dynamic_advice_test_support.dart';
import 'dynamic_review_test_support.dart';
import 'dynamic_template_test_support.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_template_sheet.dart';

class _Harness extends DoctorAppointmentHarness {
  _Harness() {
    doctorData['med_active'] = '1';
    transport.onGet = respond;
  }
  bool failExisting = false, failPatient = false;
  bool failRx = false;
  bool failAdvice = false;
  bool failTemplate = false;
  bool existingTemplates = false;
  Completer<JsonMap>? pendingTemplate;
  String patientName = 'Sample Patient';
  Completer<JsonMap>? pendingProfile;
  Completer<JsonMap>? pendingExisting;
  JsonMap get existingData => {
    'rvm_id': 900,
    'rvm_code': '2600900',
    'td_name': 'Disease template',
    if (existingTemplates) 'td_id': '701',
    if (existingTemplates) 'tt_id': '801',
    if (existingTemplates) 'tt_name': 'Exercise Plan',
    'complaints': [
      {'cm_id': 1, 'name': 'Existing complain'},
    ],
    'vitals': {'pulse': '72'},
    ...rxExistingData(),
    ...adviceExistingData(),
  };
  Future<JsonMap> respond(Uri uri) async {
    if (pendingProfile != null && uri.path.endsWith('/getDocData')) {
      return pendingProfile!.future;
    }
    if (!uri.path.contains('/dynamic_presc/')) return respondAppointments(uri);
    final endpoint = uri.pathSegments.last;
    if (endpoint == 'getPrescription') {
      if (pendingExisting != null) return pendingExisting!.future;
      if (failExisting) {
        return {'status': 500, 'message': 'Prescription lookup failed'};
      }
      return {'status': 200, 'data': existingData};
    }
    if (endpoint == 'getDiseaseTemplate' ||
        endpoint == 'getTreatmentTemplate') {
      final treatment = endpoint == 'getTreatmentTemplate',
          prefix = treatment ? 'tt' : 'td';
      return {
        'items': [
          for (final item in treatment ? treatmentTemplates : diseaseTemplates)
            {
              '${prefix}_id': item.id,
              '${prefix}_name': item.name,
              '${prefix}_description': item.description,
            },
        ],
      };
    }
    if (endpoint == 'loadDiseaseTemplate' ||
        endpoint == 'loadTreatmentTemplate') {
      if (pendingTemplate != null) {
        return pendingTemplate!.future;
      }
      if (failTemplate) {
        return {'status': 500, 'message': 'Template data unavailable'};
      }
      return {
        'status': 200,
        'data':
            endpoint == 'loadDiseaseTemplate'
                ? diseaseTemplateData()
                : treatmentTemplateData(),
      };
    }
    if (endpoint == 'getPatDetails') {
      if (failPatient) throw const AppFailure('Patient lookup failed');
      return {
        'items': [
          {
            'pat_name': 'Sample Patient',
            'ph_sub_code': 'P-11',
            'pat_age': '35 Years',
            'gender': 'Female',
            'address': 'Test address',
            'pat_phone': null,
          },
        ],
      };
    }
    if (endpoint == 'getComplain') {
      return {
        'items': [
          {'cm_id': 1, 'cm_name': 'Existing complain'},
          {'cm_id': 2, 'cm_name': 'Neck pain'},
        ],
      };
    }
    if (endpoint == 'getObjective') {
      return {
        'items': [
          {'om_id': 10, 'om_name': 'ROM'},
        ],
      };
    }
    if (endpoint == 'getObjectiveValue') {
      return {
        'items': [
          {'od_id': 11, 'od_name': 'Flexion'},
        ],
      };
    }
    if (failRx && uri.pathSegments.last == 'getDoses') {
      throw const AppFailure('Dose lookup failed');
    }
    if (['getAdvice', 'getFollowUp', 'getSpecialAlert'].contains(endpoint)) {
      if (failAdvice && endpoint == 'getAdvice') {
        throw const AppFailure('Advice lookup failed');
      }
      return adviceOptionResponse(uri);
    }
    return rxOptionResponse(uri);
  }

  DynamicPrescriptionRepository get dynamicRepository =>
      DynamicPrescriptionRepository(appointments);
  DynamicPrescriptionSeed seed({bool existing = false, String? date}) =>
      DynamicPrescriptionSeed.fromExtras({
        ...doctorAppointmentRoute(
          DoctorAppointmentAction.dynamicPrescription,
          DoctorAppointmentRow({
            ...doctorAppointmentRow(name: patientName),
            'rvm': existing ? '1' : '0',
            if (date != null) 'adm_date': date,
          }, selectedDate: now),
        ).extras,
      }, ownerDoctorId: '10');
  List<Uri> get dynamicReads =>
      transport.requests
          .where((r) => r.uri.path.contains('/dynamic_presc/'))
          .map((r) => r.uri)
          .toList();
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

Future<void> _show(
  WidgetTester tester,
  _Harness harness, {
  bool timeline = false,
  bool existing = false,
  bool durationRequired = false,
  Size size = const Size(393, 852),
  DashboardDestinationBuilder? destinationBuilder,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await harness.signIn();
  harness.transport.requests.clear();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: docDiaryTheme(),
      home: Builder(
        builder: (context) {
          final Widget page =
              timeline
                  ? DoctorAppointmentScreen(
                    auth: harness.auth,
                    repository: harness.appointments,
                    destinationBuilder: destinationBuilder,
                  )
                  : DynamicPrescriptionClinicalScreen(
                    auth: harness.auth,
                    repository: harness.dynamicRepository,
                    seed: harness.seed(existing: existing),
                    durationRequired: durationRequired,
                  );
          return Scaffold(
            body: TextButton(
              key: const Key('open_appointments'),
              onPressed: () {
                unawaited(
                  Navigator.of(
                    context,
                  ).push<void>(MaterialPageRoute(builder: (_) => page)),
                );
              },
              child: const Text('Open appointments'),
            ),
          );
        },
      ),
    ),
  );
  await _tap(tester, 'open_appointments');
}

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
        'PatuaOne': ['PatuaOne-Regular.ttf'],
        'Archivo': ['Archivo[wdth,wght].ttf'],
      }.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      loader.addFont(rootBundle.load('assets/fonts/$file'));
    }
    await loader.load();
  }
}

Future<void> _captureRx(WidgetTester tester, String name) async {
  const rxOutput = String.fromEnvironment('DYNAMIC_RX_STAGE2_RENDER_DIR');
  const adviceOutput = String.fromEnvironment('DYNAMIC_ADVICE_RENDER_DIR');
  const templateOutput = String.fromEnvironment('DYNAMIC_TEMPLATE_RENDER_DIR');
  const reviewOutput = String.fromEnvironment('DYNAMIC_REVIEW_RENDER_DIR');
  final output =
      templateOutput.isNotEmpty
          ? templateOutput
          : reviewOutput.isNotEmpty
          ? reviewOutput
          : (adviceOutput.isNotEmpty ? adviceOutput : rxOutput);
  if (output.isEmpty) return;
  final context = tester.element(
    find.byType(DynamicPrescriptionClinicalScreen),
  );
  await tester.runAsync(() async {
    for (final name in [
      'dy_rx_patient',
      'dy_rx_stethoscope',
      'dy_rx_diagnosis',
      'dy_rx_medicine',
      'dy_rx_chemistry',
      'dy_rx_caution',
      'dy_rx_pill',
      'dy_rx_treatment_plan',
      'dy_builder_medical_record',
      'dy_builder_prescription_prv',
      'dy_builder_template',
    ]) {
      await precacheImage(AssetImage('assets/images/$name.png'), context);
    }
  });
  final before = debugDisableShadows;
  void repaint(RenderObject object) {
    object.markNeedsPaint();
    object.visitChildren(repaint);
  }

  try {
    debugDisableShadows = false;
    repaint(tester.binding.renderViews.first);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final render = tester.binding.renderViews.first,
          folder = Directory(output);
      final image = await (render.debugLayer! as OffsetLayer).toImage(
        Offset.zero & render.size,
        pixelRatio: 3,
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await folder.create(recursive: true);
      await File(
        '${folder.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  } finally {
    debugDisableShadows = before;
  }
}

Future<void> _review(WidgetTester tester, {bool addPlan = false}) async {
  await _tap(tester, 'dy_builder_tab_RX');
  if (addPlan) {
    tester
        .widget<NativeDynamicRxTab>(find.byType(NativeDynamicRxTab))
        .draft
        .saveTreatmentPlan(
          DynamicTreatmentPlanEntry(text: 'Local treatment plan'),
        );
    await tester.pumpAndSettle();
  }
  await _tap(tester, 'dy_builder_tab_REVIEW');
}

Future<void> _confirm(WidgetTester tester) => _tap(tester, 'dy_review_confirm');

void main() {
  setUpAll(_fonts);
  group('scheduled Clinical repository', () {
    late _Harness h;
    setUp(() async {
      h = _Harness();
      await h.signIn();
      h.transport.requests.clear();
    });
    tearDown(() => h.auth.dispose());
    test(
      'seed matches native scheduled extras; past dates and walk-in cannot enter this stage',
      () {
        final seed = h.seed(existing: true);
        expect(seed.patientHistoryId, '11');
        expect(seed.patientId, '21');
        expect(seed.appointmentId, '41');
        expect(seed.details, 'Female • 35 Years');
        expect(seed.existing, isTrue);
        expect(seed.editableOn(h.now), isTrue);
        expect(h.seed(date: '23-OCT-26').editableOn(h.now), isFalse);
        expect(
          DynamicPrescriptionSeed.fromExtras({
            'P_PAT_TYPE': '2',
          }, ownerDoctorId: '10').valid,
          isFalse,
        );
      },
    );
    test('new prescription does not call getPrescription', () async {
      expect(
        await h.dynamicRepository.existing(
          h.auth.session!,
          h.auth.profile!,
          h.seed(),
          isCurrent: () => true,
        ),
        isEmpty,
      );
      expect(h.dynamicReads, isEmpty);
      expect(h.posts, isEmpty);
    });
    test(
      'existing prescription uses exact native identities and requires status/data/rvm_id',
      () async {
        final data = await h.dynamicRepository.existing(
          h.auth.session!,
          h.auth.profile!,
          h.seed(existing: true),
          isCurrent: () => true,
        );
        expect(data['rvm_id'], 900);
        expect(h.dynamicReads.single.queryParameters, {
          'p_ph_id': '11',
          'p_pat_id': '21',
          'p_ad_id': '41',
        });
        h.failExisting = true;
        await expectLater(
          h.dynamicRepository.existing(
            h.auth.session!,
            h.auth.profile!,
            h.seed(existing: true),
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
        h.transport.onGet = (_) async => {'status': 200, 'data': {}};
        await expectLater(
          h.dynamicRepository.existing(
            h.auth.session!,
            h.auth.profile!,
            h.seed(existing: true),
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
      },
    );
    test('patient details use ph_id; an empty response is an error', () async {
      final row = await h.dynamicRepository.patientDetails(
        h.auth.session!,
        h.auth.profile!,
        h.seed(),
        isCurrent: () => true,
      );
      expect(row['pat_name'], 'Sample Patient');
      expect(h.dynamicReads.single.queryParameters, {'p_ph_id': '11'});
      h.transport.onGet = (_) async => {'items': []};
      await expectLater(
        h.dynamicRepository.patientDetails(
          h.auth.session!,
          h.auth.profile!,
          h.seed(),
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
    });
    test(
      'stale completions and an expired appointment cannot publish Clinical data',
      () async {
        h.pendingExisting = Completer<JsonMap>();
        var current = true;
        final loading = h.dynamicRepository.existing(
          h.auth.session!,
          h.auth.profile!,
          h.seed(existing: true),
          isCurrent: () => current,
        );
        current = false;
        h.pendingExisting!.complete({'status': 200, 'data': h.existingData});
        await expectLater(loading, throwsA(isA<ObsoleteRequest>()));
        h.transport.requests.clear();
        await expectLater(
          h.dynamicRepository.existing(
            h.auth.session!,
            h.auth.profile!,
            h.seed(date: '23-OCT-26'),
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
        expect(h.dynamicReads, isEmpty);
        expect(h.posts, isEmpty);
      },
    );
  });

  testWidgets(
    'today timeline Dynamic button opens Clinical screen with exact patient, new draft and no POST',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, timeline: true);
      await _tap(tester, 'doctor_appointment_1_dynamicPrescription');
      expect(find.byType(DynamicPrescriptionClinicalScreen), findsOneWidget);
      expect(find.byType(NativeDynamicClinicalTab), findsOneWidget);
      expect(
        find.byKey(const Key('doctor_appointment_unavailable')),
        findsNothing,
      );
      expect(find.text('Sample Patient'), findsOneWidget);
      expect(find.text('Date: 24-OCT-26'), findsOneWidget);
      expect(
        h.dynamicReads.any((uri) => uri.pathSegments.last == 'getPrescription'),
        isFalse,
      );
      await _tap(tester, 'dy_add_complain');
      await tester.enterText(
        find.byKey(const Key('dy_field_entry')),
        'New clinical detail',
      );
      await _tap(tester, 'dy_action_ADD COMPLAIN');
      expect(find.text('New clinical detail'), findsOneWidget);
      expect(h.posts, isEmpty);
      await _tap(tester, 'dy_builder_back');
      expect(find.byKey(const Key('dy_unsaved')), findsOneWidget);
      await _tap(tester, 'dy_keep_editing');
      expect(find.text('New clinical detail'), findsOneWidget);
      await _tap(tester, 'dy_builder_back');
      await _tap(tester, 'dy_discard');
      expect(find.byType(DynamicPrescriptionClinicalScreen), findsNothing);
      expect(find.byType(DoctorAppointmentScreen), findsOneWidget);
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  testWidgets(
    'existing timeline prescription hydrates its Clinical draft and Back without edits returns immediately',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, timeline: true);
      await _tap(tester, 'doctor_appointment_0_dynamicPrescription');
      expect(find.text('Visit: 2600900'), findsOneWidget);
      await _tap(tester, 'dy_toggle_complain');
      expect(find.text('Existing complain'), findsOneWidget);
      expect(find.text('Pulse: 72 bpm'), findsOneWidget);
      final request = h.dynamicReads.singleWhere(
        (uri) => uri.pathSegments.last == 'getPrescription',
      );
      expect(request.queryParameters['p_ad_id'], '1');
      await _tap(tester, 'dy_builder_back');
      expect(find.byKey(const Key('dy_unsaved')), findsNothing);
      expect(find.byType(DoctorAppointmentScreen), findsOneWidget);
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  testWidgets('the existing destinationBuilder override retains priority', (
    tester,
  ) async {
    final h = _Harness();
    DashboardRoute? captured;
    await _show(
      tester,
      h,
      timeline: true,
      destinationBuilder: (context, route) {
        if (route.module != DashboardModule.doctorPrescriptionBuilder) {
          return null;
        }
        captured = route;
        return const Scaffold(body: Text('Existing injected destination'));
      },
    );
    await _tap(tester, 'doctor_appointment_1_dynamicPrescription');
    expect(find.text('Existing injected destination'), findsOneWidget);
    expect(captured!.extras['P_AD_ID'], '2');
    expect(h.dynamicReads, isEmpty);
    await tester.pumpWidget(const SizedBox());
    h.auth.dispose();
  });
  testWidgets(
    'patient summary opens native Details, skips empty rows and supports tap-to-retry',
    (tester) async {
      final h = _Harness();
      await _show(tester, h);
      h.failPatient = true;
      await _tap(tester, 'dy_builder_patient');
      expect(find.text('Patient lookup failed\nTap to retry'), findsOneWidget);
      h.failPatient = false;
      await _tap(tester, 'dy_patient_retry');
      expect(find.text('Patient Name'), findsOneWidget);
      expect(find.text('Phone Number'), findsNothing);
      await _tap(tester, 'dy_action_CLOSE');
      expect(find.byType(NativeDynamicClinicalTab), findsOneWidget);
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  testWidgets(
    'existing load failure keeps editor closed, Retry loads real data and never sends POST',
    (tester) async {
      final h = _Harness()..failExisting = true;
      await _show(tester, h, existing: true);
      expect(find.byKey(const Key('dy_builder_error')), findsOneWidget);
      expect(find.byType(NativeDynamicClinicalTab), findsNothing);
      h.failExisting = false;
      await _tap(tester, 'dy_builder_error_retry');
      expect(find.byType(NativeDynamicClinicalTab), findsOneWidget);
      await _tap(tester, 'dy_toggle_complain');
      expect(find.text('Existing complain'), findsOneWidget);
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  testWidgets(
    'error Exit closes the child and refreshes the same appointment date',
    (tester) async {
      final h = _Harness()..failExisting = true;
      await _show(tester, h, timeline: true);
      await _tap(tester, 'doctor_appointment_0_dynamicPrescription');
      h.transport.requests.clear();
      await _tap(tester, 'dy_builder_error_exit');
      expect(find.byType(DynamicPrescriptionClinicalScreen), findsNothing);
      expect(
        h.appointmentReads.single.uri.queryParameters['pdate'],
        '24-OCT-26',
      );
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  testWidgets(
    'background/resume rechecks access and preserves entered Clinical draft',
    (tester) async {
      final h = _Harness();
      await _show(tester, h);
      await _tap(tester, 'dy_add_complain');
      await tester.enterText(
        find.byKey(const Key('dy_field_entry')),
        'Preserved draft',
      );
      await _tap(tester, 'dy_action_ADD COMPLAIN');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      final tab = tester.widget<NativeDynamicClinicalTab>(
        find.byType(NativeDynamicClinicalTab),
      );
      expect(
        tab.draft.entries(DynamicClinicalType.complain).single.text,
        'Preserved draft',
      );
      if (find.text('Preserved draft').evaluate().isEmpty) {
        await _tap(tester, 'dy_toggle_complain');
      }
      expect(find.text('Preserved draft'), findsOneWidget);
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  testWidgets(
    'system Back dismisses the owned sheet before leaving the builder',
    (tester) async {
      final h = _Harness();
      await _show(tester, h);
      await _tap(tester, 'dy_add_complain');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Add Complain'), findsNothing);
      expect(find.byType(DynamicPrescriptionClinicalScreen), findsOneWidget);
      await _tap(tester, 'dy_builder_back');
      expect(find.byType(DynamicPrescriptionClinicalScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  testWidgets(
    'logout closes Clinical sheets and does not leave patient information on another route',
    (tester) async {
      final h = _Harness();
      await h.signIn();
      h.transport.requests.clear();
      await tester.pumpWidget(
        DocDiaryApp(
          auth: h.auth,
          initializeOnStart: false,
          dashboard: DashboardRepository(h.transport, now: () => h.now),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'dashboard_nav_appointment');
      await _tap(tester, 'doctor_appointment_1_dynamicPrescription');
      await _tap(tester, 'dy_add_complain');
      await h.auth.logout();
      await tester.pumpAndSettle();
      expect(find.text('Add Complain'), findsNothing);
      expect(find.byType(DynamicPrescriptionClinicalScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'small iPhone viewport retains native header and opens the Rx stage',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, size: const Size(320, 640));
      expect(
        find.byKey(const Key('dy_builder_back')).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('dy_action_NEXT: RX')))
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('dy_builder_history')))
            .onPressed,
        isNull,
      );
      await _tap(tester, 'dy_add_vitals');
      await _tap(tester, 'dy_action_CANCEL');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  testWidgets(
    'complete scheduled Clinical screen can render for native comparison',
    (tester) async {
      final h = _Harness();
      await _show(tester, h);
      const output = String.fromEnvironment('DYNAMIC_RX_WIRING_RENDER_DIR');
      if (output.isNotEmpty) {
        final context = tester.element(
          find.byType(DynamicPrescriptionClinicalScreen),
        );
        await tester.runAsync(() async {
          for (final name in [
            'dy_rx_patient',
            'dy_rx_diagnosis',
            'dy_rx_medicine',
            'dy_rx_chemistry',
            'dy_rx_caution',
            'dy_builder_medical_record',
            'dy_builder_prescription_prv',
            'dy_builder_template',
          ]) {
            await precacheImage(AssetImage('assets/images/$name.png'), context);
          }
        });
        final before = debugDisableShadows;
        try {
          debugDisableShadows = false;
          void repaint(RenderObject object) {
            object.markNeedsPaint();
            object.visitChildren(repaint);
          }

          final boundary = tester.binding.renderViews.first;
          repaint(boundary);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final render = tester.binding.renderViews.first;
            final layer = render.debugLayer! as OffsetLayer;
            final snapshot = await layer.toImage(
              Offset.zero & render.size,
              pixelRatio: 3,
            );
            final bytes = await snapshot.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final folder = Directory(output);
            await folder.create(recursive: true);
            await File(
              '${folder.path}/scheduled_clinical_screen.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            snapshot.dispose();
          });
        } finally {
          debugDisableShadows = before;
        }
      }
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'NEXT opens Rx; saved Medicine and Clinical data survive tab taps and native page swipes without refetch',
    (tester) async {
      final h = _Harness();
      await _show(tester, h);
      final catalogueReads = h.dynamicReads.length;
      await _tap(tester, 'dy_action_NEXT: RX');
      expect(
        find.byKey(const Key('dy_add_medicine')).hitTestable(),
        findsOneWidget,
      );
      await _tap(tester, 'dy_add_medicine');
      await tester.enterText(
        find.byKey(const Key('dy_field_rx_medicine')),
        'Sample medicine',
      );
      await _tap(tester, 'dy_action_ADD MEDICINE');
      expect(find.text('Dose: 0+0+1'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('dy_action_NEXT: ADVICE')),
            )
            .onPressed,
        isNotNull,
      );
      await _tap(tester, 'dy_builder_tab_CLINICAL');
      await _tap(tester, 'dy_add_complain');
      await tester.enterText(
        find.byKey(const Key('dy_field_entry')),
        'Clinical draft stays',
      );
      await _tap(tester, 'dy_action_ADD COMPLAIN');
      await _tap(tester, 'dy_builder_tab_RX');
      expect(find.text('Dose: 0+0+1'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(320, 0));
      await tester.pumpAndSettle();
      expect(find.text('Clinical draft stays').hitTestable(), findsOneWidget);
      expect(h.dynamicReads, hasLength(catalogueReads));
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'existing Rx loads all native rows and edit changes participate in the unsaved dialog',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, existing: true);
      await _tap(tester, 'dy_builder_tab_RX');
      final rx = tester.widget<NativeDynamicRxTab>(
        find.byType(NativeDynamicRxTab),
      );
      expect(rx.draft.medicines.single.duration, '7');
      expect(rx.draft.therapies.single.notes, 'থেরাপির নোট');
      expect(rx.draft.treatmentPlans, hasLength(2));
      await _tap(tester, 'dy_edit_${rx.draft.medicines.single.localId}');
      await tester.enterText(
        find.byKey(const Key('dy_field_rx_duration')),
        '10',
      );
      await _tap(tester, 'dy_action_UPDATE MEDICINE');
      expect(find.text('Duration: 10 Days'), findsOneWidget);
      await _tap(tester, 'dy_builder_back');
      expect(find.byKey(const Key('dy_unsaved')), findsOneWidget);
      await _tap(tester, 'dy_keep_editing');
      expect(rx.draft.medicines.single.duration, '10');
      await _tap(tester, 'dy_rx_segment_therapy');
      expect(find.text('Sample therapy'), findsOneWidget);
      await _tap(tester, 'dy_toggle_treatment_plan');
      expect(find.text('Custom plan'), findsOneWidget);
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'Clinical/Rx scroll and expanded sections remain mounted across tab changes and delayed resume check',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, existing: true, size: const Size(393, 690));
      final clinical = tester.widget<NativeDynamicClinicalTab>(
        find.byType(NativeDynamicClinicalTab),
      );
      final clinicalScroll =
          tester
              .widget<SingleChildScrollView>(
                find.byKey(
                  const PageStorageKey<String>('dynamic_clinical_scroll'),
                ),
              )
              .controller!;
      clinicalScroll.jumpTo(280);
      await tester.pumpAndSettle();
      final clinicalOffset = clinicalScroll.offset;
      await _tap(tester, 'dy_builder_tab_RX');
      final rx = tester.widget<NativeDynamicRxTab>(
        find.byType(NativeDynamicRxTab),
      );
      await _tap(tester, 'dy_toggle_treatment_plan');
      for (var i = 0; i < 12; i++) {
        rx.draft.saveTreatmentPlan(
          DynamicTreatmentPlanEntry(text: 'Extra plan $i'),
        );
      }
      await tester.pumpAndSettle();
      final rxScroll =
          tester
              .widget<SingleChildScrollView>(
                find.byKey(const PageStorageKey<String>('dynamic_rx_scroll')),
              )
              .controller!;
      rxScroll.jumpTo(420);
      await tester.pumpAndSettle();
      final rxOffset = rxScroll.offset;
      final reads = h.dynamicReads.length;
      h.pendingProfile = Completer<JsonMap>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        identical(
          tester
              .widget<NativeDynamicRxTab>(find.byType(NativeDynamicRxTab))
              .draft,
          rx.draft,
        ),
        isTrue,
      );
      expect(rxScroll.hasClients, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      h.pendingProfile!.complete({
        'items': [h.doctorData],
      });
      await tester.pumpAndSettle();
      expect(rxScroll.offset, closeTo(rxOffset, .1));
      await _tap(tester, 'dy_builder_tab_CLINICAL');
      expect(clinicalScroll.offset, closeTo(clinicalOffset, .1));
      expect(
        identical(
          tester
              .widget<NativeDynamicClinicalTab>(
                find.byType(NativeDynamicClinicalTab),
              )
              .draft,
          clinical.draft,
        ),
        isTrue,
      );
      await _tap(tester, 'dy_builder_tab_RX');
      expect(rxScroll.offset, closeTo(rxOffset, .1));
      expect(h.dynamicReads, hasLength(reads));
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'resume applies medicine permission change without deleting Rx draft or blocking the account',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, existing: true);
      await _tap(tester, 'dy_builder_tab_RX');
      h.doctorData['med_active'] = '0';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      final rx = tester.widget<NativeDynamicRxTab>(
        find.byType(NativeDynamicRxTab),
      );
      expect(rx.medicineAllowed, isFalse);
      expect(rx.draft.medicines, hasLength(1));
      expect(find.byKey(const Key('dy_add_medicine')), findsNothing);
      expect(find.text('Sample therapy'), findsOneWidget);
      expect(h.auth.stage.name, 'authenticated');
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'failed Rx catalogue offers Retry and cannot expose a partially initialized editor',
    (tester) async {
      final h = _Harness()..failRx = true;
      await _show(tester, h);
      expect(find.byKey(const Key('dy_builder_error')), findsOneWidget);
      expect(find.byType(NativeDynamicRxTab), findsNothing);
      h.failRx = false;
      await _tap(tester, 'dy_builder_error_retry');
      await _tap(tester, 'dy_builder_tab_RX');
      expect(find.text('No medicine added'), findsOneWidget);
      await _tap(tester, 'dy_builder_back');
      expect(find.byKey(const Key('dy_unsaved')), findsNothing);
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'logout dismisses Rx edit sheets and removes patient data from the real app',
    (tester) async {
      final h = _Harness();
      await h.signIn();
      await tester.pumpWidget(
        DocDiaryApp(
          auth: h.auth,
          initializeOnStart: false,
          dashboard: DashboardRepository(h.transport, now: () => h.now),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'dashboard_nav_appointment');
      await _tap(tester, 'doctor_appointment_1_dynamicPrescription');
      await _tap(tester, 'dy_builder_tab_RX');
      await _tap(tester, 'dy_add_medicine');
      await h.auth.logout();
      await tester.pumpAndSettle();
      expect(find.text('Add Medicine'), findsNothing);
      expect(find.byType(DynamicPrescriptionClinicalScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'uploaded right-aligned Visit/Date and long patient name fit the small iPhone card',
    (tester) async {
      final h =
          _Harness()
            ..patientName =
                'A very long patient name with several words that needs ellipsis';
      await _show(tester, h, existing: true, size: const Size(320, 640));
      final patient = find.byKey(const Key('dy_builder_patient'));
      final dateTag =
          find
              .ancestor(
                of: find.text('Date: 24-OCT-26'),
                matching: find.byType(ColoredBox),
              )
              .first;
      final m = DynamicRxMetrics(tester.element(patient));
      expect(
        tester.getRect(dateTag).right,
        closeTo(tester.getRect(patient).right - m.d(10), .1),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('dy_builder_patient_name')))
            .overflow,
        TextOverflow.ellipsis,
      );
      await _tap(tester, 'dy_builder_tab_RX');
      await _tap(tester, 'dy_rx_segment_therapy');
      expect(
        find.byKey(const Key('dy_add_therapy')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets('full native Rx screen renders with the uploaded builder UI', (
    tester,
  ) async {
    final h = _Harness();
    await _show(tester, h);
    await _tap(tester, 'dy_builder_tab_RX');
    await _captureRx(tester, 'scheduled_rx_medicine');
    await _tap(tester, 'dy_rx_segment_therapy');
    await _captureRx(tester, 'scheduled_rx_therapy');
    expect(h.posts, isEmpty);
    await tester.pumpWidget(const SizedBox());
    h.auth.dispose();
  });

  testWidgets(
    'invalid existing Rx IDs stay behind the load error; Retry reloads corrected data',
    (tester) async {
      final h = _Harness();
      h.transport.onGet = (uri) async {
        if (uri.pathSegments.last == 'getPrescription') {
          return {
            'status': 200,
            'data': {
              ...h.existingData,
              'treatment_plans': [
                {'tpm_id': 'broken-id', 'name': 'Invalid plan'},
              ],
            },
          };
        }
        return h.respond(uri);
      };
      await _show(tester, h, existing: true);
      expect(find.byKey(const Key('dy_builder_error')), findsOneWidget);
      expect(find.byType(NativeDynamicRxTab), findsNothing);
      h.transport.onGet = h.respond;
      await _tap(tester, 'dy_builder_error_retry');
      await _tap(tester, 'dy_builder_tab_RX');
      final rx = tester.widget<NativeDynamicRxTab>(
        find.byType(NativeDynamicRxTab),
      );
      expect(rx.draft.treatmentPlans.first.masterId, '300');
      expect(
        h.dynamicReads.where(
          (uri) => uri.pathSegments.last == 'getPrescription',
        ),
        hasLength(2),
      );
      await _tap(tester, 'dy_builder_back');
      expect(find.byKey(const Key('dy_unsaved')), findsNothing);
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'builder default durationRequired is false and an enabled flag reaches Medicine Add and Edit',
    (tester) async {
      for (final flag in [false, true]) {
        final h = _Harness();
        await _show(tester, h, existing: true, durationRequired: flag);
        await _tap(tester, 'dy_builder_tab_RX');
        final rx = tester.widget<NativeDynamicRxTab>(
          find.byType(NativeDynamicRxTab),
        );
        expect(rx.durationRequired, flag);
        for (final key in [
          'dy_add_medicine',
          'dy_edit_${rx.draft.medicines.single.localId}',
        ]) {
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
        expect(h.posts, isEmpty);
        await tester.pumpWidget(const SizedBox());
        h.auth.dispose();
      }
    },
  );

  testWidgets(
    'RX NEXT opens Advice and all three tab drafts survive tap and swipe without catalogue reload',
    (tester) async {
      final h = _Harness();
      await _show(tester, h);
      final reads = h.dynamicReads.length;
      await _tap(tester, 'dy_action_NEXT: RX');
      await _tap(tester, 'dy_action_NEXT: ADVICE');
      expect(
        find.byKey(const Key('dy_add_advice')).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('dy_action_NEXT: REVIEW')),
            )
            .onPressed,
        isNotNull,
      );
      await _tap(tester, 'dy_add_advice');
      await tester.enterText(
        find.byKey(const Key('dy_field_advice_entry')),
        'New advice draft',
      );
      await _tap(tester, 'dy_action_ADD ADVICE');
      await _tap(tester, 'dy_builder_tab_RX');
      await _tap(tester, 'dy_add_medicine');
      await tester.enterText(
        find.byKey(const Key('dy_field_rx_medicine')),
        'Sample medicine',
      );
      await _tap(tester, 'dy_action_ADD MEDICINE');
      await _tap(tester, 'dy_builder_tab_CLINICAL');
      await _tap(tester, 'dy_add_complain');
      await tester.enterText(
        find.byKey(const Key('dy_field_entry')),
        'Clinical text survives',
      );
      await _tap(tester, 'dy_action_ADD COMPLAIN');
      await _tap(tester, 'dy_builder_tab_ADVICE');
      expect(find.text('New advice draft').hitTestable(), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(320, 0));
      await tester.pumpAndSettle();
      expect(find.text('Dose: 0+0+1').hitTestable(), findsOneWidget);
      await _tap(tester, 'dy_builder_tab_CLINICAL');
      expect(find.text('Clinical text survives').hitTestable(), findsOneWidget);
      expect(h.dynamicReads, hasLength(reads));
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'existing Advice/Follow-up/Alert/Reference/Notes load and untouched Back remains clean',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, existing: true);
      await _tap(tester, 'dy_builder_tab_ADVICE');
      final tab = tester.widget<NativeDynamicAdviceTab>(
        find.byType(NativeDynamicAdviceTab),
      );
      expect(
        tab.draft.entries(DynamicAdviceType.advice).single.text,
        'Existing advice',
      );
      expect(
        tab.draft.entries(DynamicAdviceType.followUp).single.masterId,
        '501',
      );
      expect(
        tab.draft.entries(DynamicAdviceType.specialAlert).single.masterId,
        '601',
      );
      expect(tab.draft.reference, 'Existing reference');
      expect(tab.draft.notes, 'Existing prescription notes');
      expect(
        tester.widget<Text>(find.byKey(const Key('dy_count_reference'))).data,
        'Added',
      );
      await _tap(tester, 'dy_builder_back');
      expect(find.byKey(const Key('dy_unsaved')), findsNothing);
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'Reference/Notes edits participate in unsaved state even though their text is separate from body arrays',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, existing: true);
      await _tap(tester, 'dy_builder_tab_ADVICE');
      for (final type in [
        DynamicAdviceType.reference,
        DynamicAdviceType.notes,
      ]) {
        await _tap(tester, 'dy_add_${type.name}');
        expect(find.text('Edit ${type.label}'), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('dy_field_advice_entry')),
          'Updated ${type.label}',
        );
        await _tap(tester, 'dy_action_UPDATE ${type.label.toUpperCase()}');
      }
      await _tap(tester, 'dy_builder_back');
      expect(find.byKey(const Key('dy_unsaved')), findsOneWidget);
      await _tap(tester, 'dy_keep_editing');
      final tab = tester.widget<NativeDynamicAdviceTab>(
        find.byType(NativeDynamicAdviceTab),
      );
      expect(tab.draft.reference, 'Updated Reference');
      expect(tab.draft.notes, 'Updated Notes');
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'Advice scroll/expansion/draft stay mounted across first-to-third tab changes and delayed resume',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, existing: true, size: const Size(393, 690));
      await _tap(tester, 'dy_builder_tab_ADVICE');
      await _tap(tester, 'dy_toggle_advice');
      final tab = tester.widget<NativeDynamicAdviceTab>(
        find.byType(NativeDynamicAdviceTab),
      );
      for (var i = 0; i < 15; i++) {
        tab.draft.saveEntry(
          DynamicAdviceType.advice,
          DynamicAdviceEntry(text: 'Extra advice $i'),
        );
      }
      await tester.pumpAndSettle();
      final scroll =
          tester
              .widget<SingleChildScrollView>(
                find.byKey(
                  const PageStorageKey<String>('dynamic_advice_scroll'),
                ),
              )
              .controller!;
      scroll.jumpTo(380);
      await tester.pumpAndSettle();
      final offset = scroll.offset, reads = h.dynamicReads.length;
      await _tap(tester, 'dy_builder_tab_CLINICAL');
      await _tap(tester, 'dy_builder_tab_ADVICE');
      expect(scroll.offset, closeTo(offset, .1));
      h.pendingProfile = Completer<JsonMap>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(scroll.hasClients, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      h.pendingProfile!.complete({
        'items': [h.doctorData],
      });
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(offset, .1));
      expect(
        identical(
          tester
              .widget<NativeDynamicAdviceTab>(
                find.byType(NativeDynamicAdviceTab),
              )
              .draft,
          tab.draft,
        ),
        isTrue,
      );
      expect(tab.draft.entries(DynamicAdviceType.advice), hasLength(16));
      expect(h.dynamicReads, hasLength(reads));
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'Advice catalogue failure hides partially loaded editor and Retry loads real options',
    (tester) async {
      final h = _Harness()..failAdvice = true;
      await _show(tester, h);
      expect(find.byKey(const Key('dy_builder_error')), findsOneWidget);
      expect(find.byType(NativeDynamicAdviceTab), findsNothing);
      h.failAdvice = false;
      await _tap(tester, 'dy_builder_error_retry');
      await _tap(tester, 'dy_builder_tab_ADVICE');
      await _tap(tester, 'dy_add_followUp');
      await _tap(tester, 'dy_dropdown_advice_entry');
      await _tap(tester, 'dy_option_advice_entry_501_0');
      await _tap(tester, 'dy_action_ADD FOLLOW-UP');
      final tab = tester.widget<NativeDynamicAdviceTab>(
        find.byType(NativeDynamicAdviceTab),
      );
      expect(
        tab.draft.entries(DynamicAdviceType.followUp).single.masterId,
        '501',
      );
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'logout closes Advice sheet and removes all patient text from the real app',
    (tester) async {
      final h = _Harness();
      await h.signIn();
      await tester.pumpWidget(
        DocDiaryApp(
          auth: h.auth,
          initializeOnStart: false,
          dashboard: DashboardRepository(h.transport, now: () => h.now),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'dashboard_nav_appointment');
      await _tap(tester, 'doctor_appointment_1_dynamicPrescription');
      await _tap(tester, 'dy_builder_tab_ADVICE');
      await _tap(tester, 'dy_add_notes');
      await tester.enterText(
        find.byKey(const Key('dy_field_advice_entry')),
        'Unsaved patient notes',
      );
      await h.auth.logout();
      await tester.pumpAndSettle();
      expect(find.text('Unsaved patient notes'), findsNothing);
      expect(find.text('Add Notes'), findsNothing);
      expect(find.byType(DynamicPrescriptionClinicalScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'small iPhone Advice sections and footer fit and use the native shared sheet',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, size: const Size(320, 640));
      await _tap(tester, 'dy_builder_tab_ADVICE');
      await _tap(tester, 'dy_add_specialAlert');
      expect(find.text('Add Special Alert'), findsOneWidget);
      await _tap(tester, 'dy_action_CANCEL');
      expect(
        find.byKey(const Key('dy_action_NEXT: REVIEW')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'full Advice builder render keeps all accepted Clinical/Rx header styling',
    (tester) async {
      final h = _Harness();
      await _show(tester, h);
      await _tap(tester, 'dy_builder_tab_ADVICE');
      await _captureRx(tester, 'scheduled_advice');
      expect(h.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'Review route and NEXT expose native summaries; empty Rx cannot confirm or generate',
    (tester) async {
      final h = _Harness();
      await _show(tester, h);
      await _tap(tester, 'dy_builder_tab_ADVICE');
      await _tap(tester, 'dy_action_NEXT: REVIEW');
      expect(find.text('Rx information required'), findsOneWidget);
      expect(
        tester
            .widget<Checkbox>(find.byKey(const Key('dy_review_confirm')))
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('dy_action_GENERATE')))
            .onPressed,
        isNull,
      );
      await _captureRx(tester, 'scheduled_review_empty');
      await _tap(tester, 'dy_review_edit_rx');
      expect(
        find.byKey(const Key('dy_add_medicine')).hitTestable(),
        findsOneWidget,
      );
      expect(h.transport.binaryRequests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  for (final existing in [false, true]) {
    testWidgets(
      '${existing ? "UPDATE" : "GENERATE"} sends native JSON once and retains saved draft with confirmation reset',
      (tester) async {
        final h = _Harness();
        h.transport.onBytes =
            (_) async =>
                existing
                    ? {'string_out': 'Prescription updated successfully.'}
                    : dynamicSavedResponse();
        await _show(tester, h, existing: existing);
        await _review(tester, addPlan: !existing);
        expect(find.text('Ready for final review'), findsOneWidget);
        final before = h.transport.requests.length;
        await _confirm(tester);
        await _captureRx(
          tester,
          existing ? 'scheduled_review_existing' : 'scheduled_review_ready',
        );
        await _tap(
          tester,
          existing ? 'dy_action_UPDATE' : 'dy_action_GENERATE',
        );
        expect(
          h.transport.requests
              .skip(before)
              .where((r) => r.uri.path.endsWith('/getDocData')),
          hasLength(1),
        );
        expect(h.transport.binaryRequests, hasLength(1));
        final sent = h.transport.binaryRequests.single;
        expect(
          sent.uri.pathSegments.last,
          existing ? 'updatePrescription' : 'insertPrescription',
        );
        expect(
          jsonDecode(utf8.decode(sent.body))['treatment_plans'],
          isNotEmpty,
        );
        expect(find.byKey(const Key('dy_save_success')), findsOneWidget);
        if (!existing) {
          expect(
            find.textContaining('Prescription Code: 2600901'),
            findsOneWidget,
          );
        }
        await _captureRx(
          tester,
          existing ? 'scheduled_update_success' : 'scheduled_generate_success',
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('dy_save_success')), findsOneWidget);
        await _tap(tester, 'dy_save_ok');
        expect(
          find.text(existing ? 'Visit: 2600900' : 'Visit: 2600901'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<ElevatedButton>(find.byKey(const Key('dy_action_UPDATE')))
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<Checkbox>(find.byKey(const Key('dy_review_confirm')))
              .value,
          isFalse,
        );
        await _tap(tester, 'dy_builder_back');
        expect(find.byKey(const Key('dy_unsaved')), findsNothing);
        expect(find.byType(DynamicPrescriptionClinicalScreen), findsNothing);
        await tester.pumpWidget(const SizedBox());
        h.auth.dispose();
      },
    );
  }

  testWidgets(
    'Objective validation blocks POST and GO TO CLINICAL clears confirmation',
    (tester) async {
      final h = _Harness();
      await _show(tester, h);
      final clinical =
          tester
              .widget<NativeDynamicClinicalTab>(
                find.byType(NativeDynamicClinicalTab),
              )
              .draft;
      clinical.saveObjective(
        DynamicObjectiveEntry(
          objective: const DynamicRxOption('10', 'ROM'),
          muscleJoint: const DynamicRxOption('30', 'Knee'),
        ),
      );
      await _review(tester, addPlan: true);
      await _confirm(tester);
      await _tap(tester, 'dy_action_GENERATE');
      expect(find.byKey(const Key('dy_objective_required')), findsOneWidget);
      expect(find.textContaining('prescription:\n• ROM'), findsOneWidget);
      await _captureRx(tester, 'scheduled_review_objective_required');
      expect(h.transport.binaryRequests, isEmpty);
      await _tap(tester, 'dy_objective_go');
      expect(
        find.byKey(const Key('dy_add_vitals')).hitTestable(),
        findsOneWidget,
      );
      await _tap(tester, 'dy_builder_tab_REVIEW');
      expect(
        tester
            .widget<Checkbox>(find.byKey(const Key('dy_review_confirm')))
            .value,
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'Advice Done and Cancel keep Review confirmation; explicit UPDATE resets it',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, existing: true);
      await _review(tester);
      await _confirm(tester);
      await _tap(tester, 'dy_builder_tab_ADVICE');
      final advice =
          tester
              .widget<NativeDynamicAdviceTab>(
                find.byType(NativeDynamicAdviceTab),
              )
              .draft;
      await _tap(tester, 'dy_toggle_advice');
      await _tap(
        tester,
        'dy_edit_${advice.entries(DynamicAdviceType.advice).single.localId}',
      );
      await tester.enterText(
        find.byKey(const Key('dy_field_advice_entry')),
        'Changed advice',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        advice.entries(DynamicAdviceType.advice).single.text,
        'Existing advice',
      );
      await _tap(tester, 'dy_action_CANCEL');
      await _tap(tester, 'dy_builder_tab_REVIEW');
      expect(
        tester
            .widget<Checkbox>(find.byKey(const Key('dy_review_confirm')))
            .value,
        isTrue,
      );
      await _tap(tester, 'dy_builder_tab_ADVICE');
      await _tap(
        tester,
        'dy_edit_${advice.entries(DynamicAdviceType.advice).single.localId}',
      );
      await tester.enterText(
        find.byKey(const Key('dy_field_advice_entry')),
        'Changed advice',
      );
      await _tap(tester, 'dy_action_UPDATE ADVICE');
      await _tap(tester, 'dy_builder_tab_REVIEW');
      expect(
        tester
            .widget<Checkbox>(find.byKey(const Key('dy_review_confirm')))
            .value,
        isFalse,
      );
      expect(h.transport.binaryRequests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'pending write blocks double tap and Back; failed update preserves draft and Review scroll',
    (tester) async {
      final h = _Harness();
      final pending = Completer<JsonMap>();
      h.transport.onBytes = (_) => pending.future;
      await _show(tester, h, existing: true, size: const Size(320, 640));
      await _review(tester);
      final scroll =
          tester
              .widget<SingleChildScrollView>(
                find.byKey(
                  const PageStorageKey<String>('dynamic_review_scroll'),
                ),
              )
              .controller!;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final offset = scroll.offset;
      await _confirm(tester);
      final button = tester.widget<ElevatedButton>(
        find.byKey(const Key('dy_action_UPDATE')),
      );
      button.onPressed!();
      button.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(h.transport.binaryRequests, hasLength(1));
      expect(find.byKey(const Key('dy_save_progress')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(DynamicPrescriptionClinicalScreen), findsOneWidget);
      pending.completeError(const AppFailure('Save unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Save unavailable'), findsOneWidget);
      await _tap(tester, 'dy_save_ok');
      expect(scroll.offset, closeTo(offset, .1));
      expect(
        tester
            .widget<NativeDynamicReviewTab>(find.byType(NativeDynamicReviewTab))
            .review
            .rx
            .treatmentPlans,
        hasLength(2),
      );
      expect(h.transport.binaryRequests, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  for (final found in [false, true]) {
    testWidgets(
      'unconfirmed create is reconciled with GET only, record found=$found',
      (tester) async {
        final h = _Harness();
        h.transport.onBytes =
            (_) async => throw const AppFailure('Connection lost');
        await _show(tester, h);
        await _review(tester, addPlan: true);
        await _confirm(tester);
        await _tap(tester, 'dy_action_GENERATE');
        expect(find.text('Connection lost'), findsOneWidget);
        await _tap(tester, 'dy_save_ok');
        h.failExisting = !found;
        await _confirm(tester);
        await _tap(tester, 'dy_action_GENERATE');
        expect(h.transport.binaryRequests, hasLength(1));
        expect(
          h.dynamicReads.where(
            (uri) => uri.pathSegments.last == 'getPrescription',
          ),
          hasLength(1),
        );
        expect(
          find.textContaining(
            found
                ? 'A prescription was found'
                : 'previous save could not be confirmed',
          ),
          findsOneWidget,
        );
        await _tap(tester, 'dy_save_ok');
        expect(
          tester
              .widget<NativeDynamicReviewTab>(
                find.byType(NativeDynamicReviewTab),
              )
              .review
              .rx
              .treatmentPlans
              .single
              .text,
          'Local treatment plan',
        );
        expect(
          find.byKey(Key(found ? 'dy_action_UPDATE' : 'dy_action_GENERATE')),
          findsOneWidget,
        );
        await _tap(tester, 'dy_builder_back');
        expect(find.byKey(const Key('dy_unsaved')), findsOneWidget);
        await _tap(tester, 'dy_keep_editing');
        await tester.pumpWidget(const SizedBox());
        h.auth.dispose();
      },
    );
  }

  testWidgets(
    'save rechecks fresh medicine access and cannot send hidden-only medicine',
    (tester) async {
      final h = _Harness();
      await _show(tester, h);
      await _tap(tester, 'dy_builder_tab_RX');
      final rx =
          tester
              .widget<NativeDynamicRxTab>(find.byType(NativeDynamicRxTab))
              .draft;
      rx.saveMedicine(rxMedicine());
      await tester.pumpAndSettle();
      await _tap(tester, 'dy_builder_tab_REVIEW');
      await _confirm(tester);
      h.doctorData['med_active'] = '0';
      await _tap(tester, 'dy_action_GENERATE');
      expect(
        find.text('Please review and confirm the prescription'),
        findsOneWidget,
      );
      expect(h.transport.binaryRequests, isEmpty);
      await _tap(tester, 'dy_save_ok');
      expect(find.text('Rx information required'), findsOneWidget);
      expect(rx.medicines, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets('background before profile verification sends no POST', (
    tester,
  ) async {
    final h = _Harness();
    await _show(tester, h);
    await _review(tester, addPlan: true);
    await _confirm(tester);
    final pending = Completer<JsonMap>();
    h.pendingProfile = pending;
    await tester.tap(find.byKey(const Key('dy_action_GENERATE')));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    h.pendingProfile = null;
    pending.complete({
      'items': [h.doctorData],
    });
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(h.transport.binaryRequests, isEmpty);
    expect(find.byKey(const Key('dy_save_success')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    h.auth.dispose();
  });

  testWidgets(
    'background after dispatch adopts receipt once and shows success on resume',
    (tester) async {
      final h = _Harness();
      final pending = Completer<JsonMap>();
      h.transport.onBytes = (_) => pending.future;
      await _show(tester, h);
      await _review(tester, addPlan: true);
      await _confirm(tester);
      await tester.tap(find.byKey(const Key('dy_action_GENERATE')));
      await tester.pump();
      expect(h.transport.binaryRequests, hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      pending.complete(dynamicSavedResponse());
      await tester.pump();
      expect(find.byKey(const Key('dy_save_success')), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dy_save_success')), findsOneWidget);
      await _tap(tester, 'dy_save_ok');
      expect(find.text('Visit: 2600901'), findsOneWidget);
      expect(h.transport.binaryRequests, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'logout while saving ignores a late patient receipt and removes builder',
    (tester) async {
      final h = _Harness();
      final pending = Completer<JsonMap>();
      h.transport.onBytes = (_) => pending.future;
      await h.signIn();
      await tester.pumpWidget(
        DocDiaryApp(
          auth: h.auth,
          initializeOnStart: false,
          dashboard: DashboardRepository(h.transport, now: () => h.now),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'dashboard_nav_appointment');
      await _tap(tester, 'doctor_appointment_1_dynamicPrescription');
      await _review(tester, addPlan: true);
      await _confirm(tester);
      await tester.tap(find.byKey(const Key('dy_action_GENERATE')));
      await tester.pump();
      expect(h.transport.binaryRequests, hasLength(1));
      await h.auth.logout();
      pending.complete(dynamicSavedResponse());
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DynamicPrescriptionClinicalScreen), findsNothing);
      expect(find.byKey(const Key('dy_save_success')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'template card loads native two-step picker; successful templates keep visit and save with iOS flag 4',
    (tester) async {
      final h = _Harness();
      h.transport.onBytes = (_) async => dynamicSavedResponse();
      await _show(tester, h);
      await _tap(tester, 'dy_builder_template');
      expect(find.byType(NativeDynamicTemplateSheet), findsOneWidget);
      await _tap(tester, 'dy_template_option_disease_701_0');
      await _captureRx(tester, 'builder_template_disease');
      await _tap(tester, 'dy_template_action_LOAD DISEASE TEMPLATE');
      expect(find.text('STEP 2 OF 2'), findsOneWidget);
      await _tap(tester, 'dy_template_option_treatment_801_0');
      await _captureRx(tester, 'builder_template_treatment');
      await _tap(tester, 'dy_template_action_LOAD TREATMENT');
      expect(find.byType(NativeDynamicTemplateSheet), findsNothing);
      expect(
        find.text('Disease: Occupational Template\nTreatment: Exercise Plan'),
        findsOneWidget,
      );
      expect(h.transport.binaryRequests, isEmpty);
      await _review(tester);
      await _confirm(tester);
      await _captureRx(tester, 'builder_templates_review');
      await _tap(tester, 'dy_action_GENERATE');
      final sent = h.transport.binaryRequests.single;
      expect(sent.headers['P_TD_ID'], '701');
      expect(sent.headers['P_TT_ID'], '801');
      expect(sent.headers['P_INSERT_TYPE'], '4');
      expect(jsonDecode(utf8.decode(sent.body))['treatment_plans'], [
        {'tpm_id': 300, 'name': 'Template treatment plan'},
      ]);
      await _tap(tester, 'dy_save_ok');
      await _tap(tester, 'dy_builder_back');
      expect(find.byKey(const Key('dy_unsaved')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'existing prescription template replacement Cancel is clean; LOAD preserves Vitals/Reference/Notes and UPDATE identity',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, existing: true);
      final clinical =
          tester
              .widget<NativeDynamicClinicalTab>(
                find.byType(NativeDynamicClinicalTab),
              )
              .draft;
      final oldComplain = clinical.entries(DynamicClinicalType.complain).single;
      await _tap(tester, 'dy_builder_template');
      await _tap(tester, 'dy_template_option_disease_701_0');
      await _tap(tester, 'dy_template_action_LOAD DISEASE TEMPLATE');
      await _tap(tester, 'dy_template_replace_cancel');
      await _tap(tester, 'dy_template_close');
      expect(
        clinical.entries(DynamicClinicalType.complain).single,
        same(oldComplain),
      );
      await _tap(tester, 'dy_builder_template');
      await _tap(tester, 'dy_template_option_disease_701_0');
      await _tap(tester, 'dy_template_action_LOAD DISEASE TEMPLATE');
      await _tap(tester, 'dy_template_replace_load');
      await _tap(tester, 'dy_template_action_DONE');
      expect(find.text('Visit: 2600900'), findsOneWidget);
      expect(clinical.vitals!['pulse'], '72');
      await _review(tester);
      final review =
          tester
              .widget<NativeDynamicReviewTab>(
                find.byType(NativeDynamicReviewTab),
              )
              .review;
      expect(review.advice.reference, 'Existing reference');
      expect(review.advice.notes, 'Existing prescription notes');
      expect(review.rx.medicines, isEmpty);
      expect(review.rx.therapies, isEmpty);
      expect(review.rx.treatmentPlans, isEmpty);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('dy_action_UPDATE')))
            .onPressed,
        isNull,
      );
      await _tap(tester, 'dy_builder_back');
      expect(find.byKey(const Key('dy_unsaved')), findsOneWidget);
      await _tap(tester, 'dy_keep_editing');
      expect(h.transport.binaryRequests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'loaded template picker reopens at Treatment with cached catalogues and selected native IDs',
    (tester) async {
      final h = _Harness()..existingTemplates = true;
      await _show(tester, h, existing: true);
      await _tap(tester, 'dy_builder_template');
      expect(find.text('STEP 2 OF 2'), findsOneWidget);
      final reads = h.dynamicReads.length;
      expect(
        tester
            .widget<Radio<String>>(find.byType(Radio<String>).first)
            .groupValue,
        '801',
      );
      await _tap(tester, 'dy_template_close');
      await _tap(tester, 'dy_builder_template');
      expect(h.dynamicReads, hasLength(reads));
      await _tap(tester, 'dy_template_change');
      expect(
        tester
            .widget<Radio<String>>(find.byType(Radio<String>).first)
            .groupValue,
        '701',
      );
      await _tap(tester, 'dy_template_close');
      await _tap(tester, 'dy_builder_back');
      expect(find.byKey(const Key('dy_unsaved')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'failed template load keeps the complete existing draft and confirmation untouched',
    (tester) async {
      final h = _Harness()..failTemplate = true;
      await _show(tester, h, existing: true);
      await _review(tester);
      await _confirm(tester);
      final review =
          tester
              .widget<NativeDynamicReviewTab>(
                find.byType(NativeDynamicReviewTab),
              )
              .review;
      final before = jsonEncode({
        'clinical': review.clinical.toBody(),
        'rx': review.rx.toBody(medicineAllowed: true),
        'advice': review.advice.toBody(),
      });
      await _tap(tester, 'dy_builder_template');
      await _tap(tester, 'dy_template_option_disease_701_0');
      await _tap(tester, 'dy_template_action_LOAD DISEASE TEMPLATE');
      await _tap(tester, 'dy_template_replace_load');
      expect(find.text('Template data unavailable'), findsOneWidget);
      await _tap(tester, 'dy_template_close');
      expect(
        jsonEncode({
          'clinical': review.clinical.toBody(),
          'rx': review.rx.toBody(medicineAllowed: true),
          'advice': review.advice.toBody(),
        }),
        before,
      );
      expect(review.confirmed, isTrue);
      expect(h.transport.binaryRequests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'background cancels pending template apply, closes owned dialogs/sheet and preserves old draft on resume',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, existing: true);
      final clinical =
          tester
              .widget<NativeDynamicClinicalTab>(
                find.byType(NativeDynamicClinicalTab),
              )
              .draft;
      final pending = Completer<JsonMap>();
      h.pendingTemplate = pending;
      await _tap(tester, 'dy_builder_template');
      await _tap(tester, 'dy_template_option_disease_701_0');
      await _tap(tester, 'dy_template_action_LOAD DISEASE TEMPLATE');
      await tester.tap(find.byKey(const Key('dy_template_replace_load')));
      await tester.pump();
      expect(find.byKey(const Key('dy_template_progress')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(NativeDynamicTemplateSheet), findsOneWidget);
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      h.pendingTemplate = null;
      pending.complete({'status': 200, 'data': diseaseTemplateData()});
      await tester.pump();
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(find.byType(NativeDynamicTemplateSheet), findsNothing);
      expect(
        clinical.entries(DynamicClinicalType.complain).single.text,
        'Existing complain',
      );
      expect(h.transport.binaryRequests, isEmpty);
      await _tap(tester, 'dy_builder_template');
      expect(find.text('STEP 1 OF 2'), findsOneWidget);
      await _tap(tester, 'dy_template_close');
      await _tap(tester, 'dy_builder_back');
      expect(find.byKey(const Key('dy_unsaved')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );

  testWidgets(
    'logout closes template replacement dialog and cannot expose the patient on Login',
    (tester) async {
      final h = _Harness();
      await h.signIn();
      await tester.pumpWidget(
        DocDiaryApp(
          auth: h.auth,
          initializeOnStart: false,
          dashboard: DashboardRepository(h.transport, now: () => h.now),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'dashboard_nav_appointment');
      await _tap(tester, 'doctor_appointment_0_dynamicPrescription');
      await _tap(tester, 'dy_builder_template');
      await _tap(tester, 'dy_template_option_disease_701_0');
      await _tap(tester, 'dy_template_action_LOAD DISEASE TEMPLATE');
      expect(
        find.byKey(const Key('dy_template_replace_dialog')),
        findsOneWidget,
      );
      await h.auth.logout();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(NativeDynamicTemplateSheet), findsNothing);
      expect(find.byKey(const Key('dy_template_replace_dialog')), findsNothing);
      expect(h.transport.binaryRequests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

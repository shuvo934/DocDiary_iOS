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
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_history_sheet.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_builder_layout.dart';
import 'dynamic_history_test_support.dart';
import 'dynamic_walkin_test_support.dart';
import 'dynamic_preview_test_support.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_preview_screen.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_patient_selection_sheet.dart';

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
  Completer<JsonMap>? pendingHistory, pendingPrevious;
  bool failHistory = false, failPrevious = false;
  JsonMap? previousData;
  Completer<JsonMap>? pendingPatientList;
  bool failPatients = false;
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
    if (endpoint == 'getHundredPatListYearWise' ||
        endpoint == 'getPatListBySearch') {
      if (pendingPatientList != null) return pendingPatientList!.future;
      if (failPatients) throw const AppFailure('Patient lookup failed');
      return {'pat_list': walkInRows()};
    }
    if (endpoint == 'getPreviewData') {
      final response = previewFixture();
      (response['data'] as JsonMap)['rvm_id'] = uri.queryParameters['p_rvm_id'];
      return response;
    }
    if (endpoint == 'getPrescriptionHistory') {
      if (pendingHistory != null) return pendingHistory!.future;
      if (failHistory) throw const AppFailure('History unavailable');
      return {'items': historyRows()};
    }
    if (endpoint == 'loadPreviousPrescription') {
      if (pendingPrevious != null) return pendingPrevious!.future;
      if (failPrevious) {
        return {'status': 500, 'message': 'Previous prescription unavailable'};
      }
      return {
        'status': 200,
        'data': previousData ?? previousPrescriptionData(),
      };
    }
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
            'pat_name':
                uri.queryParameters['p_ph_id'] == '201'
                    ? 'Walk-in Patient One'
                    : uri.queryParameters['p_ph_id'] == '202'
                    ? 'Walk-in Patient Two'
                    : 'Sample Patient',
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
  DynamicPrescriptionSeed seed({
    bool existing = false,
    String? date,
    bool walkIn = false,
  }) => DynamicPrescriptionSeed.fromExtras(
    {
      if (walkIn) ...{
        'P_PAT_TYPE': '2',
        'IS_CREATED': '0',
      } else
        ...doctorAppointmentRoute(
          DoctorAppointmentAction.dynamicPrescription,
          DoctorAppointmentRow({
            ...doctorAppointmentRow(name: patientName),
            'rvm': existing ? '1' : '0',
            if (date != null) 'adm_date': date,
          }, selectedDate: now),
        ).extras,
    },
    ownerDoctorId: '10',
    now: now,
  );
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
  bool walkIn = false,
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
                    seed: harness.seed(existing: existing, walkIn: walkIn),
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
  const historyOutput = String.fromEnvironment('DYNAMIC_HISTORY_RENDER_DIR');
  const walkInOutput = String.fromEnvironment('DYNAMIC_WALKIN_RENDER_DIR');
  final output =
      walkInOutput.isNotEmpty
          ? walkInOutput
          : historyOutput.isNotEmpty
          ? historyOutput
          : templateOutput.isNotEmpty
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
      'seed matches native scheduled extras; past dates and an unselected Walk-in cannot edit',
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
        isNotNull,
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

  for (final existing in [false, true]) {
    for (final type in [DynamicAdviceType.reference, DynamicAdviceType.notes]) {
      testWidgets(
        '${existing ? "UPDATE" : "GENERATE"} with Bangla ${type.label} shows a clear dialog, keeps the draft and allows English correction',
        (tester) async {
          final h = _Harness();
          h.transport.onBytes = (_) async => dynamicSavedResponse();
          await _show(tester, h, existing: existing);
          await _tap(tester, 'dy_builder_tab_ADVICE');
          final draft =
              tester
                  .widget<NativeDynamicAdviceTab>(
                    find.byType(NativeDynamicAdviceTab),
                  )
                  .draft;
          final editing = draft.entries(type).isNotEmpty;
          await _tap(tester, 'dy_add_${type.name}');
          await tester.enterText(
            find.byKey(const Key('dy_field_advice_entry')),
            'বাংলা লেখা',
          );
          await _tap(
            tester,
            'dy_action_${editing ? "UPDATE" : "ADD"} ${type.label.toUpperCase()}',
          );
          await _review(tester, addPlan: !existing);
          await _confirm(tester);
          final lookups =
              h.transport.requests
                  .where(
                    (request) => request.uri.path.endsWith('/getPrescription'),
                  )
                  .length;
          final saveAction =
              existing ? 'dy_action_UPDATE' : 'dy_action_GENERATE';
          await _tap(tester, saveAction);
          expect(find.byKey(const Key('dy_save_error')), findsOneWidget);
          expect(find.textContaining('do not support Bangla'), findsOneWidget);
          expect(find.textContaining('Your draft is kept'), findsOneWidget);
          expect(h.transport.binaryRequests, isEmpty);
          expect(draft.entries(type).single.text, 'বাংলা লেখা');
          await _captureRx(
            tester,
            'unsupported_${type.name}_${existing ? "update" : "create"}',
          );
          await _tap(tester, 'dy_save_ok');
          await _tap(tester, 'dy_builder_tab_ADVICE');
          await _tap(tester, 'dy_add_${type.name}');
          expect(
            tester
                .widget<TextField>(
                  find.byKey(const Key('dy_field_advice_entry')),
                )
                .controller!
                .text,
            'বাংলা লেখা',
          );
          await tester.enterText(
            find.byKey(const Key('dy_field_advice_entry')),
            'English ${type.label}',
          );
          await _tap(tester, 'dy_action_UPDATE ${type.label.toUpperCase()}');
          await _review(tester);
          await _confirm(tester);
          await _tap(tester, saveAction);
          expect(find.byKey(const Key('dy_save_success')), findsOneWidget);
          expect(h.transport.binaryRequests, hasLength(1));
          final sent = h.transport.binaryRequests.single;
          expect(
            sent.headers[type == DynamicAdviceType.reference
                ? 'P_REFERENCE'
                : 'P_NOTES'],
            'English ${type.label}',
          );
          expect(sent.headers['P_INSERT_TYPE'], '4');
          expect(
            sent.uri.pathSegments.last,
            existing ? 'updatePrescription' : 'insertPrescription',
          );
          // A preflight validation failure must not mark a create as uncertain
          // or trigger recovery/another insert on the corrected manual save.
          expect(
            h.transport.requests.where(
              (request) => request.uri.path.endsWith('/getPrescription'),
            ),
            hasLength(lookups),
          );
          await _tap(tester, 'dy_save_ok');
          await tester.pumpWidget(const SizedBox());
          h.auth.dispose();
        },
      );
    }
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

  for (final existing in [false, true]) {
    testWidgets(
      'History load copies content into the current ${existing ? "UPDATE" : "GENERATE"} identity and requires review again',
      (tester) async {
        final h = _Harness()..existingTemplates = existing;
        h.transport.onBytes = (_) async => dynamicSavedResponse();
        await _show(tester, h, existing: existing);
        await _review(tester, addPlan: !existing);
        await _confirm(tester);
        await _tap(tester, 'dy_builder_history');
        await _captureRx(tester, 'builder_history');
        await _tap(tester, 'dy_history_option_600_0');
        await _tap(tester, 'dy_action_LOAD TO CURRENT RX');
        await _tap(tester, 'dy_history_replace_load');
        expect(find.byType(NativeDynamicHistorySheet), findsNothing);
        expect(
          tester
              .widget<NativeDynamicBuilderLayout>(
                find.byType(NativeDynamicBuilderLayout),
              )
              .selectedTab,
          0,
        );
        expect(
          find.text(existing ? 'Visit: 2600900' : 'Visit: ...'),
          findsOneWidget,
        );
        expect(find.text('Sample Patient'), findsOneWidget);
        expect(find.text('No template loaded'), findsOneWidget);
        final clinical =
            tester
                .widget<NativeDynamicClinicalTab>(
                  find.byType(NativeDynamicClinicalTab),
                )
                .draft;
        expect(clinical.vitals!['weight'], '66');
        expect(
          clinical.entries(DynamicClinicalType.complain).single.text,
          'Template complain',
        );
        await _captureRx(
          tester,
          existing ? 'history_loaded_update' : 'history_loaded_create',
        );
        await _tap(tester, 'dy_builder_tab_ADVICE');
        final advice =
            tester
                .widget<NativeDynamicAdviceTab>(
                  find.byType(NativeDynamicAdviceTab),
                )
                .draft;
        expect(advice.reference, 'Previous reference');
        expect(advice.notes, 'Previous notes');
        await _review(tester);
        expect(
          tester
              .widget<Checkbox>(find.byKey(const Key('dy_review_confirm')))
              .value,
          isFalse,
        );
        expect(h.transport.binaryRequests, isEmpty);
        await _confirm(tester);
        await _tap(
          tester,
          existing ? 'dy_action_UPDATE' : 'dy_action_GENERATE',
        );
        final sent = h.transport.binaryRequests.single;
        final seed = h.seed(existing: existing);
        expect(sent.headers['P_DOC_ID'], '10');
        expect(sent.headers['P_PH_ID'], seed.patientHistoryId);
        expect(sent.headers['P_PAT_ID'], seed.patientId);
        expect(sent.headers['P_AD_ID'], seed.appointmentId);
        expect(sent.headers['P_RVM_ID'], existing ? '900' : null);
        expect(sent.headers['P_TD_ID'], '');
        expect(sent.headers['P_TT_ID'], '');
        expect(sent.headers['P_REFERENCE'], 'Previous reference');
        expect(sent.headers['P_NOTES'], 'Previous notes');
        expect(sent.headers['P_WEIGHT'], '66');
        expect(sent.headers['P_INSERT_TYPE'], '4');
        expect(
          sent.uri.pathSegments.last,
          existing ? 'updatePrescription' : 'insertPrescription',
        );
        expect(
          (jsonDecode(utf8.decode(sent.body)) as Map)['medications'],
          isNotEmpty,
        );
        await _tap(tester, 'dy_save_ok');
        await tester.pumpWidget(const SizedBox());
        h.auth.dispose();
      },
    );
  }
  testWidgets(
    'History replacement Cancel preserves a confirmed existing prescription and clean Back',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, existing: true);
      await _review(tester);
      await _confirm(tester);
      await _tap(tester, 'dy_builder_history');
      await _tap(tester, 'dy_history_option_600_0');
      await _tap(tester, 'dy_action_LOAD TO CURRENT RX');
      await _tap(tester, 'dy_history_replace_cancel');
      await _tap(tester, 'dy_history_close');
      expect(
        tester
            .widget<Checkbox>(find.byKey(const Key('dy_review_confirm')))
            .value,
        isTrue,
      );
      await _tap(tester, 'dy_builder_back');
      expect(find.byKey(const Key('dy_unsaved')), findsNothing);
      expect(h.transport.binaryRequests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  testWidgets(
    'History reopen retrieves fresh patient data with no retained selection',
    (tester) async {
      final h = _Harness();
      await _show(tester, h);
      await _tap(tester, 'dy_builder_history');
      await _tap(tester, 'dy_history_option_600_0');
      await _tap(tester, 'dy_history_close');
      await _tap(tester, 'dy_builder_history');
      expect(
        h.transport.requests.where(
          (r) => r.uri.path.endsWith('/getPrescriptionHistory'),
        ),
        hasLength(2),
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('dy_action_LOAD TO CURRENT RX')),
            )
            .onPressed,
        isNull,
      );
      await _tap(tester, 'dy_history_close');
      await _tap(tester, 'dy_builder_back');
      expect(find.byKey(const Key('dy_unsaved')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  for (final previous in [false, true]) {
    testWidgets(
      'background cancels pending History ${previous ? "replacement" : "list"} and rejects the late response',
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
        if (previous) {
          h.pendingPrevious = pending;
          await _tap(tester, 'dy_builder_history');
          await _tap(tester, 'dy_history_option_600_0');
          await _tap(tester, 'dy_action_LOAD TO CURRENT RX');
          await tester.tap(find.byKey(const Key('dy_history_replace_load')));
          await tester.pump();
        } else {
          h.pendingHistory = pending;
          await tester.tap(find.byKey(const Key('dy_builder_history')));
          await tester.pump(const Duration(milliseconds: 400));
        }
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pump();
        h.pendingHistory = null;
        h.pendingPrevious = null;
        pending.complete(
          previous
              ? {'status': 200, 'data': previousPrescriptionData()}
              : {'items': historyRows()},
        );
        await tester.pump();
        for (final state in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pumpAndSettle();
        expect(find.byType(NativeDynamicHistorySheet), findsNothing);
        expect(
          clinical.entries(DynamicClinicalType.complain).single.text,
          'Existing complain',
        );
        await _tap(tester, 'dy_builder_history');
        expect(find.text('3 prescriptions found'), findsOneWidget);
        await _tap(tester, 'dy_history_close');
        await _tap(tester, 'dy_builder_back');
        expect(find.byKey(const Key('dy_unsaved')), findsNothing);
        expect(h.transport.binaryRequests, isEmpty);
        await tester.pumpWidget(const SizedBox());
        h.auth.dispose();
      },
    );
  }
  testWidgets(
    'logout closes History confirmation and removes all patient information from Login',
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
      await _tap(tester, 'dy_builder_history');
      await _tap(tester, 'dy_history_option_600_0');
      await _tap(tester, 'dy_action_LOAD TO CURRENT RX');
      expect(
        find.byKey(const Key('dy_history_replace_dialog')),
        findsOneWidget,
      );
      await h.auth.logout();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(NativeDynamicHistorySheet), findsNothing);
      expect(find.byKey(const Key('dy_history_replace_dialog')), findsNothing);
      expect(find.text('Sample Patient'), findsNothing);
      expect(h.transport.binaryRequests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final size in [const Size(393, 852), const Size(320, 640)]) {
    testWidgets(
      'uploaded builder SafeArea keeps the footer above the home indicator at ${size.width.toInt()}px',
      (tester) async {
        final h = _Harness();
        await _show(tester, h, size: size);
        final safeAreas = find.descendant(
          of: find.byType(NativeDynamicBuilderLayout),
          matching: find.byType(SafeArea),
        );
        expect(
          tester.widgetList<SafeArea>(safeAreas).any((area) => !area.bottom),
          isTrue,
        );
        expect(
          tester
              .widgetList<SafeArea>(safeAreas)
              .any((area) => !area.top && area.bottom),
          isTrue,
        );
        expect(
          tester.getRect(find.byKey(const Key('dy_action_NEXT: RX'))).bottom,
          lessThanOrEqualTo(size.height - 34),
        );
        await _captureRx(tester, 'builder_safe_area_${size.width.toInt()}');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        h.auth.dispose();
      },
    );
  }

  for (final action in ['close', 'cancel', 'back']) {
    testWidgets(
      'Walk-in required selection $action returns to appointments without opening an editable prescription',
      (tester) async {
        final h = _Harness();
        await _show(tester, h, timeline: true);
        await _tap(tester, 'doctor_appointment_walk_in');
        expect(find.byType(NativeDynamicPatientSelectionSheet), findsOneWidget);
        expect(find.byType(NativeDynamicClinicalTab), findsNothing);
        await _captureRx(tester, 'walkin_required_selection');
        if (action == 'back') {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        } else {
          await _tap(
            tester,
            action == 'close' ? 'dy_select_patient_close' : 'dy_action_CANCEL',
          );
        }
        expect(find.byType(DynamicPrescriptionClinicalScreen), findsNothing);
        expect(find.byType(DoctorAppointmentScreen), findsOneWidget);
        expect(
          h.dynamicReads.where((uri) => uri.pathSegments.last == 'getComplain'),
          isEmpty,
        );
        expect(h.transport.binaryRequests, isEmpty);
        await tester.pumpWidget(const SizedBox());
        h.auth.dispose();
      },
    );
  }
  for (final type in ['2', '1']) {
    testWidgets(
      'Walk-in ${type == '2' ? 'Indoor' : 'Outdoor'} selects patient then GENERATE/UPDATE use blank appointment and native flags',
      (tester) async {
        final h = _Harness();
        h.transport.onBytes = (_) async => dynamicSavedResponse();
        await _show(tester, h, timeline: true);
        await _tap(tester, 'doctor_appointment_walk_in');
        if (type == '1') {
          await _tap(tester, 'dy_dropdown_patient_type');
          await _tap(tester, 'dy_option_patient_type_1_1');
        }
        await _tap(tester, 'dy_patient_option_201_0');
        await _tap(tester, 'dy_action_SELECT PATIENT');
        expect(find.byType(NativeDynamicPatientSelectionSheet), findsNothing);
        expect(find.text('Walk-in Patient One'), findsOneWidget);
        expect(find.text('Date: 24-OCT-26'), findsOneWidget);
        expect(find.byType(NativeDynamicClinicalTab), findsOneWidget);
        await _captureRx(
          tester,
          'walkin_builder_${type == '2' ? 'indoor' : 'outdoor'}',
        );
        await _review(tester, addPlan: true);
        await _confirm(tester);
        await _tap(tester, 'dy_action_GENERATE');
        final create = h.transport.binaryRequests.single;
        expect(create.headers['P_PAT_ID'], '101');
        expect(create.headers['P_PH_ID'], '201');
        expect(create.headers['P_AD_ID'], '');
        expect(create.headers['P_PATIENT_TYPE'], '2');
        expect(create.headers['P_PRESCRIPTION_TYPE'], type);
        expect(create.headers['P_INSERT_TYPE'], '4');
        await _tap(tester, 'dy_save_ok');
        await _tap(tester, 'dy_builder_patient');
        expect(find.byKey(const Key('dy_action_CHANGE PATIENT')), findsNothing);
        await _tap(tester, 'dy_action_CLOSE');
        await _confirm(tester);
        await _tap(tester, 'dy_action_UPDATE');
        expect(h.transport.binaryRequests, hasLength(2));
        final update = h.transport.binaryRequests.last;
        expect(update.uri.pathSegments.last, 'updatePrescription');
        expect(update.headers['P_RVM_ID'], '901');
        expect(update.headers['P_AD_ID'], '');
        expect(update.headers['P_INSERT_TYPE'], '4');
        expect(update.headers.containsKey('P_PATIENT_TYPE'), isFalse);
        expect(
          h.dynamicReads.where(
            (uri) => uri.pathSegments.last == 'getPrescription',
          ),
          isEmpty,
        );
        await _tap(tester, 'dy_save_ok');
        await tester.pumpWidget(const SizedBox());
        h.auth.dispose();
      },
    );
  }
  testWidgets(
    'Walk-in Change patient CANCEL keeps the draft; CLEAR & CHANGE clears every section and templates',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, walkIn: true);
      await _tap(tester, 'dy_patient_option_201_0');
      await _tap(tester, 'dy_action_SELECT PATIENT');
      final clinical =
          tester
              .widget<NativeDynamicClinicalTab>(
                find.byType(NativeDynamicClinicalTab),
              )
              .draft;
      await _tap(tester, 'dy_builder_template');
      await _tap(tester, 'dy_template_option_disease_701_0');
      await _tap(tester, 'dy_template_action_LOAD DISEASE TEMPLATE');
      await _tap(tester, 'dy_template_option_treatment_801_0');
      await _tap(tester, 'dy_template_action_LOAD TREATMENT');
      clinical.saveVitals(DynamicVitals({'pulse': '76'}));
      await _tap(tester, 'dy_builder_tab_ADVICE');
      final advice =
          tester
              .widget<NativeDynamicAdviceTab>(
                find.byType(NativeDynamicAdviceTab),
              )
              .draft;
      advice.saveEntry(
        DynamicAdviceType.reference,
        DynamicAdviceEntry(text: 'Old patient reference'),
      );
      advice.saveEntry(
        DynamicAdviceType.notes,
        DynamicAdviceEntry(text: 'Old patient notes'),
      );
      await _tap(tester, 'dy_builder_tab_RX');
      final rx =
          tester
              .widget<NativeDynamicRxTab>(find.byType(NativeDynamicRxTab))
              .draft;
      await _review(tester);
      await _confirm(tester);
      for (final clear in [false, true]) {
        await _tap(tester, 'dy_builder_patient');
        await _tap(tester, 'dy_action_CHANGE PATIENT');
        await _tap(tester, 'dy_patient_option_202_1');
        await _tap(tester, 'dy_action_SELECT PATIENT');
        expect(
          find.byKey(const Key('dy_change_patient_dialog')),
          findsOneWidget,
        );
        await _captureRx(tester, 'walkin_change_patient_confirmation');
        await _tap(
          tester,
          clear ? 'dy_change_patient_confirm' : 'dy_change_patient_cancel',
        );
        if (!clear) {
          expect(find.text('Walk-in Patient One'), findsOneWidget);
          expect(advice.notes, 'Old patient notes');
          expect(rx.medicines, isNotEmpty);
          expect(
            tester
                .widget<Checkbox>(find.byKey(const Key('dy_review_confirm')))
                .value,
            isTrue,
          );
        }
      }
      expect(find.text('Walk-in Patient Two'), findsOneWidget);
      expect(find.text('No template loaded'), findsOneWidget);
      expect(clinical.vitals, isNull);
      expect(clinical.objectives, isEmpty);
      for (final type in DynamicClinicalType.values) {
        expect(clinical.entries(type), isEmpty);
      }
      for (final type in DynamicAdviceType.values) {
        expect(advice.entries(type), isEmpty);
      }
      expect(rx.medicines, isEmpty);
      expect(rx.therapies, isEmpty);
      expect(rx.treatmentPlans, isEmpty);
      await _tap(tester, 'dy_builder_back');
      expect(find.byKey(const Key('dy_unsaved')), findsNothing);
      expect(h.transport.binaryRequests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  for (final changeType in [false, true]) {
    testWidgets(
      'Walk-in reselecting the same patient keeps unsaved tracking with type change $changeType',
      (tester) async {
        final h = _Harness();
        addTearDown(h.auth.dispose);
        await _show(tester, h, walkIn: true);
        await _tap(tester, 'dy_patient_option_201_0');
        await _tap(tester, 'dy_action_SELECT PATIENT');
        await _review(tester, addPlan: true);
        await _confirm(tester);
        await _tap(tester, 'dy_builder_patient');
        await _tap(tester, 'dy_action_CHANGE PATIENT');
        if (changeType) {
          await _tap(tester, 'dy_dropdown_patient_type');
          await _tap(tester, 'dy_option_patient_type_1_1');
        }
        await _tap(tester, 'dy_patient_option_201_0');
        await _tap(tester, 'dy_action_SELECT PATIENT');
        expect(find.byKey(const Key('dy_change_patient_dialog')), findsNothing);
        await _tap(tester, 'dy_builder_back');
        expect(find.byKey(const Key('dy_unsaved')), findsOneWidget);
        await _tap(tester, 'dy_keep_editing');
        expect(
          tester
              .widget<Checkbox>(find.byKey(const Key('dy_review_confirm')))
              .value,
          !changeType,
        );
        await _tap(tester, 'dy_builder_tab_RX');
        expect(
          tester
              .widget<NativeDynamicRxTab>(find.byType(NativeDynamicRxTab))
              .draft
              .treatmentPlans
              .single
              .text,
          'Local treatment plan',
        );
        expect(h.transport.binaryRequests, isEmpty);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('Walk-in changing only Indoor/Outdoor remains an unsaved edit', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.auth.dispose);
    await _show(tester, h, walkIn: true);
    await _tap(tester, 'dy_patient_option_201_0');
    await _tap(tester, 'dy_action_SELECT PATIENT');
    await _tap(tester, 'dy_builder_patient');
    await _tap(tester, 'dy_action_CHANGE PATIENT');
    await _tap(tester, 'dy_dropdown_patient_type');
    await _tap(tester, 'dy_option_patient_type_1_1');
    await _tap(tester, 'dy_patient_option_201_0');
    await _tap(tester, 'dy_action_SELECT PATIENT');
    await _tap(tester, 'dy_builder_back');
    expect(find.byKey(const Key('dy_unsaved')), findsOneWidget);
    await _tap(tester, 'dy_discard');
    expect(find.byType(DynamicPrescriptionClinicalScreen), findsNothing);
    expect(h.transport.binaryRequests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Walk-in reselecting an unchanged empty patient remains clean', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.auth.dispose);
    await _show(tester, h, walkIn: true);
    await _tap(tester, 'dy_patient_option_201_0');
    await _tap(tester, 'dy_action_SELECT PATIENT');
    await _tap(tester, 'dy_builder_patient');
    await _tap(tester, 'dy_action_CHANGE PATIENT');
    await _tap(tester, 'dy_patient_option_201_0');
    await _tap(tester, 'dy_action_SELECT PATIENT');
    await _tap(tester, 'dy_builder_back');
    expect(find.byKey(const Key('dy_unsaved')), findsNothing);
    expect(find.byType(DynamicPrescriptionClinicalScreen), findsNothing);
    expect(h.transport.binaryRequests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Walk-in selecting the same patient retains entered content and changes Indoor/Outdoor only after SELECT',
    (tester) async {
      final h = _Harness();
      h.transport.onBytes = (_) async => dynamicSavedResponse();
      await _show(tester, h, walkIn: true);
      await _tap(tester, 'dy_patient_option_201_0');
      await _tap(tester, 'dy_action_SELECT PATIENT');
      await _review(tester, addPlan: true);
      await _confirm(tester);
      await _tap(tester, 'dy_builder_patient');
      await _tap(tester, 'dy_action_CHANGE PATIENT');
      await _tap(tester, 'dy_dropdown_patient_type');
      await _tap(tester, 'dy_option_patient_type_1_1');
      await _tap(tester, 'dy_patient_option_201_0');
      await _tap(tester, 'dy_action_SELECT PATIENT');
      expect(find.byKey(const Key('dy_change_patient_dialog')), findsNothing);
      expect(
        tester
            .widget<Checkbox>(find.byKey(const Key('dy_review_confirm')))
            .value,
        isFalse,
      );
      await _confirm(tester);
      await _tap(tester, 'dy_action_GENERATE');
      final sent = h.transport.binaryRequests.single;
      expect(sent.headers['P_PRESCRIPTION_TYPE'], '1');
      expect(
        (jsonDecode(utf8.decode(sent.body)) as Map)['treatment_plans'],
        hasLength(1),
      );
      await _tap(tester, 'dy_save_ok');
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  testWidgets(
    'Walk-in canceling optional Change patient sheet retains the current builder and confirmed content',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, walkIn: true);
      await _tap(tester, 'dy_patient_option_201_0');
      await _tap(tester, 'dy_action_SELECT PATIENT');
      await _review(tester, addPlan: true);
      await _confirm(tester);
      await _tap(tester, 'dy_builder_patient');
      await _tap(tester, 'dy_action_CHANGE PATIENT');
      await _tap(tester, 'dy_action_CANCEL');
      expect(find.byType(DynamicPrescriptionClinicalScreen), findsOneWidget);
      expect(find.text('Walk-in Patient One'), findsOneWidget);
      expect(
        tester
            .widget<Checkbox>(find.byKey(const Key('dy_review_confirm')))
            .value,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  for (final changing in [false, true]) {
    testWidgets(
      'Walk-in background invalidates pending ${changing ? 'change' : 'required'} patient read and resumes the correct flow',
      (tester) async {
        final h = _Harness();
        await _show(tester, h, timeline: true);
        await _tap(tester, 'doctor_appointment_walk_in');
        if (changing) {
          await _tap(tester, 'dy_patient_option_201_0');
          await _tap(tester, 'dy_action_SELECT PATIENT');
          await _review(tester, addPlan: true);
          await _confirm(tester);
          await _tap(tester, 'dy_builder_patient');
        } else {
          // Cancel the first selection, then use a separate new builder
          // so the pending request really belongs to mandatory initial selection.
          await _tap(tester, 'dy_select_patient_close');
        }
        final pending = Completer<JsonMap>();
        h.pendingPatientList = pending;
        await tester.tap(
          find.byKey(
            Key(
              changing
                  ? 'dy_action_CHANGE PATIENT'
                  : 'doctor_appointment_walk_in',
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(NativeDynamicPatientSelectionSheet), findsOneWidget);
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pump();
        h.pendingPatientList = null;
        pending.complete({'pat_list': walkInRows()});
        await tester.pump();
        for (final state in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
        await tester.pumpAndSettle();
        if (changing) {
          expect(find.byType(NativeDynamicPatientSelectionSheet), findsNothing);
          expect(find.text('Walk-in Patient One'), findsOneWidget);
          expect(
            tester
                .widget<Checkbox>(find.byKey(const Key('dy_review_confirm')))
                .value,
            isTrue,
          );
        } else {
          expect(
            find.byType(NativeDynamicPatientSelectionSheet),
            findsOneWidget,
          );
          await _tap(tester, 'dy_action_CANCEL');
          expect(find.byType(DynamicPrescriptionClinicalScreen), findsNothing);
        }
        expect(h.transport.binaryRequests, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        h.auth.dispose();
      },
    );
  }
  testWidgets(
    'Walk-in logout closes required selection and ignores late patient data on Login',
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
      final pending = Completer<JsonMap>();
      h.pendingPatientList = pending;
      await tester.tap(find.byKey(const Key('doctor_appointment_walk_in')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(NativeDynamicPatientSelectionSheet), findsOneWidget);
      expect(
        h.dynamicReads.where(
          (uri) => uri.pathSegments.last == 'getHundredPatListYearWise',
        ),
        hasLength(1),
      );
      await h.auth.logout();
      h.pendingPatientList = null;
      pending.complete({'pat_list': walkInRows()});
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(NativeDynamicPatientSelectionSheet), findsNothing);
      expect(find.byType(DynamicPrescriptionClinicalScreen), findsNothing);
      expect(find.text('Walk-in Patient One'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Walk-in ambiguous create preserves the patient/draft and never reconciles through an empty appointment or repeats INSERT',
    (tester) async {
      final h = _Harness();
      h.transport.onBytes =
          (_) async => throw const AppFailure('Save response lost');
      await _show(tester, h, walkIn: true);
      await _tap(tester, 'dy_patient_option_201_0');
      await _tap(tester, 'dy_action_SELECT PATIENT');
      await _review(tester, addPlan: true);
      await _confirm(tester);
      await _tap(tester, 'dy_action_GENERATE');
      await _tap(tester, 'dy_save_ok');
      await _confirm(tester);
      await _tap(tester, 'dy_action_GENERATE');
      expect(find.textContaining('Check Prescription History'), findsOneWidget);
      expect(h.transport.binaryRequests, hasLength(1));
      expect(
        h.dynamicReads.where(
          (uri) => uri.pathSegments.last == 'getPrescription',
        ),
        isEmpty,
      );
      await _tap(tester, 'dy_save_ok');
      await _tap(tester, 'dy_builder_patient');
      expect(find.byKey(const Key('dy_action_CHANGE PATIENT')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  testWidgets(
    'Walk-in History load keeps the selected patient and Outdoor type for a new prescription',
    (tester) async {
      final h = _Harness();
      h.transport.onBytes = (_) async => dynamicSavedResponse();
      await _show(tester, h, walkIn: true);
      await _tap(tester, 'dy_dropdown_patient_type');
      await _tap(tester, 'dy_option_patient_type_1_1');
      await _tap(tester, 'dy_patient_option_201_0');
      await _tap(tester, 'dy_action_SELECT PATIENT');
      await _tap(tester, 'dy_builder_history');
      await _tap(tester, 'dy_history_option_600_0');
      await _tap(tester, 'dy_action_LOAD TO CURRENT RX');
      expect(find.text('Walk-in Patient One'), findsOneWidget);
      await _review(tester);
      await _confirm(tester);
      await _tap(tester, 'dy_action_GENERATE');
      final sent = h.transport.binaryRequests.single;
      expect(sent.headers['P_PAT_ID'], '101');
      expect(sent.headers['P_PH_ID'], '201');
      expect(sent.headers['P_AD_ID'], '');
      expect(sent.headers['P_PATIENT_TYPE'], '2');
      expect(sent.headers['P_PRESCRIPTION_TYPE'], '1');
      expect(sent.headers['P_RVM_ID'], isNull);
      await _tap(tester, 'dy_save_ok');
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  testWidgets(
    'Walk-in disposal cancels a debounced patient search without late GETs',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, walkIn: true);
      await tester.enterText(
        find.byKey(const Key('dy_field_patient_search')),
        'Patient',
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        h.dynamicReads.where(
          (uri) => uri.pathSegments.last == 'getPatListBySearch',
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  void assertPatientTab(WidgetTester tester, int index) {
    final layout = tester.widget<NativeDynamicBuilderLayout>(
      find.byType(NativeDynamicBuilderLayout),
    );
    final pager = tester.widget<PageView>(find.byType(PageView));
    expect(layout.selectedTab, index);
    expect(
      pager.controller!.page,
      closeTo(index, .001),
      reason: 'The visible page must match the highlighted tab and footer.',
    );
    final types = <Type>[
      NativeDynamicClinicalTab,
      NativeDynamicRxTab,
      NativeDynamicAdviceTab,
      NativeDynamicReviewTab,
    ];
    expect(find.byType(types[index]).hitTestable(), findsOneWidget);
    expect(
      find
          .byKey(
            Key(
              'dy_action_${const ['NEXT: RX', 'NEXT: ADVICE', 'NEXT: REVIEW', 'GENERATE'][index]}',
            ),
          )
          .hitTestable(),
      findsOneWidget,
    );
  }

  Future<void> changePatient(
    WidgetTester tester,
    String historyId,
    int row,
  ) async {
    await _tap(tester, 'dy_builder_patient');
    await _tap(tester, 'dy_action_CHANGE PATIENT');
    await _tap(tester, 'dy_patient_option_${historyId}_$row');
    await _tap(tester, 'dy_action_SELECT PATIENT');
    if (find
        .byKey(const Key('dy_change_patient_dialog'))
        .evaluate()
        .isNotEmpty) {
      await _tap(tester, 'dy_change_patient_confirm');
    }
  }

  for (final index in [0, 1, 2, 3]) {
    testWidgets(
      'patient switch keeps visible content, selected tab and footer aligned on ${const ['CLINICAL', 'RX', 'ADVICE', 'REVIEW'][index]}',
      (tester) async {
        final h = _Harness();
        await _show(tester, h, walkIn: true);
        await _tap(tester, 'dy_patient_option_201_0');
        await _tap(tester, 'dy_action_SELECT PATIENT');
        await _tap(
          tester,
          'dy_builder_tab_${const ['CLINICAL', 'RX', 'ADVICE', 'REVIEW'][index]}',
        );
        assertPatientTab(tester, index);
        await changePatient(tester, '202', 1);
        expect(find.text('Walk-in Patient Two'), findsOneWidget);
        assertPatientTab(tester, index);
        await _captureRx(
          tester,
          'patient_change_${const ['clinical', 'rx', 'advice', 'review'][index]}',
        );
        final next = (index + 1) % 4;
        await _tap(
          tester,
          'dy_builder_tab_${const ['CLINICAL', 'RX', 'ADVICE', 'REVIEW'][next]}',
        );
        assertPatientTab(tester, next);
        await _tap(
          tester,
          'dy_builder_tab_${const ['CLINICAL', 'RX', 'ADVICE', 'REVIEW'][index]}',
        );
        assertPatientTab(tester, index);
        expect(h.transport.binaryRequests, isEmpty);
        await tester.pumpWidget(const SizedBox());
        h.auth.dispose();
      },
    );
  }
  testWidgets(
    'a new patient draft starts with fresh Clinical scroll even when returning to a prior registration',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, walkIn: true, size: const Size(320, 640));
      await _tap(tester, 'dy_patient_option_201_0');
      await _tap(tester, 'dy_action_SELECT PATIENT');
      for (final target in [('202', 1), ('203', 2), ('201', 0)]) {
        final finder = find.byKey(
          const PageStorageKey<String>('dynamic_clinical_scroll'),
        );
        final before = tester.widget<SingleChildScrollView>(finder).controller!;
        await tester.drag(finder, const Offset(0, -180));
        await tester.pumpAndSettle();
        expect(before.offset, greaterThan(20));
        await changePatient(tester, target.$1, target.$2);
        assertPatientTab(tester, 0);
        final after = tester.widget<SingleChildScrollView>(finder).controller!;
        expect(after, isNot(same(before)));
        expect(
          after.offset,
          closeTo(0, .001),
          reason:
              'A cleared patient draft must not restore another draft\'s PageStorage offset.',
        );
      }
      expect(h.transport.binaryRequests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  testWidgets(
    'cancel and same-patient selection retain Advice content, tab and scroll',
    (tester) async {
      final h = _Harness();
      await _show(tester, h, walkIn: true, size: const Size(320, 640));
      await _tap(tester, 'dy_patient_option_201_0');
      await _tap(tester, 'dy_action_SELECT PATIENT');
      await _tap(tester, 'dy_builder_tab_ADVICE');
      final draft =
          tester
              .widget<NativeDynamicAdviceTab>(
                find.byType(NativeDynamicAdviceTab),
              )
              .draft;
      for (var i = 0; i < 30; i++) {
        draft.saveEntry(
          DynamicAdviceType.advice,
          DynamicAdviceEntry(text: 'Patient one advice $i'),
        );
      }
      await tester.pumpAndSettle();
      await _tap(tester, 'dy_toggle_advice');
      final finder = find.byKey(
        const PageStorageKey<String>('dynamic_advice_scroll'),
      );
      final controller =
          tester.widget<SingleChildScrollView>(finder).controller!;
      await tester.drag(finder, const Offset(0, -210));
      await tester.pumpAndSettle();
      final offset = controller.offset;
      expect(offset, greaterThan(20));
      for (final action in ['cancel_sheet', 'cancel_change', 'same_patient']) {
        await _tap(tester, 'dy_builder_patient');
        await _tap(tester, 'dy_action_CHANGE PATIENT');
        if (action == 'cancel_sheet') {
          await _tap(tester, 'dy_action_CANCEL');
        } else {
          await _tap(
            tester,
            action == 'same_patient'
                ? 'dy_patient_option_201_0'
                : 'dy_patient_option_202_1',
          );
          await _tap(tester, 'dy_action_SELECT PATIENT');
          if (action == 'cancel_change') {
            await _tap(tester, 'dy_change_patient_cancel');
          }
        }
        assertPatientTab(tester, 2);
        expect(find.text('Walk-in Patient One'), findsOneWidget);
        expect(draft.entries(DynamicAdviceType.advice), hasLength(30));
        expect(
          tester.widget<SingleChildScrollView>(finder).controller,
          same(controller),
        );
        expect(controller.offset, closeTo(offset, 1));
      }
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  testWidgets(
    'repeated cross-tab patient changes clear old data and save only the final patient',
    (tester) async {
      final h = _Harness();
      h.transport.onBytes = (_) async => dynamicSavedResponse();
      await _show(tester, h, walkIn: true);
      await _tap(tester, 'dy_patient_option_201_0');
      await _tap(tester, 'dy_action_SELECT PATIENT');
      for (final step in [(1, '202', 1), (2, '203', 2), (3, '201', 0)]) {
        await _tap(tester, 'dy_builder_tab_RX');
        final rx =
            tester
                .widget<NativeDynamicRxTab>(find.byType(NativeDynamicRxTab))
                .draft;
        rx.saveTreatmentPlan(
          DynamicTreatmentPlanEntry(text: 'Old patient plan ${step.$1}'),
        );
        await tester.pumpAndSettle();
        await _tap(
          tester,
          'dy_builder_tab_${const ['CLINICAL', 'RX', 'ADVICE', 'REVIEW'][step.$1]}',
        );
        await changePatient(tester, step.$2, step.$3);
        assertPatientTab(tester, step.$1);
        expect(rx.treatmentPlans, isEmpty);
      }
      await _review(tester, addPlan: true);
      await _confirm(tester);
      await _tap(tester, 'dy_action_GENERATE');
      final sent = h.transport.binaryRequests.single;
      expect(sent.headers['P_PAT_ID'], '101');
      expect(sent.headers['P_PH_ID'], '201');
      expect(sent.headers['P_AD_ID'], '');
      expect(sent.headers['P_INSERT_TYPE'], '4');
      final body = jsonDecode(utf8.decode(sent.body)) as Map;
      expect(body['treatment_plans'], [
        {'tpm_id': null, 'name': 'Local treatment plan'},
      ]);
      await _tap(tester, 'dy_save_ok');
      await tester.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  testWidgets(
    'current preview uses saved RVM and returns to the same draft tab',
    (tester) async {
      final h = _Harness();
      addTearDown(h.auth.dispose);
      await _show(tester, h, existing: true);
      await _tap(tester, 'dy_builder_tab_RX');
      final rx =
          tester
              .widget<NativeDynamicRxTab>(find.byType(NativeDynamicRxTab).first)
              .draft;
      final snapshot = rx.toBody(medicineAllowed: true);
      await _tap(tester, 'dy_builder_preview');
      expect(find.byType(NativeDynamicPreviewScreen), findsOneWidget);
      expect(
        h.dynamicReads
            .where((uri) => uri.path.endsWith('/getPreviewData'))
            .single
            .queryParameters,
        {'p_rvm_id': '900'},
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byType(NativeDynamicPreviewScreen), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await _tap(tester, 'dy_preview_back');
      expect(find.byType(NativeDynamicPreviewScreen), findsNothing);
      expect(
        tester
            .widget<NativeDynamicBuilderLayout>(
              find.byType(NativeDynamicBuilderLayout),
            )
            .selectedTab,
        1,
      );
      expect(rx.toBody(medicineAllowed: true), snapshot);
      expect(h.transport.binaryRequests, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'History preview closes selection without loading/copying source data',
    (tester) async {
      final h = _Harness();
      addTearDown(h.auth.dispose);
      await _show(tester, h, existing: true);
      await _tap(tester, 'dy_builder_tab_ADVICE');
      final advice =
          tester
              .widget<NativeDynamicAdviceTab>(
                find.byType(NativeDynamicAdviceTab).first,
              )
              .draft;
      final snapshot = advice.toBody();
      await _tap(tester, 'dy_builder_history');
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const Key('dy_action_PREVIEW')))
            .onPressed,
        isNull,
      );
      await _tap(tester, 'dy_history_option_600_0');
      await _tap(tester, 'dy_action_PREVIEW');
      expect(find.byType(NativeDynamicHistorySheet), findsNothing);
      expect(find.byType(NativeDynamicPreviewScreen), findsOneWidget);
      expect(
        h.dynamicReads
            .where((uri) => uri.path.endsWith('/getPreviewData'))
            .single
            .queryParameters,
        {'p_rvm_id': '600'},
      );
      expect(
        h.dynamicReads.where(
          (uri) => uri.path.endsWith('/loadPreviousPrescription'),
        ),
        isEmpty,
      );
      await _tap(tester, 'dy_preview_back');
      expect(
        tester
            .widget<NativeDynamicBuilderLayout>(
              find.byType(NativeDynamicBuilderLayout),
            )
            .selectedTab,
        2,
      );
      expect(advice.toBody(), snapshot);
      expect(
        tester
            .widget<NativeDynamicBuilderLayout>(
              find.byType(NativeDynamicBuilderLayout),
            )
            .data['rvm_id'],
        900,
      );
      expect(h.transport.binaryRequests, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'older appointment opens the saved prescription directly in read-only Preview',
    (tester) async {
      final h = _Harness();
      addTearDown(h.auth.dispose);
      await _show(tester, h, timeline: true);
      h.customRows = [
        {
          ...doctorAppointmentRow(day: '23-OCT-26', time: '09:00 AM'),
          'rvm': '1',
          'rvm_id': '900',
        },
      ];
      await _tap(tester, 'doctor_appointment_date_23-OCT-26');
      await _tap(tester, 'doctor_appointment_0_prescriptionPreview');
      expect(find.byType(NativeDynamicPreviewScreen), findsOneWidget);
      expect(find.byType(DynamicPrescriptionClinicalScreen), findsNothing);
      expect(
        h.dynamicReads
            .where((uri) => uri.path.endsWith('/getPreviewData'))
            .single
            .queryParameters,
        {'p_rvm_id': '900'},
      );
      expect(
        h.dynamicReads.where((uri) => uri.path.endsWith('/getPrescription')),
        isEmpty,
      );
      expect(h.transport.binaryRequests, isEmpty);
      await _tap(tester, 'dy_preview_back');
      expect(find.byType(DoctorAppointmentScreen), findsOneWidget);
      expect(find.byType(NativeDynamicPreviewScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

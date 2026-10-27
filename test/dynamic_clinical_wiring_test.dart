import 'dart:async';
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
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'doctor_appointment_test_support.dart';

class _Harness extends DoctorAppointmentHarness {
  _Harness() {
    transport.onGet = respond;
  }
  bool failExisting = false, failPatient = false;
  Completer<JsonMap>? pendingExisting;
  JsonMap get existingData => {
    'rvm_id': 900,
    'rvm_code': '2600900',
    'td_name': 'Disease template',
    'complaints': [
      {'cm_id': 1, 'name': 'Existing complain'},
    ],
    'vitals': {'pulse': '72'},
  };
  Future<JsonMap> respond(Uri uri) async {
    if (!uri.path.contains('/dynamic_presc/')) return respondAppointments(uri);
    final endpoint = uri.pathSegments.last;
    if (endpoint == 'getPrescription') {
      if (pendingExisting != null) return pendingExisting!.future;
      if (failExisting) {
        return {'status': 500, 'message': 'Prescription lookup failed'};
      }
      return {'status': 200, 'data': existingData};
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
    return {'items': []};
  }

  DynamicPrescriptionRepository get dynamicRepository =>
      DynamicPrescriptionRepository(appointments);
  DynamicPrescriptionSeed seed({bool existing = false, String? date}) =>
      DynamicPrescriptionSeed.fromExtras({
        ...doctorAppointmentRoute(
          DoctorAppointmentAction.dynamicPrescription,
          DoctorAppointmentRow({
            ...doctorAppointmentRow(),
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
    'small iPhone viewport retains native header, Clinical controls and inactive next stage',
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
        isNull,
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
}

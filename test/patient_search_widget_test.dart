import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/patient_search/native_patient_search_layout.dart';
import 'package:docdiary_ios/features/patient_search/native_patient_search_year_dialog.dart';
import 'package:docdiary_ios/features/patient_search/native_patient_prescription_history_sheet.dart';
import 'package:docdiary_ios/features/patient_search/patient_search_screen.dart';
import 'package:docdiary_ios/features/patient_search/patient_appointment_calendar_screen.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/progress/doctor_progress_screen.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_preview_screen.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_clinical_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'patient_search_test_support.dart';
import 'dynamic_preview_test_support.dart';

Future<void> _tap(WidgetTester t, String key, {bool settle = true}) async {
  final finder = find.byKey(Key(key));
  if (finder.hitTestable().evaluate().isEmpty) {
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
  }
  await t.tap(finder);
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }
  expect(t.takeException(), isNull);
}

Future<void> _host(
  WidgetTester t,
  PatientSearchHarness h, {
  bool app = false,
  bool settle = true,
  Size size = const Size(393, 852),
  double scale = 1,
  DashboardDestinationBuilder? destinationBuilder,
  FakeDynamicPreviewPlatform? platform,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPadding);
  addTearDown(t.view.resetViewInsets);
  if (!app) addTearDown(h.auth.dispose);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await h.signIn();
  h.transport.requests.clear();
  final root =
      app
          ? DocDiaryApp(
            auth: h.auth,
            initializeOnStart: false,
            dashboard: DashboardRepository(h.transport, now: () => h.now),
          )
          : MaterialApp(
            theme: docDiaryTheme(),
            debugShowCheckedModeBanner: false,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => TextButton(
                      key: const Key('open_patient_search'),
                      onPressed:
                          () => unawaited(
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder:
                                    (_) => PatientSearchScreen(
                                      auth: h.auth,
                                      repository: h.searchRepository,
                                      destinationBuilder: destinationBuilder,
                                      previewPlatform: platform,
                                    ),
                              ),
                            ),
                          ),
                      child: const Text('Open Patient Search'),
                    ),
              ),
            ),
          );
  await t.pumpWidget(
    RepaintBoundary(key: const Key('patient_search_capture'), child: root),
  );
  await t.pumpAndSettle();
  await _tap(
    t,
    app ? 'dashboard_nav_patients' : 'open_patient_search',
    settle: settle,
  );
}

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> _capture(WidgetTester t, String name) async {
  final output = Platform.environment['PATIENT_SEARCH_RENDER_DIR'];
  if (output == null) return;
  final context = t.element(find.byKey(const Key('patient_search_capture')));
  final images =
      t
          .widgetList<Image>(find.byType(Image))
          .map((image) => image.image)
          .toList();
  await t.runAsync(() async {
    for (final image in images) {
      await precacheImage(image, context);
    }
  });
  await t.pumpAndSettle();
  final shadows = debugDisableShadows;
  try {
    debugDisableShadows = false;
    void repaint(RenderObject object) {
      object.markNeedsPaint();
      object.visitChildren(repaint);
    }

    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('patient_search_capture')),
    );
    repaint(boundary);
    await t.pump();
    await t.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 2);
      try {
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$output/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        img.dispose();
      }
    });
  } finally {
    debugDisableShadows = shadows;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final entry
        in {
          'Poppins': [
            'Poppins-Regular.ttf',
            'Poppins-Medium.ttf',
            'Poppins-SemiBold.ttf',
            'Poppins-Bold.ttf',
          ],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
          'PatuaOne': ['PatuaOne-Regular.ttf'],
        }.entries) {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }
  });
  for (final dynamicMode in [false, true]) {
    testWidgets(
      'dashboard uses actual ${dynamicMode ? "dynamic" : "normal"} PatientSearch default route',
      (t) async {
        final h = PatientSearchHarness(dynamicMode: dynamicMode);
        await _host(t, h, app: true);
        expect(find.byType(PatientSearchScreen), findsOneWidget);
        expect(find.text("Patient's Prescription"), findsOneWidget);
        expect(
          h.patientReads.single.pathSegments.last,
          dynamicMode ? 'getDyPresPatientList' : 'getPatientListNew',
        );
        expect(h.posts, isEmpty);
        await _finish(t);
      },
    );
    testWidgets(
      '${dynamicMode ? "dynamic" : "normal"} native cards, HP and year dialog match the shared pattern',
      (t) async {
        final h = PatientSearchHarness(dynamicMode: dynamicMode);
        await _host(t, h);
        expect(find.text('No Progress Found'), findsOneWidget);
        expect(find.text('APPOINTMENT VIEW'), findsNWidgets(2));
        expect(find.text('VIEW PROGRESS'), findsOneWidget);
        expect(
          find.text('Male  •  31 Years 3 Months 29 Days'),
          findsNWidgets(2),
        );
        expect(
          t
              .widget<LinearProgressIndicator>(
                find.byKey(const Key('patient_search_hp_12')),
              )
              .value,
          .6,
        );
        final yearKey =
            dynamicMode ? 'patient_search_year' : 'normal_patient_year';
        await _tap(t, yearKey);
        expect(find.byType(NativePatientSearchYearDialog), findsOneWidget);
        expect(find.text('Selected Year'), findsOneWidget);
        await _tap(t, 'patient_search_year_2023');
        expect(
          t
              .widget<Text>(
                find.byKey(const Key('patient_search_selected_year')),
              )
              .data,
          '2023',
        );
        final count = h.patientReads.length;
        await _tap(t, 'patient_search_year_cancel');
        expect(h.patientReads, hasLength(count));
        expect(
          find.text('${dynamicMode ? "Search Year" : "Year"}: 2026'),
          findsOneWidget,
        );
        await _tap(t, yearKey);
        await _tap(t, 'patient_search_year_2023');
        await _capture(
          t,
          dynamicMode ? 'dynamic_year_dialog' : 'normal_year_dialog',
        );
        await _tap(t, 'patient_search_year_ok');
        expect(h.patientReads.last.queryParameters['p_year'], '2023');
        expect(
          find.text('${dynamicMode ? "Search Year" : "Year"}: 2023'),
          findsOneWidget,
        );
        await _capture(t, dynamicMode ? 'dynamic_patients' : 'normal_patients');
        await _finish(t);
      },
    );
    testWidgets(
      '${dynamicMode ? "dynamic" : "normal"} empty message stays below the search controls',
      (t) async {
        final h = PatientSearchHarness(dynamicMode: dynamicMode)
          ..patientRows = [];
        await _host(t, h);
        expect(find.text("No Patient's Prescription Found"), findsOneWidget);
        expect(find.byType(NativePatientSearchCard), findsNothing);
        await _capture(t, dynamicMode ? 'dynamic_empty' : 'normal_empty');
        await _finish(t);
      },
    );
  }
  testWidgets(
    'dynamic typing keeps keyboard focus; Done hides it; only search button dispatches',
    (t) async {
      final h = PatientSearchHarness();
      await _host(t, h);
      final query = find.byKey(const Key('patient_search_query')),
          count = h.patientReads.length;
      await t.enterText(query, 'বাংলা & Name');
      await t.pump();
      expect(t.testTextInput.isVisible, isTrue);
      expect(t.widget<TextField>(query).focusNode!.hasFocus, isTrue);
      expect(h.patientReads, hasLength(count));
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(h.patientReads, hasLength(count));
      await _tap(t, 'patient_search_submit');
      expect(h.patientReads, hasLength(count + 1));
      expect(h.patientReads.last.queryParameters, {
        'p_search': 'বাংলা & Name',
        'p_doc_id': '10',
      });
      expect(
        find.text('Showing all searched registered patients'),
        findsOneWidget,
      );
      await _tap(t, 'patient_search_clear');
      expect(t.widget<TextField>(query).controller!.text, isEmpty);
      expect(h.patientReads, hasLength(count + 1));
      await _tap(t, 'patient_search_submit');
      expect(
        find.text('Please write patient name, code or mobile before search'),
        findsOneWidget,
      );
      await t.enterText(query, 'ab');
      await _tap(t, 'patient_search_submit');
      expect(
        find.text('Please write at least 3 characters before search'),
        findsOneWidget,
      );
      expect(h.patientReads, hasLength(count + 1));
      await _capture(t, 'dynamic_search_validation');
      await _finish(t);
    },
  );
  testWidgets(
    'normal filter makes no server search and returning from a view keeps query and scroll',
    (t) async {
      final h = PatientSearchHarness(dynamicMode: false);
      h.patientRows = List.generate(
        30,
        (i) =>
            searchedPatient(id: '${i + 11}', name: 'Sample Patient ${i + 1}'),
      );
      final routes = <DashboardRoute>[];
      await _host(
        t,
        h,
        destinationBuilder: (context, route) {
          routes.add(route);
          return Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('search_child_back'),
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ),
          );
        },
      );
      await t.enterText(
        find.byKey(const Key('normal_patient_search')),
        'sample',
      );
      await t.pumpAndSettle();
      expect(h.patientReads, hasLength(1));
      await t.drag(
        find.byKey(const Key('patient_search_list')),
        const Offset(0, -750),
      );
      await t.pumpAndSettle();
      final list = t.widget<ListView>(
            find.byKey(const Key('patient_search_list')),
          ),
          offset =
              t
                  .widget<ListView>(
                    find.byKey(const Key('patient_search_list')),
                  )
                  .controller!
                  .offset;
      expect(offset, greaterThan(100));
      final card = t.widget<NativePatientSearchCard>(
        find.byType(NativePatientSearchCard).hitTestable().first,
      );
      await _tap(t, 'patient_search_prescription_${card.patient.historyId}');
      expect(routes.single.module, DashboardModule.doctorLegacyPrescription);
      expect(routes.single.extras['FROM_PSV'], 'true');
      await _tap(t, 'search_child_back');
      expect(
        t
            .widget<ListView>(find.byKey(const Key('patient_search_list')))
            .controller,
        same(list.controller),
      );
      expect(list.controller!.offset, closeTo(offset, .5));
      expect(
        t
            .widget<TextField>(find.byKey(const Key('normal_patient_search')))
            .controller!
            .text,
        'sample',
      );
      expect(h.patientReads, hasLength(1));
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  testWidgets(
    'dynamic patient card opens fresh preview-only history and selected prescription preview',
    (t) async {
      final h = PatientSearchHarness(), platform = FakeDynamicPreviewPlatform();
      await _host(t, h, platform: platform);
      await _tap(t, 'patient_search_prescription_11');
      expect(
        find.byType(NativePatientPrescriptionHistorySheet),
        findsOneWidget,
      );
      expect(find.text('Select a prescription to preview'), findsOneWidget);
      expect(find.text('LOAD TO CURRENT RX'), findsNothing);
      expect(
        t
            .widget<ElevatedButton>(find.byKey(const Key('dy_action_PREVIEW')))
            .onPressed,
        isNull,
      );
      await _tap(t, 'patient_search_history_option_599_1');
      await _capture(t, 'patient_prescription_history');
      await _tap(t, 'dy_action_PREVIEW');
      expect(find.byType(NativeDynamicPreviewScreen), findsOneWidget);
      expect(find.byType(DynamicPrescriptionClinicalScreen), findsNothing);
      expect(
        h.transport.requests
            .lastWhere((r) => r.uri.path.endsWith('/getPreviewData'))
            .uri
            .queryParameters,
        {'p_rvm_id': '599'},
      );
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await _tap(t, 'patient_search_prescription_11');
      expect(
        t
            .widget<ElevatedButton>(find.byKey(const Key('dy_action_PREVIEW')))
            .onPressed,
        isNull,
      );
      expect(
        h.transport.requests.where(
          (r) => r.uri.path.endsWith('/getPrescriptionHistory'),
        ),
        hasLength(2),
      );
      await _tap(t, 'patient_search_history_close');
      expect(h.posts, isEmpty);
      expect(h.transport.binaryRequests, isEmpty);
      await _finish(t);
    },
  );
  testWidgets(
    'history error can retry, then empty history keeps preview disabled',
    (t) async {
      final h = PatientSearchHarness()..failHistory = true;
      await _host(t, h);
      await _tap(t, 'patient_search_prescription_11');
      expect(find.text('History unavailable'), findsOneWidget);
      h.failHistory = false;
      h.historyRecords = [];
      await _tap(t, 'patient_search_history_retry');
      expect(find.text('No prescription history found'), findsOneWidget);
      expect(
        t
            .widget<ElevatedButton>(find.byKey(const Key('dy_action_PREVIEW')))
            .onPressed,
        isNull,
      );
      await _tap(t, 'patient_search_history_close');
      await _finish(t);
    },
  );
  testWidgets(
    'View Progress opens patient read mode and never enables adding progress',
    (t) async {
      final h = PatientSearchHarness();
      await _host(t, h);
      await _tap(t, 'patient_search_progress_12');
      final screen = t.widget<DoctorProgressScreen>(
        find.byType(DoctorProgressScreen),
      );
      expect(screen.seed.patientId, '12');
      expect(screen.seed.appointment, isNull);
      expect(screen.seed.mayAdd(h.now), isFalse);
      expect(
        h.transport.requests
            .where((r) => r.uri.path.endsWith('/getHealthProgress'))
            .single
            .uri
            .queryParameters,
        {'p_ph_id': '12'},
      );
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  testWidgets(
    'Appointment View loads native range and a day shows completed/upcoming/canceled rows',
    (t) async {
      final h = PatientSearchHarness();
      await _host(t, h);
      await _tap(t, 'patient_search_appointments_11');
      expect(find.byType(PatientAppointmentCalendarScreen), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      expect(
        find.byKey(const Key('patient_calendar_marker_2026_10_24')),
        findsOneWidget,
      );
      await _capture(t, 'patient_appointment_calendar');
      await _tap(t, 'patient_calendar_day_10_2026_10_24');
      expect(
        find.byKey(const Key('patient_calendar_day_sheet')),
        findsOneWidget,
      );
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Canceled'), findsOneWidget);
      await _capture(t, 'patient_appointment_day');
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await _tap(t, 'patient_calendar_previous');
      expect(find.text('September 2026'), findsOneWidget);
      expect(
        t
            .widget<IconButton>(
              find.byKey(const Key('patient_calendar_previous')),
            )
            .onPressed,
        isNull,
      );
      for (var i = 0; i < 3; i++) {
        await _tap(t, 'patient_calendar_next');
      }
      expect(find.text('December 2026'), findsOneWidget);
      expect(
        t
            .widget<IconButton>(find.byKey(const Key('patient_calendar_next')))
            .onPressed,
        isNull,
      );
      expect(
        h.transport.requests.where(
          (r) => r.uri.path.endsWith('/getPatAppointment'),
        ),
        hasLength(1),
      );
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  testWidgets(
    'loading blocks Back; failed patient GET retries the same query without any write',
    (t) async {
      final h = PatientSearchHarness()..pendingPatients = Completer<JsonMap>();
      await _host(t, h, settle: false);
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.byType(PatientSearchScreen), findsOneWidget);
      h.pendingPatients!.complete({'pat_list': h.patientRows});
      h.pendingPatients = null;
      await t.pumpAndSettle();
      h.failPatients = true;
      await t.enterText(
        find.byKey(const Key('patient_search_query')),
        'mobile123',
      );
      await _tap(t, 'patient_search_submit');
      expect(
        find.byKey(const Key('patient_search_error_dialog')),
        findsOneWidget,
      );
      h.failPatients = false;
      await _tap(t, 'patient_search_error_retry');
      expect(h.patientReads.last.queryParameters['p_search'], 'mobile123');
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  testWidgets(
    'background discards a late search response and resumes the committed query',
    (t) async {
      final h = PatientSearchHarness();
      await _host(t, h);
      final pending = Completer<JsonMap>();
      h.pendingPatients = pending;
      await t.enterText(
        find.byKey(const Key('patient_search_query')),
        'search name',
      );
      await _tap(t, 'patient_search_submit', settle: false);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      h.pendingPatients = null;
      h.patientRows = [searchedPatient(name: 'Fresh Patient')];
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      pending.complete({
        'pat_list': [searchedPatient(name: 'Obsolete Patient')],
      });
      await t.pumpAndSettle();
      expect(find.text('Fresh Patient'), findsOneWidget);
      expect(find.text('Obsolete Patient'), findsNothing);
      expect(h.patientReads.last.queryParameters['p_search'], 'search name');
      await _finish(t);
    },
  );
  testWidgets(
    'changed scope refreshes the patient list before opening any history',
    (t) async {
      final h = PatientSearchHarness();
      await _host(t, h);
      h.doctorData['all_presc'] = '1';
      await _tap(t, 'patient_search_prescription_11');
      expect(find.byType(NativePatientPrescriptionHistorySheet), findsNothing);
      expect(
        h.patientReads.last.queryParameters.containsKey('p_doc_id'),
        isFalse,
      );
      await _tap(t, 'patient_search_prescription_11');
      expect(
        h.transport.requests
            .singleWhere((r) => r.uri.path.endsWith('/getPrescriptionHistory'))
            .uri
            .queryParameters['p_doc_id'],
        '',
      );
      await _tap(t, 'patient_search_history_close');
      await _finish(t);
    },
  );
  testWidgets('revoked access is checked before another patient GET', (
    t,
  ) async {
    final h = PatientSearchHarness();
    await _host(t, h, app: true);
    final count = h.patientReads.length;
    h.doctorData['access_flag'] = '0';
    await t.enterText(find.byKey(const Key('patient_search_query')), 'patient');
    await _tap(t, 'patient_search_submit');
    expect(h.auth.stage, isNot(AuthStage.authenticated));
    expect(h.patientReads, hasLength(count));
    expect(find.byType(NativePatientSearchCard), findsNothing);
    await _finish(t);
  });
  for (final size in [
    const Size(280, 568),
    const Size(852, 393),
    const Size(768, 1024),
  ]) {
    testWidgets(
      'search and year controls remain usable at $size and large text',
      (t) async {
        final h = PatientSearchHarness();
        await _host(t, h, size: size, scale: 1.8);
        await _tap(t, 'patient_search_year');
        await t.ensureVisible(find.byKey(const Key('patient_search_year_ok')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await _tap(t, 'patient_search_year_cancel');
        await _finish(t);
      },
    );
  }
  testWidgets(
    'year dialog includes 1950, excludes future years and commits only with OK',
    (t) async {
      final h = PatientSearchHarness();
      await _host(t, h);
      await _tap(t, 'patient_search_year');
      final list = find.descendant(
        of: find.byKey(const Key('patient_search_year_list')),
        matching: find.byType(Scrollable),
      );
      await t.scrollUntilVisible(
        find.byKey(const Key('patient_search_year_1950')),
        -400,
        scrollable: list,
        maxScrolls: 30,
      );
      await _tap(t, 'patient_search_year_1950');
      expect(h.patientReads, hasLength(1));
      expect(find.byKey(const Key('patient_search_year_2027')), findsNothing);
      await _tap(t, 'patient_search_year_ok');
      expect(h.patientReads.last.queryParameters['p_year'], '1950');
      await _finish(t);
    },
  );
  testWidgets(
    'logout closes an in-flight History sheet and discards its late patient data',
    (t) async {
      final h = PatientSearchHarness();
      await _host(t, h, app: true);
      final pending = Completer<JsonMap>();
      h.pendingHistory = pending;
      await _tap(t, 'patient_search_prescription_11', settle: false);
      expect(
        find.byKey(const Key('patient_search_history_progress')),
        findsOneWidget,
      );
      await h.auth.logout();
      await t.pumpAndSettle();
      pending.complete({'items': h.historyRecords});
      await t.pumpAndSettle();
      expect(find.byType(NativePatientPrescriptionHistorySheet), findsNothing);
      expect(find.byType(PatientSearchScreen), findsNothing);
      expect(
        h.transport.requests.where(
          (r) => r.uri.path.endsWith('/getPreviewData'),
        ),
        isEmpty,
      );
      await _finish(t);
    },
  );
  testWidgets(
    'calendar week spacing stays fixed when the available screen height changes',
    (t) async {
      final h = PatientSearchHarness();
      await _host(t, h);
      await _tap(t, 'patient_search_appointments_11');
      final a = find.byKey(const Key('patient_calendar_day_10_2026_10_3'));
      final b = find.byKey(const Key('patient_calendar_day_10_2026_10_10'));
      final before = t.getCenter(b).dy - t.getCenter(a).dy;
      t.view.physicalSize = const Size(393, 1024);
      await t.pumpAndSettle();
      expect(t.getCenter(b).dy - t.getCenter(a).dy, closeTo(before, .01));
      expect(find.text('Sat'), findsNothing);
      expect(find.text('Fri'), findsNothing);
      expect(t.takeException(), isNull);
      await _finish(t);
    },
  );
  testWidgets(
    'native day sheet centers schedule, keeps visit left and aligns doctor details',
    (t) async {
      final h = PatientSearchHarness();
      h.now = DateTime(2026, 10, 29, 18, 35);
      h.calendarRecords = [
        {
          ...patientCalendarRow(day: '25-OCT-26', time: '09:30 AM'),
          'pfn_fee_name': 'Speech & Language Therapy Service Charge',
          'doc_name': 'Sample Therapist A',
          'depts_name': 'Assessment',
          'deptd_name': 'Speech & Language Therapy Department',
        },
        {
          ...patientCalendarRow(day: '25-OCT-26', time: '05:00 PM'),
          'doc_name': 'Sample Therapist B',
          'depts_name': 'Communication Group',
          'deptd_name': 'Speech & Language Therapy Department',
        },
      ];
      await _host(t, h);
      await _tap(t, 'patient_search_appointments_11');
      await _capture(t, 'patient_appointment_calendar');
      await _tap(t, 'patient_calendar_day_10_2026_10_25');
      final card = t.getRect(
        find.byKey(const Key('patient_calendar_appointment_0')),
      );
      final time = t.getRect(
        find.byKey(const Key('patient_calendar_schedule_time_0')),
      );
      final type = t.getRect(
        find.byKey(const Key('patient_calendar_schedule_type_0')),
      );
      final visit = t.getRect(
        find.byKey(const Key('patient_calendar_visit_type_0')),
      );
      final status = t.getRect(
        find.byKey(const Key('patient_calendar_status_0')),
      );
      expect(time.center.dx, closeTo(card.center.dx, .01));
      expect(type.center.dx, closeTo(time.center.dx, .01));
      expect(visit.right, lessThan(time.left));
      expect(status.left, greaterThan(time.right));
      final doctorX =
          t.getTopLeft(find.byKey(const Key('patient_calendar_doctor_0'))).dx;
      expect(
        t.getTopLeft(find.byKey(const Key('patient_calendar_depts_name_0'))).dx,
        closeTo(doctorX, .01),
      );
      expect(
        t.getTopLeft(find.byKey(const Key('patient_calendar_deptd_name_0'))).dx,
        closeTo(doctorX, .01),
      );
      await _capture(t, 'patient_appointment_day');
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  testWidgets(
    'large-text landscape calendar and day sheet keep their full contents reachable',
    (t) async {
      final h = PatientSearchHarness();
      h.calendarRecords = List.generate(
        8,
        (i) => {
          ...patientCalendarRow(),
          'doc_name': 'Sample Therapist ${i + 1}',
        },
      );
      await _host(t, h, size: const Size(852, 393), scale: 1.8);
      await _tap(t, 'patient_search_appointments_11');
      final calendarScroll =
          find
              .descendant(
                of: find.byKey(const Key('patient_calendar_scroll')),
                matching: find.byType(Scrollable),
              )
              .first;
      await t.scrollUntilVisible(
        find.byKey(const Key('patient_calendar_day_10_2026_10_24')),
        160,
        scrollable: calendarScroll,
      );
      await _tap(t, 'patient_calendar_day_10_2026_10_24');
      final scroll = find.descendant(
        of: find.byKey(const Key('patient_calendar_day_scroll')),
        matching: find.byType(Scrollable),
      );
      await t.scrollUntilVisible(
        find.byKey(const Key('patient_calendar_appointment_7')),
        300,
        scrollable: scroll,
      );
      await t.ensureVisible(find.byKey(const Key('patient_calendar_doctor_7')));
      await t.pumpAndSettle();
      expect(find.text('Sample Therapist 8').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
      await _finish(t);
    },
  );
}

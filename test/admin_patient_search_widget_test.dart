import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/patient_search/admin_patient_search_screen.dart';
import 'package:docdiary_ios/features/patient_search/native_patient_search_layout.dart';
import 'package:docdiary_ios/features/patient_search/patient_appointment_calendar_screen.dart';
import 'package:docdiary_ios/features/prescription/normal_prescription_screen.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/progress/doctor_progress_screen.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_clinical_screen.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_preview_screen.dart';
import 'package:docdiary_ios/features/dynamic_prescription/native_dynamic_preview_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'admin_patient_search_test_support.dart';
import 'patient_search_test_support.dart';
import 'dynamic_preview_test_support.dart';

Future<void> tap(WidgetTester t, String key, {bool settle = true}) async {
  final f = find.byKey(Key(key));
  if (f.hitTestable().evaluate().isEmpty) {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
  }
  await t.tap(f);
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }
  expect(t.takeException(), isNull);
}

Future<void> host(
  WidgetTester t,
  AdminPatientSearchHarness h, {
  bool app = false,
  bool settle = true,
  Size size = const Size(393, 852),
  double scale = 1,
  DashboardDestinationBuilder? destinationBuilder,
  Future<bool> Function(Uri)? openPhone,
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
                      key: const Key('open_admin_search'),
                      onPressed:
                          () => unawaited(
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder:
                                    (_) => AdminPatientSearchScreen(
                                      auth: h.auth,
                                      repository: h.adminSearch,
                                      destinationBuilder: destinationBuilder,
                                      openPhone: openPhone,
                                      previewPlatform: platform,
                                    ),
                              ),
                            ),
                          ),
                      child: const Text('Open Admin Patient Search'),
                    ),
              ),
            ),
          );
  await t.pumpWidget(
    RepaintBoundary(key: const Key('admin_search_capture'), child: root),
  );
  await t.pumpAndSettle();
  await tap(
    t,
    app ? 'dashboard_nav_patients' : 'open_admin_search',
    settle: settle,
  );
}

Future<void> finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> search(WidgetTester t, String query) async {
  await t.enterText(find.byKey(const Key('admin_patient_search_query')), query);
  await tap(t, 'admin_patient_search_submit');
}

Future<void> capture(WidgetTester t, String name) async {
  final output = Platform.environment['ADMIN_PATIENT_SEARCH_RENDER_DIR'];
  if (output == null) return;
  final context = t.element(find.byKey(const Key('admin_search_capture')));
  final providers =
      t.widgetList<Image>(find.byType(Image)).map((w) => w.image).toList();
  await t.runAsync(() async {
    for (final image in providers) {
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
      find.byKey(const Key('admin_search_capture')),
    );
    repaint(boundary);
    await t.pump();
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$output/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
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
  testWidgets(
    'Admin dashboard opens native Patient Search with shared accepted cards and hidden ADD',
    (t) async {
      final h = AdminPatientSearchHarness();
      await host(t, h, app: true);
      expect(find.byType(AdminPatientSearchScreen), findsOneWidget);
      expect(find.text('Patient Search'), findsOneWidget);
      expect(find.text('ADD'), findsNothing);
      expect(find.text('Latest 100 Patients'), findsOneWidget);
      expect(find.byType(NativePatientSearchCard), findsNWidgets(2));
      expect(find.text('No Progress Found'), findsOneWidget);
      expect(h.patientReads.single.pathSegments.last, 'getHundredPatListNew');
      expect(h.posts, isEmpty);
      await capture(t, 'admin_patient_search_latest');
      await finish(t);
    },
  );
  testWidgets(
    'keyboard Done only closes keyboard and search keeps the supplied input settings',
    (t) async {
      final h = AdminPatientSearchHarness();
      await host(t, h);
      final field = find.byKey(const Key('admin_patient_search_query'));
      await t.enterText(field, 'Sample');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(h.patientReads, hasLength(1));
      final w = t.widget<TextField>(field);
      expect(w.textInputAction, TextInputAction.done);
      expect(w.autocorrect, isFalse);
      expect(w.enableSuggestions, isFalse);
      expect(w.smartDashesType, SmartDashesType.disabled);
      expect(w.smartQuotesType, SmartQuotesType.disabled);
      await finish(t);
    },
  );
  testWidgets(
    'search and Clear restore cached recent list without another patient GET',
    (t) async {
      final h = AdminPatientSearchHarness();
      h.searchedRows = [searchedPatient(id: '99', name: 'Found Patient')];
      await host(t, h);
      await search(t, 'Found Patient');
      expect(find.text('Found Patient'), findsNWidgets(2));
      expect(find.text('Latest 100 Patients'), findsNothing);
      expect(
        find.byKey(const Key('admin_patient_search_clear')),
        findsOneWidget,
      );
      expect(h.patientReads.last.queryParameters, {
        'p_year': '2026',
        'p_name': 'Found Patient',
      });
      await capture(t, 'admin_patient_search_results');
      final count = h.patientReads.length;
      await tap(t, 'admin_patient_search_clear');
      expect(h.patientReads, hasLength(count));
      expect(find.text('Sample Patient'), findsOneWidget);
      expect(find.text('Latest 100 Patients'), findsOneWidget);
      expect(
        t
            .widget<TextField>(
              find.byKey(const Key('admin_patient_search_query')),
            )
            .controller!
            .text,
        '',
      );
      await finish(t);
    },
  );
  for (final query in ['', 'ab', 'a.b', 'a,b', 'a-b']) {
    testWidgets('invalid search "$query" does not request patient data', (
      t,
    ) async {
      final h = AdminPatientSearchHarness();
      await host(t, h);
      await search(t, query);
      expect(
        find.byKey(const Key('admin_patient_search_helper')),
        findsOneWidget,
      );
      expect(h.patientReads, hasLength(1));
      await finish(t);
    });
  }
  testWidgets(
    'typing punctuation shows Invalid Character and a valid edit clears the hint',
    (t) async {
      final h = AdminPatientSearchHarness();
      await host(t, h);
      await t.enterText(
        find.byKey(const Key('admin_patient_search_query')),
        'a.b',
      );
      await t.pump();
      expect(find.text('Invalid Character'), findsOneWidget);
      await t.enterText(
        find.byKey(const Key('admin_patient_search_query')),
        'abc',
      );
      await t.pump();
      expect(find.text('Invalid Character'), findsNothing);
      await finish(t);
    },
  );
  testWidgets(
    'year only commits on OK and then resets the search and cached list',
    (t) async {
      final h = AdminPatientSearchHarness();
      await host(t, h);
      await search(t, 'Sample');
      await tap(t, 'admin_patient_search_year');
      await tap(t, 'patient_search_year_2023');
      await tap(t, 'patient_search_year_cancel');
      expect(find.text('Year: 2026'), findsOneWidget);
      expect(h.patientReads, hasLength(2));
      await tap(t, 'admin_patient_search_year');
      await tap(t, 'patient_search_year_2023');
      await capture(t, 'admin_patient_search_year');
      await tap(t, 'patient_search_year_ok');
      expect(h.patientReads.last.queryParameters, {'p_year': '2023'});
      expect(find.byKey(const Key('admin_patient_search_clear')), findsNothing);
      await finish(t);
    },
  );
  testWidgets(
    'empty recent list hides Latest 100 and empty search still exposes Clear',
    (t) async {
      final h = AdminPatientSearchHarness();
      h.patientRows = [];
      await host(t, h);
      expect(find.text('No Patient Found'), findsOneWidget);
      expect(find.text('Latest 100 Patients'), findsNothing);
      await capture(t, 'admin_patient_search_empty');
      await search(t, 'Missing');
      expect(find.text('No Patient Found'), findsOneWidget);
      expect(
        find.byKey(const Key('admin_patient_search_clear')),
        findsOneWidget,
      );
      await tap(t, 'admin_patient_search_clear');
      await finish(t);
    },
  );
  for (final canCall in [false, true]) {
    testWidgets(
      'call visibility follows native permission $canCall and missing number',
      (t) async {
        final h = AdminPatientSearchHarness(canCall: canCall);
        h.patientRows[1] = {...h.patientRows[1], 'pat_cell': null};
        await host(t, h);
        expect(
          find.byKey(const Key('patient_search_call_11')),
          canCall ? findsOneWidget : findsNothing,
        );
        expect(find.byKey(const Key('patient_search_call_12')), findsNothing);
        if (!canCall) await capture(t, 'admin_patient_search_limited_access');
        await finish(t);
      },
    );
  }
  testWidgets(
    'call NO keeps search and YES opens only the tel dialer after rechecking access',
    (t) async {
      final h = AdminPatientSearchHarness();
      final calls = <Uri>[];
      await host(
        t,
        h,
        openPhone: (uri) async {
          calls.add(uri);
          return true;
        },
      );
      await tap(t, 'patient_search_call_11');
      expect(
        find.text('Do you want to make a call to Sample Patient ?'),
        findsOneWidget,
      );
      await capture(t, 'admin_patient_search_call');
      await tap(t, 'admin_patient_call_no');
      expect(calls, isEmpty);
      await tap(t, 'patient_search_call_11');
      await tap(t, 'admin_patient_call_yes');
      expect(calls.single.scheme, 'tel');
      expect(calls.single.path, '01700000000');
      expect(h.posts, isEmpty);
      expect(
        h.transport.requests.where(
          (r) => r.uri.path.endsWith('/getPrescriptionHistory'),
        ),
        isEmpty,
      );
      await finish(t);
    },
  );
  testWidgets(
    'revoking call permission while confirmation is open prevents dialing',
    (t) async {
      final h = AdminPatientSearchHarness();
      final calls = <Uri>[];
      await host(
        t,
        h,
        openPhone: (uri) async {
          calls.add(uri);
          return true;
        },
      );
      await tap(t, 'patient_search_call_11');
      h.adminData['all_access_flag'] = '0';
      await tap(t, 'admin_patient_call_yes');
      expect(calls, isEmpty);
      expect(find.byKey(const Key('patient_search_call_11')), findsNothing);
      await finish(t);
    },
  );
  testWidgets(
    'phone launch failure reports an error and returns to the existing list',
    (t) async {
      final h = AdminPatientSearchHarness();
      await host(t, h, openPhone: (_) async => false);
      await tap(t, 'patient_search_call_11');
      await tap(t, 'admin_patient_call_yes');
      expect(
        find.textContaining('Could not open the phone dialer.'),
        findsOneWidget,
      );
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      expect(find.text('Sample Patient'), findsOneWidget);
      await finish(t);
    },
  );
  testWidgets(
    'normal Admin patient card opens existing read-only prescription screen',
    (t) async {
      final h = AdminPatientSearchHarness(dynamicMode: false);
      await host(t, h);
      await tap(t, 'patient_search_prescription_11');
      expect(find.byType(NormalPrescriptionScreen), findsOneWidget);
      expect(find.byKey(const Key('rx_view_only')), findsOneWidget);
      expect(find.byKey(const Key('rx_create')), findsNothing);
      expect(find.byKey(const Key('rx_add_complain')), findsNothing);
      expect(h.posts, isEmpty);
      await finish(t);
    },
  );
  for (final dynamicMode in [false, true]) {
    testWidgets(
      'missing patient id prevents ${dynamicMode ? "dynamic" : "normal"} prescription navigation',
      (t) async {
        final h = AdminPatientSearchHarness(dynamicMode: dynamicMode);
        h.patientRows[0] = {...h.patientRows[0], 'pat_id': ''};
        await host(t, h);
        await tap(t, 'patient_search_prescription_11');
        expect(
          find.textContaining(
            'Select a patient before viewing prescription history.',
          ),
          findsOneWidget,
        );
        expect(
          h.transport.requests.where(
            (r) =>
                r.uri.path.endsWith('/getPrescriptionHistory') ||
                r.uri.path.endsWith('/getPatData'),
          ),
          isEmpty,
        );
        await finish(t);
      },
    );
  }
  testWidgets(
    'Admin dynamic History opens real preview and export with no doctor or builder access',
    (t) async {
      final h = AdminPatientSearchHarness();
      final platform = FakeDynamicPreviewPlatform();
      await host(t, h, platform: platform);
      await tap(t, 'patient_search_prescription_11');
      expect(
        h.transport.requests
            .singleWhere((r) => r.uri.path.endsWith('/getPrescriptionHistory'))
            .uri
            .queryParameters['p_doc_id'],
        '',
      );
      await tap(t, 'patient_search_history_option_599_1');
      await tap(t, 'dy_action_PREVIEW');
      expect(find.byType(NativeDynamicPreviewScreen), findsOneWidget);
      expect(platform.html, contains('<html'));
      expect(find.byType(DynamicPrescriptionClinicalScreen), findsNothing);
      await tap(t, 'dy_action_SHARE');
      expect(platform.actions, [DynamicPreviewAction.share]);
      expect(h.posts, isEmpty);
      await finish(t);
    },
  );
  testWidgets(
    'Admin progress is view-only and calendar uses the accepted compact native layout',
    (t) async {
      final h = AdminPatientSearchHarness();
      await host(t, h);
      await tap(t, 'patient_search_progress_12');
      expect(find.byType(DoctorProgressScreen), findsOneWidget);
      expect(find.byKey(const Key('doctor_progress_add_tab')), findsNothing);
      expect(find.byKey(const Key('doctor_progress_submit')), findsNothing);
      await tap(t, 'doctor_progress_back');
      await tap(t, 'patient_search_appointments_11');
      expect(find.byType(PatientAppointmentCalendarScreen), findsOneWidget);
      expect(find.text('Sat'), findsNothing);
      await tap(t, 'patient_calendar_day_10_2026_10_24');
      expect(
        find.byKey(const Key('patient_calendar_day_sheet')),
        findsOneWidget,
      );
      expect(h.posts, isEmpty);
      await finish(t);
    },
  );
  testWidgets(
    'search text and list position survive a child route round trip',
    (t) async {
      final h = AdminPatientSearchHarness();
      h.patientRows = List.generate(
        20,
        (i) => searchedPatient(id: '${11 + i}', name: 'Patient ${i + 1}'),
      );
      await host(
        t,
        h,
        destinationBuilder:
            (_, route) => Scaffold(
              body: Builder(
                builder:
                    (context) => TextButton(
                      key: const Key('child_back'),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back'),
                    ),
              ),
            ),
      );
      await search(t, 'Patient');
      final scroll = find.byKey(const Key('admin_patient_search_scroll'));
      await t.drag(scroll, const Offset(0, -650));
      await t.pumpAndSettle();
      final view = t.widget<CustomScrollView>(scroll).controller!;
      final offset = view.offset;
      await t.tap(find.text('APPOINTMENT VIEW').hitTestable().first);
      await t.pumpAndSettle();
      await tap(t, 'child_back');
      expect(view.offset, closeTo(offset, .1));
      expect(
        t
            .widget<TextField>(
              find.byKey(
                const Key('admin_patient_search_query'),
                skipOffstage: false,
              ),
            )
            .controller!
            .text,
        'Patient',
      );
      await finish(t);
    },
  );
  testWidgets('failed search Retry repeats the same query and year', (t) async {
    final h = AdminPatientSearchHarness();
    await host(t, h);
    h.failPatients = true;
    await search(t, 'Sample');
    expect(
      find.byKey(const Key('admin_patient_search_error_dialog')),
      findsOneWidget,
    );
    h.failPatients = false;
    await tap(t, 'admin_patient_search_error_retry');
    expect(h.patientReads.last.queryParameters, {
      'p_year': '2026',
      'p_name': 'Sample',
    });
    await finish(t);
  });
  testWidgets(
    'background discards an old patient response and resume reloads current data',
    (t) async {
      final h = AdminPatientSearchHarness();
      h.pendingPatients = Completer<JsonMap>();
      await host(t, h, settle: false);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      final old = h.pendingPatients!;
      h.pendingPatients = null;
      old.complete({
        'pat_list': [searchedPatient(name: 'Late Patient')],
      });
      await t.pump();
      expect(find.text('Late Patient'), findsNothing);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(find.text('Sample Patient'), findsOneWidget);
      expect(find.text('Late Patient'), findsNothing);
      await finish(t);
    },
  );
  testWidgets(
    'logout closes History and prevents its late result appearing on Login',
    (t) async {
      final h = AdminPatientSearchHarness();
      await host(t, h, app: true);
      h.pendingHistory = Completer<JsonMap>();
      await tap(t, 'patient_search_prescription_11', settle: false);
      await h.auth.logout();
      await t.pumpAndSettle();
      h.pendingHistory!.complete({'items': h.historyRecords});
      await t.pumpAndSettle();
      expect(find.byType(AdminPatientSearchScreen), findsNothing);
      expect(
        find.byKey(const Key('patient_search_history_sheet')),
        findsNothing,
      );
      await finish(t);
    },
  );
  testWidgets('revoked access is checked before a new Admin patient search', (
    t,
  ) async {
    final h = AdminPatientSearchHarness();
    await host(t, h, app: true);
    h.adminData['usr_mob_app_access'] = '0';
    await search(t, 'Sample');
    expect(h.auth.stage, isNot(AuthStage.authenticated));
    expect(h.patientReads, hasLength(1));
    await finish(t);
  });
  for (final size in [
    const Size(280, 568),
    const Size(852, 393),
    const Size(768, 1024),
  ]) {
    testWidgets(
      'Admin search, phone card and year dialog support $size with large text',
      (t) async {
        final h = AdminPatientSearchHarness();
        await host(t, h, size: size, scale: 1.8);
        await tap(t, 'admin_patient_search_year');
        await t.ensureVisible(find.byKey(const Key('patient_search_year_ok')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await tap(t, 'patient_search_year_cancel');
        await finish(t);
      },
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/native_appointment_calendar.dart';
import 'package:docdiary_ios/features/appointments/unit_schedule/native_unit_appointment_layout.dart';
import 'package:docdiary_ios/features/appointments/all_schedule/all_appointment_screen.dart';
import 'package:docdiary_ios/features/appointments/all_schedule/native_all_appointment_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'all_appointment_test_support.dart';
import 'unit_appointment_test_support.dart';
import 'toast_test_support.dart';

Future<void> tap(WidgetTester t, String key, {bool settle = true}) async {
  final target = find.byKey(Key(key));
  if (target.evaluate().isEmpty && key.startsWith('doctor_history_choice_')) {
    await t.scrollUntilVisible(
      target,
      64,
      maxScrolls: 30,
      scrollable: find.descendant(
        of: find.byKey(const Key('doctor_history_choices')),
        matching: find.byType(Scrollable),
      ),
    );
  }
  if (target.hitTestable().evaluate().isEmpty) {
    await t.ensureVisible(target);
    await t.pumpAndSettle();
  }
  await t.tap(target);
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }
  expect(t.takeException(), isNull);
}

NativeAllAppointmentLayout layout(WidgetTester t) =>
    t.widget(find.byType(NativeAllAppointmentLayout));
Future<void> host(
  WidgetTester t,
  AllAppointmentHarness h, {
  bool app = false,
  bool settle = true,
  Size size = const Size(393, 852),
  double scale = 1,
  Future<bool> Function(Uri)? openPhone,
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
  final Widget root =
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
                      key: const Key('open_all_appointment'),
                      onPressed:
                          () => unawaited(
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder:
                                    (_) => AllAppointmentScreen(
                                      auth: h.auth,
                                      repository: h.allRepository,
                                      openPhone: openPhone,
                                    ),
                              ),
                            ),
                          ),
                      child: const Text('Open All Appointment'),
                    ),
              ),
            ),
          );
  await t.pumpWidget(
    RepaintBoundary(key: const Key('all_capture'), child: root),
  );
  await t.pumpAndSettle();
  await tap(
    t,
    app ? 'dashboard_allAppointment' : 'open_all_appointment',
    settle: settle,
  );
}

Future<void> finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> choose(WidgetTester t, String kind, int index) async {
  await tap(t, 'all_appointment_$kind');
  await tap(
    t,
    'doctor_history_choice_${kind == 'doctor' ? 'doctor' : 'unit'}_$index',
  );
}

Future<void> adminSelection(WidgetTester t) async {
  await choose(t, 'department', 0);
  await choose(t, 'unit', 0);
}

Future<void> day(WidgetTester t, DateTime date) async {
  layout(t).onDate(date);
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> capture(WidgetTester t, String name) async {
  final folder = Platform.environment['ALL_APPOINTMENT_RENDER_DIR'];
  if (folder == null) return;
  final shadows = debugDisableShadows;
  try {
    debugDisableShadows = false;
    void repaint(RenderObject object) {
      object.markNeedsPaint();
      object.visitChildren(repaint);
    }

    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('all_capture')),
    );
    repaint(boundary);
    await t.pump();
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$folder/$name.png');
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

void background(WidgetTester t) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    t.binding.handleAppLifecycleStateChanged(state);
  }
}

void resume(WidgetTester t) {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    t.binding.handleAppLifecycleStateChanged(state);
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
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
        }.entries) {
      final loader = FontLoader(entry.key);
      for (final font in entry.value) {
        loader.addFont(rootBundle.load('assets/fonts/$font'));
      }
      await loader.load();
    }
  });
  testWidgets(
    'Manager dashboard opens real All Appointment and preselects own permitted department and unit',
    (t) async {
      final h = AllAppointmentHarness();
      await host(t, h, app: true);
      expect(find.byType(AllAppointmentScreen), findsOneWidget);
      expect(layout(t).department!.id, '8');
      expect(layout(t).unit!.id, '2');
      expect(layout(t).rows, hasLength(3));
      expect(layout(t).doctorCount, 3);
      expect(h.departmentReads, hasLength(1));
      expect(h.unitReads, hasLength(1));
      expect(h.totalReads, hasLength(1));
      expect(h.scheduleReads, hasLength(1));
      expect(find.byTooltip('Call'), findsNothing);
      expect(h.posts, isEmpty);
      await capture(t, 'all_appointment_manager');
      await finish(t);
    },
  );
  testWidgets(
    'Admin starts with no department or unit and disabled downstream fields',
    (t) async {
      final h = AllAppointmentHarness(admin: true);
      await host(t, h);
      expect(layout(t).department, isNull);
      expect(layout(t).unit, isNull);
      expect(
        find.text('Select Unit to View Doctor/Therapist Schedule'),
        findsOneWidget,
      );
      expect(h.departmentReads, hasLength(1));
      expect(h.unitReads, isEmpty);
      expect(h.totalReads, isEmpty);
      expect(h.scheduleReads, isEmpty);
      final fields =
          t
              .widgetList<NativeScheduleSelectionField>(
                find.byType(NativeScheduleSelectionField),
              )
              .toList();
      expect(fields.map((f) => f.enabled), [true, false, false]);
      await capture(t, 'all_appointment_admin_initial');
      await finish(t);
    },
  );
  testWidgets(
    'department and unit popups are readonly and retain the accepted selection style',
    (t) async {
      final h = AllAppointmentHarness(admin: true);
      await host(t, h);
      await tap(t, 'all_appointment_department');
      expect(find.byType(EditableText), findsNothing);
      expect(t.testTextInput.isVisible, isFalse);
      await capture(t, 'all_appointment_departments');
      await tap(t, 'doctor_history_choice_unit_0');
      expect(layout(t).department!.id, '8');
      expect(layout(t).unit, isNull);
      expect(h.totalReads, hasLength(1));
      expect(h.scheduleReads, isEmpty);
      await choose(t, 'unit', 0);
      expect(layout(t).rows, hasLength(3));
      expect(h.totalReads, hasLength(1));
      await capture(t, 'all_appointment_admin_selected');
      await finish(t);
    },
  );
  testWidgets(
    'doctor filtering and clear keep all-unit and separate department totals without GET',
    (t) async {
      final h = AllAppointmentHarness();
      await host(t, h);
      final requests = h.transport.requests.length;
      await choose(t, 'doctor', 2);
      expect(layout(t).rows.single.id, '20');
      expect(layout(t).doctorCount, 3);
      await tap(t, 'all_appointment_department_totals');
      expect(
        find.text('Total Appointment:   9\nTotal Blank Schedule:   3'),
        findsOneWidget,
      );
      await capture(t, 'all_appointment_department_totals');
      await tap(t, 'all_appointment_totals_close');
      await tap(t, 'all_appointment_totals');
      expect(
        find.text('Total Appointment:   4\nTotal Blank Schedule:   2'),
        findsOneWidget,
      );
      await capture(t, 'all_appointment_unit_totals');
      await tap(t, 'all_appointment_totals_close');
      await choose(t, 'doctor', 0);
      expect(layout(t).rows, hasLength(3));
      expect(h.transport.requests.length, requests);
      await finish(t);
    },
  );
  testWidgets(
    'department change clears unit, doctor and private rows and loads only new units and totals',
    (t) async {
      final h = AllAppointmentHarness();
      await host(t, h);
      await choose(t, 'doctor', 2);
      await choose(t, 'department', 1);
      expect(layout(t).department!.id, '99');
      expect(layout(t).unit, isNull);
      expect(layout(t).doctor, isNull);
      expect(layout(t).rows, isEmpty);
      expect(h.scheduleReads, hasLength(1));
      expect(h.unitReads.last.queryParameters, {'deptd_id': '99'});
      expect(h.totalReads.last.queryParameters['deptd_id'], '99');
      await choose(t, 'unit', 0);
      expect(h.scheduleReads.last.queryParameters, {
        'pdate': '24-OCT-26',
        'depts_id': '9',
        'deptd_id': '99',
      });
      expect(layout(t).rows.single.id, '90');
      await finish(t);
    },
  );
  testWidgets(
    'unit change clears only doctor filter and reuses current department totals',
    (t) async {
      final h = AllAppointmentHarness();
      await host(t, h);
      await choose(t, 'doctor', 2);
      await choose(t, 'unit', 1);
      expect(layout(t).doctor, isNull);
      expect(layout(t).rows.single.id, '40');
      expect(h.departmentReads, hasLength(1));
      expect(h.unitReads, hasLength(1));
      expect(h.totalReads, hasLength(1));
      expect(h.scheduleReads, hasLength(2));
      await finish(t);
    },
  );
  testWidgets(
    'date change reloads department totals then selected unit schedule and resets doctor filter',
    (t) async {
      final h = AllAppointmentHarness();
      await host(t, h);
      await choose(t, 'doctor', 2);
      await tap(t, 'doctor_appointment_date_25-OCT-26');
      expect(layout(t).selected, DateTime(2026, 10, 25));
      expect(layout(t).doctor, isNull);
      expect(h.totalReads, hasLength(2));
      expect(h.scheduleReads, hasLength(2));
      expect(h.unitReads, hasLength(1));
      final endpoints =
          h.transport.requests.map((r) => r.uri.pathSegments.last).toList();
      expect(endpoints.sublist(endpoints.length - 2), [
        'getDeptdSchCount',
        'getDocWithSchedule',
      ]);
      await tap(t, 'all_appointment_department_totals');
      expect(
        find.text('Total Appointment:   6\nTotal Blank Schedule:   6'),
        findsOneWidget,
      );
      await tap(t, 'all_appointment_totals_close');
      await finish(t);
    },
  );
  testWidgets(
    'calendar without department sends no schedule reads and requests Department selection',
    (t) async {
      final toast = ToastRecorder()..install();
      addTearDown(toast.uninstall);
      final h = AllAppointmentHarness(admin: true);
      await host(t, h);
      await day(t, DateTime(2026, 10, 25));
      expect(toast.messages, contains('Please Select Department'));
      expect(h.unitReads, isEmpty);
      expect(h.totalReads, isEmpty);
      expect(h.scheduleReads, isEmpty);
      await finish(t);
    },
  );
  testWidgets(
    'calendar with department but no unit refreshes only totals and requests Unit selection',
    (t) async {
      final toast = ToastRecorder()..install();
      addTearDown(toast.uninstall);
      final h = AllAppointmentHarness(admin: true);
      await host(t, h);
      await choose(t, 'department', 0);
      await day(t, DateTime(2026, 10, 25));
      expect(toast.messages, contains('Please Select Unit'));
      expect(h.totalReads, hasLength(2));
      expect(h.unitReads, hasLength(1));
      expect(h.scheduleReads, isEmpty);
      await finish(t);
    },
  );
  testWidgets(
    'duplicate department/unit names and doctor IDs 1 and 10 preserve exact selected identity',
    (t) async {
      final h = AllAppointmentHarness();
      h.departmentRows = [
        {'deptd_id': '8', 'deptd_name': 'Same Department'},
        {'deptd_id': '99', 'deptd_name': 'Same Department'},
      ];
      h.unitRows = [
        {'depts_id': '2', 'depts_name': 'Same Unit'},
        {'depts_id': '3', 'depts_name': 'Same Unit'},
      ];
      h.doctorsByUnit['2'] = [
        unitDoctor(id: '1', name: 'Same Doctor', code: 'CODE'),
        unitDoctor(id: '10', name: 'Same Doctor', code: 'CODE'),
      ];
      await host(t, h);
      await tap(t, 'all_appointment_department');
      expect(find.text('ID: 8'), findsOneWidget);
      await tap(t, 'doctor_history_choice_unit_0');
      await choose(t, 'unit', 0);
      await choose(t, 'doctor', 1);
      expect(layout(t).rows.single.id, '1');
      expect(h.scheduleReads.last.queryParameters['depts_id'], '2');
      await finish(t);
    },
  );
  testWidgets(
    'missing profile department or unit never sends a foreign initial schedule request',
    (t) async {
      final h = AllAppointmentHarness();
      h.doctorData['depts_id'] = '7';
      await host(t, h);
      expect(layout(t).department!.id, '8');
      expect(layout(t).unit, isNull);
      expect(h.scheduleReads, isEmpty);
      await choose(t, 'unit', 0);
      expect(h.scheduleReads.single.queryParameters['depts_id'], '2');
      await finish(t);
    },
  );
  testWidgets(
    'empty units retain valid department totals, zero doctors and native select-unit message',
    (t) async {
      final h = AllAppointmentHarness();
      h.unitRows = [];
      await host(t, h);
      expect(layout(t).unit, isNull);
      expect(h.scheduleReads, isEmpty);
      expect(
        find.text('Select Unit to View Doctor/Therapist Schedule'),
        findsOneWidget,
      );
      await tap(t, 'all_appointment_department_totals');
      expect(
        find.text('Total Appointment:   9\nTotal Blank Schedule:   3'),
        findsOneWidget,
      );
      await tap(t, 'all_appointment_totals_close');
      await finish(t);
    },
  );
  testWidgets(
    'empty doctors and empty schedules keep native messages and unit totals',
    (t) async {
      final h = AllAppointmentHarness();
      h.doctorsByUnit['2'] = [];
      await host(t, h);
      expect(find.text('No Doctor/Therapist Found'), findsOneWidget);
      await capture(t, 'all_appointment_no_doctors');
      await tap(t, 'all_appointment_totals');
      expect(
        find.text('Total Appointment:   0\nTotal Blank Schedule:   0'),
        findsOneWidget,
      );
      await tap(t, 'all_appointment_totals_close');
      h.doctorsByUnit['2'] = [
        unitDoctor(slots: [], appointments: '0', total: '0', busy: '0'),
      ];
      await day(t, DateTime(2026, 10, 25));
      expect(find.text('No Schedule Found'), findsOneWidget);
      await finish(t);
    },
  );
  for (final stage in ['departments', 'units', 'totals', 'doctors']) {
    testWidgets(
      'Retry resumes failed $stage stage and does not repeat successful earlier GETs',
      (t) async {
        final h = AllAppointmentHarness();
        h.failDepartments = stage == 'departments';
        h.failUnits = stage == 'units';
        h.failTotals = stage == 'totals';
        h.failDoctors = stage == 'doctors';
        await host(t, h);
        expect(
          find.byKey(const Key('all_appointment_error_dialog')),
          findsOneWidget,
        );
        expect(layout(t).rows, isEmpty);
        await capture(t, 'all_appointment_retry_$stage');
        h.failDepartments = h.failUnits = h.failTotals = h.failDoctors = false;
        await tap(t, 'all_appointment_error_retry');
        expect(layout(t).rows, hasLength(3));
        expect(h.departmentReads, hasLength(stage == 'departments' ? 2 : 1));
        expect(h.unitReads, hasLength(stage == 'units' ? 2 : 1));
        expect(h.totalReads, hasLength(stage == 'totals' ? 2 : 1));
        expect(h.scheduleReads, hasLength(stage == 'doctors' ? 2 : 1));
        expect(h.posts, isEmpty);
        await finish(t);
      },
    );
  }
  testWidgets(
    'EXIT after error closes All Appointment without changing any patient data',
    (t) async {
      final h = AllAppointmentHarness()..failTotals = true;
      await host(t, h);
      await tap(t, 'all_appointment_error_exit');
      expect(find.byType(AllAppointmentScreen), findsNothing);
      expect(h.posts, isEmpty);
      await finish(t);
    },
  );
  testWidgets(
    'loading blocks back, calendar, month navigation and dropdown callbacks',
    (t) async {
      final h = AllAppointmentHarness()..pendingDoctors = Completer<JsonMap>();
      await host(t, h, settle: false);
      expect(find.byKey(const Key('all_appointment_loading')), findsOneWidget);
      expect(
        t
            .widget<IconButton>(find.byKey(const Key('all_appointment_back')))
            .onPressed,
        isNull,
      );
      expect(
        t
            .widget<NativeAppointmentCalendar>(
              find.byType(NativeAppointmentCalendar),
            )
            .enabled,
        isFalse,
      );
      layout(t).onMonth(1);
      await t.pump();
      expect(h.scheduleReads, hasLength(1));
      h.pendingDoctors!.complete({'count': 0});
      await t.pumpAndSettle();
      await finish(t);
    },
  );
  testWidgets(
    'calendar drag commits one date and month buttons obey native year rollover bounds',
    (t) async {
      final h = AllAppointmentHarness(clock: DateTime(2026, 1, 31, 13, 30));
      await host(t, h);
      await tap(t, 'all_appointment_next');
      expect(layout(t).selected, DateTime(2026, 2, 28));
      final reads = h.scheduleReads.length;
      await tap(t, 'all_appointment_next');
      expect(h.scheduleReads, hasLength(reads));
      await tap(t, 'all_appointment_previous');
      await tap(t, 'all_appointment_previous');
      expect(layout(t).selected, DateTime(2025, 12, 31));
      final before = h.scheduleReads.length;
      await t.drag(
        find.byKey(const Key('doctor_appointment_calendar')),
        const Offset(-160, 0),
      );
      await t.pumpAndSettle();
      expect(h.scheduleReads, hasLength(before + 1));
      await finish(t);
    },
  );
  testWidgets(
    'each doctor retains native horizontal initial focus and slot colors',
    (t) async {
      final h = AllAppointmentHarness();
      await host(t, h);
      final strip = find.byKey(const Key('unit_doctor_slots_10_0'));
      expect(t.widget<ListView>(strip).controller!.offset, greaterThan(0));
      expect(
        t.widget<Material>(find.byKey(const Key('unit_slot_10_0_3'))).color,
        const Color(0xfff5f5f5),
      );
      t.widget<ListView>(strip).controller!.jumpTo(0);
      await t.pumpAndSettle();
      expect(
        t.widget<Material>(find.byKey(const Key('unit_slot_10_0_0'))).color,
        const Color(0xff57d2d0),
      );
      expect(find.text('No Meeting happened'), findsWidgets);
      await finish(t);
    },
  );
  testWidgets(
    'full-access Admin sees Call for booked past/upcoming slots and never blank/blocked slots',
    (t) async {
      final h = AllAppointmentHarness(admin: true);
      await host(t, h);
      await adminSelection(t);
      expect(
        find.byKey(const Key('unit_slot_call_10_0_3')).hitTestable(),
        findsOneWidget,
      );
      await capture(t, 'all_appointment_admin_call_icons');
      final strip = find.byKey(const Key('unit_doctor_slots_10_0'));
      t.widget<ListView>(strip).controller!.jumpTo(0);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('unit_slot_call_10_0_0')), findsOneWidget);
      expect(find.byKey(const Key('unit_slot_call_10_0_1')), findsNothing);
      await t.drag(strip, const Offset(-220, 0));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('unit_slot_call_10_0_2')), findsNothing);
      await finish(t);
    },
  );
  testWidgets(
    'restricted Admin and missing mobile numbers hide Call controls',
    (t) async {
      final h = AllAppointmentHarness(admin: true, canCall: false);
      await host(t, h);
      await adminSelection(t);
      expect(find.byTooltip('Call'), findsNothing);
      h.adminData['all_access_flag'] = '1';
      for (final rows in h.doctorsByUnit.values) {
        for (final row in rows) {
          row['app_list'] = [
            for (final slot in nativeArray(row['app_list']))
              {...slot, 'pat_cell': ''},
          ];
        }
      }
      background(t);
      await t.pump();
      resume(t);
      await t.pumpAndSettle();
      await adminSelection(t);
      expect(find.byTooltip('Call'), findsNothing);
      await finish(t);
    },
  );
  testWidgets(
    'Call asks native YES/NO confirmation and NO never opens dialer',
    (t) async {
      final h = AllAppointmentHarness(admin: true);
      final opened = <Uri>[];
      await host(
        t,
        h,
        openPhone: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await adminSelection(t);
      await tap(t, 'unit_slot_call_10_0_3');
      expect(
        find.text('Do you want to make a call to Next Patient ?'),
        findsOneWidget,
      );
      await capture(t, 'all_appointment_call_dialog');
      await tap(t, 'all_appointment_call_no');
      expect(opened, isEmpty);
      expect(h.scheduleReads, hasLength(1));
      await finish(t);
    },
  );
  testWidgets(
    'Call YES rechecks current profile and opens one tel URI despite repeated confirmation callback',
    (t) async {
      final h = AllAppointmentHarness(admin: true);
      final opened = <Uri>[];
      await host(
        t,
        h,
        openPhone: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await adminSelection(t);
      await tap(t, 'unit_slot_call_10_0_3');
      final button = t.widget<TextButton>(
        find.byKey(const Key('all_appointment_call_yes')),
      );
      button.onPressed!();
      button.onPressed!();
      await t.pumpAndSettle();
      expect(opened.map((uri) => uri.toString()), ['tel:01700000000']);
      expect(h.posts, isEmpty);
      await finish(t);
    },
  );
  testWidgets(
    'calling permission revoked while confirmation is open prevents dialing and refreshes scope',
    (t) async {
      final h = AllAppointmentHarness(admin: true);
      final opened = <Uri>[];
      await host(
        t,
        h,
        openPhone: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await adminSelection(t);
      await tap(t, 'unit_slot_call_10_0_3');
      h.adminData['all_access_flag'] = '0';
      await tap(t, 'all_appointment_call_yes');
      expect(opened, isEmpty);
      expect(find.byTooltip('Call'), findsNothing);
      expect(layout(t).department, isNull);
      expect(h.auth.stage, AuthStage.authenticated);
      await finish(t);
    },
  );
  testWidgets(
    'losing Admin Appointment access during Call closes feature after one message without dialing',
    (t) async {
      final h = AllAppointmentHarness(admin: true);
      final opened = <Uri>[];
      await host(
        t,
        h,
        openPhone: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await adminSelection(t);
      await tap(t, 'unit_slot_call_10_0_3');
      h.adminData.addAll({
        'all_access_flag': '2',
        'hr_appointment_active': '0',
      });
      await tap(t, 'all_appointment_call_yes');
      expect(find.text('Not available'), findsOneWidget);
      await tap(t, 'dashboard_message_ok');
      expect(find.byType(AllAppointmentScreen), findsNothing);
      expect(find.text('Not available'), findsNothing);
      expect(opened, isEmpty);
      expect(h.auth.stage, AuthStage.authenticated);
      await finish(t);
    },
  );
  testWidgets(
    'failed dialer launch uses existing error dialog without retrying schedule or writing API',
    (t) async {
      final h = AllAppointmentHarness(admin: true);
      await host(t, h, openPhone: (_) async => false);
      await adminSelection(t);
      await tap(t, 'unit_slot_call_10_0_3');
      await tap(t, 'all_appointment_call_yes');
      expect(
        find.textContaining('Could not open the phone dialer.'),
        findsOneWidget,
      );
      await capture(t, 'all_appointment_dialer_error');
      await tap(t, 'dashboard_message_ok');
      expect(h.scheduleReads, hasLength(1));
      expect(h.posts, isEmpty);
      await finish(t);
    },
  );
  testWidgets(
    'background during Call preflight discards late profile and resume restores enabled controls',
    (t) async {
      final h = AllAppointmentHarness(admin: true);
      final opened = <Uri>[];
      await host(
        t,
        h,
        openPhone: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await adminSelection(t);
      final pending = Completer<JsonMap>();
      h.pendingProfile = pending;
      await tap(t, 'unit_slot_call_10_0_3', settle: false);
      background(t);
      await t.pump();
      h.pendingProfile = null;
      pending.complete({
        'count': 1,
        'items': [h.adminData],
      });
      await t.pump();
      resume(t);
      await t.pumpAndSettle();
      expect(opened, isEmpty);
      expect(layout(t).enabled, isTrue);
      expect(
        find.byKey(const Key('all_appointment_call_dialog')),
        findsNothing,
      );
      await finish(t);
    },
  );
  testWidgets(
    'logout closes Call confirmation and clears private data before a stale YES can dial',
    (t) async {
      final h = AllAppointmentHarness(admin: true);
      final opened = <Uri>[];
      await host(
        t,
        h,
        openPhone: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await adminSelection(t);
      await tap(t, 'unit_slot_call_10_0_3');
      final yes =
          t
              .widget<TextButton>(
                find.byKey(const Key('all_appointment_call_yes')),
              )
              .onPressed!;
      await h.auth.logout();
      await t.pump();
      yes();
      await t.pump(const Duration(milliseconds: 500));
      expect(opened, isEmpty);
      expect(
        find.byKey(const Key('all_appointment_call_dialog')),
        findsNothing,
      );
      expect(layout(t).rows, isEmpty);
      await finish(t);
    },
  );
  testWidgets(
    'Manager permission loss blocks next schedule read and exits feature without logout',
    (t) async {
      final h = AllAppointmentHarness();
      await host(t, h);
      h.doctorData['doc_manager_flag'] = '0';
      await day(t, DateTime(2026, 10, 25));
      expect(h.scheduleReads, hasLength(1));
      expect(find.text('Not available'), findsOneWidget);
      expect(h.auth.stage, AuthStage.authenticated);
      await tap(t, 'dashboard_message_ok');
      expect(find.byType(AllAppointmentScreen), findsNothing);
      await finish(t);
    },
  );
  testWidgets(
    'fresh account denial reaches Login without another All data GET',
    (t) async {
      final h = AllAppointmentHarness();
      await host(t, h, app: true);
      h.doctorData['access_flag'] = '0';
      await day(t, DateTime(2026, 10, 25));
      expect(h.auth.stage, isNot(AuthStage.authenticated));
      expect(find.byType(AllAppointmentScreen), findsNothing);
      expect(h.scheduleReads, hasLength(1));
      await finish(t);
    },
  );
  testWidgets(
    'ordinary doctor direct route cannot issue All Appointment data requests',
    (t) async {
      final h = AllAppointmentHarness();
      h.doctorData['doc_manager_flag'] = '0';
      await host(t, h);
      expect(h.departmentReads, isEmpty);
      expect(h.scheduleReads, isEmpty);
      expect(find.text('Not available'), findsOneWidget);
      await finish(t);
    },
  );
  testWidgets(
    'changed profile department reloads catalogues and selects only its valid own unit',
    (t) async {
      final h = AllAppointmentHarness();
      await host(t, h);
      h.doctorData.addAll({'deptd_id': '99', 'depts_id': '9'});
      await day(t, DateTime(2026, 10, 25));
      expect(h.departmentReads, hasLength(2));
      expect(layout(t).department!.id, '99');
      expect(h.scheduleReads.last.queryParameters, {
        'pdate': '25-OCT-26',
        'depts_id': '9',
        'deptd_id': '99',
      });
      await finish(t);
    },
  );
  testWidgets(
    'background discards late nested schedule data and resumes current department scope',
    (t) async {
      final h = AllAppointmentHarness()..pendingDoctors = Completer<JsonMap>();
      await host(t, h, settle: false);
      background(t);
      await t.pump();
      final pending = h.pendingDoctors!;
      h.pendingDoctors = null;
      pending.complete({
        'count': 1,
        'items': [unitDoctor(name: 'Late Private Doctor')],
      });
      await t.pump();
      expect(find.textContaining('Late Private Doctor'), findsNothing);
      resume(t);
      await t.pumpAndSettle();
      expect(layout(t).rows.first.name, 'Sample Therapist A');
      expect(h.departmentReads, hasLength(2));
      await finish(t);
    },
  );
  for (final size in [
    const Size(280, 568),
    const Size(852, 393),
    const Size(768, 1024),
  ]) {
    testWidgets(
      'All filters and doctor schedules support $size at large font scale',
      (t) async {
        final h = AllAppointmentHarness();
        await host(t, h, size: size, scale: 1.8);
        await choose(t, 'doctor', 3);
        expect(layout(t).rows.single.id, '30');
        final target = find.byKey(const Key('unit_doctor_no_schedule_30_0'));
        final scrolling =
            find
                .descendant(
                  of: find.byKey(const Key('all_appointment_scroll')),
                  matching: find.byType(Scrollable),
                )
                .first;
        await t.scrollUntilVisible(
          target,
          180,
          scrollable: scrolling,
          maxScrolls: 30,
        );
        await Scrollable.ensureVisible(t.element(target), alignment: .9);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        if (size.width == 280) {
          await capture(t, 'all_appointment_small_large_text');
        }
        if (size.width > size.height) {
          await capture(t, 'all_appointment_landscape_large_text');
        }
        await finish(t);
      },
    );
  }
}

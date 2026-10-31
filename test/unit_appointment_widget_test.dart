import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/native_appointment_calendar.dart';
import 'package:docdiary_ios/features/appointments/unit_schedule/unit_appointment_screen.dart';
import 'package:docdiary_ios/features/appointments/unit_schedule/native_unit_appointment_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'unit_appointment_test_support.dart';
import 'support.dart';
import 'toast_test_support.dart';

Future<void> tap(WidgetTester t, String key, {bool settle = true}) async {
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty && key.startsWith('doctor_history_choice_')) {
    await t.scrollUntilVisible(
      finder,
      64,
      scrollable: find.descendant(
        of: find.byKey(const Key('doctor_history_choices')),
        matching: find.byType(Scrollable),
      ),
      maxScrolls: 30,
    );
    await t.pumpAndSettle();
  }
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

Future<void> host(
  WidgetTester t,
  UnitAppointmentHarness h, {
  bool app = false,
  bool settle = true,
  Size size = const Size(393, 852),
  double scale = 1,
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
                      key: const Key('open_unit_appointment'),
                      onPressed:
                          () => unawaited(
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder:
                                    (_) => UnitAppointmentScreen(
                                      auth: h.auth,
                                      repository: h.unitRepository,
                                    ),
                              ),
                            ),
                          ),
                      child: const Text('Open Unit Appointment'),
                    ),
              ),
            ),
          );
  await t.pumpWidget(
    RepaintBoundary(key: const Key('unit_capture'), child: root),
  );
  await t.pumpAndSettle();
  await tap(
    t,
    app ? 'dashboard_unitAppointment' : 'open_unit_appointment',
    settle: settle,
  );
}

NativeUnitAppointmentLayout layout(WidgetTester t) =>
    t.widget(find.byType(NativeUnitAppointmentLayout));
Future<void> finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> capture(WidgetTester t, String name) async {
  final output = Platform.environment['UNIT_APPOINTMENT_RENDER_DIR'];
  if (output == null) return;
  final shadows = debugDisableShadows;
  try {
    debugDisableShadows = false;
    void repaint(RenderObject object) {
      object.markNeedsPaint();
      object.visitChildren(repaint);
    }

    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('unit_capture')),
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

Future<void> doctor(WidgetTester t, int choice) async {
  await tap(t, 'unit_appointment_doctor');
  await tap(t, 'doctor_history_choice_doctor_$choice');
}

Future<void> day(WidgetTester t, DateTime value) async {
  layout(t).onDate(value);
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> scrollTo(WidgetTester t, Finder target) async {
  final scrolling =
      find
          .descendant(
            of: find.byKey(const Key('unit_appointment_scroll')),
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
    'Unit Head dashboard opens real native Unit Appointment and its own unit',
    (t) async {
      final h = UnitAppointmentHarness();
      await host(t, h, app: true);
      expect(find.byType(UnitAppointmentScreen), findsOneWidget);
      expect(layout(t).unit!.id, '2');
      expect(layout(t).doctorCount, 3);
      expect(layout(t).rows.map((r) => r.id), ['10', '20', '30']);
      expect(h.unitReads.single.queryParameters, {'deptd_id': '8'});
      expect(h.scheduleReads.single.queryParameters, {
        'pdate': '24-OCT-26',
        'depts_id': '2',
        'deptd_id': '8',
      });
      expect(h.posts, isEmpty);
      await capture(t, 'unit_appointment_overview');
      await finish(t);
    },
  );
  testWidgets(
    'prefilled unit consistently uses Unit label and keeps the enlarged label fonts',
    (t) async {
      final h = UnitAppointmentHarness();
      await host(t, h);
      InputDecorator field() => t.widget(
        find.descendant(
          of: find.byKey(const Key('unit_appointment_unit')),
          matching: find.byType(InputDecorator),
        ),
      );
      expect(field().decoration.labelText, 'Unit');
      expect(
        field().decoration.floatingLabelStyle!.fontSize,
        greaterThan(field().decoration.labelStyle!.fontSize!),
      );
      final size = field().decoration.labelStyle!.fontSize;
      await tap(t, 'unit_appointment_unit');
      await tap(t, 'doctor_history_choice_unit_1');
      expect(field().decoration.labelText, 'Unit');
      expect(field().decoration.labelStyle!.fontSize, size);
      await finish(t);
    },
  );
  testWidgets(
    'a unit that has not been selected retains the Select Unit prompt',
    (t) async {
      final h = UnitAppointmentHarness()..unitRows = [];
      await host(t, h);
      final field = t.widget<InputDecorator>(
        find.descendant(
          of: find.byKey(const Key('unit_appointment_unit')),
          matching: find.byType(InputDecorator),
        ),
      );
      expect(field.decoration.labelText, 'Select Unit');
      await finish(t);
    },
  );
  testWidgets(
    'readonly unit and doctor popups use existing native choices without opening keyboard',
    (t) async {
      final h = UnitAppointmentHarness();
      await host(t, h);
      await tap(t, 'unit_appointment_unit');
      expect(find.byType(EditableText), findsNothing);
      expect(t.testTextInput.isVisible, isFalse);
      await capture(t, 'unit_appointment_unit_choices');
      await tap(t, 'doctor_history_choice_unit_0');
      await tap(t, 'unit_appointment_doctor');
      expect(find.text('...'), findsWidgets);
      expect(find.byType(EditableText), findsNothing);
      await capture(t, 'unit_appointment_doctor_choices');
      await tap(t, 'doctor_history_choice_doctor_0');
      await finish(t);
    },
  );
  testWidgets(
    'doctor filter and clear are local and keep unit totals and doctor counter',
    (t) async {
      final h = UnitAppointmentHarness();
      await host(t, h);
      final requests = h.transport.requests.length;
      await doctor(t, 2);
      expect(layout(t).rows.single.id, '20');
      expect(layout(t).doctorCount, 3);
      expect(h.transport.requests.length, requests);
      await capture(t, 'unit_appointment_filtered');
      await tap(t, 'unit_appointment_totals');
      expect(
        find.text('Total Appointment:   4\nTotal Blank Schedule:   2'),
        findsOneWidget,
      );
      await capture(t, 'unit_appointment_totals');
      await tap(t, 'unit_appointment_totals_close');
      await doctor(t, 0);
      expect(layout(t).doctor, isNull);
      expect(layout(t).rows, hasLength(3));
      expect(h.transport.requests.length, requests);
      await finish(t);
    },
  );
  testWidgets(
    'selecting a different unit clears doctor filter and loads only that unit',
    (t) async {
      final h = UnitAppointmentHarness();
      await host(t, h);
      await doctor(t, 2);
      await tap(t, 'unit_appointment_unit');
      await tap(t, 'doctor_history_choice_unit_1');
      expect(layout(t).unit!.id, '3');
      expect(layout(t).doctor, isNull);
      expect(layout(t).rows.single.id, '40');
      expect(h.unitReads, hasLength(1));
      expect(h.scheduleReads.last.queryParameters['depts_id'], '3');
      await finish(t);
    },
  );
  testWidgets(
    'duplicate unit names select exact row ID and never the last matching name',
    (t) async {
      final h = UnitAppointmentHarness();
      h.unitRows = [
        {'depts_id': '2', 'depts_name': 'Same Unit'},
        {'depts_id': '3', 'depts_name': 'Same Unit'},
      ];
      await host(t, h);
      await tap(t, 'unit_appointment_unit');
      expect(find.text('ID: 2'), findsOneWidget);
      await tap(t, 'doctor_history_choice_unit_0');
      expect(h.scheduleReads.last.queryParameters['depts_id'], '2');
      await finish(t);
    },
  );
  testWidgets(
    'doctor IDs 1 and 10 with duplicate labels filter by exact selected identity',
    (t) async {
      final h = UnitAppointmentHarness();
      h.doctorsByUnit['2'] = [
        unitDoctor(id: '1', name: 'Same Name', code: 'CODE'),
        unitDoctor(id: '10', name: 'Same Name', code: 'CODE'),
      ];
      await host(t, h);
      await doctor(t, 1);
      expect(layout(t).rows.single.id, '1');
      await finish(t);
    },
  );
  testWidgets(
    'date changes clear doctor filter and reuse loaded unit catalogue',
    (t) async {
      final h = UnitAppointmentHarness();
      await host(t, h);
      await doctor(t, 2);
      await tap(t, 'doctor_appointment_date_25-OCT-26');
      expect(layout(t).selected, DateTime(2026, 10, 25));
      expect(layout(t).doctor, isNull);
      expect(layout(t).rows, hasLength(3));
      expect(h.unitReads, hasLength(1));
      expect(h.scheduleReads, hasLength(2));
      expect(h.scheduleReads.last.queryParameters['pdate'], '25-OCT-26');
      await finish(t);
    },
  );
  testWidgets(
    'horizontal calendar drag settles one date and makes one schedule request',
    (t) async {
      final h = UnitAppointmentHarness();
      await host(t, h);
      await t.drag(
        find.byKey(const Key('doctor_appointment_calendar')),
        const Offset(-160, 0),
      );
      await t.pumpAndSettle();
      expect(layout(t).selected, isNot(DateTime(2026, 10, 24)));
      expect(h.scheduleReads, hasLength(2));
      await finish(t);
    },
  );
  testWidgets('month buttons respect native end dates across year rollover', (
    t,
  ) async {
    final h = UnitAppointmentHarness(clock: DateTime(2026, 1, 31, 13, 30));
    await host(t, h);
    await tap(t, 'unit_appointment_next');
    expect(layout(t).selected, DateTime(2026, 2, 28));
    final count = h.scheduleReads.length;
    await tap(t, 'unit_appointment_next');
    expect(h.scheduleReads, hasLength(count));
    await tap(t, 'unit_appointment_previous');
    await tap(t, 'unit_appointment_previous');
    expect(layout(t).selected, DateTime(2025, 12, 31));
    await finish(t);
  });
  testWidgets(
    'each horizontal schedule initially focuses first upcoming booked slot',
    (t) async {
      final h = UnitAppointmentHarness();
      await host(t, h);
      final strip = find.byKey(const Key('unit_doctor_slots_10_0'));
      expect(t.widget<ListView>(strip).controller!.offset, greaterThan(0));
      expect(
        find.byKey(const Key('unit_slot_10_0_3')).hitTestable(),
        findsOneWidget,
      );
      expect(layout(t).rows.first.initialScheduleIndex(h.now), 3);
      await finish(t);
    },
  );
  testWidgets(
    'elapsed slot colors refresh on a local rebuild without moving horizontal position',
    (t) async {
      final h = UnitAppointmentHarness();
      await host(t, h);
      final strip = find.byKey(const Key('unit_doctor_slots_10_0'));
      final controller = t.widget<ListView>(strip).controller!;
      final offset = controller.offset;
      final requests = h.transport.requests.length;
      expect(
        t.widget<Material>(find.byKey(const Key('unit_slot_10_0_3'))).color,
        const Color(0xfff5f5f5),
      );
      h.now = DateTime(2026, 10, 24, 14, 1);
      await tap(t, 'unit_appointment_totals');
      await tap(t, 'unit_appointment_totals_close');
      expect(
        t.widget<Material>(find.byKey(const Key('unit_slot_10_0_3'))).color,
        const Color(0xff57d2d0),
      );
      expect(controller.offset, offset);
      expect(h.transport.requests.length, requests);
      await finish(t);
    },
  );
  testWidgets(
    'native completed, blank and blocked slot cards have expected messages and colors',
    (t) async {
      final h = UnitAppointmentHarness();
      await host(t, h);
      final strip = find.byKey(const Key('unit_doctor_slots_10_0'));
      t.widget<ListView>(strip).controller!.jumpTo(0);
      await t.pumpAndSettle();
      expect(
        t.widget<Material>(find.byKey(const Key('unit_slot_10_0_0'))).color,
        const Color(0xff57d2d0),
      );
      expect(
        t.widget<Material>(find.byKey(const Key('unit_slot_10_0_1'))).color,
        const Color(0xffced6e0),
      );
      expect(find.text('No Meeting happened'), findsWidgets);
      await capture(t, 'unit_appointment_slot_states');
      await t.drag(strip, const Offset(-230, 0));
      await t.pumpAndSettle();
      expect(find.text('Blocked Time'), findsWidgets);
      expect(h.posts, isEmpty);
      expect(find.byTooltip('Call'), findsNothing);
      await finish(t);
    },
  );
  testWidgets(
    'native schedule widths wrap their content and horizontal lists scroll independently',
    (t) async {
      final h = UnitAppointmentHarness();
      h.doctorsByUnit['2'] = [
        unitDoctor(
          slots: [
            unitSlot(patient: '', time: '02:00 PM'),
            unitSlot(
              service: 'A much longer native service name for horizontal width',
            ),
          ],
        ),
      ];
      await host(t, h);
      final a = t.getSize(find.byKey(const Key('unit_slot_10_0_0'))).width;
      final b = t.getSize(find.byKey(const Key('unit_slot_10_0_1'))).width;
      expect(b, greaterThan(a));
      await finish(t);
    },
  );
  testWidgets(
    'empty doctor response shows native message, zero count and zero totals',
    (t) async {
      final h = UnitAppointmentHarness();
      h.doctorsByUnit['2'] = [];
      await host(t, h);
      expect(find.text('No Doctor/Therapist Found'), findsOneWidget);
      expect(find.text('  0'), findsOneWidget);
      await capture(t, 'unit_appointment_no_doctors');
      await tap(t, 'unit_appointment_totals');
      expect(
        find.text('Total Appointment:   0\nTotal Blank Schedule:   0'),
        findsOneWidget,
      );
      await tap(t, 'unit_appointment_totals_close');
      await finish(t);
    },
  );
  testWidgets(
    'doctor with empty schedule keeps header and native No Schedule Found',
    (t) async {
      final h = UnitAppointmentHarness();
      h.doctorsByUnit['2'] = [
        unitDoctor(appointments: '0', total: '0', busy: '0', slots: []),
      ];
      await host(t, h);
      expect(find.text('No Schedule Found'), findsOneWidget);
      expect(find.byKey(const Key('unit_doctor_slots_10_0')), findsNothing);
      await capture(t, 'unit_appointment_no_schedule');
      await finish(t);
    },
  );
  testWidgets(
    'empty unit catalogue does not request an unrelated profile unit',
    (t) async {
      final h = UnitAppointmentHarness();
      h.unitRows = [];
      final toast = ToastRecorder()..install();
      addTearDown(toast.uninstall);
      await host(t, h);
      expect(h.unitReads, hasLength(1));
      expect(h.scheduleReads, isEmpty);
      expect(layout(t).unit, isNull);
      expect(layout(t).hasDoctors, isFalse);
      await day(t, DateTime(2026, 10, 25));
      expect(toast.messages, contains('Please Select Unit'));
      expect(h.scheduleReads, isEmpty);
      await finish(t);
    },
  );
  testWidgets(
    'profile unit absent from allowed catalogue waits for an explicit valid selection',
    (t) async {
      final h = UnitAppointmentHarness();
      h.doctorData['depts_id'] = '99';
      await host(t, h);
      expect(h.scheduleReads, isEmpty);
      await tap(t, 'unit_appointment_unit');
      await tap(t, 'doctor_history_choice_unit_1');
      expect(h.scheduleReads.single.queryParameters['depts_id'], '3');
      await finish(t);
    },
  );
  testWidgets(
    'unit-list retry repeats only catalogue stage before loading selected unit',
    (t) async {
      final h = UnitAppointmentHarness();
      h.failUnits = true;
      await host(t, h);
      expect(
        find.byKey(const Key('unit_appointment_error_dialog')),
        findsOneWidget,
      );
      expect(h.scheduleReads, isEmpty);
      h.failUnits = false;
      await tap(t, 'unit_appointment_error_retry');
      expect(h.unitReads, hasLength(2));
      expect(h.scheduleReads, hasLength(1));
      await finish(t);
    },
  );
  testWidgets(
    'schedule retry repeats same unit/date without reloading unit catalogue',
    (t) async {
      final h = UnitAppointmentHarness();
      h.failDoctors = true;
      await host(t, h);
      h.failDoctors = false;
      await tap(t, 'unit_appointment_error_retry');
      expect(h.unitReads, hasLength(1));
      expect(h.scheduleReads, hasLength(2));
      expect(
        h.scheduleReads.first.queryParameters,
        h.scheduleReads.last.queryParameters,
      );
      await finish(t);
    },
  );
  testWidgets('error EXIT closes only Unit screen and performs no write', (
    t,
  ) async {
    final h = UnitAppointmentHarness();
    h.failDoctors = true;
    await host(t, h);
    await tap(t, 'unit_appointment_error_exit');
    expect(find.byType(UnitAppointmentScreen), findsNothing);
    expect(h.posts, isEmpty);
    await finish(t);
  });
  testWidgets(
    'loading disables calendar, month buttons, dropdown and Back actions',
    (t) async {
      final h = UnitAppointmentHarness();
      h.pendingDoctors = Completer<JsonMap>();
      await host(t, h, settle: false);
      expect(find.byKey(const Key('unit_appointment_loading')), findsOneWidget);
      expect(
        t
            .widget<IconButton>(find.byKey(const Key('unit_appointment_back')))
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
    'losing Unit Head permission blocks next schedule read without logging out',
    (t) async {
      final h = UnitAppointmentHarness();
      await host(t, h);
      h.doctorData['doc_deptd_head_flag'] = '0';
      await day(t, DateTime(2026, 10, 25));
      expect(h.scheduleReads, hasLength(1));
      expect(h.auth.stage, AuthStage.authenticated);
      expect(find.text('Not available'), findsOneWidget);
      await tap(t, 'dashboard_message_ok');
      expect(find.byType(UnitAppointmentScreen), findsNothing);
      await finish(t);
    },
  );
  for (final changes in [
    <String, Object?>{'doc_deptd_head_flag': '0'},
    {'doc_manager_flag': '1'},
  ]) {
    testWidgets(
      'direct Unit route with unavailable role $changes makes no schedule GET',
      (t) async {
        final h = UnitAppointmentHarness();
        h.doctorData.addAll(changes);
        await host(t, h);
        expect(h.unitReads, isEmpty);
        expect(h.scheduleReads, isEmpty);
        expect(find.text('Not available'), findsOneWidget);
        await finish(t);
      },
    );
  }
  testWidgets('Admin cannot open doctor Unit schedule through a direct route', (
    t,
  ) async {
    final h = UnitAppointmentHarness();
    h.loginResponse = adminLogin();
    await host(t, h);
    expect(h.unitReads, isEmpty);
    expect(h.scheduleReads, isEmpty);
    expect(
      find.byKey(const Key('unit_appointment_error_dialog')),
      findsOneWidget,
    );
    await finish(t);
  });
  testWidgets(
    'changed department reloads its allowed units and never sends old unit in new scope',
    (t) async {
      final h = UnitAppointmentHarness();
      await host(t, h);
      h.doctorData.addAll({'deptd_id': '99', 'depts_id': '9'});
      await tap(t, 'unit_appointment_unit');
      await tap(t, 'doctor_history_choice_unit_1');
      expect(h.unitReads.last.queryParameters['deptd_id'], '99');
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
    'revoked account access reaches Login without another unit schedule GET',
    (t) async {
      final h = UnitAppointmentHarness();
      await host(t, h, app: true);
      h.doctorData['access_flag'] = '0';
      await day(t, DateTime(2026, 10, 25));
      expect(h.auth.stage, isNot(AuthStage.authenticated));
      expect(h.scheduleReads, hasLength(1));
      expect(find.byType(UnitAppointmentScreen), findsNothing);
      await finish(t);
    },
  );
  testWidgets('logout closes an owned dropdown and removes private Unit rows', (
    t,
  ) async {
    final h = UnitAppointmentHarness();
    await host(t, h, app: true);
    await tap(t, 'unit_appointment_unit');
    await h.auth.logout();
    await t.pumpAndSettle();
    expect(find.byType(UnitAppointmentScreen), findsNothing);
    expect(find.byKey(const Key('doctor_history_choices')), findsNothing);
    await finish(t);
  });
  testWidgets(
    'background discards late schedule data and resume reloads current scope',
    (t) async {
      final h = UnitAppointmentHarness();
      h.pendingDoctors = Completer<JsonMap>();
      await host(t, h, settle: false);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump();
      final pending = h.pendingDoctors!;
      h.pendingDoctors = null;
      pending.complete({
        'count': 1,
        'items': [unitDoctor(name: 'Late Private Doctor')],
      });
      await t.pump();
      expect(find.textContaining('Late Private Doctor'), findsNothing);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(layout(t).rows.first.name, 'Sample Therapist A');
      expect(find.textContaining('Late Private Doctor'), findsNothing);
      expect(h.unitReads, hasLength(2));
      await finish(t);
    },
  );
  for (final size in [
    const Size(280, 568),
    const Size(852, 393),
    const Size(768, 1024),
  ]) {
    testWidgets(
      'Unit controls, dropdown and horizontal cards support $size and large text',
      (t) async {
        final h = UnitAppointmentHarness();
        await host(t, h, size: size, scale: 1.8);
        await tap(t, 'unit_appointment_doctor');
        await tap(t, 'doctor_history_choice_doctor_3');
        expect(layout(t).rows.single.id, '30');
        await scrollTo(
          t,
          find.byKey(const Key('unit_doctor_no_schedule_30_0')),
        );
        expect(t.takeException(), isNull);
        if (size.width > size.height) {
          await capture(t, 'unit_appointment_landscape_large_text');
        } else if (size.width == 280) {
          await capture(t, 'unit_appointment_small_large_text');
        }
        await finish(t);
      },
    );
  }
}

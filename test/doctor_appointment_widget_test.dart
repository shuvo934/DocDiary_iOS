import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_dates.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/login_screen.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/doctor_appointment_models.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/doctor_appointment_screen.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/native_doctor_appointment_layout.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_services.dart';
import 'package:docdiary_ios/features/dashboard/native_dashboard_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'doctor_appointment_test_support.dart';

Future<void> _tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  final scroll = find.byKey(const Key('doctor_appointment_scroll'));
  if (f.evaluate().isEmpty && scroll.evaluate().isNotEmpty) {
    await t.scrollUntilVisible(
      f,
      150,
      maxScrolls: 80,
      scrollable:
          find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
    );
  }
  if (f.hitTestable().evaluate().isEmpty) {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
  }
  await t.tap(f);
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

NativeDoctorAppointmentLayout _layout(WidgetTester t) =>
    t.widget(find.byType(NativeDoctorAppointmentLayout));
Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
  expect(t.takeException(), isNull);
}

Future<void> _show(
  WidgetTester t,
  DoctorAppointmentHarness h, {
  bool settle = true,
  bool direct = false,
  Size size = const Size(393, 852),
  double textScale = 1,
  DashboardDestinationBuilder? destinationBuilder,
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
  Widget root =
      direct
          ? MaterialApp(
            theme: docDiaryTheme(),
            home: DoctorAppointmentScreen(
              auth: h.auth,
              repository: h.appointments,
              destinationBuilder: destinationBuilder,
            ),
          )
          : DocDiaryApp(
            auth: h.auth,
            initializeOnStart: false,
            dashboard: DashboardRepository(h.transport, now: () => h.now),
            dashboardServices: DashboardServices(
              destinationBuilder: destinationBuilder,
            ),
          );
  // MaterialApp creates its own MediaQuery; scale its view through a builder.
  if (textScale != 1) {
    root = MaterialApp(
      theme: docDiaryTheme(),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
      home: DoctorAppointmentScreen(
        auth: h.auth,
        repository: h.appointments,
        destinationBuilder: destinationBuilder,
      ),
    );
  }
  await t.pumpWidget(
    RepaintBoundary(key: const Key('appointment_capture'), child: root),
  );
  if (!direct && textScale == 1) {
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('dashboard_nav_appointment')));
  }
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_APPOINTMENT_CAPTURE_DIR'];
  if (dir == null) return;
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('appointment_capture')),
  );
  await t.runAsync(() async {
    final bitmap = await boundary.toImage(pixelRatio: 1),
        bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
    bitmap.dispose();
    final f = File('$dir/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void _case(String name, Future<void> Function(WidgetTester) run) {
  testWidgets(name, (t) async {
    final shadows = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await run(t);
    } finally {
      debugDisableShadows = shadows;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry
        in <String, List<String>>{
          'Poppins': [
            'Poppins-Regular.ttf',
            'Poppins-SemiBold.ttf',
            'Poppins-Bold.ttf',
          ],
          'Roboto': ['Roboto-Regular.ttf'],
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
          'DocDiaryBengali': ['NotoSansBengali.ttf'],
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
  _case(
    'Dashboard opens today calendar/list; Back refreshes dashboard without login writes',
    (t) async {
      final h = DoctorAppointmentHarness();
      await _show(t, h);
      expect(find.byType(DoctorAppointmentScreen), findsOneWidget);
      expect(find.text('Appointment Schedule'), findsOneWidget);
      expect(find.text('October, 2026'), findsOneWidget);
      expect(_layout(t).rows.length, 6);
      expect(_layout(t).selected, DateTime(2026, 10, 24));
      expect(
        h.appointmentReads.single.uri.queryParameters['pdate'],
        '24-OCT-26',
      );
      expect(h.posts, isEmpty);
      await _capture(t, 'doctor_appointment_today');
      h.transport.requests.clear();
      await _tap(t, 'doctor_appointment_back');
      expect(find.byType(NativeDashboardLayout), findsOneWidget);
      expect(
        h.transport.requests.any(
          (r) => r.uri.path.endsWith('/getScheduleCount'),
        ),
        isTrue,
      );
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'neighbor date selection centers that date and reloads exactly its query',
    (t) async {
      final h = DoctorAppointmentHarness();
      await _show(t, h);
      h.transport.requests.clear();
      await _tap(t, 'doctor_appointment_date_25-OCT-26');
      expect(_layout(t).selected, DateTime(2026, 10, 25));
      expect(h.appointmentReads.length, 1);
      expect(
        h.appointmentReads.single.uri.queryParameters['pdate'],
        '25-OCT-26',
      );
      await _finish(t);
    },
  );
  _case(
    'month navigation clamps partial month endpoints and grays the disabled arrow',
    (t) async {
      final h = DoctorAppointmentHarness();
      await _show(t, h);
      await _tap(t, 'doctor_appointment_previous');
      expect(_layout(t).selected, DateTime(2026, 9, 24));
      expect(find.text('September, 2026'), findsOneWidget);
      final reads = h.appointmentReads.length;
      _layout(t).onMonth(-1);
      await t.pumpAndSettle();
      expect(h.appointmentReads.length, reads);
      expect(
        t
            .widget<InkWell>(
              find.byKey(const Key('doctor_appointment_previous')),
            )
            .onTap,
        isNull,
      );
      await _tap(t, 'doctor_appointment_next');
      await _tap(t, 'doctor_appointment_next');
      expect(_layout(t).selected, DateTime(2026, 11, 24));
      expect(
        t
            .widget<InkWell>(find.byKey(const Key('doctor_appointment_next')))
            .onTap,
        isNull,
      );
      await _capture(t, 'doctor_appointment_month_boundary');
      await _finish(t);
    },
  );
  _case('horizontal drag selects its centered day without duplicate requests', (
    t,
  ) async {
    final h = DoctorAppointmentHarness();
    await _show(t, h);
    h.transport.requests.clear();
    await t.drag(
      find.byKey(const Key('doctor_appointment_calendar')),
      const Offset(-155, 0),
    );
    await t.pumpAndSettle();
    expect(_layout(t).selected.isAfter(DateTime(2026, 10, 24)), isTrue);
    expect(h.appointmentReads.length, 1);
    expect(
      h.appointmentReads.single.uri.queryParameters['pdate'],
      oracleDate(_layout(t).selected),
    );
    await _finish(t);
  });
  _case(
    'native cyan/pale card state, progress and empty/blocked labels are visible',
    (t) async {
      final h = DoctorAppointmentHarness();
      await _show(t, h);
      expect(
        t
            .widget<Card>(find.byKey(const Key('doctor_appointment_card_0')))
            .color,
        const Color(0xff57d2d0),
      );
      expect(
        t
            .widget<LinearProgressIndicator>(
              find.byKey(const Key('doctor_appointment_hp_0')),
            )
            .value,
        .7,
      );
      expect(find.text('Availed'), findsOneWidget);
      expect(
        t
            .widget<Card>(find.byKey(const Key('doctor_appointment_card_1')))
            .color,
        const Color(0xffedf8f8),
      );
      expect(
        find.byKey(const Key('doctor_appointment_1_avail')),
        findsOneWidget,
      );
      await t.scrollUntilVisible(
        find.byKey(const Key('doctor_appointment_card_3')),
        180,
        scrollable:
            find
                .descendant(
                  of: find.byKey(const Key('doctor_appointment_scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
      );
      expect(find.text('No Meeting happened'), findsOneWidget);
      expect(find.text('Blocked Time'), findsOneWidget);
      expect(t.takeException(), isNull);
      await _finish(t);
    },
  );
  _case(
    'future card shows gray border and video notice; empty list keeps usable calendar',
    (t) async {
      final h = DoctorAppointmentHarness();
      h.customRows = [
        {
          ...doctorAppointmentRow(),
          'ts_video_conf_flag': '1',
          'pph_progress': '5',
        },
      ];
      await _show(t, h);
      expect(
        t
            .widget<Card>(find.byKey(const Key('doctor_appointment_card_0')))
            .color,
        const Color(0xfff5f5f5),
      );
      expect(
        find.byKey(const Key('doctor_appointment_video_notice_0')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('doctor_appointment_0_video')), findsNothing);
      await _capture(t, 'doctor_appointment_upcoming');
      h.customRows = [];
      await _tap(t, 'doctor_appointment_date_25-OCT-26');
      expect(find.text('No Schedule Found'), findsOneWidget);
      expect(
        find.byKey(const Key('doctor_appointment_calendar')),
        findsOneWidget,
      );
      await _capture(t, 'doctor_appointment_empty');
      await _finish(t);
    },
  );
  _case('load failure has native Retry/Exit and no invented empty state', (
    t,
  ) async {
    final h = DoctorAppointmentHarness();
    h.transport.onGet =
        (uri) async =>
            uri.path.contains('/appointment_schedule/')
                ? throw const AppFailure('Schedule service failed')
                : await h.respondAppointments(uri);
    await _show(t, h);
    expect(find.byKey(const Key('doctor_appointment_error')), findsOneWidget);
    expect(find.text('No Schedule Found'), findsNothing);
    h.transport.onGet = h.respondAppointments;
    await _tap(t, 'doctor_appointment_error_retry');
    expect(_layout(t).rows.length, 6);
    h.transport.onGet =
        (uri) async =>
            uri.path.contains('/appointment_schedule/')
                ? throw const AppFailure('Schedule service failed')
                : await h.respondAppointments(uri);
    await _tap(t, 'doctor_appointment_date_25-OCT-26');
    await _tap(t, 'doctor_appointment_error_exit');
    expect(find.byType(DoctorAppointmentScreen), findsNothing);
    await _finish(t);
  });
  _case('loading blocks retained date/month/action/back callbacks', (t) async {
    final h = DoctorAppointmentHarness();
    await _show(t, h);
    final before = _layout(t);
    final gate = Completer<JsonMap>();
    h.transport.onGet =
        (uri) =>
            uri.path.contains('/appointment_schedule/')
                ? gate.future
                : h.respondAppointments(uri);
    before.onSelected(DateTime(2026, 10, 25));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    before.onSelected(DateTime(2026, 10, 26));
    before.onMonth(1);
    before.onBack();
    before.onAction(DoctorAppointmentAction.avail, before.rows[1]);
    await t.pump();
    expect(_layout(t).selected, DateTime(2026, 10, 25));
    expect(find.byType(DoctorAppointmentScreen), findsOneWidget);
    gate.complete({'count': 0});
    await t.pumpAndSettle();
    expect(h.posts, isEmpty);
    await _finish(t);
  });
  for (final action in [DoctorAppointmentAction.dynamicPrescription]) {
    _case(
      '${action.name} keeps native visibility but unfinished destination performs no POST',
      (t) async {
        final h = DoctorAppointmentHarness();
        await _show(t, h);
        await _tap(t, 'doctor_appointment_0_${action.name}');
        expect(
          find.byKey(const Key('doctor_appointment_unavailable')),
          findsOneWidget,
        );
        expect(h.posts, isEmpty);
        await t.tap(find.text('Close'));
        await t.pumpAndSettle();
        expect(_layout(t).rows.length, 6);
        await _finish(t);
      },
    );
  }
  _case(
    'native child route data is reviewable and returning refreshes same selected date',
    (t) async {
      final h = DoctorAppointmentHarness();
      DashboardRoute? selected;
      await _show(
        t,
        h,
        destinationBuilder: (context, route) {
          if (route.module != DashboardModule.doctorHealthProgress) return null;
          selected = route;
          return Scaffold(
            body: TextButton(
              key: const Key('return_appointment_child'),
              onPressed: () => Navigator.pop(context),
              child: const Text('Return'),
            ),
          );
        },
      );
      await _tap(t, 'doctor_appointment_0_progress');
      expect(selected!.extras['P_PH_ID'], '11');
      expect(selected!.extras['AD_ID'], '1');
      h.transport.requests.clear();
      await _tap(t, 'return_appointment_child');
      expect(
        h.appointmentReads.single.uri.queryParameters['pdate'],
        '24-OCT-26',
      );
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'walk-in visibility uses both prescription flags and shows only its native extras',
    (t) async {
      final h = DoctorAppointmentHarness();
      DashboardRoute? selected;
      await _show(
        t,
        h,
        destinationBuilder: (context, route) {
          if (route.module != DashboardModule.doctorPrescriptionBuilder) {
            return null;
          }
          selected = route;
          return const Scaffold(body: Text('Walk-in destination'));
        },
      );
      await _tap(t, 'doctor_appointment_walk_in');
      expect(selected!.extras, {'P_PAT_TYPE': '2', 'IS_CREATED': '0'});
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'no dynamic prescription access uses legacy endpoint and hides walk-in',
    (t) async {
      final h = DoctorAppointmentHarness();
      h.doctorData['can_prescribe'] = '0';
      await _show(t, h);
      expect(
        h.appointmentReads.single.uri.pathSegments.last,
        'getAppointmentData',
      );
      expect(find.byKey(const Key('doctor_appointment_walk_in')), findsNothing);
      expect(
        find.byKey(const Key('doctor_appointment_0_legacyPrescription')),
        findsOneWidget,
      );
      await _finish(t);
    },
  );
  _case(
    'logout while read is pending ignores late data and closes this route',
    (t) async {
      final h = DoctorAppointmentHarness();
      final gate = Completer<JsonMap>();
      h.transport.onGet =
          (uri) =>
              uri.path.contains('/appointment_schedule/')
                  ? gate.future
                  : h.respondAppointments(uri);
      await _show(t, h, settle: false);
      await h.auth.logout();
      await t.pumpAndSettle();
      gate.complete({
        'count': 1,
        'items': [doctorAppointmentRow()],
      });
      await t.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DoctorAppointmentScreen), findsNothing);
      await _finish(t);
    },
  );
  _case('foreground refresh supersedes old read and retains selected date', (
    t,
  ) async {
    final h = DoctorAppointmentHarness();
    await _show(t, h);
    final gate = Completer<JsonMap>();
    h.transport.onGet =
        (uri) =>
            uri.path.contains('/appointment_schedule/')
                ? gate.future
                : h.respondAppointments(uri);
    _layout(t).onSelected(DateTime(2026, 10, 25));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    h.customRows = [doctorAppointmentRow(name: 'Fresh Patient')];
    h.transport.onGet = h.respondAppointments;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(_layout(t).selected, DateTime(2026, 10, 25));
    expect(_layout(t).rows.single.value('pat_name'), 'Fresh Patient');
    gate.complete({
      'count': 1,
      'items': [doctorAppointmentRow(name: 'Obsolete Patient')],
    });
    await t.pumpAndSettle();
    expect(_layout(t).rows.single.value('pat_name'), 'Fresh Patient');
    await _finish(t);
  });
  _case('background closes AVAIL dialog and resumes with fresh access check', (
    t,
  ) async {
    final h = DoctorAppointmentHarness();
    await _show(t, h);
    await _tap(t, 'doctor_appointment_1_avail');
    expect(
      find.byKey(const Key('doctor_appointment_avail_dialog')),
      findsOneWidget,
    );
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const Key('doctor_appointment_avail_dialog')),
      findsNothing,
    );
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(_layout(t).rows.length, 6);
    expect(h.posts, isEmpty);
    await _finish(t);
  });
  for (final field in ['fl_flag', 'access_flag', 'exp_date']) {
    _case(
      '$field is checked before changing date and no schedule is read after revocation',
      (t) async {
        final h = DoctorAppointmentHarness();
        await _show(t, h);
        h.transport.requests.clear();
        h.doctorData[field] =
            field == 'fl_flag'
                ? '1'
                : field == 'exp_date'
                ? '01-JAN-20'
                : '0';
        _layout(t).onSelected(DateTime(2026, 10, 25));
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
        expect(h.auth.stage, AuthStage.accountBlocked);
        expect(h.appointmentReads, isEmpty);
        expect(h.posts, isEmpty);
        await _finish(t);
      },
    );
  }
  for (final spec in [
    (const Size(320, 568), 2.0),
    (const Size(568, 320), 1.6),
    (const Size(768, 1024), 1.4),
  ]) {
    _case(
      'calendar, long patient cards and controls fit ${spec.$1} with text scale ${spec.$2}',
      (t) async {
        final h = DoctorAppointmentHarness();
        h.customRows = [
          {
            ...doctorAppointmentRow(
              name:
                  'A long patient name বাংলা পরীক্ষা which wraps across lines',
            ),
            'pfn_fee_name':
                'A long physiotherapy service description বাংলা পরীক্ষা',
            'ts_video_conf_flag': '1',
            'pph_progress': '7',
            'is_ranked': '1',
          },
        ];
        await _show(t, h, direct: true, size: spec.$1, textScale: spec.$2);
        await _tap(t, 'doctor_appointment_0_history');
        await _tap(t, 'doctor_history_back');
        expect(t.takeException(), isNull);
        await _finish(t);
      },
    );
  }
}

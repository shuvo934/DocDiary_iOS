import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/history/doctor_appointment_history_models.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/history/doctor_appointment_history_screen.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/history/native_appointment_history_layout.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/native_doctor_appointment_layout.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'doctor_appointment_history_test_support.dart';

Future<void> _tap(WidgetTester t, String key, {bool settle = true}) async {
  final f = find.byKey(Key(key));
  await t.pumpAndSettle();
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

NativeAppointmentHistoryLayout _layout(WidgetTester t) =>
    t.widget(find.byType(NativeAppointmentHistoryLayout));
Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
  expect(t.takeException(), isNull);
}

Future<void> _show(
  WidgetTester t,
  AppointmentHistoryHarness h, {
  bool open = true,
  bool direct = false,
  Size size = const Size(393, 852),
  double scale = 1,
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
  Widget root;
  if (direct) {
    addTearDown(h.auth.dispose);
    root = MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: docDiaryTheme(),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
      home: DoctorAppointmentHistoryScreen(
        auth: h.auth,
        repository: h.history,
        patient: historyPatient,
      ),
    );
  } else {
    root = DocDiaryApp(
      auth: h.auth,
      initializeOnStart: false,
      dashboard: DashboardRepository(h.transport, now: () => h.now),
      dashboardServices: DashboardServices(
        destinationBuilder: destinationBuilder,
      ),
    );
  }
  await t.pumpWidget(
    RepaintBoundary(key: const Key('history_capture'), child: root),
  );
  await t.pumpAndSettle();
  if (!direct) {
    await _tap(t, 'dashboard_nav_appointment');
    if (open) await _tap(t, 'doctor_appointment_0_history');
  }
}

Future<void> _choose(
  WidgetTester t,
  AppointmentHistoryFilter kind,
  int index,
) async {
  await _tap(t, 'doctor_history_filter_${kind.name}');
  await _tap(t, 'doctor_history_choice_${kind.name}_$index');
}

Future<void> _capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_HISTORY_CAPTURE_DIR'];
  if (dir == null) return;
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('history_capture')),
  );
  await t.runAsync(() async {
    final bitmap = await boundary.toImage(pixelRatio: 1),
        bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
    bitmap.dispose();
    final file = File('$dir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
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
            'Poppins-Medium.ttf',
            'Poppins-SemiBold.ttf',
            'Poppins-Bold.ttf',
          ],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
          'PatuaOne': ['PatuaOne-Regular.ttf'],
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
    'native history opens selected patient; range is month-to-today, independent of parent date',
    (t) async {
      final h = AppointmentHistoryHarness();
      await _show(t, h, open: false);
      h.customRows = [
        {...h.customRows!.single, 'adm_date': '25-OCT-26'},
      ];
      await _tap(t, 'doctor_appointment_date_25-OCT-26');
      await _tap(t, 'doctor_appointment_0_history');
      expect(find.text('Appointment History'), findsOneWidget);
      expect(find.text(historyPatient.name), findsOneWidget);
      expect(find.text(historyPatient.code), findsOneWidget);
      expect(_layout(t).rows.length, 3);
      expect(_layout(t).range.label, '01-OCT-26  ---  24-OCT-26');
      expect(h.historyReads.single.uri.queryParameters, {
        'begin_date': '01-OCT-26',
        'end_date': '24-OCT-26',
        'p_ph_id': '11',
      });
      expect(h.posts, isEmpty);
      await _capture(t, 'doctor_appointment_history');
      h.transport.requests.clear();
      await _tap(t, 'doctor_history_back');
      expect(
        t
            .widget<NativeDoctorAppointmentLayout>(
              find.byType(NativeDoctorAppointmentLayout),
            )
            .selected,
        DateTime(2026, 10, 25),
      );
      expect(
        h.appointmentReads.single.uri.queryParameters['pdate'],
        '25-OCT-26',
      );
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'native portrait patient/date controls stay fixed while history rows scroll',
    (t) async {
      final h = AppointmentHistoryHarness();
      h.historyRows = List.generate(20, (_) => appointmentHistoryRow());
      await _show(t, h);
      final before = t.getRect(find.byKey(const Key('doctor_history_range')));
      await t.drag(
        find.byKey(const Key('doctor_history_scroll')),
        const Offset(0, -400),
      );
      await t.pumpAndSettle();
      expect(t.getRect(find.byKey(const Key('doctor_history_range'))), before);
      expect(find.text(historyPatient.name), findsOneWidget);
      expect(h.historyReads.length, 1);
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'combined local filters distinguish IDs 1/10 and identical doctor names; clear restores rows',
    (t) async {
      final h = AppointmentHistoryHarness();
      await _show(t, h);
      await _tap(t, 'doctor_history_filter_toggle');
      await _tap(t, 'doctor_history_filter_doctor');
      expect(find.text('ID: 10'), findsOneWidget);
      expect(find.text('ID: 1'), findsOneWidget);
      final field = t.getRect(
        find.byKey(const Key('doctor_history_filter_doctor')),
      );
      final popup = t.getRect(find.byKey(const Key('doctor_history_choices')));
      expect(popup.top, closeTo(field.bottom, .5));
      expect(popup.bottom, lessThanOrEqualTo(818));
      await _capture(t, 'doctor_appointment_history_filter');
      await _tap(t, 'doctor_history_choice_doctor_2');
      expect(_layout(t).rows.length, 2);
      await _choose(t, AppointmentHistoryFilter.service, 1);
      await _choose(t, AppointmentHistoryFilter.unit, 1);
      expect(_layout(t).rows.length, 1);
      expect(_layout(t).rows.single.value('doc_id'), '1');
      expect(_layout(t).rows.single.value('pfn_id'), '1');
      expect(h.historyReads.length, 1);
      await _tap(t, 'doctor_history_filter_toggle');
      await _tap(t, 'doctor_history_filter_toggle');
      expect(_layout(t).selected.length, 3);
      await _choose(t, AppointmentHistoryFilter.service, 0);
      await _choose(t, AppointmentHistoryFilter.unit, 0);
      expect(_layout(t).rows.length, 2);
      await _choose(t, AppointmentHistoryFilter.doctor, 0);
      expect(_layout(t).rows.length, 3);
      expect(h.historyReads.length, 1);
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'range picker restores selection, Cancel does no read, Save reloads and resets filters',
    (t) async {
      final h = AppointmentHistoryHarness();
      await _show(t, h);
      await _tap(t, 'doctor_history_filter_toggle');
      await _choose(t, AppointmentHistoryFilter.service, 1);
      await _tap(t, 'doctor_history_range');
      final picker = t.widget<DateRangePickerDialog>(
        find.byType(DateRangePickerDialog),
      );
      expect(picker.helpText, 'Select Begin & End Date');
      expect(picker.initialDateRange!.start, DateTime(2026, 10));
      expect(picker.lastDate, DateTime(2100, 12, 31));
      Navigator.pop(t.element(find.byType(DateRangePickerDialog)));
      await t.pumpAndSettle();
      expect(h.historyReads.length, 1);
      await _tap(t, 'doctor_history_range');
      Navigator.pop(
        t.element(find.byType(DateRangePickerDialog)),
        DateTimeRange(
          start: DateTime(2026, 10, 20),
          end: DateTime(2026, 10, 20),
        ),
      );
      await t.pumpAndSettle();
      expect(h.historyReads.length, 2);
      expect(
        h.historyReads.last.uri.queryParameters['begin_date'],
        '20-OCT-26',
      );
      expect(_layout(t).range.label, '20-OCT-26');
      expect(_layout(t).selected, isEmpty);
      expect(_layout(t).showFilters, isTrue);
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'no upcoming access bounds picker at today and resume clamps an old future range',
    (t) async {
      final h = AppointmentHistoryHarness();
      await _show(t, h);
      await _tap(t, 'doctor_history_range');
      Navigator.pop(
        t.element(find.byType(DateRangePickerDialog)),
        DateTimeRange(
          start: DateTime(2026, 10, 25),
          end: DateTime(2026, 11, 1),
        ),
      );
      await t.pumpAndSettle();
      h.doctorData['upcoming_pat_history'] = '0';
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(_layout(t).range.label, '24-OCT-26');
      expect(h.historyReads.last.uri.queryParameters['end_date'], '24-OCT-26');
      await _tap(t, 'doctor_history_range');
      expect(
        t
            .widget<DateRangePickerDialog>(find.byType(DateRangePickerDialog))
            .lastDate,
        DateTime(2026, 10, 24),
      );
      Navigator.pop(t.element(find.byType(DateRangePickerDialog)));
      await t.pumpAndSettle();
      await _finish(t);
    },
  );
  _case(
    'native status text/colors are visible; hidden OLD flag is not introduced',
    (t) async {
      final h = AppointmentHistoryHarness();
      await _show(t, h);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('( OLD )'), findsNothing);
      final first = t.widget<Container>(
        find.byKey(const Key('doctor_history_status_0')),
      );
      expect((first.decoration! as BoxDecoration).color, DocColors.greenSea);
      await t.ensureVisible(find.byKey(const Key('doctor_history_status_1')));
      await t.pumpAndSettle();
      final second = t.widget<Container>(
        find.byKey(const Key('doctor_history_status_1')),
      );
      expect(
        (second.decoration! as BoxDecoration).color,
        const Color(0xffc23616),
      );
      await t.ensureVisible(find.byKey(const Key('doctor_history_status_2')));
      await t.pumpAndSettle();
      expect(find.text('Upcoming'), findsOneWidget);
      await _finish(t);
    },
  );
  _case(
    'filter rebind evaluates status at the current clock without a new read',
    (t) async {
      final h = AppointmentHistoryHarness();
      h.historyRows = [
        appointmentHistoryRow(day: '24-OCT-26', time: '02:00 PM'),
      ];
      await _show(t, h);
      expect(find.text('Upcoming'), findsOneWidget);
      h.now = DateTime(2026, 10, 24, 14, 30);
      await _tap(t, 'doctor_history_filter_toggle');
      await _choose(t, AppointmentHistoryFilter.service, 1);
      expect(find.text('Completed'), findsOneWidget);
      expect(h.historyReads.length, 1);
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'empty success shows native empty message and retains date/filter controls',
    (t) async {
      final h = AppointmentHistoryHarness();
      h.historyRows = [];
      await _show(t, h);
      expect(find.text('No Appointment History Found'), findsOneWidget);
      await _tap(t, 'doctor_history_filter_toggle');
      expect(
        find.byKey(const Key('doctor_history_filter_service')),
        findsOneWidget,
      );
      expect(h.posts, isEmpty);
      await _capture(t, 'doctor_appointment_history_empty');
      await _finish(t);
    },
  );
  _case('history failure has native Retry/Exit and no false empty state', (
    t,
  ) async {
    final h = AppointmentHistoryHarness();
    h.transport.onGet =
        (uri) async =>
            uri.path.endsWith('/getPatAppointHistory')
                ? throw const AppFailure('History unavailable')
                : await h.respondHistory(uri);
    await _show(t, h);
    expect(find.byKey(const Key('doctor_history_error')), findsOneWidget);
    expect(find.text('No Appointment History Found'), findsNothing);
    h.transport.onGet = h.respondHistory;
    await _tap(t, 'doctor_history_error_retry');
    expect(_layout(t).rows.length, 3);
    h.transport.onGet =
        (uri) async =>
            uri.path.endsWith('/getPatAppointHistory')
                ? throw const AppFailure('History unavailable')
                : await h.respondHistory(uri);
    await _tap(t, 'doctor_history_range');
    Navigator.pop(
      t.element(find.byType(DateRangePickerDialog)),
      DateTimeRange(start: DateTime(2026, 10, 22), end: DateTime(2026, 10, 23)),
    );
    await t.pumpAndSettle();
    await _tap(t, 'doctor_history_error_exit');
    expect(find.byType(DoctorAppointmentHistoryScreen), findsNothing);
    expect(find.byType(NativeDoctorAppointmentLayout), findsOneWidget);
    expect(h.posts, isEmpty);
    await _finish(t);
  });
  _case(
    'background closes an owned dropdown, then fresh read supersedes its callbacks',
    (t) async {
      final h = AppointmentHistoryHarness();
      await _show(t, h);
      await _tap(t, 'doctor_history_filter_toggle');
      await _tap(t, 'doctor_history_filter_doctor');
      expect(find.byKey(const Key('doctor_history_choices')), findsOneWidget);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('doctor_history_choices')), findsNothing);
      h.historyRows = [
        {...appointmentHistoryRow(), 'doc_name': 'Fresh Doctor'},
      ];
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(_layout(t).rows.single.value('doc_name'), 'Fresh Doctor');
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  _case('background supersedes a pending range read; late data is ignored', (
    t,
  ) async {
    final h = AppointmentHistoryHarness();
    await _show(t, h);
    await _tap(t, 'doctor_history_range');
    final gate = Completer<JsonMap>();
    h.transport.onGet =
        (uri) =>
            uri.path.endsWith('/getPatAppointHistory')
                ? gate.future
                : h.respondHistory(uri);
    Navigator.pop(
      t.element(find.byType(DateRangePickerDialog)),
      DateTimeRange(start: DateTime(2026, 10, 20), end: DateTime(2026, 10, 23)),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    final old = _layout(t);
    old.onRange();
    old.onToggle();
    old.onBack();
    expect(find.byType(DoctorAppointmentHistoryScreen), findsOneWidget);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    h.historyRows = [];
    h.transport.onGet = h.respondHistory;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(find.text('No Appointment History Found'), findsOneWidget);
    gate.complete({
      'count': 1,
      'items': [appointmentHistoryRow()],
    });
    await t.pumpAndSettle();
    expect(_layout(t).rows, isEmpty);
    expect(h.posts, isEmpty);
    await _finish(t);
  });
  for (final field in [
    'fl_flag',
    'access_flag',
    'exp_date',
    'pat_app_history',
  ]) {
    _case('$field is rechecked on resume before any patient history read', (
      t,
    ) async {
      final h = AppointmentHistoryHarness();
      await _show(t, h);
      h.transport.requests.clear();
      h.doctorData[field] =
          field == 'fl_flag'
              ? '1'
              : field == 'exp_date'
              ? '01-JAN-20'
              : '0';
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(h.historyReads, isEmpty);
      expect(h.posts, isEmpty);
      if (field == 'pat_app_history') {
        expect(h.auth.stage, AuthStage.authenticated);
        expect(find.byKey(const Key('doctor_history_error')), findsOneWidget);
      } else {
        expect(h.auth.stage, AuthStage.accountBlocked);
      }
      await _finish(t);
    });
  }
  _case(
    'logout removes range picker and patient data; no late history is shown',
    (t) async {
      final h = AppointmentHistoryHarness();
      await _show(t, h);
      await _tap(t, 'doctor_history_range');
      await h.auth.logout();
      await t.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsNothing);
      expect(find.byType(DoctorAppointmentHistoryScreen), findsNothing);
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'custom history destination retains priority and native patient extras',
    (t) async {
      final h = AppointmentHistoryHarness();
      DashboardRoute? captured;
      await _show(
        t,
        h,
        destinationBuilder: (context, route) {
          if (route.module != DashboardModule.doctorAppointmentHistory) {
            return null;
          }
          captured = route;
          return const Scaffold(body: Text('Custom history'));
        },
      );
      expect(find.text('Custom history'), findsOneWidget);
      expect(captured!.extras, {
        'P_NAME': 'Sample Patient',
        'P_CODE': 'P-11',
        'P_PH_ID': '11',
      });
      expect(h.historyReads, isEmpty);
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  for (final spec in [
    (const Size(320, 568), 2.0),
    (const Size(568, 320), 1.6),
    (const Size(768, 1024), 1.4),
  ]) {
    _case('long rows, filters and popup fit ${spec.$1}, text ${spec.$2}', (
      t,
    ) async {
      final h = AppointmentHistoryHarness();
      h.historyRows = List.generate(
        14,
        (i) => {
          ...appointmentHistoryRow(doctor: '$i'),
          'doc_name': 'Doctor $i with a long name বাংলা পরীক্ষা',
          'pfn_fee_name': 'Long service description বাংলা পরীক্ষা',
        },
      );
      await _show(t, h, direct: true, size: spec.$1, scale: spec.$2);
      await _tap(t, 'doctor_history_filter_toggle');
      await _tap(t, 'doctor_history_filter_doctor');
      final choice = find.byKey(const Key('doctor_history_choice_doctor_14'));
      await t.scrollUntilVisible(
        choice,
        100,
        scrollable:
            find
                .descendant(
                  of: find.byKey(const Key('doctor_history_choices')),
                  matching: find.byType(Scrollable),
                )
                .first,
        maxScrolls: 50,
      );
      await _tap(t, 'doctor_history_choice_doctor_14');
      expect(_layout(t).rows.single.value('doc_id'), '13');
      expect(t.takeException(), isNull);
      await _finish(t);
    });
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/appointments/admin_modify/admin_appointment_screen.dart';
import 'package:docdiary_ios/features/appointments/admin_modify/admin_schedule_screen.dart';
import 'package:docdiary_ios/features/appointments/admin_modify/native_admin_appointment_controls.dart';
import 'package:docdiary_ios/features/appointments/all_schedule/all_appointment_screen.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'admin_appointment_test_support.dart';

Future<void> _tap(WidgetTester t, String key, {bool settle = true}) async {
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

Future<void> _host(
  WidgetTester t,
  AdminAppointmentHarness h, {
  bool app = false,
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPadding);
  addTearDown(t.view.resetViewInsets);
  if (!app) addTearDown(h.auth.dispose);
  _resume(t);
  await h.signIn();
  h.transport.requests.clear();
  await t.pumpWidget(
    RepaintBoundary(
      key: const Key('admin_appointment_capture'),
      child:
          app
              ? DocDiaryApp(
                auth: h.auth,
                initializeOnStart: false,
                dashboard: DashboardRepository(h.transport, now: () => h.now),
              )
              : MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: docDiaryTheme(),
                builder:
                    (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(textScale)),
                      child: child!,
                    ),
                home: Builder(
                  builder:
                      (context) => Scaffold(
                        body: TextButton(
                          key: const Key('open_admin_appointment'),
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => AdminAppointmentScreen(
                                        auth: h.auth,
                                        repository: h.repository,
                                      ),
                                ),
                              ),
                          child: const Text('Test home'),
                        ),
                      ),
                ),
              ),
    ),
  );
  await t.pumpAndSettle();
  await _tap(t, app ? 'dashboard_nav_appointment' : 'open_admin_appointment');
}

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> _capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_ADMIN_APPOINTMENT_CAPTURE_DIR'];
  if (dir == null) return;
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('admin_appointment_capture')),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final f = File('$dir/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

NativeAdminAppointmentField _field(WidgetTester t, String key) =>
    t.widget(find.byKey(Key('admin_appointment_$key')));
Future<void> _patient(WidgetTester t, {int index = 0}) async {
  await _tap(t, 'admin_appointment_patient');
  await _tap(t, 'admin_appointment_picker_option_$index');
}

Future<void> _add(
  WidgetTester t, {
  int day = 2,
  int time = 0,
  String? capture,
}) async {
  await _tap(t, 'admin_appointment_add_schedule');
  await _tap(t, 'admin_schedule_date');
  final calendar = t.widget<CalendarDatePicker>(
    find.byType(CalendarDatePicker),
  );
  expect(
    MaterialLocalizations.of(
      t.element(find.byType(CalendarDatePicker)),
    ).firstDayOfWeekIndex,
    6,
  );
  expect(calendar.selectableDayPredicate!(DateTime(2026, 11, day)), true);
  calendar.onDateChanged(DateTime(2026, 11, day));
  await t.pump();
  await t.tap(find.text('OK'));
  await t.pumpAndSettle();
  await _tap(t, 'admin_schedule_time');
  await _tap(t, 'doctor_history_choice_unit_$time');
  if (capture != null) await _capture(t, capture);
  await _tap(t, 'admin_schedule_commit');
}

void _pause(WidgetTester t) {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    t.binding.handleAppLifecycleStateChanged(s);
  }
}

void _resume(WidgetTester t) {
  if (t.binding.lifecycleState == AppLifecycleState.paused) {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void _case(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (t) async {
    final original = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await body(t);
    } finally {
      debugDisableShadows = original;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final toasts = <String>[];
  setUpAll(() async {
    for (final e
        in <String, List<String>>{
          'Poppins': ['Poppins-Regular.ttf', 'Poppins-Bold.ttf'],
          'Archivo': ['Archivo[wdth,wght].ttf'],
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
          'PatuaOne': ['PatuaOne-Regular.ttf'],
          'RussoOne': ['RussoOne-Regular.ttf'],
          'DocDiaryBengali': ['NotoSansBengali.ttf'],
        }.entries) {
      final loader = FontLoader(e.key);
      for (final f in e.value) {
        loader.addFont(rootBundle.load('assets/fonts/$f'));
      }
      await loader.load();
    }
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() {
    toasts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('PonnamKarthik/fluttertoast'),
          (call) async {
            if (call.method == 'showToast') {
              toasts.add((call.arguments as Map)['msg'] as String);
            }
            return true;
          },
        );
  });

  _case(
    'native initial ADD form disables dependent fields and validates Save without a POST',
    (t) async {
      final h = AdminAppointmentHarness();
      await _host(t, h);
      expect(_field(t, 'patient').enabled, true);
      for (final key in ['doctor', 'payment', 'service', 'unit', 'quantity']) {
        expect(_field(t, key).enabled, false);
      }
      expect(h.appointmentReads, isEmpty);
      await _tap(t, 'admin_appointment_submit');
      expect(toasts, contains('Please Select Patient'));
      expect(h.appointmentPosts, isEmpty);
      await _capture(t, '01_add_initial');
      await _finish(t);
    },
  );
  _case(
    'patient search Done does not search/select; validation, clear and duplicate record selection work',
    (t) async {
      final h = AdminAppointmentHarness();
      await _host(t, h);
      await _tap(t, 'admin_appointment_patient');
      await _capture(t, '02_patient_picker');
      await t.enterText(
        find.byKey(const Key('admin_appointment_picker_query')),
        'রহিম',
      );
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(h.appointmentReads.length, 1);
      await _tap(t, 'admin_appointment_picker_search');
      expect(h.appointmentReads.last.uri.queryParameters['ph_pat'], 'রহিম');
      final reads = h.appointmentReads.length;
      await _tap(t, 'admin_appointment_picker_clear');
      expect(h.appointmentReads.length, reads);
      await t.enterText(
        find.byKey(const Key('admin_appointment_picker_query')),
        'ab',
      );
      await _tap(t, 'admin_appointment_picker_search');
      expect(
        find.text('Name or Code must be greater than 2 character'),
        findsOneWidget,
      );
      await t.enterText(
        find.byKey(const Key('admin_appointment_picker_query')),
        'abc-def',
      );
      await _tap(t, 'admin_appointment_picker_search');
      expect(h.appointmentReads.length, reads);
      await _tap(t, 'admin_appointment_picker_option_1');
      expect(
        h.appointmentReads
            .firstWhere((r) => r.uri.path.endsWith('/getDoctorList'))
            .uri
            .queryParameters['ph_id'],
        '102',
      );
      expect(_field(t, 'doctor').value, 'Example Therapist');
      expect(_field(t, 'unit').label, 'Unit');
      expect(_field(t, 'quantity').value, '3');
      expect(h.appointmentPosts, isEmpty);
      await _capture(t, '03_add_ready');
      await _finish(t);
    },
  );
  _case(
    'doctor/payment pickers and service dropdown preserve duplicate names by IDs',
    (t) async {
      final h = AdminAppointmentHarness(autoSelect: false);
      await _host(t, h);
      await _patient(t);
      await _tap(t, 'admin_appointment_doctor');
      await _capture(t, '04_doctor_picker');
      await _tap(t, 'admin_appointment_picker_option_1');
      expect(_field(t, 'unit').value, 'Another Unit');
      await _tap(t, 'admin_appointment_payment');
      await _capture(t, '05_payment_picker');
      await _tap(t, 'admin_appointment_picker_option_1');
      await _tap(t, 'admin_appointment_service');
      await _tap(t, 'doctor_history_choice_unit_1');
      expect(h.appointmentReads.last.uri.queryParameters['p_pfn_id'], '32');
      expect(_field(t, 'payment').value, 'PAY-002');
      await _finish(t);
    },
  );
  _case(
    'schedule date list, Saturday picker, time, update and quantity refund work without API writes',
    (t) async {
      final h = AdminAppointmentHarness();
      await _host(t, h);
      await _patient(t);
      await _add(t, capture: '06_schedule_editor');
      expect(_field(t, 'quantity').value, '2');
      await _capture(t, '07_add_with_schedule');
      await _tap(t, 'admin_appointment_schedule_0');
      expect(
        t
            .widget<NativeAdminAppointmentField>(
              find.byKey(const Key('admin_schedule_date')),
            )
            .enabled,
        false,
      );
      await _tap(t, 'admin_schedule_time');
      await _tap(t, 'doctor_history_choice_unit_1');
      await _tap(t, 'admin_schedule_commit');
      expect(find.text('11:00 AM'), findsOneWidget);
      expect(_field(t, 'quantity').value, '2');
      await _tap(t, 'admin_appointment_remove_0');
      await _tap(t, 'admin_appointment_no');
      expect(
        find.byKey(const Key('admin_appointment_schedule_0')),
        findsOneWidget,
      );
      await _tap(t, 'admin_appointment_remove_0');
      await _tap(t, 'admin_appointment_yes');
      expect(_field(t, 'quantity').value, '3');
      expect(h.appointmentPosts, isEmpty);
      await _finish(t);
    },
  );
  _case('tab switch No preserves schedule and Yes resets all dependent data', (
    t,
  ) async {
    final h = AdminAppointmentHarness();
    await _host(t, h);
    await _patient(t);
    await _add(t);
    await _tap(t, 'admin_appointment_tab_cancel');
    await _tap(t, 'admin_appointment_no');
    expect(
      find.byKey(const Key('admin_appointment_schedule_0')),
      findsOneWidget,
    );
    await _tap(t, 'admin_appointment_tab_cancel');
    await _tap(t, 'admin_appointment_yes');
    expect(_field(t, 'patient').value, '');
    expect(find.text('CANCEL APPOINTMENT'), findsOneWidget);
    await _patient(t);
    expect(find.text('09:00 AM'), findsOneWidget);
    expect(find.text('11:00 AM'), findsOneWidget);
    await _capture(t, '08_cancel_ready');
    await _finish(t);
  });
  _case(
    'Save confirmation No does not post; Yes saves once and clears on success',
    (t) async {
      final h = AdminAppointmentHarness();
      await _host(t, h);
      await _patient(t);
      await _add(t);
      await _tap(t, 'admin_appointment_submit');
      await _tap(t, 'admin_appointment_no');
      expect(h.appointmentPosts, isEmpty);
      final pending = Completer<JsonMap>();
      h.transport.onPost = (_, _) => pending.future;
      await _tap(t, 'admin_appointment_submit');
      await _tap(t, 'admin_appointment_yes', settle: false);
      expect(h.appointmentPosts.length, 1);
      expect(
        t
            .widget<NativeAdminAppointmentButton>(
              find.byKey(const Key('admin_appointment_submit')),
            )
            .onPressed,
        isNull,
      );
      pending.complete({
        'string_out': 'Successfully Created',
        'p_sch_msg': 'false',
      });
      await t.pumpAndSettle();
      expect(find.text('Appointment saved successfully.'), findsOneWidget);
      await _tap(t, 'admin_appointment_ok');
      expect(_field(t, 'patient').value, '');
      expect(h.appointmentPosts.length, 1);
      await _finish(t);
    },
  );
  _case(
    'batch partial failure Retry sends only the remaining row and keeps successful receipt',
    (t) async {
      final h = AdminAppointmentHarness();
      await _host(t, h);
      await _patient(t);
      await _add(t);
      await _add(t, day: 3);
      var count = 0;
      h.transport.onPost = (_, _) async {
        count++;
        if (count == 2) throw const AppFailure('Synthetic save interrupted');
        return {'string_out': 'Successfully Created', 'p_sch_msg': 'false'};
      };
      await _tap(t, 'admin_appointment_submit');
      await _tap(t, 'admin_appointment_yes');
      expect(h.appointmentPosts.length, 2);
      await _tap(t, 'admin_appointment_error_retry');
      expect(h.appointmentPosts.map((r) => r.headers['P_ADM_DATE']), [
        '02-NOV-26',
        '03-NOV-26',
        '03-NOV-26',
      ]);
      await _tap(t, 'admin_appointment_ok');
      await _finish(t);
    },
  );
  _case(
    'collision marks only conflicting row red and re-timing resubmits that row alone',
    (t) async {
      final h = AdminAppointmentHarness();
      await _host(t, h);
      await _patient(t);
      await _add(t);
      await _add(t, day: 3);
      h.transport.onPost =
          (_, headers) async => {
            'string_out': 'Successfully Created',
            'p_sch_msg':
                headers['P_ADM_DATE'] == '03-NOV-26' &&
                        headers['P_TS_ID'] == '401'
                    ? 'true'
                    : 'false',
          };
      await _tap(t, 'admin_appointment_submit');
      await _tap(t, 'admin_appointment_yes');
      expect(
        find.textContaining('Red Marked Appointment Time'),
        findsOneWidget,
      );
      await _tap(t, 'admin_appointment_ok');
      expect(find.byKey(const Key('admin_appointment_remove_0')), findsNothing);
      expect(
        find.byKey(const Key('admin_appointment_add_schedule')),
        findsNothing,
      );
      await _capture(t, '09_partial_collision');
      await _tap(t, 'admin_appointment_schedule_1');
      expect(
        t
            .widget<NativeAdminAppointmentField>(
              find.byKey(const Key('admin_schedule_date')),
            )
            .enabled,
        false,
      );
      await _tap(t, 'admin_schedule_time');
      await _tap(t, 'doctor_history_choice_unit_1');
      await _tap(t, 'admin_schedule_commit');
      await _tap(t, 'admin_appointment_submit');
      await _tap(t, 'admin_appointment_yes');
      expect(h.appointmentPosts.length, 3);
      expect(h.appointmentPosts.last.headers['P_TS_ID'], '402');
      await _tap(t, 'admin_appointment_ok');
      await _finish(t);
    },
  );
  _case(
    'Cancel confirmation saves exact appointment ID and resets within CANCEL tab',
    (t) async {
      final h = AdminAppointmentHarness();
      await _host(t, h);
      await _tap(t, 'admin_appointment_tab_cancel');
      await _patient(t);
      await _tap(t, 'admin_appointment_submit');
      await _tap(t, 'admin_appointment_no');
      expect(h.appointmentPosts, isEmpty);
      await _tap(t, 'admin_appointment_submit');
      await _tap(t, 'admin_appointment_yes');
      expect(h.appointmentPosts.single.headers, {'P_AD_ID': '501'});
      await _tap(t, 'admin_appointment_ok');
      expect(find.text('CANCEL APPOINTMENT'), findsOneWidget);
      expect(_field(t, 'patient').value, '');
      await _finish(t);
    },
  );
  _case(
    'limited access expiry blocks Cancel even when a later time is eligible',
    (t) async {
      final h = AdminAppointmentHarness(fullAccess: false);
      await _host(t, h);
      await _tap(t, 'admin_appointment_tab_cancel');
      await _patient(t);
      await _tap(t, 'admin_appointment_submit');
      expect(find.text('Unable to Cancel Appointment!'), findsOneWidget);
      expect(h.appointmentPosts, isEmpty);
      await _tap(t, 'admin_appointment_ok');
      await _finish(t);
    },
  );
  _case('permission is rechecked after Yes before a Cancel POST', (t) async {
    final h = AdminAppointmentHarness();
    await _host(t, h);
    await _tap(t, 'admin_appointment_tab_cancel');
    await _patient(t);
    await _tap(t, 'admin_appointment_submit');
    h.adminData['all_access_flag'] = '0';
    await _tap(t, 'admin_appointment_yes');
    expect(h.appointmentPosts, isEmpty);
    expect(find.byKey(const Key('admin_appointment_error')), findsOneWidget);
    await _finish(t);
  });
  _case(
    'failed service GET Retry resumes at services and does not repeat doctors/payments',
    (t) async {
      final h = AdminAppointmentHarness();
      var fails = true;
      h.onAppointmentGet = (uri) async {
        if (uri.path.endsWith('/getServiceForAddAppList') && fails) {
          fails = false;
          throw const AppFailure('Service list unavailable');
        }
        return null;
      };
      await _host(t, h);
      await _patient(t);
      expect(find.byKey(const Key('admin_appointment_error')), findsOneWidget);
      await _tap(t, 'admin_appointment_error_retry');
      expect(
        h.appointmentReads
            .where((r) => r.uri.path.endsWith('/getDoctorList'))
            .length,
        1,
      );
      expect(
        h.appointmentReads
            .where((r) => r.uri.path.endsWith('/getPaymentForAddAppList'))
            .length,
        1,
      );
      expect(
        h.appointmentReads
            .where((r) => r.uri.path.endsWith('/getServiceForAddAppList'))
            .length,
        2,
      );
      expect(_field(t, 'quantity').value, '3');
      await _finish(t);
    },
  );
  _case(
    'appointment limit and taken time disable new schedule selection with native messages',
    (t) async {
      final h = AdminAppointmentHarness();
      h.limitData = {'allowed_qty': '1', 'taken_service_qty': '1'};
      await _host(t, h);
      await _patient(t);
      await _tap(t, 'admin_appointment_add_schedule');
      expect(find.text('Appointment Limit Reached!'), findsOneWidget);
      expect(find.byType(AdminScheduleScreen), findsNothing);
      await _finish(t);
    },
  );
  _case(
    'background mid-save keeps acknowledgement, sends no second row and never replays on resume',
    (t) async {
      final h = AdminAppointmentHarness();
      await _host(t, h);
      await _patient(t);
      await _add(t);
      await _add(t, day: 3);
      final pending = Completer<JsonMap>();
      h.transport.onPost = (_, _) => pending.future;
      await _tap(t, 'admin_appointment_submit');
      await _tap(t, 'admin_appointment_yes', settle: false);
      _pause(t);
      await t.pump();
      pending.complete({
        'string_out': 'Successfully Created',
        'p_sch_msg': 'false',
      });
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      _resume(t);
      await t.pumpAndSettle();
      expect(h.appointmentPosts.length, 1);
      expect(find.byKey(const Key('admin_appointment_remove_0')), findsNothing);
      expect(
        find.byKey(const Key('admin_appointment_remove_1')),
        findsOneWidget,
      );
      await _finish(t);
    },
  );
  _case(
    'logout closes patient picker and late reads cannot republish patient data',
    (t) async {
      final h = AdminAppointmentHarness();
      await _host(t, h);
      final pending = Completer<JsonMap>();
      h.onAppointmentGet = (_) async => pending.future;
      await _tap(t, 'admin_appointment_patient', settle: false);
      await h.auth.logout();
      pending.complete({'items': h.patients});
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('admin_appointment_picker')), findsNothing);
      expect(find.text('Example Patient'), findsNothing);
      expect(h.appointmentPosts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'fresh access loss closes admin route instead of leaving an enabled stale form',
    (t) async {
      final h = AdminAppointmentHarness();
      await _host(t, h);
      h.adminData.addAll({
        'all_access_flag': '2',
        'hr_appointment_active': '0',
      });
      await _tap(t, 'admin_appointment_patient');
      expect(
        find.text('Appointment is not available for this account.'),
        findsOneWidget,
      );
      await _tap(t, 'admin_appointment_error_cancel');
      await t.pumpAndSettle();
      // The picker has closed. A fresh parent check closes the parent as well.
      if (find
          .byKey(const Key('admin_appointment_error_cancel'))
          .evaluate()
          .isNotEmpty) {
        await _tap(t, 'admin_appointment_error_cancel');
      }
      expect(find.byType(AdminAppointmentScreen), findsNothing);
      expect(h.appointmentPosts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'real Admin dashboard route opens Modify and VIEW ALL uses accepted All Appointment screen',
    (t) async {
      final h = AdminAppointmentHarness();
      await _host(t, h, app: true);
      expect(find.byType(AdminAppointmentScreen), findsOneWidget);
      await _tap(t, 'admin_appointment_view_all');
      expect(find.byType(AllAppointmentScreen), findsOneWidget);
      await _finish(t);
    },
  );
  for (final size in [const Size(280, 568), const Size(852, 393)]) {
    _case(
      'native form and patient picker stay usable at $size with larger text',
      (t) async {
        final h = AdminAppointmentHarness();
        await _host(t, h, size: size, textScale: 1.4);
        await _tap(t, 'admin_appointment_patient');
        await _tap(t, 'admin_appointment_picker_cancel');
        await _finish(t);
      },
    );
  }
  _case('taken schedule is shown and its time dropdown stays disabled', (
    t,
  ) async {
    final h = AdminAppointmentHarness();
    h.taken = [
      {'schedule': '10:00 AM'},
    ];
    await _host(t, h);
    await _patient(t);
    await _tap(t, 'admin_appointment_add_schedule');
    await _tap(t, 'admin_schedule_date');
    t
        .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
        .onDateChanged(DateTime(2026, 11, 2));
    await t.pump();
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(find.text('Taken Schedule:'), findsOneWidget);
    expect(find.text('10:00 AM'), findsOneWidget);
    expect(
      t
          .widget<NativeAdminAppointmentField>(
            find.byKey(const Key('admin_schedule_time')),
          )
          .enabled,
      false,
    );
    await _capture(t, '10_taken_schedule');
    await _finish(t);
  });
  _case('removing the last conflicting row finishes the native add process', (
    t,
  ) async {
    final h = AdminAppointmentHarness();
    await _host(t, h);
    await _patient(t);
    await _add(t);
    h.transport.onPost =
        (_, _) async => {
          'string_out': 'Successfully Created',
          'p_sch_msg': 'true',
        };
    await _tap(t, 'admin_appointment_submit');
    await _tap(t, 'admin_appointment_yes');
    await _tap(t, 'admin_appointment_ok');
    await _tap(t, 'admin_appointment_remove_0');
    await _tap(t, 'admin_appointment_yes');
    expect(find.byType(AdminAppointmentScreen), findsNothing);
    expect(h.appointmentPosts.length, 1);
    await _finish(t);
  });
  _case(
    'logout while POST is pending discards its receipt and success notice',
    (t) async {
      final h = AdminAppointmentHarness();
      await _host(t, h);
      await _patient(t);
      await _add(t);
      final pending = Completer<JsonMap>();
      h.transport.onPost = (_, _) => pending.future;
      await _tap(t, 'admin_appointment_submit');
      await _tap(t, 'admin_appointment_yes', settle: false);
      await h.auth.logout();
      pending.complete({
        'string_out': 'Successfully Created',
        'p_sch_msg': 'false',
      });
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Appointment saved successfully.'), findsNothing);
      expect(find.text('Example Patient'), findsNothing);
      expect(h.appointmentPosts.length, 1);
      await _finish(t);
    },
  );
  _case('form scroll survives a child schedule page and fresh profile return', (
    t,
  ) async {
    final h = AdminAppointmentHarness();
    await _host(t, h, size: const Size(280, 568));
    await _patient(t);
    await _tap(t, 'admin_appointment_add_schedule');
    await _tap(t, 'admin_appointment_back');
    final scroll =
        find
            .descendant(
              of: find.byKey(
                const PageStorageKey('admin_appointment_form_scroll'),
              ),
              matching: find.byType(Scrollable),
            )
            .first;
    final before = t.state<ScrollableState>(scroll).position.pixels;
    expect(before, greaterThan(0));
    await _tap(t, 'admin_appointment_add_schedule');
    await _tap(t, 'admin_appointment_back');
    expect(
      t.state<ScrollableState>(scroll).position.pixels,
      closeTo(before, .1),
    );
    await _finish(t);
  });
}

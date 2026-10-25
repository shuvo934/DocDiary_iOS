import 'toast_test_support.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/avail/doctor_appointment_avail_repository.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/avail/native_appointment_avail_dialog.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/native_doctor_appointment_layout.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'doctor_appointment_test_support.dart';

Future<void> _tap(WidgetTester t, String key, {bool settle = true}) async {
  final finder = find.byKey(Key(key));
  await t.ensureVisible(finder);
  await t.tap(finder);
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }
  expect(t.takeException(), isNull);
}

Future<void> _show(
  WidgetTester t,
  DoctorAppointmentHarness h, {
  DashboardDestinationBuilder? destinationBuilder,
}) async {
  t.view.physicalSize = const Size(393, 852);
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPadding);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  h.customRows = [doctorAppointmentRow(time: '09:00 AM')];
  await h.signIn();
  h.transport.requests.clear();
  await t.pumpWidget(
    RepaintBoundary(
      key: const Key('avail_capture'),
      child: DocDiaryApp(
        auth: h.auth,
        initializeOnStart: false,
        dashboard: DashboardRepository(h.transport, now: () => h.now),
        dashboardServices: DashboardServices(
          destinationBuilder: destinationBuilder,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  await _tap(t, 'dashboard_nav_appointment');
}

Future<void> _open(WidgetTester t) => _tap(t, 'doctor_appointment_0_avail');
Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
  expect(t.takeException(), isNull);
}

void _availed(DoctorAppointmentHarness h) {
  h.customRows = [
    {...h.customRows!.single, 'avail_flag': '1'},
  ];
}

Future<void> _capture(WidgetTester t, String name) async {
  final directory = Platform.environment['DOC_AVAIL_CAPTURE_DIR'];
  if (directory == null) return;
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('avail_capture')),
  );
  await t.runAsync(() async {
    final bitmap = await boundary.toImage(pixelRatio: 1);
    final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
    bitmap.dispose();
    final output = File('$directory/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
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
  final toasts = ToastRecorder();
  setUp(toasts.install);
  tearDown(toasts.uninstall);
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
          'RussoOne': ['RussoOne-Regular.ttf'],
          'PatuaOne': ['PatuaOne-Regular.ttf'],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
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
    'native form opens without a write; outside/back cannot confirm; Cancel closes',
    (t) async {
      final h = DoctorAppointmentHarness();
      await _show(t, h);
      await _open(t);
      expect(find.text('Avail Schedule'), findsOneWidget);
      expect(find.text('Notes (Optional)'), findsOneWidget);
      expect(h.posts, isEmpty);
      await _capture(t, 'doctor_appointment_avail_form');
      await t.tapAt(const Offset(3, 3));
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byType(NativeAppointmentAvailDialog), findsOneWidget);
      await _tap(t, 'doctor_appointment_avail_cancel');
      expect(find.byType(NativeAppointmentAvailDialog), findsNothing);
      expect(h.posts, isEmpty);
      await _finish(t);
    },
  );
  for (final note in ['', 'Patient attended and started therapy']) {
    _case(
      'explicit AVAIL with optional note "$note" posts once and refreshes status',
      (t) async {
        final h = DoctorAppointmentHarness();
        await _show(t, h);
        await _open(t);
        await t.enterText(
          find.byKey(const Key('doctor_appointment_avail_notes')),
          note,
        );
        h.transport.onPost = (uri, headers) async {
          expect(uri.path, endsWith('/appointment_schedule/availSchedule'));
          expect(headers, {'P_AD_ID': '41', 'P_NOTE': note});
          _availed(h);
          return {'string_out': 'Successfully Created'};
        };
        await _tap(t, 'doctor_appointment_avail_submit');
        expect(h.posts.length, 1);
        expect(find.byType(NativeAppointmentAvailDialog), findsNothing);
        expect(toasts.messages, contains('Successfully Availed'));
        expect(find.text('Availed'), findsOneWidget);
        expect(
          find.byKey(const Key('doctor_appointment_0_avail')),
          findsNothing,
        );
        expect(
          t
              .widget<NativeDoctorAppointmentLayout>(
                find.byType(NativeDoctorAppointmentLayout),
              )
              .selected,
          DateTime(2026, 10, 24),
        );
        await _finish(t);
      },
    );
  }
  _case('Done key only hides keyboard; cancellation discards notes', (t) async {
    final h = DoctorAppointmentHarness();
    await _show(t, h);
    await _open(t);
    await t.enterText(
      find.byKey(const Key('doctor_appointment_avail_notes')),
      'Discard this note',
    );
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(h.posts, isEmpty);
    await _tap(t, 'doctor_appointment_avail_cancel');
    await _open(t);
    expect(
      t
          .widget<TextField>(
            find.byKey(const Key('doctor_appointment_avail_notes')),
          )
          .controller!
          .text,
      isEmpty,
    );
    await _tap(t, 'doctor_appointment_avail_cancel');
    await _finish(t);
  });
  _case(
    'retained double tap and Back while saving cannot duplicate or dismiss the write',
    (t) async {
      final h = DoctorAppointmentHarness();
      await _show(t, h);
      await _open(t);
      final gate = Completer<JsonMap>();
      h.transport.onPost = (_, __) => gate.future;
      final submit =
          t
              .widget<ElevatedButton>(
                find.byKey(const Key('doctor_appointment_avail_submit')),
              )
              .onPressed!;
      submit();
      submit();
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(h.posts.length, 1);
      expect(
        find.byKey(const Key('doctor_appointment_avail_loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('doctor_appointment_avail_cancel')),
        findsNothing,
      );
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.byType(NativeAppointmentAvailDialog), findsOneWidget);
      _availed(h);
      gate.complete({'string_out': 'Successfully Created'});
      await t.pumpAndSettle();
      expect(find.text('Availed'), findsOneWidget);
      expect(h.posts.length, 1);
      await _finish(t);
    },
  );
  _case(
    'server failure is visible; explicit Retry preserves the submitted note',
    (t) async {
      final h = DoctorAppointmentHarness();
      await _show(t, h);
      await _open(t);
      await t.enterText(
        find.byKey(const Key('doctor_appointment_avail_notes')),
        'Patient is here',
      );
      h.transport.onPost =
          (_, __) async => {
            'string_out': 'Server could not save this schedule',
          };
      await _tap(t, 'doctor_appointment_avail_submit');
      expect(find.text('Server could not save this schedule'), findsOneWidget);
      expect(h.posts.length, 1);
      await _capture(t, 'doctor_appointment_avail_retry');
      h.transport.onPost = (_, headers) async {
        expect(headers['P_NOTE'], 'Patient is here');
        _availed(h);
        return {'string_out': 'Successfully Created'};
      };
      await _tap(t, 'doctor_appointment_avail_retry');
      expect(h.posts.length, 2);
      expect(find.text('Availed'), findsOneWidget);
      await _finish(t);
    },
  );
  _case('a failed write can be cancelled without another POST', (t) async {
    final h = DoctorAppointmentHarness();
    await _show(t, h);
    await _open(t);
    h.transport.onPost =
        (_, __) async => throw const AppFailure('Network failed');
    await _tap(t, 'doctor_appointment_avail_submit');
    await _tap(t, 'doctor_appointment_avail_error_cancel');
    expect(find.byType(NativeAppointmentAvailDialog), findsNothing);
    expect(h.posts.length, 1);
    await _finish(t);
  });
  _case('committed timeout Retry reads status and never posts twice', (
    t,
  ) async {
    final h = DoctorAppointmentHarness();
    await _show(t, h);
    await _open(t);
    h.transport.onPost = (_, __) async {
      _availed(h);
      throw const AppFailure(
        'The server took too long to respond.',
        kind: FailureKind.network,
      );
    };
    await _tap(t, 'doctor_appointment_avail_submit');
    expect(h.posts.length, 1);
    await _tap(t, 'doctor_appointment_avail_retry');
    expect(h.posts.length, 1);
    expect(toasts.messages, contains('This schedule is already availed.'));
    expect(find.text('Availed'), findsOneWidget);
    await _finish(t);
  });
  _case('failed status preflight shows Retry without any POST', (t) async {
    final h = DoctorAppointmentHarness();
    await _show(t, h);
    await _open(t);
    h.transport.onGet =
        (uri) async =>
            uri.path.contains('/appointment_schedule/')
                ? throw const AppFailure('Status could not load')
                : await h.respondAppointments(uri);
    await _tap(t, 'doctor_appointment_avail_submit');
    expect(find.text('Status could not load'), findsOneWidget);
    expect(h.posts, isEmpty);
    h.transport.onGet = h.respondAppointments;
    h.transport.onPost = (_, __) async {
      _availed(h);
      return {'string_out': 'Successfully Created'};
    };
    await _tap(t, 'doctor_appointment_avail_retry');
    expect(h.posts.length, 1);
    await _finish(t);
  });
  _case(
    'unsupported header characters keep an editable form instead of posting corrupt notes',
    (t) async {
      final h = DoctorAppointmentHarness();
      await _show(t, h);
      await _open(t);
      await t.enterText(
        find.byKey(const Key('doctor_appointment_avail_notes')),
        'বাংলা',
      );
      await _tap(t, 'doctor_appointment_avail_submit');
      expect(find.textContaining('single line of English'), findsOneWidget);
      expect(
        find.byKey(const Key('doctor_appointment_avail_notes')),
        findsOneWidget,
      );
      expect(h.posts, isEmpty);
      await t.enterText(
        find.byKey(const Key('doctor_appointment_avail_notes')),
        'Ready',
      );
      h.transport.onPost = (_, __) async {
        _availed(h);
        return {'string_out': 'Successfully Created'};
      };
      await _tap(t, 'doctor_appointment_avail_submit');
      expect(h.posts.single.headers['P_NOTE'], 'Ready');
      await _finish(t);
    },
  );
  _case(
    'reassigned patient closes stale confirmation and refreshes without a write',
    (t) async {
      final h = DoctorAppointmentHarness();
      await _show(t, h);
      await _open(t);
      h.customRows = [
        {
          ...h.customRows!.single,
          'patient_data': '555',
          'pat_name': 'Replacement Patient',
        },
      ];
      await _tap(t, 'doctor_appointment_avail_submit');
      expect(h.posts, isEmpty);
      expect(find.byType(NativeAppointmentAvailDialog), findsNothing);
      expect(find.text('Replacement Patient'), findsOneWidget);
      expect(
        toasts.messages,
        contains('This schedule is no longer available to avail.'),
      );
      await _finish(t);
    },
  );
  for (final field in ['fl_flag', 'access_flag', 'exp_date']) {
    _case(
      '$field is checked again at submit, closing the dialog without POST',
      (t) async {
        final h = DoctorAppointmentHarness();
        await _show(t, h);
        await _open(t);
        h.doctorData[field] =
            field == 'fl_flag'
                ? '1'
                : field == 'exp_date'
                ? '01-JAN-20'
                : '0';
        await _tap(t, 'doctor_appointment_avail_submit');
        expect(h.auth.stage, AuthStage.accountBlocked);
        expect(find.byType(NativeAppointmentAvailDialog), findsNothing);
        expect(h.posts, isEmpty);
        await _finish(t);
      },
    );
  }
  _case('background during status check cannot send a late POST', (t) async {
    final h = DoctorAppointmentHarness();
    await _show(t, h);
    await _open(t);
    final gate = Completer<JsonMap>();
    h.transport.onGet =
        (uri) =>
            uri.path.contains('/appointment_schedule/')
                ? gate.future
                : h.respondAppointments(uri);
    await _tap(t, 'doctor_appointment_avail_submit', settle: false);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    h.transport.onGet = h.respondAppointments;
    await t.pump();
    gate.complete({'count': 1, 'items': h.customRows!});
    await t.pumpAndSettle();
    expect(find.byType(NativeAppointmentAvailDialog), findsNothing);
    expect(h.posts, isEmpty);
    expect(find.byKey(const Key('doctor_appointment_0_avail')), findsOneWidget);
    await _finish(t);
  });
  _case('resume waits for in-flight POST then refreshes; it never resubmits', (
    t,
  ) async {
    final h = DoctorAppointmentHarness();
    await _show(t, h);
    await _open(t);
    final gate = Completer<JsonMap>();
    h.transport.onPost = (_, __) => gate.future;
    await _tap(t, 'doctor_appointment_avail_submit', settle: false);
    expect(h.posts.length, 1);
    final before =
        h.transport.requests
            .where(
              (r) =>
                  r.method == 'GET' &&
                  r.uri.path.contains('/appointment_schedule/'),
            )
            .length;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(
      h.transport.requests
          .where(
            (r) =>
                r.method == 'GET' &&
                r.uri.path.contains('/appointment_schedule/'),
          )
          .length,
      before,
    );
    _availed(h);
    gate.complete({'string_out': 'Successfully Created'});
    await t.pumpAndSettle();
    expect(find.text('Availed'), findsOneWidget);
    expect(find.byType(NativeAppointmentAvailDialog), findsNothing);
    expect(h.posts.length, 1);
    await _finish(t);
  });
  _case('logout drops a late success without messages or further writes', (
    t,
  ) async {
    final h = DoctorAppointmentHarness();
    await _show(t, h);
    await _open(t);
    final gate = Completer<JsonMap>();
    h.transport.onPost = (_, __) => gate.future;
    await _tap(t, 'doctor_appointment_avail_submit', settle: false);
    await h.auth.logout();
    await t.pumpAndSettle();
    gate.complete({'string_out': 'Successfully Created'});
    await t.pumpAndSettle();
    expect(find.byType(NativeAppointmentAvailDialog), findsNothing);
    expect(toasts.messages, isNot(contains('Successfully Availed')));
    expect(h.posts.length, 1);
    await _finish(t);
  });
  _case('dispose while POST is pending ignores the later result safely', (
    t,
  ) async {
    final h = DoctorAppointmentHarness();
    await _show(t, h);
    await _open(t);
    final gate = Completer<JsonMap>();
    h.transport.onPost = (_, __) => gate.future;
    await _tap(t, 'doctor_appointment_avail_submit', settle: false);
    await _finish(t);
    gate.complete({'string_out': 'Successfully Created'});
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(h.posts.length, 1);
  });
  _case('existing custom AVAIL destination retains priority', (t) async {
    final h = DoctorAppointmentHarness();
    DashboardRoute? captured;
    await _show(
      t,
      h,
      destinationBuilder: (context, route) {
        if (route.module != DashboardModule.doctorAppointmentAvail) return null;
        captured = route;
        return const Scaffold(body: Text('Custom AVAIL destination'));
      },
    );
    await _open(t);
    expect(find.text('Custom AVAIL destination'), findsOneWidget);
    expect(captured!.extras, {'AD_ID': '41'});
    expect(find.byType(NativeAppointmentAvailDialog), findsNothing);
    expect(h.posts, isEmpty);
    await _finish(t);
  });
  for (final spec in [
    (const Size(320, 568), 2.0, 260.0),
    (const Size(568, 320), 1.6, 150.0),
    (const Size(768, 1024), 1.4, 300.0),
  ]) {
    _case(
      'notes and actions remain reachable at ${spec.$1}, text ${spec.$2}, with keyboard',
      (t) async {
        t.view.physicalSize = spec.$1;
        t.view.devicePixelRatio = 1;
        t.view.viewInsets = FakeViewPadding(bottom: spec.$3);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetViewInsets);
        await t.pumpWidget(
          MaterialApp(
            theme: docDiaryTheme(),
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(spec.$2)),
                  child: child!,
                ),
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      key: const Key('open_standalone'),
                      onPressed:
                          () => unawaited(
                            showDialog<DoctorAppointmentAvailResult>(
                              context: context,
                              barrierDismissible: false,
                              builder:
                                  (_) => PopScope(
                                    canPop: false,
                                    child: NativeAppointmentAvailDialog(
                                      onSubmit:
                                          (_, __) async =>
                                              DoctorAppointmentAvailResult
                                                  .created,
                                    ),
                                  ),
                            ),
                          ),
                      child: const Text('Open'),
                    ),
                  ),
            ),
          ),
        );
        await _tap(t, 'open_standalone');
        final field = find.byKey(const Key('doctor_appointment_avail_notes'));
        await t.ensureVisible(field);
        await t.enterText(field, 'Ready');
        await _tap(t, 'doctor_appointment_avail_submit');
        expect(find.byType(NativeAppointmentAvailDialog), findsNothing);
        await _finish(t);
      },
    );
  }
}

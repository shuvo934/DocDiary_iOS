import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/progress/doctor_progress_models.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/progress/doctor_progress_screen.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/progress/native_doctor_progress_layout.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/native_doctor_appointment_layout.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'doctor_progress_test_support.dart';

Future<void> _tap(WidgetTester t, String key, {bool settle = true}) async {
  final finder = find.byKey(Key(key));
  await t.pumpAndSettle();
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

NativeDoctorProgressLayout _layout(WidgetTester t) =>
    t.widget(find.byType(NativeDoctorProgressLayout));
Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
  expect(t.takeException(), isNull);
}

Future<void> _show(
  WidgetTester t,
  DoctorProgressHarness h, {
  bool direct = false,
  DoctorProgressSeed? seed,
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
  final Widget root;
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
      home: DoctorProgressScreen(
        auth: h.auth,
        repository: h.progress,
        seed: seed ?? h.seed,
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
    RepaintBoundary(key: const Key('progress_capture'), child: root),
  );
  await t.pumpAndSettle();
  if (!direct) {
    await _tap(t, 'dashboard_nav_appointment');
    await _tap(t, 'doctor_appointment_0_progress');
  }
  expect(t.takeException(), isNull);
}

Future<void> _choose(WidgetTester t, String kind, int index) async {
  await _tap(
    t,
    kind == 'score' ? 'doctor_progress_score' : 'doctor_progress_filter_$kind',
  );
  expect(find.byKey(Key('doctor_progress_choices_$kind')), findsOneWidget);
  await t.scrollUntilVisible(
    find.byKey(
      Key('doctor_history_choice_${kind == 'score' ? 'service' : kind}_$index'),
    ),
    100,
    scrollable: find.descendant(
      of: find.byKey(const Key('doctor_history_choices')),
      matching: find.byType(Scrollable),
    ),
  );
  await t.pumpAndSettle();
  await _tap(
    t,
    'doctor_history_choice_${kind == 'score' ? 'service' : kind}_$index',
  );
}

Future<void> _fill(
  WidgetTester t, {
  String note = 'ভালো হচ্ছে',
  int score = 7,
}) async {
  await _tap(t, 'doctor_progress_add_tab');
  await _choose(t, 'score', score - 1);
  await t.enterText(find.byKey(const Key('doctor_progress_notes')), note);
  await t.testTextInput.receiveAction(TextInputAction.done);
  await t.pumpAndSettle();
}

Future<void> _confirm(
  WidgetTester t, {
  bool yes = true,
  bool settle = true,
}) async {
  await _tap(t, 'doctor_progress_submit');
  expect(find.byKey(const Key('doctor_progress_confirm')), findsOneWidget);
  await _tap(
    t,
    yes ? 'doctor_progress_confirm_yes' : 'doctor_progress_confirm_no',
    settle: settle,
  );
}

Future<void> _capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_PROGRESS_CAPTURE_DIR'];
  if (dir == null) return;
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('progress_capture')),
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
    final old = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await run(t);
    } finally {
      debugDisableShadows = old;
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
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
          'PatuaOne': ['PatuaOne-Regular.ttf'],
          'RussoOne': ['RussoOne-Regular.ttf'],
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
    'appointment opens native progress history and returns to the selected date',
    (t) async {
      final h = DoctorProgressHarness();
      await _show(t, h);
      expect(find.text('Health Progress'), findsOneWidget);
      expect(find.text('Sample Patient'), findsOneWidget);
      expect(find.text('P-11'), findsOneWidget);
      expect(_layout(t).rows.length, 3);
      expect(_layout(t).adding, isFalse);
      expect(_layout(t).canAdd, isTrue);
      expect(
        t.widget<Text>(find.byKey(const Key('doctor_progress_current'))).data,
        '8',
      );
      expect(
        t
            .widget<LinearProgressIndicator>(
              find.byKey(const Key('doctor_progress_bar')),
            )
            .value,
        .8,
      );
      expect(h.progressReads.length, 4);
      expect(h.progressWrites, isEmpty);
      final card = t.getRect(
        find.byKey(const Key('doctor_progress_history_card')),
      );
      final lastRow = t.getRect(find.byKey(const Key('doctor_progress_row_2')));
      expect(card.bottom, closeTo(lastRow.bottom, 1));
      expect(
        card.top,
        t.getTopLeft(find.byKey(const Key('doctor_progress_table_header'))).dy,
      );
      await _capture(t, 'doctor_progress_history');
      h.transport.requests.clear();
      await _tap(t, 'doctor_progress_back');
      expect(find.byType(NativeDoctorAppointmentLayout), findsOneWidget);
      expect(
        h.appointmentReads.single.uri.queryParameters['pdate'],
        '24-OCT-26',
      );
      await _finish(t);
    },
  );
  _case(
    'history scrolls horizontally together and keeps header fixed during vertical scroll',
    (t) async {
      final h = DoctorProgressHarness();
      h.progressRows = List.generate(
        30,
        (i) => progressRow(
          id: '$i',
          notes:
              'Long clinical progress note number $i with wrapping and examination detail.',
        ),
      );
      await _show(t, h);
      final header = find.byKey(const Key('doctor_progress_table_header')),
          first = find.byKey(const Key('doctor_progress_row_0'));
      final oldHeader = t.getTopLeft(header), oldFirst = t.getTopLeft(first);
      await t.drag(
        find.byKey(const Key('doctor_progress_horizontal')),
        const Offset(-650, 0),
      );
      await t.pumpAndSettle();
      expect(t.getTopLeft(header).dx, lessThan(oldHeader.dx));
      expect(
        t.getTopLeft(first).dx - t.getTopLeft(header).dx,
        closeTo(oldFirst.dx - oldHeader.dx, .1),
      );
      final headerY = t.getTopLeft(header).dy;
      await t.dragFrom(Offset(180, headerY + 160), const Offset(0, -140));
      await t.pumpAndSettle();
      expect(t.getTopLeft(header).dy, headerY);
      final scroll = t.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const Key('doctor_progress_table_rows')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scroll.position.pixels, greaterThan(0));
      expect(t.takeException(), isNull);
      await _finish(t);
    },
  );
  _case(
    'independent exact-ID filters update first score and empty state without APIs',
    (t) async {
      final h = DoctorProgressHarness();
      await _show(t, h);
      final reads = h.progressReads.length;
      await _tap(t, 'doctor_progress_filter_toggle');
      await _choose(t, 'doctor', 2);
      expect(_layout(t).rows.map((r) => r.score), [4, 2]);
      await _choose(t, 'service', 1);
      expect(_layout(t).rows.single.score, 2);
      expect(
        t.widget<Text>(find.byKey(const Key('doctor_progress_current'))).data,
        '2',
      );
      await _capture(t, 'doctor_progress_filters');
      await _choose(t, 'service', 3);
      expect(_layout(t).rows, isEmpty);
      expect(find.byKey(const Key('doctor_progress_empty')), findsOneWidget);
      expect(
        t.widget<Text>(find.byKey(const Key('doctor_progress_current'))).data,
        '0',
      );
      await _choose(t, 'doctor', 0);
      await _choose(t, 'service', 0);
      expect(_layout(t).rows.length, 3);
      expect(h.progressReads.length, reads);
      expect(h.progressWrites, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'empty response keeps patient and table header, score zero and usable add tab',
    (t) async {
      final h = DoctorProgressHarness();
      h.progressRows = [];
      await _show(t, h);
      expect(find.text('No Information Found'), findsOneWidget);
      expect(
        find.byKey(const Key('doctor_progress_table_header')),
        findsOneWidget,
      );
      expect(_layout(t).canAdd, isTrue);
      await _capture(t, 'doctor_progress_empty');
      await _finish(t);
    },
  );
  _case('add form retains draft across tabs and IME Done never posts', (
    t,
  ) async {
    final h = DoctorProgressHarness();
    h.customRows = [
      {
        ...h.customRows!.single,
        'pfn_fee_name': 'Physiotherapy Service Charge',
        'depts_name': 'Example Communication Group',
      },
    ];
    await _show(t, h);
    await _fill(t);
    expect(find.text('24-OCT-26'), findsOneWidget);
    expect(find.text('Physiotherapy Service Charge'), findsOneWidget);
    final date = t.getRect(
      find.byKey(const Key('doctor_progress_readonly_date')),
    );
    final service = t.getRect(
      find.byKey(const Key('doctor_progress_readonly_service')),
    );
    final doctor = t.getRect(
      find.byKey(const Key('doctor_progress_readonly_doctor')),
    );
    final unit = t.getRect(
      find.byKey(const Key('doctor_progress_readonly_unit')),
    );
    expect(date.height, service.height);
    expect(doctor.height, unit.height);
    await t.tap(find.byKey(const Key('doctor_progress_readonly_service')));
    await t.pump();
    expect(_layout(t).score, 7);
    expect(_layout(t).notes.text, 'ভালো হচ্ছে');
    expect(h.progressWrites, isEmpty);
    expect(t.testTextInput.isVisible, isFalse);
    await _capture(t, 'doctor_progress_add');
    await _tap(t, 'doctor_progress_history_tab');
    expect(_layout(t).adding, isFalse);
    await _tap(t, 'doctor_progress_add_tab');
    expect(_layout(t).notes.text, 'ভালো হচ্ছে');
    expect(_layout(t).score, 7);
    await _confirm(t, yes: false);
    expect(h.progressWrites, isEmpty);
    expect(_layout(t).notes.text, 'ভালো হচ্ছে');
    await _finish(t);
  });
  _case('score and note validation follow native order and block writes', (
    t,
  ) async {
    final h = DoctorProgressHarness();
    await _show(t, h);
    await _tap(t, 'doctor_progress_add_tab');
    await _tap(t, 'doctor_progress_submit');
    expect(
      find.byKey(const Key('doctor_progress_score_missing')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('doctor_progress_confirm')), findsNothing);
    await _choose(t, 'score', 9);
    expect(_layout(t).score, 10);
    await t.enterText(find.byKey(const Key('doctor_progress_notes')), ' \n ');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await _tap(t, 'doctor_progress_submit');
    expect(
      find.byKey(const Key('doctor_progress_notes_missing')),
      findsOneWidget,
    );
    expect(h.progressWrites, isEmpty);
    await _finish(t);
  });
  _case('confirmed add posts once, refreshes all four APIs and hides add', (
    t,
  ) async {
    final h = DoctorProgressHarness();
    await _show(t, h);
    await _fill(t);
    final reads = h.progressReads.length;
    h.transport.onBytes = (r) async {
      h.commitProgress(r);
      return {'string_out': 'Successfully Created'};
    };
    await _confirm(t);
    expect(h.progressWrites.length, 1);
    expect(find.text('New Progress Added'), findsOneWidget);
    expect(_layout(t).canAdd, isFalse);
    expect(_layout(t).adding, isFalse);
    expect(_layout(t).rows.first.value('pph_notes'), 'ভালো হচ্ছে');
    expect(h.progressReads.length, reads + 5);
    expect(find.byKey(const Key('doctor_progress_add_tab')), findsNothing);
    await _finish(t);
  });
  _case(
    'retained Yes and form callbacks cannot duplicate a pending write or pop screen',
    (t) async {
      final h = DoctorProgressHarness();
      await _show(t, h);
      await _fill(t);
      final form = _layout(t);
      await _tap(t, 'doctor_progress_submit');
      final yes =
          t
              .widget<TextButton>(
                find.byKey(const Key('doctor_progress_confirm_yes')),
              )
              .onPressed!;
      final gate = Completer<JsonMap>();
      h.transport.onBytes = (_) => gate.future;
      yes();
      yes();
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(h.progressWrites.length, 1);
      form.onSubmit();
      form.onBack();
      form.onAdd();
      form.onHistory();
      await t.pump();
      expect(find.byType(DoctorProgressScreen), findsOneWidget);
      expect(h.progressWrites.length, 1);
      h.commitProgress(h.progressWrites.single);
      gate.complete({'string_out': 'Successfully Created'});
      await t.pumpAndSettle();
      expect(_layout(t).canAdd, isFalse);
      expect(h.progressWrites.length, 1);
      await _finish(t);
    },
  );
  _case('write Cancel keeps the entered score and note for correction', (
    t,
  ) async {
    final h = DoctorProgressHarness();
    await _show(t, h);
    await _fill(t);
    h.transport.onBytes =
        (_) async => throw const AppFailure('Server rejected progress');
    await _confirm(t);
    expect(
      find.byKey(const Key('doctor_progress_write_error')),
      findsOneWidget,
    );
    await t.tapAt(const Offset(3, 3));
    await t.pumpAndSettle();
    expect(
      find.byKey(const Key('doctor_progress_write_error')),
      findsOneWidget,
    );
    await _tap(t, 'doctor_progress_error_cancel');
    expect(_layout(t).adding, isTrue);
    expect(_layout(t).score, 7);
    expect(_layout(t).notes.text, 'ভালো হচ্ছে');
    expect(h.progressWrites.length, 1);
    await _finish(t);
  });
  _case('explicit Retry reuses immutable note, score and native entry time', (
    t,
  ) async {
    final h = DoctorProgressHarness();
    await _show(t, h);
    await _fill(t);
    h.transport.onBytes = (_) async => throw const AppFailure('Network failed');
    await _confirm(t);
    final bytes = h.progressWrites.single.body.toList();
    h.now = h.now.add(const Duration(minutes: 2));
    h.transport.onBytes = (r) async {
      h.commitProgress(r);
      return {'string_out': 'Successfully Created'};
    };
    await _tap(t, 'doctor_progress_error_retry');
    expect(h.progressWrites.length, 2);
    expect(h.progressWrites.last.body, bytes);
    expect(_layout(t).canAdd, isFalse);
    await _finish(t);
  });
  _case(
    'a committed response timeout is reconciled on Retry without another POST',
    (t) async {
      final h = DoctorProgressHarness();
      await _show(t, h);
      await _fill(t);
      h.transport.onBytes = (r) async {
        h.commitProgress(r);
        throw const AppFailure('Timed out', kind: FailureKind.network);
      };
      await _confirm(t);
      expect(h.progressWrites.length, 1);
      await _tap(t, 'doctor_progress_error_retry');
      expect(h.progressWrites.length, 1);
      expect(_layout(t).canAdd, isFalse);
      expect(
        find.text('Progress has already been added for this schedule.'),
        findsOneWidget,
      );
      await _finish(t);
    },
  );
  _case(
    'read failure publishes no partial table and Retry reloads full chain',
    (t) async {
      final h = DoctorProgressHarness();
      var fail = true;
      h.transport.onGet =
          (uri) async =>
              fail && uri.path.endsWith('/getUnit')
                  ? throw const AppFailure('Read failed')
                  : await h.respondProgress(uri);
      await _show(t, h);
      expect(
        find.byKey(const Key('doctor_progress_load_error')),
        findsOneWidget,
      );
      expect(_layout(t).rows, isEmpty);
      expect(h.progressReads.map((r) => r.uri.pathSegments.last), [
        'getHealthProgress',
        'getService',
        'getUnit',
      ]);
      fail = false;
      await _tap(t, 'doctor_progress_error_retry');
      expect(_layout(t).rows.length, 3);
      expect(h.progressReads.length, 7);
      expect(h.progressWrites, isEmpty);
      await _finish(t);
    },
  );
  _case('read error Exit returns to appointment screen and refreshes it', (
    t,
  ) async {
    final h = DoctorProgressHarness();
    h.transport.onGet =
        (uri) async =>
            uri.path.contains('/health_progress/')
                ? throw const AppFailure('Read failed')
                : await h.respondProgress(uri);
    await _show(t, h);
    await _tap(t, 'doctor_progress_error_exit');
    expect(find.byType(DoctorProgressScreen), findsNothing);
    expect(find.byType(NativeDoctorAppointmentLayout), findsOneWidget);
    expect(h.progressWrites, isEmpty);
    await _finish(t);
  });
  for (final edit in <JsonMap>[
    {'is_ranked': '1'},
    {'schedule_time': '09:00 PM'},
    {'adm_date': '23-OCT-26'},
  ]) {
    _case('native ineligible $edit remains read-only', (t) async {
      final h = DoctorProgressHarness();
      h.customRows = [
        {...h.customRows!.first, ...edit},
      ];
      await _show(t, h, direct: true);
      expect(find.byKey(const Key('doctor_progress_add_tab')), findsNothing);
      expect(_layout(t).rows.length, 3);
      expect(h.progressWrites, isEmpty);
      await _finish(t);
    });
  }
  _case(
    'patient-search view is read-only even with a valid patient and history',
    (t) async {
      final h = DoctorProgressHarness();
      await _show(
        t,
        h,
        direct: true,
        seed: const DoctorProgressSeed.viewPatient(
          patientId: '11',
          patientName: 'Sample Patient',
          patientCode: 'P-11',
        ),
      );
      expect(_layout(t).canAdd, isFalse);
      expect(find.byKey(const Key('doctor_progress_add_tab')), findsNothing);
      expect(h.progressReads.length, 4);
      await _finish(t);
    },
  );
  for (final field in ['fl_flag', 'access_flag', 'exp_date']) {
    _case(
      'fresh $field access check blocks a retained confirmation before POST',
      (t) async {
        final h = DoctorProgressHarness();
        await _show(t, h);
        await _fill(t);
        await _tap(t, 'doctor_progress_submit');
        h.doctorData[field] =
            field == 'fl_flag'
                ? '1'
                : field == 'exp_date'
                ? '01-JAN-20'
                : '0';
        await _tap(t, 'doctor_progress_confirm_yes');
        expect(h.auth.stage, AuthStage.accountBlocked);
        expect(h.progressWrites, isEmpty);
        expect(find.byType(DoctorProgressScreen), findsNothing);
        await _finish(t);
      },
    );
  }
  for (final overlay in ['score', 'confirm', 'filter']) {
    _case(
      'background dismisses $overlay and resume reloads without submitting',
      (t) async {
        final h = DoctorProgressHarness();
        await _show(t, h);
        if (overlay == 'score') {
          await _tap(t, 'doctor_progress_add_tab');
          await _tap(t, 'doctor_progress_score');
        } else if (overlay == 'confirm') {
          await _fill(t);
          await _tap(t, 'doctor_progress_submit');
        } else {
          await _tap(t, 'doctor_progress_filter_toggle');
          await _tap(t, 'doctor_progress_filter_doctor');
        }
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byKey(const Key('doctor_progress_confirm')), findsNothing);
        expect(find.byKey(const Key('doctor_history_choices')), findsNothing);
        final reads = h.progressReads.length;
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpAndSettle();
        expect(h.progressReads.length, reads + 4);
        expect(h.progressWrites, isEmpty);
        await _finish(t);
      },
    );
  }
  _case('late read from before background cannot replace the fresh snapshot', (
    t,
  ) async {
    final h = DoctorProgressHarness();
    final gate = Completer<JsonMap>();
    h.transport.onGet =
        (uri) =>
            uri.path.endsWith('/getHealthProgress')
                ? gate.future
                : h.respondProgress(uri);
    await h.signIn();
    // A pending spinner is intentionally pumped without pumpAndSettle.
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(h.auth.dispose);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpWidget(
      MaterialApp(
        home: DoctorProgressScreen(
          auth: h.auth,
          repository: h.progress,
          seed: h.seed,
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('doctor_progress_loading')), findsOneWidget);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    h.progressRows = [];
    h.transport.onGet = h.respondProgress;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(_layout(t).rows, isEmpty);
    gate.complete({
      'count': 1,
      'items': [progressRow()],
    });
    await t.pumpAndSettle();
    expect(_layout(t).rows, isEmpty);
    expect(h.progressWrites, isEmpty);
    await _finish(t);
  });
  _case(
    'resume waits for an in-flight write, then reconciles without automatic retry',
    (t) async {
      final h = DoctorProgressHarness();
      await _show(t, h);
      await _fill(t);
      final gate = Completer<JsonMap>();
      h.transport.onBytes = (_) => gate.future;
      await _confirm(t, settle: false);
      expect(h.progressWrites.length, 1);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(h.progressWrites.length, 1);
      expect(find.byKey(const Key('doctor_progress_loading')), findsOneWidget);
      h.commitProgress(h.progressWrites.single);
      gate.complete({'string_out': 'Successfully Created'});
      await t.pumpAndSettle();
      expect(h.progressWrites.length, 1);
      expect(_layout(t).canAdd, isFalse);
      expect(
        find.byKey(const Key('doctor_progress_write_error')),
        findsNothing,
      );
      await _finish(t);
    },
  );
  _case(
    'logout removes confirmation and a late POST cannot show another patient result',
    (t) async {
      final h = DoctorProgressHarness();
      await _show(t, h);
      await _fill(t);
      final gate = Completer<JsonMap>();
      h.transport.onBytes = (_) => gate.future;
      await _confirm(t, settle: false);
      await h.auth.logout();
      await t.pumpAndSettle();
      expect(find.byType(DoctorProgressScreen), findsNothing);
      gate.complete({'string_out': 'Successfully Created'});
      await t.pumpAndSettle();
      expect(find.text('New Progress Added'), findsNothing);
      expect(h.progressWrites.length, 1);
      await _finish(t);
    },
  );
  _case('custom progress destination retains priority and all native extras', (
    t,
  ) async {
    final h = DoctorProgressHarness();
    DashboardRoute? captured;
    await _show(
      t,
      h,
      destinationBuilder: (context, route) {
        if (route.module != DashboardModule.doctorHealthProgress) return null;
        captured = route;
        return const Scaffold(body: Text('Custom Progress'));
      },
    );
    expect(find.text('Custom Progress'), findsOneWidget);
    expect(captured!.extras, {
      'P_NAME': 'Sample Patient',
      'P_CODE': 'P-11',
      'P_PH_ID': '11',
      'IS_RANKED': '0',
      'ADM_DATE': '24-OCT-26',
      'APPT_TIME': '09:00 AM',
      'PFN_NAME': 'Physiotherapy Service',
      'PFN_ID': '3',
      'DEPTS_NAME': 'Physiotherapy',
      'DEPTS_ID': '2',
      'CAT_ID': '4',
      'PRM_ID': '5',
      'PRD_ID': '6',
      'AD_ID': '41',
      'FROM_PSV': 'false',
    });
    expect(h.progressReads, isEmpty);
    expect(h.progressWrites, isEmpty);
    await _finish(t);
  });
  for (final spec in [
    (const Size(320, 568), 2.0),
    (const Size(568, 320), 1.6),
    (const Size(768, 1024), 1.4),
  ]) {
    _case(
      'table, filters, score dropdown and keyboard fit ${spec.$1}, text ${spec.$2}',
      (t) async {
        final h = DoctorProgressHarness();
        h.progressRows = List.generate(
          14,
          (i) => {
            ...progressRow(id: '$i', notes: 'Long examination detail ' * 9),
            'doc_name': 'Doctor with a very long name and qualification',
          },
        );
        await _show(t, h, direct: true, size: spec.$1, scale: spec.$2);
        await _tap(t, 'doctor_progress_filter_toggle');
        await _choose(t, 'service', 1);
        await _tap(t, 'doctor_progress_add_tab');
        await _choose(t, 'score', 9);
        expect(_layout(t).score, 10);
        t.view.viewInsets = const FakeViewPadding(bottom: 130);
        addTearDown(t.view.resetViewInsets);
        await t.enterText(
          find.byKey(const Key('doctor_progress_notes')),
          'Examination and follow up\nবাংলা নোট',
        );
        await t.pumpAndSettle();
        await t.testTextInput.receiveAction(TextInputAction.done);
        t.view.viewInsets = const FakeViewPadding();
        await t.pumpAndSettle();
        await _confirm(t, yes: false);
        expect(h.progressWrites, isEmpty);
        await _tap(t, 'doctor_progress_history_tab');
        h.progressRows = [];
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await t.pump();
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await t.pumpAndSettle();
        expect(find.byKey(const Key('doctor_progress_empty')), findsOneWidget);
        expect(t.takeException(), isNull);
        await _finish(t);
      },
    );
  }
}

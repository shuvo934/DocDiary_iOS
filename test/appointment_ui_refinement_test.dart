import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/doctor_appointment_models.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/native_appointment_calendar.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/native_appointment_timeline_card.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/native_doctor_appointment_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'doctor_appointment_test_support.dart';
import 'support.dart';

const _captureKey = Key('appointment_refine_capture');
Future<void> _fonts() async {
  for (final entry
      in <String, List<String>>{
        'Poppins': [
          'Poppins-Regular.ttf',
          'Poppins-SemiBold.ttf',
          'Poppins-Bold.ttf',
        ],
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
}

void _view(WidgetTester t) {
  t.view.physicalSize = const Size(393, 852);
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPadding);
}

Future<void> _capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_REFINE_CAPTURE_DIR'];
  if (dir == null) return;
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    final bitmap = await boundary.toImage(pixelRatio: 1),
        bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
    bitmap.dispose();
    final f = File('$dir/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

class _CalendarHarness {
  final selected = ValueNotifier(DateTime(2026, 10, 25));
  final enabled = ValueNotifier(true);
  final window = DoctorAppointmentWindow(DateTime(2026, 10, 25));
  final changes = <DateTime>[];
  void dispose() {
    selected.dispose();
    enabled.dispose();
  }

  Future<void> show(WidgetTester t) async {
    _view(t);
    addTearDown(dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: docDiaryTheme(),
        home: Scaffold(
          body: Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: enabled,
              builder:
                  (context, active, _) => ValueListenableBuilder<DateTime>(
                    valueListenable: selected,
                    builder:
                        (context, day, _) => NativeAppointmentCalendar(
                          window: window,
                          selected: day,
                          enabled: active,
                          onSelected: (date) {
                            changes.add(date);
                            selected.value = date;
                          },
                        ),
                  ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  ScrollPosition position(WidgetTester t) =>
      t
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const Key('doctor_appointment_calendar')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
}

Future<void> _done(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
  expect(t.takeException(), isNull);
}

void _captureCase(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (t) async {
    final old = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await body(t);
    } finally {
      debugDisableShadows = old;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_fonts);
  testWidgets(
    'native button visible outline is compact with spacing and full outer tap area',
    (t) async {
      _view(t);
      var calls = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: docDiaryTheme(),
          home: Scaffold(
            body: Center(
              child: AppointmentOutlineButton(
                key: const Key('compact'),
                label: 'Create Prescription',
                sdp: 1.3,
                onPressed: () => calls++,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final outline = find.descendant(
        of: find.byKey(const Key('compact')),
        matching: find.byType(OutlinedButton),
      );
      expect(t.getSize(outline).height, closeTo(20.5, .1));
      expect(
        t.getSize(find.byKey(const Key('compact'))).height,
        closeTo(32.5, .1),
      );
      expect(t.getSize(outline).width, inInclusiveRange(140, 149));
      final outer = t.getRect(find.byKey(const Key('compact')));
      await t.tapAt(Offset(outer.center.dx, outer.top + 2));
      await t.pumpAndSettle();
      expect(calls, 1);
      await t.tap(outline);
      await t.pumpAndSettle();
      expect(calls, 2);
      await _done(t);
    },
  );
  testWidgets('disabled compact button does not accept taps in its inset', (
    t,
  ) async {
    _view(t);
    var calls = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppointmentOutlineButton(
              key: const Key('compact'),
              label: 'AVAIL',
              sdp: 1.3,
              enabled: false,
              onPressed: () => calls++,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('compact')));
    await t.pump();
    expect(calls, 0);
    await _done(t);
  });
  testWidgets(
    'calendar uses five full-width compact-corner cells and bold native labels',
    (t) async {
      final h = _CalendarHarness();
      await h.show(t);
      final date = find.byKey(const Key('doctor_appointment_date_25-OCT-26'));
      expect(t.getSize(date).width, closeTo(393 / 5, .1));
      expect(t.getSize(date).height, closeTo(56, .1));
      final material = t.widget<Material>(
        find.ancestor(of: date, matching: find.byType(Material)).first,
      );
      expect(material.borderRadius, BorderRadius.circular(8));
      for (final text in t.widgetList<Text>(
        find.descendant(of: date, matching: find.byType(Text)),
      )) {
        expect(text.style!.fontWeight, FontWeight.w700);
      }
      await _done(t);
    },
  );
  testWidgets(
    'adjacent date tap animates through intermediate offsets and commits once at the end',
    (t) async {
      final h = _CalendarHarness();
      await h.show(t);
      final before = h.position(t).pixels;
      await t.tap(find.byKey(const Key('doctor_appointment_date_26-OCT-26')));
      await t.pump();
      expect(h.changes, isEmpty);
      expect(h.position(t).pixels, closeTo(before, .1));
      await t.pump(const Duration(milliseconds: 100));
      expect(h.position(t).pixels, greaterThan(before));
      expect(h.position(t).pixels, lessThan(before + 393 / 5));
      expect(h.changes, isEmpty);
      await t.pumpAndSettle();
      expect(h.changes, [DateTime(2026, 10, 26)]);
      expect(h.position(t).pixels, closeTo(before + 393 / 5, .1));
      await _done(t);
    },
  );
  testWidgets('a second date tap supersedes the first unfinished animation', (
    t,
  ) async {
    final h = _CalendarHarness();
    await h.show(t);
    await t.tap(find.byKey(const Key('doctor_appointment_date_26-OCT-26')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    await t.tapAt(
      t.getCenter(find.byKey(const Key('doctor_appointment_date_24-OCT-26'))),
    );
    await t.pumpAndSettle();
    expect(h.changes, [DateTime(2026, 10, 24)]);
    await _done(t);
  });
  testWidgets(
    'a finger drag supersedes an unfinished tap, then settles one centered date',
    (t) async {
      final h = _CalendarHarness();
      await h.show(t);
      await t.tap(find.byKey(const Key('doctor_appointment_date_26-OCT-26')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      await t.timedDrag(
        find.byKey(const Key('doctor_appointment_calendar')),
        const Offset(190, 0),
        const Duration(milliseconds: 350),
      );
      await t.pumpAndSettle();
      expect(h.changes.length, 1);
      expect(h.changes.single.isBefore(DateTime(2026, 10, 25)), isTrue);
      expect(
        h.position(t).pixels,
        closeTo(h.window.indexOf(h.selected.value) * 393 / 5, .1),
      );
      await _done(t);
    },
  );
  testWidgets(
    'disabling during motion cancels the queued date and re-enabling recenters safely',
    (t) async {
      final h = _CalendarHarness();
      await h.show(t);
      await t.tap(find.byKey(const Key('doctor_appointment_date_26-OCT-26')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 70));
      h.enabled.value = false;
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(h.changes, isEmpty);
      h.enabled.value = true;
      await t.pumpAndSettle();
      expect(h.changes, isEmpty);
      expect(
        h.position(t).pixels,
        closeTo(h.window.indexOf(DateTime(2026, 10, 25)) * 393 / 5, .1),
      );
      await _done(t);
    },
  );
  testWidgets(
    'external month/date change animates without another selection callback',
    (t) async {
      final h = _CalendarHarness();
      await h.show(t);
      final start = h.position(t).pixels;
      h.selected.value = DateTime(2026, 11, 25);
      await t.pump();
      await t
          .pump(); // Start the ticker queued by the rebuild's post-frame callback.
      await t.pump(const Duration(milliseconds: 100));
      expect(h.position(t).pixels, greaterThan(start));
      expect(
        h.position(t).pixels,
        lessThan(h.window.indexOf(h.window.last) * 393 / 5),
      );
      await t.pumpAndSettle();
      expect(h.changes, isEmpty);
      expect(
        h.position(t).pixels,
        closeTo(h.window.indexOf(h.window.last) * 393 / 5, .1),
      );
      await _done(t);
    },
  );
  testWidgets(
    'selected-date tap and disposal during animation produce no late callback',
    (t) async {
      final h = _CalendarHarness();
      await h.show(t);
      await t.tap(find.byKey(const Key('doctor_appointment_date_25-OCT-26')));
      await t.pumpAndSettle();
      expect(h.changes, isEmpty);
      await t.tap(find.byKey(const Key('doctor_appointment_date_26-OCT-26')));
      await t.pump();
      await _done(t);
      await t.pump(const Duration(milliseconds: 400));
      expect(h.changes, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
  _captureCase(
    'reference portrait preserves elevations and matches compact native controls',
    (t) async {
      _view(t);
      final now = DateTime(2026, 10, 25, 11, 33),
          window = DoctorAppointmentWindow(DateTime(2026, 10, 25));
      final flags = DoctorAppointmentFeatures(
        AccountProfile(AccountRole.doctor, {
          ...doctorProfile(),
          'can_prescribe': '0',
          'is_need_avail': '1',
          'pat_app_history': '1',
        }),
      );
      final rows = [
        DoctorAppointmentRow({
          ...doctorAppointmentRow(
            day: '25-OCT-26',
            time: '09:00 AM',
            name: 'Example Patient A',
          ),
          'pat_code': 'P-000005',
          'pat_age_now': '5 Years 11 Months 3 Days',
          'pfn_fee_name': 'Physiotherapy Service Charge',
        }, selectedDate: window.anchor),
        DoctorAppointmentRow(
          doctorAppointmentRow(day: '25-OCT-26', time: '09:30 AM', patient: ''),
          selectedDate: window.anchor,
        ),
        DoctorAppointmentRow({
          ...doctorAppointmentRow(
            day: '25-OCT-26',
            time: '10:00 AM',
            name: 'Example Patient B',
          ),
          'pat_code': 'P-000009',
          'pat_gender': 'Male',
          'pat_age_now': '17 Years 8 Months 6 Days',
          'pfn_fee_name': 'Physiotherapy Service Charge',
          'pph_progress': '3',
          'pmm': '1',
        }, selectedDate: window.anchor),
      ];
      await t.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: docDiaryTheme(),
            home: NativeDoctorAppointmentLayout(
              window: window,
              selected: window.anchor,
              now: now,
              features: flags,
              rows: rows,
              onBack: () {},
              onSelected: (_) {},
              onMonth: (_) {},
              onAction: (_, __) {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t.getSize(find.byKey(const Key('doctor_appointment_previous'))),
        const Size(48, 25),
      );
      expect(
        t.getTopLeft(find.byKey(const Key('doctor_appointment_previous'))).dx,
        closeTo(21.8, .1),
      );
      final button = find.descendant(
        of: find.byKey(const Key('doctor_appointment_0_avail')),
        matching: find.byType(OutlinedButton),
      );
      expect(t.getSize(button), const Size(65, 20.5));
      expect(
        t
            .widget<Card>(find.byKey(const Key('doctor_appointment_card_0')))
            .elevation,
        3,
      );
      expect(
        t
            .widget<Card>(find.byKey(const Key('doctor_appointment_card_1')))
            .elevation,
        1,
      );
      await _capture(t, 'appointment_ui_compact_reference');
      await _done(t);
    },
  );
}

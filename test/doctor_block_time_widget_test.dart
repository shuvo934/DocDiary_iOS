import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/login_screen.dart';
import 'package:docdiary_ios/features/block_time/doctor_block_time_models.dart';
import 'package:docdiary_ios/features/block_time/doctor_block_time_repository.dart';
import 'package:docdiary_ios/features/block_time/doctor_block_time_screen.dart';
import 'package:docdiary_ios/features/block_time/native_doctor_block_time_layout.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/native_dashboard_icons.dart';
import 'package:docdiary_ios/features/dashboard/native_dashboard_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'block_time_support.dart';
import 'support.dart';

void _pause(WidgetTester t) {
  if (t.binding.lifecycleState == AppLifecycleState.resumed) {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  if (t.binding.lifecycleState == AppLifecycleState.inactive) {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

void _resume(WidgetTester t) {
  if (t.binding.lifecycleState == AppLifecycleState.paused) {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }
  if (t.binding.lifecycleState == AppLifecycleState.hidden) {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

Iterable<RequestRecord> _reads(Harness h) => h.transport.requests.where(
  (r) => r.uri.path.endsWith('/leave_schedule/getTimeSchedule'),
);
String _cell(String date, {String month = '2026-10-01'}) =>
    'block_time_cell_${month}_$date';
Future<void> _show(WidgetTester t, Harness h, {bool settle = true}) async {
  t.view.physicalSize = const Size(393, 852);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  _resume(t);
  await h.signIn();
  await t.pumpWidget(
    RepaintBoundary(
      key: const Key('block_time_capture'),
      child: DocDiaryApp(
        auth: h.auth,
        initializeOnStart: false,
        dashboard: DashboardRepository(h.transport, now: () => h.now),
      ),
    ),
  );
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('dashboard_nav_leave')));
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _tap(WidgetTester t, String key) async {
  final target = find.byKey(Key(key));
  // Default ensureVisible would align a visible day within its PageView and
  // accidentally change months. Scroll only when the target is off-screen.
  if (target.hitTestable().evaluate().isEmpty) {
    await Scrollable.ensureVisible(
      t.element(target),
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
    await t.pumpAndSettle();
  }
  await t.tap(target);
  await t.pumpAndSettle();
}

Future<void> _closeSheet(WidgetTester t) async {
  await t.tapAt(const Offset(5, 120));
  await t.pumpAndSettle();
}

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
  expect(t.takeException(), isNull);
}

Future<void> _capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_BLOCK_CAPTURE_DIR'];
  if (dir == null) {
    return;
  }
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('block_time_capture')),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1),
        bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('$dir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final e
        in {
          'Poppins': [
            'Poppins-Regular.ttf',
            'Poppins-Medium.ttf',
            'Poppins-Bold.ttf',
          ],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
          'Ubuntu': ['Ubuntu-Medium.ttf'],
        }.entries) {
      final loader = FontLoader(e.key);
      for (final font in e.value) {
        loader.addFont(rootBundle.load('assets/fonts/$font'));
      }
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets(
    'Dashboard opens Block Time; Back refreshes without a login write',
    (t) async {
      final h = blockTimeHarness();
      await _show(t, h);
      expect(find.byType(DoctorBlockTimeScreen), findsOneWidget);
      expect(find.text('Block Time (Schedule)'), findsOneWidget);
      expect(find.text('OCTOBER  2026'), findsOneWidget);
      expect(_reads(h).length, 1);
      final semantics = t.ensureSemantics();
      expect(
        t.getSemantics(find.byKey(Key(_cell('2026-10-21')))).label,
        contains('Blocked Schedule'),
      );
      semantics.dispose();
      final posts = h.posts.length;
      await _tap(t, 'block_time_back');
      expect(find.byType(DoctorBlockTimeScreen), findsNothing);
      expect(find.byType(NativeDashboardLayout), findsOneWidget);
      expect(h.posts.length, posts);
      await _finish(t);
    },
  );
  testWidgets(
    'partial date shows native heading, weekday and ordered original times',
    (t) async {
      final h = blockTimeHarness();
      await _show(t, h);
      await _tap(t, _cell('2026-10-21'));
      expect(find.text('Blocked Schedule'), findsOneWidget);
      expect(find.text('21 October, 2026'), findsOneWidget);
      expect(find.text('Wednesday'), findsOneWidget);
      expect(find.text('09:00 AM - 10:00 AM'), findsOneWidget);
      expect(find.text('11:00 AM - 12:00 PM'), findsOneWidget);
      expect(find.text('All Schedule Blocked'), findsNothing);
      await _capture(t, 'block_time_partial_sheet');
      await _closeSheet(t);
      expect(find.byKey(const Key('block_time_sheet')), findsNothing);
      expect(_reads(h).length, 1);
      await _capture(t, 'block_time_calendar');
      await _finish(t);
    },
  );
  testWidgets(
    'all-blocked date shows red icon and message, without individual times',
    (t) async {
      final h = blockTimeHarness();
      await _show(t, h);
      expect(
        t
            .widget<NativeDashboardIcon>(
              find.byKey(const Key('block_time_icon_2026-10-01_2026-10-22')),
            )
            .color,
        const Color(0xFFCC0000),
      );
      await _tap(t, _cell('2026-10-22'));
      expect(find.text('All Schedule Blocked'), findsOneWidget);
      expect(find.text('Thursday'), findsOneWidget);
      expect(find.byKey(const Key('block_time_slot_0')), findsNothing);
      expect(find.text('Full Day Off'), findsNothing);
      await _capture(t, 'block_time_all_blocked_sheet');
      await _finish(t);
    },
  );
  testWidgets(
    'unblocked tap does nothing; native Friday, today and event colours take precedence',
    (t) async {
      final h = blockTimeHarness();
      await _show(t, h);
      Color? color(String d) =>
          t
              .widget<Text>(find.byKey(Key('block_time_label_2026-10-01_$d')))
              .style!
              .color;
      expect(color('2026-10-16'), const Color(0xFFC23616));
      expect(color('2026-10-19'), DocColors.primary);
      expect(color('2026-10-23'), const Color(0xFFFDA000));
      expect(color('2026-10-20'), DocColors.muted);
      expect(
        t
            .widget<NativeDashboardIcon>(
              find.byKey(const Key('block_time_icon_2026-10-01_2026-10-21')),
            )
            .color,
        const Color(0xFF1DD1A1),
      );
      await _tap(t, _cell('2026-10-20'));
      expect(find.byKey(const Key('block_time_sheet')), findsNothing);
      await _finish(t);
    },
  );
  testWidgets(
    'arrows and swipe are bounded to three months without extra requests',
    (t) async {
      final h = blockTimeHarness();
      await _show(t, h);
      await _tap(t, 'block_time_previous');
      expect(find.text('OCTOBER  2026'), findsOneWidget);
      await _tap(t, 'block_time_next');
      expect(find.text('NOVEMBER  2026'), findsOneWidget);
      await t.drag(
        find.byKey(const Key('block_time_pages')),
        const Offset(-350, 0),
      );
      await t.pumpAndSettle();
      expect(find.text('DECEMBER  2026'), findsOneWidget);
      await _tap(t, 'block_time_next');
      expect(find.text('DECEMBER  2026'), findsOneWidget);
      await _tap(t, _cell('2026-12-31', month: '2026-12-01'));
      expect(find.text('31 December, 2026'), findsOneWidget);
      await _closeSheet(t);
      await t.drag(
        find.byKey(const Key('block_time_pages')),
        const Offset(350, 0),
      );
      await t.pumpAndSettle();
      expect(find.text('NOVEMBER  2026'), findsOneWidget);
      expect(_reads(h).length, 1);
      await _finish(t);
    },
  );
  testWidgets(
    'muted adjacent-month blocked dates within range still open, as native does',
    (t) async {
      final h = blockTimeHarness();
      await _show(t, h);
      await _tap(t, _cell('2026-11-01'));
      expect(find.text('01 November, 2026'), findsOneWidget);
      expect(find.text('Sunday'), findsOneWidget);
      await _finish(t);
    },
  );
  testWidgets('count zero is a usable empty calendar', (t) async {
    final h = blockTimeHarness();
    h.transport.onGet =
        (u) async =>
            u.path.endsWith('getTimeSchedule')
                ? {'count': '0', 'items': null}
                : await h.defaultGet(u);
    await _show(t, h);
    expect(find.byKey(const Key('block_time_error')), findsNothing);
    expect(find.byKey(const Key('block_time_loading')), findsNothing);
    await _tap(t, _cell('2026-10-21'));
    expect(find.byKey(const Key('block_time_sheet')), findsNothing);
    await _tap(t, 'block_time_next');
    expect(find.text('NOVEMBER  2026'), findsOneWidget);
    await _finish(t);
  });
  testWidgets(
    'Error is noncancelable and Retry is explicit, retaining detail without login writes',
    (t) async {
      final h = blockTimeHarness();
      var failed = false;
      h.transport.onGet = (u) async {
        if (u.path.endsWith('getTimeSchedule')) {
          if (!failed) {
            failed = true;
            throw const AppFailure('Synthetic blocked schedule failure');
          }
          return {
            'count': 1,
            'items': [blockedSlot()],
          };
        }
        return await h.defaultGet(u);
      };
      await _show(t, h);
      expect(
        find.text(
          'Error Message: Synthetic blocked schedule failure.\nPlease try again.',
        ),
        findsOneWidget,
      );
      await t.tapAt(const Offset(3, 100));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('block_time_error')), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byKey(const Key('block_time_error')), findsOneWidget);
      final posts = h.posts.length;
      await _tap(t, 'block_time_error_retry');
      expect(find.byKey(const Key('block_time_error')), findsNothing);
      expect(_reads(h).length, 2);
      expect(h.posts.length, posts);
      await _tap(t, _cell('2026-10-21'));
      expect(find.text('09:00 AM - 10:00 AM'), findsOneWidget);
      await _finish(t);
    },
  );
  testWidgets(
    'malformed response has Retry/Exit and Exit returns to Dashboard',
    (t) async {
      final h = blockTimeHarness();
      h.transport.onGet =
          (u) async =>
              u.path.endsWith('getTimeSchedule')
                  ? {
                    'count': 1,
                    'items': [<String, Object?>{}],
                  }
                  : await h.defaultGet(u);
      await _show(t, h);
      expect(find.byKey(const Key('block_time_error')), findsOneWidget);
      await _tap(t, 'block_time_error_exit');
      expect(find.byType(DoctorBlockTimeScreen), findsNothing);
      expect(find.byType(NativeDashboardLayout), findsOneWidget);
      await _finish(t);
    },
  );
  testWidgets('loading prevents Back; logout discards a late response', (
    t,
  ) async {
    final h = blockTimeHarness(), pending = Completer<JsonMap>();
    h.transport.onGet =
        (u) =>
            u.path.endsWith('getTimeSchedule')
                ? pending.future
                : h.defaultGet(u);
    await _show(t, h, settle: false);
    expect(find.byKey(const Key('block_time_loading')), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pump();
    expect(find.byType(DoctorBlockTimeScreen), findsOneWidget);
    await h.auth.logout();
    await t.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    pending.complete({
      'count': 1,
      'items': [blockedSlot()],
    });
    await t.pumpAndSettle();
    expect(find.byType(DoctorBlockTimeScreen), findsNothing);
    expect(find.byKey(const Key('block_time_error')), findsNothing);
    await _finish(t);
  });
  testWidgets('logout closes owned sheet above the old route', (t) async {
    final h = blockTimeHarness();
    await _show(t, h);
    await _tap(t, _cell('2026-10-21'));
    await h.auth.logout();
    await t.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byKey(const Key('block_time_sheet')), findsNothing);
    await _finish(t);
  });
  testWidgets('logout cannot leave stale Error/Retry above Login', (t) async {
    final h = blockTimeHarness();
    h.transport.onGet =
        (u) async =>
            u.path.endsWith('getTimeSchedule')
                ? throw const AppFailure('Synthetic failure')
                : await h.defaultGet(u);
    await _show(t, h);
    await h.auth.logout();
    await t.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byKey(const Key('block_time_error_retry')), findsNothing);
    await _finish(t);
  });
  testWidgets('resume closes old sheet and refreshes without loginLog', (
    t,
  ) async {
    final h = blockTimeHarness();
    await _show(t, h);
    await _tap(t, _cell('2026-10-21'));
    final posts = h.posts.length;
    _pause(t);
    await t.pumpAndSettle();
    h.transport.onGet =
        (u) async =>
            u.path.endsWith('getTimeSchedule')
                ? {
                  'count': 1,
                  'items': [blockedSlot(time: 'Updated blocked time')],
                }
                : await h.defaultGet(u);
    _resume(t);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('block_time_sheet')), findsNothing);
    expect(_reads(h).length, 2);
    expect(h.posts.length, posts);
    await _tap(t, _cell('2026-10-21'));
    expect(find.text('Updated blocked time'), findsOneWidget);
    await _finish(t);
  });
  for (final e
      in {
        'fl_flag': 'Forced Log Out!',
        'access_flag': 'Access Denied!',
        'exp_date': 'Access Expired!',
      }.entries) {
    testWidgets('resume rechecks ${e.key} before another schedule request', (
      t,
    ) async {
      final h = blockTimeHarness();
      await _show(t, h);
      await _tap(t, _cell('2026-10-21'));
      final reads = _reads(h).length;
      _pause(t);
      h.doctorData[e.key] =
          e.key == 'exp_date'
              ? '18-OCT-26'
              : e.key == 'fl_flag'
              ? '1'
              : '0';
      _resume(t);
      await t.pumpAndSettle();
      expect(find.text(e.value), findsOneWidget);
      expect(_reads(h).length, reads);
      expect(find.byKey(const Key('block_time_sheet')), findsNothing);
      expect(find.byType(DoctorBlockTimeScreen), findsNothing);
      await _finish(t);
    });
  }
  testWidgets(
    'late background failure cannot replace a newer successful calendar',
    (t) async {
      final h = blockTimeHarness();
      await _show(t, h);
      final old = Completer<JsonMap>();
      var loads = 0;
      h.transport.onGet = (u) async {
        if (u.path.endsWith('getTimeSchedule')) {
          if (loads++ == 0) {
            return await old.future;
          }
          return {
            'count': 1,
            'items': [blockedSlot(time: 'Fresh response')],
          };
        }
        return await h.defaultGet(u);
      };
      _pause(t);
      _resume(t);
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('block_time_loading')), findsOneWidget);
      _pause(t);
      _resume(t);
      await t.pumpAndSettle();
      old.completeError(const AppFailure('Obsolete failure'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('block_time_error')), findsNothing);
      await _tap(t, _cell('2026-10-21'));
      expect(find.text('Fresh response'), findsOneWidget);
      await _finish(t);
    },
  );
  testWidgets(
    'month rollover refreshes complete month range and keeps the visible month',
    (t) async {
      final h = blockTimeHarness(clock: DateTime(2026, 10, 31, 23, 59));
      await _show(t, h);
      await _tap(t, 'block_time_next');
      _pause(t);
      h.now = DateTime(2026, 11, 1);
      _resume(t);
      await t.pumpAndSettle();
      expect(find.text('NOVEMBER  2026'), findsOneWidget);
      expect(_reads(h).last.uri.queryParameters, {
        'doc_id': '10',
        'FIRST_MONTH': 'NOV-26',
        'LAST_MONTH': 'JAN-27',
      });
      await _tap(t, 'block_time_previous');
      expect(find.text('NOVEMBER  2026'), findsOneWidget);
      await _finish(t);
    },
  );
  testWidgets(
    'small screen, landscape, large text and long time list remain scrollable without overflow',
    (t) async {
      final h = blockTimeHarness();
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      h.transport.onGet =
          (u) async =>
              u.path.endsWith('getTimeSchedule')
                  ? {
                    'count': 25,
                    'items': List.generate(
                      25,
                      (i) => blockedSlot(
                        time:
                            'Long blocked schedule number ${i + 1} with original text retained',
                        total: '26',
                      ),
                    ),
                  }
                  : await h.defaultGet(u);
      await _show(t, h);
      for (final e in [
        (const Size(320, 568), 2.0),
        (const Size(740, 360), 1.6),
      ]) {
        t.view.physicalSize = e.$1;
        t.platformDispatcher.textScaleFactorTestValue = e.$2;
        await t.pumpAndSettle();
        await _tap(t, _cell('2026-10-21'));
        await t.ensureVisible(find.byKey(const Key('block_time_slot_24')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        Navigator.of(
          t.element(find.byKey(const Key('block_time_sheet'))),
        ).pop();
        await t.pumpAndSettle();
      }
      t.platformDispatcher.clearTextScaleFactorTestValue();
      await _finish(t);
    },
  );
  testWidgets(
    'retained inactive Full Day Off branch does not invent blocked slots',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: docDiaryTheme(),
          home: Scaffold(
            body: NativeDoctorBlockTimeSheet(
              day: DoctorBlockedDay(
                date: DateTime(2026, 10, 21),
                slots: [],
                fullDay: true,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Leave Day'), findsOneWidget);
      expect(find.text('Full Day Off'), findsOneWidget);
      expect(find.text('All Schedule Blocked'), findsNothing);
      await _finish(t);
    },
  );
  testWidgets(
    'missing doctor/session offers a safe return without any request',
    (t) async {
      final h = blockTimeHarness();
      addTearDown(h.auth.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: docDiaryTheme(),
          home: DoctorBlockTimeScreen(
            auth: h.auth,
            repository: DoctorBlockTimeRepository(h.transport),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.text('Could Not Get Doctor Data. Please return to Login.'),
        findsOneWidget,
      );
      expect(h.transport.requests, isEmpty);
      await _finish(t);
    },
  );
}

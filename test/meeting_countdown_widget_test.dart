import 'dart:async';

import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_dates.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/native_dashboard_layout.dart';
import 'package:docdiary_ios/features/dashboard/native_meeting_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

String _timestamp(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}-${two(date.month)}-${date.year} '
      '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
}

JsonMap _meeting(
  DateTime next, {
  DateTime? last,
  String patient = 'Example Patient',
}) => {
  'items': [
    {
      'last_sc': last == null ? '' : _timestamp(last),
      'next_sc': _timestamp(next),
      'pat_name': patient,
    },
  ],
};

int _reads(Harness h) =>
    h.transport.requests
        .where((request) => request.uri.path.endsWith('getMeetingSchedule'))
        .length;

void _serve(Harness h, JsonMap response) {
  h.transport.onGet = (uri) async {
    if (uri.path.endsWith('getMeetingSchedule')) {
      return response;
    }
    return h.defaultGet(uri);
  };
}

Future<void> _show(WidgetTester tester, Harness h) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(
    DocDiaryApp(
      auth: h.auth,
      dashboard: DashboardRepository(h.transport, now: () => h.now),
      initializeOnStart: false,
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

// Advance the injected wall clock together with Flutter's fake timer clock.
Future<void> _advance(WidgetTester tester, Harness h, Duration duration) async {
  var left = duration;
  while (left > Duration.zero) {
    final step =
        left > const Duration(seconds: 1) ? const Duration(seconds: 1) : left;
    h.now = h.now.add(step);
    await tester.pump(step);
    await tester.pump();
    left -= step;
  }
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
    'live seconds and native unit visibility update with a right-anchored fill',
    (tester) async {
      final h = Harness();
      await h.signIn();
      _serve(
        h,
        _meeting(
          h.now.add(const Duration(minutes: 1)),
          last: h.now.subtract(const Duration(minutes: 1)),
        ),
      );
      final writes = h.posts.length;
      await _show(tester, h);
      final progress = find.byKey(const Key('dashboard_meeting_progress'));
      expect(tester.widget<FractionallySizedBox>(progress).widthFactor, 0.5);
      final card = tester.getRect(
        find.byKey(const Key('dashboard_next_meeting')),
      );
      final fill = tester.getRect(
        find.descendant(of: progress, matching: find.byType(ColoredBox)),
      );
      expect(fill.right, closeTo(card.right, 0.01));
      expect(fill.width, closeTo(card.width / 2, 0.01));
      expect(find.byKey(const Key('dashboard_timer_hours')), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('dashboard_timer_minutes')))
            .data,
        '01',
      );
      await _advance(tester, h, const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('dashboard_timer_minutes')), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('dashboard_timer_seconds')))
            .data,
        '59',
      );
      expect(tester.widget<FractionallySizedBox>(progress).widthFactor, 0.49);
      expect(_reads(h), 1);
      expect(h.posts.length, writes);
      await _finish(tester);
    },
  );

  testWidgets(
    'a period request does not restart a meeting that has no last_sc',
    (tester) async {
      final h = Harness();
      await h.signIn();
      _serve(h, _meeting(h.now.add(const Duration(minutes: 1))));
      final writes = h.posts.length;
      await _show(tester, h);
      await _advance(tester, h, const Duration(seconds: 30));
      await tester.tap(find.byKey(const Key('dashboard_period_currentWeek')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FractionallySizedBox>(
              find.byKey(const Key('dashboard_meeting_progress')),
            )
            .widthFactor,
        0.5,
      );
      expect(
        tester
            .widget<NativeDashboardLayout>(find.byType(NativeDashboardLayout))
            .period,
        SummaryPeriod.currentWeek,
      );
      expect(_reads(h), 2);
      expect(h.posts.length, writes);
      await _finish(tester);
    },
  );

  testWidgets(
    'time-up shows native loading and refreshes Today after three seconds',
    (tester) async {
      final h = Harness();
      await h.signIn();
      final initial = _meeting(
        h.now.add(const Duration(seconds: 2)),
        last: h.now.subtract(const Duration(seconds: 58)),
      );
      var reads = 0;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getMeetingSchedule')) {
          reads++;
          return reads <= 2 ? initial : {'items': <Object?>[]};
        }
        return h.defaultGet(uri);
      };
      final writes = h.posts.length;
      await _show(tester, h);
      await tester.tap(find.byKey(const Key('dashboard_period_currentWeek')));
      await tester.pumpAndSettle();
      await _advance(tester, h, const Duration(seconds: 2));
      expect(
        find.byKey(const Key('dashboard_meeting_refreshing')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('dashboard_bottom_menu')), findsNothing);
      expect(reads, 2);
      await _advance(tester, h, const Duration(seconds: 2));
      expect(reads, 2);
      await _advance(tester, h, const Duration(seconds: 1));
      expect(reads, 3);
      expect(find.text('No Upcoming Meeting Available'), findsOneWidget);
      expect(
        find.byKey(const Key('dashboard_meeting_countdown')),
        findsNothing,
      );
      expect(
        tester
            .widget<NativeDashboardLayout>(find.byType(NativeDashboardLayout))
            .period,
        SummaryPeriod.today,
      );
      final query =
          h.transport.requests
              .lastWhere(
                (request) => request.uri.path.endsWith('getMeetingCount'),
              )
              .uri
              .queryParameters;
      expect(query['first_date'], '15-OCT-26');
      expect(query['end_date'], '15-OCT-26');
      expect(h.posts.length, writes);
      await _finish(tester);
    },
  );

  testWidgets(
    'background cancels a pending expiry; resume reloads using the current clock',
    (tester) async {
      final h = Harness();
      await h.signIn();
      var reads = 0;
      final initial = _meeting(h.now.add(const Duration(seconds: 2)));
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getMeetingSchedule')) {
          reads++;
          return reads == 1
              ? initial
              : _meeting(h.now.add(const Duration(minutes: 1)));
        }
        return h.defaultGet(uri);
      };
      final writes = h.posts.length;
      await _show(tester, h);
      await _advance(tester, h, const Duration(seconds: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await _advance(tester, h, const Duration(seconds: 70));
      expect(reads, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(reads, 2);
      final query =
          h.transport.requests
              .lastWhere(
                (request) => request.uri.path.endsWith('getMeetingSchedule'),
              )
              .uri
              .queryParameters;
      expect(query['time_now'], nativeClockRequest(h.now));
      expect(
        find.byKey(const Key('dashboard_meeting_countdown')),
        findsOneWidget,
      );
      expect(h.posts.length, writes);
      await _finish(tester);
    },
  );

  testWidgets(
    'expiry queues one Today request behind an in-flight tab request',
    (tester) async {
      final h = Harness();
      await h.signIn();
      final pending = Completer<JsonMap>();
      final initial = _meeting(h.now.add(const Duration(seconds: 2)));
      var reads = 0;
      var active = 0;
      var maximumActive = 0;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getMeetingSchedule')) {
          reads++;
          active++;
          if (active > maximumActive) {
            maximumActive = active;
          }
          try {
            if (reads == 2) {
              return await pending.future;
            }
            return reads == 1 ? initial : {'items': <Object?>[]};
          } finally {
            active--;
          }
        }
        return h.defaultGet(uri);
      };
      final writes = h.posts.length;
      await _show(tester, h);
      await tester.tap(find.byKey(const Key('dashboard_period_currentWeek')));
      await tester.pump();
      await tester.pump();
      await _advance(tester, h, const Duration(seconds: 5));
      expect(reads, 2);
      pending.complete(_meeting(h.now.add(const Duration(minutes: 1))));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(maximumActive, 1);
      expect(
        tester
            .widget<NativeDashboardLayout>(find.byType(NativeDashboardLayout))
            .period,
        SummaryPeriod.today,
      );
      expect(h.posts.length, writes);
      await _finish(tester);
    },
  );

  testWidgets(
    'resume during a request drains one revalidation instead of losing it',
    (tester) async {
      final h = Harness();
      await h.signIn();
      final pending = Completer<JsonMap>();
      var reads = 0;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getMeetingSchedule')) {
          reads++;
          if (reads == 2) {
            return pending.future;
          }
          return _meeting(h.now.add(const Duration(hours: 1)));
        }
        return h.defaultGet(uri);
      };
      final writes = h.posts.length;
      await _show(tester, h);
      await tester.tap(find.byKey(const Key('dashboard_period_currentWeek')));
      await tester.pump();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await _advance(tester, h, const Duration(seconds: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(reads, 2);
      pending.complete(_meeting(h.now.add(const Duration(hours: 1))));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(
        tester
            .widget<NativeDashboardLayout>(find.byType(NativeDashboardLayout))
            .period,
        SummaryPeriod.today,
      );
      expect(h.posts.length, writes);
      await _finish(tester);
    },
  );

  testWidgets(
    'an expiry network error stops automatic retries and manual retry recovers',
    (tester) async {
      final h = Harness();
      await h.signIn();
      var reads = 0;
      final initial = _meeting(h.now.add(const Duration(seconds: 2)));
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getMeetingSchedule')) {
          reads++;
          if (reads == 2) {
            throw const AppFailure('Example schedule connection failure');
          }
          return reads == 1 ? initial : {'items': <Object?>[]};
        }
        return h.defaultGet(uri);
      };
      final writes = h.posts.length;
      await _show(tester, h);
      await _advance(tester, h, const Duration(seconds: 5));
      expect(
        find.textContaining('Example schedule connection failure'),
        findsOneWidget,
      );
      expect(find.text('No Upcoming Meeting Available'), findsNothing);
      await _advance(tester, h, const Duration(seconds: 20));
      expect(reads, 2);
      await tester.ensureVisible(
        find.byKey(const Key('dashboard_error_retry')),
      );
      await tester.tap(find.byKey(const Key('dashboard_error_retry')));
      await tester.pumpAndSettle();
      expect(reads, 3);
      expect(find.text('No Upcoming Meeting Available'), findsOneWidget);
      expect(h.posts.length, writes);
      await _finish(tester);
    },
  );

  testWidgets(
    'automatic refresh still enforces forced logout before summary reads',
    (tester) async {
      final h = Harness();
      await h.signIn();
      var flags = 0;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getDocFLFlag')) {
          flags++;
          return {
            'items': [
              {'fl_flag': flags == 1 ? '0' : '1'},
            ],
          };
        }
        if (uri.path.endsWith('getMeetingSchedule')) {
          return _meeting(h.now.add(const Duration(seconds: 2)));
        }
        return h.defaultGet(uri);
      };
      final writes = h.posts.length;
      await _show(tester, h);
      await _advance(tester, h, const Duration(seconds: 5));
      expect(h.auth.stage, AuthStage.accountBlocked);
      expect(find.text('Forced Log Out!'), findsOneWidget);
      expect(h.vault.clears, 0);
      await tester.tap(find.byKey(const Key('dashboard_message_ok')));
      await tester.pumpAndSettle();
      expect(h.auth.session, isNull);
      expect(h.vault.clears, 1);
      expect(_reads(h), 1);
      await _advance(tester, h, const Duration(seconds: 10));
      expect(flags, 2);
      expect(h.posts.length, writes);
      await _finish(tester);
    },
  );

  for (final action in ['logout', 'switch', 'dispose']) {
    testWidgets('$action cancels the old account expiry callback', (
      tester,
    ) async {
      final h = Harness();
      if (action == 'switch') {
        h.loginResponse = {
          ...doctorLogin(),
          'is_available': '3',
          'p_doc_list': [
            {'doc_code': 'D-10', 'doc_name': 'One'},
            {'doc_code': 'D-20', 'doc_name': 'Two'},
          ],
        };
      }
      await h.signIn();
      if (action == 'switch') {
        await h.auth.selectAccount(h.auth.selectedCenter!.accounts.first);
      }
      _serve(h, _meeting(h.now.add(const Duration(seconds: 2))));
      final writes = h.posts.length;
      await _show(tester, h);
      await _advance(tester, h, const Duration(seconds: 2));
      if (action == 'logout') {
        await h.auth.logout();
      } else if (action == 'switch') {
        h.auth.beginSwitch();
        expect(h.auth.stage, AuthStage.chooseAccount);
      } else {
        await tester.pumpWidget(const SizedBox.shrink());
      }
      await tester.pump();
      await _advance(tester, h, const Duration(seconds: 10));
      expect(_reads(h), 1);
      expect(h.posts.length, writes);
      await _finish(tester);
    });
  }

  testWidgets('no upcoming meeting performs no timer refreshes', (
    tester,
  ) async {
    final h = Harness();
    await h.signIn();
    await _show(tester, h);
    await _advance(tester, h, const Duration(seconds: 20));
    expect(find.text('No Upcoming Meeting Available'), findsOneWidget);
    expect(find.byKey(const Key('dashboard_meeting_countdown')), findsNothing);
    expect(_reads(h), 1);
    await _finish(tester);
  });

  testWidgets(
    'long patient names and multi-day timers fit small and large-text layouts',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 393.0]) {
        tester.view.physicalSize = Size(width, 852);
        await tester.pumpWidget(
          MaterialApp(
            theme: docDiaryTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 852),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: NativeMeetingPanel(
                    summary: DashboardSummary(
                      values: const {},
                      lastTime: '15-10-2026 12:30:00',
                      nextTime: '17-10-2026 14:30:00',
                      nextPatient: List.filled(
                        10,
                        'Example long patient name',
                      ).join(' '),
                    ),
                    now: DateTime(2026, 10, 15, 13, 30),
                    sdp: 1.3,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const Key('dashboard_timer_hours')))
              .data,
          '49',
        );
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
      await _finish(tester);
    },
  );
}

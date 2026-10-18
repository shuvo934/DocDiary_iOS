import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_dates.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/login_screen.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/native_dashboard_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Future<void> _show(
  WidgetTester tester,
  Harness h, {
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  for (final admin in [false, true]) {
    for (final days in [0, 3]) {
      testWidgets(
        '${admin ? 'admin' : 'doctor'} gets a $days-day warning once per dashboard entry',
        (tester) async {
          final h = Harness();
          if (admin) {
            h.loginResponse = adminLogin();
          }
          (admin ? h.adminData : h.doctorData)['exp_date'] = oracleDate(
            h.now.add(Duration(days: days)),
          );
          await h.signIn();
          final writes = h.posts.length;
          await _show(tester, h);
          expect(find.text('Access Expired Warning!'), findsOneWidget);
          expect(find.textContaining('($days day(s) left).'), findsOneWidget);
          await _tap(tester, 'dashboard_message_ok');
          await _tap(tester, 'dashboard_period_currentWeek');
          expect(find.text('Access Expired Warning!'), findsNothing);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
          expect(find.text('Access Expired Warning!'), findsNothing);
          expect(h.auth.stage, AuthStage.authenticated);
          expect(h.posts.length, writes);
          await _finish(tester);
        },
      );
    }

    testWidgets(
      '${admin ? 'admin' : 'doctor'} expired access has a blocking native dialog',
      (tester) async {
        final h = Harness();
        if (admin) {
          h.loginResponse = adminLogin();
        }
        (admin ? h.adminData : h.doctorData)['exp_date'] = oracleDate(
          h.now.subtract(const Duration(days: 1)),
        );
        await h.signIn();
        await _show(tester, h);
        expect(find.text('Access Expired!'), findsOneWidget);
        expect(
          find.textContaining(
            'To gain access to the app, Please contact with the administrator',
          ),
          findsOneWidget,
        );
        await tester.tapAt(const Offset(5, 5));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Access Expired!'), findsOneWidget);
        expect(find.byKey(const Key('dashboard_scroll')), findsNothing);
        expect(h.vault.clears, 0);
        await _tap(tester, 'dashboard_message_ok');
        expect(h.vault.clears, 1);
        expect(find.byType(LoginScreen), findsOneWidget);
        await _finish(tester);
      },
    );
  }

  testWidgets(
    'forced logout on cold restore keeps the saved session blocked until OK',
    (tester) async {
      final h = Harness();
      await h.signIn(remember: true);
      h.doctorData['fl_flag'] = '1';
      await h.auth.initialize();
      await _show(tester, h);
      expect(find.text('Forced Log Out!'), findsOneWidget);
      expect(
        find.textContaining('We are sorry for the disturbance.'),
        findsOneWidget,
      );
      expect(h.vault.state.session, isNotNull);
      expect(h.vault.clears, 0);
      await _tap(tester, 'dashboard_message_ok');
      expect(h.vault.state.session, isNull);
      expect(h.vault.state.remembered, isNotNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      await _finish(tester);
    },
  );

  testWidgets(
    'a queued warning cannot show stale expiry after background and revalidation',
    (tester) async {
      final h = Harness();
      h.doctorData['exp_date'] = oracleDate(h.now.add(const Duration(days: 3)));
      await h.signIn();
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // One frame starts loading; a post-frame warning is not pumped yet.
      await tester.pumpWidget(
        DocDiaryApp(
          auth: h.auth,
          dashboard: DashboardRepository(h.transport, now: () => h.now),
          initializeOnStart: false,
        ),
      );
      h.doctorData['exp_date'] = oracleDate(
        h.now.add(const Duration(days: 30)),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Access Expired Warning!'), findsNothing);
      expect(find.text('TOTAL SCHEDULE'), findsOneWidget);
      await _finish(tester);
    },
  );

  testWidgets(
    'profile read failure has three native actions and Retry stays read-only',
    (tester) async {
      final h = Harness();
      await h.signIn();
      var fail = true;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getDocData') && fail) {
          fail = false;
          throw const AppFailure('Example profile connection failure');
        }
        return h.defaultGet(uri);
      };
      final writes = h.posts.length;
      await _show(tester, h);
      expect(find.text('WARNING!'), findsOneWidget);
      for (final label in ['LOG OUT', 'EXIT', 'RETRY']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byKey(const Key('dashboard_scroll')), findsNothing);
      await _tap(tester, 'dashboard_error_retry');
      expect(find.text('TOTAL SCHEDULE'), findsOneWidget);
      expect(find.text('WARNING!'), findsNothing);
      expect(h.posts.length, writes);
      await _finish(tester);
    },
  );

  testWidgets(
    'repeated identical cold-restore errors still reopen the Retry dialog',
    (tester) async {
      final h = Harness();
      await h.signIn();
      var failures = 2;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getDocData') && failures > 0) {
          failures--;
          throw const AppFailure('Same temporary error');
        }
        return h.defaultGet(uri);
      };
      await h.auth.initialize();
      final resets =
          h.posts.where((p) => p.uri.path.endsWith('updateFLFlag')).length;
      await _show(tester, h);
      await _tap(tester, 'dashboard_error_retry');
      expect(find.byKey(const Key('dashboard_error_dialog')), findsOneWidget);
      expect(find.textContaining('Same temporary error'), findsOneWidget);
      await _tap(tester, 'dashboard_error_retry');
      expect(find.text('TOTAL SCHEDULE'), findsOneWidget);
      expect(
        h.posts.where((p) => p.uri.path.endsWith('updateFLFlag')).length,
        resets,
      );
      await _finish(tester);
    },
  );

  testWidgets(
    'error LOG OUT clears the session without opening another confirmation',
    (tester) async {
      final h = Harness();
      await h.signIn(remember: true);
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getDocFLFlag')) {
          throw const AppFailure('Example connection failure');
        }
        return h.defaultGet(uri);
      };
      await _show(tester, h);
      await _tap(tester, 'dashboard_error_logOut');
      expect(h.auth.session, isNull);
      expect(h.vault.state.remembered, isNotNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Do you want to log out?'), findsNothing);
      await _finish(tester);
    },
  );

  testWidgets(
    'iOS EXIT explains the Home gesture and retains the session without new requests',
    (tester) async {
      final h = Harness();
      await h.signIn();
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getDocFLFlag')) {
          throw const AppFailure('Example connection failure');
        }
        return h.defaultGet(uri);
      };
      await _show(tester, h);
      final requests = h.transport.requests.length;
      await _tap(tester, 'dashboard_error_exit');
      expect(find.text('Exit!'), findsOneWidget);
      expect(
        find.textContaining('Home gesture or Home button'),
        findsOneWidget,
      );
      expect(h.vault.clears, 0);
      await _tap(tester, 'dashboard_message_ok');
      expect(find.byKey(const Key('dashboard_error_dialog')), findsOneWidget);
      expect(h.transport.requests.length, requests);
      expect(h.auth.session, isNotNull);
      await _finish(tester);
    },
  );

  testWidgets(
    'a tab error has OK and retries its selected period without a login POST',
    (tester) async {
      final h = Harness();
      await h.signIn();
      await _show(tester, h);
      var fail = true;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getMeetingCount') && fail) {
          fail = false;
          throw const AppFailure('Example tab read failure');
        }
        return h.defaultGet(uri);
      };
      final writes = h.posts.length;
      await _tap(tester, 'dashboard_period_currentWeek');
      expect(find.text('Error!'), findsOneWidget);
      expect(find.text('LOG OUT'), findsNothing);
      await _tap(tester, 'dashboard_message_ok');
      await _tap(tester, 'dashboard_retry');
      final layout = tester.widget<NativeDashboardLayout>(
        find.byType(NativeDashboardLayout),
      );
      expect(layout.period, SummaryPeriod.currentWeek);
      expect(find.textContaining('Example tab read failure'), findsNothing);
      expect(h.posts.length, writes);
      await _finish(tester);
    },
  );

  testWidgets(
    'initial admin chart failure uses the full error handler and does not queue the second chart',
    (tester) async {
      final h = Harness();
      h.loginResponse = adminLogin();
      await h.signIn();
      var fail = true;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getPaymentDataMonthly') && fail) {
          fail = false;
          throw const AppFailure('Example initial chart failure');
        }
        return h.defaultGet(uri);
      };
      final writes = h.posts.length;
      await _show(tester, h);
      expect(find.text('WARNING!'), findsOneWidget);
      expect(
        h.transport.requests.where(
          (p) => p.uri.path.endsWith('getAppointDataMonthly'),
        ),
        isEmpty,
      );
      await _tap(tester, 'dashboard_error_retry');
      expect(find.text('OVERVIEW'), findsOneWidget);
      expect(
        h.transport.requests
            .where((p) => p.uri.path.endsWith('getAppointDataMonthly'))
            .length,
        1,
      );
      expect(h.posts.length, writes);
      await _finish(tester);
    },
  );

  testWidgets(
    'resume catches mobile-access revocation before reading protected summaries',
    (tester) async {
      final h = Harness();
      await h.signIn();
      await _show(tester, h);
      final reads =
          h.transport.requests
              .where((r) => r.uri.path.endsWith('getMeetingCount'))
              .length;
      h.doctorData['access_flag'] = '0';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Access Denied!'), findsOneWidget);
      expect(find.byKey(const Key('dashboard_scroll')), findsNothing);
      expect(
        h.transport.requests
            .where((r) => r.uri.path.endsWith('getMeetingCount'))
            .length,
        reads,
      );
      expect(h.vault.clears, 0);
      await _tap(tester, 'dashboard_message_ok');
      expect(h.vault.clears, 1);
      await _finish(tester);
    },
  );

  testWidgets(
    'the blocking error handler remains usable on small screens with large text',
    (tester) async {
      final h = Harness();
      await h.signIn();
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getDocData')) {
          throw const AppFailure('Example connection failure');
        }
        return h.defaultGet(uri);
      };
      await _show(tester, h, size: const Size(320, 640), textScale: 2);
      for (final key in [
        'dashboard_error_logOut',
        'dashboard_error_exit',
        'dashboard_error_retry',
      ]) {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await _finish(tester);
    },
  );
}

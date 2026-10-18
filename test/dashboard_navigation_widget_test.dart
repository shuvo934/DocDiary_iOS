import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/native_dates.dart';
import 'package:docdiary_ios/features/auth/login_screen.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_services.dart';
import 'package:docdiary_ios/features/dashboard/native_dashboard_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Future<void> _show(
  WidgetTester tester,
  Harness h,
  List<DashboardRoute> routes,
) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await h.signIn();
  await tester.pumpWidget(
    DocDiaryApp(
      auth: h.auth,
      dashboard: DashboardRepository(h.transport, now: () => h.now),
      initializeOnStart: false,
      dashboardServices: DashboardServices(
        destinationBuilder: (context, route) {
          routes.add(route);
          return Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('example_module_return'),
                onPressed: () => Navigator.pop(context),
                child: const Text('Return from example module'),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
    'destination return refreshes Today/current data without another login write',
    (tester) async {
      final h = Harness();
      final routes = <DashboardRoute>[];
      await _show(tester, h, routes);
      await tester.tap(find.byKey(const Key('dashboard_period_currentMonth')));
      await tester.pumpAndSettle();
      final posts = h.posts.length;
      await tester.tap(find.byKey(const Key('dashboard_nav_appointment')));
      await tester.pumpAndSettle();
      expect(routes.single.module, DashboardModule.doctorAppointments);
      final reads = h.transport.requests.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(h.transport.requests.length, reads);
      h.transport.onGet =
          (uri) async =>
              uri.path.endsWith('getScheduleCount')
                  ? {
                    'items': [
                      {'schedule': '20', 'block_schedule': '3'},
                    ],
                  }
                  : await h.defaultGet(uri);
      await tester.tap(find.byKey(const Key('example_module_return')));
      await tester.pumpAndSettle();
      final dashboard = tester.widget<NativeDashboardLayout>(
        find.byType(NativeDashboardLayout),
      );
      expect(dashboard.period, SummaryPeriod.today);
      expect(dashboard.summary!.values['TOTAL SCHEDULE'], '20');
      expect(h.posts.length, posts);
      await _finish(tester);
    },
  );

  testWidgets(
    'revocation while away blocks return before protected schedule reads',
    (tester) async {
      final h = Harness();
      final routes = <DashboardRoute>[];
      await _show(tester, h, routes);
      await tester.tap(find.byKey(const Key('dashboard_nav_appointment')));
      await tester.pumpAndSettle();
      h.doctorData['access_flag'] = '0';
      final scheduleReads =
          h.transport.requests
              .where((r) => r.uri.path.endsWith('getScheduleCount'))
              .length;
      await tester.tap(find.byKey(const Key('example_module_return')));
      await tester.pumpAndSettle();
      expect(find.text('Access Denied!'), findsOneWidget);
      expect(
        h.transport.requests
            .where((r) => r.uri.path.endsWith('getScheduleCount'))
            .length,
        scheduleReads,
      );
      await _finish(tester);
    },
  );

  testWidgets(
    'logout closes an owned destination and cannot re-open stale dashboard data',
    (tester) async {
      final h = Harness();
      final routes = <DashboardRoute>[];
      await _show(tester, h, routes);
      await tester.tap(find.byKey(const Key('dashboard_nav_appointment')));
      await tester.pumpAndSettle();
      final reads = h.transport.requests.length;
      await h.auth.logout();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byKey(const Key('example_module_return')), findsNothing);
      expect(h.transport.requests.length, reads);
      await _finish(tester);
    },
  );
}

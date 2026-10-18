import 'dart:async';

import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_dates.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/login_screen.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/native_dashboard_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Future<void> _show(WidgetTester tester, Harness h) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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

void main() {
  testWidgets(
    'doctor dashboard keeps native sections, manager actions and four icon destinations',
    (tester) async {
      final h = Harness();
      h.doctorData['doc_manager_flag'] = '1';
      h.doctorData['doc_deptd_head_flag'] = '1';
      await h.signIn();
      await _show(tester, h);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Dr. Example Therapist'), findsOneWidget);
      expect(find.text('(Example Rehabilitation Centre)'), findsOneWidget);
      expect(find.text('REPORT MANAGER'), findsOneWidget);
      expect(find.text('ALL APPOINTMENT'), findsOneWidget);
      expect(find.text('UNIT APPOINTMENT'), findsNothing);
      expect(find.text('No Upcoming Meeting Available'), findsOneWidget);
      expect(find.text('TOTAL SCHEDULE'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      for (final route in ['profile', 'appointment', 'leave', 'patients']) {
        expect(find.byKey(Key('dashboard_nav_$route')), findsOneWidget);
      }
      expect(find.byKey(const Key('dashboard_nav_payment')), findsNothing);
      expect(find.byKey(const Key('dashboard_change_photo')), findsNothing);
      final before = h.posts.length;
      await tester.tap(find.byKey(const Key('dashboard_nav_appointment')));
      await tester.pumpAndSettle();
      expect(
        find.text('This screen is not available in this development build.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(h.posts.length, before);
    },
  );

  testWidgets(
    'unit appointment is visible only for a department head without manager access',
    (tester) async {
      final h = Harness();
      h.doctorData['doc_deptd_head_flag'] = '1';
      h.doctorData['doc_manager_flag'] = '0';
      await h.signIn();
      await _show(tester, h);
      expect(find.text('UNIT APPOINTMENT'), findsOneWidget);
      expect(find.text('REPORT MANAGER'), findsNothing);
      expect(find.text('ALL APPOINTMENT'), findsNothing);
    },
  );

  testWidgets(
    'date tab changes the native query and date label without recording another login',
    (tester) async {
      final h = Harness();
      await h.signIn();
      await _show(tester, h);
      final writes = h.posts.length;
      expect(find.text('15 October, 26'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dashboard_period_currentWeek')));
      await tester.pumpAndSettle();
      final query =
          h.transport.requests
              .lastWhere((r) => r.uri.path.endsWith('getMeetingCount'))
              .uri
              .queryParameters;
      expect(query, {
        'doc_id': '10',
        'first_date': '10-OCT-26',
        'end_date': '16-OCT-26',
      });
      expect(find.text('10 October, 26  --  16 October, 26'), findsOneWidget);
      expect(h.posts.length, writes);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('admin dashboard shows exact currency values and its own menu', (
    tester,
  ) async {
    final h = Harness();
    h.loginResponse = adminLogin();
    h.adminData['all_access_flag'] = '1';
    h.adminData['hr_acc_active_flag'] = '1';
    await h.signIn();
    await _show(tester, h);
    expect(find.text('Example Admin'), findsOneWidget);
    expect(find.text('৳ 1,200.50'), findsOneWidget);
    expect(find.text('৳ 100.25'), findsOneWidget);
    expect(find.text('CANCELED'), findsOneWidget);
    expect(find.text('TOTAL SCHEDULE'), findsNothing);
    expect(find.byKey(const Key('dashboard_next_meeting')), findsNothing);
    expect(find.byKey(const Key('dashboard_change_photo')), findsOneWidget);
    for (final route in ['payment', 'appointment', 'patients', 'management']) {
      expect(find.byKey(Key('dashboard_nav_$route')), findsOneWidget);
    }
    expect(find.byKey(const Key('dashboard_nav_profile')), findsNothing);
    final picture = h.transport.requests.lastWhere(
      (r) => r.uri.path.endsWith('getAdminPic'),
    );
    expect(picture.uri.queryParameters, {'p_usr_id': '70'});
  });

  for (final access in ['2', '3']) {
    testWidgets(
      'admin access $access obeys payment and appointment visibility flags',
      (tester) async {
        final h = Harness();
        h.loginResponse = adminLogin();
        h.adminData.addAll({
          'all_access_flag': access,
          'hr_acc_active_flag': '1',
          'hr_payment_active': '0',
          'hr_appointment_active': '1',
          'acc_payment_active': '1',
          'acc_appointment_active': '0',
        });
        await h.signIn();
        await _show(tester, h);
        expect(
          find.byKey(const Key('dashboard_nav_payment')),
          access == '2' ? findsNothing : findsOneWidget,
        );
        expect(
          find.byKey(const Key('dashboard_nav_appointment')),
          access == '2' ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.byKey(const Key('dashboard_nav_management')));
        await tester.pumpAndSettle();
        expect(
          find.text(access == '2' ? 'HR & Reports' : 'Accounts & Reports'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'loading and failed summary reads do not display invented zero counts; retry recovers',
    (tester) async {
      final h = Harness();
      await h.signIn();
      final pending = Completer<JsonMap>();
      var first = true;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getDocFLFlag') && first) {
          first = false;
          return pending.future;
        }
        return h.defaultGet(uri);
      };
      await tester.pumpWidget(
        DocDiaryApp(
          auth: h.auth,
          dashboard: DashboardRepository(h.transport, now: () => h.now),
          initializeOnStart: false,
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('TOTAL SCHEDULE'), findsNothing);
      pending.completeError(const AppFailure('Example connection failure'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Example connection failure'), findsOneWidget);
      expect(find.text('WARNING!'), findsOneWidget);
      final writes = h.posts.length;
      await tester.tap(find.byKey(const Key('dashboard_error_retry')));
      await tester.pumpAndSettle();
      expect(find.text('TOTAL SCHEDULE'), findsOneWidget);
      expect(find.textContaining('Example connection failure'), findsNothing);
      expect(h.posts.length, writes);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'logout No keeps the session and Yes clears it and returns to the approved login',
    (tester) async {
      final h = Harness();
      await h.signIn();
      await _show(tester, h);
      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(h.auth.stage, AuthStage.authenticated);
      expect(h.vault.clears, 0);
      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(h.auth.session, isNull);
      expect(h.vault.clears, 1);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'phone, landscape and large text layouts can scroll without overflow',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final size in [
        const Size(320, 568),
        const Size(852, 393),
        const Size(393, 852),
      ]) {
        tester.view.physicalSize = size;
        for (final role in AccountRole.values) {
          final data =
              role == AccountRole.doctor ? doctorProfile() : adminProfile();
          data[role == AccountRole.doctor ? 'doc_name' : 'usr_fname'] =
              'Example person with a particularly long display name';
          data[role == AccountRole.doctor
                  ? 'doc_center_name'
                  : 'admin_center_name'] =
              'Example Rehabilitation Centre with a long branch name';
          data['doc_manager_flag'] = '1';
          await tester.pumpWidget(
            MaterialApp(
              theme: docDiaryTheme(),
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(1.6),
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                ),
                child: NativeDashboardLayout(
                  profile: AccountProfile(role, data),
                  summary: const DashboardSummary(
                    values: {
                      'TOTAL SCHEDULE': '12',
                      'BLOCKED SCHEDULE': '2',
                      'TOTAL': '8',
                      'COMPLETED': '4',
                      'REMAINING': '4',
                      'TOTAL APPOINTMENT': '248',
                      'CANCELED APPOINTMENT': '12',
                      'PAYMENT RECEIVED': '1234567.89',
                      'PAYMENT RETURNED': '1250.25',
                    },
                  ),
                  period: SummaryPeriod.currentWeek,
                  now: DateTime(2026, 10, 15),
                  loading: false,
                  showSwitch: true,
                  onSwitch: () {},
                  onLogout: () {},
                  onPeriod: (_) {},
                  onRefresh: () async {},
                  onDestination: (_) {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$size $role before scroll',
          );
          await tester.drag(
            find.byKey(const Key('dashboard_scroll')),
            const Offset(0, -700),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$size $role after scroll',
          );
          expect(
            find.byKey(const Key('dashboard_bottom_menu')),
            findsOneWidget,
          );
        }
      }
    },
  );
}

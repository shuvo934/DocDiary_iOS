import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/native_login_layout.dart';
import 'package:docdiary_ios/features/auth/session_vault.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';

import 'support.dart';

void main() {
  Future<Harness> showLogin(WidgetTester tester, {Harness? harness}) async {
    final h = harness ?? Harness();
    await h.auth.initialize();
    await tester.pumpWidget(
      DocDiaryApp(
        auth: h.auth,
        dashboard: DashboardRepository(h.transport, now: () => h.now),
        initializeOnStart: false,
      ),
    );
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets(
    'login labels, original artwork and password visibility control are present',
    (tester) async {
      await showLogin(tester);
      expect(find.text('WELCOME!'), findsOneWidget);
      expect(find.text('Login to continue'), findsOneWidget);
      expect(find.bySemanticsLabel('DocDiary'), findsOneWidget);
      final password = find.byKey(const Key('password_field'));
      expect(tester.widget<TextField>(password).obscureText, isTrue);
      await tester.ensureVisible(find.byTooltip('Show password'));
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(tester.widget<TextField>(password).obscureText, isFalse);
    },
  );

  testWidgets('empty submission shows validation and sends no request', (
    tester,
  ) async {
    final h = await showLogin(tester);
    await tester.ensureVisible(find.byKey(const Key('login_button')));
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();
    expect(find.text('Please Give Mobile No and Password'), findsOneWidget);
    expect(h.transport.requests, isEmpty);
  });

  testWidgets(
    'successful login enters the correct doctor dashboard and logout returns to login',
    (tester) async {
      final h = await showLogin(tester);
      await tester.enterText(
        find.byKey(const Key('mobile_field')),
        '01700000000',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'test-only-password',
      );
      await tester.ensureVisible(find.byKey(const Key('login_button')));
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pumpAndSettle();
      expect(h.auth.stage, AuthStage.authenticated);
      expect(find.text('Dr. Example Therapist'), findsOneWidget);
      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(find.text('WELCOME!'), findsOneWidget);
      expect(h.vault.state.session, isNull);
    },
  );

  testWidgets(
    'small iPhone viewport and open keyboard keep login scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await showLogin(tester);
      final headerBefore = tester.getRect(
        find.byKey(const Key('native_login_header')),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const Key('native_login_header'))),
        headerBefore,
      );
      await tester.ensureVisible(find.byKey(const Key('login_button')));
      expect(
        tester.getBottomLeft(find.byKey(const Key('login_button'))).dy,
        lessThanOrEqualTo(318.01),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'remembered credentials fill the form and the label toggles Remember Me',
    (tester) async {
      final h = Harness();
      h.vault.state = const VaultState(
        remembered: Credentials('01700000000', 'remembered-test-password'),
      );
      await showLogin(tester, harness: h);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('mobile_field')))
            .controller!
            .text,
        '01700000000',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('password_field')))
            .controller!
            .text,
        'remembered-test-password',
      );
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      await tester.ensureVisible(find.text('Remember Me'));
      await tester.tap(find.text('Remember Me'));
      await tester.pump();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      expect(h.transport.requests, isEmpty);
    },
  );

  testWidgets(
    'pending login hides the form and rejection restores the entered credentials',
    (tester) async {
      final h = await showLogin(tester);
      final response = Completer<JsonMap>();
      h.transport.onGet = (_) => response.future;
      await tester.enterText(
        find.byKey(const Key('mobile_field')),
        '01700000000',
      );
      await tester.enterText(
        find.byKey(const Key('password_field')),
        'test-only-password',
      );
      await tester.ensureVisible(find.byKey(const Key('login_button')));
      await tester.tap(find.byKey(const Key('login_button')));
      await tester.pump();
      expect(find.byType(NativeLoginProgressScreen), findsOneWidget);
      expect(find.text('WELCOME!'), findsNothing);
      expect(find.byKey(const Key('login_button')), findsNothing);
      expect(
        h.transport.requests.where((request) => request.method == 'GET').length,
        1,
      );

      response.complete({
        'is_available': '0',
        'is_online': 'Invalid test credentials',
      });
      await tester.pumpAndSettle();
      expect(find.text('Warning!'), findsOneWidget);
      expect(find.text('Invalid test credentials'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('mobile_field')))
            .controller!
            .text,
        '01700000000',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('password_field')))
            .controller!
            .text,
        'test-only-password',
      );
    },
  );

  testWidgets(
    'Contact Here requires a choice and No returns to login without requests',
    (tester) async {
      final h = await showLogin(tester);
      await tester.ensureVisible(find.byKey(const Key('contact_here')));
      await tester.tap(find.byKey(const Key('contact_here')));
      await tester.pumpAndSettle();
      expect(
        find.text('Do you want to send an email to info@techterrain-it.com ?'),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('No'), findsOneWidget);
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(h.transport.requests, isEmpty);
    },
  );
}

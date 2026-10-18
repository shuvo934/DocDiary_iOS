import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/login_screen.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

JsonMap _mixedCenter(String base) => {
  ...doctorLogin(base: base),
  'p_center_name': 'Example Rehabilitation Centre A',
  'is_available': '5',
  'p_admin_list': [
    {
      'usr_id': '70',
      'usr_fname': 'Example',
      'usr_lname': 'Admin',
      'usr_name': 'example.admin',
    },
  ],
  'p_doc_list': [
    {
      'doc_code': 'D-10',
      'doc_name': 'Example Therapist',
      'depts_name': 'Physiotherapy',
    },
  ],
};

void _configure(Harness h, {bool singleCenter = false}) {
  h.transport.onText =
      (_) async =>
          singleCenter
              ? 'https://one.example/api/'
              : 'https://one.example/api/\nhttps://two.example/api/';
  h.transport.onGet = (uri) async {
    if (uri.path.endsWith('getAllLoginData')) {
      final base = 'https://${uri.host}/api/';
      return uri.host == 'one.example'
          ? _mixedCenter(base)
          : {
            ...doctorLogin(base: base),
            'p_center_name': 'Example Rehabilitation Centre B',
          };
    }
    return h.defaultGet(uri);
  };
}

Future<void> _show(
  WidgetTester tester,
  Harness h, {
  Size viewport = const Size(393, 852),
}) async {
  tester.view.physicalSize = viewport;
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
    'center then user uses native row content and signs in with the chosen admin',
    (tester) async {
      final h = Harness();
      _configure(h);
      await h.signIn();
      await _show(tester, h);
      expect(find.text('SELECT CENTER'), findsOneWidget);
      expect(find.text('Example Rehabilitation Centre B'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(h.posts, isEmpty);

      await tester.tap(find.byKey(const Key('center_0')));
      await tester.pumpAndSettle();
      expect(h.auth.stage, AuthStage.chooseAccount);
      expect(find.text('Example Rehabilitation Centre A'), findsOneWidget);
      expect(find.text('Example Admin'), findsOneWidget);
      expect(find.text('(example.admin)'), findsOneWidget);
      expect(find.text('Example Therapist'), findsOneWidget);
      expect(find.text('Physiotherapy'), findsOneWidget);
      expect(find.text('D-10'), findsOneWidget);
      expect(find.text('70'), findsNothing);
      expect(find.text('Back to centres'), findsNothing);
      expect(h.posts, isEmpty);

      await tester.tap(find.byKey(const Key('account_0')));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(h.auth.session!.center.baseUri.host, 'one.example');
      expect(h.auth.session!.account.role, AccountRole.admin);
      expect(h.auth.session!.account.adminId, '70');
      expect(
        h.posts
            .where((request) => request.uri.path.endsWith('updateAdminFLFlag'))
            .length,
        1,
      );
      expect(
        h.posts.any((request) => request.uri.path.endsWith('updateFLFlag')),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'outside and back do not dismiss; X from either dialog returns to the entered login',
    (tester) async {
      final h = Harness();
      _configure(h);
      await h.signIn();
      await _show(tester, h);
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(h.auth.stage, AuthStage.chooseCenter);

      await tester.tap(find.byKey(const Key('close_selection')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(h.posts, isEmpty);

      await h.auth.login('01700000000', 'test-only-password', remember: false);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('center_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('close_selection')));
      await tester.pumpAndSettle();
      expect(h.auth.stage, AuthStage.signedOut);
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
      expect(h.posts, isEmpty);
    },
  );

  testWidgets(
    'single center with multiple accounts opens user choice directly',
    (tester) async {
      final h = Harness();
      _configure(h, singleCenter: true);
      await h.signIn();
      await _show(tester, h);
      expect(h.auth.stage, AuthStage.chooseAccount);
      expect(find.text('SELECT CENTER'), findsNothing);
      expect(find.text('Example Rehabilitation Centre A'), findsOneWidget);
      expect(find.text('(example.admin)'), findsOneWidget);
      expect(find.text('D-10'), findsOneWidget);
      expect(h.posts, isEmpty);
    },
  );

  testWidgets(
    'choosing a center with a single direct account skips user choice',
    (tester) async {
      final h = Harness();
      _configure(h);
      await h.signIn();
      await _show(tester, h);
      await tester.tap(find.byKey(const Key('center_1')));
      await tester.pumpAndSettle();
      expect(h.auth.stage, AuthStage.authenticated);
      expect(h.auth.session!.center.baseUri.host, 'two.example');
      expect(h.auth.session!.account.role, AccountRole.doctor);
      expect(find.byType(SelectionScreen), findsNothing);
      expect(
        h.posts
            .where((request) => request.uri.path.endsWith('updateFLFlag'))
            .length,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long center lists scroll on a small phone while the close header stays visible',
    (tester) async {
      final h = Harness();
      h.transport.onText =
          (_) async => List.generate(
            20,
            (index) => 'https://centre$index.example/api/',
          ).join('\n');
      h.transport.onGet =
          (uri) async => {
            ...doctorLogin(base: 'https://${uri.host}/api/'),
            'p_center_name':
                'Rehabilitation and Therapy Center ${uri.host} with a long name',
          };
      await h.signIn();
      await _show(tester, h, viewport: const Size(320, 568));
      final closeBefore = tester.getRect(
        find.byKey(const Key('close_selection')),
      );
      final scrollable =
          find
              .descendant(
                of: find.byKey(const ValueKey('native_centers')),
                matching: find.byType(Scrollable),
              )
              .first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('center_19')),
        200,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const Key('close_selection'))),
        closeBefore,
      );
      expect(tester.takeException(), isNull);
      expect(h.posts, isEmpty);
    },
  );

  testWidgets(
    'account switching hides login notices and marks the current center and account',
    (tester) async {
      final h = Harness();
      _configure(h);
      await h.signIn();
      await h.auth.selectCenter(h.auth.centers.first);
      await h.auth.selectAccount(h.auth.selectedCenter!.accounts.first);
      h.auth.beginSwitch();
      await _show(tester, h);
      expect(find.textContaining('We have found Multiple'), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await tester.tap(find.byKey(const Key('center_0')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.textContaining('We have found Multiple'), findsNothing);
      final writes = h.posts.length;
      await tester.tap(find.byKey(const Key('close_selection')));
      await tester.pumpAndSettle();
      expect(h.auth.stage, AuthStage.authenticated);
      expect(h.posts.length, writes);
      expect(tester.takeException(), isNull);
    },
  );
}

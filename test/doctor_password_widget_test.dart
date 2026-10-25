import 'toast_test_support.dart';
import 'dart:async';

import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/login_screen.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/profile/doctor_password_repository.dart';
import 'package:docdiary_ios/features/profile/doctor_password_screen.dart';
import 'package:docdiary_ios/features/profile/doctor_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_support.dart';
import 'support.dart';

const _old = 'test-only-password', _next = 'New+&123';
void _pause(WidgetTester tester) {
  if (tester.binding.lifecycleState == AppLifecycleState.resumed) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  if (tester.binding.lifecycleState == AppLifecycleState.inactive) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

void _resume(WidgetTester tester) {
  if (tester.binding.lifecycleState == AppLifecycleState.paused) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }
  if (tester.binding.lifecycleState == AppLifecycleState.hidden) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _show(
  WidgetTester tester,
  Harness h, {
  bool remember = false,
  Size size = const Size(393, 852),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  _resume(tester);
  await h.signIn(remember: remember);
  await tester.pumpWidget(
    DocDiaryApp(
      auth: h.auth,
      dashboard: DashboardRepository(h.transport, now: () => h.now),
      initializeOnStart: false,
    ),
  );
  await tester.pumpAndSettle();
  await _tap(tester, 'dashboard_nav_profile');
  await _tap(tester, 'profile_password');
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), value);
  await tester.pumpAndSettle();
}

Future<void> _fill(
  WidgetTester tester, {
  String current = _old,
  String next = _next,
  String? confirm,
}) async {
  await _enter(tester, 'password_current', current);
  await _enter(tester, 'password_new', next);
  await _enter(tester, 'password_confirm', confirm ?? next);
}

TextField _field(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key)));
Iterable<RequestRecord> _writes(Harness h) =>
    h.posts.where((r) => r.uri.path.endsWith('updatePassword'));
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final toasts = ToastRecorder();
  setUp(toasts.install);
  tearDown(toasts.uninstall);
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry
        in {
          'Poppins': [
            'Poppins-Regular.ttf',
            'Poppins-Medium.ttf',
            'Poppins-Bold.ttf',
          ],
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
          'Ubuntu': ['Ubuntu-Medium.ttf'],
        }.entries) {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }
  });
  testWidgets(
    'default Profile route opens three empty hidden fields with independent visibility toggles',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      expect(find.byType(DoctorPasswordScreen), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      for (final name in ['current', 'new', 'confirm']) {
        final key = 'password_$name';
        expect(_field(tester, key).controller!.text, '');
        expect(_field(tester, key).obscureText, isTrue);
        await _enter(tester, key, 'TypedSecret');
        await _tap(tester, 'password_toggle_$name');
        expect(_field(tester, key).obscureText, isFalse);
        expect(_field(tester, key).controller!.text, 'TypedSecret');
      }
      expect(_writes(h), isEmpty);
      expect(h.vault.passwordChanges, 0);
      expect(
        h.posts.where((r) => r.uri.path.endsWith('loginLog')),
        hasLength(1),
      );
      await _finish(tester);
    },
  );
  testWidgets(
    'native required/current-password validation is sequential and editing clears helpers',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      await _tap(tester, 'password_update');
      expect(find.text('Please Provide Current Password'), findsWidgets);
      expect(toasts.messages, contains('Please Provide Current Password'));
      await _enter(tester, 'password_current', 'wrong');
      await _tap(tester, 'password_update');
      expect(find.text('Current Password is Wrong'), findsWidgets);
      await _enter(tester, 'password_current', _old);
      expect(find.text('Current Password is Wrong'), findsNothing);
      await _tap(tester, 'password_update');
      expect(find.text('Please Provide New Password'), findsOneWidget);
      await _enter(tester, 'password_new', _next);
      await _tap(tester, 'password_update');
      expect(find.text('Please Provide Confirm Password'), findsOneWidget);
      expect(_writes(h), isEmpty);
      expect(h.vault.passwordChanges, 0);
      await _finish(tester);
    },
  );
  testWidgets(
    'invalid characters, matching old password and confirm mismatch block Update',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      await _fill(tester, next: 'bad pass');
      await _tap(tester, 'password_update');
      expect(find.text(DoctorPasswordChange.invalidCharacters), findsWidgets);
      await _fill(tester, next: _old);
      await _tap(tester, 'password_update');
      expect(
        find.text('New Password is matched with Current Password.'),
        findsWidgets,
      );
      await _fill(tester, confirm: 'bad"pass');
      await _tap(tester, 'password_update');
      expect(find.text(DoctorPasswordChange.invalidCharacters), findsWidgets);
      await _fill(tester, confirm: 'different');
      await _tap(tester, 'password_update');
      expect(find.text('Confirm Password did not match'), findsWidgets);
      expect(_writes(h), isEmpty);
      await _finish(tester);
    },
  );
  testWidgets(
    'Done clears field focus without submitting and Close discards typed secrets',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      for (final name in ['current', 'new', 'confirm']) {
        await _enter(tester, 'password_$name', 'Unsaved');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(_field(tester, 'password_$name').focusNode!.hasFocus, isFalse);
      }
      await _tap(tester, 'password_close');
      expect(find.byType(DoctorPasswordScreen), findsNothing);
      expect(find.byType(DoctorProfileScreen), findsOneWidget);
      expect(_writes(h), isEmpty);
      expect(h.vault.passwordChanges, 0);
      await _tap(tester, 'profile_password');
      expect(_field(tester, 'password_current').controller!.text, '');
      await _finish(tester);
    },
  );
  testWidgets(
    'Update posts directly then OK returns to Login with new Remember Me secret',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h, remember: true);
      await _fill(tester);
      await _tap(tester, 'password_update');
      expect(find.text('Yes'), findsNothing);
      expect(find.text('Success!'), findsOneWidget);
      expect(
        find.text('Password Updated Successfully. Please log in again.'),
        findsOneWidget,
      );
      expect(_writes(h).single.headers, {'P_DOC_ID': '10', 'P_PASS': _next});
      expect(h.vault.state.session, isNull);
      expect(h.vault.state.remembered!.password, _next);
      await tester.tapAt(const Offset(2, 2));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Success!'), findsOneWidget);
      await _tap(tester, 'dashboard_message_ok');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DoctorPasswordScreen), findsNothing);
      expect(_field(tester, 'mobile_field').controller!.text, '01700000000');
      expect(_field(tester, 'password_field').controller!.text, _next);
      expect(h.auth.formRemember, isTrue);
      expect(
        h.posts.where((r) => r.uri.path.endsWith('loginLog')),
        hasLength(1),
      );
      await _finish(tester);
    },
  );
  testWidgets(
    'Remember Me off returns to blank Login with no automatic saved session',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      await _fill(tester);
      await _tap(tester, 'password_update');
      expect(h.vault.state.session, isNull);
      expect(h.vault.state.remembered, isNull);
      await _tap(tester, 'dashboard_message_ok');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(_field(tester, 'password_field').controller!.text, '');
      expect(h.auth.formRemember, isFalse);
      await _finish(tester);
    },
  );
  testWidgets(
    'network Error waits for explicit Retry and uses the same submitted password',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      await _fill(tester);
      var tries = 0;
      h.transport.onPost =
          (_, _) async =>
              ++tries == 1
                  ? {'string_out': 'Password not accepted'}
                  : {'string_out': 'Successfully Created'};
      await _tap(tester, 'password_update');
      expect(find.byKey(const Key('password_error')), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(tries, 1);
      expect(h.vault.passwordChanges, 0);
      await _tap(tester, 'password_error_retry');
      expect(tries, 2);
      expect(find.text('Success!'), findsOneWidget);
      expect(_writes(h).every((r) => r.headers['P_PASS'] == _next), isTrue);
      await _finish(tester);
    },
  );
  testWidgets(
    'native Error Exit returns to Profile without changing saved credentials',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      await _fill(tester);
      h.transport.onPost =
          (_, _) async => throw const AppFailure('Network interrupted');
      await _tap(tester, 'password_update');
      await _tap(tester, 'password_error_exit');
      expect(find.byType(DoctorPasswordScreen), findsNothing);
      expect(find.byType(DoctorProfileScreen), findsOneWidget);
      expect(h.vault.passwordChanges, 0);
      expect(h.vault.state.session!.credentials.password, _old);
      await _finish(tester);
    },
  );
  testWidgets(
    'native Error outside dismissal leaves form editable and does not retry',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      await _fill(tester);
      h.transport.onPost =
          (_, _) async => throw const AppFailure('Network interrupted');
      await _tap(tester, 'password_update');
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('password_error')), findsNothing);
      await _enter(tester, 'password_new', 'OtherNew');
      expect(_field(tester, 'password_new').controller!.text, 'OtherNew');
      expect(_writes(h), hasLength(1));
      expect(h.vault.passwordChanges, 0);
      await _finish(tester);
    },
  );
  testWidgets(
    'storage failure after remote success retries storage only and cannot escape into the old session',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h, remember: true);
      await _fill(tester);
      h.vault.failPasswordChange = true;
      await _tap(tester, 'password_update');
      expect(find.byKey(const Key('password_storage_error')), findsOneWidget);
      expect(find.byKey(const Key('password_error_exit')), findsNothing);
      await tester.tapAt(const Offset(2, 2));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('password_storage_error')), findsOneWidget);
      expect(_writes(h), hasLength(1));
      expect(h.vault.passwordChanges, 1);
      h.vault.failPasswordChange = false;
      await _tap(tester, 'password_storage_retry');
      expect(_writes(h), hasLength(1));
      expect(h.vault.passwordChanges, 2);
      expect(find.text('Success!'), findsOneWidget);
      await _tap(tester, 'dashboard_message_ok');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(_field(tester, 'password_field').controller!.text, _next);
      await _finish(tester);
    },
  );
  testWidgets(
    'background success is completed once on resume without another password POST',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h, remember: true);
      await _fill(tester);
      final pending = Completer<JsonMap>();
      h.transport.onPost = (_, _) async => await pending.future;
      await tester.tap(find.byKey(const Key('password_update')));
      await tester.pump();
      expect(_writes(h), hasLength(1));
      _pause(tester);
      pending.complete({'string_out': 'Successfully Created'});
      await tester.pump();
      expect(h.vault.passwordChanges, 0);
      expect(find.text('Success!'), findsNothing);
      _resume(tester);
      await tester.pumpAndSettle();
      expect(find.text('Success!'), findsOneWidget);
      expect(_writes(h), hasLength(1));
      expect(h.vault.passwordChanges, 1);
      await _finish(tester);
    },
  );
  testWidgets(
    'double tap cannot send two password writes or two credential commits',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      await _fill(tester);
      final pending = Completer<JsonMap>();
      h.transport.onPost = (_, _) async => await pending.future;
      await tester.tap(find.byKey(const Key('password_update')));
      await tester.tap(find.byKey(const Key('password_update')));
      await tester.pump();
      expect(_writes(h), hasLength(1));
      pending.complete({'string_out': 'Successfully Created'});
      await tester.pumpAndSettle();
      expect(h.vault.passwordChanges, 1);
      expect(find.text('Success!'), findsOneWidget);
      await _finish(tester);
    },
  );
  testWidgets(
    'pause during preflight prevents dispatch and resume never auto retries the POST',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      await _fill(tester);
      final get = h.transport.onGet!;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getDocFLFlag')) {
          _pause(tester);
        }
        return await get(uri);
      };
      await tester.tap(find.byKey(const Key('password_update')));
      await tester.pump();
      expect(_writes(h), isEmpty);
      _resume(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('password_error')), findsOneWidget);
      expect(_writes(h), isEmpty);
      expect(h.vault.passwordChanges, 0);
      await _finish(tester);
    },
  );
  testWidgets(
    'logout during pending POST cannot commit credentials or show stale success above Login',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      await _fill(tester);
      final pending = Completer<JsonMap>();
      h.transport.onPost = (_, _) async => await pending.future;
      await tester.tap(find.byKey(const Key('password_update')));
      await tester.pump();
      await h.auth.logout();
      await tester.pumpAndSettle();
      pending.complete({'string_out': 'Successfully Created'});
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Success!'), findsNothing);
      expect(h.vault.passwordChanges, 0);
      expect(h.vault.state.session, isNull);
      await _finish(tester);
    },
  );
  testWidgets(
    'fresh access and forced-logout checks block both remote and credential writes',
    (tester) async {
      for (final forced in [false, true]) {
        final h = profileHarness();
        await _show(tester, h);
        await _fill(tester);
        if (forced) {
          final get = h.transport.onGet!;
          h.transport.onGet =
              (uri) async =>
                  uri.path.endsWith('getDocFLFlag')
                      ? {
                        'items': [
                          {'fl_flag': '1'},
                        ],
                      }
                      : await get(uri);
        } else {
          h.doctorData['access_flag'] = '0';
        }
        await _tap(tester, 'password_update');
        expect(h.auth.stage, AuthStage.accountBlocked);
        expect(find.byType(DoctorPasswordScreen), findsNothing);
        expect(_writes(h), isEmpty);
        expect(h.vault.passwordChanges, 0);
        await _finish(tester);
      }
    },
  );
  testWidgets(
    'idle resume preserves typed fields and rechecks expiry without login writes',
    (tester) async {
      final h = profileHarness();
      await _show(tester, h);
      await _fill(tester);
      await _tap(tester, 'password_toggle_new');
      _pause(tester);
      _resume(tester);
      await tester.pumpAndSettle();
      expect(_field(tester, 'password_new').controller!.text, _next);
      expect(_field(tester, 'password_new').obscureText, isFalse);
      expect(
        h.posts.where((r) => r.uri.path.endsWith('loginLog')),
        hasLength(1),
      );
      h.doctorData['exp_date'] = '01-JAN-20';
      _pause(tester);
      _resume(tester);
      await tester.pumpAndSettle();
      expect(h.auth.stage, AuthStage.accountBlocked);
      expect(_writes(h), isEmpty);
      await _finish(tester);
    },
  );
  testWidgets(
    'small screens, large system text, helper wrapping and keyboard keep Update reachable',
    (tester) async {
      for (final size in [const Size(320, 640), const Size(393, 852)]) {
        final h = profileHarness();
        await _show(tester, h, size: size, scale: 2);
        await _fill(tester, next: 'invalid password with spaces');
        await _tap(tester, 'password_update');
        expect(find.text(DoctorPasswordChange.invalidCharacters), findsWidgets);
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await _fill(tester);
        await _tap(tester, 'password_update');
        expect(find.text('Success!'), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await _finish(tester);
      }
    },
  );
  testWidgets(
    'missing session at construction shows recovery without stale account reads',
    (tester) async {
      final h = profileHarness();
      await h.signIn();
      await h.auth.logout();
      final requests = h.transport.requests.length;
      await tester.pumpWidget(
        MaterialApp(
          home: DoctorPasswordScreen(
            auth: h.auth,
            repository: DoctorPasswordRepository(h.transport),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Could Not Get Doctor Data. Please return to Login.'),
        findsOneWidget,
      );
      expect(h.transport.requests.length, requests);
      await _finish(tester);
      h.auth.dispose();
    },
  );
}

import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/session_vault.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

const _credentials = Credentials('01700000000', 'wrong+&/?#password');
const _notFound = 'Could not find your id.';
const _connection = 'Server Problem or Internet Not Connected';
const _apiIssue = 'There is a network issue in the server. Please Try later.';
const _offline = AppFailure(
  'Test connection failed',
  kind: FailureKind.network,
);
const _badJson = AppFailure('Test invalid JSON', kind: FailureKind.invalidData);

void _responses(Harness h, List<Object> replies) {
  h.transport.onText =
      (_) async => List.generate(
        replies.length,
        (index) => 'https://centre$index.example/api/',
      ).join('\n');
  var index = 0;
  h.transport.onGet = (uri) async {
    final reply = replies[index++];
    if (reply is AppFailure) {
      throw reply;
    }
    return reply as JsonMap;
  };
}

List<RequestRecord> _loginGets(Harness h) =>
    h.transport.requests
        .where((r) => r.uri.path.endsWith('getAllLoginData'))
        .toList();

Future<AppFailure> _reject(Harness h) async {
  try {
    await h.auth.repository.discover(_credentials);
  } on AppFailure catch (failure) {
    return failure;
  }
  throw StateError('Expected login discovery to fail');
}

Future<void> _show(WidgetTester tester, Harness h) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await h.auth.initialize();
  await tester.pumpWidget(
    DocDiaryApp(
      auth: h.auth,
      dashboard: DashboardRepository(h.transport, now: () => h.now),
      initializeOnStart: false,
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('mobile_field')),
    _credentials.mobile,
  );
  await tester.enterText(
    find.byKey(const Key('password_field')),
    _credentials.password,
  );
  await tester.ensureVisible(find.byKey(const Key('login_button')));
  await tester.tap(find.byKey(const Key('login_button')));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  late Harness h;
  setUp(() => h = Harness());
  tearDown(() => h.auth.dispose());

  test('native string and numeric flags 0 and 2 mean no matching account', () {
    for (final flag in <Object>['0', '2', 0, 2]) {
      expect(CenterOption.fromLoginResponse({'is_available': flag}), isNull);
    }
    expect(
      () => CenterOption.fromLoginResponse({'is_available': '6'}),
      throwsA(
        isA<AppFailure>().having(
          (f) => f.kind,
          'kind',
          FailureKind.invalidData,
        ),
      ),
    );
  });

  test(
    'all healthy flag2 rejections show the backend ID message after checking every API',
    () async {
      _responses(h, [
        {'is_available': '2', 'is_online': _notFound},
        {'is_available': 2, 'is_online': _notFound},
        {'is_available': '2', 'is_online': _notFound},
      ]);
      final failure = await _reject(h);
      expect(failure.message, _notFound);
      expect(failure.kind, FailureKind.denied);
      expect(_loginGets(h).map((r) => r.uri.host), [
        'centre0.example',
        'centre1.example',
        'centre2.example',
      ]);
      for (final request in _loginGets(h)) {
        expect(request.uri.queryParameters, {
          'doc_code': _credentials.mobile,
          'doc_password': _credentials.password,
        });
      }
      expect(h.posts, isEmpty);
    },
  );

  test('native flag0 rejection keeps its full server message', () async {
    _responses(h, [
      {'is_available': '0', 'is_online': 'Mobile access is disabled.'},
    ]);
    expect((await _reject(h)).message, 'Mobile access is disabled.');
  });

  test(
    'previous business message survives a final connection failure',
    () async {
      _responses(h, [
        {'is_available': '2', 'is_online': _notFound},
        _offline,
      ]);
      final failure = await _reject(h);
      expect(failure.message, _notFound);
      expect(failure.kind, FailureKind.denied);
      expect(_loginGets(h), hasLength(2));
    },
  );

  test(
    'previous business message survives malformed and unsupported later replies',
    () async {
      _responses(h, [
        {
          'is_available': '0',
          'is_online': 'Please contact your administrator.',
        },
        _badJson,
        {'is_available': '6', 'is_online': 'Unrecognized result'},
      ]);
      expect((await _reject(h)).message, 'Please contact your administrator.');
      expect(_loginGets(h), hasLength(3));
    },
  );

  test(
    'last meaningful rejection replaces the earlier one without accepting Online as a message',
    () async {
      _responses(h, [
        {'is_available': '0', 'is_online': 'Previous rejection'},
        {'is_available': '2', 'is_online': _notFound},
        {'is_available': '2', 'is_online': ' Online '},
        {'is_available': '2', 'is_online': 'null'},
      ]);
      expect((await _reject(h)).message, _notFound);
    },
  );

  test(
    'complete no-account replies without a useful message use the clear ID fallback',
    () async {
      _responses(h, [
        {'is_available': '0', 'is_online': ''},
        {'is_available': '2', 'is_online': null},
        {'is_available': '2', 'is_online': 'Online'},
      ]);
      final failure = await _reject(h);
      expect(failure.message, _notFound);
      expect(failure.kind, FailureKind.denied);
    },
  );

  test(
    'all connection failures use the native connection Retry message',
    () async {
      _responses(h, [_offline, _offline]);
      final failure = await _reject(h);
      expect(failure.message, _connection);
      expect(failure.kind, FailureKind.network);
      expect(_loginGets(h), hasLength(2));
    },
  );

  test(
    'unreadable server JSON is an API failure rather than wrong credentials',
    () async {
      _responses(h, [_badJson]);
      final failure = await _reject(h);
      expect(failure.message, _apiIssue);
      expect(failure.kind, FailureKind.server);
    },
  );

  test(
    'missing or unsupported availability and unusable matching accounts stay retryable API issues',
    () async {
      _responses(h, [
        <String, Object?>{},
        {'is_available': '6'},
        {'is_available': '1', 'p_admin_user_flag': '1', 'p_doc_code': null},
      ]);
      expect((await _reject(h)).message, _apiIssue);
      expect(_loginGets(h), hasLength(3));
    },
  );

  test('HTTP server errors keep the native server Retry message', () async {
    _responses(h, [const AppFailure('Test HTTP 500')]);
    expect((await _reject(h)).message, _apiIssue);
  });

  test(
    'an incomplete check without a useful business message cannot claim ID not found',
    () async {
      for (final replies in <List<Object>>[
        [
          {'is_available': '2', 'is_online': ''},
          _offline,
        ],
        [
          _offline,
          {'is_available': '0', 'is_online': 'Online'},
        ],
      ]) {
        _responses(h, replies);
        expect((await _reject(h)).message, _apiIssue);
      }
    },
  );

  test(
    'later failures and rejections cannot discard a matching centre',
    () async {
      _responses(h, [
        _offline,
        doctorLogin(base: 'https://one.example/api/'),
        {'is_available': '2', 'is_online': _notFound},
        _badJson,
        doctorLogin(base: 'https://two.example/api/'),
      ]);
      final result = await h.auth.repository.discover(_credentials);
      expect(result.centers.map((c) => c.baseUri.host), [
        'one.example',
        'two.example',
      ]);
      expect(result.failedServerCount, 2);
      expect(_loginGets(h), hasLength(5));
      expect(h.posts, isEmpty);
    },
  );

  test(
    'previous messages are scoped to one submit and cannot leak into Retry',
    () async {
      _responses(h, [
        {'is_available': '2', 'is_online': 'Previous attempt only'},
      ]);
      expect((await _reject(h)).message, 'Previous attempt only');
      _responses(h, [_offline]);
      expect((await _reject(h)).message, _connection);
    },
  );

  test(
    'controller rejection keeps entered credentials and remembered storage without any POST',
    () async {
      h.vault.state = const VaultState(
        remembered: Credentials('00000000000', 'saved-test-only'),
      );
      _responses(h, [
        {'is_available': '2', 'is_online': _notFound},
      ]);
      await h.auth.initialize();
      await h.auth.login(
        _credentials.mobile,
        _credentials.password,
        remember: true,
      );
      expect(h.auth.stage, AuthStage.signedOut);
      expect(h.auth.error, _notFound);
      expect(h.auth.formCredentials?.password, _credentials.password);
      expect(h.auth.session, isNull);
      expect(h.vault.state.remembered?.password, 'saved-test-only');
      expect(h.vault.saves, 0);
      expect(h.posts, isEmpty);
    },
  );

  testWidgets(
    'flag2 shows native Warning and OK, then retains the typed form',
    (tester) async {
      final h = Harness();
      _responses(h, [
        {'is_available': '2', 'is_online': _notFound},
        {'is_available': '2', 'is_online': _notFound},
      ]);
      await _show(tester, h);
      expect(find.text('Warning!'), findsOneWidget);
      expect(find.text(_notFound), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.text(_connection), findsNothing);
      expect(_loginGets(h), hasLength(2));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('password_field')))
            .controller!
            .text,
        _credentials.password,
      );
      expect(h.posts, isEmpty);
      expect(h.vault.saves, 0);
    },
  );

  testWidgets(
    'healthy missing messages show the ID fallback, not Online or a network dialog',
    (tester) async {
      final h = Harness();
      _responses(h, [
        {'is_available': '2', 'is_online': 'Online'},
      ]);
      await _show(tester, h);
      expect(find.text(_notFound), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Online'), findsNothing);
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets(
    'a final unreachable centre retains the previous native business message',
    (tester) async {
      final h = Harness();
      _responses(h, [
        {'is_available': '2', 'is_online': _notFound},
        _offline,
      ]);
      await _show(tester, h);
      expect(find.text(_notFound), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text(_connection), findsNothing);
    },
  );

  testWidgets(
    'connection Retry is manual and starts a fresh check with the same input',
    (tester) async {
      final h = Harness();
      _responses(h, [_offline, _offline]);
      await _show(tester, h);
      expect(find.text(_connection), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(_loginGets(h), hasLength(2));
      _responses(h, [
        {'is_available': '2', 'is_online': _notFound},
      ]);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text(_notFound), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(_loginGets(h), hasLength(3));
      expect(
        _loginGets(h).last.uri.queryParameters['doc_password'],
        _credentials.password,
      );
      expect(h.posts, isEmpty);
    },
  );

  testWidgets('malformed API replies show the native server Retry action', (
    tester,
  ) async {
    final h = Harness();
    _responses(h, [_badJson]);
    await _show(tester, h);
    expect(find.text(_apiIssue), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text(_notFound), findsNothing);
  });
}

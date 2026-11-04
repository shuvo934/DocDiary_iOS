import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/account_access.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

const _subscriptionPath = '/login/getSubscriptionData';

bool _isSubscription(Uri uri) => uri.path.endsWith(_subscriptionPath);

JsonMap _subscription(Object? value) => {
  'count': 1,
  'items': [
    {'val': value},
  ],
};

void main() {
  late Harness h;
  late JsonMap reply;
  List<RequestRecord> checks() =>
      h.transport.requests.where((r) => _isSubscription(r.uri)).toList();

  setUp(() {
    h = Harness(isIOS: true);
    reply = _subscription(1);
    h.transport.onGet =
        (uri) async => _isSubscription(uri) ? reply : h.defaultGet(uri);
  });
  tearDown(() => h.auth.dispose());

  for (final role in AccountRole.values) {
    test(
      'single ${role.name} verifies iOS before account initialization',
      () async {
        if (role == AccountRole.admin) h.loginResponse = adminLogin();
        await h.signIn();

        final check = checks().single;
        expect(check.method, 'GET');
        expect(
          check.uri,
          Uri.parse('https://centre.example/api$_subscriptionPath'),
        );
        expect(
          h.transport.requests.indexOf(check),
          lessThan(h.transport.requests.indexOf(h.posts.first)),
        );
        expect(h.auth.stage, AuthStage.authenticated);
        expect(h.auth.session?.account.role, role);
        expect(h.vault.saves, 1);
      },
    );
  }

  test(
    'multi-centre sign-in and switch use only the selected base URL',
    () async {
      h.transport.onText =
          (_) async =>
              'https://first.example/api/\nhttps://second.example/api/';
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getAllLoginData')) {
          return {
            ...doctorLogin(base: 'https://${uri.host}/selected/'),
            'p_center_name': uri.host,
          };
        }
        if (_isSubscription(uri)) {
          return _subscription(uri.host == 'second.example' ? '1' : '0');
        }
        return h.defaultGet(uri);
      };
      await h.signIn();
      expect(h.auth.stage, AuthStage.chooseCenter);
      expect(checks(), isEmpty);
      await h.auth.selectCenter(h.auth.centers.last);
      expect(h.auth.stage, AuthStage.authenticated);
      expect(checks().single.uri.path, '/selected$_subscriptionPath');
      expect(checks().single.uri.host, 'second.example');

      h.transport.requests.clear();
      h.auth.beginSwitch();
      expect(checks(), isEmpty);
      await h.auth.selectCenter(h.auth.centers.first);
      expect(checks().single.uri.host, 'first.example');
      expect(h.auth.stage, AuthStage.accountBlocked);
      expect(h.auth.accessFailure?.message, contains('first.example'));
      expect(h.auth.profile, isNull);
      expect(h.posts, isEmpty);
      expect(h.vault.saves, 1);
    },
  );

  test(
    'a centre with multiple accounts waits for the account choice',
    () async {
      h.loginResponse = {
        ...doctorLogin(),
        'is_available': '5',
        'p_admin_list': [
          {'usr_id': '70', 'usr_name': 'example.admin'},
        ],
        'p_doc_list': [
          {'doc_code': 'D-10', 'doc_name': 'Example Therapist'},
        ],
      };
      await h.signIn();
      expect(h.auth.stage, AuthStage.chooseAccount);
      expect(checks(), isEmpty);
      await h.auth.selectAccount(
        h.auth.selectedCenter!.accounts.singleWhere(
          (a) => a.role == AccountRole.admin,
        ),
      );
      expect(checks(), hasLength(1));
      expect(h.auth.stage, AuthStage.authenticated);
      expect(h.auth.session?.account.role, AccountRole.admin);
    },
  );

  for (final (label, result) in [
    ('val 0', _subscription('0')),
    ('no rows', <String, Object?>{'count': 0, 'items': []}),
  ]) {
    test('$label blocks access without sending login writes', () async {
      reply = result;
      await h.signIn();
      expect(h.auth.stage, AuthStage.accountBlocked);
      expect(
        h.auth.accessFailure?.reason,
        AccountAccessReason.iosSubscriptionRequired,
      );
      expect(h.auth.accessFailure?.title, 'Warning!');
      expect(h.auth.session, isNull);
      expect(h.vault.saves, 0);
      expect(h.posts, isEmpty);
      await h.auth.acknowledgeAccess();
      expect(h.auth.stage, AuthStage.signedOut);
    });
  }

  test(
    'malformed subscription is retryable and sends no login writes',
    () async {
      reply = _subscription(null);
      await h.signIn();
      expect(h.auth.stage, AuthStage.accountError);
      expect(h.auth.accessFailure, isNull);
      expect(h.posts, isEmpty);
      expect(h.vault.saves, 0);
      reply = _subscription('1');
      await h.auth.retryAccount();
      expect(h.auth.stage, AuthStage.authenticated);
      expect(checks(), hasLength(2));
      expect(
        h.posts.where((r) => r.uri.path.endsWith('updateFLFlag')),
        hasLength(1),
      );
      expect(h.vault.saves, 1);
    },
  );

  test(
    'network failure retries the same centre before resetting the flag',
    () async {
      var offline = true;
      h.transport.onGet = (uri) async {
        if (!_isSubscription(uri)) return h.defaultGet(uri);
        if (offline) {
          throw const AppFailure('Offline', kind: FailureKind.network);
        }
        return reply;
      };
      await h.signIn();
      expect(h.auth.stage, AuthStage.accountError);
      expect(h.auth.error, 'Offline');
      expect(h.posts, isEmpty);
      offline = false;
      await h.auth.retryAccount();
      expect(checks().map((r) => r.uri).toSet(), hasLength(1));
      expect(h.auth.stage, AuthStage.authenticated);
      expect(
        h.posts.where((r) => r.uri.path.endsWith('updateFLFlag')),
        hasLength(1),
      );
    },
  );

  test('saved iOS session rechecks the centre before restoring', () async {
    await h.signIn();
    expect(h.auth.stage, AuthStage.authenticated);
    h.transport.requests.clear();
    reply = _subscription(0);
    await h.auth.initialize();

    expect(checks(), hasLength(1));
    expect(h.transport.requests, hasLength(1));
    expect(h.auth.stage, AuthStage.accountBlocked);
    expect(h.auth.profile, isNull);
    await h.auth.acknowledgeAccess();
    expect(h.vault.state.session, isNull);
  });

  test(
    'profile Retry verifies subscription without resetting the flag twice',
    () async {
      h.vault.failSave = true;
      await h.signIn();
      expect(h.auth.stage, AuthStage.accountError);
      expect(h.posts, hasLength(2));
      h.vault.failSave = false;

      await h.auth.retryAccount();

      expect(h.auth.stage, AuthStage.authenticated);
      expect(checks(), hasLength(2));
      expect(h.posts, hasLength(2));
      expect(h.vault.saves, 1);
    },
  );

  test('non-iOS sign-in skips the subscription request', () async {
    final other = Harness(isIOS: false);
    addTearDown(other.auth.dispose);
    await other.signIn();
    expect(other.auth.stage, AuthStage.authenticated);
    expect(
      other.transport.requests.any((r) => _isSubscription(r.uri)),
      isFalse,
    );
  });
}

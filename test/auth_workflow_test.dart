import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';

import 'support.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness());
  tearDown(() => h.auth.dispose());

  test(
    'single doctor login saves a session only after flag update and access initialization',
    () async {
      await h.signIn();
      expect(h.auth.stage, AuthStage.authenticated);
      expect(h.auth.session!.account.role, AccountRole.doctor);
      expect(h.vault.saves, 1);
      expect(h.posts.first.uri.path, '/api/login/updateFLFlag');
      expect(h.posts.first.headers, {'P_DOC_CODE': 'D-10'});
      expect(h.posts.last.uri.path, '/api/doc_dashboard/loginLog');
      expect(h.posts.last.headers['P_IULL_SESSION_USER_ID'], '10');
    },
  );

  test('single admin login uses admin ID and admin flag endpoint', () async {
    h.loginResponse = adminLogin();
    await h.signIn();
    expect(h.auth.stage, AuthStage.authenticated);
    expect(h.auth.session!.account.adminId, '70');
    expect(h.posts.first.uri.path, '/api/login/updateAdminFLFlag');
    expect(h.posts.first.headers, {'P_USR_ID': '70'});
    expect(
      h.transport.requests.any((r) => r.uri.path.endsWith('getDocData')),
      isFalse,
    );
  });

  test(
    'password query preserves plus, ampersand, spaces, slash and fragment characters',
    () async {
      await h.auth.initialize();
      const password = ' p+&/?#বাংলা ';
      await h.auth.login('+8801700000000', password, remember: false);
      final login = h.transport.requests.firstWhere(
        (r) => r.uri.path.endsWith('getAllLoginData'),
      );
      expect(login.uri.queryParameters['doc_code'], '+8801700000000');
      expect(login.uri.queryParameters['doc_password'], password);
      expect(login.uri.hasFragment, isFalse);
      expect(h.auth.session!.credentials.password, password);
    },
  );

  test('empty input does not contact any server', () async {
    await h.auth.initialize();
    await h.auth.login('', '', remember: false);
    expect(h.transport.requests, isEmpty);
    expect(h.auth.stage, AuthStage.signedOut);
  });

  test(
    'double submit cannot send duplicate flag-reset or login-log POSTs',
    () async {
      await h.auth.initialize();
      await Future.wait([
        h.auth.login('01700000000', 'test-only-password', remember: false),
        h.auth.login('01700000000', 'test-only-password', remember: false),
      ]);
      expect(
        h.posts.where((r) => r.uri.path.endsWith('updateFLFlag')).length,
        1,
      );
      expect(h.posts.where((r) => r.uri.path.endsWith('loginLog')).length, 1);
    },
  );

  test('rejected credentials never create or save a session', () async {
    h.loginResponse = {
      'is_available': '0',
      'is_online': 'Invalid Mobile No or Password',
    };
    await h.signIn();
    expect(h.auth.session, isNull);
    expect(h.vault.saves, 0);
    expect(h.posts, isEmpty);
    expect(h.auth.error, 'Invalid Mobile No or Password');
  });

  test(
    'one unreachable centre cannot discard a valid result from another centre',
    () async {
      h.transport.onText =
          (_) async => 'https://down.example/api/\nhttps://centre.example/api/';
      h.transport.onGet = (uri) async {
        if (uri.host == 'down.example') {
          throw const AppFailure('Offline', kind: FailureKind.network);
        }
        return h.defaultGet(uri);
      };
      await h.signIn();
      expect(h.auth.stage, AuthStage.authenticated);
      expect(h.auth.failedServerCount, 1);
    },
  );

  test(
    'multiple centres wait for explicit selection; cancel makes no POST',
    () async {
      h.transport.onText =
          (_) async => 'https://one.example/api/\nhttps://two.example/api/';
      h.transport.onGet =
          (uri) async => doctorLogin(base: 'https://${uri.host}/api/');
      await h.signIn();
      expect(h.auth.stage, AuthStage.chooseCenter);
      expect(h.vault.saves, 0);
      expect(h.posts, isEmpty);
      h.auth.cancelSelection();
      expect(h.auth.stage, AuthStage.signedOut);
      expect(h.auth.session, isNull);
    },
  );

  test(
    'mixed doctor/admin result preserves the explicitly selected admin identity',
    () async {
      h.loginResponse = {
        ...doctorLogin(),
        'is_available': '5',
        'p_admin_list': jsonEncode([
          {
            'usr_id': '70',
            'usr_name': 'example.admin',
            'usr_fname': 'Example',
            'usr_lname': 'Admin',
          },
        ]),
        'p_doc_list': [
          {'doc_code': 'D-10', 'doc_name': 'Example Therapist'},
        ],
      };
      await h.signIn();
      expect(h.auth.stage, AuthStage.chooseAccount);
      expect(h.posts, isEmpty);
      await h.auth.selectAccount(h.auth.selectedCenter!.accounts.first);
      expect(h.auth.stage, AuthStage.authenticated);
      expect(h.auth.session!.account.role, AccountRole.admin);
      expect(h.auth.profile!.displayName, 'Example Admin');
    },
  );

  test(
    'server flag update failure does not request a profile or persist login',
    () async {
      h.transport.onPost = (_, __) async => {'string_out': 'Failed'};
      await h.signIn();
      expect(h.auth.session, isNull);
      expect(h.vault.saves, 0);
      expect(
        h.transport.requests.any((r) => r.uri.path.endsWith('getDocData')),
        isFalse,
      );
    },
  );

  test(
    'disabled mobile access and forced logout are both denied before login log',
    () async {
      h.doctorData['access_flag'] = '0';
      await h.signIn();
      expect(h.auth.session, isNull);
      expect(h.posts.where((r) => r.uri.path.endsWith('loginLog')), isEmpty);
      expect(h.auth.stage, AuthStage.accountBlocked);
      await h.auth.acknowledgeAccess();
      h.doctorData['access_flag'] = '1';
      h.doctorData['fl_flag'] = '1';
      await h.signIn();
      expect(h.auth.session, isNull);
      expect(h.vault.saves, 0);
    },
  );

  test('expiry is inclusive for today and denies yesterday', () async {
    h.doctorData['exp_date'] = '14-OCT-26';
    await h.signIn();
    expect(h.auth.session, isNull);
    expect(h.auth.stage, AuthStage.accountBlocked);
    await h.auth.acknowledgeAccess();
    h.doctorData['exp_date'] = '15-OCT-26';
    await h.signIn();
    expect(h.auth.stage, AuthStage.authenticated);
  });

  test(
    'first login with missing expiry sends the native three-calendar-month update',
    () async {
      h.doctorData['doc_app_first_login_flag'] = '0';
      h.doctorData['exp_date'] = null;
      await h.signIn();
      expect(h.auth.stage, AuthStage.authenticated);
      final update = h.posts.firstWhere(
        (r) => r.uri.path.endsWith('updateDocExpDate'),
      );
      expect(update.headers, {'P_DATE': '15-JAN-27', 'P_DOC_CODE': 'D-10'});
      expect(h.posts.indexOf(update), lessThan(h.posts.length - 1));
    },
  );

  test(
    'secure-storage save failure cannot report successful authentication',
    () async {
      h.vault.failSave = true;
      await h.signIn();
      expect(h.auth.stage, isNot(AuthStage.authenticated));
      expect(h.auth.session, isNull);
      expect(h.auth.error, 'Secure storage unavailable.');
    },
  );

  test(
    'logout clears active session while preserving explicit Remember Me',
    () async {
      await h.signIn(remember: true);
      await h.auth.logout();
      expect(h.auth.stage, AuthStage.signedOut);
      expect(h.vault.state.session, isNull);
      expect(h.vault.state.remembered!.mobile, '01700000000');
    },
  );

  test(
    'logout without Remember Me retains no remembered credentials',
    () async {
      await h.signIn();
      await h.auth.logout();
      expect(h.vault.state.session, isNull);
      expect(h.vault.state.remembered, isNull);
    },
  );

  test(
    'logout storage failure blocks app access instead of claiming logout succeeded',
    () async {
      await h.signIn();
      h.vault.failClear = true;
      await h.auth.logout();
      expect(h.auth.stage, AuthStage.reconnect);
      expect(h.auth.profile, isNull);
      expect(h.auth.error, contains('could not be cleared'));
    },
  );

  test(
    'saved session round-trips selected centre, account, role and catalogue',
    () async {
      await h.signIn(remember: true);
      final encoded = jsonEncode(h.auth.session!.toJson());
      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      final restored = AuthSession.fromJson(decoded);
      expect(restored.account.role, AccountRole.doctor);
      expect(restored.account.doctorCode, 'D-10');
      expect(restored.center.baseUri, Uri.parse('https://centre.example/api/'));
      expect(restored.remember, isTrue);
    },
  );

  test(
    'cold restore blocks revoked access and clears the saved session after OK',
    () async {
      await h.signIn(remember: true);
      h.doctorData['fl_flag'] = '1';
      await h.auth.initialize();
      expect(h.auth.stage, AuthStage.accountBlocked);
      expect(h.auth.profile, isNull);
      expect(h.vault.state.session, isNotNull);
      expect(h.vault.clears, 0);
      await h.auth.acknowledgeAccess();
      expect(h.auth.stage, AuthStage.signedOut);
      expect(h.vault.state.session, isNull);
      expect(h.vault.state.remembered, isNotNull);
    },
  );

  test(
    'temporary network failure on restore keeps session blocked and retryable',
    () async {
      await h.signIn();
      final saved = h.vault.state;
      h.transport.onGet =
          (_) async =>
              throw const AppFailure('Offline', kind: FailureKind.network);
      await h.auth.initialize();
      expect(h.auth.stage, AuthStage.accountError);
      expect(h.vault.state, same(saved));
      h.transport.onGet = h.defaultGet;
      await h.auth.retryAccount();
      expect(h.auth.stage, AuthStage.authenticated);
    },
  );

  test(
    'cancel account switching returns to the original profile without flag reset',
    () async {
      h.loginResponse = {
        ...doctorLogin(),
        'is_available': '3',
        'p_doc_list': [
          {'doc_code': 'D-10', 'doc_name': 'One'},
          {'doc_code': 'D-20', 'doc_name': 'Two'},
        ],
      };
      await h.signIn();
      await h.auth.selectAccount(h.auth.selectedCenter!.accounts.first);
      final original = h.auth.session;
      final postCount = h.posts.length;
      h.auth.beginSwitch();
      expect(h.auth.stage, AuthStage.chooseAccount);
      h.auth.cancelSelection();
      expect(h.auth.stage, AuthStage.authenticated);
      expect(h.auth.session, same(original));
      expect(h.posts.length, postCount);
    },
  );

  test(
    'switching account revalidates identity and does not reset forced-logout flags',
    () async {
      h.loginResponse = {
        ...doctorLogin(),
        'is_available': '3',
        'p_doc_list': [
          {'doc_code': 'D-10', 'doc_name': 'One'},
          {'doc_code': 'D-20', 'doc_name': 'Two'},
        ],
      };
      await h.signIn();
      await h.auth.selectAccount(h.auth.selectedCenter!.accounts.first);
      final flagCount =
          h.posts.where((r) => r.uri.path.endsWith('updateFLFlag')).length;
      h.auth.beginSwitch();
      h.doctorData['doc_code'] = 'D-20';
      h.doctorData['doc_id'] = '20';
      await h.auth.selectAccount(h.auth.selectedCenter!.accounts.last);
      expect(h.auth.session!.account.doctorCode, 'D-20');
      expect(h.auth.profile!.doctorId, '20');
      expect(
        h.posts.where((r) => r.uri.path.endsWith('updateFLFlag')).length,
        flagCount,
      );
    },
  );
}

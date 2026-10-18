import 'dart:async';

import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_dates.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/account_access.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/dashboard/admin_chart_models.dart';
import 'package:docdiary_ios/features/dashboard/admin_chart_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Harness _account(bool admin) {
  final h = Harness();
  if (admin) {
    h.loginResponse = adminLogin();
  }
  addTearDown(h.auth.dispose);
  return h;
}

void main() {
  for (final admin in [false, true]) {
    final role = admin ? 'admin' : 'doctor';
    test(
      '$role force flag blocks before initialization and needs explicit OK',
      () async {
        final h = _account(admin);
        (admin ? h.adminData : h.doctorData)[admin
                ? 'usr_mob_forced_log_out_flag'
                : 'fl_flag'] =
            '1';
        await h.signIn();
        expect(h.auth.stage, AuthStage.accountBlocked);
        expect(h.auth.accessFailure!.title, 'Forced Log Out!');
        expect(
          h.auth.accessFailure!.message,
          contains('We are sorry for the disturbance.'),
        );
        expect(h.posts.where((p) => p.uri.path.endsWith('loginLog')), isEmpty);
        expect(h.vault.clears, 0);
        h.auth.cancelSelection();
        expect(h.auth.stage, AuthStage.accountBlocked);
        await h.auth.acknowledgeAccess();
        expect(h.auth.stage, AuthStage.signedOut);
        expect(h.vault.clears, 1);
      },
    );

    test(
      '$role disabled mobile access has the exact native denial message',
      () async {
        final h = _account(admin);
        (admin ? h.adminData : h.doctorData)[admin
                ? 'usr_mob_app_access'
                : 'access_flag'] =
            '0';
        await h.signIn();
        expect(h.auth.stage, AuthStage.accountBlocked);
        expect(h.auth.accessFailure!.reason, AccountAccessReason.mobileAccess);
        expect(
          h.auth.accessFailure!.message,
          'You have no permission to access this app. Please contact with administrator to access this app.',
        );
        expect(h.posts.where((p) => p.uri.path.endsWith('loginLog')), isEmpty);
        expect(h.vault.saves, 0);
      },
    );

    test(
      '$role expiry stays valid today and rejects yesterday before dashboard reads',
      () async {
        final h = _account(admin);
        final values = admin ? h.adminData : h.doctorData;
        values['exp_date'] = oracleDate(h.now);
        await h.signIn();
        expect(h.auth.stage, AuthStage.authenticated);
        final warning =
            AccountExpiryWarning.forDate(h.auth.profile!.expiryDate, h.now)!;
        expect(warning.daysLeft, 0);
        h.now = h.now.add(const Duration(days: 1));
        final before = h.transport.requests.length;
        await expectLater(
          DashboardRepository(
            h.transport,
            now: () => h.now,
          ).load(h.auth.session!, h.auth.profile!, SummaryPeriod.today),
          throwsA(
            isA<AccountAccessFailure>().having(
              (f) => f.reason,
              'reason',
              AccountAccessReason.expired,
            ),
          ),
        );
        expect(h.transport.requests.length, before);
      },
    );

    test(
      '$role read-only revalidation does not reset flags or insert login records',
      () async {
        final h = _account(admin);
        await h.signIn();
        final posts = h.posts.length;
        final profile = await h.profiles.open(
          h.auth.session!,
          recordLogin: false,
        );
        ProfileRepository.checkAccess(profile, h.now);
        expect(h.posts.length, posts);
      },
    );
  }

  test(
    'warning covers 0 to 3 calendar days and crosses month/year boundaries',
    () {
      final now = DateTime(2026, 12, 30, 23, 59);
      for (final days in [-1, 0, 1, 2, 3, 4]) {
        final expiry = oracleDate(now.add(Duration(days: days)));
        final warning = AccountExpiryWarning.forDate(expiry, now);
        if (days >= 0 && days <= 3) {
          expect(warning!.daysLeft, days);
          expect(warning.message, contains('($days day(s) left).'));
        } else {
          expect(warning, isNull);
        }
      }
    },
  );

  test(
    'inactive doctor status/effective date take precedence over the force flag',
    () async {
      final h = _account(false);
      h.doctorData.addAll({
        'user_avail': '0',
        'doc_status': 'Resigned',
        'doc_eff_date': '01-OCT-26',
        'fl_flag': '1',
      });
      await h.signIn();
      expect(h.auth.accessFailure!.title, 'Access Denied!');
      expect(
        h.auth.accessFailure!.message,
        'Your status is: Resigned, with effected date: 01-OCT-26. So, You are not eligible to access this app.',
      );
      expect(h.posts.where((p) => p.uri.path.endsWith('loginLog')), isEmpty);
    },
  );

  test(
    'empty doctor and admin responses keep their different native dialogs',
    () async {
      for (final admin in [false, true]) {
        final h = _account(admin);
        h.transport.onGet =
            (uri) async =>
                uri.path.endsWith(admin ? 'getAdminData' : 'getDocData')
                    ? {'count': 0, 'items': null}
                    : h.defaultGet(uri);
        await h.signIn();
        expect(h.auth.stage, AuthStage.accountBlocked);
        expect(
          h.auth.accessFailure!.title,
          admin ? 'No Information Found!' : 'Access Denied!',
        );
        expect(
          h.auth.accessFailure!.message,
          admin
              ? 'No Admin Information found for this Id. Please contact with Administrator.'
              : 'No User Data Found',
        );
      }
    },
  );

  test(
    'a missing established expiry is retryable and never invents an extension',
    () async {
      final h = _account(false);
      h.doctorData['exp_date'] = null;
      await h.signIn();
      expect(h.auth.stage, AuthStage.accountError);
      expect(h.vault.saves, 0);
      expect(
        h.posts.where((p) => p.uri.path.contains('updateDocExpDate')),
        isEmpty,
      );
      expect(h.posts.where((p) => p.uri.path.endsWith('loginLog')), isEmpty);
    },
  );

  test(
    'a generated first-login expiry remains in the effective profile',
    () async {
      final h = _account(false);
      h.doctorData.addAll({'doc_app_first_login_flag': '0', 'exp_date': null});
      await h.signIn();
      expect(h.auth.profile!.expiryDate, '15-JAN-27');
      expect(
        h.posts.where((p) => p.uri.path.endsWith('updateDocExpDate')).length,
        1,
      );
      expect(h.posts.where((p) => p.uri.path.endsWith('loginLog')).length, 1);
    },
  );

  test('profile Retry does not repeat the login forced-flag reset', () async {
    final h = _account(false);
    var fail = true;
    h.transport.onPost = (uri, headers) async {
      if (uri.path.endsWith('loginLog') && fail) {
        fail = false;
        throw const AppFailure('Login log temporarily unavailable');
      }
      return {'string_out': 'Successfully Created'};
    };
    await h.signIn();
    expect(h.auth.stage, AuthStage.accountError);
    await h.auth.retryAccount();
    expect(h.auth.stage, AuthStage.authenticated);
    expect(h.posts.where((p) => p.uri.path.endsWith('updateFLFlag')).length, 1);
    expect(h.posts.where((p) => p.uri.path.endsWith('loginLog')).length, 2);
  });

  test(
    'storage Retry rechecks revoked access without inserting another login log',
    () async {
      final h = _account(false);
      h.vault.failSave = true;
      await h.signIn();
      expect(h.auth.stage, AuthStage.accountError);
      final writes = h.posts.length;
      h.vault.failSave = false;
      h.doctorData['fl_flag'] = '1';
      await h.auth.retryAccount();
      expect(h.auth.stage, AuthStage.accountBlocked);
      expect(h.auth.accessFailure!.reason, AccountAccessReason.forcedLogout);
      expect(h.vault.saves, 0);
      expect(h.posts.length, writes);
    },
  );

  test(
    'failed logout retries session removal instead of authenticating again',
    () async {
      final h = _account(false);
      await h.signIn();
      h.vault.failClear = true;
      await h.auth.logout();
      expect(h.auth.logoutPending, isTrue);
      expect(h.auth.profile, isNull);
      final requests = h.transport.requests.length;
      h.vault.failClear = false;
      await h.auth.initialize();
      expect(h.auth.stage, AuthStage.signedOut);
      expect(h.vault.state.session, isNull);
      expect(h.transport.requests.length, requests);
    },
  );

  test(
    'an obsolete profile response cannot queue initialization or login POSTs',
    () async {
      final h = _account(false);
      await h.signIn();
      final pending = Completer<JsonMap>();
      final started = Completer<void>();
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getDocData')) {
          started.complete();
          return pending.future;
        }
        return h.defaultGet(uri);
      };
      var current = true;
      final posts = h.posts.length;
      final request = h.profiles.open(
        h.auth.session!,
        isCurrent: () => current,
      );
      await started.future;
      current = false;
      final assertion = expectLater(request, throwsA(isA<ObsoleteRequest>()));
      pending.complete({
        'count': 1,
        'items': [h.doctorData],
      });
      await assertion;
      expect(h.posts.length, posts);
    },
  );

  test(
    'missing or invalid fresh force flags cannot approve summary or chart reads',
    () async {
      final h = _account(true);
      await h.signIn();
      for (final flag in <JsonMap>[
        {},
        {'fl_flag': 'unexpected'},
      ]) {
        h.transport.onGet =
            (_) async => {
              'count': 1,
              'items': [flag],
            };
        final before = h.transport.requests.length;
        await expectLater(
          DashboardRepository(
            h.transport,
            now: () => h.now,
          ).load(h.auth.session!, h.auth.profile!, SummaryPeriod.today),
          throwsA(isA<AppFailure>()),
        );
        expect(h.transport.requests.length, before + 1);
        await expectLater(
          AdminChartRepository(h.transport, now: () => h.now).loadBoth(
            h.auth.session!,
            h.auth.profile!,
            AdminChartType.all,
            AdminChartSelection(AdminChartMode.monthly, h.now),
          ),
          throwsA(isA<AppFailure>()),
        );
        expect(h.transport.requests.length, before + 2);
      }
    },
  );

  test(
    'incomplete admin totals are an error rather than fabricated zero values',
    () async {
      final h = _account(true);
      await h.signIn();
      h.transport.onGet =
          (uri) async =>
              uri.path.endsWith('getAdminAppPayCountNew')
                  ? {'total_app_count': '10'}
                  : h.defaultGet(uri);
      await expectLater(
        DashboardRepository(
          h.transport,
          now: () => h.now,
        ).load(h.auth.session!, h.auth.profile!, SummaryPeriod.today),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.kind,
            'kind',
            FailureKind.invalidData,
          ),
        ),
      );
    },
  );

  test(
    'expiry crossing midnight during a dashboard response cannot commit data',
    () async {
      for (final admin in [false, true]) {
        final h = _account(admin);
        (admin ? h.adminData : h.doctorData)['exp_date'] = oracleDate(h.now);
        await h.signIn();
        h.transport.onGet = (uri) async {
          if (uri.path.endsWith(
            admin ? 'getAdminAppPayCountNew' : 'getMeetingSchedule',
          )) {
            h.now = h.now.add(const Duration(days: 1));
          }
          return h.defaultGet(uri);
        };
        await expectLater(
          DashboardRepository(
            h.transport,
            now: () => h.now,
          ).load(h.auth.session!, h.auth.profile!, SummaryPeriod.today),
          throwsA(
            isA<AccountAccessFailure>().having(
              (f) => f.reason,
              'reason',
              AccountAccessReason.expired,
            ),
          ),
        );
      }
    },
  );
}

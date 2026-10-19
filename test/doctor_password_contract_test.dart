import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/profile/doctor_password_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_support.dart';
import 'support.dart';

const _old = 'test-only-password';
const _change = DoctorPasswordChange(
  current: _old,
  next: 'Next+&/?#123',
  confirm: 'Next+&/?#123',
);
Future<void> _update(
  Harness h, {
  DoctorPasswordChange change = _change,
  AccountProfile? profile,
  bool Function()? current,
  bool Function()? foreground,
}) => DoctorPasswordRepository(h.transport, now: () => h.now).update(
  h.auth.session!,
  profile ?? h.auth.profile!,
  change,
  isCurrent: current ?? () => true,
  isForeground: foreground ?? () => true,
);

void main() {
  test('validation follows native order and exact helper/toast messages', () {
    final cases = <(DoctorPasswordChange, DoctorPasswordField, String, String)>[
      (
        const DoctorPasswordChange(current: '', next: '', confirm: ''),
        DoctorPasswordField.current,
        'Please Provide Current Password',
        'Please Provide Current Password',
      ),
      (
        const DoctorPasswordChange(current: 'wrong', next: '', confirm: ''),
        DoctorPasswordField.current,
        'Current Password is Wrong',
        'Current Password is Wrong',
      ),
      (
        const DoctorPasswordChange(current: _old, next: '', confirm: ''),
        DoctorPasswordField.newPassword,
        'Please Provide New Password',
        'Please Provide New Password to Update',
      ),
      (
        const DoctorPasswordChange(
          current: _old,
          next: 'new pass',
          confirm: '',
        ),
        DoctorPasswordField.newPassword,
        DoctorPasswordChange.invalidCharacters,
        DoctorPasswordChange.invalidCharacters,
      ),
      (
        const DoctorPasswordChange(current: _old, next: _old, confirm: ''),
        DoctorPasswordField.newPassword,
        'New Password is matched with Current Password.',
        'New Password is matched with Current Password.',
      ),
      (
        const DoctorPasswordChange(current: _old, next: 'new', confirm: ''),
        DoctorPasswordField.confirm,
        'Please Provide Confirm Password',
        'Please Provide Confirm Password to Update',
      ),
      (
        const DoctorPasswordChange(
          current: _old,
          next: 'new',
          confirm: 'bad pass',
        ),
        DoctorPasswordField.confirm,
        DoctorPasswordChange.invalidCharacters,
        DoctorPasswordChange.invalidCharacters,
      ),
      (
        const DoctorPasswordChange(
          current: _old,
          next: 'new',
          confirm: 'different',
        ),
        DoctorPasswordField.confirm,
        'Confirm Password did not match',
        'Confirm Password did not match',
      ),
    ];
    for (final (change, field, helper, notice) in cases) {
      final problem = change.validate(_old)!;
      expect(problem.field, field);
      expect(problem.helper, helper);
      expect(problem.notice, notice);
    }
  });
  test(
    'native forbidden characters and unsafe header controls fail without new password policy',
    () {
      for (final invalid in [
        'a b',
        "a'b",
        'a"b',
        'a\nb',
        'a\rb',
        'a\tb',
        'a\u0000b',
        'a\u007fb',
      ]) {
        expect(
          DoctorPasswordChange(
            current: _old,
            next: invalid,
            confirm: invalid,
          ).validate(_old)?.field,
          DoctorPasswordField.newPassword,
        );
        expect(
          DoctorPasswordChange(
            current: _old,
            next: 'ok',
            confirm: invalid,
          ).validate(_old)?.field,
          DoctorPasswordField.confirm,
        );
      }
      for (final valid in [
        'x',
        'null',
        'Next+&/?#123',
        'a;b:c@d=e!',
        'বাংলা',
      ]) {
        expect(
          DoctorPasswordChange(
            current: _old,
            next: valid,
            confirm: valid,
          ).validate(_old),
          isNull,
        );
      }
    },
  );
  test(
    'password comparisons are exact and diagnostic strings redact values',
    () {
      expect(
        const DoctorPasswordChange(
          current: 'TEST-ONLY-PASSWORD',
          next: 'new',
          confirm: 'new',
        ).validate(_old)?.field,
        DoctorPasswordField.current,
      );
      expect(
        const DoctorPasswordChange(
          current: _old,
          next: 'new',
          confirm: 'NEW',
        ).validate(_old)?.field,
        DoctorPasswordField.confirm,
      );
      expect(_change.toString(), 'DoctorPasswordChange(<redacted>)');
      expect(_change.toString(), isNot(contains(_old)));
      expect(
        const Credentials('01700000000', 'secret').toString(),
        isNot(contains('secret')),
      );
    },
  );
  test(
    'update uses only native P_DOC_ID/P_PASS headers at exact endpoint',
    () async {
      final h = profileHarness();
      await h.signIn();
      final writes = h.posts.length;
      await _update(h);
      expect(h.posts.length, writes + 1);
      final request = h.posts.last;
      expect(
        request.uri.toString(),
        'https://centre.example/api/doc_profile/updatePassword',
      );
      expect(request.headers, {'P_DOC_ID': '10', 'P_PASS': 'Next+&/?#123'});
      expect(request.uri.hasQuery, isFalse);
      expect(h.transport.binaryRequests, isEmpty);
      final flag = h.transport.requests[h.transport.requests.length - 2];
      expect(flag.uri.path, endsWith('/doc_dashboard/getDocFLFlag'));
      expect(flag.uri.queryParameters, {'p_doc_id': '10'});
      expect(h.vault.passwordChanges, 0);
    },
  );
  test(
    'invalid fields dispatch no request and cannot change saved credentials',
    () async {
      final h = profileHarness();
      await h.signIn();
      final requests = h.transport.requests.length;
      for (final change in [
        const DoctorPasswordChange(
          current: 'wrong',
          next: 'new',
          confirm: 'new',
        ),
        const DoctorPasswordChange(
          current: _old,
          next: 'new pass',
          confirm: 'new pass',
        ),
        const DoctorPasswordChange(
          current: _old,
          next: 'new',
          confirm: 'different',
        ),
      ]) {
        await expectLater(
          _update(h, change: change),
          throwsA(isA<AppFailure>()),
        );
      }
      expect(h.transport.requests.length, requests);
      expect(h.vault.passwordChanges, 0);
    },
  );
  test(
    'admin, cross-doctor, unavailable, denied and expired profiles cannot dispatch',
    () async {
      final h = profileHarness();
      await h.signIn();
      final requests = h.transport.requests.length;
      for (final profile in [
        AccountProfile(AccountRole.admin, adminProfile()),
        AccountProfile(AccountRole.doctor, {
          ...h.doctorData,
          'doc_code': 'D-OTHER',
        }),
        AccountProfile(AccountRole.doctor, {
          ...h.doctorData,
          'user_avail': '0',
        }),
        AccountProfile(AccountRole.doctor, {
          ...h.doctorData,
          'access_flag': '0',
        }),
        AccountProfile(AccountRole.doctor, {
          ...h.doctorData,
          'exp_date': '01-JAN-20',
        }),
      ]) {
        await expectLater(
          _update(h, profile: profile),
          throwsA(isA<AppFailure>()),
        );
      }
      expect(h.transport.requests.length, requests);
    },
  );
  test('missing and forced-logout preflight flags prevent POST', () async {
    final h = profileHarness();
    await h.signIn();
    final writes = h.posts.length;
    for (final response in <JsonMap>[
      {'count': 0, 'items': null},
      {
        'items': [
          {'fl_flag': '1'},
        ],
      },
      {
        'items': [
          {'fl_flag': 'unknown'},
        ],
      },
      {
        'items': [<String, Object?>{}],
      },
    ]) {
      h.transport.onGet = (_) async => response;
      await expectLater(_update(h), throwsA(isA<AppFailure>()));
    }
    expect(h.posts.length, writes);
  });
  test(
    'only exact native success completes and failures never auto retry',
    () async {
      final h = profileHarness();
      await h.signIn();
      final writes = h.posts.length;
      for (final response in <JsonMap>[
        {},
        {'string_out': null},
        {'string_out': 'successfully created'},
        {'string_out': 'Rejected'},
      ]) {
        h.transport.onPost = (_, _) async => response;
        await expectLater(_update(h), throwsA(isA<AppFailure>()));
      }
      h.transport.onPost =
          (_, _) async => throw const AppFailure('Network interrupted');
      await expectLater(_update(h), throwsA(isA<AppFailure>()));
      expect(h.posts.length, writes + 5);
      expect(h.vault.passwordChanges, 0);
    },
  );
  test(
    'background or account change during preflight prevents dispatch',
    () async {
      for (final obsolete in [false, true]) {
        final h = profileHarness();
        await h.signIn();
        var current = true, foreground = true;
        h.transport.onGet = (_) async {
          if (obsolete) {
            current = false;
          } else {
            foreground = false;
          }
          return {
            'items': [
              {'fl_flag': '0'},
            ],
          };
        };
        final writes = h.posts.length;
        await expectLater(
          _update(h, current: () => current, foreground: () => foreground),
          throwsA(isA<ObsoleteRequest>()),
        );
        expect(h.posts.length, writes);
      }
    },
  );
  test(
    'background success completes the same dispatched POST and stale success is ignored',
    () async {
      final h = profileHarness();
      await h.signIn();
      var foreground = true;
      h.transport.onPost = (_, _) async {
        foreground = false;
        return {'string_out': 'Successfully Created'};
      };
      await _update(h, foreground: () => foreground);
      var current = true;
      h.transport.onPost = (_, _) async {
        current = false;
        return {'string_out': 'Successfully Created'};
      };
      await expectLater(
        _update(h, current: () => current),
        throwsA(isA<ObsoleteRequest>()),
      );
      expect(
        h.posts.where((r) => r.uri.path.endsWith('updatePassword')),
        hasLength(2),
      );
    },
  );
}

import 'dart:async';
import 'dart:convert';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/account_access.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_repository.dart';
import 'package:docdiary_ios/features/hr/leave_approval/leave_approval_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'leave_approval_test_support.dart';

void main() {
  late LeaveApprovalHarness h;
  setUp(() async {
    h = LeaveApprovalHarness();
    await h.signIn();
    h.transport.requests.clear();
  });
  tearDown(() => h.auth.dispose());
  LeaveApprovalRequest request() =>
      LeaveApprovalRequest.fromJson(approvalRequest());
  Future<List<LeaveApprovalRequest>> pending({
    bool Function()? current,
    AccountProfile? profile,
  }) async => await h.approval.pending(
    h.auth.session!,
    profile ?? h.auth.profile!,
    isCurrent: current ?? () => true,
  );
  Future<LeaveApprovalDetail?> detail() async => await h.approval.detail(
    h.auth.session!,
    h.auth.profile!,
    request(),
    isCurrent: () => true,
  );
  Future<LeaveApprovalResult> submit({
    LeaveApprovalAction action = LeaveApprovalAction.approve,
    String comment = '',
    bool checked = false,
    JsonMap? data,
    bool Function()? current,
    AccountProfile? profile,
  }) async => await h.approval.submit(
    h.auth.session!,
    profile ?? h.auth.profile!,
    request(),
    LeaveApprovalDetail(data ?? approvalDetail()),
    action,
    comment,
    prescriptionChecked: checked,
    isCurrent: current ?? () => true,
  );

  test(
    'native list and detail use selected centre, usr_name and LA ID',
    () async {
      final rows = await pending();
      final value = await detail();
      expect(rows.map((r) => r.id), ['41', '42']);
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getLeaveRequestList',
        'getLeaveData',
      ]);
      expect(h.hrRequests.first.uri.queryParameters, {
        'p_usr_name': h.auth.profile!.value('usr_name'),
      });
      expect(h.hrRequests.last.uri.queryParameters, {
        'p_la_id': '41',
        'p_usr_name': h.auth.profile!.value('usr_name'),
      });
      expect(
        h.hrRequests.every(
          (r) => r.uri.host == h.auth.session!.center.baseUri.host,
        ),
        isTrue,
      );
      expect(value!.hasEnoughBalance, isTrue);
      expect(value.isSickLeave, isFalse);
    },
  );
  test(
    'query encoding, name/code search and identity survive no matches',
    () async {
      await pending(
        profile: AccountProfile(AccountRole.admin, {
          ...h.auth.profile!.values,
          'usr_name': 'A & B+পরীক্ষা',
        }),
      );
      expect(
        h.hrRequests.single.uri.queryParameters['p_usr_name'],
        'A & B+পরীক্ষা',
      );
      final row = request();
      expect(row.matches('lr-26-0041'), isTrue);
      expect(row.matches('EMPLOYEE A'), isTrue);
      expect(row.matches('missing'), isFalse);
      expect(row.matches(''), isTrue);
      expect(row.cells, [
        'LR-26-0041',
        'Example Employee A',
        'E-11',
        '20-OCT-26',
        '2',
      ]);
      expect(
        row.sameRequest(
          LeaveApprovalRequest.fromJson(approvalRequest(employee: '99')),
        ),
        isFalse,
      );
    },
  );
  test(
    'encoded arrays, numeric IDs, null defaults and last detail row match native',
    () async {
      h.transport.onGet =
          (_) async => {
            'count': '1',
            'items': jsonEncode([
              {
                ...approvalRequest(),
                'la_id': 41,
                'la_emp_id': 11,
                'emp_name': null,
              },
            ]),
          };
      final row = (await pending()).single;
      expect(row.id, '41');
      expect(row.employeeName, '');
      h.transport.onGet =
          (_) async => {
            'count': 2,
            'items': [
              approvalDetail(),
              {
                ...approvalDetail(),
                'emp_name': 'Last',
                'la_reason': null,
                'la_leave_days': 'null',
                'leave_balance': null,
              },
            ],
          };
      final d = (await detail())!;
      expect(d.value('emp_name'), 'Last');
      expect(d.value('la_reason'), '');
      expect(d.value('la_leave_days'), '0');
      expect(d.value('leave_balance'), '0');
    },
  );
  test('repeated native rows remain in returned order', () async {
    h.requests = [
      approvalRequest(),
      approvalRequest(),
      approvalRequest(code: 'OTHER'),
    ];
    final rows = await pending();
    expect(rows.length, 3);
    expect(rows.last.code, 'OTHER');
  });
  test('count zero cannot fabricate an approvable record', () async {
    h.transport.onGet = (_) async => {'count': '0', 'items': 'ignored'};
    expect(await pending(), isEmpty);
    expect(await detail(), isNull);
  });
  for (final payload in <JsonMap>[
    {},
    {'count': -1},
    {'count': 'bad'},
    {'count': 1},
    {'count': 1, 'items': []},
    {'count': 1, 'items': 'bad'},
    {
      'count': 1,
      'items': [<String, Object?>{}],
    },
    {
      'count': 1,
      'items': [
        {...approvalRequest(), 'la_id': null},
      ],
    },
    {
      'count': 1,
      'items': [
        {...approvalRequest(), 'emp_code': true},
      ],
    },
  ]) {
    test(
      'malformed pending response ${jsonEncode(payload)} fails clearly',
      () async {
        h.transport.onGet = (_) async => payload;
        await expectLater(pending(), throwsA(isA<AppFailure>()));
      },
    );
  }
  test(
    'missing or nested detail fields identify the field without personal values',
    () async {
      for (final key in LeaveApprovalDetail.keys) {
        for (final nested in [false, true]) {
          final row = {...approvalDetail()};
          if (nested) {
            row[key] = <String, Object?>{};
          } else {
            row.remove(key);
          }
          h.details = [row];
          await expectLater(
            detail(),
            throwsA(
              isA<AppFailure>().having(
                (e) => e.message,
                'detail',
                contains('"$key"'),
              ),
            ),
          );
        }
      }
    },
  );
  for (final spec in [
    ('1', '2', false),
    ('2', '2', true),
    ('2.5', '2.25', true),
    ('-1', '0', false),
    ('0', '0', true),
  ]) {
    test('balance ${spec.$1} and days ${spec.$2} compare without rounding', () {
      expect(
        LeaveApprovalDetail(
          approvalDetail(balance: spec.$1, days: spec.$2),
        ).hasEnoughBalance,
        spec.$3,
      );
    });
  }
  for (final spec in [
    ('NaN', '2'),
    ('Infinity', '2'),
    ('10', 'wrong'),
    ('10', '-1'),
  ]) {
    test('invalid quantities $spec cannot become an approval', () {
      expect(
        () => LeaveApprovalDetail(
          approvalDetail(balance: spec.$1, days: spec.$2),
        ),
        throwsA(isA<AppFailure>()),
      );
    });
  }
  test(
    'seed keeps the exact native identifiers and rejects incomplete identity',
    () {
      final row =
          LeaveApprovalSeed.fromExtras({
            'FLAG': '1',
            'LA_ID': '41',
            'LA_APP_CODE': 'LR-26-0041',
            'LA_EMP_ID': '11',
          }).request;
      expect(row.sameRequest(request()), isTrue);
      expect(LeaveApprovalSeed.fromExtras({}).request.valid, isFalse);
    },
  );
  for (final shortCode in ['CL', 'SL', 'sl']) {
    for (final checked in [false, true]) {
      test(
        '$shortCode prescription=$checked posts exactly four approve headers',
        () async {
          final result = await submit(
            checked: checked,
            data: approvalDetail(shortCode: shortCode),
          );
          expect(result.succeeded, isTrue);
          expect(h.hrRequests.map((r) => r.method), ['GET', 'POST']);
          final post = h.hrRequests.last;
          expect(post.uri.pathSegments.last, 'approveLeave');
          expect(post.uri.hasQuery, isFalse);
          expect(post.headers, {
            'P_LA_ID': '41',
            'P_USR_NAME': h.auth.profile!.value('usr_name'),
            'P_SL_CHECK': shortCode == 'SL' && checked ? '1' : '0',
            'P_TEXT_COMMENTS': '',
          });
        },
      );
    }
  }
  test('reject has only three native headers and preserves comment', () async {
    expect(
      (await submit(
        action: LeaveApprovalAction.reject,
        comment: '  Incorrect days  ',
        checked: true,
      )).succeeded,
      isTrue,
    );
    expect(h.hrRequests.last.uri.pathSegments.last, 'rejectLeave');
    expect(h.hrRequests.last.headers, {
      'P_LA_ID': '41',
      'P_USR_NAME': h.auth.profile!.value('usr_name'),
      'P_TEXT_COMMENTS': '  Incorrect days  ',
    });
  });
  test(
    'insufficient balance blocks approve but does not block reasoned reject',
    () async {
      await expectLater(
        submit(data: approvalDetail(balance: '1')),
        throwsA(isA<AppFailure>()),
      );
      expect(h.hrRequests, isEmpty);
      expect(
        (await submit(
          action: LeaveApprovalAction.reject,
          comment: 'Insufficient',
          data: approvalDetail(balance: '1'),
        )).succeeded,
        isTrue,
      );
    },
  );
  test(
    'blank reject reason and unsupported header text fail before IO',
    () async {
      for (final text in ['', '   ']) {
        await expectLater(
          submit(action: LeaveApprovalAction.reject, comment: text),
          throwsA(isA<AppFailure>()),
        );
      }
      for (final text in [
        'বাংলা মন্তব্য',
        'line\nbreak',
        'line\rbreak',
        'a\u0000b',
      ]) {
        await expectLater(submit(comment: text), throwsA(isA<AppFailure>()));
      }
      expect(h.hrRequests, isEmpty);
    },
  );
  test(
    'changed pending identity prevents submit even if display code is reused',
    () async {
      for (final rows in [
        <JsonMap>[],
        [approvalRequest(id: '99')],
        [approvalRequest(employee: '99')],
      ]) {
        h.requests = rows;
        await expectLater(
          submit(),
          throwsA(isA<LeaveRequestNoLongerPending>()),
        );
      }
      expect(h.hrRequests.where((r) => r.method == 'POST'), isEmpty);
    },
  );
  for (final message in ['ok', 'OK', 'oK', 'Already approved', ' ok ']) {
    test(
      'updated_req=$message uses exact native case-insensitive ok',
      () async {
        h.response = {
          'string_out': 'Successfully Created',
          'updated_req': message,
        };
        final result = await submit();
        expect(result.succeeded, message.toLowerCase() == 'ok');
        expect(result.message, message);
      },
    );
  }
  for (final payload in <JsonMap>[
    {},
    {'string_out': 'Database validation failed'},
    {'string_out': 'Successfully Created'},
    {'string_out': 'Successfully Created', 'updated_req': null},
    {'string_out': 'Successfully Created', 'updated_req': <String>[]},
  ]) {
    test(
      'unconfirmed response ${jsonEncode(payload)} never claims success or retries',
      () async {
        h.response = payload;
        await expectLater(submit(), throwsA(isA<AppFailure>()));
        expect(h.hrRequests.where((r) => r.method == 'POST').length, 1);
      },
    );
  }
  test('timed out POST is never automatically repeated', () async {
    h.transport.onPost =
        (_, __) async =>
            throw const AppFailure('Timed out', kind: FailureKind.network);
    await expectLater(submit(), throwsA(isA<AppFailure>()));
    expect(h.hrRequests.where((r) => r.method == 'POST').length, 1);
  });
  test(
    'obsolete list and pending-before-write discard late responses',
    () async {
      await expectLater(
        pending(current: () => false),
        throwsA(isA<ObsoleteRequest>()),
      );
      expect(h.hrRequests, isEmpty);
      var current = true;
      final gate = Completer<JsonMap>();
      h.transport.onGet = (_) => gate.future;
      final future = submit(current: () => current);
      current = false;
      gate.complete({
        'count': 1,
        'items': [approvalRequest()],
      });
      await expectLater(future, throwsA(isA<ObsoleteRequest>()));
      expect(h.hrRequests.where((r) => r.method == 'POST'), isEmpty);
    },
  );
  test(
    'access revoke, forced logout, expiry and identity mismatch block IO',
    () async {
      for (final override in <JsonMap>[
        {'hr_acc_active_flag': '0'},
        {'hr_dashboard': '0', 'all_access_flag': '0'},
        {'usr_mob_forced_log_out_flag': '1'},
        {'usr_mob_app_access': '0'},
        {'exp_date': '01-JAN-20'},
        {'usr_name': ''},
        {'usr_id': 'another'},
      ]) {
        await expectLater(
          submit(
            profile: AccountProfile(AccountRole.admin, {
              ...h.auth.profile!.values,
              ...override,
            }),
          ),
          throwsA(
            anyOf(
              isA<AppFailure>(),
              isA<HrModuleUnavailable>(),
              isA<AccountAccessFailure>(),
            ),
          ),
        );
      }
      expect(h.hrRequests, isEmpty);
    },
  );
}

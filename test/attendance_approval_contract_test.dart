import 'dart:async';
import 'dart:convert';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/account_access.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/hr/attendance_update_approval/attendance_approval_models.dart';
import 'package:docdiary_ios/features/hr/hr_dashboard_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'attendance_approval_test_support.dart';

void main() {
  late AttendanceApprovalHarness h;
  setUp(() async {
    h = AttendanceApprovalHarness();
    await h.signIn();
    h.transport.requests.clear();
  });
  tearDown(() => h.auth.dispose());
  AttendanceApprovalRequest request() =>
      AttendanceApprovalRequest.fromJson(approvalRequest());
  Future<List<AttendanceApprovalRequest>> pending({
    bool Function()? current,
  }) async => await h.approval.pending(
    h.auth.session!,
    h.auth.profile!,
    isCurrent: current ?? () => true,
  );
  Future<AttendanceApprovalResult> submit({
    AttendanceApprovalAction action = AttendanceApprovalAction.approve,
    String comment = '',
    bool Function()? current,
    AccountProfile? profile,
  }) async => await h.approval.submit(
    h.auth.session!,
    profile ?? h.auth.profile!,
    request(),
    AttendanceApprovalDetail(approvalDetail()),
    action,
    comment,
    isCurrent: current ?? () => true,
  );

  test(
    'native list and detail queries use the selected centre and usr_name even with all access',
    () async {
      final rows = await pending();
      final detail = await h.approval.detail(
        h.auth.session!,
        h.auth.profile!,
        rows.first,
        isCurrent: () => true,
      );
      expect(rows.map((r) => r.id), ['41', '42']);
      expect(h.hrRequests.map((r) => r.uri.pathSegments.last), [
        'getAttUpReqList',
        'getAttUpdateData',
      ]);
      expect(h.hrRequests[0].uri.queryParameters, {
        'p_usr_name': h.auth.profile!.value('usr_name'),
      });
      expect(h.hrRequests[1].uri.queryParameters, {
        'p_darm_app_code': 'AR-26-0041',
        'p_usr_name': h.auth.profile!.value('usr_name'),
      });
      expect(
        h.hrRequests.every(
          (r) => r.uri.host == h.auth.session!.center.baseUri.host,
        ),
        isTrue,
      );
      expect(detail!.hasIn && detail.hasOut && detail.hasForwarder, isTrue);
    },
  );
  test('query values encode ampersands and non ASCII names once', () async {
    final profile = AccountProfile(AccountRole.admin, {
      ...h.auth.profile!.values,
      'usr_name': 'A & B+পরীক্ষা',
    });
    await h.approval.pending(h.auth.session!, profile, isCurrent: () => true);
    expect(h.hrRequests.single.uri.queryParameters, {
      'p_usr_name': 'A & B+পরীক্ষা',
    });
  });
  test(
    'search is case insensitive by code or name; row identity is stable after zero results',
    () {
      final row = request();
      expect(row.matches('ar-26-0041'), isTrue);
      expect(row.matches('EMPLOYEE A'), isTrue);
      expect(row.matches('missing'), isFalse);
      expect(row.matches(''), isTrue);
      expect(
        row.sameRequest(
          AttendanceApprovalRequest.fromJson(approvalRequest(employee: '99')),
        ),
        isFalse,
      );
    },
  );
  test(
    'string encoded items, numeric IDs, null strings and final detail row follow native parsing',
    () async {
      h.transport.onGet =
          (uri) async => {
            'count': '1',
            'items': jsonEncode([
              {
                ...approvalRequest(),
                'darm_id': 41,
                'darm_emp_id': 11,
                'emp_name': null,
              },
            ]),
          };
      expect((await pending()).single.employeeName, '');
      h.transport.onGet =
          (uri) async => {
            'count': 2,
            'items': [
              approvalDetail(),
              {
                ...approvalDetail(),
                'emp_name': 'Last',
                'arrival_time': 'null',
                'departure_time': null,
                'forwarder_name': '',
              },
            ],
          };
      final detail = await h.approval.detail(
        h.auth.session!,
        h.auth.profile!,
        request(),
        isCurrent: () => true,
      );
      expect(detail!.value('emp_name'), 'Last');
      expect(detail.hasIn || detail.hasOut || detail.hasForwarder, isFalse);
    },
  );
  test(
    'count zero is empty and missing detail never fabricates an approvable record',
    () async {
      h.transport.onGet = (uri) async => {'count': '0', 'items': 'ignored'};
      expect(await pending(), isEmpty);
      expect(
        await h.approval.detail(
          h.auth.session!,
          h.auth.profile!,
          request(),
          isCurrent: () => true,
        ),
        isNull,
      );
    },
  );
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
        {...approvalRequest(), 'darm_id': null},
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
      'malformed list ${jsonEncode(payload)} fails without usable rows',
      () async {
        h.transport.onGet = (uri) async => payload;
        await expectLater(pending(), throwsA(isA<AppFailure>()));
      },
    );
  }
  test(
    'duplicate IDs or codes are rejected instead of approving an ambiguous row',
    () async {
      h.requests.add(approvalRequest(code: 'OTHER'));
      await expectLater(pending(), throwsA(isA<AppFailure>()));
      h.requests = [approvalRequest(), approvalRequest(id: '99')];
      await expectLater(pending(), throwsA(isA<AppFailure>()));
    },
  );
  test(
    'missing detail keys fail even when another final row is valid',
    () async {
      h.details = [
        {...approvalDetail()}..remove('reason'),
        approvalDetail(),
      ];
      await expectLater(
        h.approval.detail(
          h.auth.session!,
          h.auth.profile!,
          request(),
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'approve POST has exactly five native headers and no query/body, allows empty comments',
    () async {
      expect((await submit()).succeeded, isTrue);
      expect(h.hrRequests.map((r) => r.method), ['GET', 'POST']);
      final post = h.hrRequests.last;
      expect(post.uri.pathSegments.last, 'approveAttUpReq');
      expect(post.uri.hasQuery, isFalse);
      expect(post.headers, {
        'P_DARM_ID': '41',
        'P_USR_NAME': h.auth.profile!.value('usr_name'),
        'P_DARM_EMP_ID': '11',
        'P_UPDATE_DATE': '19-OCT-26',
        'P_TEXT_COMMENTS': '',
      });
    },
  );
  test(
    'reject POST uses exactly three headers, preserving supplied comment',
    () async {
      final result = await submit(
        action: AttendanceApprovalAction.reject,
        comment: 'Incorrect time',
      );
      expect(result.succeeded, isTrue);
      expect(h.hrRequests.last.uri.pathSegments.last, 'rejectAttUpReq');
      expect(h.hrRequests.last.headers, {
        'P_DARM_ID': '41',
        'P_USR_NAME': h.auth.profile!.value('usr_name'),
        'P_TEXT_COMMENTS': 'Incorrect time',
      });
    },
  );
  test('reject requires a real reason before any HR request', () async {
    for (final text in ['', '   ']) {
      await expectLater(
        submit(action: AttendanceApprovalAction.reject, comment: text),
        throwsA(isA<AppFailure>()),
      );
    }
    expect(h.hrRequests, isEmpty);
  });
  test(
    'non-ASCII header comments fail clearly before sending instead of becoming a network error',
    () async {
      await expectLater(
        submit(comment: 'বাংলা মন্তব্য'),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            contains('single line of English text'),
          ),
        ),
      );
      expect(h.hrRequests, isEmpty);
    },
  );
  test(
    'header controls and missing approval date fail before sending',
    () async {
      for (final text in ['x\r\ny', 'x\u0000y']) {
        await expectLater(submit(comment: text), throwsA(isA<AppFailure>()));
      }
      await expectLater(
        h.approval.submit(
          h.auth.session!,
          h.auth.profile!,
          request(),
          AttendanceApprovalDetail({
            ...approvalDetail(),
            'darm_update_date': '',
          }),
          AttendanceApprovalAction.approve,
          '',
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.hrRequests, isEmpty);
    },
  );
  test(
    'no longer pending stops the POST, including identical code with a new ID',
    () async {
      h.requests = [];
      await expectLater(
        submit(),
        throwsA(isA<AttendanceRequestNoLongerPending>()),
      );
      h.requests = [approvalRequest(id: '99')];
      await expectLater(
        submit(),
        throwsA(isA<AttendanceRequestNoLongerPending>()),
      );
      expect(h.hrRequests.where((r) => r.method == 'POST'), isEmpty);
    },
  );
  for (final result in ['ok', 'OK', 'oK', 'Already approved by another user']) {
    test(
      'updated_req=$result determines success independently of string_out',
      () async {
        h.response = {
          'string_out': 'Successfully Created',
          'updated_req': result,
        };
        final response = await submit();
        expect(response.succeeded, result.toLowerCase() == 'ok');
        expect(response.message, result);
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
      'unconfirmed write response ${jsonEncode(payload)} never reports success or retries',
      () async {
        h.response = payload;
        await expectLater(submit(), throwsA(isA<AppFailure>()));
        expect(h.hrRequests.where((r) => r.method == 'POST').length, 1);
      },
    );
  }
  test('network failures do not automatically retry a POST', () async {
    h.transport.onPost =
        (uri, headers) async =>
            throw const AppFailure('Timed out', kind: FailureKind.network);
    await expectLater(submit(), throwsA(isA<AppFailure>()));
    expect(h.hrRequests.where((r) => r.method == 'POST').length, 1);
  });
  test(
    'obsolete generation before and during list/read/write produces no usable stale result',
    () async {
      await expectLater(
        pending(current: () => false),
        throwsA(isA<ObsoleteRequest>()),
      );
      expect(h.hrRequests, isEmpty);
      final gate = Completer<JsonMap>();
      var current = true;
      h.transport.onGet = (uri) => gate.future;
      final future = pending(current: () => current);
      current = false;
      gate.complete({'count': 0});
      await expectLater(future, throwsA(isA<ObsoleteRequest>()));
    },
  );
  test(
    'obsolete pending check blocks submit; obsolete POST response cannot be consumed',
    () async {
      var current = true;
      final gate = Completer<JsonMap>();
      h.transport.onGet = (uri) => gate.future;
      final future = submit(current: () => current);
      current = false;
      gate.complete({
        'count': 1,
        'items': [approvalRequest()],
      });
      await expectLater(future, throwsA(isA<ObsoleteRequest>()));
      expect(h.hrRequests.where((r) => r.method == 'POST'), isEmpty);
      current = true;
      h.transport.onGet = h.respondApproval;
      final postGate = Completer<JsonMap>();
      final started = Completer<void>();
      h.transport.onPost = (uri, headers) {
        started.complete();
        return postGate.future;
      };
      final post = submit(current: () => current);
      await started.future;
      current = false;
      postGate.complete({
        'string_out': 'Successfully Created',
        'updated_req': 'ok',
      });
      await expectLater(post, throwsA(isA<ObsoleteRequest>()));
      expect(h.hrRequests.where((r) => r.method == 'POST').length, 1);
    },
  );
  test(
    'access revocation, forced logout, expiry, missing username and mismatched identity block all IO',
    () async {
      for (final override in <JsonMap>[
        {'hr_acc_active_flag': '0'},
        {'usr_mob_forced_log_out_flag': '1'},
        {'usr_mob_app_access': '0'},
        {'exp_date': '01-JAN-20'},
        {'usr_name': ''},
        {'usr_id': 'someone_else'},
      ]) {
        final profile = AccountProfile(AccountRole.admin, {
          ...h.auth.profile!.values,
          ...override,
        });
        await expectLater(
          submit(profile: profile),
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

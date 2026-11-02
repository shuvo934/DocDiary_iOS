import 'package:flutter_test/flutter_test.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/payments/payment_models.dart';
import 'package:docdiary_ios/features/payments/payment_update_models.dart';
import 'payment_update_test_support.dart';

void main() {
  late PaymentUpdateHarness h;
  setUp(() async {
    h = PaymentUpdateHarness();
    await h.signIn();
    h.transport.requests.clear();
  });
  tearDown(() => h.auth.dispose());
  Future<void> submit(
    PaymentUpdateSubmission s, {
    bool Function()? current,
    bool Function()? owns,
  }) async => await h.updateRepository.submitUpdate(
    h.auth.session!,
    h.profile,
    s,
    isCurrent: current ?? () => true,
    ownsResponse: owns ?? () => true,
  );
  PaymentUpdateSubmission edited({bool mode = true}) {
    h.adminData['is_pay_mode_active'] = mode ? '1' : '0';
    final d = h.updateDraft();
    d.add(h.edited(d.lines.first), replacing: d.lines.first);
    return PaymentUpdateSubmission(d, mode ? h.updateConfirmation(d) : null);
  }

  test(
    'native latest payment and suffix search contract, no year or user parameters',
    () async {
      h.encoded = true;
      final rows = await h.updateRepository.payments(
        h.auth.session!,
        h.profile,
        isCurrent: () => true,
      );
      await h.updateRepository.payments(
        h.auth.session!,
        h.profile,
        search: '26.00501',
        isCurrent: () => true,
      );
      expect(rows.map((r) => r.id), ['501', '502']);
      expect(h.paymentReads.map((r) => r.uri.pathSegments.last), [
        'getFiftyPaymentList',
        'getPaymentCodeList',
      ]);
      expect(h.paymentReads.first.uri.queryParameters, isEmpty);
      expect(h.paymentReads.last.uri.queryParameters, {'prm_code': '26.00501'});
      expect(
        h.paymentReads.every(
          (r) =>
              r.uri.host == 'centre.example' &&
              r.uri.path.contains('/payement_receive/'),
        ),
        true,
      );
    },
  );
  for (final input in ['', '.26.1', '26.1', 'PR.26.000501', 'pr.26.000501']) {
    test('payment search rejects invalid native input: $input', () {
      expect(paymentCodeSearchError(input), isNotNull);
    });
  }
  test(
    'details and saved methods bind to selected master ID and preserve original date',
    () async {
      h.encoded = true;
      final p = paymentRecord(h.payments.first);
      final rows = await h.updateRepository.details(
        h.auth.session!,
        h.profile,
        p,
        isCurrent: () => true,
      );
      final saved = await h.updateRepository.savedMethods(
        h.auth.session!,
        h.profile,
        p,
        isCurrent: () => true,
      );
      expect(p.value('prm_date'), '25-OCT-26');
      expect(rows.single.available, 1);
      expect(saved.single.savedId, '701');
      expect(saved.single.cents, 103000);
      expect(h.paymentReads.map((r) => r.uri.queryParameters), [
        {'prm_id': '501'},
        {'prm_id': '501'},
      ]);
    },
  );
  test('all_access_flag required even when payment menu is allowed', () async {
    final p = AccountProfile(AccountRole.admin, {
      ...h.adminData,
      'all_access_flag': '0',
    });
    await expectLater(
      h.updateRepository.payments(h.auth.session!, p, isCurrent: () => true),
      throwsA(isA<PaymentUpdateUnavailable>()),
    );
    expect(h.paymentReads, isEmpty);
  });
  test('payment access loss prevents update reads and writes', () async {
    final s = edited();
    h.adminData.addAll({
      'all_access_flag': '0',
      'hr_payment_active': '0',
      'acc_payment_active': '0',
    });
    await expectLater(submit(s), throwsA(isA<PaymentUnavailable>()));
    expect(h.paymentPosts, isEmpty);
  });
  test(
    'quantity may not fall below used amount, unit locks after cancel or return',
    () {
      h.details[0].addAll({
        'prd_qty': '5',
        'amount': '5000',
        'available_qty': '2',
        'prd_cancel_mark': '1',
        'prd_return_mark': '2',
      });
      final d = h.updateDraft(), row = d.lines.single;
      expect(row.used, 3);
      expect(row.canChangeUnit, false);
      expect(
        () => d.add(h.edited(row, quantity: 2), replacing: row),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => d.add(h.edited(row, quantity: 5, unit: '21'), replacing: row),
        throwsA(isA<AppFailure>()),
      );
      d.add(h.edited(row, quantity: 3), replacing: row);
      expect(d.lines.single.available, 0);
      expect([d.lines.single.cancel, d.lines.single.returned], [1, 2]);
    },
  );
  test('unused quantity permits unit changes, service ID remains fixed', () {
    final d = h.updateDraft(), row = d.lines.single;
    d.add(h.edited(row, unit: '21'), replacing: row);
    expect(d.lines.single.available, 2);
    expect(
      () => d.lines.single.edited(h.newLine()),
      throwsA(isA<AppFailure>()),
    );
  });
  test('duplicates rejected across existing and new service rows', () {
    final d = h.updateDraft();
    expect(() => d.add(d.lines.single.line), throwsA(isA<AppFailure>()));
    final n = h.newLine();
    d.add(n);
    expect(() => d.add(n), throwsA(isA<AppFailure>()));
    expect(d.lines.last.id, isEmpty);
    expect(d.lines.last.available, n.quantity);
  });
  test('any scheduled service blocks entire update draft', () {
    h.details[0]['prd_sched_avail_mark'] = '1';
    final d = h.updateDraft();
    expect(d.blocked, true);
    expect(() => d.add(h.newLine()), throwsA(isA<AppFailure>()));
    expect(() => PaymentUpdateSubmission(d, null), throwsA(isA<AppFailure>()));
  });
  test(
    'existing update and new insert use distinct native headers, no master write',
    () async {
      final d = h.updateDraft();
      d.add(h.edited(d.lines.first), replacing: d.lines.first);
      d.add(h.newLine());
      final s = PaymentUpdateSubmission(d, h.updateConfirmation(d));
      await submit(s);
      expect(s.complete, true);
      expect(s.payment.name, 'PR.26.000501');
      expect(h.paymentPosts.map((r) => r.uri.pathSegments.last), [
        'updatePaymentDetails',
        'insertPaymentDetails',
        'updatePaymentMode',
      ]);
      expect(h.paymentPosts.first.headers, {
        'P_PRD_USR': h.profile.value('usr_name'),
        'P_PRM_CODE': 'PR.26.000501',
        'P_PRD_ID': '601',
        'P_PFN_ID': '31',
        'P_DEPTS_ID': '20',
        'P_PRD_QTY': '2',
        'P_PRD_RATE': '1000',
        'P_TOP_CAT_RATE': '1200',
      });
      expect(h.paymentPosts[1].headers, {
        'P_PRD_USR': h.profile.value('usr_name'),
        'P_PRM_CODE': 'PR.26.000501',
        'P_PRM_ID': '501',
        'P_PFN_ID': '32',
        'P_DEPTS_ID': '21',
        'P_PRD_QTY': '1',
        'P_PRD_RATE': '800',
        'P_PRD_TOP_CAT_RATE': '1000',
        'P_PRD_PATIENT_CAT_ID': '3',
        'P_INSERT_TYPE_FLAG': '3',
      });
      expect(h.paymentPosts.last.headers, {
        'P_AMOUNT': '1854.00',
        'P_PMM_ID': '2',
        'P_PMD_ID': '12',
        'P_AD_ID': '112',
        'D_PRMD_ID': '',
        'P_PRM_ID': '501',
        'P_UPDATE_TYPE': '1',
      });
      expect(s.originalMethods.single.cents, 103000);
      await submit(s);
      expect(h.paymentPosts.length, 3);
    },
  );
  test(
    'method-only replacement deletes saved ID then inserts new allocation',
    () async {
      final d = h.updateDraft();
      final s = PaymentUpdateSubmission(
        d,
        h.updateConfirmation(d, replace: true),
      );
      await submit(s);
      expect(h.paymentPosts.map((r) => r.uri.pathSegments.last), [
        'updatePaymentMode',
        'updatePaymentMode',
      ]);
      expect(h.paymentPosts.map((r) => r.headers['P_UPDATE_TYPE']), ['2', '1']);
      expect(h.paymentPosts.map((r) => r.headers['D_PRMD_ID']), ['701', '']);
      expect(h.paymentPosts.map((r) => r.headers['P_AMOUNT']), [
        '1030.00',
        '1030.00',
      ]);
    },
  );
  test(
    'retained saved inactive method allowed without inventing a replacement',
    () async {
      final d = h.updateDraft();
      final q = PaymentQuote(total: d.total, charge: 3000, methods: []);
      final c = PaymentConfirmation(q, d.methods, saved: d.methods);
      final s = PaymentUpdateSubmission(d, c);
      expect(s.hasChanges, false);
      await expectLater(submit(s), throwsA(isA<AppFailure>()));
      expect(h.paymentPosts, isEmpty);
      expect(
        () => PaymentConfirmation(q, d.methods),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test('saved allocation identity and amount cannot be forged', () {
    final d = h.updateDraft(), q = h.updateConfirmation(h.updateDraft()).quote;
    for (final a in [
      PaymentAllocation(d.methods[0].method, 103000, savedId: '999'),
      PaymentAllocation(d.methods[0].method, 102999, savedId: '701'),
    ]) {
      expect(
        () => PaymentConfirmation(q, [a], saved: d.methods),
        throwsA(isA<AppFailure>()),
      );
    }
  });
  test(
    'negative remaining currency keeps correct sign after service reduction',
    () {
      expect(paymentMoney(-1, fixed: true), '-0.01');
      expect(paymentMoney(-103000, fixed: true), '-1030.00');
    },
  );
  test(
    'mode off changes only details, never loads or writes payment methods',
    () async {
      final s = edited(mode: false);
      await submit(s);
      expect(s.complete, true);
      expect(
        h.paymentPosts.single.uri.pathSegments.last,
        'updatePaymentDetails',
      );
      expect(h.paymentReads.map((r) => r.uri.pathSegments.last), [
        'getPaymentDetailsList',
      ]);
    },
  );
  test('unchanged details and unchanged methods produce no mutation', () async {
    final d = h.updateDraft();
    final s = PaymentUpdateSubmission(d, h.updateConfirmation(d));
    expect(s.hasChanges, false);
    await expectLater(submit(s), throwsA(isA<AppFailure>()));
    expect(h.paymentPosts, isEmpty);
  });
  test('schedule taken since selection stops before first write', () async {
    final s = edited();
    h.details[0]['prd_sched_avail_mark'] = '1';
    await expectLater(submit(s), throwsA(isA<PaymentScheduleBlocked>()));
    expect(h.paymentPosts, isEmpty);
    expect(s.started, false);
  });
  test(
    'concurrent service or saved method change requires reselect before write',
    () async {
      final s = edited();
      h.details[0]['available_qty'] = '0';
      await expectLater(submit(s), throwsA(isA<PaymentRecordChanged>()));
      expect(h.paymentPosts, isEmpty);
      h.details[0]['available_qty'] = '1';
      h.saved[0]['prmd_amt'] = '1029';
      await expectLater(submit(s), throwsA(isA<PaymentRecordChanged>()));
      expect(h.paymentPosts, isEmpty);
    },
  );
  test('settings changed before write cannot silently change mode', () async {
    final s = edited();
    h.adminData['is_pay_mode_active'] = '0';
    await expectLater(submit(s), throwsA(isA<PaymentSettingsChanged>()));
    expect(s.started, false);
    expect(h.paymentPosts, isEmpty);
  });
  test(
    'explicit rejected method resumes after acknowledged service without replay',
    () async {
      final s = edited();
      var fail = true;
      h.transport.onPost =
          (uri, headers) async => {
            'string_out':
                uri.pathSegments.last == 'updatePaymentMode' && fail
                    ? 'Rejected'
                    : 'Successfully Created',
          };
      await expectLater(submit(s), throwsA(isA<AppFailure>()));
      expect(s.servicesAcknowledged, 1);
      expect(s.methodsAcknowledged, 0);
      expect(s.uncertain, false);
      fail = false;
      await submit(s);
      expect(s.complete, true);
      expect(h.paymentPosts.map((r) => r.uri.pathSegments.last), [
        'updatePaymentDetails',
        'updatePaymentMode',
        'updatePaymentMode',
      ]);
    },
  );
  for (final response in <JsonMap>[
    {},
    {'string_out': ''},
  ]) {
    test(
      'unconfirmed POST response locks update against duplicate retry: $response',
      () async {
        final s = edited();
        h.transport.onPost = (u, h) async => response;
        await expectLater(submit(s), throwsA(isA<PaymentWriteUncertain>()));
        expect(s.uncertain, true);
        await expectLater(submit(s), throwsA(isA<PaymentWriteUncertain>()));
        expect(h.paymentPosts.length, 1);
      },
    );
  }
  test('transport failure after POST also requires checking records', () async {
    final s = edited();
    h.transport.onPost =
        (u, h) async => throw const AppFailure('Lost connection');
    await expectLater(submit(s), throwsA(isA<PaymentWriteUncertain>()));
    await expectLater(submit(s), throwsA(isA<PaymentWriteUncertain>()));
    expect(h.paymentPosts.length, 1);
  });
  test(
    'background after acknowledged service retains receipt, no next write until foreground',
    () async {
      final s = edited();
      var foreground = true;
      h.transport.onPost = (u, h) async {
        foreground = false;
        return {'string_out': 'Successfully Created'};
      };
      await expectLater(
        submit(s, current: () => foreground),
        throwsA(isA<ObsoleteRequest>()),
      );
      expect(s.servicesAcknowledged, 1);
      expect(h.paymentPosts.length, 1);
      foreground = true;
      h.transport.onPost =
          (u, h) async => {'string_out': 'Successfully Created'};
      await submit(s);
      expect(s.complete, true);
      expect(h.paymentPosts.length, 2);
    },
  );
  test(
    'account switch during response cannot attach receipt to another account',
    () async {
      final s = edited();
      var owned = true;
      h.transport.onPost = (u, h) async {
        owned = false;
        return {'string_out': 'Successfully Created'};
      };
      await expectLater(
        submit(s, current: () => true, owns: () => owned),
        throwsA(isA<ObsoleteRequest>()),
      );
      expect(s.servicesAcknowledged, 0);
      expect(h.paymentPosts.length, 1);
    },
  );
  test(
    'malformed data rejected instead of updating zero quantities or wrong IDs',
    () async {
      final p = paymentRecord(h.payments.first),
          original = Map<String, Object?>.of(h.details.first);
      for (final change in <JsonMap>[
        {'prd_id': 'bad'},
        {'prd_qty': '0'},
        {'available_qty': '2'},
        {'amount': '99'},
        {'prd_sched_avail_mark': '-1'},
        {'prd_rate': 'NaN'},
      ]) {
        h.details[0] = {...original, ...change};
        await expectLater(
          h.updateRepository.details(
            h.auth.session!,
            h.profile,
            p,
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
      }
      expect(h.paymentPosts, isEmpty);
    },
  );
  test(
    'duplicate detail and saved IDs rejected before entering update form',
    () async {
      final p = paymentRecord(h.payments.first);
      h.details.add(h.details.first);
      h.saved.add(h.saved.first);
      await expectLater(
        h.updateRepository.details(
          h.auth.session!,
          h.profile,
          p,
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        h.updateRepository.savedMethods(
          h.auth.session!,
          h.profile,
          p,
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );
}

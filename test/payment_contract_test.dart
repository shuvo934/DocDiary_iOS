import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/payments/payment_models.dart';
import 'payment_test_support.dart';

void main() {
  late PaymentHarness h;
  setUp(() async {
    h = PaymentHarness();
    await h.signIn();
    h.transport.requests.clear();
  });
  tearDown(() => h.auth.dispose());
  Future<void> submit(
    PaymentSubmission receipt, {
    bool Function()? current,
    bool Function()? owns,
  }) async => await h.paymentRepository.submit(
    h.auth.session!,
    h.profile,
    receipt,
    isCurrent: current ?? () => true,
    ownsResponse: owns ?? () => true,
  );

  test(
    'native patient list/search use the centre, encoded query and actual spelling',
    () async {
      await h.paymentRepository.patients(
        h.auth.session!,
        h.profile,
        isCurrent: () => true,
      );
      await h.paymentRepository.patients(
        h.auth.session!,
        h.profile,
        search: 'রহিম & 12',
        isCurrent: () => true,
      );
      expect(h.paymentReads.map((r) => r.uri.pathSegments.last), [
        'getFiftyPrescriptionList',
        'getPrescriptionCodeList',
      ]);
      expect(h.paymentReads.first.uri.queryParameters, isEmpty);
      expect(h.paymentReads.last.uri.queryParameters, {'ph_pat': 'রহিম & 12'});
      expect(
        h.paymentReads.every(
          (r) =>
              r.uri.host == 'centre.example' &&
              r.uri.path.contains('/payement_receive/'),
        ),
        true,
      );
      expect(h.paymentPosts, isEmpty);
    },
  );
  test(
    'encoded ORDS arrays preserve patients with identical names and separate IDs',
    () async {
      h.encoded = true;
      final rows = await h.paymentRepository.patients(
        h.auth.session!,
        h.profile,
        isCurrent: () => true,
      );
      expect(rows.map((r) => r.name).toSet().length, 1);
      expect(rows.map((r) => r.id), ['101', '102']);
    },
  );
  for (final value in ['', 'ab', 'abc.def', 'abc-def', 'abc,def']) {
    test('native patient search validation: "$value"', () {
      expect(paymentSearchError(value), isNotNull);
    });
  }
  for (final value in ['0', '04', '-1', '1.5', '1e3', 'abc', '2147483648']) {
    test('quantity rejects $value', () {
      expect(paymentQuantityError(value), isNotNull);
    });
  }
  test(
    'quantity supports positive integer and currency arithmetic stays exact',
    () {
      expect(paymentQuantityError('4'), isNull);
      expect(paymentCents('0.10')! + paymentCents('0.20')!, 30);
      expect(paymentCents('NaN'), isNull);
      expect(paymentCents('Infinity'), isNull);
      expect(paymentCents('1.001'), isNull);
      expect(paymentMoney(247200, fixed: true), '2472.00');
    },
  );
  test(
    'same service-unit is rejected; other unit and editing the original are allowed',
    () {
      final d = h.draft(), line = d.services.single;
      expect(() => d.add(line), throwsA(isA<AppFailure>()));
      d.add(
        PaymentServiceLine(
          service: line.service,
          unit: PaymentChoice.unit(h.units[1]),
          rate: line.rate,
          quantity: 1,
        ),
      );
      expect(d.services.length, 2);
      d.add(
        PaymentServiceLine(
          service: line.service,
          unit: line.unit,
          rate: line.rate,
          quantity: 2,
        ),
        replacing: line,
      );
      expect(d.total, 180000);
      expect(
        () => d.add(d.services.last, replacing: d.services.first),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'dependent unit and patient-category rate endpoints match native parameters',
    () async {
      final d = h.draft(), line = d.services.single;
      await h.paymentRepository.services(
        h.auth.session!,
        h.profile,
        isCurrent: () => true,
      );
      await h.paymentRepository.units(
        h.auth.session!,
        h.profile,
        line.service,
        isCurrent: () => true,
      );
      final rate = await h.paymentRepository.rate(
        h.auth.session!,
        h.profile,
        d.patient!,
        line.service,
        line.unit,
        isCurrent: () => true,
      );
      expect(rate.cents, 60000);
      expect(rate.topCents, 100000);
      expect(h.paymentReads[1].uri.queryParameters, {'p_pfn_id': '31'});
      expect(h.paymentReads[2].uri.queryParameters, {
        'P_PFN_ID': '31',
        'P_DEPTS_ID': '20',
        'P_PRM_DATE': '01-Nov-26',
        'P_PAT_CAT_ID': '3',
      });
    },
  );
  test(
    'zero native rate is valid, malformed and absent rates are rejected',
    () {
      expect(
        PaymentRate.fromJson({
          'p_service_rate': null,
          'p_service_top_rate': null,
        }).cents,
        0,
      );
      for (final row in <JsonMap>[
        {},
        {'p_service_rate': 'NaN', 'p_service_top_rate': '10'},
        {'p_service_rate': '-1', 'p_service_top_rate': '10'},
      ]) {
        expect(() => PaymentRate.fromJson(row), throwsA(isA<AppFailure>()));
      }
    },
  );
  test(
    'quote gets native methods and charges; 2400 at 3 percent gives 2472',
    () async {
      final q = await h.paymentRepository.quote(
        h.auth.session!,
        h.profile,
        h.draft().services,
        isCurrent: () => true,
      );
      expect([q.total, q.charge, q.grandTotal], [240000, 7200, 247200]);
      expect(h.paymentReads.map((r) => r.uri.pathSegments.last), [
        'getPaymentMode',
        'getServiceChargePFN',
      ]);
      expect(h.paymentReads.last.uri.queryParameters, {'p_pfn_id': '31'});
    },
  );
  test(
    'charge rounds after summing and loads repeated service percentage once',
    () async {
      h.charge = '0.5';
      final d = h.draft();
      final lines = [
        for (final u in h.units)
          PaymentServiceLine(
            service: d.services.single.service,
            unit: PaymentChoice.unit(u),
            rate: const PaymentRate(100, 100),
            quantity: 1,
          ),
      ];
      final q = await h.paymentRepository.quote(
        h.auth.session!,
        h.profile,
        lines,
        isCurrent: () => true,
      );
      expect(q.total, 200);
      expect(q.charge, 1);
      expect(
        h.paymentReads
            .where((r) => r.uri.pathSegments.last == 'getServiceChargePFN')
            .length,
        1,
      );
    },
  );
  test(
    'missing charge, invalid percent and incomplete list cannot silently quote zero',
    () async {
      for (final invalid in <JsonMap>[
        {'count': 0, 'items': []},
        {
          'count': 1,
          'items': [
            {'s_c': 'NaN'},
          ],
        },
        {
          'count': 1,
          'items': [<String, Object?>{}],
        },
      ]) {
        h.onPaymentGet =
            (uri) async =>
                uri.pathSegments.last == 'getServiceChargePFN' ? invalid : null;
        await expectLater(
          h.paymentRepository.quote(
            h.auth.session!,
            h.profile,
            h.draft().services,
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
      }
      expect(h.paymentPosts, isEmpty);
    },
  );
  test(
    'confirmation rejects partial, excess, duplicate and unknown payment methods',
    () {
      final d = h.draft(), c = h.confirmation(h.draft());
      for (final allocations in [
        <PaymentAllocation>[],
        [PaymentAllocation(c.quote.methods.first, d.total)],
        [PaymentAllocation(c.quote.methods.first, 247201)],
        [
          PaymentAllocation(c.quote.methods.first, 123600),
          PaymentAllocation(c.quote.methods.first, 123600),
        ],
      ]) {
        expect(
          () => PaymentConfirmation(c.quote, allocations),
          throwsA(isA<AppFailure>()),
        );
      }
      final unknown = PaymentChoice.method({
        ...h.methods.first,
        'ad_id': '999',
      });
      expect(
        () =>
            PaymentConfirmation(c.quote, [PaymentAllocation(unknown, 247200)]),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'native master/details/method headers and order for bank plus cash split',
    () async {
      final d = h.draft(),
          r = PaymentSubmission(h.draft(), h.confirmation(d, split: true));
      await submit(r);
      expect(h.paymentPosts.map((r) => r.uri.pathSegments.last), [
        'insertPaymentMaster',
        'insertPaymentDetails',
        'insertPaymentMode',
        'insertPaymentMode',
      ]);
      expect(h.paymentPosts[0].headers, {
        'P_PRM_DATE': '01-Nov-26',
        'P_PRM_ONLINE_OFFLINE_FLAG': '0',
        'P_PRM_PATIENT_CAT_ID': '3',
        'P_PRM_PH_ID': '101',
        'P_PRM_USER': 'example.admin',
        'P_INSERT_TYPE_FLAG': '3',
        'P_PAID_AMOUNT': '2472.00',
      });
      expect(h.paymentPosts[1].headers, {
        'P_DEPTS_ID': '20',
        'P_PFN_ID': '31',
        'P_PRD_PATIENT_CAT_ID': '3',
        'P_PRD_QTY': '4',
        'P_PRD_RATE': '600',
        'P_PRD_TOP_CAT_RATE': '1000',
        'P_PRD_USR': 'example.admin',
        'P_PRM_CODE': 'PR.26.000501',
        'P_PRM_ID': '501',
        'P_INSERT_TYPE_FLAG': '3',
      });
      expect(h.paymentPosts[2].headers, {
        'P_AMOUNT': '2000.00',
        'P_PMM_ID': '2',
        'P_PMD_ID': '12',
        'P_AD_ID': '112',
        'P_PRM_ID': '501',
      });
      expect(h.paymentPosts[3].headers['P_AMOUNT'], '472.00');
      expect(r.complete, true);
      await submit(r);
      expect(h.paymentPosts.length, 4);
    },
  );
  test(
    'payment mode disabled sends service total and no method writes',
    () async {
      h.adminData['is_pay_mode_active'] = '0';
      final r = PaymentSubmission(h.draft(), null);
      await submit(r);
      expect(h.paymentPosts.map((r) => r.uri.pathSegments.last), [
        'insertPaymentMaster',
        'insertPaymentDetails',
      ]);
      expect(h.paymentPosts.first.headers['P_PAID_AMOUNT'], '2400.00');
      expect(r.complete, true);
    },
  );
  test(
    'rejected detail resumes after acknowledged master without another master',
    () async {
      var rejected = false;
      h.transport.onPost = (uri, headers) async {
        if (uri.pathSegments.last == 'insertPaymentMaster') {
          return {
            'string_out': 'Successfully Created',
            'out_prm_id': '501',
            'out_prm_code': 'PR-501',
          };
        }
        if (uri.pathSegments.last == 'insertPaymentDetails' && !rejected) {
          rejected = true;
          return {'string_out': 'Rejected'};
        }
        return {'string_out': 'Successfully Created'};
      };
      final d = h.draft(), r = PaymentSubmission(d, h.confirmation(d));
      await expectLater(submit(r), throwsA(isA<AppFailure>()));
      expect(r.masterId, '501');
      expect(r.servicesAcknowledged, 0);
      expect(r.uncertain, false);
      await submit(r);
      expect(r.complete, true);
      expect(
        h.paymentPosts
            .where((r) => r.uri.pathSegments.last == 'insertPaymentMaster')
            .length,
        1,
      );
    },
  );
  test(
    'rejected second payment method retries only the second method',
    () async {
      var rejected = false;
      h.transport.onPost = (uri, headers) async {
        if (uri.pathSegments.last == 'insertPaymentMaster') {
          return {
            'string_out': 'Successfully Created',
            'out_prm_id': '501',
            'out_prm_code': 'PR-501',
          };
        }
        if (uri.pathSegments.last == 'insertPaymentMode' &&
            headers['P_PMM_ID'] == '1' &&
            !rejected) {
          rejected = true;
          return {'string_out': 'Rejected'};
        }
        return {'string_out': 'Successfully Created'};
      };
      final d = h.draft(),
          r = PaymentSubmission(d, h.confirmation(d, split: true));
      await expectLater(submit(r), throwsA(isA<AppFailure>()));
      expect(r.servicesAcknowledged, 1);
      expect(r.methodsAcknowledged, 1);
      await submit(r);
      expect(r.complete, true);
      expect(
        h.paymentPosts
            .where((r) => r.uri.pathSegments.last == 'insertPaymentMaster')
            .length,
        1,
      );
      expect(
        h.paymentPosts
            .where((r) => r.uri.pathSegments.last == 'insertPaymentDetails')
            .length,
        1,
      );
      expect(
        h.paymentPosts
            .where(
              (r) =>
                  r.uri.pathSegments.last == 'insertPaymentMode' &&
                  r.headers['P_PMM_ID'] == '2',
            )
            .length,
        1,
      );
    },
  );
  test(
    'lost write response is uncertain and cannot be blindly replayed',
    () async {
      h.transport.onPost =
          (uri, headers) async =>
              throw const AppFailure('Connection interrupted');
      final d = h.draft(), r = PaymentSubmission(d, h.confirmation(d));
      await expectLater(submit(r), throwsA(isA<PaymentWriteUncertain>()));
      expect(r.uncertain, true);
      await expectLater(submit(r), throwsA(isA<PaymentWriteUncertain>()));
      expect(h.paymentPosts.length, 1);
    },
  );
  test(
    'acknowledged success with missing master identity is not retried',
    () async {
      h.transport.onPost =
          (uri, headers) async => {
            'string_out': 'Successfully Created',
            'out_prm_id': 'Not Found',
          };
      final d = h.draft(), r = PaymentSubmission(d, h.confirmation(d));
      await expectLater(submit(r), throwsA(isA<PaymentWriteUncertain>()));
      await expectLater(submit(r), throwsA(isA<PaymentWriteUncertain>()));
      expect(h.paymentPosts.length, 1);
    },
  );
  test(
    'backgrounded master acknowledgement is retained; no next POST until explicit continue',
    () async {
      final pending = Completer<JsonMap>();
      h.transport.onPost = (uri, headers) async => pending.future;
      final d = h.draft(), r = PaymentSubmission(d, h.confirmation(d));
      var current = true;
      final future = submit(r, current: () => current);
      await Future<void>.delayed(Duration.zero);
      current = false;
      pending.complete({
        'string_out': 'Successfully Created',
        'out_prm_id': '501',
        'out_prm_code': 'PR-501',
      });
      await expectLater(future, throwsA(isA<ObsoleteRequest>()));
      expect(r.masterId, '501');
      expect(h.paymentPosts.length, 1);
      current = true;
      h.transport.onPost =
          (uri, headers) async => {'string_out': 'Successfully Created'};
      await submit(r, current: () => current);
      expect(r.complete, true);
      expect(h.paymentPosts.length, 3);
    },
  );
  test(
    'session switch discards late response and starts no detail write',
    () async {
      final pending = Completer<JsonMap>();
      h.transport.onPost = (uri, headers) async => pending.future;
      final d = h.draft(), r = PaymentSubmission(d, h.confirmation(d));
      var owns = true;
      final future = submit(r, owns: () => owns);
      await Future<void>.delayed(Duration.zero);
      owns = false;
      pending.complete({
        'string_out': 'Successfully Created',
        'out_prm_id': '501',
        'out_prm_code': 'PR-501',
      });
      await expectLater(future, throwsA(isA<ObsoleteRequest>()));
      expect(h.paymentPosts.length, 1);
    },
  );
  test('changed payment-mode setting blocks save before any POST', () async {
    final d = h.draft(), r = PaymentSubmission(d, h.confirmation(d));
    h.adminData['is_pay_mode_active'] = '0';
    await expectLater(submit(r), throwsA(isA<PaymentSettingsChanged>()));
    expect(h.paymentPosts, isEmpty);
  });
  for (final role in ['2', '3']) {
    test(
      'role $role payment flag blocks direct feature reads and writes',
      () async {
        h.adminData.addAll({
          'all_access_flag': role,
          role == '2' ? 'hr_payment_active' : 'acc_payment_active': '0',
        });
        await expectLater(
          h.paymentRepository.patients(
            h.auth.session!,
            h.profile,
            isCurrent: () => true,
          ),
          throwsA(isA<PaymentUnavailable>()),
        );
        final d = h.draft();
        await expectLater(
          submit(PaymentSubmission(d, h.confirmation(d))),
          throwsA(isA<PaymentUnavailable>()),
        );
        expect(h.paymentReads, isEmpty);
        expect(h.paymentPosts, isEmpty);
      },
    );
  }
  test(
    'full-access override still allows payment when limited-role flags are zero',
    () async {
      h.adminData.addAll({
        'all_access_flag': '1',
        'hr_acc_active': '2',
        'hr_payment_active': '0',
        'acc_payment_active': '0',
      });
      await h.paymentRepository.services(
        h.auth.session!,
        h.profile,
        isCurrent: () => true,
      );
      expect(h.paymentReads.length, 1);
    },
  );
  test(
    'doctor, mismatched admin, forced logout and expired access cannot reach Payment API',
    () async {
      final profiles = [
        AccountProfile(AccountRole.doctor, h.doctorData),
        AccountProfile(AccountRole.admin, {...h.adminData, 'usr_id': '999999'}),
        AccountProfile(AccountRole.admin, {
          ...h.adminData,
          'usr_mob_forced_log_out_flag': '1',
        }),
        AccountProfile(AccountRole.admin, {
          ...h.adminData,
          'exp_date': '01-JAN-20',
        }),
      ];
      for (final p in profiles) {
        await expectLater(
          h.paymentRepository.services(
            h.auth.session!,
            p,
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
      }
      expect(h.paymentReads, isEmpty);
    },
  );
  test('obsolete GET response is discarded', () async {
    final pending = Completer<JsonMap>();
    var current = true;
    h.onPaymentGet = (uri) async => pending.future;
    final f = h.paymentRepository.services(
      h.auth.session!,
      h.profile,
      isCurrent: () => current,
    );
    await Future<void>.delayed(Duration.zero);
    current = false;
    pending.complete({'count': 0, 'items': []});
    await expectLater(f, throwsA(isA<ObsoleteRequest>()));
  });
}

import 'dart:convert';

import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/dashboard/admin_chart_models.dart';
import 'package:docdiary_ios/features/dashboard/admin_chart_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Harness _admin() {
  final h = Harness(clock: DateTime(2026, 10, 17));
  h.loginResponse = adminLogin();
  h.adminData['usr_id'] = '70';
  h.adminData['is_pay_appoint_type_active'] = '1';
  return h;
}

JsonMap _response({bool yearly = false}) => {
  'count': '2',
  'items': [
    {
      yearly ? 'pmonths' : 'dates': 'Second',
      'amount': '1000.50',
      'amount1': '2.50',
      'total_app': 10,
      'cancel_app': 2,
    },
    {
      yearly ? 'pmonths' : 'dates': 'First',
      'amount': '2000.50',
      'amount1': null,
      'total_app': '20',
      'cancel_app': null,
    },
  ],
};

void main() {
  for (final mode in AdminChartMode.values) {
    for (final type in AdminChartType.values) {
      test(
        '${mode.name}/${type.name} preserves both native routes, params and API row order',
        () async {
          final h = _admin();
          await h.signIn();
          addTearDown(h.auth.dispose);
          final writes = h.posts.length;
          h.transport.onGet = (uri) async {
            if (uri.path.contains('getPaymentData') ||
                uri.path.contains('getAppointData')) {
              return _response(yearly: mode == AdminChartMode.yearly);
            }
            return h.defaultGet(uri);
          };
          final repo = AdminChartRepository(h.transport, now: () => h.now);
          final selection = AdminChartSelection(mode, h.now);
          final pair = await repo.loadBoth(
            h.auth.session!,
            h.auth.profile!,
            type,
            selection,
          );
          final requests =
              h.transport.requests
                  .where(
                    (r) =>
                        r.uri.path.contains('Data') &&
                        (r.uri.path.contains('getPayment') ||
                            r.uri.path.contains('getAppoint')),
                  )
                  .toList();
          final filter =
              type == AdminChartType.all
                  ? ''
                  : type == AdminChartType.offline
                  ? 'Offline'
                  : 'Online';
          final period = mode == AdminChartMode.monthly ? 'Monthly' : 'Yearly';
          expect(requests.map((r) => r.uri.path.split('/').last), [
            'getPaymentData$filter$period',
            'getAppointData$filter$period',
          ]);
          expect(requests.first.uri.queryParameters, {
            ...selection.query,
            'user_id': 'example.admin',
          });
          expect(requests.last.uri.queryParameters, selection.query);
          expect(pair.payment.points.map((p) => p.label), ['Second', 'First']);
          expect(pair.payment.primaryTotal, '৳ 3,001');
          expect(pair.payment.secondaryTotal, '৳ 2');
          expect(pair.appointment.primaryTotal, '30');
          expect(pair.appointment.secondaryTotal, '2');
          expect(h.posts.length, writes);
        },
      );
    }
  }

  test('only all_access_flag 1 sends an empty payment user filter', () async {
    for (final access in ['0', '1', '2', '3']) {
      final h = _admin();
      h.adminData['all_access_flag'] = access;
      await h.signIn();
      final before = h.posts.length;
      await AdminChartRepository(h.transport, now: () => h.now).loadBoth(
        h.auth.session!,
        h.auth.profile!,
        AdminChartType.all,
        AdminChartSelection(AdminChartMode.monthly, h.now),
      );
      final request = h.transport.requests.lastWhere(
        (r) => r.uri.path.contains('getPaymentData'),
      );
      expect(
        request.uri.queryParameters['user_id'],
        access == '1' ? '' : 'example.admin',
      );
      expect(h.posts.length, before);
      h.auth.dispose();
    }
  });

  test('individual date changes read only the selected chart', () async {
    final h = _admin();
    await h.signIn();
    addTearDown(h.auth.dispose);
    final before = h.transport.requests.length;
    await AdminChartRepository(h.transport, now: () => h.now).loadOne(
      h.auth.session!,
      h.auth.profile!,
      AdminChartKind.appointment,
      AdminChartType.offline,
      AdminChartSelection(AdminChartMode.monthly, DateTime(2026, 2)),
    );
    final reads = h.transport.requests.skip(before).toList();
    expect(reads.length, 2); // Access flag, then the selected chart only.
    expect(
      reads.last.uri.path.endsWith('getAppointDataOfflineMonthly'),
      isTrue,
    );
    expect(reads.last.uri.queryParameters, {
      'begin_date': '01-FEB-26',
      'end_date': '28-FEB-26',
    });
  });

  test('native month/year bounds include leap days and cross-year limits', () {
    final now = DateTime(2026, 10, 31);
    expect(
      AdminChartSelection(AdminChartMode.monthly, DateTime(2028, 2)).query,
      {'begin_date': '01-FEB-28', 'end_date': '29-FEB-28'},
    );
    expect(
      AdminChartSelection(
        AdminChartMode.monthly,
        DateTime(2025, 11),
      ).isAllowed(now),
      isTrue,
    );
    expect(
      AdminChartSelection(
        AdminChartMode.monthly,
        DateTime(2025, 10),
      ).isAllowed(now),
      isFalse,
    );
    expect(
      AdminChartSelection(
        AdminChartMode.monthly,
        DateTime(2026, 11),
      ).isAllowed(now),
      isFalse,
    );
    expect(
      AdminChartSelection(AdminChartMode.yearly, DateTime(2016)).isAllowed(now),
      isTrue,
    );
    expect(
      AdminChartSelection(AdminChartMode.yearly, DateTime(2015)).isAllowed(now),
      isFalse,
    );
    expect(
      AdminChartSelection(AdminChartMode.yearly, DateTime(2027)).isAllowed(now),
      isFalse,
    );
    expect(
      AdminChartSelection(AdminChartMode.monthly, DateTime(2026, 10)).label,
      'MONTH: OCT-26',
    );
    expect(
      AdminChartSelection(AdminChartMode.yearly, DateTime(2025)).label,
      'YEAR: 2025',
    );
  });

  test(
    'chart totals use exact summation and native half-even whole-number rounding',
    () {
      String total(List<String> values) =>
          chartTotal(values.map(AdminChartNumber.parse), currency: true);
      expect(total(['0.5']), '৳ 0');
      expect(total(['1.5']), '৳ 2');
      expect(total(['2.5']), '৳ 2');
      expect(total(['3.5']), '৳ 4');
      expect(total(['-2.5']), '৳ -2');
      expect(total(['0.10', '0.20', '0.20']), '৳ 0');
      expect(
        total(['9007199254740993.50', '0.50']),
        '৳ 9,00,71,99,25,47,40,994',
      );
      expect(total(['1e3', '0.25']), '৳ 1,000');
      expect(total(['628900']), '৳ 6,28,900');
      expect(total(['30500']), '৳ 30,500');
      expect(total(['10000000']), '৳ 1,00,00,000');
      expect(total(['-1234567.50']), '৳ -12,34,568');
      expect(chartTotal([AdminChartNumber.parse('2157')]), '2157');
      expect(chartGroupInteger('628900'), '628,900'); // Native marker format.
    },
  );

  test(
    'point abbreviations match upstream formatter examples checked using Java',
    () {
      for (final item
          in <double, String>{
            0: '0',
            1.25: '1.25',
            856: '856',
            1000: '1k',
            5821: '5.82k',
            10500: '10.5k',
            101800: '102k',
            9999999: '10m',
            1000000000: '1b',
            1234567: '1.23m',
          }.entries) {
        expect(chartCompact(item.key), item.value);
      }
      expect(
        chartCompact(0.5),
        '0.5',
      ); // Guard the native negative-exponent bug.
    },
  );

  test(
    'encoded items/null numbers are supported and missing/invalid data is not empty success',
    () {
      final source = _response();
      final decoded = AdminChartData.fromResponse(
        AdminChartKind.payment,
        AdminChartMode.monthly,
        {...source, 'items': jsonEncode(source['items'])},
      );
      expect(decoded.points.last.secondary.plot, 0);
      expect(
        AdminChartData.fromResponse(
          AdminChartKind.payment,
          AdminChartMode.monthly,
          {'count': 0, 'items': null},
        ).primaryTotal,
        '৳ 0',
      );
      for (final response in <JsonMap>[
        {},
        {'count': 1, 'items': null},
        {
          'count': 1,
          'items': [
            {'amount': 'NaN'},
          ],
        },
        {
          'count': 1,
          'items': [
            {'amount': 'Infinity'},
          ],
        },
      ]) {
        expect(
          () => AdminChartData.fromResponse(
            AdminChartKind.payment,
            AdminChartMode.monthly,
            response,
          ),
          throwsA(isA<AppFailure>()),
        );
      }
      expect(
        () => AdminChartData.fromResponse(
          AdminChartKind.appointment,
          AdminChartMode.monthly,
          {
            'items': [
              {'total_app': '1.5'},
            ],
          },
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  test(
    'forced logout blocks all chart reads and a missing access response is an error',
    () async {
      final h = _admin();
      await h.signIn();
      addTearDown(h.auth.dispose);
      final repo = AdminChartRepository(h.transport, now: () => h.now);
      h.transport.onGet =
          (_) async => {
            'items': [
              {'fl_flag': '1'},
            ],
          };
      final before = h.transport.requests.length;
      await expectLater(
        repo.loadBoth(
          h.auth.session!,
          h.auth.profile!,
          AdminChartType.all,
          AdminChartSelection(AdminChartMode.monthly, h.now),
        ),
        throwsA(
          isA<AppFailure>().having(
            (failure) => failure.kind,
            'kind',
            FailureKind.denied,
          ),
        ),
      );
      expect(h.transport.requests.length, before + 1);
      h.transport.onGet = (_) async => {'items': <Object?>[]};
      await expectLater(
        repo.loadBoth(
          h.auth.session!,
          h.auth.profile!,
          AdminChartType.all,
          AdminChartSelection(AdminChartMode.monthly, h.now),
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  test('hidden type filters cannot trigger non-All chart endpoints', () async {
    final h = _admin();
    h.adminData['is_pay_appoint_type_active'] = '0';
    await h.signIn();
    addTearDown(h.auth.dispose);
    final before = h.transport.requests.length;
    await expectLater(
      AdminChartRepository(h.transport, now: () => h.now).loadBoth(
        h.auth.session!,
        h.auth.profile!,
        AdminChartType.online,
        AdminChartSelection(AdminChartMode.monthly, h.now),
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(h.transport.requests.length, before);
  });

  test(
    'obsolete payment response does not queue the old appointment request',
    () async {
      final h = _admin();
      await h.signIn();
      addTearDown(h.auth.dispose);
      var current = true;
      h.transport.onGet = (uri) async {
        if (uri.path.contains('getPaymentData')) {
          current = false;
          return _response();
        }
        return h.defaultGet(uri);
      };
      final before = h.transport.requests.length;
      await expectLater(
        AdminChartRepository(h.transport, now: () => h.now).loadBoth(
          h.auth.session!,
          h.auth.profile!,
          AdminChartType.all,
          AdminChartSelection(AdminChartMode.monthly, h.now),
          isCurrent: () => current,
        ),
        throwsA(isA<ObsoleteChartRequest>()),
      );
      expect(
        h.transport.requests
            .skip(before)
            .where((r) => r.uri.path.contains('getAppointData')),
        isEmpty,
      );
    },
  );
}

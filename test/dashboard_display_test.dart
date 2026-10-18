import 'package:docdiary_ios/core/native_dates.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/native_dashboard_format.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  test(
    'native date labels show full dates and Saturday to Friday across years',
    () {
      expect(
        nativeDashboardDate(SummaryPeriod.today, DateTime(2026, 10, 17)),
        '17 October, 26',
      );
      expect(
        nativeDashboardDate(SummaryPeriod.currentWeek, DateTime(2027, 1, 1)),
        '26 December, 26  --  01 January, 27',
      );
      expect(
        nativeDashboardDate(SummaryPeriod.nextMonth, DateTime(2028, 1, 31)),
        '01 February, 28  --  29 February, 28',
      );
    },
  );

  test(
    'currency prefix/grouping preserves decimals and arbitrary precision',
    () {
      expect(nativeDashboardMoney('1234567'), '৳ 12,34,567');
      expect(nativeDashboardMoney('628900'), '৳ 6,28,900');
      expect(nativeDashboardMoney('10000000'), '৳ 1,00,00,000');
      expect(nativeDashboardMoney('1200.50'), '৳ 1,200.50');
      expect(
        nativeDashboardMoney('123456789123456789.05'),
        '৳ 1,23,45,67,89,12,34,56,789.05',
      );
      expect(nativeDashboardMoney('-1000.25'), '৳ -1,000.25');
      expect(nativeDashboardMoney('-1234567.50'), '৳ -12,34,567.50');
      expect(nativeDashboardMoney('+1234567.50'), '৳ +12,34,567.50');
      expect(nativeDashboardMoney('0'), '৳ 0');
    },
  );

  test(
    'meeting information handles same-day, a different month with the same day number, and invalid input',
    () {
      final now = DateTime(2026, 10, 17, 10, 30);
      expect(nativeDashboardMeeting('17-10-2026 11:00:00', now), 'At 11:00 AM');
      expect(
        nativeDashboardMeeting('17-11-2026 13:05:00', now),
        'At 01:05 PM\nIn 17 Nov, 26',
      );
      expect(
        nativeDashboardMeeting('31-02-2026 10:00:00', now),
        '31-02-2026 10:00:00',
      );
      expect(nativeDashboardMeeting('11:00 AM', now), '11:00 AM');
    },
  );

  test(
    'doctor and admin pictures use the correct native endpoints, keys and account identifier',
    () async {
      for (final admin in [false, true]) {
        final h = Harness();
        if (admin) {
          h.loginResponse = adminLogin();
        }
        await h.signIn();
        final writes = h.posts.length;
        final field = admin ? 'usr_profile_pic' : 'doc_profile_pic';
        h.transport.onGet =
            (uri) async => {
              'items': [
                {field: ' AAECAw==\n'},
              ],
            };
        final picture = await DashboardRepository(
          h.transport,
        ).loadPicture(h.auth.session!, h.auth.profile!);
        expect(picture, [0, 1, 2, 3]);
        final request = h.transport.requests.last;
        expect(
          request.uri.path.endsWith(admin ? 'getAdminPic' : 'getDocPic'),
          isTrue,
        );
        expect(
          request.uri.queryParameters,
          admin ? {'p_usr_id': '70'} : {'doc_id': '10'},
        );
        expect(h.posts.length, writes);
        h.auth.dispose();
      }
    },
  );

  test(
    'empty pictures use the placeholder; malformed data is retryable as in a native full load',
    () async {
      final h = Harness();
      await h.signIn();
      for (final response in [
        {'items': <Object?>[]},
        {
          'items': [
            {'doc_profile_pic': null},
          ],
        },
      ]) {
        h.transport.onGet = (_) async => response;
        expect(
          await DashboardRepository(
            h.transport,
          ).loadPicture(h.auth.session!, h.auth.profile!),
          isNull,
        );
      }
      h.transport.onGet =
          (_) async => {
            'items': [
              {'doc_profile_pic': 'not base64!'},
            ],
          };
      await expectLater(
        DashboardRepository(
          h.transport,
        ).loadPicture(h.auth.session!, h.auth.profile!),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.kind,
            'kind',
            FailureKind.invalidData,
          ),
        ),
      );
      h.auth.dispose();
    },
  );
}

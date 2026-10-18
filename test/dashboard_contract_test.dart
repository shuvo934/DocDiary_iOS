import 'package:flutter_test/flutter_test.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_dates.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';

import 'support.dart';

void main() {
  late Harness h;
  late DashboardRepository dashboard;
  setUp(() {
    h = Harness();
    dashboard = DashboardRepository(h.transport, now: () => h.now);
  });
  tearDown(() => h.auth.dispose());

  test(
    'doctor completed/remaining counts follow scheduled time, including equality at now',
    () async {
      await h.signIn();
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getMeetingCount')) {
          return {
            'count': 3,
            'items': [
              {'appointment_date': '15-OCT-26', 'schedule_time': '12:00 PM'},
              {'appointment_date': '15-OCT-26', 'schedule_time': '01:30 PM'},
              {'appointment_date': '15-OCT-26', 'schedule_time': '02:00 PM'},
            ],
          };
        }
        return h.defaultGet(uri);
      };
      final result = await dashboard.load(
        h.auth.session!,
        h.auth.profile!,
        SummaryPeriod.today,
      );
      expect(result.values['TOTAL'], '3');
      expect(result.values['COMPLETED'], '2');
      expect(result.values['REMAINING'], '1');
      expect(result.values['TOTAL SCHEDULE'], '8');
      expect(result.values['BLOCKED SCHEDULE'], '2');
    },
  );

  test(
    'doctor current-week requests use Saturday and Friday native date parameters',
    () async {
      await h.signIn();
      await dashboard.load(
        h.auth.session!,
        h.auth.profile!,
        SummaryPeriod.currentWeek,
      );
      final query =
          h.transport.requests
              .lastWhere((r) => r.uri.path.endsWith('getMeetingCount'))
              .uri
              .queryParameters;
      expect(query, {
        'doc_id': '10',
        'first_date': '10-OCT-26',
        'end_date': '16-OCT-26',
      });
    },
  );

  test(
    'admin summary keeps exact decimal amounts and applies restricted username filter',
    () async {
      h.loginResponse = adminLogin();
      await h.signIn();
      final result = await dashboard.load(
        h.auth.session!,
        h.auth.profile!,
        SummaryPeriod.today,
      );
      expect(result.values['PAYMENT RECEIVED'], '1200.50');
      expect(result.values['PAYMENT RETURNED'], '100.25');
      final query = h.transport.requests.last.uri.queryParameters;
      expect(query['user_id'], 'example.admin');
      expect(query['begin_date'], '15-OCT-26');
    },
  );

  test(
    'all-access admin sends empty user filter; doctor ID is never substituted',
    () async {
      h.loginResponse = adminLogin();
      h.adminData['all_access_flag'] = '1';
      await h.signIn();
      await dashboard.load(
        h.auth.session!,
        h.auth.profile!,
        SummaryPeriod.currentMonth,
      );
      expect(h.transport.requests.last.uri.queryParameters['user_id'], '');
    },
  );

  test(
    'forced logout blocks summary reads rather than showing cached data',
    () async {
      await h.signIn();
      h.transport.onGet =
          (_) async => {
            'count': 1,
            'items': [
              {'fl_flag': '1'},
            ],
          };
      final before = h.transport.requests.length;
      await expectLater(
        dashboard.load(h.auth.session!, h.auth.profile!, SummaryPeriod.today),
        throwsA(
          isA<AppFailure>().having((e) => e.kind, 'kind', FailureKind.denied),
        ),
      );
      expect(h.transport.requests.length - before, 1);
    },
  );

  test(
    'missing force-logout response is an error, not implicit access approval',
    () async {
      await h.signIn();
      h.transport.onGet = (_) async => {'count': 0, 'items': <Object?>[]};
      await expectLater(
        dashboard.load(h.auth.session!, h.auth.profile!, SummaryPeriod.today),
        throwsA(isA<AppFailure>()),
      );
    },
  );
}

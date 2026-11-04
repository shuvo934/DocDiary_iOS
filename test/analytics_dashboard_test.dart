import 'dart:async';
import 'dart:convert';

import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/analytics/analytics_dashboard_screen.dart';
import 'package:docdiary_ios/features/analytics/analytics_models.dart';
import 'package:docdiary_ios/features/analytics/analytics_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';
import 'toast_test_support.dart';

class _AnalyticsHarness extends Harness {
  _AnalyticsHarness({bool portal = true})
    : super(clock: DateTime(2026, 11, 4, 11, 31)) {
    loginResponse = adminLogin();
    adminData.addAll({
      'all_access_flag': '1',
      'hr_acc_active_flag': '1',
      'usr_mob_app_analytic_access': '1',
      'is_pay_appoint_type_active': portal ? '1' : '0',
    });
    transport.onGet = _respond;
  }

  Future<JsonMap?> Function(Uri)? intercept;

  AnalyticsRepository get repository =>
      AnalyticsRepository(transport, now: () => now);
  List<Uri> get reads => [
    for (final request in transport.requests)
      if (request.uri.path.contains('/analytic_dashboard/')) request.uri,
  ];

  JsonMap _page(List<JsonMap> rows) => {
    'count': rows.length,
    'items': jsonEncode(rows),
  };

  Future<JsonMap> _respond(Uri uri) async {
    if (!uri.path.contains('/analytic_dashboard/')) return defaultGet(uri);
    final custom = await intercept?.call(uri);
    if (custom != null) return custom;
    final day = uri.queryParameters['end_date']!;
    final endpoint = uri.pathSegments.last;
    return _page(switch (endpoint) {
      'getAppLoginStatus' => [
        {'all_dates': day, 'all_amount': 200, 'u_amount': 92},
      ],
      'getOPASLoginStatus' => [
        {'all_dates': day, 'all_amount': 67, 'u_amount': 40},
      ],
      'getTotalUnqLogin' => [
        {
          'total_unq_amount':
              uri.queryParameters['p_log_type'] == '3' ? 91 : 39,
        },
      ],
      'getAppInitCountStatus' || 'getAppSchCountStatus' => [
        {
          'all_dates': day,
          'all_app_count': 27,
          'c_app_count': 24,
          'uc_app_count': 3,
        },
      ],
      'getOPASPayStatus' => [
        {
          'all_dates': day,
          'all_pay_count': 30,
          'c_pay_count': 24,
          'f_pay_count': 1,
          'na_pay_count': 5,
        },
      ],
      'getOPASCardPayStatus' => [
        {
          'card_name': 'EXAMPLE WALLET',
          'all_pay_count': 12,
          'c_pay_count': 10,
          'f_pay_count': null,
          'na_pay_count': 2,
        },
        {
          'card_name': 'Example & Visa',
          'all_pay_count': 7,
          'c_pay_count': 6,
          'f_pay_count': 1,
          'na_pay_count': 0,
        },
        {
          'card_name': 'EMPTY',
          'all_pay_count': 0,
          'c_pay_count': 0,
          'f_pay_count': 0,
          'na_pay_count': 0,
        },
      ],
      'getCardWiseFailedResult' => [
        {
          'result_type': null,
          'result_desc': 'Example decline',
          'failed_count': 1,
        },
      ],
      'getCardWiseNRResult' => [
        {
          'result_type': 'No result',
          'result_desc': 'Example timeout',
          'failed_count': 2,
        },
      ],
      _ => throw StateError('Unknown analytics request $endpoint'),
    });
  }
}

Future<void> _open(
  WidgetTester tester,
  _AnalyticsHarness h, {
  bool settle = true,
  Size size = const Size(393, 852),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await h.signIn();
  await tester.pumpWidget(
    MaterialApp(
      theme: docDiaryTheme(),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
      home: Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                onPressed:
                    () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => AnalyticsDashboardScreen(
                              auth: h.auth,
                              repository: h.repository,
                            ),
                      ),
                    ),
                child: const Text('Open Analytics'),
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.text('Open Analytics'));
  await tester.pump();
  if (settle) await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'analytics reads encoded rows, uses server unique count and checks access before reading',
    () async {
      final h = _AnalyticsHarness();
      await h.signIn();
      final session = h.auth.session!;
      final profile = h.auth.profile!;
      final range = AnalyticsRange(DateTime(2026, 11), h.now);
      final result = await h.repository.login(
        session,
        profile,
        range,
        portal: false,
        isCurrent: () => true,
      );
      expect(result.trend.total(0), 200);
      expect(result.trend.total(1), 92);
      expect(result.unique, 91);
      expect(result.trend.plotPoints.map((p) => p.values.first), [0, 200, 0]);
      expect(h.reads.last.queryParameters, {
        'begin_date': '01-Nov-26',
        'end_date': '04-Nov-26',
        'p_log_type': '3',
      });
      await expectLater(
        h.repository.login(
          session,
          profile,
          range,
          portal: false,
          isCurrent: () => false,
        ),
        throwsA(isA<ObsoleteRequest>()),
      );
      expect(h.reads.length, 2);
    },
  );

  test(
    'bad analytics rows stop the native pair and future dates make no request',
    () async {
      final h = _AnalyticsHarness();
      await h.signIn();
      h.intercept = (_) async => {'count': 2, 'items': <JsonMap>[]};
      await expectLater(
        h.repository.login(
          h.auth.session!,
          h.auth.profile!,
          AnalyticsRange.today(h.now),
          portal: false,
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.reads.length, 1);
      await expectLater(
        h.repository.login(
          h.auth.session!,
          h.auth.profile!,
          AnalyticsRange.today(h.now.add(const Duration(days: 1))),
          portal: false,
          isCurrent: () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.reads.length, 1);
    },
  );

  testWidgets(
    'portal flag hides the OPAS sections and limits the native chain',
    (tester) async {
      final h = _AnalyticsHarness(portal: false);
      await _open(tester, h);
      expect(find.text('MOBILE APPS'), findsOneWidget);
      expect(find.text('ONLINE PATIENT PORTAL'), findsNothing);
      expect(h.reads.map((u) => u.pathSegments.last), [
        'getAppLoginStatus',
        'getTotalUnqLogin',
      ]);
    },
  );

  testWidgets(
    'all sections load in native order and payment dates reload only payment',
    (tester) async {
      final h = _AnalyticsHarness();
      await _open(tester, h);
      expect(h.reads.map((u) => u.pathSegments.last), [
        'getAppLoginStatus',
        'getTotalUnqLogin',
        'getOPASLoginStatus',
        'getTotalUnqLogin',
        'getAppInitCountStatus',
        'getAppSchCountStatus',
        'getOPASPayStatus',
        'getOPASCardPayStatus',
      ]);
      expect(h.reads[3].queryParameters['p_log_type'], '1');
      await _tap(tester, 'analytics_range_payments');
      final picker = find.byKey(const Key('analytics_date_picker'));
      final dialog = tester.widget<DateRangePickerDialog>(picker);
      expect(
        dialog.selectableDayPredicate!(DateTime(2026, 11, 5), null, null),
        isFalse,
      );
      Navigator.pop(
        tester.element(picker),
        DateTimeRange(start: DateTime(2026, 11), end: DateTime(2026, 11, 4)),
      );
      await tester.pumpAndSettle();
      expect(h.reads.length, 10);
      expect(h.reads[8].pathSegments.last, 'getOPASPayStatus');
      expect(h.reads[9].pathSegments.last, 'getOPASCardPayStatus');
      expect(h.reads[9].queryParameters['begin_date'], '01-Nov-26');
      expect(find.text('01-November-26  ---  04-November-26'), findsOneWidget);
      expect(find.text('04-November-26'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed and no-result bars load the correct reasons and deselect cleanly',
    (tester) async {
      final h = _AnalyticsHarness();
      await _open(tester, h);
      await _tap(tester, 'analytics_bar_1_failed');
      expect(h.reads.last.pathSegments.last, 'getCardWiseFailedResult');
      expect(h.reads.last.queryParameters['card_name'], 'Example & Visa');
      expect(find.text('Example decline'), findsOneWidget);
      expect(
        find.text('Example & Visa - Failed Status\nTotal : 1'),
        findsOneWidget,
      );
      await _tap(tester, 'analytics_bar_0_noResult');
      expect(h.reads.last.pathSegments.last, 'getCardWiseNRResult');
      expect(find.text('Example timeout'), findsOneWidget);
      expect(find.text('Example decline'), findsNothing);
      final before = h.reads.length;
      await _tap(tester, 'analytics_bar_0_completed');
      expect(h.reads.length, before);
      expect(find.byKey(const Key('analytics_reason_heading')), findsNothing);
      expect(find.text('0 (0%)'), findsWidgets);
    },
  );

  testWidgets(
    'loading blocks Back with toast and Retry restarts the failed chain',
    (tester) async {
      final h = _AnalyticsHarness(portal: false);
      final gate = Completer<JsonMap>();
      h.intercept = (_) => gate.future;
      final toast = ToastRecorder()..install();
      addTearDown(toast.uninstall);
      await _open(tester, h, settle: false);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('analytics_back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(toast.messages, contains('Please wait while loading'));
      expect(find.byType(AnalyticsDashboardScreen), findsOneWidget);
      h.intercept = null;
      gate.complete({'count': 1, 'items': <JsonMap>[]});
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('analytics_error')), findsOneWidget);
      await _tap(tester, 'analytics_error_retry');
      expect(find.text('MOBILE APPS'), findsOneWidget);
      expect(h.reads.length, 3);
    },
  );

  testWidgets(
    'resume rechecks analytics permission and clears restricted data',
    (tester) async {
      final h = _AnalyticsHarness();
      await _open(tester, h);
      final before = h.reads.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      h.adminData['usr_mob_app_analytic_access'] = '0';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(h.reads.length, before);
      expect(
        find.text('Analytics Dashboard is not available for this account.'),
        findsOneWidget,
      );
      expect(find.text('MOBILE APPS'), findsNothing);
    },
  );

  testWidgets('small phone and large text fit the card and reason table', (
    tester,
  ) async {
    final h = _AnalyticsHarness();
    await _open(tester, h, size: const Size(320, 568), scale: 2);
    await _tap(tester, 'analytics_bar_1_failed');
    expect(find.byKey(const Key('analytics_reason_heading')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

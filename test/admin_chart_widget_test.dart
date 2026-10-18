import 'dart:async';

import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/dashboard/admin_chart_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/native_admin_line_chart.dart';
import 'package:docdiary_ios/features/dashboard/native_admin_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

JsonMap _response(Uri uri, {String? amount}) {
  final yearly = uri.path.endsWith('Yearly');
  return {
    'count': 3,
    'items': [
      for (var i = 0; i < 3; i++)
        {
          (yearly ? 'pmonths' : 'dates'):
              yearly ? ['JAN', 'FEB', 'MAR'][i] : '${i + 1}',
          'amount': amount ?? '${(i + 1) * 1000}.50',
          'amount1': (i + 1) * 10,
          'total_app': (i + 1) * 10,
          'cancel_app': i + 1,
        },
    ],
  };
}

bool _chart(Uri uri) =>
    uri.path.contains('getPaymentData') || uri.path.contains('getAppointData');
List<RequestRecord> _reads(Harness h) =>
    h.transport.requests.where((r) => _chart(r.uri)).toList();

Future<Harness> _signedAdmin({
  bool types = true,
  bool appOwnsAuth = false,
}) async {
  final h = Harness(clock: DateTime(2026, 10, 17, 10, 30));
  h.loginResponse = adminLogin();
  h.adminData['usr_id'] = '70';
  h.adminData['is_pay_appoint_type_active'] = types ? '1' : '0';
  await h.signIn();
  if (!appOwnsAuth) {
    addTearDown(h.auth.dispose);
  }
  h.transport.onGet =
      (uri) async => _chart(uri) ? _response(uri) : h.defaultGet(uri);
  return h;
}

Future<void> _show(
  WidgetTester tester,
  Harness h, {
  int revision = 0,
  double width = 393,
  double textScale = 1,
  bool app = false,
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(
    app
        ? DocDiaryApp(
          auth: h.auth,
          dashboard: DashboardRepository(h.transport, now: () => h.now),
          initializeOnStart: false,
        )
        : MaterialApp(
          theme: docDiaryTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 852),
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: NativeAdminOverview(
                  key: const ValueKey('test_overview'),
                  auth: h.auth,
                  profile: h.auth.profile!,
                  repository: AdminChartRepository(
                    h.transport,
                    now: () => h.now,
                  ),
                  sdp: 1.3,
                  refreshRevision: revision,
                ),
              ),
            ),
          ),
        ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  expect(tester.takeException(), isNull);
}

Future<void> _tap(WidgetTester tester, String key, {bool settle = true}) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
    'native overview shows both series, totals and independent year selections',
    (tester) async {
      final h = await _signedAdmin();
      final writes = h.posts.length;
      await _show(tester, h);
      expect(find.text('OVERVIEW'), findsOneWidget);
      expect(find.text('MONTH: OCT-26'), findsNWidgets(2));
      expect(find.text('Payment Receive'), findsOneWidget);
      expect(find.text('Payment Return'), findsOneWidget);
      expect(find.text('৳ 6,002'), findsOneWidget);
      expect(find.text('৳ 60'), findsOneWidget);
      expect(find.text('Cancel Appointment: '), findsOneWidget);
      await _tap(tester, 'admin_chart_mode_yearly');
      final before = _reads(h).length;
      await _tap(tester, 'admin_chart_date_payment');
      await _tap(tester, 'admin_chart_year_2025');
      expect(_reads(h).length, before);
      await _tap(tester, 'admin_chart_date_ok');
      expect(_reads(h).length, before + 1);
      expect(_reads(h).last.uri.path.endsWith('getPaymentDataYearly'), isTrue);
      expect(_reads(h).last.uri.queryParameters['begin_date'], '01-JAN-25');
      expect(find.text('YEAR: 2025'), findsOneWidget);
      expect(find.text('YEAR: 2026'), findsOneWidget);
      await _tap(tester, 'admin_chart_type_online');
      expect(find.text('YEAR: 2026'), findsNWidgets(2));
      expect(
        _reads(
          h,
        ).reversed.take(2).every((r) => r.uri.path.endsWith('OnlineYearly')),
        isTrue,
      );
      expect(h.posts.length, writes);
      await _finish(tester);
    },
  );

  testWidgets('month wheel Cancel keeps dates; OK reloads only its chart', (
    tester,
  ) async {
    final h = await _signedAdmin();
    await _show(tester, h);
    final before = _reads(h).length;
    await _tap(tester, 'admin_chart_date_payment');
    var wheel = tester.widget<ListWheelScrollView>(
      find.byKey(const Key('admin_chart_month_wheel')),
    );
    (wheel.controller! as FixedExtentScrollController).jumpToItem(
      8,
    ); // September.
    await tester.pumpAndSettle();
    await _tap(tester, 'admin_chart_date_cancel');
    expect(_reads(h).length, before);
    expect(find.text('MONTH: OCT-26'), findsNWidgets(2));
    await _tap(tester, 'admin_chart_date_payment');
    wheel = tester.widget<ListWheelScrollView>(
      find.byKey(const Key('admin_chart_month_wheel')),
    );
    (wheel.controller! as FixedExtentScrollController).jumpToItem(8);
    await tester.pumpAndSettle();
    await _tap(tester, 'admin_chart_date_ok');
    expect(_reads(h).length, before + 1);
    expect(_reads(h).last.uri.queryParameters['begin_date'], '01-SEP-26');
    expect(_reads(h).last.uri.queryParameters['end_date'], '30-SEP-26');
    expect(find.text('MONTH: SEP-26'), findsOneWidget);
    expect(find.text('MONTH: OCT-26'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('type selectors obey is_pay_appoint_type_active', (tester) async {
    final h = await _signedAdmin(types: false);
    await _show(tester, h);
    expect(find.byKey(const Key('admin_chart_type_all')), findsNothing);
    expect(find.byKey(const Key('admin_chart_type_online')), findsNothing);
    expect(find.byKey(const Key('admin_chart_card_payment')), findsOneWidget);
    expect(
      _reads(h).every(
        (r) =>
            !r.uri.path.contains('Online') && !r.uri.path.contains('Offline'),
      ),
      isTrue,
    );
    await _finish(tester);
  });

  testWidgets(
    'a newer type selection wins over an older in-flight card response',
    (tester) async {
      final h = await _signedAdmin();
      final pending = Completer<JsonMap>();
      Uri? held;
      var paymentCalls = 0;
      h.transport.onGet = (uri) async {
        if (uri.path.contains('getPaymentData')) {
          paymentCalls++;
          if (paymentCalls == 2) {
            held = uri;
            return pending.future;
          }
        }
        return _chart(uri)
            ? _response(uri, amount: uri.path.contains('Online') ? '50' : null)
            : h.defaultGet(uri);
      };
      await _show(tester, h);
      await _tap(tester, 'admin_chart_date_payment');
      await _tap(tester, 'admin_chart_date_ok', settle: false);
      await tester.pump(
        const Duration(milliseconds: 400),
      ); // Finish dialog dismissal, not its pending read.
      expect(
        find.byKey(const Key('admin_chart_loading_payment')),
        findsOneWidget,
      );
      await _tap(tester, 'admin_chart_type_online');
      expect(find.text('৳ 150'), findsOneWidget);
      pending.complete(_response(held!, amount: '999'));
      await tester.pumpAndSettle();
      expect(find.text('৳ 150'), findsOneWidget);
      expect(find.text('৳ 2,997'), findsNothing);
      expect(find.text('Error!'), findsNothing);
      await _finish(tester);
    },
  );

  testWidgets(
    'one chart error hides its totals and retries without reloading the other chart',
    (tester) async {
      final h = await _signedAdmin();
      var paymentCalls = 0;
      var appointmentCalls = 0;
      h.transport.onGet = (uri) async {
        if (uri.path.contains('getPaymentData')) {
          paymentCalls++;
          if (paymentCalls == 2) {
            throw const AppFailure('Example payment connection failure');
          }
        }
        if (uri.path.contains('getAppointData')) {
          appointmentCalls++;
        }
        return _chart(uri) ? _response(uri) : h.defaultGet(uri);
      };
      final writes = h.posts.length;
      await _show(tester, h);
      await _tap(tester, 'admin_chart_date_payment');
      await _tap(tester, 'admin_chart_date_ok');
      expect(find.text('Error!'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin_chart_totals_payment')), findsNothing);
      expect(
        find.byKey(const Key('admin_chart_totals_appointment')),
        findsOneWidget,
      );
      await _tap(tester, 'admin_chart_retry_payment');
      expect(paymentCalls, 3);
      expect(appointmentCalls, 1);
      expect(
        find.byKey(const Key('admin_chart_totals_payment')),
        findsOneWidget,
      );
      expect(h.posts.length, writes);
      await _finish(tester);
    },
  );

  testWidgets(
    'global error displays native retry and does not invent empty charts',
    (tester) async {
      final h = await _signedAdmin();
      var fail = true;
      h.transport.onGet = (uri) async {
        if (_chart(uri)) {
          if (fail) {
            throw const AppFailure('Example overview connection failure');
          }
          return _response(uri);
        }
        return h.defaultGet(uri);
      };
      await _show(tester, h);
      expect(find.text('Error!'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('admin_chart_totals_payment')), findsNothing);
      expect(find.text('No chart data available.'), findsNothing);
      fail = false;
      await _tap(tester, 'admin_chart_retry_all');
      expect(
        find.byKey(const Key('admin_chart_totals_payment')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('admin_chart_totals_appointment')),
        findsOneWidget,
      );
      await _finish(tester);
    },
  );

  testWidgets(
    'summary period changes preserve chart dates; resume resets Monthly All without login POSTs',
    (tester) async {
      final h = await _signedAdmin(appOwnsAuth: true);
      final writes = h.posts.length;
      await _show(tester, h, app: true);
      await _tap(tester, 'admin_chart_mode_yearly');
      await _tap(tester, 'admin_chart_date_payment');
      await _tap(tester, 'admin_chart_year_2025');
      await _tap(tester, 'admin_chart_date_ok');
      final before = _reads(h).length;
      await _tap(tester, 'dashboard_period_currentWeek');
      expect(find.text('YEAR: 2025'), findsOneWidget);
      expect(find.text('YEAR: 2026'), findsOneWidget);
      expect(_reads(h).length, before);
      await _tap(tester, 'admin_chart_type_online');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      h.now = h.now.add(const Duration(seconds: 70));
      await tester.pump(const Duration(seconds: 1));
      final pausedReads = _reads(h).length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_reads(h).length, pausedReads + 2);
      expect(_reads(h).last.uri.path.endsWith('getAppointDataMonthly'), isTrue);
      expect(find.text('MONTH: OCT-26'), findsNWidgets(2));
      expect(h.posts.length, writes);
      await _finish(tester);
    },
  );

  testWidgets(
    'pause invalidates a pending batch and stops its queued appointment read',
    (tester) async {
      final h = await _signedAdmin();
      final pending = Completer<JsonMap>();
      Uri? held;
      var first = true;
      h.transport.onGet = (uri) async {
        if (uri.path.contains('getPaymentData') && first) {
          first = false;
          held = uri;
          return pending.future;
        }
        return _chart(uri) ? _response(uri) : h.defaultGet(uri);
      };
      await _show(tester, h, settle: false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      pending.complete(_response(held!));
      await tester.pump(const Duration(seconds: 1));
      expect(
        _reads(h).where((r) => r.uri.path.contains('getAppointData')),
        isEmpty,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _show(tester, h, revision: 1);
      expect(
        _reads(h).where((r) => r.uri.path.contains('getAppointData')).length,
        1,
      );
      expect(
        find.byKey(const Key('admin_chart_totals_payment')),
        findsOneWidget,
      );
      await _finish(tester);
    },
  );

  testWidgets(
    'tap shows the native value marker; horizontal pinch scales X only',
    (tester) async {
      final h = await _signedAdmin();
      await _show(tester, h);
      final canvas = find.byKey(const Key('admin_chart_canvas_payment'));
      await tester.ensureVisible(canvas);
      final rect = tester.getRect(canvas);
      await tester.tapAt(Offset(rect.center.dx, rect.top + 35));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('admin_chart_marker_payment')),
        findsOneWidget,
      );
      expect(find.text('৳ 2,001'), findsOneWidget);
      final a = await tester.createGesture(pointer: 1);
      final b = await tester.createGesture(pointer: 2);
      await a.down(rect.center - const Offset(50, 0));
      await b.down(rect.center + const Offset(50, 0));
      await tester.pump();
      await a.moveBy(const Offset(-40, 0));
      await b.moveBy(const Offset(40, 0));
      await tester.pump();
      final painter =
          tester.widget<CustomPaint>(canvas).painter! as NativeAdminLinePainter;
      expect(painter.zoomX, greaterThan(1));
      expect(painter.zoomY, 1);
      expect(find.byKey(const Key('admin_chart_marker_payment')), findsNothing);
      await a.up();
      await b.up();
      await _finish(tester);
    },
  );

  testWidgets(
    'logout closes an owned date dialog without keeping the old chart active',
    (tester) async {
      final h = await _signedAdmin(appOwnsAuth: true);
      await _show(tester, h, app: true);
      await _tap(tester, 'admin_chart_date_payment');
      final reads = _reads(h).length;
      final writes = h.posts.length;
      await h.auth.logout();
      await tester.pumpAndSettle();
      expect(h.auth.session, isNull);
      expect(find.byKey(const Key('admin_chart_date_dialog')), findsNothing);
      expect(find.byKey(const Key('admin_overview')), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(_reads(h).length, reads);
      expect(h.posts.length, writes);
      await _finish(tester);
    },
  );

  testWidgets('small screens and large text render without overflow', (
    tester,
  ) async {
    final h = await _signedAdmin();
    for (final width in [320.0, 393.0, 852.0]) {
      await _show(tester, h, width: width, textScale: 2);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    await _finish(tester);
  });
}

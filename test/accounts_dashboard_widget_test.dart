import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/features/accounts/accounts_dashboard_navigation.dart';
import 'package:docdiary_ios/features/accounts/accounts_dashboard_screen.dart';
import 'package:docdiary_ios/features/accounts/native_accounts_dashboard_layout.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'accounts_dashboard_test_support.dart';

Future<void> tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      f,
      100,
      scrollable: find.descendant(
        of: find.byKey(const Key('accounts_menu_list')),
        matching: find.byType(Scrollable),
      ),
    );
  }
  if (f.hitTestable().evaluate().isEmpty) {
    await t.ensureVisible(f);
    await t.pump();
  }
  await t.tap(f);
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

void pause(WidgetTester t) {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    t.binding.handleAppLifecycleStateChanged(s);
  }
}

void resume(WidgetTester t) {
  if (t.binding.lifecycleState == AppLifecycleState.paused) {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

Future<void> host(
  WidgetTester t,
  AccountsHarness h, {
  Size size = const Size(393, 852),
  double zoom = 1,
  bool app = false,
  DashboardDestinationBuilder? builder,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.view.padding = FakeViewPadding(
    top: size.width > size.height ? 24 : 59,
    bottom: size.width > size.height ? 20 : 34,
  );
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPadding);
  if (!app) addTearDown(h.auth.dispose);
  resume(t);
  await h.signIn();
  h.transport.requests.clear();
  await t.pumpWidget(
    RepaintBoundary(
      key: const Key('accounts_capture'),
      child:
          app
              ? DocDiaryApp(
                auth: h.auth,
                initializeOnStart: false,
                dashboard: DashboardRepository(h.transport, now: () => h.now),
              )
              : MaterialApp(
                theme: docDiaryTheme(),
                debugShowCheckedModeBanner: false,
                builder:
                    (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(zoom)),
                      child: child!,
                    ),
                home: Builder(
                  builder:
                      (context) => Scaffold(
                        body: TextButton(
                          key: const Key('open_accounts'),
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => AccountsDashboardScreen(
                                        auth: h.auth,
                                        repository: h.accounts,
                                        destinationBuilder: builder,
                                      ),
                                ),
                              ),
                          child: const Text('Test home'),
                        ),
                      ),
                ),
              ),
    ),
  );
  await t.pumpAndSettle();
  if (app) {
    await tap(t, 'dashboard_nav_management');
    await tap(t, 'management_accounts');
  } else {
    await tap(t, 'open_accounts');
  }
}

Future<void> finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

String caption(WidgetTester t, String key) =>
    t.widget<Text>(find.byKey(Key(key))).data!;
Future<void> capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_ACCOUNTS_CAPTURE_DIR'];
  if (dir == null) return;
  await t.runAsync(() async {
    final context = t.element(find.byType(NativeAccountsDashboardLayout));
    for (final file in [
      'accounting_icon.png',
      ...AccountsDestination.values.map((d) => d.artwork),
    ]) {
      await precacheImage(AssetImage('assets/images/$file'), context);
    }
  });
  await t.pumpAndSettle();
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('accounts_capture')),
  );
  await t.runAsync(() async {
    final im = await boundary.toImage(pixelRatio: 2);
    final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
    im.dispose();
    final f = File('$dir/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry
        in <String, List<String>>{
          'Poppins': [
            'Poppins-Regular.ttf',
            'Poppins-Medium.ttf',
            'Poppins-Bold.ttf',
          ],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
          'Archivo': ['Archivo[wdth,wght].ttf'],
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
          'PatuaOne': ['PatuaOne-Regular.ttf'],
          'DocDiaryBengali': ['NotoSansBengali.ttf'],
        }.entries) {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  void check(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (t) async {
        final old = debugDisableShadows;
        debugDisableShadows = false;
        try {
          await body(t);
        } finally {
          debugDisableShadows = old;
        }
      });
  for (final role in ['1', '3']) {
    check('real management route opens Accounts Dashboard for role $role', (
      t,
    ) async {
      final h = AccountsHarness();
      h.adminData['all_access_flag'] = role;
      await host(t, h, app: true);
      expect(find.byType(AccountsDashboardScreen), findsOneWidget);
      expect(caption(t, 'accounts_total_voucher'), '8');
      expect(caption(t, 'accounts_amount'), '10200 (Net Profit)');
      if (role == '1') {
        await capture(t, '01_dashboard_today');
        await t.ensureVisible(find.byKey(const Key('accounts_total_expense')));
        await t.pumpAndSettle();
        await capture(t, '02_income_expense');
      }
      expect(h.accountReads.length, 3);
      await finish(t);
    });
  }
  check('periods refresh all datasets and fixed date label, reset scroll', (
    t,
  ) async {
    final h = AccountsHarness();
    await host(t, h);
    await tap(t, 'accounts_period_lastMonth');
    expect(
      caption(t, 'accounts_date_range'),
      '01 October, 26  --  31 October, 26',
    );
    expect(h.accountReads.last.uri.queryParameters['end_date'], '31-Oct-26');
    await capture(t, '03_last_month');
    await tap(t, 'accounts_period_currentWeek');
    expect(
      caption(t, 'accounts_date_range'),
      '31 October, 26  --  06 November, 26',
    );
    await tap(t, 'accounts_period_currentMonth');
    expect(
      caption(t, 'accounts_date_range'),
      '01 November, 26  --  30 November, 26',
    );
    expect(h.accountReads.length, 12);
    await finish(t);
  });
  check(
    'right menu has native icons and order; close and system Back only close drawer',
    (t) async {
      final h = AccountsHarness();
      await host(t, h);
      await tap(t, 'accounts_menu');
      expect(
        find.byKey(const Key('accounts_menu_dailyStatement')),
        findsNothing,
      );
      for (final d in accountsDestinations(h.auth.session!.center.baseUri)) {
        expect(find.byKey(Key('accounts_menu_${d.name}')), findsOneWidget);
      }
      await capture(t, '04_accounts_menu');
      await tap(t, 'accounts_drawer_close');
      expect(find.text('Accounts Menu'), findsNothing);
      await tap(t, 'accounts_menu');
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Accounts Menu'), findsNothing);
      expect(find.byType(AccountsDashboardScreen), findsOneWidget);
      await finish(t);
    },
  );
  check(
    'special centre shows eight menu entries and Daily Statement takes today',
    (t) async {
      final h = AccountsHarness(), routes = <DashboardRoute>[];
      h.loginResponse['p_center_api'] = 'https://centre.example/ords/cstar/';
      await host(
        t,
        h,
        builder: (context, route) {
          routes.add(route);
          return const Scaffold(body: Text('Synthetic child'));
        },
      );
      await tap(t, 'accounts_period_lastMonth');
      await tap(t, 'accounts_menu');
      await capture(t, '05_accounts_menu_special_centre');
      await tap(t, 'accounts_menu_dailyStatement');
      expect(routes.single.module, DashboardModule.accountsDailyStatement);
      expect(routes.single.extras['FIRST_DATE'], '02-Nov-26');
      expect(routes.single.extras['LAST_DATE'], '02-Nov-26');
      await finish(t);
    },
  );
  check(
    'chart routes carry selected dates, menu ledger carries blank dates, child return resets Today',
    (t) async {
      final h = AccountsHarness(), routes = <DashboardRoute>[];
      await host(
        t,
        h,
        builder: (context, route) {
          routes.add(route);
          return Scaffold(
            body: TextButton(
              key: const Key('child_back'),
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          );
        },
      );
      await tap(t, 'accounts_voucher_pie');
      expect(routes.last.extras, {'FIRST_DATE': '', 'LAST_DATE': ''});
      await tap(t, 'child_back');
      await tap(t, 'accounts_period_lastMonth');
      await tap(t, 'accounts_voucher_pie');
      expect(routes.last.extras, {
        'FIRST_DATE': '01-Oct-26',
        'LAST_DATE': '31-Oct-26',
      });
      await tap(t, 'child_back');
      expect(caption(t, 'accounts_date_range'), '02 November, 26');
      await tap(t, 'accounts_menu');
      await tap(t, 'accounts_menu_accountLedger');
      expect(routes.last.extras, {
        'FIRST_DATE': '',
        'LAST_DATE': '',
        'AD_ID': '',
      });
      await finish(t);
    },
  );
  check(
    'deferred menu pages explain unavailability and leave dashboard intact',
    (t) async {
      final h = AccountsHarness();
      await host(t, h);
      await tap(t, 'accounts_menu');
      await tap(t, 'accounts_menu_creditApproval');
      expect(find.byKey(const Key('accounts_unavailable')), findsOneWidget);
      await tap(t, 'accounts_unavailable_close');
      expect(caption(t, 'accounts_total_voucher'), '8');
      await finish(t);
    },
  );
  check('decimal net loss stays exact and empty period clears totals/charts', (
    t,
  ) async {
    final h = AccountsHarness();
    h.amountRows = [
      {'amount': '-139.05'},
    ];
    h.incomeRows = [
      {'income': '200.10', 'expense': '339.15'},
    ];
    await host(t, h);
    expect(caption(t, 'accounts_amount'), '139.05 (Net Loss)');
    await capture(t, '06_decimal_loss');
    h.voucherRows = [];
    h.amountRows = [];
    h.incomeRows = [
      {'income': '0.00', 'expense': '0.0'},
    ];
    await tap(t, 'accounts_period_currentMonth');
    expect(caption(t, 'accounts_total_voucher'), '0');
    expect(caption(t, 'accounts_amount'), '0 (Break Even Point)');
    await capture(t, '07_no_data');
    await finish(t);
  });
  check('error is atomic and Retry preserves selected period', (t) async {
    final h = AccountsHarness();
    await host(t, h);
    h.onAccountsGet = (u) async {
      if (u.path.endsWith('getIncomeExpense'))
        throw const AppFailure(
          'Synthetic network error',
          kind: FailureKind.network,
        );
      return null;
    };
    await tap(t, 'accounts_period_lastMonth');
    expect(find.byKey(const Key('accounts_error')), findsOneWidget);
    expect(find.byKey(const Key('accounts_total_voucher')), findsNothing);
    await capture(t, '08_error');
    h.onAccountsGet = null;
    await tap(t, 'accounts_error_retry');
    expect(
      caption(t, 'accounts_date_range'),
      '01 October, 26  --  31 October, 26',
    );
    await finish(t);
  });
  check('Exit on load error returns to parent', (t) async {
    final h = AccountsHarness();
    h.onAccountsGet = (_) async => throw const AppFailure('Synthetic failure');
    await host(t, h);
    await tap(t, 'accounts_error_exit');
    expect(find.byType(AccountsDashboardScreen), findsNothing);
    expect(find.text('Test home'), findsOneWidget);
    await finish(t);
  });
  check('resume refreshes profile without LoginLog and resets Today', (
    t,
  ) async {
    final h = AccountsHarness();
    await host(t, h);
    await tap(t, 'accounts_period_lastMonth');
    final posts = h.posts.length;
    pause(t);
    await t.pump();
    resume(t);
    await t.pumpAndSettle();
    expect(caption(t, 'accounts_date_range'), '02 November, 26');
    expect(h.posts.length, posts);
    expect(h.accountReads.length, 9);
    await finish(t);
  });
  check('late background response cannot restore old financial values', (
    t,
  ) async {
    final h = AccountsHarness();
    final pending = Completer<void>();
    var hold = false;
    h.onAccountsGet = (_) async {
      if (hold) await pending.future;
      return null;
    };
    await host(t, h);
    hold = true;
    await t.tap(find.byKey(const Key('accounts_period_lastMonth')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    pause(t);
    pending.complete();
    await t.pumpAndSettle();
    expect(find.byKey(const Key('accounts_total_voucher')), findsNothing);
    hold = false;
    resume(t);
    await t.pumpAndSettle();
    expect(caption(t, 'accounts_date_range'), '02 November, 26');
    await finish(t);
  });
  check(
    'fresh profile revocation blocks retained menu actions and clears data',
    (t) async {
      final h = AccountsHarness();
      await host(t, h);
      await tap(t, 'accounts_menu');
      h.adminData['acc_dashboard'] = '0';
      await tap(t, 'accounts_menu_creditApproval');
      expect(find.byKey(const Key('accounts_unavailable')), findsNothing);
      expect(find.byKey(const Key('accounts_total_voucher')), findsNothing);
      expect(
        find.text(
          'Accounts Dashboard access is not available for this account.',
        ),
        findsOneWidget,
      );
      expect(h.accountReads.length, 3);
      await finish(t);
    },
  );
  check('logout clears financial data and closes owned menu', (t) async {
    final h = AccountsHarness();
    await host(t, h);
    await tap(t, 'accounts_menu');
    await h.auth.logout();
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.pump();
    expect(find.byKey(const Key('accounts_total_voucher')), findsNothing);
    expect(find.text('Accounts Menu'), findsNothing);
    await finish(t);
  });
  for (final e
      in {
        'small': (const Size(320, 568), 1.0),
        'landscape': (const Size(852, 393), 1.0),
        'large_text': (const Size(393, 852), 1.8),
      }.entries) {
    check('responsive dashboard and menu scroll at ${e.key}', (t) async {
      final h = AccountsHarness();
      await host(t, h, size: e.value.$1, zoom: e.value.$2);
      await capture(t, '09_dashboard_${e.key}');
      await t.ensureVisible(find.byKey(const Key('accounts_total_expense')));
      await t.pumpAndSettle();
      await capture(t, '10_footer_${e.key}');
      await tap(t, 'accounts_menu');
      await capture(t, '11_menu_${e.key}');
      await tap(t, 'accounts_menu_patientLedger');
      expect(find.byKey(const Key('accounts_unavailable')), findsOneWidget);
      await finish(t);
    });
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/login_screen.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_services.dart';
import 'package:docdiary_ios/features/dashboard/native_dashboard_layout.dart';
import 'package:docdiary_ios/features/management/management_access.dart';
import 'package:docdiary_ios/features/management/management_menu_screen.dart';
import 'package:docdiary_ios/features/management/native_management_portal_layout.dart';
import 'package:docdiary_ios/features/reports/native_report_manager_layout.dart';
import 'package:docdiary_ios/features/reports/report_manager_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';

Harness _admin({String role = '1', String module = '1'}) =>
    Harness()
      ..loginResponse = adminLogin()
      ..adminData.addAll({
        'all_access_flag': role,
        'hr_acc_active_flag': module,
        'hr_dashboard': '1',
        'acc_dashboard': '1',
        'usr_mob_app_analytic_access': '1',
        'hr_payment_active': '0',
        'hr_appointment_active': '1',
        'acc_payment_active': '1',
        'acc_appointment_active': '0',
      });

void _case(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    final shadows = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = shadows;
    }
  });
}

Future<void> _show(
  WidgetTester t,
  Harness h, {
  DashboardDestinationBuilder? builder,
}) async {
  t.view.physicalSize = const Size(393, 852);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await h.signIn();
  await t.pumpWidget(
    DocDiaryApp(
      auth: h.auth,
      initializeOnStart: false,
      dashboard: DashboardRepository(h.transport, now: () => h.now),
      dashboardServices: DashboardServices(destinationBuilder: builder),
    ),
  );
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> _tap(WidgetTester t, String key) async {
  final target = find.byKey(Key(key));
  if (target.hitTestable().evaluate().isEmpty) await t.ensureVisible(target);
  await t.tap(target);
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
  expect(t.takeException(), isNull);
}

void _pause(WidgetTester t) =>
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
void _resume(WidgetTester t) =>
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

Future<void> _capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_MANAGEMENT_CAPTURE_DIR'];
  if (dir == null) return;
  await t.runAsync(() async {
    final context = t.element(find.byType(NativeManagementPortalLayout));
    for (final asset in [
      'hr_icon.png',
      'accounting_icon.png',
      'data_analytics.png',
      'report.png',
    ]) {
      await precacheImage(AssetImage('assets/images/$asset'), context);
    }
  });
  await t.pumpAndSettle();
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('management_capture')),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('$dir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'))).load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  _case(
    'live Dashboard opens Management Portal then Reports and refreshes on Back without login writes',
    (t) async {
      final h = _admin();
      await _show(t, h);
      final posts = h.posts.length;
      await _tap(t, 'dashboard_nav_management');
      expect(find.text('Management Portal'), findsOneWidget);
      for (final item in ManagementDestination.values) {
        expect(find.byKey(Key('management_${item.name}')), findsOneWidget);
      }
      await _tap(t, 'management_reports');
      expect(find.byType(NativeReportManagerLayout), findsOneWidget);
      expect(find.text('Payment Receive Register Report'), findsNothing);
      await _tap(t, 'report_manager_back');
      expect(find.byType(NativeManagementPortalLayout), findsOneWidget);
      final reads = h.transport.requests.length;
      await _tap(t, 'management_back');
      expect(find.byType(NativeDashboardLayout), findsOneWidget);
      expect(h.transport.requests.length, greaterThan(reads));
      expect(h.posts.length, posts);
      await _finish(t);
    },
  );

  for (final role in ['2', '3']) {
    _case(
      'role $role only shows its permitted dashboard even when every flag is 1',
      (t) async {
        final h = _admin(role: role);
        await _show(t, h);
        expect(
          find.byKey(const Key('dashboard_nav_payment')),
          role == '3' ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const Key('dashboard_nav_appointment')),
          role == '2' ? findsOneWidget : findsNothing,
        );
        await _tap(t, 'dashboard_nav_management');
        expect(
          find.text(role == '2' ? 'HR & Reports' : 'Accounts & Reports'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('management_humanResources')),
          role == '2' ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const Key('management_accounts')),
          role == '3' ? findsOneWidget : findsNothing,
        );
        expect(find.byKey(const Key('management_analytics')), findsNothing);
        expect(find.byKey(const Key('management_reports')), findsOneWidget);
        await _finish(t);
      },
    );
  }

  for (final config in [(role: '1', module: '0'), (role: '0', module: '1')]) {
    _case(
      'role ${config.role} module ${config.module} opens Reports directly',
      (t) async {
        final h = _admin(role: config.role, module: config.module);
        await _show(t, h);
        await _tap(t, 'dashboard_nav_management');
        expect(find.byType(NativeReportManagerLayout), findsOneWidget);
        expect(
          find.byKey(const Key('management_humanResources')),
          findsNothing,
        );
        await _tap(t, 'report_manager_back');
        expect(find.byType(NativeDashboardLayout), findsOneWidget);
        await _finish(t);
      },
    );
  }

  _case(
    'access flags are refreshed on resume and all-access cannot preserve revoked cards',
    (t) async {
      final h = _admin();
      await _show(t, h);
      await _tap(t, 'dashboard_nav_management');
      final posts = h.posts.length;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await t.pump();
      expect(find.byKey(const Key('management_humanResources')), findsNothing);
      _pause(t);
      h.adminData.addAll({'all_access_flag': '3', 'acc_dashboard': '0'});
      _resume(t);
      await t.pumpAndSettle();
      expect(find.text('Accounts & Reports'), findsOneWidget);
      expect(find.byKey(const Key('management_humanResources')), findsNothing);
      expect(find.byKey(const Key('management_accounts')), findsNothing);
      expect(find.byKey(const Key('management_analytics')), findsNothing);
      expect(find.byKey(const Key('management_reports')), findsOneWidget);
      expect(h.posts.length, posts);
      await _finish(t);
    },
  );

  _case('revoking the HR/Accounts module while open falls back to Reports', (
    t,
  ) async {
    final h = _admin();
    await _show(t, h);
    await _tap(t, 'dashboard_nav_management');
    _pause(t);
    h.adminData['hr_acc_active_flag'] = '0';
    _resume(t);
    await t.pumpAndSettle();
    expect(find.byType(NativeReportManagerLayout), findsOneWidget);
    expect(find.byKey(const Key('management_analytics')), findsNothing);
    await _finish(t);
  });

  _case('a forged hidden destination callback cannot invoke a module builder', (
    t,
  ) async {
    final routes = <DashboardRoute>[];
    final h = _admin(role: '3');
    await _show(
      t,
      h,
      builder: (context, route) {
        routes.add(route);
        return null;
      },
    );
    await _tap(t, 'dashboard_nav_management');
    routes.clear();
    final layout = t.widget<NativeManagementPortalLayout>(
      find.byType(NativeManagementPortalLayout),
    );
    layout.onDestination(ManagementDestination.humanResources);
    layout.onDestination(ManagementDestination.analytics);
    await t.pumpAndSettle();
    expect(routes, isEmpty);
    expect(find.byKey(const Key('management_unavailable')), findsNothing);
    await _finish(t);
  });

  _case(
    'portal child return refreshes permissions and report parameters retain exact R_TYPE',
    (t) async {
      final routes = <DashboardRoute>[];
      final h = _admin();
      h.loginResponse['p_center_api'] = 'https://centre.example/cstar/';
      Widget? builder(BuildContext context, DashboardRoute route) {
        routes.add(route);
        if (route.module != DashboardModule.humanResources &&
            route.module != DashboardModule.reportParameters) {
          return null;
        }
        return Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('child_back'),
              onPressed: () => Navigator.pop(context),
              child: const Text('Return'),
            ),
          ),
        );
      }

      await _show(t, h, builder: builder);
      await _tap(t, 'dashboard_nav_management');
      await _tap(t, 'management_humanResources');
      h.adminData['hr_dashboard'] = '0';
      await _tap(t, 'child_back');
      expect(find.byKey(const Key('management_humanResources')), findsNothing);
      await _tap(t, 'management_reports');
      expect(find.text('Payment Receive Register Report'), findsOneWidget);
      await _tap(t, 'report_manager_select_5');
      expect(routes.last.module, DashboardModule.reportParameters);
      expect(routes.last.extras, {'R_TYPE': '5'});
      await _tap(t, 'child_back');
      expect(find.byType(NativeReportManagerLayout), findsOneWidget);
      await _finish(t);
    },
  );

  _case('duplicate Reports taps cannot stack duplicate child routes', (
    t,
  ) async {
    final h = _admin();
    await _show(t, h);
    await _tap(t, 'dashboard_nav_management');
    await t.tap(find.byKey(const Key('management_reports')));
    await t.tap(
      find.byKey(const Key('management_reports')),
      warnIfMissed: false,
    );
    await t.pumpAndSettle();
    expect(find.byType(NativeReportManagerLayout), findsOneWidget);
    await _tap(t, 'report_manager_back');
    expect(find.byType(NativeManagementPortalLayout), findsOneWidget);
    await _finish(t);
  });

  _case('deferred destination availability dialog closes cleanly', (t) async {
    final h = _admin();
    await _show(t, h);
    await _tap(t, 'dashboard_nav_management');
    await _tap(t, 'management_accounts');
    expect(find.byKey(const Key('management_unavailable')), findsOneWidget);
    await t.tap(find.text('Close'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('management_accounts')), findsOneWidget);
    await _tap(t, 'management_reports');
    await _tap(t, 'report_manager_select_1');
    expect(find.byKey(const Key('management_unavailable')), findsOneWidget);
    await _finish(t);
  });

  for (final failure in ['forced', 'access', 'expired']) {
    _case(
      '$failure account access closes portal and nested Reports on resume',
      (t) async {
        final h = _admin();
        await _show(t, h);
        await _tap(t, 'dashboard_nav_management');
        await _tap(t, 'management_reports');
        _pause(t);
        if (failure == 'forced') {
          h.adminData['usr_mob_forced_log_out_flag'] = '1';
        }
        if (failure == 'access') h.adminData['usr_mob_app_access'] = '0';
        if (failure == 'expired') h.adminData['exp_date'] = '01-OCT-26';
        _resume(t);
        await t.pumpAndSettle();
        expect(
          find.text(
            failure == 'forced'
                ? 'Forced Log Out!'
                : failure == 'access'
                ? 'Access Denied!'
                : 'Access Expired!',
          ),
          findsOneWidget,
        );
        expect(find.byType(NativeReportManagerLayout), findsNothing);
        expect(find.byType(NativeManagementPortalLayout), findsNothing);
        await _finish(t);
      },
    );
  }

  _case(
    'profile failure is noncancelable Retry/Exit and never grants cached portal access',
    (t) async {
      final h = _admin();
      await _show(t, h);
      final posts = h.posts.length;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getAdminData')) {
          throw const AppFailure('Menu profile could not load');
        }
        return h.defaultGet(uri);
      };
      await _tap(t, 'dashboard_nav_management');
      expect(find.byKey(const Key('management_error')), findsOneWidget);
      expect(find.byKey(const Key('management_accounts')), findsNothing);
      await t.tapAt(const Offset(2, 2));
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byKey(const Key('management_error')), findsOneWidget);
      h.transport.onGet = h.defaultGet;
      await _tap(t, 'management_error_retry');
      expect(find.byKey(const Key('management_accounts')), findsOneWidget);
      expect(h.posts.length, posts);
      await _finish(t);
    },
  );

  _case('Exit from a load failure returns to Dashboard', (t) async {
    final h = _admin();
    await _show(t, h);
    h.transport.onGet = (uri) async {
      if (uri.path.endsWith('getAdminData')) throw const AppFailure('Offline');
      return h.defaultGet(uri);
    };
    await _tap(t, 'dashboard_nav_management');
    h.transport.onGet = h.defaultGet;
    await _tap(t, 'management_error_exit');
    expect(find.byType(NativeDashboardLayout), findsOneWidget);
    expect(find.byType(NativeManagementPortalLayout), findsNothing);
    await _finish(t);
  });

  _case('a late profile response cannot reopen a portal after logout', (
    t,
  ) async {
    final h = _admin();
    await _show(t, h);
    final pending = Completer<JsonMap>();
    h.transport.onGet =
        (uri) =>
            uri.path.endsWith('getAdminData')
                ? pending.future
                : h.defaultGet(uri);
    await t.tap(find.byKey(const Key('dashboard_nav_management')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('management_loading')), findsOneWidget);
    await h.auth.logout();
    await t.pumpAndSettle();
    pending.complete({
      'count': 1,
      'items': [h.adminData],
    });
    await t.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byKey(const Key('management_accounts')), findsNothing);
    await _finish(t);
  });

  _case(
    'a different account response is retryable and never renders its flags',
    (t) async {
      final h = _admin();
      await _show(t, h);
      h.transport.onGet =
          (uri) async =>
              uri.path.endsWith('getAdminData')
                  ? {
                    'count': 1,
                    'items': [
                      <String, Object?>{...h.adminData, 'usr_id': '71'},
                    ],
                  }
                  : h.defaultGet(uri);
      await _tap(t, 'dashboard_nav_management');
      expect(find.byKey(const Key('management_error')), findsOneWidget);
      expect(find.textContaining('different account'), findsOneWidget);
      expect(find.byKey(const Key('management_accounts')), findsNothing);
      await _finish(t);
    },
  );

  _case(
    'doctor manager opens Reports and revocation blocks a retained report callback',
    (t) async {
      final h = Harness();
      h.doctorData['doc_manager_flag'] = '1';
      final routes = <DashboardRoute>[];
      await _show(
        t,
        h,
        builder: (context, route) {
          routes.add(route);
          return null;
        },
      );
      await _tap(t, 'dashboard_reports');
      final old = t.widget<NativeReportManagerLayout>(
        find.byType(NativeReportManagerLayout),
      );
      routes.clear();
      _pause(t);
      h.doctorData['doc_manager_flag'] = '0';
      _resume(t);
      await t.pumpAndSettle();
      expect(
        find.text('Access is not available for this account.'),
        findsOneWidget,
      );
      old.onReport(ReportManagerItem.paymentReceive);
      await t.pumpAndSettle();
      expect(routes, isEmpty);
      expect(h.auth.stage, AuthStage.authenticated);
      await _finish(t);
    },
  );

  _case('logout closes a nested report dialog and every owned menu route', (
    t,
  ) async {
    final h = _admin();
    await _show(t, h);
    await _tap(t, 'dashboard_nav_management');
    await _tap(t, 'management_reports');
    await _tap(t, 'report_manager_select_1');
    expect(find.byKey(const Key('management_unavailable')), findsOneWidget);
    await h.auth.logout();
    await t.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(NativeReportManagerLayout), findsNothing);
    expect(find.byKey(const Key('management_unavailable')), findsNothing);
    await _finish(t);
  });

  _case(
    'an unsigned direct menu entry exposes no report or management actions',
    (t) async {
      final h = Harness();
      addTearDown(h.auth.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: ManagementMenuScreen(
            auth: h.auth,
            entry: ManagementEntry.reports,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.text('Access is not available for this account.'),
        findsOneWidget,
      );
      expect(find.byType(NativeReportManagerLayout), findsNothing);
      expect(find.byKey(const Key('management_accounts')), findsNothing);
      expect(h.transport.requests, isEmpty);
      await _finish(t);
    },
  );

  _case(
    'role layouts use original grid rows and large text remains scrollable',
    (t) async {
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      for (final role in ['1', '2', '3']) {
        final h = _admin(role: role);
        h.auth.dispose();
        final access = ManagementAccess(
          AccountProfile(AccountRole.admin, h.adminData),
        );
        t.view.physicalSize = const Size(393, 852);
        t.view.devicePixelRatio = 1;
        await t.pumpWidget(
          RepaintBoundary(
            key: const Key('management_capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: docDiaryTheme(),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(393, 852),
                  padding: EdgeInsets.only(top: 59, bottom: 34),
                ),
                child: NativeManagementPortalLayout(
                  title: access.title,
                  destinations: access.destinations,
                  onBack: () {},
                  onDestination: (_) {},
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await _capture(t, 'management_role_$role');
      }
      for (final size in [const Size(280, 568), const Size(852, 393)]) {
        final access = ManagementAccess(
          AccountProfile(AccountRole.admin, {
            'all_access_flag': '1',
            'hr_acc_active_flag': '1',
            'hr_dashboard': '1',
            'acc_dashboard': '1',
            'usr_mob_app_analytic_access': '1',
          }),
        );
        final tapped = <ManagementDestination>[];
        t.view.physicalSize = size;
        await t.pumpWidget(
          MaterialApp(
            theme: docDiaryTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(2.5),
              ),
              child: NativeManagementPortalLayout(
                title: access.title,
                destinations: access.destinations,
                onBack: () {},
                onDestination: tapped.add,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await _tap(t, 'management_reports');
        expect(tapped, [ManagementDestination.reports]);
        expect(t.takeException(), isNull);
      }
      await _finish(t);
    },
  );
}

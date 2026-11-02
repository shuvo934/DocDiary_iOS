import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/payments/native_payment_controls.dart';
import 'package:docdiary_ios/features/payments/payment_add_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'payment_test_support.dart';
import 'payment_update_test_support.dart';
import 'package:docdiary_ios/features/payments/payment_update_models.dart';

Future<void> _tap(WidgetTester t, String key, {bool settle = true}) async {
  final finder = find.byKey(Key(key));
  if (finder.hitTestable().evaluate().isEmpty) {
    await t.ensureVisible(finder);
    await t.pump();
  }
  await t.tap(finder);
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }
  expect(t.takeException(), isNull);
}

void _pause(WidgetTester t) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    t.binding.handleAppLifecycleStateChanged(state);
  }
}

void _resume(WidgetTester t) {
  if (t.binding.lifecycleState == AppLifecycleState.paused) {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

Future<void> _host(
  WidgetTester t,
  PaymentHarness h, {
  Size size = const Size(393, 852),
  double textScale = 1,
  bool app = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.view.padding = FakeViewPadding(
    top: size.height < size.width ? 24 : 59,
    bottom: size.height < size.width ? 20 : 34,
  );
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPadding);
  addTearDown(t.view.resetViewInsets);
  if (!app) addTearDown(h.auth.dispose);
  _resume(t);
  await h.signIn();
  h.transport.requests.clear();
  await t.pumpWidget(
    RepaintBoundary(
      key: const Key('payment_capture'),
      child:
          app
              ? DocDiaryApp(
                auth: h.auth,
                initializeOnStart: false,
                dashboard: DashboardRepository(h.transport, now: () => h.now),
              )
              : MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: docDiaryTheme(),
                builder:
                    (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(textScale)),
                      child: child!,
                    ),
                home: Builder(
                  builder:
                      (context) => Scaffold(
                        body: TextButton(
                          key: const Key('open_payment'),
                          onPressed:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => PaymentAddScreen(
                                        auth: h.auth,
                                        repository: h.paymentRepository,
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
  await _tap(t, app ? 'dashboard_nav_payment' : 'open_payment');
}

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> _capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_PAYMENT_UPDATE_CAPTURE_DIR'];
  if (dir == null) return;
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('payment_capture')),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('$dir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _select(WidgetTester t, String key, int index) async {
  await _tap(t, key);
  await _tap(t, 'doctor_history_choice_unit_$index');
}

Finder _input(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));
String _text(WidgetTester t, String key) =>
    t.widget<Text>(find.byKey(Key(key))).data!;
void _case(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (t) async {
    final original = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await body(t);
    } finally {
      debugDisableShadows = original;
    }
  });
}

Future<void> _update(
  WidgetTester t,
  PaymentUpdateHarness h, {
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  await _host(t, h, size: size, textScale: textScale);
  await _tap(t, 'payment_tab_update');
}

Future<void> _payment(WidgetTester t, {int index = 0}) async {
  await _tap(t, 'payment_update_code');
  await _tap(t, 'payment_code_option_$index');
}

Future<void> _edit(WidgetTester t, {String qty = '2', int index = 0}) async {
  await _tap(t, 'payment_update_service_row_$index');
  await t.enterText(_input('payment_service_quantity'), qty);
  await t.pumpAndSettle();
  await _tap(t, 'payment_service_commit');
  await _tap(t, 'payment_yes');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final toasts = <String>[];
  setUpAll(() async {
    for (final entry
        in <String, List<String>>{
          'Poppins': ['Poppins-Regular.ttf', 'Poppins-Bold.ttf'],
          'Archivo': ['Archivo[wdth,wght].ttf'],
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
          'PatuaOne': ['PatuaOne-Regular.ttf'],
          'RussoOne': ['RussoOne-Regular.ttf'],
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
  setUp(() {
    toasts.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('PonnamKarthik/fluttertoast'),
          (call) async {
            if (call.method == 'showToast') {
              toasts.add((call.arguments as Map)['msg'] as String);
            }
            return true;
          },
        );
  });

  _case(
    'UPDATE empty, latest payment picker, suffix search, CLEAR and original patient metadata',
    (t) async {
      final h = PaymentUpdateHarness();
      await _update(t, h);
      expect(find.byKey(const Key('payment_patient')), findsNothing);
      expect(find.byKey(const Key('payment_update_commit')), findsNothing);
      await _capture(t, '01_update_empty');
      await _tap(t, 'payment_update_code');
      await _capture(t, '02_update_latest_payments');
      expect(find.text('Latest 50 Payments'), findsOneWidget);
      expect(
        t
            .widget<Semantics>(find.byKey(const Key('payment_code_prefix')))
            .properties
            .enabled,
        false,
      );
      await t.enterText(
        find.byKey(const Key('payment_code_query')),
        'PR.26.000501',
      );
      await _tap(t, 'payment_code_search');
      expect(find.text("Code must not include 'PR'"), findsOneWidget);
      await t.enterText(
        find.byKey(const Key('payment_code_query')),
        '26.000501',
      );
      await _tap(t, 'payment_code_search');
      expect(h.paymentReads.last.uri.queryParameters, {
        'prm_code': '26.000501',
      });
      await _capture(t, '03_update_search');
      await _tap(t, 'payment_code_clear');
      expect(find.text('Latest 50 Payments'), findsOneWidget);
      await _tap(t, 'payment_code_option_0');
      expect(find.text('25-OCT-26'), findsOneWidget);
      expect(find.text('Available\nQty'), findsOneWidget);
      expect(find.byKey(const Key('payment_delete_service_0')), findsNothing);
      await _capture(t, '04_update_loaded');
      await t.ensureVisible(
        find.byKey(const Key('payment_update_add_service')),
      );
      await t.pumpAndSettle();
      await _capture(t, '04a_update_service_table');
      await _finish(t);
    },
  );
  _case(
    'available quantity dialog and native disabled service/editor summary',
    (t) async {
      final h = PaymentUpdateHarness();
      await _update(t, h);
      await _payment(t);
      await _tap(t, 'payment_update_available_0');
      expect(
        find.byKey(const Key('payment_update_quantities')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('payment_service_quantity')), findsNothing);
      await _capture(t, '05_available_quantity');
      await _tap(t, 'payment_update_quantity_close');
      await _tap(t, 'payment_update_service_row_0');
      expect(
        t
            .widget<NativeAdminAppointmentField>(
              find.byKey(const Key('payment_service_name')),
            )
            .enabled,
        false,
      );
      expect(
        t
            .widget<NativeAdminAppointmentField>(
              find.byKey(const Key('payment_service_unit')),
            )
            .enabled,
        true,
      );
      expect(find.text('Available Quantity:'), findsOneWidget);
      await t.enterText(_input('payment_service_quantity'), '2');
      await t.pumpAndSettle();
      await _capture(t, '06_update_service');
      await _tap(t, 'payment_service_commit');
      await _tap(t, 'payment_yes');
      expect(_text(t, 'payment_update_total'), '2000');
      expect(h.paymentPosts, isEmpty);
      await _finish(t);
    },
  );
  _case('used quantities lock Unit and enforce minimum after cancel/return', (
    t,
  ) async {
    final h = PaymentUpdateHarness();
    h.details[0].addAll({
      'prd_qty': '5',
      'amount': '5000',
      'available_qty': '2',
      'prd_cancel_mark': '1',
      'prd_return_mark': '2',
    });
    await _update(t, h);
    await _payment(t);
    await _tap(t, 'payment_update_service_row_0');
    expect(
      t
          .widget<NativeAdminAppointmentField>(
            find.byKey(const Key('payment_service_unit')),
          )
          .enabled,
      false,
    );
    await t.enterText(_input('payment_service_quantity'), '2');
    await _tap(t, 'payment_service_commit');
    expect(
      find.text('You can not provide quantity less than 3.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('payment_service_confirm')), findsNothing);
    await t.enterText(_input('payment_service_quantity'), '3');
    await t.pumpAndSettle();
    await _capture(t, '07_used_quantity_minimum');
    await _tap(t, 'payment_service_commit');
    await _tap(t, 'payment_yes');
    await _tap(t, 'payment_update_available_0');
    expect(
      find.textContaining('Available Quantity:', findRichText: true),
      findsOneWidget,
    );
    await _tap(t, 'payment_update_quantity_close');
    expect(h.paymentPosts, isEmpty);
    await _finish(t);
  });
  _case(
    'schedule on any service shows warning and disables entire payment update',
    (t) async {
      final h = PaymentUpdateHarness();
      h.details[0]['prd_sched_avail_mark'] = '1';
      await _update(t, h);
      await _payment(t);
      expect(find.text(paymentScheduleWarning), findsOneWidget);
      expect(find.byKey(const Key('payment_error_retry')), findsNothing);
      await _tap(t, 'payment_error_cancel');
      expect(
        t
            .widget<NativeAdminAppointmentButton>(
              find.byKey(const Key('payment_update_commit')),
            )
            .onPressed,
        isNull,
      );
      await _tap(t, 'payment_update_add_service');
      expect(find.text(paymentScheduleWarning), findsOneWidget);
      await _tap(t, 'payment_ok');
      await _capture(t, '08_schedule_blocked');
      await _tap(t, 'payment_update_available_0');
      await _tap(t, 'payment_update_quantity_close');
      expect(h.paymentPosts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'UPDATE confirmation keeps old paid 1030 and computes new total 2884 / need 1854',
    (t) async {
      final h = PaymentUpdateHarness();
      await _update(t, h);
      await _payment(t);
      await _edit(t);
      await _tap(t, 'payment_update_add_service');
      await _select(t, 'payment_service_name', 1);
      await _select(t, 'payment_service_unit', 1);
      // Synthetic category rate: 800 for this added service, total 2800.
      // Rechoose a different unit after providing the new transport rate.
      h.rateResponse = {'p_service_rate': '800', 'p_service_top_rate': '1000'};
      await _select(t, 'payment_service_unit', 0);
      await t.enterText(_input('payment_service_quantity'), '1');
      await _tap(t, 'payment_service_commit');
      await _tap(t, 'payment_yes');
      expect(_text(t, 'payment_update_total'), '2800');
      await _tap(t, 'payment_update_commit');
      expect(_text(t, 'payment_confirm_grand'), '2884.00');
      expect(_text(t, 'payment_confirm_paid'), '1030.00');
      expect(_text(t, 'payment_confirm_need'), '1854.00');
      await _capture(t, '09_confirmation_existing_paid');
      await _select(t, 'payment_confirm_method', 0);
      expect(_text(t, 'payment_confirm_need'), '0.00');
      await _tap(t, 'payment_confirm_commit');
      expect(toasts.last, 'Please add your payment method first.');
      await _tap(t, 'payment_confirm_add');
      await _capture(t, '10_confirmation_split');
      await _tap(t, 'payment_confirm_commit');
      await _tap(t, 'payment_no');
      expect(h.paymentPosts, isEmpty);
      // Rejecting the final Yes/No discards the modal copy, keeps existing saved payment.
      await _tap(t, 'payment_update_commit');
      expect(_text(t, 'payment_confirm_paid'), '1030.00');
      await _select(t, 'payment_confirm_method', 0);
      await _tap(t, 'payment_confirm_add');
      await _tap(t, 'payment_confirm_commit');
      await _tap(t, 'payment_yes');
      expect(
        find.text('Payment Updated Successfully.\nPayment Code: PR.26.000501'),
        findsOneWidget,
      );
      expect(h.paymentPosts.map((r) => r.uri.pathSegments.last), [
        'updatePaymentDetails',
        'insertPaymentDetails',
        'updatePaymentMode',
      ]);
      expect(h.paymentPosts.last.headers['P_AMOUNT'], '1854.00');
      await _tap(t, 'payment_ok');
      expect(find.text('Test home'), findsOneWidget);
      await _finish(t);
    },
  );
  _case(
    'removing saved method is local until confirmation; cancel restores it; method-only replacement',
    (t) async {
      final h = PaymentUpdateHarness();
      await _update(t, h);
      await _payment(t);
      await _tap(t, 'payment_update_commit');
      await _tap(t, 'payment_confirm_delete_0');
      expect(_text(t, 'payment_confirm_paid'), '0.00');
      await _tap(t, 'payment_confirm_cancel');
      await _tap(t, 'payment_update_commit');
      expect(_text(t, 'payment_confirm_paid'), '1030.00');
      expect(h.paymentPosts, isEmpty);
      await _tap(t, 'payment_confirm_delete_0');
      await _select(t, 'payment_confirm_method', 1);
      await _tap(t, 'payment_confirm_add');
      await _tap(t, 'payment_confirm_commit');
      await _tap(t, 'payment_yes');
      expect(h.paymentPosts.map((r) => r.headers['P_UPDATE_TYPE']), ['2', '1']);
      expect(h.paymentPosts.first.headers['D_PRMD_ID'], '701');
      await _tap(t, 'payment_ok');
      await _finish(t);
    },
  );
  _case('unchanged payment gives native no-changes toast without writing', (
    t,
  ) async {
    final h = PaymentUpdateHarness();
    await _update(t, h);
    await _payment(t);
    await _tap(t, 'payment_update_commit');
    await _tap(t, 'payment_confirm_commit');
    expect(toasts.last, 'No new changes happened to update');
    expect(h.paymentPosts, isEmpty);
    expect(find.byKey(const Key('payment_update_confirmation')), findsNothing);
    await _finish(t);
  });
  _case('mode-off update bypasses method modal, keeps original code and date', (
    t,
  ) async {
    final h = PaymentUpdateHarness(mode: false);
    await _update(t, h);
    await _payment(t);
    await _tap(t, 'payment_update_commit');
    expect(toasts.last, 'No Service Changed for Update.');
    await _edit(t);
    await _tap(t, 'payment_update_commit');
    expect(find.text('Update Payment!'), findsOneWidget);
    await _tap(t, 'payment_yes');
    expect(h.paymentPosts.single.uri.pathSegments.last, 'updatePaymentDetails');
    expect(
      h.paymentReads.where(
        (r) => r.uri.pathSegments.last == 'getPaymentModeSavedList',
      ),
      isEmpty,
    );
    await _tap(t, 'payment_ok');
    await _finish(t);
  });
  _case(
    'tab switch asks before clearing loaded services, No preserves and Yes resets',
    (t) async {
      final h = PaymentUpdateHarness();
      await _update(t, h);
      await _payment(t);
      await _tap(t, 'payment_tab_add');
      expect(find.byKey(const Key('payment_switch_tab')), findsOneWidget);
      await _tap(t, 'payment_no');
      expect(find.byKey(const Key('payment_update_commit')), findsOneWidget);
      await _tap(t, 'payment_tab_add');
      await _tap(t, 'payment_yes');
      expect(find.byKey(const Key('payment_patient')), findsOneWidget);
      await _tap(t, 'payment_tab_update');
      expect(find.byKey(const Key('payment_update_commit')), findsNothing);
      await _finish(t);
    },
  );
  _case(
    'search failure cannot leave selectable stale payment rows; CLEAR restores latest',
    (t) async {
      final h = PaymentUpdateHarness();
      await _update(t, h);
      await _tap(t, 'payment_update_code');
      h.onUpdateGet = (u) async {
        if (u.pathSegments.last == 'getPaymentCodeList') {
          throw const AppFailure('Synthetic search failure');
        }
        return null;
      };
      await t.enterText(
        find.byKey(const Key('payment_code_query')),
        '26.000501',
      );
      await _tap(t, 'payment_code_search');
      await _tap(t, 'payment_error_cancel');
      expect(find.byKey(const Key('payment_code_option_0')), findsNothing);
      await _tap(t, 'payment_code_clear');
      expect(find.byKey(const Key('payment_code_option_0')), findsOneWidget);
      await _tap(t, 'payment_code_cancel');
      await _finish(t);
    },
  );
  _case('schedule arriving after selection is checked again before saving', (
    t,
  ) async {
    final h = PaymentUpdateHarness(mode: false);
    await _update(t, h);
    await _payment(t);
    await _edit(t);
    h.details[0]['prd_sched_avail_mark'] = '1';
    await _tap(t, 'payment_update_commit');
    await _tap(t, 'payment_yes');
    expect(find.text(paymentScheduleWarning), findsOneWidget);
    expect(h.paymentPosts, isEmpty);
    await _tap(t, 'payment_error_cancel');
    expect(
      t
          .widget<NativeAdminAppointmentButton>(
            find.byKey(const Key('payment_update_commit')),
          )
          .onPressed,
      isNull,
    );
    await _finish(t);
  });
  _case('concurrent edit invalidates selection and requires reselect', (
    t,
  ) async {
    final h = PaymentUpdateHarness(mode: false);
    await _update(t, h);
    await _payment(t);
    await _edit(t);
    h.details[0]['available_qty'] = '0';
    await _tap(t, 'payment_update_commit');
    await _tap(t, 'payment_yes');
    expect(
      find.text(
        'Payment details changed. Please reselect the payment and try again.',
      ),
      findsOneWidget,
    );
    await _tap(t, 'payment_error_cancel');
    expect(find.byKey(const Key('payment_update_commit')), findsNothing);
    expect(h.paymentPosts, isEmpty);
    await _finish(t);
  });
  _case('unknown write outcome locks continue and never replays on resume', (
    t,
  ) async {
    final h = PaymentUpdateHarness(mode: false);
    await _update(t, h);
    await _payment(t);
    await _edit(t);
    h.transport.onPost = (u, h) async => {};
    await _tap(t, 'payment_update_commit');
    await _tap(t, 'payment_yes');
    expect(
      find.textContaining('The payment result could not be confirmed.'),
      findsOneWidget,
    );
    await _tap(t, 'payment_error_cancel');
    expect(
      t
          .widget<NativeAdminAppointmentButton>(
            find.byKey(const Key('payment_update_commit')),
          )
          .onPressed,
      isNull,
    );
    _pause(t);
    _resume(t);
    await t.pumpAndSettle();
    await _tap(t, 'payment_error_cancel');
    expect(h.paymentPosts.length, 1);
    await _finish(t);
  });
  _case(
    'all-access update flag revoked on resume clears payment and closes feature',
    (t) async {
      final h = PaymentUpdateHarness();
      await _update(t, h);
      await _payment(t);
      h.adminData['all_access_flag'] = '0';
      _pause(t);
      _resume(t);
      await t.pumpAndSettle();
      expect(
        find.text('Payment update is not available for this account.'),
        findsOneWidget,
      );
      await _tap(t, 'payment_error_cancel');
      expect(find.text('Test home'), findsOneWidget);
      expect(h.paymentPosts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'partial explicit rejection keeps acknowledged service and continues only pending method',
    (t) async {
      final h = PaymentUpdateHarness();
      await _update(t, h);
      await _payment(t);
      await _edit(t);
      await _tap(t, 'payment_update_commit');
      await _select(t, 'payment_confirm_method', 0);
      await _tap(t, 'payment_confirm_add');
      await _tap(t, 'payment_confirm_commit');
      var fail = true;
      h.transport.onPost =
          (u, h) async => {
            'string_out':
                u.pathSegments.last == 'updatePaymentMode' && fail
                    ? 'Rejected'
                    : 'Successfully Created',
          };
      await _tap(t, 'payment_yes');
      await _tap(t, 'payment_error_cancel');
      expect(find.text('CONTINUE PAYMENT'), findsOneWidget);
      fail = false;
      await _tap(t, 'payment_update_commit');
      expect(
        find.textContaining('Payment Updated Successfully.'),
        findsOneWidget,
      );
      expect(h.paymentPosts.map((r) => r.uri.pathSegments.last), [
        'updatePaymentDetails',
        'updatePaymentMode',
        'updatePaymentMode',
      ]);
      await _tap(t, 'payment_ok');
      await _finish(t);
    },
  );
  _case(
    'service reduction shows negative Need To Pay and requires replacing excess saved money',
    (t) async {
      final h = PaymentUpdateHarness();
      await _update(t, h);
      await _payment(t);
      await _tap(t, 'payment_update_service_row_0');
      h.rateResponse = {'p_service_rate': '800', 'p_service_top_rate': '1000'};
      await _select(t, 'payment_service_unit', 1);
      await _tap(t, 'payment_service_commit');
      await _tap(t, 'payment_yes');
      await _tap(t, 'payment_update_commit');
      expect(_text(t, 'payment_confirm_need'), '-206.00');
      expect(_text(t, 'payment_confirm_paid'), '1030.00');
      await _capture(t, '10a_confirmation_overpaid');
      await _tap(t, 'payment_confirm_commit');
      expect(toasts.last, 'Please provide full payment information');
      expect(h.paymentPosts, isEmpty);
      await _tap(t, 'payment_confirm_delete_0');
      await _select(t, 'payment_confirm_method', 0);
      await _tap(t, 'payment_confirm_add');
      await _tap(t, 'payment_confirm_commit');
      await _tap(t, 'payment_yes');
      expect(h.paymentPosts.map((r) => r.uri.pathSegments.last), [
        'updatePaymentDetails',
        'updatePaymentMode',
        'updatePaymentMode',
      ]);
      expect(h.paymentPosts.map((r) => r.headers['P_AMOUNT']), [
        null,
        '1030.00',
        '824.00',
      ]);
      await _tap(t, 'payment_ok');
      await _finish(t);
    },
  );
  _case(
    'saved methods read must succeed before patient/service panel becomes actionable',
    (t) async {
      final h = PaymentUpdateHarness();
      var fail = true;
      h.onUpdateGet = (u) async {
        if (u.pathSegments.last == 'getPaymentModeSavedList' && fail) {
          throw const AppFailure('Synthetic method load failure');
        }
        return null;
      };
      await _update(t, h);
      await _payment(t);
      expect(find.byKey(const Key('payment_update_commit')), findsNothing);
      expect(h.paymentPosts, isEmpty);
      fail = false;
      await _tap(t, 'payment_error_retry');
      expect(find.byKey(const Key('payment_update_commit')), findsOneWidget);
      await _tap(t, 'payment_update_commit');
      expect(_text(t, 'payment_confirm_paid'), '1030.00');
      await _tap(t, 'payment_confirm_cancel');
      await _finish(t);
    },
  );
  _case(
    'backgrounded update acknowledgement is retained and resume never automatically posts',
    (t) async {
      final h = PaymentUpdateHarness();
      await _update(t, h);
      await _payment(t);
      await _edit(t);
      await _tap(t, 'payment_update_commit');
      await _select(t, 'payment_confirm_method', 0);
      await _tap(t, 'payment_confirm_add');
      await _tap(t, 'payment_confirm_commit');
      final pending = Completer<Map<String, Object?>>();
      h.transport.onPost = (u, h) => pending.future;
      await _tap(t, 'payment_yes', settle: false);
      expect(h.paymentPosts.length, 1);
      _pause(t);
      pending.complete({'string_out': 'Successfully Created'});
      await t.pumpAndSettle();
      _resume(t);
      await t.pumpAndSettle();
      expect(h.paymentPosts.length, 1);
      expect(find.text('CONTINUE PAYMENT'), findsOneWidget);
      h.transport.onPost =
          (u, h) async => {'string_out': 'Successfully Created'};
      await _tap(t, 'payment_update_commit');
      expect(h.paymentPosts.length, 2);
      expect(h.paymentPosts.last.uri.pathSegments.last, 'updatePaymentMode');
      await _tap(t, 'payment_ok');
      await _finish(t);
    },
  );
  _case(
    'mode changes before first update write reopen confirmation without losing edited services',
    (t) async {
      final h = PaymentUpdateHarness();
      await _update(t, h);
      await _payment(t);
      await _edit(t);
      await _tap(t, 'payment_update_commit');
      await _select(t, 'payment_confirm_method', 0);
      await _tap(t, 'payment_confirm_add');
      await _tap(t, 'payment_confirm_commit');
      h.adminData['is_pay_mode_active'] = '0';
      await _tap(t, 'payment_yes');
      expect(h.paymentPosts, isEmpty);
      await _tap(t, 'payment_error_cancel');
      expect(_text(t, 'payment_update_total'), '2000');
      await _tap(t, 'payment_update_commit');
      expect(find.text('Update Payment!'), findsOneWidget);
      await _tap(t, 'payment_yes');
      expect(
        h.paymentPosts.single.uri.pathSegments.last,
        'updatePaymentDetails',
      );
      await _tap(t, 'payment_ok');
      await _finish(t);
    },
  );
  _case(
    'logout dismisses payment picker and late reads cannot repopulate old patient',
    (t) async {
      final h = PaymentUpdateHarness();
      await _update(t, h);
      final pending = Completer<Map<String, Object?>>();
      h.onUpdateGet =
          (u) =>
              u.pathSegments.last == 'getFiftyPaymentList'
                  ? pending.future
                  : Future.value(null);
      await _tap(t, 'payment_update_code', settle: false);
      await h.auth.logout();
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      pending.complete({'pay_list': h.payments});
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('payment_code_picker')), findsNothing);
      expect(find.byKey(const Key('payment_update_commit')), findsNothing);
      expect(h.paymentPosts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'explicit first-row rejection followed by a concurrent edit allows payment reselect',
    (t) async {
      final h = PaymentUpdateHarness(mode: false);
      await _update(t, h);
      await _payment(t);
      await _edit(t);
      h.transport.onPost = (u, h) async => {'string_out': 'Rejected'};
      await _tap(t, 'payment_update_commit');
      await _tap(t, 'payment_yes');
      await _tap(t, 'payment_error_cancel');
      h.details[0]['available_qty'] = '0';
      await _tap(t, 'payment_update_commit');
      expect(
        find.text(
          'Payment details changed. Please reselect the payment and try again.',
        ),
        findsOneWidget,
      );
      await _tap(t, 'payment_error_cancel');
      expect(find.byKey(const Key('payment_update_commit')), findsNothing);
      await _tap(t, 'payment_update_code');
      expect(find.byKey(const Key('payment_code_picker')), findsOneWidget);
      await _tap(t, 'payment_code_cancel');
      expect(h.paymentPosts.length, 1);
      await _finish(t);
    },
  );
  for (final scenario in [
    ('small', const Size(320, 568), 1.0),
    ('landscape', const Size(852, 393), 1.0),
    ('large_text', const Size(393, 852), 1.8),
  ]) {
    _case(
      'UPDATE accessible scroll / editor / confirmation / keyboard on ${scenario.$1}',
      (t) async {
        final h = PaymentUpdateHarness();
        h.payments = List.generate(
          50,
          (i) => {
            ...h.payments.first,
            'prm_id': '${501 + i}',
            'prm_code': 'PR.26.${(501 + i).toString().padLeft(6, '0')}',
          },
        );
        await _update(t, h, size: scenario.$2, textScale: scenario.$3);
        await _tap(t, 'payment_update_code');
        t.view.viewInsets = FakeViewPadding(
          bottom: scenario.$2.height < 400 ? 150 : 210,
        );
        await t.pumpAndSettle();
        await _capture(t, '11_picker_keyboard_${scenario.$1}');
        expect(
          find.byKey(const Key('payment_code_cancel')).hitTestable(),
          findsOneWidget,
        );
        t.view.resetViewInsets();
        await t.pumpAndSettle();
        await _tap(t, 'payment_code_option_0');
        await _tap(t, 'payment_update_service_row_0');
        await _capture(t, '12_service_${scenario.$1}');
        await _tap(t, 'payment_back');
        await _tap(t, 'payment_update_commit');
        await _capture(t, '13_confirmation_${scenario.$1}');
        expect(
          find.byKey(const Key('payment_confirm_cancel')).hitTestable(),
          findsOneWidget,
        );
        await _tap(t, 'payment_confirm_cancel');
        await _finish(t);
      },
    );
  }
}

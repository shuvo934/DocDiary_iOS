import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/payments/native_payment_controls.dart';
import 'package:docdiary_ios/features/payments/payment_add_screen.dart';
import 'package:docdiary_ios/features/payments/payment_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'payment_test_support.dart';

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
  final dir = Platform.environment['DOC_PAYMENT_CAPTURE_DIR'];
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

Future<void> _patient(WidgetTester t, {int index = 0}) async {
  await _tap(t, 'payment_patient');
  await _tap(t, 'payment_patient_option_$index');
}

Future<void> _select(WidgetTester t, String key, int index) async {
  await _tap(t, key);
  await _tap(t, 'doctor_history_choice_unit_$index');
}

Finder _input(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));
Future<void> _addService(
  WidgetTester t, {
  int service = 0,
  int unit = 0,
  String qty = '4',
  String? capture,
}) async {
  await _tap(t, 'payment_add_service');
  await _select(t, 'payment_service_name', service);
  await _select(t, 'payment_service_unit', unit);
  await t.enterText(_input('payment_service_quantity'), qty);
  await t.pumpAndSettle();
  if (capture != null) await _capture(t, capture);
  await _tap(t, 'payment_service_commit');
  await _tap(t, 'payment_yes');
}

Future<void> _confirmation(WidgetTester t) async {
  await _tap(t, 'payment_commit');
  expect(find.byKey(const Key('payment_confirmation')), findsOneWidget);
}

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
    'initial ADD, patient search, CLEAR, second same-name patient and cancel preserve expected selection',
    (t) async {
      final h = PaymentHarness();
      await _host(t, h);
      expect(find.byKey(const Key('payment_commit')), findsNothing);
      expect(find.byKey(const Key('payment_tab_update')), findsOneWidget);
      await _capture(t, '01_payment_empty');
      await _tap(t, 'payment_patient');
      await _capture(t, '02_patient_latest');
      expect(find.text('Latest 50 Patients'), findsOneWidget);
      expect(find.text('017*****678'), findsOneWidget);
      await t.enterText(find.byKey(const Key('payment_patient_query')), 'a');
      await _tap(t, 'payment_patient_search');
      expect(
        find.text('Name or Code must be greater than 2 character'),
        findsOneWidget,
      );
      expect(h.paymentReads.length, 1);
      await t.enterText(
        find.byKey(const Key('payment_patient_query')),
        'Sample',
      );
      await _tap(t, 'payment_patient_search');
      expect(find.text('Latest 50 Patients'), findsNothing);
      await _capture(t, '03_patient_search');
      await _tap(t, 'payment_patient_clear');
      expect(find.text('Latest 50 Patients'), findsOneWidget);
      expect(h.paymentReads.length, 2);
      await _tap(t, 'payment_patient_option_1');
      expect(
        t
            .widget<NativeAdminAppointmentField>(
              find.byKey(const Key('payment_patient')),
            )
            .value,
        '26.01.000102.01',
      );
      await _tap(t, 'payment_patient');
      await _tap(t, 'payment_patient_cancel');
      expect(
        t
            .widget<NativeAdminAppointmentField>(
              find.byKey(const Key('payment_patient')),
            )
            .value,
        '26.01.000102.01',
      );
      expect(h.paymentPosts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'selected patient details, service empty state and native fixed bottom actions',
    (t) async {
      final h = PaymentHarness();
      await _host(t, h);
      await _patient(t);
      expect(find.text('Patient Category:'), findsOneWidget);
      expect(find.text('01-Nov-26'), findsOneWidget);
      expect(find.text('Total Amount'), findsNothing);
      await _capture(t, '04_payment_patient_selected');
      await _tap(t, 'payment_commit');
      expect(toasts, contains('Please Add Service.'));
      expect(h.paymentPosts, isEmpty);
      await _tap(t, 'payment_add_service');
      await _capture(t, '05_service_empty');
      expect(
        t
            .widget<NativeAdminAppointmentField>(
              find.byKey(const Key('payment_service_unit')),
            )
            .enabled,
        false,
      );
      expect(
        t
            .widget<NativeAdminAppointmentField>(
              find.byKey(const Key('payment_service_rate')),
            )
            .enabled,
        false,
      );
      final button = t.getRect(find.byKey(const Key('payment_service_commit')));
      expect(button.bottom, greaterThan(740));
      await _tap(t, 'payment_service_commit');
      expect(find.text('Please Select Service'), findsOneWidget);
      await _finish(t);
    },
  );
  _case(
    'service dependencies, API rate, quantity, aligned table and total update',
    (t) async {
      final h = PaymentHarness();
      await _host(t, h);
      await _patient(t);
      await _addService(t, capture: '06_service_filled');
      expect(_text(t, 'payment_total'), '2400');
      await _capture(t, '07a_payment_service_added_top');
      await t.ensureVisible(find.byKey(const Key('payment_add_service')));
      await t.pumpAndSettle();
      await _capture(t, '07_payment_service_added');
      expect(h.paymentPosts, isEmpty);
      final header = t.getRect(find.byType(NativePaymentGrid).first);
      final row = t.getRect(find.byType(NativePaymentGrid).last);
      expect(row.left, header.left);
      expect(row.width, header.width);
      await _tap(t, 'payment_service_row_0');
      expect(find.byType(PaymentServiceScreen), findsOneWidget);
      expect(find.text('Update Service'), findsOneWidget);
      await t.enterText(_input('payment_service_quantity'), '2');
      await _tap(t, 'payment_service_commit');
      await _tap(t, 'payment_yes');
      expect(_text(t, 'payment_total'), '1200');
      await _tap(t, 'payment_service_delete_0');
      await _tap(t, 'payment_no');
      expect(_text(t, 'payment_total'), '1200');
      await _tap(t, 'payment_service_delete_0');
      await _tap(t, 'payment_yes');
      expect(find.byKey(const Key('payment_total')), findsNothing);
      await _finish(t);
    },
  );
  _case('duplicate service-unit blocks add and leaves the original untouched', (
    t,
  ) async {
    final h = PaymentHarness();
    await _host(t, h);
    await _patient(t);
    await _addService(t);
    await _tap(t, 'payment_add_service');
    await _select(t, 'payment_service_name', 0);
    await _select(t, 'payment_service_unit', 0);
    await t.enterText(_input('payment_service_quantity'), '1');
    await _tap(t, 'payment_service_commit');
    expect(find.text('Duplicate Service Found!'), findsOneWidget);
    expect(h.paymentPosts, isEmpty);
    await _tap(t, 'payment_ok');
    await _tap(t, 'payment_back');
    expect(_text(t, 'payment_total'), '2400');
    await _finish(t);
  });
  _case(
    'quantity validation and service switch clear the old unit/rate/amount',
    (t) async {
      final h = PaymentHarness();
      await _host(t, h);
      await _patient(t);
      await _tap(t, 'payment_add_service');
      await _select(t, 'payment_service_name', 0);
      await _select(t, 'payment_service_unit', 0);
      await t.enterText(_input('payment_service_quantity'), '0');
      await t.pump();
      expect(find.text('Invalid Quantity'), findsOneWidget);
      await t.enterText(_input('payment_service_quantity'), '4');
      await t.pump();
      expect(
        t
            .widget<NativeAdminAppointmentField>(
              find.byKey(const Key('payment_service_amount')),
            )
            .value,
        '2400',
      );
      await _select(t, 'payment_service_name', 1);
      for (final key in ['unit', 'rate', 'amount']) {
        expect(
          t
              .widget<NativeAdminAppointmentField>(
                find.byKey(Key('payment_service_$key')),
              )
              .value,
          isEmpty,
        );
      }
      await _finish(t);
    },
  );
  _case(
    'cash pending preview requires ADD; final confirmation writes once and shows native success code',
    (t) async {
      final h = PaymentHarness();
      await _host(t, h);
      await _patient(t);
      await _addService(t);
      await _confirmation(t);
      await _capture(t, '08_confirmation_empty');
      expect(_text(t, 'payment_confirm_total'), '2400.00');
      expect(_text(t, 'payment_confirm_charge'), '72.00');
      expect(_text(t, 'payment_confirm_grand'), '2472.00');
      expect(_text(t, 'payment_confirm_need'), '2472.00');
      await _select(t, 'payment_confirm_method', 0);
      expect(_text(t, 'payment_confirm_paid'), '2472.00');
      await _capture(t, '09_confirmation_cash_pending');
      await _tap(t, 'payment_confirm_commit');
      expect(toasts, contains('Please add your payment method first.'));
      expect(h.paymentPosts, isEmpty);
      await _tap(t, 'payment_confirm_add');
      await _capture(t, '10_confirmation_cash_added');
      expect(
        t
            .widget<NativeAdminAppointmentField>(
              find.byKey(const Key('payment_confirm_method')),
            )
            .enabled,
        false,
      );
      await _tap(t, 'payment_confirm_commit');
      expect(
        find.byKey(const Key('payment_save_confirmation')),
        findsOneWidget,
      );
      await _tap(t, 'payment_yes');
      expect(find.text('Success!'), findsOneWidget);
      expect(find.textContaining('PR.26.000501'), findsOneWidget);
      expect(h.paymentPosts.length, 3);
      await _tap(t, 'payment_ok');
      expect(find.text('Test home'), findsOneWidget);
      await _finish(t);
    },
  );
  _case(
    'split bank/cash, overpayment, method filtering and delete recalculate exact amounts',
    (t) async {
      final h = PaymentHarness();
      await _host(t, h);
      await _patient(t);
      await _addService(t);
      await _confirmation(t);
      await _select(t, 'payment_confirm_method', 1);
      await t.enterText(_input('payment_confirm_amount'), '3000');
      await t.pump();
      expect(find.text('Amount is greater than need to pay'), findsOneWidget);
      expect(_text(t, 'payment_confirm_paid'), '0.00');
      await t.enterText(_input('payment_confirm_amount'), '2000');
      await t.pump();
      await _tap(t, 'payment_confirm_add');
      expect(_text(t, 'payment_confirm_need'), '472.00');
      await _capture(t, '11_confirmation_bank_partial');
      await _tap(t, 'payment_confirm_method');
      await _capture(t, '12_confirmation_method_menu');
      expect(
        find.descendant(
          of: find.byKey(const Key('doctor_history_choices')),
          matching: find.text('Bank Payment (1653)'),
        ),
        findsNothing,
      );
      await _tap(t, 'doctor_history_choice_unit_0');
      await _tap(t, 'payment_confirm_add');
      expect(_text(t, 'payment_confirm_paid'), '2472.00');
      expect(_text(t, 'payment_confirm_need'), '0.00');
      await _capture(t, '13_confirmation_split_complete');
      await _tap(t, 'payment_confirm_delete_0');
      expect(_text(t, 'payment_confirm_need'), '2000.00');
      expect(_text(t, 'payment_confirm_paid'), '472.00');
      await _tap(t, 'payment_confirm_cancel');
      expect(h.paymentPosts, isEmpty);
      expect(_text(t, 'payment_total'), '2400');
      await _finish(t);
    },
  );
  _case(
    'payment mode disabled uses standard native Yes/No and skips charge/method requests',
    (t) async {
      final h = PaymentHarness(mode: false);
      await _host(t, h);
      await _patient(t);
      await _addService(t);
      await _tap(t, 'payment_commit');
      expect(find.byKey(const Key('payment_confirmation')), findsNothing);
      expect(
        find.byKey(const Key('payment_save_confirmation')),
        findsOneWidget,
      );
      await _tap(t, 'payment_no');
      expect(h.paymentPosts, isEmpty);
      await _tap(t, 'payment_commit');
      await _tap(t, 'payment_yes');
      expect(h.paymentPosts.length, 2);
      expect(h.paymentPosts.first.headers['P_PAID_AMOUNT'], '2400.00');
      expect(
        h.paymentReads.where(
          (r) => [
            'getPaymentMode',
            'getServiceChargePFN',
          ].contains(r.uri.pathSegments.last),
        ),
        isEmpty,
      );
      await _tap(t, 'payment_ok');
      await _finish(t);
    },
  );
  _case(
    'patient change clears local services and restricted account hides UPDATE',
    (t) async {
      final h = PaymentHarness(fullAccess: false);
      h.adminData['all_access_flag'] = '2';
      await _host(t, h);
      expect(find.byKey(const Key('payment_tab_update')), findsNothing);
      await _patient(t);
      await _addService(t);
      await _patient(t, index: 1);
      expect(find.byKey(const Key('payment_total')), findsNothing);
      expect(find.byKey(const Key('payment_service_row_0')), findsNothing);
      await _finish(t);
    },
  );
  _case('dashboard Payment action opens the implemented ADD screen', (t) async {
    final h = PaymentHarness();
    await _host(t, h, app: true);
    expect(find.byType(PaymentAddScreen), findsOneWidget);
    expect(
      find.text('This screen is not available in this development build.'),
      findsNothing,
    );
    await _finish(t);
  });
  _case('revoked payment access closes the child and parent with one notice', (
    t,
  ) async {
    final h = PaymentHarness();
    h.adminData['all_access_flag'] = '2';
    await _host(t, h);
    await _patient(t);
    h.adminData['hr_payment_active'] = '0';
    await _tap(t, 'payment_add_service');
    expect(
      find.text('Payment is not available for this account.'),
      findsOneWidget,
    );
    await _tap(t, 'payment_error_cancel');
    expect(find.text('Test home'), findsOneWidget);
    expect(
      h.paymentReads.where((r) => r.uri.pathSegments.last == 'getServices'),
      isEmpty,
    );
    await _finish(t);
  });
  _case(
    'background dismisses confirmation without posting and refresh does not record LoginLog',
    (t) async {
      final h = PaymentHarness();
      await _host(t, h);
      await _patient(t);
      await _addService(t);
      await _confirmation(t);
      _pause(t);
      await t.pumpAndSettle();
      _resume(t);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('payment_confirmation')), findsNothing);
      expect(h.paymentPosts, isEmpty);
      expect(
        h.transport.requests.where((r) => r.uri.path.contains('LoginLog')),
        isEmpty,
      );
      expect(_text(t, 'payment_total'), '2400');
      await _finish(t);
    },
  );
  _case(
    'acknowledged backgrounded master continues without creating another payment',
    (t) async {
      final h = PaymentHarness(mode: false);
      await _host(t, h);
      await _patient(t);
      await _addService(t);
      final pending = Completer<JsonMap>();
      h.transport.onPost = (uri, headers) async => pending.future;
      await _tap(t, 'payment_commit');
      await _tap(t, 'payment_yes', settle: false);
      expect(h.paymentPosts.length, 1);
      _pause(t);
      await t.pump();
      pending.complete({
        'string_out': 'Successfully Created',
        'out_prm_id': '501',
        'out_prm_code': 'PR-501',
      });
      await t.pump();
      _resume(t);
      await t.pumpAndSettle();
      expect(find.text('CONTINUE PAYMENT'), findsOneWidget);
      expect(h.paymentPosts.length, 1);
      h.transport.onPost =
          (uri, headers) async => {'string_out': 'Successfully Created'};
      await _tap(t, 'payment_commit');
      expect(h.paymentPosts.length, 2);
      expect(find.text('Success!'), findsOneWidget);
      await _tap(t, 'payment_ok');
      await _finish(t);
    },
  );
  _case(
    'logout removes patient dialog and a late result cannot return a patient',
    (t) async {
      final h = PaymentHarness();
      await _host(t, h);
      final pending = Completer<JsonMap>();
      h.onPaymentGet =
          (uri) async =>
              uri.pathSegments.last == 'getFiftyPrescriptionList'
                  ? pending.future
                  : null;
      await _tap(t, 'payment_patient', settle: false);
      await h.auth.logout();
      pending.complete({'pat_pres_list': h.patients});
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('payment_patient_picker')), findsNothing);
      expect(h.paymentPosts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'failed search clears stale choices and CLEAR restores the latest patients',
    (t) async {
      final h = PaymentHarness();
      await _host(t, h);
      await _tap(t, 'payment_patient');
      h.onPaymentGet = (uri) async {
        if (uri.pathSegments.last == 'getPrescriptionCodeList') {
          throw const AppFailure('Search unavailable');
        }
        return null;
      };
      await t.enterText(
        find.byKey(const Key('payment_patient_query')),
        'Sample',
      );
      await _tap(t, 'payment_patient_search');
      await _tap(t, 'payment_error_cancel');
      expect(find.byKey(const Key('payment_patient_option_0')), findsNothing);
      await _tap(t, 'payment_patient_clear');
      expect(find.byKey(const Key('payment_patient_option_0')), findsOneWidget);
      await _tap(t, 'payment_patient_option_0');
      expect(h.paymentPosts, isEmpty);
      await _finish(t);
    },
  );
  _case(
    'unit GET interrupted by background can recover with the selected service and quantity',
    (t) async {
      final h = PaymentHarness();
      await _host(t, h);
      await _patient(t);
      await _tap(t, 'payment_add_service');
      final pending = Completer<JsonMap>();
      h.onPaymentGet =
          (uri) async =>
              uri.pathSegments.last == 'getServiceUnit' ? pending.future : null;
      await _tap(t, 'payment_service_name');
      await _tap(t, 'doctor_history_choice_unit_0', settle: false);
      _pause(t);
      await t.pump();
      h.onPaymentGet = null;
      pending.complete({'count': 2, 'items': h.units});
      await t.pump();
      _resume(t);
      await t.pumpAndSettle();
      expect(
        t
            .widget<NativeAdminAppointmentField>(
              find.byKey(const Key('payment_service_unit')),
            )
            .enabled,
        true,
      );
      await _select(t, 'payment_service_unit', 0);
      expect(h.paymentPosts, isEmpty);
      await _finish(t);
    },
  );
  _case('explicitly rejected detail Retry preserves the saved master receipt', (
    t,
  ) async {
    final h = PaymentHarness(mode: false);
    await _host(t, h);
    await _patient(t);
    await _addService(t);
    var rejected = false;
    h.transport.onPost = (uri, headers) async {
      if (uri.pathSegments.last == 'insertPaymentMaster') {
        return {
          'string_out': 'Successfully Created',
          'out_prm_id': '501',
          'out_prm_code': 'PR-501',
        };
      }
      if (!rejected) {
        rejected = true;
        return {'string_out': 'Rejected'};
      }
      return {'string_out': 'Successfully Created'};
    };
    await _tap(t, 'payment_commit');
    await _tap(t, 'payment_yes');
    expect(find.byKey(const Key('payment_error_retry')), findsOneWidget);
    await _tap(t, 'payment_error_retry');
    expect(find.text('Success!'), findsOneWidget);
    expect(
      h.paymentPosts
          .where((r) => r.uri.pathSegments.last == 'insertPaymentMaster')
          .length,
      1,
    );
    expect(h.paymentPosts.length, 3);
    await _tap(t, 'payment_ok');
    await _finish(t);
  });
  _case(
    'unknown POST outcome offers no unsafe retry and disables resubmission',
    (t) async {
      final h = PaymentHarness(mode: false);
      await _host(t, h);
      await _patient(t);
      await _addService(t);
      h.transport.onPost =
          (uri, headers) async =>
              throw const AppFailure('Connection interrupted');
      await _tap(t, 'payment_commit');
      await _tap(t, 'payment_yes');
      expect(find.byKey(const Key('payment_error_retry')), findsNothing);
      expect(find.textContaining('could not be confirmed'), findsOneWidget);
      await _tap(t, 'payment_error_cancel');
      expect(
        t
            .widget<NativeAdminAppointmentButton>(
              find.byKey(const Key('payment_commit')),
            )
            .onPressed,
        isNull,
      );
      expect(h.paymentPosts.length, 1);
      await _finish(t);
    },
  );
  _case('rapid repeated commit taps issue only one master write', (t) async {
    final h = PaymentHarness(mode: false);
    await _host(t, h);
    await _patient(t);
    await _addService(t);
    final pending = Completer<JsonMap>();
    h.transport.onPost =
        (uri, headers) async =>
            uri.pathSegments.last == 'insertPaymentMaster'
                ? pending.future
                : {'string_out': 'Successfully Created'};
    await _tap(t, 'payment_commit');
    await _tap(t, 'payment_yes', settle: false);
    await t.tap(find.byKey(const Key('payment_commit')));
    await t.tap(find.byKey(const Key('payment_commit')));
    await t.pump();
    expect(h.paymentPosts.length, 1);
    pending.complete({
      'string_out': 'Successfully Created',
      'out_prm_id': '501',
      'out_prm_code': 'PR-501',
    });
    await t.pumpAndSettle();
    expect(h.paymentPosts.length, 2);
    await _tap(t, 'payment_ok');
    await _finish(t);
  });
  _case(
    'mode change before save blocks stale confirmation and reopens the current native flow',
    (t) async {
      final h = PaymentHarness();
      await _host(t, h);
      await _patient(t);
      await _addService(t);
      await _confirmation(t);
      await _select(t, 'payment_confirm_method', 0);
      await _tap(t, 'payment_confirm_add');
      await _tap(t, 'payment_confirm_commit');
      h.adminData['is_pay_mode_active'] = '0';
      await _tap(t, 'payment_yes');
      expect(h.paymentPosts, isEmpty);
      expect(find.textContaining('Payment settings changed'), findsOneWidget);
      await _tap(t, 'payment_error_cancel');
      await _tap(t, 'payment_commit');
      expect(find.byKey(const Key('payment_confirmation')), findsNothing);
      await _tap(t, 'payment_yes');
      expect(h.paymentPosts.length, 2);
      await _tap(t, 'payment_ok');
      await _finish(t);
    },
  );
  for (final item in <(String, Size, double)>[
    ('small_phone', Size(320, 568), 1),
    ('large_text', Size(393, 852), 1.8),
    ('landscape', Size(852, 393), 1),
  ]) {
    _case(
      'responsive ${item.$1} keeps service and confirmation fields/actions reachable',
      (t) async {
        final h = PaymentHarness();
        await _host(t, h, size: item.$2, textScale: item.$3);
        await _patient(t);
        await _addService(t);
        await _confirmation(t);
        await _select(t, 'payment_confirm_method', 0);
        await _tap(t, 'payment_confirm_add');
        await _capture(t, '14_${item.$1}');
        expect(t.takeException(), isNull);
        await _tap(t, 'payment_confirm_cancel');
        await _finish(t);
      },
    );
  }
  _case('patient keyboard and 50-row list scroll within the native dialog', (
    t,
  ) async {
    final h = PaymentHarness();
    final original = Map<String, Object?>.of(h.patients.first);
    h.patients.clear();
    h.patients.addAll([
      for (var i = 0; i < 50; i++)
        {...original, 'ph_id': '${1000 + i}', 'ph_sub_code': 'RX-${1000 + i}'},
    ]);
    await _host(t, h);
    await _tap(t, 'payment_patient');
    await _capture(t, '15_patient_fifty_rows');
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('payment_patient_query')), 'Sample');
    await _tap(t, 'payment_patient_search');
    expect(t.takeException(), isNull);
    t.view.viewInsets = const FakeViewPadding();
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.byKey(const Key('payment_patient_option_49')),
      250,
      scrollable: find.descendant(
        of: find.byKey(const Key('payment_patient_list')),
        matching: find.byType(Scrollable),
      ),
    );
    await _tap(t, 'payment_patient_option_49');
    expect(
      t
          .widget<NativeAdminAppointmentField>(
            find.byKey(const Key('payment_patient')),
          )
          .value,
      'RX-1049',
    );
    await _finish(t);
  });
}

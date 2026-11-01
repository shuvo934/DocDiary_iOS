import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_controller.dart';
import 'package:docdiary_ios/features/management/management_menu_screen.dart';
import 'package:docdiary_ios/features/reports/native_report_controls.dart';
import 'package:docdiary_ios/features/reports/native_report_table.dart';
import 'package:docdiary_ios/features/reports/report_manager_menu.dart';
import 'package:docdiary_ios/features/reports/report_manager_models.dart';
import 'package:docdiary_ios/features/reports/report_parameters_screen.dart';
import 'package:docdiary_ios/features/reports/report_pdf_screen.dart';
import 'package:docdiary_ios/features/reports/report_results_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'report_manager_test_support.dart';

Future<void> _tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  if (f.hitTestable().evaluate().isEmpty) await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Future<void> _show(
  WidgetTester t,
  ReportHarness h, {
  ReportManagerItem item = ReportManagerItem.paymentReceive,
  Widget Function()? page,
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(h.auth.dispose);
  _resume(t);
  await h.signIn();
  await t.pumpWidget(
    RepaintBoundary(
      key: const Key('report_capture'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: docDiaryTheme(),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                padding: const EdgeInsets.only(top: 59, bottom: 34),
              ),
              child: child!,
            ),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    key: const Key('report_test_open'),
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder:
                                (_) =>
                                    page?.call() ??
                                    ReportParametersScreen(
                                      auth: h.auth,
                                      repository: h.reports,
                                      item: item,
                                    ),
                          ),
                        ),
                    child: const Text('Report test home'),
                  ),
                ),
              ),
        ),
      ),
    ),
  );
  await _tap(t, 'report_test_open');
}

Future<void> _select(WidgetTester t, String parameter, int index) async {
  await _tap(t, 'report_filter_$parameter');
  await _tap(t, 'report_parameter_option_$index');
}

Future<void> _capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_REPORT_MANAGER_CAPTURE_DIR'];
  if (dir == null) return;
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('report_capture')),
  );
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final f = File('$dir/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(data!.buffer.asUint8List());
  });
}

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
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

void _case(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (t) async {
    final shadows = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await body(t);
    } finally {
      debugDisableShadows = shadows;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final toastMessages = <String>[];
  setUpAll(() async {
    for (final family
        in <String, List<String>>{
          'Poppins': [
            'Poppins-Regular.ttf',
            'Poppins-Medium.ttf',
            'Poppins-Bold.ttf',
          ],
          'RussoOne': ['RussoOne-Regular.ttf'],
          'PatuaOne': ['PatuaOne-Regular.ttf'],
          'OpenSans': ['OpenSans[wdth,wght].ttf'],
          'Baloo': ['Baloo-Regular.ttf'],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
          'DocDiaryBengali': ['NotoSansBengali.ttf'],
        }.entries) {
      final loader = FontLoader(family.key);
      for (final font in family.value) {
        loader.addFont(rootBundle.load('assets/fonts/$font'));
      }
      await loader.load();
    }
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() {
    toastMessages.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('PonnamKarthik/fluttertoast'),
          (call) async {
            if (call.method == 'showToast') {
              toastMessages.add((call.arguments as Map)['msg'] as String);
            }
            return true;
          },
        );
  });
  for (final item in ReportManagerItem.values) {
    _case('${item.nativeType}: native form and initial enable state', (
      t,
    ) async {
      final h = ReportHarness();
      await _show(t, h, item: item);
      expect(find.text(item.title), findsOneWidget);
      expect(find.text('01-Oct-26'), findsOneWidget);
      expect(find.text('31-Oct-26'), findsOneWidget);
      expect(
        find.byKey(const Key('report_filter_doctor')),
        item.showsDoctor ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const Key('report_filter_service')),
        item.showsService ? findsOneWidget : findsNothing,
      );
      expect(
        t
            .widget<NativeReportFilterField>(
              find.byKey(const Key('report_filter_unit')),
            )
            .enabled,
        !item.showsDoctor,
      );
      await _capture(t, 'parameters_${item.nativeType}');
      await _finish(t);
    });
  }
  _case(
    'Doctor Payment selects duplicate doctor by ID and shows native table',
    (t) async {
      final h = ReportHarness();
      await _show(t, h, item: ReportManagerItem.doctorPayment);
      await _select(t, 'department', 1);
      await _select(t, 'unit', 0);
      await _select(t, 'doctor', 1);
      await _select(t, 'service', 0);
      await _tap(t, 'report_show');
      final uri = h.reportReads.last.uri;
      expect(uri.pathSegments.last, 'getDocWisePayData');
      expect(uri.queryParameters['p_doc_id'], '11');
      expect(uri.queryParameters['p_pfn_id'], '3');
      expect(find.text('Senior Therapist'), findsOneWidget);
      expect(find.text('৳ 1,900'), findsOneWidget);
      await _capture(t, 'doctor_payment');
      await _finish(t);
    },
  );
  _case(
    'keyboard Done leaves search dialog open and never selects automatically',
    (t) async {
      final h = ReportHarness();
      await _show(t, h);
      await _tap(t, 'report_filter_department');
      await t.enterText(
        find.byKey(const Key('report_parameter_search')),
        'Rehabilitation',
      );
      await t.pumpAndSettle();
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('report_parameter_dialog')), findsOneWidget);
      expect(h.reportReads.length, 4);
      await _capture(t, 'department_search');
      await _tap(t, 'report_parameter_cancel');
      expect(
        t
            .widget<NativeReportFilterField>(
              find.byKey(const Key('report_filter_department')),
            )
            .value,
        '',
      );
      await _finish(t);
    },
  );
  _case('search with no matches has native empty message and cancel', (
    t,
  ) async {
    final h = ReportHarness();
    await _show(t, h);
    await _tap(t, 'report_filter_department');
    await t.enterText(
      find.byKey(const Key('report_parameter_search')),
      'unmatched',
    );
    await t.pumpAndSettle();
    expect(find.text('No Information Found'), findsOneWidget);
    await _tap(t, 'report_parameter_cancel');
    await _finish(t);
  });
  _case('clearing Department resets descendants and disables type 3 Unit', (
    t,
  ) async {
    final h = ReportHarness();
    await _show(t, h, item: ReportManagerItem.doctorPayment);
    await _select(t, 'department', 1);
    await _select(t, 'unit', 0);
    await _select(t, 'doctor', 0);
    await _select(t, 'service', 0);
    await _select(t, 'department', 0);
    for (final p in ['department', 'unit', 'doctor', 'service']) {
      expect(
        t
            .widget<NativeReportFilterField>(
              find.byKey(Key('report_filter_$p')),
            )
            .value,
        '',
      );
    }
    expect(
      t
          .widget<NativeReportFilterField>(
            find.byKey(const Key('report_filter_unit')),
          )
          .enabled,
      false,
    );
    await _tap(t, 'report_show');
    expect(toastMessages, contains('Please Select Doctor'));
    expect(find.byType(ReportResultsScreen), findsNothing);
    await _finish(t);
  });
  _case('invalid Begin date clears field and SHOW requests a date range', (
    t,
  ) async {
    final h = ReportHarness();
    await _show(t, h);
    await _tap(t, 'report_begin');
    await t.tap(find.byTooltip('Switch to input'));
    await t.pumpAndSettle();
    await t.enterText(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byType(TextField),
      ),
      '11/01/2026',
    );
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('report_date_invalid')), findsOneWidget);
    expect(
      t
          .widget<NativeReportFilterField>(
            find.byKey(const Key('report_begin')),
          )
          .value,
      '',
    );
    await _tap(t, 'report_show');
    expect(toastMessages, contains('Please Select Date Range'));
    await _finish(t);
  });
  for (final item in ReportManagerItem.values.where((v) => !v.directPdf)) {
    _case('${item.nativeType}: native table renders with PDF button', (
      t,
    ) async {
      final h = ReportHarness();
      await _show(
        t,
        h,
        page:
            () => ReportResultsScreen(
              auth: h.auth,
              repository: h.reports,
              request: reportRequest(item),
              config: reportConfig,
            ),
      );
      expect(find.byType(NativeReportTable), findsOneWidget);
      expect(find.byKey(const Key('report_pdf_view')), findsOneWidget);
      if (item == ReportManagerItem.paymentReceive ||
          item == ReportManagerItem.doctorAppointment) {
        await t.drag(
          find.byKey(const Key('report_table_horizontal')),
          const Offset(-320, 0),
        );
        await t.pumpAndSettle();
      }
      await _capture(t, 'table_${item.nativeType}');
      await _finish(t);
    });
  }
  _case('non-PDF centre can show data with empty server configuration', (
    t,
  ) async {
    final h = ReportHarness(special: false);
    await _show(
      t,
      h,
      page:
          () => ReportResultsScreen(
            auth: h.auth,
            repository: h.reports,
            request: reportRequest(ReportManagerItem.paymentSummary),
            config: const ReportServerConfig(),
          ),
    );
    expect(find.text('৳ 2,000'), findsOneWidget);
    expect(find.byKey(const Key('report_pdf_view')), findsNothing);
    await _finish(t);
  });
  _case('GET failure Retry repeats stage once without changing other filters', (
    t,
  ) async {
    final h = ReportHarness();
    await _show(t, h);
    var failed = false;
    h.reportOverride = (uri) async {
      if (!failed) {
        failed = true;
        throw const AppFailure('Synthetic loading failure.');
      }
      return {
        'count': 1,
        'items': [
          {'depts_id': '2', 'depts_name': 'Therapy Unit'},
        ],
      };
    };
    await _select(t, 'department', 1);
    expect(find.byKey(const Key('report_error_dialog')), findsOneWidget);
    await _tap(t, 'report_error_retry');
    expect(
      t
          .widget<NativeReportFilterField>(
            find.byKey(const Key('report_filter_department')),
          )
          .value,
      'Rehabilitation Department',
    );
    expect(
      h.reportReads.where((r) => r.uri.pathSegments.last == 'getDepts').length,
      3,
    );
    await _finish(t);
  });
  _case(
    'manager permission loss closes report and keeps session authenticated',
    (t) async {
      final h = ReportHarness();
      await _show(t, h);
      h.doctorData['doc_manager_flag'] = '0';
      await _tap(t, 'report_show');
      expect(
        find.descendant(
          of: find.byKey(const Key('report_error_dialog')),
          matching: find.text(
            'Report Manager is not available for this account.',
          ),
        ),
        findsOneWidget,
      );
      await _tap(t, 'report_error_exit');
      expect(find.byType(ReportParametersScreen), findsNothing);
      expect(h.auth.stage, AuthStage.authenticated);
      await _finish(t);
    },
  );
  _case('background during a read discards late response and resumes cleanly', (
    t,
  ) async {
    final h = ReportHarness();
    await _show(t, h);
    final pending = Completer<JsonMap>();
    h.reportOverride = (_) => pending.future;
    await _tap(t, 'report_filter_department');
    await t.tap(find.byKey(const Key('report_parameter_option_1')));
    await t.pump();
    _pause(t);
    await t.pump();
    pending.complete({
      'count': 1,
      'items': [
        {'depts_id': '2', 'depts_name': 'Stale'},
      ],
    });
    await t.pump();
    expect(find.text('Stale'), findsNothing);
    h.reportOverride = null;
    _resume(t);
    await t.pumpAndSettle();
    await _tap(t, 'report_filter_unit');
    expect(find.text('Therapy Unit'), findsOneWidget);
    expect(find.text('Stale'), findsNothing);
    await _finish(t);
  });
  _case('logout dismisses an owned parameter picker and clears old content', (
    t,
  ) async {
    final h = ReportHarness();
    await _show(t, h);
    await _tap(t, 'report_filter_department');
    await h.auth.logout();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump();
    expect(find.byKey(const Key('report_parameter_dialog')), findsNothing);
    expect(find.text('Rehabilitation Department'), findsNothing);
    await _finish(t);
  });
  _case(
    'real Management menu opens report parameters without destination override',
    (t) async {
      final h = ReportHarness();
      await _show(
        t,
        h,
        page:
            () => ManagementMenuScreen(
              auth: h.auth,
              entry: ManagementEntry.reports,
            ),
      );
      await _tap(t, 'report_manager_select_2');
      expect(find.byType(ReportParametersScreen), findsOneWidget);
      await _tap(t, 'report_show');
      expect(find.text('৳ 2,000'), findsOneWidget);
      await _finish(t);
    },
  );
  for (final size in [const Size(280, 568), const Size(852, 393)]) {
    _case('form/picker remain usable at $size with larger text', (t) async {
      final h = ReportHarness();
      await _show(
        t,
        h,
        item: ReportManagerItem.doctorPayment,
        size: size,
        textScale: 1.4,
      );
      await _tap(t, 'report_filter_department');
      await _tap(t, 'report_parameter_cancel');
      await _finish(t);
    });
  }
  _case('PDF Prev/Next bounds, confirmation and actual save dispatch', (
    t,
  ) async {
    final h = ReportHarness(),
        platform = FakeReportPdfPlatform(),
        download = FakeReportPdfTransport();
    await _show(
      t,
      h,
      page:
          () => ReportPdfScreen(
            auth: h.auth,
            repository: h.reports,
            request: reportRequest(ReportManagerItem.paymentRegister),
            config: reportConfig,
            platform: platform,
            transportFactory: () => download,
          ),
    );
    expect(
      t
          .widget<IconButton>(find.byKey(const Key('report_pdf_previous')))
          .onPressed,
      isNull,
    );
    await _tap(t, 'report_pdf_next');
    await _tap(t, 'report_pdf_next');
    expect(platform.pages, [1, 2]);
    expect(
      t.widget<IconButton>(find.byKey(const Key('report_pdf_next'))).onPressed,
      isNull,
    );
    await _tap(t, 'report_pdf_download');
    await _tap(t, 'report_download_no');
    expect(platform.saves, 0);
    await _tap(t, 'report_pdf_download');
    await _tap(t, 'report_download_yes');
    expect(platform.saves, 1);
    expect(toastMessages, contains('Report saved.'));
    await _finish(t);
    expect(platform.disposals, 1);
    expect(download.closes, greaterThan(0));
  });
  _case('PDF download rechecks Manager permission before export', (t) async {
    final h = ReportHarness(), platform = FakeReportPdfPlatform();
    await _show(
      t,
      h,
      page:
          () => ReportPdfScreen(
            auth: h.auth,
            repository: h.reports,
            request: reportRequest(ReportManagerItem.paymentRegister),
            config: reportConfig,
            platform: platform,
            transportFactory: FakeReportPdfTransport.new,
          ),
    );
    await _tap(t, 'report_pdf_download');
    h.doctorData['doc_manager_flag'] = '0';
    await _tap(t, 'report_download_yes');
    expect(platform.saves, 0);
    expect(
      find.descendant(
        of: find.byKey(const Key('report_error_dialog')),
        matching: find.text(
          'Report Manager is not available for this account.',
        ),
      ),
      findsOneWidget,
    );
    await _finish(t);
  });
  _case('PDF background cancels save and refreshes page zero on resume', (
    t,
  ) async {
    final h = ReportHarness(), platform = FakeReportPdfPlatform();
    await _show(
      t,
      h,
      page:
          () => ReportPdfScreen(
            auth: h.auth,
            repository: h.reports,
            request: reportRequest(ReportManagerItem.paymentRegister),
            config: reportConfig,
            platform: platform,
            transportFactory: FakeReportPdfTransport.new,
          ),
    );
    platform.saving = Completer<bool>();
    await _tap(t, 'report_pdf_download');
    await t.tap(find.byKey(const Key('report_download_yes')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 250));
    _pause(t);
    await t.pump();
    expect(find.byKey(const Key('synthetic_report_pdf_page')), findsNothing);
    _resume(t);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('synthetic_report_pdf_page')), findsOneWidget);
    expect(platform.suspends, greaterThan(0));
    expect(toastMessages.contains('Report saved.'), false);
    await _finish(t);
  });
  _case('PDF save error is bounded and Retry exports the cached PDF once', (
    t,
  ) async {
    final h = ReportHarness(),
        platform = FakeReportPdfPlatform(),
        download = FakeReportPdfTransport();
    var fail = true;
    platform.onSave = () async {
      if (fail) {
        fail = false;
        throw PlatformException(
          code: 'save',
          message: 'synthetic_private_detail',
        );
      }
      return true;
    };
    await _show(
      t,
      h,
      page:
          () => ReportPdfScreen(
            auth: h.auth,
            repository: h.reports,
            request: reportRequest(ReportManagerItem.paymentRegister),
            config: reportConfig,
            platform: platform,
            transportFactory: () => download,
          ),
    );
    await _tap(t, 'report_pdf_download');
    await _tap(t, 'report_download_yes');
    expect(
      find.text('Unable to save the report PDF. Please try again.'),
      findsWidgets,
    );
    expect(find.textContaining('synthetic_private_detail'), findsNothing);
    await _tap(t, 'report_error_retry');
    expect(platform.saves, 2);
    expect(download.calls.length, 1);
    expect(toastMessages, contains('Report saved.'));
    await _finish(t);
  });
}

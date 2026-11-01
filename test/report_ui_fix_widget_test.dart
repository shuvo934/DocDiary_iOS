import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:docdiary_ios/core/app_theme.dart';
import 'package:docdiary_ios/features/reports/native_report_actions.dart';
import 'package:docdiary_ios/features/reports/native_report_controls.dart';
import 'package:docdiary_ios/features/reports/native_report_icons.dart';
import 'package:docdiary_ios/features/reports/native_report_table.dart';
import 'package:docdiary_ios/features/reports/report_manager_menu.dart';
import 'package:docdiary_ios/features/reports/report_manager_models.dart';
import 'package:docdiary_ios/features/reports/report_pdf_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'report_manager_test_support.dart';

Future<void> _show(
  WidgetTester t,
  Widget page, {
  Size size = const Size(393, 852),
  double textScale = 1,
  bool settle = true,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    RepaintBoundary(
      key: const Key('report_ui_capture'),
      child: MaterialApp(
        theme: docDiaryTheme(),
        debugShowCheckedModeBanner: false,
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
                body: TextButton(
                  key: const Key('open'),
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => page),
                      ),
                  child: const Text('Open'),
                ),
              ),
        ),
      ),
    ),
  );
  await t.tap(find.byKey(const Key('open')));
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }
  expect(t.takeException(), isNull);
}

Future<void> _capture(WidgetTester t, String name) async {
  final dir = Platform.environment['DOC_REPORT_UI_CAPTURE_DIR'];
  if (dir == null) return;
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('report_ui_capture')),
  );
  await t.runAsync(() async {
    final picture = await boundary.toImage(pixelRatio: 2);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    final output = File('$dir/$name.png');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
  expect(t.takeException(), isNull);
}

Future<void> _tap(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
  expect(t.takeException(), isNull);
}

Widget _table(ReportManagerItem item, {bool empty = false, int? count}) {
  final rows = reportRows(item);
  final data =
      empty
          ? <Map<String, dynamic>>[]
          : count == null
          ? rows
          : [
            for (var i = 0; i < count; ++i)
              {
                ...rows.first,
                'deptd_name': 'Department $i',
                'doc_name': 'Therapist $i',
              },
          ];
  return NativeReportFrame(
    title: item.title,
    onClose: () {},
    action: NativeReportPdfButton(onPressed: () {}),
    child: NativeReportTable(
      table: ReportTable.fromData(item, data),
      request: reportRequest(item),
    ),
  );
}

Future<void> _pdf(
  WidgetTester t,
  ReportHarness h,
  FakeReportPdfPlatform platform,
  FakeReportPdfTransport download, {
  Size size = const Size(393, 852),
  bool settle = true,
}) async {
  addTearDown(h.auth.dispose);
  _resume(t);
  await h.signIn();
  await _show(
    t,
    ReportPdfScreen(
      auth: h.auth,
      repository: h.reports,
      request: reportRequest(ReportManagerItem.paymentRegister),
      config: reportConfig,
      platform: platform,
      transportFactory: () => download,
    ),
    size: size,
    settle: settle,
  );
}

void _pause(WidgetTester t) {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    t.binding.handleAppLifecycleStateChanged(s);
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
    final previous = debugDisableShadows;
    debugDisableShadows = false;
    try {
      await body(t);
    } finally {
      debugDisableShadows = previous;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry
        in <String, List<String>>{
          'Poppins': ['Poppins-Regular.ttf', 'Poppins-Bold.ttf'],
          'PatuaOne': ['PatuaOne-Regular.ttf'],
          'Roboto': ['Roboto-Regular.ttf', 'Roboto-Bold.ttf'],
          'Baloo': ['Baloo-Regular.ttf'],
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
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('PonnamKarthik/fluttertoast'),
          (_) async => true,
        ),
  );

  for (final item in ReportManagerItem.values.where((v) => !v.directPdf)) {
    for (final empty in [false, true]) {
      _case(
        '${item.nativeType}: ${empty ? 'empty' : 'short'} total follows data without a blank viewport',
        (t) async {
          await _show(t, _table(item, empty: empty));
          final total = t.getRect(find.byKey(const Key('report_table_total')));
          if (!empty) {
            final last = t.getRect(
              find.byKey(
                Key('report_table_row_${reportRows(item).length - 1}'),
              ),
            );
          expect(total.top - last.bottom, closeTo(0, .01));
          } else {
            final header = t.getRect(
              find
                  .text(
                    item == ReportManagerItem.doctorPayment
                        ? 'Appointment Date'
                        : item == ReportManagerItem.doctorAppointment
                        ? 'Unit Name'
                        : 'Department Name',
                  )
                  .first,
            );
            expect(total.top - header.bottom, lessThan(12));
          }
          final card =
              find
                  .ancestor(
                    of: find.byKey(const Key('report_table_total')),
                    matching: find.byType(Material),
                  )
                  .first;
          expect(t.getRect(card).bottom - total.bottom, closeTo(0, .1));
          expect(total.bottom, lessThan(550));
          final label = find.descendant(
            of: find.byKey(const Key('report_table_total')),
            matching: find.text(
              item == ReportManagerItem.paymentReceive ||
                      item == ReportManagerItem.paymentSummary
                  ? 'Total Amount'
                  : 'Grand Total',
            ),
          );
          final left = t.getTopLeft(label).dx;
          expect(left - total.left, inInclusiveRange(0, 6));
          await _capture(
            t,
            'table_${item.nativeType}_${empty ? 'empty' : 'short'}',
          );
          if (item == ReportManagerItem.paymentReceive) {
            await t.drag(
              find.byKey(const Key('report_table_horizontal')),
              const Offset(-1000, 0),
            );
            await t.pumpAndSettle();
            expect(
              find.text(empty ? '৳ 0' : '৳ 2,000').hitTestable(),
              findsOneWidget,
            );
            await _capture(t, 'table_1_${empty ? 'empty' : 'short'}_right');
          }
          await _finish(t);
        },
      );
    }
  }

  for (final item in [
    ReportManagerItem.paymentReceive,
    ReportManagerItem.paymentSummary,
  ]) {
    _case(
      '${item.nativeType}: long data scrolls to total while header stays visible',
      (t) async {
        await _show(t, _table(item, count: 120));
        final header = t.getTopLeft(find.text('Department Name'));
        expect(
          find.byKey(const Key('report_table_total')).hitTestable(),
          findsNothing,
        );
        final scrollable =
            find
                .descendant(
                  of: find.byKey(const Key('report_table_vertical')),
                  matching: find.byType(Scrollable),
                )
                .first;
        t
            .state<ScrollableState>(scrollable)
            .position
            .jumpTo(
              t.state<ScrollableState>(scrollable).position.maxScrollExtent,
            );
        await t.pumpAndSettle();
        expect(
          find.byKey(const Key('report_table_total')).hitTestable(),
          findsOneWidget,
        );
        expect(t.getTopLeft(find.text('Department Name')), header);
        final last = t.getRect(find.byKey(const Key('report_table_row_119')));
        expect(
          t.getRect(find.byKey(const Key('report_table_total'))).top -
              last.bottom,
          closeTo(0, .01),
        );
        await _finish(t);
      },
    );
  }

  for (final size in [const Size(280, 568), const Size(852, 393)]) {
    _case('table and PDF action fit $size with enlarged text', (t) async {
      await _show(
        t,
        _table(ReportManagerItem.paymentSummary, count: 120),
        size: size,
        textScale: 1.4,
      );
      expect(
        find.byKey(const Key('report_pdf_view')).hitTestable(),
        findsOneWidget,
      );
      await _finish(t);
    });
  }

  _case(
    'PDF View keeps primary color with native wide pill and tracked label',
    (t) async {
      await _show(t, _table(ReportManagerItem.paymentReceive));
      final widget = t.widget<TextButton>(
        find.byKey(const Key('report_pdf_view')),
      );
      expect(widget.style!.backgroundColor!.resolve({}), DocColors.primary);
      expect(widget.style!.shape!.resolve({}), isA<RoundedRectangleBorder>());
      expect(
        t.getSize(find.byKey(const Key('report_pdf_view'))).width,
        greaterThanOrEqualTo(88),
      );
      expect(t.widget<Text>(find.text('PDF VIEW')).style!.letterSpacing, 1.25);
      await _finish(t);
    },
  );

  _case(
    'native arrows stay small circles with white glyph and 44dp target, even disabled',
    (t) async {
      final h = ReportHarness(),
          platform = FakeReportPdfPlatform()..pageCount = 1;
      await _pdf(t, h, platform, FakeReportPdfTransport());
      for (final name in ['previous', 'next']) {
        final button = find.byKey(Key('report_pdf_$name')),
            surface = find.byKey(Key('report_pdf_${name}_surface'));
        expect(t.widget<IconButton>(button).onPressed, isNull);
        expect(t.getSize(button).width, greaterThanOrEqualTo(44));
        expect(t.getSize(surface).width, closeTo(31.8, .1));
        expect(t.widget<Material>(surface).shape, isA<CircleBorder>());
        expect(
          t
              .widget<NativeReportIcon>(
                find.descendant(
                  of: surface,
                  matching: find.byType(NativeReportIcon),
                ),
              )
              .color,
          Colors.white,
        );
      }
      await _capture(t, 'pdf_controls_synthetic_page');
      await _finish(t);
    },
  );

  _case('zoom in/out dispatches without fetching or saving the PDF again', (
    t,
  ) async {
    final h = ReportHarness(),
        platform = FakeReportPdfPlatform(),
        download = FakeReportPdfTransport();
    await _pdf(t, h, platform, download);
    final calls = h.transport.requests.length;
    await _tap(t, 'report_pdf_zoom_in');
    await _tap(t, 'report_pdf_zoom_out');
    expect(platform.zooms, [true, false]);
    expect(platform.pages, isEmpty);
    expect(platform.saves, 0);
    expect(download.calls.length, 1);
    expect(h.transport.requests.length, calls);
    await _finish(t);
  });

  _case('page, save and zoom controls wait for native initial fitting', (
    t,
  ) async {
    final h = ReportHarness(),
        platform = FakeReportPdfPlatform()..autoLoad = false;
    final download = FakeReportPdfTransport();
    // Loading spinner is intentionally active before the native fit completes.
    await _pdf(t, h, platform, download, settle: false);
    for (var i = 0; i < 10 && platform.loaded == null; ++i) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('report_pdf_zoom_in')), findsNothing);
    expect(
      t
          .widget<IconButton>(find.byKey(const Key('report_pdf_download')))
          .onPressed,
      isNull,
    );
    platform.loaded!(3);
    await t.pumpAndSettle();
    expect(
      t
          .widget<IconButton>(find.byKey(const Key('report_pdf_zoom_in')))
          .onPressed,
      isNotNull,
    );
    await _finish(t);
  });

  _case(
    'pending zoom disables duplicate actions and late completion cannot restore old background content',
    (t) async {
      final h = ReportHarness(),
          platform = FakeReportPdfPlatform(),
          download = FakeReportPdfTransport();
      final zoom = Completer<void>();
      platform.onZoom = (_) => zoom.future;
      await _pdf(t, h, platform, download);
      await t.tap(find.byKey(const Key('report_pdf_zoom_in')));
      await t.pump();
      for (final name in [
        'zoom_in',
        'zoom_out',
        'next',
        'previous',
        'download',
      ]) {
        expect(
          t.widget<IconButton>(find.byKey(Key('report_pdf_$name'))).onPressed,
          isNull,
        );
      }
      _pause(t);
      await t.pump();
      expect(find.byKey(const Key('synthetic_report_pdf_page')), findsNothing);
      _resume(t);
      zoom.completeError(
        PlatformException(code: 'cancelled', message: 'private_native_error'),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('report_error_dialog')), findsNothing);
      expect(download.calls.length, 2);
      expect(
        find.byKey(const Key('synthetic_report_pdf_page')),
        findsOneWidget,
      );
      await _finish(t);
    },
  );

  _case('bounded zoom error offers Retry and does not leak platform details', (
    t,
  ) async {
    final h = ReportHarness(),
        platform = FakeReportPdfPlatform(),
        download = FakeReportPdfTransport();
    platform.onZoom =
        (_) async =>
            throw PlatformException(
              code: 'zoom',
              message: 'private_native_error',
            );
    await _pdf(t, h, platform, download);
    await _tap(t, 'report_pdf_zoom_in');
    expect(
      find.text('The report zoom could not be changed. Please try again.'),
      findsWidgets,
    );
    expect(find.textContaining('private_native_error'), findsNothing);
    platform.onZoom = null;
    await _tap(t, 'report_error_retry');
    expect(download.calls.length, 2);
    await _tap(t, 'report_pdf_zoom_in');
    expect(platform.zooms, [true, true]);
    await _finish(t);
  });

  _case('logout during zoom clears PDF and ignores its stale failure', (
    t,
  ) async {
    final h = ReportHarness(),
        platform = FakeReportPdfPlatform(),
        download = FakeReportPdfTransport();
    final zoom = Completer<void>();
    platform.onZoom = (_) => zoom.future;
    await _pdf(t, h, platform, download);
    await t.tap(find.byKey(const Key('report_pdf_zoom_in')));
    await t.pump();
    await h.auth.logout();
    zoom.completeError(PlatformException(code: 'cancelled'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('synthetic_report_pdf_page')), findsNothing);
    expect(find.byKey(const Key('report_error_dialog')), findsNothing);
    expect(download.calls.length, 1);
    await _finish(t);
  });
}

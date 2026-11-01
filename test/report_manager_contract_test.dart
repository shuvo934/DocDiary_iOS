import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/reports/report_manager_menu.dart';
import 'package:docdiary_ios/features/reports/report_manager_models.dart';
import 'package:docdiary_ios/features/reports/report_manager_repository.dart';
import 'package:docdiary_ios/features/reports/report_pdf_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'report_manager_test_support.dart';

void main() {
  test('native files, centre rule and ordering remain exact', () {
    expect(
      nativeReportManagerItems(
        Uri.parse('https://x/cstar/'),
      ).map((v) => v.nativeType),
      ['1', '5', '2', '3', '4'],
    );
    expect(reportHasPdf(Uri.parse('https://x/CSTAR/')), false);
    expect(reportHasPdf(Uri.parse('https://x/btrf/')), true);
    expect(
      ReportManagerItem.paymentSummary.reportFile,
      'PAYMENT_RECEIVED_SUMMERY.rep',
    );
    expect(
      ReportManagerItem.doctorPayment.reportFile,
      'DOC_WISE_PAT_APP_PAY_SUMMERY.rep',
    );
    expect(
      ReportManagerItem.doctorAppointment.reportFile,
      'APPOINTMENT_SUMMARY.rep',
    );
  });
  for (final item in ReportManagerItem.values) {
    test('${item.nativeType}: native defaults and field visibility', () {
      final d = ReportParameterDraft(item, DateTime(2026, 10, 31));
      expect(d.dateText(true), '01-Oct-26');
      expect(d.dateText(false), '31-Oct-26');
      expect(d.unitEnabled, !item.showsDoctor);
      expect(d.doctorEnabled, false);
      expect(d.serviceEnabled, !item.showsDoctor);
    });
  }
  test(
    'invalid date clears only the date just chosen; valid next choice recovers',
    () {
      final d = ReportParameterDraft(
        ReportManagerItem.paymentReceive,
        DateTime(2026, 10, 31),
      );
      d.chooseDate(true, DateTime(2026, 11));
      expect(d.begin, isNull);
      expect(d.invalidRange, true);
      expect(d.end, DateTime(2026, 10, 31));
      expect(d.snapshot, throwsA(isA<AppFailure>()));
      d.chooseDate(true, DateTime(2026, 10, 20));
      expect(d.invalidRange, false);
      expect(d.dateText(true), '20-OCT-26');
      d.chooseDate(false, DateTime(2026, 10, 1));
      expect(d.end, isNull);
      expect(d.begin, DateTime(2026, 10, 20));
      d.chooseDate(false, DateTime(2027, 1));
      expect(d.snapshot().end, DateTime(2027, 1));
    },
  );
  test('doctor payment dependency, clearing parent and doctor requirement', () {
    final d = ReportParameterDraft(
      ReportManagerItem.doctorPayment,
      DateTime(2026, 10, 31),
    );
    expect(d.snapshot, throwsA(isA<AppFailure>()));
    expect(
      d.choose(
        ReportParameter.department,
        const ReportChoice('1', 'Department'),
      ),
      ReportParameter.unit,
    );
    d.loaded(ReportParameter.unit);
    expect(d.unitEnabled, true);
    expect(d.doctorEnabled, false);
    expect(
      d.choose(ReportParameter.unit, const ReportChoice('2', 'Unit')),
      ReportParameter.doctor,
    );
    d.loaded(ReportParameter.doctor);
    expect(
      d.choose(ReportParameter.doctor, const ReportChoice('10', 'Doctor')),
      ReportParameter.service,
    );
    d.loaded(ReportParameter.service);
    d.choose(ReportParameter.service, const ReportChoice('3', 'Service'));
    final snapshot = d.snapshot();
    d.choose(ReportParameter.department, ReportChoice.clear);
    d.loaded(ReportParameter.unit);
    expect(
      [d.department, d.unit, d.doctor, d.service],
      [null, null, null, null],
    );
    expect(d.unitEnabled, false);
    expect(snapshot.doctor!.id, '10');
    expect(snapshot.service!.id, '3');
  });
  test(
    'type 4 Unit enable after department clear and optional Doctor match native',
    () {
      final d = ReportParameterDraft(
        ReportManagerItem.doctorAppointment,
        DateTime(2026, 10, 31),
      );
      d.choose(ReportParameter.department, ReportChoice.clear);
      d.loaded(ReportParameter.unit);
      expect(d.unitEnabled, true);
      expect(d.snapshot().doctor, isNull);
    },
  );
  for (final item in ReportManagerItem.values.where((v) => !v.directPdf)) {
    test(
      '${item.nativeType}: exact GET endpoint and native query names',
      () async {
        final h = ReportHarness();
        addTearDown(h.auth.dispose);
        await h.signIn();
        final request = reportRequest(item),
            data = await h.reports.table(
              h.auth.session!,
              h.auth.profile!,
              reportRequest(item),
              isCurrent: () => true,
            );
        final uri = h.reportReads.single.uri;
        expect(uri.path.endsWith('/report_manager/${item.dataEndpoint}'), true);
        expect(uri.queryParameters, request.query);
        expect(data.rows.length, reportRows(item).length);
        expect(h.posts.length, 2); // Login initialization only; no report POST.
        expect(h.reportReads.every((r) => r.method == 'GET'), true);
      },
    );
    test('${item.nativeType}: zero rows retain native zero totals', () {
      final t = ReportTable.fromData(item, []);
      expect(t.rows, isEmpty);
      expect(
        t.totals,
        item == ReportManagerItem.doctorPayment
            ? ['0', '0', '0']
            : item == ReportManagerItem.doctorAppointment
            ? ['0', '0', '0', '0']
            : ['৳ 0'],
      );
    });
  }
  test('blank filters are sent as empty parameters, not omitted', () {
    final r = ReportRequest(
      item: ReportManagerItem.paymentReceive,
      begin: DateTime(2026, 10),
      end: DateTime(2026, 10, 31),
    );
    expect(r.query, {
      'deptdid': '',
      'deptsid': '',
      'pfnid': '',
      'b_date': '01-OCT-26',
      'e_date': '31-OCT-26',
    });
  });
  test(
    'catalogue sequential order, all-choice rows and JSON-string array',
    () async {
      final h = ReportHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      final c = await h.reports.catalogue(
        h.auth.session!,
        h.auth.profile!,
        ReportManagerItem.doctorAppointment,
        isCurrent: () => true,
      );
      expect(h.reportReads.map((r) => r.uri.pathSegments.last), [
        'getDeptd',
        'getDepts',
        'getService',
        'getUrlData',
      ]);
      expect(h.reportReads[1].uri.queryParameters, {'deptd_id': ''});
      expect(h.reportReads[2].uri.queryParameters, {'depts_id': ''});
      expect(c.departments.first, ReportChoice.clear);
      expect(c.units.first, ReportChoice.clear);
      expect(c.services.first, ReportChoice.clear);
      h.reportOverride =
          (_) async => {
            'count': 2,
            'items': jsonEncode([
              {'doc_id': '10', 'doc_name': 'Same'},
              {'doc_id': '11', 'doc_name': 'Same'},
            ]),
          };
      final doctors = await h.reports.choices(
        h.auth.session!,
        h.auth.profile!,
        ReportManagerItem.doctorPayment,
        ReportParameter.doctor,
        parentId: '2',
        isCurrent: () => true,
      );
      expect(doctors.map((v) => v.id), ['10', '11']);
      expect(doctors.map((v) => v.name), ['Same', 'Same']);
    },
  );
  test(
    'dependent lists do not prepend clear; empty catalogue has no fake choice',
    () async {
      final h = ReportHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      final rows = await h.reports.choices(
        h.auth.session!,
        h.auth.profile!,
        ReportManagerItem.paymentReceive,
        ReportParameter.unit,
        parentId: '1',
        isCurrent: () => true,
      );
      expect(rows.any((v) => v.isClear), false);
      h.reportOverride = (_) async => {'count': 0, 'items': []};
      expect(
        await h.reports.choices(
          h.auth.session!,
          h.auth.profile!,
          ReportManagerItem.paymentReceive,
          ReportParameter.unit,
          includeClear: true,
          isCurrent: () => true,
        ),
        isEmpty,
      );
    },
  );
  test(
    'manager loss, identity mismatch, mobile denial and centre restriction stop reads',
    () async {
      final h = ReportHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      final session = h.auth.session!, profile = h.auth.profile!;
      for (final change in [
        {'doc_manager_flag': '0'},
        {'doc_code': 'OTHER'},
        {'access_flag': '0'},
      ]) {
        final changed = AccountProfile(profile.role, {
          ...profile.values,
          ...change,
        });
        expect(
          () => h.reports.guard(
            session,
            changed,
            ReportManagerItem.paymentReceive,
            () => true,
          ),
          throwsA(anything),
        );
      }
      expect(
        () => h.reports.guard(
          session,
          profile,
          ReportManagerItem.paymentReceive,
          () => false,
        ),
        throwsA(isA<ObsoleteRequest>()),
      );
      expect(h.reportReads, isEmpty);
      final normal = ReportHarness(special: false);
      addTearDown(normal.auth.dispose);
      await normal.signIn();
      expect(
        () => normal.reports.guard(
          normal.auth.session!,
          normal.auth.profile!,
          ReportManagerItem.paymentRegister,
          () => true,
        ),
        throwsA(isA<ReportManagerUnavailable>()),
      );
    },
  );
  test('Admin can use the same report GET contracts', () async {
    final h = ReportHarness(admin: true);
    addTearDown(h.auth.dispose);
    await h.signIn();
    final t = await h.reports.table(
      h.auth.session!,
      h.auth.profile!,
      reportRequest(ReportManagerItem.paymentSummary),
      isCurrent: () => true,
    );
    expect(t.totals, ['৳ 2,000']);
  });
  test(
    'late response is discarded before parsing and no next catalogue GET runs',
    () async {
      final h = ReportHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      final pending = Completer<JsonMap>();
      var active = true;
      h.reportOverride = (_) => pending.future;
      final result = h.reports.catalogue(
        h.auth.session!,
        h.auth.profile!,
        ReportManagerItem.paymentReceive,
        isCurrent: () => active,
      );
      active = false;
      pending.complete({
        'count': 1,
        'items': [
          {'deptd_id': '1', 'deptd_name': 'D'},
        ],
      });
      await expectLater(result, throwsA(isA<ObsoleteRequest>()));
      expect(h.reportReads.length, 1);
    },
  );
  test(
    'malformed counts, incomplete lists and invalid identifiers fail boundedly',
    () async {
      final h = ReportHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      for (final payload in <JsonMap>[
        {'count': -1},
        {'count': 'bad'},
        {'count': 2, 'items': []},
        {
          'count': 1,
          'items': [
            {'deptd_id': '1+DOC=2', 'deptd_name': 'Bad'},
          ],
        },
      ]) {
        h.reportOverride = (_) async => payload;
        await expectLater(
          h.reports.choices(
            h.auth.session!,
            h.auth.profile!,
            ReportManagerItem.paymentReceive,
            ReportParameter.department,
            isCurrent: () => true,
          ),
          throwsA(isA<AppFailure>()),
        );
      }
    },
  );
  test(
    'native repeated names, group boundaries, sums and last designation',
    () {
      final p = ReportTable.fromData(
        ReportManagerItem.paymentReceive,
        reportRows(ReportManagerItem.paymentReceive),
      );
      expect(p.rows[1].cells.take(2), ['〃', '〃']);
      expect(p.rows.map((v) => v.groupEnd), [false, true, true]);
      expect(p.totals, ['৳ 2,000']);
      final d = ReportTable.fromData(
        ReportManagerItem.doctorPayment,
        reportRows(ReportManagerItem.doctorPayment),
      );
      expect(d.totals, ['৳ 1,500', '৳ 400', '৳ 1,900']);
      expect(d.designation, 'Senior Therapist');
      expect(d.rows[0].cells[2], '0');
      final a = ReportTable.fromData(
        ReportManagerItem.doctorAppointment,
        reportRows(ReportManagerItem.doctorAppointment),
      );
      expect(a.rows.last.cells.first, '〃');
      expect(a.totals, ['5', '1', '3', '9']);
      expect(
        () => ReportTable.fromData(ReportManagerItem.paymentSummary, [
          {'tot_amt': 'NaN'},
        ]),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  for (final item in ReportManagerItem.values) {
    test(
      '${item.nativeType}: Oracle URL preserves plus delimiters and encodes argument values',
      () {
        final url = reportConfig.url(reportRequest(item));
        expect(url.scheme, 'http');
        expect(url.host, 'reports.example.test');
        expect(url.port, 8888);
        expect(url.path, '/reports/rwservlet');
        final args = url.query.split('+');
        expect(args.first, 'synthetic_key');
        final map = {
          for (final a in args.skip(1))
            a.split('=').first: Uri.decodeComponent(
              a.substring(a.indexOf('=') + 1),
            ),
        };
        expect(map['report'], '/reports/DocDiary/${item.reportFile}');
        expect(map['BEGIN_DATE'], '01-OCT-26');
        expect(
          map.containsKey('UNIT'),
          item == ReportManagerItem.doctorPayment,
        );
        expect(map.containsKey('DOC'), item.showsDoctor);
        expect(map.containsKey('DEPTD'), !item.showsDoctor);
        expect(map.containsKey('CIDID'), !item.showsDoctor);
      },
    );
  }
  test(
    'bad PDF config fails only when PDF requested and errors omit server key',
    () {
      final request = reportRequest(ReportManagerItem.paymentReceive);
      for (final config in [
        const ReportServerConfig(),
        const ReportServerConfig(server: 'bad@host', path: 'x', link: 'secret'),
      ]) {
        try {
          config.url(request);
          fail('Expected invalid config');
        } on AppFailure catch (e) {
          expect(e.message.contains('secret'), false);
        }
      }
      expect(
        () => ReportServerConfig(
          server: 'host',
          path: '/report/',
          link: 'key',
        ).url(
          ReportRequest(
            item: ReportManagerItem.paymentReceive,
            begin: DateTime(2026),
            end: DateTime(2026),
            department: const ReportChoice('1+DOC=2', 'x'),
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'PDF magic rejects HTML/empty responses and accepts binary PDF prefix',
    () {
      for (final text in ['', '<html>Error</html>', '%PD']) {
        expect(
          () => validateReportPdf(Uint8List.fromList(text.codeUnits)),
          throwsA(isA<AppFailure>()),
        );
      }
      validateReportPdf(Uint8List.fromList('%PDF-1.7\n'.codeUnits));
    },
  );
  test(
    'binary download gets exact PDF bytes, rejects redirects and bounds errors',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final pdf = Uint8List.fromList('%PDF-1.7 synthetic\n'.codeUnits),
          paths = <String>[];
      server.listen((r) async {
        paths.add(r.uri.path);
        if (r.uri.path == '/redirect') {
          r.response.statusCode = 302;
          r.response.headers.set('location', '/ok');
        } else if (r.uri.path == '/bad') {
          r.response.write('not a PDF');
        } else {
          r.response.add(pdf);
        }
        await r.response.close();
      });
      final transport = IoReportPdfTransport();
      addTearDown(transport.close);
      Uri uri(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');
      expect(await transport.get(uri('/ok'), isCurrent: () => true), pdf);
      await expectLater(
        transport.get(uri('/redirect'), isCurrent: () => true),
        throwsA(isA<AppFailure>()),
      );
      expect(paths, ['/ok', '/redirect']);
      await expectLater(
        transport.get(uri('/bad'), isCurrent: () => true),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        transport.get(uri('/ok'), isCurrent: () => false),
        throwsA(isA<ObsoleteRequest>()),
      );
    },
  );
  test(
    'binary report timeout is bounded and does not retry automatically',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var calls = 0;
      server.listen((request) {
        ++calls;
      });
      final transport = IoReportPdfTransport(
        timeout: const Duration(milliseconds: 300),
      );
      addTearDown(transport.close);
      await expectLater(
        transport.get(
          Uri.parse('http://127.0.0.1:${server.port}/report?private_key'),
          isCurrent: () => true,
        ),
        throwsA(
          isA<AppFailure>()
              .having((e) => e.kind, 'network timeout', FailureKind.network)
              .having(
                (e) => e.message.contains('private_key'),
                'redacted',
                false,
              ),
        ),
      );
      expect(calls, 1);
    },
  );
  test(
    'binary report rejects declared oversize before buffering its body',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentLength =
            IoReportPdfTransport.maxBytes + 1;
        request.response.add('%PDF-'.codeUnits);
        try {
          await request.response.flush();
        } catch (_) {}
      });
      final transport = IoReportPdfTransport();
      addTearDown(transport.close);
      await expectLater(
        transport.get(
          Uri.parse('http://127.0.0.1:${server.port}/large'),
          isCurrent: () => true,
        ),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'size feedback',
            contains('too large'),
          ),
        ),
      );
    },
  );
  test(
    'legacy Admin profile may omit usr_id, but a conflicting returned ID is rejected',
    () async {
      final h = ReportHarness(admin: true);
      addTearDown(h.auth.dispose);
      await h.signIn();
      expect(h.auth.profile!.value('usr_id'), '');
      h.reports.guard(
        h.auth.session!,
        h.auth.profile!,
        ReportManagerItem.paymentReceive,
        () => true,
      );
      final conflict = AccountProfile(h.auth.profile!.role, {
        ...h.auth.profile!.values,
        'usr_id': '999',
      });
      expect(
        () => h.reports.guard(
          h.auth.session!,
          conflict,
          ReportManagerItem.paymentReceive,
          () => true,
        ),
        throwsA(isA<AppFailure>()),
      );
    },
  );
}

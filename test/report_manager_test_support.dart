import 'dart:async';
import 'dart:typed_data';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/reports/native_report_pdf_platform.dart';
import 'package:docdiary_ios/features/reports/report_manager_menu.dart';
import 'package:docdiary_ios/features/reports/report_manager_models.dart';
import 'package:docdiary_ios/features/reports/report_manager_repository.dart';
import 'package:docdiary_ios/features/reports/report_pdf_transport.dart';
import 'package:flutter/material.dart';
import 'support.dart';

const reportConfig = ReportServerConfig(
  server: 'reports.example.test:8888',
  path: '/reports/DocDiary/',
  link: 'synthetic_key+destype=cache+desformat=pdf',
  center: '9',
);
JsonMap reportConfigData() => {
  'lic_rep_server_port': reportConfig.server,
  'lic_rep_path': reportConfig.path,
  'lic_rep_hrs_link': reportConfig.link,
  'cid_id': reportConfig.center,
};
ReportRequest reportRequest(ReportManagerItem item) => ReportRequest(
  item: item,
  begin: DateTime(2026, 10),
  end: DateTime(2026, 10, 31),
  department: const ReportChoice('1', 'Rehabilitation Department'),
  unit: const ReportChoice('2', 'Therapy Unit'),
  doctor:
      item.showsDoctor ? const ReportChoice('10', 'Example Therapist') : null,
  service:
      item.showsService ? const ReportChoice('3', 'Therapy Service') : null,
);

List<JsonMap> reportRows(ReportManagerItem item) => switch (item) {
  ReportManagerItem.paymentReceive => [
    {
      'deptd_id': '1',
      'deptd_name': 'Rehabilitation Department',
      'depts_id': '2',
      'depts_name': 'Therapy Unit',
      'pfn_id': '3',
      'pfn_fee_name': 'Therapy Service',
      'prd_rate': '500',
      'tot_qty': '2',
      'tot_amt': '1000',
    },
    {
      'deptd_id': '1',
      'deptd_name': 'Rehabilitation Department',
      'depts_id': '2',
      'depts_name': 'Therapy Unit',
      'pfn_id': '4',
      'pfn_fee_name': 'Assessment',
      'prd_rate': '400',
      'tot_qty': '1',
      'tot_amt': '400',
    },
    {
      'deptd_id': '7',
      'deptd_name': 'Another Department',
      'depts_id': '8',
      'depts_name': 'Another Unit',
      'pfn_id': '5',
      'pfn_fee_name': 'Consultation',
      'prd_rate': '600',
      'tot_qty': '1',
      'tot_amt': '600',
    },
  ],
  ReportManagerItem.paymentSummary => [
    {
      'deptd_id': '1',
      'deptd_name': 'Rehabilitation Department',
      'depts_id': '2',
      'depts_name': 'Therapy Unit',
      'tot_amt': '1400',
    },
    {
      'deptd_id': '1',
      'deptd_name': 'Rehabilitation Department',
      'depts_id': '8',
      'depts_name': 'Another Unit',
      'tot_amt': '600',
    },
  ],
  ReportManagerItem.doctorPayment => [
    {
      'app_date1': '20-OCT-26',
      'designation': 'Therapist',
      'date_total_reg': '1000',
      'date_total_ets': null,
      'date_total': '1000',
    },
    {
      'app_date1': '21-OCT-26',
      'designation': 'Senior Therapist',
      'date_total_reg': '500',
      'date_total_ets': '400',
      'date_total': '900',
    },
  ],
  ReportManagerItem.doctorAppointment => [
    {
      'deptd_id': '1',
      'depts_id': '2',
      'depts_name': 'Therapy Unit',
      'doc_id': '10',
      'doc_name': 'Example Therapist',
      'regular_count': '3',
      'extra_count': '1',
      'block_count': '2',
      'blank_count': '4',
    },
    {
      'deptd_id': '1',
      'depts_id': '2',
      'depts_name': 'Therapy Unit',
      'doc_id': '11',
      'doc_name': 'Another Therapist',
      'regular_count': '2',
      'extra_count': null,
      'block_count': '1',
      'blank_count': '5',
    },
  ],
  ReportManagerItem.paymentRegister => [],
};

class ReportHarness extends Harness {
  ReportHarness({bool special = true, bool manager = true, bool admin = false})
    : super(clock: DateTime(2026, 10, 31, 13, 30)) {
    loginResponse =
        admin
            ? adminLogin()
            : doctorLogin(
              base:
                  special
                      ? 'https://centre.example/ords/cstar/'
                      : 'https://centre.example/api/',
            );
    doctorData['doc_manager_flag'] = manager ? '1' : '0';
    if (admin && special) {
      loginResponse['p_center_api'] = 'https://centre.example/ords/btrf/';
    }
    transport.onGet = respond;
  }
  Future<JsonMap> Function(Uri)? reportOverride;
  ReportManagerRepository get reports =>
      ReportManagerRepository(transport, now: () => now);
  Future<JsonMap> respond(Uri uri) async {
    if (!uri.path.contains('/report_manager/')) return defaultGet(uri);
    if (reportOverride != null) return reportOverride!(uri);
    final endpoint = uri.pathSegments.last;
    final List<JsonMap> items;
    switch (endpoint) {
      case 'getDeptd':
        items = [
          {'deptd_id': '1', 'deptd_name': 'Rehabilitation Department'},
          {'deptd_id': '7', 'deptd_name': 'Another Department'},
        ];
      case 'getDepts':
        items = [
          {'depts_id': '2', 'depts_name': 'Therapy Unit'},
          {'depts_id': '8', 'depts_name': 'Another Unit'},
        ];
      case 'getDoctors':
        items = [
          {'doc_id': '10', 'doc_name': 'Example Therapist'},
          {'doc_id': '11', 'doc_name': 'Example Therapist'},
        ];
      case 'getService':
        items = [
          {'pfn_id': '3', 'pfn_fee_name': 'Therapy Service'},
          {'pfn_id': '4', 'pfn_fee_name': 'Assessment'},
        ];
      case 'getUrlData':
        items = [reportConfigData()];
      default:
        items = reportRows(
          ReportManagerItem.values.firstWhere(
            (v) => !v.directPdf && v.dataEndpoint == endpoint,
          ),
        );
    }
    return {'count': items.length, 'items': items};
  }

  List<RequestRecord> get reportReads =>
      transport.requests
          .where((r) => r.uri.path.contains('/report_manager/'))
          .toList();
}

class FakeReportPdfTransport implements ReportPdfTransport {
  final calls = <Uri>[];
  Future<Uint8List> Function()? onGet;
  int closes = 0;
  @override
  Future<Uint8List> get(Uri uri, {required bool Function() isCurrent}) async {
    calls.add(uri);
    return onGet == null
        ? Uint8List.fromList('%PDF-1.7 synthetic platform fixture'.codeUnits)
        : onGet!();
  }

  @override
  void close() {
    ++closes;
  }
}

class FakeReportPdfPlatform implements ReportPdfPlatform {
  Uint8List? _loaded;
  ValueChanged<String>? error;
  ValueChanged<int>? loaded;
  int pageCount = 3;
  bool autoLoad = true;
  final pages = <int>[];
  final zooms = <bool>[];
  int saves = 0, suspends = 0, disposals = 0;
  Completer<bool>? saving;
  Future<int> Function(int)? onPage;
  Future<bool> Function()? onSave;
  Future<void> Function(bool)? onZoom;
  @override
  Widget buildView({
    required Uint8List bytes,
    required String documentName,
    required ValueChanged<int> onLoaded,
    required ValueChanged<String> onError,
  }) {
    error = onError;
    loaded = onLoaded;
    if (!identical(bytes, _loaded)) {
      _loaded = bytes;
      if (autoLoad) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => onLoaded(pageCount),
        );
      }
    }
    return ColoredBox(
      key: const Key('synthetic_report_pdf_page'),
      color: Colors.white,
      child: Center(
        child: Text(
          'Synthetic report PDF\nPage ${pages.isEmpty ? 1 : pages.last + 1}',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Future<int> page(int index) async {
    pages.add(index);
    return onPage == null ? index : onPage!(index);
  }

  @override
  Future<void> zoom(bool zoomIn) async {
    zooms.add(zoomIn);
    await onZoom?.call(zoomIn);
  }

  @override
  Future<bool> save() async {
    ++saves;
    if (onSave != null) {
      return onSave!();
    }
    return saving?.future ?? Future.value(true);
  }

  @override
  Future<void> suspend() async {
    ++suspends;
    _loaded = null;
    if (saving != null && !saving!.isCompleted) saving!.complete(false);
  }

  @override
  void dispose() {
    ++disposals;
  }
}

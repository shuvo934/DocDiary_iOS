import '../../core/failure.dart';
import '../../core/native_dates.dart';
import '../../core/native_json.dart';
import 'report_manager_menu.dart';

enum ReportParameter {
  department('Department', 'deptd_id', 'deptd_name'),
  unit('Unit', 'depts_id', 'depts_name'),
  doctor('Doctor', 'doc_id', 'doc_name'),
  service('Service', 'pfn_id', 'pfn_fee_name');

  const ReportParameter(this.label, this.idKey, this.nameKey);
  final String label, idKey, nameKey;
}

extension ReportManagerContract on ReportManagerItem {
  bool get showsDoctor =>
      this == ReportManagerItem.doctorPayment ||
      this == ReportManagerItem.doctorAppointment;
  bool get showsService =>
      this != ReportManagerItem.paymentSummary &&
      this != ReportManagerItem.doctorAppointment;
  bool get directPdf => this == ReportManagerItem.paymentRegister;
  String get reportFile => switch (this) {
    ReportManagerItem.paymentReceive => 'PAYMENT_RECEIVED.rep',
    ReportManagerItem.paymentRegister => 'PAYMENT_RECEIVED_REGISTER.rep',
    ReportManagerItem.paymentSummary => 'PAYMENT_RECEIVED_SUMMERY.rep',
    ReportManagerItem.doctorPayment => 'DOC_WISE_PAT_APP_PAY_SUMMERY.rep',
    ReportManagerItem.doctorAppointment => 'APPOINTMENT_SUMMARY.rep',
  };
  String get dataEndpoint => switch (this) {
    ReportManagerItem.paymentReceive => 'getPaymentRcvData',
    ReportManagerItem.paymentSummary => 'getPaymentRcvSumData',
    ReportManagerItem.doctorPayment => 'getDocWisePayData',
    ReportManagerItem.doctorAppointment => 'getDocWiseAppData',
    ReportManagerItem.paymentRegister =>
      throw const AppFailure('This report opens directly as a PDF.'),
  };
}

bool reportHasPdf(Uri centerApi) => nativeReportManagerItems(
  centerApi,
).contains(ReportManagerItem.paymentRegister);
void reportRequire(bool condition, String message) {
  if (!condition) throw AppFailure(message, kind: FailureKind.invalidData);
}

bool reportId(String id) => RegExp(r'^[A-Za-z0-9_.-]{1,100}$').hasMatch(id);

class ReportChoice {
  const ReportChoice(this.id, this.name);
  static const clear = ReportChoice('', '...');
  final String id, name;
  bool get isClear => id.isEmpty;
}

class ReportCatalogue {
  const ReportCatalogue({
    required this.departments,
    required this.units,
    required this.services,
    required this.pdf,
  });
  final List<ReportChoice> departments, units, services;
  final ReportServerConfig pdf;
}

/// ReportView owns these selections. No global/static picker state is shared.
class ReportParameterDraft {
  ReportParameterDraft(this.item, DateTime today)
    : begin = DateTime(today.year, today.month),
      end = dateOnly(today),
      unitEnabled = !item.showsDoctor,
      serviceEnabled = !item.showsDoctor;
  final ReportManagerItem item;
  DateTime? begin, end;
  bool beginPicked = false, endPicked = false, invalidRange = false;
  ReportChoice? department, unit, doctor, service;
  bool unitEnabled, doctorEnabled = false, serviceEnabled;
  String dateText(bool first) {
    final date = first ? begin : end;
    if (date == null) return '';
    final value = oracleDate(date);
    if (first ? beginPicked : endPicked) return value;
    return '${value.substring(0, 4)}${value.substring(4, 6).toLowerCase()}${value.substring(6)}';
  }

  void chooseDate(bool first, DateTime value) {
    final date = dateOnly(value);
    invalidRange =
        first
            ? end != null && date.isAfter(end!)
            : begin != null && date.isBefore(begin!);
    if (first) {
      begin = invalidRange ? null : date;
      beginPicked = true;
    } else {
      end = invalidRange ? null : date;
      endPicked = true;
    }
  }

  bool enabled(ReportParameter p) => switch (p) {
    ReportParameter.department => true,
    ReportParameter.unit => unitEnabled,
    ReportParameter.doctor => item.showsDoctor && doctorEnabled,
    ReportParameter.service => item.showsService && serviceEnabled,
  };
  ReportChoice? selected(ReportParameter p) => switch (p) {
    ReportParameter.department => department,
    ReportParameter.unit => unit,
    ReportParameter.doctor => doctor,
    ReportParameter.service => service,
  };

  /// Descendants clear before the dependent GET, including when clearing a parent.
  ReportParameter? choose(ReportParameter p, ReportChoice choice) {
    reportRequire(enabled(p), 'Please select the preceding report filter.');
    final value = choice.isClear ? null : choice;
    switch (p) {
      case ReportParameter.department:
        department = value;
        unit = doctor = service = null;
        unitEnabled = !item.showsDoctor;
        doctorEnabled = false;
        serviceEnabled = !item.showsDoctor;
        return ReportParameter.unit;
      case ReportParameter.unit:
        unit = value;
        doctor = service = null;
        doctorEnabled = false;
        serviceEnabled = !item.showsDoctor;
        return item.showsDoctor
            ? ReportParameter.doctor
            : item.showsService
            ? ReportParameter.service
            : null;
      case ReportParameter.doctor:
        doctor = value;
        service = null;
        serviceEnabled = false;
        return item == ReportManagerItem.doctorPayment
            ? ReportParameter.service
            : null;
      case ReportParameter.service:
        service = value;
        return null;
    }
  }

  void loaded(ReportParameter p) {
    switch (p) {
      case ReportParameter.unit:
        unitEnabled =
            item != ReportManagerItem.doctorPayment || department != null;
      case ReportParameter.doctor:
        doctorEnabled = true;
      case ReportParameter.service:
        serviceEnabled = true;
      case ReportParameter.department:
        break;
    }
  }

  ReportRequest snapshot() {
    reportRequire(
      begin != null && end != null && !begin!.isAfter(end!),
      'Please Select Date Range',
    );
    reportRequire(
      item != ReportManagerItem.doctorPayment || doctor != null,
      'Please Select Doctor',
    );
    return ReportRequest(
      item: item,
      begin: begin!,
      end: end!,
      department: department,
      unit: unit,
      doctor: doctor,
      service: service,
      beginText: dateText(true),
      endText: dateText(false),
    );
  }
}

class ReportRequest {
  ReportRequest({
    required this.item,
    required DateTime begin,
    required DateTime end,
    this.department,
    this.unit,
    this.doctor,
    this.service,
    String? beginText,
    String? endText,
  }) : begin = dateOnly(begin),
       end = dateOnly(end),
       beginText = beginText ?? oracleDate(begin),
       endText = endText ?? oracleDate(end);
  final ReportManagerItem item;
  final DateTime begin, end;
  final String beginText, endText;
  final ReportChoice? department, unit, doctor, service;
  void validate() {
    reportRequire(!begin.isAfter(end), 'Please Select Date Range');
    reportRequire(
      beginText.toUpperCase() == oracleDate(begin) &&
          endText.toUpperCase() == oracleDate(end),
      'Please Select Date Range',
    );
    for (final value in [department, unit, doctor, service]) {
      reportRequire(
        value == null || reportId(value.id),
        'Please select a report filter from the list.',
      );
    }
    reportRequire(
      item != ReportManagerItem.doctorPayment || doctor != null,
      'Please Select Doctor',
    );
  }

  Map<String, String> get query {
    validate();
    return switch (item) {
      ReportManagerItem.paymentReceive => {
        'deptdid': department?.id ?? '',
        'deptsid': unit?.id ?? '',
        'pfnid': service?.id ?? '',
        'b_date': beginText,
        'e_date': endText,
      },
      ReportManagerItem.paymentSummary => {
        'deptdid': department?.id ?? '',
        'deptsid': unit?.id ?? '',
        'b_date': beginText,
        'e_date': endText,
      },
      ReportManagerItem.doctorPayment => {
        'p_doc_id': doctor?.id ?? '',
        'p_pfn_id': service?.id ?? '',
        'p_begin_date': beginText,
        'p_end_date': endText,
      },
      ReportManagerItem.doctorAppointment => {
        'p_deptd_id': department?.id ?? '',
        'p_depts_id': unit?.id ?? '',
        'p_doc_id': doctor?.id ?? '',
        'p_begin_date': beginText,
        'p_end_date': endText,
      },
      ReportManagerItem.paymentRegister =>
        throw const AppFailure('This report opens directly as a PDF.'),
    };
  }

  String get documentName =>
      '${item.title}_$beginText to $endText'.replaceAll(' ', '_');
}

/// Oracle rwservlet uses literal '+' separators. Never log its server key.
class ReportServerConfig {
  const ReportServerConfig({
    this.server = '',
    this.path = '',
    this.link = '',
    this.center = '',
  });
  factory ReportServerConfig.fromData(JsonMap row) => ReportServerConfig(
    server: nativeText(row['lic_rep_server_port']).trim(),
    path: nativeText(row['lic_rep_path']),
    link: nativeText(row['lic_rep_hrs_link']),
    center: nativeText(row['cid_id']).trim(),
  );
  final String server, path, link, center;
  Uri url(ReportRequest request) {
    request.validate();
    final origin = Uri.tryParse('http://$server');
    reportRequire(
      origin != null &&
          origin.host.isNotEmpty &&
          origin.userInfo.isEmpty &&
          (origin.path.isEmpty || origin.path == '/') &&
          !origin.hasQuery &&
          !origin.hasFragment &&
          !RegExp(r'[\s/\\?#@]').hasMatch(server),
      'The report server address is unavailable. Please contact your centre.',
    );
    reportRequire(
      path.isNotEmpty &&
          link.isNotEmpty &&
          !RegExp(r'[\r\n?#]').hasMatch('$path$link'),
      'The report server configuration is unavailable. Please contact your centre.',
    );
    if (!request.item.showsDoctor) {
      reportRequire(
        center.isEmpty || reportId(center),
        'The report centre identifier is invalid.',
      );
    }
    String arg(String key, String value) =>
        '+$key=${Uri.encodeComponent(value)}';
    final query =
        StringBuffer(link)
          ..write(arg('report', '$path${request.item.reportFile}'))
          ..write(arg('BEGIN_DATE', request.beginText))
          ..write(arg('END_DATE', request.endText));
    if (request.item == ReportManagerItem.doctorPayment) {
      query
        ..write(arg('UNIT', request.unit?.id ?? ''))
        ..write(arg('DOC', request.doctor?.id ?? ''))
        ..write(arg('PFN', request.service?.id ?? ''));
    } else if (request.item == ReportManagerItem.doctorAppointment) {
      query.write(arg('DOC', request.doctor?.id ?? ''));
    } else {
      query
        ..write(arg('DEPTD', request.department?.id ?? ''))
        ..write(arg('DEPTS', request.unit?.id ?? ''))
        ..write(arg('PFN', request.service?.id ?? ''))
        ..write(arg('CIDID', center));
    }
    return Uri.parse('${origin!.replace(path: '/reports/rwservlet')}?$query');
  }
}

String reportGrouped(int value) {
  final raw = value.abs().toString(), out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < raw.length; ++i) {
    if (i > 0 && (raw.length - i) % 3 == 0) out.write(',');
    out.write(raw[i]);
  }
  return out.toString();
}

class ReportTableRow {
  ReportTableRow(Iterable<String> cells, {required this.groupEnd})
    : cells = List.unmodifiable(cells);
  final List<String> cells;
  final bool groupEnd;
}

class ReportTable {
  ReportTable._(
    this.item,
    Iterable<ReportTableRow> rows,
    Iterable<String> totals,
    this.designation,
  ) : rows = List.unmodifiable(rows),
      totals = List.unmodifiable(totals);
  final ReportManagerItem item;
  final List<ReportTableRow> rows;
  final List<String> totals;
  final String designation;
  List<String> get headers => switch (item) {
    ReportManagerItem.paymentReceive => [
      'Department Name',
      'Unit Name',
      'Service Name',
      'Quantity',
      'Rate',
      'Amount',
    ],
    ReportManagerItem.paymentSummary => [
      'Department Name',
      'Unit Name',
      'Unit Amount',
    ],
    ReportManagerItem.doctorPayment => [
      'Appointment Date',
      'Date Total (Regular)',
      'Date Total (ETS)',
      'Date Total',
    ],
    ReportManagerItem.doctorAppointment => [
      'Unit Name',
      'Doctor/Therapist Name',
      'Regular Time',
      'Extra Time',
      'Blocked',
      'Blank',
    ],
    ReportManagerItem.paymentRegister => const [],
  };
  List<double>? get fixedWidths => switch (item) {
    ReportManagerItem.paymentReceive => [113, 100, 110, 60, 60, 100],
    ReportManagerItem.doctorAppointment => [103, 110, 80, 80, 80, 80],
    _ => null,
  };
  List<int> get weights =>
      item == ReportManagerItem.paymentSummary
          ? [35, 35, 30]
          : [25, 25, 25, 25];
  int get footerSpan => headers.length - totals.length;
  String get footerLabel =>
      item == ReportManagerItem.paymentReceive ||
              item == ReportManagerItem.paymentSummary
          ? 'Total Amount'
          : 'Grand Total';
  factory ReportTable.fromData(ReportManagerItem item, List<JsonMap> data) {
    reportRequire(!item.directPdf, 'This report opens directly as a PDF.');
    final rows = <ReportTableRow>[],
        sums = List<int>.filled(
          item == ReportManagerItem.doctorPayment
              ? 3
              : item == ReportManagerItem.doctorAppointment
              ? 4
              : 1,
          0,
        );
    String t(JsonMap row, String key) => nativeText(row[key]);
    String n(JsonMap row, String key) => nativeText(row[key], '0');
    int number(String value) {
      final parsed = int.tryParse(value.trim());
      reportRequire(
        parsed != null,
        'The server returned an invalid report total.',
      );
      return parsed!;
    }

    var designation = '';
    for (var i = 0; i < data.length; ++i) {
      final row = data[i],
          previous = i == 0 ? null : data[i - 1],
          next = i + 1 == data.length ? null : data[i + 1];
      final cells = <String>[];
      var groupEnd = false;
      if (item == ReportManagerItem.paymentReceive ||
          item == ReportManagerItem.paymentSummary) {
        final sameDept =
            previous != null &&
            t(row, 'deptd_name') == t(previous, 'deptd_name');
        final sameUnit =
            sameDept && t(row, 'depts_name') == t(previous, 'depts_name');
        cells.addAll([
          sameDept ? '〃' : t(row, 'deptd_name'),
          sameUnit ? '〃' : t(row, 'depts_name'),
        ]);
        if (item == ReportManagerItem.paymentReceive) {
          final sameService =
              sameUnit && t(row, 'pfn_fee_name') == t(previous, 'pfn_fee_name');
          cells.addAll([
            sameService ? '〃' : t(row, 'pfn_fee_name'),
            t(row, 'tot_qty'),
            t(row, 'prd_rate'),
          ]);
        }
        final amount = t(row, 'tot_amt');
        cells.add(amount);
        sums[0] += number(amount);
        groupEnd =
            next == null || t(row, 'deptd_name') != t(next, 'deptd_name');
      } else if (item == ReportManagerItem.doctorPayment) {
        designation = t(row, 'designation');
        cells.add(t(row, 'app_date1'));
        for (final e
            in ['date_total_reg', 'date_total_ets', 'date_total'].indexed) {
          final value = n(row, e.$2);
          cells.add(value);
          sums[e.$1] += number(value);
        }
      } else {
        cells.addAll([
          previous != null && t(row, 'depts_name') == t(previous, 'depts_name')
              ? '〃'
              : t(row, 'depts_name'),
          t(row, 'doc_name'),
        ]);
        for (final e
            in [
              'regular_count',
              'extra_count',
              'block_count',
              'blank_count',
            ].indexed) {
          final value = n(row, e.$2);
          cells.add(value);
          sums[e.$1] += number(value);
        }
        groupEnd =
            next == null || t(row, 'depts_name') != t(next, 'depts_name');
      }
      rows.add(ReportTableRow(cells, groupEnd: groupEnd));
    }
    return ReportTable._(
      item,
      rows,
      sums.map(
        (v) =>
            item != ReportManagerItem.doctorAppointment &&
                    !(item == ReportManagerItem.doctorPayment && data.isEmpty)
                ? '৳ ${reportGrouped(v)}'
                : '$v',
      ),
      designation,
    );
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import 'native_voucher_controls.dart';
import 'voucher_models.dart';

const _mainWidths = <double>[84, 111, 221, 161, 101, 101];
const _reportWidths = <double>[164, 111, 161, 111, 111];
List<double> _widths(BuildContext context, List<double> values) {
  final factor = math.max(
    1.0,
    MediaQuery.textScalerOf(context).scale(12) / 12 / 1.3,
  );
  return values.map((w) => w * factor).toList();
}

Widget _header(
  BuildContext context,
  List<double> widths,
  List<String> names,
  double s, {
  bool compact = false,
}) {
  final style = vtText(10, s, color: Colors.white),
      height = List.generate(
        names.length,
        (i) => voucherTextHeight(
          context,
          names[i],
          widths[i],
          style,
          vertical: compact ? 5 : 8,
          minimum: compact ? 22 : 24,
        ),
      ).reduce(math.max);
  return DecoratedBox(
    decoration: const BoxDecoration(
      color: DocColors.primary,
      border: Border(bottom: BorderSide(color: Colors.black)),
    ),
    child: Row(
      children: [
        for (var i = 0; i < names.length; i++)
          voucherCell(
            width: widths[i],
            height: height,
            text: names[i],
            style: style,
            color: DocColors.primary,
            line: Colors.white,
            border: i < names.length - 1,
          ),
      ],
    ),
  );
}

class _MeasuredVoucher {
  _MeasuredVoucher(this.entry, this.heights);
  final VoucherEntry entry;
  final List<double> heights;
  double get height => heights.fold(0, (sum, h) => sum + h);
}

_MeasuredVoucher _measure(
  BuildContext context,
  VoucherEntry entry,
  List<double> widths,
  double s,
) {
  final style = vtText(10, s), lines = entry.lines;
  final heights = <double>[
    for (final line in lines)
      [
        voucherTextHeight(
          context,
          line.account,
          widths[3],
          style,
          vertical: 12 * s,
        ),
        voucherTextHeight(
          context,
          line.debitText,
          widths[4],
          style,
          vertical: 12 * s,
        ),
        voucherTextHeight(
          context,
          line.creditText,
          widths[5],
          style,
          vertical: 12 * s,
        ),
      ].reduce(math.max),
  ];
  final metadata = math.max(
    voucherTextHeight(context, entry.number, widths[1], vtText(9, s)),
    voucherTextHeight(context, entry.particulars, widths[2], vtText(8, s)),
  );
  if (heights.isEmpty) {
    heights.add(metadata);
  }
  final total = heights.fold(0.0, (sum, h) => sum + h);
  if (total < metadata) heights[heights.length - 1] += metadata - total;
  return _MeasuredVoucher(entry, heights);
}

class NativeVoucherTable extends StatelessWidget {
  const NativeVoucherTable({
    super.key,
    required this.data,
    required this.horizontal,
    required this.onEntry,
    required this.enabled,
  });
  final VoucherData data;
  final ScrollController horizontal;
  final ValueChanged<VoucherEntry> onEntry;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context),
        widths = _widths(context, _mainWidths),
        totalWidth = widths.reduce((a, b) => a + b);
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        key: const Key('vt_horizontal'),
        controller: horizontal,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(context, widths, [
                'Date',
                'Voucher No',
                'Particulars',
                'Account Details',
                'Debit',
                'Credit',
              ], s),
              for (
                var dayIndex = 0;
                dayIndex < data.days.length;
                dayIndex++
              ) ...[
                Builder(
                  builder: (context) {
                    final day = data.days[dayIndex],
                        measured =
                            day.entries
                                .map((e) => _measure(context, e, widths, s))
                                .toList();
                    final height =
                        measured.fold(0.0, (sum, m) => sum + m.height) +
                        math.max(0, measured.length - 1);
                    return ColoredBox(
                      color: vtDisabled,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          voucherCell(
                            width: widths[0],
                            height: height,
                            text: day.date,
                            style: vtText(9, s, color: Colors.black),
                          ),
                          SizedBox(
                            width: totalWidth - widths[0],
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < measured.length; i++) ...[
                                  _entryRow(context, measured[i], widths, s),
                                  if (i < measured.length - 1)
                                    const Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: Colors.black,
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (dayIndex < data.days.length - 1)
                  const Divider(height: 1, thickness: 1, color: Colors.black),
              ],
              if (data.days.isNotEmpty) _footer(context, widths, s),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entryRow(
    BuildContext context,
    _MeasuredVoucher measured,
    List<double> widths,
    double s,
  ) {
    final entry = measured.entry, h = measured.height;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        voucherCell(
          width: widths[1],
          height: h,
          text: entry.number,
          style: vtText(
            9,
            s,
            color: entry.actionable ? DocColors.greenSea : vtTextColor,
          ),
          onTap: enabled && entry.actionable ? () => onEntry(entry) : null,
          key: ValueKey('vt_voucher_${entry.date}_${entry.number}'),
        ),
        voucherCell(
          width: widths[2],
          height: h,
          text: entry.particulars,
          style: vtText(8, s),
        ),
        SizedBox(
          width: widths[3] + widths[4] + widths[5],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < measured.heights.length; i++)
                SizedBox(
                  height: measured.heights[i],
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            voucherCell(
                              width: widths[3],
                              height:
                                  measured.heights[i] -
                                  ((i < measured.heights.length - 1) ? 1 : 0),
                              text:
                                  entry.lines.isEmpty
                                      ? ''
                                      : entry.lines[i].account,
                              style: vtText(10, s),
                            ),
                            voucherCell(
                              width: widths[4],
                              height:
                                  measured.heights[i] -
                                  ((i < measured.heights.length - 1) ? 1 : 0),
                              text:
                                  entry.lines.isEmpty
                                      ? ''
                                      : entry.lines[i].debitText,
                              style: vtText(10, s),
                            ),
                            voucherCell(
                              width: widths[5],
                              height:
                                  measured.heights[i] -
                                  ((i < measured.heights.length - 1) ? 1 : 0),
                              text:
                                  entry.lines.isEmpty
                                      ? ''
                                      : entry.lines[i].creditText,
                              style: vtText(10, s),
                              border: false,
                            ),
                          ],
                        ),
                      ),
                      if (i < measured.heights.length - 1)
                        const VoucherDashes(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footer(BuildContext context, List<double> widths, double s) {
    final prefix = widths.take(4).reduce((a, b) => a + b),
        style = vtText(11, s, family: 'Poppins', color: Colors.black);
    final height = math.max(
      34.0,
      math.max(
        voucherTextHeight(context, data.debit.currency, widths[4], style),
        voucherTextHeight(context, data.credit.currency, widths[5], style),
      ),
    );
    return Column(
      children: [
        const Divider(height: 1, thickness: 1, color: Colors.black),
        Row(
          children: [
            Container(
              width: prefix,
              height: height,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Colors.black)),
              ),
              child: Text('Total Amount', style: style),
            ),
            voucherCell(
              width: widths[4],
              height: height,
              text: data.debit.currency,
              key: const Key('vt_total_debit'),
              style: style,
            ),
            voucherCell(
              width: widths[5],
              height: height,
              text: data.credit.currency,
              key: const Key('vt_total_credit'),
              style: style,
              border: false,
            ),
          ],
        ),
      ],
    );
  }
}

class NativeVoucherReportTable extends StatelessWidget {
  const NativeVoucherReportTable({
    super.key,
    required this.report,
    required this.horizontal,
    this.formatAmount,
  });
  final VoucherReport report;
  final ScrollController horizontal;
  final String Function(VtMoney)? formatAmount;
  @override
  Widget build(BuildContext context) {
    final s = adminAppointmentScale(context),
        widths = _widths(context, _reportWidths),
        style = vtText(9, s),
        totalWidth = widths.reduce((a, b) => a + b);
    final debitLabel = formatAmount?.call(report.debit) ?? report.debit.grouped;
    final creditLabel =
        formatAmount?.call(report.credit) ?? report.credit.grouped;
    final heights = <double>[
      for (final line in report.lines)
        [
          voucherTextHeight(
            context,
            line.accountCode,
            widths[1],
            style,
            vertical: 7,
            minimum: 22,
          ),
          voucherTextHeight(
            context,
            line.accountName,
            widths[2],
            style,
            vertical: 7,
            minimum: 22,
          ),
          voucherTextHeight(
            context,
            line.debitText,
            widths[3],
            style,
            vertical: 7,
            minimum: 22,
          ),
          voucherTextHeight(
            context,
            line.creditText,
            widths[4],
            style,
            vertical: 7,
            minimum: 22,
          ),
        ].reduce(math.max),
    ];
    var height = heights.fold(0.0, (sum, h) => sum + h);
    final narrationHeight = voucherTextHeight(
      context,
      report.narration,
      widths[0],
      style,
    );
    if (heights.isNotEmpty && height < narrationHeight) {
      heights[heights.length - 1] += narrationHeight - height;
      height = narrationHeight;
    }
    final footerStyle = vtText(11, s, color: Colors.black),
        footerHeight = math.max(
          24.0,
          math.max(
            voucherTextHeight(
              context,
              debitLabel,
              widths[3],
              footerStyle,
              vertical: 5,
              minimum: 24,
            ),
            voucherTextHeight(
              context,
              creditLabel,
              widths[4],
              footerStyle,
              vertical: 5,
              minimum: 24,
            ),
          ),
        );
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        key: const Key('vt_report_horizontal'),
        controller: horizontal,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(
                context,
                widths,
                ['Narration', 'A/C No', 'Head of Account', 'Debit', 'Credit'],
                s,
                compact: true,
              ),
              ColoredBox(
                color: vtDisabled,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    voucherCell(
                      width: widths[0],
                      height: height,
                      text: report.narration,
                      style: style,
                    ),
                    SizedBox(
                      width: totalWidth - widths[0],
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < report.lines.length; i++)
                            DecoratedBox(
                              decoration:
                                  i < report.lines.length - 1
                                      ? const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Color(0xffd4d4d4),
                                          ),
                                        ),
                                      )
                                      : const BoxDecoration(),
                              child: Row(
                                children: [
                                  voucherCell(
                                    width: widths[1],
                                    height: heights[i],
                                    text: report.lines[i].accountCode,
                                    style: style,
                                  ),
                                  voucherCell(
                                    width: widths[2],
                                    height: heights[i],
                                    text: report.lines[i].accountName,
                                    style: style,
                                  ),
                                  voucherCell(
                                    width: widths[3],
                                    height: heights[i],
                                    text: report.lines[i].debitText,
                                    style: style,
                                  ),
                                  voucherCell(
                                    width: widths[4],
                                    height: heights[i],
                                    text: report.lines[i].creditText,
                                    style: style,
                                    border: false,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Colors.black),
              Row(
                children: [
                  Container(
                    width: widths.take(3).reduce((a, b) => a + b),
                    height: footerHeight,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('Total :', style: footerStyle),
                  ),
                  voucherCell(
                    width: widths[3],
                    height: footerHeight,
                    text: debitLabel,
                    key: const Key('vt_report_debit'),
                    style: footerStyle,
                    border: false,
                  ),
                  voucherCell(
                    width: widths[4],
                    height: footerHeight,
                    text: creditLabel,
                    key: const Key('vt_report_credit'),
                    style: footerStyle,
                    border: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

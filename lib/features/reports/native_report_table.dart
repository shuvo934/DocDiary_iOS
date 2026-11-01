import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'native_report_controls.dart';
import 'report_manager_menu.dart';
import 'report_manager_models.dart';

/// Native table widths, group marks and totals. Header, rows and footer share
/// one horizontal scroll position for the two wide reports.
class NativeReportTable extends StatelessWidget {
  const NativeReportTable({
    super.key,
    required this.table,
    required this.request,
  });
  final ReportTable table;
  final ReportRequest request;
  @override
  Widget build(BuildContext context) {
    final scale = reportScale(context);
    return Column(
      children: [
        if (table.item == ReportManagerItem.doctorPayment)
          for (final e
              in <String, String>{
                'Doctor/Therapist Name: ': request.doctor?.name ?? '',
                'Designation: ': table.designation,
                'Unit Name: ': request.unit?.name ?? '',
                'Department: ': request.department?.name ?? '',
              }.entries)
            Padding(
              padding: EdgeInsets.fromLTRB(4 * scale, 4 * scale, 4 * scale, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      e.key,
                      style: reportText(
                        10,
                        scale,
                        family: 'Baloo',
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Text(
                      e.value,
                      style: reportText(10, scale, family: 'Baloo'),
                    ),
                  ),
                ],
              ),
            ),
        Flexible(
          fit: FlexFit.loose,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              4 * scale,
              8 * scale,
              4 * scale,
              4 * scale,
            ),
            child: Material(
              color: Colors.white,
              elevation: 1,
              borderRadius: BorderRadius.circular(8 * scale),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final fixed = table.fixedWidths;
                  final widths =
                      fixed ??
                      [
                        for (final weight in table.weights)
                          constraints.maxWidth * weight / 100,
                      ];
                  final width = widths.fold<double>(0, (a, b) => a + b);
                  final content = SizedBox(
                    width: width,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _row(context, table.headers, widths, header: true),
                        Container(width: width, height: 1, color: Colors.black),
                        Flexible(
                          fit: FlexFit.loose,
                          child: ListView.separated(
                            key: const Key('report_table_vertical'),
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: table.rows.length + 1,
                            separatorBuilder:
                                (_, index) =>
                                    index + 1 == table.rows.length
                                        ? const SizedBox.shrink()
                                        : SizedBox(
                                          height: 1,
                                          child: ColoredBox(
                                            color:
                                                table.rows[index].groupEnd
                                                    ? Colors.black
                                                    : const Color(0xff95a5a6),
                                          ),
                                        ),
                            itemBuilder: (context, index) {
                              if (index == table.rows.length) {
                                return _row(
                                  context,
                                  [table.footerLabel, ...table.totals],
                                  [
                                    widths
                                        .take(table.footerSpan)
                                        .fold<double>(0, (a, b) => a + b),
                                    ...widths.skip(table.footerSpan),
                                  ],
                                  footer: true,
                                  rowKey: const Key('report_table_total'),
                                );
                              }
                              return _row(
                                context,
                                table.rows[index].cells,
                                widths,
                                rowKey: Key('report_table_row_$index'),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                  return fixed == null
                      ? content
                      : SingleChildScrollView(
                        key: const Key('report_table_horizontal'),
                        scrollDirection: Axis.horizontal,
                        child: content,
                      );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    List<String> cells,
    List<double> widths, {
    bool header = false,
    bool footer = false,
    Key? rowKey,
  }) {
    final scale = reportScale(context);
    return ColoredBox(
      key: rowKey,
      color:
          header
              ? DocColors.primary
              : footer
              ? Colors.white
              : const Color(0xfff5f5f5),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cells.length; ++i)
              Container(
                width: widths[i],
                padding: EdgeInsets.symmetric(
                  horizontal: 4 * scale,
                  vertical: 2 * scale,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    right:
                        i + 1 < cells.length
                            ? BorderSide(
                              color: header ? Colors.white : Colors.black,
                            )
                            : BorderSide.none,
                    top:
                        footer && table.rows.isNotEmpty
                            ? const BorderSide(color: Colors.black)
                            : BorderSide.none,
                  ),
                ),
                child: Align(
                  alignment:
                      footer && i == 0
                          ? Alignment.centerLeft
                          : Alignment.center,
                  child: Text(
                    cells[i],
                    textAlign:
                        footer && i == 0 ? TextAlign.left : TextAlign.center,
                    style: reportText(
                      footer
                          ? table.item == ReportManagerItem.paymentSummary
                              ? 12
                              : 11
                          : 9,
                      scale,
                      family: footer ? 'Poppins' : 'Roboto',
                      weight: FontWeight.w700,
                      color:
                          header
                              ? Colors.white
                              : footer
                              ? Colors.black
                              : const Color(0xff6c6e6f),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

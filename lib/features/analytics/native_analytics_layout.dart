import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../dashboard/native_admin_line_chart.dart' show chartRoboto;
import 'analytics_models.dart';
import 'native_analytics_charts.dart';

const _headingGray = Color(0xff6c6e6f);
const _lightTeal = Color(0xff81cbdc);
const _lightOrange = Color(0xffffbe3d);

TextStyle _titleStyle(double size, Color color, {String font = 'Poppins'}) =>
    TextStyle(
      fontFamily: font,
      fontWeight: FontWeight.w700,
      fontSize: size,
      color: color,
    );

class AnalyticsHeading extends StatelessWidget {
  const AnalyticsHeading(
    this.text, {
    super.key,
    this.main = false,
    this.sub = false,
    this.topPadding,
  });
  final String text;
  final bool main, sub;
  final double? topPadding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      main ? 4 : 0,
      topPadding ?? (main ? 17 : 14),
      0,
      5,
    ),
    child: Align(
      alignment: main ? Alignment.centerLeft : Alignment.center,
      child: Text(
        text,
        textAlign: main ? TextAlign.left : TextAlign.center,
        style: _titleStyle(
          main
              ? 16
              : sub
              ? 12.5
              : 14,
          main
              ? analyticsOrange
              : sub
              ? DocColors.primary
              : DocColors.greenSea,
        ),
      ),
    ),
  );
}

class AnalyticsDateField extends StatelessWidget {
  const AnalyticsDateField({
    super.key,
    required this.range,
    required this.onTap,
  });

  final AnalyticsRange range;
  final VoidCallback? onTap;

  String _date(DateTime value) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${value.day.toString().padLeft(2, '0')}-'
        '${months[value.month - 1]}-'
        '${(value.year % 100).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(5, 3, 5, 10),
      child: Row(
        children: [
          Flexible(
            child: Text(
              range.first == range.last
                  ? _date(range.first)
                  : '${_date(range.first)}  ---  ${_date(range.last)}',
              style: chartRoboto(
                15,
                color: _headingGray,
                weight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.arrow_drop_down,
            color: DocColors.greenSea,
            size: 24,
          ),
        ],
      ),
    ),
  );
}

class _Metric {
  const _Metric(this.label, this.value, this.first, this.last);
  final String label;
  final int value;
  final Color first, last;
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(this.items);
  final List<_Metric> items;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 7, 2, 17),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i != 0) const SizedBox(width: 10),
            Expanded(child: _MetricCard(items[i])),
          ],
        ],
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.metric);
  final _Metric metric;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 2,
    borderRadius: BorderRadius.circular(10),
    clipBehavior: Clip.antiAlias,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [metric.first, metric.last],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(5, 13, 5, 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              metric.label,
              textAlign: TextAlign.center,
              style: _titleStyle(13, Colors.white),
            ),
            const SizedBox(height: 7),
            Text(
              '${metric.value}',
              textAlign: TextAlign.center,
              style: _titleStyle(28, Colors.white, font: 'Baloo'),
            ),
          ],
        ),
      ),
    ),
  );
}

class AnalyticsLoginContent extends StatelessWidget {
  const AnalyticsLoginContent(this.data, {super.key});
  final AnalyticsLogin data;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _MetricRow([
        _Metric(
          'ALL TIME LOGIN',
          data.trend.total(0),
          DocColors.primary,
          _lightTeal,
        ),
        _Metric('UNIQUE LOGIN', data.unique, analyticsOrange, _lightOrange),
      ]),
      AnalyticsTrendChart(trend: data.trend, series: analyticsLoginSeries),
    ],
  );
}

class AnalyticsAppointmentContent extends StatelessWidget {
  const AnalyticsAppointmentContent(this.data, {super.key});
  final AnalyticsAppointments data;

  Widget _group(String title, AnalyticsTrend trend) => Column(
    children: [
      AnalyticsHeading(title, sub: true),
      _MetricRow([
        _Metric('TOTAL', trend.total(0), DocColors.primary, _lightTeal),
        _Metric('CONFIRMED', trend.total(1), analyticsOrange, _lightOrange),
        _Metric('UNCONFIRMED', trend.total(2), analyticsGray, analyticsGray),
      ]),
      AnalyticsTrendChart(trend: trend, series: analyticsAppointmentSeries),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _group('APPOINTMENT INITIALIZATION', data.initialized),
      _group('APPOINTMENT SCHEDULE', data.scheduled),
    ],
  );
}

class AnalyticsPaymentContent extends StatelessWidget {
  const AnalyticsPaymentContent({
    super.key,
    required this.data,
    required this.selected,
    required this.reasons,
    required this.loading,
    required this.onSelect,
  });

  final AnalyticsPayments data;
  final AnalyticsCardSelection? selected;
  final List<AnalyticsReason> reasons;
  final bool loading;
  final ValueChanged<AnalyticsCardSelection?> onSelect;

  @override
  Widget build(BuildContext context) {
    final selection = selected;
    return Column(
      children: [
        _MetricRow([
          _Metric(
            'TOTAL PAYMENT INITIALIZE',
            data.trend.total(0),
            analyticsBlue,
            const Color(0xff4080c0),
          ),
        ]),
        _MetricRow([
          _Metric(
            'COMPLETED',
            data.trend.total(1),
            DocColors.primary,
            DocColors.greenSea,
          ),
          _Metric('FAILED', data.trend.total(2), analyticsRed, analyticsRose),
          _Metric(
            'NO RESULT',
            data.trend.total(3),
            analyticsGray,
            analyticsGray,
          ),
        ]),
        AnalyticsTrendChart(
          trend: data.trend,
          series: analyticsPaymentSeries,
          tall: true,
        ),
        const AnalyticsHeading('CARD WISE PAYMENT', sub: true),
        const SizedBox(height: 7),
        AnalyticsCardChart(
          cards: data.cards,
          selected: selected,
          onSelect: onSelect,
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(22),
            child: CircularProgressIndicator(
              key: Key('analytics_reason_loading'),
            ),
          ),
        if (selection != null && reasons.isNotEmpty) ...[
          AnalyticsHeading(
            '${selection.card.name} - ${selection.status.label} Status\n'
            'Total : ${selection.card.count(selection.status)}',
            key: const Key('analytics_reason_heading'),
          ),
          const SizedBox(height: 7),
          _AnalyticsTable(
            headers: const ['Result Type', 'Result Description', 'Total'],
            weights: const [30, 53, 17],
            rows: [
              for (final reason in reasons)
                [
                  TextSpan(
                    text: reason.type,
                    style: const TextStyle(color: Colors.black),
                  ),
                  TextSpan(text: reason.description),
                  TextSpan(text: '${reason.count}'),
                ],
            ],
          ),
        ],
        if (data.cards.isNotEmpty) ...[
          const SizedBox(height: 15),
          _AnalyticsTable(
            key: const Key('analytics_card_summary'),
            headers: const [
              'CARD Name',
              'Total',
              'Completed',
              'Failed',
              'No Result',
            ],
            weights: const [26, 18.5, 18.5, 18.5, 18.5],
            rows: [
              for (final card in data.cards)
                [
                  TextSpan(
                    text: card.name,
                    style: const TextStyle(color: Colors.black),
                  ),
                  TextSpan(text: '${card.total}'),
                  for (final status in AnalyticsCardStatus.values)
                    TextSpan(
                      text: '${card.count(status)} ',
                      children: [
                        TextSpan(
                          text: '(${card.percentage(status)}%)',
                          style: TextStyle(
                            color:
                                const [
                                  DocColors.greenSea,
                                  analyticsRed,
                                  DocColors.muted,
                                ][status.index],
                          ),
                        ),
                      ],
                    ),
                ],
            ],
          ),
        ],
      ],
    );
  }
}

class _AnalyticsTable extends StatelessWidget {
  const _AnalyticsTable({
    super.key,
    required this.headers,
    required this.weights,
    required this.rows,
  });
  final List<String> headers;
  final List<double> weights;
  final List<List<TextSpan>> rows;

  TableRow _row(List<TextSpan> values, {bool header = false}) => TableRow(
    decoration: BoxDecoration(
      color: header ? DocColors.primary : const Color(0xfff3f3f3),
    ),
    children: [
      for (var i = 0; i < values.length; i++)
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
          child: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              horizontal: 4,
              vertical: header ? 9 : 4,
            ),
            decoration: BoxDecoration(
              border: Border(
                right:
                    i == values.length - 1
                        ? BorderSide.none
                        : BorderSide(
                          color: header ? Colors.white : Colors.black,
                        ),
              ),
            ),
            child: Text.rich(
              values[i],
              textAlign: TextAlign.center,
              style: chartRoboto(
                11,
                color: header ? Colors.white : _headingGray,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 2,
    clipBehavior: Clip.antiAlias,
    borderRadius: BorderRadius.circular(10),
    child: Table(
      columnWidths: {
        for (var i = 0; i < weights.length; i++) i: FlexColumnWidth(weights[i]),
      },
      border: const TableBorder(
        horizontalInside: BorderSide(color: Colors.black),
        bottom: BorderSide(color: Colors.black),
      ),
      children: [
        _row([
          for (final label in headers) TextSpan(text: label),
        ], header: true),
        for (final row in rows) _row(row),
      ],
    ),
  );
}

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../dashboard/admin_chart_models.dart' show chartCompact;
import '../dashboard/native_admin_line_chart.dart' show chartRoboto;
import '../dashboard/native_chart_geometry.dart';
import 'analytics_models.dart';

const analyticsOrange = Color(0xfffda000);
const analyticsGray = Color(0xffb2bec3);
const analyticsBlue = Color(0xff0097e6);
const analyticsRed = Color(0xffc23616);
const analyticsRose = Color(0xffcf6a87);
const _axisGray = Color(0xffa0a0a0);

class AnalyticsSeries {
  const AnalyticsSeries(this.label, this.color, this.circle);
  final String label;
  final Color color, circle;
}

const analyticsLoginSeries = [
  AnalyticsSeries('Total Login Count', DocColors.greenSea, DocColors.primary),
  AnalyticsSeries('Unique Login Count', analyticsOrange, analyticsRed),
];
const analyticsAppointmentSeries = [
  AnalyticsSeries('Total', DocColors.greenSea, DocColors.primary),
  AnalyticsSeries('Confirmed', analyticsOrange, analyticsRed),
  AnalyticsSeries('Not Confirmed', Color(0xff8f8f8f), analyticsGray),
];
const analyticsPaymentSeries = [
  AnalyticsSeries('Total', analyticsBlue, Color(0xff4080c0)),
  AnalyticsSeries('Completed', DocColors.greenSea, DocColors.primary),
  AnalyticsSeries('Failed', analyticsRed, analyticsRose),
  AnalyticsSeries('No Result', Color(0xff8f8f8f), analyticsGray),
];
const analyticsBarColors = [DocColors.primary, analyticsRose, analyticsGray];

class AnalyticsChartCard extends StatelessWidget {
  const AnalyticsChartCard({
    super.key,
    required this.child,
    required this.legend,
    this.tall = false,
  });

  final Widget child;
  final List<(String, Color)> legend;
  final bool tall;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder:
        (context, constraints) => Material(
          color: Colors.white,
          elevation: 2,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 5, 7, 19),
            child: Column(
              children: [
                SizedBox(
                  height: (constraints.maxWidth * (tall ? .65 : .55)).clamp(
                    190.0,
                    350.0,
                  ),
                  width: double.infinity,
                  child: child,
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    for (final (label, color) in legend)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: 8,
                            child: ColoredBox(color: color),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              label,
                              style: chartRoboto(9.5, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
  );
}

class AnalyticsTrendChart extends StatefulWidget {
  const AnalyticsTrendChart({
    super.key,
    required this.trend,
    required this.series,
    this.tall = false,
  });

  final AnalyticsTrend trend;
  final List<AnalyticsSeries> series;
  final bool tall;

  @override
  State<AnalyticsTrendChart> createState() => _AnalyticsTrendChartState();
}

class _AnalyticsTrendChartState extends State<AnalyticsTrendChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  final _transform = TransformationController();
  (int, int)? _selected;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    unawaited(_animation.forward());
  }

  @override
  void didUpdateWidget(covariant AnalyticsTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trend != widget.trend) {
      _selected = null;
      _transform.value = Matrix4.identity();
      unawaited(_animation.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.trend.plotPoints;
    return AnalyticsChartCard(
      tall: widget.tall,
      legend: [
        for (final series in widget.series) (series.label, series.color),
      ],
      child:
          points.isEmpty
              ? const _NoChartData()
              : LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
                  final geometry = _TrendGeometry(
                    size,
                    points,
                    widget.trend.points.length > 3,
                    scale,
                  );
                  return InteractiveViewer(
                    transformationController: _transform,
                    maxScale: 5,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        final candidate = geometry.hit(details.localPosition);
                        setState(() {
                          _selected = candidate == _selected ? null : candidate;
                        });
                      },
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, _) {
                          final selection = _selected;
                          final anchor =
                              selection == null
                                  ? null
                                  : geometry.at(
                                    selection.$1,
                                    selection.$2,
                                    _animation.value,
                                  );
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              CustomPaint(
                                painter: _TrendPainter(
                                  geometry,
                                  widget.series,
                                  _animation.value,
                                  selection,
                                ),
                              ),
                              if (selection != null && anchor != null)
                                Positioned(
                                  left: (anchor.dx - 29).clamp(
                                    0.0,
                                    math.max(0.0, size.width - 58),
                                  ),
                                  top: math.max(0, anchor.dy - 33),
                                  child: IgnorePointer(
                                    child: Container(
                                      key: const Key('analytics_line_marker'),
                                      width: 58,
                                      height: 32,
                                      decoration: const BoxDecoration(
                                        image: DecorationImage(
                                          image: AssetImage(
                                            'assets/images/c_marker.png',
                                          ),
                                          fit: BoxFit.fill,
                                        ),
                                      ),
                                      padding: const EdgeInsets.only(bottom: 6),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${points[selection.$1].values[selection.$2]}',
                                        style: chartRoboto(
                                          11,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

class _TrendGeometry {
  _TrendGeometry(Size size, this.points, this.rotated, this.scale)
    : plot = Rect.fromLTRB(
        24,
        15,
        math.max(25, size.width - 24),
        math.max(16, size.height - (rotated ? 48 : 22) * scale.clamp(1, 1.6)),
      ),
      maximum = math.max(
        1.0,
        points.expand((point) => point.values).fold(0, math.max) * 1.1,
      );
  final List<AnalyticsPoint> points;
  final bool rotated;
  final double scale, maximum;
  final Rect plot;

  Offset at(int point, int series, double phase) => Offset(
    plot.left + point / (points.length - 1) * plot.width,
    plot.bottom - points[point].values[series] / maximum * plot.height * phase,
  );

  (int, int)? hit(Offset position) {
    if (!plot.inflate(8).contains(position)) return null;
    final index = ((position.dx - plot.left) / plot.width * (points.length - 1))
        .round()
        .clamp(0, points.length - 1);
    var closest = 0;
    for (var i = 1; i < points[index].values.length; i++) {
      if ((at(index, i, 1).dy - position.dy).abs() <
          (at(index, closest, 1).dy - position.dy).abs()) {
        closest = i;
      }
    }
    return (index, closest);
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.geometry, this.series, this.phase, this.selected);
  final _TrendGeometry geometry;
  final List<AnalyticsSeries> series;
  final double phase;
  final (int, int)? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = geometry.plot;
    final points = geometry.points;
    final count = points.length;
    final visible = (count * phase).ceil().clamp(1, count);
    final scale = geometry.scale.clamp(1.0, 1.5);
    canvas.drawLine(
      plot.bottomLeft,
      plot.bottomRight,
      Paint()
        ..color = _axisGray
        ..strokeWidth = .6,
    );
    canvas.save();
    canvas.clipRect(plot.inflate(12));
    for (var s = 0; s < series.length; s++) {
      Offset point(int i) => geometry.at(i, s, phase);
      canvas.drawPath(
        nativeChartCurve(visible, count, point),
        Paint()
          ..color = series[s].color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.9,
      );
      for (var i = 0; i < visible; i++) {
        final p = point(i);
        canvas.drawCircle(p, 2.8, Paint()..color = series[s].circle);
        canvas.drawCircle(p, 1.5, Paint()..color = Colors.white);
        if (count * series.length < 100 &&
            (points[i].label.isNotEmpty || s == 0)) {
          paintNativeChartLabel(
            canvas,
            chartCompact(points[i].values[s].toDouble()),
            p.translate(0, -13 * scale),
            chartRoboto(8 * scale, color: const Color(0xff8e8ba9)),
          );
        }
      }
    }
    final selection = selected;
    if (selection != null) {
      final p = geometry.at(selection.$1, selection.$2, phase);
      final paint =
          Paint()
            ..color = const Color(0xffffbb73)
            ..strokeWidth = .6;
      canvas.drawLine(Offset(plot.left, p.dy), Offset(plot.right, p.dy), paint);
      canvas.drawLine(Offset(p.dx, plot.top), Offset(p.dx, plot.bottom), paint);
    }
    canvas.restore();
    final interval = math.max(1, (count / 6).ceil());
    for (var i = 0; i < count; i += interval) {
      if (points[i].label.isEmpty) continue;
      paintNativeChartLabel(
        canvas,
        points[i].label,
        geometry.at(i, 0, 0).translate(0, 4),
        chartRoboto(9.5 * scale, color: const Color(0xff8f8f8f)),
        rotation: geometry.rotated ? math.pi / 4 : 0,
        belowAxis: true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      geometry != oldDelegate.geometry ||
      phase != oldDelegate.phase ||
      selected != oldDelegate.selected ||
      series != oldDelegate.series;
}

class AnalyticsCardChart extends StatelessWidget {
  const AnalyticsCardChart({
    super.key,
    required this.cards,
    required this.selected,
    required this.onSelect,
  });
  final List<AnalyticsCard> cards;
  final AnalyticsCardSelection? selected;
  final ValueChanged<AnalyticsCardSelection?> onSelect;

  @override
  Widget build(BuildContext context) => AnalyticsChartCard(
    tall: true,
    legend: [
      for (final status in AnalyticsCardStatus.values)
        (status.label, analyticsBarColors[status.index]),
    ],
    child:
        cards.isEmpty
            ? const _NoChartData()
            : LayoutBuilder(
              builder: (context, constraints) {
                final geometry = _BarGeometry(constraints.biggest, cards);
                return InteractiveViewer(
                  key: ObjectKey(cards),
                  maxScale: 5,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(null),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(painter: _CardPainter(geometry, selected)),
                        for (var i = 0; i < cards.length; i++)
                          for (final status in AnalyticsCardStatus.values)
                            if (cards[i].count(status) > 0)
                              Positioned.fromRect(
                                rect: geometry.bar(i, status, hit: true),
                                child: Semantics(
                                  label:
                                      '${cards[i].name}, ${status.label}, ${cards[i].count(status)}',
                                  button: true,
                                  child: GestureDetector(
                                    key: Key(
                                      'analytics_bar_${i}_${status.name}',
                                    ),
                                    behavior: HitTestBehavior.opaque,
                                    onTap:
                                        () => onSelect((
                                          card: cards[i],
                                          status: status,
                                        )),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                );
              },
            ),
  );
}

class _BarGeometry {
  _BarGeometry(Size size, this.cards)
    : labelWidth = math.max(44.0, size.height * .44),
      maximum = math.max(
        1.0,
        cards.expand((card) => card.values.skip(1)).fold(0, math.max) * 1.09,
      ) {
    var bottomSpace = 54.0;
    final label = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    );
    for (final card in cards) {
      label.text = TextSpan(
        text: card.name,
        style: chartRoboto(9.5, color: Colors.black),
      );
      label.layout(maxWidth: labelWidth);
      bottomSpace = math.max(
        bottomSpace,
        (label.width + label.height) / math.sqrt2 + 8,
      );
    }
    label.dispose();
    plot = Rect.fromLTRB(16, 14, size.width - 10, size.height - bottomSpace);
  }

  final double labelWidth;
  late final Rect plot;
  final List<AnalyticsCard> cards;
  final double maximum;
  double get group => plot.width / cards.length;
  double center(int index) => plot.left + (index + .5) * group;

  Rect bar(int index, AnalyticsCardStatus status, {bool hit = false}) {
    final width = group * .25;
    final height = cards[index].count(status) / maximum * plot.height;
    return Rect.fromLTWH(
      center(index) + (status.index - 1) * group * .27 - width / 2,
      plot.bottom - (hit ? math.max(20, height) : height),
      width,
      hit ? math.max(20, height) : height,
    );
  }
}

class _CardPainter extends CustomPainter {
  const _CardPainter(this.geometry, this.selected);
  final _BarGeometry geometry;
  final AnalyticsCardSelection? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = geometry.plot;
    final axis =
        Paint()
          ..color = _axisGray
          ..strokeWidth = .6;
    canvas.drawLine(plot.topLeft, plot.bottomLeft, axis);
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axis);
    final raw = geometry.maximum / 8;
    final base = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final step = math.max(
      1,
      ([1, 2, 5, 10].firstWhere((n) => n * base >= raw) * base).round(),
    );
    final style = chartRoboto(9.5, color: Colors.black);
    for (var tick = 0; tick <= geometry.maximum; tick += step) {
      paintNativeChartLabel(
        canvas,
        '$tick',
        Offset(
          plot.left - 5,
          plot.bottom - tick / geometry.maximum * plot.height - 6,
        ),
        style,
        rightAligned: true,
      );
    }
    final cards = geometry.cards;
    for (var i = 0; i < cards.length; i++) {
      for (final status in AnalyticsCardStatus.values) {
        final rect = geometry.bar(i, status);
        final color = analyticsBarColors[status.index];
        canvas.drawRect(
          rect,
          Paint()
            ..color =
                selected == (card: cards[i], status: status)
                    ? Color.lerp(color, Colors.black, .5)!
                    : color,
        );
        if (cards.length <= 12) {
          paintNativeChartLabel(
            canvas,
            '${cards[i].count(status)}',
            Offset(rect.center.dx, rect.top - 14),
            chartRoboto(10.5, color: Colors.black),
          );
        }
      }
      if (i % math.max(1, (cards.length / 10).ceil()) == 0) {
        paintNativeChartLabel(
          canvas,
          cards[i].name,
          Offset(geometry.center(i), plot.bottom + 5),
          style,
          rotation: math.pi / 4,
          belowAxis: true,
          maxWidth: geometry.labelWidth,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CardPainter oldDelegate) =>
      geometry != oldDelegate.geometry || selected != oldDelegate.selected;
}

class _NoChartData extends StatelessWidget {
  const _NoChartData();
  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'No chart data available.',
      style: chartRoboto(12, color: const Color(0xfff7a35c)),
    ),
  );
}

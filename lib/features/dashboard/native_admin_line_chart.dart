import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'admin_chart_models.dart';

const _orange = Color(0xFFFDA000);
const _cancel = Color(0xFFB2BEC3);

TextStyle chartRoboto(
  double size, {
  Color color = const Color(0xFF6C6E6F),
  FontWeight weight = FontWeight.normal,
}) => TextStyle(
  inherit: false,
  textBaseline: TextBaseline.alphabetic,
  fontFamily: 'Roboto',
  fontSize: size,
  fontWeight: weight,
  color: color,
);

String _seriesName(AdminChartKind kind, int series) =>
    kind == AdminChartKind.payment
        ? (series == 0 ? 'Payment Receive' : 'Payment Return')
        : (series == 0 ? 'Total Appointment' : 'Cancel Appointment');

Rect adminChartPlot(Size size, AdminChartMode mode, double textScale) =>
    Rect.fromLTRB(
      20,
      14,
      math.max(21.0, size.width - 20),
      math.max(
        15.0,
        size.height - (mode == AdminChartMode.monthly ? 55 : 24) * textScale,
      ),
    );

double _chartMaximum(AdminChartData data) {
  var highest = 0.0;
  for (final point in data.points) {
    highest = math.max(
      highest,
      math.max(point.primary.plot, point.secondary.plot),
    );
  }
  return highest <= 0 ? 1 : highest * 1.1;
}

/// Native MPAndroidChart configuration: cubic intensity .2, no fill/grid/Y
/// labels, 2dp lines, 3dp circles, 45-degree monthly X labels and tap markers.
class NativeAdminLineChart extends StatefulWidget {
  const NativeAdminLineChart({
    super.key,
    required this.data,
    required this.mode,
    required this.sdp,
  });
  final AdminChartData data;
  final AdminChartMode mode;
  final double sdp;

  @override
  State<NativeAdminLineChart> createState() => _NativeAdminLineChartState();
}

class _NativeAdminLineChartState extends State<NativeAdminLineChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  double _zoomX = 1, _zoomY = 1, _offsetX = 0, _offsetY = 0;
  double _startZoomX = 1, _startZoomY = 1, _startOffsetX = 0, _startOffsetY = 0;
  Offset _startFocal = Offset.zero;
  int _zoomAxis = 0;
  int? _selected;
  int _series = 0;

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
  void didUpdateWidget(covariant NativeAdminLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data) ||
        oldWidget.mode != widget.mode) {
      _zoomX = _zoomY = 1;
      _offsetX = _offsetY = 0;
      _selected = null;
      unawaited(_animation.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  Offset _location(int index, int series, Rect plot) {
    final point = widget.data.points[index];
    final x =
        widget.data.points.length == 1
            ? 0.5
            : index / (widget.data.points.length - 1);
    final value =
        (series == 0 ? point.primary.plot : point.secondary.plot) *
        _animation.value;
    return Offset(
      plot.left + (x - _offsetX) * _zoomX * plot.width,
      plot.bottom -
          (value / _chartMaximum(widget.data) - _offsetY) *
              _zoomY *
              plot.height,
    );
  }

  void _select(Offset position, Rect plot) {
    if (!plot.contains(position) || widget.data.points.isEmpty) {
      setState(() => _selected = null);
      return;
    }
    final x = _offsetX + (position.dx - plot.left) / (plot.width * _zoomX);
    final index =
        (x * (widget.data.points.length - 1))
            .round()
            .clamp(0, widget.data.points.length - 1)
            .toInt();
    final first = _location(index, 0, plot);
    final second = _location(index, 1, plot);
    final series =
        (position.dy - first.dy).abs() <= (position.dy - second.dy).abs()
            ? 0
            : 1;
    setState(() {
      if (_selected == index && _series == series) {
        _selected = null;
      } else {
        _selected = index;
        _series = series;
      }
    });
  }

  Widget _legend(int series, double scale) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox.square(
        dimension: 8,
        child: ColoredBox(
          color:
              series == 0
                  ? DocColors.greenSea
                  : widget.data.kind == AdminChartKind.payment
                  ? _orange
                  : _cancel,
        ),
      ),
      const SizedBox(width: 5),
      // Wrap moves whole legend entries; constrain each label as well so large
      // text can wrap within an entry on narrow screens.
      Flexible(
        child: Text(
          _seriesName(widget.data.kind, series),
          textScaler: TextScaler.noScaling,
          softWrap: true,
          style: chartRoboto(10 * scale, color: Colors.black),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    if (widget.data.points.isEmpty) {
      return Center(
        child: Text(
          'No chart data available.',
          textScaler: TextScaler.noScaling,
          style: chartRoboto(12 * scale, color: const Color(0xFFF7A35C)),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final plot = adminChartPlot(size, widget.mode, scale);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _select(details.localPosition, plot),
                onScaleStart: (details) {
                  _startFocal = details.localFocalPoint;
                  _startZoomX = _zoomX;
                  _startZoomY = _zoomY;
                  _startOffsetX = _offsetX;
                  _startOffsetY = _offsetY;
                  _zoomAxis = 0;
                },
                onScaleUpdate: (details) {
                  setState(() {
                    if (details.pointerCount > 1 &&
                        _zoomAxis == 0 &&
                        math.max(
                              (details.horizontalScale - 1).abs(),
                              (details.verticalScale - 1).abs(),
                            ) >
                            0.01) {
                      _zoomAxis =
                          (details.horizontalScale - 1).abs() >=
                                  (details.verticalScale - 1).abs()
                              ? 1
                              : 2;
                    }
                    // Native pinchZoom=false: scale one axis, rather than uniform XY.
                    if (details.pointerCount > 1) {
                      if (_zoomAxis == 1) {
                        _zoomX =
                            (_startZoomX * details.horizontalScale)
                                .clamp(1.0, 100.0)
                                .toDouble();
                      } else if (_zoomAxis == 2) {
                        _zoomY =
                            (_startZoomY * details.verticalScale)
                                .clamp(1.0, 100.0)
                                .toDouble();
                      }
                    }
                    _offsetX =
                        (_startOffsetX +
                                (_startFocal.dx - plot.left) /
                                    (plot.width * _startZoomX) -
                                (details.localFocalPoint.dx - plot.left) /
                                    (plot.width * _zoomX))
                            .clamp(0.0, 1 - 1 / _zoomX)
                            .toDouble();
                    _offsetY =
                        (_startOffsetY +
                                (plot.bottom - _startFocal.dy) /
                                    (plot.height * _startZoomY) -
                                (plot.bottom - details.localFocalPoint.dy) /
                                    (plot.height * _zoomY))
                            .clamp(0.0, 1 - 1 / _zoomY)
                            .toDouble();
                    _selected = null;
                  });
                },
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Semantics(
                            label: widget.data.points
                                .map(
                                  (point) =>
                                      '${point.label}: ${_seriesName(widget.data.kind, 0)} ${point.primary.plot}; '
                                      '${_seriesName(widget.data.kind, 1)} ${point.secondary.plot}',
                                )
                                .join('. '),
                            child: CustomPaint(
                              key: Key(
                                'admin_chart_canvas_${widget.data.kind.name}',
                              ),
                              painter: NativeAdminLinePainter(
                                data: widget.data,
                                mode: widget.mode,
                                textScale: scale,
                                phase: _animation.value,
                                zoomX: _zoomX,
                                zoomY: _zoomY,
                                offsetX: _offsetX,
                                offsetY: _offsetY,
                                selected: _selected,
                                series: _series,
                              ),
                            ),
                          ),
                        ),
                        if (_selected != null) _marker(plot, size, scale),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 20),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [_legend(0, scale), _legend(1, scale)],
          ),
        ),
      ],
    );
  }

  Widget _marker(Rect plot, Size size, double scale) {
    final point = widget.data.points[_selected!];
    final value = _series == 0 ? point.primary.plot : point.secondary.plot;
    final text =
        '${widget.data.kind == AdminChartKind.payment ? '৳ ' : ''}'
        '${chartGroupInteger(value.round().toString())}';
    final style = chartRoboto(9 * widget.sdp * scale, color: Colors.white);
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final width =
        math.max(60.0, painter.width + 10).clamp(1.0, size.width).toDouble();
    final height = math.max(32.0, painter.height + 11);
    painter.dispose();
    final position = _location(_selected!, _series, plot);
    return Positioned(
      left:
          (position.dx - width / 2)
              .clamp(0.0, math.max(0.0, size.width - width))
              .toDouble(),
      top:
          (position.dy - height)
              .clamp(0.0, math.max(0.0, size.height - height))
              .toDouble(),
      child: IgnorePointer(
        child: Semantics(
          liveRegion: true,
          label:
              '${point.label}, ${_seriesName(widget.data.kind, _series)}, $text',
          child: Container(
            key: Key('admin_chart_marker_${widget.data.kind.name}'),
            width: width,
            height: height,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/c_marker.png'),
                fit: BoxFit.fill,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(5, 3, 5, 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(text, textScaler: TextScaler.noScaling, style: style),
            ),
          ),
        ),
      ),
    );
  }
}

class NativeAdminLinePainter extends CustomPainter {
  NativeAdminLinePainter({
    required this.data,
    required this.mode,
    required this.textScale,
    required this.phase,
    required this.zoomX,
    required this.zoomY,
    required this.offsetX,
    required this.offsetY,
    this.selected,
    this.series = 0,
  });
  final AdminChartData data;
  final AdminChartMode mode;
  final double textScale, phase, zoomX, zoomY, offsetX, offsetY;
  final int? selected;
  final int series;

  void _text(
    Canvas canvas,
    String value,
    Offset position,
    double size, {
    double rotation = 0,
    bool belowAxis = false,
    Color color = const Color(0xFF6C6E6F),
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: chartRoboto(size * textScale, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    // Center the rotated label's full bounds below the axis, rather than
    // rotating its top edge around the tick (which raises half the date).
    final rotatedHeight =
        painter.width * math.sin(rotation).abs() +
        painter.height * math.cos(rotation).abs();
    canvas.translate(
      position.dx,
      position.dy + (belowAxis ? rotatedHeight / 2 : 0),
    );
    if (rotation != 0) {
      canvas.rotate(rotation);
    }
    painter.paint(
      canvas,
      Offset(-painter.width / 2, belowAxis ? -painter.height / 2 : 0),
    );
    canvas.restore();
    painter.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.points.isEmpty || size.width < 42 || size.height < 50) {
      return;
    }
    final plot = adminChartPlot(size, mode, textScale);
    final count = data.points.length;
    final maximum = _chartMaximum(data);
    Offset at(int index, int series) {
      final point = data.points[index];
      final x = count == 1 ? 0.5 : index / (count - 1);
      final value =
          (series == 0 ? point.primary.plot : point.secondary.plot) * phase;
      return Offset(
        plot.left + (x - offsetX) * zoomX * plot.width,
        plot.bottom - (value / maximum - offsetY) * zoomY * plot.height,
      );
    }

    final visible = math.max(1, (count * phase).ceil()).clamp(1, count).toInt();
    final lineColors = [
      DocColors.greenSea,
      data.kind == AdminChartKind.payment ? _orange : _cancel,
    ];
    final circleColors = [
      DocColors.primary,
      data.kind == AdminChartKind.payment
          ? const Color(0xFFC23616)
          : DocColors.muted,
    ];
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        plot.left - 4,
        plot.top - 10,
        plot.right + 4,
        plot.bottom + 4,
      ),
    );
    for (var series = 0; series < 2; series++) {
      final path = Path();
      var previous = at(0, series);
      path.moveTo(previous.dx, previous.dy);
      for (var i = 1; i < visible; i++) {
        final before = at(math.max(0, i - 2), series);
        final current = at(i, series);
        final next = at(math.min(count - 1, i + 1), series);
        final a = previous + (current - before) * 0.2;
        final b = current - (next - previous) * 0.2;
        path.cubicTo(a.dx, a.dy, b.dx, b.dy, current.dx, current.dy);
        previous = current;
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = lineColors[series]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      for (var i = 0; i < visible; i++) {
        final p = at(i, series);
        if (p.dx < plot.left - 1 ||
            p.dx > plot.right + 1 ||
            p.dy > plot.bottom + 1) {
          continue;
        }
        canvas.drawCircle(p, 3, Paint()..color = circleColors[series]);
        canvas.drawCircle(p, 1.8, Paint()..color = Colors.white);
        // MPAndroidChart suppresses point labels above its 100-entry threshold.
        if (count * 2 < 100 * zoomX) {
          _text(
            canvas,
            chartCompact(
              series == 0
                  ? data.points[i].primary.plot
                  : data.points[i].secondary.plot,
            ),
            Offset(p.dx, p.dy - 5 - 8 * textScale),
            8,
          );
        }
      }
    }
    if (selected != null) {
      final p = at(selected!, series);
      final paint =
          Paint()
            ..color = const Color(0xFFFFBB73)
            ..strokeWidth = 0.5;
      canvas.drawLine(Offset(p.dx, plot.top), Offset(p.dx, plot.bottom), paint);
      canvas.drawLine(Offset(plot.left, p.dy), Offset(plot.right, p.dy), paint);
    }
    canvas.restore();
    canvas.drawLine(
      plot.bottomLeft,
      plot.bottomRight,
      Paint()
        ..color = const Color(0xFF888888)
        ..strokeWidth = 1,
    );
    if (count == 1) {
      final x = at(0, 0).dx;
      if (x >= plot.left && x <= plot.right) {
        _text(
          canvas,
          data.points.first.label,
          Offset(x, plot.bottom + 4),
          10,
          rotation: mode == AdminChartMode.monthly ? math.pi / 4 : 0,
          belowAxis: true,
          color: const Color(0xFF888888),
        );
      }
      return;
    }
    // Same six-label/default granularity policy, using the API's original order.
    final span = math.max(1, count - 1) / zoomX;
    final raw = span / 6;
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor());
    var interval =
        math.max(1.0, (raw / magnitude).round() * magnitude).toDouble();
    final significant =
        interval / math.pow(10, (math.log(interval) / math.ln10).floor());
    if (significant > 5) {
      interval =
          math.pow(10, (math.log(interval) / math.ln10).floor() + 1).toDouble();
    }
    final first =
        (offsetX * math.max(1, count - 1) / interval).ceil() * interval;
    for (var value = first; value < count; value += interval) {
      final index = value.toInt();
      final x =
          count == 1
              ? plot.center.dx
              : plot.left +
                  (value / (count - 1) - offsetX) * zoomX * plot.width;
      if (x < plot.left - 1 || x > plot.right + 1) {
        continue;
      }
      _text(
        canvas,
        data.points[index].label,
        Offset(x, plot.bottom + 4),
        10,
        rotation: mode == AdminChartMode.monthly ? math.pi / 4 : 0,
        belowAxis: true,
        color: const Color(0xFF888888),
      );
    }
  }

  @override
  bool shouldRepaint(covariant NativeAdminLinePainter old) =>
      !identical(old.data, data) ||
      old.mode != mode ||
      old.textScale != textScale ||
      old.phase != phase ||
      old.zoomX != zoomX ||
      old.zoomY != zoomY ||
      old.offsetX != offsetX ||
      old.offsetY != offsetY ||
      old.selected != selected ||
      old.series != series;
}

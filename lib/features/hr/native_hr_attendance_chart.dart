import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'hr_dashboard_models.dart';

const hrPieColors = [
  Color.fromRGBO(85, 239, 196, 1),
  Color.fromRGBO(116, 185, 255, 1),
  Color.fromRGBO(162, 155, 254, 1),
  Color.fromRGBO(223, 230, 233, 1),
  Color.fromRGBO(255, 234, 167, 1),
  Color.fromRGBO(250, 177, 160, 1),
  Color.fromRGBO(178, 190, 195, 1),
];

/// Native donut radius/legend/colors; a drag rotates, a tap opens attendance.
class NativeHrAttendanceChart extends StatefulWidget {
  const NativeHrAttendanceChart({
    super.key,
    required this.attendance,
    required this.onOpenAttendance,
    this.valueFontSize = 12,
  });
  final HrAttendance attendance;
  final VoidCallback onOpenAttendance;
  final double valueFontSize;
  @override
  State<NativeHrAttendanceChart> createState() =>
      _NativeHrAttendanceChartState();
}

class _NativeHrAttendanceChartState extends State<NativeHrAttendanceChart> {
  double _rotation = -math.pi / 2;
  double? _dragStart;
  double _angle(Offset point, Size size) =>
      math.atan2(point.dy - size.height / 2, point.dx - size.width / 2);
  @override
  Widget build(BuildContext context) {
    final data = widget.attendance;
    final scale = MediaQuery.textScalerOf(context);
    Widget legend() => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          data.isEmpty
              ? [_entry(const Color.fromRGBO(253, 121, 168, 1), 'No Data')]
              : [
                for (final slice in data.slices)
                  _entry(hrPieColors[slice.index], data.legend(slice)),
              ],
    );
    return Semantics(
      button: true,
      label:
          'Daily Attendance. ${data.isEmpty ? 'No Data' : data.slices.map(data.legend).join(', ')}',
      child: LayoutBuilder(
        builder: (context, box) {
          final stacked = box.maxWidth < 330 || scale.scale(12) > 17;
          Widget pie(double dimension) => SizedBox(
            width: dimension,
            height: dimension,
            child: LayoutBuilder(
              builder:
                  (context, chartBox) => GestureDetector(
                    key: const Key('hr_pie'),
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onOpenAttendance,
                    onPanStart:
                        (details) =>
                            _dragStart =
                                _angle(
                                  details.localPosition,
                                  chartBox.biggest,
                                ) -
                                _rotation,
                    onPanUpdate: (details) {
                      if (_dragStart != null) {
                        setState(
                          () =>
                              _rotation =
                                  _angle(
                                    details.localPosition,
                                    chartBox.biggest,
                                  ) -
                                  _dragStart!,
                        );
                      }
                    },
                    onPanEnd: (_) => _dragStart = null,
                    child: TweenAnimationBuilder<double>(
                      key: ObjectKey(data),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(seconds: 1),
                      builder:
                          (context, progress, _) => CustomPaint(
                            painter: _DonutPainter(
                              data,
                              _rotation,
                              progress,
                              scale.scale(widget.valueFontSize),
                            ),
                          ),
                    ),
                  ),
            ),
          );
          return InkWell(
            key: const Key('hr_attendance_chart'),
            onTap: widget.onOpenAttendance,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child:
                  stacked
                      ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          pie(math.min(230, box.maxWidth - 10)),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: legend(),
                          ),
                        ],
                      )
                      : Row(
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder:
                                  (context, pieBox) => Center(
                                    child: pie(math.min(240, pieBox.maxWidth)),
                                  ),
                            ),
                          ),
                          SizedBox(
                            width: box.maxWidth * .48,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              child: legend(),
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

  Widget _entry(Color color, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              color: Colors.black,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.data, this.rotation, this.progress, this.fontSize);
  final HrAttendance data;
  final double rotation, progress, fontSize;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 5;
    if (radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    if (data.isEmpty) {
      canvas.drawArc(
        rect,
        rotation,
        math.pi * 2 * progress,
        true,
        Paint()..color = const Color.fromRGBO(253, 121, 168, 1),
      );
    } else {
      var start = rotation;
      for (final slice in data.slices) {
        final fraction = slice.number.plot / data.total;
        final sweep = fraction * math.pi * 2 * progress;
        canvas.drawArc(
          rect,
          start,
          sweep,
          true,
          Paint()..color = hrPieColors[slice.index],
        );
        if (progress == 1) {
          final text = TextPainter(
            text: TextSpan(
              text: '${(fraction * 100).round()} %',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: fontSize,
                color: Colors.black,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: radius * 1.5);
          final angle = start + sweep / 2;
          final point =
              center + Offset(math.cos(angle), math.sin(angle)) * radius * .7;
          text.paint(canvas, point - Offset(text.width / 2, text.height / 2));
        }
        start += sweep;
      }
    }
    canvas.drawCircle(center, radius * .4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.data != data ||
      old.rotation != rotation ||
      old.progress != progress ||
      old.fontSize != fontSize;
}

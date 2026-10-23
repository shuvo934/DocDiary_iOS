import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../hr_dashboard_models.dart';
import '../native_hr_attendance_chart.dart' show hrPieColors;

/// MPAndroidChart's native Float -> floor(count) value formatter.
String employeeAttendanceChartCount(double value) =>
    Float32List.fromList([value]).single.floor().toString();

class NativeEmployeeAttendanceChart extends StatefulWidget {
  const NativeEmployeeAttendanceChart({
    super.key,
    required this.attendance,
    this.sdp = 1,
  });
  final HrAttendance attendance;
  final double sdp;
  @override
  State<NativeEmployeeAttendanceChart> createState() =>
      _NativeEmployeeAttendanceChartState();
}

class _NativeEmployeeAttendanceChartState
    extends State<NativeEmployeeAttendanceChart> {
  double _rotation = -math.pi / 2;
  double? _dragStart;
  int? _selected;
  double _angle(Offset p, Size size) =>
      math.atan2(p.dy - size.height / 2, p.dx - size.width / 2);
  @override
  void didUpdateWidget(covariant NativeEmployeeAttendanceChart old) {
    super.didUpdateWidget(old);
    if (old.attendance != widget.attendance) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.attendance;
    final scale = MediaQuery.textScalerOf(context);
    Widget legend() => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.isEmpty)
          _entry(const Color(0xfffd79a8), 'No Data')
        else
          for (final slice in data.slices)
            _entry(hrPieColors[slice.index], slice.label),
      ],
    );
    return Semantics(
      label:
          data.isEmpty
              ? 'Attendance: No Data'
              : data.slices
                  .map(
                    (s) =>
                        '${s.label}: ${employeeAttendanceChartCount(s.number.plot)}',
                  )
                  .join(', '),
      child: LayoutBuilder(
        builder: (context, box) {
          Widget pie(double dimension) => SizedBox(
            width: dimension,
            height: dimension,
            child: GestureDetector(
              key: const Key('employee_pie'),
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                if (data.isEmpty) return;
                final size = Size.square(dimension),
                    delta =
                        details.localPosition -
                        Offset(dimension / 2, dimension / 2);
                final radius = dimension / 2 - 8;
                if (delta.distance < radius * .4 ||
                    delta.distance > radius + 7) {
                  setState(() => _selected = null);
                  return;
                }
                var angle =
                    (_angle(details.localPosition, size) - _rotation) %
                    (2 * math.pi);
                for (final slice in data.slices) {
                  final sweep = slice.number.plot / data.total * 2 * math.pi;
                  if (angle < sweep) {
                    setState(
                      () =>
                          _selected =
                              _selected == slice.index ? null : slice.index,
                    );
                    return;
                  }
                  angle -= sweep;
                }
              },
              onPanStart:
                  (d) =>
                      _dragStart =
                          _angle(d.localPosition, Size.square(dimension)) -
                          _rotation,
              onPanUpdate: (d) {
                if (_dragStart != null) {
                  setState(
                    () =>
                        _rotation =
                            _angle(d.localPosition, Size.square(dimension)) -
                            _dragStart!,
                  );
                }
              },
              onPanEnd: (_) => _dragStart = null,
              onPanCancel: () => _dragStart = null,
              child: TweenAnimationBuilder<double>(
                key: ObjectKey(data),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(seconds: 1),
                builder:
                    (_, progress, __) => CustomPaint(
                      painter: _EmployeeDonutPainter(
                        data,
                        _rotation,
                        progress,
                        scale.scale(12),
                        _selected,
                      ),
                    ),
              ),
            ),
          );
          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  pie(math.min(195 * widget.sdp, box.maxWidth * .6)),
                  const SizedBox(height: 6),
                  IntrinsicWidth(child: legend()),
                ],
              ),
            );
          }
          if (box.maxWidth < 330 || scale.scale(12) > 17) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                pie(math.min(220 * widget.sdp, box.maxWidth - 16)),
                Padding(padding: const EdgeInsets.all(8), child: legend()),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder:
                      (_, b) => Center(
                        child: pie(math.min(220 * widget.sdp, b.maxWidth)),
                      ),
                ),
              ),
              SizedBox(
                width: box.maxWidth * .47,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  child: legend(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _entry(Color color, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
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

class _EmployeeDonutPainter extends CustomPainter {
  _EmployeeDonutPainter(
    this.data,
    this.rotation,
    this.progress,
    this.fontSize,
    this.selected,
  );
  final HrAttendance data;
  final double rotation, progress, fontSize;
  final int? selected;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero),
        radius = math.min(size.width, size.height) / 2 - 8;
    if (radius <= 0) return;
    var angle = rotation;
    if (data.isEmpty) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        math.pi * 2 * progress,
        true,
        Paint()..color = const Color(0xfffd79a8),
      );
    } else {
      for (final slice in data.slices) {
        final sweep = slice.number.plot / data.total * math.pi * 2 * progress;
        final r = radius + (selected == slice.index ? 5 : 0);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          angle,
          sweep,
          true,
          Paint()..color = hrPieColors[slice.index],
        );
        if (progress == 1) {
          final text = TextPainter(
            textDirection: TextDirection.ltr,
            text: TextSpan(
              text: employeeAttendanceChartCount(slice.number.plot),
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: fontSize,
                color: Colors.black,
              ),
            ),
          )..layout(maxWidth: radius * 1.5);
          final point =
              center +
              Offset(math.cos(angle + sweep / 2), math.sin(angle + sweep / 2)) *
                  radius *
                  .7;
          text.paint(canvas, point - Offset(text.width / 2, text.height / 2));
        }
        angle += sweep;
      }
    }
    canvas.drawCircle(center, radius * .4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_EmployeeDonutPainter old) =>
      old.data != data ||
      old.rotation != rotation ||
      old.progress != progress ||
      old.fontSize != fontSize ||
      old.selected != selected;
}

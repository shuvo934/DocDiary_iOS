import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Original arrow_drop_down_24 / refresh_24 Android vector paths.
class NativeChartIcon extends StatelessWidget {
  const NativeChartIcon({super.key, required this.size, this.refresh = false});
  final double size;
  final bool refresh;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _ChartIconPainter(refresh)),
  );
}

class _ChartIconPainter extends CustomPainter {
  const _ChartIconPainter(this.refresh);
  final bool refresh;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final path =
        refresh
            ? (Path()
              ..moveTo(17.65, 6.35)
              ..cubicTo(16.2, 4.9, 14.21, 4, 12, 4)
              ..relativeCubicTo(-4.42, 0, -7.99, 3.58, -7.99, 8)
              ..relativeCubicTo(0, 4.42, 3.57, 8, 7.99, 8)
              ..relativeCubicTo(3.73, 0, 6.84, -2.55, 7.73, -6)
              ..relativeLineTo(-2.08, 0)
              ..relativeCubicTo(-0.82, 2.33, -3.04, 4, -5.65, 4)
              ..relativeCubicTo(-3.31, 0, -6, -2.69, -6, -6)
              ..relativeCubicTo(0, -3.31, 2.69, -6, 6, -6)
              ..relativeCubicTo(1.66, 0, 3.14, 0.69, 4.22, 1.78)
              ..lineTo(13, 11)
              ..lineTo(20, 11)
              ..lineTo(20, 4)
              ..relativeLineTo(-2.35, 2.35)
              ..close())
            : (Path()
              ..moveTo(7, 10)
              ..relativeLineTo(5, 5)
              ..relativeLineTo(5, -5)
              ..close());
    canvas.drawPath(path, Paint()..color = DocColors.primary);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChartIconPainter oldDelegate) =>
      refresh != oldDelegate.refresh;
}

import 'dart:math' as math;
import 'package:flutter/painting.dart';

/// MPAndroidChart cubic interpolation at the native .2 intensity.
Path nativeChartCurve(int visible, int count, Offset Function(int) point) {
  var previous = point(0);
  final path = Path()..moveTo(previous.dx, previous.dy);
  for (var i = 1; i < visible; i++) {
    final before = point(math.max(0, i - 2));
    final current = point(i);
    final next = point(math.min(count - 1, i + 1));
    final a = previous + (current - before) * .2;
    final b = current - (next - previous) * .2;
    path.cubicTo(a.dx, a.dy, b.dx, b.dy, current.dx, current.dy);
    previous = current;
  }
  return path;
}

void paintNativeChartLabel(
  Canvas canvas,
  String value,
  Offset position,
  TextStyle style, {
  double rotation = 0,
  bool belowAxis = false,
  bool rightAligned = false,
  double? maxWidth,
}) {
  final painter = TextPainter(
    text: TextSpan(text: value, style: style),
    textDirection: TextDirection.ltr,
    maxLines: maxWidth == null ? null : 1,
    ellipsis: maxWidth == null ? null : '…',
  )..layout(maxWidth: maxWidth ?? double.infinity);
  final rotatedHeight =
      painter.width * math.sin(rotation).abs() +
      painter.height * math.cos(rotation).abs();
  canvas.save();
  canvas.translate(
    position.dx,
    position.dy + (belowAxis ? rotatedHeight / 2 : 0),
  );
  if (rotation != 0) canvas.rotate(rotation);
  painter.paint(
    canvas,
    Offset(
      rightAligned ? -painter.width : -painter.width / 2,
      belowAxis ? -painter.height / 2 : 0,
    ),
  );
  canvas.restore();
  painter.dispose();
}

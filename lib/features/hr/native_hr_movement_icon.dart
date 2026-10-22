import 'package:flutter/material.dart';

/// Exact path from native moving_24.xml, drawn in its original 24x24 viewport.
class NativeHrMovementIcon extends StatelessWidget {
  const NativeHrMovementIcon({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CustomPaint(painter: _MovementPainter()),
  );
}

class _MovementPainter extends CustomPainter {
  const _MovementPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final path =
        Path()
          ..moveTo(19.71, 9.71)
          ..lineTo(22.0, 12.0)
          ..lineTo(22.0, 6.0)
          ..lineTo(16.0, 6.0)
          ..lineTo(18.29, 8.29)
          ..lineTo(14.12, 12.46)
          ..cubicTo(13.73, 12.85, 13.1, 12.85, 12.71, 12.46)
          ..lineTo(11.54, 11.29)
          ..cubicTo(10.37, 10.12, 8.47, 10.12, 7.3, 11.29)
          ..lineTo(2.0, 16.59)
          ..lineTo(3.41, 18.0)
          ..lineTo(8.7, 12.71)
          ..cubicTo(9.09, 12.32, 9.72, 12.32, 10.11, 12.71)
          ..lineTo(11.28, 13.88)
          ..cubicTo(12.45, 15.05, 14.35, 15.05, 15.52, 13.88)
          ..lineTo(19.71, 9.71)
          ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MovementPainter old) => false;
}

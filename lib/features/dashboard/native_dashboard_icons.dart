import 'package:flutter/material.dart';

// Paths copied from the original Android vector drawables, without substitute icons.
enum NativeDashboardGlyph {
  logout,
  profile,
  appointment,
  leave,
  payment,
  camera,
  timer,
}

class NativeDashboardIcon extends StatelessWidget {
  const NativeDashboardIcon(
    this.glyph, {
    super.key,
    required this.size,
    required this.color,
  });
  final NativeDashboardGlyph glyph;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _NativeIconPainter(glyph, color)),
  );
}

class _NativeIconPainter extends CustomPainter {
  const _NativeIconPainter(this.glyph, this.color);
  final NativeDashboardGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()..color = color;
    switch (glyph) {
      case NativeDashboardGlyph.logout:
        final logoutPath0 =
            Path()
              ..moveTo(17, 7)
              ..lineTo(15.59, 8.41)
              ..lineTo(18.17, 11)
              ..lineTo(8, 11)
              ..lineTo(8, 13)
              ..lineTo(18.17, 13)
              ..lineTo(15.59, 15.58)
              ..lineTo(17, 17)
              ..lineTo(22, 12)
              ..lineTo(17, 7)
              ..close()
              ..moveTo(4, 5)
              ..lineTo(12, 5)
              ..lineTo(12, 3)
              ..lineTo(4, 3)
              ..cubicTo(2.9, 3, 2, 3.9, 2, 5)
              ..lineTo(2, 19)
              ..cubicTo(2, 20.1, 2.9, 21, 4, 21)
              ..lineTo(12, 21)
              ..lineTo(12, 19)
              ..lineTo(4, 19)
              ..lineTo(4, 5)
              ..close();
        canvas.drawPath(logoutPath0, paint);
        break;
      case NativeDashboardGlyph.profile:
        final profilePath0 =
            Path()
              ..moveTo(12, 12)
              ..cubicTo(14.21, 12, 16, 10.21, 16, 8)
              ..cubicTo(16, 5.79, 14.21, 4, 12, 4)
              ..cubicTo(9.79, 4, 8, 5.79, 8, 8)
              ..cubicTo(8, 10.21, 9.79, 12, 12, 12)
              ..close()
              ..moveTo(12, 14)
              ..cubicTo(9.33, 14, 4, 15.34, 4, 18)
              ..lineTo(4, 20)
              ..lineTo(20, 20)
              ..lineTo(20, 18)
              ..cubicTo(20, 15.34, 14.67, 14, 12, 14)
              ..close();
        canvas.drawPath(profilePath0, paint);
        break;
      case NativeDashboardGlyph.appointment:
        final appointmentPath0 =
            Path()
              ..moveTo(11.99, 2)
              ..cubicTo(6.47, 2, 2, 6.48, 2, 12)
              ..cubicTo(2, 17.52, 6.47, 22, 11.99, 22)
              ..cubicTo(17.52, 22, 22, 17.52, 22, 12)
              ..cubicTo(22, 6.48, 17.52, 2, 11.99, 2)
              ..close()
              ..moveTo(15.29, 16.71)
              ..lineTo(11, 12.41)
              ..lineTo(11, 7)
              ..lineTo(13, 7)
              ..lineTo(13, 11.59)
              ..lineTo(16.71, 15.3)
              ..lineTo(15.29, 16.71)
              ..close();
        canvas.drawPath(appointmentPath0, paint);
        break;
      case NativeDashboardGlyph.leave:
        final leavePath0 =
            Path()
              ..moveTo(9, 1)
              ..lineTo(15, 1)
              ..lineTo(15, 3)
              ..lineTo(9, 3)
              ..lineTo(9, 1)
              ..close();
        canvas.drawPath(leavePath0, paint);
        final leavePath1 =
            Path()
              ..moveTo(13, 8)
              ..lineTo(13, 10.17)
              ..lineTo(19.98, 17.15)
              ..cubicTo(20.63, 15.91, 21, 14.5, 21, 13)
              ..cubicTo(21, 10.88, 20.26, 8.93, 19.03, 7.39)
              ..lineTo(20.45, 5.97)
              ..cubicTo(20.02, 5.46, 19.55, 4.98, 19.04, 4.56)
              ..lineTo(17.62, 5.98)
              ..cubicTo(16.07, 4.74, 14.12, 4, 12, 4)
              ..cubicTo(10.5, 4, 9.09, 4.37, 7.85, 5.02)
              ..lineTo(10.83, 8)
              ..lineTo(13, 8)
              ..close();
        canvas.drawPath(leavePath1, paint);
        final leavePath2 =
            Path()
              ..moveTo(2.81, 2.81)
              ..lineTo(1.39, 4.22)
              ..lineTo(4.79, 7.62)
              ..cubicTo(3.67, 9.12, 3, 10.98, 3, 13)
              ..cubicTo(3, 17.97, 7.02, 22, 12, 22)
              ..cubicTo(14.02, 22, 15.88, 21.33, 17.38, 20.21)
              ..lineTo(19.78, 22.61)
              ..lineTo(21.19, 21.2)
              ..lineTo(2.81, 2.81)
              ..close();
        canvas.drawPath(leavePath2, paint);
        break;
      case NativeDashboardGlyph.payment:
        final paymentPath0 =
            Path()
              ..moveTo(19, 14)
              ..lineTo(19, 6)
              ..cubicTo(19, 4.9, 18.1, 4, 17, 4)
              ..lineTo(3, 4)
              ..cubicTo(1.9, 4, 1, 4.9, 1, 6)
              ..lineTo(1, 14)
              ..cubicTo(1, 15.1, 1.9, 16, 3, 16)
              ..lineTo(17, 16)
              ..cubicTo(18.1, 16, 19, 15.1, 19, 14)
              ..close()
              ..moveTo(10, 13)
              ..cubicTo(8.34, 13, 7, 11.66, 7, 10)
              ..cubicTo(7, 8.34, 8.34, 7, 10, 7)
              ..cubicTo(11.66, 7, 13, 8.34, 13, 10)
              ..cubicTo(13, 11.66, 11.66, 13, 10, 13)
              ..close()
              ..moveTo(23, 7)
              ..lineTo(23, 18)
              ..cubicTo(23, 19.1, 22.1, 20, 21, 20)
              ..lineTo(4, 20)
              ..lineTo(4, 18)
              ..lineTo(21, 18)
              ..lineTo(21, 7)
              ..lineTo(23, 7)
              ..close();
        canvas.drawPath(paymentPath0, paint);
        break;
      case NativeDashboardGlyph.camera:
        final cameraPath0 =
            Path()
              ..moveTo(9.4, 10.5)
              ..lineTo(14.17, 2.24)
              ..cubicTo(13.47, 2.09, 12.75, 2, 12, 2)
              ..cubicTo(9.6, 2, 7.4, 2.85, 5.68, 4.25)
              ..lineTo(9.34, 10.6)
              ..lineTo(9.4, 10.5)
              ..close()
              ..moveTo(21.54, 9)
              ..cubicTo(20.62, 6.08, 18.39, 3.74, 15.54, 2.66)
              ..lineTo(11.88, 9)
              ..lineTo(21.54, 9)
              ..close()
              ..moveTo(21.8, 10)
              ..lineTo(14.31, 10)
              ..lineTo(14.6, 10.5)
              ..lineTo(19.36, 18.75)
              ..cubicTo(21, 16.97, 22, 14.61, 22, 12)
              ..cubicTo(22, 11.31, 21.93, 10.65, 21.8, 10)
              ..close()
              ..moveTo(8.54, 12)
              ..lineTo(4.64, 5.25)
              ..cubicTo(3.01, 7.03, 2, 9.39, 2, 12)
              ..cubicTo(2, 12.69, 2.07, 13.35, 2.2, 14)
              ..lineTo(9.69, 14)
              ..lineTo(8.54, 12)
              ..lineTo(8.54, 12)
              ..close()
              ..moveTo(2.46, 15)
              ..cubicTo(3.38, 17.92, 5.61, 20.26, 8.46, 21.34)
              ..lineTo(12.12, 15)
              ..lineTo(2.46, 15)
              ..close()
              ..moveTo(13.73, 15)
              ..lineTo(9.83, 21.76)
              ..cubicTo(10.53, 21.91, 11.25, 22, 12, 22)
              ..cubicTo(14.4, 22, 16.6, 21.15, 18.32, 19.75)
              ..lineTo(14.66, 13.4)
              ..lineTo(13.73, 15)
              ..lineTo(13.73, 15)
              ..close();
        canvas.drawPath(cameraPath0, paint);
        break;
      case NativeDashboardGlyph.timer:
        final timerPath0 =
            Path()
              ..moveTo(9, 1)
              ..lineTo(15, 1)
              ..lineTo(15, 3)
              ..lineTo(9, 3)
              ..lineTo(9, 1)
              ..close();
        canvas.drawPath(timerPath0, paint);
        final timerPath1 =
            Path()
              ..moveTo(19.03, 7.39)
              ..lineTo(20.45, 5.97)
              ..cubicTo(20.02, 5.46, 19.55, 4.98, 19.04, 4.56)
              ..lineTo(17.62, 5.98)
              ..cubicTo(16.07, 4.74, 14.12, 4, 12, 4)
              ..cubicTo(7.03, 4, 3, 8.03, 3, 13)
              ..cubicTo(3, 17.97, 7.02, 22, 12, 22)
              ..cubicTo(16.98, 22, 21, 17.97, 21, 13)
              ..cubicTo(21, 10.88, 20.26, 8.93, 19.03, 7.39)
              ..close()
              ..moveTo(13, 14)
              ..lineTo(11, 14)
              ..lineTo(11, 8)
              ..lineTo(13, 8)
              ..lineTo(13, 14)
              ..close();
        canvas.drawPath(timerPath1, paint);
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NativeIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

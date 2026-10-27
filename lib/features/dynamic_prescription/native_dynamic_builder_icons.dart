// Native Android vector geometry; vector portions Copyright (C) 2026 AOSP.
// Apache-2.0: https://www.apache.org/licenses/LICENSE-2.0
import 'package:flutter/material.dart';

enum DynamicBuilderGlyph { back, person, check, history, preview, template }

class NativeDynamicBuilderIcon extends StatelessWidget {
  const NativeDynamicBuilderIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    this.color = const Color(0xff16a085),
  });
  final DynamicBuilderGlyph glyph;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final asset = switch (glyph) {
      DynamicBuilderGlyph.history =>
        'assets/images/dy_builder_medical_record.png',
      DynamicBuilderGlyph.preview =>
        'assets/images/dy_builder_prescription_prv.png',
      DynamicBuilderGlyph.template => 'assets/images/dy_builder_template.png',
      _ => null,
    };
    return SizedBox.square(
      dimension: size,
      child:
          asset == null
              ? CustomPaint(painter: _BuilderPainter(glyph, color))
              : Image.asset(
                asset,
                fit: BoxFit.contain,
                color: color,
                colorBlendMode: BlendMode.srcIn,
              ),
    );
  }
}

class _BuilderPainter extends CustomPainter {
  const _BuilderPainter(this.glyph, this.color);
  final DynamicBuilderGlyph glyph;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final paint = Paint()..color = color;
    switch (glyph) {
      case DynamicBuilderGlyph.back:
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(11.67, 3.87)
              ..lineTo(9.9, 2.1)
              ..lineTo(0, 12)
              ..lineTo(9.9, 21.9)
              ..lineTo(11.67, 20.13)
              ..lineTo(3.54, 12)
              ..close();
        canvas.drawPath(path0, paint);
        break;
      case DynamicBuilderGlyph.person:
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
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
        canvas.drawPath(path0, paint);
        break;
      case DynamicBuilderGlyph.check:
        canvas.scale(size.width / 960, size.height / 960);
        final path0 =
            Path()
              ..moveTo(424, 664)
              ..lineTo(706, 382)
              ..lineTo(650, 326)
              ..lineTo(424, 552)
              ..lineTo(310, 438)
              ..lineTo(254, 494)
              ..lineTo(424, 664)
              ..close()
              ..moveTo(480, 880)
              ..quadraticBezierTo(397, 880, 324, 848.5)
              ..quadraticBezierTo(251, 817, 197, 763)
              ..quadraticBezierTo(143, 709, 111.5, 636)
              ..quadraticBezierTo(80, 563, 80, 480)
              ..quadraticBezierTo(80, 397, 111.5, 324)
              ..quadraticBezierTo(143, 251, 197, 197)
              ..quadraticBezierTo(251, 143, 324, 111.5)
              ..quadraticBezierTo(397, 80, 480, 80)
              ..quadraticBezierTo(563, 80, 636, 111.5)
              ..quadraticBezierTo(709, 143, 763, 197)
              ..quadraticBezierTo(817, 251, 848.5, 324)
              ..quadraticBezierTo(880, 397, 880, 480)
              ..quadraticBezierTo(880, 563, 848.5, 636)
              ..quadraticBezierTo(817, 709, 763, 763)
              ..quadraticBezierTo(709, 817, 636, 848.5)
              ..quadraticBezierTo(563, 880, 480, 880)
              ..close()
              ..moveTo(480, 800)
              ..quadraticBezierTo(614, 800, 707, 707)
              ..quadraticBezierTo(800, 614, 800, 480)
              ..quadraticBezierTo(800, 346, 707, 253)
              ..quadraticBezierTo(614, 160, 480, 160)
              ..quadraticBezierTo(346, 160, 253, 253)
              ..quadraticBezierTo(160, 346, 160, 480)
              ..quadraticBezierTo(160, 614, 253, 707)
              ..quadraticBezierTo(346, 800, 480, 800)
              ..close()
              ..moveTo(480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..close();
        canvas.drawPath(path0, paint);
        break;
      default:
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BuilderPainter oldDelegate) =>
      glyph != oldDelegate.glyph || color != oldDelegate.color;
}

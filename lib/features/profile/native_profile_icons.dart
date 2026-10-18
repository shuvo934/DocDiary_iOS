import 'package:flutter/material.dart';

// Paths from arrow_back.xml, edit_24.xml and baseline_videocam_24.xml.
enum NativeProfileGlyph { back, edit, video }

class NativeProfileIcon extends StatelessWidget {
  const NativeProfileIcon(
    this.glyph, {
    super.key,
    required this.size,
    required this.color,
  });
  final NativeProfileGlyph glyph;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _ProfileIconPainter(glyph, color)),
  );
}

class _ProfileIconPainter extends CustomPainter {
  const _ProfileIconPainter(this.glyph, this.color);
  final NativeProfileGlyph glyph;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final path = Path();
    switch (glyph) {
      case NativeProfileGlyph.back:
        path
          ..moveTo(11.67, 3.87)
          ..lineTo(9.9, 2.1)
          ..lineTo(0, 12)
          ..lineTo(9.9, 21.9)
          ..lineTo(11.67, 20.13)
          ..lineTo(3.54, 12)
          ..close();
        break;
      case NativeProfileGlyph.edit:
        path
          ..moveTo(3, 17.25)
          ..lineTo(3, 21)
          ..lineTo(6.75, 21)
          ..lineTo(17.81, 9.94)
          ..lineTo(14.06, 6.19)
          ..close()
          ..moveTo(20.71, 7.04)
          ..cubicTo(21.1, 6.65, 21.1, 6.02, 20.71, 5.63)
          ..lineTo(18.37, 3.29)
          ..cubicTo(17.98, 2.9, 17.35, 2.9, 16.96, 3.29)
          ..lineTo(15.13, 5.12)
          ..lineTo(18.88, 8.87)
          ..close();
        break;
      case NativeProfileGlyph.video:
        path
          ..moveTo(17, 10.5)
          ..lineTo(17, 7)
          ..cubicTo(17, 6.45, 16.55, 6, 16, 6)
          ..lineTo(4, 6)
          ..cubicTo(3.45, 6, 3, 6.45, 3, 7)
          ..lineTo(3, 17)
          ..cubicTo(3, 17.55, 3.45, 18, 4, 18)
          ..lineTo(16, 18)
          ..cubicTo(16.55, 18, 17, 17.55, 17, 17)
          ..lineTo(17, 13.5)
          ..lineTo(21, 17.5)
          ..lineTo(21, 6.5)
          ..close();
        break;
    }
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ProfileIconPainter old) =>
      old.glyph != glyph || old.color != color;
}

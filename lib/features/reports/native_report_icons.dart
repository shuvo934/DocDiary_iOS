import 'package:flutter/material.dart';

enum ReportGlyph { close, calendar, download, back, forward }

/// Original Android close_24, calendar_icon, file_download_24 and arrow vectors.
class NativeReportIcon extends StatelessWidget {
  const NativeReportIcon(
    this.glyph, {
    super.key,
    required this.size,
    required this.color,
  });
  final ReportGlyph glyph;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _ReportIconPainter(glyph, color)),
  );
}

class _ReportIconPainter extends CustomPainter {
  const _ReportIconPainter(this.glyph, this.color);
  final ReportGlyph glyph;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final large = glyph == ReportGlyph.back || glyph == ReportGlyph.forward;
    canvas.save();
    canvas.scale(
      size.width / (large ? 960 : 24),
      size.height / (large ? 960 : 24),
    );
    final p = Path();
    switch (glyph) {
      case ReportGlyph.close:
        p
          ..moveTo(19, 6.41)
          ..lineTo(17.59, 5)
          ..lineTo(12, 10.59)
          ..lineTo(6.41, 5)
          ..lineTo(5, 6.41)
          ..lineTo(10.59, 12)
          ..lineTo(5, 17.59)
          ..lineTo(6.41, 19)
          ..lineTo(12, 13.41)
          ..lineTo(17.59, 19)
          ..lineTo(19, 17.59)
          ..lineTo(13.41, 12)
          ..close();
      case ReportGlyph.download:
        p
          ..moveTo(19, 9)
          ..lineTo(15, 9)
          ..lineTo(15, 3)
          ..lineTo(9, 3)
          ..lineTo(9, 9)
          ..lineTo(5, 9)
          ..lineTo(12, 16)
          ..close()
          ..moveTo(5, 18)
          ..lineTo(5, 20)
          ..lineTo(19, 20)
          ..lineTo(19, 18)
          ..close();
      case ReportGlyph.back:
        p
          ..moveTo(313, 520)
          ..lineTo(537, 744)
          ..lineTo(480, 800)
          ..lineTo(160, 480)
          ..lineTo(480, 160)
          ..lineTo(537, 216)
          ..lineTo(313, 440)
          ..lineTo(800, 440)
          ..lineTo(800, 520)
          ..close();
      case ReportGlyph.forward:
        p
          ..moveTo(647, 520)
          ..lineTo(160, 520)
          ..lineTo(160, 440)
          ..lineTo(647, 440)
          ..lineTo(423, 216)
          ..lineTo(480, 160)
          ..lineTo(800, 480)
          ..lineTo(480, 800)
          ..lineTo(423, 744)
          ..close();
      case ReportGlyph.calendar:
        p
          ..moveTo(19, 4)
          ..lineTo(18, 4)
          ..lineTo(18, 2)
          ..lineTo(16, 2)
          ..lineTo(16, 4)
          ..lineTo(8, 4)
          ..lineTo(8, 2)
          ..lineTo(6, 2)
          ..lineTo(6, 4)
          ..lineTo(5, 4)
          ..cubicTo(3.89, 4, 3.01, 4.9, 3.01, 6)
          ..lineTo(3, 20)
          ..cubicTo(3, 21.1, 3.89, 22, 5, 22)
          ..lineTo(19, 22)
          ..cubicTo(20.1, 22, 21, 21.1, 21, 20)
          ..lineTo(21, 6)
          ..cubicTo(21, 4.9, 20.1, 4, 19, 4)
          ..close()
          ..moveTo(19, 20)
          ..lineTo(5, 20)
          ..lineTo(5, 10)
          ..lineTo(19, 10)
          ..close();
        for (final y in [12.0, 16.0]) {
          for (final x in [7.0, 11.0, 15.0]) {
            p
              ..moveTo(x + 2, y + 2)
              ..lineTo(x, y + 2)
              ..lineTo(x, y)
              ..lineTo(x + 2, y)
              ..close();
          }
        }
    }
    canvas.drawPath(p, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ReportIconPainter old) =>
      old.glyph != glyph || old.color != color;
}

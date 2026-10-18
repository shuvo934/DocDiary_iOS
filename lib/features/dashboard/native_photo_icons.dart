import 'package:flutter/material.dart';

// Geometry from the supplied Android drawables; no substitute icon shapes.
enum NativePhotoGlyph {
  camera,
  gallery,
  switchCamera,
  flashOn,
  flashOff,
  shutter,
  close,
}

class NativePhotoIcon extends StatelessWidget {
  const NativePhotoIcon(
    this.glyph, {
    super.key,
    required this.size,
    this.color = Colors.white,
  });
  final NativePhotoGlyph glyph;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _PhotoIconPainter(glyph, color)),
  );
}

class _PhotoIconPainter extends CustomPainter {
  const _PhotoIconPainter(this.glyph, this.color);
  final NativePhotoGlyph glyph;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()..color = color;
    switch (glyph) {
      case NativePhotoGlyph.camera:
        final path0 =
            Path()
              ..moveTo(12, 12)
              ..moveTo(9, 12)
              ..cubicTo(9, 10.34314575, 10.34314575, 9, 12, 9)
              ..cubicTo(13.65685425, 9, 15, 10.34314575, 15, 12)
              ..cubicTo(15, 13.65685425, 13.65685425, 15, 12, 15)
              ..cubicTo(10.34314575, 15, 9, 13.65685425, 9, 12);
        canvas.drawPath(path0, paint);
        final path1 =
            Path()
              ..moveTo(20, 4)
              ..lineTo(16.83, 4)
              ..lineTo(15.59, 2.65)
              ..cubicTo(15.22, 2.24, 14.68, 2, 14.12, 2)
              ..lineTo(9.88, 2)
              ..cubicTo(9.32, 2, 8.78, 2.24, 8.4, 2.65)
              ..lineTo(7.17, 4)
              ..lineTo(4, 4)
              ..cubicTo(2.9, 4, 2, 4.9, 2, 6)
              ..lineTo(2, 18)
              ..cubicTo(2, 19.1, 2.9, 20, 4, 20)
              ..lineTo(20, 20)
              ..cubicTo(21.1, 20, 22, 19.1, 22, 18)
              ..lineTo(22, 6)
              ..cubicTo(22, 4.9, 21.1, 4, 20, 4)
              ..close()
              ..moveTo(12, 17)
              ..cubicTo(9.24, 17, 7, 14.76, 7, 12)
              ..cubicTo(7, 9.24, 9.24, 7, 12, 7)
              ..cubicTo(14.76, 7, 17, 9.24, 17, 12)
              ..cubicTo(17, 14.76, 14.76, 17, 12, 17)
              ..close();
        canvas.drawPath(path1, paint);
        break;
      case NativePhotoGlyph.gallery:
        final path0 =
            Path()
              ..moveTo(21, 19)
              ..lineTo(21, 5)
              ..cubicTo(21, 3.9, 20.1, 3, 19, 3)
              ..lineTo(5, 3)
              ..cubicTo(3.9, 3, 3, 3.9, 3, 5)
              ..lineTo(3, 19)
              ..cubicTo(3, 20.1, 3.9, 21, 5, 21)
              ..lineTo(19, 21)
              ..cubicTo(20.1, 21, 21, 20.1, 21, 19)
              ..close()
              ..moveTo(8.5, 13.5)
              ..lineTo(11, 16.51)
              ..lineTo(14.5, 12)
              ..lineTo(19, 18)
              ..lineTo(5, 18)
              ..lineTo(8.5, 13.5)
              ..close();
        canvas.drawPath(path0, paint);
        break;
      case NativePhotoGlyph.switchCamera:
        final path0 =
            Path()
              ..moveTo(16, 7)
              ..lineTo(15, 7)
              ..lineTo(14, 6)
              ..lineTo(10, 6)
              ..lineTo(9, 7)
              ..lineTo(8, 7)
              ..cubicTo(6.9, 7, 6, 7.9, 6, 9)
              ..lineTo(6, 15)
              ..cubicTo(6, 16.1, 6.9, 17, 8, 17)
              ..lineTo(16, 17)
              ..cubicTo(17.1, 17, 18, 16.1, 18, 15)
              ..lineTo(18, 9)
              ..cubicTo(18, 7.9, 17.1, 7, 16, 7)
              ..close()
              ..moveTo(12, 14)
              ..cubicTo(10.9, 14, 10, 13.1, 10, 12)
              ..cubicTo(10, 10.9, 10.9, 10, 12, 10)
              ..cubicTo(13.1, 10, 14, 10.9, 14, 12)
              ..cubicTo(14, 13.1, 13.1, 14, 12, 14)
              ..close();
        canvas.drawPath(path0, paint);
        final path1 =
            Path()
              ..moveTo(8.57, 0.51)
              ..lineTo(13.05, 4.99)
              ..lineTo(13.05, 2.04)
              ..cubicTo(17.77, 2.51, 21.53, 6.27, 22, 10.99)
              ..cubicTo(22, 10.99, 24, 10.99, 24, 10.99)
              ..cubicTo(23.34, 3.02, 15.49, -1.59, 8.57, 0.51)
              ..close();
        canvas.drawPath(path1, paint);
        final path2 =
            Path()
              ..moveTo(10.95, 21.96)
              ..cubicTo(6.23, 21.49, 2.47, 17.73, 2, 13.01)
              ..cubicTo(2, 13.01, 0, 13.01, 0, 13.01)
              ..cubicTo(0.66, 20.98, 8.51, 25.59, 15.43, 23.49)
              ..lineTo(10.95, 19.01)
              ..lineTo(10.95, 21.96)
              ..close();
        canvas.drawPath(path2, paint);
        break;
      case NativePhotoGlyph.flashOn:
        final path0 =
            Path()
              ..moveTo(7, 2)
              ..lineTo(7, 13)
              ..lineTo(10, 13)
              ..lineTo(10, 22)
              ..lineTo(17, 10)
              ..lineTo(13, 10)
              ..lineTo(17, 2)
              ..lineTo(7, 2)
              ..close();
        canvas.drawPath(path0, paint);
        break;
      case NativePhotoGlyph.flashOff:
        final path0 =
            Path()
              ..moveTo(3.27, 3)
              ..lineTo(2, 4.27)
              ..lineTo(7, 9.27)
              ..lineTo(7, 13)
              ..lineTo(10, 13)
              ..lineTo(10, 22)
              ..lineTo(13.58, 15.86)
              ..lineTo(17.73, 20)
              ..lineTo(19, 18.73)
              ..lineTo(3.27, 3)
              ..close()
              ..moveTo(17, 10)
              ..lineTo(13, 10)
              ..lineTo(17, 2)
              ..lineTo(7, 2)
              ..lineTo(7, 4.18)
              ..lineTo(15.46, 12.64)
              ..lineTo(17, 10)
              ..close();
        canvas.drawPath(path0, paint);
        break;
      case NativePhotoGlyph.shutter:
        final path0 =
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
        canvas.drawPath(path0, paint);
        break;
      case NativePhotoGlyph.close:
        final path0 =
            Path()
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
              ..lineTo(19, 6.41)
              ..close();
        canvas.drawPath(path0, paint);
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PhotoIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

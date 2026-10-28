// Vector portions: Copyright (C) 2026 The Android Open Source Project.
// Licensed under the Apache License, Version 2.0.
// https://www.apache.org/licenses/LICENSE-2.0
// See licenses/DYNAMIC_RX_APACHE_2.0.txt in this patch.
import 'package:flutter/material.dart';

// Converted directly from the supplied Android drawables.
// Preserve original geometry, raster bytes and source filenames.
enum DynamicRxGlyph {
  vitals,
  complain,
  objective,
  clinicalFindings,
  expandLess,
  expandMore,
  add,
  close,
  edit,
  delete,
  dropdown,
  injury,
  diagnosis,
  drugHistory,
  investigation,
  importantInfo,
  pill,
  therapy,
  medicineLocked,
  treatmentPlan,
  advice,
  followUp,
  specialAlert,
  reference,
  notes,
  stethoscope,
  reviewReady,
  reviewAttention,
}

class NativeDynamicRxIcon extends StatelessWidget {
  const NativeDynamicRxIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    this.color = const Color(0xff16a085),
  });
  final DynamicRxGlyph glyph;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final asset = switch (glyph) {
      DynamicRxGlyph.injury => 'assets/images/dy_rx_patient.png',
      DynamicRxGlyph.diagnosis => 'assets/images/dy_rx_diagnosis.png',
      DynamicRxGlyph.drugHistory => 'assets/images/dy_rx_medicine.png',
      DynamicRxGlyph.investigation => 'assets/images/dy_rx_chemistry.png',
      DynamicRxGlyph.importantInfo => 'assets/images/dy_rx_caution.png',
      DynamicRxGlyph.pill => 'assets/images/dy_rx_pill.png',
      DynamicRxGlyph.treatmentPlan => 'assets/images/dy_rx_treatment_plan.png',
      DynamicRxGlyph.stethoscope => 'assets/images/dy_rx_stethoscope.png',
      _ => null,
    };
    return SizedBox.square(
      dimension: size,
      child:
          asset == null
              ? CustomPaint(painter: _NativeDynamicRxPainter(glyph, color))
              : Image.asset(
                asset,
                fit: BoxFit.contain,
                color: color,
                colorBlendMode: BlendMode.srcIn,
              ),
    );
  }
}

class _NativeDynamicRxPainter extends CustomPainter {
  const _NativeDynamicRxPainter(this.glyph, this.color);
  final DynamicRxGlyph glyph;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final paint = Paint()..color = color;
    switch (glyph) {
      case DynamicRxGlyph.vitals:
        // ic_vitals_24.xml (960 x 960)
        canvas.scale(size.width / 960, size.height / 960);
        final path0 =
            Path()
              ..moveTo(480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..lineTo(480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..lineTo(480, 480)
              ..lineTo(480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..lineTo(480, 480)
              ..lineTo(480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..lineTo(480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..lineTo(480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..lineTo(480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..quadraticBezierTo(480, 480, 480, 480)
              ..close()
              ..moveTo(480, 840)
              ..quadraticBezierTo(462, 840, 445.5, 833.5)
              ..quadraticBezierTo(429, 827, 416, 814)
              ..lineTo(148, 545)
              ..quadraticBezierTo(113, 510, 96.5, 465)
              ..quadraticBezierTo(80, 420, 80, 371)
              ..quadraticBezierTo(80, 268, 147, 194)
              ..quadraticBezierTo(214, 120, 314, 120)
              ..quadraticBezierTo(362, 120, 404.5, 139)
              ..quadraticBezierTo(447, 158, 480, 192)
              ..lineTo(480, 192)
              ..lineTo(480, 192)
              ..quadraticBezierTo(512, 158, 554.5, 139)
              ..quadraticBezierTo(597, 120, 645, 120)
              ..quadraticBezierTo(745, 120, 812.5, 194)
              ..quadraticBezierTo(880, 268, 880, 370)
              ..quadraticBezierTo(880, 419, 863, 464)
              ..quadraticBezierTo(846, 509, 812, 544)
              ..lineTo(543, 814)
              ..quadraticBezierTo(530, 827, 514, 833.5)
              ..quadraticBezierTo(498, 840, 480, 840)
              ..close()
              ..moveTo(520, 320)
              ..quadraticBezierTo(530, 320, 539, 325)
              ..quadraticBezierTo(548, 330, 553, 338)
              ..lineTo(621, 440)
              ..lineTo(787, 440)
              ..quadraticBezierTo(794, 423, 797.5, 405.5)
              ..quadraticBezierTo(801, 388, 801, 370)
              ..quadraticBezierTo(799, 301, 755, 251.5)
              ..quadraticBezierTo(711, 202, 645, 202)
              ..quadraticBezierTo(614, 202, 585.5, 214)
              ..quadraticBezierTo(557, 226, 536, 249)
              ..lineTo(509, 278)
              ..quadraticBezierTo(504, 284, 496, 287.5)
              ..quadraticBezierTo(488, 291, 480, 291)
              ..quadraticBezierTo(472, 291, 464, 287.5)
              ..quadraticBezierTo(456, 284, 450, 278)
              ..lineTo(423, 249)
              ..quadraticBezierTo(402, 226, 374, 213)
              ..quadraticBezierTo(346, 200, 314, 200)
              ..quadraticBezierTo(248, 200, 204, 250.5)
              ..quadraticBezierTo(160, 301, 160, 370)
              ..quadraticBezierTo(160, 388, 163, 405.5)
              ..quadraticBezierTo(166, 423, 173, 440)
              ..lineTo(360, 440)
              ..quadraticBezierTo(370, 440, 379, 445)
              ..quadraticBezierTo(388, 450, 393, 458)
              ..lineTo(428, 510)
              ..lineTo(482, 348)
              ..quadraticBezierTo(486, 336, 496.5, 328)
              ..quadraticBezierTo(507, 320, 520, 320)
              ..close()
              ..moveTo(532, 450)
              ..lineTo(478, 612)
              ..quadraticBezierTo(474, 624, 463, 632)
              ..quadraticBezierTo(452, 640, 439, 640)
              ..quadraticBezierTo(429, 640, 420, 635)
              ..quadraticBezierTo(411, 630, 406, 622)
              ..lineTo(338, 520)
              ..lineTo(236, 520)
              ..lineTo(473, 757)
              ..quadraticBezierTo(475, 759, 476.5, 759.5)
              ..quadraticBezierTo(478, 760, 480, 760)
              ..quadraticBezierTo(482, 760, 483.5, 759.5)
              ..quadraticBezierTo(485, 759, 487, 757)
              ..lineTo(723, 520)
              ..lineTo(600, 520)
              ..quadraticBezierTo(590, 520, 581, 515)
              ..quadraticBezierTo(572, 510, 566, 502)
              ..lineTo(532, 450)
              ..close();
        canvas.drawPath(path0, paint);
        break;
      case DynamicRxGlyph.complain:
        // ic_complaint_24.xml (24 x 24)
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(20, 2)
              ..lineTo(4, 2)
              ..cubicTo(2.9, 2, 2, 2.9, 2, 4)
              ..lineTo(2, 22)
              ..lineTo(6, 18)
              ..lineTo(20, 18)
              ..cubicTo(21.1, 18, 22, 17.1, 22, 16)
              ..lineTo(22, 4)
              ..cubicTo(22, 2.9, 21.1, 2, 20, 2)
              ..close()
              ..moveTo(20, 16)
              ..lineTo(6, 16)
              ..lineTo(4, 18)
              ..lineTo(4, 4)
              ..lineTo(20, 4)
              ..lineTo(20, 16)
              ..close();
        canvas.drawPath(path0, paint);
        break;
      case DynamicRxGlyph.objective:
        // ic_objective_info_24.xml (24 x 24)
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(7, 15)
              ..lineTo(14, 15)
              ..lineTo(14, 17)
              ..lineTo(7, 17)
              ..close()
              ..moveTo(7, 11)
              ..lineTo(17, 11)
              ..lineTo(17, 13)
              ..lineTo(7, 13)
              ..close()
              ..moveTo(7, 7)
              ..lineTo(17, 7)
              ..lineTo(17, 9)
              ..lineTo(7, 9)
              ..close()
              ..moveTo(19, 3)
              ..lineTo(14.82, 3)
              ..cubicTo(14.4, 1.84, 13.3, 1, 12, 1)
              ..cubicTo(10.7, 1, 9.6, 1.84, 9.18, 3)
              ..lineTo(5, 3)
              ..cubicTo(4.86, 3, 4.73, 3.01, 4.6, 3.04)
              ..cubicTo(4.21, 3.12, 3.86, 3.32, 3.59, 3.59)
              ..cubicTo(3.41, 3.77, 3.26, 3.99, 3.16, 4.23)
              ..cubicTo(3.06, 4.46, 3, 4.72, 3, 5)
              ..lineTo(3, 19)
              ..cubicTo(3, 19.27, 3.06, 19.54, 3.16, 19.78)
              ..cubicTo(3.26, 20.02, 3.41, 20.23, 3.59, 20.42)
              ..cubicTo(3.86, 20.69, 4.21, 20.89, 4.6, 20.97)
              ..cubicTo(4.73, 20.99, 4.86, 21, 5, 21)
              ..lineTo(19, 21)
              ..cubicTo(20.1, 21, 21, 20.1, 21, 19)
              ..lineTo(21, 5)
              ..cubicTo(21, 3.9, 20.1, 3, 19, 3)
              ..close()
              ..moveTo(12, 2.75)
              ..cubicTo(12.41, 2.75, 12.75, 3.09, 12.75, 3.5)
              ..cubicTo(12.75, 3.91, 12.41, 4.25, 12, 4.25)
              ..cubicTo(11.59, 4.25, 11.25, 3.91, 11.25, 3.5)
              ..cubicTo(11.25, 3.09, 11.59, 2.75, 12, 2.75)
              ..close()
              ..moveTo(19, 19)
              ..lineTo(5, 19)
              ..lineTo(5, 5)
              ..lineTo(19, 5)
              ..lineTo(19, 19)
              ..close();
        canvas.drawPath(path0, paint);
        break;
      case DynamicRxGlyph.clinicalFindings:
        // ic_clinical_findings_24.xml (960 x 960)
        canvas.scale(size.width / 960, size.height / 960);
        final path0 =
            Path()
              ..moveTo(160, 840)
              ..quadraticBezierTo(127, 840, 103.5, 816.5)
              ..quadraticBezierTo(80, 793, 80, 760)
              ..lineTo(80, 200)
              ..quadraticBezierTo(80, 167, 103.5, 143.5)
              ..quadraticBezierTo(127, 120, 160, 120)
              ..lineTo(800, 120)
              ..quadraticBezierTo(833, 120, 856.5, 143.5)
              ..quadraticBezierTo(880, 167, 880, 200)
              ..lineTo(880, 760)
              ..quadraticBezierTo(880, 793, 856.5, 816.5)
              ..quadraticBezierTo(833, 840, 800, 840)
              ..lineTo(160, 840)
              ..close()
              ..moveTo(160, 760)
              ..lineTo(800, 760)
              ..quadraticBezierTo(800, 760, 800, 760)
              ..quadraticBezierTo(800, 760, 800, 760)
              ..lineTo(800, 200)
              ..quadraticBezierTo(800, 200, 800, 200)
              ..quadraticBezierTo(800, 200, 800, 200)
              ..lineTo(160, 200)
              ..quadraticBezierTo(160, 200, 160, 200)
              ..quadraticBezierTo(160, 200, 160, 200)
              ..lineTo(160, 760)
              ..quadraticBezierTo(160, 760, 160, 760)
              ..quadraticBezierTo(160, 760, 160, 760)
              ..close()
              ..moveTo(200, 680)
              ..lineTo(400, 680)
              ..lineTo(400, 600)
              ..lineTo(200, 600)
              ..lineTo(200, 680)
              ..close()
              ..moveTo(582, 600)
              ..lineTo(780, 402)
              ..lineTo(723, 345)
              ..lineTo(582, 487)
              ..lineTo(525, 430)
              ..lineTo(469, 487)
              ..lineTo(582, 600)
              ..close()
              ..moveTo(200, 520)
              ..lineTo(400, 520)
              ..lineTo(400, 440)
              ..lineTo(200, 440)
              ..lineTo(200, 520)
              ..close()
              ..moveTo(200, 360)
              ..lineTo(400, 360)
              ..lineTo(400, 280)
              ..lineTo(200, 280)
              ..lineTo(200, 360)
              ..close()
              ..moveTo(160, 760)
              ..lineTo(160, 760)
              ..quadraticBezierTo(160, 760, 160, 760)
              ..quadraticBezierTo(160, 760, 160, 760)
              ..lineTo(160, 200)
              ..quadraticBezierTo(160, 200, 160, 200)
              ..quadraticBezierTo(160, 200, 160, 200)
              ..lineTo(160, 200)
              ..quadraticBezierTo(160, 200, 160, 200)
              ..quadraticBezierTo(160, 200, 160, 200)
              ..lineTo(160, 760)
              ..quadraticBezierTo(160, 760, 160, 760)
              ..quadraticBezierTo(160, 760, 160, 760)
              ..close();
        canvas.drawPath(path0, paint);
        break;
      case DynamicRxGlyph.expandLess:
        // ic_expand_less_24.xml (24 x 24)
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(12, 8)
              ..lineTo(6, 14)
              ..lineTo(7.41, 15.41)
              ..lineTo(12, 10.83)
              ..lineTo(16.59, 15.41)
              ..lineTo(18, 14)
              ..close();
        canvas.drawPath(path0, paint);
        break;
      case DynamicRxGlyph.expandMore:
        // ic_expand_more_24.xml (24 x 24)
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(16.59, 8.59)
              ..lineTo(12, 13.17)
              ..lineTo(7.41, 8.59)
              ..lineTo(6, 10)
              ..lineTo(12, 16)
              ..lineTo(18, 10)
              ..close();
        canvas.drawPath(path0, paint);
        break;
      case DynamicRxGlyph.add:
        // add_24.xml (24 x 24)
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(19, 13)
              ..lineTo(13, 13)
              ..lineTo(13, 19)
              ..lineTo(11, 19)
              ..lineTo(11, 13)
              ..lineTo(5, 13)
              ..lineTo(5, 11)
              ..lineTo(11, 11)
              ..lineTo(11, 5)
              ..lineTo(13, 5)
              ..lineTo(13, 11)
              ..lineTo(19, 11)
              ..lineTo(19, 13)
              ..close();
        canvas.drawPath(path0, paint);
        break;
      case DynamicRxGlyph.close:
        // close_24.xml (24 x 24)
        canvas.scale(size.width / 24, size.height / 24);
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
              ..close();
        canvas.drawPath(path0, paint);
        break;
      case DynamicRxGlyph.edit:
        // edit_24.xml (24 x 24)
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(3, 17.25)
              ..lineTo(3, 21)
              ..lineTo(6.75, 21)
              ..lineTo(17.81, 9.94)
              ..lineTo(14.06, 6.19)
              ..lineTo(3, 17.25)
              ..close()
              ..moveTo(20.71, 7.04)
              ..cubicTo(21.1, 6.65, 21.1, 6.02, 20.71, 5.63)
              ..lineTo(18.37, 3.29)
              ..cubicTo(17.98, 2.9, 17.35, 2.9, 16.96, 3.29)
              ..lineTo(15.13, 5.12)
              ..lineTo(18.88, 8.87)
              ..lineTo(20.71, 7.04)
              ..close();
        canvas.drawPath(path0, paint);
        break;
      case DynamicRxGlyph.delete:
        // ic_delete_24.xml (24 x 24)
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(6, 19)
              ..cubicTo(6, 20.1, 6.9, 21, 8, 21)
              ..lineTo(16, 21)
              ..cubicTo(17.1, 21, 18, 20.1, 18, 19)
              ..lineTo(18, 7)
              ..lineTo(6, 7)
              ..lineTo(6, 19)
              ..close()
              ..moveTo(19, 4)
              ..lineTo(15.5, 4)
              ..lineTo(14.5, 3)
              ..lineTo(9.5, 3)
              ..lineTo(8.5, 4)
              ..lineTo(5, 4)
              ..lineTo(5, 6)
              ..lineTo(19, 6)
              ..lineTo(19, 4)
              ..close();
        canvas.drawPath(path0, paint);
        break;
      case DynamicRxGlyph.dropdown:
        // arrow_drop_down_24.xml (24 x 24)
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(7, 10)
              ..lineTo(12, 15)
              ..lineTo(17, 10)
              ..close();
        canvas.drawPath(path0, paint);
        break;
      case DynamicRxGlyph.therapy:
        // ic_therapy_24.xml: original Android vector geometry (24 x 24).
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(12, 2)
              ..arcToPoint(
                Offset(12, 6.5),
                radius: Radius.elliptical(2.25, 2.25),
                rotation: 0,
                largeArc: true,
                clockwise: false,
              )
              ..arcToPoint(
                Offset(12, 2),
                radius: Radius.elliptical(2.25, 2.25),
                rotation: 0,
                largeArc: true,
                clockwise: false,
              )
              ..close();
        canvas.drawPath(path0, paint);
        final path1 =
            Path()
              ..moveTo(20.5, 7)
              ..lineTo(15.8, 7)
              ..lineTo(13.5, 8.6)
              ..lineTo(10.5, 8.6)
              ..lineTo(8.2, 7)
              ..lineTo(3.5, 7)
              ..cubicTo(2.67, 7, 2, 7.67, 2, 8.5)
              ..cubicTo(2, 9.33, 2.67, 10, 3.5, 10)
              ..lineTo(7.3, 10)
              ..lineTo(9, 11.2)
              ..lineTo(9, 15)
              ..lineTo(6.3, 20.1)
              ..cubicTo(5.9, 20.84, 6.18, 21.76, 6.92, 22.15)
              ..cubicTo(7.66, 22.54, 8.58, 22.26, 8.97, 21.52)
              ..lineTo(12, 16.1)
              ..lineTo(15.03, 21.52)
              ..cubicTo(15.42, 22.26, 16.34, 22.54, 17.08, 22.15)
              ..cubicTo(17.82, 21.76, 18.1, 20.84, 17.7, 20.1)
              ..lineTo(15, 15)
              ..lineTo(15, 11.2)
              ..lineTo(16.7, 10)
              ..lineTo(20.5, 10)
              ..cubicTo(21.33, 10, 22, 9.33, 22, 8.5)
              ..cubicTo(22, 7.67, 21.33, 7, 20.5, 7)
              ..close();
        canvas.drawPath(path1, paint);
        break;
      case DynamicRxGlyph.medicineLocked:
        // ic_medicine_locked_24.xml: original Android vector geometry (24 x 24).
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(17, 8)
              ..lineTo(16, 8)
              ..lineTo(16, 6)
              ..cubicTo(16, 3.24, 13.76, 1, 11, 1)
              ..cubicTo(8.24, 1, 6, 3.24, 6, 6)
              ..lineTo(6, 8)
              ..lineTo(5, 8)
              ..cubicTo(3.9, 8, 3, 8.9, 3, 10)
              ..lineTo(3, 20)
              ..cubicTo(3, 21.1, 3.9, 22, 5, 22)
              ..lineTo(17, 22)
              ..cubicTo(18.1, 22, 19, 21.1, 19, 20)
              ..lineTo(19, 10)
              ..cubicTo(19, 8.9, 18.1, 8, 17, 8)
              ..close()
              ..moveTo(11, 17)
              ..cubicTo(9.9, 17, 9, 16.1, 9, 15)
              ..cubicTo(9, 13.9, 9.9, 13, 11, 13)
              ..cubicTo(12.1, 13, 13, 13.9, 13, 15)
              ..cubicTo(13, 16.1, 12.1, 17, 11, 17)
              ..close()
              ..moveTo(14.1, 8)
              ..lineTo(7.9, 8)
              ..lineTo(7.9, 6)
              ..cubicTo(7.9, 4.29, 9.29, 2.9, 11, 2.9)
              ..cubicTo(12.71, 2.9, 14.1, 4.29, 14.1, 6)
              ..lineTo(14.1, 8)
              ..close();
        canvas.drawPath(path0, paint);
        break;
      case DynamicRxGlyph.advice:
        // ic_advice_24.xml: original native fill/stroke geometry; XML tint is green_sea.
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(5, 3)
              ..lineTo(19, 3)
              ..cubicTo(20.1, 3, 21, 3.9, 21, 5)
              ..lineTo(21, 15)
              ..cubicTo(21, 16.1, 20.1, 17, 19, 17)
              ..lineTo(16, 17)
              ..lineTo(12, 21)
              ..lineTo(8, 17)
              ..lineTo(5, 17)
              ..cubicTo(3.9, 17, 3, 16.1, 3, 15)
              ..lineTo(3, 5)
              ..cubicTo(3, 3.9, 3.9, 3, 5, 3)
              ..close();
        canvas.drawPath(
          path0,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.butt
            ..strokeJoin = StrokeJoin.round,
        );
        final path1 =
            Path()
              ..moveTo(7, 8)
              ..lineTo(17, 8)
              ..moveTo(7, 12)
              ..lineTo(14, 12);
        canvas.drawPath(
          path1,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.miter,
        );
        break;
      case DynamicRxGlyph.followUp:
        // ic_follow_up_24.xml: original native fill/stroke geometry; XML tint is green_sea.
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(6, 4.5)
              ..lineTo(18, 4.5)
              ..cubicTo(19.1, 4.5, 20, 5.4, 20, 6.5)
              ..lineTo(20, 19)
              ..cubicTo(20, 20.1, 19.1, 21, 18, 21)
              ..lineTo(6, 21)
              ..cubicTo(4.9, 21, 4, 20.1, 4, 19)
              ..lineTo(4, 6.5)
              ..cubicTo(4, 5.4, 4.9, 4.5, 6, 4.5)
              ..close();
        canvas.drawPath(
          path0,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.butt
            ..strokeJoin = StrokeJoin.round,
        );
        final path1 =
            Path()
              ..moveTo(8, 2.5)
              ..lineTo(8, 6.5)
              ..moveTo(16, 2.5)
              ..lineTo(16, 6.5)
              ..moveTo(4, 9)
              ..lineTo(20, 9);
        canvas.drawPath(
          path1,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.miter,
        );
        final path2 =
            Path()
              ..moveTo(8, 14)
              ..lineTo(10.5, 16.5)
              ..lineTo(16, 11);
        canvas.drawPath(
          path2,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        break;
      case DynamicRxGlyph.specialAlert:
        // ic_special_alert_24.xml: original native fill/stroke geometry; XML tint is green_sea.
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(12, 3)
              ..lineTo(22, 20)
              ..lineTo(2, 20)
              ..close();
        canvas.drawPath(
          path0,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.butt
            ..strokeJoin = StrokeJoin.round,
        );
        final path1 =
            Path()
              ..moveTo(12, 9)
              ..lineTo(12, 14);
        canvas.drawPath(
          path1,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.miter,
        );
        final path2 =
            Path()
              ..moveTo(12, 16.5)
              ..arcToPoint(
                Offset(12, 18.5),
                radius: Radius.elliptical(1, 1),
                rotation: 0,
                largeArc: true,
                clockwise: false,
              )
              ..arcToPoint(
                Offset(12, 16.5),
                radius: Radius.elliptical(1, 1),
                rotation: 0,
                largeArc: true,
                clockwise: false,
              )
              ..close();
        canvas.drawPath(path2, Paint()..color = color);
        break;
      case DynamicRxGlyph.reference:
        // ic_reference_24.xml: original native fill/stroke geometry; XML tint is green_sea.
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(3, 5.5)
              ..cubicTo(6, 4.5, 8.5, 4.8, 11.5, 6.5)
              ..lineTo(11.5, 20)
              ..cubicTo(8.5, 18.3, 6, 18, 3, 19)
              ..close();
        canvas.drawPath(
          path0,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.butt
            ..strokeJoin = StrokeJoin.round,
        );
        final path1 =
            Path()
              ..moveTo(21, 5.5)
              ..cubicTo(18, 4.5, 15.5, 4.8, 12.5, 6.5)
              ..lineTo(12.5, 20)
              ..cubicTo(15.5, 18.3, 18, 18, 21, 19)
              ..close();
        canvas.drawPath(
          path1,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.butt
            ..strokeJoin = StrokeJoin.round,
        );
        break;
      case DynamicRxGlyph.notes:
        // ic_notes_24.xml: original native fill/stroke geometry; XML tint is green_sea.
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(6, 2)
              ..lineTo(14, 2)
              ..lineTo(19, 7)
              ..lineTo(19, 22)
              ..lineTo(6, 22)
              ..close();
        canvas.drawPath(
          path0,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.butt
            ..strokeJoin = StrokeJoin.round,
        );
        final path1 =
            Path()
              ..moveTo(14, 2)
              ..lineTo(14, 7)
              ..lineTo(19, 7)
              ..moveTo(9, 12)
              ..lineTo(16, 12)
              ..moveTo(9, 16)
              ..lineTo(16, 16);
        canvas.drawPath(
          path1,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        break;
      case DynamicRxGlyph.reviewReady:
        // ic_review_ready_24.xml: original Android vector geometry.
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(9, 16.2)
              ..lineTo(4.8, 12)
              ..lineTo(3.4, 13.4)
              ..lineTo(9, 19)
              ..lineTo(21, 7)
              ..lineTo(19.6, 5.6)
              ..close();
        canvas.drawPath(path0, paint);
        break;
      case DynamicRxGlyph.reviewAttention:
        // ic_review_attention_24.xml: original Android vector geometry.
        canvas.scale(size.width / 24, size.height / 24);
        final path0 =
            Path()
              ..moveTo(11, 5)
              ..lineTo(13, 5)
              ..lineTo(13, 14)
              ..lineTo(11, 14)
              ..close();
        canvas.drawPath(path0, paint);
        final path1 =
            Path()
              ..moveTo(12, 16)
              ..arcToPoint(
                Offset(12, 18.8),
                radius: Radius.elliptical(1.4, 1.4),
                rotation: 0,
                largeArc: true,
                clockwise: false,
              )
              ..arcToPoint(
                Offset(12, 16),
                radius: Radius.elliptical(1.4, 1.4),
                rotation: 0,
                largeArc: true,
                clockwise: false,
              )
              ..close();
        canvas.drawPath(path1, paint);
        break;
      default:
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NativeDynamicRxPainter oldDelegate) =>
      glyph != oldDelegate.glyph || color != oldDelegate.color;
}

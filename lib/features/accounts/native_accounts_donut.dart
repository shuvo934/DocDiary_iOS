import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'accounts_dashboard_models.dart';

const accountsVoucherColors = <Color>[
  Color(0xff81ecec),
  Color(0xff74b9ff),
  Color(0xffffeaa7),
  Color(0xffdfe6e9),
  Color(0xffffeaa7),
  Color(0xfffab1a0),
  Color(0xffb2bec3),
  Color(0xff81ecec),
  Color(0xffff7675),
  Color(0xfffd79a8),
  Color(0xff60a3bc),
];

class AccountsPieSlice {
  const AccountsPieSlice(this.label, this.value, this.color);
  final String label;
  final AccountsNumber value;
  final Color color;
}

class NativeAccountsDonut extends StatefulWidget {
  const NativeAccountsDonut({
    super.key,
    required this.title,
    required this.slices,
    required this.scale,
    this.onTap,
    this.whiteValues = false,
    this.centerText,
    this.allowRotation = false,
    this.pieWidthFraction = .68,
  });
  final String title;
  final List<AccountsPieSlice> slices;
  final double scale;
  final VoidCallback? onTap;
  final bool whiteValues;
  final String? centerText;
  final bool allowRotation;
  final double pieWidthFraction;
  @override
  State<NativeAccountsDonut> createState() => _DonutState();
}

class _DonutState extends State<NativeAccountsDonut> {
  double _rotation = 0;
  @override
  Widget build(BuildContext context) {
    final empty = widget.slices.isEmpty;
    final zoom = MediaQuery.textScalerOf(context);
    final accessible = zoom.scale(12) > 18;
    final label =
        empty
            ? '${widget.title}. No Data'
            : '${widget.title}. ${widget.slices.map((s) => '${s.label}: ${s.value.text}').join('. ')}';
    Widget legend() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final slice in widget.slices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: slice.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      slice.label,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 10 * widget.scale,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    return Semantics(
      label: label,
      button: widget.onTap != null,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final diameter = math.min(
            285 * widget.scale,
            constraints.maxWidth * widget.pieWidthFraction - 16,
          );
          final pie = SizedBox(
            width: diameter + 16,
            height: diameter + 16,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                key: Key(
                  widget.whiteValues
                      ? 'accounts_income_pie'
                      : 'accounts_voucher_pie',
                ),
                onTap: widget.onTap,
                onHorizontalDragUpdate:
                    !widget.allowRotation && widget.onTap == null
                        ? null
                        : (details) =>
                            setState(() => _rotation += details.delta.dx / 100),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(
                    widget.slices
                        .map((s) => '${s.label}:${s.value.text}')
                        .join('|'),
                  ),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(seconds: 1),
                  builder:
                      (context, progress, _) => CustomPaint(
                        painter: _PiePainter(
                          slices: widget.slices,
                          title:
                              empty
                                  ? 'No Data'
                                  : (widget.centerText ??
                                      widget.title.replaceAll('/', '/\n')),
                          scale: widget.scale,
                          zoom: zoom,
                          whiteValues: widget.whiteValues,
                          rotation: _rotation,
                          progress: progress,
                        ),
                      ),
                ),
              ),
            ),
          );
          return accessible
              ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [pie, if (!empty) legend()],
              )
              : Row(
                children: [
                  pie,
                  if (!empty) Expanded(child: legend()) else const Spacer(),
                ],
              );
        },
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({
    required this.slices,
    required this.title,
    required this.scale,
    required this.zoom,
    required this.whiteValues,
    required this.rotation,
    required this.progress,
  });
  final List<AccountsPieSlice> slices;
  final String title;
  final double scale, rotation, progress;
  final TextScaler zoom;
  final bool whiteValues;
  void _text(
    Canvas canvas,
    String value,
    Offset center,
    double size,
    Color color,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: size,
          height: 1.15,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      textScaler: zoom,
    );
    painter.layout();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final fit = math.min(
      1.0,
      math.min(
        maxWidth / math.max(1, painter.width),
        maxWidth / math.max(1, painter.height),
      ),
    );
    canvas.scale(fit);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero), radius = size.shortestSide / 2;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    var start = -math.pi / 2 + rotation;
    final total = slices.fold(0.0, (sum, s) => sum + s.value.plot);
    if (total == 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = const Color(0xffb2bec3),
      );
    } else {
      for (final slice in slices) {
        final sweep = slice.value.plot / total * math.pi * 2 * progress;
        canvas.drawArc(
          bounds,
          start,
          sweep,
          true,
          Paint()..color = slice.color,
        );
        if (progress > .95 && sweep > .04) {
          final angle = start + sweep / 2;
          final point =
              center + Offset(math.cos(angle), math.sin(angle)) * radius * .7;
          _text(
            canvas,
            slice.value.text,
            point,
            10 * scale,
            whiteValues ? Colors.white : Colors.black,
            radius * .65,
          );
        }
        start += sweep;
      }
    }
    canvas.drawCircle(center, radius * .4, Paint()..color = Colors.white);
    _text(canvas, title, center, 11 * scale, Colors.black, radius * .77);
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => true;
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'leave_balance_models.dart';

// MPAndroidChart v3.1.0 ColorTemplate.VORDIPLOM_COLORS [3], [2], [0].
const leaveBalanceChartColors = [
  Color(0xff8ceaff),
  Color(0xffffd08c),
  Color(0xffc0ff8c),
];
const leaveBalanceChartLabels = ['Total Leave', 'Consumed', 'Balance'];

class NativeLeaveBalanceChart extends StatelessWidget {
  const NativeLeaveBalanceChart({super.key, required this.rows});
  final List<LeaveBalanceChartRow> rows;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'No chart data available.',
          key: Key('leave_balance_no_chart'),
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            color: Color(0xfff7a35c),
          ),
        ),
      );
    }
    return Semantics(
      label: rows
          .map(
            (r) =>
                '${r.code}: Total Leave ${leaveBalanceBarLabel(r.total)}, '
                'Consumed ${leaveBalanceBarLabel(r.consumed)}, Balance ${leaveBalanceBarLabel(r.balance)}',
          )
          .join('; '),
      child: Column(
        children: [
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: CustomPaint(
                key: const Key('leave_balance_bar_chart'),
                painter: _LeaveBarPainter(
                  rows: rows,
                  scaler: MediaQuery.textScalerOf(context),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 20),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 4,
              children: [
                for (var i = 0; i < 3; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 8,
                        height: 8,
                        child: ColoredBox(color: leaveBalanceChartColors[i]),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        leaveBalanceChartLabels[i],
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveBarPainter extends CustomPainter {
  const _LeaveBarPainter({required this.rows, required this.scaler});
  final List<LeaveBalanceChartRow> rows;
  final TextScaler scaler;
  TextPainter label(String text, {double size = 10}) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: scaler.scale(size),
        color: Colors.black,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  @override
  void paint(Canvas canvas, Size size) {
    var maximum = 0.0;
    for (final r in rows) {
      maximum = math.max(
        maximum,
        math.max(r.total, math.max(r.consumed, r.balance)),
      );
    }
    maximum = maximum <= 0 ? 1 : maximum * 1.1;
    final largest = label(leaveBalanceBarLabel(maximum), size: 10);
    final left = math.min(size.width * .25, math.max(25.0, largest.width + 7));
    final fontHeight = label('CL').height;
    final plot = Rect.fromLTRB(
      left,
      fontHeight + 6,
      math.max(left + 1, size.width - 8),
      math.max(fontHeight + 8, size.height - fontHeight - 10),
    );
    final grid =
        Paint()
          ..color = const Color(0xff808080)
          ..strokeWidth = .5;
    for (var tick = 0; tick <= 5; tick++) {
      final y = plot.bottom - plot.height * tick / 5;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final text = label(
        (maximum * tick / 5).toStringAsFixed(maximum >= 10 ? 0 : 1),
      );
      text.paint(
        canvas,
        Offset(plot.left - text.width - 5, y - text.height / 2),
      );
    }
    canvas.drawLine(plot.topLeft, plot.bottomLeft, grid);
    final groupWidth = plot.width / rows.length;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i], values = [row.total, row.consumed, row.balance];
      final groupX = plot.left + groupWidth * i;
      for (var series = 0; series < 3; series++) {
        final x = groupX + groupWidth * (.02 + series * .32 + .015);
        final barWidth = groupWidth * .29;
        final y =
            plot.bottom - (values[series] / maximum).clamp(0, 1) * plot.height;
        canvas.drawRect(
          Rect.fromLTRB(x, y, x + barWidth, plot.bottom),
          Paint()..color = leaveBalanceChartColors[series],
        );
        final text = label(leaveBalanceBarLabel(values[series]), size: 12);
        // MPAndroidChart suppresses dense value labels on a crowded chart.
        if (text.width <= barWidth + 1 && values[series] >= 0) {
          text.paint(
            canvas,
            Offset(x + (barWidth - text.width) / 2, y - text.height - 3),
          );
        }
      }
      final text = label(row.code);
      if (text.width <= groupWidth - 2) {
        text.paint(
          canvas,
          Offset(groupX + (groupWidth - text.width) / 2, plot.bottom + 6),
        );
      } else {
        canvas.save();
        canvas.clipRect(
          Rect.fromLTWH(groupX, plot.bottom + 6, groupWidth, fontHeight),
        );
        text.paint(
          canvas,
          Offset(groupX + (groupWidth - text.width) / 2, plot.bottom + 6),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LeaveBarPainter old) =>
      old.rows != rows || old.scaler != scaler;
}

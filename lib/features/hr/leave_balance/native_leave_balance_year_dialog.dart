import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import 'leave_balance_models.dart';

class NativeLeaveBalanceYearDialog extends StatefulWidget {
  const NativeLeaveBalanceYearDialog({
    super.key,
    required this.selected,
    required this.now,
  });
  final LeaveBalanceYear selected;
  final DateTime now;
  @override
  State<NativeLeaveBalanceYearDialog> createState() =>
      _NativeLeaveBalanceYearDialogState();
}

class _NativeLeaveBalanceYearDialogState
    extends State<NativeLeaveBalanceYearDialog> {
  late int _year;
  late ScrollController _scroll;
  @override
  void initState() {
    super.initState();
    _year = widget.selected.year.clamp(widget.now.year - 10, widget.now.year);
    _scroll = ScrollController(
      initialScrollOffset: ((_year - widget.now.year + 10) * 50.0 - 100).clamp(
        0.0,
        300.0,
      ),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  TextStyle text(
    double size, {
    Color color = Colors.black,
    FontWeight weight = FontWeight.w400,
  }) => TextStyle(
    fontFamily: 'Roboto',
    fontSize: size,
    color: color,
    fontWeight: weight,
  );
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final large = media.textScaler.scale(14) > 21;
    return Dialog(
      key: const Key('leave_balance_year_dialog'),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SizedBox(
        width: math.min(360, math.max(0, media.size.width - 48)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: DocColors.primary,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    children: [
                      Text(
                        'Selected Year',
                        style: text(
                          16,
                          color: Colors.white,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_year',
                        key: const Key('leave_balance_selected_year'),
                        style: text(35, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 265,
                child: ListView.builder(
                  key: const Key('leave_balance_year_list'),
                  controller: _scroll,
                  itemExtent: large ? null : 50,
                  itemCount: 11,
                  itemBuilder: (context, i) {
                    final year = widget.now.year - 10 + i;
                    return InkWell(
                      key: Key('leave_balance_year_$year'),
                      onTap: () => setState(() => _year = year),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Center(
                          child: Text(
                            '$year',
                            style: text(
                              year == _year ? 22 : 18,
                              color:
                                  year == _year
                                      ? DocColors.primary
                                      : Colors.black,
                              weight:
                                  year == _year
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    TextButton(
                      key: const Key('leave_balance_year_cancel'),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'CANCEL',
                        style: text(
                          14,
                          color: DocColors.greenSea,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('leave_balance_year_ok'),
                      onPressed:
                          () => Navigator.pop(context, LeaveBalanceYear(_year)),
                      child: Text(
                        'OK',
                        style: text(
                          14,
                          color: DocColors.greenSea,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

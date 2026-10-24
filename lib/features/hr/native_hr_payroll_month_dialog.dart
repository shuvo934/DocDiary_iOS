import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'hr_dashboard_models.dart';

/// The native month/year picker's six completed-month bounds, including January.
class NativeHrPayrollMonthDialog extends StatefulWidget {
  const NativeHrPayrollMonthDialog({
    super.key,
    required this.selected,
    required this.now,
  });
  final HrPayrollMonth selected;
  final DateTime now;
  @override
  State<NativeHrPayrollMonthDialog> createState() =>
      _NativeHrPayrollMonthDialogState();
}

class _NativeHrPayrollMonthDialogState
    extends State<NativeHrPayrollMonthDialog> {
  late List<HrPayrollMonth> _available;
  late List<int> _years;
  late int _year, _month;
  late FixedExtentScrollController _months, _yearController;
  List<int> get _allowedMonths =>
      _available
          .where((m) => m.first.year == _year)
          .map((m) => m.first.month)
          .toList();
  @override
  void initState() {
    super.initState();
    _available = HrPayrollMonth.available(widget.now);
    _years = _available.map((m) => m.first.year).toSet().toList();
    final selected =
        widget.selected.isAllowed(widget.now)
            ? widget.selected
            : _available.last;
    _year = selected.first.year;
    _month = selected.first.month;
    _months = FixedExtentScrollController(
      initialItem: _allowedMonths.indexOf(_month),
    );
    _yearController = FixedExtentScrollController(
      initialItem: _years.indexOf(_year),
    );
  }

  @override
  void dispose() {
    _months.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _selectYear(int index) {
    setState(() {
      _year = _years[index];
      if (!_allowedMonths.contains(_month)) _month = _allowedMonths.last;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _months.hasClients) {
        _months.jumpToItem(_allowedMonths.indexOf(_month));
      }
    });
  }

  Widget _wheel(
    Key key,
    FixedExtentScrollController controller,
    List<String> values,
    ValueChanged<int> changed,
  ) => SizedBox(
    height: 156,
    child: Stack(
      children: [
        Positioned(
          top: 52,
          left: 4,
          right: 4,
          child: Container(height: 2, color: DocColors.primary),
        ),
        Positioned(
          top: 102,
          left: 4,
          right: 4,
          child: Container(height: 2, color: DocColors.primary),
        ),
        ListWheelScrollView.useDelegate(
          key: key,
          controller: controller,
          itemExtent: 50,
          physics: const FixedExtentScrollPhysics(),
          diameterRatio: 100,
          onSelectedItemChanged: changed,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: values.length,
            builder:
                (context, index) => Center(
                  child: Text(
                    values[index],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Roboto', fontSize: 18),
                  ),
                ),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = media.textScaler.scale(18) / 18;
    return Dialog(
      key: const Key('hr_payroll_month_dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: math.max(
            80,
            media.size.height - media.padding.vertical - 64,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select Month',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Preserve accessibility sizing without forcing long month names into narrow wheels.
                if (scale > 1.5)
                  for (final month in _available)
                    RadioListTile<DateTime>(
                      key: Key(
                        'hr_month_${month.first.year}_${month.first.month}',
                      ),
                      title: Text(
                        '${hrMonths[month.first.month - 1]} ${month.first.year}',
                      ),
                      value: month.first,
                      groupValue: DateTime(_year, _month),
                      onChanged: (date) {
                        if (date != null) {
                          setState(() {
                            _year = date.year;
                            _month = date.month;
                          });
                        }
                      },
                    )
                else
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _wheel(
                          const Key('hr_payroll_month_wheel'),
                          _months,
                          _allowedMonths.map((m) => hrMonths[m - 1]).toList(),
                          (index) =>
                              setState(() => _month = _allowedMonths[index]),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _wheel(
                          const Key('hr_payroll_year_wheel'),
                          _yearController,
                          _years.map((year) => '$year').toList(),
                          _selectYear,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      TextButton(
                        key: const Key('hr_month_cancel'),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CANCEL'),
                      ),
                      TextButton(
                        key: const Key('hr_month_ok'),
                        onPressed:
                            () => Navigator.pop(
                              context,
                              HrPayrollMonth(DateTime(_year, _month)),
                            ),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

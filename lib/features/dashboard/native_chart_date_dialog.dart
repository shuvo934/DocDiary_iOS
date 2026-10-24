import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'admin_chart_models.dart';
import 'native_admin_line_chart.dart';

/// The Android month library uses two NumberPickers; its year-only library
/// uses a teal header and a vertical list. Both commit only on OK.
class NativeChartDateDialog extends StatefulWidget {
  const NativeChartDateDialog({
    super.key,
    required this.selection,
    required this.now,
  });
  final AdminChartSelection selection;
  final DateTime now;

  @override
  State<NativeChartDateDialog> createState() => _NativeChartDateDialogState();
}

class _NativeChartDateDialogState extends State<NativeChartDateDialog> {
  late int _year, _month;
  late FixedExtentScrollController _months;
  late FixedExtentScrollController _years;
  late ScrollController _yearList;
  late List<int> _availableMonths;

  int get _minYear =>
      widget.selection.mode == AdminChartMode.yearly
          ? widget.now.year - 10
          : DateTime(widget.now.year, widget.now.month - 11).year;

  List<int> _monthsFor(int year) => [
    for (var month = 1; month <= 12; month++)
      if (AdminChartSelection(
        AdminChartMode.monthly,
        DateTime(year, month),
      ).isAllowed(widget.now))
        month,
  ];

  @override
  void initState() {
    super.initState();
    _year =
        widget.selection.first.year.clamp(_minYear, widget.now.year).toInt();
    _availableMonths = _monthsFor(_year);
    _month = widget.selection.first.month;
    if (!_availableMonths.contains(_month)) {
      _month = _availableMonths.isEmpty ? 1 : _availableMonths.last;
    }
    _months = FixedExtentScrollController(
      initialItem: _availableMonths.indexOf(_month).clamp(0, 11).toInt(),
    );
    _years = FixedExtentScrollController(initialItem: _year - _minYear);
    _yearList = ScrollController(
      initialScrollOffset:
          ((_year - _minYear) * 50.0 - 100).clamp(0.0, 300.0).toDouble(),
    );
  }

  @override
  void dispose() {
    _months.dispose();
    _years.dispose();
    _yearList.dispose();
    super.dispose();
  }

  Widget _wheel({
    required Key key,
    required FixedExtentScrollController controller,
    required List<String> labels,
    required ValueChanged<int> onChanged,
  }) => Stack(
    children: [
      Positioned(
        top: 70,
        left: 4,
        right: 4,
        child: Container(height: 2, color: DocColors.primary),
      ),
      Positioned(
        top: 110,
        left: 4,
        right: 4,
        child: Container(height: 2, color: DocColors.primary),
      ),
      ListWheelScrollView.useDelegate(
        key: key,
        controller: controller,
        itemExtent: 40,
        physics: const FixedExtentScrollPhysics(),
        diameterRatio: 100,
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: labels.length,
          builder:
              (context, index) => Center(
                child: Text(
                  labels[index],
                  style: chartRoboto(18, color: Colors.black),
                ),
              ),
        ),
      ),
    ],
  );

  void _chooseYear(int index) {
    setState(() {
      _year = _minYear + index;
      _availableMonths = _monthsFor(_year);
      if (!_availableMonths.contains(_month)) {
        _month = _availableMonths.first;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _months.hasClients) {
        _months.jumpToItem(_availableMonths.indexOf(_month));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final yearly = widget.selection.mode == AdminChartMode.yearly;
    final size = MediaQuery.sizeOf(context);
    final fraction = size.width <= size.height ? 0.95 : 0.65;
    final width = math.max(
      0.0,
      math.min(size.width * fraction - 32, size.width - 48),
    );
    return Dialog(
      key: const Key('admin_chart_date_dialog'),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (yearly) ...[
                Container(
                  width: double.infinity,
                  color: DocColors.primary,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    children: [
                      Text(
                        'Selected Year',
                        style: chartRoboto(16, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_year',
                        key: const Key('admin_chart_selected_year'),
                        style: chartRoboto(35, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 265,
                  child: ListView.builder(
                    controller: _yearList,
                    itemCount: 11,
                    itemExtent: 50,
                    itemBuilder: (context, index) {
                      final year = _minYear + index;
                      return InkWell(
                        key: Key('admin_chart_year_$year'),
                        onTap: () => setState(() => _year = year),
                        child: Center(
                          child: Text(
                            '$year',
                            style: chartRoboto(
                              year == _year ? 22 : 18,
                              color:
                                  year == _year
                                      ? DocColors.primary
                                      : Colors.black,
                              weight:
                                  year == _year
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select Month',
                      style: chartRoboto(
                        20,
                        color: Colors.black,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 180,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _wheel(
                            key: const Key('admin_chart_month_wheel'),
                            controller: _months,
                            labels: [
                              for (final month in _availableMonths)
                                chartMonths[month - 1],
                            ],
                            onChanged: (index) {
                              if (index < _availableMonths.length) {
                                setState(
                                  () => _month = _availableMonths[index],
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          flex: 2,
                          child: _wheel(
                            key: const Key('admin_chart_year_wheel'),
                            controller: _years,
                            labels: [
                              for (
                                var year = _minYear;
                                year <= widget.now.year;
                                year++
                              )
                                '$year',
                            ],
                            onChanged: _chooseYear,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      key: const Key('admin_chart_date_cancel'),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'CANCEL',
                        style: chartRoboto(
                          14,
                          color: DocColors.primary,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('admin_chart_date_ok'),
                      onPressed:
                          () => Navigator.pop(
                            context,
                            DateTime(_year, yearly ? 1 : _month),
                          ),
                      child: Text(
                        'OK',
                        style: chartRoboto(
                          14,
                          color: DocColors.primary,
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

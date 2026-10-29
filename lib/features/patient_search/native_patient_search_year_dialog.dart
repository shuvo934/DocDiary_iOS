import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

/// The accepted chart/leave-balance year dialog, with PatientSearch's native
/// 1950..current-year range. Selection commits only with OK.
class NativePatientSearchYearDialog extends StatefulWidget {
  const NativePatientSearchYearDialog({
    super.key,
    required this.selected,
    required this.now,
  });
  final int selected;
  final DateTime now;
  @override
  State<NativePatientSearchYearDialog> createState() => _YearDialogState();
}

class _YearDialogState extends State<NativePatientSearchYearDialog> {
  late int _year;
  late final ScrollController _scroll;
  double _extent = 50;
  @override
  void initState() {
    super.initState();
    _year = widget.selected.clamp(1950, widget.now.year);
    _scroll = ScrollController(
      initialScrollOffset: math.max(0, (_year - 1950) * 50.0 - 100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extent = math.max(
      50.0,
      MediaQuery.textScalerOf(context).scale(22) * 1.4 + 20,
    );
    // Retain the accepted 50dp rows at the normal text size.
    final next =
        MediaQuery.textScalerOf(context).scale(14) > 21 ? extent : 50.0;
    if (next != _extent) {
      _extent = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.jumpTo(
            ((_year - 1950) * _extent - 100).clamp(
              0,
              _scroll.position.maxScrollExtent,
            ),
          );
        }
      });
    }
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
    return Dialog(
      key: const Key('patient_search_year_dialog'),
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
                        key: const Key('patient_search_selected_year'),
                        style: text(35, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 265,
                child: ListView.builder(
                  key: const Key('patient_search_year_list'),
                  controller: _scroll,
                  itemExtent: _extent,
                  itemCount: widget.now.year - 1950 + 1,
                  itemBuilder: (_, index) {
                    final year = 1950 + index;
                    return InkWell(
                      key: Key('patient_search_year_$year'),
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
                      key: const Key('patient_search_year_cancel'),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'CANCEL',
                        style: text(
                          14,
                          color: DocColors.primary,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('patient_search_year_ok'),
                      onPressed: () => Navigator.pop(context, _year),
                      child: Text(
                        'OK',
                        style: text(
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

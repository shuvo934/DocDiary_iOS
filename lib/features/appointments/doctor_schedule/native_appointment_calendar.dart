import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/native_dates.dart';
import 'doctor_appointment_models.dart';

/// Native HorizontalCalendar shows five dates, with day number above weekday.
/// The centered date is selected when a user finishes scrolling.
class NativeAppointmentCalendar extends StatefulWidget {
  const NativeAppointmentCalendar({
    super.key,
    required this.window,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });
  final DoctorAppointmentWindow window;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  final bool enabled;
  @override
  State<NativeAppointmentCalendar> createState() =>
      _NativeAppointmentCalendarState();
}

class _NativeAppointmentCalendarState extends State<NativeAppointmentCalendar> {
  final _scroll = ScrollController();
  double _extent = 0;
  bool _syncing = false;
  int _sync = 0;
  @override
  void didUpdateWidget(NativeAppointmentCalendar old) {
    super.didUpdateWidget(old);
    if (dateOnly(old.selected) != dateOnly(widget.selected) ||
        old.window.first != widget.window.first) {
      _center();
    }
  }

  void _center() {
    final generation = ++_sync;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _sync ||
          !_scroll.hasClients ||
          _extent == 0) {
        return;
      }
      _syncing = true;
      _scroll.jumpTo(
        (widget.window.indexOf(widget.selected) * _extent).clamp(
          0,
          _scroll.position.maxScrollExtent,
        ),
      );
      _syncing = false;
    });
  }

  Future<void> _stopped() async {
    if (!mounted ||
        !widget.enabled ||
        _syncing ||
        !_scroll.hasClients ||
        _extent == 0) {
      return;
    }
    final index = (_scroll.offset / _extent).round().clamp(
      0,
      widget.window.length - 1,
    );
    final selected = widget.window.dayAt(index);
    if (selected != dateOnly(widget.selected)) widget.onSelected(selected);
    final generation = ++_sync;
    _syncing = true;
    try {
      await _scroll.animateTo(
        index * _extent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    } finally {
      if (mounted && generation == _sync) _syncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return SizedBox(
      height: 64 * scale.clamp(1, 2.5),
      child: LayoutBuilder(
        builder: (context, bounds) {
          final extent = bounds.maxWidth / 5;
          if (_extent != extent) {
            _extent = extent;
            _center();
          }
          return NotificationListener<ScrollEndNotification>(
            onNotification: (notice) {
              if (!_syncing) unawaited(_stopped());
              return false;
            },
            child: ListView.builder(
              key: const Key('doctor_appointment_calendar'),
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              itemExtent: extent,
              physics:
                  widget.enabled
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: extent * 2),
              itemCount: widget.window.length,
              itemBuilder: (context, index) {
                final date = widget.window.dayAt(index),
                    active = date == dateOnly(widget.selected);
                const weekdays = [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun',
                ];
                return Semantics(
                  selected: active,
                  label: '${DoctorAppointmentWindow.label(date)}, ${date.day}',
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Material(
                      color: active ? DocColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        key: Key('doctor_appointment_date_${oracleDate(date)}'),
                        borderRadius: BorderRadius.circular(20),
                        onTap:
                            widget.enabled
                                ? () => widget.onSelected(date)
                                : null,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              date.day.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 12,
                                height: 1.3,
                                color:
                                    active
                                        ? Colors.white
                                        : const Color(0xff95a5a6),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              weekdays[date.weekday - 1],
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 12,
                                height: 1.3,
                                color:
                                    active
                                        ? Colors.white
                                        : const Color(0xff95a5a6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    ++_sync;
    _scroll.dispose();
    super.dispose();
  }
}

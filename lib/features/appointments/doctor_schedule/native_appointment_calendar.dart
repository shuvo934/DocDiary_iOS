import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/native_dates.dart';
import 'doctor_appointment_models.dart';

/// Native HorizontalCalendar shows five dates, with day number above weekday.
/// Tap/drag settles smoothly into the centre before committing one date change.
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
  bool _driving = false;
  bool _suppress = false;
  bool _touching = false;
  bool _tapHandled = false;
  int _pointer = 0;
  int _sync = 0;
  @override
  void didUpdateWidget(NativeAppointmentCalendar old) {
    super.didUpdateWidget(old);
    if (old.enabled && !widget.enabled) {
      // A background/loading transition must not commit an old queued gesture.
      ++_sync;
      _driving = false;
      _touching = false;
      ++_pointer;
      if (_scroll.hasClients) {
        _suppress = true;
        _scroll.jumpTo(_scroll.offset);
        _suppress = false;
      }
    }
    if (dateOnly(old.selected) != dateOnly(widget.selected) ||
        old.window.first != widget.window.first ||
        (!old.enabled && widget.enabled)) {
      _center(animated: true);
    }
  }

  void _center({bool animated = false}) {
    final generation = ++_sync;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _sync ||
          !_scroll.hasClients ||
          _extent == 0) {
        return;
      }
      unawaited(
        _moveTo(
          widget.window.indexOf(widget.selected),
          animated: animated,
          notify: false,
        ),
      );
    });
  }

  Future<void> _moveTo(
    int index, {
    bool animated = true,
    bool notify = true,
  }) async {
    if (!mounted ||
        !_scroll.hasClients ||
        _extent == 0 ||
        (notify && !widget.enabled)) {
      return;
    }
    index = index.clamp(0, widget.window.length - 1);
    final generation = ++_sync;
    _driving = true;
    try {
      final target =
          (index * _extent)
              .clamp(0.0, _scroll.position.maxScrollExtent)
              .toDouble();
      if ((_scroll.offset - target).abs() > .5) {
        if (animated) {
          await _scroll.animateTo(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        } else {
          _scroll.jumpTo(target);
        }
      }
    } finally {
      if (mounted && generation == _sync) _driving = false;
    }
    if (!mounted || generation != _sync || !notify || !widget.enabled) return;
    final selected = widget.window.dayAt(index);
    if (selected != dateOnly(widget.selected)) widget.onSelected(selected);
  }

  void _pointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    ++_pointer;
    ++_sync;
    _touching = true;
    _tapHandled = false;
    _driving = false;
  }

  void _pointerEnd(PointerEvent event) {
    final pointer = _pointer;
    // Tap recognizers run during this event; defer idle snapping until they
    // have selected the tapped cell, rather than committing the interrupted one.
    scheduleMicrotask(() {
      if (!mounted || pointer != _pointer) return;
      _touching = false;
      if (widget.enabled &&
          !_tapHandled &&
          !_driving &&
          _extent > 0 &&
          _scroll.hasClients &&
          !_scroll.position.isScrollingNotifier.value) {
        unawaited(_moveTo((_scroll.offset / _extent).round()));
      }
    });
  }

  void _tapIndex(int index) {
    _tapHandled = true;
    unawaited(_moveTo(index));
  }

  bool _notification(ScrollNotification notice) {
    if (notice.depth != 0 || _suppress) return false;
    if (notice is ScrollStartNotification && notice.dragDetails != null) {
      // A new finger gesture supersedes any incomplete programmatic motion.
      ++_sync;
      _driving = false;
    } else if (notice is ScrollEndNotification &&
        !_touching &&
        !_driving &&
        widget.enabled &&
        _extent > 0 &&
        _scroll.hasClients) {
      unawaited(_moveTo((_scroll.offset / _extent).round()));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return SizedBox(
      height: 56 * scale.clamp(1, 2.5) + .5,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final extent = bounds.maxWidth / 5;
          if (_extent != extent) {
            _extent = extent;
            _center();
          }
          return Listener(
            onPointerDown: _pointerDown,
            onPointerUp: _pointerEnd,
            onPointerCancel: _pointerEnd,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              // DrivenScrollActivity temporarily ignores cell hit tests. The
              // outer detector still allows a second tap to choose a new date.
              onTapUp:
                  widget.enabled
                      ? (details) {
                        if (_scroll.hasClients && _extent > 0) {
                          _tapIndex(
                            ((_scroll.offset +
                                        details.localPosition.dx -
                                        _extent * 2) /
                                    _extent)
                                .floor(),
                          );
                        }
                      }
                      : null,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0x1f000000), width: .5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: .5),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _notification,
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
                          label:
                              '${DoctorAppointmentWindow.label(date)}, ${date.day}',
                          child: Material(
                            color: active ? DocColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              key: Key(
                                'doctor_appointment_date_${oracleDate(date)}',
                              ),
                              borderRadius: BorderRadius.circular(8),
                              onTap:
                                  widget.enabled
                                      ? () => _tapIndex(index)
                                      : null,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    date.day.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
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
                                      fontWeight: FontWeight.w700,
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
                        );
                      },
                    ),
                  ),
                ),
              ),
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

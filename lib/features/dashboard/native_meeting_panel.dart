import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'dashboard_repository.dart';
import 'meeting_countdown.dart';
import 'native_dashboard_format.dart';
import 'native_dashboard_icons.dart';

TextStyle _meetingText(
  String family,
  double size, {
  FontWeight weight = FontWeight.normal,
}) => TextStyle(
  inherit: false,
  textBaseline: TextBaseline.alphabetic,
  fontFamily: family,
  fontSize: size,
  fontWeight: weight,
  color: Colors.white,
);

/// The native card's 180-degree progress rotation anchors its fill on the right.
/// Scheduling belongs to DashboardScreen; this widget never starts a timer.
class NativeMeetingPanel extends StatelessWidget {
  const NativeMeetingPanel({
    super.key,
    required this.summary,
    required this.now,
    required this.sdp,
    this.countdown,
  });

  final DashboardSummary summary;
  final DateTime now;
  final double sdp;
  final MeetingSnapshot? countdown;

  @override
  Widget build(BuildContext context) {
    final upcoming = summary.nextTime.trim().isNotEmpty;
    final snapshot =
        countdown ??
        MeetingTimeline.update(
          lastTime: summary.lastTime,
          nextTime: summary.nextTime,
          observedAt: now,
        )?.at(now);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 3 * sdp, vertical: 8 * sdp),
      child: Material(
        key: const Key('dashboard_next_meeting'),
        color: const Color(0xFFCED6E0),
        elevation: 3,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: (snapshot?.progressPercent ?? 0) / 100,
                    ),
                    duration: const Duration(milliseconds: 200),
                    builder:
                        (context, value, child) => FractionallySizedBox(
                          key: const Key('dashboard_meeting_progress'),
                          widthFactor: value,
                          heightFactor: 1,
                          child: child,
                        ),
                    child: const ColoredBox(color: DocColors.primary),
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: 86 * sdp),
              child: Padding(
                padding: EdgeInsets.fromLTRB(10 * sdp, 5 * sdp, 5 * sdp, 5),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              upcoming
                                  ? 'Next Meeting'
                                  : 'No Upcoming Meeting Available',
                              style: _meetingText(
                                'Poppins',
                                12 * sdp,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (upcoming)
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(left: 10 * sdp),
                                child: Text(
                                  nativeDashboardMeeting(
                                    summary.nextTime,
                                    snapshot?.asOf ?? now,
                                    hasPrevious:
                                        summary.lastTime.trim().isNotEmpty,
                                  ),
                                  key: const Key('dashboard_meeting_time'),
                                  textAlign: TextAlign.end,
                                  style: _meetingText(
                                    'Poppins',
                                    10 * sdp,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (upcoming)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 55,
                                child: Text(
                                  summary.nextPatient.isEmpty
                                      ? 'No Name Found'
                                      : 'With ${summary.nextPatient}',
                                  key: const Key('dashboard_meeting_patient'),
                                  style: _meetingText(
                                    'Poppins',
                                    11 * sdp,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (snapshot != null)
                                Expanded(
                                  flex: 45,
                                  child: Semantics(
                                    label: snapshot.description,
                                    excludeSemantics: true,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: _MeetingTimer(
                                        snapshot: snapshot,
                                        sdp: sdp,
                                      ),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _MeetingTimer extends StatelessWidget {
  const _MeetingTimer({required this.snapshot, required this.sdp});
  final MeetingSnapshot snapshot;
  final double sdp;

  List<Widget> _part(String key, int value, String label) => [
    const SizedBox(width: 8),
    Text(
      value.toString().padLeft(2, '0'),
      key: Key('dashboard_timer_$key'),
      style: _meetingText('Roboto', 10 * sdp, weight: FontWeight.w700),
    ),
    const SizedBox(width: 8),
    Text(label, style: _meetingText('Roboto', 8 * sdp)),
  ];

  @override
  Widget build(BuildContext context) => Row(
    key: const Key('dashboard_meeting_countdown'),
    mainAxisSize: MainAxisSize.min,
    children: [
      NativeDashboardIcon(
        NativeDashboardGlyph.timer,
        size: 14 * sdp,
        color: Colors.white,
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (snapshot.showHours) ..._part('hours', snapshot.hours, 'h'),
          if (snapshot.showMinutes) ..._part('minutes', snapshot.minutes, 'm'),
          ..._part('seconds', snapshot.seconds, 's'),
          const SizedBox(width: 8),
        ],
      ),
    ],
  );
}

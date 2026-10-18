/// Native getMeetingSchedule timestamps are local dd-MM-yyyy HH:mm:ss values.
/// DateTime.parse/UTC conversion would change the backend's meaning here.
DateTime? parseNativeMeetingTime(String value) {
  final match = RegExp(
    r'^(\d{2})-(\d{2})-(\d{4}) (\d{2}):(\d{2}):(\d{2})$',
  ).firstMatch(value.trim());
  if (match == null) {
    return null;
  }
  final day = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final year = int.parse(match[3]!);
  final hour = int.parse(match[4]!);
  final minute = int.parse(match[5]!);
  final second = int.parse(match[6]!);
  if (year < 1 ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31 ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    return null;
  }
  final time = DateTime(year, month, day, hour, minute, second);
  if (time.year != year ||
      time.month != month ||
      time.day != day ||
      time.hour != hour ||
      time.minute != minute ||
      time.second != second) {
    return null;
  }
  return time;
}

/// A stable interval for one last_sc/next_sc pair. Without last_sc, Android
/// starts at 100% using the first observed remaining duration as the interval.
/// Re-reading that same meeting must not reset this interval on a tab change.
class MeetingTimeline {
  const MeetingTimeline._(
    this.lastTime,
    this.nextTime,
    this.next,
    this.startedAt,
  );

  final String lastTime;
  final String nextTime;
  final DateTime next;
  final DateTime startedAt;

  static MeetingTimeline? update({
    required String lastTime,
    required String nextTime,
    required DateTime observedAt,
    MeetingTimeline? previous,
  }) {
    final next = parseNativeMeetingTime(nextTime);
    if (next == null) {
      return null;
    }
    final last = lastTime.trim();
    final upcoming = nextTime.trim();
    if (previous != null &&
        previous.lastTime == last &&
        previous.nextTime == upcoming) {
      return previous;
    }
    return MeetingTimeline._(
      last,
      upcoming,
      next,
      parseNativeMeetingTime(last) ?? observedAt,
    );
  }

  MeetingSnapshot at(DateTime now) {
    final seconds = next.difference(now).inSeconds;
    final remaining = seconds > 0 ? seconds : 0;
    final total = next.difference(startedAt).inSeconds;
    // Native uses integer percentages. Guard malformed/zero intervals and a
    // device clock moving backwards instead of dividing by zero/overdrawing.
    final percent =
        total > 0 ? (100 * remaining ~/ total).clamp(0, 100).toInt() : 0;
    return MeetingSnapshot(
      asOf: now,
      remainingSeconds: remaining,
      progressPercent: percent,
    );
  }
}

class MeetingSnapshot {
  const MeetingSnapshot({
    required this.asOf,
    required this.remainingSeconds,
    required this.progressPercent,
  });

  final DateTime asOf;
  final int remainingSeconds;
  final int progressPercent;

  bool get expired => remainingSeconds == 0;
  int get hours => remainingSeconds ~/ 3600;
  int get minutes => remainingSeconds ~/ 60 % 60;
  int get seconds => remainingSeconds % 60;
  bool get showHours => hours != 0;
  // Android tests total minutes, so '00 m' stays visible at exactly one hour.
  bool get showMinutes => remainingSeconds ~/ 60 != 0;

  String get description => [
    if (showHours) '$hours hours',
    if (showMinutes) '$minutes minutes',
    '$seconds seconds remaining',
  ].join(', ');
}

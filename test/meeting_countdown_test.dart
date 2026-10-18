import 'package:docdiary_ios/core/native_dates.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/meeting_countdown.dart';
import 'package:docdiary_ios/features/dashboard/native_dashboard_format.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  final now = DateTime(2026, 10, 15, 13, 30);

  test('meeting timestamps use strict native local calendar fields', () {
    final parsed = parseNativeMeetingTime('29-02-2028 23:59:58')!;
    expect(parsed, DateTime(2028, 2, 29, 23, 59, 58));
    expect(parsed.isUtc, isFalse);
    for (final value in [
      '',
      '15-OCT-26',
      '2026-10-15T13:30:00Z',
      '31-02-2026 13:30:00',
      '00-10-2026 13:30:00',
      '15-13-2026 13:30:00',
      '15-10-2026 24:00:00',
      '15-10-2026 13:60:00',
      '15-10-2026 13:30:60',
    ]) {
      expect(parseNativeMeetingTime(value), isNull, reason: value);
    }
  });

  test(
    'native integer progress uses last_sc to next_sc, rather than a fixed duration',
    () {
      final meeting =
          MeetingTimeline.update(
            lastTime: '15-10-2026 13:29:00',
            nextTime: '15-10-2026 13:31:00',
            observedAt: now,
          )!;
      expect(meeting.at(now).remainingSeconds, 60);
      expect(meeting.at(now).progressPercent, 50);
      expect(
        meeting.at(now.add(const Duration(seconds: 1))).progressPercent,
        49,
      );
    },
  );

  test(
    'missing last_sc starts at 100% and a repeated response preserves its anchor',
    () {
      final first =
          MeetingTimeline.update(
            lastTime: '',
            nextTime: '15-10-2026 13:31:00',
            observedAt: now,
          )!;
      expect(first.at(now).progressPercent, 100);
      final later = now.add(const Duration(seconds: 30));
      final repeated =
          MeetingTimeline.update(
            lastTime: '',
            nextTime: ' 15-10-2026 13:31:00 ',
            observedAt: later,
            previous: first,
          )!;
      expect(identical(first, repeated), isTrue);
      expect(repeated.at(later).progressPercent, 50);
      final replacement =
          MeetingTimeline.update(
            lastTime: '',
            nextTime: '15-10-2026 13:32:00',
            observedAt: later,
            previous: repeated,
          )!;
      expect(replacement.at(later).progressPercent, 100);
    },
  );

  test(
    'zero/reversed intervals and backward clock changes stay within 0 to 100',
    () {
      for (final last in ['15-10-2026 13:31:00', '15-10-2026 13:32:00']) {
        final meeting =
            MeetingTimeline.update(
              lastTime: last,
              nextTime: '15-10-2026 13:31:00',
              observedAt: now,
            )!;
        expect(meeting.at(now).progressPercent, 0);
        expect(meeting.at(now).remainingSeconds, 60);
      }
      final meeting =
          MeetingTimeline.update(
            lastTime: '15-10-2026 13:29:00',
            nextTime: '15-10-2026 13:31:00',
            observedAt: now,
          )!;
      expect(
        meeting.at(now.subtract(const Duration(hours: 1))).progressPercent,
        100,
      );
      expect(
        MeetingTimeline.update(lastTime: '', nextTime: '', observedAt: now),
        isNull,
      );
      expect(
        MeetingTimeline.update(
          lastTime: '',
          nextTime: 'invalid',
          observedAt: now,
        ),
        isNull,
      );
      final invalidLast =
          MeetingTimeline.update(
            lastTime: 'invalid',
            nextTime: '15-10-2026 13:31:00',
            observedAt: now,
          )!;
      expect(invalidLast.at(now).progressPercent, 100);
    },
  );

  test(
    'native h m s groups change at 60/3600 seconds and hours can exceed 24',
    () {
      MeetingSnapshot snapshot(int seconds) => MeetingSnapshot(
        asOf: now,
        remainingSeconds: seconds,
        progressPercent: 50,
      );
      expect(snapshot(59).showMinutes, isFalse);
      expect(snapshot(60).minutes, 1);
      expect(snapshot(60).seconds, 0);
      expect(snapshot(60).showMinutes, isTrue);
      expect(snapshot(3599).showHours, isFalse);
      expect(snapshot(3600).showHours, isTrue);
      expect(snapshot(3600).showMinutes, isTrue);
      expect(snapshot(3600).minutes, 0);
      expect(
        snapshot(3661).description,
        '1 hours, 1 minutes, 1 seconds remaining',
      );
      expect(snapshot(49 * 3600).hours, 49);
      expect(snapshot(0).showHours, isFalse);
      expect(snapshot(0).showMinutes, isFalse);
    },
  );

  test(
    'past and sub-second remaining durations reach zero without negative output',
    () {
      final meeting =
          MeetingTimeline.update(
            lastTime: '',
            nextTime: '15-10-2026 13:31:00',
            observedAt: now,
          )!;
      for (final date in [
        DateTime(2026, 10, 15, 13, 30, 59, 500),
        DateTime(2026, 10, 15, 13, 31),
        DateTime(2026, 10, 16),
      ]) {
        final value = meeting.at(date);
        expect(value.remainingSeconds, 0);
        expect(value.progressPercent, 0);
        expect(value.expired, isTrue);
      }
    },
  );

  test(
    'last_sc selects native timestamp spacing and same-day leading-zero branch',
    () {
      expect(
        nativeDashboardMeeting('15-10-2026 09:05:00', now, hasPrevious: true),
        'At  9:05 AM',
      );
      expect(
        nativeDashboardMeeting('16-10-2026 09:05:00', now, hasPrevious: true),
        'At  09:05 AM\nIn  16 Oct, 26',
      );
      expect(
        nativeDashboardMeeting('15-11-2026 09:05:00', now, hasPrevious: true),
        'At  09:05 AM\nIn  15 Nov, 26',
      );
    },
  );

  test(
    'schedule mapping keeps last_sc and request clock without adding POSTs',
    () async {
      final h = Harness(clock: now);
      await h.signIn();
      final writes = h.posts.length;
      h.transport.onGet = (uri) async {
        if (uri.path.endsWith('getMeetingSchedule')) {
          return {
            'items': [
              {
                'last_sc': '15-10-2026 13:29:00',
                'next_sc': '15-10-2026 13:31:00',
                'pat_name': 'Example Patient',
              },
            ],
          };
        }
        return h.defaultGet(uri);
      };
      final result = await DashboardRepository(
        h.transport,
        now: () => h.now,
      ).load(h.auth.session!, h.auth.profile!, SummaryPeriod.today);
      expect(result.lastTime, '15-10-2026 13:29:00');
      expect(result.nextTime, '15-10-2026 13:31:00');
      expect(result.nextPatient, 'Example Patient');
      expect(result.asOf, now);
      expect(h.transport.requests.last.uri.queryParameters, {
        'doc_id': '10',
        'time_now': '15-10-2026 01:30 PM',
      });
      expect(h.posts.length, writes);
      h.auth.dispose();
    },
  );
}

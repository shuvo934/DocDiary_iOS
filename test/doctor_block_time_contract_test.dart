import 'dart:async';
import 'dart:convert';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/account_access.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/block_time/doctor_block_time_models.dart';
import 'package:docdiary_ios/features/block_time/doctor_block_time_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'block_time_support.dart';
import 'support.dart';

Future<DoctorBlockCalendar> _load(
  Harness h, {
  AccountProfile? profile,
  bool Function()? current,
}) => DoctorBlockTimeRepository(h.transport, now: () => h.now).load(
  h.auth.session!,
  profile ?? h.auth.profile!,
  DoctorBlockWindow(h.now),
  isCurrent: current ?? () => true,
);
void main() {
  test('complete month bounds at month-end, year-end and leap February', () {
    for (final e in [
      (
        DateTime(2026, 10, 31),
        DateTime(2026, 10),
        DateTime(2026, 12, 31),
        'OCT-26',
        'DEC-26',
      ),
      (
        DateTime(2026, 12, 31),
        DateTime(2026, 12),
        DateTime(2027, 2, 28),
        'DEC-26',
        'FEB-27',
      ),
      (
        DateTime(2023, 12, 31),
        DateTime(2023, 12),
        DateTime(2024, 2, 29),
        'DEC-23',
        'FEB-24',
      ),
    ]) {
      final w = DoctorBlockWindow(e.$1);
      expect(w.first, e.$2);
      expect(w.last, e.$3);
      expect(w.firstMonth, e.$4);
      expect(w.lastMonth, e.$5);
      expect(
        w.contains(DateTime(e.$3.year, e.$3.month, e.$3.day, 23, 59)),
        isTrue,
      );
      expect(
        w.contains(DateTime(e.$3.year, e.$3.month, e.$3.day + 1)),
        isFalse,
      );
    }
  });
  test('six consecutive weeks start Saturday, including leap day', () {
    for (final m in [
      DateTime(2026, 10),
      DateTime(2027, 1),
      DateTime(2024, 2),
    ]) {
      final cells = blockTimeMonthCells(m);
      expect(cells.length, 42);
      expect(cells.first.weekday, DateTime.saturday);
      expect(cells.toSet().length, 42);
      expect(cells, contains(m));
      for (var i = 1; i < 42; i++) {
        final p = cells[i - 1];
        expect(cells[i], DateTime(p.year, p.month, p.day + 1));
      }
    }
    expect(
      blockTimeMonthCells(DateTime(2024, 2)),
      contains(DateTime(2024, 2, 29)),
    );
  });
  test(
    'exact selected-centre GET with native query and no credentials or writes',
    () async {
      final h = blockTimeHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      final posts = h.posts.length,
          data = await _load(h),
          r = h.transport.requests.last;
      expect(r.method, 'GET');
      expect(
        r.uri.toString(),
        'https://centre.example/api/leave_schedule/getTimeSchedule?doc_id=10&FIRST_MONTH=OCT-26&LAST_MONTH=DEC-26',
      );
      expect(r.headers, isEmpty);
      expect(h.posts.length, posts);
      expect(data.days.length, 5);
      expect(
        h.transport.requests.where((r) => r.uri.path.endsWith('getLeaveDays')),
        isEmpty,
      );
    },
  );
  test(
    'encoded unsorted rows retain duplicate time order and last total',
    () async {
      final h = blockTimeHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      h.transport.onGet =
          (_) async => {
            'count': 3,
            'items': jsonEncode([
              blockedSlot(time: 'first', total: '4'),
              blockedSlot(date: '22-OCT-26', time: 'other', total: '1'),
              blockedSlot(time: 'first', total: '2'),
            ]),
          };
      final c = await _load(h), d = c.at(DateTime(2026, 10, 21, 12))!;
      expect(c.days.length, 2);
      expect(d.slots.map((s) => s.time), ['first', 'first']);
      expect(d.totalSchedules, 2);
      expect(d.message, 'All Schedule Blocked');
      expect(d.fullDay, isFalse);
      expect(() => d.slots.clear(), throwsUnsupportedError);
      expect(() => c.days.clear(), throwsUnsupportedError);
    },
  );
  test(
    'partial times are original strings; all blocked uses equality, not greater-than',
    () async {
      final h = blockTimeHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      var d = (await _load(h)).at(DateTime(2026, 10, 21))!;
      expect(d.message, isNull);
      expect(d.slots.first.time, '09:00 AM - 10:00 AM');
      h.transport.onGet =
          (_) async => {
            'count': 2,
            'items': [blockedSlot(total: '1'), blockedSlot(total: '1')],
          };
      d = (await _load(h)).at(DateTime(2026, 10, 21))!;
      expect(d.allSchedulesBlocked, isFalse);
    },
  );
  test('nullable native fields normalize without inventing full-day leave', () {
    final s = DoctorBlockedSlot.fromJson({
      ...blockedSlot(),
      'lad_id': null,
      'las_id': 'null',
      'las_ts_id': null,
      'la_id': null,
      'la_month': null,
      'schedule_time': 'null',
      'tot_sc': null,
    });
    expect(s.ladId, '');
    expect(s.lasId, '');
    expect(s.timeScheduleId, '');
    expect(s.leaveId, '');
    expect(s.leaveMonth, '');
    expect(s.notes, '');
    expect(s.time, '');
    expect(s.totalSchedules, 0);
    final d = DoctorBlockedDay(date: s.date, slots: [s]);
    expect(d.fullDay, isFalse);
    expect(d.allSchedulesBlocked, isFalse);
  });
  test(
    'count zero is a successful empty calendar even with null or stale items',
    () async {
      final h = blockTimeHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      for (final items in [
        null,
        'null',
        <Object?>[],
        [blockedSlot()],
      ]) {
        h.transport.onGet = (_) async => {'count': '0', 'items': items};
        expect((await _load(h)).days, isEmpty);
      }
    },
  );
  test(
    'incomplete or malformed data stays retryable rather than false empty',
    () async {
      final h = blockTimeHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      for (final root in <JsonMap>[
        {},
        {'count': null},
        {'count': -1, 'items': []},
        {'count': 'bad', 'items': []},
        {'count': 1, 'items': null},
        {'count': 1, 'items': []},
        {'count': 1, 'items': 'broken'},
        {
          'count': 1,
          'items': [<String, Object?>{}],
        },
      ]) {
        h.transport.onGet = (_) async => root;
        await expectLater(
          _load(h),
          throwsA(
            isA<AppFailure>().having(
              (e) => e.kind,
              'kind',
              FailureKind.invalidData,
            ),
          ),
        );
      }
    },
  );
  test(
    'impossible dates, trailing data and noninteger/negative totals are rejected',
    () {
      for (final row in [
        {...blockedSlot(), 'lad_date': '31-FEB-26'},
        {...blockedSlot(), 'lad_date': '29-FEB-25'},
        {...blockedSlot(), 'lad_date': null},
        {...blockedSlot(), 'lad_date': '21-OCT-26 trailing'},
        {...blockedSlot(), 'tot_sc': '-2'},
        {...blockedSlot(), 'tot_sc': '2.5'},
      ]) {
        expect(
          () => DoctorBlockedSlot.fromJson(row),
          throwsA(isA<AppFailure>()),
        );
      }
      expect(
        DoctorBlockedSlot.fromJson({
          ...blockedSlot(),
          'lad_date': '29-feb-2024',
        }).date,
        DateTime(2024, 2, 29),
      );
    },
  );
  test('out-of-window dates cannot open a day', () {
    final c = DoctorBlockCalendar(DoctorBlockWindow(DateTime(2026, 10, 19)), [
      DoctorBlockedSlot.fromJson(blockedSlot(date: '30-SEP-26')),
      DoctorBlockedSlot.fromJson(blockedSlot()),
      DoctorBlockedSlot.fromJson(blockedSlot(date: '01-JAN-27')),
    ]);
    expect(c.at(DateTime(2026, 9, 30)), isNull);
    expect(c.at(DateTime(2027, 1, 1)), isNull);
    expect(c.at(DateTime(2026, 10, 20)), isNull);
    expect(c.at(DateTime(2026, 10, 21))!.fullDay, isFalse);
  });
  test('admin, cross-doctor and missing identity cannot fetch', () async {
    final h = blockTimeHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    for (final p in [
      AccountProfile(AccountRole.admin, adminProfile()),
      AccountProfile(AccountRole.doctor, {
        ...h.doctorData,
        'doc_code': 'OTHER',
      }),
      AccountProfile(AccountRole.doctor, {...h.doctorData, 'doc_id': ''}),
    ]) {
      final n = h.transport.requests.length;
      await expectLater(_load(h, profile: p), throwsA(isA<AppFailure>()));
      expect(h.transport.requests.length, n);
    }
  });
  test(
    'forced logout, access, expiry and status block reads; expiry today is inclusive',
    () async {
      final h = blockTimeHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      for (final v in [
        {...h.doctorData, 'fl_flag': '1'},
        {...h.doctorData, 'access_flag': '0'},
        {...h.doctorData, 'exp_date': '18-OCT-26'},
        {...h.doctorData, 'user_avail': '0'},
      ]) {
        final n = h.transport.requests.length;
        await expectLater(
          _load(h, profile: AccountProfile(AccountRole.doctor, v)),
          throwsA(isA<AccountAccessFailure>()),
        );
        expect(h.transport.requests.length, n);
      }
      expect(
        (await _load(
          h,
          profile: AccountProfile(AccountRole.doctor, {
            ...h.doctorData,
            'exp_date': '19-OCT-26',
          }),
        )).days,
        isNotEmpty,
      );
    },
  );
  test('obsolete operations cannot start or publish a late reply', () async {
    final h = blockTimeHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    final n = h.transport.requests.length;
    await expectLater(
      _load(h, current: () => false),
      throwsA(isA<ObsoleteRequest>()),
    );
    expect(h.transport.requests.length, n);
    final pending = Completer<JsonMap>();
    var current = true;
    h.transport.onGet = (_) => pending.future;
    final request = _load(h, current: () => current);
    final assertion = expectLater(request, throwsA(isA<ObsoleteRequest>()));
    current = false;
    pending.complete({'count': 0, 'items': null});
    await assertion;
  });
  test('expiry is checked again after a request crosses midnight', () async {
    final h = blockTimeHarness();
    addTearDown(h.auth.dispose);
    await h.signIn();
    final p = AccountProfile(AccountRole.doctor, {
      ...h.doctorData,
      'exp_date': '19-OCT-26',
    });
    h.transport.onGet = (_) async {
      h.now = DateTime(2026, 10, 20);
      return {'count': 0, 'items': null};
    };
    await expectLater(
      _load(h, profile: p),
      throwsA(isA<AccountAccessFailure>()),
    );
  });
  test(
    'network failure is retained without automatic retry or write',
    () async {
      final h = blockTimeHarness();
      addTearDown(h.auth.dispose);
      await h.signIn();
      const failure = AppFailure(
        'Synthetic interruption',
        kind: FailureKind.network,
      );
      h.transport.onGet = (_) async => throw failure;
      final n = h.transport.requests.length, p = h.posts.length;
      await expectLater(_load(h), throwsA(same(failure)));
      expect(h.transport.requests.length, n + 1);
      expect(h.posts.length, p);
    },
  );
}

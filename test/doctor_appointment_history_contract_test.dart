import 'dart:async';
import 'dart:convert';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/history/doctor_appointment_history_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'doctor_appointment_history_test_support.dart';

void main() {
  late AppointmentHistoryHarness h;
  setUp(() async {
    h = AppointmentHistoryHarness();
    await h.signIn();
    h.transport.requests.clear();
  });
  tearDown(() => h.auth.dispose());
  Future<List<AppointmentHistoryRow>> load({
    AccountProfile? profile,
    AppointmentHistoryPatient patient = historyPatient,
    AppointmentHistoryRange? range,
    bool Function()? current,
  }) async => await h.history.load(
    h.auth.session!,
    profile ?? h.auth.profile!,
    patient,
    range ?? AppointmentHistoryRange.initial(h.now),
    isCurrent: current ?? () => true,
  );
  test(
    'GET uses exact native patient and uppercase range parameters, with no writes',
    () async {
      final rows = await load();
      expect(rows.length, 3);
      final request = h.historyReads.single;
      expect(request.method, 'GET');
      expect(request.headers, isEmpty);
      expect(request.uri.host, h.auth.session!.center.baseUri.host);
      expect(request.uri.queryParameters, {
        'begin_date': '01-OCT-26',
        'end_date': '24-OCT-26',
        'p_ph_id': '11',
      });
      expect(h.posts, isEmpty);
    },
  );
  test('patient ID keeps native leading zeros and is encoded once', () async {
    await load(
      patient: const AppointmentHistoryPatient(
        id: '0011',
        name: 'A',
        code: 'B',
      ),
    );
    expect(h.historyReads.single.uri.queryParameters['p_ph_id'], '0011');
  });
  for (final encoded in [false, true]) {
    test(
      'items encoded=$encoded preserves all rows, order, duplicates and null defaults',
      () async {
        final a = {
          ...appointmentHistoryRow(),
          'cancel_status': null,
          'prm_code': 'null',
          'avail': null,
        };
        h.transport.onGet =
            (_) async => {
              'count': '2',
              'items': encoded ? jsonEncode([a, a]) : [a, a],
            };
        final rows = await load();
        expect(rows.length, 2);
        expect(rows.first.value('cancel_status'), '0');
        expect(rows.first.value('prm_code'), '');
        expect(rows.first.value('avail'), '');
        expect(rows.first.values, rows.last.values);
      },
    );
  }
  test(
    'zero count is an empty success without requiring an items array',
    () async {
      h.transport.onGet = (_) async => {'count': '0'};
      expect(await load(), isEmpty);
    },
  );
  for (final response in <JsonMap>[
    {},
    {'count': -1},
    {'count': 'bad'},
    {'count': 1, 'items': []},
    {'count': 1, 'items': 'not JSON'},
    {
      'count': 1,
      'items': [
        {'app_date': '24-OCT-26'},
      ],
    },
    {
      'count': 1,
      'items': [
        {...appointmentHistoryRow(), 'doc_name': true},
      ],
    },
  ]) {
    test(
      'malformed history payload cannot become a false empty state: $response',
      () async {
        h.transport.onGet = (_) async => response;
        await expectLater(load(), throwsA(isA<AppFailure>()));
        expect(h.posts, isEmpty);
      },
    );
  }
  test(
    'month-to-date defaults and date-only label survive leap days and year boundaries',
    () {
      expect(
        AppointmentHistoryRange.initial(DateTime(2024, 2, 29, 23)).label,
        '01-FEB-24  ---  29-FEB-24',
      );
      expect(
        AppointmentHistoryRange.initial(DateTime(2027, 1, 1, 1)).label,
        '01-JAN-27',
      );
      final one = AppointmentHistoryRange(
        DateTime.utc(2026, 10, 24, 23),
        DateTime(2026, 10, 24, 1),
      );
      expect(one.label, '24-OCT-26');
      expect(one.first, DateTime(2026, 10, 24));
    },
  );
  test('future range requires upcoming history access', () async {
    final range = AppointmentHistoryRange(
      DateTime(2026, 10, 25),
      DateTime(2026, 11, 2),
    );
    await load(range: range);
    expect(h.historyReads.single.uri.queryParameters['end_date'], '02-NOV-26');
    h.transport.requests.clear();
    await expectLater(
      load(
        range: range,
        profile: AccountProfile(AccountRole.doctor, {
          ...h.doctorData,
          'upcoming_pat_history': '0',
        }),
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(h.transport.requests, isEmpty);
  });
  for (final range in [
    AppointmentHistoryRange(DateTime(1899, 12, 31), DateTime(2026)),
    AppointmentHistoryRange(DateTime(2026), DateTime(2101)),
    AppointmentHistoryRange(DateTime(2026, 10, 25), DateTime(2026, 10, 24)),
  ]) {
    test('invalid range ${range.label} is rejected before IO', () async {
      await expectLater(load(range: range), throwsA(isA<AppFailure>()));
      expect(h.transport.requests, isEmpty);
    });
  }
  for (final id in ['', 'not-a-number', 'NaN', 'Infinity']) {
    test('invalid patient $id cannot query another endpoint', () async {
      await expectLater(
        load(patient: AppointmentHistoryPatient(id: id, name: 'A', code: 'B')),
        throwsA(isA<AppFailure>()),
      );
      expect(h.transport.requests, isEmpty);
    });
  }
  for (final flags in <JsonMap>[
    {'fl_flag': '1'},
    {'access_flag': '0'},
    {'exp_date': '01-JAN-20'},
    {'pat_app_history': '0'},
    {'doc_code': 'different'},
  ]) {
    test('fresh access guard blocks $flags before a history request', () async {
      await expectLater(
        load(
          profile: AccountProfile(AccountRole.doctor, {
            ...h.doctorData,
            ...flags,
          }),
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(h.transport.requests, isEmpty);
    });
  }
  test('admin identity is not accepted as a doctor history session', () async {
    await expectLater(
      load(profile: AccountProfile(AccountRole.admin, h.adminData)),
      throwsA(isA<AppFailure>()),
    );
    expect(h.transport.requests, isEmpty);
  });
  for (final spec in [
    ('23-OCT-26', '11:00 PM', 'No', AppointmentHistoryStatus.completed),
    ('24-OCT-26', '01:29 PM', 'No', AppointmentHistoryStatus.completed),
    ('24-OCT-26', '01:30 PM', 'No', AppointmentHistoryStatus.upcoming),
    ('24-OCT-26', '01:31 PM', 'No', AppointmentHistoryStatus.upcoming),
    ('25-OCT-26', 'bad', 'No', AppointmentHistoryStatus.upcoming),
    ('23-OCT-26', 'bad', 'Yes', AppointmentHistoryStatus.canceled),
    ('24-OCT-26', '09:00 AM', 'Yes', AppointmentHistoryStatus.canceled),
    ('24-OCT-26', '09:00 PM', 'Yes', AppointmentHistoryStatus.canceled),
    ('25-OCT-26', '09:00 PM', 'Yes', AppointmentHistoryStatus.canceled),
    ('24-OCT-26', 'bad', 'Yes', AppointmentHistoryStatus.notAvailable),
    ('bad', '09:00 AM', 'Yes', AppointmentHistoryStatus.notAvailable),
    ('23-OCT-26', '09:00 AM', 'yes', AppointmentHistoryStatus.completed),
  ]) {
    test('native status for ${spec.$1} ${spec.$2} cancel=${spec.$3}', () {
      final row = AppointmentHistoryRow({
        ...appointmentHistoryRow(day: spec.$1, time: spec.$2),
        'cancel_status': spec.$3,
      });
      expect(row.status(h.now), spec.$4);
    });
  }
  test(
    'choice lists preserve (ID,name) order and keep duplicate names selectable',
    () {
      final rows = [
        ...h.historyRows.map(AppointmentHistoryRow.new),
        AppointmentHistoryRow(h.historyRows.first),
      ];
      final choices = appointmentHistoryChoices(
        rows,
        AppointmentHistoryFilter.doctor,
      );
      expect(choices.map((c) => c.id), ['', '10', '1']);
      expect(choices.map((c) => c.name), ['...', 'Dr. Example', 'Dr. Example']);
      expect(
        appointmentHistoryChoices([], AppointmentHistoryFilter.doctor),
        isEmpty,
      );
    },
  );
  test(
    'three filters combine by exact ID; clearing one retains the others',
    () {
      final rows = h.historyRows.map(AppointmentHistoryRow.new).toList();
      final selected = <AppointmentHistoryFilter, AppointmentHistoryChoice>{
        AppointmentHistoryFilter.doctor: const AppointmentHistoryChoice(
          '1',
          'Dr. Example',
        ),
      };
      expect(filterAppointmentHistory(rows, selected).length, 2);
      selected[AppointmentHistoryFilter
          .service] = const AppointmentHistoryChoice('1', 'Physiotherapy');
      selected[AppointmentHistoryFilter.unit] = const AppointmentHistoryChoice(
        '2',
        'Adult Unit',
      );
      expect(
        filterAppointmentHistory(rows, selected).single.value('doc_id'),
        '1',
      );
      selected.remove(AppointmentHistoryFilter.doctor);
      expect(filterAppointmentHistory(rows, selected).length, 2);
      selected[AppointmentHistoryFilter.unit] = const AppointmentHistoryChoice(
        'missing',
        'No match',
      );
      expect(filterAppointmentHistory(rows, selected), isEmpty);
    },
  );
  test('obsolete requests neither read nor reveal late responses', () async {
    await expectLater(
      load(current: () => false),
      throwsA(isA<ObsoleteRequest>()),
    );
    expect(h.transport.requests, isEmpty);
    var current = true;
    final gate = Completer<JsonMap>();
    h.transport.onGet = (_) => gate.future;
    final future = load(current: () => current);
    final expected = expectLater(future, throwsA(isA<ObsoleteRequest>()));
    current = false;
    gate.complete({'count': h.historyRows.length, 'items': h.historyRows});
    await expected;
    expect(h.historyReads.length, 1);
    expect(h.posts, isEmpty);
  });
}

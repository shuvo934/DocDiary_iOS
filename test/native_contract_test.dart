import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:docdiary_ios/config/server_directory.dart';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_dates.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';

import 'support.dart';

void main() {
  test(
    'JSON null and legacy string null use the same fallback; numeric IDs remain strings',
    () {
      expect(nativeText(null, '0'), '0');
      expect(nativeText('null', '0'), '0');
      expect(nativeText(10.0), '10');
      expect(
        nativeArray(
          jsonEncode([
            {'doc_code': 'D-1'},
          ]),
        ).single['doc_code'],
        'D-1',
      );
      expect(() => nativeArray('not-json'), throwsA(isA<AppFailure>()));
    },
  );

  test(
    'directory accepts BOM and CRLF, ignores invalid lines, deduplicates URLs',
    () {
      final result = ServerDirectory.parse(
        '\uFEFFhttps://one.example/api\r\n\n'
        'https://one.example/api/\ninvalid\nfile:///tmp/test\n# comment\nhttp://two.example:8001/api/',
      );
      expect(result.map((e) => e.toString()), [
        'https://one.example/api/',
        'http://two.example:8001/api/',
      ]);
    },
  );

  test(
    'directory falls back to the native configuration when unavailable',
    () async {
      final transport =
          FakeTransport()
            ..onText = (_) async => throw const AppFailure('Offline');
      expect(
        (await ServerDirectory(transport).load()).map((e) => e.toString()),
        ServerDirectory.fallbackAddresses,
      );
    },
  );

  test(
    'unknown role and empty selected account ID cannot become an admin session',
    () {
      expect(
        () => CenterOption.fromLoginResponse({
          ...doctorLogin(),
          'p_admin_user_flag': '9',
        }),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => CenterOption.fromLoginResponse({
          ...adminLogin(),
          'p_admin_user_id': null,
        }),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  test('all native login result variants keep their correct account roles', () {
    final base = doctorLogin();
    final doctors = [
      {'doc_code': 'D-1', 'doc_name': 'Doctor One', 'depts_name': 'PT'},
    ];
    final admins = [
      {
        'usr_id': 7,
        'usr_name': 'admin',
        'usr_fname': 'Example',
        'usr_lname': 'Admin',
      },
    ];
    expect(
      CenterOption.fromLoginResponse({...base, 'is_available': '0'}),
      isNull,
    );
    final type3 =
        CenterOption.fromLoginResponse({
          ...base,
          'is_available': '3',
          'p_doc_list': jsonEncode(doctors),
        })!;
    expect(type3.accounts.single.role, AccountRole.doctor);
    expect(type3.requiresAccountChoice, isTrue);
    final type4 =
        CenterOption.fromLoginResponse({
          ...base,
          'is_available': '4',
          'p_admin_list': admins,
        })!;
    expect(type4.accounts.single.adminId, '7');
    final mixed =
        CenterOption.fromLoginResponse({
          ...base,
          'is_available': '5',
          'p_admin_list': jsonEncode(admins),
          'p_doc_list': doctors,
        })!;
    expect(mixed.accounts.map((e) => e.role), [
      AccountRole.admin,
      AccountRole.doctor,
    ]);
  });

  test('canceling before account choice requires no server flag update', () {
    final response = {
      ...doctorLogin(),
      'is_available': '5',
      'p_admin_list': [
        {'usr_id': '10', 'usr_name': 'admin'},
      ],
      'p_doc_list': [
        {'doc_code': '10', 'doc_name': 'Doctor'},
      ],
    };
    final center = CenterOption.fromLoginResponse(response)!;
    expect(center.accounts.map((e) => e.key).toSet().length, 2);
    expect(center.requiresAccountChoice, isTrue);
  });

  test(
    'week boundaries match native Saturday to Friday across year boundary',
    () {
      final range = SummaryRange.forPeriod(
        SummaryPeriod.currentWeek,
        DateTime(2027, 1, 1),
      );
      expect(oracleDate(range.first), '26-DEC-26');
      expect(oracleDate(range.last), '01-JAN-27');
      final sunday = SummaryRange.forPeriod(
        SummaryPeriod.currentWeek,
        DateTime(2026, 10, 18),
      );
      expect(oracleDate(sunday.first), '17-OCT-26');
    },
  );

  test(
    'month/expiry calculations handle leap years and month-end clamping',
    () {
      expect(
        calendarAddMonths(DateTime(2027, 11, 30), 3),
        DateTime(2028, 2, 29),
      );
      final range = SummaryRange.forPeriod(
        SummaryPeriod.nextMonth,
        DateTime(2026, 12, 31),
      );
      expect(oracleDate(range.last), '31-JAN-27');
      expect(() => parseOracleDate('31-FEB-26'), throwsA(isA<AppFailure>()));
    },
  );

  test('12 AM, 12 PM, and request timestamp retain native time semantics', () {
    expect(parseAppointmentTime('15-OCT-26', '12:00 AM').hour, 0);
    expect(parseAppointmentTime('15-OCT-26', '12:00 PM').hour, 12);
    expect(
      nativeClockRequest(DateTime(2026, 10, 15, 13, 5)),
      '15-10-2026 01:05 PM',
    );
    expect(
      () => parseAppointmentTime('15-OCT-26', '13:80 PM'),
      throwsA(isA<AppFailure>()),
    );
  });
}

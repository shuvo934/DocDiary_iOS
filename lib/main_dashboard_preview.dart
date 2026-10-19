import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'app.dart';
import 'config/server_directory.dart';
import 'core/native_dates.dart';
import 'core/failure.dart';
import 'core/native_json.dart';
import 'core/transport.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_models.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/profile_repository.dart';
import 'features/auth/session_vault.dart';
import 'features/dashboard/dashboard_repository.dart';

/// Fully offline fixtures. main.dart remains the live API/Keychain entry point.
/// --dart-define=DASHBOARD_PREVIEW_ROLE=admin (or doctor, unit, hr, accounts).
/// --dart-define=DASHBOARD_PREVIEW_TIMER_SECONDS=20 for two short demo meetings.
/// --dart-define=DASHBOARD_PREVIEW_ACCESS=warn3 (warn0, expired, denied,
/// forced, inactive, no_admin or retry) exercises the native dialogs offline.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const role = String.fromEnvironment(
    'DASHBOARD_PREVIEW_ROLE',
    defaultValue: 'doctor',
  );
  const seconds = int.fromEnvironment(
    'DASHBOARD_PREVIEW_TIMER_SECONDS',
    defaultValue: 1800,
  );
  const access = String.fromEnvironment(
    'DASHBOARD_PREVIEW_ACCESS',
    defaultValue: 'ok',
  );
  final clock = DateTime(2026, 10, 17, 10, 30);
  final elapsed = Stopwatch()..start();
  DateTime now() => clock.add(elapsed.elapsed);
  final transport = _DashboardPreviewTransport(
    role,
    clock: clock,
    now: now,
    seconds: seconds > 0 ? seconds : 20,
    access: access,
  );
  const doctor = AccountOption(
    role: AccountRole.doctor,
    doctorCode: 'D-10',
    doctorName: 'Example Therapist',
    department: 'Physiotherapy',
  );
  const admin = AccountOption(
    role: AccountRole.admin,
    adminId: '70',
    adminFirstName: 'Example',
    adminLastName: 'Administrator',
    adminUserName: 'example.admin',
  );
  final center = CenterOption(
    name: 'Example Rehabilitation Centre',
    baseUri: Uri.parse('https://dashboard.preview.invalid/api/'),
    accounts: const [doctor, admin],
    requiresAccountChoice: true,
  );
  final session = AuthSession(
    credentials: const Credentials('00000000000', 'preview-only'),
    center: center,
    account: transport.doctor ? doctor : admin,
    centers: [center],
    remember: false,
  );
  final auth = AuthController(
    repository: AuthRepository(transport, ServerDirectory(transport)),
    profiles: ProfileRepository(
      transport,
      now: now,
      describeClient: () async => const ClientDescriptor(),
    ),
    vault: _DashboardPreviewVault(session),
  );
  await auth.initialize();
  runApp(
    DocDiaryApp(
      auth: auth,
      dashboard: DashboardRepository(transport, now: now),
      initializeOnStart: false,
      onDispose: () {
        elapsed.stop();
        transport.close();
      },
    ),
  );
}

class _DashboardPreviewTransport implements Transport, BinaryTransport {
  _DashboardPreviewTransport(
    this.role, {
    required DateTime clock,
    required this.now,
    required int seconds,
    required this.access,
  }) : first = clock,
       duration = Duration(seconds: seconds);
  final String role;
  final String access;
  bool _failedOnce = false;
  Uint8List? _doctorProfilePicture;
  JsonMap? _profileAddress;
  final _thanas = <JsonMap>[
    {
      'dd_id': '12',
      'dd_dist_id': '1',
      'dd_thana_name': 'Savar',
      'dist_name': 'Dhaka',
    },
    {
      'dd_id': '13',
      'dd_dist_id': '1',
      'dd_thana_name': 'Dhamrai',
      'dist_name': 'Dhaka',
    },
    {
      'dd_id': '21',
      'dd_dist_id': '2',
      'dd_thana_name': 'Gazipur Sadar',
      'dist_name': 'Gazipur',
    },
  ];
  final DateTime first;
  final Duration duration;
  final DateTime Function() now;
  bool get doctor => role == 'doctor' || role == 'unit';

  @override
  Future<JsonMap> postBytes(
    Uri uri,
    Uint8List body, {
    Map<String, String> headers = const {},
    String contentType = 'application/binary',
  }) async {
    if (uri.path.endsWith('/doc_profile/updateImage')) {
      _doctorProfilePicture = Uint8List.fromList(body);
    }
    return {'string_out': 'Successfully Created'};
  }

  String get _expiry => oracleDate(
    first.add(
      Duration(
        days: switch (access) {
          'warn0' => 0,
          'warn3' => 3,
          'expired' => -1,
          _ => 90,
        },
      ),
    ),
  );

  @override
  Future<String> getText(Uri uri) async =>
      'https://dashboard.preview.invalid/api/';

  @override
  Future<JsonMap> get(Uri uri) async {
    final route = uri.path.split('/').last;
    if (access == 'retry' &&
        !_failedOnce &&
        (route == 'getDocData' || route == 'getAdminData')) {
      _failedOnce = true;
      throw const AppFailure(
        'Server problem or Internet not connected',
        kind: FailureKind.network,
      );
    }
    switch (route) {
      case 'getDocThana':
        return {'count': _thanas.length, 'items': _thanas};
      case 'getDocProfile':
        return {
          'count': 1,
          'items': [
            {
              'doc_village': 'Example Road',
              'doc_poffice': 'Savar',
              'dd_thana_name': 'Savar',
              'dist_name': 'Dhaka',
              'doc_dd_id': '12',
              'dist_id': '1',
              'doc_cell': '01700000000',
              'doc_phone': '',
              'doc_email': 'doctor@example.invalid',
              'doc_profile_pic':
                  _doctorProfilePicture == null
                      ? null
                      : base64Encode(_doctorProfilePicture!),
              ...?_profileAddress,
            },
          ],
        };
      case 'getDocData':
        return {
          'items': [
            {
              'user_avail': access == 'inactive' ? '0' : '1',
              'doc_id': '10',
              'doc_code': 'D-10',
              'doc_status': 'Inactive',
              'doc_eff_date': oracleDate(first),
              'doc_name': 'Example Therapist',
              'doc_center_name': 'Example Rehabilitation Centre',
              'fl_flag': access == 'forced' ? '1' : '0',
              'access_flag': access == 'denied' ? '0' : '1',
              'doc_app_first_login_flag': '1',
              'exp_date': _expiry,
              'doc_manager_flag': role == 'doctor' ? '1' : '0',
              'doc_deptd_head_flag': role == 'unit' ? '1' : '0',
            },
          ],
        };
      case 'getAdminData':
        if (access == 'no_admin') {
          return {'count': 0, 'items': null};
        }
        return {
          'items': [
            {
              'usr_id': '70',
              'usr_name': 'example.admin',
              'usr_fname': 'Example',
              'usr_lname': 'Administrator',
              'admin_center_name': 'Example Rehabilitation Centre',
              'usr_mob_app_access': access == 'denied' ? '0' : '1',
              'usr_mob_forced_log_out_flag': access == 'forced' ? '1' : '0',
              'usr_app_first_login_flag': '1',
              'exp_date': _expiry,
              'is_pay_appoint_type_active': '1',
              'all_access_flag':
                  role == 'hr'
                      ? '2'
                      : role == 'accounts'
                      ? '3'
                      : '1',
              'hr_acc_active_flag': '1',
              'hr_payment_active': '0',
              'hr_appointment_active': '1',
              'acc_payment_active': '1',
              'acc_appointment_active': '0',
            },
          ],
        };
      case 'getDocFLFlag':
      case 'getAdminFLFlag':
        return {
          'items': [
            {'fl_flag': '0'},
          ],
        };
      case 'getMeetingCount':
        return {
          'count': 8,
          'items': [
            for (final time in [
              '09:00 AM',
              '09:30 AM',
              '10:00 AM',
              '10:30 AM',
              '11:00 AM',
              '11:30 AM',
              '12:00 PM',
              '12:30 PM',
            ])
              {'appointment_date': '17-OCT-26', 'schedule_time': time},
          ],
        };
      case 'getScheduleCount':
        return {
          'items': [
            {'schedule': '12', 'block_schedule': '2'},
          ],
        };
      case 'getMeetingSchedule':
        final firstNext = first.add(duration);
        final secondNext = firstNext.add(duration);
        final clock = now();
        if (!clock.isBefore(secondNext)) {
          return {'items': <Object?>[]};
        }
        final secondMeeting = !clock.isBefore(firstNext);
        String stamp(DateTime time) {
          String two(int value) => value.toString().padLeft(2, '0');
          return '${two(time.day)}-${two(time.month)}-${time.year} '
              '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
        }
        return {
          'items': [
            {
              'last_sc': stamp(secondMeeting ? firstNext : first),
              'next_sc': stamp(secondMeeting ? secondNext : firstNext),
              'pat_name':
                  secondMeeting ? 'Second Example Patient' : 'Example Patient',
            },
          ],
        };
      case 'getPaymentDataMonthly':
      case 'getPaymentDataOfflineMonthly':
      case 'getPaymentDataOnlineMonthly':
      case 'getAppointDataMonthly':
      case 'getAppointDataOfflineMonthly':
      case 'getAppointDataOnlineMonthly':
      case 'getPaymentDataYearly':
      case 'getPaymentDataOfflineYearly':
      case 'getPaymentDataOnlineYearly':
      case 'getAppointDataYearly':
      case 'getAppointDataOfflineYearly':
      case 'getAppointDataOnlineYearly':
        final yearly = route.endsWith('Yearly');
        final payment = route.startsWith('getPayment');
        final beginning = parseOracleDate(uri.queryParameters['begin_date']!);
        final count =
            yearly ? 12 : DateTime(beginning.year, beginning.month + 1, 0).day;
        final factor =
            route.contains('Offline')
                ? 2
                : route.contains('Online')
                ? 1
                : 3;
        return {
          'count': count,
          'items': [
            for (var i = 0; i < count; i++)
              {
                (yearly ? 'pmonths' : 'dates'):
                    yearly
                        ? const [
                          'JAN',
                          'FEB',
                          'MAR',
                          'APR',
                          'MAY',
                          'JUN',
                          'JUL',
                          'AUG',
                          'SEP',
                          'OCT',
                          'NOV',
                          'DEC',
                        ][i]
                        : (i + 1).toString().padLeft(2, '0'),
                (payment ? 'amount' : 'total_app'):
                    payment
                        ? '${(2000 + (i % 7) * 350) * factor}.50'
                        : (8 + i % 7) * factor,
                (payment ? 'amount1' : 'cancel_app'):
                    payment ? (i % 5) * 75 * factor : i % 3,
              },
          ],
        };
      case 'getAdminAppPayCountNew':
        return {
          'total_app_count': '248',
          'cancel_app_count': '12',
          'total_pay_rcv': '123456.50',
          'total_pay_rtn': '1250.25',
        };
      case 'getDocPic':
        return _doctorProfilePicture == null
            ? {'count': 0, 'items': <Object?>[]}
            : {
              'count': 1,
              'items': [
                {'doc_profile_pic': base64Encode(_doctorProfilePicture!)},
              ],
            };
      case 'getAdminPic':
        return {'count': 0, 'items': <Object?>[]};
      default:
        throw StateError(
          'This fixture has no data for $route. Use main.dart for live login.',
        );
    }
  }

  @override
  Future<JsonMap> post(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    if (uri.path.endsWith('/doc_profile/updateAddress')) {
      final thana = _thanas.lastWhere(
        (row) => row['dd_id'] == headers['P_DD_ID'],
      );
      _profileAddress = {
        'doc_village': headers['P_S_ADDRESS'],
        'doc_poffice': headers['P_POST_OFFICE'],
        'doc_dd_id': thana['dd_id'],
        'dist_id': thana['dd_dist_id'],
        'dd_thana_name': thana['dd_thana_name'],
        'dist_name': thana['dist_name'],
      };
    }
    return {'string_out': 'Successfully Created'};
  }

  @override
  void close() {}
}

class _DashboardPreviewVault implements SessionVault, PasswordChangeVault {
  _DashboardPreviewVault(AuthSession session)
    : state = VaultState(session: session);
  VaultState state;

  @override
  Future<VaultState> load() async => state;

  @override
  Future<void> saveSession(AuthSession session) async {
    state = VaultState(session: session);
  }

  @override
  Future<void> clearSession() async {
    state = const VaultState();
  }

  @override
  Future<void> savePasswordChange(Credentials? remembered) async {
    state = VaultState(remembered: remembered);
  }
}

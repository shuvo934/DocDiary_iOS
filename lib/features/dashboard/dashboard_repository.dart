import 'dart:convert';
import 'dart:typed_data';

import '../../core/failure.dart';
import '../../core/native_dates.dart';
import '../../core/native_json.dart';
import '../../core/transport.dart';
import '../auth/auth_models.dart';
import '../auth/account_access.dart';
import '../auth/profile_repository.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.values,
    this.lastTime = '',
    this.nextTime = '',
    this.nextPatient = '',
    this.asOf,
  });
  final Map<String, String> values;
  final String lastTime;
  final String nextTime;
  final String nextPatient;

  /// Counts/date range were calculated against this request's device clock.
  final DateTime? asOf;
}

class DashboardRepository {
  DashboardRepository(this.transport, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Transport transport;
  final DateTime Function() now;

  void _guard(bool Function()? isCurrent) {
    if (isCurrent != null && !isCurrent()) {
      throw const ObsoleteRequest();
    }
  }

  List<JsonMap> _rows(JsonMap response) {
    if ((!response.containsKey('items') || response['items'] == null) &&
        nativeText(response['count']) != '0') {
      throw const AppFailure(
        'The server returned incomplete dashboard data. Please try again.',
        kind: FailureKind.invalidData,
      );
    }
    return nativeText(response['count']) == '0'
        ? const []
        : nativeItems(response);
  }

  /// A successful empty picture uses the native placeholder. A failed full-load
  /// request goes through the native Retry/Exit/Log Out flow.
  Future<Uint8List?> loadPicture(
    AuthSession session,
    AccountProfile profile,
  ) async {
    final response = await transport.get(
      apiEndpoint(
        session.center.baseUri,
        profile.isDoctor
            ? 'doc_dashboard/getDocPic'
            : 'doc_dashboard/getAdminPic',
        profile.isDoctor
            ? {'doc_id': profile.doctorId}
            : {'p_usr_id': session.account.adminId},
      ),
    );
    final items = _rows(response);
    if (items.isEmpty) {
      return null;
    }
    final encoded = nativeText(
      items.first[profile.isDoctor ? 'doc_profile_pic' : 'usr_profile_pic'],
    );
    if (encoded.isEmpty) {
      return null;
    }
    try {
      return base64Decode(encoded.replaceAll(RegExp(r'\s+'), ''));
    } on FormatException {
      throw const AppFailure(
        'The server returned an invalid profile picture. Please try again.',
        kind: FailureKind.invalidData,
      );
    }
  }

  Future<DashboardSummary> load(
    AuthSession session,
    AccountProfile profile,
    SummaryPeriod period, {
    bool Function()? isCurrent,
  }) async {
    _guard(isCurrent);
    final clock = now();
    ProfileRepository.checkAccess(profile, clock);
    final range = SummaryRange.forPeriod(period, clock);
    final doctor = profile.isDoctor;
    final flag = await transport.get(
      apiEndpoint(
        session.center.baseUri,
        doctor ? 'doc_dashboard/getDocFLFlag' : 'doc_dashboard/getAdminFLFlag',
        doctor
            ? {'p_doc_id': profile.doctorId}
            : {'p_usr_id': session.account.adminId},
      ),
    );
    _guard(isCurrent);
    final flags =
        nativeText(flag['count']) == '0' ? <JsonMap>[] : nativeItems(flag);
    if (flags.isEmpty ||
        !flags.first.containsKey('fl_flag') ||
        !const ['0', '1'].contains(nativeText(flags.first['fl_flag'], '0'))) {
      throw const AppFailure(
        'Account access could not be verified. Please try again.',
      );
    }
    if (nativeText(flags.first['fl_flag']) == '1') {
      throw const AccountAccessFailure.forcedLogout();
    }
    if (!doctor) {
      final response = await transport.get(
        apiEndpoint(
          session.center.baseUri,
          'doc_dashboard/getAdminAppPayCountNew',
          {
            'begin_date': oracleDate(range.first),
            'end_date': oracleDate(range.last),
            'user_id': profile.adminFilter,
          },
        ),
      );
      _guard(isCurrent);
      ProfileRepository.checkAccess(profile, now());
      if (!const [
        'total_app_count',
        'cancel_app_count',
        'total_pay_rcv',
        'total_pay_rtn',
      ].every(response.containsKey)) {
        throw const AppFailure(
          'The server returned incomplete dashboard totals. Please try again.',
          kind: FailureKind.invalidData,
        );
      }
      return DashboardSummary(
        asOf: clock,
        values: {
          'TOTAL APPOINTMENT': nativeText(response['total_app_count'], '0'),
          'CANCELED APPOINTMENT': nativeText(response['cancel_app_count'], '0'),
          'PAYMENT RECEIVED': nativeText(response['total_pay_rcv'], '0'),
          'PAYMENT RETURNED': nativeText(response['total_pay_rtn'], '0'),
        },
      );
    }
    final query = {
      'doc_id': profile.doctorId,
      'first_date': oracleDate(range.first),
      'end_date': oracleDate(range.last),
    };
    final responses = await Future.wait([
      transport.get(
        apiEndpoint(
          session.center.baseUri,
          'doc_dashboard/getMeetingCount',
          query,
        ),
      ),
      transport.get(
        apiEndpoint(
          session.center.baseUri,
          'doc_dashboard/getScheduleCount',
          query,
        ),
      ),
      transport.get(
        apiEndpoint(
          session.center.baseUri,
          'doc_dashboard/getMeetingSchedule',
          {'doc_id': profile.doctorId, 'time_now': nativeClockRequest(clock)},
        ),
      ),
    ]);
    _guard(isCurrent);
    ProfileRepository.checkAccess(profile, now());
    final appointments = _rows(responses[0]);
    var completed = 0;
    var remaining = 0;
    for (final row in appointments) {
      final time = nativeText(row['schedule_time']);
      if (time.isEmpty) {
        continue;
      }
      final day = nativeText(row['appointment_date'], oracleDate(clock));
      final appointment = parseAppointmentTime(day, time);
      if (appointment.isAfter(clock)) {
        remaining++;
      } else {
        completed++;
      }
    }
    final schedules = _rows(responses[1]);
    if (schedules.isNotEmpty &&
        (!schedules.first.containsKey('schedule') ||
            !schedules.first.containsKey('block_schedule'))) {
      throw const AppFailure(
        'The server returned incomplete schedule totals. Please try again.',
        kind: FailureKind.invalidData,
      );
    }
    final schedule = schedules.isEmpty ? <String, Object?>{} : schedules.first;
    final next = _rows(responses[2]);
    return DashboardSummary(
      asOf: clock,
      values: {
        'TOTAL SCHEDULE': nativeText(schedule['schedule'], '0'),
        'BLOCKED SCHEDULE': nativeText(schedule['block_schedule'], '0'),
        // Native "COMPLETED" means scheduled time has elapsed, not a clinical status.
        'TOTAL': nativeText(
          responses[0]['count'],
          appointments.length.toString(),
        ),
        'COMPLETED': completed.toString(),
        'REMAINING': remaining.toString(),
      },
      lastTime: next.isEmpty ? '' : nativeText(next.first['last_sc']),
      nextTime: next.isEmpty ? '' : nativeText(next.first['next_sc']),
      nextPatient: next.isEmpty ? '' : nativeText(next.first['pat_name']),
    );
  }
}

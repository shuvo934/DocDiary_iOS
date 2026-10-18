import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../../core/transport.dart';
import '../auth/auth_models.dart';
import '../auth/account_access.dart';
import '../auth/profile_repository.dart';
import 'admin_chart_models.dart';

class ObsoleteChartRequest implements Exception {
  const ObsoleteChartRequest();
}

class AdminChartRepository {
  AdminChartRepository(this.transport, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Transport transport;
  final DateTime Function() now;

  void _guard(bool Function()? isCurrent) {
    if (isCurrent != null && !isCurrent()) {
      throw const ObsoleteChartRequest();
    }
  }

  Future<void> _verify(
    AuthSession session,
    AccountProfile profile,
    AdminChartType type,
    bool Function()? isCurrent,
  ) async {
    _guard(isCurrent);
    if (profile.isDoctor || session.account.role != AccountRole.admin) {
      throw const AppFailure(
        'Admin charts are not available for this account.',
        kind: FailureKind.denied,
      );
    }
    ProfileRepository.checkAccess(profile, now());
    if (profile.value('all_access_flag') != '1' &&
        profile.adminFilter.isEmpty) {
      throw const AppFailure(
        'The administrator identifier was not returned by the server.',
        kind: FailureKind.invalidData,
      );
    }
    if (type != AdminChartType.all &&
        profile.value('is_pay_appoint_type_active') != '1') {
      throw const AppFailure(
        'This account does not have chart type selection.',
        kind: FailureKind.invalidData,
      );
    }
    final response = await transport.get(
      apiEndpoint(session.center.baseUri, 'doc_dashboard/getAdminFLFlag', {
        'p_usr_id': profile.value('usr_id', session.account.adminId),
      }),
    );
    _guard(isCurrent);
    final flags =
        nativeText(response['count']) == '0'
            ? <JsonMap>[]
            : nativeItems(response);
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
  }

  Future<AdminChartData> _read(
    AuthSession session,
    AccountProfile profile,
    AdminChartKind kind,
    AdminChartType type,
    AdminChartSelection selection,
    bool Function()? isCurrent,
  ) async {
    _guard(isCurrent);
    ProfileRepository.checkAccess(profile, now());
    if (!selection.isAllowed(now())) {
      throw const AppFailure(
        'Select a date within the available chart range.',
        kind: FailureKind.invalidData,
      );
    }
    final stem =
        kind == AdminChartKind.payment ? 'getPaymentData' : 'getAppointData';
    final filter = switch (type) {
      AdminChartType.all => '',
      AdminChartType.offline => 'Offline',
      AdminChartType.online => 'Online',
    };
    final period =
        selection.mode == AdminChartMode.monthly ? 'Monthly' : 'Yearly';
    final response = await transport.get(
      apiEndpoint(session.center.baseUri, 'doc_dashboard/$stem$filter$period', {
        ...selection.query,
        if (kind == AdminChartKind.payment) 'user_id': profile.adminFilter,
      }),
    );
    _guard(isCurrent);
    ProfileRepository.checkAccess(profile, now());
    return AdminChartData.fromResponse(kind, selection.mode, response);
  }

  Future<AdminChartPair> loadBoth(
    AuthSession session,
    AccountProfile profile,
    AdminChartType type,
    AdminChartSelection selection, {
    bool Function()? isCurrent,
  }) async {
    await _verify(session, profile, type, isCurrent);
    // Native queues Payment first, then Appointment. Commit the pair only when
    // both reads succeed; a failed read never turns into zero-valued data.
    final payment = await _read(
      session,
      profile,
      AdminChartKind.payment,
      type,
      selection,
      isCurrent,
    );
    final appointment = await _read(
      session,
      profile,
      AdminChartKind.appointment,
      type,
      selection,
      isCurrent,
    );
    return AdminChartPair(payment, appointment);
  }

  Future<AdminChartData> loadOne(
    AuthSession session,
    AccountProfile profile,
    AdminChartKind kind,
    AdminChartType type,
    AdminChartSelection selection, {
    bool Function()? isCurrent,
  }) async {
    await _verify(session, profile, type, isCurrent);
    return _read(session, profile, kind, type, selection, isCurrent);
  }
}

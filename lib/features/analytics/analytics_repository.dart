import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../../core/transport.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../management/management_access.dart';
import 'analytics_models.dart';

class AnalyticsUnavailable implements Exception {
  const AnalyticsUnavailable();
}

class AnalyticsRepository {
  AnalyticsRepository(this.transport, {DateTime Function()? now})
    : now = now ?? DateTime.now;

  final Transport transport;
  final DateTime Function() now;

  bool portalEnabled(AccountProfile profile) =>
      profile.value('is_pay_appoint_type_active') == '1';

  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() isCurrent, {
    bool portal = false,
  }) {
    if (!isCurrent()) throw const ObsoleteRequest();
    ProfileRepository.checkAccess(profile, now());
    if (session.account.role != AccountRole.admin ||
        !ManagementAccess(profile).allows(ManagementDestination.analytics) ||
        (portal && !portalEnabled(profile))) {
      throw const AnalyticsUnavailable();
    }
    final id = profile.value('usr_id');
    if (id.isNotEmpty && id != session.account.identity) {
      throw const AppFailure(
        'The server returned information for a different account.',
        kind: FailureKind.invalidData,
      );
    }
  }

  Future<List<JsonMap>> _read(
    AuthSession session,
    AccountProfile profile,
    AnalyticsRange range,
    String endpoint,
    bool Function() isCurrent, {
    bool portal = false,
    Map<String, String> extra = const {},
  }) async {
    guard(session, profile, isCurrent, portal: portal);
    if (!range.allowed(now())) {
      throw const AppFailure(
        'Please select a valid date range.',
        kind: FailureKind.invalidData,
      );
    }
    final response = await transport
        .get(
          apiEndpoint(session.center.baseUri, 'analytic_dashboard/$endpoint', {
            ...range.query,
            ...extra,
          }),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout:
              () =>
                  throw const AppFailure(
                    'The server took too long to respond.',
                    kind: FailureKind.network,
                  ),
        );
    guard(session, profile, isCurrent, portal: portal);
    final count = int.tryParse(nativeText(response['count']).trim());
    final rows = nativeItems(response);
    if (!response.containsKey('items') ||
        count == null ||
        count != rows.length) {
      throw const AppFailure(
        'The server returned incomplete analytics data.',
        kind: FailureKind.invalidData,
      );
    }
    return rows;
  }

  Future<AnalyticsLogin> login(
    AuthSession session,
    AccountProfile profile,
    AnalyticsRange range, {
    required bool portal,
    required bool Function() isCurrent,
  }) async {
    final trend = AnalyticsTrend(
      await _read(
        session,
        profile,
        range,
        portal ? 'getOPASLoginStatus' : 'getAppLoginStatus',
        isCurrent,
        portal: portal,
      ),
      const ['all_amount', 'u_amount'],
    );
    final rows = await _read(
      session,
      profile,
      range,
      'getTotalUnqLogin',
      isCurrent,
      portal: portal,
      extra: {'p_log_type': portal ? '1' : '3'},
    );
    var unique = 0;
    for (final row in rows) {
      unique = analyticsCount(row, 'total_unq_amount');
    }
    return AnalyticsLogin(trend, unique);
  }

  Future<AnalyticsAppointments> appointments(
    AuthSession session,
    AccountProfile profile,
    AnalyticsRange range, {
    required bool Function() isCurrent,
  }) async {
    const fields = ['all_app_count', 'c_app_count', 'uc_app_count'];
    final initialized = AnalyticsTrend(
      await _read(
        session,
        profile,
        range,
        'getAppInitCountStatus',
        isCurrent,
        portal: true,
      ),
      fields,
    );
    final scheduled = AnalyticsTrend(
      await _read(
        session,
        profile,
        range,
        'getAppSchCountStatus',
        isCurrent,
        portal: true,
      ),
      fields,
    );
    return AnalyticsAppointments(initialized, scheduled);
  }

  Future<AnalyticsPayments> payments(
    AuthSession session,
    AccountProfile profile,
    AnalyticsRange range, {
    required bool Function() isCurrent,
  }) async {
    final trend = AnalyticsTrend(
      await _read(
        session,
        profile,
        range,
        'getOPASPayStatus',
        isCurrent,
        portal: true,
      ),
      analyticsPaymentFields,
    );
    final cards = await _read(
      session,
      profile,
      range,
      'getOPASCardPayStatus',
      isCurrent,
      portal: true,
    );
    return AnalyticsPayments(trend, cards);
  }

  Future<List<AnalyticsReason>> reasons(
    AuthSession session,
    AccountProfile profile,
    AnalyticsRange range,
    AnalyticsCardSelection selection, {
    required bool Function() isCurrent,
  }) async {
    final endpoint = switch (selection.status) {
      AnalyticsCardStatus.failed => 'getCardWiseFailedResult',
      AnalyticsCardStatus.noResult => 'getCardWiseNRResult',
      AnalyticsCardStatus.completed => throw const AnalyticsUnavailable(),
    };
    final rows = await _read(
      session,
      profile,
      range,
      endpoint,
      isCurrent,
      portal: true,
      extra: {'card_name': selection.card.name},
    );
    return List.unmodifiable(rows.map(AnalyticsReason.new));
  }
}

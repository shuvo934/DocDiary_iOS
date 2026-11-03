import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../../core/transport.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../management/management_access.dart';
import 'report_manager_menu.dart';
import 'report_manager_models.dart';

class ReportManagerUnavailable implements Exception {
  const ReportManagerUnavailable();
}

/// The GET-only endpoints used by ReportView and its four data activities.
class ReportManagerRepository {
  ReportManagerRepository(this.transport, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Transport transport;
  final DateTime Function() now;
  String get moduleName => 'Report Manager';
  void guard(
    AuthSession session,
    AccountProfile profile,
    ReportManagerItem item,
    bool Function() isCurrent,
  ) {
    if (!isCurrent()) throw const ObsoleteRequest();
    final identity = profile.value(profile.isDoctor ? 'doc_code' : 'usr_id');
    // Native getAdminData is keyed by the signed-in p_usr_id, but its legacy
    // response need not repeat usr_id. Match a returned ID when present.
    final matchingIdentity =
        profile.isDoctor
            ? identity.isNotEmpty &&
                identity == session.account.doctorCode &&
                profile.doctorId.isNotEmpty
            : session.account.adminId.isNotEmpty &&
                (identity.isEmpty || identity == session.account.adminId) &&
                (session.account.adminUserName.isEmpty ||
                    profile.value('usr_name') == session.account.adminUserName);
    reportRequire(
      profile.role == session.account.role && matchingIdentity,
      'The server returned information for a different account. Please try again.',
    );
    ProfileRepository.checkAccess(profile, now());
    if (!ManagementAccess(profile).canOpenReports ||
        !nativeReportManagerItems(session.center.baseUri).contains(item)) {
      throw const ReportManagerUnavailable();
    }
  }

  Future<List<JsonMap>> _get(
    AuthSession session,
    AccountProfile profile,
    ReportManagerItem item,
    String endpoint,
    Map<String, String>? query,
    bool Function() current,
  ) async {
    guard(session, profile, item, current);
    final data = await transport
        .get(
          apiEndpoint(
            session.center.baseUri,
            'report_manager/$endpoint',
            query,
          ),
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
    guard(session, profile, item, current);
    final count = int.tryParse(nativeText(data['count']));
    reportRequire(
      count != null && count >= 0,
      'The server returned an invalid report count.',
    );
    if (count == 0) return const [];
    final rows = nativeItems(data);
    reportRequire(
      rows.length == count,
      'The server returned incomplete report data.',
    );
    return rows;
  }

  Future<List<ReportChoice>> choices(
    AuthSession session,
    AccountProfile profile,
    ReportManagerItem item,
    ReportParameter parameter, {
    String parentId = '',
    bool includeClear = false,
    required bool Function() isCurrent,
  }) async {
    reportRequire(
      parentId.isEmpty || reportId(parentId),
      'Please select a report filter from the list.',
    );
    final endpoint = switch (parameter) {
      ReportParameter.department => 'getDeptd',
      ReportParameter.unit => 'getDepts',
      ReportParameter.doctor => 'getDoctors',
      ReportParameter.service => 'getService',
    };
    final query = switch (parameter) {
      ReportParameter.department => null,
      ReportParameter.unit => {'deptd_id': parentId},
      _ => {'depts_id': parentId},
    };
    final rows = await _get(session, profile, item, endpoint, query, isCurrent);
    final result =
        rows
            .map(
              (r) => ReportChoice(
                nativeText(r[parameter.idKey]).trim(),
                nativeText(r[parameter.nameKey]),
              ),
            )
            .toList();
    reportRequire(
      result.every((r) => reportId(r.id) && r.name.trim().isNotEmpty),
      'The server returned an invalid report filter.',
    );
    return List.unmodifiable([
      if (includeClear && result.isNotEmpty) ReportChoice.clear,
      ...result,
    ]);
  }

  Future<ReportCatalogue> catalogue(
    AuthSession session,
    AccountProfile profile,
    ReportManagerItem item, {
    required bool Function() isCurrent,
  }) async {
    final departments = await choices(
      session,
      profile,
      item,
      ReportParameter.department,
      includeClear: true,
      isCurrent: isCurrent,
    );
    final units = await choices(
      session,
      profile,
      item,
      ReportParameter.unit,
      includeClear: true,
      isCurrent: isCurrent,
    );
    final services = await choices(
      session,
      profile,
      item,
      ReportParameter.service,
      includeClear: true,
      isCurrent: isCurrent,
    );
    final config = await _get(
      session,
      profile,
      item,
      'getUrlData',
      null,
      isCurrent,
    );
    return ReportCatalogue(
      departments: departments,
      units: units,
      services: services,
      pdf:
          config.isEmpty
              ? const ReportServerConfig()
              : ReportServerConfig.fromData(config.last),
    );
  }

  Future<ReportTable> table(
    AuthSession session,
    AccountProfile profile,
    ReportRequest request, {
    required bool Function() isCurrent,
  }) async {
    request.validate();
    return ReportTable.fromData(
      request.item,
      await _get(
        session,
        profile,
        request.item,
        request.item.dataEndpoint,
        request.query,
        isCurrent,
      ),
    );
  }
}

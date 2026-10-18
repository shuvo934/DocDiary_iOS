import '../../core/client_descriptor.dart';
export '../../core/client_descriptor.dart' show ClientDescriptor;

import '../../core/failure.dart';
import '../../core/native_dates.dart';
import '../../core/native_json.dart';
import '../../core/transport.dart';
import 'account_access.dart';
import 'auth_models.dart';

class AccountProfile {
  AccountProfile(this.role, JsonMap values) : values = Map.unmodifiable(values);
  final AccountRole role;
  final JsonMap values;

  String value(String key, [String fallback = '']) =>
      nativeText(values[key], fallback);
  String get doctorId => value('doc_id');
  bool get isDoctor => role == AccountRole.doctor;
  String get displayName {
    if (isDoctor) {
      final name = value('doc_name');
      return name.toLowerCase().startsWith('dr.') ? name : 'Dr. $name';
    }
    return '${value('usr_fname')} ${value('usr_lname')}'.trim().isEmpty
        ? value('usr_name')
        : '${value('usr_fname')} ${value('usr_lname')}'.trim();
  }

  String get centerName =>
      value(isDoctor ? 'doc_center_name' : 'admin_center_name');
  String get adminFilter =>
      value('all_access_flag') == '1' ? '' : value('usr_name');
  String get forceFlag =>
      value(isDoctor ? 'fl_flag' : 'usr_mob_forced_log_out_flag', '0');
  String get accessFlag =>
      value(isDoctor ? 'access_flag' : 'usr_mob_app_access', '0');
  String get firstLoginFlag => value(
    isDoctor ? 'doc_app_first_login_flag' : 'usr_app_first_login_flag',
    '0',
  );
  String get expiryDate => value('exp_date');
}

class ProfileRepository {
  ProfileRepository(
    this.transport, {
    DateTime Function()? now,
    Future<ClientDescriptor> Function()? describeClient,
  }) : now = now ?? DateTime.now,
       describeClient = describeClient ?? ClientDescriptor.collect;

  final Transport transport;
  final DateTime Function() now;
  final Future<ClientDescriptor> Function() describeClient;

  void _guard(bool Function()? isCurrent) {
    if (isCurrent != null && !isCurrent()) {
      throw const ObsoleteRequest();
    }
  }

  Future<AccountProfile> open(
    AuthSession session, {
    bool recordLogin = true,
    bool Function()? isCurrent,
  }) async {
    _guard(isCurrent);
    final doctor = session.account.role == AccountRole.doctor;
    final root = await transport.get(
      apiEndpoint(
        session.center.baseUri,
        doctor ? 'doc_dashboard/getDocData' : 'doc_dashboard/getAdminData',
        doctor
            ? {'doc_code': session.account.doctorCode}
            : {'p_usr_id': session.account.adminId},
      ),
    );
    _guard(isCurrent);
    if ((!root.containsKey('items') || root['items'] == null) &&
        nativeText(root['count']) != '0') {
      throw const AppFailure(
        'The server returned an incomplete account response.',
        kind: FailureKind.invalidData,
      );
    }
    final items =
        nativeText(root['count']) == '0' ? <JsonMap>[] : nativeItems(root);
    if (items.isEmpty) {
      throw doctor
          ? AccountAccessFailure.doctorUnavailable('', '')
          : const AccountAccessFailure.adminUnavailable();
    }
    var profile = AccountProfile(session.account.role, items.first);
    checkBasicAccess(profile);
    if (!profile.values.containsKey('exp_date') ||
        !profile.values.containsKey(
          doctor ? 'doc_app_first_login_flag' : 'usr_app_first_login_flag',
        )) {
      throw const AppFailure(
        'The server returned incomplete account initialization data. Please try again.',
        kind: FailureKind.invalidData,
      );
    }
    final nowDate = now();
    var expiry = profile.expiryDate;
    if (expiry.isEmpty) {
      if (!recordLogin || profile.firstLoginFlag == '1') {
        throw const AppFailure(
          'The server did not return your access expiry date. Please try again.',
          kind: FailureKind.invalidData,
        );
      }
      expiry = oracleDate(calendarAddMonths(nowDate, 3));
      profile = AccountProfile(profile.role, {
        ...profile.values,
        'exp_date': expiry,
      });
    }
    parseOracleDate(
      expiry,
    ); // Malformed expiry is retryable, never an implicit extension.
    if (doctor && profile.doctorId.isEmpty) {
      throw const AppFailure(
        'The doctor identifier was not returned by the server.',
        kind: FailureKind.invalidData,
      );
    }
    if (recordLogin) {
      _guard(isCurrent);
      if (profile.firstLoginFlag != '1') {
        await _successfulPost(
          session,
          doctor
              ? 'doc_dashboard/updateDocExpDate'
              : 'doc_dashboard/updateUSRExpDate',
          {
            'P_DATE': expiry,
            (doctor ? 'P_DOC_CODE' : 'P_USR_ID'): session.account.identity,
          },
        );
        _guard(isCurrent);
      }
      final client = await describeClient();
      _guard(isCurrent);
      await _successfulPost(session, 'doc_dashboard/loginLog', {
        'P_IULL_USER_ID':
            doctor ? profile.value('doc_code') : profile.value('usr_name'),
        'P_IULL_CLIENT_HOST_NAME': client.host,
        'P_IULL_CLIENT_IP_ADDR': client.ip,
        'P_IULL_CLIENT_HOST_USER_NAME': client.hostUser,
        'P_IULL_SESSION_USER_ID':
            doctor ? profile.value('doc_id', '0') : session.account.adminId,
        'P_IULL_OS_NAME': client.os,
      });
      _guard(isCurrent);
    }
    // Native expiry compares calendar dates, so today's expiry remains valid.
    checkAccess(profile, now());
    return profile;
  }

  static void checkBasicAccess(AccountProfile profile) {
    // Native doctor availability/status takes precedence over all other flags.
    if (profile.isDoctor && profile.value('user_avail') != '1') {
      throw AccountAccessFailure.doctorUnavailable(
        profile.value('doc_status'),
        profile.value('doc_eff_date'),
      );
    }
    final forceKey =
        profile.isDoctor ? 'fl_flag' : 'usr_mob_forced_log_out_flag';
    final accessKey = profile.isDoctor ? 'access_flag' : 'usr_mob_app_access';
    if (!profile.values.containsKey(forceKey) ||
        !profile.values.containsKey(accessKey) ||
        !const ['0', '1'].contains(profile.forceFlag)) {
      throw const AppFailure(
        'The server returned incomplete account access flags. Please try again.',
        kind: FailureKind.invalidData,
      );
    }
    if (profile.forceFlag == '1') {
      throw const AccountAccessFailure.forcedLogout();
    }
    if (profile.accessFlag != '1') {
      throw const AccountAccessFailure.mobileAccess();
    }
  }

  static void checkAccess(AccountProfile profile, DateTime now) {
    checkBasicAccess(profile);
    if (profile.expiryDate.isEmpty) {
      throw const AppFailure(
        'The server did not return your access expiry date. Please try again.',
        kind: FailureKind.invalidData,
      );
    }
    if (parseOracleDate(profile.expiryDate).isBefore(dateOnly(now))) {
      throw AccountAccessFailure.expired(profile.expiryDate);
    }
  }

  Future<void> _successfulPost(
    AuthSession session,
    String route,
    Map<String, String> headers,
  ) async {
    final response = await transport.post(
      apiEndpoint(session.center.baseUri, route),
      headers: headers,
    );
    if (nativeText(response['string_out']) != 'Successfully Created') {
      throw AppFailure(
        nativeText(
          response['string_out'],
          'The server could not complete account initialization. Please try again.',
        ),
      );
    }
  }
}

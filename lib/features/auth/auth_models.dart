import '../../core/failure.dart';
import '../../core/native_json.dart';

enum AccountRole {
  doctor('1'),
  admin('2');

  const AccountRole(this.nativeFlag);
  final String nativeFlag;

  static AccountRole parse(Object? value) => switch (nativeText(value)) {
    '1' => doctor,
    '2' => admin,
    _ =>
      throw const AppFailure(
        'The server returned an unsupported account role.',
        kind: FailureKind.invalidData,
      ),
  };
}

class Credentials {
  const Credentials(this.mobile, this.password);
  final String mobile;
  final String password;

  JsonMap toJson() => {'mobile': mobile, 'password': password};
  factory Credentials.fromJson(JsonMap json) => Credentials(
    nativeText(json['mobile']),
    json['password'] is String
        ? json['password']! as String
        : nativeText(json['password']),
  );

  @override
  String toString() => 'Credentials(<redacted>)';
}

class AccountOption {
  const AccountOption({
    required this.role,
    this.doctorCode = '',
    this.doctorName = '',
    this.department = '',
    this.adminId = '',
    this.adminFirstName = '',
    this.adminLastName = '',
    this.adminUserName = '',
  });

  final AccountRole role;
  final String doctorCode;
  final String doctorName;
  final String department;
  final String adminId;
  final String adminFirstName;
  final String adminLastName;
  final String adminUserName;

  String get identity => role == AccountRole.doctor ? doctorCode : adminId;
  String get key => '${role.nativeFlag}:$identity';
  String get displayName {
    if (role == AccountRole.doctor) {
      return doctorName.isEmpty ? doctorCode : doctorName;
    }
    final fullName = '$adminFirstName $adminLastName'.trim();
    return fullName.isEmpty ? adminUserName : fullName;
  }

  factory AccountOption.fromJson(JsonMap json) {
    final account = AccountOption(
      role: AccountRole.parse(json['user_admin_flag']),
      doctorCode: nativeText(json['doc_code']),
      doctorName: nativeText(json['doc_name']),
      department: nativeText(json['depts_name']),
      adminId: nativeText(json['admin_user_id']),
      adminFirstName: nativeText(json['admin_user_fname']),
      adminLastName: nativeText(json['admin_user_lname']),
      adminUserName: nativeText(json['admin_user_name']),
    );
    if (account.identity.isEmpty) {
      throw const AppFailure(
        'The server did not return an account identifier.',
        kind: FailureKind.invalidData,
      );
    }
    return account;
  }

  JsonMap toJson() => {
    'user_admin_flag': role.nativeFlag,
    'doc_code': doctorCode,
    'doc_name': doctorName,
    'depts_name': department,
    'admin_user_id': adminId,
    'admin_user_fname': adminFirstName,
    'admin_user_lname': adminLastName,
    'admin_user_name': adminUserName,
  };
}

class CenterOption {
  CenterOption({
    required this.name,
    required this.baseUri,
    required List<AccountOption> accounts,
    required this.requiresAccountChoice,
  }) : accounts = List.unmodifiable(accounts);

  final String name;
  final Uri baseUri;
  final List<AccountOption> accounts;
  final bool requiresAccountChoice;

  /// Native 0/2 responses have no matching account; neither is a connection
  /// failure. Their is_online message is handled by discovery.
  static CenterOption? fromLoginResponse(JsonMap json) {
    final available = nativeText(json['is_available']);
    if (available == '0' || available == '2') {
      return null;
    }
    if (!const ['1', '3', '4', '5'].contains(available)) {
      throw const AppFailure(
        'The server returned an unsupported login result.',
        kind: FailureKind.invalidData,
      );
    }
    final accounts = <AccountOption>[];
    if (available == '1') {
      accounts.add(
        AccountOption.fromJson({
          'user_admin_flag': json['p_admin_user_flag'],
          'doc_code': json['p_doc_code'],
          'admin_user_id': json['p_admin_user_id'],
        }),
      );
    } else {
      if (available == '4' || available == '5') {
        for (final entry in nativeArray(json['p_admin_list'])) {
          accounts.add(
            AccountOption.fromJson({
              'user_admin_flag': '2',
              'admin_user_id': entry['usr_id'],
              'admin_user_fname': entry['usr_fname'],
              'admin_user_lname': entry['usr_lname'],
              'admin_user_name': entry['usr_name'],
            }),
          );
        }
      }
      if (available == '3' || available == '5') {
        for (final entry in nativeArray(json['p_doc_list'])) {
          accounts.add(
            AccountOption.fromJson({
              'user_admin_flag': '1',
              'doc_code': entry['doc_code'],
              'doc_name': entry['doc_name'],
              'depts_name': entry['depts_name'],
            }),
          );
        }
      }
    }
    if (accounts.isEmpty) {
      throw const AppFailure(
        'No usable account was returned for this centre.',
        kind: FailureKind.invalidData,
      );
    }
    return CenterOption(
      name: nativeText(json['p_center_name']),
      baseUri: apiBase(nativeText(json['p_center_api'])),
      accounts: accounts,
      requiresAccountChoice: available != '1',
    );
  }

  JsonMap toJson() => {
    'name': name,
    'base_uri': baseUri.toString(),
    'requires_account_choice': requiresAccountChoice,
    'accounts': accounts.map((e) => e.toJson()).toList(),
  };

  factory CenterOption.fromJson(JsonMap json) => CenterOption(
    name: nativeText(json['name']),
    baseUri: apiBase(nativeText(json['base_uri'])),
    accounts:
        nativeArray(json['accounts']).map(AccountOption.fromJson).toList(),
    requiresAccountChoice: json['requires_account_choice'] == true,
  );
}

class AuthSession {
  AuthSession({
    required this.credentials,
    required this.center,
    required this.account,
    required List<CenterOption> centers,
    required this.remember,
  }) : centers = List.unmodifiable(centers) {
    if (credentials.mobile.isEmpty ||
        credentials.password.isEmpty ||
        !center.accounts.any((a) => a.key == account.key) ||
        !centers.any(
          (c) =>
              c.baseUri == center.baseUri &&
              c.accounts.any((a) => a.key == account.key),
        )) {
      throw const AppFailure(
        'The saved sign-in information is incomplete.',
        kind: FailureKind.invalidData,
      );
    }
  }

  final Credentials credentials;
  final CenterOption center;
  final AccountOption account;
  final List<CenterOption> centers;
  final bool remember;

  JsonMap toJson() => {
    'credentials': credentials.toJson(),
    'center': center.toJson(),
    'account': account.toJson(),
    'centers': centers.map((e) => e.toJson()).toList(),
    'remember': remember,
  };

  factory AuthSession.fromJson(JsonMap json) => AuthSession(
    credentials: Credentials.fromJson(nativeObject(json['credentials'])),
    center: CenterOption.fromJson(nativeObject(json['center'])),
    account: AccountOption.fromJson(nativeObject(json['account'])),
    centers: nativeArray(json['centers']).map(CenterOption.fromJson).toList(),
    remember: json['remember'] == true,
  );
}

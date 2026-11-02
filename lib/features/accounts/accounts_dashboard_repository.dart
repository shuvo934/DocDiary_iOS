import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../../core/transport.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../management/management_access.dart';
import 'accounts_dashboard_models.dart';

class AccountsModuleUnavailable implements Exception {
  const AccountsModuleUnavailable();
}

class AccountsDashboardRepository {
  AccountsDashboardRepository(this.transport, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Transport transport;
  final DateTime Function() now;
  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() current,
  ) {
    if (!current()) throw const ObsoleteRequest();
    accountsRequire(
      !profile.isDoctor &&
          session.account.role == AccountRole.admin &&
          profile.role == session.account.role &&
          (profile.value('usr_id').isEmpty ||
              profile.value('usr_id') == session.account.adminId) &&
          (session.account.adminUserName.isEmpty ||
              profile.value('usr_name') == session.account.adminUserName),
      'The server returned information for a different account. Please try again.',
    );
    ProfileRepository.checkAccess(profile, now());
    if (!ManagementAccess(profile).allows(ManagementDestination.accounts))
      throw const AccountsModuleUnavailable();
  }

  Future<List<JsonMap>> _get(
    AuthSession session,
    AccountProfile profile,
    String endpoint,
    AccountsRange range,
    bool Function() current,
  ) async {
    guard(session, profile, current);
    final data = await transport
        .get(
          apiEndpoint(
            session.center.baseUri,
            'acc_dashboard/$endpoint',
            range.query,
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
    guard(session, profile, current);
    final count = int.tryParse(nativeText(data['count']).trim());
    accountsRequire(
      count != null && count >= 0 && data.containsKey('items'),
      'The server returned incomplete Accounts Dashboard data.',
    );
    final rows = nativeItems(data);
    accountsRequire(
      rows.length == count,
      'The server returned incomplete Accounts Dashboard data.',
    );
    return rows;
  }

  Future<AccountsDashboardData> load(
    AuthSession session,
    AccountProfile profile,
    AccountsRange range, {
    required bool Function() isCurrent,
  }) async {
    final vouchers = await _get(
      session,
      profile,
      'getVoucherCount',
      range,
      isCurrent,
    );
    final slices = <AccountsVoucherSlice>[];
    for (var i = 0; i < vouchers.length; i++) {
      final label = nativeText(accountsField(vouchers[i], 'voucher_type'));
      final count = AccountsNumber(
        accountsField(vouchers[i], 'cc'),
        count: true,
        nonNegative: true,
      );
      if (label.isNotEmpty && !count.isZero)
        slices.add(AccountsVoucherSlice(label, count, i));
    }
    final amounts = await _get(
      session,
      profile,
      'getVoucherTotalAmnt',
      range,
      isCurrent,
    );
    var amount = AccountsNumber('0');
    for (final row in amounts) {
      amount = AccountsNumber(accountsField(row, 'amount'));
    }
    final balances = await _get(
      session,
      profile,
      'getIncomeExpense',
      range,
      isCurrent,
    );
    var income = AccountsNumber('0'), expense = AccountsNumber('0');
    for (final row in balances) {
      income = AccountsNumber(accountsField(row, 'income'), nonNegative: true);
      expense = AccountsNumber(
        accountsField(row, 'expense'),
        nonNegative: true,
      );
    }
    guard(session, profile, isCurrent);
    return AccountsDashboardData(
      vouchers: slices,
      amount: amount,
      income: income,
      expense: expense,
    );
  }
}

import '../../../core/failure.dart';
import '../../../core/native_json.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../../reports/report_manager_models.dart';
import '../accounts_dashboard_models.dart';
import '../accounts_dashboard_navigation.dart';
import '../voucher_transaction/voucher_models.dart';
import '../voucher_transaction/voucher_repository.dart';
import 'statement_models.dart';

class StatementRepository extends VoucherRepository {
  StatementRepository(super.transport, {super.now});
  Future<List<JsonMap>> _rows(
    AuthSession session,
    AccountProfile profile,
    String path,
    Map<String, String> query,
    bool Function() current,
  ) async {
    guard(session, profile, current);
    final data = await transport
        .get(apiEndpoint(session.center.baseUri, path, query))
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
      'The server returned incomplete statement data.',
    );
    final rows = nativeItems(data);
    accountsRequire(
      rows.length == count,
      'The server returned incomplete statement data.',
    );
    return rows;
  }

  Future<StatementData> statement(
    AuthSession session,
    AccountProfile profile,
    VoucherDates dates, {
    required bool Function() isCurrent,
  }) async {
    final chart = await _rows(
      session,
      profile,
      'acc_dashboard/getIncomeExpense',
      {'first_date': dates.first, 'end_date': dates.last},
      isCurrent,
    );
    var income = AccountsNumber('0'), expense = AccountsNumber('0');
    for (final row in chart) {
      income = AccountsNumber(accountsField(row, 'income'), nonNegative: true);
      expense = AccountsNumber(
        accountsField(row, 'expense'),
        nonNegative: true,
      );
    }
    final query = {'begin_date': dates.first, 'end_date': dates.last};
    final incomeRows = await _rows(
      session,
      profile,
      'acc_dashboard/getNIncomeStatement',
      query,
      isCurrent,
    );
    // Validate before continuing the native three-step chain.
    final incomeSection = StatementSection(
      incomeRows.map(StatementAccount.new).toList(),
    );
    final expenseRows = await _rows(
      session,
      profile,
      'acc_dashboard/getNExpenseStatement',
      query,
      isCurrent,
    );
    final expenseSection = StatementSection(
      expenseRows.map(StatementAccount.new).toList(),
    );
    guard(session, profile, isCurrent);
    return StatementData(dates, income, expense, incomeSection, expenseSection);
  }

  Future<ReportServerConfig> dailyConfig(
    AuthSession session,
    AccountProfile profile, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    accountsRequire(
      accountsDailyStatementAllowed(session.center.baseUri),
      'Daily Statement is not available for this centre.',
    );
    final rows = await _rows(
      session,
      profile,
      'report_manager/getUrlData',
      const {},
      isCurrent,
    );
    accountsRequire(
      rows.isNotEmpty,
      'The report server configuration is unavailable.',
    );
    final row = rows.last;
    for (final key in [
      'lic_rep_server_port',
      'lic_rep_path',
      'lic_rep_hrs_link',
      'cid_id',
    ]) {
      accountsField(row, key);
    }
    return ReportServerConfig.fromData(row);
  }
}

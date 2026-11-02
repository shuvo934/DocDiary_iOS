import '../dashboard/dashboard_navigation.dart';
import 'accounts_dashboard_models.dart';

enum AccountsDestination {
  creditApproval,
  debitApproval,
  journalApproval,
  voucherTransaction,
  incomeExpense,
  dailyStatement,
  accountLedger,
  patientLedger,
}

extension AccountsDestinationDetails on AccountsDestination {
  String get label =>
      const [
        'Credit Voucher Approval',
        'Debit Voucher Approval',
        'Journal Voucher Approval',
        'Voucher Transaction',
        'Income/Expense Statement',
        'Daily Statement',
        'Account Ledger',
        'Account Ledger (Patient)',
      ][index];
  String get artwork =>
      const [
        'credit_approved.png',
        'debit_voucher_approved.png',
        'journal_voucher_approved.png',
        'voucher_trans.png',
        'income_expense.png',
        'daily_statement.png',
        'account_ledger.png',
        'acc_ledger_ph.png',
      ][index];
  DashboardModule get module =>
      const [
        DashboardModule.accountsCreditApproval,
        DashboardModule.accountsDebitApproval,
        DashboardModule.accountsJournalApproval,
        DashboardModule.accountsVoucherTransaction,
        DashboardModule.accountsIncomeExpense,
        DashboardModule.accountsDailyStatement,
        DashboardModule.accountsLedger,
        DashboardModule.accountsPatientLedger,
      ][index];
  DashboardRoute route({AccountsRange? chartRange, required DateTime now}) {
    final dates = {
      'FIRST_DATE':
          chartRange == null ? '' : accountsRequestDate(chartRange.first),
      'LAST_DATE':
          chartRange == null ? '' : accountsRequestDate(chartRange.last),
    };
    return DashboardRoute(
      module,
      extras: switch (this) {
        AccountsDestination.voucherTransaction ||
        AccountsDestination.incomeExpense => dates,
        AccountsDestination.accountLedger ||
        AccountsDestination.patientLedger => {...dates, 'AD_ID': ''},
        AccountsDestination.dailyStatement => {
          'REPORT_NAME': 'DAILY_STATEMENT.rep',
          'FIRST_DATE': accountsRequestDate(now),
          'LAST_DATE': accountsRequestDate(now),
          'APP_BAR_NAME': 'Daily Statement',
        },
        _ => const {},
      },
    );
  }
}

bool accountsDailyStatementAllowed(Uri base) =>
    base.toString().contains('cstar') || base.toString().contains('btrf');
List<AccountsDestination> accountsDestinations(Uri base) => [
  for (final destination in AccountsDestination.values)
    if (destination != AccountsDestination.dailyStatement ||
        accountsDailyStatementAllowed(base))
      destination,
];

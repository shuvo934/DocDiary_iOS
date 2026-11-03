import '../../../core/native_json.dart';
import '../accounts_dashboard_models.dart';
import '../account_ledger/ledger_models.dart';
import '../voucher_transaction/voucher_models.dart';

enum StatementLevel {
  control('Level-01 (Control Head)'),
  subControl('Level-02 (Sub Control Head)'),
  details('Level-03 (Account Details)');

  const StatementLevel(this.label);
  final String label;
}

class StatementAmounts {
  const StatementAmounts(
    this.beforeDebit,
    this.beforeCredit,
    this.duringDebit,
    this.duringCredit,
  );
  static final zero = StatementAmounts(
    VtMoney.zero,
    VtMoney.zero,
    VtMoney.zero,
    VtMoney.zero,
  );
  final VtMoney beforeDebit, beforeCredit, duringDebit, duringCredit;
  VtMoney get before => beforeCredit - beforeDebit;
  VtMoney get during => duringCredit - duringDebit;
  VtMoney get balance => before + during;
  List<VtMoney> get columns => [
    beforeDebit,
    beforeCredit,
    duringDebit,
    duringCredit,
    balance,
  ];
  StatementAmounts operator +(StatementAmounts other) => StatementAmounts(
    beforeDebit + other.beforeDebit,
    beforeCredit + other.beforeCredit,
    duringDebit + other.duringDebit,
    duringCredit + other.duringCredit,
  );
}

class StatementAccount {
  StatementAccount(JsonMap row)
    : level1 = vtField(row, 'lvl1'),
      level2 = vtField(row, 'lvl2'),
      level3 = vtField(row, 'lvl3'),
      id = vtField(row, 'lg_ad_id'),
      headCode = vtField(row, 'ah_code'),
      controlCode = vtField(row, 'al1_code'),
      subControlCode = vtField(row, 'al2_code'),
      code = vtField(row, 'ad_code'),
      amounts = StatementAmounts(
        VtMoney.parse(accountsField(row, 'bfdr')),
        VtMoney.parse(accountsField(row, 'bfcr')),
        VtMoney.parse(accountsField(row, 'curdr')),
        VtMoney.parse(accountsField(row, 'curcr')),
      );
  final String level1,
      level2,
      level3,
      id,
      headCode,
      controlCode,
      subControlCode,
      code;
  final StatementAmounts amounts;
}

class StatementLine {
  StatementLine(List<StatementAccount> source)
    : accounts = List.unmodifiable(source),
      amounts = source.fold(
        StatementAmounts.zero,
        (sum, row) => sum + row.amounts,
      );
  final List<StatementAccount> accounts;
  final StatementAmounts amounts;
  StatementAccount get first => accounts.first;
}

class StatementSection {
  StatementSection(List<StatementAccount> rows)
    : rows = List.unmodifiable(rows),
      totals = rows.fold(
        StatementAmounts.zero,
        (sum, row) => sum + row.amounts,
      );
  final List<StatementAccount> rows;
  final StatementAmounts totals;
  List<StatementLine> lines(StatementLevel level) {
    if (level == StatementLevel.details) {
      return [
        for (final r in rows) StatementLine([r]),
      ];
    }
    // Native merges adjacent rows by al1_code / al2_code, retaining server order.
    final groups = <List<StatementAccount>>[];
    for (final row in rows) {
      final prior = groups.isEmpty ? null : groups.last.last;
      final same =
          prior != null &&
          prior.controlCode == row.controlCode &&
          (level == StatementLevel.control ||
              prior.subControlCode == row.subControlCode);
      if (same) {
        groups.last.add(row);
      } else {
        groups.add([row]);
      }
    }
    return groups.map(StatementLine.new).toList(growable: false);
  }
}

class StatementData {
  const StatementData(
    this.dates,
    this.chartIncome,
    this.chartExpense,
    this.income,
    this.expense,
  );
  final VoucherDates dates;
  final AccountsNumber chartIncome, chartExpense;
  final StatementSection income, expense;
  VtMoney get chartNet =>
      VtMoney.parse(chartIncome.text) - VtMoney.parse(chartExpense.text);
  StatementAmounts get profit => income.totals + expense.totals;
  String get amountLabel =>
      'Amount : ${statementAmount(chartNet, absolute: true)} '
      '(${chartNet.isZero
          ? 'Break Even Point'
          : chartNet.units.isNegative
          ? 'Net Loss'
          : 'Net Profit'})';
}

String statementAmount(
  VtMoney value, {
  bool absolute = false,
  bool blankZero = false,
}) {
  final text = ledgerAmount(
    absolute && value.units.isNegative ? VtMoney.zero - value : value,
    parentheses: false,
  );
  return blankZero && text == '0' ? '' : text;
}

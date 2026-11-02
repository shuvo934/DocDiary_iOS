import '../../core/failure.dart';
import '../../core/native_dates.dart';
import '../../core/native_json.dart';
import '../dashboard/admin_chart_models.dart';

enum AccountsPeriod { today, currentWeek, currentMonth, lastMonth }

extension AccountsPeriodLabel on AccountsPeriod {
  String get label =>
      const ['TODAY', 'CURRENT\nWEEK', 'CURRENT\nMONTH', 'LAST MONTH'][index];
}

String accountsRequestDate(DateTime date) => oracleDate(date).replaceAllMapped(
  RegExp(r'-([A-Z]{3})-'),
  (m) => '-${m[1]![0]}${m[1]!.substring(1).toLowerCase()}-',
);
String accountsFullDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} '
    '${chartMonths[date.month - 1]}, ${(date.year % 100).toString().padLeft(2, '0')}';

class AccountsRange {
  const AccountsRange(this.first, this.last);
  final DateTime first, last;
  factory AccountsRange.forPeriod(AccountsPeriod period, DateTime anchor) {
    final day = dateOnly(anchor),
        week = SummaryRange.forPeriod(SummaryPeriod.currentWeek, anchor);
    return switch (period) {
      AccountsPeriod.today => AccountsRange(day, day),
      AccountsPeriod.currentWeek => AccountsRange(week.first, week.last),
      AccountsPeriod.currentMonth => AccountsRange(
        DateTime(day.year, day.month),
        DateTime(day.year, day.month + 1, 0),
      ),
      AccountsPeriod.lastMonth => AccountsRange(
        DateTime(day.year, day.month - 1),
        DateTime(day.year, day.month, 0),
      ),
    };
  }
  Map<String, String> get query => {
    'first_date': accountsRequestDate(first),
    'end_date': accountsRequestDate(last),
  };
  String get label =>
      first == last
          ? accountsFullDate(first)
          : '${accountsFullDate(first)}  --  ${accountsFullDate(last)}';
}

void accountsRequire(bool valid, String message) {
  if (!valid) throw AppFailure(message, kind: FailureKind.invalidData);
}

Object? accountsField(JsonMap row, String key) {
  accountsRequire(
    row.containsKey(key) && row[key] is! List && row[key] is! Map,
    'The server returned incomplete Accounts Dashboard data.',
  );
  return row[key];
}

/// Keep exact amounts in text/totals; floating-point values only set chart angles.
class AccountsNumber {
  AccountsNumber(Object? raw, {bool count = false, bool nonNegative = false})
    : number = AdminChartNumber.parse(raw) {
    accountsRequire(
      !nonNegative || !number.units.isNegative,
      'The server returned an invalid Accounts Dashboard value.',
    );
    accountsRequire(
      !count || number.isWhole,
      'The server returned an invalid voucher count.',
    );
  }
  final AdminChartNumber number;
  bool get isZero => number.units == BigInt.zero;
  bool get negative => number.units.isNegative;
  double get plot => number.plot;
  BigInt get whole => number.units ~/ BigInt.from(10).pow(number.scale);
  String get text => _text(number.units);
  String get absoluteText => _text(number.units.abs());
  String _text(BigInt value) {
    final sign = value.isNegative ? '-' : '', digits = value.abs().toString();
    if (number.scale == 0) return '$sign$digits';
    final padded = digits.padLeft(number.scale + 1, '0'),
        cut = padded.length - number.scale;
    final fraction = padded.substring(cut).replaceFirst(RegExp(r'0+$'), '');
    return '$sign${padded.substring(0, cut)}${fraction.isEmpty ? '' : '.$fraction'}';
  }
}

class AccountsVoucherSlice {
  const AccountsVoucherSlice(this.label, this.count, this.colorIndex);
  final String label;
  final AccountsNumber count;
  final int colorIndex;
}

class AccountsDashboardData {
  AccountsDashboardData({
    required List<AccountsVoucherSlice> vouchers,
    required this.amount,
    required this.income,
    required this.expense,
  }) : vouchers = List.unmodifiable(vouchers);
  final List<AccountsVoucherSlice> vouchers;
  final AccountsNumber amount, income, expense;
  BigInt get voucherCount =>
      vouchers.fold(BigInt.zero, (sum, row) => sum + row.count.whole);
  String get amountLabel =>
      '${amount.absoluteText} (${amount.negative
          ? 'Net Loss'
          : amount.isZero
          ? 'Break Even Point'
          : 'Net Profit'})';
}

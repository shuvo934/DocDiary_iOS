import '../../../core/native_dates.dart';
import '../../../core/native_json.dart';
import '../accounts_dashboard_models.dart';
import '../voucher_transaction/voucher_models.dart';

class LedgerAccount {
  LedgerAccount(JsonMap row)
    : id = vtField(row, 'lg_ad_id'),
      name = vtField(row, 'ad_name'),
      code = vtField(row, 'ad_code'),
      category = vtField(row, 'al2_name'),
      group = vtField(row, 'al1_name'),
      headName = vtField(row, 'ah_name'),
      headCode = vtField(row, 'ah_code') {
    accountsRequire(
      id.isNotEmpty && name.isNotEmpty,
      'The server returned an incomplete account.',
    );
  }
  final String id, name, code, category, group, headName, headCode;
}

class LedgerPatient {
  LedgerPatient(JsonMap row)
    : id = vtField(row, 'ph_id'),
      prescriptionCode = vtField(row, 'ph_sub_code'),
      name = vtField(row, 'pat_name'),
      code = vtField(row, 'pat_code'),
      date = vtField(row, 'pat_date') {
    accountsRequire(
      id.isNotEmpty && prescriptionCode.isNotEmpty && name.isNotEmpty,
      'The server returned an incomplete patient.',
    );
  }
  final String id, prescriptionCode, name, code, date;
}

String? validateLedgerPatientQuery(String value) {
  if (value.trim().isEmpty) return 'Please Provide Patient Name or Code';
  if (value.length < 3) return 'Name or Code must be greater than 2 character';
  if (RegExp(r'[.,-]').hasMatch(value)) {
    return "Name or Code must not contain '.,-' character";
  }
  return null;
}

VoucherDates initialLedgerDates(String first, String last, DateTime now) =>
    VoucherDates.initial(
      first.isEmpty
          ? oracleDate(DateTime(now.year, now.month)).replaceAllMapped(
            RegExp(r'-([A-Z]{3})-'),
            (m) => '-${m[1]![0]}${m[1]!.substring(1).toLowerCase()}-',
          )
          : first,
      last,
      now,
    );

VtMoney ledgerOpeningBalance(VtMoney debit, VtMoney credit, String headCode) =>
    switch (headCode) {
      '01' || '04' => debit - credit,
      '02' || '03' || '05' => credit - debit,
      _ => VtMoney.zero,
    };

/// Native DecimalFormat("###,##,##,###.#"): one decimal, half-even, lakh groups.
/// All calculations and the server's carried balance retain full precision.
String ledgerAmount(VtMoney amount, {bool parentheses = true}) {
  var tenths = amount.units.abs();
  if (amount.scale > 1) {
    final divisor = BigInt.from(10).pow(amount.scale - 1);
    final remainder = tenths.remainder(divisor);
    tenths ~/= divisor;
    final twice = remainder * BigInt.two;
    if (twice > divisor || twice == divisor && tenths.isOdd) {
      tenths += BigInt.one;
    }
  } else {
    tenths *= BigInt.from(10).pow(1 - amount.scale);
  }
  final digits = (tenths ~/ BigInt.from(10)).toString();
  var head = digits.length > 3 ? digits.substring(0, digits.length - 3) : '';
  var grouped =
      digits.length > 3 ? digits.substring(digits.length - 3) : digits;
  while (head.isNotEmpty) {
    final cut = head.length > 2 ? head.length - 2 : 0;
    grouped = '${head.substring(cut)},$grouped';
    head = head.substring(0, cut);
  }
  final fraction = (tenths % BigInt.from(10)).toInt();
  final sign =
      amount.units.isNegative && tenths != BigInt.zero
          ? parentheses
              ? '(-)  '
              : '-'
          : '';
  return '$sign$grouped${fraction == 0 ? '' : '.$fraction'}';
}

class LedgerRow {
  LedgerRow(JsonMap row)
    : id = vtField(row, 'lg_id'),
      date = vtField(row, 'lg_voucher_date'),
      number = vtField(row, 'lg_voucher_no'),
      particulars = vtField(row, 'lg_particulars'),
      debit = VtMoney.parse(accountsField(row, 'lg_dr_amt')),
      credit = VtMoney.parse(accountsField(row, 'lg_cr_amt')),
      openingDebit = VtMoney.parse(accountsField(row, 'opening_dr')),
      openingCredit = VtMoney.parse(accountsField(row, 'opening_cr')),
      headCode = vtField(row, 'ah_code'),
      transactionType = vtField(row, 'lg_trans_type'),
      orderNo = vtField(row, 'lg_inv_pur_no'),
      payFlag = vtField(row, 'prm_pay_type_flag') {
    accountsField(row, 'dr_null');
    accountsField(row, 'cr_null');
    accountsRequire(
      id.isNotEmpty && id != '0' && number.isNotEmpty && date.isNotEmpty,
      'The server returned an incomplete ledger row.',
    );
    parseOracleDate(date);
  }
  final String id,
      date,
      number,
      particulars,
      headCode,
      transactionType,
      orderNo,
      payFlag;
  final VtMoney debit, credit, openingDebit, openingCredit;
  bool get opensInvoice =>
      transactionType == 'PRM' && payFlag == '1' && orderNo.isNotEmpty;
  bool get opensReport => transactionType == 'AV' && orderNo.isNotEmpty;
  bool get actionable => opensInvoice || opensReport;
}

class LedgerEntry {
  const LedgerEntry(this.row, this.balance);
  final LedgerRow row;
  final VtMoney balance;
}

class LedgerData {
  LedgerData(
    this.dates,
    this.openingDebit,
    this.openingCredit,
    List<LedgerEntry> entries,
    this.closingBalance,
  ) : entries = List.unmodifiable(entries);
  final VoucherDates dates;
  final VtMoney openingDebit, openingCredit, closingBalance;
  final List<LedgerEntry> entries;
  VtMoney get debit =>
      entries.fold(openingDebit, (sum, e) => sum + e.row.debit);
  VtMoney get credit =>
      entries.fold(openingCredit, (sum, e) => sum + e.row.credit);
}

class LedgerPatientPickerData {
  const LedgerPatientPickerData({
    this.busy = false,
    this.searched = false,
    this.rows = const [],
    this.error,
  });
  final bool busy, searched;
  final List<LedgerPatient> rows;
  final String? error;
}

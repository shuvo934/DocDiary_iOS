import 'dart:math' as math;
import '../../../core/native_dates.dart';
import '../../../core/native_json.dart';
import '../accounts_dashboard_models.dart';

String vtField(JsonMap row, String key, [String fallback = '']) =>
    nativeText(accountsField(row, key), fallback);

/// Exact base-ten arithmetic for ledger totals and invoice percentages.
class VtMoney implements Comparable<VtMoney> {
  VtMoney._(this.units, this.scale);
  factory VtMoney.parse(Object? raw) {
    final value = AccountsNumber(raw).number;
    return VtMoney._(value.units, value.scale);
  }
  static final zero = VtMoney._(BigInt.zero, 0);
  final BigInt units;
  final int scale;
  bool get isZero => units == BigInt.zero;
  VtMoney operator +(VtMoney other) {
    final exponent = math.max(scale, other.scale);
    return VtMoney._(
      units * BigInt.from(10).pow(exponent - scale) +
          other.units * BigInt.from(10).pow(exponent - other.scale),
      exponent,
    );
  }

  VtMoney operator -(VtMoney other) =>
      this + VtMoney._(-other.units, other.scale);
  VtMoney percent(VtMoney pct) =>
      VtMoney._(units * pct.units, scale + pct.scale + 2);
  @override
  int compareTo(VtMoney other) => (this - other).units.sign;
  String get text {
    final sign = units.isNegative ? '-' : '', raw = units.abs().toString();
    if (scale == 0) return '$sign$raw';
    final digits = raw.padLeft(scale + 1, '0'), cut = digits.length - scale;
    final fraction = digits.substring(cut).replaceFirst(RegExp(r'0+$'), '');
    return '$sign${digits.substring(0, cut)}${fraction.isEmpty ? '' : '.$fraction'}';
  }

  String get grouped {
    final parts = text.split('.');
    return parts.first.replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        ) +
        (parts.length == 1 ? '' : '.${parts[1]}');
  }

  String get currency => '৳ $grouped';
}

class VoucherDates {
  VoucherDates(this.first, this.last) {
    accountsRequire(
      !parseOracleDate(first).isAfter(parseOracleDate(last)),
      'Date Range is Invalid',
    );
  }
  factory VoucherDates.initial(String first, String last, DateTime now) =>
      VoucherDates(
        first.isEmpty ? _initialDate(now) : first,
        last.isEmpty ? _initialDate(now) : last,
      );
  final String first, last;
  static String _initialDate(DateTime now) => oracleDate(now).replaceAllMapped(
    RegExp(r'-([A-Z]{3})-'),
    (m) => '-${m[1]![0]}${m[1]!.substring(1).toLowerCase()}-',
  );
  String get label => 'Voucher Transaction List ($first to $last)';
  DateTime get firstDay => parseOracleDate(first);
  DateTime get lastDay => parseOracleDate(last);
  static DateTime earliest(DateTime now) => DateTime(now.year, now.month - 2);
}

class VoucherLine {
  VoucherLine(this.account, this.debitText, this.creditText)
    : debit = VtMoney.parse(debitText),
      credit = VtMoney.parse(creditText);
  final String account, debitText, creditText;
  final VtMoney debit, credit;
  bool get isDebit => debitText.isNotEmpty && creditText.isEmpty;
  bool get isCredit => creditText.isNotEmpty && debitText.isEmpty;
}

class VoucherEntry {
  VoucherEntry({
    required this.date,
    required this.number,
    required this.particulars,
    required this.orderNo,
    required this.transactionType,
    required this.payFlag,
    required this.voucherType,
    required List<VoucherLine> lines,
  }) : lines = List.unmodifiable(lines);
  final String date,
      number,
      particulars,
      orderNo,
      transactionType,
      payFlag,
      voucherType;
  final List<VoucherLine> lines;
  bool get opensInvoice =>
      transactionType == 'PRM' && payFlag == '1' && orderNo.isNotEmpty;
  bool get opensReport => transactionType == 'AV' && orderNo.isNotEmpty;
  bool get actionable => opensInvoice || opensReport;
}

class VoucherDay {
  VoucherDay(this.date, List<VoucherEntry> entries)
    : entries = List.unmodifiable(entries);
  final String date;
  final List<VoucherEntry> entries;
}

class VoucherData {
  VoucherData(
    this.dates,
    List<AccountsVoucherSlice> counts,
    List<VoucherDay> days,
  ) : counts = List.unmodifiable(counts),
      days = List.unmodifiable(days);
  final VoucherDates dates;
  final List<AccountsVoucherSlice> counts;
  final List<VoucherDay> days;
  List<String> get typeOptions =>
      counts.isEmpty ? const [] : ['...', ...counts.map((c) => c.label)];
  VoucherData filtered(String label) {
    if (label.isEmpty || label == '...') return this;
    final code = label.length < 2 ? label : label.substring(0, 2);
    return VoucherData(dates, counts.where((c) => c.label == label).toList(), [
      for (final day in days)
        if (day.entries.any(
          (e) => e.voucherType.toUpperCase() == code.toUpperCase(),
        ))
          VoucherDay(
            day.date,
            day.entries
                .where((e) => e.voucherType.toUpperCase() == code.toUpperCase())
                .toList(),
          ),
    ]);
  }

  BigInt get totalCount =>
      counts.fold(BigInt.zero, (sum, c) => sum + c.count.whole);
  Iterable<VoucherLine> get lines sync* {
    for (final day in days) {
      for (final entry in day.entries) {
        yield* entry.lines;
      }
    }
  }

  VtMoney get debit =>
      lines.fold(VtMoney.zero, (sum, line) => sum + line.debit);
  VtMoney get credit =>
      lines.fold(VtMoney.zero, (sum, line) => sum + line.credit);
}

List<VoucherDay> groupVoucherRows(List<JsonMap> rows) {
  final groups = <String, Map<String, List<JsonMap>>>{};
  for (final row in rows) {
    final date = vtField(row, 'vdate'), number = vtField(row, 'lg_voucher_no');
    accountsRequire(
      date.isNotEmpty && number.isNotEmpty,
      'The server returned an incomplete voucher transaction.',
    );
    parseOracleDate(date);
    (groups.putIfAbsent(date, () => {})[number] ??= []).add(row);
  }
  return [
    for (final day in groups.entries)
      VoucherDay(day.key, [
        for (final group in day.value.entries)
          _entry(day.key, group.key, group.value),
      ]),
  ];
}

VoucherEntry _entry(String date, String number, List<JsonMap> rows) {
  final debits = <(int, VoucherLine)>[], credits = <(int, VoucherLine)>[];
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    final line = VoucherLine(
      vtField(row, 'ad_dtl'),
      vtField(row, 'lg_dr_amt').trim(),
      vtField(row, 'lg_cr_amt').trim(),
    );
    if (line.isDebit) debits.add((index, line));
    if (line.isCredit) credits.add((index, line));
  }
  // Dart sort is not stable; the source ordinal explicitly breaks equal-value ties.
  debits.sort((a, b) {
    final c = b.$2.debit.compareTo(a.$2.debit);
    return c == 0 ? a.$1.compareTo(b.$1) : c;
  });
  credits.sort((a, b) {
    final c = b.$2.credit.compareTo(a.$2.credit);
    return c == 0 ? a.$1.compareTo(b.$1) : c;
  });
  final first = rows.first;
  return VoucherEntry(
    date: date,
    number: number,
    particulars: vtField(first, 'lg_particulars'),
    orderNo: vtField(first, 'lg_inv_pur_no'),
    transactionType: vtField(first, 'lg_trans_type'),
    payFlag: vtField(first, 'prm_pay_type_flag'),
    voucherType: vtField(first, 'lg_voucher_type'),
    lines: [...debits, ...credits].map((e) => e.$2).toList(),
  );
}

class VoucherReportLine {
  VoucherReportLine(JsonMap row)
    : accountCode = vtField(row, 'ad_code'),
      accountName = vtField(row, 'ad_name'),
      debitText = vtField(row, 'vd_dr_amt'),
      creditText = vtField(row, 'vd_cr_amt'),
      debit = VtMoney.parse(accountsField(row, 'vd_dr_amt')),
      credit = VtMoney.parse(accountsField(row, 'vd_cr_amt'));
  final String accountCode, accountName, debitText, creditText;
  final VtMoney debit, credit;
}

class VoucherReport {
  VoucherReport(this.number, List<JsonMap> rows)
    : rows = List.unmodifiable(rows),
      lines = List.unmodifiable(rows.map(VoucherReportLine.new));
  final String number;
  final List<JsonMap> rows;
  final List<VoucherReportLine> lines;
  bool get empty => rows.isEmpty;
  String get title =>
      number.contains('DV')
          ? 'Debit Voucher'
          : number.contains('CV')
          ? 'Credit Voucher'
          : number.contains('JV')
          ? 'Journal Voucher'
          : 'Voucher';
  String field(String key) => rows.isEmpty ? '' : vtField(rows.first, key);
  String get date => field('vm_date');
  String get reference => field('vm_bill_ref_no');
  String get referenceDate => field('vm_bill_ref_date');
  String get narration => field('vm_naration');
  VtMoney get debit => lines.fold(VtMoney.zero, (sum, l) => sum + l.debit);
  VtMoney get credit => lines.fold(VtMoney.zero, (sum, l) => sum + l.credit);
}

class InvoiceLine {
  InvoiceLine(JsonMap row)
    : service = vtField(row, 'pfn_fee_name'),
      unit = vtField(row, 'depts_name'),
      month = vtField(row, 'prd_payment_for_month'),
      rate = VtMoney.parse(accountsField(row, 'prd_rate')),
      quantity = VtMoney.parse(accountsField(row, 'prd_qty')),
      amount = VtMoney.parse(accountsField(row, 'amt')),
      discount = VtMoney.parse(accountsField(row, 'prd_discount_amt')),
      chargePercent = VtMoney.parse(
        accountsField(row, 'prd_service_charge_pct'),
      ) {
    // prm_amt is returned by native ORDS but totals use amt/discount/percentage.
    VtMoney.parse(accountsField(row, 'prm_amt'));
  }
  final String service, unit, month;
  final VtMoney rate, quantity, amount, discount, chargePercent;
  String get rateLabel => rate.isZero ? 'Free of Cost' : rate.text;
  String get amountLabel => amount.isZero ? 'Free of Cost' : amount.text;
  VtMoney get charge => (amount - discount).percent(chargePercent);
}

class PaymentInvoiceData {
  PaymentInvoiceData(this.code, List<JsonMap> rows)
    : metadata = Map.unmodifiable(rows.last),
      lines = List.unmodifiable(rows.map(InvoiceLine.new));
  final String code;
  final JsonMap metadata;
  final List<InvoiceLine> lines;
  String field(String key) => vtField(metadata, key, 'N/A');
  VtMoney get subTotal => lines.fold(VtMoney.zero, (sum, l) => sum + l.amount);
  VtMoney get discount =>
      lines.fold(VtMoney.zero, (sum, l) => sum + l.discount);
  VtMoney get charge => lines.fold(VtMoney.zero, (sum, l) => sum + l.charge);
  VtMoney get grandTotal => subTotal - discount + charge;
}

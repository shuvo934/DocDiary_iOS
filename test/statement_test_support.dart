import 'dart:convert';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/accounts/statements/statement_repository.dart';
import 'ledger_test_support.dart';

JsonMap statementAccount(
  String id,
  String control,
  String sub,
  String name, {
  String? controlName,
  String? subName,
  String beforeDebit = '0',
  String beforeCredit = '0',
  String duringDebit = '0',
  String duringCredit = '0',
  bool expense = false,
}) => {
  'lvl1': controlName ?? 'Example $control',
  'lvl2': subName ?? 'Example $sub',
  'lvl3': name,
  'bfdr': beforeDebit,
  'bfcr': beforeCredit,
  'curdr': duringDebit,
  'curcr': duringCredit,
  'lg_ad_id': id,
  'ah_code': expense ? '04' : '03',
  'al1_code': control,
  'al2_code': sub,
  'ad_code': '$control.$sub.$id',
};

class StatementHarness extends LedgerHarness {
  StatementHarness({bool special = true}) {
    now = DateTime(2026, 11, 3, 16, 43);
    if (special) {
      loginResponse['p_center_api'] = 'https://centre.example/ords/cstar/';
    }
    incomeRows = [
      {'income': '42300', 'expense': '1860'},
    ];
    transport.onGet = respondStatement;
  }
  StatementRepository get statements =>
      StatementRepository(transport, now: () => now);
  Future<JsonMap?> Function(Uri)? onStatementGet;
  List<JsonMap> statementIncome = [
    statementAccount(
      'bank',
      'sales',
      'service',
      'Example Sales Revenue',
      controlName: 'Example Sales Revenue',
      subName: 'Therapy Services',
      beforeDebit: '343350',
      beforeCredit: '28941870',
      duringCredit: '42300',
    ),
    statementAccount(
      'cash',
      'sales',
      'admission',
      'Example Admission Fee',
      controlName: 'Example Sales Revenue',
      subName: 'Admission Fee',
      beforeCredit: '30000',
    ),
  ];
  List<JsonMap> statementExpense = [
    statementAccount(
      'bank',
      'admin',
      'office',
      'Example Entertainment',
      controlName: 'Administrative Expenses',
      subName: 'Office Expenses',
      beforeDebit: '212566',
      beforeCredit: '1850',
      duringDebit: '1860',
      expense: true,
    ),
    statementAccount(
      'cash',
      'admin',
      'office',
      'Example Travel',
      controlName: 'Administrative Expenses',
      subName: 'Office Expenses',
      beforeDebit: '166855',
      expense: true,
    ),
    statementAccount(
      'bank',
      'admin',
      'salary',
      'Example Salary',
      controlName: 'Administrative Expenses',
      subName: 'Salary Expenses',
      beforeDebit: '23838152',
      expense: true,
    ),
    statementAccount(
      'cash',
      'goods',
      'purchase',
      'Example Purchase Toys',
      controlName: 'Cost of Goods Sold',
      subName: 'Purchase',
      beforeDebit: '50080',
      expense: true,
    ),
    statementAccount(
      'bank',
      'goods',
      'purchase',
      'Example Electronic Device',
      controlName: 'Cost of Goods Sold',
      subName: 'Purchase',
      beforeDebit: '175560',
      expense: true,
    ),
    statementAccount(
      'cash',
      'goods',
      'equipment',
      'Example Office Equipment',
      controlName: 'Cost of Goods Sold',
      subName: 'Office Equipment',
      beforeDebit: '305018',
      expense: true,
    ),
    statementAccount(
      'bank',
      'other',
      'other',
      'Example Other Expenses',
      controlName: 'Other Expenses',
      subName: 'Others',
      beforeDebit: '21320',
      expense: true,
    ),
    statementAccount(
      'cash',
      'operating',
      'rent',
      'Example Office Rent',
      controlName: 'Operating Expenses',
      subName: 'Operating Expenses',
      beforeDebit: '3320405',
      expense: true,
    ),
  ];
  List<JsonMap> configRows = [
    {
      'lic_rep_server_port': 'report.example:8889',
      'lic_rep_path': r'C:\reports\',
      'lic_rep_hrs_link': 'report_key',
      'cid_id': '7',
    },
  ];
  Future<JsonMap> respondStatement(Uri uri) async {
    final custom = await onStatementGet?.call(uri);
    if (custom != null) return custom;
    switch (uri.pathSegments.last) {
      case 'getNIncomeStatement':
        return page(statementIncome);
      case 'getNExpenseStatement':
        return page(statementExpense);
      case 'getUrlData':
        return page(configRows);
      case 'getAccLedger':
        final rows = [
          for (final r in bankRows)
            {...r, 'lg_voucher_date': uri.queryParameters['st_date']},
        ];
        return page([
          {'acc_ledger': nestedEncoded ? jsonEncode(rows) : rows},
        ]);
      default:
        return respondLedger(uri);
    }
  }
}

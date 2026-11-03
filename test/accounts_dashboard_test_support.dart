import 'dart:convert';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/accounts/accounts_dashboard_repository.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'hr_dashboard_test_support.dart';
import 'support.dart';

class AccountsHarness extends HrHarness {
  AccountsHarness({DateTime? clock})
    : super(clock: clock ?? DateTime(2026, 11, 2, 15, 19)) {
    transport.onGet = respondAccounts;
  }
  AccountsDashboardRepository get accounts =>
      AccountsDashboardRepository(transport, now: () => now);
  AccountProfile get profile => AccountProfile(AccountRole.admin, adminData);
  List<JsonMap> voucherRows = [
    {'voucher_type': 'CV (Receive)', 'cc': '4'},
    {'voucher_type': 'JV (Transfer)', 'cc': '4'},
  ];
  List<JsonMap> amountRows = [
    {'amount': '10200'},
  ];
  List<JsonMap> incomeRows = [
    {'income': '10200', 'expense': '0'},
  ];
  bool encoded = false;
  Future<JsonMap?> Function(Uri)? onAccountsGet;
  Future<JsonMap> respondAccounts(Uri uri) async {
    if (!uri.path.contains('/acc_dashboard/')) return respond(uri);
    final override = await onAccountsGet?.call(uri);
    if (override != null) return override;
    final rows = switch (uri.pathSegments.last) {
      'getVoucherCount' => voucherRows,
      'getVoucherTotalAmnt' => amountRows,
      'getIncomeExpense' => incomeRows,
      'getNIncomeStatement' || 'getNExpenseStatement' => <JsonMap>[],
      _ => throw StateError('Unexpected synthetic Accounts API: $uri'),
    };
    return {'count': rows.length, 'items': encoded ? jsonEncode(rows) : rows};
  }

  List<RequestRecord> get accountReads =>
      transport.requests
          .where((r) => r.uri.path.contains('/acc_dashboard/'))
          .toList();
}

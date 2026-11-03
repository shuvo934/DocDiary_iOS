import '../../../core/failure.dart';
import '../../../core/native_json.dart';
import '../../../core/native_dates.dart';
import '../../../core/transport.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../accounts_dashboard_models.dart';
import '../accounts_dashboard_repository.dart';
import 'voucher_models.dart';

class VoucherRepository {
  VoucherRepository(this.transport, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final Transport transport;
  final DateTime Function() now;
  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() current,
  ) => AccountsDashboardRepository(
    transport,
    now: now,
  ).guard(session, profile, current);
  Future<List<JsonMap>> _get(
    AuthSession session,
    AccountProfile profile,
    String endpoint,
    Map<String, String> query,
    bool Function() current,
  ) async {
    guard(session, profile, current);
    final response = await transport
        .get(
          apiEndpoint(session.center.baseUri, 'acc_dashboard/$endpoint', query),
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
    final count = int.tryParse(nativeText(response['count']).trim());
    accountsRequire(
      count != null && count >= 0 && response.containsKey('items'),
      'The server returned incomplete voucher data.',
    );
    final rows = nativeItems(response);
    accountsRequire(
      rows.length == count,
      'The server returned incomplete voucher data.',
    );
    return rows;
  }

  Future<VoucherData> load(
    AuthSession session,
    AccountProfile profile,
    VoucherDates dates, {
    required bool Function() isCurrent,
  }) async {
    final countRows = await _get(session, profile, 'getVoucherCount', {
      'first_date': dates.first,
      'end_date': dates.last,
    }, isCurrent);
    final counts = <AccountsVoucherSlice>[];
    for (var index = 0; index < countRows.length; index++) {
      final row = countRows[index], name = vtField(row, 'voucher_type');
      final value = AccountsNumber(
        accountsField(row, 'cc'),
        count: true,
        nonNegative: true,
      );
      if (name.isNotEmpty) counts.add(AccountsVoucherSlice(name, value, index));
    }
    final rows = await _get(session, profile, 'getNewVoucherList', {
      'st_date': dates.first,
      'end_date': dates.last,
    }, isCurrent);
    for (final row in rows) {
      for (final key in [
        'vdate',
        'lg_voucher_no',
        'lg_particulars',
        'lg_inv_pur_no',
        'lg_trans_type',
        'prm_pay_type_flag',
        'ad_dtl',
        'lg_dr_amt',
        'lg_cr_amt',
        'lg_voucher_type',
      ]) {
        accountsField(row, key);
      }
    }
    final days = groupVoucherRows(rows);
    for (final day in days) {
      final date = parseOracleDate(day.date);
      accountsRequire(
        !date.isBefore(dates.firstDay) && !date.isAfter(dates.lastDay),
        'The server returned voucher data outside the selected date range.',
      );
    }
    guard(session, profile, isCurrent);
    return VoucherData(dates, counts, days);
  }

  Future<VoucherReport> report(
    AuthSession session,
    AccountProfile profile,
    String number, {
    required bool Function() isCurrent,
  }) async {
    accountsRequire(number.trim().isNotEmpty, 'The voucher number is missing.');
    final rows = await _get(session, profile, 'getVoucherReport', {
      'p_vm_no': number,
    }, isCurrent);
    for (final row in rows) {
      for (final key in [
        'vm_date',
        'vm_type',
        'vm_bill_ref_no',
        'vm_bill_ref_date',
        'vm_naration',
        'ad_code',
        'ad_name',
        'vd_dr_amt',
        'vd_cr_amt',
      ]) {
        accountsField(row, key);
      }
      for (final key in ['vm_no', 'vm_code']) {
        if (row.containsKey(key)) {
          accountsRequire(
            nativeText(row[key]).isEmpty || nativeText(row[key]) == number,
            'The server returned a different voucher.',
          );
        }
      }
    }
    final report = VoucherReport(number, rows);
    guard(session, profile, isCurrent);
    return report;
  }

  Future<PaymentInvoiceData> invoice(
    AuthSession session,
    AccountProfile profile,
    String code, {
    required bool Function() isCurrent,
  }) async {
    accountsRequire(code.trim().isNotEmpty, 'The payment code is missing.');
    final rows = await _get(session, profile, 'getPaymentInvoice', {
      'p_prm_code': code,
    }, isCurrent);
    accountsRequire(rows.isNotEmpty, 'No data found');
    for (final row in rows) {
      accountsRequire(
        vtField(row, 'prm_code') == code,
        'The server returned a different payment invoice.',
      );
      for (final key in [
        'prm_date',
        'pat_name',
        'pat_code',
        'ph_sub_code',
        'p_age',
        'gender',
        'marital_status',
        'ph_patient_cat',
        'address',
        'pat_phone',
      ]) {
        accountsField(row, key);
      }
    }
    final invoice = PaymentInvoiceData(code, rows);
    guard(session, profile, isCurrent);
    return invoice;
  }
}

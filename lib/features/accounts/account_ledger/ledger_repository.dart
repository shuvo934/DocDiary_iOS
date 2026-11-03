import '../../../core/failure.dart';
import '../../../core/native_dates.dart';
import '../../../core/native_json.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../accounts_dashboard_models.dart';
import '../voucher_transaction/voucher_models.dart';
import '../voucher_transaction/voucher_repository.dart';
import 'ledger_models.dart';

class LedgerRepository extends VoucherRepository {
  LedgerRepository(super.transport, {super.now});

  List<JsonMap> _nestedList(Object? value) {
    accountsRequire(
      value is List<Object?> || value is String && value.trim().startsWith('['),
      'The server returned an incomplete ledger or patient list.',
    );
    return nativeArray(value);
  }

  Future<JsonMap> _get(
    AuthSession session,
    AccountProfile profile,
    String path,
    Map<String, String> query,
    bool Function() current,
  ) async {
    guard(session, profile, current);
    final response = await transport
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
    return response;
  }

  Future<List<JsonMap>> _rows(
    AuthSession session,
    AccountProfile profile,
    String endpoint,
    Map<String, String> query,
    bool Function() current,
  ) async {
    final response = await _get(
      session,
      profile,
      'acc_dashboard/$endpoint',
      query,
      current,
    );
    final count = int.tryParse(nativeText(response['count']).trim());
    accountsRequire(
      count != null && count >= 0 && response.containsKey('items'),
      'The server returned incomplete ledger data.',
    );
    final rows = nativeItems(response);
    accountsRequire(
      rows.length == count,
      'The server returned incomplete ledger data.',
    );
    return rows;
  }

  Future<List<LedgerAccount>> accounts(
    AuthSession session,
    AccountProfile profile, {
    required bool Function() isCurrent,
  }) async {
    final rows = await _rows(
      session,
      profile,
      'getAccountList',
      const {},
      isCurrent,
    );
    final accounts = rows.map(LedgerAccount.new).toList();
    accountsRequire(
      accounts.map((a) => a.id).toSet().length == accounts.length,
      'The server returned duplicate accounts.',
    );
    return List.unmodifiable(accounts);
  }

  Future<List<LedgerPatient>> patients(
    AuthSession session,
    AccountProfile profile, {
    String? query,
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    if (query != null) {
      final validation = validateLedgerPatientQuery(query);
      accountsRequire(validation == null, validation ?? 'Invalid search.');
    }
    final response = await _get(
      session,
      profile,
      query == null
          ? 'payement_receive/getFiftyPrescriptionList'
          : 'payement_receive/getPrescriptionCodeList',
      query == null ? const {} : {'ph_pat': query},
      isCurrent,
    );
    accountsRequire(
      response.containsKey('pat_pres_list'),
      'The server returned incomplete patient data.',
    );
    return List.unmodifiable(
      _nestedList(response['pat_pres_list']).map(LedgerPatient.new),
    );
  }

  Future<LedgerData> ledger(
    AuthSession session,
    AccountProfile profile,
    VoucherDates dates, {
    LedgerAccount? account,
    LedgerPatient? patient,
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    accountsRequire(
      (account == null) != (patient == null),
      'Please select an account or patient.',
    );
    final wrappers = await _rows(
      session,
      profile,
      patient == null ? 'getAccLedger' : 'getAccLedgerPh',
      {
        'st_date': dates.first,
        'end_date': dates.last,
        if (patient == null) 'ad_id': account!.id else 'p_ph_id': patient.id,
      },
      isCurrent,
    );
    final rows = <LedgerRow>[];
    var emptyDebit = VtMoney.zero, emptyCredit = VtMoney.zero;
    for (final wrapper in wrappers) {
      accountsRequire(
        wrapper.containsKey('acc_ledger') && wrapper['acc_ledger'] != null,
        'The server returned incomplete ledger data.',
      );
      for (final raw in _nestedList(wrapper['acc_ledger'])) {
        final id = vtField(raw, 'lg_id');
        accountsRequire(
          id.isNotEmpty,
          'The server returned an incomplete ledger row.',
        );
        if (id == '0') {
          emptyDebit = VtMoney.parse(accountsField(raw, 'opening_dr'));
          emptyCredit = VtMoney.parse(accountsField(raw, 'opening_cr'));
        } else {
          final row = LedgerRow(raw);
          final date = parseOracleDate(row.date);
          accountsRequire(
            !date.isBefore(dates.firstDay) && !date.isAfter(dates.lastDay),
            'The server returned ledger data outside the selected date range.',
          );
          rows.add(row);
        }
      }
    }
    final openingDebit = rows.isEmpty ? emptyDebit : rows.first.openingDebit;
    final openingCredit = rows.isEmpty ? emptyCredit : rows.first.openingCredit;
    var balance =
        rows.isEmpty
            // The patient Activity explicitly uses credit - debit when there are no rows.
            ? patient != null
                ? openingCredit - openingDebit
                : ledgerOpeningBalance(
                  openingDebit,
                  openingCredit,
                  account!.headCode,
                )
            : ledgerOpeningBalance(
              openingDebit,
              openingCredit,
              rows.first.headCode,
            );
    final entries = <LedgerEntry>[];
    for (final row in rows) {
      // Native API supplies each balance; preserve row order and pass its exact
      // unrounded result to the next request. Never show a partial ledger.
      final values = await _rows(session, profile, 'getLedgerBalance', {
        'st_date': dates.first,
        'ad_id': account?.id ?? '',
        'debit_amnt': row.debit.text,
        'credit_amnt': row.credit.text,
        'ah_code': row.headCode,
        'balance': balance.text,
      }, isCurrent);
      accountsRequire(
        values.length == 1,
        'The server did not return this ledger balance.',
      );
      balance = VtMoney.parse(accountsField(values.single, 'ledger_balance'));
      entries.add(LedgerEntry(row, balance));
    }
    guard(session, profile, isCurrent);
    return LedgerData(dates, openingDebit, openingCredit, entries, balance);
  }
}

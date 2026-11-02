import '../../core/native_json.dart';
import '../../core/failure.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import 'payment_models.dart';
import 'payment_repository.dart';
import 'payment_update_models.dart';

class PaymentUpdateRepository extends PaymentRepository {
  const PaymentUpdateRepository(super.appointments);
  @override
  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() current,
  ) {
    super.guard(session, profile, current);
    if (profile.value('all_access_flag') != '1') {
      throw const PaymentUpdateUnavailable();
    }
  }

  Future<JsonMap> _read(
    AuthSession session,
    AccountProfile profile,
    String endpoint,
    Map<String, String> query,
    bool Function() current,
  ) async {
    guard(session, profile, current);
    final result = await appointments.transport
        .get(
          apiEndpoint(
            session.center.baseUri,
            'payement_receive/$endpoint',
            query,
          ),
        )
        .timeout(const Duration(seconds: 30));
    guard(session, profile, current);
    return result;
  }

  List<JsonMap> _rows(
    JsonMap data, {
    String field = 'items',
    bool count = true,
  }) {
    paymentRequire(
      data.containsKey(field),
      'The server returned incomplete payment data.',
    );
    final rows = nativeArray(data[field]);
    if (count) {
      final n = int.tryParse(nativeText(data['count']));
      paymentRequire(
        n != null && n >= 0 && (n == 0 ? rows.isEmpty : rows.isNotEmpty),
        'The server returned an invalid payment list.',
      );
    }
    return rows;
  }

  Future<List<PaymentChoice>> payments(
    AuthSession session,
    AccountProfile profile, {
    String search = '',
    required bool Function() isCurrent,
  }) async {
    if (search.isNotEmpty) {
      paymentRequire(
        paymentCodeSearchError(search) == null,
        paymentCodeSearchError(search) ?? 'Invalid payment code',
      );
    }
    final result = await _read(
      session,
      profile,
      search.isEmpty ? 'getFiftyPaymentList' : 'getPaymentCodeList',
      {if (search.isNotEmpty) 'prm_code': search},
      isCurrent,
    );
    final rows =
        _rows(
          result,
          field: 'pay_list',
          count: false,
        ).map(paymentRecord).toList();
    paymentRequire(
      rows.map((r) => r.id).toSet().length == rows.length,
      'The server returned duplicate payment records.',
    );
    return List.unmodifiable(rows);
  }

  Future<List<PaymentUpdateLine>> details(
    AuthSession session,
    AccountProfile profile,
    PaymentChoice payment, {
    required bool Function() isCurrent,
  }) async {
    paymentRequire(paymentId(payment.id), 'Please reselect the payment.');
    final rows =
        _rows(
          await _read(session, profile, 'getPaymentDetailsList', {
            'prm_id': payment.id,
          }, isCurrent),
        ).map(PaymentUpdateLine.fromJson).toList();
    paymentRequire(
      rows.map((r) => r.id).toSet().length == rows.length &&
          rows.map((r) => r.line.key).toSet().length == rows.length,
      'The server returned duplicate payment services.',
    );
    paymentRequire(
      rows.fold<BigInt>(
            BigInt.zero,
            (n, r) => n + BigInt.from(r.line.amount),
          ) <=
          BigInt.from(paymentMaxCents),
      'The payment amount is too large. Please check the services.',
    );
    return List.unmodifiable(rows);
  }

  Future<List<PaymentAllocation>> savedMethods(
    AuthSession session,
    AccountProfile profile,
    PaymentChoice payment, {
    required bool Function() isCurrent,
  }) async {
    paymentRequire(paymentId(payment.id), 'Please reselect the payment.');
    final rows =
        _rows(
          await _read(session, profile, 'getPaymentModeSavedList', {
            'prm_id': payment.id,
          }, isCurrent),
        ).map(savedPaymentAllocation).toList();
    paymentRequire(
      rows.map((r) => r.savedId).toSet().length == rows.length &&
          rows.map((r) => r.method.key).toSet().length == rows.length,
      'The server returned duplicate saved payment methods.',
    );
    return List.unmodifiable(rows);
  }

  void _settings(AccountProfile profile, PaymentUpdateSubmission receipt) {
    if ((profile.value('is_pay_mode_active') == '1') !=
        (receipt.confirmation != null)) {
      throw const PaymentSettingsChanged();
    }
  }

  Future<void> _validate(
    AuthSession session,
    AccountProfile profile,
    PaymentUpdateSubmission receipt,
    bool Function() current,
  ) async {
    _settings(profile, receipt);
    final latest = await details(
      session,
      profile,
      receipt.payment,
      isCurrent: current,
    );
    if (latest.any((r) => r.schedule > 0)) throw PaymentScheduleBlocked(latest);
    // Native APIs have no ETag. Recheck the original rows before the first
    // acknowledged mutation; after partial progress, do not compare our own
    // saved rows to the old snapshot or replay an acknowledged operation.
    if (receipt.servicesAcknowledged == 0 && receipt.methodsAcknowledged == 0) {
      final before = {for (final r in receipt.originals) r.id: r.fingerprint};
      if (latest.length != before.length ||
          latest.any((r) => before[r.id] != r.fingerprint)) {
        throw const PaymentRecordChanged();
      }
      if (receipt.confirmation != null) {
        final methods = await savedMethods(
          session,
          profile,
          receipt.payment,
          isCurrent: current,
        );
        String fp(PaymentAllocation row) =>
            '${row.savedId}|${row.method.key}|${row.cents}';
        final old = receipt.originalMethods.map(fp).toSet();
        if (methods.length != old.length ||
            methods.any((r) => !old.contains(fp(r)))) {
          throw const PaymentRecordChanged();
        }
      }
    }
  }

  Future<void> _postUpdate(
    AuthSession session,
    AccountProfile profile,
    PaymentUpdateSubmission receipt,
    String endpoint,
    Map<String, String> headers,
    bool Function() current,
    bool Function() owns,
  ) async {
    guard(session, profile, current);
    _settings(profile, receipt);
    if (receipt.uncertain) throw const PaymentWriteUncertain();
    receipt.started = true;
    JsonMap response;
    try {
      response = await appointments.transport
          .post(
            apiEndpoint(session.center.baseUri, 'payement_receive/$endpoint'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      receipt.uncertain = true;
      throw const PaymentWriteUncertain();
    }
    guard(session, profile, owns);
    final result = nativeText(response['string_out']);
    if (result.isEmpty) {
      receipt.uncertain = true;
      throw const PaymentWriteUncertain();
    }
    paymentRequire(
      result == 'Successfully Created',
      'The payment could not be updated. Please try again.',
    );
  }

  Future<void> submitUpdate(
    AuthSession session,
    AccountProfile profile,
    PaymentUpdateSubmission receipt, {
    required bool Function() isCurrent,
    required bool Function() ownsResponse,
  }) async {
    guard(session, profile, isCurrent);
    if (receipt.uncertain) throw const PaymentWriteUncertain();
    if (receipt.complete) return;
    paymentRequire(receipt.hasChanges, 'No new changes happened to update');
    await _validate(session, profile, receipt, isCurrent);
    final user = profile.value('usr_name');
    paymentRequire(user.isNotEmpty, 'The account information is incomplete.');
    final patient = PaymentChoice.patient(receipt.payment.data);
    while (receipt.servicesAcknowledged < receipt.serviceChanges.length) {
      final row = receipt.serviceChanges[receipt.servicesAcknowledged],
          line = row.line;
      final inserting = row.id.isEmpty;
      final headers = <String, String>{
        'P_PFN_ID': line.service.id,
        'P_DEPTS_ID': line.unit.id,
        'P_PRD_QTY': '${line.quantity}',
        'P_PRD_RATE': paymentMoney(line.rate.cents),
        'P_PRD_USR': user,
        'P_PRM_CODE': receipt.payment.name,
        if (inserting) ...{
          'P_PRD_PATIENT_CAT_ID': patient.value('ph_patient_cat_id'),
          'P_PRD_TOP_CAT_RATE': paymentMoney(line.rate.topCents),
          'P_PRM_ID': receipt.payment.id,
          'P_INSERT_TYPE_FLAG': '3',
        } else ...{
          'P_PRD_ID': row.id,
          'P_TOP_CAT_RATE': paymentMoney(line.rate.topCents),
        },
      };
      await _postUpdate(
        session,
        profile,
        receipt,
        inserting ? 'insertPaymentDetails' : 'updatePaymentDetails',
        headers,
        isCurrent,
        ownsResponse,
      );
      receipt.servicesAcknowledged++;
    }
    while (receipt.methodsAcknowledged < receipt.methodChanges.length) {
      final operation = receipt.methodChanges[receipt.methodsAcknowledged],
          row = operation.allocation;
      await _postUpdate(
        session,
        profile,
        receipt,
        'updatePaymentMode',
        {
          'P_AMOUNT': paymentMoney(row.cents, fixed: true),
          'P_PMM_ID': row.method.id,
          'P_PMD_ID': row.method.value('pmd_id'),
          'P_AD_ID': row.method.value('ad_id'),
          'D_PRMD_ID': row.savedId,
          'P_PRM_ID': receipt.payment.id,
          'P_UPDATE_TYPE': operation.type,
        },
        isCurrent,
        ownsResponse,
      );
      receipt.methodsAcknowledged++;
    }
    if (!ownsResponse()) throw const ObsoleteRequest();
  }
}

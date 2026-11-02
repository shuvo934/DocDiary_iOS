import '../../core/failure.dart';
import '../../core/native_dates.dart';
import '../../core/native_json.dart';
import '../appointments/doctor_schedule/doctor_appointment_repository.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../patient_search/patient_view_access.dart';
import 'payment_models.dart';

class PaymentRepository {
  const PaymentRepository(this.appointments);
  final DoctorAppointmentRepository appointments;
  DateTime now() => appointments.now();

  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() current,
  ) {
    guardPatientViewAccess(appointments, session, profile, current);
    if (!paymentAllowed(profile)) throw const PaymentUnavailable();
  }

  void _id(String id) =>
      paymentRequire(paymentId(id), 'Please reselect the payment details.');

  Future<JsonMap> _get(
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

  List<PaymentChoice> _choices(
    List<JsonMap> rows,
    PaymentChoice Function(JsonMap) parse,
  ) {
    final values = rows.map(parse).toList(growable: false);
    paymentRequire(
      values.map((r) => r.key).toSet().length == values.length,
      'The server returned duplicate payment choices. Please try again.',
    );
    return List.unmodifiable(values);
  }

  Future<List<PaymentChoice>> patients(
    AuthSession session,
    AccountProfile profile, {
    String search = '',
    required bool Function() isCurrent,
  }) async {
    if (search.isNotEmpty) {
      paymentRequire(
        paymentSearchError(search) == null,
        paymentSearchError(search) ?? 'Invalid search',
      );
    }
    // The native constructor accepts a year but neither of these endpoints
    // sends it. Retain the actual native API contract, including its spelling.
    final data = await _get(
      session,
      profile,
      search.isEmpty ? 'getFiftyPrescriptionList' : 'getPrescriptionCodeList',
      {if (search.isNotEmpty) 'ph_pat': search},
      isCurrent,
    );
    return _choices(
      _rows(data, field: 'pat_pres_list', count: false),
      PaymentChoice.patient,
    );
  }

  Future<List<PaymentChoice>> services(
    AuthSession session,
    AccountProfile profile, {
    required bool Function() isCurrent,
  }) async => _choices(
    _rows(await _get(session, profile, 'getServices', {}, isCurrent)),
    PaymentChoice.service,
  );

  Future<List<PaymentChoice>> units(
    AuthSession session,
    AccountProfile profile,
    PaymentChoice service, {
    required bool Function() isCurrent,
  }) async {
    _id(service.id);
    return _choices(
      _rows(
        await _get(session, profile, 'getServiceUnit', {
          'p_pfn_id': service.id,
        }, isCurrent),
      ),
      PaymentChoice.unit,
    );
  }

  Future<PaymentRate> rate(
    AuthSession session,
    AccountProfile profile,
    PaymentChoice patient,
    PaymentChoice service,
    PaymentChoice unit, {
    required bool Function() isCurrent,
  }) async {
    _id(patient.id);
    _id(patient.value('ph_patient_cat_id'));
    _id(service.id);
    _id(unit.id);
    return PaymentRate.fromJson(
      await _get(session, profile, 'getServiceRate', {
        'P_PFN_ID': service.id,
        'P_DEPTS_ID': unit.id,
        'P_PRM_DATE': paymentDate(now()),
        'P_PAT_CAT_ID': patient.value('ph_patient_cat_id'),
      }, isCurrent),
    );
  }

  Future<PaymentQuote> quote(
    AuthSession session,
    AccountProfile profile,
    List<PaymentServiceLine> lines, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    paymentRequire(
      profile.value('is_pay_mode_active') == '1',
      'Payment settings changed. Please reopen payment confirmation.',
    );
    paymentRequire(lines.isNotEmpty, 'Please Add Service.');
    final methods = _choices(
      _rows(await _get(session, profile, 'getPaymentMode', {}, isCurrent)),
      PaymentChoice.method,
    );
    final percentages = <String, BigInt>{};
    var total = BigInt.zero, chargeNumerator = BigInt.zero;
    for (final line in lines) {
      _id(line.service.id);
      _id(line.unit.id);
      if (!percentages.containsKey(line.service.id)) {
        final rows = _rows(
          await _get(session, profile, 'getServiceChargePFN', {
            'p_pfn_id': line.service.id,
          }, isCurrent),
        );
        paymentRequire(
          rows.isNotEmpty && rows.last.containsKey('s_c'),
          'The service charge could not be loaded. Please try again.',
        );
        final text = nativeText(rows.last['s_c'], '0');
        final match = RegExp(r'^(\d+)(?:\.(\d{1,6}))?$').firstMatch(text);
        paymentRequire(
          match != null,
          'The server returned an invalid service charge.',
        );
        percentages[line.service.id] =
            BigInt.parse(match![1]!) * BigInt.from(1000000) +
            BigInt.parse((match[2] ?? '').padRight(6, '0'));
      }
      total += BigInt.from(line.amount);
      chargeNumerator +=
          BigInt.from(line.amount) * percentages[line.service.id]!;
    }
    // Native sums per-service percentage charges, then rounds once to 2dp.
    final charge =
        (chargeNumerator + BigInt.from(50000000)) ~/ BigInt.from(100000000);
    paymentRequire(
      total + charge <= BigInt.from(paymentMaxCents),
      'The payment amount is too large. Please check the services.',
    );
    return PaymentQuote(
      total: total.toInt(),
      charge: charge.toInt(),
      methods: methods,
    );
  }

  Future<JsonMap> _post(
    AuthSession session,
    AccountProfile profile,
    PaymentSubmission receipt,
    String endpoint,
    Map<String, String> headers,
    bool Function() isCurrent,
    bool Function() ownsResponse,
  ) async {
    guard(session, profile, isCurrent);
    if (receipt.uncertain) throw const PaymentWriteUncertain();
    if ((profile.value('is_pay_mode_active') == '1') !=
        (receipt.confirmation != null)) {
      throw const PaymentSettingsChanged();
    }
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
    // Backgrounding may happen after the server saved this row. Retain the
    // acknowledgement in this account, but guard again before any next POST.
    guard(session, profile, ownsResponse);
    if (!response.containsKey('string_out') ||
        nativeText(response['string_out']).isEmpty) {
      receipt.uncertain = true;
      throw const PaymentWriteUncertain();
    }
    paymentRequire(
      nativeText(response['string_out']) == 'Successfully Created',
      'The payment could not be saved. Please try again.',
    );
    return response;
  }

  Future<void> submit(
    AuthSession session,
    AccountProfile profile,
    PaymentSubmission receipt, {
    required bool Function() isCurrent,
    required bool Function() ownsResponse,
  }) async {
    guard(session, profile, isCurrent);
    if (receipt.uncertain) throw const PaymentWriteUncertain();
    _id(receipt.patient.id);
    _id(receipt.patient.value('ph_patient_cat_id'));
    parseOracleDate(receipt.date);
    paymentRequire(
      profile.value('usr_name').isNotEmpty,
      'The account information is incomplete.',
    );
    final user = profile.value('usr_name');
    if (receipt.masterId == null) {
      final result = await _post(
        session,
        profile,
        receipt,
        'insertPaymentMaster',
        {
          'P_PRM_DATE': receipt.date,
          'P_PRM_ONLINE_OFFLINE_FLAG': '0',
          'P_PRM_PATIENT_CAT_ID': receipt.patient.value('ph_patient_cat_id'),
          'P_PRM_PH_ID': receipt.patient.id,
          'P_PRM_USER': user,
          'P_INSERT_TYPE_FLAG': '3',
          'P_PAID_AMOUNT': paymentMoney(receipt.paid, fixed: true),
        },
        isCurrent,
        ownsResponse,
      );
      final id = nativeText(result['out_prm_id']),
          code = nativeText(result['out_prm_code']);
      if (!paymentId(id) || code.isEmpty || code == 'Not Found') {
        receipt.uncertain = true;
        throw const PaymentWriteUncertain();
      }
      receipt.masterId = id;
      receipt.masterCode = code;
    }
    while (receipt.servicesAcknowledged < receipt.lines.length) {
      final line = receipt.lines[receipt.servicesAcknowledged];
      await _post(
        session,
        profile,
        receipt,
        'insertPaymentDetails',
        {
          'P_DEPTS_ID': line.unit.id,
          'P_PFN_ID': line.service.id,
          'P_PRD_PATIENT_CAT_ID': receipt.patient.value('ph_patient_cat_id'),
          'P_PRD_QTY': '${line.quantity}',
          'P_PRD_RATE': paymentMoney(line.rate.cents),
          'P_PRD_TOP_CAT_RATE': paymentMoney(line.rate.topCents),
          'P_PRD_USR': user,
          'P_PRM_CODE': receipt.masterCode!,
          'P_PRM_ID': receipt.masterId!,
          'P_INSERT_TYPE_FLAG': '3',
        },
        isCurrent,
        ownsResponse,
      );
      receipt.servicesAcknowledged++;
    }
    final allocations =
        receipt.confirmation?.allocations ?? const <PaymentAllocation>[];
    while (receipt.methodsAcknowledged < allocations.length) {
      final row = allocations[receipt.methodsAcknowledged];
      await _post(
        session,
        profile,
        receipt,
        'insertPaymentMode',
        {
          'P_AMOUNT': paymentMoney(row.cents, fixed: true),
          'P_PMM_ID': row.method.id,
          'P_PMD_ID': row.method.value('pmd_id'),
          'P_AD_ID': row.method.value('ad_id'),
          'P_PRM_ID': receipt.masterId!,
        },
        isCurrent,
        ownsResponse,
      );
      receipt.methodsAcknowledged++;
    }
    if (!ownsResponse()) throw const ObsoleteRequest();
  }
}

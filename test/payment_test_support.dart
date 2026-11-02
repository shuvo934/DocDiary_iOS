import 'dart:convert';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/payments/payment_models.dart';
import 'package:docdiary_ios/features/payments/payment_repository.dart';
import 'all_appointment_test_support.dart';
import 'support.dart';

class PaymentHarness extends AllAppointmentHarness {
  PaymentHarness({bool fullAccess = true, bool mode = true})
    : super(
        admin: true,
        canCall: fullAccess,
        clock: DateTime(2026, 11, 1, 11),
      ) {
    adminData.addAll({
      'hr_payment_active': '1',
      'acc_payment_active': '1',
      'is_pay_mode_active': mode ? '1' : '0',
    });
    transport.onGet = respondPayment;
    transport.onPost =
        (uri, headers) async =>
            uri.pathSegments.last == 'insertPaymentMaster'
                ? {
                  'string_out': 'Successfully Created',
                  'out_prm_id': '501',
                  'out_prm_code': 'PR.26.000501',
                }
                : {'string_out': 'Successfully Created'};
  }
  PaymentRepository get paymentRepository => PaymentRepository(appointments);
  AccountProfile get profile => AccountProfile(AccountRole.admin, adminData);
  bool encoded = false;
  final patients = <JsonMap>[
    {
      'ph_id': '101',
      'ph_sub_code': '26.01.000101.01',
      'pat_name': 'Sample Patient A',
      'pat_code': '26.01.000101',
      'pat_cell': '01712345678',
      'pat_date': '01-NOV-26',
      'gender': 'Male',
      'pat_blood': 'O+',
      'address': 'Example address',
      'ph_patient_cat': 'C',
      'ph_patient_cat_id': '3',
      'ph_patient_status': 'New',
      'marital_status': 'Married',
      'p_age': '32 Years 8 Months 28 Days',
    },
    {
      'ph_id': '102',
      'ph_sub_code': '26.01.000102.01',
      'pat_name': 'Sample Patient A',
      'pat_code': '26.01.000102',
      'pat_cell': '01812345678',
      'pat_date': '01-NOV-26',
      'gender': 'Female',
      'pat_blood': '',
      'address': '',
      'ph_patient_cat': 'A',
      'ph_patient_cat_id': '1',
      'ph_patient_status': 'New',
      'marital_status': '',
      'p_age': '7 Years',
    },
  ];
  final services = <JsonMap>[
    {
      'pfn_id': '31',
      'pfn_fee_name': 'Physiotherapy Service Charge',
      'pct_flag': '1',
    },
    {
      'pfn_id': '32',
      'pfn_fee_name': 'Speech & Language Therapy Service Charge',
      'pct_flag': '0',
    },
  ];
  final units = <JsonMap>[
    {'depts_id': '20', 'depts_name': 'Autism Communication Group'},
    {'depts_id': '21', 'depts_name': 'Assessment'},
  ];
  final methods = <JsonMap>[
    {
      'pmm_id': '1',
      'pmm_name': 'Cash Payment (1)',
      'pmd_id': '11',
      'ad_id': '111',
      'account_name': 'Cash in Hand (010101001)',
    },
    {
      'pmm_id': '2',
      'pmm_name': 'Bank Payment (1653)',
      'pmd_id': '12',
      'ad_id': '112',
      'account_name':
          'Example Bank, S/A: No-0000000000000000, Example Branch. (010301000005)',
    },
    {
      'pmm_id': '3',
      'pmm_name': 'Bank Payment (1452)',
      'pmd_id': '13',
      'ad_id': '113',
      'account_name': 'Second Bank Account',
    },
  ];
  JsonMap rateResponse = {
    'p_service_rate': '600',
    'p_service_top_rate': '1000',
  };
  String charge = '3';
  Future<JsonMap?> Function(Uri)? onPaymentGet;
  Future<JsonMap> respondPayment(Uri uri) async {
    if (!uri.path.contains('/payement_receive/')) return respondAll(uri);
    final override = await onPaymentGet?.call(uri);
    if (override != null) return override;
    final endpoint = uri.pathSegments.last;
    final List<JsonMap> rows;
    String field = 'items';
    switch (endpoint) {
      case 'getFiftyPrescriptionList':
      case 'getPrescriptionCodeList':
        rows = patients;
        field = 'pat_pres_list';
      case 'getServices':
        rows = services;
      case 'getServiceUnit':
        rows = units;
      case 'getPaymentMode':
        rows = methods;
      case 'getServiceRate':
        return rateResponse;
      case 'getServiceChargePFN':
        rows = [
          {'s_c': charge},
        ];
      default:
        throw StateError('Unexpected synthetic Payment endpoint: $endpoint');
    }
    return {'count': rows.length, field: encoded ? jsonEncode(rows) : rows};
  }

  List<RequestRecord> get paymentReads =>
      transport.requests
          .where(
            (r) =>
                r.method == 'GET' && r.uri.path.contains('/payement_receive/'),
          )
          .toList();
  List<RequestRecord> get paymentPosts =>
      transport.requests
          .where(
            (r) =>
                r.method == 'POST' && r.uri.path.contains('/payement_receive/'),
          )
          .toList();
  PaymentDraft draft({int quantity = 4}) =>
      PaymentDraft()
        ..selectPatient(PaymentChoice.patient(patients.first), '01-Nov-26')
        ..add(
          PaymentServiceLine(
            service: PaymentChoice.service(services.first),
            unit: PaymentChoice.unit(units.first),
            rate: const PaymentRate(60000, 100000),
            quantity: quantity,
          ),
        );
  PaymentConfirmation confirmation(PaymentDraft draft, {bool split = false}) {
    final quote = PaymentQuote(
      total: draft.total,
      charge: 7200,
      methods: methods.map(PaymentChoice.method).toList(),
    );
    return PaymentConfirmation(
      quote,
      split
          ? [
            PaymentAllocation(quote.methods[1], 200000),
            PaymentAllocation(quote.methods[0], 47200),
          ]
          : [PaymentAllocation(quote.methods[0], quote.grandTotal)],
    );
  }
}

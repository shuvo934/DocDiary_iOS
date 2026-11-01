import 'dart:convert';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/appointments/admin_modify/admin_appointment_models.dart';
import 'package:docdiary_ios/features/appointments/admin_modify/admin_appointment_repository.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'all_appointment_test_support.dart';
import 'support.dart';

class AdminAppointmentHarness extends AllAppointmentHarness {
  AdminAppointmentHarness({
    bool fullAccess = true,
    DateTime? clock,
    bool autoSelect = true,
  }) : super(
         admin: true,
         canCall: fullAccess,
         clock: clock ?? DateTime(2026, 11, 1, 11),
       ) {
    transport.onGet = respondAdmin;
    transport.onPost =
        (uri, headers) async => {
          'string_out': 'Successfully Created',
          'p_sch_msg': 'false',
        };
    if (!autoSelect) {
      doctors = [
        ...doctors,
        {...doctors.first, 'depts_id': '21', 'depts_name': 'Another Unit'},
      ];
      payments = [
        ...payments,
        {...payments.first, 'prm_id': '202', 'prm_code': 'PAY-002'},
      ];
      services = [
        ...services,
        {...services.first, 'pfn_id': '32', 'prd_id': '42'},
      ];
    }
  }
  AdminAppointmentRepository get repository =>
      AdminAppointmentRepository(appointments);
  AccountProfile get profile => AccountProfile(AccountRole.admin, adminData);
  List<JsonMap> patients = [
    {
      'ph_id': '101',
      'ph_pat_id': '901',
      'ph_sub_code': 'RX-101',
      'ph_date': '01-NOV-26',
      'ph_patient_cat_id': '2',
      'ph_patient_cat': 'A',
      'pat_code': 'PAT-01',
      'pat_name': 'Example Patient',
      'pat_phone': '01712345678',
      'pat_cell': '01712345678',
    },
    {
      'ph_id': '102',
      'ph_pat_id': '902',
      'ph_sub_code': 'RX-102',
      'ph_date': '01-NOV-26',
      'ph_patient_cat_id': '3',
      'ph_patient_cat': 'B',
      'pat_code': 'PAT-02',
      'pat_name': 'Example Patient',
      'pat_phone': '01812345678',
      'pat_cell': '01812345678',
    },
  ];
  List<JsonMap> doctors = [
    {
      'doc_id': '10',
      'doc_code': 'D-10',
      'doc_name': 'Example Therapist',
      'depts_id': '20',
      'depts_name': 'Therapy Unit',
      'deptd_id': '8',
      'deptd_code': 'THER',
      'deptd_name': 'Rehabilitation Department',
      'desig_id': '5',
      'desig_name': 'Therapist',
    },
  ];
  List<JsonMap> payments = [
    {'prm_id': '201', 'prm_code': 'PAY-001', 'prm_date': '01-NOV-26'},
  ];
  List<JsonMap> services = [
    {
      'pfn_id': '31',
      'prd_id': '41',
      'pfn_fee_name': 'Therapy Service',
      'rest': '3',
    },
  ];
  List<JsonMap> days = [
    for (var i = 0; i < 3; i++)
      {'adm_id': '${301 + i}', 'p_adm_date': '0${2 + i}-NOV-26'},
  ];
  List<JsonMap> times = [
    {
      'ts_id': '401',
      'schedule': '09:00 AM',
      'ts_eta_flag': '0',
      'type': 'Regular',
    },
    {
      'ts_id': '402',
      'schedule': '11:00 AM',
      'ts_eta_flag': '0',
      'type': 'Regular',
    },
  ];
  List<JsonMap> taken = [];
  List<JsonMap> cancellationRows = [
    {
      'ad_id': '501',
      'app_date': '02-NOV-26',
      'time_list': [
        {'as_ts_id': '401', 'schedule': '09:00 AM'},
        {'as_ts_id': '402', 'schedule': '11:00 AM'},
      ],
    },
  ];
  JsonMap limitData = {'allowed_qty': '4', 'taken_service_qty': '0'};
  bool encoded = false;
  String apiName = 'getAvailableTimes';
  Future<JsonMap?> Function(Uri)? onAppointmentGet;
  Future<JsonMap> respondAdmin(Uri uri) async {
    if (!uri.path.contains('/appointmentModify/')) return respondAll(uri);
    final overridden = await onAppointmentGet?.call(uri);
    if (overridden != null) return overridden;
    final name = uri.pathSegments.last;
    final field =
        name.contains('PatientListForCancel') || name.contains('PatListFor')
            ? 'pat_list'
            : 'items';
    final List<JsonMap> rows;
    switch (name) {
      case 'getFiftyPatientListForAddApp':
      case 'getFiftyPatientListForCancelAppNew':
      case 'getPatListForAddAppBySearch':
      case 'getPatListForCancelAppBySearch':
        rows = patients;
      case 'getDoctorList':
      case 'getDoctorListForCancel':
        rows = doctors;
      case 'getPaymentForAddAppList':
        rows = payments;
      case 'getServiceForAddAppList':
      case 'getServiceForCancAppList':
        rows = services;
      case 'getAppDateTimeForCancel':
        rows = cancellationRows;
      case 'getAppointmentDateList':
        rows = days;
      case 'getTimeApiForDiffOccurance':
        return {'api_name': apiName};
      case 'getAvailableTimes':
        rows = times;
      case 'getTakenScheduleList':
        rows = taken;
      case 'checkSchLimitValidation':
        return limitData;
      default:
        throw StateError('Unexpected synthetic appointment endpoint: $name');
    }
    return {'count': rows.length, field: encoded ? jsonEncode(rows) : rows};
  }

  @override
  List<RequestRecord> get appointmentReads =>
      transport.requests
          .where(
            (r) =>
                r.method == 'GET' && r.uri.path.contains('/appointmentModify/'),
          )
          .toList();
  List<RequestRecord> get appointmentPosts =>
      posts.where((r) => r.uri.path.contains('/appointmentModify/')).toList();
  AdminAppointmentDraft draft({bool cancel = false}) {
    final value = AdminAppointmentDraft(cancel: cancel);
    value.selectPatient(AdminAppointmentChoice.patient(patients.first));
    value.doctors = doctors.map(AdminAppointmentChoice.doctor).toList();
    value.selectDoctor(value.doctors.first);
    value.payments = payments.map(AdminAppointmentChoice.payment).toList();
    value.selectPayment(value.payments.first);
    value.services = services.map(AdminAppointmentChoice.service).toList();
    value.selectService(value.services.first);
    value.limit = AdminScheduleLimit(limitData);
    value.cancellations = cancellationRows.map(AdminCancellation.new).toList();
    if (cancel) value.cancellation = value.cancellations.first;
    return value;
  }

  AdminSchedule schedule([int day = 0, int time = 0, bool taken = false]) =>
      AdminSchedule(
        day: AdminAppointmentDay(days[day]),
        time: AdminAppointmentTime(times[time]),
        taken: taken,
      );
}

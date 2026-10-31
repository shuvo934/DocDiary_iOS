import 'dart:async';
import 'dart:convert';
import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/appointments/unit_schedule/unit_appointment_repository.dart';
import 'doctor_appointment_test_support.dart';

JsonMap unitSlot({
  String patient = '11',
  String name = 'Sample Patient',
  String time = '02:00 PM',
  String day = '24-OCT-26',
  String service = 'Physiotherapy Service Charge',
}) => {
  'adm_date': day,
  'schedule_time': time,
  'patient_data': patient,
  'pat_name': name,
  'pat_code': 'P-11',
  'pat_cell': '01700000000',
  'pfn_fee_name': service,
};
JsonMap unitDoctor({
  String id = '10',
  String name = 'Sample Therapist A',
  String code = 'T-10',
  String appointments = '3',
  String total = '5',
  String busy = '1',
  List<JsonMap>? slots,
}) => {
  'doc_id': id,
  'doc_name': name,
  'doc_code': code,
  'app_count': appointments,
  'tot_count': total,
  'busy_count': busy,
  'app_list':
      slots ??
      [
        unitSlot(name: 'Past Patient', time: '08:00 AM'),
        unitSlot(patient: '', time: '09:00 AM'),
        unitSlot(patient: 'Blocked Time', time: '10:00 AM'),
        unitSlot(name: 'Next Patient', time: '02:00 PM'),
        unitSlot(name: 'Later Patient', time: '03:00 PM'),
      ],
};

class UnitAppointmentHarness extends DoctorAppointmentHarness {
  UnitAppointmentHarness({super.clock}) {
    doctorData.addAll({
      'doc_deptd_head_flag': '1',
      'doc_manager_flag': '0',
      'deptd_id': '8',
      'depts_id': '2',
    });
    transport.onGet = respondUnit;
    doctorsByUnit['2'] = [
      unitDoctor(),
      unitDoctor(
        id: '20',
        name: 'Sample Therapist B',
        code: 'T-20',
        appointments: '1',
        total: '2',
        busy: '0',
        slots: [
          unitSlot(patient: '', time: '11:00 AM'),
          unitSlot(name: 'Evening Patient', time: '04:00 PM'),
        ],
      ),
      unitDoctor(
        id: '30',
        name: 'Sample Therapist C',
        code: 'T-30',
        appointments: '0',
        total: '0',
        busy: '0',
        slots: [],
      ),
    ];
    doctorsByUnit['3'] = [
      unitDoctor(
        id: '40',
        name: 'Other Unit Therapist',
        code: 'T-40',
        appointments: '1',
        total: '1',
        busy: '0',
        slots: [unitSlot(name: 'Other Unit Patient')],
      ),
    ];
    doctorsByUnit['9'] = [
      unitDoctor(
        id: '90',
        name: 'New Department Therapist',
        code: 'T-90',
        appointments: '1',
        total: '1',
        busy: '0',
        slots: [unitSlot(name: 'New Department Patient')],
      ),
    ];
  }
  UnitAppointmentRepository get unitRepository =>
      UnitAppointmentRepository(appointments);
  List<JsonMap> unitRows = [
    {'depts_id': '2', 'depts_name': 'Outpatient Unit'},
    {'depts_id': '3', 'depts_name': 'Therapy Unit'},
  ];
  final doctorsByUnit = <String, List<JsonMap>>{};
  JsonMap? unitsResponse, doctorsResponse;
  bool failUnits = false, failDoctors = false, encodedArrays = false;
  Completer<JsonMap>? pendingUnits, pendingDoctors, pendingProfile;
  Future<JsonMap> respondUnit(Uri uri) async {
    final endpoint = uri.pathSegments.last;
    if (endpoint == 'getDocData' && pendingProfile != null) {
      return pendingProfile!.future;
    }
    if (endpoint == 'getUnitList') {
      if (pendingUnits != null) return pendingUnits!.future;
      if (failUnits) throw const AppFailure('Unit list unavailable');
      final rows =
          uri.queryParameters['deptd_id'] == '99'
              ? [
                <String, Object?>{
                  'depts_id': '9',
                  'depts_name': 'New Department Unit',
                },
              ]
              : unitRows;
      return unitsResponse ??
          {
            'count': rows.length,
            'items': encodedArrays ? jsonEncode(rows) : rows,
          };
    }
    if (endpoint == 'getDocWithSchedule') {
      if (pendingDoctors != null) return pendingDoctors!.future;
      if (failDoctors) throw const AppFailure('Doctor schedule unavailable');
      final rows = [
        for (final row
            in doctorsByUnit[uri.queryParameters['depts_id']] ?? <JsonMap>[])
          {
            ...row,
            'app_list':
                encodedArrays
                    ? jsonEncode([
                      for (final slot in nativeArray(row['app_list']))
                        {...slot, 'adm_date': uri.queryParameters['pdate']},
                    ])
                    : [
                      for (final slot in nativeArray(row['app_list']))
                        {...slot, 'adm_date': uri.queryParameters['pdate']},
                    ],
          },
      ];
      return doctorsResponse ??
          {
            'count': rows.length,
            'items': encodedArrays ? jsonEncode(rows) : rows,
          };
    }
    return respondAppointments(uri);
  }

  List<Uri> get unitReads =>
      transport.requests
          .where((r) => r.uri.path.endsWith('/getUnitList'))
          .map((r) => r.uri)
          .toList();
  List<Uri> get scheduleReads =>
      transport.requests
          .where((r) => r.uri.path.endsWith('/getDocWithSchedule'))
          .map((r) => r.uri)
          .toList();
}

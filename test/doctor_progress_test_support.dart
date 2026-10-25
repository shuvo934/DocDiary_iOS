import 'dart:convert';
import 'package:docdiary_ios/core/native_dates.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/doctor_appointment_models.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/progress/doctor_progress_models.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/progress/doctor_progress_repository.dart';
import 'doctor_appointment_test_support.dart';
import 'support.dart';

JsonMap progressRow({
  String id = '3',
  String service = '3',
  String unit = '2',
  String doctor = '20',
  String appointment = 'OLD-3',
  String score = '8',
  String notes = 'Patient walks with assistance',
}) => {
  'pph_id': id,
  'pph_date': '24-OCT-26',
  'pph_doc_id': doctor,
  'doc_name': 'Example Doctor',
  'pph_depts_id': unit,
  'detps_name': unit == '2' ? 'Adult Unit' : 'Child Unit',
  'pph_pfn_id': service,
  'pfn_name': service == '3' ? 'Physiotherapy' : 'Occupational Therapy',
  'pph_ad_id': appointment,
  'pph_progress': score,
  'pph_notes': notes,
  'pph_rec_no': 'Record-$id',
};

class DoctorProgressHarness extends DoctorAppointmentHarness {
  DoctorProgressHarness() {
    customRows = [doctorAppointmentRow(time: '09:00 AM')];
    transport.onGet = respondProgress;
  }
  List<JsonMap> progressRows = [
    progressRow(),
    progressRow(
      id: '2',
      service: '30',
      unit: '20',
      doctor: '10',
      appointment: 'OLD-2',
      score: '4',
    ),
    progressRow(id: '1', doctor: '10', appointment: 'OLD-1', score: '2'),
  ];
  DoctorProgressRepository get progress =>
      DoctorProgressRepository(appointments);
  DoctorProgressSeed get seed => DoctorProgressSeed.fromAppointment(
    DoctorAppointmentRow(customRows!.first, selectedDate: dateOnly(now)),
    ownerDoctorId: '10',
  );
  List<RequestRecord> get progressReads =>
      transport.requests
          .where((r) => r.uri.path.contains('/health_progress/'))
          .toList();
  List<BinaryRequestRecord> get progressWrites =>
      transport.binaryRequests
          .where((r) => r.uri.path.endsWith('/InsertPatProgress'))
          .toList();
  Future<JsonMap> respondProgress(Uri uri) async {
    final endpoint = uri.pathSegments.last;
    if (!uri.path.contains('/health_progress/')) {
      return await respondAppointments(uri);
    }
    final List<JsonMap> rows = switch (endpoint) {
      'getHealthProgress' => progressRows,
      'getService' => [
        {'pph_pfn_id': '3', 'pfn_name': 'Physiotherapy'},
        {'pph_pfn_id': '30', 'pfn_name': 'Occupational Therapy'},
        {'pph_pfn_id': '99', 'pfn_name': 'Unused Service'},
      ],
      'getUnit' => [
        {'pph_depts_id': '2', 'detps_name': 'Adult Unit'},
        {'pph_depts_id': '20', 'detps_name': 'Child Unit'},
      ],
      'getDocs' => [
        {'pph_doc_id': '20', 'doc_name': 'Example Doctor'},
        {'pph_doc_id': '10', 'doc_name': 'Example Doctor'},
      ],
      _ => throw StateError('Unexpected progress read $endpoint'),
    };
    return {'count': rows.length, 'items': rows};
  }

  void commitProgress(BinaryRequestRecord request) {
    final body = nativeObject(utf8.decode(request.body));
    progressRows = [
      progressRow(
        id: 'new',
        doctor: '10',
        appointment: body['P_AD_ID']! as String,
        score: body['P_PROGRESS']! as String,
        notes: body['P_NOTES']! as String,
      ),
      ...progressRows,
    ];
    customRows = [
      {
        ...customRows!.first,
        'is_ranked': '1',
        'pph_progress': body['P_PROGRESS'],
      },
    ];
  }
}

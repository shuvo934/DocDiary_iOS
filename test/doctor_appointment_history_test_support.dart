import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/history/doctor_appointment_history_models.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/history/doctor_appointment_history_repository.dart';
import 'doctor_appointment_test_support.dart';
import 'support.dart';

const historyPatient = AppointmentHistoryPatient(
  id: '11',
  name: 'Sample Patient',
  code: 'P-11',
);
JsonMap appointmentHistoryRow({
  String service = '1',
  String unit = '2',
  String doctor = '10',
  String day = '23-OCT-26',
  String time = '09:00 AM',
}) => {
  'ph_patient_status': 'Outdoor',
  'ph_patient_cat': 'Adult',
  'app_date': day,
  'date_name': 'Friday',
  'depts_name': unit == '2' ? 'Adult Unit' : 'Child Unit',
  'depts_id': unit,
  'deptd_name': 'Physiotherapy Department',
  'deptm_name': 'Rehabilitation',
  'schedule_time': time,
  'ets': 'Regular',
  'doc_name': 'Dr. Example',
  'doc_id': doctor,
  'pfn_fee_name': service == '1' ? 'Physiotherapy' : 'Occupational Therapy',
  'pfn_id': service,
  'avail': 'Yes',
  'ad_pat_app_status': 'Old',
  'cancel_status': 'No',
  'prm_code': 'Request-1',
};

class AppointmentHistoryHarness extends DoctorAppointmentHarness {
  AppointmentHistoryHarness() {
    customRows = [doctorAppointmentRow(id: '41', time: '09:00 AM')];
    transport.onGet = respondHistory;
  }
  List<JsonMap> historyRows = [
    appointmentHistoryRow(),
    {
      ...appointmentHistoryRow(service: '10', unit: '20', doctor: '1'),
      'cancel_status': 'Yes',
    },
    {
      ...appointmentHistoryRow(doctor: '1', day: '24-OCT-26', time: '03:00 PM'),
      'date_name': 'Saturday',
    },
  ];
  DoctorAppointmentHistoryRepository get history =>
      DoctorAppointmentHistoryRepository(appointments);
  Future<JsonMap> respondHistory(Uri uri) async =>
      uri.path.endsWith('/getPatAppointHistory')
          ? {'count': historyRows.length, 'items': historyRows}
          : await respondAppointments(uri);
  List<RequestRecord> get historyReads =>
      transport.requests
          .where((r) => r.uri.path.endsWith('/getPatAppointHistory'))
          .toList();
}

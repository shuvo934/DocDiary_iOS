import 'package:docdiary_ios/core/native_dates.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/doctor_appointment_repository.dart';
import 'support.dart';

JsonMap doctorAppointmentRow({
  String id = '41',
  String patient = '11',
  String time = '02:00 PM',
  String day = '24-OCT-26',
  String name = 'Sample Patient',
}) => {
  'adm_date': day,
  'schedule_time': time,
  'patient_data': patient,
  'depts_id': '2',
  'depts_name': 'Physiotherapy',
  'pat_name': name,
  'pat_gender': 'Female',
  'pat_id': '21',
  'pat_code': 'P-11',
  'pat_age_now': '35 Years',
  'pfn_fee_name': 'Physiotherapy Service',
  'doc_video_link': 'https://video.example/meeting',
  'ts_video_conf_flag': '0',
  'pmm': '0',
  'rvm': '0',
  'rvm_id': '',
  'is_ranked': '0',
  'pph_progress': '0',
  'pfn_id': '3',
  'ph_cat_id': '4',
  'ad_id': id,
  'ad_prm_id': '5',
  'ad_prd_id': '6',
  'avail_flag': '0',
};

class DoctorAppointmentHarness extends Harness {
  DoctorAppointmentHarness({DateTime? clock})
    : super(clock: clock ?? DateTime(2026, 10, 24, 13, 30)) {
    doctorData.addAll({
      'pat_app_history': '1',
      'upcoming_pat_history': '1',
      'is_need_avail': '1',
    });
    transport.onGet = respondAppointments;
  }
  List<JsonMap>? customRows;
  DoctorAppointmentRepository get appointments =>
      DoctorAppointmentRepository(transport, now: () => now);
  Future<JsonMap> respondAppointments(Uri uri) async {
    if (uri.path.endsWith('/getPatAppointHistory')) {
      return {'count': 0, 'items': <Object?>[]};
    }
    if (uri.path.contains('/appointment_schedule/')) {
      final day = uri.queryParameters['pdate']!;
      final rows =
          customRows ??
          [
            {
              ...doctorAppointmentRow(id: '1', day: day, time: '08:00 AM'),
              'avail_flag': '1',
              'is_ranked': '1',
              'pph_progress': '7',
              'rvm': '1',
              'rvm_id': 'RX-1',
            },
            doctorAppointmentRow(id: '2', day: day, time: '09:00 AM'),
            doctorAppointmentRow(
              id: '3',
              day: day,
              time: '10:00 AM',
              patient: '',
            ),
            {
              ...doctorAppointmentRow(
                id: '4',
                day: day,
                time: '11:00 AM',
                patient: 'Blocked Time',
              ),
            },
            {
              ...doctorAppointmentRow(id: '5', day: day, time: '02:00 PM'),
              'ts_video_conf_flag': '1',
            },
            {
              ...doctorAppointmentRow(id: '6', day: day, time: '03:00 PM'),
              'pph_progress': '5',
              'is_ranked': '1',
            },
          ];
      return {'count': rows.length, 'items': rows};
    }
    return defaultGet(uri);
  }

  List<RequestRecord> get appointmentReads =>
      transport.requests
          .where((r) => r.uri.path.contains('/appointment_schedule/'))
          .toList();
  void changeDay(DateTime day) => now = day;
  String get day => oracleDate(now);
}

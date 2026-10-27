import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/core/transport.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/doctor_appointment_repository.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';

class DynamicClinicalRequest {
  const DynamicClinicalRequest(this.method, this.uri);
  final String method;
  final Uri uri;
}

class DynamicClinicalFakeTransport implements Transport {
  final requests = <DynamicClinicalRequest>[];
  Future<JsonMap> Function(Uri)? onGet;
  @override
  Future<JsonMap> get(Uri uri) async {
    requests.add(DynamicClinicalRequest('GET', uri));
    return onGet == null ? {'items': []} : await onGet!(uri);
  }

  @override
  Future<JsonMap> post(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    requests.add(DynamicClinicalRequest('POST', uri));
    throw StateError('Clinical editing must not write to the server');
  }

  @override
  Future<String> getText(Uri uri) =>
      throw StateError('Unexpected text request');
  @override
  void close() {}
}

class DynamicClinicalHarness {
  DynamicClinicalHarness() {
    const account = AccountOption(role: AccountRole.doctor, doctorCode: 'D-10');
    final centre = CenterOption(
      name: 'Test Centre',
      baseUri: Uri.parse('https://centre.example/api/'),
      accounts: [account],
      requiresAccountChoice: false,
    );
    session = AuthSession(
      credentials: const Credentials('test-mobile', 'test-password'),
      center: centre,
      account: account,
      centers: [centre],
      remember: false,
    );
  }
  final transport = DynamicClinicalFakeTransport();
  final JsonMap doctorData = {
    'user_avail': '1',
    'doc_id': '10',
    'doc_code': 'D-10',
    'fl_flag': '0',
    'access_flag': '1',
    'doc_app_first_login_flag': '1',
    'exp_date': '15-JAN-27',
    'presc_active': '1',
    'can_prescribe': '1',
  };
  late final AuthSession session;
  AccountProfile get profile => AccountProfile(AccountRole.doctor, doctorData);
  DoctorAppointmentRepository get appointments =>
      DoctorAppointmentRepository(transport, now: () => DateTime(2026, 10, 27));
}

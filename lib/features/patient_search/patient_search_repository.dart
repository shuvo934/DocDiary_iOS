import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../appointments/doctor_schedule/doctor_appointment_repository.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../dynamic_prescription/dynamic_history_models.dart';
import '../prescription/normal_prescription_models.dart';
import '../prescription/normal_prescription_repository.dart';
import 'patient_search_models.dart';

class PatientSearchRepository {
  const PatientSearchRepository(this.appointments);
  final DoctorAppointmentRepository appointments;
  DateTime now() => appointments.now();

  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() current,
  ) => appointments.guard(session, profile, current);

  Future<JsonMap> _get(
    AuthSession session,
    AccountProfile profile,
    String path,
    Map<String, String> query,
    bool Function() current,
  ) async {
    guard(session, profile, current);
    final data = await appointments.transport
        .get(apiEndpoint(session.center.baseUri, path, query))
        .timeout(
          const Duration(seconds: 30),
          onTimeout:
              () =>
                  throw const AppFailure(
                    'The server took too long to respond. Please try again.',
                    kind: FailureKind.network,
                  ),
        );
    guard(session, profile, current);
    return data;
  }

  Future<List<PatientSearchRow>> patients(
    AuthSession session,
    AccountProfile profile,
    int year, {
    String? search,
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    rxRequire(
      year >= 1950 && year <= now().year,
      'Please select a valid year.',
    );
    final mode = PatientSearchMode.forProfile(profile);
    if (mode == PatientSearchMode.normal) {
      final rows = await NormalPrescriptionRepository(
        appointments,
      ).patients(session, profile, year, isCurrent: isCurrent);
      return List.unmodifiable(rows.map(PatientSearchRow.new));
    }
    final query = search?.trim();
    if (query != null) {
      rxRequire(
        patientSearchQueryError(query) == null,
        patientSearchQueryError(query) ?? 'Please check the search text.',
      );
    }
    final data = await _get(
      session,
      profile,
      'patient_search/${query == null ? 'getDyPresPatientList' : 'getDyPresPatientListBySearch'}',
      {
        if (query == null) 'p_year': '$year' else 'p_search': query,
        if (profile.value('all_presc') != '1') 'p_doc_id': profile.doctorId,
      },
      isCurrent,
    );
    rxRequire(
      data.containsKey('pat_list'),
      'The server returned an incomplete patient list.',
    );
    final rows =
        nativeArray(data['pat_list']).map(PatientSearchRow.new).toList();
    rxRequire(
      rows.every((row) => rxId(row.id)),
      'The server returned an invalid patient identifier.',
    );
    return List.unmodifiable(rows);
  }

  Future<List<DynamicPrescriptionHistoryItem>> history(
    AuthSession session,
    AccountProfile profile,
    PatientSearchRow patient, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, isCurrent);
    rxRequire(
      PatientSearchMode.forProfile(profile) ==
          PatientSearchMode.dynamicPrescription,
      'Dynamic prescription history is not available for this account.',
    );
    rxRequire(
      rxId(patient.id) && rxId(patient.historyId),
      'Select a patient before viewing prescription history.',
    );
    final data =
        await _get(session, profile, 'dynamic_presc/getPrescriptionHistory', {
          'p_ph_id': patient.historyId,
          'p_pat_id': patient.id,
          'p_doc_id': profile.value('all_presc') == '1' ? '' : profile.doctorId,
        }, isCurrent);
    final items = data['items'];
    rxRequire(items is List<Object?>, 'Prescription history data not found');
    return List.unmodifiable([
      for (final row in items as List<Object?>)
        if (row is Map<String, Object?> &&
            nativeText(row['rvm_id']).trim().isNotEmpty)
          DynamicPrescriptionHistoryItem.fromData(row),
    ]);
  }

  Future<List<PatientCalendarAppointment>> calendar(
    AuthSession session,
    AccountProfile profile,
    PatientSearchRow patient,
    PatientAppointmentWindow window, {
    required bool Function() isCurrent,
  }) async {
    rxRequire(
      rxId(patient.historyId),
      'Select a patient before viewing appointments.',
    );
    final data =
        await _get(session, profile, 'patient_search/getPatAppointment', {
          'PHID': patient.historyId,
          'FIRST_MONTH': _date(window.first),
          'LAST_MONTH': _date(window.last),
        }, isCurrent);
    final count = int.tryParse(nativeText(data['count']));
    rxRequire(
      count != null && count >= 0,
      'The server returned an invalid appointment count.',
    );
    if (count == 0) return const [];
    final rows = nativeItems(data).map(PatientCalendarAppointment.new).toList();
    rxRequire(
      rows.isNotEmpty && rows.length == count,
      'The server returned an incomplete appointment list.',
    );
    rxRequire(
      rows.every((row) => window.contains(row.date)),
      'The server returned an appointment outside the calendar.',
    );
    return List.unmodifiable(rows);
  }

  static String _date(DateTime date) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${date.day.toString().padLeft(2, '0')}-${months[date.month - 1]}-${(date.year % 100).toString().padLeft(2, '0')}';
  }
}

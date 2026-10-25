import 'dart:convert';
import 'dart:typed_data';
import '../../../../core/failure.dart';
import '../../../../core/native_json.dart';
import '../../../../core/transport.dart';
import '../../../auth/auth_models.dart';
import '../../../auth/profile_repository.dart';
import '../doctor_appointment_models.dart';
import '../doctor_appointment_repository.dart';
import '../history/doctor_appointment_history_models.dart';
import 'doctor_progress_models.dart';

class DoctorProgressRepository {
  const DoctorProgressRepository(this.appointments);
  final DoctorAppointmentRepository appointments;
  DateTime now() => appointments.now();
  void guard(
    AuthSession session,
    AccountProfile profile,
    DoctorProgressSeed seed,
    bool Function() current,
  ) {
    appointments.guard(session, profile, current);
    if (!seed.valid ||
        (seed.appointment != null && seed.ownerDoctorId != profile.doctorId)) {
      throw const AppFailure(
        'The patient or doctor for health progress is no longer valid.',
        kind: FailureKind.invalidData,
      );
    }
  }

  Future<List<JsonMap>> _items(
    AuthSession session,
    AccountProfile profile,
    DoctorProgressSeed seed,
    String endpoint,
    bool Function() current,
  ) async {
    guard(session, profile, seed, current);
    final response = await appointments.transport.get(
      apiEndpoint(session.center.baseUri, 'health_progress/$endpoint', {
        'p_ph_id': seed.patientId,
      }),
    );
    guard(session, profile, seed, current);
    final count = int.tryParse(nativeText(response['count']).trim());
    if (count == null || count < 0) {
      throw const AppFailure(
        'The server returned an invalid health progress count.',
        kind: FailureKind.invalidData,
      );
    }
    if (count == 0) return const [];
    final rows = nativeItems(response);
    if (rows.isEmpty) {
      throw const AppFailure(
        'The server returned an invalid health progress list.',
        kind: FailureKind.invalidData,
      );
    }
    return rows;
  }

  Future<List<DoctorProgressRow>> rows(
    AuthSession session,
    AccountProfile profile,
    DoctorProgressSeed seed, {
    required bool Function() isCurrent,
  }) async => List.unmodifiable(
    (await _items(
      session,
      profile,
      seed,
      'getHealthProgress',
      isCurrent,
    )).map(DoctorProgressRow.new),
  );

  Future<DoctorProgressSnapshot> load(
    AuthSession session,
    AccountProfile profile,
    DoctorProgressSeed seed, {
    required bool Function() isCurrent,
  }) async {
    // Preserve native order and all-or-nothing loading of the four APIs.
    final history = await rows(session, profile, seed, isCurrent: isCurrent);
    final choices =
        <AppointmentHistoryFilter, List<AppointmentHistoryChoice>>{};
    for (final kind in AppointmentHistoryFilter.values) {
      final endpoint = switch (kind) {
        AppointmentHistoryFilter.service => 'getService',
        AppointmentHistoryFilter.unit => 'getUnit',
        AppointmentHistoryFilter.doctor => 'getDocs',
      };
      final name = switch (kind) {
        AppointmentHistoryFilter.service => 'pfn_name',
        AppointmentHistoryFilter.unit => 'detps_name',
        AppointmentHistoryFilter.doctor => 'doc_name',
      };
      final values = await _items(session, profile, seed, endpoint, isCurrent);
      choices[kind] = [
        if (values.isNotEmpty) AppointmentHistoryChoice.clear,
        for (final row in values)
          AppointmentHistoryChoice(
            progressField(row, progressFilterId(kind)),
            progressField(row, name),
          ),
      ];
    }
    return DoctorProgressSnapshot(history, choices);
  }

  Future<DoctorProgressResult> submit(
    AuthSession session,
    AccountProfile profile,
    DoctorProgressSeed seed,
    DoctorProgressDraft draft, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, seed, isCurrent);
    if (!draft.valid) {
      throw const AppFailure(
        'Please provide progress from 1 to 10 and a progress note.',
        kind: FailureKind.invalidData,
      );
    }
    if (!seed.mayAdd(now())) return DoctorProgressResult.unavailable;
    final history = await rows(session, profile, seed, isCurrent: isCurrent);
    if (history.any((row) => row.forSchedule(seed))) {
      return DoctorProgressResult.alreadyAdded;
    }
    final selected = seed.appointment!;
    final fresh = await appointments.load(
      session,
      profile,
      DoctorAppointmentWindow(now()),
      selected.selectedDate,
      isCurrent: isCurrent,
    );
    final matches = fresh.where(
      (row) => const [
        'ad_id',
        'patient_data',
        'pat_id',
        'adm_date',
        'schedule_time',
        'pfn_id',
        'depts_id',
        'ad_prm_id',
        'ad_prd_id',
        'ph_cat_id',
      ].every((key) => row.value(key) == selected.value(key)),
    );
    if (matches.isEmpty) return DoctorProgressResult.unavailable;
    if (matches.any((row) => row.value('is_ranked') != '0')) {
      return DoctorProgressResult.alreadyAdded;
    }
    final currentSeed = DoctorProgressSeed.fromAppointment(
      matches.first,
      ownerDoctorId: profile.doctorId,
    );
    if (!currentSeed.mayAdd(now())) return DoctorProgressResult.unavailable;
    guard(session, profile, seed, isCurrent);
    final transport = appointments.transport;
    if (transport is! BinaryTransport) {
      throw const AppFailure(
        'This connection cannot send progress data.',
        kind: FailureKind.invalidData,
      );
    }
    final row = currentSeed.appointment!;
    final payload = <String, String>{
      'P_PH_ID': seed.patientId,
      'P_CAT_ID': row.value('ph_cat_id'),
      'P_DOC_ID': profile.doctorId,
      'P_DEPTS_ID': row.value('depts_id'),
      'P_PRM_ID': row.value('ad_prm_id'),
      'P_PFN_ID': row.value('pfn_id'),
      'P_PRD_ID': row.value('ad_prd_id'),
      'P_AD_ID': row.id,
      'P_PROGRESS': draft.score.toString(),
      'P_NOTES': draft.notes,
      'P_DOC_CODE': profile.value('doc_code'),
      'P_ENTRY_TIME': draft.entryTime,
    };
    // Reuse the transport's exact-byte body capability, as Retrofit @Body JSON.
    // It performs one POST, UTF-8 encoding once, and no automatic retry/logging.
    final response = await transport.postBytes(
      apiEndpoint(session.center.baseUri, 'health_progress/InsertPatProgress'),
      Uint8List.fromList(utf8.encode(jsonEncode(payload))),
      contentType: 'application/json; charset=utf-8',
    );
    guard(session, profile, seed, isCurrent);
    final status = response['string_out'];
    if (status is! String || status != 'Successfully Created') {
      throw AppFailure(
        status is String && nativeText(status).trim().isNotEmpty
            ? status
            : 'The server did not confirm the progress request.',
      );
    }
    return DoctorProgressResult.created;
  }
}

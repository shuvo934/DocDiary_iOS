import '../../../core/native_json.dart';
import '../../auth/auth_models.dart';
import '../../auth/profile_repository.dart';
import '../../patient_search/patient_view_access.dart';
import '../doctor_schedule/doctor_appointment_repository.dart';
import 'admin_appointment_models.dart';

class AdminAppointmentRepository {
  const AdminAppointmentRepository(this.appointments);
  final DoctorAppointmentRepository appointments;
  DateTime now() => appointments.now();
  void guard(
    AuthSession session,
    AccountProfile profile,
    bool Function() current,
  ) {
    guardPatientViewAccess(appointments, session, profile, current);
    if (!adminAppointmentAllowed(profile)) {
      throw const AdminAppointmentUnavailable();
    }
  }

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
            'appointmentModify/$endpoint',
            query,
          ),
        )
        .timeout(const Duration(seconds: 30));
    guard(session, profile, current);
    return result;
  }

  List<JsonMap> _rows(
    JsonMap response, {
    String field = 'items',
    bool count = true,
  }) {
    adminAppointmentRequire(
      response.containsKey(field),
      'The server returned incomplete appointment data.',
    );
    final rows = nativeArray(response[field]);
    if (count) {
      final value = int.tryParse(nativeText(response['count']));
      adminAppointmentRequire(
        value != null &&
            value >= 0 &&
            (value == 0 ? rows.isEmpty : rows.isNotEmpty),
        'The server returned an invalid appointment list.',
      );
    }
    return rows;
  }

  void _id(String value) => adminAppointmentRequire(
    adminAppointmentId(value),
    'Please reselect the appointment details.',
  );
  void selection(AdminAppointmentDraft draft, {bool service = true}) {
    _id(draft.patient?.id ?? '');
    _id(draft.doctor?.id ?? '');
    _id(draft.doctor?.value('depts_id') ?? '');
    if (service) {
      _id(draft.service?.id ?? '');
    }
  }

  Future<List<AdminAppointmentChoice>> patients(
    AuthSession session,
    AccountProfile profile, {
    required bool cancel,
    required String search,
    required bool Function() isCurrent,
  }) async {
    final searching = search.isNotEmpty;
    if (searching) {
      adminAppointmentRequire(
        adminPatientSearchError(search) == null,
        adminPatientSearchError(search) ?? 'Invalid search',
      );
    }
    final endpoint =
        cancel
            ? searching
                ? 'getPatListForCancelAppBySearch'
                : 'getFiftyPatientListForCancelAppNew'
            : searching
            ? 'getPatListForAddAppBySearch'
            : 'getFiftyPatientListForAddApp';
    final response = await _get(session, profile, endpoint, {
      if (searching) 'ph_pat': search,
      if (cancel)
        'is_admin': (profile.value('all_access_flag') == '1').toString(),
    }, isCurrent);
    return List.unmodifiable(
      _rows(
        response,
        field: searching || cancel ? 'pat_list' : 'items',
        count: false,
      ).map(AdminAppointmentChoice.patient),
    );
  }

  Future<List<AdminAppointmentChoice>> doctors(
    AuthSession session,
    AccountProfile profile,
    AdminAppointmentChoice patient, {
    required bool cancel,
    required bool Function() isCurrent,
  }) async {
    _id(patient.id);
    return List.unmodifiable(
      _rows(
        await _get(
          session,
          profile,
          cancel ? 'getDoctorListForCancel' : 'getDoctorList',
          {'ph_id': patient.id},
          isCurrent,
        ),
      ).map(AdminAppointmentChoice.doctor),
    );
  }

  Future<List<AdminAppointmentChoice>> payments(
    AuthSession session,
    AccountProfile profile,
    AdminAppointmentDraft draft, {
    required bool Function() isCurrent,
  }) async {
    selection(draft, service: false);
    return List.unmodifiable(
      _rows(
        await _get(session, profile, 'getPaymentForAddAppList', {
          'ph_id': draft.patient!.id,
          'depts_id': draft.doctor!.value('depts_id'),
        }, isCurrent),
      ).map(AdminAppointmentChoice.payment),
    );
  }

  Future<List<AdminAppointmentChoice>> services(
    AuthSession session,
    AccountProfile profile,
    AdminAppointmentDraft draft, {
    required bool Function() isCurrent,
  }) async {
    selection(draft, service: false);
    if (!draft.cancel) _id(draft.payment?.id ?? '');
    final rows = _rows(
      await _get(
        session,
        profile,
        draft.cancel ? 'getServiceForCancAppList' : 'getServiceForAddAppList',
        {
          'ph_id': draft.patient!.id,
          'depts_id': draft.doctor!.value('depts_id'),
          if (draft.cancel)
            'doc_id': draft.doctor!.id
          else
            'prm_id': draft.payment!.id,
        },
        isCurrent,
      ),
    );
    if (!draft.cancel) {
      for (final row in rows) {
        _id(nativeText(row['prd_id']));
        AdminScheduleLimit({
          'allowed_qty': row['rest'],
          'taken_service_qty': 0,
        });
      }
    }
    return List.unmodifiable(rows.map(AdminAppointmentChoice.service));
  }

  Future<AdminScheduleLimit> limit(
    AuthSession session,
    AccountProfile profile,
    AdminAppointmentDraft draft, {
    required bool Function() isCurrent,
  }) async {
    selection(draft);
    return AdminScheduleLimit(
      await _get(session, profile, 'checkSchLimitValidation', {
        'p_ph_id': draft.patient!.id,
        'p_depts_id': draft.doctor!.value('depts_id'),
        'p_pfn_id': draft.service!.id,
      }, isCurrent),
    );
  }

  Future<List<AdminCancellation>> cancellations(
    AuthSession session,
    AccountProfile profile,
    AdminAppointmentDraft draft, {
    required bool Function() isCurrent,
  }) async {
    selection(draft);
    return List.unmodifiable(
      _rows(
        await _get(session, profile, 'getAppDateTimeForCancel', {
          'ph_id': draft.patient!.id,
          'depts_id': draft.doctor!.value('depts_id'),
          'doc_id': draft.doctor!.id,
          'pfn_id': draft.service!.id,
        }, isCurrent),
      ).map(AdminCancellation.new),
    );
  }

  Future<List<AdminAppointmentDay>> days(
    AuthSession session,
    AccountProfile profile,
    AdminAppointmentDraft draft, {
    required bool Function() isCurrent,
  }) async {
    selection(draft);
    return List.unmodifiable(
      _rows(
        await _get(session, profile, 'getAppointmentDateList', {
          'doc_id': draft.doctor!.id,
        }, isCurrent),
      ).map(AdminAppointmentDay.new),
    );
  }

  Future<(List<AdminAppointmentTime>, List<String>)> times(
    AuthSession session,
    AccountProfile profile,
    AdminAppointmentDraft draft,
    AdminAppointmentDay day, {
    required bool Function() isCurrent,
  }) async {
    selection(draft);
    _id(day.id);
    _id(draft.payment?.id ?? '');
    _id(draft.service?.value('prd_id') ?? '');
    final result = await _get(session, profile, 'getTimeApiForDiffOccurance', {
      'p_adm_date': day.label,
      'p_pfn_id': draft.service!.id,
    }, isCurrent);
    final api = nativeText(result['api_name']);
    adminAppointmentRequire(
      RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(api),
      'Could Not Find Appointment Time Data. Try again',
    );
    final rows = _rows(
      await _get(session, profile, api, {
        'doc_id': draft.doctor!.id,
        'depts_id': draft.doctor!.value('depts_id'),
        'adm_id': day.id,
        'adm_date': day.label,
        'ph_id': draft.patient!.id,
        'ts_id': '',
        'am_id': '',
      }, isCurrent),
    );
    final taken = _rows(
      await _get(session, profile, 'getTakenScheduleList', {
        'P_ADM_ID': day.id,
        'P_DOC_ID': draft.doctor!.id,
        'P_DEPTS_ID': draft.doctor!.value('depts_id'),
        'P_PH_ID': draft.patient!.id,
        'P_PRM_ID': draft.payment!.id,
        'P_PFN_ID': draft.service!.id,
        'P_PRD_ID': draft.service!.value('prd_id'),
      }, isCurrent),
    );
    return (
      List<AdminAppointmentTime>.unmodifiable(
        rows.map(AdminAppointmentTime.new),
      ),
      List<String>.unmodifiable(taken.map((r) => nativeText(r['schedule']))),
    );
  }

  Future<JsonMap> _post(
    AuthSession session,
    AccountProfile profile,
    String path,
    Map<String, String> headers,
    bool Function() current,
    bool Function() ownsResponse,
  ) async {
    guard(session, profile, current);
    final result = await appointments.transport
        .post(
          apiEndpoint(session.center.baseUri, 'appointmentModify/$path'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 30));
    // An acknowledged write may finish while backgrounded. Keep its receipt in
    // this account's draft, but never start the next write until foregrounded.
    guard(session, profile, ownsResponse);
    adminAppointmentRequire(
      nativeText(result['string_out']) == 'Successfully Created',
      'The appointment could not be saved. Please try again.',
    );
    return result;
  }

  Future<bool> insert(
    AuthSession session,
    AccountProfile profile,
    AdminAppointmentDraft draft,
    AdminSchedule row, {
    required bool Function() isCurrent,
    required bool Function() ownsResponse,
  }) async {
    selection(draft);
    _id(draft.payment?.id ?? '');
    _id(draft.service?.value('prd_id') ?? '');
    _id(row.day.id);
    _id(row.time.id);
    adminAppointmentRequire(
      draft.schedules.contains(row) && !row.submitted,
      'This schedule has already been submitted.',
    );
    final result = await _post(
      session,
      profile,
      'insertAppointment',
      {
        'P_DOC_ID': draft.doctor!.id,
        'P_DEPTS_ID': draft.doctor!.value('depts_id'),
        'P_ADM_DATE': row.day.label,
        'P_TS_ID': row.time.id,
        'P_DESIG_ID': draft.doctor!.value('desig_id'),
        'P_ADM_ID': row.day.id,
        'P_PH_ID': draft.patient!.id,
        'P_PAT_CAT_ID': draft.patient!.value('ph_patient_cat_id'),
        'P_PRM_ID': draft.payment!.id,
        'P_PFN_ID': draft.service!.id,
        'P_PRD_ID': draft.service!.value('prd_id'),
        'P_USER': profile.value('usr_name'),
      },
      isCurrent,
      ownsResponse,
    );
    adminAppointmentRequire(
      result.containsKey('p_sch_msg') &&
          nativeText(result['p_sch_msg']).isNotEmpty,
      'The server returned an incomplete appointment result. Please check the appointment before trying again.',
    );
    return nativeText(result['p_sch_msg']) != 'false';
  }

  Future<void> cancel(
    AuthSession session,
    AccountProfile profile,
    AdminAppointmentDraft draft, {
    required bool Function() isCurrent,
    required bool Function() ownsResponse,
  }) async {
    selection(draft);
    final row = draft.cancellation;
    adminAppointmentRequire(
      row != null && draft.cancellations.contains(row),
      'Please Select Appointment Date',
    );
    adminAppointmentRequire(
      row!.canCancel(
        now(),
        fullAccess: profile.value('all_access_flag') == '1',
      ),
      'This appointment can no longer be cancelled as the allowed cancellation time has expired.',
    );
    await _post(
      session,
      profile,
      'updateforCancelAppoint',
      {'P_AD_ID': row.id},
      isCurrent,
      ownsResponse,
    );
  }
}

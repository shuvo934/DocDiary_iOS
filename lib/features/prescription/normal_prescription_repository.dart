import '../../core/native_dates.dart';
import '../../core/native_json.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import '../appointments/doctor_schedule/doctor_appointment_models.dart';
import '../appointments/doctor_schedule/doctor_appointment_repository.dart';
import 'normal_prescription_models.dart';

class NormalPrescriptionRepository {
  NormalPrescriptionRepository(this.appointments);
  final DoctorAppointmentRepository appointments;
  bool _writing = false;
  DateTime now() => appointments.now();
  void guard(
    AuthSession session,
    AccountProfile profile,
    NormalPrescriptionSeed seed,
    bool Function() current, {
    bool write = false,
  }) {
    appointments.guard(session, profile, current);
    rxRequire(
      seed.valid,
      'The patient for this prescription is no longer valid.',
    );
    if (write) {
      rxRequire(!seed.readOnly, 'Patient Search prescriptions are view only.');
      rxRequire(
        seed.ownerDoctorId == profile.doctorId &&
            !DoctorAppointmentFeatures(profile).dynamicPrescription,
        'Prescription editing is no longer available for this account.',
      );
    }
  }

  Future<List<JsonMap>> _get(
    AuthSession session,
    AccountProfile profile,
    NormalPrescriptionSeed seed,
    String endpoint,
    Map<String, String> query,
    bool Function() current,
  ) async {
    guard(session, profile, seed, current);
    final data = await appointments.transport.get(
      apiEndpoint(session.center.baseUri, endpoint, query),
    );
    guard(session, profile, seed, current);
    final count = int.tryParse(nativeText(data['count']));
    rxRequire(
      count != null && count >= 0,
      'The server returned an invalid prescription count.',
    );
    if (count == 0) return const [];
    final items = nativeItems(data);
    rxRequire(
      items.isNotEmpty,
      'The server returned an incomplete prescription list.',
    );
    return items;
  }

  Future<JsonMap> patient(
    AuthSession session,
    AccountProfile profile,
    NormalPrescriptionSeed seed, {
    required bool Function() isCurrent,
  }) async {
    var data = await _get(
      session,
      profile,
      seed,
      seed.readOnly
          ? 'patient_search/getPatData'
          : 'prescription/getOldPatData',
      {'p_ph_id': seed.patientId},
      isCurrent,
    );
    if (!seed.readOnly &&
        (data.isEmpty || !rxId(rxValue(data.last, 'pmm_id')))) {
      data = await _get(session, profile, seed, 'prescription/getNewPatData', {
        'p_ph_id': seed.patientId,
      }, isCurrent);
    }
    if (data.isEmpty) {
      rxRequire(
        seed.readOnly,
        'The patient details could not be found. Please reload the appointment.',
      );
      return {
        'pat_name': seed.patientName,
        'ph_sub_code': seed.patientCode,
        'pat_age': seed.age,
      };
    }
    final row = data.last;
    for (final key in ['ph_id', 'pmm_ph_id']) {
      if (rxValue(row, key).isNotEmpty) {
        rxRequire(
          rxValue(row, key) == seed.patientId,
          'The server returned a different patient. Please reload.',
        );
      }
    }
    rxRequire(
      data.map((r) => rxValue(r, 'pmm_id')).toSet().length == 1,
      'The server returned more than one prescription. Please reload.',
    );
    return {...row, if (rxValue(row, 'pat_age').isEmpty) 'pat_age': seed.age};
  }

  Future<List<JsonMap>> section(
    AuthSession session,
    AccountProfile profile,
    NormalPrescriptionSeed seed,
    RxSectionSpec spec,
    RxContext context, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, seed, isCurrent);
    final parent = context.parentId(spec);
    if (!rxId(parent)) return const [];
    final rows = await _get(
      session,
      profile,
      seed,
      'prescription/${spec.listEndpoint}',
      {spec.parentKey: parent},
      isCurrent,
    );
    final ids = <String>{};
    final parentColumn = switch (spec.section) {
      NormalPrescriptionSection.complain => 'pci_pmm_id',
      NormalPrescriptionSection.diagnosis => 'pdi_pmm_id',
      NormalPrescriptionSection.referral => 'drd_pdi_id',
      NormalPrescriptionSection.service => 'drs_drd_id',
      NormalPrescriptionSection.medicalHistory => 'pmh_pmm_id',
      NormalPrescriptionSection.drugHistory => 'pdh_pmm_id',
      NormalPrescriptionSection.clinicalFindings => 'cf_pmm_id',
      NormalPrescriptionSection.management => 'pmap_pmm_id',
      NormalPrescriptionSection.medication => 'pmp_pmm_id',
      NormalPrescriptionSection.advice => 'pa_pmm_id',
      NormalPrescriptionSection.reference => 'pref_pmm_id',
    };
    for (final row in rows) {
      rxRequire(
        rxId(rxValue(row, spec.rowId)) && ids.add(rxValue(row, spec.rowId)),
        'The server returned invalid prescription row identifiers.',
      );
      rxRequire(
        rxValue(row, parentColumn).isEmpty ||
            rxValue(row, parentColumn) == parent,
        'A prescription row belongs to a different patient or referral.',
      );
    }
    return rows;
  }

  Future<NormalPrescriptionSnapshot> load(
    AuthSession session,
    AccountProfile profile,
    NormalPrescriptionSeed seed, {
    required bool Function() isCurrent,
  }) async {
    final data = await patient(session, profile, seed, isCurrent: isCurrent);
    if (!rxId(rxValue(data, 'pmm_id'))) {
      return NormalPrescriptionSnapshot(data, {});
    }
    final specs =
        rxSectionSpecs.values.where((s) => s.parentKey == 'pmm_id').toList();
    final lists = await Future.wait(
      specs.map(
        (s) => section(
          session,
          profile,
          seed,
          s,
          RxContext(data),
          isCurrent: isCurrent,
        ),
      ),
    );
    guard(session, profile, seed, isCurrent);
    return NormalPrescriptionSnapshot(data, {
      for (var i = 0; i < specs.length; i++) specs[i].section: lists[i],
    });
  }

  Future<List<RxChoice>> choices(
    AuthSession session,
    AccountProfile profile,
    NormalPrescriptionSeed seed,
    RxSectionSpec spec,
    RxContext context,
    RxField field, {
    String departmentId = '',
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, seed, isCurrent, write: true);
    if (field.lookup.isEmpty) return const [];
    final query = switch (field.lookup) {
      'getMedTakeTime' ||
      'getDoses' ||
      'getManagementPlan' ||
      'getAdvice' ||
      'getReference' => <String, String>{},
      'getReferralUnit' => {'pdi_id': context.parentId(spec)},
      'getReferralDoctor' => {'depts_id': departmentId},
      'getServices' => {
        'drd_id': context.parentId(spec),
        'depts_id': rxValue(context.referral ?? {}, 'depts_id'),
      },
      _ => {'pmm_id': context.masterId},
    };
    if (field.lookup == 'getReferralDoctor' && !rxId(departmentId)) {
      return const [];
    }
    final rows = await _get(
      session,
      profile,
      seed,
      'prescription/${field.lookup}',
      query,
      isCurrent,
    );
    final result = <RxChoice>[];
    final ids = <String>{};
    for (final r in rows) {
      final name = rxValue(r, field.nameKey),
          id =
              field.isChoice
                  ? rxValue(r, field.idKey)
                  : rxValue(r, field.nameKey);
      if (name.isNotEmpty && (!field.isChoice || rxId(id)) && ids.add(id)) {
        final note = [
          if (field.lookup == 'getReferralDoctor') rxValue(r, 'doc_code'),
          rxValue(r, field.noteKey),
        ].where((part) => part.isNotEmpty).join(' · ');
        result.add(RxChoice(id, name, note));
      }
    }
    return result;
  }

  Future<JsonMap> _post(
    AuthSession session,
    AccountProfile profile,
    NormalPrescriptionSeed seed,
    String endpoint,
    Map<String, String> headers,
    bool Function() current,
  ) async {
    guard(session, profile, seed, current, write: true);
    final response = await appointments.transport.post(
      apiEndpoint(session.center.baseUri, 'prescription/$endpoint'),
      headers: headers,
    );
    guard(session, profile, seed, current, write: true);
    rxRequire(
      response['string_out'] == 'Successfully Created',
      'The server did not confirm this prescription change. Reload to check its saved state.',
    );
    return response;
  }

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    rxRequire(!_writing, 'A prescription change is already in progress.');
    _writing = true;
    try {
      return await action();
    } finally {
      _writing = false;
    }
  }

  Future<void> create(
    AuthSession session,
    AccountProfile profile,
    NormalPrescriptionSeed seed, {
    required bool Function() isCurrent,
  }) => _exclusive(() async {
    guard(session, profile, seed, isCurrent, write: true);
    final data = await patient(session, profile, seed, isCurrent: isCurrent);
    if (rxId(rxValue(data, 'pmm_id'))) return;
    final category = rxValue(data, 'pat_category_id');
    rxRequire(
      rxId(category),
      'The patient category was not returned. Please reload.',
    );
    final response = await _post(
      session,
      profile,
      seed,
      'insertNewPrescription',
      {
        'P_PH_ID': seed.patientId,
        'P_CAT_ID': category,
        'P_USER': profile.doctorId,
      },
      isCurrent,
    );
    rxRequire(
      rxId(rxValue(response, 'out_pmm_id')),
      'The server did not return the created prescription identifier. Reload to check.',
    );
  });
  Future<RxContext> _freshContext(
    AuthSession session,
    AccountProfile profile,
    NormalPrescriptionSeed seed,
    RxContext context,
    bool Function() current,
  ) async {
    final data = await patient(session, profile, seed, isCurrent: current);
    rxRequire(
      rxId(context.masterId) && rxValue(data, 'pmm_id') == context.masterId,
      'This prescription has changed. Please reload before editing.',
    );
    var fresh = RxContext(data);
    if (context.diagnosis != null) {
      final rows = await section(
        session,
        profile,
        seed,
        rxSectionSpecs[NormalPrescriptionSection.diagnosis]!,
        fresh,
        isCurrent: current,
      );
      final matches = rows.where(
        (r) => rxValue(r, 'pdi_id') == rxValue(context.diagnosis!, 'pdi_id'),
      );
      rxRequire(
        matches.length == 1,
        'The selected diagnosis is no longer available. Please reload.',
      );
      fresh = RxContext(data, diagnosis: matches.single);
    }
    if (context.referral != null) {
      rxRequire(fresh.diagnosis != null, 'Please select the diagnosis again.');
      final rows = await section(
        session,
        profile,
        seed,
        rxSectionSpecs[NormalPrescriptionSection.referral]!,
        fresh,
        isCurrent: current,
      );
      final matches = rows.where(
        (r) => rxValue(r, 'drd_id') == rxValue(context.referral!, 'drd_id'),
      );
      rxRequire(
        matches.length == 1,
        'The selected referral is no longer available. Please reload.',
      );
      fresh = RxContext(
        data,
        diagnosis: fresh.diagnosis,
        referral: matches.single,
      );
    }
    return fresh;
  }

  Future<void> save(
    AuthSession session,
    AccountProfile profile,
    NormalPrescriptionSeed seed,
    RxSectionSpec spec,
    RxContext context,
    Map<String, String> values, {
    JsonMap? existing,
    bool deleting = false,
    required bool Function() isCurrent,
  }) => _exclusive(() async {
    guard(session, profile, seed, isCurrent, write: true);
    rxRequire(
      !deleting || existing != null,
      'Select the prescription data to delete.',
    );
    if (!deleting) {
      final error = rxDraftError(spec, values);
      rxRequire(error == null, error ?? 'Please check the prescription data.');
      for (final f in spec.fields.where((f) => f.isDate)) {
        rxRequire(
          !parseOracleDate(values[f.header]!).isAfter(dateOnly(now())),
          'Injury date cannot be in the future.',
        );
      }
    }
    final fresh = await _freshContext(
      session,
      profile,
      seed,
      context,
      isCurrent,
    );
    rxRequire(
      rxId(fresh.parentId(spec)),
      'Please select the diagnosis or referral again.',
    );
    final rows = await section(
      session,
      profile,
      seed,
      spec,
      fresh,
      isCurrent: isCurrent,
    );
    if (existing != null) {
      final matches = rows.where(
        (r) => rxValue(r, spec.rowId) == rxValue(existing, spec.rowId),
      );
      rxRequire(
        matches.length == 1,
        'This prescription entry is no longer available. Please reload.',
      );
      rxRequire(
        rxMayModify(spec, matches.single),
        'Remove the child services or referrals before changing this entry.',
      );
      rxRequire(
        spec.fields.every(
          (f) =>
              rxValue(matches.single, f.rowKey) == rxValue(existing, f.rowKey),
        ),
        'This prescription entry was changed. Please reload before editing.',
      );
    } else if (rows.any(
      (r) => spec.fields.every(
        (f) => rxValue(r, f.rowKey) == (values[f.header] ?? ''),
      ),
    )) {
      return;
    }
    await _post(
      session,
      profile,
      seed,
      deleting
          ? spec.deleteEndpoint
          : existing == null
          ? spec.insertEndpoint
          : spec.updateEndpoint,
      spec.headers(values, fresh, existing: existing, deleting: deleting),
      isCurrent,
    );
  });
  Future<void> admission(
    AuthSession session,
    AccountProfile profile,
    NormalPrescriptionSeed seed,
    RxContext context,
    bool allowed, {
    required bool Function() isCurrent,
  }) => _exclusive(() async {
    guard(session, profile, seed, isCurrent, write: true);
    final fresh = await _freshContext(
          session,
          profile,
          seed,
          context,
          isCurrent,
        ),
        flag = allowed ? '1' : '0';
    if (rxValue(fresh.master, 'pmm_admission_flag') == flag) return;
    await _post(session, profile, seed, 'updatePatAdmFlag', {
      'P_FLAG': flag,
      'P_PMM_ID': fresh.masterId,
    }, isCurrent);
  });
  Future<List<JsonMap>> patients(
    AuthSession session,
    AccountProfile profile,
    int year, {
    required bool Function() isCurrent,
  }) async {
    appointments.guard(session, profile, isCurrent);
    rxRequire(
      year >= 1950 && year <= now().year,
      'Please select a valid year.',
    );
    final all = profile.value('all_presc') == '1';
    final query = <String, String>{
      'p_year': '$year',
      if (!all) ...{
        'p_doc_id':
            profile.value('doc_head_flag') == '1' ? '' : profile.doctorId,
        'p_deptd_id': profile.value('deptd_id'),
      },
    };
    if (!all) {
      rxRequire(
        rxId(profile.value('deptd_id')),
        'The doctor department was not returned. Please reload.',
      );
    }
    final data = await appointments.transport.get(
      apiEndpoint(
        session.center.baseUri,
        'patient_search/${all ? 'getPatientList' : 'getPatientListNew'}',
        query,
      ),
    );
    appointments.guard(session, profile, isCurrent);
    rxRequire(
      data.containsKey('pat_list'),
      'The server returned an incomplete patient list.',
    );
    final rows = nativeArray(data['pat_list']);
    rxRequire(
      rows.every((r) => rxId(rxValue(r, 'ph_id'))),
      'The server returned an invalid patient identifier.',
    );
    return rows;
  }
}

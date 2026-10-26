import '../../core/native_json.dart';
import '../../core/failure.dart';
import '../appointments/doctor_schedule/doctor_appointment_models.dart';

enum NormalPrescriptionSection {
  complain,
  medicalHistory,
  drugHistory,
  clinicalFindings,
  diagnosis,
  referral,
  service,
  management,
  medication,
  advice,
  reference,
}

String rxValue(JsonMap data, String key) => nativeText(data[key]);
bool rxId(String value) =>
    RegExp(r'^[0-9]+$').hasMatch(value) && BigInt.parse(value) > BigInt.zero;

/// The entry point controls write capability; PatientSearch always constructs view mode.
class NormalPrescriptionSeed {
  const NormalPrescriptionSeed._(
    this.patientId,
    this.patientName,
    this.patientCode,
    this.age,
    this.appointment,
    this.ownerDoctorId,
  );
  factory NormalPrescriptionSeed.appointment(
    DoctorAppointmentRow row, {
    required String ownerDoctorId,
  }) => NormalPrescriptionSeed._(
    row.value('patient_data'),
    row.value('pat_name'),
    row.value('pat_code'),
    row.value('pat_age_now'),
    row,
    ownerDoctorId,
  );
  factory NormalPrescriptionSeed.patient(JsonMap row) =>
      NormalPrescriptionSeed._(
        rxValue(row, 'ph_id'),
        rxValue(row, 'pat_name'),
        rxValue(row, 'sub_code'),
        rxValue(row, 'pat_age'),
        null,
        '',
      );
  final String patientId, patientName, patientCode, age, ownerDoctorId;
  final DoctorAppointmentRow? appointment;
  bool get readOnly => appointment == null;
  bool get valid =>
      rxId(patientId) &&
      (readOnly ||
          (ownerDoctorId.isNotEmpty &&
              appointment!.booked &&
              appointment!.startsAt != null));
}

class RxField {
  const RxField(
    this.header,
    this.rowKey,
    this.label, {
    this.required = true,
    this.lookup = '',
    this.idKey = '',
    this.nameKey = '',
    this.noteKey = '',
  });
  final String header, rowKey, label, lookup, idKey, nameKey, noteKey;
  final bool required;
  bool get isChoice => idKey.isNotEmpty;
  bool get isDate => header == 'P_INJURY_DATE';
  bool get numeric => header == 'P_QTY';
  String display(JsonMap row) => rxValue(row, isChoice ? nameKey : rowKey);
}

class RxSectionSpec {
  const RxSectionSpec(
    this.section,
    this.label,
    this.listEndpoint,
    this.rowId,
    this.insertEndpoint,
    this.updateEndpoint,
    this.deleteEndpoint,
    this.fields,
  );
  final NormalPrescriptionSection section;
  final String label,
      listEndpoint,
      rowId,
      insertEndpoint,
      updateEndpoint,
      deleteEndpoint;
  final List<RxField> fields;
  String get parentKey => switch (section) {
    NormalPrescriptionSection.referral => 'pdi_id',
    NormalPrescriptionSection.service => 'drd_id',
    _ => 'pmm_id',
  };
  Map<String, String> values(JsonMap row) => {
    for (final field in fields) field.header: rxValue(row, field.rowKey),
  };
  Map<String, String> headers(
    Map<String, String> values,
    RxContext context, {
    JsonMap? existing,
    bool deleting = false,
  }) {
    if (deleting) {
      return {'P_${rowId.toUpperCase()}': rxValue(existing!, rowId)};
    }
    final result = <String, String>{
      'P_${parentKey.toUpperCase()}': context.parentId(this),
      for (final field in fields) field.header: values[field.header] ?? '',
    };
    if (existing != null) {
      result['P_${rowId.toUpperCase()}'] = rxValue(existing, rowId);
    }
    if (section == NormalPrescriptionSection.complain && existing != null) {
      result['P_DATE'] = result.remove('P_INJURY_DATE')!;
    }
    return result;
  }
}

class RxContext {
  const RxContext(this.master, {this.diagnosis, this.referral});
  final JsonMap master;
  final JsonMap? diagnosis, referral;
  String get masterId => rxValue(master, 'pmm_id');
  String parentId(RxSectionSpec spec) => switch (spec.parentKey) {
    'pdi_id' => diagnosis == null ? '' : rxValue(diagnosis!, 'pdi_id'),
    'drd_id' => referral == null ? '' : rxValue(referral!, 'drd_id'),
    _ => masterId,
  };
}

class NormalPrescriptionSnapshot {
  NormalPrescriptionSnapshot(
    JsonMap patient,
    Map<NormalPrescriptionSection, List<JsonMap>> rows,
  ) : patient = Map.unmodifiable(patient),
      rows = Map.unmodifiable({
        for (final item in rows.entries)
          item.key: List<JsonMap>.unmodifiable(
            item.value.map((r) => Map<String, Object?>.unmodifiable(r)),
          ),
      });
  final JsonMap patient;
  final Map<NormalPrescriptionSection, List<JsonMap>> rows;
  bool get exists => rxId(rxValue(patient, 'pmm_id'));
}

class RxChoice {
  const RxChoice(this.id, this.name, [this.note = '']);
  final String id, name, note;
  String get description => note.isEmpty ? name : '$name — $note';
}

String? rxDraftError(RxSectionSpec spec, Map<String, String> values) {
  for (final field in spec.fields) {
    final value = (values[field.header] ?? '').trim();
    if (field.required && value.isEmpty) {
      return 'Please provide ${field.label}.';
    }
    if (field.isChoice && value.isNotEmpty && !rxId(value)) {
      return 'Please select ${field.label} from the list.';
    }
    if (value.contains('\r') || value.contains('\n')) {
      return '${field.label} must be on one line for this server.';
    }
    if (value.codeUnits.any((c) => c > 255)) {
      return '${field.label} contains characters this prescription server cannot receive.';
    }
    if (field.numeric &&
        value.isNotEmpty &&
        (num.tryParse(value) == null ||
            num.parse(value) < 0 ||
            !num.parse(value).isFinite)) {
      return 'Please provide a valid quantity.';
    }
  }
  return null;
}

void rxRequire(bool valid, String message) {
  if (!valid) throw AppFailure(message, kind: FailureKind.invalidData);
}

const rxSectionSpecs = <NormalPrescriptionSection, RxSectionSpec>{
  NormalPrescriptionSection.complain: RxSectionSpec(
    NormalPrescriptionSection.complain,
    'Complain / Injury',
    'getComplainData',
    'pci_id',
    'insertComplain',
    'updateComplain',
    'deleteComplain',
    [
      RxField(
        'P_CM_ID',
        'cm_id',
        'Complain',
        required: true,
        lookup: 'getComplain',
        idKey: 'cm_id',
        nameKey: 'cm_name',
        noteKey: 'cm_notes',
      ),
      RxField(
        'P_INJURY_ID',
        'injury_id',
        'Cause of Injury',
        required: true,
        lookup: 'getInjury',
        idKey: 'injury_id',
        nameKey: 'injury_name',
        noteKey: 'injury_notes',
      ),
      RxField(
        'P_INJURY_DATE',
        'pci_date',
        'Injury Date',
        required: true,
        lookup: '',
        idKey: '',
        nameKey: '',
        noteKey: '',
      ),
    ],
  ),
  NormalPrescriptionSection.medicalHistory: RxSectionSpec(
    NormalPrescriptionSection.medicalHistory,
    'Medical History',
    'getPatMedicalHist',
    'pmh_id',
    'insertMedicalHistory',
    'updateMedicalHistory',
    'deleteMedicalHistory',
    [
      RxField(
        'P_MHM_ID',
        'mhm_id',
        'Medical History',
        required: true,
        lookup: 'getMedHistory',
        idKey: 'mhm_id',
        nameKey: 'mhm_name',
        noteKey: 'mhm_details',
      ),
      RxField(
        'P_DETAILS',
        'pmh_details',
        'Details',
        required: false,
        lookup: '',
        idKey: '',
        nameKey: '',
        noteKey: '',
      ),
    ],
  ),
  NormalPrescriptionSection.drugHistory: RxSectionSpec(
    NormalPrescriptionSection.drugHistory,
    'Drug History',
    'getPatDrugHist',
    'pdh_id',
    'insertDrugHistory',
    'updateDrugHistory',
    'deleteDrugHistory',
    [
      RxField(
        'P_MEDICINE_ID',
        'medicine_id',
        'Drug',
        required: true,
        lookup: 'getDrugNames',
        idKey: 'medicine_id',
        nameKey: 'medicine_name',
        noteKey: '',
      ),
      RxField(
        'P_DETAILS',
        'pdh_details',
        'Details',
        required: false,
        lookup: '',
        idKey: '',
        nameKey: '',
        noteKey: '',
      ),
    ],
  ),
  NormalPrescriptionSection.clinicalFindings: RxSectionSpec(
    NormalPrescriptionSection.clinicalFindings,
    'Clinical Findings',
    'getPatClFindings',
    'cf_id',
    'insertClinicalFindings',
    'updateClinicalFindings',
    'deleteClinicalFindings',
    [
      RxField(
        'P_CFM_ID',
        'cfm_id',
        'Clinical Finding',
        required: true,
        lookup: 'getClinicalFindings',
        idKey: 'cfm_id',
        nameKey: 'cfm_name',
        noteKey: 'cfm_details',
      ),
      RxField(
        'P_DETAILS',
        'cf_details',
        'Details',
        required: false,
        lookup: '',
        idKey: '',
        nameKey: '',
        noteKey: '',
      ),
    ],
  ),
  NormalPrescriptionSection.diagnosis: RxSectionSpec(
    NormalPrescriptionSection.diagnosis,
    'Diagnosis',
    'getPatDiagnosis',
    'pdi_id',
    'insertDiagnosis',
    'updateDiagnosis',
    'deleteDiagnosis',
    [
      RxField(
        'P_DM_ID',
        'dm_id',
        'Diagnosis',
        required: true,
        lookup: 'getDiagnosisList',
        idKey: 'dm_id',
        nameKey: 'dm_name',
        noteKey: 'dm_notes',
      ),
    ],
  ),
  NormalPrescriptionSection.referral: RxSectionSpec(
    NormalPrescriptionSection.referral,
    'Referral Unit',
    'getPatReferral',
    'drd_id',
    'insertReferralUnit',
    'updateReferralUnit',
    'deleteReferralUnit',
    [
      RxField(
        'P_DEPTS_ID',
        'depts_id',
        'Referral Unit',
        required: true,
        lookup: 'getReferralUnit',
        idKey: 'depts_id',
        nameKey: 'depts_name',
        noteKey: 'depts_desc',
      ),
      RxField(
        'P_DOC_ID',
        'doc_id',
        'Referral Doctor',
        required: false,
        lookup: 'getReferralDoctor',
        idKey: 'doc_id',
        nameKey: 'doc_name',
        noteKey: 'desig_name',
      ),
    ],
  ),
  NormalPrescriptionSection.service: RxSectionSpec(
    NormalPrescriptionSection.service,
    'Service',
    'getPatRefService',
    'drs_id',
    'insertRefService',
    'updateRefService',
    'deleteRefService',
    [
      RxField(
        'P_PFN_ID',
        'pfn_id',
        'Service',
        required: true,
        lookup: 'getServices',
        idKey: 'pfn_id',
        nameKey: 'pfn_fee_name',
        noteKey: '',
      ),
      RxField(
        'P_QTY',
        'drs_qty',
        'Quantity',
        required: false,
        lookup: '',
        idKey: '',
        nameKey: '',
        noteKey: '',
      ),
    ],
  ),
  NormalPrescriptionSection.management: RxSectionSpec(
    NormalPrescriptionSection.management,
    'Management',
    'getPatManagementPlan',
    'pmap_id',
    'insertManagement',
    'updateManagement',
    'deleteManagement',
    [
      RxField(
        'P_DETAILS',
        'pmap_details',
        'Management Plan',
        required: true,
        lookup: 'getManagementPlan',
        idKey: '',
        nameKey: 'pmap_details',
        noteKey: '',
      ),
    ],
  ),
  NormalPrescriptionSection.medication: RxSectionSpec(
    NormalPrescriptionSection.medication,
    'Medication',
    'getPatMedication',
    'pmp_id',
    'insertMedication',
    'updateMedication',
    'deleteMedication',
    [
      RxField(
        'P_MEDICINE_ID',
        'medicine_id',
        'Medicine',
        required: true,
        lookup: 'getMedicines',
        idKey: 'medicine_id',
        nameKey: 'medicine_name',
        noteKey: '',
      ),
      RxField(
        'P_MPM_ID',
        'mpm_id',
        'Taking Time',
        required: true,
        lookup: 'getMedTakeTime',
        idKey: 'mpm_id',
        nameKey: 'mpm_name',
        noteKey: '',
      ),
      RxField(
        'P_DOSE_ID',
        'dose_id',
        'Dose',
        required: true,
        lookup: 'getDoses',
        idKey: 'dose_id',
        nameKey: 'dose_name',
        noteKey: '',
      ),
      RxField(
        'P_DURATION',
        'pmp_duration',
        'Duration',
        required: false,
        lookup: '',
        idKey: '',
        nameKey: '',
        noteKey: '',
      ),
    ],
  ),
  NormalPrescriptionSection.advice: RxSectionSpec(
    NormalPrescriptionSection.advice,
    'Advice',
    'getPatAdvice',
    'pa_id',
    'insertAdvice',
    'updateAdvice',
    'deleteAdvice',
    [
      RxField(
        'P_PA_NAME',
        'pa_name',
        'Advice',
        required: true,
        lookup: 'getAdvice',
        idKey: '',
        nameKey: 'pa_name',
        noteKey: '',
      ),
    ],
  ),
  NormalPrescriptionSection.reference: RxSectionSpec(
    NormalPrescriptionSection.reference,
    'Reference',
    'getPatReference',
    'pref_id',
    'insertReference',
    'updateReference',
    'deleteReference',
    [
      RxField(
        'P_PREF_NAME',
        'pref_name',
        'Reference',
        required: true,
        lookup: 'getReference',
        idKey: '',
        nameKey: 'pref_name',
        noteKey: '',
      ),
    ],
  ),
};

bool rxMayModify(RxSectionSpec spec, JsonMap row) =>
    !const [
      NormalPrescriptionSection.diagnosis,
      NormalPrescriptionSection.referral,
    ].contains(spec.section) ||
    rxValue(row, 'child_count') == '0';

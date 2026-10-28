import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_patient_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_seed.dart';

List<JsonMap> walkInRows() => [
  {
    'pat_id': '101',
    'ph_id': '201',
    'pat_name': 'Walk-in Patient One',
    'sub_code': 'P-101',
    'dd_thana_name': 'Mirpur',
    'pyear': '2026',
    'pat_cell': '01000000001',
    'gender': 'Female',
    'pat_age': '35 Years',
  },
  {
    'pat_id': '102',
    'ph_id': '202',
    'pat_name': 'Walk-in Patient Two',
    'sub_code': 'P-102',
    'dd_thana_name': 'Savar',
    'pyear': '2025',
    'pat_cell': '01000000002',
    'gender': 'Male',
    'pat_age': '40 Years',
  },
  {
    'pat_id': '101',
    'ph_id': '203',
    'pat_name': 'Another registration',
    'sub_code': 'P-101-2',
    'gender': 'Female',
    'pat_age': '35 Years',
  },
];
List<DynamicPatientItem> walkInPatients() =>
    walkInRows().map(DynamicPatientItem.fromData).toList();
DynamicPrescriptionSeed selectedWalkInSeed({String prescriptionType = '2'}) =>
    DynamicPrescriptionSeed.fromExtras(
      {'P_PAT_TYPE': '2', 'IS_CREATED': '0'},
      ownerDoctorId: '10',
      now: DateTime(2026, 10, 24),
    ).withPatient(
      patientId: '101',
      patientHistoryId: '201',
      name: 'Walk-in Patient One',
      code: 'P-101',
      gender: 'Female',
      age: '35 Years',
      prescriptionType: prescriptionType,
    );

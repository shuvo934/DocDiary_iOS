import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/prescription/normal_prescription_models.dart';
import 'package:docdiary_ios/features/prescription/normal_prescription_repository.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/doctor_appointment_models.dart';
import 'doctor_appointment_test_support.dart';

JsonMap rxPatient({bool exists = true}) => {
  'ph_id': '11',
  'pat_name': 'Sample Patient',
  'ph_sub_code': 'P-11',
  'pat_age': '35 Years',
  'gender': 'Female',
  'marital_status': 'Married',
  'pat_blood': 'A+',
  'pat_category_name': 'General',
  'pat_category_id': '4',
  'ph_patient_status': 'Active',
  'address': 'Dhaka',
  if (exists) ...{
    'pmm_id': '90',
    'pmm_code': 'MDT-90',
    'pmm_date': '24-OCT-26',
    'pmm_admission_flag': '0',
  },
};
JsonMap rxEntry(NormalPrescriptionSection kind) {
  final spec = rxSectionSpecs[kind]!;
  return {
    spec.rowId: '${700 + kind.index}',
    'child_count': '0',
    for (final f in spec.fields) ...{
      f.rowKey:
          f.isChoice
              ? '${100 + spec.fields.indexOf(f)}'
              : f.isDate
              ? '20-OCT-26'
              : f.numeric
              ? '4'
              : f.header == 'P_DURATION'
              ? '7 days'
              : 'Sample ${f.label}',
      if (f.isChoice) f.nameKey: 'Example ${f.label}',
    },
  };
}

class NormalRxHarness extends DoctorAppointmentHarness {
  NormalRxHarness() {
    doctorData.addAll({
      'presc_active': '0',
      'can_prescribe': '0',
      'all_presc': '0',
      'doc_head_flag': '0',
      'deptd_id': '8',
    });
    for (final kind in NormalPrescriptionSection.values) {
      entries[kind] = [rxEntry(kind)];
    }
    transport.onGet = respondRx;
    transport.onPost = postRx;
  }
  bool created = true;
  final entries = <NormalPrescriptionSection, List<JsonMap>>{};
  List<JsonMap> patientRows = [
    {
      'ph_id': '11',
      'pat_id': '21',
      'pat_name': 'Sample Patient',
      'sub_code': 'P-11',
      'pat_age': '35 Years',
      'gender': 'Female',
      'dd_thana_name': 'Dhaka',
    },
  ];
  NormalPrescriptionRepository get rx =>
      NormalPrescriptionRepository(appointments);
  NormalPrescriptionSeed get editSeed => NormalPrescriptionSeed.appointment(
    DoctorAppointmentRow(doctorAppointmentRow(), selectedDate: now),
    ownerDoctorId: '10',
  );
  NormalPrescriptionSeed get viewSeed =>
      NormalPrescriptionSeed.patient(patientRows.first);
  Future<JsonMap> respondRx(Uri uri) async {
    final endpoint = uri.pathSegments.last;
    if (uri.path.contains('/patient_search/') &&
        endpoint.contains('getPatientList')) {
      return {'pat_list': patientRows};
    }
    if (['getOldPatData', 'getPatData'].contains(endpoint)) {
      return {
        'count': created ? 1 : 0,
        'items': created ? [rxPatient()] : [],
      };
    }
    if (endpoint == 'getNewPatData') {
      return {
        'count': 1,
        'items': [rxPatient(exists: false)],
      };
    }
    for (final spec in rxSectionSpecs.values) {
      if (endpoint == spec.listEndpoint) {
        final rows = entries[spec.section]!;
        return {'count': rows.length, 'items': rows};
      }
      for (final field in spec.fields) {
        if (endpoint == field.lookup) {
          final row = {
            if (field.isChoice) field.idKey: '201',
            field.nameKey: 'New ${field.label}',
            if (field.noteKey.isNotEmpty) field.noteKey: 'Example note',
          };
          return {
            'count': 1,
            'items': [row],
          };
        }
      }
    }
    return respondAppointments(uri);
  }

  Future<JsonMap> postRx(Uri uri, Map<String, String> headers) async {
    final endpoint = uri.pathSegments.last;
    if (endpoint == 'insertNewPrescription') {
      created = true;
      return {
        'string_out': 'Successfully Created',
        'out_pmm_id': '90',
        'out_pmm_code': 'MDT-90',
      };
    }
    for (final spec in rxSectionSpecs.values) {
      if ([
        spec.insertEndpoint,
        spec.updateEndpoint,
        spec.deleteEndpoint,
      ].contains(endpoint)) {
        if (endpoint != spec.insertEndpoint) {
          entries[spec.section]!.removeWhere(
            (r) =>
                rxValue(r, spec.rowId) ==
                headers['P_${spec.rowId.toUpperCase()}'],
          );
        }
        if (endpoint != spec.deleteEndpoint) {
          entries[spec.section]!.add({
            ...rxEntry(spec.section),
            if (endpoint == spec.insertEndpoint)
              spec.rowId: '${900 + spec.section.index}',

            for (final field in spec.fields)
              field.rowKey:
                  headers[field.isDate && endpoint == spec.updateEndpoint
                      ? 'P_DATE'
                      : field.header] ??
                  '',
          });
        }
      }
    }
    return {'string_out': 'Successfully Created'};
  }
}

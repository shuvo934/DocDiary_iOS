import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_history_models.dart';
import 'dynamic_template_test_support.dart';

JsonMap historyRow({String id = '600', String code = '2600107'}) => {
  'rvm_id': id,
  'rvm_code': code,
  'presc_date': '23-SEP-26',
  'depts_name': 'Adult Outpatient Unit',
  'rvm_doc_id': '20',
  'doc_name': 'Sample Clinician',
  'desig_name': 'Clinical Therapist',
  'presc_type': 'Indoor',
  'pat_type': 'Walk-in',
};
List<JsonMap> historyRows() => [
  historyRow(),
  {
    ...historyRow(id: '599', code: '2600099'),
    'presc_date': '20-SEP-26',
    'depts_name': 'Communication Group',
    'pfn_fee_name': 'Physiotherapy Service charge',
    'app_date': '20-SEP-26',
    'sch_time': '10:00 AM',
    'doc_name': 'Another Clinician',
    'desig_name': 'Head of Therapy Department',
    'presc_type': 'Outdoor',
    'pat_type': 'No Data Found',
    'last_updated_time': '20-SEP-26, 03:30 PM',
  },
  historyRow(id: '598', code: '2600098'),
];
List<DynamicPrescriptionHistoryItem> historyItems() =>
    historyRows().map(DynamicPrescriptionHistoryItem.fromData).toList();
JsonMap previousPrescriptionData({String id = '600'}) => {
  ...diseaseTemplateData(),
  ...treatmentTemplateData(),
  'rvm_id': id,
  'rvm_code': '2600107',
  'rvm_doc_id': '20',
  'pat_id': '999',
  'ph_id': '998',
  'rvm_ad_id': '997',
  'td_id': '123',
  'td_name': 'Source disease',
  'tt_id': '456',
  'tt_name': 'Source treatment',
  'vitals': {'weight': '66', 'height': '166', 'pulse': '74'},
  'reference': 'Previous reference',
  'notes': 'Previous notes',
};

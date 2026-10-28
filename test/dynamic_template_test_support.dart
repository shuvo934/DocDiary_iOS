import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_template_models.dart';

const diseaseTemplates = [
  DynamicTemplateOption(
    '701',
    'Occupational Template',
    'Upper limb rehabilitation',
  ),
  DynamicTemplateOption(
    '702',
    'Physiotherapy Template',
    'Mobility and balance',
  ),
];
const treatmentTemplates = [
  DynamicTemplateOption(
    '801',
    'Exercise Plan',
    'Range of motion and strengthening',
  ),
  DynamicTemplateOption('802', 'Therapy Plan'),
];
JsonMap diseaseTemplateData() => {
  'complaints': [
    {'cm_id': 2, 'name': 'Template complain'},
  ],
  'injuries': [
    {'injury_id': 4, 'name': 'Template injury'},
  ],
  'diagnosis': [
    {'dm_id': 5, 'name': 'Template diagnosis'},
  ],
  'clinical_findings': [
    {'cfm_id': 6, 'name': 'Template finding'},
  ],
  'drug_history': [
    {'medicine_id': 7, 'name': 'Template drug'},
  ],
  'investigations': [
    {
      'pfn_id': 8,
      'name': 'Template test',
      'notes': 'Template investigation notes',
    },
  ],
  'important_info': [
    {'text': 'Template important info'},
  ],
  'objective_info': [
    {
      'om_id': 10,
      'om_name': 'ROM',
      'mjl_id': 30,
      'mjl_name': 'Knee',
      'notes': 'Template objective notes',
    },
  ],
  'advice': [
    {'text': 'Template advice'},
  ],
  'followups': [
    {'dfi_id': 501, 'text': 'Template follow-up'},
  ],
  'special_alerts': [
    {'dsai_id': 601, 'text': 'Template alert'},
  ],
};
JsonMap treatmentTemplateData() => {
  'medications': [
    {
      'medication_id': 100,
      'medicine_name': 'Sample medicine',
      'dose_id': 2,
      'dose_name': '0+0+1',
      'timing_id': 2,
      'timing_name': 'After meal',
      'route_id': 11,
      'route_name': 'Oral',
      'duration': '',
      'notes': 'Template medicine notes',
    },
  ],
  'therapies': [
    {
      'tm_id': 200,
      'name': 'Template therapy',
      'notes': 'Template therapy notes',
    },
  ],
  'treatment_plans': [
    {'tpm_id': 300, 'name': 'Template treatment plan'},
  ],
};

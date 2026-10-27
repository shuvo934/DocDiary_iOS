import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_clinical_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_rx_models.dart';

DynamicRxCatalogue rxCatalogue() => DynamicRxCatalogue(
  medicines: const [
    DynamicRxOption('100', 'Sample medicine'),
    DynamicRxOption('101', 'Another medicine'),
  ],
  doses: const [DynamicRxOption('2', '0+0+1'), DynamicRxOption('3', '1+0+1')],
  timings: const [
    DynamicRxOption('2', 'After meals [PC ]'),
    DynamicRxOption('3', 'Before meals [AC ]'),
  ],
  routes: const [
    DynamicRxOption('11', 'By mouth (oral) [PO ]'),
    DynamicRxOption('12', 'Topical'),
  ],
  therapies: const [
    DynamicRxOption('200', 'Sample therapy'),
    DynamicRxOption('201', 'Another therapy'),
  ],
  treatmentPlans: const [
    DynamicRxOption('300', 'Continue treatment'),
    DynamicRxOption('301', 'Review response'),
  ],
);

DynamicMedicineEntry rxMedicine({
  String? localId,
  String id = '100',
  String name = 'Sample medicine',
  String duration = '',
  String notes = '',
}) {
  final c = rxCatalogue();
  return DynamicMedicineEntry(
    localId: localId,
    medicine: DynamicRxOption(id, name),
    dose: c.doses.first,
    timing: c.timings.first,
    route: c.routes.first,
    duration: duration,
    notes: notes,
  );
}

JsonMap rxExistingData() => {
  'medications': [
    {
      'medication_id': 100,
      'medicine_name': 'Sample medicine',
      'dose_id': 2,
      'dose_name': '0+0+1',
      'timing_id': 2,
      'timing_name': 'After meals [PC ]',
      'route_id': 11,
      'route_name': 'By mouth (oral) [PO ]',
      'duration': '7',
      'notes': 'Saved notes',
    },
  ],
  'therapies': [
    {'tm_id': 200, 'name': 'Sample therapy', 'notes': 'থেরাপির নোট'},
  ],
  'treatment_plans': [
    {'tpm_id': 300, 'name': 'Continue treatment with edited text'},
    {'name': 'Custom plan'},
  ],
};

JsonMap rxOptionResponse(Uri uri) {
  final c = rxCatalogue();
  final (options, idKey, nameKey) = switch (uri.pathSegments.last) {
    'getMedicine' => (c.medicines, 'medicine_id', 'medicine_name'),
    'getDoses' => (c.doses, 'dose_id', 'dose_name'),
    'getMedicineTiming' => (c.timings, 'timing_id', 'timing_name'),
    'getMedicineRoute' => (c.routes, 'route_id', 'route_name'),
    'getTherapy' => (c.therapies, 'tm_id', 'tm_name'),
    'getTreatmentPlan' => (
      c.treatmentPlans,
      'tpm_id',
      'tpm_treatment_plan_name',
    ),
    _ => (<DynamicRxOption>[], '', ''),
  };
  return {
    'items': [
      for (final option in options) {idKey: option.id, nameKey: option.name},
    ],
  };
}

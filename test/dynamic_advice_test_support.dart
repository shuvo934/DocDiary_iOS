import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_advice_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_clinical_models.dart';

DynamicAdviceCatalogue adviceCatalogue() => DynamicAdviceCatalogue(
  values: {
    DynamicAdviceType.advice: const [
      DynamicRxOption('401', 'Sample advice'),
      DynamicRxOption('402', 'Another advice'),
    ],
    DynamicAdviceType.followUp: const [
      DynamicRxOption('501', 'Follow-up detail'),
      DynamicRxOption('502', 'Another follow-up'),
    ],
    DynamicAdviceType.specialAlert: const [
      DynamicRxOption('601', 'Special alert detail'),
      DynamicRxOption('602', 'Another alert'),
    ],
  },
);
JsonMap adviceExistingData() => {
  'advice': [
    {'text': 'Existing advice'},
  ],
  'followups': [
    {'dfi_id': 501, 'text': 'Follow-up detail with edited text'},
  ],
  'special_alerts': [
    {'dsai_id': 601, 'text': 'Special alert detail'},
  ],
  'reference': 'Existing reference',
  'notes': 'Existing prescription notes',
};
JsonMap adviceOptionResponse(Uri uri) {
  final types = DynamicAdviceType.values.where(
    (type) => type.hasOptions && type.endpoint == uri.pathSegments.last,
  );
  if (types.isEmpty) return {'items': []};
  final type = types.single;
  return {
    'items': [
      for (final option in adviceCatalogue().options[type]!)
        {type.idKey: option.id, type.nameKey: option.name},
    ],
  };
}

import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'normal_prescription_models.dart';

// Labels, weights and typography translated from the original Android XML.
String rxNativeName(NormalPrescriptionSection kind) => switch (kind) {
  NormalPrescriptionSection.complain => 'Complain',
  NormalPrescriptionSection.management => 'Management Plan',
  NormalPrescriptionSection.medication => 'Medicine',
  _ => rxSectionSpecs[kind]!.label,
};
String rxNativeFieldLabel(RxSectionSpec spec, RxField field) => switch (spec
    .section) {
  NormalPrescriptionSection.medicalHistory when field.isChoice =>
    'Past Medical History',
  NormalPrescriptionSection.drugHistory when field.isChoice => 'Drug Name',
  NormalPrescriptionSection.clinicalFindings when field.isChoice =>
    'Clinical Findings',
  NormalPrescriptionSection.service when field.isChoice => 'Service Name',
  NormalPrescriptionSection.medication when field.header == 'P_MPM_ID' =>
    'Time',
  NormalPrescriptionSection.medication when field.header == 'P_DURATION' =>
    'Duration (Days)',
  _ => field.label,
};
List<double> rxNativeWeights(NormalPrescriptionSection kind) => switch (kind) {
  NormalPrescriptionSection.complain => [3.5, 3.5, 2],
  NormalPrescriptionSection.medicalHistory ||
  NormalPrescriptionSection.drugHistory ||
  NormalPrescriptionSection.clinicalFindings => [5, 4],
  NormalPrescriptionSection.referral => [4.5, 4.5],
  NormalPrescriptionSection.service => [6, 3],
  NormalPrescriptionSection.medication => [3, 2, 2, 2],
  _ => [9],
};
TextStyle rxNativeText(
  double size, {
  String family = 'Roboto',
  FontWeight weight = FontWeight.w400,
  Color color = const Color(0xff6c6e6f),
  double height = 1.35,
  double? letterSpacing,
}) => TextStyle(
  fontFamily: family,
  fontFamilyFallback: const ['DocDiaryBengali'],
  fontSize: size,
  fontWeight: weight,
  fontVariations:
      family == 'OpenSans'
          ? [FontVariation('wght', weight.value.toDouble())]
          : null,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
);

class NativeRxActionButton extends StatelessWidget {
  const NativeRxActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.form = false,
    this.scale = 1,
    this.textStyle,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool form;
  final double scale;
  final TextStyle? textStyle;
  @override
  Widget build(BuildContext context) => Material(
    color: DocColors.primary,
    elevation: form ? 3 : 2,
    borderRadius: BorderRadius.circular(form ? 10 : 10 * scale),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed,
      child: Ink(
        decoration: BoxDecoration(
          gradient:
              form
                  ? const LinearGradient(
                    colors: [DocColors.primary, DocColors.greenSea],
                  )
                  : null,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: form ? 48 : 34,
            minWidth: form ? 0 : 88,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: form ? 7 : 16,
              vertical: form ? 10 : 7,
            ),
            child: Center(
              widthFactor: form ? null : 1,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style:
                      textStyle ??
                      rxNativeText(
                        (form ? 14 : 12) * scale,
                        family: form ? 'Poppins' : 'PatuaOne',
                        weight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: form ? 1.6 : 1.2,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String rxNativeMissing(RxSectionSpec spec, RxField field) => switch (spec
    .section) {
  NormalPrescriptionSection.complain => 'Please Write ${field.label}',
  NormalPrescriptionSection.medicalHistory when field.isChoice =>
    'Please Select Medical History',
  NormalPrescriptionSection.medication when field.header == 'P_MPM_ID' =>
    'Please Select Medicine Time',
  NormalPrescriptionSection.medication when field.header == 'P_DOSE_ID' =>
    'Please Select Dose',
  NormalPrescriptionSection.management ||
  NormalPrescriptionSection.advice ||
  NormalPrescriptionSection
      .reference => 'Please Write ${rxNativeFieldLabel(spec, field)}',
  _ => 'Please Select ${rxNativeFieldLabel(spec, field)}',
};

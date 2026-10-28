import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/doctor_appointment_models.dart';
import 'package:docdiary_ios/features/appointments/doctor_schedule/doctor_appointment_navigation.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_advice_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_clinical_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_repository.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_review_models.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_prescription_seed.dart';
import 'package:docdiary_ios/features/dynamic_prescription/dynamic_rx_models.dart';

import 'doctor_appointment_test_support.dart';
import 'dynamic_rx_test_support.dart';

class DynamicReviewHarness extends DoctorAppointmentHarness {
  DynamicReviewHarness() {
    doctorData['med_active'] = '1';
  }
  late final repository = DynamicPrescriptionRepository(appointments);
  DynamicPrescriptionSeed seed({bool existing = false}) =>
      DynamicPrescriptionSeed.fromExtras(
        doctorAppointmentRoute(
          DoctorAppointmentAction.dynamicPrescription,
          DoctorAppointmentRow({
            ...doctorAppointmentRow(),
            'rvm': existing ? '1' : '0',
          }, selectedDate: now),
        ).extras,
        ownerDoctorId: '10',
      );
}

class DynamicReviewDraftFixture {
  DynamicReviewDraftFixture({bool medicineAllowed = true}) {
    review = DynamicPrescriptionReview(
      clinical: clinical,
      rx: rx,
      advice: advice,
      medicineAllowed: medicineAllowed,
    );
  }
  final clinical = DynamicClinicalDraft(),
      rx = DynamicRxDraft(),
      advice = DynamicAdviceDraft();
  late final DynamicPrescriptionReview review;
  void populate() {
    clinical.saveVitals(
      DynamicVitals({
        'weight': '70',
        'height': '175',
        'systolic': '120',
        'diastolic': '80',
        'pulse': '72',
        'respiration': '16',
        'temperature': '98.6',
        'spo2': '98',
        'bmi': '22.9',
      }),
    );
    clinical.saveEntry(
      DynamicClinicalType.complain,
      DynamicClinicalEntry(masterId: '1', text: 'নমুনা অভিযোগ'),
    );
    clinical.saveEntry(
      DynamicClinicalType.importantInfo,
      DynamicClinicalEntry(text: 'Custom info'),
    );
    clinical.saveObjective(
      DynamicObjectiveEntry(
        objective: const DynamicRxOption('10', 'ROM'),
        value: const DynamicRxOption('11', 'Flexion'),
        muscleJoint: const DynamicRxOption('30', 'Knee'),
        notes: 'Objective notes',
      ),
    );
    rx.saveMedicine(rxMedicine(duration: '7', notes: 'ওষুধের নোট'));
    rx.saveTherapy(
      DynamicTherapyEntry(
        therapy: const DynamicRxOption('200', 'Sample therapy'),
        notes: 'Therapy notes',
      ),
    );
    rx.saveTreatmentPlan(
      DynamicTreatmentPlanEntry(masterId: '300', text: 'Edited treatment plan'),
    );
    advice.saveEntry(
      DynamicAdviceType.advice,
      DynamicAdviceEntry(masterId: '401', text: 'পরামর্শ'),
    );
    advice.saveEntry(
      DynamicAdviceType.followUp,
      DynamicAdviceEntry(masterId: '501', text: 'Follow-up text'),
    );
    advice.saveEntry(
      DynamicAdviceType.specialAlert,
      DynamicAdviceEntry(masterId: '601', text: 'Alert text'),
    );
    advice.saveEntry(
      DynamicAdviceType.reference,
      DynamicAdviceEntry(text: 'Ref line 1\r\nline 2'),
    );
    advice.saveEntry(
      DynamicAdviceType.notes,
      DynamicAdviceEntry(text: 'Notes line 1\nline 2'),
    );
    review.confirm(true);
  }

  void dispose() {
    review.dispose();
    clinical.dispose();
    rx.dispose();
    advice.dispose();
  }
}

JsonMap dynamicSavedResponse({String id = '901', String code = '2600901'}) => {
  'string_out': 'Prescription created successfully.',
  'out_rvm_id': id,
  'out_rvm_code': code,
};

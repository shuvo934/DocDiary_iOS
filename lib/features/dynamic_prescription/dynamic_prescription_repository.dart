import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../../core/transport.dart';
import '../appointments/doctor_schedule/doctor_appointment_repository.dart';
import '../auth/auth_models.dart';
import '../auth/profile_repository.dart';
import 'dynamic_clinical_models.dart';
import 'dynamic_clinical_repository.dart';
import 'dynamic_prescription_seed.dart';
import 'dynamic_rx_repository.dart';
import 'dynamic_advice_repository.dart';
import 'dynamic_prescription_save_models.dart';
import 'dynamic_template_repository.dart';
import 'dynamic_history_models.dart';
import 'dynamic_patient_repository.dart';

/// Native scheduled builder reads and a single JSON write at a time.
class DynamicPrescriptionRepository {
  DynamicPrescriptionRepository(this.appointments)
    : clinical = DynamicClinicalRepository(appointments),
      rx = DynamicRxRepository(appointments),
      advice = DynamicAdviceRepository(appointments),
      templates = DynamicTemplateRepository(appointments),
      patients = DynamicPatientRepository(appointments);
  final DoctorAppointmentRepository appointments;
  final DynamicClinicalRepository clinical;
  final DynamicRxRepository rx;
  final DynamicAdviceRepository advice;
  final DynamicTemplateRepository templates;
  final DynamicPatientRepository patients;
  bool _writing = false;
  bool get writing => _writing;

  void guard(
    AuthSession session,
    AccountProfile profile,
    DynamicPrescriptionSeed seed,
    bool Function() current,
  ) {
    clinical.guard(session, profile, current);
    if (!seed.valid ||
        seed.ownerDoctorId != profile.doctorId ||
        !seed.editableOn(appointments.now())) {
      throw const AppFailure(
        'Prescription editing requires a selected Walk-in patient or today’s scheduled appointment.',
        kind: FailureKind.invalidData,
      );
    }
  }

  Future<JsonMap> _get(
    AuthSession session,
    AccountProfile profile,
    DynamicPrescriptionSeed seed,
    String endpoint,
    Map<String, String> query,
    bool Function() current,
  ) async {
    guard(session, profile, seed, current);
    try {
      final result = await appointments.transport
          .get(
            apiEndpoint(
              session.center.baseUri,
              'dynamic_presc/$endpoint',
              query,
            ),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout:
                () =>
                    throw const AppFailure(
                      'The server took too long to respond. Please try again.',
                      kind: FailureKind.network,
                    ),
          );
      guard(session, profile, seed, current);
      return result;
    } catch (_) {
      guard(session, profile, seed, current);
      rethrow;
    }
  }

  Future<JsonMap> existing(
    AuthSession session,
    AccountProfile profile,
    DynamicPrescriptionSeed seed, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, seed, isCurrent);
    if (!seed.existing) return const {};
    return lookup(session, profile, seed, isCurrent: isCurrent);
  }

  /// Also used to reconcile a create whose response was not confirmed.
  Future<JsonMap> lookup(
    AuthSession session,
    AccountProfile profile,
    DynamicPrescriptionSeed seed, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, seed, isCurrent);
    if (seed.isWalkIn) {
      throw const AppFailure(
        'A Walk-in prescription cannot be identified by appointment. Please check Prescription History.',
      );
    }
    final root = await _get(session, profile, seed, 'getPrescription', {
      'p_ph_id': seed.patientHistoryId,
      'p_pat_id': seed.patientId,
      'p_ad_id': seed.appointmentId,
    }, isCurrent);
    if (dynamicRxText(root['status']) != '200' || root['data'] == null) {
      throw AppFailure(
        dynamicRxText(root['message']).isEmpty
            ? 'Prescription could not be loaded'
            : dynamicRxText(root['message']),
      );
    }
    final data = nativeObject(root['data']);
    if (dynamicRxText(data['rvm_id']).isEmpty) {
      throw const AppFailure(
        'Prescription ID not found',
        kind: FailureKind.invalidData,
      );
    }
    return data;
  }

  /// Native History is refreshed on every sheet opening, never cached.
  Future<List<DynamicPrescriptionHistoryItem>> history(
    AuthSession session,
    AccountProfile profile,
    DynamicPrescriptionSeed seed, {
    required bool Function() isCurrent,
  }) async {
    final root = await _get(session, profile, seed, 'getPrescriptionHistory', {
      'p_ph_id': seed.patientHistoryId,
      'p_pat_id': seed.patientId,
      'p_doc_id': profile.doctorId,
    }, isCurrent);
    final items = root['items'];
    if (items is! List<Object?>) {
      throw const AppFailure(
        'Prescription history data not found',
        kind: FailureKind.invalidData,
      );
    }
    return List.unmodifiable([
      for (final row in items)
        if (row is Map<String, Object?> &&
            dynamicRxText(row['rvm_id']).isNotEmpty)
          DynamicPrescriptionHistoryItem.fromData(row),
    ]);
  }

  Future<JsonMap> previousPrescription(
    AuthSession session,
    AccountProfile profile,
    DynamicPrescriptionSeed seed,
    String sourceRvmId, {
    required bool Function() isCurrent,
  }) async {
    if (sourceRvmId.trim().isEmpty) {
      throw const AppFailure('Prescription information not found');
    }
    final root = await _get(
      session,
      profile,
      seed,
      'loadPreviousPrescription',
      {'p_rvm_id': sourceRvmId.trim()},
      isCurrent,
    );
    if (dynamicRxText(root['status']) != '200') {
      throw AppFailure(
        dynamicRxText(root['message']).isEmpty
            ? 'Previous prescription could not be loaded'
            : dynamicRxText(root['message']),
      );
    }
    if (root['data'] is! Map<String, Object?>) {
      throw const AppFailure(
        'Previous prescription data not found',
        kind: FailureKind.invalidData,
      );
    }
    return nativeObject(root['data']);
  }

  Future<DynamicPrescriptionSaveReceipt> save(
    AuthSession session,
    AccountProfile profile,
    DynamicPrescriptionSeed seed,
    DynamicPrescriptionSaveRequest request, {
    required bool Function() isCurrent,
  }) async {
    guard(session, profile, seed, isCurrent);
    if (_writing) {
      throw const AppFailure(
        'Please wait while the prescription is being saved',
      );
    }
    if (request.doctorId != profile.doctorId ||
        request.patientId != seed.patientId ||
        request.patientHistoryId != seed.patientHistoryId ||
        request.appointmentId != seed.appointmentId ||
        (request.headers['P_PATIENT_TYPE'] != null &&
            request.headers['P_PATIENT_TYPE'] != seed.patientType)) {
      throw const AppFailure(
        'Prescription target information changed. Please reopen this appointment.',
        kind: FailureKind.invalidData,
      );
    }
    final transport = appointments.transport;
    if (transport is! BinaryTransport) {
      throw const AppFailure(
        'This connection cannot send prescription JSON.',
        kind: FailureKind.invalidData,
      );
    }
    // dart:io's HTTP header format cannot carry Unicode text. Never silently
    // replace characters or invent an encoding the native endpoint cannot read.
    if (request.headers.values.any(
      (value) => RegExp(r'[^\x09\x20-\x7e]').hasMatch(value),
    )) {
      throw const AppFailure(
        'Reference and Notes currently do not support Bangla or other non-English characters. '
        'Please use English text in these two fields and try again.\n\n'
        'The prescription has not been saved. Your draft is kept.',
        kind: FailureKind.invalidData,
      );
    }
    _writing = true;
    try {
      // Native Volley has zero POST retries. Never automatically resend this body.
      final response = await transport
          .postBytes(
            apiEndpoint(
              session.center.baseUri,
              'dynamic_presc/${request.endpoint}',
            ),
            request.body,
            headers: request.headers,
            contentType: DynamicPrescriptionSaveRequest.contentType,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout:
                () =>
                    throw const AppFailure(
                      'The server took too long to respond. Please try again.',
                      kind: FailureKind.network,
                    ),
          );
      guard(session, profile, seed, isCurrent);
      return DynamicPrescriptionSaveReceipt.fromResponse(response, request);
    } catch (failure) {
      guard(session, profile, seed, isCurrent);
      if (failure is ObsoleteRequest) rethrow;
      throw DynamicPrescriptionSaveFailure(
        failure is AppFailure
            ? failure.message
            : 'Prescription failed to create. Please check your network and try again.',
        kind: failure is AppFailure ? failure.kind : FailureKind.network,
      );
    } finally {
      _writing = false;
    }
  }

  Future<JsonMap> patientDetails(
    AuthSession session,
    AccountProfile profile,
    DynamicPrescriptionSeed seed, {
    required bool Function() isCurrent,
  }) async {
    final root = await _get(session, profile, seed, 'getPatDetails', {
      'p_ph_id': seed.patientHistoryId,
    }, isCurrent);
    final items = nativeItems(root);
    if (items.isEmpty) throw const AppFailure('Patient details not found');
    return items.first;
  }
}

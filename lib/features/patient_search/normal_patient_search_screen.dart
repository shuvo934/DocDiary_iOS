import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../dashboard/dashboard_navigation.dart';
import '../prescription/normal_prescription_repository.dart';
import 'patient_search_repository.dart';
import 'patient_search_screen.dart';

/// Compatibility entry for the accepted read-only normal prescription flow.
/// Both doctor search variants use the same screen and native card layout.
class NormalPatientSearchScreen extends StatelessWidget {
  const NormalPatientSearchScreen({
    super.key,
    required this.auth,
    required this.repository,
    this.destinationBuilder,
  });
  final AuthController auth;
  final NormalPrescriptionRepository repository;
  final DashboardDestinationBuilder? destinationBuilder;
  @override
  Widget build(BuildContext context) => PatientSearchScreen(
    auth: auth,
    repository: PatientSearchRepository(repository.appointments),
    destinationBuilder: destinationBuilder,
  );
}

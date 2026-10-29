import 'package:flutter/widgets.dart';

import '../auth/profile_repository.dart';
import '../management/management_access.dart';
import 'native_dashboard_layout.dart';

/// Destination module identities preserve DocDashboard's Intent branching.
/// Their screen implementations are delivered in the following modules.
enum DashboardModule {
  doctorProfile,
  doctorAppointments,
  doctorBlockTime,
  patientSearch,
  patientSearchPrescription,
  patientAppointmentCalendar,
  adminPayments,
  adminPatients,
  adminAppointments,
  hrAccounts,
  reports,
  unitAppointments,
  allAppointments,
  humanResources,
  accounts,
  analytics,
  reportParameters,
  hrDailyAttendance,
  hrEmployeeAttendance,
  hrAttendanceUpdateApproval,
  hrLeaveRecord,
  hrLeaveBalance,
  hrLeaveApproval,
  doctorAppointmentAvail,
  doctorAppointmentHistory,
  doctorHealthProgress,
  doctorLegacyPrescription,
  doctorPrescriptionBuilder,
  doctorPrescriptionPreview,
  doctorVideoCall,
}

class DashboardRoute {
  const DashboardRoute(this.module, {this.extras = const {}});
  final DashboardModule module;
  final Map<String, String> extras;
}

typedef DashboardDestinationBuilder =
    Widget? Function(BuildContext context, DashboardRoute route);

DashboardRoute? nativeDashboardRoute(
  AccountProfile profile,
  DashboardDestination destination,
) {
  if (destination == DashboardDestination.changePhoto) {
    return null; // Dashboard-owned media flow, not a destination screen.
  }
  final menu = nativeDashboardMenu(profile);
  final manager = profile.isDoctor && profile.value('doc_manager_flag') == '1';
  final unitHead =
      profile.isDoctor &&
      !manager &&
      profile.value('doc_deptd_head_flag') == '1';
  final allowed =
      menu.any((item) => item.destination == destination) ||
      (manager &&
          (destination == DashboardDestination.reports ||
              destination == DashboardDestination.allAppointment)) ||
      (unitHead && destination == DashboardDestination.unitAppointment);
  if (!allowed) {
    return null;
  }
  return switch (destination) {
    DashboardDestination.profile => const DashboardRoute(
      DashboardModule.doctorProfile,
    ),
    DashboardDestination.appointment => DashboardRoute(
      profile.isDoctor
          ? DashboardModule.doctorAppointments
          : DashboardModule.adminAppointments,
    ),
    DashboardDestination.leave => const DashboardRoute(
      DashboardModule.doctorBlockTime,
    ),
    DashboardDestination.patients => DashboardRoute(
      !profile.isDoctor
          ? DashboardModule.adminPatients
          : profile.value('presc_active') == '1' &&
              profile.value('can_prescribe') == '1'
          ? DashboardModule.patientSearchPrescription
          : DashboardModule.patientSearch,
    ),
    DashboardDestination.payment => const DashboardRoute(
      DashboardModule.adminPayments,
    ),
    DashboardDestination.management => DashboardRoute(
      ManagementAccess(profile).usesPortal
          ? DashboardModule.hrAccounts
          : DashboardModule.reports,
    ),
    DashboardDestination.unitAppointment => const DashboardRoute(
      DashboardModule.unitAppointments,
    ),
    DashboardDestination.allAppointment => const DashboardRoute(
      DashboardModule.allAppointments,
      extras: {'ADMIN_USER_FLAG': '1'},
    ),
    DashboardDestination.reports => const DashboardRoute(
      DashboardModule.reports,
    ),
    DashboardDestination.changePhoto => null,
  };
}

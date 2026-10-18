import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/dashboard/native_dashboard_layout.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  test(
    'doctor profile, appointment and block time map to their native modules',
    () {
      final profile = AccountProfile(AccountRole.doctor, doctorProfile());
      expect(
        nativeDashboardRoute(profile, DashboardDestination.profile)!.module,
        DashboardModule.doctorProfile,
      );
      expect(
        nativeDashboardRoute(profile, DashboardDestination.appointment)!.module,
        DashboardModule.doctorAppointments,
      );
      expect(
        nativeDashboardRoute(profile, DashboardDestination.leave)!.module,
        DashboardModule.doctorBlockTime,
      );
    },
  );
  test('dynamic patient search requires both prescription flags', () {
    for (final active in ['0', '1']) {
      for (final can in ['0', '1']) {
        final data =
            doctorProfile()
              ..['presc_active'] = active
              ..['can_prescribe'] = can;
        final route =
            nativeDashboardRoute(
              AccountProfile(AccountRole.doctor, data),
              DashboardDestination.patients,
            )!;
        expect(
          route.module,
          active == '1' && can == '1'
              ? DashboardModule.patientSearchPrescription
              : DashboardModule.patientSearch,
        );
      }
    }
  });
  test(
    'doctor manager takes precedence over unit head and keeps Intent extra',
    () {
      final data =
          doctorProfile()
            ..['doc_manager_flag'] = '1'
            ..['doc_deptd_head_flag'] = '1';
      final profile = AccountProfile(AccountRole.doctor, data);
      expect(
        nativeDashboardRoute(profile, DashboardDestination.reports)!.module,
        DashboardModule.reports,
      );
      final route =
          nativeDashboardRoute(profile, DashboardDestination.allAppointment)!;
      expect(route.module, DashboardModule.allAppointments);
      expect(route.extras, {'ADMIN_USER_FLAG': '1'});
      expect(
        nativeDashboardRoute(profile, DashboardDestination.unitAppointment),
        isNull,
      );
      data['doc_manager_flag'] = '0';
      expect(
        nativeDashboardRoute(
          AccountProfile(AccountRole.doctor, data),
          DashboardDestination.unitAppointment,
        )!.module,
        DashboardModule.unitAppointments,
      );
    },
  );
  test('admin appointment/payment/patient destinations use admin modules', () {
    final profile = AccountProfile(AccountRole.admin, adminProfile());
    expect(
      nativeDashboardRoute(profile, DashboardDestination.appointment)!.module,
      DashboardModule.adminAppointments,
    );
    expect(
      nativeDashboardRoute(profile, DashboardDestination.payment)!.module,
      DashboardModule.adminPayments,
    );
    expect(
      nativeDashboardRoute(profile, DashboardDestination.patients)!.module,
      DashboardModule.adminPatients,
    );
    expect(nativeDashboardRoute(profile, DashboardDestination.profile), isNull);
  });
  test(
    'HR/accounts access and activation choose the native management target',
    () {
      for (final access in ['0', '1', '2', '3']) {
        for (final enabled in ['0', '1']) {
          final data =
              adminProfile()
                ..['all_access_flag'] = access
                ..['hr_acc_active_flag'] = enabled;
          final profile = AccountProfile(AccountRole.admin, data);
          expect(
            nativeDashboardRoute(
              profile,
              DashboardDestination.management,
            )!.module,
            enabled == '1' && access != '0'
                ? DashboardModule.hrAccounts
                : DashboardModule.reports,
          );
        }
      }
    },
  );
  test('hidden HR/accounts buttons cannot dispatch a navigation request', () {
    for (final access in ['2', '3']) {
      final data = adminProfile()..['all_access_flag'] = access;
      final profile = AccountProfile(AccountRole.admin, data);
      expect(
        nativeDashboardRoute(profile, DashboardDestination.payment),
        isNull,
      );
      expect(
        nativeDashboardRoute(profile, DashboardDestination.appointment),
        isNull,
      );
      expect(
        nativeDashboardRoute(profile, DashboardDestination.changePhoto),
        isNull,
      );
    }
  });
}

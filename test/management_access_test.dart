import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/dashboard/native_dashboard_layout.dart';
import 'package:docdiary_ios/features/management/management_access.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';

void main() {
  test(
    'Analytics follows the real API key and a Java getter alias cannot grant access',
    () {
      for (final flags in <JsonMap>[
        {'usr_mob_app_analytic_access': '1', 'analytics_dashboard': '0'},
        {'usr_mob_app_analytic_access': '0', 'analytics_dashboard': '1'},
        {'analytics_dashboard': '1'},
      ]) {
        final access = ManagementAccess(
          AccountProfile(AccountRole.admin, {
            ...adminProfile(),
            'all_access_flag': '1',
            'hr_acc_active_flag': '1',
            ...flags,
          }),
        );
        expect(
          access.allows(ManagementDestination.analytics),
          flags['usr_mob_app_analytic_access'] == '1',
        );
      }
    },
  );
  test(
    'native role matrix never turns all-access into unconditional card access',
    () {
      final cases = <
        ({
          String role,
          String module,
          String hr,
          String acc,
          String analytics,
          String title,
          List<ManagementDestination> cards,
        })
      >[
        (
          role: '1',
          module: '1',
          hr: '1',
          acc: '1',
          analytics: '1',
          title: 'Management Portal',
          cards: [
            ManagementDestination.humanResources,
            ManagementDestination.accounts,
            ManagementDestination.analytics,
            ManagementDestination.reports,
          ],
        ),
        (
          role: '1',
          module: '1',
          hr: '0',
          acc: '1',
          analytics: '0',
          title: 'Management Portal',
          cards: [
            ManagementDestination.accounts,
            ManagementDestination.reports,
          ],
        ),
        (
          role: '1',
          module: '1',
          hr: '0',
          acc: '0',
          analytics: '0',
          title: 'Management Portal',
          cards: [ManagementDestination.reports],
        ),
        (
          role: '2',
          module: '1',
          hr: '1',
          acc: '1',
          analytics: '1',
          title: 'HR & Reports',
          cards: [
            ManagementDestination.humanResources,
            ManagementDestination.reports,
          ],
        ),
        (
          role: '2',
          module: '1',
          hr: '0',
          acc: '1',
          analytics: '1',
          title: 'HR & Reports',
          cards: [ManagementDestination.reports],
        ),
        (
          role: '3',
          module: '1',
          hr: '1',
          acc: '1',
          analytics: '1',
          title: 'Accounts & Reports',
          cards: [
            ManagementDestination.accounts,
            ManagementDestination.reports,
          ],
        ),
        (
          role: '3',
          module: '1',
          hr: '1',
          acc: '0',
          analytics: '1',
          title: 'Accounts & Reports',
          cards: [ManagementDestination.reports],
        ),
        (
          role: '1',
          module: '0',
          hr: '1',
          acc: '1',
          analytics: '1',
          title: 'Reports',
          cards: [ManagementDestination.reports],
        ),
        (
          role: '0',
          module: '1',
          hr: '1',
          acc: '1',
          analytics: '1',
          title: 'Reports',
          cards: [ManagementDestination.reports],
        ),
        (
          role: '4',
          module: '1',
          hr: '1',
          acc: '1',
          analytics: '1',
          title: 'Reports',
          cards: [ManagementDestination.reports],
        ),
        (
          role: 'broken',
          module: '1',
          hr: '1',
          acc: '1',
          analytics: '1',
          title: 'Reports',
          cards: [ManagementDestination.reports],
        ),
      ];
      for (final c in cases) {
        final profile = AccountProfile(AccountRole.admin, {
          ...adminProfile(),
          'all_access_flag': c.role,
          'hr_acc_active_flag': c.module,
          'hr_dashboard': c.hr,
          'acc_dashboard': c.acc,
          'usr_mob_app_analytic_access': c.analytics,
        });
        final access = ManagementAccess(profile);
        expect(access.title, c.title, reason: c.toString());
        expect(access.destinations, c.cards, reason: c.toString());
        final root =
            nativeDashboardRoute(profile, DashboardDestination.management)!;
        expect(
          root.module,
          access.usesPortal
              ? DashboardModule.hrAccounts
              : DashboardModule.reports,
        );
        expect(nativeDashboardMenu(profile).last.label, c.title);
      }
    },
  );

  test('missing flags and cross-role flags do not grant a dashboard', () {
    for (final values in <JsonMap>[
      {'all_access_flag': '1', 'hr_acc_active_flag': '1'},
      {
        'all_access_flag': '1',
        'hr_acc_active_flag': '1',
        'hr_dashboard': null,
        'acc_dashboard': 'true',
        'usr_mob_app_analytic_access': 'yes',
      },
    ]) {
      final access = ManagementAccess(
        AccountProfile(AccountRole.admin, values),
      );
      expect(access.destinations, [ManagementDestination.reports]);
    }
  });

  test('doctor-manager report access does not grant the management portal', () {
    for (final manager in ['0', '1']) {
      final access = ManagementAccess(
        AccountProfile(AccountRole.doctor, {
          ...doctorProfile(),
          'doc_manager_flag': manager,
          'all_access_flag': '1',
          'hr_acc_active_flag': '1',
          'hr_dashboard': '1',
          'acc_dashboard': '1',
          'usr_mob_app_analytic_access': '1',
        }),
      );
      expect(access.usesPortal, isFalse);
      expect(access.canOpenReports, manager == '1');
      expect(
        access.destinations,
        manager == '1' ? [ManagementDestination.reports] : isEmpty,
      );
    }
  });

  test(
    'HR and Accounts bottom menus use their own payment/appointment flags',
    () {
      for (final role in ['2', '3']) {
        final profile = AccountProfile(AccountRole.admin, {
          ...adminProfile(),
          'all_access_flag': role,
          'hr_acc_active_flag': '1',
          'hr_payment_active': '0',
          'hr_appointment_active': '1',
          'acc_payment_active': '1',
          'acc_appointment_active': '0',
        });
        final destinations = nativeDashboardMenu(
          profile,
        ).map((e) => e.destination);
        expect(
          destinations.contains(DashboardDestination.payment),
          role == '3',
        );
        expect(
          destinations.contains(DashboardDestination.appointment),
          role == '2',
        );
        expect(
          nativeDashboardRoute(
            profile,
            role == '2'
                ? DashboardDestination.payment
                : DashboardDestination.appointment,
          ),
          isNull,
        );
      }
    },
  );
}

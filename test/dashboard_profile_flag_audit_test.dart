import 'package:docdiary_ios/app.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/appointments/admin_modify/admin_appointment_models.dart';
import 'package:docdiary_ios/features/appointments/all_schedule/all_appointment_models.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_repository.dart';
import 'package:docdiary_ios/features/dashboard/native_dashboard_layout.dart';
import 'package:docdiary_ios/features/management/management_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'admin_appointment_test_support.dart';
import 'support.dart';

AccountProfile _admin(String role, JsonMap flags) => AccountProfile(
  AccountRole.admin,
  {...adminProfile(), 'all_access_flag': role, ...flags},
);

void main() {
  // Native DocDashboard.java updateAdminInterface: roles 2/3 use their own
  // pair of flags. Full-access (1) and native fallback (0) show both entries.
  for (final role in ['0', '1', '2', '3']) {
    test(
      'native role $role menu, route and appointment guards cover all 16 flag combinations',
      () {
        for (var mask = 0; mask < 16; mask++) {
          final flags = <String, Object?>{
            'hr_payment_active': '${mask & 1}',
            'hr_appointment_active': '${(mask >> 1) & 1}',
            'acc_payment_active': '${(mask >> 2) & 1}',
            'acc_appointment_active': '${(mask >> 3) & 1}',
          };
          // These are the independent native truth-table masks for each role.
          final expected =
              <String, (bool, bool)>{
                '0': (true, true),
                '1': (true, true),
                '2': (mask & 1 != 0, mask & 2 != 0),
                '3': (mask & 4 != 0, mask & 8 != 0),
              }[role]!;
          final profile = _admin(role, flags),
              menu = nativeDashboardMenu(profile);
          final reason = 'role=$role flags=$flags';
          expect(
            menu.any((m) => m.destination == DashboardDestination.payment),
            expected.$1,
            reason: reason,
          );
          expect(
            menu.any((m) => m.destination == DashboardDestination.appointment),
            expected.$2,
            reason: reason,
          );
          expect(
            nativeDashboardRoute(profile, DashboardDestination.payment)?.module,
            expected.$1 ? DashboardModule.adminPayments : null,
            reason: reason,
          );
          expect(
            nativeDashboardRoute(
              profile,
              DashboardDestination.appointment,
            )?.module,
            expected.$2 ? DashboardModule.adminAppointments : null,
            reason: reason,
          );
          expect(adminAppointmentAllowed(profile), expected.$2, reason: reason);
          expect(allAppointmentAllowed(profile), expected.$2, reason: reason);
        }
      },
    );
  }

  for (final role in ['0', '1', '2', '3']) {
    test(
      'native role $role portal cards honor all flag combinations without granting extra cards',
      () {
        const capabilities = <String, Set<ManagementDestination>>{
          '0': {},
          '1': {
            ManagementDestination.humanResources,
            ManagementDestination.accounts,
            ManagementDestination.analytics,
          },
          '2': {ManagementDestination.humanResources},
          '3': {ManagementDestination.accounts},
        };
        for (var mask = 0; mask < 16; mask++) {
          final portal = mask & 1 != 0;
          final flags = <String, Object?>{
            'hr_acc_active_flag': portal ? '1' : '0',
            'hr_dashboard': mask & 2 != 0 ? '1' : '0',
            'acc_dashboard': mask & 4 != 0 ? '1' : '0',
            'usr_mob_app_analytic_access': mask & 8 != 0 ? '1' : '0',
          };
          final profile = _admin(role, flags),
              access = ManagementAccess(profile);
          final expected = <ManagementDestination>{
            ManagementDestination.reports,
          };
          if (portal) {
            final enabled = <ManagementDestination>{
              if (mask & 2 != 0) ManagementDestination.humanResources,
              if (mask & 4 != 0) ManagementDestination.accounts,
              if (mask & 8 != 0) ManagementDestination.analytics,
            };
            expected.addAll(capabilities[role]!.intersection(enabled));
          }
          expect(
            access.destinations.toSet(),
            expected,
            reason: 'role=$role flags=$flags',
          );
          expect(
            nativeDashboardRoute(
              profile,
              DashboardDestination.management,
            )!.module,
            portal && role != '0'
                ? DashboardModule.hrAccounts
                : DashboardModule.reports,
          );
        }
      },
    );
  }

  for (final entry
      in <String, (String, DashboardDestination)>{
        'hr_payment_active': ('2', DashboardDestination.payment),
        'hr_appointment_active': ('2', DashboardDestination.appointment),
        'acc_payment_active': ('3', DashboardDestination.payment),
        'acc_appointment_active': ('3', DashboardDestination.appointment),
      }.entries) {
    test(
      '${entry.key} accepts native string/numeric 1 and denies missing, null and other values',
      () {
        for (final value in <Object?>[
          null,
          '',
          'null',
          0,
          '0',
          1,
          '1',
          true,
          false,
          'yes',
          '2',
        ]) {
          final profile = _admin(entry.value.$1, {
            'hr_payment_active': '0',
            'hr_appointment_active': '0',
            'acc_payment_active': '0',
            'acc_appointment_active': '0',
            entry.key: value,
          });
          expect(
            nativeDashboardRoute(profile, entry.value.$2) != null,
            value == 1 || value == '1',
            reason: '${entry.key}=$value',
          );
        }
        expect(
          nativeDashboardRoute(_admin(entry.value.$1, {}), entry.value.$2),
          isNull,
        );
      },
    );
  }

  for (final (role, key) in [
    ('2', 'hr_appointment_active'),
    ('3', 'acc_appointment_active'),
  ]) {
    test(
      'role $role disabled appointment blocks actual repository reads before transport',
      () async {
        final h = AdminAppointmentHarness();
        addTearDown(h.auth.dispose);
        await h.signIn();
        final denied = AccountProfile(AccountRole.admin, {
          ...h.adminData,
          'all_access_flag': role,
          key: '0',
        });
        h.transport.requests.clear();
        await expectLater(
          h.repository.patients(
            h.auth.session!,
            denied,
            cancel: false,
            search: '',
            isCurrent: () => true,
          ),
          throwsA(isA<AdminAppointmentUnavailable>()),
        );
        expect(h.transport.requests, isEmpty);
      },
    );
  }

  test(
    'native doctor manager overrides unit head; Patient and prescription flags stay independent',
    () {
      const expected = <(String, String), (bool, bool, bool)>{
        ('0', '0'): (false, false, false),
        ('0', '1'): (false, false, true),
        ('1', '0'): (true, true, false),
        ('1', '1'): (true, true, false),
      };
      for (final e in expected.entries) {
        for (final patient in ['0', '1']) {
          for (final rx in ['0', '1']) {
            for (final prescribe in ['0', '1']) {
              final profile = AccountProfile(AccountRole.doctor, {
                ...doctorProfile(),
                'doc_manager_flag': e.key.$1,
                'doc_deptd_head_flag': e.key.$2,
                'pat_pres_view': patient,
                'presc_active': rx,
                'can_prescribe': prescribe,
              });
              expect(
                nativeDashboardRoute(profile, DashboardDestination.reports) !=
                    null,
                e.value.$1,
              );
              expect(
                nativeDashboardRoute(
                      profile,
                      DashboardDestination.allAppointment,
                    ) !=
                    null,
                e.value.$2,
              );
              expect(
                nativeDashboardRoute(
                      profile,
                      DashboardDestination.unitAppointment,
                    ) !=
                    null,
                e.value.$3,
              );
              expect(
                nativeDashboardRoute(
                  profile,
                  DashboardDestination.patients,
                )?.module,
                patient == '0'
                    ? null
                    : rx == '1' && prescribe == '1'
                    ? DashboardModule.patientSearchPrescription
                    : DashboardModule.patientSearch,
              );
            }
          }
        }
      }
    },
  );

  test(
    'admin profile retains every native dashboard feature flag including future Payment Mode',
    () async {
      final h = Harness();
      addTearDown(h.auth.dispose);
      h.loginResponse = adminLogin();
      const flags = <String, Object?>{
        'all_access_flag': '3',
        'hr_payment_active': '1',
        'hr_appointment_active': '0',
        'acc_payment_active': 1,
        'acc_appointment_active': '1',
        'hr_dashboard': '0',
        'acc_dashboard': '1',
        'hr_acc_active_flag': '1',
        'is_pay_mode_active': '1',
        'is_pay_appoint_type_active': '0',
        'usr_mob_app_analytic_access': '1',
        'presc_active': '1',
      };
      h.adminData.addAll(flags);
      await h.signIn();
      for (final e in flags.entries) {
        expect(h.auth.profile!.value(e.key), '${e.value}');
      }
    },
  );

  for (final (role, prefix, portal) in [
    ('2', 'hr', 'HR & Reports'),
    ('3', 'acc', 'Accounts & Reports'),
  ]) {
    testWidgets(
      'dashboard role $role refresh adopts changed feature flags without logging in again',
      (t) async {
        t.view.physicalSize = const Size(393, 852);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final h = Harness();
        h.loginResponse = adminLogin();
        h.adminData.addAll({
          'all_access_flag': role,
          'hr_acc_active_flag': '1',
          '${prefix}_payment_active': '0',
          '${prefix}_appointment_active': '1',
        });
        await h.signIn();
        final logs =
            h.posts.where((r) => r.uri.path.endsWith('loginLog')).length;
        await t.pumpWidget(
          DocDiaryApp(
            auth: h.auth,
            initializeOnStart: false,
            dashboard: DashboardRepository(h.transport, now: () => h.now),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byKey(const Key('dashboard_nav_payment')), findsNothing);
        expect(
          find.byKey(const Key('dashboard_nav_appointment')),
          findsOneWidget,
        );
        h.adminData.addAll({
          '${prefix}_payment_active': '1',
          '${prefix}_appointment_active': '0',
          'hr_acc_active_flag': '0',
        });
        await t
            .widget<NativeDashboardLayout>(find.byType(NativeDashboardLayout))
            .onRefresh();
        await t.pumpAndSettle();
        expect(find.byKey(const Key('dashboard_nav_payment')), findsOneWidget);
        expect(
          find.byKey(const Key('dashboard_nav_appointment')),
          findsNothing,
        );
        expect(
          nativeDashboardMenu(
            t
                .widget<NativeDashboardLayout>(
                  find.byType(NativeDashboardLayout),
                )
                .profile,
          ).last.label,
          'Reports',
        );
        h.adminData.addAll({
          '${prefix}_payment_active': '0',
          '${prefix}_appointment_active': '1',
          'hr_acc_active_flag': '1',
        });
        await t
            .widget<NativeDashboardLayout>(find.byType(NativeDashboardLayout))
            .onRefresh();
        await t.pumpAndSettle();
        expect(find.byKey(const Key('dashboard_nav_payment')), findsNothing);
        expect(
          find.byKey(const Key('dashboard_nav_appointment')),
          findsOneWidget,
        );
        expect(
          nativeDashboardMenu(
            t
                .widget<NativeDashboardLayout>(
                  find.byType(NativeDashboardLayout),
                )
                .profile,
          ).last.label,
          portal,
        );
        expect(
          h.posts.where((r) => r.uri.path.endsWith('loginLog')).length,
          logs,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      },
    );
  }
}

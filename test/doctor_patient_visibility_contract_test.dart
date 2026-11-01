import 'package:docdiary_ios/features/auth/auth_models.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:docdiary_ios/features/dashboard/dashboard_navigation.dart';
import 'package:docdiary_ios/features/dashboard/native_dashboard_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support.dart';

void main() {
  for (final flag in ['1', '0', '']) {
    test('Doctor Patient visibility respects native pat_pres_view=$flag', () {
      final profile = AccountProfile(AccountRole.doctor, {
        ...doctorProfile(),
        'pat_pres_view': flag,
      });
      final visible = nativeDashboardMenu(
        profile,
      ).any((v) => v.destination == DashboardDestination.patients);
      expect(visible, flag == '1');
      expect(
        nativeDashboardRoute(profile, DashboardDestination.patients) != null,
        flag == '1',
      );
      expect(
        nativeDashboardRoute(profile, DashboardDestination.appointment),
        isNotNull,
      );
      expect(
        nativeDashboardRoute(profile, DashboardDestination.profile),
        isNotNull,
      );
    });
  }
}

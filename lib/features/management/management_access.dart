import '../auth/profile_repository.dart';

enum ManagementDestination {
  humanResources('HR Dashboard', 'hr_icon.png'),
  accounts('Accounts Dashboard', 'accounting_icon.png'),
  analytics('Analytics Dashboard', 'data_analytics.png'),
  reports('Report Manager', 'report.png');

  const ManagementDestination(this.label, this.artwork);
  final String label;
  final String artwork;
}

/// DocDashboard + HRAccounts rules. All-access does not override card flags.
class ManagementAccess {
  ManagementAccess(AccountProfile profile)
    : role = int.tryParse(profile.value('all_access_flag')) ?? 0,
      usesPortal =
          !profile.isDoctor &&
          profile.value('hr_acc_active_flag') == '1' &&
          (int.tryParse(profile.value('all_access_flag')) ?? 0) > 0,
      canOpenReports =
          !profile.isDoctor || profile.value('doc_manager_flag') == '1',
      _profile = profile;

  final int role;
  final bool usesPortal, canOpenReports;
  final AccountProfile _profile;

  String get title =>
      !usesPortal
          ? 'Reports'
          : switch (role) {
            1 => 'Management Portal',
            2 => 'HR & Reports',
            3 => 'Accounts & Reports',
            _ => 'Reports',
          };

  List<ManagementDestination> get destinations => List.unmodifiable([
    if (usesPortal &&
        (role == 1 || role == 2) &&
        _profile.value('hr_dashboard') == '1')
      ManagementDestination.humanResources,
    if (usesPortal &&
        (role == 1 || role == 3) &&
        _profile.value('acc_dashboard') == '1')
      ManagementDestination.accounts,
    if (usesPortal &&
        role == 1 &&
        _profile.value('usr_mob_app_analytic_access') == '1')
      ManagementDestination.analytics,
    if (canOpenReports) ManagementDestination.reports,
  ]);

  bool allows(ManagementDestination destination) =>
      destinations.contains(destination);
}

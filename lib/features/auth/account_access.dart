import '../../core/failure.dart';
import '../../core/native_dates.dart';

enum AccountAccessReason {
  forcedLogout,
  mobileAccess,
  expired,
  doctorUnavailable,
  adminUnavailable,
}

/// A native dashboard access dialog, distinct from a retryable request failure.
class AccountAccessFailure extends AppFailure {
  const AccountAccessFailure(this.reason, String message)
    : super(message, kind: FailureKind.denied);

  const AccountAccessFailure.forcedLogout()
    : this(
        AccountAccessReason.forcedLogout,
        'You are forced to log out from the app for server maintenance. We are sorry for the disturbance. Please Login again to continue the app.',
      );

  const AccountAccessFailure.mobileAccess()
    : this(
        AccountAccessReason.mobileAccess,
        'You have no permission to access this app. Please contact with administrator to access this app.',
      );

  const AccountAccessFailure.adminUnavailable()
    : this(
        AccountAccessReason.adminUnavailable,
        'No Admin Information found for this Id. Please contact with Administrator.',
      );

  factory AccountAccessFailure.expired(String expiry) => AccountAccessFailure(
    AccountAccessReason.expired,
    'Your access to the app is expired on: $expiry.\n'
    'To gain access to the app, Please contact with the administrator',
  );

  factory AccountAccessFailure.doctorUnavailable(
    String status,
    String effectiveDate,
  ) => AccountAccessFailure(
    AccountAccessReason.doctorUnavailable,
    status.isEmpty
        ? 'No User Data Found'
        : 'Your status is: $status, with effected date: $effectiveDate. '
            'So, You are not eligible to access this app.',
  );

  final AccountAccessReason reason;
  String get title => switch (reason) {
    AccountAccessReason.forcedLogout => 'Forced Log Out!',
    AccountAccessReason.expired => 'Access Expired!',
    AccountAccessReason.adminUnavailable => 'No Information Found!',
    AccountAccessReason.mobileAccess ||
    AccountAccessReason.doctorUnavailable => 'Access Denied!',
  };
}

class AccountExpiryWarning {
  const AccountExpiryWarning(this.expiry, this.daysLeft);
  final String expiry;
  final int daysLeft;
  String get title => 'Access Expired Warning!';
  String get message =>
      'Your access to the app will expire on: $expiry '
      '($daysLeft day(s) left).\n'
      'Please contact the administrator to renew your access and continue using the app without interruption.';

  static AccountExpiryWarning? forDate(String expiry, DateTime now) {
    final last = parseOracleDate(expiry);
    // Count calendar days even if a user's local zone crosses a DST change.
    final days =
        DateTime.utc(
          last.year,
          last.month,
          last.day,
        ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
    return days >= 0 && days <= 3 ? AccountExpiryWarning(expiry, days) : null;
  }
}

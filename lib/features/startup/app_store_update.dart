import 'package:package_info_plus/package_info_plus.dart';

import '../../core/client_descriptor.dart';
import '../../core/failure.dart';
import '../../core/native_json.dart';
import '../../core/transport.dart';

class AppVersion implements Comparable<AppVersion> {
  AppVersion._(this.parts);
  final List<int> parts;

  factory AppVersion.parse(String value) {
    if (value.length > 32 || !RegExp(r'^\d+(?:\.\d+){0,2}$').hasMatch(value)) {
      throw const FormatException('Invalid Apple version.');
    }
    final parts = value.split('.').map(int.tryParse).toList();
    if (parts.any((n) => n == null)) {
      throw const FormatException('Invalid Apple version.');
    }
    return AppVersion._([
      for (var i = 0; i < 3; i++) i < parts.length ? parts[i]! : 0,
    ]);
  }

  @override
  int compareTo(AppVersion other) {
    for (var i = 0; i < 3; i++) {
      final result = parts[i].compareTo(other.parts[i]);
      if (result != 0) {
        return result;
      }
    }
    return 0;
  }
}

class InstalledAppSnapshot {
  const InstalledAppSnapshot({
    required this.bundleId,
    required this.version,
    required this.osVersion,
  });
  final String bundleId, version, osVersion;

  static Future<InstalledAppSnapshot> read() async {
    final package = await PackageInfo.fromPlatform();
    final device = await DeviceSnapshot.read();
    return InstalledAppSnapshot(
      bundleId: package.packageName,
      version: package.version,
      osVersion: device.systemVersion,
    );
  }
}

class AppUpdateOffer {
  const AppUpdateOffer({
    required this.installedVersion,
    required this.storeVersion,
    required this.storeUrl,
  });
  final String installedVersion, storeVersion;
  final Uri storeUrl;
}

abstract interface class AppUpdateChecker {
  Future<AppUpdateOffer?> check();
}

/// Apple lookup reports public App Store marketing versions, not Android build
/// codes or TestFlight builds. A missing listing means this pre-release app can
/// start normally; failures are handled by the native-derived startup policy.
class AppStoreUpdateChecker implements AppUpdateChecker {
  AppStoreUpdateChecker(
    this.transport, {
    Future<InstalledAppSnapshot> Function()? installed,
    this.country = 'bd',
    this.appStoreId = '',
  }) : installed = installed ?? InstalledAppSnapshot.read;
  final Transport transport;
  final Future<InstalledAppSnapshot> Function() installed;
  final String country, appStoreId;

  @override
  Future<AppUpdateOffer?> check() async {
    final local = await installed();
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9.\-]+$').hasMatch(local.bundleId) ||
        !RegExp(r'^[a-zA-Z]{2}$').hasMatch(country) ||
        (appStoreId.isNotEmpty &&
            !RegExp(r'^[1-9]\d*$').hasMatch(appStoreId))) {
      throw const AppFailure('App Store update configuration is invalid.');
    }
    final current = AppVersion.parse(local.version);
    final response = await transport.get(
      Uri.https('itunes.apple.com', '/lookup', {
        if (appStoreId.isEmpty)
          'bundleId': local.bundleId
        else
          'id': appStoreId,
        'country': country.toLowerCase(),
        'entity': 'software',
      }),
    );
    final count = int.tryParse(nativeText(response['resultCount']));
    if (count == null || count < 0 || response['results'] is! List) {
      throw const AppFailure(
        'The App Store returned an invalid update response.',
      );
    }
    final results = nativeArray(response['results']);
    if (count != results.length) {
      throw const AppFailure(
        'The App Store returned incomplete update information.',
      );
    }
    if (count == 0) {
      return null;
    }
    final matches =
        results
            .where(
              (item) =>
                  nativeText(item['bundleId']) == local.bundleId &&
                  nativeText(item['kind']) == 'software',
            )
            .toList();
    if (matches.length != 1) {
      throw const AppFailure(
        'The App Store app identity could not be verified.',
      );
    }
    final item = matches.single;
    final version = nativeText(item['version']);
    if (AppVersion.parse(version).compareTo(current) <= 0) {
      return null;
    }
    // Never lock an older iPhone to a release requiring an unsupported iOS.
    final minimumOs = AppVersion.parse(nativeText(item['minimumOsVersion']));
    if (AppVersion.parse(local.osVersion).compareTo(minimumOs) < 0) {
      return null;
    }
    final id = nativeText(item['trackId']);
    if (!RegExp(r'^[1-9]\d*$').hasMatch(id) ||
        (appStoreId.isNotEmpty && id != appStoreId)) {
      throw const AppFailure('The App Store app identifier is invalid.');
    }
    return AppUpdateOffer(
      installedVersion: local.version,
      storeVersion: version,
      storeUrl: Uri.https(
        'apps.apple.com',
        '/${country.toLowerCase()}/app/id$id',
      ),
    );
  }
}

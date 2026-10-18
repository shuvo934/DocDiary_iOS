import 'dart:async';

import 'package:docdiary_ios/core/failure.dart';
import 'package:docdiary_ios/core/native_json.dart';
import 'package:docdiary_ios/features/startup/app_store_update.dart';
import 'package:docdiary_ios/features/startup/app_update_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

JsonMap _listing({
  String version = '1.10.0',
  String minimumOs = '15.0',
  String bundleId = 'com.techterrain.docdiary.ios',
}) => {
  'resultCount': 1,
  'results': [
    {
      'bundleId': bundleId,
      'version': version,
      'minimumOsVersion': minimumOs,
      'kind': 'software',
      'trackId': 123456789,
      'trackViewUrl': 'https://untrusted.example/ignore-this-url',
    },
  ],
};

AppStoreUpdateChecker _repo(
  FakeTransport t, {
  String version = '1.9.0',
  String os = '18.6',
  String id = '',
  String country = 'bd',
}) => AppStoreUpdateChecker(
  t,
  country: country,
  appStoreId: id,
  installed:
      () async => InstalledAppSnapshot(
        bundleId: 'com.techterrain.docdiary.ios',
        version: version,
        osVersion: os,
      ),
);

const _offerVersion = '1.10.0';
AppUpdateOffer _offer() => AppUpdateOffer(
  installedVersion: '1.9.0',
  storeVersion: _offerVersion,
  storeUrl: Uri.parse('https://apps.apple.com/bd/app/id123456789'),
);

class _Checker implements AppUpdateChecker {
  int calls = 0;
  Future<AppUpdateOffer?> Function()? action;
  AppUpdateOffer? next = _offer();
  @override
  Future<AppUpdateOffer?> check() async {
    calls++;
    return action == null ? next : await action!();
  }
}

void main() {
  test(
    'Apple numeric marketing versions compare correctly and ignore equivalent trailing zeros',
    () {
      expect(
        AppVersion.parse('1.10').compareTo(AppVersion.parse('1.9.99')),
        greaterThan(0),
      );
      expect(AppVersion.parse('2').compareTo(AppVersion.parse('2.0.0')), 0);
      expect(
        AppVersion.parse('1.9').compareTo(AppVersion.parse('2.0')),
        lessThan(0),
      );
      for (final value in [
        '',
        '1.0-beta',
        '1.0+4',
        '1..2',
        '-1',
        '1.2.3.4',
        'latest',
      ]) {
        expect(() => AppVersion.parse(value), throwsFormatException);
      }
    },
  );

  test(
    'lookup uses actual bundle, country and a validated Apple URL rather than a returned foreign link',
    () async {
      final t = FakeTransport()..onGet = (_) async => _listing();
      final offer = (await _repo(t).check())!;
      expect(offer.storeVersion, '1.10.0');
      expect(offer.installedVersion, '1.9.0');
      expect(
        offer.storeUrl.toString(),
        'https://apps.apple.com/bd/app/id123456789',
      );
      expect(t.requests.single.uri.host, 'itunes.apple.com');
      expect(t.requests.single.uri.queryParameters, {
        'bundleId': 'com.techterrain.docdiary.ios',
        'country': 'bd',
        'entity': 'software',
      });
      expect(t.requests.single.headers, isEmpty);
    },
  );

  test(
    'known App Store ID uses ID lookup and must still match the actual bundle',
    () async {
      final t = FakeTransport()..onGet = (_) async => _listing();
      await _repo(t, id: '123456789').check();
      expect(t.requests.single.uri.queryParameters['id'], '123456789');
      expect(
        t.requests.single.uri.queryParameters.containsKey('bundleId'),
        isFalse,
      );
      t.onGet = (_) async => _listing(bundleId: 'someone.elses.app');
      await expectLater(
        _repo(t, id: '123456789').check(),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  test(
    'no public listing yet permits the first iOS release and development builds',
    () async {
      final t =
          FakeTransport()
            ..onGet = (_) async => {'resultCount': 0, 'results': <Object?>[]};
      expect(await _repo(t).check(), isNull);
    },
  );

  test(
    'same/newer installed TestFlight version does not request an older store release',
    () async {
      for (final installed in ['1.10.0', '1.11.0', '2.0']) {
        final t = FakeTransport()..onGet = (_) async => _listing();
        expect(await _repo(t, version: installed).check(), isNull);
      }
    },
  );

  test(
    'unsupported minimum iOS never traps an older device behind an impossible update',
    () async {
      final t =
          FakeTransport()..onGet = (_) async => _listing(minimumOs: '19.0');
      expect(await _repo(t, os: '18.6').check(), isNull);
      t.onGet = (_) async => _listing(minimumOs: '18.6');
      expect(await _repo(t, os: '18.6').check(), isNotNull);
    },
  );

  test(
    'malformed responses and configuration fail as checks rather than inventing a release',
    () async {
      final t = FakeTransport();
      for (final data in <JsonMap>[
        {},
        {'resultCount': 1, 'results': []},
        {'resultCount': '1', 'results': 'wrong'},
        _listing(version: 'latest'),
        _listing(minimumOs: ''),
        _listing()
          ..['results'] = [
            <String, Object?>{'bundleId': 'wrong'},
          ],
      ]) {
        t.onGet = (_) async => data;
        await expectLater(_repo(t).check(), throwsA(anything));
      }
      await expectLater(
        _repo(t, country: 'Bangladesh').check(),
        throwsA(isA<AppFailure>()),
      );
      await expectLater(
        _repo(t, id: 'bad/id').check(),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  test(
    'initial check failure follows MainActivity onFailure and permits startup',
    () async {
      final checker =
          _Checker()..action = () async => throw const AppFailure('Offline');
      final controller = AppUpdateController(checker: checker);
      addTearDown(controller.dispose);
      await controller.check();
      expect(controller.allowsStartup, isTrue);
      expect(controller.checkFailure, isNotNull);
    },
  );

  test('debug-disabled checks make no Store or metadata request', () async {
    final checker = _Checker();
    final controller = AppUpdateController(checker: checker, enabled: false);
    addTearDown(controller.dispose);
    await controller.check();
    expect(checker.calls, 0);
    expect(controller.allowsStartup, isTrue);
  });

  test(
    'successful store launch alone never counts as a completed update',
    () async {
      final controller = AppUpdateController(
        checker: _Checker(),
        openStore: (_) async => true,
      );
      addTearDown(controller.dispose);
      await controller.check();
      await controller.update();
      expect(controller.stage, AppUpdateStage.required);
      expect(controller.allowsStartup, isFalse);
    },
  );

  test(
    'failed store launch, Cancel and Retry preserve the update gate',
    () async {
      final checker = _Checker();
      final controller = AppUpdateController(
        checker: checker,
        openStore: (_) async => false,
      );
      addTearDown(controller.dispose);
      await controller.check();
      await controller.update();
      expect(controller.stage, AppUpdateStage.failed);
      controller.cancelFailure();
      expect(controller.stage, AppUpdateStage.cancelled);
      expect(controller.allowsStartup, isFalse);
      await controller.check();
      expect(controller.stage, AppUpdateStage.required);
      controller.cancelUpdate();
      expect(controller.stage, AppUpdateStage.failed);
    },
  );

  test(
    'return from App Store rechecks and reports failure when update was not installed',
    () async {
      final checker = _Checker();
      final controller = AppUpdateController(
        checker: checker,
        openStore: (_) async => true,
      );
      addTearDown(controller.dispose);
      await controller.check();
      await controller.update();
      controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(checker.calls, 2);
      expect(controller.stage, AppUpdateStage.failed);
      expect(controller.allowsStartup, isFalse);
    },
  );

  test('an updated installed version can proceed on Store return', () async {
    final checker = _Checker();
    final controller = AppUpdateController(
      checker: checker,
      openStore: (_) async => true,
    );
    addTearDown(controller.dispose);
    await controller.check();
    await controller.update();
    checker.next = null;
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(controller.allowsStartup, isTrue);
  });

  test(
    'failed recheck cannot silently bypass an already confirmed mandatory update',
    () async {
      final checker = _Checker();
      final controller = AppUpdateController(checker: checker);
      addTearDown(controller.dispose);
      await controller.check();
      checker.action = () async => throw const AppFailure('Store unavailable');
      await controller.check();
      expect(controller.stage, AppUpdateStage.failed);
      expect(controller.allowsStartup, isFalse);
    },
  );

  test(
    'initial check timeout permits startup and obsolete completion cannot reopen a gate',
    () async {
      final pending = Completer<AppUpdateOffer?>();
      final checker = _Checker()..action = () async => pending.future;
      final controller = AppUpdateController(
        checker: checker,
        checkTimeout: const Duration(milliseconds: 2),
      );
      addTearDown(controller.dispose);
      await controller.check();
      expect(controller.allowsStartup, isTrue);
      pending.complete(_offer());
      await Future<void>.delayed(Duration.zero);
      expect(controller.allowsStartup, isTrue);
    },
  );

  test(
    'disposal during a check ignores completion without notifying disposed listeners',
    () async {
      final pending = Completer<AppUpdateOffer?>();
      final checker = _Checker()..action = () async => pending.future;
      final controller = AppUpdateController(checker: checker);
      final future = controller.check();
      controller.dispose();
      pending.complete(_offer());
      await future;
      expect(controller.offer, isNull);
    },
  );
}

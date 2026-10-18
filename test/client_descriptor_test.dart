import 'dart:async';

import 'package:docdiary_ios/core/client_descriptor.dart';
import 'package:docdiary_ios/features/auth/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

const _device = DeviceSnapshot(
  brand: 'Apple',
  model: 'iPhone17,3',
  systemName: 'iOS',
  systemVersion: '18.6',
);

ClientMetadataCollector _collector({
  Future<String?> Function()? wifi,
  Future<String?> Function()? public,
  Future<List<ClientNetworkAddress>> Function()? interfaces,
  Future<DeviceSnapshot> Function()? device,
  String Function()? hostname,
  Duration? timeout,
}) => ClientMetadataCollector(
  readDevice: device ?? () async => _device,
  readWifiIp: wifi ?? () async => '192.168.1.114',
  readPublicIp: public ?? () async => '8.8.8.8',
  readInterfaces: interfaces ?? () async => [],
  readHostname: hostname ?? () => 'my-iphone.local',
  fallbackOs: () => 'Darwin actual fallback',
  fieldTimeout: timeout ?? const Duration(seconds: 1),
);

void main() {
  test(
    'real device fields and Wi-Fi IP replace placeholders with no public call',
    () async {
      var calls = 0;
      final value =
          await _collector(
            public: () async {
              calls++;
              return '8.8.8.8';
            },
          ).collect();
      expect(value.host, 'Apple iPhone17,3');
      expect(value.os, 'iOS 18.6');
      expect(value.hostUser, 'my-iphone.local');
      expect(value.ip, '192.168.1.114');
      expect(value.ipSource, ClientIpSource.wifi);
      expect(calls, 0);
    },
  );

  test(
    'missing Wi-Fi uses public IPv4 or IPv6 as returned, not a dummy address',
    () async {
      for (final ip in ['8.8.8.8', '2001:4860:4860::8888']) {
        final value =
            await _collector(
              wifi: () async => null,
              public: () async => ip,
            ).collect();
        expect(value.ip, ip);
        expect(value.ipSource, ClientIpSource.public);
      }
    },
  );

  test(
    'public-IP failure falls back to actual cellular interfaces and prefers IPv4',
    () async {
      final value =
          await _collector(
            wifi: () async => '0.0.0.0',
            public: () async => throw StateError('Echo unavailable'),
            interfaces:
                () async => const [
                  ClientNetworkAddress('utun0', '10.8.0.4'),
                  ClientNetworkAddress('pdp_ip0', '2001:4860::1'),
                  ClientNetworkAddress('lo0', '127.0.0.1'),
                  ClientNetworkAddress('pdp_ip0', '100.64.2.3'),
                ],
          ).collect();
      expect(value.ip, '100.64.2.3');
      expect(value.ipSource, ClientIpSource.interface);
    },
  );

  test(
    'when every metadata API fails, missing values remain unknown and actual OS fallback is retained',
    () async {
      final value =
          await _collector(
            device: () async => throw StateError('Plugin failed'),
            wifi: () async => throw StateError('No Wi-Fi'),
            public: () async => throw StateError('Offline'),
            interfaces: () async => throw StateError('No interfaces'),
            hostname: () => throw StateError('Denied'),
          ).collect();
      expect(value.host, isEmpty);
      expect(value.hostUser, isEmpty);
      expect(value.ip, isEmpty);
      expect(value.os, 'Darwin actual fallback');
      expect(value.ipSource, ClientIpSource.unavailable);
    },
  );

  test(
    'a stalled plugin times out and permits the next real IP fallback',
    () async {
      final blocked = Completer<String?>();
      final value =
          await _collector(
            wifi: () async => blocked.future,
            timeout: const Duration(milliseconds: 2),
          ).collect();
      expect(value.ip, '8.8.8.8');
    },
  );

  test(
    'loopback, link-local, wildcard, multicast and unreadable addresses cannot enter loginLog',
    () {
      for (final value in [
        '',
        'null',
        '127.0.0.1',
        '::1',
        '169.254.169.254',
        'fe80::1',
        '0.0.0.0',
        '::',
        '255.255.255.255',
        '224.0.0.1',
        'not an IP',
        '8.8.8.8\r\nX:bad',
      ]) {
        expect(usableClientIp(value), isNull, reason: value);
      }
    },
  );

  test(
    'header metadata removes control characters and safely encodes Unicode',
    () {
      expect(clientHeader('Apple\r\niPhone17,3'), 'Apple  iPhone17,3');
      expect(clientHeader('আমার ফোন'), Uri.encodeComponent('আমার ফোন'));
    },
  );

  test(
    'public echo sends no identity headers and rejects unusable endpoint/response values',
    () async {
      final t = FakeTransport()..onGet = (_) async => {'ip': '8.8.8.8'};
      expect(
        await PublicIpEcho(t, Uri.parse('https://example.test/ip')).fetch(),
        '8.8.8.8',
      );
      expect(t.requests.single.headers, isEmpty);
      expect(
        await PublicIpEcho(t, Uri.parse('http://example.test/ip')).fetch(),
        isNull,
      );
      expect(t.requests, hasLength(1));
      t.onGet = (_) async => {'ip': '0.0.0.0'};
      expect(
        await PublicIpEcho(t, Uri.parse('https://example.test/ip')).fetch(),
        isNull,
      );
    },
  );

  for (final admin in [false, true]) {
    test(
      '${admin ? 'admin' : 'doctor'} loginLog keeps all six native headers with the actual descriptor',
      () async {
        final h = Harness();
        if (admin) {
          h.loginResponse = adminLogin();
        }
        await h.signIn();
        final before = h.posts.length;
        final profiles = ProfileRepository(
          h.transport,
          now: () => h.now,
          describeClient: () async => await _collector().collect(),
        );
        await profiles.open(h.auth.session!);
        final log = h.posts.last;
        expect(log.uri.path, endsWith('/doc_dashboard/loginLog'));
        expect(log.headers, {
          'P_IULL_USER_ID': admin ? 'example.admin' : 'D-10',
          'P_IULL_CLIENT_HOST_NAME': 'Apple iPhone17,3',
          'P_IULL_CLIENT_IP_ADDR': '192.168.1.114',
          'P_IULL_CLIENT_HOST_USER_NAME': 'my-iphone.local',
          'P_IULL_SESSION_USER_ID': admin ? '70' : '10',
          'P_IULL_OS_NAME': 'iOS 18.6',
        });
        expect(h.posts.length, before + 1);
        final posts = h.posts.length;
        await profiles.open(h.auth.session!, recordLogin: false);
        expect(h.posts.length, posts);
      },
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

import 'native_json.dart';
import 'transport.dart';

enum ClientIpSource { wifi, public, interface, unavailable }

class ClientDescriptor {
  const ClientDescriptor({
    this.host = '',
    this.ip = '',
    this.hostUser = '',
    this.os = '',
    this.ipSource = ClientIpSource.unavailable,
  });
  final String host, ip, hostUser, os;
  final ClientIpSource ipSource;

  static Future<ClientDescriptor> collect() async =>
      await ClientMetadataCollector().collect();
}

class DeviceSnapshot {
  const DeviceSnapshot({
    required this.brand,
    required this.model,
    required this.systemName,
    required this.systemVersion,
  });
  final String brand, model, systemName, systemVersion;

  static Future<DeviceSnapshot> read() async {
    if (Platform.isIOS) {
      final info = await DeviceInfoPlugin().iosInfo;
      return DeviceSnapshot(
        brand: 'Apple',
        model: info.utsname.machine,
        systemName: info.systemName,
        systemVersion: info.systemVersion,
      );
    }
    // Useful for previews/tests; this project still publishes only to iOS.
    return DeviceSnapshot(
      brand: '',
      model: Platform.operatingSystem,
      systemName: '',
      systemVersion: Platform.operatingSystemVersion,
    );
  }
}

class ClientNetworkAddress {
  const ClientNetworkAddress(this.interface, this.address);
  final String interface, address;
}

/// Wi-Fi first, then an HTTPS public-IP echo for cellular/VPN/IPv6, then actual
/// local interfaces. Optional metadata failures cannot break a valid sign-in.
class ClientMetadataCollector {
  ClientMetadataCollector({
    Future<DeviceSnapshot> Function()? readDevice,
    Future<String?> Function()? readWifiIp,
    Future<String?> Function()? readPublicIp,
    Future<List<ClientNetworkAddress>> Function()? readInterfaces,
    String Function()? readHostname,
    String Function()? fallbackOs,
    this.fieldTimeout = const Duration(seconds: 2),
  }) : readDevice = readDevice ?? DeviceSnapshot.read,
       readWifiIp = readWifiIp ?? NetworkInfo().getWifiIP,
       readPublicIp = readPublicIp ?? PublicIpEcho.fetchConfigured,
       readInterfaces = readInterfaces ?? _interfaces,
       readHostname = readHostname ?? (() => Platform.localHostname),
       fallbackOs = fallbackOs ?? (() => Platform.operatingSystemVersion);

  final Future<DeviceSnapshot> Function() readDevice;
  final Future<String?> Function() readWifiIp, readPublicIp;
  final Future<List<ClientNetworkAddress>> Function() readInterfaces;
  final String Function() readHostname, fallbackOs;
  final Duration fieldTimeout;

  static Future<List<ClientNetworkAddress>> _interfaces() async {
    final networks = await NetworkInterface.list(includeLinkLocal: false);
    return [
      for (final network in networks)
        for (final address in network.addresses)
          ClientNetworkAddress(network.name, address.address),
    ];
  }

  Future<T?> _optional<T>(Future<T?> Function() read) async {
    try {
      return await read().timeout(fieldTimeout);
    } catch (_) {
      return null;
    }
  }

  Future<({String value, ClientIpSource source})> _ip() async {
    final wifi = usableClientIp(await _optional(readWifiIp));
    if (wifi != null) {
      return (value: wifi, source: ClientIpSource.wifi);
    }
    final public = usableClientIp(await _optional(readPublicIp));
    if (public != null) {
      return (value: public, source: ClientIpSource.public);
    }
    final interfaces = List<ClientNetworkAddress>.of(
      await _optional(readInterfaces) ?? <ClientNetworkAddress>[],
    );
    // Prefer Wi-Fi/cellular IPv4, then their IPv6, before other live interfaces.
    int rank(ClientNetworkAddress item) =>
        (item.interface == 'en0' || item.interface.startsWith('pdp_ip')
            ? 0
            : 2) +
        (item.address.contains(':') ? 1 : 0);
    interfaces.sort((a, b) => rank(a).compareTo(rank(b)));
    for (final item in interfaces) {
      final value = usableClientIp(item.address);
      if (value != null) {
        return (value: value, source: ClientIpSource.interface);
      }
    }
    return (value: '', source: ClientIpSource.unavailable);
  }

  Future<ClientDescriptor> collect() async {
    final deviceFuture = _optional(readDevice);
    final ipFuture = _ip();
    var hostname = '';
    var osFallback = '';
    try {
      hostname = readHostname();
    } catch (_) {
      /* Optional host metadata. */
    }
    try {
      osFallback = fallbackOs();
    } catch (_) {
      /* Optional OS metadata. */
    }
    final device = await deviceFuture;
    final ip = await ipFuture;
    return ClientDescriptor(
      host: clientHeader(
        [
          device?.brand ?? '',
          device?.model ?? '',
        ].where((s) => s.trim().isNotEmpty).join(' '),
      ),
      ip: ip.value,
      ipSource: ip.source,
      hostUser: clientHeader(hostname),
      os: clientHeader(
        device == null
            ? osFallback
            : [
              device.systemName,
              device.systemVersion,
            ].where((s) => s.trim().isNotEmpty).join(' '),
      ),
    );
  }
}

String? usableClientIp(String? value) {
  final text = value?.trim() ?? '';
  final address = InternetAddress.tryParse(text);
  if (address == null ||
      address.isLoopback ||
      address.isLinkLocal ||
      text == '0.0.0.0' ||
      text == '::' ||
      text == '255.255.255.255' ||
      address.isMulticast) {
    return null;
  }
  return address.address;
}

/// Header values cannot contain CR/LF. Preserve normal values and percent-encode
/// unexpected Unicode hostnames instead of failing the whole login request.
String clientHeader(String value) {
  final clean = value.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ').trim();
  final bounded = clean.length > 256 ? clean.substring(0, 256) : clean;
  return bounded.runes.any((r) => r > 127)
      ? Uri.encodeComponent(bounded)
      : bounded;
}

class PublicIpEcho {
  PublicIpEcho(this.transport, this.endpoint);
  final Transport transport;
  final Uri endpoint;

  Future<String?> fetch() async {
    if (endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty) {
      return null;
    }
    final response = await transport.get(endpoint);
    return usableClientIp(nativeText(response['ip']));
  }

  static Future<String?> fetchConfigured() async {
    const url = String.fromEnvironment(
      'DOCDIARY_PUBLIC_IP_URL',
      defaultValue: 'https://api64.ipify.org?format=json',
    );
    if (url.isEmpty) {
      return null; // Can be disabled or replaced by a first-party HTTPS echo.
    }
    final client = IoTransport(timeout: const Duration(seconds: 2));
    try {
      final uri = Uri.tryParse(url);
      return uri == null ? null : await PublicIpEcho(client, uri).fetch();
    } finally {
      client.close();
    }
  }
}

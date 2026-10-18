import '../core/native_json.dart';
import '../core/transport.dart';

class ServerDirectory {
  ServerDirectory(this.transport);
  final Transport transport;

  static final directoryUri = Uri.parse(
    'https://raw.githubusercontent.com/shuvo934/Story/refs/heads/master/docDiaryServers',
  );

  // Copied from DocLogin.readApiText, native version 1.3.9.5.
  static const fallbackAddresses = [
    'http://103.56.208.123:8001/apex/cstar_local/',
    'http://103.73.227.28:8080/cstar/cstar-ramp/',
    'http://202.4.109.126:8003/crps/crp_savar/',
    'http://144.48.119.59:8002/apex/crp_mirpur/',
    'http://103.73.227.28:8080/cstar/cstar_bsd/',
  ];

  static List<Uri> parse(String contents) {
    final result = <Uri>[];
    for (final raw in contents
        .replaceFirst('\uFEFF', '')
        .split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      try {
        final uri = apiBase(line);
        if (!result.contains(uri)) result.add(uri);
      } catch (_) {
        // One invalid line must not prevent other configured centres loading.
      }
    }
    return result;
  }

  Future<List<Uri>> load() async {
    try {
      final servers = parse(await transport.getText(directoryUri));
      if (servers.isNotEmpty) return servers;
    } catch (_) {
      // Match the native fallback when the public directory is unavailable.
    }
    return fallbackAddresses.map(apiBase).toList(growable: false);
  }
}

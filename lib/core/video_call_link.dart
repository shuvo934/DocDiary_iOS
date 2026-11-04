import 'package:url_launcher/url_launcher.dart';

/// Opens an appointment or profile meeting URL and returns any error to show.
Future<String?> openVideoCallLink(
  String link, {
  Future<bool> Function(Uri)? open,
}) async {
  final value = link.trim();
  if (value.isEmpty) return 'Video call is not available yet';

  final uri = Uri.tryParse(value);
  if (uri == null ||
      !const ['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return 'Video call link is invalid. Please contact your administrator.';
  }

  const error = 'Could not open the video call link.';
  try {
    final launch =
        open ?? (url) => launchUrl(url, mode: LaunchMode.externalApplication);
    return await launch(uri).timeout(const Duration(seconds: 10))
        ? null
        : error;
  } catch (_) {
    return error;
  }
}

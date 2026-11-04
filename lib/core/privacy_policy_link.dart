import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyLink extends StatelessWidget {
  const PrivacyPolicyLink({super.key, this.compact = false});

  final bool compact;
  static final _url = Uri.tryParse(
    const String.fromEnvironment(
      'DOCDIARY_PRIVACY_POLICY_URL',
      defaultValue: 'https://privacy.techterrain-it.com/',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty) {
      return const SizedBox.shrink();
    }
    Future<void> open() async {
      try {
        if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
      } catch (_) {
        // The user can retry if the system browser could not open the link.
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the Privacy Policy.')),
        );
      }
    }

    return compact
        ? IconButton(
          tooltip: 'Privacy Policy',
          onPressed: open,
          icon: const Icon(Icons.privacy_tip_outlined),
        )
        : TextButton(onPressed: open, child: const Text('Privacy Policy'));
  }
}

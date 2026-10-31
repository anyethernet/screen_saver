import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = tr(context);
    return Scaffold(
      appBar: AppBar(title: Text(text.about)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(text.aboutBody, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          Text(text.aboutWindows),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => launchUrl(Uri.parse(windowsSetupUrl), mode: LaunchMode.externalApplication),
            child: Text(text.downloadWindows),
          ),
          const SizedBox(height: 28),
          Text(text.privacy, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(text.privacyBody),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => launchUrl(Uri.parse(privacyPolicyUrl), mode: LaunchMode.externalApplication),
            child: Text(text.openPrivacy),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'about_page.dart';
import 'app_model.dart';
import 'camera_page.dart';
import 'l10n.dart';
import 'viewer_page.dart';
import 'widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final text = S(model.language);
        return Scaffold(
          appBar: AppBar(
            title: Text(text.appName),
            actions: [
              TextButton(
                onPressed: () => model.setLanguage(model.language == 'ko' ? 'en' : 'ko'),
                child: Text(model.language == 'ko' ? 'EN' : '한글', style: const TextStyle(color: cream)),
              ),
              IconButton(
                tooltip: text.about,
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AboutPage()));
                },
                icon: const Icon(Icons.info_outline),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(text.homeIntro, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(text.homeWindows, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(windowsReleasesUrl), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.download),
                label: Text(text.downloadWindows),
              ),
              const SizedBox(height: 20),
              Text(text.languageLabel, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('English')),
                  ButtonSegment(value: 'ko', label: Text('한국어')),
                ],
                selected: {model.language},
                onSelectionChanged: (values) => model.setLanguage(values.first),
              ),
              const SizedBox(height: 20),
              _RoleCard(
                icon: Icons.videocam,
                title: text.homeCamera,
                body: text.homeCameraBody,
                selected: model.role == AppModel.roleCamera,
                selectedLabel: text.lastRole,
                onTap: () => _open(context, AppModel.roleCamera),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.phone_android,
                title: text.away,
                body: text.awayBody,
                selected: model.role == AppModel.roleViewer,
                selectedLabel: text.lastRole,
                onTap: () => _open(context, AppModel.roleViewer),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _open(BuildContext context, String role) async {
    await model.setRole(role);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => role == AppModel.roleCamera
            ? CameraPage(model: model)
            : ViewerPage(model: model),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.selectedLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final String selectedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? amber : Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, color: navy, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(body),
                    if (selected) ...[
                      const SizedBox(height: 6),
                      Text(selectedLabel, style: const TextStyle(color: teal)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

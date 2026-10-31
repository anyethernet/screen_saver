import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_model.dart';
import 'l10n.dart';
import 'mjpeg.dart';
import 'widgets.dart';

class ViewerSettingsPage extends StatefulWidget {
  const ViewerSettingsPage({super.key, required this.model});

  final AppModel model;

  @override
  State<ViewerSettingsPage> createState() => _ViewerSettingsPageState();
}

class _ViewerSettingsPageState extends State<ViewerSettingsPage> {
  late final TextEditingController _url;
  late final TextEditingController _token;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: displayCameraAddress(widget.model.viewerUrl));
    _token = TextEditingController(text: widget.model.viewerToken);
  }

  @override
  void dispose() {
    final url = displayCameraAddress(_url.text);
    final token = _token.text.trim();
    unawaited(widget.model.setViewer(url: url, token: token));
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _save() {
    final url = displayCameraAddress(_url.text);
    if (_url.text != url) _url.text = url;
    return widget.model.setViewer(url: url, token: _token.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.model,
      builder: (context, _) {
        final text = tr(context);
        return Scaffold(
          appBar: AppBar(title: Text(text.viewerSettings)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: text.viewerIp,
                  hintText: '100.x.x.x',
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 8),
              Text(text.viewerIpHelp),
              const SizedBox(height: 12),
              TextField(
                controller: _token,
                decoration: InputDecoration(labelText: text.token),
                onSubmitted: (_) => _save(),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: widget.model.allowBadCert,
                onChanged: (value) => widget.model.setViewer(insecure: value ?? false),
                title: Text(text.allowBadCert),
                subtitle: Text(text.allowBadCertHelp),
              ),
              const SizedBox(height: 12),
              const TailscaleCard(),
              const SizedBox(height: 20),
              Text(text.homeWindows),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(windowsSetupUrl), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.download),
                label: Text(text.downloadWindows),
              ),
            ],
          ),
        );
      },
    );
  }
}

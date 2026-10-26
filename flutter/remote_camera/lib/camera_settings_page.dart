import 'dart:async';

import 'package:flutter/material.dart';

import 'addresses.dart';
import 'app_model.dart';
import 'iot_device.dart';
import 'iot_discover.dart';
import 'l10n.dart';
import 'mjpeg.dart';
import 'native_bridge.dart';
import 'widgets.dart';

class CameraSettingsPage extends StatefulWidget {
  const CameraSettingsPage({super.key, required this.model});

  final AppModel model;

  @override
  State<CameraSettingsPage> createState() => _CameraSettingsPageState();
}

class _CameraSettingsPageState extends State<CameraSettingsPage> {
  late final TextEditingController _port;
  late final TextEditingController _token;
  bool _showToken = false;
  bool _finding = false;
  String _findMessage = '';
  List<String> _addresses = [];
  List<FoundDevice> _found = [];

  @override
  void initState() {
    super.initState();
    _port = TextEditingController(text: '${widget.model.serverPort}');
    _token = TextEditingController(text: widget.model.serverToken);
    _loadAddresses();
  }

  @override
  void dispose() {
    final port = int.tryParse(_port.text.trim());
    final token = _token.text.trim();
    unawaited(
      widget.model.setServer(
        token: token,
        port: port != null && port >= 1 && port <= 65535 ? port : null,
      ),
    );
    _port.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    try {
      final addresses = await localIpv4();
      if (!mounted) return;
      setState(() => _addresses = addresses);
    } on Object {
      // The main screen still shows an address when one is found later.
    }
  }

  Future<void> _save() async {
    final port = int.tryParse(_port.text.trim());
    await widget.model.setServer(
      token: _token.text.trim(),
      port: port != null && port >= 1 && port <= 65535 ? port : null,
    );
  }

  Future<void> _findDevices() async {
    setState(() {
      _finding = true;
      _findMessage = '';
      _found = [];
    });
    try {
      final found = await discoverHomeDevices();
      if (!mounted) return;
      setState(() {
        _found = found;
        _findMessage = found.isEmpty ? tr(context).noneFound : '';
      });
    } on Object {
      if (!mounted) return;
      setState(() => _findMessage = tr(context).findFailed);
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  Future<void> _editDevice({IotDevice? existing, bool create = false}) async {
    final saved = await showDialog<IotDevice>(
      context: context,
      builder: (context) => _DeviceDialog(existing: existing, create: create || existing == null),
    );
    if (saved == null) return;
    await widget.model.saveDevice(saved);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.model,
      builder: (context, _) {
        final text = tr(context);
        return Scaffold(
          appBar: AppBar(title: Text(text.cameraSettings)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: text.direction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text.directionHelp),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'auto', label: Text(text.auto)),
                        ButtonSegment(value: 'portrait', label: Text(text.lockPortrait)),
                        ButtonSegment(value: 'landscape', label: Text(text.lockLandscape)),
                      ],
                      selected: {widget.model.orientationMode},
                      onSelectionChanged: (selected) {
                        widget.model.setOrientationMode(selected.first);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: text.connection,
                child: Column(
                  children: [
                    TextField(
                      controller: _port,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: text.port),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(text.restartAfterPort),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _token,
                      obscureText: !_showToken,
                      decoration: InputDecoration(
                        labelText: text.token,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _showToken = !_showToken),
                          icon: Icon(_showToken ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                      onSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(text.emptyTokenWarning),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () async {
                            _token.text = createToken();
                            await _save();
                          },
                          child: Text(text.newToken),
                        ),
                        TextButton(
                          onPressed: () => copyText(context, _token.text.trim(), text.token),
                          child: Text(text.copyToken),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const TailscaleCard(),
              const SizedBox(height: 12),
              SectionCard(
                title: text.otherIps,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_addresses.isEmpty)
                      Text(text.noAddressYet)
                    else
                      for (final ip in _addresses)
                        _urlRow(ip, isTailscaleAddress(ip) ? 'Tailscale' : text.homeAddress),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: text.homeDevices,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text.deviceHelp),
                    const SizedBox(height: 12),
                    for (final device in widget.model.devices)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(device.name),
                        subtitle: Text(device.onUrl.isEmpty ? text.noOnUrl : device.onUrl),
                        onTap: () => _editDevice(existing: device),
                        trailing: IconButton(
                          onPressed: () => widget.model.removeDevice(device.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    if (_finding) const LinearProgressIndicator(),
                    if (_findMessage.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_findMessage),
                    ],
                    for (final device in _found)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(device.name),
                        subtitle: Text(device.kind),
                        trailing: TextButton(
                          onPressed: () => _editDevice(
                            create: true,
                            existing: IotDevice(
                              id: newDeviceId(),
                              name: device.name,
                              onUrl: device.onUrl,
                              offUrl: device.offUrl,
                            ),
                          ),
                          child: Text(text.add),
                        ),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _finding ? null : _findDevices,
                          icon: const Icon(Icons.search),
                          label: Text(text.finding(_finding)),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _editDevice(create: true),
                          icon: const Icon(Icons.add),
                          label: Text(text.addManually),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(text.batteryNote),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => NativeBridge.requestBatteryUnrestricted(),
                child: Text(text.unrestrictBattery),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _urlRow(String url, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(url)),
          IconButton(
            onPressed: () => copyText(context, url, label),
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
    );
  }
}

class _DeviceDialog extends StatefulWidget {
  const _DeviceDialog({this.existing, this.create = false});

  final IotDevice? existing;
  final bool create;

  @override
  State<_DeviceDialog> createState() => _DeviceDialogState();
}

class _DeviceDialogState extends State<_DeviceDialog> {
  late final TextEditingController _name;
  late final TextEditingController _on;
  late final TextEditingController _off;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _on = TextEditingController(text: existing?.onUrl ?? '');
    _off = TextEditingController(text: existing?.offUrl ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _on.dispose();
    _off.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final onUrl = _on.text.trim();
    final offUrl = _off.text.trim();
    if (name.isEmpty) {
      setState(() => _error = tr(context).needName);
      return;
    }
    if (onUrl.isEmpty && offUrl.isEmpty) {
      setState(() => _error = tr(context).needOneUrl);
      return;
    }
    Navigator.of(context).pop(
      IotDevice(
        id: widget.existing?.id ?? newDeviceId(),
        name: name,
        onUrl: onUrl,
        offUrl: offUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = tr(context);
    return AlertDialog(
      title: Text(text.deviceTitle(widget.create)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: InputDecoration(labelText: text.name)),
            const SizedBox(height: 12),
            TextField(
              controller: _on,
              decoration: InputDecoration(
                labelText: text.onUrl,
                hintText: 'http://192.168.0.50/cm?cmnd=Power%20On',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _off,
              decoration: InputDecoration(
                labelText: text.offUrl,
                hintText: 'http://192.168.0.50/cm?cmnd=Power%20Off',
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_error, style: const TextStyle(color: Color(0xFF9B2C2C))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(text.cancel)),
        FilledButton(onPressed: _save, child: Text(text.save)),
      ],
    );
  }
}

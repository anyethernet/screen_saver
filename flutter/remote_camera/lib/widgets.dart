import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n.dart';
import 'addresses.dart';
import 'mjpeg.dart';
import 'native_bridge.dart';

const navy = Color(0xFF0B1F3A);
const cream = Color(0xFFF6F1E7);
const amber = Color(0xFFE8A83E);
const teal = Color(0xFF2E8F94);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: navy,
    primary: navy,
    secondary: amber,
    surface: cream,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: navy,
      foregroundColor: cream,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: amber,
        foregroundColor: navy,
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

Future<void> copyText(BuildContext context, String value, String label) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(tr(context).copied(label))),
  );
}

class TailscaleCard extends StatefulWidget {
  const TailscaleCard({super.key});

  @override
  State<TailscaleCard> createState() => _TailscaleCardState();
}

class _TailscaleCardState extends State<TailscaleCard> with WidgetsBindingObserver {
  String _phase = 'checking';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final installed = await NativeBridge.tailscaleInstalled();
    if (!mounted) return;
    if (!installed) {
      setState(() => _phase = 'missing');
      return;
    }
    final addresses = await localIpv4();
    final hasAddress = addresses.any(isTailscaleAddress);
    final connected = hasAddress || await NativeBridge.tailscaleConnected();
    if (!mounted) return;
    setState(() => _phase = connected ? 'up' : 'down');
  }

  Future<void> _open(String message) async {
    setState(() => _busy = true);
    final outcome = await NativeBridge.openTailscale();
    if (!mounted) return;
    final text = tr(context);
    final outcomeText = switch (outcome) {
      'opened' => message,
      'store' => text.tailscaleStore,
      _ => text.tailscaleMissing,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(outcomeText)));
    setState(() => _busy = false);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final text = tr(context);
    final status = switch (_phase) {
      'missing' => text.notInstalled,
      'up' => text.connected,
      'down' => text.disconnect,
      _ => text.checking,
    };
    return SectionCard(
      title: text.tailscale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text.statusLine(status)),
          const SizedBox(height: 8),
          Text(text.tailscaleHelp),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy ? null : () => _open(text.askTailscaleOn),
                child: Text(text.connect),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _open(text.askTailscaleOff),
                child: Text(text.disconnect),
              ),
              TextButton(onPressed: _busy ? null : _refresh, child: Text(text.checkAgain)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Largest rectangle of [aspect] (width / height) that fits the parent.
class FittedStream extends StatelessWidget {
  const FittedStream({super.key, required this.bytes, required this.aspect});

  final Uint8List? bytes;
  final double? aspect;

  @override
  Widget build(BuildContext context) {
    final jpeg = bytes;
    if (jpeg == null) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = aspect != null && aspect! > 0 ? aspect! : 4 / 3;
        var width = constraints.maxWidth;
        var height = width / ratio;
        if (!height.isFinite || height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * ratio;
        }
        if (!width.isFinite || width > constraints.maxWidth) {
          width = constraints.maxWidth;
          height = width / ratio;
        }
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Image.memory(jpeg, fit: BoxFit.fill, gaplessPlayback: true),
          ),
        );
      },
    );
  }
}

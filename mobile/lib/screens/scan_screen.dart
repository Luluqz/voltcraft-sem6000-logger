import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'logger_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final List<ScanResult> _results = [];
  StreamSubscription<List<ScanResult>>? _sub;
  bool _scanning = false;

  @override
  void dispose() {
    _sub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    setState(() {
      _results.clear();
      _scanning = true;
    });

    _sub?.cancel();
    _sub = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _results
          ..clear()
          ..addAll(results);
      });
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    setState(() => _scanning = false);
  }

  bool _looksLikeSem6000(ScanResult r) {
    final name = r.device.platformName.toLowerCase();
    return name.contains('sem') || name.contains('voltcraft');
  }

  void _showDisclaimer(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('À propos'),
        content: const Text(
          'Cette application est un projet indépendant, non officielle et '
          'non affiliée à Voltcraft, Conrad Electronic, ni à aucun de leurs '
          'partenaires. "Voltcraft" et "SEM6000" sont des marques de leurs '
          'propriétaires respectifs, citées uniquement pour indiquer la '
          'compatibilité de l\'application avec cet appareil.\n\n'
          'Protocole basé sur une documentation communautaire '
          'reverse-engineered (Heckie75/voltcraft-sem-6000, licence MIT).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Power Logger — Appareils'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'À propos',
            onPressed: () => _showDisclaimer(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanning ? null : _startScan,
        child: Icon(_scanning ? Icons.hourglass_top : Icons.search),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'App non officielle, non affiliée à Voltcraft/Conrad Electronic.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, i) {
                final r = _results[i];
                final name = r.device.platformName.isEmpty
                    ? '(sans nom)'
                    : r.device.platformName;
                return ListTile(
                  leading: _looksLikeSem6000(r)
                      ? const Icon(Icons.bolt, color: Colors.orange)
                      : const Icon(Icons.bluetooth),
                  title: Text(name),
                  subtitle: Text(r.device.remoteId.str),
                  onTap: () {
                    FlutterBluePlus.stopScan();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => LoggerScreen(device: r.device),
                    ));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

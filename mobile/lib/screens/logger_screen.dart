import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../ble/sem6000_ble.dart';
import '../csv_logger.dart';
import '../protocol.dart';

class LoggerScreen extends StatefulWidget {
  const LoggerScreen({super.key, required this.device});

  final BluetoothDevice device;

  @override
  State<LoggerScreen> createState() => _LoggerScreenState();
}

class _LoggerScreenState extends State<LoggerScreen> {
  final _pinController = TextEditingController(text: '0000');
  late final Sem6000Ble _ble;
  CsvLogger? _csvLogger;
  Timer? _pollTimer;
  Measurement? _last;
  String _status = 'Déconnecté';
  bool _connected = false;
  bool _logging = false;

  @override
  void initState() {
    super.initState();
    _ble = Sem6000Ble(widget.device);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ble.disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _status = 'Connexion...');
    try {
      await _ble.connect();
      setState(() => _status = 'Authentification...');
      await _ble.authenticate(_pinController.text);
      setState(() {
        _status = 'Connecté';
        _connected = true;
      });
    } catch (e) {
      await _ble.disconnect();
      setState(() => _status = 'Erreur: $e');
    }
  }

  Future<void> _startLogging() async {
    _csvLogger = await CsvLogger.create();
    setState(() => _logging = true);
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final m = await _ble.readOnce();
      if (m == null) return;
      setState(() => _last = m);
      await _csvLogger?.appendRow(m);
    });
  }

  void _stopLogging() {
    _pollTimer?.cancel();
    setState(() => _logging = false);
  }

  Future<void> _shareCsv() async {
    final file = _csvLogger?.file;
    if (file != null) {
      await Share.shareXFiles([XFile(file.path)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.device.platformName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_status, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (!_connected) ...[
              TextField(
                controller: _pinController,
                decoration: const InputDecoration(labelText: 'PIN (4 chiffres)'),
                keyboardType: TextInputType.number,
                maxLength: 4,
              ),
              ElevatedButton(onPressed: _connect, child: const Text('Connecter')),
            ],
            if (_connected) ...[
              if (_last != null) _MeasurementCard(m: _last!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _logging ? _stopLogging : _startLogging,
                child: Text(_logging ? 'Arrêter' : 'Démarrer l\'enregistrement'),
              ),
              if (_csvLogger != null)
                TextButton(onPressed: _shareCsv, child: const Text('Exporter le CSV')),
            ],
          ],
        ),
      ),
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  const _MeasurementCard({required this.m});

  final Measurement m;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${m.watts.toStringAsFixed(3)} W',
                style: Theme.of(context).textTheme.headlineMedium),
            Text('${m.voltage} V · ${m.amperes.toStringAsFixed(3)} A · ${m.frequency} Hz'),
            Text('Prise: ${m.powerOn ? "ON" : "OFF"}'),
            Text('Total (brut): ${m.totalConsumptionRaw}'),
          ],
        ),
      ),
    );
  }
}

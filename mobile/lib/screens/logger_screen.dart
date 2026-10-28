import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:share_plus/share_plus.dart';

import '../ble/sem6000_ble.dart';
import '../csv_logger.dart';
import '../protocol.dart';
import '../recording_task_handler.dart';

/// Foreground-service id for the recording notification. Arbitrary but
/// must stay constant across the app.
const _recordingServiceId = 6000;

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
  int _secondsElapsed = 0;
  final List<FlSpot> _wattsSpots = [];

  @override
  void initState() {
    super.initState();
    _ble = Sem6000Ble(widget.device);
    _initForegroundTask();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ble.disconnect();
    if (_logging) {
      FlutterForegroundTask.stopService();
    }
    super.dispose();
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sem6000_recording',
        channelName: 'Enregistrement SEM6000',
        channelDescription:
            'Notification affichée pendant l\'enregistrement CSV, pour '
            'empêcher Android de le stopper quand une autre app est au '
            'premier plan.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
      ),
    );
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
      _startPolling();
    } catch (e) {
      await _ble.disconnect();
      setState(() => _status = 'Erreur: $e');
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _secondsElapsed = 0;
    _wattsSpots.clear();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final m = await _ble.readOnce();
      _secondsElapsed++;
      if (m == null) return;
      setState(() {
        _last = m;
        _wattsSpots.add(FlSpot(_secondsElapsed.toDouble(), m.watts));
      });
      if (_logging) {
        await _csvLogger?.appendRow(m);
      }
    });
  }

  Future<void> _startLogging() async {
    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: _recordingServiceId,
      serviceTypes: const [ForegroundServiceTypes.connectedDevice],
      notificationTitle: 'Enregistrement SEM6000 en cours',
      notificationText: 'Mesures écrites dans le CSV même en arrière-plan.',
      callback: recordingTaskCallback,
    );
    if (result is ServiceRequestFailure) {
      setState(() => _status = 'Erreur: impossible de démarrer '
          'l\'enregistrement en arrière-plan (${result.error})');
      return;
    }

    _csvLogger = await CsvLogger.create();
    setState(() => _logging = true);
  }

  void _stopLogging() {
    FlutterForegroundTask.stopService();
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
      body: SingleChildScrollView(
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
              Text('Puissance (W) sur la session',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _PowerChart(spots: _wattsSpots),
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

class _PowerChart extends StatelessWidget {
  const _PowerChart({required this.spots});

  final List<FlSpot> spots;

  @override
  Widget build(BuildContext context) {
    if (spots.length < 2) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('En attente de données...')),
      );
    }
    final maxWatts = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxWatts * 1.1 + 1,
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
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

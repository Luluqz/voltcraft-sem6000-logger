import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../protocol.dart';

class Sem6000Ble {
  Sem6000Ble(this.device);

  final BluetoothDevice device;

  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;
  final StreamController<List<int>> _notifications =
      StreamController<List<int>>.broadcast();

  Future<void> connect() async {
    await device.connect(timeout: const Duration(seconds: 10));

    final services = await device.discoverServices();
    for (final service in services) {
      for (final char in service.characteristics) {
        final uuid = char.uuid.toString().toLowerCase();
        if (uuid == uuidWrite) _writeChar = char;
        if (uuid == uuidNotify) _notifyChar = char;
      }
    }

    if (_writeChar == null || _notifyChar == null) {
      throw StateError(
          "SEM6000 characteristics not found (device may not be a SEM6000, or PIN screen not paired).");
    }

    _notifyChar!.onValueReceived.listen(_notifications.add);
    await _notifyChar!.setNotifyValue(true);
  }

  Future<void> authenticate(String pin) async {
    final frame = buildAuthFrame(pin);
    await _writeChar!.write(frame, withoutResponse: true);
    try {
      await _notifications.stream.first.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      // No response to auth: continue anyway, matches sem6000.py behaviour.
    }
  }

  Future<Measurement?> readOnce() async {
    final frame = buildMeasureFrame();
    final next = _notifications.stream.first.timeout(
      const Duration(seconds: 3),
      onTimeout: () => <int>[],
    );
    await _writeChar!.write(frame, withoutResponse: true);
    final data = await next;
    if (data.isEmpty) return null;
    return parseMeasurement(data);
  }

  Future<void> disconnect() async {
    await _notifications.close();
    if (device.isConnected) {
      await device.disconnect();
    }
  }
}

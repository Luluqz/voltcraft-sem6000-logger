import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import 'protocol.dart';

class CsvLogger {
  CsvLogger._(this.file);

  final File file;

  static Future<CsvLogger> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/sem6000_$timestamp.csv');
    await file.writeAsString(
      const ListToCsvConverter().convert([
        [
          'timestamp',
          'power_on',
          'watts',
          'voltage',
          'amperes',
          'frequency_hz',
          'total_consumption_raw',
        ]
      ]) +
          '\n',
    );
    return CsvLogger._(file);
  }

  Future<void> appendRow(Measurement m) async {
    final row = const ListToCsvConverter().convert([
      [
        DateTime.now().toIso8601String(),
        m.powerOn,
        m.watts,
        m.voltage,
        m.amperes,
        m.frequency,
        m.totalConsumptionRaw,
      ]
    ]);
    await file.writeAsString('$row\n', mode: FileMode.append);
  }
}

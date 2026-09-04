import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import 'protocol.dart';

class CsvLogger {
  CsvLogger._(this.file);

  final File file;

  static Future<CsvLogger> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    // French-style date order (jj-mm-aaaa) for the filename shown to the
    // user when sharing, e.g. sem6000_04-09-2026_10-34-00.csv.
    final timestamp = '${two(now.day)}-${two(now.month)}-${now.year}_'
        '${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
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

  /// Lists every CSV recording previously saved by this app, newest first.
  static Future<List<File>> listFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final entries = await dir.list().toList();
    final files = entries
        .whereType<File>()
        .where((f) =>
            f.uri.pathSegments.last.startsWith('sem6000_') &&
            f.path.endsWith('.csv'))
        .toList();
    // Sort by modification time rather than filename, so display/ordering
    // never depends on the exact timestamp format used in the filename.
    final withDates = await Future.wait(
      files.map((f) async => MapEntry(f, await f.lastModified())),
    );
    withDates.sort((a, b) => b.value.compareTo(a.value));
    return withDates.map((e) => e.key).toList();
  }

  static Future<void> deleteFile(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

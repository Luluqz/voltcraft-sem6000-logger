import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'screens/scan_screen.dart';

void main() {
  FlutterForegroundTask.initCommunicationPort();
  runApp(const Sem6000App());
}

class Sem6000App extends StatelessWidget {
  const Sem6000App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Power Logger for SEM6000',
      theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
      home: const ScanScreen(),
    );
  }
}

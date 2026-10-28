import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Entry point for the foreground service's isolate.
///
/// The actual BLE polling and CSV writing stay in the main isolate (in
/// [LoggerScreen]'s `Timer.periodic`); this task does no work of its own.
/// Its only job is to back the persistent notification started by
/// `FlutterForegroundTask.startService`, which keeps the whole app process
/// at foreground priority so Android doesn't throttle/freeze the main
/// isolate's timer when another app comes to the front.
@pragma('vm:entry-point')
void recordingTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_NoopTaskHandler());
}

class _NoopTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

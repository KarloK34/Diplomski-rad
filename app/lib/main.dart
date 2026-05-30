import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:gait_sense/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Opens the port the foreground-service isolate uses to send data back to the
  // UI isolate. Must run before any addTaskDataCallback/sendDataToMain call.
  FlutterForegroundTask.initCommunicationPort();
  runApp(const GaitSenseApp());
}

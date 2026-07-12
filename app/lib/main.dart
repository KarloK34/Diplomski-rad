import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:gait_sense/app.dart';
import 'package:gait_sense/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Opens the isolate communication port — must run before any
  // addTaskDataCallback/sendDataToMain call.
  FlutterForegroundTask.initCommunicationPort();
  runApp(const GaitSenseApp());
}

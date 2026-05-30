import 'package:flutter/material.dart';
import 'package:gait_sense/screens/live_har_screen.dart';

/// Root MaterialApp.
class GaitSenseApp extends StatelessWidget {
  /// Default constructor.
  const GaitSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gait Sense',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LiveHarScreen(),
    );
  }
}

import 'package:flutter/material.dart';

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
      home: const _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gait Sense')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Home screen placeholder',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

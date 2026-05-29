import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/sensor_stream/sensor_stream_bloc.dart';
import 'package:gait_sense/screens/debug_sensors_screen.dart';
import 'package:gait_sense/services/sensor_service.dart';

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
      // The debug sensor readout is the temporary home while the live HAR
      // screen does not exist yet.
      home: BlocProvider(
        create: (_) => SensorStreamBloc(sensorService: SensorService()),
        child: const DebugSensorsScreen(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/sensor_stream/sensor_stream_bloc.dart';
import 'package:gait_sense/services/sensor_service.dart';

/// Provides a screen-scoped [SensorStreamBloc] wired to a fresh
/// [SensorService].
class DebugSensorsProvider extends StatelessWidget {
  /// Wraps [child] with a freshly created [SensorStreamBloc].
  const DebugSensorsProvider({required this.child, super.key});

  /// The subtree consuming [SensorStreamBloc].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SensorStreamBloc>(
      create: (_) => SensorStreamBloc(sensorService: SensorService()),
      child: child,
    );
  }
}

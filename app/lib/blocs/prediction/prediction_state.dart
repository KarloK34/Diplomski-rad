import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/activity_prediction.dart';

/// State of the prediction bloc.
class PredictionState extends Equatable {
  /// Creates a state.
  const PredictionState({
    required this.isRunning,
    required this.latestPrediction,
    required this.predictionCount,
  });

  /// The initial, idle state.
  const PredictionState.initial()
    : isRunning = false,
      latestPrediction = null,
      predictionCount = 0;

  /// Whether the bloc is consuming windows.
  final bool isRunning;

  /// The most recent prediction, or null before the first.
  final ActivityPrediction? latestPrediction;

  /// Number of predictions produced in the current run.
  final int predictionCount;

  /// Returns a copy with the given fields replaced.
  PredictionState copyWith({
    bool? isRunning,
    ActivityPrediction? latestPrediction,
    int? predictionCount,
  }) {
    return PredictionState(
      isRunning: isRunning ?? this.isRunning,
      latestPrediction: latestPrediction ?? this.latestPrediction,
      predictionCount: predictionCount ?? this.predictionCount,
    );
  }

  @override
  List<Object?> get props => [isRunning, latestPrediction, predictionCount];
}

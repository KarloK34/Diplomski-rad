import 'package:equatable/equatable.dart';
import 'package:gait_sense/models/feature_window.dart';

/// State of the feature pipeline. Exposed by `FeaturePipelineBloc`.
class FeaturePipelineState extends Equatable {
  /// Creates a state.
  const FeaturePipelineState({
    required this.isRunning,
    required this.latestWindow,
    required this.windowCount,
  });

  /// The initial, idle state.
  const FeaturePipelineState.initial()
    : isRunning = false,
      latestWindow = null,
      windowCount = 0;

  /// Whether the pipeline is consuming samples.
  final bool isRunning;

  /// The most recently produced normalized window, or null before the first.
  final FeatureWindow? latestWindow;

  /// Number of windows produced in the current run.
  final int windowCount;

  /// Returns a copy with the given fields replaced.
  FeaturePipelineState copyWith({
    bool? isRunning,
    FeatureWindow? latestWindow,
    int? windowCount,
  }) {
    return FeaturePipelineState(
      isRunning: isRunning ?? this.isRunning,
      latestWindow: latestWindow ?? this.latestWindow,
      windowCount: windowCount ?? this.windowCount,
    );
  }

  // windowCount changes on every emitted window, so it is a cheap discriminator
  // for state equality — avoids deep-comparing the 128×8 window tensor.
  @override
  List<Object?> get props => [isRunning, windowCount];
}

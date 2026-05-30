import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/feature_pipeline/feature_pipeline_event.dart';
import 'package:gait_sense/blocs/feature_pipeline/feature_pipeline_state.dart';
import 'package:gait_sense/models/sensor_sample.dart';
import 'package:gait_sense/services/feature_pipeline.dart';

/// Consumes the resampled [SensorSample] stream and emits normalized feature
/// windows via a causal [StreamingFeatureExtractor].
///
/// The bloc subscribes directly to the service-level sample stream (a broadcast
/// stream) rather than to `SensorStreamBloc`'s state, so it sees every sample
/// instead of only the latest-at-rebuild. The window math is the causal live
/// path documented in `feature_pipeline.dart`; numerical parity with the Python
/// reference is validated separately on the offline path
/// (`test/feature_pipeline_test.dart`).
class FeaturePipelineBloc
    extends Bloc<FeaturePipelineEvent, FeaturePipelineState> {
  /// Creates the bloc around the broadcast stream of resampled samples.
  FeaturePipelineBloc({required this._sampleStream})
    : super(const FeaturePipelineState.initial()) {
    on<FeaturePipelineStarted>(_onStarted);
    on<FeaturePipelineStopped>(_onStopped);
    on<FeaturePipelineSampleReceived>(_onSampleReceived);
  }

  final Stream<SensorSample> _sampleStream;
  final StreamingFeatureExtractor _extractor = StreamingFeatureExtractor();
  StreamSubscription<SensorSample>? _subscription;

  void _onStarted(
    FeaturePipelineStarted event,
    Emitter<FeaturePipelineState> emit,
  ) {
    if (state.isRunning) return;
    _extractor.reset();
    _subscription = _sampleStream.listen(
      (sample) => add(FeaturePipelineSampleReceived(sample)),
    );
    emit(
      const FeaturePipelineState(
        isRunning: true,
        latestWindow: null,
        windowCount: 0,
      ),
    );
  }

  Future<void> _onStopped(
    FeaturePipelineStopped event,
    Emitter<FeaturePipelineState> emit,
  ) async {
    await _subscription?.cancel();
    _subscription = null;
    emit(state.copyWith(isRunning: false));
  }

  void _onSampleReceived(
    FeaturePipelineSampleReceived event,
    Emitter<FeaturePipelineState> emit,
  ) {
    final window = _extractor.add(event.sample);
    if (window == null) return;
    emit(
      state.copyWith(
        latestWindow: window,
        windowCount: state.windowCount + 1,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

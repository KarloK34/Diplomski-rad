import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gait_sense/blocs/prediction/prediction_event.dart';
import 'package:gait_sense/blocs/prediction/prediction_state.dart';
import 'package:gait_sense/models/feature_window.dart';
import 'package:gait_sense/services/har_inference.dart';

/// Sequential transformer: each window is fully classified before the next
/// starts. Inference shares one background isolate, so the default concurrent
/// transformer would let calls race and drop windows; serialize them here.
EventTransformer<E> _sequential<E>() {
  return (events, mapper) => events.asyncExpand(mapper);
}

/// Consumes [FeatureWindow]s and emits predictions via [HarInference].
///
/// Mirrors `FeaturePipelineBloc`: it subscribes directly to a broadcast stream
/// of windows (so it sees every window, not only the latest-at-rebuild) and
/// turns each into a prediction.
class PredictionBloc extends Bloc<PredictionEvent, PredictionState> {
  /// Creates the bloc. Named params use the private field names, matching
  /// `FeaturePipelineBloc`'s convention for injected stream/service deps.
  PredictionBloc({
    required this._windowStream,
    required this._inference,
  }) : super(const PredictionState.initial()) {
    on<PredictionStarted>(_onStarted);
    on<PredictionStopped>(_onStopped);
    on<PredictionWindowReceived>(_onWindowReceived, transformer: _sequential());
  }

  final Stream<FeatureWindow> _windowStream;
  final HarInference _inference;
  StreamSubscription<FeatureWindow>? _subscription;

  void _onStarted(PredictionStarted event, Emitter<PredictionState> emit) {
    if (state.isRunning) return;
    _subscription = _windowStream.listen(
      (window) => add(PredictionWindowReceived(window)),
    );
    emit(
      const PredictionState(
        isRunning: true,
        latestPrediction: null,
        predictionCount: 0,
      ),
    );
  }

  Future<void> _onStopped(
    PredictionStopped event,
    Emitter<PredictionState> emit,
  ) async {
    await _subscription?.cancel();
    _subscription = null;
    emit(state.copyWith(isRunning: false));
  }

  Future<void> _onWindowReceived(
    PredictionWindowReceived event,
    Emitter<PredictionState> emit,
  ) async {
    final prediction = await _inference.predict(event.window);
    emit(
      state.copyWith(
        latestPrediction: prediction,
        predictionCount: state.predictionCount + 1,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

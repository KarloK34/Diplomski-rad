"""Shared offline/streaming window recomputation for accuracy/agreement studies.

`streaming_vs_offline_in_the_wild.py` and `streaming_vs_offline_user_sessions.py`
both need predictions from the same raw IMU samples computed two ways --
offline (whole-session, non-causal) and a causal replay of
`StreamingFeatureExtractor.add()` (`app/lib/services/feature_pipeline.dart`) --
so this logic lives in one place rather than two divergent reimplementations
of the same causal-approximation question
(docs/tehnicko-objasnjenje-analize-hoda.md §3.5/§12.6/§13.3).
"""

from __future__ import annotations

from typing import TYPE_CHECKING

import numpy as np
import pandas as pd

from utils.orientation_invariant_features import (
    WALKING_FRAME_V2_COLS,
    compute_walking_frame_features_v2,
)

if TYPE_CHECKING:  # TensorFlow is only needed by the prediction helpers below.
    import tensorflow as tf

ACT_LABELS = ["dws", "ups", "wlk", "jog", "std", "sit"]

# StreamingFeatureExtractor defaults (feature_pipeline.dart).
WINDOW_SIZE = 128
STEP = 64
FS_HZ = 50.0
SMOOTH_SECONDS = 5.0
# Must exceed the smoothing kernel (round(SMOOTH_SECONDS * FS_HZ) = 250
# samples), or the walking-direction moving average degenerates to a no-op
# (see StreamingFeatureExtractor's doc comment in feature_pipeline.dart).
CONTEXT_SAMPLES = 250 + WINDOW_SIZE


def normalize_window(window: np.ndarray, eps: float = 1e-8) -> np.ndarray:
    """Instance Z-score, population std (`normalize_dyn` /
    `FeaturePipeline.normalizeWindow`)."""
    return (window - window.mean(axis=0, keepdims=True)) / (
        window.std(axis=0, keepdims=True) + eps
    )


def offline_windows(df_raw: pd.DataFrame) -> tuple[np.ndarray, list[int]]:
    """Whole-session (non-causal) windowing: every sample's walking-direction
    smoothing sees the entire recording, past and future -- what the model
    was trained on. Returns (windows, end_sample_index) so callers can align
    with recorded on-device predictions by `endSampleIndex`."""
    feats = compute_walking_frame_features_v2(
        df_raw, fs_hz=FS_HZ, smooth_seconds=SMOOTH_SECONDS,
        group_cols=None, keep_meta=False,
    )
    arr = feats[WALKING_FRAME_V2_COLS].to_numpy()
    windows, ends = [], []
    for st in range(0, len(arr) - WINDOW_SIZE + 1, STEP):
        windows.append(normalize_window(arr[st : st + WINDOW_SIZE]))
        ends.append(st + WINDOW_SIZE - 1)
    return np.array(windows), ends


def streaming_windows(df_raw: pd.DataFrame) -> tuple[np.ndarray, list[int]]:
    """Sample-by-sample replay of `StreamingFeatureExtractor.add()`: a
    trailing buffer capped at `CONTEXT_SAMPLES`, emitting every `STEP`
    samples once full. Because the buffer always ends at "now", the
    walking-direction smoothing is a trailing (causal) boxcar rather than the
    offline path's centred, whole-session one -- it always loses future
    context, which is the approximation under test. Emission points match
    `offline_windows` by construction, so results at the same list position
    cover the same raw samples in both paths."""
    n = len(df_raw)
    windows, ends = [], []
    i = WINDOW_SIZE - 1
    while i < n:
        buf_start = max(0, i - CONTEXT_SAMPLES + 1)
        buf = df_raw.iloc[buf_start : i + 1]
        feats = compute_walking_frame_features_v2(
            buf, fs_hz=FS_HZ, smooth_seconds=SMOOTH_SECONDS,
            group_cols=None, keep_meta=False,
        )
        arr = feats[WALKING_FRAME_V2_COLS].to_numpy()[-WINDOW_SIZE:]
        windows.append(normalize_window(arr))
        ends.append(i)
        i += STEP
    return np.array(windows), ends


def load_interpreter(tflite_path: str) -> tf.lite.Interpreter:
    """TensorFlow is imported lazily here (and in `predict_proba`) so that
    `offline_windows` / `streaming_windows` can be imported without it. Only the
    prediction studies need an interpreter; `ml/scripts/export_parity_fixtures.py`
    reuses `streaming_windows` to generate the Dart streaming-parity fixture and
    must run without TensorFlow installed."""
    import tensorflow as tf

    interp = tf.lite.Interpreter(model_path=tflite_path)
    interp.allocate_tensors()
    return interp


def predict_proba(interp: tf.lite.Interpreter, windows: np.ndarray) -> np.ndarray:
    """Runs the TFLite model over each window, returning the raw softmax
    vector per window (shape `(len(windows), len(ACT_LABELS))`), in the same
    class order as `ACT_LABELS` (confirmed against `models/
    cnn_final.preproc.json` `class_labels`, identical to the order
    `ActivityPrediction.probabilities` is persisted in by the app)."""
    in_idx = interp.get_input_details()[0]["index"]
    out_idx = interp.get_output_details()[0]["index"]
    probs = np.zeros((len(windows), len(ACT_LABELS)), dtype=np.float32)
    for i, w in enumerate(windows):
        interp.set_tensor(in_idx, w[None].astype(np.float32))
        interp.invoke()
        probs[i] = interp.get_tensor(out_idx)[0]
    return probs


def predict(interp: tf.lite.Interpreter, windows: np.ndarray) -> np.ndarray:
    """Runs the TFLite model over each window, returning argmax class indices
    (index into `ACT_LABELS`)."""
    return predict_proba(interp, windows).argmax(axis=1)


class ActivitySmoother:
    """Verbatim Python port of `ActivitySmoother`
    (`app/lib/services/activity_smoother.dart`, docs/tehnicko-objasnjenje-
    analize-hoda.md §5): causal rolling-majority vote over the last
    `window_size` raw labels, requiring `min_votes` agreeing votes once full,
    relaxed to a strict local majority while filling. Ties or insufficient
    votes fall back to the current raw label.

    Used by `ml/scripts/activity_smoother_ablation.py` to (a) replay the rule
    against simulated in-the-wild predictions and (b) reproduce the recorded
    on-device `label` from `rawLabel` sequences in `SessionLog` exports, as a
    parity check before trusting the port for (a).

    Dict iteration order matters here: Python dicts preserve insertion order,
    matching the Dart `LinkedHashMap`-backed vote tally (first-seen label
    wins ties) bit-for-bit.
    """

    def __init__(self, window_size: int = 5, min_votes: int = 3):
        assert window_size > 0
        assert 0 < min_votes <= window_size
        self.window_size = window_size
        self.min_votes = min_votes
        self._context: list[str] = []

    def reset(self) -> None:
        self._context.clear()

    def add(self, raw_label: str) -> str:
        self._context.append(raw_label)
        if len(self._context) > self.window_size:
            self._context.pop(0)

        counts: dict[str, int] = {}
        for label in self._context:
            counts[label] = counts.get(label, 0) + 1

        best_label, best_votes, tied = raw_label, 0, False
        for label, votes in counts.items():
            if votes > best_votes:
                best_label, best_votes, tied = label, votes, False
            elif votes == best_votes:
                tied = True

        required_votes = min(self.min_votes, len(self._context) // 2 + 1)
        if not tied and best_votes >= required_votes:
            return best_label
        return raw_label

    def smooth_sequence(self, raw_labels: list[str]) -> list[str]:
        """Resets the rolling context and replays `add()` over `raw_labels` in
        order -- matching `foreground_service.dart`'s reset-on-recording-commit
        behaviour (§5), so callers should pass exactly the raw-label sequence
        from one continuous recording, not multiple sessions concatenated."""
        self.reset()
        return [self.add(label) for label in raw_labels]


class SoftVoteSmoother:
    """Candidate alternative to `ActivitySmoother`'s hard majority vote,
    proposed (not yet implemented) in docs/tehnicko-objasnjenje-analize-hoda.md
    §13.14: average the last `window_size` raw softmax vectors and take the
    argmax, rather than voting over argmax labels. Averaging is well-defined
    even during the startup ramp, so no separate relaxed-threshold rule is
    needed for a partially-filled context.

    No Dart counterpart -- exists only for `ml/scripts/
    activity_smoother_ablation.py`; see that script's docstring for the
    citation status of softmax averaging as a smoothing technique.
    """

    def __init__(self, window_size: int = 5):
        assert window_size > 0
        self.window_size = window_size
        self._context: list[np.ndarray] = []

    def reset(self) -> None:
        self._context.clear()

    def add(self, probs: np.ndarray) -> str:
        self._context.append(np.asarray(probs, dtype=np.float64))
        if len(self._context) > self.window_size:
            self._context.pop(0)
        mean_probs = np.mean(self._context, axis=0)
        return ACT_LABELS[int(mean_probs.argmax())]

    def smooth_sequence(self, prob_seq) -> list[str]:
        """Resets the rolling context and replays `add()` over `prob_seq` in
        order -- same one-continuous-recording caveat as
        `ActivitySmoother.smooth_sequence`."""
        self.reset()
        return [self.add(p) for p in prob_seq]

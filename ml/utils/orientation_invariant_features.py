"""Orientation-invariant channel derivations for IMU windows.

The raw MotionSense channels (``userAcceleration.{x,y,z}``,
``rotationRate.{x,y,z}``, ``gravity.{x,y,z}``, ``attitude.{roll,pitch,yaw}``)
are defined in the phone-body frame. Their distributions change when the
phone is rotated inside a pocket, which is the main source of cross-device /
cross-orientation degradation observed in this project. Replacing the raw
axes with quantities that are invariant (or partially invariant) to rotation
of the phone is a standard preprocessing step for in-the-wild HAR.

References
----------
Henpraserttae, A., Thiemjarus, S., & Marukatat, S. (2011). Accurate
activity recognition using a mobile phone regardless of device orientation
and location. *Body Sensor Networks (BSN) 2011*, 41-46.
https://doi.org/10.1109/BSN.2011.8

Morales, J., & Akopian, D. (2017). Physical activity recognition by
smartphones, a survey. *Biocybernetics and Biomedical Engineering*, 37(3),
388-400. https://doi.org/10.1016/j.bbe.2017.04.004

Mizell, D. (2003). Using gravity to estimate accelerometer orientation.
*Proceedings of the 7th IEEE International Symposium on Wearable
Computers (ISWC '03)*, 252-253. https://doi.org/10.1109/ISWC.2003.1241424
(Original source for the vertical/horizontal decomposition used here.)

Lara, O. D., & Labrador, M. A. (2013). A survey on human activity
recognition using wearable sensors. *IEEE Communications Surveys &
Tutorials*, 15(3), 1192-1209. https://doi.org/10.1109/SURV.2012.110112.00192
(Jerk as a discriminator for ambulation phases.)

PMC10346883 -- Reducing the Impact of Sensor Orientation Variability in
RF-based Gesture Recognition. https://pmc.ncbi.nlm.nih.gov/articles/PMC10346883/

PMC9313140 -- Exploring Orientation Invariant Heuristic Features.
https://pmc.ncbi.nlm.nih.gov/articles/PMC9313140/
"""

from __future__ import annotations

from typing import Iterable, Sequence

import numpy as np
import pandas as pd

RAW_FEATURE_COLS: list[str] = [
    "attitude.roll", "attitude.pitch", "attitude.yaw",
    "gravity.x", "gravity.y", "gravity.z",
    "rotationRate.x", "rotationRate.y", "rotationRate.z",
    "userAcceleration.x", "userAcceleration.y", "userAcceleration.z",
]

ORIENTATION_INVARIANT_COLS: list[str] = [
    "acc_mag",
    "gyro_mag",
    "a_v",
    "a_h",
    "jerk_v",
    "pitch_unwrapped",
]

# Extension: walking-direction body frame.
# Replaces the orientation-dependent ``pitch_unwrapped`` channel with three
# new channels computed in a body-aligned frame {g_hat, f_hat, s_hat}, where
# f_hat is the smoothed forward direction (per Mizell, 2003; Henpraserttae
# et al., 2011). The resulting 8 channels are invariant under any rotation
# of the phone about the gravity axis (yaw).
WALKING_FRAME_COLS: list[str] = [
    "acc_mag",
    "gyro_mag",
    "a_v",
    "a_h",
    "jerk_v",
    "a_f",
    "a_s",
    "gyro_v",
]

# Extension: sign-invariant walking frame. 
# Resolves the 180-degree pocket-orientation sign ambiguity in 
# ``a_f`` / ``a_s``: a rotation of the phone by pi about gravity 
# flips the smoothed forward direction f_hat -> -f_hat, which propagates to 
# a_f -> -a_f and a_s -> -a_s. The magnitude form is invariant. 
# ``gyro_v`` is left signed because its sign depends only on the gravity-axis convention, 
# which is fixed once the input is in iOS CoreMotion format.
WALKING_FRAME_V2_COLS: list[str] = [
    "acc_mag",
    "gyro_mag",
    "a_v",
    "a_h",
    "jerk_v",
    "a_f_mag",
    "a_s_mag",
    "gyro_v",
]

DEFAULT_GROUP_COLS: tuple[str, ...] = ("id", "act", "trial")
DEFAULT_FS_HZ: float = 50.0
DEFAULT_SMOOTH_SECONDS: float = 5.0


def _row_norm(arr: np.ndarray) -> np.ndarray:
    """Euclidean norm along the last axis, kept as a 1-D array."""
    return np.sqrt(np.sum(arr * arr, axis=-1))

def _compute_block(
    df: pd.DataFrame,
    fs_hz: float,
) -> pd.DataFrame:
    """Compute the orientation-invariant channels on a contiguous block.

    The input must come from a single (subject, activity, trial) group so
    that the time derivative used for ``jerk_v`` and the ``np.unwrap`` for
    ``pitch_unwrapped`` do not bridge unrelated recordings.
    """
    ua = df[["userAcceleration.x", "userAcceleration.y", "userAcceleration.z"]].to_numpy(
        dtype=np.float64
    )
    g = df[["gravity.x", "gravity.y", "gravity.z"]].to_numpy(dtype=np.float64)
    omega = df[["rotationRate.x", "rotationRate.y", "rotationRate.z"]].to_numpy(
        dtype=np.float64
    )
    pitch = df["attitude.pitch"].to_numpy(dtype=np.float64)

    acc_mag = _row_norm(ua)
    gyro_mag = _row_norm(omega)

    g_norm = _row_norm(g)
    g_hat = g / g_norm[:, None]

    # Vertical projection: scalar a_v = u_a . g_hat (signed; sign(a_v) > 0
    # follows the direction of gravity, by convention in MotionSense).
    a_v = np.sum(ua * g_hat, axis=1)

    # Horizontal residual: magnitude of u_a once the vertical component is
    # subtracted. This is rotation-invariant about the gravity axis
    # (Mizell, 2003).
    ua_horizontal = ua - a_v[:, None] * g_hat
    a_h = _row_norm(ua_horizontal)

    # Vertical jerk: discrete derivative of a_v. The first sample is filled
    # by replicating the second sample so the output length is preserved
    # and no NaNs propagate into downstream windowing.
    dt = 1.0 / fs_hz
    jerk_v = np.empty_like(a_v)
    if a_v.size >= 2:
        jerk_v[1:] = np.diff(a_v) / dt
        jerk_v[0] = jerk_v[1]
    else:
        jerk_v[:] = 0.0

    pitch_unwrapped = np.unwrap(pitch)

    return pd.DataFrame(
        {
            "acc_mag": acc_mag,
            "gyro_mag": gyro_mag,
            "a_v": a_v,
            "a_h": a_h,
            "jerk_v": jerk_v,
            "pitch_unwrapped": pitch_unwrapped,
        },
        index=df.index,
    )


def _moving_average(arr: np.ndarray, window_samples: int) -> np.ndarray:
    """Per-column centred moving average. ``arr`` shape (N, D)."""
    if window_samples <= 1 or arr.shape[0] <= window_samples:
        return arr.copy()
    kernel = np.ones(window_samples) / window_samples
    out = np.empty_like(arr)
    for d in range(arr.shape[1]):
        out[:, d] = np.convolve(arr[:, d], kernel, mode="same")
    return out


def _walking_frame_block(
    df: pd.DataFrame,
    fs_hz: float,
    smooth_seconds: float,
) -> pd.DataFrame:
    """Compute walking-direction body-frame projections for a contiguous block.

    Returns the 8 columns listed in :data:`WALKING_FRAME_COLS`. The block
    must come from one (subject, activity, trial) recording so that the
    walking-direction smoothing does not blend two unrelated trials.

    Method (Mizell, 2003; Henpraserttae et al., 2011):
    1. Estimate gravity unit vector ``g_hat`` per sample.
    2. Decompose user-acceleration into vertical and horizontal parts.
    3. Smooth the horizontal part with a ~5-second window and use its
       direction as the forward axis ``f_hat``.
    4. Lateral axis ``s_hat = f_hat x g_hat`` completes the orthonormal
       body frame.
    5. Project user-acceleration onto ``f_hat`` (``a_f``) and ``s_hat``
       (``a_s``); project angular velocity onto ``g_hat`` (``gyro_v``) to
       capture pelvis yaw rate.
    """
    ua = df[["userAcceleration.x", "userAcceleration.y", "userAcceleration.z"]].to_numpy(
        dtype=np.float64
    )
    g = df[["gravity.x", "gravity.y", "gravity.z"]].to_numpy(dtype=np.float64)
    omega = df[["rotationRate.x", "rotationRate.y", "rotationRate.z"]].to_numpy(
        dtype=np.float64
    )

    acc_mag = _row_norm(ua)
    gyro_mag = _row_norm(omega)

    g_norm = _row_norm(g)
    g_hat = g / g_norm[:, None]

    a_v = np.sum(ua * g_hat, axis=1)
    ua_horizontal = ua - a_v[:, None] * g_hat
    a_h = _row_norm(ua_horizontal)

    smooth_samples = max(1, int(round(smooth_seconds * fs_hz)))
    ua_h_smooth = _moving_average(ua_horizontal, smooth_samples)
    smooth_norm = _row_norm(ua_h_smooth)

    # Per-sample forward direction; fallback to the trial mean where the
    # smoothed magnitude is near zero (static activity).
    eps = 1e-3  # ~1 mg, well below ambulation amplitudes
    mean_dir = ua_h_smooth.mean(axis=0)
    mean_dir_norm = np.linalg.norm(mean_dir)
    if mean_dir_norm < eps:
        # No coherent direction in the whole block (sit/std). Build a
        # deterministic horizontal axis orthogonal to the mean gravity by
        # projecting world-X onto the horizontal plane.
        mean_g = g_hat.mean(axis=0)
        mean_g = mean_g / np.linalg.norm(mean_g)
        world_x = np.array([1.0, 0.0, 0.0])
        proj = world_x - (world_x @ mean_g) * mean_g
        proj_norm = np.linalg.norm(proj)
        if proj_norm < eps:
            world_y = np.array([0.0, 1.0, 0.0])
            proj = world_y - (world_y @ mean_g) * mean_g
            proj_norm = np.linalg.norm(proj)
        f_default = proj / max(proj_norm, eps)
        f_hat = np.broadcast_to(f_default, ua.shape).copy()
    else:
        f_default = mean_dir / mean_dir_norm
        f_hat = np.where(
            smooth_norm[:, None] < eps,
            f_default,
            ua_h_smooth / np.where(smooth_norm[:, None] < eps, 1.0, smooth_norm[:, None]),
        )

    # Sideways = f_hat x g_hat (right-handed body frame). Re-orthogonalise
    # f_hat against g_hat first so f_hat lies strictly in the horizontal
    # plane even if the smoothing leaked a small vertical component.
    f_hat = f_hat - np.sum(f_hat * g_hat, axis=1, keepdims=True) * g_hat
    f_hat = f_hat / np.maximum(_row_norm(f_hat)[:, None], eps)
    s_hat = np.cross(f_hat, g_hat)

    a_f = np.sum(ua * f_hat, axis=1)
    a_s = np.sum(ua * s_hat, axis=1)
    gyro_v = np.sum(omega * g_hat, axis=1)

    dt = 1.0 / fs_hz
    jerk_v = np.empty_like(a_v)
    if a_v.size >= 2:
        jerk_v[1:] = np.diff(a_v) / dt
        jerk_v[0] = jerk_v[1]
    else:
        jerk_v[:] = 0.0

    return pd.DataFrame(
        {
            "acc_mag": acc_mag,
            "gyro_mag": gyro_mag,
            "a_v": a_v,
            "a_h": a_h,
            "jerk_v": jerk_v,
            "a_f": a_f,
            "a_s": a_s,
            "gyro_v": gyro_v,
        },
        index=df.index,
    )


def compute_walking_frame_features_v2(
    df: pd.DataFrame,
    fs_hz: float = DEFAULT_FS_HZ,
    smooth_seconds: float = DEFAULT_SMOOTH_SECONDS,
    group_cols: Sequence[str] | None = DEFAULT_GROUP_COLS,
    keep_meta: bool = True,
    meta_cols: Iterable[str] = ("id", "act", "trial", "weight", "height", "age", "gender"),
) -> pd.DataFrame:
    """Sign-invariant walking-frame features.

    Identical to :func:`compute_walking_frame_features` but returns the
    *magnitude* of the lateral / forward body-frame projections,
    ``a_f_mag = |a_f|`` and ``a_s_mag = |a_s|``. This resolves the
    180-degree pocket-orientation sign ambiguity of the v1 signed
    projections (rotating the phone by pi about gravity flips both
    ``f_hat`` and ``s_hat``, which flips ``a_f`` and ``a_s``).
    """
    # Reuse the v1 computation, then take magnitudes on the two ambiguous
    # channels.
    v1 = compute_walking_frame_features(
        df, fs_hz=fs_hz, smooth_seconds=smooth_seconds,
        group_cols=group_cols, keep_meta=keep_meta, meta_cols=meta_cols,
    )
    v1 = v1.rename(columns={"a_f": "a_f_mag", "a_s": "a_s_mag"})
    v1["a_f_mag"] = v1["a_f_mag"].abs()
    v1["a_s_mag"] = v1["a_s_mag"].abs()
    # Reorder to match WALKING_FRAME_V2_COLS.
    keep = [c for c in WALKING_FRAME_V2_COLS if c in v1.columns]
    extra = [c for c in v1.columns if c not in WALKING_FRAME_V2_COLS]
    return v1[keep + extra]


def compute_walking_frame_features(
    df: pd.DataFrame,
    fs_hz: float = DEFAULT_FS_HZ,
    smooth_seconds: float = DEFAULT_SMOOTH_SECONDS,
    group_cols: Sequence[str] | None = DEFAULT_GROUP_COLS,
    keep_meta: bool = True,
    meta_cols: Iterable[str] = ("id", "act", "trial", "weight", "height", "age", "gender"),
) -> pd.DataFrame:
    """Extension of :func:`compute_features`.

    Drops the orientation-dependent ``pitch_unwrapped`` channel and adds
    three body-frame channels (``a_f``, ``a_s``, ``gyro_v``) derived from
    the walking-direction frame. All 8 channels in the output are
    invariant under rotation of the phone about the gravity axis (yaw),
    which is the dominant nuisance variability in pocket placement
    (Mizell, 2003; Henpraserttae et al., 2011).
    """
    missing = [c for c in RAW_FEATURE_COLS if c not in df.columns]
    if missing:
        raise ValueError(
            f"Input DataFrame is missing required raw channels: {missing}"
        )
    if fs_hz <= 0:
        raise ValueError("fs_hz must be positive")
    if smooth_seconds <= 0:
        raise ValueError("smooth_seconds must be positive")

    if group_cols is None or not all(c in df.columns for c in group_cols):
        feats = _walking_frame_block(df, fs_hz=fs_hz, smooth_seconds=smooth_seconds)
    else:
        parts = []
        for _, block in df.groupby(list(group_cols), sort=False):
            parts.append(_walking_frame_block(block, fs_hz=fs_hz, smooth_seconds=smooth_seconds))
        feats = pd.concat(parts).sort_index()

    if keep_meta:
        present_meta = [c for c in meta_cols if c in df.columns]
        if present_meta:
            feats = pd.concat([feats, df[present_meta]], axis=1)

    return feats


def compute_features(
    df: pd.DataFrame,
    fs_hz: float = DEFAULT_FS_HZ,
    group_cols: Sequence[str] | None = DEFAULT_GROUP_COLS,
    keep_meta: bool = True,
    meta_cols: Iterable[str] = ("id", "act", "trial", "weight", "height", "age", "gender"),
) -> pd.DataFrame:
    """Map a 12-channel MotionSense DataFrame to orientation-invariant channels.

    Parameters
    ----------
    df:
        Long-form DataFrame with the 12 raw channels listed in
        :data:`RAW_FEATURE_COLS`, optionally with metadata columns
        (``id``, ``act``, ``trial``, etc.) produced by ``create_time_series``.
    fs_hz:
        Sampling rate used for the discrete time derivative (``jerk_v``).
        MotionSense was recorded at ~50 Hz; defaults to that.
    group_cols:
        Columns that identify a single contiguous recording. Time
        derivatives and phase-unwrapping are applied within each group so
        no edge between two unrelated recordings is treated as a real
        transient. Pass ``None`` to treat the whole DataFrame as one block
        (useful for tests or single-session in-the-wild data).
    keep_meta:
        If ``True``, metadata columns from ``meta_cols`` that exist in
        ``df`` are forwarded to the output (needed by ``sliding_windows``).
    meta_cols:
        Names of metadata columns to forward when ``keep_meta`` is true.

    Returns
    -------
    pd.DataFrame
        DataFrame with the columns from :data:`ORIENTATION_INVARIANT_COLS`
        (plus any preserved metadata), in the same row order as ``df``.
    """
    missing = [c for c in RAW_FEATURE_COLS if c not in df.columns]
    if missing:
        raise ValueError(
            f"Input DataFrame is missing required raw channels: {missing}"
        )
    if fs_hz <= 0:
        raise ValueError("fs_hz must be positive")

    if group_cols is None or not all(c in df.columns for c in group_cols):
        feats = _compute_block(df, fs_hz=fs_hz)
    else:
        # Preserve the original row order by computing per-group then
        # concatenating on the original index.
        parts = []
        for _, block in df.groupby(list(group_cols), sort=False):
            parts.append(_compute_block(block, fs_hz=fs_hz))
        feats = pd.concat(parts).sort_index()

    if keep_meta:
        present_meta = [c for c in meta_cols if c in df.columns]
        if present_meta:
            feats = pd.concat([feats, df[present_meta]], axis=1)

    return feats

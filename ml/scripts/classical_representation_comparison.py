"""Classical classifiers (RF / LinearSVC / SVC-RBF) over each channel
representation under one identical protocol -- the notebooks aren't mutually
comparable, since no classical result exists for the 8ch-v2 representation
the app ships (notebook 02 covers 12ch raw, 05 the 6ch orientation-invariant,
08 the 8ch v1), and notebook 02 also trains on more subjects (0-18) than 05/08
(0-14). The thesis' "CNN vs. tuned classical" comparison currently varies
model, representation, and training-set size all at once; this script holds
representation, split, and tuning protocol fixed so only the model varies.

Protocol: 128-sample windows/64 step grouped per (id, act, trial) [§3.3.3];
train on subjects 0-18, test 19-23, matching §3.3.4 (--train-subjects 0-14
reproduces notebooks 05/08); 18 descriptors/channel + top-72 by RF importance
[notebook 02 §7-8]; GroupKFold(5) tuning with notebook 02's grids verbatim --
notebook 08's GroupKFold(3) grid selects a different (C, gamma) and misses the
published SVC-RBF number (0.9443 vs 0.9519). Metrics: macro-F1, accuracy,
per-class F1 [ZM-3]. --cv adds GroupKFold(5) over all 24 subjects with fixed
hyperparameters, matching how the CNN's CV numbers were produced.

--in-the-wild additionally scores the best model of each representation on
the 12 labelled Android sessions (session loader, Android->iOS conversion and
trim copied verbatim from notebook 12 so window sets match the CNN's; no
per-window z-score -- the classical pipeline standardises the selected
*features* instead), since MotionSense alone can't decide which model should
ship: the CNN was partly chosen on this same axis.

Usage
-----
    python ml/scripts/classical_representation_comparison.py
    python ml/scripts/classical_representation_comparison.py --rep wf2_8
    python ml/scripts/classical_representation_comparison.py --rep wf2_8 --cv
    python ml/scripts/classical_representation_comparison.py --rep wf2_8 --in-the-wild
    python ml/scripts/classical_representation_comparison.py --rep wf2_8 --no-tilt --in-the-wild
    python ml/scripts/classical_representation_comparison.py --train-subjects 0-14

Rows from a --no-tilt run carry " bez nagiba" in the Model column, so they land
alongside the with-tilt rows in the same CSVs instead of overwriting them.

Runtime warning: SVC-RBF is O(n^2) in the number of windows. One
representation with the full grid (5 C x 4 gamma x 3 folds) over ~17 000
training windows takes roughly 20-40 min on a laptop CPU; --cv adds five more
fits per model. Run one representation at a time if that matters; results are
merged into the output CSV incrementally.

Outputs
-------
    ml/results/classical_representation_comparison.csv
    ml/results/classical_representation_cv.csv           (only with --cv)
    ml/results/classical_representation_in_the_wild.csv  (only with --in-the-wild)

Requires `data/A_DeviceMotion_data/` and `data/data_subjects_info.csv` (gitignored;
re-download from github.com/mmalekzadeh/motion-sense if missing).
"""

from __future__ import annotations

import argparse
import os
import sys
import time

import numpy as np
import pandas as pd
from sklearn.base import clone
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import f1_score
from sklearn.model_selection import GridSearchCV, GroupKFold, RandomizedSearchCV
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVC, LinearSVC

_ML_DIR = os.path.join(os.path.dirname(__file__), os.pardir)
sys.path.insert(0, os.path.abspath(_ML_DIR))

from utils.orientation_invariant_features import (  # noqa: E402
    ORIENTATION_INVARIANT_COLS,
    WALKING_FRAME_COLS,
    WALKING_FRAME_V2_COLS,
    compute_features,
    compute_walking_frame_features,
    compute_walking_frame_features_v2,
)

_REPO_ROOT = os.path.abspath(os.path.join(_ML_DIR, os.pardir))
_DATA_DIR = os.path.join(_REPO_ROOT, "data")
_MOTIONSENSE_DIR = os.path.join(_DATA_DIR, "A_DeviceMotion_data")
_SUBJECTS_CSV = os.path.join(_DATA_DIR, "data_subjects_info.csv")
_ITW_LABELS_CSV = os.path.join(_DATA_DIR, "in_the_wild", "labels.csv")
_RESULTS_DIR = os.path.join(_ML_DIR, "results")

G = 9.80665
ITW_TRIM = 150  # samples dropped at each end of a session (notebook 12)

SEED = 42
WINDOW = 128
STEP = 64
FS_HZ = 50.0
SMOOTH_SECONDS = 5.0
FFT_BINS = 8
TOP_K = 72

ACT_LABELS = ["dws", "ups", "wlk", "jog", "std", "sit"]
TRIAL_CODES = {
    "dws": [1, 2, 11],
    "ups": [3, 4, 12],
    "wlk": [7, 8, 15],
    "jog": [9, 16],
    "std": [6, 14],
    "sit": [5, 13],
}
RAW_COLS = [
    "attitude.roll", "attitude.pitch", "attitude.yaw",
    "gravity.x", "gravity.y", "gravity.z",
    "rotationRate.x", "rotationRate.y", "rotationRate.z",
    "userAcceleration.x", "userAcceleration.y", "userAcceleration.z",
]

# Representation registry. `deriver=None` means "use the raw channels as-is".
REPRESENTATIONS = {
    "raw12": {
        "label": "12 sirovih kanala",
        "cols": RAW_COLS,
        "deriver": None,
        "kwargs": {},
    },
    "oinv6": {
        # compute_features has no walking frame, so no smooth_seconds argument.
        "label": "6 kanala neovisnih o orijentaciji",
        "cols": ORIENTATION_INVARIANT_COLS,
        "deriver": compute_features,
        "kwargs": {"fs_hz": FS_HZ},
    },
    "wf1_8": {
        "label": "8 kanala tjelesnog sustava (v1, predznaceni)",
        "cols": WALKING_FRAME_COLS,
        "deriver": compute_walking_frame_features,
        "kwargs": {"fs_hz": FS_HZ, "smooth_seconds": SMOOTH_SECONDS},
    },
    "wf2_8": {
        "label": "8 kanala tjelesnog sustava (v2, konacni)",
        "cols": WALKING_FRAME_V2_COLS,
        "deriver": compute_walking_frame_features_v2,
        "kwargs": {"fs_hz": FS_HZ, "smooth_seconds": SMOOTH_SECONDS},
    },
}

STATS = [
    "mean", "std", "min", "max", "energy", "median", "iqr", "zcr",
    "dom_freq", "sp_entropy",
] + [f"fft_{i}" for i in range(FFT_BINS)]

_FREQS = np.fft.rfftfreq(WINDOW, d=1.0 / FS_HZ)


# ---------------------------------------------------------------- data loading


def load_motionsense() -> pd.DataFrame:
    """Loads MotionSense into one long DataFrame with the notebook-02 schema.

    Column order, subject indexing (code - 1) and trial grouping match the
    notebooks byte-for-byte so window counts reproduce exactly."""
    info = pd.read_csv(_SUBJECTS_CSV)
    blocks = []
    for sub_id in info["code"]:
        for act_id, act in enumerate(ACT_LABELS):
            for trial in TRIAL_CODES[act]:
                path = os.path.join(_MOTIONSENSE_DIR, f"{act}_{trial}", f"sub_{int(sub_id)}.csv")
                raw = pd.read_csv(path).drop(["Unnamed: 0"], axis=1)
                block = raw[RAW_COLS].copy()
                block["act"] = act_id
                block["id"] = int(sub_id) - 1
                block["trial"] = trial
                i = int(sub_id) - 1
                block["weight"] = info["weight"][i]
                block["height"] = info["height"][i]
                block["age"] = info["age"][i]
                block["gender"] = info["gender"][i]
                blocks.append(block)
    dataset = pd.concat(blocks, ignore_index=True)
    for col in ("act", "id", "trial"):
        dataset[col] = dataset[col].astype(int)
    return dataset


def sliding_windows(data: pd.DataFrame, cols: list[str]):
    """Windows per (id, act, trial) group -- windows never bridge two records."""
    X, y, g = [], [], []
    for (sid, act, _), block in data.groupby(["id", "act", "trial"], sort=False):
        vals = block[cols].to_numpy()
        for start in range(0, len(vals) - WINDOW + 1, STEP):
            X.append(vals[start:start + WINDOW])
            y.append(act)
            g.append(sid)
    return np.array(X), np.array(y, dtype=int), np.array(g, dtype=int)


# ----------------------------------------------------------- feature extraction


def extract_features(X: np.ndarray) -> np.ndarray:
    """18 descriptors per channel, exactly as in notebook 02 §7 / 08."""
    out = []
    for win in X:
        row = []
        for col in range(win.shape[1]):
            s = win[:, col]
            row.extend([
                s.mean(), s.std(), s.min(), s.max(),
                float((s ** 2).sum()) / len(s),
                float(np.median(s)),
                float(np.percentile(s, 75) - np.percentile(s, 25)),
                float(((np.diff(s) != 0) & (np.diff(np.sign(s)) != 0)).sum()) / (len(s) - 1),
            ])
            fft_mag = np.abs(np.fft.rfft(s))
            psd = fft_mag ** 2
            psd_n = psd / (psd.sum() + 1e-10)
            row.append(float(_FREQS[np.argmax(fft_mag)]))
            row.append(float(-np.sum(psd_n * np.log2(psd_n + 1e-10))))
            row.extend((fft_mag[:FFT_BINS] / (len(s) / 2)).tolist())
        out.append(row)
    return np.array(out)


def tilt_features(df: pd.DataFrame) -> np.ndarray:
    """Two orientation-invariant tilt descriptors (mean/std of gravity pitch),
    added to every representation including raw, matching notebook 02 §7.
    Window enumeration must match `sliding_windows` exactly."""
    out = []
    for _, block in df.groupby(["id", "act", "trial"], sort=False):
        v = block[["gravity.x", "gravity.y", "gravity.z"]].to_numpy()
        n_windows = max(0, (len(v) - WINDOW) // STEP + 1)
        for i in range(n_windows):
            w = v[i * STEP: i * STEP + WINDOW]
            tilt = np.arctan2(w[:, 2], np.sqrt(w[:, 0] ** 2 + w[:, 1] ** 2))
            out.append([float(tilt.mean()), float(tilt.std())])
    return np.array(out)


def build_design_matrix(raw: pd.DataFrame, rep_key: str, subject_ids: list[int],
                        include_tilt: bool = True):
    """Returns (features, labels, groups, feature_names) for one subject set.

    `include_tilt=False` drops `tilt_mean` / `tilt_std` -- see --no-tilt."""
    rep = REPRESENTATIONS[rep_key]
    raw_subset = raw[raw["id"].isin(subject_ids)].copy()

    if rep["deriver"] is None:
        channel_df = raw_subset
    else:
        channel_df = rep["deriver"](raw_subset, **rep["kwargs"])

    X_win, y, g = sliding_windows(channel_df, rep["cols"])
    stats = extract_features(X_win)
    names = [f"{ch}_{s}" for ch in rep["cols"] for s in STATS]
    if not include_tilt:
        return stats, y, g, names

    tilts = tilt_features(raw_subset)
    if len(stats) != len(tilts):
        raise RuntimeError(
            f"window count mismatch: {len(stats)} statistical vs {len(tilts)} tilt rows -- "
            "the two enumerations must agree row-for-row"
        )
    return np.concatenate([stats, tilts], axis=1), y, g, names + ["tilt_mean", "tilt_std"]


# ------------------------------------------------------------------- modelling


def tuned_models(X_top, y, groups):
    """Fits the three tuned classical families; returns {name: estimator}.

    Fold count, grids, n_iter and seed copied from notebook 02 §9 verbatim so
    the raw-12-channel row reproduces the published reference numbers."""
    cv = GroupKFold(5)
    fitted = {}

    rf_search = RandomizedSearchCV(
        RandomForestClassifier(class_weight="balanced", random_state=SEED, n_jobs=-1),
        {
            "n_estimators": [100, 200, 300, 500],
            "max_depth": [None, 15, 25, 40],
            "min_samples_leaf": [1, 2, 4],
            "max_features": ["sqrt", "log2", 0.3, 0.5],
        },
        n_iter=40, scoring="f1_macro", cv=cv, random_state=SEED, n_jobs=-1,
    )
    rf_search.fit(X_top, y, groups=groups)
    fitted["Slucajna suma (podesena)"] = rf_search.best_estimator_
    print(f"    RF best: {rf_search.best_params_}  CV f1={rf_search.best_score_:.4f}")

    lsvc = GridSearchCV(
        Pipeline([
            ("scaler", StandardScaler()),
            ("clf", LinearSVC(class_weight="balanced", random_state=SEED, max_iter=2000)),
        ]),
        {"clf__C": [0.01, 0.1, 1, 10, 100]},
        scoring="f1_macro", cv=cv, n_jobs=-1,
    )
    lsvc.fit(X_top, y, groups=groups)
    fitted["LinearSVC (podesen)"] = lsvc.best_estimator_
    print(f"    LinearSVC best: {lsvc.best_params_}  CV f1={lsvc.best_score_:.4f}")

    svc = GridSearchCV(
        Pipeline([
            ("scaler", StandardScaler()),
            ("clf", SVC(kernel="rbf", class_weight="balanced", random_state=SEED)),
        ]),
        {"clf__C": [0.1, 1, 10, 100], "clf__gamma": ["scale", 0.001, 0.01, 0.1]},
        scoring="f1_macro", cv=cv, n_jobs=-1,
    )
    svc.fit(X_top, y, groups=groups)
    fitted["SVC-RBF (podesen)"] = svc.best_estimator_
    print(f"    SVC-RBF best: {svc.best_params_}  CV f1={svc.best_score_:.4f}")

    return fitted


def score(name, rep_key, features_desc, y_true, y_pred) -> dict:
    per_class = f1_score(y_true, y_pred, average=None)
    row = {
        "Reprezentacija": REPRESENTATIONS[rep_key]["label"],
        "rep_key": rep_key,
        "Model": name,
        "Znacajke": features_desc,
        "Macro-F1": float(f1_score(y_true, y_pred, average="macro")),
        "Tocnost": float((y_pred == y_true).mean()),
    }
    row.update({f"F1_{a}": float(v) for a, v in zip(ACT_LABELS, per_class)})
    return row


# ---------------------------------------------------------- in-the-wild axis


def load_session(session_dir: str) -> pd.DataFrame:
    """One Android session -> a 12-channel frame in MotionSense convention.

    Verbatim from notebook 12 (audited against Sensor Logger's COORDINATES.md
    / CROSSPLATFORM.md and Apple's CMDeviceMotion reference): merge the four
    sensor CSVs on time, resample to 20 ms, reconstruct userAcceleration =
    total - gravity, convert m/s^2 -> g, negate acceleration/pitch/yaw axes,
    re-zero yaw, trim 150 samples (3 s) at each end to drop the pocket-
    insertion transient. Must stay identical to keep the window set
    comparable with the CNN's in-the-wild numbers."""
    base = os.path.join(_DATA_DIR, session_dir)

    def rd(name):
        return pd.read_csv(os.path.join(base, name)).sort_values("time")

    df = pd.merge_asof(rd("Orientation.csv")[["time", "roll", "pitch", "yaw"]],
                       rd("Gravity.csv")[["time", "x", "y", "z"]], on="time", suffixes=("", "_grav"))
    df = pd.merge_asof(df, rd("Gyroscope.csv")[["time", "x", "y", "z"]], on="time", suffixes=("", "_gyro"))
    df = pd.merge_asof(df, rd("TotalAcceleration.csv")[["time", "x", "y", "z"]], on="time", suffixes=("", "_tot_acc"))
    df.columns = [
        "time", "attitude.roll", "attitude.pitch", "attitude.yaw",
        "raw_gravity.x", "raw_gravity.y", "raw_gravity.z",
        "rotationRate.x", "rotationRate.y", "rotationRate.z",
        "raw_total_acc.x", "raw_total_acc.y", "raw_total_acc.z",
    ]
    df["time_dt"] = pd.to_datetime(df["time"])
    df = (df.set_index("time_dt")
            .resample("20ms").mean(numeric_only=True)
            .interpolate(method="linear")
            .reset_index(drop=True))
    for axis in "xyz":
        df[f"gravity.{axis}"] = -df[f"raw_gravity.{axis}"] / G
        df[f"userAcceleration.{axis}"] = (
            -(df[f"raw_total_acc.{axis}"] - df[f"raw_gravity.{axis}"]) / G
        )
    df["attitude.pitch"] = -df["attitude.pitch"]
    df["attitude.yaw"] = -df["attitude.yaw"]
    df["attitude.yaw"] = df["attitude.yaw"] - df["attitude.yaw"].iloc[0]
    return df[RAW_COLS].iloc[ITW_TRIM:-ITW_TRIM].reset_index(drop=True)


def session_design_matrix(session_raw: pd.DataFrame, rep_key: str, include_tilt: bool = True):
    """Same feature vector as the MotionSense path, for one session.

    Returns `(features, end_indices)`. `group_cols=None` since a session has
    no (id, act, trial) boundary, so smoothing sees the whole session,
    matching `streaming_offline_compare.offline_windows`; `end_indices` use
    that function's convention (`start + WINDOW - 1`) so windows line up.
    No per-window z-score is applied -- see the module docstring."""
    rep = REPRESENTATIONS[rep_key]
    if rep["deriver"] is None:
        channels = session_raw[rep["cols"]].to_numpy()
    else:
        derived = rep["deriver"](
            session_raw, group_cols=None, keep_meta=False, **rep["kwargs"]
        )
        channels = derived[rep["cols"]].to_numpy()

    gravity = session_raw[["gravity.x", "gravity.y", "gravity.z"]].to_numpy()
    n_windows = max(0, (len(channels) - WINDOW) // STEP + 1)
    n_cols = len(rep["cols"]) * len(STATS) + (2 if include_tilt else 0)
    if n_windows == 0:
        return np.empty((0, n_cols)), []

    windows = np.stack([channels[i * STEP: i * STEP + WINDOW] for i in range(n_windows)])
    tilts, ends = [], []
    for i in range(n_windows):
        w = gravity[i * STEP: i * STEP + WINDOW]
        tilt = np.arctan2(w[:, 2], np.sqrt(w[:, 0] ** 2 + w[:, 1] ** 2))
        tilts.append([float(tilt.mean()), float(tilt.std())])
        ends.append(i * STEP + WINDOW - 1)
    stats = extract_features(windows)
    if not include_tilt:
        return stats, ends
    return np.concatenate([stats, np.array(tilts)], axis=1), ends


def evaluate_in_the_wild(rep_key, estimator, name, top_idx, include_tilt=True):
    """Per-session and pooled accuracy of one fitted classical model.

    Returns (summary_row, per_session_rows), matching `final_in_the_wild.csv`:
    `correct_frac` is the fraction of windows predicted as the session's
    ground-truth activity, `majority` is the modal prediction."""
    labels = pd.read_csv(_ITW_LABELS_CSV)
    per_session, total_correct, total_windows, majority_correct = [], 0, 0, 0

    for _, meta in labels.iterrows():
        session = meta["session_dir"]
        features, _ = session_design_matrix(load_session(session), rep_key, include_tilt)
        if len(features) == 0:
            print(f"    {session}: no full window, skipped")
            continue
        pred = estimator.predict(features[:, top_idx])
        gt = int(meta["activity_id"])
        correct = int((pred == gt).sum())
        modal = int(np.bincount(pred.astype(int), minlength=len(ACT_LABELS)).argmax())
        total_correct += correct
        total_windows += len(pred)
        majority_correct += int(modal == gt)
        per_session.append({
            "rep_key": rep_key, "Model": name, "s_nagibom": include_tilt, "session": session,
            "orientation": meta["pocket_orientation"],
            "true": ACT_LABELS[gt], "correct_frac": correct / len(pred),
            "majority": ACT_LABELS[modal], "n_windows": len(pred),
        })
        print(f"    {session:10s} gt={ACT_LABELS[gt]:4s} correct={correct / len(pred):6.1%} "
              f"majority={ACT_LABELS[modal]}")

    n_sessions = len(per_session)
    summary = {
        "Reprezentacija": REPRESENTATIONS[rep_key]["label"],
        "rep_key": rep_key, "Model": name, "s_nagibom": include_tilt,
        "window_acc": total_correct / total_windows if total_windows else float("nan"),
        "session_acc": majority_correct / n_sessions if n_sessions else float("nan"),
        "n_sessions": n_sessions, "n_windows": total_windows,
    }
    print(f"    -> window-acc={summary['window_acc']:.4f}  "
          f"session-acc={summary['session_acc']:.4f}  ({total_windows} windows)")
    return summary, per_session


# --------------------------------------------- app's own long walk recordings


# Representations needing attitude.*; SessionLog doesn't persist it, so
# `load_raw_samples` zero-fills those columns -- harmless for walking-frame
# channels (gravity/userAcceleration/rotationRate only), fatal for raw12/oinv6.
_NEEDS_ATTITUDE = {"raw12", "oinv6"}


def _load_user_session_helpers():
    """Imports `load_raw_samples` / `core_window_mask` by path (not copied) so
    the core-window definition can't drift from the CNN study these numbers
    are compared against."""
    import importlib.util
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "streaming_vs_offline_user_sessions.py")
    spec = importlib.util.spec_from_file_location("_svo_user_sessions", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.load_raw_samples, module.core_window_mask


def evaluate_user_sessions(rep_key, estimator, name, top_idx, directory,
                           pattern="session_*.json", include_tilt=True):
    """Walking-label fraction of one classical model on the app's own session
    recordings. These carry no per-window ground truth, so accuracy isn't
    computable; the metric is §3.3.6's fraction of *core* windows (>=3 s from
    either end) predicted `wlk`, comparable to the CNN's 76.5% offline
    reference in `streaming_vs_offline_user_sessions.csv`."""
    import glob
    import json

    if rep_key in _NEEDS_ATTITUDE:
        print(f"    skipped: representation '{rep_key}' needs attitude.*, which the app's "
              f"session logs do not persist")
        return None, []

    load_raw_samples, core_window_mask = _load_user_session_helpers()
    paths = sorted(glob.glob(os.path.join(directory, pattern)))
    if not paths:
        raise SystemExit(f"no files matching {pattern} in {directory}")

    rows, weighted_num, weighted_den = [], 0.0, 0
    for path in paths:
        with open(path, encoding="utf-8") as fh:
            session_json = json.load(fh)
        if not session_json.get("rawSamples"):
            continue
        df_raw = load_raw_samples(session_json)
        features, ends = session_design_matrix(df_raw, rep_key, include_tilt)
        if len(features) == 0:
            continue
        pred = estimator.predict(features[:, top_idx])
        labels = [ACT_LABELS[int(p)] for p in pred]
        core = core_window_mask(len(df_raw), ends)
        n_core = sum(core)
        core_labels = [lbl for lbl, c in zip(labels, core) if c]
        core_wlk = float(np.mean([lbl == "wlk" for lbl in core_labels])) if n_core else float("nan")
        modal = max(set(labels), key=labels.count)
        weighted_num += core_wlk * n_core if n_core else 0.0
        weighted_den += n_core
        rows.append({
            "rep_key": rep_key, "Model": name, "s_nagibom": include_tilt,
            "session": os.path.basename(path),
            "n_windows": len(labels), "n_core_windows": n_core,
            "core_wlk_frac": core_wlk, "majority": modal,
        })
        print(f"    {os.path.basename(path):<45s} n={len(labels):3d} core={n_core:3d}  "
              f"core-wlk={core_wlk * 100:5.1f}%  majority={modal}")

    summary = {
        "Reprezentacija": REPRESENTATIONS[rep_key]["label"],
        "rep_key": rep_key, "Model": name, "s_nagibom": include_tilt,
        "weighted_core_wlk_frac": weighted_num / weighted_den if weighted_den else float("nan"),
        "unweighted_core_wlk_frac": float(np.nanmean([r["core_wlk_frac"] for r in rows])) if rows else float("nan"),
        "n_sessions": len(rows), "n_core_windows": weighted_den,
        "cnn_offline_reference": 0.765,
    }
    print(f"    -> weighted core-wlk={summary['weighted_core_wlk_frac']:.4f} over "
          f"{len(rows)} sessions / {weighted_den} core windows "
          f"(CNN offline reference 0.765)")
    return summary, rows


def cross_validate(raw, rep_key, estimator, name, n_splits=5, include_tilt=True) -> dict:
    """GroupKFold(5) over all 24 subjects with hyperparameters held fixed.

    Feature selection (RF importance) is refit inside each fold on its own
    training subjects, so the top-72 choice never sees the fold's test set."""
    X, y, g, _ = build_design_matrix(raw, rep_key, list(range(24)), include_tilt)
    scores = []
    for fold, (tr, te) in enumerate(GroupKFold(n_splits).split(X, y, groups=g), start=1):
        ranker = RandomForestClassifier(
            n_estimators=100, class_weight="balanced", random_state=SEED, n_jobs=-1
        ).fit(X[tr], y[tr])
        top = np.argsort(ranker.feature_importances_)[::-1][:TOP_K]
        model = clone(estimator).fit(X[tr][:, top], y[tr])
        f1 = f1_score(y[te], model.predict(X[te][:, top]), average="macro")
        scores.append(f1)
        print(f"    fold {fold}  subjects={sorted(set(g[te].tolist()))}  macro-F1={f1:.4f}")
    scores = np.array(scores)
    return {
        "Reprezentacija": REPRESENTATIONS[rep_key]["label"],
        "rep_key": rep_key,
        "Model": name,
        "s_nagibom": include_tilt,
        "CV_mean": float(scores.mean()),
        "CV_std": float(scores.std()),
        "CV_folds": " ".join(f"{s:.4f}" for s in scores),
    }


# ------------------------------------------------------------------------ main


def merge_csv(path, rows, key_cols):
    new = pd.DataFrame(rows)
    if os.path.exists(path):
        old = pd.read_csv(path)
        combined = pd.concat([old, new], ignore_index=True)
        combined = combined.drop_duplicates(subset=key_cols, keep="last")
    else:
        combined = new
    combined.to_csv(path, index=False)
    print(f"saved -> {os.path.relpath(path, _REPO_ROOT)}  ({len(combined)} rows)")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--rep", choices=list(REPRESENTATIONS) + ["all"], default="all")
    ap.add_argument("--train-subjects", choices=["0-18", "0-14"], default="0-18",
                    help="0-18 merges the validation subjects into train (protocol of "
                         "§3.3.4 and notebook 02); 0-14 reproduces notebooks 05/08.")
    ap.add_argument("--cv", action="store_true",
                    help="also run GroupKFold(5) over all 24 subjects for the best model")
    ap.add_argument("--in-the-wild", action="store_true", dest="in_the_wild",
                    help="also run the best model of each representation over the 12 "
                         "labelled Android sessions in data/in_the_wild/")
    ap.add_argument("--no-tilt", action="store_true", dest="no_tilt",
                    help="drop tilt_mean / tilt_std from the feature set. Those two are "
                         "derived from the raw gravity vector in the DEVICE frame, so they "
                         "encode how the phone sits in the pocket -- the same leak that made "
                         "pitch_unwrapped top MotionSense and collapse in the wild (§3.3.2). "
                         "The notebooks keep them in every representation on the grounds that "
                         "they 'only depend on the gravity direction', which is true and is "
                         "exactly the problem. Run with and without to test whether they "
                         "explain the classical model's drop on the flipped-pocket sessions.")
    ap.add_argument("--user-sessions", metavar="DIR", default=None,
                    help="also run the best model over the app's own session_*.json "
                         "exports in DIR, reporting the core walking-label fraction "
                         "(no accuracy: those recordings have no per-window ground truth)")
    args = ap.parse_args()

    train_ids = list(range(19)) if args.train_subjects == "0-18" else list(range(15))
    test_ids = list(range(19, 24))
    reps = list(REPRESENTATIONS) if args.rep == "all" else [args.rep]
    include_tilt = not args.no_tilt
    label_suffix = "" if include_tilt else " bez nagiba"

    os.makedirs(_RESULTS_DIR, exist_ok=True)
    print(f"train subjects: {train_ids[0]}-{train_ids[-1]} ({len(train_ids)})   "
          f"test subjects: {test_ids[0]}-{test_ids[-1]} ({len(test_ids)})   "
          f"tilt features: {'included' if include_tilt else 'EXCLUDED'}")
    print("loading MotionSense ...")
    raw = load_motionsense()
    print(f"  raw dataset: {raw.shape}")

    test_rows, cv_rows, itw_rows, itw_session_rows = [], [], [], []
    usr_rows, usr_session_rows = [], []
    for rep_key in reps:
        print(f"\n=== {rep_key}: {REPRESENTATIONS[rep_key]['label']} ===")
        t0 = time.time()
        Xtr, ytr, gtr, names = build_design_matrix(raw, rep_key, train_ids, include_tilt)
        Xte, yte, _, _ = build_design_matrix(raw, rep_key, test_ids, include_tilt)
        print(f"  train {Xtr.shape}, test {Xte.shape}  ({time.time() - t0:.1f}s)")

        ranker = RandomForestClassifier(
            n_estimators=100, class_weight="balanced", random_state=SEED, n_jobs=-1
        ).fit(Xtr, ytr)
        test_rows.append(score(
            "Slucajna suma (100 stabala, sve znacajke)" + label_suffix, rep_key,
            str(Xtr.shape[1]), yte, ranker.predict(Xte),
        ))
        top = np.argsort(ranker.feature_importances_)[::-1][:TOP_K]
        cum = ranker.feature_importances_[top].sum()
        print(f"  top-{TOP_K} covers {cum:.1%} of RF importance mass")
        print("  top-10:", ", ".join(names[i] for i in top[:10]))

        print("  tuning ...")
        models = {name + label_suffix: est
                  for name, est in tuned_models(Xtr[:, top], ytr, gtr).items()}
        for name, est in models.items():
            test_rows.append(score(
                name, rep_key, f"{Xtr.shape[1]} -> {TOP_K}", yte, est.predict(Xte[:, top]),
            ))

        if args.cv or args.in_the_wild or args.user_sessions:
            best_name = max(
                models,
                key=lambda n: f1_score(yte, models[n].predict(Xte[:, top]), average="macro"),
            )
            print(f"  best model on this representation: {best_name}")

        if args.in_the_wild:
            print("  in-the-wild (12 Android sessions):")
            summary, sessions = evaluate_in_the_wild(
                rep_key, models[best_name], best_name, top, include_tilt,
            )
            itw_rows.append(summary)
            itw_session_rows.extend(sessions)

        if args.user_sessions:
            print("  app's own session recordings (core walking-label fraction):")
            summary, sessions = evaluate_user_sessions(
                rep_key, models[best_name], best_name, top, args.user_sessions,
                include_tilt=include_tilt,
            )
            if summary is not None:
                usr_rows.append(summary)
                usr_session_rows.extend(sessions)

        if args.cv:
            print("  GroupKFold(5) over all 24 subjects:")
            cv_rows.append(cross_validate(
                raw, rep_key, models[best_name], best_name, include_tilt=include_tilt,
            ))

    print("\n" + pd.DataFrame(test_rows)[
        ["Reprezentacija", "Model", "Znacajke", "Macro-F1", "Tocnost"]
    ].round(4).to_string(index=False))

    suffix = "" if args.train_subjects == "0-18" else "_train0-14"
    merge_csv(
        os.path.join(_RESULTS_DIR, f"classical_representation_comparison{suffix}.csv"),
        test_rows, ["rep_key", "Model"],
    )
    # Keyed on representation, not (representation, model): which family wins
    # can change between runs (a wider search flipped raw12 and oinv6's
    # winners), and keying on model name would leave stale rows behind.
    if cv_rows:
        merge_csv(
            os.path.join(_RESULTS_DIR, f"classical_representation_cv{suffix}.csv"),
            cv_rows, ["rep_key", "s_nagibom"],
        )
    if itw_rows:
        print("\n" + pd.DataFrame(itw_rows)[
            ["Reprezentacija", "Model", "window_acc", "session_acc", "n_windows"]
        ].round(4).to_string(index=False))
        merge_csv(
            os.path.join(_RESULTS_DIR, f"classical_representation_in_the_wild{suffix}.csv"),
            itw_rows, ["rep_key", "s_nagibom"],
        )
        merge_csv(
            os.path.join(_RESULTS_DIR, f"classical_representation_in_the_wild_per_session{suffix}.csv"),
            itw_session_rows, ["rep_key", "s_nagibom", "session"],
        )
    if usr_rows:
        print("\n" + pd.DataFrame(usr_rows)[
            ["Reprezentacija", "Model", "weighted_core_wlk_frac", "n_sessions", "n_core_windows"]
        ].round(4).to_string(index=False))
        merge_csv(
            os.path.join(_RESULTS_DIR, f"classical_representation_user_sessions{suffix}.csv"),
            usr_rows, ["rep_key", "s_nagibom"],
        )
        merge_csv(
            os.path.join(_RESULTS_DIR, f"classical_representation_user_sessions_per_session{suffix}.csv"),
            usr_session_rows, ["rep_key", "s_nagibom", "session"],
        )


if __name__ == "__main__":
    main()

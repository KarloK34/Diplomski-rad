"""Figures for §3.4 of the thesis, Croatian labels, styled to match the rest
of the document.

`--figure scatter`: in-distribution macro-F1 vs. window accuracy on the 12
labelled Android recordings, CSV-only (no TensorFlow/MotionSense needed).
`--figure confusion`: confusion matrix of the exported model on the
MotionSense test subjects; needs TensorFlow, `models/cnn_final.tflite` and
the MotionSense data.

Usage:
    python ml/scripts/make_ch34_figures.py [--figure scatter|confusion|both] [--results-dir DIR]

Outputs (PNG, 200 dpi) into ml/results/figures/.
"""

from __future__ import annotations

import argparse
import os
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

_SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
_ML_DIR = os.path.abspath(os.path.join(_SCRIPTS_DIR, os.pardir))
_REPO_ROOT = os.path.abspath(os.path.join(_ML_DIR, os.pardir))

ACT_CODES = ["dws", "ups", "wlk", "jog", "std", "sit"]
# Croatian names only. The dataset codes (dws, ups, …) are deliberately kept out
# of the thesis: they appeared as bare axis labels and were never defined in the
# text, so every figure now carries the Croatian activity name instead.
ACT_HR = {
    "dws": "silazak\nstepenicama",
    "ups": "uspon\nstepenicama",
    "wlk": "hodanje",
    "jog": "trčanje",
    "std": "stajanje",
    "sit": "sjedenje",
}

# Categorical slots 1 and 2 of the validated reference palette. All-pairs CVD
# separation ΔE 24.7 (protan), normal-vision 33.6 -- clear of both floors.
COL_CNN = "#2a78d6"
COL_CLASSICAL = "#eb6834"
INK = "#0b0b0b"
INK_SOFT = "#52514e"

# Short Croatian labels for the scatter. Matched as substrings against the
# Model column so the CSVs stay the single source of the numbers.
SCATTER_LABELS = [
    # (substring to match, short label, family, dx, dy, ha)
    ("separable (12ch raw)", "razdvojiva,\n12 sirovih kanala", "cnn", 0, -16, "center"),
    ("6ch orient.-invariant", "6 kanala", "cnn", -9, 0, "right"),
    ("8ch wf v1", "8 kanala, v1", "cnn", 8, 0, "left"),
    ("8ch wf v2, sign-invariant", "8 kanala, v2\n(bez regularizacije)", "cnn", -8, 4, "right"),
    ("dilated + L2", "prošireni + reg.", "cnn", 8, -4, "left"),
    ("dilated+reg, SpatialDropout=0.3", "prošireni,\npodešen", "cnn", 8, -14, "left"),
    ("A_baseline + L2", "isporučeni model", "cnn", 0, 17, "center"),
]
# (rep_key, exact Model value, short label, dx, dy, ha). rep_key is required:
# the CSVs hold one "SVC-RBF (podesen)" row per representation, so matching on
# model name alone would pair one representation's macro-F1 with another's
# in-the-wild accuracy.
CLASSICAL_LABELS = [
    ("wf2_8", "SVC-RBF (podesen) bez nagiba", "SVC-RBF\nbez značajki nagiba", -10, 0, "right"),
    ("wf2_8", "SVC-RBF (podesen)", "SVC-RBF\nsa značajkama nagiba", -10, -8, "right"),
    ("raw12", "SVC-RBF (podesen)", "SVC-RBF,\n12 sirovih kanala", -10, 0, "right"),
    ("oinv6", "LinearSVC (podesen)", "SPV linearni,\n6 kanala", -10, 0, "right"),
    ("wf1_8", "SVC-RBF (podesen)", "SVC-RBF,\n8 kanala v1", 10, 0, "left"),
]


def _thesis_style() -> None:
    plt.rcParams.update({
        "font.family": "DejaVu Sans",
        "font.size": 10,
        "axes.titlesize": 12,
        "axes.labelsize": 10,
        "axes.edgecolor": "#8a8a86",
        "axes.labelcolor": INK,
        "text.color": INK,
        "xtick.color": INK_SOFT,
        "ytick.color": INK_SOFT,
        "figure.facecolor": "white",
        "axes.facecolor": "white",
    })


def _seed_ranges(results_dir: str) -> dict:
    """Min/max over repeated seeds, for the two configs that were repeated.

    Plotted point stays the thesis-quoted value; the bar shows how far it
    moves under seed variation alone, so candidates aren't ranked on noise.
    """
    out = {}
    sv = os.path.join(results_dir, "seed_variability.csv")
    if os.path.exists(sv):
        df = pd.read_csv(sv)
        g = df[(df["arch"] == "baseline") & (df["config"] == "C12_combo_A")]
        if len(g) > 1:
            out["isporučeni model"] = (g["test_f1"].min(), g["test_f1"].max(),
                                       g["itw_window_acc"].min(), g["itw_window_acc"].max())
    sc = os.path.join(results_dir, "separable_seed_check.csv")
    tf = os.path.join(results_dir, "separable_hp_sweep_test.csv")
    iw = os.path.join(results_dir, "separable_hp_sweep_in_the_wild.csv")
    if os.path.exists(sc) and os.path.exists(tf) and os.path.exists(iw):
        df = pd.read_csv(sc)
        x = list(df["test_f1"]) + [float(pd.read_csv(tf).iloc[0]["test_f1"])]
        y = list(df["itw_window_acc"]) + [float(pd.read_csv(iw).iloc[0]["window_acc"])]
        out["razdvojiva,\npodešena"] = (min(x), max(x), min(y), max(y))
    return out


def _load_scatter_points(results_dir: str) -> pd.DataFrame:
    master = pd.read_csv(os.path.join(results_dir, "master_comparison.csv"))
    rows = []
    for needle, label, family, dx, dy, ha in SCATTER_LABELS:
        hit = master[master["Model"].str.contains(needle, regex=False)]
        if hit.empty:
            print(f"  ! no master_comparison row matching {needle!r}, skipped")
            continue
        row = hit.iloc[0]
        if pd.isna(row["Android_win_acc"]):
            print(f"  ! {needle!r} has no Android_win_acc, skipped")
            continue
        rows.append({"label": label, "family": family, "dx": dx, "dy": dy, "ha": ha,
                     "x": float(row["MotionSense_F1"]), "y": float(row["Android_win_acc"])})

    cls = pd.read_csv(os.path.join(results_dir, "classical_representation_comparison.csv"))
    itw = pd.read_csv(os.path.join(results_dir, "classical_representation_in_the_wild.csv"))
    for rep_key, model, label, dx, dy, ha in CLASSICAL_LABELS:
        c = cls[(cls["rep_key"] == rep_key) & (cls["Model"] == model)]
        i = itw[(itw["rep_key"] == rep_key) & (itw["Model"] == model)]
        if len(c) != 1 or len(i) != 1:
            print(f"  ! {rep_key}/{model!r}: {len(c)} comparison and {len(i)} in-the-wild rows "
                  f"(need exactly 1 of each), skipped")
            continue
        rows.append({"label": label, "family": "classical", "dx": dx, "dy": dy, "ha": ha,
                     "x": float(c.iloc[0]["Macro-F1"]), "y": float(i.iloc[0]["window_acc"])})
    tf = os.path.join(results_dir, "separable_hp_sweep_test.csv")
    iw = os.path.join(results_dir, "separable_hp_sweep_in_the_wild.csv")
    if os.path.exists(tf) and os.path.exists(iw):
        rows.append({"label": "razdvojiva,\npodešena", "family": "cnn", "dx": 12, "dy": 0,
                     "ha": "left",
                     "x": float(pd.read_csv(tf).iloc[0]["test_f1"]),
                     "y": float(pd.read_csv(iw).iloc[0]["window_acc"])})

    points = pd.DataFrame(rows)
    ranges = _seed_ranges(results_dir)
    for col in ("xlo", "xhi", "ylo", "yhi"):
        points[col] = float("nan")
    for label, (xlo, xhi, ylo, yhi) in ranges.items():
        m = points["label"] == label
        points.loc[m, ["xlo", "xhi", "ylo", "yhi"]] = [xlo, xhi, ylo, yhi]
    return points


def figure_scatter(results_dir: str, out_dir: str) -> str:
    points = _load_scatter_points(results_dir)
    if len(points) < 3:
        raise SystemExit("not enough measured candidates for the scatter")

    from scipy.stats import spearmanr
    rho, pval = spearmanr(points["x"], points["y"])

    fig, ax = plt.subplots(figsize=(10, 6.6))
    ax.grid(True, linestyle="--", linewidth=0.6, color="#c9c9c4", alpha=0.6)
    ax.set_axisbelow(True)

    measured = points.dropna(subset=["xlo"])
    for _, p in measured.iterrows():
        ax.plot([p["xlo"], p["xhi"]], [p["y"], p["y"]], color=COL_CNN, linewidth=1.1,
                alpha=0.55, zorder=1, solid_capstyle="butt")
        ax.plot([p["x"], p["x"]], [p["ylo"], p["yhi"]], color=COL_CNN, linewidth=1.1,
                alpha=0.55, zorder=1, solid_capstyle="butt")

    styles = {
        "cnn": dict(color=COL_CNN, marker="o", label="konvolucijska mreža"),
        "classical": dict(color=COL_CLASSICAL, marker="s", label="klasični postupak (SVC-RBF)"),
    }
    for family, style in styles.items():
        sub = points[points["family"] == family]
        if sub.empty:
            continue
        ax.scatter(sub["x"], sub["y"], s=90, zorder=3,
                   facecolor=style["color"], edgecolor="white", linewidth=1.4,
                   marker=style["marker"], label=style["label"])

    # The shipped model gets a ring so it is findable without reading labels.
    shipped = points[points["label"] == "isporučeni model"]
    if not shipped.empty:
        ax.scatter(shipped["x"], shipped["y"], s=320, zorder=2,
                   facecolor="none", edgecolor=COL_CNN, linewidth=1.8)

    for _, p in points.iterrows():
        ax.annotate(p["label"], (p["x"], p["y"]),
                    textcoords="offset points", xytext=(p["dx"], p["dy"]),
                    ha=p["ha"], va="center", fontsize=9, color=INK_SOFT,
                    linespacing=1.35)

    # Subject *codes* 20-24, not the 0-based ids 19-23 the code uses: the thesis
    # numbers subjects 1 to 24 throughout (§3.3.4).
    ax.set_xlabel("Makro F1-mjera na skupu za ispitivanje MotionSense (ispitanici 20–24)")
    ax.set_ylabel("Točnost po prozoru na vlastitim snimkama\n(12 označenih snimaka, 240 prozora)")
    ax.set_title("Poredak kandidata na skupu MotionSense ne prenosi se na vlastite snimke")
    ax.set_xlim(0.880, 0.985)
    ax.set_ylim(0.288, 0.930)
    # Croatian decimal separator.
    comma = matplotlib.ticker.FuncFormatter(
        lambda v, _: f"{v:.2f}".replace(".", ",").replace("-", "−"))
    ax.xaxis.set_major_formatter(comma)
    ax.yaxis.set_major_formatter(comma)

    def _hr(value: float) -> str:
        # Croatian decimal comma and a true minus sign, not a hyphen.
        return f"{value:.2f}".replace(".", ",").replace("-", "−")

    ax.annotate("Nema pozitivne povezanosti između dviju osi:\n"
                f"Spearmanov ρ = {_hr(rho)} (p = {_hr(pval)}, n = {len(points)}).\n"
                "Točke su pojedinačna pokretanja, a crte kroz dvije od njih\n"
                "pokazuju raspon po četirima početnim stanjima učenja.",
                xy=(0.985, 0.965), xycoords="axes fraction", ha="right", va="top",
                fontsize=9, color=INK_SOFT, linespacing=1.4,
                bbox=dict(boxstyle="round,pad=0.45", facecolor="white",
                          edgecolor="#c9c9c4", linewidth=0.7))
    ax.legend(loc="upper left", frameon=True, framealpha=1.0, edgecolor="#c9c9c4", fontsize=9)

    fig.tight_layout()
    out = os.path.join(out_dir, "slika-3-6-usporedba-dviju-osi.png")
    fig.savefig(out, dpi=200)
    plt.close(fig)
    print(f"  Spearman rho = {rho:.4f} (p = {pval:.4f}, n = {len(points)})")
    return out


def figure_confusion(out_dir: str) -> str:
    """Confusion matrix of models/cnn_final.tflite on MotionSense subjects 19-23.

    Window set and channel derivation come from
    `classical_representation_comparison.py`, same as every other §3.4 number.
    """
    import importlib.util
    import tensorflow as tf

    sys.path.insert(0, _ML_DIR)
    from utils.orientation_invariant_features import WALKING_FRAME_V2_COLS  # noqa: E402
    from utils.streaming_offline_compare import normalize_window  # noqa: E402

    spec = importlib.util.spec_from_file_location(
        "_crc", os.path.join(_SCRIPTS_DIR, "classical_representation_comparison.py"))
    crc = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(crc)

    print("  loading MotionSense ...")
    raw = crc.load_motionsense()
    test = raw[raw["id"].isin(range(19, 24))]
    derived = crc.compute_walking_frame_features_v2(
        test, fs_hz=crc.FS_HZ, smooth_seconds=crc.SMOOTH_SECONDS)
    X, y, _ = crc.sliding_windows(derived, WALKING_FRAME_V2_COLS)
    Xn = np.stack([normalize_window(w) for w in X]).astype(np.float32)
    print(f"  test windows: {Xn.shape}")

    model_path = os.path.join(_REPO_ROOT, "models", "cnn_final.tflite")
    interp = tf.lite.Interpreter(model_path=model_path)
    interp.allocate_tensors()
    in_idx = interp.get_input_details()[0]["index"]
    out_idx = interp.get_output_details()[0]["index"]
    preds = []
    for window in Xn:
        interp.set_tensor(in_idx, window[None, ...])
        interp.invoke()
        preds.append(int(interp.get_tensor(out_idx).argmax()))
    preds = np.array(preds)

    n = len(ACT_CODES)
    cm = np.zeros((n, n), dtype=int)
    for true, pred in zip(y.astype(int), preds):
        cm[true, pred] += 1
    row_frac = cm / cm.sum(axis=1, keepdims=True)
    acc = float((preds == y.astype(int)).mean())
    print(f"  accuracy {acc:.4f}")

    fig, ax = plt.subplots(figsize=(8.2, 6.6))
    im = ax.imshow(row_frac, cmap="Blues", vmin=0, vmax=1)
    labels = [ACT_HR[c] for c in ACT_CODES]
    ax.set_xticks(range(n), labels, fontsize=9)
    ax.set_yticks(range(n), labels, fontsize=9)
    ax.set_xlabel("Predviđena aktivnost")
    ax.set_ylabel("Stvarna aktivnost")
    ax.set_title("Matrica zabune izvezenog modela na skupu za ispitivanje")

    for i in range(n):
        for j in range(n):
            ax.text(j, i, f"{cm[i, j]}\n{row_frac[i, j] * 100:.1f} %",
                    ha="center", va="center", fontsize=9, linespacing=1.25,
                    color="white" if row_frac[i, j] > 0.55 else INK)

    cbar = fig.colorbar(im, ax=ax, fraction=0.046, pad=0.03)
    cbar.set_label("Udio prozora unutar reda", fontsize=9)
    cbar.outline.set_edgecolor("#c9c9c4")
    ax.set_xticks(np.arange(-0.5, n, 1), minor=True)
    ax.set_yticks(np.arange(-0.5, n, 1), minor=True)
    ax.grid(which="minor", color="white", linewidth=2)
    ax.tick_params(which="minor", length=0)

    fig.tight_layout()
    out = os.path.join(out_dir, "slika-3-5-matrica-zabune.png")
    fig.savefig(out, dpi=200)
    plt.close(fig)
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--figure", choices=["scatter", "confusion", "both"], default="both")
    ap.add_argument("--results-dir", default=os.path.join(_ML_DIR, "results"),
                    help="where the result CSVs live (override only for testing)")
    ap.add_argument("--out-dir", default=None)
    args = ap.parse_args()

    out_dir = args.out_dir or os.path.join(args.results_dir, "figures")
    os.makedirs(out_dir, exist_ok=True)
    _thesis_style()

    if args.figure in ("scatter", "both"):
        print("scatter:")
        print("  saved ->", figure_scatter(args.results_dir, out_dir))
    if args.figure in ("confusion", "both"):
        print("confusion matrix:")
        print("  saved ->", figure_confusion(out_dir))


if __name__ == "__main__":
    main()

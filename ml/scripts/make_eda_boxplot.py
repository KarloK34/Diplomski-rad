"""Regenerates the activity box plot (Slika 3.3) using Croatian activity names
instead of the raw MotionSense column codes (dws, ups, ...), which are never
defined in the thesis text. Everything else matches the original figure.

Usage:
    python ml/scripts/make_eda_boxplot.py [--out FILE]
"""
from __future__ import annotations
import argparse, os
import numpy as np, pandas as pd
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
import seaborn as sns

_ML_DIR = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), os.pardir))
_DATA = os.path.join(os.path.abspath(os.path.join(_ML_DIR, os.pardir)), "data", "A_DeviceMotion_data")

ACT = ["dws", "ups", "wlk", "jog", "std", "sit"]
HR = {"dws": "silazak\nstepenicama", "ups": "uspon\nstepenicama", "wlk": "hodanje",
      "jog": "trčanje", "std": "stajanje", "sit": "sjedenje"}
TRIALS = {"dws": [1, 2, 11], "ups": [3, 4, 12], "wlk": [7, 8, 15],
          "jog": [9, 16], "std": [6, 14], "sit": [5, 13]}
COLS = ["userAcceleration.x", "userAcceleration.y", "userAcceleration.z"]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(_ML_DIR, "results", "figures",
                                                  "slika-3-3-boxplot-aktivnosti.png"))
    args = ap.parse_args()

    data = {}
    for act in ACT:
        vals = []
        for trial in TRIALS[act]:
            for sub in range(1, 25):
                path = os.path.join(_DATA, f"{act}_{trial}", f"sub_{sub}.csv")
                if os.path.exists(path):
                    d = pd.read_csv(path, usecols=COLS).to_numpy()
                    vals.append(np.sqrt((d ** 2).sum(axis=1)))
        data[act] = np.concatenate(vals)
        print(f"  {act}: {data[act].size} uzoraka, medijan {np.median(data[act]):.3f} g")

    plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10,
                         "figure.facecolor": "white", "axes.facecolor": "white"})
    fig, ax = plt.subplots(figsize=(10, 5))
    sns.boxplot(data=[data[a] for a in ACT], ax=ax, showfliers=False,
                palette="Set2", linewidth=1.0, width=0.7)
    ax.set_xticks(range(len(ACT)), [HR[a] for a in ACT])
    ax.set_xlabel("Aktivnost")
    ax.set_ylabel("Norma (g)")
    ax.set_title("Norma akceleracije po aktivnosti, svi ispitanici "
                 "(izdvojene vrijednosti skrivene)")
    ax.yaxis.set_major_formatter(
        matplotlib.ticker.FuncFormatter(lambda v, _: f"{v:.1f}".replace(".", ",")))
    fig.tight_layout()
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    fig.savefig(args.out, dpi=200)
    print("saved ->", args.out)


if __name__ == "__main__":
    main()

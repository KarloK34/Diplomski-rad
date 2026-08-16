"""Slike 3.7 i 3.8 za potpoglavlje 3.5 diplomskog rada."""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

FILL = "#F0F0F0"
EDGE = "#1A1A1A"
FRAME = "#8C8C8C"


class Canvas:
    def __init__(self, w, h):
        self.fig, self.ax = plt.subplots(figsize=(w, h))
        self.ax.set_xlim(0, 100)
        self.ax.set_ylim(0, 100)
        self.ax.axis("off")
        self.aspect = w / h

    def _fits(self, txt, x, y, w, h, padx=2.0, pady=2.0):
        self.fig.canvas.draw()
        r = self.fig.canvas.get_renderer()
        bb = txt.get_window_extent(renderer=r)
        inv = self.ax.transData.inverted()
        (x0, y0), (x1, y1) = inv.transform([[bb.x0, bb.y0], [bb.x1, bb.y1]])
        return (x1 - x0) <= (w - 2 * padx) and (y1 - y0) <= (h - 2 * pady)

    def _fit(self, txt, x, y, w, h, fs, padx=2.0, pady=1.2):
        while fs > 4.0 and not self._fits(txt, x, y, w, h, padx, pady):
            fs -= 0.25
            txt.set_fontsize(fs)
        return fs

    def box(self, x, y, w, h, text, fs=10.5, fill=FILL, r=2.0, title=None, tfs=12.5):
        self.ax.add_patch(
            FancyBboxPatch(
                (x, y), w, h,
                boxstyle=f"round,pad=0,rounding_size={r}",
                linewidth=1.3, edgecolor=EDGE, facecolor=fill,
                mutation_aspect=self.aspect,
            )
        )
        if title is None:
            t = self.ax.text(x + w / 2, y + h / 2, text, ha="center", va="center",
                             fontsize=fs, color="#111111", linespacing=1.4)
            return (t, self._fit(t, x, y, w, h, fs))
        th = h * 0.36
        bh = h * 0.64
        t1 = self.ax.text(x + w / 2, y + h - th / 2, title, ha="center", va="center",
                          fontsize=tfs, color="#111111", fontweight="bold")
        self._fit(t1, x, y + h - th, w, th, tfs)
        t2 = self.ax.text(x + w / 2, y + bh / 2, text, ha="center", va="center",
                          fontsize=fs, color="#111111", linespacing=1.35)
        return ((t1, t2), (self._fit(t1, x, y + h - th, w, th, tfs),
                           self._fit(t2, x, y, w, bh, fs)))

    def frame(self, x, y, w, h, label, just="l", fs=11.5):
        self.ax.add_patch(
            FancyBboxPatch(
                (x, y), w, h,
                boxstyle="round,pad=0,rounding_size=2.0",
                linewidth=1.0, edgecolor=FRAME, facecolor="none",
                mutation_aspect=self.aspect,
            )
        )
        if just == "l":
            self.ax.text(x + 2.6, y + h - 3.8, label, ha="left", va="center",
                         fontsize=fs, color="#333333")
        else:
            self.ax.text(x + w - 2.6, y + h - 3.8, label, ha="right", va="center",
                         fontsize=fs, color="#333333")

    def arrow(self, x1, y1, x2, y2):
        self.ax.add_patch(
            FancyArrowPatch((x1, y1), (x2, y2), arrowstyle="-|>",
                            mutation_scale=12, linewidth=1.3, color=EDGE,
                            shrinkA=0, shrinkB=0)
        )

    @staticmethod
    def unify(items):
        """items: list of (Text, size) -> set all to the smallest fitted size."""
        m = min(sz for _, sz in items)
        for t, _ in items:
            t.set_fontsize(m)

    def save(self, path):
        self.fig.savefig(path, dpi=300, bbox_inches="tight", pad_inches=0.05,
                         facecolor="white")


# ---------------------------------------------------------------- slika 3.7
c = Canvas(8.0, 4.2)
L, R = 2.0, 66.0          # lijevi stupac (slojevi)
AL, AR = 70.5, 98.0       # desni blok (analiza hoda)

g = []
g.append(c.box(L, 76, R - L, 22,
      "zasloni i elementi sučelja, navigacija, prikaz sažetka\nsesije i kretanja parametara hoda kroz vrijeme",
      title="Sloj prikaza"))
small = [c.box(AL, 76, AR - AL, 22,
      "izdvajanje odsječaka,\notkrivanje događaja hoda,\nizračun parametara hoda",
      title="Analiza hoda", tfs=11.5, fs=9.5)]

g.append(c.box(L, 50, R - L, 22,
      "tijek snimanja sesije, ograničenje trajanja,\nprijava korisnika, stanje popisa sesija i postavki",
      title="Sloj upravljanja stanjem (BLoC)"))

small.append(c.box(L, 24, 31.0, 22,
      "zapis sesije na uređaju,\nsažeci sesija u oblaku,\nprofil i postavke",
      title="Repozitoriji", fs=9.5))
small.append(c.box(L + 33.0, 24, 31.0, 22,
      "prikupljanje i pretvorba očitanja,\nizdvajanje značajki, inferencija,\nizglađivanje, pozadinska usluga",
      title="Servisi", fs=9.5))

g.append(c.box(L, 2, R - L, 18,
      "senzori uređaja, izvedbeno okruženje TensorFlow Lite,\ndatotečni sustav, Firebase",
      title="Vanjski izvori", fill="#FFFFFF"))
c.unify([(ts[0], szs[0]) for ts, szs in g + small])
c.unify([(ts[1], szs[1]) for ts, szs in g])
c.unify([(ts[1], szs[1]) for ts, szs in small])

c.arrow(R, 87, AL, 87)
c.arrow((L + R) / 2, 76, (L + R) / 2, 72)
c.arrow(L + 15.5, 50, L + 15.5, 46)
c.arrow(L + 48.5, 50, L + 48.5, 46)
c.arrow(L + 15.5, 24, L + 15.5, 20)
c.arrow(L + 48.5, 24, L + 48.5, 20)
c.save("slika-3-7-slojevi.png")

# ---------------------------------------------------------------- slika 3.8
c = Canvas(9.0, 3.9)
LEFT, RIGHT = 2.5, 98.5
ROW_W = RIGHT - LEFT
gap = 1.9

c.frame(1.0, 62.0, 98.0, 36.0,
        "Tijekom snimanja sesije: izolat pozadinske usluge")
live = [
    "Senzori\nakcelerometar\ni žiroskop",
    "Sastavljanje\nuzoraka\npri 50 Hz",
    "Kanali neovisni\no orijentaciji\n(kauzalno)",
    "Prozor\n128 × 8",
    "Prepoznavanje\naktivnosti\n(TensorFlow Lite)",
    "Izglađivanje\nniza predikcija",
]
w1 = (ROW_W - gap * (len(live) - 1)) / len(live)
y1, h1 = 65.0, 24.0
row1 = []
for i, t in enumerate(live):
    x = LEFT + i * (w1 + gap)
    row1.append(c.box(x, y1, w1, h1, t, fs=10.0))
    if i:
        c.arrow(x - gap, y1 + h1 / 2, x, y1 + h1 / 2)
c.unify(row1)

y_log, h_log = 48.0, 9.0
c.box(LEFT, y_log, ROW_W, h_log,
      "Zapis sesije na uređaju: predikcije i sirovi uzorci",
      fs=11.0, fill="#FFFFFF", r=1.5)
c.arrow(LEFT + 5 * (w1 + gap) + w1 / 2, y1, LEFT + 5 * (w1 + gap) + w1 / 2, y_log + h_log)
# sirovi uzorci ulaze u zapis sesije neovisno o predikcijama
c.arrow(LEFT + 1 * (w1 + gap) + w1 / 2, y1, LEFT + 1 * (w1 + gap) + w1 / 2, y_log + h_log)

c.frame(1.0, 13.0, 98.0, 32.0,
        "Nakon zaustavljanja sesije: radni izolat", just="r")
post = [
    "Odsječci lokomocije\ni odsječci hoda\npo ravnom",
    "Pridruživanje\nisječaka\nsirovog signala",
    "Otkrivanje\ndogađaja hoda",
    "Izračun\nparametara hoda",
]
w2 = (ROW_W - gap * (len(post) - 1)) / len(post)
y2, h2 = 16.0, 22.0
row2 = []
for i, t in enumerate(post):
    x = LEFT + i * (w2 + gap)
    row2.append(c.box(x, y2, w2, h2, t, fs=10.0))
    if i:
        c.arrow(x - gap, y2 + h2 / 2, x, y2 + h2 / 2)
c.unify(row2)
c.arrow(LEFT + w2 / 2, y_log, LEFT + w2 / 2, y2 + h2)

y_sum, h_sum = 1.0, 9.0
c.box(LEFT, y_sum, ROW_W, h_sum,
      "Sažetak sesije: prikaz korisniku i sinkronizacija sažetka u oblaku",
      fs=11.0, fill="#FFFFFF", r=1.5)
c.arrow(LEFT + 3 * (w2 + gap) + w2 / 2, y2, LEFT + 3 * (w2 + gap) + w2 / 2, y_sum + h_sum)
c.save("slika-3-8-put.png")
print("ok")

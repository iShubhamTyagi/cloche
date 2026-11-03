"""Brush height maps and the stamping engine for icing (decorating step 3).

Pure numpy, no Blender: imported by tools.py and mirrored line for line by the app's Swift
`HeightField` (Packages/ClocheKit/Sources/Decorating). Heights are in millimetres.

Each brush is a 256 x 256 map, normalised 0..1, with its real footprint (mm across) and maximum
height (mm). Stamping rule (the app does the same):
- piped beads: within one stroke the layer is the max of its stamps; the stroke then lands on
  the field as field = max(field, base + layer), where base is the field under the stroke
  before it began (beads sit on what was there, overlapping beads merge instead of stacking).
- spatula: field moves toward the target thickness under the soft mask.
- pour: field = max(field, level * blob) (a flat pool with a soft organic edge).
- drizzle: thin round line stamps, same rule as beads.
- dust: a colour-only density layer; no height.
"""
import math

import numpy as np

N = 256
xs = (np.arange(N) + 0.5) / N * 2 - 1          # -1..1 across the map
X, Y = np.meshgrid(xs, xs)
R = np.sqrt(X * X + Y * Y)
TH = np.arctan2(Y, X)

# name: footprint mm (map width), max height mm, kind
SPECS = {
    "bead_round": (6.0, 3.2, "bead"),
    "bead_star": (9.0, 4.0, "bead"),
    "bead_petal": (12.0, 3.0, "bead"),
    "dollop": (9.0, 4.8, "bead"),
    "tail": (5.0, 3.6, "bead"),
    "drizzle": (2.4, 0.9, "bead"),
    "spatula_mask": (40.0, 1.0, "mask"),
    "pour_blob": (60.0, 1.0, "mask"),
    "dust_noise": (30.0, 1.0, "mask"),
}


def _dome(r, power=0.5):
    return np.clip(1 - r * r, 0, 1) ** power


def maps():
    """{name: 256x256 float32 0..1}"""
    m = {}
    m["bead_round"] = _dome(R, 0.6)
    ridges = 0.78 + 0.22 * np.cos(8 * TH)                  # open star: 8 ridges
    m["bead_star"] = _dome(R / (0.88 + 0.12 * np.cos(8 * TH)), 0.55) * ridges
    # Petal: a thin ribbon, thick on one edge, tapering to a ruffled thin edge.
    across = np.clip((Y + 1) / 2, 0, 1)                   # 0 thick edge .. 1 thin edge
    m["bead_petal"] = np.clip(1 - (X / 0.95) ** 2, 0, 1) ** 0.5 * (1 - across) ** 1.4 * \
        (0.9 + 0.1 * np.sin(X * 18)) * (np.abs(Y) < 0.98)
    m["dollop"] = _dome(R, 0.75)
    m["tail"] = np.clip(1 - R, 0, 1) ** 1.6                # a soft peak where the tip lifts off
    m["drizzle"] = _dome(R, 0.5)
    m["spatula_mask"] = np.clip(1 - (X / 1.0) ** 2 - (Y / 0.33) ** 2, 0, 1) ** 0.7
    rng = np.random.default_rng(7)
    wobble = sum(rng.uniform(0.02, 0.06) * np.cos(k * TH + rng.uniform(0, 6.28)) for k in range(2, 9))
    m["pour_blob"] = np.clip((0.82 + wobble - R) / 0.08, 0, 1)
    m["pour_blob"] = m["pour_blob"] * m["pour_blob"] * (3 - 2 * m["pour_blob"])
    # Dust: tileable dots (integer frequencies wrap).
    u, v = (X + 1) / 2, (Y + 1) / 2
    dust = np.zeros_like(X)
    for _ in range(40):
        fx, fy = rng.integers(4, 40, 2)
        dust += np.cos(2 * math.pi * (fx * u + rng.random())) * np.cos(2 * math.pi * (fy * v + rng.random()))
    dust = (dust - dust.min()) / (dust.max() - dust.min())
    m["dust_noise"] = np.clip((dust - 0.55) / 0.3, 0, 1)
    return {k: v.astype(np.float32) for k, v in m.items()}


def manifest():
    return {name: {"file": f"{name}.png", "footprint_mm": fp, "max_height_mm": h,
                   "mm_per_px": round(fp / N, 5), "kind": kind,
                   "sizes": {"small": 0.75, "medium": 1.0, "large": 1.35} if kind == "bead" else None}
            for name, (fp, h, kind) in SPECS.items()}


class Field:
    """A rectangular height field in mm, `res` texels across `size_mm`."""

    def __init__(self, size_mm, res):
        self.size, self.res = size_mm, res
        self.h = np.zeros((res, res), np.float32)
        self.mm_per_px = size_mm / res

    def _sample_brush(self, brush, cx, cy, scale, angle):
        fp, hmax, _ = SPECS[brush]
        half = fp * scale / 2
        x0, x1 = int((cx - half) / self.mm_per_px), int((cx + half) / self.mm_per_px) + 1
        y0, y1 = int((cy - half) / self.mm_per_px), int((cy + half) / self.mm_per_px) + 1
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, self.res), min(y1, self.res)
        if x1 <= x0 or y1 <= y0:
            return None
        px = (np.arange(x0, x1) + 0.5) * self.mm_per_px - cx
        py = (np.arange(y0, y1) + 0.5) * self.mm_per_px - cy
        PX, PY = np.meshgrid(px, py)
        c, s = math.cos(-angle), math.sin(-angle)
        u = (PX * c - PY * s) / half
        v = (PX * s + PY * c) / half
        img = MAPS[brush]
        iu = np.clip(((u + 1) / 2 * N).astype(int), 0, N - 1)
        iv = np.clip(((v + 1) / 2 * N).astype(int), 0, N - 1)
        val = img[iv, iu] * ((np.abs(u) <= 1) & (np.abs(v) <= 1))
        return (slice(y0, y1), slice(x0, x1)), val * hmax * scale

    def stroke(self, brush, points, scale=1.0, spacing=0.25, tail=True):
        """Pipe along [(x_mm, y_mm), ...]: stamps every `spacing` x footprint."""
        layer = np.zeros_like(self.h)
        base = np.zeros_like(self.h)
        path = _resample(points, SPECS[brush][0] * scale * spacing)
        for i, (x, y) in enumerate(path):
            nx, ny = path[min(i + 1, len(path) - 1)]
            px_, py_ = path[max(i - 1, 0)]
            angle = math.atan2(ny - py_, nx - px_)
            hit = self._sample_brush(brush, x, y, scale, angle)
            if hit is None:
                continue
            sl, val = hit
            under = self.h[int(min(max(y / self.mm_per_px, 0), self.res - 1)),
                           int(min(max(x / self.mm_per_px, 0), self.res - 1))]
            np.maximum(layer[sl], val, out=layer[sl])
            np.maximum(base[sl], np.where(val > 0, under, 0), out=base[sl])
        if tail and brush.startswith("bead") and path:
            hit = self._sample_brush("tail", *path[-1], scale, 0)
            if hit:
                sl, val = hit
                np.maximum(layer[sl], val, out=layer[sl])
        self.h = np.maximum(self.h, np.where(layer > 0, base + layer, 0))

    def spread(self, points, target_mm=3.0, scale=1.0, strength=0.6):
        for x, y in _resample(points, SPECS["spatula_mask"][0] * scale * 0.2):
            hit = self._sample_brush("spatula_mask", x, y, scale, 0)
            if hit:
                sl, val = hit
                self.h[sl] += (target_mm - self.h[sl]) * np.clip(val, 0, 1) * strength

    def pour(self, x, y, level_mm=2.5, scale=1.0):
        hit = self._sample_brush("pour_blob", x, y, scale, 0)
        if hit:
            sl, val = hit
            self.h[sl] = np.maximum(self.h[sl], val * level_mm)


def _resample(points, step):
    out = [points[0]]
    acc = 0.0
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        d = math.hypot(x1 - x0, y1 - y0)
        t = step - acc
        while t <= d:
            out.append((x0 + (x1 - x0) * t / d, y0 + (y1 - y0) * t / d))
            t += step
        acc = d - (t - step)
    return out


MAPS = maps()

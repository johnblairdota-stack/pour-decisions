"""Fit a look's 3D colour table from the same views drawn two ways.

Used for Warm Haze (scripts/look.gd): the Spire --spireshots views drawn by
Forward+ (the PC) and by the Compatibility renderer (the cloud test pictures),
both on the golden "Last climb" day (--startlevel=10), with Comic Ink:

  godot --rendering-method forward_plus --path . -- --autotest --nophones \
      --site=spire --startlevel=10 --spirefill=0.08 --spireshots=fp10
  godot --rendering-driver opengl3 --path . -- (same) --spireshots=gl10
  python3 tools/look_lut.py fp10 gl10 assets/looks/warm_haze_lut.png 0.55

A smooth cubic colour transform is fitted (robustly: people and shadows move
between the runs) and blended with no change by the last number, then baked
as a 32x32x32 table: a strip PNG, 32 slices of 32x32 side by side, red
across a slice, green down, blue across the slices. Entries sit at texel
centres ((i + 0.5) / 32), as the engine samples it.
"""
import glob
import os
import sys

import numpy as np
from PIL import Image

N = 32


def feats(c):
    r, g, b = c[:, 0], c[:, 1], c[:, 2]
    return np.stack([np.ones_like(r), r, g, b, r * r, g * g, b * b, r * g, g * b, r * b,
                     r ** 3, g ** 3, b ** 3, r * g * b], 1)


def main():
    src, dst, out = sys.argv[1], sys.argv[2], sys.argv[3]
    k = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0
    xs, ys = [], []
    for f in sorted(glob.glob(os.path.join(src, "*.png"))):
        other = os.path.join(dst, os.path.basename(f))
        if not os.path.exists(other):
            continue
        a = np.asarray(Image.open(f).convert("RGB").resize((320, 180), Image.BOX), dtype=np.float64) / 255
        b = np.asarray(Image.open(other).convert("RGB").resize((320, 180), Image.BOX), dtype=np.float64) / 255
        xs.append(a.reshape(-1, 3))
        ys.append(b.reshape(-1, 3))
    x, y = np.concatenate(xs), np.concatenate(ys)
    w = np.ones(len(x))
    for _ in range(6):
        m, *_ = np.linalg.lstsq(feats(x) * w[:, None], y * w[:, None], rcond=None)
        res = np.abs(feats(x) @ m - y).sum(1)
        w = 1 / np.maximum(1, res / (np.median(res) * 3 + 1e-3))
    print("mean error: fitted %.3f, unchanged %.3f" % (np.abs(feats(x) @ m - y).mean(), np.abs(x - y).mean()))
    g = (np.arange(N) + 0.5) / N
    img = np.zeros((N, N * N, 3))
    for bi in range(N):
        for gi in range(N):
            c = np.stack([g, np.full(N, g[gi]), np.full(N, g[bi])], 1)
            img[gi, bi * N:(bi + 1) * N] = np.clip((1 - k) * c + k * np.clip(feats(c) @ m, 0, 1), 0, 1)
    Image.fromarray((img * 255 + 0.5).astype(np.uint8)).save(out)


if __name__ == "__main__":
    main()

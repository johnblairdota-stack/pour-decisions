"""The fly-in's rendered views (render_fly.py's fly_<i>.png) made into the game's pictures: the model's
far edge and the empty sky beyond it go under a band of haze (the cloud base it's just come down
through), and each is saved as assets/fly/<tower>_<i>.jpg.
    python tools/blender/spire/fly_pics.py <render_dir> [tower=spire]"""
import os
import sys

import numpy as np
from PIL import Image

HAZE = np.array((0.87, 0.89, 0.91))
SOLID, FADE = 0.035, 0.24      # of the height: solid haze this far under the model's edge, gone this much lower


def edge_row(a):
    """The lowest row that is still the void past the model (dark, and bluer than it is red), 0..1."""
    lum = a.mean(axis=2)
    void = (lum < 0.22) & (a[:, :, 2] > a[:, :, 0] * 1.15)
    rows = np.nonzero(void.mean(axis=1) > 0.25)[0]
    return (rows.max() + 1) / a.shape[0] if len(rows) else 0.0


def main():
    src = sys.argv[1]
    tower = next((x[6:] for x in sys.argv if x.startswith("tower=")), "spire")
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "fly")
    os.makedirs(out, exist_ok=True)
    i = 0
    while os.path.exists(os.path.join(src, "fly_%d.png" % i)):
        a = np.asarray(Image.open(os.path.join(src, "fly_%d.png" % i)).convert("RGB"), float) / 255.0
        yv = max(edge_row(a), 0.06)
        y = (np.arange(a.shape[0]) + 0.5) / a.shape[0]
        t = np.clip((y - (yv + SOLID)) / FADE, 0.0, 1.0)
        w = 1.0 - t * t * (3.0 - 2.0 * t)
        a = a * (1.0 - w[:, None, None]) + HAZE * w[:, None, None]
        Image.fromarray((a * 255.0 + 0.5).astype(np.uint8)).save(os.path.join(out, "%s_%d.jpg" % (tower, i)), quality=88)
        print("fly_pics: view %d, model edge at %.2f" % (i, yv))
        i += 1


if __name__ == "__main__":
    main()

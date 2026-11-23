"""render_film.py's frames made into the game's film: the model's far edge and the empty sky past it
go under a band of haze (the cloud base it has just come down through), the frames are encoded as
Ogg Theora (the one video format Godot plays everywhere, the tablet included) and the cameras are
copied beside it.
    python tools/blender/spire/film_pack.py <frames_dir> [tower=spire] [q=9]
Writes assets/fly/<tower>.ogv and assets/fly/<tower>_cams.json. Needs ffmpeg with libtheora.
A frame that isn't rendered yet is stood in for by the nearest one that is (for a look part-way)."""
import json
import os
import shutil
import subprocess
import sys
import tempfile

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
    src = os.path.abspath(sys.argv[1])
    tower = next((x[6:] for x in sys.argv if x.startswith("tower=")), "spire")
    q = next((x[2:] for x in sys.argv if x.startswith("q=")), "9")
    out = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "fly"))
    os.makedirs(out, exist_ok=True)
    cams = json.load(open(os.path.join(src, "cams.json")))
    n = int(cams["frames"])
    have = [i for i in range(n) if os.path.exists(os.path.join(src, "film_%04d.png" % i))]
    tmp = tempfile.mkdtemp()
    yv = 0.0
    for i in range(n):
        j = min(have, key=lambda k: abs(k - i))
        a = np.asarray(Image.open(os.path.join(src, "film_%04d.png" % j)).convert("RGB"), float) / 255.0
        # (the edge only ever goes up the frame as the camera comes down: no flicker from a missed row)
        e = max(edge_row(a), 0.06)
        yv = e if i == 0 else min(yv, e) if e < yv else yv * 0.5 + e * 0.5
        y = (np.arange(a.shape[0]) + 0.5) / a.shape[0]
        t = np.clip((y - (yv + SOLID)) / FADE, 0.0, 1.0)
        w = 1.0 - t * t * (3.0 - 2.0 * t)
        a = a * (1.0 - w[:, None, None]) + HAZE * w[:, None, None]
        Image.fromarray((a * 255.0 + 0.5).astype(np.uint8)).save(os.path.join(tmp, "f%04d.png" % i))
    ogv = os.path.join(out, tower + ".ogv")
    subprocess.check_call(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(cams["fps"]), "-i", os.path.join(tmp, "f%04d.png"),
                           "-c:v", "libtheora", "-q:v", q, "-pix_fmt", "yuv420p", "-an", ogv])
    shutil.rmtree(tmp)
    json.dump(cams, open(os.path.join(out, tower + "_cams.json"), "w"))
    print("film_pack: %d of %d frames rendered, %s (%.1f MB)" % (len(have), n, ogv, os.path.getsize(ogv) / 1e6))


if __name__ == "__main__":
    main()

"""Find where a landmark really is from photos whose cameras are solved: grid search of (x, y, z) that
minimises the reprojection error of its marks.  <blender python> -I tools/hsw/triangulate.py lift_top p01,p02,p03"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "blender", "spire"))
import numpy as np  # noqa: E402
import photo_fit as F  # noqa: E402

name, ids = sys.argv[1], sys.argv[2].split(",")
cams = {c["id"]: c for c in json.load(open(os.path.join(HERE, "hsw_cams.json")))["cams"]}
marks = {p["id"]: p for p in json.load(open(os.path.join(HERE, "hsw_marks.json")))["photos"]}
obs = []
for i in ids:
    c = next(v for k, v in cams.items() if k.startswith(i))
    m = next(mm for mm in marks[c["id"]]["marks"] if mm[0] == name)
    W, H = c["size"]
    f = c["focal_35mm"] / 43.27 * np.hypot(W, H)
    pose = [*c["pos"], c["heading_deg"], c["pitch_deg"], f, -c["blender"]["shift_y"] * max(W, H)]
    obs.append((pose, W, H, np.array(m[1:], float)))
x0, y0, z0 = [float(v) for v in sys.argv[3].split(",")] if len(sys.argv) > 3 else (600, 91, 45)
best = None
for x in np.arange(x0 - 80, x0 + 80, 2.0):
    for y in np.arange(y0 - 60, y0 + 60, 2.0):
        for z in np.arange(z0 - 15, z0 + 15, 1.0):
            e = 0.0
            for pose, W, H, o in obs:
                q, dz = F.project(pose, np.array([[x, y, z]]), W, H)
                e += float(((q[0] - o) ** 2).sum()) if dz[0] > 0 else 1e9
            if best is None or e < best[0]:
                best = (e, x, y, z)
print(name, "best x %.0f y %.0f z %.0f  rms %.1f px" % (best[1], best[2], best[3], (best[0] / len(obs)) ** 0.5))

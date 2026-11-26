"""render_open.py's exact camera and light, rendered in horizontal strips (the full 1920x1080 frame with
denoising runs out of memory in the cloud on the current, larger scene), then stitched."""
import os, sys
S = "/home/user/pour-decisions/tools/blender/spire"
sys.path.insert(0, S)
import bpy
import render_open as RO
import build_all, preview as P, render_cbd as R
from PIL import Image
out = sys.argv[-1]
os.makedirs(out, exist_ok=True)
N = 4
build_all.build_all(None, write_meta=False)
P.setup_morning()
P.apply_light(78.0, 7.0)
R.setup_cycles(int(os.environ.get("CYC_SAMPLES", "48")))
sc = bpy.context.scene
sc.render.use_border, sc.render.use_crop_to_border = True, True
sc.render.use_persistent_data = False
parts = []
for k in range(N):
    sc.render.border_min_x, sc.render.border_max_x = 0.0, 1.0
    sc.render.border_min_y, sc.render.border_max_y = k / N, (k + 1) / N
    cam = dict(RO.CAM, id="strip%d" % k)
    R.shoot(cam, out, 1.0)
    parts.append(os.path.join(out, "strip%d.png" % k))
    print("STRIP", k, Image.open(parts[-1]).size, flush=True)
W, H = RO.CAM["size"]
im = Image.new("RGB", (W, H))
y = H
for p in parts:                      # border y runs from the bottom
    s = Image.open(p).convert("RGB")
    y -= s.height
    im.paste(s, (0, y))
im.save(os.path.join(out, "open_high.png"))
print("DONE", y)

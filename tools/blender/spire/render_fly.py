"""The Spire fly-in's rendered views: one straight line down out of the cloud to the site, the same
look all the way (so each view pushed in lines up with the next). Rendered in strips.
    python render_fly.py <out> [only=i,j] [w=1920]"""
import math, os, sys
S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, S)
import bpy
import build_all, preview as P, render_cbd as R
from PIL import Image
argv = sys.argv[1:]
out = os.path.abspath(argv[0]); os.makedirs(out, exist_ok=True)
only = next((a[5:] for a in argv if a.startswith("only=")), "")
W = int(next((a[2:] for a in argv if a.startswith("w=")), 1920)); H = W * 9 // 16
T = (0.0, 0.0, 80.0)
HDIR = (-0.682, 0.731)            # from the site towards the camera (the game's +z: over Ann St)
EL = math.radians(24.0)
DIST = [2800.0, 1750.0, 1100.0, 690.0, 430.0, 270.0]
LENS = 21.7                       # the game's own 50 degree lens
def cam_at(s):
    return (T[0] + HDIR[0] * s * math.cos(EL), T[1] + HDIR[1] * s * math.cos(EL), T[2] + s * math.sin(EL))
build_all.build_all(None, write_meta=False)
P.setup_morning()
P.apply_light(78.0, 12.0)
R.setup_cycles(int(os.environ.get("CYC_SAMPLES", "40")))
sc = bpy.context.scene
sc.render.use_border, sc.render.use_crop_to_border = True, True
sc.render.use_persistent_data = False
N = 4 if W <= 1920 else 6
for i, s in enumerate(DIST):
    if only and str(i) not in only.split(","):
        continue
    parts = []
    for k in range(N):
        sc.render.border_min_x, sc.render.border_max_x = 0.0, 1.0
        sc.render.border_min_y, sc.render.border_max_y = k / N, (k + 1) / N
        R.shoot({"id": "v%d_s%d" % (i, k), "pos": cam_at(s), "look_at": T, "lens": LENS, "size": (W, H)}, out, 1.0)
        parts.append(os.path.join(out, "v%d_s%d.png" % (i, k)))
    im = Image.new("RGB", (W, H)); y = H
    for p in parts:
        st = Image.open(p).convert("RGB"); y -= st.height; im.paste(st, (0, y)); os.remove(p)
    im.save(os.path.join(out, "fly_%d.png" % i))
    print("VIEW", i, s, cam_at(s), flush=True)
print("ALLDONE", flush=True)

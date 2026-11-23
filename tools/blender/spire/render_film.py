"""The Spire fly-in as a film: one camera flight through the Brisbane model, frame by frame, from high
in the cloud down to 270 m off the tower (where the game's own live flight takes it on).

    python tools/blender/spire/render_film.py <out_dir> [from=0] [to=N] [w=1280] [fps=24] [--cams]

The camera swings round the tower as it comes down (so the city really moves past: near things faster
than far ones), always looking at the tower, and closes on it at a steady rate: every second takes
the same share off the distance left. Frames already in <out_dir> are skipped, so a run can be done
in pieces. <out_dir>/cams.json holds every frame's camera (the model's metres, z AHD): the game flies
its own camera down the same line while the film hands over. --cams writes only that.
Rendered in strips (the whole frame with denoising runs the cloud machine out of memory)."""
import json
import math
import os
import sys

S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, S)

T = (0.0, 0.0, 80.0)              # what it looks at: the tower's middle
HDIR = (-0.682, 0.731)            # from the tower towards where it ends up (over Ann St: the game's own side)
S0, S1 = 2800.0, 270.0            # m from the tower, start and end
DUR = 5.6                         # s
AZ0, EL0, EL1 = 32.0, 36.0, 24.0  # degrees: round from the end line at the start, up at the start and end
SWING = 0.8                       # of the time: the swing round and down is over by then
LENS = 21.7                       # the game's own 50 degree lens


def smooth(a, b, x):
    u = min(1.0, max(0.0, (x - a) / (b - a)))
    return u * u * (3.0 - 2.0 * u)


def cam_at(t):
    s = S0 * math.exp(-math.log(S0 / S1) * t / DUR)
    f = smooth(0.0, SWING * DUR, t)
    az = math.radians(AZ0 * (1.0 - f))
    el = math.radians(EL0 + (EL1 - EL0) * f)
    hx = HDIR[0] * math.cos(az) - HDIR[1] * math.sin(az)
    hy = HDIR[0] * math.sin(az) + HDIR[1] * math.cos(az)
    return (T[0] + hx * s * math.cos(el), T[1] + hy * s * math.cos(el), T[2] + s * math.sin(el))


def main():
    argv = sys.argv[1:]
    out = os.path.abspath(argv[0])
    os.makedirs(out, exist_ok=True)
    num = lambda k, d: type(d)(next((a[len(k) + 1:] for a in argv if a.startswith(k + "=")), d))
    fps, w = num("fps", 24), num("w", 1280)
    n = int(round(DUR * fps)) + 1
    f0, f1 = num("from", 0), min(n, num("to", n))
    h = w * 9 // 16
    json.dump({"fps": fps, "frames": n, "dur": DUR, "target": T, "lens": LENS,
               "cams": [[round(v, 2) for v in cam_at(i / fps)] for i in range(n)]}, open(os.path.join(out, "cams.json"), "w"))
    if "--cams" in argv:
        return
    import bpy
    import build_all
    import preview as P
    import render_cbd as R
    from PIL import Image
    build_all.build_all(None, write_meta=False)
    P.setup_morning()
    P.apply_light(78.0, 12.0)
    R.setup_cycles(int(os.environ.get("CYC_SAMPLES", "40")))
    sc = bpy.context.scene
    sc.render.use_border, sc.render.use_crop_to_border = True, True
    sc.render.use_persistent_data = os.environ.get("PERSIST", "1") == "1"
    strips = num("strips", 3)
    for i in range(f0, f1):
        dst = os.path.join(out, "film_%04d.png" % i)
        if os.path.exists(dst):
            continue
        parts = []
        for k in range(strips):
            sc.render.border_min_x, sc.render.border_max_x = 0.0, 1.0
            sc.render.border_min_y, sc.render.border_max_y = k / strips, (k + 1) / strips
            R.shoot({"id": "f%04d_s%d" % (i, k), "pos": cam_at(i / fps), "look_at": T, "lens": LENS, "size": (w, h)}, out, 1.0)
            parts.append(os.path.join(out, "f%04d_s%d.png" % (i, k)))
        im = Image.new("RGB", (w, h))
        y = h
        for p in parts:
            st = Image.open(p).convert("RGB")
            y -= st.height
            im.paste(st, (0, y))
            os.remove(p)
        im.save(dst)
        print("FRAME", i, flush=True)
    print("ALLDONE", flush=True)


if __name__ == "__main__":
    main()

"""Render HSW + Story Bridge views (as built, morning look).

    blender -b --factory-startup -P tools/hsw/render_hsw.py -- <out_dir> [heroes] [photos] [only=id1,id2] [scale=0.5]

heroes: layout.HSW_HERO_CAMERAS (pos / look_at in absolute metres AHD) -> <out_dir>/hero_<id>.png
photos: tools/hsw/hsw_cams.json (solved by photo_fit.py from tools/hsw/hsw_marks.json) -> <out_dir>/<id>_render.png
"""
import json
import math
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SPIRE = os.path.join(os.path.dirname(HERE), "blender", "spire")
sys.path.insert(0, SPIRE)
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import layout as L  # noqa: E402
import build_all  # noqa: E402
import preview as P  # noqa: E402


def place(cam, pos, look, lens, shift_y=0.0):
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "AUTO"
    cam.data.sensor_width = 36.0
    cam.data.lens = lens
    cam.data.shift_x = 0.0
    cam.data.shift_y = shift_y
    cam.data.clip_start, cam.data.clip_end = 0.3, 6000
    cam.location = pos
    d = Vector(look) - Vector(pos)
    if shift_y:
        d.z = 0.0
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    out = argv[0]
    os.makedirs(out, exist_ok=True)
    only = next((a[5:].split(",") for a in argv if a.startswith("only=")), None)
    scale = float(next((a[6:] for a in argv if a.startswith("scale=")), 1.0))
    t = time.time()
    build_all.build_all(None, write_meta=False)
    print("build %.1fs" % (time.time() - t))
    P.setup_morning()
    P.hide(["logistics"])
    cam = P.camera("cam_hsw")
    if "heroes" in argv:
        for c in L.HSW_HERO_CAMERAS:
            if only and c["id"] not in only:
                continue
            place(cam, c["pos"], c["look_at"], c["lens_mm"], c.get("shift_y", 0.0))
            cam.data.clip_start = c.get("clip_m", 0.3)
            P.apply_light(*L.sun_position(c.get("date", "2024-04-15"), c.get("hour", 9.0)))
            w, h = c.get("size", (1600, 900))
            P.render(os.path.join(out, "hero_%s.png" % c["id"]), int(w * scale), int(h * scale))
    if "photos" in argv:
        cams = json.load(open(os.path.join(HERE, "hsw_cams.json")))["cams"]
        for c in cams:
            if c.get("skip") or (only and c["id"] not in only):
                continue
            cam.data.type = "PERSP"
            cam.data.sensor_fit = "AUTO"
            cam.data.sensor_width = c["blender"]["sensor_mm"]
            cam.data.lens = c["blender"]["lens_mm"]
            cam.data.shift_x = 0.0
            cam.data.shift_y = c["blender"]["shift_y"]
            # low cameras: clip the first metres so a bush or tree trunk at the solved spot does not fill the lens
            cam.data.clip_start, cam.data.clip_end = (c.get("clip_m") or (30.0 if c["eye_above_ground_m"] < 3.0 else 0.3)), 6000
            x, y, z = c["pos"]
            cam.location = (x, y, z)
            hd, pt = math.radians(c["heading_deg"]), math.radians(c["pitch_deg"])
            d = Vector((math.sin(hd) * math.cos(pt), math.cos(hd) * math.cos(pt), math.sin(pt)))
            cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
            # round 1: day light only (dusk/night look is a later round); photo hour clamped into the day
            hour = min(max(float(c.get("time_h") or 10.0), 8.5), 15.5)
            P.apply_light(*L.sun_position(c.get("date") or "2024-04-15", hour))
            W, H = c["size"]
            k = 1600 / max(W, H) * scale
            P.render(os.path.join(out, "%s_render.png" % c["id"]), int(round(W * k)), int(round(H * k)))
    print("total %.1fs" % (time.time() - t))


main()

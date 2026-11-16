"""Render the Spire-area views (everything around the Spire site), modelled on tools/hsw/render_hsw.py.

    blender -b --factory-startup -P tools/spire_area/render_area.py -- <out_dir> [showcase] [heroes] [pairs] [commons]
            [only=id1,id2] [scale=0.5]

showcase: the existing showcase views (area_cams.json "showcase") -> <out_dir>/hero_<id>.png
heroes:   new heroes of the area (area_cams.json "heroes")          -> <out_dir>/hero_<id>.png
pairs:    John's solved photo cameras (tools/blender/spire/photo_cams.json) -> <out_dir>/<id>_render.png
commons:  the Commons photo cameras (showcase_cams.json)            -> <out_dir>/<id>_render.png
Views are grouped by build stage (as built, 2017 top-out) so each stage is built once.
If tools/blender/spire/area_hero.py is in build_all.MODULES, its light() sets the round's sky and grade.
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

AH = None
try:
    import area_hero as AH  # noqa: E402
    if AH not in build_all.MODULES:
        AH = None
except ImportError:
    AH = None


def light(date, hour, dusk=False, kind="street"):
    """Sun + sky for one view: preview's look, then the area round's changes when area_hero is built."""
    az, el = L.sun_position(date or "2024-04-15", hour)
    P.apply_light(az, el, "dusk" if dusk else "day")
    if AH is not None:
        AH.light(az, el, dusk, kind)


def agl(p):
    return Vector((p[0], p[1], p[2] + L.ground_z(p[0], p[1])))


def place_agl(cam, c, size=None):
    """Camera from a pos / look_at given as heights above the ground (layout.HERO_CAMERAS style)."""
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "AUTO"
    cam.data.sensor_width = 36.0
    cam.data.lens = c["lens_mm"]
    cam.data.shift_x = 0.0
    cam.data.shift_y = c.get("shift_y", 0.0)
    pos, look = agl(c["pos"]), agl(c["look_at"])
    street = c["pos"][2] < 3.0
    cam.data.clip_start, cam.data.clip_end = c.get("clip_m", 2.0 if street else 0.5), 6000
    cam.location = pos
    d = look - pos
    if c.get("shift_y"):
        d.z = 0.0
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    if size:
        return size
    return (1067, 1600) if c.get("portrait") else (1600, 1000)


def photo_cam(cam, c):
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "AUTO"
    cam.data.sensor_width = c["blender"]["sensor_mm"]
    cam.data.lens = c["blender"]["lens_mm"]
    cam.data.shift_x = 0.0
    cam.data.shift_y = c["blender"]["shift_y"]
    x, y, z = c["pos"]
    street = z - L.ground_z(x, y) < 3.0
    cam.data.clip_start, cam.data.clip_end = (c.get("clip_m") or (6.0 if street else 0.5)), 6000
    cam.location = (x, y, z)
    h, p = math.radians(c["heading_deg"]), math.radians(c["pitch_deg"])
    d = Vector((math.sin(h) * math.cos(p), math.cos(h) * math.cos(p), math.sin(p)))
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    W, H = c["size"]
    k = 1600 / max(W, H)
    return int(round(W * k)), int(round(H * k)), ("street" if street else "aerial")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    out = os.path.abspath(argv[0])
    os.makedirs(out, exist_ok=True)
    only = next((a[5:].split(",") for a in argv if a.startswith("only=")), None)
    scale = float(next((a[6:] for a in argv if a.startswith("scale=")), 1.0))
    A = json.load(open(os.path.join(HERE, "area_cams.json"), encoding="utf-8"))
    pcams = {c["id"]: c for c in json.load(open(os.path.join(SPIRE, "photo_cams.json")))["cams"]}
    ccams = {c["id"]: c for c in json.load(open(os.path.join(SPIRE, "showcase_cams.json")))["cams"]}
    lay = {c["id"]: c for c in L.CAMERAS + L.HERO_CAMERAS}
    jobs = []   # (stage, kind, id, spec)
    if "showcase" in argv:
        for s in A["showcase"]:
            if "photo_day" in s:
                c = pcams[s["photo_day"]]
                jobs.append((c["stage"], "photo_day", s["id"], dict(c, time_h=s.get("hour") or 10.0)))
            else:
                jobs.append(("as_built", "agl", s["id"], lay[s["layout"]]))
    if "heroes" in argv:
        for h in A["heroes"]:
            jobs.append((h.get("stage", "as_built"), "agl", h["id"], h))
    if "pairs" in argv:
        for pid in A["pairs"]:
            jobs.append((pcams[pid]["stage"], "pair", pid, pcams[pid]))
    if "commons" in argv:
        for pid in A["commons_pairs"]:
            jobs.append((ccams[pid]["stage"], "commons", pid, ccams[pid]))
    if only:
        jobs = [j for j in jobs if j[2] in only]
    t0 = time.time()
    done = []
    stages = sorted({j[0] for j in jobs}, key=lambda s: s not in ("as_built", "pre_spire"))
    built = None
    for st in stages:
        want = None if st in ("as_built", "pre_spire") else st
        if built != (want or "as_built"):
            t = time.time()
            build_all.build_all(want, write_meta=False)
            print("build %s %.1fs" % (st, time.time() - t), flush=True)
            P.setup_morning()
            built = want or "as_built"
        cam = P.camera("cam_area")
        for stage, kind, jid, c in jobs:
            if stage != st:
                continue
            P.hide(["spire", "core"], stage == "pre_spire")
            P.hide(["logistics"], stage in ("as_built", "pre_spire") and not c.get("show_logistics"))
            if kind == "agl":
                w, h = place_agl(cam, c, c.get("size"))
                light(c.get("date"), c.get("hour", 9.0), False, "street" if c["pos"][2] < 3 else "aerial")
                path = os.path.join(out, "hero_%s.png" % jid)
            else:
                w, h, where = photo_cam(cam, c)
                dusk = kind == "pair" and "dusk" in jid
                hour = float(c.get("time_h") or (17.4 if dusk else 12.0))
                if not dusk:
                    hour = min(max(hour, 8.5), 15.5)
                light(c.get("date", ""), hour, dusk, where)
                path = os.path.join(out, ("hero_%s.png" % jid) if kind == "photo_day" else ("%s_render.png" % jid))
            P.render(path, int(w * scale), int(h * scale))
            done.append(os.path.basename(path))
            P.hide(["spire", "core", "logistics"], False)
    json.dump({"rendered": done, "seconds": round(time.time() - t0, 1)},
              open(os.path.join(out, "render_log.json"), "w"), indent=1)
    print("total %.1fs, %d images" % (time.time() - t0, len(done)))


main()

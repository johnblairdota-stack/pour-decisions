#!/usr/bin/env python3
"""A straight fly-over of the Brisbane model, rendered frame by frame from the baked tiles.

    python3 tools/city/flyover.py plan <frames.json> [x0,y0,x1,y1] [seconds=60] [fps=24] [z=380] [seg=120]
    CYC_SAMPLES=16 /tmp/city-venv/bin/python tools/city/flyover.py render <frames.json> <out_dir> <tiles_dir> seg=K [width=1280] [step=2]
    ffmpeg -framerate 24 -i <out_dir>/f%05d.png -c:v libx264 -pix_fmt yuv420p -crf 18 flyover.mp4

plan: with no line given, the longest line through the measured block (docs/city/coverage.json): the diagonal
from the south-west corner to the north-east one, which follows the river from St Lucia past the CBD to Hamilton.
The camera flies level at z metres and looks at the ground 1.8 km ahead. Frames are grouped in segments of `seg`
frames; a segment is one Blender process, which loads only the tiles its cameras see (tiles.py) and keeps the
scene in memory between frames. render skips frames that already exist, so a stopped job picks up where it was.
step=2 renders every second frame (half the time; play them at the same fps for a flight twice as fast).
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
ORIGIN = (503046.57, 6962279.05)        # layout.ORIGIN_MGA56 (kept here so `plan` needs no Blender)
LOOK_AHEAD = 1800.0
EDGE = 250.0                            # start and stop this far inside the block


def longest_line():
    tiles = [k for k, t in json.load(open(os.path.join(ROOT, "docs", "city", "coverage.json")))["tiles"].items() if t["lidar"]]
    es = [int(k.split("_")[0]) for k in tiles]
    ns = [int(k.split("_")[1]) for k in tiles]
    x0, x1 = min(es) * 1000 - ORIGIN[0], (max(es) + 1) * 1000 - ORIGIN[0]
    y0, y1 = min(ns) * 1000 - ORIGIN[1], (max(ns) + 1) * 1000 - ORIGIN[1]
    return x0, y0, x1, y1


def plan(path, line, seconds, fps, z, seg):
    x0, y0, x1, y1 = line
    ln = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / ln, (y1 - y0) / ln
    a, b = EDGE, ln - EDGE
    n = int(seconds * fps)
    frames = []
    for i in range(n):
        d = a + (b - a) * i / (n - 1)
        x, y = x0 + ux * d, y0 + uy * d
        frames.append({"id": "f%05d" % i, "seg": i // seg, "pos": [round(x, 2), round(y, 2)], "z": z, "f35": 24,
                       "size": [1280, 720], "target": [round(x + ux * LOOK_AHEAD, 2), round(y + uy * LOOK_AHEAD, 2), 0],
                       "at": [0.5, 0.5], "clip": 5})
    json.dump(frames, open(path, "w"), indent=0)
    print("%d frames in %d segments, %.1f km at %.0f m/s" % (n, frames[-1]["seg"] + 1, (b - a) / 1000, (b - a) / seconds))


def render(path, out, tiles_dir, seg, width, step=1):
    sys.path.insert(0, os.path.join(ROOT, "tools", "blender", "spire"))
    import bpy
    import render_pairs as RP
    frames = [f for f in json.load(open(path)) if f["seg"] == seg]
    todo = [f["id"] for f in frames if int(f["id"][1:]) % step == 0 and not os.path.exists(os.path.join(out, f["id"] + ".png"))]
    if not todo:
        print("segment %d: nothing to do" % seg)
        return
    tmp = os.path.join(out, "seg%03d.json" % seg)
    os.makedirs(out, exist_ok=True)
    json.dump(frames, open(tmp, "w"))               # every frame of the segment picks the tiles, so a resumed job loads the same ones
    setup = RP.RC.setup_cycles

    def setup_keep(samples):
        setup(samples)
        bpy.context.scene.render.use_persistent_data = True     # the scene stays in Cycles between frames

    RP.RC.setup_cycles = setup_keep
    shoot = RP.shoot
    RP.shoot = lambda p, o, w: shoot(p, o, w) if p["id"] in todo else {"id": p["id"]}
    sys.argv = [sys.argv[0], tmp, out, "width=%d" % width, "tiles=" + tiles_dir]
    RP.main()


if __name__ == "__main__":
    a = sys.argv[1:]
    opt = {k: v for k, v in (x.split("=", 1) for x in a if "=" in x)}
    pos = [x for x in a if "=" not in x]
    if pos and pos[0] == "plan":
        line = [float(v) for v in pos[2].split(",")] if len(pos) > 2 else longest_line()
        plan(pos[1], line, float(opt.get("seconds", 60)), int(opt.get("fps", 24)), float(opt.get("z", 380)), int(opt.get("seg", 120)))
    elif pos and pos[0] == "render":
        render(pos[1], os.path.abspath(pos[2]), os.path.abspath(pos[3]), int(opt["seg"]), int(opt.get("width", 1280)), int(opt.get("step", 1)))
    else:
        print(__doc__)

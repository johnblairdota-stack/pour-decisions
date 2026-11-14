"""Build the whole Spire scene into the open Blender file: the finished tower, or a construction stage.

    blender -b --factory-startup -P tools/blender/spire/build_all.py [-- --stage 2016_l6] [--save out.blend]

Each module's build() returns metadata; it goes to docs/spire/blockout_meta[_<stage>].json.
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402

import layout as L  # noqa: E402
import ground, streets, buildings, spire, core, landmarks, logistics, site_plant  # noqa: E402,E401

MODULES = [ground, streets, buildings, spire, core, landmarks, logistics, site_plant]


def clear():
    for ob in list(bpy.data.objects):
        if ob.type == "CAMERA":
            continue
        bpy.data.objects.remove(ob, do_unlink=True)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


def build_all(stage=None, write_meta=True):
    clear()
    L.ACTIVE_STAGE = L.STAGES[stage] if stage else None
    meta = {"stage": stage or "finished",
            "frame": {"origin_mga56": L.ORIGIN_MGA56, "origin_latlon": L.ORIGIN_LATLON,
                      "axes": "x east, y north, z metres AHD", "model_half_m": L.MODEL_HALF}, "modules": []}
    for m in MODULES:
        t = time.time()
        r = m.build()
        r["seconds"] = round(time.time() - t, 2)
        meta["modules"].append(r)
        print("built %-10s %5.1fs  %s" % (r["module"], r["seconds"], ", ".join(r.get("objects", []))))
    if write_meta:
        os.makedirs(L.DOCS, exist_ok=True)
        name = "blockout_meta.json" if not stage else "blockout_meta_%s.json" % stage
        json.dump(meta, open(os.path.join(L.DOCS, name), "w"), indent=1)
    return meta


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build_all(argv[argv.index("--stage") + 1] if "--stage" in argv else None)
    if "--save" in argv:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(argv[argv.index("--save") + 1]))

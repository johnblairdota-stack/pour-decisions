"""Build the whole Spire blockout into the open Blender scene.

    blender -b --factory-startup -P tools/blender/spire/build_all.py [-- --save out.blend]

Each module's build() returns metadata; all of it goes to docs/spire/blockout_meta.json.
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402

import layout as L  # noqa: E402
import ground, streets, buildings, spire, landmarks, logistics  # noqa: E402,E401

MODULES = [ground, streets, buildings, spire, landmarks, logistics]


def clear():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


def build_all(write_meta=True):
    clear()
    meta = {"frame": {"origin_mga56": L.ORIGIN_MGA56, "origin_latlon": L.ORIGIN_LATLON,
                      "axes": "x east, y north, z metres AHD", "model_half_m": L.MODEL_HALF}, "modules": []}
    for m in MODULES:
        t = time.time()
        r = m.build()
        r["seconds"] = round(time.time() - t, 2)
        meta["modules"].append(r)
        print("built %-10s %5.1fs  %s" % (r["module"], r["seconds"], ", ".join(r.get("objects", []))))
    if write_meta:
        os.makedirs(L.DOCS, exist_ok=True)
        json.dump(meta, open(os.path.join(L.DOCS, "blockout_meta.json"), "w"), indent=1)
    return meta


if __name__ == "__main__":
    build_all()
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--save" in argv:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(argv[argv.index("--save") + 1]))

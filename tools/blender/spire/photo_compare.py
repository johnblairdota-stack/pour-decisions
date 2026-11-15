"""Side-by-side and 50 % overlay of each photo and its render (step 7b). Output goes OUTSIDE git:
PourDecisions-sites/compare/spire/ (John's photos never go in the repo, not even as crops).

    blender -b --factory-startup -P tools/blender/spire/photo_compare.py -- <my_photos/spire> <compare dir> [suffix]
"""
import json
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import layout as L  # noqa: E402


def load(path):
    im = bpy.data.images.load(path)
    w, h = im.size
    a = np.empty(w * h * 4, "f4")
    im.pixels.foreach_get(a)
    bpy.data.images.remove(im)
    return a.reshape(h, w, 4)[:, :, :3]


def resize(a, w, h):
    H, W = a.shape[:2]
    r = (np.arange(h) * H / h).astype(int)
    c = (np.arange(w) * W / w).astype(int)
    return a[r][:, c]


def save(a, path):
    h, w = a.shape[:2]
    im = bpy.data.images.new("o", w, h)
    rgba = np.ones((h, w, 4), "f4")
    rgba[:, :, :3] = a
    im.pixels.foreach_set(rgba.ravel())
    im.filepath_raw = path
    im.file_format = "JPEG"
    im.save()
    bpy.data.images.remove(im)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    photos, out = argv[0], argv[1]
    suffix = argv[2] if len(argv) > 2 else ""
    os.makedirs(out, exist_ok=True)
    cams = json.load(open(os.path.join(L.HERE, "photo_cams.json")))["cams"]
    for c in cams:
        if c.get("skip"):
            continue
        rp = os.path.join(L.DOCS, "photo_cams", "%s_render.png" % c["id"])
        pp = os.path.join(photos, c["file"])
        if not (os.path.exists(rp) and os.path.exists(pp)):
            continue
        ren = load(rp)
        h, w = ren.shape[:2]
        ph = resize(load(pp), w, h)            # bpy images are bottom-up; both are, so they line up
        side = np.concatenate([ph, np.ones((h, 8, 3), "f4"), ren], 1)
        save(side, os.path.join(out, "%s_side%s.jpg" % (c["id"], suffix)))
        save(0.5 * ph + 0.5 * ren, os.path.join(out, "%s_overlay%s.jpg" % (c["id"], suffix)))
        print("compare", c["id"])


if __name__ == "__main__":
    main()

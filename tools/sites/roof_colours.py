"""Roof colour of every city_wide building, read off the 2022 aerial (no bpy).

    python3 tools/sites/roof_colours.py

Reads reference/sites/spire/wide/buildings_wide.json and reference/sites/spire/river/aerial_wide.jpg
(2 m, river_shape.py). Writes reference/sites/spire/wide/roof_colours.json: {osm: [r, g, b] sRGB 0-255},
the median aerial pixel inside the top roof tier. Buildings outside the aerial (black) are left out.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "blender", "spire"))
import layout as L  # noqa: E402

Image.MAX_IMAGE_PIXELS = None


def main():
    rv = json.load(open(os.path.join(L.REF, "river", "river.json")))
    x0, y0, x1, y1 = rv["box_local"]
    st = rv["step_m"]
    im = np.asarray(Image.open(os.path.join(L.REF, "river", "aerial_wide.jpg")).convert("RGB"))
    sx, sy = im.shape[1] / ((x1 - x0) / st), im.shape[0] / ((y1 - y0) / st)
    recs = json.load(open(os.path.join(L.REF, "wide", "buildings_wide.json")))["buildings"]
    out = {}
    for b in recs:
        ring = b["tiers"][0]["ring"]
        px = [((x - x0) / st * sx, (y1 - y) / st * sy) for x, y in ring]
        c0, r0 = int(min(p[0] for p in px)), int(min(p[1] for p in px))
        c1, r1 = int(max(p[0] for p in px)) + 2, int(max(p[1] for p in px)) + 2
        if c0 < 0 or r0 < 0 or c1 > im.shape[1] or r1 > im.shape[0]:
            continue
        m = Image.new("1", (c1 - c0, r1 - r0), 0)
        ImageDraw.Draw(m).polygon([(p[0] - c0, p[1] - r0) for p in px], fill=1)
        sel = im[r0:r1, c0:c1][np.asarray(m, bool)]
        if len(sel) < 3:
            sel = im[r0:r1, c0:c1].reshape(-1, 3)
        med = np.median(sel, 0)
        if med.sum() < 24:                                  # no aerial here
            continue
        out[str(b["osm"])] = [int(v) for v in med]
    json.dump({"note": "median 2022 aerial pixel inside each footprint, sRGB 0-255. tools/sites/roof_colours.py",
               "credit": rv.get("credit", ""), "roofs": out},
              open(os.path.join(L.REF, "wide", "roof_colours.json"), "w"), separators=(",", ":"))
    print(len(out), "of", len(recs), "roofs")


if __name__ == "__main__":
    main()

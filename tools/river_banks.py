#!/usr/bin/env python3
"""The river's banks and a wet/dry mask, for setting the river down below
the land (scripts/surrounds.gd RIVER_Y): the real riverwalk and the estate
stand 3 to 4 m above mean river level (reference/elevation, 2019 LiDAR
ground), the site itself about 5 m.

Reads the wet ground of data/riverlight_osm.json (river and drains, already
cut round the paths and bridges over them) and the far river of
data/riverlight_skyline.json, and writes:

  data/river_banks.json   {"banks": [[x0, z0, x1, z1, ...], ...]}  every
                          edge between water and land, for the bank walls,
                          each run with the water on its left
  data/river_mask.png     wet = white, 4096 x 6144: the top 4096 rows are
                          +-2048 m at 1 m a pixel, the bottom 2048 rows
                          +-8192 m (4 m a pixel across, 8 m down); image
                          right = -x, up = +z. The base grass plane leaves
                          a hole where it's wet

    python3 tools/river_banks.py      (needs shapely and Pillow)
"""
import json
import os

from PIL import Image, ImageDraw
from shapely.geometry import Polygon
from shapely.geometry.polygon import orient
from shapely.ops import unary_union

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NEAR, FAR = 2048.0, 8192.0      # half-widths of the two masks, m
SIZE = 4096


def wet():
	d = json.load(open(os.path.join(ROOT, "data", "riverlight_osm.json")))
	s = json.load(open(os.path.join(ROOT, "data", "riverlight_skyline.json")))
	polys = []
	for g in d["ground"]:
		if g["kind"] not in ("water", "drain"):
			continue
		t = g["tris"]
		for i in range(0, len(t) - 5, 6):
			p = Polygon([(t[i], t[i + 1]), (t[i + 2], t[i + 3]), (t[i + 4], t[i + 5])])
			if p.area > 0.01:
				polys.append(p)
	for w in s["water"]:
		polys.append(Polygon(w).buffer(0))
	# (closing up the seams between the pieces, so no wall runs across the water)
	return unary_union([p.buffer(0.6, join_style=2) for p in polys]).buffer(-0.6, join_style=2)


def rings(g):
	"""Every bank, run so the water's on its left (x right, z up)."""
	for p in getattr(g, "geoms", [g]):
		if p.area < 4.0:
			continue
		p = orient(p, 1.0)
		yield p.exterior
		yield from p.interiors


def mask(g, half, size):
	im = Image.new("L", (size, size), 0)
	dr = ImageDraw.Draw(im)
	k = size / (2 * half)
	to = lambda x, z: ((half - x) * k, (half - z) * k)    # (image right = -x, up = +z, as seen from above)
	for p in getattr(g, "geoms", [g]):
		dr.polygon([to(*c) for c in p.exterior.coords], fill=255)
		for r in p.interiors:
			dr.polygon([to(*c) for c in r.coords], fill=0)
	return im


def main():
	g = wet()
	banks = []
	for r in rings(g):
		pts = list(r.simplify(0.3).coords)
		if max(max(abs(x), abs(z)) for x, z in pts) > FAR:
			continue
		banks.append([round(v, 1) for x, z in pts for v in (x, z)])
	with open(os.path.join(ROOT, "data", "river_banks.json"), "w") as f:
		json.dump({"source": "data/riverlight_osm.json + riverlight_skyline.json (tools/river_banks.py)", "banks": banks},
			f, separators=(",", ":"))
	near = mask(g, NEAR, SIZE)
	far = mask(g, FAR, SIZE).resize((SIZE, SIZE // 2), Image.NEAREST)
	out = Image.new("L", (SIZE, SIZE + SIZE // 2), 0)
	out.paste(near, (0, 0))
	out.paste(far, (0, SIZE))
	out.save(os.path.join(ROOT, "data", "river_mask.png"), optimize=True)
	print(len(banks), "bank rings,", sum(len(b) // 2 for b in banks), "points")


if __name__ == "__main__":
	main()

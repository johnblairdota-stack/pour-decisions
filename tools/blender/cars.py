"""The traffic round Riverlight (assets/cars/cars.glb): what drives and parks
round Northshore on a weekday morning in 2017.

Run:  python tools/blender/cars.py

  Sedan, Hatch, SUV   the usual
  Ute                 a dual-cab ute with a tub, tradie racks
  Van                 a high-roof delivery van
  Bus                 a city bus (12.5 m)
  ...Far              a box and a cabin, a dozen triangles, for the car
                      yard's thousand cars and anything far off

Each model's origin is on the road under its middle, front towards +z. The
body is painted white ("body") so the game gives each car its own colour.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import Piece, box, build, cylinder, export_glb, reset, tri_count  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "cars", "cars.glb")

PALETTE = {
	"body": "ffffff", "glass": "2c3a46", "tyre": "222222", "rim": "a9b0b5", "light": "fff4d0", "tail": "c8282a",
	"trim": "2a2d31", "plate": "f4f4f2", "rack": "8d9196", "bus_band": "f2c14e",
}


def put(name, pieces):
	return build(name, pieces, PALETTE, None, smooth=False)


def profile_body(length, width, sill, belt, roof, nose, tail, hood, boot, glass_in=0.12, mat="body"):
	"""A car body from the side: a lower box from sill to belt line with the
	nose and tail sloped, and a cabin above it set in by `glass_in` each
	side. hood/boot: how far the cabin starts from the front/back."""
	p = []
	L, W = length / 2, width / 2
	# lower body as an extruded side profile [(z, y)]
	low = [(-L, sill), (L, sill), (L, belt - nose), (L - 0.25, belt), (-L + 0.2, belt), (-L, belt - tail)]
	p.append(side_extrude(low, -W, W, mat))
	# cabin: glass box with a roof slab, sloped screens
	zf, zb = L - hood, -L + boot
	cab = [(zb, belt), (zf, belt), (zf - 0.45, roof - 0.04), (zb + 0.25, roof - 0.04)]
	p.append(side_extrude(cab, -W + glass_in, W - glass_in, "glass"))
	p.append(side_extrude([(zb + 0.22, roof - 0.06), (zf - 0.43, roof - 0.06), (zf - 0.5, roof), (zb + 0.27, roof)],
		-W + glass_in - 0.01, W - glass_in + 0.01, mat))
	# pillars between the windows (B pillar)
	zm = (zf + zb) / 2 - 0.1
	p.append(box(width - glass_in * 2 + 0.03, roof - belt - 0.05, 0.12, mat, at=(0, (roof + belt) / 2, zm)))
	return p


def side_extrude(poly, x0, x1, mat):
	"""A side profile [(z, y)] run across the car from x0 to x1."""
	p = Piece(mat)
	bm = p.bm
	a = [bm.verts.new((x0, y, z)) for z, y in poly]
	b = [bm.verts.new((x1, y, z)) for z, y in poly]
	n = len(poly)
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((a[i], a[j], b[j], b[i]))
	bm.faces.new(list(reversed(a)))
	bm.faces.new(b)
	return p


def wheels(track, base, r=0.32, w=0.22):
	out = []
	for z in (base / 2, -base / 2):
		for s in (-1, 1):
			out.append(cylinder(r, w, "tyre", 10).rot("z", math.pi / 2).move(s * (track / 2 + w / 2), r, z))
			out.append(cylinder(r * 0.6, 0.02, "rim", 8).rot("z", math.pi / 2).move(s * (track / 2 + w + 0.01), r, z))
	return out


def lamps(length, width, y, rear_y=None):
	L, W = length / 2, width / 2
	ry = rear_y if rear_y is not None else y
	out = []
	for s in (-1, 1):
		out.append(box(0.32, 0.12, 0.04, "light", at=(s * (W - 0.25), y, L + 0.01)))
		out.append(box(0.28, 0.12, 0.04, "tail", at=(s * (W - 0.22), ry, -L - 0.01)))
	out.append(box(0.5, 0.12, 0.03, "plate", at=(0, y - 0.15, L + 0.01)))
	out.append(box(0.5, 0.12, 0.03, "plate", at=(0, ry - 0.12, -L - 0.01)))
	return out


def sedan():
	p = profile_body(4.7, 1.8, 0.3, 0.95, 1.45, 0.25, 0.12, 1.55, 1.05)
	p += wheels(1.45, 2.75) + lamps(4.7, 1.8, 0.75, 0.82)
	put("Sedan", p)


def hatch():
	p = profile_body(4.1, 1.75, 0.3, 0.95, 1.48, 0.25, 0.05, 1.2, 0.2)
	p += wheels(1.42, 2.55, 0.3) + lamps(4.1, 1.75, 0.75, 0.85)
	put("Hatch", p)


def suv():
	p = profile_body(4.7, 1.9, 0.4, 1.12, 1.75, 0.2, 0.05, 1.3, 0.2)
	p += wheels(1.55, 2.8, 0.36, 0.25) + lamps(4.7, 1.9, 0.9, 1.0)
	put("SUV", p)


def ute():
	"""Dual cab, tub out the back, a ladder rack over it."""
	L, W = 5.3 / 2, 1.85 / 2
	p = [side_extrude([(-L, 0.45), (L, 0.45), (L, 0.95), (L - 0.3, 1.15), (L - 1.2, 1.15), (L - 1.2, 1.0),
		(-L, 1.0)], -W, W, "body")]
	cab = [(-0.75, 1.1), (L - 1.2, 1.1), (L - 1.75, 1.82), (-0.65, 1.82)]
	p.append(side_extrude(cab, -W + 0.1, W - 0.1, "glass"))
	p.append(side_extrude([(-0.7, 1.78), (L - 1.7, 1.78), (L - 1.75, 1.86), (-0.65, 1.86)], -W + 0.08, W - 0.08, "body"))
	p.append(box(1.7, 0.7, 0.1, "body", at=(0, 1.45, -0.72)))           # cab back wall
	p.append(box(1.75, 0.05, 1.8, "trim", at=(0, 1.0, -L + 0.95)))      # tub floor
	for x in (-0.85, 0.85):
		p.append(box(0.04, 1.0, 0.04, "rack", at=(x, 1.5, -L + 0.2)))
		p.append(box(0.04, 1.0, 0.04, "rack", at=(x, 1.5, -0.85)))
		p.append(box(0.04, 0.04, 1.9, "rack", at=(x, 2.0, -L + 1.05)))
	p.append(box(1.75, 0.04, 0.04, "rack", at=(0, 2.0, -L + 0.2)))
	p.append(box(1.75, 0.04, 0.04, "rack", at=(0, 2.0, -0.85)))
	p.append(box(1.9, 0.12, 0.12, "trim", at=(0, 0.55, -L - 0.05)))    # tow bar and bumper
	p += wheels(1.55, 3.1, 0.38, 0.26) + lamps(5.3, 1.85, 0.85, 0.9)
	put("Ute", p)


def van():
	L, W = 5.3 / 2, 1.9 / 2
	p = [side_extrude([(-L, 0.4), (L, 0.4), (L, 1.0), (L - 0.4, 1.25), (L - 1.0, 2.25), (-L, 2.25)], -W, W, "body")]
	p.append(side_extrude([(L - 0.42, 1.25), (L - 0.98, 2.15), (L - 1.6, 2.15), (L - 1.6, 1.25)], -W - 0.01, W + 0.01, "glass"))
	p.append(box(0.04, 1.6, 1.0, "trim", at=(W + 0.01, 1.3, -0.3)))    # sliding door line
	p += wheels(1.6, 3.2, 0.34, 0.24) + lamps(5.3, 1.9, 0.85, 1.0)
	put("Van", p)


def bus():
	L, W = 12.5 / 2, 2.5 / 2
	p = [side_extrude([(-L, 0.35), (L, 0.35), (L, 3.0), (L - 0.15, 3.1), (-L, 3.1)], -W, W, "body")]
	p.append(side_extrude([(-L + 0.6, 1.25), (L - 0.05, 1.25), (L - 0.05, 2.75), (-L + 0.6, 2.75)], -W - 0.01, W + 0.01, "glass"))
	p.append(side_extrude([(-L, 0.75), (L, 0.75), (L, 1.0), (-L, 1.0)], -W - 0.02, W + 0.02, "bus_band"))
	p.append(box(2.0, 0.35, 1.6, "trim", at=(0, 3.25, -L + 1.5)))      # roof air con pod
	for z in (L - 2.2, -L + 2.6):
		for s in (-1, 1):
			p.append(cylinder(0.5, 0.3, "tyre", 12).rot("z", math.pi / 2).move(s * (W - 0.1), 0.5, z))
	p += lamps(12.5, 2.5, 0.75, 0.9)
	put("Bus", p)


def far(name, length, width, belt, roof, cab_len, cab_off=0.0):
	"""A box body and a smaller cabin box: 24 triangles."""
	put(name + "Far", [box(width, belt - 0.25, length, "body", at=(0, (belt + 0.25) / 2, 0)),
		box(width - 0.15, roof - belt, cab_len, "glass", at=(0, (roof + belt) / 2, cab_off))])


def main():
	reset()
	sedan()
	hatch()
	suv()
	ute()
	van()
	bus()
	far("Sedan", 4.7, 1.8, 0.95, 1.45, 2.1, -0.2)
	far("SUV", 4.7, 1.9, 1.12, 1.75, 2.6, -0.4)
	far("Ute", 5.3, 1.85, 1.0, 1.85, 1.8, 0.3)
	import bpy
	tot = 0
	for o in bpy.context.scene.objects:
		if o.type == "MESH":
			t = tri_count([o])
			tot += t
			print("  %-10s %5d triangles" % (o.name, t))
	print("  total %d" % tot)
	export_glb(OUT)
	print("wrote", OUT)


if __name__ == "__main__":
	main()

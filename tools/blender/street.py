"""The street round Riverlight (assets/street/street.glb): what Brisbane City
Council puts along a new Northshore street and riverside park. Street lights
on outreach arms, the riverwalk's post-top lights, a bus shelter and stop
sign, park benches, bins, a bubbler, an electric BBQ shelter with its picnic
tables, street name blades and give way signs, timber bollards, a bike hoop
and the riverwalk's railing.

Run:  python tools/blender/street.py

Each part is a top-level mesh with its origin on the ground at its foot, its
front (the side people use, or the road side) towards +z; the game places
them as multimeshes (scripts/street.gd).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import box, build, cylinder, export_glb, extrude, lathe, reset, sphere, tri_count, tube  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "street", "street.glb")

PALETTE = {
	"galv": "a9b0b5", "galv_dark": "7d858b", "lamp_head": "5a6168", "lamp_glow": "fff4d0",
	"steel_black": "2e3236", "timber": "b98a55", "timber_dark": "8e6a44", "concrete": "c4c2bb",
	"glass": "9cc3d6", "shelter_roof": "e8e6df", "sign_blue": "1f4f9a", "sign_white": "f4f7fa",
	"sign_red": "d9302c", "sign_yellow": "ffc72c", "bin_green": "2f5f3f", "bin_lid": "24442f",
	"stainless": "d2d6d8", "bbq_roof": "3d6f73", "seat": "2f6fd1",
}


def put(name, pieces, smooth=False):
	return build(name, pieces, PALETTE, None, smooth=smooth)


def post(r, h, mat, at=(0, 0, 0), segs=8):
	return cylinder(r, h, mat, segs=segs, at=at)


# ---------------------------------------------------------------- lights

def street_light():
	"""A 9 m galvanised pole on a concrete footing, a 2 m outreach arm and a
	flat LED head over the road (+z)."""
	p = [cylinder(0.32, 0.25, "concrete", segs=10),
		lathe([(0.11, 0.25), (0.09, 4.0), (0.065, 8.6)], 8, "galv")]
	p.append(tube([(0, 8.4, 0), (0, 8.85, 0.35), (0, 9.0, 1.1), (0, 9.0, 2.0)], 0.045, "galv", 6))
	p.append(box(0.32, 0.1, 0.62, "lamp_head", bevel=0.03, at=(0, 8.98, 2.15)))
	p.append(box(0.24, 0.02, 0.48, "lamp_glow", at=(0, 8.92, 2.15)))
	p.append(box(0.2, 0.32, 0.12, "galv_dark", bevel=0.02, at=(0, 1.1, 0.12)))   # the base hatch
	put("StreetLight", p, smooth=True)


def park_light():
	"""The riverwalk's 4.5 m post-top light: black pole, round lantern."""
	p = [cylinder(0.22, 0.12, "concrete", segs=8),
		lathe([(0.075, 0.12), (0.06, 4.1)], 8, "steel_black"),
		lathe([(0.0, 4.1), (0.17, 4.12), (0.2, 4.35), (0.17, 4.55), (0.0, 4.6)], 10, "lamp_glow"),
		lathe([(0.0, 4.58), (0.24, 4.6), (0.0, 4.72)], 10, "steel_black")]
	put("ParkLight", p, smooth=True)


# ---------------------------------------------------------------- the bus stop

def bus_shelter():
	"""A council bus shelter: steel posts, glass back and ends, a curved
	white roof and a bench, open to the kerb (+z). 3.6 m long."""
	L, D, H = 3.6, 1.5, 2.45
	p = [box(L + 0.4, 0.08, D + 0.4, "concrete", at=(0, 0.04, 0))]
	for x in (-L / 2, L / 2):
		for z in (-D / 2, D / 2 - 0.15):
			p.append(box(0.08, H, 0.08, "steel_black", at=(x, H / 2, z)))
	p.append(box(L, 1.9, 0.03, "glass", at=(0, 1.15, -D / 2)))
	for x in (-L / 2, L / 2):
		p.append(box(0.03, 1.9, D * 0.7, "glass", at=(x, 1.15, -D / 2 + D * 0.35)))
	# The roof, a shallow arc front to back
	arc = []
	for k in range(7):
		t = k / 6
		z = -D / 2 - 0.15 + (D + 0.4) * t
		arc.append((z, H + 0.18 * math.sin(math.pi * t)))
	top = [(z, y + 0.05) for z, y in arc]
	poly = arc + list(reversed(top))
	p.append(extrude(poly, -L / 2 - 0.15, L / 2 + 0.15, "shelter_roof"))
	p.append(box(L * 0.8, 0.06, 0.38, "timber", at=(0, 0.48, -D / 2 + 0.3)))
	p.append(box(L * 0.8, 0.06, 0.06, "steel_black", at=(0, 0.42, -D / 2 + 0.12)))
	p.append(box(0.05, 0.6, 0.6, "sign_blue", at=(L / 2 + 0.05, 1.7, 0.1)))
	put("BusShelter", p)


def bus_stop_sign():
	"""The stop's pole and flag (blue and yellow, a bus in white)."""
	p = [post(0.04, 2.9, "galv"),
		box(0.48, 0.6, 0.04, "sign_yellow", at=(0, 2.55, 0.05)),
		box(0.42, 0.34, 0.045, "sign_blue", at=(0, 2.62, 0.05)),
		box(0.26, 0.12, 0.05, "sign_white", at=(0, 2.62, 0.05))]
	put("BusStopSign", p)


# ---------------------------------------------------------------- the park

def bench():
	"""A park bench: timber slats on black steel frames, facing +z."""
	p = []
	for x in (-0.75, 0.75):
		p.append(box(0.06, 0.45, 0.5, "steel_black", at=(x, 0.225, 0)))
		p.append(box(0.06, 0.5, 0.06, "steel_black", at=(x, 0.7, -0.24)))
		p.append(box(0.06, 0.05, 0.42, "steel_black", at=(x, 0.65, 0.02)))
	for i in range(4):
		p.append(box(1.8, 0.04, 0.1, "timber", bevel=0.01, at=(0, 0.46, -0.18 + i * 0.12)))
	for i in range(2):
		p.append(box(1.8, 0.1, 0.035, "timber", bevel=0.01, at=(0, 0.66 + i * 0.16, -0.25)))
	put("ParkBench", p)


def park_bin():
	"""A 240 L bin in the council's slatted steel surround."""
	p = [box(0.7, 1.0, 0.7, "bin_green", bevel=0.04, at=(0, 0.5, 0)),
		box(0.74, 0.06, 0.74, "bin_lid", bevel=0.02, at=(0, 1.02, 0)),
		box(0.3, 0.02, 0.05, "steel_black", at=(0, 1.05, 0.2))]
	for i in range(5):
		p.append(box(0.72, 0.06, 0.72, "steel_black", at=(0, 0.15 + i * 0.2, 0)))
	put("ParkBin", p)


def bubbler():
	"""A stainless drinking fountain on a post, with a dog bowl at its foot."""
	p = [cylinder(0.25, 0.08, "concrete", segs=10),
		lathe([(0.09, 0.08), (0.08, 0.9)], 10, "stainless"),
		lathe([(0.0, 0.9), (0.2, 0.92), (0.22, 1.0), (0.18, 1.0), (0.0, 0.96)], 12, "stainless"),
		tube([(0, 0.95, 0.05), (0, 1.07, 0.08), (0, 1.06, 0.13)], 0.015, "stainless", 5),
		lathe([(0.0, 0.08), (0.14, 0.08), (0.16, 0.16), (0.12, 0.16), (0.0, 0.12)], 10, "stainless").move(0, 0, 0.32)]
	put("Bubbler", p, smooth=True)


def picnic_table(name="PicnicTable", with_base=True):
	p = []
	if with_base:
		p.append(box(2.6, 0.08, 2.4, "concrete", at=(0, 0.04, 0)))
	p.append(box(1.9, 0.05, 0.8, "timber", bevel=0.01, at=(0, 0.75, 0)))
	for z in (-0.65, 0.65):
		p.append(box(1.9, 0.05, 0.28, "timber", bevel=0.01, at=(0, 0.45, z)))
	for x in (-0.7, 0.7):
		for s in (-1, 1):
			p.append(box(0.06, 0.06, 1.6, "steel_black", at=(x, 0.4, 0)))
			p.append(tube([(x, 0.0, 0.55 * s), (x, 0.74, 0.12 * s)], 0.03, "steel_black", 5))
	return put(name, p)


def bbq_shelter():
	"""The park's electric BBQ under a hipped roof on four posts, a picnic
	table each side. 5 x 4 m."""
	p = [box(6.4, 0.1, 5.2, "concrete", at=(0, 0.05, 0))]
	for x in (-2.3, 2.3):
		for z in (-1.8, 1.8):
			p.append(box(0.14, 2.6, 0.14, "steel_black", at=(x, 1.35, z)))
	# Hipped roof: a squashed pyramid
	roof = lathe([(3.6, 2.65), (3.6, 2.75), (0.6, 3.55), (0.0, 3.6)], 4, "bbq_roof")
	roof.rot("y", math.pi / 4).scale(1.0, 1.0, 0.8)
	p.append(roof)
	p.append(box(5.2, 0.14, 4.2, "galv_dark", at=(0, 2.62, 0)))
	# The BBQ: a stainless box with two hotplates, on a block plinth
	p.append(box(1.4, 0.85, 0.7, "concrete", bevel=0.03, at=(0, 0.47, 0)))
	p.append(box(1.5, 0.08, 0.8, "stainless", bevel=0.02, at=(0, 0.94, 0)))
	for x in (-0.36, 0.36):
		p.append(box(0.6, 0.02, 0.5, "steel_black", at=(x, 0.99, 0)))
	put("BBQShelter", p)


# ---------------------------------------------------------------- signs and bits

def street_sign():
	"""A street name blade (blue, white border) on a galvanised post; the game
	letters the name on (+z face) in Label3D."""
	p = [post(0.035, 2.75, "galv"),
		box(1.1, 0.2, 0.03, "sign_white", at=(0.5, 2.6, 0)),
		box(1.06, 0.16, 0.035, "sign_blue", at=(0.5, 2.6, 0))]
	put("StreetSign", p)


def give_way_sign():
	"""Give way: the red-bordered white triangle, point down."""
	p = [post(0.035, 2.3, "galv")]
	tri = [(0.0, -0.33), (0.38, 0.33), (-0.38, 0.33)]
	inner = [(0.0, -0.2), (0.25, 0.24), (-0.25, 0.24)]
	for pts, mat, t in ((tri, "sign_red", 0.02), (inner, "sign_white", 0.03)):
		# a flat prism: (x, y) outline pushed out along z
		poly = [(y, x) for x, y in pts]
		pc = extrude([(z, y) for y, z in poly], -t, t, mat)
		pc.rot("y", math.pi / 2)
		pc.move(0, 2.1, 0.03)
		p.append(pc)
	put("GiveWaySign", p)


def timber_bollard():
	p = [box(0.15, 0.9, 0.15, "timber", bevel=0.015, at=(0, 0.45, 0)),
		box(0.16, 0.05, 0.16, "timber_dark", at=(0, 0.75, 0))]
	put("TimberBollard", p)


def bike_hoop():
	pts = [(-0.35, 0, 0)] + [(math.sin(a) * -0.35, 0.55 + math.cos(a) * 0.3 * 0, 0) for a in ()] + []
	arc = []
	for k in range(9):
		a = math.pi * k / 8
		arc.append((-0.35 * math.cos(a), 0.55 + 0.25 * math.sin(a), 0))
	pts = [(-0.35, 0, 0)] + arc + [(0.35, 0, 0)]
	put("BikeHoop", [tube(pts, 0.03, "galv", 6, cap=False)], smooth=True)


RAIL = 3.0


def riverwalk_rail():
	"""A 3 m bay of the riverwalk's balustrade: posts, a timber handrail,
	steel mid rails. Runs along x."""
	p = []
	for x in (-RAIL / 2, RAIL / 2):
		p.append(box(0.08, 1.05, 0.08, "steel_black", at=(x, 0.525, 0)))
	p.append(box(RAIL + 0.1, 0.06, 0.14, "timber", bevel=0.015, at=(0, 1.08, 0)))
	for y in (0.3, 0.55, 0.8):
		p.append(box(RAIL, 0.025, 0.025, "galv", at=(0, y, 0)))
	put("RiverwalkRail", p)


def main():
	reset()
	street_light()
	park_light()
	bus_shelter()
	bus_stop_sign()
	bench()
	park_bin()
	bubbler()
	picnic_table()
	bbq_shelter()
	street_sign()
	give_way_sign()
	timber_bollard()
	bike_hoop()
	riverwalk_rail()
	import bpy
	tot = 0
	for o in bpy.context.scene.objects:
		if o.type == "MESH":
			t = tri_count([o])
			tot += t
			print("  %-18s %5d triangles" % (o.name, t))
	print("  total %d" % tot)
	export_glb(OUT)
	print("wrote", OUT)


if __name__ == "__main__":
	main()

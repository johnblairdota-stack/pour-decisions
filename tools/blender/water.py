"""The river at Hamilton Reach (assets/water/water.glb): what floats on the
Brisbane River off Northshore. A tinny, a moored yacht and a cruiser on their
swing moorings, a rowing eight out at dawn, the channel piles (green to
starboard, red to port coming upstream), a mooring buoy, a floating pontoon
and its gangway, rocks for the bank's revetment, and the cruise ship that
ties up at Portside Wharf.

Run:  python tools/blender/water.py

Each part is a top-level mesh with its origin at the waterline (y 0) at its
middle, bow towards +x; the game places them (scripts/water.gd).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import bmesh, Piece, box, build, cylinder, export_glb, extrude, lathe, reset, sphere, tri_count, tube  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "water", "water.glb")

PALETTE = {
	"hull_white": "f2f2ee", "hull_navy": "1f3550", "alloy": "b8c0c6", "alloy_dark": "8a949b",
	"antifoul": "a8423a", "deck": "d9c9a6", "glass": "3a5068", "mast": "d8dcdf", "sail": "e9e4d6",
	"sail_cover": "2c5f8a", "motor": "2b2d30", "seat": "e8e2d0", "shell": "f4f1e8", "oar": "e9e1c8",
	"blade": "c8302c", "rower": "2f6fd1", "skin": "d9a07a", "pile": "6b5a48", "green": "2f8a4a",
	"red": "d0342c", "buoy": "f4f7fa", "pontoon": "c4c2bb", "float": "2b2d30", "rail": "a9b0b5",
	"rock": "8a8478", "rock_dark": "6e695f", "funnel": "1f4f9a", "funnel_top": "2b2b2b",
	"lifeboat": "ff7a1a", "balcony": "dfe3e6", "window": "34495e", "pool": "4fa3c7",
}


def put(name, pieces, smooth=False):
	return build(name, pieces, PALETTE, None, smooth=smooth)


def hull(length, beam, depth, mat, top_mat=None, segs=10, rake=0.35, flat=0.5):
	"""A boat hull along x from -L/2 (stern) to +L/2 (bow): sections that
	narrow to a point at the bow, a transom at the stern; waterline at y 0,
	keel at -depth*0.4, sheer at depth*0.6."""
	p = Piece(mat)
	bm = p.bm
	rows = []
	for i in range(segs + 1):
		t = i / segs
		x = -length / 2 + length * t
		# half-beam: full aft, tapering to 0 at the bow
		hb = beam / 2 * (1.0 if t < 0.55 else math.cos((t - 0.55) / 0.45 * math.pi / 2) ** 0.8)
		hb = max(hb, 0.001)
		top = depth * 0.6 + rake * max(0.0, t - 0.6)
		bot = -depth * 0.4 * (1.0 - 0.6 * max(0.0, t - 0.7) / 0.3)
		ring = [
			(x, top, -hb), (x, 0.0, -hb * 0.98), (x, bot * 0.7, -hb * flat), (x, bot, 0.0),
			(x, bot * 0.7, hb * flat), (x, 0.0, hb * 0.98), (x, top, hb),
		]
		rows.append([bm.verts.new(v) for v in ring])
	for i in range(segs):
		a, b = rows[i], rows[i + 1]
		for k in range(6):
			bm.faces.new((a[k], b[k], b[k + 1], a[k + 1]))
	bm.faces.new(list(reversed(rows[0])))        # transom
	deck = rows[-1]
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
	p.paint("antifoul", lambda c: c.y < -0.02)
	return p


def deck_plate(length, beam, y, mat, segs=10):
	"""A flat deck over a hull() of the same size."""
	p = Piece(mat)
	bm = p.bm
	left, right = [], []
	for i in range(segs + 1):
		t = i / segs
		x = -length / 2 + length * t
		hb = beam / 2 * (1.0 if t < 0.55 else math.cos((t - 0.55) / 0.45 * math.pi / 2) ** 0.8)
		hb = max(hb * 0.97, 0.002)
		left.append(bm.verts.new((x, y, -hb)))
		right.append(bm.verts.new((x, y, hb)))
	for i in range(segs):
		bm.faces.new((left[i], right[i], right[i + 1], left[i + 1]))
	return p


def figure(at, mat="rower"):
	"""A little seated person (for boats): body and head."""
	x, y, z = at
	return [box(0.3, 0.5, 0.36, mat, bevel=0.06, at=(x, y + 0.25, z)),
		sphere(0.13, "skin", 8, 6, at=(x, y + 0.65, z))]


# ---------------------------------------------------------------- small boats

def tinny():
	"""A 4.3 m aluminium dinghy with a tiller outboard and one bloke fishing."""
	p = [hull(4.3, 1.7, 0.75, "alloy", segs=8, rake=0.15)]
	p.append(deck_plate(4.3, 1.7, 0.1, "alloy_dark", segs=8))
	for x in (-0.6, 0.5):
		p.append(box(0.3, 0.04, 1.5, "alloy_dark", at=(x, 0.35, 0)))
	p.append(box(0.32, 0.45, 0.3, "motor", bevel=0.05, at=(-2.25, 0.55, 0)))
	p.append(box(0.08, 0.7, 0.12, "motor", at=(-2.3, 0.0, 0)))
	p += figure((-1.2, 0.35, 0.0), "hull_navy")
	p.append(tube([(-1.0, 0.8, 0.1), (0.3, 1.6, 0.9), (1.2, 2.0, 1.6)], 0.012, "motor", 4))
	put("Tinny", p)


def yacht():
	"""A 10 m sloop on a swing mooring: sails furled on the boom under their
	cover, mast 13 m."""
	p = [hull(10.0, 3.3, 1.6, "hull_white", segs=12, rake=0.3)]
	p.append(deck_plate(10.0, 3.3, 0.96, "deck", segs=12))
	p.append(box(3.2, 0.55, 2.2, "hull_white", bevel=0.12, at=(-0.6, 1.25, 0)))
	p.append(box(2.6, 0.18, 2.24, "glass", at=(-0.4, 1.32, 0)))
	p.append(lathe([(0.09, 0.95), (0.06, 14.0)], 6, "mast").move(0.8, 0, 0))
	p.append(lathe([(0.0, 0.0), (0.2, 0.2), (0.22, 3.1), (0.0, 3.3)], 8, "sail_cover").rot("z", -math.pi / 2).move(0.8, 1.85, 0))
	for z in (-1.5, 1.5):
		p.append(tube([(0.8, 13.6, 0), (0.8, 1.0, z)], 0.01, "rail", 3, cap=False))
	p.append(tube([(0.8, 13.8, 0), (5.0, 0.9, 0)], 0.01, "rail", 3, cap=False))
	p.append(tube([(0.8, 13.0, 0), (-4.9, 0.95, 0)], 0.01, "rail", 3, cap=False))
	p.append(box(0.02, 0.3, 3.0, "rail", at=(-3.6, 1.2, 0)))
	put("Yacht", p)


def cruiser():
	"""An 11 m flybridge motor cruiser."""
	p = [hull(11.0, 3.6, 1.8, "hull_white", segs=12, rake=0.5, flat=0.7)]
	p.append(box(11.0 * 0.62, 0.12, 3.5, "hull_navy", at=(-11 * 0.19, 0.6, 0)))
	p.append(deck_plate(11.0, 3.6, 1.08, "deck", segs=12))
	p.append(box(5.0, 1.4, 3.1, "hull_white", bevel=0.2, at=(-0.9, 1.75, 0)))
	p.append(box(4.6, 0.5, 3.16, "glass", at=(-0.7, 2.05, 0)))
	p.append(box(3.4, 0.9, 2.8, "hull_white", bevel=0.15, at=(-1.4, 2.8, 0)))
	p.append(box(2.8, 0.12, 3.0, "sail_cover", at=(-1.6, 3.95, 0)))
	for x in (-2.8, -0.4):
		for z in (-1.3, 1.3):
			p.append(box(0.05, 0.8, 0.05, "rail", at=(x, 3.55, z)))
	put("Cruiser", p)


def rowing_eight():
	"""A rowing eight: an 18 m shell, eight rowers in club singlets and the
	cox in the stern, oars out both sides (they don't pull: it glides)."""
	p = []
	L = 18.0
	shell = lathe([(0.0, -L / 2), (0.18, -L / 2 + 1.5), (0.3, -L / 4), (0.3, L / 4), (0.15, L / 2 - 1.2), (0.0, L / 2)], 10, "shell")
	shell.rot("z", -math.pi / 2).scale(1.0, 0.55, 1.0).move(0, 0.05, 0)
	p.append(shell)
	for i in range(8):
		x = -5.6 + i * 1.45
		p += figure((x, 0.1, 0.0))
		side = 1 if i % 2 == 0 else -1
		p.append(tube([(x + 0.2, 0.55, 0.0), (x + 0.6, 0.45, side * 1.7), (x + 0.9, 0.05, side * 3.6)], 0.022, "oar", 3, cap=False))
		p.append(box(0.5, 0.03, 0.18, "blade", at=(x + 0.95, 0.04, side * 3.75)))
		p.append(box(0.06, 0.06, 0.9, "rail", at=(x + 0.25, 0.5, side * 0.6)))
	p += figure((-7.2, 0.0, 0.0), "hull_navy")
	put("RowingEight", p)


# ---------------------------------------------------------------- moorings, markers, pontoon

def channel_pile(name, mat, top):
	"""A timber channel pile 6 m out of the water with its top mark: a green
	triangle (starboard) or a red can (port), and a light."""
	p = [cylinder(0.25, 6.5, "pile", segs=8, at=(0, -1.0, 0))]
	p.append(cylinder(0.27, 1.4, mat, segs=8, at=(0, 3.2, 0)))
	if top == "cone":
		p.append(lathe([(0.45, 5.6), (0.0, 6.4)], 8, mat))
	else:
		p.append(cylinder(0.32, 0.7, mat, segs=8, at=(0, 5.6, 0)))
	p.append(cylinder(0.08, 0.25, "buoy", segs=6, at=(0, 6.4, 0)))
	put(name, p)


def mooring_buoy():
	put("MooringBuoy", [sphere(0.35, "buoy", 10, 6, at=(0, 0.1, 0), s=(1, 0.8, 1)),
		cylinder(0.04, 0.3, "rail", segs=5, at=(0, 0.35, 0))], smooth=True)


def pontoon():
	"""A 12 x 3 m floating pontoon on its piles, the gangway up to the bank
	(towards -z) hinged at the land end."""
	p = [box(12.0, 0.4, 3.0, "pontoon", bevel=0.05, at=(0, 0.25, 0)),
		box(12.0, 0.25, 2.8, "float", at=(0, -0.05, 0))]
	for x in (-5.2, 5.2):
		p.append(cylinder(0.3, 6.0, "rail", segs=8, at=(x, -1.5, 1.8)))
	for x in (-4.0, -1.0, 2.0, 5.0):
		p.append(box(0.18, 0.2, 0.3, "motor", at=(x, 0.5, 1.45)))   # cleats/bumpers
	# Gangway: from the pontoon's back edge up to the bank 1.6 m higher
	gx = -3.0
	p.append(extrude([(-1.5, 0.45), (-9.5, 1.85), (-9.5, 1.95), (-1.5, 0.55)], gx - 0.7, gx + 0.7, "alloy_dark"))
	for z in (gx - 0.7, gx + 0.7):
		p.append(tube([(z, 1.5, -1.5), (z, 2.9, -9.5)], 0.03, "rail", 4))
	put("Pontoon", p)


# ---------------------------------------------------------------- the bank

def rocks():
	"""Three revetment rocks, about a metre across, rough."""
	for k in range(3):
		rng = random.Random(40 + k)
		p = Piece("rock")
		bmesh.ops.create_icosphere(p.bm, subdivisions=1, radius=0.55)
		for v in p.bm.verts:
			v.co *= 1.0 + rng.uniform(-0.28, 0.22)
		p.scale(rng.uniform(0.9, 1.3), rng.uniform(0.55, 0.8), rng.uniform(0.8, 1.1))
		p.paint("rock_dark", lambda c, r=rng.random(): (c.x * 3.1 + c.z * 2.3 + r * 5) % 1.0 < 0.35)
		put("Rock%d" % k, [p])


# ---------------------------------------------------------------- the cruise ship

def cruise_ship():
	"""A cruise ship alongside Portside Wharf: 250 m, a white hull with a navy
	band, ten decks of balconies stepping in, the funnel aft, lifeboats along
	the promenade. Stylised; the game only ever sees it from 1.5 km off."""
	L, B = 250.0, 32.0
	p = [hull(L, B, 16.0, "hull_navy", segs=16, rake=4.0, flat=0.85)]
	p.append(box(L * 0.62, 3.0, B * 1.0, "hull_white", at=(-L * 0.19, 8.6, 0)))
	decks = [(0.0, 10.0, 0.86, 0.96), (13.0, 9.0, 0.80, 0.94), (21.0, 8.0, 0.72, 0.90), (28.0, 6.0, 0.6, 0.84)]
	for y0, h, lf, bf in decks:
		ln = L * lf
		x = -L / 2 + 6 + ln / 2
		p.append(box(ln, h, B * bf, "hull_white", at=(x, 10.0 + y0 + h / 2, 0)))
		p.append(box(ln * 0.98, h * 0.55, B * bf + 0.1, "balcony", at=(x, 10.0 + y0 + h * 0.5, 0)))
		# window bands
		for k in range(int(h // 3)):
			p.append(box(ln * 0.97, 0.7, B * bf + 0.2, "window", at=(x, 10.0 + y0 + 1.4 + k * 3.0, 0)))
	# Bridge wing forward, funnel aft, a pool deck
	p.append(box(6.0, 3.0, B + 4.0, "hull_white", at=(L * 0.23, 34.0, 0)))
	p.append(box(5.6, 1.2, B + 4.2, "window", at=(L * 0.23, 34.5, 0)))
	funnel = lathe([(6.0, 0.0), (5.4, 12.0), (5.0, 14.0)], 10, "funnel")
	funnel.scale(1.6, 1.0, 1.0).move(-L * 0.3, 34.0, 0)
	p.append(funnel)
	p.append(lathe([(5.0, 14.0), (4.6, 15.5), (0.0, 15.5)], 10, "funnel_top").scale(1.6, 1.0, 1.0).move(-L * 0.3, 34.0, 0))
	p.append(box(20.0, 0.4, 10.0, "pool", at=(-L * 0.05, 34.3, 0)))
	for i in range(9):
		for z in (-B / 2 - 1.0, B / 2 + 1.0):
			p.append(box(9.0, 3.0, 3.0, "lifeboat", bevel=0.8, at=(-L * 0.28 + i * 15.0, 11.5, z)))
	put("CruiseShip", p)


def main():
	reset()
	tinny()
	yacht()
	cruiser()
	rowing_eight()
	channel_pile("PileGreen", "green", "cone")
	channel_pile("PileRed", "red", "can")
	mooring_buoy()
	pontoon()
	rocks()
	cruise_ship()
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

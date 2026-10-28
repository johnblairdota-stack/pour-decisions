"""The CityCat and its terminal (assets/citycat/citycat.glb): the Northshore
Hamilton stop over the river from Bulimba, and the boat that calls there.

Run:  python tools/blender/citycat.py

  CityCat        a 25 m catamaran: navy hulls, a white cabin wrapped in dark
                 glass with a navy band, the wheelhouse up on the roof
                 forward, open decks at the bow and stern with rails and
                 life rings. Bow towards +x, waterline at y = 0.
  Terminal       the pontoon: deck at y = 0.8, 30 m along x, river side -z,
                 bank side +z; a winged shelter roof, a glass windbreak with
                 a bench along it, boarding rails with a gap in the middle,
                 a stop sign, bins, a life ring box and two guide piles.
  GangwaySpan    6 m of gangway (along +z from z = 0), trusses and
                 handrails; the game lays as many as the walk to the bank
                 needs.
  GangwayLanding the concrete landing at the bank end.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import Piece, box, build, cylinder, export_glb, reset, torus, tri_count, tube  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "citycat", "citycat.glb")

PALETTE = {
	"navy": "1f4f8f", "white": "f4f7fa", "glass": "2a3a48", "rubber": "222222", "rail": "d2d6d8",
	"ring": "ff7a1a", "yellow": "ffc72c", "concrete": "b9b7b0", "deck": "8d9196", "seat": "2f6fd1",
	"fascia": "5a6b78", "screen": "9cc3d6", "pile": "4a5056", "sign_blue": "1f4f9a", "bin": "2f5f3f", "antifoul": "7a2a24",
}


def put(name, pieces):
	return build(name, pieces, PALETTE, None, smooth=False)


def side(poly, z0, z1, mat):
	"""A side profile [(x, y)] run across from z0 to z1."""
	p = Piece(mat)
	bm = p.bm
	a = [bm.verts.new((x, y, z0)) for x, y in poly]
	b = [bm.verts.new((x, y, z1)) for x, y in poly]
	n = len(poly)
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((a[i], a[j], b[j], b[i]))
	bm.faces.new(list(reversed(a)))
	bm.faces.new(b)
	return p


def rail(points, mat="rail", r=0.03):
	return tube(points, r, mat, 6)


def life_ring(at, face_z):
	return torus(0.3, 0.07, "ring", 12, 6).rot("x", math.pi / 2).move(at[0], at[1], at[2] + 0.04 * face_z)


# ------------------------------------------------------------------ the boat

def citycat():
	p = []
	L = 12.5
	# twin hulls: raked bow, square transom; red antifoul under the water
	hull = [(-L, -0.45), (L - 2.2, -0.45), (L, 0.6), (L + 0.2, 1.5), (-L, 1.5)]
	for z in (-2.75, 2.75):
		h = side(hull, z - 0.9, z + 0.9, "navy")
		h.paint("antifoul", lambda c: c.y < -0.1)
		p.append(h)
		# rubber rub strip along the sheer
		p.append(side([(-L, 1.35), (L + 0.1, 1.35), (L + 0.2, 1.5), (-L, 1.5)], z - 0.95, z + 0.95, "rubber")
			.scale(1, 1, 1))
	# wet deck between the hulls, the bow deck tapering
	p.append(side([(-L + 0.2, 1.45), (L - 1.0, 1.45), (L - 0.2, 1.75), (-L + 0.2, 1.75)], -3.65, 3.65, "white"))
	# main cabin: white skirt, a wrap of dark glass (raked at the front),
	# a navy belt band, the roof overhanging
	x0, x1 = -8.8, 6.6
	p.append(box(x1 - x0, 0.55, 6.6, "white", at=((x0 + x1) / 2, 2.02, 0)))
	p.append(box(x1 - x0 + 0.04, 0.22, 6.64, "navy", at=((x0 + x1) / 2, 2.38, 0)))
	p.append(side([(x0, 2.49), (x1, 2.49), (x1 - 0.7, 3.55), (x0, 3.55)], -3.25, 3.25, "glass"))
	# mullions so it reads as windows
	for x in [x0 + 1.2 + 1.55 * i for i in range(9)]:
		for z in (-3.27, 3.27):
			p.append(box(0.12, 1.06, 0.03, "white", at=(x, 3.02, z)))
	p.append(side([(x0 - 0.4, 3.55), (x1 - 0.5, 3.55), (x1 - 0.85, 3.8), (x0 - 0.4, 3.8)], -3.45, 3.45, "white"))
	# wheelhouse up on the roof, forward
	p.append(side([(1.4, 3.8), (5.0, 3.8), (4.6, 5.0), (1.6, 5.0)], -1.55, 1.55, "glass"))
	p.append(box(3.0, 0.3, 3.0, "white", at=(3.15, 4.12, 0)))
	p.append(box(3.6, 0.22, 3.4, "white", at=(3.1, 5.1, 0)))
	p.append(box(3.62, 0.1, 3.42, "navy", at=(3.1, 4.95, 0)))
	# mast: nav light and radar
	p.append(cylinder(0.05, 1.3, "white", 6, at=(2.2, 5.2, 0)))
	p.append(box(0.9, 0.08, 0.18, "fascia", at=(2.2, 6.2, 0)))
	p.append(box(0.12, 0.12, 0.12, "yellow", at=(2.2, 6.55, 0)))
	# roof kit: air con pods and a life raft canister
	for x in (-5.5, -2.5):
		p.append(box(1.4, 0.35, 1.1, "white", at=(x, 3.97, 0)))
	p.append(cylinder(0.35, 1.2, "white", 10, at=(0, 0, 0)).rot("z", math.pi / 2).move(-7.6, 4.15, 1.6))
	# bow deck rail, stern deck rail and seats, life rings
	bow = [(x1, 2.75, -3.4), (L - 0.9, 2.75, -2.6), (L - 0.4, 2.75, 0), (L - 0.9, 2.75, 2.6), (x1, 2.75, 3.4)]
	p.append(rail(bow))
	p.append(rail([(q[0], 2.25, q[2]) for q in bow], r=0.025))
	for q in bow:
		p.append(cylinder(0.025, 1.0, "rail", 6, at=(q[0], 1.75, q[2])))
	stern = [(x0, 2.75, -3.5), (-L + 0.4, 2.75, -3.5), (-L + 0.4, 2.75, -1.0)]
	p.append(rail(stern))
	p.append(rail([(q[0], 2.75, -q[2]) for q in stern]))
	for q in stern:
		p.append(cylinder(0.025, 1.0, "rail", 6, at=(q[0], 1.75, q[2])))
		p.append(cylinder(0.025, 1.0, "rail", 6, at=(q[0], 1.75, -q[2])))
	for z in (-2.4, 2.4):
		p.append(box(2.4, 0.45, 0.5, "seat", at=(-10.6, 2.0, z)))
		p.append(box(2.4, 0.5, 0.1, "seat", at=(-10.6, 2.45, z + (0.25 if z > 0 else -0.25))))
	p.append(life_ring((-L + 0.42, 2.25, -2.3), 0).rot("y", math.pi / 2).move(0, 0, 0))
	p.append(life_ring((x1 + 0.6, 2.3, -3.42), -1))
	p.append(life_ring((x1 + 0.6, 2.3, 3.42), 1))
	# boarding gates at the bow shoulders (yellow), black fenders on the bow
	for z in (-3.3, 3.3):
		p.append(box(0.9, 0.9, 0.06, "yellow", at=(x1 + 1.6, 2.25, z)))
	p.append(box(0.3, 0.5, 6.4, "rubber", at=(L - 0.6, 1.3, 0)))
	put("CityCat", p)


# ------------------------------------------------------------------ the stop

def terminal():
	p = []
	W, D = 30.0, 9.0
	# pontoon: concrete float, deck at 0.8, yellow edge, rubber fender river side
	p.append(box(W, 1.4, D, "concrete", at=(0, 0.1, 0)))
	p.append(box(W - 0.4, 0.04, D - 0.4, "deck", at=(0, 0.82, 0)))
	for z in (-D / 2 + 0.12, D / 2 - 0.12):
		p.append(box(W, 0.06, 0.24, "yellow", at=(0, 0.83, z)))
	for x in (-W / 2 + 0.12, W / 2 - 0.12):
		p.append(box(0.24, 0.06, D, "yellow", at=(x, 0.83, 0)))
	p.append(box(W, 0.45, 0.35, "rubber", at=(0, 0.35, -D / 2 - 0.15)))
	for x in range(-13, 14, 4):
		p.append(cylinder(0.22, 0.9, "rubber", 8).rot("x", math.pi / 2).move(x, 0.35, -D / 2 - 0.3))
	# guide piles behind the pontoon, with collars
	for x in (-11.0, 11.0):
		p.append(cylinder(0.55, 9.0, "pile", 14, at=(x, -3.0, D / 2 + 0.7)))
		p.append(box(1.6, 0.5, 1.4, "yellow", at=(x, 0.8, D / 2 + 0.55)))
		p.append(cylinder(0.6, 0.25, "white", 14, at=(x, 6.0, D / 2 + 0.7)))
	# shelter: winged roof on two rows of posts, white soffit, grey fascia
	zf, zb = -3.0, 3.8
	for x in (-10.5, -3.5, 3.5, 10.5):
		for z in (zf, zb):
			p.append(cylinder(0.12, 3.2, "white", 8, at=(x, 0.82, z)))
	roof = [(-4.4, 4.2), (0.4, 3.9), (4.6, 4.5), (4.6, 4.75), (0.4, 4.15), (-4.4, 4.45)]
	r = Piece("white")
	bm = r.bm
	a = [bm.verts.new((-12.5, y, z)) for z, y in roof]
	b = [bm.verts.new((12.5, y, z)) for z, y in roof]
	n = len(roof)
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((a[i], a[j], b[j], b[i]))
	bm.faces.new(list(reversed(a)))
	bm.faces.new(b)
	r.paint("fascia", lambda c: abs(abs(c.z) - 0) < 99 and (c.z < -4.3 or c.z > 4.5))
	p.append(r)
	p.append(box(25.0, 0.05, 0.12, "fascia", at=(0, 4.2, -4.4)))
	# glass windbreak with a bench along it, the river side open
	p.append(box(20.0, 2.0, 0.05, "screen", at=(0, 1.9, zb + 0.15)))
	p.append(box(20.2, 0.08, 0.1, "white", at=(0, 2.92, zb + 0.15)))
	for x in (-6.0, 0.0, 6.0):
		p.append(box(3.6, 0.08, 0.5, "seat", at=(x, 1.25, zb - 0.35)))
		p.append(box(3.6, 0.45, 0.06, "seat", at=(x, 1.55, zb - 0.1)))
		for dx in (-1.6, 1.6):
			p.append(box(0.06, 0.45, 0.45, "rail", at=(x + dx, 1.02, zb - 0.35)))
	# boarding rail along the river edge, a gap in the middle for the boat
	for x0, x1 in ((-14.6, -2.5), (2.5, 14.6)):
		p.append(rail([(x0, 1.85, -D / 2 + 0.3), (x1, 1.85, -D / 2 + 0.3)], r=0.035))
		p.append(rail([(x0, 1.35, -D / 2 + 0.3), (x1, 1.35, -D / 2 + 0.3)], r=0.025))
		x = x0
		while x <= x1 + 0.01:
			p.append(cylinder(0.035, 1.05, "rail", 6, at=(x, 0.82, -D / 2 + 0.3)))
			x += 2.0
	for x in (-2.5, 2.5):
		p.append(cylinder(0.08, 1.2, "yellow", 8, at=(x, 0.82, -D / 2 + 0.3)))
	# the stop sign, a timetable board, bins, a life ring box
	p.append(cylinder(0.07, 3.8, "fascia", 8, at=(-13.5, 0.82, 2.5)))
	p.append(box(0.08, 1.2, 0.9, "sign_blue", at=(-13.5, 4.0, 2.5)))
	p.append(box(0.09, 0.5, 0.6, "white", at=(-13.5, 4.1, 2.5)))
	p.append(box(1.2, 1.6, 0.1, "fascia", at=(9.0, 1.9, zb - 0.05)))
	p.append(box(1.0, 1.3, 0.11, "white", at=(9.0, 1.95, zb - 0.06)))
	for x in (-9.0, 12.5):
		p.append(cylinder(0.3, 0.95, "bin", 10, at=(x, 0.82, zb - 0.3)))
	p.append(box(0.8, 0.9, 0.3, "ring", at=(13.5, 1.6, zb - 0.2)))
	p.append(life_ring((13.5, 1.6, zb - 0.36), -1))
	put("Terminal", p)


def gangway():
	p = []
	Lg, w = 6.0, 2.4
	p.append(box(w, 0.12, Lg, "deck", at=(0, 0.0, Lg / 2)))
	for s in (-1, 1):
		x = s * w / 2
		# a little Warren truss each side
		p.append(box(0.1, 0.1, Lg, "white", at=(x, -0.05, Lg / 2)))
		p.append(box(0.1, 0.1, Lg, "white", at=(x, 1.1, Lg / 2)))
		for i in range(4):
			za, zb = Lg * i / 4, Lg * (i + 1) / 4
			ya, yb = (-0.05, 1.1) if i % 2 == 0 else (1.1, -0.05)
			p.append(tube([(x, ya, za), (x, yb, zb)], 0.04, "white", 6))
		p.append(rail([(x - s * 0.08, 0.95, 0), (x - s * 0.08, 0.95, Lg)], r=0.025))
	put("GangwaySpan", p)
	put("GangwayLanding", [box(4.0, 1.4, 3.0, "concrete", at=(0, -0.65, 0)), box(3.0, 0.05, 2.6, "deck", at=(0, 0.06, 0))]
		+ [cylinder(0.05, 1.0, "yellow", 6, at=(s * 1.8, 0.05, -1.3)) for s in (-1, 1)])


def main():
	reset()
	citycat()
	terminal()
	gangway()
	import bpy
	tot = 0
	for o in bpy.context.scene.objects:
		if o.type == "MESH":
			t = tri_count([o])
			tot += t
			print("  %-15s %5d triangles" % (o.name, t))
	print("  total %d" % tot)
	export_glb(OUT)
	print("wrote", OUT)


if __name__ == "__main__":
	main()

"""Fences and gates round Riverlight (assets/fences/fences.glb): what the
estate's houses and blocks, the car yards, the sheds, the golf course and the
park are fenced with.

Run:  python tools/blender/fences.py

Each fence is one 3 m bay along x, centred on its origin, standing on the
ground; the game stretches a bay a little to fit a run and puts a post at
each end of the run (FencePost, FenceTimberPost). Parts named "paint" take
the colour the game gives each run (Colorbond colours, render, slats).

  ChainLink        2.1 m galvanised posts and rails, the wire ("wire") a
                   shader in the game
  Palisade         2.1 m steel pales with split tops, for the sheds
  Colorbond        1.8 m ribbed steel sheet between posts ("paint")
  Paling           1.8 m timber palings, rails on the back
  SlatFence        a rendered plinth and horizontal slats ("paint"): the
                   2017 estate's front fences
  PoolGlass        frameless glass on spigots
  LowWall          a 0.9 m rendered wall with a capping ("paint")
  Bollards         two timber bollards, the park's edge to the road
  SlidingGate      a 6 m chain-link gate on wheels and its track
  DrivewayGate     a 4 m pair of slatted swing gates between piers
  PedGate          a 1 m slatted gate between piers, a letterbox on one
  BoomGate         a car park boom: the housing and a 5 m striped arm
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import Piece, box, build, cylinder, export_glb, reset, tri_count  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "fences", "fences.glb")
BAY = 3.0

PALETTE = {
	"galv": "a9b0b5", "wire": "b9c2ca", "paint": "ffffff", "timber": "b98a55", "timber_dark": "8e6a44",
	"render": "e8e2d6", "glass": "9cc3d6", "steel_black": "2e3236", "boom_red": "d9302c", "boom_white": "f4f7fa",
	"concrete": "c4c2bb", "letterbox": "3a3f44", "rubber": "222222", "yellow": "ffc72c",
}


def put(name, pieces):
	return build(name, pieces, PALETTE, None, smooth=False)


def post(h, r=0.03, mat="galv"):
	return cylinder(r, h, mat, 8)


def chain_link():
	p = [post(2.1, 0.03).move(-BAY / 2, 0, 0)]
	p.append(cylinder(0.02, BAY, "galv", 6).rot("z", math.pi / 2).move(BAY / 2, 2.08, 0))
	p.append(cylinder(0.012, BAY, "galv", 4).rot("z", math.pi / 2).move(BAY / 2, 0.08, 0))
	p.append(box(BAY, 2.0, 0.01, "wire", at=(0, 1.07, 0)))
	put("ChainLink", p)


def palisade():
	p = [box(0.08, 2.15, 0.08, "galv", at=(-BAY / 2, 1.07, 0))]
	for y in (0.35, 1.75):
		p.append(box(BAY, 0.05, 0.05, "galv", at=(0, y, 0.05)))
	n = 14
	for i in range(n):
		x = -BAY / 2 + (i + 0.5) * BAY / n
		pale = Piece("galv")
		bm = pale.bm
		# a W-section pale as a flat strip with a split, pointed top
		pts = [(-0.03, 0), (0.03, 0), (0.03, 2.0), (0.015, 2.1), (0.0, 2.04), (-0.015, 2.1), (-0.03, 2.0)]
		a = [bm.verts.new((x + u, y, 0.09)) for u, y in pts]
		b = [bm.verts.new((x + u, y, 0.1)) for u, y in pts]
		for k in range(len(pts)):
			j = (k + 1) % len(pts)
			bm.faces.new((a[k], a[j], b[j], b[k]))
		bm.faces.new(list(reversed(a)))
		bm.faces.new(b)
		p.append(pale)
	put("Palisade", p)


def colorbond():
	p = [box(0.06, 1.85, 0.06, "paint", at=(-BAY / 2, 0.925, 0))]
	p.append(box(BAY, 0.06, 0.06, "paint", at=(0, 1.8, 0)))
	p.append(box(BAY, 0.06, 0.06, "paint", at=(0, 0.05, 0)))
	# ribbed sheet: a zig-zag section across the bay
	sheet = Piece("paint")
	bm = sheet.bm
	ribs = 12
	zs = []
	for k in range(ribs * 2 + 1):
		x = -BAY / 2 + k * BAY / (ribs * 2)
		zs.append((x, 0.015 if k % 2 else -0.015))
	lo = [bm.verts.new((x, 0.05, z)) for x, z in zs]
	hi = [bm.verts.new((x, 1.78, z)) for x, z in zs]
	for k in range(len(zs) - 1):
		bm.faces.new((lo[k], lo[k + 1], hi[k + 1], hi[k]))
	p.append(sheet)
	put("Colorbond", p)


def paling():
	p = [box(0.1, 1.85, 0.1, "timber_dark", at=(-BAY / 2, 0.925, 0.08))]
	for y in (0.35, 1.5):
		p.append(box(BAY, 0.1, 0.05, "timber_dark", at=(0, y, 0.06)))
	n = 20
	for i in range(n):
		x = -BAY / 2 + (i + 0.5) * BAY / n
		top = 1.8 + (0.03 if i % 2 else 0.0)
		p.append(box(BAY / n - 0.01, top, 0.015, "paint", at=(x, top / 2, 0)))
	put("Paling", p)


def slat_fence():
	p = [box(BAY, 0.45, 0.22, "render", at=(0, 0.225, 0))]
	p.append(box(BAY + 0.02, 0.04, 0.26, "concrete", at=(0, 0.47, 0)))
	p.append(box(0.35, 1.6, 0.35, "render", at=(-BAY / 2, 0.8, 0)))
	p.append(box(0.4, 0.05, 0.4, "concrete", at=(-BAY / 2, 1.62, 0)))
	for k in range(9):
		y = 0.58 + k * 0.11
		p.append(box(BAY - 0.35, 0.075, 0.03, "paint", at=(0, y, 0)))
	p.append(box(0.04, 1.0, 0.04, "steel_black", at=(0, 1.0, -0.03)))
	put("SlatFence", p)


def pool_glass():
	p = []
	for x in (-BAY / 2 + 0.75, BAY / 2 - 0.75):
		p.append(box(1.44, 1.2, 0.012, "glass", at=(x, 0.7, 0)))
		for dx in (-0.45, 0.45):
			p.append(cylinder(0.025, 0.25, "galv", 8, at=(x + dx, 0, 0)))
	put("PoolGlass", p)


def low_wall():
	p = [box(BAY, 0.85, 0.22, "paint", at=(0, 0.425, 0))]
	p.append(box(BAY + 0.02, 0.06, 0.28, "concrete", at=(0, 0.88, 0)))
	put("LowWall", p)


def bollards():
	p = []
	for x in (-BAY / 4, BAY / 4):
		b = cylinder(0.09, 0.9, "timber", 8, at=(x, 0, 0))
		p.append(b)
		p.append(cylinder(0.092, 0.06, "boom_white", 8, at=(x, 0.72, 0)))
	put("Bollards", p)


def posts():
	put("FencePost", [post(2.15, 0.035)])
	put("FenceTimberPost", [box(0.1, 1.85, 0.1, "timber_dark", at=(0, 0.925, 0))])
	put("FencePier", [box(0.35, 1.6, 0.35, "render", at=(0, 0.8, 0)), box(0.4, 0.05, 0.4, "concrete", at=(0, 1.62, 0))])


def sliding_gate():
	L = 6.0
	p = [box(0.06, 2.0, 0.06, "galv", at=(-L / 2, 1.1, 0)), box(0.06, 2.0, 0.06, "galv", at=(L / 2, 1.1, 0))]
	p.append(box(L, 0.06, 0.06, "galv", at=(0, 2.08, 0)))
	p.append(box(L, 0.06, 0.06, "galv", at=(0, 0.12, 0)))
	p.append(box(L, 0.04, 0.04, "galv", at=(0, 1.1, 0)))
	p.append(box(L, 1.94, 0.01, "wire", at=(0, 1.1, 0)))
	# diagonal brace
	d = math.hypot(L / 2, 1.9)
	p.append(box(d, 0.04, 0.04, "galv").rot("z", math.atan2(1.9, L / 2)).move(-L / 4, 1.1, 0))
	for x in (-L / 2 + 0.5, L / 2 - 0.5):
		p.append(cylinder(0.08, 0.04, "rubber", 10).rot("x", math.pi / 2).move(x, 0.08, 0.02))
	p.append(box(L * 2, 0.03, 0.08, "galv", at=(-L / 2, 0.015, 0)))
	put("SlidingGate", p)


def driveway_gate():
	p = []
	for x in (-2.15, 2.15):
		p.append(box(0.35, 1.6, 0.35, "render", at=(x, 0.8, 0)))
		p.append(box(0.4, 0.05, 0.4, "concrete", at=(x, 1.62, 0)))
	for s in (-1, 1):
		cx = s * 0.99
		p.append(box(1.96, 0.05, 0.05, "steel_black", at=(cx, 1.48, 0)))
		p.append(box(1.96, 0.05, 0.05, "steel_black", at=(cx, 0.12, 0)))
		for k in range(12):
			p.append(box(1.9, 0.075, 0.03, "paint", at=(cx, 0.22 + k * 0.105, 0)))
	put("DrivewayGate", p)


def ped_gate():
	p = []
	for x in (-0.68, 0.68):
		p.append(box(0.35, 1.6, 0.35, "render", at=(x, 0.8, 0)))
		p.append(box(0.4, 0.05, 0.4, "concrete", at=(x, 1.62, 0)))
	for k in range(11):
		p.append(box(0.98, 0.075, 0.03, "paint", at=(0, 0.25 + k * 0.105, 0)))
	p.append(box(0.04, 0.12, 0.06, "steel_black", at=(0.4, 1.0, 0.03)))
	p.append(box(0.3, 0.22, 0.12, "letterbox", at=(0.68, 1.2, 0.24)))
	put("PedGate", p)


def boom_gate():
	p = [box(0.4, 1.0, 0.35, "boom_white", at=(0, 0.5, 0))]
	p.append(box(0.42, 0.12, 0.37, "boom_red", at=(0, 1.0, 0)))
	p.append(box(0.6, 0.15, 0.6, "concrete", at=(0, 0.075, 0)))
	n = 10
	for k in range(n):
		x = 0.25 + (k + 0.5) * 5.0 / n
		p.append(box(5.0 / n, 0.08, 0.05, "boom_red" if k % 2 == 0 else "boom_white", at=(x, 0.9, 0)))
	p.append(box(0.08, 0.85, 0.08, "yellow", at=(5.4, 0.425, 0)))
	put("BoomGate", p)


def main():
	reset()
	chain_link()
	palisade()
	colorbond()
	paling()
	slat_fence()
	pool_glass()
	low_wall()
	bollards()
	posts()
	sliding_gate()
	driveway_gate()
	ped_gate()
	boom_gate()
	import bpy
	tot = 0
	for o in bpy.context.scene.objects:
		if o.type == "MESH":
			t = tri_count([o])
			tot += t
			print("  %-16s %5d triangles" % (o.name, t))
	print("  total %d" % tot)
	export_glb(OUT)
	print("wrote", OUT)


if __name__ == "__main__":
	main()

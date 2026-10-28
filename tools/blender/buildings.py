"""The neighbours round Riverlight (assets/buildings/buildings.glb): the
houses and the bits that sit on the roofs of the buildings the game draws
from their footprints.

  ModernHouse, ModernHouseB  the two-storey white rendered houses in the row
                             along the golf course (Hamilton Reach, 2017)
  Queenslander               high-set timber house on stumps, verandah, tin
                             hip roof (the older streets up on the ridge)
  PostwarHouse               low-set brick house with a tile hip roof
  ...Far                     a few dozen triangles each, for the thousands of
                             houses out in the haze; Body and Roof apart, so
                             the game can colour each house its own way
  RoofAC, LiftOverrun, SolarArray, Whirlybird   roof kit for the apartment
                             blocks and the warehouses
  Container20, Container40   shipping containers (Eat Street, the wharves);
                             painted white so the game tints each one

Run:  python tools/blender/buildings.py

Each model's origin is on the ground at its middle, front (street side)
towards +z.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import Piece, box, build, cylinder, export_glb, reset, tri_count  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "buildings", "buildings.glb")

PALETTE = {
	"render": "f2f0ea", "render_grey": "c9c8c2", "clad": "3a3d42", "timber": "b4875a", "glass": "54636e",
	"roof_flat": "d8d8d2", "frame": "2f3236", "garage": "8d9196", "balustrade": "a9c2cc", "weatherboard": "efe6cf",
	"trim": "ffffff", "roof_tin": "8a9096", "lattice": "6b5a48", "stump": "9a9890", "brick": "a5644a",
	"roof_tile": "b0583e", "ac": "e9e9e4", "ac_grille": "54585c", "solar": "263a5c", "solar_frame": "b9bdc0",
	"plant": "a9adb0", "door": "5a5e63", "container": "ffffff", "container_dark": "3b3e42", "whirly": "c7cbce",
	"body": "ffffff", "roof": "ffffff", "path": "c8c4ba",
}


def put(name, pieces, smooth=False):
	return build(name, pieces, PALETTE, None, smooth=smooth)


def quad_piece(verts, faces, mat):
	"""A Piece from raw verts (Godot coords) and faces (index lists)."""
	p = Piece(mat)
	vs = [p.bm.verts.new(v) for v in verts]
	for f in faces:
		p.bm.faces.new([vs[i] for i in f])
	return p


def hip(w, d, y0, h, ridge, mat, at=(0, 0)):
	"""A hip roof over a w x d box: eaves at y0, ridge h up, `ridge` long
	(along x; 0 makes a pyramid)."""
	x, z = at
	hw, hd, r = w / 2, d / 2, ridge / 2
	v = [(x - hw, y0, z - hd), (x + hw, y0, z - hd), (x + hw, y0, z + hd), (x - hw, y0, z + hd),
		(x - r, y0 + h, z), (x + r, y0 + h, z)]
	if ridge <= 0.01:
		v = v[:5]
		f = [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (3, 2, 1, 0)]
	else:
		f = [(0, 1, 5, 4), (1, 2, 5), (2, 3, 4, 5), (3, 0, 4), (3, 2, 1, 0)]
	return quad_piece(v, f, mat)


def gable(w, d, y0, h, mat, at=(0, 0), axis="x"):
	"""A gable roof, ridge along `axis`."""
	x, z = at
	hw, hd = w / 2, d / 2
	if axis == "x":
		v = [(x - hw, y0, z - hd), (x + hw, y0, z - hd), (x + hw, y0, z + hd), (x - hw, y0, z + hd),
			(x - hw, y0 + h, z), (x + hw, y0 + h, z)]
		f = [(0, 1, 5, 4), (2, 3, 4, 5), (3, 0, 4), (1, 2, 5), (3, 2, 1, 0)]
	else:
		v = [(x - hw, y0, z - hd), (x + hw, y0, z - hd), (x + hw, y0, z + hd), (x - hw, y0, z + hd),
			(x, y0 + h, z - hd), (x, y0 + h, z + hd)]
		f = [(3, 0, 4, 5), (1, 2, 5, 4), (0, 1, 4), (2, 3, 5), (3, 2, 1, 0)]
	return quad_piece(v, f, mat)


def pane(w, h, at, face="z", mat="glass", t=0.06):
	"""A flat window/door panel standing just proud of a wall facing +face
	(z, -z, x, -x)."""
	x, y, z = at
	if face in ("z", "-z"):
		return box(w, h, t, mat, at=(x, y, z))
	return box(t, h, w, mat, at=(x, y, z))


# ------------------------------------------------------------------ houses

def modern_house(name, flip=1.0, screen="clad"):
	"""Two storeys of white render, the upper floor stepped back on one side
	and run out over the garage on the other; flat roofs with a thin parapet,
	a balcony with a glass balustrade, a charcoal (or timber) feature panel."""
	s = flip
	p = []
	# ground floor 11 x 13, garage on one side at the front
	p.append(box(11.0, 3.2, 13.0, "render", at=(0, 1.6, 0)))
	p.append(box(11.3, 0.25, 13.3, "roof_flat", at=(0, 3.25, 0)))
	p.append(pane(5.2, 2.4, (-2.6 * s, 1.2, 6.53), mat="garage"))
	p.append(pane(1.1, 2.3, (1.2 * s, 1.15, 6.53), mat="door"))
	p.append(pane(2.6, 2.0, (3.6 * s, 1.4, 6.53)))
	for z in (-3.5, 1.5):
		p.append(pane(2.4, 1.6, (5.53 * s, 1.6, z), face="x"))
		p.append(pane(2.4, 1.6, (-5.53 * s, 1.6, z), face="x"))
	p.append(pane(6.0, 2.4, (0, 1.3, -6.53)))     # back stacker doors to the yard
	# upper floor 8 x 10, pushed to one side and forward over the garage
	ux = -1.4 * s
	p.append(box(8.2, 3.0, 10.0, "render", at=(ux, 4.85, 0.8)))
	p.append(box(8.5, 0.35, 10.3, "roof_flat", at=(ux, 6.5, 0.8)))
	p.append(box(8.2, 0.5, 0.25, "render", at=(ux, 6.6, 5.95)))   # parapet lip
	# feature panel and windows on the front of the upper floor
	p.append(pane(3.4, 3.0, (ux - 2.3 * s, 4.85, 5.83), mat=screen, t=0.14))
	p.append(pane(3.6, 1.8, (ux + 1.6 * s, 5.0, 5.83)))
	for z in (-2.5, 2.5):
		p.append(pane(2.0, 1.4, (ux + 4.13 * s, 5.0, z + 0.8), face="x"))
		p.append(pane(2.0, 1.4, (ux - 4.13 * s, 5.0, z + 0.8), face="x"))
	p.append(pane(5.0, 1.8, (ux, 5.0, -4.23)))
	# balcony on the ground floor roof beside the upper floor
	bx = 3.9 * s
	p.append(pane(2.4, 2.2, (bx - 1.0 * s, 4.6, 0.0), face="x"))
	p.append(box(3.0, 1.0, 0.05, "balustrade", at=(bx, 3.9, 6.45)))
	p.append(box(0.05, 1.0, 12.8, "balustrade", at=(bx + 1.48 * s, 3.9, 0)))
	p.append(box(3.1, 0.05, 0.08, "frame", at=(bx, 4.42, 6.47)))
	# entry awning, path and letterbox
	p.append(box(2.4, 0.12, 1.4, "clad", at=(1.2 * s, 2.7, 7.2)))
	p.append(box(1.2, 0.04, 3.0, "path", at=(1.2 * s, 0.02, 8.0)))
	p.append(box(5.0, 0.04, 3.0, "path", at=(-2.6 * s, 0.02, 8.0)))
	p.append(box(0.4, 1.1, 0.3, "render_grey", at=(2.5 * s, 0.55, 9.3)))
	put(name, p)


def queenslander():
	"""High-set, on stumps with timber lattice between them, weatherboards,
	a front verandah with white rails and posts, a tin hip roof and a small
	front gable, stairs down to the yard."""
	p = []
	w, d, fl = 10.0, 11.0, 2.4
	for x in (-4.6, -1.5, 1.5, 4.6):
		for z in (-5.0, -1.7, 1.7, 5.0, 7.3):
			p.append(box(0.22, fl, 0.22, "stump", at=(x, fl / 2, z)))
	p.append(box(w - 0.4, 1.6, 0.05, "lattice", at=(0, 0.9, 7.25)))
	for x in (-4.65, 4.65):
		p.append(box(0.05, 1.6, d - 0.6, "lattice", at=(x, 0.9, 0)))
	p.append(box(w, 0.3, d, "trim", at=(0, fl + 0.15, 0)))
	p.append(box(w - 0.2, 3.0, d - 0.2, "weatherboard", at=(0, fl + 1.8, 0)))
	# verandah across the front
	p.append(box(w, 0.25, 2.6, "timber", at=(0, fl + 0.12, 6.7)))
	for x in (-4.85, -2.4, 0.0, 2.4, 4.85):
		p.append(box(0.14, 2.9, 0.14, "trim", at=(x, fl + 1.6, 7.9)))
	p.append(box(w, 0.07, 0.06, "trim", at=(0, fl + 1.2, 7.9)))
	p.append(box(w, 0.07, 0.06, "trim", at=(0, fl + 0.4, 7.9)))
	for i in range(31):
		x = -4.8 + i * 0.32
		if abs(x) > 0.75:
			p.append(box(0.04, 0.8, 0.04, "trim", at=(x, fl + 0.8, 7.9)))
	# windows and the front door
	p.append(pane(1.0, 2.2, (0, fl + 1.4, 5.43), mat="door"))
	for x in (-3.0, 3.0):
		p.append(pane(1.4, 1.5, (x, fl + 1.8, 5.43)))
	for z in (-3.0, 0.5, 3.5):
		p.append(pane(1.1, 1.4, (4.93, fl + 1.8, z), face="x"))
		p.append(pane(1.1, 1.4, (-4.93, fl + 1.8, z), face="x"))
	# roof: the main hip, the verandah's skillion, the front gable
	p.append(hip(w + 0.8, d + 0.8, fl + 3.3, 2.6, 2.5, "roof_tin"))
	vr = quad_piece([(-5.2, fl + 3.35, 5.4), (5.2, fl + 3.35, 5.4), (5.2, fl + 2.95, 8.25), (-5.2, fl + 2.95, 8.25)],
		[(0, 1, 2, 3)], "roof_tin")
	p.append(vr)
	p.append(gable(3.6, 3.0, fl + 3.3, 1.7, "roof_tin", at=(0, 4.2), axis="z"))
	p.append(quad_piece([(-1.7, fl + 3.3, 5.72), (1.7, fl + 3.3, 5.72), (0, fl + 4.9, 5.72)], [(0, 1, 2)], "trim"))
	# stairs to the yard
	for i in range(8):
		y = fl - 0.3 * i
		p.append(box(1.4, 0.06, 0.32, "timber", at=(0, y - 0.15, 8.15 + 0.3 * i)))
	for x in (-0.72, 0.72):
		p.append(quad_piece([(x, fl + 0.9, 8.0), (x, 0.9, 10.5), (x, 0.0, 10.5), (x, fl, 8.0)], [(0, 1, 2, 3)], "trim"))
	put("Queenslander", p)


def postwar_house():
	"""Low-set face brick on a short base, a terracotta tile hip roof, a
	small porch and a carport."""
	p = []
	p.append(box(11.0, 0.6, 9.5, "render_grey", at=(0, 0.3, 0)))
	p.append(box(10.6, 2.6, 9.1, "brick", at=(0, 1.9, 0)))
	p.append(hip(12.0, 10.4, 3.2, 2.2, 3.0, "roof_tile"))
	p.append(pane(1.0, 2.1, (1.5, 1.65, 4.58), mat="door"))
	for x in (-3.0, 3.6):
		p.append(pane(2.0, 1.4, (x, 2.0, 4.58)))
	for z in (-2.5, 1.5):
		p.append(pane(1.4, 1.3, (5.33, 2.0, z), face="x"))
		p.append(pane(1.4, 1.3, (-5.33, 2.0, z), face="x"))
	p.append(box(2.8, 0.12, 1.6, "roof_tile", at=(1.5, 3.0, 5.3)))
	for x in (0.3, 2.7):
		p.append(box(0.12, 2.4, 0.12, "trim", at=(x, 1.8, 6.0)))
	# carport on the side
	p.append(box(3.4, 0.1, 6.0, "roof_tin", at=(7.2, 2.6, 1.5)))
	for x, z in ((8.8, -1.4), (8.8, 4.4), (5.6, 4.4)):
		p.append(box(0.1, 2.6, 0.1, "trim", at=(x, 1.3, z)))
	p.append(box(3.0, 0.04, 9.0, "path", at=(7.2, 0.02, 3.0)))
	put("PostwarHouse", p)


def far_houses():
	"""Few-triangle stand-ins, the body and the roof as separate models so
	each house in a field can take its own wall and roof colour."""
	# Queenslander: a raised box and a hip roof with the verandah under it
	put("QueenslanderFarBody", [box(9.6, 3.0, 10.6, "body", at=(0, 3.9, 0)),
		box(9.6, 2.4, 0.3, "body", at=(0, 1.2, 0))])
	put("QueenslanderFarRoof", [hip(10.8, 13.8, 5.4, 2.4, 3.0, "roof", at=(0, 1.3))])
	put("PostwarFarBody", [box(10.6, 3.2, 9.1, "body", at=(0, 1.6, 0))])
	put("PostwarFarRoof", [hip(11.8, 10.2, 3.2, 2.0, 3.0, "roof")])
	put("ModernFarBody", [box(11.0, 3.2, 13.0, "body", at=(0, 1.6, 0)),
		box(8.2, 3.2, 10.0, "body", at=(-1.4, 4.8, 0.8))])
	put("ModernFarRoof", [box(11.3, 0.2, 13.3, "roof", at=(0, 3.3, 0)),
		box(8.5, 0.3, 10.3, "roof", at=(-1.4, 6.5, 0.8))])


# ------------------------------------------------------------------ roof kit

def roof_ac():
	"""Three split-system condensers on a galvanised rail frame."""
	p = [box(3.4, 0.12, 0.9, "plant", at=(0, 0.06, 0))]
	for x in (-1.1, 0.0, 1.1):
		p.append(box(0.95, 0.8, 0.4, "ac", bevel=0.03, at=(x, 0.52, 0)))
		p.append(box(0.55, 0.55, 0.03, "ac_grille", at=(x - 0.08, 0.52, 0.21)))
	put("RoofAC", p)


def lift_overrun():
	"""The lift's machine room box on the roof, with a door and louvres."""
	p = [box(3.2, 2.8, 2.6, "render_grey", at=(0, 1.4, 0)),
		box(3.4, 0.2, 2.8, "roof_flat", at=(0, 2.9, 0)),
		pane(0.9, 2.0, (0.6, 1.0, 1.33), mat="door"),
		pane(1.2, 0.8, (-0.8, 1.9, 1.33), mat="frame")]
	put("LiftOverrun", p)


def solar_array():
	"""Ten panels on low tilt frames, 5.2 x 3.4 m, facing +z (north)."""
	p = []
	for r in range(2):
		for c in range(5):
			x = -2.1 + c * 1.05
			z = -0.85 + r * 1.75
			panel = box(1.0, 0.04, 1.65, "solar", at=(0, 0, 0)).rot("x", math.radians(10)).move(x, 0.35, z)
			p.append(panel)
		p.append(box(5.3, 0.05, 0.05, "solar_frame", at=(0, 0.2, -0.85 + r * 1.75 - 0.7)))
		p.append(box(5.3, 0.05, 0.05, "solar_frame", at=(0, 0.45, -0.85 + r * 1.75 + 0.7)))
	put("SolarArray", p)


def whirlybird():
	"""A roof ventilator: a ribbed dome on a short neck."""
	p = [cylinder(0.18, 0.3, "whirly", segs=10),
		cylinder(0.3, 0.32, "whirly", segs=12, bevel=0.1, at=(0, 0.3, 0))]
	put("Whirlybird", p)


# ------------------------------------------------------------------ containers

def container(name, length):
	"""A shipping container, corrugated sides, doors at the back (-x end)
	with locking bars; 2.44 wide, 2.59 high. Runs along x."""
	w, h = 2.44, 2.59
	p = [box(length, h, w, "container", at=(0, h / 2, 0))]
	n = int(length / 0.55)
	for i in range(n):
		x = -length / 2 + 0.3 + i * (length - 0.6) / max(n - 1, 1)
		for z in (w / 2 + 0.02, -w / 2 - 0.02):
			p.append(box(0.14, h - 0.35, 0.04, "container", at=(x, h / 2, z)))
	for z in (-0.3, 0.3):
		p.append(box(0.04, h - 0.2, 0.04, "container_dark", at=(-length / 2 - 0.03, h / 2, z * 1.8)))
	for x in (-length / 2, length / 2):
		for z in (-w / 2 + 0.1, w / 2 - 0.1):
			p.append(box(0.2, h, 0.2, "container_dark", at=(x + (0.1 if x < 0 else -0.1), h / 2, z)))
	p.append(box(length, 0.15, w, "container_dark", at=(0, 0.075, 0)))
	put(name, p)


def main():
	reset()
	modern_house("ModernHouse")
	modern_house("ModernHouseB", flip=-1.0, screen="timber")
	queenslander()
	postwar_house()
	far_houses()
	roof_ac()
	lift_overrun()
	solar_array()
	whirlybird()
	container("Container20", 6.06)
	container("Container40", 12.19)
	import bpy
	tot = 0
	for o in bpy.context.scene.objects:
		if o.type == "MESH":
			t = tri_count([o])
			tot += t
			print("  %-20s %5d triangles" % (o.name, t))
	print("  total %d" % tot)
	export_glb(OUT)
	print("wrote", OUT)


if __name__ == "__main__":
	main()

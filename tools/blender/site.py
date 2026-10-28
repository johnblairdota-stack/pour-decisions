"""The site set-up (assets/site/site.glb): what makes the ground round
Riverlight read as a working 2017 Brisbane job. Sheds and their stairs, the
port-a-loos, temporary fencing and the gate, skips and bins, the materials
laydown (ply, pallets, bar, mesh), gas bottles, the genset, a lighting tower,
a water tank, the safety kit (extinguisher stand, spill kit, cones, bollards,
barrier mesh), the crib corner and the truck washout bay.

Run:  python tools/blender/site.py

Each part is a top-level node the game picks out with factory.gd's prop(),
its origin on the ground at its footprint's centre unless a note says not;
the game places them (scripts/yard.gd).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import box, build, cylinder, export_glb, lathe, reset, sphere, torus, tri_count, tube  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "site", "site.glb")

PALETTE = {
	"shed": "e8e6df", "shed_roof": "5f7f9f", "shed_trim": "9aa4ad", "glass": "5b7fa8", "steel": "afc0d2",
	"dark_steel": "6b7480", "grille": "2b2b2b", "rubber": "1d1f23", "machine": "ffc72c", "machine_dark": "e0a800",
	"orange": "ff7a1a", "loo": "2f6fd1", "loo_roof": "f4f7fa", "fence": "c9d1d8", "fence_wire": "b9c2ca", "cloth": "2e3a36",
	"fence_foot": "ff7a1a", "skip": "2f7a4a", "skip_dark": "245f3a", "rubbish": "b98a55", "ply": "c48d55",
	"ply_face": "d9a46c", "timber": "b98a55", "rebar": "8a5a3c", "tie": "2b2b2b", "red": "e5383b",
	"bottle_ox": "2b2b2b", "bottle_ac": "7a2430", "white": "f4f7fa", "genset": "4a6b8a", "lamp": "fff4c2",
	"tank": "8fa6b8", "first_aid": "2f8f6b", "cone": "ff7a1a", "band": "f4f7fa", "table": "f4f7fa",
	"chair": "2f6fd1", "esky": "e5383b", "umbrella": "ffc72c", "umbrella_b": "f4f7fa", "slurry": "6f7275",
	"wet_crust": "9b968a", "concrete": "b5b6b3", "bin_green": "2f6f3f", "bin_lid": "e5383b", "bin_yellow": "ffc72c",
	"sign": "f4f7fa", "sign_blue": "2f6fd1", "barrier": "ff7a1a",
}


def put(name, pieces, smooth=True):
	return build(name, pieces, PALETTE, None, smooth=smooth)


def bar(a, b, r, mat, segs=6):
	return tube([a, b], r, mat, segs)


# ---------------------------------------------------------------- sheds

SHED_L, SHED_H, SHED_W = 12.0, 2.7, 3.0


def shed_unit():
	"""A 12 x 3 m site shed (a donga), long side along x, door side at +z."""
	p = []
	body = box(SHED_L, SHED_H - 0.15, SHED_W, "shed", bevel=0.04, at=(0, 0.15 + (SHED_H - 0.15) * 0.5, 0))
	# Ribbed wall cladding reads from a distance as darker vertical bands
	body.paint("shed_trim", lambda c: c.y < 0.3)
	p.append(body)
	p.append(box(SHED_L + 0.06, 0.12, SHED_W + 0.06, "shed_roof", bevel=0.02, at=(0, SHED_H - 0.02, 0)))
	# Skid base and corner posts
	for z in (-1.3, 1.3):
		p.append(box(SHED_L, 0.15, 0.15, "dark_steel", at=(0, 0.075, z)))
	for x in (-SHED_L * 0.5 + 0.06, SHED_L * 0.5 - 0.06):
		for z in (-SHED_W * 0.5 + 0.06, SHED_W * 0.5 - 0.06):
			p.append(box(0.14, SHED_H, 0.14, "shed_trim", at=(x, SHED_H * 0.5, z)))
	# Windows both long sides with a sill, the door at +z
	for z, s in ((SHED_W * 0.5 + 0.01, 1), (-SHED_W * 0.5 - 0.01, -1)):
		for x in (-4.3, -1.5, 3.8):
			p.append(box(1.3, 0.9, 0.03, "glass", at=(x, 1.65, z)))
			p.append(box(1.4, 0.06, 0.08, "shed_trim", at=(x, 1.17, z + s * 0.03)))
	p.append(box(0.95, 2.05, 0.04, "shed_trim", at=(1.2, 1.2, SHED_W * 0.5 + 0.02)))
	p.append(box(0.06, 0.06, 0.06, "dark_steel", at=(0.85, 1.2, SHED_W * 0.5 + 0.06)))
	# Split-system air conditioner on the end wall
	p.append(box(0.3, 0.6, 0.8, "white", bevel=0.04, at=(SHED_L * 0.5 + 0.17, 1.0, 0.5)))
	p.append(cylinder(0.22, 0.04, "grille", 14).rot("z", math.pi / 2).move(SHED_L * 0.5 + 0.34, 1.0, 0.5))
	put("ShedUnit", p, smooth=False)


def shed_stair():
	"""The stair tower up to the second shed: two flights to a landing at 2.7
	m, rails round it. Origin at the foot of the tower's centre; the top
	landing reaches out to +z where the upper walkway starts."""
	p = []
	w = 1.0
	# Posts
	for x in (-1.4, 1.4):
		for z in (-0.6, 0.6):
			p.append(box(0.08, 3.8, 0.08, "steel", at=(x, 1.9, z)))
	# Mid landing and top landing
	p.append(box(1.0, 0.06, 1.2, "dark_steel", at=(-0.9, 1.35, 0)))
	p.append(box(1.0, 0.06, 1.2, "dark_steel", at=(0.9, SHED_H, 0)))
	# Two flights of treads: up +x along -z side, back along +z side
	for i in range(8):
		t = i / 8.0
		p.append(box(0.24, 0.04, w * 0.55, "dark_steel", at=(1.2 - t * 2.0, 0.17 + t * 1.18, -0.3)))
		p.append(box(0.24, 0.04, w * 0.55, "dark_steel", at=(-1.2 + t * 2.0, 1.52 + t * 1.18, 0.3)))
	p.append(bar((1.4, 1.0, -0.6), (-0.4, 2.35, -0.6), 0.025, "steel"))
	p.append(bar((-1.4, 2.35, 0.6), (0.4, 3.7, 0.6), 0.025, "steel"))
	p.append(bar((-1.4, 2.4, -0.6), (-1.4, 2.4, 0.6), 0.025, "steel"))
	p.append(bar((1.4, 3.7, -0.6), (1.4, 3.7, 0.6), 0.025, "steel"))
	p.append(bar((0.4, 3.7, -0.6), (1.4, 3.7, -0.6), 0.025, "steel"))
	put("ShedStair", p, smooth=False)


def shed_walkway():
	"""The upper-level walkway along a shed's door side (+z), 12 m."""
	p = [box(SHED_L, 0.06, 1.1, "dark_steel", at=(0, 0, 0.55))]
	for x in [-6 + i * 2.0 for i in range(7)]:
		p.append(box(0.06, 1.05, 0.06, "steel", at=(x, 0.52, 1.07)))
	for y in (0.55, 1.05):
		p.append(bar((-6, y, 1.07), (6, y, 1.07), 0.025, "steel"))
	for x in [-6 + i * 3.0 for i in range(5)]:
		p.append(box(0.08, 0.08, 1.1, "dark_steel", at=(x, -0.06, 0.55)))
	put("ShedWalkway", p, smooth=False)


def porta_loo():
	p = [box(1.12, 2.15, 1.18, "loo", bevel=0.06, at=(0, 1.15, 0))]
	p.append(box(1.12, 0.1, 1.18, "loo", at=(0, 0.05, 0)))
	roof = lathe([(0.0, 2.36), (0.5, 2.3), (0.66, 2.22), (0.66, 2.2), (0.0, 2.2)], 4, "loo_roof", cap_top=True, cap_bottom=True)
	roof.rot("y", math.pi / 4).scale(1.18, 1, 1.24)
	p.append(roof)
	p.append(box(0.86, 1.9, 0.03, "loo", bevel=0.01, at=(0, 1.1, 0.6)))
	p.append(box(0.1, 0.2, 0.05, "grille", at=(0.32, 1.1, 0.63)))
	p.append(box(0.16, 0.05, 0.03, "red", at=(0.32, 1.25, 0.63)))
	p.append(cylinder(0.05, 0.4, "dark_steel", 8, at=(-0.35, 2.3, -0.4)))
	put("PortaLoo", p)


# ---------------------------------------------------------------- fencing

FENCE_W, FENCE_H = 2.4, 2.1


def _fence_frame(p, x0):
	for x in (-FENCE_W * 0.5 + 0.03, FENCE_W * 0.5 - 0.03):
		p.append(bar((x0 + x, 0.1, 0), (x0 + x, FENCE_H, 0), 0.02, "fence"))
	for y in (0.1, FENCE_H):
		p.append(bar((x0 - FENCE_W * 0.5, y, 0), (x0 + FENCE_W * 0.5, y, 0), 0.02, "fence"))


def _fence_feet(p, x0):
	for x in (-FENCE_W * 0.5, FENCE_W * 0.5):
		p.append(box(0.6, 0.12, 0.2, "fence_foot", bevel=0.03, at=(x0 + x, 0.06, 0)))
	p.append(torus(0.04, 0.012, "dark_steel", 8, 4, at=(x0 + FENCE_W * 0.5, 1.6, 0)))


def _mesh_panel(p, x0):
	"""Temporary fence panel: a wire mesh you can see through, on its feet."""
	_fence_frame(p, x0)
	n = 16
	for i in range(1, n):
		x = -FENCE_W * 0.5 + FENCE_W * i / n
		p.append(box(0.008, FENCE_H - 0.1, 0.008, "fence_wire", at=(x0 + x, 0.1 + (FENCE_H - 0.1) * 0.5, 0)))
	for k in range(1, 9):
		y = 0.1 + (FENCE_H - 0.1) * k / 9
		p.append(box(FENCE_W, 0.008, 0.008, "fence_wire", at=(x0, y, 0)))
	_fence_feet(p, x0)


def _cloth_panel(p, x0, banner=False):
	"""The same panel faced with dark shade cloth (the far sides of the site),
	or with a plain banner across it."""
	_fence_frame(p, x0)
	p.append(box(FENCE_W - 0.04, FENCE_H - 0.25, 0.012, "cloth", at=(x0, 0.12 + (FENCE_H - 0.2) * 0.5, 0.03)))
	if banner:
		p.append(box(FENCE_W - 0.2, 0.9, 0.012, "white", at=(x0, 1.3, 0.045)))
		p.append(box(FENCE_W - 0.4, 0.22, 0.012, "sign_blue", at=(x0, 1.45, 0.052)))
		p.append(box(FENCE_W - 0.9, 0.12, 0.012, "grille", at=(x0, 1.1, 0.052)))
	_fence_feet(p, x0)


def fences():
	"""One panel of each, and runs of five (12 m) so a long fence is a few
	meshes, not dozens. A run's origin is its middle."""
	for name, fn in (("FencePanel", _mesh_panel), ("FenceCloth", _cloth_panel),
			("FenceBanner", lambda p, x0: _cloth_panel(p, x0, True))):
		p = []
		fn(p, 0.0)
		put(name, p, smooth=False)
		p = []
		for i in range(5):
			fn(p, (i - 2) * FENCE_W)
		put(name + "Run", p, smooth=False)


def ppe_sign():
	"""The mandatory PPE sign at the gate: blue circles on white, on a post."""
	p = [box(0.9, 0.62, 0.03, "sign", at=(0, 1.75, 0))]
	p.append(box(0.9, 0.14, 0.035, "sign_blue", at=(0, 1.99, 0)))
	for x in (-0.28, 0.0, 0.28):
		p.append(cylinder(0.11, 0.02, "sign_blue", 14).rot("x", math.pi / 2).move(x, 1.68, -0.03))
	p.append(bar((0, 0, -0.03), (0, 1.5, -0.03), 0.03, "steel"))
	p.append(box(0.4, 0.1, 0.3, "fence_foot", bevel=0.02, at=(0, 0.05, -0.03)))
	put("PPESign", p)


# ---------------------------------------------------------------- bins and laydown

def skip_bin():
	"""A 6 m³ marrel skip with builder's rubbish in it; long side along x."""
	p = []
	shell = lathe([(0.0, 0.05), (1.0, 0.05), (1.35, 1.2), (1.35, 1.28), (1.27, 1.28), (0.94, 0.13), (0.0, 0.13)],
		4, "skip", cap_top=False, cap_bottom=True)
	shell.rot("y", math.pi / 4).scale(1.35, 1, 0.68)
	p.append(shell)
	for x in (-1.1, 1.1):
		p.append(box(0.12, 0.18, 1.5, "skip_dark", at=(x, 0.09, 0)))
	for s in (-1, 1):
		p.append(cylinder(0.1, 0.1, "skip_dark", 10).rot("z", math.pi / 2).move(s * 1.85, 1.0, -0.55))
		p.append(cylinder(0.1, 0.1, "skip_dark", 10).rot("z", math.pi / 2).move(s * 1.85, 1.0, 0.55))
	# Rubbish: offcuts, a broken pallet, plastic
	p.append(box(2.3, 0.4, 1.2, "rubbish", at=(0, 0.9, 0)))
	p.append(box(1.4, 0.05, 0.25, "ply", at=(0.4, 1.2, 0.2)).rot("z", 0.25))
	p.append(box(0.1, 0.1, 1.3, "timber", at=(-0.6, 1.18, 0)).rot("y", 0.5))
	p.append(box(0.5, 0.3, 0.4, "white", bevel=0.05, at=(-0.9, 1.15, -0.3)))
	p.append(box(0.9, 0.14, 0.7, "concrete", bevel=0.04, at=(0.9, 1.15, -0.25)))
	put("SkipBin", p)


def wheelie_bin(name, lid):
	p = [box(0.58, 1.0, 0.7, "bin_green", bevel=0.04, at=(0, 0.53, 0))]
	p[0].warp(lambda v: (v.x * (0.9 + 0.1 * v.y), v.y, v.z * (0.9 + 0.1 * v.y)))
	p.append(box(0.62, 0.06, 0.76, lid, bevel=0.02, at=(0, 1.06, 0.01)))
	p.append(bar((-0.28, 1.0, -0.38), (0.28, 1.0, -0.38), 0.02, "grille"))
	for s in (-1, 1):
		p.append(cylinder(0.1, 0.05, "rubber", 10).rot("z", math.pi / 2).move(s * 0.28, 0.1, -0.3))
	put(name, p)


def pallet():
	p = []
	for z in (-0.5, 0.0, 0.5):
		p.append(box(1.2, 0.1, 0.1, "timber", at=(0, 0.05, z)))
	for x in [-0.55 + i * 0.22 for i in range(6)]:
		p.append(box(0.14, 0.02, 1.15, "timber", at=(x, 0.11, 0)))
	put("Pallet", p, smooth=False)


def ply_stack():
	"""Formply on bearers: a stack of 2.4 x 1.2 sheets, a few ends showing."""
	p = []
	for x in (-0.9, 0.0, 0.9):
		p.append(box(0.1, 0.1, 1.25, "timber", at=(x, 0.05, 0)))
	sheet = box(2.4, 0.6, 1.2, "ply", at=(0, 0.4, 0))
	sheet.paint("ply_face", lambda c: c.y > 0.65)
	p.append(sheet)
	for i in range(5):
		p.append(box(2.4, 0.006, 1.205, "timber", at=(0, 0.16 + i * 0.12, 0)))
	p.append(box(2.42, 0.018, 1.22, "ply_face", at=(0.03, 0.71, 0.01)).rot("y", 0.03))
	put("PlyStack", p, smooth=False)


def bar_bundle():
	"""A bundle of 6 m N16 bar on dunnage, wire-tied in three places."""
	p = []
	for x in (-2.2, 0.0, 2.2):
		p.append(box(0.1, 0.1, 0.6, "timber", at=(x, 0.05, 0)))
	k = 0
	for row, n in ((0, 6), (1, 5), (2, 4)):
		for i in range(n):
			z = (i - (n - 1) * 0.5) * 0.036
			y = 0.118 + row * 0.031
			p.append(bar((-3.0 + (k % 3) * 0.04, y, z), (3.0 - (k % 2) * 0.05, y, z), 0.016, "rebar", 4))
			k += 1
	for x in (-1.8, 0.2, 2.1):
		p.append(torus(0.115, 0.01, "tie", 10, 4).rot("z", math.pi / 2).scale(1, 0.62, 1).move(x, 0.15, 0))
	put("BarBundle", p, smooth=False)


def mesh_stack():
	"""Reinforcing mesh sheets (6 x 2.4) stacked on dunnage."""
	p = []
	for x in (-2.0, 0.0, 2.0):
		p.append(box(0.1, 0.1, 2.5, "timber", at=(x, 0.05, 0)))
	for k in range(4):
		y = 0.12 + k * 0.03
		for i in range(13):
			z = -1.2 + i * 0.2
			p.append(box(6.0, 0.01, 0.012, "rebar", at=(0, y, z)))
		for i in range(31):
			x = -3.0 + i * 0.2
			p.append(box(0.012, 0.01, 2.4, "rebar", at=(x, y + 0.012, 0)))
	put("MeshStack", p, smooth=False)


def gas_cage():
	"""Gas bottles chained in a mesh cage with a roof: oxygen and acetylene."""
	p = []
	for x in (-0.75, 0.75):
		for z in (-0.4, 0.4):
			p.append(box(0.05, 1.9, 0.05, "machine_dark", at=(x, 0.95, z)))
	p.append(box(1.6, 0.05, 0.9, "machine_dark", at=(0, 1.92, 0)))
	p.append(box(1.6, 0.05, 0.9, "dark_steel", at=(0, 0.03, 0)))
	for k in range(1, 12):
		x = -0.75 + k * 1.5 / 12
		p.append(box(0.008, 1.85, 0.008, "machine_dark", at=(x, 0.95, 0.4)))
	for y in (0.7, 1.3):
		p.append(box(1.5, 0.03, 0.03, "machine_dark", at=(0, y, 0.4)))
	for i, (x, m) in enumerate(((-0.5, "bottle_ox"), (-0.17, "bottle_ox"), (0.17, "bottle_ac"), (0.5, "bottle_ac"))):
		b = lathe([(0.0, 0.05), (0.11, 0.05), (0.12, 0.1), (0.12, 1.25), (0.08, 1.38), (0.03, 1.42), (0.0, 1.42)], 14, m)
		b.move(x, 0, -0.05)
		p.append(b)
		p.append(cylinder(0.035, 0.08, "steel", 8, at=(x, 1.42, -0.05)))
	p.append(bar((-0.75, 0.95, 0.12), (0.75, 0.95, 0.12), 0.012, "dark_steel", 4))
	p.append(box(0.4, 0.28, 0.02, "red", at=(0, 1.6, 0.43)))
	put("GasCage", p, smooth=False)


def genset():
	"""A hire diesel generator on skids, with its fuel cap and exhaust."""
	p = [box(2.2, 1.35, 1.05, "genset", bevel=0.08, at=(0, 0.83, 0))]
	p[0].paint("grille", lambda c: abs(c.x) > 1.05 and 0.4 < c.y < 1.3)
	p.append(box(2.3, 0.16, 1.1, "dark_steel", bevel=0.03, at=(0, 0.08, 0)))
	for s in (-1, 1):
		p.append(box(1.6, 0.6, 0.02, "grille", at=(0, 0.95, s * 0.53)))
	p.append(cylinder(0.06, 0.3, "dark_steel", 10, at=(0.7, 1.5, -0.3)))
	p.append(box(0.36, 0.26, 0.04, "orange", at=(-0.6, 1.0, 0.55)))
	p.append(box(0.2, 0.08, 0.2, "bin_yellow", bevel=0.02, at=(-0.8, 1.53, 0.3)))
	put("Genset", p)


def light_tower():
	"""A towable lighting tower, mast up, four lamps pointing at the slab (-z)."""
	p = [box(2.6, 0.9, 1.3, "machine", bevel=0.08, at=(0, 0.95, 0))]
	p.append(box(2.8, 0.15, 1.1, "dark_steel", at=(0, 0.45, 0)))
	p.append(bar((1.4, 0.45, 0), (2.4, 0.45, 0), 0.05, "dark_steel"))
	p.append(torus(0.08, 0.025, "dark_steel", 8, 4, at=(2.45, 0.45, 0)))
	for s in (-1, 1):
		p.append(torus(0.25, 0.1, "rubber", 12, 6, at=(0, 0.35, s * 0.72)).rot("x", 0.0))
	for x, z in ((-1.1, -0.85), (-1.1, 0.85), (1.1, -0.85), (1.1, 0.85)):
		p.append(bar((x * 0.6, 0.5, z * 0.5), (x, 0.08, z), 0.04, "machine_dark"))
	# Mast, then the lamp bar on top
	p.append(box(0.18, 7.5, 0.18, "steel", at=(-0.8, 4.6, 0)))
	p.append(box(0.12, 0.12, 2.0, "dark_steel", at=(-0.8, 8.35, 0)))
	for z in (-0.75, -0.25, 0.25, 0.75):
		lamp = box(0.5, 0.4, 0.14, "dark_steel", bevel=0.03, at=(-0.8, 8.6, z))
		lamp.rot("x", 0.0)
		p.append(lamp)
		p.append(box(0.42, 0.32, 0.02, "lamp", at=(-0.8, 8.6, z - 0.075)))
	put("LightTower", p)


def water_tank():
	p = [lathe([(0.0, 0.0), (0.95, 0.0), (1.0, 0.08), (1.0, 1.9), (0.9, 2.05), (0.22, 2.12), (0.0, 2.12)], 24, "tank")]
	for y in (0.5, 1.0, 1.5):
		p.append(torus(1.0, 0.025, "tank", 24, 4, at=(0, y, 0)))
	p.append(cylinder(0.22, 0.1, "dark_steel", 12, at=(0, 2.1, 0)))
	p.append(bar((0, 0.15, 1.0), (0, 0.15, 1.25), 0.035, "dark_steel"))
	p.append(box(0.08, 0.12, 0.12, "red", at=(0, 0.15, 1.28)))
	put("WaterTank", p)


# ---------------------------------------------------------------- safety kit

def extinguisher_stand():
	p = [box(0.5, 0.05, 0.4, "red", at=(0, 0.025, 0))]
	p.append(box(0.04, 1.6, 0.04, "red", at=(0, 0.8, -0.15)))
	p.append(box(0.36, 0.48, 0.02, "sign", at=(0, 1.42, -0.12)))
	p.append(box(0.3, 0.12, 0.022, "red", at=(0, 1.56, -0.11)))
	for x, m in ((-0.12, "red"), (0.12, "sign_blue")):
		ext = lathe([(0.0, 0.06), (0.08, 0.06), (0.085, 0.1), (0.085, 0.62), (0.06, 0.68), (0.0, 0.7)], 12, m)
		ext.move(x, 0, 0)
		p.append(ext)
		p.append(box(0.04, 0.1, 0.12, "grille", at=(x, 0.75, 0)))
		p.append(bar((x, 0.72, 0.04), (x + 0.02, 0.4, 0.1), 0.012, "grille", 4))
	put("ExtinguisherStand", p)


def first_aid():
	p = [box(0.5, 0.4, 0.18, "first_aid", bevel=0.03, at=(0, 0, 0))]
	p.append(box(0.18, 0.06, 0.02, "white", at=(0, 0, 0.095)))
	p.append(box(0.06, 0.18, 0.02, "white", at=(0, 0, 0.095)))
	put("FirstAid", p)


def spill_kit():
	p = [box(0.72, 1.0, 0.72, "bin_yellow", bevel=0.05, at=(0, 0.55, 0))]
	p.append(box(0.76, 0.07, 0.8, "bin_yellow", bevel=0.02, at=(0, 1.08, 0.02)))
	p.append(box(0.5, 0.2, 0.02, "grille", at=(0, 0.75, 0.37)))
	for s in (-1, 1):
		p.append(cylinder(0.1, 0.05, "rubber", 10).rot("z", math.pi / 2).move(s * 0.33, 0.1, -0.3))
	put("SpillKit", p)


def cone():
	p = [box(0.38, 0.04, 0.38, "rubber", bevel=0.01, at=(0, 0.02, 0))]
	prof = [(0.0, 0.04)] + [(0.15 - 0.115 * t / 10.0, 0.04 + 0.66 * t / 10.0) for t in range(11)] + [(0.0, 0.7)]
	p.append(lathe(prof, 14, "cone"))
	p[-1].paint("band", lambda c: 0.3 < c.y < 0.42 or 0.5 < c.y < 0.58)
	put("Cone", p)


def bollard():
	p = [lathe([(0.0, 0.0), (0.2, 0.0), (0.2, 0.06), (0.09, 0.08), (0.075, 1.0), (0.05, 1.06), (0.0, 1.07)], 12, "bin_yellow")]
	p[0].paint("grille", lambda c: 0.78 < c.y < 0.86)
	put("Bollard", p)


def barrier_mesh():
	"""Orange barrier mesh, 4 m between star pickets with safety caps."""
	p = []
	for x in (-2.0, 0.0, 2.0):
		p.append(box(0.04, 1.2, 0.04, "dark_steel", at=(x, 0.6, 0)))
		p.append(sphere(0.05, "bin_yellow", 8, 6, at=(x, 1.22, 0)))
	for y in (0.12, 0.4, 0.7, 0.98):
		p.append(box(4.0, 0.035, 0.01, "barrier", at=(0, y, 0.03)))
	for k in range(21):
		x = -2.0 + k * 0.2
		p.append(box(0.025, 0.9, 0.01, "barrier", at=(x, 0.55, 0.03)))
	put("BarrierMesh", p, smooth=False)


# ---------------------------------------------------------------- crib corner

def crib_table():
	p = [box(1.8, 0.04, 0.75, "table", bevel=0.015, at=(0, 0.73, 0))]
	for x in (-0.8, 0.8):
		p.append(bar((x, 0.71, -0.3), (x, 0.0, 0.3), 0.018, "dark_steel"))
		p.append(bar((x, 0.71, 0.3), (x, 0.0, -0.3), 0.018, "dark_steel"))
	put("CribTable", p)


def crib_chair():
	p = [box(0.46, 0.05, 0.44, "chair", bevel=0.02, at=(0, 0.44, 0))]
	p.append(box(0.46, 0.42, 0.04, "chair", bevel=0.02, at=(0, 0.68, -0.22)).rot("x", -0.12))
	for x in (-0.2, 0.2):
		for z in (-0.18, 0.18):
			p.append(bar((x, 0.42, z), (x * 1.1, 0.0, z * 1.15), 0.016, "chair", 5))
	put("CribChair", p)


def esky():
	p = [box(0.7, 0.4, 0.42, "esky", bevel=0.05, at=(0, 0.22, 0))]
	p[0].paint("white", lambda c: c.y < 0.12)
	p.append(box(0.72, 0.08, 0.44, "white", bevel=0.03, at=(0, 0.45, 0)))
	p.append(bar((-0.2, 0.52, 0), (0.2, 0.52, 0), 0.02, "white"))
	put("Esky", p)


def umbrella():
	p = [bar((0, 0, 0), (0, 2.25, 0), 0.025, "white")]
	p.append(box(0.5, 0.06, 0.5, "dark_steel", at=(0, 0.03, 0)))
	can = lathe([(0.0, 2.3), (1.3, 1.95), (1.3, 1.9), (0.0, 2.25)], 8, "umbrella", cap_top=False, cap_bottom=False)
	can.paint("umbrella_b", lambda c: (math.atan2(c.x, c.z) % (math.pi / 2)) < math.pi / 4)
	p.append(can)
	put("Umbrella", p, smooth=False)


# ---------------------------------------------------------------- washout bay

def washout_bay():
	"""Where the trucks wash their chutes: a bunded pit with slurry in it,
	4.5 x 3 m, the open side (a ramp) at +x."""
	p = [box(4.5, 0.05, 3.0, "concrete", at=(0, 0.025, 0))]
	p.append(box(3.9, 0.02, 2.4, "slurry", at=(-0.1, 0.06, 0)))
	for s in (-1, 1):
		p.append(box(4.5, 0.35, 0.3, "concrete", bevel=0.04, at=(0, 0.17, s * 1.35)))
	p.append(box(0.3, 0.35, 3.0, "concrete", bevel=0.04, at=(-2.1, 0.17, 0)))
	p.append(box(0.4, 0.06, 2.4, "wet_crust", at=(1.95, 0.08, 0)))
	# Crust on the walls, a grate and the drain pipe to the settling tank
	for s in (-1, 1):
		p.append(box(3.6, 0.04, 0.32, "wet_crust", at=(-0.2, 0.36, s * 1.35)))
	p.append(box(0.6, 0.02, 0.6, "grille", at=(-1.5, 0.075, 0.8)))
	p.append(bar((-2.25, 0.15, 0.8), (-2.8, 0.1, 0.8), 0.07, "dark_steel", 8))
	put("WashoutBay", p, smooth=False)


def main():
	reset()
	shed_unit()
	shed_stair()
	shed_walkway()
	porta_loo()
	fences()
	ppe_sign()
	skip_bin()
	wheelie_bin("WheelieBin", "bin_lid")
	wheelie_bin("WheelieBinRecycle", "bin_yellow")
	pallet()
	ply_stack()
	bar_bundle()
	mesh_stack()
	gas_cage()
	genset()
	light_tower()
	water_tank()
	extinguisher_stand()
	first_aid()
	spill_kit()
	cone()
	bollard()
	barrier_mesh()
	crib_table()
	crib_chair()
	esky()
	umbrella()
	washout_bay()
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

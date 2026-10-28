"""The wildlife round Riverlight (assets/wildlife/wildlife.glb): what you'd see
on a weekday morning in the park, on the river and up the gum trees at
Hamilton.

Run:  python tools/blender/wildlife.py

Ground birds, pecking about the grass and the paths:
  BushTurkey     Australian brush-turkey: black, a bare red head, the
                 male's yellow wattle, a tall flat tail
  Ibis           Australian white ibis: white, a bare black head and a long
                 curved bill, black plumes at the tail
  Lapwing        masked lapwing: brown back, white front, yellow face
  Curlew         bush stone-curlew: streaky grey-brown, long legs, big
                 yellow eyes; stands stock still
  Magpie         Australian magpie, black and white
Perched:
  Kookaburra     laughing kookaburra: a big head and bill, brown and cream
Flying:
  Lorikeet       rainbow lorikeet, wings out (WingL, WingR flap)
On the river:
  Pelican        Australian pelican, floating, the big pink bill
Mammals and reptiles:
  Koala          sitting, arms round a trunk (the trunk's on its -z side)
  Possum         common brushtail possum, on all fours
  WaterDragon    eastern water dragon, basking

Each faces +z with its feet (or waterline) at y = 0. Birds have Head, Tail,
LegL, LegR (and WingL, WingR) for the game to move; the others Head and Tail.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import box, build, cylinder, empty, export_glb, lathe, reset, sphere, tri_count, tube  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "wildlife", "wildlife.glb")

PALETTE = {
	"turkey": "1d1d1f", "turkey_brown": "3a2e26", "wattle_red": "d0342c", "wattle_yellow": "f2c14e",
	"leg_grey": "6d6c6e", "ibis": "f1efe8", "ibis_dirty": "d8d2c0", "black": "151515", "lap_brown": "8a6f4e",
	"lap_white": "f4f2ea", "lap_yellow": "f2d23c", "leg_pink": "c98a7a", "curlew": "8d7f6b", "curlew_streak": "5a4d3e",
	"eye_yellow": "f2c94c", "eye": "151515", "magpie_white": "f4f4f2", "kooka_brown": "7a5a3c", "kooka_cream": "efe4cf",
	"kooka_blue": "4f7fb0", "bill_dark": "2e2a26", "bill_pale": "d9c7a0", "lori_green": "3f9a3a", "lori_blue": "3255b0",
	"lori_orange": "f08a24", "lori_red": "d9302c", "pelican": "f6f4ee", "pelican_black": "222222", "bill_pink": "f2b8a8",
	"koala": "8d9196", "koala_light": "e6e2da", "nose": "1d1d1d", "possum": "6d6c6e", "possum_dark": "2a2a2a",
	"possum_pink": "e7a7a0", "dragon": "6f7a5a", "dragon_dark": "3a3f33", "dragon_red": "b8553a",
}


def put(name, pieces, parent=None, at=(0, 0, 0), smooth=True):
	return build(name, pieces, PALETTE, parent, at=at, smooth=smooth)


def eyes(r, x, y, z, mat="eye"):
	return [sphere(r, mat, 6, 4, at=(s * x, y, z)) for s in (-1, 1)]


def bird_legs(root, hip_y, hip_x, z, length, mat, thick=0.012):
	for nm, s in (("LegL", -1), ("LegR", 1)):
		p = empty(nm, (s * hip_x, hip_y, z), root)
		foot = [tube([(0, -length, 0), (0, -length, 0.06)], thick * 0.8, mat, 4),
			tube([(0, -length, 0), (0.03, -length, 0.04)], thick * 0.7, mat, 4),
			tube([(0, -length, 0), (-0.03, -length, 0.04)], thick * 0.7, mat, 4)]
		put(nm + "_Mesh", [tube([(0, 0, 0), (0, -length * 0.5, -0.02), (0, -length, 0)], thick, mat, 5)] + foot, p)


def bush_turkey():
	root = empty("BushTurkey")
	body = sphere(0.2, "turkey", 14, 10, at=(0, 0.42, 0), s=(0.9, 0.85, 1.35))
	wing = [sphere(0.17, "turkey_brown", 10, 6, at=(s * 0.12, 0.45, -0.02), s=(0.35, 0.7, 1.2)) for s in (-1, 1)]
	neck = tube([(0, 0.5, 0.18), (0, 0.6, 0.24)], 0.05, "turkey", 6)
	put("BushTurkey_Body", [body, *wing, neck], root)
	h = empty("Head", (0, 0.62, 0.26), root)
	put("Head_Parts", [sphere(0.05, "wattle_red", 10, 6, s=(0.85, 0.9, 1.1)),
		lathe([(0.0, 0.0), (0.016, 0.0), (0.0, 0.05)], 6, "bill_dark").rot("x", math.pi / 2).move(0, -0.01, 0.04),
		torus_collar(0.045, -0.06), *eyes(0.012, 0.035, 0.015, 0.025)], h)
	t = empty("Tail", (0, 0.5, -0.24), root)
	# the tail: a tall flat fan held upright, side on
	fan = sphere(0.2, "turkey", 12, 8, s=(0.12, 1.0, 0.65)).move(0, 0.06, -0.08)
	put("Tail_Mesh", [fan], t)
	bird_legs(root, 0.27, 0.07, 0.02, 0.27, "leg_grey", 0.016)


def torus_collar(r, y):
	"""The male brush-turkey's yellow wattle hanging at the throat."""
	return sphere(r, "wattle_yellow", 10, 6, at=(0, y, 0.0), s=(1.0, 0.9, 0.8))


def ibis():
	root = empty("Ibis")
	body = sphere(0.17, "ibis", 14, 10, at=(0, 0.45, 0), s=(0.85, 0.85, 1.45))
	dirty = sphere(0.14, "ibis_dirty", 10, 6, at=(0, 0.36, 0.02), s=(0.8, 0.5, 1.3))
	put("Ibis_Body", [body, dirty], root)
	h = empty("Head", (0, 0.52, 0.2), root)
	neck = tube([(0, 0, 0), (0, 0.12, 0.04), (0, 0.2, 0.03)], 0.035, "black", 6)
	skull = sphere(0.045, "black", 10, 6, at=(0, 0.21, 0.04))
	bill = tube([(0, 0.2, 0.08), (0, 0.18, 0.16), (0, 0.13, 0.24), (0, 0.06, 0.28)], lambda u: 0.014 * (1 - 0.6 * u), "black", 5)
	put("Head_Parts", [neck, skull, bill, *eyes(0.009, 0.03, 0.22, 0.06, "lap_white")], h)
	t = empty("Tail", (0, 0.45, -0.22), root)
	plumes = [sphere(0.06, "black", 8, 5, at=(s * 0.03, -0.04, -0.03), s=(0.6, 0.6, 1.4)) for s in (-1, 1)]
	put("Tail_Mesh", [sphere(0.07, "ibis", 8, 5, s=(0.9, 0.6, 1.0)), *plumes], t)
	bird_legs(root, 0.34, 0.05, 0.02, 0.34, "black", 0.012)


def lapwing():
	root = empty("Lapwing")
	body = sphere(0.1, "lap_white", 12, 8, at=(0, 0.24, 0), s=(0.85, 0.85, 1.4))
	back = sphere(0.1, "lap_brown", 12, 8, at=(0, 0.27, -0.01), s=(0.88, 0.6, 1.42))
	put("Lapwing_Body", [body, back], root)
	h = empty("Head", (0, 0.32, 0.1), root)
	put("Head_Parts", [sphere(0.045, "lap_white", 10, 6, at=(0, 0.02, 0.01)),
		sphere(0.047, "black", 10, 6, at=(0, 0.04, 0.0), s=(1.0, 0.6, 1.0)),
		sphere(0.026, "lap_yellow", 8, 5, at=(0, 0.015, 0.035), s=(1.6, 1.3, 0.8)),
		lathe([(0.0, 0.0), (0.01, 0.0), (0.0, 0.035)], 6, "lap_yellow").rot("x", math.pi / 2).move(0, 0.01, 0.06),
		*eyes(0.008, 0.03, 0.025, 0.03)], h)
	t = empty("Tail", (0, 0.26, -0.13), root)
	put("Tail_Mesh", [sphere(0.05, "black", 8, 5, s=(0.7, 0.3, 1.2))], t)
	bird_legs(root, 0.18, 0.03, 0.0, 0.18, "leg_pink", 0.008)


def curlew():
	root = empty("Curlew")
	body = sphere(0.12, "curlew", 12, 8, at=(0, 0.36, 0), s=(0.8, 0.85, 1.6))
	body.paint("curlew_streak", lambda c: math.sin(c.z * 60 + c.y * 20) > 0.6)
	put("Curlew_Body", [body], root)
	h = empty("Head", (0, 0.46, 0.15), root)
	put("Head_Parts", [sphere(0.05, "curlew", 10, 6, s=(0.9, 0.95, 1.05)),
		lathe([(0.0, 0.0), (0.012, 0.0), (0.0, 0.045)], 6, "bill_dark").rot("x", math.pi / 2).move(0, -0.005, 0.05),
		*eyes(0.017, 0.033, 0.012, 0.025, "eye_yellow"), *eyes(0.008, 0.042, 0.012, 0.03)], h)
	t = empty("Tail", (0, 0.36, -0.18), root)
	put("Tail_Mesh", [sphere(0.06, "curlew_streak", 8, 5, s=(0.6, 0.35, 1.4))], t)
	bird_legs(root, 0.28, 0.04, 0.0, 0.28, "eye_yellow", 0.011)


def magpie():
	root = empty("Magpie")
	body = sphere(0.1, "black", 12, 8, at=(0, 0.22, 0), s=(0.85, 0.9, 1.5))
	nape = sphere(0.075, "magpie_white", 10, 6, at=(0, 0.28, 0.06), s=(0.9, 0.8, 1.0))
	wings = [sphere(0.07, "magpie_white", 8, 5, at=(s * 0.075, 0.25, -0.02), s=(0.25, 0.6, 1.3)) for s in (-1, 1)]
	put("Magpie_Body", [body, nape, *wings], root)
	h = empty("Head", (0, 0.31, 0.12), root)
	put("Head_Parts", [sphere(0.05, "black", 10, 6),
		lathe([(0.0, 0.0), (0.014, 0.0), (0.0, 0.06)], 6, "bill_pale").rot("x", math.pi / 2).move(0, -0.005, 0.045),
		*eyes(0.008, 0.032, 0.01, 0.025, "lori_red")], h)
	t = empty("Tail", (0, 0.22, -0.15), root)
	put("Tail_Mesh", [box(0.07, 0.015, 0.14, "black", at=(0, 0, -0.06)), box(0.07, 0.016, 0.04, "magpie_white", at=(0, 0, 0.0))], t)
	bird_legs(root, 0.13, 0.03, 0.0, 0.13, "black", 0.008)


def kookaburra():
	root = empty("Kookaburra")
	body = sphere(0.1, "kooka_cream", 12, 8, at=(0, 0.2, 0), s=(0.9, 1.1, 1.2))
	wings = [sphere(0.09, "kooka_brown", 10, 6, at=(s * 0.07, 0.21, -0.02), s=(0.35, 0.9, 1.3)) for s in (-1, 1)]
	spots = [sphere(0.02, "kooka_blue", 6, 4, at=(s * 0.1, 0.24, 0.02), s=(0.4, 0.8, 1.2)) for s in (-1, 1)]
	put("Kookaburra_Body", [body, *wings, *spots], root)
	h = empty("Head", (0, 0.36, 0.03), root)
	put("Head_Parts", [sphere(0.075, "kooka_cream", 12, 8, s=(1.0, 0.95, 1.05)),
		sphere(0.076, "kooka_brown", 12, 8, at=(0, 0.02, -0.01), s=(1.0, 0.55, 1.05)),
		box(0.16, 0.02, 0.06, "kooka_brown", at=(0, 0.0, 0.0)),
		lathe([(0.0, 0.0), (0.03, 0.0), (0.0, 0.11)], 8, "bill_dark").rot("x", math.pi / 2).move(0, -0.01, 0.06),
		*eyes(0.012, 0.055, 0.01, 0.04)], h)
	t = empty("Tail", (0, 0.14, -0.1), root)
	put("Tail_Mesh", [box(0.06, 0.02, 0.16, "kooka_brown", at=(0, -0.04, -0.06)).rot("x", -0.6)], t)
	bird_legs(root, 0.1, 0.03, 0.03, 0.1, "leg_grey", 0.009)


def lorikeet():
	root = empty("Lorikeet")
	body = sphere(0.06, "lori_green", 10, 6, at=(0, 0, 0), s=(0.8, 0.8, 1.7))
	chest = sphere(0.05, "lori_orange", 8, 5, at=(0, -0.01, 0.04), s=(0.8, 0.8, 1.0))
	put("Lorikeet_Body", [body, chest], root)
	h = empty("Head", (0, 0.02, 0.1), root)
	put("Head_Parts", [sphere(0.035, "lori_blue", 8, 5),
		lathe([(0.0, 0.0), (0.012, 0.0), (0.0, 0.025)], 6, "lori_red").rot("x", math.pi / 2).move(0, -0.005, 0.03)], h)
	for nm, s in (("WingL", -1), ("WingR", 1)):
		w = empty(nm, (s * 0.035, 0.01, 0.0), root)
		put(nm + "_Mesh", [box(0.2, 0.01, 0.07, "lori_green", at=(s * 0.1, 0, 0)), box(0.08, 0.011, 0.05, "lori_blue", at=(s * 0.16, 0, -0.01))], w)
	t = empty("Tail", (0, 0, -0.09), root)
	put("Tail_Mesh", [box(0.04, 0.008, 0.12, "lori_green", at=(0, 0, -0.06))], t)


def pelican():
	root = empty("Pelican")
	body = sphere(0.3, "pelican", 14, 10, at=(0, 0.12, 0), s=(0.85, 0.65, 1.5))
	wings = [sphere(0.25, "pelican_black", 10, 6, at=(s * 0.2, 0.2, -0.15), s=(0.25, 0.5, 1.3)) for s in (-1, 1)]
	put("Pelican_Body", [body, *wings], root)
	h = empty("Head", (0, 0.3, 0.32), root)
	neck = tube([(0, 0, 0), (0, 0.25, 0.02), (0, 0.42, -0.04)], 0.06, "pelican", 8)
	skull = sphere(0.07, "pelican", 10, 6, at=(0, 0.45, -0.02))
	bill = tube([(0, 0.44, 0.03), (0, 0.38, 0.25), (0, 0.32, 0.45)], lambda u: 0.03 * (1 - 0.5 * u), "bill_pink", 6)
	pouch = sphere(0.07, "bill_pink", 8, 5, at=(0, 0.33, 0.22), s=(0.6, 0.7, 2.2))
	put("Head_Parts", [neck, skull, bill, pouch, *eyes(0.012, 0.055, 0.46, 0.01)], h)
	t = empty("Tail", (0, 0.15, -0.42), root)
	put("Tail_Mesh", [sphere(0.1, "pelican", 8, 5, s=(0.9, 0.4, 1.0))], t)


def koala():
	"""Sitting up against a trunk (on its -z side, 0.4 m off), arms round it."""
	root = empty("Koala")
	body = sphere(0.2, "koala", 14, 10, at=(0, 0.25, 0), s=(0.9, 1.25, 0.85))
	belly = sphere(0.15, "koala_light", 10, 6, at=(0, 0.22, 0.07), s=(0.8, 1.2, 0.7))
	arms = [tube([(s * 0.14, 0.38, 0.0), (s * 0.2, 0.36, -0.18), (s * 0.12, 0.34, -0.33)], 0.055, "koala", 6) for s in (-1, 1)]
	legs = [tube([(s * 0.12, 0.08, 0.05), (s * 0.18, 0.05, -0.15), (s * 0.12, 0.02, -0.3)], 0.06, "koala", 6) for s in (-1, 1)]
	put("Koala_Body", [body, belly, *arms, *legs], root)
	h = empty("Head", (0, 0.52, 0.02), root)
	ears = [sphere(0.075, "koala", 8, 5, at=(s * 0.14, 0.07, -0.02), s=(1.0, 1.0, 0.45)) for s in (-1, 1)]
	tufts = [sphere(0.05, "koala_light", 8, 5, at=(s * 0.15, 0.07, 0.01), s=(1.0, 1.0, 0.3)) for s in (-1, 1)]
	put("Head_Parts", [sphere(0.13, "koala", 12, 8, s=(1.05, 0.95, 0.95)), *ears, *tufts,
		sphere(0.04, "nose", 8, 5, at=(0, -0.01, 0.12), s=(0.75, 1.1, 0.7)), *eyes(0.014, 0.055, 0.02, 0.105)], h)


def possum():
	root = empty("Possum")
	body = sphere(0.14, "possum", 12, 8, at=(0, 0.17, 0), s=(0.85, 0.8, 1.5))
	belly = sphere(0.1, "koala_light", 8, 5, at=(0, 0.12, 0.03), s=(0.8, 0.6, 1.3))
	feet = [cylinder(0.025, 0.1, "possum_dark", 6, at=(sx * 0.07, 0, sz)) for sx in (-1, 1) for sz in (0.12, -0.1)]
	put("Possum_Body", [body, belly, *feet], root)
	h = empty("Head", (0, 0.22, 0.2), root)
	ears = [lathe([(0.0, 0.0), (0.03, 0.0), (0.0, 0.07)], 6, "possum").move(s * 0.045, 0.04, -0.01) for s in (-1, 1)]
	put("Head_Parts", [sphere(0.07, "possum", 10, 6, s=(0.9, 0.85, 1.1)),
		lathe([(0.0, 0.0), (0.04, 0.0), (0.0, 0.07)], 8, "possum").rot("x", math.pi / 2).move(0, -0.01, 0.05),
		sphere(0.012, "possum_pink", 6, 4, at=(0, -0.01, 0.12)), *ears, *eyes(0.016, 0.035, 0.015, 0.05)], h)
	t = empty("Tail", (0, 0.18, -0.2), root)
	put("Tail_Mesh", [tube([(0, 0, 0), (0, 0.05, -0.15), (0, 0.02, -0.32), (0, -0.06, -0.42)],
		lambda u: 0.05 * (1 - 0.4 * u), "possum_dark", 8)], t)


def water_dragon():
	root = empty("WaterDragon")
	body = sphere(0.08, "dragon", 10, 6, at=(0, 0.07, 0), s=(0.9, 0.7, 2.2))
	stripe = sphere(0.081, "dragon_dark", 10, 6, at=(0, 0.072, -0.02), s=(0.6, 0.72, 1.6))
	chest = sphere(0.05, "dragon_red", 8, 5, at=(0, 0.05, 0.1), s=(0.9, 0.6, 1.2))
	crest = [box(0.01, 0.03, 0.015, "dragon_dark", at=(0, 0.13 - 0.01 * abs(i), 0.12 - 0.04 * i)) for i in range(6)]
	legs = [tube([(sx * 0.06, 0.06, sz), (sx * 0.13, 0.03, sz + 0.03), (sx * 0.14, 0.0, sz + 0.06)], 0.018, "dragon", 5)
		for sx in (-1, 1) for sz in (0.09, -0.1)]
	put("WaterDragon_Body", [body, stripe, chest, *crest, *legs], root)
	h = empty("Head", (0, 0.1, 0.19), root)
	put("Head_Parts", [sphere(0.045, "dragon", 8, 5, s=(0.9, 0.8, 1.5)), box(0.07, 0.01, 0.04, "dragon_dark", at=(0, 0.005, 0.0)),
		*eyes(0.008, 0.03, 0.012, 0.02)], h)
	t = empty("Tail", (0, 0.06, -0.16), root)
	put("Tail_Mesh", [tube([(0, 0, 0), (0.03, -0.02, -0.2), (-0.03, -0.04, -0.42), (0.02, -0.05, -0.6)],
		lambda u: 0.035 * (1 - 0.85 * u), "dragon", 6)], t)


def main():
	reset()
	bush_turkey()
	ibis()
	lapwing()
	curlew()
	magpie()
	kookaburra()
	lorikeet()
	pelican()
	koala()
	possum()
	water_dragon()
	import bpy
	tot = 0
	for o in bpy.context.scene.objects:
		if o.type == "MESH":
			tot += tri_count([o])
	print("  total %d triangles" % tot)
	export_glb(OUT)
	print("wrote", OUT)


if __name__ == "__main__":
	main()

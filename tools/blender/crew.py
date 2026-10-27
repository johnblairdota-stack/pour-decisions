"""The crew: one modelled body for every player and bot (assets/crew/crew.glb).

Run:  python tools/blender/crew.py   (with `pip install bpy`, or inside Blender)

Keeps the chibi's big-head proportions and the nodes the game animates
(scripts/player.gd and friends): LegL, LegR (swing at the hip), ArmL, ArmR
(pivot at the shoulder, hand 0.46 down), Head (at 1.32) with EyeL and EyeR
(scaled to blink). Dressed like a Queensland concreting crew: long-sleeve
hi-vis shirt with reflective tape, work pants with knee pads, steel caps,
gloves, a full-brim hard hat.

Hidden extras the game turns on (factory.gd):
  Look_*  the named crew's signature looks (roster.gd)
  Kit_*   what each job wears (radio, docket, belly-box remote, earmuffs,
          gumboots, splatter, harness, whistle)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import (G, Piece, arc_points, box, build, cylinder, empty, export_glb, lathe, reset,  # noqa: E402
	sphere, tri_count, tube)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "crew", "crew.glb")

# Preview colours only: the game paints these from factory.gd
PALETTE = {
	"vest": "ff7a1a", "tape": "d8dde2", "pants": "24324f", "kneepad": "3a3f47",
	"belt": "2a2a2a", "steel": "afc0d2", "boot": "8a5a32", "sole": "2b2b2b",
	"gumboot": "eef0f2", "glove": "d9b26b", "skin": "f2c9a0", "hair": "6b4a2b",
	"nose": "f2c9a0", "eye": "151515", "eye_hi": "ffffff", "cheek": "f08a7a", "mouth": "7a3030",
	"hat": "ffc72c", "hat_dark": "e0a800", "hat_rib": "f0b81f", "lens": "10151d", "muff": "ff4d4d",
	"kit_muff": "3d4a2f", "radio": "1d1f22", "remote": "ffc72c", "red": "ff4d4d",
	"harness": "22262b", "docket": "fff4c2", "splat": "a9adb3", "pocket": "e86d14",
}

HIP_Y = 0.44
SHOULDER = (0.36, 0.90)
HEAD_Y = 1.32
HAT_TILT = 0.2
HAT_Y = 0.11         # the hat sits up off the eyes, so the high camera still sees them
TORSO_DEPTH = 0.82

# The shirt, bottom to top: (radius, y)
SHIRT = [(0.0, 0.40), (0.30, 0.40), (0.325, 0.48), (0.335, 0.56), (0.335, 0.60), (0.334, 0.64),
	(0.33, 0.68), (0.325, 0.72), (0.318, 0.76), (0.305, 0.82), (0.29, 0.87), (0.26, 0.92),
	(0.21, 0.96), (0.13, 0.995), (0.0, 1.01)]


def shirt_r(y):
	for (r0, y0), (r1, y1) in zip(SHIRT[1:], SHIRT[2:]):
		if y0 <= y <= y1:
			return r0 + (r1 - r0) * (y - y0) / (y1 - y0)
	return SHIRT[-2][0]


def ang(c):
	"""Angle round the body of a point on the shirt (0 = front)."""
	return math.atan2(c.x, c.z / TORSO_DEPTH)


def on_shirt(a, y, out=0.012):
	"""A point on the shirt's surface at angle a (0 = front) and height y."""
	r = shirt_r(y) + out
	return (math.sin(a) * r, y, math.cos(a) * r * TORSO_DEPTH)


# ---------------------------------------------------------------- body

def torso(root):
	shirt = lathe(SHIRT, 32, "vest", depth=TORSO_DEPTH)
	# Reflective tape: two hoops round the body, and a band up over each
	# shoulder front and back (the usual day/night shirt)
	shirt.paint("tape", lambda c: 0.575 <= c.y <= 0.615 or 0.665 <= c.y <= 0.705)
	shirt.paint("tape", lambda c: c.y > 0.72 and 0.39 < min(abs(ang(c)), math.pi - abs(ang(c))) < 0.59)
	# A chest pocket, left side, in a darker orange
	shirt.paint("pocket", lambda c: -0.24 < c.x < -0.12 and 0.74 < c.y < 0.86 and c.z > 0)
	collar = tube(arc_points((0, 0.965, 0), 0.19, -math.pi, math.pi, 20), 0.035, "vest", closed=True)
	collar.scale(1, 1, TORSO_DEPTH + 0.05)
	hips = lathe([(0.0, 0.30), (0.27, 0.30), (0.305, 0.36), (0.31, 0.44), (0.30, 0.47)], 32, "pants",
		depth=TORSO_DEPTH, cap_top=False)
	belt = lathe([(0.317, 0.43), (0.322, 0.445), (0.322, 0.47), (0.317, 0.485)], 32, "belt",
		depth=TORSO_DEPTH, cap_top=False, cap_bottom=False)
	buckle = box(0.07, 0.05, 0.02, "steel", bevel=0.006, at=(0, 0.457, 0.322 * TORSO_DEPTH + 0.008))
	return build("Torso", [shirt, collar, hips, belt, buckle], PALETTE, root)


def leg(root, side):
	name = "LegL" if side < 0 else "LegR"
	pivot = empty(name, (0.13 * side, HIP_Y, 0), root)
	pant = lathe([(0.0, 0.0), (0.125, 0.0), (0.13, -0.08), (0.125, -0.18), (0.12, -0.26), (0.115, -0.33),
		(0.0, -0.33)], 16, "pants")
	pad = sphere(0.075, "kneepad", 14, 8, at=(0, -0.2, 0.105), s=(1.05, 1.0, 0.45))
	strap = tube(arc_points((0, -0.2, 0), 0.128, -2.3, 2.3, 12), 0.012, "kneepad")
	build(name + "_Pant", [pant, pad, strap], PALETTE, pivot)

	def boot_shape(top, r, mat, cuff):
		# Round at the heel, long at the toe, a chunky sole
		b = lathe([(0.0, -0.44), (r * 0.92, -0.44), (r, -0.425), (r * 1.02, -0.40), (r, -0.36),
			(r * 0.97, top), (0.0, top)], 16, mat)
		b.warp(lambda v: (v.x, v.y, v.z * 1.0 + (max(0.0, v.z) * (0.65 if v.y < -0.36 else 0.15))))
		b.move(0, 0, 0.025)
		b.paint("sole", lambda c: c.y < -0.415)
		parts = [b]
		if cuff:
			parts.append(tube(arc_points((0, top - 0.005, 0.02), r * 0.98, -math.pi, math.pi, 16), 0.018, mat,
				closed=True))
		return parts
	build(name + "_Boot", boot_shape(-0.29, 0.135, "boot", True), PALETTE, pivot)
	gum = boot_shape(-0.13, 0.142, "gumboot", True)
	build("Kit_Gumboot" + name[-1], gum, PALETTE, pivot, hidden=True)
	# Concrete flicked up the shins
	rng = random.Random(7 if side < 0 else 11)
	blobs = []
	for _ in range(11):
		a = rng.uniform(-1.6, 1.6)
		y = rng.uniform(-0.2, -0.04)
		r = 0.128
		blobs.append(sphere(rng.uniform(0.018, 0.035), "splat", 6, 4,
			at=(math.sin(a) * r, y, math.cos(a) * r), s=(1, 1.3, 0.35)).rot("y", a))
	build("Kit_Splatter" + name[-1], blobs, PALETTE, pivot, hidden=True)


def arm(root, side):
	name = "ArmL" if side < 0 else "ArmR"
	pivot = empty(name, (SHOULDER[0] * side, SHOULDER[1], 0), root)
	sleeve = lathe([(0.0, 0.07), (0.05, 0.065), (0.085, 0.04), (0.102, 0.0), (0.098, -0.08), (0.09, -0.2),
		(0.085, -0.3), (0.084, -0.36), (0.0, -0.36)], 16, "vest")
	sleeve.paint("tape", lambda c: -0.30 <= c.y <= -0.255)
	glove_cuff = lathe([(0.0, -0.33), (0.088, -0.33), (0.092, -0.36), (0.088, -0.39), (0.0, -0.39)], 14, "glove")
	hand = sphere(0.092, "glove", 16, 10, at=(0, -0.45, 0.0), s=(0.95, 1.12, 0.85))
	thumb = sphere(0.04, "glove", 10, 6, at=(-0.07 * side, -0.42, 0.045), s=(1, 1.5, 1)).rot("z", 0.4 * side)
	build(name + "_Sleeve", [sleeve, glove_cuff, hand, thumb], PALETTE, pivot)


def head(root):
	h = empty("Head", (0, HEAD_Y, 0), root)
	face = sphere(0.42, "skin", 24, 14, s=(1.0, 0.96, 0.95))
	ears = [sphere(0.07, "skin", 10, 6, at=(0.41 * s, -0.04, -0.02), s=(0.5, 1.0, 0.8)) for s in (-1, 1)]
	nose = sphere(0.045, "nose", 10, 6, at=(0, -0.05, 0.4), s=(1.1, 0.9, 0.8))
	cheeks = [sphere(0.075, "cheek", 12, 6, at=(0.235 * s, -0.11, 0.305), s=(1, 0.75, 0.35))
		for s in (-1, 1)]
	smile = tube(arc_points((0, -0.115, 0.0), 0.075, math.pi * 0.7, math.pi * 1.3, 8, plane="xy"), 0.011,
		"mouth")
	smile.warp(lambda v: (v.x, v.y, math.sqrt(max(0.0, 0.405 ** 2 - v.x ** 2 - (v.y * 1.05) ** 2))))
	brows = []
	for s in (-1, 1):
		b = tube(arc_points((0.14 * s, 0.04, 0), 0.08, -0.55, 0.55, 6, plane="xy"), 0.016, "hair")
		b.warp(lambda v: (v.x, v.y, math.sqrt(max(0.0, 0.425 ** 2 - v.x ** 2 - (v.y * 1.04) ** 2))))
		brows.append(b)
	# Hair under the brim: round the back and sides
	hair = sphere(0.432, "hair", 24, 12, s=(1.0, 0.96, 0.96))
	hair.cull(lambda c: c.z > 0.12 or c.y < -0.17 or c.y > 0.2)
	build("Head_Face", [face, *ears, nose, *cheeks, smile, *brows, hair], PALETTE, h)
	for s, nm in ((-1, "EyeL"), (1, "EyeR")):
		at = (0.14 * s, -0.01, 0.375)
		e = sphere(0.058, "eye", 14, 8, s=(0.9, 1.25, 0.5))
		hi = sphere(0.018, "eye_hi", 8, 4, at=(0.018, 0.03, 0.025))
		build(nm, [e, hi], PALETTE, h, at=at)
	hat(h)
	looks(h)
	return h


def hat(h):
	# A full-brim hard hat: tall dome, three ribs on top, brim all round
	dome = lathe([(0.47, 0.02), (0.475, 0.08), (0.465, 0.16), (0.44, 0.25), (0.39, 0.34), (0.31, 0.42),
		(0.2, 0.475), (0.08, 0.5), (0.0, 0.505)], 28, "hat", depth=1.1, cap_bottom=False)
	ribs = []
	for x in (-0.11, 0.0, 0.11):
		pts = []
		for k in range(13):
			a = -1.25 + 2.5 * k / 12
			r = 0.512 - abs(x) * 0.3
			pts.append((x, 0.03 + math.cos(a) * r * 0.93, math.sin(a) * r * 1.08))
		ribs.append(tube(pts, 0.024 if x == 0 else 0.018, "hat_rib", 8))
	brim = lathe([(0.45, 0.035), (0.5, 0.035), (0.55, 0.01), (0.565, -0.005), (0.552, -0.012), (0.5, 0.012),
		(0.45, 0.012)], 32, "hat_dark", depth=1.0, cap_top=False, cap_bottom=False)
	brim.warp(lambda v: (v.x, v.y - max(0.0, v.z) * 0.03, v.z * 1.06 + 0.02))
	band = lathe([(0.472, 0.02), (0.476, 0.045), (0.472, 0.07)], 28, "hat_dark", depth=1.1,
		cap_top=False, cap_bottom=False)
	# Pushed back a little off the face, so the game's high camera sees eyes
	for pc in (dome, *ribs, brim, band):
		pc.rot("x", -HAT_TILT)
	build("Hat", [dome, *ribs, brim, band], PALETTE, h, at=(0, HAT_Y, 0))


def looks(h):
	m = [sphere(0.06, "hair", 12, 6, at=(0.065 * s, -0.135, 0.395), s=(1.6, 0.6, 0.6)).rot("z", -0.25 * s)
		for s in (-1, 1)]
	build("Look_moustache", m, PALETTE, h, hidden=True)
	# A full beard: a thick roll along the jaw from ear to ear, under the
	# smile, and a moustache over it
	jaw = []
	for k in range(17):
		t = -1.35 + 2.7 * k / 16
		x, y = 0.37 * math.sin(t), -0.06 - 0.25 * math.cos(t)
		z = math.sqrt(max(0.0, 0.41 ** 2 - x * x - y * y)) * 0.95 - 0.03
		jaw.append((x, y, z))
	beard = tube(jaw, lambda u: 0.05 + 0.065 * math.sin(math.pi * u), "hair", 12)
	tache = sphere(0.055, "hair", 12, 6, at=(0, -0.1, 0.41), s=(2.0, 0.6, 0.5))
	build("Look_beard", [beard, tache], PALETTE, h, hidden=True)
	tie = sphere(0.06, "red", 10, 6, at=(0, -0.06, -0.43))
	tail = lathe([(0.0, 0.0), (0.09, -0.04), (0.1, -0.14), (0.075, -0.26), (0.03, -0.34), (0.0, -0.36)], 14,
		"hair")
	tail.rot("x", 0.35).move(0, -0.08, -0.47)
	build("Look_ponytail", [tie, tail], PALETTE, h, hidden=True)
	bun = sphere(0.14, "hair", 16, 10, at=(0, -0.06, -0.44), s=(1, 0.9, 0.9))
	build("Look_bun", [bun], PALETTE, h, hidden=True)
	# Wraparound safety sunnies
	lens = lathe([(0.442, -0.075), (0.448, -0.01), (0.445, 0.05)], 14, "lens", arc=(-0.95, 0.95),
		cap_top=False, cap_bottom=False)
	lens.scale(1, 1, 0.97)
	arms = [tube([(0.36 * s, 0.02, 0.2), (0.43 * s, 0.02, 0.0), (0.42 * s, 0.0, -0.12)], 0.012, "lens")
		for s in (-1, 1)]
	build("Look_sunnies", [lens, *arms], PALETTE, h, hidden=True)
	build("Look_earmuffs", muffs("muff"), PALETTE, h, hidden=True)
	build("Kit_Earmuffs", muffs("kit_muff"), PALETTE, h, hidden=True)


def muffs(mat):
	out = []
	for s in (-1, 1):
		cup = cylinder(0.13, 0.085, mat, 16, bevel=0.03).move(0, -0.0425, 0).rot("z", math.pi / 2).move(0.45 * s, -0.03, 0)
		out.append(cup)
		# The arm up to the hat's side slot
		out.append(tube([(0.47 * s, 0.05, 0), (0.5 * s, 0.13, 0), (0.48 * s, 0.2, 0)], 0.02, "radio"))
	return out


# ---------------------------------------------------------------- job kit

def kits(root, h):
	# Two-way radio on the right hip, aerial up
	radio = box(0.065, 0.12, 0.04, "radio", bevel=0.01)
	aerial = cylinder(0.009, 0.09, "radio", 6, at=(0.018, 0.06, 0))
	knob = cylinder(0.013, 0.02, "red", 8, at=(-0.016, 0.06, 0))
	r = shirt_r(0.52) + 0.03
	for pc in (radio, aerial, knob):
		pc.rot("y", 1.0).move(math.sin(1.0) * r, 0.52, math.cos(1.0) * r * TORSO_DEPTH)
	build("Kit_Radio", [radio, aerial, knob], PALETTE, root, hidden=True)
	# The delivery docket sticking out of the chest pocket
	docket = box(0.085, 0.09, 0.006, "docket", at=(-0.13, 0.86, shirt_r(0.86) * TORSO_DEPTH + 0.004))
	build("Kit_Docket", [docket], PALETTE, root, hidden=True)
	# Boom operator: the belly-box radio remote on a harness
	bx = box(0.34, 0.12, 0.17, "remote", bevel=0.025, at=(0, 0.6, 0.38))
	face = box(0.3, 0.012, 0.13, "radio", at=(0, 0.665, 0.38))
	sticks = []
	for x in (-0.09, 0.09):
		sticks.append(cylinder(0.012, 0.07, "radio", 6, at=(x, 0.665, 0.38)))
		sticks.append(sphere(0.026, "radio", 10, 6, at=(x, 0.74, 0.38)))
	estop = cylinder(0.03, 0.03, "red", 12, bevel=0.01, at=(0, 0.665, 0.42))
	antenna = cylinder(0.01, 0.12, "radio", 6, at=(0.14, 0.66, 0.33))
	straps = []
	for s in (-1, 1):
		pts = [(0.14 * s, 0.62, 0.38)]
		for k in range(9):
			y = 0.66 + 0.3 * k / 8
			pts.append(on_shirt(0.42 * s, y))
		pts += [on_shirt(0.42 * s, 0.97, 0.02), (0.15 * s, 1.0, 0.0), on_shirt(math.pi - 0.42 * s, 0.97, 0.02)]
		for k in range(1, 9):
			pts.append(on_shirt(math.pi - 0.42 * s, 0.96 - 0.3 * k / 8))
		pts.append(on_shirt(math.pi - 0.2 * s, 0.6))
		straps.append(tube(pts, 0.016, "harness", 6))
	build("Kit_BellyBox", [bx, face, *sticks, estop, antenna, *straps], PALETTE, root, hidden=True)
	# Dogman and rigger: full-body harness, lanyard, whistle
	parts = []
	for s in (-1, 1):
		pts = [on_shirt(0.35 * s, 0.47)]
		for k in range(1, 10):
			y = 0.47 + 0.49 * k / 9
			pts.append(on_shirt(0.35 * s, y))
		pts += [on_shirt(0.35 * s, 0.985, 0.03), (0.13 * s, 1.0, 0.0), on_shirt(math.pi - 0.3 * s, 0.97, 0.03)]
		for k in range(1, 10):
			pts.append(on_shirt(math.pi - 0.3 * s, 0.96 - 0.49 * k / 9))
		parts.append(tube(pts, 0.018, "harness", 6))
	parts.append(tube([on_shirt(a, 0.74, 0.03) for a in [-0.45 + 0.9 * k / 6 for k in range(7)]], 0.016,
		"harness", 6))
	ring_pts = [(0.0 + math.sin(a) * 0.04, 0.88 + math.cos(a) * 0.04, -shirt_r(0.88) * TORSO_DEPTH - 0.03)
		for a in [2 * math.pi * k / 10 for k in range(10)]]
	parts.append(tube(ring_pts, 0.008, "steel", 6, closed=True))
	lanyard = [(0, 0.88, -0.3), (0.05, 0.8, -0.34), (0.1, 0.62, -0.33), (0.12, 0.5, -0.31)]
	parts.append(tube(lanyard, 0.02, "remote", 6))
	parts.append(box(0.04, 0.09, 0.03, "steel", bevel=0.01, at=(0.12, 0.46, -0.31)))
	build("Kit_Harness", parts, PALETTE, root, hidden=True)
	cord = [on_shirt(a, 0.96 - 0.14 * abs(math.sin(a / 2)), 0.02) for a in
		[-math.pi + 2 * math.pi * k / 20 for k in range(21)]]
	cord = [c for c in cord if c[2] > -0.1] + [(0.0, 0.72, shirt_r(0.72) * TORSO_DEPTH + 0.02)]
	cord.sort(key=lambda c: c[0])
	whistle = [tube(cord, 0.008, "red", 5),
		box(0.04, 0.03, 0.065, "red", bevel=0.01, at=(0.0, 0.7, shirt_r(0.7) * TORSO_DEPTH + 0.04))]
	build("Kit_Whistle", whistle, PALETTE, root, hidden=True)


def main():
	reset()
	root = None   # (parts at the top, so the game finds LegL, Head ... straight under the model)
	torso(root)
	for s in (-1, 1):
		leg(root, s)
		arm(root, s)
	h = head(root)
	kits(root, h)
	import bpy
	objs = [o for o in bpy.context.scene.objects]
	print("triangles, everything:", tri_count(objs))
	print("triangles, base body:", tri_count([o for o in objs if "hidden" not in o]))
	export_glb(OUT)
	print("wrote", OUT)


if __name__ == "__main__":
	main()

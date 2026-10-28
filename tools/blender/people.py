"""The public round Riverlight (assets/people/people.glb): morning walkers,
joggers, dog walkers, cyclists, people pushing prams, commuters for the
CityCat and the odd sidewalk super watching the pour.

Run:  python tools/blender/people.py

  Person   one chibi body in the crew's proportions (big head, short legs)
           with the same joints the game swings: LegL, LegR (at the hip),
           ArmL, ArmR (at the shoulder), Head (EyeL, EyeR). Civvies, not
           hi-vis: a tee or long sleeves, shorts or long pants, sneakers.
           Hidden extras the game turns on per person (scripts/people.gd):
             Arm*_Long, Leg*_Pants   long sleeves, long pants
             Look_*                  hair, cap, bucket hat, sunnies, beard,
                                     backpack, headphones
             Hold_*                  a takeaway coffee, a phone, a dog lead
  Dog      a medium dog with LegFL/FR/BL/BR, Tail and Head to wag and trot
  Bicycle  a commuter bike with WheelF, WheelR and Cranks to turn
  Pram     a three-wheeler pram

Materials are by role (top, bottoms, shoes, skin, hair, cap ...): the game
gives each person their own colours by those names.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import (arc_points, box, build, cylinder, empty, export_glb, lathe, reset, sphere,  # noqa: E402
	tri_count, tube, torus)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "people", "people.glb")

PALETTE = {
	"top": "4f8fd6", "bottoms": "2f3a4c", "shoes": "f2f2f2", "sole": "3a3a3a", "skin": "e8b48a",
	"hair": "4a3422", "eye": "151515", "eye_hi": "ffffff", "cheek": "f08a7a", "mouth": "7a3030",
	"cap": "d9302c", "lens": "10151d", "pack": "2b2f36", "cup": "f4f1ea", "cup_lid": "3a3d42",
	"phone": "1d1f22", "lead": "d9302c", "dog": "b07a45", "dog_dark": "5a3a22", "nose": "1d1d1d",
	"frame": "1f6f8f", "tyre": "2a2a2a", "rim": "b9bdc0", "seat": "1d1d1d", "steel": "a9b0b5",
	"pram": "34495e", "pram_hood": "4a6278",
}

HIP_Y = 0.44
SHOULDER = (0.33, 0.88)
HEAD_Y = 1.30
DEPTH = 0.8
SHIRT = [(0.0, 0.40), (0.27, 0.40), (0.295, 0.48), (0.305, 0.58), (0.302, 0.68), (0.29, 0.78),
	(0.27, 0.85), (0.235, 0.92), (0.17, 0.97), (0.0, 0.99)]


def put(name, pieces, parent=None, at=(0, 0, 0), hidden=False, smooth=True):
	return build(name, pieces, PALETTE, parent, at=at, smooth=smooth, hidden=hidden)


# ---------------------------------------------------------------- the person

def person():
	root = empty("Person")
	top = lathe(SHIRT, 20, "top", depth=DEPTH)
	hips = lathe([(0.0, 0.30), (0.25, 0.30), (0.285, 0.36), (0.29, 0.44), (0.28, 0.47)], 20, "bottoms",
		depth=DEPTH, cap_top=False)
	put("Torso", [top, hips], root)
	pack = box(0.36, 0.42, 0.16, "pack", bevel=0.05, at=(0, 0.70, -0.30))
	straps = [tube([(0.14 * s, 0.93, 0.05), (0.17 * s, 0.97, -0.12), (0.14 * s, 0.88, -0.25)], 0.022, "pack", 6)
		for s in (-1, 1)]
	put("Look_backpack", [pack, *straps], root, hidden=True)
	for side in (-1, 1):
		leg(root, side)
		arm(root, side)
	head(root)


def leg(root, side):
	name = "LegL" if side < 0 else "LegR"
	pivot = empty(name, (0.12 * side, HIP_Y, 0), root)
	# shorts to the knee and bare shins, or long pants (hidden)
	shorts = lathe([(0.0, 0.0), (0.12, 0.0), (0.125, -0.08), (0.12, -0.17), (0.0, -0.17)], 12, "bottoms")
	shin = lathe([(0.0, -0.17), (0.085, -0.17), (0.08, -0.25), (0.07, -0.33), (0.0, -0.33)], 12, "skin")
	put(name + "_Shorts", [shorts, shin], pivot)
	pants = lathe([(0.0, 0.0), (0.12, 0.0), (0.125, -0.08), (0.115, -0.2), (0.105, -0.33), (0.0, -0.33)], 12,
		"bottoms")
	put(name + "_Pants", [pants], pivot, hidden=True)
	shoe = lathe([(0.0, -0.44), (0.11, -0.44), (0.118, -0.42), (0.115, -0.38), (0.1, -0.33), (0.0, -0.33)], 12,
		"shoes")
	shoe.warp(lambda v: (v.x, v.y, v.z + max(0.0, v.z) * (0.7 if v.y < -0.39 else 0.25) + 0.02))
	shoe.paint("sole", lambda c: c.y < -0.425)
	put(name + "_Shoe", [shoe], pivot)


def arm(root, side):
	name = "ArmL" if side < 0 else "ArmR"
	pivot = empty(name, (SHOULDER[0] * side, SHOULDER[1], 0), root)
	cap = lathe([(0.0, 0.07), (0.05, 0.065), (0.08, 0.04), (0.095, 0.0), (0.09, -0.12), (0.0, -0.12)], 12, "top")
	bare = lathe([(0.0, -0.12), (0.07, -0.12), (0.066, -0.25), (0.06, -0.36), (0.0, -0.36)], 12, "skin")
	hand = sphere(0.08, "skin", 12, 8, at=(0, -0.43, 0), s=(0.9, 1.1, 0.85))
	put(name + "_Short", [cap, bare], pivot)
	put(name + "_Hand", [hand], pivot)
	sleeve = lathe([(0.0, 0.07), (0.05, 0.065), (0.08, 0.04), (0.095, 0.0), (0.088, -0.15), (0.078, -0.36),
		(0.0, -0.36)], 12, "top")
	put(name + "_Long", [sleeve], pivot, hidden=True)
	if side > 0:
		# right hand: a takeaway coffee, or a phone
		cup = lathe([(0.0, 0.0), (0.04, 0.0), (0.05, 0.13), (0.0, 0.13)], 10, "cup")
		lid = cylinder(0.054, 0.02, "cup_lid", 10, at=(0, 0.13, 0))
		for pc in (cup, lid):
			pc.move(0, -0.5, 0.07)
		put("Hold_coffee", [cup, lid], pivot, hidden=True)
		ph = box(0.07, 0.13, 0.012, "phone", bevel=0.008, at=(0, -0.46, 0.09))
		ph.rot("x", -0.5)
		put("Hold_phone", [ph], pivot, hidden=True)
	else:
		# left hand: a dog lead's loop and the first metre of it
		loop = torus(0.045, 0.012, "lead", 10, 4, at=(0, -0.47, 0.03))
		line = tube([(0, -0.47, 0.06), (0.02, -0.55, 0.3), (0.03, -0.6, 0.6)], 0.01, "lead", 4)
		put("Hold_lead", [loop, line], pivot, hidden=True)


def head(root):
	h = empty("Head", (0, HEAD_Y, 0), root)
	face = sphere(0.40, "skin", 20, 12, s=(1.0, 0.96, 0.95))
	ears = [sphere(0.065, "skin", 8, 6, at=(0.39 * s, -0.04, -0.02), s=(0.5, 1.0, 0.8)) for s in (-1, 1)]
	nose = sphere(0.042, "skin", 8, 6, at=(0, -0.05, 0.38), s=(1.1, 0.9, 0.8))
	cheeks = [sphere(0.07, "cheek", 10, 6, at=(0.22 * s, -0.11, 0.29), s=(1, 0.75, 0.35)) for s in (-1, 1)]
	smile = tube(arc_points((0, -0.11, 0.0), 0.07, math.pi * 0.7, math.pi * 1.3, 6, plane="xy"), 0.01, "mouth", 6)
	smile.warp(lambda v: (v.x, v.y, math.sqrt(max(0.0, 0.385 ** 2 - v.x ** 2 - (v.y * 1.05) ** 2))))
	brows = []
	for s in (-1, 1):
		b = tube(arc_points((0.13 * s, 0.05, 0), 0.075, -0.55, 0.55, 5, plane="xy"), 0.015, "hair", 6)
		b.warp(lambda v: (v.x, v.y, math.sqrt(max(0.0, 0.405 ** 2 - v.x ** 2 - (v.y * 1.04) ** 2))))
		brows.append(b)
	put("Head_Face", [face, *ears, nose, *cheeks, smile, *brows], h)
	for s, nm in ((-1, "EyeL"), (1, "EyeR")):
		e = sphere(0.055, "eye", 10, 6, s=(0.9, 1.25, 0.5))
		hi = sphere(0.017, "eye_hi", 6, 4, at=(0.017, 0.03, 0.024))
		put(nm, [e, hi], h, at=(0.13 * s, -0.01, 0.355))
	# short hair: a cap of hair over the top and back
	hair = sphere(0.415, "hair", 20, 12, s=(1.0, 0.98, 0.98)).move(0, 0.02, 0)
	hair.cull(lambda c: (c.z > 0.1 and c.y < 0.27) or (c.z > -0.1 and c.y < 0.0) or c.y < -0.2)
	put("Hair_Short", [hair], h)
	long_hair = lathe([(0.0, -0.5), (0.3, -0.48), (0.4, -0.3), (0.43, -0.1), (0.43, 0.1), (0.38, 0.3), (0.2, 0.42),
		(0.0, 0.44)], 18, "hair", arc=(math.pi * 0.62, math.pi * 1.38))
	put("Look_long", [long_hair], h, hidden=True)
	tail = lathe([(0.0, 0.0), (0.08, -0.04), (0.09, -0.13), (0.06, -0.25), (0.0, -0.3)], 10, "hair")
	tail.rot("x", 0.35).move(0, 0.0, -0.45)
	put("Look_ponytail", [tail], h, hidden=True)
	bun = sphere(0.13, "hair", 12, 8, at=(0, 0.25, -0.33))
	put("Look_bun", [bun], h, hidden=True)
	crown = lathe([(0.41, 0.06), (0.41, 0.14), (0.37, 0.28), (0.25, 0.38), (0.0, 0.42)], 18, "cap",
		cap_bottom=False)
	peak = lathe([(0.3, 0.0), (0.0, 0.0)], 14, "cap", arc=(-0.9, 0.9)).scale(1.05, 1, 1.6).move(0, 0.09, 0.22)
	put("Look_cap", [crown, peak], h, hidden=True)
	bucket = lathe([(0.52, 0.04), (0.44, 0.09), (0.42, 0.26), (0.36, 0.38), (0.0, 0.4)], 18, "cap",
		cap_bottom=False)
	put("Look_bucket", [bucket], h, hidden=True)
	lens = lathe([(0.422, -0.07), (0.428, -0.01), (0.425, 0.05)], 10, "lens", arc=(-0.9, 0.9),
		cap_top=False, cap_bottom=False)
	put("Look_sunnies", [lens], h, hidden=True)
	jaw = []
	for k in range(13):
		t = -1.3 + 2.6 * k / 12
		x, y = 0.35 * math.sin(t), -0.06 - 0.24 * math.cos(t)
		jaw.append((x, y, math.sqrt(max(0.0, 0.39 ** 2 - x * x - y * y)) * 0.95 - 0.03))
	beard = tube(jaw, lambda u: 0.045 + 0.055 * math.sin(math.pi * u), "hair", 8)
	put("Look_beard", [beard], h, hidden=True)
	band = tube(arc_points((0, 0.06, 0), 0.43, -math.pi * 0.55, math.pi * 0.55, 10, plane="xy"), 0.03, "pack", 6)
	cups = [cylinder(0.1, 0.07, "pack", 12).rot("z", math.pi / 2).move(0.43 * s, -0.04, 0) for s in (-1, 1)]
	put("Look_headphones", [band, *cups], h, hidden=True)


# ---------------------------------------------------------------- the dog

def dog():
	"""A medium dog (a kelpie-ish cross), 0.55 m at the shoulder, facing +z."""
	root = empty("Dog")
	body = sphere(0.2, "dog", 14, 10, s=(0.85, 0.9, 2.0)).move(0, 0.5, 0)
	chest = sphere(0.17, "dog", 12, 8, at=(0, 0.52, 0.25), s=(0.9, 1.1, 1.0))
	put("Dog_Body", [body, chest], root)
	h = empty("DogHead", (0, 0.72, 0.42), root)
	skull = sphere(0.14, "dog", 12, 8, s=(0.95, 0.95, 1.05))
	snout = sphere(0.08, "dog", 10, 6, at=(0, -0.04, 0.15), s=(0.85, 0.75, 1.3))
	nose = sphere(0.03, "nose", 8, 4, at=(0, -0.02, 0.25))
	ears = [sphere(0.06, "dog_dark", 8, 4, at=(0.08 * s, 0.12, -0.02), s=(0.5, 1.3, 0.35)).rot("z", -0.3 * s)
		for s in (-1, 1)]
	eyes = [sphere(0.022, "eye", 6, 4, at=(0.065 * s, 0.03, 0.11)) for s in (-1, 1)]
	collar = torus(0.12, 0.015, "lead", 12, 4, at=(0, -0.13, -0.05))
	put("DogHead_Parts", [skull, snout, nose, *ears, *eyes, collar], h)
	for nm, x, z in (("LegFL", -0.09, 0.28), ("LegFR", 0.09, 0.28), ("LegBL", -0.09, -0.26), ("LegBR", 0.09, -0.26)):
		p = empty(nm, (x, 0.45, z), root)
		put(nm + "_Mesh", [lathe([(0.0, 0.0), (0.05, 0.0), (0.04, -0.25), (0.035, -0.42), (0.045, -0.45),
			(0.0, -0.45)], 8, "dog_dark" if z < 0 else "dog")], p)
	t = empty("Tail", (0, 0.58, -0.36), root)
	put("Tail_Mesh", [tube([(0, 0, 0), (0, 0.06, -0.12), (0, 0.04, -0.28)], lambda u: 0.035 * (1 - 0.6 * u), "dog", 6)], t)


# ---------------------------------------------------------------- bike, pram

def bicycle():
	"""A commuter bike, wheels 0.68 across, facing +z; the rider's seat at
	y 0.95, z -0.18, the bars at y 1.0, z 0.42."""
	root = empty("Bicycle")
	R = 0.34
	for nm, z in (("WheelF", 0.52), ("WheelR", -0.52)):
		w = empty(nm, (0, R, z), root)
		tyre = torus(R - 0.02, 0.025, "tyre", 20, 6).rot("z", math.pi / 2)
		hub = cylinder(0.03, 0.08, "rim", 8).rot("z", math.pi / 2).move(0.04, 0, 0)
		spokes = [box(0.008, R * 1.9, 0.008, "rim").rot("x", a) for a in (0, math.pi / 3, 2 * math.pi / 3)]
		put(nm + "_Mesh", [tyre, hub, *spokes], w)
	fr = [
		tube([(0, R, -0.52), (0, 0.42, -0.05), (0, 0.98, -0.2)], 0.022, "frame", 6),   # chain stay up to the seat
		tube([(0, 0.42, -0.05), (0, 0.92, 0.36)], 0.025, "frame", 6),                  # down tube
		tube([(0, 0.92, -0.18), (0, 0.95, 0.36)], 0.022, "frame", 6),                  # top tube
		tube([(0, R, 0.52), (0, 1.0, 0.38)], 0.022, "frame", 6),                       # fork and steerer
		tube([(-0.25, 1.05, 0.36), (0.25, 1.05, 0.36)], 0.016, "steel", 6),            # bars
		box(0.13, 0.05, 0.24, "seat", bevel=0.02, at=(0, 1.0, -0.22)),
		box(0.2, 0.03, 0.35, "steel", at=(0, R + 0.38, -0.45)),                        # rear rack
	]
	put("Bicycle_Frame", fr, root)
	c = empty("Cranks", (0, 0.42, -0.05), root)
	put("Cranks_Mesh", [cylinder(0.09, 0.02, "steel", 12).rot("z", math.pi / 2),
		box(0.02, 0.32, 0.03, "steel"), box(0.09, 0.02, 0.05, "sole", at=(0.08, 0.16, 0)),
		box(0.09, 0.02, 0.05, "sole", at=(-0.08, -0.16, 0))], c)


def pram():
	"""A three-wheeler pram, handle at the back (-z) at 1.0 m."""
	root = empty("Pram")
	parts = [
		lathe([(0.0, 0.42), (0.22, 0.42), (0.26, 0.55), (0.24, 0.68), (0.0, 0.68)], 14, "pram", depth=1.5),
		lathe([(0.27, 0.62), (0.26, 0.8), (0.18, 0.92), (0.0, 0.95)], 14, "pram_hood", depth=1.4,
			arc=(math.pi * 0.55, math.pi * 1.45)).move(0, 0, -0.05),
		tube([(-0.2, 0.15, 0.4), (-0.2, 0.45, 0.0), (-0.2, 1.0, -0.42)], 0.016, "steel", 6),
		tube([(0.2, 0.15, -0.3), (0.2, 0.45, 0.0), (0.2, 1.0, -0.42)], 0.016, "steel", 6),
		tube([(-0.2, 0.15, -0.3), (-0.2, 0.45, 0.0)], 0.016, "steel", 6),
		tube([(-0.22, 1.0, -0.42), (0.22, 1.0, -0.42)], 0.022, "seat", 6),
	]
	for x, z in ((-0.22, -0.3), (0.22, -0.3), (0.0, 0.42)):
		parts.append(torus(0.13, 0.03, "tyre", 14, 4).rot("z", math.pi / 2).move(x, 0.15, z))
	put("Pram_Body", parts, root)


def main():
	reset()
	person()
	dog()
	bicycle()
	pram()
	import bpy
	objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
	print("  person, as walking:", tri_count([o for o in objs if o.name in
		("Torso", "LegL_Shorts", "LegR_Shorts", "LegL_Shoe", "LegR_Shoe", "ArmL_Short", "ArmR_Short", "ArmL_Hand",
		"ArmR_Hand", "Head_Face", "EyeL", "EyeR", "Hair_Short")]))
	print("  everything:", tri_count(objs))
	export_glb(OUT)
	print("wrote", OUT)


if __name__ == "__main__":
	main()

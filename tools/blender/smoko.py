"""Smoko: the coffee van at the Angora Rd gate and what the screeder brings
back up on climb days (assets/props/smoko.glb).

Run:  python tools/blender/smoko.py

  CoffeeVan      a high-roof one-box van turned coffee van, parked with its
                 serving hatch open on its left (kerb) side, +x: the hatch
                 flap propped up as a shade with a striped valance, a fold-down
                 counter, the espresso machine and cups inside, a roof sign
                 and an A-frame menu board on the footpath. Origin on the road
                 under the middle of the van, front to +z. About 5.0 x 1.9 x
                 2.6 m.
  CardboardTray  a moulded-pulp four-cup carry tray, origin under its middle
  CoffeeCup      a takeaway cup with its sleeve and sip lid, 95 mm tall,
                 origin at its base
  Pie            a meat pie in its foil tray with a squiggle of sauce, origin
                 at its base
  SausageRoll    a sausage roll on a paper napkin, along x, origin at its base

Materials are named by role; factory.gd's PROP_COLORS paints them.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import (arc_points, box, build, cylinder, export_glb, extrude, lathe, reset, sphere,  # noqa: E402
	tri_count, torus, tube)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "props", "smoko.glb")

# Preview colours only: the game paints these from factory.gd (PROP_COLORS)
PALETTE = {
	"van": "f2efe6", "van_stripe": "5a3a26", "van_trim": "2b2e33", "glass": "5b7fa8", "tyre": "1d1f23",
	"rim": "c9d1d8", "light": "fff4c2", "tail": "e5383b", "awning_a": "f4f7fa", "awning_b": "c8402e",
	"van_inside": "3a2a20", "counter": "b98a55", "steel": "afc0d2", "grip": "22262b", "menu": "26302b",
	"chalk": "eef0e8", "timber": "b98a55", "cup": "f6f4ee", "sleeve": "9a6a42", "lid": "f6f4ee",
	"pulp": "b9ad94", "foil": "c9d1d8", "pastry": "c98d45", "pastry_dark": "b87a32", "sauce": "c8241c",
	"sausage": "b86a4e", "paper": "f4f7fa", "sign": "f4f7fa", "coffee": "5a3a26",
}


def put(name, pieces, smooth=False):
	return build(name, pieces, PALETTE, None, smooth=smooth)


def rod(r, h, mat, segs=10, bevel=0.0):
	"""A cylinder centred on the origin, upright (kit's sits on y = 0)."""
	return cylinder(r, h, mat, segs, bevel=bevel).move(0, -h / 2, 0)


# ---------------------------------------------------------------- the van

L, W, HT = 5.0, 1.9, 2.42     # long (z), wide (x), roof height
FRONT, BACK = 2.45, -2.5
WR = 0.33                     # wheel radius


def van():
	pc = []
	# The body: its side profile (z, y) run across the width, then a rounded
	# roof cap on top so the silhouette isn't a brick
	prof = [(BACK, 0.38), (BACK, HT - 0.12), (1.35, HT - 0.12), (2.05, 1.32), (2.32, 1.12), (FRONT, 0.86),
		(FRONT, 0.38)]
	body = extrude(prof, -W / 2, W / 2, "van")
	pc.append(body)
	pc.append(box(W - 0.06, 0.16, 3.9, "van", bevel=0.07, at=(0, HT - 0.06, -0.55)))
	# Bumpers, and a dark sill along the bottom
	pc.append(box(W + 0.04, 0.18, 0.14, "van_trim", bevel=0.04, at=(0, 0.47, FRONT + 0.03)))
	pc.append(box(W + 0.04, 0.18, 0.14, "van_trim", bevel=0.04, at=(0, 0.47, BACK - 0.03)))
	for sx in (-1, 1):
		pc.append(box(0.03, 0.12, 4.6, "van_trim", at=(sx * (W / 2 + 0.01), 0.42, -0.05)))
	# Brown stripe round the waist, under the hatch
	for sx in (-1, 1):
		pc.append(box(0.012, 0.1, 4.7, "van_stripe", at=(sx * (W / 2 + 0.006), 0.92, -0.12)))
	# Windscreen and the cab's side windows
	ws = extrude([(1.4, HT - 0.2), (2.0, 1.38), (2.04, 1.36), (1.44, HT - 0.18)], -W / 2 + 0.1, W / 2 - 0.1, "glass")
	ws.move(0, 0, 0.012)
	pc.append(ws)
	for sx in (-1, 1):
		win = extrude([(0.75, 1.4), (1.85, 1.4), (1.42, 2.1), (0.75, 2.1)], 0, 0.012, "glass")
		win.move(sx * (W / 2) + (0.0 if sx > 0 else -0.012), 0, 0)
		pc.append(win)
		# door shut lines and handle
		pc.append(box(0.012, 1.25, 0.02, "van_trim", at=(sx * (W / 2 + 0.003), 1.05, 0.72)))
		pc.append(box(0.03, 0.03, 0.14, "van_trim", bevel=0.01, at=(sx * (W / 2 + 0.01), 1.22, 0.85)))
		# mirror
		pc.append(box(0.04, 0.2, 0.12, "van_trim", bevel=0.02, at=(sx * (W / 2 + 0.16), 1.55, 1.75)))
		pc.append(box(0.16, 0.03, 0.03, "van_trim", at=(sx * (W / 2 + 0.07), 1.5, 1.78)))
	# Lights
	for sx in (-1, 1):
		pc.append(box(0.32, 0.14, 0.03, "light", bevel=0.02, at=(sx * 0.66, 0.93, FRONT + 0.0)))
		pc.append(box(0.12, 0.42, 0.03, "tail", bevel=0.015, at=(sx * 0.85, 1.2, BACK - 0.005)))
	pc.append(box(0.9, 0.12, 0.02, "van_trim", bevel=0.01, at=(0, 0.72, FRONT + 0.005)))
	# Back doors: the shut line and a window each
	pc.append(box(0.02, 1.7, 0.012, "van_trim", at=(0, 1.3, BACK - 0.004)))
	for sx in (-1, 1):
		pc.append(box(0.7, 0.45, 0.012, "glass", at=(sx * 0.42, 1.85, BACK - 0.006)))
	# Wheels: tyre, rim and hub nut, set into dark arches
	for z in (1.55, -1.55):
		for sx in (-1, 1):
			x = sx * (W / 2 - 0.12)
			pc.append(rod(WR, 0.22, "tyre", 20, bevel=0.05).rot("z", math.pi / 2).move(x, WR, z))
			pc.append(rod(0.2, 0.226, "rim", 14).rot("z", math.pi / 2).move(x, WR, z))
			pc.append(rod(0.06, 0.24, "van_trim", 8).rot("z", math.pi / 2).move(x, WR, z))
			arch = tube(arc_points((0, 0, 0), WR + 0.06, 0.0, math.pi, 12, plane="xy"), 0.035, "van_trim", 6)
			arch.rot("y", math.pi / 2).move(sx * (W / 2 + 0.01), WR, z)
			pc.append(arch)
	pc += hatch()
	pc += roof_sign()
	return pc


# The hatch on the left (+x): opening along z, its sill and lintel heights
HZ0, HZ1, HY0, HY1 = -1.75, 0.45, 1.08, 2.05


def hatch():
	pc = []
	x = W / 2
	zc = (HZ0 + HZ1) / 2
	hl = HZ1 - HZ0
	# The dark inside, seen through the opening, and its frame
	pc.append(box(0.02, HY1 - HY0, hl, "van_inside", at=(x - 0.005, (HY0 + HY1) / 2, zc)))
	for y in (HY0, HY1):
		pc.append(box(0.05, 0.05, hl + 0.05, "van_trim", bevel=0.015, at=(x + 0.01, y, zc)))
	for z in (HZ0, HZ1):
		pc.append(box(0.05, HY1 - HY0, 0.05, "van_trim", bevel=0.015, at=(x + 0.01, (HY0 + HY1) / 2, z)))
	# The flap, hinged at the top and propped out flat-ish as a shade: white
	# outside, with red and white stripes on its valance
	out = 0.95
	flap = box(out, 0.05, hl + 0.04, "van", bevel=0.02, at=(x + out / 2, 0, zc))
	flap.move(0, HY1 + 0.07, 0)
	pc.append(flap)
	n = 10
	for k in range(n):
		z0 = HZ0 + hl * k / n
		pc.append(box(0.02, 0.2, hl / n, "awning_a" if k % 2 == 0 else "awning_b",
			at=(x + out + 0.01, HY1 - 0.02, z0 + hl / n / 2)))
		# (a scalloped edge: a little tongue under each stripe)
		pc.append(box(0.02, 0.06, hl / n * 0.7, "awning_a" if k % 2 == 0 else "awning_b", bevel=0.008,
			at=(x + out + 0.01, HY1 - 0.14, z0 + hl / n / 2)))
	# Gas struts holding it
	for z in (HZ0 + 0.1, HZ1 - 0.1):
		pc.append(tube([(x + 0.02, HY0 + 0.45, z), (x + out * 0.6, HY1 + 0.05, z)], 0.012, "steel", 6))
	# The fold-down counter on its brackets
	pc.append(box(0.34, 0.04, hl - 0.1, "counter", bevel=0.012, at=(x + 0.17, HY0 - 0.02, zc)))
	for z in (HZ0 + 0.2, HZ1 - 0.2):
		pc.append(tube([(x, HY0 - 0.28, z), (x + 0.3, HY0 - 0.04, z)], 0.012, "steel", 6))
	# Inside: the espresso machine (two group heads), the grinder, a stack of
	# cups and the cups on the counter waiting for a name to be called
	mx = x - 0.32
	pc.append(box(0.42, 0.42, 0.75, "steel", bevel=0.03, at=(mx, HY0 + 0.25, zc - 0.35)))
	pc.append(box(0.44, 0.06, 0.78, "van_trim", bevel=0.02, at=(mx, HY0 + 0.48, zc - 0.35)))
	for dz in (-0.18, 0.18):
		pc.append(rod(0.04, 0.06, "grip", 10).move(mx + 0.24, HY0 + 0.2, zc - 0.35 + dz))
		pc.append(box(0.18, 0.025, 0.025, "grip", bevel=0.008, at=(mx + 0.33, HY0 + 0.17, zc - 0.35 + dz)))
	pc.append(rod(0.008, 0.18, "steel", 6).rot("z", 0.4).move(mx + 0.26, HY0 + 0.32, zc - 0.62))
	g = (mx + 0.05, HY0, zc + 0.35)
	pc.append(box(0.18, 0.3, 0.2, "grip", bevel=0.03, at=(g[0], g[1] + 0.15, g[2])))
	pc.append(lathe([(0.0, 0.0), (0.05, 0.0), (0.09, 0.16), (0.0, 0.16)], 10, "glass").move(g[0], g[1] + 0.3, g[2]))
	for k in range(6):
		pc.append(lathe([(0.03, 0.0), (0.042, 0.095), (0.0, 0.095)], 10, "cup", cap_bottom=False).move(
			mx + 0.12, HY0 + 0.02 + k * 0.03, zc + 0.75))
	for k, dz in enumerate((-0.55, -0.4, 0.05)):
		pc += cup_pieces(at=(x + 0.12 + (k % 2) * 0.08, HY0, zc + dz))
	return pc


def roof_sign():
	# A board on the roof, both sides: a big coffee cup with steam (the game
	# can hang a name on it with a Label3D)
	pc = []
	y = HT + 0.05
	pc.append(box(0.06, 0.1, 0.1, "van_trim", at=(0, y + 0.03, -1.4)))
	pc.append(box(0.06, 0.1, 0.1, "van_trim", at=(0, y + 0.03, 0.6)))
	pc.append(box(0.08, 0.5, 2.4, "sign", bevel=0.04, at=(0, y + 0.33, -0.4)))
	for sx in (-1, 1):
		x = sx * 0.045
		pc.append(box(0.012, 0.42, 2.32, "van_stripe", at=(x, y + 0.33, -0.4)))
		pc.append(box(0.014, 0.36, 2.26, "sign", at=(x * 1.05, y + 0.33, -0.4)))
		# the cup, the handle and the steam
		cup = extrude([(-1.45, y + 0.16), (-1.15, y + 0.16), (-1.11, y + 0.42), (-1.49, y + 0.42)], 0, 0.012,
			"coffee")
		cup.move(x * 1.12 - (0.012 if sx < 0 else 0.0), 0, 0.0)
		pc.append(cup)
		handle = tube(arc_points((0, 0, 0), 0.07, -math.pi / 2, math.pi / 2, 8, plane="xy"), 0.014, "coffee", 5)
		handle.rot("y", -math.pi / 2).move(x * 1.12, y + 0.3, -1.1)
		pc.append(handle)
		for k in range(2):
			z = -1.36 + k * 0.12
			steam = tube([(x * 1.12, y + 0.46, z), (x * 1.12, y + 0.5, z + 0.03), (x * 1.12, y + 0.54, z - 0.02)],
				0.008, "coffee", 4)
			pc.append(steam)
		# chalky stripes standing in for the lettering
		for k, w in enumerate((1.3, 1.0)):
			pc.append(box(0.016, 0.05, w, "van_stripe", at=(x * 1.12, y + 0.4 - k * 0.13, -0.2 - (1.3 - w) / 2)))
	return pc


def menu_board():
	# An A-frame chalkboard on the footpath by the hatch
	pc = []
	at = (W / 2 + 1.25, 0, 0.9)
	for s in (-1, 1):
		board = []
		board.append(box(0.62, 0.9, 0.035, "timber", bevel=0.012, at=(0, 0.45, 0)))
		board.append(box(0.54, 0.8, 0.012, "menu", at=(0, 0.47, 0.02)))
		board.append(box(0.36, 0.06, 0.012, "chalk", at=(0, 0.78, 0.028)))
		for k in range(5):
			w = (0.42, 0.34, 0.4, 0.3, 0.38)[k]
			board.append(box(w, 0.025, 0.01, "chalk", at=(-0.02 + (0.42 - w) * -0.3, 0.66 - k * 0.09, 0.028)))
			board.append(box(0.06, 0.025, 0.01, "chalk", at=(0.21, 0.66 - k * 0.09, 0.028)))
		# a chalk cup at the bottom
		board.append(box(0.08, 0.07, 0.01, "chalk", at=(0, 0.17, 0.028)))
		# (each board hinges at its top, so the pair stands as an A)
		for p in board:
			p.move(0, -0.9, 0).rot("x", -0.2).move(0, 0.9, 0)
			if s < 0:
				p.rot("y", math.pi)
			pc.append(p)
	for p in pc:
		p.rot("y", math.pi / 2).move(*at)
	hinge = rod(0.012, 0.6, "steel", 6).rot("z", math.pi / 2).rot("y", math.pi / 2).move(at[0], 0.88, at[2])
	return pc + [hinge]


# ---------------------------------------------------------------- the smoko run

def cup_pieces(at=(0, 0, 0), s=1.0):
	"""A takeaway cup: 95 mm tall, base at `at`."""
	x, y, z = at
	pc = [lathe([(0.0, 0.0), (0.028, 0.0), (0.04, 0.088), (0.0, 0.088)], 16, "cup", cap_top=False)]
	pc.append(lathe([(0.0315, 0.022), (0.038, 0.07), (0.0395, 0.07), (0.033, 0.022)], 16, "sleeve",
		cap_top=False, cap_bottom=False, loop=True))
	pc.append(lathe([(0.0, 0.088), (0.043, 0.088), (0.043, 0.094), (0.032, 0.1), (0.0, 0.1)], 16, "lid",
		cap_bottom=True))
	pc.append(box(0.012, 0.004, 0.006, "grip", at=(0.025, 0.1, 0)))
	for p in pc:
		p.scale(s, s, s).move(x, y, z)
	return pc


def tray():
	# Moulded pulp: a flat base with four round wells and a ridge in the middle
	pc = [box(0.23, 0.012, 0.23, "pulp", bevel=0.005, at=(0, 0.006, 0))]
	for x in (-0.055, 0.055):
		for z in (-0.055, 0.055):
			pc.append(lathe([(0.042, 0.0), (0.05, 0.05), (0.054, 0.05), (0.047, 0.0)], 16, "pulp",
				cap_top=True, cap_bottom=False, loop=True).move(x, 0.0, z))
	pc.append(box(0.025, 0.07, 0.15, "pulp", bevel=0.01, at=(0, 0.04, 0)))
	pc.append(box(0.15, 0.07, 0.025, "pulp", bevel=0.01, at=(0, 0.04, 0)))
	return pc


def pie():
	pc = [lathe([(0.0, 0.0), (0.052, 0.0), (0.064, 0.03), (0.07, 0.032), (0.07, 0.034), (0.0, 0.034)], 20, "foil")]
	# the pastry lid: domed, with a crimped rim and a steam slit
	pc.append(lathe([(0.0, 0.052), (0.03, 0.05), (0.058, 0.04), (0.066, 0.034)], 20, "pastry", cap_bottom=False))
	for k in range(16):
		a = 2 * math.pi * k / 16
		pc.append(sphere(0.008, "pastry_dark", 6, 4, at=(math.cos(a) * 0.063, 0.036, math.sin(a) * 0.063)))
	pc.append(box(0.02, 0.003, 0.004, "pastry_dark", at=(0, 0.053, 0)))
	# a squiggle of sauce on top
	pts = [(-0.03 + k * 0.006, 0.055, 0.012 * math.sin(k * 1.2)) for k in range(11)]
	pc.append(tube(pts, 0.0055, "sauce", 6))
	return pc


def sausage_roll():
	pc = [box(0.18, 0.003, 0.14, "paper", at=(0, 0.0015, 0)).rot("y", 0.2)]
	roll = rod(0.026, 0.13, "pastry", 14).rot("z", math.pi / 2).scale(1, 0.85, 1).move(0, 0.025, 0)
	pc.append(roll)
	for sx in (-1, 1):
		pc.append(rod(0.016, 0.004, "sausage", 10).rot("z", math.pi / 2).move(sx * 0.066, 0.024, 0))
		pc.append(torus(0.02, 0.006, "pastry_dark", 12, 5).rot("z", math.pi / 2).move(sx * 0.064, 0.025, 0))
	# the flaky scored top
	for k in range(4):
		pc.append(box(0.005, 0.003, 0.03, "pastry_dark").rot("y", 0.6).move(-0.045 + k * 0.03, 0.0465, 0))
	return pc


def main():
	reset()
	put("CoffeeVan", van() + menu_board())
	put("CardboardTray", tray())
	put("CoffeeCup", cup_pieces())
	put("Pie", pie())
	put("SausageRoll", sausage_roll())
	import bpy
	for o in bpy.context.scene.objects:
		if o.type == "MESH":
			print("  %-14s %5d triangles" % (o.name, tri_count([o])))
	export_glb(OUT)
	print("wrote", OUT)


if __name__ == "__main__":
	main()

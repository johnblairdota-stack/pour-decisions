"""Site Cash: the money the crew earn for the work (assets/props/cash.glb).

Run:  python tools/blender/cash.py [--preview DIR]

  cash_bill       one banknote, 0.30 x 0.15 m, standing up facing +z (and
                  printed the same on the back). A made-up note, not a copy of
                  a real one: a tower crane on the right, a hard hat in the
                  clear window on the left, guilloche-ish bands, and a plain
                  centre panel where the game prints the amount (a Label3D,
                  scripts/cash_art.gd). Its paper is "bill", tinted per
                  denomination; the panel, window and ink keep their colours.
  cash_stack      a wad of notes lying flat with a rubber band round it
  wallet_closed   a brown leather bifold, notes poking out of the top
  wallet_open     the same laid open: cards in the slots, notes in the back

Materials are named by role; scripts/cash_art.gd paints them.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import box, build, cylinder, export_glb, reset, rounded_rect, tri_count, tube  # noqa: E402
from kit import Piece  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "props", "cash.glb")

PALETTE = {
	"bill": "3f9a6a", "bill_panel": "f4efe0", "bill_window": "dcecf2", "bill_ink": "203046",
	"bill_foil": "e8c45a", "band": "c8402e", "leather": "6b4228", "leather_dark": "4a2c1a",
	"stitch": "e2c9a0", "card_a": "2f6fd6", "card_b": "e8a33a", "card_c": "1d1f24", "card_d": "3fb58a",
	"lining": "2b2f36",
}

W, H, T = 0.30, 0.15, 0.003


def put(name, pieces):
	return build(name, pieces, PALETTE, None, smooth=False)


def slab(outline, z0, z1, mat):
	"""A flat shape [(x, y)] in the xy plane, z0 to z1 thick."""
	p = Piece(mat)
	bm = p.bm
	a = [bm.verts.new((x, y, z0)) for x, y in outline]
	b = [bm.verts.new((x, y, z1)) for x, y in outline]
	n = len(outline)
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((a[i], a[j], b[j], b[i]))
	bm.faces.new(list(reversed(a)))
	bm.faces.new(b)
	return p


def rect(x0, y0, x1, y1):
	return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


# ------------------------------------------------------------------ the note

def _face(side):
	"""What's printed on one face (side +1 the front, -1 the back), as thin
	slabs just proud of the paper."""
	z0 = side * T / 2
	z1 = side * (T / 2 + 0.0006)
	lo, hi = min(z0, z1), max(z0, z1)
	hi2 = max(z0, side * (T / 2 + 0.0012)) if side > 0 else z0
	lo2 = min(z0, side * (T / 2 + 0.0012)) if side < 0 else z0
	p = []
	# the centre panel for the amount
	p.append(slab(rounded_rect(0.15, 0.088, 0.012, 3, 0.005, 0.0), lo, hi, "bill_panel"))
	# an ink frame round the edge, and a thinner one inside it
	for inset, th in ((0.008, 0.003), (0.014, 0.0012)):
		x0, x1 = -W / 2 + inset, W / 2 - inset
		y0, y1 = -H / 2 + inset, H / 2 - inset
		for a, b in (((x0, y0), (x1, y0 + th)), ((x0, y1 - th), (x1, y1)), ((x0, y0), (x0 + th, y1)),
				((x1 - th, y0), (x1, y1))):
			p.append(slab(rect(a[0], a[1], b[0], b[1]), lo, hi, "bill_ink"))
	# wavy security lines across the ends (a polyline of thin slabs)
	for k in range(5):
		y = -0.045 + k * 0.0225
		pts = [(0.09 + i * 0.0045, y + math.sin(i * 0.9 + k) * 0.004) for i in range(11)]
		p.append(tube([(x, yy, side * (T / 2 + 0.0004)) for x, yy in pts], 0.0006, "bill_ink", 3))
	# the clear window on the left with a hard hat in it
	p.append(slab(rounded_rect(0.042, 0.07, 0.01, 3, -0.112, 0.0), lo2 if side < 0 else z0, hi2 if side > 0 else z0,
		"bill_window"))
	hat = [(-0.112 + math.cos(math.radians(a)) * 0.013, -0.004 + math.sin(math.radians(a)) * 0.013)
		for a in range(0, 181, 20)]
	p.append(slab(hat, min(z0, side * (T / 2 + 0.0018)), max(z0, side * (T / 2 + 0.0018)), "bill_foil"))
	p.append(slab(rect(-0.131, -0.007, -0.093, -0.003), min(z0, side * (T / 2 + 0.0018)),
		max(z0, side * (T / 2 + 0.0018)), "bill_foil"))
	# a tower crane on the right: the mast, jib, counter jib, the hook line
	cx = 0.118
	for a, b in (((cx - 0.003, -0.05), (cx + 0.003, 0.03)), ((cx - 0.03, 0.03), (cx + 0.016, 0.034)),
			((cx - 0.002, 0.034), (cx + 0.002, 0.044)), ((cx - 0.024, 0.0), (cx - 0.0225, 0.03)),
			((cx - 0.029, -0.008), (cx - 0.018, 0.0))):
		p.append(slab(rect(a[0], a[1], b[0], b[1]), lo, hi, "bill_ink"))
	# corner rosettes
	for sx in (-1, 1):
		for sy in (-1, 1):
			if sx < 0:
				continue
			ring = [(sx * 0.122 + math.cos(2 * math.pi * i / 10) * 0.0055, sy * 0.055 + math.sin(2 * math.pi * i / 10) * 0.0055)
				for i in range(10)]
			p.append(slab(ring, min(z0, side * (T / 2 + 0.0009)), max(z0, side * (T / 2 + 0.0009)), "bill_foil"))
	if side < 0:
		# (the back reads the right way round from behind)
		for pc in p:
			pc.scale(-1, 1, 1)
	return p


def note():
	p = [slab(rounded_rect(W, H, 0.006, 2), -T / 2, T / 2, "bill")]
	return p + _face(1) + _face(-1)


def lie_flat(pieces, x=0.0, y=0.0, z=0.0, yaw=0.0):
	for pc in pieces:
		pc.rot("x", -math.pi / 2).rot("y", yaw).move(x, y, z)
	return pieces


def stack():
	p = []
	n = 7
	for i in range(n):
		# (only the top one's printing shows)
		plain = [slab(rounded_rect(W, H, 0.006, 2), -T / 2, T / 2, "bill")]
		p += lie_flat(note() if i == n - 1 else plain, 0.0, T / 2 + i * (T + 0.0004), 0.0,
			math.radians((i * 37) % 9 - 4))
	top = n * (T + 0.0004) + 0.002
	# the rubber band, a flat loop round the middle
	hz = H / 2 + 0.003
	ring = [(0.0, -0.002, -hz), (0.0, top + 0.001, -hz), (0.0, top + 0.002, 0.0), (0.0, top + 0.001, hz),
		(0.0, -0.002, hz), (0.0, -0.003, 0.0)]
	p.append(tube([(x + 0.03, y, z) for x, y, z in ring], 0.0035, "band", 5, closed=True))
	return p


# ------------------------------------------------------------------ wallet

WL, WH, WT = 0.115, 0.092, 0.009      # one leaf: width, height, thickness


def leaf(x0, x1, z0, z1):
	return [box(abs(x1 - x0), WH, abs(z1 - z0), "leather", bevel=0.0004, at=((x0 + x1) / 2, 0.0, (z0 + z1) / 2))]


def _stitch(x0, x1, y0, y1, z):
	pts = [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]
	return tube(pts, 0.0007, "stitch", 3, closed=True)


def wallet_closed():
	p = []
	# two leaves folded together, the fold on the left (-x)
	p += leaf(-WL / 2, WL / 2, -WT, 0.0)
	p += leaf(-WL / 2, WL / 2, 0.0005, WT + 0.0005)
	p.append(cylinder(WT * 0.55, WH - 0.004, "leather_dark", 10, at=(-WL / 2 + 0.002, -(WH - 0.004) / 2, 0.0005)))
	for z in (WT + 0.0006, -WT - 0.0001):
		p.append(_stitch(-WL / 2 + 0.006, WL / 2 - 0.004, -WH / 2 + 0.004, WH / 2 - 0.004, z))
	# notes poking out of the top
	for i, (dx, dy) in enumerate(((0.004, 0.012), (-0.006, 0.007))):
		pc = box(WL - 0.02, 0.03, 0.0008, "bill", at=(dx, WH / 2 - 0.015 + dy, 0.0004 - i * 0.0015))
		p.append(pc)
	# a corner of a card at the side
	p.append(box(0.012, 0.05, 0.0009, "card_a", at=(WL / 2 - 0.002, 0.012, 0.0002)))
	return p


def wallet_open():
	p = []
	# laid open, a slight V, inside up (+y here is "up the page": the wallet
	# lies in the xy plane facing +z like the note)
	ang = math.radians(8)
	for side in (-1, 1):
		lf = box(WL, WH, WT * 0.6, "leather", bevel=0.0003, at=(side * WL / 2, 0.0, -WT * 0.3))
		lf.rot("y", side * ang)
		p.append(lf)
		inner = box(WL - 0.008, WH - 0.008, 0.0008, "lining", at=(side * WL / 2, 0.0, 0.0005))
		inner.rot("y", side * ang)
		p.append(inner)
		st = _stitch(side * 0.004, side * (WL - 0.004), -WH / 2 + 0.004, WH / 2 - 0.004, 0.0012)
		st.rot("y", side * ang)
		p.append(st)
	# the spine
	p.append(cylinder(0.006, WH - 0.002, "leather_dark", 10, at=(0.0, -(WH - 0.002) / 2, -0.004)))
	# cards in three stepped slots on the left leaf
	for i, m in enumerate(("card_a", "card_b", "card_c")):
		y = 0.026 - i * 0.022
		c = box(0.085, 0.054, 0.0009, m, at=(-WL / 2 - 0.002, y + 0.008, 0.0016 + i * 0.0005))
		c.rot("y", -ang)
		p.append(c)
		pk = box(0.1, 0.03, 0.0012, "leather", at=(-WL / 2, y - 0.012, 0.0026 + i * 0.0005))
		pk.rot("y", -ang)
		p.append(pk)
	# notes in the back, peeking over the right leaf's pocket
	for i in range(3):
		n = box(WL - 0.012, 0.07, 0.0008, "bill", at=(WL / 2, 0.012 + i * 0.006, 0.0018 + i * 0.0006))
		n.rot("y", ang)
		p.append(n)
	pk = box(WL - 0.004, 0.05, 0.0014, "leather", at=(WL / 2, -0.02, 0.0042))
	pk.rot("y", ang)
	p.append(pk)
	return p


# ------------------------------------------------------------------ main

def main():
	reset()
	made = [put("cash_bill", note()), put("cash_stack", stack()), put("wallet_closed", wallet_closed()),
		put("wallet_open", wallet_open())]
	for o in made:
		print("  %-14s %6d triangles" % (o.name, tri_count([o])))
	if "--preview" in sys.argv:
		_preview(sys.argv[sys.argv.index("--preview") + 1])
	export_glb(OUT)
	print("wrote", OUT)


def _preview(out_dir):
	import bpy
	from kit import preview
	os.makedirs(out_dir, exist_ok=True)
	spots = {"cash_bill": (-0.3, 0.12, 0.0), "cash_stack": (0.05, 0.0, 0.08), "wallet_closed": (0.3, 0.06, 0.0),
		"wallet_open": (0.0, 0.1, -0.15)}
	from kit import G
	for o in bpy.context.scene.objects:
		if o.name in spots:
			o.location = G(*spots[o.name])
	preview(os.path.join(out_dir, "cash.png"), [("front", 0, 8), ("high", 25, 40), ("back", 180, 8)],
		show=lambda o: o.name in spots or o.type != "MESH", target=(0, 0.06, 0), dist=1.1, samples=16)
	for o in bpy.context.scene.objects:
		if o.name in spots:
			o.location = G(0, 0, 0)


if __name__ == "__main__":
	main()

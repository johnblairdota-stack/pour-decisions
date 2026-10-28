"""Trees and planting round Riverlight (assets/nature/trees.glb): what grows
along the river at Hamilton and Northshore. Moreton Bay figs, jacarandas (in
flower, late October, with the purple carpet under them), poincianas, spotted
gums, paperbarks, river she-oaks, cabbage and foxtail palms, pandanus by the
water, grey mangroves on the bank, and bottlebrush and lomandra in the beds.

Run:  python tools/blender/trees.py

Each species is one mesh (one object, a material slot per part) with its
origin at the foot of the trunk, so the game can draw thousands of them as
multimeshes (scripts/flora.gd). Every species has a `<Name>Far` stand-in of a
few dozen triangles for the ones out past the park.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import bmesh, Piece, build, cylinder, export_glb, lathe, reset, tri_count, tube  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "nature", "trees.glb")

PALETTE = {
	"bark": "6f5d4b", "bark_dark": "54473b", "fig_bark": "8d877b", "fig": "3f6f38", "fig_dark": "335d2f",
	"jacaranda": "9b83d6", "jacaranda_leaf": "5f8a48", "jacaranda_fallen": "9d80d2",
	"poinciana": "6c9e45", "poinciana_red": "e04a2c",
	"gum_bark": "ddd6c6", "gum_patch": "a8a69a", "gum_leaf": "71895a",
	"paperbark": "e6dcc5", "paperbark_leaf": "5e7d4c", "tuckeroo": "4f7a3c",
	"sheoak": "5f7352", "palm_trunk": "8a7a63", "palm": "5f8f3e", "palm_dead": "a68d5f",
	"palm_grey": "b9b4a8", "crownshaft": "86a650", "foxtail": "5a9440",
	"pandanus": "6b8f48", "pandanus_fruit": "e08a3a", "mangrove": "5b7550", "pneumato": "6e6455",
	"bottlebrush_leaf": "4e6f3e", "bottlebrush_red": "d0342c", "lomandra": "7e9c4e",
}

UP = (0.0, 1.0, 0.0)


def put(name, pieces):
	return build(name, pieces, PALETTE, None, smooth=True)


# ---------------------------------------------------------------- helpers

def add(a, b, k=1.0):
	return (a[0] + b[0] * k, a[1] + b[1] * k, a[2] + b[2] * k)


def norm(v):
	ln = math.sqrt(v[0] ** 2 + v[1] ** 2 + v[2] ** 2) or 1.0
	return (v[0] / ln, v[1] / ln, v[2] / ln)


def cross(a, b):
	return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def clump(r, mat, at, s=(1, 1, 1), rng=None, sub=2, jitter=0.16):
	"""A lump of foliage: a jittered icosphere (the toon light bands it)."""
	p = Piece(mat)
	bmesh.ops.create_icosphere(p.bm, subdivisions=sub, radius=r)
	if rng is not None and jitter > 0:
		for v in p.bm.verts:
			v.co *= 1.0 + rng.uniform(-jitter, jitter)
	p.scale(*s)
	return p.move(*at)


def limb(a, b, r0, r1, mat="bark", lift=0.0, segs=6, steps=4):
	"""A tapering branch from `a` to `b`, bowed upwards by `lift` m."""
	pts = []
	for i in range(steps + 1):
		t = i / steps
		pts.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t + math.sin(math.pi * t) * lift,
			a[2] + (b[2] - a[2]) * t))
	return tube(pts, lambda t: r0 + (r1 - r0) * t, mat, segs)


def ring_pts(n, radius, y, rng, a0=0.0, dr=0.0, dy=0.0):
	out = []
	for i in range(n):
		a = a0 + 2 * math.pi * i / n + rng.uniform(-0.25, 0.25)
		rr = radius + rng.uniform(-dr, dr)
		out.append((math.sin(a) * rr, y + rng.uniform(-dy, dy), math.cos(a) * rr))
	return out


def blade(base, d, length, width, mat, droop=0.4, steps=3):
	"""A strap leaf (palm leaflet, pandanus, lomandra): a strip from `base`
	out along `d`, drooping, tapering to a point."""
	d = norm(d)
	side = norm(cross(d, UP)) if abs(d[1]) < 0.95 else (1.0, 0.0, 0.0)
	p = Piece(mat)
	bm = p.bm
	rows = []
	for i in range(steps + 1):
		t = i / steps
		c = add(add(base, d, length * t), (0, -droop * t * t, 0))
		w = width * (1.0 - t) * (0.6 + 0.4 * math.sin(math.pi * min(1.0, t + 0.3)))
		if i == steps:
			rows.append([bm.verts.new(c)])
		else:
			rows.append([bm.verts.new(add(c, side, -w)), bm.verts.new(add(c, side, w))])
	for i in range(steps):
		a, b = rows[i], rows[i + 1]
		if len(b) == 1:
			bm.faces.new((a[0], a[1], b[0]))
		else:
			bm.faces.new((a[0], a[1], b[1], b[0]))
	return p


def disc(r, y, mat, rng, segs=14, wobble=0.25):
	"""A thin ragged disc on the ground (fallen flowers)."""
	p = cylinder(r, 0.02, mat, segs=segs, at=(0, y, 0))
	for v in p.bm.verts:
		a = math.atan2(v.co.x, v.co.z)
		k = 1.0 + wobble * math.sin(a * 3 + 1.3) * 0.6 + wobble * math.sin(a * 5 + 0.4) * 0.4
		v.co.x *= k
		v.co.z *= k
	return p


def trunk(profile, mat, segs=8, lean=(0.0, 0.0), flute=0.0, flute_to=2.0):
	"""An upright trunk from a lathe profile, leaning (x, z per metre up),
	with buttress flutes at the foot."""
	p = lathe(profile, segs, mat)

	def w(co):
		a = math.atan2(co.x, co.z)
		k = 1.0
		if flute > 0 and co.y < flute_to:
			k += flute * (1.0 - co.y / flute_to) * max(0.0, math.sin(a * 5))
		return (co.x * k + lean[0] * co.y, co.y, co.z * k + lean[1] * co.y)
	return p.warp(w)


def far(name, trunk_h, trunk_r, crowns, trunk_mat="bark"):
	"""The stand-in for out past the park: a post and a lump or two."""
	rng = random.Random(name)
	p = [cylinder(trunk_r, trunk_h, trunk_mat, segs=5)]
	for at, r, s, mat in crowns:
		p.append(clump(r, mat, at, s, rng, sub=2, jitter=0.1))
	return put(name, p)


# ---------------------------------------------------------------- the big shade trees

def fig():
	"""Moreton Bay fig: buttressed grey trunk, great spreading limbs, a dark
	dome 20 m across. The old ones line the river at Hamilton."""
	rng = random.Random(1)
	p = [trunk([(1.5, 0), (1.05, 0.7), (0.85, 1.8), (0.78, 3.4), (0.7, 4.8)], "fig_bark", 14, flute=0.45, flute_to=2.2)]
	ends = ring_pts(6, 6.2, 8.0, rng, 0.3, 0.8, 0.6)
	for e in ends:
		p.append(limb((e[0] * 0.08, 4.4, e[2] * 0.08), e, 0.42, 0.16, "fig_bark", lift=0.9))
	# Aerial roots hanging off the limbs
	for e in ends[::2]:
		top = (e[0] * 0.55, 6.6, e[2] * 0.55)
		p.append(tube([top, add(top, (0.1, -2.2, 0.05)), add(top, (0.05, -3.6, 0.1))], 0.05, "fig_bark", 4, cap=False))
	p.append(clump(4.4, "fig", (0, 10.6, 0), (1.25, 0.72, 1.25), rng))
	for i, e in enumerate(ring_pts(7, 6.4, 9.0, rng, 0.0, 0.6, 0.5)):
		p.append(clump(rng.uniform(3.2, 3.9), "fig_dark" if i % 2 else "fig", e, (1.0, 0.68, 1.0), rng))
	for e in ring_pts(3, 3.2, 11.8, rng, 0.9, 0.4, 0.3):
		p.append(clump(rng.uniform(2.6, 3.1), "fig", e, (1.0, 0.75, 1.0), rng))
	put("Fig", p)
	far("FigFar", 5.5, 0.9, [((0, 9.6, 0), 1.0, (9.5, 5.4, 9.5), "fig")], "fig_bark")


def jacaranda():
	"""Jacaranda in full flower (Brisbane's late October), lilac over a few
	green leaves, the fallen flowers a purple ring on the grass."""
	rng = random.Random(2)
	p = [limb((0, 0, 0), (0.35, 3.0, 0.1), 0.3, 0.22, "bark_dark", segs=8, steps=3)]
	ends = ring_pts(4, 3.0, 6.0, rng, 0.4, 0.5, 0.5)
	for e in ends:
		p.append(limb((0.35, 2.9, 0.1), e, 0.18, 0.07, "bark_dark", lift=0.4))
	p.append(clump(2.6, "jacaranda", (0.2, 8.2, 0), (1.15, 0.6, 1.15), rng))
	for i, e in enumerate(ring_pts(7, 3.2, 7.1, rng, 0.0, 0.5, 0.5)):
		p.append(clump(rng.uniform(1.9, 2.4), "jacaranda_leaf" if i in (2, 5) else "jacaranda", e, (1.0, 0.62, 1.0), rng))
	p.append(disc(4.6, 0.05, "jacaranda_fallen", rng))
	put("Jacaranda", p)
	far("JacarandaFar", 4.0, 0.3, [((0, 7.4, 0), 1.0, (4.6, 2.8, 4.6), "jacaranda")], "bark_dark")


def poinciana(bloom):
	"""Poinciana: a short trunk, limbs out flat and an umbrella of fern-green
	13 m wide; the early ones already flecked scarlet."""
	rng = random.Random(3)
	p = [trunk([(0.5, 0), (0.4, 0.6), (0.36, 2.4)], "bark", 10, lean=(0.08, 0.0), flute=0.2, flute_to=0.8)]
	top = (0.2, 2.3, 0.0)
	for e in ring_pts(5, 5.0, 4.1, rng, 0.2, 0.6, 0.3):
		p.append(limb(top, e, 0.22, 0.08, "bark", lift=0.6))
	cs = [(0.2, 5.9, 0)] + ring_pts(5, 2.6, 5.4, rng, 0.5, 0.4, 0.2) + ring_pts(7, 5.0, 4.7, rng, 0.0, 0.5, 0.2)
	for i, c in enumerate(cs):
		red = bloom and i % 3 != 1
		p.append(clump(rng.uniform(2.2, 2.7), "poinciana_red" if red else "poinciana", c, (1.15, 0.52, 1.15), rng))
	name = "PoincianaBloom" if bloom else "Poinciana"
	put(name, p)
	far(name + "Far", 2.6, 0.32, [((0, 5.0, 0), 1.0, (6.4, 1.8, 6.4), "poinciana_red" if bloom else "poinciana")])


def gum():
	"""Spotted gum: tall, pale and patched, the crown thin and high."""
	rng = random.Random(4)
	t = trunk([(0.5, 0), (0.42, 0.8), (0.36, 6.0), (0.26, 12.5)], "gum_bark", 9)
	t.warp(lambda co: (co.x + 0.45 * math.sin(co.y / 5.0), co.y, co.z + 0.2 * math.sin(co.y / 3.5)))
	t.paint("gum_patch", lambda c: (math.sin(c.y * 3.1 + c.x * 7) + math.sin(c.z * 6 - c.y * 1.7)) > 0.9)
	p = [t]
	top = (0.45 * math.sin(12.0 / 5.0), 12.0, 0.2 * math.sin(12.0 / 3.5))
	ends = ring_pts(4, 3.0, 16.0, rng, 0.1, 0.8, 1.0)
	for e in ends:
		p.append(limb(top, e, 0.18, 0.07, "gum_bark", lift=0.5))
	p.append(limb((0.35, 8.5, 0.05), (2.6, 11.5, -0.6), 0.14, 0.05, "gum_bark", lift=0.4))
	for e in ends + [(2.6, 12.4, -0.6), (top[0], 18.6, top[2])]:
		p.append(clump(rng.uniform(1.7, 2.3), "gum_leaf", add(e, (0, 0.8, 0)), (1.0, 0.62, 1.0), rng, jitter=0.24))
	for e in ring_pts(3, 1.6, 17.6, rng, 0.8, 0.3, 0.5):
		p.append(clump(rng.uniform(1.4, 1.8), "gum_leaf", e, (1.0, 0.6, 1.0), rng, jitter=0.24))
	put("Gum", p)
	far("GumFar", 13.0, 0.4, [((0, 16.6, 0), 1.0, (3.6, 2.6, 3.6), "gum_leaf")], "gum_bark")


def paperbark():
	"""Broad-leaved paperbark (melaleuca): cream papery stems, two or three of
	them, and a narrow weeping crown. Thick along the creeks and the golf
	course."""
	rng = random.Random(5)
	p = []
	for lean, h in (((0.06, 0.02), 7.5), ((-0.08, 0.05), 6.2), ((0.02, -0.09), 5.4)):
		t = trunk([(0.26, 0), (0.22, 0.5), (0.19, h * 0.6), (0.13, h)], "paperbark", 8, lean=lean)
		t.warp(lambda co: (co.x + 0.12 * math.sin(co.y * 1.3), co.y, co.z + 0.1 * math.sin(co.y * 0.9 + 1)))
		p.append(t)
	for i, y in enumerate((5.0, 6.6, 8.2, 9.6)):
		for e in ring_pts(2 if i < 3 else 1, 1.0 if i < 3 else 0.0, y, rng, i * 0.9, 0.3, 0.3):
			p.append(clump(rng.uniform(1.5, 2.0) * (1.0 - i * 0.12), "paperbark_leaf", add(e, (0.3, 0, 0.1)), (0.9, 1.25, 0.9), rng))
	put("Paperbark", p)
	far("PaperbarkFar", 5.5, 0.25, [((0.3, 7.4, 0.1), 1.0, (2.4, 3.6, 2.4), "paperbark_leaf")], "paperbark")


def tuckeroo():
	"""Tuckeroo: the council's street tree, a short trunk and a tight round
	crown of glossy leaves."""
	rng = random.Random(6)
	p = [trunk([(0.2, 0), (0.17, 0.4), (0.15, 2.2)], "bark", 8)]
	for e in ring_pts(3, 0.9, 2.4, rng, 0.0, 0.2, 0.2):
		p.append(limb((0, 1.9, 0), e, 0.1, 0.05, "bark", lift=0.2))
	p.append(clump(2.5, "tuckeroo", (0, 4.3, 0), (1.0, 0.82, 1.0), rng, sub=3, jitter=0.08))
	for e in ring_pts(4, 1.9, 3.8, rng, 0.4, 0.2, 0.4):
		p.append(clump(rng.uniform(1.3, 1.6), "tuckeroo", e, (1.0, 0.85, 1.0), rng))
	put("Tuckeroo", p)
	far("TuckerooFar", 2.4, 0.16, [((0, 4.2, 0), 1.0, (2.9, 2.3, 2.9), "tuckeroo")])


def sheoak():
	"""River she-oak (casuarina): dark furrowed trunk, a drooping grey-green
	crown like a loose cone. Along the river bank."""
	rng = random.Random(7)
	p = [trunk([(0.3, 0), (0.24, 0.5), (0.2, 5.0), (0.1, 10.0)], "bark_dark", 8, lean=(0.04, -0.03))]
	for i, (y, r) in enumerate(((4.6, 2.3), (6.4, 2.0), (8.2, 1.6), (9.8, 1.15), (11.0, 0.7))):
		off = ring_pts(1, 0.35, y, rng, i * 1.7)[0]
		p.append(clump(r, "sheoak", add(off, (0.04 * y, 0, -0.03 * y)), (1.0, 1.15, 1.0), rng, jitter=0.22))
	for e in ring_pts(3, 1.8, 5.6, rng, 0.5, 0.3, 0.6):
		p.append(clump(1.2, "sheoak", e, (1.0, 1.3, 1.0), rng, jitter=0.22))
	put("SheOak", p)
	far("SheOakFar", 5.0, 0.25, [((0.2, 6.8, 0), 1.0, (2.3, 4.4, 2.3), "sheoak")], "bark_dark")


# ---------------------------------------------------------------- palms and the river edge

def cabbage_palm():
	"""Cabbage tree palm (livistona): a tall thin ringed trunk, a ball of
	round fan fronds and a skirt of dead ones."""
	rng = random.Random(8)
	h = 12.5
	prof = []
	for i in range(13):
		y = h * i / 12
		prof.append((0.24 - 0.05 * i / 12 + (0.025 if i % 2 else 0.0), y))
	p = [trunk(prof, "palm_trunk", 7)]
	top = (0.0, h, 0.0)
	n = 15
	for i in range(n):
		yaw = 2 * math.pi * i / n + rng.uniform(-0.2, 0.2)
		pitch = rng.uniform(-0.35, 0.75)        # radians above level
		f = (math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
		stem_end = add(top, f, 1.4)
		p.append(tube([top, add(add(top, f, 0.7), (0, 0.1, 0)), stem_end], 0.035, "palm", 3, cap=False))
		# The fan: leaflets splayed from the stem's end, cupped
		side = norm(cross(f, UP))
		for k in range(7):
			t = -1.3 + 2.6 * k / 6
			d = add(add((0, 0, 0), f, math.cos(t)), side, math.sin(t))
			p.append(blade(stem_end, add(d, (0, 0.25, 0)), 1.25, 0.16, "palm", droop=0.35, steps=2))
	for i in range(6):
		yaw = 2 * math.pi * i / 6 + 0.3
		d = (math.sin(yaw) * 0.35, -1.0, math.cos(yaw) * 0.35)
		p.append(blade(add(top, (0, -0.2, 0)), d, 1.7, 0.35, "palm_dead", droop=0.0, steps=2))
	put("CabbagePalm", p)
	far("CabbagePalmFar", h, 0.2, [((0, h + 0.3, 0), 1.0, (2.4, 1.5, 2.4), "palm")], "palm_trunk")


def foxtail_palm():
	"""Foxtail palm: the smooth grey trunk and green crownshaft every 2010s
	apartment garden in Brisbane has, fronds arching like a bottlebrush."""
	rng = random.Random(9)
	h = 7.0
	p = [trunk([(0.24, 0), (0.2, 0.4), (0.25, h * 0.45), (0.19, h)], "palm_grey", 9)]
	p.append(cylinder(0.2, 1.3, "crownshaft", segs=9, at=(0, h - 0.02, 0)))
	top = (0.0, h + 1.25, 0.0)
	for i in range(9):
		yaw = 2 * math.pi * i / 9 + rng.uniform(-0.15, 0.15)
		up = rng.uniform(0.5, 1.1)
		f = (math.sin(yaw), 0, math.cos(yaw))
		spine = []
		for k in range(6):
			t = k / 5
			spine.append(add(add(top, f, 2.8 * t), (0, up * 1.6 * math.sin(math.pi * t * 0.75) - 1.6 * t * t, 0)))
		p.append(tube(spine, 0.03, "foxtail", 3, cap=False))
		# Leaflets all round the rachis (that's the foxtail)
		for k in range(1, 6):
			a, b = spine[k - 1], spine[k]
			d = norm((b[0] - a[0], b[1] - a[1], b[2] - a[2]))
			side = norm(cross(d, UP))
			for sgn in (-1, 1):
				for lift in (-0.5, 0.35):
					out = norm(add(add((0, 0, 0), side, sgn), (0, lift, 0)))
					p.append(blade(a, add(out, d, 0.6), 0.95 * (1.0 - k * 0.12), 0.13, "foxtail", droop=0.2, steps=1))
	put("FoxtailPalm", p)
	far("FoxtailPalmFar", h + 1.2, 0.2, [((0, h + 1.6, 0), 1.0, (2.5, 1.3, 2.5), "foxtail")], "palm_grey")


def pandanus():
	"""Pandanus: up on stilt roots by the water, a few leaning arms, each
	ending in a spiky tuft, orange fruit hanging under one."""
	rng = random.Random(10)
	p = []
	for i in range(6):
		a = 2 * math.pi * i / 6
		foot = (math.sin(a) * 0.9, 0.0, math.cos(a) * 0.9)
		p.append(tube([foot, (math.sin(a) * 0.45, 0.8, math.cos(a) * 0.45), (0, 1.5, 0)], 0.055, "bark", 4, cap=False))
	p.append(limb((0, 1.3, 0), (0.3, 3.0, 0.1), 0.17, 0.14, "bark", segs=7))
	tufts = [(-1.3, 4.3, 0.4), (1.5, 4.7, -0.3), (0.3, 5.1, 1.2)]
	for tf in tufts:
		p.append(limb((0.3, 2.9, 0.1), tf, 0.11, 0.08, "bark", lift=0.3))
		for k in range(18):
			yaw = 2 * math.pi * k / 18 + rng.uniform(-0.2, 0.2)
			el = rng.uniform(-0.3, 1.0)
			d = (math.sin(yaw) * math.cos(el), math.sin(el), math.cos(yaw) * math.cos(el))
			p.append(blade(tf, d, rng.uniform(1.3, 1.8), 0.14, "pandanus", droop=0.5, steps=2))
	p.append(clump(0.24, "pandanus_fruit", add(tufts[1], (0, -0.45, 0)), (1, 1.2, 1), rng, sub=1, jitter=0.05))
	put("Pandanus", p)
	far("PandanusFar", 2.6, 0.15, [((0.2, 4.6, 0.4), 1.0, (2.4, 1.2, 2.0), "pandanus")])


def mangrove():
	"""Grey mangrove: low, crooked, grey-green, on the mud at the water's
	edge with the breathing roots poking up round it."""
	rng = random.Random(11)
	p = []
	for e in ring_pts(3, 1.3, 2.0, rng, 0.2, 0.3, 0.2):
		p.append(limb((e[0] * 0.15, 0, e[2] * 0.15), e, 0.13, 0.06, "bark", lift=0.3, segs=5, steps=3))
	p.append(clump(1.9, "mangrove", (0, 3.0, 0), (1.15, 0.65, 1.15), rng))
	for e in ring_pts(5, 1.9, 2.6, rng, 0.0, 0.4, 0.3):
		p.append(clump(rng.uniform(1.2, 1.5), "mangrove", e, (1.1, 0.7, 1.1), rng))
	for k in range(26):
		a = rng.uniform(0, 2 * math.pi)
		r = rng.uniform(1.2, 3.4)
		p.append(lathe([(0.035, 0), (0.0, rng.uniform(0.18, 0.32))], 3, "pneumato").move(math.sin(a) * r, 0, math.cos(a) * r))
	put("Mangrove", p)
	far("MangroveFar", 1.4, 0.15, [((0, 2.8, 0), 1.0, (3.0, 1.4, 3.0), "mangrove")])


# ---------------------------------------------------------------- the garden beds

def bottlebrush():
	"""Bottlebrush shrub with its red brushes out."""
	rng = random.Random(12)
	p = []
	for e in ring_pts(4, 0.5, 1.3, rng, 0.0, 0.1, 0.2):
		p.append(limb((0, 0, 0), e, 0.05, 0.03, "bark", segs=4, steps=2))
	cs = ring_pts(3, 0.55, 1.5, rng, 0.5, 0.1, 0.2) + [(0, 2.1, 0)]
	for c in cs:
		p.append(clump(rng.uniform(0.7, 0.85), "bottlebrush_leaf", c, (1, 0.9, 1), rng))
	for k in range(16):
		c = cs[k % len(cs)]
		a = rng.uniform(0, 2 * math.pi)
		el = rng.uniform(-0.3, 0.9)
		at = add(c, (math.sin(a) * math.cos(el) * 0.75, math.sin(el) * 0.65, math.cos(a) * math.cos(el) * 0.75))
		p.append(cylinder(0.07, 0.3, "bottlebrush_red", segs=5, at=add(at, (0, -0.2, 0))))
	put("Bottlebrush", p)


def lomandra():
	"""Lomandra tussock, the strappy clump in every council garden bed."""
	rng = random.Random(13)
	p = []
	for k in range(20):
		a = 2 * math.pi * k / 20 + rng.uniform(-0.1, 0.1)
		el = rng.uniform(0.6, 1.35)
		d = (math.sin(a) * math.cos(el), math.sin(el), math.cos(a) * math.cos(el))
		p.append(blade((math.sin(a) * 0.05, 0, math.cos(a) * 0.05), d, rng.uniform(0.7, 0.95), 0.035, "lomandra", droop=0.5, steps=3))
	put("Lomandra", p)


def main():
	reset()
	fig()
	jacaranda()
	poinciana(False)
	poinciana(True)
	gum()
	paperbark()
	tuckeroo()
	sheoak()
	cabbage_palm()
	foxtail_palm()
	pandanus()
	mangrove()
	bottlebrush()
	lomandra()
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

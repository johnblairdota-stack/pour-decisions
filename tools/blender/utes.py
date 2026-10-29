"""Three dual-cab utes you can jump in and drive when you knock off
(assets/cars/utes.glb), and that turn up in the traffic and the kerbs:

Run:  python tools/blender/utes.py [--preview DIR]

  Hilux     Toyota Hilux SR5 (N80, 2016-20): trapezoid grille in a chrome
            surround, slim headlamps swept back into the guards, body-colour
            flares, chrome step bumper and sports bar, six-spoke alloys.
  Ranger    Ford Ranger XLT (PX2/PX3): the big three-bar chrome grille, square
            headlamps, the taller flat bonnet, black flares and roof rails,
            a black sports bar.
  Shark     BYD Shark 6 (2024): wide and upright, a light bar right across
            the nose and the tailgate, a closed black grille panel, black
            cladding round the arches, two-tone alloys.

For each:
  <Name>        the whole ute (parked, and the traffic)
  <Name>Body    without its wheels, for driving: the game spins and steers
  <Name>Wheel   one wheel, centred, axle along x, rim face towards +x
  <Name>Lite    a lighter whole ute for the far kerbs and the traffic

Each model's origin is on the road under its middle, front towards +z, as
tools/blender/cars.py. Paint is "body" (the game picks the colour); the
rest is painted by part name (scripts/utes.gd).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import Piece, box, build, cylinder, export_glb, lathe, reset, tri_count, tube  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "cars", "utes.glb")

PALETTE = {
	"body": "f4f4f2", "glass": "26323d", "tyre": "1e1e1e", "rim": "b9bfc4", "rim_dark": "3a3e44", "light": "eef3f6",
	"drl": "ffffff", "tail": "c8282a", "amber": "ff9a1f", "trim": "25282c", "chrome": "d8dde2", "grille": "1a1c1f",
	"plate": "f4f4f2", "liner": "2c2e31", "skid": "9aa0a6", "badge": "d8dde2", "ford_blue": "1f4f9a",
}

# The three utes, in metres off their brochures (length, width, height,
# wheelbase, front overhang, track, tyre). `top` is the body line from the
# nose back: nose, headlamps, cowl, belt and tub; `glass` the glasshouse.
SPECS = {
	"Hilux": dict(L=5.33, hw=0.905, H=1.815, wb=3.085, front=0.93, track=1.54, r=0.39, tw=0.265,
		nose=0.97, lamp=1.02, cowl=1.11, belt=1.13, tub=1.17, cowl_z=1.3, roof_z=0.44, back_z=-1.07,
		glass_top=0.70, flare="body", flare_w=0.035, spokes=6, rim="rim", bar="chrome", step="chrome"),
	"Ranger": dict(L=5.36, hw=0.915, H=1.85, wb=3.22, front=0.93, track=1.56, r=0.39, tw=0.265,
		nose=1.05, lamp=1.08, cowl=1.17, belt=1.19, tub=1.21, cowl_z=1.26, roof_z=0.42, back_z=-1.1,
		glass_top=0.72, flare="trim", flare_w=0.045, spokes=6, rim="rim", bar="trim", step="trim", rails=True),
	"Shark": dict(L=5.457, hw=0.96, H=1.925, wb=3.26, front=0.98, track=1.67, r=0.405, tw=0.275,
		nose=1.09, lamp=1.12, cowl=1.21, belt=1.23, tub=1.26, cowl_z=1.24, roof_z=0.36, back_z=-1.14,
		glass_top=0.76, flare="trim", flare_w=0.05, spokes=5, rim="rim_dark", bar="trim", step="trim"),
}


def put(name, pieces):
	return build(name, pieces, PALETTE, None, smooth=False)


# ------------------------------------------------------------------ shapes

def section(z, hw, y0, y1, rt=0.08, rb=0.03, inset=0.03, steps=3):
	"""A body cross-section at z: a rounded box from y0 to y1, narrowing by
	`inset` each side towards the top (tumblehome). Always the same number of
	points, so sections loft."""
	pts = []
	top = hw - inset
	rt = min(rt, (y1 - y0) * 0.45, top * 0.5)
	rb = min(rb, (y1 - y0) * 0.45)
	corners = [((hw - rb, y0 + rb), -90, 0, rb), ((top - rt, y1 - rt), 0, 90, rt),
		((-(top - rt), y1 - rt), 90, 180, rt), ((-(hw - rb), y0 + rb), 180, 270, rb)]
	for (cx, cy), a0, a1, r in corners:
		for i in range(steps + 1):
			a = math.radians(a0 + (a1 - a0) * i / steps)
			pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r, z))
	return pts


def loft(rings, mat, caps=True):
	"""Joins cross-sections (front to back or back to front) into one skin."""
	p = Piece(mat)
	bm = p.bm
	vs = [[bm.verts.new(q) for q in ring] for ring in rings]
	n = len(rings[0])
	for k in range(len(vs) - 1):
		a, b = vs[k], vs[k + 1]
		for i in range(n):
			j = (i + 1) % n
			try:
				bm.faces.new((a[i], a[j], b[j], b[i]))
			except ValueError:
				pass
	if caps:
		bm.faces.new(list(reversed(vs[0])))
		bm.faces.new(vs[-1])
	return p


def profile_x(poly, x0, x1, mat):
	"""A side profile [(z, y)] run across from x0 to x1."""
	p = Piece(mat)
	bm = p.bm
	a = [bm.verts.new((x0, y, z)) for z, y in poly]
	b = [bm.verts.new((x1, y, z)) for z, y in poly]
	n = len(poly)
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((a[i], a[j], b[j], b[i]))
	bm.faces.new(list(reversed(a)))
	bm.faces.new(b)
	return p


def face_poly(pts, z0, z1, mat):
	"""A shape drawn on the front or back [(x, y)], z0 to z1 thick."""
	p = Piece(mat)
	bm = p.bm
	a = [bm.verts.new((x, y, z0)) for x, y in pts]
	b = [bm.verts.new((x, y, z1)) for x, y in pts]
	n = len(pts)
	for i in range(n):
		j = (i + 1) % n
		bm.faces.new((a[i], a[j], b[j], b[i]))
	bm.faces.new(list(reversed(a)))
	bm.faces.new(b)
	return p


def mirror_x(pts):
	return [(-x, y) for x, y in reversed(pts)]


def arc(cz, cy, r, a0, a1, steps):
	"""Points round a wheel arch in the side view: angle 0 straight up, +
	towards the front (+z)."""
	return [(cz + math.sin(math.radians(a0 + (a1 - a0) * i / steps)) * r,
		cy + math.cos(math.radians(a0 + (a1 - a0) * i / steps)) * r) for i in range(steps + 1)]


# ------------------------------------------------------------------ wheels

def wheel(s, lite=False):
	"""One wheel: the tyre with rounded shoulders and tread blocks, the alloy
	with its spokes on the outer (+x) face."""
	r, w = s["r"], s["tw"]
	segs = 12 if lite else 24
	p = []
	prof = [(r * 0.64, -w / 2), (r * 0.9, -w / 2), (r * 0.975, -w / 2 + 0.025), (r, -w / 2 + 0.065),
		(r, w / 2 - 0.065), (r * 0.975, w / 2 - 0.025), (r * 0.9, w / 2), (r * 0.64, w / 2)]
	p.append(lathe(prof, segs, "tyre", cap_top=False, cap_bottom=False).rot("z", -math.pi / 2))
	rr = r * 0.64
	rim = s["rim"]
	# the dish behind the spokes, set in from the sidewall
	p.append(cylinder(rr, 0.04, "rim_dark" if rim == "rim" else "trim", segs, at=(0, 0, 0)).rot("z", -math.pi / 2)
		.move(w / 2 - 0.08, 0, 0))
	# the lip
	p.append(lathe([(rr, -0.012), (rr + 0.012, 0.0), (rr, 0.012), (rr - 0.02, 0.0)], segs, rim, loop=True)
		.rot("z", -math.pi / 2).move(w / 2 - 0.03, 0, 0))
	if not lite:
		n = 28
		for i in range(n):
			a = 2 * math.pi * i / n
			off = w * 0.2 * (1 if i % 2 else -1)
			p.append(box(w * 0.42, 0.03, 0.085, "tyre", at=(off, r + 0.006, 0)).rot("x", a))
	k = s["spokes"]
	for i in range(k):
		a = 2 * math.pi * i / k
		if s["spokes"] == 5:
			# split spokes, two-tone: a pair per spoke
			for da in (-0.09, 0.09):
				p.append(box(0.03, rr * 0.82, 0.032, "rim", at=(w / 2 - 0.035, rr * 0.5, 0)).rot("x", a + da))
		else:
			p.append(box(0.035, rr * 0.86, 0.06, "rim", at=(w / 2 - 0.035, rr * 0.48, 0)).rot("x", a))
	p.append(cylinder(0.075, 0.05, rim, 12 if not lite else 8).rot("z", -math.pi / 2).move(w / 2 - 0.02, 0, 0))
	p.append(cylinder(0.035, 0.02, "badge", 8).rot("z", -math.pi / 2).move(w / 2 + 0.03, 0, 0))
	if not lite:
		# wheel nuts
		for i in range(6):
			a = 2 * math.pi * i / 6 + 0.3
			p.append(box(0.02, 0.022, 0.022, "badge", at=(w / 2 + 0.02, math.cos(a) * 0.1, math.sin(a) * 0.1)))
	return p


def wheels_at(s, lite):
	out = []
	zf = s["L"] / 2 - s["front"]
	zr = zf - s["wb"]
	for z in (zf, zr):
		for side in (1, -1):
			for pc in wheel(s, lite):
				if side < 0:
					pc.rot("y", math.pi)
				pc.move(side * s["track"] / 2, s["r"], z)
				out.append(pc)
	return out


# ------------------------------------------------------------------ the body

def body(name, s, lite=False):
	L, hw, r = s["L"], s["hw"], s["r"]
	nz, tz = L / 2, -L / 2
	zf = nz - s["front"]
	zr = zf - s["wb"]
	R = r + 0.075                      # the arch opening
	arch = r + R                       # its top
	top = arch + 0.03                  # where the lower panels meet the upper body
	p = []
	steps = 2 if lite else 3

	# --- upper body, nose to tail: bonnet and guards, the doors' tops, the tub
	st = [
		(nz, hw - 0.1, s["nose"], 0.07, 0.06),
		(nz - 0.08, hw - 0.02, s["nose"] + 0.03, 0.1, 0.04),
		(nz - 0.35, hw, s["lamp"] + 0.02, 0.1, 0.03),
		(s["cowl_z"] + 0.05, hw, s["cowl"], 0.08, 0.03),
		(s["back_z"], hw + 0.005, s["belt"], 0.06, 0.03),
		(s["back_z"] - 0.04, hw + 0.005, s["tub"], 0.05, 0.02),
		(tz + 0.1, hw, s["tub"], 0.05, 0.02),
		(tz, hw - 0.03, s["tub"] - 0.02, 0.04, 0.02),
	]
	p.append(loft([section(z, w, top - 0.05, y, rt, 0.02, ins, steps) for z, w, y, rt, ins in st], "body"))

	# --- lower panels with the arches cut out of them: the front apron and
	# bumper, the doors and sills between the wheels, the back under the tub
	bot_f, bot_m, bot_r = 0.42, 0.47, 0.52
	ang = lambda y: math.degrees(math.acos(max(-1.0, min(1.0, (y - r) / R))))
	a_f, a_m, a_r = ang(bot_f), ang(bot_m), ang(bot_r)
	front = [(nz - 0.02, bot_f + 0.06), (nz, top - 0.03), (zf, top)] + arc(zf, r, R, 0, a_f, 8)[1:] + \
		[(nz - 0.12, bot_f)]
	p.append(profile_x(_ccw(front), -hw + 0.01, hw - 0.01, "body").warp(lambda v: _nose_taper(v, nz)))
	mid = [(zf, top)] + arc(zf, r, R, 0, -a_m, 8)[1:] + arc(zr, r, R, a_m, 0, 8)[:-1] + [(zr, top)]
	p.append(profile_x(_ccw(mid), -hw - 0.002, hw + 0.002, "body"))
	rear = [(zr, top)] + arc(zr, r, R, 0, -a_r, 8)[1:] + [(tz + 0.06, bot_r), (tz, bot_r + 0.08), (tz, top)]
	p.append(profile_x(_ccw(rear), -hw + 0.005, hw - 0.005, "body"))

	# arch liners (dark, so you don't see through to the far wheel) and flares
	for z in (zf, zr):
		p.append(cylinder(R - 0.01, 2 * hw - 0.06, "liner", 12 if lite else 20).rot("z", math.pi / 2)
			.move(hw - 0.03, r, z))
		for side in (1, -1):
			fl = arc(z, r, R + s["flare_w"] * 2.4, -98, 98, 10 if not lite else 6)
			inner = arc(z, r, R, 98, -98, 10 if not lite else 6)
			poly = fl + inner
			x0 = side * (hw - 0.02)
			x1 = side * (hw + s["flare_w"])
			p.append(profile_x(_ccw(poly), min(x0, x1), max(x0, x1), s["flare"]))

	# --- the glasshouse: windscreen raked back from the cowl, side glass with
	# tumblehome, the back window; roof skin over it
	gb, gt = hw - 0.04, s["glass_top"]
	yb, yt = s["belt"] - 0.02, s["H"] - 0.04
	cz, rz, bz = s["cowl_z"], s["roof_z"], s["back_z"] + 0.03
	ring = lambda z, wb_, wt, y0, y1: [(wb_, y0, z), (wt, y1, z), (-wt, y1, z), (-wb_, y0, z)]
	p.append(loft([ring(cz, gb, gb - 0.04, yb, yb + 0.03), ring(rz + 0.12, gb, gt + 0.03, yb, yt - 0.03),
		ring(rz, gb, gt, yb, yt), ring(bz, gb, gt, yb, yt)], "glass"))
	# roof skin
	p.append(loft([section(z, gt + 0.03, yt - 0.03, s["H"], 0.04, 0.0, 0.02, steps)
		for z in (rz + 0.06, rz - 0.02, bz - 0.01)], "body"))
	# pillars: A in body colour, B and C black
	for side in (1, -1):
		p.append(tube([(side * (gb - 0.005), yb, cz - 0.02), (side * (gt + 0.02), yt - 0.01, rz + 0.08)], 0.04, "body", 6))
		bpz = (rz + bz) / 2 - 0.05
		p.append(tube([(side * (gb + 0.005), yb, bpz), (side * (gt + 0.01), yt - 0.02, bpz)], 0.045, "trim", 6))
		p.append(tube([(side * (gb + 0.005), yb, bz + 0.02), (side * (gt + 0.01), yt - 0.02, bz + 0.02)], 0.05, "body", 6))
	# window line chrome / black
	for side in (1, -1):
		p.append(box(0.015, 0.02, cz - bz, "chrome" if name == "Hilux" else "trim",
			at=(side * (gb + 0.01), yb + 0.005, (cz + bz) / 2)))

	# --- doors: shut lines, handles; mirrors; side steps
	for side in (1, -1):
		x = side * (hw + 0.004)
		bpz = (rz + bz) / 2 - 0.05
		for z in (cz - 0.04, bpz, bz):
			p.append(box(0.01, top + 0.25 - bot_m, 0.012, "trim", at=(x, (top + 0.25 + bot_m) / 2 - 0.05, z)))
		for z in (bpz + 0.18, bz + 0.2):
			p.append(box(0.02, 0.035, 0.16, "chrome" if name == "Hilux" else ("trim" if name == "Ranger" else "body"),
				at=(x + side * 0.01, s["belt"] - 0.12, z)))
		# mirror on a stalk off the door's front corner
		mz = cz - 0.18
		p.append(box(0.16, 0.035, 0.05, "trim", at=(side * (hw + 0.06), s["belt"] + 0.04, mz)))
		p.append(box(0.08, 0.15, 0.22, "body" if name != "Ranger" else "trim", bevel=0.02,
			at=(side * (hw + 0.17), s["belt"] + 0.1, mz - 0.03)))
		p.append(box(0.02, 0.025, 0.1, "amber", at=(side * (hw + 0.212), s["belt"] + 0.06, mz + 0.02)))
		# side step
		p.append(box(0.2, 0.05, (zf - R) - (zr + R) - 0.1, s["step"], at=(side * (hw - 0.03), bot_m - 0.02, (zf + zr) / 2)))
		if name == "Shark":
			# black cladding along the doors' bottoms
			p.append(box(0.02, 0.14, (zf - R) - (zr + R), "trim", at=(side * (hw + 0.006), bot_m + 0.08, (zf + zr) / 2)))

	# --- the tub: liner, tailgate, sports bar
	t0, t1 = s["back_z"] - 0.08, tz + 0.08
	p.append(box(2 * hw - 0.14, 0.012, t0 - t1, "liner", at=(0, s["tub"] + 0.003, (t0 + t1) / 2)))
	p.append(box(2 * hw - 0.02, 0.02, 0.06, "trim", at=(0, s["tub"] + 0.005, tz + 0.03)))
	_sports_bar(p, s, hw, t0)
	if s.get("rails"):
		for side in (1, -1):
			p.append(tube([(side * (gt - 0.04), s["H"] - 0.02, rz - 0.02), (side * (gt - 0.04), s["H"] + 0.05, rz - 0.1),
				(side * (gt - 0.04), s["H"] + 0.05, bz + 0.1), (side * (gt - 0.04), s["H"] - 0.02, bz + 0.02)], 0.022, "trim", 6))
	# aerial
	p.append(tube([(0.0, s["H"], bz + 0.15), (0.0, s["H"] + 0.06, bz + 0.05)], 0.012, "trim", 4))

	# --- the face and the back, per ute
	{"Hilux": _hilux_face, "Ranger": _ranger_face, "Shark": _shark_face}[name](p, s, hw, nz, tz, top, lite)
	return p


def _ccw(poly):
	"""(profile_x is happy either way round; drops repeated points)"""
	out = []
	for q in poly:
		if not out or abs(out[-1][0] - q[0]) > 1e-4 or abs(out[-1][1] - q[1]) > 1e-4:
			out.append(q)
	if len(out) > 2 and abs(out[0][0] - out[-1][0]) < 1e-4 and abs(out[0][1] - out[-1][1]) < 1e-4:
		out.pop()
	return out


def _nose_taper(v, nz):
	"""Rounds the bumper's corners in plan."""
	k = max(0.0, (v[2] - (nz - 0.35)) / 0.35)
	return (v[0] * (1.0 - 0.09 * k * k), v[1], v[2])


def _sports_bar(p, s, hw, t0):
	x = hw - 0.12
	y0, y1 = s["tub"], s["H"] - 0.12
	z = t0 - 0.12
	mat = s["bar"]
	for side in (1, -1):
		p.append(tube([(side * x, y0, z - 0.45), (side * x, y1 - 0.08, z - 0.05), (side * (x - 0.06), y1, z)], 0.035, mat, 8))
	p.append(tube([(-(x - 0.06), y1, z), (x - 0.06, y1, z)], 0.035, mat, 8))


def _lamp_pair(p, pts, z0, z1, mat):
	p.append(face_poly(pts, z0, z1, mat))
	p.append(face_poly(mirror_x(pts), z0, z1, mat))


def _plate(p, y, z, face):
	p.append(box(0.38, 0.13, 0.02, "plate", at=(0, y, z + face * 0.01)))
	p.append(box(0.4, 0.15, 0.015, "trim", at=(0, y, z)))


def _hilux_face(p, s, hw, nz, tz, top, lite):
	y_n = s["nose"]
	zf = nz + 0.002
	# trapezoid grille in a chrome surround, three chrome bars
	g = [(0.42, 0.76), (0.5, y_n - 0.02), (-0.5, y_n - 0.02), (-0.42, 0.76)]
	p.append(face_poly(g, zf - 0.04, zf + 0.012, "grille"))
	p.append(tube([(x, y, zf + 0.018) for x, y in g + [g[0]]], 0.018, "chrome", 5, cap=False))
	for i, y in enumerate((0.82, 0.88, 0.94)):
		w = 0.42 + (y - 0.76) / (y_n - 0.78) * 0.08
		p.append(box(2 * w - 0.06, 0.018, 0.02, "chrome", at=(0, y, zf + 0.016)))
	p.append(cylinder(0.075, 0.02, "badge", 14).rot("x", math.pi / 2).scale(1.3, 1, 1).move(0, 0.9, zf + 0.03))
	# headlamps swept back and up into the guards, a light strip in each
	lamp = [(0.5, 0.85), (0.8, 0.9), (hw - 0.04, y_n + 0.01), (hw - 0.12, y_n + 0.03), (0.52, y_n - 0.01)]
	_lamp_pair(p, lamp, zf - 0.08, zf + 0.004, "light")
	_lamp_pair(p, [(0.55, 0.9), (0.78, 0.93), (0.78, 0.945), (0.55, 0.92)], zf - 0.08, zf + 0.012, "drl")
	# bumper: wide black intake, fogs in the corners, silver skid plate
	p.append(face_poly([(0.5, 0.5), (0.56, 0.66), (-0.56, 0.66), (-0.5, 0.5)], zf - 0.06, zf + 0.008, "trim"))
	for side in (1, -1):
		p.append(face_poly([(side * 0.66, 0.52), (side * 0.82, 0.55), (side * 0.82, 0.66), (side * 0.66, 0.66)],
			zf - 0.1, zf + 0.004, "trim"))
		p.append(cylinder(0.035, 0.02, "light", 10).rot("x", math.pi / 2).move(side * 0.74, 0.6, zf + 0.012))
	p.append(box(0.9, 0.05, 0.05, "skid", at=(0, 0.45, nz - 0.03)))
	_plate(p, 0.71, nz, 1)
	# the back: tall tail lamps on the tub's corners, chrome step bumper
	for side in (1, -1):
		p.append(box(0.12, 0.42, 0.03, "tail", at=(side * (hw - 0.07), top + 0.08, tz - 0.012)))
		p.append(box(0.08, 0.1, 0.035, "light", at=(side * (hw - 0.07), top - 0.05, tz - 0.015)))
		p.append(box(0.08, 0.06, 0.035, "amber", at=(side * (hw - 0.07), top + 0.24, tz - 0.015)))
	p.append(box(2 * hw - 0.06, 0.17, 0.2, "chrome", bevel=0.03, at=(0, 0.6, tz - 0.06)))
	p.append(box(0.5, 0.03, 0.12, "trim", at=(0, 0.69, tz - 0.08)))
	p.append(box(0.24, 0.06, 0.04, "chrome", at=(0, top + 0.18, tz - 0.012)))     # tailgate handle
	_plate(p, 0.6, tz - 0.16, -1)
	p.append(box(0.1, 0.1, 0.25, "trim", at=(0, 0.48, tz - 0.15)))                # tow hitch


def _ranger_face(p, s, hw, nz, tz, top, lite):
	y_n = s["nose"]
	zf = nz + 0.002
	# the big grille: a near-rectangle, three thick chrome bars
	g = [(0.56, 0.74), (0.58, y_n - 0.02), (-0.58, y_n - 0.02), (-0.56, 0.74)]
	p.append(face_poly(g, zf - 0.04, zf + 0.012, "grille"))
	p.append(tube([(x, y, zf + 0.02) for x, y in g + [g[0]]], 0.022, "chrome", 5, cap=False))
	for y in (0.8, 0.88, 0.96):
		p.append(box(1.1, 0.045, 0.03, "chrome", bevel=0.01, at=(0, y, zf + 0.02)))
	p.append(cylinder(0.07, 0.02, "ford_blue", 14).rot("x", math.pi / 2).scale(1.6, 1, 1).move(0, 0.88, zf + 0.045))
	# square headlamps, a black inner and a light strip
	lamp = [(0.62, 0.86), (hw - 0.03, 0.88), (hw - 0.05, y_n + 0.02), (0.62, y_n - 0.005)]
	_lamp_pair(p, lamp, zf - 0.08, zf + 0.004, "light")
	_lamp_pair(p, [(0.66, 0.9), (0.84, 0.91), (0.84, 0.94), (0.66, 0.93)], zf - 0.08, zf + 0.01, "trim")
	# bumper: silver lower, fogs in black "C" housings
	p.append(face_poly([(0.6, 0.47), (0.62, 0.62), (-0.62, 0.62), (-0.6, 0.47)], zf - 0.06, zf + 0.008, "trim"))
	p.append(face_poly([(0.45, 0.43), (0.5, 0.52), (-0.5, 0.52), (-0.45, 0.43)], zf - 0.05, zf + 0.016, "skid"))
	for side in (1, -1):
		p.append(face_poly([(side * 0.68, 0.5), (side * 0.86, 0.5), (side * 0.86, 0.68), (side * 0.68, 0.68)],
			zf - 0.1, zf + 0.004, "trim"))
		p.append(box(0.12, 0.045, 0.02, "light", at=(side * 0.77, 0.6, zf + 0.012)))
	_plate(p, 0.7, nz, 1)
	# the back: tall tail lamps, a black step bumper with a silver pad
	for side in (1, -1):
		p.append(box(0.12, 0.44, 0.03, "tail", at=(side * (hw - 0.07), top + 0.09, tz - 0.012)))
		p.append(box(0.08, 0.12, 0.035, "light", at=(side * (hw - 0.07), top + 0.02, tz - 0.015)))
	p.append(box(2 * hw - 0.06, 0.18, 0.2, "trim", bevel=0.03, at=(0, 0.6, tz - 0.06)))
	p.append(box(0.6, 0.03, 0.14, "skid", at=(0, 0.695, tz - 0.08)))
	p.append(box(0.3, 0.07, 0.04, "trim", at=(0, top + 0.19, tz - 0.012)))
	p.append(box(0.5, 0.05, 0.02, "chrome", at=(0, top + 0.06, tz - 0.012)))       # RANGER across the tailgate
	_plate(p, 0.6, tz - 0.16, -1)
	p.append(box(0.1, 0.1, 0.25, "trim", at=(0, 0.48, tz - 0.15)))


def _shark_face(p, s, hw, nz, tz, top, lite):
	y_n = s["nose"]
	zf = nz + 0.002
	# a light bar right across the nose, slim headlamps under its ends
	p.append(box(2 * hw - 0.2, 0.028, 0.02, "drl", at=(0, y_n + 0.005, zf + 0.008)))
	_lamp_pair(p, [(0.6, y_n - 0.09), (hw - 0.05, y_n - 0.07), (hw - 0.06, y_n - 0.02), (0.6, y_n - 0.035)],
		zf - 0.08, zf + 0.004, "light")
	# the closed grille: a gloss black panel, thin horizontal ribs
	g = [(0.56, 0.66), (0.58, y_n - 0.05), (-0.58, y_n - 0.05), (-0.56, 0.66)]
	p.append(face_poly(g, zf - 0.04, zf + 0.012, "grille"))
	for i in range(5):
		y = 0.7 + i * (y_n - 0.79) / 4
		p.append(box(1.08, 0.008, 0.012, "trim", at=(0, y, zf + 0.016)))
	p.append(box(0.22, 0.04, 0.02, "badge", at=(0, (0.66 + y_n - 0.05) / 2, zf + 0.022)))
	# black lower bumper with air curtains in the corners, skid plate
	p.append(face_poly([(hw - 0.06, 0.44), (hw - 0.04, 0.64), (-(hw - 0.04), 0.64), (-(hw - 0.06), 0.44)],
		zf - 0.05, zf + 0.006, "trim"))
	p.append(face_poly([(0.5, 0.42), (0.55, 0.52), (-0.55, 0.52), (-0.5, 0.42)], zf - 0.04, zf + 0.014, "skid"))
	for side in (1, -1):
		p.append(box(0.04, 0.18, 0.02, "grille", at=(side * (hw - 0.14), 0.55, zf + 0.012)))
	_plate(p, 0.58, nz + 0.01, 1)
	# the back: a light bar across the tailgate, C-shaped lamps in the corners
	p.append(box(2 * hw - 0.18, 0.03, 0.02, "tail", at=(0, top + 0.27, tz - 0.012)))
	for side in (1, -1):
		x = side * (hw - 0.07)
		p.append(box(0.1, 0.03, 0.025, "tail", at=(x, top + 0.27, tz - 0.012)))
		p.append(box(0.03, 0.26, 0.025, "tail", at=(x + side * 0.035, top + 0.15, tz - 0.012)))
		p.append(box(0.1, 0.03, 0.025, "tail", at=(x, top + 0.03, tz - 0.012)))
		p.append(box(0.05, 0.06, 0.03, "light", at=(x - side * 0.01, top + 0.15, tz - 0.014)))
	p.append(box(0.7, 0.06, 0.02, "chrome", at=(0, top + 0.18, tz - 0.012)))       # SHARK across the tailgate
	p.append(box(2 * hw - 0.04, 0.2, 0.2, "trim", bevel=0.04, at=(0, 0.6, tz - 0.06)))
	_plate(p, 0.62, tz - 0.16, -1)
	p.append(box(0.1, 0.1, 0.25, "trim", at=(0, 0.48, tz - 0.15)))


# ------------------------------------------------------------------ main

def main():
	reset()
	made = []
	for name, s in SPECS.items():
		made.append(put(name + "Body", body(name, s)))
		made.append(put(name + "Wheel", wheel(s)))
		made.append(put(name, body(name, s) + wheels_at(s, False)))
		made.append(put(name + "Lite", body(name, s, True) + wheels_at(s, True)))
	tot = 0
	for o in made:
		t = tri_count([o])
		tot += t
		print("  %-12s %6d triangles" % (o.name, t))
	print("  total %d" % tot)
	if "--preview" in sys.argv:
		_preview(sys.argv[sys.argv.index("--preview") + 1])
	export_glb(OUT)
	print("wrote", OUT)


def _preview(out_dir):
	"""A turntable of the three, side by side, for the thread."""
	import bpy
	from kit import preview
	os.makedirs(out_dir, exist_ok=True)
	keep = {"Hilux": -2.4, "Ranger": 0.0, "Shark": 2.4}
	for o in bpy.context.scene.objects:
		if o.name in keep:
			o.location.x = keep[o.name]
	preview(os.path.join(out_dir, "utes.png"),
		[("front", 25, 12), ("rear", 160, 14), ("side", 90, 6), ("side_l", -90, 6), ("high", -40, 35)],
		show=lambda o: o.name in keep or o.type != "MESH", target=(0, 0.9, 0), dist=10.5, samples=16)
	for o in bpy.context.scene.objects:
		if o.name in keep:
			o.location.x = 0.0


if __name__ == "__main__":
	main()

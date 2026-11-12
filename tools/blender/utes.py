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
  <Name>Under   what's under it, for the Body: chassis rails and cross
                members, the front diff and its half shafts, control arms and
                coil-overs, the sump guard (the Shark: its battery pack),
                gearbox and transfer case, tailshafts, fuel tank, exhaust and
                the tow bar. Same origin as the Body; parent it to the Body.
  <Name>AxleR   the rear axle, origin at the axle's centre (put it at
                (0, r, zr) and roll it with the rear wheels): the Hilux and
                Ranger a live beam axle with its diff pumpkin, drums, leaf
                springs and shocks; the Shark (independent rear) its e-motor
                and diff housing, half shafts, arms and coil springs.
  <Name>WheelLow    the wheel aired down to about 18 psi: a little lower,
                the sidewalls bulged; round all the way, so it can spin
  <Name>WheelBulge  the aired-down tyre's squashed bottom: the flat contact
                patch and the sidewall bulge over it. Doesn't spin: put it at
                the hub, not under the spinning wheel.

The arches are deep wells with a dark liner and an inner wall, room for the
wheels to ride 13 cm up into them (the flares cover the tyre's top).

Each model's origin is on the road under its middle, front towards +z, as
tools/blender/cars.py. Paint is "body" (the game picks the colour); the
rest is painted by part name (scripts/utes.gd).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import Piece, box, build, cylinder, export_glb, lathe, reset, sphere, tri_count, tube  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "cars", "utes.glb")

PALETTE = {
	"body": "f4f4f2", "glass": "26323d", "tyre": "1e1e1e", "rim": "b9bfc4", "rim_dark": "3a3e44", "light": "eef3f6",
	"drl": "ffffff", "tail": "c8282a", "tail_hi": "ff5a4a", "glass_hi": "6f8494", "amber": "ff9a1f", "trim": "25282c", "chrome": "d8dde2", "grille": "1a1c1f",
	"plate": "f4f4f2", "liner": "2c2e31", "skid": "9aa0a6", "badge": "d8dde2", "ford_blue": "1f4f9a",
	"chassis": "26282b", "diff": "4a4d52", "spring": "1b1d20", "shock": "3a3e44", "drum": "6b6460",
	"exhaust": "8a847b", "battery": "39424d", "well": "1c1d1f", "lamp_in": "2e343b",
}

# The three utes, in metres off their brochures (length, width, height,
# wheelbase, front overhang, track, tyre). `top` is the body line from the
# nose back: nose, headlamps, cowl, belt and tub; `glass` the glasshouse.
SPECS = {
	"Hilux": dict(L=5.33, hw=0.905, H=1.815, wb=3.085, front=0.93, track=1.54, r=0.39, tw=0.265,
		nose=0.97, lamp=1.02, cowl=1.16, belt=1.2, tub=1.17, cowl_z=1.3, roof_z=0.44, back_z=-1.07,
		glass_top=0.70, flare="body", flare_w=0.035, spokes=6, rim="rim", bar="chrome", step="chrome"),
	"Ranger": dict(L=5.36, hw=0.915, H=1.85, wb=3.22, front=0.93, track=1.56, r=0.39, tw=0.265,
		nose=1.05, lamp=1.08, cowl=1.22, belt=1.24, tub=1.21, cowl_z=1.26, roof_z=0.42, back_z=-1.1,
		glass_top=0.72, flare="trim", flare_w=0.045, spokes=6, rim="rim", bar="trim", step="trim", rails=True),
	"Shark": dict(L=5.457, hw=0.96, H=1.925, wb=3.26, front=0.98, track=1.67, r=0.405, tw=0.275,
		nose=1.09, lamp=1.12, cowl=1.26, belt=1.29, tub=1.26, cowl_z=1.24, roof_z=0.36, back_z=-1.14,
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

def body(name, s, lite=False, bar=True):
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
		(nz - 0.08, hw - 0.05, s["nose"] + 0.03, 0.1, 0.04),     # (inside the nose's rounded corners)
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
		p += wells(s, z, R, lite)
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

	# a shoulder crease down each side, guard to tail lamp, catching the light
	for side in (1, -1):
		cy = s["belt"] - 0.19
		p.append(box(0.014, 0.022, (nz - 0.45) - (tz + 0.12), "body",
			at=(side * (hw + 0.004), cy, ((nz - 0.45) + (tz + 0.12)) / 2)))
	# sheen on the glass: two slanting streaks on the windscreen, one on each
	# door's window
	wz = rz + 0.12
	dy, dz = (yt - 0.03) - yb, wz - cz
	ln = math.hypot(dy, dz)
	oy, oz = -dz / ln * 0.012, dy / ln * 0.012
	ws = lambda x, u: (x, yb + u * dy + oy, cz + u * dz + oz)
	for x0, x1, w in ((-0.38, -0.12, 0.03), (-0.2, 0.04, 0.016)):
		p.append(tube([ws(x0, 0.12), ws(x1, 0.88)], w, "glass_hi", 4))
	for side in (1, -1):
		for zz, w in ((rz - 0.12, 0.022), (bz + 0.32, 0.016)):
			a = (side * (gb + 0.012), yb + 0.06, zz + 0.12)
			b = (side * (gt + 0.022), yt - 0.08, zz - 0.06)
			p.append(tube([a, b], w, "glass_hi", 4))

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

	# --- the gap between the cab and the tub down each side, black caps
	# along the tub's rails, the fuel flap on the tub's left side
	for side in (1, -1):
		p.append(box(0.012, s["tub"] - bot_r + 0.02, 0.016, "trim",
			at=(side * (hw + 0.006), (s["tub"] + bot_r) / 2, s["back_z"] - 0.025)))
		p.append(box(0.07, 0.012, (s["back_z"] - 0.06) - (tz + 0.05), "trim",
			at=(side * (hw - 0.03), s["tub"] + 0.006, ((s["back_z"] - 0.06) + (tz + 0.05)) / 2)))
	fz = zr + R + 0.3
	for dy, dz, sy, sz in ((0.07, 0, 0.012, 0.15), (-0.07, 0, 0.012, 0.15), (0, 0.07, 0.15, 0.012), (0, -0.07, 0.15, 0.012)):
		p.append(box(0.008, sy, sz, "trim", at=(hw + 0.006, s["tub"] - 0.17 + dy, fz + dz)))

	# --- the tub: liner, tailgate, sports bar
	t0, t1 = s["back_z"] - 0.08, tz + 0.08
	p.append(box(2 * hw - 0.14, 0.012, t0 - t1, "liner", at=(0, s["tub"] + 0.003, (t0 + t1) / 2)))
	p.append(box(2 * hw - 0.02, 0.02, 0.06, "trim", at=(0, s["tub"] + 0.005, tz + 0.03)))
	if bar:
		_sports_bar(p, s, hw, t0)
	if s.get("rails"):
		for side in (1, -1):
			p.append(tube([(side * (gt - 0.04), s["H"] - 0.02, rz - 0.02), (side * (gt - 0.04), s["H"] + 0.05, rz - 0.1),
				(side * (gt - 0.04), s["H"] + 0.05, bz + 0.1), (side * (gt - 0.04), s["H"] - 0.02, bz + 0.02)], 0.022, "trim", 6))
	# aerial
	p.append(tube([(0.0, s["H"], bz + 0.15), (0.0, s["H"] + 0.06, bz + 0.05)], 0.012, "trim", 4))

	# --- the face and the back, per ute
	n0 = len(p)
	{"Hilux": _hilux_face, "Ranger": _ranger_face, "Shark": _shark_face}[name](p, s, hw, nz, tz, top, lite)
	# (the face follows the nose's rounded corners in plan, so the lamps
	# don't stick out past the guards)
	for pc in p[n0:]:
		pc.warp(lambda v: _nose_taper(v, nz))
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
	_lamp_pair(p, lamp, zf - 0.08, zf + 0.004, "lamp_in")
	_lamp_pair(p, [(0.55, 0.935), (0.78, 0.955), (0.78, 0.97), (0.55, 0.95)], zf - 0.08, zf + 0.012, "drl")
	for side in (1, -1):
		# twin reflectors in a chrome trim
		for x, rr in ((0.6, 0.04), (0.71, 0.034)):
			p.append(cylinder(rr, 0.016, "light", 12).rot("x", math.pi / 2).move(side * x, 0.895 + (x - 0.6) * 0.15, zf + 0.012))
		p.append(box(0.32, 0.01, 0.01, "chrome", at=(side * 0.66, 0.862, zf + 0.012)))
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
		p.append(box(0.135, 0.44, 0.026, "lamp_in", at=(side * (hw - 0.07), top + 0.08, tz - 0.008)))
		p.append(box(0.12, 0.42, 0.03, "tail", at=(side * (hw - 0.07), top + 0.08, tz - 0.012)))
		p.append(box(0.08, 0.1, 0.035, "light", at=(side * (hw - 0.07), top - 0.05, tz - 0.015)))
		p.append(box(0.08, 0.06, 0.035, "amber", at=(side * (hw - 0.07), top + 0.24, tz - 0.015)))
		for y in (top + 0.07, top + 0.13):
			p.append(box(0.09, 0.014, 0.034, "tail_hi", at=(side * (hw - 0.07), y, tz - 0.016)))
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
	p.append(cylinder(0.055, 0.02, "ford_blue", 14).rot("x", math.pi / 2).scale(1.65, 1, 1).move(0, 0.88, zf + 0.045))
	# square headlamps, a black inner and a light strip
	lamp = [(0.62, 0.86), (hw - 0.03, 0.88), (hw - 0.05, y_n + 0.02), (0.62, y_n - 0.005)]
	_lamp_pair(p, lamp, zf - 0.08, zf + 0.004, "lamp_in")
	for side in (1, -1):
		# a projector and a reflector, the DRL underlining them
		p.append(cylinder(0.045, 0.016, "light", 12).rot("x", math.pi / 2).move(side * 0.69, 0.96, zf + 0.012))
		p.append(box(0.1, 0.075, 0.016, "light", at=(side * 0.81, 0.96, zf + 0.012)))
		p.append(box(0.24, 0.016, 0.016, "drl", at=(side * 0.75, 0.9, zf + 0.012)))
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
		p.append(box(0.135, 0.46, 0.026, "lamp_in", at=(side * (hw - 0.07), top + 0.09, tz - 0.008)))
		p.append(box(0.12, 0.44, 0.03, "tail", at=(side * (hw - 0.07), top + 0.09, tz - 0.012)))
		p.append(box(0.08, 0.12, 0.035, "light", at=(side * (hw - 0.07), top + 0.02, tz - 0.015)))
		# three LED bars stacked above the reverse lamp
		for y in (top + 0.14, top + 0.19, top + 0.24):
			p.append(box(0.09, 0.014, 0.034, "tail_hi", at=(side * (hw - 0.07), y, tz - 0.016)))
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
		zf - 0.08, zf + 0.004, "lamp_in")
	for side in (1, -1):
		for x in (0.67, 0.76):
			p.append(box(0.07, 0.03, 0.016, "light", at=(side * x, y_n - 0.055, zf + 0.012)))
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
	p.append(box(2 * hw - 0.3, 0.01, 0.024, "tail_hi", at=(0, top + 0.27, tz - 0.016)))
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

# ------------------------------------------------------------------ under it

TRAVEL = 0.13       # how far a wheel rides up into its arch (m)


def wells(s, z, R, lite):
	"""The wheel arch wells, both sides: a dark liner arching over the wheel
	with room for it to ride TRAVEL up, and an inner wall so you can't see
	through to the other side."""
	r = s["r"]
	Rw = R + TRAVEL - 0.02
	n = 8 if lite else 14
	# (down each side only as far as the body's bottom edge, so no black
	# shows below it beside the wheel)
	a = math.degrees(math.acos(max(-1.0, min(1.0, (0.46 - r) / Rw))))
	out = []
	for side in (1, -1):
		xi = s["track"] / 2 - s["tw"] / 2 - 0.05
		xo = s["hw"] - 0.015
		shell = arc(z, r, Rw + 0.015, -a, a, n) + arc(z, r, Rw, a, -a, n)
		lo, hi = (xi, xo) if side > 0 else (-xo, -xi)
		out.append(profile_x(_ccw(shell), lo, hi, "well"))
		wall = arc(z, r, Rw + 0.015, -a, a, n)
		wx = side * xi
		out.append(profile_x(_ccw(wall), min(wx, wx - side * 0.015), max(wx, wx - side * 0.015), "liner"))
	return out


def _rail_path(s):
	"""The chassis rail's line, nose to tail (z, y of its middle): level under
	the cab, kicking up over the rear axle."""
	L, r = s["L"], s["r"]
	zf = L / 2 - s["front"]
	zr = zf - s["wb"]
	y = r + 0.14
	return [(L / 2 - 0.3, y + 0.04), (zf - 0.5, y), (zr + 0.75, y), (zr + 0.35, y + 0.12), (zr - 0.35, y + 0.12),
		(zr - 0.7, y + 0.06), (-L / 2 + 0.2, y + 0.06)]


def _beam(a, b, sx, sy, mat, bevel=0.01):
	"""A box beam from a to b (in a z-y plane at a's x)."""
	dz, dy = b[2] - a[2], b[1] - a[1]
	ln = math.hypot(dz, dy)
	return box(sx, sy, ln + sy * 0.5, mat, bevel=bevel).rot("x", -math.atan2(dy, dz)).move(
		a[0], (a[1] + b[1]) / 2, (a[2] + b[2]) / 2)


def under(name, s, lite=False):
	L, r, hw = s["L"], s["r"], s["hw"]
	nz, tz = L / 2, -L / 2
	zf = nz - s["front"]
	zr = zf - s["wb"]
	hub = s["track"] / 2 - s["tw"] / 2 - 0.04
	p = []
	path = _rail_path(s)
	rx = 0.46
	# the ladder: two rails, cross members, body mounts
	for side in (1, -1):
		for (z0, y0), (z1, y1) in zip(path, path[1:]):
			p.append(_beam((side * rx, y0, z0), (side * rx, y1, z1), 0.07, 0.17, "chassis"))
		for z in (zf + 0.35, zf - 0.75, zr + 1.2, zr - 0.95):
			p.append(box(0.12, 0.04, 0.1, "chassis", bevel=0.01, at=(side * (rx + 0.08), r + 0.22, z)))
	for z, y in ((nz - 0.32, r + 0.18), (zf - 0.45, r + 0.12), (zf - 1.25, r + 0.1), (zr + 0.85, r + 0.12),
			(zr - 0.75, r + 0.2), (tz + 0.25, r + 0.2)):
		p.append(box(2 * rx, 0.09, 0.08, "chassis", bevel=0.01, at=(0, y, z)))
	# the front: the diff off-centre, half shafts out to the hubs, the lower
	# arms and the coil-overs (independent front suspension on all three)
	dx = 0.07
	p.append(lathe([(0.0, -0.11), (0.1, -0.1), (0.13, 0.0), (0.1, 0.1), (0.0, 0.11)], 12 if lite else 18, "diff")
		.rot("z", math.pi / 2).move(dx, r + 0.01, zf))
	p.append(tube([(dx, r + 0.03, zf + 0.05), (dx, r + 0.1, zf - 0.45)], 0.05, "diff", 8))
	for side in (1, -1):
		p.append(tube([(dx + side * 0.1, r + 0.01, zf), (side * hub, r, zf)], 0.028, "spring", 8))
		p.append(cylinder(0.06, 0.08, "spring", 10).rot("z", math.pi / 2).move(side * (hub * 0.6 + 0.04), r, zf))
		for dz in (0.16, -0.16):
			p.append(tube([(side * (rx - 0.02), r + 0.03, zf + dz), (side * (hub - 0.04), r - 0.05, zf + dz * 0.2)],
				0.024, "chassis", 6))
		p.append(tube([(side * (hub - 0.12), r - 0.02, zf - 0.04), (side * (rx + 0.04), r + 0.42, zf - 0.08)],
			0.045, "shock", 8))
		p.append(tube([(side * (hub - 0.11), r + 0.08, zf - 0.04), (side * (rx + 0.03), r + 0.36, zf - 0.08)],
			0.07, "spring", 8))
		p.append(tube([(side * (rx - 0.02), r + 0.1, zf - 0.22), (side * (hub - 0.08), r + 0.05, zf - 0.18)],
			0.012, "chassis", 5))
	# the steering rack
	p.append(tube([(-hub + 0.12, r + 0.04, zf - 0.2), (hub - 0.12, r + 0.04, zf - 0.2)], 0.026, "diff", 8))
	if name == "Shark":
		# the battery pack between the axles, flat under the floor
		p.append(box(1.25, 0.12, zf - zr - 1.0, "battery", bevel=0.03, at=(0, r + 0.02, (zf + zr) / 2 + 0.05)))
		for k in range(6):
			z = zr + 0.75 + k * (zf - zr - 1.4) / 5
			p.append(box(1.2, 0.012, 0.03, "chassis", at=(0, r - 0.045, z)))
		# the engine's sump guard, and the front e-motor
		p.append(box(0.72, 0.012, 0.75, "skid", bevel=0.004, at=(0, r - 0.04, zf + 0.12)))
		p.append(box(0.32, 0.26, 0.3, "battery", bevel=0.03, at=(-0.12, r + 0.1, zf - 0.32)))
	else:
		# the sump guard: a bash plate from the bumper back under the engine,
		# its front turned up, with drain holes
		g = box(0.78, 0.012, 1.15, "skid", bevel=0.004, at=(0, r - 0.05, zf + 0.25))
		g.warp(lambda v: (v.x, v.y + max(0.0, v.z - (zf + 0.6)) * 0.55, v.z))
		p.append(g)
		for hx, hz in ((-0.18, zf + 0.1), (0.18, zf + 0.1), (0.0, zf - 0.15)):
			p.append(cylinder(0.035, 0.004, "chassis", 10).move(hx, r - 0.06, hz))
		# gearbox and transfer case, the tailshafts front and back
		p.append(lathe([(0.0, 0.0), (0.16, 0.05), (0.13, 0.55), (0.0, 0.6)], 12 if lite else 16, "diff")
			.rot("x", -math.pi / 2).move(0.0, r + 0.22, zf - 0.55))
		p.append(box(0.3, 0.22, 0.28, "diff", bevel=0.03, at=(0.04, r + 0.12, zf - 1.3)))
		p.append(tube([(0.07, r + 0.08, zf - 1.2), (dx, r + 0.07, zf - 0.5)], 0.03, "spring", 8))
		p.append(tube([(0.0, r + 0.12, zf - 1.45), (0.0, r + 0.04, zr + 0.28)], 0.038, "spring", 8))
		p.append(cylinder(0.05, 0.05, "diff", 10).rot("x", math.pi / 2).move(0, r + 0.08, zf - 1.42))
	# fuel tank on the left, the exhaust down the right with its muffler
	p.append(box(0.42, 0.24, 0.62, "chassis", bevel=0.04, at=(-0.22 if name != "Shark" else -0.3, r + 0.2,
		zr + 0.85)))
	ex = [(0.18, r + 0.18, zf - 0.9), (0.28, r + 0.09, zf - 1.5), (0.3, r + 0.09, zr + 1.1),
		(0.3, r + 0.1, zr + 0.45), (0.32, r + 0.28, zr), (0.32, r + 0.16, zr - 0.5), (0.55, r + 0.12, zr - 0.95)]
	p.append(tube(ex, 0.03, "exhaust", 8))
	p.append(lathe([(0.0, 0.0), (0.12, 0.02), (0.12, 0.5), (0.0, 0.52)], 12, "exhaust").rot("x", math.pi / 2)
		.move(0.29, r + 0.1, zr + 1.05))
	# the tow bar: a cross bar between the rails, the receiver, the tongue and
	# ball, the safety chain loops and the trailer plug
	ty = r + 0.1
	p.append(box(2 * rx + 0.1, 0.07, 0.07, "chassis", bevel=0.01, at=(0, ty, tz + 0.18)))
	for side in (1, -1):
		p.append(box(0.05, 0.16, 0.25, "chassis", at=(side * rx, ty + 0.08, tz + 0.27)))
	p.append(box(0.075, 0.075, 0.42, "chassis", bevel=0.008, at=(0, ty, tz + 0.06)))
	p.append(box(0.055, 0.055, 0.3, "chassis", bevel=0.006, at=(0, ty, tz - 0.2)))
	p.append(box(0.12, 0.02, 0.12, "chassis", bevel=0.005, at=(0, ty + 0.03, tz - 0.32)))
	p.append(cylinder(0.014, 0.05, "chrome", 8).move(0, ty + 0.04, tz - 0.32))
	p.append(lathe([(0.0, -0.025), (0.025, 0.0), (0.0, 0.025)], 12, "chrome").move(0, ty + 0.115, tz - 0.32))
	for side in (1, -1):
		p.append(tube([(side * 0.06, ty - 0.03, tz - 0.08), (side * 0.09, ty - 0.07, tz - 0.12),
			(side * 0.06, ty - 0.07, tz - 0.16), (side * 0.04, ty - 0.03, tz - 0.12)], 0.009, "chassis", 5))
	p.append(box(0.06, 0.06, 0.04, "trim", bevel=0.01, at=(0.16, ty + 0.02, tz + 0.02)))
	return p


def axle_rear(name, s, lite=False):
	"""Round the axle's centre (0, 0, 0): x across, z forward."""
	r = s["r"]
	hub = s["track"] / 2 - s["tw"] / 2 - 0.04
	p = []
	segs = 12 if lite else 18
	if name == "Shark":
		# independent rear: the e-motor and diff in one housing, half shafts
		# with their CV boots, the lower arms, coil springs and shocks
		p.append(box(0.42, 0.26, 0.36, "diff", bevel=0.04, at=(0, 0.04, 0.02)))
		p.append(cylinder(0.14, 0.3, "battery", segs).rot("z", math.pi / 2).move(0.15, 0.06, 0.12))
		for side in (1, -1):
			p.append(tube([(side * 0.2, 0.0, 0.0), (side * hub, 0.0, 0.0)], 0.026, "spring", 8))
			for f in (0.28, 0.85):
				p.append(lathe([(0.0, -0.04), (0.05, -0.02), (0.05, 0.02), (0.0, 0.04)], 10, "spring")
					.rot("z", math.pi / 2).move(side * (0.2 + (hub - 0.2) * f), 0, 0))
			p.append(cylinder(0.14, 0.05, "drum", segs).rot("z", math.pi / 2).move(side * (hub - 0.04), 0, 0))
			for dz in (0.2, -0.18):
				p.append(tube([(side * 0.3, -0.04, dz), (side * (hub - 0.06), -0.08, dz * 0.25)], 0.022, "chassis", 6))
			p.append(tube([(side * (hub - 0.16), -0.06, -0.06), (side * (hub - 0.2), 0.36, -0.06)], 0.065, "spring", 8))
			p.append(tube([(side * (hub - 0.1), -0.04, 0.08), (side * (hub - 0.14), 0.38, 0.1)], 0.035, "shock", 8))
		return p
	# a live beam axle: the tubes, the pumpkin with its ribbed cover at the
	# back and the pinion snout forward, brake drums at the ends
	p.append(cylinder(0.045, 2 * hub - 0.1, "diff", 12).rot("z", math.pi / 2).move(hub - 0.05, 0, 0))
	for side in (1, -1):
		p.append(lathe([(0.045, 0.0), (0.075, 0.22), (0.045, 0.3)], 12, "diff", cap_top=False, cap_bottom=False)
			.rot("z", -side * math.pi / 2).move(side * 0.12, 0, 0))
	p.append(sphere(0.15, "diff", segs, 10, s=(1.0, 0.95, 0.85)).move(0.05, -0.01, 0.0))
	p.append(lathe([(0.0, 0.0), (0.13, 0.0), (0.12, 0.05), (0.0, 0.07)], segs, "diff").rot("x", -math.pi / 2)
		.move(0.05, -0.01, -0.1))
	for k in range(4):
		p.append(box(0.012, 0.16, 0.02, "chassis", at=(0.0 + k * 0.035, -0.01, -0.165)))
	p.append(lathe([(0.0, 0.0), (0.07, 0.0), (0.055, 0.18), (0.06, 0.2), (0.075, 0.24), (0.0, 0.25)], 12, "diff")
		.rot("x", -math.pi / 2).rot("x", math.pi).move(0.05, 0.0, 0.08))
	for side in (1, -1):
		p.append(cylinder(0.14, 0.09, "drum", segs).rot("z", math.pi / 2).move(side * hub + (0.0 if side > 0 else 0.09), 0, 0))
		for k in range(5):
			p.append(box(0.012, 0.02, 0.28, "drum", at=(side * (hub - 0.05), 0.0, 0.0)).rot("x", k * math.pi / 5)
				.move(0, 0, 0))
	# leaf springs: a pack of leaves, longest on top, arched with eyes at
	# their ends, clamped to the axle by U-bolts; shocks angled up to the rails
	for side in (1, -1):
		x = side * 0.48
		for k, half in enumerate((0.7, 0.6, 0.48, 0.34, 0.22)):
			y = 0.065 - k * 0.016
			pts = []
			for i in range(11):
				t = -1 + 2 * i / 10
				pts.append((t * half, y + 0.17 * (t * half / 0.7) ** 2))
			for (z0, y0), (z1, y1) in zip(pts, pts[1:]):
				p.append(_beam((x, y0, z0), (x, y1, z1), 0.07, 0.013, "spring", bevel=0.0))
		for zz in (-0.7, 0.7):
			p.append(cylinder(0.025, 0.08, "spring", 8).rot("z", math.pi / 2).move(x + 0.04, 0.24, zz))
		for dx in (-0.045, 0.045):
			p.append(tube([(x + dx, 0.1, -0.05), (x + dx, -0.06, -0.05), (x + dx, -0.06, 0.05), (x + dx, 0.1, 0.05)],
				0.008, "chassis", 5))
		p.append(box(0.1, 0.03, 0.14, "chassis", at=(x, -0.05, 0.0)))
		sx = side * (0.48 - 0.12)
		p.append(tube([(sx, -0.04, -0.12 * side), (sx + side * 0.05, 0.4, -0.2 * side)], 0.032, "shock", 8))
		p.append(tube([(sx, 0.02, -0.12 * side), (sx + side * 0.03, 0.22, -0.16 * side)], 0.042, "shock", 8))
	# the breather hose and the brake line along the housing
	p.append(tube([(0.15, 0.13, 0.0), (0.2, 0.3, 0.08)], 0.008, "spring", 4))
	p.append(tube([(-hub + 0.1, 0.05, 0.03), (hub - 0.1, 0.05, 0.03)], 0.005, "chassis", 4))
	return p


# ------------------------------------------------------------------ aired down

LOW_DROP = 0.035      # how much lower the aired-down tyre's tread sits
LOW_BULGE = 0.022     # how far each sidewall bows out


def air_down(pieces, r, rim_r, w, mat="tyre"):
	"""Lets the air out of a wheel's tyre pieces, the same all round so it can
	still spin: the tread drops LOW_DROP and the sidewalls bow out."""
	def fn(v):
		d = math.hypot(v.y, v.z)
		if d < rim_r * 0.98 or d < 1e-6:
			return (v.x, v.y, v.z)
		t = max(0.0, min(1.0, (d - rim_r) / (r - rim_r)))
		nd = d - LOW_DROP * t
		k = nd / d
		side = 1.0 if v.x > 0 else -1.0
		bul = LOW_BULGE * math.sin(math.pi * min(1.0, t * 1.15)) * min(1.0, abs(v.x) / (w * 0.35))
		return (v.x + side * bul, v.y * k, v.z * k)
	for pc in pieces:
		if pc.mat == mat:
			pc.warp(fn)
	return pieces


def bulge(r, w, mat="tyre", lite=False):
	"""The bottom of an aired-down tyre, which doesn't turn: the flat patch on
	the ground and the sidewalls bagging out over it. Round the hub."""
	p = []
	y = -(r - LOW_DROP)          # where the ground is
	patch = 0.32
	p.append(box(w + 0.01, 0.06, patch, mat, bevel=0.02, at=(0, y + 0.03, 0)))
	n = 6 if lite else 10
	for side in (1, -1):
		pts = []
		for i in range(n + 1):
			a = math.radians(-34 + 68 * i / n)
			rr = r - LOW_DROP - 0.065
			pts.append((side * (w / 2 + LOW_BULGE * 0.6), -math.cos(a) * rr, math.sin(a) * rr))
		p.append(tube(pts, lambda t: 0.028 + 0.03 * math.sin(math.pi * t), mat, 8))
	return p


def main():
	reset()
	made = []
	for name, s in SPECS.items():
		made.append(put(name + "Body", body(name, s, bar=False)))
		bp = []
		_sports_bar(bp, s, s["hw"], s["back_z"] - 0.08)
		made.append(put(name + "SportsBar", bp))
		made.append(put(name + "Wheel", wheel(s)))
		made.append(put(name, body(name, s) + wheels_at(s, False)))
		made.append(put(name + "Lite", body(name, s, True) + wheels_at(s, True)))
		made.append(put(name + "Under", under(name, s)))
		made.append(put(name + "AxleR", axle_rear(name, s)))
		made.append(put(name + "WheelLow", air_down(wheel(s), s["r"], s["r"] * 0.64, s["tw"])))
		made.append(put(name + "WheelBulge", bulge(s["r"], s["tw"])))
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

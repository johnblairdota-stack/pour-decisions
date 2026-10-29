"""4x4 and camping gear for the three utes (assets/cars/ute_kit.glb), bought
with the crew's cash from the shop in their phone wallet.

Run:  python tools/blender/ute_kit.py [--preview DIR]

Every part is fitted to each ute and named kit_<item>_<ute> (ute: hilux,
ranger, shark). Each has the same origin, scale and facing as the utes in
assets/cars/utes.glb (tools/blender/utes.py: on the road under the ute's
middle, front towards +z), so it goes under the ute's body with no offset.

  bullbar     a steel bar across the front: the pan, upright hoops round the
              lamps and a loop over the top
  winch       a drum winch in the bull bar's middle, with the fairlead and a
              red hook (goes with the bull bar)
  spotlights  a pair of round driving lights on the bull bar's top (ditto)
  snorkel     up the left A pillar, the air ram facing forward
  lightbar    an LED bar on the roof's front edge
  mudtyres    ONE whole wheel, centred, axle along x, rim face towards +x as
              the utes' own wheels: a chunky mud terrain tyre 0.045 m taller
              (raise the wheel centres by that) on a black steel rim
  roofrack    a flat platform rack on the cab's roof
  rooftent    a hard shell rooftop tent, closed, on the rack (needs the rack)
  awning      a rolled awning in its bag down the rack's left side (ditto)
  canopy      a powder coated canopy over the tub with lift up side windows
              (hide the sports bar when it's on)
  drawers     a twin drawer unit across the back of the tub, 0.30 m tall
  fridge      a 40 L fridge in the tub's front left corner
  jerrycans   two jerry cans in a holder in the tub's front right corner
  swag        a rolled swag across the back of the tub (on the tub floor:
              raise it 0.30 m when the drawers are in)

"Lift" is no mesh: the game raises the body. Materials are named by role
(scripts/ute_kit.gd paints them); "body" takes the ute's own paint.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import box as _box, build, cylinder, export_glb, lathe, reset, tri_count, tube  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "cars", "ute_kit.glb")

PALETTE = {
	"bar": "1d1f22", "bar_plate": "2a2d31", "steel": "9aa0a6", "light": "eef3f6", "lens": "f6f2dc",
	"amber": "ff9a1f", "hook": "d9302c", "rope": "c9c2b0", "tyre": "1e1e1e", "rim_black": "2a2d31",
	"badge": "d8dde2", "rack": "26292d", "shell": "3a3e44", "canvas": "4a5560", "canopy": "2b2e33",
	"glass": "26323d", "drawer": "2f3338", "carpet": "3a3d40", "handle": "b9bfc4", "fridge": "c4c8cc",
	"fridge_lid": "2b2f36", "jerry": "c8402e", "jerry_d": "e8b830", "swag": "6f6a4a", "strap": "1d1f22",
	"body": "f4f4f2",
}

# The utes' measurements, as tools/blender/utes.py SPECS (length, half width,
# height, wheelbase, front overhang, tyre, the body line heights and where
# the windscreen, roof and cab back are)
SPECS = {
	"hilux": dict(L=5.33, hw=0.905, H=1.815, wb=3.085, front=0.93, track=1.54, r=0.39, tw=0.265,
		nose=0.97, lamp=1.02, cowl=1.11, belt=1.13, tub=1.17, cowl_z=1.3, roof_z=0.44, back_z=-1.07, glass_top=0.70),
	"ranger": dict(L=5.36, hw=0.915, H=1.85, wb=3.22, front=0.93, track=1.56, r=0.39, tw=0.265,
		nose=1.05, lamp=1.08, cowl=1.17, belt=1.19, tub=1.21, cowl_z=1.26, roof_z=0.42, back_z=-1.1, glass_top=0.72),
	"shark": dict(L=5.457, hw=0.96, H=1.925, wb=3.26, front=0.98, track=1.67, r=0.405, tw=0.275,
		nose=1.09, lamp=1.12, cowl=1.21, belt=1.23, tub=1.26, cowl_z=1.24, roof_z=0.36, back_z=-1.14, glass_top=0.76),
}

ITEMS = ["bullbar", "winch", "spotlights", "snorkel", "lightbar", "mudtyres", "roofrack", "rooftent", "awning",
	"canopy", "drawers", "fridge", "jerrycans", "swag"]

MUD_UP = 0.045


def box(sx, sy, sz, mat="white", bevel=0.0, at=(0, 0, 0)):
	"""kit.box, with `bevel` the rounding of the box's longest edges (kit's own
	scales with the box, too much on a long thin one)."""
	return _box(sx, sy, sz, mat, bevel=bevel * min(sx, sy, sz) / max(sx, sy, sz), at=at)


def put(name, pieces):
	return build(name, pieces, PALETTE, None, smooth=False)


class Ute:
	"""Where things are on one ute."""

	def __init__(self, s):
		self.s = s
		self.hw = s["hw"]
		self.nz = s["L"] / 2
		self.tz = -s["L"] / 2
		self.zf = self.nz - s["front"]
		self.zr = self.zf - s["wb"]
		self.H = s["H"]
		self.gt = s["glass_top"]
		self.rz = s["roof_z"]                     # the roof's front
		self.bz = s["back_z"] + 0.03              # the cab's back
		self.t0 = s["back_z"] - 0.08              # the tub, front to back
		self.t1 = self.tz + 0.08
		self.tub = s["tub"]                       # the tub's floor (as modelled: level with its rails)
		self.tw = 2 * self.hw - 0.14              # the tub's inside width
		self.bar_z = self.t0 - 0.12               # the sports bar

	# rack's top
	@property
	def rack_y(self):
		return self.H + 0.11


# ------------------------------------------------------------------ the front

def bullbar(u):
	s = u.s
	p = []
	z = u.nz + 0.07
	w = u.hw - 0.02
	y0, y1 = 0.36, s["nose"] + 0.02
	# the pan: a wide plate across under the grille, wrapping round the corners
	p.append(box(2 * (w - 0.18), 0.2, 0.06, "bar_plate", bevel=0.012, at=(0, y0 + 0.12, z)))
	for side in (1, -1):
		p.append(box(0.24, 0.2, 0.06, "bar_plate", bevel=0.012).rot("y", -side * 0.45)
			.move(side * (w - 0.1), y0 + 0.12, z - 0.07))
	# the main loop over the top, the centre uprights, hoops round the lamps
	r = 0.032
	p.append(tube([(-(w - 0.28), y1, z + 0.02), (-(w - 0.4), y1 + 0.08, z + 0.03), (w - 0.4, y1 + 0.08, z + 0.03),
		(w - 0.28, y1, z + 0.02)], r, "bar", 8))
	for x in (-0.32, 0.32):
		p.append(tube([(x, y0 + 0.2, z), (x, y1 + 0.08, z + 0.03)], r, "bar", 8))
	for side in (1, -1):
		p.append(tube([(side * (w - 0.28), y0 + 0.2, z), (side * (w - 0.28), y1, z + 0.02),
			(side * (w - 0.05), y1 - 0.04, z - 0.12), (side * (w + 0.02), y0 + 0.24, z - 0.18)], r, "bar", 8))
		# a plate under each hoop, an indicator in it
		p.append(box(0.06, 0.05, 0.03, "amber", at=(side * (w - 0.12), y0 + 0.22, z - 0.06)))
	# the mounting tabs for the lights, and the aerial tab
	for side in (1, -1):
		p.append(box(0.08, 0.02, 0.06, "bar_plate", at=(side * 0.45, y1 + 0.09, z + 0.03)))
	# recovery points
	for side in (1, -1):
		p.append(box(0.03, 0.08, 0.08, "hook", at=(side * 0.55, y0 + 0.02, z + 0.01)))
	return p


def winch(u):
	s = u.s
	z = u.nz + 0.08
	y = 0.47
	p = []
	# the drum between its end housings, the motor on the left, the clutch on the right
	p.append(cylinder(0.065, 0.36, "rope", 14).rot("z", math.pi / 2).move(0.18, y, z - 0.02))
	p.append(cylinder(0.075, 0.2, "bar", 14).rot("z", math.pi / 2).move(0.44, y, z - 0.02))
	p.append(box(0.12, 0.17, 0.15, "bar", bevel=0.02, at=(-0.24, y, z - 0.02)))
	p.append(box(0.08, 0.15, 0.15, "bar", bevel=0.02, at=(0.24, y, z - 0.02)))
	# the hawse fairlead on the front of the pan, the hook through it
	p.append(box(0.22, 0.09, 0.03, "steel", bevel=0.01, at=(0, y, z + 0.06)))
	p.append(box(0.12, 0.03, 0.035, "bar", at=(0, y, z + 0.07)))
	p.append(box(0.025, 0.09, 0.025, "hook", at=(0, y - 0.03, z + 0.1)))
	p.append(box(0.06, 0.025, 0.025, "hook", at=(0, y - 0.075, z + 0.1)))
	return p


def spotlights(u):
	s = u.s
	z = u.nz + 0.11
	y = s["nose"] + 0.2
	p = []
	for side in (1, -1):
		x = side * 0.45
		p.append(lathe([(0.0, 0.0), (0.105, 0.0), (0.12, 0.04), (0.12, 0.09), (0.0, 0.09)], 18, "bar")
			.rot("x", math.pi / 2).move(x, y, z - 0.05))
		p.append(cylinder(0.105, 0.012, "lens", 18).rot("x", math.pi / 2).move(x, y, z + 0.045))
		p.append(box(0.02, 0.012, 0.004, "light", at=(x, y, z + 0.052)))
		p.append(box(0.03, 0.09, 0.03, "bar", at=(x, y - 0.1, z - 0.02)))
	return p


def snorkel(u):
	s = u.s
	x = u.hw + 0.05
	gb = u.hw - 0.04
	gx = u.gt + 0.13                               # off the A pillar at the roof
	cz = s["cowl_z"]
	low = (x, s["lamp"] - 0.05, cz + 0.34)         # into the guard, ahead of the windscreen
	pts = [low, (x, s["belt"] + 0.02, cz + 0.12), (gb + 0.11, s["belt"] + 0.2, cz - 0.02),
		(gx, u.H - 0.08, u.rz + 0.12), (gx, u.H + 0.08, u.rz + 0.1)]
	p = [tube(pts, 0.048, "bar", 10)]
	# the guard plate where it goes in, the clamps up the pillar
	p.append(box(0.012, 0.16, 0.2, "bar", bevel=0.004, at=(u.hw + 0.006, s["lamp"] - 0.04, cz + 0.32)))
	for t in (0.45, 0.75):
		a, b = pts[2], pts[3]
		q = [a[i] + (b[i] - a[i]) * t for i in range(3)]
		p.append(box(0.07, 0.03, 0.07, "steel", at=(q[0] - 0.03, q[1], q[2])))
	# the ram head, facing forward, a drain at its back
	hx, hy, hz = gx, u.H + 0.14, u.rz + 0.12
	p.append(box(0.14, 0.15, 0.2, "bar", bevel=0.03, at=(hx, hy, hz)))
	p.append(box(0.1, 0.1, 0.02, "bar_plate", at=(hx, hy + 0.005, hz + 0.105)))
	return p


def lightbar(u):
	w = 2 * u.gt - 0.18
	y = u.H + 0.06
	z = u.rz + 0.03
	p = [box(w, 0.075, 0.08, "bar", bevel=0.012, at=(0, y, z)),
		box(w - 0.04, 0.05, 0.01, "light", at=(0, y, z + 0.042))]
	# the LED cells
	n = 14
	for i in range(n):
		x = -w / 2 + 0.05 + (w - 0.1) * i / (n - 1)
		p.append(box(0.012, 0.05, 0.006, "bar_plate", at=(x, y, z + 0.047)))
	for side in (1, -1):
		p.append(box(0.04, 0.06, 0.1, "bar", at=(side * (w / 2 - 0.08), u.H + 0.015, z - 0.02)))
	return p


def mudtyre(u):
	s = u.s
	r = s["r"] + MUD_UP
	w = s["tw"] + 0.04
	p = []
	prof = [(r * 0.6, -w / 2), (r * 0.88, -w / 2), (r * 0.97, -w / 2 + 0.02), (r - 0.012, -w / 2 + 0.05),
		(r - 0.012, w / 2 - 0.05), (r * 0.97, w / 2 - 0.02), (r * 0.88, w / 2), (r * 0.6, w / 2)]
	p.append(lathe(prof, 24, "tyre", cap_top=False, cap_bottom=False).rot("z", -math.pi / 2))
	# big staggered tread blocks, over the shoulders onto the sidewalls
	n = 18
	for i in range(n):
		a = 2 * math.pi * i / n
		for k, off in enumerate((-0.32, 0.0, 0.32)):
			if (i + k) % 2:
				continue
			p.append(box(w * 0.3, 0.03, 0.11, "tyre", at=(off * w, r + 0.005, 0)).rot("x", a))
		for side in (1, -1):
			p.append(box(0.03, 0.06, 0.07, "tyre", at=(side * (w / 2 - 0.005), r - 0.04, 0)).rot("x", a + (0.5 if side > 0 else 0)))
	# the black steel rim: a dish with round holes, a beadlock ring of bolts
	rr = r * 0.6
	p.append(cylinder(rr, 0.05, "rim_black", 20).rot("z", -math.pi / 2).move(w / 2 - 0.09, 0, 0))
	p.append(lathe([(rr, -0.018), (rr + 0.018, 0.0), (rr, 0.018), (rr - 0.03, 0.0)], 20, "rim_black", loop=True)
		.rot("z", -math.pi / 2).move(w / 2 - 0.035, 0, 0))
	for i in range(16):
		a = 2 * math.pi * i / 16
		p.append(box(0.016, 0.016, 0.016, "badge", at=(w / 2 - 0.02, math.cos(a) * (rr - 0.012), math.sin(a) * (rr - 0.012))))
	for i in range(8):
		a = 2 * math.pi * i / 8 + 0.2
		p.append(cylinder(0.03, 0.012, "tyre", 10).rot("z", -math.pi / 2)
			.move(w / 2 - 0.035, math.cos(a) * rr * 0.62, math.sin(a) * rr * 0.62))
	p.append(cylinder(0.075, 0.05, "rim_black", 12).rot("z", -math.pi / 2).move(w / 2 - 0.02, 0, 0))
	p.append(cylinder(0.035, 0.02, "badge", 8).rot("z", -math.pi / 2).move(w / 2 + 0.03, 0, 0))
	return p


# ------------------------------------------------------------------ the roof

def _rack_span(u):
	return u.rz + 0.02, u.bz + 0.02             # front and back of the rack (z)


def roofrack(u):
	zf, zb = _rack_span(u)
	w = 2 * (u.gt + 0.06)
	y = u.rack_y
	p = []
	# the frame and the slats across it
	for x in (-w / 2, w / 2):
		p.append(box(0.04, 0.035, zf - zb, "rack", at=(x, y, (zf + zb) / 2)))
	for z in (zf, zb):
		p.append(box(w + 0.04, 0.035, 0.04, "rack", at=(0, y, z)))
	n = 7
	for i in range(1, n):
		z = zb + (zf - zb) * i / n
		p.append(box(w, 0.018, 0.08, "rack", at=(0, y + 0.005, z)))
	# the wind deflector at the front
	p.append(box(w - 0.1, 0.08, 0.012, "rack").rot("x", -0.4).move(0, y + 0.03, zf + 0.03))
	# feet on the roof's edges
	for x in (-(u.gt - 0.02), u.gt - 0.02):
		for z in (zf - 0.12, zb + 0.12):
			p.append(box(0.06, y - u.H + 0.01, 0.1, "rack", at=(x, (y + u.H) / 2 - 0.01, z)))
	return p


def rooftent(u):
	zf, zb = _rack_span(u)
	w = 2 * (u.gt + 0.02)
	y = u.rack_y + 0.02
	h = 0.3
	length = zf - zb + 0.2
	zc = (zf + zb) / 2 - 0.05
	p = []
	# the base tray, the canvas between, the hard shell lid, sloped to the front
	p.append(box(w, 0.06, length, "shell", bevel=0.02, at=(0, y + 0.03, zc)))
	p.append(box(w - 0.04, h - 0.12, length - 0.04, "canvas", at=(0, y + 0.06 + (h - 0.12) / 2, zc)))
	lid = box(w + 0.02, 0.07, length + 0.02, "shell", bevel=0.025, at=(0, y + h - 0.03, zc))
	p.append(lid)
	# the ladder clipped down the side, latches, gas struts
	for side in (1, -1):
		p.append(box(0.04, 0.05, 0.06, "rack", at=(side * (w / 2 + 0.01), y + h - 0.08, zc + length / 2 - 0.15)))
		p.append(box(0.04, 0.05, 0.06, "rack", at=(side * (w / 2 + 0.01), y + h - 0.08, zc - length / 2 + 0.15)))
	p.append(box(0.04, 0.03, length * 0.8, "steel", at=(-(w / 2 + 0.03), y + 0.08, zc)))
	return p


def awning(u):
	zf, zb = _rack_span(u)
	x = u.gt + 0.06 + 0.1
	y = u.rack_y - 0.02
	length = (zf - zb) + 0.7
	zc = (zf + zb) / 2 - 0.3
	p = [tube([(x, y, zc - length / 2), (x, y, zc + length / 2)], 0.08, "canvas", 10)]
	# the zip line and end caps, two brackets onto the rack
	p.append(box(0.01, 0.02, length - 0.04, "bar", at=(x + 0.075, y + 0.02, zc)))
	for z in (zc - length / 2, zc + length / 2):
		p.append(cylinder(0.085, 0.04, "bar", 10).rot("x", math.pi / 2).move(x, y, z - 0.02 if z > zc else z + 0.02))
	for z in (zf - 0.15, zb + 0.15):
		p.append(box(0.16, 0.03, 0.05, "rack", at=(x - 0.08, y + 0.04, z)))
	return p


# ------------------------------------------------------------------ the tub

def canopy(u):
	w = 2 * u.hw - 0.02
	y0 = u.tub
	y1 = u.H - 0.02
	length = u.t0 - u.tz - 0.02
	zc = (u.t0 + u.tz) / 2 - 0.01
	p = [box(w, y1 - y0, length, "canopy", bevel=0.02, at=(0, (y0 + y1) / 2, zc))]
	# the gull wing side windows, the back door with its glass, a rack rail on top
	for side in (1, -1):
		p.append(box(0.01, (y1 - y0) * 0.6, length * 0.7, "glass", at=(side * (w / 2 + 0.003), y0 + (y1 - y0) * 0.55, zc + 0.05)))
		p.append(box(0.012, 0.025, length * 0.72, "steel", at=(side * (w / 2 + 0.006), y0 + (y1 - y0) * 0.86, zc + 0.05)))
		p.append(box(0.02, 0.04, 0.14, "handle", at=(side * (w / 2 + 0.012), y0 + (y1 - y0) * 0.22, zc + 0.05)))
		p.append(box(0.04, 0.035, length - 0.1, "rack", at=(side * (w / 2 - 0.1), y1 + 0.02, zc)))
	p.append(box(w - 0.3, (y1 - y0) * 0.5, 0.01, "glass", at=(0, y0 + (y1 - y0) * 0.6, u.tz + 0.005)))
	p.append(box(0.2, 0.035, 0.02, "handle", at=(0, y0 + (y1 - y0) * 0.25, u.tz)))
	# the stop light at the top of the back
	p.append(box(0.3, 0.03, 0.02, "hook", at=(0, y1 - 0.05, u.tz)))
	return p


DRAWER_H = 0.30


def drawers(u):
	w = u.tw - 0.04
	length = 0.95
	z1 = u.t1 + 0.02
	zc = z1 + length / 2
	y = u.tub
	p = [box(w, DRAWER_H, length, "drawer", bevel=0.01, at=(0, y + DRAWER_H / 2, zc)),
		box(w - 0.02, 0.012, length - 0.02, "carpet", at=(0, y + DRAWER_H + 0.004, zc))]
	# two drawer fronts with their handles, the tie down rails on top
	for side in (1, -1):
		x = side * w / 4
		p.append(box(w / 2 - 0.03, DRAWER_H - 0.05, 0.02, "drawer", bevel=0.005, at=(x, y + DRAWER_H / 2, z1 - 0.005)))
		p.append(box(0.16, 0.03, 0.03, "handle", at=(x, y + DRAWER_H * 0.62, z1 - 0.02)))
		p.append(box(0.025, 0.02, length - 0.06, "steel", at=(side * (w / 2 - 0.04), y + DRAWER_H + 0.015, zc)))
	return p


def fridge(u):
	w, h, d = 0.38, 0.47, 0.62
	x = u.tw / 2 - w / 2 - 0.04
	z = u.t0 - d / 2 - 0.04
	y = u.tub
	p = [box(w, h - 0.06, d, "fridge", bevel=0.03, at=(x, y + (h - 0.06) / 2, z)),
		box(w + 0.01, 0.07, d + 0.01, "fridge_lid", bevel=0.025, at=(x, y + h - 0.035, z))]
	# handles at each end, the control panel, the tie down strap
	for e in (1, -1):
		p.append(box(w * 0.5, 0.03, 0.04, "fridge_lid", at=(x, y + h - 0.12, z + e * (d / 2 + 0.01))))
	p.append(box(0.012, 0.08, 0.14, "fridge_lid", at=(x - w / 2 - 0.005, y + h - 0.16, z)))
	p.append(box(w + 0.04, 0.03, 0.04, "strap", at=(x, y + h + 0.01, z)))
	return p


def jerrycans(u):
	cw, ch, cd = 0.165, 0.47, 0.345
	z = u.t0 - cd / 2 - 0.04
	y = u.tub
	p = []
	for i, m in enumerate(("jerry", "jerry_d")):
		x = -(u.tw / 2 - 0.06 - cw / 2) + i * (cw + 0.02)
		p.append(box(cw, ch - 0.06, cd, m, bevel=0.015, at=(x, y + (ch - 0.06) / 2 + 0.02, z)))
		# the X pressed into each side, the three handles, the spout
		for side in (1, -1):
			p.append(box(0.006, 0.36, 0.03, m, at=(x + side * cw / 2, y + ch / 2 - 0.02, z)))
		for hz in (-0.1, 0.0, 0.1):
			p.append(box(0.025, 0.05, 0.05, m, at=(x, y + ch - 0.03, z + hz)))
		p.append(cylinder(0.03, 0.05, "fridge_lid", 10, at=(x, y + ch - 0.05, z + cd / 2 - 0.05)))
	# the holder: a base and a strap over the top
	x0 = -(u.tw / 2 - 0.06)
	x1 = x0 + 2 * cw + 0.02
	p.append(box(x1 - x0 + 0.04, 0.02, cd + 0.04, "bar", at=((x0 + x1) / 2, y + 0.01, z)))
	p.append(box(x1 - x0 + 0.05, 0.03, 0.05, "strap", at=((x0 + x1) / 2, y + ch - 0.01, z)))
	return p


def swag(u):
	r = 0.15
	w = u.tw - 0.06
	z = u.t1 + 0.12 + r
	y = u.tub + r
	p = [tube([(-w / 2, y, z), (w / 2, y, z)], r, "swag", 14)]
	for x in (-w / 2, w / 2):
		p.append(cylinder(r * 0.82, 0.02, "canvas", 14).rot("z", math.pi / 2).move(x + (0.01 if x > 0 else -0.01), y, z))
	for x in (-w * 0.3, w * 0.3):
		p.append(tube([(x, y + math.cos(a) * (r + 0.008), z + math.sin(a) * (r + 0.008))
			for a in [2 * math.pi * k / 12 for k in range(12)]], 0.012, "strap", 4, closed=True))
	p.append(box(0.06, 0.03, 0.04, "steel", at=(-w * 0.3, y + r + 0.01, z)))
	return p


BUILD = {"bullbar": bullbar, "winch": winch, "spotlights": spotlights, "snorkel": snorkel, "lightbar": lightbar,
	"mudtyres": mudtyre, "roofrack": roofrack, "rooftent": rooftent, "awning": awning, "canopy": canopy,
	"drawers": drawers, "fridge": fridge, "jerrycans": jerrycans, "swag": swag}


# ------------------------------------------------------------------ main

def main():
	reset()
	tot = 0
	for ute, s in SPECS.items():
		u = Ute(s)
		for item in ITEMS:
			o = put("kit_%s_%s" % (item, ute), BUILD[item](u))
			t = tri_count([o])
			tot += t
			print("  %-22s %6d triangles" % (o.name, t))
	print("  total %d" % tot)
	if "--preview" in sys.argv:
		_preview(sys.argv[sys.argv.index("--preview") + 1])
	export_glb(OUT)
	print("wrote", OUT)


def _preview(out_dir):
	"""Each ute fully kitted out (and the mud tyres on it), side by side: the
	utes themselves from tools/blender/utes.py, if it's there."""
	import bpy
	from kit import G, preview
	os.makedirs(out_dir, exist_ok=True)
	spots = {"hilux": -2.6, "ranger": 0.0, "shark": 2.6}
	extra = []
	try:
		import utes
		for name, key in (("Hilux", "hilux"), ("Ranger", "ranger"), ("Shark", "shark")):
			s = utes.SPECS[name]
			body = utes.body(name, s)
			extra.append(utes.put("preview_" + key, body))
			for z in (s["L"] / 2 - s["front"], s["L"] / 2 - s["front"] - s["wb"]):
				for side in (1, -1):
					w = build("preview_w_%s_%d_%d" % (key, side, int(z * 10)), mudtyre(Ute(SPECS[key])), PALETTE, None,
						smooth=False)
					w.rotation_euler = (0, 0, math.pi if side < 0 else 0)
					w.location = G(side * s["track"] / 2, s["r"] + MUD_UP, z)
					extra.append(w)
	except ImportError:
		print("  (no utes.py: previewing the kit on its own)")
	lift = 0.08 + MUD_UP
	for o in bpy.context.scene.objects:
		if o.type != "MESH":
			continue
		n = o.name
		key = n.split("_")[-1] if n.startswith("kit_") else None
		if n.startswith("preview_"):
			key = n.split("_")[2] if n.startswith("preview_w_") else n.split("_")[1]
		if key not in spots:
			continue
		if n.startswith("kit_mudtyres") or n.startswith("preview_w_"):
			if n.startswith("kit_mudtyres"):
				o["hidden"] = 1
			o.location = o.location + G(spots[key], 0.08, 0)
			continue
		if n.startswith("kit_swag"):
			o.location = G(spots[key], lift + DRAWER_H, 0)
		else:
			o.location = G(spots[key], lift, 0)
	show = lambda o: "hidden" not in o and not (o.name.startswith("kit_canopy"))
	preview(os.path.join(out_dir, "ute_kit.png"),
		[("front", 25, 12), ("rear", 160, 18), ("side_l", -90, 6), ("high", -40, 35)],
		show=show, target=(0, 1.0, 0), dist=11.5, samples=16)
	show2 = lambda o: "hidden" not in o and not o.name.startswith(("kit_drawers", "kit_fridge", "kit_jerrycans",
		"kit_swag", "kit_rooftent", "kit_awning"))
	preview(os.path.join(out_dir, "ute_kit_canopy.png"), [("rear_canopy", 150, 18)], show=show2,
		target=(0, 1.0, 0), dist=11.5, samples=16)
	for o in extra:
		bpy.data.objects.remove(o, do_unlink=True)
	for o in bpy.context.scene.objects:
		if o.name.startswith("kit_"):
			o.location = G(0, 0, 0)
			if "hidden" in o:
				del o["hidden"]


if __name__ == "__main__":
	main()

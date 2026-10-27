"""The tall plant (assets/plant/towers.glb): the boom tower's lattice sections
and the placing boom on top, the builder's hoist, and the tower crane. Each
part is a top-level node the game picks out with factory.gd's prop(); sizes
and origins match the code that places them.

Run:  python tools/blender/towers.py

MastSection: LW 2.0 square, LS 4.14 tall, base at y 0 (main.gd / climb.gd;
  the crane's 2.2 m mast is the same section scaled). Its chords and faces
  are separate meshes, each with its origin at its own middle, so a dropped
  section can bend apart (climb.gd _wreck / _bend).
BoomCollar: the climbing collar and work deck at the tower head (main.head).
BoomTurret: the slewing unit (main.yaw_node); the first arm pins at y 1.7.
BoomArm1 / BoomArm2: 20 m long out along +x from the pin; the game stretches
  them to the kit's length. BoomTip: the elbow the hose hangs off.
HoistMastSection: 1.5 m of hoist mast, 0.65 square, base at y 0.
HoistCage: 1.6 square floor at y 0, the mast side at -x.
CraneSlew: everything that slews on the tower crane, y 0 at the jib's bottom
  chords, jib out along +x (JIB 52 m), counter jib along -x.
CraneTrolley: rides the jib's bottom chords. CraneHook: the hook block, the
  rope at its top (y 0).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import box, build, cylinder, empty, export_glb, reset, torus, tri_count, tube  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "plant", "towers.glb")

PALETTE = {
	"steel": "afc0d2", "dark_steel": "6b7480", "machine": "ffc72c", "machine_dark": "e0a800",
	"chassis": "24324f", "orange": "ff7a1a", "pipe": "dce1e6", "clamp": "c7d0da", "rubber": "1d1f23",
	"glass": "5b7fa8", "cab": "f4f7fa", "grille": "2b2b2b", "ballast": "a7aaa6", "red": "e5383b",
	"rope": "2b2b2b",
}

LS = 4.14
LW = 2.0
SHOULDER = 1.7
JIB = 52.0
ARM = 20.0


def bar(a, b, r, mat, segs=6):
	return tube([a, b], r, mat, segs)


def put(name, pieces, at=(0, 0, 0), parent=None, smooth=True):
	return build(name, pieces, PALETTE, parent, at=at, smooth=smooth)


def centred(name, pieces, parent, smooth=True):
	"""A mesh whose origin is the middle of its own pieces."""
	n = 0
	s = [0.0, 0.0, 0.0]
	for pc in pieces:
		for v in pc.bm.verts:
			s[0] += v.co.x
			s[1] += v.co.y
			s[2] += v.co.z
			n += 1
	c = (s[0] / n, s[1] / n, s[2] / n)
	for pc in pieces:
		pc.move(-c[0], -c[1], -c[2])
	return put(name, pieces, at=c, parent=parent, smooth=smooth)


# ---------------------------------------------------------------- boom tower

def mast_section():
	root = empty("MastSection")
	h = LW * 0.5
	corners = [(-h, -h), (h, -h), (h, h), (-h, h)]
	# Chords: square hollow section, a bolted flange plate and pin lug each end
	for i, (x, z) in enumerate(corners):
		p = [box(0.16, LS, 0.16, "steel", at=(x, LS * 0.5, z))]
		for y in (0.03, LS - 0.03):
			p.append(box(0.3, 0.06, 0.3, "dark_steel", at=(x, y, z)))
		for y in (0.22, LS - 0.22):
			p.append(box(0.06, 0.3, 0.22, "dark_steel", at=(x - math.copysign(0.1, x), y, z)))
		centred("Chord%d" % i, p, root, smooth=False)
	# Faces: round-tube K lacing and the top and bottom girts
	for i in range(4):
		x1, z1 = corners[i]
		x2, z2 = corners[(i + 1) % 4]
		k = 0.92   # pulled in a touch from the chord centres
		a = (x1 * k, 0, z1 * k)
		b = (x2 * k, 0, z2 * k)
		mid = ((a[0] + b[0]) * 0.5, 0, (a[2] + b[2]) * 0.5)
		p = []
		for y0, y1 in ((0.12, LS * 0.5), (LS * 0.5, LS - 0.12)):
			p.append(bar((a[0], y0, a[2]), (mid[0], y1, mid[2]), 0.045, "steel"))
			p.append(bar((b[0], y0, b[2]), (mid[0], y1, mid[2]), 0.045, "steel"))
		for y in (0.12, LS * 0.5, LS - 0.12):
			p.append(bar((a[0], y, a[2]), (b[0], y, b[2]), 0.05 if y != LS * 0.5 else 0.035, "steel"))
		centred("Face%d" % i, p, root)


def boom_collar():
	p = []
	# The collar that clamps the tower head, then the deck plate on top
	for s in (-1, 1):
		p.append(box(2.5, 0.5, 0.2, "machine_dark", bevel=0.03, at=(0, -0.2, s * 1.15)))
		p.append(box(0.2, 0.5, 2.5, "machine_dark", bevel=0.03, at=(s * 1.15, -0.2, 0)))
	p.append(box(3.8, 0.14, 3.8, "machine_dark", bevel=0.03, at=(0, 0.13, 0)))
	for s in (-1, 1):
		p.append(box(3.8, 0.12, 0.04, "orange", at=(0, 0.26, s * 1.88)))
		p.append(box(0.04, 0.12, 3.8, "orange", at=(s * 1.88, 0.26, 0)))
	# Handrails: posts, top and mid rails
	for x in (-1.85, -0.62, 0.62, 1.85):
		for s in (-1, 1):
			p.append(bar((x, 0.2, s * 1.85), (x, 1.07, s * 1.85), 0.03, "orange"))
			p.append(bar((s * 1.85, 0.2, x), (s * 1.85, 1.07, x), 0.03, "orange"))
	for y, r in ((1.05, 0.04), (0.62, 0.028)):
		ring = [(-1.85, y, -1.85), (1.85, y, -1.85), (1.85, y, 1.85), (-1.85, y, 1.85)]
		for i in range(4):
			p.append(bar(ring[i], ring[(i + 1) % 4], r, "orange"))
	put("BoomCollar", p)


def boom_turret():
	p = []
	# Slew ring and the turret on it
	p.append(cylinder(0.95, 0.22, "dark_steel", 24, bevel=0.03, at=(0, 0.18, 0)))
	p.append(torus(0.98, 0.05, "grille", 24, 4, at=(0, 0.3, 0)))
	body = box(2.2, 1.05, 2.2, "machine", bevel=0.12, at=(0, 0.92, 0))
	body.paint("machine_dark", lambda c: c.y < 0.5)
	p.append(body)
	# Counterweight and hydraulic tank at the back
	p.append(box(0.7, 0.9, 1.9, "ballast", bevel=0.08, at=(-1.35, 0.85, 0)))
	p.append(box(0.5, 0.55, 0.6, "dark_steel", bevel=0.05, at=(-0.6, 1.72, -0.55)))
	p.append(cylinder(0.06, 0.12, "grille", 8, at=(-0.6, 2.0, -0.55)))
	# The pin brackets the first arm hangs in
	for z in (-0.42, 0.42):
		p.append(box(1.0, 0.75, 0.1, "machine_dark", bevel=0.03, at=(0.05, 1.65, z)))
	p.append(cylinder(0.12, 1.0, "dark_steel", 12).rot("x", math.pi / 2).move(0, SHOULDER, -0.5))
	# Pipe up through the turret to the boom
	p.append(tube([(0.0, 0.0, 0.75), (0.0, 1.55, 0.75), (0.25, 2.05, 0.6)], 0.075, "pipe", 10))
	p.append(torus(0.09, 0.03, "clamp", 10, 5, at=(0.0, 1.45, 0.75)))
	put("BoomTurret", p)


def tapered_box(length, h0, h1, w0, w1, mat, y=0.0):
	b = box(length, 1.0, 1.0, mat, bevel=0.06, at=(length * 0.5, 0, 0))

	def fn(v):
		t = max(0.0, min(1.0, v.x / length))
		return (v.x, y + v.y * (h0 + (h1 - h0) * t), v.z * (w0 + (w1 - w0) * t))
	return b.warp(fn)


def boom_arm(name, h0, h1, w0, w1, ram_top):
	p = [tapered_box(ARM, h0, h1, w0, w1, "machine")]
	# Pin bosses at each end
	p.append(cylinder(h0 * 0.48, w0 + 0.12, "chassis", 14).rot("x", math.pi / 2).move(0, 0, -(w0 + 0.12) * 0.5))
	p.append(cylinder(h1 * 0.5, w1 + 0.1, "chassis", 14).rot("x", math.pi / 2).move(ARM, 0, -(w1 + 0.1) * 0.5))
	# The luffing ram: under the first arm, over the knuckle on the second
	sy = 1 if ram_top else -1
	ry = sy * (h0 * 0.5 + 0.2)
	p.append(box(0.3, 0.22, 0.26, "chassis", bevel=0.03, at=(0.9, sy * (h0 * 0.5 + 0.08), 0)))
	p.append(cylinder(0.15, 3.4, "machine_dark", 12).rot("z", -math.pi / 2).move(1.0, ry, 0))
	p.append(cylinder(0.075, 2.6, "steel", 10).rot("z", -math.pi / 2).move(4.3, ry, 0))
	p.append(box(0.3, 0.22, 0.26, "chassis", bevel=0.03, at=(6.9, sy * (h0 * 0.5 + 0.02), 0)))
	# The delivery pipe along the side, clamped every 3 m
	pz = (w0 * 0.5 + 0.1)
	p.append(bar((-0.2, 0.05, pz), (ARM - 0.3, 0.05, pz), 0.065, "pipe", 10))
	x = 1.5
	while x < ARM:
		p.append(torus(0.075, 0.025, "clamp", 10, 5).rot("z", math.pi / 2).move(x, 0.05, pz))
		p.append(box(0.08, 0.06, 0.12, "dark_steel", at=(x, 0.05, pz - 0.08)))
		x += 3.0
	put(name, p)


def boom_tip():
	p = [tube([(-0.35, 0.05, 0.38), (-0.05, 0.05, 0.38), (0.12, -0.05, 0.2), (0.0, -0.3, 0.0)], 0.07, "pipe", 10)]
	p.append(torus(0.085, 0.03, "clamp", 10, 5, at=(0.0, -0.28, 0.0)))
	p.append(cylinder(0.12, 0.16, "dark_steel", 12, bevel=0.02, at=(0, -0.45, 0)))
	p.append(cylinder(0.19, 0.08, "rubber", 12, bevel=0.02, at=(0, -0.52, 0)))
	put("BoomTip", p)


# ---------------------------------------------------------------- hoist

HOIST_SEC = 1.5


def hoist_mast_section():
	w = 0.325
	cs = [(-w, -w), (w, -w), (w, w), (-w, w)]
	p = []
	for x, z in cs:
		p.append(bar((x, 0, z), (x, HOIST_SEC, z), 0.038, "steel", 8))
		p.append(cylinder(0.06, 0.03, "dark_steel", 8, at=(x, HOIST_SEC - 0.03, z)))
	for i in range(4):
		x1, z1 = cs[i]
		x2, z2 = cs[(i + 1) % 4]
		p.append(bar((x1, 0.05, z1), (x2, HOIST_SEC * 0.5, z2), 0.015, "steel"))
		p.append(bar((x2, HOIST_SEC * 0.5, z2), (x1, HOIST_SEC - 0.05, z1), 0.015, "steel"))
		p.append(bar((x1, 0.05, z1), (x2, 0.05, z2), 0.018, "steel"))
	# The rack the cage climbs on, up the cage side (+x)
	p.append(box(0.06, HOIST_SEC, 0.08, "dark_steel", at=(w + 0.06, HOIST_SEC * 0.5, 0)))
	p.append(box(0.03, HOIST_SEC, 0.1, "grille", at=(w + 0.1, HOIST_SEC * 0.5, 0)))
	put("HoistMastSection", p)


def hoist_cage():
	p = []
	H = 2.3
	p.append(box(1.6, 0.1, 1.6, "chassis", bevel=0.02, at=(0, 0.05, 0)))
	p.append(box(1.62, 0.08, 1.62, "chassis", bevel=0.02, at=(0, H, 0)))
	for cx in (-0.78, 0.78):
		for cz in (-0.78, 0.78):
			p.append(box(0.07, H, 0.07, "machine_dark", at=(cx, H * 0.5, cz)))
	# Mesh walls as bars on the far sides, gates (bars, a mid rail) on ±z
	for side in ("x+", "x-", "z+", "z-"):
		for k in range(1, 8):
			t = -0.78 + k * 1.56 / 8
			if side[0] == "x":
				x = 0.78 if side[1] == "+" else -0.78
				p.append(bar((x, 0.1, t), (x, H - 0.05, t), 0.012, "dark_steel", 4))
			else:
				z = 0.78 if side[1] == "+" else -0.78
				p.append(bar((t, 0.1, z), (t, H - 0.05, z), 0.012, "dark_steel", 4))
		for y in (1.1, 0.12):
			if side[0] == "x":
				x = 0.78 if side[1] == "+" else -0.78
				p.append(box(0.05, 0.06, 1.56, "machine_dark", at=(x, y, 0)))
			else:
				z = 0.78 if side[1] == "+" else -0.78
				p.append(box(1.56, 0.06, 0.05, "machine_dark", at=(0, y, z)))
	# The drive on the roof by the mast: two motors and the gearbox
	p.append(box(0.5, 0.6, 1.2, "machine", bevel=0.06, at=(-0.62, H + 0.35, 0)))
	for z in (-0.35, 0.35):
		p.append(cylinder(0.15, 0.45, "dark_steel", 12, bevel=0.02).rot("z", math.pi / 2).move(-0.2, H + 0.45, z))
	# Roof rail, and an orange beacon
	for s in (-1, 1):
		p.append(bar((-0.75, H + 1.0, s * 0.78), (0.78, H + 1.0, s * 0.78), 0.025, "orange"))
		p.append(bar((0.78, H, s * 0.78), (0.78, H + 1.0, s * 0.78), 0.025, "orange"))
	p.append(bar((0.78, H + 1.0, -0.78), (0.78, H + 1.0, 0.78), 0.025, "orange"))
	p.append(cylinder(0.07, 0.12, "orange", 10, bevel=0.02, at=(0.3, H + 0.04, 0.55)))
	put("HoistCage", p)


# ---------------------------------------------------------------- tower crane

def crane_slew():
	p = []
	y = "machine"
	# Turntable and the slewing platform on the mast top
	p.append(box(2.6, 0.7, 2.6, "machine_dark", bevel=0.08, at=(0, -0.85, 0)))
	p.append(cylinder(1.25, 0.3, "dark_steel", 20, bevel=0.03, at=(0, -1.35, 0)))
	p.append(box(2.4, 0.5, 2.4, y, bevel=0.06, at=(0, -0.1, 0)))
	# Jib: triangular truss, bottom chords (the trolley's rails) at z ±0.7
	for z in (-0.7, 0.7):
		p.append(box(JIB, 0.2, 0.2, y, at=(JIB * 0.5, 0, z)))
	p.append(bar((0, 1.4, 0), (JIB - 0.5, 1.4, 0), 0.09, y, 6))
	x = 0.0
	while x < JIB - 1.0:
		for z in (-0.7, 0.7):
			p.append(bar((x, 0.05, z), (x + 1.0, 1.38, 0), 0.04, y, 5))
			p.append(bar((x + 1.0, 1.38, 0), (x + 2.0, 0.05, z), 0.04, y, 5))
		p.append(bar((x, 0.0, -0.7), (x, 0.0, 0.7), 0.035, y, 5))
		x += 2.0
	p.append(box(0.3, 1.6, 1.6, "machine_dark", at=(JIB, 0.6, 0)))
	# Counter jib: a walkway deck with rails, the hoist winch, counterweights
	p.append(box(16.0, 0.5, 1.6, y, bevel=0.04, at=(-8.0, 0.25, 0)))
	for s in (-1, 1):
		p.append(bar((-15.5, 1.5, s * 0.8), (-1.2, 1.5, s * 0.8), 0.04, "orange"))
		xx = -15.5
		while xx <= -1.0:
			p.append(bar((xx, 0.5, s * 0.8), (xx, 1.5, s * 0.8), 0.03, "orange"))
			xx += 2.4
	for i in range(4):
		p.append(box(0.62, 2.4, 2.1, "ballast", bevel=0.05, at=(-14.3 + i * 0.66, -0.3, 0)))
	p.append(cylinder(0.45, 1.3, "dark_steel", 16, bevel=0.03).rot("x", math.pi / 2).move(-9.0, 0.95, -0.65))
	p.append(box(1.2, 0.9, 0.9, "machine_dark", bevel=0.05, at=(-10.6, 0.95, 0)))
	p.append(box(1.0, 1.2, 0.6, "cab", bevel=0.05, at=(-6.5, 1.1, 0.4)))
	# The tower head (an A frame up to 7 m) and its pendant ties
	for x0 in (-1.0, 1.0):
		for z0 in (-0.9, 0.9):
			p.append(bar((x0, 0.3, z0), (0, 7.0, 0), 0.09, y, 6))
	for yy in (2.5, 4.7):
		f = 1.0 - (yy - 0.3) / 6.7
		ring = [(-f, yy, -0.9 * f), (f, yy, -0.9 * f), (f, yy, 0.9 * f), (-f, yy, 0.9 * f)]
		for i in range(4):
			p.append(bar(ring[i], ring[(i + 1) % 4], 0.04, y, 5))
	p.append(box(0.4, 0.4, 0.4, "machine_dark", at=(0, 7.0, 0)))
	p.append(cylinder(0.08, 0.3, "red", 8, at=(0, 7.2, 0)))
	for z in (-0.12, 0.12):
		p.append(bar((0, 7.0, z), (JIB * 0.7, 1.4, 0), 0.04, "steel", 5))
		p.append(bar((0, 7.0, z), (-15.0, 0.6, z * 4), 0.04, "steel", 5))
	# Operator's cab, slung off the turntable on the jib side
	cab = box(2.2, 2.2, 2.0, "cab", bevel=0.1, at=(1.4, -1.6, 1.6))
	p.append(cab)
	p.append(box(0.05, 1.2, 1.7, "glass", at=(2.51, -1.35, 1.6)))
	p.append(box(1.7, 1.1, 0.05, "glass", at=(1.5, -1.3, 2.61)))
	p.append(box(1.4, 0.05, 1.4, "glass", at=(1.4, -2.71, 1.6)))
	p.append(box(2.3, 0.12, 0.08, "machine", at=(1.4, -0.45, 2.63)))
	# Jib name board
	p.append(box(5.0, 1.0, 0.08, "cab", at=(4.0, 0.7, 0.72)))
	p.append(box(5.0, 1.0, 0.08, "cab", at=(4.0, 0.7, -0.72)))
	put("CraneSlew", p, smooth=False)


def crane_trolley():
	p = [box(1.4, 0.18, 1.8, "machine_dark", bevel=0.03, at=(0, 0.2, 0))]
	for z in (-0.7, 0.7):
		for x in (-0.5, 0.5):
			p.append(cylinder(0.11, 0.1, "dark_steel", 10).rot("x", math.pi / 2).move(x, 0.18, z + 0.13))
		p.append(box(1.3, 0.4, 0.08, "machine_dark", at=(0, -0.05, z * 0.75)))
	for x in (-0.25, 0.25):
		p.append(cylinder(0.22, 0.1, "dark_steel", 14).rot("x", math.pi / 2).move(x, -0.35, -0.05))
	put("CraneTrolley", p)


def crane_hook():
	p = []
	# Sheave block: two cheek plates round the sheaves, stripes so it shows
	cheek = box(0.62, 0.62, 0.36, "machine", bevel=0.06, at=(0, -0.25, 0))
	cheek.paint("grille", lambda c: ((c.x + c.y) * 3.0) % 1.0 < 0.5 and abs(c.z) > 0.17)
	p.append(cheek)
	p.append(cylinder(0.08, 0.44, "dark_steel", 10).rot("x", math.pi / 2).move(0, -0.25, -0.22))
	p.append(box(0.22, 0.1, 0.22, "dark_steel", bevel=0.02, at=(0, -0.6, 0)))
	# The hook, with its safety latch
	pts = [(0, -0.62, 0), (0, -0.72, 0)]
	for k in range(11):
		a = math.pi * k / 10.0
		pts.append((-0.12 + math.cos(a) * 0.12, -0.84 - math.sin(a) * 0.12, 0))
	p.append(tube(pts, lambda t: 0.05 - 0.025 * t, "dark_steel", 8))
	p.append(bar((0.0, -0.74, 0), (-0.22, -0.82, 0), 0.012, "red", 4))
	put("CraneHook", p)


def main():
	reset()
	mast_section()
	boom_collar()
	boom_turret()
	boom_arm("BoomArm1", 0.7, 0.5, 0.56, 0.46, False)
	boom_arm("BoomArm2", 0.5, 0.34, 0.44, 0.34, True)
	boom_tip()
	hoist_mast_section()
	hoist_cage()
	crane_slew()
	crane_trolley()
	crane_hook()
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

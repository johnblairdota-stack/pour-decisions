"""The plant (assets/plant/plant.glb): the agitator truck and the trailer line
pump. Each part is a top-level node the game picks out with factory.gd's
prop(); sizes and origins match the code-built versions in line.gd.

Run:  python tools/blender/plant.py

Truck frame (line.gd _truck_mesh): +x is the front (cab), the drum's tail
and chute at -x; wheels r 0.55 at x 2.8, -1.6, -2.8. Drum: its own node,
centred, axis along x (the game tilts and spins it).
Pump frame (line.gd _build_pump, PUMP_POS): hopper end at +x (3.3, where
trucks back in), towing end and line outlet at -x.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import (arc_points, box, build, cylinder, export_glb, extrude, lathe, reset, rounded_rect,  # noqa: E402
	sphere, tri_count, torus, tube)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "plant", "plant.glb")

PALETTE = {
	"cab": "f4f7fa", "glass": "5b7fa8", "chassis": "24324f", "tyre": "1d1f23", "rim": "c9d1d8",
	"drum": "e8ebee", "livery": "ff7a1a", "steel": "afc0d2", "dark_steel": "6b7480", "grille": "2b2b2b",
	"light": "fff4c2", "tail": "e5383b", "amber": "ffb020", "machine": "ffc72c", "machine_dark": "e0a800",
	"wet_crust": "9b968a", "rubber": "1d1f23", "water": "4f8fbf",
}


def put(name, pieces, at=(0, 0, 0)):
	return build(name, pieces, PALETTE, None, at=at)


def wheel(x, y, z, r=0.55, w=0.4, dual=False):
	"""A tyre with a rim, its axle across z."""
	out = []
	for k in ([-1, 1] if dual else [0]):
		zz = z + k * w * 0.52
		tyre = torus(r - 0.17, 0.17, "tyre", 16, 6).scale(1, w / 0.34, 1)
		rim = cylinder(r * 0.55, w * 0.9, "rim", 12).move(0, -w * 0.45, 0)
		hub = cylinder(r * 0.2, w * 1.0, "dark_steel", 8).move(0, -w * 0.5, 0)
		for pc in (tyre, rim, hub):
			pc.rot("x", math.pi / 2).move(x, y, zz)
			out.append(pc)
	return out


# ---------------------------------------------------------------- agitator

def truck():
	p = []
	# Chassis rails, bumpers, mudguards, fuel and water tanks
	for z in (-0.45, 0.45):
		p.append(box(7.5, 0.28, 0.18, "chassis", bevel=0.03, at=(0, 0.82, z)))
	p.append(box(0.3, 0.3, 2.35, "chassis", bevel=0.05, at=(3.78, 0.7, 0)))
	p.append(box(0.18, 0.18, 2.2, "chassis", bevel=0.04, at=(-3.75, 0.72, 0)))
	for x in (-1.6, -2.8):
		for s in (-1, 1):
			p.append(box(0.9 if x == -2.8 else 0.8, 0.06, 0.55, "chassis", bevel=0.02, at=(x, 1.2, s * 1.0)))
	p.append(box(2.4, 0.08, 0.6, "chassis", bevel=0.02, at=(-2.2, 1.2, 0.95)).move(0, 0, 0))
	p.append(cylinder(0.32, 1.1, "steel", 16, bevel=0.06).rot("z", math.pi / 2).move(0.95, 0.85, 1.0))
	p.append(box(0.8, 0.55, 0.55, "water", bevel=0.08, at=(1.35, 1.35, -0.75)))
	# Cab-over cab: rounded box, big windscreen, side windows, grille,
	# headlights, mirrors, roof marker lights
	p.append(box(1.9, 2.0, 2.3, "cab", bevel=0.14, at=(2.9, 2.05, 0)))
	# Windscreen and door windows, set just proud of the cab
	p.append(box(0.03, 0.75, 2.0, "glass", at=(3.86, 2.55, 0)))
	for s in (-1, 1):
		p.append(box(0.8, 0.65, 0.03, "glass", at=(3.2, 2.55, s * 1.16)))
		p.append(box(0.04, 0.9, 0.03, "grille", at=(2.75, 1.85, s * 1.16)))
	p.append(box(0.06, 0.5, 1.6, "grille", bevel=0.02, at=(3.87, 1.5, 0)))
	for s in (-1, 1):
		p.append(box(0.06, 0.18, 0.35, "light", bevel=0.03, at=(3.87, 1.25, s * 0.85)))
		p.append(box(0.06, 0.12, 0.12, "amber", bevel=0.02, at=(3.87, 1.25, s * 1.08)))
		p.append(tube([(3.7, 2.5, s * 1.15), (3.95, 2.5, s * 1.35), (3.95, 2.0, s * 1.38)], 0.025, "dark_steel", 6))
		p.append(box(0.06, 0.4, 0.18, "grille", bevel=0.02, at=(3.97, 2.25, s * 1.4)))
		# Step and grab handle up to the door
		p.append(box(0.4, 0.05, 0.22, "dark_steel", bevel=0.01, at=(3.2, 0.9, s * 1.1)))
	for z in (-0.6, -0.2, 0.2, 0.6):
		p.append(box(0.08, 0.06, 0.12, "amber", bevel=0.02, at=(3.6, 3.1, z)))
	# The pedestal the drum sits in, front and rear, and a ladder up the back
	p.append(box(0.35, 1.3, 1.6, "chassis", bevel=0.05, at=(1.55, 1.75, 0)))
	p.append(box(0.35, 1.0, 1.6, "chassis", bevel=0.05, at=(-2.85, 1.55, 0)))
	for z in (-0.25, 0.25):
		p.append(tube([(-3.4, 0.6, z), (-3.15, 3.4, z)], 0.025, "steel", 6))
	for k in range(8):
		y = 0.8 + k * 0.33
		x = -3.4 + 0.25 * (y - 0.6) / 2.8
		p.append(tube([(x, y, -0.25), (x, y, 0.25)], 0.018, "steel", 6))
	# Loading hopper (charging funnel) over the drum mouth, and the fixed
	# chute under it, swinging out at -3.95
	p.append(lathe([(0.08, 3.05), (0.35, 3.3), (0.45, 3.6), (0.48, 3.65)], 12, "steel", cap_top=False,
		cap_bottom=False).move(-3.25, 0, 0))
	chute = extrude([(-0.25, 0.1), (-0.25, 0.0), (-0.18, -0.07), (0.18, -0.07), (0.25, 0.0), (0.25, 0.1),
		(0.21, 0.1), (0.21, 0.02), (0.16, -0.03), (-0.16, -0.03), (-0.21, 0.02), (-0.21, 0.1)], -4.6, -3.3, "steel")
	chute.move(0, 1.7, 0)
	p.append(chute)
	p.append(box(0.2, 1.2, 0.2, "dark_steel", bevel=0.03, at=(-3.45, 2.3, 0)))
	# Concrete crusted round the drum mouth and the chute
	p.append(sphere(0.18, "wet_crust", 10, 6, at=(-4.1, 1.75, 0.05), s=(2.0, 0.4, 1.0)))
	# Tail lights
	for s in (-1, 1):
		p.append(box(0.06, 0.15, 0.3, "tail", bevel=0.02, at=(-3.86, 0.75, s * 0.9)))
	# Wheels: steer axle at the front, twin drive axles (dual tyres) at the back
	for x in (2.8, -1.6, -2.8):
		for s in (-1, 1):
			p.extend(wheel(x, 0.55, s * (1.2 if x == 2.8 else 1.0), dual=x != 2.8))
	put("Truck", p)
	# The drum: pear-shaped, livery bands, the spiral weld showing outside
	prof = [(0.0, -2.35), (0.5, -2.3), (0.85, -2.0), (1.1, -1.3), (1.18, -0.4), (1.15, 0.4), (1.0, 1.2),
		(0.75, 1.85), (0.5, 2.2), (0.42, 2.3), (0.0, 2.32)]
	# (finer rings so the painted spiral reads)
	fine = []
	for (r0, y0), (r1, y1) in zip(prof, prof[1:]):
		for k in range(3):
			u = k / 3
			fine.append((r0 + (r1 - r0) * u, y0 + (y1 - y0) * u))
	fine.append(prof[-1])
	drum = lathe(fine, 40, "drum")
	# The supplier's livery: a broad spiral stripe round the drum, as
	# real agitators carry it (it shows the drum turning)
	drum.paint("livery", lambda c: -1.9 < c.y < 1.9 and
		((math.atan2(c.x, c.z) / (2 * math.pi) - c.y / 3.0) % 1.0) < 0.22)
	ring = torus(1.19, 0.05, "dark_steel", 24, 6, at=(0, -0.9, 0))
	parts = [drum, ring]
	for pc in parts:
		pc.rot("z", math.pi / 2)   # axis along x, the narrow end (mouth) at -x
	put("TruckDrum", parts)
	# The chute extension, hung at its root, reaching back along -x
	ext = extrude([(-0.21, 0.08), (-0.21, 0.0), (-0.15, -0.05), (0.15, -0.05), (0.21, 0.0), (0.21, 0.08),
		(0.18, 0.08), (0.18, 0.02), (0.13, -0.02), (-0.13, -0.02), (-0.18, 0.02), (-0.18, 0.08)], -1.6, 0.0,
		"steel")
	put("ChuteExt", [ext, box(0.1, 0.12, 0.5, "dark_steel", bevel=0.02, at=(-0.02, 0.03, 0))])


# ---------------------------------------------------------------- line pump

def line_pump():
	p = []
	# Trailer chassis with a drawbar to the front (-x), jack legs at the
	# corners, a toolbox, the engine canopy with louvres and doors
	for z in (-0.7, 0.7):
		p.append(box(5.6, 0.25, 0.16, "chassis", bevel=0.03, at=(0.6, 0.72, z)))
	p.append(tube([(-2.2, 0.72, -0.7), (-3.1, 0.62, 0.0), (-2.2, 0.72, 0.7)], 0.07, "chassis", 8))
	p.append(torus(0.08, 0.025, "dark_steel", 10, 5, at=(-3.15, 0.6, 0)))
	for x, z in ((-2.0, -0.95), (-2.0, 0.95), (3.0, -0.95), (3.0, 0.95)):
		p.append(box(0.18, 0.7, 0.18, "machine_dark", bevel=0.03, at=(x, 0.45, z)))
		p.append(box(0.35, 0.05, 0.35, "dark_steel", bevel=0.01, at=(x, 0.06, z)))
	canopy = box(3.6, 1.7, 2.0, "machine", bevel=0.12, at=(0.2, 1.75, 0))
	canopy.paint("grille", lambda c: abs(c.z) > 0.95 and 1.1 < c.y < 1.5 and 1.0 < c.x < 1.9)
	canopy.paint("machine_dark", lambda c: abs(c.z) > 0.95 and 1.0 < c.y < 2.45 and -1.4 < c.x < -0.6)
	p.append(canopy)
	for x in (-1.0, 0.0, 1.0):
		for s in (-1, 1):
			p.append(box(0.04, 1.3, 0.03, "machine_dark", at=(x + 0.5, 1.75, s * 1.0)))
	# Exhaust stack and the radiator cap on the roof
	p.append(cylinder(0.07, 0.5, "dark_steel", 10, at=(-0.8, 2.55, -0.6)))
	p.append(cylinder(0.09, 0.08, "grille", 10, bevel=0.02, at=(-0.8, 3.05, -0.6)))
	p.append(box(0.9, 1.2, 1.6, "machine_dark", bevel=0.1, at=(-1.9, 1.4, 0)))
	p.append(box(0.5, 0.5, 0.3, "grille", bevel=0.04, at=(-1.9, 1.5, 0.82)))
	# The pumping end: two delivery cylinders under the canopy to the S-valve
	# box at the hopper, and the outlet pipe off the front
	for z in (-0.35, 0.35):
		p.append(cylinder(0.14, 1.3, "steel", 14).rot("z", math.pi / 2).move(2.6, 0.95, z))
	p.append(box(0.5, 0.6, 1.1, "dark_steel", bevel=0.06, at=(2.25, 1.05, 0)))
	p.append(tube([(-2.35, 1.0, 0.0), (-2.7, 1.0, 0.0), (-2.9, 0.9, 0.0)], 0.07, "steel", 10))
	p.append(torus(0.08, 0.025, "dark_steel", 10, 5, at=(-2.7, 1.0, 0)).rot("z", 0.0))
	# Wheels (single axle pair)
	for x in (1.2, 2.3):
		for s in (-1, 1):
			p.extend(wheel(x, 0.45, s * 1.05, r=0.45, w=0.35))
	for s in (-1, 1):
		p.append(box(1.6, 0.06, 0.4, "chassis", bevel=0.02, at=(1.75, 0.95, s * 1.05)))
	put("LinePump", p)
	# The hopper (its own node, at HOPPER): a tapered bin, a grate on top,
	# the floor at 0.9 where the game's concrete level sits
	bin_ = lathe([(0.0, 0.86), (0.62, 0.86), (0.7, 0.9), (0.95, 1.8), (1.0, 1.85), (0.94, 1.85), (0.66, 0.94),
		(0.0, 0.94)], 4, "machine_dark", cap_top=False, cap_bottom=True)
	bin_.rot("y", math.pi / 4).scale(0.85, 1, 0.95)
	grate = []
	for i in range(5):
		grate.append(tube([(-0.78, 1.84, -0.7 + i * 0.35), (0.78, 1.84, -0.7 + i * 0.35)], 0.022, "steel", 6))
	grate.append(tube([(0.0, 1.84, -0.85), (0.0, 1.84, 0.85)], 0.03, "steel", 6))
	crust = box(1.55, 0.04, 0.12, "wet_crust", bevel=0.01, at=(0, 1.86, 0.88))
	put("PumpHopper", [bin_, *grate, crust])


def main():
	reset()
	truck()
	line_pump()
	import bpy
	for o in bpy.context.scene.objects:
		if o.type == "MESH":
			print("  %-12s %5d triangles" % (o.name, tri_count([o])))
	export_glb(OUT)
	print("wrote", OUT)


if __name__ == "__main__":
	main()

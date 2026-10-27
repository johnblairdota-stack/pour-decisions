"""Tools and site props (assets/props/props.glb): each a top-level node the
game picks out by name with factory.gd's prop().

Run:  python tools/blender/props.py

Sizes match the code-built versions they replace (screed.gd, poker.gd,
line.gd, slump.gd), so nothing moves: same origins, same reach.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from kit import (arc_points, box, build, cylinder, empty, export_glb, extrude, lathe, reset,  # noqa: E402
	rounded_rect, sphere, tri_count, torus, tube)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "props", "props.glb")

# Preview colours only: the game paints these from factory.gd (PROP_COLORS)
PALETTE = {
	"alu": "c9d1d8", "grip": "22262b", "steel": "afc0d2", "dark_steel": "6b7480", "machine": "ffc72c",
	"fuel": "e5383b", "rubber": "1d1f23", "pipe": "dce1e6", "clamp": "c7d0da", "bin": "2f6fd1",
	"bin_dark": "24559f", "rack": "e0a800", "tray": "2f8f6b", "wet": "8f949b", "timber": "b98a55",
	"barrow": "3d7a4a", "tyre": "1d1f23", "rope": "d9c27a", "chain": "8a929c", "red": "e5383b",
	"bucket": "2b2b2b", "wet_crust": "9b968a",
}


def put(name, pieces, at=(0, 0, 0)):
	return build(name, pieces, PALETTE, None, at=at)


# ---------------------------------------------------------------- the screeder's board

def screed_board():
	# 1 m of aluminium box-section screed (the game stretches it to length):
	# a tall box with ribs down its face, a wider foot that does the striking
	body = rounded_rect(0.05, 0.11, 0.008)
	foot = [(-0.03, -0.0675), (0.09, -0.0675), (0.09, -0.0505), (0.03, -0.042), (-0.03, -0.042)]
	parts = [extrude(body, -0.5, 0.5, "alu"), extrude(foot, -0.5, 0.5, "alu")]
	for y in (-0.015, 0.02):
		parts.append(extrude(rounded_rect(0.056, 0.008, 0.003, 1, 0, y), -0.5, 0.5, "dark_steel"))
	for x in (-0.5, 0.5):
		parts.append(box(0.012, 0.115, 0.056, "grip", bevel=0.003, at=(x, 0, 0)))
	put("ScreedBoard", parts)
	# A D-handle, bolted on top and leaning back
	grip = tube([(0, 0.0, 0.03), (0, 0.06, 0.0), (0, 0.075, -0.07), (0, 0.05, -0.13), (0, 0.0, -0.15)], 0.017,
		"grip", 8)
	foot_a = box(0.05, 0.02, 0.05, "dark_steel", bevel=0.005, at=(0, 0.0, 0.02))
	foot_b = box(0.05, 0.02, 0.05, "dark_steel", bevel=0.005, at=(0, 0.0, -0.14))
	put("ScreedHandle", [grip, foot_a, foot_b])


# ---------------------------------------------------------------- the poker

def poker():
	# The drive unit: a petrol motor on a tube skid, the flexible shaft's
	# coupling on the left at (-0.18, 0.55, 0)
	skid = []
	for z in (-0.22, 0.22):
		skid.append(tube([(-0.38, 0.12, z), (-0.33, 0.03, z), (0.33, 0.03, z), (0.38, 0.12, z)], 0.025,
			"dark_steel", 8))
	for x in (-0.25, 0.25):
		skid.append(tube([(x, 0.03, -0.22), (x, 0.03, 0.22)], 0.02, "dark_steel", 8))
	skid.append(tube([(0.3, 0.06, -0.15), (0.45, 0.45, -0.15), (0.55, 0.72, -0.1), (0.55, 0.72, 0.1),
		(0.45, 0.45, 0.15), (0.3, 0.06, 0.15)], 0.02, "dark_steel", 8))
	skid.append(box(0.36, 0.05, 0.3, "dark_steel", bevel=0.01, at=(0, 0.08, 0)))
	put("PokerSkid", skid)
	motor = [box(0.34, 0.26, 0.32, "machine", bevel=0.05, at=(0.03, 0.24, 0))]
	motor.append(box(0.26, 0.1, 0.24, "fuel", bevel=0.04, at=(0.06, 0.42, 0)))
	motor.append(cylinder(0.025, 0.04, "rubber", 10, bevel=0.008, at=(0.12, 0.47, 0.05)))
	starter = cylinder(0.11, 0.06, "rubber", 16, bevel=0.02).rot("z", math.pi / 2).move(0.23, 0.25, 0)
	motor.append(starter)
	motor.append(sphere(0.025, "red", 8, 5, at=(0.27, 0.25, 0)))
	filt = cylinder(0.06, 0.12, "dark_steel", 12, bevel=0.015).rot("x", math.pi / 2).move(0.0, 0.3, 0.22)
	motor.append(filt)
	muffler = cylinder(0.045, 0.2, "steel", 10, bevel=0.012).rot("z", math.pi / 2).move(-0.0, 0.2, -0.19)
	motor.append(muffler)
	# The coupling the shaft screws into
	motor.append(cylinder(0.085, 0.1, "dark_steel", 14, bevel=0.015, at=(-0.18, 0.18, 0)))
	motor.append(cylinder(0.06, 0.32, "rubber", 12, at=(-0.18, 0.24, 0)))
	put("PokerMotor", motor, at=(0, 0, 0))
	# The head in the hand: grip end of the shaft, coupling, steel bottle
	head = [cylinder(0.036, 0.13, "rubber", 10, at=(0, -0.13, 0))]
	head.append(cylinder(0.05, 0.045, "dark_steel", 12, bevel=0.01, at=(0, -0.175, 0)))
	head.append(lathe([(0.0, -0.6), (0.025, -0.598), (0.042, -0.585), (0.047, -0.56), (0.047, -0.2), (0.042, -0.178)],
		12, "steel", cap_top=True))
	for y in (-0.3, -0.45):
		head.append(torus(0.048, 0.006, "dark_steel", 12, 4, at=(0, y, 0)))
	put("PokerHead", head)


# ---------------------------------------------------------------- the pump line

CLAMP_R = 0.25


def clamp_half(name, a0, a1):
	# One half of a quick-release clamp: a channel round the pipe, ribbed,
	# the hinge ear at the hinge (+x) end. Origin = the hinge, as line.gd
	# hangs it.
	t, h = 0.09, 0.17
	r0, r1 = CLAMP_R - t / 2, CLAMP_R + t / 2
	prof = [(r0, -h / 2), (r1 - 0.015, -h / 2), (r1, -h / 2 + 0.03), (r1, h / 2 - 0.03), (r1 - 0.015, h / 2),
		(r0, h / 2), (r0, 0.035), (r0 + 0.02, 0.02), (r0 + 0.02, -0.02), (r0, -0.035)]
	ring = lathe(prof, 10, "clamp", arc=(a0, a1), loop=True)
	# (lathe angles run from +z; line.gd's run from +x: same circle, turned)
	ring.rot("y", -math.pi / 2)
	ribs = []
	for k in range(1, 4):
		a = math.radians(-90) + (a0 + (a1 - a0) * k / 4)
		p = (math.sin(a) * (r1 + 0.008), 0, math.cos(a) * (r1 + 0.008))
		rb = box(0.03, h * 0.8, 0.02, "clamp")
		rb.rot("y", a).move(*p)
		ribs.append(rb)
	ear = cylinder(0.035, h * 0.9, "clamp", 10, bevel=0.01, at=(CLAMP_R, -h * 0.45, 0))
	parts = [ring, *ribs, ear]
	for pc in parts:
		pc.move(-CLAMP_R, 0, 0)
	put(name, parts)


def pipe():
	# 3 m of 125 mm line: the tube, and a welded collar at each end with the
	# groove the clamp bites in
	body = cylinder(0.16, 2.8, "pipe", 16).rot("z", math.pi / 2).move(1.4, 0, 0)
	parts = [body]
	for s in (-1, 1):
		col = lathe([(0.16, -0.06), (0.2, -0.05), (0.21, -0.02), (0.185, -0.012), (0.185, 0.012), (0.21, 0.02),
			(0.21, 0.05), (0.17, 0.06), (0.17, 0.06)], 16, "dark_steel", cap_top=False, cap_bottom=False)
		col.rot("z", math.pi / 2).move(s * 1.44, 0, 0)
		parts.append(col)
		parts.append(lathe([(0.0, 0.0), (0.145, 0.0), (0.16, 0.0)], 16, "wet", cap_top=False)
			.rot("z", -s * math.pi / 2).move(s * 1.5, 0, 0))
	put("Pipe3m", parts)


def stores():
	# The spares bin: a blue ribbed plastic crate with a lip
	shell = lathe([(0.0, 0.0), (0.55, 0.0), (0.58, 0.02), (0.6, 0.56), (0.62, 0.57), (0.62, 0.6), (0.58, 0.6),
		(0.56, 0.06), (0.0, 0.06)], 4, "bin", depth=1.0, cap_top=False, cap_bottom=False)
	shell.rot("y", math.pi / 4).scale(1.0 / math.cos(math.pi / 4) * 1.0, 1, 0.8 / 1.2 / math.cos(math.pi / 4))
	ribs = []
	for x in (-0.42, -0.14, 0.14, 0.42):
		for z in (-1, 1):
			ribs.append(box(0.05, 0.5, 0.03, "bin_dark", bevel=0.01, at=(x, 0.3, z * 0.405)))
	for z in (-0.2, 0.2):
		for x in (-1, 1):
			ribs.append(box(0.03, 0.5, 0.05, "bin_dark", bevel=0.01, at=(x * 0.605, 0.3, z)))
	put("SparesBin", [shell, *ribs])
	# The pipe rack: a yellow stand each end with three cradles, stepping
	# back and up like the pipes on it
	stand = []
	for s in (-1, 1):
		x = s * 1.3
		stand.append(tube([(x, 0.0, -0.45), (x, 0.92, -0.45)], 0.04, "rack", 8))
		stand.append(tube([(x, 0.0, 0.45), (x, 0.6, 0.45)], 0.04, "rack", 8))
		stand.append(tube([(x, 0.02, -0.5), (x, 0.02, 0.5)], 0.04, "rack", 8))
		for i in range(3):
			y, z = 0.35 + i * 0.25 - 0.19, -0.2 + i * 0.2
			stand.append(tube([(x, y, z - 0.22), (x, y, z + 0.22)], 0.03, "rack", 8))
			for dz in (-0.22, 0.22):
				stand.append(tube([(x, y, z + dz), (x, y + 0.1, z + dz * 1.05)], 0.025, "rack", 6))
		stand.append(tube([(x, 0.3, -0.45), (x, 0.3, 0.45)], 0.03, "rack", 8))
	put("PipeRack", stand)


# ---------------------------------------------------------------- slump test kit

def slump():
	plate = [box(0.9, 0.03, 0.6, "steel", bevel=0.006)]
	for s in (-1, 1):
		plate.append(tube([(s * 0.45, 0.0, -0.12), (s * 0.5, 0.03, -0.1), (s * 0.5, 0.03, 0.1), (s * 0.45, 0.0, 0.12)],
			0.01, "dark_steel", 6))
	put("SlumpPlate", plate)
	# The green mixing tray the sample's carried in, concrete in it
	tray = lathe([(0.0, 0.05), (0.13, 0.05), (0.16, 0.06), (0.2, 0.19), (0.21, 0.195), (0.19, 0.19), (0.155, 0.075),
		(0.0, 0.075)], 4, "tray", cap_top=False, cap_bottom=True)
	tray.rot("y", math.pi / 4).scale(1.27, 1, 0.92)
	mix = lathe([(0.0, 0.17), (0.17, 0.17), (0.18, 0.165)], 4, "wet", cap_bottom=False)
	mix.rot("y", math.pi / 4).scale(1.27, 1, 0.92)
	lumps = [sphere(0.03, "wet", 8, 4, at=(x, 0.17, z), s=(1, 0.4, 1)) for x, z in
		((-0.05, 0.02), (0.06, -0.03), (0.02, 0.05))]
	put("SlumpTray", [tray])
	put("SlumpTrayMix", [mix, *lumps])
	scoop = lathe([(0.0, -0.035), (0.03, -0.033), (0.04, -0.02), (0.042, 0.0)], 10, "steel", arc=(-math.pi / 2,
		math.pi / 2), cap_top=False, cap_bottom=False)
	scoop.rot("z", math.pi / 2).scale(1.5, 1, 1)
	handle = cylinder(0.012, 0.08, "grip", 8, bevel=0.004).rot("z", math.pi / 2).move(-0.02, 0, 0)
	handle.move(-0.06, 0, 0)
	put("SlumpScoop", [scoop, handle])


# ---------------------------------------------------------------- hand tools and gear

def hand_tools():
	# Square-mouth shovel, standing up: blade at the bottom, origin at its tip
	blade = box(0.25, 0.3, 0.012, "dark_steel", bevel=0.004, at=(0, 0.15, 0))
	blade.warp(lambda v: (v.x, v.y, v.z + 0.04 * (1 - (v.x / 0.125) ** 2) * (1 - v.y / 0.3)))
	socket = cylinder(0.025, 0.12, "dark_steel", 8, at=(0, 0.28, 0.01))
	shaft = cylinder(0.018, 0.85, "timber", 8, at=(0, 0.4, 0.01))
	dgrip = tube([(-0.06, 1.25, 0.01), (-0.06, 1.33, 0.01), (0.06, 1.33, 0.01), (0.06, 1.25, 0.01)], 0.015,
		"grip", 6)
	put("Shovel", [blade, socket, shaft, dgrip, cylinder(0.02, 0.05, "grip", 8, at=(0, 1.22, 0.01))])
	# Concrete placer rake: flat aluminium blade with a hook on top
	rblade = box(0.5, 0.11, 0.012, "alu", bevel=0.004, at=(0, 0.055, 0))
	hook = box(0.5, 0.012, 0.05, "alu", bevel=0.004, at=(0, 0.11, -0.025))
	rshaft = cylinder(0.018, 1.45, "alu", 8, at=(0, 0.1, -0.02))
	rshaft.rot("x", -0.15)
	put("ConcreteRake", [rblade, hook, rshaft, box(0.06, 0.04, 0.04, "grip", 0.01, at=(0, 0.1, -0.02))])
	# Bull float lying flat: wide magnesium blade, bracket, long handle
	fblade = box(1.2, 0.012, 0.2, "alu", bevel=0.004, at=(0, 0.006, 0))
	fblade.warp(lambda v: (v.x, v.y + 0.02 * (abs(v.z) / 0.1) ** 2, v.z))
	bracket = box(0.1, 0.05, 0.08, "dark_steel", bevel=0.01, at=(0, 0.035, 0))
	fhandle = tube([(0, 0.05, 0), (0, 0.18, -0.6), (0, 0.33, -1.8)], 0.02, "alu", 8)
	put("BullFloat", [fblade, bracket, fhandle])
	# Magnesium hand float
	mblade = box(0.4, 0.012, 0.09, "alu", bevel=0.004, at=(0, 0.006, 0))
	mgrip = tube([(-0.12, 0.012, 0), (-0.09, 0.07, 0), (0.09, 0.07, 0), (0.12, 0.012, 0)], 0.016, "timber", 8)
	put("MagFloat", [mblade, mgrip])
	# 20 litre builder's bucket with a wire handle
	pail = lathe([(0.0, 0.0), (0.14, 0.0), (0.155, 0.01), (0.175, 0.34), (0.185, 0.35), (0.185, 0.36), (0.17, 0.36),
		(0.155, 0.02), (0.0, 0.02)], 18, "bucket", cap_top=False, cap_bottom=True)
	bail = tube(arc_points((0, 0.33, 0), 0.19, -math.pi / 2, math.pi / 2, 10, plane="xy"), 0.007, "dark_steel", 5)
	slurry = lathe([(0.0, 0.2), (0.165, 0.2)], 18, "wet_crust", cap_bottom=False)
	put("Bucket", [pail, bail, slurry])


def barrow():
	# Builder's wheelbarrow: deep steel tray, tube frame, one pneumatic wheel
	tray = lathe([(0.0, 0.42), (0.26, 0.42), (0.3, 0.44), (0.42, 0.7), (0.44, 0.72), (0.42, 0.72), (0.28, 0.46),
		(0.0, 0.46)], 4, "barrow", cap_top=False, cap_bottom=True)
	tray.rot("y", math.pi / 4).scale(1.25, 1, 0.95)
	tray.warp(lambda v: (v.x + (0.12 if v.x > 0 and v.y > 0.6 else 0.0), v.y, v.z))
	frame = []
	for z in (-0.2, 0.2):
		frame.append(tube([(0.62, 0.3, z * 0.4), (0.3, 0.38, z), (-0.4, 0.42, z * 1.05), (-0.95, 0.62, z * 1.2)],
			0.022, "dark_steel", 8))
		frame.append(tube([(-0.25, 0.4, z), (-0.3, 0.0, z * 1.1)], 0.02, "dark_steel", 6))
		frame.append(cylinder(0.03, 0.12, "grip", 8).rot("z", 1.2).move(-1.0, 0.64, z * 1.2))
	wheel = torus(0.13, 0.06, "tyre", 18, 8).rot("z", math.pi / 2).move(0.62, 0.19, 0)
	hub = cylinder(0.05, 0.1, "dark_steel", 10).rot("z", math.pi / 2).move(0.67, 0.19, 0)
	put("Wheelbarrow", [tray, *frame, wheel, hub])


def rigging():
	# Chain sling in a heap: master link and two legs of chain with hooks
	links = [torus(0.07, 0.014, "chain", 12, 5, at=(0, 0.014, 0)).scale(1.0, 1, 1.5)]
	rng = random.Random(3)
	for leg in (-1, 1):
		x, z, a = 0.0, 0.11 * leg, 0.0
		for k in range(10):
			a += rng.uniform(-0.5, 0.5)
			x += math.sin(a) * 0.07 * leg
			z += math.cos(a) * 0.07 * leg
			ln = torus(0.035, 0.009, "chain", 8, 4).scale(1, 1, 1.5)
			if k % 2:
				ln.rot("z", math.pi / 2)
			ln.rot("y", a).move(x, 0.035 if k % 2 else 0.01, z)
			links.append(ln)
		hook = tube(arc_points((x, 0.02, z), 0.05, 0.3, 4.6, 10), 0.012, "red", 6)
		links.append(hook)
	put("ChainSling", links)
	# Tag line, coiled on the ground
	pts = []
	for k in range(120):
		t = k / 119
		a = t * 2 * math.pi * 6
		r = 0.22 + 0.025 * math.sin(a * 0.37)
		pts.append((math.sin(a) * r, 0.02 + t * 0.09 + 0.01 * math.sin(a * 3), math.cos(a) * r))
	pts.append((0.5, 0.01, 0.1))
	put("TagLineCoil", [tube(pts, 0.012, "rope", 6)])
	# Bow shackle with its screw pin
	bow = tube(arc_points((0, 0.06, 0), 0.05, -math.pi / 2 - 0.3, math.pi / 2 + 0.3, 12, plane="xy"), 0.012,
		"red", 8)
	pin = cylinder(0.012, 0.15, "steel", 8, bevel=0.004).rot("z", math.pi / 2).move(0.075, 0.0, 0)
	put("Shackle", [bow, pin])


def main():
	reset()
	screed_board()
	poker()
	clamp_half("ClampHalfA", 0.0, math.pi)
	clamp_half("ClampHalfB", math.pi, 2 * math.pi)
	pipe()
	stores()
	slump()
	hand_tools()
	barrow()
	rigging()
	import bpy
	for o in bpy.context.scene.objects:
		if o.type == "MESH":
			print("  %-14s %5d triangles" % (o.name, tri_count([o])))
	export_glb(OUT)
	print("wrote", OUT)


if __name__ == "__main__":
	main()

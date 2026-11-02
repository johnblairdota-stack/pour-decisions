## What makes a ute a 4x4 off the bitumen (explore.gd drives it): how far its
## wheels travel, how steep a face its bumpers and belly clear, which wheels
## the engine drives (2H, 4H, 4L and the rear locker), what its tyres bite
## on at what pressure, how deep it wades, and what the kit bolted on (and
## the camping gear loaded on) changes. Real figures where the makers give
## them: approach, departure and ramp-over angles, ground clearance, wading
## depth, low-range ratio.
extends RefCounted

const Utes := preload("res://scripts/utes.gd")

## approach / departure / ramp-over (degrees), ground clearance under the
## diffs (m), wading depth (m), wheel travel each way from ride height at the
## front and rear (m), the low-range ratio (0: none), a rear locker, and the
## static weight on the front axle.
const GEO := {
	# Toyota HiLux SR5 (2024): 29° / 27°, 216 mm, 700 mm; ramp-over about 25°
	"Hilux": {"approach": 29.0, "departure": 27.0, "ramp": 25.0, "clear": 0.216, "wade": 0.70,
		"travel_f": 0.10, "travel_r": 0.13, "low": 2.566, "locker": true, "front": 0.56},
	# Ford Ranger XLT (2023): 30° / 23° / 21°, 234 mm, 800 mm
	"Ranger": {"approach": 30.0, "departure": 23.0, "ramp": 21.0, "clear": 0.234, "wade": 0.80,
		"travel_f": 0.10, "travel_r": 0.13, "low": 2.717, "locker": true, "front": 0.57},
	# BYD Shark 6: 31° / 19.3° / 17°, 230 mm, 700 mm; twin motors, no low
	# range or locker (it brakes a spinning wheel instead)
	"Shark": {"approach": 31.0, "departure": 19.3, "ramp": 17.0, "clear": 0.230, "wade": 0.70,
		"travel_f": 0.10, "travel_r": 0.11, "low": 0.0, "locker": false, "front": 0.52},
}

## The ways a part-time 4x4 drives, in the order Y steps through them
const MODES := ["2H", "4H", "4L", "4L+LOCK"]
const SHARK_MODES := ["AWD", "MUD"]

## Tyre pressures (psi): on the road, and aired down for sand and mud
const PSI_ROAD := 38.0
const PSI_LOW := 18.0
const LOW_SAFE := 60.0       # km/h aired down before the tyres start to cook
const BEAD := 9.0            # s cooking before one rolls off the rim

## How much the tyres can push on each surface, as a fraction of the weight on
## them: stock all-terrains, mud-terrains, and what airing down adds.
const MU := {"": 0.9, "dirt": 0.72, "grass": 0.52, "mud": 0.32, "sand": 0.36, "water": 0.45}
const MU_MUDTYRE := {"": 0.86, "dirt": 0.78, "grass": 0.6, "mud": 0.46, "sand": 0.4, "water": 0.5}
const MU_AIRED := {"": 0.9, "dirt": 1.06, "grass": 1.08, "mud": 1.15, "sand": 1.55, "water": 1.05}

## What the camping gear weighs (kg) and how high it sits (m above the
## ground: it raises the centre of mass)
const LOAD := {"canopy": [150.0, 1.3], "rooftent": [65.0, 2.1], "roofrack": [28.0, 1.95], "awning": [22.0, 1.9],
	"drawers": [60.0, 0.9], "fridge": [45.0, 1.0], "jerrycans": [40.0, 1.0], "swag": [10.0, 1.1],
	"winch": [42.0, 0.6], "bullbar": [65.0, 0.7], "lightbar": [6.0, 1.9], "spotlights": [8.0, 0.9], "snorkel": [4.0, 1.4]}

const LIFT_TRAVEL := 0.035   # and the longer shocks' extra travel each way
const SNORKEL_WADE := 1.15   # the intake up at the roof (m of water)

## Everything about one ute with its kit, worked out once when you get in.
## `ride` is how much higher the kit sits it (utes.gd apply_kit's "ride").
static func setup(name: String, kit: Array, ride: float) -> Dictionary:
	var g: Dictionary = GEO[name]
	var s: Dictionary = Utes.SPEC[name]
	var up := ride
	var travel := LIFT_TRAVEL if "lift" in kit else 0.0
	var front_oh: float = s["front"]
	var rear_oh: float = float(s["L"]) - float(s["front"]) - float(s["wb"])
	var mass := 0.0
	var moment := 0.0
	for k in kit:
		if LOAD.has(k):
			mass += float(LOAD[k][0])
			moment += float(LOAD[k][0]) * float(LOAD[k][1])
	var base: float = Utes.ENGINE[name]["mass"]
	var com := (base * 0.85 + moment) / (base + mass)
	return {
		# (how high off the ground plane each bumper's lowest edge sits: from
		# the angle it clears, at its own overhang; a bull bar hangs a bit lower)
		"nose": front_oh * tan(deg_to_rad(float(g["approach"]))) + up - (0.03 if "bullbar" in kit else 0.0),
		"tail": rear_oh * tan(deg_to_rad(float(g["departure"]))) + up,
		"belly": float(s["wb"]) * 0.5 * tan(deg_to_rad(float(g["ramp"]) * 0.5)) + up,
		"diff": float(g["clear"]) + up,
		"front_oh": front_oh, "rear_oh": rear_oh,
		"travel_f": float(g["travel_f"]) + travel, "travel_r": float(g["travel_r"]) + travel,
		"wade": SNORKEL_WADE if "snorkel" in kit else float(g["wade"]),
		"mud": "mudtyres" in kit, "extra": mass, "com": com,
		"low": float(g["low"]), "locker": bool(g["locker"]), "front": float(g["front"]),
		"modes": SHARK_MODES if name == "Shark" else MODES,
	}

## How hard the tyres can bite on `surf` (a fraction of the weight on them).
static func mu(surf: String, mud_tyres: bool, psi: float) -> float:
	var m: float = (MU_MUDTYRE if mud_tyres else MU).get(surf, 0.6)
	var low := clampf((PSI_ROAD - psi) / (PSI_ROAD - PSI_LOW), 0.0, 1.0)
	return m * lerpf(1.0, float(MU_AIRED.get(surf, 1.0)), low)

## What fraction of the ute's weight the driven wheels can push with, in
## `mode`: each axle gives its share of the weight times the bite, unless a
## wheel's off the ground, when an open diff sends it all to the one in the
## air. `lifted` is [FL, FR, RL, RR]; `rear` the rear axle's share of the
## weight; `belly` how much of the weight the chassis is carrying itself.
static func traction(mode: String, m: float, lifted: Array, rear: float, belly: float) -> float:
	var front_drive := mode != "2H"
	var assist := 0.15        # brakes grabbing a spinning wheel, at a crawl
	match mode:
		"4L", "4L+LOCK":
			assist = 0.45
		"AWD":
			assist = 0.4
		"MUD":
			assist = 0.65
	var t := 0.0
	var share := [1.0 - rear, rear]
	for ax in 2:
		if ax == 0 and not front_drive:
			continue
		var a: bool = lifted[ax * 2]
		var b: bool = lifted[ax * 2 + 1]
		var k := 1.0
		if a and b:
			k = 0.0
		elif a or b:
			k = 1.0 if (ax == 1 and mode == "4L+LOCK") else assist
		t += float(share[ax]) * k * m
	return t * (1.0 - belly)

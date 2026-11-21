## The flight kit: one river flight for every tower (the towers and transitions plan, 20 Nov).
## Four moves, the same on every tower:
##   SKIM    low on the water behind the CityCat
##   GATE    past one landmark (Spire: under the Story Bridge)
##   LIFT    one arc off the water and round to the site, a moment's float at the top
##   SETTLE  down onto the floor pick's own view
## A tower is one entry in TOWERS: the boat's line, the chase behind it, the arc and its timing.
## main.gd turns that into the flight's keys (it owns the sites' coordinates) and asks here for the
## curve through them, the feel on top of it (the roll into the turns, the lens opening with speed,
## the float) and the sound's score. No equipment is placed or shown by any of this.
extends RefCounted

## id (the tower card's) -> its flight. Distances in metres, times in seconds.
##   frame     what `line` is in: "real" (Riverlight's real-world metres) or "spire" (Spire's site metres)
##   line      the CityCat's last run in to the site, on the water, [x, y] points
##   river_t   the skim: s behind the boat before the lift
##   total_t   all of it, to the floor pick's view
##   back, side, up     the chase: behind the boat, off to the side away from the site, over the
##                      water, each [at the start, at the lift]
##   up_by     the height's eased over this much of the skim (0: straight line)
##   look_up, look_tower, look_pow   where it looks: over the bow by this much, turned this far
##                      towards the tower (start, lift), that turn raised to this power
##   arc       round the end of the building: [s, along the end, out from the face, m over the
##             deck, how far the look has gone from the tower to the deck]
##   end       which end of the building the arc goes round (-1 or 1)
##   floor_y, floor_n   never under this height on the first floor_n arc keys
##   rise      how far the first arc key has climbed towards its height (it sits between the river and the site)
##   gate      the landmark's line across the river: [x, z on it, x, z of its normal], game metres;
##             empty for none. The sound closes in as the camera crosses it.
const TOWERS := {
	"riverlight": {
		"frame": "real", "line": [[330, -338], [250, -318], [185, -292], [140, -262], [112, -250]],
		"river_t": 3.6, "total_t": 12.0,
		"back": [46.0, 38.0], "side": [11.0, 11.0], "up": [8.0, 11.0], "up_by": 0.0,
		"look_up": [3.0, 3.0], "look_tower": [0.3, 0.5], "look_pow": 1.0,
		"arc": [[6.2, 84.0, -150.0, 34.0, 0.35], [8.4, 70.0, -40.0, 24.0, 0.75], [10.0, 24.0, 42.0, 10.0, 1.0]],
		"end": -1.0, "floor_y": 24.0, "floor_n": 99, "rise": 0.7, "gate": [],
	},
	## The water tower: the same reach, but its own flight. A shorter run, lower and closer in:
	## it's a small job, and the whole of it is in the frame from the bank.
	"water": {
		"frame": "real", "line": [[300, -331], [250, -318], [185, -292], [140, -262], [112, -250]],
		"river_t": 2.8, "total_t": 9.6,
		"back": [40.0, 30.0], "side": [9.0, 9.0], "up": [6.0, 8.0], "up_by": 0.0,
		"look_up": [3.0, 3.0], "look_tower": [0.4, 0.7], "look_pow": 1.0,
		"arc": [[5.0, 64.0, -118.0, 22.0, 0.4], [6.8, 52.0, -30.0, 16.0, 0.8], [8.0, 18.0, 34.0, 8.0, 1.0]],
		"end": -1.0, "floor_y": 24.0, "floor_n": 99, "rise": 0.7, "gate": [],
	},
	"spire": {
		# (the site's own metres, as the Blender scene has them: up the Town Reach with Howard Smith
		# Wharves on the right, under the Story Bridge's main span 60 m north of its middle, and on
		# towards the city. The run starts 45 m short of the bridge.)
		"frame": "spire", "line": [[600.0, -35.0], [488.0, -15.0], [400.0, -60.0], [385.4, -66.0]],
		"river_t": 6.0, "total_t": 16.0,
		# (from well back, the whole bridge across the frame and the CityCat going under it; then
		# closing on the boat and under the deck itself, low: the steel's 33 m over the water)
		"back": [190.0, 38.0], "side": [30.0, 11.0], "up": [30.0, 14.0], "up_by": 0.75,
		"look_up": [26.0, 3.0], "look_tower": [0.1, 0.5], "look_pow": 2.0,
		# (up over the cliff in one sweep, round the cathedral end where nothing stands tall, and
		# down onto Ann St. Checked against cuts through the city model at 40, 70 and 100 m: never
		# under 85 m until it's over the cathedral grounds. The third key keeps it outside the
		# tower crane's jib until it's under it.)
		"arc": [[9.6, 146.0, -189.0, 72.0, 0.35], [12.2, 84.0, -48.0, 58.0, 0.7], [13.4, 70.0, 20.0, 34.0, 0.9], [14.5, 22.0, 50.0, 20.0, 1.0]],
		"end": 1.0, "floor_y": 88.0, "floor_n": 2, "rise": 1.0,
		"gate": [-305.0, -410.0, 0.78, 0.63],
	},
}

const FOV := 50.0            # the game's own lens
const FOV_FAST := 11.0       # degrees wider at full speed
const FOV_V0 := 22.0         # m/s: the lens starts to open (the skim's 19 keeps the game's own)
const FOV_V1 := 105.0        # ...and is right open
const ROLL_MAX := 0.12       # rad (7 degrees): into the turns
const ROLL_K := 0.3          # rad of roll for each rad/s the heading turns
const FLOAT_DIP := 0.38      # the float at the top of the arc: this much of its speed held back
const FLOAT_W := 0.5         # s either side

## The tower's flight (Riverlight's when it has none of its own yet).
static func of(id: String) -> Dictionary:
	return TOWERS.get(id, TOWERS["riverlight"])

## The chase behind the boat, f (0..1) through the skim: [camera, look].
static func chase(c: Dictionary, f: float, at: Vector3, dir: Vector3, side: Vector3, tower: Vector3) -> Array:
	var up_f: float = f if float(c["up_by"]) <= 0.0 else smoothstep(0.0, float(c["up_by"]), f)
	var cam: Vector3 = at - dir * lerpf(c["back"][0], c["back"][1], f) + side * lerpf(c["side"][0], c["side"][1], f) + Vector3(0, lerpf(c["up"][0], c["up"][1], up_f), 0)
	var look: Vector3 = (at + dir * 14.0 + Vector3(0, lerpf(c["look_up"][0], c["look_up"][1], f), 0)).lerp(tower, lerpf(c["look_tower"][0], c["look_tower"][1], pow(f, float(c["look_pow"]))))
	return [cam, look]

## The flight's velocity through key i: along the line between its neighbours, but never much faster
## than the slower of the two legs it joins (the river's 19 m/s into the arc's 100: a plain average
## made it back off before the key and then lurch), and stopped dead on the last.
static func tangent(keys: Array, i: int, which: int) -> Vector3:
	var n := keys.size()
	if i >= n - 1:
		return Vector3.ZERO
	var p: Vector3 = keys[i][which]
	var v_next: Vector3 = ((keys[i + 1][which] as Vector3) - p) / (float(keys[i + 1][0]) - float(keys[i][0]))
	if i == 0:
		return v_next
	var v_prev: Vector3 = (p - (keys[i - 1][which] as Vector3)) / (float(keys[i][0]) - float(keys[i - 1][0]))
	var m: Vector3 = ((keys[i + 1][which] as Vector3) - (keys[i - 1][which] as Vector3)) / (float(keys[i + 1][0]) - float(keys[i - 1][0]))
	var cap := 1.8 * minf(v_prev.length(), v_next.length())
	return m.limit_length(cap)

## A point on the flight at t: a Hermite curve through the keys (which = 1 camera, 2 look), its
## speed carried across each key and brought to a stop on the last.
static func at(keys: Array, t: float, which: int) -> Vector3:
	var n := keys.size()
	var i := 0
	while i < n - 2 and t > float(keys[i + 1][0]):
		i += 1
	var t0: float = keys[i][0]
	var t1: float = keys[i + 1][0]
	var p0: Vector3 = keys[i][which]
	var p1: Vector3 = keys[i + 1][which]
	var m0 := tangent(keys, i, which)
	var m1 := tangent(keys, i + 1, which)
	var h := t1 - t0
	var u := clampf((t - t0) / h, 0.0, 1.0)
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * p0 + (u3 - 2.0 * u2 + u) * h * m0 + (-2.0 * u3 + 3.0 * u2) * p1 + (u3 - u2) * h * m1

## When the camera's at the top of its arc (the highest key after the skim).
static func apex_t(keys: Array, river_t: float) -> float:
	var best := -1.0
	var y := -1e9
	for k in keys:
		if float(k[0]) > river_t and float(k[0]) < float(keys[keys.size() - 1][0]) and (k[1] as Vector3).y > y:
			y = (k[1] as Vector3).y
			best = float(k[0])
	return best

## How fast the flight's clock runs at t: a moment's float at the top of the arc.
static func rate(t: float, apex: float) -> float:
	if apex < 0.0:
		return 1.0
	var u := (t - apex) / FLOAT_W
	return 1.0 - FLOAT_DIP * exp(-u * u)

## When the camera crosses the tower's gate (-1: it has none, or never does).
static func gate_t(c: Dictionary, keys: Array) -> float:
	var g: Array = c["gate"]
	if g.size() < 4 or keys.is_empty():
		return -1.0
	var was := 0.0
	var t := 0.0
	var end := float(keys[keys.size() - 1][0])
	while t < end:
		var p := at(keys, t, 1)
		var d := (p.x - float(g[0])) * float(g[2]) + (p.z - float(g[1])) * float(g[3])
		if t > 0.0 and d * was < 0.0:
			return t
		was = d
		t += 0.1
	return -1.0

## The feel on top of the curve at t: {"roll": rad about the lens (positive: banked to the right),
## "fov": degrees, "v": m/s}. The roll follows how fast the flight's heading is turning (measured
## over two thirds of a second, so a key going by doesn't twitch it) and there's none on the skim:
## the camera's riding behind a boat there. The lens opens with the speed. Both are gone by the
## time it settles.
static func feel(keys: Array, t: float, river_t: float) -> Dictionary:
	var end := float(keys[keys.size() - 1][0])
	var h := 0.33
	var a := at(keys, maxf(0.0, t - h), 1)
	var b := at(keys, t, 1)
	var c := at(keys, minf(end, t + h), 1)
	var v0 := Vector2(b.x - a.x, b.z - a.z)
	var v1 := Vector2(c.x - b.x, c.z - b.z)
	var speed := (at(keys, minf(end, t + 0.05), 1) - at(keys, maxf(0.0, t - 0.05), 1)).length() / 0.1
	var roll := 0.0
	if v0.length() > 1.0 and v1.length() > 1.0:
		# (turning to the right, seen from above with -z ahead: the heading's angle goes up)
		roll = clampf(v0.angle_to(v1) / h * ROLL_K, -ROLL_MAX, ROLL_MAX)
	var calm := smoothstep(river_t - 0.3, river_t + 1.2, t) * (1.0 - smoothstep(end - 3.0, end - 1.0, t))
	return {"roll": roll * calm, "fov": FOV + FOV_FAST * smoothstep(FOV_V0, FOV_V1, speed) * (1.0 - smoothstep(end - 3.0, end - 1.0, t)), "v": speed}

## The sound's score at t: how much of each place's bed (sfx.set_ambience), the CityCat's engines
## and their pitch, and the lull at the top of the arc. `site` is what the site itself wants once
## it's landed (main.gd's own mix): the score hands over to it through the settle.
##   skim    the engines and the water, a little wind
##   gate    the bridge's traffic overhead, the water dulled
##   lift    the engines fall behind and drop in pitch, the wind comes up with the height
##   float   almost nothing, for a moment
##   settle  the site's own morning
static func score(t: float, river_t: float, apex: float, gate: float, total: float, city: bool, site: Dictionary) -> Dictionary:
	var up := smoothstep(river_t - 0.4, maxf(river_t + 1.0, apex), t)
	var land := smoothstep(total - 3.0, total - 0.4, t)
	var under := 0.0
	if gate >= 0.0:
		var u := (t - gate) / 0.9
		under = exp(-u * u)
	var amb := {
		"river": (1.0 - up) * (1.0 - 0.5 * under),
		"wind": 0.15 + 0.85 * up,
		"traffic": 0.9 * under,
		"city": (0.6 if city else 0.25) * up,
		"morning": 0.25 * (1.0 - up),
		"dawn": 0.0, "park": 0.0,
	}
	var out := {}
	for name in site:
		out[name] = lerpf(float(amb.get(name, 0.0)), float(site[name]), land)
	var lull := 0.0
	if apex >= 0.0:
		var q := (t - apex) / 0.4
		lull = exp(-q * q)
	return {"amb": out, "boat": 1.0 - smoothstep(river_t - 0.2, river_t + 2.6, t), "pitch": lerpf(1.0, 0.78, up), "lull": lull}

# ------------------------------------------------------------------ the equipment tour

## The equipment tour before a pour: the camera follows the concrete's route once, so everyone has
## seen every machine before they're asked to work it. The route's fixed (John, 22 Nov): truck,
## hopper, pump, the line along the ground floor, up through the slab openings to the column, the
## boom, the hose. Where each of those IS belongs to the level, not to this file: with no "route"
## here main.gd reads the places the level already has. A tower's real route drops in as
## "route": [[stop, x, y, z], ...] in game metres ("up" as many times as the line has corners on
## its way up), and nothing else changes.
const TOURS := {
	"riverlight": {"route": []},
	"spire": {"route": []},     # (being redesigned in the mast climb thread: left to the level until that's confirmed)
}

## Each stop: [s from the stop before, how close (of the game's own camera distance), unused, whose job it is ("" nobody's), what's happening]
## (the tour looks from the same angle the game's own camera does, only closer in: that's the angle
## the site's built to be seen from. Stood beside each machine it stared at walls and bare ground.)
const TOUR_STOPS := {
	"truck": [0.0, 0.55, 0.0, "line", "Trucks back up to the hopper here"],
	"hopper": [1.1, 0.42, 0.0, "line", "The concrete goes into the hopper"],
	"pump": [1.0, 0.42, 0.0, "pump", "The pump pushes it down the line"],
	"ground": [1.0, 0.45, 0.0, "pump", "Along the ground"],
	"up": [1.5, 0.55, 0.0, "", "Up to the deck"],
	"column": [1.1, 0.7, 0.0, "boom", "Out along the boom"],
	"hose": [1.0, 0.55, 0.0, "hose", "And out of the hose"],
}
const TOUR_LAND_T := 1.3      # s from the hose back to the game's own view
const TOUR_SHORT := ["up", "column", "hose"]    # after the first of a session: just the climb to the deck

## The tour through `route` ([[stop, Vector3], ...]), each stop seen along `off` (the game's own
## camera, from what it looks at) scaled in, ending on the game's view (`fin` looking at `fin_look`):
## {"keys": [t, camera, look] for at(), "cues": [t, stop] as each comes up, "total": s}.
static func tour(route: Array, off: Vector3, fin: Vector3, fin_look: Vector3, short: bool) -> Dictionary:
	var keys: Array = []
	var cues: Array = []
	var t := 0.0
	var ups := 0
	for r in route:
		if String(r[0]) == "up":
			ups += 1
	var was := ""
	for r in route:
		var id := String(r[0])
		if not TOUR_STOPS.has(id) or (short and not id in TOUR_SHORT):
			continue
		var s: Array = TOUR_STOPS[id]
		var p: Vector3 = r[1]
		if not keys.is_empty():
			t += float(s[0]) / (float(ups) if id == "up" else 1.0)
		keys.append([t, p + off * float(s[1]), p])
		if id != was:
			cues.append([maxf(0.0, t - 0.35), id])
		was = id
	if keys.size() < 2:
		return {}
	t += TOUR_LAND_T
	keys.append([t, fin, fin_look])
	return {"keys": keys, "cues": cues, "total": t}

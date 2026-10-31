## Crew bots: they work whichever jobs no person has taken, through the same
## stick and buttons a person uses. Each looks after its own job first, runs
## when its hand sign goes red, and helps out where a real crew would (the
## pump operator kills the pump on a spike and climbs up to fix the line).
extends Node

var game
var _boom_goal := Vector3.ZERO
var _boom_goal_t := 0.0
var _heap_t := 0.0
var _boom_ok := true    # the boom bot's own say on pumping now
var _tap_y := -1.0
var _scr := {"mode": "seek", "x": 0.0, "dir": 1.0, "end": 0.0, "t": 0.0}
var _spot_tries := {}   # patch -> {n, at, p}: spot pulls tried on it
var _strip_runs := {}   # strip x -> {n, at}: pulls down that strip lately
const STRIP_AGAIN := 2     # pulls down one strip before it's left a while
const STRIP_REST := 25.0   # s a well-worked strip is left before going back
var _barked := {}
var _naive_dog := OS.get_cmdline_user_args().has("--naive-dog")
var _pk_target := Vector3(INF, 0, 0)
var _pk_urgent := false
const URGENT_PK := 0.55   # how close to going off before the poker bot drops what it's doing
const PACE := [0.75, 0.88, 1.0]   # bronze, silver, gold
const READ_T := [2.4, 1.4, 0.6]   # s to make the call on a tested load
const REACT_T := [1.3, 0.8, 0.45] # s to kill the pump on a pressure spike

func setup(owner_game) -> void:
	game = owner_game

func _tap() -> bool:
	return fmod(game.phase_t, 0.2) < 0.1

func _clear(p) -> void:
	p.ai_move = Vector2.ZERO
	p.ai_action = false
	p.ai_alt = false
	p.ai_slow = false
	p.ai_leave = false

func _bark_once(p, key: String, text: String) -> void:
	if not _barked.has(key):
		_barked[key] = true
		p.bark(text)

func forget(key: String) -> void:
	_barked.erase(key)

## Called every frame after the crew have been handled: sets each bot's
## inputs for the next frame.
## Bots aren't perfect: at bronze pace each one switches off for a few
## seconds a couple of times a pour (a phone call, a chat with a truck
## driver), at silver once, at gold never. It's the gap a person on the job
## can do better than.
const SLIPS := [2, 1, 0]
const SLIP_T := 6.0
const SLIP_LINES := ["Hang on, phone!", "Back in a sec!", "Just checking something…", "Where's my water?"]
var _slips := {}       # role -> fill fractions still to come
var _slip_t := {}      # role -> seconds left switched off
var _slips_for := -1   # the level the slips were planned for

func _plan_slips() -> void:
	_slips.clear()
	_slip_t.clear()
	_slips_for = game.k
	if OS.get_cmdline_user_args().has("--noslips"):
		return
	var n: int = SLIPS[game.score.bot_tier]
	for role in game.crew.crew:
		var at: Array = []
		for i in n:
			at.append(randf_range(0.15, 0.85))
		at.sort()
		_slips[role] = at

## True while this bot's switched off (and it says why, once).
func _slipping(p, role: String, delta: float) -> bool:
	if game.phase != "pour" or not game.ops.primed or p.covering:
		return false
	# A pressure spike snaps the pump operator out of it: the alarm's loud
	if role == "pump" and game.line.spike_on:
		_slip_t[role] = 0.0
		return false
	var left: float = _slip_t.get(role, 0.0)
	if left > 0.0:
		_slip_t[role] = left - delta
		return true
	var at: Array = _slips.get(role, [])
	if not at.is_empty() and game._filled_ratio() >= float(at[0]):
		at.pop_front()
		# (never in the middle of something that can't wait)
		if p.busy in ["", "boom"] and p.zone in ["deck", "ground"]:
			_slip_t[role] = SLIP_T
			p.bark(SLIP_LINES[randi() % SLIP_LINES.size()], 1.6)
			return true
	return false

func tick(delta: float) -> void:
	var crew: Dictionary = game.crew.crew
	game.climb.dog_bot = null
	if game.phase == "pour" and _slips_for != game.k:
		_plan_slips()
	for role in crew:
		var p = crew[role]
		if not p.bot and not p.covering:
			continue
		_clear(p)
		# How sharp the bots are working matches the people playing: bronze to
		# start, up a step each time the crew beats it (score.bot_tier)
		var tier: int = game.score.bot_tier
		p.pace = PACE[tier]
		p.hurry = int(game.urgent.get(role, 0)) >= (2 if tier == 0 else 1)
		if p.zone == "hoist" or game.phase in ["select", "roles"]:
			continue
		if not p.covering and _slipping(p, role, delta):
			continue
		match role:
			"boom": _boom(p, delta)
			"line": _line(p, delta)
			"pump": _pump(p, delta)
			"poker": _poker(p, delta)
			"screed": _screed(p, delta)
			"hose": _hose(p, delta)

# ------------------------------------------------------------------ getting about

## Steers toward a point on the bot's own level. True once it's there.
## Anything in the way (the pump, trucks, the tower, the deck's edges and the
## walkway out to the boom) is routed round by a grid search over whatever
## the level's walkable area is, so it keeps working if the site changes.
func walk(p, to: Vector3, tol := 0.35) -> bool:
	var at: Vector3 = p.position
	var goal := to
	var z: String = p.zone
	# (a deck target just past the walkable edge is steered at directly: the
	# bot slides along the formwork to it, as it always has)
	if (z == "ground" or (z == "deck" and game._walkable(to, z, p))) and not _open_line(at, to, z, p):
		goal = _route(p, at, to)
	var d := goal - at
	d.y = 0.0
	if d.length() < tol and goal == to:
		p.ai_move = Vector2.ZERO
		_stuck.erase(p.get_instance_id())
		return true
	var local := d.normalized().rotated(Vector3.UP, -game.cam_yaw)
	var k := 1.0 if goal != to else clampf(d.length() / 0.6, 0.35, 1.0)
	p.ai_move = Vector2(local.x, local.z) * k
	_unstick(p)
	return false

## Watchdog: a bot pushing the stick but going nowhere (wedged on a corner, a
## truck pulled in front of it) sidesteps for a moment and re-plans its route.
var _stuck := {}   # id -> {pos, t, side_t, sign}
func _unstick(p) -> void:
	var id: int = p.get_instance_id()
	var e: Dictionary = _stuck.get(id, {"pos": p.position, "t": 0.0, "side_t": 0.0, "sign": 1.0})
	var dt: float = get_process_delta_time()
	if float(e["side_t"]) > 0.0:
		e["side_t"] = float(e["side_t"]) - dt
		var mv: Vector2 = p.ai_move
		p.ai_move = Vector2(-mv.y, mv.x) * float(e["sign"]) + mv * 0.3
	elif (p.position - (e["pos"] as Vector3)).length() < 0.04 and p.ai_move.length() > 0.3:
		e["t"] = float(e["t"]) + dt
		if float(e["t"]) > 0.8:
			e["t"] = 0.0
			e["side_t"] = 0.5
			e["sign"] = -float(e["sign"])
			_routes.erase(id)
	else:
		e["t"] = 0.0
	e["pos"] = p.position
	_stuck[id] = e

## Can we walk straight there? Elbow room along the way, but the end point
## only has to be walkable (jobs right by the formwork, a truck's tailgate).
## On the deck, plain walkable is enough all the way: it's open slab.
func _open_line(a: Vector3, b: Vector3, zone := "ground", who = null) -> bool:
	var n := int(ceil(a.distance_to(b) / 0.4))
	for i in range(1, n + 1):
		var q := a.lerp(b, float(i) / n)
		if i == n or zone == "deck":
			if not game._walkable(q, zone, who):
				return false
		elif not _roomy(q, zone, who):
			return false
	return true

## Walkable with a bit of elbow room, so routes don't hug the edges.
func _roomy(q: Vector3, zone := "ground", who = null) -> bool:
	for o in [Vector3.ZERO, Vector3(0.35, 0, 0), Vector3(-0.35, 0, 0), Vector3(0, 0, 0.35), Vector3(0, 0, -0.35)]:
		if not game._walkable(q + o, zone, who):
			return false
	return true

const CELL := 0.8
var _routes := {}   # bot -> {t, to, path}

func _route(p, at: Vector3, to: Vector3) -> Vector3:
	var key: int = p.get_instance_id()
	var r: Dictionary = _routes.get(key, {})
	if r.is_empty() or game.phase_t - float(r["t"]) > 0.5 or (r["to"] as Vector3).distance_to(to) > 0.5 or game.phase_t < float(r["t"]) or r.get("zone", "") != p.zone:
		r = {"t": game.phase_t, "to": to, "zone": p.zone, "path": _bfs(at, to, p.zone, p)}
		_routes[key] = r
	var path: Array = r["path"]
	# Head for the furthest waypoint we can walk straight to
	var best := to
	for i in range(path.size() - 1, -1, -1):
		var w: Vector3 = path[i]
		if _open_line(at, w, p.zone, p):
			return w
	return best if path.is_empty() else path[0]

func _bfs(a: Vector3, b: Vector3, zone := "ground", who = null) -> Array:
	var box: Rect2 = game.walk_bounds(zone)
	var x0 := box.position.x
	var z0 := box.position.y
	var nx := int(ceil(box.size.x / CELL))
	var nz := int(ceil(box.size.y / CELL))
	var ca := Vector2i(clampi(int((a.x - x0) / CELL), 0, nx - 1), clampi(int((a.z - z0) / CELL), 0, nz - 1))
	var cb := Vector2i(clampi(int((b.x - x0) / CELL), 0, nx - 1), clampi(int((b.z - z0) / CELL), 0, nz - 1))
	var prev := {ca: ca}
	var frontier: Array = [ca]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var found := false
	while not frontier.is_empty() and not found:
		var next: Array = []
		for c in frontier:
			for d in dirs:
				var n: Vector2i = c + d
				if n.x < 0 or n.y < 0 or n.x >= nx or n.y >= nz or prev.has(n):
					continue
				var w := Vector3(x0 + (n.x + 0.5) * CELL, a.y, z0 + (n.y + 0.5) * CELL)
				if n != cb and not _roomy(w, zone, who):
					continue
				prev[n] = c
				if n == cb:
					found = true
					break
				next.append(n)
			if found:
				break
		frontier = next
	if not found:
		return []
	var out: Array = [b]
	var c2: Vector2i = prev[cb]
	while c2 != ca:
		out.push_front(Vector3(x0 + (c2.x + 0.5) * CELL, a.y, z0 + (c2.y + 0.5) * CELL))
		c2 = prev[c2]
	return out

## Where things are, read off the site's own stations, so nothing's pinned to
## one building's layout.
func _deck(key: String) -> Vector3:
	var v: Vector3 = game.deck_pos(key)
	return Vector3(v.x, game.work_y, v.z)

func _gnd(key: String) -> Vector3:
	return (game.stations[key]["node"] as Node3D).position

## Gets to `zone` (deck or ground) by the ladder or the hoist, then to `pos`.
func go(p, zone: String, pos: Vector3, tol := 0.4) -> bool:
	var tower: bool = game.kit == "tower"
	var wy: float = game.work_y
	if p.zone == "ladder":
		return _ladder_to(p, wy if zone == "deck" else 0.0, true)
	if p.zone == "hoist":
		return false
	if p.zone == zone:
		return walk(p, pos, tol)
	if p.zone == "deck":
		var at: Vector3 = _deck("ladder") if tower else _deck("hoist")
		if walk(p, at, 0.5):
			p.ai_action = _tap()
	elif p.zone == "ground":
		var at2: Vector3 = _gnd("ladder_g") if tower else _gnd("hoist_g")
		if walk(p, at2, 0.5):
			p.ai_action = _tap()
	return false

func _ladder_to(p, want_y: float, step_off: bool) -> bool:
	var top: float = maxf(0.0, game.line.riser_top - 1.6)
	if game.kit == "tower" and game.deck_open():
		top = maxf(top, game.work_y)
	want_y = clampf(want_y, 0.0, top)
	var dy: float = want_y - p.position.y
	if absf(dy) > 0.06:
		p.ai_move = Vector2(0, -signf(dy) * clampf(absf(dy) * 4.0, 0.3, 1.0))
		return false
	if step_off:
		p.ai_leave = _tap()
		return false
	return true

func _station(key: String) -> Vector3:
	var n: Node3D = game.stations[key]["node"]
	return n.global_position

# ------------------------------------------------------------------ boom operator

func _boom(p, delta: float) -> void:
	var g = game
	var wy: float = g.work_y
	if g.climb.active:
		# Dogman: stand where the load and the crane driver can both be seen
		if go(p, "deck", _deck("dogman"), 0.5):
			if _naive_dog:
				_dog_like_a_person(p)
			else:
				g.climb.dog_bot = p
		return
	if g.phase != "pour":
		if p.busy == "":
			go(p, "deck", _deck("boom"))
		return
	if p.busy != "boom":
		var st := _station("boom")
		if go(p, "deck", Vector3(st.x, wy, st.z), 0.5):
			p.ai_action = _tap()
		return
	var line = g.line
	var pour = g.pour
	# Start-up and washout: the slurry and the last of the line into the bin
	if g.ops.wants_bin():
		var bl: Vector3 = g._pour_local(g.ops.bin_world())
		var tb: Vector3 = bl - g._pour_local(g.tip_target)
		tb.y = 0.0
		if tb.length() > 0.08:
			var lb := (tb.normalized() * minf(1.0, tb.length() / 1.2)).rotated(Vector3.UP, -g.cam_yaw)
			p.ai_move = Vector2(lb.x, lb.z)
		p.ai_action = g.ops.over_bin(g.discharge())
		return
	if not g.ops.primed or g.ops.busy():
		return
	# Aim at the lowest spot in the bay being poured
	if _boom_goal_t <= 0.0:
		_boom_goal = pour.next_face_point(pour.cur_bay, g._pour_local(g.discharge()))
		# Keep the hose off the edge forms, so nothing goes over them
		var em: float = maxf(0.75, pour.aim_margin)
		_boom_goal.x = clampf(_boom_goal.x, -pour.bw * 0.5 + em, pour.bw * 0.5 - em)
		_boom_goal.z = clampf(_boom_goal.z, -pour.bd * 0.5 + em, pour.bd * 0.5 - em)
		if pour.round_r > 0.0:
			var fl := Vector2(_boom_goal.x, _boom_goal.z).limit_length(pour.round_r - 1.0)
			_boom_goal = Vector3(fl.x, _boom_goal.y, fl.y)
		_boom_goal_t = 0.5
		# A concreter calling "boom over here" gets the hose
		if g.call_t > 0.0 and g.call_marker.visible:
			_boom_goal = g._pour_local(g.call_marker.global_position)
			_boom_goal.y = 0.0
	_boom_goal_t -= delta
	var to: Vector3 = _boom_goal - g._pour_local(g.tip_target)
	to.y = 0.0
	if to.length() > 0.1:
		var local := (to.normalized() * minf(1.0, to.length() / 1.2)).rotated(Vector3.UP, -g.cam_yaw)
		p.ai_move = Vector2(local.x, local.z)
	# Keep the hopper from running dry: drop to low between trucks
	var info: Dictionary = line.hud_info()
	var feeding: bool = info["bay"] == "discharging"
	# (high or low output is the pump operator's now)
	var ok: bool = line.hopper > 0.25 or feeding and line.hopper > 0.08
	var why := "" if ok else "hopper"
	if pour.raining or g.climb.wind_gust >= g.BOOM_WIND or line.line_down() or line.blocked:
		ok = false
		why = "line"
	if line.hopper < 0.08 and not feeding:
		_bark_once(p, "hopper", "Hopper's empty!")
	elif line.hopper > 1.0:
		forget("hopper")
	# A weeping clamp: stop pumping so the line hand can swap it
	if line.fail_i >= 0 and line.wear > 0.25 and not g.let_burst:
		ok = false
		why = "clamp"
	# Don't pile it up: off the trigger while the hose moves on from a full spot,
	# or while it's still swinging over to the face
	var dl: Vector3 = g._pour_local(g.discharge())
	var under: float = pour.height_at(dl)
	if to.length() > 2.5 and under > pour.SLAB * 1.3:
		ok = false
		why = "pile"
	# (on a big slab's wide splash, never stand building a heap: wait for the
	# hose to move on to fresh deck)
	if pour.vol_k > 1.0 and under > pour.SLAB * 1.5:
		ok = false
		why = "heap"
		# (a goal that only heaps up beside it: give up on it for a while)
		_heap_t += delta
		if _heap_t > 1.5:
			_heap_t = 0.0
			pour.skip_near(_boom_goal, 1.2, 25.0)
			_boom_goal_t = 0.0
	else:
		_heap_t = 0.0
	# Never ahead of the bay being poured (swinging across from the bin, or
	# the hose hand still catching up)
	# (a hose that's stopped moving is as far as the boom reaches: pump there)
	var hv: float = Vector2(dl.x - _last_dl.x, dl.z - _last_dl.z).length() / maxf(delta, 0.001)
	_last_dl = dl
	var swinging := hv > 0.4
	if swinging and (pour.bay_of_x(dl.x) > pour.cur_bay or to.length() > 3.5):
		ok = false
		why = "swing"
	if why != "" and game.autotest:
		stop_t[why] = float(stop_t.get(why, 0.0)) + delta
	_boom_ok = ok
	p.ai_action = ok

# ------------------------------------------------------------------ hose hand

var _hose_goal := Vector3.INF
var stop_t := {}     # (test) s the boom bot held off pumping, by reason
var _last_dl := Vector3.ZERO
var _hose_goal_t := 0.0

## The hose hand: take the end hose from under the boom, walk it to the bin for
## the slurry and the washout, and on the pour put it where the boom can't
## quite: the low spots in the leading strip, right out to the forms and into
## the corners.
## Fixing a defect falls to the hose hand (or the poker hand, if the hose hand's
## a person too) when the screeder's a person and slow. (Not the boom op: they
## work off the scaffold and can't step onto the pad.)
func _cover_defect(p) -> bool:
	var g = game
	if g.phase != "inspect" or g.defect_fixed or g.crew.is_bot("screed") or g.phase_t <= 6.0:
		return false
	if p.role == "poker" and g.crew.is_bot("hose"):
		return false
	if go(p, "deck", Vector3(g.defect.position.x, g.work_y, g.defect.position.z), 0.6):
		p.ai_action = true
	return true

func _hose(p, delta: float) -> void:
	var g = game
	var pour = g.pour
	if _cover_defect(p):
		return
	if g.climb.active:
		# The second tag line: same as the poker hand's, off the other corner
		if p.busy == "tag2":
			p.ai_action = true
			return
		if go(p, "deck", _deck("tag2"), 0.45):
			p.ai_action = g.climb.tag_ready(1) and g.climb.tag_hand2 == null
		return
	if g.phase != "pour":
		if p.busy == "" and g.phase != "pour":
			go(p, "deck", _deck("poker") + Vector3(-2.0, 0, -2.0), 0.6)
		return
	if p.zone != "deck":
		go(p, "deck", g.hose_anchor(), 0.6)
		return
	if p.busy != "hose":
		if g.hose_holder == null and walk(p, g.hose_anchor(), 0.6):
			p.ai_action = _tap()
		return
	# On the radio
	if g.ops.role() == "hose":
		p.ai_action = _tap()
		return
	var anchor: Vector3 = g.hose_anchor()
	var tgt := anchor
	if g.ops.wants_bin():
		tgt = g.ops.bin_world()
	else:
		_hose_goal_t -= delta
		if _hose_goal_t <= 0.0 or _hose_goal.x == INF:
			_hose_goal_t = 0.4
			_hose_goal = _hose_spot(anchor)
		tgt = _hose_goal
	# Stand so the nozzle (just in front) is over the spot
	var here: Vector3 = p.position
	var d := Vector3(tgt.x - here.x, 0, tgt.z - here.z)
	if d.length() > 0.7:
		walk(p, Vector3(tgt.x, g.work_y, tgt.z) - d.normalized() * 0.5, 0.25)
	else:
		p.face(Vector3(tgt.x, here.y, tgt.z))
	if g.ops.wants_bin():
		return   # (the slurry and the washout: the boom pumps into the bin)
	# Call the pump on (hold A) when it's worth it, the way the boom bot did
	# before the call was the hose hand's: not into an empty hopper, a weeping
	# clamp or a blocked line, not in the rain or a gust, not while walking off
	# a spot that's full, and never ahead of the bay being poured
	var line = g.line
	var feeding: bool = line.hud_info()["bay"] == "discharging"
	var ok: bool = line.hopper > 0.25 or feeding and line.hopper > 0.08
	if pour.raining or g.climb.wind_gust >= g.BOOM_WIND or line.line_down() or line.blocked or line.tripped:
		ok = false
	if line.fail_i >= 0 and line.wear > 0.25 and not g.let_burst:
		ok = false
	# Don't pile it up while the boom's still swinging over to its next spot
	# (as the boom bot judged it when the trigger was its own)
	var dl: Vector3 = g._pour_local(g.discharge())
	var op = g._boom_operator()
	if op != null and op.bot:
		# (the boom bot still judges the swing, the pile-ups and, on a big
		# slab, the heaps: it moves on from them, the hose hand holds off)
		ok = ok and _boom_ok
	elif pour.vol_k > 1.0 and pour.height_at(dl) > pour.SLAB * 1.5:
		ok = false
	if pour.bay_of_x(dl.x) > pour.cur_bay:
		ok = false
	p.ai_action = ok

## The lowest spot within the end hose's reach that the pour plan wants now.
func _hose_spot(anchor: Vector3) -> Vector3:
	var g = game
	var pour = g.pour
	var best := 1e9
	# (nothing wanted in reach: stay in the bay, by the anchor)
	var al: Vector3 = g._pour_local(anchor)
	var bxx: Vector2 = pour.bay_x(pour.cur_bay)
	var out := anchor + Vector3(clampf(al.x, bxx.x - bxx.y * 0.5 + 0.4, bxx.x + bxx.y * 0.5 - 0.6) - al.x, 0, 0)
	for k in 25:
		# (it works close under the tip: where the boom aims still matters)
		var r: float = 0.0 if k == 0 else g.HOSE_REACH * (0.22 if k <= 8 else 0.45)
		var a := TAU * float(k % 8) / 8.0 + (0.4 if k > 16 else 0.0)
		var q := anchor + Vector3(cos(a), 0, sin(a)) * r
		var loc: Vector3 = g._pour_local(q)
		if not pour.good_pour_spot(loc):
			continue
		var h: float = pour.height_at(loc)
		if h < best:
			best = h
			out = q
	return out

# ------------------------------------------------------------------ truck hand and repairs

## What part the pump operator needs in hand for the repair ahead, or "".
func part_needed() -> String:
	var line = game.line
	if game.phase != "pour":
		return ""
	var step: String = line._step_name()
	if line.job_kind in ["clamp", "burst"] and step in ["depress", "open", "clean", "kit"]:
		return "clamp"
	if line.job_kind == "" and line.fail_i >= 0:
		return "clamp"
	if line.job_kind == "block" and step in ["depress", "open", "lower", "pipe"]:
		return "pipe"
	return ""

func _line(p, delta: float) -> void:
	var g = game
	var line = g.line
	# Climb days: sling the next section on the laydown for the crane (unless
	# the rigger's stood waiting on pins: they go up first), and send the pins up
	if g.climb.active:
		if p.zone != "ground":
			go(p, "ground", _gnd("sling"))
			return
		var pins_first: bool = g.climb.needs_pins() and g.climb.stage in ["roll", "pin"] and (p.held_kind == "pins" or not g.climb.pins_coming())
		if g.climb.needs_sling() and not pins_first:
			if walk(p, _gnd("sling"), 0.5):
				p.ai_action = g.climb.hook_ready()
			return
		if g.climb.needs_pins():
			if p.held_kind == "pins":
				if walk(p, _gnd("haul"), 0.5):
					p.ai_action = _tap()
				return
			if not g.climb.pins_coming() and p.held == null:
				if walk(p, _gnd("pins"), 0.5):
					p.ai_action = _tap()
				return
		walk(p, _gnd("sling") + Vector3(1.2, 0, 0.8), 0.6)
		return
	if p.zone != "ground":
		go(p, "ground", _gnd("bay") + Vector3(0.7, 0, 0.8))
		return
	if p.held != null:
		p.ai_leave = _tap()
	elif g.phase == "pour":
		_bay(p, false)
	else:
		walk(p, _gnd("bay") + Vector3(0.7, 0, 0.8), 0.6)

## The pump operator up the riser: grab the part, climb to the joint and fix
## it (the spike they killed has already taken the pressure off). True while
## there's a repair.
func _repair(p, delta: float) -> bool:
	var g = game
	var line = g.line
	if g.phase != "pour" or not (line.fail_i >= 0 or line.fix_i >= 0 or (line.blocked and not line.block_found)):
		return false
	if g.let_burst and line.fail_i >= 0 and not line.burst:
		return false
	var part := part_needed()
	var coming: bool = part != "" and line.part_coming(part, p)
	# They grab their own part on the way to the joint (anyone can still send
	# one up the haul rope)
	var need_fetch: bool = part != "" and p.held_kind != part and not coming
	var target_j: int = line.fix_i if line.fix_i >= 0 else line.fail_i
	_bark_once(p, "job%d" % line.stats.get("jobs", 0), "On it!")
	match p.zone:
		"deck":
			if g.kit == "tower" and not need_fetch:
				if walk(p, _deck("ladder"), 0.5):
					p.ai_action = _tap()
			else:
				go(p, "ground", _gnd("ladder_g") + Vector3(0.2, 0, 1.5))
		"ground":
			if need_fetch:
				if p.held != null:
					p.ai_leave = _tap()
					return true
				var st: Vector3 = g.GROUND_STATIONS["spares" if part == "clamp" else "rack"]["pos"]
				if walk(p, st, 0.5):
					p.ai_action = _tap()
			elif g.kit == "tower":
				if walk(p, _gnd("ladder_g"), 0.5):
					p.ai_action = _tap()
			else:
				if line.blocked and not line.block_found and line.fix_i < 0:
					target_j = int(g.phase_t / 1.5) % line.clamps.size()
				var jp: Vector3 = line.clamps[maxi(0, target_j)]["pos"]
				if walk(p, Vector3(jp.x, 0, jp.z - 1.5), 0.4):
					_fix(p)
		"ladder":
			var want_y := 0.0
			if need_fetch:
				want_y = 0.0
			elif line.blocked and not line.block_found and line.job_kind == "":
				# Tap the riser every metre and a half, top down
				if _tap_y < 0.0:
					_tap_y = line.riser_top - 2.0
				want_y = _tap_y - 1.0
				if absf(p.position.y - clampf(want_y, 0.0, maxf(0.0, line.riser_top - 1.6))) < 0.1:
					p.ai_action = fmod(g.phase_t, 0.4) < 0.1
					if fmod(g.phase_t, 0.4) < delta:
						_tap_y -= 1.5
						if _tap_y < 0.5:
							_tap_y = line.riser_top - 2.0
			else:
				_tap_y = -1.0
				want_y = line.clamps[maxi(0, target_j)]["pos"].y - 1.0
			want_y = clampf(want_y, 0.0, maxf(0.0, line.riser_top - 1.6))
			var dy: float = want_y - p.position.y
			if absf(dy) > 0.06:
				p.ai_move = Vector2(0, -signf(dy) * clampf(absf(dy) * 4.0, 0.3, 1.0))
			elif not need_fetch and line.joint_near(p) >= 0:
				_fix(p)
			elif need_fetch:
				p.ai_leave = _tap()
	return true

func _fix(p) -> void:
	var line = game.line
	if line.job_kind == "":
		p.ai_action = _tap()
		return
	match line._step_name():
		"open", "close", "lower":
			p.ai_action = true
		"clean", "kit", "pipe":
			p.ai_action = _tap()
		"pin":
			p.ai_action = true

## Rigger on climb days: through the same buttons, jack, roll in, line up the
## holes, podger, hammer the pins home, R-clips on.
func _rigger(p) -> void:
	var c = game.climb
	if p.busy != "rigger":
		if go(p, "deck", _deck("rigger"), 0.5):
			p.ai_action = _tap()
		return
	var prev: bool = p._ai_prev["action"]
	match c.stage:
		"jack":
			p.ai_action = c.ram_state == "ready" and not prev
		"roll":
			p.ai_action = true
		"pin":
			match c.pin_sub:
				"split":
					p.ai_action = not prev
				"align":
					if absf(c.hole_off) > 0.012:
						p.ai_move = Vector2(0, signf(c.hole_off) * clampf(absf(c.hole_off) / 0.04, 0.35, 1.0))
					else:
						p.ai_action = not prev
				"podger":
					p.ai_action = not prev
				"drive":
					if c.winding:
						p.ai_action = c.power < c.SWEET + 0.06
					else:
						p.ai_action = not prev and c.cool <= 0.0
				"clip":
					p.ai_action = true

# ------------------------------------------------------------------ pump operator

func _pump(p, delta: float) -> void:
	var g = game
	var line = g.line
	# Start-up and washout jobs at the panel come first, and the release
	# valve to blow the washout water back
	if g.phase == "pour" and g.ops.role() == "pump":
		if go(p, "ground", _gnd("valve" if g.ops.stage == "valve" else "panel"), 0.5):
			p.ai_action = true
		return
	# Climb days: rigger on the climbing frame
	if g.climb.active:
		_rigger(p)
		return
	# Eyes on the gauge. A spike: kill it (A), as quick as this tier of bot
	# reacts, wherever they are
	if g.phase == "pour" and line.spike_on:
		if line.spike_t >= REACT_T[g.score.bot_tier]:
			p.ai_action = _tap()
		return
	# Something broken on the line: up the riser to fix it
	if _repair(p, delta):
		return
	_tap_y = -1.0
	if p.zone != "ground":
		go(p, "ground", _gnd("panel") + Vector3(-4.6, 0, 0.7))
		return
	if g.phase == "setup":
		for i in 4:
			if g.outriggers[i] < 1.0:
				if walk(p, g.GROUND_STATIONS["rig%d" % i]["pos"], 0.5):
					p.ai_action = true
				return
		return
	var panel: Vector3 = g.GROUND_STATIONS["panel"]["pos"]
	if p.held != null:
		p.ai_leave = _tap()
		return
	if g.phase != "pour":
		walk(p, panel + Vector3(0.6, 0, 0.9), 0.6)
		return
	# Tripped: back to the panel and hold A to restart
	if line.tripped:
		if walk(p, panel, 0.6):
			p.ai_action = true
		return
	if line.live and line.idle_t > line.SET_TIME * 0.5 and not line.line_down():
		if walk(p, panel, 0.6):
			p.ai_action = fmod(g.phase_t, 0.3) < 0.1
		return
	walk(p, panel + Vector3(0.6, 0, 0.9), 0.6)

## The truck bay. With `urgent_only`, only acts if a truck needs something now.
func _bay(p, urgent_only: bool) -> bool:
	var line = game.line
	var t = line.needs_check()
	var bay: Vector3 = game.GROUND_STATIONS["bay"]["pos"]
	# Spotting the truck it waved in: wave it on, let go about on the mark
	for tr in line.trucks:
		if tr["state"] in ["called", "approach", "back"] and tr.get("spotter") == p:
			walk(p, bay, 0.6)
			if tr["state"] == "back":
				if not tr.has("bot_stop"):
					tr["bot_stop"] = 1.0 + randf_range(-1.0, 1.0) * [0.05, 0.03, 0.015][game.score.bot_tier]
				p.ai_action = float(tr.get("su", 0.0)) < float(tr["bot_stop"])
			return true
	if t != null:
		if walk(p, bay, 0.6):
			if not t["checked"]:
				p.ai_action = true
			else:
				# Reads the docket (a moment), then makes the right call
				t["read_t"] = float(t.get("read_t", 0.0)) + get_process_delta_time()
				if float(t["read_t"]) < READ_T[game.score.bot_tier]:
					return true
				var call: String = line.right_call(t)
				if t.get("mix_wrong", "") != "" and call == "reject":
					# (a bot doesn't always spot the wrong mix on the docket)
					if not t.has("bot_saw"):
						t["bot_saw"] = randf() > [0.3, 0.15, 0.05][game.score.bot_tier]
					if not t["bot_saw"]:
						call = "use"
				match call:
					"use":
						p.ai_action = _tap()
					"water":
						p.ai_alt = _tap()
					_:
						p.ai_leave = _tap()
		return true
	if line.too_old_queued() != null:
		if walk(p, bay, 0.6):
			p.ai_leave = _tap()
		return true
	if line.can_wave_in():
		if walk(p, bay, 0.6):
			p.ai_action = _tap()
		return true
	if urgent_only:
		return false
	walk(p, bay, 0.8)
	return true

# ------------------------------------------------------------------ poker hand

func _poker(p, _delta: float) -> void:
	var g = game
	var wy: float = g.work_y
	if g.climb.active:
		# The tag line: wait at the tag spot, then hold A once the load's over
		# the deck (the run out to the line and back is the job's own)
		if p.busy == "tag":
			p.ai_action = true
			return
		if go(p, "deck", _deck("tag"), 0.45):
			p.ai_action = g.climb.tag_ready() and g.climb.tag_hand == null
		return
	if _cover_defect(p):
		return
	if g.phase != "pour":
		if p.busy == "":
			go(p, "deck", _deck("poker") + Vector3(0.5, 0, -1.8))
		return
	if p.zone != "deck":
		go(p, "deck", _deck("poker") + Vector3(0.5, 0, -1.8))
		return
	var poker = g.poker
	var pour = g.pour
	if p.tool != "poker":
		var at: Vector3 = g.rig.position + poker.station_local()
		if walk(p, Vector3(at.x, wy, at.z), 0.6):
			p.ai_action = _tap()
		return
	var st: Dictionary = poker._state(p)
	if st["state"] == "in":
		p.ai_action = pour.raw_count(st["spot"], poker.R) > 0
		return
	if st["state"] == "out":
		return
	var local: Vector3 = p.position - pour.position
	local.y = 0.0
	# Keep one target until it's done, so the bot doesn't chase its own tail.
	# But a patch that's about to go off comes first: otherwise, with fresh
	# loads landing right beside it, the bot never gets round to the far
	# corner and it goes off raw
	var urgent: Array = pour.raw_spots(1, 0.0)
	var hot: bool = urgent.size() > 0 and float(urgent[0][1]) > URGENT_PK
	if hot and not _pk_urgent:
		_pk_target = urgent[0][0]
		_pk_urgent = true
	elif _pk_target.x == INF or pour.raw_count(_pk_target, poker.R * 0.7) <= 2:
		if hot:
			_pk_target = urgent[0][0]
			_pk_urgent = true
		else:
			_pk_target = poker.next_spot(local)
			_pk_urgent = false
	# Square up to it: the poker goes in just in front of you
	var close: Vector3 = pour.position + _pk_target - p.position
	close.y = 0.0
	if _pk_target.x != INF and close.length() < 0.75 and st["state"] == "":
		p.face(pour.position + _pk_target)
	var tgt: Vector3 = _pk_target
	if tgt.x == INF:
		return
	var to: Vector3 = pour.position + tgt
	to.y = wy
	var unit_w: Vector3 = g.rig.position + poker.unit_local
	if Vector2(to.x - unit_w.x, to.z - unit_w.z).length() > poker.HOSE_LEN - 0.8:
		p.ai_alt = true
	var appr: Vector3 = to - p.position
	appr.y = 0.0
	var stand: Vector3 = to - (appr.normalized() * 0.45 if appr.length() > 0.5 else Vector3(sin(p.model.rotation.y), 0, cos(p.model.rotation.y)) * 0.45)
	if appr.length() < 0.75 or walk(p, stand, 0.3):
		p.ai_move = Vector2.ZERO
		p.ai_action = true

# ------------------------------------------------------------------ screeder

func _screed(p, delta: float) -> void:
	_screed_inner(p, delta)
	# Never press A on the hoist landing: that'd send them down in the cage
	if p.zone == "deck" and Vector2(p.position.x - _deck("hoist").x, p.position.z - _deck("hoist").z).length() < 1.6:
		p.ai_action = false

func _screed_inner(p, delta: float) -> void:
	var g = game
	var wy: float = g.work_y
	if g.phase == "inspect" and not g.defect_fixed:
		if go(p, "deck", Vector3(g.defect.position.x, wy, g.defect.position.z), 0.6):
			p.ai_action = true
		return
	if g.climb.active and g.climb.smoko.bot_step(p, self):
		return
	if g.phase != "pour" or g.climb.active:
		_spot_tries.clear()
		_strip_runs.clear()
		_scr = {"mode": "seek", "x": 0.0, "dir": 1.0, "end": 0.0, "t": 0.0}
		if p.busy == "":
			go(p, "deck", _deck("screed") + Vector3(3.2, 0, 8.2))
		return
	if p.zone != "deck":
		go(p, "deck", _deck("screed") + Vector3(3.2, 0, 8.2))
		return
	var scr = g.screed
	var pour = g.pour
	if p.tool != "screed":
		return   # (the board's handed over automatically)
	var local: Vector3 = p.position - pour.position
	local.y = 0.0
	var hose: Vector3 = g._pour_local(g.discharge())
	var half_d: float = pour.bd * 0.5 - 0.5
	match _scr["mode"]:
		"seek":
			var full: bool = g._filled_ratio() >= 1.0
			# (spots tried a few times without luck are left a while)
			var now: float = g.phase_t
			for k in _spot_tries.keys():
				if _spot_tries[k]["n"] >= 3 and now - float(_spot_tries[k]["at"]) > 20.0:
					_spot_tries.erase(k)
			var skip: Array = []
			for k in _spot_tries:
				if _spot_tries[k]["n"] >= 3:
					skip.append(_spot_tries[k]["p"])
			var tgt: Vector3 = pour.needs_screed(local, hose, 0.0 if full else 2.4, skip)
			if tgt.x == INF:
				# Nothing ready: wait behind the pokers, out from under the boom
				var wait := Vector3(clampf(hose.x - 4.0, -pour.bw * 0.5 + 1.0, pour.bw * 0.5 - 1.0), 0, clampf(-hose.z * 0.5, -pour.bd * 0.5 + 1.5, pour.bd * 0.5 - 1.5))
				wait = _on_slab(wait, 1.0)
				walk(p, pour.position + Vector3(wait.x, 0, wait.z) + Vector3(0, wy - pour.position.y, 0), 0.8)
				return
			var strip: float = scr.BOARD - 0.3
			var x: float = clampf(roundf((tgt.x + pour.bw * 0.5 - strip * 0.5) / strip) * strip - pour.bw * 0.5 + strip * 0.5, -pour.bw * 0.5 + 1.2, pour.bw * 0.5 - 1.2)
			var dir := 1.0 if tgt.z < 0.0 else -1.0
			if pour.round_r > 0.0:
				x = clampf(x, -pour.round_r + 1.2, pour.round_r - 1.2)
			if pour.strip_work(x - strip * 0.5, x + strip * 0.5) >= 14 and absf(tgt.x - x) < 1.3 and not _strip_worn(x):
				_scr = _strip_pull(x, dir, half_d)
			else:
				# Odd bits (a corner, an edge, a patch a strip can't reach): stand
				# inside it, board on the patch, and pull it in toward the middle
				_scr = {"mode": "spot_go", "tgt": tgt, "t": 0.0}
		"spot_go":
			var tgt2: Vector3 = _scr["tgt"]
			var n := _inward(tgt2)
			# Second and third goes at the same patch come at it from an angle
			var key := "%d,%d" % [int(round(tgt2.x * 2.0)), int(round(tgt2.z * 2.0))]
			var tries: int = int(_spot_tries.get(key, {}).get("n", 0))
			if tries == 1:
				n = n.rotated(Vector3.UP, 0.7)
			elif tries >= 2:
				n = n.rotated(Vector3.UP, -0.7)
			var stand := _on_slab(tgt2 + n * 0.85, 0.45)
			_scr["t"] += delta
			p.ai_action = false
			if walk(p, pour.position + Vector3(stand.x, wy - pour.position.y, stand.z), 0.25) or _scr["t"] > 7.0 * sqrt(pour.vol_k):
				_spot_tries[key] = {"n": tries + 1, "at": g.phase_t, "p": tgt2}
				p.model.rotation.y = atan2(-n.x, -n.z)   # facing the patch
				_scr = {"mode": "spot_pull", "tgt": tgt2, "n": n, "from": stand, "t": 0.0}
		"spot_pull":
			var n2: Vector3 = _scr["n"]
			_scr["t"] += delta
			p.ai_action = true
			if _scr["t"] < 0.3:
				# Board down onto the patch first
				p.model.rotation.y = atan2(-n2.x, -n2.z)
				return
			var to_pt := _on_slab((_scr["from"] as Vector3) + n2 * 1.5, 0.45)
			if walk(p, pour.position + Vector3(to_pt.x, wy - pour.position.y, to_pt.z), 0.25) or _scr["t"] > 3.5:
				p.ai_action = false
				_scr = {"mode": "seek", "x": 0.0, "dir": 1.0, "end": 0.0, "t": 0.0}
		"approach":
			var dir: float = _scr["dir"]
			# Walking backwards, the board trails behind: start right at the form so
			# it's dragged in over the edge row, and finish at the far form
			var start := Vector3(_scr["x"], 0, float(_scr.get("start", -_half_at(float(_scr["x"]), half_d) * dir)))
			var at: Vector3 = pour.position + start
			at.y = wy
			_scr["t"] += delta
			# Stepping across to the next strip, the board stays down: it's
			# dragged along the form, finishing the edge and the corners
			# (only if there's concrete under the board, not bare deck)
			p.ai_action = bool(_scr.get("hold", false)) and _under_board(p)
			if walk(p, at, 0.35) or _scr["t"] > 6.0 * sqrt(pour.vol_k):
				if not p.ai_action:
					p.model.rotation.y = 0.0 if dir > 0.0 else PI
				_scr["mode"] = "sweep"
				_scr["t"] = 0.0
		"sweep":
			var dir2: float = _scr["dir"]
			var end: Vector3 = pour.position + Vector3(_scr["x"], 0, float(_scr["end"]))
			end.y = wy
			_scr["t"] += delta
			p.ai_action = _under_board(p) or scr.carry > 0.01
			var arrived := walk(p, end, 0.3)
			# Don't screed under the boom's hose
			var ahead: Vector3 = local + Vector3(0, 0, dir2 * 1.2)
			var under_hose: bool = g._filled_ratio() < 1.0 and Vector2(ahead.x - hose.x, ahead.z - hose.z).length() < 1.6
			if arrived or _scr["t"] > 9.0 * sqrt(pour.vol_k) or under_hose:
				p.ai_action = arrived
				# Down one strip and back up the next, the way a crew works a slab:
				# step across a board's width and pull it back the other way
				var strip: float = scr.BOARD - 0.3
				var nx := -INF
				if arrived:
					for cand in [float(_scr["x"]) + strip, float(_scr["x"]) - strip]:
						var lim: float = (pour.round_r if pour.round_r > 0.0 else pour.bw * 0.5) - 1.2
						var cx: float = clampf(cand, -lim, lim)
						if absf(cx - float(_scr["x"])) < 1.0:
							continue
						if pour.strip_work(cx - strip * 0.5, cx + strip * 0.5) >= 8 and not _strip_worn(cx):
							nx = cx
							break
				if nx > -INF:
					_scr = _strip_pull(nx, -dir2, half_d)
					_scr["hold"] = true
				else:
					p.ai_action = false
					_scr = {"mode": "seek", "x": 0.0, "dir": 1.0, "end": 0.0, "t": 0.0}

## A pull down the strip at `x`, only as far as there's concrete wanting it:
## from the form (or just short of the first rough bit) to just past the last.
func _strip_pull(x: float, dir: float, half_d: float) -> Dictionary:
	var pour = game.pour
	var strip: float = game.screed.BOARD - 0.3
	var half := _half_at(x, half_d)
	var band: Vector2 = pour.strip_band(x - strip * 0.5, x + strip * 0.5)
	var start := -half * dir
	var end := half * dir
	if band.x != INF:
		if dir > 0.0:
			start = maxf(-half, band.x - 1.5)
			end = minf(half, band.y + 1.5)
		else:
			start = minf(half, band.y + 1.5)
			end = maxf(-half, band.x - 1.5)
	# (a start within a couple of metres of the form goes right to it, to catch the edge)
	if absf(start) > half - 2.0:
		start = -half * dir
	if absf(end) > half - 2.0:
		end = half * dir
	var key := int(roundf(x * 2.0))
	var run: Dictionary = _strip_runs.get(key, {"n": 0, "at": 0.0})
	_strip_runs[key] = {"n": int(run["n"]) + 1, "at": game.phase_t}
	return {"mode": "approach", "x": x, "dir": dir, "start": start, "end": end, "t": 0.0}

## A strip that's been pulled a couple of times lately: what's left on it is
## odd bits (low spots, fresh top-ups), better done as spot work or later.
func _strip_worn(x: float) -> bool:
	var key := int(roundf(x * 2.0))
	if not _strip_runs.has(key):
		return false
	var run: Dictionary = _strip_runs[key]
	if game.phase_t - float(run["at"]) > STRIP_REST:
		_strip_runs.erase(key)
		return false
	return int(run["n"]) >= STRIP_AGAIN

## Concrete in front of the screeder, where the board would land (or just
## inside it, so a pull that starts at the form still catches the edge row).
func _under_board(p) -> bool:
	var pour = game.pour
	var fwd := Vector3(sin(p.model.rotation.y), 0, cos(p.model.rotation.y))
	var c: Vector3 = p.global_position + fwd * 0.85 - pour.position
	return pour.height_at(c) > 0.05 or pour.height_at(c + fwd * 0.5) > 0.05 or pour.height_at(c - fwd * 0.6) > 0.05

## Pulls a pour-local point onto the slab, `margin` in from its edge.
func _on_slab(v: Vector3, margin: float) -> Vector3:
	var pour = game.pour
	var out := Vector3(v.x, 0, v.z)
	if pour.round_r > 0.0:
		var f := Vector2(out.x, out.z).limit_length(pour.round_r - margin - 0.4)
		return Vector3(f.x, 0, f.y)
	out.x = clampf(out.x, -pour.bw * 0.5 + margin, pour.bw * 0.5 - margin)
	out.z = clampf(out.z, -pour.bd * 0.5 + margin, pour.bd * 0.5 - margin)
	return out

## Which way is "in" from a spot on the slab: straight in from the nearest
## edge (or corner), or toward the middle of a round slab.
func _inward(v: Vector3) -> Vector3:
	var pour = game.pour
	if pour.round_r > 0.0:
		var f := Vector2(-v.x, -v.z)
		if f.length() < 0.5:
			f = Vector2(0, 1)
		f = f.normalized()
		return Vector3(f.x, 0, f.y)
	var n := Vector3.ZERO
	if absf(v.x) > pour.bw * 0.5 - 1.6:
		n.x = -signf(v.x)
	if absf(v.z) > pour.bd * 0.5 - 1.6:
		n.z = -signf(v.z)
	if n == Vector3.ZERO:
		n = Vector3(0, 0, -signf(v.z) if absf(v.z) > 0.1 else 1.0)
	return n.normalized()

## How far a screed strip at `x` runs from the middle: the whole depth of a
## square slab, or the chord of a round one.
func _half_at(x: float, half_d: float) -> float:
	var r: float = game.pour.round_r
	if r <= 0.0:
		return half_d
	return maxf(0.6, sqrt(maxf(0.0, (r - 0.55) * (r - 0.55) - x * x)))

## Test only (`--naive-dog`): dogs the way a first-timer would, through the
## buttons: push the stick toward the ghost, and hold A once it's over it.
func _dog_like_a_person(p) -> void:
	var c = game.climb
	if p.busy != "dogman":
		p.ai_action = c.stage in ["fly", "guide"] and _tap()
		return
	if c.stage != "guide" or c.load == null:
		return
	var lp: Vector3 = c.load.position
	var to := Vector3(c.LAT_X - lp.x, 0, c.RUNWAY_Z - lp.z)
	# Test only (`--knocktest`): steer it gently into the tower first
	if OS.get_cmdline_user_args().has("--knocktest") and c.stage_t < 9.0:
		to = Vector3(c.LAT_X - lp.x, 0, 0.0 - lp.z)
		p.ai_slow = true
		var local0 := to.normalized().rotated(Vector3.UP, -game.cam_yaw)
		p.ai_move = Vector2(local0.x, local0.z)
		p.ai_action = c.stage_t > 1.0   # lower it as it drifts in
		return
	if to.length() > 0.35:
		var local := to.normalized().rotated(Vector3.UP, -game.cam_yaw)
		p.ai_move = Vector2(local.x, local.z)
	else:
		p.ai_action = true

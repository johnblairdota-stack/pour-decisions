## Spire's climb day, as on John's day at The Tannery (21 Nov 2026): every third level the tower crane
## lifts the placing boom's whole square column up through the slab openings, a pipe length at a time.
##   1. PARK      the boom operator swings the boom round, folds it and pins it
##   2. BOOM OFF  the pump operator, up on the column's platform, knocks out its 8 pins, and the crane
##                lifts the boom off onto the deck
##   3. ADAPTOR   4 more pins, and the adaptor plate comes off on the crane too
##   4. LUGS      the hook's shackled onto the two red lugs on the column's top
##   5. WEDGES    the hose hand, down the ladder, knocks the wedges and corner plates out of the slab
##                it's wedged at, and pulls the feet in off the pads
##   6. LIFT x5   the crane lifts the column a pipe length; the boom operator, dogging, whistles the stop
##                at the mark (the driver reacts a moment later). The truck hand sends a pipe up the
##                rope and the hose hand fits it in under the column, with a ladder length every
##                other lift
##   7. SEAT      feet out onto the pads two floors under the new deck, wedges and plates in up top
##   8. BOOM ON   shackles off, the adaptor and the boom back on, 4 + 8 pins
##   9. CHECK     the mobilisation check: the boom operator unfolds it and swings it on the remote
## Bots do any job nobody's doing (bots.gd hands them to bot()).
extends Node3D

signal finished

const F := preload("res://scripts/factory.gd")
const LineScript := preload("res://scripts/line.gd")
const SpireSite := preload("res://scripts/spire_site.gd")

const PIPES := 5
const HOIST_V := 0.32       # m/s the crane lifts the column
const CREEP_V := 0.1        # m/s inching it up or down on a held call
const OP_DELAY := 0.35      # s: the driver's reaction to the whistle
const STOP_TOL := 0.12      # m either side of the mark the pipe still goes in
const NO_CALL := 0.6        # m past the mark: the driver stops it himself
const PIN_T := 0.5          # s a pin takes to knock out or drive home
const REACH := 1.4          # m from a deck or ground job

var game
var active := false
var step := ""
var step_t := 0.0
var prog := 0.0             # 0..1 of the current job
var count := 0              # pins done this job
var lift_i := 0             # pipes in so far
var lifted := 0.0           # m the column's risen
var rise := 0.0             # m it rises today
var from_head := 0.0        # its head height before
var to_head := 0.0          # ...and after
var foot0 := 0.0            # the slab its feet were on
var wedge0 := 0.0           # ...and the one it was wedged at
var foot1 := 0.0
var wedge1 := 0.0
var feet := true
var wedged := true
var hoist := ""             # "up", "stopping", "held", "creep_up", "creep_down", ""
var _stop_in := 0.0
var _called := false
var _bot_err := 0.0
var _jobs_done := {}        # step -> who did it

# The crane: the hook goes where `_hook_to` says, a waypoint at a time
var hook_pos := Vector3.ZERO
var _way: Array = []
var _load: Node3D           # what's on the hook (the boom's head, the adaptor, or null)
var _load_off := Vector3.ZERO
var _on_column := false     # shackled to the column's lugs
var _slings: Array[MeshInstance3D] = []
var _pipe: Node3D           # the pipe on its way up the haul rope
var _pipe_y := 0.0
var _rope: MeshInstance3D
var _boom_rest := Vector3.ZERO
var _adaptor: Node3D
var _adaptor_rest := Vector3.ZERO
var _mark: Label3D          # the dogman's mark at the column's foot: "0.4 m to go"
var _saved_borrow: Callable

func _ready() -> void:
	for i in 2:
		var s := F.cylinder(0.03, 1.0, F.color_mat(Color("3a6bd1")), Vector3.ZERO, 5)
		s.visible = false
		add_child(s)
		_slings.append(s)
	_rope = F.cylinder(0.015, 1.0, F.color_mat(Color("d9c27a")), Vector3.ZERO, 5)
	_rope.visible = false
	add_child(_rope)
	_mark = F.label3d("", 30, Color("ffc72c"))
	_mark.visible = false
	_mark.no_depth_test = true
	add_child(_mark)

## Today's a climb day: the column stands where it was for the last three levels.
func start() -> void:
	var g = game
	var k: int = g.k
	active = true
	step = ""
	lift_i = 0
	lifted = 0.0
	feet = true
	wedged = true
	hoist = ""
	_jobs_done = {}
	from_head = g.spire_mast_head(k - 1)
	to_head = g.spire_mast_head(k)
	rise = to_head - from_head
	foot0 = g.spire_foot_y(k - 1)
	wedge0 = g.spire_wedge_y(k - 1)
	foot1 = g.spire_foot_y(k)
	wedge1 = g.spire_wedge_y(k)
	_place_column()
	_saved_borrow = g.climb.borrow
	g.climb.borrow = Callable(self, "_crane")
	hook_pos = Vector3(g.climb.trolley_xz.x, g.climb.CRANE_H - g.climb.cable_len, g.climb.trolley_xz.y)
	_way = []
	_boom_rest = _laydown(0)
	_adaptor_rest = _laydown(1)
	g.climb.park_stage = "slew"
	g.climb.park_slew = 0.0
	g.climb.park_fold = 0.0
	_go("park")
	g.hud.toast("Climb day: the crane lifts the boom's column %.0f m up through the slabs" % rise, 3.0)

func _place_column() -> void:
	var g = game
	g.spire_column(from_head + lifted, foot0 if lifted < rise - 0.01 else foot1, wedge0 if lifted < 0.01 else wedge1, feet, wedged)

# ------------------------------------------------------------------ the steps

## What each step needs: who does it (bot role), where (deck / ground / ladder, and the spot or height),
## what the button says, how many goes and how long each.
func job() -> Dictionary:
	var g = game
	var top_y: float = from_head + lifted - 1.75   # (on the column's platform, under its top)
	var bottom: float = foot0 + lifted
	match step:
		"park":
			return {"role": "boom", "zone": "deck", "at": _boom_spot(), "verb": "hold: park the boom", "n": 1, "t": 0.0}
		"boom_pins":
			return {"role": "pump", "zone": "ladder", "y": top_y, "verb": "knock out boom pin", "n": 8, "t": PIN_T}
		"adaptor_pins":
			return {"role": "pump", "zone": "ladder", "y": top_y, "verb": "knock out adaptor pin", "n": 4, "t": PIN_T}
		"shackle":
			return {"role": "pump", "zone": "ladder", "y": top_y, "verb": "shackle the lugs", "n": 2, "t": 0.8}
		"wedges_out":
			return {"role": "hose", "zone": "ladder", "y": wedge0, "verb": "knock out the wedges", "n": 4, "t": 0.6}
		"feet_in":
			return {"role": "hose", "zone": "ladder", "y": foot0 + 0.1, "verb": "pull the feet in", "n": 1, "t": 1.4}
		"send_pipe":
			return {"role": "line", "zone": "ground", "at": _haul_spot(), "verb": "send a pipe up", "n": 1, "t": 1.0}
		"fit_pipe":
			var what := "fit pipe + ladder" if lift_i % 2 == 0 else "fit the pipe"
			return {"role": "hose", "zone": "ladder", "y": maxf(0.0, bottom - 0.4), "verb": what, "n": 1, "t": 1.6}
		"feet_out":
			return {"role": "hose", "zone": "ladder", "y": foot1 + 0.1, "verb": "feet out on the pads", "n": 1, "t": 1.4}
		"wedges_in":
			return {"role": "hose", "zone": "ladder", "y": wedge1, "verb": "drive the wedges", "n": 4, "t": 0.6}
		"unshackle":
			return {"role": "pump", "zone": "ladder", "y": to_head - 1.75, "verb": "unshackle", "n": 2, "t": 0.6}
		"adaptor_in":
			return {"role": "pump", "zone": "ladder", "y": to_head - 1.75, "verb": "pin the adaptor", "n": 4, "t": PIN_T}
		"boom_in":
			return {"role": "pump", "zone": "ladder", "y": to_head - 1.75, "verb": "pin the boom", "n": 8, "t": PIN_T}
		"check":
			return {"role": "boom", "zone": "deck", "at": _boom_spot(), "verb": "hold: mobilisation check", "n": 1, "t": 0.0}
		"lift":
			return {"role": "boom", "zone": "deck", "at": _dog_spot(), "verb": "", "n": 0, "t": 0.0}
	return {}

func _go(s: String) -> void:
	step = s
	step_t = 0.0
	prog = 0.0
	count = 0
	var j := job()
	var who := ""
	if j.has("role"):
		var p = game.crew.crew.get(j["role"])
		if p != null:
			who = " · " + p.char_name
	var say := {
		"park": "Park the boom", "boom_pins": "Boom pins out, up on the column", "boom_off": "Crane: boom off",
		"adaptor_pins": "Adaptor pins out", "adaptor_off": "Crane: adaptor off", "hook_down": "Crane: hook down to the lugs",
		"shackle": "Shackle the lugs", "wedges_out": "Wedges out", "feet_in": "Feet in off the pads",
		"lift": "Lift %d of %d: dogman, whistle STOP at the mark" % [lift_i + 1, PIPES], "send_pipe": "Pipe up the rope",
		"fit_pipe": "Pipe in under the column", "feet_out": "Feet out onto the pads", "wedges_in": "Wedges in",
		"unshackle": "Shackles off", "adaptor_on": "Crane: adaptor back on", "adaptor_in": "Pin the adaptor",
		"boom_on": "Crane: boom back on", "boom_in": "Pin the boom", "check": "Mobilisation check: unfold it and swing it"}
	if say.has(s):
		game.hud.toast("Climb · %s%s" % [say[s], who if j.get("n", 0) > 0 or s in ["park", "check", "lift"] else ""], 2.2)
	if game.autotest:
		print("[autotest]   mast climb: %s (lifted %.2f of %.2f m)" % [s, lifted, rise])
	# (the ladder catches whoever's climbing at the job's height)
	game.line.extra_stops = [j["y"]] if j.get("zone", "") == "ladder" else []
	match s:
		"boom_off":
			_fly_to(game.head, game.head.global_position + Vector3(0, 2.4, 0), _boom_rest + Vector3(0, 2.4, 0))
		"adaptor_off":
			_adaptor = game.spire_adaptor()
			_fly_to(_adaptor, _adaptor.global_position + Vector3(0, 1.4, 0), _adaptor_rest + Vector3(0, 1.4, 0))
		"hook_down":
			_way = [_lug_hook()]
		"adaptor_on":
			_fly_to(_adaptor, _adaptor.global_position + Vector3(0, 1.4, 0), _col_top() + Vector3(0, 1.4, 0))
		"boom_on":
			_fly_to(game.head, game.head.global_position + Vector3(0, 2.4, 0), _col_top() + Vector3(0, 0.62 + 2.4, 0))
		"lift":
			hoist = "up"
			_called = false
			var tiers := [0.16, 0.09, 0.05]
			_bot_err = randf_range(-1.0, 1.0) * float(tiers[clampi(game.score.bot_tier, 0, 2)])
		"send_pipe":
			pass

func _done_step() -> void:
	match step:
		"park": _go("boom_pins")
		"boom_pins": _go("boom_off")
		"boom_off": _go("adaptor_pins")
		"adaptor_pins": _go("adaptor_off")
		"adaptor_off": _go("hook_down")
		"hook_down": _go("shackle")
		"shackle":
			_on_column = true
			_go("wedges_out")
		"wedges_out":
			wedged = false
			_place_column()
			_go("feet_in")
		"feet_in":
			feet = false
			_place_column()
			_go("lift")
		"lift": _go("send_pipe")
		"send_pipe": _go("fit_pipe")
		"fit_pipe":
			lift_i += 1
			game.line.rebuild_riser()
			game.sfx.hit("clank")
			game.pop("PIPE %d IN" % lift_i, Vector3(LineScript.RISER.x, foot0 + lifted, LineScript.RISER.z) + Vector3(0, 1.2, 0.6), Color("7cd992"))
			if lift_i < PIPES:
				_go("lift")
			else:
				lifted = rise
				feet = true
				_place_column()
				_go("feet_out")
		"feet_out": _go("wedges_in")
		"wedges_in":
			wedged = true
			_place_column()
			_go("unshackle")
		"unshackle":
			_on_column = false
			_way = [hook_pos + Vector3(0, 4.0, 0)]
			_go("adaptor_on")
		"adaptor_on": _go("adaptor_in")
		"adaptor_in":
			game.spire_adaptor_home(_adaptor)
			_adaptor = null
			_go("boom_on")
		"boom_on": _go("boom_in")
		"boom_in":
			game.head.position = Vector3(game.head.position.x, to_head, game.head.position.z)
			_load = null
			_way = [hook_pos + Vector3(0, 6.0, 0)]
			game.climb.park_stage = ""
			_go("check")
		"check":
			_finish()

func _finish() -> void:
	active = false
	step = ""
	game.line.extra_stops = []
	game.climb.borrow = _saved_borrow
	for s in _slings:
		s.visible = false
	_rope.visible = false
	_mark.visible = false
	game.climb.park_slew = 0.0
	game.climb.park_fold = 0.0
	game.line.rebuild_riser()
	game.hud.toast("Column's up %.0f m, wedged and the boom's tested. Back to pouring." % rise, 2.5)
	game.score.award(game.crew.crew.get("pump"), 30, "Climb day")
	finished.emit()

# ------------------------------------------------------------------ every frame

func update(delta: float) -> void:
	if not active:
		return
	step_t += delta
	match step:
		"park":
			if game.climb.park_stage == "done":
				_done_step()
		"check":
			if prog >= 1.0:
				_done_step()
		"boom_off", "adaptor_off", "hook_down", "adaptor_on", "boom_on":
			if _way.is_empty():
				if step in ["boom_off", "adaptor_off"]:
					# (set down: off the hook)
					_load = null
					_way = [hook_pos + Vector3(0, 3.0, 0)]
					game.sfx.hit("thunk")
				_done_step()
		"lift":
			_lift(delta)
		"send_pipe", "fit_pipe":
			_update_pipe(delta)
	_draw(delta)

## The column going up on the hook: the dogman's whistle stops it (a moment later), short or long of
## the mark they inch it with held calls.
func _lift(delta: float) -> void:
	var target := rise * float(lift_i + 1) / float(PIPES)
	var dog = game.crew.crew.get("boom")
	match hoist:
		"up":
			lifted += HOIST_V * delta
			if lifted > target + NO_CALL:
				hoist = "held"
				game.hud.toast("No call: the driver's stopped it himself, well past the mark", 2.0)
				game.sfx.hit("clank")
		"stopping":
			lifted += HOIST_V * delta
			_stop_in -= delta
			if _stop_in <= 0.0:
				hoist = "held"
				var err := lifted - target
				if absf(err) <= STOP_TOL:
					game.pop("ON THE MARK", _mark.global_position + Vector3(0, 0.5, 0), Color("7cd992"))
					if dog != null:
						game.score.award(dog, 15, "Dogging")
				else:
					game.pop("%.0f cm %s" % [absf(err) * 100.0, "short" if err < 0.0 else "over"], _mark.global_position + Vector3(0, 0.5, 0), Color("ff8a1f"))
		"creep_up":
			lifted += CREEP_V * delta
		"creep_down":
			lifted -= CREEP_V * delta
	lifted = clampf(lifted, 0.0, rise + NO_CALL)
	hook_pos = _lug_hook()
	_place_column()
	var err2 := lifted - target
	if hoist in ["held", "creep_up", "creep_down"] and absf(err2) <= STOP_TOL * 0.7 and hoist == "held" and step_t > 0.3:
		_done_step()

## The dogman's whistles, from whoever's the boom operator (a bot: bot()).
func _dog(p, delta: float) -> void:
	var target := rise * float(lift_i + 1) / float(PIPES)
	var err := lifted - target
	match hoist:
		"up":
			p.cue("action", "whistle STOP", clampf(lifted / maxf(target, 0.01), 0.0, 1.0), absf(err) < 0.5)
			if p.action_pressed():
				hoist = "stopping"
				_stop_in = OP_DELAY
				game.sfx.hit("tink")
		"held", "creep_up", "creep_down":
			if absf(err) > STOP_TOL * 0.7:
				var up := err < 0.0
				p.cue("action", "hold: inch it %s" % ("up" if up else "down"), -1.0, true)
				if p.action_held():
					hoist = "creep_up" if up else "creep_down"
				else:
					hoist = "held"

func _update_pipe(delta: float) -> void:
	if _pipe == null:
		return
	var want := maxf(0.6, foot0 + lifted - 1.0)
	if step == "fit_pipe" and _pipe_y < want:
		_pipe_y = minf(want, _pipe_y + 3.0 * game.line.tall_k() * delta)
	_pipe.position = Vector3(LineScript.HAUL.x, _pipe_y, LineScript.HAUL.z)

## A hand job's going (any player at the spot with A held): true when it's done.
func handle_player(p, delta: float) -> bool:
	if not active:
		return false
	if step == "lift" and p == game.crew.crew.get("boom"):
		_dog(p, delta)
		return p.zone != "ladder"
	var j := job()
	if j.is_empty() or int(j.get("n", 0)) <= 0 and not step in ["park", "check"]:
		return false
	if not _at(p, j):
		return false
	var at_ladder: bool = p.zone == "ladder"
	if at_ladder:
		game.line._ladder(p, delta)
		if absf(p.position.y - float(j["y"])) > 0.35:
			return true
	match step:
		"park":
			p.cue("action", j["verb"], (game.climb.park_slew + game.climb.park_fold) * 0.5, true)
			if p.action_held():
				game.climb._park_step(delta, true, true)
			return true
		"check":
			p.cue("action", j["verb"], prog, true)
			if p.action_held():
				prog = minf(1.0, prog + delta / 3.0)
				game.climb.park_fold = 1.0 - clampf(prog * 2.0, 0.0, 1.0)
				game.climb.park_slew = 1.0 - clampf(prog * 2.0 - 1.0, 0.0, 1.0)
			return true
		"send_pipe":
			if _pipe != null:
				return true
	var n: int = j["n"]
	var verb: String = j["verb"]
	if n > 1:
		verb = "%s %d/%d" % [verb, count + 1, n]
	p.cue("action", verb, prog, true)
	if p.action_held():
		prog += delta / maxf(0.05, float(j["t"]))
		p.pose_arms(Vector3(-1.2 + 0.6 * sin(step_t * 14.0), 0, -0.3), Vector3(-1.2 - 0.6 * sin(step_t * 14.0), 0, 0.3))
		if prog >= 1.0:
			prog = 0.0
			count += 1
			game.sfx.hit("thunk" if step.ends_with("pins") or step.ends_with("_in") else "clank")
			if count >= n:
				_jobs_done[step] = p
				game.score.award(p, 5 * n, "Climb day")
				if step == "send_pipe":
					_pipe = _make_pipe()
					_pipe_y = 0.6
					_done_step()
				elif step == "fit_pipe":
					if _pipe != null:
						_pipe.queue_free()
						_pipe = null
					_done_step()
				else:
					_done_step()
	return true

func _at(p, j: Dictionary) -> bool:
	match String(j["zone"]):
		"ladder":
			return p.zone == "ladder" and absf(p.position.y - float(j["y"])) < 1.2
		_:
			var at: Vector3 = j["at"]
			return p.zone == j["zone"] and Vector2(p.position.x - at.x, p.position.z - at.z).length() < REACH

# ------------------------------------------------------------------ bots

## A crew bot's part in the climb day. True: it's been told what to do (bots.gd leaves it alone).
func bot(p, role: String, delta: float) -> bool:
	if not active:
		return false
	var b = game.bots
	var j := job()
	if step == "lift" and role == "boom":
		if not b.go(p, "deck", _dog_spot(), 0.5):
			return true
		var target := rise * float(lift_i + 1) / float(PIPES)
		var err := lifted - target
		var prev: bool = p._ai_prev["action"]
		match hoist:
			"up":
				p.ai_action = not prev and lifted >= target - HOIST_V * OP_DELAY + _bot_err
			"held", "creep_up", "creep_down":
				p.ai_action = absf(err) > STOP_TOL * 0.5
		return true
	if j.is_empty() or j.get("role", "") != role or int(j.get("n", 0)) <= 0 and not step in ["park", "check"]:
		# (nothing for them right now: off the ladder, out of the way)
		if p.zone == "ladder":
			b._ladder_to(p, game.work_y if game.work_y > p.position.y - 6.0 else 0.0, true)
		elif role in ["pump", "hose"] and p.zone == "deck":
			b.walk(p, _deck_wait(role), 0.6)
		elif role == "line":
			b.go(p, "ground", _haul_spot() + Vector3(0.8, 0, 0.9), 0.6)
		elif role == "boom":
			b.go(p, "deck", _dog_spot(), 0.6)
		else:
			b.go(p, "deck", _deck_wait(role), 0.6)
		return true
	if step == "send_pipe" and _pipe != null:
		return true
	match String(j["zone"]):
		"ladder":
			if p.zone == "ladder":
				var y: float = j["y"]
				if b._ladder_to(p, y, false):
					p.ai_action = true
			else:
				# (onto the ladder from wherever they are: the deck's top, or its foot on the street)
				var via: Vector3 = b._deck("ladder") if p.zone == "deck" else b._gnd("ladder_g")
				if float(j["y"]) < game.work_y - 6.0 and p.zone == "deck" and false:
					pass
				if b.walk(p, via, 0.5):
					p.ai_action = b._tap()
		_:
			if b.go(p, j["zone"], j["at"], 0.45):
				p.ai_action = true
	return true

# ------------------------------------------------------------------ the crane

## climb.gd's crane, while it's ours: true every frame (it has the hook).
func _crane(delta: float) -> bool:
	var c = game.climb
	if not _way.is_empty():
		var to: Vector3 = _way[0]
		var dxz := Vector2(to.x - hook_pos.x, to.z - hook_pos.z)
		var step_xz := dxz.limit_length(3.0 * delta)
		var dy := clampf(to.y - hook_pos.y, -2.6 * delta, 2.6 * delta)
		# (up before across, across before down)
		if to.y > hook_pos.y + 0.05 and dxz.length() > 0.2:
			step_xz = Vector2.ZERO
		elif to.y < hook_pos.y - 0.05 and dxz.length() > 0.2:
			dy = 0.0
		hook_pos += Vector3(step_xz.x, dy, step_xz.y)
		if hook_pos.distance_to(to) < 0.05:
			hook_pos = to
			_way.pop_front()
	c.trolley_xz = Vector2(hook_pos.x, hook_pos.z)
	c.cable_len = c.CRANE_H - hook_pos.y
	if _load != null:
		_load.global_position = hook_pos + _load_off
	return true

## Up from where `load` is, over the jump form and the boom's column, and down to `to` (the hook's spot).
func _fly_to(load: Node3D, pick: Vector3, to: Vector3) -> void:
	var clear: float = maxf(game.spire_head_y(game.k), maxf(from_head, to_head)) + 5.0
	_way = [Vector3(pick.x, maxf(hook_pos.y, clear), pick.z), pick]
	# (once the hook's at `pick`, the load's slung on and comes with it)
	_way.append({"sling": load})
	_way.append(Vector3(pick.x, clear, pick.z))
	_way.append(Vector3(to.x, clear, to.z))
	_way.append(to)
	_way = _expand(_way)

## Waypoints with a "sling" marker: split into two runs (the hook's own, then the load's).
func _expand(w: Array) -> Array:
	return w

func _draw(_delta: float) -> void:
	# (the sling marker in the waypoints: the load comes on here)
	if not _way.is_empty() and _way[0] is Dictionary:
		var d: Dictionary = _way.pop_front()
		_load = d["sling"]
		_load_off = _load.global_position - hook_pos
		game.sfx.hit("clank")
	var att: Array = []
	if _load != null:
		var c := _load.global_position
		att = [c + Vector3(0.45, 0.3, 0.0), c + Vector3(-0.45, 0.3, 0.0)]
		if _load == game.head:
			att = [c + Vector3(0.7, 1.0, 0.0), c + Vector3(-0.7, 1.0, 0.0)]
	elif _on_column or step in ["shackle"]:
		var t := _col_top()
		att = [t + Vector3(0.16, 0.25, 0), t + Vector3(-0.16, 0.25, 0)]
	for i in 2:
		_slings[i].visible = att.size() == 2
		if att.size() == 2:
			F.stretch(_slings[i], hook_pos, att[i])
	# The pipe on the haul rope
	_rope.visible = _pipe != null
	if _pipe != null:
		var top := Vector3(LineScript.HAUL.x, from_head + lifted, LineScript.HAUL.z)
		F.stretch(_rope, top, _pipe.position + Vector3(0, 1.1, 0))
	# The dogman's mark: how far the column's foot is off the pipe length
	_mark.visible = step == "lift"
	if _mark.visible:
		var target := rise * float(lift_i + 1) / float(PIPES)
		var togo := target - lifted
		_mark.text = "MARK" if absf(togo) <= STOP_TOL else ("%.1f m to go" % togo if togo > 0.0 else "%.1f m over" % -togo)
		_mark.modulate = Color("7cd992") if absf(togo) <= STOP_TOL else (Color("ffc72c") if togo > 0.0 else Color("ff5a4a"))
		_mark.position = Vector3(LineScript.RISER.x + 0.6, foot0 + lifted + 0.3, LineScript.RISER.z + 0.5)

# ------------------------------------------------------------------ places

func _col_top() -> Vector3:
	var m := SpireSite.mast_xz()
	return Vector3(m.x, from_head + lifted - 0.62, m.y)

func _lug_hook() -> Vector3:
	return _col_top() + Vector3(0, 2.2, 0)

func _boom_spot() -> Vector3:
	var st: Vector3 = game.bots._station("boom")
	return Vector3(st.x + 1.6, game.work_y, st.z)

func _dog_spot() -> Vector3:
	var m := SpireSite.mast_xz()
	return _on_deck(Vector3(m.x + 2.4, 0, m.y + 2.2))

func _haul_spot() -> Vector3:
	return Vector3(LineScript.HAUL.x + 0.9, 0, LineScript.HAUL.z + 0.6)

func _deck_wait(role: String) -> Vector3:
	var m := SpireSite.mast_xz()
	var off := {"pump": Vector3(1.8, 0, 2.8), "hose": Vector3(3.0, 0, 3.0), "poker": Vector3(4.2, 0, 2.0), "screed": Vector3(4.0, 0, 3.6)}
	return _on_deck(Vector3(m.x, 0, m.y) + off.get(role, Vector3(3, 0, 3)))

## The nearest spot on the deck's slab to `p` (at deck height).
func _on_deck(p: Vector3) -> Vector3:
	var g = game
	for r in [0.0, 1.0, 2.0, 3.0, 4.5, 6.0]:
		for a in 12:
			var q: Vector3 = p + Vector3(cos(a * TAU / 12.0), 0, sin(a * TAU / 12.0)) * r
			q.y = g.work_y
			if g.on_pad(q) and g._walkable(q, "deck"):
				return q
	return Vector3(p.x, g.work_y, p.z)

## Where the boom (0) and the adaptor (1) are set down on the deck while the column's lifted.
func _laydown(i: int) -> Vector3:
	var m := SpireSite.mast_xz()
	var p := _on_deck(Vector3(m.x + 6.0 + 2.5 * i, 0, m.y + 4.0))
	return Vector3(p.x, game.work_y + 0.1, p.z)

func _make_pipe() -> Node3D:
	var n := Node3D.new()
	n.add_child(F.cylinder(0.07, 1.9, F.mat("steel"), Vector3(0, 0, 0), 8))
	add_child(n)
	return n

## For the see-through circle: the column's foot while it's going up.
func cut_point() -> Vector4:
	var m := SpireSite.mast_xz()
	return Vector4(m.x, foot0 + lifted + 1.0, m.y, 4.0)

## Spire's climb day, as on John's day at The Tannery (21 Nov 2026): every third level the tower crane
## lifts the placing boom's whole square column up through the slab openings, a pipe length at a time.
##   1. PARK      the boom operator swings the boom round, folds it and pins it
##   2. BOOM OFF  the pump operator, up on the column's platform, knocks out its 4 pins, and the crane
##                lifts the boom off onto the deck
##   3. ADAPTOR   4 more pins, and the adaptor plate comes off on the crane too
##   4. LUGS      the hook's shackled onto the two red lugs on the column's top
##   5. WEDGES    the hose hand, down the ladder, knocks the wedges and corner plates out of the slab
##                it's wedged at, and pulls the feet in off the pads
##   6. LIFT x5   the crane lifts the column a pipe length; the bottom dogger radios the stop
##                at the mark (the driver reacts a moment later). The truck hand sends a pipe up the
##                rope and the hose hand fits it in under the column, with a ladder length every
##                other lift
##   7. SEAT      feet out onto the pads two floors under the new deck, wedges and plates in up top
##   8. BOOM ON   shackles off, the adaptor and the boom back on, 4 + 4 pins
##   9. CHECK     the mobilisation check: the boom operator unfolds it and swings it on the remote
## Bots do any job nobody's doing (bots.gd hands them to bot()).
##
## The crew work the real trades on a climb day (trades.gd CLIMB_SEAT "spire"): the boom op (a pumpy)
## parks the boom and does the check; the top rigger, harnessed on the boom, knocks the 4 boom pins and
## climbs off to do the adaptor's 4; the lug rigger the shackles; the opening rigger the wedges, feet and pipes down the ladder; the BOTTOM
## dogger, at the pipe feed, radios the column to its mark and sends each pipe up; the TOP dogger,
## on the deck, radios the crane for the boom and adaptor lifts. The crane listens to both.
extends Node3D

signal finished

const F := preload("res://scripts/factory.gd")
const LineScript := preload("res://scripts/line.gd")
const SpireSite := preload("res://scripts/spire_site.gd")
const UI := preload("res://scripts/ui.gd")
const Trades := preload("res://scripts/trades.gd")

const PIPES := 5
const HOIST_V := 0.32       # m/s the crane lifts the column
const CREEP_V := 0.1        # m/s inching it up or down on a held call
const OP_DELAY := 0.35      # s: the driver's reaction to the radio call
const STOP_TOL := 0.12      # m either side of the mark the pipe still goes in
const NO_CALL := 0.6        # m past the mark: the driver stops it himself
const PIN_T := 0.5          # s a pin takes to knock out or drive home
const HELP_T := 25.0        # s before a bot takes over a job a person's left
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
var _tag: Label3D           # over the job: what it is and whose
var _absent := {}           # roles a bot's had to stand in for today (it waits less the next time)
var _who: Dictionary = {}     # player -> the label over them: their turn, or who they're waiting on
var open_air := false       # (the erection day's is out on the roof: mast_erect.gd)
var _shot_next := ""        # (dev: shoot this step a few seconds in, once things are moving)
var _radio_ok := false      # the top dogger's called this crane lift (the crane waits for the call)
const CRANE_STEPS := ["boom_off", "adaptor_off", "hook_down", "adaptor_on", "boom_on"]
## What the top dogger radios for each crane lift, and the crane op's answer.
const RADIO := {"boom_off": ["Take the boom up", "Boom's coming up"], "adaptor_off": ["Adaptor's free, take it up", "Adaptor up"],
	"hook_down": ["Hook down to the lugs", "Hook coming down"], "adaptor_on": ["Bring the adaptor back", "Adaptor coming in"],
	"boom_on": ["Bring the boom back on", "Boom coming in"]}

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
	_tag = F.label3d("", 34, Color("ffc72c"))
	_tag.visible = false
	_tag.no_depth_test = true
	add_child(_tag)

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
	_absent = {}
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
	# The roll call: who has which job today, by player tag
	var lines: Array = []
	for role in ["boom", "pump", "poker", "hose", "line", "screed"]:
		if g.crew.crew.get(role) != null:
			lines.append("%s · %s" % [who_text(role), CLIMB_JOB[role]])
	g.hud.job_intro("CLIMB DAY · WHO DOES WHAT", "\n".join(lines), UI.GOLD, 14.0)

func _place_column() -> void:
	var g = game
	# (the first climb: it comes up off the X base the length it was stood at, and its make-up piece
	# goes on under it as it's seated)
	var lvl: int = g.k - 1 if g.spire_free(g.k - 1) and lifted < rise - 0.01 else g.k
	g.spire_column(from_head + lifted, foot0 if lifted < rise - 0.01 else foot1, wedge0 if lifted < 0.01 else wedge1, feet, wedged, lvl)

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
		"harness":
			return {"role": "pump", "zone": "ladder", "y": top_y, "verb": "harness on, climb onto the boom", "n": 1, "t": 1.2}
		"harness2":
			return {"role": "pump", "zone": "ladder", "y": to_head - 1.75, "verb": "harness on, climb onto the boom", "n": 1, "t": 1.2}
		"boom_pins":
			return {"role": "pump", "zone": "ladder", "y": top_y, "verb": "knock out boom pin", "n": 4, "t": PIN_T}
		"adaptor_pins":
			return {"role": "pump", "zone": "ladder", "y": top_y, "verb": "knock out adaptor pin", "n": 4, "t": PIN_T}
		"shackle":
			return {"role": "poker", "zone": "ladder", "y": top_y, "verb": "shackle the lugs", "n": 2, "t": 0.8}
		"wedges_out":
			if g.spire_free(g.k - 1):
				# (its first climb: it's stood free on the X base till now)
				return {"role": "hose", "zone": "ladder", "y": foot0 + 0.1, "verb": "undo the hold-down nuts", "n": 8, "t": 0.5}
			return {"role": "hose", "zone": "ladder", "y": wedge0, "verb": "knock out the wedges", "n": 4, "t": 0.6}
		"feet_in":
			if g.spire_free(g.k - 1):
				return {"role": "hose", "zone": "ladder", "y": foot0 + 0.1, "verb": "unbolt the X base", "n": 1, "t": 1.4}
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
			return {"role": "poker", "zone": "ladder", "y": to_head - 1.75, "verb": "unshackle", "n": 2, "t": 0.6}
		"adaptor_in":
			return {"role": "pump", "zone": "ladder", "y": to_head - 1.75, "verb": "pin the adaptor", "n": 4, "t": PIN_T}
		"boom_in":
			return {"role": "pump", "zone": "ladder", "y": to_head - 1.75, "verb": "pin the boom", "n": 4, "t": PIN_T}
		"check":
			return {"role": "boom", "zone": "deck", "at": _boom_spot(), "verb": "hold: mobilisation check", "n": 1, "t": 0.0}
		"lift":
			return {"role": "line", "zone": "ground", "at": _haul_spot(), "verb": "", "n": 0, "t": 0.0}
		"boom_off", "adaptor_off", "hook_down", "adaptor_on", "boom_on":
			if not _radio_ok:
				return {"role": "screed", "zone": "deck", "at": _dog_spot(), "verb": "radio: " + String(RADIO[step][0]).to_lower(), "n": 1, "t": 0.0, "radio": true}
	return {}

func _go(s: String) -> void:
	step = s
	step_t = 0.0
	_radio_ok = false
	prog = 0.0
	count = 0
	var j := job()
	var who := ""
	if j.has("role"):
		var p = game.crew.crew.get(j["role"])
		if p != null:
			who = " · " + p.char_name
	var say := {
		"park": "Park the boom", "harness": "Top rigger: harness on, onto the boom", "harness2": "Top rigger: harness on, onto the boom",
		"boom_pins": "Boom pins out, harnessed on the boom", "boom_off": "Top dogger: call the boom off",
		"adaptor_pins": "Off the boom: adaptor pins out", "adaptor_off": "Top dogger: call the adaptor off", "hook_down": "Top dogger: hook down to the lugs",
		"shackle": "Shackle the lugs", "wedges_out": "Wedges out", "feet_in": "Feet in off the pads",
		"lift": "Lift %d of %d: bottom dogger, radio STOP at the mark" % [lift_i + 1, PIPES], "send_pipe": "Pipe up the rope",
		"fit_pipe": "Pipe in under the column", "feet_out": "Feet out onto the pads", "wedges_in": "Wedges in",
		"unshackle": "Shackles off", "adaptor_on": "Top dogger: adaptor back on", "adaptor_in": "Pin the adaptor",
		"boom_on": "Top dogger: boom back on", "boom_in": "Pin the boom", "check": "Mobilisation check: unfold it and swing it"}
	if say.has(s):
		game.hud.toast("Climb · %s%s" % [say[s], who if j.get("n", 0) > 0 or s in ["park", "check", "lift"] or s in CRANE_STEPS else ""], 2.2)
	if game._spire_shots != "" and s in ["boom_off", "wedges_out", "fit_pipe", "boom_on", "check"] and (s != "fit_pipe" or lift_i == 2):
		game.mast_shot = s if s != "boom_off" else ""
		_shot_next = "boom_off" if s == "boom_off" else ""
	if game.autotest:
		print("[autotest]   mast climb: %s (lifted %.2f of %.2f m) at %.0fs" % [s, lifted, rise, game.phase_t])
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
		"park": _go("harness")
		"harness": _go("boom_pins")
		"harness2": _go("boom_in")
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
			_load = null
			_way = [hook_pos + Vector3(0, 2.0, 0)]
			game.spire_adaptor_home(_adaptor)
			_adaptor = null
			_go("boom_on")
		"boom_on": _go("harness2")
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
	_tag.visible = false
	for p in _who:
		if is_instance_valid(_who[p]):
			_who[p].queue_free()
	_who = {}
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
	if _shot_next != "" and step_t > 8.0:
		game.mast_shot = _shot_next
		_shot_next = ""
	match step:
		"park":
			if game.climb.park_stage == "done":
				_done_step()
		"check":
			if prog >= 1.0:
				_done_step()
		"boom_off", "adaptor_off", "hook_down", "adaptor_on", "boom_on":
			if _radio_ok and _way.is_empty():
				if step in ["boom_off", "adaptor_off"]:
					# (set down: off the hook)
					_load = null
					_way = [hook_pos + Vector3(0, 3.0, 0)]
					game.sfx.hit("thunk")
				_done_step()
		"lift":
			_lift(delta)
			if game.autotest and fmod(step_t, 5.0) < delta:
				print("[autotest]     lift %d: %s lifted %.2f target %.2f t %.0f" % [lift_i, hoist, lifted, rise * float(lift_i + 1) / float(PIPES), step_t])
		"send_pipe", "fit_pipe":
			_update_pipe(delta)
	_draw(delta)

## The column going up on the hook: the bottom dogger's radio call stops it (a moment later), short or long of
## the mark they inch it with held calls.
func _lift(delta: float) -> void:
	var target := rise * float(lift_i + 1) / float(PIPES)
	var dog = game.crew.crew.get("line")
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
	if hoist == "held" and absf(lifted - target) <= STOP_TOL and step_t > 0.3:
		_done_step()

## The bottom dogger's radio calls, at the pipe feed (a bot: bot()). The crane op can't see the
## column's foot down here: he goes on what the dogger says.
func _dog(p, delta: float) -> void:
	var target := rise * float(lift_i + 1) / float(PIPES)
	var err := lifted - target
	match hoist:
		"up":
			p.cue("action", "radio: ALL STOP", clampf(lifted / maxf(target, 0.01), 0.0, 1.0), absf(err) < 0.5)
			if p.action_pressed():
				hoist = "stopping"
				_stop_in = OP_DELAY
				game.sfx.hit("tink")
				game.hud.toast("Radio · %s: \"All stop\" · Crane: \"Stopping\"" % p.char_name, 1.4)
		"held", "creep_up", "creep_down":
			if absf(err) > STOP_TOL:
				var up := err < 0.0
				p.cue("action", "hold: radio %s slow" % ("up" if up else "down"), -1.0, true)
				if p.action_held():
					hoist = "creep_up" if up else "creep_down"
				else:
					hoist = "held"
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
	if step == "lift" and (p == game.crew.crew.get("line") or (p.bot and p.role == "screed" and _absent.has("line"))):
		_dog(p, delta)
		return p.zone != "ladder"
	var j := job()
	if j.get("radio", false):
		if not _at(p, j):
			return false
		p.cue("action", j["verb"], -1.0, true)
		if p.action_pressed():
			_call_lift(p)
		return true
	if j.is_empty() or (int(j.get("n", 0)) <= 0 and not (step in ["park", "check"])):
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
		"fit_pipe":
			if _pipe != null and _pipe_y < maxf(0.6, foot0 + lifted - 1.0) - 0.05:
				p.cue("action", "pipe's coming up", -1.0)
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

## The top dogger's call on the radio, and the crane op's answer: the lift goes.
func _call_lift(p) -> void:
	_radio_ok = true
	_jobs_done[step] = p
	game.sfx.hit("tink")
	var r: Array = RADIO.get(step, ["Take it up", "Coming up"])
	game.hud.toast("Radio · %s: \"%s\" · Crane: \"%s\"" % [p.char_name, r[0], r[1]], 2.0)
	game.score.award(p, 5, "Climb day")

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
	# (dev: a step that's hung, and where everyone is)
	if game.autotest and step_t > 60.0 and fmod(step_t, 30.0) < delta:
		print("[autotest]     mast step %s hung %.0fs: job %s | %s %s zone %s at %s busy '%s'" % [step, step_t, str(job()), role, p.char_name, p.zone, str(p.position), p.busy])
	var b = game.bots
	var j := job()
	# (a job that's a person's, and they haven't got to it: after a while a bot steps in for them)
	if not j.is_empty() and j.get("role", "") != role and step_t > (6.0 if _absent.has(j.get("role", "")) else HELP_T):
		var owner = game.crew.crew.get(j["role"])
		var back := {"pump": "poker", "poker": "pump", "hose": "pump", "line": "screed", "screed": "line", "boom": "screed"}
		if owner != null and not owner.bot and not owner.covering and back.get(j["role"], "") == role:
			_absent[j["role"]] = true
			j["role"] = role
			if step == "lift":
				role = "line"
	if step == "lift" and role == "line":
		# (at the pipe feed, where the column's foot comes up past the mark)
		b.go(p, "ground", _haul_spot(), 0.6)
		var target := rise * float(lift_i + 1) / float(PIPES)
		var err := lifted - target
		var prev: bool = p._ai_prev["action"]
		match hoist:
			"up":
				p.ai_action = not prev and lifted >= target - HOIST_V * OP_DELAY + _bot_err
			"held", "creep_up", "creep_down":
				p.ai_action = absf(err) > STOP_TOL * 0.5
		return true
	if j.is_empty() or j.get("role", "") != role or (int(j.get("n", 0)) <= 0 and not (step in ["park", "check"])):
		# (nothing for them right now: off the ladder, out of the way; up top, the pump operator waits
		# on the platform while the crane's at work)
		if p.zone == "ladder" and role in ["pump", "poker"] and step in CRANE_STEPS:
			return true
		if p.zone == "ladder":
			b._ladder_to(p, game.work_y if game.work_y > p.position.y - 6.0 else 0.0, true)
		elif role in ["pump", "poker", "hose"] and p.zone == "deck":
			b.walk(p, _deck_wait(role), 0.6)
		elif role == "line":
			b.go(p, "ground", _haul_spot() + Vector3(0, 0, 1.2), 0.6)
		elif role == "screed":
			b.go(p, "deck", _dog_spot(), 0.6)
		elif role == "boom":
			b.go(p, "deck", _boom_spot(), 0.6)
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
				if b.walk(p, via, 0.5):
					p.ai_action = b._tap()
		_:
			if b.go(p, j["zone"], j["at"], 0.45):
				# (a radio call's one press, a beat after they're there)
				p.ai_action = b._tap() if j.get("radio", false) else true
	return true

# ------------------------------------------------------------------ the crane

## climb.gd's crane, while it's ours: true every frame (it has the hook).
func _crane(delta: float) -> bool:
	var c = game.climb
	# (the sling marker in the waypoints: the load comes on here)
	# (a lift waits on the top dogger's call)
	if step in CRANE_STEPS and not _radio_ok:
		c.trolley_xz = Vector2(hook_pos.x, hook_pos.z)
		c.cable_len = c.CRANE_H - hook_pos.y
		return true
	if not _way.is_empty() and _way[0] is Dictionary:
		var d: Dictionary = _way.pop_front()
		_load = d["sling"]
		_load_off = _load.global_position - hook_pos
		game.sfx.hit("clank")
	if not _way.is_empty():
		var to: Vector3 = _way[0]
		var dxz := Vector2(to.x - hook_pos.x, to.z - hook_pos.z)
		var step_xz := dxz.limit_length(4.5 * delta)
		var dy := clampf(to.y - hook_pos.y, -3.5 * delta, 3.5 * delta)
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

func _draw(_delta: float) -> void:
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
	var ja := job_at()
	var j := job()
	var holder = game.crew.crew.get(j.get("role", "")) if not j.is_empty() else null
	# (once they're at it their own button says what to do: the tag would only sit on their name)
	_tag.visible = ja != Vector3.INF and not (holder != null and _at(holder, j))
	if _tag.visible:
		_tag.text = "%s\n%s" % [String(j["verb"]).trim_prefix("hold: ").to_upper(), who_text(String(j["role"]))]
		_tag.position = ja + Vector3(0, 1.6 + 0.08 * sin(step_t * 3.0), 0)
	_draw_who(j)
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
	# (the gin wheel's rope comes down in the passage under the podium, by the ladder's foot)
	return game.bots._gnd("haul")

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

const STEP_ORDER := ["park", "harness", "boom_pins", "boom_off", "adaptor_pins", "adaptor_off", "hook_down", "shackle", "wedges_out", "feet_in",
	"lift", "send_pipe", "fit_pipe", "feet_out", "wedges_in", "unshackle", "adaptor_on", "adaptor_in", "boom_on", "harness2", "boom_in", "check"]
const STEP_SAY := {
	"park": "park the boom", "harness": "top rigger: harness on, onto the boom", "harness2": "top rigger: harness on, onto the boom", "boom_pins": "4 boom pins out", "boom_off": "crane lifts the boom off",
	"adaptor_pins": "4 adaptor pins out", "adaptor_off": "crane lifts the adaptor off", "hook_down": "hook down to the column",
	"shackle": "shackle the 2 red lugs", "wedges_out": "wedges and corner plates out", "feet_in": "feet in off the pads",
	"lift": "crane lifts the column: radio STOP at the mark", "send_pipe": "a pipe up the rope", "fit_pipe": "pipe in under the column",
	"feet_out": "feet out onto the pads", "wedges_in": "wedges and corner plates in", "unshackle": "shackles off",
	"adaptor_on": "crane brings the adaptor back", "adaptor_in": "4 adaptor pins in", "boom_on": "crane brings the boom back",
	"boom_in": "4 boom pins in", "check": "mobilisation check on the remote"}

## Which job each step is (the rest are the tower crane's), and what each job does on a climb day.
const STEP_ROLE := {"park": "boom", "harness": "pump", "harness2": "pump", "boom_pins": "pump", "boom_off": "screed", "adaptor_pins": "pump", "adaptor_off": "screed",
	"hook_down": "screed", "shackle": "poker", "wedges_out": "hose", "feet_in": "hose", "lift": "line", "send_pipe": "line",
	"fit_pipe": "hose", "feet_out": "hose", "wedges_in": "hose", "unshackle": "poker", "adaptor_on": "screed", "adaptor_in": "pump",
	"boom_on": "screed", "boom_in": "pump", "check": "boom"}
const CLIMB_JOB := {
	"boom": "parks the boom, and does the mobilisation check at the end",
	"pump": "up top, harnessed on the boom: the 4 boom pins, then off the boom for the adaptor's 4, out and back in",
	"poker": "up on the column: shackles on and off the red lugs",
	"hose": "down the ladder in the openings: wedges, feet, and each pipe under the column",
	"line": "at the pipe feed: radios the crane to STOP at each mark, and sends the 5 pipes up",
	"screed": "on the deck: radios the crane for the boom and adaptor lifts"}
## The day in eight stages, for the strip on the HUD.
const STAGES := ["BOOM OFF", "ADAPTOR OFF", "HOOK ON", "WEDGES OUT", "LIFT + PIPES", "FEET + WEDGES", "BOOM ON", "CHECK"]
const STAGE_OF := {"park": 0, "harness": 0, "boom_pins": 0, "boom_off": 0, "adaptor_pins": 1, "adaptor_off": 1, "hook_down": 2, "shackle": 2,
	"wedges_out": 3, "feet_in": 3, "lift": 4, "send_pipe": 4, "fit_pipe": 4, "feet_out": 5, "wedges_in": 5, "unshackle": 5,
	"adaptor_on": 6, "adaptor_in": 6, "boom_on": 6, "harness2": 6, "boom_in": 6, "check": 7}

func stages() -> Array:
	var out := STAGES.duplicate()
	if step in ["lift", "send_pipe", "fit_pipe"]:
		out[4] = "LIFT + PIPE %d OF %d" % [mini(lift_i + 1, PIPES), PIPES]
	return out

func stage_i() -> int:
	return int(STAGE_OF.get(step, 0))

## "P2 TASH" for a person, "JULES (bot)" for a bot, on `role`.
func who_text(role: String) -> String:
	var p = game.crew.crew.get(role)
	var job_name := Trades.climb_full(role, "spire", " ").to_upper()
	if p == null:
		return job_name
	if p.bot:
		return "%s (bot) · %s" % [String(p.char_name).to_upper(), job_name]
	return "P%d %s · %s" % [p.index, String(p.char_name).to_upper(), job_name]

## The job that's up after this step (skipping the crane's own moves).
func next_role() -> String:
	match step:
		"lift": return "line"
		"send_pipe": return "hose"
		"fit_pipe": return "line" if lift_i + 1 < PIPES else "hose"
	var i := STEP_ORDER.find(step)
	for n in range(i + 1, STEP_ORDER.size()):
		if STEP_ROLE.has(STEP_ORDER[n]):
			return STEP_ROLE[STEP_ORDER[n]]
	return ""

## Over each person: it's their turn and where to go, or who everyone's waiting on (and "you're next").
func _draw_who(j: Dictionary) -> void:
	var now := String(STEP_ROLE.get(step, ""))
	var nxt := next_role()
	for p in game.crew.humans():
		var l: Label3D = _who.get(p)
		if l == null or not is_instance_valid(l):
			l = F.label3d("", 54, Color("ffc72c"))
			l.no_depth_test = true
			add_child(l)
			_who[p] = l
		var text := ""
		var mine: bool = p.role == now and not p.covering
		if mine:
			if step == "lift" or j.is_empty():
				text = ""        # (the radio call's on their own button)
			elif _at(p, j):
				text = ""
			elif String(j["zone"]) == "ladder":
				var up: bool = float(j["y"]) > p.position.y
				text = "YOUR TURN\n%s THE LADDER" % ("UP" if up else "DOWN")
			elif String(j["zone"]) == "ground":
				text = "YOUR TURN\nDOWN TO THE HAUL ROPE"
			else:
				text = "YOUR TURN\nTO THE BOOM REMOTE"
		else:
			var on := "THE CRANE'S MOVE" if now == "" else "WAITING ON %s" % who_text(now).get_slice(" · ", 0)
			if p.role == nxt:
				text = "%s\nYOU'RE NEXT" % on
			elif not STEP_ROLE.values().has(p.role):
				text = "%s\nNO JOB TODAY · STAND CLEAR" % on
			else:
				text = on
		l.visible = text != ""
		l.text = text
		l.modulate = Color("ffc72c") if mine else Color("e9e4d6")
		l.position = p.global_position + Vector3(0, 3.3 + (0.08 * sin(step_t * 3.0) if mine else 0.0), 0)
	for p in _who.keys():
		if not is_instance_valid(p) or p.bot:
			if is_instance_valid(_who[p]):
				_who[p].queue_free()
			_who.erase(p)

## For the HUD: [task, who it's on, 0..1 of the day, their job].
func hud_task() -> Array:
	var j := job()
	var who := "TOWER CRANE"
	if j.has("role") and game.crew.crew.get(j["role"]) != null:
		who = who_text(String(j["role"]))
	var done := 0.0
	var i := STEP_ORDER.find(step)
	if step in ["lift", "send_pipe", "fit_pipe"]:
		var li := STEP_ORDER.find("lift")
		done = (float(li) + 6.0 * (float(lift_i) + (float(i) - float(li)) / 3.0) / float(PIPES)) / float(STEP_ORDER.size() + 3)
	elif i >= STEP_ORDER.find("feet_out"):
		done = (float(STEP_ORDER.find("lift")) + 6.0 + float(i - STEP_ORDER.find("feet_out"))) / float(STEP_ORDER.size() + 3)
	else:
		done = float(maxi(i, 0)) / float(STEP_ORDER.size() + 3)
	var lift_txt := " · pipe %d of %d" % [mini(lift_i + 1, PIPES), PIPES] if step in ["lift", "send_pipe", "fit_pipe"] else ""
	return ["Climb day · %s%s" % [STEP_SAY.get(step, ""), lift_txt], who, done, String(j.get("role", ""))]

## Where the current job is, for a floating tag over it (Vector3.INF if it's the crane's).
func job_at() -> Vector3:
	var j := job()
	if j.is_empty() or step == "lift":
		return Vector3.INF
	if String(j["zone"]) == "ladder":
		return Vector3(LineScript.LADDER.x, float(j["y"]) + 1.0, LineScript.LADDER.z)
	return (j["at"] as Vector3) + Vector3(0, 0.2, 0)

## For the see-through circle: the job that's inside the building (down the ladder at the wedges, the
## feet or the pipe going in), and the column's foot while it's going up.
func cut_points() -> Array:
	var m := SpireSite.mast_xz()
	var out: Array = []
	var j := job()
	if not j.is_empty() and String(j["zone"]) == "ladder" and float(j["y"]) < game.work_y - 1.0:
		out.append(Vector4(m.x, float(j["y"]) + 0.8, m.y, 4.5))
	if step in ["lift", "send_pipe", "fit_pipe", "feet_in", "feet_out"]:
		out.append(Vector4(m.x, foot0 + lifted + 0.6, m.y, 4.5))
	return out

## For the camera: [what to look at, how far back, is it inside the building (the section view)].
func focus() -> Array:
	var m := SpireSite.mast_xz()
	var top := _col_top()
	match step:
		"boom_off", "adaptor_off", "adaptor_on", "boom_on", "hook_down":
			# (the hook and what's on it, with the column's top)
			var mid := (hook_pos + top) * 0.5
			return [mid, clampf(hook_pos.distance_to(top) * 1.3 + 14.0, 16.0, 40.0), false]
		"lift", "send_pipe", "fit_pipe":
			# (the column's foot, where the mark and the pipe are)
			return [Vector3(m.x, foot0 + lifted + 1.5, m.y), 22.0, true]
	var j := job()
	if not j.is_empty() and String(j["zone"]) == "ladder":
		var inside: bool = float(j["y"]) < game.work_y - 1.0
		return [Vector3(m.x, float(j["y"]) + 1.0, m.y), 22.0 if inside else 14.0, inside]
	return [Vector3(m.x, game.work_y + 2.0, m.y), 20.0, false]

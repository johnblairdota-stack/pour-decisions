## The start and the end of every pour, the way a pump crew runs them.
##
## START-UP (priming), before any concrete goes in the slab:
##   1. START THE PUMP     pump operator, hold A at the PUMP PANEL
##   2. DRAGON'S BREATHING the pump pushes the air out of the line ahead of it:
##                         hot air comes out the hose end. The pipe guy, on the
##                         hose, radios it down (A)
##   3. SLURRY IN          pump operator tips the bag of slurry (cement, sand and
##                         water) into the hopper (hold A at the panel). It
##                         coats the inside of the line so the concrete slides
##   4. SLURRY OUT         the slurry reaches the hose. It mustn't go in the
##                         slab: the boom (and the pipe guy) put the hose over
##                         the BIN and pump it all in (hold A over the bin)
##   5. CONCRETE'S ON      the first concrete comes through: the pipe guy radios
##                         "concrete's on" (A) and the pour begins
##
## WASHOUT, once the slab's full (SCP's water washout: water pumped in behind
## the concrete pushes it out, the last of it goes in a bin, then the water's
## blown back to the pump and into the settling tanks to be used again,
## https://scpaus.com.au/water-washout-clean-out-system/):
##   1. WATER IN           pump operator cleans the hopper and fills it with
##                         water (hold A at the panel)
##   2. INTO THE BIN       the water pushes the last of the concrete out: the
##                         boom puts the hose over the BIN and pumps it out,
##                         concrete then water, into the bin
##   3. BLOW IT BACK       pump operator opens the RELEASE VALVE at the pump (hold
##                         A): the water runs back into the settling tank
##
## Every step has one person and one place, a hand sign and a ticket. Nobody
## gets stuck: a step nobody does gets a loud call, then the crew does it
## (slower, and it costs points).
extends Node3D

const F := preload("res://scripts/factory.gd")
const UI := preload("res://scripts/ui.gd")

const HOLD_T := 1.4          # s to hold A for a panel or valve job
const SLURRY := 0.35         # m³ of slurry to get through the hose
const PUSH := 0.3            # m³ of concrete left in the line at the end
const WATER := 0.18          # m³ of water through after it
const RATE := 0.14           # m³/s out of the hose for these
const BIN_R := 0.85          # m: the hose counts as over the bin inside this
const TRAVEL_T := 2.4        # s for the air (and then the slurry) to reach the hose
const NAG_T := 7.0           # s before a step's call goes out loud
const AUTO_T := 30.0         # s before the crew does a step themselves
const RADIO_AUTO_T := 4.0    # s a bot pipe guy (or nobody) takes to radio
const SIGNAL_AIR := 2.4      # s into "air" when the hot air puffs out of the hose
const SIGNAL_CONC := 0.6     # s into "concrete" when the first grey concrete spurts out
const ON_THE_DOT := 1.2      # s after the sign to call it for the bonus
const PERSON_AUTO := 6.0     # s after the sign before the crew carries on without the call

const STEPS := {
	"start": ["Start the pump", "pump", "panel", "START THE PUMP"],
	"air": ["The dragon's breathing?", "hose", "hose", "RADIO: DRAGON'S BREATHING"],
	"slurry_in": ["Slurry into the hopper", "pump", "panel", "SLURRY IN"],
	"slurry_go": ["Slurry's on its way up", "", "", ""],
	"slurry_out": ["Slurry into the bin, not the slab", "boom", "bin", "BIN"],
	"concrete": ["Concrete's on?", "hose", "hose", "RADIO: CONCRETE'S ON"],
	"water_in": ["Clean the hopper, water in", "pump", "panel", "WATER IN"],
	"push": ["The last of it into the bin", "boom", "bin", "BIN"],
	"valve": ["Blow the water back", "pump", "valve", "OPEN THE VALVE"],
}
const PRIME_ORDER := ["start", "air", "slurry_in", "slurry_go", "slurry_out", "concrete"]
const WASH_ORDER := ["water_in", "push", "valve"]

var game
var stage := ""             # a STEPS key, "pour" while pouring, "done" after the washout
var primed := false
var washed := false
var step_t := 0.0
var hold := 0.0              # hold progress on the current panel/valve job
var left := 0.0              # m³ still to come out of the hose this step
var in_bin := 0.0            # m³ in the bin
var _nagged := false
var bin: Node3D
var _bin_fill: MeshInstance3D
var steam: CPUParticles3D
var water_fx: CPUParticles3D
var tank: Node3D
var tank_label: Label3D
var _tank_water: MeshInstance3D
var _tank_ring: MeshInstance3D
var _tank_ring_mat: StandardMaterial3D
var _tank_arrow: Label3D
var _tank_t := 0.0
var _spill_t := 0.0

func setup(owner_game) -> void:
	game = owner_game
	# The bin: a steel skip on the scaffold by the boom
	bin = Node3D.new()
	bin.add_child(F.box(Vector3(1.2, 0.08, 0.9), F.mat("steel"), Vector3(0, 0.04, 0)))
	for side in [[Vector3(1.2, 0.8, 0.06), Vector3(0, 0.44, 0.42)], [Vector3(1.2, 0.8, 0.06), Vector3(0, 0.44, -0.42)],
			[Vector3(0.06, 0.8, 0.9), Vector3(0.57, 0.44, 0)], [Vector3(0.06, 0.8, 0.9), Vector3(-0.57, 0.44, 0)]]:
		bin.add_child(F.box(side[0], F.mat("orange"), side[1]))
	_bin_fill = F.box(Vector3(1.08, 1.0, 0.78), F.color_mat(Color("8a8d91")), Vector3(0, 0.1, 0))
	_bin_fill.scale.y = 0.01
	bin.add_child(_bin_fill)
	game.rig.add_child(bin)
	# Hot air out of the hose end: the dragon breathing
	steam = CPUParticles3D.new()
	steam.amount = 26
	steam.lifetime = 0.9
	steam.emitting = false
	steam.direction = Vector3(0, -1, 0)
	steam.spread = 35.0
	steam.initial_velocity_min = 1.2
	steam.initial_velocity_max = 2.4
	steam.gravity = Vector3(0, 2.4, 0)
	steam.scale_amount_min = 0.6
	steam.scale_amount_max = 1.6
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	sm.radial_segments = 6
	sm.rings = 3
	var stm := StandardMaterial3D.new()
	stm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stm.albedo_color = Color(1.0, 0.92, 0.82, 0.45)
	sm.material = stm
	steam.mesh = sm
	game.add_child(steam)
	# The settling tank by the pump, where the washout water runs back to:
	# a bright blue tank on a big blue ground ring (seen through trucks and
	# crowds, like a station spot), a hose from the release valve into it,
	# and a name over it that's scaled like a station's
	tank = Node3D.new()
	var blue := Color("3fa7ff")
	tank.add_child(F.box(Vector3(1.9, 1.2, 1.2), F.color_mat(Color("d9dde2")), Vector3(0, 0.6, 0)))
	tank.add_child(F.box(Vector3(1.94, 0.22, 1.24), F.color_mat(blue), Vector3(0, 0.95, 0)))
	_tank_water = F.box(Vector3(1.7, 0.06, 1.0), F.color_mat(Color("5aa6d6"), false, Color("2d6fa8")), Vector3(0, 0.75, 0))
	tank.add_child(_tank_water)
	_tank_ring = MeshInstance3D.new()
	var tr := TorusMesh.new()
	tr.inner_radius = 1.45
	tr.outer_radius = 1.75
	tr.rings = 32
	tr.ring_segments = 4
	_tank_ring.mesh = tr
	_tank_ring_mat = StandardMaterial3D.new()
	_tank_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tank_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tank_ring_mat.albedo_color = Color(blue, 0.7)
	_tank_ring.material_override = _tank_ring_mat
	_tank_ring.scale = Vector3(1, 0.1, 1)
	_tank_ring.position.y = 0.05
	_tank_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tank_ring.layers = 4
	var xr := MeshInstance3D.new()
	xr.mesh = tr
	var xm := StandardMaterial3D.new()
	xm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	xm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	xm.no_depth_test = true
	xm.render_priority = -1
	xm.albedo_color = Color(blue, 0.25)
	xr.material_override = xm
	xr.layers = 4
	xr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tank_ring.add_child(xr)
	tank.add_child(_tank_ring)
	# A bobbing arrow over it while the water's to be blown back
	_tank_arrow = F.label3d("▼", 72, blue)
	_tank_arrow.layers = 2
	_tank_arrow.position = Vector3(0, 2.9, 0)
	_tank_arrow.visible = false
	tank.add_child(_tank_arrow)
	# (out in front of the pump, on the street side, clear of its outriggers,
	# so it's never lost behind the pump or under its gauge reading)
	tank.position = game.GROUND_STATIONS["valve"]["pos"] + Vector3(-2.6, 0, 0.6)
	game.add_child(tank)
	tank_label = F.label3d("SETTLING TANK", 34, Color("6cc3ff"))
	tank_label.layers = 2
	tank_label.render_priority = 9
	tank_label.position = tank.position + Vector3(0, 1.9, 0)
	game.add_child(tank_label)
	# The hose from the release valve over the tank's lip
	var vp: Vector3 = game.GROUND_STATIONS["valve"]["pos"] + Vector3(0.3, 0.55, 0)
	var lip := tank.position + Vector3(-0.7, 1.25, 0.1)
	var hose := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.07
	hm.bottom_radius = 0.07
	hm.height = vp.distance_to(lip)
	hm.radial_segments = 8
	hose.mesh = hm
	hose.material_override = F.color_mat(blue)
	game.add_child(hose)
	hose.position = (vp + lip) * 0.5
	hose.look_at(lip + Vector3(0, 0.0001, 0), Vector3.UP)
	hose.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	water_fx = CPUParticles3D.new()
	water_fx.amount = 40
	water_fx.lifetime = 0.6
	water_fx.emitting = false
	water_fx.direction = Vector3(-0.95, 0.3, 0.2)
	water_fx.spread = 18.0
	water_fx.initial_velocity_min = 2.0
	water_fx.initial_velocity_max = 3.4
	water_fx.gravity = Vector3(0, -6, 0)
	var wm := SphereMesh.new()
	wm.radius = 0.06
	wm.height = 0.12
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color("6fb7ff")
	wm.material = wmat
	water_fx.mesh = wm
	game.add_child(water_fx)
	place()

## Puts the bin on this site's scaffold.
func place() -> void:
	bin.position = game.deck_pos("bin")

func start_pour() -> void:
	primed = false
	washed = false
	in_bin = 0.0
	_bin_fill.scale.y = 0.01
	_go("start")

func start_washout() -> void:
	if stage == "pour":
		_go("water_in")

func end_pour() -> void:
	stage = ""
	steam.emitting = false
	water_fx.emitting = false

func _go(s: String) -> void:
	stage = s
	step_t = 0.0
	hold = 0.0
	_nagged = false
	match s:
		"slurry_out":
			left = SLURRY
		"push":
			left = PUSH + WATER
		"pour":
			primed = true
			game.line.live = true
			game.line._prime_t = 9.0
			game.hud.toast("Concrete's on: pour away!", 1.8)
			game.sfx.hit("ding")
		"done":
			washed = true
			game.hud.toast("Line's clean. Water's back in the settling tank.", 2.0)
			game.sfx.hit("ding")

func _next() -> void:
	var order: Array = PRIME_ORDER if PRIME_ORDER.has(stage) else WASH_ORDER
	var i := order.find(stage)
	if i >= 0 and i + 1 < order.size():
		_go(order[i + 1])
	elif PRIME_ORDER.has(stage):
		_go("pour")
	else:
		_go("done")

## Which job this step is waiting on ("" if none, or no step).
func role() -> String:
	return STEPS[stage][1] if STEPS.has(stage) else ""

func busy() -> bool:
	return STEPS.has(stage)

## How full the bin step is, 0..1: the button's concrete fill.
func bin_progress() -> float:
	if not wants_bin():
		return -1.0
	return clampf(1.0 - left / (SLURRY if stage == "slurry_out" else PUSH + WATER), 0.0, 1.0)

## The hose has to go over the bin now.
func wants_bin() -> bool:
	return stage in ["slurry_out", "push"]

func bin_world() -> Vector3:
	return bin.global_position + Vector3(0, 0.9, 0)

func over_bin(at: Vector3) -> bool:
	var b := bin_world()
	return Vector2(at.x - b.x, at.z - b.z).length() < BIN_R

## What comes out of the hose now, for the colour of the stream.
func stream_color() -> Variant:
	match stage:
		"slurry_out":
			return Color("c2b49a")
		"push":
			return Color("6c6f73") if left > WATER else Color("6fb7ff")
		"concrete":
			return Color("6c6f73")
	return null

# ------------------------------------------------------------------ hands on

## The pump operator at the panel. True if a step here took the controls.
func panel(p, delta: float) -> bool:
	if role() != "pump" or STEPS[stage][2] != "panel":
		return false
	var verb: String = {"start": "start the pump", "slurry_in": "tip the slurry in", "water_in": "clean out, water in"}[stage]
	p.cue("action", verb, hold, true)
	p.gold(not p.bot)
	if p.action_held():
		hold = minf(1.0, hold + delta / HOLD_T)
		p.pose_arms(Vector3(-1.4, 0, -0.2), Vector3(-1.2 + 0.2 * sin(step_t * 12.0), 0, 0.2))
		if hold >= 1.0:
			_done_by(p, 10)
	else:
		hold = maxf(0.0, hold - delta)
	return true

## When the thing the pipe guy's waiting to call actually happens.
func signal_t() -> float:
	return SIGNAL_AIR if stage == "air" else SIGNAL_CONC

## The pipe guy on the radio: it's a timing call. Watch the end of the hose
## and call it the moment it happens (the hot air puffing out; the first grey
## concrete coming through): on the dot is a bonus. True only on the frame the
## call's made (so the rest of the job, like taking the hose, still works).
var _not_yet_at := -99.0

func radio(p) -> bool:
	if role() != "hose":
		return false
	var verb := "radio: dragon's breathing!" if stage == "air" else "radio: concrete's on!"
	var since := step_t - signal_t()
	if since < 0.0:
		p.say("watch the hose…")
		# (a person jumping the gun hears it once in a while; bots never)
		if p.action_pressed() and not p.bot and not p.covering and Time.get_ticks_msec() * 0.001 - _not_yet_at > 2.5:
			_not_yet_at = Time.get_ticks_msec() * 0.001
			p.bark("Not yet…", 0.8)
		return false
	p.cue("action", verb, -1.0, true)
	p.gold(not p.bot and since <= ON_THE_DOT)
	if p.action_pressed():
		p.bark("The dragon's breathing!" if stage == "air" else "Concrete's on!", 1.6)
		if since <= ON_THE_DOT:
			game.score.award(p, 15, "Called it on the dot")
			game.sfx.hit("chime")
			_done_by(p, 5)
		else:
			_done_by(p, 5)
		return true
	return false

## The end hose is showing the sign right now (for the stream and the puff).
func showing_sign() -> bool:
	if stage == "air":
		return step_t >= SIGNAL_AIR
	if stage == "concrete":
		return step_t >= SIGNAL_CONC and step_t < SIGNAL_CONC + 1.8
	return false

## The pump operator at the release valve.
func valve(p, delta: float) -> bool:
	if stage != "valve":
		return false
	p.cue("action", "open the release valve", hold, true)
	p.gold(not p.bot)
	if p.action_held():
		hold = minf(1.0, hold + delta / HOLD_T)
		p.pose_arms(Vector3(-1.0, 0, -0.3), Vector3(-1.0 + 0.4 * hold, 0, 0.3))
		water_fx.position = game.GROUND_STATIONS["valve"]["pos"] + Vector3(0.4, 0.6, 0)
		water_fx.emitting = true
		if hold >= 1.0:
			_done_by(p, 15)
	else:
		hold = maxf(0.0, hold - delta)
	return true

func _done_by(p, pts: int) -> void:
	if p != null:
		game.score.award(p, pts, "Start-up and washout")
		p.bounce()
	game.sfx.hit("tink")
	_next()

## The boom pumping during a bin step: everything goes in the bin if the hose
## is over it, and on the deck (where it shouldn't) if it isn't. Returns m³.
func pump(delta: float, want: bool, at: Vector3) -> float:
	if not wants_bin() or not want or left <= 0.0:
		return 0.0
	var q := minf(left, RATE * delta)
	left -= q
	if over_bin(at):
		in_bin += q
		_bin_fill.scale.y = clampf(in_bin / (SLURRY + PUSH + WATER), 0.01, 0.95)
	else:
		_spill_t += q
		if stage == "push" and left > WATER:
			game.pour.deposit(game._pour_local(at), q)
		if _spill_t > 0.04:
			_spill_t = 0.0
			game.score.award(game._boom_operator(), -4, "Missed the bin")
			game.pop("not on the slab!", at + Vector3(0, 0.6, 0), Color("ff6b6b"))
	if left <= 0.0:
		game.score.award(game._boom_operator(), 15, "Start-up and washout")
		_next()
	return q

# ------------------------------------------------------------------ ticking over

func update(delta: float) -> void:
	steam.emitting = stage == "air" and step_t >= SIGNAL_AIR
	if steam.emitting:
		steam.global_position = game.discharge()
	if stage != "valve":
		water_fx.emitting = false
	# The tank calls out while the washout water's to be blown back into it
	_tank_t += delta
	var call := stage == "valve"
	_tank_arrow.visible = call
	_tank_arrow.position.y = 2.9 + 0.25 * sin(_tank_t * 5.0)
	_tank_ring_mat.albedo_color.a = (0.55 + 0.4 * sin(_tank_t * 6.0)) if call else 0.7
	# (the water in it rises as the washout comes back)
	var lvl := 1.0 if washed else (hold if call else 0.0)
	_tank_water.position.y = 0.75 + 0.35 * lvl
	if not busy():
		return
	step_t += delta
	if stage == "slurry_go" and step_t >= TRAVEL_T:
		_next()
		return
	# A bot pipe guy radios it in a moment; a person who misses it doesn't
	# hold anyone up: after a few seconds the crew carries on without the call
	if role() == "hose":
		var h = game.crew.crew.get("hose")
		var t0 := signal_t()
		var bot_like: bool = h == null or h.bot or h.covering
		if bot_like and step_t > t0 + RADIO_AUTO_T * 0.5:
			if h != null and h.bot:
				h.bark("The dragon's breathing!" if stage == "air" else "Concrete's on!", 1.6)
			_next()
			return
		if not bot_like and step_t > t0 + PERSON_AUTO:
			game.hud.toast("The boom operator saw it anyway: carry on", 1.6)
			_next()
			return
	var who = game.crew.crew.get(role()) if role() != "" else null
	if step_t > NAG_T and not _nagged and who != null and not who.bot:
		_nagged = true
		game.hud.toast("%s: %s" % [UI.ROLE_NAME.get(role(), "").to_upper(), STEPS[stage][0].to_lower()], 2.6)
	if step_t > AUTO_T:
		game.hud.toast("The crew gets it done: %s" % STEPS[stage][0].to_lower(), 2.0)
		game.score.award(null, -15, "Start-up and washout held up")
		if wants_bin():
			in_bin += left
			left = 0.0
			_bin_fill.scale.y = 0.9
		_next()

## For the HUD: [title, what, the job's role, progress 0..1] or [] when quiet.
func ticket() -> Array:
	if not busy():
		return []
	var all: Array = PRIME_ORDER if PRIME_ORDER.has(stage) else WASH_ORDER
	var head := "Start-up" if PRIME_ORDER.has(stage) else "Washout"
	# (count only the steps someone does: the slurry on its way up is part
	# of getting it into the bin)
	var order: Array = all.filter(func(s): return STEPS[s][1] != "")
	var n := order.find("slurry_out" if stage == "slurry_go" else stage) + 1
	var frac := hold
	if wants_bin():
		frac = 1.0 - left / (SLURRY if stage == "slurry_out" else PUSH + WATER)
	elif stage == "slurry_go":
		frac = step_t / TRAVEL_T
	return ["%s %d of %d" % [head, n, order.size()], STEPS[stage][0], STEPS[stage][1], frac]

## For the hand signs: [key, world position, level, role, label] or [].
func job() -> Array:
	if not busy() or role() == "":
		return []
	var where: String = STEPS[stage][2]
	var pos := Vector3.ZERO
	match where:
		"panel":
			pos = game.GROUND_STATIONS["panel"]["pos"] + Vector3(0, 2.0, 0)
		"valve":
			pos = game.GROUND_STATIONS["valve"]["pos"] + Vector3(0, 2.0, 0)
		"bin":
			pos = bin_world() + Vector3(0, 1.2, 0)
		"hose":
			pos = game.discharge() + Vector3(0, 1.6, 0)
	var lvl := 2 if step_t > NAG_T else 1
	return ["ops_" + stage, pos, lvl, role(), STEPS[stage][3]]

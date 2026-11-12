## The start and the end of every pour, the way a pump crew runs them.
##
## START-UP (priming), before any concrete goes in the slab:
##   1. START THE PUMP     pump operator, hold A at the PUMP PANEL
##   2. DRAGON'S BREATHING the pump pushes the air out of the line ahead of it:
##                         hot air comes out the hose end. The hose hand, on the
##                         hose, radios it down (A)
##   3. SLURRY IN          pump operator tips the bag of slurry (cement, sand and
##                         water) into the hopper (hold A at the panel). It
##                         coats the inside of the line so the concrete slides
##   4. SLURRY OUT         the slurry reaches the hose. It mustn't go in the
##                         slab: the boom (and the hose hand) put the hose over
##                         the BIN and pump it all in (hold A over the bin)
##   5. CONCRETE'S ON      the first concrete comes through: the hose hand radios
##                         "concrete's on" (A) and the pour begins
##
## WASHOUT, once the slab's full (SCP's water washout: water pumped in behind
## the concrete pushes it out, the last of it goes in a bin, then the water's
## blown back to the pump and into the settling tanks to be used again,
## https://scpaus.com.au/water-washout-clean-out-system/):
##   1. WATER IN           pump operator cleans the hopper and fills it with
##                         water (hold A at the panel)
##   2. SPONGE BALL        pump operator loads the sponge ball (hold A at the
##                         panel): it rides between the concrete and the water
##                         and wipes the line clean on its way up
##   3. INTO THE BIN       the water pushes the last of the concrete out: the
##                         boom puts the hose over the BIN and pumps it out,
##                         concrete then water, into the bin
##   4. CATCH THE BALL     the ball pops out of the end hose: the hose hand
##                         catches it (A the moment it pops) or it flies off
##                         onto the slab
##   5. BLOW IT BACK       pump operator opens the RELEASE VALVE at the pump (hold
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
const RADIO_AUTO_T := 4.0    # s a bot hose hand (or nobody) takes to radio
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
	"ball_in": ["Sponge ball into the line", "pump", "panel", "SPONGE BALL"],
	"push": ["The last of it into the bin", "boom", "bin", "BIN"],
	"catch": ["Catch the sponge ball", "hose", "hose", "CATCH THE BALL"],
	"valve": ["Blow the water back", "pump", "valve", "BLOW THE WATER BACK"],
}
const PRIME_ORDER := ["start", "air", "slurry_in", "slurry_go", "slurry_out", "concrete"]
const WASH_ORDER := ["water_in", "ball_in", "push", "catch", "valve"]
const BALL_T := 1.6          # s after the bin step before the ball pops out of the hose
const CATCH_WIN := 1.0       # s to catch it once it's out
const CATCH_PAY := 12

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
var _tank_t := 0.0
var _spill_t := 0.0
var ball: Node3D             # the sponge ball, when it's out of the line
var ball_caught := false     # caught clean this pour
var _ball_from := Vector3.ZERO
var _ball_to := Vector3.ZERO
var _ball_t := -1.0          # >= 0 while it's flying
var _ball_who = null         # caught by (it flies to their hands)

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
	_build_pit()
	water_fx = CPUParticles3D.new()
	water_fx.amount = 40
	water_fx.lifetime = 0.6
	water_fx.emitting = false
	water_fx.direction = Vector3(-0.5, 0.25, 0.8)
	water_fx.spread = 14.0
	water_fx.initial_velocity_min = 1.2
	water_fx.initial_velocity_max = 2.2
	water_fx.position = PIT + Vector3(-0.1, 0.12, -PIT_SIZE.y * 0.5 + 0.05)
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

# ------------------------------------------------------------------ the grated trench and the tank pit

# The washout runs under the yard: a steel grate set flush in the hardstand
# under the pump, its hopper and the trucks' rears back to their rear wheels
# (in the pump's own frame, line.gd pf: along it, across it), a grated trench
# from there to the fence, and the settling tank sat in a pit there, parallel
# with the fence, under a lift-off grate lid. Everyone walks straight over
# all of it.
const PAD_PUMP := Rect2(-2.2, -1.1, 4.6, 2.6)     # under the pump: along -2.2..2.4, across -1.1..1.5
const PAD_BAY := Rect2(2.4, -3.3, 4.5, 6.6)       # under the hopper and the truck rears
const TRENCH := Rect2(0.0, 1.5, 0.7, 6.7)         # from the pump's street side out to the pit
const PIT := Vector3(11.9, 0, 10.85)
const PIT_SIZE := Vector2(3.2, 1.5)
const GRATE_Y := 0.068
# How far a point 1 m down in the pit shows towards the camera, on the flat
# (the game's camera: yaw 0.55, pitch 0.62)
const PIT_LEAN := Vector2(0.73, 1.19)
var _tank_in := Rect2()     # the tank's open top, as painted (pit's own x, z)
var _tank_lvl := 0.0

var _pad_water: Array[MeshInstance3D] = []
var _trench_water: MeshInstance3D
var _ripples: Array[MeshInstance3D] = []
var _flow := 0.0            # how far down the trench the water's got, 0..1
var _flow_t := 0.0

## Whether this ground point is on a grate (for the footsteps).
func on_grate(p: Vector3) -> bool:
	var q: Vector2 = game.LineScript.in_pf(p)
	if PAD_PUMP.has_point(q) or PAD_BAY.has_point(q) or TRENCH.has_point(q):
		return true
	return absf(p.x - PIT.x) < PIT_SIZE.x * 0.5 and absf(p.z - PIT.z) < PIT_SIZE.y * 0.5

## A grate over a rectangle of `parent`'s ground (x0..x1, z0..z1): the dark
## under it, bearing bars across the short way and a frame round it.
func _grate(parent: Node3D, r: Rect2, y: float, framed := true) -> void:
	var c := r.get_center()
	var dark := F.color_mat(Color("23272e"))
	parent.add_child(F.box(Vector3(r.size.x, 0.008, r.size.y), dark, Vector3(c.x, y, c.y), false))
	var steel := F.color_mat(Color("8e98a6"))
	var along_x := r.size.x >= r.size.y    # (the bars lie across the long way)
	var n := int((r.size.x if along_x else r.size.y) / 0.17)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(0.055, 0.02, r.size.y) if along_x else Vector3(r.size.x, 0.02, 0.055)
	bm.material = steel
	mm.mesh = bm
	mm.instance_count = n
	for i in n:
		var t := (i + 0.5) / float(n)
		var at := Vector3(r.position.x + r.size.x * t, y + 0.02, c.y)
		if not along_x:
			at = Vector3(c.x, y + 0.02, r.position.y + r.size.y * t)
		mm.set_instance_transform(i, Transform3D(Basis(), at))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	# (two flats the other way tie the bars together)
	for k in [0.3, 0.7]:
		var tsize := Vector3(r.size.x, 0.012, 0.04)
		var tat := Vector3(c.x, y + 0.034, r.position.y + r.size.y * k)
		if not along_x:
			tsize = Vector3(0.04, 0.012, r.size.y)
			tat = Vector3(r.position.x + r.size.x * k, y + 0.034, c.y)
		parent.add_child(F.box(tsize, steel, tat, false))
	if framed:
		var fr := F.color_mat(Color("56606e"))
		for sx in [0.0, 1.0]:
			parent.add_child(F.box(Vector3(0.07, 0.03, r.size.y + 0.07), fr, Vector3(r.position.x + r.size.x * sx, y + 0.012, c.y), false))
			parent.add_child(F.box(Vector3(r.size.x + 0.07, 0.03, 0.07), fr, Vector3(c.x, y + 0.012, r.position.y + r.size.y * sx), false))

func _water_plane(parent: Node3D, r: Rect2, y: float, col: Color) -> MeshInstance3D:
	var c := r.get_center()
	var w := F.box(Vector3(r.size.x - 0.1, 0.006, r.size.y - 0.1), F.color_mat(col, false, col * 0.35), Vector3(c.x, y, c.y), false)
	w.visible = false
	parent.add_child(w)
	return w

func _build_pit() -> void:
	var blue := Color("3fa7ff")
	# The grated pad and trench, laid out in the pump's frame
	var pad := Node3D.new()
	pad.position = game.LineScript.PUMP_POS
	pad.rotation.y = game.LineScript.PUMP_YAW
	game.add_child(pad)
	for r in [PAD_PUMP, PAD_BAY, TRENCH]:
		_grate(pad, r, GRATE_Y)
	for r in [PAD_PUMP, PAD_BAY]:
		_pad_water.append(_water_plane(pad, r, GRATE_Y + 0.008, Color("5d8fb0")))
	# (the water in the trench runs from the pump end out to the pit)
	_trench_water = _water_plane(pad, TRENCH, GRATE_Y + 0.008, blue)
	for i in 7:
		var rp := F.box(Vector3(TRENCH.size.x - 0.16, 0.006, 0.22), F.color_mat(Color("cfeaff"), false, Color("6fb7ff")), Vector3.ZERO, false)
		rp.visible = false
		pad.add_child(rp)
		_ripples.append(rp)
	# The pit by the fence, parallel with it: a concrete rim, the tank down
	# in it, and a grate lid in three lift-off panels, one propped open so
	# the tank shows
	tank = Node3D.new()
	tank.position = PIT
	game.add_child(tank)
	var hx := PIT_SIZE.x * 0.5
	var hz := PIT_SIZE.y * 0.5
	var conc := F.color_mat(Color("c8c4ba"))
	for sx in [-1.0, 1.0]:
		tank.add_child(F.box(Vector3(0.16, 0.035, PIT_SIZE.y + 0.32), conc, Vector3(sx * (hx + 0.08), GRATE_Y + 0.005, 0), false))
		tank.add_child(F.box(Vector3(PIT_SIZE.x + 0.32, 0.035, 0.16), conc, Vector3(0, GRATE_Y + 0.005, sx * (hz + 0.08)), false))
	# The pit's inside is painted on the flat the way the game's camera sees
	# down into it (a point `d` m down shows d * PIT_LEAN nearer the camera):
	# the far wall and the west wall, the tank's top 0.3 m down, the dark
	# inside the tank and the water in it, which comes into view from the
	# near side as it rises
	var flat := func(x0: float, x1: float, z0: float, z1: float, lift: float, col: Color) -> MeshInstance3D:
		var m := F.box(Vector3(x1 - x0, 0.004, z1 - z0), F.color_mat(col), Vector3((x0 + x1) * 0.5, GRATE_Y + lift, (z0 + z1) * 0.5), false)
		tank.add_child(m)
		return m
	var top := PIT_LEAN * 0.3
	flat.call(-hx, hx, -hz, hz, 0.0, Color("8d9093"))                      # far wall
	flat.call(-hx, -hx + 0.12 + top.x, -hz, hz, 0.003, Color("6c6f73"))    # west wall, in shade
	flat.call(-hx, hx, -hz + 0.1 + top.y, -hz + 0.14 + top.y, 0.003, Color("3a3f45"))   # the gap behind the tank
	var tx0 := -hx + 0.12 + top.x
	var tz0 := -hz + 0.12 + top.y
	flat.call(tx0, hx, tz0, hz, 0.006, Color("d9dde2"))                    # tank top
	flat.call(tx0, hx, tz0, tz0 + 0.07, 0.009, blue)
	_tank_in = Rect2(tx0 + 0.1, tz0 + 0.12, hx - tx0 - 0.1, hz - tz0 - 0.12)
	flat.call(_tank_in.position.x, hx, _tank_in.position.y, hz, 0.009, Color("2b3038"))   # inside the tank
	_tank_water = F.box(Vector3.ONE, F.color_mat(Color("5aa6d6"), false, Color("2d6fa8")), Vector3.ZERO, false)
	tank.add_child(_tank_water)
	var pw := PIT_SIZE.x / 3.0
	for i in 3:
		var lid := Node3D.new()
		tank.add_child(lid)
		var r := Rect2(-pw * 0.5 + 0.02, 0.0, pw - 0.04, PIT_SIZE.y)
		if i == 0:
			# Propped open: hinged on its far edge, with a stay under it
			lid.position = Vector3(-hx + pw * 0.5, GRATE_Y + 0.03, -hz)
			lid.rotation.x = -0.95
			tank.add_child(F.beam(Vector3(-hx + pw * 0.5, GRATE_Y, hz * 0.2), Vector3(-hx + pw * 0.5, GRATE_Y + 0.75, -hz + 0.55), 0.04, F.color_mat(Color("56606e"))))
			_grate_panel(lid, r)
		else:
			lid.position = Vector3(-hx + pw * (i + 0.5), GRATE_Y + 0.03, -hz)
			_grate_panel(lid, r)
	# The blue ring round it, seen through trucks and crowds like a station spot
	_tank_ring = MeshInstance3D.new()
	var tr := TorusMesh.new()
	tr.inner_radius = 1.45
	tr.outer_radius = 1.7
	tr.rings = 32
	tr.ring_segments = 4
	_tank_ring.mesh = tr
	_tank_ring_mat = StandardMaterial3D.new()
	_tank_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tank_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tank_ring_mat.albedo_color = Color(blue, 0.0)
	_tank_ring.material_override = _tank_ring_mat
	_tank_ring.scale = Vector3(1.35, 0.06, 0.8)
	_tank_ring.position.y = 0.12
	_tank_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tank_ring.layers = 4
	tank.add_child(_tank_ring)
	tank_label = F.label3d("SETTLING TANK", 34, Color("6cc3ff"))
	tank_label.layers = 2
	tank_label.render_priority = 9
	tank_label.position = PIT + Vector3(0.5, 1.5, 0)
	game.add_child(tank_label)

## One lift-off lid panel: bars and a frame, with no dark under it (the tank
## shows through).
func _grate_panel(parent: Node3D, r: Rect2) -> void:
	var steel := F.color_mat(Color("8e98a6"))
	var n := int(r.size.y / 0.17)
	for i in n:
		parent.add_child(F.box(Vector3(r.size.x, 0.02, 0.055), steel, Vector3(r.get_center().x, 0, r.position.y + r.size.y * (i + 0.5) / float(n)), false))
	var fr := F.color_mat(Color("56606e"))
	for sx in [0.0, 1.0]:
		parent.add_child(F.box(Vector3(0.06, 0.03, r.size.y), fr, Vector3(r.position.x + r.size.x * sx, 0, r.get_center().y), false))
		parent.add_child(F.box(Vector3(r.size.x, 0.03, 0.06), fr, Vector3(r.get_center().x, 0, r.position.y + r.size.y * sx), false))
	# (a lifting handle each end)
	for k in [0.25, 0.75]:
		parent.add_child(F.box(Vector3(0.22, 0.03, 0.05), F.color_mat(Color("ffc72c")), Vector3(r.get_center().x, 0.02, r.position.y + r.size.y * k), false))

## The washout water, there to see: it lies under the pump's grate from the
## moment the hopper's cleaned out, and when the pump operator blows the line
## back it runs down the trench and falls into the tank, which fills.
func _update_water(delta: float) -> void:
	var washing: bool = stage in WASH_ORDER or washed
	for w in _pad_water:
		w.visible = washing
	var call := stage == "valve"
	var want := 1.0 if washed else (clampf(hold * 1.6, 0.0, 1.0) if call else 0.0)
	_flow = move_toward(_flow, want, delta * (0.9 if want > _flow else 0.25))
	_trench_water.visible = _flow > 0.01
	if _trench_water.visible:
		var ln := (TRENCH.size.y - 0.1) * _flow
		_trench_water.scale.z = _flow
		_trench_water.position.z = TRENCH.position.y + 0.05 + ln * 0.5
	var running: bool = call and hold > 0.02 and not washed
	_flow_t += delta
	for i in _ripples.size():
		var rp := _ripples[i]
		var u := fmod(_flow_t * 0.45 + float(i) / _ripples.size(), 1.0)
		rp.visible = running and u < _flow
		rp.position = Vector3(TRENCH.get_center().x, GRATE_Y + 0.013, TRENCH.position.y + 0.15 + (TRENCH.size.y - 0.3) * u)
	water_fx.emitting = running and _flow > 0.9
	# (the water in the tank: the higher it stands, the more of it shows
	# past the tank's near lip)
	var lvl := 1.0 if washed else (clampf((hold - 0.4) * 1.7, 0.0, 1.0) if call else 0.0)
	_tank_lvl = move_toward(_tank_lvl, lvl, delta * 0.8)
	var down := lerpf(0.62, 0.12, _tank_lvl)
	var wx0 := _tank_in.position.x + PIT_LEAN.x * down
	var wz0 := _tank_in.position.y + PIT_LEAN.y * down
	var wx1 := PIT_SIZE.x * 0.5
	var wz1 := PIT_SIZE.y * 0.5
	_tank_water.visible = wz1 - wz0 > 0.03
	_tank_water.scale = Vector3(maxf(0.01, wx1 - wx0), 0.004, maxf(0.01, wz1 - wz0))
	_tank_water.position = Vector3((wx0 + wx1) * 0.5, GRATE_Y + 0.012, (wz0 + wz1) * 0.5)
	_tank_ring_mat.albedo_color.a = (0.5 + 0.35 * sin(_tank_t * 6.0)) if call else 0.0

## Puts the bin on this site's scaffold.
func place() -> void:
	bin.position = game.deck_pos("bin")

func start_pour() -> void:
	primed = false
	washed = false
	ball_caught = false
	_ball_t = -1.0
	if ball:
		ball.visible = false
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
	var verb: String = {"start": "start the pump", "slurry_in": "tip the slurry in", "water_in": "clean out, water in", "ball_in": "load the sponge ball"}[stage]
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

## When the thing the hose hand's waiting to call actually happens.
func signal_t() -> float:
	return SIGNAL_AIR if stage == "air" else (BALL_T if stage == "catch" else SIGNAL_CONC)

## The hose hand on the radio: it's a timing call. Watch the end of the hose
## and call it the moment it happens (the hot air puffing out; the first grey
## concrete coming through): on the dot is a bonus. True only on the frame the
## call's made (so the rest of the job, like taking the hose, still works).
var _not_yet_at := -99.0

func radio(p) -> bool:
	if role() != "hose":
		return false
	if stage == "catch":
		return _catch(p)
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

## The sponge ball: it pops out of the end hose BALL_T into the step, and the
## hose hand has CATCH_WIN to grab it. True on the frame they do.
func _catch(p) -> bool:
	var since := step_t - BALL_T
	if since < 0.0:
		p.say("ball's coming…")
		p.cue("action", "catch the ball", clampf(step_t / BALL_T, 0.0, 1.0), false)
		return false
	p.cue("action", "CATCH IT!", -1.0, true)
	p.gold(not p.bot)
	if p.action_pressed():
		ball_caught = true
		_ball_fly(game.discharge(), p.global_position + Vector3(0, 1.1, 0), p)
		p.bark("Got it!", 1.2)
		game.score.award(p, CATCH_PAY, "Caught the sponge ball")
		var op = game.crew.crew.get("pump") if game.crew else null
		if op != null and op != p:
			game.score.award(op, CATCH_PAY, "Caught the sponge ball")
		game.sfx.hit("chime")
		p.bounce()
		_next()
		return true
	return false

## The ball out of the hose, flying to whoever caught it or off onto the slab.
func _ball_fly(from: Vector3, to: Vector3, who) -> void:
	if ball == null:
		ball = F.prop("SpongeBall")
		ball.scale = Vector3.ONE * 2.0   # (it reads from the couch)
		game.add_child(ball)
	ball.visible = true
	_ball_from = from
	_ball_to = to
	_ball_t = 0.0
	_ball_who = who

func _ball_update(delta: float) -> void:
	if ball == null or _ball_t < 0.0:
		return
	_ball_t += delta
	var u := clampf(_ball_t / 0.55, 0.0, 1.0)
	ball.global_position = _ball_from.lerp(_ball_to, u) + Vector3(0, 1.2 * sin(u * PI), 0)
	ball.rotation.x += delta * 14.0
	if u >= 1.0:
		_ball_t = -1.0
		if _ball_who != null:
			ball.visible = false   # (in their hands, and into the bucket)

## The end hose is showing the sign right now (for the stream and the puff).
func showing_sign() -> bool:
	if stage == "air":
		return step_t >= SIGNAL_AIR
	if stage == "concrete":
		return step_t >= SIGNAL_CONC and step_t < SIGNAL_CONC + 1.8
	if stage == "catch":
		return step_t >= BALL_T and step_t < BALL_T + CATCH_WIN
	return false

## The pump operator at the release valve.
func valve(p, delta: float) -> bool:
	if stage != "valve":
		return false
	p.cue("action", "blow the water back to the tank", hold, true)
	p.gold(not p.bot)
	p.face(game.line.PUMP_POS)
	if p.action_held():
		hold = minf(1.0, hold + delta / HOLD_T)
		p.pose_arms(Vector3(-1.0, 0, -0.3), Vector3(-1.0 + 0.4 * hold, 0, 0.3))
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
	_tank_t += delta
	_update_water(delta)
	_ball_update(delta)
	if not busy():
		return
	step_t += delta
	# The sponge ball: a bot (or nobody) on the hose catches it; a person who
	# misses it watches it fly off onto the slab
	if stage == "catch":
		var hh = game.crew.crew.get("hose") if game.crew else null
		var bot_hose: bool = hh == null or hh.bot or hh.covering
		if bot_hose and step_t > BALL_T + 0.3:
			ball_caught = hh != null
			_ball_fly(game.discharge(), (hh.global_position if hh != null else game.discharge()) + Vector3(0, 1.1, 0), hh)
			if hh != null:
				hh.bark("Got it!", 1.2)
			_next()
		elif not bot_hose and step_t > BALL_T + CATCH_WIN:
			var at: Vector3 = game.discharge()
			var fwd := Vector3(at.x - game.tip_pos.x, 0, at.z - game.tip_pos.z)
			fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3(1, 0, 0)
			_ball_fly(at, Vector3(at.x, game.work_y + game.pour.SLAB + 0.1, at.z) + fwd * 3.5, null)
			game.pop("Sponge ball's on the slab!", at + Vector3(0, 1.2, 0), Color("ffc23d"))
			game.score.award(hh, -6, "Missed the sponge ball")
			_next()
		return
	if stage == "slurry_go" and step_t >= TRAVEL_T:
		_next()
		return
	# A bot hose hand radios it in a moment; a person who misses it doesn't
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
			pos = game.GROUND_STATIONS["panel"]["pos"] + Vector3(0, 2.0, 0)
		"bin":
			pos = bin_world() + Vector3(0, 1.2, 0)
		"hose":
			pos = game.discharge() + Vector3(0, 1.6, 0)
	var lvl := 2 if step_t > NAG_T else 1
	return ["ops_" + stage, pos, lvl, role(), STEPS[stage][3]]

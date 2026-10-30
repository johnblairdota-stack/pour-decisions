## The slump test at the truck bay, done by hand in a close-up, the way it's
## done on an Australian site (AS 1012.3.1, accepted against AS 1379):
##
##   1. SAMPLE    press A: you walk to the truck's chute with the green
##                tray, fill it off the running load and carry it back
##   2. FILL+ROD  one hold of A does the lot: the cone (300 mm tall, 200 mm
##                base, 100 mm top) in three layers of about equal volume,
##                each rodded 25 times with the 16 mm rod to push the air out,
##                then struck off by rolling the rod across. It stops itself
##   3. LIFT      the cone straight up, steady, in about 3 to 5 seconds (hold A:
##                stop part way for more than a moment and it jerks, the
##                concrete shears, and the test has to be done again)
##   4. MEASURE   press A: the tape runs down from the rod across the upturned
##                cone to the centre of the slumped top, and it's read off
##
## Four presses a load, every load on the tower. A guide over the close-up
## lists the four steps, ticks them off and says what each is for.
##
## Then the call: use it, add the water the plant held back (then mix and test
## again), or send it back. The docket's on the truck: a wrong mix goes back
## whatever the slump reads.
##
## Keeping pace: once the sample's in the barrow the driver keeps the chute
## running into the hopper on trust (up to line.TRUST_M3), so the pour doesn't
## stop for the test. A quick, clean test means less concrete goes in before
## the call; a bad load caught late has already put some in.
extends Node

const F := preload("res://scripts/factory.gd")

const CONE_H := 0.3          # m, the cone (the rig's scaled up, like every chibi tool, so it reads)
const S := 2.6               # the rig's scale in the world
const R_BASE := 0.1          # half of the 200 mm base
const R_TOP := 0.05          # half of the 100 mm top
const MARKS := [0.07, 0.16, 0.315]   # fill heights for the three layers (the last heaped)
const MARK_TOL := 0.02      # m either side of a mark that counts as on it
const FILL_RATE := 0.3      # m a second while A's held
const RODS := 25
const ROD_RATE := 11.0      # strokes a second while A's held (it stops itself on 25)
const FILLROD_T := 3.2      # s: the one hold that fills, rods and strikes off all three layers
const FILL_SHARE := 0.35    # of each layer's share of that hold: the filling (the rest is rodding)
const STRIKE_FROM := 0.92   # the last bit of the hold strikes off the top
const SCOOP_T := 1.0        # s at the chute filling the tray
const BARROW_AT := Vector3(0.12, 0, -0.38)   # where the tray sits by the plate
const LIFT_T := 2.2          # s: steady, straight up (3 to 5 s on site; the game runs quick)
const LIFT_PAUSE := 0.6      # s a lift can stop part way before it jerks and shears
const TAPE_RATE := 0.12      # m a second the tape runs down while A's held
const TEST_X := -0.17        # where the cone stands on the plate (local)
const FLIP_X := 0.25         # where the upturned cone goes

var game
var line
var root: Node3D
var _cone: Node3D
var _fill: MeshInstance3D
var _fill_mesh: CylinderMesh
var _rod: Node3D
var _tape: MeshInstance3D
var _barrow: Node3D
var _scoop: Node3D
var _reading: Label3D
var _mark: MeshInstance3D
var _mark_mesh: TorusMesh
var _water: CPUParticles3D    # water pouring over the cone when the call's "add water"
var _t := 0.0

func setup(owner_line, at: Vector3) -> void:
	line = owner_line
	game = line.game
	root = Node3D.new()
	root.position = at
	root.scale = Vector3.ONE * S
	root.visible = false
	line.add_child(root)
	var steel := F.mat("steel")
	# Base plate (damp steel), a little longer to take the upturned cone
	var plate := F.prop("SlumpPlate")
	plate.position = Vector3(0.04, 0.015, 0)
	root.add_child(plate)
	# The cone: open both ends, foot rests either side
	_cone = Node3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = R_TOP + 0.004
	cm.bottom_radius = R_BASE + 0.004
	cm.height = CONE_H
	cm.cap_top = false
	cm.cap_bottom = false
	var shell := MeshInstance3D.new()
	shell.mesh = cm
	# (see-through, so the layers, the rod and the mark read inside it)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.78, 0.82, 0.86, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.metallic = 0.6
	glass.roughness = 0.35
	shell.material_override = glass
	# The rim at the top and the foot of the cone, solid steel
	var rim := MeshInstance3D.new()
	var rt := TorusMesh.new()
	rt.inner_radius = R_TOP
	rt.outer_radius = R_TOP + 0.01
	rim.mesh = rt
	rim.material_override = steel
	rim.position.y = CONE_H
	_cone.add_child(rim)
	var foot := MeshInstance3D.new()
	var ft := TorusMesh.new()
	ft.inner_radius = R_BASE
	ft.outer_radius = R_BASE + 0.012
	foot.mesh = ft
	foot.material_override = steel
	_cone.add_child(foot)
	shell.position.y = CONE_H * 0.5
	_cone.add_child(shell)
	for s in [-1.0, 1.0]:
		_cone.add_child(F.box(Vector3(0.05, 0.008, 0.04), steel, Vector3(s * (R_BASE + 0.03), 0.004, 0)))
		_cone.add_child(F.box(Vector3(0.012, 0.05, 0.03), steel, Vector3(s * (R_TOP + 0.03), CONE_H * 0.62, 0)))
	root.add_child(_cone)
	# The concrete in (and then out of) the cone
	_fill_mesh = CylinderMesh.new()
	_fill_mesh.radial_segments = 20
	_fill = MeshInstance3D.new()
	_fill.mesh = _fill_mesh
	_fill.material_override = F.color_mat(Color("767b82"))
	root.add_child(_fill)
	# The mark the layer's filled to (for the fill step only)
	_mark = MeshInstance3D.new()
	_mark_mesh = TorusMesh.new()
	_mark.mesh = _mark_mesh
	_mark.material_override = F.color_mat(Color("ffc72c"))
	root.add_child(_mark)
	# The 16 mm rod, 600 mm long
	_rod = Node3D.new()
	_rod.add_child(F.cylinder(0.008, 0.6, steel, Vector3(0, 0.3, 0), 6))
	root.add_child(_rod)
	# Tape measure from the rod down
	_tape = F.box(Vector3(0.03, 1.0, 0.006), F.color_mat(Color("ffc72c")), Vector3.ZERO, false)
	root.add_child(_tape)
	# The sample in a barrow, and a scoop
	_barrow = Node3D.new()
	# (child 1 is the concrete in it: shown when the tray's full)
	_barrow.add_child(F.prop("SlumpTray"))
	_barrow.add_child(F.prop("SlumpTrayMix"))
	_barrow.position = BARROW_AT
	root.add_child(_barrow)
	_scoop = F.prop("SlumpScoop")
	root.add_child(_scoop)
	# The reading, big, in the close-up
	_reading = F.label3d("", 22, Color("ffc72c"))
	_reading.layers = 1 << 10   # (main.gd CLOSE_ONLY: in the close-ups only)
	_reading.pixel_size = 0.004
	_reading.position = Vector3(TEST_X, 0.62, 0)
	_reading.outline_size = 10
	root.add_child(_reading)
	# Water, for a stiff reading: a stream of drops over the cone
	_water = CPUParticles3D.new()
	_water.amount = 40
	_water.lifetime = 0.7
	_water.emitting = false
	_water.direction = Vector3(0, -1, 0)
	_water.spread = 12.0
	_water.initial_velocity_min = 0.2
	_water.initial_velocity_max = 0.5
	_water.gravity = Vector3(0, -1.6, 0)
	_water.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_water.emission_sphere_radius = 0.06
	var drop := SphereMesh.new()
	drop.radius = 0.012
	drop.height = 0.03
	drop.radial_segments = 6
	drop.rings = 3
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.35, 0.7, 1.0, 0.85)
	wm.emission_enabled = true
	wm.emission = Color(0.25, 0.6, 1.0)
	wm.emission_energy_multiplier = 1.4
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = wm
	_water.mesh = drop
	_water.position = Vector3(TEST_X, 0.72, 0)
	root.add_child(_water)

func _st(t: Dictionary) -> Dictionary:
	if not t.has("sl"):
		t["sl"] = {"step": "sample", "draw": "sample", "layer": 0, "level": 0.0, "rods": 0.0, "u": 0.0, "lift": 0.0, "tape": 0.0, "shear": false, "slips": 0}
	return t["sl"]

## Start again (after a shear, or after water's been added and mixed in).
func restart(t: Dictionary, keep_sample := false) -> void:
	t.erase("sl")
	if keep_sample:
		_st(t)["step"] = "fill"
		_st(t)["draw"] = "fill"
		_st(t)["armed"] = false

func step_of(t) -> String:
	if t == null:
		return ""
	return String(_st(t)["step"])

## The actual slump of this sample (shear: worse and lopsided).
func _true(t: Dictionary) -> float:
	return float(t["slump"])

## Height of the slumped top's centre above the plate, m.
func _top_y(t: Dictionary) -> float:
	return 0.03 + CONE_H - _true(t) / 1000.0

## One frame of the test. Returns true when the measurement's been taken.
## Four presses: A to go and get a sample (you walk to the chute with the
## tray, fill it and carry it back on your own), one hold of A to fill and rod
## all three layers and strike off (it stops itself), a held lift (steady:
## stop part way and it shears), and A to run the tape down and read it.
func work(p, t: Dictionary, delta: float) -> bool:
	var st := _st(t)
	var auto: bool = p.bot or p.covering
	var held: bool = p.action_held() if not auto else _bot_hold(st)
	var pressed: bool = p.action_pressed() if not auto else _bot_press(t, st)
	if st["step"] == "fetch":
		return false   # (walking to the chute and back: fetch_tick)
	# Stand at the plate, behind the cone, so the close-up has you in it
	var stand := _stand()
	p.position.x = move_toward(p.position.x, stand.x, 3.0 * delta)
	p.position.z = move_toward(p.position.z, stand.z, 3.0 * delta)
	p.face(root.global_position + Vector3(TEST_X, 0, 0) * S)
	var done := false
	match st["step"]:
		"sample":
			p.cue("action", "get a sample", -1.0, true)
			p.gold(not p.bot)
			if pressed:
				st["step"] = "fetch"
				st["leg"] = "go"
				st["u"] = 0.0
				st["who"] = p
				p.bounce()
		"fill":
			# One hold does the lot: three layers, each filled to its ring and
			# rodded 25 times, then struck off. It stops itself at the end; let
			# go part way and it waits for you
			if not st.get("armed", true):
				p.cue("action", "hold: fill and rod", 0.0, true)
				if not held:
					st["armed"] = true
				_show(t)
				return false
			var u: float = st["u"]
			p.cue("action", ("done: let go" if u >= 1.0 else "hold: fill and rod"), u, true)
			p.gold(not p.bot)
			if held and u < 1.0:
				var before := int(float(st["rods"]))
				var was_layer: int = st["layer"]
				st["u"] = minf(1.0, u + delta / FILLROD_T)
				_fill_at(st, float(st["u"]))
				var draw: String = st["draw"]
				if draw == "rod" and int(float(st["rods"])) != before:
					game.sfx.hit("tink")
				if int(st["layer"]) != was_layer:
					game.sfx.hit("plop")
					game.haptic(p, "8")
				match draw:
					"fill":
						var sw: float = sin(float(st["u"]) * 40.0)
						p.pose_arms(Vector3(-0.9 - 0.5 * sw, 0, -0.2), Vector3(-0.6, 0, 0.3))
					"rod":
						var ph := fmod(float(st["rods"]), 1.0)
						p.pose_arms(Vector3(-1.5 + 0.5 * sin(ph * TAU), 0, -0.1), Vector3(-1.5 + 0.5 * sin(ph * TAU), 0, 0.1))
					_:
						var sw2 := sin(float(st["u"]) * 60.0)
						p.pose_arms(Vector3(-1.1, 0, -0.3 + 0.3 * sw2), Vector3(-1.1, 0, 0.3 + 0.3 * sw2))
				if st["u"] >= 1.0:
					game.sfx.hit("ding")
					game.haptic(p, "12")
					game.score.award(p, 3, "Slump tests")
			elif u >= 1.0 and not held:
				st["step"] = "lift"
				st["draw"] = "lift"
				st["lift"] = 0.0
				st["armed"] = false
		"lift":
			# A fresh hold, then a steady lift straight up. Let go part way and
			# it waits a moment; stop too long and it jerks, the concrete shears
			# and the test has to be done again
			if not st.get("armed", true):
				p.cue("action", "hold: lift it straight up", 0.0, true)
				if not held:
					st["armed"] = true
				_show(t)
				return false
			var paused: float = st.get("pause", 0.0)
			p.cue("action", ("keep holding, steady!" if paused > 0.0 else "hold: lift it straight up"), st["lift"], true, Vector2(-1, -1), paused > 0.0)
			p.gold(not p.bot and paused <= 0.0)
			if held:
				st["pause"] = 0.0
				st["lift"] = minf(1.0, float(st["lift"]) + delta / LIFT_T)
				p.pose_arms(Vector3(-1.2 - 1.2 * float(st["lift"]), 0, -0.35), Vector3(-1.2 - 1.2 * float(st["lift"]), 0, 0.35))
				if st["lift"] >= 1.0:
					st["step"] = "measure"
					st["draw"] = "measure"
					st["tape"] = 0.0
					st["armed"] = false
					st["touch"] = false
					st["running"] = false
					if not st.get("wobbled", false):
						game.score.award(p, 3, "Slump tests")
						game.pop("steady lift", root.global_position + Vector3(0, 1.4, 0), Color("ffd23f"))
					game.sfx.hit("clank")
			elif st["lift"] > 0.05:
				st["pause"] = paused + delta
				st["wobbled"] = true
				if st["pause"] > LIFT_PAUSE:
					# Jerked it: one side shears off. That's no test: do it again
					st["shear"] = true
					st["step"] = "sheared"
					st["draw"] = "sheared"
					st["u"] = 0.0
					st["pause"] = 0.0
					game.sfx.hit("buzz")
					game.pop("Shear slump: test it again", root.global_position + Vector3(0, 1.4, 0), Color("ff4d4d"))
		"sheared":
			st["u"] = float(st["u"]) + delta
			p.cue("action", "press: scoop it back, start again", -1.0, true)
			if st["u"] > 1.2 and pressed:
				st["step"] = "fill"
				st["draw"] = "fill"
				st["layer"] = 0
				st["level"] = 0.0
				st["rods"] = 0.0
				st["u"] = 0.0
				st["lift"] = 0.0
				st["shear"] = false
				st["wobbled"] = false
				st["armed"] = false
		"measure":
			# Press once: the tape runs down from the rod, stops when it
			# touches the slumped top, and the reading's taken off it
			var target: float = _true(t) / 1000.0
			p.pose_arms(Vector3(-1.0, 0, -0.2), Vector3(-0.7, 0, 0.3))
			if not st.get("running", false):
				if not st.get("armed", true):
					if not held:
						st["armed"] = true
				p.cue("action", "measure it", -1.0, true)
				p.gold(not p.bot)
				if st.get("armed", true) and pressed:
					st["running"] = true
			elif not st.get("touch", false):
				p.cue("action", "measuring…", clampf(float(st["tape"]) / maxf(0.01, target), 0.0, 1.0), true)
				var slow := clampf((target - float(st["tape"])) / 0.025, 0.3, 1.0)
				st["tape"] = minf(target, float(st["tape"]) + TAPE_RATE * slow * delta)
				if st["tape"] >= target - 0.0005:
					st["touch"] = true
					st["u"] = 0.0
					game.sfx.hit("tink")
					game.haptic(p, "12")
			else:
				st["u"] = float(st["u"]) + delta
				if st["u"] > 0.35:
					t["measured"] = float(_reading_of(t))
					game.score.award(p, 5, "Slump tests")
					game.sfx.hit("ding")
					st["step"] = "done"
					st["draw"] = "done"
					done = true
	_show(t)
	return done

## Where the tester stands at the plate.
func _stand() -> Vector3:
	return root.global_position + Vector3(-0.44, 0, -0.16) * S

## How far through the one fill-and-rod hold (0 to 1) sets the layer, the
## level in the cone and the rod count: each third is a layer, filled to its
## ring then rodded 25 times; the last bit strikes off the top.
func _fill_at(st: Dictionary, u: float) -> void:
	if u >= STRIKE_FROM:
		st["layer"] = 2
		st["draw"] = "strike"
		st["rods"] = float(RODS)
		st["strike"] = clampf((u - STRIKE_FROM) / (1.0 - STRIKE_FROM), 0.0, 1.0)
		st["level"] = lerpf(0.315, CONE_H, float(st["strike"]))
		return
	var w := u / STRIKE_FROM * 3.0
	var layer := mini(2, int(w))
	var f := w - float(layer)
	var from: float = 0.0 if layer == 0 else float(MARKS[layer - 1])
	st["layer"] = layer
	if f < FILL_SHARE:
		st["draw"] = "fill"
		st["rods"] = 0.0
		st["level"] = lerpf(from, float(MARKS[layer]), smoothstep(0.0, 1.0, f / FILL_SHARE))
	else:
		st["draw"] = "rod"
		st["level"] = MARKS[layer]
		st["rods"] = (f - FILL_SHARE) / (1.0 - FILL_SHARE) * float(RODS)

## The walk for a sample, after the press: over to the truck's chute with
## the tray, a scoop of the load into it, and back to the plate. Called by
## the truck bay every frame (you're away from the bay while it runs).
func fetch_tick(t: Dictionary, chute: Vector3, delta: float) -> void:
	var st := _st(t)
	var p = st.get("who")
	if p == null or not is_instance_valid(p):
		st["step"] = "fill"
		st["armed"] = false
		return
	root.visible = true
	st["u"] = float(st["u"]) + delta
	var stand := _stand()
	if not st.has("at"):
		st["at"] = _fetch_spot(chute, stand)
		# (round the trucks, not through them: across to the lane beside the
		# hopper first, then along it)
		var at0: Vector3 = st["at"]
		st["via"] = Vector3(at0.x, 0, stand.z - 0.8)
	var at: Vector3 = st["at"]
	var via: Vector3 = st["via"]
	var tray_full := false
	st["fetch_t"] = float(st.get("fetch_t", 0.0)) + delta
	match st["leg"]:
		"go":
			if not st.get("passed", false):
				if _walk_to(p, via, float(st["u"]), delta) or float(st["u"]) > 3.0:
					st["passed"] = true
					st["u"] = 0.0
			elif _walk_to(p, at, float(st["u"]), delta):
				st["leg"] = "scoop"
				st["u"] = 0.0
		"scoop":
			p.face(chute)
			p.pose_arms(Vector3(-1.2, 0, -0.25), Vector3(-1.2, 0, 0.25))
			tray_full = float(st["u"]) > SCOOP_T * 0.5
			if st["u"] >= SCOOP_T:
				game.sfx.hit("plop")
				st["leg"] = "back"
				st["u"] = 0.0
		"back":
			tray_full = true
			if st.get("passed", false):
				if _walk_to(p, via, float(st["u"]), delta) or float(st["u"]) > 3.0:
					st["passed"] = false
					st["u"] = 0.0
			elif _walk_to(p, stand, float(st["u"]), delta):
				st["step"] = "fill"
				st["draw"] = "fill"
				st["u"] = 0.0
				st["armed"] = false
				game.sfx.hit("plop")
				game.score.award(p, 2, "Slump tests")
				if game.autotest:
					print("[autotest]   slump sample fetched in %.1fs" % float(st["fetch_t"]))
				_barrow.position = BARROW_AT
				_barrow.rotation = Vector3.ZERO
				return
	# The green tray, carried in front at the hands
	var fwd := Vector3(sin(p.model.rotation.y), 0, cos(p.model.rotation.y))
	_barrow.global_position = p.global_position + fwd * 0.75 + Vector3(0, 0.35, 0)
	_barrow.rotation = Vector3(0, p.model.rotation.y + PI * 0.5, 0)
	_barrow.visible = true
	(_barrow.get_child(1) as Node3D).visible = tray_full
	if st["leg"] != "scoop":
		p.pose_arms(Vector3(-1.1, 0, -0.25), Vector3(-1.1, 0, 0.25))

## Where to stand to fill the tray off the chute: right beside it, on
## ground you can walk on (never in the hopper's footprint or a truck's, and
## out from behind the trucks backing in).
func _fetch_spot(chute: Vector3, stand: Vector3) -> Vector3:
	var c := Vector3(chute.x, 0, chute.z)
	var to_stand := Vector3(stand.x - c.x, 0, stand.z - c.z).normalized()
	var first := Vector3.INF
	for off in [Vector3(1.15, 0, 0), Vector3(1.15, 0, 0.5), Vector3(1.15, 0, -0.5), Vector3(1.3, 0, 0), to_stand * 1.5, to_stand * 2.5]:
		var pt: Vector3 = c + off
		if game._walkable(pt, "ground"):
			if not _behind_a_truck(pt):
				return pt
			if first == Vector3.INF:
				first = pt
	# (a truck backing in right there: it waits a moment while you're behind it)
	return first if first != Vector3.INF else Vector3(stand.x, 0, stand.z)

func _behind_a_truck(pt: Vector3) -> bool:
	for t in line.trucks:
		if t["state"] in ["called", "approach", "back"]:
			var rear: Vector3 = (t["node"] as Node3D).global_transform * Vector3(-5.6, 0, 0)
			if Vector2(pt.x - rear.x, pt.z - rear.z).length() < 2.2:
				return true
	return false

## Walks a tester toward `to` (their own legs, or straight there if
## something's in the way). True once they're there.
func _walk_to(p, to: Vector3, u: float, delta: float) -> bool:
	var d := Vector2(to.x - p.position.x, to.z - p.position.z)
	if d.length() < 0.25:
		return true
	if u < 2.5:
		p.run_to = Vector3(to.x, p.position.y, to.z)
	else:
		# (stuck on something: step straight there, but never into anywhere
		# you couldn't walk out of)
		var nx := Vector3(move_toward(p.position.x, to.x, 4.0 * delta), p.position.y, move_toward(p.position.z, to.z, 4.0 * delta))
		if game._walkable(nx, p.zone):
			p.position = nx
		p.face(Vector3(to.x, p.global_position.y, to.z))
	return u > 6.0

## The tape at the top of the slumped concrete, to the nearest 5 mm.
func _reading_of(t: Dictionary) -> int:
	return int(roundf(_true(t) / 5.0) * 5.0)

## Bots do it by the book.
func _bot_hold(st: Dictionary) -> bool:
	if not st.get("armed", true):
		return false
	match st["step"]:
		"fill":
			return float(st["u"]) < 1.0
		"sheared", "done", "measure", "sample", "fetch":
			return false
	return true

func _bot_press(_t: Dictionary, st: Dictionary) -> bool:
	match st["step"]:
		"sample", "measure":
			return st.get("armed", true) and not st.get("running", false)
		"sheared":
			return true
	return false

## Draws the test as it stands.
func _show(t) -> void:
	root.visible = true
	if t == null:
		return
	var st := _st(t)
	var step: String = st.get("draw", st["step"])
	var lift: float = st["lift"]
	_scoop.visible = step == "fill"
	_mark.visible = step == "fill"
	if step == "fill":
		var mh: float = MARKS[st["layer"]]
		var mr := lerpf(R_BASE, R_TOP, clampf(mh / CONE_H, 0.0, 1.0)) + 0.008
		_mark_mesh.inner_radius = mr
		_mark_mesh.outer_radius = mr + 0.008
		_mark.position = Vector3(TEST_X, 0.03 + mh, 0)
	if st["step"] != "fetch":
		_barrow.position = BARROW_AT
		_barrow.rotation = Vector3.ZERO
		_barrow.visible = true
		(_barrow.get_child(1) as Node3D).visible = step in ["fill", "rod"]
	_tape.visible = step in ["measure", "done"]
	_reading.text = ""
	_water.emitting = false
	_reading.modulate = Color("ffc72c")
	_reading.scale = Vector3.ONE
	_t += get_process_delta_time()
	# The cone: down on the plate, lifting, then upturned beside it
	if step in ["measure", "done"]:
		_cone.position = Vector3(FLIP_X, CONE_H + 0.03, 0)
		_cone.rotation = Vector3(PI, 0, 0)
	else:
		_cone.position = Vector3(TEST_X, 0.03 + lift * (CONE_H + 0.12), 0)
		_cone.rotation = Vector3.ZERO
	# The concrete
	var h := 0.0
	var rb := R_BASE
	var rt := R_BASE
	var lean := 0.0
	if step == "sample":
		h = 0.0
	elif step in ["fill", "rod", "strike"] or (step == "lift" and lift <= 0.0):
		h = st["level"]
		var k := clampf(h / CONE_H, 0.0, 1.05)
		rb = R_BASE
		rt = lerpf(R_BASE, R_TOP, k)
	else:
		var s: float = _true(t) / 1000.0
		var e: float = smoothstep(0.0, 1.0, lift) if step == "lift" else 1.0
		var sag := s * e
		h = CONE_H - sag
		# It spreads as it drops (about the same volume)
		rb = R_BASE + sag * 0.55
		rt = R_TOP + sag * 0.35
		if step == "sheared":
			h = CONE_H * 0.55
			lean = 0.45
	_fill.visible = h > 0.004
	_fill_mesh.height = maxf(0.004, h)
	_fill_mesh.bottom_radius = rb if h > 0.004 else R_BASE
	_fill_mesh.top_radius = rt if h > 0.004 else R_BASE
	_fill.position = Vector3(TEST_X + lean * 0.12, 0.03 + h * 0.5, 0)
	_fill.rotation = Vector3(0, 0, -lean)
	# The rod: in the cone while rodding, across the top while striking off,
	# then laid across the upturned cone
	match step:
		"rod":
			var ph := fmod(float(st["rods"]), 1.0)
			_rod.rotation = Vector3(0, 0, 0.08 * sin(float(st["rods"]) * 2.3))
			_rod.position = Vector3(TEST_X + 0.04 * sin(float(st["rods"]) * 1.7), 0.03 + float(st["level"]) - 0.06 + 0.12 * absf(sin(ph * PI)), 0.03 * cos(float(st["rods"]) * 1.3))
		"strike":
			_rod.rotation = Vector3(0, 0, PI * 0.5)
			_rod.position = Vector3(TEST_X + 0.3, 0.03 + CONE_H + 0.012, -0.12 + 0.24 * float(st.get("strike", 0.0)))
		"measure", "done":
			_rod.rotation = Vector3(0, 0, PI * 0.5)
			_rod.position = Vector3(FLIP_X + 0.15, 0.03 + CONE_H + 0.009, 0)
		_:
			_rod.rotation = Vector3(0.3, 0, 0)
			_rod.position = Vector3(0.36, 0.0, -0.2)
	# The scoop going back and forth from the barrow
	if step == "fill":
		var u: float = fmod(float(st["u"]) * 9.0, 1.0)
		var from := _barrow.position + Vector3(0, 0.24, 0)
		var to := Vector3(TEST_X, 0.03 + CONE_H + 0.05, 0)
		var e2 := 0.5 - 0.5 * cos(u * TAU)
		_scoop.position = from.lerp(to, e2) + Vector3(0, 0.12 * sin(e2 * PI), 0)
		_scoop.rotation = Vector3(0, 0, -1.2 * smoothstep(0.7, 1.0, e2))
	# The tape from the rod down to the reading
	if step in ["measure", "done"]:
		var depth: float = st["tape"] if step == "measure" else float(t.get("measured", 0.0)) / 1000.0
		_tape.scale = Vector3(1, maxf(0.002, depth), 1)
		_tape.position = Vector3(TEST_X, 0.03 + CONE_H + 0.009 - depth * 0.5, 0.0)
		_reading.text = "%d mm" % int(round(depth * 1000.0))
		_reading.position = Vector3(TEST_X + 0.02, 0.03 + CONE_H + 0.1, 0.05)
		if step == "done" and not says_call(t):
			# A truck hand who knows the job reads the tape against the spec
			# themselves: the number and the band, no verdict
			_reading.text = "%d mm   spec %d-%d" % [int(t.get("measured", 0.0)), int(line.SPEC_SLUMP - line.SLUMP_TOL), int(line.SPEC_SLUMP + line.SLUMP_TOL)]
			_reading.modulate = Color.WHITE
			_reading.scale = Vector3.ONE * 1.3
		elif step == "done":
			# The reading says what to do: gold and bold in spec, blue with
			# water pouring when it's stiff, red when it goes back
			var pulse := 1.0 + 0.08 * sin(_t * 6.0)
			match line.right_call(t):
				"use":
					_reading.text = "%d mm  ✓" % int(t.get("measured", 0.0))
					_reading.modulate = Color("ffd23f") * (1.15 + 0.25 * sin(_t * 6.0))
					_reading.scale = Vector3.ONE * 1.5 * pulse
				"water":
					_reading.text = "%d mm  STIFF: ADD WATER" % int(t.get("measured", 0.0))
					_reading.modulate = Color("6cc3ff")
					_reading.scale = Vector3.ONE * 1.2 * pulse
					_water.emitting = true
				_:
					var old: bool = float(t["age"]) > line.MAX_AGE
					var why := "WRONG MIX: SEND IT BACK" if t.get("mix_wrong", "") != "" else ("TOO OLD: SEND IT BACK" if old else "SEND IT BACK")
					_reading.text = "%d mm  %s" % [int(t.get("measured", 0.0)), why]
					_reading.modulate = Color("ff5a5f")
					_reading.scale = Vector3.ONE * 1.2 * pulse

## Whether the reading says the call for this truck hand: yes while they're
## new to the job (their gold assist is still bright), no once they've got it,
## and always when there's no person on the test.
const SAYS_CALL_GOLD := 0.35
func says_call(t: Dictionary) -> bool:
	var who = t.get("tester")
	if who == null or not is_instance_valid(who) or who.bot or game == null:
		return true
	return float(game.gold_level(who)) > SAYS_CALL_GOLD

## The four steps, in order: [step key, name, what you're doing and why].
const GUIDE := [
	["sample", "SAMPLE", "Fill the green tray off the chute."],
	["fill", "FILL + ROD", "3 layers, 25 rods each, struck off."],
	["lift", "LIFT", "Straight up, steady. Don't stop."],
	["measure", "MEASURE", "Tape down from the rod."],
]

## Which of the four steps this test is on (0 to 3; 4 when it's measured).
func guide_index(t: Dictionary) -> int:
	var step: String = _st(t)["step"]
	match step:
		"done":
			return GUIDE.size()
		"sheared":
			return 2
		"fetch":
			return 0
	for i in GUIDE.size():
		if GUIDE[i][0] == step:
			return i
	return 0

## The guide's line: what this step is for, or what the reading means.
func guide_text(t: Dictionary) -> String:
	var st := _st(t)
	match st["step"]:
		"sheared":
			return "Sheared. Scoop it back, test again."
		"fetch":
			return "Off to the chute for a sample."
		"fill":
			if float(st["u"]) <= 0.0:
				return GUIDE[1][2]
			match String(st.get("draw", "fill")):
				"strike":
					return "Strike off: roll the rod across."
				"rod":
					return "Layer %d of 3: 25 rods, air out." % (int(st["layer"]) + 1)
			return "Layer %d of 3, up to the yellow ring." % (int(st["layer"]) + 1) if int(st["layer"]) < 2 else "Layer 3 of 3, heaped over the top."
		"done":
			var m := int(t.get("measured", t["slump"]))
			var lo := int(line.SPEC_SLUMP - line.SLUMP_TOL)
			var hi := int(line.SPEC_SLUMP + line.SLUMP_TOL)
			if not says_call(t):
				return "%d mm (spec %d to %d). Your call: use, water or send back." % [m, lo, hi]
			var why := "In spec: use it."
			match line.right_call(t):
				"water": why = "Too stiff: add the %d L/m³ held back, test again." % int(line.WATER_HELD)
				"reject":
					if t.get("mix_wrong", "") != "":
						why = "But the docket's the wrong mix: send it back."
					elif float(t["age"]) > line.MAX_AGE:
						why = "Over %d min old: send it back." % int(line.MAX_AGE)
					else:
						why = "Out of spec: send it back."
			return "%d mm (spec %d to %d). %s" % [m, lo, hi, why]
	return GUIDE[guide_index(t)][2]

## The close-up's caption for this test (short: the guide carries the rest).
func caption(t: Dictionary) -> String:
	var i := guide_index(t)
	if _st(t)["step"] == "sheared":
		return "SLUMP TEST · shear: again"
	if i >= GUIDE.size():
		return "SLUMP %d mm · %d min old" % [int(t.get("measured", t["slump"])), int(t["age"])]
	return "SLUMP TEST · step %d of 4: %s" % [i + 1, String(GUIDE[i][1]).to_lower()]

## Where the close-up camera sits: low and side on, so the cone, the tape
## and the slumped concrete all read.
func eye(t) -> Vector3:
	var at := root.global_position
	var st := _st(t) if t != null else {"step": ""}
	if st["step"] in ["measure", "done"]:
		return at + Vector3(0.1, 1.0, 2.5)
	return at + Vector3(-0.2, 1.7, 2.5)

func focus(t) -> Vector3:
	var st := _st(t) if t != null else {"step": ""}
	var at := root.global_position
	if st["step"] in ["measure", "done"]:
		return at + Vector3(0.1, 0.55, 0)
	return at + Vector3(-0.45, 0.6, 0)

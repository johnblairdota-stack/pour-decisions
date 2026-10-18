## The slump test at the truck bay, done by hand in a close-up, the way it's
## done on an Australian site (AS 1012.3.1, accepted against AS 1379):
##
##   1. SAMPLE    a barrow-load off the chute once the load's running
##   2. FILL      the cone (300 mm tall, 200 mm base, 100 mm top) in three
##                layers of about equal volume: about 70 mm, 160 mm, then
##                heaped over the top (hold A: it stops on the yellow ring)
##   3. ROD       each layer 25 times with the 16 mm rod to push the air out
##                (hold A: it counts to 25 and stops)
##   4. STRIKE    off the top, rolling the rod across it (hold A)
##   5. LIFT      the cone straight up, steady, in about 3 to 5 seconds (hold A:
##                stop part way for more than a moment and it jerks, the
##                concrete shears, and the test has to be done again)
##   6. MEASURE   the upturned cone goes beside it with the rod across the top;
##                the tape goes down from the rod to the centre of the slumped
##                top (hold A: it stops when it touches; press A to read it)
##
## Every step is a hold that stops itself at the right point, so anyone can
## do the test first time; a steady lift is the bonus. A guide over the
## close-up lists the six steps, ticks them off and says what each is for.
##
## Then the call: use it, add the water the plant held back (then mix and test
## again), or send it back. Everything's shown in the close-up: no docket on
## screen.
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
const STRIKE_T := 0.45
const SAMPLE_T := 0.45
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
	root.add_child(F.box(Vector3(0.9, 0.03, 0.6), steel, Vector3(0.04, 0.015, 0)))
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
	_barrow.add_child(F.box(Vector3(0.36, 0.14, 0.26), F.color_mat(Color("2f8f6b")), Vector3(0, 0.12, 0)))
	_barrow.add_child(F.box(Vector3(0.32, 0.03, 0.22), F.color_mat(Color("8f949b")), Vector3(0, 0.19, 0)))
	_barrow.position = Vector3(0.12, 0, -0.38)
	root.add_child(_barrow)
	_scoop = F.box(Vector3(0.08, 0.03, 0.1), steel, Vector3.ZERO)
	root.add_child(_scoop)
	# The reading, big, in the close-up
	_reading = F.label3d("", 22, Color("ffc72c"))
	_reading.layers = 1
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
		t["sl"] = {"step": "sample", "layer": 0, "level": 0.0, "rods": 0.0, "u": 0.0, "lift": 0.0, "tape": 0.0, "shear": false, "slips": 0}
	return t["sl"]

## Start again (after a shear, or after water's been added and mixed in).
func restart(t: Dictionary, keep_sample := false) -> void:
	t.erase("sl")
	if keep_sample:
		_st(t)["step"] = "fill"

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
## Every step is a hold of A that stops itself at the right point, so anyone
## can do it first time: the skill bonus is in keeping a steady hand.
func work(p, t: Dictionary, delta: float) -> bool:
	var st := _st(t)
	var auto: bool = p.bot or p.covering
	var held: bool = p.action_held() if not auto else _bot_hold(st)
	var pressed: bool = p.action_pressed() if not auto else _bot_press(t, st)
	# Stand at the plate, behind the cone, so the close-up has you in it
	var stand := root.global_position + Vector3(-0.44, 0, -0.16) * S
	p.position.x = move_toward(p.position.x, stand.x, 3.0 * delta)
	p.position.z = move_toward(p.position.z, stand.z, 3.0 * delta)
	p.face(root.global_position + Vector3(TEST_X, 0, 0) * S)
	var done := false
	match st["step"]:
		"sample":
			p.cue("action", "hold: scoop a sample", st["u"], true)
			p.gold(not p.bot)
			if held:
				st["u"] = minf(1.0, float(st["u"]) + delta / SAMPLE_T)
				p.pose_arms(Vector3(-1.0, 0, -0.3), Vector3(-1.0, 0, 0.3))
				if st["u"] >= 1.0:
					st["step"] = "fill"
					st["u"] = 0.0
					st["armed"] = false
					game.sfx.hit("plop")
		"fill":
			# Hold to scoop it in. It slows as it nears the yellow ring and
			# stops on it; let go and that layer's in
			var mark: float = MARKS[st["layer"]]
			var lv: float = st["level"]
			var at_mark := lv >= mark - 0.001
			if not st.get("armed", true):
				p.cue("action", "let go, then hold to fill", 0.0, true)
				if not held:
					st["armed"] = true
				_show(t)
				return false
			p.cue("action", ("at the ring: let go" if at_mark else "hold: fill to the ring"), clampf(lv / mark, 0.0, 1.0), true)
			p.gold(at_mark and not p.bot)
			if held and not at_mark:
				var near := clampf((mark - lv) / 0.03, 0.25, 1.0)
				st["level"] = minf(mark, lv + FILL_RATE * near * delta)
				st["u"] = fmod(float(st["u"]) + delta * 2.2, 1.0)
				var sw: float = sin(float(st["u"]) * TAU)
				p.pose_arms(Vector3(-0.9 - 0.5 * sw, 0, -0.2), Vector3(-0.6, 0, 0.3))
				if st["level"] >= mark - 0.001:
					game.sfx.hit("tink")
					game.haptic(p, "8")
			elif not held and at_mark:
				game.score.award(p, 1, "Slump tests")
				st["step"] = "rod"
				st["rods"] = 0.0
				st["armed"] = false
		"rod":
			# Hold to rod; the count runs up to 25 and stops. Let go and that
			# layer's done
			var rods: float = st["rods"]
			var counted := rods >= float(RODS)
			if not st.get("armed", true):
				p.cue("action", "let go, then hold to rod", 0.0, true)
				if not held:
					st["armed"] = true
				_show(t)
				return false
			p.cue("action", ("25: let go" if counted else "hold: rod it %d of 25" % int(rods)), rods / float(RODS), true)
			p.gold(counted and not p.bot)
			if held and not counted:
				var before := int(rods)
				st["rods"] = minf(float(RODS), rods + ROD_RATE * delta)
				if int(st["rods"]) != before:
					game.sfx.hit("tink")
				if st["rods"] >= float(RODS):
					game.sfx.hit("ding")
					game.haptic(p, "12")
				var ph := fmod(float(st["rods"]), 1.0)
				p.pose_arms(Vector3(-1.5 + 0.5 * sin(ph * TAU), 0, -0.1), Vector3(-1.5 + 0.5 * sin(ph * TAU), 0, 0.1))
			elif not held and counted:
				game.score.award(p, 2, "Slump tests")
				st["layer"] += 1
				st["rods"] = 0.0
				st["armed"] = false
				if st["layer"] >= 3:
					st["step"] = "strike"
					st["u"] = 0.0
				else:
					st["step"] = "fill"
					st["level"] = MARKS[st["layer"] - 1]
		"strike":
			if not st.get("armed", true):
				p.cue("action", "let go, then hold to strike off", 0.0, true)
				if not held:
					st["armed"] = true
				_show(t)
				return false
			p.cue("action", "hold: roll the rod across", st["u"], true)
			p.gold(not p.bot)
			if held:
				st["u"] = minf(1.0, float(st["u"]) + delta / STRIKE_T)
				var sw2 := sin(float(st["u"]) * TAU * 2.0)
				p.pose_arms(Vector3(-1.1, 0, -0.3 + 0.3 * sw2), Vector3(-1.1, 0, 0.3 + 0.3 * sw2))
				st["level"] = lerpf(0.315, CONE_H, float(st["u"]))
				if st["u"] >= 1.0:
					st["step"] = "lift"
					st["u"] = 0.0
					st["armed"] = false
		"lift":
			# A fresh hold, then a steady lift straight up. Let go part way and
			# it waits a moment; stop too long and it jerks, the concrete shears
			# and the test has to be done again
			if not st.get("armed", true):
				p.cue("action", "let go, then hold to lift", 0.0, true)
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
					st["tape"] = 0.0
					st["armed"] = false
					st["touch"] = false
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
					st["u"] = 0.0
					st["pause"] = 0.0
					game.sfx.hit("buzz")
					game.pop("Shear slump: test it again", root.global_position + Vector3(0, 1.4, 0), Color("ff4d4d"))
		"sheared":
			st["u"] = float(st["u"]) + delta
			p.cue("action", "press: scoop it back, start again", -1.0, true)
			if st["u"] > 1.2 and pressed:
				st["step"] = "fill"
				st["layer"] = 0
				st["level"] = 0.0
				st["lift"] = 0.0
				st["shear"] = false
				st["wobbled"] = false
				st["armed"] = false
		"measure":
			# Hold to run the tape down from the rod. It slows near the top
			# and stops when it touches; then press to read it off
			var target: float = _true(t) / 1000.0
			var depth: float = st["tape"]
			if not st.get("armed", true):
				p.cue("action", "let go, then hold to lower the tape", 0.0, true)
				if not held:
					st["armed"] = true
				_show(t)
				return false
			p.pose_arms(Vector3(-1.0, 0, -0.2), Vector3(-0.7, 0, 0.3))
			if not st.get("touch", false):
				p.cue("action", "hold: lower the tape", clampf(depth / maxf(0.01, target), 0.0, 1.0), true)
				p.gold(not p.bot)
				if held:
					var slow := clampf((target - depth) / 0.025, 0.3, 1.0)
					st["tape"] = minf(target, depth + TAPE_RATE * slow * delta)
					if st["tape"] >= target - 0.0005:
						st["touch"] = true
						st["u"] = 0.0
						game.sfx.hit("tink")
						game.haptic(p, "12")
			else:
				st["u"] = float(st["u"]) + delta
				p.cue("action", "press: read %d mm" % _reading_of(t), -1.0, true)
				p.gold(not p.bot)
				if st["u"] > 0.25 and pressed:
					t["measured"] = float(_reading_of(t))
					game.score.award(p, 5, "Slump tests")
					game.sfx.hit("ding")
					st["step"] = "done"
					done = true
	_show(t)
	return done

## The tape at the top of the slumped concrete, to the nearest 5 mm.
func _reading_of(t: Dictionary) -> int:
	return int(roundf(_true(t) / 5.0) * 5.0)

## Bots do it by the book.
func _bot_hold(st: Dictionary) -> bool:
	if not st.get("armed", true):
		return false
	match st["step"]:
		"fill":
			return float(st["level"]) < float(MARKS[st["layer"]]) - 0.001
		"rod":
			return float(st["rods"]) < float(RODS)
		"measure":
			return not st.get("touch", false)
		"sheared", "done":
			return false
	return true

func _bot_press(_t: Dictionary, st: Dictionary) -> bool:
	match st["step"]:
		"measure":
			return st.get("touch", false)
		"sheared":
			return true
	return false

## Draws the test as it stands.
func _show(t) -> void:
	root.visible = true
	if t == null:
		return
	var st := _st(t)
	var step: String = st["step"]
	var lift: float = st["lift"]
	_scoop.visible = step == "fill"
	_mark.visible = step == "fill"
	if step == "fill":
		var mh: float = MARKS[st["layer"]]
		var mr := lerpf(R_BASE, R_TOP, clampf(mh / CONE_H, 0.0, 1.0)) + 0.008
		_mark_mesh.inner_radius = mr
		_mark_mesh.outer_radius = mr + 0.008
		_mark.position = Vector3(TEST_X, 0.03 + mh, 0)
	_barrow.visible = step != "sample" or float(st["u"]) > 0.2
	(_barrow.get_child(1) as Node3D).visible = step in ["sample", "fill", "rod"]
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
			_rod.position = Vector3(TEST_X + 0.3, 0.03 + CONE_H + 0.012, -0.12 + 0.24 * float(st["u"]))
		"measure", "done":
			_rod.rotation = Vector3(0, 0, PI * 0.5)
			_rod.position = Vector3(FLIP_X + 0.15, 0.03 + CONE_H + 0.009, 0)
		_:
			_rod.rotation = Vector3(0.3, 0, 0)
			_rod.position = Vector3(0.36, 0.0, -0.2)
	# The scoop going back and forth from the barrow
	if step == "fill":
		var u: float = st["u"]
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
		if step == "done":
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
					_reading.text = "%d mm  %s" % [int(t.get("measured", 0.0)), "TOO OLD: SEND IT BACK" if old else "SEND IT BACK"]
					_reading.modulate = Color("ff5a5f")
					_reading.scale = Vector3.ONE * 1.2 * pulse

## The six steps, in order: [step key, name, what you're doing and why].
const GUIDE := [
	["sample", "SAMPLE", "Scoop a barrow-load off the chute."],
	["fill", "FILL", "3 layers, each up to the yellow ring."],
	["rod", "ROD", "25 rods a layer, air out."],
	["strike", "STRIKE", "Roll the rod across to level the top."],
	["lift", "LIFT", "Straight up, steady. Don't stop."],
	["measure", "MEASURE", "Tape down to the concrete."],
]

## Which of the six steps this test is on (0 to 5; 6 when it's measured).
func guide_index(t: Dictionary) -> int:
	var step: String = _st(t)["step"]
	if step == "done":
		return GUIDE.size()
	if step == "sheared":
		return 4
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
		"fill":
			return "Layer %d of 3, up to the yellow ring." % (int(st["layer"]) + 1) if int(st["layer"]) < 2 else "Layer 3 of 3, heaped over the top."
		"rod":
			return "Layer %d of 3: 25 rods, air out." % (int(st["layer"]) + 1)
		"done":
			var m := int(t.get("measured", t["slump"]))
			var lo := int(line.SPEC_SLUMP - line.SLUMP_TOL)
			var hi := int(line.SPEC_SLUMP + line.SLUMP_TOL)
			var why := "In spec: use it."
			match line.right_call(t):
				"water": why = "Too stiff: add the %d L/m³ held back, test again." % int(line.WATER_HELD)
				"reject": why = ("Over %d min old: send it back." % int(line.MAX_AGE)) if float(t["age"]) > line.MAX_AGE else "Out of spec: send it back."
			return "%d mm (spec %d to %d). %s" % [m, lo, hi, why]
	return GUIDE[guide_index(t)][2]

## The close-up's caption for this test (short: the guide carries the rest).
func caption(t: Dictionary) -> String:
	var i := guide_index(t)
	if _st(t)["step"] == "sheared":
		return "SLUMP TEST · shear: again"
	if i >= GUIDE.size():
		return "SLUMP %d mm · %d min old" % [int(t.get("measured", t["slump"])), int(t["age"])]
	return "SLUMP TEST · step %d of 6: %s" % [i + 1, String(GUIDE[i][1]).to_lower()]

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

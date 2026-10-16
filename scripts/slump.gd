## The slump test at the truck bay, done by hand in a close-up, the way it's
## done on an Australian site (AS 1012.3.1, accepted against AS 1379):
##
##   1. SAMPLE    a barrow-load off the chute once the load's running (hold A)
##   2. FILL      the cone (300 mm tall, 200 mm base, 100 mm top) in three
##                layers of about equal volume: about 70 mm, 160 mm, then
##                heaped over the top (hold A, let go on the mark)
##   3. ROD       each layer 25 times with the 16 mm rod (hold A, let go on 25)
##   4. STRIKE    off the top, rolling the rod across it (hold A)
##   5. LIFT      the cone straight up, steady, in about 3 to 5 seconds (hold A:
##                let go part way and it jerks, the concrete shears, and the
##                test has to be done again)
##   6. MEASURE   the upturned cone goes beside it with the rod across the top;
##                the tape goes down from the rod to the centre of the slumped
##                top (press A when it touches)
##
## Then the call: use it, add the water the plant held back (then mix and test
## again), or send it back. Everything's shown in the close-up: no docket on
## screen.
extends Node

const F := preload("res://scripts/factory.gd")

const CONE_H := 0.3          # m, the cone (the rig's scaled up, like every chibi tool, so it reads)
const S := 2.6               # the rig's scale in the world
const R_BASE := 0.1          # half of the 200 mm base
const R_TOP := 0.05          # half of the 100 mm top
const MARKS := [0.07, 0.16, 0.315]   # fill heights for the three layers (the last heaped)
const MARK_TOL := 0.02      # m either side of a mark that counts as on it
const FILL_RATE := 0.2      # m a second while A's held
const RODS := 25
const ROD_RATE := 20.0      # strokes a second (five a tap)       # strokes a second
const STRIKE_T := 0.45
const SAMPLE_T := 0.45
const LIFT_T := 2.5          # s: steady, straight up (3 to 5 s on site; the game runs quick)
const TAPE_RATE := 0.15      # m a second the tape runs down
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
	root.add_child(_reading)

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
			p.cue("action", "sample off the chute", st["u"], true)
			p.gold(not p.bot)
			if held:
				st["u"] = minf(1.0, float(st["u"]) + delta / SAMPLE_T)
				p.pose_arms(Vector3(-1.0, 0, -0.3), Vector3(-1.0, 0, 0.3))
				if st["u"] >= 1.0:
					st["step"] = "fill"
					st["u"] = 0.0
					game.sfx.hit("plop")
		"fill":
			var mark: float = MARKS[st["layer"]]
			var lv: float = st["level"]
			var top: float = 0.36
			var zone := Vector2((mark - MARK_TOL) / top, (mark + MARK_TOL) / top)
			p.cue("action", "fill layer %d of 3 to the mark" % (st["layer"] + 1) if st["layer"] < 2 else "fill and heap it over", lv / top, true, zone)
			if held:
				st["level"] = minf(top, lv + FILL_RATE * delta)
				st["u"] = fmod(float(st["u"]) + delta * 2.2, 1.0)
				var sw: float = sin(float(st["u"]) * TAU)
				p.pose_arms(Vector3(-0.9 - 0.5 * sw, 0, -0.2), Vector3(-0.6, 0, 0.3))
			elif lv >= mark - MARK_TOL:
				# Let go: that's the layer in
				if lv > mark + MARK_TOL * 2.0 and st["layer"] < 2:
					game.pop("layer's too deep", root.global_position + Vector3(0, 1.4, 0), Color("ffc72c"))
					game.score.award(p, -2, "Slump tests")
				else:
					game.score.award(p, 1, "Slump tests")
				st["step"] = "rod"
				st["rods"] = 0.0
		"rod":
			# Each tap of A is five strokes of the rod, evenly over the layer;
			# the button's gold when the last five are in and it's ready again
			var shown: float = st["rods"]
			var goal: float = st.get("goal", 0.0)
			var ready := shown >= goal - 0.01
			p.cue("action", "rod it: %d of %d (tap)" % [int(goal), RODS], goal / float(RODS), true)
			p.gold(not p.bot and ready)
			if pressed and ready and goal < RODS:
				st["goal"] = goal + 5.0
				game.haptic(p, "12")
			if shown < goal:
				var before := int(shown)
				st["rods"] = minf(goal, shown + ROD_RATE * delta)
				if int(st["rods"]) != before:
					game.sfx.hit("tink")
			var ph := fmod(float(st["rods"]), 1.0)
			if shown < goal:
				p.pose_arms(Vector3(-1.5 + 0.5 * sin(ph * TAU), 0, -0.1), Vector3(-1.5 + 0.5 * sin(ph * TAU), 0, 0.1))
			if float(st["rods"]) >= RODS:
				st["layer"] += 1
				st["rods"] = 0.0
				st["goal"] = 0.0
				if st["layer"] >= 3:
					st["step"] = "strike"
					st["u"] = 0.0
				else:
					st["step"] = "fill"
					st["level"] = MARKS[st["layer"] - 1]
		"strike":
			p.cue("action", "strike off the top", st["u"], true)
			p.gold(not p.bot)
			if held:
				st["u"] = minf(1.0, float(st["u"]) + delta / STRIKE_T)
				var sw2 := sin(float(st["u"]) * TAU * 2.0)
				p.pose_arms(Vector3(-1.1, 0, -0.3 + 0.3 * sw2), Vector3(-1.1, 0, 0.3 + 0.3 * sw2))
				st["level"] = lerpf(0.315, CONE_H, float(st["u"]))
				if st["u"] >= 1.0:
					st["step"] = "lift"
					st["u"] = 0.0
		"lift":
			p.cue("action", "lift it straight up, steady", st["lift"], true)
			p.gold(not p.bot)
			if held:
				st["lift"] = minf(1.0, float(st["lift"]) + delta / LIFT_T)
				p.pose_arms(Vector3(-1.2 - 1.2 * float(st["lift"]), 0, -0.35), Vector3(-1.2 - 1.2 * float(st["lift"]), 0, 0.35))
				if st["lift"] >= 1.0:
					st["step"] = "measure"
					st["tape"] = 0.0
					game.sfx.hit("clank")
			elif st["lift"] > 0.05:
				# Jerked it: one side shears off. That's no test: do it again
				st["shear"] = true
				st["step"] = "sheared"
				st["u"] = 0.0
				game.sfx.hit("buzz")
				game.pop("Shear slump: test it again", root.global_position + Vector3(0, 1.4, 0), Color("ff4d4d"))
				game.score.award(p, -3, "Slump tests")
		"sheared":
			st["u"] = float(st["u"]) + delta
			p.cue("action", "scoop it back, start again", -1.0, true)
			if st["u"] > 1.2 and pressed:
				st["step"] = "fill"
				st["layer"] = 0
				st["level"] = 0.0
				st["lift"] = 0.0
				st["shear"] = false
		"measure":
			# The tape runs down from the rod; the reading is where it stops
			var depth: float = st["tape"]
			var target: float = _true(t) / 1000.0
			var zone3 := Vector2((target - 0.008) / 0.31, (target + 0.008) / 0.31)
			p.cue("action", "tape touches the top: read it", depth / 0.31, true, zone3)
			st["tape"] = depth + TAPE_RATE * delta
			if st["tape"] > 0.31:
				st["tape"] = 0.0   # (missed it: back up and down again)
			p.pose_arms(Vector3(-1.0, 0, -0.2), Vector3(-0.7, 0, 0.3))
			if pressed:
				var reading: float = roundf(depth * 1000.0 / 5.0) * 5.0   # (to the nearest 5 mm)
				t["measured"] = reading
				var off := absf(reading - _true(t))
				if off <= 8.0:
					game.score.award(p, 5, "Slump tests")
					game.sfx.hit("ding")
				else:
					game.sfx.hit("tink")
				st["step"] = "done"
				done = true
	_show(t)
	return done

## Bots do it by the book.
func _bot_hold(st: Dictionary) -> bool:
	match st["step"]:
		"fill":
			return float(st["level"]) < float(MARKS[st["layer"]])
		"sheared", "measure", "done":
			return false
	return true

func _bot_press(t: Dictionary, st: Dictionary) -> bool:
	match st["step"]:
		"rod":
			return float(st["rods"]) >= float(st.get("goal", 0.0)) - 0.01
		"measure":
			return absf(float(st["tape"]) - _true(t) / 1000.0) < 0.003
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

## The close-up's caption for this test (what's being done, then the result).
func caption(t: Dictionary) -> String:
	var st := _st(t)
	match st["step"]:
		"sample": return "SLUMP TEST · sample off the chute"
		"fill", "rod":
			return "SLUMP TEST · layer %d of 3 · %s" % [mini(3, int(st["layer"]) + 1), "rod it 25 times: %d" % int(st["rods"]) if st["step"] == "rod" else "fill to the mark"]
		"strike": return "SLUMP TEST · strike off"
		"lift": return "SLUMP TEST · lift in 3 to 5 s, no twist"
		"sheared": return "SHEAR SLUMP · no test, do it again"
		"measure": return "SLUMP TEST · rod across the cone, tape to the centre"
	return "SLUMP %d mm · spec %d ±%d · batched %d min ago · %d L/m³ water held back" % [int(t.get("measured", t["slump"])), int(line.SPEC_SLUMP), int(line.SLUMP_TOL), int(t["age"]), int(line.WATER_HELD)]

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

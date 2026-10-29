## Knock off: the HUD goes and you're off the clock, free to wander the real
## streets round Riverlight, down the riverwalk and into the river, to catch
## the CityCat from the Northshore Hamilton terminal, or to jump in a Hilux, a
## Ranger or a BYD Shark parked on Angora Road and go for a drive. Step in
## front of a car, a bus or a truck and you go flying.
##
## Reached from the top-out screen (the beer button, A / Space) or the Smoko
## menu any time; the job waits (the game's paused) till you come back. Only
## the map's surrounds keep running: traffic, people, the river.
##
## Everything here is in the map's own metres (this node sits where the
## Surrounds do: x west, z north, Riverlight at the origin).
extends Node3D

const F := preload("res://scripts/factory.gd")
const UI := preload("res://scripts/ui.gd")
const Icons := preload("res://scripts/icons.gd")
const Utes := preload("res://scripts/utes.gd")
const Surrounds := preload("res://scripts/surrounds.gd")
const Water := preload("res://scripts/water.gd")
const Cars := preload("res://scripts/cars.gd")

const WALK := 4.6
const RUN := 9.0
const SWIM := 2.4
const JUMP := 6.4
const GRAVITY := 22.0
const STEP := 0.6            # m you can step up without jumping
const REACH := 3.8           # m from a ute's middle to get in
const EDGE := 1500.0         # the map runs out
const HIP := 0.85            # the body's middle above the feet: it tumbles round here
const SWIM_Y := Water.RIVER_Y - 1.05   # feet in the water, head and shoulders out

## The ute's engine and chassis (m/s, m/s²): an arcade feel, but with weight
const TOP := 41.0            # ~150 km/h
const PULL := 8.2            # off the line
const BRAKE := 15.0
const REVERSE := 9.0
const REV_ACC := 6.0
const ENGINE_DRAG := 1.4
const GRIP := 13.0           # how hard the tyres pull the car back onto its heading
const MU := 10.5             # most sideways the tyres can hold (m/s²) before it slides
const MU_HANDBRAKE := 3.2
const GEARS := [0.0, 8.0, 15.5, 23.0, 30.5, 37.0, 99.0]

var game
var active := false
var _who                     # the person who knocked off (a player.gd), or null
var _paused_it := false
var _hidden: Array = []
var cam: Camera3D
var _main_cam: Camera3D

var _d := {}
var _bpolys: Array = []      # building footprints you can't walk into
var _bgrid := {}             # 20 m cell -> footprint indexes
var _water: Array = []
var _wseg := {}              # 20 m cell -> [a, b] bank edges
var _wet := {}               # 2 m cell -> in the river
var _fer := {}               # the ferry terminal: at, dir to the bank, run, yaw
var traffic: Node
var _boat: Node3D

var mode := "walk"           # walk, drive, ride, fly (knocked over), down (lying there)
var me: Node3D               # at the feet
var tumble: Node3D           # at the hips: what spins when you go flying
var model: Node3D
var vel := Vector3.ZERO
var _grounded := true
var _swim := false
var _walk_t := 0.0
var _t := 0.0
var _yaw := 0.0              # which way you face
var _deck := Vector3.ZERO    # where you stand on the CityCat (its own metres)
var _spin := Vector3.ZERO    # tumbling, rad/s round each axis
var _down_t := 0.0
var _squash := 0.0
var _stars: Array = []
var _hit_cd := 0.0
var _back_hold := 0.0

var utes: Array = []         # {name, node, pos, yaw, v (Vector2), yaw_rate, steer, pitch, roll, pv, rv, spin, rpm}
var car: Dictionary = {}     # the one you're driving
var _smoke: Array = []

var _cam_yaw := 0.0
var _cam_pitch := 0.32
var _cam_dist := 6.5
var _cam_pos := Vector3.ZERO
var _shake := 0.0
var _rmb := false
var _pad := false

var _ui: CanvasLayer
var _badge: Control
var _prompt: PanelContainer
var _prompt_key: Label
var _prompt_text: Label
var _help: Label
var _help_t := 0.0
var _speedo: VBoxContainer
var _speed_label: Label
var _ute_label: Label
var _toast: Label
var _toast_t := 0.0

var _audio: AudioStreamPlayer
var _gen: AudioStreamGeneratorPlayback
var _eng_ph := 0.0
var _eng_rpm := 800.0
var _eng_load := 0.0
var _squeal := 0.0
var _thud := 0.0
var _noise_lp := 0.0

var _demo := OS.get_cmdline_user_args().has("--explore") or OS.get_cmdline_user_args().has("--explore=river")
		# (dev: a scripted run with screenshots; `=river` starts at the CityCat)
var _demo_t := 0.0
var _fake := {}
var _shots := {}

func setup(owner_game) -> void:
	game = owner_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	var world := game.get_node_or_null("Surrounds") as Node3D
	if world != null:
		position = world.position
		traffic = world.get_node_or_null("Traffic")
		_boat = world.get_node_or_null("CityCatRun") as Node3D
	_d = Surrounds._load()
	if not _d.is_empty():
		_index_map()
	_build_ui()
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.1
	cam.far = 16000.0
	add_child(cam)
	_audio = AudioStreamPlayer.new()
	var gs := AudioStreamGenerator.new()
	gs.mix_rate = 22050.0
	gs.buffer_length = 0.15
	_audio.stream = gs
	_audio.volume_db = -8.0
	add_child(_audio)

# ------------------------------------------------------------------ the map

func _index_map() -> void:
	for b in _d["buildings"]:
		var poly := Surrounds._v2(b["pts"])
		if poly.size() < 3 or poly[0].length() > EDGE + 200.0:
			continue
		var c := Vector2.ZERO
		for q in poly:
			c += q
		c /= poly.size()
		if not Surrounds._clear(c):
			continue
		_add_poly(poly)
	for b in _d.get("riverlight", []):
		# (the tower itself, both wings; Riverlight North isn't built here)
		if String(b["name"]) == "Riverlight Apartments":
			_add_poly(Surrounds._v2(b["pts"]))
	for a in _d["areas"]:
		if a["kind"] != "water":
			continue
		var poly := Surrounds._v2(a["pts"])
		_water.append(poly)
		for i in poly.size():
			var p0 := poly[i]
			var p1 := poly[(i + 1) % poly.size()]
			if p0.length() > EDGE + 300.0 and p1.length() > EDGE + 300.0:
				continue
			var n := maxi(1, ceili(p0.distance_to(p1) / 10.0))
			var seen := {}
			for k in n + 1:
				var q: Vector2 = p0.lerp(p1, float(k) / n)
				var cell := Vector2i(floori(q.x / 20.0), floori(q.y / 20.0))
				if seen.has(cell):
					continue
				seen[cell] = true
				if not _wseg.has(cell):
					_wseg[cell] = []
				_wseg[cell].append([p0, p1])
	for fe in _d.get("ferry", []):
		var at := Vector2(fe["at"][0], fe["at"][1])
		var edge := Vector2(fe["edge"][0], fe["edge"][1])
		var dir := (edge - at).normalized()
		_fer = {"at": at, "edge": edge, "dir": dir, "start": at + dir * 4.5, "run": (at + dir * 4.5).distance_to(edge),
			"rot": -deg_to_rad(float(fe["bank_deg"]))}
		break

func _add_poly(poly: PackedVector2Array) -> void:
	var i := _bpolys.size()
	_bpolys.append(poly)
	var box := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		box = box.expand(q)
	for cx in range(floori(box.position.x / 20.0), floori(box.end.x / 20.0) + 1):
		for cz in range(floori(box.position.y / 20.0), floori(box.end.y / 20.0) + 1):
			var cell := Vector2i(cx, cz)
			if not _bgrid.has(cell):
				_bgrid[cell] = []
			_bgrid[cell].append(i)

func _in_building(p: Vector2) -> bool:
	for i in _bgrid.get(Vector2i(floori(p.x / 20.0), floori(p.y / 20.0)), []):
		if Geometry2D.is_point_in_polygon(p, _bpolys[i]):
			return true
	return false

func _is_wet(p: Vector2) -> bool:
	var cell := Vector2i(floori(p.x / 2.0), floori(p.y / 2.0))
	if _wet.has(cell):
		return _wet[cell]
	var c := (Vector2(cell) + Vector2(0.5, 0.5)) * 2.0
	var w := false
	for poly in _water:
		if Geometry2D.is_point_in_polygon(c, poly):
			w = true
			break
	_wet[cell] = w
	return w

## How far out into the river from the nearest bank (m; 99 out in the middle).
func _from_bank(p: Vector2) -> float:
	var best := 99.0
	var c := Vector2i(floori(p.x / 20.0), floori(p.y / 20.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for sg in _wseg.get(c + Vector2i(dx, dz), []):
				best = minf(best, Geometry2D.get_closest_point_to_segment(p, sg[0], sg[1]).distance_to(p))
	return best

## The terminal's pontoon and gangway: [height, "pontoon"/"gangway"], or [].
func _ferry_floor(p: Vector2) -> Array:
	if _fer.is_empty():
		return []
	var rel: Vector2 = p - _fer["at"]
	var a: float = _fer["rot"]
	var lx := rel.dot(Vector2(cos(a), -sin(a)))
	var lz := rel.dot(Vector2(sin(a), cos(a)))
	if absf(lx) < 14.8 and absf(lz) < 4.3:
		return [Water.RIVER_Y + 0.84, "pontoon"]
	var dir: Vector2 = _fer["dir"]
	var along := (p - (_fer["start"] as Vector2)).dot(dir)
	var across := absf((p - (_fer["start"] as Vector2)).dot(Vector2(dir.y, -dir.x)))
	var run: float = _fer["run"]
	if along > -0.3 and along < run + 3.0 and across < (1.2 if along < run else 2.0):
		return [lerpf(Water.RIVER_Y + 0.84, 0.86, clampf(along / run, 0.0, 1.0)), "gangway"]
	return []

## The ground's height under `p`: the land's flat, the bank slopes down into
## the river and the bed drops away under the water.
func floor_y(p: Vector2) -> float:
	var f := _ferry_floor(p)
	if not f.is_empty():
		return f[0]
	if _is_wet(p):
		return Water.wall_y(_from_bank(p))
	return 0.0

func _blocked(p: Vector2) -> bool:
	return p.length() > EDGE or _in_building(p)

# ------------------------------------------------------------------ in and out

func can_enter() -> bool:
	return not active and not _d.is_empty()

## Knock off: `who` is the person (P1 if null), `from_menu` when it came from
## the Smoko menu (already paused).
func enter(who = null) -> void:
	if not can_enter():
		return
	active = true
	_who = who if who != null else (game.crew.human(1) if game.crew != null else null)
	_paused_it = true
	get_tree().paused = true
	var world := game.get_node_or_null("Surrounds") as Node3D
	if world != null:
		world.process_mode = Node.PROCESS_MODE_ALWAYS
	_hidden.clear()
	for c in game.get_children():
		if c is CanvasLayer and c != _ui and c.visible:
			_hidden.append(c)
			c.visible = false
	_badge.visible = false
	_main_cam = game.camera
	cam.current = true
	if utes.is_empty():
		_park_utes()
	_spawn_me()
	_help_t = 9.0
	_audio.play()
	_gen = _audio.get_stream_playback() as AudioStreamGeneratorPlayback
	_toast_msg("Knocked off. Have a look round.")

func leave() -> void:
	if not active:
		return
	if mode == "drive":
		_get_out(true)
	if mode == "ride":
		_leave_boat()
	active = false
	for c in _hidden:
		if is_instance_valid(c):
			c.visible = true
	_hidden.clear()
	var world := game.get_node_or_null("Surrounds") as Node3D
	if world != null:
		world.process_mode = Node.PROCESS_MODE_INHERIT
	if _boat != null and _boat.has_meta("tween"):
		(_boat.get_meta("tween") as Tween).set_speed_scale(1.0)
	if traffic != null:
		traffic.blockers = []
	if me != null:
		me.visible = false
	_audio.stop()
	_prompt.visible = false
	_help.visible = false
	_speedo.visible = false
	if _main_cam != null:
		_main_cam.current = true
	if _paused_it:
		get_tree().paused = false

## Three utes nose to tail in the kerb lane on Angora Road, across from the
## site: the Hilux at the front, then the Ranger and the Shark.
func _park_utes() -> void:
	var a := Vector2(16, 56)
	var b := Vector2(100, -77)
	for r in _d["roads"]:
		if String(r["name"]) == "Angora Road" and (r["pts"] as Array).size() >= 3:
			a = Vector2(r["pts"][1][0], r["pts"][1][1])
			b = Vector2(r["pts"][2][0], r["pts"][2][1])
	var u := (b - a).normalized()
	var n := Vector2(-u.y, u.x)
	if n.dot(-(a + b) * 0.5) > 0.0:
		n = -n
	# (n points away from the site; the kerb lane on the site side, facing
	# the way that side's traffic goes)
	var mid := a.lerp(b, 0.5)
	var kerb := mid - n * (5.4 - Cars.PARK_W * 0.5)
	if traffic != null:
		traffic.clear_parked_near(kerb, 16.0)
	var face := u if Vector2(u.y, -u.x).dot(-n) > 0.0 else -u
	var order: Array = Utes.NAMES.duplicate()
	var mine := _my_ute()
	if mine != "":
		# (yours at the front of the queue)
		order.erase(mine)
		order.push_front(mine)
	for i in order.size():
		var nm: String = order[i]
		var node := Utes.drivable(nm, Utes.OWN_PAINT[nm])
		Utes.apply_kit(node, nm.to_lower(), _kit_on(nm))
		add_child(node)
		var c := {"name": nm, "node": node, "pos": kerb + face * (1 - i) * 8.5, "yaw": atan2(face.x, face.y),
			"v": Vector2.ZERO, "yaw_rate": 0.0, "steer": 0.0, "pitch": 0.0, "roll": 0.0, "pv": 0.0, "rv": 0.0,
			"spin": 0.0, "rpm": 800.0, "vf_prev": 0.0, "bob": 0.0}
		utes.append(c)
		_place_car(c, 0.0)
	_fer["spawn"] = kerb - n * 3.6

## Hooks for the wallet (scripts/wallet.gd): the ute this person owns and
## has picked ("Hilux", "Ranger" or "Shark", "" for none) and the kit
## fitted to one of theirs.
func _my_ute() -> String:
	return ""

func _kit_on(_name: String) -> Array:
	return []

func _spawn_me() -> void:
	if me == null:
		me = Node3D.new()
		me.name = "OffTheClock"
		add_child(me)
		tumble = Node3D.new()
		tumble.position.y = HIP
		me.add_child(tumble)
		var src: Node3D = _who.model if _who != null and _who.get("model") != null else null
		if src != null:
			model = src.duplicate() as Node3D
			for nm in ["Kit_", "Tool"]:
				for k in model.find_children(nm + "*", "", true, false):
					(k as Node3D).visible = false
		else:
			model = F.chibi(Color("ff7a1a"), UI.P_COLORS[0])
		model.position = Vector3(0, -HIP, 0)
		model.rotation = Vector3.ZERO
		model.scale = Vector3.ONE
		tumble.add_child(model)
		for i in 3:
			var s := F.sphere(0.07, F.color_mat(UI.GOLD, false, UI.GOLD * 0.6))
			s.visible = false
			me.add_child(s)
			_stars.append(s)
	me.visible = true
	var at: Vector2 = _fer.get("spawn", Vector2(60, -14))
	me.position = Vector3(at.x, 0, at.y)
	vel = Vector3.ZERO
	mode = "walk"
	_swim = false
	tumble.basis = Basis.IDENTITY
	model.visible = true
	# looking across at the utes
	var mid: Vector2 = utes[1]["pos"] if utes.size() > 1 else at + Vector2(1, 0)
	_yaw = atan2(mid.x - at.x, mid.y - at.y)
	tumble.rotation.y = _yaw
	_cam_yaw = _yaw + PI
	_cam_pos = me.position + Vector3(sin(_cam_yaw), 0.5, cos(_cam_yaw)) * _cam_dist

# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		_pad = false
	if not active:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_rmb = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_cam_dist = maxf(3.0, _cam_dist - 0.6)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_cam_dist = minf(16.0, _cam_dist + 0.6)
	elif event is InputEventMouseMotion and _rmb:
		var mm := event as InputEventMouseMotion
		_cam_yaw -= mm.relative.x * 0.006
		_cam_pitch = clampf(_cam_pitch + mm.relative.y * 0.004, 0.05, 1.2)

func _read() -> Dictionary:
	if _demo:
		var f := {"move": Vector2.ZERO, "jump": false, "hold_a": false, "use": false, "run": false, "back": false,
			"gas": 0.0, "brake": 0.0}
		f.merge(_fake, true)
		_fake["jump"] = false
		_fake["use"] = false
		return f
	var p = _who
	var mv := Vector2.ZERO
	var jump := false
	var hold_a := false
	var use := false
	var run := false
	var back := false
	if p != null:
		mv = p.move_input()
		jump = p.action_pressed()
		hold_a = p.action_held()
		use = p.alt_pressed()
		run = p.slow_held()
		back = p._held("leave")
		p.end_frame()
	else:
		mv = Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down")
		jump = Input.is_action_just_pressed("p1_action")
		hold_a = Input.is_action_pressed("p1_action")
		use = Input.is_action_just_pressed("p1_alt")
		run = Input.is_action_pressed("p1_slow")
		back = Input.is_action_pressed("p1_leave")
	var dev: int = 0 if p == null or p.ai else p.index - 1
	var gas := Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT)
	var brake := Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT)
	var rs := Vector2(Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X), Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y))
	if rs.length() > 0.2:
		_cam_yaw -= rs.x * get_process_delta_time() * 2.4
		_cam_pitch = clampf(_cam_pitch + rs.y * get_process_delta_time() * 1.2, 0.05, 1.2)
	return {"move": mv, "jump": jump, "hold_a": hold_a, "use": use, "run": run, "back": back,
		"gas": gas if gas > 0.1 else 0.0, "brake": brake if brake > 0.1 else 0.0}

# ------------------------------------------------------------------ each frame

func _process(delta: float) -> void:
	if not active:
		_badge.visible = game != null and game.phase == "topout" and game.hud.visible and can_enter() \
			and not get_tree().paused
		if _badge.visible:
			var k := 1.0 + 0.04 * sin(Time.get_ticks_msec() / 1000.0 * TAU / UI.BREATHE_T)
			_badge.scale = Vector2(k, k)
		if _demo and game != null and game._frames > 20 and _demo_t == 0.0 and can_enter():
			enter(null)
		return
	var dt := minf(delta, 1.0 / 20.0)
	_t += dt
	_hit_cd = maxf(0.0, _hit_cd - dt)
	if _demo:
		_run_demo(dt)
	var inp := _read()
	if inp["back"]:
		_back_hold += dt
		if _back_hold > 0.8:
			_back_hold = 0.0
			leave()
			return
	else:
		_back_hold = 0.0
	match mode:
		"walk":
			_walk(dt, inp)
			_hits()
		"fly", "down":
			_ragdoll(dt, inp)
		"drive":
			_drive(dt, inp)
		"ride":
			_ride(dt, inp)
	for c in utes:
		if not is_same(c, car):
			_settle(c, dt)
	if traffic != null:
		var bl: Array = []
		for c in utes:
			bl.append(c["pos"])
		traffic.blockers = bl
	_update_camera(dt)
	_update_ui(dt)
	_feed_audio()

# ------------------------------------------------------------------ on foot

func _walk(dt: float, inp: Dictionary) -> void:
	var p2 := Vector2(me.position.x, me.position.z)
	var fl := floor_y(p2)
	_swim = fl < SWIM_Y - 0.05 and me.position.y <= SWIM_Y + 0.3
	var mv: Vector2 = inp["move"]
	var dir := Vector3(mv.x, 0, mv.y).rotated(Vector3.UP, _cam_yaw)
	var sp := SWIM if _swim else (RUN if inp["run"] else WALK)
	var want := dir * sp
	var k := 1.0 - exp(-dt * (6.0 if _swim else (14.0 if _grounded else 2.5)))
	vel.x = lerpf(vel.x, want.x, k)
	vel.z = lerpf(vel.z, want.z, k)
	# across the ground, one axis at a time so you slide along walls
	for axis in [0, 2]:
		var step := Vector3.ZERO
		step[axis] = vel[axis] * dt
		var to := Vector2(me.position.x + step.x, me.position.z + step.z)
		if _blocked(to) or _car_at(to, 0.35) or (floor_y(to) - maxf(me.position.y, fl) > STEP and not _swim):
			vel[axis] = 0.0
		else:
			me.position += step
	p2 = Vector2(me.position.x, me.position.z)
	fl = floor_y(p2)
	var stand := maxf(fl, SWIM_Y) if fl < SWIM_Y else fl
	if inp["jump"] and (_grounded or _swim):
		vel.y = JUMP * (0.7 if _swim else 1.0)
		_grounded = false
		_squash = 0.6
	if _grounded and me.position.y - stand < 0.5 and vel.y <= 0.0:
		me.position.y = move_toward(me.position.y, stand, dt * 6.0) if absf(me.position.y - stand) < 0.4 else stand
		vel.y = 0.0
	else:
		vel.y -= GRAVITY * dt
		me.position.y += vel.y * dt
		if me.position.y <= stand:
			if not _grounded and vel.y < -7.0:
				_squash = 0.7
				if fl < SWIM_Y:
					_splash(me.position)
			me.position.y = stand
			vel.y = 0.0
			_grounded = true
		else:
			_grounded = false
	if _swim:
		me.position.y = SWIM_Y + sin(_t * 2.6) * 0.05
	var flat := Vector2(vel.x, vel.z)
	if flat.length() > 0.3:
		_yaw = lerp_angle(_yaw, atan2(flat.x, flat.y), minf(1.0, dt * 12.0))
		# the camera swings round behind you as you walk forwards
		var fwd := maxf(0.0, -mv.y)
		_cam_yaw = lerp_angle(_cam_yaw, _yaw + PI, minf(1.0, dt * 1.1 * fwd))
		_walk_t += dt * (8.0 if _swim else flat.length() * 2.3)
	else:
		_walk_t = lerpf(_walk_t, roundf(_walk_t / PI) * PI, minf(1.0, dt * 8.0))
	tumble.basis = Basis(Vector3.UP, _yaw)
	_pose(dt, flat.length())
	if inp["use"]:
		var c := _near_ute()
		if not c.is_empty():
			_get_in(c)
		elif _boat_ready() and _on_pontoon():
			_board()

func _pose(dt: float, speed: float) -> void:
	var s := sin(_walk_t)
	var legs := 0.6 if speed > 0.3 or _swim else 0.0
	(model.get_node("LegL") as Node3D).rotation = Vector3(s * legs, 0, 0)
	(model.get_node("LegR") as Node3D).rotation = Vector3(-s * legs, 0, 0)
	if _swim:
		# freestyle: arms over and over
		(model.get_node("ArmL") as Node3D).rotation = Vector3(_walk_t * 1.3, 0, -0.3)
		(model.get_node("ArmR") as Node3D).rotation = Vector3(_walk_t * 1.3 + PI, 0, 0.3)
	elif not _grounded:
		(model.get_node("ArmL") as Node3D).rotation = Vector3(-2.6, 0, -0.5)
		(model.get_node("ArmR") as Node3D).rotation = Vector3(-2.6, 0, 0.5)
	else:
		var sw := s * (0.5 if speed < 6.0 else 0.9)
		(model.get_node("ArmL") as Node3D).rotation = Vector3(-sw, 0, -0.25)
		(model.get_node("ArmR") as Node3D).rotation = Vector3(sw, 0, 0.25)
	model.rotation.x = 0.25 if speed > 6.5 and _grounded else (0.5 if _swim else 0.0)
	_squash = maxf(0.0, _squash - dt * 3.0)
	var b := sin(_squash * PI) * 0.25
	model.scale = Vector3(1.0 + b, 1.0 - b, 1.0 + b)

func _near_ute() -> Dictionary:
	var p2 := Vector2(me.position.x, me.position.z)
	var best := {}
	var bd := REACH
	for c in utes:
		var dd := p2.distance_to(c["pos"])
		if dd < bd:
			bd = dd
			best = c
	return best

## A ute (parked or driven) covering `p` (within `pad`).
func _car_at(p: Vector2, pad: float) -> bool:
	for c in utes:
		if _in_box(p, c["pos"], c["yaw"], _half(c["name"]), pad):
			return true
	return false

func _half(name: String) -> Vector2:
	var s: Dictionary = Utes.SPEC[name]
	return Vector2(float(s["hw"]) + 0.05, float(s["L"]) * 0.5)

static func _in_box(p: Vector2, at: Vector2, yaw: float, half: Vector2, pad: float) -> bool:
	var rel := p - at
	var fwd := Vector2(sin(yaw), cos(yaw))
	var left := Vector2(fwd.y, -fwd.x)
	return absf(rel.dot(left)) < half.x + pad and absf(rel.dot(fwd)) < half.y + pad

# ------------------------------------------------------------------ getting hit

## Traffic doesn't stop for people on foot.
func _hits() -> void:
	if traffic == null or _hit_cd > 0.0 or me.position.y > 2.6:
		return
	var p2 := Vector2(me.position.x, me.position.z)
	for dv in traffic._drivers:
		var n: Node3D = dv["node"]
		var at := Vector2(n.position.x, n.position.z)
		if at.distance_squared_to(p2) > 100.0:
			continue
		var v: float = dv["speed"]
		if v < 1.5:
			continue
		var half: Vector2 = Cars.SIZE.get(dv["kind"], Vector2(0.9, 2.4))
		if _in_box(p2, at, n.rotation.y, half, 0.3):
			var fwd := Vector2(sin(n.rotation.y), cos(n.rotation.y))
			var side := signf((p2 - at).dot(Vector2(fwd.y, -fwd.x)))
			var big := 1.35 if dv["kind"] == "Bus" else 1.0
			_knock(fwd * v * 1.2 * big + Vector2(fwd.y, -fwd.x) * side * 2.5, v * big, "Ooft! " + {"Bus": "Hit by the bus.",
				"Van": "Cleaned up by a van."}.get(dv["kind"], "Hit by a car."))
			return

## Sent flying: `push` across the ground (m/s), how hard (for the height and
## the spin), and what to say about it.
func _knock(push: Vector2, hard: float, msg: String) -> void:
	mode = "fly"
	_hit_cd = 1.0
	_grounded = false
	vel = Vector3(push.x, 4.5 + hard * 0.5, push.y)
	me.position.y += 0.2
	var axis := Vector3(push.y, 0, -push.x).normalized()
	if axis == Vector3.ZERO:
		axis = Vector3.RIGHT
	_spin = axis * (6.0 + hard * 0.55) + Vector3(randf_range(-3, 3), randf_range(-5, 5), randf_range(-3, 3))
	_shake = minf(1.0, 0.35 + hard * 0.04)
	_thud = 1.0
	_toast_msg(msg)

func _ragdoll(dt: float, inp: Dictionary) -> void:
	var p2 := Vector2(me.position.x, me.position.z)
	var fl := floor_y(p2)
	var stand := maxf(fl, SWIM_Y) if fl < SWIM_Y else fl
	if mode == "fly":
		vel.y -= GRAVITY * dt
		var to := me.position + vel * dt
		if _blocked(Vector2(to.x, to.z)) or _car_at(Vector2(to.x, to.z), 0.2):
			# off a wall
			vel.x *= -0.45
			vel.z *= -0.45
			_shake = 0.3
			_thud = 0.6
		else:
			me.position = to
		if _spin.length() > 0.01:
			tumble.basis = Basis(_spin.normalized(), _spin.length() * dt) * tumble.basis
		tumble.basis = tumble.basis.orthonormalized()
		# arms and legs everywhere
		var f := clampf(vel.length() / 10.0, 0.2, 1.0)
		for nm in ["ArmL", "ArmR", "LegL", "LegR"]:
			var j := model.get_node(nm) as Node3D
			var ph := float(nm.hash() % 7)
			j.rotation = Vector3(sin(_t * 17.0 + ph) * 1.6 * f - 0.6, cos(_t * 13.0 + ph) * 0.6 * f,
				sin(_t * 11.0 + ph * 2.0) * 1.2 * f * (1.0 if nm.ends_with("R") else -1.0))
		if me.position.y <= stand:
			me.position.y = stand
			if fl < SWIM_Y:
				# into the river: that's the end of the flight
				_splash(me.position)
				vel = Vector3.ZERO
			if absf(vel.y) > 2.2:
				# bounce
				vel.y = -vel.y * 0.42
				vel.x *= 0.62
				vel.z *= 0.62
				_spin *= 0.6
				_squash = 1.0
				_thud = clampf(absf(vel.y) / 6.0, 0.25, 1.0)
				_shake = maxf(_shake, 0.25)
				_dust(me.position)
			else:
				mode = "down"
				_down_t = 0.0
				vel = Vector3.ZERO
		_squash = maxf(0.0, _squash - dt * 4.0)
		var b := sin(_squash * PI) * 0.3
		model.scale = Vector3(1.0 + b, 1.0 - b, 1.0 + b)
	else:
		_down_t += dt
		me.position.y = stand if fl >= SWIM_Y else SWIM_Y
		if fl < SWIM_Y:
			# (no lying about in the river)
			_down_t = maxf(_down_t, 1.4)
		var lying := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, -PI * 0.5)
		var up := Basis(Vector3.UP, _yaw)
		var get_up := clampf((_down_t - 1.6) / 0.6, 0.0, 1.0)
		var target := lying.slerp(up, ease(get_up, -2.0)) if get_up > 0.0 else lying
		tumble.basis = tumble.basis.slerp(target, minf(1.0, dt * (10.0 if get_up == 0.0 else 30.0))).orthonormalized()
		tumble.position.y = lerpf(0.22, HIP, get_up)
		for nm in ["ArmL", "ArmR", "LegL", "LegR"]:
			var j := model.get_node(nm) as Node3D
			j.rotation = j.rotation.lerp(Vector3(0, 0, (-0.9 if nm == "ArmL" else (0.9 if nm == "ArmR" else 0.0)) * (1.0 - get_up)),
				minf(1.0, dt * 6.0))
		model.scale = model.scale.lerp(Vector3.ONE, minf(1.0, dt * 8.0))
		# seeing stars
		for i in _stars.size():
			var s: Node3D = _stars[i]
			s.visible = get_up < 1.0 and fl >= SWIM_Y
			var a := _t * 4.0 + TAU * i / _stars.size()
			var head := tumble.global_position + (tumble.basis * Vector3(0, 0.55, 0))
			s.global_position = head + Vector3(cos(a) * 0.45, 0.35 + sin(_t * 6.0 + i) * 0.05, sin(a) * 0.45)
		if get_up >= 1.0 or (inp["jump"] and _down_t > 0.5):
			for s in _stars:
				s.visible = false
			tumble.basis = Basis(Vector3.UP, _yaw)
			tumble.position.y = HIP
			mode = "walk"
			_grounded = true
			_hit_cd = 1.2

func _dust(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -3, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	sm.material = F.flat_mat(Color(0.82, 0.8, 0.74, 0.7))
	p.mesh = sm
	p.position = at + Vector3(0, 0.1, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0, true, false, true).timeout.connect(p.queue_free)

func _splash(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 30
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -14, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	sm.material = F.flat_mat(Color(0.9, 0.95, 1.0, 0.85))
	p.mesh = sm
	p.position = Vector3(at.x, Water.RIVER_Y + 0.05, at.z)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2, true, false, true).timeout.connect(p.queue_free)
	_thud = maxf(_thud, 0.5)

# ------------------------------------------------------------------ the ute

func _get_in(c: Dictionary) -> void:
	car = c
	mode = "drive"
	me.visible = false
	_cam_yaw = float(c["yaw"]) + PI
	_cam_dist = 6.5
	_toast_msg(Utes.TITLE[c["name"]])

## Out of the driver's door (on the right). Bailing out at speed doesn't end
## well.
func _get_out(quiet := false) -> void:
	var c := car
	car = {}
	mode = "walk"
	me.visible = true
	var yaw: float = c["yaw"]
	var fwd := Vector2(sin(yaw), cos(yaw))
	var right := Vector2(-fwd.y, fwd.x)
	var spot: Vector2 = c["pos"] + right * (float(Utes.SPEC[c["name"]]["hw"]) + 0.8) + fwd * 0.4
	if _blocked(spot) or _car_at(spot, 0.2):
		spot = c["pos"] - right * (float(Utes.SPEC[c["name"]]["hw"]) + 0.8)
	me.position = Vector3(spot.x, floor_y(spot), spot.y)
	_yaw = atan2(right.x, right.y)
	tumble.basis = Basis(Vector3.UP, _yaw)
	vel = Vector3.ZERO
	_grounded = true
	var v: Vector2 = c["v"]
	if not quiet and v.length() > 7.0:
		_knock(v * 0.85 + right * 3.0, v.length() * 0.6, "Bailed out at %d km/h. Bold." % roundi(v.length() * 3.6))
	c["v"] = c["v"] if v.length() <= 7.0 else Vector2.ZERO
	_cam_yaw = yaw + PI

func _drive(dt: float, inp: Dictionary) -> void:
	var c := car
	var mv: Vector2 = inp["move"]
	var gas := maxf(maxf(0.0, -mv.y), float(inp["gas"]))
	var brake := maxf(maxf(0.0, mv.y), float(inp["brake"]))
	var hb: bool = inp["hold_a"]
	var yaw: float = c["yaw"]
	var fwd := Vector2(sin(yaw), cos(yaw))
	var left := Vector2(fwd.y, -fwd.x)
	var v: Vector2 = c["v"]
	var vf := v.dot(fwd)
	var vl := v.dot(left)
	# --- along: engine, brakes, reverse
	if gas > 0.0:
		if vf < -0.5:
			vf = minf(0.0, vf + BRAKE * gas * dt)
		else:
			vf += PULL * gas * maxf(0.0, 1.0 - pow(maxf(vf, 0.0) / TOP, 1.7)) * dt
	if brake > 0.0:
		if vf > 0.5:
			vf = maxf(0.0, vf - BRAKE * brake * dt)
		else:
			vf = maxf(-REVERSE, vf - REV_ACC * brake * dt)
	if gas == 0.0 and brake == 0.0:
		vf = move_toward(vf, 0.0, (ENGINE_DRAG + 0.0035 * vf * vf) * dt)
	else:
		vf -= signf(vf) * 0.0035 * vf * vf * dt
	if hb:
		vf = move_toward(vf, 0.0, 5.0 * dt)
	# --- steering: quick at a crawl, calmer at speed
	var max_steer := lerpf(0.6, 0.12, clampf(absf(vf) / 32.0, 0.0, 1.0))
	var target := mv.x * max_steer
	var st: float = c["steer"]
	st = move_toward(st, target, dt * (2.6 if absf(target) > absf(st) else 4.5))
	c["steer"] = st
	var wb: float = Utes.SPEC[c["name"]]["wb"]
	var want_rate := -vf * tan(st) / wb
	if hb and absf(vf) > 4.0:
		# the back steps out
		want_rate *= 1.5
	var yr: float = c["yaw_rate"]
	yr = lerpf(yr, want_rate, 1.0 - exp(-dt * (9.0 if not hb else 4.0)))
	c["yaw_rate"] = yr
	# --- sideways: the tyres drag the car back onto its heading, up to what
	# they can hold; past that it slides
	var hold := MU_HANDBRAKE if hb else MU
	var pull := minf(absf(vl) * GRIP, hold)
	vl = move_toward(vl, 0.0, pull * dt)
	yaw += yr * dt
	c["yaw"] = yaw
	fwd = Vector2(sin(yaw), cos(yaw))
	left = Vector2(fwd.y, -fwd.x)
	# (the velocity keeps pointing where it was: the car's turned under it,
	# and what's now sideways is the slip the tyres work on next frame)
	var was := yaw - yr * dt
	v = Vector2(sin(was), cos(was)) * vf + Vector2(cos(was), -sin(was)) * vl
	c["v"] = v
	_move_car(c, dt)
	# --- the springs: nose dives under brakes, squats on the gas, leans out
	# of corners
	var a_long := (vf - float(c["vf_prev"])) / dt
	c["vf_prev"] = vf
	_spring(c, clampf(-a_long * 0.0075, -0.06, 0.07), clampf(yr * vf * 0.011, -0.075, 0.075), dt)
	c["spin"] = float(c["spin"]) + (0.0 if hb else vf) / float(Utes.SPEC[c["name"]]["r"]) * dt
	var slide := absf(vl)
	_squeal = lerpf(_squeal, clampf((slide - 2.0) / 6.0, 0.0, 1.0) + (0.6 if hb and absf(vf) > 6.0 else 0.0), minf(1.0, dt * 8.0))
	if slide > 3.5 or (hb and absf(vf) > 6.0):
		_smoke_at(c)
	_place_car(c, dt)
	# engine: a five-speed auto, rough at idle
	var g := 1
	while g < GEARS.size() - 1 and absf(vf) > GEARS[g]:
		g += 1
	var lo: float = GEARS[g - 1]
	var hi: float = GEARS[g]
	var u := clampf((absf(vf) - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)
	var rpm := 850.0 + (1400.0 + u * 2400.0 if absf(vf) > 0.3 else 0.0) + gas * (500.0 if absf(vf) < 1.0 else 200.0)
	_eng_rpm = lerpf(_eng_rpm, rpm, minf(1.0, dt * 6.0))
	_eng_load = lerpf(_eng_load, gas, minf(1.0, dt * 5.0))
	me.position = Vector3(c["pos"].x, 0, c["pos"].y)
	if inp["use"]:
		_get_out()

## Moves a ute along by its velocity: off buildings, the river's edge and the
## other cars.
func _move_car(c: Dictionary, dt: float) -> void:
	var v: Vector2 = c["v"]
	var at: Vector2 = c["pos"]
	var to := at + v * dt
	if _car_free(c, to, float(c["yaw"])):
		c["pos"] = to
	else:
		var hit := v.length()
		var x_ok := _car_free(c, at + Vector2(v.x * dt, 0), float(c["yaw"]))
		var z_ok := _car_free(c, at + Vector2(0, v.y * dt), float(c["yaw"]))
		if x_ok and not z_ok:
			c["pos"] = at + Vector2(v.x * dt, 0)
			v.y *= -0.25
			v.x *= 0.85
		elif z_ok and not x_ok:
			c["pos"] = at + Vector2(0, v.y * dt)
			v.x *= -0.25
			v.y *= 0.85
		else:
			v *= -0.3
		c["v"] = v
		c["yaw_rate"] = float(c["yaw_rate"]) * 0.5
		if hit > 4.0:
			_shake = minf(1.0, hit * 0.05)
			_thud = clampf(hit / 15.0, 0.3, 1.0)
			c["pv"] = float(c["pv"]) - hit * 0.02
	# the traffic shoves (and is shoved by) a ute in its way
	if traffic != null:
		var me_half := _half(c["name"])
		for dv in traffic._drivers:
			var n: Node3D = dv["node"]
			var o := Vector2(n.position.x, n.position.z)
			if o.distance_squared_to(c["pos"]) > 64.0:
				continue
			var half: Vector2 = Cars.SIZE.get(dv["kind"], Vector2(0.9, 2.4))
			if _boxes_touch(c["pos"], float(c["yaw"]), me_half, o, n.rotation.y, half):
				var away: Vector2 = (c["pos"] - o).normalized()
				c["pos"] = c["pos"] + away * 0.25
				var their := Vector2(sin(n.rotation.y), cos(n.rotation.y)) * float(dv["speed"])
				var vv: Vector2 = c["v"]
				var into := vv.dot(-away)
				if into > 0.0:
					vv += away * into * 1.4
					if into > 4.0:
						_shake = minf(1.0, into * 0.06)
						_thud = clampf(into / 12.0, 0.3, 1.0)
				c["v"] = vv + their * 0.3 * dt * 10.0

func _car_free(c: Dictionary, at: Vector2, yaw: float) -> bool:
	var half := _half(c["name"])
	var fwd := Vector2(sin(yaw), cos(yaw))
	var left := Vector2(fwd.y, -fwd.x)
	for k in [[1, 1], [1, -1], [-1, 1], [-1, -1], [0, 1], [0, -1], [1, 0], [-1, 0]]:
		var q: Vector2 = at + left * half.x * float(k[0]) + fwd * half.y * float(k[1])
		if _blocked(q):
			return false
		var fl := floor_y(q)
		if fl < -0.6 or fl > 0.3:
			# (the river, the bank, the pontoon's gangway)
			return false
	for o in utes:
		if not is_same(o, c) and _boxes_touch(at, yaw, half, o["pos"], o["yaw"], _half(o["name"])):
			return false
	if traffic != null:
		for it in traffic.parked:
			if String(it[0]) == "":
				continue
			var t: Transform3D = it[1]
			var o := Vector2(t.origin.x, t.origin.z)
			if o.distance_squared_to(at) < 49.0:
				var oy := atan2(t.basis.z.x, t.basis.z.z)
				if _boxes_touch(at, yaw, half, o, oy, Cars.SIZE.get(it[0], Vector2(0.9, 2.35))):
					return false
	return true

## Two boxes overlap (separating axis test on each box's own axes).
static func _boxes_touch(a: Vector2, ay: float, ah: Vector2, b: Vector2, by: float, bh: Vector2) -> bool:
	var axes := [Vector2(cos(ay), -sin(ay)), Vector2(sin(ay), cos(ay)), Vector2(cos(by), -sin(by)), Vector2(sin(by), cos(by))]
	var d := b - a
	for ax: Vector2 in axes:
		var ra := ah.x * absf(ax.dot(axes[0])) + ah.y * absf(ax.dot(axes[1]))
		var rb := bh.x * absf(ax.dot(axes[2])) + bh.y * absf(ax.dot(axes[3]))
		if absf(d.dot(ax)) > ra + rb:
			return false
	return true

## A parked ute rocks back level, and rolls to a stop if you left it moving.
func _settle(c: Dictionary, dt: float) -> void:
	var v: Vector2 = c["v"]
	if v.length() > 0.05:
		c["v"] = v.move_toward(Vector2.ZERO, 3.0 * dt)
		_move_car(c, dt)
		c["spin"] = float(c["spin"]) + (c["v"] as Vector2).length() / 0.4 * dt
	c["steer"] = move_toward(float(c["steer"]), 0.0, dt)
	_spring(c, 0.0, 0.0, dt)
	_place_car(c, dt)

func _spring(c: Dictionary, pitch_to: float, roll_to: float, dt: float) -> void:
	var pv: float = c["pv"]
	var rv: float = c["rv"]
	pv += ((pitch_to - float(c["pitch"])) * 140.0 - pv * 11.0) * dt
	rv += ((roll_to - float(c["roll"])) * 120.0 - rv * 10.0) * dt
	c["pv"] = pv
	c["rv"] = rv
	c["pitch"] = float(c["pitch"]) + pv * dt
	c["roll"] = float(c["roll"]) + rv * dt

func _place_car(c: Dictionary, dt: float) -> void:
	var n: Node3D = c["node"]
	var p: Vector2 = c["pos"]
	n.position = Vector3(p.x, 0.0, p.y)
	n.rotation.y = c["yaw"]
	var body := n.get_node("Body") as Node3D
	var speed := (c["v"] as Vector2).length()
	c["bob"] = float(c["bob"]) + dt * (6.0 + speed * 0.9)
	body.position.y = float(n.get_meta("ride", 0.0)) + 0.02 + sin(float(c["bob"]) * 3.1) * 0.006 * clampf(speed / 20.0, 0.0, 1.0)
	body.rotation = Vector3(c["pitch"], 0, c["roll"])
	for w in ["FL", "FR", "RL", "RR"]:
		var steer := n.get_node(w) as Node3D
		steer.rotation.y = -float(c["steer"]) if w.begins_with("F") else 0.0
		(steer.get_node("Spin") as Node3D).rotation.x = c["spin"]

func _smoke_at(c: Dictionary) -> void:
	if _smoke.size() > 40 or randf() > 0.6:
		return
	var n: Node3D = c["node"]
	for w in ["RL", "RR"]:
		var at := (n.get_node(w) as Node3D).global_position
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.35
		sm.height = 0.7
		sm.radial_segments = 8
		sm.rings = 4
		s.mesh = sm
		s.material_override = F.flat_mat(Color(0.92, 0.92, 0.9, 0.55))
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s)
		s.global_position = at - Vector3(0, 0.2, 0)
		_smoke.append(s)
		var tw := s.create_tween()
		tw.set_parallel(true)
		tw.tween_property(s, "scale", Vector3.ONE * 3.0, 1.4)
		tw.tween_property(s, "position:y", s.position.y + 1.2, 1.4)
		tw.tween_property(s, "transparency", 1.0, 1.4)
		tw.chain().tween_callback(func():
			_smoke.erase(s)
			s.queue_free())

# ------------------------------------------------------------------ the CityCat

func _on_pontoon() -> bool:
	var f := _ferry_floor(Vector2(me.position.x, me.position.z))
	return not f.is_empty() and f[1] == "pontoon"

func _boat_ready() -> bool:
	if _boat == null or not _boat.has_meta("berth"):
		return false
	var berth: Vector2 = _boat.get_meta("berth")
	return Vector2(_boat.position.x, _boat.position.z).distance_to(berth) < 0.6

func _board() -> void:
	mode = "ride"
	# on through the boarding gate at the bow shoulder, the pontoon's side
	var local := _boat.to_local(to_global(me.position))
	_deck = Vector3(7.6, 1.75, 2.6 * (signf(local.z) if local.z != 0.0 else 1.0))
	_cam_dist = maxf(_cam_dist, 10.0)
	_cam_pitch = maxf(_cam_pitch, 0.5)
	_toast_msg("All aboard. Hold %s to hurry the trip." % ("RB" if _pad else "F"))

func _leave_boat() -> void:
	mode = "walk"
	var berth: Vector2 = _boat.get_meta("berth")
	var at: Vector2 = _fer["at"]
	var off := at + (berth - at).normalized() * 2.5
	me.position = Vector3(off.x, floor_y(off), off.y)
	_grounded = true
	if _boat.has_meta("tween"):
		(_boat.get_meta("tween") as Tween).set_speed_scale(1.0)

func _ride(dt: float, inp: Dictionary) -> void:
	var mv: Vector2 = inp["move"]
	# walking about the deck, the camera's way round
	var world_dir := Vector3(mv.x, 0, mv.y).rotated(Vector3.UP, _cam_yaw)
	var local_dir := _boat.global_transform.basis.inverse() * world_dir
	_deck += Vector3(local_dir.x, 0, local_dir.z) * WALK * 0.7 * dt
	_deck.x = clampf(_deck.x, -11.8, 10.8)
	_deck.z = clampf(_deck.z, -3.1, 3.1)
	me.global_position = _boat.to_global(_deck)
	if mv.length() > 0.2:
		_yaw = lerp_angle(_yaw, atan2(world_dir.x, world_dir.z), minf(1.0, dt * 10.0))
		_walk_t += dt * 9.0
	tumble.basis = Basis(Vector3.UP, _yaw)
	_grounded = true
	_swim = false
	_pose(dt, mv.length() * 3.0)
	if _boat.has_meta("tween"):
		(_boat.get_meta("tween") as Tween).set_speed_scale(5.0 if inp["run"] else 1.0)
	if _boat_ready() and inp["use"]:
		_leave_boat()
	elif inp["jump"] and not _boat_ready():
		# over the side
		mode = "walk"
		var side := _boat.global_transform.basis.z * signf(_deck.z if _deck.z != 0.0 else 1.0)
		me.global_position = _boat.to_global(Vector3(_deck.x, 2.2, 3.9 * signf(_deck.z if _deck.z != 0.0 else 1.0)))
		vel = Vector3(side.x, 0, side.z) * 3.0 + Vector3(0, 4.0, 0)
		_grounded = false
		if _boat.has_meta("tween"):
			(_boat.get_meta("tween") as Tween).set_speed_scale(1.0)
		_toast_msg("Man overboard!")

# ------------------------------------------------------------------ camera

func _update_camera(dt: float) -> void:
	var focus: Vector3
	var want: Vector3
	var fov := 55.0
	if mode == "drive":
		var c := car
		var yaw: float = c["yaw"]
		var v: Vector2 = c["v"]
		var speed := v.length()
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		# (behind the way it's pointing; swings round slowly, so a slide shows)
		var back := yaw + PI
		if v.dot(Vector2(fwd.x, fwd.z)) < -3.0:
			back = yaw
		_cam_yaw = lerp_angle(_cam_yaw, back, minf(1.0, dt * (2.2 if not _rmb else 0.0)))
		focus = Vector3(c["pos"].x, 1.3, c["pos"].y) + fwd * clampf(speed * 0.08, 0.0, 2.5)
		var dist := _cam_dist + 0.6 + speed * 0.06
		want = focus + Vector3(sin(_cam_yaw) * cos(_cam_pitch * 0.7), sin(_cam_pitch * 0.7) + 0.12, cos(_cam_yaw) * cos(_cam_pitch * 0.7)) * dist
		fov = 55.0 + clampf(speed * 0.45, 0.0, 18.0)
	else:
		focus = me.position + Vector3(0, 1.2, 0)
		if mode == "fly" or mode == "down":
			focus = tumble.global_position - global_position + Vector3(0, 0.4, 0)
		want = focus + Vector3(sin(_cam_yaw) * cos(_cam_pitch), sin(_cam_pitch), cos(_cam_yaw) * cos(_cam_pitch)) * _cam_dist
		# (never under the water or the ground)
	var fl := floor_y(Vector2(want.x, want.z))
	want.y = maxf(want.y, maxf(fl, Water.RIVER_Y) + 0.5)
	_cam_pos = _cam_pos.lerp(want, 1.0 - exp(-dt * (7.0 if mode != "drive" else 9.0)))
	_shake = maxf(0.0, _shake - dt * 1.8)
	var jiggle := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.25
	cam.position = _cam_pos + jiggle
	cam.fov = lerpf(cam.fov, fov, minf(1.0, dt * 3.0))
	if cam.position.distance_to(focus) > 0.1:
		cam.look_at(to_global(focus), Vector3.UP)

# ------------------------------------------------------------------ sound

## The ute's engine (a four-cylinder diesel's firing note, rough with
## noise), tyres squealing in a slide and a thud when something hits.
func _feed_audio() -> void:
	if _gen == null:
		return
	var n := _gen.get_frames_available()
	var driving := mode == "drive"
	var f := _eng_rpm / 60.0 * 2.0
	var vol := (0.16 + 0.14 * _eng_load) if driving else 0.0
	for i in n:
		_eng_ph += f / 22050.0
		if _eng_ph > 1.0:
			_eng_ph -= 1.0
		var ph := _eng_ph * TAU
		var noise := randf_range(-1.0, 1.0)
		_noise_lp = lerpf(_noise_lp, noise, 0.25)
		var e := (sin(ph) * 0.55 + sin(ph * 2.0 + 0.4) * 0.3 + sin(ph * 0.5) * 0.35 + _noise_lp * 0.35) * (0.7 + 0.3 * sin(ph * 0.5))
		var s := e * vol
		s += (noise - _noise_lp) * _squeal * 0.18 * sin(_t * 900.0 + i * 0.37)
		s += _noise_lp * _thud * 0.9
		_thud = maxf(0.0, _thud - 1.0 / 22050.0 * 5.0)
		s = clampf(s, -1.0, 1.0)
		_gen.push_frame(Vector2(s, s))
	if not driving:
		_squeal = 0.0

# ------------------------------------------------------------------ on screen

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 8
	add_child(_ui)
	# The top-out screen's way out: a beer, and "Knock off"
	_badge = PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = UI.GLASS_SOLID
	bs.set_corner_radius_all(40)
	bs.border_color = UI.YELLOW
	bs.set_border_width_all(3)
	bs.content_margin_left = 14
	bs.content_margin_right = 26
	bs.content_margin_top = 10
	bs.content_margin_bottom = 10
	_badge.add_theme_stylebox_override("panel", bs)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_badge.add_child(row)
	var disc := PanelContainer.new()
	var ds := StyleBoxFlat.new()
	ds.bg_color = UI.YELLOW
	ds.set_corner_radius_all(36)
	disc.add_theme_stylebox_override("panel", ds)
	disc.custom_minimum_size = Vector2(72, 72)
	var beer := TextureRect.new()
	beer.texture = Icons.texture("beer", 128)
	beer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	beer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	beer.custom_minimum_size = Vector2(72, 72)
	beer.modulate = UI.INK
	disc.add_child(beer)
	row.add_child(disc)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -4)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(UI.head("KNOCK OFF", 40, UI.WHITE))
	var sub := Label.new()
	sub.text = "Space · A · go for a wander"
	sub.add_theme_font_override("font", UI.font("body"))
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", UI.MUTED)
	words.add_child(sub)
	row.add_child(words)
	_badge.visible = false
	_ui.add_child(_badge)
	_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_badge.position = Vector2(-40, -40)
	_badge.resized.connect(func():
		_badge.pivot_offset = _badge.size * 0.5
		_badge.position = get_viewport().get_visible_rect().size - _badge.size - Vector2(36, 36))
	# what you can do here (a button and a word)
	_prompt = PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = UI.GLASS
	ps.set_corner_radius_all(26)
	ps.content_margin_left = 10
	ps.content_margin_right = 20
	ps.content_margin_top = 6
	ps.content_margin_bottom = 6
	_prompt.add_theme_stylebox_override("panel", ps)
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 12)
	_prompt.add_child(pr)
	_prompt_key = UI.head("X", 30, UI.GLYPH_INK["X"])
	var ks := StyleBoxFlat.new()
	ks.bg_color = UI.GLYPH["X"]
	ks.set_corner_radius_all(22)
	ks.content_margin_left = 12
	ks.content_margin_right = 12
	_prompt_key.add_theme_stylebox_override("normal", ks)
	pr.add_child(_prompt_key)
	_prompt_text = UI.head("", 30, UI.WHITE)
	pr.add_child(_prompt_text)
	_prompt.visible = false
	_ui.add_child(_prompt)
	_help = Label.new()
	_help.add_theme_font_override("font", UI.font("body"))
	_help.add_theme_font_size_override("font_size", 22)
	_help.add_theme_color_override("font_color", UI.BONE)
	_help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_help.add_theme_constant_override("outline_size", 6)
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_help.visible = false
	_ui.add_child(_help)
	_speedo = VBoxContainer.new()
	_speedo.add_theme_constant_override("separation", -8)
	_speed_label = UI.head("0", 64, UI.WHITE, 8)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speedo.add_child(_speed_label)
	_ute_label = UI.head("", 24, UI.BONE, 6)
	_ute_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speedo.add_child(_ute_label)
	_speedo.visible = false
	_ui.add_child(_speedo)
	_toast = UI.head("", 40, UI.YELLOW, 10)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	_ui.add_child(_toast)

func _toast_msg(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_t = 2.6

func _update_ui(dt: float) -> void:
	var view := get_viewport().get_visible_rect().size
	# what's on offer where you are
	var key := ""
	var text := ""
	match mode:
		"walk":
			var c := _near_ute()
			if not c.is_empty():
				key = "X"
				text = "Get in the " + Utes.TITLE[c["name"]]
			elif _on_pontoon():
				if _boat_ready():
					key = "X"
					text = "Board the CityCat"
				else:
					text = "Wait here for the CityCat"
		"drive":
			if (car["v"] as Vector2).length() < 7.0:
				key = "X"
				text = "Get out"
		"ride":
			if _boat_ready():
				key = "X"
				text = "Get off at Northshore Hamilton · hold %s to cast off" % _key_name("Y")
			else:
				key = "Y"
				text = "Hold to hurry the trip · A: jump over the side"
		"down":
			key = "A"
			text = "Get up"
	_prompt.visible = text != ""
	if _prompt.visible:
		_prompt_key.visible = key != ""
		_prompt_key.text = _key_name(key)
		var ks := _prompt_key.get_theme_stylebox("normal") as StyleBoxFlat
		if key != "":
			ks.bg_color = UI.GLYPH[key]
			_prompt_key.add_theme_color_override("font_color", UI.GLYPH_INK[key])
		_prompt_text.text = text
		_prompt.reset_size()
		_prompt.position = Vector2((view.x - _prompt.size.x) * 0.5, view.y - _prompt.size.y - 70.0)
	_help_t = maxf(0.0, _help_t - dt)
	_help.visible = _help_t > 0.0
	if _help.visible:
		_help.modulate.a = clampf(_help_t, 0.0, 1.0)
		if mode == "drive":
			_help.text = ("Stick steer · RT go · LT brake / reverse · hold A handbrake · X get out" if _pad else
				"W go · S brake / reverse · A D steer · hold Space handbrake · E get out") + \
				"\n" + ("Hold B: back to the site" if _pad else "Hold Q: back to the site")
		else:
			_help.text = ("Stick walk · hold RB run · A jump · X get in · right stick look" if _pad else
				"WASD walk · hold F run · Space jump · E get in · right-drag look") + \
				"\n" + ("Hold B: back to the site" if _pad else "Hold Q or Esc: back to the site")
		_help.reset_size()
		_help.position = Vector2((view.x - _help.size.x) * 0.5, view.y - _help.size.y - 18.0)
	_speedo.visible = mode == "drive"
	if _speedo.visible:
		_speed_label.text = "%d km/h" % roundi((car["v"] as Vector2).length() * 3.6)
		_ute_label.text = Utes.TITLE[car["name"]]
		_speedo.reset_size()
		_speedo.position = view - _speedo.size - Vector2(36, 24)
	_toast_t = maxf(0.0, _toast_t - dt)
	_toast.visible = _toast_t > 0.0
	if _toast.visible:
		_toast.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
		_toast.reset_size()
		_toast.position = Vector2((view.x - _toast.size.x) * 0.5, view.y * 0.16)

func _key_name(k: String) -> String:
	if k == "" or _pad or (_who != null and _who.ai):
		return {"X": "X", "A": "A", "Y": "RB", "": ""}[k]
	return {"X": "E", "A": "Space", "Y": "F"}[k]

# ------------------------------------------------------------------ dev: a scripted run with screenshots

func _shot(key: String) -> void:
	if _shots.has(key) or game.shot_dir == "":
		return
	_shots[key] = true
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(game.shot_dir)
	img.save_png(game.shot_dir.path_join("explore_%s.png" % key))
	print("[explore] shot ", key)

var _demo_step := 0
var _demo_mark := 0.0
var _demo_dv: Dictionary = {}

func _run_demo(dt: float) -> void:
	if _demo_t == 0.0 and OS.get_cmdline_user_args().has("--explore=river"):
		_demo_step = 7
	_demo_t += dt
	if Engine.get_process_frames() % 20 == 0:
		print("[explore] t %.1f step %d mode %s at %s" % [_demo_t, _demo_step, mode, me.position])
	# (the autotest only draws frames it wants a shot of)
	RenderingServer.render_loop_enabled = true
	var t := _demo_t - _demo_mark
	_fake["move"] = Vector2.ZERO
	_fake["gas"] = 0.0
	_fake["hold_a"] = false
	_fake["run"] = false
	match _demo_step:
		0:
			# a walk across to the utes
			_fake["move"] = Vector2(0, -1)
			if t > 1.6:
				_shot("walk")
			if t > 2.4:
				_next()
		1:
			_get_in(utes[0])
			_next()
		2:
			_fake["gas"] = 1.0
			_fake["move"] = Vector2(0.0 if t < 3.0 else 0.35, 0)
			if t > 4.5:
				_shot("drive")
			if t > 5.5:
				_fake["hold_a"] = true
				_fake["move"] = Vector2(1.0, 0)
			if t > 6.3:
				_shot("drift")
			if t > 7.0:
				_next()
		3:
			# back to the kerb for a look at all three
			_get_out(true)
			var c: Dictionary = utes[0]
			c["v"] = Vector2.ZERO
			c["pos"] = (utes[1]["pos"] as Vector2) * 2.0 - (utes[2]["pos"] as Vector2)
			c["yaw"] = utes[1]["yaw"]
			var mid: Vector2 = utes[1]["pos"]
			var side := Vector2(cos(float(utes[1]["yaw"])), -sin(float(utes[1]["yaw"])))
			me.position = Vector3(mid.x - side.x * 9.0, 0, mid.y - side.y * 9.0)
			_cam_yaw = atan2(-side.x, -side.y) + 0.5
			_cam_dist = 12.0
			_cam_pitch = 0.3
			_next()
		4:
			if t > 1.5:
				_shot("utes")
				_cam_dist = 6.5
				_next()
		5:
			# out on the road in front of the traffic
			if _demo_dv.is_empty():
				for dv in traffic._drivers:
					var n: Node3D = dv["node"]
					if float(dv["speed"]) > 6.0 and dv["kind"] != "Bus" and Vector2(n.position.x, n.position.z).length() < 300.0:
						_demo_dv = dv
						break
			if _demo_dv.is_empty():
				_demo_dv = traffic._drivers[0]
			var n: Node3D = _demo_dv["node"]
			var fwd := Vector3(sin(n.rotation.y), 0, cos(n.rotation.y))
			me.position = n.position + fwd * 9.0
			me.position.y = 0.0
			_cam_yaw = n.rotation.y + PI * 0.5
			_next()
		6:
			if mode == "fly" and not _shots.has("hit"):
				_demo_mark = _demo_t - 0.0
				_demo_step = 61
			elif t > 4.0:
				_knock(Vector2(sin(_cam_yaw), cos(_cam_yaw)) * 12.0, 12.0, "Ooft! Hit by a car.")
		61:
			if t > 0.3:
				_shot("hit")
			if mode == "down" and t > 1.0:
				_shot("down")
			if mode == "walk" and t > 1.5:
				_next()
		7:
			# down at the CityCat terminal
			var at: Vector2 = _fer["at"]
			var off := at + (_fer["dir"] as Vector2) * 2.0
			me.position = Vector3(off.x, floor_y(off), off.y)
			_cam_yaw = atan2((_fer["dir"] as Vector2).x, (_fer["dir"] as Vector2).y) + 0.6
			_cam_dist = 14.0
			_cam_pitch = 0.35
			if _boat.has_meta("tween"):
				(_boat.get_meta("tween") as Tween).set_speed_scale(25.0)
			_next()
		8:
			if _boat_ready():
				(_boat.get_meta("tween") as Tween).set_speed_scale(1.0)
				if t > 0.0 and not _shots.has("terminal"):
					_shot("terminal")
					_demo_mark = _demo_t
				elif _shots.has("terminal") and t > 0.5:
					_board()
					_next()
			elif t > 120.0:
				_next()
		9:
			# away up the river, then over the side
			_fake["run"] = t > 1.0
			if t > 7.0 and not _boat_ready():
				_shot("citycat")
				_fake["jump"] = true
				_next()
		10:
			if t > 2.5:
				_shot("swim")
				_next()
		11:
			# along the riverwalk to the water's edge
			if mode == "ride":
				_leave_boat()
			var at: Vector2 = _fer["edge"]
			var dir: Vector2 = _fer["dir"]
			var along := Vector2(-dir.y, dir.x)
			var spot := at + along * 30.0 + dir * 2.0
			me.position = Vector3(spot.x, 0, spot.y)
			_cam_yaw = atan2(dir.x, dir.y) + 0.4
			_cam_dist = 9.0
			_next()
		12:
			_fake["move"] = Vector2(0, -1)
			if t > 0.2:
				_cam_yaw = atan2((_fer["dir"] as Vector2).x, (_fer["dir"] as Vector2).y)
			if t > 2.2:
				_shot("bank")
			if t > 3.0:
				print("[explore] demo done")
				get_tree().quit(0)

func _next() -> void:
	print("[explore] step %d done at %.1fs (frame %d)" % [_demo_step, _demo_t, Engine.get_process_frames()])
	_demo_step += 1
	_demo_mark = _demo_t

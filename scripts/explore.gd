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
const Wallet := preload("res://scripts/wallet.gd")
const Surrounds := preload("res://scripts/surrounds.gd")
const Water := preload("res://scripts/water.gd")
const Cars := preload("res://scripts/cars.gd")
const Crash := preload("res://scripts/crash.gd")
const Park := preload("res://scripts/park4x4.gd")
const Offroad := preload("res://scripts/offroad.gd")

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
const DEEP := Water.RIVER_Y - 14.0     # the Brisbane River's bed out in the channel
const GONE := 3.4            # s from going under (or driving in) to waking up back at the site
const RAMP := 6.0            # m of ramp from the terminal's landing down to the riverwalk

## The ute's engine and chassis (m/s, m/s²): an arcade feel, but with weight
const TOP := 41.0            # ~150 km/h
const BRAKE := 15.0
const REVERSE := 9.0
const REV_ACC := 6.0
const GRIP := 13.0           # how hard the tyres pull the car back onto its heading
const MU := 10.5             # most sideways the tyres can hold (m/s²) before it slides
const MU_HANDBRAKE := 3.2
const COM_H := 0.85          # a ute's centre of mass above the ground (m)

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
var _piers: Array = []        # [box, polygon] of the piers you can walk out on (surrounds.gd)
var _wseg := {}              # 20 m cell -> [a, b] bank edges
var _wet := {}               # 2 m cell -> in the river
var _fer := {}               # the ferry terminal: at, dir to the bank, run, yaw
var traffic: Node
var crash: Node3D            # what a ute can run into (crash.gd)
var park: Park                # the golf course's 4x4 park (park4x4.gd)
var _park_done := {}         # its challenges you've driven: "bog", "dam", "hill", "sand"
var _park_in := ""           # the challenge you're in now
var _park_t := 0.0           # (and since when)
var _park_run := {}          # this go at it: where you came in, the lowest you got, time stopped, rescued
var _park_medal := {}        # this knock-off's best medal at each ("gold", "silver", "bronze")
var _mud_slap := 0.0         # mud flung up into the wheel arches
var _park_label: Label
var _indexed := false
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
var _gone_t := 0.0           # drowning, or the ute going down
var _frozen := false         # the Smoko menu's up over the wander
var _fade: ColorRect
var _board_label: Label3D    # the terminal's timetable screen
var _board_t := 0.0

var utes: Array = []         # {name, node, pos, yaw, v (Vector2), yaw_rate, steer, pitch, roll, pv, rv, spin, rpm}
var car: Dictionary = {}     # the one you're driving
var _kit_sig := ""           # whose ute and kit is parked at the kerb
var _smoke: Array = []
var _y_hold := 0.0           # how long Y's been held in the ute (a tap shifts 2H/4H/4L, a hold airs the tyres)
var _y_was := false
var _y_used := false         # (this hold's already done its job)
var _hiss := 0.0             # air out of (or into) the tyres
var _scrape := 0.0           # a bumper or the belly dragging on the dirt

var _cam_yaw := 0.0
var _cam_pitch := 0.32
var _cam_dist := 6.5
var _cam_pos := Vector3.ZERO
var _shake := 0.0
var _rmb := false
var _look_hold := 0.0        # just looked round: the camera leaves you be this long before easing back behind
const LOOK_HOLD := 1.5
## In a ute the D-pad is the 4x4 controls: up/down the drive, right the
## locker, left the tyres (so it doesn't steer as well)
const DPAD := {"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN, "left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT}
var _dpad_was := {}
var _snap_was := false
var _dash_q := ""            # a tap on the phone's dash (drive, lock, air), done next frame
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
var _revs: Array = []        # the tacho's segments
var _gear_label: Label
var _drive_label: Label      # 2H / 4H / 4L, the locker, the tyres
var _dmg_fill: ColorRect
var _toast: Label
var _toast_t := 0.0

var _audio: AudioStreamPlayer
var _places_t := 0.0
var _gen: AudioStreamGeneratorPlayback
var _eng_ph := 0.0
var _eng_rpm := 800.0
var _eng_load := 0.0
var _squeal := 0.0
var _thud := 0.0
var _noise_lp := 0.0
var _whine_ph := 0.0

var _demo: bool = Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a == "--explore" or (a.begins_with("--explore=") and a != "--explore=live"))
## Dev: `--explore=live` knocks the first phone to join off straight away and
## leaves the driving to that phone (for trying the phone's free roam page)
var _live: bool = OS.get_cmdline_user_args().has("--explore=live")
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
	if world != null:
		# the estate's apartment blocks, terraces and houses (neighbours.gd)
		for poly in world.get_meta("foot", []):
			if (poly as PackedVector2Array).size() >= 3:
				_add_poly(poly)
	_build_ui()
	if not _fer.is_empty():
		_build_terminal()
	crash = Crash.new()
	crash.name = "Crash"
	add_child(crash)
	park = Park.new()
	park.name = "Park4x4"
	add_child(park)
	if not _d.is_empty():
		park.build(_d)
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
	for pr in Surrounds.piers(_d):
		var polys: Array = []
		if pr.has("pts"):
			polys.append(Surrounds._v2(pr["pts"]))
		else:
			var ln := Surrounds._v2(pr["line"])
			for i in ln.size() - 1:
				var side := (ln[i + 1] - ln[i]).normalized().orthogonal() * float(pr["w"]) * 0.5
				polys.append(PackedVector2Array([ln[i] + side, ln[i + 1] + side, ln[i + 1] - side, ln[i] - side]))
		for poly: PackedVector2Array in polys:
			var box := Rect2(poly[0], Vector2.ZERO)
			for q in poly:
				box = box.expand(q)
			_piers.append([box, poly])
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
	# (the ramp down off the landing to the riverwalk)
	var ed := p - (_fer["edge"] as Vector2)
	var ea := ed.dot(_fer["dir"])
	if ea >= 3.0 and ea < 3.0 + RAMP and absf(ed.dot(Vector2(_fer["dir"].y, -_fer["dir"].x))) < 1.25:
		return [lerpf(0.86, 0.0, (ea - 3.0) / RAMP), "ramp"]
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
	for pr in _piers:
		if (pr[0] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, pr[1]):
			return 0.3
	if _is_wet(p):
		# (down the bank's wall, then away to the channel: well over your head)
		var a := _from_bank(p)
		if a <= 3.6:
			return Water.wall_y(a)
		return lerpf(Water.wall_y(3.6), DEEP, clampf((a - 3.6) / 8.0, 0.0, 1.0))
	return park.height(p) if park != null else 0.0

func _blocked(p: Vector2) -> bool:
	return p.length() > EDGE or _in_building(p) or _ferry_solid(p)

## The CityCat terminal's posts, glass windbreak, benches and boarding rail
## (citycat.py's Terminal): solid, with the gaps where the gangway comes in
## and the boat ties up.
func _ferry_solid(p: Vector2) -> bool:
	if _fer.is_empty():
		return false
	var rel: Vector2 = p - _fer["at"]
	var a: float = _fer["rot"]
	var x := rel.dot(Vector2(cos(a), -sin(a)))
	var z := rel.dot(Vector2(sin(a), cos(a)))
	if absf(x) > 15.5 or absf(z) > 6.5:
		return false
	for px: float in [-10.5, -3.5, 3.5, 10.5]:
		for pz: float in [-3.0, 3.8]:
			if Vector2(x - px, z - pz).length() < 0.4:
				return true
	for px: float in [-11.0, 11.0]:
		if Vector2(x - px, z - 5.2).length() < 0.85:
			return true
	# (the windbreak and the benches along it)
	if absf(x) > 1.3 and absf(x) < 10.3 and z > 3.7 and z < 4.35:
		return true
	if absf(absf(x) - 6.0) < 2.1 and z > 3.15 and z < 4.35:
		return true
	# (the rail along the river edge, open where the boat comes alongside)
	if absf(x) > 2.3 and absf(x) < 15.0 and z < -3.9 and z > -4.6:
		return true
	return false

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
	game.far_shadows(true)
	# (re-parked when this person's ute or kit isn't what's at the kerb,
	# say after a shop at Smoko)
	var sig := "%s|%s|%s" % [_my_ute(), _kit_on("Hilux"), [_kit_on("Ranger"), _kit_on("Shark")]]
	if not utes.is_empty() and sig != _kit_sig and car.is_empty():
		_clear_utes()
	_kit_sig = sig
	if utes.is_empty():
		_park_utes()
	if not _indexed and world != null:
		_indexed = true
		crash.index(world)
		park.clear_trees(crash)
	_spawn_me()
	_update_boards()
	_help_t = 9.0
	_audio.play()
	_gen = _audio.get_stream_playback() as AudioStreamGeneratorPlayback
	# (the site's sound keeps going while the job's paused, but only the place:
	# the machines and the band stop till you're back)
	game.sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	game.sfx.hush_site()
	_places_t = 0.0
	_toast_msg("Knocked off. Have a look round.")

func _menu_up() -> bool:
	return game.pause_menu != null and game.pause_menu.visible

func _set_world(m: int) -> void:
	var world := game.get_node_or_null("Surrounds") as Node3D
	if world != null:
		world.process_mode = m

func leave() -> void:
	if not active:
		return
	if mode == "drive":
		_get_out(true)
	if mode == "ride":
		_leave_boat()
	active = false
	game.far_shadows(false)
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
	# (back at the site: the utes go back to the kerb for next time, and
	# what they knocked over stands back up)
	_clear_utes()
	crash.reset()
	if me != null:
		me.visible = false
	_audio.stop()
	for name in PLACES:
		game.sfx.set_ambience(name, 0.0)
	game.sfx.process_mode = Node.PROCESS_MODE_INHERIT
	_frozen = false
	_fade.color.a = 0.0
	_prompt.visible = false
	_help.visible = false
	_speedo.visible = false
	if _main_cam != null:
		_main_cam.current = true
	if _paused_it:
		get_tree().paused = false

func _clear_utes() -> void:
	for c in utes:
		(c["node"] as Node3D).queue_free()
	utes.clear()
	car = {}
	_kit_sig = ""

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
		var kit := _kit_on(nm)
		Utes.apply_kit(node, nm.to_lower(), kit)
		add_child(node)
		var c := {"name": nm, "node": node, "pos": kerb + face * (1 - i) * 8.5, "yaw": atan2(face.x, face.y),
			"v": Vector2.ZERO, "yaw_rate": 0.0, "steer": 0.0, "pitch": 0.0, "roll": 0.0, "pv": 0.0, "rv": 0.0,
			"spin": 0.0, "rpm": 800.0, "vf_prev": 0.0, "bob": 0.0, "dmg": 0.0, "gear": 1, "shift": 0.0, "tip": 0.0,
			"rb": false, "bent": {"FL": 0.0, "FR": 0.0, "RL": 0.0, "RR": 0.0}, "stuck": 0.0, "smoke_t": 0.0,
			"y": 0.0, "vy": 0.0, "gp": 0.0, "gr": 0.0, "air": false}
		_offroad(c, kit)
		utes.append(c)
		_place_car(c, 0.0)
	_fer["spawn"] = kerb - n * 3.6

## Hooks for the wallet (scripts/wallet.gd): the ute this person owns and
## has picked ("Hilux", "Ranger" or "Shark", "" for none) and the kit
## fitted to one of theirs.
func _my_ute() -> String:
	var id := String(Wallet.of(_char()).get("ute", ""))
	return id.capitalize() if id in Wallet.UTES.map(func(u): return u["id"]) else ""

## (only on the utes they own: the others at the kerb are stock)
func _kit_on(name: String) -> Array:
	var w := Wallet.of(_char())
	if not (w.get("utes", []) as Array).has(name.to_lower()):
		return []
	return Array((w.get("kit", {}) as Dictionary).get(name.to_lower(), []))

func _char() -> String:
	return String(_who.char_id) if _who != null and "char_id" in _who and _who.char_id != "" else ""

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
	_grounded = true
	_gone_t = 0.0
	tumble.basis = Basis.IDENTITY
	tumble.position.y = HIP
	model.visible = true
	model.scale = Vector3.ONE
	for s in _stars:
		s.visible = false
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
		_look_hold = LOOK_HOLD

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
	# (a phone has pedals and a swipe to look, no pad behind it)
	var phone: bool = p != null and p.remote_id >= 0
	var gas := 0.0
	var brake := 0.0
	var rs := Vector2.ZERO
	var jl := Vector2.ZERO
	var dpad := {}
	var snap := false
	if not phone:
		gas = Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT)
		brake = Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT)
		rs = Vector2(Input.get_joy_axis(dev, JOY_AXIS_RIGHT_X), Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y))
		jl = Vector2(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X), Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y))
		var any_dpad := false
		for k in DPAD:
			var on := Input.is_joy_button_pressed(dev, DPAD[k])
			dpad[k] = on and not bool(_dpad_was.get(k, false))
			_dpad_was[k] = on
			any_dpad = any_dpad or on
		if mode == "drive" and any_dpad:
			mv = jl if jl.length() > 0.2 else Vector2.ZERO
		var r3 := Input.is_joy_button_pressed(dev, JOY_BUTTON_RIGHT_STICK)
		snap = r3 and not _snap_was
		_snap_was = r3
	var drag := Vector2.ZERO
	if p != null:
		if (p.look as Vector2).length() > rs.length():
			rs = p.look
		gas = maxf(gas, (p.pedal as Vector2).x)
		brake = maxf(brake, (p.pedal as Vector2).y)
		drag = p.look_drag
		p.look_drag = Vector2.ZERO
	var dt := get_process_delta_time()
	_look_hold = maxf(0.0, _look_hold - dt)
	if rs.length() > 0.2:
		_cam_yaw -= rs.x * dt * 2.4
		_cam_pitch = clampf(_cam_pitch + rs.y * dt * 1.2, 0.05, 1.2)
		_look_hold = LOOK_HOLD
	if drag != Vector2.ZERO:
		# (a swipe right across the whole phone turns you round most of the way)
		_cam_yaw -= drag.x * 3.6
		_cam_pitch = clampf(_cam_pitch + drag.y * 2.0, 0.05, 1.2)
		_look_hold = LOOK_HOLD
	if snap:
		_look_hold = 0.0
		_cam_yaw = (float(car["yaw"]) if mode == "drive" and not car.is_empty() else _yaw) + PI
	var dash := _dash_q
	_dash_q = ""
	return {"move": mv, "jump": jump, "hold_a": hold_a, "use": use, "run": run, "back": back,
		"gas": gas if gas > 0.1 else 0.0, "brake": brake if brake > 0.1 else 0.0,
		# gas and brake off the stick only on keys: a pad has triggers, a phone pedals
		"stick_gas": not phone and jl.length() < 0.2,
		# an analog stick (a phone's or a pad's) pushed right to its edge: run
		"edge": (phone or jl.length() > 0.2) and mv.length() > 0.95,
		"dpad": dpad, "dash": dash}

# ------------------------------------------------------------------ each frame

func _process(delta: float) -> void:
	_board_t -= delta
	if _board_t <= 0.0 and _board_label != null:
		_board_t = 1.0
		_update_board()
	if not active:
		_badge.visible = game != null and game.phase == "topout" and game.hud.visible and can_enter() \
			and not get_tree().paused
		if _badge.visible:
			var k := 1.0 + 0.04 * sin(Time.get_ticks_msec() / 1000.0 * TAU / UI.BREATHE_T)
			_badge.scale = Vector2(k, k)
		if _demo and game != null and game._frames > 20 and _demo_t == 0.0 and can_enter():
			enter(null)
		if _live and game != null and game._frames > 20 and can_enter():
			for p in game.players:
				if p.remote_id >= 0:
					_live = false
					enter(p)
					break
		return
	var dt := minf(delta, 1.0 / 20.0)
	if _menu_up():
		# Smoko over the wander: everything holds where it is
		if _demo:
			_run_demo(dt)
		if not _frozen:
			_frozen = true
			_set_world(Node.PROCESS_MODE_INHERIT)
			_audio.stream_paused = true
		return
	if _frozen:
		_frozen = false
		_set_world(Node.PROCESS_MODE_ALWAYS)
		_audio.stream_paused = false
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
		"drown":
			_drown(dt)
		"sink":
			_sink(dt)
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
	_feed_places(dt)

# ------------------------------------------------------------------ on foot

func _walk(dt: float, inp: Dictionary) -> void:
	var p2 := Vector2(me.position.x, me.position.z)
	var fl := floor_y(p2)
	_swim = fl < SWIM_Y - 0.05 and me.position.y <= SWIM_Y + 0.3
	var mv: Vector2 = inp["move"]
	var dir := Vector3(mv.x, 0, mv.y).rotated(Vector3.UP, _cam_yaw)
	var sp := SWIM if _swim else (RUN if inp["run"] or inp.get("edge", false) else WALK)
	var want := dir * sp
	var k := 1.0 - exp(-dt * (6.0 if _swim else (14.0 if _grounded else 2.5)))
	vel.x = lerpf(vel.x, want.x, k)
	vel.z = lerpf(vel.z, want.z, k)
	# across the ground, one axis at a time so you slide along walls
	for axis in [0, 2]:
		var step := Vector3.ZERO
		step[axis] = vel[axis] * dt
		var to := Vector2(me.position.x + step.x, me.position.z + step.z)
		# (your shoulder against the wall, not your middle)
		var reach := Vector2(signf(step.x), signf(step.z)) * 0.32
		if _blocked(to) or _blocked(to + reach) or _car_at(to, 0.35) or (floor_y(to) - maxf(me.position.y, fl) > STEP and not _swim):
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
		if fl < SWIM_Y - 0.6:
			# out of your depth in the Brisbane River: the current takes you
			mode = "drown"
			_gone_t = 0.0
			_toast_msg("Out of your depth! The current's got you.")
			return
	var flat := Vector2(vel.x, vel.z)
	if flat.length() > 0.3:
		_yaw = lerp_angle(_yaw, atan2(flat.x, flat.y), minf(1.0, dt * 12.0))
		# the camera swings round behind you as you walk forwards
		# (unless you've just looked round)
		var fwd := maxf(0.0, -mv.y) if _look_hold <= 0.0 else 0.0
		_cam_yaw = lerp_angle(_cam_yaw, _yaw + PI, minf(1.0, dt * 1.1 * fwd))
		_walk_t += dt * (8.0 if _swim else flat.length() * 2.3)
	else:
		_walk_t = lerpf(_walk_t, roundf(_walk_t / PI) * PI, minf(1.0, dt * 8.0))
		# stood still, done looking round: the camera eases back behind you
		if _look_hold <= 0.0 and not _rmb:
			_cam_yaw = lerp_angle(_cam_yaw, _yaw + PI, minf(1.0, dt * 0.8))
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
				if fl < SWIM_Y - 0.6:
					mode = "drown"
					_gone_t = 0.0
					tumble.basis = Basis(Vector3.UP, _yaw)
					return
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

# ------------------------------------------------------------------ the river

## Out of your depth: a bit of a thrash at the top, then down you go, and
## you wake up back at the site.
func _drown(dt: float) -> void:
	_gone_t += dt
	var sink := clampf((_gone_t - 1.1) / 1.6, 0.0, 1.0)
	me.position.y = SWIM_Y + sin(_t * 7.0) * 0.12 * (1.0 - sink) - sink * sink * 3.0
	_swim = true
	# arms up, waving
	for nm in ["ArmL", "ArmR"]:
		(model.get_node(nm) as Node3D).rotation = Vector3(-2.9 + sin(_t * 9.0 + (0.0 if nm == "ArmL" else 2.0)) * 0.5, 0,
			(-0.4 if nm == "ArmL" else 0.4))
	for nm in ["LegL", "LegR"]:
		(model.get_node(nm) as Node3D).rotation = Vector3(sin(_t * 8.0 + (0.0 if nm == "LegL" else PI)) * 0.7, 0, 0)
	if sink > 0.0 and fmod(_gone_t, 0.25) < dt:
		_bubbles(me.position + Vector3(0, 1.4, 0))
	_fade.color.a = clampf((_gone_t - (GONE - 0.7)) / 0.6, 0.0, 1.0)
	if _gone_t >= GONE:
		_respawn("Drowned in the Brisbane River. Back at the site.")

## The ute nose-dives off the bank, wallows, and goes under with you in it.
func _sink(dt: float) -> void:
	var c := car
	_gone_t += dt
	var v: Vector2 = c["v"]
	c["v"] = v.move_toward(Vector2.ZERO, (6.0 if float(c["y"]) < Water.RIVER_Y else 2.0) * dt)
	c["pos"] = (c["pos"] as Vector2) + (c["v"] as Vector2) * dt
	var y: float = c["y"]
	var vy: float = c["vy"]
	if y > Water.RIVER_Y - 0.4:
		vy -= GRAVITY * dt
	else:
		# floats a moment, then the water's in
		if float(c.get("splashed", 0.0)) == 0.0:
			c["splashed"] = 1.0
			_splash(Vector3(c["pos"].x, 0, c["pos"].y))
			_shake = 0.6
			_thud = 1.0
		vy = lerpf(vy, -0.35 - _gone_t * 0.4, minf(1.0, dt * 3.0))
	c["y"] = y + vy * dt
	c["vy"] = vy
	# heavy end first
	c["pitch"] = lerpf(float(c["pitch"]), 0.35, minf(1.0, dt * 1.2))
	c["roll"] = lerpf(float(c["roll"]), 0.08, minf(1.0, dt))
	_place_car(c, dt)
	if y < Water.RIVER_Y and fmod(_gone_t, 0.15) < dt:
		_bubbles(Vector3(c["pos"].x, Water.RIVER_Y - 0.2, c["pos"].y) + Vector3(randf_range(-1, 1), 0, randf_range(-1.5, 1.5)))
	_eng_load = 0.0
	_eng_rpm = lerpf(_eng_rpm, 0.0, minf(1.0, dt * 2.0))
	_fade.color.a = clampf((_gone_t - (GONE - 0.7)) / 0.6, 0.0, 1.0)
	if _gone_t >= GONE:
		_respawn("The ute's at the bottom of the river. You're back at the site.")

## Back at the site, the utes parked up again at the kerb.
func _respawn(msg: String) -> void:
	_clear_utes()
	crash.reset()
	_park_utes()
	_kit_sig = "%s|%s|%s" % [_my_ute(), _kit_on("Hilux"), [_kit_on("Ranger"), _kit_on("Shark")]]
	_spawn_me()
	_cam_pitch = 0.32
	_fade.color.a = 1.0
	var tw := _fade.create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(_fade, "color:a", 0.0, 0.9)
	_toast_msg(msg)

func _bubbles(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 8
	p.lifetime = 0.7
	p.explosiveness = 0.6
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 1.0, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.material = F.flat_mat(Color(0.92, 0.97, 1.0, 0.8))
	p.mesh = sm
	p.position = Vector3(at.x, maxf(at.y, Water.RIVER_Y - 0.1), at.z)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0, true, false, true).timeout.connect(p.queue_free)

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
	_end_rec()
	_drop_spotter()
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
	if c["rb"]:
		_tumble(c, dt)
		return
	var mv: Vector2 = inp["move"]
	var sg: bool = inp.get("stick_gas", true)
	var gas := maxf(maxf(0.0, -mv.y) if sg else 0.0, float(inp["gas"]))
	var brake := maxf(maxf(0.0, mv.y) if sg else 0.0, float(inp["brake"]))
	var hb: bool = inp["hold_a"]
	var dead := _dead(c)
	if dead:
		gas = 0.0
	var e: Dictionary = Utes.ENGINE[c["name"]]
	var o: Dictionary = c["off"]
	var mass: float = float(e["mass"]) + float(o["extra"])
	var r: float = Utes.SPEC[c["name"]]["r"]
	var yaw: float = c["yaw"]
	var fwd := Vector2(sin(yaw), cos(yaw))
	var left := Vector2(fwd.y, -fwd.x)
	var v: Vector2 = c["v"]
	var vf := v.dot(fwd)
	var vl := v.dot(left)
	var spd := absf(vf)
	c["pos_prev"] = c["pos"]
	# --- winching out, or being snatched out by a mate: it's doing the driving
	if _recover(c, hb and not dead, gas, dt):
		return
	# --- Y: a tap steps through 2H, 4H, 4L and the rear locker; held while
	# stopped, it lets the tyres down (or pumps them up at an air station)
	var yh: bool = inp["run"]
	if yh and not _y_was:
		_y_hold = 0.0
		_y_used = false
	if yh:
		_y_hold += dt
	if not yh and _y_was and _y_hold < 0.45:
		_shift_drive(c, spd)
	if yh and _y_hold >= 0.6 and spd < 0.6 and not c.has("air_job") and not _y_used:
		_y_used = true
		_start_air(c)
	_y_was = yh
	_dash_controls(c, spd, inp)
	_tyre_job(c, spd, dt)
	var drive: String = c["drive"]
	var low := drive.begins_with("4L") and float(o["low"]) > 0.0
	# --- what it's on: the 4x4 park's mud, sand, water and dirt hold it up
	# and give the tyres less to bite on; in the air they've nothing
	var surf: String = park.surface(c["pos"]) if park != null else ""
	var grip := 1.0
	var res := 0.0
	match surf:
		"mud":
			grip = 0.6
			res = 0.1 + 0.12 * clampf(-park.height(c["pos"]) / 0.42, 0.0, 1.0)
		"sand":
			grip = 0.65
			res = 0.09
		"water":
			grip = 0.7
			res = 0.04 + 0.14 * maxf(0.0, park.water(c["pos"]) - park.height(c["pos"])) + 0.003 * vf * vf
		"dirt":
			grip = 0.88
			res = 0.012
		"grass":
			grip = 0.8
			res = 0.02
	# (the tyres: mud-terrains bite harder off the road, and aired down they
	# float over the sand; a flat one drags)
	var psi: float = c["psi"]
	var mu := Offroad.mu(surf, o["mud"], psi)
	grip *= mu / Offroad.mu(surf, false, Offroad.PSI_ROAD)
	if surf == "sand":
		res *= lerpf(1.0, 0.45, clampf((Offroad.PSI_ROAD - psi) / (Offroad.PSI_ROAD - Offroad.PSI_LOW), 0.0, 1.0))
	if c["flat"] != "":
		grip *= 0.85
		mu *= 0.85
		res += 0.03
	# (dug in: the wheels sitting in their own holes)
	res += float(c["dig"]) * 0.35
	var air: bool = c.get("air", false)
	if air:
		grip = 0.0
	# --- the drivetrain: what the engine (or the motors) put through the wheels
	var force := 0.0
	var reversing := vf < -0.3 or (brake > 0.0 and vf < 0.5 and gas == 0.0)
	if e["kind"] == "phev":
		var ratio: float = e["gears"][0]
		var fmax := float(e["nm"]) * ratio * 0.9 / r
		force = minf(fmax, float(e["kw"]) * 1000.0 / maxf(spd, 1.0)) * gas
		c["rpm"] = spd / r * ratio * 60.0 / TAU
		c["gear"] = 1
	else:
		var gears: Array = e["gears"]
		var fd: float = e["final"]
		var g: int = c["gear"]
		var ratio: float = float(e["reverse"]) if reversing else float(gears[g - 1])
		if low:
			# (low range: the transfer case gears it all down again)
			ratio *= float(o["low"])
		var wheel_rpm := spd / r * 60.0 / TAU
		var eng := wheel_rpm * ratio * fd
		# (the torque converter lets it rev up to its stall speed off the line,
		# and multiplies the torque while it's slipping)
		var stall := lerpf(float(e["idle"]), float(e["torque_from"]) + 300.0, gas)
		var slip := clampf(1.0 - eng / maxf(stall, 1.0), 0.0, 1.0)
		var rpm := maxf(eng, maxf(float(e["idle"]), stall * slip + eng * (1.0 - slip)))
		if not dead:
			force = Utes.torque_at(e, rpm) * gas * ratio * fd * 0.8 / r * (1.0 + slip * 0.2)
		if eng > float(e["cut"]):
			force = 0.0
		c["shift"] = maxf(0.0, float(c["shift"]) - dt)
		if float(c["shift"]) > 0.0:
			force *= 0.3
		if not reversing:
			var up_at := lerpf(1900.0, float(e["red"]), gas)
			if eng > up_at and g < (ceili(gears.size() * 0.5) if low else gears.size()):
				g += 1
				c["shift"] = 0.32
			elif g > 1 and (eng < lerpf(1250.0, float(e["red"]) * 0.6, gas) \
					and eng * float(gears[g - 2]) / float(gears[g - 1]) < float(e["red"]) * 0.95 or (low and g > ceili(gears.size() * 0.5))):
				g -= 1
				c["shift"] = 0.22
			if spd < 1.0:
				g = 1
		c["gear"] = g
		c["rpm"] = 0.0 if dead else rpm
	if spd * 3.6 > (35.0 if c["flat"] != "" else float(e["top"])):
		force = 0.0
	# (what a diesel ute really pulls off the line, turbo lag and all, or
	# crawling in low range; the Shark's motors give it everything at once)
	force = minf(force, (0.62 if e["kind"] == "phev" else (0.85 if low else 0.45)) * mass * 9.8)
	# --- and what the tyres can put down: the driven wheels' share of the
	# weight (more on the back going uphill), none from one hanging in the air
	# unless the diff's locked, none at all with the belly on a crest
	var wb0: float = Utes.SPEC[c["name"]]["wb"]
	var rear := clampf(1.0 - float(o["front"]) + sin(float(c.get("gp", 0.0))) * float(o["com"]) / wb0, 0.1, 0.95)
	var trac := Offroad.traction(drive, mu, c["lift"], rear, float(c["belly"])) * mass * 9.8 * cos(float(c.get("gp", 0.0)))
	var want := force
	if drive != "2H":
		# (off-road traction control: it cuts the power to a spinning wheel)
		want = minf(want, trac * 1.15)
	force = minf(force, trac)
	var slip := 0.0
	if gas > 0.2 and want > trac * 1.03 and not air:
		slip = clampf((want - trac) / (mass * 9.8 * 0.25), 0.15, 1.0)
	c["slip"] = lerpf(float(c.get("slip", 0.0)), slip, minf(1.0, dt * 6.0))
	var drag := 0.6 * float(e["cda"]) * vf * vf + 0.016 * mass * 9.8 * clampf(spd, 0.0, 1.0)
	if gas > 0.0:
		if vf < -0.5:
			vf = minf(0.0, vf + BRAKE * gas * dt)
		else:
			vf += (force - drag) / mass * dt
	if brake > 0.0:
		if vf > 0.5:
			vf = maxf(0.0, vf - BRAKE * brake * maxf(grip, 0.25) * dt)
		elif not dead:
			vf = maxf(-REVERSE, vf - REV_ACC * brake * dt)
		else:
			# (a drowned or wrecked engine doesn't go backwards either)
			vf = move_toward(vf, 0.0, BRAKE * brake * dt)
	if gas == 0.0 and brake == 0.0:
		# rolling, the engine holding it back
		var hold := drag / mass + (0.5 + float(c["rpm"]) / 4000.0 * 0.9 if e["kind"] != "phev" else 0.9)
		if low:
			# (low range holds it back down a hill, no brakes needed)
			hold = maxf(hold * 2.5, 9.8 * sin(absf(float(c.get("gp", 0.0)))) + 0.6)
		vf = move_toward(vf, 0.0, hold * dt)
	if hb:
		vf = move_toward(vf, 0.0, 5.0 * dt)
	if not air:
		# a hill pulling it back (or on down), and the bog holding it
		vf -= 9.8 * sin(float(c.get("gp", 0.0))) * dt
		vf = move_toward(vf, 0.0, res * 9.8 * dt)
	# --- steering: quick at a crawl, calmer at speed; a bent wheel pulls
	var bent: Dictionary = c["bent"]
	var max_steer := lerpf(0.6, 0.12, clampf(absf(vf) / 32.0, 0.0, 1.0))
	var pull := (float(bent["FL"]) - float(bent["FR"])) * 0.12
	if c["flat"] != "":
		pull += 0.06 if String(c["flat"]).ends_with("L") else -0.06
	var target := clampf(mv.x * max_steer + pull, -0.65, 0.65)
	var st: float = c["steer"]
	st = move_toward(st, target, dt * (2.6 if absf(target) > absf(st) else 4.5))
	c["steer"] = st
	var wb: float = Utes.SPEC[c["name"]]["wb"]
	var want_rate := -vf * tan(st) / wb
	if hb and absf(vf) > 4.0:
		# the back steps out
		want_rate *= 1.5
	if drive == "4L+LOCK" and surf in ["", "dirt", "grass"]:
		# (a locked diff pushes on wide: both back wheels want to go the same speed)
		want_rate *= 0.7
	var yr: float = c["yaw_rate"]
	if air:
		want_rate = yr
	yr = lerpf(yr, want_rate, 1.0 - exp(-dt * (9.0 if not hb else 4.0) * maxf(grip, 0.3)))
	c["yaw_rate"] = yr
	# --- sideways: the tyres drag the car back onto its heading, up to what
	# they can hold; past that it slides
	var hold_l := (MU_HANDBRAKE if hb else MU) * grip
	if not air:
		# (across a slope it wants to slide down it)
		vl -= 9.8 * sin(float(c.get("gr", 0.0))) * dt
	vl = move_toward(vl, 0.0, minf(absf(vl) * GRIP, hold_l) * dt)
	yaw += yr * dt
	c["yaw"] = yaw
	fwd = Vector2(sin(yaw), cos(yaw))
	left = Vector2(fwd.y, -fwd.x)
	# (the velocity keeps pointing where it was: the car's turned under it,
	# and what's now sideways is the slip the tyres work on next frame)
	var was := yaw - yr * dt
	v = Vector2(sin(was), cos(was)) * vf + Vector2(cos(was), -sin(was)) * vl
	c["v"] = v
	# --- sliding sideways too fast, the tyres dig in and over it goes
	var lift := float((c["node"] as Node3D).get_meta("ride", 0.0))
	if absf(vl) > 9.0 and spd > 8.0:
		c["tip"] = float(c["tip"]) + (absf(vl) - 9.0) * dt * (0.6 + lift * 3.0)
	else:
		c["tip"] = maxf(0.0, float(c["tip"]) - dt * 2.0)
	var lean := float(c.get("gr", 0.0))
	var tip_at := 0.6 - (float(o["com"]) - 0.85) * 0.5
	if absf(lean) > tip_at and not air:
		# (too steep across a slope: the high side lifts, and over she goes)
		c["tip"] = float(c["tip"]) + (absf(lean) - tip_at) * dt * 10.0 + dt * 2.0
		if float(c["tip"]) > 1.0:
			c["tip"] = 0.0
			_launch(c, Vector3(v.x, 1.4, v.y), Vector3(fwd.x, 0, fwd.y) * signf(lean) * 2.6)
			_toast_msg("Over she goes! Too steep across the hill.")
			return
	if float(c["tip"]) > 1.0:
		c["tip"] = 0.0
		_launch(c, Vector3(v.x, 2.2 + absf(vl) * 0.12, v.y), Vector3(fwd.x, 0, fwd.y) * -signf(vl) * (2.0 + absf(vl) * 0.3))
		_toast_msg("Rolled it!")
		return
	_move_car(c, dt)
	if c["rb"] or mode != "drive":
		return
	_follow_ground(c, dt, true)
	if c["rb"]:
		return
	_chassis(c, dt)
	_offroad_tick(c, surf, gas, dt)
	if mode != "drive":
		return
	# --- the springs: nose dives under brakes, squats on the gas, leans out
	# of corners (more on a lift kit)
	var a_long := (vf - float(c["vf_prev"])) / dt
	c["vf_prev"] = vf
	_spring(c, clampf(-a_long * 0.009, -0.08, 0.09), clampf(yr * vf * 0.0135 * (1.0 + lift * 4.0), -0.13, 0.13), dt)
	c["spin"] = float(c["spin"]) + (0.0 if hb else vf + float(c["slip"]) * 14.0) / r * dt
	var slide := absf(vl)
	_squeal = lerpf(_squeal, clampf((slide - 2.0) / 6.0, 0.0, 1.0) + (0.6 if hb and absf(vf) > 6.0 else 0.0), minf(1.0, dt * 8.0))
	if slide > 3.5 or (hb and absf(vf) > 6.0):
		_smoke_at(c)
	_place_car(c, dt)
	_damage_fx(c, dt)
	_park_fx(c, surf, gas, vf, dt)
	_mud_slap = lerpf(_mud_slap, clampf((spd - 1.0) / 7.0, 0.0, 1.0) if surf == "mud" or (surf == "water" and spd > 2.0) else 0.0, minf(1.0, dt * 6.0))
	_park_challenges(c, dt)
	_spotter(c, dt)
	_eng_rpm = lerpf(_eng_rpm, float(c["rpm"]), minf(1.0, dt * 10.0))
	_eng_load = lerpf(_eng_load, gas, minf(1.0, dt * 5.0))
	me.position = Vector3(c["pos"].x, float(c.get("y", 0.0)), c["pos"].y)
	var cp: Vector2 = c["pos"]
	if _is_wet(cp) and floor_y(cp) < Water.RIVER_Y - 0.3:
		# off the edge and into the river
		mode = "sink"
		_gone_t = 0.0
		c["y"] = 0.0
		c["vy"] = 0.0
		_toast_msg("Into the river! That's the %s gone." % Utes.TITLE[c["name"]])
		return
	# --- never stuck: foot down and going nowhere, or upside down
	if gas > 0.3 and spd < 0.4:
		c["stuck"] = float(c["stuck"]) + dt
	else:
		c["stuck"] = maxf(0.0, float(c["stuck"]) - dt)
	if float(c["stuck"]) > 1.2:
		if surf in ["mud", "sand", "water", "grass", "dirt"] and _car_block(c, c["pos"], c["yaw"], 0.0, Vector2.ZERO).is_empty():
			# (bogged or beaten by the hill: a mate with a snatch strap, unless
			# you've a winch to get yourself out; they wait longer for that)
			if float(c["stuck"]) > (12.0 if "winch" in (c["kit"] as Array) else 6.0) and _rec.is_empty():
				c["stuck"] = 0.0
				_start_strap(c, -fwd)
		else:
			_unstick(c, true)
			c["stuck"] = 0.0
	if inp["use"]:
		_get_out()

# ------------------------------------------------------------------ recovery

## Getting unstuck: the winch on the bull bar (hold A when you're bogged or
## hung up and it drags you out to a tree, or a ground anchor if there's no
## tree in reach); with no winch, a mate backs up with a snatch strap. And on
## the park's steep stuff, a mate walks out in front and spots you over it.
const WINCH_LINE := 28.0     # m of rope on the drum
const WINCH_PULL := 0.7      # m/s it drags the ute in (more with the wheels turning too)
const CARTON := 40           # $: what a mate's snatch costs you
const SPOT_AT := ["hill", "logs", "moguls"]

var _rec := {}               # the winch or strap job on now: kind, t, anchor, rope, the mate's ute
var _winch := 0.0            # the winch motor's grind
var _winch_ph := 0.0
var _spot: Node3D            # the spotter, out in front on the hard stuff
var _spot_label: Label3D
var _spot_t := 0.0
var _spot_call := ""
var _spot_away := 0.0

## Hung up enough to need the winch: stopped, and bogged, dug in or on its belly.
func _hung_up(c: Dictionary) -> bool:
	if (c["v"] as Vector2).length() > 0.8 or c["rb"] or _dead(c):
		return false
	var clr: Array = c.get("clr", [-1.0, -1.0, -1.0])
	return float(c["stuck"]) > 0.6 or float(c["dig"]) > 0.08 or float(c["belly"]) > 0.3 or float(clr[0]) > -0.02

## The winch's hook: the middle of the bull bar.
func _bar(c: Dictionary) -> Vector3:
	var s: Dictionary = Utes.SPEC[c["name"]]
	var fwd := Vector2(sin(float(c["yaw"])), cos(float(c["yaw"])))
	var at := (c["pos"] as Vector2) + fwd * (float(s["L"]) * 0.5 - 0.15)
	return Vector3(at.x, float(c.get("y", 0.0)) + float(c.get("raise", 0.0)) + 0.55, at.y)

## A rope (a unit-long box) stretched from `a` to `b`.
func _rope(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var dir := d.normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(dir, up) * Basis.from_scale(Vector3(1, 1, d.length())), (a + b) * 0.5)

## Where the winch rope goes: the nearest big tree out in front, in reach;
## else a ground anchor dug in up ahead.
func _winch_anchor(c: Dictionary) -> Dictionary:
	var fwd := Vector2(sin(float(c["yaw"])), cos(float(c["yaw"])))
	var p: Vector2 = c["pos"]
	var best := {}
	var bd := INF
	if crash != null:
		for it in crash.near(p + fwd * WINCH_LINE * 0.5, WINCH_LINE * 0.5):
			if it["kind"] != "tree":
				continue
			var d := (it["p"] as Vector2) - p
			if d.length() < 6.0 or d.length() > WINCH_LINE or d.normalized().dot(fwd) < 0.8:
				continue
			if d.length() < bd:
				bd = d.length()
				best = {"p": it["p"], "tree": true}
	if best.is_empty():
		best = {"p": p + fwd * 18.0, "tree": false}
	return best

func _start_winch(c: Dictionary) -> void:
	var a := _winch_anchor(c)
	var ap: Vector2 = a["p"]
	var gy := floor_y(ap)
	var rope := F.box(Vector3(0.04, 0.04, 1.0), F.color_mat(Color("5a5550")), Vector3.ZERO, false)
	add_child(rope)
	var stake: Node3D = null
	if not a["tree"]:
		# (a ground anchor: a yellow stake driven in on an angle)
		stake = F.box(Vector3(0.1, 0.9, 0.1), F.color_mat(Color("e0b020"), true), Vector3(ap.x, gy + 0.25, ap.y))
		var fwd := Vector2(sin(float(c["yaw"])), cos(float(c["yaw"])))
		stake.rotation = Vector3(0.0, atan2(fwd.x, fwd.y), 0.0)
		stake.rotate_object_local(Vector3.RIGHT, 0.45)
		add_child(stake)
	_rec = {"kind": "winch", "t": 0.0, "p": ap, "y": gy + (0.9 if a["tree"] else 0.4), "rope": rope, "stake": stake}
	_toast_msg("Winching out to %s. Keep holding A; a touch of throttle helps." % ("that tree" if a["tree"] else "a ground anchor"))
	if _who != null:
		game.haptic(_who, "40,30,40")

## A mate in another ute backs up in front of `dir`, hooks a snatch strap on
## and takes off: the strap stretches and yanks you out the way you came.
func _start_strap(c: Dictionary, dir: Vector2) -> void:
	var nm: String = "Ranger" if c["name"] != "Ranger" else "Hilux"
	var mate := Utes.drivable(nm, Color("e9e6df"))
	add_child(mate)
	var gap := float(Utes.SPEC[c["name"]]["L"]) * 0.5 + float(Utes.SPEC[nm]["L"]) * 0.5 + 3.5
	var mp := (c["pos"] as Vector2) + dir * gap
	mate.position = Vector3(mp.x, floor_y(mp), mp.y)
	mate.basis = Basis(Vector3.UP, atan2(dir.x, dir.y))
	var m := F.color_mat(Color("ff8c1a"), true)
	var r1 := F.box(Vector3(0.07, 0.02, 1.0), m, Vector3.ZERO, false)
	var r2 := F.box(Vector3(0.07, 0.02, 1.0), m, Vector3.ZERO, false)
	add_child(r1)
	add_child(r2)
	_rec = {"kind": "strap", "t": 0.0, "dir": dir, "from": c["pos"], "mate": mate, "mate_l": float(Utes.SPEC[nm]["L"]),
		"mp": mp, "rope": r1, "rope2": r2, "done": false}
	_toast_msg("Bogged. Your mate's backed up with a snatch strap.")

func _end_rec() -> void:
	for k in ["rope", "rope2", "stake", "mate"]:
		var n = _rec.get(k)
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	_rec = {}
	_winch = 0.0

## The winch and the strap, each frame: true while one's moving the ute (so
## it isn't driving itself).
func _recover(c: Dictionary, hb: bool, gas: float, dt: float) -> bool:
	if _rec.is_empty() and hb and "winch" in (c["kit"] as Array) and _hung_up(c):
		_start_winch(c)
	if _rec.is_empty():
		return false
	_rec["t"] = float(_rec["t"]) + dt
	if _rec["kind"] == "strap":
		return _strap(c, dt)
	var anchor: Vector2 = _rec["p"]
	var hook := Vector3(anchor.x, float(_rec["y"]), anchor.y)
	if not hb:
		# (let go: the drum stops; drive off and the rope's packed away)
		_winch = maxf(0.0, _winch - dt * 4.0)
		_rec["idle"] = float(_rec.get("idle", 0.0)) + dt
		if float(_rec["idle"]) > 1.5 or (c["v"] as Vector2).length() > 2.0:
			_end_rec()
		else:
			_rope(_rec["rope"], _bar(c), hook)
		return false
	_rec["idle"] = 0.0
	var to := anchor - (c["pos"] as Vector2)
	if to.length() < 6.0:
		_toast_msg("Winched right up to it. Unhook and drive on.")
		_end_rec()
		return false
	var dir := to.normalized()
	var sp := WINCH_PULL * (1.0 + gas * 0.8)
	c["pos"] = (c["pos"] as Vector2) + dir * sp * dt
	c["v"] = dir * sp
	c["yaw_rate"] = 0.0
	# (the nose swings round to line up with the rope)
	var want := atan2(dir.x, dir.y)
	c["yaw"] = float(c["yaw"]) + clampf(wrapf(want - float(c["yaw"]), -PI, PI), -0.35 * dt, 0.35 * dt)
	c["dig"] = maxf(0.0, float(c["dig"]) - dt * 0.2)
	c["stuck"] = 0.0
	c["winched"] = true
	c["winching"] = true
	_winch = minf(1.0, _winch + dt * 5.0)
	_follow_ground(c, dt, false)
	_chassis(c, dt)
	c["winching"] = false
	c["spin"] = float(c["spin"]) + sp / float(Utes.SPEC[c["name"]]["r"]) * dt
	_rope(_rec["rope"], _bar(c), hook)
	_place_car(c, dt)
	_park_challenges(c, dt)
	_spotter(c, dt)
	return true

## The snatch: the mate creeps off to take up the slack, the strap stretches,
## and you come out with a jolt. Then they drive off and you owe them a carton.
func _strap(c: Dictionary, dt: float) -> bool:
	var t: float = _rec["t"]
	var dir: Vector2 = _rec["dir"]
	var mate: Node3D = _rec["mate"]
	var md := 1.5 * smoothstep(0.3, 1.6, t)
	if t > 1.6:
		md = 1.5 + 3.5 * (1.0 - pow(1.0 - clampf((t - 1.6) / 0.8, 0.0, 1.0), 3.0))
	if t > 2.4:
		md = 5.0 + (t - 2.4) * (1.5 + (t - 2.4) * 1.2)
	var mp: Vector2 = (_rec["mp"] as Vector2) + dir * md
	mate.position = Vector3(mp.x, floor_y(mp), mp.y)
	if t > 9.0:
		_end_rec()
		return false
	if t > 2.4:
		if not _rec["done"]:
			_rec["done"] = true
			(_rec["rope"] as Node3D).visible = false
			(_rec["rope2"] as Node3D).visible = false
			c["rescued"] = true
			c["dug"] = false
			c["dig"] = 0.0
			c["stuck"] = 0.0
			c["v"] = dir * 1.0
			var paid := _char() != "" and Wallet.cash(_char()) >= CARTON
			if paid:
				Wallet.pay(_char(), -CARTON)
				Wallet.save()
			_toast_msg("Out! That's a carton you owe your mate%s." % (" (%s)" % Wallet.money(CARTON) if paid else ""))
			_hint(c, "nowinch", "A bull bar and winch from the 4x4 shop and you'd get yourself out.")
		return false
	# (you, dragged out the way you came)
	var k := 0.0
	if t > 1.6:
		k = 1.0 - pow(1.0 - (t - 1.6) / 0.8, 3.0)
	c["pos"] = (_rec["from"] as Vector2) + dir * 3.5 * k
	c["v"] = Vector2.ZERO
	c["dig"] = maxf(0.0, float(c["dig"]) - dt * 0.3)
	if t > 1.6 and not _rec.has("jolt"):
		_rec["jolt"] = true
		_thud = 0.6
		_shake = maxf(_shake, 0.25)
		if _who != null:
			game.haptic(_who, "80")
	_follow_ground(c, dt, false)
	_place_car(c, dt)
	var s: Dictionary = Utes.SPEC[c["name"]]
	var mine := (c["pos"] as Vector2) + dir * float(s["L"]) * 0.5
	var theirs := mp - dir * float(_rec["mate_l"]) * 0.5
	var a := Vector3(mine.x, float(c.get("y", 0.0)) + 0.45, mine.y)
	var b := Vector3(theirs.x, floor_y(theirs) + 0.45, theirs.y)
	# (slack on the ground, then tight)
	var mid := (a + b) * 0.5 + Vector3.DOWN * 0.4 * (1.0 - smoothstep(0.2, 1.6, t))
	_rope(_rec["rope"], a, mid)
	_rope(_rec["rope2"], mid, b)
	return true

## A mate walks out in front on the hill, the logs and the moguls, and calls
## you over it: what's touching, which wheel's in the air, when to stop.
func _spotter(c: Dictionary, dt: float) -> void:
	var yaw: float = c["yaw"]
	var fwd := Vector2(sin(yaw), cos(yaw))
	var left := Vector2(fwd.y, -fwd.x)
	var p: Vector2 = c["pos"]
	var s: Dictionary = Utes.SPEC[c["name"]]
	# (in it, or with the bull bar up against it)
	var ahead: String = park.challenge(p + fwd * (float(s["L"]) * 0.5 + 2.0))
	var want: bool = (_park_in in SPOT_AT or ahead in SPOT_AT) and not _dead(c)
	_spot_away = 0.0 if want else _spot_away + dt
	var tp := p + fwd * (float(s["L"]) * 0.5 + 5.0) + left * 0.6
	if _rec.get("kind", "") == "winch":
		# (well off to the side of a loaded winch rope)
		tp = p + fwd * (float(s["L"]) * 0.5 + 1.5) + left * 4.5
	if _spot == null:
		if not want or (c["v"] as Vector2).length() > 4.5:
			return
		_spot = Node3D.new()
		_spot.name = "Spotter"
		add_child(_spot)
		var body := F.chibi(Color("ff7a1a"), Color("f4f4f0"))
		body.name = "Body"
		_spot.add_child(body)
		_spot_label = F.label3d("", 34, UI.GOLD)
		_spot_label.position.y = 2.25
		_spot.add_child(_spot_label)
		_spot.position = Vector3(tp.x, floor_y(tp), tp.y)
		_spot_call = ""
		_spot_t = 0.0
	if _spot_away > 2.0:
		_drop_spotter()
		return
	# (walks backwards out in front, keeping clear of the bull bar)
	var cur := Vector2(_spot.position.x, _spot.position.z)
	cur = cur.move_toward(tp, dt * 3.2)
	_spot.position = Vector3(cur.x, floor_y(cur), cur.y)
	var face := p - cur
	_spot.rotation.y = atan2(face.x, face.y)
	_spot_t -= dt
	if _spot_t <= 0.0:
		_spot_t = 0.6
		var clr: Array = c.get("clr", [-1.0, -1.0, -1.0])
		var vf := (c["v"] as Vector2).dot(fwd)
		var lift: Array = c["lift"]
		var call := "Keep coming... keep coming"
		var pose := "come"
		if _rec.get("kind", "") == "winch":
			call = "Steady on the winch... she's coming"
			pose = "slow"
		elif float(c["dig"]) > 0.08:
			call = "You're digging in! Back up, then go again"
			pose = "back"
		elif float(clr[0]) > -0.03 and vf > -0.1:
			call = "STOP! Your bumper's on it. Back up, take it on an angle"
			pose = "stop"
		elif float(clr[2]) > -0.02:
			call = "Easy! You're on your belly"
			pose = "stop"
		elif float(clr[1]) > -0.02:
			call = "Watch your tow bar!"
			pose = "slow"
		elif lift.has(true):
			call = "%s's in the air. Slow, keep it slow" % ["Front left", "Front right", "Back left", "Back right"][lift.find(true)]
			pose = "slow"
		elif (c["v"] as Vector2).length() > 2.8:
			call = "Too quick! Slow it right down"
			pose = "slow"
		elif absf(vf) < 0.2:
			call = "Come to me"
		if call != _spot_call:
			_spot_call = call
			_spot_label.text = call
			if _demo:
				print("[explore] spotter: " + call)
		_spot.set_meta("pose", pose)
	# (the hand signals)
	var body := _spot.get_node("Body") as Node3D
	var al := body.get_node("ArmL") as Node3D
	var ar := body.get_node("ArmR") as Node3D
	var w := sin(_t * 7.0)
	match String(_spot.get_meta("pose", "come")):
		"stop":
			al.rotation.z = -2.8
			ar.rotation.z = 2.8
		"slow":
			al.rotation.z = -1.35 + w * 0.25
			ar.rotation.z = 1.35 - w * 0.25
		"back":
			al.rotation.z = -0.25
			ar.rotation.z = 1.6 + w * 0.5
		_:
			al.rotation.z = -0.25
			ar.rotation.z = 2.3 + w * 0.45

func _drop_spotter() -> void:
	if _spot != null:
		_spot.queue_free()
	_spot = null
	_spot_away = 0.0

# ------------------------------------------------------------------ 4x4

## Gone for good: written off, or drowned.
func _dead(c: Dictionary) -> bool:
	return float(c["dmg"]) >= 1.0 or bool(c.get("drowned", false))

## A ute's 4x4 state, fresh off the kerb with this kit on (offroad.gd).
func _offroad(c: Dictionary, kit: Array) -> void:
	var o := Offroad.setup(c["name"], kit, float((c["node"] as Node3D).get_meta("ride", 0.0)))
	c["kit"] = kit
	c["off"] = o
	c["drive"] = (o["modes"] as Array)[0]
	c["psi"] = Offroad.PSI_ROAD
	c["dig"] = 0.0
	c["flat"] = ""
	c["heat"] = 0.0
	c["drowned"] = false
	c["lift"] = [false, false, false, false]
	c["woff"] = [0.0, 0.0, 0.0, 0.0]
	c["raise"] = 0.0
	c["belly"] = 0.0
	c["slip"] = 0.0
	c["hints"] = {}
	var wy := []
	for w in ["FL", "FR", "RL", "RR"]:
		wy.append((c["node"].get_node(w) as Node3D).position.y)
	c["wy0"] = wy

## A tip on screen, at most every half a minute for each kind.
func _hint(c: Dictionary, key: String, text: String) -> void:
	if c.get("winching", false):
		return
	if not is_same(c, car):
		return
	var h: Dictionary = c["hints"]
	if _t - float(h.get(key, -999.0)) < 30.0:
		return
	h[key] = _t
	_toast_msg(text)

## Y tapped: on to the next of 2H, 4H, 4L, 4L with the rear locker in
## (the Shark: AWD, then its MUD mode). Into or out of low range only at a
## crawl, as in the real thing.
func _shift_drive(c: Dictionary, spd: float) -> void:
	var modes: Array = c["off"]["modes"]
	var now: String = c["drive"]
	_drive_to(c, modes[(modes.find(now) + 1) % modes.size()], spd)

## Into another drive (2H, 4H, 4L, 4L+LOCK; AWD, MUD): low range only at a crawl.
func _drive_to(c: Dictionary, to: String, spd: float) -> void:
	var now: String = c["drive"]
	if to == now:
		return
	if (to.begins_with("4L") != now.begins_with("4L")) and spd > 2.0:
		_toast_msg("Stop first to shift %s low range." % ("into" if to.begins_with("4L") else "out of"))
		return
	c["drive"] = to
	_thud = maxf(_thud, 0.25)
	_toast_msg({"2H": "2H: back wheels only.", "4H": "4H: all four wheels driving.",
		"4L": "4L: low range. Crawl it.", "4L+LOCK": "Rear diff locked: both back wheels turn together.",
		"AWD": "AWD: normal.", "MUD": "MUD mode: grabs a spinning wheel."}[to])

## Y held at a stop: let the tyres down, or pump them back up (only at an
## air station: there's no compressor in the tub).
func _start_air(c: Dictionary) -> void:
	var psi: float = c["psi"]
	if psi > Offroad.PSI_LOW + 1.0:
		c["air_job"] = Offroad.PSI_LOW
		_toast_msg("Letting the tyres down to %d psi..." % int(Offroad.PSI_LOW))
	elif park != null and park.air_near(c["pos"]):
		c["air_job"] = Offroad.PSI_ROAD
		_toast_msg("Pumping the tyres back up to %d psi..." % int(Offroad.PSI_ROAD))
	else:
		_toast_msg("Tyres are down. Pump them up at the FREE AIR post by the park gate.")

func _tyre_job(c: Dictionary, spd: float, dt: float) -> void:
	if not c.has("air_job"):
		_hiss = maxf(0.0, _hiss - dt * 3.0)
		return
	var to: float = c["air_job"]
	if spd > 0.8:
		c.erase("air_job")
		_toast_msg("Tyres at %d psi." % roundi(float(c["psi"])))
		return
	var psi: float = c["psi"]
	psi = move_toward(psi, to, dt * (5.0 if to < psi else 3.5))
	c["psi"] = psi
	_hiss = 0.6
	if is_equal_approx(psi, to):
		c.erase("air_job")
		if to >= Offroad.PSI_ROAD:
			c["flat"] = ""
			c["heat"] = 0.0
		_toast_msg("Tyres at %d psi. %s" % [roundi(to), "Soft sand's no worry now." if to < 25.0 else "Good for the road."])

## The chassis on its four springs: each wheel follows the ground under it as
## far as it can travel, the body rides on the plane between them, and where
## the ground comes up past a bumper, the belly or a diff, it hits.
func _chassis(c: Dictionary, dt: float) -> void:
	if park == null:
		return
	var o: Dictionary = c["off"]
	var s: Dictionary = Utes.SPEC[c["name"]]
	var yaw: float = c["yaw"]
	var fwd := Vector2(sin(yaw), cos(yaw))
	var left := Vector2(fwd.y, -fwd.x)
	var p: Vector2 = c["pos"]
	var zf: float = float(s["L"]) * 0.5 - float(s["front"])
	var zr: float = zf - float(s["wb"])
	var tw: float = float(s["track"]) * 0.5
	var g := [park.height(p + fwd * zf + left * tw), park.height(p + fwd * zf - left * tw),
		park.height(p + fwd * zr + left * tw), park.height(p + fwd * zr - left * tw)]
	var front := (float(g[0]) + float(g[1])) * 0.5
	var rear := (float(g[2]) + float(g[3])) * 0.5
	var B := (front - rear) / float(s["wb"])
	var A := rear - B * zr
	var C := ((float(g[0]) + float(g[2])) - (float(g[1]) + float(g[3]))) / (4.0 * tw)
	# (twisted across a diagonal: two wheels up into the arches, two hanging)
	var e := (float(g[0]) - float(g[1]) - float(g[2]) + float(g[3])) * 0.25
	var want := [e, -e, -e, e]
	var travel := [o["travel_f"], o["travel_f"], o["travel_r"], o["travel_r"]]
	var up := 0.0
	for i in 4:
		up = maxf(up, float(want[i]) - float(travel[i]))
	# --- what's under it: the ground against the bumpers, belly and diffs
	var hw: float = float(s["hw"]) * 0.7
	var plane := func(z: float, lat: float) -> float: return A + B * z + C * lat
	var under := func(z: float, lat: float) -> float:
		return park.height(p + fwd * z + left * lat) - float(plane.call(z, lat)) - up
	var nose := -INF
	var tail := -INF
	for lat in [0.0, hw, -hw]:
		nose = maxf(nose, float(under.call(zf + float(o["front_oh"]), lat)) - float(o["nose"]))
		tail = maxf(tail, float(under.call(zr - float(o["rear_oh"]), lat)) - float(o["tail"]))
	var belly := maxf(float(under.call((zf + zr) * 0.5, 0.0)) - float(o["belly"]),
		maxf(float(under.call(zf, 0.0)), float(under.call(zr, 0.0))) - float(o["diff"]))
	var air: bool = c.get("air", false)
	if air:
		nose = -1.0
		tail = -1.0
		belly = -1.0
	c["clr"] = [nose, tail, belly]
	# (sat on its belly: the wheels hang off it)
	var perch := maxf(belly, 0.0)
	up += perch
	var lift := [false, false, false, false]
	var woff: Array = c["woff"]
	for i in 4:
		var t: float = travel[i]
		var to := -t if air else clampf(float(want[i]) - up, -t, t)
		lift[i] = air or float(want[i]) - up < -t - 0.02
		woff[i] = lerpf(float(woff[i]), to, 1.0 - exp(-dt * (8.0 if air else 22.0)))
	c["lift"] = lift
	c["raise"] = lerpf(float(c["raise"]), up, 1.0 - exp(-dt * 14.0))
	c["belly"] = clampf(perch / 0.1, 0.0, 0.95)
	if air:
		return
	var v: Vector2 = c["v"]
	var vf := v.dot(fwd)
	var scrape := 0.0
	# --- the front bumper into a face steeper than it clears
	if nose > 0.0 and vf > 0.2:
		if nose > 0.08 and not c.get("winching", false):
			c["pos"] = c["pos_prev"]
			if vf > 3.0:
				_impact(c, p + fwd * (zf + float(o["front_oh"])), -fwd, vf * 0.8, "ground", {})
			v -= fwd * vf
			vf = 0.0
			c["dug"] = true
			_hint(c, "nose", "Bumper's dug in: that's steeper than your approach angle. Back off and take it on an angle.")
		else:
			vf = maxf(0.0, vf - (2.0 + nose * 60.0) * dt)
			v = fwd * vf + left * v.dot(left)
		scrape = maxf(scrape, 0.6)
	# --- the tow bar dragging (backing into it, it stops you)
	if tail > 0.0 and absf(vf) > 0.2:
		if tail > 0.08 and vf < 0.0:
			c["pos"] = c["pos_prev"]
			v -= fwd * vf
			vf = 0.0
		else:
			vf = move_toward(vf, 0.0, (2.0 + tail * 50.0) * dt)
			v = fwd * vf + left * v.dot(left)
		scrape = maxf(scrape, 0.5)
		_hint(c, "tail", "Tow bar's dragging. That's your departure angle.")
	# --- high-centred: the belly on the crest carries the weight
	if belly > 0.0:
		if absf(vf) > 0.3:
			vf = move_toward(vf, 0.0, (2.5 + belly * 30.0) * dt)
			v = fwd * vf + left * v.dot(left)
			scrape = maxf(scrape, 0.8)
		if belly > 0.05:
			_hint(c, "belly", "High-centred! Belly's on the crest. Rock it back, or come at it with more speed.")
	c["v"] = v
	if scrape > 0.0 and is_same(c, car):
		if _scrape < 0.05 and _who != null:
			game.haptic(_who, "60")
		_scrape = maxf(_scrape, scrape)
		if randf() < dt * 14.0:
			var at := p + fwd * (zf + float(o["front_oh"]) if nose > 0.0 else (zr - float(o["rear_oh"]) if tail > 0.0 else (zf + zr) * 0.5))
			_debris(Vector3(at.x, float(c.get("y", 0.0)) + 0.15, at.y), Vector3(-fwd.x, 0.5, -fwd.y), 3.0, Color("8a6a48"), true)

## Each frame on the dirt: digging in, the tyres cooking, the water rising up
## the intake, and the tips that teach it.
func _offroad_tick(c: Dictionary, surf: String, gas: float, dt: float) -> void:
	var o: Dictionary = c["off"]
	var slip: float = c["slip"]
	var spd := (c["v"] as Vector2).length()
	var dig: float = c["dig"]
	var fwd := Vector2(sin(float(c["yaw"])), cos(float(c["yaw"])))
	var vf := (c["v"] as Vector2).dot(fwd)
	if surf in ["mud", "sand"]:
		if slip > 0.2 and spd < 1.5:
			# (spinning on the spot: the tyres dig their own holes)
			dig = minf(0.28, dig + dt * (0.11 if surf == "mud" else 0.06) * slip)
		elif vf < -0.3:
			# (rocking it: back out of the holes)
			dig = maxf(0.0, dig - dt * 0.25)
		elif spd > 0.5:
			dig = maxf(0.0, dig - dt * 0.1)
		elif slip < 0.2:
			dig = maxf(0.0, dig - dt * 0.06)
	else:
		dig = maxf(0.0, dig - dt * 0.5)
	c["dig"] = dig
	var off_road := surf in ["mud", "sand", "dirt", "grass", "water"]
	var drive: String = c["drive"]
	if slip > 0.3 and off_road:
		var lifted := (c["lift"] as Array).has(true)
		if drive == "2H":
			_hint(c, "2h", "Back wheels spinning. Tap Y for 4WD.")
		elif lifted and drive != "4L+LOCK" and c["name"] != "Shark":
			_hint(c, "lock", "A wheel's in the air, spinning. Tap Y to 4L and the rear locker.")
		elif lifted and c["name"] == "Shark":
			_hint(c, "lock", "A wheel's in the air. Tap Y for MUD mode.")
		elif surf == "sand" and float(c["psi"]) > 30.0:
			_hint(c, "sand", "Soft sand. Stop and hold Y to let the tyres down.")
	if dig > 0.12:
		_hint(c, "dig", "Digging in! Ease off and rock it: back, then forward.")
	# --- aired down at speed, the tyres heat up and one rolls off the rim
	if float(c["psi"]) < 30.0 and spd * 3.6 > Offroad.LOW_SAFE:
		c["heat"] = float(c["heat"]) + dt
		_hint(c, "heat", "Tyres are aired down. Keep it under %d or you'll roll one off the rim." % int(Offroad.LOW_SAFE))
		if float(c["heat"]) > Offroad.BEAD and c["flat"] == "":
			c["flat"] = ["FL", "FR", "RL", "RR"][randi() % 4]
			c["psi"] = minf(float(c["psi"]), Offroad.PSI_LOW)
			_thud = 1.0
			_shake = maxf(_shake, 0.4)
			_toast_msg("Rolled a tyre off the rim! Limp it to the FREE AIR post.")
			if _who != null:
				game.haptic(_who, "120")
	else:
		c["heat"] = maxf(0.0, float(c["heat"]) - dt * 0.3)
	# --- wading: water up the air intake drowns the engine
	if park != null and not _dead(c):
		var s: Dictionary = Utes.SPEC[c["name"]]
		var pf: Vector2 = (c["pos"] as Vector2) + fwd * (float(s["L"]) * 0.5 - float(s["front"]))
		var wl: float = park.water(pf)
		if wl > -90.0:
			var deep: float = wl - park.height(pf)
			# (a steady walking pace pushes a bow wave that keeps the engine bay
			# low; too fast and it comes over the bonnet)
			# (and it can only throw so much: the creek's causeways are shallow
			# enough for a stock ute at any speed; the dam's deep end isn't)
			var bow := 0.0
			if spd > 2.8:
				bow = minf(0.012 * (spd - 2.8) * (spd - 2.8), 0.22)
			elif spd > 1.0:
				bow = -0.06
			var at := deep + bow
			var wade := float(o["wade"]) + float((c["node"] as Node3D).get_meta("ride", 0.0))
			if at > wade - 0.15:
				_hint(c, "deep", "Water's nearly at the air intake! Walking pace, steady bow wave.")
			if at > wade and gas > 0.05:
				c["drowned"] = true
				c["rpm"] = 0.0
				_thud = 1.0
				_shake = maxf(_shake, 0.5)
				var n: Node3D = c["node"]
				_puff(n.global_position + Vector3(0, 1.3, 0) + n.global_basis.z * 1.6, Color(0.9, 0.92, 0.95, 0.4), 0.5, 2.5)
				if _who != null:
					game.haptic(_who, "90,60,90")
				_toast_msg("Hydrolocked! Water up the intake. %s" % ("" if "snorkel" in c["kit"] else "A snorkel would've saved it."))

## Moves a ute along by its velocity. Buildings, the other cars, poles and
## big trees stop it (with a dent to show for it); signs, bins and small
## plants go flat; birds and people in the way come off second best.
func _move_car(c: Dictionary, dt: float) -> void:
	var v: Vector2 = c["v"]
	var at: Vector2 = c["pos"]
	var yaw: float = c["yaw"]
	var to := at + v * dt
	var hit := _car_block(c, to, yaw, v.length(), v)
	if hit.is_empty():
		c["pos"] = to
	else:
		var n: Vector2 = hit["n"]
		var vn := v.dot(n)
		if vn < 0.0:
			var imp := -vn
			v -= n * vn * 1.3
			v *= 0.9
			# (hit off-centre, it slews round)
			var r: Vector2 = (hit["p"] as Vector2) - at
			c["yaw_rate"] = float(c["yaw_rate"]) * 0.5 + clampf((r.x * n.y - r.y * n.x) * imp * 0.06, -2.5, 2.5)
			c["v"] = v
			_impact(c, hit["p"], n, imp, hit["what"], hit.get("it", {}))
			if imp > 13.0 and mode == "drive" and is_same(c, car):
				# hard enough to throw it about: up it goes, round where it hit
				var r3 := Vector3(r.x, -0.25, r.y)
				var j3 := Vector3(n.x, 0, n.y) * imp
				_launch(c, Vector3(v.x, 1.2 + imp * 0.1, v.y), (r3.cross(j3) * 0.22).limit_length(5.5))
				return
		c["v"] = v
		if not _car_block(c, at, yaw, 0.0, Vector2.ZERO).is_empty():
			_unstick(c, false)
	var speed := (c["v"] as Vector2).length()
	if speed > 1.5 and crash != null:
		var half := _half(c["name"])
		for w in crash.birds_in(c["pos"], half, yaw):
			crash.squash(w, c["v"])
			if _hit_cd <= 0.0:
				_toast_msg(["Road kill.", "Sorry, little fella.", "That's a %s gone." % String(w["kind"]).to_lower()][randi() % 3])
				_hit_cd = 2.0
		if speed > 2.5:
			for w in crash.people_in(c["pos"], half, yaw):
				var side := Vector2(-v.y, v.x).normalized() * randf_range(-2.0, 2.0)
				crash.bowl(w, c["v"] * 1.05 + side)
				c["v"] = (c["v"] as Vector2) * 0.92
				_impact(c, (c["pos"] as Vector2) + (c["v"] as Vector2).normalized() * _half(c["name"]).y, -(c["v"] as Vector2).normalized(),
					speed * 0.25, "person", {})
				_toast_msg(("Ooft! Knocked a cyclist off." if w["kind"] == "bike" else "Ooft! Sorry, mate!"))
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
				var into := (vv - their).dot(-away)
				if into > 0.0:
					vv += away * into * 1.4
					if into > 3.0:
						_impact(c, (c["pos"] as Vector2) - away * me_half.x, away, into, "car", {})
				c["v"] = vv + their * 0.3 * dt * 10.0

## What a ute at `at` facing `yaw` is up against: {} if nothing, else where
## ("p"), the way out ("n") and what ("what", and the "it" from crash.gd).
## Moving at `speed` (along `v`), it flattens what's flattenable as it goes.
func _car_block(c: Dictionary, at: Vector2, yaw: float, speed: float, v: Vector2) -> Dictionary:
	var half := _half(c["name"])
	var fwd := Vector2(sin(yaw), cos(yaw))
	var left := Vector2(fwd.y, -fwd.x)
	for k in [[1, 1], [-1, 1], [0, 1], [1, -1], [-1, -1], [0, -1], [1, 0], [-1, 0], [1, 0.5], [-1, 0.5], [1, -0.5], [-1, -0.5]]:
		var q: Vector2 = at + left * half.x * float(k[0]) + fwd * half.y * float(k[1])
		if _blocked(q):
			return {"p": q, "n": _wall_normal(q, at), "what": "wall"}
		if not _ferry_floor(q).is_empty():
			# (no utes on the terminal)
			return {"p": q, "n": (at - q).normalized(), "what": "wall"}
	for o in utes:
		if not is_same(o, c) and not o["rb"] and _boxes_touch(at, yaw, half, o["pos"], o["yaw"], _half(o["name"])):
			return {"p": at.lerp(o["pos"], 0.5), "n": (at - (o["pos"] as Vector2)).normalized(), "what": "car"}
	if traffic != null:
		for it in traffic.parked:
			if String(it[0]) == "":
				continue
			var t: Transform3D = it[1]
			var o := Vector2(t.origin.x, t.origin.z)
			if o.distance_squared_to(at) < 49.0:
				var oy := atan2(t.basis.z.x, t.basis.z.z)
				if _boxes_touch(at, yaw, half, o, oy, Cars.SIZE.get(it[0], Vector2(0.9, 2.35))):
					return {"p": at.lerp(o, 0.5), "n": (at - o).normalized(), "what": "car"}
	if crash != null:
		for it in crash.near(at, half.y + 0.5):
			if not _in_box(it["p"], at, yaw, half, float(it["r"])):
				continue
			match it["kind"]:
				"flat", "plant":
					crash.knock(it, v)
					c["v"] = (c["v"] as Vector2) * (0.97 if it["kind"] == "plant" else 0.93)
					if speed > 3.0 and it["kind"] == "flat":
						_impact(c, it["p"], (at - (it["p"] as Vector2)).normalized(), speed * 0.2, "sign", {})
					if _hit_cd <= 0.0 and it["kind"] == "flat":
						_toast_msg({"StreetSign": "Flattened the street sign.", "GiveWaySign": "Didn't give way.",
							"BusStopSign": "No more bus stop.", "ParkBin": "Bin night.", "ParkBench": "Took out a bench.",
							"PicnicTable": "Picnic's off.", "Bubbler": "Bubbler's gone."}.get(it["model"], "Flattened it."))
						_hit_cd = 1.5
				"pole":
					if speed > 9.0:
						crash.knock(it, v)
						c["v"] = (c["v"] as Vector2) * 0.7
						_impact(c, it["p"], (at - (it["p"] as Vector2)).normalized(), speed * 0.45, "pole", {})
						_toast_msg("Took the light pole with it.")
					else:
						return {"p": it["p"], "n": (at - (it["p"] as Vector2)).normalized(), "what": "pole", "it": it}
				_:
					return {"p": it["p"], "n": (at - (it["p"] as Vector2)).normalized(), "what": it["kind"], "it": it}
	return {}

## Which way's out of a building from a point inside its wall, towards `from`.
func _wall_normal(q: Vector2, from: Vector2) -> Vector2:
	var n := Vector2.ZERO
	for k in 16:
		var d := Vector2.from_angle(k * TAU / 16.0)
		for reach in [0.6, 1.5, 3.0]:
			if not _in_building(q + d * reach):
				n += d / reach
				break
	if n == Vector2.ZERO:
		return (from - q).normalized()
	return n.normalized()

## Clear of whatever it's in: the nearest free spot round about.
func _unstick(c: Dictionary, say: bool) -> void:
	var at: Vector2 = c["pos"]
	var yaw: float = c["yaw"]
	for ring in range(1, 16):
		var reach := ring * 0.5
		for k in 12:
			var q := at + Vector2.from_angle(k * TAU / 12.0) * reach
			if _car_block(c, q, yaw, 0.0, Vector2.ZERO).is_empty() and not _is_wet(q):
				c["pos"] = q
				c["v"] = Vector2.ZERO
				if say:
					_toast_msg("Rocked it free.")
				return
	_road_reset(c)

## Back on the nearest bit of road, facing along it.
func _road_reset(c: Dictionary) -> void:
	var at: Vector2 = c["pos"]
	var best := Vector2.ZERO
	var dir := Vector2(0, 1)
	var bd := INF
	for r in _d["roads"]:
		var pts: Array = r["pts"]
		for i in range(1, pts.size()):
			var a := Vector2(pts[i - 1][0], pts[i - 1][1])
			var b := Vector2(pts[i][0], pts[i][1])
			var q := Geometry2D.get_closest_point_to_segment(at, a, b)
			var dd := q.distance_to(at)
			if dd < bd and q.length() < EDGE:
				bd = dd
				best = q
				dir = (b - a).normalized()
	c["pos"] = best + Vector2(dir.y, -dir.x) * 1.8
	c["yaw"] = atan2(dir.x, dir.y)
	c["v"] = Vector2.ZERO
	c["yaw_rate"] = 0.0
	if _car_block(c, c["pos"], c["yaw"], 0.0, Vector2.ZERO).is_empty():
		return
	c["pos"] = best

## A ute hit something `imp` m/s hard at `p` (the way out `n`): a dent there,
## bits everywhere, and the damage adding up till it won't go.
func _impact(c: Dictionary, p: Vector2, n: Vector2, imp: float, what: String, it: Dictionary) -> void:
	if what == "tree" and not it.is_empty():
		crash.shake(it, imp)
	if _demo:
		print("[explore] hit %s %s at %.1f m/s" % [what, it.get("model", ""), imp])
	if imp < 1.5:
		return
	var node: Node3D = c["node"]
	var shell := node.get_node("Body/Shell") as MeshInstance3D
	var hit3 := to_global(Vector3(p.x, 0.75 + float(c.get("y", 0.0)), p.y))
	var local := shell.global_transform.affine_inverse() * hit3
	var front := local.z > float(Utes.SPEC[c["name"]]["L"]) * 0.25
	var bar := 0.35 if front and node.get_node_or_null("Body/bullbar") != null else 1.0
	var was: float = c["dmg"]
	var amount := pow(clampf((imp - 2.0) / 28.0, 0.0, 1.2), 1.3) * 0.85 * bar
	c["dmg"] = minf(1.0, was + amount)
	var dir := (shell.global_transform.basis.inverse() * Vector3(n.x, 0, n.y)).normalized()
	if imp > 2.5:
		Utes.dent(shell, local, dir, clampf(imp * 0.012, 0.02, 0.28) * bar, 0.45 + imp * 0.025)
	if imp > 7.0:
		var best := "FL"
		var bd := INF
		for w in ["FL", "FR", "RL", "RR"]:
			var wl := (node.get_node(w) as Node3D).position
			var dd := Vector2(wl.x, wl.z).distance_to(Vector2(local.x, local.z))
			if dd < bd:
				bd = dd
				best = w
		var bent: Dictionary = c["bent"]
		bent[best] = minf(0.35, float(bent[best]) + amount * 0.6)
	_debris(hit3, Vector3(n.x, 0.4, n.y), imp, Utes.OWN_PAINT.get(c["name"], Color.WHITE) if c.get("paint") == null else c["paint"],
		what in ["wall", "pole", "solid", "car"])
	if is_same(c, car):
		_shake = maxf(_shake, minf(1.0, imp * 0.05))
		_thud = maxf(_thud, clampf(imp / 15.0, 0.3, 1.0))
	var now: float = c["dmg"]
	if is_same(c, car):
		if was < 0.4 and now >= 0.4:
			_toast_msg("Steam out the bonnet.")
		elif was < 0.75 and now >= 0.75:
			_toast_msg("She's not well. Black smoke.")
		elif was < 1.0 and now >= 1.0:
			_toast_msg("That's it, she's cactus.")

## Bits of plastic, glass and paint off a hit, and sparks off metal.
func _debris(at: Vector3, out: Vector3, imp: float, paint: Color, sparks: bool) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = clampi(int(imp * 2.0), 6, 40)
	p.lifetime = 1.6
	p.explosiveness = 0.95
	p.direction = out.normalized()
	p.spread = 60.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 2.0 + imp * 0.3
	p.gravity = Vector3(0, -14, 0)
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.02, 0.05)
	bm.material = F.color_mat(paint, false)
	p.mesh = bm
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1))
	g.set_color(1, Color(0.6, 0.65, 0.7))
	p.color_ramp = g
	p.position = to_local(at)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0, true, false, true).timeout.connect(p.queue_free)
	if not sparks or imp < 6.0:
		return
	var s := CPUParticles3D.new()
	s.one_shot = true
	s.amount = clampi(int(imp * 1.5), 8, 30)
	s.lifetime = 0.45
	s.explosiveness = 1.0
	s.direction = out.normalized()
	s.spread = 80.0
	s.initial_velocity_min = 3.0
	s.initial_velocity_max = 8.0
	s.gravity = Vector3(0, -9, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.025
	sm.height = 0.05
	sm.material = F.flat_mat(Color(1.0, 0.82, 0.35))
	s.mesh = sm
	s.position = to_local(at)
	add_child(s)
	s.emitting = true
	get_tree().create_timer(0.8, true, false, true).timeout.connect(s.queue_free)

## Steam, then black smoke, out from under the bonnet as it gets worse.
func _damage_fx(c: Dictionary, dt: float) -> void:
	var dmg: float = c["dmg"]
	if dmg < 0.4:
		return
	c["smoke_t"] = float(c["smoke_t"]) - dt
	if float(c["smoke_t"]) > 0.0 or _smoke.size() > 50:
		return
	c["smoke_t"] = lerpf(0.22, 0.08, dmg)
	var n: Node3D = c["node"]
	var s: Dictionary = Utes.SPEC[c["name"]]
	var at := n.to_global(Vector3(randf_range(-0.3, 0.3), 1.15, float(s["L"]) * 0.5 - 0.7))
	var col := Color(0.92, 0.93, 0.93, 0.28).lerp(Color(0.12, 0.12, 0.13, 0.6), clampf((dmg - 0.6) / 0.4, 0.0, 1.0))
	_puff(at, col, 0.16 + dmg * 0.14, 1.4 + dmg)

func _puff(at: Vector3, col: Color, size: float, life: float) -> void:
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	s.mesh = sm
	# (see-through and lit, so a run of them reads as a plume, not a blob)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	s.material_override = m
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	s.global_position = at
	_smoke.append(s)
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector3.ONE * 2.4, life)
	tw.tween_property(s, "position:y", s.position.y + 2.5, life)
	tw.tween_property(s, "transparency", 1.0, life)
	tw.chain().tween_callback(func():
		_smoke.erase(s)
		s.queue_free())

# ------------------------------------------------------------------ thrown about

## Off its wheels: from here it's a box with mass, bouncing and rolling till
## it comes to rest, then back on its wheels to drive on (righted for you if
## it ends up on its side or its roof).
func _launch(c: Dictionary, v3: Vector3, w: Vector3) -> void:
	if c["rb"]:
		return
	c["rb"] = true
	var B := Basis(Vector3.UP, float(c["yaw"])) * Basis.from_euler(Vector3(-float(c.get("gp", 0.0)), 0, float(c.get("gr", 0.0)))) \
		* Basis.from_euler(Vector3(float(c["pitch"]), 0, float(c["roll"])))
	c["B"] = B
	c["P"] = Vector3(c["pos"].x, COM_H + float(c.get("y", 0.0)), c["pos"].y)
	c["V"] = v3
	c["W"] = w
	c["rest"] = 0.0
	c["right_t"] = -1.0
	c["air"] = false
	c["gp"] = 0.0
	c["gr"] = 0.0
	c["pitch"] = 0.0
	c["roll"] = 0.0
	c["pv"] = 0.0
	c["rv"] = 0.0
	(c["node"] as Node3D).get_node("Body").rotation = Vector3.ZERO

func _tumble(c: Dictionary, dt: float) -> void:
	var s: Dictionary = Utes.SPEC[c["name"]]
	var mass: float = Utes.ENGINE[c["name"]]["mass"]
	var hw: float = s["hw"]
	var hl: float = float(s["L"]) * 0.5
	var ib := Vector3(mass / 12.0 * (1.85 * 1.85 + 4.0 * hl * hl), mass / 12.0 * (4.0 * hw * hw + 4.0 * hl * hl),
		mass / 12.0 * (4.0 * hw * hw + 1.85 * 1.85))
	var B: Basis = c["B"]
	var P: Vector3 = c["P"]
	var V: Vector3 = c["V"]
	var W: Vector3 = c["W"]
	var bottom := 0.05 - COM_H
	var top := 1.85 - COM_H
	var wheels_down := 0
	var biggest := 0.0
	var big_at := Vector3.ZERO
	var big_n := Vector3.UP
	if float(c["right_t"]) >= 0.0:
		# righting it: back over onto its wheels
		c["right_t"] = float(c["right_t"]) + dt
		var u := clampf(float(c["right_t"]) / 0.8, 0.0, 1.0)
		var up := Basis(Vector3.UP, atan2(B.z.x, B.z.z) if absf(B.z.y) < 0.9 else float(c["yaw"]))
		c["B"] = (c["B0"] as Basis).slerp(up, ease(u, -2.0))
		P.y = COM_H + (park.height(Vector2(P.x, P.z)) if park != null else 0.0) + sin(u * PI) * 1.2
		c["P"] = P
		if u >= 1.0:
			_land(c)
			return
		_place_rb(c)
		return
	var h := dt / 4.0
	for step in 4:
		V.y -= 9.8 * 1.4 * h
		P += V * h
		if W.length() > 0.0001:
			B = Basis(W.normalized(), W.length() * h) * B
		B = B.orthonormalized()
		wheels_down = 0
		for cx in [-1.0, 1.0]:
			for cy in [bottom, top]:
				for cz in [-1.0, 1.0]:
					var rw := B * Vector3(cx * hw, cy, cz * hl)
					var p := P + rw
					var p2 := Vector2(p.x, p.z)
					var gnd := (park.height(p2) if park != null else 0.0) if not _is_wet(p2) else -99.0
					var gn := park.normal(p2) if park != null else Vector3.UP
					var ff := _ferry_floor(p2)
					if not ff.is_empty():
						gnd = ff[0]
						gn = Vector3.UP
					var pen := gnd - p.y
					if pen > 0.0:
						var j := _contact(B, ib, mass, rw, gn, 0.25, 0.75 if cy == top or B.y.y < 0.5 else 0.0, V, W)
						V = j[0]
						W = j[1]
						P.y += pen * 0.6
						if cy == bottom and B.y.y > 0.5:
							wheels_down += 1
						if float(j[2]) > biggest:
							biggest = j[2]
							big_at = p
							big_n = Vector3.UP
					if _in_building(p2):
						var n2 := _wall_normal(p2, Vector2(P.x, P.z))
						var n3 := Vector3(n2.x, 0, n2.y)
						var j := _contact(B, ib, mass, rw, n3, 0.3, 0.5, V, W)
						V = j[0]
						W = j[1]
						P += n3 * 0.08
						if float(j[2]) > biggest:
							biggest = j[2]
							big_at = p
							big_n = n3
		# rolling on its wheels: they don't drag along, only across
		if wheels_down >= 2:
			var f := B.z
			var vf := V.dot(f)
			V -= f * vf * 0.004
			W *= 0.97
		W *= 1.0 - 0.25 * h
	c["B"] = B
	c["P"] = P
	c["V"] = V
	c["W"] = W
	c["pos"] = Vector2(P.x, P.z)
	c["v"] = Vector2(V.x, V.z)
	c["y"] = P.y - COM_H
	if biggest > 3.0:
		_impact(c, Vector2(big_at.x, big_at.z), Vector2(big_n.x, big_n.z).normalized() if absf(big_n.y) < 0.5 else -(c["v"] as Vector2).normalized(),
			biggest, "ground", {})
		if absf(big_n.y) > 0.5:
			_dust(Vector3(big_at.x, 0.0, big_at.z))
	# props, birds and people in its way (it's still a box going through them)
	_move_props(c)
	if _is_wet(Vector2(P.x, P.z)) and P.y < Water.RIVER_Y + 0.8:
		c["rb"] = false
		c["y"] = P.y - COM_H
		c["vy"] = V.y
		(c["node"] as Node3D).basis = Basis(Vector3.UP, atan2(B.z.x, B.z.z))
		c["yaw"] = atan2(B.z.x, B.z.z)
		mode = "sink"
		_gone_t = 0.0
		_toast_msg("Into the river! That's the %s gone." % Utes.TITLE[c["name"]])
		return
	if V.length() < 0.7 and W.length() < 0.7:
		c["rest"] = float(c["rest"]) + dt
	else:
		c["rest"] = 0.0
	if B.y.y > 0.85 and wheels_down >= 3 and W.length() < 1.6 and absf(V.y) < 1.5:
		_land(c)
		return
	if float(c["rest"]) > 1.0:
		_toast_msg("On its %s. Righting it." % ("roof" if B.y.y < -0.5 else "side"))
		c["right_t"] = 0.0
		c["B0"] = B
	_place_rb(c)
	c["spin"] = float(c["spin"]) + V.dot(B.z) / float(s["r"]) * dt
	_eng_rpm = lerpf(_eng_rpm, float(Utes.ENGINE[c["name"]]["idle"]) * 1.6, minf(1.0, dt * 4.0))

## One corner's bounce off the ground or a wall: [velocity, spin, how hard
## (m/s it took out)].
func _contact(B: Basis, ib: Vector3, mass: float, rw: Vector3, n: Vector3, bounce: float, mu: float, V: Vector3, W: Vector3) -> Array:
	var iinv := func(x: Vector3) -> Vector3: return B * ((B.transposed() * x) / ib)
	var vp := V + W.cross(rw)
	var vn := vp.dot(n)
	if vn >= 0.0:
		return [V, W, 0.0]
	var rn := rw.cross(n)
	var kn := 1.0 / mass + n.dot((iinv.call(rn) as Vector3).cross(rw))
	var j := -(1.0 + bounce) * vn / kn
	V += n * j / mass
	W += iinv.call(rw.cross(n * j))
	if mu > 0.0:
		vp = V + W.cross(rw)
		var vt := vp - n * vp.dot(n)
		if vt.length() > 0.01:
			var t := vt.normalized()
			var kt := 1.0 / mass + t.dot((iinv.call(rw.cross(t)) as Vector3).cross(rw))
			var jt := minf(vt.length() / kt, mu * j)
			V -= t * jt / mass
			W -= iinv.call(rw.cross(t * jt))
	return [V, W, -vn]

func _place_rb(c: Dictionary) -> void:
	var n: Node3D = c["node"]
	var B: Basis = c["B"]
	var P: Vector3 = c["P"]
	n.basis = B
	n.position = P - B * Vector3(0, COM_H, 0)
	for w in ["FL", "FR", "RL", "RR"]:
		((n.get_node(w) as Node3D).get_node("Spin") as Node3D).rotation.x = c["spin"]

## Back on its wheels, driving.
func _land(c: Dictionary) -> void:
	var B: Basis = c["B"]
	c["rb"] = false
	c["yaw"] = atan2(B.z.x, B.z.z)
	var V: Vector3 = c["V"]
	# (a roll scrubs off a lot: panels and glass on the bitumen, tyres bouncing)
	c["v"] = Vector2(V.x, V.z) * 0.55
	c["yaw_rate"] = (c["W"] as Vector3).y * 0.5
	c["y"] = park.height(c["pos"]) if park != null else 0.0
	c["vy"] = 0.0
	c["air"] = false
	c["pitch"] = 0.0
	c["roll"] = 0.0
	c["pv"] = -0.4
	c["rv"] = 0.0
	(c["node"] as Node3D).basis = Basis(Vector3.UP, c["yaw"])
	if not _car_block(c, c["pos"], c["yaw"], 0.0, Vector2.ZERO).is_empty():
		_unstick(c, false)
	_place_car(c, 0.0)

## Flattening and bowling over while thrown about.
func _move_props(c: Dictionary) -> void:
	if crash == null:
		return
	var at: Vector2 = c["pos"]
	var v: Vector2 = c["v"]
	var half := _half(c["name"])
	for it in crash.near(at, half.y):
		if it["kind"] in ["flat", "plant", "pole"] and (it["p"] as Vector2).distance_to(at) < half.y:
			crash.knock(it, v)
	for w in crash.birds_in(at, half, c["yaw"]):
		crash.squash(w, v)
	for w in crash.people_in(at, half, c["yaw"]):
		crash.bowl(w, v + Vector2(randf_range(-2, 2), randf_range(-2, 2)))

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

## The ground under a ute: [its height at the ute's middle, the pitch (nose
## up +) and the roll (left side up +)], from where its four wheels sit.
func _ground_under(c: Dictionary) -> Array:
	var s: Dictionary = Utes.SPEC[c["name"]]
	var yaw: float = c["yaw"]
	var fwd := Vector2(sin(yaw), cos(yaw))
	var left := Vector2(fwd.y, -fwd.x)
	var p: Vector2 = c["pos"]
	var zf: float = float(s["L"]) * 0.5 - float(s["front"])
	var zr: float = zf - float(s["wb"])
	var tw: float = float(s["track"]) * 0.5
	var fl: float = park.height(p + fwd * zf + left * tw)
	var fr: float = park.height(p + fwd * zf - left * tw)
	var rl: float = park.height(p + fwd * zr + left * tw)
	var rr: float = park.height(p + fwd * zr - left * tw)
	var front := (fl + fr) * 0.5
	var rear := (rl + rr) * 0.5
	return [lerpf(rear, front, -zr / float(s["wb"])), atan2(front - rear, float(s["wb"])),
		atan2((fl + rl) * 0.5 - (fr + rr) * 0.5, tw * 2.0)]

## Up and down with the ground, leaning with it; off a crest fast enough
## it flies, and comes down with a thump (or a bounce, and over, if it's hard).
func _follow_ground(c: Dictionary, dt: float, can_fly: bool) -> void:
	if park == null or dt <= 0.0:
		return
	var g := _ground_under(c)
	var gy: float = g[0]
	var y: float = c.get("y", 0.0)
	var vy: float = c.get("vy", 0.0)
	var air: bool = c.get("air", false)
	var fall := 9.8 * 1.3
	var by := y + vy * dt - fall * dt * dt
	if can_fly and by > gy + 0.04 and (air or vy > 0.8):
		air = true
		vy -= fall * dt
		y = by
	else:
		if air:
			air = false
			c["air"] = false
			c["y"] = gy
			# (how hard it comes down against the ground: landing on a down
			# slope going its way is soft, flat or into an up slope isn't)
			var fwd := Vector2(sin(float(c["yaw"])), cos(float(c["yaw"])))
			var ground_vy := (c["v"] as Vector2).dot(fwd) * tan(float(g[1]))
			if _landed(c, ground_vy - vy):
				return
			vy = 0.0
		else:
			vy = clampf((gy - y) / dt, -25.0, 25.0)
		y = gy
	c["y"] = y
	c["vy"] = vy
	c["air"] = air
	var k := 1.0 - exp(-dt * (3.0 if air else 16.0))
	c["gp"] = lerp_angle(float(c.get("gp", 0.0)), float(g[1]), k)
	c["gr"] = lerp_angle(float(c.get("gr", 0.0)), float(g[2]), k)

## Down off a jump at `hit` m/s: true if it's gone over.
func _landed(c: Dictionary, hit: float) -> bool:
	var v: Vector2 = c["v"]
	var fwd := Vector2(sin(float(c["yaw"])), cos(float(c["yaw"])))
	if hit > 3.0:
		if _who != null and is_same(c, car):
			game.haptic(_who, str(clampi(int(hit * 10.0), 25, 140)))
		c["pv"] = float(c["pv"]) - hit * 0.12
		_shake = maxf(_shake, clampf(hit * 0.05, 0.1, 0.6))
		_dust(Vector3(c["pos"].x, float(c["y"]), c["pos"].y))
		_thud = maxf(_thud, clampf(hit / 10.0, 0.3, 1.0))
	if hit > 7.0:
		_impact(c, (c["pos"] as Vector2) + fwd * 1.6, -fwd, (hit - 5.0) * 0.9, "ground", {})
	if hit > 12.0 and mode == "drive" and is_same(c, car):
		# hard enough to bounce it, end over end
		_launch(c, Vector3(v.x * 0.8, hit * 0.3, v.y * 0.8), Vector3(fwd.y, 0, -fwd.x) * clampf(hit * 0.2, 1.5, 5.0))
		_toast_msg("Came down nose first. That's going to leave a mark.")
		return true
	if hit > 5.0 and is_same(c, car):
		_toast_msg(["Big air!", "Sent it!", "Airborne!"][randi() % 3])
	return false

## Mud flung off the back wheels (and caked up the sides), sand kicked up,
## a bow wave through the water, dust off the dirt.
func _park_fx(c: Dictionary, surf: String, gas: float, vf: float, dt: float) -> void:
	if surf == "":
		return
	var n: Node3D = c["node"]
	var mud: float = c.get("mud", 0.0)
	c["fx_t"] = float(c.get("fx_t", 0.0)) - dt
	var busy: bool = (gas > 0.3 or absf(vf) > 2.0) and not c.get("air", false)
	if float(c["fx_t"]) <= 0.0 and busy:
		c["fx_t"] = 0.08
		var yaw: float = c["yaw"]
		var back := Vector3(-sin(yaw), 0, -cos(yaw)) * signf(vf if absf(vf) > 0.3 else 1.0)
		for w in (["FL", "FR"] if surf == "water" else ["RL", "RR"]):
			var at := (n.get_node(w) as Node3D).global_position
			match surf:
				"mud":
					_debris(at, back * 1.4 + Vector3(0, 2.0, 0), 2.0 + gas * 4.0, Color("4e3a28"), false)
					mud = minf(0.55, mud + 0.012)
				"sand":
					_puff(at, Color(0.9, 0.84, 0.66, 0.45), 0.35, 0.9)
				"water":
					if absf(vf) > 1.5:
						_wade(at, absf(vf))
				"dirt":
					if absf(vf) > 7.0 and randf() < 0.5:
						_puff(at, Color(0.72, 0.62, 0.48, 0.3), 0.3, 0.8)
	if surf == "water":
		mud = maxf(0.0, mud - dt * 0.12)
	if absf(mud - float(c.get("mud", 0.0))) > 0.0001:
		c["mud"] = mud
		var shell := n.get_node("Body/Shell") as MeshInstance3D
		shell.set_instance_shader_parameter("tint", (Utes.OWN_PAINT[c["name"]] as Color).lerp(Color("5b4530"), mud))

## Water thrown out from a wheel ploughing through (at the water's surface).
func _wade(at: Vector3, speed: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = clampi(int(speed * 3.0), 8, 36)
	p.lifetime = 0.9
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 2.0 + speed * 0.45
	p.gravity = Vector3(0, -12, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	sm.material = F.flat_mat(Color(0.82, 0.86, 0.8, 0.85))
	p.mesh = sm
	var wl: float = park.water(Vector2(to_local(at).x, to_local(at).z))
	p.position = Vector3(to_local(at).x, wl + 0.05, to_local(at).z)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2, true, false, true).timeout.connect(p.queue_free)

## The park's challenges: through the bog, across the dam and through the
## sand traps without stopping, and up the hill to the top.
func _park_challenges(c: Dictionary, dt: float) -> void:
	if park == null:
		return
	var ch: String = park.challenge(c["pos"])
	# (put somewhere else: back at the site after drowning one, or another ute)
	var jumped: bool = _park_run.has("at") and (c["pos"] as Vector2).distance_to(_park_run["at"]) > 4.0
	_park_run["at"] = c["pos"]
	if jumped and _park_in != "":
		_park_in = ""
		_park_run = {"at": c["pos"]}
	if ch == _park_in:
		_park_t += dt
		if ch != "":
			var r := _park_run
			r["low"] = minf(float(r.get("low", 0.0)), park.height(c["pos"]))
			if (c["v"] as Vector2).length() < 0.5:
				r["stopped"] = float(r.get("stopped", 0.0)) + dt
			if c.get("air", false):
				r["air"] = true
		if ch == "hill" and not _park_run.has("done") and float(c.get("y", 0.0)) > float(park.FEATURES[0][5]) - 1.2:
			_park_run["done"] = true
			_park_finish("hill", c)
		return
	# (out the other side, still going, after a proper go at it)
	var was := _park_in
	_park_in = ch
	if was != "" and was != "hill" and _park_t > 1.2 and _park_run.has("from"):
		# (out the far side, not back the way you came)
		var from: Vector2 = _park_run["from"]
		if (c["pos"] as Vector2).distance_to(from) > park.centre(was).distance_to(from):
			_park_finish(was, c)
	_park_t = 0.0
	_park_run = {"from": c["pos"], "at": c["pos"], "low": 0.0, "stopped": 0.0, "dmg": c["dmg"]}
	c["dug"] = false
	c["rescued"] = false
	c["winched"] = false

## A go at a challenge finished: its time, a medal (gold needs the hard
## line too), and a record if it's your best.
func _park_finish(ch: String, c: Dictionary) -> void:
	var r := _park_run
	var t := _park_t
	var m: Array = park.MEDALS[ch]
	var name: String = park.CHALLENGES[ch]
	if c.get("rescued", false) or _dead(c):
		_toast_msg("%s: no time, you had help." % name)
		_park_tick(ch)
		return
	var hard := park.hard_way(ch, r.get("from", c["pos"]))
	match ch:
		"hill":
			hard = hard and not r.get("air", false)
		"bog":
			hard = float(r["low"]) < -0.3
		"dam":
			hard = float(r["low"]) < -0.9
		"sand", "moguls":
			hard = float(r["stopped"]) < 0.4
		"logs":
			hard = not c.get("dug", false)
	if c.get("winched", false):
		hard = false
	var medal := "bronze"
	if t <= float(m[1]):
		medal = "silver"
	if t <= float(m[0]) and hard:
		medal = "gold"
	# (knocked it about getting there: down one)
	if float(c["dmg"]) - float(r.get("dmg", 0.0)) > 0.15:
		medal = {"gold": "silver", "silver": "bronze", "bronze": "bronze"}[medal]
	var rank := {"gold": 3, "silver": 2, "bronze": 1}
	if rank[medal] > int(rank.get(_park_medal.get(ch, ""), 0)):
		_park_medal[ch] = medal
	var best := _record(ch, t, medal)
	var why := ""
	if medal != "gold" and t <= float(m[0]) and not hard:
		why = " Gold's %s." % ("without the winch" if c.get("winched", false) else m[2])
	_toast_msg("%s: %.1f s · %s%s%s" % [name, t, medal.to_upper(), " · new best!" if best else "", why])
	if _who != null:
		game.haptic(_who, "20,40,20,40,60" if medal == "gold" else "20,40,20")
	_park_tick(ch, true)

## Keeps a crew member's best time at each (wallet.gd's save); true if it's a
## new one. The boards by the gates show the crew's best.
func _record(ch: String, t: float, medal: String) -> bool:
	var who := _char()
	var w := Wallet.of(who if who != "" else "you")
	if not w.has("park"):
		w["park"] = {}
	var pk: Dictionary = w["park"]
	var was: Dictionary = pk.get(ch, {})
	var rank := {"gold": 3, "silver": 2, "bronze": 1}
	var better: bool = was.is_empty() or int(rank[medal]) > int(rank.get(was.get("m", ""), 0)) \
		or (medal == was.get("m", "") and t < float(was.get("t", 999.0)))
	if better:
		pk[ch] = {"t": snappedf(t, 0.1), "m": medal}
		Wallet.save()
		_update_boards()
	return better

func _update_boards() -> void:
	if park == null or park.boards.is_empty():
		return
	var rank := {"gold": 3, "silver": 2, "bronze": 1}
	var lines := ["4x4 PARK RECORDS"]
	for ch in park.CHALLENGES:
		var best := {}
		var by := ""
		for who in (Wallet.data["chars"] as Dictionary):
			var rec: Dictionary = ((Wallet.data["chars"][who] as Dictionary).get("park", {}) as Dictionary).get(ch, {})
			if rec.is_empty():
				continue
			if best.is_empty() or int(rank[rec["m"]]) > int(rank[best["m"]]) \
					or (rec["m"] == best["m"] and float(rec["t"]) < float(best["t"])):
				best = rec
				by = String(who).capitalize()
		lines.append("%s   %s" % [park.CHALLENGES[ch], ("%.1f s %s  %s" % [best["t"], String(best["m"]).to_upper(), by]) if not best.is_empty() else "--"])
	for b in park.boards:
		(b as Label3D).text = "\n".join(lines)

func _park_tick(ch: String, quiet := false) -> void:
	if _park_done.has(ch):
		return
	_park_done[ch] = true
	var n := _park_done.size()
	if n >= park.CHALLENGES.size():
		_toast_msg("All %d done! Fair dinkum bush basher." % n)
	elif not quiet:
		_toast_msg("%s done. %d of %d." % [park.CHALLENGES[ch], n, park.CHALLENGES.size()])

## A parked ute rocks back level, and rolls to a stop if you left it moving.
func _settle(c: Dictionary, dt: float) -> void:
	if c["rb"]:
		# (left tumbling: it finishes on its own)
		_tumble(c, dt)
		return
	_damage_fx(c, dt)
	var v: Vector2 = c["v"]
	if v.length() > 0.05:
		c["v"] = v.move_toward(Vector2.ZERO, 3.0 * dt)
		_move_car(c, dt)
		c["spin"] = float(c["spin"]) + (c["v"] as Vector2).length() / 0.4 * dt
	c["steer"] = move_toward(float(c["steer"]), 0.0, dt)
	_follow_ground(c, dt, false)
	_spring(c, 0.0, 0.0, dt)
	_place_car(c, dt)

func _spring(c: Dictionary, pitch_to: float, roll_to: float, dt: float) -> void:
	var pv: float = c["pv"]
	var rv: float = c["rv"]
	# (soft enough to see it lean and sway)
	pv += ((pitch_to - float(c["pitch"])) * 110.0 - pv * 9.0) * dt
	rv += ((roll_to - float(c["roll"])) * 85.0 - rv * 7.0) * dt
	c["pv"] = pv
	c["rv"] = rv
	c["pitch"] = float(c["pitch"]) + pv * dt
	c["roll"] = float(c["roll"]) + rv * dt

func _place_car(c: Dictionary, dt: float) -> void:
	if c["rb"]:
		_place_rb(c)
		return
	var n: Node3D = c["node"]
	var p: Vector2 = c["pos"]
	# (up on its belly or a bump stop, down in its own holes in the mud)
	n.position = Vector3(p.x, float(c.get("y", 0.0)) + float(c.get("raise", 0.0)) - float(c.get("dig", 0.0)) * 0.6, p.y)
	n.basis = Basis(Vector3.UP, float(c["yaw"])) * Basis.from_euler(Vector3(-float(c.get("gp", 0.0)), 0, float(c.get("gr", 0.0))))
	var body := n.get_node("Body") as Node3D
	var speed := (c["v"] as Vector2).length()
	c["bob"] = float(c["bob"]) + dt * (6.0 + speed * 0.9)
	body.position.y = float(n.get_meta("ride", 0.0)) + 0.02 + sin(float(c["bob"]) * 3.1) * 0.006 * clampf(speed / 20.0, 0.0, 1.0)
	body.rotation = Vector3(c["pitch"], 0, c["roll"])
	Utes.wings(n, speed, dt)
	var bent: Dictionary = c["bent"]
	var woff: Array = c.get("woff", [0.0, 0.0, 0.0, 0.0])
	var wy0: Array = c.get("wy0", [])
	var bump := 0.0
	var surf: String = park.surface(p) if park != null else ""
	if surf in ["dirt", "grass", "sand", "mud"] and not c.get("air", false):
		# (the little stuff under the tyres: ruts, tussocks, stones)
		bump = {"dirt": 0.035, "grass": 0.02, "sand": 0.015, "mud": 0.03}[surf] * clampf(speed / 6.0, 0.0, 1.0)
	var psi_now: float = c.get("psi", Offroad.PSI_ROAD)
	var aired: bool = psi_now < 26.0 or c.get("flat", "") != ""
	if c.has("kit"):
		Utes.air(n, c["name"], aired, "mudtyres" in c["kit"])
	var ys := [0.0, 0.0, 0.0, 0.0]
	for i in 4:
		var w: String = ["FL", "FR", "RL", "RR"][i]
		var steer := n.get_node(w) as Node3D
		if wy0.size() == 4:
			var q := p + Vector2(steer.position.x, steer.position.z).rotated(-float(c["yaw"]))
			var jig := bump * sin(q.x * 3.1 + q.y * 2.3) * cos(q.y * 4.7 - q.x * 1.3)
			var flat: bool = c.get("flat", "") == w
			# (aired down the tread sits lower; a flat one's down on its rim)
			var sag := 0.12 if flat else 0.0
			steer.position.y = float(wy0[i]) * (1.0 - sag) - (Utes.LOW_DROP if aired else 0.0) + float(woff[i]) + jig \
				- float(c.get("dig", 0.0)) * 0.4
			steer.scale = Vector3(1.0 + sag * 0.6, 1.0 - sag, 1.0 - sag)
			ys[i] = steer.position.y
		steer.rotation.y = -float(c["steer"]) if w.begins_with("F") else 0.0
		# (a wheel knocked out of line leans in)
		steer.rotation.z = float(bent[w]) * (1.0 if steer.position.x > 0.0 else -1.0)
		(steer.get_node("Spin") as Node3D).rotation.x = c["spin"]
	# the live rear axle rolls with the back wheels (the Shark's independent:
	# its motor housing stays with the body)
	var ax := n.get_node_or_null("AxleR") as Node3D
	if ax != null and wy0.size() == 4 and c["name"] != "Shark":
		var tr: float = Utes.SPEC[c["name"]]["track"]
		ax.position.y = (float(ys[2]) + float(ys[3])) * 0.5
		ax.rotation.z = atan2(float(ys[2]) - float(ys[3]), tr)

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

## The terminal for walkers: a ramp down off the landing to the riverwalk,
## and a screen with the time and when the next CityCats call.
func _build_terminal() -> void:
	var dir: Vector2 = _fer["dir"]
	var edge: Vector2 = _fer["edge"]
	var yaw := atan2(dir.x, dir.y)
	var rise := 0.86
	var slope := atan2(rise, RAMP)
	var len := Vector2(RAMP, rise).length()
	var mid := edge + dir * (3.0 + RAMP * 0.5)
	var ramp := Node3D.new()
	ramp.name = "TerminalRamp"
	ramp.position = Vector3(mid.x, rise * 0.5, mid.y)
	ramp.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, slope)
	add_child(ramp)
	var concrete := F.color_mat(Color("b9b7b0"), false)
	var rail := F.color_mat(Color("d2d6d8"), false)
	var bm := BoxMesh.new()
	bm.size = Vector3(2.4, 0.3, len)
	var deck := MeshInstance3D.new()
	deck.mesh = bm
	deck.material_override = concrete
	deck.position.y = -0.15
	ramp.add_child(deck)
	for sx in [-1.0, 1.0]:
		var r := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.06, 0.06, len)
		r.mesh = rm
		r.material_override = rail
		r.position = Vector3(sx * 1.17, 0.95, 0)
		ramp.add_child(r)
		for k in 3:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.05, 0.95, 0.05)
			post.mesh = pm
			post.material_override = rail
			post.position = Vector3(sx * 1.17, 0.47, (k - 1) * len * 0.45)
			ramp.add_child(post)
	# the timetable screen, beside the top of the ramp, facing the way you come
	var side := Vector2(dir.y, -dir.x)
	var at := edge + dir * 3.4 + side * 1.9
	var sign := Node3D.new()
	sign.name = "CityCatTimes"
	sign.position = Vector3(at.x, 0, at.y)
	sign.rotation.y = yaw
	add_child(sign)
	var pole := MeshInstance3D.new()
	var pm2 := BoxMesh.new()
	pm2.size = Vector3(0.12, 1.6, 0.12)
	pole.mesh = pm2
	pole.material_override = F.color_mat(Color("3a3e44"), false)
	pole.position.y = 0.75
	sign.add_child(pole)
	var panel := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(2.1, 1.25, 0.1)
	panel.mesh = pb
	panel.material_override = F.color_mat(Color("15181d"), false)
	panel.position.y = 2.1
	sign.add_child(panel)
	var trim := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(2.1, 0.2, 0.11)
	trim.mesh = tb
	trim.material_override = F.color_mat(Color("1f4f9a"), false)
	trim.position.y = 2.82
	sign.add_child(trim)
	_board_label = Label3D.new()
	_board_label.font_size = 34
	_board_label.pixel_size = 0.004
	_board_label.outline_size = 0
	_board_label.modulate = Color("ffb340")
	_board_label.position = Vector3(0, 2.07, 0.06)
	_board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_label.shaded = false
	_board_label.double_sided = false
	sign.add_child(_board_label)
	var head := Label3D.new()
	head.text = "CityCat · Northshore Hamilton"
	head.font_size = 24
	head.pixel_size = 0.004
	head.outline_size = 0
	head.modulate = Color.WHITE
	head.position = Vector3(0, 2.82, 0.065)
	head.shaded = false
	head.double_sided = false
	sign.add_child(head)

## Seconds till the CityCat's next at the terminal (0 while it's there),
## from where it is on its run (citycat.gd), and the whole round trip.
func _cat_times() -> Vector2:
	if _boat == null or not _boat.has_meta("eta"):
		return Vector2(-1, 0)
	var eta: float = _boat.get_meta("eta")
	return Vector2(0.0 if eta < 0.5 else eta, float(_boat.get_meta("cycle")))

func _clock(after: float) -> String:
	var t := Time.get_time_dict_from_system()
	var m := int(t["hour"]) * 60 + int(t["minute"]) + int(after / 60.0)
	return "%d:%02d" % [(m / 60) % 24, m % 60]

func _update_board() -> void:
	var tc := _cat_times()
	if tc.x < 0.0:
		_board_label.text = _clock(0)
		return
	var lines := ["Now  %s" % _clock(0), "Next CityCats"]
	if tc.x == 0.0:
		lines.append("Boarding now")
	else:
		lines.append("%s   %s" % [_clock(tc.x), _mins(tc.x)])
	for k in [1, 2]:
		lines.append(_clock(tc.x + tc.y * k))
	_board_label.text = "\n".join(lines)

func _mins(sec: float) -> String:
	return "due" if sec < 45.0 else "%d min" % ceili(sec / 60.0)


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
	if _demo and _demo_dv.has("cam"):
		# (a demo shot from up high)
		var cv: Array = _demo_dv["cam"]
		cam.global_position = to_global(cv[0])
		cam.look_at(to_global(cv[1]))
		return
	var focus: Vector3
	var want: Vector3
	var fov := 55.0
	if mode == "drive" or mode == "sink":
		var c := car
		var yaw: float = c["yaw"]
		var v: Vector2 = c["v"]
		var speed := v.length()
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		# (behind the way it's pointing; swings round slowly, so a slide shows)
		var back := yaw + PI
		if v.dot(Vector2(fwd.x, fwd.z)) < -3.0:
			back = yaw
		_cam_yaw = lerp_angle(_cam_yaw, back, minf(1.0, dt * (2.2 if not _rmb and _look_hold <= 0.0 else 0.0)))
		focus = Vector3(c["pos"].x, 1.3 + maxf(float(c.get("y", 0.0)), Water.RIVER_Y - 1.0), c["pos"].y) + fwd * clampf(speed * 0.08, 0.0, 2.5)
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
	var driving := mode == "drive" and not _frozen and not _dead(car)
	var f := _eng_rpm / 60.0 * 2.0
	var vol := (0.16 + 0.14 * _eng_load) if driving else 0.0
	var whine := 0.0
	var gear_whine := 0.0
	if driving and String(car.get("drive", "")).begins_with("4L") and Utes.ENGINE[car["name"]]["kind"] != "phev":
		# (low range: the transfer case's straight-cut gears singing)
		gear_whine = _eng_rpm / 60.0 * 5.3
	if driving and Utes.ENGINE[car["name"]]["kind"] == "phev":
		# the Shark: the petrol engine humming away as a generator, and the
		# motors' whine rising with the speed
		whine = _eng_rpm / 60.0 * 4.0
		f = (1400.0 + _eng_load * 1600.0) / 60.0 * 2.0
		vol = 0.05 + 0.05 * _eng_load
	for i in n:
		_eng_ph += f / 22050.0
		if _eng_ph > 1.0:
			_eng_ph -= 1.0
		var ph := _eng_ph * TAU
		var noise := randf_range(-1.0, 1.0)
		_noise_lp = lerpf(_noise_lp, noise, 0.25)
		var e := (sin(ph) * 0.55 + sin(ph * 2.0 + 0.4) * 0.3 + sin(ph * 0.5) * 0.35 + _noise_lp * 0.35) * (0.7 + 0.3 * sin(ph * 0.5))
		var s := e * vol
		if whine > 0.0:
			_whine_ph = fmod(_whine_ph + whine / 22050.0, 1.0)
			s += sin(_whine_ph * TAU) * (0.03 + 0.05 * _eng_load) + sin(_whine_ph * TAU * 1.5) * 0.015
		s += (noise - _noise_lp) * _squeal * 0.18 * sin(_t * 900.0 + i * 0.37)
		s += _noise_lp * _thud * 0.9
		# (air hissing out of the valves; metal and rock scraping underneath)
		s += (noise - _noise_lp) * _hiss * 0.12
		if gear_whine > 0.0:
			_whine_ph = fmod(_whine_ph + gear_whine / 22050.0, 1.0)
			s += sin(_whine_ph * TAU) * (0.012 + 0.02 * _eng_load)
		# (mud slapping the arches: lumpy bursts of low noise)
		s += _noise_lp * _mud_slap * 0.5 * maxf(0.0, sin(_t * 23.0 + i * 0.004) * sin(_t * 9.0 + i * 0.0017))
		s += (noise * 0.6 + sin(_t * 310.0 + i * 0.09) * 0.4) * _scrape * 0.16
		# (the winch motor grinding the rope in)
		if _winch > 0.0:
			_winch_ph = fmod(_winch_ph + (170.0 + 50.0 * _winch) / 22050.0, 1.0)
			s += (sin(_winch_ph * TAU) * 0.6 + signf(sin(_winch_ph * TAU * 2.0)) * 0.2) * _winch * 0.05
		_thud = maxf(0.0, _thud - 1.0 / 22050.0 * 5.0)
		s = clampf(s, -1.0, 1.0)
		_gen.push_frame(Vector2(s, s))
	_scrape = maxf(0.0, _scrape - 0.12)
	if not driving:
		_mud_slap = 0.0
		_squeal = 0.0
		_hiss = 0.0

## What you hear of the place, by where you are (sounds/amb/ and the CityCat's
## engines): street birds everywhere; traffic by how many cars are close; the
## river lapping near the bank, the pontoon or in the water; the golf course's
## birds in the 4x4 park; the CityCat when it's close or you're on it; and the
## breeze off the river.
const PLACES := ["morning", "traffic", "river", "park", "wind", "city", "dawn", "rain"]
func _feed_places(dt: float) -> void:
	_places_t -= dt
	if _places_t > 0.0 or me == null:
		return
	_places_t = 0.25
	var at: Vector3 = me.global_position
	var p := Vector2(me.position.x, me.position.z)
	if mode == "drive" and not car.is_empty():
		p = car["pos"]
	var cars := 0.0
	if traffic != null:
		for dv in traffic._drivers:
			var n: Node3D = dv["node"]
			if is_instance_valid(n) and n.visible:
				cars += clampf(1.0 - n.global_position.distance_to(at) / 90.0, 0.0, 1.0)
	var bank := 0.0 if _is_wet(p) else _from_bank(p)
	var river := 1.0 if mode in ["ride", "drown", "sink"] or not _ferry_floor(p).is_empty() else clampf(1.0 - bank / 60.0, 0.0, 1.0)
	var in_park: bool = park != null and park.surface(p) != ""
	var boat := 0.0
	if mode == "ride":
		boat = 1.0
	elif _boat != null and _boat.visible:
		boat = clampf(1.0 - _boat.global_position.distance_to(at) / 160.0, 0.0, 1.0)
	var sfx = game.sfx
	sfx.set_ambience("morning", 0.3 if in_park else 0.8 - 0.4 * river)
	sfx.set_ambience("traffic", clampf(cars / 2.0, 0.0, 1.0) * (0.4 if mode == "ride" else 1.0))
	sfx.set_ambience("river", river)
	sfx.set_ambience("park", 1.0 if in_park else 0.0)
	sfx.set_ambience("wind", 0.15 + 0.35 * river)
	sfx.set_ambience("city", 0.0)
	sfx.set_ambience("dawn", 0.0)
	sfx.set_ambience("rain", 0.0)
	sfx.set_loop("citycat", boat)

# ------------------------------------------------------------------ on screen

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 8
	add_child(_ui)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.05, 0.08, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_fade)
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
	_speedo.add_theme_constant_override("separation", 4)
	_speed_label = UI.head("0", 64, UI.WHITE, 8)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speedo.add_child(_speed_label)
	# the tacho: a row of lights up to the redline, and the gear
	var tach := HBoxContainer.new()
	tach.add_theme_constant_override("separation", 3)
	tach.alignment = BoxContainer.ALIGNMENT_END
	_gear_label = UI.head("D1", 30, UI.YELLOW, 6)
	_gear_label.custom_minimum_size = Vector2(64, 0)
	tach.add_child(_gear_label)
	for i in 22:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(9, 10 + i)
		seg.size_flags_vertical = Control.SIZE_SHRINK_END
		tach.add_child(seg)
		_revs.append(seg)
	_speedo.add_child(tach)
	_ute_label = UI.head("", 24, UI.BONE, 6)
	_ute_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speedo.add_child(_ute_label)
	_drive_label = UI.head("", 26, UI.YELLOW, 6)
	_drive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speedo.add_child(_drive_label)
	# how knocked about it is
	var dmg := HBoxContainer.new()
	dmg.alignment = BoxContainer.ALIGNMENT_END
	dmg.add_theme_constant_override("separation", 8)
	dmg.add_child(UI.head("DAMAGE", 18, UI.BONE, 4))
	var track := ColorRect.new()
	track.color = Color(0, 0, 0, 0.45)
	track.custom_minimum_size = Vector2(160, 10)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dmg_fill = ColorRect.new()
	_dmg_fill.size = Vector2(0, 10)
	track.add_child(_dmg_fill)
	dmg.add_child(track)
	_speedo.add_child(dmg)
	_speedo.visible = false
	_ui.add_child(_speedo)
	_toast = UI.head("", 40, UI.YELLOW, 10)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	_ui.add_child(_toast)
	# the 4x4 park's challenges, while you're in it
	_park_label = UI.head("", 26, UI.BONE, 8)
	_park_label.visible = false
	_ui.add_child(_park_label)

func _toast_msg(text: String) -> void:
	if _demo:
		print("[explore] toast: " + text)
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
					var tc := _cat_times()
					text = "Next CityCat " + (_mins(tc.x) if tc.x >= 0.0 else "soon")
		"drive":
			if car["rb"]:
				text = ""
			elif _dead(car):
				key = "X"
				text = ("Drowned it · get out" if car.get("drowned", false) else "She's cactus · get out")
			elif _rec.get("kind", "") == "strap":
				text = "Hang on: your mate's snatching you out"
			elif _rec.get("kind", "") == "winch" or (_rec.is_empty() and "winch" in (car["kit"] as Array) and _hung_up(car)):
				key = "A"
				text = "Hold: winch out"
			elif (car["v"] as Vector2).length() < 7.0:
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
			if ks.bg_color != UI.GLYPH[key]:
				ks.bg_color = UI.GLYPH[key]
			UI.font_color(_prompt_key, UI.GLYPH_INK[key])
		_prompt_text.text = text
		_prompt.reset_size()
		_prompt.position = Vector2((view.x - _prompt.size.x) * 0.5, view.y - _prompt.size.y - 70.0)
	_help_t = maxf(0.0, _help_t - dt)
	_help.visible = _help_t > 0.0
	if _help.visible:
		_help.modulate.a = clampf(_help_t, 0.0, 1.0)
		var phone: bool = _who != null and _who.remote_id >= 0
		if mode == "drive":
			if phone:
				_help.text = "Phone: the stick steers · GAS and BRAKE pedals · A handbrake · X get out" + \
					"\nTap the dash for 2H / 4H / 4L and the locker · hold PSI for the tyres" + \
					"\nHold BACK TO WORK on the phone: back to the site"
			else:
				_help.text = ("Stick steer · RT go · LT brake / reverse · hold A handbrake · X get out" if _pad else
					"W go · S brake / reverse · A D steer · hold Space handbrake · E get out") + \
					"\n" + ("D-pad: up / down 2H 4H 4L · right locker · left tyres" if _pad else
					"Tap F: 2H / 4H / 4L / locker · hold F stopped: tyre pressure") + \
					"\n" + ("Click the right stick: camera behind · hold B: back to the site" if _pad else "Hold Q: back to the site")
		elif phone:
			_help.text = "Phone: stick to walk, push it to the edge to run · drag the right side to look round" + \
				"\nA jump · X get in · hold BACK TO WORK on the phone: back to the site"
		else:
			_help.text = ("Stick walk, push it all the way to run · A jump · X get in · right stick look" if _pad else
				"WASD walk · hold F run · Space jump · E get in · right-drag look") + \
				"\n" + ("Click the right stick: camera behind · hold B: back to the site" if _pad else "Hold Q or Esc: back to the site")
		_help.reset_size()
		_help.position = Vector2((view.x - _help.size.x) * 0.5, view.y - _help.size.y - 18.0)
		# (the prompt sits clear above the help, never over it)
		if _prompt.visible:
			_prompt.position.y = minf(_prompt.position.y, _help.position.y - _prompt.size.y - 10.0)
	_speedo.visible = mode == "drive"
	if _speedo.visible:
		_speed_label.text = "%d km/h" % roundi((car["v"] as Vector2).length() * 3.6)
		_ute_label.text = Utes.TITLE[car["name"]]
		var e: Dictionary = Utes.ENGINE[car["name"]]
		var dead := _dead(car)
		var u: float
		var red: float
		if e["kind"] == "phev":
			# (the Shark shows the motors' power drawn, not revs)
			u = clampf(_eng_load * clampf(1.0 - (car["v"] as Vector2).length() / 60.0, 0.4, 1.0), 0.0, 1.0)
			red = 0.86
			_gear_label.text = "EV" if not dead else "--"
		else:
			u = float(car["rpm"]) / float(e["cut"])
			red = float(e["red"]) / float(e["cut"])
			var vf := (car["v"] as Vector2).dot(Vector2(sin(float(car["yaw"])), cos(float(car["yaw"]))))
			_gear_label.text = "--" if dead else ("R" if vf < -0.3 else "D%d" % int(car["gear"]))
			_ute_label.text = "%s · %d rpm" % [Utes.TITLE[car["name"]], roundi(float(car["rpm"]) / 50.0) * 50]
		for i in _revs.size():
			var at := (i + 0.5) / _revs.size()
			var lit := at <= u
			var col := UI.WHITE if at < red * 0.8 else (UI.YELLOW if at < red else Color("ff4a3d"))
			(_revs[i] as ColorRect).color = col if lit else Color(1, 1, 1, 0.14)
		var dk := ("RB" if _pad else "F")
		var bits: Array = [String(car["drive"]).replace("+LOCK", " · LOCKED")]
		bits.append("%d psi" % roundi(float(car["psi"])))
		if car["flat"] != "":
			bits.append("FLAT TYRE")
		if car.get("drowned", false):
			bits.append("DROWNED")
		_drive_label.text = "  ·  ".join(bits) + "   [%s]" % dk
		UI.font_color(_drive_label, Color("ff4a3d") if car["flat"] != "" or car.get("drowned", false) else UI.YELLOW)
		var dm: float = car["dmg"]
		_dmg_fill.size = Vector2(160.0 * dm, 10)
		_dmg_fill.color = UI.YELLOW.lerp(Color("ff4a3d"), dm)
		_speedo.reset_size()
		_speedo.position = view - _speedo.size - Vector2(36, 24)
	var here := Vector2(me.position.x, me.position.z)
	_park_label.visible = park != null and park.box.has_point(here) and park.box.grow(-25.0).has_point(here)
	if _park_label.visible:
		var bits: Array = []
		for k in park.CHALLENGES:
			var md: String = _park_medal.get(k, "")
			bits.append(("✓ " if _park_done.has(k) else "") + String(park.CHALLENGES[k]) + ((" " + md.to_upper()) if md != "" else ""))
		_park_label.text = "4x4 PARK   " + "   ".join(bits)
		_park_label.position = Vector2(36, 28)
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
	# (taken once this frame's been drawn: the demo only draws every so often)
	_shot_q.append(key)

func _save_shots() -> void:
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(game.shot_dir)
	for key in _shot_q:
		img.save_png(game.shot_dir.path_join("explore_%s.png" % key))
		print("[explore] shot ", key)
	_shot_q.clear()

var _demo_step := 0
var _demo_mark := 0.0
var _shot_q: Array = []
var _quit_code := -1         # the demo's done: quit once its last shots are saved
var _drawn := false
var _demo_dv: Dictionary = {}

func _run_demo(dt: float) -> void:
	if _demo_t == 0.0 and (OS.get_cmdline_user_args().has("--explore=river") or OS.get_cmdline_user_args().has("--explore=board")):
		_demo_step = 7
	if _demo_t == 0.0 and OS.get_cmdline_user_args().has("--explore=crash"):
		_demo_step = 20
	if _demo_t == 0.0 and OS.get_cmdline_user_args().has("--explore=park"):
		_demo_step = 40
	if _demo_t == 0.0 and OS.get_cmdline_user_args().has("--explore=4x4"):
		_demo_step = 60
	if _demo_t == 0.0 and OS.get_cmdline_user_args().has("--explore=recovery"):
		_demo_step = 70
	if _demo_t == 0.0 and OS.get_cmdline_user_args().has("--explore=traffic"):
		_demo_step = 90
	if _demo_t == 0.0 and OS.get_cmdline_user_args().has("--explore=obstacles"):
		_demo_obstacle("moguls", "Hilux", "4H")
		_demo_step = 67
	_demo_t += dt
	if Engine.get_process_frames() % 20 == 0:
		print("[explore] t %.1f step %d mode %s at %s" % [_demo_t, _demo_step, mode, me.position])
	# (the autotest only draws frames it wants a shot of: here every tenth,
	# and the one after a shot's asked for)
	if _drawn and not _shot_q.is_empty():
		_save_shots()
	if _quit_code >= 0 and _shot_q.is_empty():
		get_tree().quit(_quit_code)
		return
	_drawn = not _shot_q.is_empty() or Engine.get_process_frames() % 10 == 0
	RenderingServer.render_loop_enabled = _drawn
	var t := _demo_t - _demo_mark
	_fake["move"] = Vector2.ZERO
	_fake["gas"] = 0.0
	_fake["hold_a"] = false
	_fake["run"] = false
	if _demo_step >= 90:
		_demo_traffic(t)
		return
	if _demo_step >= 70:
		_demo_recovery(t)
		return
	if _demo_step >= 60:
		_demo_4x4(t)
		return
	if _demo_step >= 40:
		_demo_park(t)
		return
	if _demo_step >= 20:
		_demo_crash(t)
		return
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
			# up the ramp from the riverwalk to the terminal
			var dir: Vector2 = _fer["dir"]
			var foot: Vector2 = (_fer["edge"] as Vector2) + dir * (3.0 + RAMP + 1.5)
			me.position = Vector3(foot.x, 0, foot.y)
			_cam_yaw = atan2(dir.x, dir.y) + 0.5
			_cam_dist = 8.0
			_cam_pitch = 0.4
			_next()
		8:
			_fake["move"] = Vector2(0, -1) if t < 2.4 else Vector2.ZERO
			_cam_yaw = atan2((_fer["dir"] as Vector2).x, (_fer["dir"] as Vector2).y)
			if t > 1.2:
				_shot("ramp")
			if t > 3.0:
				print("[explore] after the ramp: y %.2f floor %s" % [me.position.y, _ferry_floor(Vector2(me.position.x, me.position.z))])
				# a look at the timetable
				var sign := get_node("CityCatTimes") as Node3D
				var front := sign.position + sign.basis.z * 4.0
				me.position = Vector3(front.x, 0, front.z) + sign.basis.x * 2.4
				mode = "walk"
				_yaw = atan2(-sign.basis.z.x, -sign.basis.z.z)
				_cam_yaw = atan2(sign.basis.z.x, sign.basis.z.z) + 0.25
				_cam_dist = 4.0
				_cam_pitch = 0.15
				_update_board()
				_next()
		9:
			if t > 1.0:
				_shot("timetable")
				print("[explore] board: ", _board_label.text.replace("\n", " | "))
				if OS.get_cmdline_user_args().has("--explore=board"):
					_quit_code = 0
				var at: Vector2 = _fer["at"]
				var off := at + (_fer["dir"] as Vector2) * 2.0
				me.position = Vector3(off.x, floor_y(off), off.y)
				_cam_yaw = atan2((_fer["dir"] as Vector2).x, (_fer["dir"] as Vector2).y) + 0.6
				_cam_dist = 14.0
				_cam_pitch = 0.35
				if _boat.has_meta("tween"):
					(_boat.get_meta("tween") as Tween).set_speed_scale(25.0)
				_next()
		10:
			if t < 2.2:
				# (down the gangway first: you walk on it, not in it)
				if not _shots.has("gangway_off"):
					var dir: Vector2 = _fer["dir"]
					var mid: Vector2 = (_fer["start"] as Vector2) + dir * float(_fer["run"]) * 0.5
					if t < 0.1:
						me.position = Vector3(mid.x, floor_y(mid), mid.y)
						_yaw = atan2(dir.x, dir.y)
						var side := Vector2(dir.y, -dir.x) * 9.0
						_demo_dv = {"cam": [Vector3(mid.x + side.x, 1.2, mid.y + side.y) - Vector3(dir.x, 0, dir.y) * 4.0,
							Vector3(mid.x, me.position.y + 0.6, mid.y)]}
					elif t > 1.5 and not _shots.has("gangway_q"):
						_shots["gangway_q"] = true
						_shot("gangway")
					elif t > 1.9:
						_shots["gangway_off"] = true
						print("[explore] on the gangway: y %.2f floor %s" % [me.position.y, _ferry_floor(Vector2(me.position.x, me.position.z))])
						var at: Vector2 = _fer["at"]
						var off := at + (_fer["dir"] as Vector2) * 2.0
						me.position = Vector3(off.x, floor_y(off), off.y)
						_cam_yaw = atan2((_fer["dir"] as Vector2).x, (_fer["dir"] as Vector2).y) + 0.6
						_cam_dist = 14.0
						# (and up on the bank downstream, looking back up the river the
						# way it comes in)
						var bt: Vector2 = _boat.get_meta("berth")
						var o := -(_fer["dir"] as Vector2)
						var up_river := Vector2(cos(float(_fer["rot"])), -sin(float(_fer["rot"])))
						var aim := bt + up_river * 45.0 + o * 20.0
						var eye := at - o * 20.0 - up_river * 30.0
						_demo_dv = {"cam": [Vector3(eye.x, 16.0, eye.y), Vector3(aim.x, Water.RIVER_Y, aim.y)]}
				return
			var eta: float = _boat.get_meta("eta", 99.0)
			if not _boat_ready() and eta < 90.0 and not _shots.has("approach"):
				# (slow it to watch it swing in alongside)
				(_boat.get_meta("tween") as Tween).set_speed_scale(3.0)
				if eta < 45.0:
					_shot("approach_far")
				if eta < 22.0:
					_shot("approach")
					print("[explore] coming in: eta %.1f at %s" % [eta, _boat.position])
				return
			if _boat_ready():
				(_boat.get_meta("tween") as Tween).set_speed_scale(1.0)
				if not _shots.has("terminal"):
					_shot("terminal")
					_demo_mark = _demo_t
				elif t > 0.5:
					_demo_dv = {}
					_board()
					_next()
			elif t > 120.0:
				_next()
		11:
			# away up the river, then over the side, and under
			_fake["run"] = t > 1.0 and mode == "ride"
			if t > 7.0 and mode == "ride" and not _boat_ready():
				_shot("citycat")
				_fake["jump"] = true
			if mode == "drown" and _gone_t > 1.6:
				_shot("drown")
			if mode == "walk" and _shots.has("drown") and _fade.color.a < 0.3:
				_shot("respawn")
				_next()
		12:
			# Smoko while knocked off: the wander holds where it is
			if t < 0.1 and not game.pause_menu.visible:
				game.pause_menu.toggle(1)
			if t > 0.8 and game.pause_menu.visible:
				_shot("smoko")
				game.pause_menu.close()
			if t > 1.2:
				print("[explore] after smoko: active %s paused %s mode %s" % [active, get_tree().paused, mode])
				_next()
		13:
			# a ute off the riverwalk into the river
			var dir: Vector2 = _fer["dir"]
			var along := Vector2(-dir.y, dir.x)
			var spot: Vector2 = (_fer["edge"] as Vector2) + along * 30.0 + dir * 7.0
			var c: Dictionary = utes[0]
			c["pos"] = spot
			c["yaw"] = atan2(-dir.x, -dir.y)
			c["v"] = Vector2.ZERO
			_get_in(c)
			_cam_yaw = atan2(dir.x, dir.y) + 0.7
			_next()
		14:
			if mode == "drive":
				_fake["gas"] = 1.0
			if mode == "sink" and _gone_t > 1.3:
				_shot("sink")
			if mode == "walk" and _shots.has("sink") and _fade.color.a < 0.3:
				_shot("back")
				print("[explore] utes %d, at %s" % [utes.size(), me.position])
				print("[explore] demo done")
				_quit_code = 0
			if t > 30.0:
				print("[explore] demo stuck in ", mode)
				_quit_code = 1

## Dev: riding behind a car each way along two-way streets, to see they keep
## left (and print which side of the line every car's on).
func _demo_traffic(t: float) -> void:
	var k := _demo_step - 90
	if k == 4 or k == 5:
		# (the estate's blocks along Parkside Circuit, and a roundabout from up
		# high: everyone round it clockwise)
		_demo_dv = {"cam": [Vector3(-232, 2.4, -101), Vector3(-300, 3, -96)] if k == 4 else
			[Vector3(108, 34, -60), Vector3(108, 0, -92)]}
		if t > 1.5:
			_shot("traffic_%d" % k)
		if t > 2.0:
			_next()
		return
	if k >= 6:
		var wrong := 0
		for dv in traffic._drivers:
			var r: Dictionary = dv["route"]
			if r["oneway"]:
				continue
			var pts: PackedVector2Array = r["pts"]
			var p: Vector2 = dv["p"]
			var best := INF
			var side := 0.0
			for i in range(1, pts.size()):
				var c := Geometry2D.get_closest_point_to_segment(p, pts[i - 1], pts[i])
				if c.distance_to(p) < best:
					best = c.distance_to(p)
					var f: Vector2 = dv["fwd"]
					side = (p - c).dot(Vector2(f.y, -f.x))
			if side < -0.3:
				wrong += 1
		print("[explore] two-way traffic on the right of the line: %d of %d" % [wrong, traffic._drivers.size()])
		print("[explore] demo done")
		_quit_code = 0
		return
	if not _demo_dv.has("dv") or int(_demo_dv.get("k", -1)) != k:
		_demo_dv = {}
		var want := 1.0 if k % 2 == 0 else -1.0
		var n := 0
		for dv in traffic._drivers:
			if not dv["route"]["oneway"] and float(dv["dir"]) == want and (dv["p"] as Vector2).length() < 350.0:
				n += 1
				if n == 1 + k / 2:
					_demo_dv = {"dv": dv, "k": k}
					break
		if _demo_dv.is_empty():
			_next()
			return
	var d: Dictionary = _demo_dv["dv"]
	var p: Vector2 = d["p"]
	var f: Vector2 = d["fwd"]
	var p3 := Vector3(p.x, 0, p.y)
	var f3 := Vector3(f.x, 0, f.y)
	_demo_dv["cam"] = [p3 - f3 * 16.0 + Vector3.UP * 6.0, p3 + f3 * 12.0]
	if t > 1.5:
		_shot("traffic_%d" % k)
		print("[explore] car %d dir %d on %s" % [d["i"], d["dir"], d["route"].get("name", "?")])
	if t > 2.0:
		_next()

## Dev: a ute lined up `back` metres short of `at`, coming at it.
func _demo_line_up(at: Vector2, back: float, name := "Ranger", force := Vector2.ZERO) -> void:
	var c: Dictionary = {}
	for u in utes:
		if u["name"] == name:
			c = u
	if mode == "drive" and not is_same(car, c):
		_get_out(true)
	var from := at + (Vector2(at.x, at.y) - Vector2.ZERO).normalized().rotated(0.0) * 0.0
	var dir := Vector2(1, 0)
	# (come at it from whichever side's open)
	for k in (16 if force == Vector2.ZERO else 0):
		var d := Vector2.from_angle(k * TAU / 16.0)
		var ok := true
		for t in range(2, int(back) + 4, 2):
			var q := at - d * float(t)
			if _blocked(q) or _is_wet(q) or not _ferry_floor(q).is_empty():
				ok = false
				break
			# (and a clear run in: nothing else in the way first)
			for o in crash.near(q, 2.2):
				if (o["p"] as Vector2).distance_to(at) > 1.0 and (o["p"] as Vector2).distance_to(q) < 1.6 + float(o["r"]):
					ok = false
			if not ok:
				break
		if ok:
			dir = d
			break
	if force != Vector2.ZERO:
		dir = force
	from = at - dir * back
	_demo_dv["tgt"] = at
	_demo_dv.erase("pass_t")
	_rmb = false
	c["pos"] = from
	c["yaw"] = atan2(dir.x, dir.y)
	c["v"] = Vector2.ZERO
	c["yaw_rate"] = 0.0
	c["rb"] = false
	(c["node"] as Node3D).basis = Basis(Vector3.UP, c["yaw"])
	if mode != "drive":
		_get_in(c)
	_cam_yaw = c["yaw"] + PI
	_place_car(c, 0.0)

## Flat out at the demo target till it's reached (or hit), then the shot
## `after` s later; true once that's taken (or it's given up).
func _demo_run(t: float, shot: String, after: float) -> bool:
	var tgt: Vector2 = _demo_dv["tgt"]
	var fwd := Vector2(sin(float(car["yaw"])), cos(float(car["yaw"])))
	var to := tgt - (car["pos"] as Vector2)
	if not _demo_dv.has("pass_t") and (to.dot(fwd) < 1.0 or to.length() < 2.5 or (t > 2.0 and (car["v"] as Vector2).length() < 0.5)):
		_demo_dv["pass_t"] = t
		print("[explore] reached the %s at %.1f s, %d km/h" % [shot, t, roundi((car["v"] as Vector2).length() * 3.6)])
		# (from the side, so it's not hidden behind the ute)
		_cam_yaw = float(car["yaw"]) + PI + 1.25
		_rmb = true
	_fake["gas"] = 0.0 if _demo_dv.has("pass_t") else 0.9
	if _demo_dv.has("pass_t") and t > float(_demo_dv["pass_t"]) + after:
		_shot(shot)
		return true
	if t > 14.0:
		print("[explore] never reached the %s" % shot)
		return true
	return false

## Puts the Hilux at `at` facing `to`, you in it.
func _demo_place(at: Vector2, to: Vector2, ute := "Hilux") -> void:
	var c: Dictionary = {}
	for u in utes:
		if u["name"] == ute:
			c = u
	var dir := (to - at).normalized()
	if mode == "drive" and not is_same(car, c):
		var old := car
		_get_out(true)
		# (and out of the way)
		old["pos"] = (old["pos"] as Vector2) + Vector2(-dir.y, dir.x) * 9.0
		old["v"] = Vector2.ZERO
	c["pos"] = at
	c["yaw"] = atan2(dir.x, dir.y)
	c["v"] = Vector2.ZERO
	c["yaw_rate"] = 0.0
	c["rb"] = false
	c["air"] = false
	c["vy"] = 0.0
	c["y"] = float(_ground_under(c)[0])
	c["dig"] = 0.0
	c["drowned"] = false
	c["flat"] = ""
	c["drive"] = "4H"
	if mode != "drive":
		_get_in(c)
	_cam_yaw = float(c["yaw"]) + PI
	_rmb = false
	_place_car(c, 0.0)

## Steers along `route` (its points in turn) at about `kmh`; true at the end.
func _demo_follow(route: PackedVector2Array, kmh: float) -> bool:
	var i: int = _demo_dv.get("wp", 1)
	var at: Vector2 = car["pos"]
	while i < route.size() and at.distance_to(route[i]) < 5.0:
		i += 1
	_demo_dv["wp"] = i
	if i >= route.size():
		return true
	var to := route[i] - at
	var dy := wrapf(atan2(to.x, to.y) - float(car["yaw"]), -PI, PI)
	_fake["move"] = Vector2(clampf(-dy * 2.5, -1.0, 1.0), 0)
	var spd := (car["v"] as Vector2).length() * 3.6
	_fake["gas"] = 1.0 if spd < kmh else 0.0
	return false

func _demo_park(t: float) -> void:
	if Engine.get_process_frames() % 20 == 0 and mode == "drive":
		print("[explore] park t %.1f %d km/h y %.2f pitch %.2f roll %.2f %s air %s %s" % [t, roundi((car["v"] as Vector2).length() * 3.6),
			car["y"], car["gp"], car["gr"], park.surface(car["pos"]), car["air"], car["pos"]])
	var e2: PackedVector2Array = PackedVector2Array(park.WAY_IN["Parkside"])
	match _demo_step:
		40:
			_demo_dv.clear()
			# from high over the creek, looking across the park
			_demo_dv["cam"] = [Vector3(-150.0, 90.0, -40.0), Vector3(-230.0, 0.0, 150.0)]
			if t > 0.6:
				_shot("park_overview")
			# (and from above each causeway)
			for i in park._fords.size():
				var fc: Vector2 = park._fords[i]["c"]
				if t > 0.8 + i * 0.6:
					_demo_dv["cam"] = [Vector3(fc.x + 10.0, 14.0, fc.y - 12.0), Vector3(fc.x, 0.0, fc.y)]
				if t > 1.2 + i * 0.6:
					_shot("park_ford_above%d" % i)
			if t > 1.0 + park._fords.size() * 0.6:
				_demo_dv.erase("cam")
				_demo_place(e2[0] + (e2[0] - e2[1]).normalized() * 9.0, e2[0])
				_next()
		41:
			if t > 0.8:
				_shot("park_mouth")
				_demo_dv["wp"] = 0
				_next()
		42:
			# in off Parkside Circuit, over the causeway and past the club's sign
			var route := e2.duplicate()
			route.append(Vector2(-330.0, 76.0))
			var near_ford := (car["pos"] as Vector2).distance_to(e2[1].lerp(e2[2], 0.35)) < 6.0
			if park.surface(car["pos"]) == "water" and not _shots.has("park_ford"):
				_cam_yaw = float(car["yaw"]) + PI + 1.1
				_rmb = true
				_demo_dv["ford_t"] = t
			if _demo_dv.has("ford_t") and t > float(_demo_dv["ford_t"]) + 0.3 and not _shots.has("park_ford"):
				_shot("park_ford")
				_rmb = false
			if _demo_follow(route, 22.0) or t > 40.0:
				# stop by the club sign for a look
				var sg := e2[e2.size() - 2] + (e2[e2.size() - 1] - e2[e2.size() - 2]).normalized() * 4.0
				var dir := (e2[e2.size() - 1] - e2[e2.size() - 2]).normalized()
				var spot: Vector2 = sg + Vector2(-dir.y, dir.x) * (park.TRACK_W * 0.5 + 1.8)
				_demo_place(spot - dir * 3.0 - Vector2(-dir.y, dir.x) * 3.2, spot + dir * 20.0 - Vector2(-dir.y, dir.x) * 3.2)
				# (looking at it the way you'd come in, the ute alongside)
				var eye := spot - dir * 9.0 - Vector2(-dir.y, dir.x) * 1.5
				_demo_dv["cam"] = [Vector3(eye.x, 2.4, eye.y), Vector3(spot.x, 1.5, spot.y)]
				print("[explore] near ford %s" % near_ford)
				_next()
		43:
			if t > 0.8:
				_shot("park_sign")
				# a run at the hill climb
				_demo_place(Vector2(-275.0, 77.0), Vector2(-330.0, 76.0))
				_demo_dv["wp"] = 1
				_next()
		44:
			if t > 0.2:
				_demo_dv.erase("cam")
			var route := PackedVector2Array([Vector2(-275.0, 77.0), Vector2(-300.0, 77.0), Vector2(-330.0, 76.0), Vector2(-360.0, 75.0), Vector2(-420.0, 75.0)])
			var x: float = (car["pos"] as Vector2).x
			if x < -337.0 and not _shots.has("park_climb"):
				_cam_yaw = float(car["yaw"]) + PI + 1.3
				_rmb = true
				_shot("park_climb")
			if car["air"] and not _shots.has("park_air"):
				_demo_dv["air_t"] = t
				_shot("park_air")
				print("[explore] airborne at %s y %.2f vy %.2f" % [car["pos"], car["y"], car["vy"]])
			if _demo_follow(route, 75.0) or t > 30.0:
				print("[explore] hill run done: top reached %s, dmg %.2f" % [_park_done.has("hill"), car["dmg"]])
				_rmb = false
				_demo_place(Vector2(-118.0, 171.0), Vector2(-142.0, 166.0))
				_demo_dv["wp"] = 1
				_next()
		45:
			var route := PackedVector2Array([Vector2(-118.0, 171.0), Vector2(-142.0, 166.0), Vector2(-178.0, 164.0), Vector2(-195.0, 150.0)])
			if (car["pos"] as Vector2).x < -158.0 and not _shots.has("park_bog"):
				_cam_yaw = float(car["yaw"]) + PI + 0.9
				_rmb = true
				_shot("park_bog")
			if _demo_follow(route, 25.0) or t > 30.0:
				print("[explore] bog done %s at %.1f s" % [_park_done.has("bog"), t])
				_rmb = false
				_demo_place(Vector2(-50.0, 269.0), Vector2(-128.0, 262.0))
				_demo_dv["wp"] = 1
				_next()
		46:
			var route := PackedVector2Array([Vector2(-50.0, 269.0), Vector2(-62.0, 268.0), Vector2(-128.0, 262.0), Vector2(-150.0, 225.0)])
			if (car["pos"] as Vector2).x < -90.0 and not _shots.has("park_dam"):
				_cam_yaw = float(car["yaw"]) + PI + 1.0
				_rmb = true
				_shot("park_dam")
			if _demo_follow(route, 10.0) or t > 30.0:
				print("[explore] dam done %s, drowned %s" % [_park_done.has("dam"), car["drowned"]])
				_rmb = false
				_demo_place(Vector2(-180.0, 162.0), Vector2(-200.0, 142.0))
				_demo_dv["wp"] = 1
				_next()
		47:
			var route := PackedVector2Array([Vector2(-180.0, 162.0), Vector2(-200.0, 142.0), Vector2(-240.0, 110.0), Vector2(-260.0, 98.0)])
			if (car["pos"] as Vector2).x < -208.0 and not _shots.has("park_sand"):
				_cam_yaw = float(car["yaw"]) + PI + 0.8
				_rmb = true
				_shot("park_sand")
			if _demo_follow(route, 35.0) or t > 30.0:
				print("[explore] sand done %s; done %s" % [_park_done.has("sand"), _park_done.keys()])
				_rmb = false
				# and the MacArthur Ave way in, from the road
				var e1: PackedVector2Array = PackedVector2Array(park.WAY_IN["MacArthur"])
				_demo_place(e1[0] + (e1[0] - e1[1]).normalized() * 8.0, e1[0])
				_next()
		48:
			if t > 0.8 and not _shots.has("park_mouth2"):
				_shot("park_mouth2")
			if t > 1.4 and not _shots.has("park_records"):
				# (the records board by the MacArthur gate, square on)
				var bd := (park.boards[0] as Node3D).get_parent() as Node3D
				var fwd := bd.basis.z
				_demo_dv["cam"] = [bd.position + fwd * 3.2 + Vector3(0, 1.8, 0), bd.position + Vector3(0, 1.8, 0)]
				_shot("park_records")
			if t > 2.2:
				_demo_dv.erase("cam")
				# flat out through the creek: shallow enough for a stock ute
				var e1: PackedVector2Array = PackedVector2Array(park.WAY_IN["MacArthur"])
				_demo_dv["route"] = e1.slice(2)
				_demo_place(e1[2], e1[3])
				car["drive"] = "4H"
				_demo_dv["wp"] = 1
				_next()
		49:
			if Engine.get_process_frames() % 10 == 0:
				print("[explore] ford run %d km/h %s surf %s drowned %s" % [roundi((car["v"] as Vector2).length() * 3.6), car["pos"],
					park.surface(car["pos"]), car.get("drowned", false)])
			if _demo_follow(_demo_dv["route"], 60.0) or t > 25.0:
				print("[explore] ford run done: drowned %s at %s" % [car.get("drowned", false), car["pos"]])
				print("[explore] demo done")
				_quit_code = 0

## Lines a ute up 12 m short of an obstacle, to drive straight over it.
func _demo_obstacle(kind: String, ute: String, drive: String) -> void:
	var o: Dictionary = {}
	for ob in park._obs:
		if ob["kind"] == kind:
			o = ob
	var ax := Vector2(cos(float(o["yaw"])), sin(float(o["yaw"])))
	var a: float = o["a"]
	var from: Vector2 = (o["c"] as Vector2) - ax * (a + 12.0)
	_demo_dv["route"] = PackedVector2Array([from, (o["c"] as Vector2) + ax * (a + 10.0)])
	_demo_dv["wp"] = 1
	var c: Dictionary = {}
	for u in utes:
		if u["name"] == ute:
			c = u
	if mode == "drive" and not is_same(car, c):
		var old := car
		_get_out(true)
		# (and out of the way)
		old["pos"] = (old["pos"] as Vector2) + Vector2(-ax.y, ax.x) * 8.0
		old["v"] = Vector2.ZERO
	c["pos"] = from
	c["yaw"] = atan2(ax.x, ax.y)
	c["v"] = Vector2.ZERO
	c["yaw_rate"] = 0.0
	c["rb"] = false
	c["air"] = false
	c["vy"] = 0.0
	c["y"] = float(_ground_under(c)[0])
	c["dig"] = 0.0
	c["drowned"] = false
	c["dmg"] = 0.0
	if mode != "drive":
		_get_in(c)
	c["drive"] = drive
	_cam_yaw = float(c["yaw"]) + PI
	_place_car(c, 0.0)

## The 4x4 run (--explore=4x4): the wheels working over a twist, crawling
## onto the hill's lip, spinning in the bog in 2H, airing down for the sand,
## and drowning one in the deep end of the dam.
func _demo_4x4(t: float) -> void:
	if mode == "drive" and Engine.get_process_frames() % 10 == 0:
		print("[explore] 4x4 t %.1f %s %d km/h %s psi %d slip %.2f dig %.2f belly %.2f lift %s woff %s surf %s drowned %s" % [t,
			car["drive"], roundi((car["v"] as Vector2).length() * 3.6), car["pos"], roundi(float(car["psi"])), car["slip"],
			car["dig"], car["belly"], car["lift"], (car["woff"] as Array).map(func(x): return snappedf(x, 0.01)),
			park.surface(car["pos"]), car["drowned"]])
	match _demo_step:
		60:
			# the worst twist round the hill's flanks that's still drivable
			var best := [0.0, Vector2.ZERO, 0.0]
			for ix in range(-30, 31, 2):
				for iy in range(-26, 27, 2):
					var q := Vector2(-360.0 + ix, 75.0 + iy)
					for k in 8:
						var yw := k * PI / 8.0
						var f := Vector2(sin(yw), cos(yw))
						var l := Vector2(f.y, -f.x)
						var h := [park.height(q + f * 1.7 + l * 0.77), park.height(q + f * 1.7 - l * 0.77),
							park.height(q - f * 1.4 + l * 0.77), park.height(q - f * 1.4 - l * 0.77)]
						var e := absf(float(h[0]) - float(h[1]) - float(h[2]) + float(h[3])) * 0.25
						var gp := absf(atan2((float(h[0]) + float(h[1]) - float(h[2]) - float(h[3])) * 0.5, 3.1))
						var gr := absf(atan2((float(h[0]) + float(h[2]) - float(h[1]) - float(h[3])) * 0.5, 1.54))
						if e > float(best[0]) and e < 0.2 and gp < 0.35 and gr < 0.3:
							best = [e, q, yw]
			print("[explore] twist spot %s yaw %.2f twist %.2f m" % [best[1], best[2], best[0]])
			var at: Vector2 = best[1]
			var yw: float = best[2]
			_demo_place(at, at + Vector2(sin(yw), cos(yw)) * 10.0)
			var side := Vector2(cos(yw), -sin(yw))
			var eye := at + side * 6.5 + Vector2(sin(yw), cos(yw)) * 2.5
			_demo_dv["cam"] = [Vector3(eye.x, park.height(at) + 1.2, eye.y), Vector3(at.x, park.height(at) + 0.5, at.y)]
			_next()
		61:
			_fake["hold_a"] = true
			var at: Vector2 = car["pos"]
			var yw: float = car["yaw"]
			var side := Vector2(cos(yw), -sin(yw))
			# (from the downhill side, looking up under the arches)
			if park.height(at - side * 7.0) < park.height(at + side * 7.0):
				side = -side
			var eye := at + side * 7.5 + Vector2(sin(yw), cos(yw)) * 2.0
			var gy := float(car["y"])
			_demo_dv["cam"] = [Vector3(eye.x, maxf(park.height(eye) + 1.0, gy + 0.9), eye.y), Vector3(at.x, gy + 0.6, at.y)]
			if t > 1.2 and not _shots.has("4x4_twist"):
				_shot("4x4_twist")
			if t > 1.8:
				print("[explore] twist: lift %s woff %s raise %.2f" % [car["lift"], car["woff"], car["raise"]])
				print("[explore] twist node %s cam %s air %s y %.2f" % [(car["node"] as Node3D).global_position, cam.global_position, car["air"], car["y"]])
				_demo_dv.erase("cam")
				_demo_place(Vector2(-332.0, 76.0), Vector2(-380.0, 75.0))
				car["drive"] = "4L"
				_demo_dv["wp"] = 1
				_next()
		62:
			# crawling up the face in 4L and onto the lip: the belly finds it
			if float(car["belly"]) > 0.15 and not _shots.has("4x4_crest"):
				_cam_yaw = float(car["yaw"]) + PI + 1.5
				_rmb = true
				_shot("4x4_crest")
				print("[explore] high-centred at %s belly %.2f lift %s" % [car["pos"], car["belly"], car["lift"]])
			if (car["pos"] as Vector2).x < -345.0 and not _shots.has("4x4_climb"):
				_cam_yaw = float(car["yaw"]) + PI + 1.4
				_rmb = true
				_shot("4x4_climb")
			if _demo_follow(PackedVector2Array([Vector2(-332.0, 76.0), Vector2(-380.0, 75.0)]), 8.0) or t > 30.0:
				print("[explore] crawl done at %s in %.1f s" % [car["pos"], t])
				_rmb = false
				_demo_place(Vector2(-126.0, 169.0), Vector2(-195.0, 162.0))
				car["drive"] = "2H"
				_demo_dv["wp"] = 1
				_next()
		63:
			# the bog in 2H: the back wheels dig in; tap Y for 4H and out
			var pos: Vector2 = car["pos"]
			if car["drive"] == "2H" and park.surface(pos) == "mud" and float(car["slip"]) > 0.3:
				_demo_dv["spin_t"] = float(_demo_dv.get("spin_t", 0.0)) + get_process_delta_time()
				if float(_demo_dv["spin_t"]) > 1.0 and not _shots.has("4x4_spin"):
					_cam_yaw = float(car["yaw"]) + PI + 0.8
					_rmb = true
					_shot("4x4_spin")
				if float(_demo_dv["spin_t"]) > 3.0 and not _demo_dv.has("tapped"):
					_fake["run"] = true   # (a tap on Y: released next frame)
					_demo_dv["tapped"] = true
					print("[explore] 2H stuck in the bog at %s; into 4H" % pos)
			if _demo_follow(PackedVector2Array([Vector2(-126.0, 169.0), Vector2(-195.0, 162.0)]), 14.0) or t > 30.0:
				print("[explore] bog run done at %s in %.1f s, %s" % [car["pos"], t, car["drive"]])
				_rmb = false
				_demo_place(Vector2(-186.0, 157.0), Vector2(-206.0, 136.0))
				car["drive"] = "4H"
				_next()
		64:
			# stop, hold Y: the tyres go down to 18
			_fake["run"] = t > 0.3 and t < 1.3
			if float(car["psi"]) <= Offroad.PSI_LOW + 0.1 and not _shots.has("4x4_aired"):
				var at: Vector2 = car["pos"]
				var yw: float = car["yaw"]
				var w := at + Vector2(sin(yw), cos(yw)) * 1.7 + Vector2(-cos(yw), sin(yw)) * 2.8
				_demo_dv["cam"] = [Vector3(w.x, park.height(at) + 0.7, w.y), Vector3(at.x, park.height(at) + 0.4, at.y) + Vector3(sin(yw), 0, cos(yw)) * 1.0]
				_shot("4x4_aired")
				_demo_dv["wp"] = 1
				_demo_dv["air_t"] = t
			if _demo_dv.has("air_t") and t > float(_demo_dv["air_t"]) + 0.4:
				_demo_dv.erase("cam")
				if _demo_follow(PackedVector2Array([Vector2(-186.0, 157.0), Vector2(-206.0, 136.0), Vector2(-240.0, 110.0)]), 30.0) or t > 30.0:
					print("[explore] sand aired down done at %s, dig %.2f" % [car["pos"], car["dig"]])
					var ap: Vector2 = park.air_posts[1]
					_demo_place(ap + Vector2(4.0, -2.0), ap + Vector2(20.0, -10.0))
					_next()
		65:
			# and back up at the FREE AIR post
			_fake["run"] = t > 0.3 and t < 1.3
			if t > 0.6 and not _shots.has("4x4_airpost"):
				var ap: Vector2 = park.air_posts[1]
				_demo_dv["cam"] = [Vector3(ap.x - 6.0, 2.2, ap.y + 5.0), Vector3(ap.x + 2.0, 0.8, ap.y - 1.0)]
				_shot("4x4_airpost")
			if float(car["psi"]) >= Offroad.PSI_ROAD - 0.1 or t > 12.0:
				print("[explore] pumped up to %d psi at %.1f s" % [roundi(float(car["psi"])), t])
				_demo_dv.erase("cam")
				# into the dam off the track, too quick, where it's deepest
				var deep := Vector2.ZERO
				var dh := 0.0
				var bb := Rect2(park.dam[0], Vector2.ZERO)
				for q in park.dam:
					bb = bb.expand(q)
				for ix in range(int(bb.position.x), int(bb.end.x), 2):
					for iz in range(int(bb.position.y), int(bb.end.y), 2):
						var hq := park.height(Vector2(ix, iz))
						if hq < dh:
							dh = hq
							deep = Vector2(ix, iz)
				var from := deep
				for k in 16:
					var d := Vector2.from_angle(k * TAU / 16.0)
					var q := deep + d * 9.0
					if park.height(q) > -0.35 and not park.on_track(q, park.TRACK_W):
						from = deep + d * 14.0
						break
				print("[explore] dam deep end %s %.2f m; in from %s" % [deep, dh, from])
				_demo_dv["dam"] = PackedVector2Array([from, deep + (deep - from).normalized() * 6.0])
				_demo_place(from, deep)
				car["drive"] = "4H"
				_demo_dv["wp"] = 1
				_next()
		66:
			if car["drowned"] and not _shots.has("4x4_drowned"):
				_cam_yaw = float(car["yaw"]) + PI + 1.0
				_rmb = true
				_demo_dv["drown_t"] = t
				_shot("4x4_drowned")
			var done := _demo_follow(_demo_dv["dam"], 15.0)
			if (_demo_dv.has("drown_t") and t > float(_demo_dv["drown_t"]) + 1.0) or done or t > 20.0:
				print("[explore] dam: drowned %s at %s" % [car["drowned"], car["pos"]])
				_rmb = false
				_demo_obstacle("moguls", "Hilux", "4H")
				_next()
		67:
			# the moguls in 4H: a wheel in the air spins and it stops; tap Y
			# to 4L, again for the locker, and it walks through
			var r: PackedVector2Array = _demo_dv["route"]
			if (car["lift"] as Array).has(true) and not _shots.has("4x4_moguls"):
				_cam_yaw = float(car["yaw"]) + PI + 1.3
				_rmb = true
				_shot("4x4_moguls")
				print("[explore] moguls: lift %s woff %s" % [car["lift"], car["woff"]])
			if float(car["slip"]) > 0.3 and (car["v"] as Vector2).length() < 0.4 and car["drive"] != "4L+LOCK":
				_demo_dv["stall_t"] = float(_demo_dv.get("stall_t", 0.0)) + get_process_delta_time()
				if float(_demo_dv["stall_t"]) > 1.5:
					_demo_dv["stall_t"] = 0.0
					_fake["run"] = true
					print("[explore] moguls: stalled in %s at %s, tap Y" % [car["drive"], car["pos"]])
			if _demo_follow(r, 7.0) or t > 40.0:
				print("[explore] moguls done in %s at %s, %.1f s; medal %s" % [car["drive"], car["pos"], t, _park_medal.get("moguls", "-")])
				_rmb = false
				_demo_obstacle("logs", "Hilux", "4L")
				_next()
		68:
			# the log step: a stock Hilux's bumper digs in
			var r: PackedVector2Array = _demo_dv["route"]
			if car.get("dug", false) and not _shots.has("4x4_logs_dug"):
				_cam_yaw = float(car["yaw"]) + PI + 1.4
				_rmb = true
				_shot("4x4_logs_dug")
				print("[explore] logs: Hilux dug in at %s" % [car["pos"]])
				_demo_dv["dug_t"] = t
			if _demo_follow(r, 6.0) or t > 14.0 or (_demo_dv.has("dug_t") and t > float(_demo_dv["dug_t"]) + 2.0):
				print("[explore] logs Hilux: at %s, dug %s" % [car["pos"], car.get("dug", false)])
				_rmb = false
				_demo_obstacle("logs", "Shark", "AWD")
				_next()
		69:
			# and the Shark's 31° nose clears it
			var r: PackedVector2Array = _demo_dv["route"]
			var o: Dictionary = park._obs[1]
			if (car["pos"] as Vector2).distance_to(o["c"]) < 1.0 and not _shots.has("4x4_logs_shark"):
				_cam_yaw = float(car["yaw"]) + PI + 1.4
				_rmb = true
				_shot("4x4_logs_shark")
			if _demo_follow(r, 6.0) or t > 20.0:
				print("[explore] logs Shark: at %s, dug %s, medal %s" % [car["pos"], car.get("dug", false), _park_medal.get("logs", "-")])
				print("[explore] boards: %s" % (park.boards[0] as Label3D).text.replace("\n", " | "))
				print("[explore] demo done")
				_quit_code = 0

## The recovery run (--explore=recovery): a Hilux with a bar and winch bogs
## itself in 2H and winches out; a stock Ranger bogs and a mate snatches it
## out; then the winch Hilux noses into the log step with a spotter calling
## it, and winches itself over.
func _demo_recovery(t: float) -> void:
	if mode == "drive" and Engine.get_process_frames() % 10 == 0:
		print("[explore] rec t %.1f %s %d km/h %s stuck %.1f dig %.2f belly %.2f rec %s spot %s" % [t, car["name"],
			roundi((car["v"] as Vector2).length() * 3.6), car["pos"], car["stuck"], car["dig"], car["belly"],
			_rec.get("kind", "-"), _spot != null])
	var bog := PackedVector2Array([Vector2(-126.0, 169.0), Vector2(-195.0, 162.0)])
	match _demo_step:
		70:
			_demo_dv.clear()
			for u in utes:
				if u["name"] == "Hilux":
					Utes.apply_kit(u["node"], "hilux", ["bullbar", "winch"])
					_offroad(u, ["bullbar", "winch"])
			_demo_place(bog[0], bog[1])
			car["drive"] = "2H"
			_demo_dv["wp"] = 1
			_next()
		71:
			# bogged in 2H, foot down; then hold A and winch out
			if _rec.is_empty() and not car.get("winched", false):
				_demo_follow(bog, 14.0)
				if float(car["stuck"]) > 1.5:
					_fake["hold_a"] = true
					_fake["gas"] = 0.3
			elif _rec.get("kind", "") == "winch":
				_fake["hold_a"] = true
				_fake["gas"] = 0.3
				if float(_rec["t"]) > 2.5 and not _shots.has("rec_winch"):
					var at: Vector2 = car["pos"]
					var yw: float = car["yaw"]
					var eye := at + Vector2(cos(yw), -sin(yw)) * 7.0 + Vector2(sin(yw), cos(yw)) * 5.0
					_demo_dv["cam"] = [Vector3(eye.x, float(car["y"]) + 2.4, eye.y), Vector3(at.x, float(car["y"]) + 0.6, at.y) + Vector3(sin(yw), 0, cos(yw)) * 4.0]
					_shot("rec_winch")
				if float(_rec["t"]) > 9.0:
					_fake["hold_a"] = false
			if (car.get("winched", false) and _rec.is_empty()) or t > 45.0:
				print("[explore] winch done at %s in %.1f s, winched %s, dig %.2f" % [car["pos"], t, car.get("winched", false), car["dig"]])
				_demo_dv.erase("cam")
				_demo_place(bog[0] + Vector2(0.0, -4.0), bog[1] + Vector2(0.0, -4.0), "Ranger")
				car["drive"] = "2H"
				_demo_dv["wp"] = 1
				_next()
		72:
			# a stock Ranger: bogged, and a mate turns up with a snatch strap
			if _rec.is_empty() and not car.get("rescued", false):
				_demo_follow(PackedVector2Array([bog[0] + Vector2(0.0, -4.0), bog[1] + Vector2(0.0, -4.0)]), 14.0)
			if _rec.get("kind", "") == "strap" and float(_rec["t"]) > 1.7 and not _shots.has("rec_strap"):
				var at: Vector2 = car["pos"]
				var dir: Vector2 = _rec["dir"]
				var side := Vector2(-dir.y, dir.x)
				var eye := at + side * 9.0 + dir * 3.0
				_demo_dv["cam"] = [Vector3(eye.x, float(car["y"]) + 2.6, eye.y), Vector3(at.x, float(car["y"]) + 0.6, at.y) + Vector3(dir.x, 0, dir.y) * 4.0]
				_shot("rec_strap")
			if (car.get("rescued", false) and _rec.is_empty()) or t > 45.0:
				print("[explore] strap done at %s in %.1f s, rescued %s" % [car["pos"], t, car.get("rescued", false)])
				_demo_dv.erase("cam")
				_demo_obstacle("logs", "Hilux", "4L")
				_next()
		73:
			# the bull bar sits low: it noses into the logs with the spotter
			# calling stop; winch it over
			var r: PackedVector2Array = _demo_dv["route"]
			if _spot != null and _spot_call.begins_with("STOP") and not _shots.has("rec_spotter"):
				var at: Vector2 = car["pos"]
				var yw: float = car["yaw"]
				var eye := at + Vector2(cos(yw), -sin(yw)) * 6.0 - Vector2(sin(yw), cos(yw)) * 3.0
				_demo_dv["cam"] = [Vector3(eye.x, float(car["y"]) + 2.2, eye.y), Vector3(at.x, float(car["y"]) + 0.8, at.y) + Vector3(sin(yw), 0, cos(yw)) * 4.0]
				_shot("rec_spotter")
				_demo_dv["stop_t"] = t
			if _demo_dv.has("stop_t") and t > float(_demo_dv["stop_t"]) + 0.6:
				_demo_dv.erase("cam")
				_fake["hold_a"] = t < float(_demo_dv["stop_t"]) + 12.0
				_fake["gas"] = 0.3 if _fake["hold_a"] else 0.0
				if _rec.get("kind", "") == "winch" and float(_rec["t"]) > 4.0 and not _shots.has("rec_logs_winch"):
					_cam_yaw = float(car["yaw"]) + PI + 1.3
					_rmb = true
					_shot("rec_logs_winch")
			elif not _demo_dv.has("stop_t"):
				_demo_follow(r, 4.0)
			if (_demo_dv.has("stop_t") and t > float(_demo_dv["stop_t"]) + 13.0) or t > 40.0:
				print("[explore] logs winch: at %s, winched %s, medal %s" % [car["pos"], car.get("winched", false), _park_medal.get("logs", "-")])
				print("[explore] demo done")
				_quit_code = 0

func _demo_find(kind: String) -> Dictionary:
	var best := {}
	var bd := INF
	var home: Vector2 = _fer.get("spawn", Vector2.ZERO)
	for it in crash._items:
		if it["kind"] == kind and not it["down"]:
			var dd := (it["p"] as Vector2).distance_to(home)
			if dd < bd:
				bd = dd
				best = it
	return best

func _demo_crash(t: float) -> void:
	_fake["gas"] = 0.0
	match _demo_step:
		20:
			# off the line, flat out: the revs, the gears and 0 to 100
			var it := _demo_find("flat")
			_demo_line_up(it["p"], 45.0)
			_demo_dv = {"sign": it}
			_next()
		21:
			_fake["gas"] = 1.0
			if Engine.get_process_frames() % 10 == 0:
				print("[explore] t %.1f %d km/h D%d %d rpm" % [t, roundi((car["v"] as Vector2).length() * 3.6), car["gear"], car["rpm"]])
			if t > 1.0 and not _shots.has("revs"):
				_shot("revs")
			if (_demo_dv["sign"] as Dictionary)["down"]:
				_demo_mark = _demo_t
				_demo_step = 22
			elif t > 12.0:
				print("[explore] missed the sign")
				_next()
		22:
			if t > 0.25:
				_shot("sign")
				var it := _demo_find("tree")
				_demo_line_up(it["p"], 24.0)
				_next()
		23:
			if _demo_run(t, "tree", 1.2):
				print("[explore] after the tree: dmg %.2f" % car["dmg"])
				# a bird
				var w: Dictionary = crash._birds._walkers[0]
				var n: Node3D = w["node"]
				w["pause"] = 99.0
				_demo_line_up(Vector2(n.position.x, n.position.z), 18.0)
				_next()
		24:
			if _demo_run(t, "roadkill", 0.5):
				# a cyclist
				var bike: Dictionary = {}
				for w in crash._people._walkers:
					if w["kind"] == "bike":
						bike = w
						break
				if bike.is_empty():
					bike = crash._people._walkers[0]
				bike["pause"] = 99.0
				var n: Node3D = bike["node"]
				_demo_line_up(Vector2(n.position.x, n.position.z), 16.0)
				_next()
		25:
			if _demo_run(t, "cyclist", 0.6):
				# a building, hard: head on at a wall with a clear 45 m run up
				var home: Vector2 = _fer.get("spawn", Vector2.ZERO)
				var order: Array = []
				for bp in _bpolys:
					var dd: float = (bp[0] as Vector2).distance_to(home)
					if dd > 30.0 and dd < 500.0:
						order.append([dd, bp])
				order.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
				var found := false
				for o in order:
					var poly: PackedVector2Array = o[1]
					for i in poly.size():
						var p0 := poly[i]
						var p1 := poly[(i + 1) % poly.size()]
						if p0.distance_to(p1) < 6.0:
							continue
						var mid := (p0 + p1) * 0.5
						var n := (p1 - p0).normalized().orthogonal()
						if _in_building(mid + n * 0.8):
							n = -n
						var ok := true
						for k in range(1, 46, 2):
							var q := mid + n * float(k)
							if _blocked(q) or _is_wet(q) or not crash.near(q, 2.0).is_empty():
								ok = false
								break
						if ok:
							_demo_line_up(mid, 44.0, "Ranger", -n)
							found = true
							break
					if found:
						break
				if not found:
					print("[explore] no clear wall found")
				_next()
		26:
			_fake["gas"] = 1.0 if not car["rb"] and float(car["dmg"]) < 0.5 else 0.0
			if car["rb"] and not _shots.has("crash"):
				_demo_dv["crash_t"] = t
			if _demo_dv.has("crash_t") and t > float(_demo_dv["crash_t"]) + 0.35:
				_shot("crash")
			if _shots.has("crash") and not car["rb"] and t > float(_demo_dv.get("crash_t", 0.0)) + 1.0:
				_cam_yaw += 1.6
				_cam_dist = 7.0
				_rmb = true
				_demo_dv["wreck_t"] = t
				_next()
			if t > 20.0:
				print("[explore] never crashed: dmg %.2f rb %s" % [car["dmg"], car["rb"]])
				_next()
		27:
			if t > 1.0:
				_shot("wreck")
				print("[explore] after the building: dmg %.2f bent %s" % [car["dmg"], car["bent"]])
				# a rollover on the open road: flat out, then the handbrake and full lock
				var c: Dictionary = {}
				for u in utes:
					if u["name"] == "Hilux":
						c = u
				_get_out(true)
				var r: Dictionary = _d["roads"][0]
				var best_len := 0.0
				for rr in _d["roads"]:
					var pts: Array = rr["pts"]
					for i in range(1, pts.size()):
						var a := Vector2(pts[i - 1][0], pts[i - 1][1])
						var b := Vector2(pts[i][0], pts[i][1])
						if a.distance_to(b) > best_len and a.length() < 600.0:
							best_len = a.distance_to(b)
							_demo_dv["road"] = [a, b]
				var ab: Array = _demo_dv["road"]
				var dir := ((ab[1] as Vector2) - (ab[0] as Vector2)).normalized()
				c["pos"] = ab[0]
				c["yaw"] = atan2(dir.x, dir.y)
				c["v"] = dir * 30.0
				c["rb"] = false
				_get_in(c)
				_rmb = false
				print("[explore] road %.0f m long" % best_len)
				_next()
		28:
			_fake["gas"] = 1.0
			if t > 1.0:
				_fake["hold_a"] = true
				_fake["move"] = Vector2(1.0, 0)
			if car["rb"] and not _demo_dv.has("roll_t"):
				_demo_dv["roll_t"] = t
			if _demo_dv.has("roll_t") and t > float(_demo_dv["roll_t"]) + 0.5:
				_shot("rollover")
			if _shots.has("rollover") and not car["rb"]:
				print("[explore] back on its wheels after %.1f s, dmg %.2f" % [t - float(_demo_dv["roll_t"]), car["dmg"]])
				_shot("landed")
				print("[explore] demo done")
				_quit_code = 0
			if t > 25.0:
				print("[explore] stuck: rb %s mode %s" % [car["rb"], mode])
				_quit_code = 1

func _next() -> void:
	print("[explore] step %d done at %.1fs (frame %d)" % [_demo_step, _demo_t, Engine.get_process_frames()])
	_demo_step += 1
	_demo_mark = _demo_t

# ------------------------------------------------------------------ the 4x4 dash (phone dash chips, pad D-pad)

## The phone's dash or the pad's D-pad, in the ute: the drive up and down
## (2H, 4H, 4L; the Shark AWD, MUD), the rear locker in and out (4L only),
## and the tyres let down or pumped up at a stop.
func _dash_controls(c: Dictionary, spd: float, inp: Dictionary) -> void:
	var dp: Dictionary = inp.get("dpad", {})
	var dash: String = inp.get("dash", "")
	if dash == "drive":
		_step_drive(c, spd, 1, true)
	elif dp.get("up", false):
		_step_drive(c, spd, 1, false)
	elif dp.get("down", false):
		_step_drive(c, spd, -1, false)
	if dp.get("right", false) or dash == "lock":
		_toggle_lock(c, spd)
	if dp.get("left", false) or dash == "air":
		if spd >= 0.6:
			_toast_msg("Stop first to do the tyres.")
		elif not c.has("air_job"):
			_start_air(c)

## One step along the drives, the locker left out (it has its own switch).
## The phone's one drive chip goes round and round; the pad's up and down
## stop at the ends.
func _step_drive(c: Dictionary, spd: float, dir: int, wrap: bool) -> void:
	var base: Array = []
	for m in c["off"]["modes"]:
		if not String(m).ends_with("+LOCK"):
			base.append(m)
	var i := base.find(String(c["drive"]).replace("+LOCK", ""))
	var j := i + dir
	if not wrap and (j < 0 or j >= base.size()):
		return
	_drive_to(c, base[posmod(j, base.size())], spd)

## The rear locker: in and out in 4L (the Shark has none).
func _toggle_lock(c: Dictionary, spd: float) -> void:
	if not ("4L+LOCK" in (c["off"]["modes"] as Array)):
		_toast_msg("No rear locker on this one. MUD mode grabs a spinning wheel instead.")
		return
	match String(c["drive"]):
		"4L":
			_drive_to(c, "4L+LOCK", spd)
		"4L+LOCK":
			_drive_to(c, "4L", spd)
			_toast_msg("Locker out.")
		_:
			_toast_msg("The locker goes in in 4L. Shift down to 4L first.")

## A tap on the phone's dash from person `p`: drive, lock or air.
func dash(p, what: String) -> void:
	if not active or (_who != null and p != _who):
		return
	_dash_q = what

## What the phone shows when knocked off: walking or driving, and in a ute
## the dash (drive, locker, tyres) and whether the winch is on offer.
func phone_state() -> Dictionary:
	var st := {"t": "roam", "m": mode}
	if mode == "drive" and not car.is_empty() and car.has("off"):
		var d := String(car["drive"])
		st["drive"] = d.replace("+LOCK", "")
		st["lock"] = d.ends_with("+LOCK")
		st["has_lock"] = "4L+LOCK" in (car["off"]["modes"] as Array)
		st["psi"] = roundi(float(car["psi"]))
		st["air"] = car.has("air_job")
		st["low"] = float(car["psi"]) < Offroad.PSI_ROAD - 1.0
		st["winch"] = "winch" in (car["kit"] as Array) and _hung_up(car)
	elif mode == "walk":
		st["near"] = "ute" if not _near_ute().is_empty() else ("boat" if _boat_ready() and _on_pontoon() else "")
	return st

## The tower crane's pour day (the real site trades plan, stage 6; board
## section 13). While the players pour, the crane, its driver and two
## doggers (all bots) keep lifting for the other trades. Each lift is the same
## small scene: the slinging dogger hooks a load on at the laydown on Ann St
## and radios it up, the crane flies it, the landing dogger radios it in
## ("slew left... lower away... all stop") and a trade crew carries it off.
##
## Spire: a lift list per level, in the real order: reo and stair frames for
## the steelies up on the jump form, ply and prop packs for the formies,
## bricks, post-tensioning coils, then edge screens for the scaffies on a
## loading platform out from the east face three floors under the deck (clear
## of the hung scaffold), and a full skip down to the gantry over the footpath.
## Riverlight: the other wing's lifts already run (west_wing.gd); this adds
## the same horn, shadow and wind stop to them.
##
## It touches the players lightly and never blocks the pour:
##   - a horn sounds and a shadow crosses the deck when a load passes over it
##   - the crane waits (up to BOOM_WAIT) if a placing boom is in its path
##   - in high wind the crane stops first (CRANE_WIND), before the boom has
##     to park (main.BOOM_WIND), so the boom op gets a warning
##   - no score or pay depends on it
extends Node3D

const F := preload("res://scripts/factory.gd")
const SpireSite := preload("res://scripts/spire_site.gd")

const SLING := 2.0           # hook to the top of the load
const H_SPD := 10.0          # m/s the hook travels round (slew and trolley; game-quick)
const V_SPD := 14.0          # m/s hoisting
const CRANE_WIND := 60.0     # km/h gust: the crane stops (the boom parks at main.BOOM_WIND, 72)
const WIND_BACK := 52.0      # km/h: under this for WIND_CALM s and it starts again
const WIND_CALM := 10.0
const BOOM_NEAR := 6.0       # m (across the ground) from a placing boom's head that the crane won't fly a load
const BOOM_WAIT := 20.0      # s it waits for a boom before going round it, higher
const CARRY_LEG := 2.4       # s a crew takes to carry a piece in, or come back for the next
const TRIPS := 3
const SAY_T := 2.2           # s a radio line shows

## The loads, what each looks like and who it's for.
const KINDS := {
	"reo":     {"name": "reo bundle", "trade": "steelies", "to": "core"},
	"frame":   {"name": "stair reo frame", "trade": "steelies", "to": "core"},
	"mesh":    {"name": "mesh", "trade": "steelies", "to": "core"},
	"ply":     {"name": "ply pack", "trade": "formies", "to": "platform"},
	"props":   {"name": "prop pack", "trade": "formies", "to": "platform"},
	"bricks":  {"name": "brick cage", "trade": "brickies", "to": "platform"},
	"pt":      {"name": "strand coil", "trade": "post-tensioners", "to": "platform"},
	"screens": {"name": "edge screens", "trade": "scaffies", "to": "platform"},
	"skip":    {"name": "full skip", "trade": "labourers", "to": "street"},
}
## The trades' shirts and hats (no pumpy orange or concreter green: those are the players')
const LOOKS := {
	"steelies": [Color("2d3f66"), Color("f4f7fa")], "formies": [Color("e2d05a"), Color("3a7bd5")],
	"brickies": [Color("b5562e"), Color("f4f7fa")], "post-tensioners": [Color("6b7280"), Color("f4f7fa")],
	"scaffies": [Color("23272e"), Color("f4f7fa")], "labourers": [Color("2a9d8f"), Color("f4f7fa")],
	"doggers": [Color("3a6bd1"), Color("f4f7fa")],
}
const FACES := [{"skin": "e8b48a", "hair": "2b1d14", "look": "beard"}, {"skin": "c98e62", "hair": "121212", "look": "sunnies"},
	{"skin": "f2c9a0", "hair": "8a5a2e", "look": "moustache"}, {"skin": "8d5a3b", "hair": "121212", "look": ""},
	{"skin": "f2c9a0", "hair": "c9a060", "look": "ponytail"}, {"skin": "d9a37a", "hair": "4a3122", "look": "earmuffs"}]

## The loading platform: out from the east face (game +x) at the Clark Lane end.
const PLAT_EDGE := Vector2(18.4, -19.0)   # where it meets the slab edge
const PLAT_SIZE := Vector2(5.6, 4.0)      # out from the face, along it
## How far in from the platform's outer end a load lands: well out past the hung scaffold's outside
## face (1.55 m off the slab) and its mesh, so the hook and its load come down in clear air and
## never through the scaffold or the deck's edge.
const PLAT_LAND := 1.5
## Where the steelies land things on the jump form's top deck (inside its ring).
const CORE_SPOTS := [Vector2(-4.2, -16.4), Vector2(2.2, -21.6)]
## The laydown: on the deck of the gantry over Ann St's footpath, east of
## the crane's foot (spire_street.gd _gantry), the way a CBD site with no
## yard uses it. The kerb lane's the trucks' and the footpath stays open under it.
const LAY_X := [26.6, 28.4, 30.2]
const SKIP_X := 32.0
const GANTRY_TOP := 3.3 + 0.16           # spire_street.gd DECK_Y, and the deck's planks

var game
var level := -1
var on := false              # lifts are running this level (Spire)
var lifts: Array = []        # {kind, at, node, state, pick, to, ...}
var _i := -1                 # the lift on the hook
var _state := ""             # "" / "to_pick" / "rig" / "hold" / "lift" / "land" / "clear"
var _t := 0.0
var _st := 0.0               # s in the state
var _move := {}
var _wait_boom := 0.0
var _go_high := false
var _inner: Callable         # whoever had the crane before (Riverlight: the west wing)
var _wind_stop := false
var _wind_told := false      # (the toast once a level; the radio says it after that)
var _calm := 0.0
var _over := false           # the load's over our deck now
var _slings: Array[MeshInstance3D] = []
var _shadow: MeshInstance3D
var _platform: Node3D
var _slinger: Node3D
var _lander: Node3D
var _doggers: Array[Node3D] = []
var _say: Array[Label3D] = []
var _say_t := [0.0, 0.0]
var _crews := {}             # trade -> [chibi, ...]
var _tags := {}              # trade -> Label3D over them
var _work := {}              # trade -> {"lift": i, "trip": n, "t": s} while they're carrying a load in
var _shot := ""              # dev: the shot this moment makes

func setup(g) -> void:
	game = g
	_shadow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 24
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.05, 0.06, 0.08, 0.38)
	sm.no_depth_test = false
	disc.material = sm
	_shadow.mesh = disc
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.visible = false
	add_child(_shadow)
	for i in 2:
		var sl := F.cylinder(0.03, 1.0, F.color_mat(Color("3a6bd1")), Vector3.ZERO, 5)
		sl.visible = false
		add_child(sl)
		_slings.append(sl)

# ------------------------------------------------------------------ a level

## A new level (main._start_floor): Spire gets its lift list; Riverlight
## keeps the west wing's, with the wind stop and the horn added.
func start_level(k: int) -> void:
	if game.tutorial or game.climb == null:
		return
	level = k
	_wind_told = false
	_i = -1
	_state = ""
	_move = {}
	_work.clear()
	_over = false
	_hide_slings()
	for l in lifts:
		(l["node"] as Node3D).queue_free()
	lifts.clear()
	if not (game.climb.borrow.is_valid() and game.climb.borrow.get_object() == self):
		_inner = game.climb.borrow
		game.climb.borrow = Callable(self, "_crane")
	on = game.spire
	if not on:
		return
	if _platform == null:
		_build_people()
	_build_platform()
	_build_lifts(k)
	for tr in _crews:
		for n in _crews[tr]:
			n.visible = tr == "steelies"
	_place_steelies(true)

## The lifts for level k: the real order (frames and reo, then deck packs,
## bricks, the PT gear, screens), 8 a level, varied a little floor to floor.
func _build_lifts(k: int) -> void:
	# (the full skip goes down first: it's been filling on the platform since yesterday)
	var list := ["reo", "skip", "frame" if k % 2 == 0 else "mesh", "ply", "props", "bricks", "pt" if k % 3 == 0 else "reo", "screens"]
	var ats := [0.0, 0.08, 0.17, 0.27, 0.37, 0.47, 0.57, 0.67]
	for j in list.size():
		var kind: String = list[j]
		var node := _make_load(kind)
		add_child(node)
		var l := {"kind": kind, "at": ats[j], "node": node, "state": "wait", "pick": Vector3.ZERO, "to": Vector3.ZERO, "spot": j % 2, "slot": -1}
		lifts.append(l)
	_lay_out()

## Where each load sits before it flies: the next three on the laydown, the
## skip full on the platform.
func _lay_out() -> void:
	var used := {}
	for l in lifts:
		if l["state"] in ["wait", "queued"] and int(l["slot"]) >= 0:
			used[int(l["slot"])] = true
	for j in lifts.size():
		var l: Dictionary = lifts[j]
		var node: Node3D = l["node"]
		if not l["state"] in ["wait", "queued"]:
			continue
		if l["kind"] == "skip":
			l["pick"] = _plat_spot(0.8)
			node.position = l["pick"]
			node.visible = true
			continue
		if int(l["slot"]) < 0:
			for s in LAY_X.size():
				if not used.has(s):
					l["slot"] = s
					used[s] = true
					var x: float = LAY_X[s]
					l["pick"] = _gantry(x)
					node.position = l["pick"]
					node.rotation.y = 0.0
					break
		node.visible = int(l["slot"]) >= 0

## A spot on the gantry's deck, halfway across it.
func _gantry(x: float) -> Vector3:
	return Vector3(x, GANTRY_TOP, (SpireSite.face_z(x) + 0.15 + 2.05) * 0.5)

## The platform's floor: three floors under the deck (the hung scaffold
## takes the two under it).
func _plat_y() -> float:
	return game.level_y(level - 2)

func _plat_spot(along: float) -> Vector3:
	return Vector3(PLAT_EDGE.x + PLAT_SIZE.x - PLAT_LAND, _plat_y(), PLAT_EDGE.y + (along - 0.5) * PLAT_SIZE.y * 0.7)

## The jump form's top deck (spire_site.set_core: 0.2 over the walls' top).
func _core_y() -> float:
	var lead := int(SpireSite.d["jump_form"]["lead_levels"])
	return game.level_y(mini(level + 1 + lead, game.floors() + 1)) + 0.2

func _landing(l: Dictionary) -> Vector3:
	match String(KINDS[l["kind"]]["to"]):
		"core":
			var c: Vector2 = CORE_SPOTS[int(l["spot"])]
			return Vector3(c.x, _core_y(), c.y)
		"street":
			return _gantry(SKIP_X)
	return _plat_spot(0.22)

# ------------------------------------------------------------------ building

func _build_platform() -> void:
	if _platform == null:
		_platform = Node3D.new()
		add_child(_platform)
		var grate := F.color_mat(Color("8b9096"))
		var rail := F.mat("yellow_dark")
		var frame := F.color_mat(Color("39414f"))
		var w := PLAT_SIZE.x
		var d := PLAT_SIZE.y
		# Deck plate, two cantilever beams back into the floor, and a gate-and-rail round three sides
		_platform.add_child(F.box(Vector3(w, 0.12, d), grate, Vector3(w * 0.5, -0.06, 0)))
		for s in [-1.0, 1.0]:
			_platform.add_child(F.box(Vector3(w + 2.4, 0.22, 0.18), frame, Vector3(w * 0.5 - 1.2, -0.23, s * (d * 0.5 - 0.15))))
			_platform.add_child(F.box(Vector3(w, 0.06, 0.06), rail, Vector3(w * 0.5, 1.0, s * d * 0.5)))
			_platform.add_child(F.box(Vector3(w, 0.06, 0.06), rail, Vector3(w * 0.5, 0.5, s * d * 0.5)))
			_platform.add_child(F.box(Vector3(w, 0.15, 0.03), rail, Vector3(w * 0.5, 0.07, s * d * 0.5)))
		_platform.add_child(F.box(Vector3(0.06, 1.0, d), rail, Vector3(w, 0.5, 0)))
		for c in [Vector2(0.05, -1), Vector2(0.05, 1), Vector2(w, -1), Vector2(w, 1)]:
			_platform.add_child(F.box(Vector3(0.08, 1.05, 0.08), rail, Vector3(c.x, 0.52, c.y * d * 0.5)))
		var tag := F.label3d("LOADING PLATFORM", 22, Color("ffc72c"))
		tag.position = Vector3(w * 0.5, 1.6, 0)
		tag.no_depth_test = false
		_platform.add_child(tag)
	_platform.position = Vector3(PLAT_EDGE.x, _plat_y(), PLAT_EDGE.y)

func _make_load(kind: String) -> Node3D:
	var n := Node3D.new()
	var steel := F.mat("steel")
	var reo := F.color_mat(Color("6b3a24"))
	match kind:
		"reo":
			n.add_child(F.prop("BarBundle", {}, F.SITE))
		"mesh":
			n.add_child(F.prop("MeshStack", {}, F.SITE))
		"frame":
			# (a pre-tied cage of bars, flown flat: a stair's or a wall's reo)
			for i in 6:
				n.add_child(F.box(Vector3(0.04, 0.04, 2.4), reo, Vector3(-0.9 + i * 0.36, 0.1, 0)))
				n.add_child(F.box(Vector3(0.04, 0.04, 2.4), reo, Vector3(-0.9 + i * 0.36, 0.5, 0)))
			for j in 7:
				n.add_child(F.box(Vector3(1.9, 0.04, 0.04), reo, Vector3(0, 0.1, -1.15 + j * 0.38)))
				n.add_child(F.box(Vector3(1.9, 0.04, 0.04), reo, Vector3(0, 0.5, -1.15 + j * 0.38)))
				n.add_child(F.box(Vector3(0.04, 0.44, 0.04), reo, Vector3(-0.9, 0.3, -1.15 + j * 0.38)))
				n.add_child(F.box(Vector3(0.04, 0.44, 0.04), reo, Vector3(0.9, 0.3, -1.15 + j * 0.38)))
		"ply":
			n.add_child(F.prop("PlyStack", {}, F.SITE))
		"props":
			n.add_child(F.prop("Pallet", {}, F.SITE))
			for r in 3:
				for c in 5:
					n.add_child(F.box(Vector3(2.4, 0.07, 0.07), steel, Vector3(0, 0.2 + r * 0.08, -0.2 + c * 0.1)))
		"bricks":
			# (a brick cage: pallets of brick inside a steel frame with a lifting bar)
			var brick := F.color_mat(Color("a8502f"))
			n.add_child(F.box(Vector3(1.2, 0.12, 1.0), F.color_mat(Color("9a7a52")), Vector3(0, 0.06, 0)))
			n.add_child(F.box(Vector3(1.1, 0.7, 0.9), brick, Vector3(0, 0.47, 0)))
			for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				n.add_child(F.box(Vector3(0.05, 1.3, 0.05), F.mat("yellow_dark"), Vector3(c.x * 0.62, 0.65, c.y * 0.52)))
			n.add_child(F.box(Vector3(1.3, 0.06, 0.06), F.mat("yellow_dark"), Vector3(0, 1.3, 0)))
		"pt":
			# (a coil of strand on its cradle)
			n.add_child(F.box(Vector3(1.4, 0.12, 1.4), F.color_mat(Color("9a7a52")), Vector3(0, 0.06, 0)))
			var coil := F.cylinder(0.65, 0.9, F.color_mat(Color("8d969c")), Vector3(0, 0.57, 0), 16)
			n.add_child(coil)
			n.add_child(F.cylinder(0.3, 0.92, F.color_mat(Color("3a3f45")), Vector3(0, 0.57, 0), 12))
		"screens":
			var s := F.prop("EdgeScreen", {}, F.SITE)
			s.rotation.x = -PI * 0.5
			s.position.y = 0.1
			n.add_child(s)
			for i in 4:
				n.add_child(F.box(Vector3(3.0, 0.05, 0.05), steel, Vector3(0, 0.3 + i * 0.06, 0.6)))
		"skip":
			n.add_child(F.prop("SkipBin", {}, F.SITE))
	n.set_meta("lug_y", 0.8 if kind in ["bricks", "pt"] else 0.4)
	return n

func _build_people() -> void:
	var fi := 0
	for tr in ["steelies", "formies", "brickies", "post-tensioners", "scaffies", "labourers"]:
		var list: Array = []
		var look: Array = LOOKS[tr]
		for j in (1 if tr == "labourers" else 2):
			var n := F.chibi(look[0], look[1])
			F.dress(n, FACES[fi % FACES.size()])
			fi += 1
			n.scale = Vector3.ONE * 1.05
			add_child(n)
			list.append(n)
		_crews[tr] = list
		var tag := F.label3d(tr.to_upper(), 20, Color("e8edf2"))
		tag.no_depth_test = false
		tag.visible = false
		add_child(tag)
		_tags[tr] = tag
	for j in 2:
		var d := F.chibi(LOOKS["doggers"][0], LOOKS["doggers"][1])
		F.dress(d, FACES[(j + 3) % FACES.size()])
		F.kit(d, "dogman")
		d.scale = Vector3.ONE * 1.05
		add_child(d)
		_doggers.append(d)
		var say := F.label3d("", 22, Color("ffe7a3"))
		say.visible = false
		add_child(say)
		_say.append(say)
	_slinger = _doggers[0]
	_lander = _doggers[1]

# ------------------------------------------------------------------ every frame

func _process(delta: float) -> void:
	if game == null or level < 0 or game.climb == null:
		return
	_t += delta
	var live: bool = game.phase in ["inspect", "pour"]
	_wind(delta, live)
	_watch_over_deck(live)
	for j in _say.size():
		_say_t[j] = maxf(0.0, _say_t[j] - delta)
		if _say_t[j] <= 0.0:
			_say[j].visible = false
	if not on:
		return
	if not live and _i >= 0:
		finish()
	var vis: bool = live or game.phase in ["screed", "columns"]
	visible = vis
	if not vis:
		return
	var frac: float = game._filled_ratio() if game.phase == "pour" else 0.0
	for l in lifts:
		if l["state"] == "wait" and frac >= float(l["at"]) and game.phase == "pour":
			l["state"] = "queued"
	_update_people(delta)

## The crane (climb.gd calls this each frame it isn't lifting for the climb):
## true while it has the hook.
func _crane(delta: float) -> bool:
	if not game.phase in ["inspect", "pour"] or level < 0:
		_hide_slings()
		return false
	if not on:
		# (Riverlight: the west wing's lifts, but not a new one while the wind's up)
		if _wind_stop and game.west != null and game.west._lift_i < 0:
			return false
		return _inner.is_valid() and _inner.call(delta)
	_st += delta
	if _i < 0:
		if _state == "clear":
			if _step_move(delta):
				_state = ""
			return true
		if _wind_stop:
			return false
		for j in lifts.size():
			if lifts[j]["state"] == "queued":
				_begin(j)
				break
		if _i < 0:
			_hide_slings()
			return false
	var l: Dictionary = lifts[_i]
	var node: Node3D = l["node"]
	match _state:
		"to_pick":
			if _step_move(delta):
				_set_state("rig")
		"rig":
			_slings_to(node, minf(1.0, _st / 0.9))
			if _st > 1.3:
				_radio(0, "Hooked on. Take it up!")
				_set_state("hold")
				_plan_move(node.global_position + Vector3(0, SLING + 1.2, 0), true)
		"hold":
			# (just off the ground: it waits there if a boom's where it's going)
			_step_move(delta)
			node.global_position = _hook() - Vector3(0, SLING, 0)
			_slings_to(node, 1.0)
			if not _move.is_empty():
				return true
			var blocked := _boom_in_way(l["to"]) and not _go_high
			if blocked:
				if _wait_boom == 0.0:
					_radio(1, "Hold it there. Boom's in the way.")
					if game.autotest:
						print("[autotest]   crane: %s held for a placing boom" % KINDS[l["kind"]]["name"])
				_wait_boom += delta
				if _wait_boom > BOOM_WAIT:
					_go_high = true
					_radio(1, "Take it round high, over the boom.")
				return true
			if _wait_boom > 0.0:
				_radio(1, "Boom's clear. Bring it on.")
			l["state"] = "fly"
			_set_state("lift")
			_plan_move(l["to"] + Vector3(0, SLING, 0), true, 10.0 if _go_high else 0.0)
			var da: float = _move.get("da", 0.0)
			if absf(da) > 0.15:
				_radio(1, "Slew %s..." % ("right" if da > 0.0 else "left"))
		"lift":
			var done := _step_move(delta)
			node.global_position = _hook() - Vector3(0, SLING, 0)
			node.rotation.y = lerp_angle(node.rotation.y, 0.4 if l["kind"] in ["reo", "screens"] else 0.0, minf(1.0, delta))
			_slings_to(node, 1.0)
			var u: float = float(_move.get("t", 1.0)) / float(_move.get("T", 1.0)) if not _move.is_empty() else 1.0
			if u > 0.72 and not l.has("lowered"):
				l["lowered"] = true
				_radio(1, "Lower away... easy...")
			if done:
				_set_state("land")
		"land":
			_slings_to(node, 1.0 - minf(1.0, _st / 0.9))
			if _st > 1.1:
				_land(l)
	return true

func _set_state(s: String) -> void:
	_state = s
	_st = 0.0

func _begin(j: int) -> void:
	_i = j
	var l: Dictionary = lifts[j]
	l["to"] = _landing(l)
	_wait_boom = 0.0
	_go_high = false
	_set_state("to_pick")
	_plan_move(l["pick"] + Vector3(0, SLING + 0.3, 0), false)

func _land(l: Dictionary) -> void:
	var node: Node3D = l["node"]
	node.global_position = l["to"]
	l["state"] = "landed"
	_radio(1, "All stop. She's down.")
	game.sfx.hit("thunk")
	var tr: String = KINDS[l["kind"]]["trade"]
	_work[tr] = {"lift": _i, "trip": 0, "t": 0.0}
	if game.autotest:
		print("[autotest]   crane: %s landed for the %s at %d%% of the pour" % [KINDS[l["kind"]]["name"], tr, int(game._filled_ratio() * 100.0)])
	_hide_slings()
	_i = -1
	_set_state("clear")
	_plan_move(_hook() + Vector3(0, 6.0, 0), false)
	_lay_out()

## Our slab's done (or the phase moved on): whatever's in the air is set
## down where it was going.
func finish() -> void:
	if not on or _i < 0:
		return
	var l: Dictionary = lifts[_i]
	if l["state"] == "fly":
		_land(l)
	else:
		l["state"] = "queued"
		_i = -1
		_set_state("")
	_hide_slings()

# ------------------------------------------------------------------ the hook

func _hook() -> Vector3:
	var c = game.climb
	return Vector3(c.trolley_xz.x, c.CRANE_H - c.cable_len + 0.4, c.trolley_xz.y)

func _set_hook(at: Vector3) -> void:
	var c = game.climb
	c.trolley_xz = Vector2(at.x, at.z)
	c.cable_len = c.CRANE_H + 0.4 - at.y

## Sets the hook travelling to `to`: slewing round the mast and trolleying at
## once, hoisting clear first with a load on and lowering in at the end (as
## west_wing.gd's).
func _plan_move(to: Vector3, loaded: bool, extra := 0.0) -> void:
	var mast: Vector3 = game.climb.MAST
	var from := _hook()
	var a0 := atan2(from.z - mast.z, from.x - mast.x)
	var a1 := atan2(to.z - mast.z, to.x - mast.x)
	var da := wrapf(a1 - a0, -PI, PI)
	var r0 := Vector2(from.x - mast.x, from.z - mast.z).length()
	var r1 := Vector2(to.x - mast.x, to.z - mast.z).length()
	var clear_y := maxf(from.y, to.y) + (6.0 if loaded else 3.0) + extra
	if loaded:
		# (over the deck it flies well above the crew and the boom's arms)
		clear_y = maxf(clear_y, game.deck_top() + 14.0 + extra)
	clear_y = minf(clear_y, game.climb.CRANE_H - 3.0)
	var horiz := absf(da) * maxf(r0, r1) + absf(r1 - r0)
	var vert := absf(clear_y - from.y) + absf(clear_y - to.y)
	var t := maxf(1.5, horiz / H_SPD + vert / V_SPD * 0.5)
	_move = {"a0": a0, "da": da, "r0": r0, "r1": r1, "y0": from.y, "y1": to.y, "yc": clear_y, "t": 0.0, "T": t}

func _step_move(delta: float) -> bool:
	if _move.is_empty():
		return true
	_move["t"] += delta
	var u := clampf(_move["t"] / _move["T"], 0.0, 1.0)
	_set_hook(_move_at(u))
	if u >= 1.0:
		_move = {}
		return true
	return false

func _move_at(u: float) -> Vector3:
	var s := smoothstep(0.2, 0.85, u)
	var a: float = _move["a0"] + _move["da"] * s
	var r: float = lerpf(_move["r0"], _move["r1"], s)
	var y: float
	if u < 0.3:
		y = lerpf(_move["y0"], _move["yc"], smoothstep(0.0, 0.3, u))
	elif u > 0.75:
		y = lerpf(_move["yc"], _move["y1"], smoothstep(0.75, 1.0, u))
	else:
		y = _move["yc"]
	var mast: Vector3 = game.climb.MAST
	return Vector3(mast.x + cos(a) * r, y, mast.z + sin(a) * r)

## Whether a placing boom's head is near the line the load would fly to `to`.
func _boom_in_way(to: Vector3) -> bool:
	var heads: Array = []
	if game.tip != null:
		heads.append(game.tip.global_position)
	if game.spire and game._spire_b != null:
		heads.append(game._spire_b.tip_pos)
	if heads.is_empty():
		return false
	var mast: Vector3 = game.climb.MAST
	var from := _hook()
	var a0 := atan2(from.z - mast.z, from.x - mast.x)
	var da := wrapf(atan2(to.z - mast.z, to.x - mast.x) - a0, -PI, PI)
	var r0 := Vector2(from.x - mast.x, from.z - mast.z).length()
	var r1 := Vector2(to.x - mast.x, to.z - mast.z).length()
	for s in 9:
		var u := (s + 1) / 10.0
		var a := a0 + da * u
		var r := lerpf(r0, r1, u)
		var p := Vector2(mast.x + cos(a) * r, mast.z + sin(a) * r)
		for h in heads:
			if p.distance_to(Vector2(h.x, h.z)) < BOOM_NEAR:
				return true
	return false

func _hide_slings() -> void:
	for s in _slings:
		s.visible = false

## Two-leg sling from the hook to the load's ends; `k` 0..1 as the dogger
## hooks it on (or off).
func _slings_to(node: Node3D, k: float) -> void:
	var hook := _hook() - Vector3(0, 0.3, 0)
	for j in 2:
		var end := node.global_transform * Vector3(-0.6 if j == 0 else 0.6, float(node.get_meta("lug_y", 0.4)), 0)
		var dangle := hook + Vector3(-0.15 if j == 0 else 0.15, -1.0, 0)
		F.stretch(_slings[j], hook, dangle.lerp(end, k))

# ------------------------------------------------------------------ the players' side

## The horn and the shadow: a load passing over our deck.
func _watch_over_deck(live: bool) -> void:
	var load_at := Vector3.INF
	if live and on and _i >= 0 and _state in ["lift", "land"]:
		load_at = (lifts[_i]["node"] as Node3D).global_position
	elif live and not on and game.west != null and game.west._crane_state == "lift" and game.west._lift_i >= 0:
		load_at = game.west._hook() - Vector3(0, 2.2, 0)
	var deck: float = game.deck_top()
	var over := load_at != Vector3.INF and load_at.y > deck + 2.0 and _on_deck(Vector2(load_at.x, load_at.z))
	if over and not _over:
		game.sfx.hit("horn")
		if game.autotest:
			print("[autotest]   crane: load over the deck (horn)")
	_over = over
	_shadow.visible = over
	if over:
		var hgt := load_at.y - deck
		_shadow.position = Vector3(load_at.x, deck + 0.04, load_at.z)
		var r := clampf(1.6 - hgt * 0.02, 1.0, 1.6)
		_shadow.scale = Vector3(r, 1.0, r)

func _on_deck(p: Vector2) -> bool:
	if game.spire:
		return Geometry2D.is_point_in_polygon(p, SpireSite.poly("plate"))
	var sc: Vector3 = game.SC
	return absf(p.x - sc.x) < game.BW * 0.5 and absf(p.y - sc.z) < game.BD * 0.5

## The crane stops for the wind before the boom has to park: that's the boom
## op's warning.
func _wind(delta: float, live: bool) -> void:
	var gust: float = game.climb.wind_gust
	if not live:
		_wind_stop = false
		_calm = 0.0
		return
	if not _wind_stop and gust >= CRANE_WIND:
		_wind_stop = true
		_calm = 0.0
		if not _wind_told:
			_wind_told = true
			game.hud.toast("Wind's at %d km/h: the crane's stopped. The boom parks at %d." % [int(gust), int(game.BOOM_WIND)], 3.0)
		if on:
			_radio(1, "Wind's up. Crane's stopping.")
		if game.autotest:
			print("[autotest]   crane: stopped for the wind at %d km/h" % int(gust))
	elif _wind_stop:
		_calm = _calm + delta if gust < WIND_BACK else 0.0
		if _calm > WIND_CALM:
			_wind_stop = false
			if on:
				_radio(1, "Wind's down. Crane's back on.")
			if game.autotest:
				print("[autotest]   crane: back on after the wind")

## A dogger's radio call: a line over their head and the radio's click.
func _radio(who: int, text: String) -> void:
	if _say.is_empty():
		return
	_say[who].text = "Radio · \"%s\"" % text
	_say[who].visible = true
	_say_t[who] = SAY_T
	game.sfx.hit("radio")

# ------------------------------------------------------------------ the people

func _place_steelies(snap := false) -> void:
	var list: Array = _crews.get("steelies", [])
	for j in list.size():
		var c: Vector2 = CORE_SPOTS[j]
		var at := Vector3(c.x + 1.2, _core_y(), c.y + 0.8)
		if snap:
			(list[j] as Node3D).position = at
		(list[j] as Node3D).set_meta("goal", at)

func _update_people(delta: float) -> void:
	# The doggers: the slinger at the load on the laydown, the lander where it's going
	var sg := _gantry(LAY_X[0] - 1.3)
	var lg := _plat_spot(0.0) + Vector3(-PLAT_SIZE.x * 0.3, 0, -0.6)
	var signal_up := false
	if _i >= 0:
		var l: Dictionary = lifts[_i]
		if _state in ["to_pick", "rig", "hold"]:
			sg = l["pick"] + Vector3(1.1, 0, 0)
		var to: Vector3 = l["to"]
		lg = to + Vector3(1.6, 0, 1.1)
		if KINDS[l["kind"]]["to"] == "street":
			lg = to + Vector3(-1.1, 0, 0)
		elif KINDS[l["kind"]]["to"] == "platform":
			lg = to + Vector3(-1.2, 0, 1.0)
		signal_up = _state in ["hold", "lift", "land"]
	_slinger.set_meta("goal", sg)
	_lander.set_meta("goal", lg)
	_walk(_slinger, delta, _state == "rig")
	_walk(_lander, delta, false)
	_arms_up(_lander, signal_up)
	for j in 2:
		_say[j].position = _doggers[j].position + Vector3(0, 2.4, 0)
	# The crews: steelies tying the core's wall steel all pour; the others come out for their load
	_place_steelies()
	for tr in _crews:
		var list: Array = _crews[tr]
		var tag: Label3D = _tags[tr]
		var w: Dictionary = _work.get(tr, {})
		if tr != "steelies" and w.is_empty():
			for n in list:
				n.visible = false
			tag.visible = false
			continue
		if not w.is_empty():
			_carry(tr, list, w, delta)
			if _work.has(tr) == false:
				continue
		var busy_tie: bool = tr == "steelies" and w.is_empty()
		for n in list:
			n.visible = true
			_walk(n, delta, busy_tie)
		tag.visible = true
		tag.position = (list[0] as Node3D).position + Vector3(0, 2.6, 0)

## A crew carrying a landed load in: out to it, a piece back in, TRIPS times;
## the stack goes down a trip at a time and then they go back to their work.
func _carry(tr: String, list: Array, w: Dictionary, delta: float) -> void:
	var l: Dictionary = lifts[int(w["lift"])]
	var node: Node3D = l["node"]
	var to: Vector3 = l["to"]
	# (on the platform they stack it at the slab edge, where it's handed in)
	var inside := Vector3(PLAT_EDGE.x + 0.8, to.y, to.z + 0.6)
	if KINDS[l["kind"]]["to"] == "core":
		inside = to + Vector3(1.8, 0, 1.6)
	elif KINDS[l["kind"]]["to"] == "street":
		inside = to + Vector3(0.9, 0, 0)
	w["t"] = float(w["t"]) + delta
	var leg := int(float(w["t"]) / CARRY_LEG)
	var going_out := leg % 2 == 0
	if leg >= TRIPS * 2:
		node.visible = false
		_work.erase(tr)
		if game.autotest:
			print("[autotest]   crane: the %s have the %s in" % [tr, KINDS[l["kind"]]["name"]])
		return
	if l["kind"] != "skip":
		node.scale.y = maxf(0.15, 1.0 - float(leg / 2) / float(TRIPS))
	if not list[0].visible:
		for j in list.size():
			(list[j] as Node3D).position = inside + Vector3(0, 0, j * 0.7)
	for j in list.size():
		var n: Node3D = list[j]
		var by := Vector3(1.0, 0, -0.5 + j * 1.0) if KINDS[l["kind"]]["to"] == "platform" else Vector3(-0.9, 0, -0.5 + j * 1.0)
		n.set_meta("goal", (to + by) if going_out else (inside + Vector3(0, 0, j * 0.7)))
		n.set_meta("carry", not going_out)

func _walk(n: Node3D, delta: float, working: bool) -> void:
	var goal: Vector3 = n.get_meta("goal", n.position)
	var d := goal - n.position
	var flat := Vector3(d.x, 0, d.z)
	var dist := flat.length()
	var moving := dist > 0.25
	if dist > 22.0 or absf(d.y) > 2.5:
		# (a long way, or another floor: they've gone by the stairs or the hoist)
		n.position = goal
		moving = false
	elif moving:
		n.position += flat / dist * minf(dist, 2.0 * delta)
		n.rotation.y = atan2(flat.x, flat.z)
	n.position.y = goal.y
	var ph := _t * 8.0 + n.get_instance_id() % 7
	(n.get_node("LegL") as Node3D).rotation.x = sin(ph) * (0.5 if moving else 0.0)
	(n.get_node("LegR") as Node3D).rotation.x = -sin(ph) * (0.5 if moving else 0.0)
	var arm_l := n.get_node("ArmL") as Node3D
	var arm_r := n.get_node("ArmR") as Node3D
	var head := n.get_node("Head") as Node3D
	if bool(n.get_meta("carry", false)) and moving:
		arm_l.rotation = Vector3(-1.3, 0, -0.2)
		arm_r.rotation = Vector3(-1.3, 0, 0.2)
		head.rotation.x = 0.0
	elif working and not moving:
		arm_l.rotation = Vector3(-1.1 + 0.25 * sin(_t * 11.0 + ph), 0, -0.2)
		arm_r.rotation = Vector3(-1.0 - 0.25 * sin(_t * 11.0 + ph * 1.7), 0, 0.2)
		head.rotation.x = 0.45
	else:
		arm_l.rotation = Vector3(-sin(ph) * (0.4 if moving else 0.0), 0, -0.25)
		arm_r.rotation = Vector3(sin(ph) * (0.4 if moving else 0.0), 0, 0.25)
		head.rotation.x = 0.0

func _arms_up(n: Node3D, up: bool) -> void:
	if not up:
		return
	(n.get_node("ArmR") as Node3D).rotation = Vector3(-2.7, 0, 0.2)
	(n.get_node("Head") as Node3D).rotation.x = -0.35

# ------------------------------------------------------------------ dev

## Dev: a load in the air (for the "cranelift" shot), where to look.
func lifting() -> bool:
	return on and _i >= 0 and _state == "lift" and not _move.is_empty() and float(_move["t"]) / float(_move["T"]) > 0.4

func lift_focus() -> Vector3:
	return _hook() - Vector3(0, SLING + 2.0, 0)

## Dev: a crew carrying a load in (for the "cranecrew" shot), where to look.
func crew_focus() -> Vector3:
	for tr in _work:
		if KINDS[lifts[int(_work[tr]["lift"])]["kind"]]["to"] == "platform":
			return (_crews[tr][0] as Node3D).position + Vector3(0, 1.0, 0)
	return Vector3.INF

## Dev shots (main._maybe_shot): "cranelift" a load in the air, "cranecrew" a
## crew carrying one in, "cranelay" the laydown and the slinging dogger.
func shot_key(only: Array, taken: Dictionary) -> String:
	if not on:
		return ""
	if "cranelift" in only and not taken.has("cranelift") and lifting():
		return "cranelift"
	if "cranecrew" in only and not taken.has("cranecrew") and crew_focus() != Vector3.INF and float(_work.values()[0]["t"]) > 3.5:
		return "cranecrew"
	if "cranelay" in only and not taken.has("cranelay") and _i >= 0 and _state == "rig":
		return "cranelay"
	return ""

## [where to look, how far back]
func shot_cam(key: String) -> Array:
	match key:
		"cranecrew":
			# (from out past the east face, where the platform is)
			game.cam_yaw = 1.2
			game.cam_pitch = 0.3
			return [_plat_spot(0.5) + Vector3(0, 1.0, 0), 13.0]
		"cranelay":
			return [_slinger.position + Vector3(0, 1.0, 0), 12.0]
	return [lift_focus(), 26.0]

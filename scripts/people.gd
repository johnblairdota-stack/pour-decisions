## The public round Riverlight on a pour morning: walkers with a coffee,
## dog walkers, joggers and cyclists on the park paths and the riverwalk,
## someone pushing a pram, commuters waiting on the CityCat pontoon and a
## few sidewalk supers watching the pour from the path. The models are
## tools/blender/people.py (assets/people/people.glb); scripts/surrounds.gd
## makes one of these with the map's paths.
extends Node3D

const F := preload("res://scripts/factory.gd")
const LIB := "res://assets/people/people.glb"
const NEAR := 450.0          # paths this close to the site get people
const SEE := 320.0           # nobody's drawn or animated further from the camera than this
const WALKERS := 24

const SKIN := [Color("f2c9a0"), Color("e8b48a"), Color("c98d62"), Color("a8714a"), Color("7a4d32"), Color("f6d8bd")]
const HAIR := [Color("2a1d14"), Color("4a3422"), Color("6b4a2b"), Color("a8783f"), Color("d8b46a"), Color("8a8a88"),
	Color("1a1a1a")]
const TOPS := [Color("f4f4f2"), Color("1f2d4a"), Color("4f8fd6"), Color("e85d75"), Color("3fb58a"), Color("f2c14e"),
	Color("8d6cc8"), Color("2b2f36"), Color("ff7a45"), Color("9cc9e8"), Color("c4d96a")]
const BOTTOMS := [Color("1d1f24"), Color("2f3a4c"), Color("4a5a78"), Color("b9a57e"), Color("6b6f75"), Color("3a5f8f")]
const SHOES := [Color("f4f4f2"), Color("1d1f24"), Color("ff5a5a"), Color("4f8fd6"), Color("c4c8cc")]
const CAPS := [Color("d9302c"), Color("1f2d4a"), Color("f4f4f2"), Color("2f6f5a"), Color("e8a33a")]
const BIKES := [Color("1f6f8f"), Color("d9302c"), Color("2b2f36"), Color("e8e6df"), Color("3fb58a")]
const DOGS := [[Color("b07a45"), Color("5a3a22")], [Color("2b2622"), Color("e8e2d6")], [Color("d8b46a"), Color("a8783f")],
	[Color("8a8a88"), Color("2b2622")]]

## kind: [share of walkers, speed m/s, stride (legs' swing a metre)]
const KINDS := {
	"walk": [0.32, 1.25, 4.6], "coffee": [0.14, 1.1, 4.6], "dog": [0.2, 1.0, 4.6], "jog": [0.18, 2.7, 3.6],
	"bike": [0.11, 5.0, 2.2], "pram": [0.05, 1.0, 4.6],
}

static var _lib: Node
static var _mats := {}

var _walkers: Array = []     # each a Dictionary: see _walker()
var _idlers: Array = []      # [node, base yaw, phase]
var _t := 0.0

## Makes the people for the map `d` under `root`. `keep_clear` is false where
## people mustn't go (the site, the truck road).
static func build(root: Node3D, d: Dictionary, keep_clear: Callable, rng: RandomNumberGenerator) -> Node3D:
	var p: Node3D = (load("res://scripts/people.gd") as GDScript).new()
	p.name = "People"
	root.add_child(p)
	p.setup(d, keep_clear, rng)
	return p

func setup(d: Dictionary, keep_clear: Callable, rng: RandomNumberGenerator) -> void:
	var routes := _routes(d, keep_clear)
	if routes.is_empty():
		return
	var long: Array = routes.filter(func(r): return r["len"] > 220.0)
	for i in WALKERS:
		var kind := _pick_kind(rng)
		var pool: Array = long if kind in ["jog", "bike"] and not long.is_empty() else routes
		_walkers.append(_walker(kind, pool[rng.randi() % pool.size()], rng))
		_step(_walkers[-1], 0.0, Vector3.ZERO)
	_supers(d, keep_clear, rng)
	_commuters(d, rng)

# ------------------------------------------------------------------ routes

## The map's footpaths and cycleways near the site, as routes to walk up and
## down, cut where they'd cross the site.
static func _routes(d: Dictionary, keep_clear: Callable) -> Array:
	var out: Array = []
	for p in d.get("paths", []):
		if p["kind"] == "steps":
			continue
		var run := PackedVector2Array()
		for q in p["pts"]:
			var v := Vector2(q[0], q[1])
			if v.length() < NEAR and keep_clear.call(v):
				run.append(v)
			else:
				_add_route(out, run)
				run = PackedVector2Array()
		_add_route(out, run)
	return out

static func _add_route(out: Array, pts: PackedVector2Array) -> void:
	if pts.size() < 2:
		return
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i - 1].distance_to(pts[i]))
	if cum[cum.size() - 1] > 40.0:
		out.append({"pts": pts, "cum": cum, "len": cum[cum.size() - 1]})

## Where a route is `s` metres along: [point, direction].
static func _at(r: Dictionary, s: float) -> Array:
	var cum: PackedFloat32Array = r["cum"]
	var pts: PackedVector2Array = r["pts"]
	var i := 1
	while i < cum.size() - 1 and cum[i] < s:
		i += 1
	var a := pts[i - 1]
	var b := pts[i]
	var seg := maxf(cum[i] - cum[i - 1], 0.001)
	return [a.lerp(b, clampf((s - cum[i - 1]) / seg, 0.0, 1.0)), (b - a).normalized()]

static func _pick_kind(rng: RandomNumberGenerator) -> String:
	var x := rng.randf()
	for k in KINDS:
		x -= float(KINDS[k][0])
		if x <= 0.0:
			return k
	return "walk"

# ------------------------------------------------------------------ people

## A dressed person: their own colours, hair and extras.
static func person(rng: RandomNumberGenerator, kind := "walk") -> Node3D:
	if _lib == null:
		_lib = (load(LIB) as PackedScene).instantiate()
	var n: Node3D = _lib.get_node("Person").duplicate()
	var per := {
		"top": TOPS[rng.randi() % TOPS.size()], "bottoms": BOTTOMS[rng.randi() % BOTTOMS.size()],
		"shoes": SHOES[rng.randi() % SHOES.size()], "skin": SKIN[rng.randi() % SKIN.size()],
		"hair": HAIR[rng.randi() % HAIR.size()], "cap": CAPS[rng.randi() % CAPS.size()],
	}
	_paint(n, per)
	var on: Array = []
	var long_hair := rng.randf() < 0.45
	if long_hair:
		on.append(["Look_ponytail", "Look_bun", "Look_long"][rng.randi() % 3] if kind != "jog" else "Look_ponytail")
	elif rng.randf() < 0.2:
		on.append("Look_beard")
	if kind == "jog":
		if rng.randf() < 0.5:
			on.append("Look_cap")
		if rng.randf() < 0.4:
			on.append("Look_headphones")
	else:
		var r := rng.randf()
		if r < 0.18:
			on.append("Look_cap")
		elif r < 0.3:
			on.append("Look_bucket")
		if rng.randf() < 0.3:
			on.append("Look_sunnies")
		if rng.randf() < 0.3 and kind in ["walk", "bike"]:
			on.append("Look_backpack")
		if rng.randf() < 0.35 and kind != "bike":
			on.append_array(["ArmL_Long", "ArmR_Long"])
		if rng.randf() < 0.45:
			on.append_array(["LegL_Pants", "LegR_Pants"])
	if kind == "coffee":
		on.append("Hold_coffee")
	elif kind == "dog":
		on.append("Hold_lead")
	for c in _all(n):
		var nm := String(c.name)
		var extra := nm.begins_with("Look_") or nm.begins_with("Hold_") or nm.ends_with("_Long") or nm.ends_with("_Pants")
		if extra:
			c.visible = nm in on
	# long sleeves and long pants cover the bare arm and the shorts
	for side in ["L", "R"]:
		if "Arm%s_Long" % side in on:
			n.get_node("Arm%s/Arm%s_Short" % [side, side]).visible = false
		if "Leg%s_Pants" % side in on:
			n.get_node("Leg%s/Leg%s_Shorts" % [side, side]).visible = false
	(n.get_node("ArmL") as Node3D).rotation.z = -0.15
	(n.get_node("ArmR") as Node3D).rotation.z = 0.15
	n.scale = Vector3.ONE * rng.randf_range(0.92, 1.06)
	_far(n)
	return n

static func _model(name: String, per: Dictionary) -> Node3D:
	if _lib == null:
		_lib = (load(LIB) as PackedScene).instantiate()
	var n: Node3D = _lib.get_node(name).duplicate()
	_paint(n, per)
	_far(n)
	return n

static func _all(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all(c))
	return out

static func _paint(n: Node, per: Dictionary) -> void:
	for c in _all(n):
		if not c is MeshInstance3D:
			continue
		var mi := c as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var key := src.resource_name if src != null else ""
			var col: Color = per.get(key, _default(key))
			mi.set_surface_override_material(i, _mat(col, key in ["top", "bottoms", "skin", "hair", "cap", "dog", "frame", "pram"]))

static func _default(key: String) -> Color:
	return {"sole": Color("3a3a3a"), "eye": Color("151515"), "eye_hi": Color.WHITE, "cheek": Color("f08a7a"),
		"mouth": Color("7a3030"), "lens": Color("10151d"), "pack": Color("2b2f36"), "cup": Color("f4f1ea"),
		"cup_lid": Color("3a3d42"), "phone": Color("1d1f22"), "lead": Color("d9302c"), "nose": Color("1d1d1d"),
		"tyre": Color("2a2a2a"), "rim": Color("b9bdc0"), "seat": Color("1d1d1d"), "steel": Color("a9b0b5"),
		"pram_hood": Color("4a6278"), "dog": Color("b07a45"), "dog_dark": Color("5a3a22"),
		"frame": Color("1f6f8f"), "pram": Color("34495e")}.get(key, Color.MAGENTA)

static func _mat(c: Color, outlined: bool) -> Material:
	var k := "%s%s" % [c.to_html(false), outlined]
	if not _mats.has(k):
		_mats[k] = F.color_mat(c, outlined)
	return _mats[k]

## Not drawn past SEE from the camera.
static func _far(n: Node) -> void:
	for c in _all(n):
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).visibility_range_end = SEE
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ------------------------------------------------------------------ walkers

func _walker(kind: String, route: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var n := person(rng, kind)
	add_child(n)
	var w := {"kind": kind, "node": n, "route": route, "s": rng.randf() * float(route["len"]),
		"dir": 1.0 if rng.randf() < 0.5 else -1.0, "speed": float(KINDS[kind][1]) * rng.randf_range(0.85, 1.15),
		"phase": rng.randf() * TAU, "pause": 0.0, "yaw": 0.0, "side": 1.6 if rng.randf() < 0.5 else -1.6}
	if kind == "dog":
		var cols: Array = DOGS[rng.randi() % DOGS.size()]
		var dg := _model("Dog", {"dog": cols[0], "dog_dark": cols[1]})
		dg.scale = Vector3.ONE * rng.randf_range(0.8, 1.15)
		add_child(dg)
		w["dog"] = dg
	elif kind == "bike":
		var bk := _model("Bicycle", {"frame": BIKES[rng.randi() % BIKES.size()]})
		add_child(bk)
		w["bike"] = bk
		for side in ["L", "R"]:
			(n.get_node("Arm" + side) as Node3D).rotation.x = -1.15
	elif kind == "pram":
		var pr := _model("Pram", {"pram": TOPS[rng.randi() % TOPS.size()].darkened(0.3)})
		add_child(pr)
		w["pram"] = pr
	return w

func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam != null else Vector3.ZERO
	for w in _walkers:
		_step(w, delta, eye)
	for it in _idlers:
		var n: Node3D = it[0]
		if _dist(n, eye) > SEE:
			continue
		var ph: float = it[2]
		(n.get_node("Head") as Node3D).rotation.y = sin(_t * 0.4 + ph) * 0.5
		# now and then someone points at the pour
		if it.size() > 3:
			var point := fmod(_t + ph * 7.0, 14.0) < 2.5
			var arm := n.get_node("ArmR") as Node3D
			arm.rotation.x = lerpf(arm.rotation.x, -1.5 if point else 0.0, minf(1.0, delta * 4.0))

static func _dist(n: Node3D, eye: Vector3) -> float:
	return (n.global_position if n.is_inside_tree() else n.position).distance_to(eye)

func _step(w: Dictionary, delta: float, eye: Vector3) -> void:
	var r: Dictionary = w["route"]
	var n: Node3D = w["node"]
	var kind: String = w["kind"]
	var far := _dist(n, eye) > SEE
	if float(w["pause"]) > 0.0:
		w["pause"] = float(w["pause"]) - delta
		if not far:
			_pose(w, 0.0, delta)
		return
	var v: float = w["speed"]
	var s: float = float(w["s"]) + v * float(w["dir"]) * delta
	if s < 0.0 or s > float(r["len"]):
		# the end of the path: turn round (a dog walker stops for a sniff first)
		s = clampf(s, 0.0, float(r["len"]))
		w["dir"] = -float(w["dir"])
		if kind in ["walk", "dog", "coffee"]:
			w["pause"] = randf_range(1.5, 6.0)
	w["s"] = s
	var at := _at(r, s)
	var p: Vector2 = at[0]
	var fwd: Vector2 = (at[1] as Vector2) * float(w["dir"])
	# keep to the left, as Queenslanders do
	var off := Vector2(fwd.y, -fwd.x) * (0.8 if kind != "bike" else 1.2)
	p += off
	var yaw := atan2(fwd.x, fwd.y)
	w["yaw"] = lerp_angle(float(w["yaw"]), yaw, minf(1.0, delta * 5.0))
	if far:
		n.position = Vector3(p.x, 0, p.y)
		return
	var ry: float = w["yaw"]
	var dir3 := Vector3(sin(ry), 0, cos(ry))
	match kind:
		"bike":
			var bk: Node3D = w["bike"]
			bk.position = Vector3(p.x, 0, p.y)
			bk.rotation.y = ry
			n.position = bk.position + dir3 * -0.2 + Vector3(0, 0.55, 0)
			n.rotation = Vector3(0.22, ry, 0)
			w["phase"] = float(w["phase"]) + delta * v / 2.2 * TAU / 2.0
			var ph: float = w["phase"]
			(bk.get_node("Cranks") as Node3D).rotation.x = ph
			for wh in ["WheelF", "WheelR"]:
				(bk.get_node(wh) as Node3D).rotation.x = s / 0.34
			(n.get_node("LegL") as Node3D).rotation.x = -1.0 + sin(ph) * 0.5
			(n.get_node("LegR") as Node3D).rotation.x = -1.0 - sin(ph) * 0.5
			return
		"pram":
			var pr: Node3D = w["pram"]
			pr.position = Vector3(p.x, 0, p.y) + dir3 * 0.85
			pr.rotation.y = ry
		"dog":
			var dg: Node3D = w["dog"]
			var side := Vector3(dir3.z, 0, -dir3.x) * float(w["side"]) * 0.5
			dg.position = Vector3(p.x, 0, p.y) + dir3 * 1.0 + side
			dg.rotation.y = ry
			var dp := float(w["phase"]) * 1.6
			for lg in [["LegFL", 0.0], ["LegBR", 0.0], ["LegFR", PI], ["LegBL", PI]]:
				(dg.get_node(lg[0]) as Node3D).rotation.x = sin(dp + float(lg[1])) * 0.55
			(dg.get_node("Tail") as Node3D).rotation.y = sin(_t * 9.0) * 0.6
	n.position = Vector3(p.x, 0, p.y)
	n.rotation = Vector3(0.12 if kind == "jog" else 0.0, ry, 0)
	_pose(w, v, delta)

## Legs and arms for walking (or standing, at v = 0).
func _pose(w: Dictionary, v: float, delta: float) -> void:
	var n: Node3D = w["node"]
	var kind: String = w["kind"]
	if kind == "bike":
		return
	var stride: float = KINDS[kind][2]
	w["phase"] = float(w["phase"]) + delta * v * stride
	var ph: float = w["phase"]
	var amp := 0.0 if v <= 0.0 else (0.75 if kind == "jog" else 0.45)
	(n.get_node("LegL") as Node3D).rotation.x = sin(ph) * amp
	(n.get_node("LegR") as Node3D).rotation.x = -sin(ph) * amp
	var al := n.get_node("ArmL") as Node3D
	var ar := n.get_node("ArmR") as Node3D
	match kind:
		"jog":
			al.rotation.x = -0.9 - sin(ph) * 0.6
			ar.rotation.x = -0.9 + sin(ph) * 0.6
			n.position.y = absf(sin(ph)) * 0.08
		"pram":
			al.rotation.x = -1.1
			ar.rotation.x = -1.1
		"coffee":
			al.rotation.x = -sin(ph) * amp * 0.8
			ar.rotation.x = -0.9
		"dog":
			al.rotation.x = -0.5
			ar.rotation.x = sin(ph) * amp * 0.8
		_:
			al.rotation.x = -sin(ph) * amp * 0.8
			ar.rotation.x = sin(ph) * amp * 0.8

# ------------------------------------------------------------------ standing

## Two or three people on the path nearest the site's fence, watching.
func _supers(d: Dictionary, keep_clear: Callable, rng: RandomNumberGenerator) -> void:
	var best := Vector2.INF
	for p in d.get("paths", []):
		for q in p["pts"]:
			var v := Vector2(q[0], q[1])
			var r := v.length()
			if r > 45.0 and r < 90.0 and keep_clear.call(v) and r < best.length():
				best = v
	if best == Vector2.INF:
		return
	var face := (-best).normalized()
	var along := Vector2(face.y, -face.x)
	for i in rng.randi_range(2, 3):
		var n := person(rng, "coffee" if i == 1 else "walk")
		var p := best + along * (i - 1.0) * 0.9
		n.position = Vector3(p.x, 0, p.y)
		n.rotation.y = atan2(face.x, face.y) + rng.randf_range(-0.3, 0.3)
		add_child(n)
		var it := [n, n.rotation.y, rng.randf() * TAU]
		if i == 0:
			it.append(true)   # the one who points
		_idlers.append(it)

## Commuters waiting on the CityCat pontoon.
func _commuters(d: Dictionary, rng: RandomNumberGenerator) -> void:
	for fe in d.get("ferry", []):
		var at := Vector2(fe["at"][0], fe["at"][1])
		var yaw := -deg_to_rad(float(fe["bank_deg"]))
		for i in 4:
			var n := person(rng, "coffee" if i % 2 == 0 else "walk")
			var local := Vector3(rng.randf_range(-9.0, 9.0), 0.8, rng.randf_range(-2.0, 2.5))
			var p := Vector3(at.x, 0, at.y) + local.rotated(Vector3.UP, yaw)
			n.position = p
			n.rotation.y = yaw + PI + rng.randf_range(-0.6, 0.6)
			if i == 3:
				n.get_node("ArmR/Hold_phone").visible = true
				(n.get_node("ArmR") as Node3D).rotation.x = -1.0
			add_child(n)
			_idlers.append([n, n.rotation.y, rng.randf() * TAU])

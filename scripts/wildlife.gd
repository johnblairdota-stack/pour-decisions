## The wildlife round Riverlight: brush-turkeys, ibis, masked lapwings,
## magpies and a pair of bush stone-curlews about the park; a kookaburra on
## the riverwalk rail; rainbow lorikeets screaming over in flocks; pelicans
## on the river; water dragons basking on the bank; a koala up a gum in the
## park; and, on a dawn pour, brushtail possums still out. The models are
## tools/blender/wildlife.py (assets/wildlife/wildlife.glb); scripts/
## surrounds.gd makes one of these with the map.
extends Node3D

const F := preload("res://scripts/factory.gd")
const Water := preload("res://scripts/water.gd")
const Flora := preload("res://scripts/flora.gd")
const LIB := "res://assets/wildlife/wildlife.glb"
const NEAR := 380.0          # where the ground animals live
const SEE := 260.0           # and how far off they're drawn
const RAIL_R := 380.0        # the riverwalk rail runs this far (surrounds.gd PARK_R)

## [model, how many groups, group size, walking speed (m/s), how far from home]
const GROUND := [["BushTurkey", 3, 1, 0.6, 9.0], ["Ibis", 2, 3, 0.4, 7.0], ["Lapwing", 2, 2, 0.9, 6.0],
	["Magpie", 3, 1, 0.7, 6.0], ["Curlew", 1, 2, 0.15, 2.5]]

const COLORS := {
	"turkey": Color("1d1d1f"), "turkey_brown": Color("3a2e26"), "wattle_red": Color("d0342c"),
	"wattle_yellow": Color("f2c14e"), "leg_grey": Color("6d6c6e"), "ibis": Color("f1efe8"), "ibis_dirty": Color("d8d2c0"),
	"black": Color("151515"), "lap_brown": Color("8a6f4e"), "lap_white": Color("f4f2ea"), "lap_yellow": Color("f2d23c"),
	"leg_pink": Color("c98a7a"), "curlew": Color("8d7f6b"), "curlew_streak": Color("5a4d3e"), "eye_yellow": Color("f2c94c"),
	"eye": Color("151515"), "magpie_white": Color("f4f4f2"), "kooka_brown": Color("7a5a3c"), "kooka_cream": Color("efe4cf"),
	"kooka_blue": Color("4f7fb0"), "bill_dark": Color("2e2a26"), "bill_pale": Color("d9c7a0"), "lori_green": Color("3f9a3a"),
	"lori_blue": Color("3255b0"), "lori_orange": Color("f08a24"), "lori_red": Color("d9302c"), "pelican": Color("f6f4ee"),
	"pelican_black": Color("222222"), "bill_pink": Color("f2b8a8"), "koala": Color("8d9196"), "koala_light": Color("e6e2da"),
	"nose": Color("1d1d1d"), "possum": Color("6d6c6e"), "possum_dark": Color("2a2a2a"), "possum_pink": Color("e7a7a0"),
	"dragon": Color("6f7a5a"), "dragon_dark": Color("3a3f33"), "dragon_red": Color("b8553a"),
}
## The big ones get the crew's ink outline; on a little bird it'd swamp it
const OUTLINED := ["Ibis", "Pelican", "Koala"]

## How light it is on a dawn pour (main.gd), 0 day to 1 before sunrise:
## the possums are about while it's still dim
static var dawn := 0.0

static var _lib: Node
static var _mats := {}

var _walkers: Array = []     # ground birds: {node, home, target, speed, range, pause, peck, ph}
var _floaters: Array = []    # pelicans: {node, home, ph}
var _flocks: Array = []      # lorikeets: {birds: [[node, offset]], centre, r, h, speed, a}
var _sitters: Array = []     # [node, phase, kind]
var _possums: Array = []
var _t := 0.0

## `ok(p)`: grass an animal can stand on (off the site, the roads and what's
## built).
static func build(root: Node3D, d: Dictionary, ok: Callable, rng: RandomNumberGenerator) -> Node3D:
	var w: Node3D = (load("res://scripts/wildlife.gd") as GDScript).new()
	w.name = "Wildlife"
	root.add_child(w)
	w.setup(d, ok, rng)
	return w

func setup(d: Dictionary, ok: Callable, rng: RandomNumberGenerator) -> void:
	var rivers: Array = []
	for a in d.get("areas", []):
		if a["kind"] == "water":
			rivers.append(_ring(a["pts"]))
	var water := func(p: Vector2) -> bool:
		for poly in rivers:
			if Geometry2D.is_point_in_polygon(p, poly):
				return true
		return false
	var parks: Array = []
	for a in d.get("areas", []):
		if a["kind"] in ["park", "golf"]:
			var poly := _ring(a["pts"])
			for q in poly:
				if q.length() < NEAR:
					parks.append(poly)
					break
	var edge := _bank(d)
	if not parks.is_empty():
		_ground(parks, ok, rng)
		_koala(parks, ok, rng)
	_riverside(edge, ok, water, rng)
	_lorikeets(rng)

static func _ring(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(Vector2(q[0], q[1]))
	return out

## A spot on open grass in one of the parks near the site.
static func _spot(parks: Array, ok: Callable, rng: RandomNumberGenerator) -> Variant:
	for tries in 60:
		var poly: PackedVector2Array = parks[rng.randi() % parks.size()]
		var box := Rect2(poly[0], Vector2.ZERO)
		for q in poly:
			box = box.expand(q)
		var p := Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
		if p.length() < NEAR and Geometry2D.is_point_in_polygon(p, poly) and ok.call(p):
			return p
	return null

# ------------------------------------------------------------------ models

static func model(name: String) -> Node3D:
	if _lib == null:
		_lib = (load(LIB) as PackedScene).instantiate()
	var n: Node3D = _lib.get_node(name).duplicate()
	# (Blender numbers the joints it's seen before, Head.001 and so on: the
	# game wants each animal's own Head, Tail, LegL ...)
	for c in n.get_children():
		var nm := String(c.name)
		var cut := nm.find("_0")
		if cut < 0:
			cut = nm.find(".0")
		if cut > 0 and nm.substr(0, cut) in ["Head", "Tail", "LegL", "LegR", "WingL", "WingR"]:
			c.name = nm.substr(0, cut)
	var outlined := name in OUTLINED
	for c in _all(n):
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var src := mi.mesh.surface_get_material(i)
				var key := src.resource_name if src != null else ""
				var k := key + str(outlined)
				if not _mats.has(k):
					_mats[k] = F.color_mat(COLORS.get(key, Color.MAGENTA), outlined)
				mi.set_surface_override_material(i, _mats[k])
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).visibility_range_end = SEE
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

static func _all(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_all(c))
	return out

# ------------------------------------------------------------------ the park

func _ground(parks: Array, ok: Callable, rng: RandomNumberGenerator) -> void:
	for g in GROUND:
		for k in int(g[1]):
			var home = _spot(parks, ok, rng)
			if home == null:
				continue
			for j in int(g[2]):
				var n := model(g[0])
				var p: Vector2 = home + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))
				n.position = Vector3(p.x, 0, p.y)
				n.rotation.y = rng.randf() * TAU
				add_child(n)
				_walkers.append({"node": n, "kind": g[0], "home": home, "target": p, "speed": float(g[3]),
					"range": float(g[4]), "pause": rng.randf_range(0.0, 4.0), "ph": rng.randf() * TAU, "ok": ok,
					"rng": rng})

## A spotted gum in the park with a koala asleep in its arms, 4.5 m up.
func _koala(parks: Array, ok: Callable, rng: RandomNumberGenerator) -> void:
	var p = _spot(parks, ok, rng)
	if p == null:
		return
	var gum := MeshInstance3D.new()
	gum.mesh = Flora.mesh("Gum")
	gum.position = Vector3(p.x, 0, p.y)
	add_child(gum)
	# the trunk's middle at 4.5 m (tools/blender/trees.py gum(): it wanders)
	var y := 4.5
	var c := Vector3(0.45 * sin(y / 5.0), y, 0.2 * sin(y / 3.5))
	var r := 0.42 + (0.36 - 0.42) * (y - 0.8) / 5.2
	var face := Vector3(0, 0, 1).rotated(Vector3.UP, rng.randf_range(-0.6, 0.6))
	var k := model("Koala")
	k.position = gum.position + c + face * (r + 0.32) + Vector3(0, -0.3, 0)
	k.rotation.y = atan2(face.x, face.z)
	add_child(k)
	_sitters.append([k, rng.randf() * TAU, "koala"])
	# a possum at the foot of it, on a dawn pour
	var pos := model("Possum")
	pos.position = gum.position + Vector3(1.2, 0, -0.6)
	pos.rotation.y = rng.randf() * TAU
	add_child(pos)
	_possums.append(pos)

# ------------------------------------------------------------------ the river

## The river's edge near the site, as the riverwalk's balustrade bays
## (surrounds.gd _riverwalk): [the bay's middle on the bank, the way inland,
## whether there's a rail there].
static func _bank(d: Dictionary) -> Array:
	var out: Array = []
	var ferry: Array = []
	for fe in d.get("ferry", []):
		ferry.append(Vector2(fe["at"][0], fe["at"][1]))
	var beach: Array = []
	for a in d.get("areas", []):
		if a["kind"] == "beach":
			beach.append(_ring(a["pts"]))
	for a in d.get("areas", []):
		if a["kind"] != "water":
			continue
		var poly := _ring(a["pts"])
		if poly.size() > 2 and poly[0].is_equal_approx(poly[poly.size() - 1]):
			poly.remove_at(poly.size() - 1)
		for i in poly.size():
			var p0 := poly[i]
			var p1 := poly[(i + 1) % poly.size()]
			if p0.length() > RAIL_R and p1.length() > RAIL_R:
				continue
			var e := p1 - p0
			var ln := e.length()
			if ln < 1.0:
				continue
			var dir := e / ln
			var into := Vector2(-dir.y, dir.x)
			if not Geometry2D.is_point_in_polygon((p0 + p1) * 0.5 + into * 2.0, poly):
				into = -into
			var n := maxi(1, roundi(ln / 3.0))
			for k in n:
				var p := p0.lerp(p1, (k + 0.5) / n)
				if p.length() > RAIL_R:
					continue
				var rail := true
				for f in ferry:
					if p.distance_to(f) < 45.0:
						rail = false
				for bp in beach:
					if Geometry2D.is_point_in_polygon(p - into * 3.0, bp):
						rail = false
				out.append([p, -into, rail])
	return out

func _riverside(edge: Array, ok: Callable, water: Callable, rng: RandomNumberGenerator) -> void:
	if edge.is_empty():
		return
	# the kookaburra on the riverwalk rail (1.1 m), a water dragon or two on
	# the bank, pelicans out on the water
	for tries in 40:
		var e: Array = edge[rng.randi() % edge.size()]
		var p: Vector2 = e[0] + e[1] * 1.0
		if e[2] and ok.call(p + e[1] * 1.5):
			var k := model("Kookaburra")
			k.position = Vector3(p.x, 1.12, p.y)
			k.rotation.y = atan2(-e[1].x, -e[1].y)
			add_child(k)
			_sitters.append([k, rng.randf() * TAU, "kooka"])
			var pm := model("Possum")
			var q: Vector2 = p + Vector2(e[1].y, -e[1].x) * 9.0
			pm.position = Vector3(q.x, 1.12, q.y)
			pm.rotation.y = atan2(e[1].y, -e[1].x)
			add_child(pm)
			_possums.append(pm)
			break
	var dragons := 0
	for tries in 40:
		if dragons >= 2:
			break
		var e: Array = edge[rng.randi() % edge.size()]
		var p: Vector2 = e[0] + e[1] * rng.randf_range(2.5, 4.0)
		if ok.call(p):
			var g := model("WaterDragon")
			g.position = Vector3(p.x, 0.02, p.y)
			g.rotation.y = atan2(-e[1].x, -e[1].y) + rng.randf_range(-1.0, 1.0)
			add_child(g)
			_sitters.append([g, rng.randf() * TAU, "dragon"])
			dragons += 1
	for i in 3:
		for tries in 30:
			var e: Array = edge[rng.randi() % edge.size()]
			var p: Vector2 = e[0] - e[1] * rng.randf_range(20.0, 60.0)
			if water.call(p):
				var n := model("Pelican")
				n.position = Vector3(p.x, Water.RIVER_Y, p.y)
				n.rotation.y = rng.randf() * TAU
				add_child(n)
				_floaters.append({"node": n, "home": p, "ph": rng.randf() * TAU})
				break

# ------------------------------------------------------------------ the sky

func _lorikeets(rng: RandomNumberGenerator) -> void:
	for f in 2:
		var birds: Array = []
		for i in 7:
			var n := model("Lorikeet")
			add_child(n)
			birds.append([n, Vector3(rng.randf_range(-4, 4), rng.randf_range(-1.5, 1.5), rng.randf_range(-5, 5)),
				rng.randf() * TAU])
		_flocks.append({"birds": birds, "centre": Vector2(rng.randf_range(-150, 150), rng.randf_range(-120, 200)),
			"r": rng.randf_range(90.0, 160.0), "h": rng.randf_range(22.0, 38.0), "speed": 14.0 * (1.0 if f == 0 else -1.0),
			"a": rng.randf() * TAU})
	_fly(0.0)

# ------------------------------------------------------------------ moving

func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam != null else Vector3.ZERO
	for w in _walkers:
		_walk(w, delta, eye)
	for f in _floaters:
		var n: Node3D = f["node"]
		var ph: float = f["ph"]
		var home: Vector2 = f["home"]
		# (drifting slowly about where it started)
		n.position = Vector3(home.x + (sin(_t * 0.05 + ph) - sin(ph)) * 6.0, Water.RIVER_Y + sin(_t * 1.3 + ph) * 0.04,
			home.y + (cos(_t * 0.04 + ph) - cos(ph)) * 6.0)
		n.rotation.y = _t * 0.03 + ph
		(n.get_node("Head") as Node3D).rotation.y = sin(_t * 0.3 + ph) * 0.4
	for s in _sitters:
		var n: Node3D = s[0]
		var ph: float = s[1]
		if _dist(n, eye) > SEE:
			continue
		var h := n.get_node("Head") as Node3D
		match s[2]:
			"koala":
				h.rotation.y = sin(_t * 0.15 + ph) * 0.35
			"kooka":
				h.rotation.y = sin(_t * 0.5 + ph) * 0.6 if fmod(_t + ph * 3.0, 9.0) < 6.0 else 0.0
				# every so often it throws its head back and laughs
				var laugh := fmod(_t + ph * 7.0, 23.0)
				h.rotation.x = -0.5 * sin(laugh * 9.0) * float(laugh < 2.5)
			"dragon":
				h.rotation.x = -0.15 * float(fmod(_t + ph * 5.0, 7.0) < 0.6)
	var show := dawn > 0.2
	for p in _possums:
		(p as Node3D).visible = show
		if show:
			((p as Node3D).get_node("Head") as Node3D).rotation.y = sin(_t * 0.8) * 0.5
	_fly(delta)

static func _dist(n: Node3D, eye: Vector3) -> float:
	return (n.global_position if n.is_inside_tree() else n.position).distance_to(eye)

## A ground bird: walks to a spot near home, stops and pecks about (a
## brush-turkey scratches), and on again.
func _walk(w: Dictionary, delta: float, eye: Vector3) -> void:
	var n: Node3D = w["node"]
	if _dist(n, eye) > SEE:
		return
	var head := n.get_node("Head") as Node3D
	var ph: float = w["ph"]
	var kind: String = w["kind"]
	if float(w["pause"]) > 0.0:
		w["pause"] = float(w["pause"]) - delta
		# pecking: head down and up, now and then
		var peck := maxf(0.0, sin(_t * (5.0 if kind != "Curlew" else 0.6) + ph))
		head.rotation.x = 0.0 if kind == "Curlew" else peck * peck * 0.9
		for leg in ["LegL", "LegR"]:
			(n.get_node(leg) as Node3D).rotation.x = 0.0
		if kind == "BushTurkey" and fmod(_t + ph, 6.0) < 1.2:
			(n.get_node("LegL" if fmod(_t * 3.0, 2.0) < 1.0 else "LegR") as Node3D).rotation.x = -0.7
		if float(w["pause"]) <= 0.0:
			var rng: RandomNumberGenerator = w["rng"]
			var ok: Callable = w["ok"]
			var home: Vector2 = w["home"]
			var r := float(w["range"])
			for tries in 6:
				var p := home + Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r))
				if ok.call(p):
					w["target"] = p
					break
		return
	var to: Vector2 = w["target"]
	var at := Vector2(n.position.x, n.position.z)
	var gap := to - at
	if gap.length() < 0.1:
		var rng: RandomNumberGenerator = w["rng"]
		w["pause"] = rng.randf_range(3.0, 9.0) * (3.0 if kind == "Curlew" else 1.0)
		return
	var step := minf(gap.length(), float(w["speed"]) * delta)
	at += gap.normalized() * step
	n.position = Vector3(at.x, 0, at.y)
	n.rotation.y = lerp_angle(n.rotation.y, atan2(gap.x, gap.y), minf(1.0, delta * 6.0))
	var stride := _t * float(w["speed"]) * 18.0
	(n.get_node("LegL") as Node3D).rotation.x = sin(stride) * 0.5
	(n.get_node("LegR") as Node3D).rotation.x = -sin(stride) * 0.5
	# birds bob their heads as they walk
	head.rotation.x = 0.12 * sin(stride * 2.0)

## The lorikeets: round and round the park in a loose, rowdy flock.
func _fly(delta: float) -> void:
	for f in _flocks:
		f["a"] = float(f["a"]) + delta * float(f["speed"]) / float(f["r"])
		var a: float = f["a"]
		var c: Vector2 = f["centre"]
		var r: float = f["r"]
		var lead := Vector3(c.x + cos(a) * r, float(f["h"]) + sin(a * 2.3) * 4.0, c.y + sin(a) * r)
		var fwd := Vector3(-sin(a), 0, cos(a)) * signf(float(f["speed"]))
		var yaw := atan2(fwd.x, fwd.z)
		for b in f["birds"]:
			var n: Node3D = b[0]
			var off: Vector3 = b[1]
			var ph: float = b[2]
			n.position = lead + off.rotated(Vector3.UP, yaw) + Vector3(0, sin(_t * 2.0 + ph) * 0.6, 0)
			n.rotation.y = yaw
			var flap := sin(_t * 22.0 + ph) * 0.8
			(n.get_node("WingL") as Node3D).rotation.z = flap
			(n.get_node("WingR") as Node3D).rotation.z = -flap

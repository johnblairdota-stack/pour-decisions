## The CityCat and the Northshore Hamilton terminal it calls at, from
## tools/blender/citycat.py (assets/citycat/citycat.glb): the pontoon and its
## gangway back to the bank (scripts/surrounds.gd), the boat running up and
## down the river, and the same boat in the top-out fly-past (main.gd).
extends RefCounted

const F := preload("res://scripts/factory.gd")
const Water := preload("res://scripts/water.gd")
const LIB := "res://assets/citycat/citycat.glb"
const SPAN := 6.0          # one GangwaySpan, m

const COLORS := {
	"navy": Color("1f4f8f"), "white": Color("f4f7fa"), "glass": Color("2a3a48"), "rubber": Color("222222"),
	"rail": Color("d2d6d8"), "ring": Color("ff7a1a"), "yellow": Color("ffc72c"), "concrete": Color("b9b7b0"),
	"deck": Color("8d9196"), "screen": Color("9cc3d6"), "seat": Color("2f6fd1"), "fascia": Color("5a6b78"), "pile": Color("4a5056"),
	"sign_blue": Color("1f4f9a"), "bin": Color("2f5f3f"), "antifoul": Color("7a2a24"),
}

static var _lib: Node
static var _meshes := {}
static var _mats := {}

## One model's mesh, its parts given toon materials.
static func mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	if _lib == null:
		_lib = (load(LIB) as PackedScene).instantiate()
	var mi := _lib.get_node_or_null(name) as MeshInstance3D
	if mi == null:
		push_warning("citycat: no model " + name)
		_meshes[name] = null
		return null
	var m := mi.mesh
	for i in m.get_surface_count():
		var src := m.surface_get_material(i)
		var key := src.resource_name if src != null else ""
		if not _mats.has(key):
			_mats[key] = F.color_mat(COLORS.get(key, Color.MAGENTA), false)
		m.surface_set_material(i, _mats[key])
	_meshes[name] = m
	return m

static func model(name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh(name)
	return mi

## A CityCat, bow towards +x, waterline at its origin (put it at Water.RIVER_Y).
static func boat() -> Node3D:
	return model("CityCat")

## The Northshore Hamilton terminal: the pontoon (its river side away from
## the bank) and a gangway of spans back to the bank edge.
static func terminal(root: Node3D, fe: Dictionary) -> void:
	var at := Vector2(fe["at"][0], fe["at"][1])
	var edge := Vector2(fe["edge"][0], fe["edge"][1])
	var t := model("Terminal")
	t.position = Vector3(at.x, Water.RIVER_Y, at.y)
	t.rotation.y = -deg_to_rad(float(fe["bank_deg"]))
	root.add_child(t)
	# gangway: from the pontoon's bank side to the bank, as whole spans
	var dir := (edge - at).normalized()
	var start := at + dir * 4.5
	var run := start.distance_to(edge)
	var n := maxi(1, ceili(run / SPAN))
	var yaw := atan2(dir.x, dir.y)
	# (up from the pontoon's deck to the landing on the bank)
	var y0 := Water.RIVER_Y + 0.82
	var y1 := 0.8
	var pitch := -atan2(y1 - y0, run)
	var step := Vector2(run, y1 - y0).length() / n
	for i in n:
		var g := model("GangwaySpan")
		var p := start + dir * (run * i / n)
		g.position = Vector3(p.x, lerpf(y0, y1, float(i) / n), p.y)
		g.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis.from_scale(Vector3(1, 1, step / SPAN))
		root.add_child(g)
	var land := model("GangwayLanding")
	land.position = Vector3(edge.x, 0.8, edge.y) + Vector3(dir.x, 0, dir.y) * 1.5
	land.rotation.y = yaw
	root.add_child(land)

## A CityCat comes down the river from the city, eases off, swings in and
## comes alongside the terminal's pontoon, waits while people get on and off,
## then pulls away, turns round out in the river and heads back.
const CRUISE := 10.0         # m/s on the run (about 20 knots)
const EASE := 0.42           # m/s² slowing to berth and picking up again
const CREEP := 0.6           # m/s coming the last bit alongside
const DWELL := 40.0          # s at the pontoon
const TURNAROUND := 20.0     # s at the top of the run

static func run(root: Node3D, fe: Dictionary, route: Array) -> void:
	var b := boat()
	var at := Vector2(fe["at"][0], fe["at"][1])
	var edge := Vector2(fe["edge"][0], fe["edge"][1])
	var out := (at - edge).normalized()
	# (the pontoon's long side, as terminal() lays it)
	var rot := -deg_to_rad(float(fe["bank_deg"]))
	var along := Vector2(cos(rot), -sin(rot))
	var berth := at + out * 9.0
	var r: Array = []
	for q in route:
		r.append(Vector2(q[0], q[1]))
	# which way it's heading as it comes alongside: the way it's been going
	var s := -1.0 if r.size() > 1 and ((r[r.size() - 1] as Vector2) - (r[0] as Vector2)).dot(along) < 0.0 else 1.0
	var head := along * s
	# (the run down the river, dropping the last of it to swing in wide and
	# come up parallel to the pontoon)
	var down: Array = []
	for q: Vector2 in r:
		if (q - berth).dot(-head) > 150.0:
			down.append(q)
	var inbound: Array = down.duplicate()
	inbound.append_array([berth - head * 110.0 + out * 40.0, berth - head * 40.0 + out * 6.0, berth - head * 12.0 + out * 0.6, berth])
	# away ahead, out into the stream, round in a wide turn and back up the river
	var outbound: Array = [berth, berth + head * 25.0 + out * 4.0, berth + head * 70.0 + out * 40.0, berth + head * 60.0 + out * 110.0,
		berth - head * 20.0 + out * 150.0]
	var up: Array = down.duplicate()
	up.reverse()
	outbound.append_array(up)
	var legs := [_leg(inbound, true), _leg(outbound, false)]
	b.position = Vector3(inbound[0].x, Water.RIVER_Y, inbound[0].y)
	b.name = "CityCatRun"
	root.add_child(b)
	var t_in: float = legs[0]["time"]
	var t_out: float = legs[1]["time"]
	var cycle := t_in + DWELL + t_out + TURNAROUND
	var tw := b.create_tween().set_loops()
	# (explore.gd: you can catch it at the terminal when you knock off, hurry
	# the trip along, and read the timetable off its "eta")
	b.set_meta("tween", tw)
	b.set_meta("berth", berth)
	b.set_meta("cycle", cycle)
	var pts: Array = []
	for q: Vector2 in inbound:
		pts.append(Vector3(q.x, Water.RIVER_Y, q.y))
	b.set_meta("route", pts)
	tw.tween_method(func(t: float) -> void: _sail(b, legs[0], t, t_in - t), 0.0, t_in, t_in)
	tw.tween_method(func(t: float) -> void: _moored(b, t, 0.0), 0.0, DWELL, DWELL)
	tw.tween_method(func(t: float) -> void: _sail(b, legs[1], t, t_out - t + TURNAROUND + t_in), 0.0, t_out, t_out)
	# (idling up the top of the run, swinging round to come back down)
	var back: PackedVector2Array = legs[0]["path"]
	var yaw_in := atan2(-(back[1] - back[0]).y, (back[1] - back[0]).x)
	tw.tween_method(func(t: float) -> void:
		_moored(b, t, TURNAROUND - t + t_in)
		b.rotation.y = lerp_angle(b.rotation.y, yaw_in, clampf(t / TURNAROUND, 0.0, 1.0) * 0.08), 0.0, TURNAROUND, TURNAROUND)

## One leg as a smooth curve through `ctrl` (Catmull-Rom), sampled every
## couple of metres, with the time it takes: easing down to a creep at the end
## (`arrive`) or easing up from the start.
static func _leg(ctrl: Array, arrive: bool) -> Dictionary:
	var c: Array = [ctrl[0] + (ctrl[0] - ctrl[1])]
	c.append_array(ctrl)
	c.append(ctrl[ctrl.size() - 1] + (ctrl[ctrl.size() - 1] - ctrl[ctrl.size() - 2]))
	var path := PackedVector2Array()
	for i in range(1, c.size() - 2):
		var p0: Vector2 = c[i - 1]
		var p1: Vector2 = c[i]
		var p2: Vector2 = c[i + 1]
		var p3: Vector2 = c[i + 2]
		var n := maxi(2, ceili(p1.distance_to(p2) / 2.0))
		for k in n:
			var u := float(k) / n
			path.append(0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u))
	path.append(ctrl[ctrl.size() - 1])
	var dist := PackedFloat32Array([0.0])
	for i in range(1, path.size()):
		dist.append(dist[i - 1] + path[i - 1].distance_to(path[i]))
	var total := dist[dist.size() - 1]
	# time at each sample, from the speed there
	var time := PackedFloat32Array([0.0])
	for i in range(1, path.size()):
		var d := (dist[i] + dist[i - 1]) * 0.5
		var gone := total - d if arrive else d
		var v := clampf(sqrt(2.0 * EASE * gone) + CREEP, CREEP, CRUISE)
		time.append(time[i - 1] + (dist[i] - dist[i - 1]) / v)
	return {"path": path, "time": time[time.size() - 1], "t": time}

## Where it is `t` s into a leg: along the curve, bow round to the way it's
## going, leaning into the turns and the stern squatting as it gets going.
static func _sail(b: Node3D, leg: Dictionary, t: float, eta: float) -> void:
	var path: PackedVector2Array = leg["path"]
	var tt: PackedFloat32Array = leg["t"]
	var i := tt.bsearch(t)
	i = clampi(i, 1, path.size() - 1)
	var u := clampf((t - tt[i - 1]) / maxf(tt[i] - tt[i - 1], 0.001), 0.0, 1.0)
	var p := path[i - 1].lerp(path[i], u)
	var dir := (path[i] - path[i - 1]).normalized()
	var ahead := (path[mini(i + 4, path.size() - 1)] - path[i - 1]).normalized()
	var yaw := atan2(-dir.y, dir.x)
	var turn := wrapf(atan2(-ahead.y, ahead.x) - yaw, -PI, PI)
	var v := path[i - 1].distance_to(path[i]) / maxf(tt[i] - tt[i - 1], 0.001)
	b.position = Vector3(p.x, Water.RIVER_Y, p.y)
	b.rotation = Vector3(-turn * 0.35 * clampf(v / CRUISE, 0.0, 1.0), lerp_angle(b.rotation.y, yaw, 0.25),
		clampf(v / CRUISE, 0.0, 1.0) * 0.025)
	b.set_meta("eta", eta)

## Tied up (or idling at the top of the run): just the river moving it.
static func _moored(b: Node3D, t: float, eta: float) -> void:
	b.rotation.x = sin(t * 1.3) * 0.006
	b.rotation.z = sin(t * 0.9) * 0.004
	b.position.y = Water.RIVER_Y + sin(t * 1.1) * 0.03
	b.set_meta("eta", eta)

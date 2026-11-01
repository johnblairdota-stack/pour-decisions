## What a ute can run into off the road when you knock off (explore.gd):
## the street furniture and trees round Riverlight (street.gd and flora.gd
## draw them as multimeshes), the ground birds (wildlife.gd) and the people
## on the paths (people.gd). Signs, bins, benches and small plants go flat;
## big trees stay rooted and drop leaves or flowers; light poles stand up to
## a nudge and go over if you're quick; birds end up road kill in a puff of
## feathers; people and cyclists go flying like the crew do, then get up.
## Everything's put back when you're back at the site.
extends Node3D

const F := preload("res://scripts/factory.gd")
const Flora := preload("res://scripts/flora.gd")

## Street models: what a ute does to it, and its radius (m)
const STREET := {
	"StreetSign": ["flat", 0.15], "GiveWaySign": ["flat", 0.3], "BusStopSign": ["flat", 0.2],
	"ParkBin": ["flat", 0.35], "Bubbler": ["flat", 0.3], "BikeHoop": ["flat", 0.3],
	"ParkBench": ["flat", 0.8], "PicnicTable": ["flat", 1.0],
	"StreetLight": ["pole", 0.16], "ParkLight": ["pole", 0.12],
	"BusShelter": ["solid", 1.5], "BBQShelter": ["solid", 1.8],
}
## Trees that go over under a ute; anything else under 3 m does too
const SMALL := ["Lomandra", "Bottlebrush", "Pandanus"]
## What falls out of a tree when it's hit: [colour, how many]
const DROP := {
	"Jacaranda": [Color("9b7fd8"), 40], "Poinciana": [Color("e2482e"), 34], "PoincianaBloom": [Color("e2482e"), 40],
	"Bottlebrush": [Color("d8302a"), 18], "Gum": [Color("8ea05a"), 22], "Fig": [Color("4f8a3a"), 26],
	"Paperbark": [Color("f2ecd8"), 24], "Tuckeroo": [Color("6f9a3e"), 22], "SheOak": [Color("6b6a3c"), 26],
	"CabbagePalm": [Color("6f8f3c"), 8], "FoxtailPalm": [Color("6f8f3c"), 8], "Mangrove": [Color("4f7a3a"), 18],
}
## The birds' feathers: [main, second]
const FEATHERS := {
	"BushTurkey": [Color("1d1d1f"), Color("d0342c")], "Ibis": [Color("f1efe8"), Color("1d1d1d")],
	"Lapwing": [Color("8a6f4e"), Color("f4f2ea")], "Magpie": [Color("151515"), Color("f4f4f2")],
	"Curlew": [Color("8d7f6b"), Color("5a4d3e")],
}
const CELL := 8.0
const GRAVITY := 22.0

var _items: Array = []         # {mm, i, xf, kind, model, r, p (Vector2), down}
var _grid := {}
var _knocked: Array = []       # items knocked over: put back on reset()
var _wobble: Array = []        # [item, t, axis] big trees swaying after a hit
var _birds: Node               # wildlife.gd
var _people: Node              # people.gd
var _squashed: Array = []      # [bird dict, its transform]
var _flying: Array = []        # people knocked over: {w, node, bike, vel, spin, t, state}
var _t := 0.0

## Reads what's standing about from the Surrounds (call once it's built).
func index(world: Node3D) -> void:
	_items.clear()
	_grid.clear()
	var inv := world.global_transform.affine_inverse()
	for mmi in world.find_children("*", "MultiMeshInstance3D", true, false):
		var nm: String = mmi.name
		var model := ""
		var sp := ""
		if nm.begins_with("Street_"):
			model = nm.split("_")[1]
			if not STREET.has(model):
				continue
		elif nm.begins_with("Trees_") and nm.split("_").size() >= 4:
			sp = nm.split("_")[1]
		else:
			continue
		var mm: MultiMesh = mmi.multimesh
		var base: Transform3D = inv * mmi.global_transform
		for i in mm.instance_count:
			var own := mm.get_instance_transform(i)
			var xf: Transform3D = base * own
			# (xf is where it stands round here; own is the multimesh's own copy)
			var it := {"mm": mm, "i": i, "xf": xf, "own": own, "p": Vector2(xf.origin.x, xf.origin.z), "down": false}
			if model != "":
				it["model"] = model
				it["kind"] = STREET[model][0]
				it["r"] = float(STREET[model][1])
			else:
				var s := xf.basis.get_scale().y
				var tall := Flora.height(sp) * s
				it["model"] = sp
				it["tall"] = tall
				if sp in SMALL or tall < 3.0:
					it["kind"] = "plant"
					it["r"] = 0.5 * s
				else:
					it["kind"] = "tree"
					it["r"] = (0.55 if sp == "Fig" else (0.2 if sp.ends_with("Palm") else 0.3)) * maxf(s, 0.6)
			var k := _items.size()
			_items.append(it)
			var c := Vector2i(floori(it["p"].x / CELL), floori(it["p"].y / CELL))
			if not _grid.has(c):
				_grid[c] = []
			_grid[c].append(k)
	_birds = world.get_node_or_null("Wildlife")
	_people = world.get_node_or_null("People")

## Things still standing within `r` of `p` (plus their own size).
func near(p: Vector2, r: float) -> Array:
	var out: Array = []
	var c := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	var span := ceili(r / CELL)
	for dx in range(-span, span + 1):
		for dz in range(-span, span + 1):
			for k in _grid.get(c + Vector2i(dx, dz), []):
				var it: Dictionary = _items[k]
				if not it["down"] and (it["p"] as Vector2).distance_to(p) < r + float(it["r"]):
					out.append(it)
	return out

## Over it goes, away from `push` (m/s across the ground).
func knock(it: Dictionary, push: Vector2) -> void:
	if it["down"]:
		return
	it["down"] = true
	var xf: Transform3D = it["xf"]
	stow(it)
	var n := MeshInstance3D.new()
	n.mesh = (it["mm"] as MultiMesh).mesh
	add_child(n)
	n.transform = xf
	it["node"] = n
	_knocked.append(it)
	var dir := push.normalized() if push.length() > 0.1 else Vector2(1, 0)
	var axis := Vector3(dir.y, 0, -dir.x)
	var pole: bool = it["kind"] == "pole"
	var lie := (PI * 0.5 - 0.05) if it["kind"] != "plant" else PI * 0.42
	var slide := clampf(push.length() * (0.04 if pole else 0.12), 0.0, 3.0)
	var tw := n.create_tween().set_parallel(true)
	var b0 := xf.basis
	var o0 := xf.origin
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(n):
			n.transform = Transform3D(Basis(axis, -lie * u * u) * b0, o0 + Vector3(dir.x, 0, dir.y) * slide * u),
		0.0, 1.0, 0.9 if pole else 0.3)

## Out of sight in its multimesh (down 50 m and shrunk to nothing).
func stow(it: Dictionary) -> void:
	var own: Transform3D = it["own"]
	(it["mm"] as MultiMesh).set_instance_transform(it["i"], Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), own.origin - Vector3(0, 50, 0)))

## A big tree hit: stays put, shakes, and drops leaves or flowers.
func shake(it: Dictionary, hard: float) -> void:
	_wobble.append([it, 0.0, minf(0.12, 0.02 + hard * 0.006)])
	var drop: Array = DROP.get(it["model"], [Color("5f8a3a"), 20])
	var tall: float = it.get("tall", 6.0)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = int(float(drop[1]) * clampf(hard / 8.0, 0.4, 1.6))
	p.lifetime = 3.2
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = tall * 0.3
	p.direction = Vector3.DOWN
	p.spread = 70.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, -1.6, 0)
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.06)
	var m := F.flat_mat(drop[0])
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.mesh = q
	p.position = (it["xf"] as Transform3D).origin + Vector3(0, tall * 0.7, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(4.0, true, false, true).timeout.connect(p.queue_free)

## Ground birds a ute's run over: [bird dict].
func birds_in(p: Vector2, half: Vector2, yaw: float) -> Array:
	var out: Array = []
	if _birds == null:
		return out
	for w in _birds._walkers:
		var n: Node3D = w["node"]
		if _in_box(Vector2(n.position.x, n.position.z), p, yaw, half, 0.15):
			out.append(w)
	return out

func squash(w: Dictionary, push: Vector2) -> void:
	_birds._walkers.erase(w)
	var n: Node3D = w["node"]
	_squashed.append([w, n.transform])
	var at := n.position + Vector3(push.x, 0, push.y).normalized() * 0.6
	n.position = Vector3(at.x, 0.02, at.z)
	n.rotation = Vector3(0, randf() * TAU, 0)
	n.scale = Vector3(1.35, 0.14, 1.35)
	var cols: Array = FEATHERS.get(w["kind"], [Color("8d8578"), Color("f2efe6")])
	for k in 2:
		var f := CPUParticles3D.new()
		f.one_shot = true
		f.amount = 22
		f.lifetime = 2.6
		f.explosiveness = 0.95
		f.direction = Vector3(push.x, 1.6, push.y).normalized()
		f.spread = 70.0
		f.initial_velocity_min = 1.5
		f.initial_velocity_max = 4.0
		f.gravity = Vector3(0, -0.9, 0)
		f.damping_min = 1.5
		f.damping_max = 3.0
		f.angular_velocity_min = -300.0
		f.angular_velocity_max = 300.0
		var q := QuadMesh.new()
		q.size = Vector2(0.11, 0.22)
		var m := F.flat_mat(cols[k])
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		# (face the camera, spinning, so they read as feathers not sticks)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		f.angle_min = -180.0
		f.angle_max = 180.0
		q.material = m
		f.mesh = q
		f.position = at + Vector3(0, 0.3, 0)
		add_child(f)
		f.emitting = true
		get_tree().create_timer(3.0, true, false, true).timeout.connect(f.queue_free)

## People on the paths (and cyclists) a ute's hitting.
func people_in(p: Vector2, half: Vector2, yaw: float) -> Array:
	var out: Array = []
	if _people == null:
		return out
	for w in _people._walkers:
		if w.get("down", false):
			continue
		var n: Node3D = w["node"]
		if _in_box(Vector2(n.position.x, n.position.z), p, yaw, half, 0.35):
			out.append(w)
	return out

## Sent flying, the bike one way and them the other.
func bowl(w: Dictionary, push: Vector2) -> void:
	w["down"] = true
	var hard := push.length()
	var it := {"w": w, "node": w["node"], "vel": Vector3(push.x, 3.5 + hard * 0.35, push.y), "t": 0.0, "state": "fly",
		"spin": Vector3(push.y, 0, -push.x).normalized() * (5.0 + hard * 0.5) + Vector3(randf_range(-2, 2), randf_range(-4, 4), 0)}
	var n: Node3D = it["node"]
	it["basis"] = n.basis
	if w.has("bike"):
		var bk: Node3D = w["bike"]
		it["bike"] = bk
		it["bvel"] = Vector3(push.x * 0.7, 1.5, push.y * 0.7)
		it["bspin"] = Vector3(randf_range(-6, 6), randf_range(-8, 8), randf_range(-6, 6))
	_flying.append(it)

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_t += dt
	for k in range(_wobble.size() - 1, -1, -1):
		var wb: Array = _wobble[k]
		var it: Dictionary = wb[0]
		wb[1] = float(wb[1]) + dt
		var t: float = wb[1]
		var own: Transform3D = it["own"]
		var a := sin(t * 9.0) * float(wb[2]) * exp(-t * 2.2)
		if t > 2.0:
			a = 0.0
			_wobble.remove_at(k)
		(it["mm"] as MultiMesh).set_instance_transform(it["i"], Transform3D(Basis(Vector3(1, 0, 0.3).normalized(), a) * own.basis, own.origin))
	for k in range(_flying.size() - 1, -1, -1):
		if _fly(_flying[k], dt):
			_flying.remove_at(k)

## One person's tumble; true once they're back on their feet.
func _fly(it: Dictionary, dt: float) -> bool:
	var n: Node3D = it["node"]
	it["t"] = float(it["t"]) + dt
	if it.has("bike"):
		var bk: Node3D = it["bike"]
		var bv: Vector3 = it["bvel"]
		if bk.position.y > 0.0 or bv.y > 0.0:
			bv.y -= GRAVITY * dt
			bk.position += bv * dt
			bk.rotation += (it["bspin"] as Vector3) * dt
			if bk.position.y <= 0.0:
				bk.position.y = 0.0
				bv = Vector3.ZERO
				# down on its side
				bk.rotation = Vector3(0, bk.rotation.y, PI * 0.5 * (1.0 if randf() < 0.5 else -1.0))
			it["bvel"] = bv
	match it["state"]:
		"fly":
			var v: Vector3 = it["vel"]
			v.y -= GRAVITY * dt
			n.position += v * dt
			var sp: Vector3 = it["spin"]
			n.basis = Basis(sp.normalized(), sp.length() * dt) * n.basis
			n.basis = n.basis.orthonormalized()
			for j in ["ArmL", "ArmR", "LegL", "LegR"]:
				var jn := n.get_node_or_null(j) as Node3D
				if jn != null:
					var ph := float(j.hash() % 7)
					jn.rotation = Vector3(sin(_t * 17.0 + ph) * 1.5 - 0.5, 0, sin(_t * 11.0 + ph) * 1.0)
			if n.position.y <= 0.15:
				n.position.y = 0.15
				if absf(v.y) > 2.5:
					v = Vector3(v.x * 0.6, -v.y * 0.4, v.z * 0.6)
					it["spin"] = sp * 0.5
				else:
					it["state"] = "down"
					it["t"] = 0.0
					v = Vector3.ZERO
			it["vel"] = v
		"down":
			var yaw := n.rotation.y
			n.basis = n.basis.slerp(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5), minf(1.0, dt * 8.0)).orthonormalized()
			if float(it["t"]) > 2.6:
				# up, dusted off, back on their way (or back on the bike)
				n.basis = Basis(Vector3.UP, yaw)
				n.position.y = 0.0
				for j in ["ArmL", "ArmR", "LegL", "LegR"]:
					var jn := n.get_node_or_null(j) as Node3D
					if jn != null:
						jn.rotation = Vector3.ZERO
				if it.has("bike"):
					var bk: Node3D = it["bike"]
					bk.rotation = Vector3(0, bk.rotation.y, 0)
					for side in ["L", "R"]:
						var arm := n.get_node_or_null("Arm" + side) as Node3D
						if arm != null:
							arm.rotation.x = -1.15
				(it["w"] as Dictionary)["down"] = false
				return true
	return false

## Everything stood back up and the birds back about (back at the site).
func reset() -> void:
	for it in _knocked:
		(it["mm"] as MultiMesh).set_instance_transform(it["i"], it["own"])
		it["down"] = false
		if is_instance_valid(it.get("node")):
			(it["node"] as Node).queue_free()
		it.erase("node")
	_knocked.clear()
	for wb in _wobble:
		(wb[0]["mm"] as MultiMesh).set_instance_transform(wb[0]["i"], wb[0]["own"])
	_wobble.clear()
	for sq in _squashed:
		var w: Dictionary = sq[0]
		(w["node"] as Node3D).transform = sq[1]
		_birds._walkers.append(w)
	_squashed.clear()
	for it in _flying:
		var n: Node3D = it["node"]
		n.basis = Basis(Vector3.UP, n.rotation.y)
		(it["w"] as Dictionary)["down"] = false
	_flying.clear()

static func _in_box(p: Vector2, at: Vector2, yaw: float, half: Vector2, pad: float) -> bool:
	var rel := p - at
	var fwd := Vector2(sin(yaw), cos(yaw))
	var left := Vector2(fwd.y, -fwd.x)
	return absf(rel.dot(left)) < half.x + pad and absf(rel.dot(fwd)) < half.y + pad

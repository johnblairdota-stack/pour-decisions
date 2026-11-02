## The three utes from tools/blender/utes.py (assets/cars/utes.glb): the
## Toyota Hilux, Ford Ranger and BYD Shark. Whole models for the traffic and
## the kerbs (cars.gd), and a body with four wheels that spin and steer for
## the one you're driving when you knock off (explore.gd).
extends RefCounted

const F := preload("res://scripts/factory.gd")
const LIB := "res://assets/cars/utes.glb"
const NAMES := ["Hilux", "Ranger", "Shark"]
const TITLE := {"Hilux": "Toyota Hilux SR5", "Ranger": "Ford Ranger XLT", "Shark": "BYD Shark 6"}

## As tools/blender/utes.py: length, half width, wheelbase, front overhang,
## track and tyre radius (m)
const SPEC := {
	"Hilux": {"L": 5.33, "hw": 0.905, "wb": 3.085, "front": 0.93, "track": 1.54, "r": 0.39},
	"Ranger": {"L": 5.36, "hw": 0.915, "wb": 3.22, "front": 0.93, "track": 1.56, "r": 0.39},
	"Shark": {"L": 5.457, "hw": 0.96, "wb": 3.26, "front": 0.98, "track": 1.67, "r": 0.405},
}

## Each one's own paint when it's yours: Glacier White, Lightning Blue,
## Atlantis Grey
const OWN_PAINT := {"Hilux": Color("f2f2ef"), "Ranger": Color("1f5fae"), "Shark": Color("5b6670")}

const COLORS := {
	"glass": Color("26323d"), "tyre": Color("1e1e1e"), "rim": Color("b9bfc4"), "rim_dark": Color("3a3e44"),
	"light": Color("eef3f6"), "drl": Color("ffffff"), "tail": Color("c8282a"), "amber": Color("ff9a1f"),
	"trim": Color("25282c"), "chrome": Color("d8dde2"), "grille": Color("1a1c1f"), "plate": Color("f4f4f2"),
	"liner": Color("2c2e31"), "skid": Color("9aa0a6"), "badge": Color("d8dde2"), "ford_blue": Color("1f4f9a"),
	# underneath (<Name>Under, <Name>AxleR) and the arch wells
	"chassis": Color("26282b"), "diff": Color("4a4d52"), "spring": Color("1b1d20"), "shock": Color("3a3e44"),
	"drum": Color("6b6460"), "exhaust": Color("8a847b"), "battery": Color("39424d"), "well": Color("1c1d1f"),
}

static var _lib: Node
static var _meshes := {}
static var _mats := {}

static func has(name: String) -> bool:
	return mesh(name) != null

## A model's mesh, painted by part; "body" takes each ute's own colour (the
## car paint shader's `tint`, or a multimesh's instance colour).
static func mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	if _lib == null:
		if not ResourceLoader.exists(LIB):
			return null
		_lib = (load(LIB) as PackedScene).instantiate()
	var mi := _lib.get_node_or_null(name) as MeshInstance3D
	if mi == null:
		_meshes[name] = null
		return null
	var m := mi.mesh
	for i in m.get_surface_count():
		var src := m.surface_get_material(i)
		m.surface_set_material(i, _mat(src.resource_name if src != null else ""))
	_meshes[name] = m
	return m

static func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	if key == "body":
		var s := ShaderMaterial.new()
		s.shader = preload("res://shaders/car_paint.gdshader")
		m = s
	elif key in ["light", "drl"]:
		m = F.color_mat(COLORS[key], false, Color(1.0, 0.97, 0.9) * (0.5 if key == "drl" else 0.25))
	else:
		m = F.color_mat(COLORS.get(key, Color.MAGENTA), false)
	_mats[key] = m
	return m

## A ute to drive: a "Body" pivot (it pitches and rolls on its springs) and
## four wheels, "FL" "FR" "RL" "RR", each a "Steer" pivot holding the "Spin".
static func drivable(name: String, paint: Color) -> Node3D:
	var s: Dictionary = SPEC[name]
	var root := Node3D.new()
	root.name = name
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var bm := MeshInstance3D.new()
	bm.name = "Shell"
	bm.mesh = mesh(name + "Body")
	bm.set_instance_shader_parameter("tint", paint)
	body.add_child(bm)
	# (what's underneath: rails, front diff, sump guard, tow bar; and the
	# rear axle, which rolls with the back wheels)
	var under := mesh(name + "Under")
	if under != null:
		var um := MeshInstance3D.new()
		um.name = "Under"
		um.mesh = under
		body.add_child(um)
	var zf: float = s["L"] * 0.5 - s["front"]
	var zr: float = zf - s["wb"]
	var axle := mesh(name + "AxleR")
	if axle != null:
		var am := MeshInstance3D.new()
		am.name = "AxleR"
		am.mesh = axle
		am.position = Vector3(0, s["r"], zr)
		root.add_child(am)
	for w in [["FL", 1.0, zf], ["FR", -1.0, zf], ["RL", 1.0, zr], ["RR", -1.0, zr]]:
		var steer := Node3D.new()
		steer.name = w[0]
		steer.position = Vector3(w[1] * s["track"] * 0.5, s["r"], w[2])
		root.add_child(steer)
		var spin := Node3D.new()
		spin.name = "Spin"
		steer.add_child(spin)
		var wm := MeshInstance3D.new()
		wm.mesh = mesh(name + "Wheel")
		if w[1] < 0.0:
			# (the rim faces out on both sides)
			wm.rotation.y = PI
		spin.add_child(wm)
		# (aired down, the tyre's squashed bottom: it doesn't turn)
		var bulge := mesh(name + "WheelBulge")
		if bulge != null:
			var bg := MeshInstance3D.new()
			bg.name = "Bulge"
			bg.mesh = bulge
			bg.visible = false
			if w[1] < 0.0:
				bg.rotation.y = PI
			steer.add_child(bg)
	return root

## How much lower an aired-down tyre's tread sits (tools/blender/utes.py)
const LOW_DROP := 0.035

## Swaps every wheel to its aired-down tyre (bagged sidewalls, squashed
## bottom) or back; mud-terrains have their own.
static func air(node: Node3D, name: String, low: bool, mud: bool) -> void:
	if bool(node.get_meta("aired", false)) == low:
		return
	node.set_meta("aired", low)
	var K: Script = load("res://scripts/ute_kit.gd") if mud and ResourceLoader.exists("res://scripts/ute_kit.gd") else null
	for w in ["FL", "FR", "RL", "RR"]:
		var steer := node.get_node(w) as Node3D
		var spin := steer.get_node("Spin") as Node3D
		if spin.get_child_count() == 0:
			continue
		var tyre := spin.get_child(0) as MeshInstance3D
		var m: Mesh
		if K != null:
			m = K.mesh("mudtyreslow" if low else "mudtyres", name.to_lower())
		else:
			m = mesh(name + ("WheelLow" if low else "Wheel"))
		if m != null:
			tyre.mesh = m
		var bg := steer.get_node_or_null("Bulge") as MeshInstance3D
		if bg != null:
			if K != null:
				var mb: Mesh = K.mesh("mudtyresbulge", name.to_lower())
				if mb != null:
					bg.mesh = mb
			bg.visible = low

## A lift kit raises the body this much (m)
const LIFT := 0.05

## Fits the bought 4x4 kit (scripts/ute_kit.gd, assets/cars/ute_kit.glb) to a
## drivable ute: each part goes under the Body so it rides the springs; mud
## tyres swap onto every wheel and lift it all by UteKit.MUD_UP. How high the
## body sits is left on the node as "ride" for explore.gd.
static func apply_kit(node: Node3D, ute: String, kit: Array) -> void:
	if kit.is_empty() or not ResourceLoader.exists("res://scripts/ute_kit.gd"):
		return
	var K: Script = load("res://scripts/ute_kit.gd")
	var body := node.get_node("Body") as Node3D
	var ride := 0.0
	for item in kit:
		var it := String(item)
		if it == "lift":
			ride += LIFT
			continue
		if it == "mudtyres":
			ride += K.MUD_UP
			for w in ["FL", "FR", "RL", "RR"]:
				var steer := node.get_node(w) as Node3D
				var spin := steer.get_node("Spin") as Node3D
				var tyre = K.part("mudtyres", ute)
				if tyre == null:
					break
				steer.position.y += K.MUD_UP
				for c in spin.get_children():
					c.queue_free()
				if steer.position.x < 0.0:
					tyre.rotation.y = PI
				spin.add_child(tyre)
			continue
		var part = K.part(it, ute)
		if part is Node3D:
			if it == "swag" and "drawers" in kit:
				part.position.y = K.DRAWER_H
			body.add_child(part)
	node.set_meta("ride", ride)

## What drives each one, near enough the real thing: kerb mass (kg), peak
## power (kW) and torque (Nm) and where it makes them, idle and redline
## (rpm), the gears and final drive, tyre radius, drag area (m²) and top
## speed (km/h). The Shark's a plug-in hybrid: its motors drive the wheels
## through one gear and the 1.5 petrol mostly runs as a generator.
const ENGINE := {
	"Hilux": {"mass": 2110.0, "kw": 150.0, "nm": 500.0, "torque_from": 1600.0, "power_at": 3400.0, "idle": 750.0,
		"red": 3600.0, "cut": 4000.0, "gears": [3.600, 2.090, 1.488, 1.000, 0.687, 0.580], "final": 3.909,
		"reverse": 3.732, "cda": 1.32, "top": 175.0, "kind": "diesel", "label": "2.8 turbo diesel · 6-speed auto"},
	"Ranger": {"mass": 2250.0, "kw": 154.0, "nm": 500.0, "torque_from": 1750.0, "power_at": 3750.0, "idle": 780.0,
		"red": 4250.0, "cut": 4500.0, "gears": [4.696, 2.985, 2.146, 1.769, 1.520, 1.275, 1.000, 0.854, 0.689, 0.636],
		"final": 3.73, "reverse": 4.866, "cda": 1.30, "top": 180.0, "kind": "diesel",
		"label": "2.0 bi-turbo diesel · 10-speed auto"},
	"Shark": {"mass": 2710.0, "kw": 321.0, "nm": 650.0, "torque_from": 0.0, "power_at": 0.0, "idle": 0.0,
		"red": 0.0, "cut": 0.0, "gears": [9.2], "final": 1.0, "reverse": 9.2, "cda": 1.28, "top": 160.0,
		"kind": "phev", "label": "1.5 turbo plug-in hybrid · twin motors"},
}

## Engine torque at `rpm` with the throttle wide open (Nm): building from
## idle to its plateau, flat to where peak power comes in, then falling
## away so the power holds.
static func torque_at(e: Dictionary, rpm: float) -> float:
	var nm: float = e["nm"]
	var from: float = e["torque_from"]
	var idle: float = e["idle"]
	if rpm < from:
		return nm * lerpf(0.35, 1.0, clampf((rpm - idle) / maxf(from - idle, 1.0), 0.0, 1.0))
	var p_nm := float(e["kw"]) * 1000.0 / (rpm * TAU / 60.0)
	return minf(nm, p_nm) * (1.0 if rpm <= float(e["red"]) else clampf(1.0 - (rpm - float(e["red"])) / 600.0, 0.0, 1.0))

## Body copies with their own vertices, so each ute you drive dents on its
## own: `mi` gets a mesh of its own and keeps its arrays in meta "dent".
static func own_body(mi: MeshInstance3D) -> void:
	var src := mi.mesh
	var surfs: Array = []
	for s in src.get_surface_count():
		surfs.append([src.surface_get_arrays(s), src.surface_get_material(s)])
	mi.set_meta("dent", surfs)
	_rebuild(mi)

## Pushes the body in round `at` (its own metres) by up to `depth` along
## `dir`, fading out over `radius`, and turns the faces there so the light
## shows the crease.
static func dent(mi: MeshInstance3D, at: Vector3, dir: Vector3, depth: float, radius: float) -> void:
	if not mi.has_meta("dent"):
		own_body(mi)
	for sf in mi.get_meta("dent"):
		var arr: Array = sf[0]
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i in vs.size():
			var d := vs[i].distance_to(at)
			if d >= radius:
				continue
			var k := 1.0 - d / radius
			k = k * k * (3.0 - 2.0 * k)
			# (a bit of crumple, so it doesn't push in as a smooth dish)
			var j := 0.75 + 0.5 * fposmod(sin(vs[i].x * 37.0 + vs[i].y * 53.0 + vs[i].z * 29.0) * 43758.5, 1.0)
			vs[i] += dir * depth * k * j
			if ns.size() == vs.size():
				ns[i] = (ns[i] + dir * k * 0.9 + Vector3(sin(vs[i].z * 19.0), cos(vs[i].x * 23.0), 0) * k * 0.35).normalized()
		arr[Mesh.ARRAY_VERTEX] = vs
		if ns.size() == vs.size():
			arr[Mesh.ARRAY_NORMAL] = ns
	_rebuild(mi)

static func _rebuild(mi: MeshInstance3D) -> void:
	var m := ArrayMesh.new()
	for sf in mi.get_meta("dent"):
		var arr: Array = (sf[0] as Array).duplicate()
		# (tangents go stale once it's bent; the toon shading doesn't use them)
		arr[Mesh.ARRAY_TANGENT] = null
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(m.get_surface_count() - 1, sf[1])
	mi.mesh = m

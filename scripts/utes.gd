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
	bm.mesh = mesh(name + "Body")
	bm.set_instance_shader_parameter("tint", paint)
	body.add_child(bm)
	var zf: float = s["L"] * 0.5 - s["front"]
	var zr: float = zf - s["wb"]
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
	return root

## Fits the bought 4x4 kit (scripts/ute_kit.gd, assets/cars/ute_kit.glb) to a
## drivable ute: each item's part goes under the Body, so it rides the springs.
static func apply_kit(node: Node3D, ute: String, kit: Array) -> void:
	if kit.is_empty() or not ResourceLoader.exists("res://scripts/ute_kit.gd"):
		return
	var K: Script = load("res://scripts/ute_kit.gd")
	var body := node.get_node("Body") as Node3D
	for item in kit:
		var part = K.part(String(item), ute)
		if part is Node3D:
			body.add_child(part)

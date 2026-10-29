## The 4x4 and camping gear for the utes, from tools/blender/ute_kit.py
## (assets/cars/ute_kit.glb), bought from the shop in a player's wallet.
## Each part is fitted to its ute: put it under the ute's body with no
## offset. "mudtyres" is one whole wheel, for swapping onto each wheel (raise
## the wheel centres by MUD_UP); "lift" has no part, the body just sits higher.
extends RefCounted

const F := preload("res://scripts/factory.gd")
const LIB := "res://assets/cars/ute_kit.glb"
const UTES := ["hilux", "ranger", "shark"]
const ITEMS := ["bullbar", "winch", "spotlights", "snorkel", "lightbar", "mudtyres", "roofrack", "rooftent",
	"awning", "canopy", "drawers", "fridge", "jerrycans", "swag"]

## What each part needs fitted first
const NEEDS := {"winch": "bullbar", "spotlights": "bullbar", "rooftent": "roofrack", "awning": "roofrack"}
## The mud tyres are this much taller than the standard ones (m)
const MUD_UP := 0.045
## The swag lies on the tub floor; on top of the drawers it sits this much higher
const DRAWER_H := 0.30

const COLORS := {
	"bar": Color("1d1f22"), "bar_plate": Color("2a2d31"), "steel": Color("9aa0a6"), "light": Color("eef3f6"),
	"lens": Color("f6f2dc"), "amber": Color("ff9a1f"), "hook": Color("d9302c"), "rope": Color("c9c2b0"),
	"tyre": Color("1e1e1e"), "rim_black": Color("2a2d31"), "badge": Color("d8dde2"), "rack": Color("26292d"),
	"shell": Color("3a3e44"), "canvas": Color("4a5560"), "canopy": Color("2b2e33"), "glass": Color("26323d"),
	"drawer": Color("2f3338"), "carpet": Color("3a3d40"), "handle": Color("b9bfc4"), "fridge": Color("c4c8cc"),
	"fridge_lid": Color("2b2f36"), "jerry": Color("c8402e"), "jerry_d": Color("e8b830"), "swag": Color("6f6a4a"),
	"strap": Color("1d1f22"),
}

static var _lib: Node
static var _meshes := {}
static var _mats := {}

## One part for one ute ("hilux", "ranger", "shark"), painted; null if
## there's no such part.
static func part(item: String, ute: String) -> MeshInstance3D:
	var m := mesh(item, ute)
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = item
	mi.mesh = m
	return mi

static func mesh(item: String, ute: String) -> Mesh:
	var key := "kit_%s_%s" % [item, ute.to_lower()]
	if _meshes.has(key):
		return _meshes[key]
	if _lib == null:
		if not ResourceLoader.exists(LIB):
			return null
		_lib = (load(LIB) as PackedScene).instantiate()
	var mi := _lib.get_node_or_null(key) as MeshInstance3D
	if mi == null:
		_meshes[key] = null
		return null
	var m := mi.mesh
	for i in m.get_surface_count():
		var src := m.surface_get_material(i)
		m.surface_set_material(i, _mat(src.resource_name if src != null else ""))
	_meshes[key] = m
	return m

static func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	if key == "body":
		var s := ShaderMaterial.new()
		s.shader = preload("res://shaders/car_paint.gdshader")
		m = s
	elif key in ["light", "lens"]:
		m = F.color_mat(COLORS[key], false, Color(1.0, 0.97, 0.88) * 0.3)
	else:
		m = F.color_mat(COLORS.get(key, Color.MAGENTA), false)
	_mats[key] = m
	return m

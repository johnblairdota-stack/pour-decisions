## The 4x4 and camping gear for the utes, from tools/blender/ute_kit.py
## (assets/cars/ute_kit.glb), bought from the shop in a player's wallet.
## Each part is fitted to its ute: put it under the ute's body with no
## offset. "mudtyres" is one whole wheel, for swapping onto each wheel (raise
## the wheel centres by MUD_UP); "lift" has no part, the body just sits higher.
extends RefCounted

const F := preload("res://scripts/factory.gd")
const LIB := "res://assets/cars/ute_kit.glb"
const UTES := ["hilux", "ranger", "shark"]
## The mud tyres are this much taller than the standard ones (m)
const MUD_UP := 0.045
## The swag lies on the tub floor; on top of the drawers it sits this much higher
const DRAWER_H := 0.30
## How far the canopy's gull wing doors swing up when they're open (rad)
const WING_OPEN := 2.5

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

## What fitting `item` puts on the ute's body, given all the `kit` that's on
## it, placed: the swag goes on the drawers if they're in, or up on the
## canopy's roof if that's on; the canopy brings its two gull wing doors
## (pivots "WingL"/"WingR" on their hinges, open: see wings()).
static func fit(item: String, ute: String, kit: Array) -> Array:
	var out: Array = []
	if item == "swag" and "canopy" in kit:
		var roof := part("swagroof", ute)
		if roof != null:
			roof.name = "swag"
			return [roof]
	var p := part(item, ute)
	if p == null:
		return out
	if item == "swag" and "drawers" in kit:
		p.position.y = DRAWER_H
	out.append(p)
	if item == "canopy":
		var hinge := origin("canopywing", ute)
		for side in [1.0, -1.0]:
			var m := part("canopywing", ute)
			if m == null:
				break
			var pv := Node3D.new()
			pv.name = "WingL" if side > 0.0 else "WingR"
			pv.position = Vector3(hinge.x * side, hinge.y, hinge.z)
			pv.rotation.z = WING_OPEN * side
			if side < 0.0:
				m.rotation.y = PI
			pv.add_child(m)
			out.append(pv)
	return out

## Opens (1) or shuts (0) the canopy's gull wing doors, if it has them.
static func wings(body: Node3D, open: float) -> void:
	for side in [1.0, -1.0]:
		var pv := body.get_node_or_null("WingL" if side > 0.0 else "WingR") as Node3D
		if pv != null:
			pv.rotation.z = WING_OPEN * side * open

## Where a part's origin sits on the ute (its node's place in the library).
static func origin(item: String, ute: String) -> Vector3:
	mesh(item, ute)
	if _lib == null:
		return Vector3.ZERO
	var n := _lib.get_node_or_null("kit_%s_%s" % [item, ute.to_lower()]) as Node3D
	return n.position if n != null else Vector3.ZERO

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

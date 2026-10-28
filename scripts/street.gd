## The street furniture round Riverlight, drawn as multimeshes: one per model
## per tile near the site, toon-painted by part name. The models are
## tools/blender/street.py (assets/street/street.glb); scripts/surrounds.gd
## decides where they go. Also the kerbs and the centre lines down the local
## streets, and the street name lettering.
extends RefCounted

const F := preload("res://scripts/factory.gd")
const LIB := "res://assets/street/street.glb"
const TILE := 160.0

const COLORS := {
	"galv": Color("a9b0b5"), "galv_dark": Color("7d858b"), "lamp_head": Color("5a6168"), "lamp_glow": Color("fff4d0"),
	"steel_black": Color("2e3236"), "timber": Color("b98a55"), "timber_dark": Color("8e6a44"), "concrete": Color("c4c2bb"),
	"glass": Color("9cc3d6"), "shelter_roof": Color("e8e6df"), "sign_blue": Color("1f4f9a"), "sign_white": Color("f4f7fa"),
	"sign_red": Color("d9302c"), "sign_yellow": Color("ffc72c"), "bin_green": Color("2f5f3f"), "bin_lid": Color("24442f"),
	"stainless": Color("d2d6d8"), "bbq_roof": Color("3d6f73"), "seat": Color("2f6fd1"),
}
const KERB := Color("c4c2bb")
const LINE := Color("eeeeea")

static var _lib: Node
static var _meshes := {}
static var _glow: ShaderMaterial

## One model's mesh, its parts given toon materials.
static func mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	if _lib == null:
		_lib = (load(LIB) as PackedScene).instantiate()
	var mi := _lib.get_node_or_null(name) as MeshInstance3D
	if mi == null:
		push_warning("street: no model " + name)
		_meshes[name] = null
		return null
	var m := mi.mesh
	for i in m.get_surface_count():
		var src := m.surface_get_material(i)
		var key := src.resource_name if src != null else ""
		if key == "lamp_glow":
			if _glow == null:
				_glow = F.color_mat(COLORS[key], false)
			m.surface_set_material(i, _glow)
		else:
			m.surface_set_material(i, _mat(key))
	_meshes[name] = m
	return m

static var _mats := {}
static func _mat(key: String) -> Material:
	if not _mats.has(key):
		_mats[key] = F.color_mat(COLORS.get(key, Color.MAGENTA), false)
	return _mats[key]

## The street lights' glow, 0 (day) to 1 (before sunrise on a dawn pour).
static func set_lit(k: float) -> void:
	if _glow != null:
		_glow.set_shader_parameter("emission_color", Color(1.0, 0.86, 0.55) * (1.6 * k))

## Places `items` (each [model name, Transform3D]) under `root`.
static func place(root: Node3D, items: Array) -> void:
	var groups := {}
	for it in items:
		var t: Transform3D = it[1]
		var key := "%s|%d|%d" % [it[0], floori(t.origin.x / TILE), floori(t.origin.z / TILE)]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(t)
	for key in groups:
		var name: String = (key as String).split("|")[0]
		var m := mesh(name)
		if m == null:
			continue
		var list: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Street_" + (key as String).replace("|", "_")
		mi.multimesh = mm
		# (only the tall, solid things throw a shadow worth drawing)
		if not name in ["StreetLight", "BusShelter", "BBQShelter", "ParkLight"]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)

## A model standing at `p` (ground), its front (+z) towards `face`.
static func at(p: Vector2, face: Vector2, y := 0.0, sx := 1.0) -> Transform3D:
	var yaw := atan2(face.x, face.y)
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sx, 1, 1)), Vector3(p.x, y, p.y))

## The lettering on a street name blade placed with at(): both faces.
static func letter(root: Node3D, t: Transform3D, text: String) -> void:
	for side in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = text
		l.font_size = 40
		l.pixel_size = 0.0028
		l.outline_size = 0
		l.modulate = Color("f4f7fa")
		l.double_sided = false
		l.shaded = false
		l.transform = t * Transform3D(Basis(Vector3.UP, 0.0 if side > 0 else PI), Vector3(0.5, 2.6, 0.03 * side))
		root.add_child(l)

## Kerbs: strips (each [a, b] on the ground) as one mesh, a 0.3 x 0.13 m
## concrete upstand.
static func kerbs(root: Node3D, strips: Array) -> void:
	_strips(root, strips, 0.3, 0.13, KERB, "Kerbs")

## Centre line dashes (each [a, b]), white paint just proud of the road.
static func lines(root: Node3D, dashes: Array) -> void:
	_strips(root, dashes, 0.12, 0.07, LINE, "CentreLines")

static func _strips(root: Node3D, strips: Array, w: float, h: float, c: Color, nm: String) -> void:
	if strips.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in strips:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x) * w * 0.5
		var q := [a - n, b - n, b + n, a + n]
		_face(st, [Vector3(q[0].x, h, q[0].y), Vector3(q[1].x, h, q[1].y), Vector3(q[2].x, h, q[2].y),
			Vector3(q[3].x, h, q[3].y)], Vector3.UP)
		for side in [[0, 1, -n], [2, 3, n]]:
			var p0: Vector2 = q[side[0]]
			var p1: Vector2 = q[side[1]]
			var nn: Vector2 = (side[2] as Vector2).normalized()
			_face(st, [Vector3(p0.x, 0, p0.y), Vector3(p1.x, 0, p1.y), Vector3(p1.x, h, p1.y),
				Vector3(p0.x, h, p0.y)], Vector3(nn.x, 0, nn.y))
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = st.commit()
	mi.material_override = F.color_mat(c, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

## A quad, wound whichever way faces `nrm` (it's drawn one-sided).
static func _face(st: SurfaceTool, v: Array, nrm: Vector3) -> void:
	var c: Vector3 = (v[1] - v[0]).cross(v[2] - v[0])
	if c.dot(nrm) > 0.0:
		v = [v[0], v[3], v[2], v[1]]
	st.set_normal(nrm)
	for i in [0, 1, 2, 0, 2, 3]:
		st.add_vertex(v[i])

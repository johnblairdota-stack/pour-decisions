## Builds the prototype's stylized meshes from primitives: materials, beams,
## lattice sections, chibi crew and props. Swap these for modelled assets later.
extends RefCounted

const TOON := preload("res://shaders/toon.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const WINDOWS := preload("res://shaders/windows.gdshader")

const COLORS := {
	"concrete": Color("b9bec5"),
	"column": Color("8a929c"),
	"core": Color("b7bcc3"),
	"yellow": Color("ffc72c"),
	"yellow_dark": Color("e0a800"),
	"orange": Color("ff7a1a"),
	"steel": Color("afc0d2"),
	"pipe": Color("dce1e6"),
	"hose": Color("2b2b2b"),
	"navy": Color("24324f"),
	"skin": Color("f2c9a0"),
	"white": Color("f4f7fa"),
	"eye": Color("151515"),
	"cheek": Color("f08a7a"),
	"ply": Color("c48d55"),
	"wet": Color("8f949b"),
	"wet_full": Color("e9ecef"),
	"grass": Color("6a8a4c"),
	"road": Color("3c4048"),
	"river": Color("4f6660"),
	"tree": Color("4f8a4a"),
	"trunk": Color("7a5a3a"),
	"bridge": Color("c4c3bc"),
	"podium": Color("7d848e"),
	"red": Color("ff4d4d"),
	"green": Color("7cd992"),
	"blue": Color("4fa3ff"),
	"rope": Color("d9c27a"),
	# The surroundings (scripts/surrounds.gd)
	"rock": Color("6b665c"),
	"palm": Color("5f8f3e"),
	"palm_trunk": Color("8a7a63"),
	"shed": Color("c9c6bd"),
	"shed_roof": Color("a9adb0"),
	"dry_grass": Color("a39a68"),
	"fairway": Color("7fae58"),
	"green_cut": Color("8cc063"),
	"sand": Color("e6d7aa"),
	"citycat_blue": Color("1f4f8f"),
}

static var _cache := {}

static func mat(name: String, outlined := false) -> ShaderMaterial:
	var key := name + ("_o" if outlined else "")
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", COLORS.get(name, Color.MAGENTA))
	if outlined:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE
		m.next_pass = o
	_cache[key] = m
	return m

static func color_mat(c: Color, outlined := false, emission := Color.BLACK) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("emission_color", emission)
	if outlined:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE
		m.next_pass = o
	return m

static func window_mat(frame: Color, lit_ratio: float, glow := 1.2, glass := Color(0.20, 0.30, 0.46)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WINDOWS
	m.set_shader_parameter("frame_color", frame)
	m.set_shader_parameter("glass_color", glass)
	m.set_shader_parameter("lit_ratio", lit_ratio)
	m.set_shader_parameter("glow", glow)
	return m

static func flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func box(size: Vector3, material: Material, pos := Vector3.ZERO, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static func sphere(radius: float, material: Material, pos := Vector3.ZERO, hemisphere := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * (1.0 if hemisphere else 2.0)
	sm.is_hemisphere = hemisphere
	sm.radial_segments = 24
	sm.rings = 12
	mi.mesh = sm
	mi.material_override = material
	mi.position = pos
	return mi

static func cylinder(radius: float, height: float, material: Material, pos := Vector3.ZERO, sides := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = sides
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	return mi

## A square-section beam between two points.
static func beam(a: Vector3, b: Vector3, thickness: float, material: Material) -> MeshInstance3D:
	var d := b - a
	var mi := box(Vector3(thickness, thickness, d.length()), material)
	var dir := d.normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(dir, up), (a + b) * 0.5)
	return mi

## One free-standing lattice tower section (SCP-style), base at y = 0.
static func lattice_section(height: float, width: float) -> Node3D:
	var g := Node3D.new()
	var h := width * 0.5
	var steel := mat("steel")
	var corners := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
	for c in corners:
		g.add_child(beam(c, c + Vector3(0, height, 0), 0.16, steel))
	for i in 4:
		var c1: Vector3 = corners[i]
		var c2: Vector3 = corners[(i + 1) % 4]
		g.add_child(beam(c1 + Vector3(0, 0.1, 0), c2 + Vector3(0, height * 0.5, 0), 0.08, steel))
		g.add_child(beam(c2 + Vector3(0, height * 0.5, 0), c1 + Vector3(0, height - 0.1, 0), 0.08, steel))
		g.add_child(beam(c1 + Vector3(0, height - 0.05, 0), c2 + Vector3(0, height - 0.05, 0), 0.1, steel))
	return g

## A chibi crew member, about 1.3 m tall, facing +Z. Returns the root with
## named parts so scripts can animate arms, legs and head.
static func chibi(vest_color: Color, hat_color := Color("ffc72c")) -> Node3D:
	var root := Node3D.new()
	root.name = "Chibi"
	var vest := color_mat(vest_color, true)
	var navy := mat("navy", true)
	var skin := mat("skin", true)

	var leg_l := cylinder(0.11, 0.42, navy, Vector3(-0.13, 0.21, 0), 10)
	leg_l.name = "LegL"
	var leg_r := cylinder(0.11, 0.42, navy, Vector3(0.13, 0.21, 0), 10)
	leg_r.name = "LegR"
	root.add_child(leg_l)
	root.add_child(leg_r)

	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.28
	cm.bottom_radius = 0.34
	cm.height = 0.55
	cm.radial_segments = 16
	body.mesh = cm
	body.material_override = vest
	body.position = Vector3(0, 0.68, 0)
	root.add_child(body)
	root.add_child(cylinder(0.33, 0.07, mat("white"), Vector3(0, 0.64, 0), 16))

	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.name = "ArmL" if side < 0 else "ArmR"
		pivot.position = Vector3(0.36 * side, 0.9, 0)
		pivot.rotation.z = 0.25 * side
		var arm := cylinder(0.08, 0.42, vest, Vector3(0, -0.21, 0), 8)
		pivot.add_child(arm)
		var hand := sphere(0.09, skin, Vector3(0, -0.44, 0))
		hand.set_meta("skin", true)
		pivot.add_child(hand)
		root.add_child(pivot)

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.32, 0)
	root.add_child(head)
	var face := sphere(0.42, skin)
	face.set_meta("skin", true)
	head.add_child(face)
	var eye := mat("eye")
	var eye_l := sphere(0.055, eye, Vector3(-0.14, 0.02, 0.39))
	eye_l.name = "EyeL"
	head.add_child(eye_l)
	var eye_r := sphere(0.055, eye, Vector3(0.14, 0.02, 0.39))
	eye_r.name = "EyeR"
	head.add_child(eye_r)
	var cheek_l := sphere(0.075, mat("cheek"), Vector3(-0.24, -0.1, 0.34))
	cheek_l.scale = Vector3(1, 1, 0.4)
	var cheek_r := sphere(0.075, mat("cheek"), Vector3(0.24, -0.1, 0.34))
	cheek_r.scale = Vector3(1, 1, 0.4)
	head.add_child(cheek_l)
	head.add_child(cheek_r)
	var hat_mat := color_mat(hat_color, true)
	head.add_child(sphere(0.46, hat_mat, Vector3(0, 0.06, 0), true))
	head.add_child(cylinder(0.56, 0.05, color_mat(hat_color.darkened(0.15), true), Vector3(0, 0.08, 0.06), 20))
	return root

static func label3d(text: String, size := 48, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 12
	l.modulate = color
	l.outline_modulate = Color(0.04, 0.07, 0.12, 1)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.01
	return l


## Dresses a chibi as one of the named crew: skin tone, plus one signature
## look (moustache, beard, ponytail, bun, sunnies or earmuffs) and hair colour.
static func dress(root: Node3D, ch: Dictionary) -> void:
	var skin := color_mat(Color(ch.get("skin", "f2c9a0")), true)
	_reskin(root, skin)
	var head: Node3D = root.get_node("Head")
	if head.has_node("Look"):
		var old := head.get_node("Look")
		head.remove_child(old)
		old.queue_free()
	var look := Node3D.new()
	look.name = "Look"
	head.add_child(look)
	var hair := color_mat(Color(ch.get("hair", "4a3122")), true)
	match String(ch.get("look", "")):
		"moustache":
			var m := sphere(0.1, hair, Vector3(0, -0.13, 0.4))
			m.scale = Vector3(1.9, 0.45, 0.6)
			look.add_child(m)
		"beard":
			var b := sphere(0.3, hair, Vector3(0, -0.2, 0.2))
			b.scale = Vector3(1.15, 0.75, 0.9)
			look.add_child(b)
		"ponytail":
			look.add_child(sphere(0.12, hair, Vector3(0, -0.02, -0.44)))
			var t := sphere(0.1, hair, Vector3(0, -0.24, -0.5))
			t.scale = Vector3(0.9, 1.7, 0.9)
			look.add_child(t)
		"bun":
			look.add_child(sphere(0.15, hair, Vector3(0, 0.02, -0.46)))
		"sunnies":
			var dark := color_mat(Color("10151d"), false)
			for x in [-0.15, 0.15]:
				var lens := box(Vector3(0.2, 0.11, 0.03), dark, Vector3(x, 0.03, 0.41))
				look.add_child(lens)
			look.add_child(box(Vector3(0.12, 0.03, 0.03), dark, Vector3(0, 0.06, 0.42)))
		"earmuffs":
			var red := color_mat(Color("ff4d4d"), true)
			for x in [-0.42, 0.42]:
				var cup := cylinder(0.13, 0.09, red, Vector3(x, 0.0, 0.0), 12)
				cup.rotation.z = PI * 0.5
				look.add_child(cup)

static func _reskin(n: Node, skin: Material) -> void:
	for c in n.get_children():
		if c is MeshInstance3D and c.has_meta("skin"):
			(c as MeshInstance3D).material_override = skin
		_reskin(c, skin)

## An upright prism over a floor plan `poly` (x/z points), from y0 up `h`:
## a floor slab or a storey of facade on a building that isn't a box. Each
## face goes in both windings with its own normal, so it reads from any side
## whichever way round the plan was drawn.
static func prism(poly: PackedVector2Array, y0: float, h: float, material: Material, caps := true) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := func(a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
		for v in [a, b, c, a, c, b]:
			st.set_normal(n)
			st.add_vertex(v)
	if caps:
		var idx := Geometry2D.triangulate_polygon(poly)
		for i in range(0, idx.size(), 3):
			var p := [poly[idx[i]], poly[idx[i + 1]], poly[idx[i + 2]]]
			for y in [y0, y0 + h]:
				tri.call(Vector3(p[0].x, y, p[0].y), Vector3(p[1].x, y, p[1].y), Vector3(p[2].x, y, p[2].y), Vector3.UP if y > y0 else Vector3.DOWN)
	# Outward from each wall: which side that is depends on the plan's winding
	var area := 0.0
	for i in poly.size():
		area += poly[i].cross(poly[(i + 1) % poly.size()])
	var out_k := 1.0 if area > 0.0 else -1.0
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var d := (b - a).normalized()
		var n := Vector3(d.y, 0, -d.x) * out_k
		var a0 := Vector3(a.x, y0, a.y)
		var b0 := Vector3(b.x, y0, b.y)
		var up := Vector3(0, h, 0)
		tri.call(a0, b0, b0 + up, n)
		tri.call(a0, b0 + up, a0 + up, n)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material
	return mi

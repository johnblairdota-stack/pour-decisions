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

## Riverlight's own facade (white slab bands, dark glass, charcoal panels)
static func riverlight_mat() -> ShaderMaterial:
	var m := window_mat(Color("ecebe8"), 0.0, 0.0, Color("6f818a"))
	m.set_shader_parameter("riverlight", true)
	m.set_shader_parameter("cell", Vector2(1.5, 3.0))
	m.set_shader_parameter("panel_color", Color("2e3136"))
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
## Modelled 2.0 m square and 4.14 m tall (tools/blender/towers.py); its four
## chords and four faces are separate parts, so a dropped one bends apart.
static func lattice_section(height: float, width: float) -> Node3D:
	var g := prop("MastSection", {}, TOWERS)
	if not is_equal_approx(height, 4.14) or not is_equal_approx(width, 2.0):
		g.scale = Vector3(width / 2.0, height / 4.14, width / 2.0)
	return g

## A chibi crew member, about 1.3 m tall, facing +Z. Returns the root with
## named parts so scripts can animate arms, legs and head.
## The crew model, built in Blender (tools/blender/crew.py, assets/crew/crew.glb).
## It keeps the joints the game animates: LegL and LegR swing at the hip,
## ArmL and ArmR pivot at the shoulder with the hand 0.46 down, Head at 1.32
## with EyeL and EyeR to blink. Every material is named for what it is (skin,
## vest, hat, tape ...) and gets the game's toon look here; the Look_* and
## Kit_* parts start hidden (dress() and kit() turn them on).
const CREW_GLB := "res://assets/crew/crew.glb"
## The crew's fixed colours, by material name. The rest come per person:
## vest and hat (the call), skin and hair (dress()).
const CREW_COLORS := {
	"tape": Color("dfe4e8"), "pants": Color("24324f"), "kneepad": Color("3a3f47"),
	"belt": Color("2a2a2a"), "steel": Color("afc0d2"), "boot": Color("8a5a32"), "sole": Color("2b2b2b"),
	"gumboot": Color("eef0f2"), "glove": Color("d9b26b"), "skin": Color("f2c9a0"), "nose": Color("e8bd94"), "hair": Color("4a3122"),
	"eye": Color("151515"), "eye_hi": Color("ffffff"), "cheek": Color("f08a7a"), "mouth": Color("7a3030"),
	"lens": Color("10151d"), "muff": Color("ff4d4d"), "kit_muff": Color("3d4a2f"), "radio": Color("1d1f22"),
	"remote": Color("ffc72c"), "red": Color("e5383b"), "harness": Color("22262b"), "docket": Color("fff4c2"),
	"splat": Color("a9adb3"),
}
## Small or painted-on parts: no outline (it would swallow them)
const CREW_NO_OUTLINE := ["nose", "eye", "eye_hi", "cheek", "mouth", "tape", "pocket", "splat", "docket",
	"wet", "wet_crust", "chain", "rope"]
## What each job wears (role keys as in crew.gd)
const CREW_KIT := {
	"line": ["Kit_Radio", "Kit_Docket"],
	"pump": ["Kit_Radio", "Kit_Earmuffs"],
	"boom": ["Kit_BellyBox"],
	"hose": ["Kit_GumbootL", "Kit_GumbootR", "Kit_SplatterL", "Kit_SplatterR"],
	"poker": ["Kit_GumbootL", "Kit_GumbootR", "Kit_SplatterL", "Kit_SplatterR", "Kit_Earmuffs"],
	"screed": ["Kit_GumbootL", "Kit_GumbootR", "Kit_SplatterL", "Kit_SplatterR"],
	"dogman": ["Kit_Harness", "Kit_Whistle", "Kit_Radio"],
	"rigger": ["Kit_Harness", "Kit_Radio"],
}

static var _crew_scene: PackedScene

## Tools and site props, built in Blender (tools/blender/props.py): one node
## each, by name (ScreedBoard, PokerHead, ClampHalfA, Pipe3m, Shovel ...).
const PROPS_GLB := "res://assets/props/props.glb"
const TOWERS := "res://assets/plant/towers.glb"
const PROP_COLORS := {
	"alu": Color("c9d1d8"), "grip": Color("22262b"), "dark_steel": Color("6b7480"), "machine": Color("ffc72c"),
	"fuel": Color("e5383b"), "rubber": Color("1d1f23"), "pipe": Color("dce1e6"), "clamp": Color("c7d0da"),
	"bin": Color("2f6fd1"), "bin_dark": Color("24559f"), "rack": Color("e0a800"), "tray": Color("2f8f6b"),
	"wet": Color("8f949b"), "timber": Color("b98a55"), "barrow": Color("3d7a4a"), "tyre": Color("1d1f23"),
	"rope": Color("d9c27a"), "chain": Color("8a929c"), "bucket": Color("2b2b2b"), "wet_crust": Color("9b968a"),
	# The plant (tools/blender/plant.py)
	"cab": Color("f4f7fa"), "glass": Color("5b7fa8"), "chassis": Color("24324f"), "rim": Color("c9d1d8"),
	"drum": Color("e8ebee"), "livery": Color("ff7a1a"), "light": Color("fff4c2"), "tail": Color("e5383b"),
	"amber": Color("ffb020"), "machine_dark": Color("e0a800"), "water": Color("4f8fbf"), "grille": Color("2b2b2b"),
	# The tall plant (tools/blender/towers.py)
	"orange": Color("ff7a1a"), "ballast": Color("a7aaa6"),
}
static var _libs := {}
## Props are small: a crew-weight outline would swallow a shovel handle
const PROP_OUTLINE := 0.012

## A fresh copy of one prop, toon-painted. `per` swaps a material by name
## (a worn clamp's colour, say).
## `glb` picks another model file of named parts (the plant, say).
static func prop(prop_name: String, per := {}, glb := PROPS_GLB) -> Node3D:
	if not _libs.has(glb):
		_libs[glb] = (load(glb) as PackedScene).instantiate()
	var src: Node = _libs[glb].get_node_or_null(prop_name)
	if src == null:
		push_warning("no prop " + prop_name)
		return Node3D.new()
	var n: Node3D = src.duplicate()
	n.transform = Transform3D.IDENTITY
	_paint(n, per, PROP_OUTLINE)
	return n

static func chibi(vest_color: Color, hat_color := Color("ffc72c")) -> Node3D:
	if _crew_scene == null:
		_crew_scene = load(CREW_GLB)
	var root: Node3D = _crew_scene.instantiate()
	root.name = "Chibi"
	var per := {
		"vest": color_mat(vest_color, true),
		"pocket": color_mat(vest_color.darkened(0.12), false),
		"hat": color_mat(hat_color, true),
		"hat_dark": color_mat(hat_color.darkened(0.15), true),
		"hat_rib": color_mat(hat_color.darkened(0.07), false),
	}
	_paint(root, per)
	for n in _crew_parts(root):
		if n.name.begins_with("Look_") or n.name.begins_with("Kit_"):
			n.visible = false
	# Arms hang a little out from the body, as the chibi's always did
	(root.get_node("ArmL") as Node3D).rotation.z = -0.25
	(root.get_node("ArmR") as Node3D).rotation.z = 0.25
	return root

static func _crew_parts(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		out.append(c)
		out.append_array(_crew_parts(c))
	return out

## Gives every surface of the crew model its toon material, by the name it
## has in Blender. `per` overrides by name (this person's vest, hat, skin).
static func _paint(root: Node, per: Dictionary, outline := 0.0) -> void:
	for n in [root] + _crew_parts(root):
		if not n is MeshInstance3D:
			continue
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var key := src.resource_name if src != null else ""
			if per.has(key):
				mi.set_surface_override_material(i, per[key])
			elif mi.get_surface_override_material(i) == null:
				mi.set_surface_override_material(i, _crew_mat(key, outline))

## `outline` > 0 sets the outline's thickness (else the shader's own).
static func _crew_mat(key: String, outline := 0.0) -> ShaderMaterial:
	var ck := "crew_%s_%s" % [key, outline]
	if not _cache.has(ck):
		var c: Color = CREW_COLORS.get(key, PROP_COLORS.get(key, Color.MAGENTA))
		var m := color_mat(c, not key in CREW_NO_OUTLINE)
		if outline > 0.0 and m.next_pass != null:
			(m.next_pass as ShaderMaterial).set_shader_parameter("thickness", outline)
		_cache[ck] = m
	return _cache[ck]

## Puts on (or takes off) what a job wears: `job` is a role key, or
## "dogman" / "rigger" for climb days.
static func kit(root: Node3D, job: String, on := true) -> void:
	if on and job in ["line", "pump", "boom", "hose", "poker", "screed"]:
		root.set_meta("job", job)
	for nm in CREW_KIT.get(job, []):
		var n := root.find_child(nm, true, false) as Node3D
		if n != null:
			n.visible = on
	# Gumboots go on over the boots
	var gum := root.find_child("Kit_GumbootL", true, false) as Node3D
	for side in ["L", "R"]:
		var boot := root.find_child("Leg%s_Boot" % side, true, false) as Node3D
		if boot != null and gum != null:
			boot.visible = not gum.visible
	# Someone in their own earmuffs doesn't need the hat's
	var own := root.find_child("Look_earmuffs", true, false) as Node3D
	var hat_muffs := root.find_child("Kit_Earmuffs", true, false) as Node3D
	if own != null and hat_muffs != null and own.visible:
		hat_muffs.visible = false

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


## Dresses a chibi as one of the named crew: skin tone, hair colour, plus one
## signature look (moustache, beard, ponytail, bun, sunnies or earmuffs).
static func dress(root: Node3D, ch: Dictionary) -> void:
	_paint(root, {
		"skin": color_mat(Color(ch.get("skin", "f2c9a0")), true),
		"nose": color_mat(Color(ch.get("skin", "f2c9a0")).darkened(0.04), false),
		"hair": color_mat(Color(ch.get("hair", "4a3122")), true),
	})
	var look := String(ch.get("look", ""))
	for n in _crew_parts(root):
		if n.name.begins_with("Look_"):
			n.visible = n.name == "Look_" + look
	# (the job's kit again: the hat's earmuffs give way to their own)
	if root.has_meta("job"):
		kit(root, root.get_meta("job"))

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

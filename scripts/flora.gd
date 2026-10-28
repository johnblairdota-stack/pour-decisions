## Trees and planting round Riverlight, drawn as multimeshes: one per species
## per tile near the site (so the camera skips the tiles behind it), the far
## stand-ins past that. The models are tools/blender/trees.py
## (assets/nature/trees.glb); scripts/surrounds.gd decides where they grow.
extends RefCounted

const LIB := "res://assets/nature/trees.glb"
const FOLIAGE := preload("res://shaders/foliage.gdshader")
const LEAF := preload("res://shaders/foliage_leaf.gdshader")

const NEAR := 520.0      # m from the site: past this a tree's drawn as its far stand-in
const SHADOW := 320.0    # ...and only trees this close cast shadows
const TILE := 160.0      # near trees are batched in tiles this wide

const COLORS := {
	"bark": Color("6f5d4b"), "bark_dark": Color("54473b"), "fig_bark": Color("8d877b"),
	"fig": Color("3f6f38"), "fig_dark": Color("335d2f"),
	"jacaranda": Color("9b83d6"), "jacaranda_leaf": Color("5f8a48"), "jacaranda_fallen": Color("9d80d2"),
	"poinciana": Color("6c9e45"), "poinciana_red": Color("e04a2c"),
	"gum_bark": Color("ddd6c6"), "gum_patch": Color("a8a69a"), "gum_leaf": Color("71895a"),
	"paperbark": Color("e6dcc5"), "paperbark_leaf": Color("5e7d4c"), "tuckeroo": Color("4f7a3c"),
	"sheoak": Color("5f7352"), "palm_trunk": Color("8a7a63"), "palm": Color("5f8f3e"), "palm_dead": Color("a68d5f"),
	"palm_grey": Color("b9b4a8"), "crownshaft": Color("86a650"), "foxtail": Color("5a9440"),
	"pandanus": Color("6b8f48"), "pandanus_fruit": Color("e08a3a"), "mangrove": Color("5b7550"),
	"pneumato": Color("6e6455"), "bottlebrush_leaf": Color("4e6f3e"), "bottlebrush_red": Color("d0342c"),
	"lomandra": Color("7e9c4e"),
}
## Strap leaves and fronds: thin, so drawn from both sides, and they shimmer
const STRAP := ["palm", "palm_dead", "foxtail", "pandanus", "lomandra"]

## Per species: how much it moves in the breeze, and its range of sizes
const SPECIES := {
	"Fig": [0.05, 0.8, 1.25], "Jacaranda": [0.1, 0.8, 1.2], "Poinciana": [0.06, 0.8, 1.2],
	"PoincianaBloom": [0.06, 0.85, 1.15], "Gum": [0.11, 0.8, 1.25], "Paperbark": [0.12, 0.8, 1.2],
	"Tuckeroo": [0.06, 0.75, 1.15], "SheOak": [0.14, 0.8, 1.25], "CabbagePalm": [0.16, 0.75, 1.2],
	"FoxtailPalm": [0.18, 0.8, 1.2], "Pandanus": [0.08, 0.75, 1.2], "Mangrove": [0.05, 0.7, 1.25],
	"Bottlebrush": [0.04, 0.75, 1.2], "Lomandra": [0.0, 0.8, 1.3],
}
## What grows where, by weight
const MIX := {
	"street": {"Tuckeroo": 6, "Poinciana": 1.5, "Jacaranda": 1.5, "FoxtailPalm": 1},
	"park": {"Fig": 1.4, "Poinciana": 2, "PoincianaBloom": 0.5, "Jacaranda": 1.6, "Paperbark": 1.6,
		"CabbagePalm": 1, "Gum": 1, "SheOak": 0.8, "Tuckeroo": 0.6},
	"riverside": {"SheOak": 3, "Pandanus": 2, "Paperbark": 2, "Fig": 1.5, "CabbagePalm": 1.5},
	"golf": {"Gum": 3.5, "Paperbark": 3, "SheOak": 1.5, "Fig": 1, "Poinciana": 1},
	"scrub": {"Paperbark": 4, "Gum": 3, "SheOak": 3},
	"suburb": {"Jacaranda": 2, "Poinciana": 2, "Gum": 2, "Tuckeroo": 1.5, "FoxtailPalm": 1, "Fig": 0.5, "CabbagePalm": 1},
	"bed": {"Lomandra": 3, "Bottlebrush": 1},
}

static var _lib: Node
static var _meshes := {}

## A species from a mix (see MIX).
static func pick(mix: String, rng: RandomNumberGenerator) -> String:
	var m: Dictionary = MIX[mix]
	var tot := 0.0
	for k in m:
		tot += m[k]
	var r := rng.randf() * tot
	for k in m:
		r -= m[k]
		if r <= 0.0:
			return k
	return m.keys()[0]

## One species' mesh, its parts given the foliage material.
static func mesh(sp: String) -> Mesh:
	if _meshes.has(sp):
		return _meshes[sp]
	if _lib == null:
		_lib = (load(LIB) as PackedScene).instantiate()
	var mi := _lib.get_node_or_null(sp) as MeshInstance3D
	if mi == null:
		push_warning("flora: no tree " + sp)
		_meshes[sp] = null
		return null
	var m := mi.mesh
	var base := sp.trim_suffix("Far")
	var sway: float = SPECIES.get(base, [0.0])[0]
	for i in m.get_surface_count():
		var src := m.surface_get_material(i)
		var key := src.resource_name if src != null else ""
		var mat := ShaderMaterial.new()
		mat.shader = LEAF if key in STRAP else FOLIAGE
		mat.set_shader_parameter("albedo", COLORS.get(key, Color.MAGENTA))
		mat.set_shader_parameter("sway", sway)
		mat.set_shader_parameter("flutter", 0.03 if key in STRAP else 0.0)
		m.surface_set_material(i, mat)
	_meshes[sp] = m
	return m

## How tall a species' model stands at scale 1.
static func height(sp: String) -> float:
	var m := mesh(sp)
	return maxf(m.get_aabb().end.y, 0.5) if m != null else 8.0

## Plants `trees` (each [species, Vector3 on the ground], or with a third
## entry, the height it should stand) under `root`.
static func plant(root: Node3D, trees: Array, rng: RandomNumberGenerator) -> void:
	var groups := {}
	for t in trees:
		var sp: String = t[0]
		var at: Vector3 = t[1]
		var d := Vector2(at.x, at.z).length()
		var far := d > NEAR
		if far and sp in ["Lomandra", "Bottlebrush"]:
			continue
		var key: String
		if far:
			key = sp + "Far"
		else:
			key = "%s|%d|%d|%d" % [sp, floori(at.x / TILE), floori(at.z / TILE), 1 if d < SHADOW else 0]
		if not groups.has(key):
			groups[key] = []
		var r: Array = SPECIES.get(sp, [0.0, 1.0, 1.0])
		var s := rng.randf_range(r[1], r[2])
		if t.size() > 2:
			s = clampf(float(t[2]) / height(sp), 0.45, 2.4)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.92, 1.08), s))
		var v := rng.randf_range(0.86, 1.08)
		var w := rng.randf_range(-0.04, 0.04)
		groups[key].append([Transform3D(b, at), Color(v * (1.0 + w), v, v * (1.0 - w))])
	for key in groups:
		var parts: PackedStringArray = (key as String).split("|")
		var sp: String = parts[0] if parts.size() > 1 else key
		var m := mesh(sp)
		if m == null:
			continue
		var list: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = m
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][0])
			mm.set_instance_color(i, list[i][1])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Trees_" + (key as String).replace("|", "_")
		mi.multimesh = mm
		if parts.size() < 4 or parts[3] != "1":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)

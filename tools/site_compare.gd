## Shoots the game's surroundings straight down so they can be laid over the
## real site data (tools/site_compare.py): a colour map, a height map and a
## trees-only height map, 1 m a pixel, north (+z) up, east (-x) right, plus
## every tree the game plants as JSON.
##   godot --rendering-driver opengl3 --resolution 1500x1500 --path . \
##     --script res://tools/site_compare.gd -- --out=/some/dir
## Heights are packed as two base-128 digits in red and green, each offset
## by 64 (the GL3 output crushes values under about 57):
## metres = ((r - 64) * 128 + (g - 64)) / 16383 * SPAN + LOW; black is no data.
extends SceneTree

const SIZE := 1500.0     # metres across, one pixel a metre
const LOW := -10.0
const SPAN := 160.0

var out_dir := "user://site_compare"
var _world: Node3D
var _env: Environment
var _frames := 0
var _passes := ["colour", "height", "trees"]

const HEIGHT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
varying float h;
void vertex() {
	h = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}
void fragment() {
	float u = floor(clamp((h - %f) / %f, 0.0, 1.0) * 16383.0 + 0.5);
	float hi = floor(u / 128.0);
	float lo = u - hi * 128.0;
	ALBEDO = vec3((64.0 + hi) / 255.0, (64.0 + lo) / 255.0, 0.5);
}
"""

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_world = Node3D.new()
	root.add_child(_world)
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color("3d5a6b")
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color("cfe3f2")
	_env.ambient_light_energy = 0.6
	we.environment = _env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-60, 160, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 1500.0
	_world.add_child(sun)
	var s := Node3D.new()
	_world.add_child(s)
	preload("res://scripts/surrounds.gd").build(s)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = SIZE
	cam.near = 1.0
	cam.far = 2000.0
	cam.position = Vector3(0, 800, 0)
	cam.rotation_degrees = Vector3(-90, 180, 0)
	_world.add_child(cam)
	cam.make_current()
	_dump_trees(s)

func _dump_trees(s: Node) -> void:
	var trees := []
	for mi in _all(s):
		if not (mi is MultiMeshInstance3D and String(mi.name).begins_with("Trees_")):
			continue
		var sp: String = String(mi.name).substr(6).split("_")[0].trim_suffix("Far")
		var mm: MultiMesh = mi.multimesh
		var top: float = mm.mesh.get_aabb().end.y
		for i in mm.instance_count:
			var t: Transform3D = mi.global_transform * mm.get_instance_transform(i)
			trees.append([sp, snappedf(t.origin.x, 0.1), snappedf(t.origin.z, 0.1), snappedf(t.basis.y.length() * top, 0.1)])
	var f := FileAccess.open(out_dir.path_join("game_trees.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"trees": trees}))
	print("trees ", trees.size())

func _all(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out

func _process(_delta: float) -> bool:
	_frames += 1
	if _passes.is_empty():
		return true
	if _frames % 12 != 0:
		return false
	var p: String = _passes.pop_front()
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join("game_%s.png" % p))
	print("saved ", p)
	if p == "colour":
		# Everything shows its own height from here on
		var m := ShaderMaterial.new()
		m.shader = Shader.new()
		m.shader.code = HEIGHT_SHADER % [LOW, SPAN]
		for g in _all(_world):
			if g is GeometryInstance3D:
				g.material_override = m
			# (the grass plane under everything has a hole for the river that
			# this shader can't cut, so it's left out: bare verges read no data)
			if g is MeshInstance3D and g.mesh is PlaneMesh:
				g.visible = false
		_env.background_color = Color.BLACK
		_env.ambient_light_energy = 0.0
	elif p == "height":
		for g in _all(_world):
			if g is GeometryInstance3D and not String(g.name).begins_with("Trees_"):
				g.visible = false
	return false

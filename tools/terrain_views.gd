## Pictures of the real ground from round the site, to check the hills and
## what stands on them (scripts/terrain.gd, scripts/surrounds.gd):
##   godot --rendering-driver opengl3 --resolution 1600x900 --path . \
##     --script res://tools/terrain_views.gd -- --out=/some/dir
## (a plain sky and haze, not the game's own look)
extends SceneTree

var out_dir := "user://terrain_views"
var _cam: Camera3D
var _frames := 0
## name, camera (map frame: x west, z north), where it looks
var _views := [
	["west_city", Vector3(0, 45, 0), Vector3(3000, 20, -1500)],
	["north_hills", Vector3(0, 45, 0), Vector3(1500, 15, 2500)],
	["aerial_west", Vector3(-600, 450, -900), Vector3(4000, 0, 0)],
	["aerial_south", Vector3(0, 350, 1200), Vector3(-200, 0, -2500)],
	["zoom_coottha", Vector3(0, 45, 0), Vector3(12778, 150, -5500), 25.0],
	["zoom_gravatt", Vector3(0, 45, 0), Vector3(-1516, 100, -10956), 25.0],
	["hill_morningside", Vector3(-200, 120, -550), Vector3(-600, 10, -1000), 60.0],
	["hill_edge", Vector3(-350, 60, -600), Vector3(-550, 10, -800), 60.0],
	["far_bank", Vector3(2500, 80, -600), Vector3(3500, 0, -2500), 60.0],
]

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var world := Node3D.new()
	root.add_child(world)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.fog_enabled = true
	env.fog_light_color = Color("b8c8d6")
	env.fog_density = 0.00008
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 150, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	world.add_child(sun)
	var s := Node3D.new()
	world.add_child(s)
	var t0 := Time.get_ticks_msec()
	preload("res://scripts/surrounds.gd").build(s)
	print("build ms ", Time.get_ticks_msec() - t0)
	_cam = Camera3D.new()
	_cam.near = 0.5
	_cam.far = 16000.0
	_cam.fov = 60.0
	world.add_child(_cam)
	_cam.make_current()
	_next()

func _next() -> void:
	var v: Array = _views[0]
	_cam.position = v[1]
	_cam.look_at(v[2])
	_cam.fov = v[3] if v.size() > 3 else 60.0

func _process(_delta: float) -> bool:
	_frames += 1
	if _views.is_empty():
		return true
	if _frames % 10 != 0:
		return false
	var v: Array = _views.pop_front()
	root.get_texture().get_image().save_png(out_dir.path_join("%s.png" % v[0]))
	print("saved ", v[0])
	if not _views.is_empty():
		_next()
	return false

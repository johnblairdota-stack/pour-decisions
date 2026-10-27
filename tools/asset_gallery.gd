## Lines up the modelled assets in the game's own toon look and saves a
## screenshot, to check a Blender batch in Godot before it goes in a PR.
##   godot --path . --script res://tools/asset_gallery.gd -- --out=/some/dir [--set=crew]
## Cloud (software GL) renders come out washed out; judge colour on a PC.
extends SceneTree

const F := preload("res://scripts/factory.gd")
const Roster := preload("res://scripts/roster.gd")
const UI := preload("res://scripts/ui.gd")

var out_dir := "user://gallery"
var which := "crew"
var _frames := 0
var _cam: Camera3D
var _shots: Array = []   # [name, camera position, look at]

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--set="):
			which = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("cfe3f2")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("cfe3f2")
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := F.box(Vector3(40, 0.1, 40), F.mat("concrete"), Vector3(0, -0.05, 0))
	world.add_child(ground)
	_cam = Camera3D.new()
	_cam.fov = 22
	world.add_child(_cam)
	match which:
		"crew":
			_crew(world)

func _crew(world: Node3D) -> void:
	# Every named crew member, each in a job's kit, with the job's hat
	var jobs := ["boom", "line", "pump", "hose", "poker", "screed", "dogman", "rigger"]
	var hats := {"dogman": Color("f4f7fa"), "rigger": Color("f4f7fa")}
	var i := 0
	for ch in Roster.CHARACTERS:
		var job: String = jobs[i]
		var hat: Color = hats.get(job, UI.ROLE.get(job, Color("ffc72c")))
		var m := F.chibi(Color("ff7a1a"), hat)
		F.dress(m, ch)
		F.kit(m, job)
		m.position = Vector3((i - 3.5) * 1.35, 0, 0)
		m.rotation.y = 0.25
		world.add_child(m)
		var l := F.label3d("%s\n%s" % [ch["name"], job], 20, Color.WHITE)
		l.position = m.position + Vector3(0, 2.3, 0)
		world.add_child(l)
		i += 1
	_shots = [
		["crew_front", Vector3(0, 2.0, 21.0), Vector3(0, 0.95, 0)],
		["crew_back", Vector3(0, 2.4, -21.0), Vector3(0, 0.95, 0)],
		["crew_game_cam", Vector3(0, 11.0, 10.0), Vector3(0, 0.6, 0)],
		["crew_close_left", Vector3(-3.4, 1.7, 5.0), Vector3(-3.4, 1.0, 0)],
		["crew_close_right", Vector3(3.4, 1.7, 5.0), Vector3(3.4, 1.0, 0)],
	]

func _process(_delta: float) -> bool:
	_frames += 1
	if _shots.is_empty():
		return true
	var s: Array = _shots[0]
	if _frames % 8 == 1:
		_cam.position = s[1]
		_cam.look_at(s[2])
	elif _frames % 8 == 0:
		var img := root.get_texture().get_image()
		var path: String = out_dir.path_join("%s.png" % s[0])
		img.save_png(path)
		print("saved ", path)
		_shots.pop_front()
	return false

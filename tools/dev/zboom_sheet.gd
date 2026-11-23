## Dev: a side-on sheet of the Z-fold boom's poses.  godot --path . -s tools/dev/zboom_sheet.gd -- OUTDIR
extends SceneTree

const ZBoom := preload("res://scripts/zboom.gd")
const F := preload("res://scripts/factory.gd")

func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	var world := Node3D.new()
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0)
	world.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("9fc3e6")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	world.add_child(env)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	world.add_child(cam)
	# (a stub of column and the deck 9 m under the pivot)
	world.add_child(F.box(Vector3(1, 14, 1), F.color_mat(Color("e8e2cf")), Vector3(0, -7, 0)))
	world.add_child(F.box(Vector3(80, 0.3, 30), F.color_mat(Color("c9ccc8")), Vector3(10, -9.2, 0)))
	var z := ZBoom.new()
	world.add_child(z)
	z.build(1.7, 3.0)
	var shots := [["far", 33.0, -8.0, 0.0], ["mid", 20.0, -8.0, 0.0], ["near", 7.0, -8.0, 0.0], ["carry", 20.0, -8.0, 0.22],
		["fold4", 20.0, -8.0, 0.415], ["fold3", 20.0, -8.0, 0.61], ["fold2", 20.0, -8.0, 0.805], ["stowed", 20.0, -8.0, 1.0]]
	for s in shots:
		z.pose(s[1], s[2], s[3])
		cam.size = 34.0
		cam.position = Vector3(14, 2.0, 40)
		if String(s[0]) == "stowed":
			cam.size = 9.0
			cam.position = Vector3(4.5, 1.5, 12)
			cam.rotation = Vector3(-0.12, 0.25, 0)
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("%s/zboom_%s.png" % [out, s[0]])
		print("shot ", s[0], " ", z.ang)
	quit()

## Dev: a close look at Spire's column form, cage and column.  godot --path . -s tools/dev/column_form_sheet.gd -- OUTDIR
extends SceneTree

const Cycle := preload("res://scripts/spire_floor_cycle.gd")
const F := preload("res://scripts/factory.gd")

func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp"
	var world := Node3D.new()
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("9fc3e6")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var cam := Camera3D.new()
	world.add_child(cam)
	world.add_child(F.box(Vector3(30, 0.3, 30), F.color_mat(Color("a9abaa")), Vector3(0, -0.15, 0)))
	var cy = Cycle.new()
	world.add_child(cy)
	var form: Node3D = cy._form(Cycle.COL_L, Cycle.COL_T, 2.48)
	world.add_child(form)
	var views := [["front", Vector3(3.0, 2.6, 4.2)], ["back", Vector3(-2.8, 2.6, -3.4)], ["top", Vector3(1.2, 5.0, 2.0)]]
	for v in views:
		cam.look_at_from_position(v[1], Vector3(0, 1.2, 0))
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("%s/form_%s.png" % [out, v[0]])
	quit()

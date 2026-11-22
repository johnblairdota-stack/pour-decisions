extends Node3D
## A test flight along a river corridor (tools/blender/spire/corridor.py), on its own: not part of the game.
##
##     godot --path . res://scenes/corridor_view.tscn -- [--corridor=south_brisbane] [--tower=william1] [--loop]
##
## Loads assets/corridors/<id>.glb and data/corridors/<id>.json, lays the river and the far-city panorama
## round it, and flies the json's (provisional) camera path low over the water towards the tower, with the
## frame time on screen. It is here to answer one thing before a real flight is built on it: what the
## corridor looks like and costs on the PC and the tablet.
##
## This places no equipment. Equipment, line routes and climb methods come from the mast climb thread / John.

const RIVER_AHD := 0.3
const SPEED := 22.0          # m/s along the path
const LOOK_AHEAD := 260.0    # m
const TOWER_PULL := 0.45     # how far the look point leans to the tower
const PANO_R := 4200.0       # m: the panorama's ring (12 above to 30 below level, as it was rendered)

var id := "south_brisbane"
var tower := ""
var loop := false
var data := {}
var pts: Array[Vector3] = []
var lens: Array[float] = []
var total := 0.0
var dist := 0.0
var cam: Camera3D
var label: Label
var slow := 0.0
var worst := 0.0
var frames := 0
var spent := 0.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--corridor="):
			id = a.get_slice("=", 1)
		elif a.begins_with("--tower="):
			tower = a.get_slice("=", 1)
		elif a == "--loop":
			loop = true
	var jp := "res://data/corridors/%s.json" % id
	if not FileAccess.file_exists(jp):
		push_error("corridor_view: no %s" % jp)
		get_tree().quit(1)
		return
	data = JSON.parse_string(FileAccess.get_file_as_string(jp))
	if tower == "" or not data["towers"].has(tower):
		tower = data["towers"].keys()[0]
	_sky()
	_model()
	_river()
	_pano()
	_path()
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.5
	cam.far = 9000.0
	add_child(cam)
	cam.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	layer.add_child(label)
	_place()

## Blender's frame (x east, y north, z up) to the engine's (the glb is exported y-up: x, z, -y).
static func g(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, z, -y)

func _sky() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.3, 0.5, 0.8)
	sm.sky_horizon_color = Color(0.74, 0.82, 0.9)
	sm.ground_horizon_color = Color(0.74, 0.82, 0.9)
	sm.ground_bottom_color = Color(0.3, 0.3, 0.27)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.82)
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED     # (the sky's glare washed every colour out)
	env.fog_enabled = true
	env.fog_light_color = Color(0.76, 0.82, 0.88)
	env.fog_density = 0.00022
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34.0, -125.0, 0.0)
	sun.light_energy = 1.7
	sun.shadow_enabled = false           # (a corridor is seen from far off: no shadows, as the plan has it)
	add_child(sun)

func _model() -> void:
	var scene = load(data["glb"])
	if not scene is PackedScene:
		push_error("corridor_view: %s did not load" % data["glb"])
		return
	var m: Node3D = scene.instantiate()
	m.name = "Corridor"
	add_child(m)
	var tris := 0
	var draws := 0
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draws += mi.mesh.get_surface_count()
		# (the glb carries no normals, as the game's other city models: flat ones are worked out here, smooth for the crowns)
		var lit := ArrayMesh.new()
		var smooth := String(mi.name).begins_with("cor_trees")
		for s in mi.mesh.get_surface_count():
			var st := SurfaceTool.new()
			st.create_from(mi.mesh, s)
			if not smooth:
				st.deindex()
			st.generate_normals(smooth)      # (the crown lumps are wound the other way)
			st.commit(lit)
			lit.surface_set_material(s, mi.mesh.surface_get_material(s))
		mi.mesh = lit
		for s in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_array_len(s) / 3 if not smooth else mi.mesh.surface_get_array_index_len(s) / 3
			var mat := mi.mesh.surface_get_material(s)
			if mat is BaseMaterial3D:
				(mat as BaseMaterial3D).metallic = 0.0
				(mat as BaseMaterial3D).roughness = 0.85
				(mat as BaseMaterial3D).metallic_specular = 0.0
				if String(mi.name).begins_with("cor_shared") or String(mi.name).begins_with("cor_ground") \
						or String(mi.name).begins_with("cor_trees") or String(mi.name).begins_with("tower_"):
					(mat as BaseMaterial3D).vertex_color_use_as_albedo = true
					(mat as BaseMaterial3D).vertex_color_is_srgb = false     # (the exporter has already taken them to linear)
	print("corridor_view: %s, %d triangles in %d surfaces" % [id, tris, draws])

func _river() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12000, 12000)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.33, 0.24)
	mat.roughness = 0.18
	mat.metallic = 0.25
	mi.material_override = mat
	mi.position = Vector3(0, RIVER_AHD, 0)
	add_child(mi)

## The far city: the strip panorama from the tower's top, on a ring round it (see-through sky).
func _pano() -> void:
	var p := "res://assets/corridors/%s_pano_%s.png" % [id, tower]
	if not ResourceLoader.exists(p):
		return
	var t: Dictionary = data["towers"][tower]
	var eye := g(t["at"][0], t["at"][1], float(t["top_ahd"]) + 6.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 72
	var top := PANO_R * tan(deg_to_rad(12.0))
	var bot := -PANO_R * tan(deg_to_rad(30.0))
	for i in n:
		var quad := []
		for k in [0, 1]:
			var u := float(i + k) / n
			var lon := (u - 0.5) * TAU                       # (the strip's middle is north, east to its right)
			var d := Vector3(sin(lon), 0.0, -cos(lon)) * PANO_R
			quad.append([eye + d + Vector3(0, top, 0), Vector2(u, 0.0)])
			quad.append([eye + d + Vector3(0, bot, 0), Vector2(u, 1.0)])
		for j in [0, 1, 2, 2, 1, 3]:
			st.set_uv(quad[j][1])
			st.add_vertex(quad[j][0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(p)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _path() -> void:
	for p in data["path_provisional"]:
		pts.append(g(p[0], p[1], p[2]))
	lens = [0.0]
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
		lens.append(total)

func _at(d: float) -> Vector3:
	d = clampf(d, 0.0, total)
	var i := 1
	while i < pts.size() - 1 and lens[i] < d:
		i += 1
	var f := (d - lens[i - 1]) / maxf(0.001, lens[i] - lens[i - 1])
	var a := pts[maxi(i - 2, 0)]
	var b := pts[i - 1]
	var c := pts[i]
	var e := pts[mini(i + 1, pts.size() - 1)]
	return 0.5 * ((2.0 * b) + (c - a) * f + (2.0 * a - 5.0 * b + 4.0 * c - e) * f * f + (3.0 * b - a - 3.0 * c + e) * f * f * f)

func _place() -> void:
	var t: Dictionary = data["towers"][tower]
	var at := g(t["at"][0], t["at"][1], 45.0)
	var pos := _at(dist)
	var ahead := _at(dist + LOOK_AHEAD)
	if dist + LOOK_AHEAD > total:
		ahead = pos + (_at(total) - _at(total - 40.0)).normalized() * LOOK_AHEAD
	ahead.y = 30.0
	cam.position = pos
	cam.look_at(ahead.lerp(at, TOWER_PULL), Vector3.UP)

func _process(delta: float) -> void:
	if cam == null:
		return
	dist += SPEED * delta
	if dist >= total:
		if loop:
			dist = 0.0
		else:
			print("corridor_view: flown %.0f m, %d frames, mean %.1f ms, worst %.1f ms" % [total, frames, spent / maxf(1, frames) * 1000.0, worst * 1000.0])
			get_tree().quit()
			return
	_place()
	if frames > 5:
		worst = maxf(worst, delta)
	frames += 1
	spent += delta
	slow = lerpf(slow, delta, 0.1)
	label.text = "%s to %s   %d fps   %.1f ms   %d draws   %d m of %d" % [data["name"], data["towers"][tower]["name"],
			int(round(Engine.get_frames_per_second())), slow * 1000.0,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(dist), int(total)]

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
		"props":
			_props(world)
		"plant":
			_plant(world)
		"towers":
			_towers(world)
		"site":
			_site(world)
		"trees":
			_trees(world)
		"street":
			_street(world)
		"water":
			_water(world)
		"river":
			_river(world)
		"buildings":
			_buildings(world)
		"estate":
			_estate(world)

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

func _props(world: Node3D) -> void:
	# Every prop in a grid, labelled
	var rows := [
		["ScreedBoard", "ScreedHandle", "PokerSkid", "PokerMotor", "PokerHead", "ClampHalfA", "ClampHalfB"],
		["Pipe3m", "SparesBin", "PipeRack", "Wheelbarrow", "BullFloat"],
		["SlumpPlate", "SlumpTray", "SlumpTrayMix", "SlumpScoop", "Shovel", "ConcreteRake", "MagFloat", "Bucket"],
		["ChainSling", "TagLineCoil", "Shackle"],
	]
	var widths := {"Pipe3m": 3.4, "PipeRack": 3.0, "BullFloat": 2.2, "Wheelbarrow": 2.0, "SparesBin": 1.5}
	var z := -3.0
	for row in rows:
		var x := 0.0
		var placed: Array = []
		for nm in row:
			var w: float = widths.get(nm, 1.0)
			var n := F.prop(nm)
			if nm == "ScreedBoard":
				n.scale.x = 0.9
			n.position = Vector3(x + w * 0.5, 0, z)
			world.add_child(n)
			var l := F.label3d(nm, 16, Color.WHITE)
			l.position = n.position + Vector3(0, 1.0 if nm != "Shovel" and nm != "PipeRack" else 1.55, 0.3)
			world.add_child(l)
			placed.append(n)
			placed.append(l)
			x += w + 0.3
		for n in placed:
			n.position.x -= x * 0.5
		z += 2.2
	_shots = [
		["props_all", Vector3(0, 12.0, 11.0), Vector3(0, 0.0, 0.0)],
		["props_tools", Vector3(-1.5, 2.4, -0.2), Vector3(-1.5, 0.3, -3.0)],
		["props_slump", Vector3(0, 2.4, 3.5), Vector3(0, 0.3, 1.4)],
		["props_stores", Vector3(0, 2.6, 1.8), Vector3(0, 0.4, -0.8)],
		["props_rigging", Vector3(0, 2.2, 6.6), Vector3(0, 0.1, 3.6)],
	]

func _plant(world: Node3D) -> void:
	const PLANT := "res://assets/plant/plant.glb"
	# The agitator as line.gd puts it together, and the pump with its hopper
	var t := Node3D.new()
	t.add_child(F.prop("Truck", {}, PLANT))
	var drum := Node3D.new()
	drum.position = Vector3(-0.6, 2.4, 0)
	drum.rotation.z = -0.2
	drum.add_child(F.prop("TruckDrum", {}, PLANT))
	t.add_child(drum)
	var ext := F.prop("ChuteExt", {}, PLANT)
	ext.position = Vector3(-4.55, 1.62, 0)
	t.add_child(ext)
	t.position = Vector3(-1.0, 0, 3.0)
	world.add_child(t)
	var pump := F.prop("LinePump", {}, PLANT)
	pump.position = Vector3(-1.0, 0, -3.0)
	world.add_child(pump)
	var hop := F.prop("PumpHopper", {}, PLANT)
	hop.position = Vector3(2.3, 0, -3.0)
	world.add_child(hop)
	_shots = [
		["plant_front", Vector3(9.0, 4.5, 12.0), Vector3(0, 1.5, 0)],
		["plant_back", Vector3(-11.0, 5.0, 10.0), Vector3(0, 1.5, 0)],
		["plant_top", Vector3(4.0, 16.0, 12.0), Vector3(0, 0.5, 0)],
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

func _towers(world: Node3D) -> void:
	# Two boom tower sections with the collar, turret and a short boom on top;
	# the hoist cage on three mast sections; the crane's head, trolley, hook
	for i in 2:
		var s := F.lattice_section(4.14, 2.0)
		s.position = Vector3(0, i * 4.14, 0)
		world.add_child(s)
	var head := Node3D.new()
	head.position.y = 8.28
	world.add_child(head)
	head.add_child(F.prop("BoomCollar", {}, F.TOWERS))
	var yaw := Node3D.new()
	yaw.rotation.y = -0.6
	head.add_child(yaw)
	yaw.add_child(F.prop("BoomTurret", {}, F.TOWERS))
	var arm1 := Node3D.new()
	arm1.position.y = 1.7
	arm1.rotation.z = 0.5
	yaw.add_child(arm1)
	var a1 := F.prop("BoomArm1", {}, F.TOWERS)
	a1.scale.x = 0.4
	arm1.add_child(a1)
	var arm2 := Node3D.new()
	arm2.position.x = 8.0
	arm2.rotation.z = -1.3
	arm1.add_child(arm2)
	var a2 := F.prop("BoomArm2", {}, F.TOWERS)
	a2.scale.x = 0.4
	arm2.add_child(a2)
	var tip := F.prop("BoomTip", {}, F.TOWERS)
	tip.position.x = 8.0
	tip.rotation.z = 0.8
	arm2.add_child(tip)
	for i in 3:
		var hs := F.prop("HoistMastSection", {}, F.TOWERS)
		hs.position = Vector3(-6.25, i * 1.5, 0)
		world.add_child(hs)
	var cage := F.prop("HoistCage", {}, F.TOWERS)
	cage.position = Vector3(-5.0, 0, 0)
	world.add_child(cage)
	var slew := F.prop("CraneSlew", {}, F.TOWERS)
	slew.position = Vector3(0, 0, -30)
	world.add_child(slew)
	var trolley := F.prop("CraneTrolley", {}, F.TOWERS)
	trolley.position = Vector3(10, 0, -30)
	world.add_child(trolley)
	var hook := F.prop("CraneHook", {}, F.TOWERS)
	hook.position = Vector3(10, -4, -30)
	world.add_child(hook)
	_shots = [
		["towers_boom", Vector3(10.0, 12.0, 14.0), Vector3(1.0, 8.0, 0)],
		["towers_hoist", Vector3(-1.0, 3.5, 7.0), Vector3(-5.5, 1.6, 0)],
		["towers_crane", Vector3(14.0, 6.0, -12.0), Vector3(-2.0, 0.0, -30)],
		["towers_crane_far", Vector3(30.0, 18.0, 0.0), Vector3(14.0, 0.0, -30)],
	]

func _site(world: Node3D) -> void:
	# The yard as the game lays it out (scripts/yard.gd), on a big ground
	world.add_child(F.box(Vector3(160, 0.1, 80), F.mat("grass"), Vector3(10, -0.06, -5)))
	var y := Node3D.new()
	world.add_child(y)
	preload("res://scripts/yard.gd").build(y)
	_shots = [
		["site_sheds", Vector3(-8.0, 9.0, -6.0), Vector3(-17.0, 2.0, 6.0)],
		["site_crib", Vector3(-12.0, 4.0, -2.0), Vector3(-17.0, 1.0, 5.0)],
		["site_gate", Vector3(36.0, 6.0, 24.0), Vector3(36.0, 1.0, 11.0)],
		["site_west", Vector3(36.0, 7.0, 0.0), Vector3(44.5, 0.8, 7.0)],
		["site_laydown", Vector3(-6.0, 7.0, -32.0), Vector3(-6.0, 0.5, -22.0)],
		["site_wide", Vector3(10.0, 45.0, 45.0), Vector3(10.0, 0.0, 4.0)],
	]

func _trees(world: Node3D) -> void:
	# Every species in a row on grass, near and far versions (scripts/flora.gd)
	world.add_child(F.box(Vector3(260, 0.1, 120), F.mat("grass"), Vector3(0, -0.04, -15)))
	var Flora := preload("res://scripts/flora.gd")
	var big := ["Fig", "Jacaranda", "Poinciana", "PoincianaBloom", "Gum", "Paperbark", "Tuckeroo"]
	var small := ["SheOak", "CabbagePalm", "FoxtailPalm", "Pandanus", "Mangrove", "Bottlebrush", "Lomandra"]
	var widths := {"Fig": 21.0, "Jacaranda": 11.0, "Poinciana": 14.0, "PoincianaBloom": 14.0, "Gum": 9.0,
		"Paperbark": 6.0, "Tuckeroo": 7.0, "SheOak": 6.0, "CabbagePalm": 6.0, "FoxtailPalm": 7.0,
		"Pandanus": 5.0, "Mangrove": 7.0, "Bottlebrush": 3.0, "Lomandra": 2.5}
	for row in [[big, -60.0], [small, 60.0]]:
		var x := 0.0
		var names: Array = row[0]
		var tot := 0.0
		for n in names:
			tot += widths[n]
		x = row[1] - tot * 0.5
		for n in names:
			x += widths[n] * 0.5
			for far in [false, true]:
				var m: Mesh = Flora.mesh(n + ("Far" if far else ""))
				if m == null:
					continue
				var mi := MeshInstance3D.new()
				mi.mesh = m
				mi.position = Vector3(x, 0, -35.0 if far else 0.0)
				world.add_child(mi)
			x += widths[n] * 0.5
	_shots = [
		["trees_big", Vector3(-60, 9.0, 85.0), Vector3(-60, 7.0, 0.0)],
		["trees_small", Vector3(60, 6.0, 52.0), Vector3(60, 4.0, 0.0)],
		["trees_far", Vector3(0, 16.0, -240.0), Vector3(0, 6.0, -35.0)],
		["trees_close", Vector3(-82, 5.0, 26.0), Vector3(-75, 6.0, 0.0)],
	]

func _street(world: Node3D) -> void:
	# Each piece of street furniture in a row (scripts/street.gd)
	world.add_child(F.box(Vector3(80, 0.1, 40), F.mat("grass"), Vector3(0, -0.04, 0)))
	var Street := preload("res://scripts/street.gd")
	var names := ["StreetLight", "ParkLight", "BusShelter", "BusStopSign", "ParkBench", "ParkBin", "Bubbler",
		"PicnicTable", "BBQShelter", "StreetSign", "GiveWaySign", "TimberBollard", "BikeHoop", "RiverwalkRail"]
	var widths := [3.0, 1.5, 5.0, 1.5, 2.5, 1.5, 1.2, 3.0, 7.0, 2.0, 1.5, 1.0, 1.5, 3.5]
	var tot := 0.0
	for w in widths:
		tot += w
	var x := -tot * 0.5
	for i in names.size():
		x += widths[i] * 0.5
		var mi := MeshInstance3D.new()
		mi.mesh = Street.mesh(names[i])
		mi.position = Vector3(x, 0, 0)
		world.add_child(mi)
		if names[i] == "StreetSign":
			Street.letter(world, mi.transform, "MacArthur Av")
		x += widths[i] * 0.5
	_shots = [
		["street_all", Vector3(0, 7.0, 42.0), Vector3(0, 2.2, 0.0)],
		["street_left", Vector3(-12, 3.5, 14.0), Vector3(-12, 2.0, 0.0)],
		["street_right", Vector3(10, 3.5, 13.0), Vector3(10, 1.4, 0.0)],
	]

func _water(world: Node3D) -> void:
	# The boats and bits for the river in a row (scripts/water.gd)
	world.add_child(F.box(Vector3(120, 0.1, 60), F.color_mat(Color("4f6660")), Vector3(0, -0.06, 0)))
	var W := preload("res://scripts/water.gd")
	var row := [["Tinny", 6.0], ["Yacht", 12.0], ["Cruiser", 13.0], ["RowingEight", 20.0], ["PileGreen", 3.0],
		["PileRed", 3.0], ["MooringBuoy", 2.0], ["Pontoon", 14.0], ["Rock0", 2.0], ["Rock1", 2.0], ["Rock2", 2.0]]
	var x := -45.0
	for r in row:
		x += r[1] * 0.5
		var n: MeshInstance3D = W.node(r[0])
		n.position = Vector3(x, 0, 0)
		world.add_child(n)
		x += r[1] * 0.5
	var ship: MeshInstance3D = W.node("CruiseShip")
	ship.position = Vector3(0, 0, -150)
	world.add_child(ship)
	_shots = [
		["water_boats", Vector3(-22, 12.0, 48.0), Vector3(-22, 2.0, 0.0)],
		["water_bits", Vector3(25, 6.0, 22.0), Vector3(25, 1.5, 0.0)],
		["water_ship", Vector3(-180, 60.0, 120.0), Vector3(0, 15.0, -150.0)],
	]

func _river(world: Node3D) -> void:
	# The real river round the site (scripts/surrounds.gd + water.gd), looked
	# at from a few spots on the water
	var s := Node3D.new()
	world.add_child(s)
	preload("res://scripts/surrounds.gd").build(s)
	var ship: Node3D = s.find_child("CruiseShip", true, false)
	var yacht: Node3D = s.find_child("Yacht", true, false)
	var pont: Node3D = s.find_child("Pontoon", true, false)
	_shots = [["river_bank", Vector3(60, 25.0, -260.0), Vector3(20, 0.0, -190.0)]]
	if ship != null:
		_shots.append(["river_ship", ship.position + Vector3(-200, 80, -250), ship.position + Vector3(0, 20, 0)])
	if yacht != null:
		_shots.append(["river_moorings", yacht.position + Vector3(-40, 14, -40), yacht.position])
	if pont != null:
		_shots.append(["river_pontoon", pont.position + Vector3(-25, 10, -25), pont.position])
	_cam.fov = 50
	_cam.far = 8000

func _buildings(world: Node3D) -> void:
	# The houses, roof kit and containers in a row (scripts/neighbours.gd)
	world.add_child(F.box(Vector3(140, 0.1, 60), F.color_mat(Color("78a457")), Vector3(0, -0.06, 0)))
	var N := preload("res://scripts/neighbours.gd")
	var row := [["ModernHouse", 14.0], ["ModernHouseB", 14.0], ["Queenslander", 13.0], ["PostwarHouse", 16.0],
		["RoofAC", 5.0], ["LiftOverrun", 5.0], ["SolarArray", 7.0], ["Whirlybird", 2.0], ["Container20", 8.0],
		["Container40", 14.0]]
	var items: Array = []
	var x := -55.0
	for r in row:
		x += r[1] * 0.5
		var c := Color("2f5f8f") if (r[0] as String).begins_with("Container") else Color.WHITE
		items.append([r[0], Transform3D(Basis(), Vector3(x, 0, 0)), c])
		x += r[1] * 0.5
	var far := [["Queenslander", Color("efe6cf"), Color("8a9096")], ["Postwar", Color("a5644a"), Color("b0583e")],
		["Modern", Color("f2f0ea"), Color("d8d8d2")]]
	for i in far.size():
		var t := Transform3D(Basis(), Vector3(-30 + i * 16, 0, -25))
		items.append([far[i][0] + "FarBody", t, far[i][1]])
		items.append([far[i][0] + "FarRoof", t, far[i][2]])
	N.place(world, items)
	_shots = [
		["bldg_houses", Vector3(-30, 14.0, 40.0), Vector3(-30, 3.0, 0.0)],
		["bldg_kit", Vector3(22, 9.0, 22.0), Vector3(22, 1.0, 0.0)],
		["bldg_far", Vector3(-14, 30.0, 25.0), Vector3(-14, 2.0, -25.0)],
	]
	_cam.fov = 40

func _estate(world: Node3D) -> void:
	# The estate next door, the sheds and Eat Street's containers in the game
	# (scripts/surrounds.gd + neighbours.gd)
	var s := Node3D.new()
	world.add_child(s)
	preload("res://scripts/surrounds.gd").build(s)
	_shots = [
		["estate_from_site", Vector3(10, 40.0, -20.0), Vector3(-90, 8.0, 40.0)],
		["estate_river", Vector3(-150, 30.0, -260.0), Vector3(-170, 8.0, -90.0)],
		["estate_houses", Vector3(110, 25.0, 140.0), Vector3(60, 4.0, 180.0)],
		["estate_roofs", Vector3(-60, 90.0, -40.0), Vector3(-120, 10.0, 20.0)],
		["sheds", Vector3(140, 30.0, 380.0), Vector3(80, 4.0, 470.0)],
		["eat_street", Vector3(360, 25.0, -110.0), Vector3(415, 1.0, -165.0)],
		["haze", Vector3(0, 60.0, 900.0), Vector3(0, 0.0, 1800.0)],
	]
	_cam.fov = 50
	_cam.far = 8000

## Handover: once the top-out fly-past is over and the camera's back on the
## whole of Riverlight, the site packs up the way a time-lapse shows it.
## The trucks and the pump go, the sheds and the fences, then the hoist, the
## boom tower and the tower crane come down a section at a time from the top,
## each with a puff of dust. The hardstand turns to lawn and the finished
## forecourt grows in: the salvaged wharf poles, the lap pool, the trees,
## and the RIVERLIGHT wall with its pergola on the Angora Road driveway.
## Any A skips to the end. Then the top-out card comes up.
extends Node3D

signal finished

const F := preload("res://scripts/factory.gd")
const Flora := preload("res://scripts/flora.gd")

const STRIP_END := 5.6       # s: the last of the site kit's gone
const GROW_AT := 5.2         # s: the garden starts coming up
const T_END := 9.0           # s: the card comes up
const POP := 0.55            # s each piece of garden takes to grow in

var game
var active := false
var t := 0.0
var garden: Node3D
var _jobs: Array = []        # [at s, Callable], run in order
var _grow: Array = []        # [node, at s, full scale]
var _rng := RandomNumberGenerator.new()

func start(g) -> void:
	game = g
	active = true
	t = 0.0
	_rng.seed = 2018
	_plan_strip()
	_plan_garden()
	_jobs.sort_custom(func(a, b): return a[0] < b[0])
	game.hud.toast("Handover: the site packs up. Press A to skip", 3.0)

## Runs the time-lapse on. Returns true once it's over.
func tick(delta: float) -> bool:
	if not active:
		return true
	t += delta
	while not _jobs.is_empty() and float(_jobs[0][0]) <= t:
		(_jobs.pop_front()[1] as Callable).call()
	for gr in _grow:
		var u := clampf((t - float(gr[1])) / POP, 0.0, 1.0)
		(gr[0] as Node3D).visible = u > 0.0
		(gr[0] as Node3D).scale = gr[2] * maxf(0.001, _back(u))
	if t >= T_END:
		_finish()
		return true
	return false

## Straight to the finished site.
func skip() -> void:
	if not active:
		return
	t = T_END
	for j in _jobs:
		(j[1] as Callable).call()
	_jobs.clear()
	tick(0.0)

func _finish() -> void:
	active = false
	game.hud.toast("Riverlight · handed over 2018", 3.0)
	finished.emit()

# ------------------------------------------------------------------ packing up

func _at(s: float, c: Callable) -> void:
	_jobs.append([s, c])

func _plan_strip() -> void:
	# The street first: trucks, the pump, the bin, the gear on the ground
	_at(0.3, func():
		_gone(game.line, Vector3(24.0, 0.5, 6.0), true)
		_gone(game.ops, Vector3(19.0, 0.5, 6.5), false)
		# (the settling tank and its hoses sit on the site itself)
		for key in ["tank", "tank_label", "hose", "steam", "water_fx"]:
			var n = game.ops.get(key)
			if n is Node3D:
				_gone(n, n.global_position, key == "tank")
		_gone(game.ground_st, Vector3.ZERO, false)
		for key in game.stations:
			(game.stations[key]["node"] as Node3D).visible = false
		game.sfx.hit("thunk"))
	# The scaffold and rails round the roof
	_at(0.7, func(): _gone(game.rig, game.rig.global_position + Vector3(-7.0, 0.5, -9.0), true))
	# The sheds, fences, skips and laydown, from the building outwards
	var bits: Array = []
	for c in game.yard.get_children():
		if c is Node3D:
			bits.append(c)
	var mid := Vector3(-4.0, 0, -6.0)
	bits.sort_custom(func(a, b): return (a as Node3D).global_position.distance_to(mid) < (b as Node3D).global_position.distance_to(mid))
	for i in bits.size():
		var n: Node3D = bits[i]
		_at(1.0 + 2.0 * i / maxf(1.0, bits.size() - 1.0), func(): _gone(n, n.global_position + Vector3(0, 0.6, 0), i % 3 == 0))
	_at(1.2, func():
		for h in game._hardstand:
			(h as Node3D).visible = false
		game.podium.material_override = F.color_mat(Color("cfc8b8")))
	# The hoist, the boom tower and the crane, a section at a time off the top
	_at(2.4, func(): _gone(game.hoist_cage, game.hoist_cage.global_position + Vector3(0, 1.5, 0), true))
	_mast(game.hoist_mast, 2.5, 3.9)
	_at(2.9, func(): _gone(game.head, game.head.global_position, true))
	_mast(game.lattice, 3.0, 4.7)
	if game.climb != null and game.climb.crane != null:
		var cl = game.climb
		_at(3.4, func():
			for n in [cl.crane_slew, cl.cable, cl.hook]:
				if n != null:
					_gone(n, cl.crane_slew.global_position, n == cl.crane_slew)
			for s in cl.slings:
				s.visible = false)
		_mast(cl.crane, 3.6, STRIP_END - 0.2)
		_at(STRIP_END, func(): cl.visible = false)
	_at(STRIP_END, func():
		game.stream.visible = false
		for n in game.npcs:
			n.visible = false
		game.engineer.visible = false
		game.defect.visible = false)

## Takes a mast down a section at a time, top first.
func _mast(mast: Node3D, from: float, to: float) -> void:
	if mast == null or not mast.visible:
		return
	var secs: Array = []
	for c in mast.get_children():
		if c is Node3D and c.visible:
			secs.append(c)
	secs.sort_custom(func(a, b): return (a as Node3D).global_position.y > (b as Node3D).global_position.y)
	for i in secs.size():
		var s: Node3D = secs[i]
		_at(lerpf(from, to, float(i) / maxf(1.0, secs.size() - 1.0)), func():
			_gone(s, s.global_position + Vector3(0, 1.0, 0), i % 2 == 0)
			if i % 3 == 0:
				game.sfx.hit("clank"))
	_at(to + 0.05, func(): mast.visible = false)

func _gone(n, at: Vector3, puff: bool) -> void:
	if n == null or not is_instance_valid(n):
		return
	(n as Node3D).visible = false
	if puff and at != Vector3.ZERO:
		_dust(at)

## A little puff of site dust where something was.
func _dust(at: Vector3) -> void:
	var d := CPUParticles3D.new()
	d.one_shot = true
	d.emitting = true
	d.amount = 14
	d.lifetime = 1.4
	d.explosiveness = 0.9
	d.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	d.emission_sphere_radius = 0.8
	d.direction = Vector3.UP
	d.spread = 70.0
	d.initial_velocity_min = 1.0
	d.initial_velocity_max = 3.0
	d.gravity = Vector3(0, 0.6, 0)
	d.damping_min = 1.5
	d.damping_max = 2.5
	d.scale_amount_min = 0.8
	d.scale_amount_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.0))
	d.scale_amount_curve = curve
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 3
	m.material = F.flat_mat(Color(0.82, 0.77, 0.68, 0.55))
	d.mesh = m
	d.position = at
	add_child(d)
	get_tree().create_timer(2.0).timeout.connect(d.queue_free)

# ------------------------------------------------------------------ the garden

## Something that grows in at `at` s.
func _grows(n: Node3D, at: float) -> void:
	n.visible = false
	_grow.append([n, at, n.scale])
	garden.add_child(n)

func _plan_garden() -> void:
	garden = Node3D.new()
	add_child(garden)
	var lawn := F.color_mat(Color("86b955"))
	var paver := F.color_mat(Color("d9d2c2"))
	var timber := F.color_mat(Color("8a7560"))
	var charcoal := F.color_mat(Color("33373b"))
	var hedge := F.color_mat(Color("4f7f3a"))
	# Lawn where the hardstand was, and the paths through it
	_grows(F.box(Vector3(26.5, 0.05, 11.3), lawn, Vector3(21.75, 0.03, 7.35), false), GROW_AT)
	_grows(F.box(Vector3(27.0, 0.06, 2.4), paver, Vector3(21.5, 0.07, 2.9), false), GROW_AT + 0.1)
	_grows(F.box(Vector3(2.4, 0.06, 9.0), paver, Vector3(13.0, 0.07, 8.2), false), GROW_AT + 0.15)
	# The lap pool with its white coping, out in the lawn
	var pool := Node3D.new()
	pool.position = Vector3(25.5, 0, 9.0)
	pool.add_child(F.box(Vector3(13.0, 0.1, 3.6), F.color_mat(Color("eeece6")), Vector3(0, 0.07, 0), false))
	pool.add_child(F.box(Vector3(12.0, 0.04, 2.6), F.color_mat(Color("49b6d8")), Vector3(0, 0.13, 0), false))
	_grows(pool, GROW_AT + 0.6)
	# Salvaged wharf timbers standing in the forecourt
	for i in 9:
		var p := Node3D.new()
		var h := _rng.randf_range(3.0, 6.5)
		p.add_child(F.cylinder(0.2, h, timber, Vector3(0, h * 0.5, 0), 8))
		p.position = Vector3(15.5 + i * 1.1 + _rng.randf_range(-0.3, 0.3), 0.05, 4.8 + _rng.randf_range(-0.6, 0.6) + (i % 2) * 1.2)
		p.rotation = Vector3(_rng.randf_range(-0.04, 0.04), 0, _rng.randf_range(-0.04, 0.04))
		_grows(p, GROW_AT + 0.9 + i * 0.12)
	# Garden beds, and trees on the lawn
	for at in [Vector3(10.5, 0, 7.5), Vector3(33.5, 0, 5.0), Vector3(19.5, 0, 12.0)]:
		var bed := Node3D.new()
		bed.position = at
		bed.add_child(F.box(Vector3(2.4, 0.35, 2.4), hedge, Vector3(0, 0.18, 0)))
		Flora.plant(bed, [["Lomandra", Vector3(-0.5, 0.3, 0.4)], ["Bottlebrush", Vector3(0.4, 0.3, -0.3)]], _rng)
		_grows(bed, GROW_AT + 1.2)
	var trees := [["Tuckeroo", Vector3(10.5, 0, 12.0)], ["CabbagePalm", Vector3(34.0, 0, 12.2)], ["Poinciana", Vector3(16.0, 0, 11.5)],
		["CabbagePalm", Vector3(11.5, 0, 3.2)], ["Tuckeroo", Vector3(29.0, 0, 4.4)]]
	for i in trees.size():
		var tr := Node3D.new()
		tr.position = trees[i][1]
		Flora.plant(tr, [[trees[i][0], Vector3.ZERO, 5.5 if trees[i][0] != "CabbagePalm" else 7.0]], _rng)
		_grows(tr, GROW_AT + 1.4 + i * 0.25)
	# The driveway off Angora Road: down under a charcoal wall with the name
	# on it, a hedge along its top and a timber pergola over the ramp
	var drive := Node3D.new()
	drive.position = Vector3(41.5, 0, 6.0)
	drive.add_child(F.box(Vector3(6.0, 0.05, 4.0), F.color_mat(Color("54585c")), Vector3(1.5, 0.03, 0), false))
	drive.add_child(F.box(Vector3(0.45, 2.6, 7.5), charcoal, Vector3(-1.6, 1.3, 0)))
	drive.add_child(F.box(Vector3(0.7, 0.5, 7.5), hedge, Vector3(-1.6, 2.85, 0)))
	var sign := F.label3d("RIVERLIGHT", 120, Color("f4f2ec"))
	sign.outline_size = 0
	sign.pixel_size = 0.008
	sign.position = Vector3(-1.36, 1.7, 0)
	sign.rotation.y = PI * 0.5
	drive.add_child(sign)
	for z in [-2.4, 2.4]:
		for x in [-1.1, 3.6]:
			drive.add_child(F.box(Vector3(0.18, 3.0, 0.18), timber, Vector3(x, 1.5, z)))
		drive.add_child(F.box(Vector3(5.2, 0.2, 0.2), timber, Vector3(1.25, 3.05, z)))
	for i in 9:
		drive.add_child(F.box(Vector3(0.12, 0.14, 5.2), timber, Vector3(-0.9 + i * 0.55, 3.2, 0)))
	_grows(drive, GROW_AT + 0.4)
	_at(GROW_AT + 1.0, func(): game.sfx.hit("birds"))
	_at(T_END - 0.4, func(): game.sfx.hit("chime"))

## 0 -> 1 with a little overshoot, so things pop up like a time-lapse.
static func _back(u: float) -> float:
	var c := 1.4
	var v := u - 1.0
	return 1.0 + (c + 1.0) * v * v * v + c * v * v

## The real surroundings of Riverlight at Hamilton Reach, Brisbane, built from
## primitives: the river, the park and the RiverWalk, the Hamilton Reach
## neighbours, the golf course, Bulimba across the water, the CBD far upstream,
## the Gateway Bridge downstream and a CityCat running to the terminal.
## Sources: /mnt/project-files/visuals/riverlight-site-reference.md.
##
## The site plan has the river at -z. Riverlight looks south over the river, so
## seen from the site the city's upstream on the right (+x) and the Gateway
## Bridge downstream on the left (-x), as they are from the real building.
## Distances past the river are squeezed to about half, so the haze leaves
## something to see.
extends RefCounted

const F := preload("res://scripts/factory.gd")

const RIVER_N := -34.0       # the near bank (the RiverWalk's on it)
const RIVER_W := 380.0       # the Brisbane River's about 400 m wide here
const RIVER_S := RIVER_N - RIVER_W
const GATEWAY_X := -1300.0   # the Gateway Bridge, about 3 km downstream
const TERMINAL := Vector3(-150.0, 0.0, RIVER_N - 12.0)   # Northshore Hamilton CityCat

const ROOFS := [Color("8a9096"), Color("5e6670"), Color("b4634a"), Color("e8e6df"), Color("9c8b74"), Color("6f7a72")]
const WALLS := [Color("f1eee6"), Color("e5ddcc"), Color("d7dde0"), Color("f4f2ec")]
const LEAVES := [Color("4f7d43"), Color("5d8a48"), Color("426b3c"), Color("6b9150")]

static func build(root: Node3D) -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8000, 8000)
	ground.mesh = pm
	ground.material_override = F.mat("grass")
	root.add_child(ground)
	root.add_child(F.box(Vector3(8000, 0.05, 9), F.mat("road"), Vector3(0, 0.03, 16), false))
	root.add_child(F.box(Vector3(8000, 0.05, RIVER_W), _water(), Vector3(0, 0.04, RIVER_N - RIVER_W * 0.5), false))
	# Rock revetment along both banks, and the RiverWalk path on the near one
	root.add_child(F.box(Vector3(8000, 0.3, 2.0), F.mat("rock"), Vector3(0, 0.05, RIVER_N - 0.6), false))
	root.add_child(F.box(Vector3(8000, 0.3, 2.0), F.mat("rock"), Vector3(0, 0.05, RIVER_S + 0.6), false))
	root.add_child(F.box(Vector3(8000, 0.06, 4), F.mat("podium"), Vector3(0, 0.05, -28), false))
	# Kingsford Smith Drive, up behind the site
	root.add_child(F.box(Vector3(8000, 0.05, 22), F.mat("road"), Vector3(0, 0.03, 330), false))

	var rng := RandomNumberGenerator.new()
	rng.seed = 2017
	_park(root, rng)
	_neighbours(root)
	_sheds(root)
	_golf(root, rng)
	_suburbs(root, rng)
	_cbd(root, rng)
	_gateway(root)
	_terminal(root)
	_citycat(root)

## Northshore Riverside Park between the site and the river: lawn, big shade
## trees, and palms along the RiverWalk.
static func _park(root: Node3D, rng: RandomNumberGenerator) -> void:
	for x in [-72.0, -46.0, -24.0, 2.0, 26.0, 50.0, 78.0]:
		_palm(root, Vector3(x + rng.randf_range(-3, 3), 0, -31.5 + rng.randf_range(-1, 1)), rng)
	for p in [Vector3(-60, 0, -18), Vector3(-34, 0, -22), Vector3(40, 0, -20), Vector3(66, 0, -16), Vector3(96, 0, -22)]:
		_fig(root, p, rng.randf_range(4.5, 6.0))

static func _palm(root: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(6.5, 9.0)
	var lean := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	var top := at + Vector3(0, h, 0) + lean
	var trunk := F.beam(at, top, 0.32, F.mat("palm_trunk"))
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(trunk)
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf() * 0.4
		var tip := top + Vector3(cos(a) * 2.6, -1.1, sin(a) * 2.6)
		var mid := top + Vector3(cos(a) * 1.3, 0.35, sin(a) * 1.3)
		root.add_child(F.beam(top, mid, 0.22, F.mat("palm")))
		root.add_child(F.beam(mid, tip, 0.18, F.mat("palm")))

static func _fig(root: Node3D, at: Vector3, r: float) -> void:
	root.add_child(F.cylinder(0.6, 3.2, F.mat("trunk"), at + Vector3(0, 1.6, 0), 8))
	var crown := F.sphere(r, F.mat("tree"), at + Vector3(0, 3.0 + r * 0.45, 0))
	crown.scale = Vector3(1.0, 0.8, 1.0)
	root.add_child(crown)

## Hamilton Reach's other buildings: lower than Riverlight ("it rises above the
## low rise buildings below"), in the estate's whites, sand and river greys.
static func _neighbours(root: Node3D) -> void:
	# [x, z, width, depth, storeys, facade]
	var blocks := [
		[-56.0, -6.0, 18.0, 22.0, 7, Color("f1efe9")],
		[-84.0, 22.0, 24.0, 16.0, 6, Color("e2d8c4")],
		[-60.0, 52.0, 30.0, 14.0, 5, Color("f1efe9")],
		[-118.0, -12.0, 20.0, 26.0, 8, Color("c9d3d8")],
		[-146.0, 34.0, 26.0, 18.0, 6, Color("f1efe9")],
		[-182.0, 0.0, 22.0, 22.0, 5, Color("e2d8c4")],
		[-34.0, 88.0, 40.0, 12.0, 3, Color("e2d8c4")],
		[-100.0, 96.0, 44.0, 12.0, 3, Color("d7dde0")],
		[-170.0, 92.0, 36.0, 12.0, 3, Color("f1efe9")],
	]
	for b in blocks:
		var h: float = float(b[4]) * 3.1
		var m := F.window_mat(b[5], 0.0, 0.0, Color("566e7d"))
		var mi := F.box(Vector3(b[2], h, b[3]), m, Vector3(b[0], h * 0.5, b[1]))
		root.add_child(mi)
		# Roof slab and plant room in white
		root.add_child(F.box(Vector3(b[2] + 0.6, 0.5, b[3] + 0.6), F.mat("white"), Vector3(b[0], h + 0.25, b[1]), false))
		if int(b[4]) >= 5:
			root.add_child(F.box(Vector3(b[2] * 0.35, 2.4, b[3] * 0.35), F.mat("white"), Vector3(b[0], h + 1.2, b[1]), false))
	# Street trees along the estate's streets
	for x in range(-200, -30, 14):
		for z in [70.0, 112.0]:
			_fig(root, Vector3(x, 0, z), 2.6)

## Northshore west of the site in 2017: old wharf sheds and vacant lots.
static func _sheds(root: Node3D) -> void:
	for s in [[120.0, -6.0, 70.0, 30.0], [210.0, 30.0, 60.0, 34.0], [150.0, 80.0, 90.0, 26.0]]:
		var h := 9.0
		root.add_child(F.box(Vector3(s[2], h, s[3]), F.mat("shed"), Vector3(s[0], h * 0.5, s[1])))
		var roof := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(s[3] + 1.0, 3.0, s[2] + 1.0)
		roof.mesh = prism
		roof.material_override = F.mat("shed_roof")
		roof.position = Vector3(s[0], h + 1.5, s[1])
		roof.rotation.y = PI * 0.5
		root.add_child(roof)
	for lot in [[70.0, 150.0, 80.0, 60.0], [260.0, 120.0, 100.0, 80.0], [330.0, -10.0, 70.0, 40.0]]:
		root.add_child(F.box(Vector3(lot[2], 0.05, lot[3]), F.mat("dry_grass"), Vector3(lot[0], 0.06, lot[1]), false))

## The Royal Queensland Golf Club borders Hamilton Reach on the east.
static func _golf(root: Node3D, rng: RandomNumberGenerator) -> void:
	var trees: Array = []
	for f in [[-420.0, 40.0, 260.0, 46.0, 0.2], [-560.0, 170.0, 300.0, 52.0, -0.3], [-760.0, 60.0, 280.0, 48.0, 0.5], [-900.0, 230.0, 240.0, 44.0, 0.1]]:
		var fw := F.box(Vector3(f[2], 0.05, f[3]), F.mat("fairway"), Vector3(f[0], 0.06, f[1]), false)
		fw.rotation.y = f[4]
		root.add_child(fw)
		var green := F.cylinder(13.0, 0.06, F.mat("green_cut"), Vector3(f[0], 0.1, f[1]) + Vector3(cos(f[4]), 0, -sin(f[4])) * f[2] * 0.5, 20)
		root.add_child(green)
		for side in [-1.0, 1.0]:
			var bunker := F.cylinder(6.0, 0.07, F.mat("sand"), green.position + Vector3(rng.randf_range(-8, 8), 0.03, side * 14.0), 14)
			bunker.scale = Vector3(1.6, 1, 0.8)
			root.add_child(bunker)
		for i in 26:
			var along: float = rng.randf_range(-0.5, 0.5) * f[2]
			var across: float = (f[3] * 0.5 + rng.randf_range(6, 16)) * (1.0 if i % 2 == 0 else -1.0)
			var b := Basis(Vector3.UP, f[4])
			trees.append(Vector3(f[0], 0, f[1]) + b * Vector3(along, 0, across))
	_tree_field(root, trees, rng)

## Across the river: Bulimba and Morningside, low houses under big trees. And
## up behind the site, Hamilton's houses on the hill past Kingsford Smith Drive.
static func _suburbs(root: Node3D, rng: RandomNumberGenerator) -> void:
	var houses: Array = []
	var trees: Array = []
	for i in 1400:
		var p := Vector3(rng.randf_range(-1700, 2200), 0, rng.randf_range(RIVER_S - 1300, RIVER_S - 18))
		if abs(p.x - GATEWAY_X) < 60.0:
			continue
		houses.append(p)
	for i in 900:
		var p := Vector3(rng.randf_range(-1700, 2200), 0, rng.randf_range(RIVER_S - 1300, RIVER_S - 10))
		trees.append(p)
	for i in 900:
		var p := Vector3(rng.randf_range(-1700, 2200), 0, rng.randf_range(350, 1500))
		if (p.x < -250 and p.z < 500) or abs(p.x - GATEWAY_X) < 60.0:
			continue
		houses.append(p)
		if i % 2 == 0:
			trees.append(p + Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12)))
	_house_field(root, houses, rng)
	_tree_field(root, trees, rng)

static func _house_field(root: Node3D, at: Array, rng: RandomNumberGenerator) -> void:
	var walls := MultiMesh.new()
	walls.transform_format = MultiMesh.TRANSFORM_3D
	walls.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 1, 1)
	walls.mesh = bm
	walls.instance_count = at.size()
	var roofs := MultiMesh.new()
	roofs.transform_format = MultiMesh.TRANSFORM_3D
	roofs.use_colors = true
	var pr := PrismMesh.new()
	pr.size = Vector3(1, 1, 1)
	roofs.mesh = pr
	roofs.instance_count = at.size()
	for i in at.size():
		var w := rng.randf_range(9, 14)
		var d := rng.randf_range(10, 16)
		# Queenslanders stand up on stumps: a taller box under the roof
		var h := rng.randf_range(3.2, 5.5)
		var yaw := rng.randf() * PI
		var b := Basis(Vector3.UP, yaw)
		walls.set_instance_transform(i, Transform3D(b * Basis.from_scale(Vector3(w, h, d)), at[i] + Vector3(0, h * 0.5, 0)))
		walls.set_instance_color(i, WALLS[rng.randi() % WALLS.size()])
		roofs.set_instance_transform(i, Transform3D(b * Basis.from_scale(Vector3(w + 1.0, 2.4, d + 1.0)), at[i] + Vector3(0, h + 1.2, 0)))
		roofs.set_instance_color(i, ROOFS[rng.randi() % ROOFS.size()])
	_add_multi(root, walls)
	_add_multi(root, roofs)

static func _tree_field(root: Node3D, at: Array, rng: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	mm.mesh = sm
	mm.instance_count = at.size()
	for i in at.size():
		var r := rng.randf_range(4.0, 9.0)
		var b := Basis.from_scale(Vector3(r * 2.0, r * 1.4, r * 2.0))
		mm.set_instance_transform(i, Transform3D(b, at[i] + Vector3(0, r * 1.1, 0)))
		mm.set_instance_color(i, LEAVES[rng.randi() % LEAVES.size()])
	_add_multi(root, mm)

static func _add_multi(root: Node3D, mm: MultiMesh) -> void:
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _tinted()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

## The river: the Brisbane River's olive-brown, glossy enough to pick up the
## sky so it reads as water from up high.
static func _water() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = F.COLORS["river"]
	m.roughness = 0.12
	m.metallic_specular = 0.8
	return m

static var _tint: StandardMaterial3D

## Toon-lit, coloured per instance (for the fields of houses and trees).
static func _tinted() -> StandardMaterial3D:
	if _tint == null:
		_tint = StandardMaterial3D.new()
		_tint.vertex_color_use_as_albedo = true
		_tint.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		_tint.specular_mode = BaseMaterial3D.SPECULAR_TOON
		_tint.roughness = 0.9
	return _tint

## The CBD, about 6 km upstream to the west-south-west, in the haze.
static func _cbd(root: Node3D, rng: RandomNumberGenerator) -> void:
	var centre := Vector3(1900, 0, -1250)
	var tones := [Color("8fa6b8"), Color("a7b7c2"), Color("7d93a6"), Color("c3ccd2"), Color("9aa9b0")]
	for i in 38:
		var p := centre + Vector3(rng.randf_range(-260, 260), 0, rng.randf_range(-200, 200))
		var near := 1.0 - clampf(p.distance_to(centre) / 300.0, 0.0, 1.0)
		var h := rng.randf_range(40, 90) + near * rng.randf_range(60, 170)
		var w := rng.randf_range(24, 44)
		var b := F.box(Vector3(w, h, rng.randf_range(24, 44)), F.color_mat(tones[i % tones.size()]), p + Vector3(0, h * 0.5, 0), false)
		b.rotation.y = rng.randf_range(-0.3, 0.3)
		root.add_child(b)

## The Gateway Bridge (Sir Leo Hielscher Bridges): twin concrete box girders,
## 1.6 km long, 260 m main span, the deck 64.5 m over the river.
static func _gateway(root: Node3D) -> void:
	var mid := RIVER_N - RIVER_W * 0.5
	var half := 800.0
	var concrete := F.mat("bridge")
	for x in [GATEWAY_X - 16.0, GATEWAY_X + 16.0]:
		var n := 32
		var prev := Vector3.ZERO
		for i in n + 1:
			var u := -1.0 + 2.0 * i / n
			var p := Vector3(x, _gateway_deck(u), mid + u * half)
			if i > 0:
				var seg := F.box(Vector3(22.0, 4.0, prev.distance_to(p) + 0.5), concrete, (prev + p) * 0.5, false)
				seg.basis = Basis.looking_at(p - prev, Vector3.UP)
				root.add_child(seg)
			prev = p
		# Piers: the two big ones either side of the main span, then the approaches
		var piers := [-130.0, 130.0]
		for k in range(1, 9):
			piers.append(-130.0 - k * 75.0)
			piers.append(130.0 + k * 75.0)
		for z in piers:
			var u: float = z / half
			var h := _gateway_deck(u) - 2.0
			if h < 2.0:
				continue
			var t := 7.0 if absf(z) < 140.0 else 3.5
			root.add_child(F.box(Vector3(t, h, t * 1.6), concrete, Vector3(x, h * 0.5, mid + z), false))
		# The main span's girder deepens over the piers (haunches)
		for z in [-130.0, 130.0]:
			root.add_child(F.box(Vector3(18.0, 12.0, 40.0), concrete, Vector3(x, _gateway_deck(z / half) - 6.0, mid + z), false))

static func _gateway_deck(u: float) -> float:
	return 4.0 + 60.5 * (1.0 - u * u)

## The Northshore Hamilton CityCat terminal: a pontoon with a white and blue
## shelter, and a gangway to the RiverWalk.
static func _terminal(root: Node3D) -> void:
	var t := Node3D.new()
	t.position = TERMINAL
	root.add_child(t)
	t.add_child(F.box(Vector3(30, 1.0, 9), F.mat("podium"), Vector3(0, 0.3, 0)))
	t.add_child(F.box(Vector3(26, 0.4, 8), F.mat("white"), Vector3(0, 3.6, 0)))
	t.add_child(F.box(Vector3(26.2, 0.6, 8.2), F.mat("citycat_blue"), Vector3(0, 3.2, 0)))
	for x in [-11.0, 0.0, 11.0]:
		for z in [-3.5, 3.5]:
			t.add_child(F.box(Vector3(0.25, 2.6, 0.25), F.mat("white"), Vector3(x, 2.0, z)))
	t.add_child(F.beam(Vector3(0, 0.8, 4.5), Vector3(0, 0.6, 12.0), 2.2, F.mat("steel")))

## A CityCat comes down from the city, berths at the terminal, and heads back.
static func _citycat(root: Node3D) -> void:
	var boat := Node3D.new()
	var navy := F.mat("citycat_blue")
	for z in [-2.6, 2.6]:
		boat.add_child(F.box(Vector3(25, 1.6, 1.8), navy, Vector3(0, 0.6, z)))
	boat.add_child(F.box(Vector3(24, 1.4, 7.0), F.mat("white"), Vector3(0, 1.9, 0)))
	boat.add_child(F.box(Vector3(18, 1.3, 6.4), F.color_mat(Color("2a3a48")), Vector3(-1.0, 3.2, 0)))
	boat.add_child(F.box(Vector3(19, 0.35, 6.8), F.mat("white"), Vector3(-1.0, 4.0, 0)))
	boat.add_child(F.box(Vector3(24.2, 0.4, 7.05), navy, Vector3(0, 2.3, 0)))
	var berth := TERMINAL + Vector3(0, 0, -8.5)
	var away := Vector3(2300, 0, RIVER_N - RIVER_W * 0.55)
	boat.position = away
	var d := berth - away
	boat.rotation.y = atan2(-d.z, d.x)
	root.add_child(boat)
	var tw := boat.create_tween().set_loops()
	tw.tween_property(boat, "position", berth, 150.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(40.0)
	tw.tween_property(boat, "position", away, 150.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_interval(20.0)

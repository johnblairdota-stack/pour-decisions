## The buildings round Riverlight. The Hamilton Reach estate next door as it
## stood in 2017 (data/hamilton_reach_2017.json, traced off the 2017 aerial by
## tools/estate_to_game.py: the apartment blocks and terrace rows with their
## balconied facades and roof plant, and the row of two-storey houses along
## the golf course); the map's warehouses and sheds near the site as
## corrugated sheds with low gable roofs, roller doors and whirlybirds; Eat
## Street's shipping containers; and the fields of houses out in the haze.
## The models are tools/blender/buildings.py (assets/buildings/buildings.glb).
## scripts/surrounds.gd hands over the map's buildings it wants drawn here and
## extrudes the rest itself.
extends RefCounted

const F := preload("res://scripts/factory.gd")
const LIB := "res://assets/buildings/buildings.glb"
const ESTATE := "res://data/hamilton_reach_2017.json"
const CLADDING := preload("res://shaders/cladding.gdshader")
const TILE := 160.0
const STOREY := 3.1
const DETAIL_R := 800.0     # gable roofs, whirlybirds and containers this close to the site
const SHEDS := ["industrial", "warehouse", "shed", "commercial", "retail"]

const COLORS := {
	"render": Color("f2f0ea"), "render_grey": Color("c9c8c2"), "clad": Color("3a3d42"), "timber": Color("b4875a"),
	"glass": Color("54636e"), "roof_flat": Color("d8d8d2"), "frame": Color("2f3236"), "garage": Color("8d9196"),
	"balustrade": Color("a9c2cc"), "weatherboard": Color("efe6cf"), "trim": Color("ffffff"), "roof_tin": Color("8a9096"),
	"lattice": Color("6b5a48"), "stump": Color("9a9890"), "brick": Color("a5644a"), "roof_tile": Color("b0583e"),
	"ac": Color("e9e9e4"), "ac_grille": Color("54585c"), "solar": Color("263a5c"), "solar_frame": Color("b9bdc0"),
	"plant": Color("a9adb0"), "door": Color("5a5e63"), "container_dark": Color("3b3e42"), "whirly": Color("c7cbce"),
	"path": Color("c8c4ba"),
}
## The estate's facades: white slab edges, grey glass, and a feature colour
## on the solid panels between the balconies, block by block
const FRAME := Color("f2f0ea")
const GLASS := Color("5f727c")
const PANELS := [Color("3a3d42"), Color("b4875a"), Color("8d969c"), Color("6f7d72")]
const ROOF := Color("d8d8d2")
const SHED_WALLS := [Color("d9d6cf"), Color("c4c8ca"), Color("e2dfd6"), Color("b9c0c4"), Color("9aa5ab")]
const SHED_ROOF := Color("c3c7c9")
const CONTAINERS := [Color("b04a3a"), Color("2f5f8f"), Color("6f7a72"), Color("c98a3a"), Color("e8e6df"),
	Color("2f6f5a"), Color("d9b23a")]
## Out in the haze: weatherboard and brick, tin and tile
const HOUSE_WALLS := [Color("f1eee6"), Color("e5ddcc"), Color("d7dde0"), Color("f4f2ec"), Color("e9e2c8")]
const BRICK := [Color("a5644a"), Color("b9806a"), Color("c8b49a"), Color("8f5a46")]
const TIN := [Color("8a9096"), Color("5e6670"), Color("b4634a"), Color("e8e6df"), Color("6f7a72"), Color("2f5f4f")]
const TILE_ROOF := [Color("b0583e"), Color("9c4b3a"), Color("6e6a66"), Color("8a5a45")]

static var _lib: Node
static var _meshes := {}
static var _mats := {}
static var _sheds: Array = []        # the map's buildings handed over: [poly, h, wall, kind]
static var _boxes: Array = []        # [poly, h, colour] containers drawn as models
static var _blocks: Array = []       # the map's apartment blocks: [poly, storeys]

## Clears what an earlier level handed over.
static func begin() -> void:
	_sheds.clear()
	_boxes.clear()
	_blocks.clear()

## Offered each of the map's buildings near enough to draw properly; true if
## it's taken (and surrounds.gd shouldn't extrude it).
static func claim(kind: String, poly: PackedVector2Array, h: float, dist: float, rng: RandomNumberGenerator) -> bool:
	if dist > DETAIL_R:
		return false
	if kind == "apartments":
		_blocks.append([poly, maxi(roundi(h / STOREY), 3)])
		return true
	if kind == "container":
		_boxes.append([poly, h, CONTAINERS[rng.randi() % CONTAINERS.size()]])
		return true
	if kind in SHEDS:
		_sheds.append([poly, h, SHED_WALLS[rng.randi() % SHED_WALLS.size()], kind])
		return true
	return false

## Draws the estate and what was claimed. Returns the footprints, so the
## street furniture and the trees keep off them.
static func build(root: Node3D, rng: RandomNumberGenerator) -> Array:
	var foot: Array = []
	var items: Array = []
	_estate(root, items, foot, rng)
	_draw_sheds(root, items, rng)
	_containers(items, rng)
	place(root, items)
	return foot

# ------------------------------------------------------------------ models

## One model's mesh, its parts given toon materials ("body", "roof" and
## "container" take each instance's own colour).
static func mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	if _lib == null:
		_lib = (load(LIB) as PackedScene).instantiate()
	var mi := _lib.get_node_or_null(name) as MeshInstance3D
	if mi == null:
		push_warning("neighbours: no model " + name)
		_meshes[name] = null
		return null
	var m := mi.mesh
	for i in m.get_surface_count():
		var src := m.surface_get_material(i)
		var key := src.resource_name if src != null else ""
		m.surface_set_material(i, _mat(key))
	_meshes[name] = m
	return m

static func _mat(key: String) -> Material:
	if not _mats.has(key):
		if key in ["body", "roof", "container"]:
			var t := StandardMaterial3D.new()
			t.vertex_color_use_as_albedo = true
			t.vertex_color_is_srgb = true
			t.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			t.specular_mode = BaseMaterial3D.SPECULAR_TOON
			t.roughness = 0.9
			_mats[key] = t
		else:
			_mats[key] = F.color_mat(COLORS.get(key, Color.MAGENTA), false)
	return _mats[key]

## Places `items` (each [model name, Transform3D, colour]) under `root`, one
## multimesh per model per tile.
static func place(root: Node3D, items: Array, shadows := true) -> void:
	var groups := {}
	for it in items:
		var t: Transform3D = it[1]
		var key := "%s|%d|%d" % [it[0], floori(t.origin.x / TILE), floori(t.origin.z / TILE)]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(it)
	for key in groups:
		var name: String = (key as String).split("|")[0]
		var m := mesh(name)
		if m == null:
			continue
		var list: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = m
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][1])
			mm.set_instance_color(i, list[i][2] if list[i].size() > 2 else Color.WHITE)
		var mi := MultiMeshInstance3D.new()
		mi.name = "Bldg_" + (key as String).replace("|", "_")
		mi.multimesh = mm
		if not shadows or name in ["RoofAC", "SolarArray", "Whirlybird"]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)

## Standing at `p` on the ground (or at height y), front (+z) towards `face`.
static func at(p: Vector2, face: Vector2, y := 0.0, s := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, atan2(face.x, face.y)).scaled(s), Vector3(p.x, y, p.y))

# ------------------------------------------------------------------ the estate

static func _estate(root: Node3D, items: Array, foot: Array, rng: RandomNumberGenerator) -> void:
	if not FileAccess.file_exists(ESTATE):
		push_warning("neighbours: %s missing" % ESTATE)
		return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ESTATE))
	var blocks: Array = []
	for b in d["blocks"]:
		blocks.append([_poly(b["pts"]), int(b["storeys"]), b["kind"] == "apartments"])
	for b in _blocks:
		blocks.append([b[0], b[1], true])
	# walls by feature colour (one facade material each), roofs in one mesh
	var walls := {}
	var roofs := SurfaceTool.new()
	roofs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 0
	for b in blocks:
		var poly: PackedVector2Array = b[0]
		var h := float(b[1]) * STOREY + 0.5
		var pc: int = n % PANELS.size()
		n += 1
		if not walls.has(pc):
			walls[pc] = SurfaceTool.new()
			(walls[pc] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
		_walls(walls[pc], poly, 0.0, h)
		_cap(roofs, poly, h, ROOF)
		foot.append(poly)
		_roof_kit(poly, h, b[2], items, rng)
	for pc in walls:
		var mi := MeshInstance3D.new()
		mi.name = "Estate_%d" % pc
		mi.mesh = (walls[pc] as SurfaceTool).commit()
		var m := F.window_mat(FRAME, 0.0, 0.0, GLASS)
		m.set_shader_parameter("riverlight", true)
		m.set_shader_parameter("cell", Vector2(1.6, STOREY))
		m.set_shader_parameter("panel_color", PANELS[pc])
		m.set_shader_parameter("panel_every", 3.0)
		mi.material_override = m
		root.add_child(mi)
	var rm := MeshInstance3D.new()
	rm.name = "EstateRoofs"
	rm.mesh = roofs.commit()
	rm.material_override = _vertex_mat()
	root.add_child(rm)
	var k := 0
	for hs in d["houses"]:
		var p := Vector2(hs["at"][0], hs["at"][1])
		var face := Vector2(hs["face"][0], hs["face"][1])
		items.append(["ModernHouse" if k % 2 == 0 else "ModernHouseB", at(p, face), Color.WHITE])
		k += 1
		var t := Transform2D(atan2(face.x, face.y), p)
		foot.append(t * PackedVector2Array([Vector2(-6, -7), Vector2(6, -7), Vector2(6, 9), Vector2(-6, 9)]))

## Lift overruns, air conditioners and solar panels on a flat roof, squared
## to its longest side, kept back from the edge and from each other.
static func _roof_kit(poly: PackedVector2Array, h: float, lifts: bool, items: Array, rng: RandomNumberGenerator) -> void:
	var inner := Geometry2D.offset_polygon(poly, -3.0)
	if inner.is_empty():
		return
	var inside: PackedVector2Array = inner[0]
	var axis := _long_axis(poly)
	var face := axis.orthogonal()
	var box := Rect2(inside[0], Vector2.ZERO)
	for p in inside:
		box = box.expand(p)
	var area := absf(_area(poly))
	var want := []
	if lifts:
		want.append("LiftOverrun")
		if area > 1500.0:
			want.append("LiftOverrun")
	for i in clampi(int(area / 200.0), 1, 8):
		want.append("RoofAC")
	for i in clampi(int(area / (220.0 if not lifts else 380.0)), 1, 8):
		want.append("SolarArray")
	var put: Array = []
	for name in want:
		for tries in 30:
			var p := Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
			if not Geometry2D.is_point_in_polygon(p, inside):
				continue
			var ok := true
			for q in put:
				if p.distance_to(q) < 5.5:
					ok = false
					break
			if ok:
				put.append(p)
				items.append([name, at(p, face, h), Color.WHITE])
				break

# ------------------------------------------------------------------ sheds

## The map's warehouses and sheds near the site: corrugated walls (the
## cladding shader: ribs, a precast plinth, roller doors) up to the eaves and,
## where the footprint's a plain box, a low gable roof along the long side
## with whirlybirds along the ridge (otherwise a flat roof).
static func _draw_sheds(root: Node3D, items: Array, rng: RandomNumberGenerator) -> void:
	if _sheds.is_empty():
		return
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var roofs := SurfaceTool.new()
	roofs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in _sheds:
		var r := _rect(s[0])
		if r.is_empty():
			# not a plain box: the walls round its outline and a flat roof
			walls.set_color(s[2])
			_walls(walls, s[0], 0.0, s[1])
			_cap(roofs, s[0], s[1], SHED_ROOF)
			continue
		var c := (r[0] + r[2]) * 0.5
		var u := r[1] - r[0]
		var v := r[3] - r[0]
		if u.length() < v.length():
			r = PackedVector2Array([r[1], r[2], r[3], r[0]])
			var t := u
			u = v
			v = t
		var ridge_h := minf(v.length() * 0.5 * tan(deg_to_rad(6.0)), 2.5)
		var eave := maxf(float(s[1]) - ridge_h, 3.5)
		walls.set_color(s[2])
		_walls(walls, r, 0.0, eave)
		# the gable ends: from the eaves up to the ridge
		var a := r[0] + v * 0.5
		var b := r[1] + v * 0.5
		var top := eave + ridge_h
		for e in [[r[0], r[3], a], [r[2], r[1], b]]:
			var p0: Vector2 = e[0]
			var p1: Vector2 = e[1]
			var pm: Vector2 = e[2]
			var out := (pm - c).normalized()
			_tri(walls, [Vector3(p0.x, eave, p0.y), Vector3(p1.x, eave, p1.y), Vector3(pm.x, top, pm.y)],
				Vector3(out.x, 0, out.y))
		# two roof slopes, run out past the walls a little
		var over := v.normalized() * 0.5
		var ou := u.normalized() * 0.3
		var dip := 0.5 * tan(deg_to_rad(6.0))
		roofs.set_color(SHED_ROOF)
		for side in [[r[0] - over - ou, r[1] - over + ou], [r[3] + over - ou, r[2] + over + ou]]:
			var q0: Vector2 = side[0]
			var q1: Vector2 = side[1]
			var m0 := a - ou
			var m1 := b + ou
			var y0 := eave - dip
			var up := (Vector3(q1.x - q0.x, 0, q1.y - q0.y)).cross(Vector3(m0.x - q0.x, top - y0, m0.y - q0.y)).normalized()
			if up.y < 0.0:
				up = -up
			_quad(roofs, [Vector3(q0.x, y0, q0.y), Vector3(q1.x, y0, q1.y), Vector3(m1.x, top + 0.05, m1.y),
				Vector3(m0.x, top + 0.05, m0.y)], up)
		if s[3] in ["industrial", "warehouse"]:
			var n := int(u.length() / 12.0)
			for i in n:
				var p := a + u * ((i + 0.5) / n)
				items.append(["Whirlybird", Transform3D(Basis(), Vector3(p.x, top, p.y)), Color.WHITE])
	var wm := MeshInstance3D.new()
	wm.name = "Sheds"
	wm.mesh = walls.commit()
	var m := ShaderMaterial.new()
	m.shader = CLADDING
	wm.material_override = m
	root.add_child(wm)
	var rm := MeshInstance3D.new()
	rm.name = "ShedRoofs"
	rm.mesh = roofs.commit()
	rm.material_override = _vertex_mat()
	root.add_child(rm)

# ------------------------------------------------------------------ containers

## Each container footprint as the model that fits it (20 or 40 foot), a
## few stacked two high.
static func _containers(items: Array, rng: RandomNumberGenerator) -> void:
	for bx in _boxes:
		var poly: PackedVector2Array = bx[0]
		var c := Vector2.ZERO
		for p in poly:
			c += p
		c /= poly.size()
		var axis := _long_axis(poly)
		var ln := 0.0
		for p in poly:
			ln = maxf(ln, absf((p - c).dot(axis)) * 2.0)
		var name := "Container40" if ln > 9.0 else "Container20"
		var face := axis.orthogonal()
		items.append([name, at(c, face), bx[2]])
		if rng.randf() < 0.25:
			items.append([name, at(c, face, 2.6), CONTAINERS[rng.randi() % CONTAINERS.size()]])

# ------------------------------------------------------------------ the haze

## Houses out past the map: Queenslanders, post-war brick and the odd new
## one, each with its own walls and roof.
static func house_field(root: Node3D, spots: Array, rng: RandomNumberGenerator) -> void:
	var items: Array = []
	for p in spots:
		var spot: Vector3 = p
		var r := rng.randf()
		var kind := "Queenslander" if r < 0.45 else ("Postwar" if r < 0.85 else "Modern")
		var wall: Color = BRICK[rng.randi() % BRICK.size()] if kind == "Postwar" else HOUSE_WALLS[rng.randi() % HOUSE_WALLS.size()]
		var roof: Color = TILE_ROOF[rng.randi() % TILE_ROOF.size()] if kind == "Postwar" else TIN[rng.randi() % TIN.size()]
		var s := rng.randf_range(0.85, 1.15)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), spot)
		items.append([kind + "FarBody", t, wall])
		items.append([kind + "FarRoof", t, roof])
	place(root, items, false)

# ------------------------------------------------------------------ geometry

static func _poly(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p[0], p[1]))
	if out.size() > 1 and out[0].is_equal_approx(out[out.size() - 1]):
		out.remove_at(out.size() - 1)
	return out

static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5

## The direction of the polygon's longest side.
static func _long_axis(poly: PackedVector2Array) -> Vector2:
	var best := Vector2.RIGHT
	var bl := 0.0
	for i in poly.size():
		var e := poly[(i + 1) % poly.size()] - poly[i]
		if e.length() > bl:
			bl = e.length()
			best = e / bl
	return best

## The polygon's smallest bounding rectangle (four corners in turn), if the
## polygon fills most of it; otherwise empty.
static func _rect(poly: PackedVector2Array) -> PackedVector2Array:
	if poly.size() < 4 or poly.size() > 8:
		return PackedVector2Array()
	var best := PackedVector2Array()
	var best_a := INF
	for i in poly.size():
		var e := (poly[(i + 1) % poly.size()] - poly[i]).normalized()
		var n := e.orthogonal()
		var u0 := INF
		var u1 := -INF
		var v0 := INF
		var v1 := -INF
		for p in poly:
			u0 = minf(u0, p.dot(e))
			u1 = maxf(u1, p.dot(e))
			v0 = minf(v0, p.dot(n))
			v1 = maxf(v1, p.dot(n))
		var a := (u1 - u0) * (v1 - v0)
		if a < best_a:
			best_a = a
			best = PackedVector2Array([e * u0 + n * v0, e * u1 + n * v0, e * u1 + n * v1, e * u0 + n * v1])
	if best_a <= 0.0 or absf(_area(poly)) / best_a < 0.85:
		return PackedVector2Array()
	return best

## Outward-facing walls round a footprint from y0 to y1.
static func _walls(st: SurfaceTool, poly: PackedVector2Array, y0: float, y1: float) -> void:
	var turn := 1.0 if _area(poly) > 0.0 else -1.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var e := (b - a).normalized()
		var out := Vector3(e.y, 0, -e.x) * turn
		_quad(st, [Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y)], out)

## A flat roof over a footprint.
static func _cap(st: SurfaceTool, poly: PackedVector2Array, y: float, c: Color) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	st.set_color(c)
	for i in range(0, idx.size(), 3):
		var t := [poly[idx[i]], poly[idx[i + 1]], poly[idx[i + 2]]]
		_tri(st, [Vector3(t[0].x, y, t[0].y), Vector3(t[1].x, y, t[1].y), Vector3(t[2].x, y, t[2].y)], Vector3.UP)

## A quad, wound whichever way faces `nrm` (drawn one-sided).
static func _quad(st: SurfaceTool, v: Array, nrm: Vector3) -> void:
	_tri(st, [v[0], v[1], v[2]], nrm)
	_tri(st, [v[0], v[2], v[3]], nrm)

static func _tri(st: SurfaceTool, v: Array, nrm: Vector3) -> void:
	var c: Vector3 = (v[1] - v[0]).cross(v[2] - v[0])
	if c.dot(nrm) > 0.0:
		v = [v[0], v[2], v[1]]
	st.set_normal(nrm)
	for p in v:
		st.add_vertex(p)

static var _vm: StandardMaterial3D
static func _vertex_mat() -> StandardMaterial3D:
	if _vm == null:
		_vm = StandardMaterial3D.new()
		_vm.vertex_color_use_as_albedo = true
		_vm.vertex_color_is_srgb = true
		_vm.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		_vm.specular_mode = BaseMaterial3D.SPECULAR_TOON
		_vm.roughness = 0.9
	return _vm

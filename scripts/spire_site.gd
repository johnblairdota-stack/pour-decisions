## Spire Residences, 550 Queen St, Brisbane: the playable tower from L6 (the 1250 mm transfer slab) to
## the roof, 34 pours. Data and model come from the Blender build (tools/blender/spire/export_game.py:
## data/spire_site.json, assets/spire/spire_site.glb).
##
## Each level has two pours split by a construction joint that runs parallel with Ann St just in
## front of the core's jump form. The players (bots fill any empty jobs) pour the Ann St side, pour A:
## one open slab with nothing to work round. At the same time a bot crew pours the rest, pour B, round
## the core, with real concrete of their own (spire_b.gd). Both
## finish, then the deck goes up a floor and the core's jump form jumps (it stays LEAD levels ahead).
##
## The placing booms stand on tubular masts up through the lift core, the way a mast-mounted boom goes
## on a tower with a jump form: the mast is jacked up through the core as the form climbs (no lattice
## sections to add). The riser comes up the Ann St face on its ladder tower, crosses under the deck to
## the core and goes up the mast.
##
## The game's frame: the site is turned so the tower's Ann St edge runs along the game's x with the
## street on its +z side (the camera looks in from over Ann St), and slid so the riser's ladder tower
## (main.LAT_X, 0, 0) stands on the footpath just outside the podium. Then the pump, the hopper and the
## trucks (line.gd, which stay where Riverlight has them) are on Ann St's kerb lanes. y is metres above
## the Ann St kerb at the gate.
extends RefCounted

const F := preload("res://scripts/factory.gd")
const DATA := "res://data/spire_site.json"
const TOWER := Vector2(12.0, 0.0)   # main.LAT_X: the riser's ladder tower
const TOWER_CLEAR := 1.3       # m from the tower's middle back to the Ann St boundary (the podium's edge)
const SLIDE_X := 2.0           # the plate's straight Ann St edge then runs x -11 .. 14.9: the tower and the hoist both stand on it
const WALK_OUT := 0.85         # main.WALK_MID
const RIG_CLEAR := 0.7         # m people keep off the jump form's screens

## Parts of the site model the game leaves out
const HIDE := ["placing_booms_KVM26", "line_pump_BSA2109HD", "agitator_truck", "delivery_line", "street_shrubs", "PROPS_and_backprops"]

static var d := {}
static var th := 0.0           # local -> game rotation
static var off := Vector2.ZERO
static var street := 0.0       # AHD of the Ann St kerb at the gate (game y 0)
static var _polys := {}
static var _bound_a := Vector2.ZERO   # the Ann St boundary: a point on it, and its slope dz/dx
static var _bound_k := 0.0

## Loads the data and works out the frame. False if the data is missing.
static func setup() -> bool:
	if not d.is_empty():
		return true
	var f := FileAccess.open(DATA, FileAccess.READ)
	if f == null:
		push_error("Spire: %s missing (run tools/blender/spire/export_game.py)" % DATA)
		return false
	d = JSON.parse_string(f.get_as_text())
	# (the core's long side is the plan's own axis: the plate's Ann St edge is parallel with it)
	var c0 := Vector2(float(d["core"][0][0]), float(d["core"][0][1]))
	var c1 := Vector2(float(d["core"][1][0]), float(d["core"][1][1]))
	var along := (c1 - c0).normalized()
	th = atan2(along.y, -along.x)
	street = float(d.get("street_ahd", d["ground_ahd"]))
	off = Vector2.ZERO
	var plate := _raw("plate")
	var bb := _box(plate)
	off.x = SLIDE_X - (bb.position.x + 24.0)      # (the plate's 40.6 m long: its east end at x -22)
	var gate := g(d["truck_gate"]["xy"])
	var gate2 := g([float(d["truck_gate"]["xy"][0]) + float(d["truck_gate"]["along"][0]), float(d["truck_gate"]["xy"][1]) + float(d["truck_gate"]["along"][1])])
	_bound_k = (gate2.y - gate.y) / (gate2.x - gate.x)
	off.y = (TOWER.y - TOWER_CLEAR) - (gate.y + _bound_k * (TOWER.x - gate.x))
	_bound_a = g(d["truck_gate"]["xy"])
	_cut_pours()
	return true

static func _raw(key: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in d[key]:
		out.append(g(p))
	if Geometry2D.is_polygon_clockwise(out):
		out.reverse()
	return out

static func _box(pp: PackedVector2Array) -> Rect2:
	var bb := Rect2(pp[0], Vector2.ZERO)
	for p in pp:
		bb = bb.expand(p)
	return bb

## The biggest outer ring of a clip's result.
static func _big(parts: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	var area := 0.0
	for part in parts:
		if Geometry2D.is_polygon_clockwise(part):
			continue
		var bb := _box(part)
		if bb.get_area() > area:
			area = bb.get_area()
			best = part
	return best

## The two pours: the joint runs along x just in front of the jump form. "A" is the Ann St strip, "B" the
## rest with the core cut out; "front" is A's side of the plate (the scaffold's line).
static func _cut_pours() -> void:
	var plate := _raw("plate")
	var core := _raw("core")
	# The joint runs parallel to Ann St just in front of the jump form: our pour is the whole Ann St
	# strip of the plate, one open slab with nothing to work round, and the other crew's wraps the core.
	var zc := _box(core).end.y + float(d["jump_form"]["rig_out_m"]) + RIG_CLEAR + 0.6
	var bb := _box(plate).grow(5.0)
	var front_box := PackedVector2Array([Vector2(bb.position.x, zc), Vector2(bb.end.x, zc), Vector2(bb.end.x, bb.end.y), Vector2(bb.position.x, bb.end.y)])
	var back_box := PackedVector2Array([Vector2(bb.position.x, bb.position.y), Vector2(bb.end.x, bb.position.y), Vector2(bb.end.x, zc), Vector2(bb.position.x, zc)])
	var front := _big(Geometry2D.intersect_polygons(plate, front_box))
	var back := _big(Geometry2D.intersect_polygons(plate, back_box))
	_polys = {"plate": plate, "core": core, "front": front,
		"A": _big(Geometry2D.clip_polygons(front, core)), "B": _big(Geometry2D.clip_polygons(back, core))}
	var rig: Array = Geometry2D.offset_polygon(core, float(d["jump_form"]["rig_out_m"]), Geometry2D.JOIN_MITER)
	_polys["rig"] = rig[0] if not rig.is_empty() else core
	# where people can walk on our deck: pour A and its scaffold, a metre over the joint onto pour
	# B's formwork, never into the jump form
	var keep: Array = Geometry2D.offset_polygon(_polys["rig"], RIG_CLEAR, Geometry2D.JOIN_MITER)
	var grown: Array = Geometry2D.offset_polygon(front, 1.25, Geometry2D.JOIN_MITER)
	_polys["walk"] = _big(Geometry2D.clip_polygons(grown[0], keep[0]))
	# the walkway's centreline: round the outside of pour A, in front of the jump form at the back
	var mid: Array = Geometry2D.offset_polygon(front, WALK_OUT, Geometry2D.JOIN_MITER)
	var keep2: Array = Geometry2D.offset_polygon(_polys["rig"], RIG_CLEAR + 0.4, Geometry2D.JOIN_MITER)
	_polys["loop"] = _big(Geometry2D.clip_polygons(mid[0], keep2[0]))

## Local metres (x east, y north) -> game x/z.
static func g(p) -> Vector2:
	var x := float(p[0])
	var y := float(p[1])
	var rx := x * cos(th) - y * sin(th)
	var ry := x * sin(th) + y * cos(th)
	return Vector2(rx + off.x, -ry + off.y)

## "plate", "core", "A", "B", "front" (A with no notch), "rig" (the jump form's screens), "walk"
## (where our deck can be walked) and "loop" (the walkway's centreline), in game x/z.
static func poly(key: String) -> PackedVector2Array:
	return _polys[key]

## Game z of the Ann St boundary (the podium's street edge) at game x.
static func boundary_z(x: float) -> float:
	return _bound_a.y + _bound_k * (x - _bound_a.x)

## Game z of the plate's Ann St edge at game x (its bounding edge where x is off the plate).
static func front_z(x: float) -> float:
	var plate: PackedVector2Array = _polys["plate"]
	var best := -1e9
	var n := plate.size()
	for i in n:
		var a := plate[i]
		var b := plate[(i + 1) % n]
		if (a.x - x) * (b.x - x) <= 0.0 and absf(a.x - b.x) > 1e-4:
			best = maxf(best, lerpf(a.y, b.y, (x - a.x) / (b.x - a.x)))
	return best if best > -1e8 else _box(plate).end.y

## The masts in the lift core: ours in its Ann St half, the bot crew's in the other.
static func mast_xz(ours := true) -> Vector2:
	var core: PackedVector2Array = _polys["core"]
	var c := centroid(core)
	var bb := _box(core)
	return Vector2(c.x + (-2.6 if ours else 2.6), c.y + bb.size.y * (0.22 if ours else -0.22))

static func levels() -> Array:
	return d["levels"]

static func level_name(i: int) -> String:
	var lv: Array = d["levels"]
	return String(lv[clampi(i, 0, lv.size() - 1)]["name"])

static func is_transfer(i: int) -> bool:
	return String(d["levels"][clampi(i, 0, d["levels"].size() - 1)]["kind"]) == "transfer"

## Game y of the top of the slab poured at playable level i (0 = L6).
static func top_y(i: int) -> float:
	var lv: Array = d["levels"]
	return float(lv[clampi(i, 0, lv.size() - 1)]["top_ahd"]) - street

static func centroid(pp: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pp:
		c += p
	return c / maxf(1.0, pp.size())

## The camera's yaw for the players' pour: in from over Ann St, looking south east across the slab, so
## the street crew at the pump are in front of it and the core and its jump form stand behind.
static func cam_yaw() -> float:
	return 0.3

## Everything round the tower: the Blender model, turned and slid into the game's frame.
static func build_world(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "SpireSite"
	var scene = load(String(d["model"]["glb"]))
	if scene is PackedScene:
		var m: Node3D = scene.instantiate()
		m.rotation.y = th
		_tint(m)
		# (the model's own plant stands where the Blender stage had it: the game builds the booms, the
		# pump, the trucks and the line itself, and the Ann St planters are out for the pour)
		for nm in HIDE:
			var n := m.find_child(nm, true, false) as Node3D
			if n != null:
				n.visible = false
		root.add_child(m)
		# glTF y-up: (x, ahd, -y). A turn of th about y maps it onto the game's frame
		root.position = Vector3(off.x, -street, off.y)
	else:
		push_warning("Spire: the site model hasn't been imported yet (open the project in the editor once)")
	parent.add_child(root)
	return root

## glTF carries only flat colours, and most of the neighbours' walls are near white: under the game's
## sun they burnt out to blank white boxes. The neighbours get the game's own toon material (so the
## picture styles reach them too), no brighter than a sunlit render wall, and their walls the game's
## window grid, the way Riverlight's neighbours have. Bare ground goes paving grey, the land beyond
## the model the game's park green, rock a warm sandstone, water the river's blue-green.
const WALL_MAX := 0.74        # brightest a wall's colour may be (its value, 0..1)
static var _mats := {}

static func _tint(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat is BaseMaterial3D:
				var m2 := _game_mat(mat as BaseMaterial3D)
				if m2 != null:
					mi.set_surface_override_material(s, m2)
	for c in n.get_children():
		_tint(c)

static func _game_mat(mat: BaseMaterial3D) -> Material:
	var nm := String(mat.resource_name)
	if _mats.has(nm):
		return _mats[nm]
	var out: Material = null
	var col := mat.albedo_color
	if nm == "clay_water":
		var w := mat.duplicate() as BaseMaterial3D
		w.albedo_color = Color("3f6f78")
		w.roughness = 0.08
		w.metallic_specular = 0.9
		out = w
	elif mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or col.a < 0.99 or mat.albedo_texture != null \
			or nm.contains("glass") or nm.contains("leadlight") or nm.contains("lit_") or nm.contains("lens") or nm.begins_with("text_"):
		out = null       # (glass, lamps and painted text keep the model's own material)
	elif nm == "clay_ground" or nm == "far_land" or nm == "clay_rock":
		# (bare ground in the city blocks is paving, not lawn: the parks have their own grass)
		var g2 := mat.duplicate() as BaseMaterial3D
		g2.albedo_color = Color("7f9a5c") if nm == "far_land" else (Color("b49a76") if nm == "clay_rock" else Color("9c9a93"))
		out = g2
	elif nm == "clay_slab" or nm == "clay_slab_b" or nm == "clay_column" or nm == "clay_formwork":
		# (the podium's own structure: the game's concrete and formply, not the model's pale clay colours)
		out = F.color_mat(Color("c79a5e") if nm == "clay_formwork" else (Color("8f9291") if nm == "clay_column" else Color("a9abaa")))
	elif nm.begins_with("look_") or nm.begins_with("gen_") or nm == "clay_roof":
		# the neighbours (glTF colours are linear: the game's are sRGB)
		col = col.linear_to_srgb()
		if col.v > WALL_MAX:
			col.v = WALL_MAX
		if nm.ends_with("_wall") or nm.ends_with("_band"):
			var glass := col.darkened(0.45).lerp(Color(0.24, 0.32, 0.42), 0.4)
			var wm := F.window_mat(col, 0.0, 0.0, glass)
			wm.set_shader_parameter("cell", Vector2(2.4, 3.1))
			out = wm
		else:
			out = F.color_mat(col)
	_mats[nm] = out
	return out

# ------------------------------------------------------------------ the tower as it climbs

## One finished level of the whole plate (both pours), with the core opening, edge columns and
## the dark open frame of the storey under it.
static func floor_slab(parent: Node3D, slab_y: float, thick: float, ftf: float) -> void:
	var plate := poly("plate")
	var core := poly("core")
	var parts: Array = Geometry2D.clip_polygons(plate, core)
	var grey := F.color_mat(Color("a9abaa"))
	for part in parts:
		parent.add_child(F.prism(part, slab_y - thick, thick, grey))
	var inset: Array = Geometry2D.offset_polygon(plate, -1.2)
	if not inset.is_empty():
		parent.add_child(F.prism(inset[0], slab_y - thick - ftf + 0.02, ftf - thick - 0.04, F.color_mat(Color("3a3f45")), false))

## The core: walls from the podium roof up to `top_y`, and the jump form's screened rig round its top.
static func build_core(parent: Node3D) -> Dictionary:
	var core := poly("core")
	var walls := Node3D.new()
	walls.name = "SpireCore"
	parent.add_child(walls)
	var rig := Node3D.new()
	rig.name = "JumpForm"
	parent.add_child(rig)
	var ring := poly("rig")
	var screen := F.color_mat(Color("b4bac1"))
	var n := ring.size()
	for j in n:
		var a: Vector2 = ring[j]
		var b: Vector2 = ring[(j + 1) % n]
		var mid := (a + b) * 0.5
		var s := F.box(Vector3(a.distance_to(b), 1.0, 0.12), screen, Vector3(mid.x, 0.5, mid.y))
		s.rotation.y = -atan2(b.y - a.y, b.x - a.x)
		rig.add_child(s)
	var lab := F.label3d("JUMP FORM", 56, Color("1d2023"))
	lab.name = "Label"
	rig.add_child(lab)
	return {"walls": walls, "rig": rig, "core": core, "ring": ring}

## Sets the core's height: walls up to `top`, the rig over the top `rig_levels` storeys.
static func set_core(parts: Dictionary, bottom: float, top: float, ftf: float) -> void:
	var walls: Node3D = parts["walls"]
	for c in walls.get_children():
		c.queue_free()
	var core: PackedVector2Array = parts["core"]
	var inner: Array = Geometry2D.offset_polygon(core, -float(d["core_wall_m"]))
	var mat := F.mat("core")
	var cut: Array = Geometry2D.clip_polygons(core, inner[0]) if not inner.is_empty() else [core]
	for piece in cut:
		walls.add_child(F.prism(piece, bottom, top - bottom, mat))
	var rig: Node3D = parts["rig"]
	var rig_h := ftf * float(d["jump_form"]["rig_levels"]) + 1.5
	rig.position.y = top - rig_h + 1.5
	rig.scale.y = rig_h
	var lab: Label3D = rig.get_node("Label")
	lab.scale.y = 1.0 / rig_h
	lab.position = Vector3(centroid(core).x, 1.0 + 0.4 / rig_h, centroid(core).y)

# ------------------------------------------------------------------ the scaffold round the deck

## The perimeter scaffold, following the plate's real edge: grating, handrails, toe boards, standards
## down to the floor below and the blue edge screens. It's open at the hoist landing and at the
## ladder tower's platform (`gaps`: [x0, x1] runs of the Ann St edge left clear).
static func build_scaffold(parent: Node3D, walk_gap: float, walk_w: float, fh: float, gaps: Array, yard) -> Array:
	var parts: Array = []
	var plate := poly("plate")
	var mid: Array = Geometry2D.offset_polygon(plate, walk_gap + walk_w * 0.5, Geometry2D.JOIN_MITER)
	var outer: Array = Geometry2D.offset_polygon(plate, walk_gap + walk_w, Geometry2D.JOIN_MITER)
	if mid.is_empty() or outer.is_empty():
		return parts
	var grate := F.mat("steel")
	var rail := F.mat("orange")
	var toe := F.mat("yellow_dark")
	var c := centroid(plate)
	var m: PackedVector2Array = mid[0]
	for j in m.size():
		var a: Vector2 = m[j]
		var b: Vector2 = m[(j + 1) % m.size()]
		var at := (a + b) * 0.5
		var seg := F.box(Vector3(a.distance_to(b) + 0.25, 0.1, walk_w), grate, Vector3(at.x, -0.05, at.y))
		seg.rotation.y = -atan2(b.y - a.y, b.x - a.x)
		parent.add_child(seg)
		parts.append(seg)
	var o: PackedVector2Array = outer[0]
	var screens := Node3D.new()
	screens.name = "EdgeScreens"
	parent.add_child(screens)
	parts.append(screens)
	for j in o.size():
		var a: Vector2 = o[j]
		var b: Vector2 = o[(j + 1) % o.size()]
		# (cut the run at the gaps: only on the Ann St side, where the edge runs along x)
		var runs: Array = [[a, b]]
		if absf(b.y - a.y) < absf(b.x - a.x) * 0.3 and (a.y + b.y) * 0.5 > c.y:
			for gap in gaps:
				var next: Array = []
				for r in runs:
					next.append_array(_cut_run(r[0], r[1], float(gap[0]), float(gap[1])))
				runs = next
		for r in runs:
			var p: Vector2 = r[0]
			var q: Vector2 = r[1]
			var ln := p.distance_to(q)
			if ln < 0.2:
				continue
			var at := (p + q) * 0.5
			var ry := -atan2(q.y - p.y, q.x - p.x)
			for y in [0.55, 1.08]:
				var bar := F.box(Vector3(ln, 0.06, 0.06), rail, Vector3(at.x, y, at.y))
				bar.rotation.y = ry
				parent.add_child(bar)
				parts.append(bar)
			var tb := F.box(Vector3(ln, 0.15, 0.03), toe, Vector3(at.x, 0.075, at.y))
			tb.rotation.y = ry
			parent.add_child(tb)
			parts.append(tb)
			var n := maxi(1, int(ln / 2.0))
			for k in n + 1:
				var s := p.lerp(q, float(k) / n)
				for post in [F.box(Vector3(0.07, 1.1, 0.07), rail, Vector3(s.x, 0.55, s.y)), F.box(Vector3(0.06, fh, 0.06), grate, Vector3(s.x, -fh * 0.5, s.y))]:
					parent.add_child(post)
					parts.append(post)
			var out := (at - c).normalized() * 0.25
			var inward := Vector3(c.x - at.x, 0, c.y - at.y).normalized()
			yard.screen_line(screens, Vector3(p.x + out.x, 0, p.y + out.y), Vector3(q.x + out.x, 0, q.y + out.y), inward)
	return parts

## The parts of a..b outside x0..x1.
static func _cut_run(a: Vector2, b: Vector2, x0: float, x1: float) -> Array:
	var lo := minf(a.x, b.x)
	var hi := maxf(a.x, b.x)
	if x1 <= lo or x0 >= hi:
		return [[a, b]]
	var at := func(x: float) -> Vector2:
		return a.lerp(b, (x - a.x) / (b.x - a.x))
	var out: Array = []
	if x0 > lo:
		out.append([at.call(lo), at.call(x0)] if a.x < b.x else [at.call(x0), at.call(lo)])
	if x1 < hi:
		out.append([at.call(x1), at.call(hi)] if a.x < b.x else [at.call(hi), at.call(x1)])
	return out

## A point `s` metres round the walkway's centreline, and how far round the point nearest `q` is.
static func loop_point(s: float) -> Vector2:
	var lp := poly("loop")
	var n := lp.size()
	var per := 0.0
	for i in n:
		per += lp[i].distance_to(lp[(i + 1) % n])
	s = fposmod(s, per)
	for i in n:
		var ln := lp[i].distance_to(lp[(i + 1) % n])
		if s <= ln:
			return lp[i].lerp(lp[(i + 1) % n], s / maxf(ln, 0.001))
		s -= ln
	return lp[0]

static func loop_param(q: Vector2) -> float:
	var lp := poly("loop")
	var n := lp.size()
	var best := 1e9
	var out := 0.0
	var run := 0.0
	for i in n:
		var a := lp[i]
		var ab := lp[(i + 1) % n] - a
		var ln := ab.length()
		var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var dd := (a + ab * t).distance_to(q)
		if dd < best:
			best = dd
			out = run + t * ln
		run += ln
	return out

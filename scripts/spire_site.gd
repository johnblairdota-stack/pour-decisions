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
const CORE_CLEAR := 0.45       # m people keep off the core's walls (they walk under the jump form)

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
	# The game's ground is level at the pump: y 0 is the street's own height there, not at the gate
	# (Ann St climbs about 4 in 100 past the site).
	var scene = load(String(d["model"]["glb"]))
	if scene is PackedScene:
		var m: Node3D = scene.instantiate()
		_read_ground(m, Transform3D(Basis(Vector3.UP, th), Vector3(off.x, -street, off.y)))
		_read_podium(m, Transform3D(Basis(Vector3.UP, th), Vector3(off.x, -street, off.y)))
		m.free()
		var at0 := ground_y(PAD.x, PAD.y)
		street += at0
		for i in _hm.size():
			if _hm[i] > -1e8:
				_hm[i] -= at0
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
static func _area(pp: PackedVector2Array) -> float:
	var a := 0.0
	for i in pp.size():
		a += pp[i].cross(pp[(i + 1) % pp.size()])
	return absf(a) * 0.5

static func _cut_pours() -> void:
	var plate := _raw("plate")
	var core := _raw("core")
	# The joint runs parallel to Ann St just in front of the jump form: our pour is the whole Ann St
	# strip of the plate, one open slab with nothing to work round, and the other crew's wraps the core.
	# (John, 16 Nov: our pour is the Ann St front and both sides of the core, a U round it; the joint
	# runs along the line of the core's back wall and the other crew pours the strip behind)
	# He wants the two pours equal: the joint (parallel to Ann St) is slid to where each crew has half
	# the floor's area, no further back than the core's back wall so ours stays a U and never a ring.
	var bb := _box(plate).grow(5.0)
	var lo := _box(core).position.y
	var hi := _box(core).end.y
	var half := (_area(plate) - _area(core)) * 0.5
	for i in 24:
		var zm := (lo + hi) * 0.5
		var box := PackedVector2Array([Vector2(bb.position.x, zm), Vector2(bb.end.x, zm), Vector2(bb.end.x, bb.end.y), Vector2(bb.position.x, bb.end.y)])
		var a_m := 0.0
		for part in Geometry2D.intersect_polygons(plate, box):
			for piece in Geometry2D.clip_polygons(part, core):
				a_m += _area(piece)
		if a_m > half:
			lo = zm
		else:
			hi = zm
	var zc := (lo + hi) * 0.5
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
	# (the jump form's screens hang a storey up: people work under them, right up to the core's wall)
	var keep: Array = Geometry2D.offset_polygon(core, CORE_CLEAR, Geometry2D.JOIN_MITER)
	var grown: Array = Geometry2D.offset_polygon(front, 1.25, Geometry2D.JOIN_MITER)
	_polys["walk"] = _big(Geometry2D.clip_polygons(grown[0], keep[0]))
	# the walkway's centreline: round the outside of pour A, in front of the jump form at the back
	var mid: Array = Geometry2D.offset_polygon(front, WALK_OUT, Geometry2D.JOIN_MITER)
	var keep2: Array = Geometry2D.offset_polygon(core, CORE_CLEAR + 0.6, Geometry2D.JOIN_MITER)
	_polys["loop"] = _big(Geometry2D.clip_polygons(mid[0], keep2[0]))
	# The boom operator's beat: the scaffold along Ann St and round both ends, out and back (the
	# joint side is the other crew's deck, and the bit round the core is on our own wet slab)
	var ring: PackedVector2Array = mid[0]
	var n := ring.size()
	var first := -1
	for i in n:
		if ring[i].y < zc + 0.6 and ring[(i + 1) % n].y >= zc + 0.6:
			first = (i + 1) % n
	var beat := PackedVector2Array()
	if first >= 0:
		for i in n:
			var q := ring[(first + i) % n]
			if q.y < zc + 0.6:
				break
			beat.append(q)
	if beat.size() >= 2:
		var ret := beat.duplicate()
		ret.reverse()
		_polys["beat"] = beat + ret.slice(1, ret.size() - 1)
	else:
		_polys["beat"] = _polys["loop"]

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
		_level_street(m, m, Transform3D(Basis(Vector3.UP, th), Vector3(off.x, -street, off.y)))
		_tint(m)
		_trim(m)
		# (the model's own plant stands where the Blender stage had it: the game builds the booms, the
		# pump, the trucks and the line itself, and the Ann St planters are out for the pour)
		for nm in HIDE:
			var n := m.find_child(nm, true, false) as Node3D
			if n != null:
				n.visible = false
		root.add_child(m)
		_add_far(m)
		# glTF y-up: (x, ahd, -y). A turn of th about y maps it onto the game's frame
		root.position = Vector3(off.x, -street, off.y)
	else:
		push_warning("Spire: the site model hasn't been imported yet (open the project in the editor once)")
	parent.add_child(root)
	return root

## Howard Smith Wharves and the Story Bridge, 300-900 m off (tools/blender/spire/export_hsw_far.py): the
## render's buildings in the same frame as the site model, so they go in under it. Seen only from far off:
## no shadows.
const FAR_GLB := "res://assets/spire/hsw_far.glb"

static func _add_far(m: Node3D) -> void:
	if not ResourceLoader.exists(FAR_GLB):
		return
	var scene = load(FAR_GLB)
	if scene is PackedScene:
		var far: Node3D = scene.instantiate()
		far.name = "HSWFar"
		_tint(far)
		_no_shadow(far)
		m.add_child(far)

static func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)

# ------------------------------------------------------------------ what it costs to draw
## The ground and everything lying flat on it (roads, kerbs, markings, the painted street names), the
## far suburbs and the far trees: none of it throws a shadow anyone could see, and each was drawn again
## into the sun's shadow map for every split.
const NO_SHADOW := ["ground_", "far_", "river_water", "roads", "footpaths_kerbs", "footways", "line_marking",
	"car_park", "kerb_gutter", "streetname", "busonly", "street_white", "street_red", "street_no_stopping",
	"street_lenses", "street_lit_", "street_target_boards", "street_heads", "street_name_blades",
	"street_sign_faces", "street_art", "hsw_boardwalk", "tree_crowns_far", "palm_fronds_far", "area_flat_"]
## Small things nobody can make out from further off than this (m): the street names painted on the
## road, the bus lane words, the lamps' lenses and the signal heads.
const NEAR_ONLY := {"streetname": 70.0, "busonly": 70.0, "street_lenses": 160.0, "street_lit_": 160.0,
	"street_target_boards": 160.0, "street_sign_faces": 120.0, "street_name_blades": 120.0, "street_bins": 60.0,
	"street_bin_wheels": 60.0, "street_bollards": 90.0, "street_art": 120.0,
	"area_small_": 150.0, "area_carpark_sign_text": 60.0, "area_cathedral_noticeboard_text": 60.0, "area_sign": 120.0}

static func _trim(n: Node) -> void:
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		var nm := String(g.name)
		for pre in NO_SHADOW:
			if nm.begins_with(pre):
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for pre in NEAR_ONLY:
			if nm.begins_with(pre):
				g.visibility_range_end = float(NEAR_ONLY[pre])
				g.visibility_range_end_margin = 5.0
				g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	for c in n.get_children():
		_trim(c)

# ------------------------------------------------------------------ the street's own levels
# Ann St isn't flat: it falls along the site and has a crossfall and kerbs. The game's ground is y 0 at
# the gate, so anything that drives or walks away from the pump is put on the street's real surface.
const PAD := Vector2(21.0, 8.0)      # the pump's hopper and truck bay (line.gd HOPPER..BAY)
const HM_X0 := -90.0
const HM_Z0 := -100.0
const HM_NX := 240
const HM_NZ := 150
static var _hm := PackedFloat32Array()

static func _read_ground(model: Node3D, xf: Transform3D) -> void:
	_hm.resize(HM_NX * HM_NZ)
	_hm.fill(-1e9)
	for nm in ["roads", "footpaths_kerbs", "kerb_gutter", "footways"]:
		var mi := model.find_child(nm, true, false) as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var f: PackedVector3Array = mi.mesh.get_faces()
		for t in range(0, f.size(), 3):
			var a := xf * f[t]
			var b := xf * f[t + 1]
			var c := xf * f[t + 2]
			var x0 := maxi(0, int(floor(minf(a.x, minf(b.x, c.x)) - HM_X0)))
			var x1 := mini(HM_NX - 1, int(ceil(maxf(a.x, maxf(b.x, c.x)) - HM_X0)))
			var z0 := maxi(0, int(floor(minf(a.z, minf(b.z, c.z)) - HM_Z0)))
			var z1 := mini(HM_NZ - 1, int(ceil(maxf(a.z, maxf(b.z, c.z)) - HM_Z0)))
			if x0 > x1 or z0 > z1:
				continue
			var den := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
			if absf(den) < 1e-6:
				continue
			for iz in range(z0, z1 + 1):
				for ix in range(x0, x1 + 1):
					var px := HM_X0 + ix
					var pz := HM_Z0 + iz
					var w0 := ((b.z - c.z) * (px - c.x) + (c.x - b.x) * (pz - c.z)) / den
					var w1 := ((c.z - a.z) * (px - c.x) + (a.x - c.x) * (pz - c.z)) / den
					var w2 := 1.0 - w0 - w1
					if w0 < -0.02 or w1 < -0.02 or w2 < -0.02:
						continue
					var y := w0 * a.y + w1 * b.y + w2 * c.y
					if y > _hm[iz * HM_NX + ix]:
						_hm[iz * HM_NX + ix] = y

## The podium's slabs come out past the boundary line in places (by the stairs, 1.9 m): their real
## Ann St edge, read off the model every half metre of x.
const PODIUM_SLABS := [3.8, 7.0, 10.2, 13.4, 16.6]   # game y of the podium's slabs (L1 to L5)
const POD_X0 := -30.0
const POD_N := 140
static var _pod := PackedFloat32Array()

static func _read_podium(model: Node3D, xf: Transform3D) -> void:
	_pod.resize(POD_N)
	_pod.fill(-1e9)
	for node in model.find_children("SLAB_L0*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var f: PackedVector3Array = mi.mesh.get_faces()
		for t in range(0, f.size(), 3):
			var tri := [xf * f[t], xf * f[t + 1], xf * f[t + 2]]
			for j in 3:
				var a: Vector3 = tri[j]
				var b: Vector3 = tri[(j + 1) % 3]
				if absf(a.x - b.x) < 1e-4:
					continue
				var i0 := maxi(0, int(ceil((minf(a.x, b.x) - POD_X0) * 2.0)))
				var i1 := mini(POD_N - 1, int(floor((maxf(a.x, b.x) - POD_X0) * 2.0)))
				for i in range(i0, i1 + 1):
					var x := POD_X0 + i * 0.5
					var z := lerpf(a.z, b.z, (x - a.x) / (b.x - a.x))
					if z < 8.0 and z > _pod[i]:
						_pod[i] = z

## Game z of the podium's real Ann St face over game x0..x1 (the boundary line where the model has none).
static func podium_z(x0: float, x1: float) -> float:
	var best := -1e9
	for i in range(maxi(0, int(floor((x0 - POD_X0) * 2.0))), mini(POD_N - 1, int(ceil((x1 - POD_X0) * 2.0))) + 1):
		if i < _pod.size():
			best = maxf(best, _pod[i])
	return best if best > -1e8 else maxf(boundary_z(x0), boundary_z(x1))

## The podium's Ann St face as a building under way reads from the pour camera: a pale edge band on
## every slab and the storeys between them dark and open (car park decks with nothing in them yet).
## `brick`: the folded brick skin started from the bottom, up to that many storeys. `scaffold`: the
## bricklayers' scaffold stands on the gantry up to the storey being laid, with shade mesh on that
## storey. `gaps`: [x0, x1] runs the scaffold leaves clear (hoist, stairs, riser).
## Call it again as the job goes on: it clears what it built before.
static func build_podium_face(parent: Node3D, brick := 0, scaffold := false, gaps: Array = []) -> void:
	for c in parent.get_children():
		if String(c.name).begins_with("PodiumFace"):
			parent.remove_child(c)
			c.queue_free()
	if _pod.is_empty():
		return
	var bands: Array[Transform3D] = []
	var backs: Array[Transform3D] = []
	var skins: Array[Transform3D] = []
	var tubes: Array[Transform3D] = []
	var planks: Array[Transform3D] = []
	var mesh: Array[Transform3D] = []
	var ys: Array = [0.0] + PODIUM_SLABS
	var top_storey := mini(brick + 1, ys.size() - 2)
	for i in POD_N - 1:
		var z0 := _pod[i]
		var z1 := _pod[i + 1]
		if z0 < -1e8 or z1 < -1e8 or absf(z1 - z0) > 1.2:
			continue
		var x := POD_X0 + (i + 0.5) * 0.5
		var z := (z0 + z1) * 0.5
		var yaw := -atan2(z1 - z0, 0.5)
		var len := Vector2(0.5, z1 - z0).length() + 0.02
		var rot := Basis(Vector3.UP, yaw)
		var clear := scaffold
		for gp in gaps:
			if x > gp[0] and x < gp[1]:
				clear = false
		for lv in range(1, ys.size()):
			var y: float = ys[lv]
			bands.append(Transform3D(rot * Basis.from_scale(Vector3(len, 0.42, 0.12)), Vector3(x, y - 0.1, z + 0.05)))
			if lv >= 2:
				var y0: float = ys[lv - 1]
				if lv - 1 <= brick:
					# (folded brickwork: the face steps in and out a brick's width every 2 m)
					var fold := 0.12 if int(floor(x / 2.0)) % 2 == 0 else 0.0
					skins.append(Transform3D(rot * Basis.from_scale(Vector3(len, y - y0 - 0.5, 0.12)), Vector3(x, (y0 + y) * 0.5 - 0.05, z - 0.02 + fold)))
				else:
					backs.append(Transform3D(rot * Basis.from_scale(Vector3(len, y - y0 - 0.4, 0.1)), Vector3(x, (y0 + y) * 0.5 - 0.1, z - 1.1)))
				if clear and lv - 1 <= top_storey:
					planks.append(Transform3D(rot * Basis.from_scale(Vector3(len, 0.05, 0.75)), Vector3(x, y0 + 0.12, z + 0.62)))
					for hy in [1.1, 2.1]:
						tubes.append(Transform3D(rot * Basis.from_scale(Vector3(len, 0.05, 0.05)), Vector3(x, y0 + 0.12 + hy, z + 1.0)))
					if i % 4 == 0:
						for dz in [0.24, 1.0]:
							tubes.append(Transform3D(Basis.from_scale(Vector3(0.06, y - y0, 0.06)), Vector3(x, (y0 + y) * 0.5 + 0.12, z + dz)))
						tubes.append(Transform3D(Basis.from_scale(Vector3(0.05, 0.05, 0.76)), Vector3(x, y0 + 0.07, z + 0.62)))
					if lv - 1 == top_storey and brick < ys.size() - 2:
						mesh.append(Transform3D(rot * Basis.from_scale(Vector3(len, y - y0 + 0.9, 0.02)), Vector3(x, (y0 + y) * 0.5 + 0.55, z + 1.05)))
	var net := StandardMaterial3D.new()
	net.albedo_color = Color(0.16, 0.42, 0.36, 0.5)
	net.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	net.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sets := [[bands, F.color_mat(Color("e6e8e3"))], [backs, F.color_mat(Color("343a42"))],
		[skins, F.color_mat(Color("a8553a"))], [tubes, F.color_mat(Color("9aa3ad"))],
		[planks, F.color_mat(Color("c9a45c"))], [mesh, net]]
	for st in sets:
		var xf: Array = st[0]
		if xf.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		bm.material = st[1]
		mm.mesh = bm
		mm.instance_count = xf.size()
		for k in xf.size():
			mm.set_instance_transform(k, xf[k])
		var mi := MultiMeshInstance3D.new()
		mi.name = "PodiumFace"
		mi.multimesh = mm
		if st[1] == net:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi, true)

## How far the podium's brick has got by pour `k` (0 = level 6): [storeys laid, scaffold up?].
## Bare for the first pours, a storey every three floors, done and stripped by level 20.
static func podium_stage(k: int) -> Array:
	return [clampi(k / 3, 0, PODIUM_SLABS.size() - 1), k >= 2 and k < 14]

## Game z of whatever's furthest out at game x: the boundary line or the podium's own face.
static func face_z(x: float) -> float:
	return maxf(boundary_z(x), podium_z(x - 0.5, x + 0.5))

## The street's surface (game y) at game x/z; 0 where the model has no road or footpath.
static func ground_y(x: float, z: float) -> float:
	if _hm.is_empty():
		return 0.0
	var fx := clampf(x - HM_X0, 0.0, HM_NX - 1.001)
	var fz := clampf(z - HM_Z0, 0.0, HM_NZ - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var i := iz * HM_NX + ix
	var h00 := _hm[i]
	var h10 := _hm[i + 1]
	var h01 := _hm[i + HM_NX]
	var h11 := _hm[i + HM_NX + 1]
	if h00 < -1e8 or h10 < -1e8 or h01 < -1e8 or h11 < -1e8:
		var best := maxf(maxf(h00, h10), maxf(h01, h11))
		return best if best > -1e8 else 0.0
	var u := fx - ix
	var v := fz - iz
	return lerpf(lerpf(h00, h10, u), lerpf(h01, h11, u), v)

# Ann St climbs about 4 in 100 past the site, and the game's street works (pump, racking, hoist, the
# people on the ground) stand on level ground at y 0. So the street is levelled in front of the site,
# the way a pump pad's packed level: the road, kerbs, footpaths, paint and everything standing on them
# come to y 0 between LEVEL_X0 and LEVEL_X1 and ease back to the street's own fall over LEVEL_EASE.
const LEVEL_X0 := -12.0
const LEVEL_X1 := 34.0
const LEVEL_EASE := 16.0
const GROUND_KIT := ["ground_", "roads", "footpaths", "footways", "line_marking", "car_park", "kerb_", "streetname",
	"busonly", "hoarding", "bus_", "street_", "tree_", "palm_", "area_flat_", "area_kit_", "area_small_", "area_sign"]

static func _level_w(x: float) -> float:
	return smoothstep(LEVEL_X0 - LEVEL_EASE, LEVEL_X0, x) * (1.0 - smoothstep(LEVEL_X1, LEVEL_X1 + LEVEL_EASE, x))

static func _level_street(n: Node, model: Node3D, xf: Transform3D) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		var kit := false
		for pre in GROUND_KIT:
			if nm.begins_with(pre):
				kit = true
		if kit and mi.mesh != null:
			# (this node's own place in the model: the model isn't in the tree yet)
			var rel := Transform3D.IDENTITY
			var q: Node = mi
			while q != model and q is Node3D:
				rel = (q as Node3D).transform * rel
				q = q.get_parent()
			var to_game := xf * rel
			var up := rel.basis.inverse() * Vector3.UP
			var box: AABB = to_game * mi.mesh.get_aabb()
			if box.end.x > LEVEL_X0 - LEVEL_EASE and box.position.x < LEVEL_X1 + LEVEL_EASE:
				var out := ArrayMesh.new()
				for si in mi.mesh.get_surface_count():
					var arr: Array = mi.mesh.surface_get_arrays(si)
					var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
					for i in vv.size():
						var gp := to_game * vv[i]
						var w := _level_w(gp.x)
						if w > 0.0:
							vv[i] -= up * (ground_y(gp.x, gp.z) * w)
					arr[Mesh.ARRAY_VERTEX] = vv
					out.add_surface_from_arrays((mi.mesh as ArrayMesh).surface_get_primitive_type(si) if mi.mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES, arr)
					out.surface_set_material(si, mi.mesh.surface_get_material(si))
				mi.mesh = out
	for c in n.get_children():
		_level_street(c, model, xf)

## How far up a truck (or anyone) at game x/z stands: 0 on the levelled street in front of the site,
## the street's own level beyond it.
static func road_lift(x: float, z: float) -> float:
	return ground_y(x, z) * (1.0 - _level_w(x))

## glTF carries only flat colours, and most of the neighbours' walls are near white: under the game's
## sun they burnt out to blank white boxes. The neighbours get the game's own toon material (so the
## picture styles reach them too), no brighter than a sunlit render wall, and their walls the game's
## window grid, the way Riverlight's neighbours have. Bare ground goes paving grey, the land beyond
## the model the game's park green, rock a warm sandstone, water the river's blue-green.
const RIVER_COL := Color("62593c")      # (the Brisbane River's brown)
const WALL_MAX := 0.74       # brightest a wall's colour may be (its value, 0..1)
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

## The neighbours' materials: they're cut away where they hide someone working down on the street.
static var _cut_mats: Array = []
static var _cut_sent: Array = []

## `ps`: up to 6 work points (world xyz, circle radius in m) the neighbours mustn't hide.
static func street_cut(ps: Array) -> void:
	var n := ps.size()
	ps = ps.duplicate()
	while ps.size() < 6:
		ps.append(Vector4.ZERO)
	if [n, ps] == _cut_sent:
		return
	_cut_sent = [n, ps]
	for m in _cut_mats:
		(m as ShaderMaterial).set_shader_parameter("cut_n", n)
		(m as ShaderMaterial).set_shader_parameter("cut_p", ps)

static func _game_mat(mat: BaseMaterial3D) -> Material:
	var nm := String(mat.resource_name)
	if _mats.has(nm):
		return _mats[nm]
	var out: Material = null
	var col := mat.albedo_color
	if nm == "clay_water":
		# (the render's muddy brown-green Brisbane River, a little deeper so it doesn't read as sand, with
		# Riverlight's ripples and glints to say water)
		var w := ShaderMaterial.new()
		w.shader = preload("res://shaders/river.gdshader")
		w.set_shader_parameter("water", RIVER_COL)
		w.set_shader_parameter("gloss", 0.4)
		w.set_shader_parameter("rough", 0.3)
		out = w
	elif mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or col.a < 0.99 or mat.albedo_texture != null \
			or nm.contains("glass") or nm.contains("leadlight") or nm.contains("lit_") or nm.contains("lens") or nm.begins_with("text_"):
		out = null       # (glass, lamps and painted text keep the model's own material)
	elif nm == "story_bridge_steel" or nm == "story_bridge_underside" or nm == "story_bridge_render":
		# (the Story Bridge from the river: mid grey steel that goes near black underneath, on weathered
		# concrete piers. The model's own colours come out pale steel on white blocks.)
		var b2 := mat.duplicate() as BaseMaterial3D
		b2.albedo_color = Color("4b504f") if nm == "story_bridge_steel" else (Color("1b1e1e") if nm == "story_bridge_underside" else Color("9a9488"))
		b2.metallic = 0.0
		b2.roughness = 0.9
		out = b2
	elif nm == "clay_ground" or nm == "far_land" or nm == "clay_rock":
		# (bare ground in the city blocks is paving, not lawn: the parks have their own grass)
		var g2 := mat.duplicate() as BaseMaterial3D
		g2.albedo_color = Color("7f9a5c") if nm == "far_land" else (Color("b49a76") if nm == "clay_rock" else Color("9c9a93"))
		out = g2
	elif nm == "clay_slab" or nm == "clay_slab_b" or nm == "clay_column" or nm == "clay_formwork":
		# (the podium's own structure: the game's concrete and formply, not the model's pale clay colours)
		out = F.color_mat(Color("c79a5e") if nm == "clay_formwork" else (Color("5f666e") if nm == "clay_column" else Color("c9ccc8")))
	elif nm.begins_with("area_bldg_"):
		# (the Spire area's parts of the neighbours: Mantra's blue stripes and balconies, roof plant, the
		# Customs House portico: plain, and cut away with the walls they're on)
		col = col.srgb_to_linear()       # (as below: the look's own colour)
		if col.v > WALL_MAX:
			col.v = WALL_MAX
		var am := F.window_mat(col, 0.0, 0.0, col)
		am.set_shader_parameter("cell", Vector2(9999.0, 9999.0))
		am.set_shader_parameter("cut", true)
		_cut_mats.append(am)
		out = am
	elif nm.begins_with("look_") or nm.begins_with("gen_") or nm == "clay_roof":
		# the neighbours. The Blender scene writes each look's hex colour straight in as a linear value,
		# and the glTF import brightens that once more for the screen: taking the brightening back off
		# gives the colour the look was written with (Customs House's sandstone, not off-white).
		col = col.srgb_to_linear()
		if col.v > WALL_MAX:
			col.v = WALL_MAX
		var looks: Dictionary = d.get("looks", {})
		if looks.has(nm):
			# (the building's own facade recipe from the Blender scene: its glass, and its window grid as
			# a curtain wall, strips, punched windows or balcony doors)
			var lk: Dictionary = looks[nm]
			var gl: Array = lk["glass"]
			var glass := Color(float(gl[0]), float(gl[1]), float(gl[2])).lightened(0.1)     # (dark against the pale walls, as the render's glass reads)
			var wm := F.window_mat(col, 0.0, 0.0, glass)
			var bay := float(lk["bay"])
			var side := clampf(0.5 - 0.5 * float(lk["win"]) / bay, 0.03, 0.45)
			wm.set_shader_parameter("cell", Vector2(bay, float(lk["floor"])))
			wm.set_shader_parameter("win_rect", Vector4(side, 1.0 - side, float(lk["sill"]), float(lk["head"])))
			wm.set_shader_parameter("diag", bool(lk.get("diag", false)))
			wm.set_shader_parameter("roof", true)
			out = wm
		elif not looks.is_empty() and nm.ends_with("_band"):
			# (slab edges and balcony fronts: plain bands, as the render has them)
			var bm := F.window_mat(col, 0.0, 0.0, col)
			bm.set_shader_parameter("cell", Vector2(9999.0, 9999.0))
			bm.set_shader_parameter("roof", true)
			out = bm
		elif nm.ends_with("_wall") or nm.ends_with("_band"):
			var glass := col.darkened(0.45).lerp(Color(0.24, 0.32, 0.42), 0.4)
			var wm := F.window_mat(col, 0.0, 0.0, glass)
			wm.set_shader_parameter("cell", Vector2(2.4, 3.1))
			wm.set_shader_parameter("roof", true)
			out = wm
		elif nm.ends_with("_roof"):
			# (roofs fill the foreground from the pour camera: pavers, plant pads, walkways)
			var rm := F.window_mat(col, 0.0, 0.0, col)
			rm.set_shader_parameter("cell", Vector2(9999.0, 9999.0))
			rm.set_shader_parameter("roof", true)
			out = rm
		else:
			# (plain parts of a neighbour: the same shader with no windows, so it can be cut away too)
			var pm := F.window_mat(col, 0.0, 0.0, col)
			pm.set_shader_parameter("cell", Vector2(9999.0, 9999.0))
			out = pm
		(out as ShaderMaterial).set_shader_parameter("cut", true)
		_cut_mats.append(out)
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
	# (the rig's built one unit tall and stretched to its real height by set_core: heights here are
	# shares of that)
	var rig_h := float(d["tower_ftf_m"]) * float(d["jump_form"]["rig_levels"]) + 1.5
	var u := 1.0 / rig_h
	var screens := [F.color_mat(Color("d3d7da")), F.color_mat(Color("c2c7cc"))]
	var frame := F.color_mat(Color("39414f"))
	var rail := F.mat("yellow_dark")
	var deck_y := 1.0 - 1.3 * u            # the top working deck: the screens stand 1.3 m over it
	var n := ring.size()
	for j in n:
		var a: Vector2 = ring[j]
		var b: Vector2 = ring[(j + 1) % n]
		var len := a.distance_to(b)
		var edge := Node3D.new()
		edge.position = Vector3((a.x + b.x) * 0.5, 0, (a.y + b.y) * 0.5)
		edge.rotation.y = -atan2(b.y - a.y, b.x - a.x)
		rig.add_child(edge)
		# Screen panels between steel posts, about 2.4 m wide
		var cells := maxi(1, int(round(len / 2.4)))
		var w := len / cells
		for c in cells:
			edge.add_child(F.box(Vector3(w - 0.08, 1.0, 0.1), screens[(c + j) % 2], Vector3(-len * 0.5 + (c + 0.5) * w, 0.5, 0)))
		for c in cells + 1:
			edge.add_child(F.box(Vector3(0.14, 1.0 + 0.3 * u, 0.2), frame, Vector3(-len * 0.5 + c * w, 0.5 - 0.15 * u, 0.02)))
		# The deck edges showing through as dark bands with a yellow kick board, a handrail along the
		# top, and the open trailing platform hung underneath
		for dk in [deck_y, deck_y - 2.9 * u, deck_y - 5.8 * u]:
			if dk > 0.02:
				edge.add_child(F.box(Vector3(len + 0.2, 0.22 * u, 0.22), frame, Vector3(0, dk, 0.03)))
				edge.add_child(F.box(Vector3(len + 0.2, 0.12 * u, 0.24), rail, Vector3(0, dk + 0.2 * u, 0.03)))
		edge.add_child(F.box(Vector3(len + 0.2, 0.1 * u, 0.16), rail, Vector3(0, 1.0 + 0.05 * u, 0)))
		edge.add_child(F.box(Vector3(len + 0.2, 0.16 * u, 0.9), frame, Vector3(0, -0.25 * u, -0.4)))
		edge.add_child(F.box(Vector3(len + 0.2, 0.07 * u, 0.07), rail, Vector3(0, 0.3 * u, 0.02)))
		edge.add_child(F.box(Vector3(len + 0.2, 0.07 * u, 0.07), rail, Vector3(0, 0.6 * u, 0.02)))
	# The top deck (formply), and on it the things that say "jump form" from above: the wall steel
	# standing up out of the pour, the hydraulic pack, the crew's toilet and the stair hatch
	rig.add_child(F.prism(ring, deck_y - 0.1 * u, 0.1 * u, F.color_mat(Color("c79a5e"))))
	var bars: Array[Transform3D] = []
	var cn := core.size()
	for j in cn:
		var a: Vector2 = core[j]
		var b: Vector2 = core[(j + 1) % cn]
		var steps := maxi(1, int(a.distance_to(b) / 0.45))
		for k in steps:
			var q := a.lerp(b, (k + 0.5) / steps)
			var inw := (centroid(core) - q).normalized() * 0.15
			bars.append(Transform3D(Basis.from_scale(Vector3(0.05, 2.1 * u, 0.05)), Vector3(q.x + inw.x, deck_y + 1.05 * u, q.y + inw.y)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	bm.material = F.color_mat(Color("9a4a2c"))
	mm.mesh = bm
	mm.instance_count = bars.size()
	for k in bars.size():
		mm.set_instance_transform(k, bars[k])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	rig.add_child(mi)
	var cc := centroid(core)
	var bbx := _box(core)
	# (the wall pour's dark slot inside the steel, so the core reads as walls with shafts between)
	var inner: Array = Geometry2D.offset_polygon(core, -0.45)
	if not inner.is_empty():
		rig.add_child(F.prism(inner[0], deck_y, 0.03 * u, F.color_mat(Color("b88a52"))))
	rig.add_child(F.box(Vector3(1.1, 2.2 * u, 1.1), F.color_mat(Color("2f7fd0")), Vector3(bbx.position.x - 0.55, deck_y + 1.1 * u, cc.y + 0.9)))
	rig.add_child(F.box(Vector3(1.2, 0.08 * u, 1.2), F.color_mat(Color("f4f7fa")), Vector3(bbx.position.x - 0.55, deck_y + 2.24 * u, cc.y + 0.9)))
	rig.add_child(F.box(Vector3(1.5, 1.0 * u, 0.9), F.color_mat(Color("e0352b")), Vector3(bbx.end.x + 0.55, deck_y + 0.5 * u, cc.y - 0.8)))
	rig.add_child(F.box(Vector3(1.0, 0.05 * u, 1.0), frame, Vector3(bbx.end.x + 0.5, deck_y + 0.03 * u, cc.y + 1.2)))
	var lab := F.label3d("JUMP FORM", 56, Color("1d2023"))
	lab.name = "Label"
	rig.add_child(lab)
	F.bake(rig)
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
	# (all of it stands still on the rig: it's merged into a few meshes once it's built, F.bake)
	var scaf := Node3D.new()
	scaf.name = "Scaffold"
	parent.add_child(scaf)
	parts.append(scaf)
	var m: PackedVector2Array = mid[0]
	for j in m.size():
		var a: Vector2 = m[j]
		var b: Vector2 = m[(j + 1) % m.size()]
		var at := (a + b) * 0.5
		var seg := F.box(Vector3(a.distance_to(b) + 0.25, 0.1, walk_w), grate, Vector3(at.x, -0.05, at.y))
		seg.rotation.y = -atan2(b.y - a.y, b.x - a.x)
		scaf.add_child(seg)
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
				scaf.add_child(bar)
			var tb := F.box(Vector3(ln, 0.15, 0.03), toe, Vector3(at.x, 0.075, at.y))
			tb.rotation.y = ry
			scaf.add_child(tb)
			var n := maxi(1, int(ln / 2.0))
			for k in n + 1:
				var s := p.lerp(q, float(k) / n)
				for post in [F.box(Vector3(0.07, 1.1, 0.07), rail, Vector3(s.x, 0.55, s.y)), F.box(Vector3(0.06, fh, 0.06), grate, Vector3(s.x, -fh * 0.5, s.y))]:
					scaf.add_child(post)
			var out := (at - c).normalized() * 0.25
			var inward := Vector3(c.x - at.x, 0, c.y - at.y).normalized()
			yard.screen_line(screens, Vector3(p.x + out.x, 0, p.y + out.y), Vector3(q.x + out.x, 0, q.y + out.y), inward)
	F.bake(scaf)
	F.bake(screens)
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
	var lp := poly("beat")
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
	var lp := poly("beat")
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

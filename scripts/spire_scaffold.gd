extends RefCounted
## Spire's perimeter scaffold, built the way a hung scaffold goes round a tower's working deck:
## needle beams cantilevered off the slab two floors down, standards in pairs every bay, ledgers
## and transoms at each lift, planked platforms level with each floor, guardrail, mid rail and toe
## board on the outside, face bracing every fourth bay, ties back to the slab edges, and containment
## mesh on the outside face from the bottom lift to 2 m above the deck (the Safe Work Australia
## formwork guide's "at least 2 metres above the working surface").
##
## Nobody plays the scaffolder yet, but it's laid out so one can: `bays` is the table of every bay
## (where it is, which lift group it's in), `STEPS` is the real order a bay goes up in, and the top
## lift (everything above the deck) is built in groups that `raise()` stands up one after another
## as the deck jumps a floor.

const F := preload("res://scripts/factory.gd")
const SpireSite := preload("res://scripts/spire_site.gd")
const MESH := preload("res://shaders/scaffold_mesh.gdshader")

const BAY := 2.4          # m, the longest bay (standard to standard along the face)
const TOP := 2.0          # m the outside standards and the mesh stand above the deck
const RAIL := 1.0         # m, guardrail above each platform; the mid rail's at half that
const TOE := 0.15         # m, toe board
const FLOORS_DOWN := 2    # the platforms under the deck's: one a floor, down to the needles
const TUBE := 0.05        # m, standards, ledgers, transoms (48.3 mm tube)
const GROUP := 4          # bays in one top-lift group (what a pair of scaffolders does in one go)
const BRACE_EVERY := 4    # a face brace every this many bays
const NEEDLE_IN := 2.4    # m the needle beams run back in over the slab

## The order a bay goes up in on site (for the scaffolder's job, when there is one).
const STEPS := ["needles", "standards", "ledgers", "transoms", "planks", "guardrails", "toe_boards", "braces", "ties", "mesh"]

## Every bay: {"a", "b": Vector2 (outside face, rig x/z), "in": Vector2 (unit, towards the slab),
## "group": int (its top-lift group), "run": int}.
static var bays: Array = []
static var _tops: Array = []      # the top-lift groups, in the order they go up
static var mesh_mats: Array = []  # the mesh's materials (main gives them the see-through circle)

## Builds it on `parent` (the rig: y 0 is the deck's top). `gaps`: [x0, x1] runs of the Ann St
## edge left open (the hoist landing, the ladder tower's platform). Returns the nodes it made.
static func build(parent: Node3D, walk_gap: float, walk_w: float, fh: float, gaps: Array) -> Array:
	bays = []
	_tops = []
	var parts: Array = []
	var plate := SpireSite.poly("plate")
	var mid: Array = Geometry2D.offset_polygon(plate, walk_gap + walk_w * 0.5, Geometry2D.JOIN_MITER)
	var outer: Array = Geometry2D.offset_polygon(plate, walk_gap + walk_w, Geometry2D.JOIN_MITER)
	if mid.is_empty() or outer.is_empty():
		return parts
	var galv := F.mat("steel")
	var rail := F.mat("orange")
	var toe := F.mat("yellow_dark")
	var tie := F.mat("yellow")
	var needle := F.color_mat(Color("5d6166"))
	var plank := F.color_mat(Color("b9bdc1"))
	var skirt := _mesh_mat(0.8)
	var veil := _mesh_mat(0.5)
	mesh_mats = [skirt, veil]
	var c := SpireSite.centroid(plate)
	var bottom := -fh * FLOORS_DOWN
	var lifts: Array = []
	for i in FLOORS_DOWN + 1:
		lifts.append(-fh * i)

	var scaf := Node3D.new()
	scaf.name = "Scaffold"
	parent.add_child(scaf)
	parts.append(scaf)
	var top := Node3D.new()
	top.name = "ScaffoldTop"
	parent.add_child(top)
	parts.append(top)

	# The deck-level platform, all the way round (it carries on across the gaps)
	var m: PackedVector2Array = mid[0]
	for j in m.size():
		var a: Vector2 = m[j]
		var b: Vector2 = m[(j + 1) % m.size()]
		var at := (a + b) * 0.5
		var seg := F.box(Vector3(a.distance_to(b) + 0.25, 0.1, walk_w), galv, Vector3(at.x, -0.05, at.y))
		seg.rotation.y = -atan2(b.y - a.y, b.x - a.x)
		scaf.add_child(seg)

	var o: PackedVector2Array = outer[0]
	var run_i := 0
	var bay_i := 0
	for j in o.size():
		var ea: Vector2 = o[j]
		var eb: Vector2 = o[(j + 1) % o.size()]
		if ea.distance_to(eb) < 0.2:
			continue
		var along := (eb - ea).normalized()
		var inw := Vector2(-along.y, along.x)
		if not Geometry2D.is_point_in_polygon((ea + eb) * 0.5 + inw * 0.2, o):
			inw = -inw
		# (cut the run at the gaps: only on the Ann St side, where the edge runs along x)
		var runs: Array = [[ea, eb]]
		if absf(eb.y - ea.y) < absf(eb.x - ea.x) * 0.3 and (ea.y + eb.y) * 0.5 > c.y:
			for gap in gaps:
				var next: Array = []
				for r in runs:
					next.append_array(SpireSite._cut_run(r[0], r[1], float(gap[0]), float(gap[1])))
				runs = next
		for r in runs:
			var p: Vector2 = r[0]
			var q: Vector2 = r[1]
			var ln := p.distance_to(q)
			if ln < 0.2:
				continue
			var n := maxi(1, ceili(ln / BAY))
			var ry := -atan2(q.y - p.y, q.x - p.x)
			var grp: Node3D = null
			for k in n + 1:
				var s := p.lerp(q, float(k) / n)
				var si := s + inw * walk_w
				if k < n and k % GROUP == 0:
					grp = Node3D.new()
					grp.name = "Lift%d" % _tops.size()
					top.add_child(grp)
					_tops.append(grp)
				# Standards: the pair under the deck, and the outside one on up past it
				scaf.add_child(F.box(Vector3(TUBE, -bottom, TUBE), galv, Vector3(s.x, bottom * 0.5, s.y)))
				scaf.add_child(F.box(Vector3(TUBE, -bottom + 0.1, TUBE), galv, Vector3(si.x, bottom * 0.5 + 0.05, si.y)))
				grp.add_child(F.box(Vector3(TUBE, TOP + 0.1, TUBE), galv, Vector3(s.x, (TOP + 0.1) * 0.5, s.y)))
				# The needle it stands on, back in over the slab two floors down
				var n0 := s - inw * 0.25
				var n1 := s + inw * (walk_w + walk_gap + NEEDLE_IN)
				scaf.add_child(F.beam(Vector3(n0.x, bottom - 0.1, n0.y), Vector3(n1.x, bottom - 0.1, n1.y), 0.16, needle))
				for y in lifts:
					# (transoms under each platform; a tie back to the slab edge every other pair)
					scaf.add_child(F.beam(Vector3(s.x, y - 0.13, s.y), Vector3(si.x, y - 0.13, si.y), TUBE, galv))
					if k % 2 == 0 and y < 0.0:
						var t1 := si + inw * (walk_gap + 0.35)
						scaf.add_child(F.beam(Vector3(si.x, y + 0.3, si.y), Vector3(t1.x, y + 0.3, t1.y), TUBE, tie))
				if k == n:
					continue
				var s2 := p.lerp(q, float(k + 1) / n)
				var bl := s.distance_to(s2)
				var at := (s + s2) * 0.5
				var ati := at + inw * walk_w
				bays.append({"a": s, "b": s2, "in": inw, "group": _tops.size() - 1, "run": run_i})
				for y in lifts:
					# (ledgers both faces, guardrail, mid rail and toe board on the outside)
					for led in [at, ati]:
						_bar(scaf, Vector3(bl, TUBE, TUBE), galv, Vector3(led.x, y - 0.08, led.y), ry)
					for h in [RAIL * 0.5, RAIL]:
						_bar(scaf, Vector3(bl, 0.06, 0.06), rail if y == 0.0 else galv, Vector3(at.x, y + h, at.y), ry)
					_bar(scaf, Vector3(bl, TOE, 0.03), toe, Vector3(at.x, y + TOE * 0.5, at.y), ry)
					if y < 0.0:
						var pm := at + inw * walk_w * 0.5
						_bar(scaf, Vector3(bl, 0.05, walk_w - 0.1), plank, Vector3(pm.x, y - 0.025, pm.y), ry)
					if bay_i % BRACE_EVERY == 0 and y < 0.0:
						scaf.add_child(F.beam(Vector3(s.x, y, s.y), Vector3(s2.x, y + fh, s2.y), TUBE, galv))
				# The mesh on the outside face: a closer weave below the deck, lighter above it so
				# the pour's still seen through the near side
				var mo := at - inw * 0.06
				_bar(scaf, Vector3(bl, -bottom, 0.006), skirt, Vector3(mo.x, bottom * 0.5, mo.y), ry, false)
				_bar(grp, Vector3(bl, TOP, 0.006), veil, Vector3(mo.x, TOP * 0.5, mo.y), ry, false)
				# The top lift's own ledger, and a brace with the rest
				_bar(grp, Vector3(bl, TUBE, TUBE), galv, Vector3(at.x, TOP, at.y), ry)
				if bay_i % BRACE_EVERY == 0:
					grp.add_child(F.beam(Vector3(s.x, 0.0, s.y), Vector3(s2.x, TOP, s2.y), TUBE, galv))
				bay_i += 1
			run_i += 1
	F.bake(scaf)
	for g in _tops:
		F.bake(g)
	return parts

## Stands the top lift up round the deck: `u` 0 (none of it) to 1 (all of it), group by group in
## the order the scaffolders work round.
static func raise(u: float) -> void:
	var n := _tops.size()
	for i in n:
		if is_instance_valid(_tops[i]):
			(_tops[i] as Node3D).visible = u >= 1.0 or float(i) < u * n

## The bay nearest a point (rig x/z), or -1.
static func bay_near(at: Vector2) -> int:
	var best := -1
	var bd := INF
	for i in bays.size():
		var d: float = ((bays[i]["a"] + bays[i]["b"]) * 0.5).distance_squared_to(at)
		if d < bd:
			bd = d
			best = i
	return best

static func _bar(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, ry: float, shadows := true) -> void:
	var b := F.box(size, mat, pos, shadows)
	b.rotation.y = ry
	parent.add_child(b)

static func _mesh_mat(cover: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = MESH
	m.set_shader_parameter("cover", cover)
	return m

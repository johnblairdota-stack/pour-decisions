extends Node3D
## What happens on Spire between one pour and the next, shown as it's done on the job (nobody plays
## these trades yet, but each stage is its own step so they can be):
##
##   cages   the steel fixers land a prebuilt cage for every column, craned in
##   forms   the formworkers close a form round each cage and brace it with push-pull props
##   pour    the columns are poured, a lift at a time
##   strip   the forms come off
##   props   the formworkers stand the props, set bearers over them and joists over those (450 mm
##           apart), and the formply goes on from the edge in
##
## One of these hangs on each storey (main.floor_nodes[k]: y 0 is the slab it stands on). Once the
## deck over it is poured the props come out and back-props stay for two more floors; the columns stay.
##
## Sizes are trade practice, not from a drawing of Spire: blade columns 1.2 x 0.3 m about 6 m apart
## round the edge with a ring inside, props 1.5 m apart both ways, back-props at every other one.

const F := preload("res://scripts/factory.gd")
const SpireSite := preload("res://scripts/spire_site.gd")

const TIME := 9.0            # s, the whole cycle (main's "columns" phase on Spire)
const COL_L := 1.2           # blade column: along the edge, and through
const COL_T := 0.3
const COL_STEP := 6.2        # m between columns round the edge
const COL_IN := 0.8          # m in from the slab edge to a column's middle
const RING_IN := 8.0         # the inside ring: this far in from the edge
const PROP_STEP := 1.5       # m between props, both ways
const JOIST_STEP := 0.45     # m between joists
const BANDS := 8             # the deck's props go up in this many strips
const BACK_FLOORS := 2       # floors under the deck that keep back-props

## The stages: key, where it starts and ends in the cycle (0..1), the trade, what the TV says.
const STAGES := [
	["cages", 0.00, 0.18, "steel", "Steel fixers · Column cages craned in"],
	["forms", 0.18, 0.36, "form", "Formworkers · Column forms on, braced"],
	["pour", 0.36, 0.56, "concrete", "Concreters · Columns poured"],
	["strip", 0.56, 0.68, "form", "Formworkers · Column forms stripped"],
	["props", 0.68, 1.00, "form", "Formworkers · Props, bearers, joists"],
]

static var _cycles: Array = []     # every storey's, oldest first
static var _cols: Array = []       # the column plan: [Vector2 at, float yaw]

var fh := 2.9
var age := 0                       # 0 the storey being built; 1 the one under it; ...
var done := false
var _built := false
var _cages: Array = []
var _forms: Array = []
var _fills: Array = []
var _bands: Array = []
var _col_root: Node3D
var _back: Node3D

## Starts a storey's cycle on `floor_node`; every storey under it gets a floor older.
static func begin(floor_node: Node3D, floor_h: float):
	var live: Array = []
	for c in _cycles:
		if is_instance_valid(c):
			live.append(c)
	_cycles = live
	for c in _cycles:
		c._older()
	var cy = new()
	cy.name = "FloorCycle"
	cy.fh = floor_h
	floor_node.add_child(cy)
	_cycles.append(cy)
	return cy

## Runs the newest storey's cycle to `u` (0..1).
static func advance(u: float) -> void:
	if not _cycles.is_empty() and is_instance_valid(_cycles[-1]):
		_cycles[-1].show_at(u)

## What the TV says for the cycle at `u`.
static func task(u: float) -> String:
	for s in STAGES:
		if u < float(s[2]):
			return str(s[4])
	return str(STAGES[-1][4])

## Where the columns stand (game x/z) and which way each one's long side runs.
static func columns() -> Array:
	if not _cols.is_empty():
		return _cols
	var plate := SpireSite.poly("plate")
	var keep_out: Array = [Geometry2D.offset_polygon(SpireSite.poly("core"), 1.2)[0],
		Geometry2D.offset_polygon(SpireSite.opening(), 0.8)[0], Geometry2D.offset_polygon(SpireSite.opening(false), 0.8)[0]]
	for inset in [COL_IN, RING_IN]:
		var rings: Array = Geometry2D.offset_polygon(plate, -inset)
		for ring in rings:
			if Geometry2D.is_polygon_clockwise(ring):
				continue
			var n: int = ring.size()
			var per := 0.0
			for i in n:
				per += ring[i].distance_to(ring[(i + 1) % n])
			var count := maxi(3, int(round(per / COL_STEP)))
			var gap := per / count
			var want := gap * 0.5
			var walked := 0.0
			for i in n:
				var a: Vector2 = ring[i]
				var b: Vector2 = ring[(i + 1) % n]
				var ln := a.distance_to(b)
				while want <= walked + ln and ln > 0.001:
					var at := a.lerp(b, (want - walked) / ln)
					var ok := true
					for ko in keep_out:
						if Geometry2D.is_point_in_polygon(at, ko):
							ok = false
					if ok:
						_cols.append([at, -atan2(b.y - a.y, b.x - a.x)])
					want += gap
				walked += ln
	return _cols

func _h() -> float:
	return fh - 0.42            # floor to the underside of the formply

func _build() -> void:
	if _built:
		return
	_built = true
	var h := _h()
	var rust := F.color_mat(Color("9a4a2c"))
	var shutter := F.mat("yellow")
	var brace := F.color_mat(Color("c9422e"))
	var conc := F.mat("column")
	_col_root = Node3D.new()
	_col_root.name = "Columns"
	add_child(_col_root)
	for c in columns():
		var at: Vector2 = c[0]
		var here := Transform3D(Basis(Vector3.UP, float(c[1])), Vector3(at.x, 0, at.y))
		# The cage: eight bars and their ties, made up on the ground and flown in whole
		var cage := Node3D.new()
		cage.transform = here
		for i in 4:
			for s in [-1.0, 1.0]:
				cage.add_child(F.box(Vector3(0.03, h, 0.03), rust, Vector3(lerpf(-COL_L * 0.5 + 0.06, COL_L * 0.5 - 0.06, i / 3.0), h * 0.5, s * (COL_T * 0.5 - 0.05))))
		var ties := 6
		for i in ties:
			var ty := lerpf(0.15, h - 0.15, float(i) / (ties - 1))
			for s in [-1.0, 1.0]:
				cage.add_child(F.box(Vector3(COL_L - 0.08, 0.02, 0.02), rust, Vector3(0, ty, s * (COL_T * 0.5 - 0.035))))
		add_child(cage)
		F.bake(cage)
		cage.visible = false
		_cages.append(cage)
		# The form: two shutters and two stop ends, with a push-pull prop each side down to the slab
		var form := Node3D.new()
		form.transform = here
		for s in [-1.0, 1.0]:
			form.add_child(F.box(Vector3(COL_L + 0.2, h - 0.05, 0.06), shutter, Vector3(0, (h - 0.05) * 0.5, s * (COL_T * 0.5 + 0.03))))
			form.add_child(F.box(Vector3(0.06, h - 0.05, COL_T), shutter, Vector3(s * (COL_L * 0.5 + 0.03), (h - 0.05) * 0.5, 0)))
			form.add_child(F.beam(Vector3(s * 0.3, h * 0.7, s * (COL_T * 0.5 + 0.06)), Vector3(s * 0.3, 0.05, s * (COL_T * 0.5 + 1.3)), 0.06, brace))
		add_child(form)
		F.bake(form)
		form.visible = false
		_forms.append(form)
		# The column itself: poured from the bottom up
		var fill := Node3D.new()
		fill.transform = here
		fill.add_child(F.box(Vector3(COL_L, h, COL_T), conc, Vector3(0, h * 0.5, 0)))
		fill.scale.y = 0.01
		fill.visible = false
		_col_root.add_child(fill)
		_fills.append(fill)
	_build_props()

## Just the finished columns (a storey the game skipped past, or one too far down to need the rest).
func _build_plain() -> void:
	if _built:
		return
	_built = true
	done = true
	var h := _h()
	_col_root = Node3D.new()
	_col_root.name = "Columns"
	add_child(_col_root)
	for c in columns():
		var at: Vector2 = c[0]
		var col := F.box(Vector3(COL_L, h, COL_T), F.mat("column"), Vector3(at.x, h * 0.5, at.y))
		col.rotation.y = float(c[1])
		_col_root.add_child(col)
	F.bake(_col_root)

func _prop_points(step: float) -> Array:
	var plate := SpireSite.poly("plate")
	var edge: PackedVector2Array = Geometry2D.offset_polygon(plate, -0.3)[0]
	var core: PackedVector2Array = Geometry2D.offset_polygon(SpireSite.poly("core"), 0.35)[0]
	var holes: Array = [core, Geometry2D.offset_polygon(SpireSite.opening(), 0.5)[0], Geometry2D.offset_polygon(SpireSite.opening(false), 0.5)[0]]
	var bb := Rect2(plate[0], Vector2.ZERO)
	for p in plate:
		bb = bb.expand(p)
	var out: Array = []
	var x := bb.position.x + 0.6
	while x < bb.end.x:
		var col: Array = []
		var z := bb.position.y + 0.6
		while z < bb.end.y:
			var q := Vector2(x, z)
			var ok := Geometry2D.is_point_in_polygon(q, edge)
			for hole in holes:
				if ok and Geometry2D.is_point_in_polygon(q, hole):
					ok = false
			if ok:
				col.append(q)
			z += step
		if not col.is_empty():
			out.append(col)
		x += step
	return out

## The deck's falsework: a prop every 1.5 m, a bearer over each line of them, joists across the
## bearers. Built in strips (west to east), each stood up in turn.
func _build_props() -> void:
	var h := _h()
	var red := F.color_mat(Color("c9422e"))
	var inner := F.mat("steel")
	var timber := F.color_mat(Color("b98a55"))
	var lvl := F.color_mat(Color("d9b36a"))
	var plate := SpireSite.poly("plate")
	var top := h - 0.24                    # the props' heads: under the bearers
	var lines := _prop_points(PROP_STEP)
	if lines.is_empty():
		return
	var per := maxi(1, ceili(float(lines.size()) / BANDS))
	var band: Node3D = null
	for i in lines.size():
		if i % per == 0:
			band = Node3D.new()
			band.name = "Props%d" % _bands.size()
			add_child(band)
			_bands.append(band)
		var line: Array = lines[i]
		var za := INF
		var zb := -INF
		for q in line:
			band.add_child(F.cylinder(0.04, top * 0.55, red, Vector3(q.x, top * 0.275, q.y), 6))
			band.add_child(F.cylinder(0.028, top * 0.45, inner, Vector3(q.x, top * 0.775, q.y), 6))
			band.add_child(F.box(Vector3(0.16, 0.02, 0.16), inner, Vector3(q.x, 0.01, q.y)))
			za = minf(za, q.y)
			zb = maxf(zb, q.y)
		# (the bearer over this line of props: where the line's broken by the core, one each side)
		var a0: float = line[0].y
		for j in line.size():
			var last: bool = j == line.size() - 1
			if last or line[j + 1].y - line[j].y > PROP_STEP * 1.5:
				var b1: float = line[j].y
				band.add_child(F.box(Vector3(0.1, 0.15, b1 - a0 + 0.5), timber, Vector3(line[0].x, top + 0.075, (a0 + b1) * 0.5)))
				if not last:
					a0 = line[j + 1].y
		# Joists across to the next line of props, cut to the slab's edge
		var x0: float = line[0].x - PROP_STEP * 0.5
		var x1: float = x0 + PROP_STEP
		var z := za - 0.3
		while z <= zb + 0.3:
			for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([Vector2(x0, z), Vector2(x1, z)]), plate):
				if seg.size() >= 2 and seg[0].distance_to(seg[1]) > 0.1:
					band.add_child(F.box(Vector3(seg[0].distance_to(seg[1]), 0.09, 0.045), lvl, Vector3((seg[0].x + seg[1].x) * 0.5, top + 0.195, z)))
			z += JOIST_STEP
	for b in _bands:
		F.bake(b)
		b.visible = false

## The back-props left under a poured slab: every other prop, up to the soffit, nothing else.
func _build_back() -> void:
	if _back != null:
		return
	_back = Node3D.new()
	_back.name = "BackProps"
	add_child(_back)
	var h := _h() + 0.1
	var grey := F.color_mat(Color("8d9198"))
	var inner := F.mat("steel")
	for line in _prop_points(PROP_STEP * 2.0):
		for q in line:
			_back.add_child(F.cylinder(0.04, h * 0.55, grey, Vector3(q.x, h * 0.275, q.y), 6))
			_back.add_child(F.cylinder(0.028, h * 0.45, inner, Vector3(q.x, h * 0.775, q.y), 6))
	F.bake(_back)

## Shows the cycle as it stands at `u` (0 nothing yet .. 1 ready for the deck's steel).
func show_at(u: float) -> void:
	if done:
		return
	_build()
	var n := _cages.size()
	var cg := _span(u, 0)
	var fm := _span(u, 1)
	var pr := _span(u, 2)
	var st := _span(u, 3)
	var pp := _span(u, 4)
	for i in n:
		var t := float(i) / maxf(1.0, n)
		# (each cage comes down on the hook over the last bit of its turn)
		var drop := clampf((cg - t) * n, 0.0, 1.0)
		_cages[i].visible = drop > 0.0 and st < 1.0
		_cages[i].position.y = (1.0 - ease(drop, 0.4)) * 7.0
		_forms[i].visible = fm > t and st <= t
		var fill := clampf((pr - t * 0.7) / 0.3, 0.0, 1.0)
		_fills[i].visible = fill > 0.0
		_fills[i].scale.y = maxf(0.01, fill)
	for i in _bands.size():
		_bands[i].visible = pp * 0.85 > float(i) / _bands.size()
	if u >= 1.0:
		_finish()

## How far through stage `i` the cycle is at `u`, 0..1.
func _span(u: float, i: int) -> float:
	return clampf((u - float(STAGES[i][1])) / (float(STAGES[i][2]) - float(STAGES[i][1])), 0.0, 1.0)

func _finish() -> void:
	if done:
		return
	done = true
	for nd in _cages + _forms:
		nd.queue_free()
	_cages = []
	_forms = []
	for f in _fills:
		f.visible = true
		f.scale.y = 1.0
	_fills = []
	F.bake(_col_root)
	for b in _bands:
		b.visible = true

## The deck's moved on a floor: the props under a poured slab come out and back-props stay for a
## couple of floors.
func _older() -> void:
	age += 1
	if not _built:
		_build_plain()
	elif not done:
		_finish()
	for b in _bands:
		b.queue_free()
	_bands = []
	if age <= BACK_FLOORS:
		_build_back()
	elif _back != null:
		_back.queue_free()
		_back = null

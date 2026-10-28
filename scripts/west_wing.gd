## The other crew on Riverlight's west wing, building their next deck while
## ours is poured, the way a flat-plate concrete frame goes up a floor at a
## time on an Australian job:
##   1. COLUMNS AND CORE  the steel fixers tie each column cage onto the
##      starter bars left in the slab below, and the lift core's wall steel;
##      the formworkers close steel column boxes round the cages (held plumb
##      with push-pull props) and crane-handled gang forms round the shaft,
##      then they're poured and the forms come off
##   2. DECK FORMWORK     props with bearers and joists on top, then formply,
##      working from the link out to the rounded end, and stop-ends round the
##      edge. The tower crane flies up the prop pack and the ply.
##   3. REINFORCEMENT     the crane lands bar bundles on the ply (two-leg
##      slings, a dogman on the deck guiding them in); the fixers lay the
##      bottom mat on bar chairs, the post-tensioning ducts (banded over the
##      column lines one way, spread across the other), the top bars over
##      the columns, and the starter bars for the next floor's columns
## It runs on our pour's clock: `progress` follows our slab's fill, so they
## finish fixing as we finish pouring, and their concrete goes in as ours
## cures (main._other_crew_floor lays their slab over it).
extends Node3D

const F := preload("res://scripts/factory.gd")

const SOFFIT := 2.7          # top of the formply (the slab's underside), from the floor below
const TOP := 3.0             # top of the slab
const COL := 0.6             # column size
## The lift core: two shafts side by side, between the column lines
const CORE_C := Vector2(27.6, -9.6)
const CORE_S := Vector2(5.2, 2.8)
const WALL := 0.2
const STRIP := 1.2           # formply sheet width (the deck goes down a strip at a time)
const BAR := 0.035           # bar thickness as drawn (fatter than an N12, so it reads)
const BAR_GAP := 0.45        # bar spacing as drawn
## When each piece of work happens, as a share of our pour
const ST := {
	"cages": [0.0, 0.10], "core_reo": [0.02, 0.12], "core_form": [0.07, 0.17], "col_form": [0.09, 0.18],
	"cast": [0.18, 0.22], "props": [0.21, 0.42], "ply": [0.25, 0.46], "edge": [0.42, 0.48],
	"bottom": [0.47, 0.64], "pt": [0.62, 0.77], "top": [0.76, 0.90], "starters": [0.88, 0.97],
}
## The crane's lifts: when the load's called for, what it is and where it goes
## (local x, z; "deck" lands on the ply, "floor" on the slab below; "ply"
## lands just behind where the ply's got to)
const LIFTS := [
	{"at": 0.0, "what": "panel_n"},
	{"at": 0.02, "what": "panel_s"},
	{"at": 0.18, "what": "PropPack", "to": Vector2(48.0, -13.5), "on": "floor", "used": 0.40},
	{"at": 0.28, "what": "PlyStack", "to": Vector2(0, -15.5), "on": "ply", "used": 0.46},
	{"at": 0.40, "what": "BarBundle", "to": Vector2(19.5, -16.0), "on": "deck", "used": 0.66},
	{"at": 0.52, "what": "BarBundle", "to": Vector2(36.0, -3.0), "on": "deck", "used": 0.70},
	{"at": 0.62, "what": "DuctBundle", "to": Vector2(41.0, -15.5), "on": "deck", "used": 0.78},
	{"at": 0.74, "what": "BarBundle", "to": Vector2(22.0, -3.5), "on": "deck", "used": 0.92},
]
## The west crew's laydown, on the ground south of their wing under the crane
const LAYDOWN_Z := -23.6
const LAYDOWN_X0 := 17.0
const SLING := 2.2           # hook to the top of the load
const H_SPD := 7.0           # m/s the hook travels round (slew and trolley; game-quick)
const V_SPD := 8.0           # m/s hoisting

var game
var plan: PackedVector2Array
var level := 0
var progress := 0.0
var poured := false          # their slab's in (our slab's locked)
var x0 := 0.0
var x1 := 0.0

var _cols: Array = []        # column centres (local x/z), by x
var _cages: Array[Node3D] = []
var _col_forms: Array[Node3D] = []
var _col_conc: Array[Node3D] = []
var _core_reo: Array[Node3D] = []
var _core_inner: Node3D
var _core_ends: Node3D
var _core_conc: Node3D
var _panels := {}            # "panel_n"/"panel_s" -> gang form panel
var _props_mm: MultiMeshInstance3D
var _bearers_mm: MultiMeshInstance3D
var _joists_mm: MultiMeshInstance3D
var _prop_xs: PackedFloat32Array = []
var _strips: Array[Node3D] = []
var _strip_x: PackedFloat32Array = []
var _edges: Array[Node3D] = []
var _bars := {}              # layer -> MultiMeshInstance3D
var _top_by_col: Array = []  # per column: [first instance, count] in the top layer
var _next_starters: Node3D
var _base_starters: Node3D
var _deck: Node3D            # everything on and under the new deck
var _crew: Array[Node3D] = []
var _slinger: Node3D         # the dogman on the ground, slinging the loads
var _lifts: Array = []
var _lift_i := -1            # the lift the crane's on
var _crane_state := ""       # "" / "to_pick" / "rig" / "lift" / "land" / "clear"
var _crane_t := 0.0
var _move := {}
var _slings: Array[MeshInstance3D] = []
var _t := 0.0

var m_bar: ShaderMaterial
var m_form: ShaderMaterial
var m_ply: Array = []
var m_conc: ShaderMaterial

func build(owner_game, wing: PackedVector2Array) -> void:
	game = owner_game
	plan = wing
	x0 = INF
	x1 = -INF
	for p in plan:
		x0 = minf(x0, p.x)
		x1 = maxf(x1, p.x)
	m_bar = F.color_mat(Color("5e3320"))
	m_form = F.color_mat(Color("e8b13a"))
	m_ply = [F.mat("ply"), F.color_mat(Color("b9844d"))]
	m_conc = F.mat("column")
	_deck = Node3D.new()
	add_child(_deck)
	_build_columns()
	_build_core()
	_build_formwork()
	_build_bars()
	_build_lifts()
	_build_crew()
	for i in 2:
		var sl := F.cylinder(0.03, 1.0, F.color_mat(Color("3a6bd1")), Vector3.ZERO, 5)
		sl.visible = false
		game.add_child(sl)
		_slings.append(sl)
	game.climb.borrow = Callable(self, "_crane")

# ------------------------------------------------------------------ geometry

## A single mesh out of many boxes ([size, centre] pairs), so a cage of
## forty bars is one draw.
static func _merged(boxes: Array, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	var bm := BoxMesh.new()
	for bx in boxes:
		bm.size = bx[0]
		st.append_from(bm, 0, Transform3D(Basis(), bx[1]))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi

static func _multi(xforms: Array, mat: Material, shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	mm.mesh = bm
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

## A box `size` at `at`, as a multimesh instance.
static func _xf(size: Vector3, at: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), at)

func _in_core(p: Vector2, pad := 0.0) -> bool:
	return absf(p.x - CORE_C.x) < CORE_S.x * 0.5 + pad and absf(p.y - CORE_C.y) < CORE_S.y * 0.5 + pad

## A straight bar line across the plan, clipped to its edges and broken
## round the lift shafts: [[a, b], ...]
func _clip(a: Vector2, b: Vector2, inset := 0.06) -> Array:
	var poly: Array = Geometry2D.offset_polygon(plan, -inset)
	var out := []
	if poly.is_empty():
		return out
	for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), poly[0]):
		var s: PackedVector2Array = seg
		var p: Vector2 = s[0]
		var q: Vector2 = s[s.size() - 1]
		# (the shafts are open: stop the bar either side of them)
		var lo := CORE_C - CORE_S * 0.5 - Vector2(0.05, 0.05)
		var hi := CORE_C + CORE_S * 0.5 + Vector2(0.05, 0.05)
		var horiz := absf(q.y - p.y) < 0.001
		var c := p.y if horiz else p.x
		var inside := (c > lo.y and c < hi.y) if horiz else (c > lo.x and c < hi.x)
		if inside:
			var a0 := minf(p.x, q.x) if horiz else minf(p.y, q.y)
			var a1 := maxf(p.x, q.x) if horiz else maxf(p.y, q.y)
			var l0 := lo.x if horiz else lo.y
			var l1 := hi.x if horiz else hi.y
			for r in [[a0, minf(a1, l0)], [maxf(a0, l1), a1]]:
				if r[1] - r[0] > 0.2:
					out.append([Vector2(r[0], c), Vector2(r[1], c)] if horiz else [Vector2(c, r[0]), Vector2(c, r[1])])
		else:
			out.append([p, q])
	return out

func _build_columns() -> void:
	var inner: Array = Geometry2D.offset_polygon(plan, -0.7)
	var x := 15.6
	while x < x1:
		var z := -18.9
		while z < 1.2:
			var c := Vector2(x, z)
			if not inner.is_empty() and Geometry2D.is_point_in_polygon(c, inner[0]) and not _in_core(c, 1.0):
				_cols.append(c)
			z += 6.4
		x += 7.2
	var tie_y := 0.15
	for c in _cols:
		# The cage: eight bars up from the floor and ties every 250
		var boxes := []
		var h := COL * 0.5 - 0.06
		for v in [Vector2(-h, -h), Vector2(0, -h), Vector2(h, -h), Vector2(h, 0), Vector2(h, h), Vector2(0, h), Vector2(-h, h), Vector2(-h, 0)]:
			boxes.append([Vector3(BAR, SOFFIT, BAR), Vector3(v.x, SOFFIT * 0.5, v.y)])
		tie_y = 0.15
		while tie_y < SOFFIT:
			boxes.append([Vector3(h * 2.0 + BAR, 0.02, 0.02), Vector3(0, tie_y, -h)])
			boxes.append([Vector3(h * 2.0 + BAR, 0.02, 0.02), Vector3(0, tie_y, h)])
			boxes.append([Vector3(0.02, 0.02, h * 2.0 + BAR), Vector3(-h, tie_y, 0)])
			boxes.append([Vector3(0.02, 0.02, h * 2.0 + BAR), Vector3(h, tie_y, 0)])
			tie_y += 0.25
		var cage := Node3D.new()
		cage.position = Vector3(c.x, 0, c.y)
		cage.add_child(_merged(boxes, m_bar))
		_deck.add_child(cage)
		_cages.append(cage)
		# The steel column box over it, propped two ways
		var form := Node3D.new()
		form.position = Vector3(c.x, 0, c.y)
		form.add_child(F.box(Vector3(COL + 0.12, SOFFIT - 0.05, COL + 0.12), m_form, Vector3(0, (SOFFIT - 0.05) * 0.5, 0)))
		for d in [Vector3(1.7, 0, 0.3), Vector3(-0.3, 0, 1.7)]:
			form.add_child(F.beam(Vector3(0, 2.0, 0) + d.normalized() * 0.36, d + Vector3(0, 0.05, 0), 0.06, F.mat("steel")))
		_deck.add_child(form)
		_col_forms.append(form)
		var conc := F.box(Vector3(COL, SOFFIT, COL), m_conc, Vector3(c.x, SOFFIT * 0.5, c.y))
		_deck.add_child(conc)
		_col_conc.append(conc)

## The two lift shafts: wall steel, the inner shaft forms, the gang panels
## the crane flies onto the long faces, the ends, and the concrete walls.
func _walls() -> Array:
	var lo := CORE_C - CORE_S * 0.5
	var hi := CORE_C + CORE_S * 0.5
	# [centre, size] in plan: north, south, east end, west end, the wall between
	return [[Vector2(CORE_C.x, hi.y - WALL * 0.5), Vector2(CORE_S.x, WALL)], [Vector2(CORE_C.x, lo.y + WALL * 0.5), Vector2(CORE_S.x, WALL)],
		[Vector2(lo.x + WALL * 0.5, CORE_C.y), Vector2(WALL, CORE_S.y)], [Vector2(hi.x - WALL * 0.5, CORE_C.y), Vector2(WALL, CORE_S.y)],
		[CORE_C, Vector2(WALL, CORE_S.y)]]

func _build_core() -> void:
	var conc_boxes := []
	for w in _walls():
		var c: Vector2 = w[0]
		var s: Vector2 = w[1]
		var boxes := []
		var along_x := s.x > s.y
		var ln := s.x if along_x else s.y
		var t := -ln * 0.5 + 0.1
		while t <= ln * 0.5 - 0.05:
			for face in [-0.05, 0.05]:
				var at := Vector3(t, SOFFIT * 0.5, face) if along_x else Vector3(face, SOFFIT * 0.5, t)
				boxes.append([Vector3(BAR, SOFFIT + 0.2, BAR), at])
			t += 0.3
		var y := 0.2
		while y < SOFFIT:
			for face in [-0.065, 0.065]:
				boxes.append([Vector3(ln, BAR, BAR) if along_x else Vector3(BAR, BAR, ln), Vector3(0, y, face) if along_x else Vector3(face, y, 0)])
			y += 0.3
		var reo := Node3D.new()
		reo.position = Vector3(c.x, 0, c.y)
		reo.add_child(_merged(boxes, m_bar))
		_deck.add_child(reo)
		_core_reo.append(reo)
		conc_boxes.append([Vector3(s.x, SOFFIT, s.y), Vector3(c.x, SOFFIT * 0.5, c.y)])
	_core_conc = _merged(conc_boxes, F.mat("core"))
	_deck.add_child(_core_conc)
	# Inside each shaft, a shaft form (a collapsible box), set first
	var inner := []
	for side in [-1.0, 1.0]:
		var cx: float = CORE_C.x + side * (CORE_S.x * 0.25)
		inner.append([Vector3(CORE_S.x * 0.5 - WALL * 1.5 - 0.06, SOFFIT, CORE_S.y - WALL * 2.0 - 0.06), Vector3(cx, SOFFIT * 0.5, CORE_C.y)])
	_core_inner = _merged(inner, m_form)
	_deck.add_child(_core_inner)
	# The end forms, set by hand
	var ends := []
	for side in [-1.0, 1.0]:
		ends.append([Vector3(0.1, SOFFIT, CORE_S.y + 0.2), Vector3(CORE_C.x + side * (CORE_S.x * 0.5 + 0.05), SOFFIT * 0.5, CORE_C.y)])
	_core_ends = _merged(ends, m_form)
	_deck.add_child(_core_ends)
	# The long faces: gang forms (ply on a steel waler frame), flown in whole
	for key in ["panel_n", "panel_s"]:
		var side := 1.0 if key == "panel_n" else -1.0
		var p := Node3D.new()
		p.add_child(F.box(Vector3(CORE_S.x + 0.4, SOFFIT, 0.08), m_form, Vector3(0, SOFFIT * 0.5, 0)))
		for wy in [0.4, 1.35, 2.3]:
			p.add_child(F.box(Vector3(CORE_S.x + 0.6, 0.12, 0.1), F.mat("steel"), Vector3(0, wy, side * 0.09)))
		p.set_meta("lug_y", SOFFIT)
		p.set_meta("rest", Vector3(CORE_C.x, 0, CORE_C.y + side * (CORE_S.y * 0.5 + 0.04)))
		game.add_child(p)
		_panels[key] = p

func _build_formwork() -> void:
	# Props on a 1.2 x 1.5 grid under the deck, each with its bearer and
	# four joists, in the order they go up (from the link outwards)
	var inner: Array = Geometry2D.offset_polygon(plan, -0.4)
	var pts := []
	var x := x0 + 0.6
	while x < x1:
		var z := -20.0 + 0.75
		while z < 2.0:
			var c := Vector2(x, z)
			if not inner.is_empty() and Geometry2D.is_point_in_polygon(c, inner[0]) and not _in_core(c, 0.3):
				var clear := true
				for cc in _cols:
					if (cc as Vector2).distance_to(c) < 0.6:
						clear = false
				if clear:
					pts.append(c)
			z += 1.5
		x += STRIP
	var props := []
	var bearers := []
	var joists := []
	var b_top := SOFFIT - 0.017 - 0.12
	for c in pts:
		props.append(_xf(Vector3(0.06, b_top - 0.15, 0.06), Vector3(c.x, (b_top - 0.15) * 0.5, c.y)))
		bearers.append(_xf(Vector3(0.1, 0.15, 1.5), Vector3(c.x, b_top - 0.075, c.y)))
		for j in 4:
			joists.append(_xf(Vector3(STRIP, 0.12, 0.08), Vector3(c.x, b_top + 0.06, c.y - 0.5625 + j * 0.375)))
		_prop_xs.append(c.x)
	_props_mm = _multi(props, F.mat("steel"))
	_bearers_mm = _multi(bearers, F.color_mat(Color("c79a4a")))
	_joists_mm = _multi(joists, F.color_mat(Color("d6b06c")), false)
	for m in [_props_mm, _bearers_mm, _joists_mm]:
		_deck.add_child(m)
	# Formply, a sheet-wide strip at a time, cut round the shafts
	var lo := CORE_C - CORE_S * 0.5
	var hi := CORE_C + CORE_S * 0.5
	var i := 0
	x = x0
	while x < x1:
		var strip := Node3D.new()
		var rects := []
		var a := x + 0.015
		var b := x + STRIP - 0.015
		if b <= lo.x or a >= hi.x:
			rects.append([a, b, -30.0, 10.0])
		else:
			if a < lo.x:
				rects.append([a, lo.x, -30.0, 10.0])
			if b > hi.x:
				rects.append([hi.x, b, -30.0, 10.0])
			rects.append([maxf(a, lo.x), minf(b, hi.x), -30.0, lo.y])
			rects.append([maxf(a, lo.x), minf(b, hi.x), hi.y, 10.0])
		for r in rects:
			var rect := PackedVector2Array([Vector2(r[0], r[2]), Vector2(r[1], r[2]), Vector2(r[1], r[3]), Vector2(r[0], r[3])])
			for piece in Geometry2D.intersect_polygons(plan, rect):
				strip.add_child(F.prism(piece, SOFFIT - 0.017, 0.017, m_ply[i % 2]))
		strip.visible = false
		_deck.add_child(strip)
		_strips.append(strip)
		_strip_x.append(x + STRIP)
		x += STRIP
		i += 1
	# Stop-ends round the edge of the slab
	for e in plan.size():
		var p: Vector2 = plan[e]
		var q: Vector2 = plan[(e + 1) % plan.size()]
		var mid := (p + q) * 0.5
		var ed := F.box(Vector3((q - p).length(), 0.42, 0.04), m_ply[0], Vector3(mid.x, SOFFIT + 0.19, mid.y))
		ed.rotation.y = -atan2(q.y - p.y, q.x - p.x)
		ed.visible = false
		_deck.add_child(ed)
		_edges.append(ed)

func _bar_xf(a: Vector2, b: Vector2, y: float, w := BAR, h := BAR) -> Transform3D:
	var d := b - a
	var mid := (a + b) * 0.5
	var basis := Basis(Vector3.UP, -atan2(d.y, d.x)) * Basis.from_scale(Vector3(d.length(), h, w))
	return Transform3D(basis, Vector3(mid.x, y, mid.y))

func _build_bars() -> void:
	var y0 := SOFFIT + 0.045      # bottom mat on its chairs (25 cover)
	# Bottom mat: bars along the wing first, then across them
	var along := []
	var z := -20.0 + 0.2
	while z < 2.0:
		for s in _clip(Vector2(x0 - 1.0, z), Vector2(x1 + 1.0, z)):
			along.append(_bar_xf(s[0], s[1], y0))
		z += BAR_GAP
	var across := []
	var x := x0 + 0.2
	while x < x1:
		for s in _clip(Vector2(x, -21.0), Vector2(x, 3.0)):
			across.append(_bar_xf(s[0], s[1], y0 + BAR))
		x += BAR_GAP
	along.append_array(across)
	_bars["bottom"] = _multi(along, m_bar, false)
	_bars["bottom"].set_meta("split", along.size() - across.size())
	# Post-tensioning: flat galvanised ducts banded over each column line
	# along the wing, then spread across it
	var ducts := []
	var rows := {}
	for c in _cols:
		rows[snappedf((c as Vector2).y, 0.1)] = true
	for rz in rows.keys():
		for off in [-0.15, -0.05, 0.05, 0.15]:
			for s in _clip(Vector2(x0 - 1.0, rz + off), Vector2(x1 + 1.0, rz + off), 0.15):
				ducts.append(_bar_xf(s[0], s[1], y0 + 0.09, 0.07, 0.02))
	var banded := ducts.size()
	x = x0 + 0.9
	while x < x1:
		for s in _clip(Vector2(x, -21.0), Vector2(x, 3.0), 0.15):
			ducts.append(_bar_xf(s[0], s[1], y0 + 0.11, 0.07, 0.02))
		x += 1.4
	_bars["pt"] = _multi(ducts, F.color_mat(Color("7d878e")), false)
	_bars["pt"].set_meta("split", banded)
	# Top bars over each column, both ways
	var top := []
	for c in _cols:
		var first := top.size()
		for j in 7:
			var o := -0.9 + j * 0.3
			for s in _clip(c + Vector2(-1.6, o), c + Vector2(1.6, o)):
				top.append(_bar_xf(s[0], s[1], TOP - 0.06))
			for s in _clip(c + Vector2(o, -1.6), c + Vector2(o, 1.6)):
				top.append(_bar_xf(s[0], s[1], TOP - 0.06 + BAR))
		_top_by_col.append([first, top.size() - first])
	_bars["top"] = _multi(top, m_bar, false)
	for key in _bars:
		_deck.add_child(_bars[key])
	# Starter bars: the next floor's (poking up out of this deck), and this
	# floor's (left in the slab below, what the cages tie onto)
	for which in ["next", "base"]:
		var boxes := []
		var y_bot := TOP - 0.3 if which == "next" else 0.0
		var y_top := TOP + 0.9 if which == "next" else 0.9
		var h := COL * 0.5 - 0.06
		for c in _cols:
			for v in [Vector2(-h, -h), Vector2(0, -h), Vector2(h, -h), Vector2(h, 0), Vector2(h, h), Vector2(0, h), Vector2(-h, h), Vector2(-h, 0)]:
				boxes.append([Vector3(BAR, y_top - y_bot, BAR), Vector3(c.x + v.x, (y_top + y_bot) * 0.5, c.y + v.y)])
		for w in _walls():
			var c: Vector2 = w[0]
			var s: Vector2 = w[1]
			var along_x := s.x > s.y
			var ln := s.x if along_x else s.y
			var t := -ln * 0.5 + 0.1
			while t <= ln * 0.5 - 0.05:
				var at := Vector2(c.x + t, c.y) if along_x else Vector2(c.x, c.y + t)
				boxes.append([Vector3(BAR, y_top - y_bot, BAR), Vector3(at.x, (y_top + y_bot) * 0.5, at.y)])
				t += 0.3
		var n := Node3D.new()
		n.add_child(_merged(boxes, m_bar))
		add_child(n)
		if which == "next":
			_next_starters = n
		else:
			_base_starters = n

## What the crane flies, and where it's stood on the laydown till then.
func _build_lifts() -> void:
	for i in LIFTS.size():
		var spec: Dictionary = LIFTS[i]
		var what: String = spec["what"]
		var node: Node3D
		if _panels.has(what):
			node = _panels[what]
		else:
			node = Node3D.new()
			match what:
				"PropPack":
					# (a stillage of props: steel tubes on a pallet)
					node.add_child(F.prop("Pallet", {}, F.SITE))
					for r in 3:
						for c in 5:
							node.add_child(F.box(Vector3(2.4, 0.07, 0.07), F.mat("steel"), Vector3(0, 0.2 + r * 0.08, -0.2 + c * 0.1)))
				"DuctBundle":
					for r in 4:
						node.add_child(F.box(Vector3(6.0, 0.03, 0.4), F.color_mat(Color("a7b0b6")), Vector3(0, 0.08 + r * 0.04, 0)))
					node.add_child(F.box(Vector3(0.1, 0.08, 0.5), F.color_mat(Color("6b6f73")), Vector3(-2.2, 0.04, 0)))
					node.add_child(F.box(Vector3(0.1, 0.08, 0.5), F.color_mat(Color("6b6f73")), Vector3(2.2, 0.04, 0)))
				_:
					node.add_child(F.prop(what, {}, F.SITE))
			game.add_child(node)
		_lifts.append({"spec": spec, "node": node, "state": "wait", "pick": Vector3(LAYDOWN_X0 + i * 3.1, 0.0, LAYDOWN_Z), "to": Vector3.ZERO})

func _build_crew() -> void:
	var looks := [{"skin": "e8b48a", "hair": "2b1d14", "look": "beard"}, {"skin": "c98e62", "hair": "121212", "look": "sunnies"},
		{"skin": "f2c9a0", "hair": "8a5a2e", "look": "moustache"}, {"skin": "8d5a3b", "hair": "121212", "look": ""},
		{"skin": "f2c9a0", "hair": "c9a060", "look": "ponytail"}, {"skin": "d9a37a", "hair": "4a3122", "look": "earmuffs"}]
	for i in 6:
		# Four steel fixers (white hats, navy shirts), two formworkers (blue hats)
		var fixer := i < 4
		var n := F.chibi(Color("2d3f66") if fixer else Color("e2d05a"), Color("f4f7fa") if fixer else Color("3a7bd5"))
		F.dress(n, looks[i])
		n.scale = Vector3.ONE * 1.05
		n.set_meta("job", "fixer" if fixer else "formie")
		n.set_meta("goal", Vector3(14.0 + i, 0, -6.0))
		n.set_meta("face", Vector3.ZERO)
		n.position = Vector3(14.0 + i, 0, -6.0)
		add_child(n)
		_crew.append(n)
	F.kit(_crew[0], "dogman")
	_slinger = F.chibi(Color("2d3f66"), Color("f4f7fa"))
	F.dress(_slinger, {"skin": "e0ad84", "hair": "6a4a2a", "look": "bun"})
	F.kit(_slinger, "dogman")
	_slinger.scale = Vector3.ONE * 1.05
	_slinger.position = Vector3(LAYDOWN_X0 - 2.0, 0, LAYDOWN_Z + 1.6)
	game.add_child(_slinger)

# ------------------------------------------------------------------ the cycle

## A new floor: up onto the slab that's just gone in, everything reset.
func start_level(k: int) -> void:
	level = k
	position.y = k * game.FH
	progress = 0.0
	poured = false
	_lift_i = -1
	_crane_state = ""
	for l in _lifts:
		l["state"] = "wait"
	for n in _crew:
		var p := n.position
		n.position = Vector3(p.x, 0.0, p.z)
	_apply()

## Our slab's locked: their concrete's in too (the plate main lays over this).
func pour_done() -> void:
	progress = 1.0
	poured = true
	if _lift_i >= 0:
		_drop_lift()
	_apply()

func _u(key: String) -> float:
	var w: Array = ST[key]
	return clampf((progress - w[0]) / (w[1] - w[0]), 0.0, 1.0)

func ply_x(b: float) -> float:
	var w: Array = ST["ply"]
	return lerpf(x0, x1, clampf((b - w[0]) / (w[1] - w[0]), 0.0, 1.0))

func update(delta: float, frac: float) -> void:
	_t += delta
	_slinger.visible = visible
	if not visible:
		for l in _lifts:
			(l["node"] as Node3D).visible = false
		_hide_slings()
		return
	if not poured:
		# (never goes backwards: a slab that's had its coverage nibbled stays done)
		progress = maxf(progress, clampf(frac, 0.0, 1.0))
	for i in _lifts.size():
		var l: Dictionary = _lifts[i]
		if l["state"] == "wait" and progress >= l["spec"]["at"] and not poured and game.phase in ["inspect", "pour"]:
			l["state"] = "queued"
	_apply()
	_update_crew(delta)

## Shows each piece of work as far as it's got.
func _apply() -> void:
	var cast := _u("cast") >= 1.0
	var n := _cols.size()
	for i in n:
		var cu := clampf(_u("cages") * n - i, 0.0, 1.0)
		_cages[i].visible = cu > 0.0 and not cast
		_cages[i].scale.y = maxf(0.02, cu)
		var fu := clampf(_u("col_form") * n - i, 0.0, 1.0)
		_col_forms[i].visible = fu > 0.0 and not cast
		_col_forms[i].position.y = (1.0 - fu) * 2.5
		_col_conc[i].visible = cast
	for i in _core_reo.size():
		var ru := clampf(_u("core_reo") * _core_reo.size() - i, 0.0, 1.0)
		_core_reo[i].visible = ru > 0.0 and not cast
		_core_reo[i].scale.y = maxf(0.02, ru)
	_core_inner.visible = _u("core_form") > 0.0 and not cast
	_core_ends.visible = _u("core_form") > 0.6 and not cast
	_core_conc.visible = cast
	# Deck formwork, from the link outwards (the props a few metres ahead)
	var px := lerpf(x0, x1 + 3.0, _u("props"))
	var cnt := _prop_xs.bsearch(px)
	_props_mm.multimesh.visible_instance_count = cnt
	_bearers_mm.multimesh.visible_instance_count = cnt
	_joists_mm.multimesh.visible_instance_count = cnt * 4
	var plx := ply_x(progress) if _u("ply") > 0.0 else -INF
	for i in _strips.size():
		_strips[i].visible = _strip_x[i] <= plx + 0.01 and not poured
	for i in _edges.size():
		_edges[i].visible = _u("edge") * _edges.size() > i and not poured
	# The steel
	var bm: MultiMesh = _bars["bottom"].multimesh
	bm.visible_instance_count = 0 if poured else int(_u("bottom") * bm.instance_count)
	var pm: MultiMesh = _bars["pt"].multimesh
	pm.visible_instance_count = 0 if poured else int(_u("pt") * pm.instance_count)
	var tm: MultiMesh = _bars["top"].multimesh
	tm.visible_instance_count = 0 if poured else int(_u("top") * tm.instance_count)
	var last: bool = level >= game.floors() - 1
	_next_starters.visible = _u("starters") >= 0.5 and not last
	_base_starters.visible = not cast
	# The loads (all flown in the game's frame)
	for l in _lifts:
		var node: Node3D = l["node"]
		var spec: Dictionary = l["spec"]
		var used: float = spec.get("used", ST["cast"][0])
		var panel := _panels.has(spec["what"])
		match l["state"]:
			"wait", "queued", "skipped":
				if panel and progress >= spec["at"] + 0.12:
					# (a panel the crane never got to: set by hand)
					node.global_position = to_global(node.get_meta("rest"))
					node.visible = not cast
				else:
					node.global_position = l["pick"]
					node.rotation.y = 0.0
					node.visible = progress < used and not poured
			"fly":
				node.visible = true
			"landed":
				if panel:
					node.global_position = to_global(node.get_meta("rest"))
					node.visible = not cast
				else:
					node.visible = progress < used and not (poured and spec.get("on", "") != "floor")
	_props_mm.visible = not poured
	_bearers_mm.visible = not poured
	_joists_mm.visible = not poured

# ------------------------------------------------------------------ the crane

## Drives the tower crane while the climb isn't using it. Returns false to
## let it park.
func _crane(delta: float) -> bool:
	if not visible:
		return false
	if _lift_i < 0:
		for i in _lifts.size():
			if _lifts[i]["state"] == "queued":
				var l: Dictionary = _lifts[i]
				# (too late for it: they've moved on, it comes up by hand)
				if progress > float(l["spec"].get("used", 1.0)) - 0.04 or poured:
					l["state"] = "skipped"
					if game.autotest:
						print("[autotest]   west wing: %s skipped (crane too late)" % l["spec"]["what"])
					continue
				_lift_i = i
				_begin_lift()
				break
	if _lift_i < 0:
		_hide_slings()
		if _crane_state == "clear":
			if _step_move(delta):
				_crane_state = ""
			return true
		# (between lifts it waits over their laydown, not over our deck)
		if game.phase in ["inspect", "pour"] and progress < 0.97:
			var standby := Vector3(LAYDOWN_X0 + 8.0, position.y + 12.0, LAYDOWN_Z + 3.0)
			if _move.is_empty() and _hook().distance_to(standby) > 1.0:
				_plan_move(standby, false)
			_step_move(delta)
			return true
		return false
	var l: Dictionary = _lifts[_lift_i]
	var node: Node3D = l["node"]
	match _crane_state:
		"to_pick":
			if _step_move(delta):
				_crane_state = "rig"
				_crane_t = 0.0
		"rig":
			_crane_t += delta
			_slings_to(node, minf(1.0, _crane_t / 0.9))
			if _crane_t > 1.2:
				_crane_state = "lift"
				l["state"] = "fly"
				_plan_move(l["to"] + Vector3(0, SLING, 0), true)
		"lift":
			var done := _step_move(delta)
			node.global_position = _hook() - Vector3(0, SLING, 0)
			node.rotation.y = lerp_angle(node.rotation.y, float(l.get("yaw", 0.0)), minf(1.0, delta))
			_slings_to(node, 1.0)
			if done:
				_crane_state = "land"
				_crane_t = 0.0
		"land":
			_crane_t += delta
			_slings_to(node, 1.0 - minf(1.0, _crane_t / 0.9))
			if _crane_t > 1.1:
				_land(l)
	_draw_dogman(l)
	return true

## Dev: a load's in the air between the laydown and the deck.
func lifting() -> bool:
	return _crane_state == "lift" and not _move.is_empty() and float(_move["t"]) / float(_move["T"]) > 0.45

func lift_focus() -> Vector3:
	return _hook() - Vector3(0, SLING + 4.0, 0)

func _hook() -> Vector3:
	var c = game.climb
	return Vector3(c.trolley_xz.x, c.CRANE_H - c.cable_len + 0.4, c.trolley_xz.y)

func _set_hook(at: Vector3) -> void:
	var c = game.climb
	c.trolley_xz = Vector2(at.x, at.z)
	c.cable_len = c.CRANE_H + 0.4 - at.y

func _begin_lift() -> void:
	var l: Dictionary = _lifts[_lift_i]
	var spec: Dictionary = l["spec"]
	var base := position.y
	var to := Vector3.ZERO
	var yaw := 0.0
	if _panels.has(spec["what"]):
		to = to_global(_panels[spec["what"]].get_meta("rest"))
	else:
		var at: Vector2 = spec["to"]
		var y := base
		match spec.get("on", "deck"):
			"deck":
				y += SOFFIT
			"ply":
				at.x = clampf(ply_x(progress + 0.05) - 2.5, x0 + 4.0, CORE_C.x - 4.0)
				y += SOFFIT
		to = Vector3(at.x, y, at.y)
		yaw = 0.4 if spec["what"] == "BarBundle" else 0.0
	l["to"] = to
	l["yaw"] = yaw
	_crane_state = "to_pick"
	_plan_move(l["pick"] + Vector3(0, SLING + 0.3, 0), false)

## Sets the hook travelling from where it is to `to`: slewing round the
## mast and trolleying at once, hoisting clear first with a load on (and
## lowering in at the end).
func _plan_move(to: Vector3, loaded: bool) -> void:
	var mast: Vector3 = game.climb.MAST
	var from := _hook()
	var a0 := atan2(from.z - mast.z, from.x - mast.x)
	var a1 := atan2(to.z - mast.z, to.x - mast.x)
	var da := wrapf(a1 - a0, -PI, PI)
	var r0 := Vector2(from.x - mast.x, from.z - mast.z).length()
	var r1 := Vector2(to.x - mast.x, to.z - mast.z).length()
	var clear_y := maxf(from.y, to.y) + (6.0 if loaded else 3.0)
	var horiz := absf(da) * maxf(r0, r1) + absf(r1 - r0)
	var vert := (clear_y - from.y) + (clear_y - to.y)
	var t := maxf(2.0, horiz / H_SPD + vert / V_SPD * 0.5)
	_move = {"a0": a0, "da": da, "r0": r0, "r1": r1, "y0": from.y, "y1": to.y, "yc": clear_y, "t": 0.0, "T": t}

func _step_move(delta: float) -> bool:
	if _move.is_empty():
		return true
	_move["t"] += delta
	var u := clampf(_move["t"] / _move["T"], 0.0, 1.0)
	var s := smoothstep(0.2, 0.85, u)
	var a: float = _move["a0"] + _move["da"] * s
	var r: float = lerpf(_move["r0"], _move["r1"], s)
	var y: float
	if u < 0.3:
		y = lerpf(_move["y0"], _move["yc"], smoothstep(0.0, 0.3, u))
	elif u > 0.75:
		y = lerpf(_move["yc"], _move["y1"], smoothstep(0.75, 1.0, u))
	else:
		y = _move["yc"]
	var mast: Vector3 = game.climb.MAST
	_set_hook(Vector3(mast.x + cos(a) * r, y, mast.z + sin(a) * r))
	if u >= 1.0:
		_move = {}
		return true
	return false

func _land(l: Dictionary) -> void:
	var node: Node3D = l["node"]
	l["state"] = "landed"
	if game.autotest:
		print("[autotest]   west wing: %s landed at %d%% of the pour" % [l["spec"]["what"], int(progress * 100.0)])
	node.global_position = l["to"]
	_hide_slings()
	_lift_i = -1
	_crane_state = "clear"
	# (back up clear of the deck and out of the way)
	_plan_move(_hook() + Vector3(0, 8.0, 0), false)

## The crane's lift was overtaken (our slab's done): it's set down where
## it's going.
func _drop_lift() -> void:
	var l: Dictionary = _lifts[_lift_i]
	if l["state"] == "fly":
		_land(l)
	else:
		l["state"] = "wait"
		_lift_i = -1
		_crane_state = ""
	_hide_slings()

func _hide_slings() -> void:
	for s in _slings:
		s.visible = false

## Two-leg sling from the hook to the load's ends; `on` 0..1 as the
## dogman hooks it up (or unhooks it).
func _slings_to(node: Node3D, on: float) -> void:
	var hook := _hook() - Vector3(0, 0.3, 0)
	for i in 2:
		var end := node.global_transform * Vector3(-1.0 if i == 0 else 1.0, float(node.get_meta("lug_y", 0.3)), 0)
		var dangle := hook + Vector3(-0.15 if i == 0 else 0.15, -1.0, 0)
		_line(_slings[i], hook, dangle.lerp(end, on))

static func _line(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var ln := d.length()
	if ln < 0.01:
		m.visible = false
		return
	m.visible = true
	var dir := d / ln
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	m.transform = Transform3D(Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, -PI * 0.5), (a + b) * 0.5)
	m.scale = Vector3(1, ln, 1)

func _draw_dogman(l: Dictionary) -> void:
	var dog := _crew[0]
	var at: Vector3 = l["to"] if _crane_state in ["lift", "land"] else l["pick"]
	dog.set_meta("dog_at", at)

# ------------------------------------------------------------------ the crew

## Where each of the crew should be working right now (local), and whether
## they're up on the new deck.
func _spots() -> Array:
	var out := []
	var n := _cols.size()
	var deck_y := SOFFIT
	var b := progress
	for i in _crew.size():
		var fixer := i < 4
		var at := Vector3(16.0 + i * 0.8, 0.0, -5.0)
		if b >= 0.97 or poured:
			# Done: stood at the link watching ours go in
			at = Vector3(15.0 + i * 0.9, TOP if poured else deck_y, -3.5 - (i % 2) * 1.2)
		elif fixer:
			if b < ST["cast"][0]:
				var ci := clampi(int(_u("cages") * n) + (i % 2), 0, n - 1)
				at = Vector3(_cols[ci].x + 0.7, 0, _cols[ci].y + (0.7 if i < 2 else -0.7))
				if i >= 2 and _u("core_reo") < 1.0:
					at = Vector3(CORE_C.x - 1.0 + i, 0, CORE_C.y + CORE_S.y * 0.5 + 0.6)
			elif b < ST["bottom"][0]:
				# Cutting and bending on the floor below while the deck goes down
				# (then up on the ply to stage the bundles)
				at = Vector3(CORE_C.x - 6.0 + i * 1.3, deck_y if b > 0.42 else 0.0, -15.0 if b > 0.42 else -12.0)
			elif b < ST["pt"][0]:
				var bu := _u("bottom")
				var split: int = _bars["bottom"].get_meta("split")
				var total: int = _bars["bottom"].multimesh.instance_count
				var share := float(split) / float(total)
				if bu < share:
					var z := lerpf(-19.5, 1.5, bu / share)
					at = Vector3(lerpf(x0 + 6.0, x1 - 6.0, (i + 0.5) / 4.0), deck_y, z)
				else:
					var x := lerpf(x0 + 1.0, x1 - 2.0, (bu - share) / (1.0 - share))
					at = Vector3(x, deck_y, -17.0 + i * 5.0)
			elif b < ST["top"][0]:
				var x := lerpf(x0 + 1.0, x1 - 2.0, _u("pt"))
				at = Vector3(x, deck_y, -16.0 + i * 4.5)
			else:
				var ci := clampi(int((_u("top") if b < ST["starters"][0] else _u("starters")) * n) + int(i / 2.0), 0, n - 1)
				at = Vector3(_cols[ci].x + (0.9 if i % 2 == 0 else -0.9), deck_y, _cols[ci].y + 0.5)
		else:
			if b < ST["cast"][0]:
				# On the column boxes and the core forms
				var ci := clampi(int(_u("col_form") * n), 0, n - 1)
				at = Vector3(_cols[ci].x - 0.8, 0, _cols[ci].y) if i == 4 else Vector3(CORE_C.x + CORE_S.x * 0.5 + 0.7, 0, CORE_C.y)
			elif b < ST["edge"][0]:
				# One standing props ahead, one laying ply behind
				var px := lerpf(x0, x1 + 3.0, _u("props"))
				at = Vector3(px - 0.5, 0.0, -14.0) if i == 4 else Vector3(maxf(x0 + 1.0, ply_x(b) - 0.6), deck_y, -7.0)
			elif b < ST["edge"][1] + 0.04:
				var e := clampi(int(_u("edge") * plan.size()), 0, plan.size() - 1)
				var p: Vector2 = plan[e]
				var q: Vector2 = plan[(e + 1) % plan.size()]
				var m := p.lerp(q, 0.5 + (0.2 if i == 4 else -0.2))
				var inward := (q - p).orthogonal().normalized() * -0.8
				at = Vector3(m.x + inward.x, deck_y, m.y + inward.y)
			else:
				# Back down the floor below, back-propping and cleaning up
				at = Vector3(x1 - 10.0 - (i - 4) * 6.0, 0.0, -9.0)
		out.append(at)
	# The dogman's on the load while the crane has one
	if _lift_i >= 0 and _crew[0].has_meta("dog_at"):
		var d: Vector3 = _crew[0].get_meta("dog_at")
		var local := d - Vector3(0, position.y, 0)
		if _crane_state in ["lift", "land"]:
			out[0] = Vector3(local.x + 1.6, maxf(0.0, local.y), local.z + 1.2)
	return out

func _update_crew(delta: float) -> void:
	var spots := _spots()
	# The slinger walks to each load on the laydown and hooks it on
	var rigging := _lift_i >= 0 and _crane_state in ["to_pick", "rig"]
	var sg := Vector3(LAYDOWN_X0 - 2.0, 0, LAYDOWN_Z + 1.6)
	if rigging:
		sg = _lifts[_lift_i]["pick"] + Vector3(1.3, 0, 1.0)
	var sd := sg - _slinger.position
	sd.y = 0.0
	var s_moving := sd.length() > 0.3
	if s_moving:
		_slinger.position += sd.normalized() * minf(sd.length(), 2.2 * delta)
		_slinger.rotation.y = atan2(sd.x, sd.z)
	var sph := _t * 8.0
	(_slinger.get_node("LegL") as Node3D).rotation.x = sin(sph) * (0.5 if s_moving else 0.0)
	(_slinger.get_node("LegR") as Node3D).rotation.x = -sin(sph) * (0.5 if s_moving else 0.0)
	var up := rigging and _crane_state == "rig" and not s_moving
	(_slinger.get_node("ArmR") as Node3D).rotation = Vector3(-2.6 if up else 0.0, 0, 0.25)
	(_slinger.get_node("ArmL") as Node3D).rotation = Vector3(-1.2 if up else 0.0, 0, -0.25)
	_slinger.visible = visible
	for i in _crew.size():
		var n := _crew[i]
		var goal: Vector3 = spots[i]
		# (spread the crew so two don't stand in each other)
		goal += Vector3(sin(i * 2.4) * 0.35, 0, cos(i * 2.4) * 0.35)
		var d := goal - n.position
		var flat := Vector3(d.x, 0, d.z)
		var dist := flat.length()
		var moving := dist > 0.3
		var spd := 1.8 if dist < 12.0 else 5.0
		if dist > 25.0:
			# (a long way: they've gone by the stairs; just be there)
			n.position = goal
			moving = false
		elif moving:
			n.position += flat / dist * minf(dist, spd * delta)
			n.rotation.y = atan2(flat.x, flat.z)
		n.position.y = move_toward(n.position.y, goal.y, 2.5 * delta)
		var ph := _t * 8.0 + i
		(n.get_node("LegL") as Node3D).rotation.x = sin(ph) * (0.5 if moving else 0.0)
		(n.get_node("LegR") as Node3D).rotation.x = -sin(ph) * (0.5 if moving else 0.0)
		var arm_l := n.get_node("ArmL") as Node3D
		var arm_r := n.get_node("ArmR") as Node3D
		var head := n.get_node("Head") as Node3D
		if i == 0 and _lift_i >= 0 and _crane_state in ["lift", "land"] and not moving:
			# Dogman: one arm up to the crane, eyes on the load
			arm_r.rotation = Vector3(-2.7, 0, 0.2)
			arm_l.rotation = Vector3(-0.3 + 0.25 * sin(_t * 3.0), 0, -0.25)
			head.rotation.x = -0.35
		elif moving or progress >= 0.97 or poured:
			arm_l.rotation = Vector3(-sin(ph) * (0.4 if moving else 0.0), 0, -0.25)
			arm_r.rotation = Vector3(sin(ph) * (0.4 if moving else 0.0), 0, 0.25)
			head.rotation.x = 0.0
		else:
			# Tying bar / fixing: bent to it, hands busy
			arm_l.rotation = Vector3(-1.1 + 0.25 * sin(_t * 11.0 + i), 0, -0.2)
			arm_r.rotation = Vector3(-1.0 - 0.25 * sin(_t * 11.0 + i * 1.7), 0, 0.2)
			head.rotation.x = 0.45

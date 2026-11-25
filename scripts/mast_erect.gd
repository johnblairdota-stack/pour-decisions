## Spire's first day: the placing boom goes up. It stands free on its X base ("crucifix") on the
## podium's roof till the first climb, as SCP's unit 531 does (John's photos, 24 Nov 2026):
##   1. X BASE    a dogger slings it, the crane flies it over the cast-in rods, the dogger radios
##                it down, it's packed level on timber and the clamp plates are nutted down
##   2. COLUMN    the 11 m section, then the 9 m: slung lying down, stood up on the hook, called down,
##                bolted to the base's flange (M30s) or pinned to the section under it, and the rigger
##                goes up its ladder to let the hook go. The pipe in its face is clamped on as it goes
##   3. ADAPTOR   on the crane, 4 pins
##   4. BOOM      folded, on four chains: 4 pins (like the adaptor), and the rigger's out on it to unchain it
##   5. PLUG IN   the bend onto the foot of the line, the power lead in
##   6. TEST      the mobilisation test: unfold it, swing it, and the emergency stop
## Every step's a row in `steps` (built in start()); bots do any job nobody's doing.
## What's read off the photos or guessed, not published: the X base's size, how many rods and nuts, the
## order of the test. SCP's own site says only that a mast free-stands on a static base to about 20 m.
extends Node3D

signal finished

const F := preload("res://scripts/factory.gd")
const LineScript := preload("res://scripts/line.gd")
const SpireSite := preload("res://scripts/spire_site.gd")
const UI := preload("res://scripts/ui.gd")
const Trades := preload("res://scripts/trades.gd")
const ZBoom := preload("res://scripts/zboom.gd")

const HELP_T := 25.0        # s before a bot takes over a job a person's left
const REACH := 1.5          # m from a job on the roof
const HOVER := 1.0          # m over its seat the crane stops with a load, for the dogger to radio down
const LIE_Y := 0.62         # m a section's middle is off the roof, lying on its dunnage

var game
var active := false
var open_air := true
var steps: Array = []
var si := -1
var step := ""
var step_t := 0.0
var prog := 0.0
var count := 0
var foot := 0.0             # the roof it stands on
var to_head := 0.0          # the boom's head once it's up
var stood := 0.0            # m of column stood and fixed
var _absent := {}
var pen := false            # Spire: the column's lowered into its penetration, no X base (John, 25 Nov)
var col_foot := 0.0         # the slab its legs sit on (Spire: a floor under the roof the day's worked from)
var zn := "deck"            # where the work is: Spire's podium roof ("deck"), the water tower's yard ("ground")

# The crane (climb.gd's, borrowed)
var hook_pos := Vector3.ZERO
var _way: Array = []
var _load: Node3D
var _load_off := Vector3.ZERO
var _col_slung := false     # the hook's still on the top of the column just stood
var _slings: Array[MeshInstance3D] = []
var _saved_borrow: Callable
var _tag: Label3D
var _who: Dictionary = {}

# The kit laid out on the roof
var _base: Node3D
var _hold: Node3D
var _hold_n := 0
var _secs: Array = []       # the sections' stand-ins, lying down: {node, len}
var _adaptor: Node3D
var _lead: MeshInstance3D
var _bend: Node3D

func _ready() -> void:
	for i in 4:
		var s := F.cylinder(0.025, 1.0, F.color_mat(Color("3a3d42")), Vector3.ZERO, 5)
		s.visible = false
		add_child(s)
		_slings.append(s)
	_tag = F.label3d("", 34, Color("ffc72c"))
	_tag.visible = false
	_tag.no_depth_test = true
	add_child(_tag)

# ------------------------------------------------------------------ places

func _m() -> Vector3:
	var m: Vector3 = game.erect_foot()
	return Vector3(m.x, foot, m.z)

## The nearest spot on the roof's slab to `p`.
func _on_deck(p: Vector3) -> Vector3:
	var g = game
	for r in [0.0, 1.0, 2.0, 3.0, 4.5, 6.0, 8.0]:
		for a in 12:
			var q: Vector3 = p + Vector3(cos(a * TAU / 12.0), 0, sin(a * TAU / 12.0)) * r
			q.y = foot
			if (zn == "ground" or g.on_pad(q)) and g._walkable(q, zn):
				return q
	return Vector3(p.x, foot, p.z)

## Where the kit's laid out, from the column's foot. The water tower's yard runs off to +x on the far
## side of the tower from the tank; Spire's roof is open to +x and +z.
func _lay(key: String) -> Vector3:
	var spire := {"base": Vector3(5.5, 0, 2.5), "sec": Vector3(3.5, 0, 5.0), "sec_dz": Vector3(0, 0, 1.7), "adaptor": Vector3(8.0, 0, 2.5),
		"boom": Vector3(11.0, 0, 2.5), "dog": Vector3(2.6, 0, 2.4), "remote": Vector3(4.0, 0, 3.6)}
	var water := {"base": Vector3(4.5, 0, -1.0), "sec": Vector3(3.2, 0, -3.3), "sec_dz": Vector3(0, 0, -1.6), "adaptor": Vector3(6.8, 0, -1.0),
		"boom": Vector3(9.5, 0, -1.2), "dog": Vector3(2.8, 0, -1.8), "remote": Vector3(4.2, 0, -2.4)}
	return (water if zn == "ground" else spire)[key]

## Spire: the roof the kit's laid out on, as bare grey concrete, so the white column, base and boom
## read against it (the model's slab is near white: John, 25 Nov).
func _roof_slab() -> void:
	var poly: PackedVector2Array = SpireSite.poly("plate")
	var tris := Geometry2D.triangulate_polygon(poly)
	if tris.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in tris:
		var q := poly[i]
		st.add_vertex(Vector3(q.x, 0, q.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = F.color_mat(Color("7c807d"))
	mi.position.y = foot + 0.03
	add_child(mi)

func _base_rest() -> Vector3:
	return _on_deck(_m() + _lay("base"))

func _sec_rest(i: int, l := 11.0) -> Vector3:
	var p := _on_deck(_m() + _lay("sec") + _lay("sec_dz") * i)
	if zn == "deck":
		# (a section lies from here out to +x: slid back along the roof till the whole length, and a
		# metre past each end, is inside the edge scaffold)
		for back in 40:
			var q := p - Vector3(0.5 * back, 0, 0)
			var ok := true
			for t in [-1.0, 0.0, l * 0.25, l * 0.5, l * 0.75, l, l + 1.0]:
				for dz in [-0.7, 0.7]:
					var e := Vector3(q.x + t, foot, q.z + dz)
					if not game.on_pad(e):
						ok = false
			if ok:
				p = q
				break
	return Vector3(p.x, foot + LIE_Y, p.z)

func _adaptor_rest() -> Vector3:
	var p := _on_deck(_m() + _lay("adaptor"))
	return Vector3(p.x, foot + 0.2, p.z)

func _boom_rest() -> Vector3:
	var p := _on_deck(_m() + _lay("boom"))
	return Vector3(p.x, foot + 0.1, p.z)

func _dog_spot() -> Vector3:
	return _on_deck(_m() + _lay("dog"))

func _base_spot(i: int) -> Vector3:
	var s := -1.0 if zn == "ground" else 1.0
	return _on_deck(_m() + [Vector3(1.9, 0, 1.2 * s), Vector3(-0.2, 0, 2.1 * s), Vector3(1.4, 0, 2.0 * s)][i])

func _remote_spot() -> Vector3:
	return _on_deck(_m() + _lay("remote"))

func _deck_wait(role: String) -> Vector3:
	var off := {"pump": Vector3(2.4, 0, 3.4), "hose": Vector3(3.4, 0, 3.8), "boom": Vector3(2.6, 0, 2.4), "line": Vector3(5.0, 0, 4.0),
		"poker": Vector3(6.5, 0, 6.5), "screed": Vector3(7.5, 0, 5.5)}
	var o: Vector3 = off.get(role, Vector3(6, 0, 6))
	if zn == "ground":
		o.z = -o.z * 0.6
	return _on_deck(_m() + o)

func _col_top() -> Vector3:
	return Vector3(_m().x, col_foot + stood, _m().z)

# ------------------------------------------------------------------ the day

func start() -> void:
	var g = game
	active = true
	zn = "ground" if g.tutorial else "deck"
	pen = not g.tutorial
	foot = g.erect_deck_y()
	col_foot = g.erect_foot().y
	to_head = g.erect_head_y()
	stood = 0.0
	_absent = {}
	_col_slung = false
	_load = null
	_hold_n = 0
	var length: float = to_head - 0.62 - col_foot
	if pen:
		_start_pen(length)
		return
	# (an 11 m section on the base, then a 9 m: ZBoom.joints)
	var lens: Array = []
	var prev := 0.0
	for jy in ZBoom.joints(length):
		if float(jy) > 2.0:
			lens.append(float(jy) - prev)
			prev = float(jy)
	if length - prev > 1.2 or lens.is_empty():
		lens.append(length - prev)
	else:
		lens[lens.size() - 1] += length - prev
	# Nothing's stood yet: the boom's folded on the roof, the column's in lengths beside it
	g.erect_column(0.0, true)
	g.line.rebuild_riser()
	if zn == "ground":
		# (nothing's up to climb yet: the whole crew starts the day in the yard)
		for p in g.players:
			if p.zone != "ground":
				p.zone = "ground"
				p.busy = ""
				p.position = _deck_wait(p.role)
	g.climb.park_stage = "done"
	g.climb.park_slew = 1.0
	g.climb.park_fold = 1.0
	g.head.position = _boom_rest()
	_hold = ZBoom.xbase_hold(0)
	_hold.position = _m()
	add_child(_hold)
	if zn == "deck":
		_roof_slab()
	_base = ZBoom.xbase()
	_base.position = _base_rest() + Vector3(0, 0.1, 0)
	_base.set_meta("att", [Vector3(0.7, 0.5, 0.7), Vector3(-0.7, 0.5, 0.7), Vector3(0.7, 0.5, -0.7), Vector3(-0.7, 0.5, -0.7)])
	add_child(_base)
	_secs = []
	for i in lens.size():
		var n := ZBoom.section(float(lens[i]), SpireSite.COLUMN * 0.5)
		n.position = _sec_rest(i, float(lens[i]))
		n.rotation.z = PI * 0.5
		n.set_meta("len", float(lens[i]))
		n.set_meta("att", [Vector3(0.16, 0.25, 0), Vector3(-0.16, 0.25, 0)])
		add_child(n)
		_secs.append({"node": n, "len": float(lens[i])})
	_adaptor = Node3D.new()
	_adaptor.add_child(F.box(Vector3(1.2, 0.26, 1.2), F.color_mat(Color("eceeed"))))
	for sx in [-0.42, 0.42]:
		for sz in [-0.42, 0.42]:
			_adaptor.add_child(F.box(Vector3(0.1, 0.32, 0.24), F.color_mat(Color("d3202f")), Vector3(sx, 0.29, sz)))
	_adaptor.position = _adaptor_rest()
	_adaptor.set_meta("att", [Vector3(0.45, 0.3, 0.0), Vector3(-0.45, 0.3, 0.0)])
	add_child(_adaptor)
	g.head.set_meta("att", [Vector3(0.7, 1.0, 0.5), Vector3(-0.7, 1.0, 0.5), Vector3(0.7, 1.0, -0.5), Vector3(-0.7, 1.0, -0.5)])
	_saved_borrow = g.climb.borrow
	g.climb.borrow = Callable(self, "_crane")
	hook_pos = Vector3(g.climb.trolley_xz.x, g.climb.CRANE_H - g.climb.cable_len, g.climb.trolley_xz.y)
	_way = []
	_build_steps(lens)
	si = -1
	_next()
	g.hud.toast("Erection day: the X base, %.0f m of column and the boom go up on the crane" % length, 3.5)
	var lines: Array = []
	for role in ["boom", "pump", "poker", "hose", "line", "screed"]:
		if g.crew.crew.get(role) != null:
			lines.append("%s · %s" % [who_text(role), JOBS[role]])
	g.hud.job_intro("ERECTION DAY · WHO DOES WHAT", "\n".join(lines), UI.GOLD, 14.0)

# ------------------------------------------------------------------ Spire: into the penetration

var _col_lie: Node3D        # the whole column lying on the roof, its sections in a line, top at its origin
var _joint_at: Array = []   # where each lying joint is on the roof
const GAP := 0.45           # m the lying sections are apart till they're pinned

## Spire's day: the sections are pinned together lying on the roof (all of it at floor level), the crane
## stands the whole column up and lowers it down through the opening while a rigger at the opening radios
## it to its mark, its red legs go out onto the rubber pads on the floor below and it's wedged at both
## floors; then the crow's nest's last side, the adaptor, the boom, the test.
func _start_pen(length: float) -> void:
	var g = game
	var lens: Array = []        # from the top down: the crow's nest section first
	var prev := length
	var js: Array = ZBoom.joints(length, true)
	js.reverse()
	for jy in js:
		lens.append(prev - float(jy))
		prev = float(jy)
	lens.append(prev)
	g.spire_col_nest = 0
	g.spire_col_fix = 0
	g.erect_column(0.0, true)
	g.line.rebuild_riser()
	g.climb.park_stage = "done"
	g.climb.park_slew = 1.0
	g.climb.park_fold = 1.0
	g.head.position = _boom_rest()
	_hold = null
	_base = null
	_roof_slab()
	# The column, lying: the crow's nest section on the flat side of its U platform
	_col_lie = Node3D.new()
	_col_lie.position = _sec_rest(0, length + GAP * (lens.size() - 1))
	_col_lie.rotation.z = PI * 0.5
	_col_lie.set_meta("len", length)
	_col_lie.set_meta("att", [Vector3(0.16, 0.25, 0), Vector3(-0.16, 0.25, 0)])
	add_child(_col_lie)
	_secs = []
	_joint_at = []
	var cum := 0.0
	for i in lens.size():
		var n := ZBoom.section(float(lens[i]), SpireSite.COLUMN * 0.5)
		n.position.y = -(cum + GAP * i)
		n.set_meta("y", -cum)
		_col_lie.add_child(n)
		if i == 0:
			for part in ZBoom.nest_parts(-1.15, false):
				n.add_child(part)
		_secs.append({"node": n, "len": float(lens[i])})
		cum += float(lens[i])
		if i < lens.size() - 1:
			_joint_at.append(_col_lie.position + Vector3(cum + GAP * i, 0, 0))
	_adaptor = Node3D.new()
	_adaptor.add_child(F.box(Vector3(1.2, 0.26, 1.2), F.color_mat(Color("eceeed"))))
	for sx in [-0.42, 0.42]:
		for sz in [-0.42, 0.42]:
			_adaptor.add_child(F.box(Vector3(0.1, 0.32, 0.24), F.color_mat(Color("d3202f")), Vector3(sx, 0.29, sz)))
	_adaptor.position = _adaptor_rest()
	_adaptor.set_meta("att", [Vector3(0.45, 0.3, 0.0), Vector3(-0.45, 0.3, 0.0)])
	add_child(_adaptor)
	g.head.set_meta("att", [Vector3(0.7, 1.0, 0.5), Vector3(-0.7, 1.0, 0.5), Vector3(0.7, 1.0, -0.5), Vector3(-0.7, 1.0, -0.5)])
	_saved_borrow = g.climb.borrow
	g.climb.borrow = Callable(self, "_crane")
	hook_pos = Vector3(g.climb.trolley_xz.x, g.climb.CRANE_H - g.climb.cable_len, g.climb.trolley_xz.y)
	_way = []
	_build_steps_pen(lens, length)
	si = -1
	_next()
	g.hud.toast("Install day: %.0f m of column goes down into the penetration, then the boom" % length, 3.5)
	var lines: Array = []
	for role in ["boom", "pump", "poker", "hose", "line", "screed"]:
		if g.crew.crew.get(role) != null:
			lines.append("%s · %s" % [who_text(role), JOBS_PEN[role]])
	g.hud.job_intro("INSTALL DAY · WHO DOES WHAT", "\n".join(lines), UI.GOLD, 14.0)

const JOBS_PEN := {
	"boom": "tests the boom on the remote: unfold, swing, emergency stop",
	"pump": "pins the sections together on the roof, then the crow's nest's last side, the adaptor's 4 pins and the boom's 4, harnessed",
	"poker": "stands at the opening and radios the crane up and down to the mark, pushes the legs out onto the pads, wedges it",
	"hose": "clamps the pipe and ladder across each joint, fits the bend and the power lead",
	"line": "slings each load for the crane: column, adaptor, boom",
	"screed": "radios the adaptor and the boom down onto their seats"}

func _build_steps_pen(lens: Array, length: float) -> void:
	steps = []
	var m := _m()
	var top := col_foot + length
	var open_at := _on_deck(m + Vector3(1.5, 0, 1.3))
	# 1. pinned together lying on the roof: no one works off the hook
	for j in _joint_at.size():
		var at: Vector3 = _joint_at[j]
		var spot := _on_deck(Vector3(at.x + GAP * 0.5, foot, at.z + 1.0))
		steps.append(_job("pin_joint%d" % j, 0, "pump", "drive a joint pin", 4, 0.5, "Joint %d of %d: pins in, on the roof" % [j + 1, _joint_at.size()], spot))
		steps.append(_job("pipe_joint%d" % j, 0, "hose", "clamp the pipe and ladder", 2, 0.7, "Clamp pipe and ladder over the joint", spot + Vector3(0.9, 0, 0)))
	# 2. stood up and lowered in
	var seat := Vector3(m.x, top, m.z)
	var drop := (foot - col_foot) + 1.0
	steps.append(_job("sling_col", 1, "line", "shackle its two lugs", 2, 0.6, "Sling the column by its top lugs", _on_deck(_col_lie.position + Vector3(-0.9, -LIE_Y, 0.6))))
	steps.append({"id": "fly_col", "kind": "fly", "stage": 1, "load": _col_lie, "seat": seat, "hover": drop, "say": "Crane stands the column up over the opening"})
	steps.append({"id": "land_col", "kind": "land", "stage": 1, "role": "poker", "zone": zn, "at": open_at, "verb": "hold: radio it down to the mark", "n": 1, "t": 5.0, "load": _col_lie, "seat": seat, "hover": drop,
		"say": "At the opening: radio it down to the mark"})
	# 3. legs and wedges
	steps.append(_job("legs", 2, "poker", "push a leg out onto its pad", 4, 0.7, "Floor below: legs out onto the rubber pads", null, col_foot + 0.2))
	steps.append(_job("wedge_low", 2, "poker", "drive a corner wedge", 4, 0.5, "Corner plates and wedges, floor below", null, col_foot + 0.2))
	steps.append(_job("wedge_top", 2, "hose", "drive a corner wedge", 4, 0.5, "Corner plates and wedges at the roof", open_at))
	steps.append(_job("unsling_col", 2, "pump", "let the hook go", 2, 0.6, "Up its ladder: hook off", null, top - 1.13))
	# 4. the crow's nest
	steps.append(_job("nest", 3, "pump", "harness on, click the last side in", 2, 0.9, "Harness on: crow's nest, last side on", null, top - 1.13))
	# 5. the adaptor, 6. the boom, 7. plug in, 8. the test: as the water tower's
	_steps_top(4, m, top)
	_stage_names = ["JOIN ON ROOF", "LOWER IN", "LEGS + WEDGES", "CROW'S NEST", "ADAPTOR", "BOOM ON", "PLUG IN", "TEST"]

## Who does what, by trade (trades.gd CLIMB_SEAT "erect"): doggers sling and call the loads, riggers
## nut, bolt, pin and let the hook go, pumpies fit the pipe, the bend and the power and test the boom.
const JOBS := {
	"boom": "tests the boom on the remote: unfold, swing, emergency stop",
	"pump": "nuts the clamp plates, bolts the flange, drives the joint pins, the adaptor's 4 pins, then harnessed on the boom its 4 pins and the chains off",
	"poker": "packs the base level, and climbs the column to let the hook go",
	"hose": "clamps the pipe up the column, fits the bend and the power lead",
	"line": "slings each load for the crane: base, column, adaptor, boom",
	"screed": "radios every load down onto its seat: the crane op goes on what they say"}

func _job(id: String, stage: int, role: String, verb: String, n: int, t: float, say: String, at = null, y := -1000.0) -> Dictionary:
	var d := {"id": id, "kind": "job", "stage": stage, "role": role, "verb": verb, "n": n, "t": t, "say": say}
	if y > -999.0:
		d["zone"] = "ladder"
		d["y"] = y
	else:
		d["zone"] = zn
		d["at"] = at
	return d

## The day, a row a step. kind "job": a hand job (n goes of t seconds); "fly": the crane brings `load` to
## hover over `seat`; "land": the dogger holds to radio it down onto `seat`; "test": the boom on the remote.
func _build_steps(lens: Array) -> void:
	steps = []
	var m := _m()
	var names: Array = []
	for l in lens:
		names.append("%.0f m section" % float(l))
	# 1. the X base
	steps.append(_job("sling_base", 0, "line", "sling the X base", 4, 0.5, "Sling the X base", _base_rest() + Vector3(1.5, 0, 0.9)))
	steps.append({"id": "fly_base", "kind": "fly", "stage": 0, "load": _base, "seat": m, "say": "Crane flies the X base in"})
	steps.append({"id": "land_base", "kind": "land", "stage": 0, "role": "screed", "zone": zn, "at": _dog_spot(), "verb": "hold: radio it down", "n": 1, "t": 2.6, "load": _base, "seat": m, "say": "Radio it down between the rods"})
	steps.append(_job("pack_base", 0, "poker", "pack it level", 4, 0.7, "Pack the base level", _base_spot(0)))
	steps.append(_job("nut_base", 0, "pump", "nut down the clamp plate", 4, 0.9, "Clamp plates on, nuts down", _base_spot(1)))
	steps.append(_job("unsling_base", 0, "line", "unhook the base", 1, 0.8, "Slings off the base", _base_spot(2)))
	# 2. the column
	var cum := 0.0
	for i in lens.size():
		var l: float = lens[i]
		var n: Node3D = _secs[i]["node"]
		var seat := m + Vector3(0, cum + l, 0)
		var st := 1 + i
		var rest := _sec_rest(i, float(lens[i]))
		steps.append(_job("sling_sec%d" % i, st, "line", "shackle its two lugs", 2, 0.6, "Sling the %s" % names[i], _on_deck(Vector3(rest.x - 0.9, foot, rest.z + 0.3))))
		steps.append({"id": "fly_sec%d" % i, "kind": "fly", "stage": st, "load": n, "seat": seat, "say": "Crane stands the %s up" % names[i]})
		steps.append({"id": "land_sec%d" % i, "kind": "land", "stage": st, "role": "screed", "zone": zn, "at": _dog_spot(), "verb": "hold: radio it down", "n": 1, "t": 2.6, "load": n, "seat": seat,
			"say": "Radio it down onto the %s" % ("base" if i == 0 else "joint")})
		if i == 0:
			steps.append(_job("fix_sec0", st, "pump", "bolt the flange (M30)", 8, 0.5, "Bolt the flange to the base", _base_spot(1)))
		else:
			steps.append(_job("fix_sec%d" % i, st, "pump", "drive a joint pin", 8, 0.5, "8 joint pins, hand tight", null, foot + cum - 0.6))
			steps.append(_job("pipe_sec%d" % i, st, "hose", "clamp the pipe and ladder", 2, 0.7, "Clamp pipe and ladder", null, foot + cum - 0.6))
		steps.append(_job("unsling_sec%d" % i, st, "poker", "let the hook go", 2, 0.6, "Up the ladder: hook off", null, foot + cum + l - 0.9))
		cum += l
	var top := foot + cum
	var st2 := 1 + lens.size()
	_steps_top(st2, m, top)
	_stage_names = ["X BASE"]
	for nm in names:
		_stage_names.append(String(nm).to_upper())
	_stage_names.append_array(["ADAPTOR", "BOOM ON", "PLUG IN", "TEST"])

## The adaptor, the boom, plugging in and the mobilisation test, from stage `st2`: the same on any column.
func _steps_top(st2: int, m: Vector3, top: float) -> void:
	# 3. the adaptor
	steps.append(_job("sling_ad", st2, "line", "sling the adaptor", 2, 0.6, "Sling the adaptor", _adaptor_rest() + Vector3(0.2, -0.2, 1.1)))
	steps.append({"id": "fly_ad", "kind": "fly", "stage": st2, "load": _adaptor, "seat": Vector3(m.x, top + 0.13, m.z), "say": "Crane lifts the adaptor"})
	steps.append({"id": "land_ad", "kind": "land", "stage": st2, "role": "screed", "zone": zn, "at": _dog_spot(), "verb": "hold: radio it down", "n": 1, "t": 2.2, "load": _adaptor, "seat": Vector3(m.x, top + 0.13, m.z), "say": "Radio the adaptor down"})
	steps.append(_job("pin_ad", st2, "pump", "pin the adaptor", 4, 0.5, "4 adaptor pins", null, top - 1.13))
	# 4. the boom
	steps.append(_job("sling_boom", st2 + 1, "line", "chain the boom", 4, 0.6, "Chain the folded boom", _boom_rest() + Vector3(0.4, -0.1, 1.6)))
	steps.append({"id": "fly_boom", "kind": "fly", "stage": st2 + 1, "load": game.head, "seat": Vector3(m.x, to_head, m.z), "say": "Crane lifts the boom"})
	steps.append({"id": "land_boom", "kind": "land", "stage": st2 + 1, "role": "screed", "zone": zn, "at": _dog_spot(), "verb": "hold: radio it down", "n": 1, "t": 3.0, "load": game.head, "seat": Vector3(m.x, to_head, m.z), "say": "Radio the boom down"})
	steps.append(_job("harness", st2 + 1, "pump", "harness on, climb onto the boom", 1, 1.2, "Harness on, onto the boom", null, top - 1.13))
	steps.append(_job("pin_boom", st2 + 1, "pump", "pin the boom", 4, 0.5, "4 boom pins", null, top - 1.13))
	steps.append(_job("unchain", st2 + 1, "pump", "unchain the boom", 4, 0.6, "Clip on, chains off", null, top - 1.13))
	# 5. plug in
	steps.append(_job("bend", st2 + 2, "hose", "clamp the bend on", 2, 0.8, "Bend onto the line's foot", _base_spot(0)))
	steps.append(_job("power", st2 + 2, "hose", "plug in the power lead", 1, 1.2, "Plug in the power lead", _base_spot(2)))
	# 6. the mobilisation test
	steps.append({"id": "test_unfold", "kind": "test", "stage": st2 + 3, "role": "boom", "zone": zn, "at": _remote_spot(), "verb": "hold: unfold it, arm by arm", "n": 1, "t": 5.0, "say": "Test: unfold on the remote"})
	steps.append({"id": "test_slew", "kind": "test", "stage": st2 + 3, "role": "boom", "zone": zn, "at": _remote_spot(), "verb": "hold: swing it round", "n": 1, "t": 4.0, "say": "Test: swing it round"})
	steps.append(_job("test_estop", st2 + 3, "boom", "hit the emergency stop", 1, 0.5, "Test: emergency stop", _remote_spot()))
	steps.append(_job("test_look", st2 + 3, "pump", "check pins, hoses, leaks", 3, 0.8, "Check pins, hoses, leaks", null, top - 1.13))

var _stage_names: Array = []

func job() -> Dictionary:
	if not active or si < 0 or si >= steps.size():
		return {}
	var s: Dictionary = steps[si]
	if s["kind"] == "fly":
		return {}
	return s

func _next() -> void:
	si += 1
	if si >= steps.size():
		_finish()
		return
	var s: Dictionary = steps[si]
	step = s["id"]
	step_t = 0.0
	prog = 0.0
	count = 0
	var who := ""
	if s.has("role"):
		var p = game.crew.crew.get(s["role"])
		if p != null:
			who = " · " + p.char_name
	game.hud.toast("Erect · %s%s" % [s["say"], who], 2.4)
	if game.autotest:
		print("[autotest]   mast erect: %s (stood %.1f m) at %.0fs" % [step, stood, game.phase_t])
	game.line.extra_stops = [s["y"]] if s.get("zone", "") == "ladder" else []
	if String(s["id"]).begins_with("sling_") and _load == null and not _col_slung:
		# (the hook comes over to it while it's slung)
		var to := _hook_on(steps[si + 1]["load"])
		_way = [Vector3(hook_pos.x, maxf(hook_pos.y, to.y + 6.0), hook_pos.z), Vector3(to.x, maxf(hook_pos.y, to.y + 6.0), to.z), to]
	if s["kind"] == "fly":
		var load: Node3D = s["load"]
		var seat: Vector3 = s["seat"]
		var clear: float = game.erect_clear_y()
		if _load != load:
			# (the hook's not on it yet: over to it first)
			_load = load
			_load_off = load.global_position - _hook_on(load)
			hook_pos = _hook_on(load)
		var lift: float = float(load.get_meta("len", 0.0))
		var up := maxf(clear, hook_pos.y + lift)
		_way = [Vector3(hook_pos.x, up, hook_pos.z), Vector3(seat.x, up, seat.z), _seat_hook(load, seat) + Vector3(0, float(s.get("hover", HOVER)), 0)]

## Where the hook hangs over `load` as it lies.
func _hook_on(load: Node3D) -> Vector3:
	return load.global_position + Vector3(0, 2.2, 0)

## ...and where it is with `load` on its seat.
func _seat_hook(_load_n: Node3D, seat: Vector3) -> Vector3:
	return seat - _load_off

func _done() -> void:
	var s: Dictionary = steps[si]
	var id: String = s["id"]
	var g = game
	if id.begins_with("sling_"):
		# (the hook's come over while they slung it)
		var load: Node3D = steps[si + 1]["load"]
		_load = load
		_way = []
		hook_pos = _hook_on(load)
		_load_off = load.global_position - hook_pos
		g.sfx.hit("clank")
	elif id.begins_with("pin_joint"):
		# (the next section's drawn up tight to the one above it)
		var j := int(id.right(1))
		for i in range(j + 1, _secs.size()):
			var n: Node3D = _secs[i]["node"]
			n.position.y += GAP
		g.sfx.hit("clank")
	elif id == "land_col":
		stood = float(_col_lie.get_meta("len"))
		_col_lie.visible = false
		_load = null
		_col_slung = true
		hook_pos = _col_top() + Vector3(0, 2.2, 0)
		g.spire_col_nest = 1
		g.erect_column(stood, true)
		g.line.rebuild_riser()
		g.sfx.hit("thunk")
		g.pop("ON THE MARK", _m() + Vector3(1.5, 1.6, 0), Color("7cd992"))
	elif id == "legs":
		g.spire_col_fix = 1
		g.erect_column(stood, true)
		g.sfx.hit("clank")
	elif id == "wedge_top":
		g.spire_col_fix = 2
		g.erect_column(stood, true)
	elif id == "unsling_col":
		_col_slung = false
		_way = [hook_pos + Vector3(0, 8.0, 0)]
	elif id == "nest":
		g.spire_col_nest = 2
		g.erect_column(stood, true)
		g.sfx.hit("clank")
	elif id == "pack_base":
		pass
	elif id == "unsling_base":
		_load = null
		_way = [hook_pos + Vector3(0, 8.0, 0)]
	elif id.begins_with("pipe_sec") or id == "fix_sec0":
		_stand(int(id.right(1)))
	elif id.begins_with("unsling_sec"):
		_col_slung = false
		_way = [hook_pos + Vector3(0, 8.0, 0)]
	elif id == "pin_ad":
		_load = null
		_adaptor.visible = false
		g.erect_column(stood, false)
		_way = [hook_pos + Vector3(0, 6.0, 0)]
	elif id == "unchain":
		_load = null
		_way = [hook_pos + Vector3(0, 8.0, 0)]
		g.head.position = Vector3(_m().x, to_head, _m().z)
	elif id == "bend":
		g.sfx.hit("clank")
	elif id == "test_estop":
		g.pop("E-STOP OK", g.head.global_position + Vector3(0, 1.5, 0), Color("7cd992"))
	_next()

## Section `i`'s fixed: it's column now (its ladder and pipe with it), the hook still on its top.
func _stand(i: int) -> void:
	var g = game
	stood += float(_secs[i]["len"])
	(_secs[i]["node"] as Node3D).visible = false
	_load = null
	_col_slung = true
	hook_pos = _col_top() + Vector3(0, 2.2, 0)
	g.erect_column(stood, true)
	g.line.rebuild_riser()
	g.sfx.hit("thunk")
	g.pop("%.0f m UP" % stood, _col_top() + Vector3(1.5, 0.5, 0), Color("7cd992"))

func _finish() -> void:
	var g = game
	active = false
	step = ""
	g.line.extra_stops = []
	g.climb.borrow = _saved_borrow
	for s in _slings:
		s.visible = false
	_tag.visible = false
	for p in _who:
		if is_instance_valid(_who[p]):
			_who[p].queue_free()
	_who = {}
	for n in [_base, _hold, _adaptor]:
		if n != null:
			n.queue_free()
	for d in _secs:
		(d["node"] as Node).queue_free()
	_secs = []
	if _col_lie != null:
		_col_lie.queue_free()
		_col_lie = null
	g.climb.park_stage = ""
	g.climb.park_slew = 0.0
	g.climb.park_fold = 0.0
	g.hud.toast("The boom's up, on its legs in the penetration, and tested." if pen else "The boom's up, free-standing on its X base, and tested.", 3.0)
	g.score.award(g.crew.crew.get("pump"), 30, "Erection day")
	finished.emit()

# ------------------------------------------------------------------ every frame

func update(delta: float) -> void:
	if not active:
		return
	# (the building's opened up along the column while the work's on the floor below)
	open_air = not bool(focus()[2])
	step_t += delta
	var s: Dictionary = steps[si]
	match String(s["kind"]):
		"fly":
			if _way.is_empty():
				_next()
		"land":
			# (down the last metre as the dogger radios it)
			var seat_hook := _seat_hook(s["load"], s["seat"])
			hook_pos = seat_hook + Vector3(0, float(s.get("hover", HOVER)) * (1.0 - prog), 0)
	# A section comes up off the roof by its top, its foot trailing till it hangs plumb
	if _load != null and _load.has_meta("len"):
		var l: float = _load.get_meta("len")
		var h: float = (hook_pos.y + _load_off.y) - (foot + LIE_Y)
		_load.rotation.z = acos(clampf(h / l, 0.0, 1.0)) if h < l else 0.0
	# The hold-down: a clamp plate on for every go at the nuts
	var want := 4 if si > _step_i("nut_base") else (count if step == "nut_base" else 0)
	if want != _hold_n and _hold != null:
		_hold_n = want
		_hold.queue_free()
		_hold = ZBoom.xbase_hold(want)
		_hold.position = _m()
		add_child(_hold)
	_draw()

func _step_i(id: String) -> int:
	for i in steps.size():
		if steps[i]["id"] == id:
			return i
	return -1

func handle_player(p, delta: float) -> bool:
	if not active:
		return false
	var j := job()
	if j.is_empty() or not _at(p, j):
		return false
	if p.zone == "ladder":
		game.line._ladder(p, delta)
		if absf(p.position.y - float(j["y"])) > 0.35:
			return true
	var kind: String = j["kind"]
	var n: int = j["n"]
	var verb: String = j["verb"]
	if n > 1:
		verb = "%s %d/%d" % [verb, count + 1, n]
	p.cue("action", verb, prog, true)
	if p.action_held():
		prog += delta / maxf(0.05, float(j["t"]))
		if kind == "job":
			p.pose_arms(Vector3(-1.2 + 0.6 * sin(step_t * 14.0), 0, -0.3), Vector3(-1.2 - 0.6 * sin(step_t * 14.0), 0, 0.3))
		elif kind == "test":
			if step == "test_unfold":
				game.climb.park_fold = 1.0 - clampf(prog, 0.0, 1.0)
			else:
				game.climb.park_slew = 1.0 - clampf(prog, 0.0, 1.0)
		if prog >= 1.0:
			prog = 0.0
			count += 1
			game.sfx.hit("thunk" if kind == "job" else "clank")
			if count >= n:
				game.score.award(p, 5 * n if kind == "job" else 15, "Erection day")
				if kind == "land":
					game.pop("DOWN", (j["seat"] as Vector3) + Vector3(0, 0.6, 0), Color("7cd992"))
				_done()
	return true

func _at(p, j: Dictionary) -> bool:
	if String(j["zone"]) == "ladder":
		return p.zone == "ladder" and absf(p.position.y - float(j["y"])) < 1.2
	var at: Vector3 = j["at"]
	return p.zone == zn and Vector2(p.position.x - at.x, p.position.z - at.z).length() < REACH

# ------------------------------------------------------------------ bots

func bot(p, role: String, delta: float) -> bool:
	if not active:
		return false
	if game.autotest and step_t > 60.0 and fmod(step_t, 30.0) < delta:
		print("[autotest]     erect step %s hung %.0fs: job %s | %s %s zone %s at %s busy '%s'" % [step, step_t, str(job().get("verb", "")), role, p.char_name, p.zone, str(p.position), p.busy])
	var b = game.bots
	if p.busy != "":
		# (off the boom's remote, or whatever they were on)
		p.ai_leave = b._tap()
		return true
	var j := job()
	var mine: bool = not j.is_empty() and j["role"] == role
	if not j.is_empty() and not mine and step_t > (6.0 if _absent.has(j["role"]) else HELP_T):
		# (a person's job, and they haven't got to it: a bot steps in for them)
		var owner = game.crew.crew.get(j["role"])
		var back := {"pump": "poker", "poker": "pump", "hose": "boom", "boom": "hose", "line": "screed", "screed": "line"}
		if owner != null and not owner.bot and not owner.covering and back.get(j["role"], "") == role:
			_absent[j["role"]] = true
			mine = true
	if not mine:
		if p.zone == "ladder":
			# (the rigger waits up the column while the crane brings the next piece, if that's theirs)
			if role in ["pump", "poker", "hose"] and _next_zone(role) == "ladder":
				return true
			b._ladder_to(p, game.work_y if zn == "deck" else 0.0, true)
		elif p.zone == zn:
			b.walk(p, _deck_wait(role), 0.6)
		else:
			b.go(p, zn, _deck_wait(role), 0.6)
		return true
	if String(j["zone"]) == "ladder":
		if p.zone == "ladder":
			if b._ladder_to(p, float(j["y"]), false):
				p.ai_action = true
		elif p.zone == "deck":
			if b.walk(p, b._deck("ladder"), 0.5):
				p.ai_action = b._tap()
		else:
			if b.walk(p, b._gnd("ladder_g"), 0.5):
				p.ai_action = b._tap()
	elif b.go(p, zn, j["at"], 0.45):
		p.ai_action = true
	return true

## The zone of `role`'s next job from here on ("" if they've none left).
func _next_zone(role: String) -> String:
	for i in range(si, steps.size()):
		if steps[i].get("role", "") == role:
			return String(steps[i]["zone"])
	return ""

# ------------------------------------------------------------------ the crane

func _crane(delta: float) -> bool:
	var c = game.climb
	if not _way.is_empty():
		var to: Vector3 = _way[0]
		var dxz := Vector2(to.x - hook_pos.x, to.z - hook_pos.z)
		var step_xz := dxz.limit_length(4.5 * delta)
		var dy := clampf(to.y - hook_pos.y, -3.5 * delta, 3.5 * delta)
		if to.y > hook_pos.y + 0.05 and dxz.length() > 0.2:
			step_xz = Vector2.ZERO
		elif to.y < hook_pos.y - 0.05 and dxz.length() > 0.2:
			dy = 0.0
		hook_pos += Vector3(step_xz.x, dy, step_xz.y)
		if hook_pos.distance_to(to) < 0.05:
			hook_pos = to
			_way.pop_front()
	c.trolley_xz = Vector2(hook_pos.x, hook_pos.z)
	c.cable_len = c.CRANE_H - hook_pos.y
	if _load != null:
		_load.global_position = hook_pos + _load_off
	return true

func _draw() -> void:
	var att: Array = []
	if _load != null:
		for a in _load.get_meta("att", []):
			att.append(_load.to_global(a))
	elif _col_slung:
		var t := _col_top()
		att = [t + Vector3(0.16, 0.25, 0), t + Vector3(-0.16, 0.25, 0)]
	for i in _slings.size():
		_slings[i].visible = i < att.size()
		if i < att.size():
			F.stretch(_slings[i], hook_pos, att[i])
	var ja := job_at()
	var j := job()
	var holder = game.crew.crew.get(j.get("role", "")) if not j.is_empty() else null
	_tag.visible = ja != Vector3.INF and not (holder != null and _at(holder, j))
	if _tag.visible:
		_tag.text = "%s\n%s" % [String(j["verb"]).trim_prefix("hold: ").to_upper(), who_text(String(j["role"]))]
		_tag.position = ja + Vector3(0, 1.6 + 0.08 * sin(step_t * 3.0), 0)
	_draw_who(j)

# ------------------------------------------------------------------ for the HUD and the camera

func stages() -> Array:
	return _stage_names

func stage_i() -> int:
	return int(steps[si]["stage"]) if si >= 0 and si < steps.size() else 0

func who_text(role: String) -> String:
	var p = game.crew.crew.get(role)
	var job_name := Trades.climb_full(role, "erect", " ").to_upper()
	if p == null:
		return job_name
	if p.bot:
		return "%s (bot) · %s" % [String(p.char_name).to_upper(), job_name]
	return "P%d %s · %s" % [p.index, String(p.char_name).to_upper(), job_name]

func next_role() -> String:
	for i in range(si + 1, steps.size()):
		if steps[i].has("role"):
			return steps[i]["role"]
	return ""

func _draw_who(j: Dictionary) -> void:
	var now := String(j.get("role", ""))
	var nxt := next_role()
	for p in game.crew.humans():
		var l: Label3D = _who.get(p)
		if l == null or not is_instance_valid(l):
			l = F.label3d("", 54, Color("ffc72c"))
			l.no_depth_test = true
			add_child(l)
			_who[p] = l
		var text := ""
		var mine: bool = p.role == now and not p.covering
		if mine:
			if _at(p, j):
				text = ""
			elif String(j["zone"]) == "ladder":
				text = "YOUR TURN\n%s THE COLUMN'S LADDER" % ("UP" if float(j["y"]) > p.position.y else "DOWN")
			else:
				text = "YOUR TURN\n%s" % String(j["verb"]).trim_prefix("hold: ").to_upper()
		else:
			var on := "THE CRANE'S MOVE" if now == "" else "WAITING ON %s" % who_text(now).get_slice(" · ", 0)
			if p.role == nxt:
				text = "%s\nYOU'RE NEXT" % on
			elif not JOBS.has(p.role):
				text = "%s\nNO JOB TODAY · STAND CLEAR" % on
			else:
				text = on
		l.visible = text != ""
		l.text = text
		l.modulate = Color("ffc72c") if mine else Color("e9e4d6")
		l.position = p.global_position + Vector3(0, 3.3 + (0.08 * sin(step_t * 3.0) if mine else 0.0), 0)
	for p in _who.keys():
		if not is_instance_valid(p) or p.bot:
			if is_instance_valid(_who[p]):
				_who[p].queue_free()
			_who.erase(p)

## For the HUD: [task, who it's on, 0..1 of the day, their job].
func hud_task() -> Array:
	if si < 0 or si >= steps.size():
		return ["Erection day", "", 1.0, ""]
	var s: Dictionary = steps[si]
	var who := "TOWER CRANE"
	if s.has("role") and game.crew.crew.get(s["role"]) != null:
		who = who_text(String(s["role"]))
	return ["Erection day · %s" % String(s["say"]), who, float(si) / float(steps.size()), String(s.get("role", ""))]

func job_at() -> Vector3:
	var j := job()
	if j.is_empty():
		return Vector3.INF
	if String(j["zone"]) == "ladder":
		return Vector3(LineScript.LADDER.x, float(j["y"]) + 1.0, LineScript.LADDER.z)
	return (j["at"] as Vector3) + Vector3(0, 0.2, 0)

func cut_points() -> Array:
	return []

## For the camera: [what to look at, how far back, is it inside the building].
func focus() -> Array:
	var m := _m()
	if si < 0 or si >= steps.size():
		return [m + Vector3(0, 2, 0), 20.0, false]
	var s: Dictionary = steps[si]
	match String(s["kind"]):
		"fly", "land":
			var seat: Vector3 = s["seat"]
			var mid := (hook_pos + seat) * 0.5
			return [mid, clampf(hook_pos.distance_to(seat) * 1.2 + 16.0, 18.0, 42.0), false]
		"test":
			return [Vector3(m.x, (foot + to_head) * 0.5 + 4.0, m.z), 40.0, false]
	if String(s["zone"]) == "ladder":
		var inside: bool = float(s["y"]) < foot - 1.0      # (the floor below: the legs, the pads, the wedges)
		return [Vector3(m.x, float(s["y"]) + 0.8, m.z), 9.0 if inside else 16.0, inside, inside]
	return [(s["at"] as Vector3) + Vector3(0, 1.5, 0), 16.0, false]

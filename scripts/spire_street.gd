extends Node3D
## Spire: the kerbside work zone on Ann St, set up the way a Brisbane CBD pour is (the research's in
## the project's "CBD pour-day street setup" doc). One kerb lane is barricaded for the pump, its
## hopper and one truck; the footpath stays open under a gantry; a traffic controller holds the
## traffic while a truck pulls round and backs in; another holds the people on the footpath at the
## site gate while the crew's crossing; and a spotter backs every truck onto the hopper.
##
## The three new jobs (traffic controller, gate controller, spotter) are played by bots here. They
## aren't crew roles yet: nobody picks them, and the truck hand can still spot a truck themselves.

const F := preload("res://scripts/factory.gd")
const SpireSite := preload("res://scripts/spire_site.gd")
const Line := preload("res://scripts/line.gd")

const EDGE := Line.KERB_EDGE          # the barrier line
const KERB := 2.2                     # the kerb's face
const ZONE_X0 := -9.0                 # the barriers start (the cone taper's upstream of this)
const ZONE_X1 := 41.5                 # the last cone
const OUT_GAP := Vector2(-1.0, 10.5)  # the ready truck pulls out through here
const IN_GAP := Vector2(25.5, 37.0)   # ...and backs in (and drives out) through here
const GATE := Vector2(5.4, 16.6)      # the site gate: no gantry here (the riser, the way up, the haul rope)
const DECK_Y := 3.3                   # the gantry's deck over the footpath
const WALK_SPEED := 1.3

var game
var _tc: Node3D            # the traffic controller, at the taper
var _tc_bat: Node3D
var _tc_face: MeshInstance3D
var _tc_label: Label3D
var _gate: Array = []      # the gate controllers: {node, bat, face, at}
var _spotter: Node3D
var _spot_label: Label3D
var _walkers: Array = []   # people on the footpath: {node, x, dir, phase}
var _board: Array = []     # the arrow board's lamps
var _t := 0.0
var _hold_traffic := false
var _hold_gate := false
var _called_seen := false

static func gy(x: float, z: float) -> float:
	return SpireSite.road_lift(x, z)

func build(owner_game) -> void:
	game = owner_game
	name = "SpireStreet"
	_barriers()
	_cones()
	_signs()
	_gantry()
	_zones()
	# (the barriers, cones, signs, gantry and lines never move: a few meshes for the lot)
	F.bake(self)
	_people()

# ------------------------------------------------------------------ the work zone

func _barrier(x: float, z: float, i: int, yaw := 0.0) -> void:
	# A water-filled barrier, 2 m long: orange and white by turns
	var n := Node3D.new()
	var col := Color("f26a1b") if i % 2 == 0 else Color("f4f2ec")
	n.add_child(F.box(Vector3(1.94, 0.5, 0.5), F.color_mat(col, true), Vector3(0, 0.25, 0)))
	n.add_child(F.box(Vector3(1.94, 0.4, 0.3), F.color_mat(col, true), Vector3(0, 0.68, 0)))
	n.add_child(F.box(Vector3(0.5, 0.06, 0.2), F.color_mat(Color("23272e")), Vector3(0, 0.9, 0), false))
	n.position = Vector3(x, gy(x, z), z)
	n.rotation.y = yaw
	add_child(n)

func _barriers() -> void:
	var i := 0
	for run: Vector2 in [Vector2(ZONE_X0, OUT_GAP.x), Vector2(OUT_GAP.y, IN_GAP.x)]:
		var x := run.x + 1.0
		while x < run.y - 0.9:
			_barrier(x, EDGE, i)
			i += 1
			x += 2.0
	# (the upstream end's closed across the lane behind the ready truck's way in)
	_barrier(ZONE_X0 - 0.2, EDGE - 1.0, 1, PI * 0.5)

func _cone(x: float, z: float) -> void:
	var n := Node3D.new()
	n.add_child(F.box(Vector3(0.36, 0.04, 0.36), F.color_mat(Color("23272e")), Vector3(0, 0.02, 0), false))
	var c := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.15
	cm.height = 0.7
	cm.radial_segments = 8
	c.mesh = cm
	c.material_override = F.color_mat(Color("f26a1b"), true)
	c.position.y = 0.39
	n.add_child(c)
	n.add_child(F.cylinder(0.085, 0.12, F.color_mat(Color("f4f2ec")), Vector3(0, 0.46, 0), 8))
	n.position = Vector3(x, gy(x, z), z)
	add_child(n)

func _cones() -> void:
	# The taper: the kerb lane closes over 12 m, with a gap at its end where the trucks turn in
	for i in 7:
		var u := i / 6.0
		_cone(lerpf(-30.0, -18.0, u), lerpf(KERB + 0.3, EDGE, u))
	# Along the lane line where the trucks cross it: only at the ends of each gap
	for x in [OUT_GAP.x + 0.4, OUT_GAP.y - 0.4, IN_GAP.x + 0.5, IN_GAP.y + 0.5, 39.0, ZONE_X1]:
		_cone(x, EDGE)

func _post_sign(x: float, z: float, text: String, back: Color, ink: Color, size := Vector2(1.0, 0.8), yaw := -PI * 0.5) -> void:
	var n := Node3D.new()
	n.add_child(F.cylinder(0.035, 1.5, F.color_mat(Color("8e98a6")), Vector3(0, 0.75, 0), 6))
	n.add_child(F.box(Vector3(0.5, 0.05, 0.5), F.color_mat(Color("23272e")), Vector3(0, 0.03, 0), false))
	n.add_child(F.box(Vector3(size.x, size.y, 0.04), F.color_mat(back, true), Vector3(0, 1.5 + size.y * 0.5, 0)))
	for side in [1.0, -1.0]:
		var l := F.label3d(text, 44, ink)
		l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		l.outline_size = 0
		l.pixel_size = 0.0045
		l.width = size.x / 0.0045 - 20.0
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.position = Vector3(0, 1.5 + size.y * 0.5, 0.03 * side)
		if side < 0.0:
			l.rotation.y = PI
		n.add_child(l)
	n.position = Vector3(x, gy(x, z), z)
	n.rotation.y = yaw
	add_child(n)

func _signs() -> void:
	var orange := Color("ffb000")
	var black := Color("111417")
	# (the faces look back down Ann St, at the traffic coming)
	_post_sign(-50.0, KERB - 0.5, "ROADWORK AHEAD", orange, black)
	_post_sign(-40.0, KERB - 0.5, "LEFT LANE CLOSED", orange, black)
	_post_sign(-34.0, KERB - 0.5, "40", Color("f4f2ec"), Color("c8102e"), Vector2(0.7, 0.8))
	_post_sign(-33.0, KERB - 0.5, "PREPARE TO STOP", orange, black)
	_post_sign(ZONE_X1 + 4.0, KERB - 0.5, "END ROADWORK", orange, black)
	_post_sign(OUT_GAP.x - 0.6, EDGE, "TRUCKS", orange, black, Vector2(0.9, 0.5))
	# The arrow board, on its trailer in the closed lane ahead of the taper's end
	var ab := Node3D.new()
	ab.add_child(F.box(Vector3(1.6, 0.25, 1.1), F.color_mat(Color("ffb000"), true), Vector3(0, 0.45, 0)))
	for z in [-0.6, 0.6]:
		ab.add_child(F.cylinder(0.26, 0.16, F.color_mat(Color("23272e")), Vector3(0, 0.26, z), 10))
		(ab.get_child(ab.get_child_count() - 1) as Node3D).rotation.x = PI * 0.5
	ab.add_child(F.cylinder(0.05, 1.6, F.color_mat(Color("8e98a6")), Vector3(0, 1.3, 0), 6))
	ab.add_child(F.box(Vector3(0.08, 1.2, 2.4), F.color_mat(Color("16181c"), true), Vector3(0, 2.6, 0)))
	# (lamps: an arrow pointing out to the open lanes, +z)
	var lamps := [Vector2(-0.9, 0), Vector2(-0.55, 0), Vector2(-0.2, 0), Vector2(0.15, 0), Vector2(0.5, 0), Vector2(0.85, 0),
		Vector2(0.5, 0.35), Vector2(0.5, -0.35), Vector2(0.15, 0.2), Vector2(0.15, -0.2)]
	for lp: Vector2 in lamps:
		var m := F.box(Vector3(0.03, 0.16, 0.16), F.flat_mat(Color("ffcf33")), Vector3(-0.07, 2.6 + lp.y, lp.x), false)
		m.set_meta("nobake", true)
		ab.add_child(m)
		_board.append(m)
	ab.position = Vector3(-21.5, gy(-21.5, 3.6), 3.6)
	add_child(ab)

## The gantry over the footpath (Class B: a solid deck people walk under, lit beneath, a hoarding on
## its street edge, the site sheds on top). It stops for the site gate, the hoist and the crane.
func _gantry() -> void:
	var steel := F.color_mat(Color("56606e"), true)
	var deck := F.color_mat(Color("c9ccd1"), true)
	var hoard := F.color_mat(Color("f4f2ec"), true)
	var blue := F.color_mat(Color("1f4f9c"), true)
	var gaps: Array[Vector2] = [GATE, Vector2(game.hoist_x - 1.9, game.hoist_x + 1.9)]
	if game.climb != null:
		gaps.append(Vector2(game.climb.MAST.x - 2.0, game.climb.MAST.x + 2.0))
	var x := -17.0
	var shed_done := 0
	while x < 33.0:
		var x1 := x + 3.0
		var skip := false
		for g in gaps:
			if x1 > g.x and x < g.y:
				skip = true
		if not skip:
			var xm := x + 1.5
			var z0: float = SpireSite.face_z(xm) + 0.15
			var z1 := KERB - 0.15
			var y0 := gy(xm, 0.8)
			var bay := Node3D.new()
			bay.position = Vector3(xm, y0, 0)
			add_child(bay)
			var top := DECK_Y - y0 if absf(y0) < 1.2 else DECK_Y
			for px in [-1.5, 1.5]:
				bay.add_child(F.box(Vector3(0.14, top, 0.14), steel, Vector3(px, top * 0.5, z1)))
				bay.add_child(F.box(Vector3(0.14, top, 0.14), steel, Vector3(px, top * 0.5, z0)))
			bay.add_child(F.box(Vector3(3.0, 0.16, z1 - z0 + 0.5), deck, Vector3(0, top + 0.08, (z0 + z1) * 0.5)))
			# (the hoarding along the deck's street edge, with the site's blue band)
			bay.add_child(F.box(Vector3(3.0, 1.1, 0.06), hoard, Vector3(0, top + 0.7, z1 + 0.2)))
			bay.add_child(F.box(Vector3(3.0, 0.28, 0.07), blue, Vector3(0, top + 0.5, z1 + 0.2)))
			# (and the wall between the footpath and the site)
			bay.add_child(F.box(Vector3(3.0, top, 0.06), hoard, Vector3(0, top * 0.5, z0)))
			bay.add_child(F.box(Vector3(1.6, 0.05, 0.12), F.flat_mat(Color("fff3c4")), Vector3(0, top - 0.04, (z0 + z1) * 0.5), false))
			if xm > 16.0 and xm < 21.5 and shed_done < 2:
				# The site sheds on the deck
				shed_done += 1
				bay.add_child(F.box(Vector3(2.9, 2.3, z1 - z0 - 0.3), F.color_mat(Color("e9edf2"), true), Vector3(0, top + 0.16 + 1.15, (z0 + z1) * 0.5 - 0.1)))
				bay.add_child(F.box(Vector3(1.1, 0.7, 0.05), F.color_mat(Color("5f8fd0")), Vector3(0, top + 1.6, z1 - 0.38)))
		x = x1
	# The gate's own signs, on the gantry's ends each side of it
	for gx in [GATE.x - 0.3, GATE.y + 0.3]:
		_post_sign(gx + (-1.6 if gx < 10.0 else 1.6), KERB - 0.3, "SITE GATE WAIT HERE", Color("ffb000"), Color("111417"), Vector2(1.2, 0.8), -PI * 0.5 if gx < 10.0 else PI * 0.5)

func _stripe(a: Vector3, b: Vector3, col: Color, w := 0.14) -> void:
	var d := b - a
	var m := F.box(Vector3(d.length(), 0.012, w), F.flat_mat(col), (a + b) * 0.5 + Vector3(0, 0.03, 0), false)
	m.rotation.y = -atan2(d.z, d.x)
	add_child(m)

## An exclusion zone painted on the road: a red and white edge, hatched across, and its name.
func _zone(r: Rect2, text: String, col: Color) -> void:
	var p := [Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0, r.position.y), Vector3(r.end.x, 0, r.end.y), Vector3(r.position.x, 0, r.end.y)]
	for i in 4:
		_stripe(p[i], p[(i + 1) % 4], col)
	var x := r.position.x + 0.8
	while x < r.end.x - r.size.y:
		_stripe(Vector3(x, 0, r.position.y + 0.1), Vector3(x + r.size.y - 0.2, 0, r.end.y - 0.1), Color(col, 1.0), 0.07)
		x += 1.6
	var l := F.label3d(text, 40, col)
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.outline_size = 6
	l.pixel_size = 0.006
	l.rotation.x = -PI * 0.5
	l.position = Vector3(r.get_center().x, 0.05, r.end.y - 0.32)
	add_child(l)

func _zones() -> void:
	# The ground line crosses the footpath under a pipe ramp
	var so := Line.STEP_OVER
	var ramp := Node3D.new()
	ramp.position = Vector3(so.x, gy(so.x, so.z), so.z + 0.2)
	ramp.rotation.y = 0.14
	ramp.add_child(F.box(Vector3(0.6, 0.42, 2.6), F.color_mat(Color("ffc72c"), true), Vector3(0, 0.21, 0)))
	for sx in [-0.62, 0.62]:
		var w := F.box(Vector3(0.75, 0.05, 2.6), F.color_mat(Color("23272e")), Vector3(sx, 0.2, 0))
		w.rotation.z = 0.52 * signf(sx)
		ramp.add_child(w)
	add_child(ramp)
	# Round the hopper and the reversing truck: nobody on foot while one's backing in
	_zone(Rect2(Line.HOPPER.x - 0.6, KERB + 0.1, 12.5, 2.75), "EXCLUSION ZONE · TRUCK REVERSING", Color("e23b2e"))
	# The people on the footpath wait behind these while the gate's shut
	for gx in [GATE.x, GATE.y]:
		_stripe(Vector3(gx, gy(gx, 0.5), SpireSite.face_z(gx) + 0.3), Vector3(gx, gy(gx, 0.5), KERB - 0.2), Color("ffc72c"), 0.18)

# ------------------------------------------------------------------ the people

func _bat(parent: Node3D) -> Array:
	# The stop/slow bat: a disc on a pole, held out in the right hand
	var bat := Node3D.new()
	bat.add_child(F.cylinder(0.022, 1.7, F.color_mat(Color("e9edf2")), Vector3(0, 0.85, 0), 6))
	var face := F.cylinder(0.26, 0.04, F.flat_mat(Color("e23b2e")), Vector3(0, 1.85, 0), 8)
	face.rotation.x = PI * 0.5
	bat.add_child(face)
	bat.position = Vector3(0.42, 0, 0.12)
	parent.add_child(bat)
	return [bat, face]

func _controller(at: Vector3, yaw: float) -> Dictionary:
	var n := F.chibi(Color("ff7a1a"), Color("f4f7fa"))
	n.position = Vector3(at.x, gy(at.x, at.z), at.z)
	n.rotation.y = yaw
	add_child(n)
	var b := _bat(n)
	(n.get_node("ArmR") as Node3D).rotation.x = -1.2
	return {"node": n, "bat": b[0], "face": b[1], "at": at, "yaw": yaw}

func _people() -> void:
	# The traffic controller at the taper, facing the traffic coming up Ann St
	var c := _controller(Vector3(ZONE_X0 - 1.6, 0, EDGE + 0.2), -PI * 0.5)
	_tc = c["node"]
	_tc_bat = c["bat"]
	_tc_face = c["face"]
	_tc_label = F.label3d("SLOW", 40, Color("ffc72c"))
	_tc_label.layers = 2
	_tc_label.position = Vector3(0, 2.75, 0)
	_tc.add_child(_tc_label)
	# One each end of the gate, facing the people walking up to it
	_gate.append(_controller(Vector3(GATE.x - 0.5, 0, KERB - 0.6), -PI * 0.5))
	_gate.append(_controller(Vector3(GATE.y + 0.5, 0, KERB - 0.6), PI * 0.5))
	# The spotter: on the kerb beside the hopper, in the driver's mirror the whole way back
	_spotter = F.chibi(Color("d8f04a"), Color("f4f7fa"))
	var sp := Vector3(Line.HOPPER.x + 0.4, 0, KERB - 0.45)
	_spotter.position = Vector3(sp.x, gy(sp.x, sp.z), sp.z)
	_spotter.rotation.y = PI * 0.5
	add_child(_spotter)
	_spot_label = F.label3d("", 40, Color.WHITE)
	_spot_label.layers = 2
	_spot_label.position = Vector3(0, 2.6, 0)
	_spotter.add_child(_spot_label)
	# People on the footpath, both ways
	var coats := [Color("3b6fb5"), Color("8a4fb0"), Color("3f8f6a"), Color("b0483f"), Color("5a6470"), Color("c98a2b")]
	for i in 6:
		var w := F.chibi(coats[i], coats[(i + 3) % 6])
		for h in w.find_children("Hat*", "", true, false):
			if h is Node3D:
				(h as Node3D).visible = false
		w.scale = Vector3.ONE * 0.95
		add_child(w)
		_walkers.append({"node": w, "x": -38.0 + i * 15.0, "dir": 1.0 if i % 2 == 0 else -1.0, "phase": i * 1.7, "lane": 0.35 if i % 2 == 0 else -0.35})

func _path_z(x: float, lane: float) -> float:
	# (through the gate they keep to the kerb side, clear of the foot of the stairs)
	var mid := (SpireSite.face_z(x) + KERB) * 0.5 + lane
	var g := smoothstep(GATE.x - 3.0, GATE.x, x) * (1.0 - smoothstep(GATE.y, GATE.y + 3.0, x))
	# (where the podium comes out to the stairs, that's in the kerb lane, between the stairs' foot and the racking)
	return lerpf(mid, maxf(KERB - 0.75, Line.LADDER_FOOT.z + 0.75) + lane * 0.5, g)

func _process(delta: float) -> void:
	if game == null or game.line == null:
		return
	_t += delta
	var line = game.line
	# --- the trucks: who's moving in the street, and who's backing in
	var moving := false
	var backing = null
	var called := false
	for t in line.trucks:
		var st: String = t["state"]
		var n: Node3D = t["node"]
		if st in ["called", "approach", "back", "turned"] or (st in ["leave", "road"] and n.position.x < ZONE_X1 + 14.0):
			moving = true
		if st == "back":
			backing = t
		if st == "arrive":
			called = true
	_hold_traffic = moving
	# (the next load's called up by radio as the ready spot empties: line.gd's just-in-time rule)
	if called and not _called_seen and game.phase == "pour":
		game.pop("RADIO: next truck, come on up", _tc.position + Vector3(0, 3.2, 0), Color("9fd3ff"))
	_called_seen = called
	# --- the traffic controller: steps out with STOP while a truck's pulling round or out
	var home := Vector3(ZONE_X0 - 1.6, 0, EDGE + 0.2)
	var out := Vector3(ZONE_X0 - 2.4, 0, EDGE + 2.1)
	var want := out if _hold_traffic else home
	var at := _tc.position.move_toward(Vector3(want.x, gy(want.x, want.z), want.z), 2.2 * delta)
	_tc.position = at
	_show_bat(_tc_face, _hold_traffic)
	_tc_label.text = "STOP" if _hold_traffic else "SLOW"
	_tc_label.modulate = Color("ff5a4d") if _hold_traffic else Color("ffc72c")
	_tc_label.visible = game.phase == "pour"
	(_tc.get_node("ArmL") as Node3D).rotation.x = -2.6 if _hold_traffic else 0.0
	# --- the gate: shut to the footpath while the crew's crossing it or something's on the rope
	_hold_gate = line.hook["state"] != "down" and String(line.hook["kind"]) != ""
	for p in game.players:
		if p.zone == "ground" and p.position.x > GATE.x and p.position.x < GATE.y and p.position.z < KERB + 0.2:
			_hold_gate = true
		if p.zone == "ladder":
			_hold_gate = true
	for g in _gate:
		_show_bat(g["face"], _hold_gate)
		((g["node"] as Node3D).get_node("ArmL") as Node3D).rotation.x = -2.6 if _hold_gate else 0.0
	# --- the spotter: waves the truck back, hand up to stop it on the mark
	var arm_l := _spotter.get_node("ArmL") as Node3D
	var arm_r := _spotter.get_node("ArmR") as Node3D
	if backing != null:
		var su := float(backing.get("su", clampf(float(backing["t"]) / line.SPOT_LEN, 0.0, 1.0)))
		var beckon := sin(_t * 9.0)
		if su < 0.86:
			arm_l.rotation.x = -1.5 + 0.5 * beckon
			arm_r.rotation.x = -1.5 + 0.5 * beckon
			_spot_label.text = "COME BACK"
			_spot_label.modulate = Color("7cd992")
		else:
			arm_l.rotation.x = -2.9
			arm_r.rotation.x = -2.9
			_spot_label.text = "WHOA"
			_spot_label.modulate = Color("ff5a4d")
		var rear: Vector3 = (backing["node"] as Node3D).global_transform * Vector3(-5.6, 0, 0)
		_spotter.rotation.y = atan2(rear.x - _spotter.position.x, rear.z - _spotter.position.z)
	else:
		arm_l.rotation.x = move_toward(arm_l.rotation.x, 0.0, 6.0 * delta)
		arm_r.rotation.x = move_toward(arm_r.rotation.x, 0.0, 6.0 * delta)
		_spot_label.text = ""
		_spotter.rotation.y = lerp_angle(_spotter.rotation.y, PI * 0.5, 3.0 * delta)
	# --- the footpath: people walk through, and wait at the gate while it's shut
	for w in _walkers:
		var n: Node3D = w["node"]
		var x: float = w["x"]
		var dir: float = w["dir"]
		var step := WALK_SPEED * delta
		var stop_x := (GATE.x - 1.2) if dir > 0.0 else (GATE.y + 1.2)
		var held: bool = _hold_gate and (stop_x - x) * dir >= 0.0 and (stop_x - x) * dir < step + 0.6
		# (no walking into the back of someone waiting)
		for o in _walkers:
			if o != w and float(o["dir"]) == dir and (float(o["x"]) - x) * dir > 0.0 and (float(o["x"]) - x) * dir < 0.9:
				held = true
		if not held:
			x += dir * step
		if x > 58.0:
			x = -44.0
		elif x < -44.0:
			x = 58.0
		w["x"] = x
		var z := _path_z(x, w["lane"])
		n.position = Vector3(x, gy(x, z) + (0.0 if held else absf(sin(_t * 7.0 + float(w["phase"]))) * 0.05), z)
		n.rotation.y = PI * 0.5 * dir
		var sw := 0.0 if held else sin(_t * 7.0 + float(w["phase"])) * 0.5
		(n.get_node("ArmL") as Node3D).rotation.x = sw
		(n.get_node("ArmR") as Node3D).rotation.x = -sw
		(n.get_node("LegL") as Node3D).rotation.x = -sw
		(n.get_node("LegR") as Node3D).rotation.x = sw
	# --- the arrow board's lamps flash
	var on := fmod(_t, 1.2) < 0.7
	for m in _board:
		(m as Node3D).visible = on

func _show_bat(face: MeshInstance3D, stop: bool) -> void:
	(face.material_override as StandardMaterial3D).albedo_color = Color("e23b2e") if stop else Color("ffb000")

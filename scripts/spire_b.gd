## Spire's pour B: the other half of each level, poured by a bot crew at the same time as ours.
## It's the same job done the same way, on the game's own concrete (pour.gd): a deck of formply and
## steel, a placing boom on its own mast in the lift core laying the slab bay by bay from the far end
## back, a hose hand under the boom's tip, two concreters on pokers working the wet edge, and a screeder
## coming along behind them. They keep pace with our pour (`frac`), so both halves finish together.
extends Node3D

const F := preload("res://scripts/factory.gd")
const PourScript := preload("res://scripts/pour.gd")
const SpireSite := preload("res://scripts/spire_site.gd")

const L1 := 15.0
const L2 := 15.0
const SHOULDER := 1.7
const HOSE := 3.0
const HOSE_SPD := 2.4          # m/s the boom walks its hose across the slab
const WALK := 2.0              # m/s, the crew
const POUR_T := 48.0           # s of hose time for the whole of pour B
const BOARD := 2.6             # m, the screed board

var game
var pour
var plan := PackedVector2Array()   # pour B, game x/z
var centre := Vector3.ZERO
var head: Node3D
var mast: MeshInstance3D
var yaw: Node3D
var arm1: Node3D
var arm2: Node3D
var tip: Node3D
var stream: MeshInstance3D
var hose := Vector3.ZERO           # where the hose is, pour-local
var goal := Vector3.ZERO
var men: Array = []                # {node, job, at (pour-local), carry}
var _pick_t := 0.0
var _t := 0.0
var _finish := 0.0
var _placing := false
var _rig := PackedVector2Array()

func build(owner_game) -> void:
	game = owner_game
	name = "PourB"
	plan = SpireSite.poly("B")
	var grown: Array = Geometry2D.offset_polygon(SpireSite.poly("rig"), 0.45, Geometry2D.JOIN_MITER)
	_rig = grown[0] if not grown.is_empty() else SpireSite.poly("rig")
	var bb := Rect2(plan[0], Vector2.ZERO)
	for p in plan:
		bb = bb.expand(p)
	centre = Vector3(bb.get_center().x, 0, bb.get_center().y)
	pour = PourScript.new()
	add_child(pour)
	pour.build(bb.size.x + 0.6, bb.size.y + 0.6, [])
	pour.position = centre
	var rel := PackedVector2Array()
	for p in plan:
		rel.append(p - Vector2(centre.x, centre.z))
	pour.set_poly(rel)
	pour.reset()
	# Their boom: a second mast up through the lift core, in its far half
	var at := SpireSite.mast_xz(false)
	head = Node3D.new()
	head.position = Vector3(at.x, 0, at.y)
	add_child(head)
	mast = F.cylinder(0.42, 1.0, F.mat("orange"), Vector3.ZERO, 12)
	add_child(mast)
	head.add_child(F.prop("BoomCollar", {}, F.TOWERS))
	yaw = Node3D.new()
	head.add_child(yaw)
	yaw.add_child(F.prop("BoomTurret", {}, F.TOWERS))
	arm1 = Node3D.new()
	arm1.position.y = SHOULDER
	yaw.add_child(arm1)
	var a1 := F.prop("BoomArm1", {}, F.TOWERS)
	a1.scale.x = L1 / 20.0
	arm1.add_child(a1)
	arm2 = Node3D.new()
	arm2.position.x = L1
	arm1.add_child(arm2)
	var a2 := F.prop("BoomArm2", {}, F.TOWERS)
	a2.scale.x = L2 / 20.0
	arm2.add_child(a2)
	tip = Node3D.new()
	tip.position.x = L2
	arm2.add_child(tip)
	tip.add_child(F.prop("BoomTip", {}, F.TOWERS))
	tip.add_child(F.cylinder(0.17, HOSE, F.mat("hose"), Vector3(0, -HOSE * 0.5, 0), 8))
	stream = F.cylinder(0.2, 1.0, F.color_mat(Color("6c6f73")), Vector3.ZERO, 10)
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stream)
	for job in ["hose", "poker", "poker", "screed"]:
		var c := F.chibi(Color("ff7a1a"), Color("f4f7fa"))
		F.kit(c, job)
		add_child(c)
		men.append({"node": c, "job": job, "at": Vector3.ZERO, "carry": 0.0, "wait": 0.0})
	start_level()

## A new deck: clean formwork, the crew back at the far end.
func start_level() -> void:
	pour.reset()
	pour.set_cured(0.0)
	_finish = 0.0
	hose = _inside(Vector3(-pour.bw * 0.5 + 3.0, 0, 0))
	goal = hose
	for i in men.size():
		men[i]["at"] = _inside(hose + Vector3(1.5 + i * 1.2, 0, 1.0 - i * 0.8))
		men[i]["carry"] = 0.0

## The nearest spot on pour B to a pour-local point.
func _inside(local: Vector3) -> Vector3:
	var q := Vector2(local.x + centre.x, local.z + centre.z)
	if Geometry2D.is_point_in_polygon(q, plan):
		return local
	var best := 1e9
	var out := local
	for i in pour.NX * pour.NZ:
		if pour.mask[i] == 1:
			var c: Vector3 = pour.cell_center(i)
			var dd := c.distance_squared_to(local)
			if dd < best:
				best = dd
				out = c
	return out

func _in_rig(local: Vector3) -> bool:
	return Geometry2D.is_point_in_polygon(Vector2(local.x + centre.x, local.z + centre.z), _rig)

## `frac`: how far our own pour's got (0..1). `deck_y`: the top of the formply (main.deck_top). `head_y`: the boom
## head's height (it rides the jump form with ours).
func update(delta: float, frac: float, phase: String, deck_y: float, head_y: float) -> void:
	_t += delta
	visible = phase != "topout"
	position.y = deck_y
	head.position.y = head_y - deck_y
	var bottom: float = -3.0 * float(game.FH)
	mast.position = Vector3(head.position.x, (head.position.y + bottom) * 0.5, head.position.z)
	mast.scale.y = head.position.y - bottom
	pour.open_time = maxf(60.0, float(game.pour.open_time) * 2.5)
	var cov: float = pour.coverage() / 0.985
	var pouring: bool = phase == "pour" and cov < minf(1.0, frac + 0.03)
	_placing = false
	if phase == "pour":
		_pick_t -= delta
		if _pick_t <= 0.0 and cov < 1.0:
			_pick_t = 0.5
			goal = pour.next_face_point(pour.cur_bay, hose)
		var to := goal - hose
		to.y = 0.0
		hose += to.limit_length(HOSE_SPD * delta)
		if pouring and to.length() < 1.5:
			_placing = true
			pour.deposit(hose, pour.needed() / POUR_T * delta)
	pour.set_splash(_placing, hose)
	if phase == "pour" or _finish < 1.0:
		pour.step(delta)
	if phase in ["screed", "cure", "sign", "report"]:
		# (ours is done: theirs is finished off and goes hard with it)
		if _finish <= 0.0:
			pour.finish_vibration(1.0)
		_finish = minf(1.0, _finish + delta / 3.0)
		pour.screed(_finish, delta)
		if _finish >= 1.0:
			pour.set_cured(1.0)
	_boom()
	_crew(delta, phase)

func _boom() -> void:
	var hp := head.position + Vector3(0, SHOULDER, 0)
	var t := centre + hose + Vector3(0, 1.3 + HOSE, 0)
	var hv := Vector2(t.x - hp.x, t.z - hp.z)
	yaw.rotation.y = atan2(-hv.y, hv.x)
	var d := hv.length()
	var ty := t.y - hp.y
	var dist := clampf(sqrt(d * d + ty * ty), 1.0, L1 + L2 - 0.05)
	var phi := atan2(ty, d)
	var a := acos(clampf((L1 * L1 + dist * dist - L2 * L2) / (2.0 * L1 * dist), -1.0, 1.0))
	var b := acos(clampf((L1 * L1 + L2 * L2 - dist * dist) / (2.0 * L1 * L2), -1.0, 1.0))
	arm1.rotation.z = phi + a
	arm2.rotation.z = -(PI - b)
	tip.rotation.z = -(arm1.rotation.z + arm2.rotation.z)
	var under: float = pour.height_at(hose)
	stream.visible = _placing
	var fall := 1.3
	stream.position = centre + hose + Vector3(0, under * 0.5 + fall * 0.5, 0)
	stream.scale = Vector3(1.0 + 0.15 * sin(_t * 23.0), fall, 1.0 + 0.15 * sin(_t * 19.0))

func _crew(delta: float, phase: String) -> void:
	var pokers := 0
	for m in men:
		var at: Vector3 = m["at"]
		var want := at
		var working := false
		match String(m["job"]):
			"hose":
				# on the end hose, a step back from where it's landing
				want = hose + Vector3(0.9, 0, 0.5)
			"poker":
				pokers += 1
				var spot: Vector3 = pour.needs_vibrating(at + Vector3(0, 0, 2.5 if pokers == 1 else -2.5))
				if phase == "pour" and spot.x != INF:
					want = spot
					if at.distance_to(spot) < 0.9:
						working = true
						pour.vibrate(at, 1.2, delta, 0.7)
				else:
					want = hose + Vector3(2.5, 0, 2.0 if pokers == 1 else -2.0)
			"screed":
				m["wait"] = float(m["wait"]) - delta
				if float(m["wait"]) <= 0.0:
					m["wait"] = 0.6
					m["goal"] = pour.needs_screed(at, hose, 3.0)
				var sg: Vector3 = m.get("goal", Vector3(INF, 0, 0))
				if phase == "pour" and sg.x != INF:
					want = sg
					working = true
					var side := Vector3(0, 0, BOARD * 0.5)
					var res: Dictionary = pour.screed_strip(at - side, at + side, delta, float(m["carry"]))
					m["carry"] = minf(0.05, float(res["carry"]))
				else:
					want = hose + Vector3(4.5, 0, 0.0)
		want = _inside(want)
		var step := want - at
		step.y = 0.0
		var node: Node3D = m["node"]
		if step.length() > 0.15:
			var mv := step.limit_length(WALK * (0.5 if working else 1.0) * delta)
			# (round the jump form, never through it)
			if _in_rig(at + mv):
				var side := Vector3(signf(mv.x) if absf(mv.x) > 0.001 else 1.0, 0, 0) * mv.length()
				var fwd := Vector3(0, 0, signf(mv.z) if absf(mv.z) > 0.001 else 1.0) * mv.length()
				mv = side if not _in_rig(at + side) and absf(step.x) >= absf(step.z) * 0.2 else (fwd if not _in_rig(at + fwd) else (side if not _in_rig(at + side) else Vector3.ZERO))
			at += mv
			node.rotation.y = lerp_angle(node.rotation.y, atan2(step.x, step.z), minf(1.0, delta * 8.0))
		m["at"] = at
		var wet: float = pour.height_at(at)
		node.position = centre + at + Vector3(0, maxf(0.0, wet - 0.12), 0)
		if working:
			node.position.y += 0.03 * absf(sin(_t * 9.0))

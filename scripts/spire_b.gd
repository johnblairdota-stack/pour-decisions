## Spire's pour B: the other half of each level, poured by the other crew at the same time as ours.
## It's the same job done by the same crew bots as ours: the same chibis walking the same way, run by
## bots.gd's own boom operator, hose hand, poker hand and screeder, with poker.gd's pokers and
## screed.gd's board, on the game's own concrete (pour.gd). spire_b_view.gd answers what those scripts
## ask "the game" for, about pour B. Nothing's poured unless their hose hand calls the pump on with
## their boom operator on the remote, nothing's compacted unless a poker's in it, and nothing's
## finished unless the screed board's been over it. Their own pump (out of sight) runs high while
## they're behind our pour, low while they're ahead and waits on its next truck once they're well
## ahead, so both halves go at the same pace and tend to finish together.
## Two pokers: one more than our crew's, so a second bots.gd runs the second poker hand.
extends Node3D

const F := preload("res://scripts/factory.gd")
const PourScript := preload("res://scripts/pour.gd")
const SpireSite := preload("res://scripts/spire_site.gd")
const PlayerScript := preload("res://scripts/player.gd")
const BotsScript := preload("res://scripts/bots.gd")
const PokerScript := preload("res://scripts/poker.gd")
const ScreedScript := preload("res://scripts/screed.gd")
const ViewScript := preload("res://scripts/spire_b_view.gd")
const LineScript := preload("res://scripts/line.gd")

const L1 := 15.0
const L2 := 15.0
const SHOULDER := 1.7
const HOSE := 3.0
const HOSE_WALK_K := 0.55      # walking with the hose: slow and steady (as main.gd)
const BOOT_SINK := 0.06
const AHEAD := 0.05            # their pump waits once they're this far ahead of ours (low while they're ahead at all)
const FINISH_STALL := 12.0     # (as main.gd: no progress this long and they finish the last bits by hand)
const FINISH_MAX := 45.0
const ROLES := ["boom", "hose", "poker", "poker", "screed"]

var game
var view
var pour
var plan := PackedVector2Array()   # pour B, game x/z
var centre := Vector3.ZERO
var head: Node3D
var mast: MeshInstance3D
var yaw: Node3D
var arm1: Node3D
var arm2: Node3D
var tip: Node3D
var hang: Node3D                   # the end hose hanging off the tip when nobody's on it
var stream: MeshInstance3D
var tip_pos := Vector3.ZERO        # where the tip is (world), and where it's being steered to (view.tip_target)
var boom_spot := Vector3.ZERO      # the boom operator's spot, on the jump form's walkway by their mast
var start := Vector3.ZERO          # where the crew start: the far end, where the bays begin
var crew: Array = []               # {p, role, bots, pk}
var pokers: Array = []
var screed_m
var bots: Array = []               # [crew's, second poker hand's]
var done := false
var hose_call := false
var pumping := false
var by_hand := 0
var _segs: Array = []
var _t := 0.0
var _finish := 0.0
var _full_at := -1.0
var _fin_best := 9.0
var _fin_t := 0.0
var _fin_check := 0.0
var _fin_dt := 0.0
var _core := PackedVector2Array()
var _walk := PackedVector2Array()
var _step_dt := 0.0
var _odd := false
var _was_phase := ""

func build(owner_game) -> void:
	game = owner_game
	name = "PourB"
	plan = SpireSite.poly("B")
	# (as pour A's crew: they keep off the core's walls, and walk under the jump form)
	var grown: Array = Geometry2D.offset_polygon(SpireSite.poly("core"), SpireSite.CORE_CLEAR, Geometry2D.JOIN_MITER)
	_core = grown[0] if not grown.is_empty() else SpireSite.poly("core")
	var wg: Array = Geometry2D.offset_polygon(plan, 0.25, Geometry2D.JOIN_MITER)
	_walk = wg[0] if not wg.is_empty() else plan
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
	view = ViewScript.new()
	view.main = game
	view.b = self
	view.pour = pour
	view.SC = centre
	view.BW = pour.bw
	view.BD = pour.bd
	view.autotest = bool(game.get("autotest"))
	add_child(view)
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
	hang = F.cylinder(0.17, HOSE, F.mat("hose"), Vector3(0, -HOSE * 0.5, 0), 8)
	tip.add_child(hang)
	stream = F.cylinder(0.2, 1.0, F.color_mat(Color("6c6f73")), Vector3.ZERO, 10)
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stream)
	# The boom operator's spot: on the jump form's walkway, at the slab's edge nearest the mast
	var edge := _inside(Vector3(at.x, 0, at.y) - centre) + centre
	var back := Vector3(at.x - edge.x, 0, at.y - edge.z)
	boom_spot = edge + (back.normalized() * 0.6 if back.length() > 0.1 else Vector3.ZERO)
	var st := Node3D.new()
	st.position = boom_spot
	view.add_child(st)
	view.stations = {"boom": {"node": st}}
	# The bays run along x from the far (-x) end
	start = _inside(Vector3(-pour.bw * 0.5 + 3.0, 0, 0)) + centre
	# Their screed board and two pokers, each poker on its own drive unit
	screed_m = ScreedScript.new()
	view.add_child(screed_m)
	screed_m.build(view)
	view.screed = screed_m
	for i in 2:
		var pk = PokerScript.new()
		view.add_child(pk)
		view.poker = pk
		pk.build(view)
		pokers.append(pk)
	# The crew: the same chibis as ours, in white
	var n_pk := 0
	for role in ROLES:
		var p := PlayerScript.new()
		p.setup(0, Color("f4f7fa"))
		p.tag.visible = false
		p.prompt.visible = false
		p.ring.visible = false
		p.ai = true
		p.bot = true
		p.role = role
		p.zone = "deck"
		F.kit(p.model, role)
		add_child(p)
		var m := {"p": p, "role": role, "pk": null, "bi": 0}
		if role == "poker":
			m["pk"] = pokers[n_pk]
			m["bi"] = n_pk
			n_pk += 1
		crew.append(m)
		view.players.append(p)
		if not view.crew.crew.has(role):
			view.crew.crew[role] = p
	start_level()

## A new deck: clean formwork, the crew back at the far end.
func start_level() -> void:
	_drop_hose()
	for m in crew:
		var p = m["p"]
		if m["pk"] != null and p.tool == "poker":
			m["pk"].put_down(p)
		p.busy = ""
	screed_m.clear()
	for pk in pokers:
		pk.clear()
	pour.reset()
	pour.set_cured(0.0)
	done = false
	pumping = false
	by_hand = 0
	_pump_t = 0.0
	_finish = 0.0
	_full_at = -1.0
	# (fresh bots each level: their routes, slips and strips start over)
	for bt in bots:
		bt.queue_free()
	bots.clear()
	for i in 2:
		var bt = BotsScript.new()
		bt.name = "BotsB%d" % i
		add_child(bt)
		bt.setup(view)
		bots.append(bt)
	tip_pos = start + Vector3(1.0, 0, 0)
	view.tip_target = tip_pos
	for i in crew.size():
		var p = crew[i]["p"]
		if crew[i]["role"] == "boom":
			p.position = boom_spot
		else:
			p.position = _inside(start - centre + Vector3(1.5 + i * 1.2, 0, 1.0 - i * 0.8)) + centre
	for i in pokers.size():
		var u: Vector3 = _inside(start - centre + Vector3(2.0, 0, -1.8 + i * 3.6)) + centre
		pokers[i].unit_local = Vector3(u.x, 0, u.z)
		pokers[i].unit.position = pokers[i].unit_local

## (dev shots) the middle of their crew, the boom operator left out.
func crew_centre() -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for m in crew:
		if m["role"] != "boom":
			c += (m["p"] as Node3D).global_position
			n += 1
	return c / maxf(1.0, n)

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

## Pour B and a step round its forms, never into the core.
func walkable(q: Vector3) -> bool:
	var v := Vector2(q.x, q.z)
	return Geometry2D.is_point_in_polygon(v, _walk) and not Geometry2D.is_point_in_polygon(v, _core)

## Spots on their deck the bots ask for by name (main.deck_pos's keys).
func spot(key: String) -> Vector3:
	match key:
		"boom", "dogman", "bin":
			return Vector3(boom_spot.x, 0, boom_spot.z)
		"hoist", "ladder":
			return Vector3(1e5, 0, 1e5)   # (none on their side)
		"screed":
			return Vector3(start.x - 3.2, 0, start.z - 8.2)   # (bots add 3.2, 8.2)
		"poker":
			return Vector3(start.x - 0.5, 0, start.z + 1.8)   # (bots add 0.5, -1.8)
	return Vector3(start.x, 0, start.z)

## Where the concrete comes out: the hose hand's nozzle, or the end of the hanging hose.
func discharge() -> Vector3:
	var h = view.hose_holder
	if h != null and is_instance_valid(h) and h.busy == "hose":
		var f := Vector3(sin(h.model.rotation.y), 0, cos(h.model.rotation.y))
		return h.hand_l.global_position + f * 0.3 + Vector3(0, -0.12, 0)
	return tip.global_position + Vector3(0, -HOSE, 0)

func _take_hose(p) -> void:
	view.hose_holder = p
	p.busy = "hose"
	p.bounce()
	hang.visible = false

func _drop_hose() -> void:
	var h = view.hose_holder
	if h != null and is_instance_valid(h) and h.busy == "hose":
		h.busy = ""
	view.hose_holder = null
	hose_call = false
	if hang:
		hang.visible = true
	for s in _segs:
		s.visible = false

## `frac`: how far our own pour's got (0..1). `deck_y`: the top of the formply (main.deck_top). `head_y`: the boom
## head's height (it rides the jump form with ours).
func update(delta: float, frac: float, phase: String, deck_y: float, head_y: float) -> void:
	var t0 := Time.get_ticks_usec()
	_update(delta, frac, phase, deck_y, head_y)
	if view.autotest:
		_cost_us += Time.get_ticks_usec() - t0
		_cost_n += 1

var _cost_us := 0
var _cost_n := 0

func _update(delta: float, frac: float, phase: String, deck_y: float, head_y: float) -> void:
	_t += delta
	visible = phase != "topout"
	pour.position.y = deck_y
	view.rig.position.y = deck_y
	view.work_y = deck_y
	(view.stations["boom"]["node"] as Node3D).position.y = deck_y
	boom_spot.y = deck_y
	head.position.y = head_y
	var bottom: float = deck_y - 3.0 * float(game.FH)
	mast.position = Vector3(head.position.x, (head_y + bottom) * 0.5, head.position.z)
	mast.scale.y = head_y - bottom
	pour.open_time = maxf(60.0, float(game.pour.open_time) * 2.5)
	view.phase_t = float(game.phase_t)
	view.cam_yaw = float(game.cam_yaw)
	view.k = int(game.k)
	view.score.bot_tier = int(game.score.bot_tier)
	view.ops.primed = frac > 0.0 or bool(game.ops.primed)
	# Their pour runs while ours does, and on through our screeding if they're still at it; past
	# that ours is locked off with theirs, so whatever's left is finished off quick
	view.phase = "pour" if phase in ["pour", "screed"] and not done else ("done" if phase == "pour" else phase)
	if not visible or phase in ["select", "roles"]:
		return
	if phase != _was_phase:
		if _was_phase == "pour" and view.autotest:
			print("[autotest] pour B when ours filled: %.0f%% in, %s, %d cells finished by hand" % [view._filled_ratio() * 100.0, "done" if done else "still going", by_hand])
		_was_phase = phase
	var cov: float = view._filled_ratio()
	if view.phase == "pour":
		_finishing(delta, cov)
		if view.autotest:
			_log(delta, frac, cov)
	elif not done and phase in ["cure", "sign", "report"]:
		# (ours is done and locked: what's left of theirs is finished off and goes hard with it)
		if _finish <= 0.0:
			_drop_hose()
			pour.finish_vibration(1.0)
			if view.autotest:
				print("[autotest] pour B finished off: %.0f%% in" % (cov * 100.0))
		_finish = minf(1.0, _finish + delta / 1.5)
		pour.screed(_finish, delta)
		if _finish >= 1.0:
			done = true
	if done and phase in ["cure", "sign", "report"]:
		pour.set_cured(1.0)
	_odd = not _odd
	_crew_tick(delta)
	_pump(delta, frac, cov)
	# (their concrete flows on every other frame, a double step: it's across the deck from ours, and
	# stepping it every frame cost as much as our own pour)
	_step_dt += delta
	if (view.phase == "pour" or _finish > 0.0 and _finish < 1.0) and _odd:
		pour.step(minf(_step_dt, 0.1))
		_step_dt = 0.0
	tip_pos = tip_pos.lerp(Vector3(view.tip_target.x, deck_y, view.tip_target.z), minf(1.0, delta * 4.0))
	tip_pos.y = deck_y
	if game.has_method("rig_clear"):
		# (the boom can't swing through the jump form: main.gd's own check, for this boom's head)
		var tc: Array = game.rig_clear(view.tip_target, head.global_position, L1, L2)
		view.tip_target = tc[0]
		var pc: Array = game.rig_clear(tip_pos, head.global_position, L1, L2)
		tip_pos = Vector3(pc[0].x, deck_y, pc[0].z)
	_boom()
	_draw_hose()

var _log_t := 0.0
var _pump_t := 0.0
## (test runs: how pour B's going, every 10 s)
func _log(delta: float, frac: float, cov: float) -> void:
	_pump_t += delta if pumping else 0.0
	_log_t += delta
	if _log_t < 10.0:
		return
	_log_t = 0.0
	var left: Vector2 = pour.work_left()
	var who := ""
	for m in crew:
		var p = m["p"]
		who += " %s(%s%s)" % [m["role"], p.busy, "/" + p.tool if p.tool != "" else ""]
		if OS.get_cmdline_user_args().has("--dbgb"):
			var bt = bots[int(m["bi"])]
			print("   %s at %s mv %s act %s walk %s pk %s scr %s" % [m["role"], str(p.position - pour.position).substr(0, 30), str(p.ai_move), p.ai_action, walkable(p.position), str(bt._pk_target), str(bt._scr.get("mode", ""))])
	var la: Vector2 = game.pour.work_left()
	print("[pourB] ours %.0f%% (raw %.0f%% rough %.0f%%)" % [frac * 100.0, la.x * 100.0, la.y * 100.0] + " theirs %.0f%% | raw %.1f%% rough %.1f%% | pumped %.0fs | %.2f ms/frame |%s" % [cov * 100.0, left.x * 100.0, left.y * 100.0, _pump_t, float(_cost_us) / maxf(1.0, _cost_n) / 1000.0, who])
	_cost_us = 0
	_cost_n = 0

## Full: done once it's all vibrated and screeded, and never stuck at it (as ours).
func _finishing(delta: float, cov: float) -> void:
	if cov < 1.0:
		return
	if _full_at < 0.0:
		_full_at = _t
		_fin_best = 9.0
		_fin_t = 0.0
		_fin_check = 0.0
	# (what's left is a scan of the whole slab: a few times a second is plenty)
	_fin_dt += delta
	_fin_check -= delta
	if _fin_check > 0.0:
		return
	_fin_check = 0.25
	delta = _fin_dt
	_fin_dt = 0.0
	var left: Vector2 = pour.work_left()
	var s := left.x + left.y
	if s <= 0.0:
		done = true
		_drop_hose()
		return
	if s < _fin_best - 0.002:
		_fin_best = s
		_fin_t = 0.0
	else:
		_fin_t += delta
	if _fin_t > FINISH_STALL or _t - _full_at > FINISH_MAX:
		by_hand += pour.finish_by_hand()
		_fin_t = 0.0

## Their pump: on while the hose hand holds the call (or the boom operator, with nobody on the hose).
func _pump(delta: float, frac: float, cov: float) -> void:
	var op = view._boom_operator()
	var want := false
	if view.phase == "pour" and op != null and cov < 1.0:
		want = hose_call if view.hose_holder != null else op.action_held()
	var local: Vector3 = view._pour_local(discharge())
	local.y = 0.0
	# (their trucks come as often as ours: well ahead of our pour, their pump waits on the next one)
	var ahead: float = cov - frac if frac < 0.999 else 0.0
	if ahead > AHEAD:
		want = false
	if want:
		pour.deposit(local, LineScript.PUMP_Q * (1.0 if ahead <= 0.0 else LineScript.LOW) * delta)
	pumping = want
	view.line.pumping = want
	pour.set_splash(want, local)
	stream.visible = want
	if want:
		var d := discharge()
		var under: float = pour.position.y + pour.height_at(local)
		var fall := maxf(0.1, d.y - under)
		stream.position = Vector3(d.x, under + fall * 0.5, d.z)
		stream.scale = Vector3(0.6 + 0.1 * sin(_t * 23.0), fall, 0.6 + 0.1 * sin(_t * 19.0))

## The crew: bots.gd sets each one's stick and buttons, then they act on them as ours do.
var _think_dt := 0.0

func _crew_tick(delta: float) -> void:
	_think_dt += delta
	var tier: int = view.score.bot_tier
	var cam := get_viewport().get_camera_3d()
	var cam_pos: Vector3 = cam.global_position if cam else Vector3.ZERO
	var shiver: Array = []
	for m in crew:
		var p = m["p"]
		var role: String = m["role"]
		var bt = bots[int(m["bi"])]
		p.begin_cues()
		# Standing on the wet concrete, boots just into it
		var stand: float = view.work_y
		if role != "boom":
			stand = maxf(stand, pour.position.y + pour.height_at(view._pour_local(p.position)) - BOOT_SINK)
		p.position.y = stand
		# (their bots think on the frames their concrete doesn't flow, every other one, and the stick
		# and buttons hold in between: half the cost, and nobody can tell from across the deck)
		if not _odd:
			if view.phase == "pour" and bt._slips_for != view.k:
				bt._plan_slips()
			bt._clear(p)
			p.pace = bt.PACE[tier]
			p.hurry = false
			if m["pk"] != null:
				view.poker = m["pk"]
			if not bt._slipping(p, role, _think_dt):
				match role:
					"boom": bt._boom(p, _think_dt)
					"hose": bt._hose(p, _think_dt)
					"poker": bt._poker(p, _think_dt)
					"screed": bt._screed(p, _think_dt)
		var pk_k: float = m["pk"].speed_k(p) if m["pk"] != null else 1.0
		p.speed = 6.0 * screed_m.speed_k(p) * pk_k * (HOSE_WALK_K if p.busy == "hose" else 1.0)
		p.walk(delta, Callable(view, "_walkable").bind(p), view.cam_yaw)
		_act(m, delta)
		p._update_balloons(delta, cam_pos)
		p.end_frame()
	for pk in pokers:
		pk.update(delta)
		for id in pk.users:
			var st: Dictionary = pk.users[id]
			if st["state"] == "in" and shiver.size() < 4:
				var sp: Vector3 = st["spot"]
				shiver.append(Vector4(sp.x, sp.z, 1.0 - 0.7 * (1.0 - float(pour.raw_count(sp, pk.R)) / float(maxi(1, st["raw0"]))), 0.0))
	if not _odd:
		_think_dt = 0.0
	# (both pokers' ripples, not just the last one's)
	pour.set_shiver(shiver)
	screed_m.update(delta)

## What a crew member's buttons do on their side: main.gd's _handle_player, for their jobs.
func _act(m: Dictionary, delta: float) -> void:
	var p = m["p"]
	var pouring: bool = view.phase == "pour"
	match String(m["role"]):
		"boom":
			if p.busy == "boom":
				if not pouring:
					p.busy = ""
					return
				var v: Vector2 = p.move_input()
				var t: Vector3 = view.tip_target + Vector3(v.x, 0, v.y).rotated(Vector3.UP, view.cam_yaw) * 7.0 * delta * p.pace
				t.x = clampf(t.x, centre.x - pour.bw * 0.5 + 0.6, centre.x + pour.bw * 0.5 - 0.6)
				t.z = clampf(t.z, centre.z - pour.bd * 0.5 + 0.6, centre.z + pour.bd * 0.5 - 0.6)
				view.tip_target = t
				p.face(Vector3(tip_pos.x, p.position.y, tip_pos.z))
			elif pouring and _flat(p.position, boom_spot) < 1.2 and p.action_pressed():
				p.busy = "boom"
				p.bounce()
		"hose":
			if p.busy == "hose":
				_hose_work(p)
			elif pouring and view.hose_holder == null and _flat(p.position, view.hose_anchor()) < 1.0 and p.action_pressed():
				_take_hose(p)
		"poker":
			var pk = m["pk"]
			if p.tool != "poker":
				if pouring and _flat(p.position, pk._unit_world()) < 1.3 and p.action_pressed():
					pk.pick_up(p)
			else:
				pk.handle_player(p, delta)
		"screed":
			screed_m.handle_player(p, delta)

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _hose_work(p) -> void:
	if view.phase != "pour":
		_drop_hose()
		return
	# The end hose only reaches so far from under the boom tip: past that, the boom drags you along
	var a: Vector3 = view.hose_anchor()
	var off := Vector2(p.position.x - a.x, p.position.z - a.z)
	if off.length() > view.HOSE_REACH:
		off = off.normalized() * view.HOSE_REACH
		p.position.x = a.x + off.x
		p.position.z = a.z + off.y
	var sway := 0.04 * sin(_t * 3.0)
	p.pose_arms(Vector3(-1.25 + sway, 0, 0.85), Vector3(-0.75 - sway, 0, -0.85))
	hose_call = p.action_held()

## The end hose: a sagging run from the boom tip to the hose hand's hands, then out to the nozzle.
func _draw_hose() -> void:
	var h = view.hose_holder
	if h == null or not is_instance_valid(h):
		return
	if _segs.is_empty():
		for i in 8:
			var seg := F.cylinder(0.16, 1.0, F.mat("hose"), Vector3.ZERO, 8)
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(seg)
			_segs.append(seg)
	var a: Vector3 = tip.global_position
	var back: Vector3 = h.hand_r.global_position
	var mid := (a + back) * 0.5 + Vector3(0, -0.8, 0)
	var prev := a
	var run := _segs.size() - 2
	for i in _segs.size():
		var q: Vector3
		if i < run:
			var u := float(i + 1) / run
			q = a.lerp(mid, u).lerp(mid.lerp(back, u), u)
		else:
			q = h.hand_l.global_position if i == run else discharge()
		_seg(_segs[i], prev, q)
		prev = q

func _seg(seg: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var ln := d.length()
	seg.visible = ln > 0.02
	if not seg.visible:
		return
	var dir := d / ln
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	seg.transform = Transform3D(Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, -PI * 0.5), (a + b) * 0.5)
	seg.scale = Vector3(1, ln, 1)

func _boom() -> void:
	var hp := head.position + Vector3(0, SHOULDER, 0)
	var t := tip_pos + Vector3(0, 1.3 + HOSE, 0)
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

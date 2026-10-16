## The poker vibrator, done the way the crew does it: plunge the poker
## straight down and hold it while trapped air comes up out of the concrete.
## You can see and hear it working: the surface trembles around the head and
## spits little air bubbles, the drive unit drones, and as the concrete
## compacts the bubbles stop, the drone steadies and the cream comes up glossy.
## Then lift it out slowly and move on about one and a half times its radius
## of action. Don't drag it sideways. The poker runs off a drive unit on a
## flexible shaft, so whoever's on it has to tow the unit along as the pour
## moves. Hold it in long after it's done and bleed water comes to the top.
extends Node3D

const F := preload("res://scripts/factory.gd")

const R := 1.5             # radius of action, m (game scale)
const COMPACT_T := 0.6     # s for a person to compact a spot
const NPC_T := 1.25        # the crew are a bit slower
const OVER_T := 2.5        # s held after it's done before bleed water comes up
const HOSE_LEN := 6.5      # flexible shaft length, m
const CREEP := 0.13        # walking speed while it's in the concrete (share of normal)
const LEASH := 1.3         # m you can work it along from where it went in
const GOOD_SHARE := 0.45   # gold: at least this much of the circle is raw concrete

var game
var pour
var unit: Node3D
var unit_local := Vector3(1.5, 0, 4.4)    # on the deck, rig-local
var users := {}            # instance id -> state
var hint: Node3D           # where to plunge next, for a person holding the poker
var _hint_mat: StandardMaterial3D
var _plop_t := 0.0

func build(owner_game) -> void:
	game = owner_game
	pour = game.pour
	# The drive unit: a little petrol motor on a skid with a pull handle
	unit = Node3D.new()
	unit.add_child(F.box(Vector3(0.7, 0.08, 0.5), F.mat("navy"), Vector3(0, 0.04, 0)))
	var motor := F.box(Vector3(0.5, 0.4, 0.4), F.mat("yellow", true), Vector3(0, 0.3, 0))
	motor.name = "Motor"
	unit.add_child(motor)
	unit.add_child(F.cylinder(0.12, 0.3, F.mat("hose"), Vector3(-0.18, 0.55, 0), 8))
	unit.add_child(F.beam(Vector3(0.3, 0.1, 0), Vector3(0.6, 0.7, 0), 0.04, F.mat("steel")))
	game.rig.add_child(unit)
	unit.position = unit_local
	# The "plunge here" hint: a soft chevron bobbing over the next raw spot
	hint = Node3D.new()
	_hint_mat = StandardMaterial3D.new()
	_hint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hint_mat.albedo_color = Color(0.77, 0.61, 1.0, 0.55)
	_hint_mat.no_depth_test = true
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.0
	cm.height = 0.3
	cm.radial_segments = 4
	cone.mesh = cm
	cone.material_override = _hint_mat
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hint.add_child(cone)
	var stem := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.06, 0.28, 0.06)
	stem.mesh = sm
	stem.material_override = _hint_mat
	stem.position.y = 0.28
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hint.add_child(stem)
	hint.visible = false
	pour.add_child(hint)

## Deck position (rig-local) of the POKER pick-up spot: next to the unit.
func station_local() -> Vector3:
	return unit_local

func _state(who) -> Dictionary:
	var id: int = who.get_instance_id()
	if not users.has(id):
		var st := {"state": "", "t": 0.0, "done_t": 0.0, "spot": Vector3.ZERO, "bled": false, "raw0": 1}
		var bub := CPUParticles3D.new()
		bub.amount = 14
		bub.lifetime = 0.45
		bub.emitting = false
		bub.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		bub.emission_box_extents = Vector3(R * 0.55, 0.01, R * 0.55)
		bub.direction = Vector3(0, 1, 0)
		bub.spread = 12.0
		bub.initial_velocity_min = 0.25
		bub.initial_velocity_max = 0.6
		bub.gravity = Vector3(0, -0.4, 0)
		bub.scale_amount_min = 0.4
		bub.scale_amount_max = 1.1
		var sm := SphereMesh.new()
		sm.radius = 0.045
		sm.height = 0.09
		sm.radial_segments = 6
		sm.rings = 3
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.93, 0.95, 1.0, 0.8)
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.material = bm
		bub.mesh = sm
		pour.add_child(bub)
		st["bub"] = bub
		users[id] = st
	return users[id]

## Gives a player the poker: the head in their hand and the shaft back to the unit.
func pick_up(p) -> void:
	p.tool = "poker"
	var prop := Node3D.new()
	prop.name = "PokerProp"
	var head := F.cylinder(0.05, 0.55, F.mat("steel", true), Vector3(0, -0.32, 0.05), 8)
	head.name = "Head"
	prop.add_child(head)
	p.hand_r.add_child(prop)
	var hose := F.cylinder(0.035, 1.0, F.mat("hose"), Vector3.ZERO, 6)
	game.add_child(hose)
	var st := _state(p)
	st["hose"] = hose
	st["state"] = ""
	game.sfx.hit("clank")
	p.bounce()

func put_down(p) -> void:
	p.tool = ""
	p.busy = ""
	var prop: Node = p.hand_r.get_node_or_null("PokerProp")
	if prop:
		prop.queue_free()
	var st := _state(p)
	if st.has("hose"):
		(st["hose"] as Node).queue_free()
		st.erase("hose")
	(st["bub"] as CPUParticles3D).emitting = false
	st["state"] = ""
	p.model.position = Vector3.ZERO

func _crew(who) -> bool:
	return who.get("role") != null and who.get("role") != ""

## One frame of plunging. Returns true while the poker is in the concrete or
## being withdrawn.
func _work(who, st: Dictionary, holding: bool, delta: float, compact_t: float) -> bool:
	var bub: CPUParticles3D = st["bub"]
	match st["state"]:
		"":
			if holding:
				var local: Vector3 = st["spot"]
				if pour.height_at(local) < 0.06:
					return false
				st["state"] = "in"
				st["t"] = 0.0
				st["done_t"] = 0.0
				st["bled"] = false
				st["raw0"] = maxi(1, pour.raw_count(local, R))
				game.sfx.hit("plop")
				return true
			return false
		"in":
			st["t"] += delta
			var local: Vector3 = st["spot"]
			var left: int = pour.vibrate(local, R * 1.15, delta, compact_t)
			var prog: float = 1.0 - float(left) / float(st["raw0"])
			bub.position = Vector3(local.x, pour.height_at(local) + 0.03, local.z)
			bub.emitting = left > 0
			bub.initial_velocity_max = lerpf(0.7, 0.3, prog)
			if left == 0:
				if st["done_t"] == 0.0:
					game.sfx.hit("chime")
					if _crew(who):
						game.score.award(who, 5, "Poker")
						game.haptic(who, "30,40,30")
				st["done_t"] += delta
				if st["done_t"] > OVER_T and not st["bled"]:
					st["bled"] = true
					pour.mark_bleed(local, R * 0.6)
					game.sfx.hit("hiss")
					if _crew(who):
						game.score.award(who, -10, "Over-vibrated")
						game.pop("bleed water!", pour.global_position + local + Vector3(0, 1.2, 0), Color("6fa8dc"))
			if not holding:
				if st["done_t"] > 0.0 and not st["bled"] and _crew(who):
					game.score.award(who, 2, "Poker")
				st["state"] = "out"
				st["t"] = 0.0
				bub.emitting = false
			return true
		"out":
			st["t"] += delta
			if st["t"] > 0.35:
				st["state"] = ""
				return false
			return true
	return false

## How fast someone holding the poker can walk: a slow creep while it's in.
func speed_k(p) -> float:
	if p.tool != "poker":
		return 1.0
	return CREEP if _state(p)["state"] == "in" else 1.0

## The person on the poker. Returns true (they're always handled while holding it).
##
## Hold A to put it in and keep holding: you can creep it along a little way
## (slowly, LEASH metres from where it went in) while it works. When you can't
## go any further, or the purple's all gone, let go and walk on.
func handle_player(p, delta: float) -> bool:
	if p.tool != "poker":
		return false
	var st := _state(p)
	if game.phase != "pour":
		put_down(p)
		return true
	var local: Vector3 = p.position - pour.position
	local.y = 0.0
	var at_end := false
	if st["state"] == "in" and st.has("origin"):
		# On the leash: it won't come any further from where it went in
		var o: Vector3 = st["origin"]
		var off := local - o
		if off.length() > LEASH:
			off = off.normalized() * LEASH
			local = o + off
			p.position.x = pour.position.x + local.x
			p.position.z = pour.position.z + local.z
		at_end = off.length() > LEASH - 0.12
	var was: String = st["state"]
	if st["state"] in ["", "in"]:
		st["spot"] = local + Vector3(sin(p.model.rotation.y), 0, cos(p.model.rotation.y)) * 0.45
	var busy_now := _work(p, st, p.action_held(), delta, COMPACT_T)
	if was == "" and st["state"] == "in":
		st["origin"] = local
	p.busy = "plunge" if busy_now else ""
	var prop: Node3D = p.hand_r.get_node_or_null("PokerProp")
	match st["state"]:
		"in":
			var left: int = pour.raw_count(st["spot"], R)
			st["raw0"] = maxi(int(st["raw0"]), left)
			if left > 0:
				st["done_t"] = 0.0
			var prog := 1.0 - float(left) / float(st["raw0"])
			var done: bool = left == 0
			# Done here, or it won't reach any further: the button goes red and
			# shakes, saying stop, let go
			var stop := done or at_end
			p.cue("action", ("done here: let go" if done else "let go") if stop else "hold · creep along", clampf(prog, 0.0, 1.0), stop, Vector2(-1, -1), stop and not p.bot)
			# Leaning on it with both hands; the whole chibi buzzes with it
			var buzz := (1.0 - prog * 0.6) * 0.025
			p.model.position = Vector3(sin(game.phase_t * 83.0), 0, cos(game.phase_t * 71.0)) * buzz
			p.pose_arms(Vector3(-0.55, 0, -0.05), Vector3(-0.4 + 0.06 * sin(game.phase_t * 70.0), 0, 0.08))
			if prop:
				var dip := clampf(st["t"] * 3.0, 0.0, 1.0)
				prop.position = Vector3(sin(game.phase_t * 90.0) * 0.012, -0.25 * dip, 0)
			if fmod(st["t"], 0.3) < delta:
				game.haptic(p, "70" if not done else "25")
		"out":
			p.model.position = Vector3.ZERO
			p.pose_arms(Vector3(-0.9, 0, -0.1), Vector3(-0.9, 0, 0.1))
			if prop:
				prop.position = Vector3(0, -0.25 * (1.0 - st["t"] / 0.35), 0)
		_:
			p.model.position = Vector3.ZERO
			if prop:
				prop.position = Vector3.ZERO
			var raw: int = pour.raw_count(st["spot"], R)
			if raw > 0:
				p.cue("action", "plunge", -1.0, true)
				# Gold: a good spot, the circle well into the purple
				if not p.bot:
					p.gold(pour.raw_share(st["spot"], R) >= GOOD_SHARE)
			p.pose_arms(Vector3(-0.8, 0, -0.2), Vector3(-0.8, 0, 0.2))
			# Tow the drive unit along behind you
			var ud := _unit_world()
			var dist := Vector2(p.position.x - ud.x, p.position.z - ud.z).length()
			if p.alt_held():
				var to: Vector3 = p.position - game.rig.position
				to.y = 0.0
				var dir: Vector3 = to - unit_local
				if dir.length() > 1.4:
					unit_local += dir.normalized() * minf(dir.length() - 1.4, 3.2 * delta)
					unit.position = unit_local
			if p.slow_pressed():
				game.call_boom(p.position)
			if p.leave_pressed():
				put_down(p)
				return true
			# Walk further than the shaft reaches and you drag the unit along
			if dist > HOSE_LEN:
				var pull := Vector3(p.position.x - ud.x, 0, p.position.z - ud.z).normalized() * (dist - HOSE_LEN)
				unit_local += pull
				unit_local.x = clampf(unit_local.x, -7.6, 7.6)
				unit_local.z = clampf(unit_local.z, -5.6, 5.6)
				unit.position = unit_local
	_draw_hose(p, st)
	return true

func _unit_world() -> Vector3:
	return game.rig.position + unit_local

func _draw_hose(p, st: Dictionary) -> void:
	if not st.has("hose"):
		return
	var a := _unit_world() + Vector3(-0.18, 0.55, 0)
	var b: Vector3 = p.hand_r.global_position
	var hose: MeshInstance3D = st["hose"]
	var d := b - a
	var ln := d.length()
	if ln < 0.05:
		return
	var dir := d / ln
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	hose.transform = Transform3D(Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, -PI * 0.5), (a + b) * 0.5 + Vector3(0, -0.15, 0))
	hose.scale = Vector3(1, ln, 1)

## A crew concreter standing at `local`: plunge, wait for the bubbles to stop,
## lift out. Returns true while they're busy at this spot.
func npc_work(n: Node3D, local: Vector3, delta: float) -> bool:
	var st := _state(n)
	if st["state"] == "":
		st["spot"] = local
	var raw: int = pour.raw_count(st["spot"], R)
	if st["state"] == "" and raw == 0:
		return false
	var want: bool = st["state"] != "in" or raw > 0
	if st["state"] == "in" and st["t"] > 4.0:
		want = false
	var busy_now := _work(n, st, want, delta, NPC_T)
	var al: Node3D = n.get_node("ArmL")
	var ar: Node3D = n.get_node("ArmR")
	if st["state"] == "in":
		al.rotation = Vector3(-0.6, 0, -0.1)
		ar.rotation = Vector3(-0.35 + 0.05 * sin(game.phase_t * 70.0), 0, 0.1)
	return busy_now

func npc_idle(n: Node3D) -> void:
	var st := _state(n)
	(st["bub"] as CPUParticles3D).emitting = false
	st["state"] = ""

## Pour-local spot a poker-width on from `from` that's still raw, or INF.
func next_spot(from: Vector3) -> Vector3:
	var best := 1e9
	var out := Vector3(INF, 0, 0)
	var g: Vector3 = pour.needs_vibrating(from)
	if g.x == INF:
		return out
	# Prefer a spot about 1.5 R away, overlapping the last
	for k in 12:
		var ang := k * TAU / 12.0
		var c := from + Vector3(cos(ang), 0, sin(ang)) * R * 1.4
		var raw: int = pour.raw_count(c, R * 0.7)
		if raw > 3:
			var d := c.distance_to(g)
			if d < best:
				best = d
				out = c
	return out if out.x != INF else g

func update(delta: float) -> void:
	# The surface trembles round every poker that's in, and the drone follows
	# the nearest one a person is working
	var shiver: Array = []
	var loud := 0.0
	var pitch := 0.0
	for id in users:
		var st: Dictionary = users[id]
		if st["state"] == "in" and shiver.size() < 4:
			var sp: Vector3 = st["spot"]
			var prog := 1.0 - float(pour.raw_count(sp, R)) / float(maxi(1, st["raw0"]))
			shiver.append(Vector4(sp.x, sp.z, 1.0 - prog * 0.7, 0.0))
			var who = instance_from_id(id)
			var k := 0.45
			if who != null and who.get("bot") == false:
				k = 1.0
			if k > loud:
				loud = k
				pitch = prog
	pour.set_shiver(shiver)
	game.sfx.rumble = loud if game.phase == "pour" else 0.0
	game.sfx.rumble_pitch = pitch
	if loud > 0.0:
		_plop_t -= delta
		if _plop_t <= 0.0 and pitch < 0.95:
			_plop_t = randf_range(0.08, 0.3) + pitch * 0.4
			game.sfx.hit("plop")
	var motor: Node3D = unit.get_node("Motor")
	motor.position.y = 0.3 + (0.012 * sin(game.phase_t * 80.0) if game.phase == "pour" else 0.0)
	# The hint for a person holding the poker
	hint.visible = false
	for p in game.players:
		if p.tool == "poker" and not p.bot and _state(p)["state"] == "":
			var local: Vector3 = p.position - pour.position
			local.y = 0.0
			var spot := next_spot(local)
			if spot.x != INF:
				hint.visible = true
				hint.position = Vector3(spot.x, pour.height_at(spot) + 0.45 + 0.12 * sin(game.phase_t * 5.0), spot.z)
				_hint_mat.albedo_color.a = 0.35 + 0.25 * sin(game.phase_t * 5.0)
			break

func clear() -> void:
	hint.visible = false
	for p in game.players:
		if p.tool == "poker":
			put_down(p)
	for id in users:
		(users[id]["bub"] as CPUParticles3D).emitting = false
		users[id]["state"] = ""
	pour.set_shiver([])
	game.sfx.rumble = 0.0

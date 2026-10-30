## Screeding, done by hand the way a concreter does it behind the pokers: a
## long aluminium screed board held low in both hands and sawed side to side
## as it's dragged across the fresh concrete. It cuts the high spots down to
## the slab level and pushes the surplus along in a roll in front of the board
## to fill the low spots. Screed it after it's been vibrated (the poker would
## spoil a finished surface) and before it goes off.
extends Node3D

const F := preload("res://scripts/factory.gd")

var BOARD := 3.0            # m (a longer board on a bigger slab, set in build)
const REACH := 0.85         # board ahead of the hands
const SPEED_K := 0.95       # walking speed while screeding (the bots)
const PERSON_K := 0.68      # a person screeding: a steady pull, not a jog (quicker on the big slab)
const CARRY_K := 1.0        # a person carrying the board about
const BOTTOM := 0.07        # board centre above its bottom edge
const TILT := 0.12          # rad the board tips, the near (leading) edge up
const MAX_CARRY := 0.35     # m³ the roll can hold before it spills past the ends

var _gold_t := 0.0     # the board finished something just now (gold cue)
var game
var pour
var rack_local := Vector3(-7.2, 0, -5.0)   # where the board leans against the edge form
var board: Node3D           # the board, on the rack or in someone's hands
var roll: MeshInstance3D    # the surplus rolling in front of the board
var holder = null
var carry := 0.0
var _locked_yaw := 0.0
var _working := false
var _scrape_t := 0.0
var _saw := 0.0
var _raw_warned := 0.0
var _crumbs: CPUParticles3D
var _down := 0.0            # 0 upright like a staff .. 1 down in the screeding position
var _want_down := false
var _idle_t := 0.0
var _spin_t := -1.0         # >= 0 while doing staff tricks
var _over_concrete := true
var _input_seen := false
# The bull float (X swaps to it, a person on the screed): screeded concrete
# comes up shiny with bleed water and goes matt, and that's when it's floated
const FLOAT_REACH := 4.4    # m out from the hands to the blade
const FLOAT_W := 1.2        # blade length, m
var floating := false
var float_node: Node3D
var _float_pole: Node3D
var _float_told := 0.0
var _float_slide := 0.0

func build(owner_game) -> void:
	game = owner_game
	pour = game.pour
	BOARD = 3.0 * minf(1.7, sqrt(pour.vol_k))
	board = Node3D.new()
	# Aluminium box-section screed (1 m modelled, stretched to length) and two
	# D-handles
	var beam := F.prop("ScreedBoard")
	beam.scale.x = BOARD
	board.add_child(beam)
	for x in [-0.45, 0.45]:
		var h := F.prop("ScreedHandle")
		h.position = Vector3(x, 0.055, 0.0)
		board.add_child(h)
	_rest()
	roll = F.cylinder(1.0, BOARD - 0.2, F.color_mat(Color("767a7e")), Vector3.ZERO, 10)
	roll.rotation.z = PI * 0.5
	roll.visible = false
	add_child(roll)
	_crumbs = CPUParticles3D.new()
	_crumbs.amount = 24
	_crumbs.lifetime = 0.4
	_crumbs.emitting = false
	_crumbs.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_crumbs.emission_box_extents = Vector3(1.2, 0.02, 0.05)
	_crumbs.direction = Vector3(0, 1, 0)
	_crumbs.spread = 40.0
	_crumbs.initial_velocity_min = 0.6
	_crumbs.initial_velocity_max = 1.4
	_crumbs.gravity = Vector3(0, -9, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	sm.radial_segments = 5
	sm.rings = 3
	sm.material = F.color_mat(Color("6f7276"))
	_crumbs.mesh = sm
	add_child(_crumbs)
	float_node = F.prop("BullFloatHead")
	float_node.visible = false
	add_child(float_node)
	_float_pole = float_node.find_child("BullFloatPole", true, false) as Node3D

## The board always goes with the screeder: upright at their side like a
## staff when they're not using it, and down in front when they screed.
func _rest() -> void:
	pass

## Deck position (rig-local) of the old screed rack (kept for the station).
func station_local() -> Vector3:
	return rack_local

## Hands the board to whoever's the screeder now.
func pick_up(p) -> void:
	if holder != null and holder != p and is_instance_valid(holder):
		holder.tool = ""
	p.tool = "screed"
	holder = p
	_put_float_away()
	if board.get_parent():
		board.get_parent().remove_child(board)
	p.model.add_child(board)
	_down = 0.0
	_spin_t = -1.0
	_idle_t = 0.0

## (The screeder never puts the board down now; this just stops screeding.)
func put_down(_p) -> void:
	_dump()
	_working = false

## Letting go of the board. At the formwork the surplus gets struck off over
## the edge (it's shovelled into a barrow); anywhere else it's left spread
## thin along the board, not dropped in one heap.
func _dump() -> void:
	if carry > 0.02 and holder != null:
		var c: Vector3 = _board_center(holder) - pour.position
		var feet: Vector3 = holder.global_position - pour.position
		var edge: float = minf(minf(pour.bw * 0.5 - absf(c.x), pour.bd * 0.5 - absf(c.z)), minf(pour.bw * 0.5 - absf(feet.x), pour.bd * 0.5 - absf(feet.z)))
		if edge > 0.9:
			var fwd := Vector3(sin(holder.model.rotation.y), 0, cos(holder.model.rotation.y))
			var right := fwd.cross(Vector3.UP)
			for k in 6:
				pour.deposit(c + right * (BOARD * (float(k) / 5.0 - 0.5) * 0.9), carry / 6.0, false)
	carry = 0.0
	roll.visible = false

## The last pull into the formwork: once the board's being dragged right up to
## an edge, the screeder steps out over the form and pulls it home, so the
## strip between the board and that edge gets finished too.
func _finish_to_edge(p, c: Vector3, right: Vector3, fwd: Vector3, saw: float, delta: float) -> void:
	var e := -fwd   # the way you're walking: from the board toward your feet
	var t_edge := INF
	if absf(e.x) > 0.3:
		t_edge = minf(t_edge, ((pour.bw * 0.5 * signf(e.x)) - c.x) / e.x)
	if absf(e.z) > 0.3:
		t_edge = minf(t_edge, ((pour.bd * 0.5 * signf(e.z)) - c.z) / e.z)
	if t_edge == INF or t_edge > REACH + 0.75:
		return
	var s := 0.28
	while s < t_edge - 0.05:
		var cc: Vector3 = c + e * minf(s, t_edge - 0.15)
		var res: Dictionary = pour.screed_strip(cc - right * (BOARD * 0.5) + right * saw, cc + right * (BOARD * 0.5) + right * saw, delta, carry)
		carry = res["carry"]
		var done: int = res["done"]
		if done > 0:
			game.score.trickle(p, float(done) * 0.25, "Screeding")
		s += 0.28
	# What's left in front of the board goes over the form into the barrow
	if t_edge < REACH + 0.5:
		carry = 0.0

func _board_center(p) -> Vector3:
	var fwd := Vector3(sin(p.model.rotation.y), 0, cos(p.model.rotation.y))
	return p.global_position + fwd * REACH

## The screeder, with the board. Returns true while they're screeding (so
## everything else they might do near a station still works the rest of the time).
func handle_player(p, delta: float, near := "") -> bool:
	if p.tool != "screed" or p != holder:
		return false
	_input_check(p)
	if game.phase != "pour" or p.zone != "deck":
		if _working:
			_working = false
			_dump()
		_put_float_away()
		return false
	var hold: bool = p.action_held()
	# At a station that wants A for something else, A is for that
	if not _working and near != "" and not (near in ["screed", "poker", "boom"]):
		return false
	# X: swap the board for the bull float, and back
	if not p.bot and not _working and p.alt_pressed():
		floating = not floating
		game.sfx.hit("clank")
		if not floating:
			_put_float_away()
	if floating:
		return _float(p, delta, hold)
	_want_down = hold
	if hold and not _working and _down > 0.7:
		_working = true
		_locked_yaw = p.model.rotation.y
	elif not hold and _working:
		_working = false
		_dump()
	var fwd := Vector3(sin(p.model.rotation.y), 0, cos(p.model.rotation.y))
	var right := fwd.cross(Vector3.UP)
	if _working:
		# Screeding is done walking backwards: you face the board and pull it
		# toward you, sawing it side to side as you step back
		var v: Vector2 = p.move_input()
		var moving: bool = v.length() > 0.2
		if moving:
			var mdir := Vector3(v.x, 0, v.y).rotated(Vector3.UP, game.cam_yaw)
			_locked_yaw = atan2(-mdir.x, -mdir.z)
		p.model.rotation.y = _locked_yaw
		fwd = Vector3(sin(_locked_yaw), 0, cos(_locked_yaw))
		right = fwd.cross(Vector3.UP)
		_saw += delta * (9.0 if moving else 4.0)
		var saw := sin(_saw) * 0.14
		var c: Vector3 = p.global_position + fwd * REACH - pour.position
		c.y = 0.0
		var a: Vector3 = c - right * (BOARD * 0.5) + right * saw
		var b: Vector3 = c + right * (BOARD * 0.5) + right * saw
		# Nothing under the board yet (bare deck): it just rides along
		_over_concrete = pour.height_at(c) > 0.05 or pour.height_at(a) > 0.05 or pour.height_at(b) > 0.05 or carry > 0.01
		var res: Dictionary = pour.screed_strip(a, b, delta, carry)
		carry = res["carry"]
		if moving:
			_finish_to_edge(p, c, right, fwd, saw, delta)
		if carry > MAX_CARRY:
			# Too much in front: it spills off the ends of the board
			var spill: float = carry - MAX_CARRY
			for k in 3:
				pour.deposit(a - fwd * 0.2 - right * (0.15 * k), spill / 6.0, false)
				pour.deposit(b - fwd * 0.2 + right * (0.15 * k), spill / 6.0, false)
			carry = MAX_CARRY
		var done: int = res["done"]
		var raw: int = res["raw"]
		_raw_warned = maxf(0.0, _raw_warned - delta)
		if raw > 4 and _raw_warned <= 0.0:
			# Board's over concrete nobody's poked yet: it won't finish it
			_raw_warned = 4.0
			p.bark("Needs a poke first!", 1.4)
			if not p.bot:
				game.hud.toast("Purple's not vibrated: the screed won't finish it", 1.8)
		if int(res.get("held", 0)) > 4 and raw <= 4 and _raw_warned <= 0.0:
			# Vibrated, but the poker hasn't said she's right on this strip
			_raw_warned = 4.0
			p.bark("Waiting on she's right!", 1.4)
			if not p.bot:
				game.hud.toast("Screed the green strips: the poker calls each one when it's done", 1.8)
		if done > 0:
			game.score.trickle(p, float(done) * 0.25, "Screeding")
			_gold_t = 0.35
		roll.visible = carry > 0.01
		if roll.visible:
			var r := clampf(sqrt(carry / (PI * (BOARD - 0.2))) * 1.0, 0.04, 0.2)
			# The surplus rolls along on the near side of the board, toward you
			var rp: Vector3 = p.global_position + fwd * maxf(0.25, REACH - 0.12 - r) + right * saw
			rp.y = pour.global_position.y + pour.SLAB + r * 0.8
			roll.global_position = rp
			roll.scale = Vector3(r, 1.0, r)
			roll.rotation = Vector3(0.0, _locked_yaw, PI * 0.5)
		_crumbs.global_position = p.global_position + fwd * REACH + Vector3(0, 0.1, 0)
		_crumbs.global_rotation = Vector3(0, _locked_yaw, 0)
		_crumbs.emitting = moving and _over_concrete
		_scrape_t -= delta
		if moving and _over_concrete and _scrape_t <= 0.0:
			_scrape_t = 0.28
			game.sfx.hit("scrape")
			game.haptic(p, "18")
		_gold_t = maxf(0.0, _gold_t - delta)
		p.cue("action", "keep pulling" if _gold_t > 0.0 else "screed", 1.0, false)
		# Gold: the board's finishing concrete as it goes
		p.gold(_gold_t > 0.0 and not p.bot)
		p.say("")
		return true
	_crumbs.emitting = false
	# Is there something worth screeding just ahead?
	var ahead: Vector3 = p.global_position + fwd * 1.4 - pour.position
	if pour.height_at(ahead) > pour.SLAB * 0.8:
		p.cue("action", "screed", _down if hold else -1.0, true)
		# Gold: vibrated, unscreeded concrete right where the board would land
		var land: Vector3 = p.global_position + fwd * REACH - pour.position
		p.gold(not p.bot and pour.unscreeded_at(land))
	if not p.bot and pour.float_ready_n > 20:
		p.cue("alt", "bull float", -1.0, false)
		p.gold(true)
	return hold

## Floating: the blade rides out on the slab, the pole back to the hands.
## Hold A and it works the concrete under the blade.
func _float(p, delta: float, hold: bool) -> bool:
	board.visible = false
	_crumbs.emitting = false
	var fwd := Vector3(sin(p.model.rotation.y), 0, cos(p.model.rotation.y))
	var right := fwd.cross(Vector3.UP)
	# Pushed out and drawn back while it works
	_float_slide = _float_slide + delta * 3.0 if hold else 0.0
	var reach: float = FLOAT_REACH + (0.5 * sin(_float_slide) if hold else 0.0)
	var head: Vector3 = p.global_position + fwd * reach
	var local: Vector3 = head - pour.position
	local.y = 0.0
	var surf: float = maxf(pour.height_at(local), 0.0)
	float_node.visible = true
	float_node.global_position = Vector3(head.x, pour.global_position.y + surf + 0.01, head.z)
	float_node.global_rotation = Vector3(0, atan2(fwd.x, fwd.z), 0)
	if _float_pole:
		# The pole climbs from the bracket to the hands
		var rise: float = p.global_position.y + 1.0 - float_node.global_position.y
		_float_pole.rotation.x = asin(clampf(rise / 4.8, -0.9, 0.9))
	p.pose_arms(Vector3(-1.2, 0, -0.25), Vector3(-1.0, 0, 0.25))
	var on_slab: bool = pour.height_at(local) > pour.SLAB * 0.6
	_float_told = maxf(0.0, _float_told - delta)
	if hold and on_slab:
		var r: Vector3i = pour.float_line(local - right * FLOAT_W * 0.5, local + right * FLOAT_W * 0.5)
		if r.x > 0:
			game.score.trickle(p, float(r.x) * 0.35, "Bull floating")
			_gold_t = 0.35
		if r.y > 2 and _float_told <= 0.0:
			_float_told = 4.0
			game.pop("Still shiny: dragged the water up", head + Vector3(0, 1.2, 0), Color("6fa8dc"))
			game.score.award(p, -3, "Floated too early")
		elif r.z > 2 and _float_told <= 0.0:
			_float_told = 4.0
			game.hud.toast("Gone too far: it won't close up now", 1.6)
		if fmod(_float_slide, 1.1) < delta * 3.0:
			game.sfx.hit("scrape")
	_gold_t = maxf(0.0, _gold_t - delta)
	p.cue("action", "float" if not hold else "keep floating", -1.0, on_slab and pour.float_ready_n > 0)
	p.gold(not p.bot and _gold_t > 0.0)
	p.cue("alt", "back to the board")
	return hold

func _put_float_away() -> void:
	floating = false
	if float_node:
		float_node.visible = false
	if board:
		board.visible = true

## Any input from the screeder stops the staff tricks.
func _input_check(p) -> void:
	var busy: bool = p.move_input().length() > 0.1 or p.action_held() or p.alt_held() or p.slow_held() or p._held("leave")
	if busy:
		_idle_t = 0.0
		if _spin_t >= 0.0:
			_spin_t = -1.0
	_input_seen = true

## The board's speed penalty while it's being dragged.
func speed_k(p) -> float:
	if p.tool != "screed":
		return 1.0
	if p.bot:
		return SPEED_K if _working else 1.0
	return PERSON_K if _working else CARRY_K

func update(delta: float) -> void:
	# The screeder always has the board, whoever's playing them
	var sc = game.crew.crew.get("screed") if game.crew else null
	if sc != null and holder != sc:
		pick_up(sc)
	if holder == null or not is_instance_valid(holder):
		roll.visible = false
		_crumbs.emitting = false
		return
	var p = holder
	if p.bot and floating:
		_put_float_away()
	# Matt concrete waiting for the float glints gold for a person new to it
	pour.set_float_view(0.0 if p.bot or game.phase != "pour" else clampf(game.gold_level(p), 0.0, 1.0) * (1.0 if game.gold_level(p) > 0.06 else 0.0))
	if not _input_seen:
		_input_check(p)   # (handle_player wasn't called this frame)
	_input_seen = false
	if not _working:
		roll.visible = false
		_crumbs.emitting = false
	var want_down: bool = _working or _want_down
	_want_down = false
	_down = move_toward(_down, 1.0 if want_down else 0.0, delta / 0.22)
	# Idle long enough with nothing to do: staff tricks
	if not want_down and not floating and _down <= 0.0 and p.busy == "" and p.zone in ["deck", "ground"]:
		_idle_t += delta
		if _idle_t > 3.5 and _spin_t < 0.0:
			_spin_t = 0.0
	else:
		_idle_t = 0.0
		_spin_t = -1.0
	_pose(p, delta)

## Upright at the side like a staff, eased down into the screeding position,
## or spun round like a bow staff while they wait.
func _pose(p, delta: float) -> void:
	if floating:
		return   # (the float's pole is in both hands: _float poses them)
	if _spin_t >= 0.0:
		_spin_t += delta
		var phase := fmod(_spin_t, 4.0)
		var q: Quaternion
		if phase < 2.2:
			# Round the body, flat
			q = Quaternion(Vector3.UP, _spin_t * 9.0) * Quaternion(Vector3.FORWARD, 0.15 * sin(_spin_t * 5.0))
			board.position = Vector3(0, 1.15, 0.0)
		else:
			# A windmill in front, both hands on it
			q = Quaternion(Vector3(0, 0, 1), _spin_t * 10.0)
			board.position = Vector3(0, 1.2, 0.42)
		board.quaternion = q
		var k := sin(_spin_t * 9.0)
		p.pose_arms(Vector3(-1.5 + 0.3 * k, 0, -0.35), Vector3(-1.5 - 0.3 * k, 0, 0.35))
		return
	var e := ease(clampf(_down, 0.0, 1.0), -2.0)
	var saw := sin(_saw) * 0.14 if _working else 0.0
	var up_pos := Vector3(-0.42, 1.42, 0.16)
	var up_rot := Quaternion(Vector3(0, 0, 1), PI * 0.5)
	# Down, the board rides on the concrete: its bottom edge on the finished
	# level (or on the deck where there's none yet), tipped a little so the
	# leading edge is up and the back edge cuts, the way it's held on site
	var c: Vector3 = _board_center(p) - pour.position
	var surf: float = maxf(pour.height_at(c), pour.SLAB if _over_concrete else 0.0)
	var dn_y: float = pour.global_position.y + surf + BOTTOM - p.global_position.y
	var dn_pos := Vector3(saw, dn_y, REACH)
	board.position = up_pos.lerp(dn_pos, e)
	board.quaternion = up_rot.slerp(Quaternion(Vector3.RIGHT, TILT), e)
	var arm_up_r := Vector3(-0.25, 0, -0.15)
	var arm_up_l := Vector3(0.05, 0, 0.1)
	var sw := sin(_saw) if _working else 0.0
	var arm_dn_r := Vector3(-0.75 - 0.15 * sw, 0, -0.25)
	var arm_dn_l := Vector3(-0.75 + 0.15 * sw, 0, 0.25)
	p.pose_arms(arm_up_r.lerp(arm_dn_r, e), arm_up_l.lerp(arm_dn_l, e))

func clear() -> void:
	_dump()
	carry = 0.0
	_working = false
	roll.visible = false
	_put_float_away()

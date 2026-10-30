## The truck hand's wash-down: once the trucks have gone and the washout's on,
## they hose the hopper clean, stripe by stripe. Grey slurry streaks down the
## hopper; hold A facing it and the hose gun knocks the nearest streak off.
## No fail state: a clean hopper is a note on the truck hand's report card.
## On climb days there's no washout, but the truck hand gets a gap once the
## section's slung and the pins are up: the hopper's grimy from the pumping
## line being blown through, so they hose it down then.
## (A person on the truck hand does it; bots leave it for the yard.)
extends Node3D

const F := preload("res://scripts/factory.gd")
const SprayFx := preload("res://scripts/spray_fx.gd")
const STRIPES := 6
const CLEAN_T := 1.3        # s of spray to knock one streak off
const REACH := 3.6          # m from the hopper the jet reaches
const PAY := 4

var game
var line
var _stripes: Array[MeshInstance3D] = []
var _dirt: Array[float] = []       # 1 grimy .. 0 clean, per stripe
var gun: Node3D
var spray: Node3D
var _holder = null
var _hiss_t := 0.0
var clean := false                 # every streak off this pour
var climb_dirty := false           # streaks to hose off in a climb day's gap

func setup(owner_line) -> void:
	line = owner_line
	game = line.game
	# Streaks of slurry down the hopper's sides
	var mat := F.color_mat(Color("5d6064"))
	for k in STRIPES:
		var side := -1.0 if k < STRIPES / 2 else 1.0
		var i := k % (STRIPES / 2)
		var s := F.box(Vector3(0.22, 0.6, 0.03), mat, line.HOPPER + Vector3(-0.5 + 0.5 * i, 0.55, side * 0.9))
		add_child(s)
		_stripes.append(s)
		_dirt.append(1.0)
	gun = F.prop("HoseGun")
	gun.visible = false
	add_child(gun)
	spray = SprayFx.new()
	spray.position = Vector3(0, 0.07, -0.3)
	gun.add_child(spray)
	reset()

## A fresh pour: the hopper's grimy again (and the streaks hide till washout).
func reset() -> void:
	clean = false
	for k in STRIPES:
		_dirt[k] = 1.0
		_stripes[k].scale = Vector3.ONE
		_stripes[k].visible = false
	_put_away()

## A climb day: the hopper's grimy again, for the truck hand's gap.
func begin_climb() -> void:
	reset()
	climb_dirty = true

func wanted() -> bool:
	if game.phase == "pour" and game.ops.stage in game.ops.WASH_ORDER and not clean:
		return true
	return climb_dirty and in_climb_gap()

## The truck hand's climb-day jobs are done: the section's slung and the pins
## are up (or on their way), so there's nothing for them till it lands.
func in_climb_gap() -> bool:
	var c = game.climb
	return c != null and c.active and not c.needs_sling() and not c.needs_pins()

## The truck hand during the washout. True while they're on the hose.
func handle(p, delta: float) -> bool:
	if not wanted() or p.bot or p.covering or p.zone != "ground" or p.held != null:
		if _holder == p:
			_put_away()
		return false
	for s in _stripes:
		s.visible = true
	var hop: Vector3 = line.global_position + line.HOPPER
	var to := Vector3(hop.x - p.global_position.x, 0, hop.z - p.global_position.z)
	if to.length() > REACH:
		if _holder == p:
			_put_away()
		return false
	var k := _nearest(p.global_position)
	if k < 0:
		return false
	p.cue("action", "hose the hopper down", 1.0 - _left(), false)
	p.gold(true)
	if not p.action_held():
		if _holder == p:
			_put_away()
		return false
	_holder = p
	p.face(Vector3(hop.x, p.global_position.y, hop.z))
	# The gun in the right hand, the jet on the streak
	if gun.get_parent() != p.hand_r:
		gun.get_parent().remove_child(gun)
		p.hand_r.add_child(gun)
	gun.visible = true
	gun.position = Vector3.ZERO
	gun.look_at(_stripes[k].global_position, Vector3.UP)
	spray.set("on", true)
	spray.set("pressure", 0.8)
	spray.set("floor_y", line.global_position.y)
	p.pose_arms(Vector3(-1.4, 0, -0.3), Vector3(-1.5, 0, 0.2))
	_dirt[k] = maxf(0.0, _dirt[k] - delta / CLEAN_T)
	_stripes[k].scale = Vector3(1.0, maxf(0.02, _dirt[k]), 1.0)
	if _dirt[k] <= 0.0:
		_stripes[k].visible = false
		game.score.award(p, PAY, "Hopper hosed down")
		game.sfx.hit("tink")
	_hiss_t -= delta
	if _hiss_t <= 0.0:
		_hiss_t = 0.45
		game.sfx.hit("hiss")
	if _left() <= 0.0:
		clean = true
		climb_dirty = false
		game.pop("Hopper's clean", hop + Vector3(0, 2.6, 0), Color("7cd992"))
		_put_away()
	return true

func _left() -> float:
	var t := 0.0
	for d in _dirt:
		t += d
	return t / STRIPES

func _nearest(from: Vector3) -> int:
	var best := -1
	var bd := INF
	for k in STRIPES:
		if _dirt[k] <= 0.0:
			continue
		var d := from.distance_to(_stripes[k].global_position)
		if d < bd:
			bd = d
			best = k
	return best

func _put_away() -> void:
	_holder = null
	if spray:
		spray.set("on", false)
	if gun:
		gun.visible = false
		if gun.get_parent() != self:
			gun.get_parent().remove_child(gun)
			add_child(gun)

func update(_delta: float) -> void:
	# The streaks show once the washout's on, till they're hosed off
	var on: bool = (game.phase == "pour" and game.ops.stage in game.ops.WASH_ORDER) or (climb_dirty and game.climb != null and game.climb.active)
	for k in STRIPES:
		_stripes[k].visible = on and _dirt[k] > 0.0
	if not wanted() and _holder != null:
		_put_away()

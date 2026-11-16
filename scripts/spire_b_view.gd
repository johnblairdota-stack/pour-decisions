## Pour B as its crew sees it. The other crew on Spire run the very same crew bots as ours (bots.gd)
## and the very same poker and screed board (poker.gd, screed.gd): those scripts only ever ask
## "the game" for the slab, the boom, the line and the like, so this answers them for pour B. Their
## own pump runs off to one side, out of sight, so the line here is never in trouble; everything
## else (where the boom aims, when the hose hand calls the pump, which purple gets poked, which
## strip gets screeded) is decided the same way as on our slab.
extends Node3D

const SpireSite := preload("res://scripts/spire_site.gd")

const HOSE_REACH := 2.0
const BOOM_WIND := 72.0
const COVERAGE_DONE := 0.985

var main            # the real game
var b               # spire_b.gd
var pour
var phase := "pour"
var phase_t := 0.0
var cam_yaw := 0.0
var work_y := 0.0
var kit := "tower"
var k := 0
var spire := false  # (poker.gd's own Spire placement is pour A's: ours is set in spire_b.gd)
var autotest := false
var defect_fixed := true
var defect: Node3D
var let_burst := false
var tip_target := Vector3.ZERO
var rig: Node3D
var screed
var poker
var hose_holder = null
var call_t := 0.0
var call_marker: Node3D
var players: Array = []
var urgent := {}
var stations := {}
var SC := Vector3.ZERO
var BW := 10.0
var BD := 10.0
var climb := Climb.new()
var score := Score.new()
var crew := Crew.new()
var line := Line.new()
var ops := Ops.new()
var sfx := Sfx.new()
var hud := Hud.new()

class Smoko:
	func speed_k() -> float:
		return 1.0
	func bot_step(_p, _bots) -> bool:
		return false

class Climb:
	var active := false
	var wind_gust := 0.0
	var dog_bot = null
	var smoko := Smoko.new()

class Score:
	var bot_tier := 0
	func award(_who, _pts, _why) -> void:
		pass
	func trickle(_who, _pts, _why) -> void:
		pass

class Crew:
	var crew := {}
	func is_bot(_role: String) -> bool:
		return true

## Their line: fed off their own pump, out of sight. Never short, never in trouble.
class Line:
	var hopper := 5.0
	var trucks: Array = []
	var spike_on := false
	var blocked := false
	var tripped := false
	var fail_i := -1
	var wear := 0.0
	var riser_top := 0.0
	var pumping := false
	func hud_info() -> Dictionary:
		return {"bay": "discharging"}
	func line_down() -> bool:
		return false

class Ops:
	var primed := true
	func busy() -> bool:
		return false
	func wants_bin() -> bool:
		return false
	func role() -> String:
		return ""
	func radio(_p) -> bool:
		return false
	func bin_world() -> Vector3:
		return Vector3.ZERO
	func over_bin(_at) -> bool:
		return false

## (across the deck from ours: their tools are left out of the mix)
class Sfx:
	var rumble := 0.0
	var rumble_pitch := 0.0
	func hit(_name: String, _vol := 1.0) -> void:
		pass
	func set_loop(_name: String, _v: float) -> void:
		pass
	func has_loop(_name: String) -> bool:
		return false

class Hud:
	func toast(_t: String, _s := 1.0) -> void:
		pass

func _init() -> void:
	name = "PourBView"
	rig = Node3D.new()
	rig.name = "RigB"
	add_child(rig)
	call_marker = Node3D.new()
	call_marker.visible = false
	add_child(call_marker)
	defect = Node3D.new()
	add_child(defect)

# ------------------------------------------------------------------ what the bots ask

func _pour_local(world: Vector3) -> Vector3:
	return world - pour.position

func _filled_ratio() -> float:
	return clampf(pour.coverage() / COVERAGE_DONE, 0.0, 1.0)

func discharge() -> Vector3:
	return b.discharge()

func hose_anchor() -> Vector3:
	return Vector3(b.tip_pos.x, work_y, b.tip_pos.z)

func _boom_operator():
	for p in players:
		if p.busy == "boom":
			return p
	return null

func deck_pos(key: String) -> Vector3:
	return b.spot(key)

func deck_open() -> bool:
	return false

## Pour B and a step round it, never the jump form; the boom operator keeps to his spot by the core.
func _walkable(q: Vector3, zone: String, who = null) -> bool:
	if zone != "deck":
		return false
	if who != null and who.role == "boom":
		return Vector2(q.x - b.boom_spot.x, q.z - b.boom_spot.z).length() < 1.4
	return b.walkable(q)

func walk_bounds(_zone: String) -> Rect2:
	return Rect2(SC.x - BW * 0.5 - 1.0, SC.z - BD * 0.5 - 1.0, BW + 2.0, BD + 2.0)

func gold_level(_p) -> float:
	return 0.0

func haptic(_p, _pattern: String) -> void:
	pass

func pop(_text: String, _at: Vector3, _c := Color.WHITE) -> void:
	pass

func call_boom(_at: Vector3) -> void:
	pass

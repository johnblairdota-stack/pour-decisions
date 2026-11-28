## The crane op's signals on Spire's column climb (John, 28 Nov: words on a
## small button weren't enough). While a person's in the cab:
##  - a big gold arrow rides on the hook, pointing the way the dogger's
##    calling it, with the call written hard against it (HOIST UP, SLEW LEFT, TROLLEY
##    OUT: left and right are the crane op's own, John's dogging rule);
##  - ALL STOP is a red sign, no arrow;
##  - a green ring marks where the hook's got to end up.
## The same call goes to the op's phone as an arrow the way to push the stick
## (phones.gd reads phone()).
##
## It reads the call off mast_climb.gd and draws; it never moves the crane.
extends Node3D

const F := preload("res://scripts/factory.gd")

const GOLD := Color("ffc72c")
const RED := Color("ff5a4a")
const GREEN := Color("7cd992")
const SIZE := 2.6            # m, the arrow's length
## call -> [the phone's arrow, what to do there]
const PHONE := {
	"HOIST UP": ["⬆", "Hold X"], "UP SLOW": ["⬆", "Hold X, gently"],
	"LOWER, EASY": ["⬇", "Hold A"], "DOWN SLOW": ["⬇", "Hold A, gently"],
	"SLEW LEFT": ["⬅", "Stick left"], "SLEW RIGHT": ["➡", "Stick right"],
	"TROLLEY OUT": ["⬆", "Stick up"], "TROLLEY IN": ["⬇", "Stick down"],
	"ALL STOP": ["✋", "Let go"],
}

var mast
var _arrow: Node3D
var _mat: StandardMaterial3D
var _text: Label3D
var _ring: MeshInstance3D
var _ring_text: Label3D

func setup(m) -> void:
	mast = m
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = GOLD
	_mat.no_depth_test = true
	_mat.render_priority = 8
	_arrow = Node3D.new()
	var shaft := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.34, 0.34) * SIZE
	shaft.mesh = bm
	shaft.position.x = 0.35 * SIZE
	shaft.material_override = _mat
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow.add_child(shaft)
	var head := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.34 * SIZE
	cm.height = 0.45 * SIZE
	cm.radial_segments = 4
	head.mesh = cm
	head.rotation.z = -PI * 0.5
	head.position.x = 0.92 * SIZE
	head.material_override = _mat
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow.add_child(head)
	_arrow.visible = false
	add_child(_arrow)
	# (the call, written in the arrow: dark on the gold, big enough for the TV)
	_text = F.label3d("", 88, GOLD)
	_text.outline_size = 22
	_text.render_priority = 9
	_text.visible = false
	add_child(_text)
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.0
	tm.outer_radius = 1.25
	_ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = GREEN
	rm.no_depth_test = true
	_ring.material_override = rm
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)
	_ring_text = F.label3d("HOOK TO HERE", 54, GREEN)
	_ring_text.visible = false
	add_child(_ring_text)

## The call the op's on now ("" when there's none, or nobody's in the cab).
func call_now() -> String:
	if mast == null or mast.cab == null or not mast.active:
		return ""
	if mast.step == "lift":
		match String(mast.hoist):
			"up": return "HOIST UP"
			"stopping": return "ALL STOP"
			"creep_up": return "UP SLOW"
			"creep_down": return "DOWN SLOW"
		return ""
	if mast.step in mast.CRANE_STEPS and mast._radio_ok:
		return String(mast._cab_call)
	return ""

## The way that call moves the hook, in the world (ZERO for a stop).
func dir_of(call: String) -> Vector3:
	match call:
		"HOIST UP", "UP SLOW": return Vector3.UP
		"LOWER, EASY", "DOWN SLOW": return Vector3.DOWN
	var crane = mast.game.climb.crane
	var base: Vector3 = crane.global_position if crane != null else Vector3.ZERO
	var out := Vector3(mast.hook_pos.x - base.x, 0, mast.hook_pos.z - base.z)
	if out.length() < 0.01:
		return Vector3.ZERO
	out = out.normalized()
	match call:
		"TROLLEY OUT": return out
		"TROLLEY IN": return -out
		# (left as the op sees it, facing out along the jib: anticlockwise from above)
		"SLEW LEFT": return Vector3(out.z, 0, -out.x)
		"SLEW RIGHT": return Vector3(-out.z, 0, out.x)
	return Vector3.ZERO

## For the op's phone: {call, arrow, how}, or {} when there's no call.
func phone() -> Dictionary:
	var c := call_now()
	if c == "":
		return {}
	var p: Array = PHONE.get(c, ["", ""])
	return {"call": c, "arrow": p[0], "how": p[1]}

func update(t: float) -> void:
	var c := call_now()
	var at: Vector3 = mast.hook_pos + Vector3(0, 3.4, 0)
	var d := dir_of(c) if c != "" else Vector3.ZERO
	_arrow.visible = d != Vector3.ZERO
	_text.visible = c != ""
	if _arrow.visible:
		var bob := d * (0.25 * sin(t * 5.0))
		_arrow.position = at - d * (SIZE * 0.5) + bob
		if absf(d.y) > 0.5:
			_arrow.rotation = Vector3(0, 0, PI * 0.5 * signf(d.y))
		else:
			_arrow.rotation = Vector3(0, atan2(-d.z, d.x), 0)
		# (the call sits hard against the arrow: beside an up or down one, over a sideways one)
		var cam := get_viewport().get_camera_3d()
		var right: Vector3 = cam.global_transform.basis.x if cam != null else Vector3.RIGHT
		_text.position = at + (right * 2.6 if absf(d.y) > 0.5 else Vector3(0, 1.3, 0))
		_text.modulate = GOLD
	elif c != "":
		# (a stop: a red sign, no arrow)
		_text.position = at
		_text.modulate = RED
	if _text.visible and _text.text != c:
		_text.text = c
	# Where the hook's got to end up on this lift
	var to := Vector3.INF
	if mast.cab != null and mast.step in mast.CRANE_STEPS:
		for w in mast._way:
			if w is Vector3:
				to = w
	_ring.visible = to != Vector3.INF and to.distance_to(mast.hook_pos) > 0.3
	_ring_text.visible = _ring.visible
	if _ring.visible:
		_ring.position = to
		_ring_text.position = to + Vector3(0, 0.9, 0)

## The wallet shop's turning ute, for one phone: the person's real 3D ute
## (utes.gd) with the kit they own (ute_kit.gd) on a turntable, in its own
## little world, drawn off-screen and sent to the phone as JPEG frames
## (phones.gd). The piece of kit they've picked in the shop shows on it as a
## gold see-through preview until they buy it; buying it drops the real part
## in with a flash and a burst of sparks.
extends Node

const Utes := preload("res://scripts/utes.gd")
const SIZE := Vector2i(480, 300)
## Frames a second sent to the phone
const FPS := 9.0
const TURN := 0.55            # rad/s round the turntable
const GOLD := Color("ffd23f")
const BG := Color("1b1e26")   # (the phone wallet's own panel colour)

var vp: SubViewport
var _turn: Node3D
var _car: Node3D
var _cam: Camera3D
var _sparks: CPUParticles3D
var _flash: OmniLight3D
var _key := ""
var _ghosts: Array = []       # the preview's see-through parts
var _ghost_mat: StandardMaterial3D
var _t := 0.0
var _send_t := 0.0
var _pop: Array = []          # {node, t}: just-installed parts settling in
var _lift_ghost := false
var _ride := 0.0

func _ready() -> void:
	vp = SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_energy = 0.55
	rim.light_color = Color(0.75, 0.85, 1.0)
	vp.add_child(rim)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_cam.position = Vector3(0, 2.6, 8.6)
	vp.add_child(_cam)
	_cam.look_at(Vector3(0, 0.85, 0))
	# the turntable: a dark disc with a gold rim
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 3.3
	cm.bottom_radius = 3.4
	cm.height = 0.08
	cm.radial_segments = 64
	disc.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color("2a2e38")
	dm.roughness = 0.8
	disc.material_override = dm
	disc.position.y = -0.04
	vp.add_child(disc)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 3.32
	tm.outer_radius = 3.42
	tm.rings = 64
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = GOLD
	rm.emission_enabled = true
	rm.emission = GOLD
	rm.emission_energy_multiplier = 0.6
	ring.material_override = rm
	vp.add_child(ring)
	_turn = Node3D.new()
	vp.add_child(_turn)
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = Color(GOLD, 0.5)
	_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.amount = 90
	_sparks.lifetime = 0.9
	_sparks.explosiveness = 0.95
	_sparks.direction = Vector3.UP
	_sparks.spread = 75.0
	_sparks.initial_velocity_min = 3.0
	_sparks.initial_velocity_max = 6.5
	_sparks.gravity = Vector3(0, -9.0, 0)
	_sparks.scale_amount_min = 0.6
	_sparks.scale_amount_max = 1.2
	var sq := QuadMesh.new()
	sq.size = Vector2(0.09, 0.09)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_color = Color(1.0, 0.86, 0.35)
	sm.vertex_color_use_as_albedo = true
	sq.material = sm
	_sparks.mesh = sq
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 0.85, 1))
	grad.set_color(1, Color(1, 0.6, 0.1, 0))
	_sparks.color_ramp = grad
	vp.add_child(_sparks)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.9, 0.6)
	_flash.omni_range = 7.0
	_flash.light_energy = 0.0
	_flash.position = Vector3(0, 2.2, 1.5)
	vp.add_child(_flash)

## Shows this ute ("hilux", "ranger" or "shark") with the kit they own, and
## `preview` (a kit id, or "") as the gold see-through part.
func show_ute(ute: String, kit: Array, preview := "") -> void:
	var key := "%s|%s|%s" % [ute, ",".join(kit), preview]
	if key == _key:
		return
	_key = key
	if _car != null:
		_car.queue_free()
		_car = null
	_ghosts.clear()
	_pop.clear()
	_lift_ghost = false
	var nm := ute.capitalize()
	if not Utes.has(nm):
		return
	_car = Utes.drivable(nm, Utes.OWN_PAINT[nm])
	_turn.add_child(_car)
	Utes.apply_kit(_car, ute, kit)
	_ride = float(_car.get_meta("ride", 0.0))
	if preview != "" and not kit.has(preview):
		_add_ghost(ute, kit, preview)
	_place_body(0.0)

func _add_ghost(ute: String, kit: Array, item: String) -> void:
	if not ResourceLoader.exists("res://scripts/ute_kit.gd"):
		return
	var K: Script = load("res://scripts/ute_kit.gd")
	if item == "lift":
		_lift_ghost = true
		return
	if item == "mudtyres":
		# (the new tyres over the stock ones, see-through)
		for w in ["FL", "FR", "RL", "RR"]:
			var spin := _car.get_node(w).get_node("Spin") as Node3D
			var tyre = K.part("mudtyres", ute)
			if tyre == null:
				return
			tyre.position.y = K.MUD_UP
			if (_car.get_node(w) as Node3D).position.x < 0.0:
				tyre.rotation.y = PI
			tyre.material_override = _ghost_mat
			spin.add_child(tyre)
			_ghosts.append(tyre)
		return
	for part in K.fit(item, ute, kit + [item]):
		for mi in [part] + part.find_children("*", "MeshInstance3D", true, false):
			if mi is MeshInstance3D:
				(mi as MeshInstance3D).material_override = _ghost_mat
		_car.get_node("Body").add_child(part)
		_ghosts.append(part)

## Just bought `item`: it's fitted for real, drops in with a bounce, a flash
## and a shower of sparks.
func installed(ute: String, kit: Array, item: String) -> void:
	_key = ""
	show_ute(ute, kit, "")
	if _car == null:
		return
	var body := _car.get_node("Body") as Node3D
	var found: Array = []
	if item == "mudtyres":
		for w in ["FL", "FR", "RL", "RR"]:
			found.append(_car.get_node(w).get_node("Spin"))
	elif item == "lift":
		found.append(body)
	else:
		var got := body.get_node_or_null(item)
		if got != null:
			found.append(got)
		elif body.get_child_count() > 1:
			found.append(body.get_child(body.get_child_count() - 1))
	var at := Vector3(0, 1.4, 0)
	for f in found:
		_pop.append({"node": f, "t": 0.0, "base": (f as Node3D).scale})
		at = (f as Node3D).global_position if f != body else at
	_sparks.position = at
	_sparks.restart()
	_sparks.emitting = true
	_flash.light_energy = 6.0

func _place_body(lift_bob: float) -> void:
	if _car == null:
		return
	var body := _car.get_node("Body") as Node3D
	body.position.y = _ride + 0.02 + lift_bob

func _process(delta: float) -> void:
	_t += delta
	_turn.rotation.y = fmod(_t * TURN, TAU) - 0.6
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	_ghost_mat.albedo_color.a = 0.3 + 0.35 * pulse
	_place_body((Utes.LIFT * pulse) if _lift_ghost else 0.0)
	for e in _pop.duplicate():
		e["t"] += delta
		var k: float = e["t"] / 0.55
		var n: Node3D = e["node"]
		if k >= 1.0 or not is_instance_valid(n):
			if is_instance_valid(n):
				n.scale = e["base"]
			_pop.erase(e)
			continue
		# (overshoots, then settles)
		var s := 1.0 + 0.35 * sin(k * PI * 2.5) * (1.0 - k)
		n.scale = (e["base"] as Vector3) * s
	_flash.light_energy = maxf(0.0, _flash.light_energy - delta * 12.0)

## A frame for the phone when one's due (empty when not, or when the game's
## not drawing, as in the headless tests).
func frame(delta: float) -> PackedByteArray:
	_send_t -= delta
	if _send_t > 0.0 or DisplayServer.get_name() == "headless":
		return PackedByteArray()
	_send_t = 1.0 / FPS
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		return PackedByteArray()
	return img.save_jpg_to_buffer(0.72)

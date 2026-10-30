## "Hands needed" signs: a small orange marker with a hand on it, floating over
## any job that needs a worker right now (a poker nobody's holding, a truck
## waiting for its slump test, a clamp weeping up the riser). When it gets
## urgent it turns red, shakes and throws sparks, and the bots run for it.
## Each sign carries the icon of the job it's for, in that job's colour, and a
## sign for a person's job that's off screen (or behind the street band) gets
## an arrow on the edge of the screen pointing to it.
extends Node3D

const Icons := preload("res://scripts/icons.gd")
const UI := preload("res://scripts/ui.gd")
const Settings := preload("res://scripts/settings.gd")

class Arrow extends Control:
	var col := Color.WHITE
	var ang := 0.0
	var tex: Texture2D
	var level := 0
	var t := 0.0
	func _draw() -> void:
		var dir := Vector2.from_angle(ang)
		var side := dir.orthogonal() * 15.0
		var pulse := 1.0 + (0.12 * sin(t * 10.0) if level >= 1 else 0.0)
		var ring := Color("ff3b30") if level >= 1 and fmod(t, 0.5) < 0.25 else col
		draw_colored_polygon(PackedVector2Array([dir * 46.0 * pulse, dir * 22.0 + side, dir * 22.0 - side]), ring)
		draw_circle(Vector2.ZERO, 28.0 * pulse, Color(0.05, 0.08, 0.14, 0.92))
		draw_arc(Vector2.ZERO, 28.0 * pulse, 0.0, TAU, 40, ring, 3.5, true)
		if tex:
			draw_texture_rect(tex, Rect2(Vector2(-20, -20) * pulse, Vector2(40, 40) * pulse), false, col)

var game
var _pin_tex: ImageTexture
var _hand_tex: ImageTexture
var _signs := {}              # key -> {root, pin, hand, icon, sparks, t, level, seen}
var _arrow_layer: CanvasLayer
var _arrows := {}             # key -> Arrow

const NAMES := {"poker": "VIBRATE", "raw": "VIBRATE HERE", "boom": "PUMP", "screed": "SCREED",
	"bay": "TRUCK", "panel": "PUMP PANEL", "joint": "CLAMP", "block": "BLOCKAGE", "spares": "CLAMP KIT",
	"rack": "PIPE", "hook": "TAKE IT", "defect": "BAR CHAIR", "dogman": "DOGMAN", "tag": "TAG LINE", "tag2": "TAG LINE",
	"rigger": "RIGGER", "rig0": "OUTRIGGER", "rig1": "OUTRIGGER", "rig2": "OUTRIGGER", "rig3": "OUTRIGGER"}
const ORANGE := Color("ff8a1f")
const RED := Color("ff3b30")

func setup(owner_game) -> void:
	game = owner_game
	_pin_tex = ImageTexture.create_from_image(_draw_pin(128))
	_hand_tex = ImageTexture.create_from_image(_draw_hand(128))
	_arrow_layer = CanvasLayer.new()
	_arrow_layer.layer = 3
	add_child(_arrow_layer)

# ------------------------------------------------------------------ textures

static func _cap(p: Vector2, a: Vector2, b: Vector2, r: float) -> float:
	var pa := p - a
	var ba := b - a
	var h := clampf(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	return (pa - ba * h).length() - r

static func _box(p: Vector2, c: Vector2, half: Vector2, r: float) -> float:
	var q := (p - c).abs() - half + Vector2(r, r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r

## A map-pin marker: round head with a point underneath, white (tinted later).
static func _draw_pin(n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var s := n / 128.0
	for y in n:
		for x in n:
			var p := Vector2(x, y) / s
			var disc := Vector2(p.x - 64.0, p.y - 56.0).length() - 46.0
			# The point: a triangle under the disc
			var tri := maxf(absf(p.x - 64.0) * 1.05 + (p.y - 124.0) * 0.55, 70.0 - p.y)
			var d := minf(disc, tri)
			var a := clampf(0.5 - d, 0.0, 1.0)
			var edge := clampf(0.5 - absf(d + 3.0) + 2.5, 0.0, 1.0)
			var c := Color(1, 1, 1, a).lerp(Color(0.35, 0.18, 0.05, a), edge * 0.6)
			img.set_pixel(x, y, c)
	return img

## An open hand (palm, four fingers, thumb), cream with a dark outline.
static func _draw_hand(n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var s := n / 128.0
	for y in n:
		for x in n:
			var p := Vector2(x, y) / s
			var d := _box(p, Vector2(64, 70), Vector2(19, 17), 7.0)
			d = minf(d, _cap(p, Vector2(50, 54), Vector2(48, 30), 5.5))
			d = minf(d, _cap(p, Vector2(60, 52), Vector2(60, 24), 5.5))
			d = minf(d, _cap(p, Vector2(70, 52), Vector2(71, 26), 5.5))
			d = minf(d, _cap(p, Vector2(79, 56), Vector2(82, 36), 5.0))
			d = minf(d, _cap(p, Vector2(48, 74), Vector2(34, 58), 5.5))
			var a := clampf(0.5 - (d - 3.5), 0.0, 1.0)
			var inner := clampf(0.5 - d, 0.0, 1.0)
			var c := Color(0.12, 0.08, 0.05, a).lerp(Color(1.0, 0.97, 0.9, a), inner)
			img.set_pixel(x, y, c)
	return img

# ------------------------------------------------------------------ signs

func _make(key: String) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var pin := Sprite3D.new()
	pin.texture = _pin_tex
	pin.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pin.no_depth_test = true
	pin.render_priority = 26
	pin.shaded = false
	pin.pixel_size = 0.0075
	pin.layers = 2
	root.add_child(pin)
	var hand := Sprite3D.new()
	hand.texture = _hand_tex
	hand.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hand.no_depth_test = true
	hand.render_priority = 27
	hand.shaded = false
	hand.pixel_size = 0.0057
	hand.position = Vector3(0, 0.07, 0.01)
	hand.layers = 2
	root.add_child(hand)
	var icon := Sprite3D.new()
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.no_depth_test = true
	icon.render_priority = 28
	icon.shaded = false
	icon.pixel_size = 0.0056
	icon.position = Vector3(0.66, 0.2, 0.02)
	icon.layers = 2
	root.add_child(icon)
	var sp := CPUParticles3D.new()
	sp.amount = 18
	sp.lifetime = 0.5
	sp.emitting = false
	sp.direction = Vector3(0, 1, 0)
	sp.spread = 180.0
	sp.initial_velocity_min = 1.5
	sp.initial_velocity_max = 3.2
	sp.gravity = Vector3(0, -6, 0)
	sp.scale_amount_min = 0.6
	sp.scale_amount_max = 1.2
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, 0.12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("ffd36b")
	bm.material = m
	sp.mesh = bm
	sp.set_particle_flag(CPUParticles3D.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)
	sp.layers = 2
	root.add_child(sp)
	var cap := Label3D.new()
	cap.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cap.no_depth_test = true
	cap.render_priority = 27
	cap.font_size = 46
	cap.outline_size = 10
	cap.pixel_size = 0.005
	cap.position = Vector3(0, -0.62, 0)
	cap.layers = 2
	cap.text = NAMES.get(key, "")
	root.add_child(cap)
	var e := {"root": root, "pin": pin, "hand": hand, "icon": icon, "sparks": sp, "t": 0.0, "level": 0, "seen": true, "cap": cap, "role": ""}
	_signs[key] = e
	return e

## Shows this frame's jobs. Each entry: {key, pos, level} where level is
## 0 (someone's needed), 1 (urgent: red) or 2 (critical: shakes and sparks).
func show_jobs(list: Array, delta: float) -> void:
	for k in _signs:
		_signs[k]["seen"] = false
	var cam: Camera3D = game.camera
	var t: float = game.phase_t
	var band: bool = game.band_box != null and game.band_box.visible
	for j in list:
		var key: String = j["key"]
		var e: Dictionary = _signs[key] if _signs.has(key) else _make(key)
		e["seen"] = true
		e["level"] = int(j.get("level", 0))
		var root: Node3D = e["root"]
		var pos: Vector3 = j["pos"]
		e["t"] = minf(e["t"] + delta, 10.0)
		var lv: int = e["level"]
		var k_size := clampf(cam.global_position.distance_to(pos) / 15.0, 0.85, 3.0)
		if band and pos.y < game.work_y - 2.0:
			# (a street sign, seen in the band's own camera, far closer to it)
			k_size = clampf(game.band_cam.global_position.distance_to(pos) / 15.0 * game.BAND_CUE_K, 0.5, 3.0)
		var appear := ease(clampf(e["t"] * 4.0, 0.0, 1.0), 0.4)
		var beat := 0.5 + 0.5 * sin(t * (4.0 if lv == 0 else 9.0))
		var sc := k_size * appear * (1.0 + 0.08 * beat + (0.12 * beat if lv >= 1 else 0.0))
		var bob := Vector3(0, 0.12 * sin(t * 2.6 + pos.x), 0)
		var jitter := Vector3.ZERO
		if lv >= 2:
			jitter = Vector3(sin(t * 61.0), sin(t * 53.0 + 1.0) * 0.6, 0) * 0.07 * k_size
		root.visible = true
		root.position = pos + bob + jitter
		root.scale = Vector3.ONE * sc
		var col := ORANGE if lv == 0 else RED.lerp(Color("ff7a1a"), 0.35 * beat)
		(e["pin"] as Sprite3D).modulate = col
		(e["cap"] as Label3D).scale = Vector3.ONE * float(Settings.value("world_text"))
		var cap: Label3D = e["cap"]
		cap.text = j.get("text", NAMES.get(key, ""))
		cap.modulate = Color(1, 0.93, 0.85) if lv == 0 else Color(1, 0.75, 0.72)
		var sp: CPUParticles3D = e["sparks"]
		sp.emitting = lv >= 2
		var role: String = j.get("role", "")
		var icon: Sprite3D = e["icon"]
		icon.visible = role != ""
		if role != "" and e["role"] != role:
			e["role"] = role
			icon.texture = Icons.outlined(role, 96)
			icon.modulate = UI.ROLE.get(role, Color.WHITE)
		_arrow_for(key, j, lv, delta)
	for k in _signs:
		var e: Dictionary = _signs[k]
		if not e["seen"]:
			(e["root"] as Node3D).visible = false
			(e["sparks"] as CPUParticles3D).emitting = false
			e["t"] = 0.0
	for k in _arrows:
		var a: Arrow = _arrows[k]
		if not a.get_meta("seen", false):
			a.visible = false
		a.set_meta("seen", false)

## An arrow on the edge of the screen for a sign that's out of view, for the
## jobs people are doing (and anything critical). Street signs while the screen
## is split are in the street band already.
func _arrow_for(key: String, j: Dictionary, lv: int, delta: float) -> void:
	var role: String = j.get("role", "")
	if role == "" or key.begins_with("raw"):
		return
	var mine := false
	for h in game.humans():
		if h.role == role:
			mine = true
	if not mine and lv < 2:
		return
	var pos: Vector3 = j["pos"]
	if game._split > 0.5 and pos.y < 5.0:
		return
	var cam: Camera3D = game.camera
	var size: Vector2 = get_viewport().get_visible_rect().size
	# (kept inside the HUD's panels: the task bar and the side panels sit
	# along the top)
	var area := Rect2(Vector2(40, 130), Vector2(size.x - 80, size.y - game._band_h - 170))
	var behind := cam.is_position_behind(pos)
	var p2 := cam.unproject_position(pos)
	var centre := area.get_center()
	if behind:
		p2 = centre - (p2 - centre) * 4.0
	elif area.has_point(p2):
		return
	var dir := p2 - centre
	if dir.length() < 1.0:
		return
	# Where the line from the centre leaves the area
	var half := area.size * 0.5
	var k := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	var at := centre + dir * minf(k, 1.0) * 0.96
	var a: Arrow = _arrows.get(key)
	if a == null:
		a = Arrow.new()
		_arrow_layer.add_child(a)
		_arrows[key] = a
	a.visible = true
	a.set_meta("seen", true)
	a.position = at
	a.ang = dir.angle()
	a.col = UI.ROLE.get(role, Color.WHITE)
	a.tex = Icons.texture(role, 64)
	a.level = lv
	a.t += delta
	a.queue_redraw()

func hide_all() -> void:
	show_jobs([], 0.0)

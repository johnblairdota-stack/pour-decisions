## A co-op player: a chibi that walks the working deck, climbs the tower
## ladder, works the pump at ground level, carries parts, and uses stations.
##
## Controls are four face buttons and a stick, like a phone controller:
##   A = use / pick up / hold to work     B = drop / step off / leave
##   X = second action                    Y = special (slowly, emergency)
## What to press is shown as a pulsing button glyph over the player's head,
## with a ring that fills for hold actions.
extends Node3D

const CrewInfo := preload("res://scripts/roster.gd")
const F := preload("res://scripts/factory.gd")
const Icons := preload("res://scripts/icons.gd")
const CUE := preload("res://shaders/cue.gdshader")
const PILL := preload("res://shaders/pill.gdshader")
const UI := preload("res://scripts/ui.gd")
const BALLOON := preload("res://shaders/balloon.gdshader")
const BARK_SIZE := 30
const BARK_WRAP := 330.0    # px of text before a spoken line wraps
const Settings := preload("res://scripts/settings.gd")
const GOLD := Color("ffd23f")

const BTN := {"action": "A", "leave": "B", "alt": "X", "slow": "Y"}
const BTN_COLORS := {"A": Color("3fe0c5"), "B": Color("ff5a5f"), "X": Color("9b6bff"), "Y": Color("ffc23d")}
## The keyboard key behind each button, for people playing on the keys
const KEYS := {"p1_": {"A": "Space", "B": "Q", "X": "E", "Y": "F"}, "p2_": {"A": "Enter", "B": "Shift", "X": "Ctrl", "Y": "Alt"}}

var index := 1
var prefix := "p1_"
var tag_color := Color("4fa3ff")
var speed := 6.0
var busy := ""            # station this player is locked into, "" when free
var zone := "deck"        # "deck", "ladder", "ground" or "hoist"
var tool := ""            # "poker" while carrying the vibrator
var held: Node3D = null   # a part being carried (clamp kit, pipe)
var held_kind := ""
var model: Node3D
var hand_r: Node3D
var hand_l: Node3D
var tag: Label3D
var prompt: Label3D       # short status only (heights, counts); actions use cues
var _walk := 0.0
## How worn out this crew member is, 0 (fresh) to 1 (cooked). Prototype for
## the smoko mechanic: they slouch, the head hangs and lolls, eyes go heavy,
## arms dangle, sweat drips and they walk slower.
var weary := 0.0
var show_bot_cues := false   # dev: draw a bot's cues as if a person were playing it
var _sweat: CPUParticles3D
var _phase := randf() * 6.0
var _bounce := 0.0
var _moving := false
var run_to := Vector3.INF    # a job running this player somewhere on its own (set each frame)

# Virtual input: the test bot and phone controllers drive these instead of
# the keyboard, so every input source goes through the same code paths.
var ai := false
var ai_move := Vector2.ZERO
var ai_action := false
var ai_alt := false
var ai_slow := false
var ai_leave := false
var _ai_prev := {"action": false, "alt": false, "slow": false, "leave": false}
var remote_id := -1       # phone controller connection, -1 if none
var touched := false
var char_id := ""
var char_name := ""      # someone has used the keyboard or pad for this player
var bot := false          # a crew bot is driving the virtual input
var role := ""            # the job this chibi does: boom, line, pump, poker, screed
var hurry := false        # bots run for urgent work
var pace := 1.0           # a bot's stick, scaled by how sharp the bots are working (bronze/silver/gold)
## A person who's gone quiet while their job waits gets covered by a crewmate
## (the job's bot brain drives them) until they touch their controls again
var covering := false
var idle_in := 0.0        # seconds since this person last touched their controls
var ring: MeshInstance3D  # a coloured disc under a person's feet
var bubble: Label3D       # a short spoken line ("Clamp coming up!")
var _bubble_t := 0.0
var _balloons: Array = []   # {node, t, life, base, phase}: speech balloons floating up
var pts_frac := 0.0       # fractional points still to be awarded (continuous work)

# Button cues, rebuilt every frame by whoever handles this player
var cues: Array = []      # [button, verb, progress, urgent]
var _cue_nodes: Array = []

func setup(i: int, color: Color) -> void:
	index = i
	prefix = "p%d_" % i
	tag_color = color
	model = F.chibi(Color("ff7a1a"), color)
	add_child(model)
	hand_r = Node3D.new()
	hand_r.position = Vector3(0, -0.46, 0)
	model.get_node("ArmR").add_child(hand_r)
	hand_l = Node3D.new()
	hand_l.position = Vector3(0, -0.46, 0)
	model.get_node("ArmL").add_child(hand_l)
	tag = F.label3d("P%d" % i, 50, color)
	tag.font = UI.font("head")
	tag.position = Vector3(0, 2.2, 0)
	add_child(tag)
	prompt = F.label3d("", 30, Color.WHITE)
	prompt.position = Vector3(0, 2.0, 0)
	add_child(prompt)
	# Three glyph slots: two from cue(), plus a third a station can add by hand
	# (the truck bay's B: send it back)
	for k in 3:
		var n := Node3D.new()
		var quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.95, 0.95)
		quad.mesh = qm
		var m := ShaderMaterial.new()
		m.shader = CUE
		m.render_priority = 30
		quad.material_override = m
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(quad)
		var letter := F.label3d("A", 64, Color("0f1b2d"))
		letter.font = UI.font("head")
		letter.outline_size = 0
		letter.render_priority = 31
		letter.pixel_size = 0.0085
		n.add_child(letter)
		# The verb tag: a dark pill with the job's dot, the words on it
		var pill := MeshInstance3D.new()
		pill.mesh = QuadMesh.new()
		var pm := ShaderMaterial.new()
		pm.shader = PILL
		pm.render_priority = 30
		pill.material_override = pm
		pill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(pill)
		var verb := F.label3d("", 44, Color.WHITE)
		verb.font = UI.font("head")
		verb.outline_size = 0
		verb.position = Vector3(0.75, 0, 0)
		verb.render_priority = 31
		n.add_child(verb)
		n.visible = false
		add_child(n)
		# (layer 4: the main views show them; the close-ups and the small
		# views of someone off screen leave them out and show the badge)
		for v in [quad, letter, verb, pill]:
			v.layers = 8
		# Gold: 14 star sparks the moment it goes gold, then a trickle
		var sp := _star_sparks(14, 0.55, true)
		var tr := _star_sparks(5, 0.5, false)
		sp.layers = 8
		tr.layers = 8
		n.add_child(sp)
		n.add_child(tr)
		_cue_nodes.append({"node": n, "mat": m, "letter": letter, "verb": verb, "pill": pill, "pmat": pm, "sparks": sp, "trickle": tr, "pressed_at": -9.0, "was_down": false})
	tag.layers = 2
	prompt.layers = 2
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.48
	tm.outer_radius = 0.6
	tm.rings = 28
	tm.ring_segments = 4
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = color
	ring.material_override = rmat
	ring.scale = Vector3(1, 0.15, 1)
	ring.position.y = 0.05
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	bubble = F.label3d("", 34, Color("0f1b2d"))
	bubble.outline_size = 0
	bubble.modulate = Color("0f1b2d")
	bubble.position = Vector3(0, 2.75, 0)
	bubble.layers = 2
	bubble.render_priority = 20
	var bg := MeshInstance3D.new()
	bg.name = "BubbleBg"
	bg.mesh = QuadMesh.new()
	var bgm := ShaderMaterial.new()
	bgm.shader = BALLOON
	bgm.render_priority = 19
	bg.material_override = bgm
	bg.layers = 2
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bg.position = Vector3(0, 0, -0.01)
	bubble.no_depth_test = true
	bubble.add_child(bg)
	bubble.visible = false
	add_child(bubble)
	_sweat = CPUParticles3D.new()
	_sweat.amount = 6
	_sweat.lifetime = 0.7
	_sweat.emitting = false
	_sweat.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	_sweat.emission_sphere_radius = 0.42
	_sweat.direction = Vector3(0, 1, 0)
	_sweat.spread = 50.0
	_sweat.initial_velocity_min = 0.4
	_sweat.initial_velocity_max = 0.8
	_sweat.gravity = Vector3(0, -5, 0)
	var dm := SphereMesh.new()
	dm.radius = 0.035
	dm.height = 0.09
	dm.radial_segments = 6
	dm.rings = 3
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.6, 0.85, 1.0, 0.85)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.material = dmat
	_sweat.mesh = dm
	_sweat.position = Vector3(0, 1.4, 0)
	model.add_child(_sweat)

static var _star_tex: Texture2D

## The Site Kit's gold star sparks (the phone throws the same ones).
func _star_sparks(amount: int, life: float, burst: bool) -> CPUParticles3D:
	var sp := CPUParticles3D.new()
	sp.amount = amount
	sp.lifetime = life
	sp.emitting = false
	sp.one_shot = burst
	sp.explosiveness = 1.0 if burst else 0.0
	sp.local_coords = true
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	sp.emission_sphere_radius = 0.42
	sp.direction = Vector3(0, 1, 0)
	sp.spread = 180.0
	sp.initial_velocity_min = 1.4 if burst else 0.5
	sp.initial_velocity_max = 2.4 if burst else 0.9
	sp.damping_min = 2.0
	sp.damping_max = 3.0
	sp.gravity = Vector3(0, -1.5, 0)
	sp.angle_min = 0.0
	sp.angle_max = 90.0
	sp.angular_velocity_min = -240.0
	sp.angular_velocity_max = 240.0
	sp.scale_amount_min = 0.7
	sp.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	sp.scale_amount_curve = curve
	var qm := QuadMesh.new()
	qm.size = Vector2(0.16, 0.16)
	var spm := StandardMaterial3D.new()
	spm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	spm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spm.albedo_color = UI.GOLD
	if _star_tex == null:
		_star_tex = UI.star_texture(48)
	spm.albedo_texture = _star_tex
	spm.no_depth_test = true
	spm.render_priority = 32
	qm.material = spm
	sp.mesh = qm
	sp.layers = 2
	return sp

# ------------------------------------------------------------------ who's driving

## Who is driving this chibi: a person (keyboard, pad or phone) or a bot.
func driver() -> Dictionary:
	return {"index": index, "prefix": prefix, "color": tag_color, "ai": ai, "bot": bot, "remote_id": remote_id, "touched": touched, "char": char_id}

func set_driver(d: Dictionary) -> void:
	index = d["index"]
	prefix = d["prefix"]
	tag_color = d["color"]
	ai = d["ai"]
	bot = d["bot"]
	remote_id = d["remote_id"]
	touched = d["touched"]
	if d.get("char", "") != "":
		set_char(d["char"])
	ai_move = Vector2.ZERO
	ai_action = false
	ai_alt = false
	ai_slow = false
	ai_leave = false
	_ai_prev = {"action": false, "alt": false, "slow": false, "leave": false}
	hurry = false
	refresh_tag()

func is_human() -> bool:
	return not bot

## Becomes one of the named crew (look and name).
func set_char(id: String) -> void:
	char_id = id
	var info: Dictionary = CrewInfo.char_info(id)
	char_name = info["name"]
	F.dress(model, info)
	refresh_tag()

func refresh_tag() -> void:
	if tag == null:
		return
	_hat_icon()
	if bot:
		tag.text = char_name.to_lower()
		tag.modulate = Color(0.85, 0.9, 0.97, 0.75)
		tag.font_size = 30
		ring.visible = false
	else:
		tag.text = "P%d · %s" % [index, char_name]
		tag.modulate = tag_color
		tag.font_size = 44
		ring.visible = true
		(ring.material_override as StandardMaterial3D).albedo_color = tag_color

## The job's icon on the front of the hard hat, so the job reads even where
## the hat's colour doesn't.
func _hat_icon() -> void:
	if model == null or role == "":
		return
	var head: Node3D = model.get_node_or_null("Head")
	if head == null:
		return
	var s: Sprite3D = head.get_node_or_null("HatIcon")
	if s == null:
		s = Sprite3D.new()
		s.name = "HatIcon"
		# Big on the hat
		# (always turned to the camera, painted over the dome, so it reads
		# whichever way they're facing)
		s.pixel_size = 0.0068
		s.position = Vector3(0, 0.36, 0.0)
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.no_depth_test = true
		s.render_priority = 3
		s.shaded = false
		s.double_sided = false
		head.add_child(s)
	s.texture = Icons.outlined(role, 96)
	s.modulate = Color.WHITE
## Said out loud: a small speech balloon that floats up off their head and
## pops after a moment.
func bark(text: String, seconds := 1.8) -> void:
	var world := get_parent()
	if world == null:
		return
	var b: Label3D = bubble.duplicate()
	b.text = text
	b.font_size = BARK_SIZE
	# The balloon fits the line: one line when it's short, wrapped onto two
	# or three when it's long, never wider than BARK_WRAP
	var font: Font = b.font if b.font else ThemeDB.fallback_font
	var one := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, BARK_SIZE)
	var px := one
	if one.x > BARK_WRAP:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.width = BARK_WRAP
		px = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, BARK_WRAP, BARK_SIZE)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var box := px * b.pixel_size + Vector2(0.36, 0.22)
	var tail := 0.22
	var bg: MeshInstance3D = b.get_node("BubbleBg")
	var qm := QuadMesh.new()
	qm.size = Vector2(box.x, box.y + tail)
	bg.mesh = qm
	bg.position = Vector3(0, -tail * 0.5, -0.01)
	var mat: ShaderMaterial = (bg.material_override as ShaderMaterial).duplicate()
	mat.set_shader_parameter("size", box)
	mat.set_shader_parameter("tail", tail)
	bg.material_override = mat
	b.visible = true
	world.add_child(b)
	b.global_position = global_position + Vector3(0, 2.6, 0)
	_balloons.append({"node": b, "mat": mat, "h": box.y + tail, "t": 0.0, "life": seconds + 0.6 + 0.04 * maxf(0.0, text.length() - 18.0), "base": b.global_position, "phase": randf() * TAU})
	# (older balloons drift up out of the way)
	while _balloons.size() > 3:
		var old: Dictionary = _balloons.pop_front()
		(old["node"] as Node).queue_free()

func _update_balloons(delta: float, cam_pos: Vector3) -> void:
	# Each balloon sits above the newer ones under it, however many lines
	# they run to, so a long line never covers a short one
	var stack := 0.0
	for i in range(_balloons.size() - 1, -1, -1):
		var en: Dictionary = _balloons[i]
		en["stack"] = stack
		stack += float(en.get("h", 0.6)) + 0.08
	for e in _balloons.duplicate():
		var b: Label3D = e["node"]
		if not is_instance_valid(b):
			_balloons.erase(e)
			continue
		e["t"] = float(e["t"]) + delta
		var t: float = e["t"]
		var life: float = e["life"]
		var bk := clampf(b.global_position.distance_to(cam_pos) / 15.0, 0.8, 2.2) if cam_pos != Vector3.ZERO else 1.0
		# Floats up with a little bob, the way a balloon does, following its owner
		var base: Vector3 = global_position + Vector3(0, 2.4 + 0.25 * bk, 0)
		var sway := Vector3(0.12 * sin(t * 2.2 + float(e["phase"])), 0, 0)
		var rise := maxf(minf(0.55 * t, 0.5), float(e.get("stack", 0.0)))
		e["rise"] = lerpf(float(e.get("rise", rise)), rise, minf(1.0, delta * 10.0))
		b.global_position = base + Vector3(0, float(e["rise"]) + float(e.get("h", 0.6)) * 0.5, 0) * bk + sway * bk
		var grow := minf(1.0, t * 7.0)
		var k := bk * (0.5 + 0.5 * grow)
		if t > life - 0.14:
			# Pop!
			var u := (t - (life - 0.14)) / 0.14
			k *= 1.0 + 0.6 * u
			b.modulate.a = 1.0 - u
			(e["mat"] as ShaderMaterial).set_shader_parameter("alpha", 1.0 - u)
			if not e.has("popped"):
				e["popped"] = true
				_pop_burst(b.global_position)
		b.scale = Vector3.ONE * k
		if t >= life:
			b.queue_free()
			_balloons.erase(e)

func _pop_burst(at: Vector3) -> void:
	var world := get_parent()
	if world == null:
		return
	var sp := CPUParticles3D.new()
	sp.one_shot = true
	sp.amount = 10
	sp.lifetime = 0.35
	sp.explosiveness = 1.0
	sp.spread = 180.0
	sp.initial_velocity_min = 1.2
	sp.initial_velocity_max = 2.2
	sp.gravity = Vector3.ZERO
	var m := BoxMesh.new()
	m.size = Vector3(0.05, 0.05, 0.05)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(1, 1, 1)
	mm.no_depth_test = true
	m.material = mm
	sp.mesh = m
	sp.layers = 2
	world.add_child(sp)
	sp.global_position = at
	sp.emitting = true
	get_tree().create_timer(0.6).timeout.connect(sp.queue_free)

# ------------------------------------------------------------------ input

## True while this person is touching their own keys or pad right now.
func raw_active() -> bool:
	if bot:
		return false
	if ai:
		# (a phone that's being covered takes itself back: phones.gd)
		if covering:
			return false
		# A phone: holding a button or the stick counts, even with no new
		# messages coming in
		return ai_action or ai_alt or ai_slow or ai_leave or ai_move.length() > 0.1
	for what in ["action", "alt", "slow", "leave"]:
		if InputMap.has_action(prefix + what) and Input.is_action_pressed(prefix + what):
			return true
	if InputMap.has_action(prefix + "left") and Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down") != Vector2.ZERO:
		return true
	return false

## They're back: hand the controls straight back.
func uncover() -> void:
	covering = false
	idle_in = 0.0
	pace = 1.0
	hurry = false
	ai_move = Vector2.ZERO
	ai_action = false
	ai_alt = false
	ai_slow = false
	ai_leave = false
	_ai_prev = {"action": false, "alt": false, "slow": false, "leave": false}

func move_input() -> Vector2:
	if ai or covering:
		return ai_move.limit_length(1.0)
	var v := Input.get_vector(prefix + "left", prefix + "right", prefix + "up", prefix + "down")
	if v != Vector2.ZERO:
		touched = true
	return v

func _held(what: String) -> bool:
	if ai or covering:
		match what:
			"action": return ai_action
			"alt": return ai_alt
			"slow": return ai_slow
			"leave": return ai_leave
	var on := Input.is_action_pressed(prefix + what)
	if on:
		touched = true
	return on

func _pressed(what: String) -> bool:
	if ai or covering:
		return _held(what) and not _ai_prev[what]
	return Input.is_action_just_pressed(prefix + what)

func action_pressed() -> bool:
	return _pressed("action")

func action_held() -> bool:
	return _held("action")

func alt_pressed() -> bool:
	return _pressed("alt")

func alt_held() -> bool:
	return _held("alt")

func slow_pressed() -> bool:
	return _pressed("slow")

func slow_held() -> bool:
	return _held("slow")

func leave_pressed() -> bool:
	return _pressed("leave")

## Called once per frame after handling, so virtual presses register once.
func end_frame() -> void:
	if ai or covering:
		_ai_prev = {"action": ai_action, "alt": ai_alt, "slow": ai_slow, "leave": ai_leave}

# ------------------------------------------------------------------ cues

## Show a button to press. `what` is "action", "alt", "leave" or "slow" (or
## "A"/"B"/"X"/"Y"). `progress` >= 0 draws a hold ring. Up to two at once.
func cue(what: String, verb := "", progress := -1.0, urgent := false, zone := Vector2(-1, -1), alarm := false) -> void:
	_cue_added = cues.size() < 2
	if not _cue_added:
		return
	cues.append([BTN.get(what, what), verb, progress, urgent, zone, alarm, false])

var _cue_added := false

## The gold assist: the button just cued lights up gold when this is the
## moment (or the spot) to press it. A setting turns the hints off; a hold's
## own gold band (the hammer) always shows.
func gold(on := true) -> void:
	if on and _cue_added and not cues.is_empty():
		cues[-1][6] = true

## Colours the button just cued (the slump call's water-blue X).
func tint(col: Color) -> void:
	if _cue_added and not cues.is_empty():
		cues[-1].append(col)

## Is this cue gold right now (in its hold band, or flagged by the assist)?
static func is_gold(cu: Array) -> bool:
	var zv: Vector2 = cu[4] if cu.size() > 4 else Vector2(-1, -1)
	if zv.x >= 0.0 and float(cu[2]) >= zv.x and float(cu[2]) <= zv.y:
		return true
	return cu.size() > 6 and cu[6] and bool(Settings.value("gold_assist"))

var _was_gold := [false, false, false]

## A short status line under the head (a height, a count), not an action.
func say(text: String) -> void:
	prompt.text = text

func begin_cues() -> void:
	cues.clear()
	prompt.text = ""

func show_cues(cam_right: Vector3, t: float, cam_pos := Vector3.ZERO, cam_k := 1.0) -> void:
	# Keep glyphs a steady size on screen however far away the camera is
	var k_size := 1.0
	bubble.visible = false
	_update_balloons(get_process_delta_time(), cam_pos)
	if bot and not show_bot_cues:
		for c in _cue_nodes:
			(c["node"] as Node3D).visible = false
		return
	if cam_pos != Vector3.ZERO:
		k_size = clampf(global_position.distance_to(cam_pos) / 15.0 * cam_k, 0.5 if cam_k != 1.0 else 0.9, 3.2)
	var on_keys: bool = not ai and not bot and KEYS.has(prefix) and bool(get_parent().on_keys.get(prefix, prefix == "p1_"))
	for k in _cue_nodes.size():
		var c: Dictionary = _cue_nodes[k]
		var n: Node3D = c["node"]
		n.visible = k < cues.size()
		if not n.visible:
			_was_gold[k] = false
			(c["trickle"] as CPUParticles3D).emitting = false
			continue
		var cu: Array = cues[k]
		var btn: String = cu[0]
		var alarm: bool = cu.size() > 5 and cu[5]
		# Small, just beside the head, so the name tag above stays readable
		var gk := k_size * 0.55
		n.position = Vector3(0, 1.5 + 0.2 * gk - k * 1.05 * gk, 0) + cam_right * (0.45 + 0.55 * gk)
		# Alarm: a hard shake, 0.15 s a cycle
		if alarm:
			var w := t * TAU / UI.SHAKE_T
			n.position += Vector3(sin(w), sin(w * 0.8 + 1.0), 0) * 0.05 * gk
		n.scale = Vector3.ONE * gk
		var m: ShaderMaterial = c["mat"]
		var tinted: bool = cu.size() > 7 and cu[7] is Color
		var col: Color = UI.ALARM if alarm else (cu[7] if tinted else BTN_COLORS.get(btn, Color.WHITE))
		var lip: Color = col.darkened(0.45) if alarm or tinted else UI.LIP.get(btn, col.darkened(0.45))
		m.set_shader_parameter("color", col)
		m.set_shader_parameter("lip", lip)
		m.set_shader_parameter("progress", cu[2])
		m.set_shader_parameter("zone", cu[4] if cu.size() > 4 else Vector2(-1, -1))
		var in_zone: bool = is_gold(cu) and not alarm
		# (the assist, as against a hold's own gold band)
		var assisted: bool = in_zone and cu.size() > 6 and cu[6]
		m.set_shader_parameter("assist", 1.0 if assisted else 0.0)
		m.set_shader_parameter("gold_on", 1.0 if in_zone else 0.0)
		var tr: CPUParticles3D = c["trickle"]
		tr.emitting = in_zone
		if in_zone and not _was_gold[k]:
			(c["sparks"] as CPUParticles3D).restart()
			if not bot:
				# A little buzz in the hand the moment it goes gold
				get_parent().haptic(self, UI.BUZZ["gold"])
		_was_gold[k] = in_zone
		# The press squash: 90 ms down onto the lip, then a springy overshoot
		var what: String = BTN.find_key(btn) if BTN.values().has(btn) else ""
		var down := what != "" and not bot and _held(what)
		if down and not c["was_down"]:
			c["pressed_at"] = t
		c["was_down"] = down
		var since: float = t - float(c["pressed_at"])
		if since < 0.0:
			# (the clock's the phase's, and it went back to 0 when the phase
			# changed: a press from before that is long gone, not in the future,
			# or the bounce below blows the button up to fill the screen)
			c["pressed_at"] = -9.0
			since = t + 9.0
		var squash := 0.0
		var press_k := 1.0
		if since < 0.09:
			squash = since / 0.09
			press_k = 1.0 - 0.12 * squash
		elif since < 0.6:
			squash = maxf(0.0, 1.0 - (since - 0.09) / 0.08)
			press_k = 1.0 - 0.12 * cos((since - 0.09) * 22.0) * exp(-(since - 0.09) * 12.0)
		if down and float(cu[2]) >= 0.0:
			squash = maxf(squash, 0.6)
		m.set_shader_parameter("squash", squash)
		# Motion: ready breathes, press-now pulses, gold beats fast
		var period := UI.BREATHE_T
		var amp := UI.BREATHE_S - 1.0
		if alarm:
			period = UI.SHAKE_T * 2.0
			amp = 0.08
		elif in_zone:
			period = UI.GOLD_T
			amp = 0.1
		elif cu[3]:
			period = UI.URGENT_T
			amp = UI.URGENT_S - 1.0
		var pl := 0.5 - 0.5 * cos(t * TAU / period + k)
		m.set_shader_parameter("pulse", (0.7 + 0.3 * pl) if alarm or in_zone else (0.25 + 0.5 * pl * (1.0 if cu[3] else 0.4)))
		m.set_shader_parameter("scale_mul", (1.0 + amp * pl) * press_k * gk * (1.18 if in_zone else 1.0))
		var letter: Label3D = c["letter"]
		letter.text = btn
		letter.position = Vector3(0, 0.035 * (1.0 - 0.7 * squash), 0.01)
		letter.modulate = Color("2a1d00") if in_zone else (Color.WHITE if alarm else UI.GLYPH_INK.get(btn, Color("0f1b2d")))
		letter.scale = Vector3.ONE * (1.0 + amp * pl) * press_k * (1.18 if in_zone else 1.0)
		var verb: Label3D = c["verb"]
		var words: String = cu[1]
		if in_zone and words != "":
			words = words.to_upper()
		if on_keys:
			var key: String = KEYS[prefix].get(btn, "")
			words = ("%s  [%s]" % [words, key]) if words != "" else "[%s]" % key
		verb.text = words
		verb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		verb.modulate = Color("ff6b5f") if alarm else (UI.GOLD if in_zone else (Color("9fd6ff") if tinted else UI.BONE))
		# The pill under the words, sized to them, with the job's dot
		var pill: MeshInstance3D = c["pill"]
		pill.visible = words != ""
		if words != "":
			var tw := UI.font("head").get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, verb.font_size).x * verb.pixel_size
			var h := verb.font_size * verb.pixel_size * 1.25
			var left := 0.58
			var bw := tw + h * 1.35
			verb.position = cam_right * (left + h * 0.95)
			pill.position = cam_right * (left + bw * 0.5) + Vector3(0, 0, -0.01)
			(pill.mesh as QuadMesh).size = Vector2(bw, h) * gk
			var pm: ShaderMaterial = c["pmat"]
			pm.set_shader_parameter("box", Vector2(bw, h))
			pm.set_shader_parameter("dot_color", UI.ALARM if alarm else UI.ROLE.get(role, tag_color))
			pm.set_shader_parameter("edge", Color(UI.GOLD, 0.9) if in_zone else (Color(UI.ALARM, 0.9) if alarm else Color(0, 0, 0, 0)))

# ------------------------------------------------------------------ carrying

func hold_item(item: Node3D, kind: String) -> void:
	held = item
	held_kind = kind
	if item.get_parent():
		item.get_parent().remove_child(item)
	model.add_child(item)
	if kind == "pipe":
		item.position = Vector3(0.0, 1.05, 0.0)
		item.rotation = Vector3(0, 0, PI * 0.5)
	else:
		item.position = Vector3(0, 0.75, 0.42)
		item.rotation = Vector3.ZERO
	bounce()

## Hands the held item back to the caller (to drop or use). Returns it.
func release_item() -> Node3D:
	var it := held
	held = null
	held_kind = ""
	if it and it.get_parent():
		it.get_parent().remove_child(it)
	return it

# ------------------------------------------------------------------ movement and animation

## Moves on the XZ plane. `walkable` is a Callable(Vector3, String) -> bool.
## `cam_yaw` turns stick input into camera-relative movement.
func walk(delta: float, walkable: Callable, cam_yaw: float) -> void:
	var v := move_input()
	if (busy != "" and busy != "hose") or zone == "ladder" or zone == "hoist":
		v = Vector2.ZERO
	var dir := Vector3(v.x, 0, v.y).rotated(Vector3.UP, cam_yaw)
	var run := run_to != Vector3.INF
	if run:
		var to := Vector3(run_to.x - position.x, 0, run_to.z - position.z)
		dir = to.normalized() if to.length() > 0.15 else Vector3.ZERO
	run_to = Vector3.INF
	var sp := speed * (0.7 if held_kind == "pipe" else 1.0) * (1.3 if hurry or run else 1.0) * (1.0 - 0.35 * weary) * pace
	if dir.length() > 0.05:
		var step := dir * sp * delta
		var p := position
		if walkable.call(p + Vector3(step.x, 0, 0), zone):
			p.x += step.x
		if walkable.call(p + Vector3(0, 0, step.z), zone):
			p.z += step.z
		position = p
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 12.0))
		_moving = true
		_walk += delta * (15.0 if hurry else 11.0)
	else:
		_moving = false
		_walk = lerpf(_walk, roundf(_walk / PI) * PI, minf(1.0, delta * 8.0))
	# Running for something urgent: lean into it
	model.rotation.x = lerpf(model.rotation.x, (0.22 if hurry and _moving else 0.0) + 0.2 * weary, minf(1.0, delta * 8.0))
	animate(delta)

func animate(delta: float) -> void:
	_phase += delta
	var s := sin(_walk)
	model.get_node("LegL").rotation.x = s * 0.6
	model.get_node("LegR").rotation.x = -s * 0.6
	var head: Node3D = model.get_node("Head")
	head.position.y = 1.32 + absf(s) * 0.05 + sin(_phase * 3.0) * 0.02 * (1.0 - weary) - 0.09 * weary
	# Worn out: the head hangs and lolls slowly side to side, eyes half shut
	head.rotation.z = sin(_phase * 1.7) * 0.06 * (1.0 - weary) + sin(_phase * 0.8) * 0.2 * weary
	head.rotation.x = 0.42 * weary + sin(_phase * 0.55) * 0.06 * weary
	var lid := 1.0 - 0.75 * weary * (0.85 + 0.15 * sin(_phase * 0.4))
	if fmod(_phase, 3.7) < 0.12:
		lid = 0.1   # a slow blink
	for e in ["EyeL", "EyeR"]:
		if head.has_node(e):
			(head.get_node(e) as Node3D).scale = Vector3(1.0, lid, 1.0)
	if _sweat:
		_sweat.emitting = weary > 0.45
	if busy == "" and zone != "ladder" and tool == "":
		if held_kind == "pipe":
			pose_arms(Vector3(-2.7, 0, -0.3), Vector3(-2.7, 0, 0.3))
		elif held != null:
			pose_arms(Vector3(-1.2, 0, 0.2), Vector3(-1.2, 0, -0.2))
		else:
			# Arms swing as you walk; worn out, they just hang and dangle
			var dangle := sin(_phase * 1.1) * 0.08 * weary
			pose_arms(Vector3(-s * 0.5 * (1.0 - 0.6 * weary) + 0.25 * weary + dangle, 0, -0.25 + 0.15 * weary), Vector3(s * 0.5 * (1.0 - 0.6 * weary) + 0.25 * weary - dangle, 0, 0.25 - 0.15 * weary))
	# Squash and stretch after an action (and a slump when worn out)
	_bounce = maxf(0.0, _bounce - delta * 4.0)
	var b := sin(_bounce * PI) * 0.18
	var slump := 0.07 * weary
	model.scale = Vector3(1.0 + b + slump * 0.5, 1.0 - b - slump, 1.0 + b + slump * 0.5)

func bounce() -> void:
	_bounce = 1.0

func set_arms(left_x: float, right_x: float, left_z := -0.25, right_z := 0.25) -> void:
	model.get_node("ArmL").rotation = Vector3(left_x, 0, left_z)
	model.get_node("ArmR").rotation = Vector3(right_x, 0, right_z)

## Full control of both arms, for hand signals: (x, y, z) Euler per arm.
func pose_arms(left: Vector3, right: Vector3) -> void:
	model.get_node("ArmL").rotation = left
	model.get_node("ArmR").rotation = right

func face(world_point: Vector3) -> void:
	var d := world_point - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		model.rotation.y = atan2(d.x, d.z)

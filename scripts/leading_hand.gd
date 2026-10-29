## The leading hand (Macca, unless someone's playing him) when he steps in
## to cover a job: he storms over to whoever it was waiting on, stands at
## their shoulder and gives them a spray the whole time, red in the face,
## steam off his hat, finger pointing, the language bleeped out like on TV.
## He doesn't take their body: their chibi does the step, with him yelling
## them through it. When they take it back (or the step's done) he gets one
## last word in and stomps off.
extends Node3D

const F := preload("res://scripts/factory.gd")
const Roster := preload("res://scripts/roster.gd")
const SHOUT := preload("res://shaders/shout.gdshader")

const WALK := 5.5          # m/s, storming
const SIDE := 1.25         # m off their shoulder
const LINE_EVERY := 2.7    # s between lines
const LINE_LIFE := 2.3     # s a shout stays up
const SHOUT_SIZE := 30
const SHOUT_WRAP := 360.0  # px of text before a shout wraps
const CUSS := ["#@%&", "$#!@", "%&#@", "@#$%!", "#%@&"]

## {n} is the person's crew name, {c} a bleeped word
const OPENERS := ["OI, {n}! WAKE UP, YA {c}!", "{n}! WHAT THE {c} ARE YA DOIN'?!", "STRUTH, {n}! SHIFT YA {c}!"]
const SPRAY := {
	"line": ["THE TRUCK'S BEEN SITTIN' THERE, YA {c}!", "TEST THE {c} LOAD, {n}!", "THE DRIVER'S ON HIS {c} PHONE COS OF YOU!"],
	"pump": ["WHO'S ON THE {c} PUMP?!", "WATCH THE {c} GAUGE, {n}!", "SHE'LL BLOCK, YA {c} GALAH!"],
	"boom": ["THE BOOM DON'T STEER ITSELF, YA {c}!", "SWING THE {c} THING, {n}!"],
	"hose": ["GRAB THE {c} HOSE, {n}!", "IT'S A HOSE, NOT A {c} PET!"],
	"poker": ["IT'S GOIN' OFF, YA {c}! GET THE POKER IN!", "{n}! VIBRATE THE {c} THING!"],
	"screed": ["WHO'S ON THE {c} BOARD?!", "SCREED IT, YA {c}, IT'S GOIN' OFF!"],
	"": ["MY NAN POURS FASTER, YA {c}!", "FOUR HUNDRED BUCKS A METRE AND YOU'RE {c} STANDIN' THERE!", "YA WANNA GO BACK TO THE {c} OFFICE?!",
		"MOVE YA {c} FEET, {n}!", "FAIR {c} DINKUM!", "I'VE GOT {c} BOOTS OLDER THAN YOU!", "DO I LOOK LIKE YA {c} MUM?!"],
}
const BACK := ["ABOUT {c} TIME, {n}!", "OH, NOW YA WAKE UP, YA {c}!", "DON'T {c} DO IT AGAIN!"]
const DONE := ["DONE IT FOR YA, YA {c}!", "THAT'S HOW IT'S {c} DONE, {n}!", "YOU OWE ME A {c} PIE, {n}!"]

var game
var who = null               # the person he's spraying
var char_info: Dictionary = {}
var _body: Node3D
var _steam: CPUParticles3D
var _t := 0.0
var _line_t := 0.0
var _said: Array = []        # the last few lines, so he doesn't repeat himself
var _shouts: Array = []      # {node, mat, t, base, seed}
var _leave_t := 0.0          # walking off, then gone
var _leave_dir := Vector3.ZERO
var _red := 0.0
var on_t := 0.0              # seconds he's been at the current person

func setup(owner_game) -> void:
	game = owner_game
	char_info = Roster.char_info("macca")
	# The leading hand's white hat and a hi-vis orange shirt: the boss on site
	_body = F.chibi(Color("f47a20"), Color("f4f7fa"))
	F.dress(_body, char_info)
	_body.scale = Vector3.ONE * 1.12
	add_child(_body)
	_steam = CPUParticles3D.new()
	_steam.emitting = false
	_steam.amount = 14
	_steam.lifetime = 0.9
	_steam.direction = Vector3.UP
	_steam.spread = 25.0
	_steam.initial_velocity_min = 1.2
	_steam.initial_velocity_max = 2.0
	_steam.gravity = Vector3(0, 0.6, 0)
	_steam.scale_amount_min = 0.6
	_steam.scale_amount_max = 1.2
	var puff := SphereMesh.new()
	puff.radius = 0.09
	puff.height = 0.18
	_steam.mesh = puff
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color(1, 1, 1, 0.75)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_steam.material_override = pm
	_steam.position = Vector3(0, 2.15, 0)
	_body.add_child(_steam)
	visible = false

## Who the leading hand is today: Macca, or if a person's playing Macca,
## the first of the crew nobody's playing.
func _pick_char() -> void:
	var taken := {}
	for q in game.players:
		taken[String(q.char_name).to_lower()] = true
	for id in ["macca", "nev", "gus", "tash", "priya", "robbo", "jules", "kiri"]:
		if not taken.has(id):
			char_info = Roster.char_info(id)
			F.dress(_body, char_info)
			return

func lh_name() -> String:
	return String(char_info.get("name", "Macca"))

## He's covering `p` now: over he comes.
func start(p) -> void:
	if who == p:
		return
	var was_on := visible and _leave_t <= 0.0
	who = p
	_leave_t = 0.0
	if not was_on:
		_pick_char()
		visible = true
		var off: Vector3 = _side_spot(p) - p.global_position
		# (he comes in from a few metres off, on the far side from the camera)
		global_position = p.global_position + off.normalized() * 7.0
		if not _on_same_level(global_position, p.global_position):
			global_position = _side_spot(p)
	_line_t = 0.9
	on_t = 0.0
	_say(OPENERS)

## They've taken it back (`back`), or the step's done: one last word, then off.
func stop(p, back: bool) -> void:
	if who != p:
		return
	_say(BACK if back else DONE)
	who = null
	_leave_t = 2.4
	var cam: Camera3D = game.camera
	var away := (global_position - cam.global_position) if cam else Vector3.FORWARD
	away.y = 0.0
	_leave_dir = away.normalized().rotated(Vector3.UP, randf_range(-0.8, 0.8))

func _on_same_level(a: Vector3, b: Vector3) -> bool:
	return absf(a.y - b.y) < 1.0

func _side_spot(p) -> Vector3:
	var cam: Camera3D = game.camera
	var right := Vector3.RIGHT
	if cam:
		right = cam.global_transform.basis.x
		right.y = 0.0
		right = right.normalized()
	# (whichever side of them he's already on)
	var side := 1.0 if (global_position - p.global_position).dot(right) >= 0.0 else -1.0
	return p.global_position + right * SIDE * side

## One line from `pool` (or the job's lines), with each {c} bleeped.
func _say(pool) -> void:
	var lines: Array = []
	if pool is Dictionary:
		lines = (pool.get(String(who.role) if who != null else "", []) as Array) + (pool[""] as Array)
	else:
		lines = pool
	var pick: String = lines[randi() % lines.size()]
	for _i in 4:
		if not _said.has(pick):
			break
		pick = lines[randi() % lines.size()]
	_said.append(pick)
	if _said.size() > 4:
		_said.pop_front()
	var nm := String(who.char_name).to_upper() if who != null else "MATE"
	var cusses := 0
	var text := pick.replace("{n}", nm)
	var at_c := text.find("{c}")
	while at_c >= 0:
		text = text.substr(0, at_c) + CUSS[randi() % CUSS.size()] + text.substr(at_c + 3)
		cusses += 1
		at_c = text.find("{c}")
	_shout(text)
	# The bleeps land on the bleeped words, a beat apart
	for i in cusses:
		var at := 0.12 + i * 0.5
		get_tree().create_timer(at).timeout.connect(func(): if is_instance_valid(game) and game.sfx: game.sfx.hit("bleep" if i == 0 else "bleep_s"))
	if who != null:
		game.haptic(who, "60,40,60,40,120")

func _shout(text: String) -> void:
	var b: Label3D = F.label3d(text, SHOUT_SIZE, Color("7a0c0c"))
	b.outline_size = 0
	b.layers = 2
	b.render_priority = 22
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font: Font = b.font if b.font else ThemeDB.fallback_font
	var px := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, SHOUT_SIZE)
	if px.x > SHOUT_WRAP:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.width = SHOUT_WRAP
		px = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, SHOUT_WRAP, SHOUT_SIZE)
	var box := px * b.pixel_size
	var spike := 0.2
	var bg := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = (box * 0.72 + Vector2(0.12, 0.12) + Vector2(spike + 0.06, spike + 0.06)) * 2.0
	bg.mesh = qm
	var mat := ShaderMaterial.new()
	mat.shader = SHOUT
	mat.render_priority = 21
	mat.set_shader_parameter("size", box)
	mat.set_shader_parameter("spike_h", spike)
	var sd := randf()
	mat.set_shader_parameter("seed", sd)
	bg.material_override = mat
	bg.layers = 2
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bg.position = Vector3(0, 0, -0.01)
	b.add_child(bg)
	game.add_child(b)
	_shouts.append({"node": b, "mat": mat, "t": 0.0, "seed": sd})
	while _shouts.size() > 2:
		var old: Dictionary = _shouts.pop_front()
		(old["node"] as Node).queue_free()

## (dev) A shout's up and fully in.
func shouting() -> bool:
	for e in _shouts:
		if float(e["t"]) > 0.4 and float(e["t"]) < LINE_LIFE - 0.4:
			return true
	return false

func update(delta: float) -> void:
	_t += delta
	on_t += delta
	_update_shouts(delta)
	if not visible:
		return
	var moving := false
	if who != null and is_instance_valid(who):
		if not who.covering:
			stop(who, true)
		else:
			var goal: Vector3 = _side_spot(who)
			var d := goal - global_position
			if d.length() > 18.0 or not _on_same_level(goal, global_position) and d.length() > 3.0:
				# (a long way, or up or down a level: he's come by the stairs)
				global_position = goal
				d = Vector3.ZERO
			var flat := Vector3(d.x, 0, d.z)
			moving = flat.length() > 0.35
			if moving:
				global_position += flat.normalized() * minf(flat.length(), WALK * delta)
			global_position.y = move_toward(global_position.y, goal.y, 4.0 * delta)
			# Facing them, always
			var look: Vector3 = who.global_position - global_position
			if look.length() > 0.2:
				rotation.y = lerp_angle(rotation.y, atan2(look.x, look.z), minf(1.0, delta * 10.0))
			_line_t -= delta
			if _line_t <= 0.0:
				_line_t = LINE_EVERY + randf_range(-0.3, 0.5)
				_say(SPRAY)
	elif _leave_t > 0.0:
		_leave_t -= delta
		moving = true
		global_position += _leave_dir * 3.0 * delta
		rotation.y = atan2(_leave_dir.x, _leave_dir.z)
		if _leave_t <= 0.0:
			visible = false
	else:
		visible = false
	_animate(delta, moving)

func _animate(delta: float, moving: bool) -> void:
	var spraying := who != null and not moving
	var ph := _t * (11.0 if moving else 7.0)
	(_body.get_node("LegL") as Node3D).rotation.x = sin(ph) * (0.6 if moving else 0.0)
	(_body.get_node("LegR") as Node3D).rotation.x = -sin(ph) * (0.6 if moving else 0.0)
	var arm_r := _body.get_node("ArmR") as Node3D
	var arm_l := _body.get_node("ArmL") as Node3D
	var head := _body.get_node("Head") as Node3D
	if spraying:
		# Finger jabbing at them, the other fist going, head pushed forward
		var jab := sin(_t * 14.0)
		arm_r.rotation = Vector3(-1.55 + 0.18 * jab, 0, 0.12)
		arm_l.rotation = Vector3(-2.3 + 0.55 * absf(sin(_t * 6.0)), 0, -0.35)
		head.rotation.x = 0.18 + 0.1 * sin(_t * 12.0)
		_body.position.y = absf(sin(_t * 6.0)) * 0.08
	else:
		arm_l.rotation = Vector3(-sin(ph) * (0.5 if moving else 0.0), 0, -0.25)
		arm_r.rotation = Vector3(sin(ph) * (0.5 if moving else 0.0), 0, 0.25)
		head.rotation.x = 0.1 if who != null else 0.0
		_body.position.y = 0.0
	_steam.emitting = who != null
	# Red in the face while he's at it
	var want := 1.0 if who != null else 0.0
	var was := _red
	_red = move_toward(_red, want, delta * 1.5)
	if absf(_red - was) > 0.0 and (int(_red * 10.0) != int(was * 10.0) or _red == want):
		var skin := Color(char_info.get("skin", "f1c7a3")).lerp(Color("e0453a"), _red * 0.7)
		F.dress(_body, {"skin": skin.to_html(false), "hair": char_info.get("hair", "6b4a2b"), "look": char_info.get("look", "moustache")})

func _update_shouts(delta: float) -> void:
	var cam: Camera3D = game.camera
	for e in _shouts.duplicate():
		var b: Label3D = e["node"]
		if not is_instance_valid(b):
			_shouts.erase(e)
			continue
		e["t"] = float(e["t"]) + delta
		var t: float = e["t"]
		if t > LINE_LIFE:
			b.queue_free()
			_shouts.erase(e)
			continue
		var bk := clampf(b.global_position.distance_to(cam.global_position) / 15.0, 0.8, 2.2) if cam else 1.0
		# Pops in big, shivers, and the older one's pushed up out of the way
		var pop := 1.0 + 0.35 * maxf(0.0, 1.0 - t * 6.0)
		var older := _shouts.size() - 1 - _shouts.find(e)
		var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.03 * bk
		b.global_position = global_position + Vector3(0, 2.9 + 0.3 * bk + older * 0.75 * bk, 0) + shake
		b.scale = Vector3.ONE * bk * pop
		var fade := clampf((LINE_LIFE - t) / 0.3, 0.0, 1.0)
		b.modulate.a = fade
		(e["mat"] as ShaderMaterial).set_shader_parameter("alpha", fade)

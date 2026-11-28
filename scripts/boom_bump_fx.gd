extends RefCounted
## The boom knocks the jump form: nobody should have to guess that it hit. A heavy clang with a bang
## under it, a red and white starburst and "CLANG!" at the spot on the form, a red ring off the boom
## tip, a jolt of the screen and a buzz on the operator's phone.

const F := preload("res://scripts/factory.gd")

const FINE := 10             # points off a knock (score.gd turns points into dollars)

## `at`: where it touched (world). `away`: the way it bounced off (unit, on plan). `op`: the boom
## operator, or null.
static func hit(game, at: Vector3, away: Vector3, op) -> void:
	game.sfx.hit("clang")
	game.sfx.hit("bang")
	game.shake = maxf(game.shake, 0.45)
	game.pop("CLANG!", at + Vector3(0, 0.9, 0), Color("ff5a4a"))
	if op != null:
		game.haptic(op, "bad")
	# (a knock costs: it's the boom op's money, bot or person)
	if game.get("score") != null and game.score != null:
		game.score.award(op, -FINE, "Boom collision")
	var burst := Node3D.new()
	game.add_child(burst)
	burst.global_position = at
	var red := _mat(Color(1.0, 0.25, 0.2, 1.0))
	var white := _mat(Color(1.0, 0.97, 0.9, 1.0))
	# (the star faces back the way the boom bounced, so it's flat on the form's face)
	var yaw := atan2(away.x, away.z)
	for i in 10:
		var a := TAU * i / 10.0
		var long := i % 2 == 0
		var spike := F.box(Vector3(0.09, 1.1 if long else 0.65, 0.05), red if long else white, Vector3.ZERO, false)
		spike.position = Vector3(cos(a), sin(a), 0) * (0.75 if long else 0.5)
		spike.rotation.z = a - PI * 0.5
		burst.add_child(spike)
	burst.rotation.y = yaw
	burst.scale = Vector3.ONE * 0.4
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.5
	tm.outer_radius = 0.62
	ring.mesh = tm
	ring.material_override = red
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(ring)
	ring.global_position = at + away * 0.3
	var tw: Tween = game.create_tween().set_parallel(true)
	tw.tween_property(burst, "scale", Vector3.ONE * 1.5, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "scale", Vector3(3.0, 0.5, 3.0), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(red, "albedo_color:a", 0.0, 0.3).set_delay(0.3)
	tw.tween_property(white, "albedo_color:a", 0.0, 0.3).set_delay(0.3)
	tw.chain().tween_callback(burst.queue_free)
	tw.tween_callback(ring.queue_free)

static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.albedo_color = c
	return m

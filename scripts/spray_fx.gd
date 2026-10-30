## The truck hand's wash-down: water out of the hose gun (props.glb
## "HoseGun") in a jet that breaks up into drops, arcs down and splashes.
## Put it at the gun's tip (0, 0.07, -0.3 in the gun's space) facing the
## same way; it sprays along its -z. `on` turns it on, `pressure` (0..1)
## sets how far it throws. Drops splash where they reach `floor_y` (global
## y; the hardstand or the truck's chute, whichever is under it).
## spray_fx.hose(points) makes the hose itself, along global points.
extends Node3D

const RF := preload("res://scripts/rope_fx.gd")
const F := preload("res://scripts/factory.gd")
const MAX := 320
const PER_S := 260.0
const SPEED := Vector2(3.0, 7.0)    # m/s out of the nozzle, at pressure 0 and 1
const LIFE := 1.4
const SPLASH_T := 0.35

@export var on := false
@export var pressure := 1.0
@export var floor_y := 0.0

var _mm: MultiMeshInstance3D
var _drops: Array[Dictionary] = []
var _owed := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/spray_drop.gdshader")
	m.render_priority = 2
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	_mm = MultiMeshInstance3D.new()
	_mm.multimesh = mm
	_mm.material_override = m
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm.top_level = true
	add_child(_mm)

func _process(delta: float) -> void:
	var gt := global_transform
	var fwd := -gt.basis.z.normalized()
	if on:
		_owed += PER_S * delta * lerpf(0.5, 1.0, pressure)
	while _owed >= 1.0 and _drops.size() < MAX:
		_owed -= 1.0
		var sp := lerpf(SPEED.x, SPEED.y, clampf(pressure, 0.0, 1.0)) * _rng.randf_range(0.9, 1.05)
		var spread := Vector3(_rng.randfn(0, 0.035), _rng.randfn(0, 0.035), _rng.randfn(0, 0.035))
		var v := (fwd + spread).normalized() * sp
		# (spread the spawn along the last frame's path so the jet's solid)
		var back := _rng.randf() * delta
		_drops.append({"p": gt.origin + v * back, "v": v, "t": back / LIFE, "s": _rng.randf_range(0.6, 1.2), "ring": false})
	if not on:
		_owed = 0.0
	var keep: Array[Dictionary] = []
	for d in _drops:
		if d["ring"]:
			d["t"] += delta / SPLASH_T
		else:
			d["t"] += delta / LIFE
			d["v"].y -= 9.8 * delta
			d["v"] *= 1.0 - 0.6 * delta
			d["p"] += d["v"] * delta
			if d["p"].y <= floor_y:
				# hit the ground: one in three leaves a splash ring
				if _rng.randf() < 0.35:
					keep.append({"p": Vector3(d["p"].x, floor_y + 0.01, d["p"].z), "v": Vector3.ZERO, "t": 0.0,
						"s": d["s"], "ring": true})
				continue
		if d["t"] < 1.0:
			keep.append(d)
	_drops = keep
	_draw()

func _draw() -> void:
	var mm := _mm.multimesh
	mm.visible_instance_count = _drops.size()
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam != null else Vector3(0, 10, 10)
	for i in _drops.size():
		var d: Dictionary = _drops[i]
		var b: Basis
		if d["ring"]:
			var w: float = 0.12 * d["s"] * (1.0 + 2.0 * d["t"])
			b = Basis(Vector3(w, 0, 0), Vector3(0, 0, w), Vector3(0, -1, 0))
		else:
			# stretched along its flight, turned to face the camera
			var v: Vector3 = d["v"]
			var along := v.normalized() if v.length() > 0.01 else Vector3.DOWN
			var to_eye: Vector3 = (eye - d["p"]).normalized()
			var across := along.cross(to_eye)
			across = across.normalized() if across.length() > 0.001 else Vector3.RIGHT
			# (long and thin while it's still a jet, shorter once it's broken up)
			var len := clampf(v.length() * lerpf(0.06, 0.03, d["t"]), 0.05, 0.4)
			var wid: float = 0.035 * d["s"] * (1.0 + d["t"])
			b = Basis(across * wid, along * len, across.cross(along))
		mm.set_instance_transform(i, Transform3D(b, d["p"]))
		mm.set_instance_custom_data(i, Color(d["t"], 1.0 if d["ring"] else 0.0, 0, 0))

## The wash hose along `points` (global): a dark green rubber tube
## (smoothed through the points, so a few will do)
static func hose(points: PackedVector3Array, r := 0.016) -> MeshInstance3D:
	var smooth := PackedVector3Array()
	var n := points.size()
	for i in n - 1:
		var p0 := points[maxi(i - 1, 0)]
		var p3 := points[mini(i + 2, n - 1)]
		var steps := maxi(2, int(points[i].distance_to(points[i + 1]) / 0.1))
		for k in steps:
			smooth.append(points[i].cubic_interpolate(points[i + 1], p0, p3, float(k) / steps))
	smooth.append(points[n - 1])
	var mi := MeshInstance3D.new()
	mi.mesh = RF.tube(smooth, r, 8)
	mi.material_override = F.color_mat(F.PROP_COLORS["hose"], false)
	mi.top_level = true
	return mi

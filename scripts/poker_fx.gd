## What the poker does to the concrete, big enough to read from the couch:
## air bubbles that swell up, wobble and pop (with a ring and a bit of
## spatter), the glossy cream that comes up once a spot's compacted, and the
## bleed-water puddle if it's held in too long. The bubbles stopping is the
## sign a spot is done, so they're big and shiny on purpose.
##
## Put it where the poker's in, at the concrete's top surface, and move it
## with the poker. Set `rate` (0..1: how hard the bubbles are coming; 0 and
## they stop), `sheen` (0..1: the cream) and `bleed` (0..1: the puddle).
## `radius` is the area it covers (m). `low_light` brightens it for dawn.
extends Node3D

const MAX_BUBBLES := 40
const MAX_RINGS := 24
const MAX_DROPS := 48
const PER_S := 16.0         # bubbles a second at rate 1
const GROW := Vector2(0.35, 0.8)    # s to swell up
const SIZE := Vector2(0.06, 0.14)   # bubble radius, m
const POP_T := 0.12         # s the skin takes to clear
const RING_T := 0.45
const DROP_T := 0.4

@export var rate := 0.0
@export var sheen := 0.0
@export var bleed := 0.0
@export var radius := 0.5
@export var low_light := 0.0:
	set(v):
		low_light = v
		if _bub_mat != null:
			_bub_mat.set_shader_parameter("low_light", v)
			_sheen_mat.set_shader_parameter("low_light", v)

var _bubbles: MultiMeshInstance3D
var _rings: MultiMeshInstance3D
var _drops: MultiMeshInstance3D
var _sheen: MeshInstance3D
var _churn: MeshInstance3D
var _churn_mat: ShaderMaterial
var _bleed: MeshInstance3D
var _bub_mat: ShaderMaterial
var _sheen_mat: ShaderMaterial
var _bleed_mat: ShaderMaterial
var _b: Array[Dictionary] = []
var _r: Array[Dictionary] = []
var _d: Array[Dictionary] = []
var _owed := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	var seed := _rng.randf() * 10.0
	# the cream and the puddle: flat discs just over the surface
	_sheen_mat = _mat("res://shaders/cream_sheen.gdshader", 1)
	_sheen_mat.set_shader_parameter("seed", seed)
	_sheen = _disc(_sheen_mat, 0.004)
	_bleed_mat = _mat("res://shaders/bleed_water.gdshader", 2)
	_bleed_mat.set_shader_parameter("seed", seed)
	_bleed = _disc(_bleed_mat, 0.006)
	_churn_mat = _mat("res://shaders/poker_churn.gdshader", 3)
	_churn_mat.set_shader_parameter("seed", seed)
	_churn = _disc(_churn_mat, 0.007)
	# the bubbles: half domes, sitting on the surface
	_bub_mat = _mat("res://shaders/poker_bubble.gdshader", 4)
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 1.0
	dome.is_hemisphere = true
	dome.radial_segments = 16
	dome.rings = 6
	_bubbles = _multi(dome, _bub_mat, MAX_BUBBLES)
	# the rings left when one pops, and the spatter
	var ring_mat := _mat("res://shaders/poker_ring.gdshader", 3)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	_rings = _multi(plane, ring_mat, MAX_RINGS)
	var drop_mat := _mat("res://shaders/poker_ring.gdshader", 5)
	drop_mat.set_shader_parameter("spatter", true)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_drops = _multi(quad, drop_mat, MAX_DROPS)
	low_light = low_light

func _mat(path: String, prio: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	m.render_priority = prio
	return m

func _disc(m: ShaderMaterial, lift: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * 2.0
	mi.mesh = pm
	mi.material_override = m
	mi.position.y = lift
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi

func _multi(mesh: Mesh, m: ShaderMaterial, n: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = n
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (big enough to hold everything it might draw, so it isn't culled)
	mmi.custom_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 2, 4))
	add_child(mmi)
	return mmi

## Clear everything at once (the poker's been lifted and moved on)
func clear() -> void:
	_b.clear()
	_r.clear()
	_d.clear()
	_owed = 0.0

func _process(delta: float) -> void:
	# the cream and the puddle
	var span := radius * 1.25
	_sheen.scale = Vector3(span, 1, span)
	_sheen.visible = sheen > 0.01
	_sheen_mat.set_shader_parameter("amount", clampf(sheen, 0.0, 1.0))
	_bleed.scale = Vector3(span * 1.3, 1, span * 1.3)
	_bleed.visible = bleed > 0.01
	_bleed_mat.set_shader_parameter("amount", clampf(bleed, 0.0, 1.0))
	_bleed_mat.set_shader_parameter("shake", 1.0 if rate > 0.0 or bleed < 1.0 else 0.3)
	_churn.scale = Vector3(span * 0.9, 1, span * 0.9)
	_churn.visible = rate > 0.01
	_churn_mat.set_shader_parameter("amount", clampf(rate, 0.0, 1.0))
	# new bubbles, mostly near the poker, some further out
	_owed += clampf(rate, 0.0, 1.0) * PER_S * delta
	while _owed >= 1.0 and _b.size() < MAX_BUBBLES:
		_owed -= 1.0
		var a := _rng.randf() * TAU
		var d := radius * sqrt(_rng.randf()) * (0.25 + 0.75 * _rng.randf())
		var big := lerpf(SIZE.x, SIZE.y, pow(_rng.randf(), 1.5)) * lerpf(0.75, 1.0, rate)
		_b.append({"p": Vector3(cos(a) * d, 0.0, sin(a) * d), "s": big, "t": 0.0,
			"grow": lerpf(GROW.x, GROW.y, _rng.randf()), "ph": _rng.randf(), "pop": -1.0})
	_owed = minf(_owed, 1.0)
	# grow them, then pop them
	var keep: Array[Dictionary] = []
	for b in _b:
		b["t"] += delta
		if b["pop"] < 0.0 and b["t"] >= b["grow"]:
			b["pop"] = 0.0
		if b["pop"] >= 0.0:
			b["pop"] += delta / POP_T
			if b["pop"] >= 1.0:
				_burst(b["p"], b["s"])
				continue
		keep.append(b)
	_b = keep
	_r = _age(_r, delta, RING_T)
	_d = _age(_d, delta, DROP_T)
	for d in _d:
		d["v"].y -= 9.8 * delta
		d["p"] += d["v"] * delta
	_draw()

func _age(list: Array[Dictionary], delta: float, life: float) -> Array[Dictionary]:
	var keep: Array[Dictionary] = []
	for x in list:
		x["t"] += delta / life
		if x["t"] < 1.0:
			keep.append(x)
	return keep

func _burst(p: Vector3, s: float) -> void:
	if _r.size() < MAX_RINGS:
		_r.append({"p": p, "s": s, "t": 0.0})
	for i in _rng.randi_range(2, 4):
		if _d.size() >= MAX_DROPS:
			break
		var a := _rng.randf() * TAU
		var out := _rng.randf_range(0.4, 1.0)
		_d.append({"p": p + Vector3(0, s * 0.3, 0), "s": s * _rng.randf_range(0.18, 0.32), "t": 0.0,
			"v": Vector3(cos(a) * out, _rng.randf_range(1.4, 2.4), sin(a) * out)})

func _draw() -> void:
	var mm := _bubbles.multimesh
	mm.visible_instance_count = _b.size()
	for i in _b.size():
		var b: Dictionary = _b[i]
		var grow := clampf(b["t"] / b["grow"], 0.0, 1.0)
		var s: float = b["s"]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s * 1.6, s)), b["p"]))
		var pop := maxf(b["pop"], 0.0)
		mm.set_instance_custom_data(i, Color(sqrt(grow), b["ph"], pop, 1.0 - pop * pop))
	mm = _rings.multimesh
	mm.visible_instance_count = _r.size()
	for i in _r.size():
		var r: Dictionary = _r[i]
		var w: float = r["s"] * lerpf(2.2, 5.5, sqrt(r["t"]))
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(w, 1, w)), r["p"] + Vector3(0, 0.008, 0)))
		mm.set_instance_custom_data(i, Color(r["t"], 0, 0, 0))
	mm = _drops.multimesh
	mm.visible_instance_count = _d.size()
	for i in _d.size():
		var d: Dictionary = _d[i]
		var w: float = d["s"] * 2.0
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(w, w, w)), d["p"]))
		mm.set_instance_custom_data(i, Color(d["t"], 0, 0, 0))

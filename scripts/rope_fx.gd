## A rope hanging between two points with a little sag: the climb section's
## second tag line, or anything else that needs a length of rope. Laid-rope
## look from shaders/rope.gdshader. Call set_ends() whenever the ends move
## (global positions); `slack` is how far the middle hangs below the line
## between them (m). Also lends tube() to spray_fx.gd for the wash hose.
extends MeshInstance3D

const SEGS := 20
const SIDES := 6

@export var radius := 0.014
@export var color := Color("d9c27a"):
	set(v):
		color = v
		if _mat != null:
			_mat.set_shader_parameter("color", v)

var _mat: ShaderMaterial
var _last: Array = []

func _init() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/rope.gdshader")
	_mat.set_shader_parameter("color", color)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true

## The rope from `a` to `b` (global), its middle `slack` m lower than the
## straight line. It swings a touch with `sway` (m, sideways in the middle).
func set_ends(a: Vector3, b: Vector3, slack := 0.4, sway := 0.0) -> void:
	var key := [a, b, slack, sway]
	if key == _last:
		return
	_last = key
	var side := (b - a).cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.001 else Vector3.RIGHT
	var pts := PackedVector3Array()
	for i in SEGS + 1:
		var t := float(i) / SEGS
		var bow := 4.0 * t * (1.0 - t)
		pts.append(a.lerp(b, t) + Vector3.DOWN * slack * bow + side * sway * bow)
	global_transform = Transform3D.IDENTITY
	mesh = tube(pts, radius, SIDES)

## A round tube along `pts` (in the mesh's own space), UV.x = metres along
static func tube(pts: PackedVector3Array, r: float, sides := 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	if n < 2:
		return null
	var along := 0.0
	var prev_side := Vector3.ZERO
	var rings: Array[PackedVector3Array] = []
	var norms: Array[PackedVector3Array] = []
	var dist := PackedFloat32Array()
	for i in n:
		var d := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var s := d.cross(Vector3.UP)
		if s.length() < 0.01:
			s = d.cross(Vector3.RIGHT)
		s = s.normalized()
		if prev_side != Vector3.ZERO and s.dot(prev_side) < 0.0:
			s = -s
		prev_side = s
		var u := s.cross(d).normalized()
		if i > 0:
			along += pts[i].distance_to(pts[i - 1])
		dist.append(along)
		var ring := PackedVector3Array()
		var nr := PackedVector3Array()
		for k in sides + 1:
			var a := TAU * k / sides
			var nn := s * cos(a) + u * sin(a)
			ring.append(pts[i] + nn * r)
			nr.append(nn)
		rings.append(ring)
		norms.append(nr)
	for i in n - 1:
		for k in sides:
			var q := [[i, k], [i + 1, k], [i + 1, k + 1], [i, k], [i + 1, k + 1], [i, k + 1]]
			for v in q:
				st.set_normal(norms[v[0]][v[1]])
				st.set_uv(Vector2(dist[v[0]], float(v[1]) / sides))
				st.add_vertex(rings[v[0]][v[1]])
	return st.commit()

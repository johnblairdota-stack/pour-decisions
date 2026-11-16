## Dev, for the hand of cards' backdrops (assets/cards/roof_*.jpg): the top of the finished building,
## built under the camera for `--roofshot` (main.gd). Each tower's view from its roof, looking out:
## Spire over its rooftop pool to the Story Bridge, Riverlight off its roof terrace down Hamilton
## Reach, the water tower from the walkway round the top of its tank.
## The set stands on the deck at the camera's feet, its far edge open to the view.
extends RefCounted

const F := preload("res://scripts/factory.gd")

const EYE := 1.65              # m: the camera's over the deck by this
const POOL_DROP := 6.5         # m: the camera's over Spire's pool deck by this

## kind: "pool" (Spire), "terrace" (Riverlight), "tank" (the water tower)
static func build(parent: Node3D, cam: Vector3, look: Vector3, kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "RoofSet"
	parent.add_child(root)
	var fwd := Vector3(look.x - cam.x, 0, look.z - cam.z).normalized()
	# (Spire: the pool deck is the level under the roof terrace the camera stands on, so the view
	# goes out over the water to the bridge rather than into the pool's far wall)
	root.position = Vector3(cam.x, cam.y - (POOL_DROP if kind == "pool" else EYE), cam.z)
	root.look_at(root.position + fwd, Vector3.UP)      # (local -z: out to the view, +x: to the right)
	match kind:
		"pool":
			_pool(root)
		"terrace":
			_terrace(root)
		"tank":
			_tank(root)
	return root

static func _mat(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

static func _glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.88, 0.9, 0.12)
	m.roughness = 0.05
	m.metallic = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## A box from local x0..x1 (right), z0..z1 (forward is -z: give z as metres out, positive), y0..y1.
static func _blk(root: Node3D, mat: Material, x0: float, x1: float, out0: float, out1: float, y0: float, y1: float) -> MeshInstance3D:
	var size := Vector3(absf(x1 - x0), absf(y1 - y0), absf(out1 - out0))
	var pos := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, -(out0 + out1) * 0.5)
	var b := F.box(size, mat, pos, false)
	root.add_child(b)
	return b

static func _lounger(root: Node3D, x: float, out: float, frame: Material, pad: Material) -> void:
	_blk(root, frame, x - 0.36, x + 0.36, out - 1.0, out + 0.9, 0.0, 0.32)
	_blk(root, pad, x - 0.33, x + 0.33, out - 0.95, out + 0.4, 0.32, 0.4)
	var back := _blk(root, pad, x - 0.33, x + 0.33, 0.0, 0.7, 0.0, 0.08)
	back.position = Vector3(x, 0.62, -(out + 0.75))
	back.rotation.x = deg_to_rad(-50.0)

static func _planter(root: Node3D, x: float, out: float, s := 1.0) -> void:
	_blk(root, _mat(Color("4a4c50")), x - 0.6 * s, x + 0.6 * s, out - 0.6 * s, out + 0.6 * s, 0.0, 0.75 * s)
	var leaf := _mat(Color("4f7a3c"))
	for k in [[0.0, 0.0, 0.7], [0.35, 0.2, 0.5], [-0.3, -0.25, 0.55]]:
		var sp := F.sphere(float(k[2]) * s, leaf, Vector3(x + float(k[0]) * s, (0.75 + float(k[2]) * 0.8) * s, -(out + float(k[1]) * s)))
		root.add_child(sp)

## Spire: a stone deck, the pool running out to an infinity edge, loungers down the right, planters
## on the left. Nothing past the water's far edge but the city and the river.
static func _pool(root: Node3D) -> void:
	var stone := _mat(Color("d9cfbc"), 0.9)
	var coping := _mat(Color("f1ede4"), 0.7)
	var water := _mat(Color("2fa6c4"), 0.04, 0.25)
	var under := _mat(Color("1d6f86"), 0.3)
	var near := 4.0
	var far := 18.0
	var hw := 4.2
	# the deck either side and behind, flush with the top of the coping
	_blk(root, stone, -10.0, -hw - 0.4, -6.0, far, -0.3, 0.0)
	_blk(root, stone, hw + 0.4, 10.0, -6.0, far, -0.3, 0.0)
	_blk(root, stone, -hw - 0.4, hw + 0.4, -6.0, near - 0.4, -0.3, 0.0)
	# the coping round three sides; the far side's the edge the water spills over
	_blk(root, coping, -hw - 0.4, -hw, near - 0.4, far, -0.05, 0.03)
	_blk(root, coping, hw, hw + 0.4, near - 0.4, far, -0.05, 0.03)
	_blk(root, coping, -hw, hw, near - 0.4, near, -0.05, 0.03)
	# the water, brimming, and the pool's body under it
	_blk(root, water, -hw, hw, near, far + 0.05, -0.06, -0.02)
	_blk(root, under, -hw - 0.4, hw + 0.4, near - 0.4, far + 0.2, -1.6, -0.3)
	# the spill channel's lip, just under the water's edge
	_blk(root, _mat(Color("2a2d33")), -hw - 0.4, hw + 0.4, far + 0.05, far + 0.35, -0.5, -0.1)
	var frame := _mat(Color("e8e6e1"), 0.5)
	var pad := _mat(Color("f7f4ee"), 0.95)
	for out in [6.0, 9.2, 12.4]:
		_lounger(root, hw + 2.0, out, frame, pad)
	_planter(root, -hw - 2.4, 5.0)
	_planter(root, -hw - 2.6, 11.5, 1.2)
	# a frameless glass rail beyond the decks either side of the pool (not across the water)
	var glass := _glass()
	for side in [-1.0, 1.0]:
		var x0: float = (hw + 0.4) * side
		var x1: float = 10.0 * side
		_blk(root, glass, minf(x0, x1), maxf(x0, x1), far - 0.03, far + 0.03, 0.0, 1.15)

## Riverlight: a timber terrace at the roof's edge, a glass rail, a table and two chairs.
static func _terrace(root: Node3D) -> void:
	var deck := _mat(Color("a8835a"), 0.9)
	# (the camera stands at the rail: the deck's under the frame, the rail's top along the bottom)
	var edge := 1.1
	_blk(root, deck, -8.0, 8.0, -6.0, edge, -0.3, 0.0)
	var glass := _glass()
	_blk(root, glass, -8.0, 8.0, edge - 0.05, edge, 0.0, 1.15)
	_blk(root, _mat(Color("8c9096"), 0.4, 0.6), -8.0, 8.0, edge - 0.08, edge + 0.03, 1.15, 1.19)
	var white := _mat(Color("eeeae2"), 0.6)
	_blk(root, white, 2.2, 3.4, 0.2, 1.2, 0.72, 0.76)
	_blk(root, white, 2.75, 2.85, 0.65, 0.75, 0.0, 0.72)
	_planter(root, -2.6, 0.6, 0.8)

## The water tower: the steel walkway round the top of the tank, its handrail, the tank's roof behind.
static func _tank(root: Node3D) -> void:
	var steel := _mat(Color("8d969b"), 0.5, 0.5)
	var rail := _mat(Color("f2c230"), 0.5)
	_blk(root, steel, -3.0, 3.0, -2.0, 2.4, -0.1, 0.0)
	for x in [-3.0, -1.0, 1.0, 3.0]:
		_blk(root, rail, x - 0.03, x + 0.03, 2.33, 2.39, 0.0, 1.05)
	_blk(root, rail, -3.0, 3.0, 2.33, 2.39, 1.0, 1.06)
	_blk(root, rail, -3.0, 3.0, 2.33, 2.39, 0.5, 0.55)

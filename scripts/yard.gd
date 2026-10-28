## The site set-up round Riverlight's east wing, as a 2017 Watpac job had it:
## the shed stack and crib corner in the yard east of the hoist, temporary
## fencing along the site road with the truck gate, the skip and the truck
## washout by the west wing, and the formwork, bar and mesh laid down along
## the south side where the crane picks them up. The models are
## tools/blender/site.py (assets/site/site.glb); this only places them.
##
## Kept clear of where people walk (main.walk_bounds), where the trucks back
## in and pull out (line.gd _back_path, _leave_path) and the crane's laydown.

const F := preload("res://scripts/factory.gd")

const FENCE_Z := 13.35       # just behind the hardstand's kerb, on the site road
const FENCE_E := -26.8       # the yard's east fence
const FENCE_W := 47.3        # ...and its west one, at the west wing's end
const GATE := Vector2(31.0, 42.0)   # the truck gate, open (x)
const PANEL := 2.4
const RUN := 12.0            # a run of five panels

static func _put(parent: Node3D, prop_name: String, at: Vector3, yaw := 0.0) -> Node3D:
	var n := F.prop(prop_name, {}, F.SITE)
	n.position = at
	n.rotation.y = yaw
	parent.add_child(n)
	return n

## Panels along a straight line from `a` to `b` (on the ground), in runs of
## five where they fit and single panels for what's left.
static func _fence(parent: Node3D, a: Vector3, b: Vector3, kind: String) -> void:
	var d := b - a
	var n := int(round(d.length() / PANEL))
	if n <= 0:
		return
	var dir := d.normalized()
	var yaw := atan2(-dir.z, dir.x)
	var i := 0
	while i < n:
		if n - i >= 5:
			_put(parent, kind + "Run", a + dir * PANEL * (i + 2.5), yaw)
			i += 5
		else:
			_put(parent, kind, a + dir * PANEL * (i + 0.5), yaw)
			i += 1

static func build(parent: Node3D) -> void:
	# Fencing: wire mesh along the site road so the crew stays in view, shade
	# cloth on the far sides, a few banners by the sheds
	_fence(parent, Vector3(FENCE_E, 0, FENCE_Z), Vector3(FENCE_E + RUN, 0, FENCE_Z), "FenceBanner")
	_fence(parent, Vector3(FENCE_E + RUN, 0, FENCE_Z), Vector3(GATE.x, 0, FENCE_Z), "FencePanel")
	_fence(parent, Vector3(GATE.y, 0, FENCE_Z), Vector3(FENCE_W, 0, FENCE_Z), "FencePanel")
	_fence(parent, Vector3(FENCE_E, 0, FENCE_Z), Vector3(FENCE_E, 0, 2.5), "FenceCloth")
	_fence(parent, Vector3(FENCE_E, 0, 2.5), Vector3(-22.0, 0, 2.5), "FenceCloth")
	_fence(parent, Vector3(FENCE_W, 0, FENCE_Z), Vector3(FENCE_W, 0, 1.9), "FenceCloth")
	# The truck gate: its two leaves slid open behind the fence, the PPE sign,
	# bollards at the posts and cones down the lane
	for k in 2:
		_put(parent, "FencePanel", Vector3(GATE.x - PANEL * (k + 0.5), 0, FENCE_Z - 0.3))
	_put(parent, "PPESign", Vector3(GATE.x - 0.6, 0, FENCE_Z + 0.5))
	for x in [GATE.x + 0.3, GATE.y - 0.3]:
		_put(parent, "Bollard", Vector3(x, 0, FENCE_Z))
	for at in [Vector3(31.6, 0, 12.2), Vector3(31.6, 0, 10.0), Vector3(42.4, 0, 12.4), Vector3(42.4, 0, 9.2)]:
		_put(parent, "Cone", at)

	# The yard east of the hoist: two stacks of sheds (office and crib room
	# over, toilets and the drying room under), the stair, the walkway along
	# the upper doors, and the crib corner out front
	var shed_x := -17.4
	for z_yaw in [[8.2, PI], [11.2, 0.0]]:
		for lvl in 2:
			_put(parent, "ShedUnit", Vector3(shed_x, lvl * 2.72, z_yaw[0]), z_yaw[1])
	_put(parent, "ShedWalkway", Vector3(shed_x, 2.7, 6.7), PI)
	_put(parent, "ShedStair", Vector3(-24.95, 0, 6.6))
	_put(parent, "FirstAid", Vector3(-12.6, 1.6, 6.62), PI)
	for i in 2:
		_put(parent, "PortaLoo", Vector3(-10.6, 0, 12.2 - i * 1.3), PI * 0.5)
	_put(parent, "ExtinguisherStand", Vector3(-10.9, 0, 8.6), PI * 0.5)
	_put(parent, "CribTable", Vector3(-17.0, 0, 4.4))
	for c in [[-17.6, 3.75, 0.2], [-16.4, 3.75, -0.15], [-17.6, 5.05, PI - 0.1], [-16.4, 5.05, PI + 0.25]]:
		_put(parent, "CribChair", Vector3(c[0], 0, c[1]), c[2])
	_put(parent, "Umbrella", Vector3(-17.0, 0, 4.4))
	_put(parent, "Esky", Vector3(-15.3, 0, 4.1), 0.3)
	_put(parent, "WaterTank", Vector3(-23.6, 0, 4.0))
	_put(parent, "WheelieBin", Vector3(-20.6, 0, 5.9), PI)
	_put(parent, "WheelieBinRecycle", Vector3(-19.9, 0, 5.9), PI)
	_put(parent, "Genset", Vector3(-11.6, 0, 5.0), PI * 0.5)
	_put(parent, "LightTower", Vector3(-13.6, 0, 3.2))

	# By the west wing, past where the trucks swing out: the chute washout,
	# the skip and the gas bottles against the wall
	_put(parent, "WashoutBay", Vector3(44.7, 0, 9.4), -PI * 0.5)
	_put(parent, "SkipBin", Vector3(44.8, 0, 4.8), PI * 0.5)
	_put(parent, "GasCage", Vector3(42.9, 0, 2.5))
	_put(parent, "SpillKit", Vector3(14.6, 0, 12.4))

	# The south side, under the crane: ply, pallets, bar and mesh, and
	# barrier mesh round the laydown
	_put(parent, "MeshStack", Vector3(-15.0, 0, -22.2))
	_put(parent, "BarBundle", Vector3(-7.5, 0, -21.6))
	_put(parent, "BarBundle", Vector3(-7.4, 0, -22.6), 0.04)
	for i in 3:
		_put(parent, "PlyStack", Vector3(-1.5 + i * 2.7, 0, -21.9), 0.04 * (i - 1))
	for i in 2:
		_put(parent, "Pallet", Vector3(-19.5, i * 0.13, -21.8), i * 0.2)
	_put(parent, "BarrierMesh", Vector3(-12.0, 0, -23.8))
	_put(parent, "BarrierMesh", Vector3(-4.0, 0, -23.8))
	_put(parent, "BarrierMesh", Vector3(4.0, 0, -23.8))

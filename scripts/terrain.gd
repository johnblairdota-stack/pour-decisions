## The real lie of the land round Riverlight: the 2019 LiDAR's bare ground,
## turned into the map frame by tools/terrain_to_game.py (data/terrain.bin).
## Northshore's reclaimed and flat, so it's gentle: the golf course a metre
## or two down, the riverwalk and the estate a bit up, the drains low. Out
## past it the real hills: Hamilton and Ascot north, Bulimba and Morningside
## over the river, Mt Gravatt and Mt Coot-tha on the skyline, from two
## coarser grids round it (data/terrain_mid.bin to 2.6 km, 5 m apart, the
## map's streets and buildings levelled into it too; data/terrain_far.bin to
## 16 km, 40 m apart). Each grid meets the next one out exactly at its edge.
##
## Everything outside the game's own site asks here how high the ground is:
## the map's ground and the banks (surrounds.gd), the buildings, kerbs,
## trees and fences (drape, after they're built), the traffic and the
## walkers, free roam and the 4x4 park. The tool keeps these put, so the
## rest of the game doesn't move:
##   - the site pad, and the street past its gates, at exactly 0
##   - the river at Water.RIVER_Y, and dry land at least 0.5 m above it
##   - the CityCat's bank at 0, where the gangway lands
##   - each street level across, each building on a level pad
## Out past 16 km it's 0 again: the flat world beyond.
##
## The map frame (x = west, z = north, origin Riverlight's centroid) is the
## Surrounds node's; the game's own frame is it less main.gd's REAL_ORIGIN.
extends RefCounted

const BIN := "res://data/terrain.bin"
const META := "res://data/terrain.json"
const GROUND := "res://data/ground_3d.bin"
## main.gd's REAL_ORIGIN (x, z): the map frame is the game's plus this
const ORIGIN := Vector2(-15.8, 9.5)
const RIVER_Y := -2.5            # water.gd's: kept out of a preload loop
## Below this (the bed of the river, a pile's foot) nothing's lifted; from
## here up to 0 it eases in, so a bank wall stretches rather than floats
const ANCHOR := RIVER_Y - 0.6

static var _h := PackedFloat32Array()
static var _n := 0
static var _half := 0.0
static var _cell := 1.0
static var _tried := false
## the coarser grids round the near one, finest first: [heights, n, half, cell]
static var _outer: Array = []

static func _load() -> void:
	_tried = true
	if not FileAccess.file_exists(BIN) or not FileAccess.file_exists(META):
		push_warning("terrain: %s missing, the world's flat" % BIN)
		return
	var meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	if not meta is Dictionary:
		return
	_n = int(meta["grid"])
	_half = float(meta["half"])
	_cell = float(meta["cell"])
	_h = FileAccess.get_file_as_bytes(BIN).to_float32_array()
	if _h.size() != _n * _n:
		push_warning("terrain: %s is the wrong size" % BIN)
		_h = PackedFloat32Array()
		_n = 0
		return
	for l in meta.get("layers", []):
		if String(l["file"]) == BIN:
			continue
		var n := int(l["grid"])
		var h := PackedFloat32Array()
		if FileAccess.file_exists(l["file"]):
			h = FileAccess.get_file_as_bytes(l["file"]).to_float32_array()
		if h.size() != n * n:
			push_warning("terrain: %s missing or the wrong size, flat past it" % l["file"])
			break
		_outer.append([h, n, float(l["half"]), float(l["cell"])])

static func ready() -> bool:
	if not _tried:
		_load()
	return _n > 0

## How high the ground is at `p` (map frame, m).
static func y(p: Vector2) -> float:
	if not _tried:
		_load()
	if _n == 0:
		return 0.0
	var fx := (p.x + _half) / _cell
	var fz := (p.y + _half) / _cell
	if fx < 0.0 or fz < 0.0 or fx >= _n - 1 or fz >= _n - 1:
		return _out_y(p)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i := iz * _n + ix
	var a := lerpf(_h[i], _h[i + 1], tx)
	var b := lerpf(_h[i + _n], _h[i + _n + 1], tx)
	return lerpf(a, b, tz)

## ...past the near grid: the finest of the others that reaches.
static func _out_y(p: Vector2) -> float:
	for l in _outer:
		var h: PackedFloat32Array = l[0]
		var n: int = l[1]
		var half: float = l[2]
		var cell: float = l[3]
		var fx := (p.x + half) / cell
		var fz := (p.y + half) / cell
		if fx < 0.0 or fz < 0.0 or fx >= n - 1 or fz >= n - 1:
			continue
		var ix := int(fx)
		var iz := int(fz)
		var tx := fx - ix
		var tz := fz - iz
		var i := iz * n + ix
		return lerpf(lerpf(h[i], h[i + 1], tx), lerpf(h[i + n], h[i + n + 1], tx), tz)
	return 0.0

## ...at a spot in the game's own frame (main.gd's, the site's).
static func y_game(p: Vector3) -> float:
	return y(Vector2(p.x + ORIGIN.x, p.z + ORIGIN.y))

## Which way the ground leans at `p` (map frame), over `e` m each way.
static func normal(p: Vector2, e := 1.0) -> Vector3:
	var hx := y(p + Vector2(e, 0)) - y(p - Vector2(e, 0))
	var hz := y(p + Vector2(0, e)) - y(p - Vector2(0, e))
	return Vector3(-hx, 2.0 * e, -hz).normalized()

## A height `h` made for flat ground at 0, put on the real ground at `p`:
## anything from 0 up goes up or down with the ground; down towards the
## river's bed it eases off, so the bottom of a bank or a pile stays put.
static func lift(p: Vector2, h: float) -> float:
	if h >= 0.0:
		return h + y(p)
	var k := clampf((h - ANCHOR) / -ANCHOR, 0.0, 1.0)
	return h + y(p) * k

## Whether `p` is on the near grid, the 2 m one round the site.
static func covers(p: Vector2) -> bool:
	if not _tried:
		_load()
	return _n > 0 and absf(p.x) < _half and absf(p.y) < _half

# ------------------------------------------------------------------ draping

## Puts everything under `root` (built for flat ground) onto the real ground.
## Meshes built for one place (SurfaceTool: kerbs, lines, fences, the
## buildings) have each vertex lifted; multimeshes have each copy lifted at
## its foot; anything else (a model used in many places) is lifted as a
## whole at its origin. `skip` are nodes left as they are (the water, things
## that move and find the ground for themselves, the site's own).
static func drape(root: Node3D, skip: Array = []) -> void:
	if not ready():
		return
	var jobs: Array = []
	var uses := {}
	_collect(root, Transform3D.IDENTITY, skip, jobs, uses)
	for j in jobs:
		var n: Node3D = j[0]
		var xf: Transform3D = j[1]
		match j[2]:
			"multi":
				_drape_multi(n as MultiMeshInstance3D, xf)
			"mesh":
				if int(uses.get((n as MeshInstance3D).mesh, 0)) == 1:
					_drape_mesh(n as MeshInstance3D, xf)
				else:
					_lift_node(n, xf)
			_:
				_lift_node(n, xf)

## What to do with each node: [node, its map transform, "multi" | "mesh" |
## "node"]. `xf` is the map transform of `n`.
static func _collect(n: Node, xf: Transform3D, skip: Array, jobs: Array, uses: Dictionary) -> void:
	for c in n.get_children():
		if c in skip or c.has_meta("no_drape"):
			continue
		if not c is Node3D:
			_collect(c, xf, skip, jobs, uses)
			continue
		var c3 := c as Node3D
		var cx := xf * c3.transform
		if c3.has_meta("drape_whole") or c3.scene_file_path != "":
			jobs.append([c3, cx, "node"])
		elif c3 is MultiMeshInstance3D:
			jobs.append([c3, cx, "multi"])
		elif c3 is MeshInstance3D:
			var m := (c3 as MeshInstance3D).mesh
			if m is ArrayMesh and m.resource_path == "" and _laid_out(c3 as MeshInstance3D):
				uses[m] = int(uses.get(m, 0)) + 1
				jobs.append([c3, cx, "mesh"])
			else:
				jobs.append([c3, cx, "node"])
		elif c3.get_child_count() == 0 or c3.transform != Transform3D.IDENTITY:
			# (a model put somewhere, a person, a boat: as one)
			jobs.append([c3, cx, "node"])
		else:
			# (a group, at the map's origin: what's in it)
			_collect(c3, cx, skip, jobs, uses)

## Whether a mesh is laid out across the map (kerbs, a block of houses)
## rather than a model about its origin.
static func _laid_out(mi: MeshInstance3D) -> bool:
	if mi.has_meta("drape_vertices"):
		return true
	var ab := mi.mesh.get_aabb()
	return maxf(ab.size.x, ab.size.z) > 6.0 or Vector2(ab.get_center().x, ab.get_center().z).length() > 4.0

static func _lift_node(n: Node3D, xf: Transform3D) -> void:
	var o := xf.origin
	var dy := lift(Vector2(o.x, o.z), o.y) - o.y
	if absf(dy) < 0.001:
		return
	# (in its parent's frame: up in the map is up in the parent too, as the
	# map's parents are only ever moved, never turned)
	n.position.y += dy

static func _drape_multi(mm_i: MultiMeshInstance3D, xf: Transform3D) -> void:
	var mm := mm_i.multimesh
	if mm == null or mm.instance_count == 0:
		return
	for i in mm.instance_count:
		var t := mm.get_instance_transform(i)
		var o := xf * t.origin
		var dy := lift(Vector2(o.x, o.z), o.y) - o.y
		if absf(dy) > 0.001:
			t.origin.y += dy
			mm.set_instance_transform(i, t)
	# (the culling box: copies can now stand lower than any did)
	var ab := mm_i.custom_aabb
	if ab.size != Vector3.ZERO:
		mm_i.custom_aabb = ab.grow(3.0)

static func _drape_mesh(mi: MeshInstance3D, xf: Transform3D) -> void:
	var src := mi.mesh as ArrayMesh
	var inv := xf.affine_inverse()
	var out := ArrayMesh.new()
	var moved := false
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in v.size():
			var w := xf * v[i]
			var ny := lift(Vector2(w.x, w.z), w.y)
			if absf(ny - w.y) > 0.001:
				w.y = ny
				v[i] = inv * w
				moved = true
		arr[Mesh.ARRAY_VERTEX] = v
		# (any custom channels keep their formats)
		var fmt := src.surface_get_format(s)
		var flags := 0
		for k in 4:
			var sh: int = Mesh.ARRAY_FORMAT_CUSTOM_BASE + k * Mesh.ARRAY_FORMAT_CUSTOM_BITS
			flags |= fmt & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << sh)
		out.add_surface_from_arrays(src.surface_get_primitive_type(s), arr, [], {}, flags)
		out.surface_set_material(s, src.surface_get_material(s))
		out.surface_set_name(s, src.surface_get_name(s))
	if moved:
		mi.mesh = out

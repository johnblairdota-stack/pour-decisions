extends SceneTree
const Surrounds := preload("res://scripts/surrounds.gd")
const Terrain := preload("res://scripts/terrain.gd")

func _verts(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh is ArrayMesh:
		var m := (n as MeshInstance3D).mesh as ArrayMesh
		for s in m.get_surface_count():
			t += m.surface_get_array_len(s)
	for c in n.get_children():
		t += _verts(c)
	return t

func _init() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var t0 := Time.get_ticks_msec()
	Surrounds.build(root)
	print("build ms ", Time.get_ticks_msec() - t0)
	for c in root.get_children():
		print("%-28s %-22s kids %4d verts %7d" % [c.name, c.get_class(), c.get_child_count(), _verts(c)])
	# trees and street furniture stand on the ground
	var off := 0
	var n := 0
	for c in root.get_children():
		if c is MultiMeshInstance3D and (String(c.name).begins_with("Trees_") or String(c.name).begins_with("Street_Park")):
			var mm := (c as MultiMeshInstance3D).multimesh
			for i in mm.instance_count:
				var o := mm.get_instance_transform(i).origin
				if Terrain.covers(Vector2(o.x, o.z)):
					n += 1
					if absf(o.y - Terrain.y(Vector2(o.x, o.z))) > 0.1:
						off += 1
	print("trees and park furniture on the heightmap: %d, off the ground: %d" % [n, off])
	# laid-out meshes: how far each triangle's middle is off the ground there
	for c in root.get_children():
		if c is MeshInstance3D and String(c.name) in ["Kerbs", "CentreLines", "Banks", "Revetment"]:
			var m := (c as MeshInstance3D).mesh
			var worst := 0.0
			var bad := 0
			var tris := 0
			for s in m.get_surface_count():
				var v: PackedVector3Array = m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
				for i in range(0, v.size() - 2, 3):
					var mid := (v[i] + v[i + 1] + v[i + 2]) / 3.0
					if not Terrain.covers(Vector2(mid.x, mid.z)) or mid.y < -1.5:
						continue
					var lo := minf(v[i].y, minf(v[i + 1].y, v[i + 2].y))
					var hi := maxf(v[i].y, maxf(v[i + 1].y, v[i + 2].y))
					if hi - lo > 0.3:
						continue    # (an upright face)
					tris += 1
					var g := mid.y - Terrain.y(Vector2(mid.x, mid.z))
					var gv := 0.0
					for k in 3:
						gv += v[i + k].y - Terrain.y(Vector2(v[i + k].x, v[i + k].z))
					gv /= 3.0
					var miss := absf(g - gv)
					if miss > 0.05:
						bad += 1
					worst = maxf(worst, miss)
			print("%s: %d flat triangles, %d more than 5 cm off the ground in the middle, worst %.2f m" % [c.name, tris, bad, worst])
	quit()

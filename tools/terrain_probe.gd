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
	quit()

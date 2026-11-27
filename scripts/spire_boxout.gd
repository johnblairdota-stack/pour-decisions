extends RefCounted
## The box-out round the boom column's penetration on Spire's deck: formply edge boards on all four
## sides, a little higher than the slab's finished top, with timber walers and pegs behind them, so
## the concrete stops at the opening and none of it runs down inside. A red and white board on top
## says the area inside isn't poured (main's sign over it reads "PENETRATION · NO POUR").
##
## Local to the rig (y 0 is the deck's top; the slab finishes `slab` above it).

const F := preload("res://scripts/factory.gd")

const UP := 0.2           # m the boards stand above the slab's finished top
const PLY := 0.06         # m, board thickness
const CAP := 0.3          # m, the red and white capping board's width (wide enough to read from the TV's camera)

static func build(op: PackedVector2Array, slab: float) -> Node3D:
	var n := Node3D.new()
	n.name = "PenetrationBoxOut"
	var ply := F.color_mat(Color("2b2622"))        # (black formply, as on John's site photos)
	var timber := F.color_mat(Color("e07a1f"))     # (orange LVL walers)
	var red := F.color_mat(Color("d3202f"))
	var white := F.color_mat(Color("f2f2ee"))
	var x0 := op[0].x
	var x1 := op[2].x
	var z0 := op[0].y
	var z1 := op[2].y
	var h := slab + UP
	var sides := [[Vector2(x0, z0), Vector2(x1, z0), Vector2(0, 1)], [Vector2(x1, z0), Vector2(x1, z1), Vector2(-1, 0)],
		[Vector2(x1, z1), Vector2(x0, z1), Vector2(0, -1)], [Vector2(x0, z1), Vector2(x0, z0), Vector2(1, 0)]]
	for s in sides:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var inw: Vector2 = s[2]
		var ln := a.distance_to(b)
		var mid := (a + b) * 0.5
		var along_x := absf(b.x - a.x) > absf(b.y - a.y)
		var size := func(l: float, hh: float, t: float) -> Vector3:
			return Vector3(l, hh, t) if along_x else Vector3(t, hh, l)
		# The board (its face to the concrete), the waler behind it on the opening's side
		n.add_child(F.box(size.call(ln + PLY * 2.0, h, PLY), ply, Vector3(mid.x, h * 0.5, mid.y)))
		var w := mid + inw * (PLY * 0.5 + 0.045)
		n.add_child(F.box(size.call(ln, 0.09, 0.09), timber, Vector3(w.x, h - 0.1, w.y)))
		# The red and white capping, in half-metre lengths
		var bits := maxi(2, int(round(ln / 0.5)))
		for i in bits:
			var c := a.lerp(b, (i + 0.5) / bits) + inw * (CAP * 0.5 - PLY)
			n.add_child(F.box(size.call(ln / bits, 0.05, CAP), red if i % 2 == 0 else white, Vector3(c.x, h + 0.025, c.y)))
	return n

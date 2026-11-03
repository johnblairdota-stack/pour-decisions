## The 4x4 park's ways in off the street (map metres; x is west, z is
## north), shared by the park itself (park4x4.gd), and by the houses and
## fences that keep clear of them (neighbours.gd, fences.gd). The MacArthur
## way starts right at the roundabout, up the lane behind the terraces
## (one house came out to open it up), so you can see where to go in.
extends RefCounted

const WAY_IN := {
	"MacArthur": [Vector2(0.4, 94.0), Vector2(-0.5, 105.9), Vector2(-1.8, 110.3), Vector2(-11.6, 126.0),
		Vector2(-30.0, 150.0), Vector2(-45.0, 172.0), Vector2(-60.0, 185.0)],
	"Parkside": [Vector2(-214.0, -8.0), Vector2(-235.0, 15.0), Vector2(-255.0, 40.0), Vector2(-275.0, 62.0), Vector2(-295.0, 78.0)],
}
## Where along each way the street ends and the park begins (the FREE AIR
## post and the records board stand there).
const GATE := {"MacArthur": 3, "Parkside": 0}

## Whether `p` is within `pad` of a way in.
static func near(p: Vector2, pad: float) -> bool:
	for k in WAY_IN:
		var w: Array = WAY_IN[k]
		for i in w.size() - 1:
			if Geometry2D.get_closest_point_to_segment(p, w[i], w[i + 1]).distance_to(p) < pad:
				return true
	return false

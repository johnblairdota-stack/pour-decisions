extends RefCounted
## Spire's deck section view (John's pick on 28 Nov 2026: "C + camera 2").
##
## C, the section cut: on the parts that take it (the perimeter scaffold, its containment mesh and the
## building's floors: main._give_cut(n, true)), the camera's side is cut away like a section drawing,
## the same idea as the climb day's slot up the boom column. Over the deck, the screens, rails and
## standards past a line through the deck's middle go, down to the toe boards; under the deck, the
## outside few metres of the storey below go, so you look into it. The cut's edges are hatched
## (shaders/cutaway.gdshaderinc cut_near_zone / cut_section). The boom, its column, the hoist and the
## tower crane never take it.
##
## 2, the section tilt: mid-pour, when the deck view closes in on the crew and the wet edge
## (main._tight), it also drops lower, looking in across the cut edge. Same direction as before, so
## the sticks don't change.

const SpireSite := preload("res://scripts/spire_site.gd")

const BELOW_IN := 2.5         # m in from the plate's edge the storey below is opened
const SECTION_PITCH := 0.4    # rad the deck view drops to mid-pour (from about 35 to 23 degrees down)

static var _c := Vector2.INF  # the plate's middle
static var _plate := PackedVector2Array()

## [cut_near, cut_near2] for the shader (zeros: off). `yaw`: the camera's; `deck_y`: the deck's top;
## `fh`: a storey.
static func params(on: bool, yaw: float, deck_y: float, fh: float) -> Array:
	if not on:
		return [Vector4.ZERO, Vector4.ZERO]
	if _c.x == INF:
		_plate = SpireSite.poly("plate")
		_c = SpireSite.centroid(_plate)
	# (quantised, so the materials aren't all written to every frame)
	yaw = snappedf(yaw, 0.02)
	var d := Vector2(sin(yaw), cos(yaw))
	var ext := 0.0
	for p in _plate:
		ext = maxf(ext, (p - _c).dot(d))
	return [Vector4(d.x, d.y, _c.x, _c.y), Vector4(snappedf(deck_y, 0.05), 0.0, ext - BELOW_IN, fh)]

## The deck view's pitch: `tight` 0 (whole slab) .. 1 (closed in on the crew mid-pour).
static func pitch(cam_pitch: float, tight: float) -> float:
	return lerpf(cam_pitch, minf(cam_pitch, SECTION_PITCH), ease(tight, -1.8))

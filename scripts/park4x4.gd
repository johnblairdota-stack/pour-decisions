## The Royal Queensland's back paddock gone bush when you knock off
## (explore.gd): two dirt tracks in off the estate, each splashing over the
## creek on a causeway, with mud tracked out onto the road where they come
## out; then a bog, a dam to wade across, a hill climb and a run of sand traps,
## all linked by a rutted track. The rest still looks like a golf course:
## greens with their flags, tee markers, and a club sign at each way in that
## nobody's paying any attention to.
##
## explore.gd asks it the ground's height (`height`), what it's made of
## (`surface`) and which way it leans (`normal`) anywhere on the map; outside
## the park that's flat, "" and straight up.
extends Node3D

const F := preload("res://scripts/factory.gd")
const Surrounds := preload("res://scripts/surrounds.gd")

## The tracks (map metres; x is west, z is north). Each way in starts at the
## road's edge and crosses the creek on the way.
const WAY_IN := {
	"MacArthur": [Vector2(-11.6, 126.0), Vector2(-30.0, 150.0), Vector2(-45.0, 172.0), Vector2(-60.0, 185.0)],
	"Parkside": [Vector2(-214.0, -8.0), Vector2(-235.0, 15.0), Vector2(-255.0, 40.0), Vector2(-275.0, 62.0), Vector2(-295.0, 78.0)],
}
const TRACKS := [
	# the main run: bog, sand traps, up the hill and round
	[Vector2(-60.0, 185.0), Vector2(-100.0, 178.0), Vector2(-142.0, 166.0), Vector2(-178.0, 164.0), Vector2(-200.0, 142.0),
		Vector2(-240.0, 110.0), Vector2(-295.0, 78.0), Vector2(-330.0, 76.0), Vector2(-360.0, 75.0), Vector2(-400.0, 75.0),
		Vector2(-408.0, 56.0), Vector2(-380.0, 44.0), Vector2(-330.0, 50.0), Vector2(-295.0, 78.0)],
	# the dam loop: across the water and back down to the bog
	[Vector2(-60.0, 185.0), Vector2(-55.0, 230.0), Vector2(-62.0, 268.0), Vector2(-128.0, 262.0), Vector2(-150.0, 225.0),
		Vector2(-160.0, 190.0), Vector2(-160.0, 172.0)],
]
const TRACK_W := 4.6

## The challenges: [kind, centre, half length, half width, yaw of the long axis, size]
## hill: size is its height; bog and sand: how deep the wheels sink
const FEATURES := [
	["hill", Vector2(-360.0, 75.0), 17.0, 24.0, 0.0, 10.0],   # 10 m up a straight 17 m face (from the west), a flat top, 40 m down the back
	["bog", Vector2(-160.0, 166.0), 19.0, 9.5, 0.0, 0.42],
	["sand", Vector2(-196.0, 146.0), 9.0, 6.0, 0.7, 0.2],
	["sand", Vector2(-214.0, 128.0), 8.0, 5.5, 0.6, 0.2],
	["sand", Vector2(-232.0, 116.0), 7.0, 5.0, 0.5, 0.2],
]
const HILL_BACK := 40.0      # the hill's gentler back slope (m from the top)
const LIP_R := 2.5          # m the face rounds over at the lip (a sharp lip high-centres anything at a crawl)
const FOOT_R := 1.5         # and rounds in at its foot
const HILL_TOP := 3.0        # half the flat top's length: the face ends in a lip you can fly off
const DAM_DEEP := 0.6        # the dam's crossing (on the track) at its deepest
const DAM_HOLE := 1.25       # and off the track, where it drowns a stock ute
const FORD_DEEP := 0.38      # the causeways under the creek's water
## Two more on the tracks: a run of moguls that twists a ute corner to corner
## (a wheel in each axle in the air: the rear locker's job), and a bank faced
## with logs, a step up higher than a stock Hilux's front bumper clears (a
## lift kit's job, or the Ranger's and Shark's steeper noses) and a step down
## the far side that drags a long tail (the Shark's).
## [kind, centre, half length, half width, yaw, height]
const OBSTACLES := [
	["moguls", Vector2(-355.0, 47.0), 14.0, 3.6, 0.119, 0.7],
	["logs", Vector2(-85.0, 180.6), 4.0, 3.0, -2.968, 0.6],
]
const MOGUL_WAVE := 6.2      # m from hump to hump along the track: twice a wheelbase, so it twists
## Where the challenges count as done
const CHALLENGES := {"bog": "The Bog", "dam": "The Dam", "hill": "Hill Climb", "sand": "Sand Traps",
	"moguls": "Moguls", "logs": "Log Step"}
## Times for gold and silver (s), and what gold also needs: the hard line
const MEDALS := {
	"hill": [14.0, 22.0, "up the face with all four on the ground"], "bog": [7.0, 11.0, "through the deep middle"],
	"dam": [14.0, 22.0, "across the deep end"], "sand": [7.0, 11.0, "without stopping"],
	"moguls": [10.0, 18.0, "without stopping"], "logs": [5.0, 9.0, "without the bumper digging in"],
}

const MUD := Color("5b4530")
const DIRT := Color("8a6a48")
const RUT := Color("5e4632")
const SAND := Color("e2d2a0")
const GREEN := Color("7fae58")

var box := Rect2()           # the park's bounds (anything outside's plain ground)
var tracks: Array = []       # PackedVector2Array, the way-ins first
var dam: PackedVector2Array  # the golf lake the dam loop wades across
var _feat: Array = []        # FEATURES as dicts
var _obs: Array = []         # OBSTACLES as dicts
var boards: Array = []       # the records boards by the gates (Label3D)
var _fords: Array = []       # {c, along (unit, the track's way), across, hl, hw}
var _tgrid := {}             # 10 m cell -> [track index, segment index]
var _mud_mat: StandardMaterial3D
var air_posts: Array = []    # where the FREE AIR posts stand, by each way in

func build(d: Dictionary) -> void:
	for k in WAY_IN:
		tracks.append(PackedVector2Array(WAY_IN[k]))
	for t in TRACKS:
		tracks.append(PackedVector2Array(t))
	for f in FEATURES:
		_feat.append({"kind": f[0], "c": f[1], "a": f[2], "b": f[3], "yaw": f[4], "size": f[5]})
	for f in OBSTACLES:
		_obs.append({"kind": f[0], "c": f[1], "a": f[2], "b": f[3], "yaw": f[4], "size": f[5]})
	for a in d.get("areas", []):
		if a["kind"] == "golf_water":
			var poly := Surrounds._v2(a["pts"])
			if Geometry2D.is_point_in_polygon(Vector2(-90.0, 265.0), poly):
				dam = poly
	# where the tracks cross the creek, a causeway
	for dr in d.get("drains", []):
		var line := Surrounds._v2(dr["pts"])
		for t in tracks:
			for i in t.size() - 1:
				for j in line.size() - 1:
					var x = Geometry2D.segment_intersects_segment(t[i], t[i + 1], line[j], line[j + 1])
					if x != null:
						var along: Vector2 = (t[i + 1] - t[i]).normalized()
						var across: Vector2 = (line[j + 1] - line[j]).normalized()
						var w := float(dr.get("w", 6.0))
						# (the creek runs `across`; its shallows reach `hw` either side
						# of its middle, for `hl` up and down from the crossing)
						_fords.append({"c": x, "along": along, "across": across, "perp": across.orthogonal(),
							"hl": 30.0, "hw": w * 0.5 + 1.2, "w": w})
	box = Rect2(tracks[0][0], Vector2.ZERO)
	for t in tracks:
		for q in t:
			box = box.expand(q)
	box = box.grow(30.0)
	for ti in tracks.size():
		var t: PackedVector2Array = tracks[ti]
		for i in t.size() - 1:
			var n := maxi(1, ceili(t[i].distance_to(t[i + 1]) / 5.0))
			var seen := {}
			for k in n + 1:
				var q := t[i].lerp(t[i + 1], float(k) / n)
				for dx in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						var cell := Vector2i(floori(q.x / 10.0) + dx, floori(q.y / 10.0) + dz)
						if seen.has(cell):
							continue
						seen[cell] = true
						if not _tgrid.has(cell):
							_tgrid[cell] = []
						_tgrid[cell].append([ti, i])
	_build_hill()
	_build_pits()
	_build_fords()
	_build_air()
	_build_obstacles()
	_build_tracks()
	_build_road_mud()
	_build_signs()
	_build_golf()

# ------------------------------------------------------------------ the ground

## The local frame of a feature: (along its long axis, across it)
static func _local(f: Dictionary, p: Vector2) -> Vector2:
	var r := p - (f["c"] as Vector2)
	var yaw: float = f["yaw"]
	var ax := Vector2(cos(yaw), sin(yaw))
	return Vector2(r.dot(ax), r.dot(Vector2(-ax.y, ax.x)))

## 0 at the edge of a feature's ellipse, 1 in its middle (and < 0 outside).
static func _inside(f: Dictionary, p: Vector2) -> float:
	var l := _local(f, p)
	var a: float = f["a"]
	if f["kind"] == "hill":
		a = (HILL_BACK if l.x < 0.0 else a) + HILL_TOP
	var r2 := (l.x / a) * (l.x / a) + (l.y / float(f["b"])) * (l.y / float(f["b"]))
	return 1.0 - r2

## The ground under `p`: what a wheel or a boot stands on.
func height(p: Vector2) -> float:
	if not box.has_point(p):
		return 0.0
	var h := 0.0
	for f in _feat:
		var u := _inside(f, p)
		if u <= 0.0:
			continue
		match f["kind"]:
			"hill":
				# a straight face up to a lip, the flat top, a rounded back;
				# steep falling away either side
				var l := _local(f, p)
				var along := 1.0
				if l.x > HILL_TOP:
					# (the face: rounded over at the lip and in at the foot, so a
					# crawl can make it over; straight between)
					var a: float = f["a"]
					var dn := l.x - HILL_TOP
					var k := 1.0 / (a - LIP_R * 0.5 - FOOT_R * 0.5)
					if dn < LIP_R:
						along = 1.0 - k * dn * dn / (2.0 * LIP_R)
					elif dn < a - FOOT_R:
						along = 1.0 - k * (dn - LIP_R * 0.5)
					else:
						along = k * maxf(0.0, a - dn) * maxf(0.0, a - dn) / (2.0 * FOOT_R)
				elif l.x < -HILL_TOP:
					var q := clampf((-l.x - HILL_TOP) / HILL_BACK, 0.0, 1.0)
					along = (1.0 - q * q) * (1.0 - q * q)
				var b: float = f["b"]
				h += float(f["size"]) * along * smoothstep(b, b * 0.45, absf(l.y))
			"bog", "sand":
				h -= float(f["size"]) * smoothstep(0.0, 0.5, u)
	for o in _obs:
		h += _obstacle(o, p)
	var fd := _ford(p)
	if fd >= 0.0:
		h -= fd
	elif not dam.is_empty() and Geometry2D.is_point_in_polygon(p, dam):
		h -= minf(DAM_DEEP if on_track(p, TRACK_W * 0.5 + 1.0) else DAM_HOLE, _edge(p, dam) * 0.22)
	return h

## How much an obstacle stands up at `p`.
static func _obstacle(o: Dictionary, p: Vector2) -> float:
	var l := _local(o, p)
	var a: float = o["a"]
	var b: float = o["b"]
	if absf(l.x) > a or absf(l.y) > b:
		return 0.0
	var hgt: float = o["size"]
	if o["kind"] == "logs":
		# (a flat top, the logs' faces rounded off each end like the logs they are)
		var e := absf(l.x) - (a - 0.35)
		return hgt * (sqrt(maxf(0.0, 1.0 - e * e / (0.35 * 0.35))) if e > 0.0 else 1.0)
	# moguls: humps left and right in turn, faded in at each end and the sides
	var fade := smoothstep(a, a - 2.5, absf(l.x)) * smoothstep(b, b - 1.0, absf(l.y))
	return hgt * 0.5 * (1.0 + sin(l.x * TAU / MOGUL_WAVE) * sin(l.y * PI / 1.6)) * fade

## How deep a causeway's water is at `p` (-1 off them).
func _ford(p: Vector2) -> float:
	for fd in _fords:
		var r: Vector2 = p - (fd["c"] as Vector2)
		var a := absf(r.dot(fd["perp"]))
		var c := absf(r.dot(fd["across"]))
		if c < float(fd["hl"]) and a < float(fd["hw"]):
			# (down the bank into it and up the other side)
			return FORD_DEEP * smoothstep(float(fd["hw"]), float(fd["hw"]) - 2.0, a)
	return -1.0

static func _edge(p: Vector2, poly: PackedVector2Array) -> float:
	var best := 99.0
	for i in poly.size():
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()]).distance_to(p))
	return best

## The water's surface at `p` (on the causeways and in the dam), or -99.
func water(p: Vector2) -> float:
	if not box.has_point(p):
		return -99.0
	if _ford(p) > 0.02:
		return 0.035
	if not dam.is_empty() and Geometry2D.is_point_in_polygon(p, dam):
		return 0.0
	return -99.0

## What the ground's made of: "mud", "sand", "water", "dirt" (the tracks),
## "grass" (the rest of the course), or "" off the park.
func surface(p: Vector2) -> String:
	if not box.has_point(p):
		return ""
	if water(p) > -90.0 and height(p) < -0.1:
		return "water"
	for f in _feat:
		if f["kind"] != "hill" and _inside(f, p) > 0.0:
			return "mud" if f["kind"] == "bog" else "sand"
	for o in _obs:
		var l := _local(o, p)
		if absf(l.x) < float(o["a"]) and absf(l.y) < float(o["b"]):
			return "dirt"
	if on_track(p, TRACK_W * 0.5):
		return "dirt"
	return "grass"

## The challenge `p`'s in, if any ("bog", "dam", "hill", "sand").
func challenge(p: Vector2) -> String:
	if not box.has_point(p):
		return ""
	for f in _feat:
		if _inside(f, p) > 0.0:
			return f["kind"]
	for o in _obs:
		var l := _local(o, p)
		# (the run-up and run-out count too)
		if absf(l.x) < float(o["a"]) + 2.0 and absf(l.y) < float(o["b"]):
			return o["kind"]
	if not dam.is_empty() and Geometry2D.is_point_in_polygon(p, dam):
		return "dam"
	return ""

## The middle of a challenge.
func centre(ch: String) -> Vector2:
	if ch == "dam" and not dam.is_empty():
		var m := Vector2.ZERO
		for q in dam:
			m += q
		return m / dam.size()
	for f in _feat + _obs:
		if f["kind"] == ch:
			return f["c"]
	return Vector2.ZERO

## Where a run at `ch` comes in from: true for the hard way in (the hill's
## steep face, rather than up its back).
func hard_way(ch: String, from: Vector2) -> bool:
	if ch == "hill":
		return _local(_feat[0], from).x > 0.0
	return true

func on_track(p: Vector2, w: float) -> bool:
	for ts in _tgrid.get(Vector2i(floori(p.x / 10.0), floori(p.y / 10.0)), []):
		var t: PackedVector2Array = tracks[ts[0]]
		if Geometry2D.get_closest_point_to_segment(p, t[ts[1]], t[ts[1] + 1]).distance_to(p) < w:
			return true
	return false

## Near enough a FREE AIR post to pump the tyres up.
func air_near(p: Vector2) -> bool:
	for a in air_posts:
		if (a as Vector2).distance_to(p) < 8.0:
			return true
	return false

## A FREE AIR post just in off the road at each way in: a compressor box on a
## pole, the hose coiled on it, a sign (props.glb "AirPost").
func _build_air() -> void:
	for k in WAY_IN:
		var w: Array = WAY_IN[k]
		var a: Vector2 = w[0]
		var dir: Vector2 = (w[1] - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var at: Vector2 = a + dir * 13.0 + side * (TRACK_W * 0.5 + 1.6)
		air_posts.append(at)
		var post := F.prop("AirPost")
		post.name = "AirPost"
		post.position = Vector3(at.x, height(at), at.y)
		# (dial to the track)
		post.rotation.y = atan2(-side.x, -side.y)
		add_child(post)

## The moguls' churned dirt and the log step's logs, and a records board by
## each FREE AIR post.
func _build_obstacles() -> void:
	for o in _obs:
		var c: Vector2 = o["c"]
		var a: float = o["a"]
		var b: float = o["b"]
		var yaw: float = o["yaw"]
		var ax := Vector2(cos(yaw), sin(yaw))
		var side := Vector2(-ax.y, ax.x)
		if true:
			var r := Rect2(c, Vector2.ZERO)
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					r = r.expand(c + ax * a * sx + side * b * sy)
			var mi := _grid_mesh(r, 0.5, func(p: Vector2) -> Array:
				var l := _local(o, p)
				if absf(l.x) > a + 0.5 or absf(l.y) > b + 0.5:
					return []
				var h := height(p)
				return [h + 0.03, DIRT.lerp(RUT, clampf(1.0 - h / float(o["size"]), 0.0, 1.0) * 0.6), 5])
			mi.name = "Moguls" if o["kind"] == "moguls" else "LogStep"
			if o["kind"] == "moguls":
				continue
		# logs: two layers stacked across the track at each face
		var bark := F.color_mat(Color("6b4a2f"))
		var ends := F.color_mat(Color("c9a46b"))
		var hgt: float = o["size"]
		var rad := hgt * 0.27
		var layers := []
		for sd: float in [-1.0, 1.0]:
			var x0 := sd * (a - rad * 0.5)
			layers.append_array([[x0, 0.0], [x0 - sd * rad * 2.0, 0.0], [x0 - sd * rad, 1.0]])
		for lg in layers:
			var m := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = rad * randf_range(0.92, 1.08)
			cm.bottom_radius = cm.top_radius
			cm.height = b * 2.0 + randf_range(-0.3, 0.3)
			cm.radial_segments = 10
			m.mesh = cm
			m.material_override = bark
			var at: Vector2 = c + ax * float(lg[0])
			m.position = Vector3(at.x, rad + float(lg[1]) * (hgt - rad * 2.0) * 0.95, at.y)
			m.basis = Basis(Vector3.UP, atan2(side.x, side.y)) * Basis(Vector3.RIGHT, PI * 0.5)
			add_child(m)
			# (the sawn ends)
			for sd: float in [-1.0, 1.0]:
				var e := MeshInstance3D.new()
				var em := CylinderMesh.new()
				em.top_radius = cm.top_radius * 0.96
				em.bottom_radius = em.top_radius
				em.height = 0.02
				e.mesh = em
				e.material_override = ends
				e.position = Vector3(0, cm.height * 0.5 * sd, 0)
				m.add_child(e)
	# the records boards
	for i in air_posts.size():
		var at: Vector2 = air_posts[i]
		var w: Array = WAY_IN.values()[i]
		var dir: Vector2 = (w[1] - w[0]).normalized()
		var spot: Vector2 = at + dir * 3.5
		var bd := Node3D.new()
		bd.name = "Records"
		bd.position = Vector3(spot.x, height(spot), spot.y)
		bd.rotation.y = atan2(-dir.x, -dir.y)
		add_child(bd)
		for sx: float in [-0.9, 0.9]:
			bd.add_child(F.box(Vector3(0.1, 2.4, 0.1), F.color_mat(Color("6b4a2f")), Vector3(sx, 1.2, 0)))
		bd.add_child(F.box(Vector3(2.1, 1.25, 0.06), F.color_mat(Color("23402c")), Vector3(0, 1.75, 0)))
		var l := Label3D.new()
		l.font_size = 30
		l.pixel_size = 0.0045
		l.outline_size = 0
		l.modulate = Color("f4f2ea")
		l.width = 440.0
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.position = Vector3(0, 1.75, 0.04)
		l.text = "4x4 PARK RECORDS"
		bd.add_child(l)
		boards.append(l)

## Which way's up off the ground at `p`.
func normal(p: Vector2) -> Vector3:
	if not box.has_point(p):
		return Vector3.UP
	var e := 0.6
	var hx := height(p + Vector2(e, 0)) - height(p - Vector2(e, 0))
	var hz := height(p + Vector2(0, e)) - height(p - Vector2(0, e))
	return Vector3(-hx, 2.0 * e, -hz).normalized()

## Trees that would be standing on a track or in a challenge come out (crash.gd).
func clear_trees(crash) -> void:
	for it in crash._items:
		if it["down"] or not box.has_point(it["p"]):
			continue
		var p: Vector2 = it["p"]
		var gone := on_track(p, TRACK_W * 0.5 + 2.0) or challenge(p) in ["hill", "bog", "sand"] or _ford(p) >= 0.0
		if gone:
			it["down"] = true
			crash.stow(it)

# ------------------------------------------------------------------ the look

## A grid of ground over `rect`, `fn` giving each corner [height, colour,
## surface code] (or [] to leave that square out).
func _grid_mesh(rect: Rect2, step: float, fn: Callable) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := ceili(rect.size.x / step)
	var nz := ceili(rect.size.y / step)
	var pts := {}
	for i in nx + 1:
		for j in nz + 1:
			var p := rect.position + Vector2(i * step, j * step)
			pts[Vector2i(i, j)] = fn.call(p)
	for i in nx:
		for j in nz:
			var q: Array = [pts[Vector2i(i, j)], pts[Vector2i(i + 1, j)], pts[Vector2i(i + 1, j + 1)], pts[Vector2i(i, j + 1)]]
			if q.any(func(v: Array) -> bool: return v.is_empty()):
				continue
			var ps: Array = [rect.position + Vector2(i * step, j * step), rect.position + Vector2((i + 1) * step, j * step),
				rect.position + Vector2((i + 1) * step, (j + 1) * step), rect.position + Vector2(i * step, (j + 1) * step)]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for k in tri:
					var v: Array = q[k]
					var p: Vector2 = ps[k]
					st.set_color(v[1])
					st.set_uv(Vector2(float(v[2]), 0))
					st.set_normal(normal(p))
					st.add_vertex(Vector3(p.x, v[0], p.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Surrounds.ground_mat()
	add_child(mi)
	return mi

func _rect_of(f: Dictionary, pad: float) -> Rect2:
	var r := maxf(float(f["a"]), float(f["b"])) + pad
	if f["kind"] == "hill":
		r = maxf(r, HILL_BACK + pad)
	return Rect2((f["c"] as Vector2) - Vector2(r, r), Vector2(r, r) * 2.0)

func _build_hill() -> void:
	for f in _feat:
		if f["kind"] != "hill":
			continue
		var top: float = f["size"]
		var mi := _grid_mesh(_rect_of(f, 1.0), 2.0, func(p: Vector2) -> Array:
			var u := _inside(f, p)
			if u <= -0.08:
				return []
			var h := height(p)
			var n := normal(p)
			# (worn to dirt where it's steepest and along the climb)
			var bare := clampf((1.0 - n.y) * 4.0, 0.0, 0.55)
			var col := GREEN.lerp(DIRT, bare).darkened(0.06 * clampf(h / top, 0.0, 1.0))
			return [maxf(h, 0.0) + 0.02, col, 5 if bare > 0.4 else 2])
		mi.name = "HillClimb"

## The bog and the sand traps: churned mud with puddles, and raked sand.
func _build_pits() -> void:
	for f in _feat:
		if f["kind"] == "hill":
			continue
		var mud: bool = f["kind"] == "bog"
		var mi := _grid_mesh(_rect_of(f, 2.5), 1.0, func(p: Vector2) -> Array:
			var u := _inside(f, p)
			if u <= -0.35:
				return []
			if u <= 0.0:
				# (a lip of churned dirt round it, sloping back down to the grass)
				var k := clampf(-u / 0.35, 0.0, 1.0)
				return [0.12 * (1.0 - k) + 0.01, (DIRT if mud else SAND.darkened(0.06)).lerp(GREEN, k * k), 5 if mud else 4]
			# (the visible top: the wheels sink below it)
			var wobble := sin(p.x * 1.7) * cos(p.y * 1.3) * 0.03
			var col := MUD if mud else SAND
			if mud and sin(p.x * 0.45 + p.y * 0.3) * cos(p.y * 0.55) > 0.55:
				col = Color("4a4f4c")   # (puddles)
			return [0.06 + wobble, col.darkened(0.08 * u), 5 if mud else 4])
		mi.name = "Bog" if mud else "SandTrap"

## The creek crossings: a stretch of creek water with muddy banks,
## and a depth post either side of the track.
func _build_fords() -> void:
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.30, 0.42, 0.44, 0.9)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.12
	wm.metallic_specular = 0.8
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bank := SurfaceTool.new()
	bank.begin(Mesh.PRIMITIVE_TRIANGLES)
	for fd in _fords:
		var c: Vector2 = fd["c"]
		var across: Vector2 = fd["across"]
		var perp: Vector2 = fd["perp"]
		var hl: float = fd["hl"]
		var hw: float = fd["hw"]
		# the creek's water over its stretch either side of the crossing
		var ww := hw - 0.9
		_quad(st, c, across * hl, perp * ww, 0.035, Color.WHITE, -1)
		# and muddy banks either side, churned where the track crosses
		for sd: float in [-1.0, 1.0]:
			_quad(bank, c + perp * sd * (ww + 0.7), across * hl, perp * 0.75, 0.03, Color("6e5a42"), 5)
		for sd: float in [-1.0, 1.0]:
			var along: Vector2 = fd["along"]
			_depth_post(c + perp * sd * (hw + 0.4) + along.orthogonal() * (TRACK_W * 0.5 + 0.7), "%.1f" % FORD_DEEP)
	var w := MeshInstance3D.new()
	w.name = "Creek"
	w.mesh = st.commit()
	w.material_override = wm
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(w)
	var bk := MeshInstance3D.new()
	bk.mesh = bank.commit()
	bk.material_override = Surrounds.ground_mat()
	bk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bk)
	# and a post at the dam crossing
	if not dam.is_empty():
		_depth_post(Vector2(-63.0, 271.0), "%.1f" % DAM_DEEP)
		_depth_post(Vector2(-127.0, 258.0), "%.1f" % DAM_DEEP)

## A flat rectangle at `y`: centre `c`, half sides `u` and `v`.
static func _quad(st: SurfaceTool, c: Vector2, u: Vector2, v: Vector2, y: float, col: Color, code: int) -> void:
	var q := [c - u - v, c + u - v, c + u + v, c - u + v]
	for k in [0, 1, 2, 0, 2, 3]:
		var p: Vector2 = q[k]
		st.set_color(col)
		if code >= 0:
			st.set_uv(Vector2(code, 0))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(p.x, y, p.y))

## A white post banded red each 0.2 m, with the depth on a tag.
func _depth_post(at: Vector2, tag: String) -> void:
	var post := Node3D.new()
	post.position = Vector3(at.x, height(at), at.y)
	add_child(post)
	for k in 6:
		post.add_child(F.box(Vector3(0.1, 0.2, 0.1), F.color_mat(Color("f2f0ea") if k % 2 == 0 else Color("d33a2c")),
			Vector3(0, 0.1 + k * 0.2, 0)))
	var l := Label3D.new()
	l.text = tag + " m"
	l.font_size = 40
	l.pixel_size = 0.005
	l.outline_size = 8
	l.modulate = Color("ffe08a")
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position.y = 1.5
	post.add_child(l)

## The dirt tracks: a worn strip with two muddy wheel ruts down it.
func _build_tracks() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ti in tracks.size():
		var t: PackedVector2Array = tracks[ti].duplicate()
		if ti < WAY_IN.size():
			# (the ways in start off the road's edge, not on the bitumen)
			t[0] = t[0] + (t[1] - t[0]).normalized() * 4.5
		var pts := PackedVector2Array()
		for i in t.size() - 1:
			var n := maxi(1, ceili(t[i].distance_to(t[i + 1]) / 1.0))
			for k in n:
				pts.append(t[i].lerp(t[i + 1], float(k) / n))
		pts.append(t[t.size() - 1])
		for strip in [[0.0, TRACK_W * 0.5, DIRT, 0.05], [-0.85, 0.26, RUT, 0.07], [0.85, 0.26, RUT, 0.07]]:
			for i in pts.size() - 1:
				var a := pts[i]
				var b := pts[i + 1]
				if _ford(a) >= 0.0 and _ford(b) >= 0.0:
					continue
				# (no track through the bog, the sand or the dam: it's churned up, or under water)
				if _pit(a) or _pit(b) or _on_logs(a) or _on_logs(b):
					continue
				var dir := (b - a).normalized()
				var side := Vector2(-dir.y, dir.x)
				var off: float = strip[0]
				var hw: float = strip[1]
				var lift: float = strip[3]
				var quad := [a + side * (off - hw), a + side * (off + hw), b + side * (off + hw), b + side * (off - hw)]
				var ys := []
				for q in quad:
					ys.append(_top(q) + lift)
				var col: Color = strip[2]
				col = col.darkened(randf() * 0.06)
				for k in [0, 1, 2, 0, 2, 3]:
					var q: Vector2 = quad[k]
					st.set_color(col)
					st.set_uv(Vector2(5, 0))
					st.set_normal(normal(q))
					st.add_vertex(Vector3(q.x, ys[k], q.y))
	var mi := MeshInstance3D.new()
	mi.name = "Tracks"
	mi.mesh = st.commit()
	mi.material_override = Surrounds.ground_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _on_logs(p: Vector2) -> bool:
	for o in _obs:
		if o["kind"] == "logs":
			var l := _local(o, p)
			if absf(l.x) < float(o["a"]) + 0.2 and absf(l.y) < float(o["b"]) + 0.5:
				return true
	return false

func _pit(p: Vector2) -> bool:
	if not dam.is_empty() and Geometry2D.is_point_in_polygon(p, dam):
		return true
	for f in _feat:
		if f["kind"] != "hill" and _inside(f, p) > -0.1:
			return true
	return false

## What you see at `p`: the hill's grass, the pits' tops, the causeway's bed
## (the dam's water hides what's under it).
func _top(p: Vector2) -> float:
	var h := height(p)
	for f in _feat:
		if f["kind"] != "hill" and _inside(f, p) > -0.35:
			return maxf(h, 0.06)
	if _ford(p) >= 0.0:
		return h
	return maxf(h, 0.0)

## Mud tracked out onto the road where each way in comes out: tyre marks
## curling off the dirt and fading along the kerb lane both ways.
func _build_road_mud() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4044
	for k in WAY_IN:
		var t: PackedVector2Array = PackedVector2Array(WAY_IN[k])
		var mouth := t[0]
		var out := (t[0] - t[1]).normalized()
		# (the road runs across the track's mouth)
		var road := Vector2(-out.y, out.x)
		for m in 7:
			var turn := 1.0 if m % 2 == 0 else -1.0
			var lane := rng.randf_range(-1.6, 1.6)
			var reach := rng.randf_range(9.0, 22.0)
			for wheel: float in [-0.85, 0.85]:
				var prev := Vector2.INF
				var n := 24
				for i in n + 1:
					var u := float(i) / n
					# out of the track, turning into the lane and along it
					var bend := smoothstep(0.0, 0.45, u)
					var p := mouth + out * (2.5 + 3.5 * bend + lane * 0.3) + road * turn * u * reach \
						+ (out.rotated(PI * 0.5) * wheel * (1.0 - bend) + out * wheel * bend * turn)
					if prev != Vector2.INF:
						var dir := (p - prev).normalized()
						var side := Vector2(-dir.y, dir.x) * 0.14
						var a := 0.75 * (1.0 - u) * (1.0 - u)
						var col := Color(0.30, 0.22, 0.14, a)
						var quad := [prev - side, prev + side, p + side, p - side]
						for q_i in [0, 1, 2, 0, 2, 3]:
							var q: Vector2 = quad[q_i]
							st.set_color(col)
							st.set_normal(Vector3.UP)
							st.add_vertex(Vector3(q.x, 0.035, q.y))
					prev = p
		# and a skin of mud on the kerb and footpath where they come out
		for i in 10:
			var p := mouth + out * rng.randf_range(0.5, 4.5) + road * rng.randf_range(-2.5, 2.5)
			var r := rng.randf_range(0.4, 1.2)
			for s in 8:
				var a0 := TAU * s / 8.0
				var a1 := TAU * (s + 1) / 8.0
				st.set_color(Color(0.33, 0.25, 0.16, 0.6))
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(p.x, 0.04, p.y))
				st.add_vertex(Vector3(p.x + cos(a0) * r, 0.04, p.y + sin(a0) * r))
				st.add_vertex(Vector3(p.x + cos(a1) * r, 0.04, p.y + sin(a1) * r))
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.95
	var mi := MeshInstance3D.new()
	mi.name = "RoadMud"
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

## The club's sign at each way in (with somebody's addition), and a timber
## sign at each challenge.
func _build_signs() -> void:
	for k in WAY_IN:
		var t: PackedVector2Array = PackedVector2Array(WAY_IN[k])
		# on the course side of the creek, beside the track, facing you as you come in
		var i := t.size() - 2
		var dir := (t[i + 1] - t[i]).normalized()
		var at := t[i] + dir * 4.0 + Vector2(-dir.y, dir.x) * (TRACK_W * 0.5 + 1.8)
		_club_sign(at, atan2(-dir.x, -dir.y))
	var names := {"bog": "THE BOG", "hill": "HILL CLIMB", "sand": "SAND TRAPS", "moguls": "MOGULS", "logs": "LOG STEP"}
	var signed := {}
	for f in _feat:
		if signed.has(f["kind"]):
			continue
		signed[f["kind"]] = true
		var c: Vector2 = f["c"]
		var a: float = f["a"]
		var ax := Vector2(cos(float(f["yaw"])), sin(float(f["yaw"])))
		var at := c + ax * (a + 5.0) + Vector2(-ax.y, ax.x) * (float(f["b"]) * 0.6 + 3.0)
		_timber_sign(at, atan2(ax.x, ax.y), names[f["kind"]], f["kind"] == "hill")
	for o in _obs:
		var c: Vector2 = o["c"]
		var ax := Vector2(cos(float(o["yaw"])), sin(float(o["yaw"])))
		var at := c - ax * (float(o["a"]) + 4.0) + Vector2(-ax.y, ax.x) * (float(o["b"]) + 1.5)
		_timber_sign(at, atan2(-ax.x, -ax.y), names[o["kind"]], o["kind"] == "logs")
	if not dam.is_empty():
		_timber_sign(Vector2(-57.0, 262.0), atan2(-1.0, 0.0), "THE DAM", false)

func _club_sign(at: Vector2, yaw: float) -> void:
	var s := Node3D.new()
	s.name = "NoFourByFour"
	s.position = Vector3(at.x, 0, at.y)
	s.rotation.y = yaw
	add_child(s)
	var white := F.color_mat(Color("f4f2ea"))
	var green := F.color_mat(Color("1f4a2e"))
	var gold := F.color_mat(Color("c9a646"))
	for sx: float in [-0.85, 0.85]:
		s.add_child(F.box(Vector3(0.12, 2.3, 0.12), white, Vector3(sx, 1.15, 0)))
	s.add_child(F.box(Vector3(2.0, 1.3, 0.08), gold, Vector3(0, 1.75, 0)))
	s.add_child(F.box(Vector3(1.88, 1.18, 0.1), green, Vector3(0, 1.75, 0)))
	# (a little crown and pennant up top, like the club's own)
	s.add_child(F.box(Vector3(0.5, 0.16, 0.08), gold, Vector3(0, 2.48, 0)))
	var lines := [["ROYAL QUEENSLAND GOLF CLUB", 22, Color("e3c766"), 2.22], ["NO 4x4", 64, Color("f4f2ea"), 1.82],
		["on the course · members' carts only", 18, Color("e3e8df"), 1.38]]
	for ln in lines:
		var l := Label3D.new()
		l.text = ln[0]
		l.font_size = ln[1]
		l.pixel_size = 0.0045
		l.outline_size = 0
		l.modulate = ln[2]
		l.position = Vector3(0, ln[3], 0.06)
		l.shaded = false
		l.double_sided = false
		s.add_child(l)
	# somebody's had a go with a can of spray paint
	var ish := Label3D.new()
	ish.text = "...ish"
	ish.font_size = 52
	ish.pixel_size = 0.0045
	ish.outline_size = 0
	ish.modulate = Color("e03526")
	ish.position = Vector3(0.62, 1.6, 0.065)
	ish.rotation.z = 0.22
	ish.shaded = false
	ish.double_sided = false
	s.add_child(ish)
	# (and on the back, for the way out)
	var bk := Label3D.new()
	bk.text = "Please repair your divots"
	bk.font_size = 30
	bk.pixel_size = 0.0045
	bk.outline_size = 0
	bk.modulate = Color("f4f2ea")
	bk.position = Vector3(0, 1.75, -0.06)
	bk.rotation.y = PI
	bk.shaded = false
	bk.double_sided = false
	s.add_child(bk)
	# and a muddy tyre's gone up the side of a post
	var mud := F.color_mat(Color("4e3a28"))
	for k in 4:
		s.add_child(F.box(Vector3(0.13, 0.12, 0.13), mud, Vector3(-0.85, 0.15 + k * 0.22, 0)))

func _timber_sign(at: Vector2, yaw: float, text: String, steep: bool) -> void:
	var s := Node3D.new()
	s.position = Vector3(at.x, height(at), at.y)
	s.rotation.y = yaw
	add_child(s)
	var wood := F.color_mat(Color("8a6440"))
	var board := F.color_mat(Color("b88a58"))
	for sx: float in [-0.75, 0.75]:
		s.add_child(F.box(Vector3(0.16, 1.9, 0.16), wood, Vector3(sx, 0.95, 0)))
	s.add_child(F.box(Vector3(1.9, 0.62, 0.1), board, Vector3(0, 1.55, 0)))
	var l := Label3D.new()
	l.text = text
	l.font_size = 56
	l.pixel_size = 0.0045
	l.outline_size = 0
	l.modulate = Color("2c1d10")
	l.position = Vector3(0, 1.57, 0.06)
	l.shaded = false
	s.add_child(l)
	var back := l.duplicate() as Label3D
	back.position.z = -0.06
	back.rotation.y = PI
	s.add_child(back)
	if steep:
		var w := Label3D.new()
		w.text = "Low range. Keep it straight."
		w.font_size = 26
		w.pixel_size = 0.0045
		w.outline_size = 0
		w.modulate = Color("2c1d10")
		w.position = Vector3(0, 1.32, 0.06)
		w.shaded = false
		s.add_child(w)

## Still a golf course: a couple of greens with their flags, tee blocks,
## and the yardage posts.
func _build_golf() -> void:
	var greens := [[Vector2(-115.0, 210.0), 8.0, "7"], [Vector2(-300.0, 125.0), 9.0, "8"], [Vector2(-255.0, 160.0), 7.0, "12"]]
	for g in greens:
		var c: Vector2 = g[0]
		var r: float = g[1]
		_grid_mesh(Rect2(c - Vector2(r + 1.0, r + 1.0), Vector2(r + 1.0, r + 1.0) * 2.0), 1.0, func(p: Vector2) -> Array:
			var d := p.distance_to(c) / r
			if d > 1.08:
				return []
			return [0.025, Color("9ed36a") if d < 1.0 else Color("86bb5a"), 2])
		var flag := Node3D.new()
		flag.position = Vector3(c.x + r * 0.2, 0, c.y - r * 0.15)
		add_child(flag)
		flag.add_child(F.box(Vector3(0.04, 2.2, 0.04), F.color_mat(Color("f2f0ea")), Vector3(0, 1.1, 0)))
		flag.add_child(F.box(Vector3(0.6, 0.4, 0.02), F.color_mat(Color("e23b2e")), Vector3(0.3, 1.95, 0)))
		var l := Label3D.new()
		l.text = g[2]
		l.font_size = 40
		l.pixel_size = 0.005
		l.outline_size = 0
		l.modulate = Color.WHITE
		l.position = Vector3(0.3, 1.95, 0.02)
		l.shaded = false
		flag.add_child(l)
		# the tees, back down the fairway
		var tee := c + Vector2(0, -60.0).rotated(float(g[1]))
		if on_track(tee, 6.0) or challenge(tee) != "":
			continue
		for sx: float in [-1.5, 1.5]:
			add_child(F.box(Vector3(0.3, 0.3, 0.3), F.color_mat(Color("f4f2ea")), Vector3(tee.x + sx, 0.15, tee.y)))

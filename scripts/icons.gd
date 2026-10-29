## A simple white icon for each job, drawn in code, tinted wherever it's used
## (hard hats, hand signs, the job list, close-up tabs, menus, the phone), so a
## job is never told apart by colour alone.
##   boom    the placing boom: two arm sections and a hanging hose
##   line    a concrete truck: cab, drum, wheels (the truck hand)
##   pump    a pressure gauge: dial, ticks and a needle up in the red
##   poker   a poker: a rod with vibration waves either side
##   screed  a screed board: a long bar with two handles
##   hose    the rubber end hose: a curving hose, its nozzle and drops
##   beer    a schooner with a head on it: knocking off
extends RefCounted

const ROLES := ["boom", "line", "pump", "poker", "screed", "hose"]   # (and "beer", not a job)
static var _cache := {}

static func texture(role: String, size := 128) -> ImageTexture:
	var key := "%s%d" % [role, size]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var s := size / 128.0
	for y in size:
		for x in size:
			var p := Vector2(x, y) / s
			var d := _sdf(role, p)
			var a := clampf(0.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

## Glyph with a dark outline, for icons drawn over busy backgrounds.
static func outlined(role: String, size := 128) -> ImageTexture:
	var key := "o%s%d" % [role, size]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var s := size / 128.0
	for y in size:
		for x in size:
			var p := Vector2(x, y) / s
			var d := _sdf(role, p)
			var fill := clampf(0.5 - d, 0.0, 1.0)
			var edge := clampf(0.5 - (d - 6.0), 0.0, 1.0)
			var c := Color(0.06, 0.08, 0.12, edge).lerp(Color(1, 1, 1, edge), fill)
			img.set_pixel(x, y, c)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

static func _seg(p: Vector2, a: Vector2, b: Vector2, r: float) -> float:
	var pa := p - a
	var ba := b - a
	var h := clampf(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	return (pa - ba * h).length() - r

static func _box(p: Vector2, c: Vector2, half: Vector2, r := 4.0) -> float:
	var q := (p - c).abs() - half + Vector2(r, r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r

static func _sdf(role: String, p: Vector2) -> float:
	match role:
		"boom":
			var d := _seg(p, Vector2(18, 110), Vector2(52, 36), 8.0)          # lower arm
			d = minf(d, _seg(p, Vector2(52, 36), Vector2(108, 52), 7.0))       # upper arm
			d = minf(d, _seg(p, Vector2(108, 52), Vector2(108, 92), 4.5))      # hose
			d = minf(d, (p - Vector2(52, 36)).length() - 11.0)                 # knuckle
			d = minf(d, _box(p, Vector2(22, 112), Vector2(16, 6), 3.0))        # base
			return d
		"line":
			var d := _box(p, Vector2(24, 66), Vector2(16, 18), 5.0)            # cab
			var dr := (p - Vector2(78, 58)) / Vector2(38, 24)
			d = minf(d, (dr.length() - 1.0) * 24.0)                            # drum
			d = minf(d, _box(p, Vector2(66, 84), Vector2(56, 5), 2.0))         # chassis
			for wx in [26, 74, 100]:
				d = minf(d, (p - Vector2(wx, 98)).length() - 10.0)             # wheels
			return d
		"pump":
			var c := Vector2(64, 68)
			var r := (p - c).length()
			var d := absf(r - 46.0) - 6.5                                     # the dial
			for k in 5:
				var a := PI * (1.15 - 0.075 * k * 4.0)
				var dir := Vector2(cos(a), -sin(a))
				d = minf(d, _seg(p, c + dir * 28.0, c + dir * 36.0, 3.5))      # ticks
			d = minf(d, _seg(p, c, c + Vector2(26, -22), 5.0))                 # the needle, up in the red
			d = minf(d, r - 9.0)                                              # hub
			d = minf(d, _box(p, Vector2(64, 120), Vector2(18, 5), 2.0))        # stem
			return d
		"poker":
			var d := _seg(p, Vector2(64, 10), Vector2(64, 100), 7.0)           # the rod
			d = minf(d, _box(p, Vector2(64, 108), Vector2(10, 12), 4.0))       # the head
			for side in [-1.0, 1.0]:
				for k in 3:
					var cx: float = 64.0 + side * (24.0 + k * 14.0)
					var arc := absf((p - Vector2(cx - side * 30.0, 92)).length() - 30.0 - k * 14.0) - 3.5
					# keep only the bit of each arc beside the head
					arc = maxf(arc, absf(p.y - 92.0) - 16.0)
					arc = maxf(arc, -side * (p.x - 64.0) + 10.0)
					d = minf(d, arc)
			return d
		"screed":
			var d := _box(p, Vector2(64, 76), Vector2(58, 7), 3.0)             # the board
			d = minf(d, _seg(p, Vector2(36, 70), Vector2(30, 34), 5.0))        # handles
			d = minf(d, _seg(p, Vector2(92, 70), Vector2(98, 34), 5.0))
			d = minf(d, _seg(p, Vector2(22, 34), Vector2(38, 34), 6.0))
			d = minf(d, _seg(p, Vector2(90, 34), Vector2(106, 34), 6.0))
			# the surplus rolling in front of it
			for k in 4:
				d = minf(d, (p - Vector2(28 + k * 24, 96)).length() - 7.0)
			return d
		"hose":
			var pts := [Vector2(22, 12), Vector2(30, 46), Vector2(62, 56), Vector2(84, 78), Vector2(88, 96)]
			var d := 999.0
			for k in pts.size() - 1:
				d = minf(d, _seg(p, pts[k], pts[k + 1], 9.0))
			d = minf(d, _box(p, Vector2(89, 104), Vector2(12, 8), 3.0))       # the nozzle
			d = minf(d, (p - Vector2(80, 122)).length() - 4.5)                # drops
			d = minf(d, (p - Vector2(98, 120)).length() - 4.5)
			d = minf(d, (p - Vector2(89, 126)).length() - 3.5)
			return d
		"beer":
			# the glass, narrowing to the base, with a line under the head
			var t := clampf((p.y - 40.0) / 80.0, 0.0, 1.0)
			var d := _box(p, Vector2(60, 80), Vector2(lerpf(34.0, 26.0, t), 40), 6.0)
			d = maxf(d, -(absf(p.y - 50.0) - 3.0))
			# the head spilling over the rim, a drip down the side
			for c in [Vector2(36, 38), Vector2(54, 30), Vector2(74, 32), Vector2(88, 40)]:
				d = minf(d, (p - c).length() - 14.0)
			d = minf(d, _seg(p, Vector2(28, 42), Vector2(28, 58), 5.0))
			# a handle, so it reads as a glass at any size
			d = minf(d, absf(_box(p, Vector2(100, 78), Vector2(14, 20), 10.0)) - 5.0)
			return d
	return 999.0

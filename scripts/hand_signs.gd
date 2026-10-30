## Hand Signs: what the crew "say" over their heads, as a round sign with a
## picture and a word or two, never a sentence and never a voice (the people
## on the couch do the talking). The sign's colour says how much it matters:
##   chat     grey, small: "on it", "not yet"
##   call     the colour of the job it's calling: "KIRI · TRUCK", "PUMP", "STOP"
##   alarm    red, shakes, stays up longer: "HOPPER EMPTY"
##   gold     gold: "CONCRETE ON", a lightning kill ("0.4 s KILL")
##   thanks   green, a thumb and no word
##   slip     a bot that's switched off: a phone and "…"
## Each kind has its own bleep (sfx.gd "sign_<kind>"). Lines are mapped from
## the text the game already barks, so the callers don't change.
extends RefCounted

const KINDS := {
	"chat": {"fill": Color("e9ecef"), "edge": Color("5d6470"), "ink": Color("1a1d24"), "disc": Color("c8ccd2"), "glyph": Color("1a1d24"), "size": 30, "life": 1.3},
	"call": {"fill": Color("f4f7fa"), "edge": Color("7cd992"), "ink": Color("1a1d24"), "disc": Color("7cd992"), "glyph": Color("1a1d24"), "size": 34, "life": 2.4},
	"alarm": {"fill": Color("ff3b2f"), "edge": Color("ffffff"), "ink": Color("ffffff"), "disc": Color("ffffff"), "glyph": Color("ff3b2f"), "size": 36, "life": 2.6},
	"gold": {"fill": Color("ffd23f"), "edge": Color("ffffff"), "ink": Color("1a1d24"), "disc": Color("1a1d24"), "glyph": Color("ffd23f"), "size": 36, "life": 2.0},
	"thanks": {"fill": Color("f4f7fa"), "edge": Color("4fb36b"), "ink": Color("1a1d24"), "disc": Color("4fb36b"), "glyph": Color("ffffff"), "size": 30, "life": 1.3},
	"slip": {"fill": Color("3a3f4b"), "edge": Color("9b6bff"), "ink": Color("f4f7fa"), "disc": Color("9b6bff"), "glyph": Color("ffffff"), "size": 32, "life": 1.8},
}

## Job colours, for a call's edge (the job being called).
const JOB_COLORS := {"boom": Color("ffc72c"), "line": Color("7cd992"), "pump": Color("ff7a1a"),
	"poker": Color("c49bff"), "screed": Color("f4f7fa"), "hose": Color("2fd3e8")}

## Every line the game barks -> [kind, icon, word]. ("" word: picture only.)
const LINES := {
	"On it!": ["chat", "check", "ON IT"],
	"Not yet…": ["chat", "hand", "NOT YET"],
	"Take it up!": ["call", "up", "UP"],
	"Pump it!": ["call", "down", "PUMP"],
	"Stop!": ["call", "hand", "STOP"],
	"Needs a poke first!": ["call", "warn", "POKE IT"],
	"Hopper's empty!": ["alarm", "warn", "HOPPER EMPTY"],
	"Still under pressure!": ["alarm", "warn", "PRESSURE"],
	"Whoa!": ["chat", "warn", "WHOA"],
	"Easy!": ["chat", "warn", "EASY"],
	"Aaagh!": ["chat", "warn", "AAAGH"],
	"The dragon's breathing!": ["gold", "star", "AIR'S OUT"],
	"Concrete's on!": ["gold", "star", "CONCRETE ON"],
	"Ta!": ["thanks", "thumb", ""],
	"Hang on, phone!": ["slip", "phone", "…"],
	"Back in a sec!": ["slip", "phone", "…"],
	"Just checking something…": ["slip", "phone", "…"],
	"Where's my water?": ["slip", "phone", "…"],
}

## A crewmate calling someone by name ("Kiri! Truck's waiting!", from
## main.CALL_OUTS) -> the job's short name, by the end of the line.
const CALL_WORDS := {"Bay's waiting on the boom!": ["boom", "BOOM"], "Truck's waiting!": ["line", "TRUCK"],
	"Pump needs you!": ["pump", "PUMP"], "Grab the hose!": ["hose", "HOSE"], "Get the poker in!": ["poker", "POKER"],
	"Screed's waiting!": ["screed", "SCREED"], "You're up!": ["", "YOU'RE UP"]}

## What a line becomes: {kind, icon, word, edge (a call's job colour, or null)}.
static func read(text: String) -> Dictionary:
	if LINES.has(text):
		var l: Array = LINES[text]
		return {"kind": l[0], "icon": l[1], "word": l[2]}
	if text.ends_with(" s KILL"):
		return {"kind": "gold", "icon": "star", "word": text}
	for tail in CALL_WORDS:
		if text.ends_with(tail) and text.length() > tail.length():
			var who := text.substr(0, text.length() - tail.length()).strip_edges().trim_suffix("!")
			var cw: Array = CALL_WORDS[tail]
			var out := {"kind": "call", "icon": "arrow", "word": "%s · %s" % [who.to_upper(), cw[1]]}
			if JOB_COLORS.has(cw[0]):
				out["edge"] = JOB_COLORS[cw[0]]
			return out
	# Anything new: a grey chat sign with the line in capitals
	return {"kind": "chat", "icon": "", "word": text.to_upper().trim_suffix("!")}

# ------------------------------------------------------------------ the pictures

static var _cache := {}

## The round picture on the left of a sign: a disc with a glyph on it.
static func icon(name: String, kind: String) -> ImageTexture:
	var key := name + "|" + kind
	if _cache.has(key):
		return _cache[key]
	var n := 96
	var st: Dictionary = KINDS[kind]
	var disc: Color = st["disc"]
	var glyph: Color = st["glyph"]
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			# (glyphs are drawn in a -1..1 box over the middle of the disc)
			var q := (p - c) / (n * 0.3)
			var dd := p.distance_to(c) - n * 0.47
			var a_disc := clampf(0.5 - dd, 0.0, 1.0)
			var g := _glyph(name, q) * n * 0.3
			var a_gl := clampf(0.5 - g, 0.0, 1.0) * a_disc
			var col := disc.lerp(glyph, a_gl)
			col.a = a_disc
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

static func _seg(p: Vector2, a: Vector2, b: Vector2, r: float) -> float:
	var pa := p - a
	var ba := b - a
	var h := clampf(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	return (pa - ba * h).length() - r

static func _box(p: Vector2, c: Vector2, half: Vector2, r: float) -> float:
	var q := (p - c).abs() - (half - Vector2(r, r))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r

## Signed distance (in the -1..1 box, y down) to a glyph's ink.
static func _glyph(name: String, p: Vector2) -> float:
	var w := 0.14
	match name:
		"check":
			return minf(_seg(p, Vector2(-0.6, 0.0), Vector2(-0.15, 0.45), w), _seg(p, Vector2(-0.15, 0.45), Vector2(0.65, -0.45), w))
		"arrow":
			return minf(_seg(p, Vector2(-0.7, 0), Vector2(0.6, 0), w), minf(_seg(p, Vector2(0.65, 0), Vector2(0.15, -0.5), w), _seg(p, Vector2(0.65, 0), Vector2(0.15, 0.5), w)))
		"up":
			return minf(_seg(p, Vector2(0, 0.7), Vector2(0, -0.6), w), minf(_seg(p, Vector2(0, -0.65), Vector2(-0.5, -0.15), w), _seg(p, Vector2(0, -0.65), Vector2(0.5, -0.15), w)))
		"down":
			return minf(_seg(p, Vector2(0, -0.7), Vector2(0, 0.6), w), minf(_seg(p, Vector2(0, 0.65), Vector2(-0.5, 0.15), w), _seg(p, Vector2(0, 0.65), Vector2(0.5, 0.15), w)))
		"warn":
			var t := minf(_seg(p, Vector2(0, -0.8), Vector2(-0.8, 0.65), w * 0.8), minf(_seg(p, Vector2(-0.8, 0.65), Vector2(0.8, 0.65), w * 0.8), _seg(p, Vector2(0.8, 0.65), Vector2(0, -0.8), w * 0.8)))
			t = minf(t, _seg(p, Vector2(0, -0.25), Vector2(0, 0.15), w * 0.8))
			return minf(t, p.distance_to(Vector2(0, 0.42)) - w)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + TAU * i / 10.0
				pts.append(Vector2(cos(a), sin(a)) * (0.85 if i % 2 == 0 else 0.38))
			var d := INF
			for i in 10:
				d = minf(d, _seg(p, pts[i], pts[(i + 1) % 10], 0.0))
			return -d if Geometry2D.is_point_in_polygon(p, pts) else d
		"thumb":
			var cuff := _box(p, Vector2(-0.55, 0.25), Vector2(0.16, 0.42), 0.05)
			var fist := _box(p, Vector2(0.15, 0.3), Vector2(0.48, 0.38), 0.18)
			var th := _seg(p, Vector2(-0.12, -0.05), Vector2(0.05, -0.72), 0.17)
			return minf(cuff, minf(fist, th))
		"phone":
			var body := absf(_box(p, Vector2.ZERO, Vector2(0.42, 0.8), 0.14)) - w * 0.7
			return minf(body, _seg(p, Vector2(-0.12, 0.55), Vector2(0.12, 0.55), w * 0.6))
		"hand":
			var palm := _box(p, Vector2(0, 0.3), Vector2(0.45, 0.42), 0.2)
			for i in 4:
				var x := -0.33 + i * 0.22
				palm = minf(palm, _seg(p, Vector2(x, 0.1), Vector2(x, -0.62 + absf(i - 1.5) * 0.12), 0.1))
			return minf(palm, _seg(p, Vector2(-0.4, 0.35), Vector2(-0.78, -0.05), 0.11))
	return INF

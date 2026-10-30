## The game's UI look in one place: colours, panels, labels and button glyphs,
## shared by the HUD, the front-end screens and the pause menu.
extends RefCounted

const Icons := preload("res://scripts/icons.gd")

const INK := Color("0f1b2d")
const GLASS := Color(0.04, 0.07, 0.12, 0.78)
const GLASS_SOLID := Color(0.05, 0.08, 0.14, 0.94)
const EDGE := Color(1, 1, 1, 0.12)
const YELLOW := Color("ffc72c")
const MUTED := Color("9fb0c6")
const WHITE := Color("f4f7fa")
const RED := Color("ff4d4d")
const GREEN := Color("7cd992")
const GLYPH := {"A": Color("3fe0c5"), "B": Color("ff5a5f"), "X": Color("9b6bff"), "Y": Color("ffc23d")}

# ------------------------------------------------------------ the Site Kit
# One look for every button prompt, on the TV and on the phone (the phone page
# in controller_page.gd uses the same numbers). Each button is a face colour,
# a darker lip under it and a dark letter; four colours mean one thing each.
const LIP := {"A": Color("1b8a6e"), "B": Color("9b2525"), "X": Color("5a35b0"), "Y": Color("b17a00")}
const GLYPH_INK := {"A": Color("04281f"), "B": Color("2b0606"), "X": Color("1b0d3a"), "Y": Color("2a1d00")}
const GOLD := Color("ffd23f")     # now, the sweet spot, perfect
const ALARM := Color("ff3b2f")    # danger only
const DONE := Color("4fb36b")     # finished, good
const TRACK := Color("1a1d24")    # an empty ring, tags
const CARD := Color("15171d")     # dark cards
const PAPER := Color("f3efe4")    # the job ticket
const BONE := Color("f4f2ec")     # text on dark
const DIM := Color("8a8d97")
## The motion, in seconds and scale: the same on the phone
const BREATHE_T := 2.4
const BREATHE_S := 1.06
const URGENT_T := 0.5
const URGENT_S := 1.14
const GOLD_T := 0.3
const SHAKE_T := 0.15
## Buzz patterns, ms (vibrate on/off/on…)
const BUZZ := {"press": "12", "turn": "30,60,30", "gold": "15", "missed": "120", "alarm": "90,60,90", "done": "10,40,10"}
## Players' tag colours, P1-P6 (match the phone page)
const P_COLORS := [Color("3d8bff"), Color("ff4f6d"), Color("ff8a3d"), Color("7cd992"), Color("c49bff"), Color("2fd3e8")]

const FONT_FILES := {"head": "res://fonts/BarlowCondensed-ExtraBold.ttf", "body": "res://fonts/Barlow-SemiBold.ttf"}
static var _fonts := {}

## Barlow Condensed ExtraBold ("head") for letters, verbs and callouts;
## Barlow ("body") for the rest. Loaded straight from the .ttf so it works
## before the editor has imported anything; Godot's own font if it's missing.
static func font(kind := "body") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f: Font = ThemeDB.fallback_font
	var path: String = FONT_FILES.get(kind, FONT_FILES["body"])
	if FileAccess.file_exists(path):
		var ff := FontFile.new()
		if ff.load_dynamic_font(path) == OK:
			ff.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			ff.generate_mipmaps = true
			ff.multichannel_signed_distance_field = false
			f = ff
	_fonts[kind] = f
	return f

## Makes Barlow the font for everything that doesn't pick its own: every
## Control, and the Label3Ds in the world. Call once at startup.
static func install_fonts() -> void:
	var body := font("body")
	if body == ThemeDB.fallback_font:
		return
	ThemeDB.fallback_font = body
	var th := ThemeDB.get_default_theme()
	if th != null:
		th.default_font = body

## A label in the heading face (Barlow Condensed ExtraBold).
static func head(text: String, size: int, color := WHITE, outline := 0) -> Label:
	var l := label(text, size, color, outline)
	l.add_theme_font_override("font", font("head"))
	return l

## A round pill (the verb tag, the P tag): a StyleBox with full rounding.
static func pill(bg: Color, pad := Vector4(10, 3, 12, 3), border := Color(0, 0, 0, 0), border_w := 0) -> PanelContainer:
	return panel(bg, 99, border, border_w, pad)

## A player's "P3" tag: a coloured pill with the number in the heading face.
static func ptag(i: int, size := 18, bot := false) -> PanelContainer:
	var bg: Color = Color("5d606b") if bot else P_COLORS[(i - 1) % P_COLORS.size()]
	var p := pill(bg, Vector4(size * 0.4, 1, size * 0.4, 1))
	var l := head("bot" if bot else "P%d" % i, size, Color("111111"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

## The verb tag: a dark pill with the job's dot, then the words.
static func verb_tag(text: String, dot: Color, size := 20, col := BONE) -> PanelContainer:
	var p := pill(Color(TRACK, 0.92), Vector4(10, 4, 14, 4))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var d := Hat.new()
	d.dot = true
	d.color = dot
	d.custom_minimum_size = Vector2(size * 0.55, size * 0.55)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(d)
	h.add_child(head(text, size, col))
	return p
## Job colours: the same as the hard hats, so a colour always means a job
const ROLE := {"boom": Color("ffc72c"), "line": Color("7cd992"), "pump": Color("ff7a1a"), "poker": Color("c49bff"), "screed": Color("f4f7fa"), "hose": Color("2fd3e8")}
const ROLE_NAME := {"boom": "Boom operator", "line": "Truck hand", "pump": "Pump operator", "poker": "Poker hand", "screed": "Screeder", "hose": "Hose hand"}
const ROLE_SHORT := {
	"boom": "Steers the placing boom and pours, bay by bay.",
	"line": "Trucks and slump tests. Slings and pins on climb days.",
	"pump": "Kills the pump on a spike, and climbs up to fix the riser.",
	"poker": "Vibrates the concrete as it lands.",
	"screed": "Strikes the slab flat behind the pokers.",
	"hose": "Runs the pour: you decide where it lands and when it flows. The boom follows you.",
}
## The question each job asks of whoever picks it, on the crew page and the
## phone lobby: not what it feels like, what it'll ask of you.
const ROLE_ASK := {
	"boom": "Can you swing a 30 m boom without whipping the hose?",
	"hose": "Can you run the whole pour from the end of a hose?",
	"line": "Would you send a truck of concrete back?",
	"pump": "Can you kill the pump in half a second?",
	"poker": "Can you tell when the bubbles stop?",
	"screed": "Can you walk backwards dead straight?",
}
const ROLE_CLIMB := {"boom": "Climb days: dogman", "line": "Climb days: slinger and pins", "poker": "Climb days: tag line", "pump": "Climb days: rigger", "screed": "", "hose": ""}
## The job ticket: what each job is for and its steps on a pour, in order,
## as the phone shows it (with the live step highlighted), the pause menu's
## "Your job" card and the toolbox talk. Each step: [button ("stick" for the
## stick), what to do, words in the game's own button prompts that mean
## you're on this step].
const JOB_CARD := {
	"boom": {"goal": "Steer the boom and fill each bay.", "watch": "where the hose hand is heading. Fast swings whip the hose.",
		"steps": [["stick", "Swing the hose over the bay (push harder to go faster)", ["boom remote", "steer", "swing"]],
			["stick", "Keep the boom over the hose hand: they call the pump", ["pump", "bin"]],
			["B", "Put the remote down", ["put down", "step off"]]]},
	"line": {"goal": "Get good concrete off every truck.", "watch": "the docket. Wrong mix or too old: send it back.",
		"steps": [["A", "Hold to wave the truck back. Let go at STOP", ["wave", "stop", "let go", "truck in"]],
			["A", "Slump test: 4 presses, it stops itself", ["sample", "fill", "rod", "lift", "measur", "tape", "scoop", "slump test it"]],
			["Y", "Skip the test. Every skip makes a bad load likelier", ["skip"]],
			["A", "Use the load", ["use it", "pour it"]],
			["B", "Send it back", ["send it back", "send back"]],
			["X", "Add the water held back, test again", ["water"]],
			["stick", "Radio the pump what's coming", ["radio"]],
			["A", "Washout: hose the hopper down", ["hose the hopper"]]]},
	"pump": {"goal": "Keep the line alive.", "watch": "the gauge. Under half a second is +40.",
		"steps": [["A", "KILL THE PUMP the moment the gauge spikes", ["kill", "stop pumping", "let go: stop"]],
			["A", "Climb up, open the clamp, swap the part", ["climb", "clamp", "pipe", "open", "fit", "tap", "pin", "chair", "knock", "lower", "carry", "take"]],
			["A", "Hold at the panel to restart", ["restart"]],
			["X", "High or low output. Drop to low when a stiff load creeps", ["go high", "go low", "high", "low"]],
			["Y", "Hold at the panel to signal the chute: keep the hopper between the lines", ["chute"]],
			["A", "Washout: hold at the panel to load the sponge ball", ["sponge ball", "load the"]],
			["A", "Hold to open the washout valve", ["valve", "release", "washout"]]]},
	"hose": {"goal": "Run the pour: where it lands and when it flows.", "watch": "heaps. Move on before it piles up.",
		"steps": [["A", "Grab the end hose under the boom", ["end hose", "take"]],
			["stick", "Walk it to the empty spot", ["walk"]],
			["A", "Hold to call the pump on, let go for off", ["pump on", "pump", "radio", "dragon", "concrete's on"]],
			["A", "Washout: catch the sponge ball as it pops out", ["catch"]],
			["B", "Let go of the hose", ["put down", "let go of"]]]},
	"poker": {"goal": "Shake the air out so it sets solid.", "watch": "the bubbles. When they stop, lift. Too long and water pools.",
		"steps": [["A", "Pick up the poker", ["take poker", "pick up"]],
			["A", "Hold in the purple until the bubbles stop", ["plunge", "poke", "hold", "lift"]],
			["A", "She's right: tap a glossy strip for the screeder", ["she's right", "call the strip"]],
			["Y", "Call the boom over here", ["call", "boom over"]],
			["B", "Put it down", ["put down"]]]},
	"screed": {"goal": "Strike the slab flat behind the pokers.", "watch": "the green strips the poker calls. Float them once they go matt.",
		"steps": [["A", "Pick up the board", ["take screed", "pick up"]],
			["A", "Hold and walk back over the green", ["screed", "stroke"]],
			["X", "Bull float: swap to it once a strip goes matt", ["bull float", "back to the board"]],
			["A", "Hold to float under the blade", ["float"]]]},
}

## What each button does in each job, for the pause menu's "Your job" card and
## the phone page. [button, what it does]; "stick" for the stick. A pour's
## list is the job ticket's steps (JOB_CARD).
const ROLE_HOW := {
	"boom": {
		"climb": [["stick", "push to a call: TROLLEY OUT / IN, SLEW LEFT / RIGHT · let go: STOP"], ["A", "hold: LOWER (when the ghost sits on the green)"], ["X", "hold: HOIST"], ["Y", "hold: EASY · twice: ALL STOP"]],
	},
	"line": {
		"climb": [["A", "hold at the LAYDOWN to sling the next section"], ["A", "a PIN BAG from the base, up the HAUL ROPE"]],
	},
	"pump": {
		"climb": [["A", "jack the frame · roll the section in"], ["stick", "line up the holes, A: podger"], ["A", "swing the hammer, let go in the gold"], ["A", "hold: R-clip back on (Y skips it: a safety note)"]],
	},
	"poker": {
		"climb": [["A", "hold once the load is over the deck: grab the tag line and walk it back"], ["stick", "walk with the load"]],
	},
	"hose": {},
	"screed": {
		"climb": [["stick", "a breather: show off with the board"]],
	},
}

## The job ticket on the TV, as on the phone: paper, the hard hat and the
## job, who's on it, what it's for, each step with its button, and what to
## watch. `climb` adds the climb-day steps; `compact` drops the watch line.
static func job_ticket(role: String, who: String, pi: int, compact := false, climb := false, width := 360.0) -> PanelContainer:
	var col: Color = ROLE.get(role, WHITE)
	var ink := Color("1d1a14")
	var soft := Color("6b6252")
	var card := panel(PAPER, 10, col.darkened(0.15), 0, Vector4(14, 10, 14, 12))
	style(card).border_width_top = 6
	style(card).border_color = col
	card.custom_minimum_size = Vector2(width, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	var hat := Hat.new()
	hat.color = col.darkened(0.08)
	hat.icon = role if ROLE.has(role) else ""
	hat.custom_minimum_size = Vector2(36, 30)
	top.add_child(hat)
	var jn := head(ROLE_NAME.get(role, role).to_upper(), 24, ink)
	jn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	jn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(jn)
	if pi > 0:
		var tag := ptag(pi, 16)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(tag)
	if who != "":
		var wl := head(who, 16, soft)
		wl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		top.add_child(wl)
	var card_d: Dictionary = JOB_CARD.get(role, {})
	var goal := label(String(card_d.get("goal", "")), 16, ink, 0)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.custom_minimum_size = Vector2(width - 28, 0)
	v.add_child(goal)
	var parts := [["", how(role, "pour")]]
	if climb and not how(role, "climb").is_empty():
		parts.append(["CLIMB DAY", how(role, "climb")])
	for part in parts:
		if part[0] != "":
			v.add_child(head(part[0], 15, soft))
		var steps: Array = part[1]
		for st in steps.slice(0, 3 if compact else steps.size()):
			var r := HBoxContainer.new()
			r.add_theme_constant_override("separation", 8)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var g := glyph(st[0], 24)
			g.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			r.add_child(g)
			var t := label(String(st[1]), 15, ink, 0)
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			t.custom_minimum_size = Vector2(width - 64, 0)
			t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			r.add_child(t)
			v.add_child(r)
	if not compact and card_d.has("watch"):
		var w := HBoxContainer.new()
		w.add_theme_constant_override("separation", 6)
		v.add_child(w)
		var wh := head("WATCH", 15, col.darkened(0.35))
		wh.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		w.add_child(wh)
		var wt := label(String(card_d["watch"]), 14, soft, 0)
		wt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wt.custom_minimum_size = Vector2(width - 90, 0)
		w.add_child(wt)
	return card

## A job's steps for a pour or a climb day: [[button, text], ...].
static func how(role: String, part := "pour") -> Array:
	if part == "pour":
		var out: Array = []
		for st in JOB_CARD.get(role, {}).get("steps", []):
			out.append([st[0], st[1]])
		return out
	return ROLE_HOW.get(role, {}).get(part, [])

## Which step of the job ticket a button prompt is (by its button and its
## words), or -1.
static func step_for(role: String, btn: String, verb: String) -> int:
	var steps: Array = JOB_CARD.get(role, {}).get("steps", [])
	var v := verb.to_lower()
	var best := -1
	var best_n := 0
	for i in steps.size():
		var st: Array = steps[i]
		var n := 0
		for w in st[2]:
			if v.contains(String(w)):
				n += 2
		if st[0] == btn:
			n += 1
		if n > best_n and (st[0] == btn or n >= 2):
			best_n = n
			best = i
	return best if best_n >= 2 else -1

static func panel(bg := GLASS, radius := 12, border := EDGE, border_w := 1, pad := Vector4(14, 10, 14, 10)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func style(p: Control) -> StyleBoxFlat:
	return p.get_theme_stylebox("panel") as StyleBoxFlat

static func label(text: String, size: int, color := WHITE, outline := 5) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 1))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## A round button glyph (A/B/X/Y): the Site Kit disc, with its darker lip
## under it, a white rim and the letter in the heading face. Any other
## letter (an icon, "Aa") gets a disc in `color`.
static func glyph(letter: String, size: int, color := Color(-1, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var face: Color = color if color.r >= 0.0 else GLYPH.get(letter, YELLOW)
	sb.bg_color = face
	sb.set_corner_radius_all(size)
	sb.border_color = Color(1, 1, 1, 0.95)
	sb.set_border_width_all(2)
	# The lip: a hard shadow straight down, so it looks pressable on the TV too
	sb.shadow_color = LIP.get(letter, face.darkened(0.45)) if color.r < 0.0 else face.darkened(0.45)
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(0, maxf(2.0, round(size * 0.08)))
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if letter == "stick":
		# The thumbstick: a dark disc with the stick's ring and nub on it
		sb.bg_color = Color("2b2f3a")
		sb.shadow_color = Color("111318")
		var st := Stick.new()
		p.add_child(st)
		return p
	var l := Label.new()
	l.text = letter
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font("head"))
	l.add_theme_font_size_override("font_size", int(size * (0.62 if letter.length() == 1 else 0.42)))
	l.add_theme_color_override("font_color", GLYPH_INK.get(letter, INK))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	p.set_meta("label", l)
	return p

## A glyph followed by a word: "Ⓐ ready".
static func hint(letter: String, text: String, size := 18) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := glyph(letter, size + 8)
	h.add_child(g)
	var l := head(text, size + 2, WHITE, 4)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return h

## A thin progress bar: background track plus fill. Returns the fill rect
## (resize it with `size.x`), with its full width in meta "w".
static func bar(parent: Control, w: float, h: float, color: Color) -> ColorRect:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(w, h)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var bg := ColorRect.new()
	bg.color = TRACK
	bg.size = Vector2(w, h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.size = Vector2(0, h)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fill)
	fill.set_meta("w", w)
	return fill

static func set_bar(fill: ColorRect, frac: float) -> void:
	fill.size.x = float(fill.get_meta("w")) * clampf(frac, 0.0, 1.0)

## Pins a content-sized control to a point on the screen. The anchor's side
## decides which way it grows: right/bottom edges grow inward, centres both ways.
static func place(c: Control, anchor: Vector2, offset: Vector2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = offset.x
	c.offset_right = offset.x
	c.offset_top = offset.y
	c.offset_bottom = offset.y
	c.grow_horizontal = Control.GROW_DIRECTION_END if anchor.x == 0.0 else (Control.GROW_DIRECTION_BEGIN if anchor.x == 1.0 else Control.GROW_DIRECTION_BOTH)
	c.grow_vertical = Control.GROW_DIRECTION_END if anchor.y == 0.0 else (Control.GROW_DIRECTION_BEGIN if anchor.y == 1.0 else Control.GROW_DIRECTION_BOTH)

static func thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## A hard hat, drawn: the job's colour, a brim, and optionally the player's
## tag colour as a ring round it. `dot` draws just a round dot instead. The
## same shape as the phone page's SVG hat (M1 16h22v2H1z M3.5 16v-3a8.5 8.5 0 0 1 17 0v3z).
class Hat extends Control:
	var color := Color.WHITE:
		set(v):
			color = v
			queue_redraw()
	var dot := false
	var glow := 0.0:          # 0..1: a gold halo (the game's waiting on them)
		set(v):
			glow = v
			queue_redraw()
	var dim := false:
		set(v):
			dim = v
			queue_redraw()
	var check := false:
		set(v):
			check = v
			queue_redraw()
	## The job's icon on the front of the dome, so a job's never told apart
	## by colour alone ("" for a plain hat)
	var icon := "":
		set(v):
			icon = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size
		var c: Color = color
		if dim:
			c = Color(c, 0.5)
		if dot:
			draw_circle(s * 0.5, minf(s.x, s.y) * 0.5, c, true, -1.0, true)
			return
		var k := minf(s.x / 24.0, s.y / 20.0)
		var o := Vector2((s.x - 24.0 * k) * 0.5, (s.y - 20.0 * k) * 0.5)
		if glow > 0.0:
			var g := Color("ffd23f")
			for i in 4:
				g.a = 0.12 * glow * (4 - i) / 4.0
				draw_circle(o + Vector2(12, 12) * k, (11.0 + i * 2.2) * k, g, true, -1.0, true)
		# Dome: a half disc on a short band
		var pts := PackedVector2Array()
		var r := 8.5
		for i in 25:
			var a := PI + PI * i / 24.0
			pts.append(o + (Vector2(12, 13) + Vector2(cos(a), sin(a)) * r) * k)
		pts.append(o + Vector2(20.5, 16) * k)
		pts.append(o + Vector2(3.5, 16) * k)
		draw_colored_polygon(pts, c)
		# Ridge, a little lighter
		draw_line(o + Vector2(12, 4.6) * k, o + Vector2(12, 13) * k, c.lightened(0.25), 1.6 * k, true)
		# Brim
		draw_rect(Rect2(o + Vector2(1, 16) * k, Vector2(22, 2) * k), c.darkened(0.12))
		if icon != "":
			# (no ridge behind it: a dark badge on the dome, the icon in the hat's colour)
			var ic := o + Vector2(12, 10.8) * k
			draw_circle(ic, 6.2 * k, Color(INK, 0.9 if not dim else 0.45), true, -1.0, true)
			var isz := 10.6 * k
			draw_texture_rect(Icons.texture(icon, 64 if isz < 48.0 else 128), Rect2(ic - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false, c.lightened(0.15))
		if check:
			var g2 := Color("4fb36b")
			var cc := o + Vector2(20, 5) * k
			draw_circle(cc, 4.2 * k, g2, true, -1.0, true)
			draw_polyline(PackedVector2Array([cc + Vector2(-2, 0) * k, cc + Vector2(-0.5, 1.6) * k, cc + Vector2(2.2, -1.6) * k]), Color.WHITE, 1.3 * k, true)

## The thumbstick drawn inside a glyph disc.
class Stick extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_arc(c, r * 0.58, 0, TAU, 32, Color(1, 1, 1, 0.55), maxf(1.5, r * 0.09), true)
		draw_circle(c, r * 0.3, Color("f4f2ec"), true, -1.0, true)

## A four-point star sparkle, white on clear (tint it gold), for the gold
## moment's sparks on the TV.
static func star_texture(n := 48) -> ImageTexture:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var dx: float = absf(x - c) / c
			var dy: float = absf(y - c) / c
			# A concave diamond: |x|^0.5 + |y|^0.5 < 1
			var v := sqrt(dx) + sqrt(dy)
			var a := clampf((1.0 - v) * 6.0, 0.0, 1.0)
			a = maxf(a, clampf(1.0 - (dx * dx + dy * dy) * 9.0, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

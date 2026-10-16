## The game's UI look in one place: colours, panels, labels and button glyphs,
## shared by the HUD, the front-end screens and the pause menu.
extends RefCounted

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
## Job colours: the same as the hard hats, so a colour always means a job
const ROLE := {"boom": Color("ffc72c"), "line": Color("7cd992"), "pump": Color("ff7a1a"), "poker": Color("c49bff"), "screed": Color("f4f7fa"), "hose": Color("2fd3e8")}
const ROLE_NAME := {"boom": "Boom operator", "line": "Line hand", "pump": "Pump operator", "poker": "Poker hand", "screed": "Screeder", "hose": "Pipe guy"}
const ROLE_SHORT := {
	"boom": "Steers the placing boom and pours, bay by bay.",
	"line": "Keeps the riser sound: clamps, bursts, blockages.",
	"pump": "Trucks, slump tests, the hopper and the pump.",
	"poker": "Vibrates the concrete as it lands.",
	"screed": "Strikes the slab flat behind the pokers.",
	"hose": "On the end hose: puts the concrete exactly where it's wanted.",
}
const ROLE_CLIMB := {"boom": "Climb days: dogman", "line": "Climb days: rigger", "poker": "Climb days: tag line", "pump": "Climb days: slinger and pins", "screed": "", "hose": ""}
## What each button does in each job, for the pause menu's "Your job" card and
## the phone page. [button, what it does]; "stick" for the stick.
const ROLE_HOW := {
	"boom": {
		"pour": [["stick", "steer the hose over the bay"], ["A", "hold to pump (with a person on the hose: pump on their call)"], ["X", "boom high / low output"], ["B", "put the remote down"]],
		"climb": [["stick", "whistle the crane toward the ghost"], ["A", "hold to lower it in"], ["X", "hoist"], ["Y", "\"slowly\" (twice: stop)"]],
	},
	"line": {
		"pour": [["A", "carry parts · open and close clamps (hold)"], ["X", "safety pin"], ["B", "put it down · step off the ladder"], ["stick", "the ladder snaps to the joint"]],
		"climb": [["A", "jack the frame · roll the section in"], ["stick", "line up the holes, A: podger"], ["A", "swing the hammer, let go in the gold"], ["A", "R-clip back on"]],
	},
	"pump": {
		"pour": [["A", "wave a truck back"], ["A", "slump test: sample, fill 3 layers to the mark, rod 25 each, strike off, lift steady, read the tape"], ["A", "use the load"], ["X", "add the water held back (then test again)"], ["B", "send it back"], ["Y", "belt remote: pressure off (hold)"]],
		"climb": [["A", "hold at the LAYDOWN to sling the next section"], ["A", "a PIN BAG from the base, up the HAUL ROPE"]],
	},
	"poker": {
		"pour": [["A", "pick up the poker"], ["A", "hold in the purple until it's glossy"], ["Y", "call the boom over here"], ["B", "put it down"]],
		"climb": [["A", "hold the tag line to stop the swing"], ["stick", "walk with the load"]],
	},
	"hose": {
		"pour": [["A", "take the end hose (under the boom)"], ["stick", "walk it to where the concrete's wanted"], ["A", "hold: call the pump on (let go: off)"], ["A", "radio it the moment you see it: the dragon's breathing · concrete's on"], ["B", "let go of the hose"]],
	},
	"screed": {
		"pour": [["A", "pick up the board"], ["A", "hold and walk back over the gold"], ["B", "put it down"]],
		"climb": [["stick", "a breather: show off with the board"]],
	},
}

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

## A round button glyph (A/B/X/Y) or an icon letter on a coloured disc.
static func glyph(letter: String, size: int, color := Color(-1, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color if color.r >= 0.0 else GLYPH.get(letter, YELLOW)
	sb.set_corner_radius_all(size)
	sb.border_color = Color(1, 1, 1, 0.9)
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = letter
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(size * 0.58))
	l.add_theme_color_override("font_color", INK)
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
	var l := label(text, size, WHITE, 4)
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
	bg.color = Color(1, 1, 1, 0.13)
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

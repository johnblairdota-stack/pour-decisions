## The front end, in the Site Kit look, laid over the real site (the camera's
## flying over it behind). Two pages:
##   0. The cold open: just the title and the code to scan, while the camera
##      comes in over the river. Phones can already join and pick a job.
##   1. CREW: the title, one big code to scan, and the hat rack: six hard
##      hats, one per job. Each person grabs a hat (on their phone, or with
##      the stick) and their P tag lands on it; bots wear the rest. Lock in
##      with A (or hold LOCK IN on the phone). Once everyone's in, the
##      lowest-numbered player holds A to start.
##   2. SITE: the real building, floor by floor (main.gd draws the floors on
##      the site itself and the camera goes to the one picked) and the kit
##      to pour it with.
## Casual crews keep moving: there's always one gold default action, any
## player can press it, a countdown ring picks it on its own, and B goes back.
extends CanvasLayer

signal chosen(kit: String)
signal roles_done
signal back_to_crew

const UI := preload("res://scripts/ui.gd")
const Settings := preload("res://scripts/settings.gd")
const QR := preload("res://scripts/qr.gd")
const Story := preload("res://scripts/story.gd")

const KITS := [
	{"id": "tower", "name": "Tower boom", "sub": "Pump on the street, boom up a lattice tower", "ok": true, "tag": "WHAT SCP RAN HERE"},
	{"id": "truck", "name": "Truck boom", "sub": "Boom on the pump truck. Runs out of reach up top", "ok": true, "tag": "REACH RUNS OUT UP TOP"},
	{"id": "tutorial", "name": "Water tower", "sub": "A short guided job on a round water tower", "ok": true, "tag": "NEW? START HERE"},
	{"id": "line", "name": "Line pump", "sub": "Trailer pump, pipe run across the deck", "ok": false, "tag": "LATER CHAPTER"},
	{"id": "mast", "name": "Mast boom", "sub": "Placing boom on a floor-climbing mast", "ok": false, "tag": "LATER CHAPTER"},
]
## The site page's cards, left to right (indices into KITS). A fresh save
## puts the water tower first and picks it; once the crew's poured on the
## tower the water tower card goes (_arrange_cards).
const CARDS_FRESH := [2, 0, 1]
const CARDS_TUT_DONE := [0, 2, 1]
const CARDS_ON_SITE := [0, 1]
const CARD_TAGS := {"fresh": ["NEW? START HERE", "THE TOWER", "OTHER KIT"], "tut_done": ["PICKED FOR YOU", "ONCE MORE", "OTHER KIT"], "site": ["PICKED FOR YOU", "OTHER KIT"]}
var CARDS: Array = CARDS_TUT_DONE
const FLOORS := 11
const MEDAL_COL := [Color("d0884a"), Color("d6dde6"), Color("ffd23f")]
const CLIMB_BEFORE := [4, 7, 10]   # levels that start with a climb day
const RACK_ORDER := ["boom", "line", "pump", "hose", "poker", "screed"]

const HOLD_T := 0.8           # everyone's locked in: the first player holds A this long to start
const WAIT_T := 20.0          # ...and if nobody does, it starts on its own
const OPEN_T := 6.0           # the cold open: the title over the fly-in, before the hat rack
const AUTO_T := 20.0          # someone's locked in: the ring runs, then everyone's in
const SITE_T := 15.0          # the site page starts the picked pour on its own

var game = null
var page := "crew"
var index := 0                # the kit picked (into KITS)
var start_level := 1          # the floor picked on the site page (1-based)
var _done := false
var _cool := 0.0
var _pcool := {}
var _ready_p := {}            # person index -> locked in on the crew page
var _hold_t := 0.0            # how long the first player's held A, everyone locked in
var _hold_armed := false      # (they've let go of A since locking in)
var _wait_t := 0.0            # everyone's in and nobody's holding
var _all_in := false          # every person here's locked in
## (the phones' lobby reads this: seconds until it starts on its own, or -1)
var _count_t: float:
	get:
		return (WAIT_T - _wait_t) if _all_in and page == "crew" else -1.0
var _waiting := false         # the first player's holding A but someone's still choosing
var open_t := 0.0             # the cold open's clock
var crew_t := 0.0             # how long the crew page has been up
var open_e := 0.0             # 0 the cold open, 1 the crew page (main.gd flies the camera on it)
var _bar: Control
var _tagline: Control
var _auto_t := -1.0
var _site_t := SITE_T
var _t := 0.0
var _floor_pick := 0          # 0-based
var _card_i := 0              # which of CARDS
var _card_state := ""         # "fresh", "tut_done" or "site"

var _crew_page: Control
var _site_page: Control
var _hats: Dictionary = {}    # role -> {hat, tag, ptag, who, col}
var _pdots: Array = []
var _ring: Ring
var _count_title: Label
var _count_sub: Label
var _go_pill: PanelContainer
var _go_title: Label
var _go_sub: Label
var _back_hint: Control
var _qr_rect: TextureRect
var _qr_panel: Control       # the QR's card, top right
var _title: Control          # the title, top left
var _rack: Control           # the hat rack: fitted between those and the bar along the bottom
var _qr_url := ""
var _url_label: Label
var _help_label: Label
var join: Label
# site page
var _floor_rows: Array = []   # {row, bar, label, num, medal}
var _site_ring: Ring
var _site_note: Label
var _lvl_k: Label
var _lvl_title: Label
var _lvl_line: Label         # the day's line from the tower's story
var _lvl_chips: HBoxContainer
var _kit_cards: Array = []

func _ready() -> void:
	layer = 5
	# The real site's behind it all: only the top and the bottom are
	# darkened, for the type
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.6, 1.0])
	g.colors = PackedColorArray([Color(0.043, 0.047, 0.063, 0.82), Color(0.043, 0.047, 0.063, 0.2), Color(0.043, 0.047, 0.063, 0.2), Color(0.043, 0.047, 0.063, 0.86)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_crew_page(root)
	_build_site_page(root)
	_show_page("crew")

# ------------------------------------------------------------------ crew page

func _build_crew_page(root: Control) -> void:
	_crew_page = Control.new()
	_crew_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crew_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crew_page)
	# The title
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	_crew_page.add_child(tv)
	UI.place(tv, Vector2(0, 0), Vector2(48, 30))
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 14)
	tv.add_child(th)
	var logo_hat := UI.Hat.new()
	logo_hat.color = UI.YELLOW
	logo_hat.custom_minimum_size = Vector2(92, 78)
	logo_hat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(logo_hat)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -14)
	th.add_child(names)
	names.add_child(UI.head("Pour Decisions", 84, UI.BONE, 8))
	# (where it is: smaller and paler, under the name)
	names.add_child(UI.head("Brisbane", 38, Color(UI.BONE, 0.62), 6))
	_tagline = UI.label(Settings.brand("site") + ", Hamilton Reach · a crew of six · bots fill the gaps", 24, Color("d4d1c8"), 4)
	tv.add_child(_tagline)
	# One code for everyone, top right
	var qr := UI.panel(UI.CARD, 18, Color(1, 1, 1, 0.08), 1, Vector4(14, 14, 18, 14))
	_crew_page.add_child(qr)
	UI.place(qr, Vector2(1, 0), Vector2(-40, 26))
	var qh := HBoxContainer.new()
	qh.add_theme_constant_override("separation", 16)
	qr.add_child(qh)
	var qbg := UI.panel(Color.WHITE, 12, Color(0, 0, 0, 0), 0, Vector4(8, 8, 8, 8))
	qh.add_child(qbg)
	_qr_rect = TextureRect.new()
	_qr_rect.custom_minimum_size = Vector2(176, 176)
	_qr_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_qr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_qr_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	qbg.add_child(_qr_rect)
	var qv := VBoxContainer.new()
	qv.add_theme_constant_override("separation", 6)
	qv.custom_minimum_size = Vector2(330, 0)
	qh.add_child(qv)
	qv.add_child(UI.head("Scan to join", 40, UI.BONE))
	var how := UI.label("One code for everyone. Pads and keyboards: press A.", 24, Color("c9c6bd"), 0)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(330, 0)
	qv.add_child(how)
	_url_label = UI.head("", 26, UI.GOLD)
	qv.add_child(_url_label)
	_help_label = UI.label("", 24, UI.DIM, 0)
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.custom_minimum_size = Vector2(330, 0)
	qv.add_child(_help_label)
	join = _help_label
	# The hat rack
	var rack := UI.panel(Color("bf8f58"), 22, Color("8f6436"), 8, Vector4(26, 16, 26, 18))
	_crew_page.add_child(rack)
	UI.place(rack, Vector2(0, 0), Vector2.ZERO)
	_rack = rack
	_qr_panel = qr
	_title = tv
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	rack.add_child(rv)
	var rt := HBoxContainer.new()
	rt.add_theme_constant_override("separation", 14)
	rv.add_child(rt)
	rt.add_child(UI.head("Grab a hat", 36, Color("1b1308")))
	var rs := UI.label("On your phone, or left / right for the job and up / down for who. Then lock in.", 24, Color("3d2c18"), 0)
	rs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rt.add_child(rs)
	var rail := ColorRect.new()
	rail.color = Color("5b5f68")
	rail.custom_minimum_size = Vector2(0, 10)
	rv.add_child(rail)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	rv.add_child(row)
	for role in RACK_ORDER:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.custom_minimum_size = Vector2(212, 0)
		col.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.add_child(col)
		var peg := ColorRect.new()
		peg.color = Color("33363d")
		peg.custom_minimum_size = Vector2(14, 16)
		peg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(peg)
		var hat := UI.Hat.new()
		hat.color = UI.ROLE[role]
		hat.icon = role
		hat.custom_minimum_size = Vector2(120, 100)
		hat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(hat)
		var jn := UI.head(UI.ROLE_NAME[role], 30, Color("1b1308"))
		jn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(jn)
		var tag := UI.pill(UI.CARD, Vector4(5, 4, 12, 4))
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(tag)
		var tr := HBoxContainer.new()
		tr.add_theme_constant_override("separation", 6)
		tag.add_child(tr)
		var ptag := UI.ptag(1, 24)
		tr.add_child(ptag)
		var who := UI.label("", 24, UI.BONE, 0)
		who.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tr.add_child(who)
		var ask := UI.head(UI.ROLE_ASK[role], 24, Color("1b1308"))
		ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ask.custom_minimum_size = Vector2(206, 0)
		col.add_child(ask)
		_hats[role] = {"hat": hat, "tag": tag, "ptag": ptag, "who": who}
	# Along the bottom: who's in, the countdown, and the gold default
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 18)
	_crew_page.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 48
	bar.offset_right = -48
	bar.offset_top = -128
	bar.offset_bottom = -20
	_bar = bar
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 8)
	bar.add_child(dots)
	for i in 6:
		var d := UI.panel(Color(0, 0, 0, 0), 99, UI.DIM, 2, Vector4(0, 0, 0, 0))
		d.custom_minimum_size = Vector2(56, 56)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var dl := UI.head("P%d" % (i + 1), 24, UI.DIM)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		d.add_child(dl)
		dots.add_child(d)
		_pdots.append({"disc": d, "label": dl})
	_ring = Ring.new()
	_ring.custom_minimum_size = Vector2(78, 78)
	_ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_ring)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 0)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(cv)
	_count_title = UI.head("", 32, UI.BONE)
	cv.add_child(_count_title)
	_count_sub = UI.label("", 24, Color("c9c6bd"), 0)
	_count_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(_count_sub)
	_back_hint = _key_hint("B", "CHANGE", false)
	bar.add_child(_back_hint)
	_go_pill = UI.pill(UI.TRACK, Vector4(8, 8, 24, 8), UI.GOLD, 2)
	_go_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_go_pill)
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 12)
	_go_pill.add_child(gh)
	gh.add_child(UI.glyph("A", 54))
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", -2)
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	gh.add_child(gv)
	_go_title = UI.head("", 30, UI.BONE)
	gv.add_child(_go_title)
	_go_sub = UI.label("", 24, Color("c9c6bd"), 0)
	gv.add_child(_go_sub)

## A button and what it does, for the bottom bars.
func _key_hint(letter: String, text: String, bright := true) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var g := UI.glyph(letter, 46)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(g)
	var l := UI.head(text, 24, UI.BONE if bright else Color("c9c6bd"))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return h

func _refresh_crew() -> void:
	var crew = game.crew
	var people: Array = crew.humans()
	for role in RACK_ORDER:
		var e: Dictionary = _hats[role]
		var p = crew.crew[role]
		var hat: UI.Hat = e["hat"]
		var locked: bool = not p.bot and bool(_ready_p.get(p.index, false))
		hat.dim = p.bot
		hat.check = locked
		var ptag: PanelContainer = e["ptag"]
		var who: Label = e["who"]
		UI.style(e["tag"]).bg_color = Color(0.106, 0.075, 0.031, 0.22) if p.bot else UI.CARD
		if p.bot:
			UI.style(ptag).bg_color = Color("5d606b")
			(ptag.get_child(0) as Label).text = "bot"
			who.text = p.char_name
			who.add_theme_color_override("font_color", Color("3d2c18"))
			hat.rotation = 0.0
		else:
			UI.style(ptag).bg_color = p.tag_color
			(ptag.get_child(0) as Label).text = "P%d" % p.index
			who.text = p.char_name + ("" if locked else "…")
			who.add_theme_color_override("font_color", UI.BONE)
			# Still choosing: the hat sways on its peg
			hat.pivot_offset = Vector2(hat.size.x * 0.5, 0)
			hat.rotation = 0.0 if locked else 0.06 * sin(_t * 5.0)
	for i in 6:
		var d: Dictionary = _pdots[i]
		var q = crew.human(i + 1)
		var sb := UI.style(d["disc"])
		sb.bg_color = q.tag_color if q != null else Color(0, 0, 0, 0)
		sb.border_color = Color(1, 1, 1, 0.9) if q != null and bool(_ready_p.get(i + 1, false)) else (Color(0, 0, 0, 0) if q != null else UI.DIM)
		(d["label"] as Label).add_theme_color_override("font_color", Color("111111") if q != null else UI.DIM)
		(d["disc"] as Control).modulate.a = 1.0 if q != null else 0.45 + 0.2 * sin(_t * 3.0 + i)
	var bots := RACK_ORDER.size() - people.size()
	var any_locked := false
	var all_locked := not people.is_empty()
	var choosing: Array = []
	for p in people:
		if bool(_ready_p.get(p.index, false)):
			any_locked = true
		else:
			all_locked = false
			choosing.append("P%d" % p.index)
	var first := "P%d" % _starter(people).index if not people.is_empty() else "P1"
	if people.is_empty():
		_go_title.text = "PRESS A TO JOIN"
		_go_sub.text = "bots take the jobs nobody does"
	elif all_locked:
		_go_title.text = "HOLD TO START"
		_go_sub.text = ("%s · bots take the other %d jobs" % [first, bots]) if bots > 0 else ("%s · the whole crew's people" % first)
	else:
		_go_title.text = "LOCK IN"
		_go_sub.text = "then %s holds A to start" % first
	_go_pill.pivot_offset = _go_pill.size * 0.5
	_go_pill.scale = Vector2.ONE * (1.0 + (UI.BREATHE_S - 1.0) * (0.5 - 0.5 * cos(_t * TAU / UI.BREATHE_T)))
	_back_hint.visible = any_locked
	if all_locked:
		# (the ring fills as the first player holds A; left alone, it runs
		# down and the job starts anyway)
		var holding := _hold_t > 0.0
		_ring.frac = clampf(_hold_t / HOLD_T, 0.0, 1.0) if holding else clampf(1.0 - _wait_t / WAIT_T, 0.0, 1.0)
		_ring.text = "A" if holding else str(int(ceil(maxf(WAIT_T - _wait_t, 0.0))))
		_count_title.text = "Everyone's in"
		_count_sub.text = "%s: hold A to start. B changes your hat." % first
	elif any_locked:
		_ring.frac = clampf(_auto_t / AUTO_T, 0.0, 1.0)
		_ring.text = str(int(ceil(maxf(_auto_t, 0.0))))
		_count_title.text = ("Waiting on %s" % " and ".join(choosing)) if _waiting else "Nearly there"
		_count_sub.text = "%s %s still choosing. When the ring runs out they keep the hat they're on." % [" and ".join(choosing), "is" if choosing.size() == 1 else "are"]
	else:
		_ring.frac = -1.0
		_count_title.text = "Grab a hat"
		_count_sub.text = "Pick a job, then lock in. You can swap on site."
	_ring.visible = any_locked

## A person locks in (or changes their mind).
func set_ready(i: int, on: bool) -> void:
	if bool(_ready_p.get(i, false)) == on:
		return
	_ready_p[i] = on
	# (the hat they've locked in on jumps)
	if on and game != null and is_inside_tree():
		var me = game.crew.human(i)
		if me != null and _hats.has(me.role):
			var hat: Control = _hats[me.role]["hat"]
			hat.scale = Vector2(1.3, 1.3)
			create_tween().tween_property(hat, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if game != null:
		game.sfx.hit("ding" if on else "tink")
		if game._dbg:
			print("[select] P%d %s" % [i, "locked in" if on else "unlocked"])
		var p = game.crew.human(i)
		if on and p != null and game.has_method("haptic"):
			game.haptic(p, UI.BUZZ["done"])

## The hat rack goes under the title and the QR card and above the bar
## along the bottom, shrunk to fit when the screen text is big (it used to
## sit in the middle and cover the bottom of the QR at 1.25).
const RACK_GAP := 14.0
const RACK_BAR := 142.0      # px kept clear along the bottom for the bar

func _fit_rack() -> void:
	if _rack == null:
		return
	var vs: Vector2 = _crew_page.size
	var top: float = 30.0 + _title.size.y + RACK_GAP
	if _qr_panel.visible:
		top = maxf(top, _qr_panel.get_rect().end.y + RACK_GAP)
	var bottom: float = vs.y - RACK_BAR
	var sz: Vector2 = _rack.get_combined_minimum_size()
	var k := minf(1.0, minf((bottom - top) / sz.y, (vs.x - 48.0) / sz.x))
	_rack.size = sz
	_rack.scale = Vector2(k, k)
	# (hard down on the bar, so the site shows over it)
	_rack.position = Vector2((vs.x - sz.x * k) * 0.5, bottom - sz.y * k)
	# The title: big in the middle for the cold open, then up to its corner
	var ts: Vector2 = _title.get_combined_minimum_size()
	_title.size = ts
	var big := 1.45
	var sc := lerpf(big, 1.0, open_e)
	_title.scale = Vector2(sc, sc)
	_title.position = Vector2((vs.x - ts.x * big) * 0.5, vs.y * 0.3).lerp(Vector2(48, 30), open_e)
	_rack.modulate.a = open_e
	_bar.modulate.a = open_e
	_tagline.modulate.a = open_e

## Who starts the job: the lowest-numbered person here.
func _starter(people: Array):
	var best = null
	for p in people:
		if best == null or p.index < best.index:
			best = p
	return best

func _process_crew(delta: float) -> void:
	var crew = game.crew
	var people: Array = crew.humans()
	# The cold open: the title over the fly-in. Any button cuts it short
	# (and that press does nothing else)
	if open_e < 1.0:
		open_t += delta
		var skip: bool = (game.autotest and not game.wants_cold_open()) or _uitest
		for p in people:
			if p.action_pressed() or p.leave_pressed() or p.move_input().length() > 0.5:
				skip = true
		if skip:
			open_t = maxf(open_t, OPEN_T)
		open_e = ease(clampf((open_t - OPEN_T) / 0.7, 0.0, 1.0), -2.0)
		_fit_rack()
		_refresh_crew()
		if open_e < 1.0:
			return
	crew_t += delta
	_fit_rack()
	for p in people:
		var i: int = p.index
		_pcool[i] = maxf(0.0, float(_pcool.get(i, 0.0)) - delta)
		var v: Vector2 = p.move_input()
		var me = crew.human(i)
		if me == null:
			continue
		var locked: bool = _ready_p.get(i, false)
		if not locked and _pcool[i] <= 0.0:
			# Left / right along the rack: the next hat a bot's wearing.
			# Up / down: who's wearing it.
			if absf(v.x) > 0.5:
				crew.cycle(i, int(signf(v.x)))
				_pcool[i] = 0.22
				game.sfx.hit("tink")
			elif absf(v.y) > 0.5:
				crew.cycle_char(i, int(signf(v.y)))
				_pcool[i] = 0.22
				game.sfx.hit("tink")
		me = crew.human(i)
		if me.action_pressed():
			# The gold default: lock in
			if not locked:
				set_ready(i, true)
		elif me.leave_pressed() and locked:
			set_ready(i, false)
	people = crew.humans()
	var all := not people.is_empty()
	var any := false
	for p in people:
		var r: bool = _ready_p.get(p.index, false)
		all = all and r
		any = any or r
	_all_in = all
	var first = _starter(people)
	var held: bool = first != null and first.action_held()
	_waiting = false
	if all:
		# Everyone's in: the first player holds A to start (they have to let
		# go of the press that locked them in first). Left alone, it starts.
		_auto_t = -1.0
		if not held:
			_hold_armed = true
		if held and _hold_armed:
			if _hold_t <= 0.0:
				game.sfx.hit("tink")
			_hold_t += delta
		else:
			_hold_t = maxf(0.0, _hold_t - delta * 2.0)
			_wait_t += delta
		if _hold_t >= HOLD_T or _wait_t >= WAIT_T:
			game.sfx.hit("ding")
			go_site()
	else:
		_hold_t = 0.0
		_wait_t = 0.0
		_hold_armed = false
		# (holding A with someone still choosing: it says who it's waiting on)
		_waiting = held and first != null and bool(_ready_p.get(first.index, false))
		if any:
			if _auto_t < 0.0:
				_auto_t = AUTO_T
			_auto_t -= delta
			if _auto_t <= 0.0:
				# The ring's run out: everyone's in on the hat they're wearing
				for p in people:
					_ready_p[p.index] = true
				_auto_t = -1.0
		else:
			_auto_t = -1.0
	_refresh_crew()

## On to the second page.
func go_site() -> void:
	_show_page("site")
	open_e = 1.0
	_hold_t = 0.0
	_wait_t = 0.0
	_cool = 0.3
	_site_t = SITE_T
	_pick_defaults()
	roles_done.emit()

# ------------------------------------------------------------------ site page

func _build_site_page(root: Control) -> void:
	_site_page = Control.new()
	_site_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_site_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_site_page)
	var title := UI.head(Settings.brand("site") + " · next pour", 56, UI.BONE, 8)
	_site_page.add_child(title)
	UI.place(title, Vector2(0, 0), Vector2(48, 26))
	# The building's the real one, out on the site (main.gd draws its floors
	# and takes the camera to the one picked): this side's the pour picked,
	# and the kit
	var card := UI.panel(Color(UI.CARD, 0.9), 22, Color(1, 1, 1, 0.08), 1, Vector4(26, 20, 26, 22))
	_site_page.add_child(card)
	UI.place(card, Vector2(1, 0), Vector2(-40, 104))
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	rv.custom_minimum_size = Vector2(804, 0)
	card.add_child(rv)
	_lvl_k = UI.head("", 24, UI.DIM)
	rv.add_child(_lvl_k)
	_lvl_title = UI.head("", 46, UI.BONE)
	rv.add_child(_lvl_title)
	_lvl_line = UI.label("", 24, UI.BONE, 0)
	_lvl_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lvl_line.custom_minimum_size = Vector2(800, 0)
	rv.add_child(_lvl_line)
	_lvl_chips = HBoxContainer.new()
	_lvl_chips.add_theme_constant_override("separation", 10)
	rv.add_child(_lvl_chips)
	var note := UI.label("Stick up or down picks the floor. Left or right picks the kit.", 24, Color("c9c6bd"), 0)
	rv.add_child(note)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	rv.add_child(cards)
	for ki in [0, 2, 1]:
		var k: Dictionary = KITS[ki]
		var c := UI.panel(UI.TRACK, 16, Color("2c2f39"), 1, Vector4(16, 12, 16, 14))
		c.custom_minimum_size = Vector2(260, 170)
		cards.add_child(c)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		c.add_child(v)
		var tg := UI.head("", 24, UI.DIM)
		v.add_child(tg)
		v.add_child(UI.head(k["name"], 34, UI.BONE))
		var sub := UI.label(Settings.branded(k["sub"]), 24, Color("b9b6ad"), 0)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(226, 0)
		v.add_child(sub)
		_kit_cards.append({"card": c, "tag": tg, "kit": ki})
	_site_note = UI.label("", 24, UI.YELLOW, 0)
	_site_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_site_note.custom_minimum_size = Vector2(800, 0)
	rv.add_child(_site_note)
	# The countdown and the buttons
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 18)
	_site_page.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 48
	bar.offset_right = -48
	bar.offset_top = -104
	bar.offset_bottom = -24
	_site_ring = Ring.new()
	_site_ring.custom_minimum_size = Vector2(72, 72)
	_site_ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_site_ring)
	var sn := UI.label("", 24, Color("c9c6bd"), 4)
	sn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(sn)
	_site_ring.set_meta("note", sn)
	var go := UI.pill(UI.TRACK, Vector4(8, 6, 22, 6), UI.GOLD, 2)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.add_child(_key_hint("A", "POUR"))
	bar.add_child(go)
	_site_ring.set_meta("go", go)
	var back := _key_hint("B", "CREW", false)
	bar.add_child(back)

## For main.gd's floors out on the site: the floor picked (0-based), or -1
## on the water tower's card.
func floor_pick() -> int:
	return -1 if KITS[index]["id"] == "tutorial" else _floor_pick

func medals() -> Array:
	return _medals()

func _medals() -> Array:
	var m = Settings.value("medals")
	return m if m is Array else []

## The gold default: the tower boom, on the next floor nobody's poured.
func _pick_defaults() -> void:
	var m := _medals()
	var done := 0
	while done < m.size() and int(m[done]) >= 0:
		done += 1
	_floor_pick = clampi(done, 0, FLOORS - 1)
	_arrange_cards(done)
	_card_i = 0
	index = CARDS[_card_i]
	_refresh_site()

## Has this save poured on the tower (or the truck boom) before? Then the
## water tower's done its job and its card goes. Until then a crew that's
## never played is pointed at it first.
func _arrange_cards(done: int) -> void:
	var on_site: bool = done > 0 or bool(Settings.value("tower_started"))
	_card_state = "site" if on_site else ("tut_done" if bool(Settings.value("tut_done")) else "fresh")
	CARDS = {"fresh": CARDS_FRESH, "tut_done": CARDS_TUT_DONE, "site": CARDS_ON_SITE}[_card_state]
	var tags: Array = CARD_TAGS[_card_state]
	var row: Node = null
	for e in _kit_cards:
		var c: Control = e["card"]
		row = c.get_parent()
		var at := CARDS.find(int(e["kit"]))
		c.visible = at >= 0
		if at >= 0:
			(e["tag"] as Label).text = tags[at]
	if row != null:
		for at in CARDS.size():
			for e in _kit_cards:
				if int(e["kit"]) == CARDS[at]:
					row.move_child(e["card"], at)

func _refresh_site() -> void:
	var m := _medals()
	var done := 0
	while done < m.size() and int(m[done]) >= 0:
		done += 1
	var tut: bool = KITS[index]["id"] == "tutorial"
	for e in _floor_rows:
		var n: int = e["n"]
		var i := n - 1
		var poured := i < m.size() and int(m[i]) >= 0
		var next := i == done
		var sel := i == _floor_pick and not tut
		var sb := UI.style(e["bar"])
		var lab: Label = e["label"]
		if poured:
			sb.bg_color = Color("a8a296")
			sb.border_color = UI.GOLD if sel else Color(0, 0, 0, 0)
			lab.text = Story.title(i) + ("  ·  pour it again" if sel else "")
			lab.add_theme_color_override("font_color", Color("1b1a17"))
		elif next:
			sb.bg_color = Color("2a2410")
			sb.border_color = UI.GOLD
			lab.text = "NEXT · " + Story.title(i)
			lab.add_theme_color_override("font_color", UI.GOLD)
		else:
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = Color("3a3e4a")
			lab.text = Story.title(i)
			lab.add_theme_color_override("font_color", UI.DIM)
		sb.set_border_width_all(3 if sel or next else 2)
		(e["bar"] as Control).modulate.a = 0.4 if tut else 1.0
		(e["num"] as Label).add_theme_color_override("font_color", UI.GOLD if next else (Color("c9c6bd") if poured else UI.DIM))
		var medal: PanelContainer = e["medal"]
		medal.visible = poured
		if poured:
			UI.style(medal).bg_color = [Color("d0884a"), Color("d6dde6"), Color("ffd23f")][clampi(int(m[i]), 0, 2)]
	var lvl := _floor_pick + 1
	start_level = 1 if tut else lvl
	if tut:
		_lvl_k.text = "TUTORIAL"
		_lvl_title.text = "Water tower · a short guided job"
		_lvl_line.text = ""
	else:
		_lvl_k.text = "LEVEL %d OF %d" % [lvl, FLOORS]
		_lvl_title.text = "Level %d · %s" % [lvl, Story.title(lvl - 1)]
		_lvl_line.text = Story.line(lvl - 1)
	for c in _lvl_chips.get_children():
		_lvl_chips.remove_child(c)
		c.queue_free()
	var chips := [[KITS[index]["name"], UI.YELLOW]]
	if not tut and lvl in CLIMB_BEFORE and KITS[index]["id"] == "tower":
		chips.append(["Climb day first", UI.ROLE["pump"]])
	if not tut and lvl - 1 < m.size() and int(m[lvl - 1]) >= 0:
		var mi := clampi(int(m[lvl - 1]), 0, 2)
		chips.append([["Bronze", "Silver", "Gold"][mi] + " last time", MEDAL_COL[mi]])
	elif not tut and lvl - 1 == done:
		chips.append(["Next floor up", UI.GOLD])
	for ch in chips:
		var p := UI.pill(UI.TRACK, Vector4(10, 4, 14, 4))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		p.add_child(h)
		var d := UI.Hat.new()
		d.dot = true
		d.color = ch[1]
		d.custom_minimum_size = Vector2(14, 14)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(d)
		h.add_child(UI.label(ch[0], 24, UI.BONE, 0))
		_lvl_chips.add_child(p)
	for e2 in _kit_cards:
		var on := int(e2["kit"]) == index
		var sb2 := UI.style(e2["card"])
		sb2.bg_color = Color("2a2410") if on else UI.CARD
		sb2.border_color = UI.GOLD if on else Color("2c2f39")
		sb2.set_border_width_all(3 if on else 1)
		(e2["tag"] as Label).add_theme_color_override("font_color", UI.GOLD if on else UI.DIM)

func _process_site(delta: float) -> void:
	if _done:
		return
	_cool = maxf(0.0, _cool - delta)
	var v := Vector2.ZERO
	var pressed := false
	var back := false
	# Anyone can change it, start it or go back; the ring starts it anyway
	if game != null:
		for p in game.crew.humans():
			var mv: Vector2 = p.move_input()
			if mv.length() > v.length():
				v = mv
			pressed = pressed or p.action_pressed()
			back = back or p.leave_pressed()
	if _cool <= 0.0 and absf(v.x) > 0.5:
		var ni := clampi(_card_i + int(signf(v.x)), 0, CARDS.size() - 1)
		if ni != _card_i:
			_card_i = ni
			index = CARDS[_card_i]
			_site_note.text = ""
			_site_t = SITE_T
			_refresh_site()
			for e in _kit_cards:
				if int(e["kit"]) == index:
					var kc: Control = e["card"]
					kc.pivot_offset = kc.size * 0.5
					kc.scale = Vector2(1.08, 1.08)
					create_tween().tween_property(kc, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if game:
				game.sfx.hit("tink")
		_cool = 0.22
	elif _cool <= 0.0 and absf(v.y) > 0.5 and KITS[index]["id"] != "tutorial":
		var m := _medals()
		var done := 0
		while done < m.size() and int(m[done]) >= 0:
			done += 1
		var nf := clampi(_floor_pick - int(signf(v.y)), 0, mini(done, FLOORS - 1))
		if nf != _floor_pick:
			_floor_pick = nf
			_site_t = SITE_T
			_refresh_site()
			if game:
				game.sfx.hit("tink")
		_cool = 0.22
	_site_t -= delta
	_site_ring.frac = clampf(_site_t / SITE_T, 0.0, 1.0)
	_site_ring.text = str(int(ceil(maxf(_site_t, 0.0))))
	var tut: bool = KITS[index]["id"] == "tutorial"
	(_site_ring.get_meta("note") as Label).text = ("The water tower starts on its own." if tut else "Level %d starts on its own." % start_level) + " Anyone can change it."
	var go: Control = _site_ring.get_meta("go")
	go.pivot_offset = go.size * 0.5
	go.scale = Vector2.ONE * (1.0 + (UI.BREATHE_S - 1.0) * (0.5 - 0.5 * cos(_t * TAU / UI.BREATHE_T)))
	if (_cool <= 0.0 and pressed) or _site_t <= 0.0:
		pick(index)
	elif back:
		for k in _ready_p.keys():
			_ready_p[k] = false
		_show_page("crew")
		back_to_crew.emit()

func pick(i: int) -> void:
	index = i
	var ci := CARDS.find(i)
	if ci >= 0:
		_card_i = ci
	if _floor_rows.size() > 0:
		_refresh_site()
	var k: Dictionary = KITS[i]
	if not k["ok"]:
		_site_note.text = "The %s comes in a later chapter." % k["name"].to_lower()
		return
	if k["id"] == "tutorial":
		start_level = 1
	_done = true
	chosen.emit(k["id"])

# ------------------------------------------------------------------ shared

var _uitest := OS.get_cmdline_user_args().has("--uitest")
var _ut := 0.0

func _process(delta: float) -> void:
	if game == null:
		return
	_t += delta
	if _uitest:
		# Dev: click through both pages the way a person would
		_ut += delta
		var p1 = game.crew.human(1)
		if page == "crew" and p1 != null:
			if _ut > 0.5 and _ut - delta <= 0.5:
				game.crew.cycle_char(1, 1)
				print("[uitest] char -> %s" % game.crew.human(1).char_name)
			if _ut > 1.0 and _ut - delta <= 1.0:
				game.crew.cycle(1, 1)
				print("[uitest] job -> %s, chars: %s" % [game.crew.human(1).role, str(game.crew.ROLES.map(func(r): return game.crew.crew[r].char_name))])
			if _ut > 1.5 and _ut - delta <= 1.5:
				set_ready(1, true)
			if _ut > 2.2 and _ut - delta <= 2.2:
				go_site()
		elif page == "site" and _ut > 2.5 and not _done:
			print("[uitest] picking the tower")
			pick(0)
	if page == "crew":
		_process_crew(delta)
	else:
		_process_site(delta)

func _show_page(which: String) -> void:
	var was := page
	page = which
	_crew_page.visible = which == "crew"
	_site_page.visible = which == "site"
	# (the page coming in slides in from its side and fades up)
	if was != which and is_inside_tree():
		var pg: Control = _site_page if which == "site" else _crew_page
		pg.modulate.a = 0.0
		pg.position.x = 60.0 if which == "site" else -60.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(pg, "modulate:a", 1.0, 0.25)
		tw.tween_property(pg, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if which == "crew":
		_hold_t = 0.0
		_wait_t = 0.0
		_hold_armed = false
		_auto_t = -1.0

func set_join(text: String, url := "") -> void:
	if url != _qr_url and _qr_rect != null:
		_qr_url = url
		_qr_rect.texture = QR.texture(url, 4) if url != "" else null
		_url_label.text = url.replace("http://", "or type ") if url != "" else ""
	if _help_label != null:
		var help := ""
		if url != "":
			var others: Array = game.phones.other_urls() if game != null and game.phones != null else []
			help = "Not loading? Use the same Wi-Fi, and allow Godot through the firewall."
			if not others.is_empty():
				help = "Not loading? Try " + " or ".join(others.map(func(o): return String(o).replace("http://", "")))
		else:
			help = text.split("\n")[0] if text != "" else ""
		_help_label.text = help
	if _qr_rect != null:
		(_qr_rect.get_parent() as Control).visible = _qr_rect.texture != null

# ------------------------------------------------------------------ pictures

## A countdown ring: a gold arc that runs down, with the seconds in the middle.
class Ring extends Control:
	var frac := 1.0:
		set(v):
			frac = v
			queue_redraw()
	var text := "":
		set(v):
			text = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if frac < 0.0:
			return
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 5.0
		draw_arc(c, r, 0, TAU, 48, Color("1a1d24"), 7.0, true)
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, Color("ffd23f"), 7.0, true)
		var f: Font = UI.font("head")
		var fs := int(r * 0.95)
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffd23f"))

## The front end, in the Site Kit look, two pages:
##   1. CREW: the title, one big code to scan, and the hat rack: six hard
##      hats, one per job. Each person grabs a hat (on their phone, or with
##      the stick) and their P tag lands on it; bots wear the rest. Lock in
##      with A (or hold LOCK IN on the phone).
##   2. SITE: the building floor by floor (poured floors show their medal,
##      the next one glows gold) and the kit to pour it with.
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
	{"id": "tower", "name": "Tower boom", "sub": "Stationary pump + placing boom on a lattice tower", "ok": true, "tag": "WHAT SCP RAN HERE"},
	{"id": "truck", "name": "Truck boom", "sub": "Truck-mounted boom pump. Reach runs out on the top floors", "ok": true, "tag": "REACH RUNS OUT UP TOP"},
	{"id": "tutorial", "name": "Water tower", "sub": "A short guided job on a round concrete water tower", "ok": true, "tag": "NEW? START HERE"},
	{"id": "line", "name": "Line pump", "sub": "Trailer pump, pipe run across the deck", "ok": false, "tag": "LATER CHAPTER"},
	{"id": "mast", "name": "Mast boom", "sub": "Placing boom on a floor-climbing mast", "ok": false, "tag": "LATER CHAPTER"},
]
## The site page's three cards, left to right (indices into KITS)
const CARDS := [0, 2, 1]
const CARD_TAG := ["PICKED FOR YOU", "NEW TO THIS?", "OTHER KIT"]
const FLOORS := 11
const CLIMB_BEFORE := [4, 7, 10]   # levels that start with a climb day
const RACK_ORDER := ["boom", "line", "pump", "hose", "poker", "screed"]

const COUNT_T := 3.0          # everyone's locked in: a short count, B still stops it
const AUTO_T := 20.0          # someone's locked in: the ring runs, then everyone's in
const SITE_T := 15.0          # the site page starts the picked pour on its own

var game = null
var page := "crew"
var index := 0                # the kit picked (into KITS)
var start_level := 1          # the floor picked on the site page (1-based)
var _roles := true            # (kept for the dev autotest hooks)
var _done := false
var _cool := 0.0
var _pcool := {}
var _ready_p := {}            # person index -> locked in on the crew page
var _count_t := -1.0          # counting down to the site page
var _auto_t := -1.0
var _site_t := SITE_T
var _t := 0.0
var _floor_pick := 0          # 0-based
var _card_i := 0              # which of CARDS

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
	var shade := ColorRect.new()
	shade.color = Color(0.043, 0.047, 0.063, 0.86)
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
	logo_hat.custom_minimum_size = Vector2(76, 64)
	logo_hat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(logo_hat)
	th.add_child(UI.head("POUR DECISIONS", 66, UI.BONE))
	tv.add_child(UI.label(Settings.brand("site") + ", Hamilton Reach · a crew of six · bots fill the gaps", 18, Color("d4d1c8"), 0))
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
	_qr_rect.custom_minimum_size = Vector2(148, 148)
	_qr_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_qr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_qr_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	qbg.add_child(_qr_rect)
	var qv := VBoxContainer.new()
	qv.add_theme_constant_override("separation", 6)
	qv.custom_minimum_size = Vector2(250, 0)
	qh.add_child(qv)
	qv.add_child(UI.head("Scan to join", 34, UI.BONE))
	var how := UI.label("Everyone scans this one code. Your phone says which player you are. Keyboards and pads: press A.", 15, Color("c9c6bd"), 0)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(250, 0)
	qv.add_child(how)
	_url_label = UI.head("", 20, UI.GOLD)
	qv.add_child(_url_label)
	_help_label = UI.label("", 12, UI.DIM, 0)
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.custom_minimum_size = Vector2(250, 0)
	qv.add_child(_help_label)
	join = _help_label
	# The hat rack
	var rack := UI.panel(Color("bf8f58"), 22, Color("8f6436"), 8, Vector4(26, 16, 26, 18))
	_crew_page.add_child(rack)
	UI.place(rack, Vector2(0.5, 0.5), Vector2(0, 26))
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	rack.add_child(rv)
	var rt := HBoxContainer.new()
	rt.add_theme_constant_override("separation", 14)
	rv.add_child(rt)
	rt.add_child(UI.head("Grab a hat", 34, Color("1b1308")))
	var rs := UI.label("Pick your job on your phone, or left / right (up / down changes who you are), then lock in", 16, Color("3d2c18"), 0)
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
		col.custom_minimum_size = Vector2(176, 0)
		col.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.add_child(col)
		var peg := ColorRect.new()
		peg.color = Color("33363d")
		peg.custom_minimum_size = Vector2(14, 16)
		peg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(peg)
		var hat := UI.Hat.new()
		hat.color = UI.ROLE[role]
		hat.custom_minimum_size = Vector2(120, 100)
		hat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(hat)
		var jn := UI.head(UI.ROLE_NAME[role], 24, Color("1b1308"))
		jn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(jn)
		var tag := UI.pill(UI.CARD, Vector4(5, 4, 12, 4))
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(tag)
		var tr := HBoxContainer.new()
		tr.add_theme_constant_override("separation", 6)
		tag.add_child(tr)
		var ptag := UI.ptag(1, 16)
		tr.add_child(ptag)
		var who := UI.label("", 16, UI.BONE, 0)
		who.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tr.add_child(who)
		var line := UI.label(UI.ROLE_SHORT[role], 13, Color("3d2c18"), 0)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.custom_minimum_size = Vector2(170, 0)
		col.add_child(line)
		_hats[role] = {"hat": hat, "tag": tag, "ptag": ptag, "who": who}
	# Along the bottom: who's in, the countdown, and the gold default
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 18)
	_crew_page.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 48
	bar.offset_right = -48
	bar.offset_top = -112
	bar.offset_bottom = -24
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 8)
	bar.add_child(dots)
	for i in 6:
		var d := UI.panel(Color(0, 0, 0, 0), 99, UI.DIM, 2, Vector4(0, 0, 0, 0))
		d.custom_minimum_size = Vector2(46, 46)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var dl := UI.head("P%d" % (i + 1), 18, UI.DIM)
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
	_count_title = UI.head("", 30, UI.BONE)
	cv.add_child(_count_title)
	_count_sub = UI.label("", 15, Color("b9b6ad"), 0)
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
	_go_sub = UI.label("", 13, Color("c9c6bd"), 0)
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
	_go_title.text = ("START WITH %d" % people.size()) if not people.is_empty() else "PRESS A TO JOIN"
	_go_sub.text = ("any player · bots take the other %d jobs" % bots) if bots > 0 else "any player · the whole crew's people"
	_go_pill.pivot_offset = _go_pill.size * 0.5
	_go_pill.scale = Vector2.ONE * (1.0 + (UI.BREATHE_S - 1.0) * (0.5 - 0.5 * cos(_t * TAU / UI.BREATHE_T)))
	_back_hint.visible = any_locked
	if all_locked:
		_ring.frac = clampf(_count_t / COUNT_T, 0.0, 1.0)
		_ring.text = str(int(ceil(maxf(_count_t, 0.0))))
		_count_title.text = "Everyone's in"
		_count_sub.text = "Starting now. B stops it."
	elif any_locked:
		_ring.frac = clampf(_auto_t / AUTO_T, 0.0, 1.0)
		_ring.text = str(int(ceil(maxf(_auto_t, 0.0))))
		_count_title.text = "Nearly there"
		_count_sub.text = "Starting when the ring runs out. %s %s still choosing: they keep the hat they're on." % [" and ".join(choosing), "is" if choosing.size() == 1 else "are"]
	else:
		_ring.frac = -1.0
		_count_title.text = "Grab a hat"
		_count_sub.text = "Pick a job, then lock in. Bots wear the hats nobody takes, and you can swap on site."
	_ring.visible = any_locked

## A person locks in (or changes their mind).
func set_ready(i: int, on: bool) -> void:
	if bool(_ready_p.get(i, false)) == on:
		return
	_ready_p[i] = on
	if game != null:
		game.sfx.hit("ding" if on else "tink")
		if game._dbg:
			print("[select] P%d %s" % [i, "locked in" if on else "unlocked"])
		var p = game.crew.human(i)
		if on and p != null and game.has_method("haptic"):
			game.haptic(p, UI.BUZZ["done"])

func _process_crew(delta: float) -> void:
	var crew = game.crew
	var people: Array = crew.humans()
	var go_now := false
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
			# The gold default: lock in, and once you're in, go now
			if locked:
				go_now = true
			else:
				set_ready(i, true)
		elif me.leave_pressed() and locked:
			set_ready(i, false)
	var all := not people.is_empty()
	var any := false
	for p in people:
		var r: bool = _ready_p.get(p.index, false)
		all = all and r
		any = any or r
	if go_now:
		for p in people:
			_ready_p[p.index] = true
		all = true
		_count_t = minf(_count_t, 0.6) if _count_t > 0.0 else 0.6
	if all:
		_auto_t = -1.0
		if _count_t < 0.0:
			_count_t = COUNT_T
			game.sfx.hit("ding")
		var was := int(ceil(_count_t))
		_count_t -= delta
		if int(ceil(_count_t)) != was and _count_t > 0.0:
			game.sfx.hit("tink")
		if _count_t <= 0.0:
			_count_t = -1.0
			go_site()
	else:
		_count_t = -1.0
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
	var title := UI.head(Settings.brand("site") + " · next pour", 54, UI.BONE)
	_site_page.add_child(title)
	UI.place(title, Vector2(0, 0), Vector2(48, 26))
	# The building, floor by floor, from the street up
	var tower := VBoxContainer.new()
	tower.add_theme_constant_override("separation", 4)
	_site_page.add_child(tower)
	UI.place(tower, Vector2(0, 0), Vector2(60, 110))
	for n in range(FLOORS, 0, -1):
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		tower.add_child(r)
		var num := UI.head("L%d" % n, 18, UI.DIM)
		num.custom_minimum_size = Vector2(36, 0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r.add_child(num)
		var b := UI.panel(Color(0, 0, 0, 0), 8, Color("3a3e4a"), 2, Vector4(12, 2, 10, 2))
		b.custom_minimum_size = Vector2(380, 36)
		r.add_child(b)
		var bh := HBoxContainer.new()
		bh.add_theme_constant_override("separation", 8)
		b.add_child(bh)
		var lab := UI.head("", 17, UI.DIM)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bh.add_child(lab)
		if n in CLIMB_BEFORE:
			var chip := UI.pill(Color(0, 0, 0, 0.35), Vector4(8, 1, 8, 1))
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			chip.add_child(UI.head("CLIMB DAY", 13, UI.YELLOW))
			bh.add_child(chip)
		var medal := UI.panel(UI.GOLD, 99, Color(0, 0, 0, 0), 0, Vector4(0, 0, 0, 0))
		medal.custom_minimum_size = Vector2(22, 22)
		medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bh.add_child(medal)
		_floor_rows.append({"bar": b, "label": lab, "num": num, "medal": medal, "n": n})
	var ground := ColorRect.new()
	ground.color = Color("5f8a5a")
	ground.custom_minimum_size = Vector2(380, 12)
	var gr := HBoxContainer.new()
	gr.add_theme_constant_override("separation", 10)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(36, 0)
	gr.add_child(sp)
	gr.add_child(ground)
	tower.add_child(gr)
	# The pour picked, and the kit
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 12)
	rv.custom_minimum_size = Vector2(700, 0)
	_site_page.add_child(rv)
	UI.place(rv, Vector2(1, 0), Vector2(-48, 120))
	_lvl_k = UI.head("", 18, UI.DIM)
	rv.add_child(_lvl_k)
	_lvl_title = UI.head("", 46, UI.BONE)
	rv.add_child(_lvl_title)
	_lvl_line = UI.label("", 21, UI.BONE, 0)
	_lvl_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lvl_line.custom_minimum_size = Vector2(680, 0)
	rv.add_child(_lvl_line)
	_lvl_chips = HBoxContainer.new()
	_lvl_chips.add_theme_constant_override("separation", 10)
	rv.add_child(_lvl_chips)
	var note := UI.label("Floors you've poured show their medal. Stick up or down picks another floor; left or right picks the kit.", 17, Color("c9c6bd"), 0)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(680, 0)
	rv.add_child(note)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	rv.add_child(cards)
	for ci in CARDS.size():
		var k: Dictionary = KITS[CARDS[ci]]
		var c := UI.panel(UI.TRACK, 16, Color("2c2f39"), 1, Vector4(16, 14, 16, 16))
		c.custom_minimum_size = Vector2(220, 150)
		cards.add_child(c)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		c.add_child(v)
		var tg := UI.head(CARD_TAG[ci], 14, UI.DIM)
		v.add_child(tg)
		v.add_child(UI.head(k["name"], 30, UI.BONE))
		var sub := UI.label(Settings.branded(k["sub"]), 14, Color("b9b6ad"), 0)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(186, 0)
		v.add_child(sub)
		_kit_cards.append({"card": c, "tag": tg})
	var later := UI.label("Later chapters: line pump · mast boom", 14, UI.DIM, 0)
	rv.add_child(later)
	_site_note = UI.label("", 17, UI.YELLOW, 0)
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
	var sn := UI.label("", 19, Color("c9c6bd"), 0)
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
	_card_i = 0
	index = CARDS[_card_i]
	_refresh_site()

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
	if not tut and lvl <= done:
		chips.append(["Poured before", UI.DONE])
	for ch in chips:
		var p := UI.pill(UI.TRACK, Vector4(10, 4, 14, 4))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		p.add_child(h)
		var d := UI.Hat.new()
		d.dot = true
		d.color = ch[1]
		d.custom_minimum_size = Vector2(10, 10)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(d)
		h.add_child(UI.label(ch[0], 16, UI.BONE, 0))
		_lvl_chips.add_child(p)
	for ci in _kit_cards.size():
		var e2: Dictionary = _kit_cards[ci]
		var on := ci == _card_i
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
		_site_note.text = "The %s comes in a later chapter. Pick the tower or the truck." % k["name"].to_lower()
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
		elif page == "site" and _ut > 2.5 and not _done:
			print("[uitest] picking the tower")
			pick(0)
	if page == "crew":
		_process_crew(delta)
	else:
		_process_site(delta)

func _show_page(which: String) -> void:
	page = which
	_roles = which == "crew"
	_crew_page.visible = which == "crew"
	_site_page.visible = which == "site"
	if which == "crew":
		_count_t = -1.0
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
			help = "Not loading? Same Wi-Fi as this computer, and allow Godot through the Windows firewall (private networks)."
			if not others.is_empty():
				help = "Not loading? Try " + " or ".join(others.map(func(o): return String(o).replace("http://", ""))) + ", and allow Godot through the firewall."
		else:
			help = text.split("\n")[0] if text != "" else ""
		_help_label.text = help
	if _qr_rect != null:
		(_qr_rect.get_parent() as Control).visible = _qr_rect.texture != null

## (Older entry point, kept for the main script.)
func show_roles() -> void:
	_show_page("crew")

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

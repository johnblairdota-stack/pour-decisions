## The HUD. Small and out of the way: everything that matters to the job in
## hand is in the world (the hand signs, the button cues by your head, the
## close-up cameras), so the screen only carries what you can't see there.
##
##   top centre   what the crew's doing now, with its progress (and the clock)
##   top right    points and rank; the pump (hopper, trucks, line pressure)
##                and the wind, each only while it matters
##   left         the live jobs, most urgent first, each with a countdown bar
##   centre       one-line call-outs that fade
##   bottom       the dogman's whistle call while dogging; "Esc pause"
## Close-up cameras sit bottom right (see main.gd), framed in the job's colour.
extends CanvasLayer

const UI := preload("res://scripts/ui.gd")
const Icons := preload("res://scripts/icons.gd")

# (kept for older callers)
const YELLOW := UI.YELLOW
const ORANGE := Color("ff7a1a")
const INK := UI.INK
const MUTED := UI.MUTED
const RED := UI.RED

var _root: Control
var _top: Control          # the report and the briefing, above the street band
# task
var task_box: PanelContainer
var task_chip: Label
var task_label: Label
var clock_label: Label
var sub_label: Label
var prog_fill: ColorRect
# score
var score_label: Label
var level_label: Label
var rank_label: Label
var rank_bar: ColorRect
var _shown_score := 0.0
var _score_box: PanelContainer
# pump
var pump_panel: PanelContainer
var hopper_pct: Label
var hopper_fill: ColorRect
var trucks_label: Label
var line_label: Label
var gauge: Gauge
var _pause_hint: Label
var _bottom := -1.0
# wind
var wind_panel: PanelContainer
var wind_label: Label
var wind_bar: ColorRect
# tickets
var ticket_box: VBoxContainer
var tickets: Array = []
# call-outs
var toast_panel: PanelContainer
var toast_label: Label
var _toast_t := 0.0
var _alert := ""
var signal_panel: PanelContainer
var signal_label: Label
var bolt_panel: PanelContainer
var bolt_title: Label
var bolt_zone: ColorRect
var bolt_marker: ColorRect
var bolt_glyph: PanelContainer
const BOLT_W := 320.0
# cards
var card: PanelContainer
var _card_t := 0.0
var _card_hold := false      # the slab report waits for someone to press A
var _card_age := 0.0
var card_away := false        # the slab report waits, out of sight (while the top slab's signed)
var _card_box: VBoxContainer
var _card_next: Label
var _card_fill: ColorRect
var _card_go: Control
var brief: PanelContainer
var rank_banner: PanelContainer
var rank_banner_label: Label
var _rank_t := 0.0
var banner: PanelContainer
var facts: PanelContainer
var facts_label: Label
# joining (shown on the pause menu, not over the game)
var join_text := ""
var join_url := ""
var join_hint := ""

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	# The slab report and the briefing sit on their own layer, above the
	# street band and the pop-up cameras, so a split screen never hides them
	var top_layer := CanvasLayer.new()
	top_layer.layer = 5
	add_child(top_layer)
	_top = Control.new()
	_top.set_anchors_preset(Control.PRESET_FULL_RECT)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_layer.add_child(_top)

	# --- What's happening now, top centre
	task_box = UI.panel(UI.GLASS, 12, UI.EDGE, 1, Vector4(14, 8, 14, 10))
	_root.add_child(task_box)
	UI.place(task_box, Vector2(0.5, 0), Vector2(0, 14))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 5)
	task_box.add_child(tv)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	tv.add_child(th)
	task_chip = UI.label("", 16, UI.YELLOW, 0)
	task_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	th.add_child(task_chip)
	task_label = UI.label("", 25, UI.WHITE, 4)
	task_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# (a long task trims with "…" rather than running into the clock)
	task_label.custom_minimum_size = Vector2(330, 0)
	task_label.clip_text = true
	task_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	th.add_child(task_label)
	clock_label = UI.label("", 19, UI.MUTED, 0)
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_label.custom_minimum_size = Vector2(56, 0)
	th.add_child(clock_label)
	prog_fill = UI.bar(tv, 380, 5, ORANGE)
	sub_label = UI.label("", 17, UI.WHITE, 3)
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_label.custom_minimum_size = Vector2(380, 0)
	sub_label.visible = false
	tv.add_child(sub_label)

	# --- Points and rank, top right
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	_root.add_child(right)
	UI.place(right, Vector2(1, 0), Vector2(-16, 14))
	_score_box = UI.panel(UI.GLASS, 12, UI.EDGE, 1, Vector4(14, 6, 14, 8))
	right.add_child(_score_box)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	_score_box.add_child(sv)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 12)
	sv.add_child(sh)
	level_label = UI.label("L1/11", 17, UI.MUTED, 0)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sh.add_child(level_label)
	score_label = UI.label("0", 34, UI.YELLOW, 4)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_label.custom_minimum_size = Vector2(120, 0)
	sh.add_child(score_label)
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 8)
	sv.add_child(rh)
	rank_label = UI.label("LABOURER", 14, UI.WHITE, 0)
	rank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rh.add_child(rank_label)
	var rbh := VBoxContainer.new()
	rbh.alignment = BoxContainer.ALIGNMENT_CENTER
	rh.add_child(rbh)
	rank_bar = UI.bar(rbh, 90, 4, UI.YELLOW)

	# --- The pump, under the score while pouring
	pump_panel = UI.panel(UI.GLASS, 12, UI.EDGE, 1, Vector4(12, 6, 12, 8))
	pump_panel.custom_minimum_size = Vector2(214, 0)
	right.add_child(pump_panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 3)
	pump_panel.add_child(pv)
	var ph := HBoxContainer.new()
	pv.add_child(ph)
	var hl := UI.label("HOPPER", 14, UI.MUTED, 0)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(hl)
	hopper_pct = UI.label("", 16, UI.WHITE, 0)
	ph.add_child(hopper_pct)
	hopper_fill = UI.bar(pv, 190, 7, UI.GREEN)
	trucks_label = UI.label("", 15, UI.WHITE, 0)
	pv.add_child(trucks_label)
	line_label = UI.label("", 15, UI.MUTED, 0)
	pv.add_child(line_label)
	# The pump operator's gauge: the needle jumps into the red on a spike
	gauge = Gauge.new()
	gauge.custom_minimum_size = Vector2(190, 74)
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(gauge)
	pump_panel.visible = false

	# --- Wind, only while it matters
	wind_panel = UI.panel(UI.GLASS, 12, UI.EDGE, 1, Vector4(12, 6, 12, 8))
	wind_panel.custom_minimum_size = Vector2(214, 0)
	right.add_child(wind_panel)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 3)
	wind_panel.add_child(wv)
	wind_label = UI.label("", 15, UI.WHITE, 0)
	wv.add_child(wind_label)
	var wbh := Control.new()
	wbh.custom_minimum_size = Vector2(190, 6)
	wv.add_child(wbh)
	var wbg := ColorRect.new()
	wbg.color = Color(1, 1, 1, 0.13)
	wbg.size = Vector2(190, 6)
	wbh.add_child(wbg)
	wind_bar = ColorRect.new()
	wind_bar.size = Vector2(0, 6)
	wbh.add_child(wind_bar)
	var stop := ColorRect.new()
	stop.color = UI.RED
	stop.size = Vector2(2, 12)
	stop.position = Vector2(190.0 * 54.0 / 80.0, -3)
	wbh.add_child(stop)
	wind_panel.visible = false

	# --- Live jobs, down the left
	ticket_box = VBoxContainer.new()
	ticket_box.add_theme_constant_override("separation", 6)
	_root.add_child(ticket_box)
	UI.place(ticket_box, Vector2(0, 0), Vector2(16, 14))
	for i in 5:
		var t := UI.panel(UI.GLASS, 10, UI.EDGE, 1, Vector4(8, 6, 12, 7))
		t.custom_minimum_size = Vector2(250, 0)
		ticket_box.add_child(t)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		t.add_child(hb)
		var icon := UI.glyph("!", 24, ORANGE)
		hb.add_child(icon)
		var jicon := TextureRect.new()
		jicon.custom_minimum_size = Vector2(32, 32)
		jicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		jicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		jicon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(jicon)
		var v2 := VBoxContainer.new()
		v2.add_theme_constant_override("separation", 3)
		v2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(v2)
		var tl := UI.label("", 17, UI.WHITE, 3)
		# (fixed width, wrapping: a long ticket never runs under the task bar)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.custom_minimum_size = Vector2(230, 0)
		v2.add_child(tl)
		var bf := UI.bar(v2, 200, 3, UI.GREEN)
		t.visible = false
		tickets.append({"panel": t, "icon": icon, "jicon": jicon, "label": tl, "fill": bf})

	# --- Call-outs: one line, under the task, fading
	toast_panel = UI.panel(Color(0.04, 0.07, 0.12, 0.7), 20, Color(0, 0, 0, 0), 0, Vector4(18, 6, 18, 7))
	_root.add_child(toast_panel)
	UI.place(toast_panel, Vector2(0.5, 0), Vector2(0, 108))
	toast_label = UI.label("", 24, UI.YELLOW, 4)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.add_child(toast_label)
	toast_panel.visible = false

	# --- The dogman's whistle call
	signal_panel = UI.panel(Color(0.04, 0.07, 0.12, 0.75), 22, Color(0, 0, 0, 0), 0, Vector4(22, 8, 22, 9))
	_root.add_child(signal_panel)
	UI.place(signal_panel, Vector2(0.5, 1), Vector2(0, -36))
	signal_label = UI.label("", 30, UI.WHITE, 5)
	signal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	signal_panel.add_child(signal_label)
	signal_panel.visible = false

	# --- A timing bar, for the odd job that needs one
	bolt_panel = UI.panel()
	_root.add_child(bolt_panel)
	UI.place(bolt_panel, Vector2(0.5, 1), Vector2(0, -110))
	var bv := VBoxContainer.new()
	bolt_panel.add_child(bv)
	var bth := HBoxContainer.new()
	bth.add_theme_constant_override("separation", 8)
	bv.add_child(bth)
	bolt_glyph = UI.glyph("A", 30)
	bth.add_child(bolt_glyph)
	bolt_title = UI.head("", 22, UI.BONE)
	bolt_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bth.add_child(bolt_title)
	var bb := Control.new()
	bb.custom_minimum_size = Vector2(BOLT_W, 18)
	bv.add_child(bb)
	var bbg := ColorRect.new()
	bbg.color = UI.TRACK
	bbg.size = Vector2(BOLT_W, 18)
	bb.add_child(bbg)
	bolt_zone = ColorRect.new()
	bolt_zone.color = UI.GOLD
	bolt_zone.size = Vector2(60, 18)
	bb.add_child(bolt_zone)
	bolt_marker = ColorRect.new()
	bolt_marker.color = Color.WHITE
	bolt_marker.size = Vector2(5, 26)
	bolt_marker.position = Vector2(0, -4)
	bb.add_child(bolt_marker)
	bolt_panel.visible = false

	# --- Pause hint, bottom left, tiny
	var ph2 := UI.label("Pause: Esc · Start · the Pause button on a phone", 14, Color(1, 1, 1, 0.45), 3)
	_root.add_child(ph2)
	UI.place(ph2, Vector2(0, 1), Vector2(16, -12))
	_pause_hint = ph2

	# --- The crew: six hard hats, bottom left, the one the game's waiting on glowing
	_build_crew()

	# --- Slab report
	card = UI.panel(UI.CARD, 16, UI.EDGE, 0, Vector4(24, 16, 24, 18))
	var csb := UI.style(card)
	csb.border_width_top = 8
	csb.border_color = UI.GOLD
	csb.shadow_color = Color(0, 0, 0, 0.5)
	csb.shadow_size = 18
	_top.add_child(card)
	UI.place(card, Vector2(0.5, 0.5), Vector2(0, 20))
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 10)
	card.add_child(_card_box)
	card.visible = false

	# --- The toolbox talk before a pour: paper, on its own layer
	brief = UI.panel(UI.PAPER, 14, UI.EDGE, 0, Vector4(24, 16, 24, 18))
	style_brief()
	brief.custom_minimum_size = Vector2(760, 0)
	_top.add_child(brief)
	UI.place(brief, Vector2(0.5, 0.5), Vector2(0, 20))
	_tb_box = VBoxContainer.new()
	_tb_box.add_theme_constant_override("separation", 8)
	brief.add_child(_tb_box)
	brief.visible = false

	# --- Top out
	banner = UI.panel(UI.YELLOW, 16, Color(0, 0, 0, 0), 0, Vector4(26, 10, 26, 12))
	banner.add_child(UI.label("TOPPED OUT!", 64, UI.INK, 0))
	_root.add_child(banner)
	UI.place(banner, Vector2(0.5, 0), Vector2(0, 150))
	banner.visible = false
	facts = UI.panel(UI.GLASS_SOLID, 16, UI.EDGE, 2, Vector4(22, 16, 22, 16))
	facts.custom_minimum_size = Vector2(560, 0)
	_root.add_child(facts)
	UI.place(facts, Vector2(0.5, 1), Vector2(0, -60))
	facts_label = UI.label("", 18, UI.WHITE, 0)
	facts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facts_label.custom_minimum_size = Vector2(520, 0)
	facts.add_child(facts_label)
	facts.visible = false

func _process(delta: float) -> void:
	_place_tickets()
	_animate_crew(delta)
	if _toast_t > 0.0:
		_toast_t -= delta
		toast_panel.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
		if _toast_t <= 0.0 and _alert == "":
			toast_panel.visible = false
	if _alert != "":
		toast_panel.visible = true
		toast_panel.modulate.a = 1.0
	if not card_away:
		_card_age += delta
	if card_away:
		card.visible = false
	elif _card_hold:
		card.visible = true
		card.modulate.a = 1.0
		# (the gold A breathes, so it's clear what moves things on)
		if _card_go != null:
			_card_go.pivot_offset = _card_go.size * 0.5
			_card_go.scale = Vector2.ONE * (1.0 + (UI.BREATHE_S - 1.0) * (0.5 - 0.5 * cos(_card_age * TAU / UI.BREATHE_T)))
	elif _card_t > 0.0:
		_card_t -= delta
		card.visible = _card_t > 0.0
		card.modulate.a = clampf(_card_t * 2.0, 0.0, 1.0)
	if _rank_t > 0.0:
		_rank_t -= delta
		rank_banner.visible = _rank_t > 0.0
		var u := clampf((2.4 - _rank_t) * 5.0, 0.0, 1.0)
		rank_banner.pivot_offset = rank_banner.size * 0.5
		rank_banner.scale = Vector2.ONE * (0.6 + 0.4 * ease(u, 0.3) + 0.04 * sin(_rank_t * 12.0))
		rank_banner.modulate.a = clampf(_rank_t * 2.0, 0.0, 1.0)

# ------------------------------------------------------------------ crew bar

const CREW_ORDER := ["boom", "line", "pump", "hose", "poker", "screed"]
var crew_bar: PanelContainer
var _crew: Dictionary = {}     # role -> {hat, tag, label, nudge}
var _crew_wait: Label
var _crew_t := 0.0
var _crew_key := ""

func _build_crew() -> void:
	crew_bar = UI.panel(UI.GLASS, 12, UI.EDGE, 1, Vector4(10, 6, 12, 6))
	_root.add_child(crew_bar)
	UI.place(crew_bar, Vector2(0, 1), Vector2(16, -36))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	crew_bar.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	for role in CREW_ORDER:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		col.custom_minimum_size = Vector2(40, 0)
		h.add_child(col)
		var hat := UI.Hat.new()
		hat.color = UI.ROLE[role]
		hat.custom_minimum_size = Vector2(40, 30)
		col.add_child(hat)
		var tag := UI.pill(Color("5d606b"), Vector4(5, 0, 5, 0))
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var tl := UI.head("bot", 13, Color("111111"))
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_child(tl)
		col.add_child(tag)
		# (the job's part in the Site Band: a little level that bounces on
		# the beat while it's playing)
		var eq := ColorRect.new()
		eq.color = UI.ROLE[role]
		eq.custom_minimum_size = Vector2(28, 7)
		eq.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		eq.pivot_offset = Vector2(14, 7)
		eq.visible = false
		col.add_child(eq)
		_crew[role] = {"hat": hat, "tag": tag, "label": tl, "nudge": 0, "eq": eq}
	_crew_wait = UI.head("", 16, UI.GOLD)
	_crew_wait.visible = false
	v.add_child(_crew_wait)
	crew_bar.visible = false

## Who's on each job: rows of {role, p (player number), name, bot, nudge}
## (nudge as main.nudge_level: 1 their turn, 2 called out, 3 covered).
func set_crew(rows: Array, show := true) -> void:
	crew_bar.visible = show
	if not show:
		return
	var key := str(rows)
	if key == _crew_key:
		return
	_crew_key = key
	var wait_txt := ""
	var wait_lvl := 0
	for r in rows:
		var e: Dictionary = _crew.get(r["role"], {})
		if e.is_empty():
			continue
		var bot: bool = r["bot"]
		var pi: int = r["p"]
		UI.style(e["tag"]).bg_color = Color("5d606b") if bot else UI.P_COLORS[(pi - 1) % UI.P_COLORS.size()]
		(e["label"] as Label).text = "bot" if bot else "P%d" % pi
		(e["hat"] as UI.Hat).dim = false
		e["nudge"] = int(r["nudge"])
		if e["nudge"] > wait_lvl:
			wait_lvl = e["nudge"]
			var who := "P%d %s" % [pi, String(r["name"]).to_upper()]
			match wait_lvl:
				1:
					wait_txt = "WAITING ON %s" % who
				2:
					wait_txt = "%s · THE CREW'S CALLING" % who
				3:
					wait_txt = "LEADING HAND'S COVERING %s · PRESS ANYTHING" % who
	_crew_wait.text = wait_txt
	_crew_wait.visible = wait_txt != ""
	_crew_wait.add_theme_color_override("font_color", UI.GOLD if wait_lvl < 3 else UI.BONE)
	crew_bar.reset_size()

## Each job's level in the Site Band (sfx.gd), on its hat in the crew bar.
func set_band(sfx, show: bool) -> void:
	var beat: float = sfx.beat_phase()
	for role in _crew:
		var eq: ColorRect = _crew[role]["eq"]
		var lvl: float = sfx.band_level(role)
		eq.visible = show
		eq.scale.y = maxf(0.12, lvl * (1.0 - 0.65 * beat))
		eq.modulate.a = 0.35 + 0.65 * lvl

func _animate_crew(delta: float) -> void:
	if crew_bar == null or not crew_bar.visible:
		return
	_crew_t += delta
	for role in _crew:
		var e: Dictionary = _crew[role]
		var hat: UI.Hat = e["hat"]
		var n: int = e["nudge"]
		var period: float = UI.URGENT_T if n >= 2 else UI.BREATHE_T
		var pl := 0.5 - 0.5 * cos(_crew_t * TAU / period)
		var g := 0.0
		if n == 1 or n == 2:
			g = 0.55 + 0.45 * pl
		elif n == 3:
			g = 0.35
		if absf(hat.glow - g) > 0.02:
			hat.glow = g
		hat.pivot_offset = hat.size * Vector2(0.5, 1.0)
		hat.scale = Vector2.ONE * (1.0 + (0.12 if n == 2 else 0.06) * pl) if n in [1, 2] else Vector2.ONE

# ------------------------------------------------------------------ top bar

## What the crew's doing now. `title` is short ("Pour · bay 3 of 4"); `sub`
## only when there's something to do that isn't shown anywhere else.
func set_task(title: String, sub := "") -> void:
	var chip := ""
	var t := title
	var dot := title.find(" · ")
	if dot > 0 and dot < 14:
		chip = title.substr(0, dot).to_upper()
		t = title.substr(dot + 3)
	task_chip.text = chip
	task_chip.visible = chip != ""
	task_label.text = t
	task_box.visible = title != ""
	sub_label.text = sub
	sub_label.visible = sub != ""

func set_progress(p: float) -> void:
	UI.set_bar(prog_fill, p)

## The pour clock (in the task bar) and the line pressure (on the pump panel).
func set_stats(timer_text: String, pressure: float, warn := false) -> void:
	clock_label.text = timer_text
	line_label.text = "LINE  %d bar" % int(pressure)
	line_label.add_theme_color_override("font_color", UI.RED if warn else UI.MUTED)
	gauge.bar = pressure

## Lifts everything along the bottom of the screen clear of the street band
## (the split view's strip along the bottom), `h` pixels tall.
func set_bottom_inset(h: float) -> void:
	h = roundf(h)
	if h == _bottom:
		return
	_bottom = h
	UI.place(signal_panel, Vector2(0.5, 1), Vector2(0, -36 - h))
	UI.place(bolt_panel, Vector2(0.5, 1), Vector2(0, -110 - h))
	UI.place(_pause_hint, Vector2(0, 1), Vector2(16, -12 - h))
	UI.place(crew_bar, Vector2(0, 1), Vector2(16, -36 - h))
	if facts != null:
		UI.place(facts, Vector2(0.5, 1), Vector2(0, -60 - h))

func set_gauge(spike: bool, tripped: bool) -> void:
	gauge.spike = spike
	gauge.tripped = tripped

func set_floor(done: int, total: int) -> void:
	level_label.text = "L%d/%d" % [mini(done + 1, total), total]

## Crew points, counting up to the real total, with the rank ladder under it.
func set_score(total: int, rank: String, next_rank: String, frac: float, bump: float) -> void:
	_shown_score = move_toward(_shown_score, total, maxf(4.0, absf(total - _shown_score) * 0.18))
	score_label.text = "$" + UI.thousands(int(_shown_score))
	score_label.pivot_offset = score_label.size * Vector2(1.0, 0.5)
	score_label.scale = Vector2.ONE * (1.0 + 0.15 * bump)
	rank_label.text = rank.to_upper() + ("  →  " + next_rank if next_rank != "" else "")
	UI.set_bar(rank_bar, frac)

static func _thousands(n: int) -> String:
	return UI.thousands(n)

func rank_up(rank: String) -> void:
	if rank_banner == null:
		rank_banner = UI.panel(UI.YELLOW, 16, Color(0, 0, 0, 0), 0, Vector4(26, 10, 26, 12))
		_root.add_child(rank_banner)
		UI.place(rank_banner, Vector2(0.5, 0.5), Vector2(0, -90))
		rank_banner_label = UI.label("", 44, UI.INK, 0)
		rank_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_banner.add_child(rank_banner_label)
	rank_banner_label.text = "RANK UP  ·  " + rank.to_upper()
	rank_banner.visible = true
	_rank_t = 2.4

# ------------------------------------------------------------------ side panels

## Pump panel: hopper, the trucks at the pump, the line pressure.
func set_pump(on: bool, info := {}) -> void:
	pump_panel.visible = on
	if not on:
		return
	var fill: float = info.get("hopper", 0.0)
	var c := UI.GREEN
	if fill < 0.2:
		c = UI.RED
	elif fill < 0.45:
		c = UI.YELLOW
	hopper_fill.color = c
	UI.set_bar(hopper_fill, fill)
	hopper_pct.text = "%d%%   ·   %s" % [int(fill * 100.0), "HIGH" if info.get("high", true) else "LOW"]
	hopper_pct.add_theme_color_override("font_color", c)
	# Just the counts: what each truck needs doing is on the job list
	var bits := []
	var at := int(info.get("bay", "") != "") + int(info.get("standby", "") != "")
	bits.append("TRUCKS  %d at the pump" % at)
	var q: int = info.get("queue", 0)
	bits.append("%d on the road" % q if q > 0 else "next in %ds" % int(info.get("next", 0.0)))
	trucks_label.text = "  ·  ".join(bits)

func set_wind(gust_kmh: float, mean_kmh: float, stop_kmh: float, show := true) -> void:
	wind_panel.visible = show
	if not show:
		return
	wind_label.text = "WIND  %d km/h  ·  gust %d" % [int(mean_kmh), int(gust_kmh)]
	var c := UI.GREEN
	if gust_kmh >= stop_kmh:
		c = UI.RED
	elif gust_kmh >= stop_kmh * 0.75:
		c = UI.YELLOW
	wind_label.add_theme_color_override("font_color", c)
	wind_bar.color = c
	wind_bar.size.x = 190.0 * clampf(gust_kmh / 80.0, 0.0, 1.0)

## Live jobs: [{icon, text, frac (0..1 left), color, urgent}]
func set_tickets(list: Array, t: float) -> void:
	for i in tickets.size():
		var slot: Dictionary = tickets[i]
		var panel: PanelContainer = slot["panel"]
		panel.visible = i < list.size()
		if not panel.visible:
			continue
		var tk: Dictionary = list[i]
		var icon: PanelContainer = slot["icon"]
		var col: Color = tk.get("color", ORANGE)
		UI.style(icon).bg_color = col
		(icon.get_meta("label") as Label).text = tk.get("icon", "!")
		# Whose job it is: that job's icon in its colour; anything else keeps a letter
		var role: String = tk.get("role", "")
		var jicon: TextureRect = slot["jicon"]
		jicon.visible = role != ""
		icon.visible = role == ""
		if role != "":
			jicon.texture = Icons.outlined(role, 64)
			jicon.modulate = col
		(slot["label"] as Label).text = tk.get("text", "")
		var frac: float = clampf(tk.get("frac", 1.0), 0.0, 1.0)
		var fill: ColorRect = slot["fill"]
		UI.set_bar(fill, frac)
		fill.color = tk["bar"] if tk.has("bar") else (UI.RED if frac < 0.25 else (UI.YELLOW if frac < 0.5 else UI.GREEN))
		var urgent: bool = tk.get("urgent", false)
		var sb := UI.style(panel)
		sb.border_color = col if urgent else UI.EDGE
		sb.set_border_width_all(2 if urgent else 1)
		panel.modulate = Color(1, 1, 1, 1) if not urgent else Color(1, 0.9 + 0.1 * sin(t * 10.0), 0.9 + 0.1 * sin(t * 10.0), 1)

# ------------------------------------------------------------------ call-outs

func set_alert(text: String) -> void:
	_alert = text
	if text != "":
		toast_label.text = text
		toast_label.add_theme_color_override("font_color", UI.RED)
	elif _toast_t <= 0.0:
		toast_panel.visible = false

func toast(text: String, seconds := 2.2) -> void:
	if _alert != "":
		return
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", UI.YELLOW)
	_toast_t = seconds
	toast_panel.visible = true
	toast_panel.modulate.a = 1.0

func set_signal(text: String, color := Color.WHITE) -> void:
	signal_label.text = text
	signal_label.add_theme_color_override("font_color", color)
	signal_panel.visible = text != ""

func show_bolt(on: bool, bolt := 1, total := 4, zone_from := 0.6, zone_w := 0.18, marker := 0.0) -> void:
	show_meter(on, "BOLT %d / %d" % [bolt, total], "", zone_from, zone_w, marker)

func show_meter(on: bool, title := "", _hint := "", zone_from := 0.6, zone_w := 0.18, marker := 0.0, button := "A") -> void:
	bolt_panel.visible = on
	if not on:
		return
	bolt_title.text = title
	(bolt_glyph.get_meta("label") as Label).text = button
	UI.style(bolt_glyph).bg_color = UI.GLYPH.get(button, UI.GLYPH["A"])
	UI.style(bolt_glyph).shadow_color = UI.LIP.get(button, UI.LIP["A"])
	# In the gold: the whole zone brightens, so the moment reads at a glance
	var inz := marker >= zone_from and marker <= zone_from + zone_w
	bolt_zone.color = UI.GOLD.lightened(0.35) if inz else UI.GOLD
	bolt_zone.position.x = BOLT_W * zone_from
	bolt_zone.size.x = BOLT_W * zone_w
	bolt_marker.position.x = BOLT_W * clampf(marker, 0.0, 1.0) - 2.5

# ------------------------------------------------------------------ joining

## Phone joining lives on the pause menu (and the front end), not over the game.
func show_join(_on: bool, text := "") -> void:
	if text != "":
		join_hint = text

func set_join(text: String, url := "") -> void:
	join_text = text
	join_url = url

# ------------------------------------------------------------------ cards

## The slab report. `d` is {title, points, quality, verdict, medal (0-2),
## medal_note, crew: [{role, p, bot, name, pts, why}], star (the role of
## the crew star, "" for none), losses: [text], next (what's up next)}.
## `seconds` < 0: it stays up till someone presses A (dismiss_card), with
## the countdown set_report_left moves.
func show_slab(d: Dictionary, seconds := 6.0) -> void:
	for c in _card_box.get_children():
		_card_box.remove_child(c)
		c.queue_free()
	var mcols := [Color("d0884a"), Color("d6dde6"), Color("ffd23f")]
	var mnames := ["BRONZE", "SILVER", "GOLD"]
	var m: int = clampi(int(d.get("medal", 0)), 0, 2)
	# The medal, the points and the quality
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	_card_box.add_child(top)
	var disc := UI.panel(mcols[m], 36, Color(1, 1, 1, 0.85), 3, Vector4(0, 0, 0, 0))
	disc.custom_minimum_size = Vector2(72, 72)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var star := UI.head("★", 40, Color(0, 0, 0, 0.55))
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	disc.add_child(star)
	top.add_child(disc)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	tv.add_child(UI.head(String(d.get("title", "")), 16, UI.DIM))
	var hl := HBoxContainer.new()
	hl.add_theme_constant_override("separation", 18)
	tv.add_child(hl)
	hl.add_child(UI.head(mnames[m], 44, mcols[m]))
	hl.add_child(UI.head("+$" + _thousands(int(d.get("points", 0))), 44, UI.GOLD))
	var q := UI.head("QUALITY %d%%  ·  %s" % [int(d.get("quality", 0)), String(d.get("verdict", "")).to_upper()], 20, UI.BONE)
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hl.add_child(q)
	var note := UI.label(String(d.get("medal_note", "")), 14, UI.DIM, 0)
	tv.add_child(note)
	# The crew: one card per hard hat
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_card_box.add_child(row)
	for r in d.get("crew", []):
		row.add_child(_hat_card(r, String(r["role"]) == String(d.get("star", ""))))
	# What cost quality
	var losses: Array = d.get("losses", [])
	if not losses.is_empty():
		var lf := HFlowContainer.new()
		lf.add_theme_constant_override("h_separation", 8)
		lf.add_theme_constant_override("v_separation", 4)
		lf.custom_minimum_size = Vector2(860, 0)
		_card_box.add_child(lf)
		var lh := UI.head("QUALITY KNOCKED BACK BY", 14, UI.DIM)
		lh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lf.add_child(lh)
		for l in losses.slice(0, 4):
			var pl := UI.pill(Color(UI.ALARM, 0.16), Vector4(10, 2, 10, 3), Color(UI.ALARM, 0.5), 1)
			pl.add_child(UI.label(String(l).replace("   ", "  "), 14, Color("ffb3ad"), 0))
			lf.add_child(pl)
	# Up next, the countdown, and the buttons
	_card_hold = seconds < 0.0
	_card_go = null
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	_card_box.add_child(foot)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 3)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(nv)
	_card_next = UI.head("UP NEXT · " + String(d.get("next", "")).to_upper(), 18, UI.BONE)
	nv.add_child(_card_next)
	var bh := Control.new()
	bh.custom_minimum_size = Vector2(380, 6)
	nv.add_child(bh)
	var tr := ColorRect.new()
	tr.color = UI.TRACK
	tr.size = Vector2(380, 6)
	bh.add_child(tr)
	_card_fill = ColorRect.new()
	_card_fill.color = UI.GOLD
	_card_fill.size = Vector2(380, 6)
	bh.add_child(_card_fill)
	bh.visible = _card_hold
	if _card_hold:
		# (after the last slab there's no next pour: A goes on to the top-out)
		if not d.get("last", false):
			foot.add_child(_kit_button("Y", "SWAP HATS", false))
		_card_go = _kit_button("A", "TOP OUT" if d.get("last", false) else "NEXT POUR", true)
		foot.add_child(_card_go)
	card.visible = true
	card.modulate.a = 1.0
	_card_t = maxf(0.0, seconds)
	_card_age = 0.0
	_refit_card()

## How much of the report's countdown is left (0..1), and the seconds.
func set_report_left(left: float, _secs: float) -> void:
	if _card_fill == null or not _card_hold:
		return
	_card_fill.size.x = 380.0 * clampf(left, 0.0, 1.0)

## A crew member's hard hat card on the report: their points and what
## earned them most; the crew star gets a gold frame and a ribbon.
func _hat_card(r: Dictionary, star: bool) -> PanelContainer:
	var col: Color = UI.ROLE.get(r["role"], UI.WHITE)
	var c := UI.panel(Color(1, 1, 1, 0.05), 10, UI.GOLD if star else Color(1, 1, 1, 0.08), 2 if star else 1, Vector4(8, 8, 8, 8))
	UI.style(c).border_width_top = 5
	if not star:
		UI.style(c).border_color = col
	c.custom_minimum_size = Vector2(138, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	c.add_child(v)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 6)
	v.add_child(th)
	var hat := UI.Hat.new()
	hat.color = col
	hat.custom_minimum_size = Vector2(36, 30)
	hat.dim = bool(r["bot"])
	th.add_child(hat)
	var tag := UI.ptag(int(r["p"]), 14, bool(r["bot"]))
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(tag)
	var jn := UI.head(UI.ROLE_NAME.get(r["role"], "").to_upper(), 15, col)
	jn.clip_text = true
	jn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(jn)
	var pts := int(r["pts"])
	v.add_child(UI.head(("+$" if pts >= 0 else "-$") + _thousands(pts), 26, UI.GOLD if star else UI.BONE))
	if r.has("wallet"):
		# (a person's own share, banked in their wallet)
		var wl := UI.label("%s in %s's wallet" % [("$" + _thousands(int(r["wallet"]))), String(r["name"])], 12, UI.GREEN, 0)
		wl.clip_text = true
		v.add_child(wl)
	var why := UI.label(String(r["why"]), 13, UI.DIM, 0)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.custom_minimum_size = Vector2(122, 34)
	why.max_lines_visible = 2
	v.add_child(why)
	if star:
		var rib := UI.pill(UI.GOLD, Vector4(8, 1, 8, 2))
		rib.add_child(UI.head("★ CREW STAR", 14, Color("2a1d00")))
		rib.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(rib)
	return c

## A Site Kit button with its word: the gold one is the default.
func _kit_button(btn: String, text: String, gold: bool) -> PanelContainer:
	var p := UI.pill(UI.GOLD if gold else Color(1, 1, 1, 0.08), Vector4(8, 5, 16, 5), Color(1, 1, 1, 0.9) if gold else Color(0, 0, 0, 0), 2 if gold else 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	h.add_child(UI.glyph(btn, 30))
	var l := UI.head(text, 22, Color("2a1d00") if gold else UI.BONE)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return p

func card_waiting() -> bool:
	return _card_hold

func card_age() -> float:
	return _card_age

func dismiss_card() -> void:
	if _card_hold:
		_card_hold = false
		_card_t = 0.4

## The truck's docket after a slump test, for the truck hand to read:
## the measured slump against the mix's spec, how long since it was batched
## against the 90 minute limit, and the water the plant held back that may be
## added on site. `d` is {slump, age, help, right}; empty hides it.
var docket: PanelContainer
var _dk_slump: Control
var _dk_age: Control
var _dk_slump_l: Label
var _dk_age_l: Label
var _dk_hints: HBoxContainer
var _dk_key := ""
const DK_SPEC := Vector2(75.0, 150.0)   # accepted slump band, mm (spec 100 mm)
const DK_AGE := 90.0

func _build_docket() -> void:
	docket = UI.panel(Color("f4efe2"), 8, Color("c9bfa4"), 2, Vector4(18, 12, 18, 14))
	docket.custom_minimum_size = Vector2(380, 0)
	_root.add_child(docket)
	_place_docket()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	docket.add_child(v)
	v.add_child(UI.label("DELIVERY DOCKET · N32 mix, spec slump 100 mm", 14, Color("5a5040"), 0))
	_dk_slump_l = UI.label("", 19, UI.INK, 0)
	v.add_child(_dk_slump_l)
	_dk_slump = DocketBar.new()
	_dk_slump.custom_minimum_size = Vector2(344, 18)
	_dk_slump.set("lo", 0.0)
	_dk_slump.set("hi", 200.0)
	_dk_slump.set("band", DK_SPEC)
	v.add_child(_dk_slump)
	_dk_age_l = UI.label("", 19, UI.INK, 0)
	v.add_child(_dk_age_l)
	_dk_age = DocketBar.new()
	_dk_age.custom_minimum_size = Vector2(344, 18)
	_dk_age.set("lo", 0.0)
	_dk_age.set("hi", 120.0)
	_dk_age.set("band", Vector2(0.0, DK_AGE))
	v.add_child(_dk_age)
	var water := UI.label("Water held back at the plant: up to 10 L/m³ may be added on site", 14, Color("5a5040"), 0)
	water.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	water.custom_minimum_size = Vector2(344, 0)
	v.add_child(water)
	_dk_hints = HBoxContainer.new()
	_dk_hints.add_theme_constant_override("separation", 14)
	v.add_child(_dk_hints)
	docket.visible = false

func show_docket(d: Dictionary) -> void:
	if docket == null:
		_build_docket()
	docket.visible = not d.is_empty()
	if d.is_empty():
		_dk_key = ""
		return
	# Sits above the street band when the screen's split
	docket.offset_bottom = -24 - float(d.get("band", 0.0))
	docket.offset_top = docket.offset_bottom - docket.size.y
	var key := "%d|%d|%s|%s" % [int(d["slump"]), int(d["age"]), str(d["help"]), str(d["right"])]
	if key == _dk_key:
		return
	_dk_key = key
	_dk_slump_l.text = "Slump measured: %d mm" % int(d["slump"])
	_dk_age_l.text = "Batched %d min ago (limit %d)" % [int(d["age"]), int(DK_AGE)]
	_dk_slump.set("value", float(d["slump"]))
	_dk_age.set("value", float(d["age"]))
	_dk_slump.set("help", d["help"])
	_dk_age.set("help", d["help"])
	_dk_slump.queue_redraw()
	_dk_age.queue_redraw()
	for c in _dk_hints.get_children():
		_dk_hints.remove_child(c)
		c.queue_free()
	for h in [["A", "use it", "use"], ["X", "add water", "water"], ["B", "send it back", "reject"]]:
		var hint := UI.hint(h[0], h[1], 16)
		for c in hint.get_children():
			if c is Label:
				(c as Label).add_theme_color_override("font_color", UI.INK)
				(c as Label).add_theme_constant_override("outline_size", 0)
		if d["help"] and d["right"] != h[2]:
			hint.modulate = Color(1, 1, 1, 0.35)
		_dk_hints.add_child(hint)

## The line pressure gauge: a half dial, green to red, with the needle. On a
## spike the dial flashes red and the needle shakes in the red.
class Gauge extends Control:
	const MAX_BAR := 250.0
	var bar := 0.0
	var spike := false
	var tripped := false
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y - 6.0)
		var r := minf(size.x * 0.5 - 6.0, size.y - 12.0)
		if spike and fmod(_t, UI.SHAKE_T * 2.0) < UI.SHAKE_T:
			draw_rect(Rect2(Vector2.ZERO, size), Color(UI.ALARM, 0.3))
		# green to 120 bar, amber to 180, red above
		var bands := [[0.0, 120.0, UI.DONE], [120.0, 180.0, Color("f2b51f")], [180.0, MAX_BAR, UI.ALARM]]
		for b in bands:
			var a0 := PI + PI * float(b[0]) / MAX_BAR
			var a1 := PI + PI * float(b[1]) / MAX_BAR
			draw_arc(c, r, a0, a1, 24, b[2], 7.0, true)
		var v := clampf(bar / MAX_BAR, 0.0, 1.0)
		if spike:
			v = clampf(v + 0.015 * sin(_t * 70.0), 0.0, 1.0)
		var ang := PI + PI * v
		var tip := c + Vector2(cos(ang), sin(ang)) * (r - 4.0)
		draw_line(c, tip, Color.WHITE, 3.5, true)
		draw_circle(c, 5.0, Color.WHITE)
		var font := UI.font("head")
		var txt := "KILL IT" if spike else ("TRIPPED · RESTART" if tripped else "%d bar" % int(bar))
		var col := Color("ff6b5f") if spike else (Color("f2b51f") if tripped else Color("c9c6bd"))
		var fs := 18
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var gw := 26.0 if spike else 0.0
		var x0 := c.x - (tw + gw) * 0.5
		var ty := c.y - r * 0.35
		if spike:
			# The A to press, as the Site Kit button
			var gc := Vector2(x0 + 10.0, ty - fs * 0.32)
			var k := 1.0 + 0.1 * (0.5 - 0.5 * cos(_t * TAU / UI.GOLD_T))
			draw_circle(gc + Vector2(0, 1), 12.0 * k, Color.WHITE, true, -1.0, true)
			draw_circle(gc + Vector2(0, 2.5), 10.5 * k, UI.LIP["A"], true, -1.0, true)
			draw_circle(gc, 10.5 * k, UI.GLYPH["A"], true, -1.0, true)
			var aw := font.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(font, gc + Vector2(-aw * 0.5, 5.5), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.GLYPH_INK["A"])
		draw_string(font, Vector2(x0 + gw, ty), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## A docket gauge: the scale, the accepted band in green, and a marker.
class DocketBar extends Control:
	var lo := 0.0
	var hi := 1.0
	var band := Vector2.ZERO
	var value := 0.0
	var help := false
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, h * 0.3, w, h * 0.4), Color("d9d0bb"))
		var a := (band.x - lo) / (hi - lo) * w
		var b := (band.y - lo) / (hi - lo) * w
		draw_rect(Rect2(a, h * 0.3, b - a, h * 0.4), Color("7cbf8a"))
		var x := clampf((value - lo) / (hi - lo), 0.0, 1.0) * w
		var inside := value >= band.x and value <= band.y
		var mc := (Color("1f6f3a") if inside else Color("c0392b")) if help else Color("0f1b2d")
		draw_rect(Rect2(x - 3, 0, 6, h), mc)

## Grow (or shrink) the report card round whatever's in it now.
func _refit_card() -> void:
	UI.place(card, Vector2(0.5, 0.5), Vector2(0, 20))
	card.reset_size()

## The toolbox talk: what the day's like, the pour plan, and each job's
## first move with its button and who's on it. `d` is {title, plan, chips:
## [[text, "hot"/"warn"/""]], moves: [{role, btn, text, p, bot}], wait}.
## With `wait` it shows the hold-A bar (anyone can hold it) and the
## countdown till it starts itself; set_toolbox moves them.
var _tb_box: VBoxContainer
var _tb_fill: ColorRect
var _tb_hold: HoldGlyph
var _tb_left: Label

func style_brief() -> void:
	var sb := UI.style(brief)
	sb.border_width_top = 8
	sb.border_color = UI.GOLD
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18

func show_brief(on: bool, _text := "", _wait := false) -> void:
	if not on:
		brief.visible = false

func show_toolbox(d: Dictionary) -> void:
	for c in _tb_box.get_children():
		_tb_box.remove_child(c)
		c.queue_free()
	var ink := Color("1d1a14")
	var soft := Color("6b6252")
	_tb_box.add_child(UI.head(String(d.get("title", "")), 16, soft))
	var plan := UI.head(String(d.get("plan", "")), 30, ink)
	plan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plan.custom_minimum_size = Vector2(712, 0)
	_tb_box.add_child(plan)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 6)
	_tb_box.add_child(chips)
	for ch in d.get("chips", []):
		var kind: String = ch[1]
		var bg: Color = UI.ALARM if kind == "hot" else (UI.GOLD if kind == "warn" else Color("e2dccb"))
		var fg: Color = Color.WHITE if kind == "hot" else (Color("2a1d00") if kind == "warn" else ink)
		var pill := UI.pill(bg, Vector4(12, 3, 12, 4))
		pill.add_child(UI.head(String(ch[0]), 17, fg))
		chips.add_child(pill)
	var notes: Array = d.get("notes", [])
	for n in notes:
		var nl := UI.label(String(n), 15, soft, 0)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size = Vector2(712, 0)
		_tb_box.add_child(nl)
	var rule := ColorRect.new()
	rule.color = Color("d9d0bb")
	rule.custom_minimum_size = Vector2(712, 2)
	_tb_box.add_child(rule)
	_tb_box.add_child(UI.head("FIRST MOVES", 15, soft))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 8)
	_tb_box.add_child(grid)
	for m in d.get("moves", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(345, 0)
		var hat := UI.Hat.new()
		hat.color = UI.ROLE.get(m["role"], UI.WHITE).darkened(0.08)
		hat.custom_minimum_size = Vector2(34, 28)
		hat.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(hat)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		row.add_child(v)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 6)
		v.add_child(top)
		top.add_child(UI.head(UI.ROLE_NAME.get(m["role"], m["role"]).to_upper(), 17, ink))
		var tag := UI.ptag(int(m["p"]), 13, bool(m["bot"]))
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(tag)
		var how := HBoxContainer.new()
		how.add_theme_constant_override("separation", 6)
		v.add_child(how)
		var g := UI.glyph(String(m["btn"]), 22)
		g.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		how.add_child(g)
		var t := UI.label(String(m["text"]), 14, ink, 0)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(270, 0)
		how.add_child(t)
		grid.add_child(row)
	_tb_hold = null
	if d.get("wait", false):
		var bar_holder := Control.new()
		bar_holder.custom_minimum_size = Vector2(712, 6)
		_tb_box.add_child(bar_holder)
		var track := ColorRect.new()
		track.color = Color("e2dccb")
		track.size = Vector2(712, 6)
		bar_holder.add_child(track)
		_tb_fill = ColorRect.new()
		_tb_fill.color = UI.GOLD.darkened(0.08)
		_tb_fill.size = Vector2(712, 6)
		bar_holder.add_child(_tb_fill)
		var foot := HBoxContainer.new()
		foot.add_theme_constant_override("separation", 10)
		_tb_box.add_child(foot)
		_tb_left = UI.head("STARTS ITSELF IN 20s", 16, soft)
		_tb_left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tb_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(_tb_left)
		_tb_hold = HoldGlyph.new()
		_tb_hold.custom_minimum_size = Vector2(46, 46)
		foot.add_child(_tb_hold)
		var go := UI.head("ANYONE: HOLD A TO START", 24, ink)
		go.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		foot.add_child(go)
	brief.visible = true
	brief.reset_size()
	UI.place(brief, Vector2(0.5, 0.5), Vector2(0, 20))

## The toolbox talk's hold (0..1) and how much of its countdown is left (0..1).
func set_toolbox(hold: float, left: float, secs: float) -> void:
	if _tb_hold == null or not brief.visible:
		return
	_tb_hold.prog = hold
	_tb_fill.size.x = 712.0 * clampf(left, 0.0, 1.0)
	_tb_left.text = "STARTS ITSELF IN %ds" % int(ceil(secs))

## The big hold A over a person's head for a long hold out on site (the
## slurry and the washout into the bin): the same A as the toolbox talk's,
## filling with concrete as the job's done, the gold ring going round, and
## the job's word beside it.
var _big_hold: HBoxContainer
var _big_glyph: HoldGlyph
var _big_word: Label

## `drain`: the washout's A starts full of water and drains as it's done.
func show_big_hold(at: Vector2, prog: float, text: String, drain := false) -> void:
	if _big_hold == null:
		_big_hold = HBoxContainer.new()
		_big_hold.add_theme_constant_override("separation", 6)
		_big_hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(_big_hold)
		_big_glyph = HoldGlyph.new()
		_big_glyph.custom_minimum_size = Vector2(78, 78)
		_big_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_big_hold.add_child(_big_glyph)
		var pill := UI.panel(UI.CARD, 12, UI.EDGE, 1, Vector4(12, 5, 12, 5))
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_big_hold.add_child(pill)
		_big_word = UI.head("", 22, UI.GOLD)
		pill.add_child(_big_word)
	_big_hold.visible = true
	_big_glyph.prog = maxf(prog, 0.001)
	_big_glyph.drain = drain
	_big_word.text = text
	_big_hold.reset_size()
	_big_hold.position = at - Vector2(39, 39)

func hide_big_hold() -> void:
	if _big_hold != null:
		_big_hold.visible = false

## A Site Kit A that fills with concrete while it's held, ringed in gold.
class HoldGlyph extends Control:
	var prog := 0.0
	var drain := false     # full of water at the start, emptying as it goes
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var pl := 0.5 - 0.5 * cos(_t * TAU / (UI.URGENT_T if prog > 0.0 else UI.BREATHE_T))
		var k := 1.0 + (UI.URGENT_S - 1.0 if prog > 0.0 else UI.BREATHE_S - 1.0) * pl
		var r := minf(size.x, size.y) * 0.34 * k
		draw_arc(c, r + 7.0, 0, TAU, 40, UI.TRACK, 4.0, true)
		if prog > 0.0:
			draw_arc(c, r + 7.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(prog, 0.0, 1.0), 40, UI.GOLD, 4.0, true)
		draw_circle(c + Vector2(0, 1.5), r + 2.0, Color.WHITE, true, -1.0, true)
		draw_circle(c + Vector2(0, 3.0), r, UI.LIP["A"], true, -1.0, true)
		draw_circle(c, r, UI.GLYPH["A"], true, -1.0, true)
		var level := (1.0 - clampf(prog, 0.0, 1.0)) if drain else clampf(prog, 0.0, 1.0)
		if level > 0.0 and (prog > 0.0 or drain):
			var top := r - 2.0 * r * level
			var pts := PackedVector2Array()
			for i in 33:
				var a := TAU * i / 32.0
				var p := Vector2(cos(a), sin(a)) * r
				if p.y < top:
					p.y = top
				pts.append(c + p)
			draw_colored_polygon(pts, Color(0.3, 0.62, 0.95, 0.8) if drain else Color(0.62, 0.61, 0.58, 0.75))
		var f := UI.font("head")
		var fs := int(r * 1.25)
		var w := f.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-w * 0.5, fs * 0.36), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.GLYPH_INK["A"])

func show_topout(text: String) -> void:
	banner.visible = true
	facts.visible = true
	facts_label.text = text

func hide_topout() -> void:
	banner.visible = false
	facts.visible = false


## At big screen-text sizes the job tickets drop below the task bar, so the
## three panels along the top never collide.
var _ticket_scale := -1.0

## At big text the docket centres, between the job tickets and the pump panel.
func _place_docket() -> void:
	if docket == null:
		return
	if get_tree().root.content_scale_factor >= 1.4:
		UI.place(docket, Vector2(0.5, 1), Vector2(0, -24))
	else:
		UI.place(docket, Vector2(0.5, 1), Vector2(-120, -24))

func _place_tickets() -> void:
	var sc: float = get_tree().root.content_scale_factor
	if sc == _ticket_scale or ticket_box == null:
		return
	_ticket_scale = sc
	UI.place(ticket_box, Vector2(0, 0), Vector2(16, 14 if sc < 1.4 else 130))
	# Big text: the task bar steps left of the score panel, and the docket
	# goes to the bottom right, clear of the tickets
	var big: bool = sc >= 1.4
	UI.place(task_box, Vector2(0.5, 0), Vector2(-70 if big else 0, 14))
	_place_docket()

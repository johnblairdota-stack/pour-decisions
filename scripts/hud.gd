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
const BOLT_W := 320.0
# cards
var card: PanelContainer
var _card_t := 0.0
var _card_title: Label
var _card_head: Label
var _card_quality: Label
var _card_cols: HBoxContainer
var _medal_row: HBoxContainer
var _medal_disc: PanelContainer
var _medal_name: Label
var _medal_note: Label
var brief: PanelContainer
var _brief_title: Label
var _brief_lines: VBoxContainer
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
	bolt_title = UI.label("", 18, UI.YELLOW)
	bv.add_child(bolt_title)
	var bb := Control.new()
	bb.custom_minimum_size = Vector2(BOLT_W, 18)
	bv.add_child(bb)
	var bbg := ColorRect.new()
	bbg.color = Color(1, 1, 1, 0.15)
	bbg.size = Vector2(BOLT_W, 18)
	bb.add_child(bbg)
	bolt_zone = ColorRect.new()
	bolt_zone.color = UI.YELLOW
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

	# --- Slab report
	card = UI.panel(UI.GLASS_SOLID, 16, UI.YELLOW, 2, Vector4(24, 18, 24, 18))
	card.custom_minimum_size = Vector2(620, 0)
	_root.add_child(card)
	UI.place(card, Vector2(0.5, 0.5), Vector2(0, 30))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	_card_title = UI.label("", 15, UI.MUTED, 0)
	cv.add_child(_card_title)
	var chh := HBoxContainer.new()
	chh.add_theme_constant_override("separation", 26)
	cv.add_child(chh)
	_card_head = UI.label("", 44, UI.YELLOW, 4)
	chh.add_child(_card_head)
	_card_quality = UI.label("", 22, UI.WHITE, 3)
	_card_quality.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chh.add_child(_card_quality)
	# The slab's medal: a disc in bronze, silver or gold, and what the next ones take
	_medal_row = HBoxContainer.new()
	_medal_row.add_theme_constant_override("separation", 12)
	cv.add_child(_medal_row)
	_medal_disc = UI.panel(Color.WHITE, 24, Color(0, 0, 0, 0.35), 3, Vector4(0, 0, 0, 0))
	_medal_disc.custom_minimum_size = Vector2(48, 48)
	_medal_row.add_child(_medal_disc)
	var star := UI.label("★", 26, UI.INK, 0)
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_medal_disc.add_child(star)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 0)
	_medal_row.add_child(mv)
	_medal_name = UI.label("", 26, UI.WHITE, 3)
	mv.add_child(_medal_name)
	_medal_note = UI.label("", 15, UI.MUTED, 0)
	mv.add_child(_medal_note)
	_medal_row.visible = false
	_card_cols = HBoxContainer.new()
	_card_cols.add_theme_constant_override("separation", 30)
	cv.add_child(_card_cols)
	card.visible = false

	# --- Pre-pour briefing
	brief = UI.panel(UI.GLASS_SOLID, 16, UI.EDGE, 2, Vector4(22, 16, 22, 18))
	brief.custom_minimum_size = Vector2(520, 0)
	_root.add_child(brief)
	UI.place(brief, Vector2(0.5, 0.5), Vector2(0, 40))
	var bv2 := VBoxContainer.new()
	bv2.add_theme_constant_override("separation", 8)
	brief.add_child(bv2)
	_brief_title = UI.label("", 15, UI.MUTED, 0)
	bv2.add_child(_brief_title)
	_brief_lines = VBoxContainer.new()
	_brief_lines.add_theme_constant_override("separation", 6)
	bv2.add_child(_brief_lines)
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
	if _toast_t > 0.0:
		_toast_t -= delta
		toast_panel.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
		if _toast_t <= 0.0 and _alert == "":
			toast_panel.visible = false
	if _alert != "":
		toast_panel.visible = true
		toast_panel.modulate.a = 1.0
	if _card_t > 0.0:
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

func set_floor(done: int, total: int) -> void:
	level_label.text = "L%d/%d" % [mini(done + 1, total), total]

## Crew points, counting up to the real total, with the rank ladder under it.
func set_score(total: int, rank: String, next_rank: String, frac: float, bump: float) -> void:
	_shown_score = move_toward(_shown_score, total, maxf(4.0, absf(total - _shown_score) * 0.18))
	score_label.text = UI.thousands(int(_shown_score))
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

func show_meter(on: bool, title := "", _hint := "", zone_from := 0.6, zone_w := 0.18, marker := 0.0) -> void:
	bolt_panel.visible = on
	if not on:
		return
	bolt_title.text = title
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

## Old-style card (title, headline, body text).
func show_card(title: String, headline: String, body: String, seconds := 5.0) -> void:
	show_report(title, headline, "", Array(body.split("\n")), [], seconds)

## The slab report: points, quality, what earned them, what cost quality.
func show_report(title: String, headline: String, quality_text: String, gains: Array, losses: Array, seconds := 6.0) -> void:
	_card_title.text = title
	_card_head.text = headline
	_card_quality.text = quality_text
	_medal_row.visible = false
	for c in _card_cols.get_children():
		_card_cols.remove_child(c)
		c.queue_free()
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	_card_cols.add_child(left)
	# (the biggest few, and the rest summed, so the card never overflows)
	var shown := 0
	var rest := 0
	for r in gains:
		if String(r) == "":
			continue
		if shown < 6:
			left.add_child(_row(r, UI.WHITE))
			shown += 1
		else:
			var tail := String(r).rsplit("   ", true, 1)
			if tail.size() > 1:
				rest += int(tail[1].strip_edges().replace("+", ""))
	if rest != 0:
		left.add_child(_row("Everything else   %s%d" % ["+" if rest > 0 else "", rest], UI.MUTED))
	if not losses.is_empty():
		var right := VBoxContainer.new()
		right.add_theme_constant_override("separation", 2)
		_card_cols.add_child(right)
		right.add_child(UI.label("QUALITY KNOCKED BACK BY", 12, UI.MUTED, 0))
		for r in losses:
			right.add_child(_row(r, Color("ff9a9a")))
	card.visible = true
	card.modulate.a = 1.0
	_card_t = seconds
	_refit_card()

## The truck's docket after a slump test, for the pump operator to read:
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

## Adds the slab's medal to the report that's showing.
func show_medal(m: int, note: String) -> void:
	var cols := [Color("d0884a"), Color("d6dde6"), Color("ffd23f")]
	var names := ["BRONZE", "SILVER", "GOLD"]
	UI.style(_medal_disc).bg_color = cols[m]
	_medal_name.text = names[m]
	_medal_name.add_theme_color_override("font_color", cols[m])
	_medal_note.text = note
	_medal_row.visible = true
	_refit_card()

## Grow (or shrink) the report card round whatever's in it now.
func _refit_card() -> void:
	UI.place(card, Vector2(0.5, 0.5), Vector2(0, 30))
	card.reset_size()

func _row(text: String, col: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var parts := text.rsplit("   ", true, 1)
	h.custom_minimum_size = Vector2(340, 0)
	var a := UI.label(parts[0].strip_edges(), 18, col, 0)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.clip_text = true
	a.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(a)
	if parts.size() > 1:
		var b := UI.label(parts[1].strip_edges(), 18, UI.YELLOW if col == UI.WHITE else col, 0)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.custom_minimum_size = Vector2(60, 0)
		h.add_child(b)
	return h

## Pre-pour briefing: a title line, then one row per point.
func show_brief(on: bool, text := "") -> void:
	brief.visible = on
	if not on:
		return
	var lines := Array(text.split("\n"))
	_brief_title.text = lines[0] if not lines.is_empty() else ""
	for c in _brief_lines.get_children():
		_brief_lines.remove_child(c)
		c.queue_free()
	for l in lines.slice(1):
		var s := String(l)
		if s.strip_edges() == "":
			continue
		var warn := s.begins_with("HOT") or s.begins_with("SHOWER") or s.begins_with("TRAFFIC") or s.begins_with("GUSTY")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var dot := ColorRect.new()
		dot.color = UI.YELLOW if warn else UI.MUTED
		dot.custom_minimum_size = Vector2(4, 20)
		row.add_child(dot)
		var lab := UI.label(s, 19, UI.WHITE, 0)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(460, 0)
		row.add_child(lab)
		_brief_lines.add_child(row)

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

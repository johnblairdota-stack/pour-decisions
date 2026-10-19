## Esc (or a pad's Start, or the phone's menu button) calls smoko: the whole
## site stops. Back to work is the gold default (A, or B from anywhere on the
## first page); from here people swap jobs, add a player off the QR, change
## the settings, start again or knock off. On the right, the job ticket of
## whoever's playing (or the QR while "Add a player" is picked), and how the
## day's going along the bottom. Settings are kept between sessions.
extends CanvasLayer

const UI := preload("res://scripts/ui.gd")
const QR := preload("res://scripts/qr.gd")
const Settings := preload("res://scripts/settings.gd")

const SCALES := [1.0, 1.25, 1.5]
const MAIN := [["Back to work", "resume"], ["Swap jobs", "swap"], ["Add a player", "join"], ["Settings", "settings"],
	["Start again", "restart"], ["Knock off", "quit"]]
const SETTINGS := ["incidents", "gold_assist", "docket_help", "ui_scale", "world_text", "split", "fullscreen", "sound", "shake",
	"real_names", "cam_test", "back"]
const PAGE_TITLE := {"main": "SMOKO", "settings": "SETTINGS", "swap": "SWAP JOBS"}

var game
var _items: Array = []         # {button, action, label}
var _index := 0
var _page := "main"            # main, settings or swap
var _who := 1                  # the player whose menu press it was (swaps move them)
var _title: Label
var _sub: Label
var _list: VBoxContainer
var _note: Label
var _right: VBoxContainer
var _stats: HBoxContainer
var _qr_url := ""
var _cool := 0.0
var _t := 0.0

static func apply_ui_scale(tree: SceneTree) -> void:
	tree.root.content_scale_factor = float(Settings.value("ui_scale"))

func setup(owner_game) -> void:
	game = owner_game
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	add_child(outer)
	UI.place(outer, Vector2(0.5, 0.5), Vector2(0, 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	outer.add_child(row)
	var left := UI.panel(UI.CARD, 16, UI.EDGE, 1, Vector4(22, 16, 22, 18))
	left.custom_minimum_size = Vector2(350, 0)
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(left)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	left.add_child(v)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	v.add_child(th)
	var cup := UI.Hat.new()
	cup.color = UI.GOLD
	cup.custom_minimum_size = Vector2(44, 36)
	th.add_child(cup)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -4)
	th.add_child(tv)
	_title = UI.head("SMOKO", 46, UI.GOLD)
	tv.add_child(_title)
	_sub = UI.head("", 16, UI.DIM)
	tv.add_child(_sub)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 5)
	v.add_child(_list)
	_note = UI.label("", 14, UI.DIM, 0)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(306, 0)
	v.add_child(_note)
	var hints := HBoxContainer.new()
	hints.add_theme_constant_override("separation", 16)
	v.add_child(hints)
	hints.add_child(UI.hint("A", "CHOOSE", 15))
	hints.add_child(UI.hint("B", "BACK", 15))
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 10)
	_right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_right)
	_stats = HBoxContainer.new()
	_stats.add_theme_constant_override("separation", 10)
	_stats.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(_stats)
	_build_page("main")

func _unhandled_input(event: InputEvent) -> void:
	if game == null or game.autotest:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F11:
		Settings.toggle_fullscreen()
		if visible:
			_refresh()
		get_viewport().set_input_as_handled()
		return
	var esc: bool = event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE
	var start: bool = event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START
	if esc or start:
		if esc:
			_who = 1
		toggle()
		get_viewport().set_input_as_handled()

func toggle(who := -1) -> void:
	if visible:
		close()
	else:
		if who > 0:
			_who = who
		open()

func open() -> void:
	visible = true
	get_tree().paused = true
	_cool = 0.2
	_build_page("main")

func close() -> void:
	visible = false
	get_tree().paused = false

## Opens straight on a page ("swap" from the slab report's Y).
func open_on(page: String, who := -1) -> void:
	toggle(who)
	if visible and page != "main":
		_build_page(page)

# ------------------------------------------------------------------ pages

func _build_page(page: String) -> void:
	_page = page
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_items.clear()
	var rows: Array = []
	match page:
		"main":
			rows = MAIN
		"settings":
			for a in SETTINGS:
				rows.append(["", a])
		"swap":
			for role in game.crew.ROLES:
				rows.append(["", "role:" + role])
			rows.append(["Back", "back"])
	for it in rows:
		_items.append(_make_row(it[0], it[1]))
	_title.text = PAGE_TITLE.get(page, "SMOKO")
	_index = 0
	if page == "swap":
		# (start on the first job a bot's doing)
		for i in _items.size():
			var a: String = _items[i]["action"]
			if a.begins_with("role:") and game.crew.is_bot(a.substr(5)):
				_index = i
				break
	_refresh()

func _make_row(text: String, action: String) -> Dictionary:
	var b := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	sb.anti_aliasing = true
	b.add_theme_stylebox_override("panel", sb)
	b.custom_minimum_size = Vector2(306, 38)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var lead: Control = null
	if action.begins_with("role:"):
		var hat := UI.Hat.new()
		hat.color = UI.ROLE[action.substr(5)]
		hat.custom_minimum_size = Vector2(30, 24)
		lead = hat
	elif action == "resume":
		lead = UI.glyph("A", 26)
	elif action == "quit":
		lead = UI.glyph("B", 26)
	if lead != null:
		lead.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(lead)
	var l := UI.head(text, 22, UI.BONE)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var tag_box := HBoxContainer.new()
	tag_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tag_box)
	var idx := _items.size()
	b.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseMotion:
			_select(idx)
		elif e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_select(idx)
			_do(action))
	_list.add_child(b)
	return {"button": b, "action": action, "label": l, "tags": tag_box, "style": sb}

func _refresh() -> void:
	var lvl: int = game.k + 1
	_sub.text = ("SITE'S STOPPED · LEVEL %d" % lvl) if _page == "main" else ("P%d · PICK A JOB A BOT'S DOING" % _who if _page == "swap" else "KEPT FOR NEXT TIME")
	for e in _items:
		var l: Label = e["label"]
		var a: String = e["action"]
		var tags: HBoxContainer = e["tags"]
		for c in tags.get_children():
			tags.remove_child(c)
			c.queue_free()
		match a:
			"gold_assist":
				l.text = "Gold assist: %s" % ("on" if Settings.value("gold_assist") else "off")
			"split":
				l.text = "Split screen: %s" % ("auto" if Settings.value("split") else "off")
			"cam_test":
				l.text = "Camera test: %s" % Settings.CAM_TESTS[Settings.cam_test][0]
			"real_names":
				l.text = "Brand names: %s" % ("real" if Settings.value("real_names") else "lookalike")
			"fullscreen":
				l.text = "Full screen: %s" % ("on" if Settings.value("fullscreen") else "off")
			"sound":
				l.text = "Sound: %s" % ("off" if game.sfx.muted else "on")
			"shake":
				l.text = "Screen shake: %s" % ("on" if game.shake_on else "off")
			"incidents":
				l.text = "Incidents: %s" % Settings.INCIDENT_NAMES[int(Settings.value("incidents"))]
			"docket_help":
				l.text = "Load call help: %s" % ("on" if Settings.value("docket_help") else "off")
			"ui_scale":
				l.text = "Screen text: %d%%" % int(round(float(Settings.value("ui_scale")) * 100.0))
			"world_text":
				l.text = "Names & labels: %d%%" % int(round(float(Settings.value("world_text")) * 100.0))
			"back":
				l.text = "Back"
			"join":
				var full: bool = game.crew.humans().size() >= game.crew.MAX_PEOPLE
				l.text = "Add a player" + ("  (crew's full)" if full else "")
			_:
				if a.begins_with("role:"):
					var role := a.substr(5)
					var p = game.crew.crew[role]
					l.text = UI.ROLE_NAME[role]
					var tag := UI.ptag(p.index, 15, p.bot)
					tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					tags.add_child(tag)
	_select(_index)
	_build_right()
	_build_stats()

func _select(i: int) -> void:
	if i < 0 or i >= _items.size():
		return
	var changed := i != _index
	_index = i
	for k in _items.size():
		var e: Dictionary = _items[k]
		var sb: StyleBoxFlat = e["style"]
		var on := k == _index
		var a: String = e["action"]
		var gold := a == "resume"
		sb.bg_color = UI.GOLD if gold else (Color(1, 1, 1, 0.12) if on else Color(1, 1, 1, 0.04))
		sb.border_color = Color.WHITE if on else Color(0, 0, 0, 0)
		sb.set_border_width_all(2 if on else 0)
		var col: Color = Color("2a1d00") if gold else (Color("ff8a84") if a == "quit" else UI.BONE)
		if a.begins_with("role:") and not game.crew.is_bot(a.substr(5)):
			col = UI.DIM
		(e["label"] as Label).add_theme_color_override("font_color", col)
	_note.text = _note_for(_items[_index]["action"])
	if changed:
		_build_right()

# ------------------------------------------------------------------ right side

func _build_right() -> void:
	for c in _right.get_children():
		_right.remove_child(c)
		c.queue_free()
	var a: String = _items[_index]["action"] if not _items.is_empty() else ""
	if a == "join":
		_right.add_child(_join_card())
		return
	var climb: bool = game.k in game.climb_levels() if game.has_method("climb_levels") else false
	var people: Array = game.crew.humans()
	if _page == "swap" and a.begins_with("role:"):
		var role := a.substr(5)
		var p = game.crew.crew[role]
		_right.add_child(UI.head("THE JOB", 16, UI.DIM))
		_right.add_child(UI.job_ticket(role, p.char_name, 0 if p.bot else p.index, false, climb, 400))
		return
	if people.is_empty():
		people = [game.crew.crew["boom"]]
	_right.add_child(UI.head("YOUR JOB" if people.size() == 1 else "YOUR JOBS", 16, UI.DIM))
	var grid := GridContainer.new()
	grid.columns = 1 if people.size() == 1 else 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	_right.add_child(grid)
	var compact: bool = people.size() > 2
	for p in people.slice(0, 4):
		grid.add_child(UI.job_ticket(p.role, p.char_name, 0 if p.bot else p.index, compact, climb and people.size() == 1, 400 if people.size() == 1 else 300))
	if people.size() > 4:
		_right.add_child(UI.label("+%d more on the crew" % (people.size() - 4), 14, UI.DIM, 0))

func _join_card() -> PanelContainer:
	var card := UI.panel(UI.PAPER, 12, UI.EDGE, 0, Vector4(18, 14, 18, 16))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	v.add_child(UI.head("SCAN TO JOIN", 26, Color("1d1a14")))
	var url: String = game.hud.join_url
	var text: String = game.hud.join_text
	if url != _qr_url:
		_qr_url = url
	if url != "":
		var qr := TextureRect.new()
		qr.texture = QR.texture(url, 4)
		qr.custom_minimum_size = Vector2(220, 220)
		qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		v.add_child(qr)
		v.add_child(UI.head(url.replace("http://", ""), 18, Color("1d1a14")))
	var full: bool = game.crew.humans().size() >= game.crew.MAX_PEOPLE
	var msg := text if text != "" else ("Everyone's in (%d players)." % game.crew.MAX_PEOPLE if full else "")
	msg += ("\n" if msg != "" else "") + "Pads: press A. Keyboard P2: press Enter. A new player takes the busiest job a bot's doing."
	var l := UI.label(msg, 15, Color("6b6252"), 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	v.add_child(l)
	return card

## How the day's going: level, points, rank, the pour clock and the crew.
func _build_stats() -> void:
	for c in _stats.get_children():
		_stats.remove_child(c)
		c.queue_free()
	var bits := [["LEVEL", "%d / %d" % [game.k + 1, game.floors()]], ["POINTS", UI.thousands(game.score.total)],
		["RANK", game.score.rank_name()], ["POUR CLOCK", "%d:%02d" % [int(game.pour_clock) / 60, int(game.pour_clock) % 60]],
		["CREW", "%d people · %d bots" % [game.crew.humans().size(), game.crew.ROLES.size() - game.crew.humans().size()]]]
	for b in bits:
		var p := UI.pill(Color(UI.CARD, 0.9), Vector4(14, 4, 14, 5))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		p.add_child(h)
		var k := UI.head(b[0], 14, UI.DIM)
		k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(k)
		h.add_child(UI.head(b[1], 18, UI.BONE))
		_stats.add_child(p)

func _note_for(action: String) -> String:
	match action:
		"resume":
			return "Everyone back on the tools. Anyone can press it."
		"swap":
			return "Move onto a job a bot's doing. The bot takes yours."
		"join":
			return "Another phone scans the code and gets a P tag and a job."
		"settings":
			return "Incidents, gold assist, text size, sound and the rest."
		"restart":
			return "Back to the crew page. Points so far are lost."
		"quit":
			return "Knock off for the day: closes the game."
		"incidents":
			return ["Nothing goes wrong on the line. Just pour.",
				"One clamp or blockage per pour, like a normal day.",
				"Something per bay from level 3. Keep the truck hand busy.",
				"Something every bay, blockages too, from level 1."][int(Settings.value("incidents"))] + "  (from the next pour)"
		"ui_scale":
			return "Bigger HUD and menus, for a big TV across the room."
		"docket_help":
			return "On: after a slump test, the right call (use it, add water, send it back) glows. Off: weigh your reading against the order yourself. (Always on in the tutorial.)"
		"world_text":
			return "Name tags and station labels over the site."
		"split":
			return "Auto: when the crew are far apart (the deck up high, someone down on the street), the screen splits, the deck on top and the street along the bottom. Off: one camera pulls back to take in everyone."
		"cam_test":
			var roles: Array = Settings.CAM_TESTS[Settings.cam_test][1]
			if roles.is_empty():
				return "Try the multiplayer cameras on your own: the camera treats some of the bots as people playing (their buttons show too). Not saved."
			var names: Array = []
			for r in roles:
				names.append(UI.ROLE_NAME.get(r, r))
			return "The camera follows " + ", ".join(names) + " as if people were playing them, plus you. Not saved."
		"real_names":
			return "Real: the real company, building and equipment names (used with permission). Lookalike: made-up names, for showing the game round."
		"gold_assist":
			return "On: a button lights up gold the moment it's the right time, or you're in the right spot, to press it. Off: read the job yourself."
		"fullscreen":
			return "Fill the whole screen. F11 flips it any time."
		"sound":
			return "Site noise, the pump, the radio calls."
		"shake":
			return "The camera kicks on a burst or a whip."
		"back":
			return ""
	if action.begins_with("role:"):
		var role := action.substr(5)
		var p = game.crew.crew[role]
		if not p.bot:
			return "P%d's on this one." % p.index if p.index != _who else "That's your job now."
		var why: String = game.swap_blocked(game.crew.human(_who)) if game.crew.human(_who) != null else ""
		return why if why != "" else "Hold on: A swaps P%d onto it." % _who
	return ""

# ------------------------------------------------------------------ doing

func _do(action: String) -> void:
	if action.begins_with("role:"):
		_swap_to(action.substr(5))
		return
	match action:
		"resume":
			close()
			return
		"swap":
			_build_page("swap")
			return
		"settings":
			_build_page("settings")
			return
		"back":
			_build_page("main")
			return
		"join":
			pass
		"incidents":
			Settings.cycle("incidents", [0, 1, 2, 3])
		"docket_help":
			Settings.put("docket_help", not bool(Settings.value("docket_help")))
		"ui_scale":
			Settings.cycle("ui_scale", SCALES)
			apply_ui_scale(get_tree())
		"world_text":
			Settings.cycle("world_text", SCALES)
			if game.has_method("apply_world_text"):
				game.apply_world_text()
		"gold_assist":
			Settings.put("gold_assist", not bool(Settings.value("gold_assist")))
		"split":
			Settings.put("split", not bool(Settings.value("split")))
		"cam_test":
			Settings.cam_test = (Settings.cam_test + 1) % Settings.CAM_TESTS.size()
		"real_names":
			Settings.put("real_names", not bool(Settings.value("real_names")))
			for n in get_tree().get_nodes_in_group("brand_pumper"):
				(n as Label3D).text = Settings.brand("pumper")
		"fullscreen":
			Settings.toggle_fullscreen()
		"sound":
			game.sfx.toggle_mute()
		"shake":
			game.shake_on = not game.shake_on
		"restart":
			close()
			get_tree().reload_current_scene()
			return
		"quit":
			get_tree().quit()
			return
	_refresh()

func _swap_to(role: String) -> void:
	var me = game.crew.human(_who)
	if me == null or not game.crew.is_bot(role):
		return
	var why: String = game.swap_blocked(me)
	if why != "":
		_note.text = why
		return
	if game.crew.assign(_who, role):
		game.hud.toast("P%d is on the %s job" % [_who, UI.ROLE_NAME[role].to_lower()], 1.6)
		if game.has_method("haptic"):
			game.haptic(game.crew.crew[role], UI.BUZZ["done"])
		_build_page("main")

# ------------------------------------------------------------------ input

var phone_y := 0.0
var _phone_a := false
var _phone_b := false

## A phone's buttons while the menu's up: A chooses, B goes back. `who` is
## the phone's player number, so a swap moves them.
func phone_button(b: String, who := -1) -> void:
	if who > 0:
		_who = who
	if b == "A":
		_phone_a = true
	elif b == "B":
		_phone_b = true

func _process(delta: float) -> void:
	if not visible:
		phone_y = 0.0
		return
	_t += delta
	_cool = maxf(0.0, _cool - delta)
	var y := 0.0
	var pressed := false
	var back := false
	for i in range(1, 7):
		var p := "p%d_" % i
		if not InputMap.has_action(p + "up"):
			continue
		var ay := Input.get_axis(p + "up", p + "down")
		var pa := Input.is_action_just_pressed(p + "action")
		var pb := Input.is_action_just_pressed(p + "leave")
		if absf(ay) > 0.5 or pa or pb:
			if game.crew.human(i) != null:
				_who = i
		y += ay
		pressed = pressed or pa
		back = back or pb
	# Phones steer the menu too (their stick and buttons arrive here)
	y += phone_y
	pressed = pressed or _phone_a
	back = back or _phone_b
	_phone_a = false
	_phone_b = false
	if _cool <= 0.0 and absf(y) > 0.5:
		_select(clampi(_index + int(signf(y)), 0, _items.size() - 1))
		_cool = 0.2
	if pressed and _cool <= 0.0:
		_cool = 0.2
		_do(_items[_index]["action"])
	elif back and _cool <= 0.0:
		_cool = 0.2
		if _page == "main":
			close()
		else:
			_build_page("main")
	# The gold default breathes, like every gold button
	if not _items.is_empty():
		var b: Control = _items[0]["button"]
		if _page == "main":
			b.pivot_offset = b.size * 0.5
			b.scale = Vector2.ONE * (1.0 + 0.025 * (0.5 - 0.5 * cos(_t * TAU / UI.BREATHE_T)))
		else:
			b.scale = Vector2.ONE

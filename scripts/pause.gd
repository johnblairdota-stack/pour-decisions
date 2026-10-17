## Esc (or a pad's Start) pauses the whole site. The menu: carry on, your job
## (what each button does in it, pour and climb day), the controls and phone
## joining, the settings (incidents, UI size, labels in the world, sound,
## shake), start again, or quit. Settings are kept between sessions.
extends CanvasLayer

const UI := preload("res://scripts/ui.gd")
const QR := preload("res://scripts/qr.gd")
const Icons := preload("res://scripts/icons.gd")
const Settings := preload("res://scripts/settings.gd")

const SCALES := [1.0, 1.25, 1.5]

var game
var _items: Array = []         # {button, action}
var _index := 0
var _panel: PanelContainer
var _list: VBoxContainer
var _controls: PanelContainer
var _job: PanelContainer
var _job_box: VBoxContainer
var _note: Label
var _qr: TextureRect
var _join: Label
var _qr_url := ""
var _cool := 0.0
var _side := "job"             # which card is open on the right: job or controls

static func apply_ui_scale(tree: SceneTree) -> void:
	tree.root.content_scale_factor = float(Settings.value("ui_scale"))

func setup(owner_game) -> void:
	game = owner_game
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.08, 0.66)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	add_child(row)
	UI.place(row, Vector2(0.5, 0.5), Vector2(0, 0))
	_panel = UI.panel(UI.GLASS_SOLID, 18, UI.YELLOW, 2, Vector4(26, 20, 26, 22))
	_panel.custom_minimum_size = Vector2(360, 0)
	row.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	v.add_child(UI.label("PAUSED", 44, UI.YELLOW))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 5)
	v.add_child(_list)
	var rows := [["Carry on", "resume"], ["Your job", "job"], ["Controls & joining", "controls"],
		["", "incidents"], ["", "gold_assist"], ["", "real_names"], ["", "split"], ["", "cam_test"], ["", "docket_help"], ["", "ui_scale"], ["", "world_text"], ["", "fullscreen"], ["", "sound"], ["", "shake"],
		["Start again", "restart"], ["Quit", "quit"]]
	for it in rows:
		var b := Button.new()
		b.text = it[0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 21)
		b.custom_minimum_size = Vector2(308, 40)
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(1, 1, 1, 0.05)
			sb.set_corner_radius_all(10)
			sb.content_margin_left = 14
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(_do.bind(it[1]))
		b.mouse_entered.connect(_select.bind(_items.size()))
		_list.add_child(b)
		_items.append({"button": b, "action": it[1]})
	_note = UI.label("", 14, UI.MUTED, 0)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(308, 38)
	v.add_child(_note)
	v.add_child(UI.hint("A", "choose      Esc  carry on", 15))

	# Your job: one card per person playing
	_job = UI.panel(UI.GLASS_SOLID, 18, UI.EDGE, 2, Vector4(22, 18, 22, 18))
	_job.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_job)
	_job_box = VBoxContainer.new()
	_job_box.add_theme_constant_override("separation", 12)
	_job.add_child(_job_box)

	# Controls & joining
	_controls = UI.panel(UI.GLASS_SOLID, 18, UI.EDGE, 2, Vector4(22, 18, 22, 18))
	_controls.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_controls)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	_controls.add_child(cv)
	cv.add_child(UI.label("CONTROLS", 16, UI.MUTED, 0))
	for b2 in [["A", "do the job · hold to work"], ["B", "put down · step off"], ["X", "the job's second action"], ["Y", "hand signal"]]:
		cv.add_child(UI.hint(b2[0], b2[1], 17))
	var keys := UI.label("Keyboard P1  WASD move · Space A · Q B · E X · F Y · 1–6 swap job\nKeyboard P2  arrows · Enter A · Shift B · Ctrl X · Alt Y\nF11 full screen · Tab skyline view · right-drag to turn the camera · wheel to zoom", 14, UI.MUTED, 0)
	cv.add_child(keys)
	cv.add_child(UI.label("JOIN ON A PHONE", 16, UI.MUTED, 0))
	var jr := HBoxContainer.new()
	jr.add_theme_constant_override("separation", 12)
	cv.add_child(jr)
	_qr = TextureRect.new()
	_qr.custom_minimum_size = Vector2(200, 200)
	_qr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_qr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	jr.add_child(_qr)
	_join = UI.label("", 18, UI.WHITE, 0)
	_join.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_join.custom_minimum_size = Vector2(220, 0)
	_join.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	jr.add_child(_join)
	_select(0)
	_show_side()

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
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	visible = true
	get_tree().paused = true
	_cool = 0.2
	_select(0)
	_refresh()

func close() -> void:
	visible = false
	get_tree().paused = false

func _show_side() -> void:
	_job.visible = _side == "job"
	_controls.visible = _side == "controls"

func _build_jobs() -> void:
	for c in _job_box.get_children():
		c.queue_free()
	_job_box.add_child(UI.label("YOUR JOB", 16, UI.MUTED, 0))
	var people: Array = game.humans() if game.has_method("humans") else game.crew.humans()
	if people.is_empty() and game.crew:
		people = [game.crew.crew["boom"]]
	var grid := GridContainer.new()
	grid.columns = 2 if people.size() > 2 else 1
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	_job_box.add_child(grid)
	for p in people:
		grid.add_child(_job_card(p, people.size() > 1))

func _job_card(p, compact: bool) -> PanelContainer:
	var col: Color = UI.ROLE.get(p.role, UI.WHITE)
	var card := UI.panel(Color(1, 1, 1, 0.04), 12, col, 2, Vector4(14, 10, 14, 12))
	card.custom_minimum_size = Vector2(330 if compact else 400, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var ic := TextureRect.new()
	ic.texture = Icons.texture(p.role, 96)
	ic.modulate = col
	ic.custom_minimum_size = Vector2(44, 44)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(ic)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	top.add_child(tv)
	var who: String = p.char_name if p.char_name != "" else "You"
	tv.add_child(UI.label("%s · %s" % [who, UI.ROLE_NAME.get(p.role, p.role)], 19, col, 0))
	var short := UI.label(UI.ROLE_SHORT.get(p.role, ""), 13, UI.MUTED, 0)
	tv.add_child(short)
	var how: Dictionary = UI.ROLE_HOW.get(p.role, {})
	for part in [["ON A POUR", "pour"], [UI.ROLE_CLIMB.get(p.role, "").replace("Climb days: ", "CLIMB DAYS: ").to_upper(), "climb"]]:
		if part[0] == "" or not how.has(part[1]):
			continue
		v.add_child(UI.label(part[0], 12, UI.MUTED, 0))
		for h in how[part[1]]:
			if h[0] == "stick":
				var r := HBoxContainer.new()
				r.add_theme_constant_override("separation", 8)
				var st := UI.label("◎", 16, UI.WHITE, 0)
				st.custom_minimum_size = Vector2(24, 0)
				st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				r.add_child(st)
				r.add_child(UI.label(h[1], 14, UI.WHITE, 0))
				v.add_child(r)
			else:
				v.add_child(UI.hint(h[0], h[1], 14))
	return card

func _refresh() -> void:
	for e in _items:
		var b: Button = e["button"]
		match e["action"]:
			"gold_assist":
				b.text = "Gold assist: %s" % ("on" if Settings.value("gold_assist") else "off")
			"split":
				b.text = "Split screen: %s" % ("auto" if Settings.value("split") else "off")
			"cam_test":
				b.text = "Camera test: %s" % Settings.CAM_TESTS[Settings.cam_test][0]
			"real_names":
				b.text = "Brand names: %s" % ("real" if Settings.value("real_names") else "lookalike")
			"fullscreen":
				b.text = "Full screen: %s" % ("on" if Settings.value("fullscreen") else "off")
			"sound":
				b.text = "Sound: %s" % ("off" if game.sfx.muted else "on")
			"shake":
				b.text = "Screen shake: %s" % ("on" if game.shake_on else "off")
			"incidents":
				b.text = "Incidents: %s" % Settings.INCIDENT_NAMES[int(Settings.value("incidents"))]
			"docket_help":
				b.text = "Load call help: %s" % ("on" if Settings.value("docket_help") else "off")
			"ui_scale":
				b.text = "Screen text: %d%%" % int(round(float(Settings.value("ui_scale")) * 100.0))
			"world_text":
				b.text = "Names & labels: %d%%" % int(round(float(Settings.value("world_text")) * 100.0))
			"job":
				b.text = "Your job  %s" % ("▸" if _side == "job" else "")
			"controls":
				b.text = "Controls & joining  %s" % ("▸" if _side == "controls" else "")
	_note.text = _note_for(_items[_index]["action"])
	if _side == "job":
		_build_jobs()
	var url: String = game.hud.join_url
	var text: String = game.hud.join_text
	_join.text = text if text != "" else "Everyone's in (4 players)." if game.crew.humans().size() >= 4 else "Keyboard P2: press Enter.\nPads: press A."
	if url != _qr_url:
		_qr_url = url
		_qr.texture = QR.texture(url, 4) if url != "" else null
	_qr.visible = _qr.texture != null

func _note_for(action: String) -> String:
	match action:
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
	return ""

func _select(i: int) -> void:
	if i < 0:
		return
	_index = i
	for k in _items.size():
		var b: Button = _items[k]["button"]
		var on := k == _index
		for st in ["normal", "hover", "pressed", "focus"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(st)
			sb.bg_color = Color(1, 0.78, 0.17, 0.95) if on else Color(1, 1, 1, 0.05)
		b.add_theme_color_override("font_color", UI.INK if on else UI.WHITE)
		b.add_theme_color_override("font_hover_color", UI.INK if on else UI.WHITE)
	if _note:
		_note.text = _note_for(_items[_index]["action"])

func _do(action: String) -> void:
	match action:
		"resume":
			close()
			return
		"job", "controls":
			_side = action
			_show_side()
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

var phone_y := 0.0
var _phone_a := false
var _phone_b := false

## A phone's buttons while the menu's up: A chooses, B carries on.
func phone_button(b: String) -> void:
	if b == "A":
		_phone_a = true
	elif b == "B":
		_phone_b = true

func _process(delta: float) -> void:
	if not visible:
		phone_y = 0.0
		return
	_cool = maxf(0.0, _cool - delta)
	var y := 0.0
	var pressed := false
	var back := false
	for p in ["p1_", "p2_", "p3_", "p4_"]:
		if InputMap.has_action(p + "up"):
			y += Input.get_axis(p + "up", p + "down")
			pressed = pressed or Input.is_action_just_pressed(p + "action")
			back = back or Input.is_action_just_pressed(p + "leave")
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
	elif back:
		close()

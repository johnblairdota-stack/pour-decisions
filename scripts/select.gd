## The front end, two pages:
##   1. CREW: each person picks who they are (one of the named crew) and which
##      job they do. Bots, as the rest of the crew, work every job nobody takes.
##   2. SITE: the building and the equipment to build it with. The tower boom
##      is what SCP ran on Riverlight; the truck boom works but runs out of
##      reach on the top floors. The other two are for later chapters.
extends CanvasLayer

signal chosen(kit: String)
signal roles_done
signal back_to_crew

const UI := preload("res://scripts/ui.gd")
const F := preload("res://scripts/factory.gd")
const Roster := preload("res://scripts/roster.gd")
const Settings := preload("res://scripts/settings.gd")
const QR := preload("res://scripts/qr.gd")

const KITS := [
	{"id": "tower", "name": "Tower boom", "sub": "Stationary pump + placing boom on a lattice tower", "ok": true, "tag": "WHAT SCP RAN HERE",
		"jobs": ["Trucks, hopper and the street pump", "A clamped riser up the tower", "Climb the tower every 3 levels"]},
	{"id": "truck", "name": "Truck boom", "sub": "Truck-mounted boom pump", "ok": true, "tag": "REACH RUNS OUT UP TOP",
		"jobs": ["Outriggers and pads", "Trucks, hopper and the pump", "Far corners by hand on the top floors"]},
	{"id": "tutorial", "name": "Water tower", "sub": "Tutorial: a short guided job on a round concrete water tower", "ok": true, "tag": "NEW? START HERE",
		"jobs": ["Pump the tank floor", "Climb the boom one section", "Pump the roof, with one weeping clamp"]},
	{"id": "line", "name": "Line pump", "sub": "Trailer pump, pipe run across the deck", "ok": false, "tag": "LATER CHAPTER",
		"jobs": ["Lay and clamp the pipe run", "Move the hose end by hand"]},
	{"id": "mast", "name": "Mast boom", "sub": "Placing boom on a floor-climbing mast", "ok": false, "tag": "LATER CHAPTER",
		"jobs": ["Wedge and pack the mast", "Jack it up through the slabs"]},
]

var game = null
var page := "crew"
var index := 0
var _roles := true            # (kept for the dev autotest hooks)
var _done := false
var _cool := 0.0
var _pcool := {}
var _ready_p := {}            # person index -> ready on the crew page
const COUNT_T := 3.0
var _count_t := -1.0          # counting down to the site page once everyone's ready
var _count_label: Label
const Icons := preload("res://scripts/icons.gd")

var _crew_page: Control
var _site_page: Control
var _steps: Array[Label] = []
var _slots_row: HBoxContainer
var _slots: Dictionary = {}   # person index -> {card, portrait, name, line, role, role_bar, climb, foot}
var _strip: HBoxContainer
var _strip_chips: Dictionary = {}
var _kit_cards: Array = []
var _site_note: Label
var _lead_hint: Label
var _bld_name: Label
var _bld_sub: Label
var _bld_pic: Control
var _bld_facts: GridContainer
var _qr_rect: TextureRect
var _qr_url := ""
var join: Label

func _ready() -> void:
	layer = 5
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.08, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Header: the game's name, and where you are in the two steps
	var logo := UI.label("POUR DECISIONS", 26, UI.YELLOW)
	root.add_child(logo)
	UI.place(logo, Vector2(0, 0), Vector2(40, 28))
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 22)
	root.add_child(steps)
	UI.place(steps, Vector2(1, 0), Vector2(-40, 30))
	for s in ["1  CREW & JOBS", "2  SITE & KIT"]:
		var l := UI.label(s, 20, UI.MUTED)
		steps.add_child(l)
		_steps.append(l)
	_build_crew_page(root)
	_build_site_page(root)
	# Join on a phone: small, bottom right
	var jrow := HBoxContainer.new()
	jrow.add_theme_constant_override("separation", 12)
	root.add_child(jrow)
	UI.place(jrow, Vector2(1, 1), Vector2(-40, -26))
	join = UI.label("", 16, UI.MUTED)
	join.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	join.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	jrow.add_child(join)
	_qr_rect = TextureRect.new()
	_qr_rect.custom_minimum_size = Vector2(84, 84)
	_qr_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_qr_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	jrow.add_child(_qr_rect)
	_show_page("crew")

# ------------------------------------------------------------------ crew page

func _build_crew_page(root: Control) -> void:
	_crew_page = Control.new()
	_crew_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crew_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_crew_page)
	var title := UI.label("WHO YOU ARE, AND YOUR JOB", 46, UI.WHITE)
	_crew_page.add_child(title)
	UI.place(title, Vector2(0.5, 0), Vector2(0, 84))
	_count_label = UI.label("", 26, UI.MUTED)
	_crew_page.add_child(_count_label)
	UI.place(_count_label, Vector2(0.5, 1), Vector2(0, -190))
	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 22)
	_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_crew_page.add_child(_slots_row)
	UI.place(_slots_row, Vector2(0.5, 0.5), Vector2(0, -10))
	# Who's on every job, people and bots
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 10)
	_crew_page.add_child(_strip)
	UI.place(_strip, Vector2(0.5, 1), Vector2(0, -130))

func _slot_card(i: int) -> Dictionary:
	var card := UI.panel(UI.GLASS_SOLID, 16, UI.EDGE, 2, Vector4(16, 14, 16, 14))
	card.custom_minimum_size = Vector2(290, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var who := UI.label("P%d" % i, 18, UI.MUTED)
	v.add_child(who)
	var portrait := Portrait.new()
	portrait.custom_minimum_size = Vector2(258, 210)
	v.add_child(portrait)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var la := UI.label("◀", 22, UI.MUTED)
	row.add_child(la)
	var name := UI.label("", 34, UI.WHITE)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(name)
	row.add_child(UI.label("▶", 22, UI.MUTED))
	var line := UI.label("", 15, UI.MUTED, 0)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.custom_minimum_size = Vector2(258, 40)
	v.add_child(line)
	var role_box := UI.panel(Color(1, 1, 1, 0.06), 10, Color(1, 1, 1, 0.0), 0, Vector4(10, 8, 10, 8))
	v.add_child(role_box)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 2)
	role_box.add_child(rv)
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 6)
	rv.add_child(rrow)
	rrow.add_child(UI.label("▲", 16, UI.MUTED))
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(30, 30)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rrow.add_child(ic)
	var role := UI.label("", 22, UI.WHITE)
	role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rrow.add_child(role)
	rrow.add_child(UI.label("▼", 16, UI.MUTED))
	var desc := UI.label("", 14, UI.WHITE, 0)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size = Vector2(238, 38)
	rv.add_child(desc)
	var climb := UI.label("", 13, UI.MUTED, 0)
	climb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(climb)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(foot)
	_slots_row.add_child(card)
	return {"card": card, "who": who, "portrait": portrait, "name": name, "line": line, "role": role, "icon": ic, "desc": desc, "climb": climb, "foot": foot, "ready": null}

func _empty_card() -> PanelContainer:
	var card := UI.panel(Color(0.04, 0.07, 0.12, 0.45), 16, Color(1, 1, 1, 0.18), 2, Vector4(16, 14, 16, 14))
	card.custom_minimum_size = Vector2(300 if _qr_url != "" else 220, 420)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var t := UI.label("Join in", 24, UI.WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if _qr_url != "":
		# Big enough to scan from the couch: point a phone camera at it
		var q := TextureRect.new()
		q.texture = QR.texture(_qr_url, 4)
		q.custom_minimum_size = Vector2(260, 260)
		q.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		q.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		q.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		v.add_child(q)
		var u := UI.label(_qr_url.replace("http://", ""), 24, UI.YELLOW, 0)
		u.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(u)
		var how := UI.label("Scan with your phone (same Wi-Fi)\nor press Enter / a pad's A", 15, UI.MUTED, 0)
		how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(how)
		# A page that won't load: the other addresses, and the usual culprit
		var others: Array = game.phones.other_urls() if game != null and game.phones != null else []
		var help := "Not loading? Allow Godot through\nthe Windows firewall (private networks)"
		if not others.is_empty():
			help = "Not loading? Try " + " or ".join(others.map(func(o): return String(o).replace("http://", ""))) + "\nor allow Godot through the firewall"
		var tip := UI.label(help, 13, UI.MUTED, 0)
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.custom_minimum_size.x = 268
		v.add_child(tip)
	else:
		var plus := UI.label("+", 64, UI.MUTED)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(plus)
		var how2 := UI.label("Enter or a pad's A", 15, UI.MUTED, 0)
		how2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(how2)
	return card

func _rebuild_slots() -> void:
	for c in _slots_row.get_children():
		_slots_row.remove_child(c)
		c.queue_free()
	_slots.clear()
	var people: Array = game.crew.humans()
	for p in people:
		_slots[p.index] = _slot_card(p.index)
	if people.size() < 4:
		_slots_row.add_child(_empty_card())
	for c in _strip.get_children():
		_strip.remove_child(c)
		c.queue_free()
	_strip_chips.clear()
	for role in game.crew.ROLES:
		var chip := UI.panel(UI.GLASS, 10, UI.ROLE[role], 0, Vector4(12, 6, 12, 6))
		chip.custom_minimum_size = Vector2(200, 0)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		chip.add_child(h)
		var sw := TextureRect.new()
		sw.texture = Icons.texture(role, 64)
		sw.modulate = UI.ROLE[role]
		sw.custom_minimum_size = Vector2(34, 34)
		sw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sw.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(sw)
		var vv := VBoxContainer.new()
		vv.add_theme_constant_override("separation", 0)
		h.add_child(vv)
		vv.add_child(UI.label(UI.ROLE_NAME[role].to_upper(), 13, UI.MUTED, 0))
		var who := UI.label("", 18, UI.WHITE, 0)
		vv.add_child(who)
		_strip.add_child(chip)
		_strip_chips[role] = {"chip": chip, "who": who}

func _refresh_crew() -> void:
	var crew = game.crew
	var people: Array = crew.humans()
	if people.size() != _slots.size():
		_rebuild_slots()
	for p in people:
		var e: Dictionary = _slots[p.index]
		var info: Dictionary = Roster.char_info(p.char_id)
		var col: Color = UI.ROLE[p.role]
		(e["who"] as Label).text = "P%d" % p.index
		(e["who"] as Label).add_theme_color_override("font_color", p.tag_color)
		(e["name"] as Label).text = info["name"]
		(e["line"] as Label).text = info["line"]
		(e["role"] as Label).text = UI.ROLE_NAME[p.role]
		(e["role"] as Label).add_theme_color_override("font_color", col)
		(e["icon"] as TextureRect).texture = Icons.texture(p.role, 64)
		(e["icon"] as TextureRect).modulate = col
		(e["desc"] as Label).text = UI.ROLE_SHORT[p.role]
		(e["climb"] as Label).text = UI.ROLE_CLIMB[p.role]
		(e["portrait"] as Portrait).show_crew(info, col)
		var ready: bool = _ready_p.get(p.index, false)
		var sb := UI.style(e["card"])
		sb.border_color = col if ready else p.tag_color
		sb.set_border_width_all(5 if ready else 2)
		var foot: HBoxContainer = e["foot"]
		var want := "ready" if ready else "pick"
		if foot.get_meta("state", "") != want:
			foot.set_meta("state", want)
			for c in foot.get_children():
				foot.remove_child(c)
				c.queue_free()
			if ready:
				foot.add_child(UI.label("✓ READY", 22, UI.GREEN))
				foot.add_child(UI.hint("B", "change", 15))
			else:
				foot.add_child(UI.hint("A", "ready", 18))
	for role in _strip_chips:
		var p = crew.crew[role]
		var who: Label = _strip_chips[role]["who"]
		if p.bot:
			who.text = p.char_name + "  ·  bot"
			who.add_theme_color_override("font_color", UI.MUTED)
		else:
			who.text = "P%d  %s" % [p.index, p.char_name]
			who.add_theme_color_override("font_color", p.tag_color)

func _process_crew(delta: float) -> void:
	var crew = game.crew
	var people: Array = crew.humans()
	for p in people:
		var i: int = p.index
		_pcool[i] = maxf(0.0, float(_pcool.get(i, 0.0)) - delta)
		var v: Vector2 = p.move_input()
		var me = crew.human(i)
		if me == null:
			continue
		if not _ready_p.get(i, false) and _pcool[i] <= 0.0:
			if absf(v.x) > 0.5:
				crew.cycle_char(i, int(signf(v.x)))
				_pcool[i] = 0.22
				game.sfx.hit("tink")
			elif absf(v.y) > 0.5:
				crew.cycle(i, int(signf(v.y)))
				_pcool[i] = 0.22
				game.sfx.hit("tink")
		me = crew.human(i)
		if me.action_pressed() and not _ready_p.get(i, false):
			_ready_p[i] = true
			game.sfx.hit("ding")
			if game._dbg:
				print("[select] P%d ready" % i)
		elif me.leave_pressed() and _ready_p.get(i, false):
			_ready_p[i] = false
	_refresh_crew()
	var all := not people.is_empty()
	var waiting := []
	for p in people:
		if not _ready_p.get(p.index, false):
			all = false
			waiting.append("P%d" % p.index)
	# Everyone's ready: a short count, so a late joiner (or a change of mind,
	# B) can still stop it
	if all:
		if _count_t < 0.0:
			_count_t = COUNT_T
			game.sfx.hit("ding")
		var was := int(ceil(_count_t))
		_count_t -= delta
		if int(ceil(_count_t)) != was and _count_t > 0.0:
			game.sfx.hit("tink")
		_count_label.text = "Starting in %d…" % int(ceil(maxf(_count_t, 0.0)))
		_count_label.add_theme_color_override("font_color", UI.GREEN)
		if _count_t <= 0.0:
			_count_t = -1.0
			go_site()
	else:
		_count_t = -1.0
		var any_ready := false
		for k in _ready_p:
			any_ready = any_ready or _ready_p[k]
		_count_label.text = ("Waiting for %s to press A" % " and ".join(waiting)) if any_ready else ""
		_count_label.add_theme_color_override("font_color", UI.MUTED)

## On to the second page.
func go_site() -> void:
	_show_page("site")
	_cool = 0.3
	roles_done.emit()

# ------------------------------------------------------------------ site page

func _build_site_page(root: Control) -> void:
	_site_page = Control.new()
	_site_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_site_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_site_page)
	var title := UI.label("THE SITE & THE KIT", 46, UI.WHITE)
	_site_page.add_child(title)
	UI.place(title, Vector2(0.5, 0), Vector2(0, 84))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	_site_page.add_child(row)
	UI.place(row, Vector2(0.5, 0.5), Vector2(0, 10))
	# The building
	var job := UI.panel(UI.GLASS_SOLID, 16, UI.EDGE, 2, Vector4(20, 18, 20, 18))
	job.custom_minimum_size = Vector2(430, 0)
	row.add_child(job)
	var jv := VBoxContainer.new()
	jv.add_theme_constant_override("separation", 8)
	job.add_child(jv)
	jv.add_child(UI.label("THE BUILDING", 14, UI.MUTED, 0))
	_bld_name = UI.label(Settings.brand("site"), 38, UI.YELLOW)
	jv.add_child(_bld_name)
	_bld_sub = UI.label(Settings.brand("area") + " · Stage 7", 18, UI.WHITE, 0)
	jv.add_child(_bld_sub)
	var pic := Elevation.new()
	_bld_pic = pic
	pic.custom_minimum_size = Vector2(390, 250)
	jv.add_child(pic)
	var facts := GridContainer.new()
	facts.columns = 2
	facts.add_theme_constant_override("h_separation", 22)
	facts.add_theme_constant_override("v_separation", 4)
	jv.add_child(facts)
	_bld_facts = facts
	for f in [["11", "levels"], ["33 m", "top slab"], ["1", "slab a level"], ["shared", "tower crane"]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.add_child(UI.label(f[0], 22, UI.WHITE))
		var l := UI.label(f[1], 15, UI.MUTED, 0)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
		facts.add_child(h)
	# The kit: the two you can play now, big; the later chapters' two, small
	var kv := VBoxContainer.new()
	kv.add_theme_constant_override("separation", 10)
	row.add_child(kv)
	kv.add_child(UI.label("THE KIT", 14, UI.MUTED, 0))
	var big := HBoxContainer.new()
	big.add_theme_constant_override("separation", 16)
	kv.add_child(big)
	var small := HBoxContainer.new()
	small.add_theme_constant_override("separation", 16)
	for k in KITS:
		if k["ok"]:
			var c := UI.panel(UI.GLASS_SOLID, 14, UI.EDGE, 2, Vector4(18, 16, 18, 16))
			c.custom_minimum_size = Vector2(300, 300)
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 8)
			c.add_child(v)
			v.add_child(UI.label(Settings.branded(k["tag"]), 13, UI.YELLOW, 0))
			v.add_child(UI.label(k["name"], 32, UI.WHITE))
			var sub := UI.label(k["sub"], 15, UI.MUTED, 0)
			sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sub.custom_minimum_size = Vector2(264, 0)
			v.add_child(sub)
			for j in k["jobs"]:
				var jl := UI.label("•  " + j, 17, UI.WHITE, 0)
				jl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				jl.custom_minimum_size = Vector2(264, 0)
				v.add_child(jl)
			big.add_child(c)
			_kit_cards.append(c)
		else:
			var c2 := UI.panel(Color(0.05, 0.08, 0.14, 0.55), 12, Color(1, 1, 1, 0.08), 1, Vector4(14, 8, 14, 10))
			c2.custom_minimum_size = Vector2(300, 0)
			var v2 := VBoxContainer.new()
			v2.add_theme_constant_override("separation", 0)
			c2.add_child(v2)
			v2.add_child(UI.label(k["name"] + "  ·  later chapter", 17, UI.MUTED, 0))
			var s2 := UI.label(k["sub"], 13, Color(UI.MUTED, 0.7), 0)
			v2.add_child(s2)
			small.add_child(c2)
	kv.add_child(small)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 22)
	_site_page.add_child(foot)
	UI.place(foot, Vector2(0.5, 1), Vector2(0, -60))
	_lead_hint = UI.label("", 18, UI.MUTED)
	foot.add_child(_lead_hint)
	foot.add_child(UI.hint("A", "start", 18))
	foot.add_child(UI.hint("B", "back to the crew", 18))
	_site_note = UI.label("", 18, UI.YELLOW)
	_site_page.add_child(_site_note)
	UI.place(_site_note, Vector2(0.5, 1), Vector2(0, -110))
	_highlight()

func _process_site(delta: float) -> void:
	if _done:
		return
	_cool = maxf(0.0, _cool - delta)
	var v := Vector2.ZERO
	var pressed := false
	var back := false
	# One person drives this page (the first player), so nobody fights over it;
	# anyone can still go back to the crew page
	var lead = null
	if game != null:
		var people: Array = game.crew.humans()
		if not people.is_empty():
			lead = people[0]
			v = lead.move_input()
			pressed = lead.action_pressed()
			_lead_hint.text = "P%d picks  ·" % lead.index if people.size() > 1 else ""
			_lead_hint.add_theme_color_override("font_color", lead.tag_color)
		for p in people:
			back = back or p.leave_pressed()
	if _cool <= 0.0 and absf(v.x) > 0.5:
		var ni := clampi(index + int(signf(v.x)), 0, _kit_cards.size() - 1)
		if ni != index:
			index = ni
			_site_note.text = ""
			_highlight()
			if game:
				game.sfx.hit("tink")
		_cool = 0.22
	if _cool <= 0.0 and pressed:
		pick(index)
	elif back:
		for k in _ready_p.keys():
			_ready_p[k] = false
		_show_page("crew")
		back_to_crew.emit()

func pick(i: int) -> void:
	index = i
	_highlight()
	var k: Dictionary = KITS[i]
	if not k["ok"]:
		_site_note.text = "The %s comes in a later chapter. Pick the tower or the truck." % k["name"].to_lower()
		return
	_done = true
	chosen.emit(k["id"])

func _highlight() -> void:
	# The building panel shows the site the card's for
	if _bld_name:
		var tut: bool = index < KITS.size() and KITS[index]["id"] == "tutorial"
		_bld_name.text = "Water tower" if tut else Settings.brand("site")
		_bld_sub.text = "Tutorial site · a concrete pedestal tower" if tut else Settings.brand("area") + " · Stage 7"
		_bld_pic.set("water", tut)
		_bld_pic.queue_redraw()
		_bld_facts.visible = not tut
	for i in _kit_cards.size():
		var sb := UI.style(_kit_cards[i])
		sb.border_color = UI.YELLOW if i == index else UI.EDGE
		sb.set_border_width_all(4 if i == index else 2)

# ------------------------------------------------------------------ shared

var _uitest := OS.get_cmdline_user_args().has("--uitest")
var _ut := 0.0

func _process(delta: float) -> void:
	if game == null:
		return
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
				_ready_p[1] = true
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
	for i in _steps.size():
		var on := (i == 0 and which == "crew") or (i == 1 and which == "site")
		_steps[i].add_theme_color_override("font_color", UI.YELLOW if on else UI.MUTED)

func set_join(text: String, url := "") -> void:
	if join:
		# (with phones on, the Join in card shows the code and the address)
		join.text = "" if url != "" else text
	if url != _qr_url and _qr_rect != null:
		_qr_url = url
		# (the big code lives in the Join in card now)
		_qr_rect.texture = null
		_qr_rect.visible = false
		if _slots_row != null:
			_rebuild_slots()

## (Older entry point, kept for the main script.)
func show_roles() -> void:
	_show_page("crew")

# ------------------------------------------------------------------ pictures

## A turning 3D portrait of a crew member in their job's hard hat.
class Portrait extends SubViewportContainer:
	var _view: SubViewport
	var _pivot: Node3D
	var _model: Node3D
	var _key := ""
	var _t := 0.0

	func _init() -> void:
		stretch = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_view = SubViewport.new()
		_view.own_world_3d = true
		_view.transparent_bg = true
		_view.size = Vector2i(258, 210)
		_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_view)
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0, 0, 0, 0)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.75, 0.8, 0.9)
		e.ambient_light_energy = 0.6
		env.environment = e
		_view.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.7, 0.6, 0)
		sun.light_energy = 1.2
		_view.add_child(sun)
		var cam := Camera3D.new()
		cam.fov = 30.0
		var eye := Vector3(0, 1.15, 3.4)
		cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.95, 0) - eye, Vector3.UP), eye)
		_view.add_child(cam)
		_pivot = Node3D.new()
		_view.add_child(_pivot)

	func show_crew(info: Dictionary, hat: Color) -> void:
		var key: String = String(info["id"]) + hat.to_html()
		if key == _key:
			return
		_key = key
		if _model:
			_model.queue_free()
		_model = F.chibi(Color("ff7a1a"), hat)
		F.dress(_model, info)
		_pivot.add_child(_model)

	func _process(delta: float) -> void:
		_t += delta
		_pivot.rotation.y = 0.5 * sin(_t * 0.8)
		if _model:
			var head: Node3D = _model.get_node("Head")
			head.position.y = 1.32 + 0.02 * sin(_t * 3.0)

## The building's elevation: 11 slabs on columns beside the river, with the
## top slab highlighted and the placing boom's tower alongside.
class Elevation extends Control:
	var water := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if water:
			# The water tower: the shaft, the cone, the tank, its roof
			draw_rect(Rect2(0, h - 34, w, 34), Color("4f6b4a"))
			var cx := w * 0.42
			var base := h - 34
			draw_rect(Rect2(cx - 22, base - 120, 44, 120), Color("b7bcc3"))
			for i in 4:
				draw_line(Vector2(cx - 22, base - 30 * (i + 1)), Vector2(cx + 22, base - 30 * (i + 1)), Color("8a929c"), 1.0)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 22, base - 120), Vector2(cx + 22, base - 120), Vector2(cx + 70, base - 160), Vector2(cx - 70, base - 160)]), Color("b7bcc3"))
			draw_rect(Rect2(cx - 70, base - 200, 140, 40), Color("b7bcc3"))
			draw_rect(Rect2(cx - 70, base - 186, 140, 8), Color("4fa3ff"))
			draw_rect(Rect2(cx - 74, base - 204, 148, 6), Color("ffc72c"))
			var tx := cx + 110
			draw_rect(Rect2(tx, base - 214, 14, 214), Color("dce1e6"), false, 2.0)
			draw_line(Vector2(tx + 7, base - 214), Vector2(tx - 50, base - 232), Color("ffc72c"), 5.0)
			draw_line(Vector2(tx - 50, base - 232), Vector2(cx, base - 206), Color("ffc72c"), 4.0)
			return
		draw_rect(Rect2(0, h - 26, w, 26), Color("2f5f8f"))         # the river
		draw_rect(Rect2(0, h - 34, w, 8), Color("4f6b4a"))
		var bx := w * 0.18
		var bw := w * 0.5
		var fh := (h - 60) / 11.0
		for i in 11:
			var y := h - 34 - (i + 1) * fh
			var col := Color("ffc72c") if i == 10 else Color("b7bcc3")
			draw_rect(Rect2(bx, y, bw, fh * 0.22), col)
			if i < 10:
				for c in 5:
					draw_rect(Rect2(bx + 6 + c * (bw - 16) / 4.0, y + fh * 0.22, 4, fh * 0.78), Color("8a929c"))
				draw_rect(Rect2(bx + 4, y + fh * 0.3, bw - 8, fh * 0.6), Color(1, 0.95, 0.75, 0.18))
		# The tower and its boom
		var tx := bx + bw + 30
		draw_rect(Rect2(tx, h - 34 - fh * 11.6, 16, fh * 11.6), Color("dce1e6"), false, 2.0)
		for i in 23:
			var y2 := h - 34 - i * fh * 0.5
			draw_line(Vector2(tx, y2), Vector2(tx + 16, y2 - fh * 0.5), Color("dce1e6"), 1.0)
		var top := Vector2(tx + 8, h - 34 - fh * 11.6)
		draw_line(top, top + Vector2(-70, -18), Color("ffc72c"), 5.0)
		draw_line(top + Vector2(-70, -18), top + Vector2(-150, 16), Color("ffc72c"), 4.0)

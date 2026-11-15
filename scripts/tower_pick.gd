## The tower pick: the first page (select.gd), one tower at a time, live behind it (main.gd orbits the
## camera round the site). Left / right moves between towers; a tower on the other site flies there
## over the river map (site_transition.gd) and the game comes back up on this page with it. A picks.
extends Control

const UI := preload("res://scripts/ui.gd")
const Settings := preload("res://scripts/settings.gd")
const Transition := preload("res://scripts/site_transition.gd")

## The towers, left to right. "site" is the run it lives in (main.gd builds one site per run).
const TOWERS := [
	{"id": "water", "site": "riverlight", "kit": "tutorial", "name": "WATER TOWER", "where": "Induction · Hamilton",
		"facts": ["2 POURS", "ROUND SLABS", "GUIDED"],
		"special": "A short guided job before the real thing: the tank floor, one climb, the roof slab."},
	{"id": "riverlight", "site": "riverlight", "kit": "tower", "name": "RIVERLIGHT", "where": "Hamilton Reach · 2017",
		"facts": ["11 LEVELS", "1 POUR A LEVEL", "BOOM TOWER"],
		"special": "The boom's on a lattice tower in the notch between two wings. Every third level the crew climbs it with the crane."},
	{"id": "spire", "site": "spire", "kit": "tower", "name": "SPIRE RESIDENCES", "where": "550 Queen St, Brisbane · 2015-2018",
		"facts": ["34 POURS", "L6 TO THE ROOF", "2 BOOMS"],
		"special": "L6 is a 1250 mm transfer slab. Your crew pours the Ann St side; a bot crew pours the other side with the second boom. The core's jump form stays three levels ahead."},
]
const MEDAL_COL := [Color("d0884a"), Color("d6dde6"), Color("ffd23f")]

## The card to come back to after a fly to the other site (the game restarts, this doesn't)
static var landed := -1

var game = null
var index := 1
var _cool := 0.0
var _busy := false
var _card: PanelContainer
var _name: Label
var _where: Label
var _facts: HBoxContainer
var _special: Label
var _medals: Label
var _go: Label
var _left: Label
var _right: Label
var _dots: HBoxContainer
var _t := 0.0

signal picked(card: Dictionary)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# where to start: back where the fly landed, else this run's site (the water tower first for a
	# brand new crew)
	var site: String = game.site if game != null else "riverlight"
	if landed >= 0 and String(TOWERS[landed]["site"]) == site:
		index = landed
	else:
		index = 2 if site == "spire" else (1 if Settings.value("tut_done") else 0)
	landed = -1
	var title := UI.head("PICK A TOWER", 34, UI.GOLD, 6)
	add_child(title)
	UI.place(title, Vector2(0, 0), Vector2(44, 30))
	_card = UI.panel(Color(UI.CARD, 0.9), 22, Color(1, 1, 1, 0.08), 1, Vector4(30, 22, 34, 24))
	add_child(_card)
	UI.place(_card, Vector2(0, 1), Vector2(44, -40))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_card.add_child(v)
	_where = UI.head("", 24, UI.DIM)
	v.add_child(_where)
	_name = UI.head("", 84, UI.BONE)
	v.add_child(_name)
	_facts = HBoxContainer.new()
	_facts.add_theme_constant_override("separation", 10)
	v.add_child(_facts)
	_special = UI.label("", 24, Color("d5d2c8"), 0)
	_special.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_special.custom_minimum_size = Vector2(620, 0)
	v.add_child(_special)
	_medals = UI.head("", 26, UI.BONE)
	v.add_child(_medals)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	v.add_child(row)
	var go := UI.pill(UI.TRACK, Vector4(10, 6, 24, 6), UI.GOLD, 2)
	_go = UI.head("", 30, UI.BONE)
	go.add_child(_go)
	row.add_child(go)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 10)
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_dots)
	for i in TOWERS.size():
		var d := UI.Hat.new()
		d.dot = true
		d.custom_minimum_size = Vector2(18, 18)
		_dots.add_child(d)
	_left = UI.head("", 26, Color("c9c6bd"), 6)
	add_child(_left)
	UI.place(_left, Vector2(0, 0), Vector2(44, 82))
	_right = UI.head("", 26, Color("c9c6bd"), 6)
	_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_right)
	UI.place(_right, Vector2(1, 0), Vector2(-44, 82))
	_refresh()

func card() -> Dictionary:
	return TOWERS[index]

## Medals on a site so far: "2 gold · 1 silver · 3 bronze · furthest L09".
func _progress(c: Dictionary) -> Array:
	if c["id"] == "water":
		return ["DONE" if Settings.value("tut_done") else "NEW? START HERE", false]
	var key := "medals_spire" if c["site"] == "spire" else "medals"
	var m = Settings.value(key)
	var arr: Array = m if m is Array else []
	var tally := [0, 0, 0]
	var far := -1
	for i in arr.size():
		if int(arr[i]) >= 0:
			tally[clampi(int(arr[i]), 0, 2)] += 1
			far = i
	if far < 0:
		return ["NOT STARTED", false]
	var lv := "L%02d" % (far + 6) if c["site"] == "spire" else "L%d" % (far + 1)
	return ["%d GOLD · %d SILVER · %d BRONZE · FURTHEST %s" % [tally[2], tally[1], tally[0], lv], true]

func _refresh() -> void:
	var c: Dictionary = card()
	_name.text = c["name"]
	_where.text = String(c["where"]).to_upper()
	for ch in _facts.get_children():
		ch.queue_free()
	for f in c["facts"]:
		var chip := UI.pill(Color(1, 1, 1, 0.08), Vector4(10, 2, 12, 2))
		chip.add_child(UI.head(f, 22, UI.GOLD))
		_facts.add_child(chip)
	_special.text = c["special"]
	var pr: Array = _progress(c)
	_medals.text = pr[0]
	_go.text = "A · CONTINUE" if pr[1] else "A · START"
	for i in _dots.get_child_count():
		var d = _dots.get_child(i)
		d.color = UI.GOLD if i == index else Color(1, 1, 1, 0.3)
	_left.text = ("◀  " + TOWERS[index - 1]["name"]) if index > 0 else ""
	_right.text = (TOWERS[index + 1]["name"] + "  ▶") if index < TOWERS.size() - 1 else ""

## Dev: `--pickshots=<dir>` saves each tower's card and a frame of the fly, stepping right on its own
var _demo := ""
var _demo_t := 0.0

static var _demo_began := false

func _demo_step(delta: float) -> void:
	if not _demo_began:
		_demo_began = true
		if game != null and game.site != "riverlight":
			# (the run starts from the water tower, on Riverlight)
			Settings.put("site", "riverlight")
			get_tree().reload_current_scene()
			return
	_demo_t += delta
	if _demo_t < 3.5:
		return
	_demo_t = -99.0
	var img := get_viewport().get_texture().get_image()
	img.save_png(_demo.path_join("pick_%s.png" % card()["id"]))
	print("[pickshots] pick_%s" % card()["id"])
	if index < TOWERS.size() - 1:
		Transition.shot_dir = _demo
		move(1)
		_demo_t = 0.0
	else:
		get_tree().quit()

## One frame of input from the crew (stick, A); select.gd calls it while this page is up.
func step(delta: float, mv: Vector2, pressed: bool) -> void:
	_t += delta
	if _demo == "":
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--pickshots="):
				_demo = a.substr(12)
		if _demo == "":
			_demo = "-"
	if _demo != "-" and not _busy:
		_demo_step(delta)
		return
	_cool = maxf(0.0, _cool - delta)
	if _busy:
		return
	_go.get_parent().scale = Vector2.ONE * (1.0 + 0.04 * (0.5 - 0.5 * cos(_t * TAU / 1.6)))
	_go.get_parent().pivot_offset = _go.get_parent().size * 0.5
	if _cool <= 0.0 and absf(mv.x) > 0.5:
		move(int(signf(mv.x)))
		_cool = 0.3
	elif _cool <= 0.0 and pressed:
		_busy = true
		picked.emit(card())

## To the next tower left (-1) or right (+1). One on the other site flies there.
func move(dir: int) -> void:
	var ni := clampi(index + dir, 0, TOWERS.size() - 1)
	if ni == index:
		return
	if game != null:
		game.sfx.hit("tink")
	var from: String = TOWERS[index]["site"]
	var to: String = TOWERS[ni]["site"]
	index = ni
	if from != to and game != null:
		_busy = true
		landed = ni
		Settings.put("site", to)
		var tw := create_tween()
		tw.tween_property(_card, "modulate:a", 0.0, 0.25)
		Transition.fly(get_tree(), from, to)
		return
	# same site: the card slides over
	_card.modulate.a = 0.0
	var x0 := _card.position.x
	_card.position.x = x0 + 80.0 * dir
	_refresh()
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(_card, "modulate:a", 1.0, 0.25)
	tw2.tween_property(_card, "position:x", x0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## The water tower tutorial's coach: a panel down the left that says what's
## going on and, for each person playing, the next thing their job needs, in
## that job's colour with its icon. It follows the game and never waits for
## anyone: do the thing and it moves on.
extends CanvasLayer

const UI := preload("res://scripts/ui.gd")
const Icons := preload("res://scripts/icons.gd")

var game
var _panel: PanelContainer
var _title: Label
var _story: Label
var _rows: VBoxContainer
var _key := ""
var _intro_t := 0.0

func setup(owner_game) -> void:
	game = owner_game
	layer = 4
	_panel = UI.panel(UI.GLASS, 14, UI.YELLOW, 2, Vector4(16, 12, 16, 14))
	_panel.custom_minimum_size = Vector2(380, 0)
	add_child(_panel)
	UI.place(_panel, Vector2(0, 0), Vector2(16, 200))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)
	_title = UI.label("", 15, UI.YELLOW, 0)
	v.add_child(_title)
	_story = UI.label("", 15, UI.WHITE, 0)
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story.custom_minimum_size = Vector2(348, 0)
	v.add_child(_story)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	v.add_child(_rows)
	_panel.visible = false

func start() -> void:
	_panel.visible = true
	_intro_t = 0.0

func update(delta: float) -> void:
	if not game.tutorial or game.phase in ["roles", "select", "topout"]:
		_panel.visible = false
		return
	_panel.visible = not game.skyline
	_intro_t += delta
	var head := _story_now()
	var tips: Array = []
	var people: Array = game.humans()
	for p in people:
		var t := _tip(p)
		if t != "":
			tips.append([p, t])
	tips = tips.slice(0, 3)
	var key: String = head[0] + head[1]
	for t in tips:
		key += str(t[0].role) + String(t[1])
	if key == _key:
		return
	_key = key
	_title.text = head[0]
	_story.text = head[1]
	_story.visible = head[1] != ""
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	for t in tips:
		var p = t[0]
		var col: Color = UI.ROLE.get(p.role, UI.WHITE)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var ic := TextureRect.new()
		ic.texture = Icons.texture(p.role, 64)
		ic.modulate = col
		ic.custom_minimum_size = Vector2(30, 30)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(ic)
		var l := UI.label(String(t[1]), 16, col, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(308, 0)
		h.add_child(l)
		_rows.add_child(h)

## [title, one short line] for where the job's up to. The coach says one
## thing, in a few words; the facts wait for the slab report.
func _story_now() -> Array:
	var g = game
	var floor_name := "TANK FLOOR" if g.k == g.TUT_FIRST else "ROOF SLAB"
	match g.phase:
		"columns", "deck":
			if g.k == g.TUT_FIRST:
				return ["WATER TOWER · THE TANK FLOOR", "The forms are going up."]
			return ["WATER TOWER · THE TANK WALL", "The boom climbs to reach the roof."]
		"inspect":
			return ["WATER TOWER · " + floor_name, "Pre-pour check, then the trucks."]
		"pour":
			return ["WATER TOWER · POUR THE " + floor_name, "Keep the wet edge alive."]
		"screed", "cure":
			return ["WATER TOWER · " + floor_name, "Poured. Now it cures."]
		"climb":
			return ["WATER TOWER · CLIMB THE BOOM", "One new section, up by crane."]
	return ["WATER TOWER", ""]

## What this person's job needs from them next ("" if nothing): one line,
## one verb, the place in capitals.
func _tip(p) -> String:
	var g = game
	var line = g.line
	var climb = g.climb
	if g.phase == "climb":
		match p.role:
			"line":
				if climb.needs_sling():
					return "Hold A at the LAYDOWN to sling it." if climb.hook_ready() or p.position.distance_to(climb.LAYDOWN) > 3.5 else "Wait for the hook, then hold A."
				if climb.needs_pins():
					if p.held_kind == "pins":
						return "Take the bag to the HAUL ROPE: A."
					return "Grab a PIN BAG at the tower foot: A."
				return "Done. Watch it fly."
			"screed":
				return "Nothing to do. Have a breather."
			"boom":
				if climb.stage in ["jack", "fly"]:
					return "Wait at DOGMAN for the load."
				if climb.stage == "guide":
					return "Push toward the green ghost. Hold A to lower."
			"poker":
				if climb.stage in ["fly", "guide"]:
					if climb.tag_hand == p:
						return "Keep holding A on the tag line."
					return "Wait at TAG LINE, then hold A."
			"pump":
				if p.busy != "rigger":
					return "Go to RIGGER and press A."
				match climb.stage:
					"jack":
						return "Press A to pump the rams."
					"roll":
						return "Hold A to roll the section in."
					"pin":
						match climb.pin_sub:
							"wait":
								return "Wait for the pins."
							"split":
								return "Press A to pull the R-clip."
							"align":
								return "Stick till the holes glow green, then A."
							"drive":
								return "Hold A, let go in the gold."
							"clip":
								return "Hold A to clip the pin."
		return ""
	if g.phase == "inspect":
		if p.role == "line":
			return "Head to the TRUCK BAY."
		return ""
	if g.phase != "pour":
		return ""
	# The start-up and the washout: one person, one place, one button
	var ops = g.ops
	if ops.busy() and ops.role() == p.role:
		match ops.stage:
			"start":
				return "Hold A at the PUMP PANEL to start."
			"air":
				return "Press A to radio the air's out." if ops.step_t >= ops.TRAVEL_T else "Watch the hose: air's coming."
			"slurry_in":
				return "Hold A at the PUMP PANEL: slurry in."
			"slurry_out":
				return "Hose over the BIN, hold A."
			"concrete":
				return "Press A: concrete's on!"
			"water_in":
				return "Hold A at the PUMP PANEL: water in."
			"push":
				return "Hose over the BIN, hold A."
			"valve":
				return "Hold A at the RELEASE VALVE."
	if ops.busy() and p.role in ["boom", "hose"]:
		return "Wait: the line's being primed." if not ops.primed else "Wait: washout under way."
	match p.role:
		"hose":
			if p.busy != "hose":
				return "Walk under the END HOSE, press A."
			return "Walk the hose to the gold. Hold A to pump."
		"boom":
			if p.busy != "boom":
				return "Press A at the BOOM REMOTE."
			if g.pipe_calls():
				return "Steer the hose to the pipe guy."
			if not line.pumping:
				return "Hold A to pump. Steer with the stick."
			return "Keep it on the wet edge."
		"poker":
			if p.tool != "poker":
				return "Pick up the POKER: A."
			return "Hold A in purple till the bubbles stop."
		"screed":
			return "Hold A, walk back over the gold."
		"pump":
			if line.spike_on:
				return "SPIKE! Press A now."
			if line.fix_i >= 0 or (line.blocked and not line.block_found) or (line.fail_i >= 0 and line.burst):
				return "Grab the part, fix it up the LADDER."
			if line.fail_i >= 0:
				return "Grab a CLAMP KIT, swap it up the LADDER."
			if line.tripped:
				return "Hold A at the PUMP PANEL to restart."
			if line.live and line.idle_t > line.SET_TIME * 0.5 and not line.line_down():
				return "Press A at the PUMP PANEL: stroke it."
			var adv: Dictionary = g.speed_advice
			if adv["want"] != "" and adv["level"] >= 1:
				return "Press X: pump to %s." % adv["want"].to_upper()
			if line.chute_signalled() and line._pouring_truck():
				var fill: float = line.hopper / line.HOPPER_CAP
				if fill < line.HOP_BAND.x or fill > line.HOP_BAND.y:
					return "Hold Y at the PANEL: stick up for more chute, down for less."
			return "Watch the gauge. Red needle: press A."
		"line":
			if p.busy == "radio":
				return "Flick the stick: tell the pump what's coming."
			for tr in line.trucks:
				if tr["state"] in ["called", "approach", "back"] and tr.get("spotter") != null:
					return "Hold A to back it. Let go at STOP."
			var chk = line.needs_check()
			if chk != null:
				if chk.get("too_old", false):
					return "Too old: press B to send it back."
				if chk["state"] == "docket":
					return "Check the docket against the ORDER."
				if chk.get("choice", false):
					return "A: slump test it. Y: skip it (risk shown)."
				if not chk["checked"]:
					return "Slump test at the TRUCK BAY."
				return "80 to 120: A. Stiff: X. Wet: B."
			if line.can_wave_in():
				return "Press A at the TRUCK BAY: wave it in."
			return "Keep the trucks coming."
	return ""

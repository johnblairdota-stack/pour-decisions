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

## [title, the story so far] for where the job's up to.
func _story_now() -> Array:
	var g = game
	var floor_name := "TANK FLOOR" if g.k == g.TUT_FIRST else "ROOF SLAB"
	match g.phase:
		"columns", "deck":
			if g.k == g.TUT_FIRST:
				return ["WATER TOWER · THE TANK FLOOR", "The shaft below was cast in 3 m lifts with jump forms: pour a lift, climb the forms, pour the next. Up top, the cone flares out to carry the tank."]
			return ["WATER TOWER · THE TANK WALL", "The tank's wall goes up on the tank floor. The boom has to climb a section to reach over it for the roof."]
		"inspect":
			return ["WATER TOWER · " + floor_name, "Pre-pour check: forms, steel and bar chairs. Then the trucks start arriving."]
		"pour":
			return ["WATER TOWER · POUR THE " + floor_name, "A round slab, pumped from the far side back to the boom. Keep the wet edge alive and keep the pokers and the screed board right behind it."]
		"screed", "cure":
			return ["WATER TOWER · " + floor_name, "Poured. It's screeded, then left to cure."]
		"climb":
			return ["WATER TOWER · CLIMB THE BOOM", "The placing boom climbs with the job: one lattice section, slung on the street, flown up by the tower crane, dogged in and pinned."]
	return ["WATER TOWER", ""]

## What this person's job needs from them next ("" if nothing).
func _tip(p) -> String:
	var g = game
	var line = g.line
	var climb = g.climb
	if g.phase == "climb":
		match p.role:
			"line":
				if climb.needs_sling():
					return "Street: the crane's hook is over the LAYDOWN. Go there and hold A to sling the section." if climb.hook_ready() or p.position.distance_to(climb.LAYDOWN) > 3.5 else "The hook's coming down. Hold A once it's there."
				if climb.needs_pins():
					if p.held_kind == "pins":
						return "Take the bag to the HAUL ROPE and press A: it goes up to the rigger."
					return "Now the pins: grab a PIN BAG at the foot of the tower (A). Four pins, R-clips on, in one sealed bag."
				return "Slung, and the pins are up. Watch it fly."
			"screed":
				return "Nothing for the screeder on a climb day. Have a breather (and a twirl)."
			"boom":
				if climb.stage in ["jack", "fly"]:
					return "You're the dogman for this. Wait at DOGMAN for the load."
				if climb.stage == "guide":
					return "Push the stick toward the green ghost: each push is a whistle to the crane. Hold A to lower it in. Y means \"slowly\"."
			"poker":
				if climb.stage in ["fly", "guide"]:
					if climb.tag_hand == p:
						return "Keep holding A: you've got the tag line. Let go and you drop it."
					return "Wait at TAG LINE. Once the load's up over the deck, hold A: you run out, grab the line and walk it back."
			"pump":
				if p.busy != "rigger":
					return "Go to RIGGER and press A to work the climbing frame."
				match climb.stage:
					"jack":
						return "Press A to pump the rams. Each stroke lifts the boom about half a metre."
					"roll":
						return "Hold A to roll the new section in along the runway."
					"pin":
						match climb.pin_sub:
							"wait":
								return "Waiting for the pins: the truck hand sends them up the haul rope."
							"split":
								return "Take a pin set and pull its R-clip off: press A."
							"align":
								return "Stick up or down till the holes glow green, then A for the podger."
							"drive":
								return "Hold A to wind the hammer back, let go in the gold. Three clean blows."
							"clip":
								return "Hold A: the R-clip back on through the pin."
		return ""
	if g.phase == "inspect":
		if p.role == "line":
			return "Head to the TRUCK BAY: the first truck's already backed on."
		return ""
	if g.phase != "pour":
		return ""
	# The start-up and the washout: one person, one place, one button
	var ops = g.ops
	if ops.busy() and ops.role() == p.role:
		match ops.stage:
			"start":
				return "Start-up: at the PUMP PANEL, hold A to start the pump."
			"air":
				return "The pump's pushing the air out ahead of it: hot air out of the end hose, the dragon breathing. Press A to radio it down." if ops.step_t >= ops.TRAVEL_T else "Watch the end of the hose: hot air's coming."
			"slurry_in":
				return "Hold A at the PUMP PANEL to tip the slurry in: cement, sand and water. It coats the inside of the line so the concrete slides."
			"slurry_out":
				return "The slurry's at the hose. It mustn't go in the slab: swing the hose over the BIN on the scaffold (the button goes gold) and hold A to pump it in."
			"concrete":
				return "Concrete's coming through. Press A to radio: concrete's on!"
			"water_in":
				return "Washout: hold A at the PUMP PANEL to clean out the hopper and fill it with water."
			"push":
				return "The water's pushing the last of the concrete out. Hose over the BIN (gold) and hold A: concrete, then water, into the bin."
			"valve":
				return "Hold A at the RELEASE VALVE by the pump: the water blows back down into the settling tank."
	if ops.busy() and p.role in ["boom", "hose"]:
		return "Start-up first: the line has to be primed before any concrete goes in." if not ops.primed else "Washout under way."
	match p.role:
		"hose":
			if p.busy != "hose":
				return "Take the END HOSE: it hangs under the boom tip. Walk under it and press A."
			return "Walk the hose where it's wanted: where it glows gold, right out to the forms and into the corners. The concrete's your call: hold A for the pump, let go to stop."
		"boom":
			if p.busy != "boom":
				return "Walk to BOOM REMOTE and press A to take it."
			var adv: Dictionary = g.speed_advice
			if adv["want"] != "" and adv["level"] >= 1:
				return "X is up: switch the pump to %s (%s)." % [adv["want"].to_upper(), adv["why"]]
			if g.pipe_calls():
				return "The pipe guy calls the concrete on and off. Steer the boom with the stick so the end hose reaches where they're working, and keep it along the wet edge."
			if not line.pumping:
				return "Hold A to pump (nobody's on the end hose). The stick steers the hose. Start in the green bay."
			return "Lay it against the wet edge so it stays green. Amber means it's getting old: get back to it."
		"poker":
			if p.tool != "poker":
				return "Pick up the poker at its drive unit (A)."
			return "Hold A in the purple concrete until the bubbles stop and it goes glossy, then move on."
		"screed":
			return "Hold A to bring the board down, then walk backwards over the gold. The board pulls the surplus along into the low spots."
		"pump":
			if line.spike_on:
				return "SPIKE! A now, wherever you are: kill the pump. The faster, the more it's worth."
			if line.fix_i >= 0 or (line.blocked and not line.block_found) or (line.fail_i >= 0 and line.burst):
				return "The riser needs you: grab the part (CLAMP KITS or PIPES), up the LADDER, and fix it."
			if line.fail_i >= 0:
				return "A clamp's weeping. The pump's off: grab a CLAMP KIT and up the LADDER to swap it, then restart."
			if line.tripped:
				return "Pump's off and the pressure's easing. Hold A at the PUMP PANEL to restart it."
			if line.live and line.idle_t > line.SET_TIME * 0.5 and not line.line_down():
				return "The line's standing still. A at the PUMP PANEL strokes it so it doesn't go off."
			return "Watch the gauge on the side of the pump. The moment the needle jumps into the red, A kills the pump."
		"line":
			for tr in line.trucks:
				if tr["state"] in ["called", "approach", "back"] and tr.get("spotter") != null:
					return "Spot the truck back: hold A to wave it on, and let go when the ring glows gold, with its chute over the hopper. Too far and it backs into the hopper."
			var chk = line.needs_check()
			if chk != null:
				if chk["state"] == "docket":
					return "Not due a test: read the docket on the truck against the ORDER line above it. Same mix, A pours it. Wrong strength, stone or site, B sends it back before it goes in."
				if not chk["checked"]:
					return "Truck in: slump test at the TRUCK BAY. Every step is a hold of A that stops itself: scoop, fill to the ring, rod to 25, strike off, lift steady, lower the tape, then press A to read it. The guide over the close-up shows each step. The truck keeps feeding while you test."
				return "Your reading against the order, 100 mm ±20: in it, A uses the load. Under 80 (stiff), X adds the water the plant held back, then test again. Over 120, or batched over 90 minutes ago, B sends it back."
			if line.can_wave_in():
				return "Wave the next truck in (A at the TRUCK BAY), then spot it back onto the hopper."
			return "Keep the trucks coming. Each new load that opens before the hopper runs low grows your changeover streak."
	return ""

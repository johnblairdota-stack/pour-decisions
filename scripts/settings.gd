## Player settings, kept between sessions (user://settings.cfg).
##   incidents   0 none · 1 normal (one per pour) · 2 busy (one per bay from
##               level 3) · 3 chaos (one per bay, blockages too, from level 1)
##   ui_scale    1.0 / 1.25 / 1.5: everything on screen, for a big TV far away
##   world_text  1.0 / 1.25 / 1.5: names, station labels and signs in the world
##   docket_help the right call on a truck docket glows (always on in the tutorial)
##   fullscreen  the game fills the screen (F11 flips it)
##   gold_mode   the gold assist (buttons light up gold when it's the moment, or
##               the spot, to press them): 0 fades as each person gets good at a
##               job and comes back if they slip · 1 locked on at full sparkle · 2 off
##   dog_help    the dogman's help on climb days: 0 First Day (the swing mostly
##               damped, a quick driver, the stop ghost) · 1 On Site (the stop
##               ghost) · 2 Ticketed (full swing and lag, no ghost)
##   real_names  the real company, building and equipment names, or made-up lookalikes
##   split       the screen splits (deck on top, street below) when the crew are far apart
##   band        the Site Band: the pour plays a tune out of the site's own noises
##   vol_site, vol_band, vol_alerts   the three volumes (0..1): the site, the band, alarms
##   medals      the best medal (0 bronze, 1 silver, 2 gold; -1 not poured) for
##               each of Riverlight's floors, for the site page
extends RefCounted

const PATH := "user://settings.cfg"
const INCIDENT_NAMES := ["None", "Normal", "Busy", "Chaos"]
const DOG_HELP_NAMES := ["First Day", "On Site", "Ticketed"]
const GOLD_NAMES := ["fades as you learn", "full sparkle", "off"]

static var data := {"incidents": 1, "ui_scale": 1.25, "world_text": 1.25, "docket_help": false, "fullscreen": false, "gold_assist": true, "gold_mode": 0, "dog_help": 0, "real_names": true, "split": true, "band": true, "vol_site": 1.0, "vol_band": 1.0, "vol_alerts": 1.0, "ver": 2, "medals": []}
static var _loaded := false

## Camera test (not saved: it's for trying out the multiplayer cameras on
## your own). The camera treats these jobs' bots as people playing, so you
## see the split screen, close-ups and framing that crew would get.
const CAM_TESTS := [
	["Off", []],
	["Deck + street", ["boom", "pump"]],
	["Deck + ladder", ["boom", "line"]],
	["Two on the deck", ["poker", "screed"]],
	["Deck, ladder + street", ["boom", "line", "pump"]],
	["Four players", ["boom", "poker", "pump", "line"]],
	["Whole crew", ["boom", "poker", "screed", "hose", "pump", "line"]],
]
static var cam_test := 0

static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in data.keys():
			data[k] = cf.get_value("game", k, data[k])
		# Settings saved before screen text defaulted to 125% (TV-sized)
		# come up to it once
		if int(cf.get_value("game", "ver", 1)) < 2:
			data["ui_scale"] = maxf(float(data["ui_scale"]), 1.25)
			data["ver"] = 2
		# (the old on/off gold switch: off stays off)
		if not cf.has_section_key("game", "gold_mode") and not bool(data["gold_assist"]):
			data["gold_mode"] = 2

static func value(key: String):
	ensure()
	return data[key]

static func put(key: String, v) -> void:
	ensure()
	data[key] = v
	var cf := ConfigFile.new()
	for k in data.keys():
		cf.set_value("game", k, data[k])
	cf.save(PATH)

## Puts the window in or out of full screen to match the setting.
static func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(value("fullscreen")) else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)

static func toggle_fullscreen() -> void:
	put("fullscreen", not bool(value("fullscreen")))
	apply_window()

## Real names, used with permission, or clearly made-up lookalikes (for
## showing the game round without the real brands).
const REAL := {"pumper": "SCP", "site": "Riverlight", "area": "Hamilton Reach", "builder": "Watpac Construction",
	"boom": "Putzmeister MX42 placing boom"}
const LOOKALIKE := {"pumper": "PourCo", "site": "Rivermark", "area": "Harbour Reach", "builder": "a tier-one builder",
	"boom": "42 m placing boom"}

static func brand(key: String) -> String:
	return String((REAL if bool(value("real_names")) else LOOKALIKE).get(key, key))

## Swaps any real names in a line of text for the current choice.
static func branded(text: String) -> String:
	if bool(value("real_names")):
		return text
	for k in REAL:
		text = text.replace(REAL[k], LOOKALIKE[k])
	return text

static func cycle(key: String, options: Array) -> void:
	var at := options.find(value(key))
	put(key, options[(at + 1) % options.size()])

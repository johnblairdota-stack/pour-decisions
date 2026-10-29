## The crew's money. Every point of work is cash ($10 a point): it rises off
## the work as a banknote, the whole crew's take for the pour is the level's
## score, and each person banks their own share in their wallet, which is
## kept between sessions under the crew member they play (Macca, Tash...).
## From the wallet (on the phone) they buy a 4x4 ute and kit it out.
##
## Also kept per crew member: how sure they are at each job, which fades the
## gold assist as they get good and brings it back if they slip.
##
## Saved in user://wallet.json:
##   {"chars": {char_id: {"cash": int, "banked": int, "utes": [ute ids],
##     "ute": selected ute id, "kit": {ute id: [item ids]},
##     "skill": {role: 0..1}}}}
extends RefCounted

const PATH := "user://wallet.json"
## Dollars per point of work
const CASH := 10

## The utes on sale (the three drivable ones from the explore mode)
const UTES := [
	{"id": "hilux", "name": "Toyota Hilux SR5", "price": 58000, "col": "e9e9e6"},
	{"id": "ranger", "name": "Ford Ranger XLT", "price": 62000, "col": "2f5d8a"},
	{"id": "shark", "name": "BYD Shark 6", "price": 57900, "col": "5c6168"},
]
## 4x4 and camping kit. `needs` is kit that has to be on the ute first.
const KIT := [
	{"id": "mudtyres", "name": "Mud-terrain tyres", "price": 2400, "shop": "4x4", "line": "Big tread for the boat ramp and the beach."},
	{"id": "lift", "name": "2-inch lift kit", "price": 3500, "shop": "4x4", "line": "Springs and shocks: sits higher, clears more."},
	{"id": "bullbar", "name": "Steel bull bar", "price": 2800, "shop": "4x4", "line": "Roo bar, recovery points, a mount for the winch."},
	{"id": "winch", "name": "12,000 lb winch", "price": 1900, "shop": "4x4", "line": "Pulls you out when the track wins.", "needs": "bullbar"},
	{"id": "snorkel", "name": "Snorkel", "price": 650, "shop": "4x4", "line": "Clean air for the motor, river crossings."},
	{"id": "lightbar", "name": "LED light bar", "price": 700, "shop": "4x4", "line": "Turns night into day on the dirt."},
	{"id": "spotlights", "name": "Driving lights", "price": 900, "shop": "4x4", "line": "A pair of spotties on the bar.", "needs": "bullbar"},
	{"id": "roofrack", "name": "Roof rack", "price": 1300, "shop": "camping", "line": "A flat platform up top for the big gear."},
	{"id": "rooftent", "name": "Rooftop tent", "price": 3900, "shop": "camping", "line": "Unfolds in a minute, sleeps two off the ground.", "needs": "roofrack"},
	{"id": "awning", "name": "Side awning", "price": 950, "shop": "camping", "line": "Shade for the camp chairs.", "needs": "roofrack"},
	{"id": "canopy", "name": "Aluminium canopy", "price": 6500, "shop": "camping", "line": "Lockable tub box with gull-wing doors."},
	{"id": "drawers", "name": "Drawer system", "price": 2300, "shop": "camping", "line": "Two slide-out drawers and a fridge slide."},
	{"id": "fridge", "name": "Camp fridge", "price": 1400, "shop": "camping", "line": "Cold drinks after the top-out."},
	{"id": "jerrycans", "name": "Jerry cans", "price": 250, "shop": "camping", "line": "Twenty litres of water and twenty of diesel."},
	{"id": "swag", "name": "Swag", "price": 550, "shop": "camping", "line": "Canvas bedroll, the old-school way to camp."},
]

static var data := {"chars": {}}
static var _loaded := false

static func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if OS.get_cmdline_user_args().has("--autotest"):
		return   # (test runs start every crew member broke and new)
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary and d.get("chars") is Dictionary:
		data = d

static func save() -> void:
	if OS.get_cmdline_user_args().has("--autotest"):
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))

## One crew member's record (made on first use).
static func of(char_id: String) -> Dictionary:
	ensure()
	var chars: Dictionary = data["chars"]
	if not chars.has(char_id):
		chars[char_id] = {"cash": 0, "banked": 0, "utes": [], "ute": "", "kit": {}, "skill": {}}
	return chars[char_id]

static func cash(char_id: String) -> int:
	return int(of(char_id).get("cash", 0))

## Pays (or docks) a crew member. Nobody's wallet goes below nothing.
static func pay(char_id: String, dollars: int) -> void:
	if char_id == "":
		return
	var w := of(char_id)
	w["cash"] = maxi(0, int(w.get("cash", 0)) + dollars)
	if dollars > 0:
		w["banked"] = int(w.get("banked", 0)) + dollars

static func ute(id: String) -> Dictionary:
	for u in UTES:
		if u["id"] == id:
			return u
	return {}

static func item(id: String) -> Dictionary:
	for k in KIT:
		if k["id"] == id:
			return k
	return {}

## The kit on this crew member's selected ute.
static func kit_on(char_id: String) -> Array:
	var w := of(char_id)
	var u: String = w.get("ute", "")
	return Array((w.get("kit", {}) as Dictionary).get(u, []))

## Buys a ute or a piece of kit for the selected ute. Returns "" when it went
## through, or why it didn't, in words for the phone.
static func buy(char_id: String, id: String) -> String:
	var w := of(char_id)
	var u := ute(id)
	if not u.is_empty():
		var owned: Array = w.get("utes", [])
		if owned.has(id):
			w["ute"] = id   # (already theirs: drive this one)
			save()
			return ""
		if cash(char_id) < int(u["price"]):
			return "Not enough in the wallet yet"
		w["cash"] = cash(char_id) - int(u["price"])
		owned.append(id)
		w["utes"] = owned
		w["ute"] = id
		save()
		return ""
	var it := item(id)
	if it.is_empty():
		return "Not in the shop"
	var on: String = w.get("ute", "")
	if on == "":
		return "Buy a ute first"
	var kit: Dictionary = w.get("kit", {})
	var have: Array = kit.get(on, [])
	if have.has(id):
		return "Already fitted"
	if it.has("needs") and not have.has(it["needs"]):
		return "Needs the %s first" % String(item(it["needs"])["name"]).to_lower()
	if cash(char_id) < int(it["price"]):
		return "Not enough in the wallet yet"
	w["cash"] = cash(char_id) - int(it["price"])
	have.append(id)
	kit[on] = have
	w["kit"] = kit
	save()
	return ""

# ------------------------------------------------------------------ skill

## How sure this crew member is at a job, 0 (new) to 1 (ticketed).
static func skill(char_id: String, role: String) -> float:
	if char_id == "":
		return 0.0
	return float((of(char_id).get("skill", {}) as Dictionary).get(role, 0.0))

static func add_skill(char_id: String, role: String, d: float) -> void:
	if char_id == "" or role == "":
		return
	var w := of(char_id)
	var s: Dictionary = w.get("skill", {})
	s[role] = clampf(float(s.get(role, 0.0)) + d, 0.0, 1.0)
	w["skill"] = s

## "$12,400"
static func money(dollars: int) -> String:
	var neg := dollars < 0
	var s := str(absi(dollars))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-$" if neg else "$") + s + out

## The real site trades, and every task the game has sorted into the trade
## that really does it (the real site roles plan, sections 09 and 13, John,
## 24 Nov 2026). A person picks a trade for the day; any task in that trade is
## theirs to take. For now each person still starts on one task (their job,
## crew.gd's role) and stays there, so the game plays as it did. Later stages
## let people move between their trade's tasks, with bots covering the rest.
##
## Pour days: Pumpy (boom op, line hand, pump op) and Concreter (poker,
## screed, and the gate: trucks in and slump tests). Gate crew, crane op and
## doggers are bots on a pour day. Climb days: Rigger, Dogger, Crane op, and
## one Pumpy to park the boom.
extends RefCounted

## Each trade: what it's called, its plural, its seats on each day type (0:
## not on site that day as a player trade), and its one-line job.
const TRADES := {
	"pumpy": {"name": "Pumpy", "plural": "Pumpies", "seats": {"pour": 3, "climb": 1},
		"line": "Runs the pump, the pipe and the boom. Line repairs and the washout."},
	"concreter": {"name": "Concreter", "plural": "Concreters", "seats": {"pour": 3, "climb": 0},
		"line": "Poker, screed, bull float, defects. Also the gate: trucks in and slump tests."},
	"gate": {"name": "Gate crew", "plural": "Gate crew", "seats": {"pour": 0, "climb": 0}, "bots_only": true,
		"line": "The traffic controller and the concrete tester. Bots, unless a concreter walks over."},
	"rigger": {"name": "Rigger", "plural": "Riggers", "seats": {"pour": 0, "climb": 3},
		"line": "Pins, shackles, wedges, feet, pipes and ladders."},
	"dogger": {"name": "Dogger", "plural": "Doggers", "seats": {"pour": 0, "climb": 2},
		"line": "Calls the crane on the radio. Bottom: the height at the pipe feed. Top: the lifts and the tag line."},
	"crane": {"name": "Crane op", "plural": "Crane ops", "seats": {"pour": 0, "climb": 1},
		"line": "Hoist, slew and trolley on the doggers' calls. Can't always see the load."},
}
## Pour-day player trades, in pick order.
const POUR_TRADES := ["pumpy", "concreter"]
## Each trade's hat colour (ui.gd ROLE uses the same for its jobs).
const COL := {"pumpy": Color("ff7a1a"), "concreter": Color("7cd992"), "gate": Color("ffc72c"),
	"rigger": Color("3d8bff"), "dogger": Color("c49bff"), "crane": Color("f4f7fa")}
const CLIMB_TRADES := ["rigger", "dogger", "crane", "pumpy"]

## Today's jobs (crew.gd's role keys) and the trade each belongs to.
const ROLE_TRADE := {"boom": "pumpy", "hose": "pumpy", "pump": "pumpy", "poker": "concreter", "screed": "concreter", "line": "concreter"}
## The task each job starts on and holds on a pour.
const ROLE_TASK := {"boom": "boom_remote", "hose": "end_hose", "pump": "pump_panel", "poker": "poke", "screed": "screed", "line": "truck_in"}

## Every task: its trade, what it's called, its kind (held: all pour;
## once; popup; every: every truck; lift: a climb lift), the day type, the job
## that does it in the game today ("" if nobody yet), and whether it's in the
## game yet.
const TASKS := {
	# Pumpy, pour day
	"boom_remote": {"trade": "pumpy", "name": "Boom remote", "kind": "held", "day": "pour", "role": "boom", "in_game": true},
	"end_hose": {"trade": "pumpy", "name": "End hose", "kind": "held", "day": "pour", "role": "hose", "in_game": true},
	"pump_panel": {"trade": "pumpy", "name": "Pump panel", "kind": "held", "day": "pour", "role": "pump", "in_game": true},
	"prime": {"trade": "pumpy", "name": "Prime the line", "kind": "once", "day": "pour", "role": "hose", "in_game": true},
	"line_repair": {"trade": "pumpy", "name": "Line repair", "kind": "popup", "day": "pour", "role": "pump", "in_game": true},
	"sponge_load": {"trade": "pumpy", "name": "Load the sponge ball", "kind": "once", "day": "pour", "role": "pump", "in_game": true},
	"sponge_catch": {"trade": "pumpy", "name": "Catch the sponge ball", "kind": "once", "day": "pour", "role": "hose", "in_game": true},
	"hopper_wash": {"trade": "pumpy", "name": "Hose the hopper", "kind": "once", "day": "pour", "role": "line", "in_game": true},
	"park_boom": {"trade": "pumpy", "name": "Park the boom", "kind": "once", "day": "both", "role": "boom", "in_game": true},
	# Concreter, pour day: the deck
	"poke": {"trade": "concreter", "name": "Poker", "kind": "held", "day": "pour", "role": "poker", "in_game": true},
	"screed": {"trade": "concreter", "name": "Screed", "kind": "held", "day": "pour", "role": "screed", "in_game": true},
	"bull_float": {"trade": "concreter", "name": "Bull float", "kind": "popup", "day": "pour", "role": "screed", "in_game": true},
	"defects": {"trade": "concreter", "name": "Fix the defects", "kind": "once", "day": "pour", "role": "screed", "in_game": true},
	# Concreter, pour day: the gate (really the traffic controller and the
	# concrete tester; bots do these unless a concreter walks over)
	"truck_in": {"trade": "concreter", "name": "Wave the truck in", "kind": "every", "day": "pour", "role": "line", "in_game": true, "gate": true},
	"docket": {"trade": "concreter", "name": "Check the docket", "kind": "every", "day": "pour", "role": "line", "in_game": true, "gate": true},
	"slump": {"trade": "concreter", "name": "Slump test", "kind": "every", "day": "pour", "role": "line", "in_game": true, "gate": true},
	"radio_load": {"trade": "concreter", "name": "Radio the pump", "kind": "every", "day": "pour", "role": "line", "in_game": true, "gate": true},
	# Pumpy, climb day
	"l1_bend": {"trade": "pumpy", "name": "L1 bend off and on", "kind": "once", "day": "climb", "role": "", "in_game": false},
	"bracket_pipes": {"trade": "pumpy", "name": "Bracket the pipes", "kind": "once", "day": "climb", "role": "", "in_game": false},
	"mob_check": {"trade": "pumpy", "name": "Mobilisation check", "kind": "once", "day": "climb", "role": "boom", "in_game": true},
	# Rigger, climb day
	"chain_boom": {"trade": "rigger", "name": "Chain the boom", "kind": "once", "day": "climb", "role": "", "in_game": false},
	"pins": {"trade": "rigger", "name": "Boom and adaptor pins", "kind": "once", "day": "climb", "role": "pump", "in_game": true},
	"shackles": {"trade": "rigger", "name": "Shackle the lugs", "kind": "once", "day": "climb", "role": "pump", "in_game": true},
	"wedges": {"trade": "rigger", "name": "Wedges and corner plates", "kind": "once", "day": "climb", "role": "hose", "in_game": true},
	"feet": {"trade": "rigger", "name": "Feet in and out", "kind": "once", "day": "climb", "role": "hose", "in_game": true},
	"fit_pipes": {"trade": "rigger", "name": "Fit the pipes", "kind": "once", "day": "climb", "role": "hose", "in_game": true},
	"ladders": {"trade": "rigger", "name": "Fit the ladders", "kind": "once", "day": "climb", "role": "", "in_game": false},
	# Dogger, climb day (the builder's crane crew)
	"dog_bottom": {"trade": "dogger", "name": "Bottom dogger: call the height", "kind": "lift", "day": "climb", "role": "boom", "in_game": true},
	"dog_top": {"trade": "dogger", "name": "Top dogger: call the lifts", "kind": "lift", "day": "climb", "role": "", "in_game": false},
	"tag_line": {"trade": "dogger", "name": "Tag line", "kind": "lift", "day": "climb", "role": "poker", "in_game": true},
	"send_pipes": {"trade": "dogger", "name": "Send the pipes up", "kind": "lift", "day": "climb", "role": "line", "in_game": true},
	# Crane op, climb day (a bot crane today)
	"crane_cab": {"trade": "crane", "name": "Crane cab", "kind": "held", "day": "climb", "role": "", "in_game": false},
}

## The trade a job (crew.gd role key) belongs to, "" if none.
static func of_role(role: String) -> String:
	return String(ROLE_TRADE.get(role, ""))

static func trade_name(trade: String) -> String:
	return String((TRADES.get(trade, {}) as Dictionary).get("name", trade))

static func plural(trade: String) -> String:
	return String((TRADES.get(trade, {}) as Dictionary).get("plural", trade))

## How many seats `trade` has on a day type ("pour" or "climb").
static func seats(trade: String, day := "pour") -> int:
	return int(((TRADES.get(trade, {}) as Dictionary).get("seats", {}) as Dictionary).get(day, 0))

## The task ids in `trade` for a day type (tasks for "both" days count on either).
static func tasks(trade: String, day := "pour", in_game_only := false) -> Array:
	var out: Array = []
	for id in TASKS:
		var t: Dictionary = TASKS[id]
		if t["trade"] != trade or not (t["day"] == day or t["day"] == "both"):
			continue
		if in_game_only and not bool(t["in_game"]):
			continue
		out.append(id)
	return out

## The jobs (role keys) that make up a trade's seats on a pour, in pick order.
static func roles(trade: String) -> Array:
	var out: Array = []
	for role in ["boom", "hose", "pump", "poker", "screed", "line"]:
		if ROLE_TRADE[role] == trade:
			out.append(role)
	return out

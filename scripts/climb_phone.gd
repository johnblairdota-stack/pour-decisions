## Spire's crane days on the phone (John, 28 Nov: the TV's "who does what"
## box was too much to read). The TV says only who's in which seat. Each
## person's phone has their own step by step for the day: the steps they've
## done ticked, the one that's on now lit, the ones coming, and above them
## whose turn it is ("YOUR TURN · UP THE LADDER", "WAITING ON P2 KIRI ·
## YOU'RE NEXT").
##
## It reads the day off whichever's running: the column climb (mast_climb.gd)
## or the install / erection day (mast_erect.gd). phones.gd sends it.
extends RefCounted

const Trades := preload("res://scripts/trades.gd")

const WINDOW := 4            # steps on the phone at once (the one before, now, and what's next)
const TV_FOOT := "\nYour steps are on your phone"

## The column climb, step by step, said to the person doing it.
const SPIRE_SAY := {
	"park": "At the remote: hold A to fold the boom away",
	"check": "Last job. At the remote: hold A for the mobilisation check",
	"harness": "Up the column's ladder to the top. Hold A: harness on, onto the boom",
	"boom_pins": "Hold A: knock out the 4 boom pins",
	"adaptor_pins": "Boom's gone. Hold A: knock out the 4 adaptor pins",
	"adaptor_in": "Adaptor's back on. Hold A: drive its 4 pins in",
	"harness2": "Boom's back on. Hold A: harness on, onto the boom",
	"boom_in": "Hold A: drive the 4 boom pins in",
	"shackle": "Up the ladder to the top of the column. Hold A: shackle the 2 red lugs",
	"unshackle": "Wedges are in. Up top again, hold A: shackles off",
	"wedges_out": "Down the ladder in the opening. Hold A: knock the wedges out",
	"feet_in": "Down to the feet. Hold A: pull them in off the pads",
	"fit_pipe": "Each time the column stops: hold A to fit the pipe under it",
	"feet_out": "Column's up. Hold A: feet out onto the pads",
	"wedges_in": "Up to the wedges. Hold A: drive them in",
	"lift": "On the ladder at the column's foot. Tap A to radio ALL STOP at the mark, then hold A to inch it",
	"send_pipe": "Down at the haul rope: hold A to send a pipe up",
	"boom_off": "At the radio spot on the deck. Tap A: call the crane to take the boom off",
	"adaptor_off": "Tap A: call the crane to take the adaptor off",
	"hook_down": "Tap A: call the hook down to the column",
	"adaptor_on": "Tap A: call the adaptor back on",
	"boom_on": "Tap A: call the boom back on",
}
const LOOP := ["lift", "send_pipe", "fit_pipe"]

## The crane day that's running (mast_erect.gd or mast_climb.gd), or null.
static func day(g):
	for key in ["erect", "mast"]:
		var d = g.get(key)
		if d != null and is_instance_valid(d) and d.active:
			return d
	return null

## One line of the TV's roll call: "TOP RIGGER · P1 TASH".
static func roll_line(g, role: String, kind: String) -> String:
	var seat := String(((Trades.CLIMB_SEAT.get(kind, {}) as Dictionary).get(role, ["", role]) as Array)[1]).to_upper()
	var p = g.crew.crew.get(role)
	if p == null:
		return seat
	if p.bot:
		return "%s · %s (bot)" % [seat, String(p.char_name).to_upper()]
	return "%s · P%d %s" % [seat, p.index, String(p.char_name).to_upper()]

## Every step `role` has today, in order: [words, done, on now].
static func plan(g, role: String) -> Array:
	var d = day(g)
	var out: Array = []
	if d == null:
		return out
	if d.get("steps") is Array:
		# (the install and erection days: a built list of steps, each with its job)
		var list: Array = d.steps
		for i in list.size():
			var s: Dictionary = list[i]
			if String(s.get("role", "")) == role:
				out.append([String(s.get("say", "")), i < int(d.si), i == int(d.si)])
		return out
	var order: Array = d.STEP_ORDER
	var ci: int = order.find(d.step)
	var loop_end: int = order.find("fit_pipe")
	for i in order.size():
		var id := String(order[i])
		if String(d.STEP_ROLE.get(id, "")) != role:
			continue
		var words := String(SPIRE_SAY.get(id, String(d.STEP_SAY.get(id, id)).capitalize()))
		var done := i < ci
		if id in LOOP:
			# (round and round, a pipe at a time: done when the last pipe's in)
			done = ci > loop_end
			if not done:
				words += " (pipe %d of %d)" % [mini(int(d.lift_i) + 1, int(d.PIPES)), int(d.PIPES)]
		out.append([words, done, i == ci])
	return out

## What person `p`'s phone shows: {steps: [[button, words, done]], i (the lit
## one, or -1), go (whose turn it is)}. Empty when there's no crane day on.
static func state(g, p) -> Dictionary:
	var d = day(g)
	if d == null or p == null or d.get("cab") == p:
		return {}
	var rows := plan(g, String(p.role))
	var cur := -1
	var nxt := -1
	for i in rows.size():
		if rows[i][2]:
			cur = i
		elif nxt < 0 and not rows[i][1]:
			nxt = i
	var at := cur if cur >= 0 else (nxt if nxt >= 0 else rows.size() - 1)
	var from := clampi(at - 1, 0, maxi(0, rows.size() - WINDOW))
	var steps: Array = []
	for i in range(from, mini(rows.size(), from + WINDOW)):
		steps.append(["A", ("✓ " if rows[i][1] else "") + String(rows[i][0]), 1 if rows[i][1] else 0])
	var tt: Array = d.turn_text(p, d.job())
	var go := String(tt[0]).replace("\n", " · ")
	if go == "" and cur < 0 and rows.size() > 0 and nxt < 0:
		go = "ALL YOUR JOBS ARE DONE"
	return {"steps": steps, "i": (cur - from) if cur >= 0 else -1, "go": go}

## Moving between tasks in your trade (the real site trades plan, stage 5,
## board section 10). Nobody owns a task: a trade is a small crew that
## covers all of its tasks between them. Walk up to a trade-mate bot at its
## task (the boom remote, the end hose, the pump panel; the poker, the screed,
## the truck bay) and press Y: it's yours. The bot says "All yours" and takes
## the job you left (it drives your old chibi there), so the pour never has a
## gap. Your job becomes whatever task you're actually doing.
##
## Underneath it's the swap the Smoko menu does (crew.assign): you hop into
## the chibi that's on the task, the bot into yours. Only a bot's task can
## be taken this way: a person's is theirs till they walk off it.
##
## Each task spot also says who's on it (a P tag, or the bot's name), in the
## colour of the trade it belongs to, so two pumpies can split the boom and the
## hose without guessing.
extends Node

const Trades := preload("res://scripts/trades.gd")
const UI := preload("res://scripts/ui.gd")
const F := preload("res://scripts/factory.gd")

const REACH := 1.9        # m from the bot on the task
const COOL := 1.5         # s between takes, so two people can't ping-pong a task
const PHASES := ["inspect", "pour"]
## The task spots (main.gd stations) that show who's on them: station -> job.
const SPOTS := {"boom": "boom", "hose": "hose", "panel": "pump", "poker": "poker", "screed": "screed", "bay": "line"}

var game
var _cool := {}           # person index -> s till they can take another
var _who := {}            # station -> its "who" Label3D

func setup(g) -> void:
	game = g

## The task a job's on, in words ("pump panel").
static func task_name(role: String) -> String:
	var t: String = Trades.ROLE_TASK.get(role, "")
	return String((Trades.TASKS.get(t, {}) as Dictionary).get("name", UI.ROLE_NAME.get(role, role))).to_lower()

## The trade-mate bot person `p` could take over from right now, or null.
func candidate(p):
	if p.bot or p.covering or not game.phase in PHASES:
		return null
	if p.busy != "" or p.held != null or p.zone in ["ladder", "hoist"]:
		return null
	var tr := Trades.of_role(p.role)
	if tr == "":
		return null
	var best = null
	var best_d := REACH
	for role in Trades.roles(tr):
		var q = game.crew.crew[role]
		if q == p or not q.bot or q.covering or q.zone != p.zone or q.zone in ["ladder", "hoist"]:
			continue
		var d := Vector2(q.position.x - p.position.x, q.position.z - p.position.z).length()
		if d < best_d:
			best_d = d
			best = q
	return best

## Each person, after their own job's had its go (main.gd's player loop):
## the Y button to take a trade-mate bot's task, when one's in reach and Y
## isn't already doing something for their own job.
func offer(p, delta: float) -> void:
	var i: int = p.index
	_cool[i] = maxf(0.0, float(_cool.get(i, 0.0)) - delta)
	if p.covering:
		# (the leading hand's driving them: no taking anything till they've
		# been back on their own buttons a moment)
		_cool[i] = maxf(_cool[i], 1.0)
	if _cool[i] > 0.0:
		return
	if _offer_claim(p):
		return
	var q = candidate(p)
	if q == null:
		return
	for cu in p.cues:
		if String(cu[0]) == "Y":
			return
	p.cue("slow", "take the " + task_name(q.role))
	if p.slow_pressed():
		take(p, q)

## Person `p` takes bot `q`'s task: they swap chibis, and the bot heads off
## to the job `p` left.
func take(p, q) -> bool:
	var was: String = p.role
	var role: String = q.role
	var bot_name: String = q.char_name
	if not game.crew.assign(p.index, role):
		return false
	_cool[p.index] = COOL
	var me = game.crew.crew[role]
	var bot = game.crew.crew[was]
	bot.bark("All yours!")
	game.sfx.hit("ding")
	game.hud.toast("P%d's on the %s. %s's taking the %s." % [me.index, task_name(role), bot_name, task_name(was)], 2.4)
	if game.has_method("haptic"):
		game.haptic(me, UI.BUZZ["done"])
	if game.autotest:
		print("[autotest]   P%d takes the %s off %s (bot), who goes to the %s" % [me.index, task_name(role), bot_name, task_name(was)])
	return true

## Every frame: the task spots say who's on them, and a pop-up's claim is kept up to date.
func tick() -> void:
	if game.autotest:
		_test()
	_tick_claims()
	for key in SPOTS:
		if not game.stations.has(key):
			continue
		var st: Dictionary = game.stations[key]
		var lbl: Label3D = st["label"]
		var who: Label3D = _who.get(key)
		if who == null:
			who = F.label3d("", 26, UI.BONE)
			who.position.y = -0.42
			who.layers = lbl.layers
			who.no_depth_test = true
			who.render_priority = 9
			lbl.add_child(who)
			_who[key] = who
		var q = game.crew.crew.get(SPOTS[key])
		var txt := ""
		var col: Color = UI.DIM
		if q != null:
			if q.bot:
				txt = q.char_name + " · bot"
			else:
				txt = "P%d %s" % [q.index, q.char_name]
				col = q.tag_color
		if who.text != txt:
			who.text = txt
		if who.modulate != col:
			who.modulate = col

## Dev: `--takeover=<job>` has P1 take that trade-mate bot's task 15 s into
## the first pour, then reports where everyone's got to 20 s later.
var _test_at := -1.0
var _test_press := 0
func _test() -> void:
	if _test_at == -2.0 or game.phase != "pour":
		return
	var want := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--takeover="):
			want = a.substr(11)
	if want == "" or game.crew.humans().is_empty():
		_test_at = -2.0
		return
	if _test_at < 0.0 and game.phase_t > 15.0:
		var p = game.crew.humans()[0]
		var q = game.crew.crew.get(want)
		_test_at = game.phase_t
		if q == null or not q.bot or Trades.of_role(q.role) != Trades.of_role(p.role):
			print("[autotest]   takeover: can't take %s from P%d's %s" % [want, p.index, p.role])
			_test_at = -2.0
			return
		_uncover(p)
		p.busy = ""
		# (stood beside the bot, then Y, through the same offer() a person's press goes through)
		p.zone = q.zone
		p.position = q.position + Vector3(0.8, 0, 0.4)
		p.ai_slow = false
		_test_press = 3
	elif _test_press > 0:
		_test_press -= 1
		var p = game.crew.humans()[0]
		_uncover(p)
		p.ai_slow = _test_press == 1
	elif _test_at >= 0.0 and game.phase_t > _test_at + 20.0:
		_test_at = -2.0
		var rows: Array = []
		for role in Trades.roles(Trades.of_role(want)):
			var q = game.crew.crew[role]
			rows.append("%s=%s%s busy '%s' zone %s" % [role, "bot " if q.bot else "P%d " % q.index, q.char_name, q.busy, q.zone])
		print("[autotest]   takeover 20 s on: " + "; ".join(rows))

func _uncover(p) -> void:
	if p.covering:
		p.uncover()
		game.lead_hand.stop(p, true)

# ------------------------------------------------------------------ "Mine!": claiming a pop-up

## A pop-up in a trade (today: a line repair, a pumpy's): the bot whose job it
## is calls it and waits a moment for a person in the trade to say "Mine!" (Y)
## before going itself. A claim holds while they get on with it, and goes back
## to the bot if they leave it.
const CLAIM_WAIT := 4.0       # s the bot waits on a call before it goes
const CLAIM_IDLE := 15.0      # s a claimant can stand idle before the bot takes it back
var claims := {}              # pop-up -> the person who said "Mine!"
var _called_at := {}          # pop-up -> phase_t when the bot called it

## Whether a line repair's waiting on someone (the pump's off and something's broken on the riser).
func _repair_up() -> bool:
	var line = game.line
	if game.phase != "pour" or line == null or line.spike_on:
		return false
	if game.let_burst and line.fail_i >= 0 and not line.burst:
		return false
	return line.fail_i >= 0 or line.fix_i >= 0 or (line.blocked and not line.block_found)

## The people who could claim the repair: pumpies who aren't the pump op, while a bot is.
func _claimers() -> Array:
	var out: Array = []
	var po = game.crew.crew.get("pump")
	if po == null or not po.bot:
		return out
	for h in game.crew.humans():
		if h != po and Trades.of_role(h.role) == "pumpy" and not h.covering:
			out.append(h)
	return out

## The person who's claimed a pop-up, or null.
func claimed_by(id: String):
	var c = claims.get(id)
	return c if c != null and is_instance_valid(c) and not c.bot else null

## For the pump bot (bots.gd): stay at the panel instead of going up the riser,
## because a person's said "Mine!", or the call's still out for one.
func repair_held() -> bool:
	if not _repair_up():
		return false
	if claimed_by("repair") != null:
		return true
	return not _claimers().is_empty() and game.phase_t - float(_called_at.get("repair", game.phase_t)) < CLAIM_WAIT

## Dev: `--claimrepair` has P1 (a pumpy, not the pump op) call Mine! on each
## line repair and do it through the pump bot's own repair moves.
var _claimtest: bool = OS.get_cmdline_user_args().has("--claimrepair")

func _test_claim() -> void:
	var people: Array = game.crew.humans()
	if people.is_empty():
		return
	var p = people[0]
	game.bots._clear(p)
	if claimed_by("repair") == p:
		game.bots._repair(p, get_process_delta_time())
	elif _repair_up() and claimed_by("repair") == null and Trades.of_role(p.role) == "pumpy" and p.role != "pump":
		# (a person pressing anything takes their job back off the leading hand: so does this)
		_uncover(p)
		p.idle_in = 0.0
		_cool[p.index] = 0.0
		p.ai_slow = int(game.phase_t * 10.0) % 2 == 0

var _down_t := 0.0            # s the repair's been off (a blink between steps isn't the end of it)
var _test_ladder := {}        # dev: who was up the ladder while the claim held

func _tick_claims() -> void:
	if _claimtest and game.autotest:
		_test_claim()
	if not _repair_up():
		_down_t += get_process_delta_time()
		if _down_t > 1.5:
			if game.autotest and claims.has("repair") and _claimtest:
				print("[autotest]   claimed repair done: up the ladder %s" % [_test_ladder.keys()])
			claims.erase("repair")
			_called_at.erase("repair")
			_test_ladder.clear()
		return
	_down_t = 0.0
	if _claimtest and claimed_by("repair") != null:
		for q in game.crew.crew.values():
			if q.zone == "ladder":
				_test_ladder[("P%d " % q.index if not q.bot else "bot ") + q.role] = true
	if not _called_at.has("repair"):
		_called_at["repair"] = game.phase_t
		if not _claimers().is_empty():
			var po = game.crew.crew["pump"]
			var j: int = game.line.fix_i if game.line.fix_i >= 0 else game.line.fail_i
			po.bark(("Clamp's gone on %d! Anyone?" % (j + 1)) if j >= 0 else "Line's blocked! Anyone?")
	var c = claimed_by("repair")
	if c != null and (c.idle_in > CLAIM_IDLE or c.covering or Trades.of_role(c.role) != "pumpy" or c.role == "pump"):
		claims.erase("repair")
		game.crew.crew["pump"].bark("I'll get it.")
		if game.autotest:
			print("[autotest]   P%d's repair claim lapses: the pump bot goes" % c.index)

## Y on a called pop-up: "Mine!". True when the button went to that.
func _offer_claim(p) -> bool:
	if not _repair_up() or claimed_by("repair") != null or not _claimers().has(p):
		return false
	# (once the bot's on the ladder it's too late to call it)
	var po = game.crew.crew["pump"]
	if po.zone in ["ladder", "hoist"]:
		return false
	for cu in p.cues:
		if String(cu[0]) == "Y":
			return false
	p.cue("slow", "Mine! fix the line", -1.0, true)
	if p.slow_pressed():
		claims["repair"] = p
		p.bark("Mine!")
		po.bark("All yours. I'll mind the panel.")
		game.sfx.hit("ding")
		game.hud.toast("P%d's got the line repair. %s stays on the panel." % [p.index, po.char_name], 2.4)
		if game.autotest:
			print("[autotest]   P%d calls Mine! on the line repair" % p.index)
		return true
	return false

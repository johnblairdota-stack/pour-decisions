## Cash. Every bit of real work earns money the moment it's done: a banknote
## with the amount on it rises off whoever did it and fades. The whole crew's
## take is the slab's score (the pool); each person also banks what they
## earned, plus an even share of the crew-wide money, in their own wallet
## (wallet.gd), kept between sessions. There's no ceiling, just a ladder of
## ranks to climb, from Labourer up to Concrete Legend.
extends Node

const F := preload("res://scripts/factory.gd")
const Wallet := preload("res://scripts/wallet.gd")
const CashArt := preload("res://scripts/cash_art.gd")

## The site's rate card: what each kind of work is worth against the
## points the jobs hand out. Steady work (screeding, pouring) pays by the
## square metre, so on the full-size slab it pays less a cell; the calls and
## the quick reactions, where a person makes the difference, pay more.
const RATE := {
	"Screeding": 0.25, "Poker": 0.9, "Concrete placed": 0.9, "On the end hose": 1.2,
	"Spikes killed": 3.0, "Clamp swapped before it burst": 2.0, "Line repairs": 2.0,
	"Blockage found by tap test": 2.0, "Safety pins in": 1.5, "Pump restarted": 1.0,
	"Good loads in": 2.0, "Bad loads turned away": 3.0, "Slump tests": 1.5,
	"Trucks spotted in": 2.0, "Tight changeovers": 2.0, "Called it on the dot": 2.0,
	"Good call on the output": 1.5, "Sections landed": 2.0, "Tag line": 2.0, "R-clips on": 1.5,
}

## The crew's ladder, in dollars banked over the chapter. A bronze crew
## takes about $25,000 a slab, so top-out is around Site Super; Legend
## takes a crew that pours better than the bots.
const RANKS := [
	[0, "Labourer"],
	[25000, "Apprentice"],
	[70000, "Concreter"],
	[130000, "Leading Hand"],
	[200000, "Foreman"],
	[260000, "Site Super"],
	[370000, "Concrete Legend"],
]
const GOLD := Color("ffd23f")
const POP := Color("ffffff")   # points rising off people: white (gold means the assist)
const LOSS := Color("ff5a5f")

## A medal for every slab, the way a builder would judge a pour: was it good
## (the engineer's quality score) and was it quick (the pour clock against the
## slab's target times). The bots work at
## the crew's level: bronze to start, a step up each time the crew beats their
## medal, a step down when it falls short, so good players aren't held back
## and new ones aren't left behind.
const MEDALS := ["Bronze", "Silver", "Gold"]
const SILVER_Q := 85.0
const GOLD_Q := 95.0
## Target pour times (s) for silver and gold, by kit. Pours get a little
## longer as the riser grows, so they ease up the building.
## Tuned so an all-bot crew (bots at bronze, slips and all) lands on Bronze;
## Silver is a crew as good as a bot that never switches off (people don't
## take phone calls mid-pour); Gold is better than that.
## (Tower times re-measured on the full-size slab: bronze bots 140-175 s,
## silver and gold bots about 118-120 s, where quality sets them apart.)
const SILVER_T := {"tower": 135.0, "truck": 110.0, "tutorial": 60.0}
const GOLD_T := {"tower": 121.0, "truck": 99.0, "tutorial": 52.0}
const T_PER_LEVEL := 0.4
## Seconds of slack per person playing, so bringing friends in (who talk,
## learn and get in each other's way) never costs the crew a medal
const T_PER_PERSON := 3.0
var bot_tier := 0
var _forced := false           # --bots=bronze/silver/gold pins it (testing)
var medals: Array = []         # the medal (0..2) for each slab so far

var game
var total := 0
var level := 0                 # this slab's points so far
var by_role := {}              # role -> points this slab
var by_person := {}            # "P1" etc -> dollars over the chapter
var wallet_pour := {}          # char id -> dollars into their wallet this slab
var log_rows := {}             # what earned them this slab: label -> points
var role_rows := {}            # role -> {label -> points} this slab
var costs: Array = []          # everything that cost money this slab: {why, pts, role, t}

## The job that owns a crew-wide cost (a burst is the pump operator's to stop)
const COST_OWNER := {"Clamp burst": "pump", "Line blocked": "pump", "Hose whip": "boom", "Finished by hand": "boom",
	"Start-up and washout held up": "pump"}
## One line on how not to do it again, for the slab report's WHAT WENT WRONG
const COST_HINT := {
	"Clamp burst": "A spike was left too long. Kill the pump the moment the gauge flashes, then fix the clamp.",
	"Line blocked": "A stiff or old load on HIGH packs the line. Drop to LOW while the gauge creeps.",
	"Pumped into a blockage": "When A goes red and shakes, let go and wait for the fix.",
	"Hose whip": "The boom swung too fast. Small pushes near the hose hand.",
	"Bad load accepted": "Slump test every truck. Too wet or too old goes back with B.",
	"Bad concrete in before the call": "Make the load call before that truck's concrete goes in.",
	"Driver had to make the call": "The truck sat waiting. Test it before the driver gives up.",
	"Trucks spotted in": "Call STOP before the truck backs into the hopper.",
	"Hopper spilled over": "Ease the chute back when the hopper's near the brim.",
	"Over-vibrated": "Pull the poker out once the bubbles stop.",
	"Footprints in the finish": "Keep off concrete that's been screeded.",
	"Floated too early": "Wait for the concrete to firm up before floating.",
	"Finished by hand": "Get the boom over every corner of the slab.",
	"Sections wrecked": "Slow the crane near the landing and steady it with the tag lines.",
	"Pins left without an R-clip": "Every tower pin gets its R-clip.",
	"Missed the bin": "Keep the boom over the slurry bin while it pumps.",
	"Missed the sponge ball": "Be at the end hose to catch the sponge ball at the washout.",
	"Start-up and washout held up": "Get the start-up slurry and washout done promptly.",
	"Water added past the docket": "Never add more water than the docket allows.",
	"Water added to a good load": "Only add water when the slump test reads stiff.",
	"Water added to a wet load": "A wet load needs no water. Send it back if it's too wet.",
	"Water added to an old load": "An old load can't be saved with water. Send it back.",
}
var rank_i := 0
var bump := 0.0                # HUD counter bump after a gain
var _pops: Array = []          # {label, t, who, amount}

func setup(owner_game) -> void:
	game = owner_game
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bots="):
			bot_tier = clampi(["bronze", "silver", "gold"].find(a.substr(7)), 0, 2)
			_forced = true

func start_level() -> void:
	level = 0
	wallet_pour = {}
	by_role = {}
	log_rows = {}
	role_rows = {}
	costs = []

## Seconds of slack for each line fault the day had planned beyond the one
## the times above were tuned with (one clamp a pour). Trouble ramps up the
## tower (main._trouble_n: 1, 2, 3 then 4 faults a pour, some of them
## blockages), and each one stops the pump while someone climbs the riser:
## the crew shouldn't lose a medal to the floor they're on. (Measured 13 Nov
## on level 11, four faults: silver and gold bots took 188-226 s against a
## 125 s base, about 29 s for each fault past the first.)
const FAULT_T := {"clamp": 30.0, "block": 40.0}
const FAULTS_TUNED := 1

## The slack for a day's planned faults ([{kind}] from main._plan_incidents).
static func fault_slack(plan: Array) -> float:
	var ts: Array = []
	for inc in plan:
		ts.append(float(FAULT_T.get(String(inc.get("kind", "clamp")), FAULT_T["clamp"])))
	# (the cheapest ones are the ones already allowed for)
	ts.sort()
	var out := 0.0
	for i in range(FAULTS_TUNED, ts.size()):
		out += ts[i]
	return out

## [silver time, gold time] for this slab.
func targets(kit: String, k: int, people := 0, slack := 0.0) -> Vector2:
	return Vector2(float(SILVER_T.get(kit, 80.0)), float(GOLD_T.get(kit, 70.0))) + Vector2.ONE * (T_PER_LEVEL * k + T_PER_PERSON * people + slack)

## This slab's medal; moves the bots a step toward it when people are playing.
func finish_slab(kit: String, k: int, people: int, quality: float, pour_t: float, slack := 0.0) -> int:
	var t := targets(kit, k, people, slack)
	var m := 0
	if quality >= GOLD_Q and pour_t <= t.y:
		m = 2
	elif quality >= SILVER_Q and pour_t <= t.x:
		m = 1
	medals.append(m)
	if people > 0 and not _forced:
		bot_tier = clampi(bot_tier + signi(m - bot_tier), 0, 2)
	return m

func rank_name(i := -1) -> String:
	return RANKS[rank_i if i < 0 else i][1]

## Progress from this rank to the next, 0..1 (1 at the top).
func rank_frac() -> float:
	if rank_i >= RANKS.size() - 1:
		return 1.0
	var a: int = RANKS[rank_i][0]
	var b: int = RANKS[rank_i + 1][0]
	return clampf(float(total - a) / float(b - a), 0.0, 1.0)

func next_rank() -> String:
	return RANKS[rank_i + 1][1] if rank_i < RANKS.size() - 1 else ""

## The way to the next rank, in words for the slab report: how much more,
## and roughly how many slabs like this one ("" at the top).
func next_rank_line(per_slab: int) -> String:
	if rank_i >= RANKS.size() - 1:
		return ""
	var need: int = int(RANKS[rank_i + 1][0]) - total
	var slabs := ""
	if per_slab > 0:
		var n := int(ceil(float(need) / float(per_slab)))
		slabs = "  ·  about %d more slab%s like this" % [n, "" if n == 1 else "s"]
	return "Next rank: %s in $%s%s" % [next_rank(), _thou(maxi(0, need)), slabs]

static func _thou(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out

## Pay comes in real notes: under $150 a job pays the one note nearest its
## rate ($5, $10, $20, $50 or $100, judged on a log scale, so $35 is a $50
## and $25 a $20); more than that rounds to $50s and comes as a fan of notes.
const NOTE_VALUES := [5, 10, 20, 50, 100]

static func to_notes(dollars: int) -> int:
	var a := absi(dollars)
	if a == 0:
		return 0
	var r := 0
	if a < 150:
		r = 5
		for v: int in NOTE_VALUES:
			if absf(log(float(a) / float(v))) < absf(log(float(a) / float(r))):
				r = v
	else:
		r = int(roundf(float(a) / 50.0)) * 50
	return r * signi(dollars)

## Points for `who` (a crew chibi, or null for the whole crew), shown as a
## "+N" rising off them. `why` groups it on the slab report.
func award(who, pts: int, why: String, at := Vector3.INF) -> void:
	var base := why.split(" (")[0]
	pts = to_notes(int(roundf(float(pts) * float(RATE.get(base, 1.0)) * Wallet.CASH)))
	if pts == 0:
		return
	total = maxi(0, total + pts)
	level += pts
	var role: String = who.role if who != null else "crew"
	if pts < 0:
		costs.append({"why": base, "pts": pts, "role": role if who != null else String(COST_OWNER.get(base, "crew")),
			"t": float(game.pour_clock) if game != null and "pour_clock" in game else 0.0})
	by_role[role] = int(by_role.get(role, 0)) + pts
	log_rows[why] = int(log_rows.get(why, 0)) + pts
	var rr: Dictionary = role_rows.get(role, {})
	rr[why] = int(rr.get(why, 0)) + pts
	role_rows[role] = rr
	if who != null and not who.bot and not who.get("covering"):
		var key := "P%d" % who.index
		by_person[key] = int(by_person.get(key, 0)) + pts
		Wallet.pay(who.char_id, pts)
		wallet_pour[who.char_id] = int(wallet_pour.get(who.char_id, 0)) + pts
		if pts < 0 and game.has_method("slipped"):
			game.slipped(who, 0.06)
	elif who == null and game.crew != null:
		# Crew-wide money (the quality bonus, finishing early, a burst) is
		# shared out evenly between the people playing
		var people: Array = game.crew.humans()
		for q in people:
			var share := int(pts / people.size())
			Wallet.pay(q.char_id, share)
			wallet_pour[q.char_id] = int(wallet_pour.get(q.char_id, 0)) + share
	if pts > 0:
		bump = 1.0
	var where := at
	if where.x == INF and who != null:
		where = who.global_position + Vector3(0, 2.3, 0)
	if where.x != INF:
		_pop(who, pts, where)
	while rank_i < RANKS.size() - 1 and total >= RANKS[rank_i + 1][0]:
		rank_i += 1
		_rank_up()

## Continuous work (pouring, screeding) earns fractions that pop as whole points.
func trickle(who, amount: float, why: String, step := 10) -> void:
	who.pts_frac += amount
	if who.pts_frac >= step:
		var n := int(who.pts_frac / step) * step
		who.pts_frac -= n
		award(who, n, why)

func _rank_up() -> void:
	game.hud.rank_up(rank_name())
	game.sfx.hit("ding")
	game.sfx.hit("clang")
	if game.confetti:
		game.confetti.position = game.camera.global_position + game.camera.global_transform.basis.z * -14.0 + Vector3(0, 4, 0)
		game.confetti.amount = 160
		game.confetti.restart()
		game.confetti.emitting = true

## Money rising off the work: a banknote with the amount on it (or the
## amount in red when it's docked).
func _pop(who, pts: int, at: Vector3) -> void:
	# Quick gains off the same person stack onto one note
	for e in _pops:
		if e["who"] == who and who != null and e["t"] < 0.35 and signi(e["amount"]) == signi(pts):
			e["amount"] += pts
			e["t"] = minf(e["t"], 0.12)
			_dress(e)
			return
	var e: Dictionary = {}
	for old in _pops:
		if old["t"] >= 1.0:
			e = old
			_pops.erase(old)
			break
	if e.is_empty():
		var n := Node3D.new()
		game.add_child(n)
		var note := Node3D.new()   # (turned to face the camera; holds the note)
		n.add_child(note)
		var l: Label3D = F.label3d("", 40, POP)
		l.layers = 2
		l.outline_size = 10
		l.outline_modulate = Color(0.08, 0.06, 0.02, 1)
		l.no_depth_test = true
		l.render_priority = 25
		n.add_child(l)
		e = {"node": n, "note": note, "label": l, "shown": 0}
	e["t"] = 0.0
	e["who"] = who
	e["amount"] = pts
	e["base"] = at + Vector3(randf_range(-0.25, 0.25), 0, 0)
	(e["node"] as Node3D).position = e["base"]
	(e["node"] as Node3D).visible = true
	_dress(e)
	_pops.append(e)

## Pay is the real notes that make it up, fanned out (cash_art.gd); money
## docked is the amount in red.
func _dress(e: Dictionary) -> void:
	var v: int = e["amount"]
	var l: Label3D = e["label"]
	l.text = Wallet.money(v)
	l.modulate = LOSS
	l.visible = v <= 0
	var note: Node3D = e["note"]
	note.visible = v > 0
	if v > 0 and int(e["shown"]) != v:
		e["shown"] = v
		for c in note.get_children():
			c.queue_free()
		var b := CashArt.bill(v)
		b.scale = Vector3.ONE * 5.0
		for c in b.find_children("*", "Label3D", true, false):
			(c as Label3D).render_priority = 25
		note.add_child(b)

func update(delta: float) -> void:
	bump = maxf(0.0, bump - delta * 3.0)
	var cam: Camera3D = game.camera
	for e in _pops:
		e["t"] += delta
		var t: float = e["t"]
		var n: Node3D = e["node"]
		if t >= 1.0:
			n.visible = false
			continue
		var base: Vector3 = e["base"]
		if e["who"] != null:
			base = (e["who"] as Node3D).global_position + Vector3(0, 2.3, 0)
		n.position = base + Vector3(0, 0.4 + 1.3 * ease(t, 0.5), 0)
		var vc: Camera3D = game.view_cam(n.global_position) if game.has_method("view_cam") else cam
		var k := clampf(vc.global_position.distance_to(n.global_position) / 15.0, 0.8 if vc == cam else 0.5, 2.6)
		var pop := 1.0 + 0.5 * sin(clampf(t * 7.0, 0.0, PI))
		n.scale = Vector3.ONE * k * pop * 0.55
		var a := clampf((1.0 - t) * 3.0, 0.0, 1.0)
		(e["label"] as Label3D).modulate.a = a
		# the note faces the camera, and folds away as it fades
		var note: Node3D = e["note"]
		note.scale = Vector3.ONE * maxf(0.01, a)
		if n.global_position.distance_to(cam.global_position) > 0.1:
			note.look_at(cam.global_position, Vector3.UP, true)

## The slab report's points section.
func report_rows() -> Array:
	var rows: Array = []
	var keys := log_rows.keys()
	keys.sort_custom(func(a, b): return absi(log_rows[a]) > absi(log_rows[b]))
	for k in keys:
		var v: int = log_rows[k]
		rows.append("%s   %s%d" % [k, "+" if v > 0 else "", v])
	return rows

## The slab's biggest costs, worst first: [{why, pts, n, role, t (first time),
## hint}], grouped by what happened.
func worst(n := 3) -> Array:
	var by := {}
	for c in costs:
		var key: String = c["why"]
		if not by.has(key):
			by[key] = {"why": key, "pts": 0, "n": 0, "role": c["role"], "t": c["t"], "hint": String(COST_HINT.get(key, ""))}
		by[key]["pts"] += int(c["pts"])
		by[key]["n"] += 1
	var out: Array = by.values()
	out.sort_custom(func(a, b): return int(a["pts"]) < int(b["pts"]))
	return out.slice(0, n)

## What cost this job the most this slab ("" if nothing did).
func worst_reason(role: String) -> String:
	var rr: Dictionary = role_rows.get(role, {})
	var w := ""
	var wv := 0
	for k in rr:
		if int(rr[k]) < wv:
			wv = int(rr[k])
			w = k
	return w

## What earned this job the most this slab ("" if nothing).
func top_reason(role: String) -> String:
	var rr: Dictionary = role_rows.get(role, {})
	var best := ""
	var best_v := 0
	for k in rr:
		if int(rr[k]) > best_v:
			best_v = int(rr[k])
			best = k
	return best

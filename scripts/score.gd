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
	"Screeding": 0.35, "Poker": 0.9, "Concrete placed": 0.9, "On the end hose": 1.2,
	"Spikes killed": 3.0, "Clamp swapped before it burst": 2.0, "Line repairs": 2.0,
	"Blockage found by tap test": 2.0, "Safety pins in": 1.5, "Pump restarted": 1.0,
	"Good loads in": 2.0, "Bad loads turned away": 3.0, "Slump tests": 1.5,
	"Trucks spotted in": 2.0, "Tight changeovers": 2.0, "Called it on the dot": 2.0,
	"Good call on the output": 1.5, "Sections landed": 2.0, "Tag line": 2.0, "R-clips on": 1.5,
}

## The crew's ladder, in dollars banked over the chapter. A bronze crew
## takes about $30,000 a slab, so top-out is around Site Super; Legend
## takes a crew that pours better than the bots.
const RANKS := [
	[0, "Labourer"],
	[25000, "Apprentice"],
	[70000, "Concreter"],
	[130000, "Leading Hand"],
	[200000, "Foreman"],
	[290000, "Site Super"],
	[400000, "Concrete Legend"],
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
const MEDAL_COLORS := [Color("d0884a"), Color("d6dde6"), Color("ffd23f")]
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

## [silver time, gold time] for this slab.
func targets(kit: String, k: int, people := 0) -> Vector2:
	return Vector2(float(SILVER_T.get(kit, 80.0)), float(GOLD_T.get(kit, 70.0))) + Vector2.ONE * (T_PER_LEVEL * k + T_PER_PERSON * people)

## This slab's medal; moves the bots a step toward it when people are playing.
func finish_slab(kit: String, k: int, people: int, quality: float, pour_t: float) -> int:
	var t := targets(kit, k, people)
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

## Points for `who` (a crew chibi, or null for the whole crew), shown as a
## "+N" rising off them. `why` groups it on the slab report.
func award(who, pts: int, why: String, at := Vector3.INF) -> void:
	var base := why.split(" (")[0]
	pts = int(roundf(float(pts) * float(RATE.get(base, 1.0)) * Wallet.CASH))
	if pts == 0:
		return
	total = maxi(0, total + pts)
	level += pts
	var role: String = who.role if who != null else "crew"
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

## Pay is a Site Cash note (cash_art.gd) with the amount printed on it;
## money docked is the amount in red.
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
		var k := clampf(cam.global_position.distance_to(n.global_position) / 15.0, 0.8, 2.6)
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

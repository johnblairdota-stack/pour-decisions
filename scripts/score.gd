## Points. Every bit of real work earns them, the moment it's done: a small
## "+N" pops up off whoever did it, rises and fades. There's no ceiling, just a
## ladder of ranks to climb, from Labourer up to Concrete Legend.
extends Node

const F := preload("res://scripts/factory.gd")

const RANKS := [
	[0, "Labourer"],
	[2000, "Apprentice"],
	[5000, "Concreter"],
	[9500, "Leading Hand"],
	[14000, "Foreman"],
	[19500, "Site Super"],
	[26000, "Concrete Legend"],
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
const SILVER_T := {"tower": 86.0, "truck": 110.0, "tutorial": 60.0}
const GOLD_T := {"tower": 77.0, "truck": 99.0, "tutorial": 52.0}
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
var by_person := {}            # "P1" etc -> points over the chapter
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

func _pop(who, pts: int, at: Vector3) -> void:
	# Quick gains off the same person stack into one counter
	for e in _pops:
		if e["who"] == who and who != null and e["t"] < 0.35 and signi(e["amount"]) == signi(pts):
			e["amount"] += pts
			e["t"] = minf(e["t"], 0.12)
			(e["label"] as Label3D).text = ("+%d" if e["amount"] > 0 else "%d") % e["amount"]
			return
	var l: Label3D = null
	for e in _pops:
		if e["t"] >= 1.0:
			l = e["label"]
			_pops.erase(e)
			break
	if l == null:
		l = F.label3d("", 40, POP)
		l.layers = 2
		l.outline_size = 10
		l.outline_modulate = Color(0.08, 0.06, 0.02, 1)
		l.no_depth_test = true
		l.render_priority = 25
		game.add_child(l)
	l.text = ("+%d" if pts > 0 else "%d") % pts
	l.modulate = POP if pts > 0 else LOSS
	l.position = at + Vector3(randf_range(-0.25, 0.25), 0, 0)
	l.visible = true
	_pops.append({"label": l, "t": 0.0, "who": who, "amount": pts, "base": l.position})

func update(delta: float) -> void:
	bump = maxf(0.0, bump - delta * 3.0)
	var cam: Camera3D = game.camera
	for e in _pops:
		e["t"] += delta
		var t: float = e["t"]
		var l: Label3D = e["label"]
		if t >= 1.0:
			l.visible = false
			continue
		var base: Vector3 = e["base"]
		if e["who"] != null:
			base = (e["who"] as Node3D).global_position + Vector3(0, 2.3, 0)
		l.position = base + Vector3(0, 0.4 + 1.3 * ease(t, 0.5), 0)
		var vc: Camera3D = game.view_cam(l.global_position) if game.has_method("view_cam") else cam
		var k := clampf(vc.global_position.distance_to(l.global_position) / 15.0, 0.8 if vc == cam else 0.5, 2.6)
		var pop := 1.0 + 0.5 * sin(clampf(t * 7.0, 0.0, PI))
		l.scale = Vector3.ONE * k * pop * 0.55
		l.modulate.a = clampf((1.0 - t) * 3.0, 0.0, 1.0)

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

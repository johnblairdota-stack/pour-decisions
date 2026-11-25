## The crews change over (the real site trades plan, stage 4, board section
## 11). Before a climb day the concreters knock off and the riggers' ute and
## the crane crew pull in, so the people playing take a climb-day seat:
## riggers, doggers, the crane cab (Spire's column climb) and the one pumpy
## who parks the boom. Each card is a trade, each seat is a hat with a P tag
## or a bot's name on it.
##
## Seats are the crew's chibis (trades.gd CLIMB_SEAT: who each chibi is on
## this kind of climb), plus the crane cab, which isn't a chibi: the person
## who takes it leaves their chibi to a trade-mate bot (mast_climb.take_cab).
## Left / right steps to the next free seat, A locks in, B changes. When
## everyone's in (or the clock runs out) it's done, and after the climb
## main.gd puts everyone back on their pour-day hats (restore()).
##
## The site stops while it's up: main.gd's "changeover" phase skips walking
## and the jobs and hands each person's buttons here (handle()).
extends CanvasLayer

const UI := preload("res://scripts/ui.gd")
const Trades := preload("res://scripts/trades.gd")

signal done(cab)

const AUTO_T := 25.0          # s until it goes with the seats as they are
const READY_T := 0.9          # s after the last person locks in
const BOT_T := 1.2            # s it stays up in a test run with nobody choosing

var game
var kind := "spire"           # trades.gd CLIMB_SEAT key: spire, erect, lattice
var seats: Array = []         # {trade, label, role ("cab" for the crane cab, "" for none)}
var cab = null                # the person who's taken the cab
var _ready_p := {}            # person index -> locked in
var _cool := {}
var _t := 0.0
var _ready_t := 0.0
var _finished := false
var _seat_ui: Array = []      # per seat: {hat, ptag, who, box}
var _root: Control
var _box: Control
var _clock: Label
var _status: Label

## Whether a climb day of this game gets the change-over page: a person's
## playing (bots just get on with it) and it isn't the water tower's lesson,
## where the coach walks them through the day.
static func wanted(g) -> bool:
	if g.tutorial or g.crew.humans().is_empty():
		return false
	return not OS.get_cmdline_user_args().has("--nochangeover")

## Who's on which pour-day job now: {person index: role}.
static func seats_now(crew) -> Dictionary:
	var out := {}
	for p in crew.humans():
		out[p.index] = p.role
	return out

## Back on the pour-day hats after the climb (each person to the job they had,
## where a bot's on it now; a few passes, so two people can swap back).
static func restore(crew, was: Dictionary) -> void:
	for _pass in 3:
		var moved := false
		for i in was:
			var p = crew.human(int(i))
			if p == null or p.role == String(was[i]):
				continue
			if crew.crew[String(was[i])].bot and crew.assign(int(i), String(was[i])):
				moved = true
		if not moved:
			break

func setup(g, climb_kind: String) -> void:
	game = g
	kind = climb_kind
	layer = 18
	_build_seats()
	_build()
	if game.autotest:
		print("[autotest]   the crews change over (%s): %s" % [kind, ", ".join(seats.map(func(s): return "%s %s" % [s["trade"], s["label"]]))])

## The seats on this kind of climb, a trade at a time in the climb's pick
## order (riggers, doggers, the crane op, the pumpy), then anyone left over.
func _build_seats() -> void:
	seats = []
	var map: Dictionary = Trades.CLIMB_SEAT.get(kind, {})
	var order: Array = Trades.CLIMB_TRADES.duplicate()
	order.append("")
	for tr in order:
		for role in ["boom", "hose", "pump", "poker", "screed", "line"]:
			var s: Array = map.get(role, ["", role])
			if String(s[0]) == tr:
				seats.append({"trade": tr, "label": String(s[1]), "role": role})
		if tr == "crane":
			# (the cab's a seat on Spire's column climb; on the others the crane's own driver works it)
			seats.append({"trade": "crane", "label": "Cab", "role": "cab" if _cab_open() else ""})

func _cab_open() -> bool:
	return kind == "spire" and game.mast != null and game.mast.has_method("take_cab")

## The seat a person's on.
func seat_of(p) -> int:
	for i in seats.size():
		var r: String = seats[i]["role"]
		if (r == "cab" and cab == p) or (r == p.role and cab != p):
			return i
	return -1

## Whether person `p` could sit in seat `i`.
func _free(i: int, p) -> bool:
	var r: String = seats[i]["role"]
	if r == "":
		return false
	if r == "cab":
		return cab == null or cab == p
	var q = game.crew.crew[r]
	return q.bot or q == p

## Person `p` steps along to the next free seat (dir +1/-1).
func step(p, dir: int) -> void:
	var at := seat_of(p)
	var n := seats.size()
	for k in range(1, n):
		var i := (at + dir * k + n * 2) % n
		if _free(i, p):
			_sit(p, i)
			return

func _sit(p, i: int) -> void:
	var r: String = seats[i]["role"]
	if r == "cab":
		cab = p
	else:
		if cab == p:
			cab = null
		if p.role != r:
			game.crew.assign(p.index, r)
	game.sfx.hit("tink")

## A person's buttons while it's up (main.gd's player loop calls it, before
## their end_frame, so a phone's or a test's presses land once).
func handle(p, delta: float) -> void:
	if p.bot or _finished:
		return
	var i: int = p.index
	_cool[i] = maxf(0.0, float(_cool.get(i, 0.0)) - delta)
	var locked: bool = _ready_p.get(i, false)
	var v: Vector2 = p.move_input()
	if not locked and _cool[i] <= 0.0 and absf(v.x) > 0.5:
		step(p, int(signf(v.x)))
		_cool[i] = 0.22
	if p.action_pressed() and not locked:
		_ready_p[i] = true
		game.sfx.hit("ding")
	elif p.leave_pressed() and locked:
		_ready_p[i] = false
		game.sfx.hit("tink")

func _process(delta: float) -> void:
	if _finished or game == null:
		return
	_t += delta
	var people: Array = game.crew.humans()
	if game.autotest:
		_test_picks(people)

	var all := not people.is_empty()
	for p in people:
		all = all and bool(_ready_p.get(p.index, false))
	_ready_t = (_ready_t + delta) if all else 0.0
	if _ready_t >= READY_T or _t >= AUTO_T:
		_finish()
		return
	_refresh(people, all)
	_fit()

## Test runs: `--changeover=cab` (or a seat's role key) sits P1 there, then
## everyone locks in.
func _test_picks(people: Array) -> void:
	if _t < (2.5 if String(game.shot_dir) != "" else BOT_T) or people.is_empty():
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--changeover=") and not _ready_p.has(-1):
			_ready_p[-1] = true
			var want := a.substr(13)
			for i in seats.size():
				if String(seats[i]["role"]) == want and _free(i, people[0]):
					_sit(people[0], i)
	for p in people:
		_ready_p[p.index] = true

func _finish() -> void:
	_finished = true
	if game.autotest:
		var who: Array = []
		for p in game.crew.humans():
			var s := seat_of(p)
			who.append("P%d %s" % [p.index, (Trades.trade_name(seats[s]["trade"]) + " " + String(seats[s]["label"])) if s >= 0 else p.role])
		print("[autotest]   crews changed over in %.1fs: %s" % [_t, ", ".join(who)])
	game.hud.toast("Climb day crew's on. Back on your pour hats after the climb.", 2.4)
	done.emit(cab)

# ------------------------------------------------------------------ the page

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.62)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_root.add_child(v)
	_box = v
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 16)
	v.add_child(th)
	var hat := UI.Hat.new()
	hat.color = Trades.COL["rigger"]
	hat.custom_minimum_size = Vector2(84, 70)
	th.add_child(hat)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -4)
	th.add_child(tv)
	tv.add_child(UI.head("Climb day · the crews change over", 52, UI.BONE, 6))
	var sub := UI.label("The concreters knock off. The riggers' ute and the crane crew pull in. Take a seat for the climb: you're back on your pour hat after it.", 26, Color("d4d1c8"), 4)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(1100, 0)
	tv.add_child(sub)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 18)
	v.add_child(cards)
	var row: HBoxContainer = null
	var at := "?"
	for i in seats.size():
		var s: Dictionary = seats[i]
		if s["trade"] != at:
			at = s["trade"]
			row = _card(cards, at)
		_seat_ui.append(_seat(row, s))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 22)
	v.add_child(bar)
	var keys := UI.label("◀ ▶  next free seat     A  lock in     B  change", 26, UI.BONE, 4)
	bar.add_child(keys)
	_status = UI.label("", 26, Color("d4d1c8"), 4)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_status)
	_clock = UI.head("", 34, UI.GOLD, 4)
	bar.add_child(_clock)

func _card(parent: Control, trade: String) -> HBoxContainer:
	var col: Color = Trades.COL.get(trade, UI.DIM)
	var card := UI.panel(UI.CARD, 16, col, 3, Vector4(14, 10, 14, 12))
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var band := UI.panel(col, 10, Color(0, 0, 0, 0), 0, Vector4(12, 2, 12, 2))
	v.add_child(band)
	var nm := Trades.trade_name(trade) if trade != "" else "Spare hand"
	band.add_child(UI.head(nm.to_upper(), 30, Color("1b1308")))
	var line := String((Trades.TRADES.get(trade, {}) as Dictionary).get("line", "Rests this climb, ready to swap in."))
	if trade == "pumpy":
		line = "Parks the boom, then the mobilisation check."
	var ln := UI.label(line, 20, Color("c9c6bd"), 0)
	ln.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ln.custom_minimum_size = Vector2(180, 0)
	v.add_child(ln)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	return row

func _seat(row: HBoxContainer, s: Dictionary) -> Dictionary:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.custom_minimum_size = Vector2(170, 0)
	row.add_child(col)
	var hat := UI.Hat.new()
	hat.color = Trades.COL.get(s["trade"], UI.DIM)
	hat.custom_minimum_size = Vector2(96, 80)
	hat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(hat)
	var sn := UI.head(String(s["label"]).to_upper(), 24, UI.BONE)
	sn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sn.custom_minimum_size = Vector2(170, 0)
	col.add_child(sn)
	var tag := UI.pill(UI.TRACK, Vector4(5, 4, 12, 4))
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(tag)
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 6)
	tag.add_child(tr)
	var ptag := UI.ptag(1, 22)
	tr.add_child(ptag)
	var who := UI.label("", 22, UI.BONE, 0)
	who.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tr.add_child(who)
	return {"hat": hat, "ptag": ptag, "who": who}

func _refresh(people: Array, all: bool) -> void:
	for i in seats.size():
		var s: Dictionary = seats[i]
		var e: Dictionary = _seat_ui[i]
		var hat: UI.Hat = e["hat"]
		var ptag: PanelContainer = e["ptag"]
		var who: Label = e["who"]
		var r: String = s["role"]
		var p = null
		if r == "cab":
			p = cab
		elif r != "":
			var q = game.crew.crew[r]
			p = null if q.bot or q == cab else q
		if p != null:
			var locked: bool = _ready_p.get(p.index, false)
			hat.dim = false
			hat.check = locked
			hat.pivot_offset = Vector2(hat.size.x * 0.5, 0)
			hat.rotation = 0.0 if locked else 0.06 * sin(_t * 5.0)
			UI.style(ptag).bg_color = p.tag_color
			(ptag.get_child(0) as Label).text = "P%d" % p.index
			who.text = p.char_name + ("" if locked else "…")
		else:
			hat.dim = true
			hat.check = false
			hat.rotation = 0.0
			UI.style(ptag).bg_color = Color("5d606b")
			(ptag.get_child(0) as Label).text = "bot"
			if r == "cab" or r == "":
				who.text = "crane's driver" if s["trade"] == "crane" else "bot"
			else:
				who.text = game.crew.crew[r].char_name
	var choosing: Array = []
	for p in people:
		if not bool(_ready_p.get(p.index, false)):
			choosing.append("P%d" % p.index)
	_status.text = "Everyone's in." if all else ("Still choosing: " + ", ".join(choosing))
	_clock.text = str(int(ceil(maxf(AUTO_T - _t, 0.0))))

## Centred, shrunk to fit the screen (big screen text included).
func _fit() -> void:
	var vs: Vector2 = _root.size
	var sz: Vector2 = _box.get_combined_minimum_size()
	var k := minf(1.0, minf((vs.x - 64.0) / sz.x, (vs.y - 64.0) / sz.y))
	_box.size = sz
	_box.scale = Vector2(k, k)
	_box.position = (vs - sz * k) * 0.5

## The smoko run on climb days. The screeder's got nothing to screed while
## the boom climbs, so they do the coffee run: everyone picks an order on
## their phone (or keeps their usual), the screeder walks down to the coffee
## van at the Angora Rd gate, buys the lot (each order comes out of its
## owner's wallet), rides the tray back up the hoist and hands each order to
## whoever ordered it. Every order in hands before the boom's seated and
## each person gets their money back with a tip, and the crew carries on a
## bit quicker for a while. Late, and the orders that didn't land are just
## gone. Bots pick orders too, and a bot screeder does the run.
extends Node3D

const F := preload("res://scripts/factory.gd")
const Smoko := preload("res://scripts/smoko_art.gd")
const Wallet := preload("res://scripts/wallet.gd")

const MENU := [
	{"id": "flat", "name": "Flat white", "price": 5, "prop": "CoffeeCup"},
	{"id": "iced", "name": "Iced coffee", "price": 6, "prop": "CoffeeCup"},
	{"id": "roll", "name": "Sausage roll", "price": 5, "prop": "SausageRoll"},
	{"id": "pie", "name": "Pie", "price": 6, "prop": "Pie"},
]
## The van at the Angora Rd gate, hatch to the site; the screeder buys at VAN_STAND
const VAN_POS := Vector3(31.0, 0, 14.6)
const VAN_STAND := Vector3(31.0, 0, 12.1)
const BUY_T := 1.8          # s of A at the hatch to buy the lot
const BUY_R := 1.5          # m from the stand
const HAND_R := 1.6         # m: close enough to hand an order over
const HAND_PAY := 3
const TIP := 3              # dollars on top of the money back, each
const BOOST_T := 45.0       # s the crew's quicker after a good smoko
const BOOST_K := 1.12

var game
var climb
var van: Node3D
var tray: Node3D
var stage := ""             # "" none, "run" to the van, "back" handing out, "done"
var orders := {}            # player -> menu id
var paid := {}              # player -> dollars out of their wallet
var owed: Array = []        # players still waiting on their order
var runner = null
var _buy := 0.0
var boost_t := 0.0
var _eat: Array = []        # [food node, seconds left] in people's hands
var _hint_t := 0.0
var _t := 0.0               # s since the climb started (for the test log)

func setup(owner_climb) -> void:
	climb = owner_climb
	game = climb.game
	van = Smoko.van()
	van.position = VAN_POS
	van.rotation.y = PI * 0.5   # front up Angora Rd, the hatch to the site
	van.visible = false
	add_child(van)

func item(id: String) -> Dictionary:
	for m in MENU:
		if m["id"] == id:
			return m
	return MENU[0]

## A climb's starting: fresh orders (people keep what they had last time).
func begin() -> void:
	var was := orders
	orders = {}
	paid = {}
	owed = []
	_buy = 0.0
	_drop_tray()
	for p in game.players:
		if was.has(p):
			orders[p] = was[p]
		else:
			orders[p] = MENU[randi() % MENU.size()]["id"]
	stage = "run"
	_t = 0.0
	van.visible = true

## A phone's pick (before the tray's bought; after that it's in the bag).
func pick(p, id: String) -> bool:
	if stage != "run" or p == null:
		return false
	for m in MENU:
		if m["id"] == id:
			orders[p] = id
			return true
	return false

## For the phones: the menu, their pick, and how the run's going.
func phone_state(p) -> Dictionary:
	var on: bool = climb.active and stage in ["run", "back"]
	var st := "picking" if stage == "run" else ("coming" if p in owed else "got it")
	var menu := []
	for m in MENU:
		menu.append([m["id"], m["name"], m["price"]])
	return {"t": "smoko", "on": on, "menu": menu, "pick": String(orders.get(p, "")), "st": st, "lock": stage != "run"}

func speed_k() -> float:
	return BOOST_K if boost_t > 0.0 else 1.0

## The screeder on the run. True while it's taken their input.
func handle(p, delta: float) -> bool:
	if not climb.active or p != runner:
		return false
	match stage:
		"run":
			if p.zone != "ground":
				return false
			var d := Vector2(p.position.x - VAN_STAND.x, p.position.z - VAN_STAND.z).length()
			if d > BUY_R:
				return false
			p.face(Vector3(VAN_POS.x, p.position.y, VAN_POS.z))
			p.cue("action", "hold: buy smoko (%s)" % Wallet.money(_total()), _buy / BUY_T, true)
			p.gold(not p.bot)
			if not p.action_held():
				_buy = maxf(0.0, _buy - delta)
				return true
			_buy += delta
			p.set_arms(-1.2, -0.4)
			if _buy >= BUY_T:
				_bought(p)
			return true
		"back":
			if p.zone != "deck" and p.zone != "ground":
				return false
			var q = _nearest_owed(p)
			if q == null:
				return false
			var m := item(orders[q])
			p.cue("action", "give %s the %s" % [q.char_name, String(m["name"]).to_lower()], -1.0, true)
			p.gold(not p.bot)
			if p.action_pressed():
				_hand(p, q)
			return true
	return false

func _total() -> int:
	var t := 0
	for q in orders:
		t += int(item(orders[q])["price"])
	return t

func _bought(p) -> void:
	_buy = 0.0
	# Everyone's order out of their own wallet
	for q in orders:
		if not is_instance_valid(q):
			continue
		var price := int(item(orders[q])["price"])
		paid[q] = price
		Wallet.pay(q.char_id, -price)
		owed.append(q)
	stage = "back"
	tray = Smoko.tray(0)
	var cups := 0
	for q in owed:
		if item(orders[q])["prop"] == "CoffeeCup" and cups < Smoko.SLOTS.size():
			var c := Smoko.food("CoffeeCup")
			c.position = Smoko.SLOTS[cups]
			tray.add_child(c)
			cups += 1
	tray.scale = Vector3.ONE * 2.2   # (it's a 0.23 m tray: big enough to read on the TV)
	p.hand_r.add_child(tray)
	tray.position = Vector3(0, 0.05, -0.2)
	game.sfx.hit("ding")
	game.pop("Smoko's bought", VAN_STAND + Vector3(0, 2.4, 0), Color("ffc72c"))
	if game.autotest:
		print("[autotest]   smoko bought at %.1fs of the climb (%d orders, $%d)" % [_t, owed.size(), _total()])

func _nearest_owed(p):
	var best = null
	var bd := HAND_R
	for q in owed:
		if not is_instance_valid(q) or q == p:
			continue
		if q.zone != p.zone:
			continue
		var d := _reach(p, q)
		if d < bd:
			bd = d
			best = q
	return best

## Across the deck to them (the rigger's up on the frame's platform: still
## near enough to pass a coffee up)
func _reach(p, q) -> float:
	if absf(p.position.y - q.position.y) > 5.0:
		return INF
	return Vector2(p.position.x - q.position.x, p.position.z - q.position.z).length()

func _hand(p, q) -> void:
	owed.erase(q)
	var m := item(orders[q])
	var f := Smoko.food(m["prop"])
	f.scale = Vector3.ONE * 2.2
	q.hand_r.add_child(f)
	f.position = Vector3(0, 0.06, -0.12)
	_eat.append([f, 8.0])
	q.bounce()
	game.sfx.hit("tink")
	game.pop("%s: %s" % [q.char_name, m["name"]], q.global_position + Vector3(0, 2.4, 0), Color("7cd992"))
	game.score.award(p, HAND_PAY, "Smoko run")
	# The runner's own order comes off the tray last, once everyone else has theirs
	if owed.size() == 1 and owed[0] == p:
		owed.clear()
		var mine := Smoko.food(item(orders[p])["prop"])
		mine.scale = Vector3.ONE * 2.2
		_eat.append([mine, 8.0])
		p.hand_l.add_child(mine)
	if owed.is_empty():
		_all_landed()

func _all_landed() -> void:
	stage = "done"
	_drop_tray()
	for q in paid:
		if is_instance_valid(q):
			Wallet.pay(q.char_id, int(paid[q]) + TIP)
	boost_t = BOOST_T
	game.hud.toast("Smoko's landed: everyone's money back plus a tip", 2.4)
	game.sfx.hit("ding")
	if game.autotest:
		print("[autotest]   smoko all handed out at %.1fs of the climb" % _t)

## The boom's seated: whatever's not landed by now is gone.
func end_climb() -> void:
	if stage in ["run", "back"]:
		if stage == "back" and not owed.is_empty():
			game.hud.toast("Smoko's late: %d order%s went cold" % [owed.size(), "" if owed.size() == 1 else "s"], 2.4)
		if game.autotest:
			print("[autotest]   smoko not finished at the climb's end (%s, %d owed)" % [stage, owed.size()])
	stage = ""
	owed = []
	_drop_tray()
	van.visible = false

func _drop_tray() -> void:
	if tray != null and is_instance_valid(tray):
		tray.queue_free()
	tray = null

func update(delta: float) -> void:
	boost_t = maxf(0.0, boost_t - delta)
	_t += delta
	for e in _eat.duplicate():
		e[1] -= delta
		if e[1] <= 0.0 or not is_instance_valid(e[0]):
			if is_instance_valid(e[0]):
				e[0].queue_free()
			_eat.erase(e)
	if not climb.active or stage == "" or stage == "done":
		return
	runner = game.crew.crew.get("screed")
	if runner == null:
		return
	# Who's waiting on what: their order over their head while the tray's about
	if stage == "back" and runner.zone == "deck":
		for q in owed:
			if is_instance_valid(q) and q != runner:
				q.say("%s?" % String(item(orders[q])["name"]).to_lower())
	if not runner.bot:
		_hint_t -= delta
		if _hint_t <= 0.0 and stage == "run" and runner.zone == "deck":
			_hint_t = 6.0
			runner.say("smoko run: coffee van at the gate")

## Where the van stand is, for the station marker.
func stand() -> Vector3:
	return VAN_STAND

## A bot screeder's run: down the ladder, along to the van, buy, back up the
## hoist, then round the crew. True while the run's got them.
func bot_step(p, bots) -> bool:
	if not climb.active or p != runner:
		return false
	match stage:
		"run":
			if bots.go(p, "ground", VAN_STAND, 0.6):
				p.ai_action = true
			return true
		"back":
			if p.zone != "deck" and p.zone != "ground":
				return true
			var best = null
			var bd := INF
			for q in owed:
				if is_instance_valid(q) and q != p and q.zone == p.zone:
					var d := _reach(p, q)
					if d < bd:
						bd = d
						best = q
			if best == null:
				# Nobody left down here: back up in the cage with the tray
				if p.zone == "ground":
					if bots.walk(p, bots._gnd("hoist_g"), 0.5):
						p.ai_action = bots._tap()
					return true
				return false
			# (only press A once they're in reach: a press anywhere else would
			# take whatever station's there, like the rigger's)
			if bots.walk(p, Vector3(best.position.x, p.position.y, best.position.z), HAND_R * 0.6) or _nearest_owed(p) == best:
				p.ai_action = _nearest_owed(p) == best and bots._tap()
			return true
	return false

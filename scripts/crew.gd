## The crew: one chibi per job. Each person takes a job, and bots work every
## job nobody has taken, through the same buttons a person presses. Bots go
## for the work flagged with a hand sign, and run when it turns red.
##
## Climb days use the same crew: the boom operator is the dogman, the line hand
## rigs and pins the tower, and the poker hand holds the tag line.
extends Node

const PlayerScript := preload("res://scripts/player.gd")
const Roster := preload("res://scripts/roster.gd")
const CHARACTERS := Roster.CHARACTERS
const DEFAULT_CHAR := Roster.DEFAULT_CHAR

const ROLES := ["boom", "line", "pump", "poker", "screed", "hose"]
const JOIN_ORDER := ["boom", "hose", "poker", "line", "pump", "screed"]
const PLAYER_COLORS := [Color("4fa3ff"), Color("7cd992"), Color("ff7ad9"), Color("c49bff")]
const INFO := {
	"boom": {"name": "Boom operator", "hat": Color("ffc72c"), "climb": "dogman",
		"text": "Steer the placing boom from the radio remote and pump the concrete where it's needed, bay by bay. Keep an eye on the hopper.\n\nClimb days: dogman, whistling the crane in."},
	"line": {"name": "Line hand", "hat": Color("7cd992"), "climb": "rigger",
		"text": "Keep the riser sound. Swap a weeping clamp before it bursts, remake a burst joint, tap-test and replace a blocked pipe.\n\nClimb days: rigger, pinning the new sections."},
	"pump": {"name": "Pump operator", "hat": Color("ff7a1a"), "climb": "",
		"text": "Run the truck bay and the pump. Wave trucks in, slump-test every load, add water or reject it, drop the pressure for the line hand, and run parts when the line's down."},
	"poker": {"name": "Poker hand", "hat": Color("c49bff"), "climb": "tag line",
		"text": "Vibrate the concrete as it lands: plunge, feel it shudder, lift out when the bubbles stop, move on. Tow your drive unit along.\n\nClimb days: the tag line."},
	"hose": {"name": "Pipe guy", "hat": Color("2fd3e8"), "climb": "",
		"text": "On the end of the rubber hose: walk it where the concrete's wanted, right into the corners the boom can't quite reach, and call the pump on and off. On the radio for the start-up: the dragon's breathing, slurry out, concrete's on."},
	"screed": {"name": "Screeder", "hat": Color("f4f7fa"), "climb": "",
		"text": "Follow the pokers with the screed board. Saw it side to side to strike the slab flat, rolling the surplus into the low spots, before it goes off.\n\nInspections: fix the defects."},
}

var game
var crew := {}                 # role -> chibi

## Characters nobody's playing yet (people or bots), in roster order.
func free_chars(except = null) -> Array:
	var used := {}
	for role in crew:
		if crew[role] != except:
			used[crew[role].char_id] = true
	var out: Array = []
	for c in CHARACTERS:
		if not used.has(c["id"]):
			out.append(c["id"])
	return out

func build(owner_game) -> void:
	game = owner_game
	for role in ROLES:
		var p := PlayerScript.new()
		game.add_child(p)
		p.setup(0, INFO[role]["hat"])
		p.role = role
		crew[role] = p
		var d := bot_identity()
		d["char"] = DEFAULT_CHAR[role]
		p.set_driver(d)
		game.players.append(p)
	place_start()

func place_start() -> void:
	var wy: float = game.work_y
	for role in ROLES:
		var p = crew[role]
		match role:
			"boom": p.position = Vector3(5.0, wy, -2.5)
			"poker": p.position = Vector3(2.0, wy, 3.2)
			"screed": p.position = Vector3(-4.0, wy, 3.2)
			"hose": p.position = Vector3(3.0, wy, -1.0)
			"line":
				p.zone = "ground"
				p.position = Vector3(14.6, 0, 3.4)
			"pump":
				p.zone = "ground"
				p.position = Vector3(19.4, 0, 9.2)

## A bot driver. `keep` is the character it takes over as (a person leaving a
## job leaves their character with them, so the bot picks up a free one).
func bot_identity(keep := "") -> Dictionary:
	var ch := keep
	if ch == "":
		var free := free_chars()
		ch = free[0] if not free.is_empty() else CHARACTERS[0]["id"]
	return {"index": 0, "prefix": "p0_", "color": Color.WHITE, "ai": true, "bot": true, "remote_id": -1, "touched": false, "char": ch}

static func human_identity(i: int, remote: bool, ch := "") -> Dictionary:
	return {"index": i, "prefix": "p%d_" % i, "color": PLAYER_COLORS[i - 1], "ai": remote, "bot": false, "remote_id": 1 if remote else -1, "touched": false, "char": ch}

## Person `i` steps to the next character along (dir +1/-1). If a bot is
## playing that character, the bot takes the person's old one.
func cycle_char(i: int, dir: int) -> void:
	var p = human(i)
	if p == null:
		return
	var ids: Array = []
	for c in CHARACTERS:
		ids.append(c["id"])
	var at := ids.find(p.char_id)
	for k in range(1, ids.size()):
		var want: String = ids[(at + dir * k + ids.size() * 2) % ids.size()]
		var holder = null
		for role in ROLES:
			if crew[role].char_id == want:
				holder = crew[role]
		if holder != null and not holder.bot:
			continue   # another person's playing them
		if holder != null:
			holder.set_char(p.char_id)
		p.set_char(want)
		return

func humans() -> Array:
	var out: Array = []
	for role in ROLES:
		if not crew[role].bot:
			out.append(crew[role])
	out.sort_custom(func(a, b): return a.index < b.index)
	return out

func human(i: int):
	for role in ROLES:
		var p = crew[role]
		if not p.bot and p.index == i:
			return p
	return null

func is_bot(role: String) -> bool:
	return crew[role].bot

## Moves person `i` onto the chibi doing `role` (if no other person has it).
## Their old chibi goes back to a bot.
func assign(i: int, role: String) -> bool:
	var to = crew[role]
	if not to.bot:
		return to.index == i
	var from = human(i)
	var ident: Dictionary = from.driver() if from != null else {}
	if from == null:
		return false
	# The person keeps their character; the bot they swap with moves over
	var bot_char: String = to.char_id
	from.set_driver(bot_identity(bot_char))
	to.set_driver(ident)
	if game.phones:
		game.phones.retarget(from, to)
	return true

## A new person: they get the most useful job nobody's doing.
func join(remote: bool, want_index := -1):
	var free := ""
	for role in JOIN_ORDER:
		if crew[role].bot:
			free = role
			break
	if free == "":
		return null
	var idx := want_index
	if idx < 0:
		for i in ([3, 4, 2] if remote else [2, 3, 4]):
			if human(i) == null:
				idx = i
				break
	if idx < 0 or human(idx) != null:
		return null
	crew[free].set_driver(human_identity(idx, remote, crew[free].char_id))
	return crew[free]

## Person `i` steps to the next job along (dir +1/-1) that nobody else has.
func cycle(i: int, dir: int) -> void:
	var p = human(i)
	if p == null:
		return
	var at := ROLES.find(p.role)
	for k in range(1, ROLES.size()):
		var role: String = ROLES[(at + dir * k + ROLES.size() * 2) % ROLES.size()]
		if crew[role].bot:
			assign(i, role)
			return

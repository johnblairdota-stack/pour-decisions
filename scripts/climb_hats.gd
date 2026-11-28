extends RefCounted
## Climb-day hats. On a climb day the crew works other trades (trades.gd CLIMB_SEAT): riggers,
## doggers, the crane op and one pumpy. Each chibi's hard hat, the icon on it and the hats on the
## TV's crew bar change to the trade they're on for the day (rigger blue with a podger spanner,
## dogger purple with a radio, crane op white with a hook), and go back to the pour-day hats after.

const F := preload("res://scripts/factory.gd")
const UI := preload("res://scripts/ui.gd")
const Trades := preload("res://scripts/trades.gd")

static var on := ""        # the climb kind the hats are on for, "" on a pour day
static var _look := {}     # role -> [colour, icon] while they're on

## A job's hat colour and icon today (the TV's own hats ask: assembly_hud.gd).
static func color_of(role: String) -> Color:
	return _look[role][0] if _look.has(role) else UI.ROLE.get(role, Color.WHITE)

static func icon_of(role: String) -> String:
	return _look[role][1] if _look.has(role) else role

## Everyone into the hats of a `kind` climb day ("spire", "pen", "erect", "lattice"). `cab`: the
## person who's taken the crane cab, or null.
static func apply(game, kind: String, cab = null) -> void:
	on = kind
	for role in game.crew.crew:
		var p = game.crew.crew[role]
		var trade := Trades.climb_trade(role, kind)
		if cab != null and p == cab:
			trade = "crane"
		_wear(game, role, p, Trades.COL.get(trade, UI.ROLE[role]), trade if trade in ["rigger", "dogger", "crane"] else role)

## Back on the pour-day hats.
static func restore(game) -> void:
	if on == "":
		return
	on = ""
	for role in game.crew.crew:
		_wear(game, role, game.crew.crew[role], UI.ROLE[role], "")
	_look = {}

static func _wear(game, role: String, p, col: Color, icon: String) -> void:
	_look[role] = [col, icon if icon != "" else role]
	if p != null and is_instance_valid(p) and p.model != null:
		F._paint(p.model, {"hat": F.color_mat(col, true), "hat_dark": F.color_mat(col.darkened(0.15), true),
			"hat_rib": F.color_mat(col.darkened(0.07), false)})
		p.hat_icon = icon
		p.refresh_tag()
	if game.hud != null and game.hud._crew.has(role):
		var hat: UI.Hat = game.hud._crew[role]["hat"]
		hat.color = col
		hat.icon = icon if icon != "" else role
